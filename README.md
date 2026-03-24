# End-of-Day App Closure

Closes your work apps at the end of each day via a native macOS dialog.
Scheduled daily at **18:30** using launchd. Zero dependencies — pure Bash + osascript.

## Quick Start

```bash
bash scripts/install.sh
```

That's it. The installer runs onboarding, sets up the schedule, and verifies everything.

---

## How It Works

### Setup Flow (run once)

```
┌─────────────────────────────────────┐
│         bash install.sh             │
└──────────────────┬──────────────────┘
                   │
                   ▼
        ┌──────────────────────┐
        │  chmod +x scripts    │
        └──────────┬───────────┘
                   │
                   ▼
        ┌──────────────────────────────────────┐
        │          onboarding.sh               │
        │                                      │
        │  ╔══════════════════════════════╗    │
        │  ║  macOS "choose from list"    ║    │
        │  ║                              ║    │
        │  ║  [x] Microsoft Outlook       ║    │
        │  ║  [x] Microsoft Teams         ║    │
        │  ║  [ ] Slack                   ║    │
        │  ║  [x] Microsoft Edge          ║    │
        │  ║  [ ] Zoom          [Cancel]  ║    │
        │  ║                    [  OK  ]  ║    │
        │  ╚══════════════════════════════╝    │
        └──────────┬───────────────────────────┘
                   │  saves selection
                   ▼
        ┌──────────────────────────────┐
        │  ~/.config/end_of_day/       │
        │  apps.conf                   │
        └──────────┬───────────────────┘
                   │
                   ▼
        ┌──────────────────────────────────────────────────┐
        │  generate plist  →  ~/Library/LaunchAgents/      │
        │  launchctl bootstrap  (Ventura+)                  │
        │  launchctl load       (older macOS)               │
        └──────────┬───────────────────────────────────────┘
                   │
                   ▼
        ┌──────────────────────────────┐
        │  ✓ Agent registered          │
        │    Runs daily at 18:30       │
        └──────────────────────────────┘
```

### Daily Runtime Flow (18:30, triggered by launchd)

```
  ┌────────────────────────────┐
  │     launchd  @  18:30      │
  └─────────────┬──────────────┘
                │
                ▼
  ┌─────────────────────────────────┐
  │  read ~/.config/end_of_day/     │
  │  apps.conf                      │
  └─────────────┬───────────────────┘
                │
                ▼
         ┌──────┴──────┐
         │ any app     │
         │  running?   │
         └──┬───────┬──┘
           YES      NO
            │        └──────────────────────► exit silently
            ▼
  ┌─────────────────────────────────┐
  │  🔔  notification banner        │
  │      "Time to wrap up 🌅"       │
  │      "Apps closing in 30s"      │
  └─────────────┬───────────────────┘
                │
                ▼
  ┌──────────────────────────────────────┐
  │  ╔════════════════════════════════╗  │
  │  ║   End of Day                   ║  │
  │  ║                                ║  │
  │  ║  It's the end of the day! 🌅   ║  │
  │  ║  Work apps are about to close. ║  │
  │  ║  Auto-confirms in 30s.         ║  │
  │  ║                                ║  │
  │  ║  [ Not Now ]  [Close Apps Now] ║  │
  │  ╚════════════════════════════════╝  │
  └──────────┬──────────────┬────────────┘
             │              │
          Not Now    Close / Timeout
             │              │
             ▼              ▼
           exit    ┌────────────────────────────┐
                   │  tell application X to quit │
                   │  (pkill fallback)            │
                   └────────────┬────────────────┘
                                │
                                ▼
                   ┌────────────────────────────────┐
                   │  🔔  result notification        │
                   │                                 │
                   │  ╔═════════════════════════╗   │
                   │  ║  End of Day — Done  🌙   ║   │
                   │  ║                          ║   │
                   │  ║  Closed 3 app(s):        ║   │
                   │  ║  • Microsoft Outlook     ║   │
                   │  ║  • Microsoft Teams       ║   │
                   │  ║  • Microsoft Edge        ║   │
                   │  ║              [Great, thanks!]║  │
                   │  ╚═════════════════════════╝   │
                   │      (auto-dismisses in 10s)    │
                   └────────────────────────────────┘
```

---

## Files

| File | Purpose |
|------|---------|
| `scripts/install.sh` | One-shot installer — run this first |
| `scripts/onboarding.sh` | Interactive app selector — re-run anytime to change your list |
| `scripts/end_of_day.sh` | Main script — triggered daily by launchd |

**Config & Logs** (created on first run):

| Path | Purpose |
|------|---------|
| `~/.config/end_of_day/apps.conf` | Your selected apps (newline-delimited) |
| `~/Library/Logs/end_of_day/end_of_day.log` | Runtime log |
| `~/.config/end_of_day/install.log` | Install log |
| `~/Library/LaunchAgents/com.endofday.closeapps.plist` | Generated launchd agent |

---

## Change Your App List

```bash
bash scripts/onboarding.sh
```

Re-runs the selection dialog and overwrites `apps.conf`. No reinstall needed.

## Test Without Waiting for 18:30

```bash
bash scripts/end_of_day.sh
```

## Uninstall

```bash
launchctl bootout gui/$(id -u)/com.endofday.closeapps
rm ~/Library/LaunchAgents/com.endofday.closeapps.plist
rm -rf ~/.config/end_of_day
```

---

## First-Run Permission Prompt

On first execution macOS will ask:

> *"Terminal" wants to control "System Events"*

Allow it in **System Settings › Privacy & Security › Automation**.
This is a one-time prompt.
