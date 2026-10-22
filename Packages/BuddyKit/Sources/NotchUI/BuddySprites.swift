import AppKit
import BuddyCore
import ImageIO
import Observation
import os

/// Loads the buddy art that ships in this package, recolors it, and keeps it in memory.
///
///     image(buddy, color, pose) ──in the cache?──▶ NSImage
///                  │ no
///                  ▼
///     BuddyAssets.candidates ──first file on disk──▶ PNG ──color is not original?──▶ HueSwap on the pixels
///                         (or in an unlocked pack)                                         │
///                                                                                  cache ◀─┘
///
/// Locked buddies ship in `Packs/*.axopack` (`BuddyPack`). `unlock(_:)` opens the packs a code fits,
/// keeps their art in memory only, and adds their buddies to `catalog`. Views that read `catalog` update.
///
/// The export script adds art over time, so any file can be missing. Every lookup can return nil,
/// and the views then show a symbol.
@MainActor
@Observable
public final class BuddySprites {
    public static let shared = BuddySprites()

    /// Menu bar icons are this many points tall.
    public static let menuBarHeight: CGFloat = 18
    /// About 150 KB per sprite, so the cache stays under about 40 MB.
    private static let maximumCachedImages = 256
    private static let log = Logger(subsystem: "com.hassanarshad.axo", category: "BuddySprites")

    /// The open buddies, then the buddies of each unlocked pack.
    public private(set) var catalog: BuddyCatalog
    /// The ids of the buddies that ship open. A usage count names only these (DECISIONS T54).
    public let openBuddyIDs: Set<String>
    /// The `Buddies` folder: catalog.json and <buddy id>/<asset>.png.
    private let directory: URL?
    /// The `Packs` folder: one locked file per pack.
    private let packsDirectory: URL?
    /// PNG data of the unlocked buddies, by buddy id, then by asset name. Never written to disk.
    @ObservationIgnored private var packArt: [String: [String: Data]] = [:]
    @ObservationIgnored private var filesByBuddy: [String: Set<String>] = [:]
    @ObservationIgnored private var images: [ImageKey: NSImage] = [:]
    @ObservationIgnored private var menuBarImages: [MenuBarKey: NSImage] = [:]
    @ObservationIgnored private var brokenImages: Set<ImageKey> = []

    /// The resource bundle that SwiftPM makes for NotchUI: Axo.app/Contents/Resources/<name> in the app,
    /// and next to the test bundle in `swift test`.
    static let resourceBundleName = "BuddyKit_NotchUI.bundle"
    static let packExtension = "axopack"

    convenience init() {
        let bundle = Self.resourceBundle()
        self.init(
            directory: bundle?.url(forResource: "Buddies", withExtension: nil),
            packsDirectory: bundle?.url(forResource: "Packs", withExtension: nil))
    }

    /// Finds the resource bundle by name. Not `Bundle.module`: it stops the app (fatalError) when the
    /// bundle is missing, and a missing bundle must only mean "no art" (the views then show a symbol).
    static func resourceBundle() -> Bundle? {
        let code = Bundle(for: BuddySprites.self)
        let places = [Bundle.main.resourceURL, code.resourceURL, code.bundleURL.deletingLastPathComponent()]
        let found = places.lazy.compactMap { $0.flatMap { Bundle(url: $0.appending(path: resourceBundleName)) } }.first
        if found == nil {
            log.error("\(resourceBundleName, privacy: .public) is missing; no buddy art")
        }
        return found
    }

    init(directory: URL?, packsDirectory: URL? = nil) {
        self.directory = directory
        self.packsDirectory = packsDirectory
        let catalog = Self.loadCatalog(in: directory)
        self.catalog = catalog
        openBuddyIDs = Set(catalog.buddies.map(\.id))
    }

