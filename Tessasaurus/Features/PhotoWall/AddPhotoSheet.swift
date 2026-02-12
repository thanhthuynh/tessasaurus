//
//  AddPhotoSheet.swift
//  Tessasaurus
//

import SwiftUI
import PhotosUI

struct AddPhotoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: PhotoWallViewModel

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [SelectedPhoto] = []
    @State private var isLoadingImages = false

    var body: some View {
        NavigationStack {
            ZStack {
                TessaColors.background
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    if selectedImages.isEmpty {
                        photoPickerSection
                    } else {
                        selectedPhotosSection
                    }
                }
                .padding()

                if viewModel.isUploading {
                    uploadingOverlay
                }
            }
            .navigationTitle("Add Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if !selectedImages.isEmpty {
                        Button("Upload") {
                            uploadPhotos()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(TessaGradients.sunrise)
                        .disabled(viewModel.isUploading)
                    }
                }
            }
            .toolbarBackground(TessaColors.primary.opacity(0.8), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .onChange(of: selectedItems) { _, newItems in
            loadImages(from: newItems)
        }
    }

    // MARK: - Photo Picker Section

    private var photoPickerSection: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(TessaGradients.sunrise)

            Text("Select Photos")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)

            Text("Choose photos to share with your partner")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 10,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Choose Photos", systemImage: "photo.stack")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(TessaGradients.sunrise)
                    .clipShape(Capsule())
            }
            .padding(.top, 20)

            Spacer()
        }
    }

    // MARK: - Selected Photos Section

    private var selectedPhotosSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("\(selectedImages.count) photo\(selectedImages.count == 1 ? "" : "s") selected")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Add More", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TessaColors.coral)
                }
            }

            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach($selectedImages) { $photo in
                        SelectedPhotoCard(photo: $photo) {
                            removePhoto(photo)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Uploading Overlay

    private var uploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("Uploading...")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("\(Int(viewModel.uploadProgress * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                ProgressView(value: viewModel.uploadProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: TessaColors.coral))
                    .frame(width: 200)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
        }
    }

    // MARK: - Actions

    private func loadImages(from items: [PhotosPickerItem]) {
        isLoadingImages = true

        Task {
            var newPhotos: [SelectedPhoto] = []

            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    let photo = SelectedPhoto(image: uiImage)
                    newPhotos.append(photo)
                }
            }

            await MainActor.run {
                selectedImages = newPhotos
                isLoadingImages = false
            }
        }
    }

    private func removePhoto(_ photo: SelectedPhoto) {
        selectedImages.removeAll { $0.id == photo.id }
        // Also update the picker selection
        if selectedImages.isEmpty {
            selectedItems = []
        }
    }

    private func uploadPhotos() {
        let photosToUpload = selectedImages.map { ($0.image, $0.caption, $0.bubbleSize) }

        Task {
            await viewModel.uploadPhotos(images: photosToUpload)
            dismiss()
        }
    }
}

// MARK: - Selected Photo Model

struct SelectedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
    var caption: String = ""
    var bubbleSize: BubbleSize = .medium
}

// MARK: - Selected Photo Card

struct SelectedPhotoCard: View {
    @Binding var photo: SelectedPhoto
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            // Photo preview with remove button
            ZStack(alignment: .topTrailing) {
                Image(uiImage: photo.image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
                .padding(8)
            }

            // Caption input
            TextField("Add a caption...", text: $photo.caption)
                .textFieldStyle(.plain)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.1))
                )
                .foregroundStyle(.white)

            // Bubble size picker
            HStack(spacing: 12) {
                Text("Size:")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))

                Picker("Bubble Size", selection: $photo.bubbleSize) {
                    ForEach(BubbleSize.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

#Preview {
    AddPhotoSheet(viewModel: PhotoWallViewModel())
}
