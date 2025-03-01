emailAddress=""
mySQLPassword=""
websiteDomain=""

cd /var/www/pterodactyl

{
    echo "127.0.0.1", # Redis Host
    echo "3306",
    echo "panel",
    echo "pterodactyl",
    echo "${mySQLPassword}" # Redis Password
} | sudo php artisan p:environment:database
