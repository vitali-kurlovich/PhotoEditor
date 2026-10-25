//
//  Created by Kurlovich Vitali on 10/25/26.
//

import CoreImage
import Foundation
import MCP
import Observation

enum MCPClientError: LocalizedError {
    case invalidURL
    case notConnected
    case toolsNotSupported
    case invalidArguments

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Enter a valid http(s) server URL"
        case .notConnected:
            return "Not connected to an MCP server"
        case .toolsNotSupported:
            return "The server doesn't provide tools"
        case .invalidArguments:
            return "Arguments must be a JSON object"
        }
    }
}

@Observable
final class MCPClientManager {
    enum State: Equatable {
        case disconnected
        case connecting
        case connected(serverName: String, serverVersion: String)
        case failed(String)
    }

    static let shared = MCPClientManager()

    private(set) var state: State = .disconnected
    private(set) var tools: [Tool] = []

    @ObservationIgnored private var client: Client?

    private init() {}

    var isConnected: Bool {
        if case .connected = state { return true }
        return false
    }

    func connect(to urlString: String, bearerToken: String? = nil) async {
        await disconnect()

        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            state = .failed(MCPClientError.invalidURL.localizedDescription)
            return
        }

        state = .connecting

        let client = Client(name: "PhotoEditor", version: Self.appVersion)
        let transport = HTTPClientTransport(
            endpoint: url,
            streaming: true,
            requestModifier: Self.authorization(bearerToken)
        )

        do {
            let result = try await client.connect(transport: transport)
            self.client = client
            state = .connected(serverName: result.serverInfo.name, serverVersion: result.serverInfo.version)

            if result.capabilities.tools != nil {
                try await refreshTools()
            }
        } catch {
            await client.disconnect()
            state = .failed(error.localizedDescription)
        }
    }

    func disconnect() async {
        if let client {
            await client.disconnect()
        }
        client = nil
        tools = []
        state = .disconnected
    }

    func refreshTools() async throws {
        guard let client else { throw MCPClientError.notConnected }

        var all: [Tool] = []
        var cursor: String?
        repeat {
            let page = try await client.listTools(cursor: cursor)
            all += page.tools
            cursor = page.nextCursor
        } while cursor != nil

        tools = all
    }

    /// Calls a tool with arguments given as a JSON object string.
    func callTool(_ name: String, argumentsJSON: String) async throws -> MCPToolResult {
        guard let client else { throw MCPClientError.notConnected }

        let arguments = try Self.decodeArguments(argumentsJSON)
        let result = try await client.callTool(name: name, arguments: arguments)

        return MCPToolResult(content: result.content, isError: result.isError ?? false)
    }

    private static func decodeArguments(_ json: String) throws -> [String: Value]? {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        do {
            return try JSONDecoder().decode([String: Value].self, from: Data(trimmed.utf8))
        } catch {
            throw MCPClientError.invalidArguments
        }
    }

    private nonisolated static func authorization(_ token: String?) -> @Sendable (URLRequest) -> URLRequest {
        guard let token, !token.isEmpty else { return { $0 } }

        return { request in
            var request = request
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            return request
        }
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }
}

struct MCPToolResult {
    let content: [Tool.Content]
    let isError: Bool

    /// Text parts of the result joined by new lines.
    var text: String {
        content.compactMap { item in
            switch item {
            case let .text(text, _, _):
                return text
            case let .resource(resource, _, _):
                return resource.text ?? resource.uri
            case let .resourceLink(uri, name, _, _, _, _):
                return "\(name): \(uri)"
            case .image, .audio:
                return nil
            }
        }.joined(separator: "\n")
    }

    /// A displayable piece of the result, in the order the tool returned it.
    enum Item {
        case text(String)
        /// Image data embedded in the result.
        case imageData(Data)
        /// Link to an image, e.g. a Gradio file URL from a Hugging Face Space.
        case imageURL(URL)
        case link(name: String, url: URL)
        /// Content the app can't show, such as audio.
        case note(String)
    }

    var items: [Item] {
        content.flatMap { item -> [Item] in
            switch item {
            case let .text(text, _, _):
                return [.text(text)] + Self.links(in: text).filter(Self.hasImageExtension).map(Item.imageURL)

            case let .image(base64, mimeType, _, _):
                guard let data = Data(base64Encoded: base64) else { return [.note("Unreadable \(mimeType) image")] }
                return [.imageData(data)]

            case let .audio(_, mimeType, _, _):
                return [.note("Audio (\(mimeType)) isn't supported")]

            case let .resource(resource, _, _):
                if resource.mimeType?.hasPrefix("image/") == true,
                   let blob = resource.blob, let data = Data(base64Encoded: blob)
                {
                    return [.imageData(data)]
                }
                return [.text(resource.text ?? resource.uri)]

            case let .resourceLink(uri, name, _, _, mimeType, _):
                guard let url = URL(string: uri) else { return [.text("\(name): \(uri)")] }
                let isImage = mimeType.map { $0.hasPrefix("image/") } ?? Self.hasImageExtension(url)
                return isImage ? [.imageURL(url)] : [.link(name: name, url: url)]
            }
        }
    }

    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "webp", "heic", "gif", "tif", "tiff"]

    private static func hasImageExtension(_ url: URL) -> Bool {
        imageExtensions.contains(url.pathExtension.lowercased())
    }

    private static func links(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }

        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap(\.url)
    }
}

extension MCPClientManager {
    /// Downloads an image a tool returned as a link.
    func loadImage(from url: URL) async throws -> CIImage {
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let image = CIImage(data: data) else {
            throw URLError(.cannotDecodeContentData)
        }
        return image
    }
}
