#!/usr/bin/env sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
readonly PROJECT_ROOT
readonly CADDYFILE_UNDER_TEST="${CADDYFILE_UNDER_TEST:-${PROJECT_ROOT}/Caddyfile}"
readonly TEST_IMAGE="dunglas/frankenphp:1.12.5-php8.4-bookworm"
readonly CONTAINER_PORT="8080"
readonly STARTUP_ATTEMPTS="30"
readonly STARTUP_DELAY_SECONDS="1"
readonly EXPECTED_NOT_FOUND="404"
readonly EXPECTED_OK="200"
readonly EXPECTED_NO_CONTENT="204"
readonly CACHE_HEADER_NAME="Cache-Control"
readonly STATIC_CACHE_VALUE="public, max-age=31536000, immutable"
readonly MUTABLE_CACHE_VALUE="no-store"
readonly READY_PATH="/themes/classic/assets/theme.css"
readonly PRODUCT_IMAGE_RESPONSE="product image"
readonly CATEGORY_IMAGE_RESPONSE="category image"
readonly ALPHA_CATEGORY_IMAGE_RESPONSE="alpha category image"
readonly LEGACY_FANCYBOX_RESPONSE="legacy fancybox image"
readonly API_DISPATCHER_RESPONSE="api:"

TEMP_DIR="$(mktemp -d)"
readonly TEMP_DIR
readonly APP_DIR="${TEMP_DIR}/app"
readonly CONTAINER_NAME="frankenphp-prestashop-routing-$$"

cleanup() {
	docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
	rm -rf "$TEMP_DIR"
}

trap cleanup EXIT INT TERM

write_fixture() {
	mkdir -p \
		"${APP_DIR}/config" \
		"${APP_DIR}/img/c" \
		"${APP_DIR}/img/p/1/2/3" \
		"${APP_DIR}/js/jquery/plugins/fancybox/images" \
		"${APP_DIR}/var/logs" \
		"${APP_DIR}/vendor" \
		"${APP_DIR}/webservice" \
		"${APP_DIR}/themes/classic/assets"

	printf '%s\n' '<?php header("Content-Type: text/plain"); echo "fallback:" . $_SERVER["REQUEST_URI"];' > "${APP_DIR}/index.php"
	printf '%s\n' "<?php header('Content-Type: text/plain'); echo '${API_DISPATCHER_RESPONSE}' . \$_GET['url'];" > "${APP_DIR}/webservice/dispatcher.php"
	printf '%s\n' 'APP_SECRET=must-not-leak' > "${APP_DIR}/.env"
	printf '%s\n' '{"autoload":{}}' > "${APP_DIR}/composer.json"
	printf '%s\n' '<?php echo "config leak";' > "${APP_DIR}/config/settings.inc.php"
	printf '%s\n' '<?php echo "vendor leak";' > "${APP_DIR}/vendor/autoload.php"
	printf '%s\n' 'sensitive log' > "${APP_DIR}/var/logs/prod.log"
	printf '%s\n' 'body{color:#111}' > "${APP_DIR}/themes/classic/assets/theme.css"
	printf '%s\n' "$PRODUCT_IMAGE_RESPONSE" > "${APP_DIR}/img/p/1/2/3/123-demo.jpg"
	printf '%s\n' "$CATEGORY_IMAGE_RESPONSE" > "${APP_DIR}/img/c/12-category.jpg"
	printf '%s\n' "$ALPHA_CATEGORY_IMAGE_RESPONSE" > "${APP_DIR}/img/c/fr-12.jpg"
	printf '%s\n' "$LEGACY_FANCYBOX_RESPONSE" > "${APP_DIR}/js/jquery/plugins/fancybox/images/loading.gif"
	printf '%s\n' 'id,name' > "${APP_DIR}/export.csv"
}

start_server() {
	docker run --rm --name "$CONTAINER_NAME" -d \
		-e "SERVER_NAME=:${CONTAINER_PORT}" \
		-v "${CADDYFILE_UNDER_TEST}:/etc/caddy/Caddyfile:ro" \
		-v "${APP_DIR}:/app:ro" \
		-p "127.0.0.1::${CONTAINER_PORT}" \
		"$TEST_IMAGE" \
		frankenphp run --config /etc/caddy/Caddyfile >/dev/null
}

server_url() {
	host_port="$(docker port "$CONTAINER_NAME" "$CONTAINER_PORT/tcp" | sed 's/.*://')"
	printf 'http://127.0.0.1:%s' "$host_port"
}

