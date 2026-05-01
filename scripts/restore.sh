#!/usr/bin/env bash
# HRMS — восстановление из backup-архива.
# Запуск: ./scripts/restore.sh ./backups/hrms-2026-05-01-150000.tar.gz
#
# ВНИМАНИЕ: затирает текущую БД и storage/. Только для prod-восстановления
# или dev-среды на чистую систему. Сначала спрашивает подтверждение.

set -euo pipefail

ARCHIVE="${1:-}"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'

log()  { echo -e "${GREEN}▶${RESET} $*"; }
warn() { echo -e "${YELLOW}⚠${RESET} $*"; }
err()  { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }

[ -n "${ARCHIVE}" ] && [ -f "${ARCHIVE}" ] || err "Использование: ./scripts/restore.sh <archive.tar.gz>"

WORK_DIR=$(mktemp -d)
cleanup() { rm -rf "${WORK_DIR}"; }
trap cleanup EXIT

log "Распаковываю ${ARCHIVE}"
tar -xzf "${ARCHIVE}" -C "${WORK_DIR}"

[ -f "${WORK_DIR}/database.sql" ] || err "В архиве нет database.sql"
[ -f "${WORK_DIR}/manifest.txt" ] && cat "${WORK_DIR}/manifest.txt" | sed 's/^/    /'

warn "Сейчас будет полное восстановление: БД и storage/ будут перезаписаны."
read -r -p "Продолжить? Введите YES: " CONFIRM
[ "${CONFIRM}" = "YES" ] || err "Отмена."

# ── БД ─────────────────────────────────────────────────────────────────────
log "Восстанавливаю БД"
if command -v docker >/dev/null 2>&1 && docker compose ps db --format json 2>/dev/null | grep -q running; then
  docker compose exec -T db psql -U hrms -d hrms_production < "${WORK_DIR}/database.sql"
else
  : "${DATABASE_URL:?DATABASE_URL не задан}"
  psql "${DATABASE_URL}" < "${WORK_DIR}/database.sql"
fi

# ── Storage ────────────────────────────────────────────────────────────────
if [ -f "${WORK_DIR}/storage.tar.gz" ]; then
  log "Восстанавливаю storage/"
  rm -rf storage
  tar -xzf "${WORK_DIR}/storage.tar.gz"
  if command -v docker >/dev/null 2>&1; then
    CONTAINER=$(docker compose ps -q app 2>/dev/null || echo "")
    if [ -n "${CONTAINER}" ]; then
      docker cp storage "${CONTAINER}:/rails/" 2>/dev/null || true
    fi
  fi
fi

# ── master.key ────────────────────────────────────────────────────────────
if [ -f "${WORK_DIR}/master.key" ]; then
  warn "Архив содержит master.key — НЕ перезаписываю автоматически. Ручное действие при необходимости."
fi

log "Восстановление завершено"
log "Не забудь перезапустить app: docker compose restart app worker"
