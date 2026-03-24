import Cocoa

class TimePickerWindowController: NSWindowController {
    var onConfirm: ((Int, Int) -> Void)?

    private var hourField:   NSTextField!
    private var minuteField: NSTextField!

    static func show(defaultHour: Int = 18, defaultMinute: Int = 30,
                     onConfirm: @escaping (Int, Int) -> Void) {
        let wc = TimePickerWindowController()
        wc.onConfirm = onConfirm
        wc.buildWindow(defaultHour: defaultHour, defaultMinute: defaultMinute)
        wc.showWindow(nil)
        wc.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Retain controller for window lifetime
        objc_setAssociatedObject(NSApp as AnyObject, &TimePickerWindowController.key, wc, .OBJC_ASSOCIATION_RETAIN)
    }

    private static var key: UInt8 = 0

    private func buildWindow(defaultHour: Int, defaultMinute: Int) {
        let w: CGFloat = 320
        let h: CGFloat = 220

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "End-of-Day Setup"
        win.isReleasedWhenClosed = false
        win.center()
        self.window = win

        let cv = win.contentView!

        // Title label
        let title = NSTextField(labelWithString: "When should apps close?")
        title.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        title.alignment = .center
        title.frame = NSRect(x: 20, y: h - 50, width: w - 40, height: 22)
        cv.addSubview(title)

        let sub = NSTextField(labelWithString: "Set your daily end-of-day trigger time.")
        sub.font = NSFont.systemFont(ofSize: 12)
        sub.textColor = .secondaryLabelColor
        sub.alignment = .center
        sub.frame = NSRect(x: 20, y: h - 74, width: w - 40, height: 18)
        cv.addSubview(sub)

        // Hour field
        let hourLabel = NSTextField(labelWithString: "Hour (0–23)")
        hourLabel.font = NSFont.systemFont(ofSize: 11)
        hourLabel.textColor = .secondaryLabelColor
        hourLabel.frame = NSRect(x: 40, y: 120, width: 100, height: 16)
        cv.addSubview(hourLabel)

        hourField = makeIntField(value: defaultHour, min: 0, max: 23)
        hourField.frame = NSRect(x: 40, y: 92, width: 80, height: 26)
        cv.addSubview(hourField)

        // Minute field
        let minLabel = NSTextField(labelWithString: "Minute (0–59)")
        minLabel.font = NSFont.systemFont(ofSize: 11)
        minLabel.textColor = .secondaryLabelColor
        minLabel.frame = NSRect(x: 180, y: 120, width: 100, height: 16)
        cv.addSubview(minLabel)

        minuteField = makeIntField(value: defaultMinute, min: 0, max: 59)
        minuteField.frame = NSRect(x: 180, y: 92, width: 80, height: 26)
        cv.addSubview(minuteField)

        // Colon separator
        let colon = NSTextField(labelWithString: ":")
        colon.font = NSFont.systemFont(ofSize: 22, weight: .light)
        colon.frame = NSRect(x: 126, y: 88, width: 20, height: 32)
        cv.addSubview(colon)

        // Next button
        let nextBtn = NSButton(title: "Next →", target: self, action: #selector(confirm))
        nextBtn.bezelStyle = NSButton.BezelStyle.rounded
        nextBtn.keyEquivalent = "\r"
        nextBtn.frame = NSRect(x: w - 110, y: 16, width: 90, height: 28)
        cv.addSubview(nextBtn)

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.bezelStyle = NSButton.BezelStyle.rounded
        cancelBtn.keyEquivalent = "\u{1b}"
        cancelBtn.frame = NSRect(x: w - 210, y: 16, width: 90, height: 28)
        cv.addSubview(cancelBtn)
    }

    private func makeIntField(value: Int, min: Int, max: Int) -> NSTextField {
        let field = NSTextField()
        field.stringValue = String(value)
        field.alignment = .center
        field.font = NSFont.monospacedDigitSystemFont(ofSize: 18, weight: .regular)
        let fmt = NumberFormatter()
        fmt.numberStyle = .none
        fmt.minimum = NSNumber(value: min)
        fmt.maximum = NSNumber(value: max)
        fmt.allowsFloats = false
        field.formatter = fmt
        return field
    }

    @objc private func confirm() {
        let h = Int(hourField.stringValue) ?? 18
        let m = Int(minuteField.stringValue) ?? 30
        guard (0...23).contains(h) else { shake(hourField); return }
        guard (0...59).contains(m) else { shake(minuteField); return }
        window?.orderOut(nil)
        onConfirm?(h, m)
    }

    @objc private func cancel() {
        NSApp.terminate(nil)
    }

    private func shake(_ view: NSView) {
        let anim = CABasicAnimation(keyPath: "position.x")
        anim.duration = 0.05
        anim.repeatCount = 4
        anim.autoreverses = true
        anim.byValue = 6
        view.layer?.add(anim, forKey: "shake")
        view.wantsLayer = true
    }
}
