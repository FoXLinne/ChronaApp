import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "profile.user")) {
                    TextField(String(localized: "profile.name"), text: $appModel.profile.name)
                    TextField(String(localized: "profile.avatar"), text: $appModel.profile.avatarSymbol)
                    TextField(String(localized: "profile.signature"), text: $appModel.profile.signature, axis: .vertical)
                }

                Section(String(localized: "profile.routine")) {
                    Button(String(localized: "profile.logSleep")) {
                        appModel.addSleepTime(.now)
                    }
                    Button(String(localized: "profile.logWake")) {
                        appModel.addWakeTime(.now)
                    }
                }

                Section(String(localized: "profile.settings")) {
                    Toggle(String(localized: "settings.autoPin"), isOn: $appModel.settings.autoMoveCompletedTaskToTop)
                    Toggle(String(localized: "settings.dimCompleted"), isOn: $appModel.settings.strikethroughCompletedTask)
                    Toggle(String(localized: "settings.minimal"), isOn: $appModel.settings.enableMinimalBlackMode)
                    Toggle(String(localized: "settings.keepAwake"), isOn: $appModel.settings.keepScreenAwake)
                    Toggle(String(localized: "settings.liveActivities"), isOn: $appModel.settings.liveActivitiesEnabled)
                    Toggle(String(localized: "settings.dailyReminder"), isOn: $appModel.settings.dailyReminderEnabled)
                    Toggle(String(localized: "settings.noPause"), isOn: $appModel.settings.advancedDisallowPause)
                    Toggle(String(localized: "settings.noEarlyFinish"), isOn: $appModel.settings.advancedDisallowEarlyFinish)

                    Picker(String(localized: "settings.restTime"), selection: $appModel.settings.restDurationMinutes) {
                        Text(String(localized: "common.off")).tag(0)
                        ForEach(1..<11, id: \.self) { minute in
                            Text("\(minute) min").tag(minute)
                        }
                    }

                    Picker(String(localized: "settings.theme"), selection: $appModel.settings.theme) {
                        Text(String(localized: "theme.system")).tag(AppTheme.system)
                        Text(String(localized: "theme.light")).tag(AppTheme.light)
                        Text(String(localized: "theme.dark")).tag(AppTheme.dark)
                    }

                    Picker(String(localized: "settings.pauseLimit"), selection: pauseLimitBinding) {
                        Text(String(localized: "common.unlimited")).tag(Optional<Int>.none)
                        ForEach(1..<11, id: \.self) { minute in
                            Text("\(minute) min").tag(Optional(minute))
                        }
                    }

                    DatePicker(
                        String(localized: "settings.reminderTime"),
                        selection: reminderBinding,
                        displayedComponents: .hourAndMinute
                    )
                }

                Section {
                    NavigationLink(String(localized: "profile.about")) {
                        AboutView()
                    }
                }
            }
            .navigationTitle(String(localized: "tab.profile"))
        }
    }

    private var reminderBinding: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: appModel.settings.dailyReminderHour, minute: appModel.settings.dailyReminderMinute, second: 0, of: .now) ?? .now
        } set: { newValue in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            appModel.settings.dailyReminderHour = components.hour ?? 20
            appModel.settings.dailyReminderMinute = components.minute ?? 0
        }
    }

    private var pauseLimitBinding: Binding<Int?> {
        Binding {
            appModel.settings.stopwatchPauseLimitMinutes
        } set: { newValue in
            appModel.settings.stopwatchPauseLimitMinutes = newValue
        }
    }
}
