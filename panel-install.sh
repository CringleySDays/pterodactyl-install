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
"
read execution

if [ execution === "1"]; then 
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

# sudo sed -i 's/^# requirepass foobared/requirepass pi/' /etc/redis/redis.conf

elif [ execution === "2"]; then

redis-cli <<EOF
CONFIG SET requirepass ${mySQLPassword}
AUTH ${mySQLPassword}
exit
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
    echo "127.0.0.1" # Redis Host
    echo "${mySQLPassword}" # Redis Password
    echo "6379"
} | sudo php artisan p:environment:setup

{
    echo "127.0.0.1" # Redis Host
    echo "3306"
    echo "panel"
    echo "pterodactyl"
    echo "${mySQLPassword}" # Redis Password
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
    echo "${panelPassword}" # Panel Password
} | sudo php artisan p:user:make

sudo chown -R www-data:www-data /var/www/pterodactyl/*

# --------------------------------------------

# (crontab -l | grep -v -F "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1" ; echo "* * * * * php /var/www/pterodactyl/artisan schedule:run >> /dev/null 2>&1") | sudo crontab -e
# TODO: This one needs to be broken off since the above needs a human intervention.

elif [ execution === "3"]; then

tee /etc/systemd/system/pteroq.service <<EOF
# Pterodactyl Queue Worker File
# ----------------------------------

[Unit]
Description=Pterodactyl Queue Worker
After=redis-server.service

[Service]
# On some systems the user and group might be different.
# Some systems use `apache` or `nginx` as the user and group.
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

else
echo "Invalid input. Please try again."

fi

sudo ln -s /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
sudo systemctl restart nginx

# --------------------------------------------

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

# --------------------------------------------
