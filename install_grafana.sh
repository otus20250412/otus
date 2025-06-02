#!/bin/bash

echo "Установка Grafana..."

# Директория с пакетами
PKG_DIR="/home/vboxuser"

# Устанавливаем необходимые пакеты
sudo apt-get install -y apt-transport-https software-properties-common wget

# Добавляем репозиторий Grafana
#sudo mkdir -p /etc/apt/keyrings/
#wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
#echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list

# Обновляем пакеты и устанавливаем Grafana
sudo apt-get update
#sudo apt-get install -y grafana
sudo dpkg -i "${PKG_DIR}/grafana_10.4.1_amd64.deb"
sudo apt-get install -f -y

# Запускаем Grafana
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

echo "Grafana установлена и запущена. Проверьте статус:"
echo "sudo systemctl status grafana-server"
echo "Веб-интерфейс доступен на http://localhost:3000"
echo "Логин/пароль по умолчанию: admin/admin"