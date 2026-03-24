import Cocoa

class OnboardingWindowController: NSWindowController, NSSearchFieldDelegate {

    var triggerHour:   Int = 18
    var triggerMinute: Int = 30
    // apps, activeDays ([Int], empty = every day), closeDelaySeconds
    var onSave: (([String], [Int], Int) -> Void)?

    private var checkedSet: Set<String> = []
    private var runningSet: Set<String> = []

    private var checkboxes:     [NSButton]    = []
    private var runningDots:    [NSTextField] = []
    private var sectionHeaders: [(view: NSTextField, category: String)] = []
    private var countLabel:     NSTextField!
    private var dayButtons:     [NSButton]    = []   // Mon–Sun toggles
    private var delayStepper:   NSStepper!
    private var delayLabel:     NSTextField!

    // Calendar weekday order: Sun=1 … Sat=7
    private static let dayLabels: [(label: String, weekday: Int)] = [
        ("Sun", 1), ("Mon", 2), ("Tue", 3), ("Wed", 4),
        ("Thu", 5), ("Fri", 6), ("Sat", 7)
    ]

    // MARK: – Factory

    static func show(triggerHour: Int, triggerMinute: Int,
                     onSave: @escaping ([String], [Int], Int) -> Void) {
        let wc       = OnboardingWindowController()
        wc.triggerHour   = triggerHour
        wc.triggerMinute = triggerMinute
        wc.onSave        = onSave
        wc.runningSet    = AppCatalog.runningApps()
        let config        = try? Config.load()
        wc.checkedSet    = config.map { Set($0.apps) } ?? wc.runningSet

        wc.buildWindow(apps: AppCatalog.installedApps(), config: config)
        wc.showWindow(nil)
        wc.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        objc_setAssociatedObject(NSApp as AnyObject, &OnboardingWindowController.key, wc, .OBJC_ASSOCIATION_RETAIN)
    }

    private static var key: UInt8 = 0

    // MARK: – Window construction

    private func buildWindow(apps: [String], config: Config?) {
        let padH:   CGFloat = 20
        let listW:  CGFloat = 380
        let winW:   CGFloat = listW + padH * 2
        let winH:   CGFloat = 660

        // Layout bottom-up
        let btnY:      CGFloat = 14
        let delayY:    CGFloat = btnY  + 28 + 12
        let daysY:     CGFloat = delayY + 28 + 8
        let scrollY:   CGFloat = daysY + 36 + 12
        let scrollH:   CGFloat = winH - scrollY - 28 - 8 - 28 - 8 - 20 - 16
        let searchY:   CGFloat = scrollY + scrollH + 8
        let toolY:     CGFloat = searchY + 28 + 8
        let headerY:   CGFloat = toolY   + 28 + 8

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: winW, height: winH),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        let h = triggerHour; let m = triggerMinute
        win.title = "End-of-Day Setup — \(h):\(String(format: "%02d", m)) daily"
        win.isReleasedWhenClosed = false
        win.center()
        self.window = win
        let cv = win.contentView!

        // ── Header ──
        let header = NSTextField(labelWithString: "Select apps to close at end of day:")
        header.font  = NSFont.systemFont(ofSize: 13, weight: .medium)
        header.frame = NSRect(x: padH, y: headerY, width: listW, height: 20)
        cv.addSubview(header)

