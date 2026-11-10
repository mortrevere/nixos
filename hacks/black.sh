#!/usr/bin/env bash
set -euo pipefail

action="${1-switch}"
if [[ $# -gt 1 || ($action != switch && $action != boot) ]]; then
  echo "Usage: $0 [switch|boot]" >&2
  exit 2
fi

exec nix shell nixpkgs#nixos-rebuild -c nixos-rebuild "$action" \
  --flake '.?submodules=1#black' \
  --target-host leo@black.house.leo.surf \
  --build-host leo@black.house.leo.surf \
  --sudo
