import SwiftUI
#if os(iOS) || os(tvOS)
import UIKit
#endif

enum ScreenAwakeController {
    static func update(isEnabled: Bool) {
        DispatchQueue.main.async {
            #if os(iOS) || os(tvOS)
            UIApplication.shared.isIdleTimerDisabled = isEnabled
            #else
            _ = isEnabled
            #endif
        }
    }

    static func updateRefreshRate(isImmersive: Bool) {
        DispatchQueue.main.async {
            // Keep this as a no-op on SDKs that do not expose a stable app-level refresh-rate API.
            _ = isImmersive
        }
    }
}
