<!-- Generated: 2026-03-30 | Files scanned: 38 | Token estimate: ~900 -->

# Architecture

## App Structure

```
TessasaurusApp (@main)
  ├── AppDelegate → FirebaseApp.configure()
  ├── OnboardingView (overlay, gated by @AppStorage "hasCompletedOnboarding")
  └── ContentView
      ├── PhotoWallView       [tab 0, opacity-switched]
      ├── CouponsView         [tab 1, opacity-switched]
      └── FloatingTabBar      [hides when photo detail is open]
```

## Data Flow

```
Firebase (Firestore + Firebase Storage)
  └── FirebasePhotoService.shared
        ├── ensureAuthenticated() → anonymous sign-in (Auth.auth)
        ├── fetchAllPhotos()      → Firestore query ordered by createdAt desc
        ├── uploadPhoto()         → Storage.putDataAsync + Firestore.setData
        ├── startListening()      → Firestore addSnapshotListener (delta sync)
        ├── deletePhoto()         → Firestore.delete + Storage.delete
        ├── updatePhotoCaption()  → Firestore.updateData
        └── updatePhotoBubbleSize() → Firestore.updateData

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
  4. Firebase Storage fetch  → network fallback
```

## Service Dependencies

```
PhotoWallViewModel
  ├── FirebasePhotoService.shared
  ├── PhotoStorageService.shared
  ├── ImageCacheService.shared
  └── UserDefaults (isUploaderMode)

CouponsViewModel
  ├── PersistenceService (injected)
  └── HapticService.shared

FirebasePhotoService → PhotoStorageService (saves downloaded images locally)
FirebasePhotoService → FirebaseAuth (anonymous sign-in before any network op)
```

## Firebase Error Types

```
FirebasePhotoError (LocalizedError)
  ├── imageCompressionFailed
  ├── notAuthenticated
  ├── uploadFailed(message: String)
  ├── downloadFailed(message: String)
  └── serviceUnavailable
```

## Key Patterns

- `@Observable` + `@MainActor` on async ViewModels
- Singleton services via `static let shared`
- Firebase anonymous auth — invisible to user, fires on first `loadPhotos()`
- Firestore snapshot listener for real-time delta sync (added/modified/removed)
- Optimistic updates with rollback on Firebase failure
- ID-based selection (`selectedPhotoID: UUID?`, derive object from array)
- `os.Logger` for structured logging
- `UUID.stableHash` for deterministic per-launch-stable hashing
- DI via init params with defaults for testability
- No APNs or CloudKit entitlements
