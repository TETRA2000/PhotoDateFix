import Foundation
import Photos

struct PhotoAssetItem: Identifiable {
    let id: String
    let asset: PHAsset
    let photosDate: Date
    let exifDate: Date
    var isSelected: Bool = false

    var timeDifference: TimeInterval {
        exifDate.timeIntervalSince(photosDate)
    }

    var formattedTimeDifference: String {
        let diff = timeDifference
        let absDiff = abs(diff)
        let sign = diff < 0 ? "−" : "+"

        let days = Int(absDiff) / 86400
        let hours = (Int(absDiff) % 86400) / 3600
        let minutes = (Int(absDiff) % 3600) / 60
        let seconds = Int(absDiff) % 60

        if days > 0 {
            return "\(sign)\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(sign)\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(sign)\(minutes)m \(seconds)s"
        } else {
            return "\(sign)\(seconds)s"
        }
    }
}
