#!/bin/bash

# Проверяем, выполняется ли скрипт с правами root
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт должен быть запущен с правами root" >&2
    exit 1
fi

# Определяем активный сетевой интерфейс
INTERFACE=$(ip route | awk '/default/ {print $5}' | head -n1)
[ -z "$INTERFACE" ] && INTERFACE="enp0s3"  # Используем enp0s3 как fallback

# Создаем/редактируем файл конфигурации netplan с правильными правами
cat > /tmp/01-netcfg.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses: [192.168.1.100/24]
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [192.168.1.1, 8.8.8.8, 8.8.4.4]
EOF

# Копируем с правильными правами
mv /tmp/01-netcfg.yaml /etc/netplan/01-netcfg.yaml
chmod 600 /etc/netplan/01-netcfg.yaml

# Применяем изменения netplan
netplan apply

# Перезапускаем сетевые службы
systemctl restart systemd-networkd
systemctl restart systemd-resolved

# Проверяем текущие настройки
echo -e "\nТекущие сетевые интерфейсы:"
ip addr show

echo -e "\nТекущая таблица маршрутизации:"
ip route show

# Проверяем соединение
echo -e "\nПроверка DNS..."
nslookup google.com

echo -e "\nПроверка соединения с google.com..."
ping -c 4 google.com