        // ── Select all/none + count ──
        let selAll = NSButton(title: "Select All", target: self, action: #selector(selectAllApps))
        selAll.bezelStyle = NSButton.BezelStyle.rounded
        selAll.frame = NSRect(x: padH, y: toolY, width: 90, height: 28)
        cv.addSubview(selAll)

        let selNone = NSButton(title: "Select None", target: self, action: #selector(selectNoneApps))
        selNone.bezelStyle = NSButton.BezelStyle.rounded
        selNone.frame = NSRect(x: padH + 98, y: toolY, width: 95, height: 28)
        cv.addSubview(selNone)

        countLabel = NSTextField(labelWithString: "")
        countLabel.alignment  = .right
        countLabel.textColor  = .secondaryLabelColor
        countLabel.font       = NSFont.systemFont(ofSize: 12)
        countLabel.frame      = NSRect(x: padH + 200, y: toolY + 5, width: listW - 200, height: 18)
        cv.addSubview(countLabel)

        // ── Search ──
        let searchField = NSSearchField(frame: NSRect(x: padH, y: searchY, width: listW, height: 28))
        searchField.placeholderString = "Filter apps…"
        searchField.delegate = self
        cv.addSubview(searchField)

        // ── App list ──
        let scrollView = NSScrollView(frame: NSRect(x: padH, y: scrollY, width: listW, height: scrollH))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers  = true
        scrollView.borderType          = .bezelBorder
        buildDocView(apps: apps, in: scrollView, innerWidth: listW - 4)
        cv.addSubview(scrollView)

        // ── Day picker ──
        let daysLabel = NSTextField(labelWithString: "Run on:")
        daysLabel.font      = NSFont.systemFont(ofSize: 12)
        daysLabel.textColor = .secondaryLabelColor
        daysLabel.frame     = NSRect(x: padH, y: daysY + 8, width: 52, height: 18)
        cv.addSubview(daysLabel)

        let activeDays = Set(config?.activeDays ?? [])
        let btnW: CGFloat   = 44
        let btnGap: CGFloat = 4
        var bx: CGFloat     = padH + 56
        for (lbl, weekday) in OnboardingWindowController.dayLabels {
            let btn = NSButton(checkboxWithTitle: lbl, target: self, action: nil)
            // Pre-check: if activeDays is empty → all days active; otherwise check membership
            btn.state = (activeDays.isEmpty || activeDays.contains(weekday)) ? .on : .off
            btn.frame = NSRect(x: bx, y: daysY + 5, width: btnW, height: 22)
            cv.addSubview(btn)
            dayButtons.append(btn)
            bx += btnW + btnGap
        }

        // ── Close delay stepper ──
        let delayVal = config?.closeDelaySeconds ?? 0
        let delayRowLabel = NSTextField(labelWithString: "Delay between apps:")
        delayRowLabel.font      = NSFont.systemFont(ofSize: 12)
        delayRowLabel.textColor = .secondaryLabelColor
        delayRowLabel.frame     = NSRect(x: padH, y: delayY + 6, width: 145, height: 18)
        cv.addSubview(delayRowLabel)

        delayStepper = NSStepper()
        delayStepper.minValue   = 0
        delayStepper.maxValue   = 10
        delayStepper.increment  = 1
        delayStepper.intValue   = Int32(delayVal)
        delayStepper.frame      = NSRect(x: padH + 148, y: delayY + 2, width: 22, height: 26)
        delayStepper.target     = self
        delayStepper.action     = #selector(delayStepperChanged)
        cv.addSubview(delayStepper)

        delayLabel = NSTextField(labelWithString: delayLabelText(delayVal))
        delayLabel.font      = NSFont.systemFont(ofSize: 12)
        delayLabel.textColor = .labelColor
        delayLabel.frame     = NSRect(x: padH + 174, y: delayY + 6, width: 150, height: 18)
        cv.addSubview(delayLabel)

        // ── Buttons ──
        let uninstallBtn = NSButton(title: "Uninstall…", target: self, action: #selector(uninstall))
        uninstallBtn.frame      = NSRect(x: padH, y: btnY, width: 90, height: 28)
        uninstallBtn.bezelColor = .systemRed
        cv.addSubview(uninstallBtn)

        let statsBtn = NSButton(title: "📊 Stats", target: self, action: #selector(openStats))
        statsBtn.frame = NSRect(x: winW - 275, y: btnY, width: 80, height: 28)
        cv.addSubview(statsBtn)

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.frame         = NSRect(x: winW - 185, y: btnY, width: 80, height: 28)
        cancelBtn.keyEquivalent = "\u{1b}"
        cv.addSubview(cancelBtn)

        let saveBtn = NSButton(title: "Save", target: self, action: #selector(save))
        saveBtn.bezelStyle    = NSButton.BezelStyle.rounded
        saveBtn.frame         = NSRect(x: winW - 90, y: btnY, width: 70, height: 28)
        saveBtn.keyEquivalent = "\r"
        cv.addSubview(saveBtn)

        updateCountLabel()
    }

    private func delayLabelText(_ val: Int) -> String {
        val == 0 ? "No delay" : "\(val)s between each app"
    }

    private func buildDocView(apps: [String], in scrollView: NSScrollView, innerWidth w: CGFloat) {
        var grouped: [String: [String]] = [:]
        for app in apps {
            let cat = AppCatalog.categoryMap[app] ?? "Other"
            grouped[cat, default: []].append(app)
        }

        let rowH:   CGFloat = 26
        let hdrH:   CGFloat = 22
        let hdrGap: CGFloat = 10

        var totalH: CGFloat = 4
        for cat in AppCatalog.categoryOrder {
            guard let catApps = grouped[cat], !catApps.isEmpty else { continue }
            totalH += hdrGap + hdrH + CGFloat(catApps.count) * rowH
        }
        totalH += 4

        let docH    = max(totalH, scrollView.frame.height - 2)
        let docView = NSView(frame: NSRect(x: 0, y: 0, width: w, height: docH))
        scrollView.documentView = docView

        var y = docH - 4

        for cat in AppCatalog.categoryOrder {
            guard let catApps = grouped[cat], !catApps.isEmpty else { continue }

            y -= hdrGap + hdrH
            let hdr = NSTextField(labelWithString: cat.uppercased())
            hdr.font      = NSFont.systemFont(ofSize: 10, weight: .semibold)
            hdr.textColor = .tertiaryLabelColor
            hdr.frame     = NSRect(x: 10, y: y, width: w - 20, height: hdrH)
            docView.addSubview(hdr)
            sectionHeaders.append((view: hdr, category: cat))

            for app in catApps {
                y -= rowH
                let cb = NSButton(checkboxWithTitle: app, target: self, action: #selector(checkboxChanged))
                cb.frame = NSRect(x: 12, y: y, width: w - 34, height: rowH)
                cb.state = checkedSet.contains(app) ? .on : .off
                docView.addSubview(cb)
                checkboxes.append(cb)

                let dot = NSTextField(labelWithString: "●")
                dot.textColor = .systemGreen
                dot.font      = NSFont.systemFont(ofSize: 9)
                dot.frame     = NSRect(x: w - 20, y: y + 6, width: 14, height: 14)
                dot.toolTip   = "Currently running"
                dot.isHidden  = !runningSet.contains(app)
                docView.addSubview(dot)
                runningDots.append(dot)
            }
        }
    }

    // MARK: – Actions

    @objc private func checkboxChanged() { updateCountLabel() }

    @objc private func selectAllApps() {
        checkboxes.forEach { $0.state = .on }
        updateCountLabel()
    }

    @objc private func selectNoneApps() {
        checkboxes.forEach { $0.state = .off }
        updateCountLabel()
    }

    @objc private func delayStepperChanged() {
        delayLabel.stringValue = delayLabelText(Int(delayStepper.intValue))
    }

    @objc private func save() {
        let selected = checkboxes.filter { $0.state == .on }.map { $0.title }
        guard !selected.isEmpty else {
            let alert = NSAlert()
            alert.messageText     = "No apps selected"
            alert.informativeText = "Please select at least one app to close at end of day."
            alert.alertStyle      = .warning
            alert.runModal()
            return
        }

        // Collect active days; empty = all days
        var activeDays: [Int] = []
        for (idx, btn) in dayButtons.enumerated() where btn.state == .on {
            activeDays.append(OnboardingWindowController.dayLabels[idx].weekday)
        }
        // If all 7 are checked, normalise to empty (= every day)
        if activeDays.count == 7 { activeDays = [] }

        window?.orderOut(nil)
        onSave?(selected, activeDays, Int(delayStepper.intValue))
    }

    @objc private func cancel() { NSApp.terminate(nil) }

    @objc private func openStats() { StatsWindowController.show() }

    @objc private func uninstall() {
        let confirm = NSAlert()
        confirm.messageText     = "Uninstall End of Day?"
        confirm.informativeText = "This will remove the launchd agent and all config files."
        confirm.alertStyle      = .warning
        confirm.addButton(withTitle: "Uninstall")
        confirm.addButton(withTitle: "Cancel")
        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        window?.orderOut(nil)
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
        done.messageText     = errors.isEmpty ? "Uninstalled" : "Completed with errors"
        done.informativeText = (removed.map { "✓ \($0)" } + errors.map { "✗ \($0)" }).joined(separator: "\n")
        done.alertStyle      = errors.isEmpty ? .informational : .warning
        done.addButton(withTitle: "Done")
        done.runModal()
        NSApp.terminate(nil)
    }

    // MARK: – Search

    func controlTextDidChange(_ obj: Notification) {
        guard let sf = obj.object as? NSSearchField else { return }
        applyFilter(sf.stringValue.lowercased())
    }

    private func applyFilter(_ query: String) {
        var visibleCats: Set<String> = []
        for (idx, cb) in checkboxes.enumerated() {
            let visible = query.isEmpty || cb.title.lowercased().contains(query)
            cb.isHidden              = !visible
            runningDots[idx].isHidden = !visible || !runningSet.contains(cb.title)
            if visible { visibleCats.insert(AppCatalog.categoryMap[cb.title] ?? "Other") }
        }
        for row in sectionHeaders { row.view.isHidden = !visibleCats.contains(row.category) }
    }

    // MARK: – Helpers

    private func updateCountLabel() {
        let on    = checkboxes.filter { $0.state == .on }.count
        let total = checkboxes.count
        countLabel.stringValue = "\(on) of \(total) selected"
    }
}
