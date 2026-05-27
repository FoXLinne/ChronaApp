import Foundation

/// Widget 只需要展示倒数日的轻量字段，避免依赖主 App 的完整数据模型。
struct SharedCountdownEvent: Codable, Hashable, Identifiable {
    var id: UUID
    var title: String
    var date: Date
    var includesTime: Bool
}

/// Widget 热力图使用的每日专注时长。
struct SharedDailyFocusDuration: Codable, Hashable, Identifiable {
    var day: Date
    var duration: TimeInterval

    var id: Date { day }
}

/// App Group 共享数据容器，主 App 与 Widget 之间传递专注数据。
enum SharedStore {
    private static let fallbackAppGroupID = "group.top.kaedekr.chrona"
    private static let appGroupEntitlementKey = "com.apple.security.application-groups"
    private static let countdownEventsKey = "countdownEvents"
    private static let monthlyFocusDurationsKey = "monthlyFocusDurations"

    /// SideStore 等重签流程可能改写 App Group，运行时优先使用最终 profile 里的 group。
    static let appGroupID = signedAppGroupID ?? fallbackAppGroupID

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private static var signedAppGroupID: String? {
        guard let profileURL = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let profileData = try? Data(contentsOf: profileURL),
              let plistData = embeddedPlistData(from: profileData),
              let plist = try? PropertyListSerialization.propertyList(
                from: plistData,
                format: nil
              ) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let groups = entitlements[appGroupEntitlementKey] as? [String]
        else {
            return nil
        }

        return groups.first { $0.hasPrefix("group.") }
    }

    private static func embeddedPlistData(from profileData: Data) -> Data? {
        guard let startMarker = "<?xml".data(using: .utf8),
              let endMarker = "</plist>".data(using: .utf8),
              let start = profileData.range(of: startMarker)?.lowerBound,
              let end = profileData.range(of: endMarker, in: start..<profileData.endIndex)?.upperBound
        else {
            return nil
        }

        return profileData.subdata(in: start..<end)
    }

    /// 今日专注总时长（秒），由主 App 写入，Widget 读取。
    static var todayFocusDuration: TimeInterval {
        get { defaults?.double(forKey: "todayFocusDuration") ?? 0 }
        set { defaults?.set(newValue, forKey: "todayFocusDuration") }
    }

    /// 最后更新时间戳，Widget 用来判断数据新鲜度。
    static var lastUpdated: Date? {
        get { defaults?.object(forKey: "lastUpdated") as? Date }
        set { defaults?.set(newValue, forKey: "lastUpdated") }
    }

    /// 倒数日事件列表，由主 App 写入，Widget 配置和展示读取。
    static var countdownEvents: [SharedCountdownEvent] {
        get {
            guard let data = defaults?.data(forKey: countdownEventsKey) else { return [] }
            return (try? JSONDecoder().decode([SharedCountdownEvent].self, from: data)) ?? []
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults?.set(data, forKey: countdownEventsKey)
        }
    }

    /// 本月每日专注时长，供热力图 Widget 读取。
    static var monthlyFocusDurations: [SharedDailyFocusDuration] {
        get {
            guard let data = defaults?.data(forKey: monthlyFocusDurationsKey) else { return [] }
            return (try? JSONDecoder().decode([SharedDailyFocusDuration].self, from: data)) ?? []
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults?.set(data, forKey: monthlyFocusDurationsKey)
        }
    }

    /// 同步今日专注时长到共享容器。
    static func syncTodayFocusDuration(_ duration: TimeInterval) {
        todayFocusDuration = duration
        lastUpdated = .now
    }

    /// 同步倒数日事件列表到共享容器。
    static func syncCountdownEvents(_ events: [SharedCountdownEvent]) {
        countdownEvents = events
        lastUpdated = .now
    }

    /// 同步本月每日专注时长到共享容器。
    static func syncMonthlyFocusDurations(_ durations: [SharedDailyFocusDuration]) {
        monthlyFocusDurations = durations
        lastUpdated = .now
    }
}
