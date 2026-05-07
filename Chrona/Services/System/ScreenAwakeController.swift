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
}
