import XCTest
@testable import FocusOrb

final class ClipItemTests: XCTestCase {
    func testDefaultsToTextClip() {
        let item = ClipItem(content: "hello")

        XCTAssertEqual(item.kind, .text)
        XCTAssertNil(item.imagePath)
        XCTAssertFalse(item.isImage)
    }

    func testImageClipStoresPath() {
        let item = ClipItem(
            content: "",
            kind: .image,
            imagePath: "  /tmp/focusorb-image.png  "
        )

        XCTAssertEqual(item.kind, .image)
        XCTAssertTrue(item.isImage)
        XCTAssertEqual(item.imagePath, "/tmp/focusorb-image.png")
    }

    func testEmptyImagePathNormalizesToNil() {
        let item = ClipItem(
            content: "",
            kind: .image,
            imagePath: "   "
        )

        XCTAssertNil(item.imagePath)
    }
}
