import Foundation

/// Turns a day of posture checks into one number from 0 to 100.
public enum PostureScore {
    /// Percent of known checks that were good. Unknown checks do not count.
    /// Returns nil if there is no known check yet, so the UI can show "no data" instead of 0.
    public static func daily(_ assessments: [PostureAssessment]) -> Int? {
        let known = assessments.filter { $0 != .unknown }
        guard !known.isEmpty else { return nil }
        let good = known.filter(\.isGood).count
        return Int((Double(good) / Double(known.count) * 100).rounded())
    }

    /// Days in a row, counting back from the newest day, where the score reached the goal.
    /// `scores` is ordered oldest first. A day with no data ends the streak.
    public static func streak(_ scores: [Int?], goal: Int = 70) -> Int {
        var count = 0
        for score in scores.reversed() {
            guard let score, score >= goal else { break }
            count += 1
        }
        return count
    }
}
