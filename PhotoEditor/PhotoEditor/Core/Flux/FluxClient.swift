import Foundation

/// FLUX models served by fal.ai through Hugging Face Inference Providers.
///
/// FLUX.1 has 12B parameters, so it can't run on an iPhone; generation runs in the cloud
/// and is billed to the Hugging Face account that owns the token.
nonisolated enum FluxModel: String, CaseIterable, Identifiable, Sendable {
    case schnell
    case dev
    case kreaDev

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .schnell: "FLUX.1 [schnell]"
        case .dev: "FLUX.1 [dev]"
        case .kreaDev: "FLUX.1 Krea [dev]"
        }
    }

    var repository: String {
        switch self {
        case .schnell: "black-forest-labs/FLUX.1-schnell"
        case .dev: "black-forest-labs/FLUX.1-dev"
        case .kreaDev: "black-forest-labs/FLUX.1-Krea-dev"
        }
    }

    /// fal.ai application id the Hugging Face router maps the model to.
    var providerID: String {
        switch self {
        case .schnell: "fal-ai/flux/schnell"
        case .dev: "fal-ai/flux/dev"
        case .kreaDev: "fal-ai/flux/krea"
        }
    }

    var stepRange: ClosedRange<Double> {
        switch self {
        case .schnell: 1 ... 12
        case .dev, .kreaDev: 1 ... 50
        }
    }

    var defaultStepCount: Double {
        switch self {
        case .schnell: 4
        case .dev, .kreaDev: 28
        }
    }

    /// schnell is guidance-distilled and ignores the guidance scale.
    var supportsGuidance: Bool {
        self != .schnell
    }

    var defaultGuidanceScale: Double {
        switch self {
        case .schnell: 0
        case .dev: 3.5
        case .kreaDev: 4.5
        }
    }
}

/// Runs FLUX text-to-image requests on the fal.ai queue through `router.huggingface.co`.
nonisolated struct FluxClient: Sendable {
    struct Request: Sendable {
        var model: FluxModel
        var prompt: String
        var width: Int = 1024
        var height: Int = 1024
        var stepCount: Int
        var guidanceScale: Double
        var seed: UInt32 = .random(in: 0 ... .max)
    }

    struct Result: Sendable {
        let imageData: Data
        let seed: UInt32
    }

    enum Status: Sendable {
        case queued(position: Int?)
        case running
    }

    enum ClientError: LocalizedError {
        case missingToken
        case badResponse(status: Int, message: String)
        case noImage

        var errorDescription: String? {
            switch self {
            case .missingToken:
                "Enter a Hugging Face token with the “Make calls to Inference Providers” permission."
            case let .badResponse(status, message):
                message.isEmpty ? "Request failed with HTTP \(status)" : "HTTP \(status): \(message)"
            case .noImage:
                "The provider did not return an image."
            }
        }
    }

    static let routerURL = URL(string: "https://router.huggingface.co/fal-ai")!

    let token: String
    var session: URLSession = .shared

    func generate(_ request: Request, onStatus: @Sendable (Status) -> Void = { _ in }) async throws -> Result {
        guard !token.isEmpty else { throw ClientError.missingToken }

        let submitted: QueueResponse = try await send(
            url: Self.queueURL(path: request.model.providerID),
            method: "POST",
            body: Payload.encoder.encode(Payload(request))
        )

        // The status and result paths come from the response, as fal may redirect the request
        let requestPath = URL(string: submitted.responseURL)?.path() ?? "\(request.model.providerID)/requests/\(submitted.requestID)"

        var status = submitted
        while status.status != "COMPLETED" {
            onStatus(status.status == "IN_PROGRESS" ? .running : .queued(position: status.queuePosition))
            try await Task.sleep(for: .milliseconds(500))
            status = try await send(url: Self.queueURL(path: requestPath + "/status"))
        }

        let output: Output = try await send(url: Self.queueURL(path: requestPath))
        guard let imageURL = output.images.first.flatMap({ URL(string: $0.url) }) else {
            throw ClientError.noImage
        }

        let (data, response) = try await session.data(from: imageURL)
        try Self.validate(response, data: data)

        return Result(imageData: data, seed: output.seed.map(UInt32.init(truncatingIfNeeded:)) ?? request.seed)
    }
}

private nonisolated extension FluxClient {
    struct Payload: Encodable {
        struct ImageSize: Encodable {
            let width: Int
            let height: Int
        }

        let prompt: String
        let imageSize: ImageSize
        let numInferenceSteps: Int
        let guidanceScale: Double?
        let seed: UInt32
        let numImages = 1
        let outputFormat = "png"

        init(_ request: Request) {
            prompt = request.prompt
            imageSize = ImageSize(width: request.width, height: request.height)
            numInferenceSteps = request.stepCount
            guidanceScale = request.model.supportsGuidance ? request.guidanceScale : nil
            seed = request.seed
        }

        static let encoder: JSONEncoder = {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            return encoder
        }()
    }

    struct QueueResponse: Decodable {
        let status: String
        let requestID: String
        let responseURL: String
        let queuePosition: Int?

        enum CodingKeys: String, CodingKey {
            case status
            case requestID = "request_id"
            case responseURL = "response_url"
            case queuePosition = "queue_position"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            status = try container.decode(String.self, forKey: .status)
            // Status polls don't repeat the request id and response url
            requestID = try container.decodeIfPresent(String.self, forKey: .requestID) ?? ""
            responseURL = try container.decodeIfPresent(String.self, forKey: .responseURL) ?? ""
            queuePosition = try container.decodeIfPresent(Int.self, forKey: .queuePosition)
        }
    }

    struct Output: Decodable {
        struct Image: Decodable {
            let url: String
        }

        let images: [Image]
        let seed: Int64?
    }

    struct ErrorBody: Decodable {
        let error: String?
        let detail: String?
    }

    static func queueURL(path: String) -> URL {
        routerURL
            .appending(path: path.hasPrefix("/") ? String(path.dropFirst()) : path)
            .appending(queryItems: [URLQueryItem(name: "_subdomain", value: "queue")])
    }

    func send<Response: Decodable>(url: URL, method: String = "GET", body: Data? = nil) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        try Self.validate(response, data: data)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    static func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) else { return }

        let body = try? JSONDecoder().decode(ErrorBody.self, from: data)
        let message = body?.error ?? body?.detail ?? String(decoding: data.prefix(300), as: UTF8.self)
        throw ClientError.badResponse(status: http.statusCode, message: message)
    }
}
