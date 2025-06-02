#!/bin/bash

# Установка node_exporter
NODE_EXPORTER_VERSION="1.6.1"
NODE_EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"

echo "Установка node_exporter v${NODE_EXPORTER_VERSION}..."

# Создаем пользователя для node_exporter
sudo useradd --no-create-home --shell /bin/false node_exporter

# Скачиваем и распаковываем node_exporter
wget $NODE_EXPORTER_URL
tar xvfz node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
sudo cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64*

# Создаем systemd сервис
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# Запускаем node_exporter
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

echo "node_exporter установлен и запущен. Проверьте статус:"
echo "sudo systemctl status node_exporter"
echo "Метрики доступны на http://localhost:9100/metrics"