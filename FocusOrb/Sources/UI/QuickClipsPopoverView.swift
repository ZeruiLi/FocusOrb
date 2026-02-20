import SwiftUI
import AppKit

struct QuickClipsPopoverView: View {
    @ObservedObject var captureStore: CaptureStore
    let onClose: () -> Void

    private var recentClips: [ClipItem] {
        captureStore.recentClips(limit: 12)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.string("Quick Clips"))
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                Spacer()
                Button(L10n.string("Close"), action: onClose)
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }

            if recentClips.isEmpty {
                Text(L10n.string("No clips yet. Copy some text or image and it will appear here."))
                    .font(.caption)
                    .foregroundColor(AppTheme.Colors.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(recentClips) { clip in
                            clipRow(clip)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
        }
        .padding(14)
        .frame(width: 360)
        .background(Material.thin)
    }

    @ViewBuilder
    private func clipRow(_ clip: ClipItem) -> some View {
        HStack(spacing: 8) {
            Button {
                captureStore.copyClipToPasteboard(clip)
                onClose()
            } label: {
                HStack(spacing: 8) {
                    if clip.isImage {
                        Group {
                            if let path = clip.imagePath, let image = NSImage(contentsOfFile: path) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(Color.white.opacity(0.24))
                                    .overlay(
                                        Image(systemName: "photo")
                                            .foregroundColor(AppTheme.Colors.textMuted)
                                    )
                            }
                        }
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(L10n.string("Image Clip"))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(AppTheme.Colors.textPrimary)

                            if let path = clip.imagePath {
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                    .font(.system(size: 11, weight: .regular, design: .rounded))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .foregroundColor(AppTheme.Colors.textMuted)
                            }
                        }
                    } else {
                        Image(systemName: clip.isPinned ? "pin.fill" : "doc.on.doc")
                            .foregroundColor(clip.isPinned ? AppTheme.Colors.warmOrange : AppTheme.Colors.textMuted)
                            .frame(width: 14)

                        Text(clip.content)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.22))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                captureStore.setClipPinned(clipID: clip.id, isPinned: !clip.isPinned)
            } label: {
                Image(systemName: clip.isPinned ? "pin.slash" : "pin")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
    }
}
