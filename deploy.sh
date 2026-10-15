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
# Optional backup before deploy:
#   ssh citapet_production 'cd /opt/cita.pet/dog_grooming && RUN_BACKUP=1 ./deploy.sh'

APP_DIR="${APP_DIR:-/opt/cita.pet/dog_grooming}"
BRANCH="${BRANCH:-main}"
GIT_REMOTE_URL="${GIT_REMOTE_URL:-git@github.com:mauroponce/dog_grooming.git}"
RUN_BACKUP="${RUN_BACKUP:-0}"
BACKUP_COMMAND="${BACKUP_COMMAND:-/bin/bash $APP_DIR/ops/backup_postgres.sh}"
APP_HOST="${APP_HOST:-dog-grooming.example.com}"
APP_PROTOCOL="${APP_PROTOCOL:-https}"
APP_BASE_URL="${APP_BASE_URL:-${APP_PROTOCOL}://${APP_HOST}}"

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

if [ "$RUN_BACKUP" = "1" ]; then
  echo "Running production backup..."
  $BACKUP_COMMAND
else
  echo "Skipping backup. Set RUN_BACKUP=1 to enable it."
fi

if [ ! -d ".git" ]; then
  echo "Bootstrapping git checkout in $APP_DIR..."
  git init
  git remote add origin "$GIT_REMOTE_URL"
  git fetch --depth=1 origin "$BRANCH"
  git clean -fd -e .env -e .env.production -e '.env.production.bak.*' -e log/ -e tmp/ -e storage/
  git reset --hard "origin/$BRANCH"
  git checkout -B "$BRANCH" "origin/$BRANCH"
else
  echo "Updating git checkout..."
  if git remote get-url origin >/dev/null 2>&1; then
    git remote set-url origin "$GIT_REMOTE_URL"
  else
    git remote add origin "$GIT_REMOTE_URL"
  fi
  git fetch origin "$BRANCH"

  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    echo "Completing bootstrap over existing untracked rsync files..."
    git clean -fd -e .env -e .env.production -e '.env.production.bak.*' -e log/ -e tmp/ -e storage/
    git reset --hard "origin/$BRANCH"
    git checkout -B "$BRANCH" "origin/$BRANCH"
  else
    git checkout "$BRANCH" || git checkout -B "$BRANCH" "origin/$BRANCH"

    if [ -n "$(git status --porcelain --untracked-files=no)" ]; then
      echo "Tracked files have local changes. Aborting instead of overwriting production files."
      git status --short
      exit 1
    fi

    git pull --ff-only origin "$BRANCH"
  fi
fi

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
"${COMPOSE[@]}" build web
"${COMPOSE[@]}" run --rm web bin/deploy_migrate
if [ "${RESET_PRELAUNCH_DATA:-}" = "confirm-citapet-prelaunch" ]; then
  "${COMPOSE[@]}" stop web
  $BACKUP_COMMAND
  "${COMPOSE[@]}" run --rm -e RESET_PRELAUNCH_DATA=confirm-citapet-prelaunch web bin/rails citapet:reset_prelaunch
fi
"${COMPOSE[@]}" up -d --remove-orphans
"${COMPOSE[@]}" exec -T caddy caddy reload --config /etc/caddy/Caddyfile
"${COMPOSE[@]}" ps
"${COMPOSE[@]}" logs --tail=120 web

wait_for_url health "$APP_BASE_URL/up"
wait_for_url login "$APP_BASE_URL/acceder"
wait_for_url home "$APP_BASE_URL/"
