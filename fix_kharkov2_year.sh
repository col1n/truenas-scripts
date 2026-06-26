#!/bin/bash
HOST_FOLDER="/mnt/Home_1/PhotoSPOT_I/2010_Me_Kharkov_Dima_Vizit/jpegs_from_camera"
MNT="/work"
DRYRUN=${1:-}
ARGFILE="/tmp/kharkov2_year_args.txt"
DATESFILE="/tmp/kharkov2_dates.txt"
sudo rm -f "$ARGFILE" && sudo touch "$ARGFILE" && sudo chmod 777 "$ARGFILE"

current_file=""
while IFS= read -r line; do
  if [[ "$line" == ======* ]]; then
    current_file=$(basename "${line#======== /tmp/}")
  elif [[ "$line" =~ ^2001: ]]; then
    fixed=$(echo "$line" | sed 's/^2001/2010/')
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
