import CoreImage
import CoreImage.CIFilterBuiltins

enum FilterType: Identifiable, Hashable, Sendable {
    case none
    case sepia
    case mono
    case noir
    case chrome
    case instant
    case fade
    case process
    case transfer
    case comic
    case invert
    case vibrance
    case lut(CubeLUT)

    var id: Self {
        self
    }

    /// Applies the filter to `image`, returning the original image if the
    /// filter fails to produce output (CoreImage filters can return nil for
    /// out-of-range inputs or unsupported extents).
    nonisolated func apply(to image: CIImage) -> CIImage {
        switch self {
        case .none:
            return image

        case .sepia:
            let filter = CIFilter.sepiaTone()
            filter.inputImage = image
            filter.intensity = 0.9
            return filter.outputImage ?? image

        case .mono:
            let filter = CIFilter.photoEffectMono()
            filter.inputImage = image
            return filter.outputImage ?? image

        case .noir:
            let filter = CIFilter.photoEffectNoir()
            filter.inputImage = image
            return filter.outputImage ?? image

        case .chrome:
            let filter = CIFilter.photoEffectChrome()
            filter.inputImage = image
            return filter.outputImage ?? image

        case .instant:
            let filter = CIFilter.photoEffectInstant()
            filter.inputImage = image
            return filter.outputImage ?? image

        case .fade:
            let filter = CIFilter.photoEffectFade()
            filter.inputImage = image
            return filter.outputImage ?? image

        case .process:
            let filter = CIFilter.photoEffectProcess()
            filter.inputImage = image
            return filter.outputImage ?? image

        case .transfer:
            let filter = CIFilter.photoEffectTransfer()
            filter.inputImage = image
            return filter.outputImage ?? image

        case .comic:
            let filter = CIFilter.comicEffect()
            filter.inputImage = image
            return filter.outputImage ?? image

        case .invert:
            let filter = CIFilter.colorInvert()
            filter.inputImage = image
            return filter.outputImage ?? image

        case .vibrance:
            let filter = CIFilter.vibrance()
            filter.inputImage = image
            filter.amount = 0.8
            return filter.outputImage ?? image

        case let .lut(cube):
            let filter = CIFilter.colorCube()
            filter.inputImage = image
            filter.cubeData = cube.data
            filter.cubeDimension = Float(cube.dimension)
            return filter.outputImage ?? image
        }
    }
}
