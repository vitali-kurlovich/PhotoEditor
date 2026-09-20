//
//  Created by Kurlovich Vitali on 9/20/26.
//

import Foundation
import Observation

@Observable
final class ProgressObservation: NSObject {
    private let progress: Progress

    private(set) var progressValue: Float
    private(set) var isFinished: Bool
    private(set) var isCancelled: Bool
    private(set) var isPaused: Bool
    private(set) var localizedDescription: String
    private(set) var localizedAdditionalDescription: String

    private var fractionCompletedObservation: NSKeyValueObservation?

    private var isFinishedObservation: NSKeyValueObservation?
    private var isCancelledObservation: NSKeyValueObservation?
    private var isPausedObservation: NSKeyValueObservation?
    private var localizedDescriptionObservation: NSKeyValueObservation?
    private var localizedAdditionalDescriptionObservation: NSKeyValueObservation?

    init(progress: Progress) {
        self.progress = progress

        progressValue = Float(progress.fractionCompleted)
        isFinished = progress.isFinished
        isCancelled = progress.isCancelled
        isPaused = progress.isPaused
        localizedDescription = progress.localizedDescription
        localizedAdditionalDescription = progress.localizedAdditionalDescription
        super.init()

        prepareObservation()
    }
}

private extension ProgressObservation {
    func prepareObservation() {
        fractionCompletedObservation = progress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] object, _ in
            self?.progressValue = Float(object.fractionCompleted)
        }

        isFinishedObservation = progress.observe(\.isFinished, options: [.initial, .new]) { [weak self] object, _ in
            self?.isFinished = object.isFinished
        }

        isCancelledObservation = progress.observe(\.isCancelled, options: [.initial, .new]) { [weak self] object, _ in
            self?.isCancelled = object.isCancelled
        }

        isPausedObservation = progress.observe(\.isPaused, options: [.initial, .new]) { [weak self] object, _ in
            self?.isPaused = object.isPaused
        }

        localizedDescriptionObservation = progress.observe(\.localizedDescription, options: [.initial, .new]) { [weak self] object, _ in
            self?.localizedDescription = object.localizedDescription
        }

        localizedAdditionalDescriptionObservation = progress.observe(\.localizedAdditionalDescription, options: [.initial, .new]) { [weak self] object, _ in
            self?.localizedAdditionalDescription = object.localizedAdditionalDescription
        }
    }
}
