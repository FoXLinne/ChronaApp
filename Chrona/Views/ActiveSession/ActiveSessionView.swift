import SwiftUI

struct ActiveSessionView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var revealControls = true

    var body: some View {
        ZStack {
            AppBackground(seed: appModel.activeTask?.backgroundName ?? "sunset")

            if let session = appModel.activeSession, let status = appModel.timerStatus {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Text(session.phase == .rest ? String(localized: "session.resting") : session.taskTitle)
                            .font(.title2.weight(.semibold))
                        Text(session.mode == .pomodoro ? String(localized: "mode.pomodoro") : session.mode == .stopwatch ? String(localized: "mode.stopwatch") : String(localized: "mode.countdown"))
                            .foregroundStyle(.secondary)
                    }

                    Text(appModel.formattedDuration(status.remaining ?? status.elapsed))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .monospacedDigit()
                        .animation(.smooth, value: status.remaining ?? status.elapsed)

                    if session.phase == .focus {
                        progressView(status: status, session: session)
                    }

                    if revealControls || !appModel.shouldShowMinimalMode {
                        controlPanel(for: session)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(24)
                .foregroundStyle(.white)
                .animation(.smooth, value: revealControls)
            } else {
                emptyState
            }

            if appModel.shouldShowMinimalMode && !revealControls {
                Color.black.ignoresSafeArea()
                VStack(spacing: 16) {
                    Text(appModel.formattedDuration(appModel.timerStatus?.remaining ?? appModel.timerStatus?.elapsed ?? 0))
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Button(String(localized: "session.showControls")) {
                        withAnimation(.smooth) {
                            revealControls = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.2))
                }
                .onTapGesture {
                    withAnimation(.smooth) {
                        revealControls = true
                    }
                }
            }
        }
        .onChange(of: appModel.shouldShowMinimalMode) { _, enabled in
            if enabled {
                withAnimation(.smooth.delay(0.2)) {
                    revealControls = false
                }
            } else {
                revealControls = true
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "timer.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white.opacity(0.9))
            Text(String(localized: "session.noTask"))
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
            Text(String(localized: "session.noTask.subtitle"))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
            if appModel.quickLaunchTaskID != nil {
                Button(String(localized: "session.quickStart")) {
                    appModel.quickStartLastTask()
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.2))
            }
        }
        .padding(28)
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
    private func controlPanel(for session: ActiveSessionSnapshot) -> some View {
        VStack(spacing: 14) {
            if session.phase == .focus {
                HStack(spacing: 12) {
                    if session.mode == .stopwatch && !appModel.settings.advancedDisallowPause {
                        Button(session.isPaused ? String(localized: "common.resume") : String(localized: "common.pause")) {
                            appModel.pauseOrResumeActiveSession()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white.opacity(0.2))
                    }

                    Button(String(localized: "common.stop")) {
                        appModel.stopActiveSession()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red.opacity(0.8))
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
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.2))
            }
        }
    }
}
