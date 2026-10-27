
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
            invalidatePhotosPickerItem()
        }
    }

    var selectedImage: CIImage?
    var filter: FilterType = .sepia

    private(set) var state: State = .ready

    private func invalidatePhotosPickerItem() {
        guard let newItem = selectedItem else { return }

        MetalContextManager.shared.clearCaches()

        Task {
            state = .loading("Load image from Photo Library")
            do {
                selectedImage = try await PhotoLibraryManager.shared.load(newItem)

            } catch {
                print(error)
            }
            state = .ready
        }
    }

    func generateVideo() async throws -> URL {
        guard let selectedImage else {
            throw PhotoViewModelError.noImage
        }

        state = .loading("Generate video")

        let generator = VideoGenerator(inputImage: selectedImage, filter: filter)
        let ext = "mp4"
        let fileName = UUID().uuidString
        let outputUrl = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension(ext)

        try await generator.export(to: outputUrl)

        state = .ready

        return outputUrl

        // state = .loading("Save video to Photo Library")
        // try await PhotoLibraryManager.shared.saveVideoToPhotos(outputUrl)
    }

    func saveImageToPhotoLibrary() async throws {
        guard let selectedImage else { return }

        state = .loading("Save image to Photo Library")

        let image = filter.apply(to: selectedImage)

        try await PhotoLibraryManager.shared.save(image: image)

        state = .ready
    }
}
