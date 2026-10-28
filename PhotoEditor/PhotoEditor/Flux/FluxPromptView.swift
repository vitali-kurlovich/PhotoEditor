import CoreImage
import ImageIO
import SwiftUI

/// Generates images with FLUX through Hugging Face Inference Providers.
struct FluxPromptView: View {
    @Environment(\.dismiss) private var dismiss

    var onImage: (CIImage) -> Void = { _ in }

    /// Shared with `HuggingfacePromtView`, so the token is entered once.
    @AppKeychainStore(key: "HUGGINGFACE_API_KEY")
    var bearerToken: String

    @State
    private var model = FluxViewModel()

    @FocusState private var isPromptFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Access token", text: $bearerToken)
                    Picker("Model", selection: $model.model) {
                        ForEach(FluxModel.allCases) { model in
                            Text(model.title).tag(model)
                        }
                    }
                    .disabled(model.isGenerating)
                } header: {
                    HStack {
                        Text("Hugging Face")
                        Spacer()
                        Link("Tokens", destination: URL(string: "https://huggingface.co/settings/tokens")!)
                    }
                } footer: {
                    Text("FLUX runs in the cloud on fal.ai and is billed to your Hugging Face account.")
                }

                Section("Prompt") {
                    TextEditor(text: $model.prompt)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .focused($isPromptFocused)
                }

                Section {
                    VStack(alignment: .leading) {
                        LabeledContent("Width", value: model.width, format: .number)
                        Slider(value: $model.width, in: 256 ... 2048, step: 64)
                    }
                    VStack(alignment: .leading) {
                        LabeledContent("Height", value: model.height, format: .number)
                        Slider(value: $model.height, in: 256 ... 2048, step: 64)
                    }
                    VStack(alignment: .leading) {
                        LabeledContent("Steps", value: model.stepCount, format: .number)
                        Slider(value: $model.stepCount, in: model.model.stepRange, step: 1)
                    }
                    if model.model.supportsGuidance {
                        VStack(alignment: .leading) {
                            LabeledContent("Guidance", value: model.guidanceScale, format: .number)
                            Slider(value: $model.guidanceScale, in: 1 ... 10, step: 0.5)
                        }
                    }
                    HStack {
                        statusRow
                        Spacer()
                        if model.isGenerating {
                            Button("Cancel", role: .cancel) {
                                model.cancel()
                            }
                        } else {
                            Button("Generate") {
                                isPromptFocused = false
                                model.generate(token: bearerToken)
                            }
                            .disabled(model.prompt.isEmpty || bearerToken.isEmpty)
                        }
                    }
                }

                if let data = model.imageData,
                   let source = CGImageSourceCreateWithData(data as CFData, nil),
                   let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
                {
                    Section {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .scaledToFit()
                        Button("Use Image") {
                            onImage(CIImage(cgImage: image))
                            dismiss()
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("FLUX")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .controlSize(.small)
            .onDisappear {
                model.cancel()
            }
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch model.state {
        case .idle:
            EmptyView()
        case let .queued(position):
            HStack {
                ProgressView()
                if let position {
                    Text("In queue (\(position))")
                } else {
                    Text("In queue…")
                }
            }
        case .running:
            HStack {
                ProgressView()
                Text("Generating…")
            }
        case let .finished(_, seed):
            Text("Seed \(seed, format: .number.grouping(.never))")
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    FluxPromptView { _ in
    }
}
