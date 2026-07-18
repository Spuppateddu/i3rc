#!/usr/bin/env bash
# Uniform entry point for orchestrators (e.g. best-linux-environment): they
# clone/update this repo and just call ./install.sh. The real install logic
# lives in setup.sh; this wrapper delegates to it, then live-reloads a running
# i3 session so a pulled config applies immediately.
#
# Usage: ./install.sh [--dry-run]     (also honours DRY_RUN=true from the env)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true
DRY_RUN="${DRY_RUN:-false}"

args=()
[[ "$DRY_RUN" == true ]] && args+=(--dry-run)

chmod +x "$REPO/setup.sh"
bash "$REPO/setup.sh" ${args[@]+"${args[@]}"}

if [[ "$DRY_RUN" != true ]] && command -v i3-msg >/dev/null 2>&1 \
   && i3-msg -t get_version >/dev/null 2>&1; then
    i3-msg reload >/dev/null || echo "i3 reload failed — try \$mod+Shift+r." >&2
fi
