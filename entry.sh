#!/bin/sh

# check if mysql data directory is nuked
# if so, install the db
echo "Checking /var/lib/mysql folder"
if [ ! -f /var/lib/mysql/ibdata1 ]; then 
    echo "Installing db"
    mariadb-install-db --user=mysql --ldata=/var/lib/mysql > /dev/null
    echo "Installed"
fi;

if [ ! -d "/run/mysqld" ]; then
  mkdir -p /run/mysqld
fi

# from mysql official docker repo
if [ -z "$MYSQL_ROOT_PASSWORD" -a -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
 echo >&2 'error: database is uninitialized and password option is not specified '
 echo >&2 '  You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_RANDOM_ROOT_PASSWORD'
 exit 1
fi

# random password
if [ ! -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
  MYSQL_ROOT_PASSWORD="$(pwgen -1 32)"
  echo "GENERATED ROOT PASSWORD: $MYSQL_ROOT_PASSWORD"
fi

tfile=`mktemp`
if [ ! -f "$tfile" ]; then
  return 1
fi

# cat << EOF > $tfile
# USE mysql;
# DELETE FROM user;
# FLUSH PRIVILEGES;
# GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY "$MYSQL_ROOT_PASSWORD" WITH GRANT OPTION;
# GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
# UPDATE user SET password=PASSWORD("") WHERE user='root' AND host='localhost';
# FLUSH PRIVILEGES;
# EOF

/usr/bin/mysqld --user=mysql --bootstrap --verbose < $tfile
rm -f $tfile


if [ -e /first_run ]; then
  echo "Bootstrapping"
  rm /first_run
  sqlinitfile=`mktemp`
  if [ "$db" != "" ]; then
    echo "CREATE DATABASE IF NOT EXISTS \`$db\` CHARACTER SET utf8 COLLATE utf8_general_ci;" >> $sqlinitfile
    if [ "$db_user" != "" ]; then
      echo "CREATE USER IF NOT EXISTS '$db_user' IDENTIFIED BY '$db_password';" >> $sqlinitfile
      echo "GRANT ALL ON \`$db\`.* to '$db_user'@'%' IDENTIFIED BY '$db_password';" >> $sqlinitfile
      echo "GRANT ALL ON \`$db\`.* to '$db_user'@'localhost' IDENTIFIED BY '$db_password';" >> $sqlinitfile
      echo "FLUSH PRIVILEGES;" >> $sqlinitfile
    fi
  fi
  /usr/share/mariadb/mysql.server start && \
  /usr/bin/mysql < $sqlinitfile && \
  rm $sqlinitfile
  if [ "$HTTP_ROOT" != "" ]; then
    sed -i 's#^DocumentRoot ".*#DocumentRoot "/var/www/localhost/htdocs/'$HTTP_ROOT'"#g' /etc/apache2/httpd.conf
  fi
  if [ "$WORDPRESS" = true ]; then
    cd /var/www/localhost/htdocs/ \
    && wp core download --allow-root \
    && wp core config --allow-root \
      --dbname=$db \
      --dbuser=${db_user} \
      --dbpass=${db_password} \
      --dbhost=localhost \
    && wp core install --allow-root \
      --admin_name=admin \
      --admin_password=admin \
      --admin_email=admin@example.com \
      --url=http://$HOSTNAME \
      --title=WordPress \
    && wp theme update --allow-root --all \
    && wp plugin update --allow-root --all
    # && chown -R wocker:wocker /var/www/wordpress
  fi
  /usr/share/mariadb/mysql.server stop

  wget  https://www.adminer.org/latest-mysql-en.php -O  adminer.php
fi




    # mysqld < "CREATE DATABASE $db;\
    # GRANT ALL PRIVILEGES ON *.* TO '$db_user'@'%' IDENTIFIED BY '$db_password';\
    # GRANT ALL PRIVILEGES ON *.* TO '$db_user'@'localhost' IDENTIFIED BY '$db_password';\
    # FLUSH PRIVILEGES;"

    


# start mysql
# nohup mysqld_safe --skip-grant-tables --bind-address 0.0.0.0 --user mysql > /dev/null 2>&1 &
# exec /usr/bin/mysqld --user=root --bind-address=0.0.0.0
/usr/bin/supervisord