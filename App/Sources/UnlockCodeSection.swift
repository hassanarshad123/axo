import BuddyCore
import NotchUI
import SwiftUI

/// Settings > Buddy > Secret buddies: a code opens a locked buddy pack (DECISIONS T54).
///
///     ┌ Secret buddies ──────────────────────────────┐
///     │ Code  [ XXXX-XXXX-XXXX-XXXX ]  [Unlock]       │
///     │ Unlocked: <names>. Pick one above.            │
///     └ Some buddies are secret. If someone gave you a code, type it here.
///
/// All on this Mac: the code opens a file inside the app. Nothing is sent.
struct UnlockCodeSection: View {
    let engine: BuddyEngine
    @Bindable var settings: SettingsStore
    @State private var codeText = ""
    @State private var message: String?

    private let sprites = BuddySprites.shared

    var body: some View {
        Section {
            HStack {
                TextField("Code", text: $codeText, prompt: Text("XXXX-XXXX-XXXX-XXXX"))
                    .font(.body.monospaced())
                    .autocorrectionDisabled()
                    .onSubmit(unlock)
                Button("Unlock", action: unlock)
                    .disabled(codeText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Secret buddies")
        } footer: {
            Text("Some buddies are secret. If someone gave you a code, type it here.")
        }
    }

    private func unlock() {
        guard let code = UnlockCode(codeText) else {
            message = "A code has 16 letters and digits. Check it and try again."
            return
        }
        let buddies = sprites.unlock(code)
        guard !buddies.isEmpty else {
            message = "This code does not open any buddies."
            return
        }
        if !settings.unlockCodes.contains(code) {
            settings.unlockCodes = settings.unlockCodes + [code]
        }
        codeText = ""
        message = "Unlocked: \(ListFormatter.localizedString(byJoining: buddies.map(\.name))). Pick one above."
        engine.appearanceChanged()  // A locked buddy that was picked before now shows.
    }
}
