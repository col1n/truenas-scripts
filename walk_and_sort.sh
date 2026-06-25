#!/bin/bash
# walk_and_sort.sh
# Usage: ./walk_and_sort.sh
# Usage: ./walk_and_sort.sh [--dry-run]

SORT_SCRIPT="/mnt/Home_1/sort_to_folders.sh"
LOG_DATE=$(date '+%Y-%m-%d %H:%M:%S')
DRY_RUN=false

[[ "$1" == "--dry-run" ]] && DRY_RUN=true

SORTED_MARKERS=("jpegs_from_camera" "jpegs_from_nefs" "nefs" "videos" "other_raws" "jpegs_other" "videos_other")

PHOTO_ROOTS=(
    "/mnt/Home_1/PhotoSPOT_I"
    "/mnt/Home_1/PhotoSPOT_II"
    "/mnt/Home_1/PhotoSPOT_III"
)

echo "=== $LOG_DATE ==="
$DRY_RUN && echo "--- DRY RUN MODE ---"

processed=0
total=0

has_loose_uppercase() {
    local dir="$1"
    for ext in JPG JPEG NEF ORF DNG CR2 CR3 ARW MOV MP4 XMP; do
        find "$dir" -maxdepth 1 -name "*.$ext" | grep -q . && return 0
    done
    return 1
}

is_sorted() {
    local dir="$1"
    for marker in "${SORTED_MARKERS[@]}"; do
        [[ -d "$dir/$marker" ]] && return 0
    done
    return 1
}

process_dir() {
    local dir="$1"
    ((total++))

    is_sorted "$dir" && return

    if has_loose_uppercase "$dir"; then
        if $DRY_RUN; then
            echo "WOULD SORT: $dir"
        else
            echo "Sorting: $dir"
            "$SORT_SCRIPT" "$dir"
        fi
        ((processed++))
    fi

    # Also check one level deeper for camera subfolders (nikon/, mavic/ etc.)
    while IFS= read -r subdir; do
        # Skip already-sorted subfolders
        local subname=$(basename "$subdir")
        local is_marker=false
        for marker in "${SORTED_MARKERS[@]}"; do
            [[ "$subname" == "$marker" ]] && is_marker=true && break
        done
        $is_marker && continue

        is_sorted "$subdir" && continue

        if has_loose_uppercase "$subdir"; then
            ((total++))
            if $DRY_RUN; then
                echo "WOULD SORT (camera subfolder): $subdir"
            else
                echo "Sorting (camera subfolder): $subdir"
                "$SORT_SCRIPT" "$subdir"
            fi
            ((processed++))
        fi
    done < <(find "$dir" -mindepth 1 -maxdepth 1 -type d)
}

for root in "${PHOTO_ROOTS[@]}"; do
    if [[ ! -d "$root" ]]; then
        echo "WARNING: $root not found, skipping"
        continue
    fi

    while IFS= read -r dir; do
        process_dir "$dir"
    done < <(find "$root" -mindepth 1 -maxdepth 1 -type d)
done

if $DRY_RUN; then
    echo "Done. Would sort $processed of $total folders."
else
    echo "Done. Sorted $processed of $total folders."
fi
echo ""

