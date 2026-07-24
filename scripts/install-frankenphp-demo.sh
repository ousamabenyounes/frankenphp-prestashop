#!/usr/bin/env sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
readonly PROJECT_ROOT
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly ENV_EXAMPLE_FILE="${PROJECT_ROOT}/.env.example"
readonly LOG_FILE="${PROJECT_ROOT}/var/log/full-install-frankenphp.log"
readonly DEMO_DOMAIN="localhost:8080"
readonly ADMIN_EMAIL="admin@example.com"
readonly ADMIN_PASSWORD="FrankenPHP-Demo-2026!"

mkdir -p "${PROJECT_ROOT}/var/log"

if [ ! -f "$ENV_FILE" ]; then
	cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"
fi

"${PROJECT_ROOT}/scripts/install-prestashop.sh"

docker compose -f "${PROJECT_ROOT}/compose.yaml" config >/dev/null
docker compose -f "${PROJECT_ROOT}/compose.yaml" up -d --build
docker compose -f "${PROJECT_ROOT}/compose.yaml" exec -T php sh -lc 'rm -rf var/cache/prod var/cache/dev && rm -f app/config/parameters.yml'

docker compose -f "${PROJECT_ROOT}/compose.yaml" exec -T php \
	frankenphp php-cli install/index_cli.php \
	--domain="$DEMO_DOMAIN" \
	--db_server=database \
	--db_name=prestashop \
	--db_user=prestashop \
	--db_password=prestashop \
	--prefix=ps_ \
	--name='FrankenPHP PrestaShop' \
	--email="$ADMIN_EMAIL" \
	--password="$ADMIN_PASSWORD" \
	--firstname=Demo \
	--lastname=Admin \
	--language=en \
	--country=fr \
	--timezone=UTC \
	--ssl=0 \
	--rewrite=1 \
	--fixtures=1 > "$LOG_FILE" 2>&1

docker compose -f "${PROJECT_ROOT}/compose.yaml" exec -T php sh -lc 'rm -rf install var/cache/prod var/cache/dev'

admin_path="$(find "${PROJECT_ROOT}/prestashop" -maxdepth 1 -type d -name 'admin*' -printf '%f\n' | sort | head -1)"
printf 'Front office: http://%s/\n' "$DEMO_DOMAIN"
printf 'Back office: http://%s/%s/index.php\n' "$DEMO_DOMAIN" "$admin_path"
printf 'Admin email: %s\n' "$ADMIN_EMAIL"
printf 'Admin password: %s\n' "$ADMIN_PASSWORD"

