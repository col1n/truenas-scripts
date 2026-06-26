#!/bin/bash
HOST_FOLDER="/mnt/Home_1/PhotoSPOT_I/2010.09.12_Kharkov/пАШКА"
MNT="/work"
DRYRUN=${1:-}
ARGFILE="/tmp/dsc_orig_args.txt"
> "$ARGFILE"

find "$HOST_FOLDER" -maxdepth 1 -type f -name '*.JPG_original' | sort | while read -r orig; do
  base=$(basename "$orig" .JPG_original)
  jpg="$HOST_FOLDER/${base}.JPG"
  [ ! -f "$jpg" ] && { echo "SKIP (no JPG): $base"; continue; }

  dt=$(sudo docker run --rm -v "$HOST_FOLDER":/work tigerj/exiftool exiftool -s3 -DateTimeOriginal "/work/${base}.JPG_original" 2>/dev/null)
  [ -z "$dt" ] && { echo "SKIP (no date): $base"; continue; }

  fixed=$(echo "$dt" | sed 's/^2001/2010/')
  human=$(echo "$fixed" | sed 's/:/\-/;s/:/\-/;s/ /_/')

  if [ "$DRYRUN" = "--dry-run" ]; then
    printf 'WOULD: %-15s %s -> %s\n' "$base" "$dt" "$fixed"
    continue
  fi

  printf 'FIX: %-15s %s -> %s\n' "$base" "$dt" "$fixed"
  {
    echo "-DateTimeOriginal=$fixed"
    echo "-CreateDate=$fixed"
    echo "-ModifyDate=$fixed"
    echo "$MNT/${base}.JPG"
    echo "-execute"
  } >> "$ARGFILE"
done

if [ "$DRYRUN" = "--dry-run" ]; then exit 0; fi

sudo docker run --rm -v "$HOST_FOLDER":"$MNT" -v "$ARGFILE":"$ARGFILE" \
  tigerj/exiftool exiftool -overwrite_original -P -@ "$ARGFILE"

echo "Done."
