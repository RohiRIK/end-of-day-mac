import Foundation

struct Installer {
    static let label    = "com.endofday.closeapps"
    private static let home = FileManager.default.homeDirectoryForCurrentUser
    static let plistURL: URL = home.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    static let logDirURL: URL = home.appendingPathComponent("Library/Logs/end_of_day")
    private static var launchdTarget: String { "gui/\(getuid())/\(label)" }

    static func install(config: Config) throws {
        let binaryPath = Bundle.main.executablePath ?? CommandLine.arguments[0]
        try FileManager.default.createDirectory(at: logDirURL, withIntermediateDirectories: true)
        let logPath = logDirURL.appendingPathComponent("end_of_day.log").path

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [binaryPath, "--menubar"],
            "RunAtLoad": true,
            "KeepAlive": true,
            "StandardOutPath": logPath,
            "StandardErrorPath": logPath,
            "EnvironmentVariables": [
                "HOME": home.path,
                "PATH": "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
            ]
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: plistURL, options: .atomic)

        run("/bin/launchctl", ["bootout", launchdTarget])
        let (exitCode, errOut) = run("/bin/launchctl", ["bootstrap", "gui/\(getuid())", plistURL.path])
        if exitCode != 0 { throw InstallerError.launchctlFailed(errOut) }
    }

    static func isInstalled() -> Bool {
        run("/bin/launchctl", ["list", label]).0 == 0
    }

    @discardableResult
    static func run(_ executable: String, _ args: [String]) -> (Int32, String) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardError  = pipe
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (proc.terminationStatus, output)
    }
}

enum InstallerError: Error, LocalizedError {
    case launchctlFailed(String)
    var errorDescription: String? {
        if case .launchctlFailed(let msg) = self { return "launchctl failed: \(msg)" }
        return nil
    }
}
