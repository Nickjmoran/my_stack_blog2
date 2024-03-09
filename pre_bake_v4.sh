#!/bin/bash -xe

#Updating the system 
sudo yum update -y

#Installing LAMP
sudo amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2

#Installing apache and maria
sudo yum install -y httpd mariadb-server

#Starting apache & enabling at boot
sudo systemctl start httpd

sudo systemctl enable httpd

#Adding the EC2 user to the apache group
sudo usermod -a -G apache ec2-user

#Setting Permissions
sudo chown -R ec2-user:apache /var/www
sudo chmod 2775 /var/www && find /var/www -type d -exec sudo chmod 2775 {} \;
find /var/www -type f -exec sudo chmod 0664 {} \;

#Creating a php file for manual checks if needed
echo "<?php phpinfo(); ?>" > /var/www/html/phpinfo.php

#Deleting the php file
rm /var/www/html/phpinfo.php

#Starting Maria
sudo systemctl start mariadb

root_pass="Thisismyserver1!"

#Installing the expect command
sudo yum -y install expect.x86_64
SECURE_MYSQL=$(expect -c "

spawn mysql_secure_installation

expect  \"Enter current password for root (enter for none):\"
send \"\r\"

expect \"Change the root password? [Y/n]\"
send \"Y\r\"

expect \"New password:\"
send \"${root_pass}\r\"

expect \"Re-enter new password:\"
send \"${root_pass}\r\"

expect \"Remove anonymous users? [Y/n]\"
send \"Y\r\"

expect \"Disallow root login remotely? [Y/n]\"
send \"Y\r\"

expect \"Remove test database and access to it? [Y/n]\"
send \"Y\r\"

expect \"Reload privilege tables now? [Y/n]\"
send \"Y\r\"

expect eof
")

echo "$SECURE_MYSQL"


#Installing additional php services
sudo yum install php-mbstring -y

#Restarting apache to capture additional resources as well as the fpm
sudo systemctl restart httpd
sudo systemctl restart php-fpm

#CD to apache group root directory 
cd /var/www/html

#Downloading and extracting phpMyAdmin
wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
mkdir phpMyAdmin && tar -xvzf phpMyAdmin-latest-all-languages.tar.gz -C phpMyAdmin --strip-components 1

#Deleting tarball
rm phpMyAdmin-latest-all-languages.tar.gz

#Downloading and extracting wordpress 
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz

#Restarting Maria before creating wordpress creds
sudo systemctl start mariadb

#Creating wp creds and creating wp database
DB_NAME="wordpressdb"
DB_USER="stack_nic_sep23"
DB_PASSWORD="passwerd1!"
mysql -u root <<EOF
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
CREATE DATABASE \`$DB_NAME\`;
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
exit
EOF


#Copying config file from the sample 
cp wordpress/wp-config-sample.php wordpress/wp-config.php

#Updating config file with necessary variables
WP_CONFIG="/var/www/html/wordpress/wp-config.php"
sed -i "s/'database_name_here'/'$DB_NAME'/g" $WP_CONFIG
sed -i "s/'username_here'/'$DB_USER'/g" $WP_CONFIG
sed -i "s/'password_here'/'$DB_PASSWORD'/g" $WP_CONFIG

#Extracting all required wp files from wp folder and moving them to the html directory for access
cp -r wordpress/* /var/www/html/

#Updating apache config file with required overrides
APACHE_CONF="/etc/httpd/conf/httpd.conf"
sudo sed -i '151s/None/All/g' $APACHE_CONF

#Granting ownership permissions of the group root folder to everyone in the apache group
sudo chown -R apache /var/www

#Granting group rights to the apache group root folder 
sudo chgrp -R apache /var/www

#Changing the apache root folder rights
sudo chmod 2775 /var/www
find /var/www -type d -exec sudo chmod 2775 {} \;
find /var/www -type f -exec sudo chmod 0664 {} \;

#Restarting apache to capture changes
sudo systemctl restart httpd

#Enabling apache and maria at boot again just in case
sudo systemctl enable httpd && sudo systemctl enable mariadb

#Verifying apache is running
sudo systemctl status httpd

#Installing the wp CLI
sudo yum install -y php-cli
sudo curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

#Checking the CLI info for debugging purposes
php wp-cli.phar --info

#Granting permissions to all users as well as moving it somewhere executable
sudo chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

#Getting IP address of the instance
IP_ADDRESS=$(curl -s http://checkip.amazonaws.com)

#Checking to see if wp is running for debug purposes
wp --info

DB_EMAIL="Nicholas.jmoran@hotmail.com"
wp core install --url="http://${IP_ADDRESS}" --title="Welcome To Nick's Blog" --admin_user="$DB_USER" --admin_password="$DB_PASSWORD" --admin_email="$DB_EMAIL" --path=/var/www/html/

#Changing permissions to allow the installation of themes not native to the download package
sudo find . -type d -exec chmod 0755 {} \;
sudo find . -type f -exec chmod 0644 {} \;
sudo chown -R ec2-user:apache .
sudo chmod -R g+w .
sudo chmod g+s .

#Installing the desired 2017 theme
wp theme install twentyseventeen --activate

#Restarting apache to capture changes
sudo systemctl restart httpd
