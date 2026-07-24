#!/usr/bin/env sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
readonly PROJECT_ROOT
readonly DEFAULT_APP_DIR="prestashop"
readonly EXPECTED_OK_STATUS="200"
readonly EXPECTED_NOT_FOUND_STATUS="404"
readonly STATIC_CACHE_VALUE="public, max-age=31536000, immutable"
readonly CACHE_HEADER_NAME="Cache-Control"
readonly MIN_BODY_BYTES="1000"
readonly RESPONSE_BODY_FILE="/tmp/prestashop-verify-body"

cleanup() {
	rm -f "$RESPONSE_BODY_FILE"
}

trap cleanup EXIT INT TERM

app_dir_arg="${1:-$DEFAULT_APP_DIR}"
base_url="${2:-}"
expected_title="${3:-}"

if [ -z "$base_url" ] || [ -z "$expected_title" ]; then
	printf 'usage: %s APP_DIR BASE_URL EXPECTED_TITLE\n' "$0" >&2
	exit 1
fi

case "$app_dir_arg" in
	/*) app_dir="$app_dir_arg" ;;
	*) app_dir="${PROJECT_ROOT}/${app_dir_arg}" ;;
esac
readonly app_dir

if [ ! -d "$app_dir" ]; then
	printf 'application directory not found: %s\n' "$app_dir" >&2
	exit 1
fi

assert_status() {
	url="$1"
	expected_status="$2"

	status="$(curl -Ls -o "$RESPONSE_BODY_FILE" -w '%{http_code}' "$url")"
	body_bytes="$(wc -c < "$RESPONSE_BODY_FILE")"

	if [ "$status" != "$expected_status" ]; then
		printf 'unexpected status for %s: expected %s, got %s\n' "$url" "$expected_status" "$status" >&2
		exit 1
	fi

	if [ "$expected_status" = "$EXPECTED_OK_STATUS" ] && [ "$body_bytes" -lt "$MIN_BODY_BYTES" ]; then
		printf 'unexpectedly small body for %s: %s bytes\n' "$url" "$body_bytes" >&2
		exit 1
	fi
}

assert_title() {
	url="$1"
	expected_text="$2"

	curl -Ls -o "$RESPONSE_BODY_FILE" "$url"
	if ! grep -Fq "$expected_text" "$RESPONSE_BODY_FILE"; then
		printf 'missing title for %s: %s\n' "$url" "$expected_text" >&2
		exit 1
	fi
}

assert_header_contains() {
	url="$1"
	header_name="$2"
	expected_value="$3"

	headers="$(curl -sSI "$url")"
	if ! printf '%s\n' "$headers" | grep -Fi "${header_name}:" | grep -Fq "$expected_value"; then
		printf 'missing header value for %s: %s: %s\n' "$url" "$header_name" "$expected_value" >&2
		printf '%s\n' "$headers" >&2
		exit 1
	fi
}

admin_path="$(find "$app_dir" -maxdepth 1 -type d -name 'admin*' ! -name 'admin' ! -name 'admin-api' -printf '%f\n' | sort | head -1)"
if [ -z "$admin_path" ]; then
	printf 'PrestaShop admin directory not found in %s\n' "$app_dir" >&2
	exit 1
fi
readonly admin_path

asset_path="$(find "${app_dir}/themes" -type f -name '*.css' -printf '%P\n' 2>/dev/null | sort | head -1)"
if [ -z "$asset_path" ]; then
	printf 'CSS asset not found in %s/themes\n' "$app_dir" >&2
	exit 1
fi
readonly asset_url="${base_url%/}/themes/${asset_path}"

assert_status "${base_url%/}/" "$EXPECTED_OK_STATUS"
assert_title "${base_url%/}/" "$expected_title"
assert_status "${base_url%/}/${admin_path}/index.php" "$EXPECTED_OK_STATUS"
assert_title "${base_url%/}/${admin_path}/index.php" "$expected_title"
assert_status "${base_url%/}/.env" "$EXPECTED_NOT_FOUND_STATUS"
assert_status "${base_url%/}/vendor/autoload.php" "$EXPECTED_NOT_FOUND_STATUS"
assert_status "${base_url%/}/config/settings.inc.php" "$EXPECTED_NOT_FOUND_STATUS"
assert_status "$asset_url" "$EXPECTED_OK_STATUS"
assert_header_contains "$asset_url" "$CACHE_HEADER_NAME" "$STATIC_CACHE_VALUE"

printf 'Verified PrestaShop shop at %s with admin path %s.\n' "$base_url" "$admin_path"
