//
//  PhotoWallView.swift
//  Tessasaurus
//

import SwiftUI

struct PhotoWallView: View {
    @Binding var showTabBar: Bool
    @State private var viewModel = PhotoWallViewModel()
    @State private var selectedPhoto: Photo?
    @State private var showAddPhotoSheet = false
    @State private var showDeleteAllConfirmation = false
    @State private var isSelectingPhoto = false

    var body: some View {
        ZStack {
            if viewModel.photos.isEmpty && !viewModel.isLoading {
                // Empty state with cosmic background
                ZStack {
                    StarfieldBackground(canvasOffset: .zero, canvasScale: 1.0)
                    emptyState
                }
                .ignoresSafeArea()
            } else {
                constellationCanvas
            }

            // Floating header overlay
            VStack {
                header
                Spacer()
            }

            // Floating add button (uploader mode only)
            if viewModel.isUploaderMode {
                addButton
            }

            // Photo detail overlay
            if let photo = selectedPhoto {
                PhotoDetailView(
                    photo: photo,
                    image: viewModel.fullResolutionImage(for: photo),
                    imageLoader: { photo in await viewModel.loadImageAsync(for: photo) },
                    isUploaderMode: viewModel.isUploaderMode,
                    onDismiss: {
                        isSelectingPhoto = true
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            selectedPhoto = nil
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isSelectingPhoto = false
                        }
                    },
                    onUpdateCaption: { newCaption in
                        selectedPhoto?.caption = newCaption
                        Task {
                            await viewModel.updateCaption(for: photo, newCaption: newCaption)
                        }
                    }
                )
                .transition(.opacity)
            }

            // Loading overlay
            if viewModel.isLoading && viewModel.photos.isEmpty {
                loadingOverlay
            }
        }
        .task {
            await viewModel.loadPhotos()
        }
        .sheet(isPresented: $showAddPhotoSheet) {
            AddPhotoSheet(viewModel: viewModel)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An error occurred")
        }
        // TEMPORARY: Delete All confirmation (remove after use)
        .confirmationDialog(
            "Delete All Photos?",
            isPresented: $showDeleteAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) {
                Task { await viewModel.deleteAllPhotos() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all photos from CloudKit and local storage. This cannot be undone.")
        }
        .overlay {
            if viewModel.isDeletingAll, let progress = viewModel.deleteAllProgress {
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text(progress)
                        .font(TessaTypography.detail)
                        .foregroundStyle(.white)
                }
                .padding(24)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        // END TEMPORARY
        .onChange(of: selectedPhoto) { _, newValue in
            withAnimation {
                showTabBar = newValue == nil
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()

                VStack(spacing: 4) {
                    Text("Our Memories")
                        .font(TessaTypography.sectionTitle)
                        .foregroundStyle(.white)

                    Text("\(viewModel.photos.count) photos")
                        .font(TessaTypography.detail)
                        .foregroundStyle(TessaColors.textSecondary)
                }

                Spacer()
            }
            .overlay(alignment: .trailing) {
                Menu {
                    Button {
                        viewModel.toggleUploaderMode()
                    } label: {
                        Label(
                            viewModel.isUploaderMode ? "Switch to Viewer Mode" : "Switch to Uploader Mode",
                            systemImage: viewModel.isUploaderMode ? "eye" : "square.and.arrow.up"
                        )
                    }

                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    Divider()

                    // TEMPORARY: Delete All Photos (remove after use)
                    Button(role: .destructive) {
                        showDeleteAllConfirmation = true
                    } label: {
                        Label("Delete All Photos", systemImage: "trash")
                    }
                    .disabled(viewModel.isDeletingAll)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(8)
                        .accessibilityLabel("Settings menu")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    TessaColors.deepSpace.opacity(0.8),
                    TessaColors.deepSpace.opacity(0.4),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Constellation Canvas

    private var constellationCanvas: some View {
        ConstellationCanvasView(
            photos: viewModel.photos,
            onPhotoTap: { photo in
                guard !isSelectingPhoto else { return }
                isSelectingPhoto = true
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    selectedPhoto = photo
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isSelectingPhoto = false
                }
            },
            imageLoader: { photo in
                await viewModel.loadImageAsync(for: photo)
            }
        )
    }

    // MARK: - Add Button

    private var addButton: some View {
        VStack {
            Spacer()

            HStack {
                Spacer()

                Button {
                    HapticService.shared.lightTap()
                    showAddPhotoSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(TessaColors.cardBorder, lineWidth: 1)
                                )
                                .shadow(color: TessaColors.primary.opacity(0.3), radius: 10, x: 0, y: 5)
                        )
                }
                .padding(.trailing, 24)
                .padding(.bottom, 90) // Above floating tab bar
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(TessaGradients.sunrise)

            Text("No photos yet")
                .font(TessaTypography.subtitle)
                .foregroundStyle(.white)

            if viewModel.isUploaderMode {
                Text("Tap the + button to add photos")
                    .font(TessaTypography.detail)
                    .foregroundStyle(TessaColors.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Photos will appear here when\nthey're shared with you")
                    .font(TessaTypography.detail)
                    .foregroundStyle(TessaColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.2)

            Text("Loading photos...")
                .font(TessaTypography.detail)
                .foregroundStyle(TessaColors.textSecondary)
        }
    }
}

#Preview {
    PhotoWallView(showTabBar: .constant(true))
}
