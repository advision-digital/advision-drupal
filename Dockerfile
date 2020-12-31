FROM drupal:8.9.11

ARG DEBIAN_FRONTEND=noninteractive
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
ARG RELEASE_NAME="$(cat /etc/os-release | grep -P "^C<=VERSION_CODENAME=).*")"

RUN apt-get update && apt-get install -y --no-install-recommends --fix-missing apt-utils gnupg &&\
	echo "deb http://packages.dotdeb.org $RELEASE_NAME all" >> /etc/apt/sources.list &&\
	echo "deb-src http://packages.dotdeb.org $RELEASE_NAME all" >> /etc/apt/sources.list &&\
	curl -sS https://www.dotdeb.org/dotdeb.gpg | apt-key add -

# Customize GD
RUN apt-get install -y --no-install-recommends unzip libfreetype6-dev libjpeg-dev libpng-dev libpq-dev libzip-dev zlib1g-dev libwebp-dev &&\
	docker-php-ext-configure gd --with-freetype --with-jpeg=/usr --with-webp && docker-php-ext-install gd

# Customize php.ini
RUN { \
	echo 'memory_limit = 4096M'; \
	echo 'post_max_size = 30M'; \
	echo 'upload_max_filesize = 30M'; \
} > /usr/local/etc/php/conf.d/docker-php-ext-core.ini

# Composer 
RUN composer --working-dir=/opt/drupal require drupal/upgrade_status:^3.0

# Add Email Capabilities
RUN apt-get install -y --no-install-recommends mailutils postfix &&\
    postconf smtp_tls_security_level=encrypt

# Drupal config
RUN mkdir /opt/drupal/private && chown www-data:www-data /opt/drupal/private

# Add services to the entrypoint
RUN sed -i '$i service postfix start' /usr/local/bin/docker-php-entrypoint