# Benchmark Plan

The benchmark must compare two separate PrestaShop installations, not the same database served by two frontends with different shop domains.

## FrankenPHP

```console
./scripts/install-frankenphp-demo.sh
REQUESTS=50 WARMUP=5 ./scripts/bench-url.sh http://localhost:8080/
```

## Nginx and PHP-FPM

The repository includes `compose.nginx.yaml`, `Dockerfile.fpm`, and `docker/nginx/default.conf` as the baseline stack.

Install the baseline into a separate source directory named `prestashop-nginx/`
with the same PrestaShop version, fixtures, PHP settings, MariaDB version, and
Redis version, then benchmark:

```console
NGINX_HTTP_PORT=8082 ./scripts/install-nginx-demo.sh
REQUESTS=50 WARMUP=5 ./scripts/bench-url.sh http://localhost:8082/
```

The benchmark helper aborts if the target returns a non-2xx status. A fast 404 or
500 is not a valid performance result.

Each run prints individual samples and a final summary:

```text
summary samples=50 min=0.170000 avg=0.220000 p50=0.215000 p95=0.260000 p99=0.280000 max=0.280000
```

## Benchmark Parity

Before comparing numbers, verify that both stacks use:

- the same PrestaShop release and fixture data
- the same PHP release and extension set
- the same `docker/php/conf/prestashop.ini` values
- the same MariaDB and Redis image versions
- the same shop cache settings
- the same warmed route, status code, and response size

For higher confidence, run a concurrent benchmark tool such as `oha`, `wrk`, or
`hey` after this serial smoke benchmark. Report CPU and memory for `php`,
`fpm`, `nginx`, `database`, and `redis`; do not compare FrankenPHP against an
untuned FPM pool or a different cache state.

## Rules

- Use the same machine, PrestaShop version, fixture data, PHP version, extensions, OPCache settings, database version, and cache settings.
- Warm both applications before measuring.
- Report p50, p95, p99, status codes, downloaded bytes, CPU, and memory.
- Do not claim FrankenPHP is faster unless the numbers show it on the tested workload.
