#!/usr/bin/env bash
set -euo pipefail

# Create albums for the latest N event folders (by mtime) that lack one.
# Usage:  IMMICH_API_KEY='key' add_latest_albums.sh [N]   (N defaults to 10)
# Works both as root (cron) and as a normal user (uses sudo for docker).

# ---- config ----
IMMICH_URL="http://localhost:30041"
API_KEY="${IMMICH_API_KEY:?Set IMMICH_API_KEY before running}"
PG_CONTAINER="ix-immich-pgvecto-1"
PGUSER="immich"
PGDB="immich"
HOST_ROOT="/mnt/Home_1"
DB_ROOT="/mnt/photos"
ROOTS=(
  "${HOST_ROOT}/PhotoSPOT_I"
  "${HOST_ROOT}/PhotoSPOT_II"
  "${HOST_ROOT}/PhotoSPOT_III"
)
LIMIT="${1:-10}"
DRY_RUN="${DRY_RUN:-0}"
# ----------------

hdr_key=(-H "x-api-key: ${API_KEY}")
hdr_json=(-H "Content-Type: application/json")

if [[ $EUID -eq 0 ]]; then DOCKER=(docker); else DOCKER=(sudo docker); fi

existing_names="$(mktemp)"
curl -s "${hdr_key[@]}" "${IMMICH_URL}/api/albums" \
  | jq -r '.[].albumName' > "$existing_names"

album_exists() { grep -Fxq -- "$1" "$existing_names"; }

mapfile -t EVENT_DIRS < <(
  for root in "${ROOTS[@]}"; do
    find "$root" -mindepth 1 -maxdepth 1 -type d -printf '%T@\t%p\n'
  done | sort -rn | cut -f2-
)

created=0
for dir in "${EVENT_DIRS[@]}"; do
  (( created >= LIMIT )) && break

  album_name="$(basename "$dir")"
  db_dir="${DB_ROOT}${dir#$HOST_ROOT}"

  album_exists "$album_name" && continue

  mapfile -t ASSET_IDS < <(
    "${DOCKER[@]}" exec "$PG_CONTAINER" \
      psql -U "$PGUSER" "$PGDB" -At -c \
      "SELECT id FROM asset
       WHERE type IN ('IMAGE','VIDEO')
         AND \"deletedAt\" IS NULL
         AND \"originalPath\" LIKE '${db_dir//\'/\'\'}/%';"
  )

  if [[ ${#ASSET_IDS[@]} -eq 0 ]]; then
    echo "SKIP (not indexed yet): $dir"
    continue
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "DRY: would create '${album_name}' with ${#ASSET_IDS[@]} assets <- $dir"
    created=$((created + 1))
    continue
  fi

  album_id="$(
    curl -s "${hdr_key[@]}" "${hdr_json[@]}" \
      -X POST "${IMMICH_URL}/api/albums" \
      -d "{\"albumName\":$(jq -Rn --arg n "$album_name" '$n')}" \
      | jq -r '.id'
  )"

  ids_file="$(mktemp)"
  printf '%s\n' "${ASSET_IDS[@]}" | jq -R . | jq -s . > "$ids_file"
  jq -c '_nwise(250)' "$ids_file" | while IFS= read -r chunk; do
    curl -s "${hdr_key[@]}" "${hdr_json[@]}" \
      -X PUT "${IMMICH_URL}/api/albums/${album_id}/assets" \
      -d "{\"ids\":${chunk}}" > /dev/null
  done
  rm -f "$ids_file"

  echo "$album_name" >> "$existing_names"
  echo "OK: created '${album_name}' (${#ASSET_IDS[@]} assets) <- $dir"
  created=$((created + 1))
done

rm -f "$existing_names"
echo "Done. Created ${created} album(s)."
