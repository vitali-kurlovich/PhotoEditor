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

                    Task {
                        state = .loading
                        do {
                            selectedImage = try await newItem.loadTransferable(type: CIImage.self)
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
            ToolbarItem(placement: modePlacement) {
                Picker("Mode", selection: $viewMode) {
                    Label("Original", systemImage: "camera.metering.spot")
                        .tag(ViewMode.original)

                    Label("Split", systemImage: "rectangle.split.2x1")
                        .tag(ViewMode.divided)

                    Label("Filtered", systemImage: "camera.filters")
                        .tag(ViewMode.filtered)
                }.pickerStyle(.segmented)
            }

            ToolbarItemGroup(placement: .automatic) {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images
                ) {
                    Label("Choose Photo", systemImage: "photo")
                }

                Button("Filters", systemImage: "camera.filters") {
                    showFilterPicker.toggle()
                }.disabled(selectedItem == nil)
            }
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
