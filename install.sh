#!/usr/bin/env bash
# End-of-Day Automation — Bootstrap Installer
# Compiles the Swift app and launches --setup (first-run wizard).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
APP_DIR="$SCRIPT_DIR/EndOfDay.app/Contents/MacOS"
BINARY="$APP_DIR/EndOfDay"
LOG_DIR="$HOME/.config/end_of_day"

mkdir -p "$APP_DIR" "$LOG_DIR"

# ── Compile (skip if binary is newer than all sources) ───────────────────────
needs_compile=false
if [[ ! -f "$BINARY" ]]; then
    needs_compile=true
else
    for src in "$SRC_DIR"/*.swift; do
        if [[ "$src" -nt "$BINARY" ]]; then
            needs_compile=true
            break
        fi
    done
fi

if $needs_compile; then
    if ! command -v swiftc &>/dev/null; then
        echo "ERROR: swiftc not found. Install Xcode Command Line Tools: xcode-select --install" >&2
        exit 1
    fi
    echo "Compiling EndOfDay..."
    SDK="$(xcrun --show-sdk-path 2>/dev/null || true)"
    swiftc \
        ${SDK:+-sdk "$SDK"} \
        "$SRC_DIR"/*.swift \
        -o "$BINARY" \
        -framework Cocoa \
        -framework UserNotifications \
        2>&1 | tee "$LOG_DIR/install.log"
    chmod +x "$BINARY"
    echo "Compiled successfully."
else
    echo "Binary up to date — skipping compile."
fi

# ── Launch setup (or onboard if config exists) ────────────────────────────────
if [[ -f "$HOME/.config/end_of_day/config.json" ]]; then
    echo "Existing config found. Launching app selection..."
    "$BINARY" --onboard
else
    echo "Launching first-run setup..."
    "$BINARY" --setup
fi
