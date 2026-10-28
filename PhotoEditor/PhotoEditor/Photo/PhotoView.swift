//
//  Created by Kurlovich Vitali on 9/18/26.
//

import CoreImage
import PhotosUI
import SwiftUI

struct PhotoView: View {
    @State private var showFilterPicker: Bool = false
    @State private var showPhotosPicker: Bool = false
    @State private var showMCPServer: Bool = false
    @State private var showStableDiffusion: Bool = false
    @State private var showFlux: Bool = false

    @State private var showVideoPreview: Bool = false

    @State private var viewMode: ViewMode = .divided

    @State
    private var model = PhotoViewModel()

    typealias ViewMode = CIImageView.Configuration.Mode

    var body: some View {
        ZStack {
            ImageEditorView(
                filter: model.filter,
                editedImage: model.selectedImage,
                viewMode: viewMode
            )
            .ignoresSafeArea()
            .overlay(alignment: .center) {
                switch model.state {
                case let .loading(description):
                    PhotoProgressView(description: description)
                case .ready:
                    EmptyView()
                }
            }

            #if os(iOS) || os(tvOS)
            .sheet(isPresented: $showFilterPicker) {
                FilterPickerLoader(
                    thumbnail: model.selectedImage,
                    selectedFilter: .init(get: {
                        model.filter
                    }, set: { new in
                        model.filter = new ?? .none
                    })
                )
            }
            #elseif os(macOS)
            .inspector(isPresented: $showFilterPicker) {
                FilterPickerLoader(
                    thumbnail: model.selectedImage,
                    selectedFilter: .init(get: {
                        model.filter
                    }, set: { new in
                        model.filter = new ?? .none
                    })
                )
            }
            #endif
        }
        .onAppear {
            if model.selectedItem == nil {
                showPhotosPicker = true
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button("Save Photo", systemImage: "square.and.arrow.up") {
                    Task {
                        do {
                            try await model.saveImageToPhotoLibrary()
                        } catch {}
                    }

                }.disabled(model.selectedImage == nil || model.state != .ready)

                Button("Generate Video", systemImage: "movieclapper") {
                    Task {
                        do {
                            let _ = try await model.generateVideo()

                            showVideoPreview = true
                        } catch {}
                    }

                }.disabled(model.selectedImage == nil || model.state != .ready)
            }

            ToolbarItem(placement: modePlacement) {
                PhotoEditorViewModePicker(viewMode: $viewMode)
            }

            ToolbarItemGroup(placement: .automatic) {
                Button("Choose Photo", systemImage: "photo") {
                    showPhotosPicker.toggle()
                }.disabled(model.state != .ready)

                Button("Filters", systemImage: "camera.filters") {
                    showFilterPicker.toggle()
                }.disabled(model.selectedImage == nil || model.state != .ready)

                Button("MCP", systemImage: "point.3.connected.trianglepath.dotted") {
                    showMCPServer.toggle()
                }

                Button("Stable Diffusion", systemImage: "wand.and.sparkles") {
                    showStableDiffusion.toggle()
                }

                Button("FLUX", systemImage: "sparkles") {
                    showFlux.toggle()
                }
            }
        }
        .sheet(isPresented: $showMCPServer) {
            HuggingfacePromtView(
                onImage: { image in
                    MetalContextManager.shared.clearCaches()
                    model.selectedImage = image
                }
            )
        }
        .sheet(isPresented: $showStableDiffusion) {
            StableDiffusionPromptView(
                onImage: { image in
                    MetalContextManager.shared.clearCaches()
                    model.selectedImage = image
                }
            )
        }
        .sheet(isPresented: $showFlux) {
            FluxPromptView(
                onImage: { image in
                    MetalContextManager.shared.clearCaches()
                    model.selectedImage = image
                }
            )
        }
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $model.selectedItem,
            matching: .images
        )
        .sheet(isPresented: $showVideoPreview) {
            if let url = model.videoURL {
                VideoPreview(url: url)
            }
        }
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
