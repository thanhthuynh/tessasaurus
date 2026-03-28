//
//  ServiceAndViewModelTests.swift
//  TessasaurusTests
//

import Testing
import Foundation
import UIKit
@testable import Tessasaurus

// MARK: - ImageCacheDownsampleTests

struct ImageCacheDownsampleTests {
    private func makeJPEGData(width: CGFloat, height: CGFloat) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.jpegData(compressionQuality: 0.8)!
    }

    @Test func validJPEGReturnsNonNil() {
        let data = makeJPEGData(width: 100, height: 100)
        let result = ImageCacheService.downsampleFromData(data, maxPixelDimension: 200)
        #expect(result != nil)
    }

    @Test func resultWithinMaxDimension() {
        let data = makeJPEGData(width: 400, height: 300)
        let result = ImageCacheService.downsampleFromData(data, maxPixelDimension: 100)
        #expect(result != nil)
        if let result {
            let maxSide = max(result.size.width, result.size.height)
            #expect(maxSide <= 100)
        }
    }

    @Test func smallerThanMaxReturnsReasonableSize() {
        let data = makeJPEGData(width: 50, height: 50)
        let result = ImageCacheService.downsampleFromData(data, maxPixelDimension: 200)
        #expect(result != nil)
        if let result {
            // ImageIO should not massively upscale — allow small rounding differences
            #expect(result.size.width <= 200)
            #expect(result.size.height <= 200)
        }
    }

    @Test func invalidDataReturnsNil() {
        let data = Data([0x00, 0x01, 0x02])
        let result = ImageCacheService.downsampleFromData(data, maxPixelDimension: 100)
        #expect(result == nil)
    }
}

// MARK: - CouponsViewModelTests

struct CouponsViewModelTests {
    private func makeViewModel() -> (CouponsViewModel, PersistenceService) {
        let ud = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        let ps = PersistenceService(userDefaults: ud)
        let vm = CouponsViewModel(persistenceService: ps)
        return (vm, ps)
    }

    /// The first coupon (Kisses & Hugs) is infinite (totalUses == nil).
    private var infiniteCoupon: Coupon { Coupon.allCoupons[0] }

    /// The second coupon (Free Massage) has totalUses == 5.
    private var limitedCoupon: Coupon { Coupon.allCoupons[1] }

    // MARK: remainingUses

    @Test func remainingUsesInfiniteReturnsNil() {
        let (vm, _) = makeViewModel()
        #expect(vm.remainingUses(for: infiniteCoupon) == nil)
    }

    @Test func remainingUsesCountsDown() {
        let (vm, ps) = makeViewModel()
        ps.incrementCouponUsedCount(for: limitedCoupon.id)
        ps.incrementCouponUsedCount(for: limitedCoupon.id)
        #expect(vm.remainingUses(for: limitedCoupon) == 3)
    }

    @Test func remainingUsesFloorsAtZero() {
        let (vm, ps) = makeViewModel()
        for _ in 0..<6 {
            ps.incrementCouponUsedCount(for: limitedCoupon.id)
        }
        #expect(vm.remainingUses(for: limitedCoupon) == 0)
    }

    // MARK: canRedeem

    @Test func canRedeemInfiniteAlwaysTrue() {
        let (vm, _) = makeViewModel()
        #expect(vm.canRedeem(infiniteCoupon))
    }

    @Test func canRedeemExhaustedReturnsFalse() {
        let (vm, ps) = makeViewModel()
        for _ in 0..<limitedCoupon.totalUses! {
            ps.incrementCouponUsedCount(for: limitedCoupon.id)
        }
        #expect(!vm.canRedeem(limitedCoupon))
    }

    // MARK: sortedCoupons / availableCount

    @Test func sortedCouponsPutsRedeemableFirst() {
        let (vm, ps) = makeViewModel()
        // Exhaust the limited coupon
        for _ in 0..<limitedCoupon.totalUses! {
            ps.incrementCouponUsedCount(for: limitedCoupon.id)
        }
        let sorted = vm.sortedCoupons
        // The first coupon in the sorted list should still be redeemable
        #expect(vm.canRedeem(sorted[0]))
    }

    @Test func availableCountDecreasesOnExhaustion() {
        let (vm, ps) = makeViewModel()
        let beforeCount = vm.availableCount

        for _ in 0..<limitedCoupon.totalUses! {
            ps.incrementCouponUsedCount(for: limitedCoupon.id)
        }

        #expect(vm.availableCount == beforeCount - 1)
    }

    // MARK: State transitions

    @Test func selectCouponSetsState() {
        let (vm, _) = makeViewModel()
        vm.selectCoupon(infiniteCoupon)
        #expect(vm.selectedCoupon?.id == infiniteCoupon.id)
        #expect(vm.showRedeemConfirmation)
    }

    @Test func selectExhaustedCouponDoesNothing() {
        let (vm, ps) = makeViewModel()
        for _ in 0..<limitedCoupon.totalUses! {
            ps.incrementCouponUsedCount(for: limitedCoupon.id)
        }
        vm.selectCoupon(limitedCoupon)
        #expect(vm.selectedCoupon == nil)
        #expect(!vm.showRedeemConfirmation)
    }

    @Test func dismissClearsState() {
        let (vm, _) = makeViewModel()
        vm.selectCoupon(infiniteCoupon)
        vm.dismissConfirmation()
        #expect(vm.selectedCoupon == nil)
        #expect(!vm.showRedeemConfirmation)
    }

    @Test func confirmRedemptionIncrementsAndClears() {
        let (vm, ps) = makeViewModel()
        vm.selectCoupon(limitedCoupon)
        vm.confirmRedemption()
        #expect(ps.couponUsedCount(for: limitedCoupon.id) == 1)
        #expect(vm.selectedCoupon == nil)
        #expect(!vm.showRedeemConfirmation)
    }

    @Test func confirmDoesNothingWithoutSelection() {
        let (vm, ps) = makeViewModel()
        vm.confirmRedemption()
        // No coupon was selected — used count should remain 0 for all
        for coupon in Coupon.allCoupons {
            #expect(ps.couponUsedCount(for: coupon.id) == 0)
        }
    }
}