    /// Opens every locked pack this code fits and adds its buddies to `catalog`. All on this Mac.
    /// Returns the buddies of those packs (also when they were open already). Empty: the code fits no pack.
    @discardableResult
    public func unlock(_ code: UnlockCode) -> [Buddy] {
        var found: [Buddy] = []
        for url in packFiles() {
            do {
                let pack = try BuddyPack.opened(try Self.readPack(at: url), with: code)
                add(pack)
                found += pack.buddies
            } catch BuddyPackError.wrongCode {
                continue  // The normal case: this code is for another pack.
            } catch {
                Self.log.error("Could not open \(url.lastPathComponent, privacy: .public): \(error, privacy: .public)")
            }
        }
        return found
    }

    /// The art for a pose, or its fallback (see `BuddyAssets.candidates`). Nil when no file exists.
    public func image(
        buddyID: String,
        color: BuddyColor,
        pose: String,
        form: Int = BuddyAssets.plainForm
    ) -> NSImage? {
        guard let asset = BuddyAssets.resolve(pose, form: form, available: files(for: buddyID)) else { return nil }
        return image(buddyID: buddyID, color: color, asset: asset)
    }

    /// True when this exact file exists. No fallback.
    public func hasAsset(_ asset: String, buddyID: String) -> Bool {
        files(for: buddyID).contains(asset)
    }

    /// The menu bar icon, `menuBarHeight` points tall.
    /// - Outline: a template image (macOS paints it for light and dark menu bars).
    ///   Nil when the art is missing: the app then shows a symbol.
    /// - Color: the buddy's head in its color. The happy pose when the head art is missing.
    public func menuBarImage(buddyID: String, color: BuddyColor, style: MenuBarIconStyle) -> NSImage? {
        let key = MenuBarKey(buddyID: buddyID, color: style == .outline ? .original : color, style: style)
        if let cached = menuBarImages[key] { return cached }
        let asset = BuddyAssets.menuBarAsset(for: style)
        let art: NSImage? =
            switch style {
            case .outline:
                hasAsset(asset, buddyID: buddyID) ? image(buddyID: buddyID, color: .original, asset: asset) : nil
            case .color:
                hasAsset(asset, buddyID: buddyID)
                    ? image(buddyID: buddyID, color: color, asset: asset)
                    : image(buddyID: buddyID, color: color, pose: "happy")
            }
        guard let icon = art.flatMap({ Self.menuBarCopy(of: $0, template: style == .outline) }) else { return nil }
        menuBarImages[key] = icon
        return icon
    }

    // MARK: - Loading

    private func image(buddyID: String, color: BuddyColor, asset: String) -> NSImage? {
        let key = ImageKey(buddyID: buddyID, color: color, asset: asset)
        if let cached = images[key] { return cached }
        guard !brokenImages.contains(key) else { return nil }
        guard let made = makeImage(buddyID: buddyID, color: color, asset: asset) else {
            Self.log.error("Could not load \(buddyID, privacy: .public)/\(asset, privacy: .public).png")
            brokenImages.insert(key)
            return nil
        }
        if images.count >= Self.maximumCachedImages {
            images.removeAll()
        }
        images[key] = made
        return made
    }

    private func makeImage(buddyID: String, color: BuddyColor, asset: String) -> NSImage? {
        guard let source = imageSource(buddyID: buddyID, asset: asset),
            let art = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        let colored = recolored(art, buddyID: buddyID, color: color)
        return NSImage(cgImage: colored, size: NSSize(width: colored.width, height: colored.height))
    }

    /// An unlocked buddy's art comes from memory, an open buddy's art from its folder.
    private func imageSource(buddyID: String, asset: String) -> CGImageSource? {
        if let images = packArt[buddyID] {
            return images[asset].flatMap { CGImageSourceCreateWithData($0 as CFData, nil) }
        }
        guard let url = directory?.appending(path: buddyID).appending(path: "\(asset).png") else { return nil }
        return CGImageSourceCreateWithURL(url as CFURL, nil)
    }

