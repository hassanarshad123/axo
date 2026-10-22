import AppKit
import BuddyCore

@testable import NotchUI

/// The pixels of a picture as plain sRGB numbers, for tests.
/// (`NSBitmapImageRep.colorAt` can report "Generic RGB" and shift the numbers, so it is not used.)
struct SpritePixels {
    private let bitmap: RGBABitmap

    var width: Int { bitmap.width }
    var height: Int { bitmap.height }

    init?(_ image: NSImage?) {
        guard let picture = image?.cgImage(forProposedRect: nil, context: nil, hints: nil),
            let bitmap = RGBABitmap(picture)
        else { return nil }
        self.bitmap = bitmap
    }

    func alpha(x: Int, y: Int) -> Double {
        Double(bitmap.bytes[(y * width + x) * 4 + 3]) / 255
    }

    /// The color without its alpha. Nil for a fully see-through pixel.
    func color(x: Int, y: Int) -> PixelColor? {
        let index = (y * width + x) * 4
        let alpha = Double(bitmap.bytes[index + 3])
        guard alpha > 0 else { return nil }
        return PixelColor(
            red: Double(bitmap.bytes[index]) / alpha,
            green: Double(bitmap.bytes[index + 1]) / alpha,
            blue: Double(bitmap.bytes[index + 2]) / alpha)
    }

    /// The largest difference in red, green or blue.
    static func difference(_ first: PixelColor, _ second: PixelColor) -> Double {
        max(abs(first.red - second.red), abs(first.green - second.green), abs(first.blue - second.blue))
    }
}
