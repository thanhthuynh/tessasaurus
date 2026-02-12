//
//  FloatingTabBar.swift
//  Tessasaurus
//

import SwiftUI

struct FloatingTabBar: View {
    @Binding var selectedTab: Int

    private let haptics = HapticService.shared

    private let tabs: [(icon: String, label: String)] = [
        ("heart.fill", "Home"),
        ("sparkles", "Photos")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { index in
                Button {
                    guard selectedTab != index else { return }
                    haptics.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(
                                selectedTab == index
                                ? AnyShapeStyle(TessaGradients.sunrise)
                                : AnyShapeStyle(Color.white.opacity(0.4))
                            )

                        Text(tabs[index].label)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(
                                selectedTab == index
                                ? Color.white
                                : Color.white.opacity(0.4)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .accessibilityLabel(tabs[index].label)
            }
        }
        .frame(width: 200)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(TessaColors.cardBorder, lineWidth: 1)
                    )
                    .shadow(color: TessaColors.primary.opacity(0.2), radius: 20, x: 0, y: 10)

                // Sliding pill indicator
                GeometryReader { geometry in
                    let tabWidth = geometry.size.width / CGFloat(tabs.count)
                    Capsule()
                        .fill(TessaColors.primary.opacity(0.2))
                        .frame(width: tabWidth - 12, height: geometry.size.height - 8)
                        .offset(x: CGFloat(selectedTab) * tabWidth + 6, y: 4)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedTab)
                }
            }
        )
        .safeAreaPadding(.bottom)
    }
}

#Preview {
    ZStack {
        GradientBackground()

        VStack {
            Spacer()
            FloatingTabBar(selectedTab: .constant(0))
        }
    }
}
