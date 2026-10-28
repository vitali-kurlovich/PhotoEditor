//
//  Created by Kurlovich Vitali on 10/25/26.
//

import CoreImage
import MCP
import SwiftUI

struct MCPServerView: View {
    private nonisolated static var key: String {
        "HUGGINGFACE_API_KEY"
    }

    /// Called when the user picks an image returned by a tool.
    var onImage: (CIImage) -> Void = { _ in }

    private let serverURL: String = "https://huggingface.co/mcp"

    @AppKeychainStore(key: Self.key)
    private var bearerToken: String

    @Environment(\.dismiss) private var dismiss

    private var manager: MCPClientManager {
        .shared
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Bearer token (optional)", text: $bearerToken)
                } header: {
                    HStack {
                        Text("Hugging Face")
                        Spacer()
                        Link("https://huggingface.co", destination: URL(string: "https://huggingface.co/settings/tokens")!)
                    }
                }
                Section {
                    statusRow

                    if manager.isConnected {
                        Button("Disconnect", role: .destructive) {
                            Task { await manager.disconnect() }
                        }
                    } else {
                        Button("Connect") {
                            Task { await manager.connect(to: serverURL, bearerToken: bearerToken) }
                        }
                        .disabled(manager.state == .connecting || serverURL.isEmpty)
                    }
                }

                if manager.isConnected {
                    Section("Tools") {
                        if manager.tools.isEmpty {
                            Text("No tools available")
                                .foregroundStyle(.secondary)
                        }

                        ForEach(manager.tools, id: \.name) { tool in
                            NavigationLink {
                                MCPToolView(tool: tool, onImage: { image in
                                    onImage(image)
                                    dismiss()
                                })
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(tool.title ?? tool.name)
                                    if let description = tool.description {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("MCP Servers")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .refreshable {
                try? await manager.refreshTools()
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
    MCPServerView()
}
