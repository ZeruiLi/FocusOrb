import AppKit
import SwiftUI

enum BundledImage {
    static func nsImage(named name: String, fileExtension: String = "png", subdirectory: String? = nil) -> NSImage? {
        let url = Bundle.module.url(forResource: name, withExtension: fileExtension, subdirectory: subdirectory)
            ?? Bundle.module.url(forResource: name, withExtension: fileExtension)
        guard let url else { return nil }
        return NSImage(contentsOf: url)
    }

    static func swiftUIImage(named name: String, fileExtension: String = "png", subdirectory: String? = nil) -> Image? {
        guard let nsImage = nsImage(named: name, fileExtension: fileExtension, subdirectory: subdirectory) else { return nil }
        return Image(nsImage: nsImage)
    }
}
