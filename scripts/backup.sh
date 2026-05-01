#!/usr/bin/env bash
# HRMS — резервная копия БД + загруженных файлов.
# Запуск из docker-compose окружения:
#   ./scripts/backup.sh                    # → ./backups/hrms-YYYY-MM-DD-HHMMSS.tar.gz
#   ./scripts/backup.sh /var/backups/hrms  # → /var/backups/hrms/hrms-...tar.gz
#
# Восстановление: scripts/restore.sh <archive>
#
# Cron (ежедневно в 3:00):
#   0 3 * * * cd /path/to/hrms && ./scripts/backup.sh /var/backups/hrms >> /var/log/hrms-backup.log 2>&1

set -euo pipefail

BACKUP_DIR="${1:-./backups}"
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
ARCHIVE="${BACKUP_DIR}/hrms-${TIMESTAMP}.tar.gz"
WORK_DIR=$(mktemp -d)

mkdir -p "${BACKUP_DIR}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

cleanup() { rm -rf "${WORK_DIR}"; }
trap cleanup EXIT

log() { echo -e "${GREEN}▶${RESET} $*"; }
err() { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }

# ── 1. PostgreSQL dump ─────────────────────────────────────────────────────
log "Делаю pg_dump"
if command -v docker >/dev/null 2>&1 && docker compose ps db --format json 2>/dev/null | grep -q running; then
  # Через docker compose
  docker compose exec -T db pg_dump -U hrms -d hrms_production --clean --if-exists \
    > "${WORK_DIR}/database.sql" || err "pg_dump упал"
else
  # Прямой psql если БД на host'е
  : "${DATABASE_URL:?DATABASE_URL не задан и docker-БД не активна}"
  pg_dump "${DATABASE_URL}" --clean --if-exists > "${WORK_DIR}/database.sql"
fi
DB_SIZE=$(du -h "${WORK_DIR}/database.sql" | cut -f1)
log "БД: ${DB_SIZE}"

# ── 2. Active Storage (загруженные файлы) ─────────────────────────────────
if [ -d "storage" ]; then
  log "Архивирую storage/ (Active Storage uploads)"
  tar -czf "${WORK_DIR}/storage.tar.gz" storage/ 2>/dev/null || true
  STORAGE_SIZE=$(du -h "${WORK_DIR}/storage.tar.gz" 2>/dev/null | cut -f1 || echo "0")
  log "Storage: ${STORAGE_SIZE}"
elif command -v docker >/dev/null 2>&1; then
  log "Копирую storage из app-контейнера"
  CONTAINER=$(docker compose ps -q app 2>/dev/null || echo "")
  if [ -n "${CONTAINER}" ]; then
    docker cp "${CONTAINER}:/rails/storage" "${WORK_DIR}/storage" 2>/dev/null || log "storage пуст или нет"
    [ -d "${WORK_DIR}/storage" ] && tar -czf "${WORK_DIR}/storage.tar.gz" -C "${WORK_DIR}" storage/
  fi
fi

# ── 3. config/master.key и schema.rb (для восстановления) ────────────────
[ -f "config/master.key" ] && cp config/master.key "${WORK_DIR}/master.key"
[ -f "db/schema.rb" ]      && cp db/schema.rb "${WORK_DIR}/schema.rb"

# ── 4. Метаданные ─────────────────────────────────────────────────────────
cat > "${WORK_DIR}/manifest.txt" <<EOF
HRMS backup
created_at: ${TIMESTAMP}
hostname: $(hostname)
git_sha: $(git rev-parse HEAD 2>/dev/null || echo "no-git")
ruby_version: $(ruby -v 2>/dev/null || echo "n/a")
contains:
  - database.sql ($(du -h ${WORK_DIR}/database.sql | cut -f1))
  - storage.tar.gz (если есть Active Storage uploads)
  - master.key (для расшифровки credentials)
  - schema.rb (для верификации миграций)
EOF

# ── 5. Финальный архив ────────────────────────────────────────────────────
tar -czf "${ARCHIVE}" -C "${WORK_DIR}" .
chmod 600 "${ARCHIVE}"
ARCHIVE_SIZE=$(du -h "${ARCHIVE}" | cut -f1)

log "Бэкап готов: ${ARCHIVE} (${ARCHIVE_SIZE})"

# ── 6. Ротация: оставляем 30 последних ──────────────────────────────────
RETAIN="${HRMS_BACKUP_RETAIN:-30}"
if [ -d "${BACKUP_DIR}" ]; then
  TO_DELETE=$(ls -1t "${BACKUP_DIR}"/hrms-*.tar.gz 2>/dev/null | tail -n +$((RETAIN + 1)))
  if [ -n "${TO_DELETE}" ]; then
    echo -e "${YELLOW}Удаляю старые бэкапы (>${RETAIN}):${RESET}"
    echo "${TO_DELETE}" | xargs -r rm -v
  fi
fi
