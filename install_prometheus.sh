#!/bin/bash

# Установка Prometheus
PROMETHEUS_VERSION="2.47.0"
PROMETHEUS_URL="https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"

echo "Установка Prometheus v${PROMETHEUS_VERSION}..."

# Создаем пользователя для Prometheus
sudo useradd --no-create-home --shell /bin/false prometheus

# Скачиваем и распаковываем Prometheus
wget $PROMETHEUS_URL
tar xvfz prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
sudo mkdir -p /etc/prometheus /var/lib/prometheus
sudo cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus \
       prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool /usr/local/bin/
sudo cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/consoles \
           prometheus-${PROMETHEUS_VERSION}.linux-amd64/console_libraries /etc/prometheus/
rm -rf prometheus-${PROMETHEUS_VERSION}.linux-amd64*

# Настраиваем права
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
sudo chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

# Создаем конфигурационный файл
sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF

# Создаем systemd сервис
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

# Запускаем Prometheus
sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

echo "Prometheus установлен и запущен. Проверьте статус:"
echo "sudo systemctl status prometheus"
echo "Веб-интерфейс доступен на http://localhost:9090"