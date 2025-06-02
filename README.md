# 🚀 OTUS Server Automation Setup

[![2025-06-01-11-46-35.jpg](https://i.postimg.cc/9MrsBJ4y/2025-06-01-11-46-35.jpg)](https://postimg.cc/LYFy9k3s)

![Linux](https://img.shields.io/badge/-Linux-grey?logo=linux)
![OSX](https://img.shields.io/badge/-OSX-black?logo=apple)
![FreeBSD](https://img.shields.io/badge/-FreeBSD-red?logo=freebsd)
![Usage](https://img.shields.io/badge/Usage-System%20resource%20monitor-blue)
![Bash](https://img.shields.io/badge/Bash-v4.4%5E-green?logo=GNU%20bash)
![Python](https://img.shields.io/badge/Python-v3.6%5E-orange?logo=python)
![bashtop_version](https://img.shields.io/github/v/tag/aristocratos/bashtop?label=version)
[![Donate](https://img.shields.io/badge/-Donate-yellow?logo=paypal)](https://paypal.me/aristocratos)
[![Sponsor](https://img.shields.io/badge/-Sponsor-red?logo=github)](https://github.com/sponsors/aristocratos)
[![Coffee](https://img.shields.io/badge/-Buy%20me%20a%20Coffee-grey?logo=Ko-fi)](https://ko-fi.com/aristocratos)

Автоматизированная установка и настройка серверного окружения для курса OTUS.  
Скрипты выполняют полную подготовку среды: от базовой настройки сети до развертывания мониторинга и системы бэкапов.

## 📋 Содержание
- [🚀 Быстрый старт](#-быстрый-старт)
- [⚙️ Последовательность выполнения](#️-последовательность-выполнения)
- [📜 Описание скриптов](#-описание-скриптов)
- [❗ Важные примечания](#-важные-примечания)
- [🔄 Аварийное восстановление](#-аварийное-восстановление)
- [🎉 Завершение установки](#-завершение-установки)

## 🚀 Быстрый старт

```bash
# Переходим в домашнюю директорию
cd /home/vboxuser || { echo "Ошибка: не удалось перейти в /home/vboxuser"; exit 1; }

# Очищаем и клонируем репозиторий
LOCAL_WORK_DIR="/home/vboxuser/otus"
sudo rm -rf "$LOCAL_WORK_DIR"
git clone "https://github.com/otus20250412/otus.git"
cd otus

# Делаем скрипты исполняемыми
chmod +x *.sh

# Запускаем основной процесс установки
./0_full_install.sh
```

## 📜 Описание скриптов

| # | Скрипт | Назначение | Время выполнения |
| - | --------- | ---------------- | ---- |
| 1 | 1_setup_network_v2.sh | Настройка сетевых интерфейсов и правил маршрутизации | 2-5 мин
| 2 | 2_install.sh | Установка и настройка Nginx, Apache2, настройка балансировки нагрузки | 10-15 мин
| 3 | 3_setup_iptables.sh | Конфигурация firewall (iptables) для защиты сервера | 1-2 мин
| 4 | 4_install_mysql.sh | Установка и настройка MySQL/MariaDB, создание пользователей и БД | 5-10 мин
| 5 | 5_install_monitoring.sh | Развертывание стека мониторинга (Prometheus, Node Exporter, Grafana) | 5-7 мин
| 6 | 6_install_elk_v3.sh | Установка и настройка ELK-стека (Elasticsearch, Kibana, Filebeat) для логирования | 10-15 мин
| 7 | 7_backup_slave_and_push.sh | Настройка автоматических бэкапов БД с отправкой в репозиторий | 3-5 мин
| 8 | 8_restore_db_master.sh | Восстановление БД из последнего бэкапа (для аварийных случаев) | 5-10 мин

## ❗Важные примечания

Все скрипты должны выполняться из папки /home/vboxuser/otus

## Требования к системе:
* Ubuntu Server 20.04/22.04 LTS
* Минимум 4GB RAM (рекомендуется 8GB для работы ELK-стека)
* 20GB свободного места на диске
* Доступ в интернет для загрузки пакетов
* Логи выполнения сохраняются в /var/log/otus_setup.log
* Для аутентификации в GitHub используйте personal access token

## Доступные сервисы после установки:

* Веб-сервер: http://ваш-сервер
* Grafana (мониторинг): http://ваш-сервер:3000
* Kibana (логи): http://ваш-сервер:5601
* Prometheus (метрики): http://ваш-сервер:9090
