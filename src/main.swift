import Cocoa

let app = NSApplication.shared

let mode = CommandLine.arguments.dropFirst().first ?? (Config.exists() ? "--onboard" : "--setup")

switch mode {

case "--setup":
    app.setActivationPolicy(.regular)
    let delegate = SetupDelegate()
    app.delegate = delegate
    app.run()

case "--onboard":
    app.setActivationPolicy(.regular)
    let delegate = OnboardDelegate()
    app.delegate = delegate
    app.run()

case "--menubar":
    app.setActivationPolicy(.accessory)
    let delegate = MenuBarDelegate()
    app.delegate = delegate
    app.run()

case "--run":
    app.setActivationPolicy(.accessory)
    let delegate = RunDelegate()
    app.delegate = delegate
    app.run()

case "--uninstall":
    app.setActivationPolicy(.regular)
    let delegate = UninstallDelegate()
    app.delegate = delegate
    app.run()

default:
    fputs("Usage: EndOfDay --setup | --onboard | --menubar | --run | --uninstall\n", stderr)
    exit(1)
}

// MARK: – Delegates

class SetupDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        TimePickerWindowController.show(defaultHour: 18, defaultMinute: 30) { hour, minute in
            OnboardingWindowController.show(triggerHour: hour, triggerMinute: minute) { apps, activeDays, closeDelay in
                saveAndInstall(Config(apps: apps, triggerHour: hour, triggerMinute: minute,
                                      activeDays: activeDays, closeDelaySeconds: closeDelay))
            }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { false }
}

class OnboardDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        var config = (try? Config.load()) ?? Config(apps: [], triggerHour: 18, triggerMinute: 30)
        OnboardingWindowController.show(triggerHour: config.triggerHour,
                                        triggerMinute: config.triggerMinute) { apps, activeDays, closeDelay in
            config.apps              = apps
            config.activeDays        = activeDays
            config.closeDelaySeconds = closeDelay
            saveAndInstall(config)
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { false }
}

class MenuBarDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ note: Notification) {
        MenuBarApp.start()
    }
}

class RunDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ note: Notification) {
        EndOfDayRunner.run()
    }
}

class UninstallDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText     = "Uninstall End of Day?"
        alert.informativeText = "This will remove the launchd agent and all config files.\n\nThe app itself will not be deleted."
        alert.alertStyle      = .warning
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            NSApp.terminate(nil)
            return
        }

        var removed: [String] = []
        var errors:  [String] = []

        Installer.run("/bin/launchctl", ["bootout", "gui/\(getuid())/\(Installer.label)"])
        if FileManager.default.fileExists(atPath: Installer.plistURL.path) {
            do {
                try FileManager.default.removeItem(at: Installer.plistURL)
                removed.append("~/Library/LaunchAgents/\(Installer.label).plist")
            } catch { errors.append(error.localizedDescription) }
        }

        let configDir = Config.path.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: configDir.path) {
            do {
                try FileManager.default.removeItem(at: configDir)
                removed.append("~/.config/end_of_day/")
            } catch { errors.append(error.localizedDescription) }
        }

        if FileManager.default.fileExists(atPath: Installer.logDirURL.path) {
            do {
                try FileManager.default.removeItem(at: Installer.logDirURL)
                removed.append("~/Library/Logs/end_of_day/")
            } catch { errors.append(error.localizedDescription) }
        }

        let done = NSAlert()
        if errors.isEmpty {
            done.messageText     = "Uninstalled"
            done.informativeText = "Removed:\n" + removed.map { "• \($0)" }.joined(separator: "\n")
            done.alertStyle      = .informational
        } else {
            done.messageText     = "Uninstall completed with errors"
            done.informativeText = (removed.map { "✓ \($0)" } + errors.map { "✗ \($0)" }).joined(separator: "\n")
            done.alertStyle      = .warning
        }
        done.addButton(withTitle: "Done")
        done.runModal()
        NSApp.terminate(nil)
    }
}

// MARK: – Shared helpers

private func saveAndInstall(_ config: Config) {
    do {
        try config.save()
        try Installer.install(config: config)
        let script = "display notification \"\(config.apps.count) apps will close at \(config.triggerHour):\(String(format: "%02d", config.triggerMinute)) daily.\" with title \"End-of-Day Setup Complete\""
        Installer.run("/usr/bin/osascript", ["-e", script])
    } catch {
        showError(error.localizedDescription)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
}

private func showError(_ msg: String) {
    let alert = NSAlert()
    alert.messageText     = "Setup Error"
    alert.informativeText = msg
    alert.alertStyle      = .critical
    alert.runModal()
    NSApp.terminate(nil)
}
