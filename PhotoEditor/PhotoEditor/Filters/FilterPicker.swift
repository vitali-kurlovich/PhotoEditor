//
//  Created by Kurlovich Vitali on 9/18/26.
//

import Observation
import SwiftUI

@Observable
final nonisolated class FilterManagerObserver: @unchecked Sendable {
    var state: FilterManager.State = .idle
    var filters: [FilterType] = [
        .none,
        .sepia,
        .mono,
        .noir,
        .chrome,
        .instant,
        .fade,
        .process,
        .transfer,
        .comic,
        .invert,
        .vibrance,
    ]
}

actor FilterManager {
    enum State: Hashable, Sendable {
        case idle
        case loading(Float)
        case ready
    }

    private init() {
        Task {
            await fetch()
        }
    }

    static let shared = FilterManager()

    let observer = FilterManagerObserver()

    private func fetch() async {
        observer.state = .loading(0)

        let urls = LUTBundle.fileURLs

        let count = Float(urls.count)
        var processed: Float = 0

        for url in urls {
            do {
                let cube = try await CubeLUT(url)
                observer.filters.append(.lut(cube))
                processed += 1

                observer.state = .loading(processed / count)
            } catch {}
        }

        observer.state = .ready
    }
}

extension FilterManager {
    var state: State {
        observer.state
    }

    var filters: [FilterType] {
        observer.filters
    }
}

struct FilterPickerLoader: View {
    @State private var observer = FilterManager.shared.observer
    let thumbnail: CIImage?
    @Binding var selectedFilter: FilterType?
    #if os(iOS) || os(tvOS)
        @Environment(\.dismiss) private var dismiss
    #endif
    var body: some View {
        NavigationStack {
            VStack {
                switch observer.state {
                case .idle:
                    EmptyView()

                case let .loading(progress):
                    ProgressView(value: progress)

                    FilterPicker(
                        observer: $observer,
                        thumbnail: thumbnail,
                        selectedFilter: $selectedFilter
                    )

                case .ready:
                    FilterPicker(observer: $observer, thumbnail: thumbnail, selectedFilter: $selectedFilter)
                }
                Spacer()
            }.navigationTitle("Filters")
            #if os(iOS) || os(tvOS)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        if #available(iOS 26.0, *) {
                            Button(role: .cancel) {
                                dismiss()
                            }
                        } else {
                            // Fallback on earlier versions
                        }
                    }
                }.onChange(of: selectedFilter) { _, _ in
                    dismiss()
                }
            #endif
        }
    }
}

struct FilterPicker: View {
    @Binding
    var observer: FilterManagerObserver
    let thumbnail: CIImage?

    @Binding var selectedFilter: FilterType?

    @Environment(\.dismiss) private var dismiss
    private let filterInfo = FilterTypeInfo()

    var filters: [FilterType] {
        observer.filters
    }

    var body: some View {
        List(selection: $selectedFilter) {
            ForEach(filters) { filter in
                FilterPickerItem(filter: filter, thumbnail: thumbnail)
            }
        }
    }
}

struct FilterPickerItem: View {
    let filter: FilterType
    let thumbnail: CIImage?
    private let filterInfo = FilterTypeInfo()
    var body: some View {
        HStack {
            CIImageView(
                image: thumbnail,
                configuration: .filtered(filter: filter, displayMode: .fill)
            )
            .frame(width: 100, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 12)

            Text(filterInfo.displayName(for: filter))
            Spacer()
        }
    }
}

#Preview {
    @Previewable
    @State var selectedFilter: FilterType? = FilterType.none

    @Previewable
    @State var showFilterPicker = false

    //  NavigationStack {
    Button("Filters") {
        showFilterPicker.toggle()
    }.sheet(isPresented: $showFilterPicker) {
        FilterPickerLoader(thumbnail: nil, selectedFilter: $selectedFilter)
    }

    //
    // }
}
