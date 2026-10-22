import AppKit
import BuddyCore
import Foundation
import SwiftUI
import Testing

@testable import NotchUI

/// Draws the Progress window off screen. Set `AXO_SNAPSHOT_DIR` to also save it as a PNG file to look at.
@Suite("Progress window renders")
@MainActor
struct ProgressDashboardRenderTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: Date()))!
    }

    @Test("A buddy at level 7 with a week of days draws")
    func filled() throws {
        let days = (-6...0).map { offset in
            DayTotals(
                day: day(offset), goodChecks: 180 + offset * 10, knownChecks: 240, breaksFinished: 4 + offset % 3,
                remindersDone: 6, secondsAtMac: Double(5 * 3600 + offset * 900), goalReached: offset != -3)
        }
        let earlier = DayTotals(day: day(-30), goodChecks: 5_000, knownChecks: 6_000, goalReached: true)
        let state = ProgressState(days: days + [earlier])
        #expect(state.form == 3)
        let appearance = BuddyAppearance(buddyID: "10-neko-cat", name: "Neko", color: .original, form: state.form)
        try render(
            ProgressSummary(
                appearance: appearance, state: state, now: Date(), calendar: calendar, photos: [], message: nil,
                onDeleteHistory: {}),
            name: "progress-filled")
    }

    @Test("A new buddy with no history draws")
    func empty() throws {
        let appearance = BuddyAppearance(buddyID: "25-axo-axolotl", name: "Axo", color: .original, form: 1)
        try render(
            ProgressSummary(
                appearance: appearance, state: .empty, now: Date(), calendar: calendar, photos: nil,
                message: "History could not open. Today is not saved.", onDeleteHistory: {}),
            name: "progress-empty")
    }

    @Test("Durations read as minutes, then hours and minutes; the streak reads as words")
    func durations() {
        #expect(ProgressSummary.streakText(0) == "No streak yet")
        #expect(ProgressSummary.streakText(1) == "1 goal day")
        #expect(ProgressSummary.streakText(4) == "4 goal days in a row")
        #expect(ProgressSummary.duration(59) == "0 m")
        #expect(ProgressSummary.duration(45 * 60) == "45 m")
        #expect(ProgressSummary.duration(4 * 3600 + 12 * 60) == "4 h 12 m")
    }

    private func render(_ view: some View, name: String) throws {
        let renderer = ImageRenderer(content: view.frame(width: 760).background(Color.white))
        renderer.scale = 2
        let image = try #require(renderer.cgImage)
        #expect(image.width > 0)
        guard let folder = ProcessInfo.processInfo.environment["AXO_SNAPSHOT_DIR"] else { return }
        let bitmap = NSBitmapImageRep(cgImage: image)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: folder).appendingPathComponent("\(name).png"))
    }
}
