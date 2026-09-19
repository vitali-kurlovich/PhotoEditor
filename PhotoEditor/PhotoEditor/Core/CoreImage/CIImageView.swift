import CGMathKit
import CoreImage
import CoreImage.CIFilterBuiltins
import MetalKit
import SwiftUI

extension CIImageView {
    struct Configuration: Hashable, Sendable {
        enum Mode: Hashable, Sendable {
            case original
            case divided
            case filtered
        }

        var filter: FilterType
        var cropOffset: CGFloat
        var mode: Mode

        static func original() -> Configuration {
            .init(filter: .none, cropOffset: 0, mode: .original)
        }

        static func filtered(filter: FilterType) -> Configuration {
            .init(filter: filter, cropOffset: 0, mode: .filtered)
        }

        static func divided(filter: FilterType, offset: CGFloat) -> Configuration {
            .init(filter: filter, cropOffset: offset, mode: .divided)
        }
    }
}

struct CIImageView: Equatable {
    let image: CIImage?
    let configuration: Configuration

    func updateView(_ view: MTKView, context: Context) {
        defer {
            #if os(iOS) || os(tvOS)
                view.setNeedsDisplay()
            #elseif os(macOS)
                view.setNeedsDisplay(view.bounds)
            #endif
        }

        let coordinator = context.coordinator

        guard var image else {
            coordinator.image = nil
            return
        }

        let filter = configuration.filter
        let mode = configuration.mode
        let cropOffset = configuration.cropOffset

        let tr = CGAffineTransform
            .transform(
                for: image.extent.integral,
                aspectFit: CGRect(origin: .zero, size: view.drawableSize)
            )

        image = image.transformed(by: tr)

        switch mode {
        case .original:
            coordinator.image = image

        case .filtered:
            coordinator.image = filter.apply(to: image)

        case .divided:
            #if os(iOS) || os(tvOS)
                let scale = view.layer.contentsScale
            #elseif os(macOS)
                let scale = view.layer?.contentsScale ?? 1
            #endif

            let offset = cropOffset * scale

            let rect = image.extent

            let vertical = CGVerticalLine(x: offset)

            let (originalRect, filteredRect) = rect.divide(by: vertical)

            let compose = CIFilter.sourceOverCompositing()
            compose.inputImage = image.cropped(to: originalRect)
            compose.backgroundImage = filter.apply(to: image.cropped(to: filteredRect))

            coordinator.image = compose.outputImage
        }
    }
}

#if os(iOS) || os(tvOS)
    extension CIImageView: UIViewRepresentable {
        func makeUIView(context: Context) -> MTKView {
            let view = MTKView(frame: .zero, device: context.coordinator.device)

            view.delegate = context.coordinator
            view.framebufferOnly = false
            view.isPaused = false

            // view.framebufferOnly = false
            view.colorPixelFormat = .bgra8Unorm

            view.enableSetNeedsDisplay = true
            // view.preferredFramesPerSecond = 30
            view.backgroundColor = .clear
            return view
        }

        func updateUIView(_ view: MTKView, context: Context) {
            updateView(view, context: context)
        }
    }

#elseif os(macOS)

    /// SwiftUI wrapper around an MTKView, backed by our Metal `Renderer`.
    extension CIImageView: NSViewRepresentable {
        func makeNSView(context: Context) -> MTKView {
            let view = MTKView()

            view.device = context.coordinator.device
            view.delegate = context.coordinator
            view.framebufferOnly = false
            view.isPaused = false
            view.enableSetNeedsDisplay = true
            // view.preferredFramesPerSecond = 30
            view.clearColor = MTLClearColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)

            return view
        }

        func updateNSView(_ view: MTKView, context: Context) {
            updateView(view, context: context)
        }
    }

#endif

extension CIImageView {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
}

extension CIImageView {
    final class Coordinator: NSObject, MTKViewDelegate {
        let device: MTLDevice
        let context: CIContext
        var image: CIImage?

        private let colorSpace = CGColorSpaceCreateDeviceRGB()

        private let commandQueue: MTLCommandQueue

        override init() {
            //  self.cameraManager = cameraManager
            guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
                fatalError("Metal is not supported on this device.")
            }
            self.device = device
            context = CIContext(mtlDevice: device)
            commandQueue = queue
            super.init()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange _: CGSize) {
            #if os(iOS) || os(tvOS)
                view.setNeedsDisplay()
            #elseif os(macOS)
                view.setNeedsDisplay(view.bounds)
            #endif
        }

        func draw(in view: MTKView) {
            guard
                let drawable = view.currentDrawable,
                let commandBuffer = commandQueue.makeCommandBuffer()
            else { return }

            let renderEncoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: {
                    let descriptor = MTLRenderPassDescriptor()

                    let color = descriptor.colorAttachments[0]!
                    color.texture = drawable.texture
                    color.loadAction = .clear
                    color.storeAction = .store
                    color.clearColor = MTLClearColorMake(0, 0, 0, 0)

                    return descriptor
                }()
            )

            renderEncoder?.endEncoding()

            if let image,
               image.extent.width > 0, image.extent.height > 0
            {
                #if os(iOS) || os(tvOS)
                    let scale = view.layer.contentsScale
                #elseif os(macOS)
                    let scale = view.layer?.contentsScale ?? 1
                #endif

                let bounds = CGRect(
                    x: view.bounds.x * scale,
                    y: view.bounds.y * scale,
                    width: view.bounds.width * scale,
                    height: view.bounds.height * scale
                )

                context
                    .render(
                        image,
                        to: drawable.texture,
                        commandBuffer: commandBuffer,
                        bounds: bounds,
                        colorSpace: colorSpace
                    )
            }

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}
