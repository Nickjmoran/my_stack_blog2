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

#Installing additional php services
sudo yum install php-mbstring -y

#Restarting apache to capture additional resources as well as the fpm
sudo systemctl restart httpd
sudo systemctl restart php-fpm

#Installing git
sudo yum install git -y
#CD to apache group root directory 
cd /var/www/html

#Creating wp creds and creating wp database
DB_NAME="wordpressdb"
DB_USER="stack_nic_sep23"
DB_PASSWORD="passwerd1!"
DB_HOST="testrds1.clw4oi62ww68.us-east-1.rds.amazonaws.com"

#Updating config file with necessary variables
WP_CONFIG="/var/www/html/wp-config.php"
sed -i "s/'database_name_here'/'$DB_NAME'/g" $WP_CONFIG
sed -i "s/'username_here'/'$DB_USER'/g" $WP_CONFIG
sed -i "s/'password_here'/'$DB_PASSWORD'/g" $WP_CONFIG
sed -i "s/'rds_instance'/'$DB_HOST'/g" $WP_CONFIG

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

#Enabling apache at boot again just in case
sudo systemctl enable httpd

#Verifying apache is running
sudo systemctl status httpd

#Restarting apache to capture changes
sudo systemctl restart httpd
