import CryptoKit
import Foundation

/// 负责数据与设置的分文件持久化、旧版本迁移及导入导出
final class PersistenceService {
    private let dataURL: URL
    private let settingsURL: URL
    private let legacyURL: URL

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let allowedBackgroundNames = Set(["sunset", "forest", "ocean", "lavender", "midnight", "mint"])

    init() {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        dataURL = base.appendingPathComponent("chrona_data.json")
        settingsURL = base.appendingPathComponent("chrona_settings.json")
        legacyURL = base.appendingPathComponent("chrona_state.json")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - 迁移

    /// 若旧版单文件存在，则补齐缺失或损坏的新文件；只有两份新文件都可读后才删除旧文件。
    func migrateIfNeeded() -> Bool {
        guard FileManager.default.fileExists(atPath: legacyURL.path),
              let data = try? Data(contentsOf: legacyURL),
              let snapshot = try? decoder.decode(AppSnapshot.self, from: data) else {
            return false
        }

        let isDataReady = canDecode(DataStore.self, at: dataURL)
        let isSettingsReady = canDecode(SettingsStore.self, at: settingsURL)
        guard !isDataReady || !isSettingsReady else {
            return false
        }

        let migratedData = DataStore(
            version: StorageSchemaVersion.current,
            tasks: snapshot.tasks,
            sessions: snapshot.sessions,
            countdownEvents: snapshot.countdownEvents,
            profile: snapshot.profile,
            checkInDates: snapshot.checkInDates,
            lastTaskID: snapshot.lastTaskID,
            activeSession: snapshot.activeSession
        )
        let migratedSettings = SettingsStore(
            version: StorageSchemaVersion.current,
            settings: snapshot.settings
        )

        let didSaveData = isDataReady || save(data: migratedData)
        let didSaveSettings = isSettingsReady || save(settings: migratedSettings)
        guard didSaveData,
              didSaveSettings,
              canDecode(DataStore.self, at: dataURL),
              canDecode(SettingsStore.self, at: settingsURL) else {
            return false
        }

        try? FileManager.default.removeItem(at: legacyURL)
        return true
    }

    // MARK: - 加载

    func loadData() -> DataStore {
        guard let data = try? Data(contentsOf: dataURL),
              let store = try? decoder.decode(DataStore.self, from: data) else {
            return .default
        }
        return store
    }

    func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let store = try? decoder.decode(SettingsStore.self, from: data) else {
            return .default
        }
        return store.settings
    }

    // MARK: - 保存

    @discardableResult
    func save(data store: DataStore) -> Bool {
        var copy = store
        copy.version = StorageSchemaVersion.current
        return writeAndVerify(copy, to: dataURL)
    }

    @discardableResult
    func save(settings store: SettingsStore) -> Bool {
        var copy = store
        copy.version = StorageSchemaVersion.current
        return writeAndVerify(copy, to: settingsURL)
    }

