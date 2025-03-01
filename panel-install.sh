# --------------------------------------------

emailAddress=""
mySQLPassword=""
panelUsername=""
panelPassword=""
panelFirstName=""
panelLastName=""

# The local IP of where the server will be used.
websiteIP="" 

# What the domain will be called so you don't have to input the IP to get the panel up.
websiteDomain=""

# --------------------------------------------

(sudo grep -v -F "${websiteIP} ${websiteDomain}" /etc/hosts; echo "${websiteIP} ${websiteDomain}") | sudo tee /etc/hosts

sudo apt -y install software-properties-common curl apt-transport-https ca-certificates gnupg

sudo LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php

sudo curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/redis.list

sudo curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash
sudo apt update

sudo apt -y install php8.3 php8.3-{common,cli,gd,mysql,mbstring,bcmath,xml,fpm,curl,zip} mariadb-server nginx tar unzip git redis-server

curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

# --------------------------------------------

sudo mkdir -p /var/www/pterodactyl
cd /var/www/pterodactyl

sudo curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
sudo tar -xzvf panel.tar.gz
sudo chmod -R 755 storage/* bootstrap/cache/

# --------------------------------------------

echo "" | sudo mariadb -u root -p <<EOF
USE mysql;
CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${mySQLPassword}';
CREATE DATABASE panel;
GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION;
EXIT;
EOF

# --------------------------------------------

sudo cp .env.example .env
sudo COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
sudo php artisan key:generate --force

# --------------------------------------------
