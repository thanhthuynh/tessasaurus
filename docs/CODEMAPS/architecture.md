<!-- Generated: 2026-03-28 | Files scanned: 33 | Token estimate: ~900 -->

# Architecture

## App Structure

```
TessasaurusApp (@main)
  ├── OnboardingView (overlay, gated by @AppStorage "hasCompletedOnboarding")
  └── ContentView
      ├── PhotoWallView       [tab 0, opacity-switched]
      ├── CouponsView         [tab 1, opacity-switched]
      └── FloatingTabBar      [hides when photo detail is open]
```

## Data Flow

```
CloudKit (publicCloudDatabase)
  └── CloudKitPhotoService.shared
        ├── fetchAllPhotos() → paginated CKQuery with cursor
        ├── uploadPhoto()    → CKRecord + CKAsset
        └── subscribeToChanges() → push → AppDelegate → .photosDidUpdate notification

PhotoStorageService.shared
  ├── Documents/Photos/<uuid>.jpg        (full-res)
  ├── Documents/Thumbnails/<uuid>.jpg    (thumbnails)
  └── Documents/photos_metadata.json     ([Photo] JSON, atomic writes)

ImageCacheService.shared
  ├── thumbnailCache (NSCache, 200 items / 30 MB)
  └── fullResCache   (NSCache, 10 items / 50 MB)

Image Loading (PhotoWallViewModel.loadImageAsync):
  1. Memory thumbnail cache  → instant
  2. Disk thumbnail          → Task.detached
  3. Disk full-res           → Task.detached + generate thumbnail
  4. CloudKit fetch          → network fallback
```

## Service Dependencies

```
PhotoWallViewModel
  ├── CloudKitPhotoService.shared
  ├── PhotoStorageService.shared
  ├── ImageCacheService.shared
  └── UserDefaults (isUploaderMode)

CouponsViewModel
  ├── PersistenceService (injected)
  └── HapticService.shared

CloudKitPhotoService → PhotoStorageService (saves downloaded images)
```

## Key Patterns

- `@Observable` + `@MainActor` on async ViewModels
- Singleton services via `static let shared`
- ID-based selection (`selectedPhotoID: UUID?`, derive object from array)
- `os.Logger` for structured logging
- `UUID.stableHash` for deterministic per-launch-stable hashing
- DI via init params with defaults for testability
- Optimistic updates with rollback on CloudKit failure
