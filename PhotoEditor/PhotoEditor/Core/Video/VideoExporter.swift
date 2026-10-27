//
//  Created by Kurlovich Vitali on 10/27/26.
//

import AVFoundation
import CGMathKit
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo
import Foundation

enum VideoGeneratorError: Error {
    case assetWriterError(String)
    case failedFrame
}

struct VideoGenerator {
    let fps: Int32
    let durationSeconds: TimeInterval

    let filter: FilterType
    let inputImage: CIImage

    init(inputImage: CIImage, filter: FilterType, duration durationSeconds: TimeInterval = 6.0, fps: Int32 = 30) {
        self.durationSeconds = durationSeconds
        self.fps = fps
        self.filter = filter
        self.inputImage = inputImage
    }

    func export(to outputURL: URL) async throws {
        let rect = inputImage.extent

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: rect.width,
            AVVideoHeightKey: rect.height,
        ])
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: rect.width,
                kCVPixelBufferHeightKey as String: rect.height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            ]
        )
        writer.add(input)
        guard writer.startWriting() else {
            throw VideoGeneratorError.assetWriterError("Cannot start writing: \(writer.error?.localizedDescription ?? "unknown")")
        }

        writer.startSession(atSourceTime: .zero)

        // GPU-backed context; renders straight into the writer's pixel buffers.
        let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
        let colorSpace = inputImage.colorSpace ?? CGColorSpace(
            name: CGColorSpace.sRGB
        )!

        let frameCount = Int(durationSeconds * Double(fps))

        for frame in 0 ..< frameCount {
            while !input.isReadyForMoreMediaData {
                usleep(1000)
            }

            guard let pool = adaptor.pixelBufferPool else {
                throw VideoGeneratorError.assetWriterError("No pixel buffer pool")
            }
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            guard let buffer = pixelBuffer else {
                throw VideoGeneratorError.assetWriterError("Cannot allocate pixel buffer")
            }

            guard let image = makeFrame(t: Double(frame) / Double(frameCount)) else {
                throw VideoGeneratorError.failedFrame
            }

            let extent = CGRect(
                x: 0,
                y: 0,
                width: rect.width,
                height: rect.height
            )

            context.render(image, to: buffer, bounds: extent, colorSpace: colorSpace)

            let time = CMTime(value: CMTimeValue(frame), timescale: fps)
            
            if !adaptor.append(buffer, withPresentationTime: time) {
                throw VideoGeneratorError.assetWriterError("Append failed at frame \(frame): \(writer.error?.localizedDescription ?? "")")
            }
        }

        input.markAsFinished()

        await writer.finishWriting()
    }

    private func makeFrame(t: Double) -> CIImage? {
        let image = inputImage

        let rect = image.extent
        let offset = rect.width * (1.0 - t)
        let vertical = CGVerticalLine(x: offset)
        let (originalRect, filteredRect) = rect.divide(by: vertical)

        let compose = CIFilter.sourceOverCompositing()
        compose.inputImage = image.cropped(to: originalRect)
        compose.backgroundImage = filter.apply(to: image.cropped(to: filteredRect))

        return compose.outputImage
    }
}
