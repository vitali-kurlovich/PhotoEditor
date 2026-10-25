//
//  Created by Kurlovich Vitali on 10/25/26.
//

import CoreImage
import MCP
import SwiftUI

struct MCPToolView: View {
    let tool: Tool
    var onImage: (CIImage) -> Void = { _ in }

    @State private var argumentsJSON: String = "{}"
    @State private var result: MCPToolResult?
    @State private var errorMessage: String?
    @State private var isRunning: Bool = false

    var body: some View {
        Form {
            if let description = tool.description {
                Section {
                    Text(description)
                }
            }

            Section("Input schema") {
                Text(Self.prettyJSON(tool.inputSchema))
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }

            Section("Arguments (JSON)") {
                TextEditor(text: $argumentsJSON)
                    .font(.body.monospaced())
                    .frame(minHeight: 120)
                    .autocorrectionDisabled()
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif

                Button {
                    run()
                } label: {
                    if isRunning {
                        ProgressView()
                    } else {
                        Text("Call Tool")
                    }
                }
                .disabled(isRunning)
            }

            if let errorMessage {
                Section("Error") {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if let result {
                Section(result.isError ? "Tool error" : "Result") {
                    if !result.text.isEmpty {
                        Text(result.text)
                            .font(.callout.monospaced())
                            .foregroundStyle(result.isError ? .red : .primary)
                            .textSelection(.enabled)
                    }

                    ForEach(Array(result.images.enumerated()), id: \.offset) { _, image in
                        Button {
                            onImage(image)
                        } label: {
                            CIImageThumbnail(image: image)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open image in editor")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(tool.title ?? tool.name)
    }

    private func run() {
        isRunning = true
        errorMessage = nil
        result = nil

        Task {
            do {
                result = try await MCPClientManager.shared.callTool(tool.name, argumentsJSON: argumentsJSON)
            } catch {
                errorMessage = error.localizedDescription
            }
            isRunning = false
        }
    }

    private static func prettyJSON(_ value: Value) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        guard let data = try? encoder.encode(value) else { return value.description }
        return String(decoding: data, as: UTF8.self)
    }
}

private struct CIImageThumbnail: View {
    let image: CIImage

    var body: some View {
        if let cgImage = MetalContextManager.shared.ciContext.createCGImage(image, from: image.extent) {
            Image(decorative: cgImage, scale: 1)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 240)
        } else {
            Label("Unsupported image", systemImage: "photo.badge.exclamationmark")
        }
    }
}
