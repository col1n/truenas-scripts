#!/bin/bash
HOST_FOLDER="/mnt/Home_1/PhotoSPOT_I/2010.09.12_Kharkov/пАШКА"
MNT="/work"
DRYRUN=${1:-}
START_HOUR=10
STEP_MIN=2
ARGFILE="/tmp/dsc_exif_args.txt"
> "$ARGFILE"

mapfile -t entries < <(
  find "$HOST_FOLDER" -maxdepth 1 -type f -iname 'DSC_*.jpg' | while read -r f; do
    base=$(basename "$f")
    seq=$(echo "$base" | grep -oE '[0-9]+' | head -1)
    [ -z "$seq" ] && continue
    echo "$seq $f"
  done | sort -k1,1n
)

idx=0
for line in "${entries[@]}"; do
  f=$(echo "$line" | cut -d' ' -f2-)
  base=$(basename "$f")
  total_min=$(( idx * STEP_MIN ))
  hh=$(( START_HOUR + total_min / 60 ))
  mm=$(( total_min % 60 ))
  idx=$(( idx + 1 ))
  dt=$(printf '2010:09:12 %02d:%02d:00' "$hh" "$mm")
  human=$(printf '2010-09-12 %02d:%02d' "$hh" "$mm")

  if [ "$DRYRUN" = "--dry-run" ]; then
    printf 'WOULD: %-20s -> %s\n' "$base" "$human"
    continue
  fi

  printf 'PLAN:  %-20s -> %s\n' "$base" "$human"
  {
    echo "-DateTimeOriginal=$dt"
    echo "-CreateDate=$dt"
    echo "-ModifyDate=$dt"
    echo "$MNT/$(basename "$f")"
    echo "-execute"
  } >> "$ARGFILE"
done

if [ "$DRYRUN" = "--dry-run" ]; then
  echo "Dry run. ${#entries[@]} files would be processed."
  exit 0
fi

sudo docker run --rm -v "$HOST_FOLDER":"$MNT" -v "$ARGFILE":"$ARGFILE" \
  tigerj/exiftool exiftool -overwrite_original -P -@ "$ARGFILE"

echo "Done."
