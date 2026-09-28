import Foundation

final class PersistenceService {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(filename: String = "chrona_state.json") {
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.fileURL = baseURL.appendingPathComponent(filename)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> AppSnapshot {
        guard
            let data = try? Data(contentsOf: fileURL),
            let snapshot = try? decoder.decode(AppSnapshot.self, from: data)
        else {
            return .default
        }
        return snapshot
    }

    func save(_ snapshot: AppSnapshot) {
        // Persist the whole app snapshot so tasks, records, and active timer can restore together.
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
