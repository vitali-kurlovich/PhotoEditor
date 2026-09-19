//
//  Created by Kurlovich Vitali on 9/19/26.
//

import CoreImage
import SwiftUI

struct ImageEditorView: View {
    typealias ViewMode = CIImageView.Configuration.Mode

    let filter: FilterType
    let editedImage: CIImage?
    let viewMode: ViewMode

    @State private var splitBaseline: CGFloat = 0.5

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .local)
            let offset = frame.minX + frame.width * splitBaseline
            CIImageView(
                image: editedImage,
                configuration: self.configuration(offset: offset)
            )
        }
        .overlay {
            if viewMode == .divided, filter != .none, editedImage != nil {
                SplitControl(midPoint: $splitBaseline)
            }
        }
    }
}

private extension ImageEditorView {
    func configuration(offset: CGFloat) -> CIImageView.Configuration {
        switch viewMode {
        case .original:
            return .original()
        case .filtered:
            return .filtered(filter: filter)
        case .divided:
            return .divided(filter: filter, offset: offset)
        }
    }
}
