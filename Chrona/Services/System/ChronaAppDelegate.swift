#if os(iOS)
import UIKit

/// 应用程序委托，负责管理全局界面旋转方向的锁定
/// 通过实现 `supportedInterfaceOrientationsFor` 系统代理方法，
/// 作为系统查询「当前允许哪些屏幕方向」的唯一权威来源
final class ChronaAppDelegate: NSObject, UIApplicationDelegate {

    /// 全局屏幕方向锁，用于控制当前允许的旋转方向
    /// - 默认值为 `.portrait`（仅竖屏），应用启动时始终以竖屏显示
    /// - 由 `InterfaceOrientationController.setRotationEnabled(_:)` 在运行时动态修改
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    /// 系统回调：查询指定窗口所支持的界面方向
    /// - 每次设备旋转或方向策略更新时，系统都会调用此方法
    /// - 直接返回 `orientationLock` 以实现动态控制
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        Self.orientationLock
    }
}
#endif
