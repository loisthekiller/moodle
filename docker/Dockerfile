FROM php:8.3-apache

RUN apt-get update && apt-get install -y \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libxml2-dev \
    libicu-dev \
    libldap2-dev \
    libonig-dev \
    libpq-dev \
    libsodium-dev \
    libcurl4-openssl-dev \
    curl \
    unzip \
    git \
    cron \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
        gd \
        mysqli \
        pdo \
        pdo_mysql \
        zip \
        xml \
        intl \
        mbstring \
        opcache \
        soap \
        exif \
        sodium \
        curl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN a2enmod rewrite

RUN sed -i 's|DocumentRoot /var/www/html|DocumentRoot /var/www/html/public|g' \
        /etc/apache2/sites-available/000-default.conf \
    && sed -i 's|<Directory /var/www/html>|<Directory /var/www/html/public>|g' \
        /etc/apache2/apache2.conf

RUN echo "max_input_vars = 5000"      >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo "post_max_size = 128M"    >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo "upload_max_filesize = 128M" >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo "max_execution_time = 300"   >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo "opcache.enable = 1"         >> /usr/local/etc/php/conf.d/moodle.ini \
    && echo "opcache.memory_consumption = 128" >> /usr/local/etc/php/conf.d/moodle.ini

WORKDIR /var/www/html

COPY . .

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN mkdir -p /var/moodledata && chmod 750 /var/moodledata

EXPOSE 80

ENTRYPOINT ["/entrypoint.sh"]