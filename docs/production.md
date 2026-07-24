# Production Notes

This repository is a starting point for running PrestaShop on FrankenPHP. Treat
the included Compose files as a deployable reference, not as a complete hosting
policy.

## Persistent Data

Keep these PrestaShop paths persistent across image rebuilds and container
replacements:

- `app/config`
- `download`
- `img`
- `modules`
- `themes`
- `translations`
- `upload`
- `var`

The helper script `scripts/ensure-prestashop-permissions.sh` aligns writable
paths with the web user inside the container. Run it after extracting or
restoring a shop archive.

## Secrets

Do not commit `.env` or generated PrestaShop configuration files. Inject
database passwords, cookie keys, mail credentials, and external service tokens
through your runtime secret manager.

## Trusted Proxies

When FrankenPHP runs behind another load balancer or reverse proxy, configure
trusted proxies and forwarded headers explicitly in PrestaShop and Caddy. Do not
trust all forwarded headers from the public internet.

## TLS and Domains

Use a real `SERVER_NAME` in production so Caddy can manage certificates and so
PrestaShop generates stable absolute URLs. Keep the local HTTP-only demo setup
separate from production.

## Validation

After each deploy, verify at least:

- front office returns `200`
- back office login returns `200`
- `/.env`, `/vendor/autoload.php`, and `/config/settings.inc.php` return `404`
- static assets return immutable cache headers
- mutable export/archive paths do not receive immutable cache headers

The script `scripts/verify-local-shop.sh` covers these checks for local and CI
demo installs.
