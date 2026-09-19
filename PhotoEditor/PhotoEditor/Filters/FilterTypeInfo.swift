//
//  FilterTypeInfo.swift
//  CameraFilters
//
//  Created by Kurlovich Vitali on 9/18/26.
//

import SwiftUI

struct FilterTypeInfo {
    func displayName(for filter: FilterType) -> String {
        switch filter {
        case .none:
            return "Original"
        case .sepia:
            return "Sepia"
        case .mono:
            return "Mono"
        case .noir:
            return "Noir"
        case .chrome:
            return "Chrome"
        case .instant:
            return "Instant"
        case .fade:
            return "Fade"
        case .process:
            return "Process"
        case .transfer:
            return "Transfer"
        case .comic:
            return "Comic"
        case .invert:
            return "Invert"
        case .vibrance:
            return "Vibrance"
        case let .lut(cube):
            if let title = cube.title, title.isEmpty == false {
                return title
            }
            return "LUT"
        }
    }

    func displayImage(for filter: FilterType) -> Image {
        switch filter {
        case .none:
            return Image(systemName: "photo")
        case .sepia:
            return Image(systemName: "circle.bottomrighthalf.pattern.checkered")
        case .mono:
            return Image(systemName: "lightspectrum.horizontal")
        case .noir:
            return Image(systemName: "circle.lefthalf.filled.righthalf.striped.horizontal")
        case .chrome:
            return Image(systemName: "circle.dotted.and.circle")
        case .instant:
            return Image(systemName: "photo")
        case .fade:
            return Image(systemName: "photo")
        case .process:
            return Image(systemName: "photo")
        case .transfer:
            return Image(systemName: "photo")
        case .comic:
            return Image(systemName: "photo")
        case .invert:
            return Image(systemName: "photo")
        case .vibrance:
            return Image(systemName: "photo")
        case .lut:
            return Image(systemName: "photo")
        }
    }
}
