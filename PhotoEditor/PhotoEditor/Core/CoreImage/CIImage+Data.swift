//
//  Created by Kurlovich Vitali on 9/18/26.
//

import CoreImage
import ImageIO

extension CGImage {
    static func image(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            nil
        ) else {
            return nil
        }

        return CGImageSourceCreateImageAtIndex(
            source,
            0,
            nil
        )
    }
}

extension CIImage {
    static func image(from data: Data) -> CIImage? {
        guard let image = CGImage.image(from: data) else {
            return nil
        }
        return CIImage(cgImage: image)
    }
}
