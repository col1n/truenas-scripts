#!/bin/bash
# Set filesystem timestamps on WP_ videos from their filename date,
# preserving intra-day order via the _NNN sequence suffix.
FOLDER="/mnt/Home_1/PhotoSPOT_I/2013.09.22-27_Germany/newVIDEO/"
DRYRUN=${1:-}            # pass --dry-run to preview only
START_HOUR=10            # first file of each day starts here
STEP_MIN=2              # minutes added per sequence step

# ---------- PASS 1: collect <date> <seq> <fullpath>, sorted ----------
mapfile -t entries < <(
  find "$FOLDER" -type f -iname 'WP_*' | while read -r f; do
    base=$(basename "$f")
    date=$(echo "$base" | grep -oE '[0-9]{8}' | head -1)
    [ -z "$date" ] && continue
    seq=$(echo "$base" | sed -E 's/.*[0-9]{8}_([0-9]+).*/\1/')
    [ "$seq" = "$base" ] && seq=0
    echo "$date $seq $f"
  done | sort -k1,1 -k2,2n
)

# ---------- PASS 2: assign incrementing times per day ----------
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

  touch_dt=$(printf '%s%02d%02d' "$date" "$hh" "$mm")
  human=$(printf '%s-%s-%s %02d:%02d' "${date:0:4}" "${date:4:2}" "${date:6:2}" "$hh" "$mm")

  if [ "$DRYRUN" = "--dry-run" ]; then
    printf 'WOULD: %-28s seq=%-4s -> %s\n' "$base" "$seq" "$human"
    continue
  fi

  printf 'SET: %-28s -> %s\n' "$base" "$human"
  touch -t "$touch_dt" "$f"
done
echo "Done."
