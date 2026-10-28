import CoreGraphics
import Foundation
import Observation

@Observable
final class StableDiffusionViewModel {
    enum State {
        case idle
        case generating(step: Int, stepCount: Int)
        case finished(CGImage, seed: UInt32)
        case failed(String)
    }

    var prompt: String = ""
    var negativePrompt: String = ""
    var stepCount: Double = 20
    var guidanceScale: Double = 7

    private(set) var state: State = .idle

    private let generator = SDXLGenerator()
    private var generationTask: Task<Void, Never>?

    var isGenerating: Bool {
        generationTask != nil
    }

    var image: CGImage? {
        if case let .finished(image, _) = state {
            return image
        }
        return nil
    }
}

extension StableDiffusionViewModel {
    func generate(resourcesAt url: URL) {
        guard generationTask == nil else { return }

        let request = SDXLGenerator.Request(
            prompt: prompt,
            negativePrompt: negativePrompt,
            stepCount: Int(stepCount),
            guidanceScale: Float(guidanceScale)
        )

        state = .generating(step: 0, stepCount: request.stepCount)

        generationTask = Task {
            defer { generationTask = nil }
            do {
                let image = try await generator.generate(request, resourcesAt: url) { [weak self] step, stepCount in
                    Task { @MainActor in
                        guard let self, self.isGenerating else { return }
                        self.state = .generating(step: step, stepCount: stepCount)
                    }
                }
                state = .finished(image, seed: request.seed)
            } catch is CancellationError {
                state = .idle
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        generationTask?.cancel()
    }

    func unload() async {
        cancel()
        await generator.unload()
    }
}
