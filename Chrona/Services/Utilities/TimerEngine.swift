import Foundation

struct TimerStatus {
    var elapsed: TimeInterval
    var remaining: TimeInterval?
    var isFinished: Bool
}

enum TimerEngine {
    static func status(for snapshot: ActiveSessionSnapshot, now: Date = .now) -> TimerStatus {
        // Always derive progress from wall-clock time so backgrounding and relaunch stay accurate.
        let effectiveNow = snapshot.isPaused ? (snapshot.pausedAt ?? now) : now
        let elapsed = max(0, effectiveNow.timeIntervalSince(snapshot.startedAt) - snapshot.pausedAccumulated)
        let targetDuration = snapshot.phase == .focus ? snapshot.focusDuration : snapshot.restDuration

        guard let targetDuration else {
            return TimerStatus(elapsed: elapsed, remaining: nil, isFinished: false)
        }

        let remaining = max(0, targetDuration - elapsed)
        return TimerStatus(elapsed: elapsed, remaining: remaining, isFinished: remaining <= 0)
    }
}
