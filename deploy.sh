#!/bin/bash

set -e # Прерывание выполнения скрипта при ошибке

# Переменные
PROJECT_NAME="fast_api_to-deploy"
PROJECT_DIR="/home/ubuntu/$PROJECT_NAME"
LOGFILE="/var/log/deploy.log"
NGINX_CONF="/etc/nginx/sites-available/${PROJECT_NAME}_nginx.conf"

# Логирование
exec > >(tee -a $LOGFILE) 2>&1

echo "Starting deployment at $(date)"

# Удаление старого приложения с проверкой
if [ -d "$PROJECT_DIR" ]; then
    echo "Deleting old app"
    sudo rm -rf $PROJECT_DIR
fi

# Создание папки для нового приложения
echo "Creating app folder"
sudo mkdir -p $PROJECT_DIR

# Перемещение файлов в папку приложения
echo "Moving files to app folder"
sudo mv /home/ubuntu/temporary/* $PROJECT_DIR && sudo rm -r /home/ubuntu/temporary

# Перемещение env файла
cd $PROJECT_DIR
sudo mv env .env

# Обновление системы
echo "Updating package lists"
sudo apt-get update

# Установка Python и зависимостей
echo "Installing Python and pip"
if ! dpkg -s python3 &>/dev/null; then
    sudo apt-get install -y python3 python3-pip
fi

if ! dpkg -s python3.12-venv &>/dev/null; then
    sudo apt install -y python3.12-venv
fi

# Создание и активация виртуального окружения
echo "Creating and activating virtual environment"
sudo python3 -m venv venv
sudo chown -R ubuntu:ubuntu $PROJECT_DIR/venv/
sudo chmod -R 755 $PROJECT_DIR/venv/
source $PROJECT_DIR/venv/bin/activate

# Установка зависимостей
echo "Installing dependencies"
python3 -m pip install --upgrade pip
python3 -m pip install -r requirements.txt

# Проверка установки и конфигурации Nginx
echo "Checking and configuring Nginx"
if ! command -v nginx > /dev/null; then
    sudo apt-get install -y nginx
fi

if [ ! -f $NGINX_CONF ]; then
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo bash -c "cat > $NGINX_CONF <<EOF
server {
    listen 80;
    server_name ${EC2_HOST};

    location / {
        proxy_pass http://127.0.0.1:8000;
    }
}
EOF"
    sudo ln -s $NGINX_CONF /etc/nginx/sites-enabled
    sudo systemctl restart nginx
else
    echo "Nginx reverse proxy configuration already exists."
fi

# Проверка и настройка Uvicorn
echo "Configuring Uvicorn service"
if [ ! -f /etc/systemd/system/uvicorn.service ]; then
    sudo bash -c "cat > /etc/systemd/system/uvicorn.service <<EOF
[Unit]
Description=Uvicorn instance to serve my FastAPI app
After=network.target

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=$PROJECT_DIR
ExecStart=$PROJECT_DIR/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000 --workers 3
Restart=always
Environment=\"PATH=$PROJECT_DIR/venv/bin\"

[Install]
WantedBy=multi-user.target
EOF"

    echo "Reloading daemons and starting Uvicorn"
    sudo systemctl daemon-reload
    sudo systemctl start uvicorn
else
    echo "Restarting Uvicorn service"
    sudo systemctl restart uvicorn
fi

# Проверка статуса Uvicorn
if systemctl is-active --quiet uvicorn; then
    echo "Uvicorn started successfully"
else
    echo "Uvicorn failed to start" >&2
    exit 1
fi

echo "Deployment completed successfully at $(date)"