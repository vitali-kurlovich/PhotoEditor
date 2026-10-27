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
    case pngRepresentationFailed
    case importFailed
    case fileDoNotExists

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Photo library access was denied. Enable it in Settings to save photos."
        case let .saveFailed(error):
            return "Couldn't save the photo: \(error.localizedDescription)"
        case .importFailed:
            return "Couldn't load the photo"
        case .pngRepresentationFailed:
            return "Couldn't make png representation"
        case .fileDoNotExists:
            return "File do not exists"
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
            let context = await MetalContextManager.shared.ciContext
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            let data = context.pngRepresentation(
                of: image,
                format: .RGBA8,
                colorSpace: colorSpace
            )

            guard let data else {
                throw PhotoLibraryError.pngRepresentationFailed
            }

            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }

        } catch {
            throw PhotoLibraryError.saveFailed(error)
        }
    }

    func saveVideoToPhotos(_ url: URL) async throws {
        guard FileManager.default
            .fileExists(atPath: url.path)
        else {
            throw PhotoLibraryError.fileDoNotExists
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw PhotoLibraryError.permissionDenied }

        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = false // true moves the file instead of copying it
            request.addResource(with: .video, fileURL: url, options: options)
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
