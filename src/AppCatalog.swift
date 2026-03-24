import AppKit

struct AppCatalog {
    struct Entry {
        let bundleName: String
        let canonicalName: String
        let category: String
    }

    static let categoryOrder = [
        "Office", "Communication", "Productivity", "Browsers", "Dev", "Design", "Remote/IT", "Other"
    ]

    static let entries: [Entry] = [
        // Office
        Entry(bundleName: "Microsoft Outlook",     canonicalName: "Microsoft Outlook",     category: "Office"),
        Entry(bundleName: "Microsoft Teams",        canonicalName: "Microsoft Teams",        category: "Office"),
        Entry(bundleName: "Microsoft Teams (work or school)", canonicalName: "Microsoft Teams (work or school)", category: "Office"),
        Entry(bundleName: "Microsoft Edge",         canonicalName: "Microsoft Edge",         category: "Office"),
        Entry(bundleName: "Microsoft Excel",        canonicalName: "Microsoft Excel",        category: "Office"),
        Entry(bundleName: "Microsoft Word",         canonicalName: "Microsoft Word",         category: "Office"),
        Entry(bundleName: "Microsoft PowerPoint",   canonicalName: "Microsoft PowerPoint",   category: "Office"),
        Entry(bundleName: "Microsoft OneNote",      canonicalName: "Microsoft OneNote",      category: "Office"),
        // Communication
        Entry(bundleName: "Slack",      canonicalName: "Slack",      category: "Communication"),
        Entry(bundleName: "zoom.us",    canonicalName: "zoom.us",    category: "Communication"),
        Entry(bundleName: "WhatsApp",   canonicalName: "WhatsApp",   category: "Communication"),
        Entry(bundleName: "Discord",    canonicalName: "Discord",    category: "Communication"),
        Entry(bundleName: "Telegram",   canonicalName: "Telegram",   category: "Communication"),
        Entry(bundleName: "Signal",     canonicalName: "Signal",     category: "Communication"),
        Entry(bundleName: "Loom",       canonicalName: "Loom",       category: "Communication"),
        Entry(bundleName: "Webex",      canonicalName: "Webex",      category: "Communication"),
        // Productivity
        Entry(bundleName: "Notion",    canonicalName: "Notion",    category: "Productivity"),
        Entry(bundleName: "Obsidian",  canonicalName: "Obsidian",  category: "Productivity"),
        Entry(bundleName: "Todoist",   canonicalName: "Todoist",   category: "Productivity"),
        Entry(bundleName: "Things3",   canonicalName: "Things 3",  category: "Productivity"),
        // Browsers
        Entry(bundleName: "Google Chrome", canonicalName: "Google Chrome", category: "Browsers"),
        Entry(bundleName: "Firefox",       canonicalName: "Firefox",       category: "Browsers"),
        Entry(bundleName: "Arc",           canonicalName: "Arc",           category: "Browsers"),
        // Dev
        Entry(bundleName: "Visual Studio Code", canonicalName: "Visual Studio Code", category: "Dev"),
        Entry(bundleName: "Cursor",             canonicalName: "Cursor",             category: "Dev"),
        Entry(bundleName: "iTerm2",             canonicalName: "iTerm2",             category: "Dev"),
        Entry(bundleName: "Warp",               canonicalName: "Warp",               category: "Dev"),
        Entry(bundleName: "GitHub Desktop",     canonicalName: "GitHub Desktop",     category: "Dev"),
        Entry(bundleName: "TablePlus",          canonicalName: "TablePlus",          category: "Dev"),
        // Design
        Entry(bundleName: "Figma",  canonicalName: "Figma",  category: "Design"),
        Entry(bundleName: "Sketch", canonicalName: "Sketch", category: "Design"),
        // Remote / IT
        Entry(bundleName: "AnyDesk",                              canonicalName: "AnyDesk",                              category: "Remote/IT"),
        Entry(bundleName: "Microsoft Remote Desktop",             canonicalName: "Microsoft Remote Desktop",             category: "Remote/IT"),
        Entry(bundleName: "Cisco AnyConnect Secure Mobility Client", canonicalName: "Cisco AnyConnect Secure Mobility Client", category: "Remote/IT"),
        Entry(bundleName: "GlobalProtect",                        canonicalName: "GlobalProtect",                        category: "Remote/IT"),
        // Other
        Entry(bundleName: "Spotify", canonicalName: "Spotify", category: "Other"),
    ]

    static let categoryMap: [String: String] = Dictionary(
        uniqueKeysWithValues: entries.map { ($0.canonicalName, $0.category) }
    )
    // O(1) lookup by bundle name
    static let bundleNameIndex: [String: Entry] = Dictionary(
        uniqueKeysWithValues: entries.map { ($0.bundleName, $0) }
    )
    // Pre-built set — avoids rebuilding on every runningApps() call
    static let canonicalNameSet: Set<String> = Set(entries.map { $0.canonicalName })

    static func installedApps() -> [String] {
        var searchDirs = [URL(fileURLWithPath: "/Applications")]
        let home = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
        if FileManager.default.fileExists(atPath: home.path) {
            searchDirs.append(home)
        }

        var found: [String] = []
        let fm = FileManager.default
        for dir in searchDirs {
            guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for item in items where item.pathExtension == "app" {
                let bundleName = item.deletingPathExtension().lastPathComponent
                if let entry = bundleNameIndex[bundleName] {
                    found.append(entry.canonicalName)
                }
            }
        }
        let foundSet = Set(found)
        return entries.compactMap { foundSet.contains($0.canonicalName) ? $0.canonicalName : nil }
    }

    static func runningApps() -> Set<String> {
        let running = NSWorkspace.shared.runningApplications.compactMap { $0.localizedName }
        return Set(running.filter { canonicalNameSet.contains($0) })
    }
}
