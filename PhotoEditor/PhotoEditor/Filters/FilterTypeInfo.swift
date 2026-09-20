//
//  Created by Kurlovich Vitali on 9/18/26.
//

import CoreImage
import SwiftUI

extension CIFilter {
    var displayName: String {
        attributes[kCIAttributeDisplayName] as? String ?? attributes[kCIAttributeFilterDisplayName] as? String ?? ""
    }

    var attributeDescription: String? {
        attributes[kCIAttributeDescription] as? String
    }
}

extension FilterTypeInfo {
    func coreImageFilter(for type: FilterType) -> CIFilter? {
        switch type {
        case .none:
            return nil
        case .sepia:
            return CIFilter.sepiaTone()
        case .mono:
            return CIFilter.photoEffectMono()
        case .noir:
            return CIFilter.photoEffectNoir()
        case .chrome:
            return CIFilter.photoEffectChrome()
        case .instant:
            return CIFilter.photoEffectInstant()
        case .fade:
            return CIFilter.photoEffectFade()
        case .process:
            return CIFilter.photoEffectProcess()
        case .transfer:
            return CIFilter.photoEffectTransfer()
        case .comic:
            return CIFilter.comicEffect()
        case .invert:
            return CIFilter.colorInvert()
        case .vibrance:
            return CIFilter.vibrance()
        case .lut:
            return CIFilter.colorCube()
        }
    }
}

struct FilterTypeInfo {
    func displayName(for filter: FilterType) -> String {
        coreImageFilter(for: filter)?.displayName ?? "Original"
    }

    func attributeDescription(for filter: FilterType) -> String? {
        coreImageFilter(for: filter)?.attributeDescription
    }
}
