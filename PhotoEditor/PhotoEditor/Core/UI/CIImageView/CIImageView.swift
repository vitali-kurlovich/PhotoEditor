import CGMathKit
import CoreImage
import CoreImage.CIFilterBuiltins
import MetalKit
import SwiftUI

extension CIImageView: Equatable {
    struct Configuration: Hashable, Sendable {
        enum Mode: Hashable, Sendable {
            case original
            case divided
            case filtered
        }

        enum DisplayMode: Hashable, Sendable {
            case fill
            case fit
        }

        var filter: FilterType
        var cropOffset: CGFloat
        var mode: Mode
        var displayMode: DisplayMode = .fit

        static func original(displayMode: DisplayMode = .fit) -> Configuration {
            .init(filter: .none, cropOffset: 0, mode: .original, displayMode: displayMode)
        }

        static func filtered(filter: FilterType, displayMode: DisplayMode = .fit) -> Configuration {
            .init(filter: filter, cropOffset: 0, mode: .filtered, displayMode: displayMode)
        }

        static func divided(filter: FilterType, offset: CGFloat, displayMode: DisplayMode = .fit) -> Configuration {
            .init(filter: filter, cropOffset: offset, mode: .divided, displayMode: displayMode)
        }
    }
}

struct CIImageView {
    let image: CIImage?

    let configuration: Configuration

    func updateView(_: MTKView, context: Context) {
        let coordinator = context.coordinator
        coordinator.image = image
        coordinator.configuration = configuration
    }
}

#if os(iOS) || os(tvOS)
    extension CIImageView: UIViewRepresentable {
        func makeUIView(context: Context) -> MTKView {
            let coordinator = context.coordinator

            let view = MTKView(frame: .zero, device: context.coordinator.device)
            coordinator.view = view
            coordinator.image = image

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
            let coordinator = context.coordinator

            let view = MTKView(frame: .zero, device: coordinator.device)

            coordinator.view = view
            coordinator.image = image

            view.delegate = coordinator
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
    final class Coordinator: NSObject {
        override init() {
            let metalContext: CIMetalContext = MetalContextManager.shared.context

            guard let queue = metalContext.device.makeCommandQueue() else {
                fatalError("Metal is not supported on this device.")
            }
            device = metalContext.device
            context = metalContext.context
            commandQueue = queue
            super.init()
        }

        let device: MTLDevice
        let context: CIContext

        private let commandQueue: MTLCommandQueue

        var view: MTKView!
        var configuration: CIImageView.Configuration = .original() {
            didSet {
                setNeedsUpdate()
            }
        }

        var image: CIImage? {
            didSet {
                setNeedsUpdate()
            }
        }
    }
}

extension CIImageView.Coordinator: MTKViewDelegate {
    func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {
        setNeedsUpdate()
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

        if let colorSpace = image?.colorSpace, let image = processedImage,
           image.extent.width > 0, image.extent.height > 0
        {
            let scale = self.scale

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

private extension CIImageView.Coordinator {
    var scale: CGFloat {
        #if os(iOS) || os(tvOS)
            return view.layer.contentsScale
        #elseif os(macOS)
            return view.layer?.contentsScale ?? 1
        #endif
    }

    func setNeedsUpdate() {
        #if os(iOS) || os(tvOS)
            view.setNeedsDisplay()
        #elseif os(macOS)
            view.setNeedsDisplay(view.bounds)
        #endif
    }

    var processedImage: CIImage? {
        guard var image else {
            return nil
        }

        let filter = configuration.filter
        let mode = configuration.mode
        let cropOffset = configuration.cropOffset
        let displayMode = configuration.displayMode

        let transform: CGAffineTransform

        switch displayMode {
        case .fill:
            transform = CGAffineTransform
                .transform(
                    for: image.extent.integral,
                    aspectFill: CGRect(origin: .zero, size: view.drawableSize)
                )
        case .fit:
            transform = CGAffineTransform
                .transform(
                    for: image.extent.integral,
                    aspectFit: CGRect(origin: .zero, size: view.drawableSize)
                )
        }

        image = image.transformed(by: transform)

        switch mode {
        case .original:
            return image

        case .filtered:
            return filter.apply(to: image)

        case .divided:
            let scale = self.scale

            let offset = cropOffset * scale
            let rect = image.extent
            let vertical = CGVerticalLine(x: offset)
            let (originalRect, filteredRect) = rect.divide(by: vertical)

            let compose = CIFilter.sourceOverCompositing()
            compose.inputImage = image.cropped(to: originalRect)
            compose.backgroundImage = filter.apply(to: image.cropped(to: filteredRect))

            return compose.outputImage
        }
    }
}
