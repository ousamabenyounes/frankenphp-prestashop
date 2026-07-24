#!/usr/bin/env sh
set -eu

PROJECT_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
readonly PROJECT_ROOT
readonly TEST_IMAGE="dunglas/frankenphp:1.12.5-php8.4-bookworm"
readonly CONTAINER_PORT="8080"
readonly STARTUP_ATTEMPTS="30"
readonly STARTUP_DELAY_SECONDS="1"
readonly EXPECTED_OK_STATUS="200"
readonly EXPECTED_SAMPLE_COUNT="3"

TEMP_DIR="$(mktemp -d)"
readonly TEMP_DIR
readonly CADDYFILE_PATH="${TEMP_DIR}/Caddyfile"
readonly OUTPUT_FILE="${TEMP_DIR}/bench.out"
readonly CONTAINER_NAME="frankenphp-prestashop-bench-summary-$$"

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
	respond "ok" 200
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
	if [ "$status" = "$EXPECTED_OK_STATUS" ]; then
		break
	fi

	sleep "$STARTUP_DELAY_SECONDS"
	attempt=$((attempt + 1))
done

if [ "$status" != "$EXPECTED_OK_STATUS" ]; then
	docker logs "$CONTAINER_NAME" >&2 || true
	printf 'benchmark summary fixture did not become ready at %s\n' "$BENCH_URL" >&2
	exit 1
fi

REQUESTS="$EXPECTED_SAMPLE_COUNT" WARMUP=1 "${PROJECT_ROOT}/scripts/bench-url.sh" "$BENCH_URL" > "$OUTPUT_FILE"

sample_lines="$(grep -c '^sample=' "$OUTPUT_FILE")"
if [ "$sample_lines" != "$EXPECTED_SAMPLE_COUNT" ]; then
	printf 'unexpected sample line count: expected %s, got %s\n' "$EXPECTED_SAMPLE_COUNT" "$sample_lines" >&2
	cat "$OUTPUT_FILE" >&2
	exit 1
fi

if ! grep -Eq '^summary samples=3 min=[0-9.]+ avg=[0-9.]+ p50=[0-9.]+ p95=[0-9.]+ p99=[0-9.]+ max=[0-9.]+$' "$OUTPUT_FILE"; then
	printf 'missing benchmark percentile summary\n' >&2
	cat "$OUTPUT_FILE" >&2
	exit 1
fi

printf 'Benchmark summary test passed.\n'
