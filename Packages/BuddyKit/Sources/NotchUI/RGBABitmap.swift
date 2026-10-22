import CoreGraphics
import Foundation

/// A picture as premultiplied sRGB RGBA bytes: 8 bits each, top row first.
/// This is the form `HueSwap.recolored(premultipliedRGBA:)` works on.
struct RGBABitmap: Sendable, Equatable {
    let width: Int
    let height: Int
    let bytes: [UInt8]

    private static let alphaInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    init(width: Int, height: Int, bytes: [UInt8]) {
        self.width = width
        self.height = height
        self.bytes = bytes
    }

    /// Draws the picture 1:1 into sRGB bytes. Nil if Core Graphics cannot draw it.
    init?(_ image: CGImage) {
        guard let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let width = image.width
        let height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = data.withUnsafeMutableBytes { buffer in
            guard
                let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: sRGB, bitmapInfo: Self.alphaInfo)
            else { return false }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        self.init(width: width, height: height, bytes: data)
    }

    func makeImage() -> CGImage? {
        guard bytes.count == width * height * 4,
            let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
            let provider = CGDataProvider(data: Data(bytes) as CFData)
        else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: sRGB, bitmapInfo: CGBitmapInfo(rawValue: Self.alphaInfo), provider: provider,
            decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
