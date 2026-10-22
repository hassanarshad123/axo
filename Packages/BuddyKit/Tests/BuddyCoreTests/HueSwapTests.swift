import Foundation
import Testing

@testable import BuddyCore

@Suite("HueSwap")
struct HueSwapTests {
    /// Axo pink (hue 345) to teal (hue 175).
    private let axoToTeal = HueSwap(sourceHue: 345, targetHue: 175, tolerance: 30)

    private func rgb(_ hex: UInt32) -> PixelColor {
        PixelColor(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    private func isClose(_ lhs: PixelColor, _ rhs: PixelColor) -> Bool {
        abs(lhs.red - rhs.red) < 0.002 && abs(lhs.green - rhs.green) < 0.002 && abs(lhs.blue - rhs.blue) < 0.002
    }

    @Test("The main color turns by (target - main hue) and keeps its lightness")
    func mainColorTurns() {
        let pink = rgb(0xF0_7286)  // hue 350.5
        let turned = axoToTeal.apply(pink)
        #expect(abs(turned.hue - 180.5) < 0.5)
        #expect(abs(turned.saturation - pink.saturation) < 0.001)
        #expect(abs(turned.value - pink.value) < 0.001)
    }

    @Test("Colors far from the main hue stay: skin, a teal scarf")
    func farColorsStay() {
        let skin = rgb(0xE8_A07A)  // hue about 20, 35 degrees from 345
        let scarf = rgb(0x61_A99C)  // hue 169
        #expect(axoToTeal.apply(skin) == skin)
        #expect(axoToTeal.apply(scarf) == scarf)
    }

    @Test("White, gray and black stay (too little color)")
    func grayStays() {
        for gray in [PixelColor(red: 1, green: 1, blue: 1), PixelColor(red: 0.5, green: 0.49, blue: 0.5), .black] {
            #expect(axoToTeal.apply(gray) == gray)
        }
        let paleWhite = rgb(0xE8_DADC)  // hue 351, saturation 0.06
        #expect(axoToTeal.apply(paleWhite) == paleWhite)
    }

    @Test("The hue window wraps around 0 / 360")
    func windowWraps() {
        let mochi = HueSwap(sourceHue: 355, targetHue: 95, tolerance: 30)
        let orangeRed = PixelColor(hue: 10, saturation: 0.5, value: 0.9)  // 15 degrees past 360
        #expect(abs(mochi.apply(orangeRed).hue - 110) < 0.5)
    }

    @Test("Original color means no swap")
    func originalIsNil() {
        let axo = Buddy(id: "25-axo-axolotl", number: 25, name: "Axo", mainHue: 345)
        #expect(HueSwap(buddy: axo, color: .original) == nil)
        #expect(HueSwap(buddy: axo, color: .teal)?.targetHue == 175)
        #expect(HueSwap(buddy: axo, color: .teal)?.tolerance == HueSwap.defaultTolerance)
    }

    @Test("HSV round trip")
    func hsvRoundTrip() {
        for hex: UInt32 in [0xF0_7286, 0x61_A99C, 0xFF_C63C, 0x08_3F40, 0x0A_0213] {
            let color = rgb(hex)
            #expect(isClose(PixelColor(hue: color.hue, saturation: color.saturation, value: color.value), color))
        }
    }

    @Test("Pixels: the main color turns, other colors and every alpha stay, see-through stays see-through")
    func recolorsPixels() {
        let pixels: [UInt8] = [
            0xF0, 0x72, 0x86, 0xFF,  // Axo pink, solid
            0xE8, 0xA0, 0x7A, 0xFF,  // skin
            0x00, 0x00, 0x00, 0x00,  // see-through
            0x78, 0x39, 0x43, 0x80,  // the pink at half alpha (premultiplied)
            0xFF, 0xFF, 0xFF, 0xFF,  // white
        ]
        let result = axoToTeal.recolored(premultipliedRGBA: pixels)
        #expect(result.count == pixels.count)
        #expect(stride(from: 3, to: result.count, by: 4).allSatisfy { result[$0] == pixels[$0] })

        let turned = color(result, at: 0, alpha: 255)
        #expect(abs(turned.hue - 180.5) < 1.5)
        #expect(Array(result[4..<8]) == Array(pixels[4..<8]))
        #expect(Array(result[8..<12]) == [0, 0, 0, 0])
        #expect(Array(result[16..<20]) == Array(pixels[16..<20]))

        // Half alpha: the same turn, at half strength. Premultiplied values never go above alpha.
        let half = color(result, at: 12, alpha: 128)
        #expect(abs(half.hue - 180.5) < 3)
        #expect(result[12...14].allSatisfy { $0 <= 0x80 })
    }

    /// The pixel at a byte index, without its alpha.
    private func color(_ pixels: [UInt8], at index: Int, alpha: Double) -> PixelColor {
        PixelColor(
            red: Double(pixels[index]) / alpha,
            green: Double(pixels[index + 1]) / alpha,
            blue: Double(pixels[index + 2]) / alpha
        )
    }

    @Test("Soft edges: a color just inside an edge turns only part of the way")
    func softEdges() {
        // Hue 12 is 27 degrees from 345: 3 of the 8 feather degrees inside the window.
        #expect(abs(axoToTeal.weight(of: PixelColor(hue: 12, saturation: 0.6, value: 0.9)) - 0.375) < 0.001)
        #expect(abs(axoToTeal.apply(PixelColor(hue: 12, saturation: 0.6, value: 0.9)).hue - 308.25) < 0.5)
        // Saturation 0.15 is 0.03 above the 0.12 limit: half of the 0.06 feather.
        #expect(abs(axoToTeal.weight(of: PixelColor(hue: 345, saturation: 0.15, value: 0.9)) - 0.5) < 0.001)
        #expect(axoToTeal.weight(of: PixelColor(hue: 345, saturation: 0.6, value: 0.9)) == 1)
        #expect(axoToTeal.weight(of: PixelColor(hue: 20, saturation: 0.6, value: 0.9)) == 0)
    }

    @Test("Dark pixels below the minimum value keep their color, with a soft edge")
    func minimumValue() {
        let hammy = HueSwap(sourceHue: 35, targetHue: 205, tolerance: 18, minimumValue: 0.6)
        let shadow = PixelColor(hue: 35, saturation: 0.7, value: 0.5)
        #expect(hammy.apply(shadow) == shadow)
        #expect(abs(hammy.weight(of: PixelColor(hue: 35, saturation: 0.7, value: 0.64)) - 0.5) < 0.001)
        #expect(abs(hammy.apply(PixelColor(hue: 35, saturation: 0.7, value: 0.9)).hue - 205) < 0.5)
    }

    @Test("The window can sit away from the main hue; the turn still starts at the main hue")
    func centerAwayFromMainHue() {
        // Sprout: main hue 75, but its greens reach 130. The window is 97 ± 38.
        let sprout = HueSwap(sourceHue: 75, targetHue: 205, centerHue: 97, tolerance: 38)
        let green = PixelColor(hue: 120, saturation: 0.6, value: 0.8)
        #expect(abs(sprout.apply(green).hue - 250) < 0.5)  // 120 + (205 - 75)
        let yellow = PixelColor(hue: 50, saturation: 0.6, value: 0.8)  // 47 from 97: outside
        #expect(sprout.apply(yellow) == yellow)
    }

    @Test("Neko: the orange turns, the cream face and the pink mouth stay")
    func nekoKeepsFaceAndMouth() {
        let neko = HueSwap(
            sourceHue: 35, targetHue: 205, centerHue: 38, tolerance: 22, minimumSaturation: 0.5, minimumValue: 0.65)
        let orange = PixelColor(hue: 35, saturation: 0.75, value: 0.95)
        let cream = PixelColor(hue: 40, saturation: 0.25, value: 0.98)
        let mouth = PixelColor(hue: 12, saturation: 0.55, value: 0.85)
        #expect(abs(neko.apply(orange).hue - 205) < 0.5)
        #expect(neko.apply(cream) == cream)
        #expect(neko.apply(mouth) == mouth)
    }

    @Test("The turn takes the short way round the color wheel")
    func shortestTurn() {
        #expect(HueSwap.turn(from: 10, to: 350) == -20)
        #expect(HueSwap.turn(from: 350, to: 10) == 20)
        #expect(HueSwap.turn(from: 345, to: 175) == -170)
        #expect(HueSwap.turn(from: 0, to: 180) == 180)
        #expect(HueSwap.turn(from: 180, to: 0) == 180)
        #expect(HueSwap.turn(from: 30, to: 30) == 0)
    }

    @Test("Pixels: an odd byte count keeps the extra bytes as they are")
    func recolorsPartialPixel() {
        let pixels: [UInt8] = [0xF0, 0x72, 0x86, 0xFF, 0x12, 0x34]
        let result = axoToTeal.recolored(premultipliedRGBA: pixels)
        #expect(result.count == 6)
        #expect(Array(result[4...]) == [0x12, 0x34])
    }
}
