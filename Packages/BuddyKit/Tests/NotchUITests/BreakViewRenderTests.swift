import AppKit
import BuddyCore
import Foundation
import SwiftUI
import Testing

@testable import NotchUI

/// Draws the break views off screen. Set `AXO_SNAPSHOT_DIR` to also save them as PNG files to look at.
@Suite("Break views render")
@MainActor
struct BreakViewRenderTests {
    private let session = BreakSession(
        reminder: Reminder.defaults[2], style: .fullScreenLocked, startedAt: Date().addingTimeInterval(-20))

    @Test("The full-screen break draws")
    func fullScreen() throws {
        let session = try #require(session)
        let model = BreakScreenModel(session: session, appearance: .axo)
        let view = BreakScreenView(model: model, onSkip: {}, onExit: {}).frame(width: 1440, height: 900)
        try render(view, name: "break-full-screen-locked")

        let skippable = try #require(
            BreakSession(reminder: Reminder.defaults[0], style: .fullScreenSkippable, startedAt: Date()))
        let skipView = BreakScreenView(
            model: BreakScreenModel(session: skippable, appearance: .axo), onSkip: {}, onExit: {}
        )
        .frame(width: 1440, height: 900)
        try render(skipView, name: "break-full-screen-skippable")
    }

    @Test("The island break draws")
    func island() throws {
        let session = try #require(session)
        let view = BreakIslandView(session: session, appearance: .axo, buddyHeight: 92, onEnd: {})
            .foregroundStyle(.white)
            .padding(.top, 38)
            .padding(.horizontal, 18)
            .frame(width: BuddyIslandView.expandedSize.width, height: BuddyIslandView.expandedSize.height)
            .background(.black)
        try render(view, name: "break-island")
    }

    private func render(_ view: some View, name: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        #expect(image.width > 0)
        guard let folder = ProcessInfo.processInfo.environment["AXO_SNAPSHOT_DIR"] else { return }
        let bitmap = NSBitmapImageRep(cgImage: image)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name).png"))
    }
}
