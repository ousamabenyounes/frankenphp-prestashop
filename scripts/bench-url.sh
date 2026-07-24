#!/usr/bin/env sh
set -eu

readonly DEFAULT_REQUESTS="50"
readonly DEFAULT_WARMUP="5"
readonly CURL_FORMAT="status=%{http_code} total=%{time_total} connect=%{time_connect} starttransfer=%{time_starttransfer} size=%{size_download}"
readonly SUCCESS_STATUS_PATTERN="^2"
readonly FIRST_PERCENTILE_INDEX="1"
readonly PERCENTILE_SCALE="100"
readonly P50_PERCENTILE="50"
readonly P95_PERCENTILE="95"
readonly P99_PERCENTILE="99"

target_url="${1:-}"
requests="${REQUESTS:-$DEFAULT_REQUESTS}"
warmup="${WARMUP:-$DEFAULT_WARMUP}"
samples_file="$(mktemp)"
readonly samples_file

cleanup() {
	rm -f "$samples_file"
}

trap cleanup EXIT INT TERM

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

sample_total() {
	sample="$1"

	printf '%s\n' "$sample" | sed -n 's/.*total=\([0-9.][0-9.]*\).*/\1/p'
}

print_summary() {
	sort -n "$samples_file" | awk \
		-v p50="$P50_PERCENTILE" \
		-v p95="$P95_PERCENTILE" \
		-v p99="$P99_PERCENTILE" \
		-v scale="$PERCENTILE_SCALE" \
		-v first_index="$FIRST_PERCENTILE_INDEX" '
		{
			values[++count] = $1
			sum += $1
		}
		END {
			if (count < first_index) {
				exit 1
			}

			printf "summary samples=%d min=%.6f avg=%.6f p50=%.6f p95=%.6f p99=%.6f max=%.6f\n",
				count,
				values[first_index],
				sum / count,
				values[int((p50 * count + scale - 1) / scale)],
				values[int((p95 * count + scale - 1) / scale)],
				values[int((p99 * count + scale - 1) / scale)],
				values[count]
		}
	'
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
	sample_total "$sample" >> "$samples_file"
	printf '%s' "$sample"
	printf '\n'
	counter=$((counter + 1))
done

print_summary
