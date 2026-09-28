import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var appModel: AppViewModel

    @State private var draft = AppSettings.default
    @State private var showClearDataConfirm = false
    @State private var showClearDataFinal = false
    @State private var pendingImportResult: PersistenceService.ImportResult?
    @State private var showImportPicker = false
    @State private var showImportConfirm = false
    @State private var importIsLegacy = false
    @State private var importFileVersion = 0
    @State private var importSignatureMismatch = false

    private var isRuntimeLocked: Bool {
        appModel.activeSession != nil
    }

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    StrictModeSettingsView(draft: $draft)
                } label: {
                    SettingRowLabel(
                        title: String(localized: "settings.strictMode"),
                        subtitle: String(localized: "settings.strictMode.subtitle")
                    )
                }

                Toggle(isOn: pauseLimitEnabledBinding) {
                    SettingRowLabel(
                        title: String(localized: "settings.enablePauseLimit"),
                        subtitle: String(localized: "settings.enablePauseLimit.subtitle")
                    )
                }

                if draft.stopwatchPauseLimitMinutes != nil {
                    HStack(alignment: .center, spacing: 12) {
                        SettingRowLabel(
                            title: String(localized: "settings.pauseLimit"),
                            subtitle: String(localized: "settings.pauseLimit.subtitle")
                        )
                        Spacer()
                        Text("\(draft.stopwatchPauseLimitMinutes ?? 15)\(String(localized: "settings.minutesUnit"))")
                            .foregroundStyle(.secondary)
                        Stepper("", value: Binding(
                            get: { draft.stopwatchPauseLimitMinutes ?? 15 },
                            set: { draft.stopwatchPauseLimitMinutes = $0 }
                        ), in: 1...30)
                        .labelsHidden()
                    }
                }

                Toggle(isOn: restAfterTaskBinding) {
                    SettingRowLabel(
                        title: String(localized: "settings.restAfterTask"),
                        subtitle: String(localized: "settings.restAfterTask.subtitle")
                    )
                }

                if draft.restDurationMinutes > 0 {
                    HStack(alignment: .center, spacing: 12) {
                        SettingRowLabel(
                            title: String(localized: "settings.restTime"),
                            subtitle: String(localized: "settings.restTime.subtitle")
                        )
                        Spacer()
                        Text("\(draft.restDurationMinutes)\(String(localized: "settings.minutesUnit"))")
                            .foregroundStyle(.secondary)
                        Stepper("", value: $draft.restDurationMinutes, in: 1...30)
                            .labelsHidden()
                    }
                }
            } header: {
                Text(String(localized: "settings.category.focusBehavior"))  
            } footer: {
                if isRuntimeLocked {
                    Text(String(localized: "settings.runtime.locked"))  
                }
            }
            .disabled(isRuntimeLocked)

            Section(String(localized: "settings.category.appearance")) {

                NavigationLink {
                    TimerDisplaySettingsView(draft: $draft)
                } label: {
                    SettingRowLabel(
                        title: String(localized: "settings.timerDisplay"),
                        subtitle: String(localized: "settings.timerDisplay.subtitle")
                    )
                }

                Toggle(isOn: fixedSortBinding) {
                    SettingRowLabel(
                        title: String(localized: "settings.fixedSort"),
                        subtitle: String(localized: "settings.fixedSort.subtitle")
                    )
                }

                Toggle(isOn: $draft.strikethroughCompletedTask) {
                    SettingRowLabel(
                        title: String(localized: "settings.dimCompleted"),
                        subtitle: String(localized: "settings.dimCompleted.subtitle")
                    )
                }

                Picker(String(localized: "settings.theme"), selection: $draft.theme) {
                    Text(String(localized: "theme.system")).tag(AppTheme.system)
                    Text(String(localized: "theme.light")).tag(AppTheme.light)
                    Text(String(localized: "theme.dark")).tag(AppTheme.dark)
                }
            }

            Section(String(localized: "settings.category.notification")) {
                Toggle(isOn: $draft.dailyReminderEnabled) {
                    SettingRowLabel(
                        title: String(localized: "settings.dailyReminder"),
                        subtitle: String(localized: "settings.dailyReminder.subtitle")
                    )
                }
                if draft.dailyReminderEnabled {
                    DatePicker(
                        String(localized: "settings.reminderTime"),
                        selection: reminderBinding,
                        displayedComponents: .hourAndMinute
                    )
                }
                Toggle(isOn: $draft.liveActivitiesEnabled) {
                    SettingRowLabel(
                        title: String(localized: "settings.liveActivities"),
                        subtitle: String(localized: "settings.liveActivities.subtitle")
                    )
                }
            }

            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text(String(localized: "settings.systemSettings.action"))
                }
            } header: {
                Text(String(localized: "settings.category.system"))
            } footer: {
                Text(String(localized: "settings.systemSettings.footer"))
            }

            Section(String(localized: "settings.category.data")) {
                Button {
                    exportData()
                } label: {
                    Text(String(localized: "settings.exportData"))
                }
                
                Button {
                    showImportPicker = true
                } label: {
                    Text(String(localized: "settings.importData"))
                }
            }

            Section(String(localized: "settings.category.other")) {
                Button(role: .destructive) {
                    showClearDataConfirm = true
                } label: {
                    Text(String(localized: "settings.clearData"))
                }
            }

            // --- 演示版本声明（已注释，正式版移除）---
            // ChronaDemoNotice()
            // ---------------------------------------------------------
        }
        .navigationTitle(String(localized: "profile.settings"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            draft = appModel.settings
        }
        .onChange(of: draft) { _, newDraft in
            let merged = mergedSettingsForRuntimeSafety(from: newDraft)
            if merged != appModel.settings {
                appModel.settings = merged
            }
        }
        .alert(String(localized: "settings.clearData.confirm.title"), isPresented: $showClearDataConfirm) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "common.delete"), role: .destructive) {
                showClearDataFinal = true
            }
        } message: {
            Text(String(localized: "settings.clearData.confirm.message"))
        }
        .alert(String(localized: "settings.clearData.final.title"), isPresented: $showClearDataFinal) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "settings.clearData.final.action"), role: .destructive) {
                appModel.clearAllData()
            }
        } message: {
            Text(String(localized: "settings.clearData.final.message"))
        }
        .alert(importConfirmTitle, isPresented: $showImportConfirm) {
            Button(String(localized: "common.cancel"), role: .cancel) {
                pendingImportResult = nil
            }
            Button(String(localized: "settings.importData.force"), role: .destructive) {
                performImport()
            }
        } message: {
            Text(importConfirmMessage)
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result)
        }
    }

    private var importConfirmTitle: String {
        if importSignatureMismatch {
            return String(localized: "settings.importData.confirm.title.modified")
        } else if importIsLegacy {
            return String(localized: "settings.importData.confirm.title.legacy")
        } else if importFileVersion > ExportFormatVersion.current {
            return String(localized: "settings.importData.confirm.title.newer")
        } else {
            return String(localized: "settings.importData.confirm.title")
        }
    }

    private var importConfirmMessage: String {
        if importSignatureMismatch {
            return String(localized: "settings.importData.confirm.message.modified")
        } else if importIsLegacy {
            return String(localized: "settings.importData.confirm.message.legacy")
        } else if importFileVersion > ExportFormatVersion.current {
            return String(format: String(localized: "settings.importData.confirm.message.newer"), importFileVersion, ExportFormatVersion.current)
        } else {
            return String(localized: "settings.importData.confirm.message")
        }
    }

    private var fixedSortBinding: Binding<Bool> {
        Binding {
            !draft.autoMoveCompletedTaskToTop
        } set: { enabled in
            draft.autoMoveCompletedTaskToTop = !enabled
        }
    }

    private var pauseLimitEnabledBinding: Binding<Bool> {
        Binding {
            draft.stopwatchPauseLimitMinutes != nil
        } set: { enabled in
            if enabled {
                if draft.stopwatchPauseLimitMinutes == nil {
                    draft.stopwatchPauseLimitMinutes = 15
                }
            } else {
                draft.stopwatchPauseLimitMinutes = nil
            }
        }
    }

    private var restAfterTaskBinding: Binding<Bool> {
        Binding {
            draft.restDurationMinutes > 0
        } set: { enabled in
            if enabled {
                if draft.restDurationMinutes <= 0 {
                    draft.restDurationMinutes = 5
                }
            } else {
                draft.restDurationMinutes = 0
            }
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

    private func mergedSettingsForRuntimeSafety(from candidate: AppSettings) -> AppSettings {
        guard appModel.activeSession != nil else { return candidate }

        var merged = candidate
        merged.advancedDisallowPause = appModel.settings.advancedDisallowPause
        merged.advancedDisallowEarlyFinish = appModel.settings.advancedDisallowEarlyFinish
        merged.restDurationMinutes = appModel.settings.restDurationMinutes
        merged.stopwatchPauseLimitMinutes = appModel.settings.stopwatchPauseLimitMinutes
        return merged
    }

    // MARK: - 数据导入导出 (Persistence)
    
    /// 导出数据：生成 JSON 文件并调起系统分享面板
    private func exportData() {
        guard let data = appModel.exportData() else { return }
        
        let fileName = "chrona_data_" + Date.now.formatted(.dateTime.year().month().day())
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName).appendingPathExtension("json")
        
        do {
            try data.write(to: fileURL)
            let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            
            // 在 iPad 上需要配置 popoverPresentationController 避免崩溃
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                
                if let popover = activityViewController.popoverPresentationController {
                    let bounds = windowScene.screen.bounds
                    popover.sourceView = rootViewController.view
                    popover.sourceRect = CGRect(x: bounds.width / 2, y: bounds.height / 2, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                
                rootViewController.present(activityViewController, animated: true)
            }
        } catch {
            print("Export failed: \(error)")
        }
    }
    
    /// 处理文件选择器的结果
    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            guard url.startAccessingSecurityScopedResource() else {
                appModel.showGlobalNotice(String(localized: "settings.importData.failed"))
                return
            }

            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)

                guard let importResult = appModel.inspectImport(data: data) else {
                    appModel.showGlobalNotice(String(localized: "settings.importData.failed"))
                    return
                }

                // 预检结果会在确认后直接复用，避免重复解码同一份备份文件。
                pendingImportResult = importResult
                importFileVersion = importResult.fileVersion
                importIsLegacy = importResult.isLegacy
                importSignatureMismatch = importResult.isSignatureMismatch
                showImportConfirm = true
            } catch {
                print("Import read failed: \(error)")
                appModel.showGlobalNotice(String(localized: "settings.importData.failed"))
            }

        case .failure(let error):
            print("Import picker failed: \(error)")
        }
    }

    /// 执行最终的导入操作
    private func performImport() {
        guard let importResult = pendingImportResult else { return }
        defer { pendingImportResult = nil }

        let status = appModel.importData(importResult)
        guard case .success(let fileVersion, let isLegacy, let isSignatureMismatch) = status else {
            appModel.showGlobalNotice(String(localized: "settings.importData.failed"))
            return
        }

        // 导入成功后同步刷新 UI 草稿状态
        draft = appModel.settings

        // 版本提示
        if isSignatureMismatch {
            appModel.showGlobalNotice(String(localized: "settings.importData.modifiedNotice"))
        } else if isLegacy {
            appModel.showGlobalNotice(String(localized: "settings.importData.legacyNotice"))
        } else if fileVersion > ExportFormatVersion.current {
            appModel.showGlobalNotice(String(localized: "settings.importData.newerWarning"))
        } else {
            appModel.showGlobalNotice(String(localized: "settings.importData.success"))
        }
    }
}

private struct StrictModeSettingsView: View {
    @Binding var draft: AppSettings

    var body: some View {
        Form {
            Toggle(String(localized: "settings.noPause"), isOn: $draft.advancedDisallowPause)

            Toggle(isOn: $draft.advancedDisallowEarlyFinish) {
                SettingRowLabel(
                    title: String(localized: "settings.noEarlyFinish"),
                    subtitle: String(localized: "settings.earlyFinish.note")
                )
            }
        }
        .navigationTitle(String(localized: "settings.strictMode"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SettingRowLabel: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppViewModel())
    }
}
