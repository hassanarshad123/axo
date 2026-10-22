import Foundation
import Testing

@testable import BuddyCore

@Suite("ProgressPhotoPolicy")
struct ProgressPhotoPolicyTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Karachi")!
        return calendar
    }()

    private func date(_ day: Int, hour: Int = 10, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    @Test("File names hold the local day and the kind, and read back")
    func names() {
        let name = ProgressPhotoPolicy.fileName(for: .daily, at: date(22, hour: 23), calendar: calendar)
        #expect(name == "2026-10-22-daily.jpg")
        let photo = ProgressPhotoPolicy.parse(name, calendar: calendar)
        #expect(photo?.kind == .daily)
        #expect(photo?.day == calendar.startOfDay(for: date(22)))
        #expect(ProgressPhotoPolicy.parse("2026-10-22-posture.jpg", calendar: calendar)?.kind == .posture)
        #expect(ProgressPhotoPolicy.parse("holiday.jpg", calendar: calendar) == nil)
        #expect(ProgressPhotoPolicy.parse("2026-13-40-daily.jpg", calendar: calendar) == nil)
    }

    @Test("Each kind once a day")
    func due() {
        let today = date(22)
        #expect(ProgressPhotoPolicy.due(at: today, existing: [], calendar: calendar) == [.daily, .posture])
        let taken = [ProgressPhoto(kind: .daily, day: calendar.startOfDay(for: today))]
        #expect(ProgressPhotoPolicy.due(at: today, existing: taken, calendar: calendar) == [.posture])
        // Yesterday's photo does not count for today.
        let old = [ProgressPhoto(kind: .daily, day: calendar.startOfDay(for: date(21)))]
        #expect(ProgressPhotoPolicy.due(at: today, existing: old, calendar: calendar) == [.daily, .posture])
    }

    @Test("Bad posture fills the posture photo first, good posture the daily one, nobody seen nothing")
    func kindToSave() {
        let slouch = PostureAssessment.slouching([.headDropped])
        #expect(ProgressPhotoPolicy.kindToSave(due: [.daily, .posture], assessment: slouch) == .posture)
        #expect(ProgressPhotoPolicy.kindToSave(due: [.daily], assessment: slouch) == .daily)
        #expect(ProgressPhotoPolicy.kindToSave(due: [.daily, .posture], assessment: .good) == .daily)
        #expect(ProgressPhotoPolicy.kindToSave(due: [.posture], assessment: .good) == nil)
        #expect(ProgressPhotoPolicy.kindToSave(due: [.daily, .posture], assessment: .unknown) == nil)
    }

    @Test("Photos 30 days old or more are deleted")
    func expired() {
        let now = date(22)
        let photos = [
            ProgressPhoto(kind: .daily, day: calendar.startOfDay(for: date(23, month: 9))),  // 29 days
            ProgressPhoto(kind: .daily, day: calendar.startOfDay(for: date(22, month: 9))),  // 30 days
            ProgressPhoto(kind: .posture, day: calendar.startOfDay(for: date(1, month: 8))),
        ]
        let gone = ProgressPhotoPolicy.expired(photos, at: now, calendar: calendar)
        #expect(gone == Array(photos.dropFirst()))
    }
}
