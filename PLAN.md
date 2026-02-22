# Photo Metadata Editor - Implementation Plan

## Problem

When photos are imported to the Mac Photos app via USB (not iCloud sync), any date/time adjustments made on iPhone are lost. The Photos app `creationDate` reverts to the original file's EXIF `DateTimeOriginal`, discarding user edits. This app will help identify and fix these mismatched dates.

## Architecture Overview

The app will use **PhotoKit** (`Photos` framework) to access the user's photo library and **ImageIO** to read EXIF metadata from the original image data. It compares `PHAsset.creationDate` (the date Photos app shows) against the EXIF `DateTimeOriginal` embedded in the image file. When these differ, the photo is flagged as having a date mismatch.

The existing SwiftData `Item` model and boilerplate will be replaced with PhotoKit-based views.

## Implementation Steps

### Step 1: Project Configuration

- Add `NSPhotoLibraryUsageDescription` to Info.plist (required for Photos access)
- Remove the SwiftData `Item` model and related code (unused boilerplate)

### Step 2: Photo Library Service (`PhotoLibraryService.swift`)

Create an `@Observable` class that handles all PhotoKit interactions:

- **Authorization**: Request read-write access to the photo library via `PHPhotoLibrary.requestAuthorization(for: .readWrite)`
- **Fetch all image assets**: Use `PHAsset.fetchAssets(with: .image, options:)` sorted by `creationDate`
- **Extract EXIF date**: For each asset, use `PHImageManager.requestImageDataAndOrientation(for:options:)` to get the image data, then use `CGImageSourceCreateWithData` + `CGImageSourceCopyPropertiesAtIndex` to read `kCGImagePropertyExifDictionary` → `kCGImagePropertyExifDateTimeOriginal`
- **Compare dates**: Flag assets where `PHAsset.creationDate` differs from the EXIF `DateTimeOriginal` (with a configurable tolerance, e.g. 2 seconds, to avoid false positives from rounding)
- **Fix dates**: Use `PHPhotoLibrary.shared().performChanges` with `PHAssetChangeRequest(for: asset)` and set `creationDate` to the EXIF original date

### Step 3: Data Model (`PhotoAssetItem.swift`)

A lightweight struct to represent a photo with mismatched metadata:

```swift
struct PhotoAssetItem: Identifiable {
    let id: String              // PHAsset.localIdentifier
    let asset: PHAsset
    let photosDate: Date        // PHAsset.creationDate (what Photos shows)
    let exifDate: Date          // EXIF DateTimeOriginal (the true original)
    var isSelected: Bool
}
```

### Step 4: Main View - Photo List (`ContentView.swift`)

Replace the current SwiftData boilerplate with:

- **Authorization prompt**: Show a request-access screen if not authorized
- **Loading state**: Show a progress indicator while scanning the library
- **Photo list**: Display only photos with date mismatches in a `List`
  - Each row shows: thumbnail, filename, Photos date, EXIF date, and the time difference
  - Multi-selection support via checkboxes
- **Toolbar actions**:
  - "Select All" / "Deselect All" toggle
  - "Fix Selected" button to batch-update `creationDate` on selected assets
  - Scan/refresh button
- **Empty state**: Message when no mismatches are found

### Step 5: Photo Row View (`PhotoRowView.swift`)

A row component showing:
- Thumbnail image (loaded via `PHImageManager.requestImage`)
- Photos date vs EXIF original date, both formatted
- Time difference (e.g., "+3h 20m" or "−1 day")
- Selection checkbox

### Step 6: Detail View (`PhotoDetailView.swift`)

When a photo is tapped, show:
- Larger preview image
- Full metadata comparison (Photos date, EXIF date, difference)
- Individual "Fix Date" button

### Step 7: App Entry Point Update (`Photo_Metadata_EditorApp.swift`)

- Remove `ModelContainer` / SwiftData setup
- Inject the `PhotoLibraryService` into the environment

## Key Technical Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Date comparison tolerance | 2 seconds | Avoids false positives from sub-second rounding between EXIF strings and Date objects |
| EXIF reading method | `PHImageManager.requestImageDataAndOrientation` + ImageIO | Reads EXIF directly from original image data without needing file system access |
| Date fix method | `PHAssetChangeRequest.creationDate = exifDate` | Sets the Photos creation date to match the EXIF original; this is the standard PhotoKit approach |
| Scanning approach | On-demand (user presses scan) | Avoids scanning the entire library on every launch; user controls when to scan |
| State management | `@Observable` class | Modern Swift observation, no Combine needed |

## File Changes Summary

| File | Action |
|---|---|
| `Item.swift` | **Delete** (SwiftData model no longer needed) |
| `Photo_Metadata_EditorApp.swift` | **Modify** (remove SwiftData, add PhotoLibraryService) |
| `ContentView.swift` | **Rewrite** (photo mismatch list with multi-select) |
| `PhotoLibraryService.swift` | **New** (PhotoKit + EXIF reading + date fixing) |
| `PhotoAssetItem.swift` | **New** (data model for mismatched photos) |
| `PhotoRowView.swift` | **New** (list row component) |
| `PhotoDetailView.swift` | **New** (detail view with full metadata) |
| `Info.plist` | **Modify** (add NSPhotoLibraryUsageDescription) |
