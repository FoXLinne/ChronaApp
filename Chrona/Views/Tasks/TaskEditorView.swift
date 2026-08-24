import SwiftUI

struct TaskEditorView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var mode: FocusMode
    @State private var presetID: String
    @State private var countdownDuration: TimeInterval
    @State private var backgroundName: String
    @State private var showAdvancedCountdownEditor = false
    @State private var customCountdownMinutesText = ""
    @State private var showDiscardChangesConfirm = false

    let task: TaskItem?
    let onSave: (TaskItem) -> Void

    private let initialTitle: String
    private let initialMode: FocusMode
    private let initialPresetID: String
    private let initialCountdownDuration: TimeInterval
    private let initialBackgroundName: String
    private let backgrounds = ThemePalette.seeds

    init(task: TaskItem?, onSave: @escaping (TaskItem) -> Void) {
        self.task = task
        self.onSave = onSave

        let title = task?.title ?? ""
        let mode = task?.mode ?? .pomodoro
        let presetID = task?.pomodoroPresetID ?? PomodoroPreset.default.id
        let countdownDuration = task?.countdownDuration ?? 5 * 60
        let backgroundName = task?.backgroundName ?? ThemePalette.defaultSeed

        initialTitle = title
        initialMode = mode
        initialPresetID = presetID
        initialCountdownDuration = countdownDuration
        initialBackgroundName = backgroundName

        _title = State(initialValue: title)
        _mode = State(initialValue: mode)
        _presetID = State(initialValue: presetID)
        _countdownDuration = State(initialValue: countdownDuration)
        _backgroundName = State(initialValue: backgroundName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField(String(localized: "task.name"), text: $title)
                        
                        if isDuplicateName {
                            Text(String(localized: "task.error.duplicateName"))
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }

                    Picker(String(localized: "task.mode"), selection: $mode) {
                        ForEach(FocusMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    Picker(String(localized: "task.background"), selection: $backgroundName) {
                        ForEach(backgrounds, id: \.self) { name in
                            Text(backgroundTitle(for: name)).tag(name)
                        }
                    }
                }

                if mode == .pomodoro {
                    Section(String(localized: "task.form.timer")) {
                        Picker(String(localized: "task.preset"), selection: $presetID) {
                            ForEach(PomodoroPreset.all) { preset in
                                Text(String(format: "%@ %d/%d", FocusMode.pomodoro.label, Int(preset.workDuration / 60), Int(preset.breakDuration / 60))).tag(preset.id)
                            }
                        }
                    }
                }

                if mode == .countdown {
                    Section(String(localized: "task.form.timer")) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                Slider(value: countdownSliderMinutesBinding, in: 5...300, step: 5)
                                Button {
                                    customCountdownMinutesText = "\(countdownMinutes)"
                                    showAdvancedCountdownEditor = true
                                } label: {
                                    Image(systemName: "square.and.pencil")
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel(String(localized: "common.edit"))
                            }

                            Text(String(format: String(localized: "task.countdown.minutes.preview"), countdownMinutes))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(task == nil ? String(localized: "task.add") : String(localized: "task.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .chronaSoftScrollEdgeEffect()
            .background(PageBackground(seed: backgroundName))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        requestDismiss()
                    }
                    .confirmationDialog(
                        String(localized: "editor.discardChanges.title"),
                        isPresented: $showDiscardChangesConfirm,
                        titleVisibility: .visible
                    ) {
                        Button(String(localized: "editor.discardChanges.action"), role: .destructive) {
                            dismiss()
                        }
                        Button(String(localized: "common.cancel"), role: .cancel) {}
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDuplicateName)
                }
            }
            .alert(String(localized: "task.countdown.advanced.title"), isPresented: $showAdvancedCountdownEditor) {
                TextField(String(localized: "task.countdown.advanced.placeholder"), text: $customCountdownMinutesText)
                Button(String(localized: "common.cancel"), role: .cancel) {}
                Button(String(localized: "common.done")) {
                    applyCustomCountdownMinutes()
                }
            } message: {
                Text(String(localized: "task.countdown.advanced.message"))
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
        }
    }

    private func requestDismiss() {
        guard hasUnsavedChanges else {
            dismiss()
            return
        }
        showDiscardChangesConfirm = true
    }

    private func save() {
        var output = task ?? TaskItem(title: title, mode: mode, order: 0)
        output.title = title
        output.mode = mode
        output.pomodoroPresetID = presetID
        output.countdownDuration = countdownDuration
        output.backgroundName = backgroundName
        onSave(output)
        dismiss()
    }

    private func backgroundTitle(for name: String) -> String {
        switch name {
        case "forest":
            return String(localized: "background.forest")
        case "ocean":
            return String(localized: "background.ocean")
        case "lavender":
            return String(localized: "background.lavender")
        case "midnight":
            return String(localized: "background.midnight")
        case "mint":
            return String(localized: "background.mint")
        default:
            return String(localized: "background.sunset")
        }
    }

    private var countdownMinutes: Int {
        min(max(Int((countdownDuration / 60).rounded()), 1), 300)
    }

    private var isDuplicateName: Bool {
        _appModel.wrappedValue.isTaskNameDuplicate(title, excluding: task?.id)
    }

    private var hasUnsavedChanges: Bool {
        title != initialTitle
            || mode != initialMode
            || presetID != initialPresetID
            || countdownDuration != initialCountdownDuration
            || backgroundName != initialBackgroundName
    }

    private var countdownSliderMinutesBinding: Binding<Double> {
        Binding(
            get: {
                let snapped = Int((Double(countdownMinutes) / 5).rounded()) * 5
                return Double(min(max(snapped, 5), 300))
            },
            set: { newValue in
                let stepped = Int(newValue.rounded() / 5) * 5
                countdownDuration = TimeInterval(min(max(stepped, 5), 300) * 60)
            }
        )
    }

    private func applyCustomCountdownMinutes() {
        guard let minutes = Int(customCountdownMinutesText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }
        countdownDuration = TimeInterval(min(max(minutes, 1), 300) * 60)
    }
}

#Preview("Add Task") {
    TaskEditorView(task: nil) { _ in }
}

#Preview("Edit Task") {
    TaskEditorView(
        task: TaskItem(
            title: "Deep Work",
            mode: .pomodoro,
            pomodoroPresetID: PomodoroPreset.preset25.id,
            countdownDuration: 25 * 60,
            backgroundName: "sunset",
            order: 0
        )
    ) { _ in }
}
