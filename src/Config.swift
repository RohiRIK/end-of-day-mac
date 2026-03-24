import Foundation

struct Config: Codable {
    var apps: [String]
    var triggerHour: Int
    var triggerMinute: Int
    /// Calendar weekday numbers that should trigger: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
    /// Empty array means every day.
    var activeDays: [Int]
    var closeDelaySeconds: Int

    init(apps: [String], triggerHour: Int, triggerMinute: Int,
         activeDays: [Int] = [], closeDelaySeconds: Int = 0) {
        self.apps               = apps
        self.triggerHour        = triggerHour
        self.triggerMinute      = triggerMinute
        self.activeDays         = activeDays
        self.closeDelaySeconds  = closeDelaySeconds
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        apps              = try c.decode([String].self, forKey: .apps)
        triggerHour       = try c.decode(Int.self,      forKey: .triggerHour)
        triggerMinute     = try c.decode(Int.self,      forKey: .triggerMinute)
        activeDays        = (try? c.decode([Int].self,  forKey: .activeDays))         ?? []
        closeDelaySeconds = (try? c.decode(Int.self,    forKey: .closeDelaySeconds))  ?? 0
    }

    static let path: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/end_of_day")
        return dir.appendingPathComponent("config.json")
    }()

    static func exists() -> Bool {
        FileManager.default.fileExists(atPath: path.path)
    }

    static func load() throws -> Config {
        let data = try Data(contentsOf: path)
        return try JSONDecoder().decode(Config.self, from: data)
    }

    func save() throws {
        let dir = Config.path.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: Config.path, options: .atomic)
    }
}
