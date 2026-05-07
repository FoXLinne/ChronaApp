import SwiftUI
#if os(iOS)
import UIKit
#endif

/// 界面旋转方向控制器
/// 提供静态方法 `setRotationEnabled(_:)` 用于全局开启 / 关闭屏幕旋转
enum InterfaceOrientationController {

    /// 设置屏幕旋转是否开启
    /// - Parameter enabled: `true` 表示允许旋转（开启横屏），`false` 表示锁定竖屏
    static func setRotationEnabled(_ enabled: Bool) {
        #if os(iOS)
        // 异步派发到主线程执行，确保 UI 操作线程安全
        DispatchQueue.main.async {
            // 第一步：更新 AppDelegate 中的全局方向锁
            // 这是系统查询「支持哪些方向」的唯一权威来源
            ChronaAppDelegate.orientationLock = enabled ? .allButUpsideDown : .portrait

            // 获取当前激活的窗口场景，后续操作需要通过它发送几何更新请求
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
                return
            }

            // 第二步：主动请求几何更新，直接告知系统需要切换到指定的方向限制
            let mask: UIInterfaceOrientationMask = enabled ? .allButUpsideDown : .portrait
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))

            // 第三步：通知根 ViewController 重新评估并更新其支持的界面方向
            // 确保 UI 状态与锁定状态保持同步，是整个流程的最后一道保障
            windowScene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        #else
        // 非 iOS 平台（如 macOS）不支持旋转控制，空操作避免编译警告
        _ = enabled
        #endif
    }
}
