//
//  PhotoDetailView.swift
//  Tessasaurus
//

import SwiftUI

struct PhotoDetailView: View {
    let photo: Photo
    let image: UIImage?
    let imageLoader: ((Photo) async -> UIImage?)?
    let isUploaderMode: Bool
    let onDismiss: () -> Void
    var onUpdateCaption: ((String?) -> Void)?

    @State private var asyncImage: UIImage?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @GestureState private var magnificationState: CGFloat = 1.0

    @State private var editedCaption: String = ""
    @State private var isEditingCaption: Bool = false
    @FocusState private var isCaptionFocused: Bool

    private let haptics = HapticService.shared
    private let dismissThreshold: CGFloat = 100

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    private var dragProgress: CGFloat {
        min(abs(dragOffset.height) / dismissThreshold, 1.0)
    }

    var body: some View {
        ZStack {
            // Background with blur and progressive opacity
            TessaColors.deepSpace.opacity(Double(0.95 * (1.0 - dragProgress * 0.5)))
                .background(.ultraThinMaterial.opacity(0.5))
                .ignoresSafeArea()
                .onTapGesture {
                    if isEditingCaption {
                        saveCaption()
                    } else {
                        onDismiss()
                    }
                }

            VStack(spacing: 24) {
                Spacer()

                photoContent

                // Caption section
                captionSection

                if let date = photo.createdAt as Date? {
                    VStack(spacing: 4) {
                        Text(date, style: .date)
                            .font(TessaTypography.caption)
                            .foregroundStyle(.white.opacity(0.6))

                        Text(Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date()))
                            .font(TessaTypography.badge)
                            .foregroundStyle(TessaColors.textTertiary)
                    }
                }

                Spacer()

                dismissHint
            }
        }
        .gesture(isEditingCaption ? nil : dragGesture)
        .accessibilityAction(named: "Dismiss") { onDismiss() }
        .onAppear {
            editedCaption = photo.caption ?? ""
        }
        .task {
            if image == nil, let loader = imageLoader {
                asyncImage = await loader(photo)
            }
        }
    }

    // MARK: - Caption Section

    @ViewBuilder
    private var captionSection: some View {
        if isUploaderMode {
            if isEditingCaption {
                // Editing mode
                VStack(spacing: 12) {
                    TextField("Add a caption...", text: $editedCaption)
                        .font(TessaTypography.cardTitle)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .tint(TessaColors.coral)
                        .focused($isCaptionFocused)
                        .submitLabel(.done)
                        .onSubmit { saveCaption() }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(TessaColors.coral.opacity(0.6), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 32)

                    HStack(spacing: 16) {
                        Button("Cancel") {
                            editedCaption = photo.caption ?? ""
                            isEditingCaption = false
                            isCaptionFocused = false
                        }
                        .font(TessaTypography.detail)
                        .foregroundStyle(TessaColors.textSecondary)

                        Button("Save") {
                            saveCaption()
                        }
                        .font(TessaTypography.detail.weight(.semibold))
                        .foregroundStyle(TessaColors.coral)
                    }
                }
            } else {
                // Display mode — tappable to edit
                Button {
                    isEditingCaption = true
                    isCaptionFocused = true
                    haptics.lightTap()
                } label: {
                    HStack(spacing: 8) {
                        Text(photo.caption ?? "Tap to add caption")
                            .font(TessaTypography.cardTitle)
                            .foregroundStyle(photo.caption != nil ? .white : .white.opacity(0.4))
                            .multilineTextAlignment(.center)

                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(TessaColors.cardBorder, lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 32)
            }
        } else {
            // Viewer mode — read-only
            if let caption = photo.caption {
                Text(caption)
                    .font(TessaTypography.cardTitle)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(TessaColors.cardBorder, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 32)
            }
        }
    }

    @ViewBuilder
    private var photoContent: some View {
        Group {
            if let uiImage = image ?? asyncImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if let assetName = photo.assetImageName {
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                placeholderContent
            }
        }
        .scaleEffect((scale * magnificationState) * (1 - dragProgress * 0.15))
        .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
        .gesture(magnificationGesture)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }

    private var placeholderContent: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [
                        TessaColors.primaryLight.opacity(0.3),
                        TessaColors.pink.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(photo.aspectRatio, contentMode: .fit)
            .overlay(
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.white.opacity(0.5))
            )
    }

    private var dismissHint: some View {
        Text("Swipe down to close")
            .font(TessaTypography.caption)
            .foregroundStyle(TessaColors.textTertiary)
            .padding(.bottom, 40)
    }

    // MARK: - Actions

    private func saveCaption() {
        let newCaption = editedCaption.trimmingCharacters(in: .whitespacesAndNewlines)
        let caption: String? = newCaption.isEmpty ? nil : newCaption
        onUpdateCaption?(caption)
        isEditingCaption = false
        isCaptionFocused = false
        haptics.lightTap()
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .updating($magnificationState) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    scale = min(max(scale * value.magnification, 1.0), 4.0)
                    if scale == 1.0 {
                        offset = .zero
                    }
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale == 1.0 {
                    dragOffset = value.translation

                    // Haptic when crossing threshold
                    if abs(value.translation.height) > dismissThreshold &&
                       abs(value.translation.height - value.predictedEndTranslation.height) < 50 {
                        haptics.mediumTap()
                    }
                } else {
                    offset.width += value.translation.width / 10
                    offset.height += value.translation.height / 10
                }
            }
            .onEnded { value in
                if scale == 1.0 {
                    if abs(value.translation.height) > dismissThreshold {
                        onDismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = .zero
                        }
                    }
                }
            }
    }
}

#Preview {
    PhotoDetailView(
        photo: Photo.samples[0],
        image: nil,
        imageLoader: nil,
        isUploaderMode: true,
        onDismiss: {}
    )
}
