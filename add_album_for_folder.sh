#!/usr/bin/env bash
set -euo pipefail

# Create an Immich album for ONE folder, only if it doesn't already exist.
# Usage:  IMMICH_API_KEY='key' add_album_for_folder.sh /mnt/Home_1/PhotoSPOT_I/SomeEvent

# ---- config ----
IMMICH_URL="http://localhost:30041"
API_KEY="${IMMICH_API_KEY:?Set IMMICH_API_KEY before running}"
PG_CONTAINER="ix-immich-pgvecto-1"
PGUSER="immich"
PGDB="immich"
HOST_ROOT="/mnt/Home_1"
DB_ROOT="/mnt/photos"
# ----------------

dir="${1:?Usage: add_album_for_folder.sh <event-folder-path>}"
dir="${dir%/}"
album_name="$(basename "$dir")"
db_dir="${DB_ROOT}${dir#$HOST_ROOT}"

hdr_key=(-H "x-api-key: ${API_KEY}")
hdr_json=(-H "Content-Type: application/json")

existing="$(
  curl -s "${hdr_key[@]}" "${IMMICH_URL}/api/albums" \
    | jq -r --arg n "$album_name" '.[] | select(.albumName == $n) | .id' \
    | head -n1
)"

if [[ -n "$existing" ]]; then
  echo "EXISTS: '${album_name}' (album ${existing}) — nothing to do"
  exit 0
fi

mapfile -t ASSET_IDS < <(
  sudo docker exec "$PG_CONTAINER" \
    psql -U "$PGUSER" "$PGDB" -At -c \
    "SELECT id FROM asset
     WHERE type IN ('IMAGE','VIDEO')
       AND \"deletedAt\" IS NULL
       AND \"originalPath\" LIKE '${db_dir//\'/\'\'}/%';"
)

if [[ ${#ASSET_IDS[@]} -eq 0 ]]; then
  echo "SKIP: '${album_name}' has no indexed assets yet"
  exit 0
fi

album_id="$(
  curl -s "${hdr_key[@]}" "${hdr_json[@]}" \
    -X POST "${IMMICH_URL}/api/albums" \
    -d "{\"albumName\":$(jq -Rn --arg n "$album_name" '$n')}" \
    | jq -r '.id'
)"

printf '%s\n' "${ASSET_IDS[@]}" | jq -R . | jq -s . > /tmp/ids_single.json
jq -c '_nwise(250)' /tmp/ids_single.json | while IFS= read -r chunk; do
  curl -s "${hdr_key[@]}" "${hdr_json[@]}" \
    -X PUT "${IMMICH_URL}/api/albums/${album_id}/assets" \
    -d "{\"ids\":${chunk}}" > /dev/null
done

echo "OK: created '${album_name}' (${#ASSET_IDS[@]} assets)"
