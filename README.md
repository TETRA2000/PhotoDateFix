# PhotoDateFix

An iOS app that detects and fixes photos whose dates were incorrectly changed during import to the Photos app.

## Problem

When photos are imported to the Mac Photos app via USB (rather than iCloud sync), any date/time adjustments previously made on iPhone are lost. The Photos app reverts the `creationDate` to the file's original EXIF `DateTimeOriginal`, discarding user edits. See [Reddit thread](https://www.reddit.com/r/ApplePhotos/comments/1giucci/imported_photos_wrong_date_different_than_similar/) for context.

## How It Works

1. **Filter (optional)** — Set a date range before scanning to limit which photos are fetched. This avoids costly iCloud downloads for photos outside the range of interest.
2. **Scan** — The app fetches image assets from the photo library using PhotoKit, reads each image's EXIF `DateTimeOriginal` via ImageIO, and compares it against the `PHAsset.creationDate` that Photos displays. Photos differing by more than 2 seconds are flagged as mismatched.
3. **Review** — Mismatched photos are shown in a list with thumbnails, both dates, and the time difference. Tap a photo to see a detailed comparison. The date range filter can also be applied after scanning to narrow the results.
4. **Fix** — Select one or more photos and batch-update their `creationDate` to match the original EXIF date using `PHAssetChangeRequest`.

## Project Structure

```
PhotoDateFix/
  PhotoDateFixApp.swift           — App entry point
  ContentView.swift               — Main view: auth flow, scan, results list, filter, toolbar
  PhotoLibraryService.swift       — PhotoKit authorization, EXIF scanning, date filtering, date fixing
  PhotoAssetItem.swift            — Data model for a photo with mismatched dates
  PhotoRowView.swift              — List row: thumbnail, dates, selection checkbox
  PhotoDetailView.swift           — Detail view: larger preview, full date comparison
```

## Key Frameworks

- **PhotoKit** (`Photos`) — Access photo library, fetch assets, modify creation dates
- **ImageIO** — Read EXIF metadata (`DateTimeOriginal`, `OffsetTimeOriginal`) from image data
- **SwiftUI** — User interface

## Requirements

- iOS 17.0+
- Xcode 16.0+
- Photo Library access (read/write)
