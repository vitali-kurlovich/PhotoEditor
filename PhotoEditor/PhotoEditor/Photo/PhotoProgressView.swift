//
//  Created by Kurlovich Vitali on 10/27/26.
//

import SwiftUI

struct PhotoProgressView: View {
    let description: String

    var body: some View {
        HStack {
            ProgressView()
            Text(description)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16).fill(Material.thin)
        }
    }
}
