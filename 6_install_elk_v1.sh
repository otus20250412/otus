#!/bin/bash

# Проверка на root-права
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт должен быть запущен с правами root" >&2
    exit 1
fi

# Директория с пакетами
PKG_DIR="/home/vboxuser"

# Установка Elasticsearch
echo "Установка Elasticsearch..."
dpkg -i "${PKG_DIR}/elasticsearch-8.9.1-amd64.deb"
systemctl daemon-reload
systemctl enable elasticsearch
systemctl start elasticsearch

# Установка Kibana
echo "Установка Kibana..."
dpkg -i "${PKG_DIR}/kibana-8.9.1-amd64.deb"

# Настройка Kibana
echo "Настройка Kibana..."
cat > /etc/kibana/kibana.yml <<EOL
server.port: 5601
server.host: "0.0.0.0"
elasticsearch.hosts: ["http://localhost:9200"]
EOL

systemctl enable kibana
systemctl start kibana

# Установка Filebeat
echo "Установка Filebeat..."
dpkg -i "${PKG_DIR}/filebeat-8.9.1-amd64.deb"

# Настройка интеграции Filebeat с Kibana и Elasticsearch
echo "Настройка Filebeat..."

# 1. Загрузка готовых dashboard и настроек в Kibana
filebeat setup --dashboards

# 2. Настройка модуля nginx
filebeat modules enable nginx

# 3. Конфигурация Filebeat для отправки данных в Elasticsearch
cat > /etc/filebeat/filebeat.yml <<EOL
filebeat.inputs:
- type: filestream
  enabled: false

filebeat.config.modules:
  path: \${path.config}/modules.d/*.yml
  reload.enabled: false

setup.template.settings:
  index.number_of_shards: 1

output.elasticsearch:
  hosts: ["localhost:9200"]

processors:
  - add_host_metadata:
      when.not.contains.tags: forwarded
  - add_cloud_metadata: ~
  - add_docker_metadata: ~
  - add_kubernetes_metadata: ~
EOL

# 4. Запуск Filebeat
systemctl enable filebeat
systemctl start filebeat

echo "Установка и настройка завершены!"
echo "Kibana доступна по адресу: http://<ваш_IP>:5601"
echo "Для просмотра логов nginx:"
echo "1. Откройте Kibana"
echo "2. Перейдите в меню Analytics -> Discover"
echo "3. Выберите индекс 'filebeat-*'"