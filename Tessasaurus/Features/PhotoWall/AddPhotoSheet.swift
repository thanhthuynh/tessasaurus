//
//  AddPhotoSheet.swift
//  Tessasaurus
//

import SwiftUI
import PhotosUI

// MARK: - Photo Upload State

enum PhotoUploadState {
    case pending, uploading, success, failed
}

// MARK: - Selected Photo Model

struct SelectedPhoto: Identifiable {
    let id = UUID()
    var image: UIImage?
    var caption: String = ""
    var bubbleSize: BubbleSize = .medium
    var uploadState: PhotoUploadState = .pending
    var isLoaded: Bool { image != nil }
}

// MARK: - Add Photo Sheet

struct AddPhotoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: PhotoWallViewModel

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [SelectedPhoto] = []
    @State private var isLoadingImages = false
    @State private var loadingTask: Task<Void, Never>?
    @FocusState private var focusedCaptionID: UUID?

    private var loadedCount: Int {
        selectedImages.filter(\.isLoaded).count
    }

    private var allLoaded: Bool {
        !selectedImages.isEmpty && selectedImages.allSatisfy(\.isLoaded)
    }

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
                .animation(TessaAnimations.standard, value: selectedImages.isEmpty)

                if viewModel.isUploading {
                    uploadingOverlay
                        .transition(.opacity)
                }
            }
            .navigationTitle("Add Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        loadingTask?.cancel()
                        dismiss()
                    }
                    .foregroundStyle(TessaColors.textPrimary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if !selectedImages.isEmpty {
                        Button("Upload") {
                            uploadPhotos()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(TessaGradients.sunrise)
                        .disabled(viewModel.isUploading || selectedImages.contains { $0.image == nil })
                        .accessibilityLabel("Upload \(loadedCount) photos")
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
                .font(TessaTypography.subtitle)
                .foregroundStyle(TessaColors.textPrimary)

            Text("Choose photos to share with your partner")
                .font(TessaTypography.detail)
                .foregroundStyle(TessaColors.textSecondary)
                .multilineTextAlignment(.center)

            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 10,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Choose Photos", systemImage: "photo.stack")
                    .font(TessaTypography.cardTitle)
                    .foregroundStyle(TessaColors.textPrimary)
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
                    .font(TessaTypography.cardTitle)
                    .foregroundStyle(TessaColors.textPrimary)

                Spacer()

                PhotosPicker(
                    selection: $selectedItems,
                    maxSelectionCount: 10,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Add More", systemImage: "plus")
                        .font(TessaTypography.detail.weight(.medium))
                        .foregroundStyle(TessaColors.coral)
                }
            }

            ScrollView {
                VStack(spacing: 16) {
                    ForEach($selectedImages) { $photo in
                        SelectedPhotoCard(
                            photo: $photo,
                            focusedCaptionID: $focusedCaptionID
                        ) {
                            withAnimation(TessaAnimations.standard) {
                                removePhoto(photo)
                            }
                            HapticService.shared.mediumTap()
                        }
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(maxHeight: .infinity)
            .scrollDismissesKeyboard(.interactively)
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

                let uploadedCount = selectedImages.filter { $0.uploadState == .success }.count
                Text("Uploading \(uploadedCount)/\(selectedImages.count)")
                    .font(TessaTypography.cardTitle)
                    .foregroundStyle(TessaColors.textPrimary)

                Text("\(Int(viewModel.uploadProgress * 100))%")
                    .font(TessaTypography.detail)
                    .foregroundStyle(TessaColors.textSecondary)

                ProgressView(value: viewModel.uploadProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: TessaColors.coral))
                    .frame(width: 200)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
        }
    }

    // MARK: - Actions

    private func loadImages(from items: [PhotosPickerItem]) {
        loadingTask?.cancel()
        isLoadingImages = true
        HapticService.shared.lightTap()

        // Create placeholder entries immediately
        let placeholders: [SelectedPhoto] = items.map { _ in SelectedPhoto() }
        selectedImages = placeholders

        loadingTask = Task {
            // Load all images concurrently
            let loadedImages: [(Int, UIImage?)] = await withTaskGroup(of: (Int, UIImage?).self) { group in
                for (index, item) in items.enumerated() {
                    group.addTask {
                        guard !Task.isCancelled else { return (index, nil) }
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            return (index, uiImage)
                        }
                        return (index, nil)
                    }
                }
                var results: [(Int, UIImage?)] = []
                for await result in group {
                    results.append(result)
                }
                return results
            }

            guard !Task.isCancelled else { return }

            await MainActor.run {
                // Batch update: assign all images at once
                for (index, image) in loadedImages {
                    guard index < selectedImages.count else { continue }
                    selectedImages[index].image = image
                }
                // Remove entries that failed to load
                selectedImages.removeAll { !$0.isLoaded }
                isLoadingImages = false
                if !selectedImages.isEmpty {
                    HapticService.shared.selection()
                }
            }
        }
    }

    private func removePhoto(_ photo: SelectedPhoto) {
        selectedImages.removeAll { $0.id == photo.id }
        selectedItems = []
    }

    private func uploadPhotos() {
        let photosToUpload: [(UIImage, String?, BubbleSize)] = selectedImages.compactMap { photo in
            guard let image = photo.image else { return nil }
            let caption: String? = photo.caption.isEmpty ? nil : photo.caption
            return (image, caption, photo.bubbleSize)
        }

        Task {
            // Mark all as uploading
            for index in selectedImages.indices {
                selectedImages[index].uploadState = .uploading
            }

            let result = await viewModel.uploadPhotos(images: photosToUpload)

            if result.failureCount == 0 {
                for index in selectedImages.indices {
                    selectedImages[index].uploadState = .success
                }
                HapticService.shared.success()
                try? await Task.sleep(nanoseconds: 400_000_000)
                dismiss()
            } else if result.successCount > 0 {
                // Mark succeeded
                for index in 0..<min(result.successCount, selectedImages.count) {
                    selectedImages[index].uploadState = .success
                }
                // Mark failed
                for index in result.successCount..<selectedImages.count {
                    selectedImages[index].uploadState = .failed
                }
                HapticService.shared.warning()
                try? await Task.sleep(nanoseconds: 600_000_000)
                // Remove succeeded, keep failed
                selectedImages = selectedImages.filter { $0.uploadState != .success }
                selectedItems = []
            } else {
                for index in selectedImages.indices {
                    selectedImages[index].uploadState = .failed
                }
                HapticService.shared.warning()
            }
        }
    }
}