    /// 写入后立即读回解码，避免迁移阶段误删仍有价值的旧数据。
    private func writeAndVerify<T: Codable>(_ value: T, to url: URL) -> Bool {
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: [.atomic])
            return canDecode(T.self, at: url)
        } catch {
            print("Persistence write failed: \(error.localizedDescription)")
            return false
        }
    }

    private func canDecode<T: Decodable>(_ type: T.Type, at url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url) else { return false }
        return (try? decoder.decode(type, from: data)) != nil
    }

    // MARK: - 导出/导入

    /// 导出为含版本号的单文件，方便用户备份；进行中的计时会话不进入备份。
    func exportData(data dataStore: DataStore, settings: AppSettings) -> Data? {
        var export = ChronaExportFile(
            formatVersion: ExportFormatVersion.current,
            exportedAt: Date(),
            tasks: dataStore.tasks,
            sessions: dataStore.sessions,
            countdownEvents: dataStore.countdownEvents,
            profile: dataStore.profile,
            settings: settings,
            checkInDates: dataStore.checkInDates,
            lastTaskID: dataStore.lastTaskID,
            signature: nil
        )
        export.signature = signature(for: export)

        let exporter = JSONEncoder()
        exporter.dateEncodingStrategy = .iso8601
        exporter.outputFormatting = .prettyPrinted
        return try? exporter.encode(export)
    }

    /// 导入结果
    struct ImportResult {
        let tasks: [TaskItem]
        let sessions: [FocusSessionRecord]
        let countdownEvents: [CountdownEvent]
        let profile: ProfileInfo
        let settings: AppSettings
        let checkInDates: [Date]?
        let lastTaskID: UUID?
        /// 导入文件的格式版本号，若为旧格式则为 0
        let fileVersion: Int
        /// 导入文件是否来自旧版 AppSnapshot 格式
        let isLegacy: Bool
        /// 新版备份签名是否通过；旧备份没有签名，保持兼容导入。
        let isSignatureVerified: Bool
        /// 文件带有签名但校验失败，说明备份可能被修改或损坏。
        let isSignatureMismatch: Bool
    }

    /// 预检并解析导入数据，供确认弹窗和最终导入复用，避免同一文件重复解码。
    func inspectImport(data: Data) -> ImportResult? {
        // 尝试新版导出格式
        if let export = try? decoder.decode(ChronaExportFile.self, from: data) {
            let hasSignature = export.signature != nil
            let isSignatureVerified = verifySignatureIfPresent(for: export)
            return makeImportResult(
                tasks: export.tasks,
                sessions: export.sessions,
                countdownEvents: export.countdownEvents,
                profile: export.profile,
                settings: export.settings,
                checkInDates: export.checkInDates,
                lastTaskID: export.lastTaskID,
                fileVersion: export.formatVersion,
                isLegacy: false,
                isSignatureVerified: hasSignature && isSignatureVerified,
                isSignatureMismatch: hasSignature && !isSignatureVerified
            )
        }
        // 回退旧版 AppSnapshot（无版本号，视为 version 0）
        if let snapshot = try? decoder.decode(AppSnapshot.self, from: data) {
            return makeImportResult(
                tasks: snapshot.tasks,
                sessions: snapshot.sessions,
                countdownEvents: snapshot.countdownEvents,
                profile: snapshot.profile,
                settings: snapshot.settings,
                checkInDates: snapshot.checkInDates,
                lastTaskID: snapshot.lastTaskID,
                fileVersion: 0,
                isLegacy: true,
                isSignatureVerified: false,
                isSignatureMismatch: false
            )
        }
        return nil
    }
}

// MARK: - 导入签名与归一化

private extension PersistenceService {
    struct ExportSigningPayload: Codable {
        let formatVersion: Int
        let exportedAt: Date
        var tasks: [TaskItem]
        var sessions: [FocusSessionRecord]
        var countdownEvents: [CountdownEvent]
        var profile: ProfileInfo
        var settings: AppSettings
        var checkInDates: [Date]?
        var lastTaskID: UUID?
    }

    var exportSignatureKey: SymmetricKey {
        // 这是完整性签名，不是隐私加密；密钥只用于拦截普通手改和传输损坏。
        SymmetricKey(data: Data("Chrona.ExportSignature.v1.KaedeKR".utf8))
    }

    func signaturePayload(for export: ChronaExportFile) -> ExportSigningPayload {
        ExportSigningPayload(
            formatVersion: export.formatVersion,
            exportedAt: export.exportedAt,
            tasks: export.tasks,
            sessions: export.sessions,
            countdownEvents: export.countdownEvents,
            profile: export.profile,
            settings: export.settings,
            checkInDates: export.checkInDates,
            lastTaskID: export.lastTaskID
        )
    }

    func canonicalData(for payload: ExportSigningPayload) -> Data? {
        let signer = JSONEncoder()
        signer.dateEncodingStrategy = .iso8601
        signer.outputFormatting = [.sortedKeys]
        return try? signer.encode(payload)
    }

    func signature(for export: ChronaExportFile) -> String? {
        guard let data = canonicalData(for: signaturePayload(for: export)) else { return nil }
        let code = HMAC<SHA256>.authenticationCode(for: data, using: exportSignatureKey)
        return Data(code).map { String(format: "%02x", $0) }.joined()
    }

    func verifySignatureIfPresent(for export: ChronaExportFile) -> Bool {
        guard let existingSignature = export.signature else { return true }
        return signature(for: export) == existingSignature.lowercased()
    }

    func makeImportResult(
        tasks: [TaskItem],
        sessions: [FocusSessionRecord],
        countdownEvents: [CountdownEvent],
        profile: ProfileInfo,
        settings: AppSettings,
        checkInDates: [Date]?,
        lastTaskID: UUID?,
        fileVersion: Int,
        isLegacy: Bool,
        isSignatureVerified: Bool,
        isSignatureMismatch: Bool
    ) -> ImportResult {
        let normalizedTasks = normalizedTasks(tasks)
        let taskIDs = Set(normalizedTasks.map(\.id))

        return ImportResult(
            tasks: normalizedTasks,
            sessions: normalizedSessions(sessions, validTaskIDs: taskIDs),
            countdownEvents: normalizedCountdownEvents(countdownEvents),
            profile: normalizedProfile(profile),
            settings: normalizedSettings(settings),
            checkInDates: normalizedCheckInDates(checkInDates),
            lastTaskID: lastTaskID.flatMap { taskIDs.contains($0) ? $0 : nil },
            fileVersion: fileVersion,
            isLegacy: isLegacy,
            isSignatureVerified: isSignatureVerified,
            isSignatureMismatch: isSignatureMismatch
        )
    }

