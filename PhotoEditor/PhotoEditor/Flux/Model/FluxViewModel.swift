import Foundation
import Observation

@Observable
final class FluxViewModel {
    enum State {
        case idle
        case queued(position: Int?)
        case running
        case finished(Data, seed: UInt32)
        case failed(String)
    }

    var model: FluxModel = .schnell {
        didSet {
            stepCount = model.defaultStepCount
            guidanceScale = model.defaultGuidanceScale
        }
    }

    var prompt: String = ""
    var width: Double = 1024
    var height: Double = 1024
    var stepCount: Double = FluxModel.schnell.defaultStepCount
    var guidanceScale: Double = FluxModel.schnell.defaultGuidanceScale

    private(set) var state: State = .idle

    private var generationTask: Task<Void, Never>?

    var isGenerating: Bool {
        generationTask != nil
    }

    var imageData: Data? {
        if case let .finished(data, _) = state {
            return data
        }
        return nil
    }
}

extension FluxViewModel {
    func generate(token: String) {
        guard generationTask == nil else { return }

        let request = FluxClient.Request(
            model: model,
            prompt: prompt,
            width: Int(width),
            height: Int(height),
            stepCount: Int(stepCount),
            guidanceScale: guidanceScale
        )
        let client = FluxClient(token: token)

        state = .queued(position: nil)

        generationTask = Task {
            defer { generationTask = nil }
            do {
                let result = try await client.generate(request) { status in
                    Task { @MainActor in
                        guard self.isGenerating else { return }
                        switch status {
                        case let .queued(position):
                            self.state = .queued(position: position)
                        case .running:
                            self.state = .running
                        }
                    }
                }
                state = .finished(result.imageData, seed: result.seed)
            } catch is CancellationError {
                state = .idle
            } catch let error as URLError where error.code == .cancelled {
                state = .idle
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        generationTask?.cancel()
    }
}
