import BuddyCore
import NotchUI
import SwiftUI

/// Settings > Buddy: pick a buddy, name it, color it, choose the menu bar icon, and type a code.
///
///     ┌ Buddy ───────────────────────────────────────┐
///     │ [Goo] [Neko] [Bit] ... 8 per row, 2-3 rows   │  (selected one has a frame; unlocked
///     │                                              │   buddies come last)
///     │ Name   [ Axo            ]  16 characters max │  (each buddy keeps its own name)
///     │ Color  (o) (o) (o) (o) (o) (o)               │  (each shows the buddy in that color; a color
///     │                                              │   that looks like the buddy's own is left out)
///     │ Menu bar icon   [ Outline | Color ]          │
///     │ Secret buddies: Code [ ... ] [Unlock]        │  (`UnlockCodeSection`)
///     └──────────────────────────────────────────────┘
struct BuddySettingsView: View {
    let engine: BuddyEngine
    @Bindable var settings: SettingsStore
    @State private var nameText: String

    private let sprites = BuddySprites.shared
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)

    init(engine: BuddyEngine, settings: SettingsStore) {
        self.engine = engine
        self.settings = settings
        _nameText = State(initialValue: settings.buddyNames[engine.appearance.buddyID] ?? "")
    }

    var body: some View {
        Form {
            Section("Pick your buddy") {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(sprites.catalog.buddies) { buddy in
                        buddyCell(buddy)
                    }
                }
                .padding(.vertical, 4)
            }
            Section("Make it yours") {
                TextField("Name", text: $nameText, prompt: Text(defaultName))
                    .onChange(of: nameText) { _, newValue in nameChanged(newValue) }
                LabeledContent("Color") {
                    HStack(spacing: 6) {
                        ForEach(colorChoices) { color in
                            colorSwatch(color)
                        }
                    }
                }
                Picker("Menu bar icon", selection: $settings.menuBarIcon) {
                    ForEach(MenuBarIconStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            UnlockCodeSection(engine: engine, settings: settings)
        }
        .formStyle(.grouped)
    }

    private var current: BuddyAppearance { engine.appearance }

    private var colorChoices: [BuddyColor] {
        guard let buddy = sprites.catalog.buddy(withID: current.buddyID) else { return BuddyColor.allCases }
        return BuddyColor.choices(for: buddy, keeping: settings.buddyColor)
    }

    /// The picked buddy's own name, shown when the user has not typed one.
    private var defaultName: String {
        sprites.catalog.resolvedBuddy(id: current.buddyID)?.name ?? BuddyAppearance.axo.name
    }

    private func buddyCell(_ buddy: Buddy) -> some View {
        let isSelected = buddy.id == current.buddyID
        return Button {
            settings.buddyID = buddy.id
            engine.appearanceChanged()
            nameText = settings.buddyNames[buddy.id] ?? ""  // show the name this buddy kept
        } label: {
            VStack(spacing: 2) {
                BuddySpriteView(
                    appearance: BuddyAppearance(
                        buddyID: buddy.id, name: buddy.name, color: .original, form: current.form),
                    mood: .happy,
                    height: 40,
                    animates: false
                )
                Text(buddy.name)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)  // the duo has the longest name
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(selectionBackground(isSelected))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(buddy.name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func colorSwatch(_ color: BuddyColor) -> some View {
        let isSelected = color == settings.buddyColor
        return Button {
            settings.buddyColor = color
            engine.appearanceChanged()
        } label: {
            Group {
                if let art = sprites.image(buddyID: current.buddyID, color: color, pose: "happy", form: current.form) {
                    Image(nsImage: art).resizable().interpolation(.high).aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "paintpalette")
                }
            }
            .frame(width: 34, height: 34)
            .padding(3)
            .background(selectionBackground(isSelected))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(color.title)
        .accessibilityLabel(Text(color.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func selectionBackground(_ isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            }
    }

    /// Cuts the text to 16 characters as the user types, and saves it for the buddy on screen
    /// (blank = the buddy's own name).
    private func nameChanged(_ newValue: String) {
        if newValue.count > BuddyName.maximumLength {
            nameText = String(newValue.prefix(BuddyName.maximumLength))
            return  // The cut text comes back through onChange and is saved then.
        }
        let names = BuddyName.names(settings.buddyNames, setting: newValue, for: current.buddyID)
        guard names != settings.buddyNames else { return }
        settings.buddyNames = names
        engine.appearanceChanged()
    }
}
