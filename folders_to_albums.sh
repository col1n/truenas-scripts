#!/usr/bin/env bash
set -euo pipefail

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
DRY_RUN="${DRY_RUN:-0}"
# ----------------

hdr_key=(-H "x-api-key: ${API_KEY}")
hdr_json=(-H "Content-Type: application/json")

mapfile -t EVENT_DIRS < <(
  for root in "${ROOTS[@]}"; do
    find "$root" -mindepth 1 -maxdepth 1 -type d
  done | sort -u
)

echo "Event folders: ${#EVENT_DIRS[@]}"
[[ "$DRY_RUN" == "1" ]] && echo "*** DRY RUN — no albums will be created ***"

for dir in "${EVENT_DIRS[@]}"; do
  album_name="$(basename "$dir")"

  db_dir="${DB_ROOT}${dir#$HOST_ROOT}"

  existing="$(
    curl -s "${hdr_key[@]}" "${IMMICH_URL}/api/albums" \
      | jq -r --arg n "$album_name" '.[] | select(.albumName == $n) | .id' \
      | head -n1
  )"
  if [[ -n "$existing" ]]; then
    echo "EXISTS: '${album_name}' — skipping"
    continue
  fi

  mapfile -t ASSET_IDS < <(
    docker exec "$PG_CONTAINER" \
      psql -U "$PGUSER" "$PGDB" -At -c \
      "SELECT id FROM asset
       WHERE type IN ('IMAGE','VIDEO')
         AND \"deletedAt\" IS NULL
         AND \"originalPath\" LIKE '${db_dir//\'/\'\'}/%';"
  )

  [[ ${#ASSET_IDS[@]} -eq 0 ]] && { echo "SKIP (empty): $dir"; continue; }

  if [[ "$DRY_RUN" == "1" ]]; then
    echo "DRY: would create '${album_name}' with ${#ASSET_IDS[@]} assets <- $dir"
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

  echo "OK: '${album_name}' (${#ASSET_IDS[@]} assets) <- $dir"
done
