<!-- Generated: 2026-03-28 | Files scanned: 33 | Token estimate: ~700 -->

# Features

## PhotoWall (tab 0)

```
PhotoWallView (269 lines)
  ├── ConstellationCanvasView (381 lines)
  │   ├── StarfieldBackground ── 200 stars, 3 parallax layers, Canvas
  │   ├── ConstellationLinesView ── Canvas, up to 3 neighbors per bubble
  │   └── PhotoBubble[] ── visibility-culled, glow + shimmer, async image load
  ├── PhotoDetailView (364 lines) ── overlay
  │   ├── pinch-to-zoom (1×–4×), drag-to-dismiss, pan when zoomed
  │   ├── caption edit (uploader mode), bubble size picker
  │   └── date display (absolute + relative)
  └── AddPhotoSheet (454 lines) ── sheet
      ├── PhotosPicker (max 10), concurrent thumbnail generation
      └── sequential upload via viewModel.uploadSinglePhoto()

PhotoWallViewModel (390 lines)
  State: photos[], isLoading, isUploading, uploadProgress, errorMessage, showError, isUploaderMode
  Key methods:
    loadPhotos()        → CK account check → fetch → save metadata → subscribe
    loadImageAsync()    → 4-tier cache cascade (memory → disk thumb → disk full → CK)
    uploadSinglePhoto() → CK upload + local save + cache
    updateCaption()     → optimistic update + CK save + rollback on failure
    updateBubbleSize()  → optimistic update + CK save + rollback on failure
    deletePhoto()       → CK delete + cache eviction + metadata save

ConstellationLayout
    calculatePositions() → sort by size → ring placement → jitter → collision resolution
    PlacedBubble: photoID (UUID), index, position, ringIndex, bubbleScale
```

## Coupons (tab 1)

```
CouponsView (274 lines)
  ├── header (time-based greeting + "Tessa")
  ├── coupon list → CouponCardView[] (GlassCard)
  ├── redeem confirmation overlay
  ├── ConfettiView (celebration)
  └── toast notification

CouponsViewModel (109 lines)
  State: coupons[], selectedCoupon?, showRedeemConfirmation, showCelebration, showToast
  Key methods:
    canRedeem()          → checks PersistenceService used count vs totalUses
    selectCoupon()       → guard canRedeem → set state → haptic
    confirmRedemption()  → increment count → send SMS → celebration sequence
    sortedCoupons        → redeemable first
    availableCount       → count of redeemable coupons

Coupon model: 10 hardcoded coupons with stable UUID literals
  Redemption: sms:+16107049840&body=<coupon name>
```

## Onboarding

```
OnboardingView (299 lines)
  Phase A: title screen ("黄理央")
  Phase B: 6 bilingual messages with growing star brightness
  Phase C: transition (cosmic gradient rises, posts .onboardingWillDismiss, sets hasCompletedOnboarding)

Gate: @AppStorage("hasCompletedOnboarding") in TessasaurusApp
```
