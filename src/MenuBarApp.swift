import Cocoa

class MenuBarApp: NSObject {

    private var statusItem: NSStatusItem!
    private var triggerTimer: Timer?
    private var pausedToday   = false
    private var snoozedUntil: Date? = nil
    private var nextFireDate:  Date? = nil

    private static var shared: MenuBarApp?

    static func start() {
        let app = MenuBarApp()
        shared = app
        app.setUp()
    }

    // MARK: – Setup

    private func setUp() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            let resDir = Bundle.main.resourcePath ?? ""
            let img = NSImage(contentsOfFile: "\(resDir)/MenuBarIcon.png")
            img?.size = NSSize(width: 18, height: 18)
            btn.image   = img
            btn.toolTip = "End of Day"
        }
        statusItem.menu = buildMenu()
        scheduleNextRun()
    }

    // MARK: – Scheduling

    private func scheduleNextRun() {
        triggerTimer?.invalidate()
        triggerTimer  = nil
        snoozedUntil  = nil

        guard let config = try? Config.load() else { return }

        let now = Date()
        let cal = Calendar.current

        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.hour   = config.triggerHour
        comps.minute = config.triggerMinute
        comps.second = 0

        var next = cal.date(from: comps)!
        if next <= now {
            next = cal.date(byAdding: .day, value: 1, to: next)!
        }

        // Advance to the next allowed weekday
        if !config.activeDays.isEmpty {
            next = nextAllowedDay(from: next, activeDays: config.activeDays, calendar: cal)
        }

        nextFireDate = next
        refreshMenu()

        let interval = next.timeIntervalSince(now)
        triggerTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.onTriggerFired()
        }
    }

    private func nextAllowedDay(from date: Date, activeDays: [Int], calendar cal: Calendar) -> Date {
        var d = date
        for _ in 0..<8 {    // at most 7 days forward
            let weekday = cal.component(.weekday, from: d)
            if activeDays.contains(weekday) { return d }
            d = cal.date(byAdding: .day, value: 1, to: d)!
        }
        return date     // fallback: shouldn't happen if activeDays non-empty
    }

    private func onTriggerFired() {
        guard let config = try? Config.load() else { scheduleNextRun(); return }

        if pausedToday {
            pausedToday = false
            refreshMenu()
            scheduleNextRun()
            return
        }

        if !config.activeDays.isEmpty {
            let weekday = Calendar.current.component(.weekday, from: Date())
            if !config.activeDays.contains(weekday) {
                scheduleNextRun()
                return
            }
        }

        EndOfDayRunner.trigger { [weak self] in
            self?.snooze(minutes: 30)
        }

        scheduleNextRun()
    }

    private func snooze(minutes: Int) {
        triggerTimer?.invalidate()
        let fireDate = Date().addingTimeInterval(Double(minutes) * 60)
        snoozedUntil = fireDate
        nextFireDate = fireDate
        refreshMenu()

        triggerTimer = Timer.scheduledTimer(withTimeInterval: Double(minutes) * 60,
                                            repeats: false) { [weak self] _ in
            self?.snoozedUntil = nil
            self?.onTriggerFired()
        }
    }

    // MARK: – Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Next run title
        let nextItem = NSMenuItem(title: nextRunTitle(), action: nil, keyEquivalent: "")
        nextItem.isEnabled = false
        nextItem.tag = 1
        menu.addItem(nextItem)

        menu.addItem(.separator())

        // Pause / Snooze
        let pauseItem = NSMenuItem(title: pauseTitle(), action: #selector(togglePause), keyEquivalent: "")
        pauseItem.target = self
        pauseItem.tag = 2
        menu.addItem(pauseItem)

        let snoozeItem = NSMenuItem(title: "Snooze 30 min", action: #selector(snoozeFromMenu), keyEquivalent: "")
        snoozeItem.target = self
        menu.addItem(snoozeItem)

        menu.addItem(.separator())

        // Analytics section
        for line in Analytics.menuLines() {
            let item = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            item.isEnabled = false
            item.tag = 10
            menu.addItem(item)
        }

        menu.addItem(.separator())

        // Config
        let changeAppsItem = NSMenuItem(title: "Change Apps…", action: #selector(changeApps), keyEquivalent: "")
        changeAppsItem.target = self
        menu.addItem(changeAppsItem)

        let changeTimeItem = NSMenuItem(title: "Change Time…", action: #selector(changeTime), keyEquivalent: "")
        changeTimeItem.target = self
        menu.addItem(changeTimeItem)

        let runNowItem = NSMenuItem(title: "Run Now", action: #selector(runNow), keyEquivalent: "")
        runNowItem.target = self
        menu.addItem(runNowItem)

        let statsItem = NSMenuItem(title: "View Stats…", action: #selector(viewStats), keyEquivalent: "")
        statsItem.target = self
        menu.addItem(statsItem)

        menu.addItem(.separator())

        let uninstallItem = NSMenuItem(title: "Uninstall…", action: #selector(uninstall), keyEquivalent: "")
        uninstallItem.target = self
        menu.addItem(uninstallItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }

    private func refreshMenu() {
        guard let menu = statusItem.menu else { return }
        if let item = menu.item(withTag: 1) { item.title = nextRunTitle() }
        if let item = menu.item(withTag: 2) { item.title = pauseTitle()   }
        // Refresh analytics items
        let analyticsLines = Analytics.menuLines()
        let analyticsItems = menu.items.filter { $0.tag == 10 }
        for (i, item) in analyticsItems.enumerated() {
            item.title = analyticsLines[safe: i] ?? item.title
        }
    }

    private func nextRunTitle() -> String {
        guard let d = nextFireDate else { return "🌅 Next run: —" }
        let cal = Calendar.current
        let h   = cal.component(.hour,   from: d)
        let m   = cal.component(.minute, from: d)
        let hms = "\(h):\(String(format: "%02d", m))"
        if pausedToday         { return "Paused today (next: \(hms))" }
        if snoozedUntil != nil { return "Snoozed until \(hms)" }
        if !Calendar.current.isDateInToday(d) {
            let dayFmt = DateFormatter()
            dayFmt.dateFormat = "EEE"
            return "Next run: \(dayFmt.string(from: d)) \(hms)"
        }
        return "Next run: \(hms)"
    }

    private func pauseTitle() -> String {
        pausedToday ? "Resume Today" : "Pause Today"
    }

    // MARK: – Menu Actions

    @objc private func togglePause() {
        pausedToday.toggle()
        refreshMenu()
    }

    @objc private func snoozeFromMenu() {
        snooze(minutes: 30)
    }

    @objc private func viewStats() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        StatsWindowController.show()
    }

    @objc private func runNow() {
        EndOfDayRunner.trigger { [weak self] in self?.snooze(minutes: 30) }
    }

    @objc private func changeApps() {
        openOnboarding()
    }

    @objc private func changeTime() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        guard let config = try? Config.load() else { return }
        TimePickerWindowController.show(defaultHour: config.triggerHour,
                                        defaultMinute: config.triggerMinute) { [weak self] h, m in
            OnboardingWindowController.show(triggerHour: h, triggerMinute: m) { apps, activeDays, closeDelay in
                var updated = config
                updated.apps              = apps
                updated.triggerHour       = h
                updated.triggerMinute     = m
                updated.activeDays        = activeDays
                updated.closeDelaySeconds = closeDelay
                try? updated.save()
                try? Installer.install(config: updated)
                self?.scheduleNextRun()
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    @objc private func uninstall() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let confirm = NSAlert()
        confirm.messageText     = "Uninstall End of Day?"
        confirm.informativeText = "Removes the launchd agent and all config files."
        confirm.alertStyle      = .warning
        confirm.addButton(withTitle: "Uninstall")
        confirm.addButton(withTitle: "Cancel")
        guard confirm.runModal() == .alertFirstButtonReturn else {
            NSApp.setActivationPolicy(.accessory)
            return
        }

        Installer.run("/bin/launchctl", ["bootout", "gui/\(getuid())/\(Installer.label)"])
        var removed: [String] = []
        var errors:  [String] = []
        for (url, label) in [
            (Installer.plistURL,                       "LaunchAgents plist"),
            (Config.path.deletingLastPathComponent(),  "~/.config/end_of_day/"),
            (Installer.logDirURL,                      "Logs/end_of_day/")
        ] {
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            do    { try FileManager.default.removeItem(at: url); removed.append(label) }
            catch { errors.append(error.localizedDescription) }
        }

        let done = NSAlert()
        done.messageText     = errors.isEmpty ? "Uninstalled" : "Uninstall completed with errors"
        done.informativeText = (removed.map { "✓ \($0)" } + errors.map { "✗ \($0)" }).joined(separator: "\n")
        done.alertStyle      = errors.isEmpty ? .informational : .warning
        done.addButton(withTitle: "Done")
        done.runModal()
        NSApp.terminate(nil)
    }

    // MARK: – Helpers

    private func openOnboarding() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        guard let config = try? Config.load() else { return }
        OnboardingWindowController.show(triggerHour: config.triggerHour,
                                        triggerMinute: config.triggerMinute) { [weak self] apps, activeDays, closeDelay in
            var updated = config
            updated.apps              = apps
            updated.activeDays        = activeDays
            updated.closeDelaySeconds = closeDelay
            try? updated.save()
            try? Installer.install(config: updated)
            self?.scheduleNextRun()
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

// MARK: – Safe subscript
private extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
