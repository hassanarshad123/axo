import CoreGraphics
import Testing

@testable import NotchUI

@Suite("NotchGeometry")
struct NotchGeometryTests {
    // Values from a 14-inch MacBook Pro at the default scale.
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

    @Test func hardwareNotch() {
        let geometry = NotchGeometry.resolve(
            screenFrame: screen,
            safeAreaTop: 32,
            auxiliaryTopLeft: CGRect(x: 0, y: 950, width: 662, height: 32),
            auxiliaryTopRight: CGRect(x: 850, y: 950, width: 662, height: 32)
        )
        #expect(geometry.hasHardwareNotch)
        #expect(geometry.notchRect == CGRect(x: 662, y: 950, width: 188, height: 32))
    }

    @Test func noNotchGivesFakeIslandAtTopCenter() {
        let external = CGRect(x: 1512, y: 0, width: 2560, height: 1440)
        let geometry = NotchGeometry.resolve(
            screenFrame: external, safeAreaTop: 0, auxiliaryTopLeft: nil, auxiliaryTopRight: nil)
        #expect(!geometry.hasHardwareNotch)
        #expect(geometry.notchRect.midX == external.midX)
        #expect(geometry.notchRect.maxY == external.maxY)
        #expect(geometry.notchRect.size == NotchGeometry.fakeIslandSize)
    }

    @Test func panelHangsFromTheTopCenter() {
        let geometry = NotchGeometry(notchRect: CGRect(x: 662, y: 950, width: 188, height: 32), hasHardwareNotch: true)
        let frame = geometry.panelFrame(maxIslandSize: CGSize(width: 420, height: 150))
        #expect(frame.midX == geometry.notchRect.midX)
        #expect(frame.maxY == geometry.notchRect.maxY)
        #expect(frame.size == CGSize(width: 420, height: 150))
    }
}
