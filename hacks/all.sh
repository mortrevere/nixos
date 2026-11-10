#!/usr/bin/env bash
set -euo pipefail

action="${1-switch}"
if [[ $# -gt 1 || ($action != switch && $action != boot) ]]; then
  echo "Usage: $0 [switch|boot]" >&2
  exit 2
fi

LC_ALL=C parallel --line-buffer --tag --halt soon,fail=1 {} "$action" ::: ./hacks/red.sh ./hacks/blue.sh ./hacks/black.sh
