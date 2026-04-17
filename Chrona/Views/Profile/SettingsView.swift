import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppViewModel

    @State private var draft = AppSettings.default

    var body: some View {
        Form {
            Section(String(localized: "settings.category.task")) {
                Toggle(String(localized: "settings.autoPin"), isOn: $draft.autoMoveCompletedTaskToTop)
                Toggle(String(localized: "settings.dimCompleted"), isOn: $draft.strikethroughCompletedTask)
            }

            Section {
                Toggle(String(localized: "settings.minimal"), isOn: $draft.enableMinimalBlackMode)
                Toggle(String(localized: "settings.keepAwake"), isOn: $draft.keepScreenAwake)
                Picker(String(localized: "settings.restTime"), selection: $draft.restDurationMinutes) {
                    Text(String(localized: "common.off")).tag(0)
                    ForEach(1..<11, id: \.self) { minute in
                        Text("\(minute) min").tag(minute)
                    }
                }
                Picker(String(localized: "settings.pauseLimit"), selection: $draft.stopwatchPauseLimitMinutes) {
                    Text(String(localized: "common.unlimited")).tag(Optional<Int>.none)
                    ForEach(1..<11, id: \.self) { minute in
                        Text("\(minute) min").tag(Optional(minute))
                    }
                }
            } header: {
                Text(String(localized: "settings.category.timer"))
            } footer: {
                if appModel.activeSession != nil {
                    Text(String(localized: "settings.runtime.locked"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(appModel.activeSession != nil)

            Section(String(localized: "settings.category.appearance")) {
                Picker(String(localized: "settings.theme"), selection: $draft.theme) {
                    Text(String(localized: "theme.system")).tag(AppTheme.system)
                    Text(String(localized: "theme.light")).tag(AppTheme.light)
                    Text(String(localized: "theme.dark")).tag(AppTheme.dark)
                }
            }

            Section(String(localized: "settings.category.notification")) {
                Toggle(String(localized: "settings.dailyReminder"), isOn: $draft.dailyReminderEnabled)
                DatePicker(
                    String(localized: "settings.reminderTime"),
                    selection: reminderBinding,
                    displayedComponents: .hourAndMinute
                )
                .disabled(!draft.dailyReminderEnabled)
            }

            Section(String(localized: "settings.category.advanced")) {
                Toggle(String(localized: "settings.noPause"), isOn: $draft.advancedDisallowPause)
                Toggle(String(localized: "settings.noEarlyFinish"), isOn: $draft.advancedDisallowEarlyFinish)
                Toggle(String(localized: "settings.liveActivities"), isOn: $draft.liveActivitiesEnabled)
            }
        }
        .navigationTitle(String(localized: "profile.settings"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            draft = appModel.settings
        }
        .onDisappear {
            appModel.settings = mergedSettingsForRuntimeSafety()
        }
    }

    private var reminderBinding: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: draft.dailyReminderHour, minute: draft.dailyReminderMinute, second: 0, of: .now) ?? .now
        } set: { newValue in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            draft.dailyReminderHour = components.hour ?? 20
            draft.dailyReminderMinute = components.minute ?? 0
        }
    }

    private func mergedSettingsForRuntimeSafety() -> AppSettings {
        guard appModel.activeSession != nil else { return draft }

        var merged = draft
        merged.enableMinimalBlackMode = appModel.settings.enableMinimalBlackMode
        merged.keepScreenAwake = appModel.settings.keepScreenAwake
        merged.restDurationMinutes = appModel.settings.restDurationMinutes
        merged.stopwatchPauseLimitMinutes = appModel.settings.stopwatchPauseLimitMinutes
        if merged != draft {
            appModel.showGlobalNotice(String(localized: "settings.runtime.deferNotice"))
        }
        return merged
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppViewModel())
    }
}
