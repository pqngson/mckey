#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
APP="$TMP/EngineHarness.app/Contents"
mkdir -p "$APP/MacOS" "$APP/Resources"
cat > "$APP/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>local.mckey.engine-tests</string><key>CFBundleExecutable</key><string>engine-tests</string><key>CFBundlePackageType</key><string>APPL</string></dict></plist>
PLIST
cp "$ROOT"/McKey/Resources/Dictionaries/*.bin "$APP/Resources/"
swiftc -module-cache-path "$TMP/modules" "$ROOT"/McKey/Engine/*.swift "$ROOT"/Tests/Engine/EngineRegressionTests.swift -o "$APP/MacOS/engine-tests"
PHTV_TEST_BINARY="$APP/MacOS/engine-tests" python3 - <<'PY'
import os, subprocess, sys, time

binary = os.environ["PHTV_TEST_BINARY"]
cases = ["telex", "vni", "simple", "tables", "backspace", "vni-backspace", "caps", "reset", "escape", "dictionary", "instances", "modern", "shortcuts", "quick", "restore", "words", "raw", "quick-start", "quick-end", "custom", "no-capitalize", "legacy-options", "boundary-delete", "restore-backspace", "deletion-sync"]
started = time.monotonic()
for case in cases:
    remaining = 30 - (time.monotonic() - started)
    if remaining <= 0:
        raise SystemExit("engine regression wall cap exceeded (30s)")
    try:
        result = subprocess.run([binary, case], check=True, timeout=min(5, remaining), text=True)
    except subprocess.TimeoutExpired:
        raise SystemExit(f"engine regression case timed out: {case}")
PY
