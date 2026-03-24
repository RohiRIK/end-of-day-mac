import Cocoa

class StatsWindowController: NSWindowController {

    private static var key: UInt8 = 0

    static func show() {
        let wc = StatsWindowController()
        wc.buildWindow()
        wc.showWindow(nil)
        wc.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        objc_setAssociatedObject(NSApp as AnyObject, &StatsWindowController.key, wc, .OBJC_ASSOCIATION_RETAIN)
    }

    private func buildWindow() {
        let winW: CGFloat = 380
        let winH: CGFloat = 440

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: winW, height: winH),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "End of Day — Stats"
        win.isReleasedWhenClosed = false
        win.center()
        self.window = win

        let cv = win.contentView!
        let pad: CGFloat = 24
        var y = winH - pad

        // ── Title ──
        y -= 28
        let title = NSTextField(labelWithString: "📊  Your Stats")
        title.font      = NSFont.systemFont(ofSize: 18, weight: .semibold)
        title.alignment = .center
        title.frame     = NSRect(x: pad, y: y, width: winW - pad * 2, height: 28)
        cv.addSubview(title)

        y -= 32

        // ── Summary cards row ──
        let entries  = Analytics.load()
        let today    = Analytics.todayString()
        let streak   = Analytics.currentStreak(entries)
        let total    = entries.reduce(0) { $0 + $1.appsClosed }
        let runs     = entries.count
        let thisMonth = Analytics.monthString(from: Date())
        let monthClosed = entries.filter { $0.date.hasPrefix(thisMonth) }.reduce(0) { $0 + $1.appsClosed }
        let ranToday = entries.last?.date == today

        let cards: [(emoji: String, value: String, label: String)] = [
            ("🔥", "\(streak)", "day streak"),
            ("📦", "\(total)",  "apps closed"),
            ("🏃", "\(runs)",   "total runs"),
            ("📅", "\(monthClosed)", "this month"),
        ]

        let cardW: CGFloat  = (winW - pad * 2 - 12) / 4
        let cardH: CGFloat  = 72
        y -= cardH
        for (i, card) in cards.enumerated() {
            let x  = pad + CGFloat(i) * (cardW + 4)
            let box = NSView(frame: NSRect(x: x, y: y, width: cardW, height: cardH))
            box.wantsLayer  = true
            box.layer?.cornerRadius = 8
            box.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

            let emojiLbl = NSTextField(labelWithString: card.emoji)
            emojiLbl.font      = NSFont.systemFont(ofSize: 20)
            emojiLbl.alignment = .center
            emojiLbl.frame     = NSRect(x: 0, y: cardH - 30, width: cardW, height: 26)
            box.addSubview(emojiLbl)

            let valLbl = NSTextField(labelWithString: card.value)
            valLbl.font      = NSFont.systemFont(ofSize: 16, weight: .semibold)
            valLbl.alignment = .center
            valLbl.frame     = NSRect(x: 0, y: cardH - 54, width: cardW, height: 22)
            box.addSubview(valLbl)

            let lblLbl = NSTextField(labelWithString: card.label)
            lblLbl.font      = NSFont.systemFont(ofSize: 10)
            lblLbl.textColor = .secondaryLabelColor
            lblLbl.alignment = .center
            lblLbl.frame     = NSRect(x: 0, y: 4, width: cardW, height: 14)
            box.addSubview(lblLbl)

            cv.addSubview(box)
        }

        y -= 16

        // ── Today badge ──
        if ranToday {
            y -= 24
            let badge = NSTextField(labelWithString: "✅  You already ran End of Day today!")
            badge.font       = NSFont.systemFont(ofSize: 12)
            badge.textColor  = .systemGreen
            badge.alignment  = .center
            badge.frame      = NSRect(x: pad, y: y, width: winW - pad * 2, height: 20)
            cv.addSubview(badge)
            y -= 8
        }

        // ── Separator ──
        y -= 12
        let sep = NSBox(frame: NSRect(x: pad, y: y, width: winW - pad * 2, height: 1))
        sep.boxType = .separator
        cv.addSubview(sep)
        y -= 8

