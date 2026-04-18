import SwiftUI

struct ActiveSessionView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var revealControls = true
    @State private var showStopConfirm = false
    @State private var showDiscardConfirm = false
    @State private var autoHideTask: Task<Void, Never>?
    @State private var hasPlayedInitialImmersiveTransition = false

    private var isImmersive: Bool {
        appModel.shouldShowMinimalMode && !revealControls
    }

    var body: some View {
        ZStack {
            AppBackground(seed: appModel.activeTask?.backgroundName ?? "sunset")
            Color.black
                .ignoresSafeArea()
                .opacity(isImmersive ? 1 : 0)
                .animation(.smooth, value: isImmersive)

            if let session = appModel.activeSession, let status = appModel.timerStatus {
                Color.black
                    .ignoresSafeArea()
                    .opacity(session.phase == .focus && session.isPaused ? (isImmersive ? 0.22 : 0.3) : 0)
                    .animation(.smooth, value: session.isPaused)

                let timerText = appModel.formattedDuration(status.remaining ?? status.elapsed)

                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Text(session.phase == .rest ? String(localized: "session.resting") : session.taskTitle)
                            .font(.title2.weight(.semibold))
                        Text(session.mode == .pomodoro ? String(localized: "mode.pomodoro") : session.mode == .stopwatch ? String(localized: "mode.stopwatch") : String(localized: "mode.countdown"))
                            .foregroundStyle(.secondary)
                    }
                    .opacity(isImmersive ? 0 : 1)
                    .frame(height: isImmersive ? 0 : nil)

                    Text(timerText)
                        .font(.system(size: timerFontSize(for: timerText), weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .contentTransition(isImmersive ? .identity : .numericText())
                        .monospacedDigit()
                        .animation(isImmersive ? nil : .smooth, value: status.remaining ?? status.elapsed)

                    if session.phase == .focus {
                        progressView(status: status, session: session)
                            .opacity(isImmersive ? 0 : 1)
                            .frame(height: isImmersive ? 0 : nil)
                    }

                    if revealControls || !appModel.shouldShowMinimalMode {
                        controlPanel(for: session)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    if session.phase == .focus, session.mode != .pomodoro, session.isPaused {
                        pauseStatusView(for: session)
                            .opacity(isImmersive ? 0 : 1)
                            .frame(height: isImmersive ? 0 : nil)
                    }

                    if isImmersive {
                        Text(String(localized: "session.tapHint"))
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }
                .padding(24)
                .foregroundStyle(.white)
                .animation(.smooth, value: revealControls)
            } else {
                emptyState
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard isImmersive else { return }
            withAnimation(.smooth) {
                revealControls = true
            }
            scheduleAutoImmersion()
        }
        .onAppear {
            ScreenAwakeController.updateRefreshRate(isImmersive: isImmersive)
            appModel.setActiveImmersiveChromeHidden(isImmersive)
        }
        .onChange(of: appModel.shouldShowMinimalMode) { _, enabled in
            if enabled {
                if hasPlayedInitialImmersiveTransition {
                    revealControls = false
                } else {
                    withAnimation(.smooth.delay(0.2)) {
                        revealControls = false
                    }
                    hasPlayedInitialImmersiveTransition = true
                }
                scheduleAutoImmersion()
            } else {
                revealControls = true
                autoHideTask?.cancel()
            }
            ScreenAwakeController.updateRefreshRate(isImmersive: appModel.shouldShowMinimalMode && !revealControls)
            appModel.setActiveImmersiveChromeHidden(appModel.shouldShowMinimalMode && !revealControls)
        }
        .onChange(of: revealControls) { _, _ in
            ScreenAwakeController.updateRefreshRate(isImmersive: appModel.shouldShowMinimalMode && !revealControls)
            appModel.setActiveImmersiveChromeHidden(appModel.shouldShowMinimalMode && !revealControls)
            if revealControls {
                scheduleAutoImmersion()
            }
        }
        .onDisappear {
            autoHideTask?.cancel()
            ScreenAwakeController.updateRefreshRate(isImmersive: false)
            appModel.setActiveImmersiveChromeHidden(false)
        }
        .toolbar(isImmersive ? .hidden : .visible, for: .tabBar)
        .statusBarHidden(appModel.shouldShowMinimalMode && !revealControls)
        .alert(String(localized: "session.stop.confirm.title"), isPresented: $showStopConfirm) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "common.stop"), role: .destructive) {
                if appModel.stopConsequence() == .discardAdvancedRule {
                    showDiscardConfirm = true
                } else {
                    appModel.stopActiveSession()
                }
            }
        } message: {
            Text(String(localized: "session.stop.confirm.message"))
        }
        .alert(String(localized: "session.discard.confirm.title"), isPresented: $showDiscardConfirm) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "session.discard.confirm.action"), role: .destructive) {
                appModel.stopActiveSession()
            }
        } message: {
            Text(String(localized: "session.discard.confirm.message"))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "timer.circle.fill")
                .font(.system(size: 96))
                .foregroundStyle(.white.opacity(0.9))
            Text(String(localized: "session.noTask"))
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white)
            Text(String(localized: "session.noTask.subtitle"))
                .multilineTextAlignment(.center)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
            if appModel.quickLaunchTaskID != nil {
                if let lastTask = appModel.quickLaunchTask {
                    Text(String(format: String(localized: "session.lastTask"), lastTask.title))
                        .foregroundStyle(.white.opacity(0.75))
                        .font(.footnote)
                        .padding(12)
                }
                Button(String(localized: "session.quickStart")) {
                    appModel.quickStartLastTask()
                }
                .font(.headline.weight(.semibold))
                .buttonSizing(.flexible)
                .padding(.horizontal, 108)
                .controlSize(.extraLarge)
                .buttonStyle(.glass(.regular.tint(.accentColor)))
                .foregroundStyle(.white)
            }
            Button(String(localized: "session.goTasks")) {
                appModel.openTasksTab()
            }
            .font(.headline.weight(.semibold))
            .buttonSizing(.flexible)
            .padding(.horizontal, 108)
            .controlSize(.extraLarge)
            .buttonStyle(.glass(.regular.tint(.blue)))
            .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func progressView(status: TimerStatus, session: ActiveSessionSnapshot) -> some View {
        if let target = session.focusDuration ?? session.restDuration {
            ProgressView(value: min(1, status.elapsed / max(1, target)))
                .tint(.white)
        } else {
            Text(String(localized: "session.elapsed"))
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    @ViewBuilder
    private func pauseStatusView(for session: ActiveSessionSnapshot) -> some View {
        if let deadline = session.pauseDeadline {
            let remaining = max(0, deadline.timeIntervalSince(appModel.now))
            VStack(spacing: 6) {
                Label(String(localized: "session.pause.statusLimited"), systemImage: "pause.circle.fill")
                Text(String(format: String(localized: "session.pause.remaining"), appModel.formattedDuration(remaining)))
                    .font(.footnote)
            }
            .foregroundStyle(.white.opacity(0.85))
        } else {
            Label(String(localized: "session.pause.status"), systemImage: "pause.circle.fill")
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    @ViewBuilder
    private func controlPanel(for session: ActiveSessionSnapshot) -> some View {
        VStack(spacing: 14) {
            if session.phase == .focus {
                HStack(spacing: 12) {
                    if session.mode != .pomodoro && !appModel.settings.advancedDisallowPause {
                        Button(session.isPaused ? String(localized: "common.resume") : String(localized: "common.pause")) {
                            appModel.pauseOrResumeActiveSession()
                        }
                        .buttonStyle(.glass(.regular.tint(.blue)))
                        .foregroundStyle(.white)
                    }

                    Button(String(localized: "common.stop")) {
                        showStopConfirm = true
                    }
                    .buttonStyle(.glass(.regular.tint(.red)))
                    .foregroundStyle(.white)
                }

                if appModel.settings.advancedDisallowEarlyFinish {
                    Text(String(localized: "settings.earlyFinish.note"))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                }
            } else {
                Button(String(localized: "session.endRest")) {
                    appModel.endRest()
                }
                .buttonStyle(.glass(.regular.tint(.red)))
                .foregroundStyle(.white)
            }
        }
        .controlSize(.large)
    }

    private func scheduleAutoImmersion() {
        autoHideTask?.cancel()
        guard appModel.shouldShowMinimalMode, revealControls else { return }
        let delay = UInt64(max(1, appModel.minimalModeActivationDelaySeconds))

        autoHideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            guard appModel.shouldShowMinimalMode, revealControls else { return }
            withAnimation(.smooth) {
                revealControls = false
            }
        }
    }

    private func timerFontSize(for timerText: String) -> CGFloat {
        guard isImmersive else { return 72 }
        let hasHourPart = timerText.filter { $0 == ":" }.count >= 2
        return hasHourPart ? 92 : 108
    }
}

#Preview("Empty") {
    ActiveSessionView()
        .environmentObject(AppViewModel())
}

#Preview("Empty With Quick Start") {
    let model = AppViewModel()
    model.activeSession = nil
    model.quickLaunchTaskID = model.sortedTasks.first?.id

    return ActiveSessionView()
        .environmentObject(model)
}
