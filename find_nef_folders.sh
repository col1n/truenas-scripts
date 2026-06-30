#!/usr/bin/env bash
set -euo pipefail

# ---- config ----
HOST_ROOT="/mnt/Home_1"
ROOTS=(
  "${HOST_ROOT}/PhotoSPOT_I"
  "${HOST_ROOT}/PhotoSPOT_II"
  "${HOST_ROOT}/PhotoSPOT_III"
)
# ----------------

mapfile -t EVENT_DIRS < <(
  for root in "${ROOTS[@]}"; do
    find "$root" -mindepth 1 -maxdepth 1 -type d
  done | sort -u
)

total=0
for dir in "${EVENT_DIRS[@]}"; do
  count=$(find "$dir" -type f -iname '*.nef' | wc -l)
  if [[ "$count" -gt 0 ]]; then
    printf '%6d  %s\n' "$count" "$dir"
    total=$((total + 1))
  fi
done

echo "----"
echo "Folders containing NEFs: ${total}"