    /// Adds the pack's buddies that are not in the catalog yet. An open buddy with the same id wins.
    private func add(_ pack: BuddyPack) {
        let known = Set(catalog.buddies.map(\.id))
        let added = pack.buddies.filter { !known.contains($0.id) }
        guard !added.isEmpty else { return }
        for buddy in added {
            packArt[buddy.id] = pack.art[buddy.id]
            forget(buddy.id)  // A lookup before the unlock saved "no art" for this id.
        }
        catalog = BuddyCatalog(buddies: catalog.buddies + added)
    }

    private func forget(_ buddyID: String) {
        filesByBuddy[buddyID] = nil
        images = images.filter { $0.key.buddyID != buddyID }
        menuBarImages = menuBarImages.filter { $0.key.buddyID != buddyID }
        brokenImages = brokenImages.filter { $0.buddyID != buddyID }
    }

    private func packFiles() -> [URL] {
        guard let packsDirectory else { return [] }
        let urls = (try? FileManager.default.contentsOfDirectory(at: packsDirectory, includingPropertiesForKeys: nil))
        return (urls ?? []).filter { $0.pathExtension == Self.packExtension }.sorted { $0.path < $1.path }
    }

    /// The file's bytes. A file bigger than `BuddyPack.maximumSize` is not read.
    private static func readPack(at url: URL) throws -> Data {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= BuddyPack.maximumSize else { throw BuddyPackError.notAPack }
        return try Data(contentsOf: url)
    }

    /// The art with its main color turned. The art as drawn for `.original`, or if drawing fails.
    private func recolored(_ art: CGImage, buddyID: String, color: BuddyColor) -> CGImage {
        guard let buddy = catalog.buddy(withID: buddyID), let swap = HueSwap(buddy: buddy, color: color) else {
            return art
        }
        guard let pixels = RGBABitmap(art),
            let result = RGBABitmap(
                width: pixels.width,
                height: pixels.height,
                bytes: swap.recolored(premultipliedRGBA: pixels.bytes)
            ).makeImage()
        else {
            Self.log.error("Could not recolor \(buddyID, privacy: .public); showing the original colors")
            return art
        }
        return result
    }

    /// The PNG names (without ".png") in a buddy's folder. Only ids from the catalog are read,
    /// so a strange id in the saved settings cannot point at another folder.
    private func files(for buddyID: String) -> Set<String> {
        if let known = filesByBuddy[buddyID] { return known }
        var found: Set<String> = []
        if let images = packArt[buddyID] {
            found = Set(images.keys)
        } else if catalog.buddy(withID: buddyID) != nil, let folder = directory?.appending(path: buddyID) {
            let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            found = Set(urls.filter { $0.pathExtension == "png" }.map { $0.deletingPathExtension().lastPathComponent })
        }
        filesByBuddy[buddyID] = found
        return found
    }

    private static func loadCatalog(in directory: URL?) -> BuddyCatalog {
        guard let url = directory?.appending(path: "catalog.json") else {
            log.error("The Buddies folder is missing from the bundle; no buddy art")
            return BuddyCatalog(buddies: [])
        }
        do {
            return try BuddyCatalog.decoded(from: Data(contentsOf: url))
        } catch {
            log.error("Could not read catalog.json: \(error.localizedDescription, privacy: .public)")
            return BuddyCatalog(buddies: [])
        }
    }

    private static func menuBarCopy(of art: NSImage, template: Bool) -> NSImage? {
        guard let pixels = art.cgImage(forProposedRect: nil, context: nil, hints: nil), pixels.height > 0 else {
            return nil
        }
        let width = menuBarHeight * CGFloat(pixels.width) / CGFloat(pixels.height)
        let icon = NSImage(cgImage: pixels, size: NSSize(width: width, height: menuBarHeight))
        icon.isTemplate = template
        return icon
    }

    private struct ImageKey: Hashable {
        let buddyID: String
        let color: BuddyColor
        let asset: String
    }

    private struct MenuBarKey: Hashable {
        let buddyID: String
        let color: BuddyColor
        let style: MenuBarIconStyle
    }
}
