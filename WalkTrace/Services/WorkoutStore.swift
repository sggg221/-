import Foundation

@MainActor
final class WorkoutStore: ObservableObject {
    @Published private(set) var sessions: [WorkoutSession] = []
    @Published private(set) var recoverableDraft: WorkoutSession?
    @Published var storageError: String?

    private let archiveURL: URL
    private let draftURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WalkTrace", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        archiveURL = directory.appendingPathComponent("workouts.json")
        draftURL = directory.appendingPathComponent("active-workout.json")
        if let data = try? Data(contentsOf: archiveURL),
           let decoded = try? decoder.decode([WorkoutSession].self, from: data) {
            sessions = decoded.sorted { $0.startDate > $1.startDate }
        }
        if let data = try? Data(contentsOf: draftURL) {
            recoverableDraft = try? decoder.decode(WorkoutSession.self, from: data)
        }
    }

    func add(_ session: WorkoutSession) {
        sessions.removeAll { $0.id == session.id }
        sessions.insert(session, at: 0)
        sessions.sort { $0.startDate > $1.startDate }
        persist()
    }

    func updateSteps(id: UUID, steps: Int) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[index].stepCount = max(0, steps)
        persist()
    }

    func delete(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        persist()
    }

    func saveDraft(_ session: WorkoutSession) {
        do {
            try write(encoder.encode(session), to: draftURL)
            recoverableDraft = session
        } catch {
            storageError = "暂时无法保存运动中的数据：\(error.localizedDescription)"
        }
    }

    func restoreDraft() {
        guard let draft = recoverableDraft else { return }
        add(draft)
        discardDraft()
    }

    func discardDraft() {
        recoverableDraft = nil
        try? FileManager.default.removeItem(at: draftURL)
    }

    var todaySessions: [WorkoutSession] {
        sessions.filter { Calendar.current.isDateInToday($0.startDate) }
    }

    private func persist() {
        do {
            try write(encoder.encode(sessions), to: archiveURL)
        } catch {
            storageError = "历史记录保存失败：\(error.localizedDescription)"
        }
    }

    private func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        // Keep workout writes possible after the user locks the device.
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }
}
