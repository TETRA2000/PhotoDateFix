import SwiftUI
import Photos

struct PhotoDetailView: View {
    let item: PhotoAssetItem
    let onFix: () -> Void

    @State private var image: UIImage?
    @State private var isFixing = false
    @State private var showFixConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.quaternary)
                        .frame(height: 300)
                        .overlay {
                            ProgressView()
                        }
                }

                VStack(spacing: 16) {
                    dateRow(label: "Photos Date", date: item.photosDate, color: .primary)
                    dateRow(label: "EXIF Original Date", date: item.exifDate, color: .blue)

                    HStack {
                        Text("Difference")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(item.formattedTimeDifference)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                    .padding()
                    .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal)

                Button {
                    showFixConfirmation = true
                } label: {
                    Label("Fix Date to EXIF Original", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isFixing)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Photo Details")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Fix Photo Date",
            isPresented: $showFixConfirmation,
            titleVisibility: .visible
        ) {
            Button("Set date to \(item.exifDate.formatted(.dateTime))") {
                Task {
                    isFixing = true
                    onFix()
                    isFixing = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will change the photo's date from \(item.photosDate.formatted(.dateTime)) to \(item.exifDate.formatted(.dateTime)).")
        }
        .task {
            await loadImage()
        }
    }

    private func dateRow(label: String, date: Date, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(date, format: .dateTime)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
        .padding()
        .background(.fill.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private func loadImage() async {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true

        image = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: item.asset,
                targetSize: CGSize(width: 800, height: 800),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}
