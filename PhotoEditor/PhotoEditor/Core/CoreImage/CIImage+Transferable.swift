//
//  Created by Kurlovich Vitali on 9/20/26.
//

import CoreImage
import CoreTransferable

internal import UniformTypeIdentifiers

#if canImport(UIKit)
    import UIKit

#endif
#if canImport(AppKit)
    import AppKit
#endif

enum TransferError: Error {
    case importFailed
}

extension CIImage: @retroactive Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
            let transform: CGAffineTransform

            #if os(iOS) || os(tvOS)
                guard let image = UIImage(data: data), let cgImage = image.cgImage else {
                    throw TransferError.importFailed
                }

                let orientation = image.imageOrientation
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

            #elseif os(macOS)
                guard let image = NSImage(data: data), let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    throw TransferError.importFailed
                }

                transform = .identity

            #endif

            return CIImage(
                cgImage: cgImage
            ).transformed(by: transform)
        }
    }
}
