#!/bin/bash

echo "deleting old app"
sudo rm -rf /home/ubuntu/fast_api_to-deploy

echo "creating app folder"
sudo mkdir -p /var/www/fast_api_to-deploy

echo "moving files to app folder"
sudo mv  * /home/ubuntu/fast_api_to-deploy

# Navigate to the app directory
cd /home/ubuntu/fast_api_to-deploy
sudo mv env .env

sudo apt-get update
echo "installing python and pip"
sudo apt-get install -y python3 python3-pip

# Create venv and activate it
cd /home/ubuntu/fast_api_to-deploy
sudo apt install -y python3.12-venv
sudo python3 -m venv venv
source  venv/bin/activate

# Install application dependencies from requirements.txt
echo "Install application dependencies from requirements.txt"
sudo pip3 install -r requirements.txt


# Update and install Nginx if not already installed
if ! command -v nginx > /dev/null; then
    echo "Installing Nginx"
    sudo apt-get update
    sudo apt-get install -y nginx
fi

# Configure Nginx to act as a reverse proxy if not already configured
if [ ! -f /etc/nginx/sites-available/fastapi_nginx ]; then
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo bash -c 'cat > /etc/nginx/sites-available/fastapi_nginx <<EOF
server {
    listen 80;
    server_name 51.20.255.245;

    location / {
        proxy_pass http://127.0.0.1:8000;
    }
}
EOF'

    sudo ln -s /etc/nginx/sites-available/fastapi_nginx /etc/nginx/sites-enabled
    sudo systemctl restart nginx
else
    echo "Nginx reverse proxy configuration already exists."
fi

# Stop any existing Gunicorn process
sudo pkill gunicorn
sudo rm -rf myapp.sock

# # Start Gunicorn with the Flask application
# # Replace 'server:app' with 'yourfile:app' if your Flask instance is named differently.
# # gunicorn --workers 3 --bind 0.0.0.0:8000 server:app &
echo "starting gunicorn"
sudo gunicorn --workers 3 --bind unix:myapp.sock  main:app --daemon
#sudo gunicorn --workers 3 --bind unix:myapp.sock  server:app --user www-data --group www-data --daemon
echo "started gunicorn 🚀"