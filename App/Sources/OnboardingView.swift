import AppKit
import BuddyCore
import SwiftUI

/// The first-start window. One page per `OnboardingStep`, with Back and Next at the bottom.
///
///     ┌──────────────────────────────────────────┐
///     │              [art or content]            │
///     │  Title                                   │
///     │  Short text                              │
///     ├──────────────────────────────────────────┤
///     │  ● ● ○ ○ ○ ○ ○          [Back]  [Next]   │
///     └──────────────────────────────────────────┘
struct OnboardingView: View {
    let engine: BuddyEngine
    @Bindable var settings: SettingsStore
    let onFinish: () -> Void
    @State private var step = OnboardingStep.welcome

    var body: some View {
        VStack(spacing: 0) {
            page
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer
        }
        .frame(width: 640, height: 620)
    }

    @ViewBuilder private var page: some View {
        switch step {
        case .welcome:
            ArtPage(
                image: "onboarding-welcome", title: step.title,
                text: "\(engine.appearance.name) lives in your notch. It helps you sit well and take short breaks.")
        case .buddy:
            VStack(spacing: 0) {
                PageTitle(step.title, text: "You can change it any time in Settings.")
                BuddySettingsView(engine: engine, settings: settings)
            }
        case .privacy:
            ArtPage(
                image: "onboarding-privacy", title: step.title,
                text: "The camera looks for 3 seconds each minute. Each picture is checked on this Mac and "
                    + "thrown away at once. Pictures are never sent. Progress photos are off unless you turn them on."
            ) {
                UsageCountsChoice(settings: settings)
            }
        case .permissions:
            PermissionsPage(settings: settings)
        case .airPods:
            ArtPage(
                image: "onboarding-airpods", title: step.title,
                text: "AirPods Pro, Max or 3rd generation can tell when your head drops. They help when "
                    + "the camera is off. macOS asks for Motion access at the first check."
            ) {
                Toggle("Use AirPods head motion", isOn: $settings.headphonesEnabled)
                    .toggleStyle(.switch)
            }
        case .calibrate:
            CalibratePage(engine: engine, settings: settings)
        case .done:
            DonePage(appearance: engine.appearance, settings: settings)
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(OnboardingStep.allCases, id: \.self) { item in
                    Circle()
                        .fill(item == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)"))
            Spacer()
            if let previous = step.previous {
                Button("Back") { step = previous }
            }
            Button(nextTitle) {
                if let next = step.next {
                    step = next
                } else {
                    onFinish()
                }
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private var nextTitle: String {
        switch step {
        case .welcome: "Start"
        case .calibrate: settings.baseline == nil ? "Later" : "Next"
        case .done: "Done"
        default: "Next"
        }
    }
}

/// A title and one or two short lines under it.
struct PageTitle: View {
    let title: String
    let text: String

    init(_ title: String, text: String) {
        self.title = title
        self.text = text
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.title2.bold())
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 40)
        .padding(.top, 20)
    }
}

/// A page with one onboarding picture, a title, text and optional controls.
struct ArtPage<Extra: View>: View {
    let image: String
    let title: String
    let text: String
    @ViewBuilder let extra: () -> Extra

    init(image: String, title: String, text: String, @ViewBuilder extra: @escaping () -> Extra = { EmptyView() }) {
        self.image = image
        self.title = title
        self.text = text
        self.extra = extra
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(image)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 330)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            PageTitle(title, text: text)
            extra()
            Spacer(minLength: 0)
        }
        .padding(.top, 20)
    }
}
