FROM drupal:8.9.13

ARG DEBIAN_FRONTEND=noninteractive
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
ARG RELEASE_NAME="$(cat /etc/os-release | grep -P -o "(?<=VERSION_CODENAME=).*")"

RUN { 											\
	echo 'apc.shm_size = 512M'; 				\
	echo 'apc.slam_defense = 1'; 				\
} > /usr/local/etc/php/conf.d/docker-php-ext-apcu.ini

RUN { 											\
	echo 'opcache.fast_shutdown=1'; 			\
	echo 'opcache.interned_strings_buffer=32'; 	\
	echo 'opcache.max_accelerated_files=20071'; \
	echo 'opcache.max_wasted_percentage=10'; 	\
	echo 'opcache.memory_consumption=512'; 		\
	echo 'opcache.revalidate_freq=10'; 			\
	echo 'opcache.validate_timestamps=1'; 		\		
} > /usr/local/etc/php/conf.d/opcache-recommended.ini

RUN { 											\
	echo 'memory_limit = -1'; 					\
	echo 'post_max_size = 30M'; 				\
	echo 'upload_max_filesize = 30M'; 			\
} > /usr/local/etc/php/conf.d/docker-php-ext-core.ini

RUN { 																																	\
	echo '#!/bin/bash';																													\
	echo 'while ! $(service apache2 status | grep -q "is running"); do sleep 2; done;';													\
	echo 'CORE_VERSION=$(drush core:status | grep -P -o "(?<=Drupal version).*" | cut -d ':' -f2 | xargs)';								\
	echo 'if [ "$CORE_VERSION" = "$DRUPAL_VERSION" ]; then exit 0; fi';																	\
	echo 'curl "https://ftp.drupal.org/files/projects/drupal-$DRUPAL_VERSION.zip" --output /tmp/drupal.zip';							\
	echo 'unzip /tmp/drupal.zip -d /tmp';																								\
	echo 'find "/tmp/drupal-$DRUPAL_VERSION/core/" \( -iname tests -o -iname docs -o -iname examples \) -type d -exec rm -rf "{}" +';	\
	echo 'drush state:set system.maintenance_mode 1 && sleep 5'; 																		\
	echo 'rm -rf /opt/drupal/web/core/*'; 																								\
	echo 'cp -a "/tmp/drupal-$DRUPAL_VERSION/core/." /opt/drupal/web/core/';															\
	echo 'drush updatedb'; 																												\
	echo 'drush cache:rebuild'; 																										\
	echo 'rm -rf /tmp/drupal*'; 																										\
	echo 'drush state:set system.maintenance_mode 0'; 																					\
} > /usr/local/bin/core-updater.sh && chmod +x /usr/local/bin/core-updater.sh

RUN apt-get update && apt-get install -y --no-install-recommends --fix-missing apt-utils gnupg	&&\
	echo "deb http://packages.dotdeb.org $RELEASE_NAME all" >> /etc/apt/sources.list 			&&\
	echo "deb-src http://packages.dotdeb.org $RELEASE_NAME all" >> /etc/apt/sources.list 		&&\
	curl -sS https://www.dotdeb.org/dotdeb.gpg | apt-key add -

RUN apt-get install -y --no-install-recommends   							  									\
	unzip mailutils postfix libfreetype6-dev libjpeg-dev  					  									\
	libpng-dev libpq-dev libzip-dev zlib1g-dev libwebp-dev 														&&\
	mkdir /opt/drupal/private  																					&&\
	chown www-data:www-data /opt/drupal/private 																&&\
	export COMPOSER_HOME="$(mktemp -d)" 																		&&\
	find /opt/drupal/vendor/ \( -iname tests -o -iname docs -o -iname examples \) -type d -exec rm -rf "{}" + 	&&\
	composer --prefer-dist --optimize-autoloader --working-dir=/opt/drupal require drush/drush					&&\
	composer --prefer-dist --optimize-autoloader --working-dir=/opt/drupal require drupal/upgrade_status:^3.0 	&&\
	composer --prefer-dist --optimize-autoloader --working-dir=/opt/drupal require patchwork/jsqueeze 			&&\
	composer --prefer-dist --optimize-autoloader --working-dir=/opt/drupal require natxet/CssMin 				&&\
	postconf smtp_tls_security_level=encrypt 																	&&\
	pecl install apcu 																							&&\
	pecl install uploadprogress 																				&&\
	docker-php-ext-configure gd --with-freetype --with-jpeg=/usr --with-webp 									&&\
	docker-php-ext-install gd																					&&\
	docker-php-ext-enable apcu 																					&&\
	docker-php-ext-enable uploadprogress 																		&&\
	rm -rf "$COMPOSER_HOME" 																					&&\
	rm -rf /var/lib/apt/lists/*																					&&\
	find /opt/drupal/vendor/ \( -iname tests -o -iname docs -o -iname examples \) -type d -exec rm -rf "{}" +	&&\
	sed -i '$i service postfix start' /usr/local/bin/docker-php-entrypoint 										&&\
	sed -i '$i /usr/local/bin/core-updater.sh &' /usr/local/bin/docker-php-entrypoint
