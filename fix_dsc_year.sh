#!/bin/bash
HOST_FOLDER="/mnt/Home_1/PhotoSPOT_I/2010.09.12_Kharkov/пАШКА"
MNT="/work"
DRYRUN=${1:-}
ARGFILE="/tmp/dsc_year_args.txt"
DATESFILE="/tmp/dsc_dates.txt"
> "$ARGFILE"

current_file=""
while IFS= read -r line; do
  if [[ "$line" == ======* ]]; then
    # extract filename: /tmp/DSC_1831.JPG_original -> DSC_1831.JPG
    orig_base=$(basename "${line#======== /tmp/}")
    current_file="${orig_base%.JPG_original}.JPG"
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
