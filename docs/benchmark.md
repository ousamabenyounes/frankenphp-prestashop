# Benchmark Plan

The benchmark must compare two separate PrestaShop installations, not the same database served by two frontends with different shop domains.

## FrankenPHP

```console
./scripts/install-frankenphp-demo.sh
./scripts/bench-url.sh http://localhost:8080/
```

## Nginx and PHP-FPM

The repository includes `compose.nginx.yaml`, `Dockerfile.fpm`, and `docker/nginx/default.conf` as the baseline stack.

Use a separate source directory named `prestashop-nginx/`, install it with the same PrestaShop version, fixtures, PHP settings, MariaDB version, and Redis version, then benchmark:

```console
REQUESTS=50 WARMUP=5 ./scripts/bench-url.sh http://localhost:8081/
```

## Rules

- Use the same machine, PrestaShop version, fixture data, PHP version, extensions, OPCache settings, database version, and cache settings.
- Warm both applications before measuring.
- Report p50, p95, p99, status codes, downloaded bytes, CPU, and memory.
- Do not claim FrankenPHP is faster unless the numbers show it on the tested workload.

