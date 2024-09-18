#!/bin/bash

echo "Deleting old app"
sudo rm -rf /home/ubuntu/fast_api_to-deploy

echo "Creating app folder"
sudo mkdir -p /home/ubuntu/fast_api_to-deploy

echo "Moving files to app folder"
sudo mv /home/ubuntu/temporary/* /home/ubuntu/fast_api_to-deploy
sudo rm -r /home/ubuntu/temporary

echo "Navigate to the app directory"
cd /home/ubuntu/fast_api_to-deploy
sudo mv env .env

sudo apt-get update

echo "Installing python and pip"
sudo apt-get install -y python3 python3-pip

echo "Add rights to app folder"
sudo chown -R ubuntu:ubuntu /home/ubuntu/fast_api_to-deploy/
sudo chmod -R 755 /home/ubuntu/fast_api_to-deploy/

echo "Create venv and activate it"
cd /home/ubuntu/fast_api_to-deploy
sudo apt install -y python3.12-venv
sudo python3 -m venv venv
sudo chown -R ubuntu:ubuntu /home/ubuntu/fast_api_to-deploy/venv/
sudo chmod -R 755 /home/ubuntu/fast_api_to-deploy/venv/
source /home/ubuntu/fast_api_to-deploy/venv/bin/activate

echo "Install application dependencies from requirements.txt"
python3 -m pip install --upgrade pip
python3 -m pip install -r requirements.txt

echo "Update and install Nginx if not already installed"
if ! command -v nginx > /dev/null; then
    echo "Installing Nginx"
    sudo apt-get update
    sudo apt-get install -y nginx
fi

echo "Configure Nginx to act as a reverse proxy if not already configured"
if [ ! -f /etc/nginx/sites-available/fastapi_nginx.conf ]; then
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo bash -c 'cat > /etc/nginx/sites-available/fastapi_nginx.conf <<EOF
server {
    listen 80;
    server_name 13.49.46.150;

    location / {
        proxy_pass http://127.0.0.1:8000;
    }
}
EOF'

    sudo ln -s /etc/nginx/sites-available/fastapi_nginx.conf /etc/nginx/sites-enabled
    sudo systemctl restart nginx
else
    echo "Nginx reverse proxy configuration already exists."
fi



echo "Configure Uvicorn service if not already configured"
if [ ! -f /etc/systemd/system/uvicorn.service ]; then
    sudo bash -c 'cat > /etc/systemd/system/uvicorn.service <<EOF
[Unit]
Description=Uvicorn instance to serve my FastAPI app
After=network.target

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/fast_api_to-deploy
ExecStart=/home/ubuntu/fast_api_to-deploy/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --workers 3
Restart=always
Environment="PATH=/home/ubuntu/fast_api_to-deploy/venv/bin"

[Install]
WantedBy=multi-user.target
EOF'

    echo "Reload daemons"
    sudo systemctl daemon-reload
    echo "Starting uvicorn service"
    sudo systemctl start uvicorn
    echo "Uvicorn started successfully 🚀"
else
    echo "Uvicorn service configuration already exists. Restart uvicorn service."
    sudo systemctl restart uvicorn.service
    echo "Uvicorn restarted successfully 🚀"
fi