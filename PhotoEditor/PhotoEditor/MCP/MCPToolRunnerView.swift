//
//  Created by Kurlovich Vitali on 10/26/26.
//

import CoreImage
import MCP
import SwiftUI

struct MCPToolRunnerView: View {
    @Binding
    var runner: MCPToolRunner
    var onImage: (CIImage) -> Void = { _ in }

    var body: some View {
        switch runner.result {
        case .idle:
            EmptyView()
        case .inProgress:
            ProgressView()
        case let .error(error):
            Text(error)
        case let .run(run):
            MCPToolRunView(run: run, onImage: onImage) { _ in
            }
        }
    }
}
