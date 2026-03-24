# EndOfDay.app

> A macOS menu bar app that closes your work apps at the end of the day — automatically.

<p align="center">
  <img src="EndOfDay.app/Contents/Resources/MenuBarIcon@2x.png" width="72" alt="App Icon">
</p>

---

## Screenshots

| Onboarding | Stats | Tray Menu |
|:---:|:---:|:---:|
| ![Onboarding](docs/screenshot-onboarding.png) | ![Stats](docs/screenshot-stats.png) | ![Tray](docs/screenshot-tray.png) |

---

## Features

- **Menu bar tray** — persistent sunset icon in the top bar; no Dock clutter
- **Custom day picker** — choose exactly which days to run (Mon, Tue, Wed…)
- **Pause Today** — skip tonight without changing your schedule
- **Snooze 30 min** — delay from the countdown alert or tray menu
- **Per-app close delay** — stagger quits so apps have time to save (0–10s)
- **Analytics** — streak, total runs, apps closed, 7-day bar chart, recent history
- **Uninstall** — removes launchd agent + config from within the app

---

## Install

**Option 1 — Download release**

Download `EndOfDay.app.zip` from the [latest release](https://github.com/RohiRIK/end-of-day-mac/releases/latest), unzip, and double-click.

**Option 2 — Build from source**

```bash
git clone https://github.com/RohiRIK/end-of-day-mac
cd end-of-day-mac
bash install.sh
```

Requires Xcode Command Line Tools (`xcode-select --install`) and macOS 12+.

---

## Usage

| Action | How |
|--------|-----|
| First-time setup | Run `install.sh` or double-click the app |
| Change apps / schedule | Double-click the app |
| Pause tonight | Tray icon → Pause Today |
| Snooze | Tray icon → Snooze 30 min |
| View stats | Tray icon → View Stats… |
| Run now | Tray icon → Run Now |
| Uninstall | Double-click app → Uninstall… |

---

## How it works

1. `install.sh` compiles the Swift sources and opens the setup wizard
2. Pick a trigger time + which apps to close + which days to run
3. A launchd agent (`com.endofday.closeapps`) starts `EndOfDay --menubar` at login with `KeepAlive: true`
4. The tray app runs all day with an internal Timer — no polling overhead
5. At trigger time → 30s countdown alert → close apps → log to analytics

**Config:** `~/.config/end_of_day/config.json`
**Analytics:** `~/.config/end_of_day/analytics.json`
**Logs:** `~/Library/Logs/end_of_day/end_of_day.log`

---

## Requirements

- macOS 12+
- Xcode Command Line Tools (`xcode-select --install`)
