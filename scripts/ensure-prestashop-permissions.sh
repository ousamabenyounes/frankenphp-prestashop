#!/usr/bin/env sh
set -eu

readonly DEFAULT_APP_DIR="/app"
readonly APP_DIR="${PRESTASHOP_APP_DIR:-$DEFAULT_APP_DIR}"
readonly WEB_USER="${PRESTASHOP_WEB_USER:-www-data}"
readonly WEB_GROUP="${PRESTASHOP_WEB_GROUP:-www-data}"

if [ ! -f "${APP_DIR}/index.php" ]; then
	printf 'PrestaShop index.php not found in %s\n' "$APP_DIR" >&2
	exit 1
fi

for writable_path in \
	"app/config" \
	"download" \
	"img" \
	"modules" \
	"themes" \
	"translations" \
	"upload" \
	"var"; do
	if [ -e "${APP_DIR}/${writable_path}" ]; then
		chown -R "${WEB_USER}:${WEB_GROUP}" "${APP_DIR}/${writable_path}"
	fi
done

printf 'PrestaShop writable paths are owned by %s:%s in %s\n' "$WEB_USER" "$WEB_GROUP" "$APP_DIR"
