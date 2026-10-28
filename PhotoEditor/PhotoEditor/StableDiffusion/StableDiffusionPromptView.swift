import CoreImage
import SwiftUI

/// Generates images on device with Core ML SDXL.
struct StableDiffusionPromptView: View {
    @Environment(\.dismiss) private var dismiss

    var onImage: (CIImage) -> Void = { _ in }

    @State
    private var model = StableDiffusionViewModel()

    @State
    private var errorMessage: String?

    @FocusState private var isPromptFocused: Bool

    private var store: SDXLModelStore {
        .shared
    }

    var body: some View {
        NavigationStack {
            Form {
                modelSection

                Section("Prompt") {
                    TextEditor(text: $model.prompt)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .focused($isPromptFocused)
                    TextField("Negative prompt", text: $model.negativePrompt)
                }

                Section {
                    VStack(alignment: .leading) {
                        LabeledContent("Steps", value: model.stepCount, format: .number)
                        Slider(value: $model.stepCount, in: 10 ... 50, step: 1)
                    }
                    VStack(alignment: .leading) {
                        LabeledContent("Guidance", value: model.guidanceScale, format: .number)
                        Slider(value: $model.guidanceScale, in: 1 ... 12, step: 0.5)
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
                                model.generate(resourcesAt: store.modelURL)
                            }
                            .disabled(model.prompt.isEmpty || !store.isReady)
                        }
                    }
                }

                if let image = model.image {
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
            .navigationTitle("Stable Diffusion XL")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .controlSize(.small)
            .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
            } message: {
                Text(errorMessage ?? "")
            }
            .onDisappear {
                Task { await model.unload() }
            }
        }
    }

    @ViewBuilder
    private var modelSection: some View {
        Section {
            switch store.state {
            case .notDownloaded:
                Text("SDXL base runs on device with Core ML. It needs a ~3 GB download and an iPhone with 8 GB of RAM.")
                    .foregroundStyle(.secondary)
                Button("Download Model", systemImage: "arrow.down.circle") {
                    store.download()
                }
            case let .downloading(progress):
                ProgressReportView(progress)
                Button("Cancel Download", role: .cancel) {
                    store.cancelDownload()
                }
            case .ready:
                Label("Model ready", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button("Delete Model", systemImage: "trash", role: .destructive) {
                    do {
                        try store.delete()
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                .disabled(model.isGenerating)
            case let .failed(message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Button("Retry Download", systemImage: "arrow.clockwise") {
                    store.download()
                }
            }
        } header: {
            HStack {
                Text("Model")
                Spacer()
                Link("Hugging Face", destination: URL(string: "https://huggingface.co/\(SDXLModelStore.repository)")!)
            }
        }
    }

    @ViewBuilder
    private var statusRow: some View {
        switch model.state {
        case .idle:
            EmptyView()
        case let .generating(step, stepCount):
            HStack {
                ProgressView()
                Text(step == 0 ? "Loading model…" : "Step \(step) of \(stepCount)")
            }
        case let .finished(_, seed):
            Text("Seed \(seed, format: .number.grouping(.never))")
                .foregroundStyle(.secondary)
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    StableDiffusionPromptView { _ in
    }
}
