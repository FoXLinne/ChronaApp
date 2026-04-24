import SwiftUI

struct TimerDisplaySettingsView: View {
    @Binding var draft: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $draft.enableMinimalBlackMode) {
                    SettingRowLabel(
                        title: String(localized: "settings.immersive"),
                        subtitle: immersiveSubtitle
                    )
                }

                if draft.enableMinimalBlackMode {
                    Picker(selection: $draft.minimalModeActivationDelaySeconds) {
                        Text(String(localized: "settings.minimalDelay.5s")).tag(5)
                            .foregroundStyle(.secondary)
                        Text(String(localized: "settings.minimalDelay.10s")).tag(10)
                            .foregroundStyle(.secondary)
                        Text(String(localized: "settings.minimalDelay.30s")).tag(30)
                            .foregroundStyle(.secondary)
                        Text(String(localized: "settings.minimalDelay.60s")).tag(60)
                            .foregroundStyle(.secondary)
                    } label: {
                        Text(String(localized: "settings.minimalDelay"))
                    }
                }

                Toggle(isOn: $draft.keepScreenAwake) {
                    SettingRowLabel(
                        title: String(localized: "settings.keepAwake"),
                        subtitle: String(localized: "settings.keepAwake.subtitle")
                    )
                }

                Toggle(isOn: $draft.showStatusBarOverlay) {
                    SettingRowLabel(
                        title: String(localized: "settings.showStatusBarOverlay"),
                        subtitle: String(localized: "settings.showStatusBarOverlay.subtitle")
                    )
                }

                Toggle(isOn: $draft.showPersonalizedBackground) {
                    SettingRowLabel(
                        title: String(localized: "settings.showPersonalizedBackground"),
                        subtitle: String(localized: "settings.showPersonalizedBackground.subtitle")
                    )
                }
            }
        }
        .navigationTitle(String(localized: "settings.timerDisplay"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var immersiveSubtitle: String {
        if draft.enableMinimalBlackMode {
            return String(format: String(localized: "settings.immersive.subtitle.on"), draft.minimalModeActivationDelaySeconds)
        }
        return String(localized: "settings.immersive.subtitle.off")
    }
}
