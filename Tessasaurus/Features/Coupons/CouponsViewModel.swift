//
//  CouponsViewModel.swift
//  Tessasaurus
//

import SwiftUI

@Observable
final class CouponsViewModel {
    private let persistenceService: PersistenceService
    private let hapticService = HapticService.shared

    init(persistenceService: PersistenceService = PersistenceService()) {
        self.persistenceService = persistenceService
    }

    var coupons = Coupon.allCoupons
    var selectedCoupon: Coupon?
    var showRedeemConfirmation = false
    var showCelebration = false
    var showToast = false
    var toastMessage = ""
    var errorMessage: String?
    var showError = false

    var sortedCoupons: [Coupon] {
        coupons.sorted { a, b in
            let aRedeemable = canRedeem(a)
            let bRedeemable = canRedeem(b)
            if aRedeemable != bRedeemable { return aRedeemable }
            return false
        }
    }

    var availableCount: Int {
        coupons.filter { canRedeem($0) }.count
    }

    func remainingUses(for coupon: Coupon) -> Int? {
        guard let total = coupon.totalUses else { return nil }
        return max(0, total - persistenceService.couponUsedCount(for: coupon.id))
    }

    func canRedeem(_ coupon: Coupon) -> Bool {
        guard let total = coupon.totalUses else { return true }
        return persistenceService.couponUsedCount(for: coupon.id) < total
    }

    func selectCoupon(_ coupon: Coupon) {
        guard canRedeem(coupon) else { return }
        hapticService.selection()
        selectedCoupon = coupon
        showRedeemConfirmation = true
    }

    func dismissConfirmation() {
        hapticService.lightTap()
        showRedeemConfirmation = false
        selectedCoupon = nil
    }

    func confirmRedemption() {
        guard let coupon = selectedCoupon else { return }

        persistenceService.incrementCouponUsedCount(for: coupon.id)
        hapticService.success()

        showRedeemConfirmation = false

        sendSMS(for: coupon)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            showCelebration = true
            await hapticService.celebrationBurst()

            toastMessage = "\(coupon.name) redeemed!"
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showToast = true
            }

            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.3)) {
                showToast = false
            }

            try? await Task.sleep(for: .milliseconds(500))
            showCelebration = false
        }

        selectedCoupon = nil
    }

    private func sendSMS(for coupon: Coupon) {
        guard let url = Coupon.smsURL(for: coupon) else {
            errorMessage = "Could not create SMS"
            showError = true
            return
        }

        guard UIApplication.shared.canOpenURL(URL(string: "sms:")!) else {
            errorMessage = "SMS is not available on this device"
            showError = true
            return
        }

        UIApplication.shared.open(url)
    }
}
