//
//  Created by Kurlovich Vitali on 10/25/26.
//

import CoreImage
import SwiftUI

/// One call of a tool and its response.
@Observable
final class MCPToolRun: Identifiable {
    enum Item: Identifiable {
        case text(id: Int, String)
        case image(id: Int, MCPImageItem)
        case link(id: Int, name: String, url: URL)
        case note(id: Int, String)

        var id: Int {
            switch self {
            case let .text(id, _), let .image(id, _), let .link(id, _, _), let .note(id, _):
                return id
            }
        }
    }

    let id = UUID()
    let date: Date
    let duration: Duration
    let argumentsJSON: String
    let isError: Bool
    let items: [Item]

    init(result: MCPToolResult, argumentsJSON: String, date: Date, duration: Duration) {
        self.date = date
        self.duration = duration
        self.argumentsJSON = argumentsJSON
        isError = result.isError

        items = result.items.enumerated().map { index, item in
            switch item {
            case let .text(text):
                return .text(id: index, text)
            case let .imageData(data):
                return .image(id: index, MCPImageItem(data: data))
            case let .imageURL(url):
                return .image(id: index, MCPImageItem(url: url))
            case let .link(name, url):
                return .link(id: index, name: name, url: url)
            case let .note(note):
                return .note(id: index, note)
            }
        }
    }

    /// All text parts of the response.
    var text: String {
        items.compactMap { item in
            if case let .text(_, text) = item { return text }
            return nil
        }.joined(separator: "\n")
    }
}

/// An image from a tool response, decoded from embedded data or downloaded from a link.
@Observable
final class MCPImageItem {
    enum State {
        case loading
        case loaded(CIImage, CGImage)
        case failed(String)
    }

    let url: URL?
    private(set) var state: State = .loading

    init(data: Data) {
        url = nil
        state = Self.decode(data)
    }

    init(url: URL) {
        self.url = url
        Task { await load() }
    }

    func load() async {
        guard let url else { return }
        state = .loading

        do {
            let image = try await MCPClientManager.shared.loadImage(from: url)
            state = Self.render(image)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private static func decode(_ data: Data) -> State {
        guard let image = CIImage(data: data) else { return .failed("Unsupported image format") }
        return render(image)
    }

    private static func render(_ image: CIImage) -> State {
        guard let cgImage = MetalContextManager.shared.ciContext.createCGImage(image, from: image.extent) else {
            return .failed("Couldn't render image")
        }
        return .loaded(image, cgImage)
    }
}

struct MCPToolRunView: View {
    let run: MCPToolRun
    var onImage: (CIImage) -> Void
    /// Puts this run's arguments back into the editor.
    var onReuseArguments: (String) -> Void

    @State private var showArguments: Bool = false

    var body: some View {
        Section {
            ForEach(run.items) { item in
                switch item {
                case let .text(_, text):
                    MCPTextBlock(text: text, isError: run.isError)
                case let .image(_, image):
                    MCPImageCard(item: image, onImage: onImage)
                case let .link(_, name, url):
                    Link(destination: url) {
                        Label(name, systemImage: "link")
                    }
                case let .note(_, note):
                    Label(note, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }

            if run.items.isEmpty {
                Text("Empty response")
                    .foregroundStyle(.secondary)
            }

            DisclosureGroup("Arguments", isExpanded: $showArguments) {
                Text(run.argumentsJSON.isEmpty ? "{}" : run.argumentsJSON)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)

                Button("Use These Arguments", systemImage: "arrow.uturn.backward") {
                    onReuseArguments(run.argumentsJSON)
                }
                .buttonStyle(.borderless)
            }
        } header: {
            HStack {
                Label(run.isError ? "Tool error" : "Result",
                      systemImage: run.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(run.isError ? .red : .green)
                Spacer()
                Text(run.date, style: .time)
                Text(run.duration.formatted(.units(allowed: [.seconds, .milliseconds], width: .narrow, maximumUnitCount: 1)))
            }
        }
    }
}

private struct MCPTextBlock: View {
    let text: String
    let isError: Bool

    @State private var copied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Self.linkified(text))
                .font(.callout.monospaced())
                .foregroundStyle(isError ? .red : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc") {
                    Pasteboard.copy(text)
                    copied = true
                }
                ShareLink(item: text)
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
    }

    /// Makes URLs in the text tappable.
    private static func linkified(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return attributed
        }

        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let url = match.url,
                  let range = Range(match.range, in: text),
                  let lower = AttributedString.Index(range.lowerBound, within: attributed),
                  let upper = AttributedString.Index(range.upperBound, within: attributed)
            else { continue }

            attributed[lower ..< upper].link = url
        }
        return attributed
    }
}

