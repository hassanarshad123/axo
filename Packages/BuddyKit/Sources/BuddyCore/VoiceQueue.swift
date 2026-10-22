import Foundation

/// The lines waiting to be said, one at a time, first in first out.
///
/// The coach must not talk over itself or say old news. So the queue keeps at most 3 lines
/// (a new line pushes out the oldest), and a line that waited more than 10 seconds is dropped.
public struct VoiceQueue: Sendable, Equatable {
    public static let capacity = 3
    public static let staleAfter: TimeInterval = 10
    public static let empty = VoiceQueue(items: [])

    private struct Item: Sendable, Equatable {
        let line: VoiceLine
        let addedAt: Date
    }

    private let items: [Item]

    private init(items: [Item]) {
        self.items = items
    }

    public var count: Int { items.count }
    public var isEmpty: Bool { items.isEmpty }

    public func adding(_ line: VoiceLine, at date: Date) -> VoiceQueue {
        VoiceQueue(items: Array((items + [Item(line: line, addedAt: date)]).suffix(Self.capacity)))
    }

    /// The next line that is still fresh, and the queue without it. Stale lines go too.
    public func next(at date: Date) -> (line: VoiceLine?, rest: VoiceQueue) {
        let fresh = items.drop { date.timeIntervalSince($0.addedAt) > Self.staleAfter }
        guard let first = fresh.first else { return (nil, .empty) }
        return (first.line, VoiceQueue(items: Array(fresh.dropFirst())))
    }
}