    func normalizedTasks(_ tasks: [TaskItem]) -> [TaskItem] {
        var seenIDs = Set<UUID>()
        return tasks
            .sorted(by: { $0.order < $1.order })
            .enumerated()
            .map { index, task in
                var copy = task
                if seenIDs.contains(copy.id) {
                    copy.id = UUID()
                }
                seenIDs.insert(copy.id)

                let title = copy.title.trimmingCharacters(in: .whitespacesAndNewlines)
                copy.title = title.isEmpty ? "Imported Task" : title
                copy.pomodoroPresetID = PomodoroPreset.all.contains(where: { $0.id == copy.pomodoroPresetID })
                    ? copy.pomodoroPresetID
                    : PomodoroPreset.default.id
                copy.countdownDuration = clampedDuration(copy.countdownDuration, min: 60, max: 300 * 60, fallback: 5 * 60)
                copy.backgroundName = allowedBackgroundNames.contains(copy.backgroundName) ? copy.backgroundName : "sunset"
                copy.order = index
                return copy
            }
    }

    func normalizedSessions(_ sessions: [FocusSessionRecord], validTaskIDs: Set<UUID>) -> [FocusSessionRecord] {
        var seenIDs = Set<UUID>()
        return sessions.compactMap { record in
            guard record.focusedDuration.isFinite, record.focusedDuration >= 0 else { return nil }

            var copy = record
            if seenIDs.contains(copy.id) {
                copy.id = UUID()
            }
            seenIDs.insert(copy.id)

            if let taskID = copy.taskID, !validTaskIDs.contains(taskID) {
                copy.taskID = nil
            }
            copy.taskTitle = copy.taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if copy.taskTitle.isEmpty {
                copy.taskTitle = "Imported Task"
            }
            if copy.endedAt < copy.startedAt {
                copy.endedAt = copy.startedAt.addingTimeInterval(copy.focusedDuration)
            }
            return copy
        }
        .sorted(by: { $0.startedAt > $1.startedAt })
    }

    func normalizedCountdownEvents(_ events: [CountdownEvent]) -> [CountdownEvent] {
        var seenIDs = Set<UUID>()
        return events.compactMap { event in
            let title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }

            var copy = event
            if seenIDs.contains(copy.id) {
                copy.id = UUID()
            }
            seenIDs.insert(copy.id)
            copy.title = title
            return copy
        }
        .sorted(by: { $0.date < $1.date })
    }

    func normalizedProfile(_ profile: ProfileInfo) -> ProfileInfo {
        var copy = profile
        let name = copy.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let signature = copy.signature.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.name = name.isEmpty ? ProfileInfo.default.name : name
        copy.signature = signature
        copy.avatarSymbol = copy.avatarSymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? ProfileInfo.default.avatarSymbol
            : copy.avatarSymbol
        return copy
    }

    func normalizedSettings(_ settings: AppSettings) -> AppSettings {
        var copy = settings
        copy.restDurationMinutes = clampedInt(copy.restDurationMinutes, min: 0, max: 30)
        copy.dailyReminderHour = clampedInt(copy.dailyReminderHour, min: 0, max: 23)
        copy.dailyReminderMinute = clampedInt(copy.dailyReminderMinute, min: 0, max: 59)
        copy.minimalModeActivationDelaySeconds = clampedInt(copy.minimalModeActivationDelaySeconds, min: 5, max: 60)
        if let pauseLimit = copy.stopwatchPauseLimitMinutes {
            copy.stopwatchPauseLimitMinutes = clampedInt(pauseLimit, min: 1, max: 30)
        }
        return copy
    }

    func normalizedCheckInDates(_ dates: [Date]?) -> [Date]? {
        guard let dates else { return nil }
        let calendar = Calendar.current
        let uniqueDays = Set(dates.map { calendar.startOfDay(for: $0) })
        return uniqueDays.sorted(by: >)
    }

    func clampedDuration(_ value: TimeInterval, min: TimeInterval, max: TimeInterval, fallback: TimeInterval) -> TimeInterval {
        guard value.isFinite else { return fallback }
        return Swift.min(Swift.max(value, min), max)
    }

    func clampedInt(_ value: Int, min: Int, max: Int) -> Int {
        Swift.min(Swift.max(value, min), max)
    }
}