private struct MCPImageCard: View {
    let item: MCPImageItem
    var onImage: (CIImage) -> Void

    @State private var showViewer: Bool = false
    @State private var saveState: SaveState = .idle

    enum SaveState: Equatable {
        case idle, saving, saved
        case failed(String)
    }

    var body: some View {
        switch item.state {
        case .loading:
            HStack {
                ProgressView()
                Text(item.url?.lastPathComponent ?? "Loading image…")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

        case let .failed(message):
            VStack(alignment: .leading, spacing: 8) {
                Label("Couldn't load image: \(message)", systemImage: "photo.badge.exclamationmark")
                    .foregroundStyle(.red)
                if item.url != nil {
                    Button("Retry", systemImage: "arrow.clockwise") {
                        Task { await item.load() }
                    }
                    .buttonStyle(.borderless)
                }
            }

        case let .loaded(image, cgImage):
            VStack(alignment: .leading, spacing: 8) {
                Image(decorative: cgImage, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 320)
                    .clipShape(.rect(cornerRadius: 8))
                    .contentShape(.rect)
                    .onTapGesture { showViewer = true }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Show image full screen")

                Text("\(cgImage.width) × \(cgImage.height)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                actions(image: image, cgImage: cgImage)
            }
            .imageViewer(isPresented: $showViewer, cgImage: cgImage)
        }
    }

    private func actions(image: CIImage, cgImage: CGImage) -> some View {
        HStack(spacing: 16) {
            Button("Edit", systemImage: "camera.filters") {
                onImage(image)
            }

            Button(action: { save(image) }) {
                switch saveState {
                case .idle:
                    Label("Save", systemImage: "square.and.arrow.down")
                case .saving:
                    ProgressView()
                case .saved:
                    Label("Saved", systemImage: "checkmark")
                case .failed:
                    Label("Retry Save", systemImage: "exclamationmark.triangle")
                }
            }
            .disabled(saveState == .saving || saveState == .saved)

            let preview = Image(decorative: cgImage, scale: 1)
            ShareLink(item: preview, preview: SharePreview("Image", image: preview))
        }
        .buttonStyle(.borderless)
        .font(.callout)
    }

    private func save(_ image: CIImage) {
        saveState = .saving
        Task {
            do {
                try await PhotoLibraryManager.shared.save(image: image)
                saveState = .saved
            } catch {
                saveState = .failed(error.localizedDescription)
            }
        }
    }
}

/// Full-screen image with pinch zoom, pan, and double-tap zoom.
private struct MCPImageViewer: View {
    let cgImage: CGImage

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero

    var body: some View {
        NavigationStack {
            Image(decorative: cgImage, scale: 1)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale * pinch)
                .offset(x: offset.width + drag.width, y: offset.height + drag.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
                .gesture(magnify.simultaneously(with: pan))
                .onTapGesture(count: 2) {
                    withAnimation {
                        scale = scale > 1 ? 1 : 3
                        offset = .zero
                    }
                }
                .clipped()
                .background(.black)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in
                scale = min(max(scale * value.magnification, 1), 8)
                if scale == 1 { offset = .zero }
            }
    }

    private var pan: some Gesture {
        DragGesture()
            .updating($drag) { value, state, _ in
                if scale > 1 { state = value.translation }
            }
            .onEnded { value in
                guard scale > 1 else { return }
                offset.width += value.translation.width
                offset.height += value.translation.height
            }
    }
}

private extension View {
    @ViewBuilder
    func imageViewer(isPresented: Binding<Bool>, cgImage: CGImage) -> some View {
        #if os(iOS)
            fullScreenCover(isPresented: isPresented) { MCPImageViewer(cgImage: cgImage) }
        #else
            sheet(isPresented: isPresented) {
                MCPImageViewer(cgImage: cgImage)
                    .frame(minWidth: 600, minHeight: 500)
            }
        #endif
    }
}

private enum Pasteboard {
    static func copy(_ text: String) {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        #else
            UIPasteboard.general.string = text
        #endif
    }
}
