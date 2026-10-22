import CryptoKit
import Foundation

/// The app details that go with each usage count. Nothing else about the Mac is sent.
public struct UsageContext: Sendable, Equatable {
    public let appID: String
    /// A random id made on this Mac. Only its SHA-256 hash leaves the Mac.
    public let installID: String
    /// A random id for this launch of the app.
    public let sessionID: String
    public let appVersion: String
    public let build: String
    /// The macOS version, "major.minor".
    public let systemVersion: String
    /// "arm64" (Apple chip) or "x86_64" (Intel).
    public let architecture: String
    /// A Debug build: TelemetryDeck shows these counts apart, as test counts.
    public let isTestBuild: Bool

    public init(
        appID: String, installID: String, sessionID: String, appVersion: String, build: String,
        systemVersion: String, architecture: String, isTestBuild: Bool
    ) {
        self.appID = appID
        self.installID = installID
        self.sessionID = sessionID
        self.appVersion = appVersion
        self.build = build
        self.systemVersion = systemVersion
        self.architecture = architecture
        self.isTestBuild = isTestBuild
    }
}

/// One usage count, in the exact form of TelemetryDeck's ingest API (version 2).
///
///     UsageSignal + UsageContext ─▶ UsageReport ─▶ JSON array ─▶ POST https://nom.telemetrydeck.com/v2/
///
/// Axo builds this body itself instead of using the TelemetryDeck SDK. The SDK adds about 60
/// fields to each count (usage history, screen, locale, accessibility settings), keeps a session
/// log and shares a queue file with other apps. Here only the fields below leave the Mac
/// (docs/PRIVACY-NOTICE.md, docs/DECISIONS.md T51).
public struct UsageReport: Sendable, Equatable, Encodable {
    public static let endpoint = URL(string: "https://nom.telemetrydeck.com/v2/")!

    public let receivedAt: Date
    public let appID: String
    public let clientUser: String
    public let sessionID: String
    public let type: String
    public let payload: [String: String]
    public let isTestMode: String

    public init(signal: UsageSignal, context: UsageContext, at date: Date) {
        receivedAt = date
        appID = context.appID
        clientUser = Self.hashed(context.installID)
        sessionID = context.sessionID
        type = signal.name
        payload = Self.appDetails(context).merging(signal.parameters) { _, event in event }
        isTestMode = context.isTestBuild ? "true" : "false"
    }

    /// The JSON body for one request: an array of counts, dates in UTC.
    public static func encode(_ reports: [UsageReport]) throws -> Data {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(formatter)
        return try encoder.encode(reports)
    }

    /// Lowercase hex SHA-256, as TelemetryDeck expects for the user id.
    static func hashed(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func appDetails(_ context: UsageContext) -> [String: String] {
        [
            "TelemetryDeck.AppInfo.version": context.appVersion,
            "TelemetryDeck.AppInfo.buildNumber": context.build,
            "TelemetryDeck.Device.platform": "macOS",
            "TelemetryDeck.Device.systemMajorMinorVersion": context.systemVersion,
            "TelemetryDeck.Device.architecture": context.architecture,
        ]
    }
}
