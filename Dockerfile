FROM alpine:3.12
ENV TIMEZONE America/New_York
RUN apk update && apk upgrade
RUN apk add --no-cache bash \
   busybox-extras \
   mariadb mariadb-client \
   apache2 \
   apache2-utils \
   curl wget vim htop \
   tzdata \
   php7-apache2 \
   php7-cli \
   php7-phar \
   php7-zlib \
   php7-zip \
   php7-bz2 \
   php7-ctype \
   php7-curl \
   php7-pdo_mysql \
   php7-mysqli \
   php7-json \
   php7-mcrypt \
   php7-xml \
   php7-dom \
   php7-iconv \
   php7-xdebug \
   php7-session \
   php7-intl \
   php7-gd \
   php7-mbstring \
   php7-apcu \
   php7-opcache \
   php7-tokenizer \
   php7-xml \
   php7-fileinfo \
   supervisor

RUN rm /var/cache/apk/*

RUN curl -sS https://getcomposer.org/installer | \
   php -- --install-dir=/usr/bin --filename=composer

#
# Install WP-CLI
#
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli-nightly.phar \
   && chmod +x wp-cli-nightly.phar \
   && mv wp-cli-nightly.phar /usr/bin/wp


#
RUN \
   sed -i 's/AllowOverride none/AllowOverride All/gi' /etc/apache2/httpd.conf && \
   sed -i 's#Require all denied#Require all granted#' /etc/apache2/httpd.conf && \
   echo "IncludeOptional /etc/apache2/sites.d/*.conf" >> /etc/apache2/httpd.conf && \
   mkdir /etc/apache2/sites.d
# sed -i 's#^DocumentRoot ".*#DocumentRoot "/var/www/localhost/htdocs"#g' /etc/apache2/httpd.conf

# RUN sed -i '/^#LoadModule vhost_alias/s/^#//g' /etc/apache2/httpd.conf

# configure timezone, mysql, apache
RUN cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone && \
    mkdir -p /run/mysqld && chown -R mysql:mysql /run/mysqld /var/lib/mysql && \
    # mariadb-install-db --user=mysql --ldata=/var/lib/mysql > /dev/null && \
    mkdir -p /run/apache2 && chown -R apache:apache /run/apache2 && chown -R apache:apache /var/www/localhost/htdocs/ && \
    sed -i 's#\#LoadModule rewrite_module modules\/mod_rewrite.so#LoadModule rewrite_module modules\/mod_rewrite.so#' /etc/apache2/httpd.conf && \
    sed -i 's#ServerName www.example.com:80#\nServerName localhost:80#' /etc/apache2/httpd.conf && \
    sed -i 's/skip-networking/\#skip-networking/i' /etc/my.cnf.d/mariadb-server.cnf && \
    sed -i '/mariadb\]/a log_error = \/var\/www\/app\/logs\/mysql_error.log' /etc/my.cnf.d/mariadb-server.cnf && \
    # sed -i -e"s/^#bind-address\s*=\s*127.0.0.1/bind-address = 0.0.0.0/" /etc/my.cnf.d/mariadb-server.cnf && \
    sed -i -e"s/^#bind-address\s*=\s*0.0.0.0/bind-address = 0.0.0.0/" /etc/my.cnf.d/mariadb-server.cnf && \
    sed -i '/mariadb\]/a skip-external-locking' /etc/my.cnf.d/mariadb-server.cnf && \
    sed -i '/mariadb\]/a general_log = ON' /etc/my.cnf.d/mariadb-server.cnf && \
    sed -i '/mariadb\]/a general_log_file = \/var\/lib\/mysql\/query.log' /etc/my.cnf.d/mariadb-server.cnf #&& \
    # sed -i 's#/var/lib/mysql/error.log#/var/www/app/logs/mysql_error.log#' /etc/my.cnf.d/mariadb-server.cnf

RUN sed -i 's#display_errors = Off#display_errors = On#' /etc/php7/php.ini && \
   sed -i 's#upload_max_filesize = 2M#upload_max_filesize = 100M#' /etc/php7/php.ini && \
   sed -i 's#post_max_size = 8M#post_max_size = 100M#' /etc/php7/php.ini && \
   sed -i 's#session.cookie_httponly =#session.cookie_httponly = true#' /etc/php7/php.ini && \
   sed -i 's#error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT#error_reporting = E_ALL#' /etc/php7/php.ini


# Configure xdebug
RUN echo "zend_extension=xdebug.so" > /etc/php7/conf.d/xdebug.ini && \
   echo -e "\n[XDEBUG]"  >> /etc/php7/conf.d/xdebug.ini && \
   echo "xdebug.remote_enable=1" >> /etc/php7/conf.d/xdebug.ini && \
   echo "xdebug.remote_connect_back=1" >> /etc/php7/conf.d/xdebug.ini && \
   echo "xdebug.idekey=PHPSTORM" >> /etc/php7/conf.d/xdebug.ini && \
   echo "xdebug.remote_log=\"/tmp/xdebug.log\"" >> /etc/php7/conf.d/xdebug.ini

# COPY sql_init.sql /init.sql

COPY xdebug.ini /etc/php7/conf.d/xdebug.ini

RUN touch /first_run

COPY entry.sh /entry.sh

RUN chmod u+x /entry.sh

WORKDIR /var/www/app/

EXPOSE 80
EXPOSE 3306
EXPOSE 3307
EXPOSE 9000


#
# Supervisor
#
RUN mkdir -p /var/log/supervisor
ADD supervisord.conf /etc/supervisord.conf

# CMD ["/usr/bin/supervisord"]
ENTRYPOINT ["/entry.sh"]