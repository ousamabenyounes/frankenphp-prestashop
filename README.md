# PrestaShop on FrankenPHP

Run PrestaShop 9.1.4 on top of FrankenPHP using the official FrankenPHP Docker image, Caddy, MariaDB, Redis, and OPCache.

This repository is intentionally a skeleton, not a fork of PrestaShop. Put a PrestaShop source tree in `prestashop/`, copy `.env.example` to `.env`, then start the stack.

## Requirements

- Docker
- Docker Compose
- Git

## Quick Start

```console
cp .env.example .env
./scripts/install-prestashop.sh
docker compose up -d --build
```

Open `http://localhost:8080` and follow the PrestaShop installer.

Use these database settings during installation:

- Database host: `database`
- Database name: `prestashop`
- Database user: `prestashop`
- Database password: `prestashop`

## What Is Included

- FrankenPHP `1.12.5` with PHP `8.4`
- MariaDB `11.4.7`
- Redis `7.2.5`
- PHP extensions commonly needed by PrestaShop: APCu, BCMath, cURL, GD, Intl, Mbstring, OPCache, PDO MySQL, SOAP, ZIP
- Caddy rules for PrestaShop-friendly URLs, static cache headers, and blocked sensitive paths
- PHP settings aligned with PrestaShop 9 requirements, including `memory_limit = 512M`
- A separate Nginx + PHP-FPM baseline for fair performance comparisons

## Security Checks

The Caddyfile blocks direct HTTP access to sensitive files and directories such as `.env`, Composer metadata, logs, SQL dumps, `config/`, `var/`, `vendor/`, `tools/`, and VCS metadata.

The skeleton also disables PHP version exposure, enables strict sessions, and avoids floating Docker tags.

## Smoke Validation

Run the local validation script:

```console
./scripts/validate-skeleton.sh
```

It checks:

- required skeleton files exist
- Docker image tags are pinned
- Caddyfile contains the PrestaShop routing and security matchers
- PHP settings include the expected hardening and OPCache values
- Docker Compose renders successfully when Docker Compose is available
- Caddy/FrankenPHP validates the Caddyfile when Docker is available

The CI runs the same validation plus a real FrankenPHP routing test. That HTTP test starts FrankenPHP in Docker with a PrestaShop-like fixture and verifies:

- sensitive paths return `404`
- static assets return `200` with long-lived immutable cache headers
- mutable export files use `Cache-Control: no-store`
- friendly URLs fall back to `index.php`

## Local Demo

To install a disposable local shop and get verified URLs:

```console
./scripts/install-frankenphp-demo.sh
```

The script prints the front-office and back-office URLs after installation.

To install the comparable Nginx + PHP-FPM baseline on another port:

```console
NGINX_HTTP_PORT=8082 ./scripts/install-nginx-demo.sh
```

## Performance Comparison

See [docs/benchmark.md](docs/benchmark.md). The repository includes a Nginx + PHP-FPM baseline, but performance claims should be made only after both stacks run separate PrestaShop installations with the same data and settings.

## Production Notes

See [docs/production.md](docs/production.md) before using this as a production base. The short version: keep PrestaShop writable data persistent, inject secrets through the runtime, configure trusted proxies deliberately, and validate HTTP behavior after each deploy.

## Why Not Worker Mode Yet?

PrestaShop includes Symfony components, but it is not a pure Symfony application. It still has legacy request state, modules, overrides, sessions, cookies, and filesystem-heavy behavior. This skeleton uses FrankenPHP classic mode first. Worker mode should be treated as a separate compatibility project with cross-request state tests.
