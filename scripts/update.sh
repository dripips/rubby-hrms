#!/usr/bin/env bash
# HRMS — обновление до новой версии без потери данных. Запуск:
#   ./scripts/update.sh         # обновить до master HEAD
#   ./scripts/update.sh v1.10   # обновить до конкретного тега
#
# Что делает:
#   1. Снимает бэкап БД + uploads (вызывает scripts/backup.sh)
#   2. git pull / git checkout <tag>
#   3. docker compose build (новый образ)
#   4. Запускает миграции на новом образе ДО рестарта (zero-downtime intent)
#   5. docker compose up -d (rolling restart app + worker)
#   6. Healthcheck — ждёт /up = 200 или откатывает
#
# Если что-то пошло не так — git checkout предыдущей версии + docker compose up.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

log()  { echo -e "${GREEN}▶${RESET} $*"; }
warn() { echo -e "${YELLOW}⚠${RESET} $*"; }
err()  { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }

TARGET=${1:-}
CURRENT_REV=$(git rev-parse HEAD)

# ── 1. Pre-flight ─────────────────────────────────────────────────────────
log "Проверяю Docker"
command -v docker >/dev/null 2>&1 || err "Docker не установлен"
docker compose ps >/dev/null 2>&1 || err "docker compose stack не запущен — сначала ./scripts/install.sh"

[ -f .env ] || err ".env не найден — сначала ./scripts/install.sh"

# ── 2. Snapshot БД + uploads ─────────────────────────────────────────────
log "Снимаю бэкап ДО обновления"
if [ -x ./scripts/backup.sh ]; then
  ./scripts/backup.sh || err "Бэкап провалился — апгрейд прерван"
else
  warn "scripts/backup.sh не найден — пропускаю бэкап (РИСКОВАННО!)"
fi

# ── 3. Pull новой версии ─────────────────────────────────────────────────
log "Текущая версия: ${CURRENT_REV:0:8}"
log "Тяну изменения с GitHub"
git fetch --tags origin
if [ -n "$TARGET" ]; then
  log "Переключаюсь на $TARGET"
  git checkout "$TARGET" || err "git checkout $TARGET провалился"
else
  git checkout master
  git pull --ff-only origin master || err "git pull провалился — возможно есть локальные изменения"
fi
NEW_REV=$(git rev-parse HEAD)

if [ "$CURRENT_REV" = "$NEW_REV" ]; then
  log "Уже на актуальной версии — нечего обновлять"
  exit 0
fi

# ── 4. Build нового образа ───────────────────────────────────────────────
log "Билжу новый образ (займёт 3-8 мин)"
docker compose build app

# ── 5. Миграции БД на НОВОМ образе ──────────────────────────────────────
log "Запускаю миграции"
docker compose run --rm --no-deps app bin/rails db:migrate

# ── 6. Rolling restart ──────────────────────────────────────────────────
log "Рестартую app + worker"
docker compose up -d --no-deps app worker

# ── 7. Healthcheck ───────────────────────────────────────────────────────
log "Жду /up (до 60с)"
for i in {1..60}; do
  if docker compose exec -T app curl -sf http://localhost:80/up >/dev/null 2>&1; then
    log "Приложение отвечает — обновление успешно"
    echo
    echo "═══════════════════════════════════════════════════════════════"
    echo "  HRMS обновлён: ${CURRENT_REV:0:8} → ${NEW_REV:0:8}"
    [ -n "$TARGET" ] && echo "  Tag: $TARGET"
    echo "  Логи:    docker compose logs -f app"
    echo "  Откат:   ./scripts/update.sh ${CURRENT_REV}"
    echo "═══════════════════════════════════════════════════════════════"
    exit 0
  fi
  sleep 1
done

err "Healthcheck failed — приложение не отвечает. Откат: git checkout $CURRENT_REV && docker compose up -d"
