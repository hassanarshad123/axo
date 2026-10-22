import BuddyCore
import CoreMotion
import Foundation

/// Reads head angle from AirPods Pro, AirPods Max and other supported headphones.
/// Used as a backup when the camera is off or the user is out of frame.
///
/// `@unchecked Sendable`: `manager`, `collected` and `isSampling` are touched only on `queue`,
/// one private serial queue. The motion handler runs there too (`updateQueue` sits on top of it).
public final class HeadphonePostureSampler: @unchecked Sendable {
    public enum SamplerError: Error, Equatable, LocalizedError {
        case permissionDenied
        /// Another sample is still running. The caller should wait for it.
        case busy

        public var errorDescription: String? {
            switch self {
            case .permissionDenied:
                "AirPods motion access is off. Turn it on in System Settings > Privacy & Security."
            case .busy:
                "AirPods are busy with another check."
            }
        }
    }

    private let queue = DispatchQueue(label: "Axo.HeadphonePostureSampler")
    private let updateQueue: OperationQueue
    private let manager = CMHeadphoneMotionManager()
    private var collected: [PostureReading] = []
    private var isSampling = false

    public init() {
        let updateQueue = OperationQueue()
        updateQueue.name = "Axo.HeadphonePostureSampler.updates"
        updateQueue.maxConcurrentOperationCount = 1
        updateQueue.underlyingQueue = queue
        self.updateQueue = updateQueue
    }

    /// Listens for `duration` seconds. Returns no readings if no supported headphones are worn.
    /// Only one sample runs at a time; a second call while one runs throws `.busy`.
    public func sample(for duration: TimeInterval) async throws -> [PostureReading] {
        guard try await onQueue({ try self.begin() }) else { return [] }
        do {
            try await Task.sleep(for: .seconds(duration))
        } catch {
            _ = try? await onQueue { self.finish() }
            throw error
        }
        return try await onQueue { self.finish() }
    }

    /// Returns false if this Mac cannot read head motion.
    private func begin() throws -> Bool {
        switch CMHeadphoneMotionManager.authorizationStatus() {
        case .denied, .restricted: throw SamplerError.permissionDenied
        case .authorized, .notDetermined: break
        @unknown default: break
        }
        guard manager.isDeviceMotionAvailable else { return false }
        guard !isSampling else { throw SamplerError.busy }

        isSampling = true
        collected = []
        manager.startDeviceMotionUpdates(to: updateQueue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            // Runs on `queue`, through `updateQueue`.
            self.collected.append(
                PostureReading(
                    timestamp: Date(),
                    source: .headphones,
                    headPitch: motion.attitude.pitch * 180 / .pi,
                    confidence: 1
                ))
        }
        return true
    }

    private func finish() -> [PostureReading] {
        manager.stopDeviceMotionUpdates()
        isSampling = false
        let readings = collected
        collected = []
        return readings
    }

    private func onQueue<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try work() })
            }
        }
    }
}
