#!/usr/bin/env sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
readonly PROJECT_ROOT
readonly NGINX_IMAGE="nginx:1.27.5-bookworm"
readonly FPM_IMAGE="php:8.4-fpm-bookworm"
readonly CONTAINER_PORT="80"
readonly STARTUP_ATTEMPTS="30"
readonly STARTUP_DELAY_SECONDS="1"
readonly EXPECTED_OK_STATUS="200"
readonly ADMIN_DIR="adminpathinfotest"
readonly LOGIN_PATH="/login"

TEMP_DIR="$(mktemp -d)"
readonly TEMP_DIR
readonly APP_DIR="${TEMP_DIR}/app"
readonly NETWORK_NAME="frankenphp-prestashop-nginx-path-info-$$"
readonly FPM_CONTAINER_NAME="${NETWORK_NAME}-fpm"
readonly NGINX_CONTAINER_NAME="${NETWORK_NAME}-nginx"

cleanup() {
	docker rm -f "$NGINX_CONTAINER_NAME" "$FPM_CONTAINER_NAME" >/dev/null 2>&1 || true
	docker network rm "$NETWORK_NAME" >/dev/null 2>&1 || true
	rm -rf "$TEMP_DIR"
}

trap cleanup EXIT INT TERM

mkdir -p "${APP_DIR}/${ADMIN_DIR}"
cat > "${APP_DIR}/${ADMIN_DIR}/index.php" <<'EOF'
<?php
header('Content-Type: text/plain');
echo 'script=' . $_SERVER['SCRIPT_NAME'] . "\n";
echo 'path_info=' . ($_SERVER['PATH_INFO'] ?? '') . "\n";
echo 'request_uri=' . $_SERVER['REQUEST_URI'] . "\n";
EOF
cat > "${APP_DIR}/index.php" <<'EOF'
<?php
header('Content-Type: text/plain');
echo "front\n";
EOF

docker network create "$NETWORK_NAME" >/dev/null
docker run --rm --name "$FPM_CONTAINER_NAME" --network "$NETWORK_NAME" --network-alias fpm -d \
	-v "${APP_DIR}:/app:ro" \
	"$FPM_IMAGE" >/dev/null
docker run --rm --name "$NGINX_CONTAINER_NAME" --network "$NETWORK_NAME" -d \
	-v "${APP_DIR}:/app:ro" \
	-v "${PROJECT_ROOT}/docker/nginx/default.conf:/etc/nginx/conf.d/default.conf:ro" \
	-p "127.0.0.1::${CONTAINER_PORT}" \
	"$NGINX_IMAGE" >/dev/null

host_port="$(docker port "$NGINX_CONTAINER_NAME" "$CONTAINER_PORT/tcp" | sed 's/.*://')"
readonly BASE_URL="http://127.0.0.1:${host_port}"
readonly ADMIN_LOGIN_URL="${BASE_URL}/${ADMIN_DIR}/index.php${LOGIN_PATH}"

attempt="1"
while [ "$attempt" -le "$STARTUP_ATTEMPTS" ]; do
	status="$(curl -sS -o /dev/null -w '%{http_code}' "$BASE_URL/" 2>/dev/null || true)"
	if [ "$status" = "$EXPECTED_OK_STATUS" ]; then
		break
	fi

	sleep "$STARTUP_DELAY_SECONDS"
	attempt=$((attempt + 1))
done

if [ "$status" != "$EXPECTED_OK_STATUS" ]; then
	docker logs "$NGINX_CONTAINER_NAME" >&2 || true
	docker logs "$FPM_CONTAINER_NAME" >&2 || true
	printf 'Nginx PATH_INFO fixture did not become ready at %s\n' "$BASE_URL" >&2
	exit 1
fi

response="$(curl -sS "$ADMIN_LOGIN_URL")"

if ! printf '%s\n' "$response" | grep -Fq "script=/${ADMIN_DIR}/index.php"; then
	printf 'unexpected SCRIPT_NAME for admin PATH_INFO request\n%s\n' "$response" >&2
	exit 1
fi

if ! printf '%s\n' "$response" | grep -Fq "path_info=${LOGIN_PATH}"; then
	printf 'unexpected PATH_INFO for admin request\n%s\n' "$response" >&2
	exit 1
fi

printf 'Nginx PATH_INFO routing test passed.\n'
