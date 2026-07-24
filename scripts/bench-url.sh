#!/usr/bin/env sh
set -eu

readonly DEFAULT_REQUESTS="50"
readonly DEFAULT_WARMUP="5"
readonly CURL_FORMAT="status=%{http_code} total=%{time_total} connect=%{time_connect} starttransfer=%{time_starttransfer} size=%{size_download}"

target_url="${1:-}"
requests="${REQUESTS:-$DEFAULT_REQUESTS}"
warmup="${WARMUP:-$DEFAULT_WARMUP}"

if [ -z "$target_url" ]; then
	printf 'usage: %s URL\n' "$0" >&2
	exit 1
fi

run_request() {
	curl -Ls -o /dev/null -w "$CURL_FORMAT" "$target_url"
}

counter="1"
while [ "$counter" -le "$warmup" ]; do
	run_request >/dev/null
	counter=$((counter + 1))
done

counter="1"
while [ "$counter" -le "$requests" ]; do
	printf 'sample=%s ' "$counter"
	run_request
	printf '\n'
	counter=$((counter + 1))
done