        // ── Section: Last 7 days bar chart ──
        y -= 20
        let chartTitle = NSTextField(labelWithString: "Last 7 days")
        chartTitle.font      = NSFont.systemFont(ofSize: 12, weight: .semibold)
        chartTitle.textColor = .secondaryLabelColor
        chartTitle.frame     = NSRect(x: pad, y: y, width: winW - pad * 2, height: 18)
        cv.addSubview(chartTitle)

        y -= 80
        buildBarChart(in: cv, x: pad, y: y, width: winW - pad * 2, height: 72, entries: entries)

        y -= 16

        // ── Separator ──
        let sep2 = NSBox(frame: NSRect(x: pad, y: y, width: winW - pad * 2, height: 1))
        sep2.boxType = .separator
        cv.addSubview(sep2)
        y -= 8

        // ── Section: Recent runs list ──
        y -= 20
        let recentTitle = NSTextField(labelWithString: "Recent runs")
        recentTitle.font      = NSFont.systemFont(ofSize: 12, weight: .semibold)
        recentTitle.textColor = .secondaryLabelColor
        recentTitle.frame     = NSRect(x: pad, y: y, width: winW - pad * 2, height: 18)
        cv.addSubview(recentTitle)

        let recent = Array(entries.sorted { $0.date > $1.date }.prefix(5))
        for entry in recent {
            y -= 22
            let row = NSTextField(labelWithString: "\(entry.date)    \(entry.appsClosed) app\(entry.appsClosed == 1 ? "" : "s") closed")
            row.font      = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            row.textColor = .labelColor
            row.frame     = NSRect(x: pad, y: y, width: winW - pad * 2, height: 18)
            cv.addSubview(row)
        }

        if recent.isEmpty {
            y -= 22
            let none = NSTextField(labelWithString: "No runs recorded yet.")
            none.font      = NSFont.systemFont(ofSize: 12)
            none.textColor = .tertiaryLabelColor
            none.frame     = NSRect(x: pad, y: y, width: winW - pad * 2, height: 18)
            cv.addSubview(none)
        }

        // ── Close button ──
        let closeBtn = NSButton(title: "Close", target: self, action: #selector(closeWindow))
        closeBtn.bezelStyle    = NSButton.BezelStyle.rounded
        closeBtn.keyEquivalent = "\r"
        closeBtn.frame         = NSRect(x: winW - pad - 80, y: 14, width: 80, height: 28)
        cv.addSubview(closeBtn)
    }

    private func buildBarChart(in cv: NSView, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat,
                                entries: [AnalyticsEntry]) {
        let cal     = Calendar.current
        let today   = Date()
        let fmt     = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let dayFmt  = DateFormatter()
        dayFmt.dateFormat = "EEE"

        // Build 7-day window
        var days: [(label: String, count: Int)] = []
        for offset in (0..<7).reversed() {
            let d     = cal.date(byAdding: .day, value: -offset, to: today)!
            let key   = fmt.string(from: d)
            let count = entries.first(where: { $0.date == key })?.appsClosed ?? 0
            days.append((dayFmt.string(from: d), count))
        }

        let maxVal  = max(days.map { $0.count }.max() ?? 1, 1)
        let barW    = (width - 6) / 7
        let barAreaH: CGFloat = height - 18

        for (i, day) in days.enumerated() {
            let bx     = x + CGFloat(i) * (barW + 1)
            let frac   = CGFloat(day.count) / CGFloat(maxVal)
            let bh     = max(frac * barAreaH, day.count > 0 ? 4 : 2)
            let by     = y + 18

            let bar = NSView(frame: NSRect(x: bx, y: by, width: barW, height: bh))
            bar.wantsLayer = true
            bar.layer?.cornerRadius = 3
            bar.layer?.backgroundColor = (day.count > 0 ? NSColor.systemOrange : NSColor.separatorColor).cgColor
            cv.addSubview(bar)

            // Day label
            let lbl = NSTextField(labelWithString: day.label)
            lbl.font      = NSFont.systemFont(ofSize: 9)
            lbl.textColor = .tertiaryLabelColor
            lbl.alignment = .center
            lbl.frame     = NSRect(x: bx, y: y, width: barW, height: 14)
            cv.addSubview(lbl)
        }
    }

    @objc private func closeWindow() { window?.close() }
}

