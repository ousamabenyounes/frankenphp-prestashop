#!/usr/bin/env sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

readonly CADDYFILE_PATH="${PROJECT_ROOT}/Caddyfile"
readonly COMPOSE_PATH="${PROJECT_ROOT}/compose.yaml"
readonly NGINX_COMPOSE_PATH="${PROJECT_ROOT}/compose.nginx.yaml"
readonly DOCKERFILE_PATH="${PROJECT_ROOT}/Dockerfile"
readonly FPM_DOCKERFILE_PATH="${PROJECT_ROOT}/Dockerfile.fpm"
readonly NGINX_CONFIG_PATH="${PROJECT_ROOT}/docker/nginx/default.conf"
readonly PHP_INI_PATH="${PROJECT_ROOT}/docker/php/conf/prestashop.ini"
readonly ENV_EXAMPLE_PATH="${PROJECT_ROOT}/.env.example"
readonly README_PATH="${PROJECT_ROOT}/README.md"
readonly BENCHMARK_DOC_PATH="${PROJECT_ROOT}/docs/benchmark.md"
readonly PRODUCTION_DOC_PATH="${PROJECT_ROOT}/docs/production.md"
readonly CI_WORKFLOW_PATH="${PROJECT_ROOT}/.github/workflows/ci.yaml"
readonly E2E_WORKFLOW_PATH="${PROJECT_ROOT}/.github/workflows/e2e.yaml"
readonly VERIFY_SHOP_SCRIPT_PATH="${PROJECT_ROOT}/scripts/verify-local-shop.sh"

readonly FRANKENPHP_IMAGE="dunglas/frankenphp:1.12.5-php8.4-bookworm"
readonly MARIADB_IMAGE="mariadb:11.4.7"
readonly REDIS_IMAGE="redis:7.2.5-alpine"
readonly MAILPIT_IMAGE="axllent/mailpit:v1.27.8"
readonly PRESTASHOP_VERSION="9.1.4"
readonly PHP_FPM_IMAGE="php:8.4-fpm-bookworm"
readonly NGINX_IMAGE="nginx:1.27.5-bookworm"
readonly PHP_EXTENSION_INSTALLER_IMAGE="mlocati/php-extension-installer:2.11.12"

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
require_file "$NGINX_COMPOSE_PATH"
require_file "$DOCKERFILE_PATH"
require_file "$FPM_DOCKERFILE_PATH"
require_file "$NGINX_CONFIG_PATH"
require_file "$PHP_INI_PATH"
require_file "$ENV_EXAMPLE_PATH"
require_file "$README_PATH"
require_file "$BENCHMARK_DOC_PATH"
require_file "$PRODUCTION_DOC_PATH"
require_file "$CI_WORKFLOW_PATH"
require_file "$E2E_WORKFLOW_PATH"
require_file "$VERIFY_SHOP_SCRIPT_PATH"

require_contains "$DOCKERFILE_PATH" "ARG FRANKENPHP_IMAGE=${FRANKENPHP_IMAGE}"
require_contains "$DOCKERFILE_PATH" 'FROM ${FRANKENPHP_IMAGE}'
require_contains "$COMPOSE_PATH" "image: ${MARIADB_IMAGE}"
require_contains "$COMPOSE_PATH" "image: ${REDIS_IMAGE}"
require_contains "$COMPOSE_PATH" "image: ${MAILPIT_IMAGE}"
require_contains "$NGINX_COMPOSE_PATH" "image: ${NGINX_IMAGE}"
require_contains "$NGINX_COMPOSE_PATH" "image: ${MARIADB_IMAGE}"
require_contains "$NGINX_COMPOSE_PATH" "image: ${REDIS_IMAGE}"
require_contains "$NGINX_COMPOSE_PATH" "image: ${MAILPIT_IMAGE}"
require_contains "$FPM_DOCKERFILE_PATH" "FROM ${PHP_FPM_IMAGE}"
require_contains "$FPM_DOCKERFILE_PATH" "COPY --from=${PHP_EXTENSION_INSTALLER_IMAGE}"
require_contains "$ENV_EXAMPLE_PATH" "PRESTASHOP_VERSION=${PRESTASHOP_VERSION}"

require_contains "$CADDYFILE_PATH" "root * /app"
require_contains "$CADDYFILE_PATH" "encode zstd br gzip"
require_contains "$CADDYFILE_PATH" "php_server"
require_contains "$CADDYFILE_PATH" "@blockedFiles"
require_contains "$CADDYFILE_PATH" "@blockedDirectories"
require_contains "$CADDYFILE_PATH" "respond @blockedFiles 404"
require_contains "$CADDYFILE_PATH" "respond @blockedDirectories 404"
require_contains "$CADDYFILE_PATH" "@webserviceApi path_regexp webserviceApi"
require_contains "$CADDYFILE_PATH" "@productImage7 path_regexp productImage7"
require_contains "$CADDYFILE_PATH" "@numericCategoryImage path_regexp numericCategoryImage"
require_contains "$CADDYFILE_PATH" "@alphaCategoryImage path_regexp alphaCategoryImage"
require_contains "$CADDYFILE_PATH" "try_files {path} /index.php"
require_contains "$NGINX_CONFIG_PATH" 'try_files $uri /index.php$is_args$args'
require_contains "$NGINX_CONFIG_PATH" "?<path_info>"
require_contains "$NGINX_CONFIG_PATH" 'fastcgi_param PATH_INFO $path_info'
require_contains "$NGINX_CONFIG_PATH" "fastcgi_pass fpm:9000"

require_contains "$PHP_INI_PATH" "expose_php = 0"
require_contains "$PHP_INI_PATH" "session.use_strict_mode = 1"
require_contains "$PHP_INI_PATH" "memory_limit = 512M"
require_contains "$PHP_INI_PATH" "opcache.enable=1"

require_contains "$README_PATH" "Security Checks"
require_contains "$README_PATH" "Smoke Validation"
require_contains "$README_PATH" "Production Notes"
require_contains "$README_PATH" "PrestaShop 9.1.4"
require_contains "$README_PATH" "actions/workflows/ci.yaml/badge.svg"
require_contains "$README_PATH" "actions/workflows/e2e.yaml/badge.svg"
require_contains "$README_PATH" "Mailpit"
require_contains "$BENCHMARK_DOC_PATH" "p50"
require_contains "$BENCHMARK_DOC_PATH" "p95"
require_contains "$BENCHMARK_DOC_PATH" "p99"
require_contains "$BENCHMARK_DOC_PATH" "Benchmark Parity"
require_contains "$PRODUCTION_DOC_PATH" "Persistent Data"
require_contains "$PRODUCTION_DOC_PATH" "Trusted Proxies"
require_contains "$CI_WORKFLOW_PATH" "Test Nginx PATH_INFO routing"
require_contains "$CI_WORKFLOW_PATH" "Test benchmark summary"
require_contains "$E2E_WORKFLOW_PATH" "workflow_dispatch"
require_contains "$E2E_WORKFLOW_PATH" "Verify FrankenPHP demo shop"

require_absent "$COMPOSE_PATH" ":latest"
require_absent "$NGINX_COMPOSE_PATH" ":latest"
require_absent "$DOCKERFILE_PATH" ":latest"
require_absent "$FPM_DOCKERFILE_PATH" ":latest"
require_absent "$README_PATH" ":latest"
require_absent "$E2E_WORKFLOW_PATH" "@main"
require_absent "$E2E_WORKFLOW_PATH" "@master"

printf 'PrestaShop FrankenPHP skeleton smoke config passed.\n'
