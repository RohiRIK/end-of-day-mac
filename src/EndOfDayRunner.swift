import AppKit
import UserNotifications

class EndOfDayRunner {

    // Called from --menubar mode (event loop is already running; no NSApp lifecycle)
    // onSnooze is called when the user picks "Snooze 30 min" so the tray can reschedule.
    static func trigger(onSnooze: (() -> Void)? = nil) {
        guard let config = try? Config.load(), !config.apps.isEmpty else { return }
        let running = NSWorkspace.shared.runningApplications.filter { app in
            guard let name = app.localizedName else { return false }
            return config.apps.contains(name)
        }
        guard !running.isEmpty else { return }
        requestNotificationPermission {
            DispatchQueue.main.async {
                EndOfDayRunner.showCountdownAlert(appsToClose: running, config: config, onSnooze: onSnooze)
            }
        }
    }

    // Called from --run mode: manages its own NSApp event loop
    static func run() {
        guard let config = try? Config.load(), !config.apps.isEmpty else {
            postNotification(title: "End of Day", body: "No apps configured. Run --setup first.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { NSApp.terminate(nil) }
            NSApp.run()
            return
        }

        let running = NSWorkspace.shared.runningApplications.filter { app in
            guard let name = app.localizedName else { return false }
            return config.apps.contains(name)
        }

        guard !running.isEmpty else {
            NSApp.terminate(nil)
            return
        }

        requestNotificationPermission {
            DispatchQueue.main.async {
                EndOfDayRunner.showCountdownAlert(appsToClose: running, config: config, onSnooze: nil)
            }
        }
        NSApp.run()
    }

    // MARK: – Countdown alert

    private static func showCountdownAlert(appsToClose: [NSRunningApplication],
                                           config: Config,
                                           onSnooze: (() -> Void)?) {
        postNotification(title: "End of Day 🌅", body: "Work apps closing in 30s. Tap to cancel.")

        let alert = NSAlert()
        alert.messageText     = "End of Day 🌅"
        alert.informativeText = "Closing in 30s…"
        alert.alertStyle      = .informational
        alert.addButton(withTitle: "Close Apps Now")   // .alertFirstButtonReturn
        alert.addButton(withTitle: "Not Now")          // .alertSecondButtonReturn
        alert.addButton(withTitle: "Snooze 30 min")    // .alertThirdButtonReturn

        var remaining = 30
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            remaining -= 1
            alert.informativeText = remaining > 0 ? "Closing in \(remaining)s…" : "Closing…"
            if remaining <= 0 { t.invalidate(); NSApp.abortModal() }
        }
        RunLoop.main.add(timer, forMode: .modalPanel)

        let response = alert.runModal()
        timer.invalidate()

        switch response {
        case .alertFirstButtonReturn, .stop:
            closeApps(appsToClose, config: config)
        case .alertThirdButtonReturn:
            let snoozeUntil = Date().addingTimeInterval(30 * 60)
            let cal = Calendar.current
            let h   = cal.component(.hour,   from: snoozeUntil)
            let m   = cal.component(.minute, from: snoozeUntil)
            postNotification(title: "End of Day — Snoozed",
                             body: "Will close apps at \(h):\(String(format: "%02d", m)).")
            onSnooze?()
        default:
            // "Not Now" — in --run mode terminate; in --menubar mode do nothing (tray stays alive)
            if onSnooze == nil { NSApp.terminate(nil) }
        }
    }

    // MARK: – Close apps

    private static func closeApps(_ apps: [NSRunningApplication], config: Config) {
        var names: [String] = []
        for (idx, app) in apps.enumerated() {
            let delay = Double(config.closeDelaySeconds) * Double(idx)
            let name  = app.localizedName ?? "Unknown"
            names.append(name)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { app.terminate() }
        }
        Analytics.record(appsClosed: apps.count)
        // Show result after the last app has had time to quit (+1s buffer)
        let totalDelay = Double(config.closeDelaySeconds) * Double(max(0, apps.count - 1)) + 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
            showResultAlert(closed: names)
        }
    }

    private static func showResultAlert(closed: [String]) {
        let count      = closed.count
        let bulletList = closed.map { "• \($0)" }.joined(separator: "\n")
        let commaList  = closed.joined(separator: ", ")
        postNotification(title: "End of Day — Done 🌙",
                         body: "Closed \(count) app(s): \(commaList)")

        let alert = NSAlert()
        alert.messageText     = "End of Day — Done 🌙"
        alert.informativeText = "Closed \(count) app(s):\n\(bulletList)"
        alert.alertStyle      = .informational
        alert.addButton(withTitle: "Great, thanks!")

        var remaining = 10
        let timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            remaining -= 1
            if remaining <= 0 { t.invalidate(); NSApp.abortModal() }
        }
        RunLoop.main.add(timer, forMode: .modalPanel)
        alert.runModal()
        timer.invalidate()

        // In --run mode the app terminates; in --menubar mode stay alive
        if NSApp.activationPolicy() != .accessory {
            NSApp.terminate(nil)
        }
    }

    // MARK: – Notifications

    private static func requestNotificationPermission(completion: @escaping () -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
            completion()
        }
    }

    private static func postNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
