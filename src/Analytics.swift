import Foundation

struct AnalyticsEntry: Codable {
    var date: String        // "YYYY-MM-DD"
    var appsClosed: Int
}

struct Analytics {
    static let path: URL = Config.path.deletingLastPathComponent()
                                      .appendingPathComponent("analytics.json")

    // MARK: – Write

    static func record(appsClosed count: Int) {
        var entries = load()
        let today = todayString()
        if let idx = entries.firstIndex(where: { $0.date == today }) {
            entries[idx].appsClosed += count
        } else {
            entries.append(AnalyticsEntry(date: today, appsClosed: count))
        }
        if entries.count > 90 { entries = Array(entries.suffix(90)) }
        save(entries)
    }

    // MARK: – Read

    static func load() -> [AnalyticsEntry] {
        guard let data = try? Data(contentsOf: path) else { return [] }
        return (try? JSONDecoder().decode([AnalyticsEntry].self, from: data)) ?? []
    }

    /// Lines for the tray menu (3 disabled items)
    static func menuLines() -> [String] {
        let entries = load()
        guard !entries.isEmpty else { return ["No data yet"] }

        let streak      = currentStreak(entries)
        let total       = entries.reduce(0) { $0 + $1.appsClosed }
        let runs        = entries.count
        let monthClosed = entries.filter { $0.date.hasPrefix(monthString(from: Date())) }
                                  .reduce(0) { $0 + $1.appsClosed }
        return [
            "🔥 Streak: \(streak) day\(streak == 1 ? "" : "s")",
            "📦 This month: \(monthClosed) apps closed",
            "📊 All time: \(total) apps / \(runs) runs"
        ]
    }

    // MARK: – Helpers (internal so StatsWindow can use them)

    static func currentStreak(_ entries: [AnalyticsEntry]) -> Int {
        let cal    = Calendar.current
        var streak = 0
        var check  = Date()
        for entry in entries.sorted(by: { $0.date > $1.date }) {
            guard let d = parseDate(entry.date) else { break }
            if cal.isDate(d, inSameDayAs: check) {
                streak += 1
                check = cal.date(byAdding: .day, value: -1, to: check)!
            } else { break }
        }
        return streak
    }

    static func todayString() -> String {
        dateFmt.string(from: Date())
    }

    static func monthString(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        return fmt.string(from: date)
    }

    static func parseDate(_ s: String) -> Date? {
        dateFmt.date(from: s)
    }

    // MARK: – Private

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    private static func save(_ entries: [AnalyticsEntry]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: path, options: .atomic)
    }
}
