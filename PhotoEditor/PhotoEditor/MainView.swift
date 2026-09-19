//
//  Created by Kurlovich Vitali on 9/18/26.
//

import SwiftUI

struct MainView: View {
    var body: some View {
        TabView {
            Tab("Photo", systemImage: "photo") {
                NavigationStack {
                    PhotoView()
                }
            }

            Tab("Camera", systemImage: "camera") {
                NavigationStack {
                    CameraView()
                }
            }
        }
    }
}

#Preview {
    MainView()
}
