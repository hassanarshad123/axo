@preconcurrency import AVFoundation
import BuddyCore
import CoreImage
import Foundation
import Vision

/// What one camera sample found.
public struct CameraSample: Sendable {
    public let readings: [PostureReading]
    /// One frame as a JPEG. Only when the caller asked for it (progress photos are on).
    public let photo: Data?

    public init(readings: [PostureReading], photo: Data?) {
        self.readings = readings
        self.photo = photo
    }
}

/// Turns the camera on for a short time, reads body pose from the frames, then turns the camera off.
///
/// Privacy: frames stay in memory, are checked on this Mac, and are dropped at once.
/// Nothing is saved or sent. The one exception: when the user turned on progress photos, a sample
/// may keep one frame as a JPEG for the app to save on this Mac (docs/PRIVACY.md rule 3).
///
/// `@unchecked Sendable`: all mutable state is touched only on `queue`, one private serial queue.
/// The sample buffer delegate runs on the same queue.
public final class CameraPostureSampler: NSObject, @unchecked Sendable {
    public enum SamplerError: Error, Equatable, LocalizedError {
        case permissionDenied
        case cameraUnavailable
        case configurationFailed
        /// Another sample is still running. The caller should wait for it.
        case busy
        /// The camera ran but sent no picture. The input is rebuilt on the next sample.
        case noFrames

        public var errorDescription: String? {
            switch self {
            case .permissionDenied:
                "Camera access is off. Turn it on in System Settings > Privacy & Security > Camera."
            case .cameraUnavailable:
                "No camera found. Connect a camera, or turn off camera checks in Settings."
            case .configurationFailed:
                "The camera could not start. Try again in a minute."
            case .busy:
                "The camera is busy with another check."
            case .noFrames:
                "The camera sent no picture. It will be set up again on the next check."
            }
        }
    }

    /// Seconds between two frames that we analyse. The camera sends about 30 frames per second.
    private let frameInterval: TimeInterval
    /// Joints below this confidence count as "not seen".
    private let minimumJointConfidence: Float

    // Everything below is touched only on `queue`.
    private let queue = DispatchQueue(label: "Axo.CameraPostureSampler")
    private let session = AVCaptureSession()
    private lazy var imageContext = CIContext()
    private var input: AVCaptureDeviceInput?
    /// The user's pick (`CameraInfo.id`). Nil = the built-in camera.
    private var cameraID: String?
    private var mode = Mode.posture(capturePhoto: false)
    private var photo: Data?
    private var personSeen = false
    private var output: AVCaptureVideoDataOutput?
    /// Set when the session reports an error or an interruption. The input is rebuilt before the next sample.
    private var needsRebuild = false
    private var isSampling = false
    private var framesSeen = 0
    private var collected: [PostureReading] = []
    private var lastAnalysed: Date = .distantPast
    /// Set once in `init`, removed in `deinit`.
    private var observers: [NSObjectProtocol] = []

