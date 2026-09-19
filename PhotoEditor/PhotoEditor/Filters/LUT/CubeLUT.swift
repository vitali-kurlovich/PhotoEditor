//
//  Created by Kurlovich Vitali on 9/18/26.
//

import CoreImage
import Foundation

public nonisolated struct CubeLUT: Hashable, Sendable {
    public let title: String?
    public let dimension: Int
    public let data: Data
    public let domainMin: SIMD3<Float>
    public let domainMax: SIMD3<Float>

    public init(
        title: String?,
        dimension: Int,
        data: Data,
        domainMin: SIMD3<Float>,
        domainMax: SIMD3<Float>
    ) {
        self.title = title
        self.dimension = dimension
        self.data = data
        self.domainMin = domainMin
        self.domainMax = domainMax
    }
}

public enum CubeLUTError: LocalizedError {
    case IOError(Error)
    case invalidFormat
    case missingSize
    case invalidSize
    case unsupported1DLUT
    case invalidDomain
    case invalidRow(line: Int)
    case incorrectRowCount(expected: Int, actual: Int)

    public var errorDescription: String? {
        switch self {
        case let .IOError(error):
            return "I/O error: \(error.localizedDescription)"
        case .invalidFormat:
            return "Invalid format."
        case .missingSize:
            return "Missing LUT_3D_SIZE."
        case .invalidSize:
            return "Invalid LUT_3D_SIZE."
        case .unsupported1DLUT:
            return "Only 3D LUTs are supported."
        case .invalidDomain:
            return "Invalid DOMAIN_MIN or DOMAIN_MAX."
        case let .invalidRow(line):
            return "Invalid RGB data at line \(line)."
        case let .incorrectRowCount(expected, actual):
            return "Expected \(expected) rows, got \(actual)."
        }
    }
}

public extension CubeLUT {
    init(_ text: String) throws(CubeLUTError) {
        self = try parseCubeLUT(text)
    }

    init(_ data: Data) throws(CubeLUTError) {
        guard let text = String(data: data, encoding: .utf8) else {
            throw CubeLUTError.invalidFormat
        }
        try self.init(text)
    }

    init(_ url: URL) async throws(CubeLUTError) {
        self = try await parseCubeLUT(url.lines)
    }
}

private struct CubeLUTParser: Sendable {
    private var title: String?

    private var dimension: Int?
    private var domainMin = SIMD3<Float>(repeating: 0)
    private var domainMax = SIMD3<Float>(repeating: 1)
    private var rgbValues: [SIMD3<Float>] = []
    private var found3DSize = false
    private var found1DSize = false
    private var lineNumber = 0

    private var isFinalized: Bool = false

    mutating func nextLine<S: StringProtocol>(_ rawLine: S) throws(CubeLUTError) {
        assert(isFinalized == false)

        lineNumber += 1

        let line = rawLine
            .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard line.isEmpty == false else { return }
        guard line != "\n" else { return }

        let parts = line.split {
            $0 == " " || $0 == "\t" || $0 == ","
        }

        guard let keyword = parts.first else { return }

        switch keyword.uppercased() {
        case "TITLE":
            title = parts.dropFirst().joined(separator: " ")

        case "LUT_1D_SIZE":
            found1DSize = true

        case "LUT_3D_SIZE":
            guard parts.count >= 2,
                  let size = Int(parts[1]),
                  size >= 2
            else {
                throw CubeLUTError.invalidSize
            }

            dimension = size
            found3DSize = true

        case "DOMAIN_MIN":
            guard parts.count >= 4,
                  let r = Float(parts[1]),
                  let g = Float(parts[2]),
                  let b = Float(parts[3])
            else {
                throw CubeLUTError.invalidDomain
            }

            domainMin = SIMD3(r, g, b)

        case "DOMAIN_MAX":
            guard parts.count >= 4,
                  let r = Float(parts[1]),
                  let g = Float(parts[2]),
                  let b = Float(parts[3])
            else {
                throw CubeLUTError.invalidDomain
            }

            domainMax = SIMD3(r, g, b)

        default:
            guard parts.count == 3,
                  let r = Float(parts[0]),
                  let g = Float(parts[1]),
                  let b = Float(parts[2])
            else {
                return
            }

            rgbValues.append(SIMD3(r, g, b))
        }
    }

    mutating func finalize() throws(CubeLUTError) -> CubeLUT {
        isFinalized = true

        guard let dimension else {
            throw CubeLUTError.missingSize
        }

        let expectedCount = dimension * dimension * dimension

        guard rgbValues.count == expectedCount else {
            throw CubeLUTError.incorrectRowCount(
                expected: expectedCount,
                actual: rgbValues.count
            )
        }

        var rgbaValues = [Float]()
        rgbaValues.reserveCapacity(expectedCount * 4)

        for rgb in rgbValues {
            rgbaValues.append(rgb.x)
            rgbaValues.append(rgb.y)
            rgbaValues.append(rgb.z)
            rgbaValues.append(1.0)
        }

        let data = rgbaValues.withUnsafeBytes {
            Data($0)
        }

        return CubeLUT(
            title: title,
            dimension: dimension,
            data: data,
            domainMin: domainMin,
            domainMax: domainMax
        )
    }
}

private func parseCubeLUT<S: AsyncSequence>(_ lines: S) async throws(CubeLUTError) -> CubeLUT where S.Element == String {
    var parser = CubeLUTParser()

    do {
        for try await rawLine in lines {
            try parser.nextLine(rawLine)
        }

    } catch let error as CubeLUTError {
        throw error
    } catch {
        throw CubeLUTError.IOError(error)
    }

    return try parser.finalize()
}

private func parseCubeLUT(_ text: String) throws(CubeLUTError) -> CubeLUT {
    var parser = CubeLUTParser()

    let lines = text.components(separatedBy: .newlines)

    for rawLine in lines {
        try parser.nextLine(rawLine)
    }

    return try parser.finalize()
}
