import AppKit
import BuddyCore
import SwiftUI

/// The saved progress photos in a row, newest first. Each file loads once, when it scrolls into view.
struct PhotoStrip: View {
    let photos: [ProgressPhotoItem]

    var body: some View {
        if photos.isEmpty {
            Text("No photos yet. Axo saves one a day while you sit at the Mac.")
                .font(.callout).foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 10) {
                    ForEach(photos) { item in
                        PhotoThumbnail(item: item)
                    }
                }
            }
            .frame(height: 124)
        }
    }
}

private struct PhotoThumbnail: View {
    let item: ProgressPhotoItem
    @State private var image: NSImage?

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let image {
                    Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Color.secondary.opacity(0.15)
                }
            }
            .frame(width: 128, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(caption).font(.caption2).foregroundStyle(.secondary)
        }
        .task(id: item.url) { image = NSImage(contentsOf: item.url) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Progress photo, \(caption)"))
    }

    private var caption: String {
        let day = item.photo.day.formatted(.dateTime.month(.abbreviated).day())
        return item.photo.kind == .posture ? "\(day) · slouch" : day
    }
}
