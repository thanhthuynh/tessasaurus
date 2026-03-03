//
//  TessasaurusTests.swift
//  TessasaurusTests
//
//  Created by Thanh Huynh on 1/28/26.
//

import Testing
import Foundation
@testable import Tessasaurus

struct PersistenceServiceTests {
    @Test func markDayOpenedPersistsCorrectly() async throws {
        let userDefaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        let service = PersistenceService(userDefaults: userDefaults)
        let occasionID = UUID()

        service.markDayOpened(3, for: occasionID)

        #expect(service.isDayOpened(3, for: occasionID))
        #expect(!service.isDayOpened(2, for: occasionID))

        userDefaults.removePersistentDomain(forName: userDefaults.description)
    }

    @Test func openedDaysReturnsAllOpenedDays() async throws {
        let userDefaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        let service = PersistenceService(userDefaults: userDefaults)
        let occasionID = UUID()

        service.markDayOpened(1, for: occasionID)
        service.markDayOpened(3, for: occasionID)
        service.markDayOpened(5, for: occasionID)

        let opened = service.openedDays(for: occasionID)
        #expect(opened == [1, 3, 5])

        userDefaults.removePersistentDomain(forName: userDefaults.description)
    }

    @Test func resetClearsAllOpenedDays() async throws {
        let userDefaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        let service = PersistenceService(userDefaults: userDefaults)
        let occasionID = UUID()

        service.markDayOpened(1, for: occasionID)
        service.markDayOpened(2, for: occasionID)
        service.resetAllOpenedDays(for: occasionID)

        #expect(service.openedDays(for: occasionID).isEmpty)

        userDefaults.removePersistentDomain(forName: userDefaults.description)
    }
}

struct CouponPersistenceTests {
    @Test func couponUsedCountStartsAtZero() async throws {
        let userDefaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        let service = PersistenceService(userDefaults: userDefaults)
        let couponID = UUID()

        #expect(service.couponUsedCount(for: couponID) == 0)

        userDefaults.removePersistentDomain(forName: userDefaults.description)
    }

    @Test func incrementCouponUsedCountIncrementsCorrectly() async throws {
        let userDefaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        let service = PersistenceService(userDefaults: userDefaults)
        let couponID = UUID()

        service.incrementCouponUsedCount(for: couponID)
        #expect(service.couponUsedCount(for: couponID) == 1)

        service.incrementCouponUsedCount(for: couponID)
        #expect(service.couponUsedCount(for: couponID) == 2)

        userDefaults.removePersistentDomain(forName: userDefaults.description)
    }

    @Test func couponUsedCountIsolatedPerCoupon() async throws {
        let userDefaults = UserDefaults(suiteName: "test_\(UUID().uuidString)")!
        let service = PersistenceService(userDefaults: userDefaults)
        let couponA = UUID()
        let couponB = UUID()

        service.incrementCouponUsedCount(for: couponA)
        service.incrementCouponUsedCount(for: couponA)
        service.incrementCouponUsedCount(for: couponB)

        #expect(service.couponUsedCount(for: couponA) == 2)
        #expect(service.couponUsedCount(for: couponB) == 1)

        userDefaults.removePersistentDomain(forName: userDefaults.description)
    }
}

struct CouponModelTests {
    @Test func smsURLFormatsCorrectly() async throws {
        let coupon = Coupon.allCoupons[0]
        let url = Coupon.smsURL(for: coupon)

        #expect(url != nil)
        let urlString = url!.absoluteString
        #expect(urlString.contains("sms:+16107049840"))
        #expect(urlString.contains("body="))
        #expect(urlString.contains(coupon.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!))
    }

    @Test func infiniteCouponReportsInfinite() async throws {
        let kissesAndHugs = Coupon.allCoupons[0]
        #expect(kissesAndHugs.isInfinite)
        #expect(kissesAndHugs.totalUses == nil)
    }

    @Test func limitedCouponReportsFinite() async throws {
        let massage = Coupon.allCoupons[1]
        #expect(!massage.isInfinite)
        #expect(massage.totalUses == 5)
    }

    @Test func allCouponsHaveUniqueIDs() async throws {
        let ids = Coupon.allCoupons.map(\.id)
        let uniqueIDs = Set(ids)
        #expect(ids.count == uniqueIDs.count)
    }
}
