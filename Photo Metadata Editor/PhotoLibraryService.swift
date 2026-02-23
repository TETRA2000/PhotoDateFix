import Foundation
import Photos
import ImageIO
import UIKit

@Observable
@MainActor
final class PhotoLibraryService {

    enum AuthorizationStatus {
        case notDetermined
        case authorized
        case limited
        case denied
    }

    enum ScanState {
        case idle
        case scanning(progress: Double)
        case completed
        case error(String)
    }

    private(set) var authorizationStatus: AuthorizationStatus = .notDetermined
    private(set) var scanState: ScanState = .idle
    private(set) var mismatchedPhotos: [PhotoAssetItem] = []
    private(set) var totalPhotosScanned: Int = 0

    /// Tolerance in seconds for date comparison to avoid false positives from rounding
    var dateTolerance: TimeInterval = 2.0

    // MARK: - Authorization

    func checkAuthorization() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        updateAuthStatus(status)
    }

    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        updateAuthStatus(status)
    }

    private func updateAuthStatus(_ status: PHAuthorizationStatus) {
        switch status {
        case .authorized:
            authorizationStatus = .authorized
        case .limited:
            authorizationStatus = .limited
        case .denied, .restricted:
            authorizationStatus = .denied
        case .notDetermined:
            authorizationStatus = .notDetermined
        @unknown default:
            authorizationStatus = .denied
        }
    }

    // MARK: - Scanning

    func scanForMismatches() async {
        scanState = .scanning(progress: 0)
        mismatchedPhotos = []
        totalPhotosScanned = 0

        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = false }

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        let totalCount = fetchResult.count
        guard totalCount > 0 else {
            scanState = .completed
            return
        }

        var results: [PhotoAssetItem] = []

        for i in 0..<totalCount {
            let asset = fetchResult.object(at: i)

            if let exifDate = await extractExifDate(from: asset),
               let photosDate = asset.creationDate {
                let diff = abs(exifDate.timeIntervalSince(photosDate))
                if diff > dateTolerance {
                    let item = PhotoAssetItem(
                        id: asset.localIdentifier,
                        asset: asset,
                        photosDate: photosDate,
                        exifDate: exifDate
                    )
                    results.append(item)
                }
            }

            totalPhotosScanned = i + 1
            if (i + 1) % 10 == 0 || i == totalCount - 1 {
                scanState = .scanning(progress: Double(i + 1) / Double(totalCount))
                mismatchedPhotos = results
            }
        }

        mismatchedPhotos = results
        scanState = .completed
    }

    // MARK: - EXIF Date Extraction

    private func extractExifDate(from asset: PHAsset) async -> Date? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.version = .original
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, _ in
                guard let data else {
                    continuation.resume(returning: nil)
                    return
                }

                let date = Self.exifDateFromImageData(data)
                continuation.resume(returning: date)
            }
        }
    }

    private static func exifDateFromImageData(_ data: Data) -> Date? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
              let dateString = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String
        else {
            return nil
        }

        // EXIF date format: "2024:01:15 14:30:00"
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Check for timezone offset in EXIF
        if let offsetString = exifDict[kCGImagePropertyExifOffsetTimeOriginal as String] as? String {
            formatter.timeZone = Self.timeZone(from: offsetString)
        } else {
            // Fall back to the device's current timezone if no offset is stored
            formatter.timeZone = .current
        }

        return formatter.date(from: dateString)
    }

    private static func timeZone(from offsetString: String) -> TimeZone? {
        // Offset format: "+09:00" or "-05:00"
        let cleaned = offsetString.replacingOccurrences(of: ":", with: "")
        guard cleaned.count >= 3 else { return nil }

        let sign: Int = cleaned.hasPrefix("-") ? -1 : 1
        let digits = cleaned.dropFirst()
        guard let value = Int(digits) else { return nil }

        let hours = value / 100
        let minutes = value % 100
        let totalSeconds = sign * (hours * 3600 + minutes * 60)

        return TimeZone(secondsFromGMT: totalSeconds)
    }

    // MARK: - Fixing Dates

    func fixDates(for items: [PhotoAssetItem]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            for item in items {
                let request = PHAssetChangeRequest(for: item.asset)
                request.creationDate = item.exifDate
            }
        }

        // Update local state: remove fixed items
        let fixedIDs = Set(items.map(\.id))
        mismatchedPhotos.removeAll { fixedIDs.contains($0.id) }
    }

    // MARK: - Selection

    func toggleSelection(for id: String) {
        guard let index = mismatchedPhotos.firstIndex(where: { $0.id == id }) else { return }
        mismatchedPhotos[index].isSelected.toggle()
    }

    func selectAll() {
        for i in mismatchedPhotos.indices {
            mismatchedPhotos[i].isSelected = true
        }
    }

    func deselectAll() {
        for i in mismatchedPhotos.indices {
            mismatchedPhotos[i].isSelected = false
        }
    }

    var selectedItems: [PhotoAssetItem] {
        mismatchedPhotos.filter(\.isSelected)
    }

    var allSelected: Bool {
        !mismatchedPhotos.isEmpty && mismatchedPhotos.allSatisfy(\.isSelected)
    }
}
