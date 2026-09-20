//
//  Created by Kurlovich Vitali on 9/20/26.
//

import SwiftUI

struct PhotoEditorViewModePicker: View {
    typealias ViewMode = CIImageView.Configuration.Mode

    @Binding var viewMode: ViewMode

    var body: some View {
        Picker("Mode", selection: $viewMode) {
            Label("Original", systemImage: "camera.metering.spot")
                .tag(ViewMode.original)

            Label("Split", systemImage: "rectangle.split.2x1")
                .tag(ViewMode.divided)

            Label("Filtered", systemImage: "camera.filters")
                .tag(ViewMode.filtered)
        }.pickerStyle(.segmented)
    }
}
