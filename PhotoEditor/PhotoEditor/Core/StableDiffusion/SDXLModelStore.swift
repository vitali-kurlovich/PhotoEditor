import Foundation
import Observation

/// Downloads the Core ML SDXL model from Hugging Face and keeps it in Application Support.
@Observable
final class SDXLModelStore {
    static let shared = SDXLModelStore()

    enum State {
        case notDownloaded
        case downloading(Progress)
        case ready(URL)
        case failed(String)
    }

    enum StoreError: LocalizedError {
        case badResponse(String)

        var errorDescription: String? {
            switch self {
            case let .badResponse(path):
                "Failed to download \(path)"
            }
        }
    }

    /// 4-bit palettized SDXL base, 768×768, SPLIT_EINSUM attention for iOS 17+.
    static let repository = "apple/coreml-stable-diffusion-xl-base-ios"
    static let folder = "coreml-stable-diffusion-xl-base-ios_split_einsum_compiled"

    private(set) var state: State = .notDownloaded

    private var downloadTask: Task<Void, Never>?

    let modelURL: URL

    private var completeMarkerURL: URL {
        modelURL.appending(path: ".complete")
    }

    init() {
        let support = URL.applicationSupportDirectory.appending(path: "StableDiffusion", directoryHint: .isDirectory)
        modelURL = support.appending(path: Self.folder, directoryHint: .isDirectory)

        if FileManager.default.fileExists(atPath: completeMarkerURL.path) {
            state = .ready(modelURL)
        }
    }
}

extension SDXLModelStore {
    var isReady: Bool {
        if case .ready = state {
            return true
        }
        return false
    }

    var isDownloading: Bool {
        if case .downloading = state {
            return true
        }
        return false
    }

    func download() {
        guard downloadTask == nil, !isReady else { return }

        let progress = Progress(totalUnitCount: 0)
        progress.kind = .file
        progress.fileOperationKind = .downloading
        state = .downloading(progress)

        downloadTask = Task {
            defer { downloadTask = nil }
            do {
                try await performDownload(progress: progress)
                state = .ready(modelURL)
            } catch is CancellationError {
                state = .notDownloaded
            } catch let error as URLError where error.code == .cancelled {
                state = .notDownloaded
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
    }

    func delete() throws {
        cancelDownload()
        if FileManager.default.fileExists(atPath: modelURL.path) {
            try FileManager.default.removeItem(at: modelURL)
        }
        state = .notDownloaded
    }
}

private extension SDXLModelStore {
    nonisolated struct RemoteFile: Decodable, Sendable {
        let type: String
        let path: String
        let size: Int64
    }

    func performDownload(progress: Progress) async throws {
        let files = try await Self.fetchFileList()
        progress.totalUnitCount = files.reduce(0) { $0 + $1.size }

        let fileManager = FileManager.default
        try fileManager.createDirectory(at: modelURL, withIntermediateDirectories: true)

        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var rootURL = modelURL.deletingLastPathComponent()
        try? rootURL.setResourceValues(resourceValues)

        for file in files {
            try Task.checkCancellation()

            let relativePath = String(file.path.dropFirst(Self.folder.count + 1))
            let destination = modelURL.appending(path: relativePath)

            // Resume: skip files that are already complete
            if let size = try? fileManager.attributesOfItem(atPath: destination.path)[.size] as? Int64, size == file.size {
                progress.completedUnitCount += file.size
                continue
            }

            let delegate = ChildProgressDelegate(parent: progress, pendingUnitCount: file.size)
            let (tempURL, response) = try await URLSession.shared.download(from: Self.resolveURL(for: file.path), delegate: delegate)

            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw StoreError.badResponse(file.path)
            }

            try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: tempURL, to: destination)
        }

        fileManager.createFile(atPath: completeMarkerURL.path, contents: nil)
    }

    static func fetchFileList() async throws -> [RemoteFile] {
        let url = URL(string: "https://huggingface.co/api/models/\(repository)/tree/main/\(folder)?recursive=true")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw StoreError.badResponse(url.absoluteString)
        }

        return try JSONDecoder()
            .decode([RemoteFile].self, from: data)
            .filter { $0.type == "file" }
    }

    static func resolveURL(for path: String) -> URL {
        URL(string: "https://huggingface.co/\(repository)/resolve/main/")!
            .appending(path: path)
    }
}

/// Attaches each download task's progress to the overall model progress.
private final nonisolated class ChildProgressDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    let parent: Progress
    let pendingUnitCount: Int64

    init(parent: Progress, pendingUnitCount: Int64) {
        self.parent = parent
        self.pendingUnitCount = pendingUnitCount
    }

    func urlSession(_: URLSession, didCreateTask task: URLSessionTask) {
        parent.addChild(task.progress, withPendingUnitCount: pendingUnitCount)
    }
}
