ARG FRANKENPHP_IMAGE=dunglas/frankenphp:1.12.5-php8.4-bookworm
FROM ${FRANKENPHP_IMAGE}

WORKDIR /app

RUN set -eux; \
	install-php-extensions \
		apcu \
		bcmath \
		curl \
		gd \
		intl \
		mbstring \
		opcache \
		pdo_mysql \
		soap \
		zip

COPY --link Caddyfile /etc/caddy/Caddyfile
COPY --link docker/php/conf/prestashop.ini /usr/local/etc/php/conf.d/prestashop.ini
COPY --link scripts/ensure-prestashop-permissions.sh /usr/local/bin/ensure-prestashop-permissions

RUN chmod +x /usr/local/bin/ensure-prestashop-permissions

HEALTHCHECK --start-period=60s CMD curl -fsS "http://localhost/healthz" || exit 1

CMD ["frankenphp", "run", "--config", "/etc/caddy/Caddyfile"]
