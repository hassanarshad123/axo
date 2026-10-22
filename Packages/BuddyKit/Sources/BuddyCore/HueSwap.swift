import Foundation

/// A color with red, green and blue from 0 to 1 (sRGB, as stored in the PNG files).
public struct PixelColor: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let black = PixelColor(red: 0, green: 0, blue: 0)

    /// HSV: hue in degrees (0 ..< 360), saturation and value from 0 to 1.
    public init(hue: Double, saturation: Double, value: Double) {
        let sector = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
        let chroma = value * saturation
        let second = chroma * (1 - abs(sector.truncatingRemainder(dividingBy: 2) - 1))
        let low = value - chroma
        let (red, green, blue): (Double, Double, Double) =
            switch Int(sector) {
            case 0: (chroma, second, 0)
            case 1: (second, chroma, 0)
            case 2: (0, chroma, second)
            case 3: (0, second, chroma)
            case 4: (second, 0, chroma)
            default: (chroma, 0, second)
            }
        self.init(red: red + low, green: green + low, blue: blue + low)
    }

    public var value: Double { max(red, green, blue) }

    public var saturation: Double {
        let high = value
        return high > 0 ? (high - min(red, green, blue)) / high : 0
    }

    /// Hue in degrees (0 ..< 360). 0 for a gray.
    public var hue: Double {
        let high = value
        let chroma = high - min(red, green, blue)
        guard chroma > 0 else { return 0 }
        let sector: Double =
            if high == red {
                ((green - blue) / chroma).truncatingRemainder(dividingBy: 6)
            } else if high == green {
                (blue - red) / chroma + 2
            } else {
                (red - green) / chroma + 4
            }
        let degrees = sector * 60
        return degrees < 0 ? degrees + 360 : degrees
    }
}

/// Recolors a buddy: its main color turns to another hue, everything else stays.
///
///     hue within `tolerance` of `centerHue`? ─┐
///     saturation ≥ `minimumSaturation`?      ├─ all yes ──▶ turn by (target - source)
///     value ≥ `minimumValue`?                ─┘  any no ──▶ keep (eyes, skin, blush, white, outlines)
///
/// Each test has a soft edge (`hueFeather`, `saturationFeather`, `valueFeather`): a pixel just inside
/// an edge turns only part of the way. With hard edges, single pixels turned on Shelly's spots (flecks).
///
/// The default window is 30 degrees, not 40: skin (hue 15 to 20) is 30 to 35 degrees from a pink
/// main hue (345) and must not turn. Each buddy can set its own window and limits in `catalog.json`
/// (written from `design/buddies/buddy-settings.json`), for example Neko's minimum saturation keeps
/// its pink ears and cream face while the orange patches turn.
public struct HueSwap: Sendable, Hashable {
    public static let defaultTolerance: Double = 30
    /// Below this the pixel is white, gray or black, and keeps its color.
    public static let defaultMinimumSaturation: Double = 0.12
    /// Widths of the soft edges: degrees of hue, then saturation and value (0 to 1).
    static let hueFeather: Double = 8
    static let saturationFeather: Double = 0.06
    static let valueFeather: Double = 0.08

    /// The turn is (target - source), the short way round the color wheel.
    public let sourceHue: Double
    public let targetHue: Double
    /// The middle of the window of hues that turn. Usually the source hue.
    public let centerHue: Double
    public let tolerance: Double
    public let minimumSaturation: Double
    /// Darker pixels keep their color (eyes, outlines).
    public let minimumValue: Double

    public init(
        sourceHue: Double,
        targetHue: Double,
        centerHue: Double? = nil,
        tolerance: Double = defaultTolerance,
        minimumSaturation: Double = defaultMinimumSaturation,
        minimumValue: Double = 0
    ) {
        self.sourceHue = sourceHue
        self.targetHue = targetHue
        self.centerHue = centerHue ?? sourceHue
        self.tolerance = tolerance
        self.minimumSaturation = minimumSaturation
        self.minimumValue = minimumValue
    }

