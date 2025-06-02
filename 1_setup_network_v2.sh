#!/bin/bash

# Проверяем, выполняется ли скрипт с правами root
if [ "$(id -u)" -ne 0 ]; then
    echo "Этот скрипт должен быть запущен с правами root" >&2
    exit 1
fi

# Определяем активный сетевой интерфейс
INTERFACE=$(ip route | awk '/default/ {print $5}' | head -n1)
[ -z "$INTERFACE" ] && INTERFACE="enp0s3"  # Используем enp0s3 как fallback

# Устанавливаем debconf-utils, если ещё не установлен
sudo apt update
sudo apt install -y debconf-utils

# Задаём автоматический ответ "Нет" на вопрос о сохранении текущих правил IPv4
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | sudo debconf-set-selections

# Задаём автоматический ответ "Нет" на вопрос о сохранении текущих правил IPv6
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | sudo debconf-set-selections

### Настройка needrestart (изменяем только нужные параметры, не перезаписывая весь файл)
# Создаем временный файл для редактирования
cp /etc/needrestart/needrestart.conf /tmp/needrestart.conf.tmp

# Устанавливаем нужные параметры с помощью sed
sed -i "s/^\$nrconf{restart}.*/\$nrconf{restart} = 'a';/" /tmp/needrestart.conf.tmp
sed -i "s/^\$nrconf{kernelhints}.*/\$nrconf{kernelhints} = 0;/" /tmp/needrestart.conf.tmp

# Если параметров не было, добавляем их в конец файла
grep -q "^\$nrconf{restart}" /tmp/needrestart.conf.tmp || echo "\$nrconf{restart} = 'a';" >> /tmp/needrestart.conf.tmp
grep -q "^\$nrconf{kernelhints}" /tmp/needrestart.conf.tmp || echo "\$nrconf{kernelhints} = 0;" >> /tmp/needrestart.conf.tmp

# Копируем обратно с сохранением прав
mv /tmp/needrestart.conf.tmp /etc/needrestart/needrestart.conf
chmod 644 /etc/needrestart/needrestart.conf

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