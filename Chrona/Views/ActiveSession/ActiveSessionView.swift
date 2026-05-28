import Combine
import SwiftUI

struct ActiveSessionView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var revealControls = true
    @State private var showStopConfirm = false
    @State private var showDiscardConfirm = false
    @State private var autoHideTask: Task<Void, Never>?
    @State private var hasPlayedInitialImmersiveTransition = false
    @State private var disableClockAnimation = false
    @State private var showSettings = false
    @State private var timerDisplayDraft = AppSettings.default
    @State private var batteryLevel: Float = -1
    @State private var isLandscapeForOverlay = false
    @State private var burnInOffset = CGSize.zero
    @Environment(\.colorScheme) private var colorScheme

    private var isImmersive: Bool {
        appModel.shouldShowMinimalMode && !revealControls
    }

    private var primaryForeground: Color {
        if isImmersive { return .white }
        return appModel.settings.showPersonalizedBackground ? .white : .primary
    }

    private var secondaryForeground: Color {
        if isImmersive { return .white.opacity(0.75) }
        return appModel.settings.showPersonalizedBackground ? .white.opacity(0.75) : .secondary
    }

    private var statusBarForeground: Color {
        if isImmersive { return .white.opacity(0.35) }
        if appModel.settings.showPersonalizedBackground { return .white.opacity(0.55) }
        return colorScheme == .dark ? .white.opacity(0.45) : .primary.opacity(0.55)
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                if appModel.settings.showPersonalizedBackground {
                    AppBackground(seed: appModel.activeTask?.backgroundName ?? ThemePalette.defaultSeed)
                } else {
                    AppBackgroundLite()
                }
                Color.black
                    .ignoresSafeArea()
                    .opacity(isImmersive ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: isImmersive)

                if let session = appModel.activeSession, let status = appModel.timerStatus {
                    Color.black
                        .ignoresSafeArea()
                        .opacity(session.phase == .focus && session.isPaused ? (isImmersive ? 0.22 : 0.3) : 0)
                        .animation(.smooth, value: session.isPaused)
                        .animation(.easeInOut(duration: 0.3), value: isImmersive)

                    let timerText = appModel.formattedDuration(status.remaining ?? status.elapsed)

                    if isLandscape {
                        HStack(spacing: 32) {
                            // 长任务名限制为两行，避免横屏时挤压计时器和控制栏。
                            VStack(spacing: 10) {
                                Text(session.phase == .rest ? String(localized: "session.resting") : session.taskTitle)
                                    .font(.title2.weight(.semibold))
                                    .lineLimit(2)
                                    .truncationMode(.tail)
                                Text(session.mode.label)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            VStack(spacing: 12) {
                                Text(timerText)
                                    .font(.system(size: timerFontSize(for: timerText, isLandscape: isLandscape), weight: .bold, design: .rounded))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .contentTransition(disableClockAnimation ? .identity : .numericText())
                                    .monospacedDigit()
                                    .animation(disableClockAnimation ? nil : .smooth, value: status.remaining ?? status.elapsed)

                                if !isImmersive, session.phase == .focus {
                                    // 横屏进度条随可用宽度收缩，兼容小尺寸设备。
                                    progressView(status: status, session: session)
                                        .frame(width: min(220, geometry.size.width * 0.28))
                                }

                                if isImmersive {
                                    Text(String(localized: "session.tapHint"))
                                        .font(.footnote)
                                        .foregroundStyle(secondaryForeground)
                                }
                            }

                            if !isImmersive {
                                // 横屏保持控制栏在上、暂停状态在下，与竖屏交互一致。
                                VStack(spacing: 16) {
                                    if revealControls || !appModel.shouldShowMinimalMode {
                                        // 横屏使用更紧凑的控件尺寸，避免溢出安全区域。
                                        controlPanel(for: session, isLandscape: true)
                                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                                    }

                                    if session.phase == .focus, session.mode != .pomodoro, session.isPaused {
                                        pauseStatusView(for: session)
                                    }
                                }
                            }
                        }
                        // 横屏垂直留白更小，避免低高度场景内容被裁切。
                        .padding(.horizontal, 24)
                        .padding(.vertical, isLandscape ? 12 : 24)
                        .foregroundStyle(primaryForeground)
                        .animation(.smooth, value: revealControls)
                        .animation(.smooth, value: isImmersive)
                        .transition(.opacity.combined(with: .scale(scale: 1.05)))
                    } else {
                        VStack(spacing: 24) {
                            // 竖屏同样限制长标题，保持计时器位置稳定。
                            VStack(spacing: 10) {
                                Text(session.phase == .rest ? String(localized: "session.resting") : session.taskTitle)
                                    .font(.title2.weight(.semibold))
                                    .lineLimit(2)
                                    .truncationMode(.tail)
                                Text(session.mode.label)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Text(timerText)
                                .font(.system(size: timerFontSize(for: timerText, isLandscape: isLandscape), weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                                .contentTransition(disableClockAnimation ? .identity : .numericText())
                                .monospacedDigit()
                                .animation(disableClockAnimation ? nil : .smooth, value: status.remaining ?? status.elapsed)

                            if !isImmersive, session.phase == .focus {
                                progressView(status: status, session: session)
                            }

                            if !isImmersive, revealControls || !appModel.shouldShowMinimalMode {
                                controlPanel(for: session, isLandscape: false)
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }

                            if !isImmersive, session.phase == .focus, session.mode != .pomodoro, session.isPaused {
                                pauseStatusView(for: session)
                            }

                            if isImmersive {
                                Text(String(localized: "session.tapHint"))
                                    .font(.footnote)
                                    .foregroundStyle(secondaryForeground)
                            }
                        }
                        .padding(24)
                        .foregroundStyle(primaryForeground)
                        .animation(.smooth, value: revealControls)
                        .animation(.smooth, value: isImmersive)
                        .transition(.opacity.combined(with: .scale(scale: 1.05)))
                    }
                } else {
                    emptyState(isLandscape: isLandscape)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

            }
            .animation(.smooth, value: appModel.activeSession == nil)
            .onChange(of: isLandscape) { _, newValue in isLandscapeForOverlay = newValue }
        }
        .transition(.opacity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isImmersive else { return }
            withAnimation(.smooth) {
                revealControls = true
            }
            scheduleAutoImmersion()
        }
        .onAppear {
            appModel.setActiveImmersiveChromeHidden(isImmersive)
            disableClockAnimation = isImmersive
            UIDevice.current.isBatteryMonitoringEnabled = true
            batteryLevel = UIDevice.current.batteryLevel
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !isImmersive {
                    Button {
                        timerDisplayDraft = appModel.settings
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                    .buttonStyle(.plain)
                }
            }
        }.toolbar(isImmersive ? .hidden : .visible, for: .navigationBar)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                TimerDisplaySettingsView(draft: $timerDisplayDraft)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                showSettings = false
                            } label: {
                                Image(systemName: "xmark")
                            }
                        }
                    }
            }
        }
        .onChange(of: appModel.selectedTab) { _, newTab in
            if newTab != .active {
                showSettings = false
            }
        }
        .onChange(of: timerDisplayDraft) { _, newDraft in
            appModel.settings = newDraft
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
            
            appModel.setActiveImmersiveChromeHidden(appModel.shouldShowMinimalMode && !revealControls)
        }
        .onChange(of: revealControls) { _, _ in
            appModel.setActiveImmersiveChromeHidden(appModel.shouldShowMinimalMode && !revealControls)
            if revealControls {
                scheduleAutoImmersion()
            }
        }
        .onChange(of: isImmersive) { _, newValue in
            if newValue {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1))
                    if isImmersive {
                        disableClockAnimation = true
                    }
                }
            } else {
                disableClockAnimation = false
            }
        }

        .onReceive(NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)) { _ in
            batteryLevel = UIDevice.current.batteryLevel
        }
        .onReceive(Timer.publish(every: 300, on: .main, in: .common).autoconnect()) { _ in
            let maxShift: CGFloat = 3
            burnInOffset = CGSize(
                width: CGFloat.random(in: -maxShift...maxShift),
                height: CGFloat.random(in: -maxShift...maxShift)
            )
        }

        .onDisappear {
            autoHideTask?.cancel()
            appModel.setActiveImmersiveChromeHidden(false)
            UIDevice.current.isBatteryMonitoringEnabled = false
        }
        .toolbar(isImmersive ? .hidden : .visible, for: .tabBar)
        .statusBarHidden(appModel.shouldShowMinimalMode && !revealControls)
        .overlay(alignment: .topLeading) {
            if appModel.settings.showStatusBarOverlay {
                statusBarContent
                    .padding(.top, (isLandscapeForOverlay ? 35 : 75) + burnInOffset.height)
                    .padding(.leading, (isLandscapeForOverlay ? 50 : 20) + burnInOffset.width)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(nil, value: isImmersive)
            }
        }
        .alert(String(localized: "session.stop.confirm.title"), isPresented: $showStopConfirm) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "common.stop"), role: .destructive) {
                if appModel.stopConsequence() == .discardAdvancedRule {
                    showDiscardConfirm = true
                } else {
                    withAnimation(.smooth) {
                        appModel.stopActiveSession()
                    }
                }
            }
        } message: {
            Text(String(localized: "session.stop.confirm.message"))
        }
        .alert(String(localized: "session.discard.confirm.title"), isPresented: $showDiscardConfirm) {
            Button(String(localized: "common.cancel"), role: .cancel) {}
            Button(String(localized: "session.discard.confirm.action"), role: .destructive) {
                withAnimation(.smooth) {
                    appModel.stopActiveSession()
                }
            }
        } message: {
            Text(String(localized: "session.discard.confirm.message"))
        }
    }

    // MARK: - 状态栏覆盖层（时间 + 电量）

    private var statusBarContent: some View {
        HStack(spacing: 5) {
            Text(appModel.now.formatted(.dateTime.hour().minute()))
                .font(.system(size: 11, weight: .regular, design: .rounded))

            Text(String(localized: "common.separator"))
                .font(.system(size: 11, weight: .thin))

            if batteryLevel >= 0 {
                Image(systemName: batteryIcon(for: batteryLevel))
                    .font(.system(size: 9, weight: .light))

                Text(verbatim: "\(Int(batteryLevel * 100))%")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
            }
        }
        .foregroundStyle(statusBarForeground)
    }

    private func batteryIcon(for level: Float) -> String {
        switch level {
        case ..<0.1: return "battery.0"
        case ..<0.25: return "battery.25"
        case ..<0.5: return "battery.50"
        case ..<0.75: return "battery.75"
        default: return "battery.100"
        }
    }

    @ViewBuilder
    private func emptyState(isLandscape: Bool) -> some View {
        if isLandscape {
            HStack(spacing: 24) {
                Image(systemName: "timer.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(appModel.settings.showPersonalizedBackground || colorScheme == .dark ? .white : Color.accentColor)

                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "session.noTask"))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(primaryForeground)
                    Text(String(localized: "session.noTask.subtitle"))
                        .multilineTextAlignment(.leading)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(secondaryForeground)

                    if appModel.quickLaunchTaskID != nil {
                        if let lastTask = appModel.quickLaunchTask {
                            Text(String(format: String(localized: "session.lastTask"), lastTask.title))
                                .foregroundStyle(secondaryForeground)
                                .font(.footnote)
                        }
                    }

                    HStack(spacing: 12) {
                        if appModel.quickLaunchTaskID != nil {
                            Button(String(localized: "session.quickStart")) {
                                appModel.quickStartLastTask()
                            }
                            .font(.headline.weight(.semibold))
                            .controlSize(.large)
                            .buttonStyle(.glass(.regular.tint(.accentColor)))
                            .foregroundStyle(.white)
                        }

                        Button(String(localized: "session.goTasks")) {
                            appModel.openTasksTab()
                        }
                        .font(.headline.weight(.semibold))
                        .controlSize(.large)
                        .buttonStyle(.glass(.regular.tint(.blue)))
                        .foregroundStyle(.white)
                    }
                }
            }
            .padding(24)
        } else {
            VStack(spacing: 18) {
                Image(systemName: "timer.circle.fill")
                    .font(.system(size: 96))
                    .foregroundStyle(appModel.settings.showPersonalizedBackground || colorScheme == .dark ? .white : Color.accentColor)
                Text(String(localized: "session.noTask"))
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(primaryForeground)
                Text(String(localized: "session.noTask.subtitle"))
                    .multilineTextAlignment(.center)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(secondaryForeground)
                if appModel.quickLaunchTaskID != nil {
                    if let lastTask = appModel.quickLaunchTask {
                        Text(String(format: String(localized: "session.lastTask"), lastTask.title))
                            .foregroundStyle(secondaryForeground)
                            .font(.footnote)
                            .padding(12)
                    }
                    Button(String(localized: "session.quickStart")) {
                        appModel.quickStartLastTask()
                    }
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, min(108, 80))
                    .controlSize(.extraLarge)
                    .buttonStyle(.glass(.regular.tint(.accentColor)))
                    .foregroundStyle(.white)
                }
                Button(String(localized: "session.goTasks")) {
                    appModel.openTasksTab()
                }
                .font(.headline.weight(.semibold))
                .padding(.horizontal, min(108, 80))
                .controlSize(.extraLarge)
                .buttonStyle(.glass(.regular.tint(.blue)))
                .foregroundStyle(.white)
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func progressView(status: TimerStatus, session: ActiveSessionSnapshot) -> some View {
        if let target = session.focusDuration ?? session.restDuration {
            ProgressView(value: min(1, status.elapsed / max(1, target)))
                .tint(.white)
        } else {
            Text(String(localized: "session.elapsed"))
                .foregroundStyle(secondaryForeground)
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
            .foregroundStyle(secondaryForeground)
        } else {
            Label(String(localized: "session.pause.status"), systemImage: "pause.circle.fill")
                .foregroundStyle(secondaryForeground)
        }
    }

    @ViewBuilder
    private func controlPanel(for session: ActiveSessionSnapshot, isLandscape: Bool = false) -> some View {
        VStack(spacing: isLandscape ? 10 : 14) {
            if session.phase == .focus {
                HStack(spacing: 12) {
                    if session.mode != .pomodoro && !appModel.settings.advancedDisallowPause {
                        Button(session.isPaused ? String(localized: "common.resume") : String(localized: "common.pause")) {
                            withAnimation(.smooth) {
                                appModel.pauseOrResumeActiveSession()
                            }
                        }
                        .font(.headline.weight(.semibold))
                        .buttonStyle(.glass(.regular.tint(.blue)))
                        .foregroundStyle(.white)
                    }

                    Button(String(localized: "common.stop")) {
                        showStopConfirm = true
                    }
                    .font(.headline.weight(.semibold))
                    .buttonStyle(.glass(.regular.tint(.red)))
                    .foregroundStyle(.white)
                }

                if appModel.settings.advancedDisallowEarlyFinish {
                    Text(String(localized: "settings.earlyFinish.note"))
                        .font(.footnote)
                        .foregroundStyle(secondaryForeground)
                }
            } else {
                Button(String(localized: "session.endRest")) {
                    withAnimation(.smooth) {
                        appModel.endRest()
                    }
                }
                .font(.headline.weight(.semibold))
                .buttonStyle(.glass(.regular.tint(.red)))
                .foregroundStyle(.white)
            }
        }
        // 按钮尺寸保持 .large，横屏无需缩减
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

    private func timerFontSize(for timerText: String, isLandscape: Bool) -> CGFloat {
        guard isImmersive else { return isLandscape ? 96 : 72 }
        let hasHourPart = timerText.filter { $0 == ":" }.count >= 2
        if isLandscape {
            return hasHourPart ? 160 : 200
        } else {
            return hasHourPart ? 92 : 108
        }
    }
}

private struct AppBackgroundLite: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if colorScheme == .dark {
            Color(UIColor.secondarySystemBackground)
                .ignoresSafeArea()
        } else {
            LinearGradient(
                colors: ThemePalette.editorBackgroundColors(for: "sunset", colorScheme: .light),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
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

#Preview("Landscape Empty", traits: .landscapeLeft) {
    ActiveSessionView()
        .environmentObject(AppViewModel())
}