    /// Nil when the color keeps the art as drawn (`.original`).
    public init?(buddy: Buddy, color: BuddyColor) {
        guard let target = color.targetHue else { return nil }
        self.init(
            sourceHue: buddy.mainHue,
            targetHue: target,
            centerHue: buddy.hueCenter,
            tolerance: buddy.hueTolerance,
            minimumSaturation: buddy.minSaturation,
            minimumValue: buddy.minValue
        )
    }

    /// How far a color turns: 1 is the whole way, 0 keeps it, between is a soft edge.
    public func weight(of color: PixelColor) -> Double {
        Self.ramp(tolerance - Self.distance(color.hue, centerHue), over: Self.hueFeather)
            * Self.ramp(color.saturation - minimumSaturation, over: Self.saturationFeather)
            * Self.ramp(color.value - minimumValue, over: Self.valueFeather)
    }

    public func apply(_ color: PixelColor) -> PixelColor {
        let weight = weight(of: color)
        guard weight > 0 else { return color }
        let hue = color.hue + weight * Self.turn(from: sourceHue, to: targetHue)
        return PixelColor(hue: hue, saturation: color.saturation, value: color.value)
    }

    /// Recolors a picture given as premultiplied RGBA bytes (8 bits each, as Core Graphics draws them).
    /// Alpha never changes. Each distinct pixel is worked out once, so a palette sprite (about 130 colors)
    /// costs about 130 `apply` calls.
    ///
    /// Exact per pixel. A Core Image color cube was tried first: its blending between table points
    /// half-turned the colors at the edge of the hue window (about 10% of Axo's pixels).
    public func recolored(premultipliedRGBA pixels: [UInt8]) -> [UInt8] {
        var output = pixels
        var known: [UInt32: (UInt8, UInt8, UInt8)] = [:]
        for index in stride(from: 0, to: pixels.count - 3, by: 4) {
            let alpha = pixels[index + 3]
            guard alpha > 0 else { continue }
            let key =
                UInt32(pixels[index]) << 24 | UInt32(pixels[index + 1]) << 16 | UInt32(pixels[index + 2]) << 8
                | UInt32(alpha)
            let turned = known[key] ?? turnedPixel(pixels[index], pixels[index + 1], pixels[index + 2], alpha: alpha)
            known[key] = turned
            (output[index], output[index + 1], output[index + 2]) = turned
        }
        return output
    }

    private func turnedPixel(_ red: UInt8, _ green: UInt8, _ blue: UInt8, alpha: UInt8) -> (UInt8, UInt8, UInt8) {
        let scale = Double(alpha)
        func unpremultiplied(_ channel: UInt8) -> Double { min(1, Double(channel) / scale) }
        func premultiplied(_ channel: Double) -> UInt8 { UInt8((min(1, max(0, channel)) * scale).rounded()) }
        let source = PixelColor(red: unpremultiplied(red), green: unpremultiplied(green), blue: unpremultiplied(blue))
        let color = apply(source)
        return (premultiplied(color.red), premultiplied(color.green), premultiplied(color.blue))
    }

    /// Distance between two hues on the color wheel, 0 to 180 degrees.
    static func distance(_ first: Double, _ second: Double) -> Double {
        let difference = abs(first - second).truncatingRemainder(dividingBy: 360)
        return min(difference, 360 - difference)
    }

    /// The short way round the color wheel from one hue to another: -180 (exclusive) to 180 degrees.
    static func turn(from source: Double, to target: Double) -> Double {
        let difference = (target - source).truncatingRemainder(dividingBy: 360)
        if difference > 180 { return difference - 360 }
        if difference <= -180 { return difference + 360 }
        return difference
    }

    /// 0 at or below 0, rising in a straight line to 1 at `band`.
    static func ramp(_ amount: Double, over band: Double) -> Double {
        amount <= 0 ? 0 : min(1, amount / band)
    }
}