    public init(frameInterval: TimeInterval = 0.25, minimumJointConfidence: Float = 0.3) {
        self.frameInterval = frameInterval
        self.minimumJointConfidence = minimumJointConfidence
        super.init()
        let names = [AVCaptureSession.runtimeErrorNotification, AVCaptureSession.wasInterruptedNotification]
        observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: session, queue: nil) { [weak self] _ in
                self?.markForRebuild()
            }
        }
    }

    /// The session reported an error or was interrupted (for example the camera was taken by another app).
    private func markForRebuild() {
        queue.async { self.needsRebuild = true }
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// True when the user already allowed the camera. Never shows the system question.
    public static var isAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    public static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// What the frames are used for during one sample.
    private enum Mode {
        case posture(capturePhoto: Bool)
        case presence
    }

    /// Uses this camera from the next sample on. Nil = the built-in camera.
    public func useCamera(id: String?) {
        queue.async {
            guard self.cameraID != id else { return }
            self.cameraID = id
            self.needsRebuild = true
        }
    }

    /// Runs the camera for `duration` seconds and returns the readings it got.
    /// Only one sample runs at a time; a second call while one runs throws `.busy`.
    public func sample(for duration: TimeInterval, capturePhoto: Bool = false) async throws -> CameraSample {
        guard await Self.requestAccess() else { throw SamplerError.permissionDenied }

        try await onQueue { try self.begin(.posture(capturePhoto: capturePhoto)) }
        do {
            try await Task.sleep(for: .seconds(duration))
        } catch {
            _ = try? await onQueue { try self.finish() }
            throw error
        }
        let result = try await onQueue { try self.finish() }
        return CameraSample(readings: result.readings, photo: result.photo)
    }

    /// Looks for a face or a person for at most `maxDuration` seconds. Stops at the first one.
    public func lookForPerson(maxDuration: TimeInterval) async throws -> Bool {
        guard await Self.requestAccess() else { throw SamplerError.permissionDenied }

        try await onQueue { try self.begin(.presence) }
        let deadline = Date().addingTimeInterval(maxDuration)
        do {
            while Date() < deadline {
                try await Task.sleep(for: .milliseconds(250))
                if try await onQueue({ self.personSeen }) { break }
            }
        } catch {
            _ = try? await onQueue { try self.finish() }
            throw error
        }
        return try await onQueue { try self.finish() }.personSeen
    }

    private func begin(_ newMode: Mode) throws {
        guard !isSampling else { throw SamplerError.busy }
        try prepareSession()
        mode = newMode
        collected = []
        photo = nil
        personSeen = false
        framesSeen = 0
        isSampling = true
        session.startRunning()
    }

    private struct Collected: Sendable {
        let readings: [PostureReading]
        let photo: Data?
        let personSeen: Bool
    }

    private func finish() throws -> Collected {
        session.stopRunning()
        isSampling = false
        let result = Collected(readings: collected, photo: photo, personSeen: personSeen)
        collected = []
        photo = nil
        personSeen = false
        mode = .posture(capturePhoto: false)
        guard framesSeen > 0 else {
            needsRebuild = true
            throw SamplerError.noFrames
        }
        return result
    }

    /// Builds the input the first time, and again when the camera went away
    /// (unplugged, Continuity Camera left, lid closed), the user picked another camera,
    /// the picked camera came back, or the session reported a problem.
    private func prepareSession() throws {
        let device = CameraDevices.device(savedID: cameraID)
        if let input, input.device.isConnected, !needsRebuild, input.device.uniqueID == device?.uniqueID {
            return
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if let input {
            session.removeInput(input)
            self.input = nil
        }
        needsRebuild = false

        guard let device, let newInput = try? AVCaptureDeviceInput(device: device) else {
            throw SamplerError.cameraUnavailable
        }
        guard session.canAddInput(newInput) else { throw SamplerError.configurationFailed }
        session.addInput(newInput)
        input = newInput

        if session.canSetSessionPreset(.vga640x480) {
            session.sessionPreset = .vga640x480
        }
        try addOutputIfNeeded()
    }

    private func addOutputIfNeeded() throws {
        guard output == nil else { return }
        let newOutput = AVCaptureVideoDataOutput()
        newOutput.alwaysDiscardsLateVideoFrames = true
        newOutput.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(newOutput) else { throw SamplerError.configurationFailed }
        session.addOutput(newOutput)
        output = newOutput
    }

    private func onQueue<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                continuation.resume(with: Result { try work() })
            }
        }
    }
}

extension CameraPostureSampler: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        framesSeen += 1
        let now = Date()
        guard now.timeIntervalSince(lastAnalysed) >= frameInterval,
            let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }
        lastAnalysed = now

        switch mode {
        case .presence:
            if !personSeen, CameraFrames.personVisible(in: pixelBuffer) {
                personSeen = true
            }
        case .posture(let capturePhoto):
            analysePosture(pixelBuffer, at: now, capturePhoto: capturePhoto)
        }
    }

    private func analysePosture(_ pixelBuffer: CVPixelBuffer, at now: Date, capturePhoto: Bool) {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        guard (try? handler.perform([request])) != nil,
            let observation = request.results?.first,
            let reading = reading(from: observation, at: now)
        else { return }

        collected.append(reading)
        // The photo is a frame where the body was found, so it shows the posture that was checked.
        if capturePhoto, photo == nil {
            photo = CameraFrames.jpeg(from: pixelBuffer, context: imageContext)
        }
    }

    private func reading(from observation: VNHumanBodyPoseObservation, at date: Date) -> PostureReading? {
        guard let points = try? observation.recognizedPoints(.all) else { return nil }

        func location(_ joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let point = points[joint], point.confidence >= minimumJointConfidence else { return nil }
            return point.location
        }

        let joints = BodyPoseMetrics.Joints(
            nose: location(.nose),
            leftShoulder: location(.leftShoulder),
            rightShoulder: location(.rightShoulder)
        )
        return BodyPoseMetrics.reading(from: joints, confidence: Double(observation.confidence), at: date)
    }
}
