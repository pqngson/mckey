#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/mckey-runtime.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT

CLANG_MODULE_CACHE_PATH="$build_dir/module-cache" SWIFT_MODULECACHE_PATH="$build_dir/module-cache" swiftc -O \
  "$root/McKey/Engine/PHTVOptions.swift" \
  "$root/McKey/McKeySettings.swift" \
  "$root/McKey/EnglishApps.swift" \
  "$root/Tests/Runtime/McKeySettingsTests.swift" \
  -o "$build_dir/runtime-tests"

cat > "$build_dir/run-cases.sh" <<'SH'
#!/bin/sh
set -eu
for test_case in migration malformed-import roundtrip reset-batch modifier-release cancel key-release modifier-map restore-release pause-hold english-apps english-apps-persist; do
  "$HOME/.ai/capped" 20 "$1" "$test_case"
done
SH
chmod +x "$build_dir/run-cases.sh"
"$HOME/.ai/capped" 30 "$build_dir/run-cases.sh" "$build_dir/runtime-tests"
