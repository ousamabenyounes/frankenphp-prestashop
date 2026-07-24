#!/usr/bin/env sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
readonly PROJECT_ROOT
readonly TEST_IMAGE="dunglas/frankenphp:1.12.5-php8.4-bookworm"
readonly CONTAINER_PORT="8080"
readonly STARTUP_ATTEMPTS="30"
readonly STARTUP_DELAY_SECONDS="1"
readonly EXPECTED_ERROR_STATUS="500"

TEMP_DIR="$(mktemp -d)"
readonly TEMP_DIR
readonly CADDYFILE_PATH="${TEMP_DIR}/Caddyfile"
readonly CONTAINER_NAME="frankenphp-prestashop-bench-status-$$"

cleanup() {
	docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
	rm -rf "$TEMP_DIR"
}

trap cleanup EXIT INT TERM

cat > "$CADDYFILE_PATH" <<'EOF'
{
	auto_https off
}

:8080 {
	respond "error" 500
}
EOF

docker run --rm --name "$CONTAINER_NAME" -d \
	-v "${CADDYFILE_PATH}:/etc/caddy/Caddyfile:ro" \
	-p "127.0.0.1::${CONTAINER_PORT}" \
	"$TEST_IMAGE" \
	frankenphp run --config /etc/caddy/Caddyfile >/dev/null

host_port="$(docker port "$CONTAINER_NAME" "$CONTAINER_PORT/tcp" | sed 's/.*://')"
readonly BENCH_URL="http://127.0.0.1:${host_port}/"

attempt="1"
while [ "$attempt" -le "$STARTUP_ATTEMPTS" ]; do
	status="$(curl -sS -o /dev/null -w '%{http_code}' "$BENCH_URL" 2>/dev/null || true)"
	if [ "$status" = "$EXPECTED_ERROR_STATUS" ]; then
		break
	fi

	sleep "$STARTUP_DELAY_SECONDS"
	attempt=$((attempt + 1))
done

if [ "$status" != "$EXPECTED_ERROR_STATUS" ]; then
	docker logs "$CONTAINER_NAME" >&2 || true
	printf 'benchmark status fixture did not become ready at %s\n' "$BENCH_URL" >&2
	exit 1
fi

if REQUESTS=1 WARMUP=1 "${PROJECT_ROOT}/scripts/bench-url.sh" "$BENCH_URL" >/tmp/bench-url-status.out 2>/tmp/bench-url-status.err; then
	printf 'bench-url.sh accepted a non-2xx target\n' >&2
	cat /tmp/bench-url-status.out >&2
	exit 1
fi

if ! grep -Fq 'benchmark target returned non-success status' /tmp/bench-url-status.err; then
	printf 'bench-url.sh failed for the wrong reason\n' >&2
	cat /tmp/bench-url-status.err >&2
	exit 1
fi

printf 'Benchmark status guard test passed.\n'
