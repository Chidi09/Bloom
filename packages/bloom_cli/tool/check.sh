#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

dart pub get
dart analyze
dart test -j 1 --exclude-tags browser_e2e
