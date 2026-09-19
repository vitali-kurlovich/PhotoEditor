import CoreImage
import SwiftUI

struct CameraView: View {
    @State private var permissionDenied: Bool = false

    @State private var image: CIImage?
    @State private var filter: FilterType = .none
    @State private var cropBaseline: CGFloat = 0.5

    var body: some View {
        ZStack {
            if permissionDenied {
                permissionDeniedView
            } else if let image {
                CIImageView(
                    image: image,
                    configuration: .init(
                        filter: filter,
                        cropOffset: cropBaseline,
                        mode: .filtered
                    )
                )
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    filterPicker
                    controls
                }
                .padding(.bottom, 24)
            }
        }
        .task(id: "CameraManager") {
            permissionDenied = false
            do {
                try await CameraManager.shared.start()

                for await image in await CameraManager.shared.videoStream {
                    self.image = image
                }

            } catch {
                permissionDenied = true
            }
        }.task(id: "Photo") {

            for await image in await CameraManager.shared.photoCaptureStream {
                do {
                    try await PhotoLibraryManager.shared.save(image: filter.apply(to: image))

                } catch {}
            }
        }
        .onDisappear {
            Task {
                await CameraManager.shared.stop()
            }
        }
    }

    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {}
            .padding(.bottom, 12)
    }

    private var controls: some View {
        HStack {
            Spacer()
            Button {
                Task {
                    await CameraManager.shared.captureFilteredPhoto()
                }
            } label: {
                Circle()
                    .strokeBorder(.white, lineWidth: 4)
                    .frame(width: 74, height: 74)
                    .background(Circle().fill(.white.opacity(0.25)))
            }
            Spacer()
            Button {
                Task {
                    try? await CameraManager.shared.flipCamera()
                }
            }
            label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(.black.opacity(0.35), in: Circle())
            }
            .padding(.trailing, 24)
        }
        .padding(.horizontal, 24)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Camera access is required")
                .font(.headline)
            Text("Enable camera access in Settings to use the live filter preview.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            #if os(iOS) || os(tvOS)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            #endif
        }
        .padding()
    }

    /*
     private func toast(text: String) -> some View {
         VStack {
             Spacer()
             Text(text)
                 .font(.subheadline.weight(.medium))
                 .padding(.horizontal, 16)
                 .padding(.vertical, 10)
                 .background(.black.opacity(0.75), in: Capsule())
                 .foregroundStyle(.white)
                 .padding(.bottom, 140)
         }
         .transition(.opacity)
         .onAppear {
             DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                 withAnimation { cameraManager.lastSavedConfirmation = nil }
             }
         }
     }
     */
}

#Preview {
    CameraView()
}
