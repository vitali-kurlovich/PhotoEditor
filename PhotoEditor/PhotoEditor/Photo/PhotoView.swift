//
//  Created by Kurlovich Vitali on 9/18/26.
//

import CoreImage
import PhotosUI
import SwiftUI

struct PhotoView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: CIImage? = nil

    @State private var filter: FilterType = .sepia

    @State private var showFilterPicker: Bool = false
    @State private var showPhotosPicker: Bool = false
    @State private var viewMode: ViewMode = .divided

    typealias ViewMode = CIImageView.Configuration.Mode

    var body: some View {
        ZStack {
            ImageEditorView(filter: filter, editedImage: selectedImage, viewMode: viewMode)
                .ignoresSafeArea()

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
                        do {
                            if let data = try await newItem.loadTransferable(
                                type: Data.self
                            ) {
                                let image = CIImage.image(from: data)
                                selectedImage = image
                            }

                        } catch {
                            print("Unable to load image:", error)
                        }
                    }
                }
        }
        .onAppear {
            if selectedItem == nil {
                showPhotosPicker = true
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
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
}

#Preview {
    NavigationStack {
        PhotoView()
    }
}
