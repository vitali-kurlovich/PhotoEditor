
import Observation
import PhotosUI
import SwiftUI

@Observable
final class PhotoViewModel {
    enum PhotoViewModelError: Error {
        case noImage
        case noPhotosPickerItem
    }

    enum State: Hashable {
        case loading(String)
        case ready
    }

    var selectedItem: PhotosPickerItem? {
        didSet {
            Task {
                await invalidatePhotosPickerItem()
            }
        }
    }

    var selectedImage: CIImage?
    var filter: FilterType = .sepia

    private(set) var state: State = .ready

    private(set) var videoURL: URL?
}

extension PhotoViewModel {
    func generateVideo() async throws -> URL {
        state = .loading("Generate video")

        defer {
            state = .ready
        }

        guard let selectedImage else {
            throw PhotoViewModelError.noImage
        }

        let task = Task {
            let generator = VideoGenerator(
                inputImage: selectedImage,
                filter: filter,
                duration: 3
            )

            let ext = "mp4"
            let fileName = UUID().uuidString
            let outputUrl = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)
                .appendingPathExtension(ext)

            try await generator.export(to: outputUrl)
            videoURL = outputUrl
            return outputUrl
        }

        return try await task.value
    }

    func saveImageToPhotoLibrary() async throws {
        guard let selectedImage else { return }

        defer {
            state = .ready
        }

        state = .loading("Save image to Photo Library")

        let task = Task {
            let image = filter.apply(to: selectedImage)

            try await PhotoLibraryManager.shared.save(image: image)
        }

        try await task.value
    }
}

extension PhotoViewModel {
    private func invalidatePhotosPickerItem() async {
        guard let newItem = selectedItem else { return }

        MetalContextManager.shared.clearCaches()

        state = .loading("Load image from Photo Library")

        defer {
            state = .ready
        }

        let task = Task {
            do {
                selectedImage = try await PhotoLibraryManager.shared.load(newItem)

            } catch {
                print(error)
            }
        }
        await task.value
    }
}
