#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

dart pub get
dart analyze
dart test -p vm

browser_tests=()
for test_file in test/*_test.dart; do
  if grep -q "^@TestOn('browser')" "$test_file"; then
    browser_tests+=("$test_file")
  fi
done

if ((${#browser_tests[@]} == 0)); then
  echo "No browser tests found" >&2
  exit 1
fi

browser_platform=${BLOOM_BROWSER:-chrome}
if [[ "$browser_platform" == "chrome" ]]; then
  if [[ -z "${CHROME_EXECUTABLE:-}" ]]; then
    for candidate in chromium chromium-browser google-chrome google-chrome-stable; do
      if command -v "$candidate" >/dev/null 2>&1; then
        CHROME_EXECUTABLE=$(command -v "$candidate")
        break
      fi
    done
  fi
  if [[ -z "${CHROME_EXECUTABLE:-}" || ! -x "$CHROME_EXECUTABLE" ]]; then
    echo "Chrome browser tests need CHROME_EXECUTABLE set to an executable Chrome/Chromium path." >&2
    echo "Set BLOOM_BROWSER to another supported browser platform to use a different browser." >&2
    exit 1
  fi
  export CHROME_EXECUTABLE
fi
dart test -p "$browser_platform" -j 1 "${browser_tests[@]}"

build_js=$(mktemp "${TMPDIR:-/tmp}/bloom-js-native.XXXXXX")
trap 'rm -f "$build_js" "$build_js.map" "$build_js.deps"' EXIT
dart compile js -O4 -o "$build_js" example/main.dart
gzip_bytes=$(gzip -c "$build_js" | wc -c | tr -d '[:space:]')
if ((gzip_bytes > 51200)); then
  echo "Production example exceeds 50 KiB gzip: $gzip_bytes bytes" >&2
  exit 1
fi
echo "Production example: $gzip_bytes bytes gzip (50 KiB budget)"

dart compile js -O4 -o "$build_js" tool/i18n_size.dart
i18n_gzip_bytes=$(gzip -c "$build_js" | wc -c | tr -d '[:space:]')
if ((i18n_gzip_bytes > 102400)); then
  echo "Localized entry exceeds 100 KiB gzip: $i18n_gzip_bytes bytes" >&2
  exit 1
fi
echo "Localized entry: $i18n_gzip_bytes bytes gzip (100 KiB budget)"
