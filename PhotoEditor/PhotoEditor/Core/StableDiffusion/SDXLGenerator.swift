import CoreGraphics
import CoreML
import StableDiffusion

/// Runs the Core ML SDXL pipeline off the main actor.
actor SDXLGenerator {
    nonisolated struct Request: Sendable {
        var prompt: String
        var negativePrompt: String = ""
        var stepCount: Int = 20
        var guidanceScale: Float = 7
        var seed: UInt32 = .random(in: 0 ... .max)
    }

    enum GeneratorError: LocalizedError {
        case noImage

        var errorDescription: String? {
            "The pipeline did not return an image."
        }
    }

    private var pipeline: StableDiffusionXLPipeline?
    private var resourcesURL: URL?

    func generate(
        _ request: Request,
        resourcesAt url: URL,
        onStep: @Sendable (_ step: Int, _ stepCount: Int) -> Void
    ) throws -> CGImage {
        let pipeline = try loadPipeline(resourcesAt: url)

        var config = StableDiffusionXLPipeline.Configuration(prompt: request.prompt)
        config.negativePrompt = request.negativePrompt
        config.stepCount = request.stepCount
        config.guidanceScale = request.guidanceScale
        config.seed = request.seed
        config.schedulerType = .dpmSolverMultistepScheduler
        // SDXL VAE scaling factor
        config.encoderScaleFactor = 0.13025
        config.decoderScaleFactor = 0.13025

        let images = try pipeline.generateImages(configuration: config) { progress in
            onStep(progress.step + 1, progress.stepCount)
            return !Task.isCancelled
        }

        try Task.checkCancellation()

        guard let image = images.first ?? nil else {
            throw GeneratorError.noImage
        }
        return image
    }

    func unload() {
        pipeline?.unloadResources()
        pipeline = nil
        resourcesURL = nil
    }

    private func loadPipeline(resourcesAt url: URL) throws -> StableDiffusionXLPipeline {
        if let pipeline, resourcesURL == url {
            return pipeline
        }

        let configuration = MLModelConfiguration()
        // The iOS model uses SPLIT_EINSUM attention, which is tuned for the Neural Engine
        configuration.computeUnits = .cpuAndNeuralEngine

        #if os(iOS)
            let reduceMemory = true
        #else
            let reduceMemory = false
        #endif

        let pipeline = try StableDiffusionXLPipeline(
            resourcesAt: url,
            configuration: configuration,
            reduceMemory: reduceMemory
        )
        try pipeline.loadResources()

        self.pipeline = pipeline
        resourcesURL = url
        return pipeline
    }
}
