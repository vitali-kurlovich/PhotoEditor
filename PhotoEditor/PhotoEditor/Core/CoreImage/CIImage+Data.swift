//
//  Created by Kurlovich Vitali on 9/18/26.
//

import CoreImage
import ImageIO

extension CIImage {
    static func image(from data: Data) -> CIImage? {
        return CIImage(data: data)
    }
}
