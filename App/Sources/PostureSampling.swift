import BuddyCore
import Foundation
import PostureEngine

/// The readings of one posture sample, and how each sensor did.
struct PostureSample: Sendable {
    let readings: [PostureReading]
    let camera: SensorStatus
    let headphones: SensorStatus
    /// One camera frame as a JPEG, only when the caller asked for it (progress photos).
    let photo: Data?
}

/// Runs the camera and AirPods, one job at a time.
///
///     check ───────[sample 3 s]
///     calibrate          └─waits─▶[sample 5 s]
///     presence look                     └─waits─▶[look ≤ 3 s]
///
/// A new job waits until the one before it ends, so two jobs never fight for the camera.
/// Cancelling the caller cancels its job.
@MainActor
final class PostureSampling {
    private let camera = CameraPostureSampler()
    private let headphones = HeadphonePostureSampler()
    /// The newest job. The next job waits for it.
    private var lastJob: Task<Void, Never>?

    func useCamera(id: String?) {
        camera.useCamera(id: id)
    }

    func sample(
        for duration: TimeInterval, sensors: PostureCheckPolicy.Sensors, capturePhoto: Bool = false
    ) async -> PostureSample {
        await enqueue(fallback: Self.nothing) { [camera, headphones] in
            await Self.collect(
                camera: camera, headphones: headphones, duration: duration, sensors: sensors,
                capturePhoto: capturePhoto)
        }
    }

    /// True when the camera saw a face or a person. Nil when the camera could not look.
    func lookForPerson() async -> Bool? {
        await enqueue(fallback: nil) { [camera] in
            try? await camera.lookForPerson(maxDuration: Presence.lookDuration)
        }
    }

    private func enqueue<T: Sendable>(fallback: T, _ work: @escaping @Sendable () async -> T) async -> T {
        let previous = lastJob
        let task = Task {
            _ = await previous?.value
            guard !Task.isCancelled else { return fallback }
            return await work()
        }
        lastJob = Task { _ = await task.value }
        return await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static let nothing = PostureSample(readings: [], camera: .notUsed, headphones: .notUsed, photo: nil)

    private nonisolated static func collect(
        camera: CameraPostureSampler,
        headphones: HeadphonePostureSampler,
        duration: TimeInterval,
        sensors: PostureCheckPolicy.Sensors,
        capturePhoto: Bool
    ) async -> PostureSample {
        async let fromCamera =
            sensors.camera
            ? read { try await camera.sample(for: duration, capturePhoto: capturePhoto) } : .skipped
        async let fromHeadphones =
            sensors.headphones
            ? read { CameraSample(readings: try await headphones.sample(for: duration), photo: nil) } : .skipped
        let (cameraRead, headphonesRead) = await (fromCamera, fromHeadphones)
        return PostureSample(
            readings: cameraRead.readings + headphonesRead.readings,
            camera: cameraRead.status,
            headphones: headphonesRead.status,
            photo: cameraRead.photo
        )
    }

    private struct SensorRead: Sendable {
        let readings: [PostureReading]
        let status: SensorStatus
        let photo: Data?

        static let skipped = SensorRead(readings: [], status: .notUsed, photo: nil)
    }

    /// Turns a sampler result into readings plus a status. A cancelled sample is not an error.
    private nonisolated static func read(_ work: @Sendable () async throws -> CameraSample) async -> SensorRead {
        do {
            let sample = try await work()
            return SensorRead(readings: sample.readings, status: .worked, photo: sample.photo)
        } catch is CancellationError {
            return .skipped
        } catch {
            return SensorRead(readings: [], status: .failed(error.localizedDescription), photo: nil)
        }
    }
}
