//
//  Created by Kurlovich Vitali on 9/20/26.
//

import CoreImage
import MetalKit

struct CIMetalContext {
    let device: MTLDevice
    let context: CIContext

    init(device: MTLDevice) {
        self.device = device
        context = CIContext(mtlDevice: device)
    }
}

final class MetalContextManager {
    let context: CIMetalContext

    static let shared = MetalContextManager(device: MTLCreateSystemDefaultDevice()!)

    private init(device: MTLDevice) {
        context = CIMetalContext(device: device)
    }
}
