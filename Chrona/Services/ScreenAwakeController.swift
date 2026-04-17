import SwiftUI
import UIKit

enum ScreenAwakeController {
    static func update(isEnabled: Bool) {
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = isEnabled
        }
    }

    static func updateRefreshRate(isImmersive: Bool) {
        DispatchQueue.main.async {
            // Keep this as a no-op on SDKs that do not expose a stable app-level refresh-rate API.
            _ = isImmersive
        }
    }
}
