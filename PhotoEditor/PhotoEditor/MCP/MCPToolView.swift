//
//  Created by Kurlovich Vitali on 10/25/26.
//

import CoreImage
import MCP
import SwiftUI

@Observable
final class MCPToolRunner {
    enum Result {
        case idle
        case inProgress
        case run(MCPToolRun)
        case error(String)
    }

    var result: Result = .idle

    var tool: Tool?

    init(tool: Tool? = nil) {
        self.tool = tool
    }

    func prettyJSON(_ arguments: [String: Value]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        guard let data = try? encoder.encode(arguments) else { return arguments.description }
        return String(decoding: data, as: UTF8.self)
    }

    func run(_ arguments: [String: Value]) async {
        guard let tool else { return }

        result = .inProgress

        do {
            let clock = ContinuousClock()
            let start = clock.now
            let date = Date()

            let toolResult = try await manager.callTool(
                tool.name,
                arguments: arguments
            )

            let run = MCPToolRun(result: toolResult, argumentsJSON: prettyJSON(arguments), date: date, duration: clock.now - start)
            result = .run(run)

        } catch {
            result = .error(error.localizedDescription)
        }
    }

    private var manager: MCPClientManager {
        .shared
    }
}

struct MCPToolView: View {
    let tool: Tool
    var onImage: (CIImage) -> Void = { _ in }

    @State private var argumentsJSON: String = "{}"
    @State private var runs: [MCPToolRun] = []
    @State private var errorMessage: String?
    @State private var isRunning: Bool = false
    @State private var showSchema: Bool = false

    var body: some View {
        Form {
            Section {
                if let description = tool.description {
                    Text(description)
                }

                DisclosureGroup("Input schema", isExpanded: $showSchema) {
                    Text(Self.prettyJSON(tool.inputSchema))
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
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
                        HStack {
                            ProgressView()
                            Text("Running…")
                        }
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
                        .textSelection(.enabled)
                }
            }

            ForEach(runs) { run in
                MCPToolRunView(run: run, onImage: onImage) { arguments in
                    argumentsJSON = arguments
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(tool.title ?? tool.name)
        .toolbar {
            if !runs.isEmpty {
                ToolbarItem(placement: .automatic) {
                    Button("Clear Results", systemImage: "trash") {
                        runs = []
                        errorMessage = nil
                    }
                }
            }
        }.controlSize(.small)
    }

    private func run() {
        isRunning = true
        errorMessage = nil

        let arguments = argumentsJSON
        let clock = ContinuousClock()
        let start = clock.now
        let date = Date()

        Task {
            do {
                let result = try await MCPClientManager.shared.callTool(tool.name, argumentsJSON: arguments)
                let run = MCPToolRun(result: result, argumentsJSON: arguments, date: date, duration: clock.now - start)
                runs.insert(run, at: 0)
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

struct MCPInputToolView: View {
    let input: Value

    var body: some View {}
}

struct MCPInputToolBoolView: View {
    let name: String

    var value: Bool

    var body: some View {
        // Toggle(name, isOn: <#T##Binding<Bool>#>)
    }
}
