FROM drupal:8.9.13

ARG DEBIAN_FRONTEND=noninteractive
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
ARG RELEASE_NAME="$(cat /etc/os-release | grep -P -o "(?<=VERSION_CODENAME=).*")"

# opcache-recommended.ini
RUN { 											\
	echo 'opcache.fast_shutdown=1'; 			\
	echo 'opcache.interned_strings_buffer=16'; 	\
	echo 'opcache.max_accelerated_files=20000'; \
	echo 'opcache.memory_consumption=512'; 		\
	echo 'opcache.revalidate_freq=0'; 			\
	echo 'opcache.validate_timestamps=0'; 		\		
} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# php.ini
RUN { 									\
	echo 'memory_limit = -1'; 			\
	echo 'post_max_size = 30M'; 		\
	echo 'upload_max_filesize = 30M'; 	\
} > /usr/local/etc/php/conf.d/docker-php-ext-core.ini && service apache2 restart

RUN apt-get update && apt-get install -y --no-install-recommends --fix-missing apt-utils gnupg	&&\
	echo "deb http://packages.dotdeb.org $RELEASE_NAME all" >> /etc/apt/sources.list 			&&\
	echo "deb-src http://packages.dotdeb.org $RELEASE_NAME all" >> /etc/apt/sources.list 		&&\
	curl -sS https://www.dotdeb.org/dotdeb.gpg | apt-key add -

# Extra dependencies, webp, unzip, mailutils, postfix, drush, upgrade_status, jsqueeze
RUN apt-get install -y --no-install-recommends   							  	\
	unzip mailutils postfix libfreetype6-dev libjpeg-dev  					  	\
	libpng-dev libpq-dev libzip-dev zlib1g-dev libwebp-dev 						&&\
	export COMPOSER_HOME="$(mktemp -d)" 										&&\
	composer -o --working-dir=/opt/drupal require drush/drush					&&\
	composer -o --working-dir=/opt/drupal require drupal/upgrade_status:^3.0 	&&\
	composer -o --working-dir=/opt/drupal require patchwork/jsqueeze 			&&\
	composer -o --working-dir=/opt/drupal require natxet/CssMin 				&&\
	rm -rf "$COMPOSER_HOME" 													&&\
	postconf smtp_tls_security_level=encrypt 									&&\
	docker-php-ext-configure gd --with-freetype --with-jpeg=/usr --with-webp 	&&\
	docker-php-ext-install gd													&&\
	mkdir /opt/drupal/private && chown www-data:www-data /opt/drupal/private 	&&\
	rm -rf /var/lib/apt/lists/*

# Post install script
RUN { 																					\
	echo '#!/bin/bash';																	\
	echo 'while ! $(service apache2 status | grep -q "is running"); do sleep 2; done;';	\
	echo 'drush state:set system.maintenance_mode 1'; 									\
	echo 'composer --working-dir=/opt/drupal require drupal/core:$DRUPAL_VERSION'; 		\
	echo 'drush updatedb'; 																\
	echo 'drush cache:rebuild'; 														\
	echo 'drush state:set system.maintenance_mode 0'; 									\	
} > /usr/local/bin/postinstall.sh && chmod +x /usr/local/bin/postinstall.sh

RUN sed -i '$i service postfix start' /usr/local/bin/docker-php-entrypoint &&\
	sed -i '$i /usr/local/bin/postinstall.sh &' /usr/local/bin/docker-php-entrypoint