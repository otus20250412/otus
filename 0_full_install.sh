#!/bin/bash

# Скрипт для установки и настройки дофига всего по курсу linux для самых маленьких и тупых
# Работает из директории /home/vboxuser

# Переходим в домашнюю директорию пользователя vboxuser
cd /home/vboxuser || { echo "Ошибка: не удалось перейти в /home/vboxuser"; exit 1; }

# очищаем папку репозиотрия, клонируем его и копируем файлы в домашнюю директорию
# LOCAL_WORK_DIR="/home/vboxuser/otus"
# sudo rm -rf "$LOCAL_WORK_DIR"
# git clone "https://[personal access token]@github.com/otus20250412/otus.git"
# cp -a -T /home/vboxuser/otus /home/vboxuser

# 2. Делаем скрипты исполняемыми
chmod +x 1_setup_network_v2.sh
chmod +x 2_install.sh
chmod +x 3_setup_iptables.sh
chmod +x 4_install_mysql.sh
chmod +x 5_install_monitoring.sh
chmod +x 6_install_elk_v3.sh
chmod +x 7_backup_slave_and_push.sh
chmod +x 8_restore_db_master.sh

# Запускаем скрипты последовательно
echo "Запуск установки setup_network.sh..."
./1_setup_network_v2.sh

echo "Запуск установки nginx, apache2, балансировки и вот это вот всё..."
./2_install.sh

echo "Запуск настройки iptables..."
./3_setup_iptables.sh

# раскомментировать при аварином восстановлении
# echo "Установка свежего бекапа"
# ./8_restore_db_master.sh

echo "Запуск установки и настройки MySQL..."
./4_install_mysql.sh

echo "Запуск установки Prometheus, node_exporter, Grafana ..."
./5_install_monitoring.sh

echo "Запуск установки Elasticsearch, Kibana, Filebeat..."
./6_install_elk_v3.sh

echo "Бекап БД и пуш в репозиторий"
./7_backup_slave_and_push.sh
                                               
echo "Установка завершена! Ништяк"
