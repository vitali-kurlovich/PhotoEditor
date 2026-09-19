//
//  Created by Kurlovich Vitali on 9/17/26.
//

import CoreImage
import Photos

enum PhotoLibraryError: LocalizedError {
    case permissionDenied
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Photo library access was denied. Enable it in Settings to save photos."
        case let .saveFailed(error):
            return "Couldn't save the photo: \(error.localizedDescription)"
        }
    }
}

actor PhotoLibraryManager {
    static let shared = PhotoLibraryManager()

    private init() {}

    func save(
        image: CIImage
    ) async throws(PhotoLibraryError) {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)

        guard status == .authorized || status == .limited else {
            throw PhotoLibraryError.permissionDenied
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                _ = PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        } catch {
            throw PhotoLibraryError.saveFailed(error)
        }
    }
}
