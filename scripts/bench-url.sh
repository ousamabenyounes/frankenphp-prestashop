#!/usr/bin/env sh
set -eu

readonly DEFAULT_REQUESTS="50"
readonly DEFAULT_WARMUP="5"
readonly CURL_FORMAT="status=%{http_code} total=%{time_total} connect=%{time_connect} starttransfer=%{time_starttransfer} size=%{size_download}"
readonly SUCCESS_STATUS_PATTERN="^2"

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

assert_success_sample() {
	sample="$1"

	status="$(printf '%s\n' "$sample" | sed -n 's/.*status=\([0-9][0-9][0-9]\).*/\1/p')"
	if ! printf '%s\n' "$status" | grep -Eq "$SUCCESS_STATUS_PATTERN"; then
		printf 'benchmark target returned non-success status: %s\n' "$sample" >&2
		exit 1
	fi
}

counter="1"
while [ "$counter" -le "$warmup" ]; do
	warmup_sample="$(run_request)"
	assert_success_sample "$warmup_sample"
	counter=$((counter + 1))
done

counter="1"
while [ "$counter" -le "$requests" ]; do
	printf 'sample=%s ' "$counter"
	sample="$(run_request)"
	assert_success_sample "$sample"
	printf '%s' "$sample"
	printf '\n'
	counter=$((counter + 1))
done
