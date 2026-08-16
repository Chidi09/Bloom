#!/usr/bin/env bash
# Splits the /root/dev/Bloom mixed working tree into its two public/private
# slices (preserving history via git-filter-repo) and pushes each to its
# own GitHub repo. Never push this repo's own `origin` directly — it has
# no remote configured on purpose, since a plain push would mix public
# framework code with private cloud/website code into one repo.
#
# Usage: scripts/push-split.sh [branch]   (defaults to current branch)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANCH="${1:-$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

PUBLIC_REMOTE="https://github.com/Chidi09/Bloom.git"
PRIVATE_REMOTE="https://github.com/Chidi09/bloom-cloud.git"

echo "== Splitting '$BRANCH' from $ROOT =="

# --- Public: packages/, apps/, LICENSE, README.md ---
git clone --no-local --branch "$BRANCH" "$ROOT" "$WORKDIR/public" >/dev/null
(
  cd "$WORKDIR/public"
  git filter-repo --path packages/ --path apps/ --path LICENSE --path README.md
  git remote add origin "$PUBLIC_REMOTE"
  git branch -M main
  git push origin main
)
echo "== Pushed public split to $PUBLIC_REMOTE =="

# --- Private: cloud-backend/, cloud-dashboard/, bloom-website/, docs/, examples/ ---
git clone --no-local --branch "$BRANCH" "$ROOT" "$WORKDIR/private" >/dev/null
(
  cd "$WORKDIR/private"
  git filter-repo \
    --path cloud-backend/ \
    --path cloud-dashboard/ \
    --path bloom-website/ \
    --path docs/ \
    --path examples/ \
    --path cloud-dashboard-frontend.md \
    --path bloom-ui-primitives-port-plan.md \
    --path BLOOM_UI_PORT_STATUS.md \
    --path README.md \
    --path LICENSE
  git remote add origin "$PRIVATE_REMOTE"
  git branch -M main
  git push origin main
)
echo "== Pushed private split to $PRIVATE_REMOTE =="
