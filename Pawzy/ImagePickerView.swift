//
//  ImagePickerView.swift
//  Pawzy
//
//  Kamera + Galeri seçici ve tam ekran fotoğraf görüntüleyici
//

import SwiftUI
import PhotosUI

// MARK: - CameraPicker (UIImagePickerController wrapper)

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                let data = image.jpegData(compressionQuality: 0.8)
                parent.imageData = data
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - FullScreenPhotoView

struct FullScreenPhotoView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(20)
                    }
                }
                Spacer()
            }
        }
    }
}

// MARK: - Photo Source Picker Modifier

/// Kamera / Galeri seçimi için confirmation dialog + picker'ları yöneten modifier
struct PhotoSourcePickerModifier: ViewModifier {
    @Binding var imageData: Data?
    @State private var showSourceDialog: Bool = false
    @State private var showCamera: Bool = false
    @State private var showGallery: Bool = false

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                showSourceDialog = true
            }
            .confirmationDialog("Fotoğraf Ekle", isPresented: $showSourceDialog) {
                Button("Kamera") {
                    showCamera = true
                }
                Button("Galeri") {
                    showGallery = true
                }
                Button("İptal", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(imageData: $imageData)
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showGallery) {
                PhotoPicker(imageData: $imageData)
            }
    }
}

extension View {
    func photoSourcePicker(imageData: Binding<Data?>) -> some View {
        self.modifier(PhotoSourcePickerModifier(imageData: imageData))
    }
}
