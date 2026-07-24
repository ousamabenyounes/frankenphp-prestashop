#!/usr/bin/env sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
readonly PROJECT_ROOT
readonly COMPOSE_FILE="${PROJECT_ROOT}/compose.yaml"
readonly NGINX_COMPOSE_FILE="${PROJECT_ROOT}/compose.nginx.yaml"
readonly CADDYFILE_PATH="${PROJECT_ROOT}/Caddyfile"
readonly ENV_FILE="${PROJECT_ROOT}/.env"
readonly ENV_EXAMPLE_FILE="${PROJECT_ROOT}/.env.example"
readonly VALIDATION_IMAGE="dunglas/frankenphp:1.12.5-php8.4-bookworm"

cleanup() {
	if [ "${CREATED_ENV_FILE:-0}" = "1" ]; then
		rm -f "$ENV_FILE"
	fi
}

trap cleanup EXIT INT TERM

"${PROJECT_ROOT}/tests/smoke-config.sh"

if command -v docker >/dev/null 2>&1; then
	if [ ! -f "$ENV_FILE" ]; then
		cp "$ENV_EXAMPLE_FILE" "$ENV_FILE"
		CREATED_ENV_FILE=1
	fi

	if docker compose version >/dev/null 2>&1; then
		docker compose --env-file "${PROJECT_ROOT}/.env.example" -f "$COMPOSE_FILE" config >/dev/null
		docker compose --env-file "${PROJECT_ROOT}/.env.example" -f "$NGINX_COMPOSE_FILE" config >/dev/null
	fi

	docker run --rm \
		-v "${CADDYFILE_PATH}:/etc/caddy/Caddyfile:ro" \
		"$VALIDATION_IMAGE" \
		frankenphp validate --config /etc/caddy/Caddyfile
fi

printf 'Skeleton validation passed.\n'
