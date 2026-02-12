//
//  DayProgressView.swift
//  Tessasaurus
//

import SwiftUI

struct DayProgressView: View {
    let totalDays: Int
    let currentDay: Int?
    let openedDays: Set<Int>
    let dayStatus: (Int) -> DayStatus
    let onDayTap: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(1...totalDays, id: \.self) { day in
                DayCircle(
                    dayNumber: day,
                    status: dayStatus(day),
                    isOpened: openedDays.contains(day),
                    isCurrent: day == currentDay
                )
                .onTapGesture {
                    onDayTap(day)
                }
            }
        }
        .padding(.horizontal)
    }
}

struct DayCircle: View {
    let dayNumber: Int
    let status: DayStatus
    let isOpened: Bool
    let isCurrent: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 40, height: 40)

            Circle()
                .strokeBorder(borderColor, lineWidth: isCurrent ? 3 : 1)
                .frame(width: 40, height: 40)

            if isOpened {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            } else if status == .locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                Text("\(dayNumber)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .animation(.spring(response: 0.3), value: isOpened)
    }

    private var backgroundColor: Color {
        if isOpened {
            return TessaColors.primary
        } else if isCurrent {
            return TessaColors.coral.opacity(0.5)
        } else if status == .unlocked {
            return TessaColors.primaryLight.opacity(0.3)
        } else {
            return Color.white.opacity(0.1)
        }
    }

    private var borderColor: Color {
        if isCurrent {
            return TessaColors.gold
        } else if isOpened {
            return TessaColors.primary
        } else {
            return Color.white.opacity(0.3)
        }
    }
}

#Preview {
    ZStack {
        GradientBackground()
        DayProgressView(
            totalDays: 7,
            currentDay: 3,
            openedDays: [1, 2],
            dayStatus: { day in
                if day < 3 { return .unlocked }
                else if day == 3 { return .current }
                else { return .locked }
            },
            onDayTap: { _ in }
        )
    }
}
