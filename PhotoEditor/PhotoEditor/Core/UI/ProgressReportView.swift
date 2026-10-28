//
//  Created by Kurlovich Vitali on 9/20/26.
//

import SwiftUI

struct ProgressReportView: View {
    @State private var observation: ProgressObservation?

    init(_ progress: Progress) {
        _observation = State(initialValue: ProgressObservation(progress: progress))
    }

    var body: some View {
        ZStack {
            if let observation {
                ProgressView(value: observation.progressValue) {
                    Label {
                        Text(observation.localizedDescription)
                    } icon: {}
                }
            }
        }
        .onDisappear {
            observation = nil
        }
    }
}
