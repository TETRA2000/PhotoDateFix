import SwiftUI
import Photos

struct PhotoRowView: View {
    let item: PhotoAssetItem
    let isSelected: Bool
    let onToggleSelection: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggleSelection) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 60, height: 60)
                    .overlay {
                        ProgressView()
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Photos:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.photosDate, format: .dateTime)
                        .font(.caption)
                }
                HStack {
                    Text("EXIF:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.exifDate, format: .dateTime)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                Text(item.formattedTimeDifference)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 4)
        .task {
            await loadThumbnail()
        }
    }

    private func loadThumbnail() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true

        thumbnail = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: item.asset,
                targetSize: CGSize(width: 120, height: 120),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded {
                    continuation.resume(returning: image)
                }
            }
        }
    }
}
