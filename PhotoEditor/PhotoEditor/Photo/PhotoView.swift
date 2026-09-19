//
//  Created by Kurlovich Vitali on 9/18/26.
//

import CGMathKit
import CoreImage
import ImageIO
import PhotosUI
import SwiftUI

struct PhotoView: View {
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: CIImage? = nil

    @State private var filter: FilterType = .comic
    @State private var cropBaseline: CGFloat = 0.5

    @State private var cropOffset: CGFloat = 0
    @State private var showFilterPicker: Bool = false
    @State private var showPhotosPicker: Bool = false
    @State private var viewMode: ViewMode = .divided

    typealias ViewMode = CIImageView.Configuration.Mode

    func configuration(offset: CGFloat) -> CIImageView.Configuration {
        switch viewMode {
        case .original:
            return .original()
        case .filtered:
            return .filtered(filter: filter)
        case .divided:
            return .divided(filter: filter, offset: offset)
        }
    }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                let frame = proxy.frame(in: .local)
                let offset = frame.minX + frame.width * cropBaseline

                CIImageView(
                    image: selectedImage,
                    configuration: self.configuration(offset: offset)
                )
            }
            .overlay {
                if viewMode == .divided, filter != .none {
                    SplitControl(midPoint: $cropBaseline)
                }
            }
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
            ToolbarItem(placement: .status) {
                Picker("Mode", selection: $viewMode) {
                    Label("Original", systemImage: "camera.metering.spot")
                        .tag(ViewMode.original)

                    Label("Split", systemImage: "rectangle.split.2x1")
                        .tag(ViewMode.divided)

                    Label("Filtered", systemImage: "camera.filters")
                        .tag(ViewMode.filtered)
                }.pickerStyle(.segmented)
            }

            ToolbarItem(placement: .automatic) {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images
                ) {
                    Label("Choose Photo", systemImage: "photo")
                }
            }

            ToolbarItem {
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
