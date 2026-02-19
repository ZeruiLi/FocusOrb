import AppKit
import SwiftUI

enum BundledImage {
    private static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }

    static func nsImage(named name: String, fileExtension: String = "png", subdirectory: String? = nil) -> NSImage? {
        let url = resourceBundle.url(forResource: name, withExtension: fileExtension, subdirectory: subdirectory)
            ?? resourceBundle.url(forResource: name, withExtension: fileExtension)
        guard let url else { return nil }
        return NSImage(contentsOf: url)
    }

    static func swiftUIImage(named name: String, fileExtension: String = "png", subdirectory: String? = nil) -> Image? {
        guard let nsImage = nsImage(named: name, fileExtension: fileExtension, subdirectory: subdirectory) else { return nil }
        return Image(nsImage: nsImage)
    }
}
