#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/dog_grooming/current}"
ENV_FILE="${ENV_FILE:-$APP_DIR/.env.production}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/dog_grooming/postgres}"
BACKUP_PREFIX="${POSTGRES_BACKUP_PREFIX:-backups/postgres}"
POSTGRES_USER="${POSTGRES_USER:-dog_grooming}"
POSTGRES_DB="${POSTGRES_DB:-dog_grooming_production}"
RETENTION_DAYS="${POSTGRES_BACKUP_RETENTION_DAYS:-30}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "No existe el archivo de entorno: $ENV_FILE" >&2
  exit 1
fi

load_dotenv() {
  local line key value

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    [[ -z "$line" || "$line" == \#* ]] && continue
    [[ "$line" == export\ * ]] && line="${line#export }"
    [[ "$line" != *=* ]] && continue

    key="${line%%=*}"
    value="${line#*=}"
    key="${key%"${key##*[![:space:]]}"}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    if [[ ${#value} -ge 2 ]]; then
      if [[ "${value:0:1}" == "\"" && "${value: -1}" == "\"" ]]; then
        value="${value:1:${#value}-2}"
      elif [[ "${value:0:1}" == "'" && "${value: -1}" == "'" ]]; then
        value="${value:1:${#value}-2}"
      fi
    fi

    export "$key=$value"
  done < "$ENV_FILE"
}

load_dotenv

: "${CLOUDFLARE_ACCESS_KEY_ID:?Falta CLOUDFLARE_ACCESS_KEY_ID}"
: "${CLOUDFLARE_SECRET_ACCESS_KEY:?Falta CLOUDFLARE_SECRET_ACCESS_KEY}"
: "${CLOUDFLARE_R2_ENDPOINT:?Falta CLOUDFLARE_R2_ENDPOINT}"

CLOUDFLARE_R2_BUCKET="${CLOUDFLARE_R2_BUCKET:-dog-grooming}"
BACKUP_PREFIX="${BACKUP_PREFIX%/}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_FILE="$BACKUP_DIR/${POSTGRES_DB}_${TIMESTAMP}.sql.gz"
REMOTE_URI="s3://$CLOUDFLARE_R2_BUCKET/$BACKUP_PREFIX/$(basename "$BACKUP_FILE")"

mkdir -p "$BACKUP_DIR"
cd "$APP_DIR"

echo "[$(date -u --iso-8601=seconds)] Generando backup $BACKUP_FILE"
docker compose -f compose.production.yml --env-file "$ENV_FILE" exec -T db \
  pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" | gzip -9 > "$BACKUP_FILE"

echo "[$(date -u --iso-8601=seconds)] Subiendo backup a $REMOTE_URI"
AWS_ACCESS_KEY_ID="$CLOUDFLARE_ACCESS_KEY_ID" \
AWS_SECRET_ACCESS_KEY="$CLOUDFLARE_SECRET_ACCESS_KEY" \
aws s3 cp "$BACKUP_FILE" "$REMOTE_URI" --endpoint-url "$CLOUDFLARE_R2_ENDPOINT"

rm -f "$BACKUP_FILE"

CUTOFF_EPOCH="$(date -u -d "$RETENTION_DAYS days ago" +%s)"
echo "[$(date -u --iso-8601=seconds)] Eliminando backups remotos con mas de $RETENTION_DAYS dias"
AWS_ACCESS_KEY_ID="$CLOUDFLARE_ACCESS_KEY_ID" \
AWS_SECRET_ACCESS_KEY="$CLOUDFLARE_SECRET_ACCESS_KEY" \
aws s3 ls "s3://$CLOUDFLARE_R2_BUCKET/$BACKUP_PREFIX/" --endpoint-url "$CLOUDFLARE_R2_ENDPOINT" |
while read -r backup_date backup_time _backup_size backup_name; do
  [[ -z "${backup_name:-}" || "$backup_date" == "PRE" ]] && continue

  backup_epoch="$(date -u -d "$backup_date $backup_time" +%s)"
  if (( backup_epoch < CUTOFF_EPOCH )); then
    AWS_ACCESS_KEY_ID="$CLOUDFLARE_ACCESS_KEY_ID" \
    AWS_SECRET_ACCESS_KEY="$CLOUDFLARE_SECRET_ACCESS_KEY" \
    aws s3 rm "s3://$CLOUDFLARE_R2_BUCKET/$BACKUP_PREFIX/$backup_name" --endpoint-url "$CLOUDFLARE_R2_ENDPOINT"
  fi
done

echo "[$(date -u --iso-8601=seconds)] Backup finalizado"
