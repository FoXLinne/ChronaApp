import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import IOKit.ps
#endif

/// 平台电量读取入口。返回 nil 表示当前设备没有电池或系统无法提供电量。
enum BatteryStatusProvider {
    #if os(iOS)
    static let levelDidChangeNotification = UIDevice.batteryLevelDidChangeNotification
    #else
    static let levelDidChangeNotification = Notification.Name("BatteryStatusProvider.levelDidChange")
    #endif

    static func startMonitoring() {
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        #endif
    }

    static func stopMonitoring() {
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = false
        #endif
    }

    static var currentLevel: Float? {
        #if os(iOS)
        let level = UIDevice.current.batteryLevel
        return normalizedLevel(level)
        #elseif os(macOS)
        return macBatteryLevel
        #else
        return nil
        #endif
    }

    private static func normalizedLevel(_ level: Float) -> Float? {
        guard level >= 0 else { return nil }
        return min(max(level, 0), 1)
    }

    #if os(macOS)
    private static var macBatteryLevel: Float? {
        guard
            let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let powerSources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return nil
        }

        for source in powerSources {
            guard
                let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                let type = description[kIOPSTypeKey as String] as? String,
                type == kIOPSInternalBatteryType,
                let currentCapacity = description[kIOPSCurrentCapacityKey as String] as? Int,
                let maxCapacity = description[kIOPSMaxCapacityKey as String] as? Int,
                maxCapacity > 0
            else {
                continue
            }

            return normalizedLevel(Float(currentCapacity) / Float(maxCapacity))
        }

        return nil
    }
    #endif
}
