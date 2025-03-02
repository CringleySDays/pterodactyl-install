#!/bin/bash
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

echo "Please enter the following for which execution to follow:

[1] Install the panel from start (If you have not installed this before).
[2] To finish installing the panel (After you enter the password in requirepass).
[3] Finalise the panel installation (After you finish the crontab tasks).
[4] Start wings installation (After you finish the Swap with Docker tasks).
[5] Start the wings service (After you finish setting up the wings config file).

"
read -r execution

if [ "$execution" = "1" ]; then 
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
    cd /var/www/pterodactyl || { echo "Failed to change directory to /var/www/pterodactyl"; exit 1; }

    sudo curl -Lo panel.tar.gz https://github.com/pterodactyl/panel/releases/latest/download/panel.tar.gz
    sudo tar -xzvf panel.tar.gz
    sudo chmod -R 755 storage/* bootstrap/cache/

    # --------------------------------------------

    sudo cp .env.example .env
    sudo COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
    sudo php artisan key:generate --force

    # --------------------------------------------

    echo "" | sudo mariadb -u root -p <<EOF
USE mysql; 
CREATE USER 'pterodactyl'@'127.0.0.1' IDENTIFIED BY '${mySQLPassword}'; 
CREATE DATABASE panel; 
GRANT ALL PRIVILEGES ON panel.* TO 'pterodactyl'@'127.0.0.1' WITH GRANT OPTION; 
EXIT; 
EOF


    # --------------------------------------------
    echo "
    Please run the following command to finish the first part of the installation before moving onto the next part of the install.

    sudo nano /etc/redis/redis.conf

    Then find the following line:
    # requirepass foobared

    Uncomment the line and change the password to the following:
    requirepass ${mySQLPassword}

    Then save and exit the redis.conf file.
    "
    exit 0

elif [ "$execution" = "2" ]; then

        redis-cli <<EOF
CONFIG SET requirepass ${mySQLPassword}
EOF


    # --------------------------------------------

    {
        echo "${emailAddress}"
        echo "${websiteDomain}"
        echo "Europe/London"
        echo "redis"
        echo "redis"
        echo "redis"
        echo "yes"
        echo "no"
        echo "127.0.0.1"
        echo "${mySQLPassword}"
        echo "6379"
    } | sudo php artisan p:environment:setup

    {
        echo "127.0.0.1"
        echo "3306"
        echo "panel"
        echo "pterodactyl"
        echo "${mySQLPassword}"
    } | sudo php artisan p:environment:database


    {
        echo "sendmail"
        echo "${emailAddress}"
        echo ""
    } | sudo php artisan p:environment:mail

    # --------------------------------------------

    sudo php artisan migrate --seed --force

    {
        echo "yes"
        echo "${emailAddress}"
        echo "${panelUsername}"
        echo "${panelFirstName}"
        echo "${panelLastName}"
        echo "${panelPassword}"
    } | sudo php artisan p:user:make

    sudo chown -R www-data:www-data /var/www/pterodactyl/*

# --------------------------------------------

    echo "
    Please run the following command to finish the first part of the installation before moving onto the next part of the install.
    
    sudo crontab -e

    Then add the following line to the crontab file:
    * * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1

    Then save and exit the crontab file.
    "

    exit 0

elif [ "$execution" = "3" ]; then

    tee /etc/systemd/system/pteroq.service <<EOF
# Pterodactyl Queue Worker File
# ----------------------------------

[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
User=www-data
Group=www-data
Restart=always
ExecStart=/usr/bin/php /var/www/pterodactyl/artisan queue:work --queue=high,standard,low --sleep=3 --tries=3
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl enable --now redis-server
    sudo systemctl enable --now pteroq.service

    # --------------------------------------------

    sudo rm /etc/nginx/sites-enabled/default
    tee /etc/nginx/sites-available/pterodactyl.conf <<EOF
server {
# Replace the example <domain> with your domain name or IP address
listen 80;
server_name ${websiteDomain};

root /var/www/pterodactyl/public;
index index.html index.htm index.php;
charset utf-8;

location / {
    try_files $uri $uri/ /index.php?$query_string;
}

location = /favicon.ico { access_log off; log_not_found off; }
location = /robots.txt  { access_log off; log_not_found off; }

access_log off;
error_log  /var/log/nginx/pterodactyl.app-error.log error;

# allow larger file uploads and longer script runtimes
client_max_body_size 100m;
client_body_timeout 120s;

sendfile off;

location ~ \.php$ {
    fastcgi_split_path_info ^(.+\.php)(/.+)$;
    fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    fastcgi_index index.php;
    include fastcgi_params;
    fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    fastcgi_param HTTP_PROXY "";
    fastcgi_intercept_errors off;
    fastcgi_buffer_size 16k;
    fastcgi_buffers 4 16k;
    fastcgi_connect_timeout 300;
    fastcgi_send_timeout 300;
    fastcgi_read_timeout 300;
}

location ~ /\.ht {
    deny all;
}
}
EOF

    sudo ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
    sudo systemctl restart nginx

    echo "You need to run this following command to finish the panel install"
    echo "sudo /etc/default/grub"
    echo "Then ctrl + w and search for GRUB_CMDLINE_LINUX_DEFAULT"
    echo "Add the following within the strings. If there is data within the string, add in a comma and then the following: swapaccount=1"
    echo ""
    echo "For example: GRUB_CMDLINE_LINUX_DEFAULT='quiet splash, swapaccount=1'"
    echo ""
    echo "Add it to GRUB_CMDLINE_LINUX as well following the example if there is data included in the strings."

    echo "Then run the following command: sudo update-grub"
    echo "Then reboot the server with the following command: sudo reboot"


elif [ "$execution" = "4" ]; then 
    # --------------------------------------------

    sudo mkdir -p /etc/pterodactyl
    sudo curl -L -o /usr/local/bin/wings "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
    sudo chmod u+x /usr/local/bin/wings

    echo "Go to http://${websiteDomain} to access the panel. Login with your credentials.

    Click the setting cog icon, top right. Create a location and then a node. Finish setting it up and then head to the configuration section on the top and copy the configuration text.
    
    Then run the following command to finish the wings installation:
    
    sudo nano /etc/pterodactyl/config.yml

    Then paste the configuration text into the config.yml file and save and exit the file.
    "
    exit 0

    # --------------------------------------------


elif [ "$execution" = "5" ]; then
    sudo wings --debug

    tee /etc/systemd/system/wings.service <<EOF
[Unit]
Description=Pterodactyl Wings Daemon
After=docker.service
Requires=docker.service
PartOf=docker.service

[Service]
User=root
WorkingDirectory=/etc/pterodactyl
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=180
StartLimitBurst=30
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl enable --now wings

else
    echo "Invalid input. Please try again."
    
fi
