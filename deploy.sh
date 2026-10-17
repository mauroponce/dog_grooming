#!/usr/bin/env bash
set -euo pipefail

# Deploy production from the server itself.
#
# First run, from your local machine:
#   scp deploy.sh citapet_production:/opt/cita.pet/dog_grooming/deploy.sh
#   ssh citapet_production 'cd /opt/cita.pet/dog_grooming && chmod +x deploy.sh && ./deploy.sh'
#
# Later deploys:
#   ssh citapet_production 'cd /opt/cita.pet/dog_grooming && ./deploy.sh'
#
# Emergency-only backup opt-out:
#   ssh citapet_production 'cd /opt/cita.pet/dog_grooming && RUN_BACKUP=0 ./deploy.sh'

APP_DIR="${APP_DIR:-/opt/cita.pet/dog_grooming}"
BRANCH="${BRANCH:-main}"
REVISION="${REVISION:-}"
GIT_REMOTE_URL="${GIT_REMOTE_URL:-git@github.com:mauroponce/dog_grooming.git}"
RUN_BACKUP="${RUN_BACKUP:-1}"

cd "$APP_DIR"

if ! command -v git >/dev/null 2>&1; then
  echo "git is not installed on this server."
  echo "Install it first, for example: apt-get update && apt-get install -y git"
  exit 1
fi

if ! git config --global --get-all safe.directory | grep -Fxq "$APP_DIR"; then
  git config --global --add safe.directory "$APP_DIR"
fi

if [ ! -f ".env.production" ]; then
  echo "Missing $APP_DIR/.env.production. Aborting to avoid booting without production secrets."
  exit 1
fi

dotenv_value() {
  local key="$1"
  local line value

  line="$(grep -m 1 -E "^[[:space:]]*(export[[:space:]]+)?${key}[[:space:]]*=" .env.production || true)"
  value="${line#*=}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  if [[ ${#value} -ge 2 ]] && { [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]] || [[ "${value:0:1}" == "'" && "${value: -1}" == "'" ]]; }; then
    value="${value:1:${#value}-2}"
  fi
  printf '%s' "$value"
}

APP_HOST="${APP_HOST:-$(dotenv_value APP_HOST)}"
APP_HOST="${APP_HOST:-cita.pet}"
APP_PROTOCOL="${APP_PROTOCOL:-$(dotenv_value APP_PROTOCOL)}"
APP_PROTOCOL="${APP_PROTOCOL:-https}"
APP_BASE_URL="${APP_BASE_URL:-${APP_PROTOCOL}://${APP_HOST}}"

if [ ! -d ".git" ]; then
  echo "Bootstrapping git checkout in $APP_DIR..."
  git init
  git remote add origin "$GIT_REMOTE_URL"
  git fetch --depth=1 origin "${REVISION:-$BRANCH}"
  git clean -fd -e .env -e .env.production -e '.env.production.bak.*' -e log/ -e tmp/ -e storage/
  if [ -n "$REVISION" ]; then
    git checkout --detach FETCH_HEAD
  else
    git reset --hard "origin/$BRANCH"
    git checkout -B "$BRANCH" "origin/$BRANCH"
  fi
else
  echo "Updating git checkout..."
  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$GIT_REMOTE_URL"
  else
    git remote add origin "$GIT_REMOTE_URL"
  fi
  git fetch origin "${REVISION:-$BRANCH}"

  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    echo "Completing bootstrap over existing untracked rsync files..."
    git clean -fd -e .env -e .env.production -e '.env.production.bak.*' -e log/ -e tmp/ -e storage/
    if [ -n "$REVISION" ]; then
      git checkout --detach FETCH_HEAD
    else
      git reset --hard "origin/$BRANCH"
      git checkout -B "$BRANCH" "origin/$BRANCH"
    fi
  else
    if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
      echo "Tracked files have local changes. Aborting instead of overwriting production files."
      git status --short
      exit 1
    fi

    if [ -n "$REVISION" ]; then
      git checkout --detach FETCH_HEAD
    else
      git checkout "$BRANCH" || git checkout -B "$BRANCH" "origin/$BRANCH"
      git pull --ff-only origin "$BRANCH"
    fi
  fi
fi

echo "Deploying revision $(git rev-parse HEAD)"

COMPOSE=(docker compose -f compose.production.yml --env-file .env.production)

wait_for_url() {
  local label="$1"
  local url="$2"
  local attempts="${HEALTHCHECK_RETRIES:-30}"
  local sleep_seconds="${HEALTHCHECK_SLEEP:-2}"
  local attempt=1
  local code

  while [ "$attempt" -le "$attempts" ]; do
    if code="$(curl --connect-timeout 5 --max-time 10 -sS -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)" &&
      [ "${code:-000}" -ge 200 ] &&
      [ "${code:-000}" -lt 400 ]; then
      echo "${label}=${code}"
      return 0
    fi

    echo "${label} pending (${attempt}/${attempts}, last=${code:-000})"
    sleep "$sleep_seconds"
    attempt=$((attempt + 1))
  done

  echo "${label}=failed last=${code:-000}" >&2
  return 1
}

"${COMPOSE[@]}" config --quiet
"${COMPOSE[@]}" up -d db
if [ "$RUN_BACKUP" = "1" ]; then
  echo "Running production backup..."
  /bin/bash "$APP_DIR/ops/backup_postgres.sh"
else
  echo "WARNING: production backup skipped because RUN_BACKUP=0."
fi
"${COMPOSE[@]}" build web
"${COMPOSE[@]}" run --rm web bin/rails citapet:production_preflight
"${COMPOSE[@]}" run --rm web bin/deploy_migrate
"${COMPOSE[@]}" up -d --remove-orphans
"${COMPOSE[@]}" exec -T caddy caddy reload --config /etc/caddy/Caddyfile
"${COMPOSE[@]}" ps
"${COMPOSE[@]}" logs --tail=120 web

wait_for_url health "$APP_BASE_URL/up"
wait_for_url login "$APP_BASE_URL/acceder"
wait_for_url home "$APP_BASE_URL/"