// MARK: - Selected Photo Card

struct SelectedPhotoCard: View {
    @Binding var photo: SelectedPhoto
    var focusedCaptionID: FocusState<UUID?>.Binding
    let onRemove: () -> Void

    private var isFocused: Bool {
        focusedCaptionID.wrappedValue == photo.id
    }

    var body: some View {
        VStack(spacing: 12) {
            // Photo preview with remove button
            ZStack(alignment: .topTrailing) {
                if let image = photo.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(uploadStateOverlay)
                } else {
                    // Shimmer placeholder while loading
                    RoundedRectangle(cornerRadius: 12)
                        .fill(TessaColors.inputBackground)
                        .frame(height: 150)
                        .shimmer()
                }

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(TessaColors.textPrimary)
                        .shadow(radius: 2)
                }
                .padding(8)
                .accessibilityLabel("Remove photo")
            }

            // Caption input
            if photo.isLoaded {
                TextField("Add a caption...", text: $photo.caption, prompt: Text("Add a caption...").foregroundStyle(TessaColors.textTertiary))
                    .font(TessaTypography.body)
                    .textFieldStyle(.plain)
                    .tint(TessaColors.coral)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(TessaColors.inputBackground)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(isFocused ? TessaColors.coral.opacity(0.6) : .clear, lineWidth: 1)
                            )
                    )
                    .contentShape(Rectangle())
                    .foregroundStyle(TessaColors.textPrimary)
                    .focused(focusedCaptionID, equals: photo.id)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { focusedCaptionID.wrappedValue = nil }
                    .accessibilityLabel("Photo caption")

                // Bubble size picker
                HStack(spacing: 12) {
                    Text("Size:")
                        .font(TessaTypography.caption)
                        .foregroundStyle(TessaColors.textSecondary)

                    Picker("Bubble Size", selection: $photo.bubbleSize) {
                        ForEach(BubbleSize.allCases, id: \.self) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Photo display size")
                    .onChange(of: photo.bubbleSize) { _, _ in
                        HapticService.shared.selection()
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(TessaColors.cardBorder, lineWidth: 0.5)
                )
        )
    }

    @ViewBuilder
    private var uploadStateOverlay: some View {
        switch photo.uploadState {
        case .uploading:
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.4))
                .overlay(
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                )
        case .success:
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.3))
                .overlay(
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.green)
                )
                .transition(.opacity)
        case .failed:
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.3))
                .overlay(
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.red)
                )
        case .pending:
            EmptyView()
        }
    }
}

#Preview {
    AddPhotoSheet(viewModel: PhotoWallViewModel())
}
