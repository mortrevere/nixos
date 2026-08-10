#!/usr/bin/env bash

set -euo pipefail

source_dir=/opt/transmission/downloads/complete
destination_dir=/data/Extreme_SSD/archives/films
minimum_age_minutes=1440

if [[ ! -d $source_dir || ! -d $destination_dir ]]; then
  echo "Source or destination directory is unavailable; nothing to move." >&2
  exit 0
fi

# Transmission may update a file inside a completed item's directory without
# changing the directory timestamp. Only archive an item when neither it nor
# any of its contents has changed during the retention period.
while IFS= read -r -d '' item; do
  name=${item##*/}
  destination=$destination_dir/$name

  if [[ -e $destination || -L $destination ]]; then
    echo "Skipping $item: destination already exists: $destination" >&2
    continue
  fi

  if find "$item" -mmin -"$minimum_age_minutes" -print -quit | grep -q .; then
    continue
  fi

  echo "Moving $item to $destination"
  mv -- "$item" "$destination"
done < <(find "$source_dir" -mindepth 1 -maxdepth 1 -mmin +"$minimum_age_minutes" -print0)
