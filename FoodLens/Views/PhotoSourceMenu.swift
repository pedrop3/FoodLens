import SwiftUI
import PhotosUI


struct PhotoSourceMenu: View {
    var title: String
    var systemImage: String = "camera"
    var onImageData: (Data) -> Void

    @State private var showingCamera = false
    @State private var showingPhotosPicker = false
    @State private var photosPickerItem: PhotosPickerItem?

    var body: some View {
        Menu {
            Button {
                showingCamera = true
            } label: {
                Label("Tirar foto", systemImage: "camera")
            }

            Button {
                showingPhotosPicker = true
            } label: {
                Label("Importar foto", systemImage: "photo.on.rectangle")
            }
        } label: {
            Label(title, systemImage: systemImage)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraCaptureView(
                onCapture: { data in
                    showingCamera = false
                    onImageData(data)
                },
                onCancel: { showingCamera = false }
            )
            .ignoresSafeArea()
        }

        .photosPicker(isPresented: $showingPhotosPicker, selection: $photosPickerItem, matching: .images)
        .onChange(of: photosPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    onImageData(data)
                }
                photosPickerItem = nil
            }
        }
    }
}
