//
//  PhotoDetailView.swift
//  Tessasaurus
//

import SwiftUI

struct PhotoDetailView: View {
    let photo: Photo
    let image: UIImage?
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @GestureState private var magnificationState: CGFloat = 1.0

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
            Color.black.opacity(Double(0.9 * (1.0 - dragProgress * 0.5)))
                .background(.ultraThinMaterial.opacity(0.5))
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 24) {
                Spacer()

                photoContent

                // Caption in glass card
                if let caption = photo.caption {
                    Text(caption)
                        .font(.title3.weight(.medium))
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

                if let date = photo.createdAt as Date? {
                    VStack(spacing: 4) {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))

                        Text(Self.relativeDateFormatter.localizedString(for: date, relativeTo: Date()))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }

                Spacer()

                dismissHint
            }
        }
        .gesture(dragGesture)
    }

    @ViewBuilder
    private var photoContent: some View {
        Group {
            if let uiImage = image {
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
            .font(.caption)
            .foregroundStyle(.white.opacity(0.5))
            .padding(.bottom, 40)
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .updating($magnificationState) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.3)) {
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
                        withAnimation(.spring(response: 0.3)) {
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
        onDismiss: {}
    )
}
