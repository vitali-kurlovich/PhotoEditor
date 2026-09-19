//
//  Created by Kurlovich Vitali on 9/17/26.
//

import CoreImage
import Photos

#if canImport(UIKit)
    import UIKit
#endif
#if canImport(AppKit)
    import AppKit
#endif

extension PHAssetChangeRequest {
    nonisolated static func creationRequestForAsset(from image: CIImage) -> Self {
        #if os(iOS) || os(tvOS)
            let image = UIImage(ciImage: image)
        #elseif os(macOS)
            let rep = NSCIImageRep(ciImage: image)
            let image = NSImage(size: rep.size)
            image.addRepresentation(rep)
        #endif
        return creationRequestForAsset(from: image)
    }
}
