import BuddyCore
import Foundation

// Makes and checks the locked buddy packs (`BuddyPack`, DECISIONS T54).
//
//   swift run axo-pack new-code                 print a new random code
//   swift run axo-pack seal <folder> <file>     lock <folder>/catalog.json and <folder>/<buddy id>/*.png
//   swift run axo-pack check <file>             open <file> and list what is inside
//
// seal and check read the code from AXO_UNLOCK_CODE, not from the command line, so the code
// does not show in the process list. `make packs` passes it from ~/.secrets.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("axo-pack: \(message)\n".utf8))
    exit(1)
}

func codeFromEnvironment() -> UnlockCode {
    guard let text = ProcessInfo.processInfo.environment["AXO_UNLOCK_CODE"] else {
        fail("Set AXO_UNLOCK_CODE to the pack's code.")
    }
    guard let code = UnlockCode(text) else { fail("AXO_UNLOCK_CODE is not a code (16 characters).") }
    return code
}

/// The buddies in <folder>/catalog.json, with every PNG in their folders.
func readPack(in folder: URL) throws -> BuddyPack {
    let catalog = try BuddyCatalog.decoded(from: Data(contentsOf: folder.appending(path: "catalog.json")))
    var art: [String: [String: Data]] = [:]
    for buddy in catalog.buddies {
        let files = try FileManager.default.contentsOfDirectory(
            at: folder.appending(path: buddy.id), includingPropertiesForKeys: nil)
        let images = try files.filter { $0.pathExtension == "png" }.map { url in
            (url.deletingPathExtension().lastPathComponent, try Data(contentsOf: url))
        }
        art[buddy.id] = Dictionary(uniqueKeysWithValues: images)
    }
    return BuddyPack(buddies: catalog.buddies, art: art)
}

func describe(_ pack: BuddyPack) -> String {
    pack.buddies.map { "\($0.id) \"\($0.name)\": \(pack.art[$0.id]?.count ?? 0) images" }.joined(separator: "\n")
}

let arguments = Array(CommandLine.arguments.dropFirst())
do {
    switch arguments.first {
    case "new-code" where arguments.count == 1:
        print(UnlockCode.random().display)
    case "seal" where arguments.count == 3:
        let code = codeFromEnvironment()
        let pack = try readPack(in: URL(filePath: arguments[1]))
        let sealed = try pack.sealed(with: code)
        try sealed.write(to: URL(filePath: arguments[2]), options: .atomic)
        // Open it again, so a bad file never ships.
        guard try BuddyPack.opened(sealed, with: code) == pack else { fail("The locked file does not open the same.") }
        print("Locked \(sealed.count / 1024) KB:\n\(describe(pack))")
    case "check" where arguments.count == 2:
        let pack = try BuddyPack.opened(Data(contentsOf: URL(filePath: arguments[1])), with: codeFromEnvironment())
        print(describe(pack))
    default:
        fail("Use: new-code | seal <folder> <file> | check <file>")
    }
} catch {
    fail("\(error)")
}