wait_for_server() {
	base_url="$1"
	attempt="1"

	while [ "$attempt" -le "$STARTUP_ATTEMPTS" ]; do
		ready_status="$(curl -sS -o /dev/null -w '%{http_code}' "${base_url}${READY_PATH}" 2>/dev/null || true)"
		if [ "$ready_status" = "$EXPECTED_OK" ]; then
			return 0
		fi

		sleep "$STARTUP_DELAY_SECONDS"
		attempt=$((attempt + 1))
	done

	docker logs "$CONTAINER_NAME" >&2 || true
	printf 'FrankenPHP did not become ready at %s\n' "$base_url" >&2
	exit 1
}

assert_status() {
	base_url="$1"
	path="$2"
	expected_status="$3"

	actual_status="$(curl -sS -o /dev/null -w '%{http_code}' "${base_url}${path}")"
	if [ "$actual_status" != "$expected_status" ]; then
		printf 'unexpected status for %s: expected %s, got %s\n' "$path" "$expected_status" "$actual_status" >&2
		exit 1
	fi
}

assert_header_contains() {
	base_url="$1"
	path="$2"
	header_name="$3"
	expected_value="$4"

	headers="$(curl -sSI "${base_url}${path}")"
	if ! printf '%s\n' "$headers" | grep -Fi "${header_name}:" | grep -Fq "$expected_value"; then
		printf 'missing header value for %s: %s: %s\n' "$path" "$header_name" "$expected_value" >&2
		printf '%s\n' "$headers" >&2
		exit 1
	fi
}

assert_body_contains() {
	base_url="$1"
	path="$2"
	expected_text="$3"

	body="$(curl -sS "${base_url}${path}")"
	if ! printf '%s' "$body" | grep -Fq "$expected_text"; then
		printf 'missing body text for %s: %s\n' "$path" "$expected_text" >&2
		printf '%s\n' "$body" >&2
		exit 1
	fi
}

write_fixture
start_server
BASE_URL="$(server_url)"
readonly BASE_URL
wait_for_server "$BASE_URL"

for blocked_path in \
	"/.env" \
	"/composer.json" \
	"/config/settings.inc.php" \
	"/vendor/autoload.php" \
	"/var/logs/prod.log"; do
	assert_status "$BASE_URL" "$blocked_path" "$EXPECTED_NOT_FOUND"
done

assert_status "$BASE_URL" "/themes/classic/assets/theme.css" "$EXPECTED_OK"
assert_header_contains "$BASE_URL" "/themes/classic/assets/theme.css" "$CACHE_HEADER_NAME" "$STATIC_CACHE_VALUE"
assert_header_contains "$BASE_URL" "/export.csv" "$CACHE_HEADER_NAME" "$MUTABLE_CACHE_VALUE"
assert_status "$BASE_URL" "/" "$EXPECTED_OK"
assert_body_contains "$BASE_URL" "/" "fallback:/"
assert_status "$BASE_URL" "/fr/robes/1-demo-product.html?token=ok" "$EXPECTED_OK"
assert_body_contains "$BASE_URL" "/fr/robes/1-demo-product.html?token=ok" "fallback:/fr/robes/1-demo-product.html?token=ok"
assert_status "$BASE_URL" "/123-demo/product-image.jpg" "$EXPECTED_OK"
assert_body_contains "$BASE_URL" "/123-demo/product-image.jpg" "$PRODUCT_IMAGE_RESPONSE"
assert_status "$BASE_URL" "/c/12-category/category-image.jpg" "$EXPECTED_OK"
assert_body_contains "$BASE_URL" "/c/12-category/category-image.jpg" "$CATEGORY_IMAGE_RESPONSE"
assert_status "$BASE_URL" "/c/fr-12/category-image.jpg" "$EXPECTED_OK"
assert_body_contains "$BASE_URL" "/c/fr-12/category-image.jpg" "$ALPHA_CATEGORY_IMAGE_RESPONSE"
assert_status "$BASE_URL" "/images_ie/loading.gif" "$EXPECTED_OK"
assert_body_contains "$BASE_URL" "/images_ie/loading.gif" "$LEGACY_FANCYBOX_RESPONSE"
assert_status "$BASE_URL" "/api/products" "$EXPECTED_OK"
assert_body_contains "$BASE_URL" "/api/products" "${API_DISPATCHER_RESPONSE}products"
assert_status "$BASE_URL" "/upload/module-file.txt" "$EXPECTED_OK"
assert_body_contains "$BASE_URL" "/upload/module-file.txt" "fallback:/upload/module-file.txt"

printf 'PrestaShop FrankenPHP Caddy routing test passed.\n'
