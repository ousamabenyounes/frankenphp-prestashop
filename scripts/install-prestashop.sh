#!/usr/bin/env sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
readonly PROJECT_ROOT
readonly ENV_EXAMPLE_FILE="${PROJECT_ROOT}/.env.example"
readonly APP_DIR="${PROJECT_ROOT}/prestashop"
readonly DOWNLOAD_DIR="${PROJECT_ROOT}/.download"
readonly PRESTASHOP_CLASSIC_VERSION="9.1.4-5.0"
readonly PRESTASHOP_ZIP="prestashop_${PRESTASHOP_CLASSIC_VERSION}.zip"
readonly PRESTASHOP_INNER_ZIP="prestashop.zip"
readonly PRESTASHOP_URL="https://github.com/PrestaShopCorp/prestashop-classic/releases/download/${PRESTASHOP_CLASSIC_VERSION}/${PRESTASHOP_ZIP}"
readonly PRESTASHOP_VERSION_LINE="PRESTASHOP_VERSION=9.1.4"

if ! grep -Fq "$PRESTASHOP_VERSION_LINE" "$ENV_EXAMPLE_FILE"; then
	printf 'unexpected PrestaShop version in %s; expected %s\n' "$ENV_EXAMPLE_FILE" "$PRESTASHOP_VERSION_LINE" >&2
	exit 1
fi

if [ -e "$APP_DIR/index.php" ]; then
	printf 'PrestaShop already appears to be installed in %s\n' "$APP_DIR"
	exit 0
fi

mkdir -p "$APP_DIR" "$DOWNLOAD_DIR"

if [ ! -f "${DOWNLOAD_DIR}/${PRESTASHOP_ZIP}" ]; then
	curl -fL --retry 3 --retry-delay 2 \
		-o "${DOWNLOAD_DIR}/${PRESTASHOP_ZIP}" \
		"$PRESTASHOP_URL"
fi

unzip -oq "${DOWNLOAD_DIR}/${PRESTASHOP_ZIP}" -d "$APP_DIR"

if [ -f "${APP_DIR}/${PRESTASHOP_INNER_ZIP}" ]; then
	unzip -oq "${APP_DIR}/${PRESTASHOP_INNER_ZIP}" -d "$APP_DIR"
	rm -f "${APP_DIR}/${PRESTASHOP_INNER_ZIP}"
fi

if [ ! -f "${APP_DIR}/index.php" ]; then
	printf 'downloaded archive did not create expected %s/index.php\n' "$APP_DIR" >&2
	exit 1
fi

printf 'PrestaShop %s extracted to %s\n' "$PRESTASHOP_CLASSIC_VERSION" "$APP_DIR"
