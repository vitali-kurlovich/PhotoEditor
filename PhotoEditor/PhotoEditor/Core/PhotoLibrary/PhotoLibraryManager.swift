//
//  Created by Kurlovich Vitali on 9/17/26.
//

import CoreImage
import Photos
import PhotosUI
import SwiftUI

enum PhotoLibraryError: LocalizedError {
    case permissionDenied
    case saveFailed(Error)
    case importFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Photo library access was denied. Enable it in Settings to save photos."
        case let .saveFailed(error):
            return "Couldn't save the photo: \(error.localizedDescription)"
        case .importFailed:
            return "Couldn't load the photo"
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

    func load(_ item: PhotosPickerItem) async throws -> CIImage {
        #if os(iOS) || os(tvOS)

            do {
                guard let data = try await item
                    .loadTransferable(type: Data.self)
                else {
                    throw PhotoLibraryError.importFailed
                }

                guard let image = UIImage(data: data) else {
                    throw PhotoLibraryError.importFailed
                }

                guard let cgImage = image.cgImage else {
                    throw PhotoLibraryError.importFailed
                }

                let orientation = image.imageOrientation
                let transform: CGAffineTransform
                switch orientation {
                case .up:
                    transform = .identity
                case .down:
                    transform = .init(scaleX: 1, y: -1)
                case .left:
                    transform = .identity
                case .right:
                    transform = .identity
                case .upMirrored:
                    transform = .identity
                case .downMirrored:
                    transform = .identity
                case .leftMirrored:
                    transform = .identity
                case .rightMirrored:
                    transform = .identity
                @unknown default:
                    transform = .identity
                }

                return CIImage(cgImage: cgImage).transformed(by: transform)

            } catch {
                throw PhotoLibraryError.importFailed
            }

        #elseif os(macOS)

            do {
                guard let image = try await item
                    .loadTransferable(type: NSImage.self)
                else {
                    throw PhotoLibraryError.importFailed
                }

                guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    throw PhotoLibraryError.importFailed
                }

                return CIImage(cgImage: cgImage)

            } catch {
                throw PhotoLibraryError.importFailed
            }

        #endif
    }
}
