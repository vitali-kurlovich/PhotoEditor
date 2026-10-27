//
//  Created by Kurlovich Vitali on 10/27/26.
//

import AVKit
import SwiftUI

struct VideoPreview: View {
    enum State {
        case ready
        case progress(String)
    }

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer

    @State private var ratio: CGFloat = 16.0 / 9.0

    @State private var state: State = .ready

    private let url: URL

    init(url: URL) {
        self.url = url
        player = AVPlayer(url: url)
    }

    var body: some View {
        NavigationStack {
            VideoPlayer(player: player)
                .aspectRatio(ratio, contentMode: .fit)
                .task { ratio = await Self.aspectRatio(of: url) ?? 16 / 9 }
                .overlay {
                    switch state {
                    case .ready:
                        EmptyView()
                    case let .progress(string):
                        PhotoProgressView(description: string)
                    }
                }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save Video", systemImage: "square.and.arrow.up") {
                    Task {
                        state = .progress("Saving video into Photo Library")
                        defer {
                            state = .ready
                        }
                        let task = Task {
                            try await PhotoLibraryManager.shared.saveVideoToPhotos(url)
                        }
                        do {
                            try await task.value
                        } catch {
                            // TODO: Check error
                        }
                        dismiss()
                    }
                }
            }

            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    static func aspectRatio(of url: URL) async -> CGFloat? {
        let asset = AVURLAsset(url: url)
        guard let track = try? await asset.loadTracks(withMediaType: .video).first,
              let (size, transform) = try? await track.load(.naturalSize, .preferredTransform)
        else { return nil }
        let r = CGRect(origin: .zero, size: size).applying(transform)
        return abs(r.width) / abs(r.height)
    }
}
