import Foundation

/// Runs `work` every `interval` seconds until the task is cancelled or `owner` is gone.
/// The engine keeps the tasks and cancels them in `stop()`.
@MainActor
func repeatingTask<Owner: AnyObject>(
    every interval: TimeInterval,
    owner: Owner,
    _ work: @escaping @MainActor (Owner) async -> Void
) -> Task<Void, Never> {
    Task { [weak owner] in
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(interval))
            } catch {
                return  // Cancelled.
            }
            guard let owner else { return }
            await work(owner)
        }
    }
}

extension Duration {
    /// The duration in seconds, with the fraction.
    var timeInterval: TimeInterval {
        let parts = components
        return TimeInterval(parts.seconds) + TimeInterval(parts.attoseconds) / 1e18
    }
}
