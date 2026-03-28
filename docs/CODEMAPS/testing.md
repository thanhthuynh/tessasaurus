<!-- Generated: 2026-03-28 | Files scanned: 6 | Token estimate: ~400 -->

# Testing

## Unit Tests (Swift Testing) — 79 test cases

| File | Suites | Tests |
|------|--------|-------|
| `TessasaurusTests.swift` | PersistenceServiceTests, CouponPersistenceTests, CouponModelTests | 10 |
| `ModelTests.swift` | BubbleSizeTests, UUIDStableHashTests, PhotoEqualityTests, PhotoCodableTests | 32 |
| `LayoutTests.swift` | ConstellationLayoutTests, ConstellationEdgeTests | 12 |
| `ServiceAndViewModelTests.swift` | ImageCacheDownsampleTests, CouponsViewModelTests | 17 |

## UI Tests (XCTest) — 14 test cases

| File | Coverage |
|------|----------|
| `TessasaurusUITests.swift` | Tab navigation, photo wall header/settings/add, coupons redeem flow |
| `TessasaurusUITestsLaunchTests.swift` | Launch screenshots (light/dark) |

## Run Commands

```bash
# Unit tests
xcodebuild test -project Tessasaurus.xcodeproj -scheme Tessasaurus \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TessasaurusTests

# UI tests
xcodebuild test -project Tessasaurus.xcodeproj -scheme Tessasaurus \
  -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:TessasaurusUITests
```

## Key Patterns

- Isolated `UserDefaults(suiteName: "test_\(UUID())")` per test
- UI tests use `-hasCompletedOnboarding YES` launch argument
- `ImageCacheService.downsampleFromData` testable as static method
- `CouponsViewModel` accepts injected `PersistenceService`
- `ConstellationLayout.calculatePositions` is pure (no I/O, no singletons)
