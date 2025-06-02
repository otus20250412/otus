#!/bin/bash

# Скрипт для установки и настройки мониторинга
# Работает из директории /home/vboxuser

# Переходим в домашнюю директорию пользователя vboxuser
cd /home/vboxuser || { echo "Ошибка: не удалось перейти в /home/vboxuser"; exit 1; }

# 2. Делаем скрипты исполняемыми
chmod +x install_node_exporter.sh
chmod +x install_prometheus.sh
chmod +x install_grafana.sh

# 3. Запускаем скрипты последовательно
echo "Запуск установки node_exporter..."
./install_node_exporter.sh

echo "Запуск установки Prometheus..."
./install_prometheus.sh

echo "Запуск установки Grafana..."
./install_grafana.sh

echo "Установка завершена!"
echo "Доступные сервисы:"
echo "node_exporter: http://localhost:9100/metrics"
echo "Prometheus:    http://localhost:9090"
echo "Grafana:       http://localhost:3000 (admin/admin)"