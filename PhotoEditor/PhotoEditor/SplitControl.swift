//
//  Created by Kurlovich Vitali on 9/18/26.
//

import SwiftUI

struct SplitControl: View {
    @Binding
    var midPoint: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let bounds = proxy.frame(in: .local)
            ZStack {
                Rectangle()
                    .fill(.primary)
                    .frame(width: 1)
                Image(systemName: "arrowtriangle.left.and.line.vertical.and.arrowtriangle.right.fill")
                    .font(.title)
                    .padding(8)
                    .background {
                        Circle()
                            .strokeBorder(.secondary, lineWidth: 1)
                            .fill(Material.ultraThin)
                    }
            }
            .position(
                x: bounds.minX + bounds.width * midPoint,
                y: bounds.midY
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        midPoint = (value.location.x - bounds.minX) / bounds.width
                    }
            )
        }
    }
}

#Preview {
    @Previewable @State var midPoint: CGFloat = 0.5

    SplitControl(midPoint: $midPoint)
}
