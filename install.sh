emailAddress=""
mySQLPassword=""
websiteDomain=""

cd /var/www/pterodactyl

{
    echo ${emailAddress},
    echo ${websiteDomain},
    echo "Europe/London",
    echo "redis",
    echo "redis",
    echo "redis",
    echo "yes",
    echo "no",
    echo "127.0.0.1", # Redis Host
    echo ${mySQLPassword}, # Redis Password
    echo "6379"
} | sudo php artisan p:environment:setup
