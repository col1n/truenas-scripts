#!/bin/bash
# Deploy scripts from repo (/mnt/Home_1/scripts) to live location (/mnt/Home_1/).
# Prompts per-file, shows a diff, and backs up the existing version first.
set -euo pipefail

REPO="/mnt/Home_1/scripts"
LIVE="/mnt/Home_1"

# Scripts managed by this deploy (edit this list as you add more)
SCRIPTS="sort_to_folders.sh walk_and_sort.sh watch_and_sort.sh"

for s in $SCRIPTS; do
  src="$REPO/$s"
  dst="$LIVE/$s"

  if [ ! -f "$src" ]; then
    echo "SKIP: $s not in repo"
    continue
  fi

  echo "=============================="
  echo "Script: $s"

  if [ ! -f "$dst" ]; then
    echo "  (no live version exists — would be a new file)"
  elif diff -q "$src" "$dst" >/dev/null; then
    echo "  identical to live version — nothing to do"
    continue
  else
    echo "  --- diff (live vs repo) ---"
    diff "$dst" "$src"
    echo "  ---------------------------"
  fi

  read -p "Update $s ? [y/N] " ans < /dev/tty
  if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
    if [ -f "$dst" ]; then
      cp "$dst" "$dst.bak"
      echo "  backed up -> $s.bak"
    fi
    cp "$src" "$dst"
    chmod +x "$dst"
    echo "  deployed $s"
  else
    echo "  skipped $s"
  fi
done
echo "Done."