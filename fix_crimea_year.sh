#!/bin/bash
HOST_FOLDER="/mnt/Home_1/PhotoSPOT_I/2011.07.18-26_Crimea/104NCD60/jpegs_from_camera"
MNT="/work"
DRYRUN=${1:-}
ARGFILE="/tmp/crimea_year_args.txt"
DATESFILE="/tmp/crimea_dates.txt"
> "$ARGFILE"

current_file=""
while IFS= read -r line; do
  if [[ "$line" == ======* ]]; then
    current_file=$(basename "${line#======== /tmp/}")
  elif [[ "$line" =~ ^2002: ]]; then
    fixed=$(echo "$line" | sed 's/^2002/2011/')
    if [ "$DRYRUN" = "--dry-run" ]; then
      printf 'WOULD: %-20s %s -> %s\n' "$current_file" "$line" "$fixed"
    else
      printf 'FIX:   %-20s %s -> %s\n' "$current_file" "$line" "$fixed"
      {
        echo "-DateTimeOriginal=$fixed"
        echo "-CreateDate=$fixed"
        echo "-ModifyDate=$fixed"
        echo "$MNT/$current_file"
        echo "-execute"
      } >> "$ARGFILE"
    fi
  fi
done < "$DATESFILE"

[ "$DRYRUN" = "--dry-run" ] && exit 0

sudo docker run --rm -v "$HOST_FOLDER":"$MNT" -v "$ARGFILE":"$ARGFILE" \
  tigerj/exiftool exiftool -overwrite_original -P -@ "$ARGFILE"

echo "Done."
