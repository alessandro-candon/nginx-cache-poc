ARG DOCKER_REGISTRY=docker.io
ARG PHP_VERSION=8.1

FROM ${DOCKER_REGISTRY}/bitnami/php-fpm:${PHP_VERSION}-prod AS php_prod
ARG COMPOSER_VERSION=2.3.10
ENV PHP_INI_DIR="/opt/bitnami/php/etc" APP_ENV=prod APP_DEBUG=0 SERVER_ENV=prod

USER root

WORKDIR /app

RUN set -eux \
  && apt-get update && apt-get install -y --no-install-recommends \
  && install_packages autoconf make libpq5 libfcgi0ldbl libfcgi-bin unzip libpq-dev g++ git libjpeg-dev libpng-dev libtiff-dev libgif-dev libzstd-dev \
  && yes 'yes' | pecl install -f igbinary redis

COPY . .

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
  && cp .build/*.ini $PHP_INI_DIR/conf.d/ \
  && rm -f $PHP_INI_DIR/php-fpm.d/* \
  && cp .build/php-fpm.conf $PHP_INI_DIR/php-fpm.conf \
  && cp .build/www.conf $PHP_INI_DIR/php-fpm.d/ \
  && echo "extension=pgsql.so" >> $PHP_INI_DIR/conf.d/pgsql.ini \
  && echo "extension=pdo_pgsql.so" >> $PHP_INI_DIR/conf.d/pgsql.ini \
  && echo "opcache.revalidate_freq = 0" >> $PHP_INI_DIR/conf.d/php_opcache.ini \
  && echo "zend.assertions = -1" >> $PHP_INI_DIR/conf.d/php_opcache.ini \
  && echo "assert.exception = 0" >> $PHP_INI_DIR/conf.d/php_opcache.ini \
  && echo "opcache.preload = /app/config/preload.php" >> $PHP_INI_DIR/conf.d/php_opcache.ini \
  && echo "opcache.preload_user = www-data" >> $PHP_INI_DIR/conf.d/php_opcache.ini \
  && composer self-update ${COMPOSER_VERSION} \
  && mkdir -p var/cache var/log \
  && composer install --prefer-dist --no-dev --no-autoloader --no-scripts --no-progress --no-ansi \
  && composer clear-cache --no-ansi \
  && composer dump-autoload --optimize --classmap-authoritative --no-dev \
  && composer dump-env prod \
  && composer run-script --no-dev --no-ansi post-install-cmd \
  && chmod +x bin/console \
  && bin/console cache:clear --no-warmup && bin/console cache:warmup \
  && composer clear-cache --no-ansi \
  && chown -R www-data:www-data /app/var \
  && sync

USER www-data
CMD ["php-fpm", "-F", "--pid", "/tmp/php-fpm.pid", "-y", "/opt/bitnami/php/etc/php-fpm.conf"]

FROM php_prod AS php_dev

ENV PHP_INI_DIR="/opt/bitnami/php/etc" APP_ENV=dev APP_DEBUG=1 SERVER_ENV=dev GOOGLE_APPLICATION_CREDENTIALS="/tmp/application_default_credentials.json"

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    && install_packages bash ncurses-bin zsh \
    && pecl install pcov \
    && pecl install xdebug-3.1.2 \
    && rm -rf "$PHP_INI_DIR/conf.d/php_custom.ini" \
    && rm -rf "$PHP_INI_DIR/conf.d/php_opcache.ini" \
    && echo "zend.assertions = 1" >> $PHP_INI_DIR/conf.d/php_opcache.ini \
    && echo "assert.exception = 1" >> $PHP_INI_DIR/conf.d/php_opcache.ini \
    && echo "extension=pcov.so" >> $PHP_INI_DIR/conf.d/pcov.ini \
    && mkdir -m 777 -p /.composer

ENV XDEBUG_CONF_FILE=$PHP_INI_DIR/conf.d/docker-php-ext-xdebug.ini
COPY --chown=www-data:www-data .docker/php/xdebug.ini $XDEBUG_CONF_FILE
COPY .docker/php/xdebug-starter.sh /usr/local/bin/xdebug-starter

RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    && git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions \
    && sed -i -E "s/^plugins=\((.*)\)$/plugins=(\1 git git-flow zsh-autosuggestions)/" /root/.zshrc \
    && echo "export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE=\"fg=#0cb074\"" >> /root/.zshrc


COPY .docker/php/shell-aliases.rc /tmp/shell-aliases.rc
RUN cat /tmp/shell-aliases.rc >> /root/.bashrc \
    && cat /tmp/shell-aliases.rc >> ~/.zshrc

RUN echo 'deb [trusted=yes] https://repo.symfony.com/apt/ /' | tee /etc/apt/sources.list.d/symfony-cli.list \
    && apt update \
    && apt install symfony-cli

CMD ["php-fpm", "-F", "--pid", "/tmp/php-fpm.pid", "-y", "/opt/bitnami/php/etc/php-fpm.conf"]
