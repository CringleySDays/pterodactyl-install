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
