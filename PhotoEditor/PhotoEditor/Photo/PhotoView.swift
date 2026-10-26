//
//  Created by Kurlovich Vitali on 9/18/26.
//

import CoreImage
import PhotosUI
import SwiftUI

struct PhotoView: View {
    enum State: Hashable {
        case idle
        case loading
        case ready
    }

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: CIImage? = nil

    @State private var filter: FilterType = .sepia

    @State private var showFilterPicker: Bool = false
    @State private var showPhotosPicker: Bool = false
    @State private var showMCPServer: Bool = false
    @State private var viewMode: ViewMode = .divided

    @State private var state: State = .idle

    typealias ViewMode = CIImageView.Configuration.Mode

    var body: some View {
        ZStack {
            ImageEditorView(filter: filter, editedImage: selectedImage, viewMode: viewMode)
                .ignoresSafeArea()
                .overlay(alignment: .center) {
                    switch state {
                    case .idle:
                        EmptyView()
                    case .loading:
                        ProgressView()
                    case .ready:
                        EmptyView()
                    }
                }

            #if os(iOS) || os(tvOS)
                .sheet(isPresented: $showFilterPicker) {
                    FilterPickerLoader(
                        thumbnail: selectedImage,
                        selectedFilter: .init(get: {
                            filter
                        }, set: { new in
                            filter = new ?? .none
                        })
                    )
                }
            #elseif os(macOS)
                .inspector(isPresented: $showFilterPicker) {
                    FilterPickerLoader(
                        thumbnail: selectedImage,
                        selectedFilter: .init(get: {
                            filter
                        }, set: { new in
                            filter = new ?? .none
                        })
                    )
                }
            #endif
                .onChange(of: selectedItem) { _, newItem in
                    guard let newItem else { return }

                    MetalContextManager.shared.clearCaches()

                    Task {
                        state = .loading
                        do {
                            selectedImage = try await PhotoLibraryManager.shared.load(newItem)

                        } catch {
                            print(error)
                        }
                        state = .ready
                    }
                }
        }
        .onAppear {
            if selectedItem == nil {
                showPhotosPicker = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Save Photo", systemImage: "square.and.arrow.up") {
                    guard let selectedImage else { return }

                    Task {
                        state = .loading
                        do {
                            let image = filter.apply(to: selectedImage)

                            try await PhotoLibraryManager.shared.save(image: image)
                        } catch {
                            print(error)
                        }

                        state = .ready
                    }
                }.disabled(selectedImage == nil || state != .ready)
            }

            ToolbarItem(placement: modePlacement) {
                PhotoEditorViewModePicker(viewMode: $viewMode)
            }

            ToolbarItemGroup(placement: .automatic) {
                Button("Choose Photo", systemImage: "photo") {
                    showPhotosPicker.toggle()
                }.disabled(state != .ready)

                Button("Filters", systemImage: "camera.filters") {
                    showFilterPicker.toggle()
                }.disabled(selectedImage == nil || state != .ready)

                Button("MCP", systemImage: "point.3.connected.trianglepath.dotted") {
                    showMCPServer.toggle()
                }
            }
        }
        .sheet(isPresented: $showMCPServer) {
            HuggingfacePromtView(
                onImage: { image in
                    MetalContextManager.shared.clearCaches()
                    selectedImage = image
                    state = .ready
                }
            )
        }
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $selectedItem,
            matching: .images
        )
        .ignoresSafeArea()
    }

    var modePlacement: ToolbarItemPlacement {
        #if os(iOS) || os(tvOS)
            .bottomBar
        #elseif os(macOS)
            .automatic
        #endif
    }
}

#Preview {
    NavigationStack {
        PhotoView()
    }
}
