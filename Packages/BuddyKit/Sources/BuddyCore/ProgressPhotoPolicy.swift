import Foundation

/// One saved progress photo, known by its file name ("2026-10-22-daily.jpg").
public struct ProgressPhoto: Sendable, Equatable, Hashable {
    public enum Kind: String, Sendable, CaseIterable {
        /// The first check of the day that saw the user.
        case daily
        /// One check with bad posture, to see the difference.
        case posture
    }

    public let kind: Kind
    /// The start of the local day the photo was taken.
    public let day: Date

    public init(kind: Kind, day: Date) {
        self.kind = kind
        self.day = day
    }
}

/// Rules for opt-in progress photos (docs/PRIVACY.md rule 3): at most one of each kind a day,
/// kept on this Mac only, deleted after 30 days. The app does the file work; the rules live here.
public enum ProgressPhotoPolicy {
    public static let keepDays = 30
    public static let fileExtension = "jpg"

    public static func fileName(for kind: ProgressPhoto.Kind, at date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return "\(day)-\(kind.rawValue).\(fileExtension)"
    }

    /// Nil for any file that is not a progress photo.
    public static func parse(_ fileName: String, calendar: Calendar = .current) -> ProgressPhoto? {
        let suffix = ".\(fileExtension)"
        guard fileName.hasSuffix(suffix) else { return nil }
        let parts = fileName.dropLast(suffix.count).split(separator: "-").map(String.init)
        guard parts.count == 4, let kind = ProgressPhoto.Kind(rawValue: parts[3]),
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        let components = DateComponents(year: year, month: month, day: day)
        guard components.isValidDate(in: calendar), let date = calendar.date(from: components) else { return nil }
        return ProgressPhoto(kind: kind, day: calendar.startOfDay(for: date))
    }

    /// The kinds not taken yet today.
    public static func due(
        at date: Date, existing: [ProgressPhoto], calendar: Calendar = .current
    ) -> Set<ProgressPhoto.Kind> {
        let today = calendar.startOfDay(for: date)
        let taken = Set(existing.filter { $0.day == today }.map(\.kind))
        return Set(ProgressPhoto.Kind.allCases).subtracting(taken)
    }

    /// Which photo a check fills. Bad posture fills the posture photo first. Nobody seen: none.
    public static func kindToSave(due: Set<ProgressPhoto.Kind>, assessment: PostureAssessment) -> ProgressPhoto.Kind? {
        switch assessment {
        case .unknown:
            return nil
        case .slouching:
            if due.contains(.posture) { return .posture }
            return due.contains(.daily) ? .daily : nil
        case .good:
            return due.contains(.daily) ? .daily : nil
        }
    }

    /// Photos from 30 or more days ago.
    public static func expired(_ photos: [ProgressPhoto], at date: Date, calendar: Calendar = .current)
        -> [ProgressPhoto]
    {
        let today = calendar.startOfDay(for: date)
        return photos.filter { photo in
            (calendar.dateComponents([.day], from: photo.day, to: today).day ?? 0) >= keepDays
        }
    }
}
