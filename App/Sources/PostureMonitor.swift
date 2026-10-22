import ActivityMonitor
import BuddyCore
import Foundation
import Observation
import PostureEngine

/// Posture checks and calibration. The engine asks for a check each minute and acts on the result.
///
///     check ──▶ sample (camera 3 s + AirPods 3 s) ──▶ assessment ──▶ learn a little ──▶ nudge? fixed?
@MainActor
@Observable
final class PostureMonitor {
    /// What one check found, and what the buddy should do about it.
    struct Result {
        let assessment: PostureAssessment
        /// The sensor that decided. Nil when no sensor saw the user.
        let sensor: PostureReading.Source?
        /// Bad checks in a row reached the limit: show the nudge.
        let shouldNudge: Bool
        /// Good again after a nudge: say "good job".
        let fixedAfterNudge: Bool
    }

    private(set) var posture: PostureAssessment = .unknown
    private(set) var isCalibrating = false
    /// The result of the last calibration, when the user should know something about it.
    private(set) var calibrationMessage: String?
    private(set) var cameraError: String?
    private(set) var headphonesError: String?

    /// Calibration start and end, for the voice coach. The engine sets it.
    @ObservationIgnored var onEvent: (EngineEvent) -> Void = { _ in }
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored let photos: ProgressPhotos
    @ObservationIgnored private let sampling = PostureSampling()
    @ObservationIgnored private var slouchStreak = 0
    /// True after a nudge, until posture is good again.
    @ObservationIgnored private var nudged = false
    /// The day photos were last cleaned up.
    @ObservationIgnored private var photoDay = Calendar.current.startOfDay(for: Date())

    static let sampleDuration: TimeInterval = 3
    static let calibrationDuration: TimeInterval = 5
    /// Posture checks in a row that must be bad before the buddy speaks up.
    static let slouchChecksBeforeNudge = 2

    init(settings: SettingsStore, photos: ProgressPhotos) {
        self.settings = settings
        self.photos = photos
        sampling.useCamera(id: settings.cameraID)
        photos.deleteExpired()
    }

    /// Deletes expired progress photos once a day.
    func rollOver(to date: Date) {
        let day = Calendar.current.startOfDay(for: date)
        guard day != photoDay else { return }
        photoDay = day
        photos.deleteExpired(at: date)
    }

    /// The camera is on, calibrated and allowed. Never shows the system question.
    var canUseCamera: Bool {
        settings.cameraEnabled && settings.baseline != nil && CameraPostureSampler.isAuthorized
    }

    /// Call after the user picks another camera in Settings.
    func cameraChanged() {
        sampling.useCamera(id: settings.cameraID)
    }

    /// A short camera look for a face or a person (presence, and the setup window).
    /// Nil when the camera could not look.
    func lookForPerson() async -> Bool? {
        guard settings.cameraEnabled else { return nil }
        let seen = await sampling.lookForPerson()
        cameraError = seen == nil ? "The camera could not check if you are there." : nil
        return seen
    }

    func calibrate() async {
        guard !isCalibrating else { return }
        isCalibrating = true
        defer { isCalibrating = false }
        calibrationMessage = nil

        let sensors = PostureCheckPolicy.Sensors(
            camera: settings.cameraEnabled, headphones: settings.headphonesEnabled)
        guard sensors.any else {
            calibrationMessage = "Turn on the camera or AirPods in Settings first."
            return
        }
        onEvent(.calibrationStarted)
        // Waits for a running posture check to end, then samples.
        let sample = await sampling.sample(for: Self.calibrationDuration, sensors: sensors)
        record(sample)
        guard let baseline = PostureBaseline.calibrated(from: sample.readings) else {
            calibrationMessage = "I could not see you. Sit in front of the camera and try again."
            onEvent(.calibrationEnded(succeeded: false))
            return
        }
        settings.calibrate(baseline)
        onEvent(.calibrationEnded(succeeded: true))
        posture = .unknown
        slouchStreak = 0
        nudged = false
        if !baseline.hasCameraValues {
            calibrationMessage = "Calibrated with AirPods only. The camera gives better checks."
        }
    }

    /// One posture check. Nil when no check ran (no calibration, sensors off, user away).
    func check(activity: ActivityState, isScreenLockedOrAsleep: Bool) async -> Result? {
        guard !isCalibrating, settings.baseline != nil else { return nil }
        let sensors = PostureCheckPolicy.sensors(
            activity: activity,
            idleSeconds: ActivitySensors.secondsSinceLastInput(),
            isScreenLockedOrAsleep: isScreenLockedOrAsleep,
            cameraEnabled: settings.cameraEnabled,
            headphonesEnabled: settings.headphonesEnabled
        )
        guard sensors.any else { return nil }

        let photosDue = settings.snapshotsEnabled ? photos.due() : []
        let sample = await sampling.sample(
            for: Self.sampleDuration, sensors: sensors, capturePhoto: sensors.camera && !photosDue.isEmpty)
        record(sample)
        // A calibration may have started while this sample ran. Its new baseline wins.
        guard !isCalibrating, let baseline = settings.baseline else { return nil }

        let evaluator = PostureEvaluator(thresholds: .standard(for: settings.sensitivity))
        let check = evaluator.check(sample.readings, against: baseline)
        posture = check.result
        learn(from: check, baseline: baseline)
        keepPhoto(sample.photo, due: photosDue, assessment: check.cameraVote)
        return result(for: check.result, sensor: check.decidingSensor)
    }

    /// Saves the frame when progress photos are on and the check fills a missing photo.
    /// The camera's own vote decides, because the photo shows what the camera saw.
    private func keepPhoto(_ photo: Data?, due: Set<ProgressPhoto.Kind>, assessment: PostureAssessment) {
        guard let photo, settings.snapshotsEnabled,
            let kind = ProgressPhotoPolicy.kindToSave(due: due, assessment: assessment)
        else { return }
        photos.save(photo, kind: kind)
    }

    private func result(for assessment: PostureAssessment, sensor: PostureReading.Source?) -> Result {
        let fixed = assessment.isGood && nudged
        if assessment.isGood { nudged = false }
        slouchStreak = assessment.isGood || assessment == .unknown ? 0 : slouchStreak + 1
        let shouldNudge = slouchStreak == Self.slouchChecksBeforeNudge
        if shouldNudge { nudged = true }
        return Result(assessment: assessment, sensor: sensor, shouldNudge: shouldNudge, fixedAfterNudge: fixed)
    }

    /// "Learns over time": one small step per good check, kept close to the calibrated posture.
    private func learn(from check: PostureCheck, baseline: PostureBaseline) {
        let anchor = settings.calibratedBaseline ?? baseline
        let learned = baseline.learning(from: check.readingsToLearnFrom, anchor: anchor)
        if learned != baseline {
            settings.baseline = learned
        }
    }

    /// Each sensor keeps its own message. A sensor that did not run keeps its last one.
    private func record(_ sample: PostureSample) {
        cameraError = sample.camera.message(after: cameraError)
        headphonesError = sample.headphones.message(after: headphonesError)
    }
}
