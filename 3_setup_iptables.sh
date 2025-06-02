#!/bin/bash

# Установка необходимых пакетов
sudo apt update
sudo apt install -y iptables-persistent

# Проверяем название службы (в разных версиях Ubuntu может отличаться)
if systemctl list-unit-files | grep -q "netfilter-persistent.service"; then
    SERVICE_NAME="netfilter-persistent"
elif systemctl list-unit-files | grep -q "iptables-persistent.service"; then
    SERVICE_NAME="iptables-persistent"
else
    SERVICE_NAME=""
fi

# Создаем директорию для правил, если её нет
sudo mkdir -p /etc/iptables

# Сбрасываем текущие правила (очищаем)
sudo iptables -F
sudo iptables -X

# Базовые правила
sudo iptables -A INPUT -i lo -j ACCEPT  # Разрешаем локальный интерфейс
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT  # Разрешаем establi>

# Разрешаем нужные порты
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT   # SSH
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT   # HTTP
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT  # HTTPS
sudo iptables -A INPUT -p tcp --dport 3000 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 3306 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 5601 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 9090 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 9100 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 9200 -j ACCEPT

# Запрещаем все остальные входящие соединения
sudo iptables -P INPUT DROP

# Разрешаем все исходящие соединения
sudo iptables -A OUTPUT -j ACCEPT

# Сохраняем правила
sudo iptables-save | sudo tee /etc/iptables/rules.v4 >/dev/null
#sudo ip6tables-save | sudo tee /etc/iptables/rules.v6 >/dev/null

# Применяем правила (для разных версий Ubuntu)
if [ -n "$SERVICE_NAME" ]; then
    sudo systemctl enable $SERVICE_NAME
    sudo systemctl restart $SERVICE_NAME
else
    # Альтернативный способ применения правил
    sudo iptables-restore < /etc/iptables/rules.v4
    #sudo ip6tables-restore < /etc/iptables/rules.v6
fi

echo "Правила iptables успешно настроены и сохранены"
echo "Разрешены порты: 22 (SSH), 80 (HTTP), 443 (HTTPS), 3000, 3306, 5601, 9090, 9100, 9200"
