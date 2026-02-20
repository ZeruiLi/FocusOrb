import Foundation
import AppKit
import UniformTypeIdentifiers

final class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    private var pollTimer: Timer?
    private var lastChangeCount: Int
    private var ignoredChangeCountOnce: Int?

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.pollPasteboard()
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func syncWithSettings() {
        if AppSettings.shared.enableClips && !AppSettings.shared.pauseClips {
            start()
        } else {
            stop()
        }
    }

    func markInternalCopy(changeCount: Int) {
        ignoredChangeCountOnce = changeCount
    }

    private func pollPasteboard() {
        let pasteboard = NSPasteboard.general
        let currentChange = pasteboard.changeCount
        guard currentChange != lastChangeCount else { return }
        lastChangeCount = currentChange

        if let ignoredChangeCountOnce, ignoredChangeCountOnce == currentChange {
            self.ignoredChangeCountOnce = nil
            return
        }
        ignoredChangeCountOnce = nil

        if let imagePayload = imagePayload(from: pasteboard) {
            CaptureStore.shared.addImageClip(
                data: imagePayload.data,
                preferredExtension: imagePayload.fileExtension
            )
            return
        }

        guard let copiedText = pasteboard.string(forType: .string) else { return }

        CaptureStore.shared.addClip(content: copiedText)
    }

    private func imagePayload(from pasteboard: NSPasteboard) -> (data: Data, fileExtension: String)? {
        if let payload = imagePayloadFromFileURL(pasteboard) {
            return payload
        }

        if
            let image = (pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage])?.first,
            let data = pngData(from: image)
        {
            return (data: data, fileExtension: "png")
        }

        if
            let tiffData = pasteboard.data(forType: .tiff),
            let bitmap = NSBitmapImageRep(data: tiffData),
            let data = bitmap.representation(using: .png, properties: [:])
        {
            return (data: data, fileExtension: "png")
        }

        return nil
    }

    private func imagePayloadFromFileURL(_ pasteboard: NSPasteboard) -> (data: Data, fileExtension: String)? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]

        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else {
            return nil
        }

        for url in urls {
            let ext = url.pathExtension.lowercased()
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            guard
                !ext.isEmpty,
                let type = UTType(filenameExtension: ext),
                type.conforms(to: .image),
                let data = try? Data(contentsOf: url),
                !data.isEmpty
            else {
                continue
            }
            return (data: data, fileExtension: ext)
        }

        return nil
    }

    private func pngData(from image: NSImage) -> Data? {
        guard
            let tiffData = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiffData)
        else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
