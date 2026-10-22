import AppKit
import BuddyCore
import PostureEngine
import SwiftUI

/// Settings > Posture: sensors, camera pick, sensitivity, calibration and progress photos.
struct PostureSettingsView: View {
    let engine: BuddyEngine
    @Bindable var settings: SettingsStore
    @State private var cameras: [CameraInfo] = []
    @State private var confirmDelete = false

    private var monitor: PostureMonitor { engine.postureMonitor }
    private var photos: ProgressPhotos { monitor.photos }

    var body: some View {
        Form {
            Section("Sensors") {
                Toggle("Use the camera (checked on this Mac, never sent)", isOn: $settings.cameraEnabled)
                if settings.cameraEnabled {
                    cameraPicker
                }
                Toggle("Use AirPods head motion", isOn: $settings.headphonesEnabled)
            }
            Section("Checks") {
                Picker("Sensitivity", selection: $settings.sensitivity) {
                    ForEach(PostureSensitivity.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text(sensitivityHelp).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(settings.baseline == nil ? "Calibrate posture" : "Calibrate again") {
                        Task { await monitor.calibrate() }
                    }
                    .disabled(monitor.isCalibrating)
                    if monitor.isCalibrating {
                        ProgressView().controlSize(.small)
                        Text("Sit tall for 5 seconds.").font(.caption)
                    } else if let message = monitor.calibrationMessage {
                        Text(message).font(.caption).foregroundStyle(.orange)
                    }
                }
            }
            photosSection
        }
        .formStyle(.grouped)
        .onAppear { cameras = CameraDevices.available() }
    }

    private var cameraPicker: some View {
        Picker("Camera", selection: $settings.cameraID) {
            Text("Built-in camera (automatic)").tag(String?.none)
            ForEach(cameras) { camera in
                Text(camera.name).tag(String?.some(camera.id))
            }
            if let id = settings.cameraID, !cameras.contains(where: { $0.id == id }) {
                Text("Saved camera (not connected)").tag(String?.some(id))
            }
        }
        .onChange(of: settings.cameraID) { _, _ in monitor.cameraChanged() }
    }

    private var sensitivityHelp: String {
        switch settings.sensitivity {
        case .relaxed: "More room before a check counts as a slouch. Good for the first days."
        case .normal: "The default."
        case .strict: "Less room. The buddy speaks up sooner."
        }
    }

    private var photosSection: some View {
        Section("Progress photos") {
            Toggle("Save progress photos on this Mac", isOn: $settings.snapshotsEnabled)
            Text(
                "One photo a day, and one when you slouch. Kept only on this Mac, never sent, "
                    + "left out of Time Machine, and deleted after 30 days."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack {
                Text(photos.count == 1 ? "1 photo saved" : "\(photos.count) photos saved")
                Spacer()
                Button("Show in Finder") { NSWorkspace.shared.open(photos.folder) }
                    .disabled(photos.count == 0)
                Button("Delete all…", role: .destructive) { confirmDelete = true }
                    .disabled(photos.count == 0)
            }
            if let error = photos.lastError {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
        }
        .confirmationDialog("Delete all progress photos?", isPresented: $confirmDelete) {
            Button("Delete all photos", role: .destructive) { photos.deleteAll() }
        } message: {
            Text("This cannot be undone.")
        }
    }
}
