import Foundation

/// A camera the Mac can use, as plain values (the device code fills it in).
public struct CameraInfo: Sendable, Equatable, Identifiable, Hashable {
    public enum Kind: Sendable, Equatable, Hashable {
        case builtIn
        /// USB or display camera.
        case external
        /// An iPhone used as a webcam (Continuity Camera).
        case continuity
    }

    /// The device's unique id. It stays the same across restarts.
    public let id: String
    public let name: String
    public let kind: Kind

    public init(id: String, name: String, kind: Kind) {
        self.id = id
        self.name = name
        self.kind = kind
    }
}

/// Which camera the posture checks use.
public enum CameraChoice {
    /// The saved camera while it is connected. Otherwise the built-in camera, then a wired one, then any.
    /// An iPhone comes last: it may be in a pocket.
    public static func pick(savedID: String?, from cameras: [CameraInfo]) -> CameraInfo? {
        if let savedID, let saved = cameras.first(where: { $0.id == savedID }) {
            return saved
        }
        return cameras.first { $0.kind == .builtIn }
            ?? cameras.first { $0.kind == .external }
            ?? cameras.first
    }
}
