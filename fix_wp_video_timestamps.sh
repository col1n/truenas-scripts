#!/bin/bash
# Fix WP_ video timestamps from filename, preserving intra-day order via _NNN suffix.
set -euo pipefail
FOLDER="/mnt/Home_1/PhotoSPOT_I/2013.09.22-27_Germany/newVIDEO/1"
DRYRUN=${1:-}            # pass --dry-run to preview
START_HOUR=10            # first file of each day starts here
STEP_MIN=2               # minutes added per sequence step

# ---------- PASS 1: collect ----------
# Build lines: <date> <seq> <fullpath>
mapfile -t entries < <(
  find "$FOLDER" -type f -iname 'WP_*' | while read -r f; do
    base=$(basename "$f")
    date=$(echo "$base" | grep -oE '[0-9]{8}' | head -1)
    [ -z "$date" ] && continue
    # sequence: the number group after the date, e.g. WP_20130922_027 -> 027
    seq=$(echo "$base" | sed -E 's/.*[0-9]{8}_([0-9]+).*/\1/')
    [ "$seq" = "$base" ] && seq=0     # no match -> 0
    echo "$date $seq $f"
  done | sort -k1,1 -k2,2n          # sort by date, then sequence
)

# ---------- PASS 2: assign times within each day ----------
prev_date=""
idx=0
for line in "${entries[@]}"; do
  date=$(echo "$line" | awk '{print $1}')
  seq=$(echo  "$line" | awk '{print $2}')
  f=$(echo    "$line" | cut -d' ' -f3-)
  base=$(basename "$f")

  if [ "$date" != "$prev_date" ]; then idx=0; prev_date="$date"; fi

  total_min=$(( idx * STEP_MIN ))
  hh=$(( START_HOUR + total_min / 60 ))
  mm=$(( total_min % 60 ))
  idx=$(( idx + 1 ))

  Y=${date:0:4}; M=${date:4:2}; D=${date:6:2}
  exif_dt=$(printf '%s:%s:%s %02d:%02d:00' "$Y" "$M" "$D" "$hh" "$mm")
  touch_dt=$(printf '%s%02d%02d' "$date" "$hh" "$mm")

  cur=$(exiftool -s3 -CreateDate "$f" 2>/dev/null)

  if [ "$DRYRUN" = "--dry-run" ]; then
    printf 'WOULD: %-28s seq=%-4s cur=%-20s -> %s\n' "$base" "$seq" "${cur:-<none>}" "$exif_dt"
    continue
  fi

  printf 'FIX: %-28s -> %s\n' "$base" "$exif_dt"
  exiftool -api QuickTimeUTC=1 -overwrite_original \
    "-CreateDate=$exif_dt" "-ModifyDate=$exif_dt" \
    "-MediaCreateDate=$exif_dt" "-MediaModifyDate=$exif_dt" \
    "-TrackCreateDate=$exif_dt" "-TrackModifyDate=$exif_dt" \
    "$f"
  touch -t "$touch_dt" "$f"
done