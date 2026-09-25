#!/usr/bin/env bash
# Prints where the Bloom JS Native docs live for the project in the current
# directory (or the directory passed as $1): the project's AGENTS.md, and the
# COOKBOOK.md / reference/llms*.txt shipped inside the resolved bloom_js_native
# package. Resolving through package_config.json means the docs always match
# the package version the project actually compiles against.
#
# Usage: locate_docs.sh [project_dir]

set -euo pipefail

dir="$(cd "${1:-.}" && pwd)"

# Walk up to the nearest Dart project root.
root="$dir"
while [[ "$root" != "/" && ! -f "$root/pubspec.yaml" ]]; do
  root="$(dirname "$root")"
done
if [[ ! -f "$root/pubspec.yaml" ]]; then
  echo "No pubspec.yaml found at or above $dir" >&2
  exit 1
fi
echo "project:   $root"

if [[ -f "$root/AGENTS.md" ]]; then
  echo "agents:    $root/AGENTS.md"
else
  echo "agents:    (none — project was not scaffolded by 'bloom create --js-native')"
fi

pkg=""
config="$root/.dart_tool/package_config.json"
if [[ "$(basename "$root")" == "bloom_js_native" ]]; then
  pkg="$root"
elif [[ -f "$config" ]]; then
  pkg="$(python3 - "$config" <<'PY'
import json, sys, os
from urllib.parse import urlparse, unquote
path = sys.argv[1]
for p in json.load(open(path))["packages"]:
    if p["name"] == "bloom_js_native":
        uri = p["rootUri"]
        if uri.startswith("file:"):
            print(unquote(urlparse(uri).path))
        else:  # relative to .dart_tool/
            print(os.path.normpath(os.path.join(os.path.dirname(path), uri)))
        break
PY
)"
fi

if [[ -z "$pkg" ]]; then
  if [[ -f "$config" ]]; then
    echo "package:   (bloom_js_native is not a dependency of this project)"
  else
    echo "package:   (unresolved — run 'dart pub get' first)"
  fi
  exit 0
fi

version="$(grep -m1 '^version:' "$pkg/pubspec.yaml" | awk '{print $2}')"
echo "package:   $pkg (bloom_js_native $version)"
for f in COOKBOOK.md reference/llms.txt reference/llms-full.txt; do
  if [[ -f "$pkg/$f" ]]; then
    printf '%-10s %s\n' "$(basename "$f"):" "$pkg/$f"
  else
    printf '%-10s %s\n' "$(basename "$f"):" "(missing in this version)"
  fi
done
