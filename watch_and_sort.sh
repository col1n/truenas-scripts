#!/bin/bash
# watch_and_sort.sh
# Watches PhotoSPOT folders and triggers walk_and_sort.sh after 30 min of no new files

WATCH_DIRS="/mnt/Home_1/PhotoSPOT_I /mnt/Home_1/PhotoSPOT_II /mnt/Home_1/PhotoSPOT_III"
QUIET_MINUTES=30
SORT_SCRIPT="/mnt/Home_1/walk_and_sort.sh"
STAMP_FILE="/tmp/photospot_last_activity"
LOG="/mnt/Home_1/sort_log.txt"
LOCK_FILE="/tmp/watch_and_sort.lock"

if [ -f "$LOCK_FILE" ]; then
    exit 0
fi

touch "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

# Check for files newer than the stamp file
if [[ -f "$STAMP_FILE" ]]; then
    new_files=$(find $WATCH_DIRS -newer "$STAMP_FILE" -type f \( -name "*.JPG" -o -name "*.NEF" -o -name "*.MOV" -o -name "*.MP4" -o -name "*.mp4" \) 2>/dev/null | wc -l)
else
    new_files=$(find $WATCH_DIRS -type f 2>/dev/null | wc -l)
fi

if [[ $new_files -gt 0 ]]; then
    echo "$(date): $new_files new files detected, resetting quiet timer" >> "$LOG"
    touch "$STAMP_FILE"
    exit 0
fi

# No new files ??? check if quiet period has passed
if [[ ! -f "$STAMP_FILE" ]]; then
    exit 0
fi

last_activity=$(stat -c %Y "$STAMP_FILE")
now=$(date +%s)
elapsed=$(( (now - last_activity) / 60 ))

if [[ $elapsed -ge $QUIET_MINUTES ]]; then
    echo "$(date): Quiet for ${elapsed} min ??? triggering walk_and_sort.sh" >> "$LOG"
    "$SORT_SCRIPT" >> "$LOG" 2>&1
    rm -f "$STAMP_FILE"
    echo "$(date): Sort complete" >> "$LOG"
else
    echo "$(date): Quiet for ${elapsed} min, waiting for ${QUIET_MINUTES} min threshold" >> "$LOG"
fi
