#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
swiftc -module-cache-path "$TMP/modules" \
  "$ROOT"/McKey/Engine/*.swift \
  "$ROOT"/McKey/Settings/EngineCodeTableLookup.swift \
  "$ROOT"/McKey/Settings/McKeyTextConversionService.swift \
  "$ROOT"/Tests/Settings/ConversionTests.swift \
  -o "$TMP/conversion-tests"
PHTV_TEST_BINARY="$TMP/conversion-tests" python3 - <<'PY'
import os, subprocess, time

binary = os.environ["PHTV_TEST_BINARY"]
started = time.monotonic()
for case in ["tables", "exhaustive", "tcvn-canonical", "fallback-passthrough", "remove-marks", "tcvn-uppercase", "case-modes"]:
    remaining = 30 - (time.monotonic() - started)
    if remaining <= 0:
        raise SystemExit("conversion tests exceeded the 30 second cap")
    try:
        subprocess.run([binary, case], check=True, timeout=min(5, remaining), text=True)
    except subprocess.TimeoutExpired:
        raise SystemExit(f"conversion test timed out: {case}")
PY
