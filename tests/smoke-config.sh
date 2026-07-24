#!/usr/bin/env sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

readonly CADDYFILE_PATH="${PROJECT_ROOT}/Caddyfile"
readonly COMPOSE_PATH="${PROJECT_ROOT}/compose.yaml"
readonly DOCKERFILE_PATH="${PROJECT_ROOT}/Dockerfile"
readonly PHP_INI_PATH="${PROJECT_ROOT}/docker/php/conf/prestashop.ini"
readonly ENV_EXAMPLE_PATH="${PROJECT_ROOT}/.env.example"
readonly README_PATH="${PROJECT_ROOT}/README.md"

readonly FRANKENPHP_IMAGE="dunglas/frankenphp:1.12.5-php8.4-bookworm"
readonly MARIADB_IMAGE="mariadb:11.4.7"
readonly REDIS_IMAGE="redis:7.2.5-alpine"
readonly PRESTASHOP_VERSION="9.1.4"

require_file() {
	file_path="$1"

	if [ ! -f "$file_path" ]; then
		printf 'missing required file: %s\n' "$file_path" >&2
		exit 1
	fi
}

require_contains() {
	file_path="$1"
	expected_text="$2"

	if ! grep -Fq "$expected_text" "$file_path"; then
		printf 'missing expected text in %s: %s\n' "$file_path" "$expected_text" >&2
		exit 1
	fi
}

require_absent() {
	file_path="$1"
	forbidden_text="$2"

	if grep -Fq "$forbidden_text" "$file_path"; then
		printf 'forbidden floating reference in %s: %s\n' "$file_path" "$forbidden_text" >&2
		exit 1
	fi
}

require_file "$CADDYFILE_PATH"
require_file "$COMPOSE_PATH"
require_file "$DOCKERFILE_PATH"
require_file "$PHP_INI_PATH"
require_file "$ENV_EXAMPLE_PATH"
require_file "$README_PATH"

require_contains "$DOCKERFILE_PATH" "ARG FRANKENPHP_IMAGE=${FRANKENPHP_IMAGE}"
require_contains "$DOCKERFILE_PATH" 'FROM ${FRANKENPHP_IMAGE}'
require_contains "$COMPOSE_PATH" "image: ${MARIADB_IMAGE}"
require_contains "$COMPOSE_PATH" "image: ${REDIS_IMAGE}"
require_contains "$ENV_EXAMPLE_PATH" "PRESTASHOP_VERSION=${PRESTASHOP_VERSION}"

require_contains "$CADDYFILE_PATH" "root * /app"
require_contains "$CADDYFILE_PATH" "encode zstd br gzip"
require_contains "$CADDYFILE_PATH" "php_server"
require_contains "$CADDYFILE_PATH" "@blockedFiles"
require_contains "$CADDYFILE_PATH" "@blockedDirectories"
require_contains "$CADDYFILE_PATH" "respond @blockedFiles 404"
require_contains "$CADDYFILE_PATH" "respond @blockedDirectories 404"
require_contains "$CADDYFILE_PATH" "try_files {path} {path}/ /index.php"

require_contains "$PHP_INI_PATH" "expose_php = 0"
require_contains "$PHP_INI_PATH" "session.use_strict_mode = 1"
require_contains "$PHP_INI_PATH" "memory_limit = 512M"
require_contains "$PHP_INI_PATH" "opcache.enable=1"

require_contains "$README_PATH" "Security Checks"
require_contains "$README_PATH" "Smoke Validation"
require_contains "$README_PATH" "PrestaShop 9.1.4"

require_absent "$COMPOSE_PATH" ":latest"
require_absent "$DOCKERFILE_PATH" ":latest"
require_absent "$README_PATH" ":latest"

printf 'PrestaShop FrankenPHP skeleton smoke config passed.\n'
