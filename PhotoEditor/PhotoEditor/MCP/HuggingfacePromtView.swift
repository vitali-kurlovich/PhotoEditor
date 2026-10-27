//
//  Created by Kurlovich Vitali on 10/26/26.
//

import CoreImage
import MCP
import SwiftUI

extension HuggingfacePromtView {
    private nonisolated static var key: String {
        "HUGGINGFACE_API_KEY"
    }

    private var manager: MCPClientManager {
        .shared
    }
}

struct HuggingfacePromtView: View {
    @Environment(\.dismiss) private var dismiss

    @AppKeychainStore(key: Self.key)
    var bearerToken: String

    private var serverURL: String = "https://huggingface.co/mcp"

    @State
    private var runner = MCPToolRunner()

    @State
    private var waitForResponse: Bool = false

    var onImage: (CIImage) -> Void = { _ in }
    @State
    private var promt: String = ""

    @State
    private var width: Double = 1024
    @State
    private var height: Double = 1024
    
    @FocusState private var isPromptFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section{
                    SecureField("Bearer token (optional)", text: $bearerToken)
                } header: {
                    HStack {
                        Text("Hugging Face")
                        Spacer()
                        Link("https://huggingface.co", destination: URL(string:"https://huggingface.co/settings/tokens")!)
                    }
                }
                Section {
                    TextField("Promt", text: $promt)
                        .focused($isPromptFocused)
                    Slider(value: $width, in: 256 ... 2048, step: 256) {
                        HStack {
                            Text("Width")
                            Text(width, format: .number)
                        }
                    }
                    Slider(value: $height, in: 256 ... 2048, step: 256) {
                        HStack {
                            Text("Height")
                            Text(height, format: .number)
                        }
                    }
                    HStack {
                        statusRow
                        Spacer()
                        Button("Send") {
                            Task {
                                waitForResponse = true

                                if manager.isConnected == false {
                                    await manager.connect(to: serverURL, bearerToken: bearerToken)
                                }

                                self.runner.tool = manager.tools.last

                                await runner
                                    .run(
                                        [
                                            "prompt": .string(promt),
                                            "width": .double(width),
                                            "height": .double(height),
                                        ]
                                    )

                                waitForResponse = false
                            }

                        }.disabled(promt.isEmpty || waitForResponse)
                    }
                }
                MCPToolRunnerView(runner: $runner, onImage: onImage)
            }
            .formStyle(.grouped)
            .navigationTitle("Huggingface")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .controlSize(.small)
            .onAppear {
                isPromptFocused = true
            }
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch manager.state {
        case .disconnected:
            Label("Disconnected", systemImage: "circle")
                .foregroundStyle(.secondary)
        case .connecting:
            HStack {
                ProgressView()
                Text("Connecting…")
            }
        case let .connected(name, version):
            Label("\(name) \(version)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    HuggingfacePromtView { _ in
    }
}
