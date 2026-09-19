import AVFoundation
import CoreImage
import Observation

public enum CameraError: LocalizedError {
    case permissionDenied
    case noDevice
    case inputError
    case videoOutputError
    case photoOutputError
    case sessionError(Error)

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera access was denied. Enable it in Settings to use camera."

        case .noDevice:
            return "Couldn't create AVCaptureDevice"

        case .inputError:
            return "Couldn't connect capture device input "

        case .videoOutputError:
            return "Couldn't connect video output"

        case .photoOutputError:
            return "Couldn't connect photo output"

        case let .sessionError(error):
            return "Session configuration error: \(error.localizedDescription)"
        }
    }
}

@Observable
public final nonisolated class CameraManagerObserver {
    public internal(set) var state: CameraManager.State = .idle
}

public actor CameraManager {
    public enum State: Hashable, Sendable {
        case idle
        case requestAccess
        case permissionDenied
        case failed
        case started
        case stoped
    }

    public static let shared = CameraManager()

    private init() {}

    public let observer = CameraManagerObserver()

    private var currentDevice: AVCaptureDevice?

    private var currentCameraPosition: AVCaptureDevice.Position = .back

    private let sampleBufferDelegate = VideoDataOutputSampleBufferDelegate()
    private let photoCaptureDelegate = PhotoCaptureDelegate()

    private let videoQueue = DispatchQueue(label: "camera.video.queue", qos: .userInteractive)

    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
}

public extension CameraManager {
    var state: State {
        observer.state
    }

    var videoStream: AsyncStream<CIImage> {
        sampleBufferDelegate.outputImageStream
    }

    var photoCaptureStream: AsyncStream<CIImage> {
        photoCaptureDelegate.photoCaptureStream
    }

    var isRunning: Bool {
        session.isRunning
    }
}

public extension CameraManager {
    func start() async throws(CameraError) {
        observer.state = .requestAccess

        guard await AVCaptureDevice.requestAccess(for: .video) else {
            observer.state = .permissionDenied
            throw CameraError.permissionDenied
        }

        do {
            try await configureSession()
            observer.state = .started
        } catch {
            observer.state = .failed
            throw error
        }
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }

        observer.state = .stoped
    }
}

public extension CameraManager {
    func captureFilteredPhoto() {
        let settings = AVCapturePhotoSettings()

        if let device = currentDevice,
           device.hasFlash
        {
            settings.flashMode = .auto
        }

        photoOutput.capturePhoto(with: settings, delegate: photoCaptureDelegate)
    }

    func flipCamera() async throws {
        currentCameraPosition = currentCameraPosition == .back ? .front : .back
        try await configureSession()
    }
}

extension CameraManager {
    private func configureSession() async throws(CameraError) {
        currentDevice = nil

        session.beginConfiguration()
        session.sessionPreset = .hd1920x1080

        // Input
        session.inputs.forEach { session.removeInput($0) }

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition)
        else {
            session.commitConfiguration()
            throw CameraError.noDevice
        }

        // Input
        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)

        } catch {
            session.commitConfiguration()
            throw CameraError.sessionError(error)
        }

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraError.inputError
        }

        session.addInput(input)

        // Output

        session.outputs.forEach { session.removeOutput($0) }
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true

        videoOutput
            .setSampleBufferDelegate(
                sampleBufferDelegate,
                queue: videoQueue
            )

        guard session
            .canAddOutput(videoOutput)
        else {
            session.commitConfiguration()
            throw CameraError.videoOutputError
        }

        guard session
            .canAddOutput(photoOutput)
        else {
            session.commitConfiguration()
            throw CameraError.photoOutputError
        }

        session.addOutput(videoOutput)
        session.addOutput(photoOutput)

        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if currentCameraPosition == .front, connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }

        session.commitConfiguration()
        session.startRunning()

        currentDevice = device
    }
}

private final nonisolated class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let photoCaptureStream: AsyncStream<CIImage>
    private let continuation: AsyncStream<CIImage>.Continuation

    override init() {
        let (stream, continuation) = AsyncStream<CIImage>.makeStream()
        photoCaptureStream = stream
        self.continuation = continuation
    }

    func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error _: (any Error)?
    ) {
        guard let image = photo.cgImageRepresentation() else {
            return
        }

        let ciImage = CIImage(cgImage: image)

        continuation.yield(ciImage)
    }
}

private final nonisolated class VideoDataOutputSampleBufferDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let outputImageStream: AsyncStream<CIImage>
    private let continuation: AsyncStream<CIImage>.Continuation

    override init() {
        let (stream, continuation) = AsyncStream<CIImage>.makeStream()
        outputImageStream = stream
        self.continuation = continuation
    }

    func captureOutput(
        _: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from _: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        continuation.yield(image)
    }
}
