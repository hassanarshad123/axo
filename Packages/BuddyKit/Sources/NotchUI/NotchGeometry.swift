import CoreGraphics

/// Finds where the buddy island goes on a screen.
///
///     Notch Mac:      ┌──── menu bar ────┬─notch─┬──── menu bar ────┐
///                                         ▲ island grows out of here
///     Other screens:  ┌──── menu bar ───(fake island)─── menu bar ───┐
public struct NotchGeometry: Sendable, Equatable {
    /// The hardware notch, or the fake island rectangle on screens without a notch.
    public let notchRect: CGRect
    public let hasHardwareNotch: Bool

    public static let fakeIslandSize = CGSize(width: 190, height: 32)

    public init(notchRect: CGRect, hasHardwareNotch: Bool) {
        self.notchRect = notchRect
        self.hasHardwareNotch = hasHardwareNotch
    }

    /// - Parameters:
    ///   - screenFrame: `NSScreen.frame` (bottom-left origin).
    ///   - safeAreaTop: `NSScreen.safeAreaInsets.top`. More than 0 only on notch screens.
    ///   - auxiliaryTopLeft: `NSScreen.auxiliaryTopLeftArea`, the menu bar part left of the notch.
    ///   - auxiliaryTopRight: `NSScreen.auxiliaryTopRightArea`, the menu bar part right of the notch.
    public static func resolve(
        screenFrame: CGRect,
        safeAreaTop: CGFloat,
        auxiliaryTopLeft: CGRect?,
        auxiliaryTopRight: CGRect?
    ) -> NotchGeometry {
        if safeAreaTop > 0, let left = auxiliaryTopLeft, let right = auxiliaryTopRight, right.minX > left.maxX {
            let rect = CGRect(
                x: left.maxX,
                y: screenFrame.maxY - safeAreaTop,
                width: right.minX - left.maxX,
                height: safeAreaTop
            )
            return NotchGeometry(notchRect: rect, hasHardwareNotch: true)
        }

        let size = fakeIslandSize
        let rect = CGRect(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        return NotchGeometry(notchRect: rect, hasHardwareNotch: false)
    }

    /// The window frame that holds the island in all its sizes. It hangs down from the top center.
    public func panelFrame(maxIslandSize: CGSize) -> CGRect {
        let width = max(maxIslandSize.width, notchRect.width)
        let height = max(maxIslandSize.height, notchRect.height)
        return CGRect(
            x: notchRect.midX - width / 2,
            y: notchRect.maxY - height,
            width: width,
            height: height
        )
    }
}
