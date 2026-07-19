#!/usr/bin/env bash
set -euo pipefail

hosts=(
  leo@10.0.0.19
  leo@10.0.0.30
  leo@10.0.0.29
)

for host in "${hosts[@]}"; do
  ssh "$host" sudo systemctl reboot &
done

wait
