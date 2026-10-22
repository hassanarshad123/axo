import BuddyCore
import Foundation
import Observation
import os

/// Opt-in progress photos, saved only on this Mac (docs/PRIVACY.md rule 3).
///
///     ~/Library/Application Support/Axo/Photos/2026-10-22-daily.jpg
///                                              2026-10-22-posture.jpg
///
/// The folder is left out of Time Machine and only this user can open it.
/// The rules (one of each kind a day, 30 days) live in `ProgressPhotoPolicy`.
@MainActor
@Observable
final class ProgressPhotos {
    private(set) var count = 0
    private(set) var lastError: String?

    @ObservationIgnored let folder: URL
    @ObservationIgnored private let files = FileManager.default
    private static let logger = Logger(subsystem: "com.hassanarshad.axo", category: "Photos")

    init(folder: URL = ProgressPhotos.defaultFolder) {
        self.folder = folder
        count = saved().count
    }

    static var defaultFolder: URL {
        URL.applicationSupportDirectory.appending(path: "Axo/Photos", directoryHint: .isDirectory)
    }

    /// The photo kinds still missing today.
    func due(at date: Date = Date()) -> Set<ProgressPhoto.Kind> {
        ProgressPhotoPolicy.due(at: date, existing: saved().map(\.photo))
    }

    func save(_ jpeg: Data, kind: ProgressPhoto.Kind, at date: Date = Date()) {
        do {
            try prepareFolder()
            let url = folder.appending(path: ProgressPhotoPolicy.fileName(for: kind, at: date))
            try jpeg.write(to: url, options: .atomic)
            try files.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path(percentEncoded: false))
            lastError = nil
        } catch {
            fail("Could not save a progress photo", error)
        }
        count = saved().count
    }

    /// Photos from 30 or more days ago are deleted. Runs at start and once a day.
    func deleteExpired(at date: Date = Date()) {
        let all = saved()
        let expired = Set(ProgressPhotoPolicy.expired(all.map(\.photo), at: date))
        remove(all.filter { expired.contains($0.photo) }.map(\.url))
    }

    func deleteAll() {
        remove(saved().map(\.url))
    }

    /// The saved photos, newest first.
    func saved() -> [(photo: ProgressPhoto, url: URL)] {
        let names = (try? files.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
        let photos = names.compactMap { name -> (photo: ProgressPhoto, url: URL)? in
            guard let photo = ProgressPhotoPolicy.parse(name) else { return nil }
            return (photo, folder.appending(path: name))
        }
        return photos.sorted { ($0.photo.day, $0.photo.kind.rawValue) > ($1.photo.day, $1.photo.kind.rawValue) }
    }

    private func remove(_ urls: [URL]) {
        for url in urls {
            do {
                try files.removeItem(at: url)
            } catch {
                fail("Could not delete a progress photo", error)
            }
        }
        count = saved().count
    }

    /// Makes the folder (owner only) and keeps it out of Time Machine backups.
    private func prepareFolder() throws {
        try files.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = folder
        try url.setResourceValues(values)
    }

    private func fail(_ message: String, _ error: Error) {
        lastError = "\(message). \(error.localizedDescription)"
        Self.logger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
    }
}
