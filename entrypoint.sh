#!/bin/bash

function wait_for() {
    SERVICE=$1
    PORT=$2
    HOST=${3-localhost}
    bash -c "cat < /dev/null > /dev/tcp/$HOST/$PORT"
    while [[ $? != 0 ]]; do
        echo "waiting for $SERVICE at $HOST to online..."
        sleep 1
        bash -c "cat < /dev/null > /dev/tcp/$HOST/$PORT"
    done
    echo "connected to $SERVICE on $HOST port $PORT"
}

DB_HOSTNAME=${DB_HOSTNAME-localhost}
DB_USERNAME=${DB_USERNAME-tripwire}
DB_PASSWORD=${DB_PASSWORD-secret}
ADMIN_EMAIL=${ADMIN_EMAIL-"webmaster@localhost"}
SERVER_NAME=${SERVER_NAME-"tripwire.local"}
ADMIN_PASSWORD=${ADMIN_PASSWORD-admin}

MYSQL_ROOT_PASS=$(echo -e `date` | md5sum | awk '{ print $1 }');

service mysql restart

wait_for mysql 3306

echo $(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"Set root password?\"
send \"y\r\"
expect \"New password:\"
send \"$MYSQL_ROOT_PASS\r\"
expect \"Re-enter new password:\"
send \"$MYSQL_ROOT_PASS\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")

apt-get remove -y expect
apt-get autoremove -y

mysql -uroot -p$MYSQL_ROOT_PASS -e "create database tripwire;"
mysql -uroot -p$MYSQL_ROOT_PASS -e "create database eve_api;"
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL ON tripwire.* to '$DB_USERNAME'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL ON eve_api.* to '$DB_USERNAME'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT SUPER ON *.* to '$DB_USERNAME'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"

mysql -u$DB_USERNAME -p$DB_PASSWORD tripwire < /tmp/tripwire.sql
mysql -u$DB_USERNAME -p$DB_PASSWORD eve_api < /tmp/eve_api.sql
mysql -u$DB_USERNAME -p$DB_PASSWORD -e "INSERT INTO eve_api.cacheTime (type, time) VALUES ('activity', now())"

mv db.inc.example.php db.inc.php
sed -i -e "s/host=localhost/host=$DB_HOSTNAME/" db.inc.php
sed -i -e "s/dbname=tripwire_database/dbname=tripwire/" db.inc.php
sed -i -e "s/username/$DB_USERNAME/" db.inc.php
sed -i -e "s/password/$DB_PASSWORD/" db.inc.php
sed -i -e "s/clientID/$SSO_CLIENT_ID/" db.inc.php
sed -i -e "s/secret/$SSO_SECRET_KEY/" db.inc.php

echo "ServerName $SERVER_NAME" >> /etc/apache2/apache2.conf
unlink /etc/apache2/sites-enabled/000-default.conf
sed -i -e "s/Options Indexes FollowSymLinks/Options FollowSymLinks/" /etc/apache2/apache2.conf
sed -i -e "s/ServerTokens OS/ServerTokens Prod/" /etc/apache2/conf-enabled/security.conf
sed -i -e "s/ServerSignature On/ServerSignature Off/" /etc/apache2/conf-enabled/security.conf

cat <<EOF >> /etc/apache2/sites-available/100-$SERVER_NAME.conf
<VirtualHost *:80>
    ServerAdmin $ADMIN_EMAIL
    DocumentRoot "/var/www/tripwire"
    ServerName $SERVER_NAME
    ServerAlias www.$SERVER_NAME
    ErrorLog /var/log/apache2/$SERVER_NAME-error.log
    CustomLog /var/log/apache2/$SERVER_NAME-access.log combined
    <Directory "/var/www/tripwire">
        AllowOverride All
        Order allow,deny
        Allow from all
    </Directory>
</VirtualHost>
EOF

ln -s /etc/apache2/sites-available/100-$SERVER_NAME.conf /etc/apache2/sites-enabled/

service apache2 restart
apachectl -t -D DUMP_VHOSTS
php --version

cat <<EOF > /tmp/api_pull.patch
*** tools/api_pull.php.orig	Fri Jan 22 18:01:57 2016
--- tools/api_pull.php	Fri Jan 22 19:19:45 2016
***************
*** 1,14 ****
  <?php

  session_start();

- if(!isset($_SESSION['super']) || $_SESSION['super'] != 1) {
- 	echo 'Security Failure!';
- 	exit();
- }
-
  ini_set('display_errors', 'On');

  require('../db.inc.php');
  require('../api.class.php');

--- 1,9 ----
EOF

patch /var/www/tripwire/tools/api_pull.php /tmp/api_pull.patch
cd /var/www/tripwire/tools/

while [[ 1 ]]; do
    /usr/bin/php api_pull.php > /dev/null 2>&1
    for I in {1..180}; do
      sleep 1
    done
done
