#!/usr/bin/env sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
readonly PROJECT_ROOT
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly ENV_EXAMPLE_FILE="${PROJECT_ROOT}/.env.example"
readonly LOG_FILE="${PROJECT_ROOT}/var/log/full-install-nginx-fpm.log"
readonly DEMO_DOMAIN="localhost:${NGINX_HTTP_PORT:-8081}"
readonly ADMIN_EMAIL="admin@example.com"
readonly ADMIN_PASSWORD="Nginx-FPM-Demo-2026!"
readonly APP_DIR="${PROJECT_ROOT}/prestashop-nginx"
readonly PARAMETERS_FILE="${APP_DIR}/app/config/parameters.php"
readonly INSTALL_DIR="${APP_DIR}/install"

mkdir -p "${PROJECT_ROOT}/var/log"

if [ ! -f "$ENV_FILE" ]; then
	cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"
fi

PRESTASHOP_APP_DIR="$APP_DIR" "${PROJECT_ROOT}/scripts/install-prestashop.sh"

docker compose -p frankenphp-prestashop-nginx -f "${PROJECT_ROOT}/compose.nginx.yaml" config >/dev/null
docker compose -p frankenphp-prestashop-nginx -f "${PROJECT_ROOT}/compose.nginx.yaml" up -d --build

if [ ! -f "$PARAMETERS_FILE" ] || [ -d "$INSTALL_DIR" ]; then
	docker compose -p frankenphp-prestashop-nginx -f "${PROJECT_ROOT}/compose.nginx.yaml" exec -T fpm sh -lc 'rm -rf var/cache/prod var/cache/dev && rm -f app/config/parameters.yml'

	docker compose -p frankenphp-prestashop-nginx -f "${PROJECT_ROOT}/compose.nginx.yaml" exec -T fpm \
		php install/index_cli.php \
		--domain="$DEMO_DOMAIN" \
		--db_server=database \
		--db_name=prestashop \
		--db_user=prestashop \
		--db_password=prestashop \
		--prefix=ps_ \
		--name='Nginx FPM PrestaShop' \
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
fi

docker compose -p frankenphp-prestashop-nginx -f "${PROJECT_ROOT}/compose.nginx.yaml" exec -T fpm sh -lc 'rm -rf install var/cache/prod var/cache/dev'
docker compose -p frankenphp-prestashop-nginx -f "${PROJECT_ROOT}/compose.nginx.yaml" exec -T fpm \
	sh /usr/local/bin/ensure-prestashop-permissions

admin_path="$(find "$APP_DIR" -maxdepth 1 -type d -name 'admin*' ! -name 'admin-api' -printf '%f\n' | sort | head -1)"
printf 'Front office: http://%s/\n' "$DEMO_DOMAIN"
printf 'Back office: http://%s/%s/index.php\n' "$DEMO_DOMAIN" "$admin_path"
printf 'Admin email: %s\n' "$ADMIN_EMAIL"
printf 'Admin password: %s\n' "$ADMIN_PASSWORD"
