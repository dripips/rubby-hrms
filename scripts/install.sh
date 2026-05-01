#!/usr/bin/env bash
# HRMS — авто-установщик через Docker. Запуск:
#   curl -fsSL https://raw.githubusercontent.com/dripips/hrms/main/scripts/install.sh | bash
# либо локально:
#   ./scripts/install.sh
#
# Что делает:
#  1. Проверяет docker и docker compose
#  2. Создаёт .env с генерацией случайных секретов
#  3. Билдит контейнер
#  4. Поднимает stack (db + app + worker)
#  5. Создаёт первого superadmin'а
#  6. Печатает URL и логин

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

log()  { echo -e "${GREEN}▶${RESET} $*"; }
warn() { echo -e "${YELLOW}⚠${RESET} $*"; }
err()  { echo -e "${RED}✗${RESET} $*" >&2; exit 1; }

# ── 1. Проверка зависимостей ──────────────────────────────────────────────
log "Проверяю Docker"
command -v docker >/dev/null 2>&1 || err "Docker не установлен. Скачай: https://docs.docker.com/get-docker/"
docker compose version >/dev/null 2>&1 || err "Docker Compose v2 не найден. Обнови Docker."

# ── 2. .env с секретами ───────────────────────────────────────────────────
if [ -f .env ]; then
  warn ".env уже существует — пропускаю генерацию. Удали его если хочешь свежий."
else
  log "Генерирую .env"
  RAILS_KEY=$(docker run --rm ruby:3-slim ruby -rsecurerandom -e 'puts SecureRandom.hex(64)')
  PG_PASS=$(docker run --rm ruby:3-slim ruby -rsecurerandom -e 'puts SecureRandom.alphanumeric(24)')
  cat > .env <<EOF
RAILS_MASTER_KEY=${RAILS_KEY}
POSTGRES_PASSWORD=${PG_PASS}
APP_HOST=localhost:3000
APP_PORT=3000
POSTGRES_PORT=5432
EOF
  log ".env создан с случайными секретами"
fi

# config/master.key должен совпадать с RAILS_MASTER_KEY
if [ ! -f config/master.key ]; then
  source .env
  echo "${RAILS_MASTER_KEY}" > config/master.key
  chmod 600 config/master.key
  log "config/master.key синхронизирован с .env"
fi

# ── 3. Build образа ───────────────────────────────────────────────────────
log "Билжу Docker-образ (займёт 5-10 мин при первом запуске)"
docker compose build

# ── 4. Запуск ─────────────────────────────────────────────────────────────
log "Запускаю db + app + worker"
docker compose up -d

# Ждём готовности базы и web
log "Ждём готовности приложения (до 60с)"
for i in {1..60}; do
  if docker compose exec -T app curl -sf http://localhost:80/up >/dev/null 2>&1; then
    log "Приложение отвечает"
    break
  fi
  sleep 1
done

# ── 5. Seed данных + superadmin ──────────────────────────────────────────
log "Создаю первого superadmin'а"
docker compose exec -T app bin/rails runner '
  if User.where(role: "superadmin").any?
    puts "[skip] superadmin уже существует"
  else
    require "securerandom"
    pass = ENV["ADMIN_PASSWORD"].presence || SecureRandom.alphanumeric(16)
    company = Company.first_or_create!(name: "My Company", default_locale: "ru")
    user = User.create!(
      email: "admin@hrms.local",
      password: pass,
      password_confirmation: pass,
      role: "superadmin",
      company: company
    )
    File.write("/rails/tmp/admin_credentials.txt", "email: admin@hrms.local\npassword: #{pass}\n")
    puts "[ok] superadmin создан"
  end
'

if docker compose exec -T app test -f /rails/tmp/admin_credentials.txt; then
  CREDS=$(docker compose exec -T app cat /rails/tmp/admin_credentials.txt)
  echo
  echo "═══════════════════════════════════════════════════════════════"
  echo "  HRMS установлен!"
  echo
  echo "  URL:      http://localhost:3000"
  echo "  Доступы:"
  echo "${CREDS}" | sed 's/^/    /'
  echo
  echo "  ⚠ Сохрани пароль — он показывается один раз."
  echo "  Логи:     docker compose logs -f app"
  echo "  Стоп:     docker compose down"
  echo "  Бэкап:    docker compose exec db pg_dump -U hrms hrms_production > backup.sql"
  echo "═══════════════════════════════════════════════════════════════"
else
  warn "Креды superadmin'а не выведены — возможно был раньше создан. Проверь docker compose logs app."
  echo
  echo "URL: http://localhost:3000"
fi
