#!/bin/bash
# sort_to_folders.sh
# Sorts loose image/video files in a directory into subfolders.
# Usage: ./sort_to_folders.sh [path]
# If no path given, uses current directory.

TARGET="${1:-.}"
cd "$TARGET" || { echo "ERROR: Cannot access $TARGET"; exit 1; }
echo "Processing: $(pwd)"
moved=0

for file in *; do
    [[ -f "$file" ]] || continue

    # Get extension as-is (preserve case)
    ext="${file##*.}"

    case "$ext" in
        JPG|JPEG)             folder="jpegs_from_camera" ;;
        jpg|jpeg)             folder="jpegs_other" ;;
        NEF)                  folder="nefs" ;;
        xmp|acr)              folder="nefs" ;;
        DNG|ORF|CR2|CR3|ARW)  folder="other_raws" ;;
        MOV|MP4)              folder="videos" ;;
        mov|mp4)              folder="videos_other" ;;
        *)                    continue ;;
    esac

    mkdir -p "$folder"
    if [[ ! -f "$folder/$file" ]]; then
        echo "Moving '$file' -> '$folder/'"
        mv "$file" "$folder/"
        ((moved++))
    fi
done

echo "Done. Moved $moved file(s)."
