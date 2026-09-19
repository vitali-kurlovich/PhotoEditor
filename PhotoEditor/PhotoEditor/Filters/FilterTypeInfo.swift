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
}
