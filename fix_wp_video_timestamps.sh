#!/bin/bash
# Rewrite embedded dates on WP_ videos from filename, preserving intra-day
# order via _NNN suffix. Uses tigerj/exiftool in Docker. Run with sudo.
HOST_FOLDER="/mnt/Home_1/PhotoSPOT_I/2013.09.22-27_Germany/newVIDEO"
MNT="/work"                 # mount point inside container
DRYRUN=${1:-}
START_HOUR=10
STEP_MIN=2
TZ_OFFSET="+03:00"          # Germany summer time in Sep 2013 (CEST)
ARGFILE="/tmp/wp_exif_args.txt"
> "$ARGFILE"

# ---------- PASS 1: collect <date> <seq> <relpath> ----------
mapfile -t entries < <(
  find "$HOST_FOLDER" -type f -iname 'WP_*.mp4' | while read -r f; do
    base=$(basename "$f")
    date=$(echo "$base" | grep -oE '[0-9]{8}' | head -1)
    [ -z "$date" ] && continue
    seq=$(echo "$base" | sed -E 's/.*[0-9]{8}_([0-9]+).*/\1/')
    [ "$seq" = "$base" ] && seq=0
    rel="${f#$HOST_FOLDER/}"
    echo "$date $seq $rel"
  done | sort -k1,1 -k2,2n
)

# ---------- PASS 2: assign times, build exiftool argfile ----------
prev_date=""
idx=0
count=0
for line in "${entries[@]}"; do
  date=$(echo "$line" | awk '{print $1}')
  rel=$(echo "$line" | cut -d' ' -f3-)
  base=$(basename "$rel")

  if [ "$date" != "$prev_date" ]; then idx=0; prev_date="$date"; fi
  total_min=$(( idx * STEP_MIN ))
  hh=$(( START_HOUR + total_min / 60 ))
  mm=$(( total_min % 60 ))
  idx=$(( idx + 1 ))

  Y=${date:0:4}; M=${date:4:2}; D=${date:6:2}
  dt=$(printf '%s:%s:%s %02d:%02d:00' "$Y" "$M" "$D" "$hh" "$mm")
  human=$(printf '%s-%s-%s %02d:%02d' "$Y" "$M" "$D" "$hh" "$mm")

  if [ "$DRYRUN" = "--dry-run" ]; then
    printf 'WOULD: %-28s -> %s\n' "$base" "$human"
    continue
  fi

  printf 'PLAN:  %-28s -> %s\n' "$base" "$human"
  # exiftool argfile entries (one arg per line)
  {
    echo "-DateTimeOriginal=$dt"
    echo "-CreationDate=$dt$TZ_OFFSET"
    echo "-CreateDate=$dt"
    echo "-MediaCreateDate=$dt"
    echo "-TrackCreateDate=$dt"
    echo "$MNT/$rel"
    echo "-execute"
  } >> "$ARGFILE"
  count=$((count+1))
done

if [ "$DRYRUN" = "--dry-run" ]; then
  echo "Dry run only. $((${#entries[@]})) files would be processed."
  exit 0
fi

echo "Processing $count files via exiftool..."
sudo docker run --rm -v "$HOST_FOLDER":"$MNT" -v "$ARGFILE":"$ARGFILE" \
  tigerj/exiftool exiftool -api QuickTimeUTC=1 -overwrite_original -P -@ "$ARGFILE"

echo "Done. Now run a targeted Refresh metadata (or Extract Metadata: All) in Immich."