#!/bin/bash

# Проверка прав root
if [ "$(id -u)" -ne 0 ]; then
  echo "Этот скрипт должен быть запущен с правами root" >&2
  exit 1
fi

# Конфигурация (ЗАПОЛНИТЕ ЭТИ ДАННЫЕ ПЕРЕД ЗАПУСКОМ!)
MASTER_IP="192.168.1.100"
SLAVE_IP="192.168.1.101"
SLAVE_SSH_PASS="111111"      # Пароль root для SSH на слейве
MYSQL_ROOT_PASS="Testpass1$" # Пароль root MySQL
REPL_USER="replicator"
REPL_PASS="strong_repl_password"
DB_NAME="Otus_test"

# Проверка обязательных параметров
if [ -z "$SLAVE_SSH_PASS" ] || [ -z "$MYSQL_ROOT_PASS" ]; then
  echo "ОШИБКА: Не заданы обязательные пароли!" >&2
  echo "Перед запуском отредактируйте скрипт и укажите:" >&2
  echo "1. SLAVE_SSH_PASS - пароль root для SSH на слейве" >&2
  echo "2. MYSQL_ROOT_PASS - пароль root MySQL" >&2
  exit 1
fi

# Функция для безопасного выполнения команд MySQL
function mysql_exec() {
  MYSQL_PWD="$MYSQL_ROOT_PASS" mysql -uroot -e "$1" 2>/dev/null || {
    echo "ОШИБКА MySQL: Не удалось выполнить команду: $1" >&2
    return 1
  }
}

# Функция для выполнения команд на слейве через SSH
function ssh_exec() {
  sshpass -p "$SLAVE_SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@"$SLAVE_IP" "$1" || {
    echo "ОШИБКА SSH: Не удалось выполнить команду на слейве: $1" >&2
    return 1
  }
}

# 1. Настройка мастера
echo "=== НАСТРОЙКА МАСТЕРА ($MASTER_IP) ==="
apt-get install -y sshpass

# Проверка подключения к MySQL
if ! mysql_exec "SELECT 1"; then
  echo "ОШИБКА: Не удалось подключиться к MySQL на мастере с указанным паролем" >&2
  echo "Проверьте MYSQL_ROOT_PASS и попробуйте снова" >&2
  exit 1
fi

# Конфигурация мастера
echo "Конфигурация MySQL мастера..."
hostnamectl set-hostname mysql-master
cat > /etc/mysql/mysql.conf.d/replication.cnf <<EOF
[mysqld]
server-id = 1
log_bin = /var/log/mysql/mysql-bin.log
binlog_do_db = $DB_NAME
bind-address = $MASTER_IP
EOF

systemctl restart mysql || {
  echo "ОШИБКА: Не удалось перезапустить MySQL на мастере" >&2
  exit 1
}

# Настройка репликации
echo "Настройка пользователя репликации..."
mysql_exec "CREATE USER IF NOT EXISTS '$REPL_USER'@'$SLAVE_IP' IDENTIFIED BY '$REPL_PASS';"
mysql_exec "GRANT REPLICATION SLAVE ON *.* TO '$REPL_USER'@'$SLAVE_IP';"
mysql_exec "ALTER USER '$REPL_USER'@'$SLAVE_IP' IDENTIFIED WITH mysql_native_password BY '$REPL_PASS';"
mysql_exec "FLUSH PRIVILEGES;"

# Создание тестовой БД
mysql_exec "CREATE DATABASE IF NOT EXISTS $DB_NAME;"
mysql_exec "USE $DB_NAME; CREATE TABLE IF NOT EXISTS request_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    request_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_ip VARCHAR(45) NOT NULL,
    request_url VARCHAR(255) NOT NULL,
    destination_port INT NOT NULL,
    user_agent VARCHAR(255),
    referrer VARCHAR(255)
);"

# Получение позиции репликации
echo "Получение позиции репликации..."
mysql_exec "FLUSH TABLES WITH READ LOCK;"
MASTER_STATUS=$(mysql_exec "SHOW MASTER STATUS\G")
LOG_FILE=$(echo "$MASTER_STATUS" | grep "File:" | awk '{print $2}')
LOG_POS=$(echo "$MASTER_STATUS" | grep "Position:" | awk '{print $2}')
mysql_exec "UNLOCK TABLES;"

# Создание дампа БД
echo "Создание дампа БД..."
DUMP_FILE="/tmp/replication_dump.sql"
MYSQL_PWD="$MYSQL_ROOT_PASS" mysqldump -uroot $DB_NAME > $DUMP_FILE || {
  echo "ОШИБКА: Не удалось создать дамп базы данных" >&2
  exit 1
}

# 2. Настройка слейва
echo -e "\n=== НАСТРОЙКА СЛЕЙВА ($SLAVE_IP) ==="
ssh_exec "hostnamectl set-hostname mysql-replica"

# Проверка SSH-подключения
if ! ssh_exec "echo 'SSH подключение успешно'"; then
  echo "ОШИБКА: Не удалось подключиться к слейву по SSH" >&2
  echo "Проверьте SLAVE_SSH_PASS и доступность сервера" >&2
  exit 1
fi

# Копирование дампа на слейв
echo "Копирование дампа на слейв..."
sshpass -p "$SLAVE_SSH_PASS" scp -o StrictHostKeyChecking=no $DUMP_FILE root@$SLAVE_IP:/tmp/ || {
  echo "ОШИБКА: Не удалось скопировать дамп на слейв" >&2
  exit 1
}

# Установка MySQL на слейве
echo "Установка MySQL на слейве..."
ssh_exec "apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server" || {
  echo "ОШИБКА: Не удалось установить MySQL на слейве" >&2
  exit 1
}

# Конфигурация слейва
echo "Конфигурация MySQL слейва..."
ssh_exec "cat > /etc/mysql/mysql.conf.d/replication.cnf <<EOF
[mysqld]
server-id = 2
relay-log = /var/log/mysql/mysql-relay-bin.log
log_bin = /var/log/mysql/mysql-bin.log
binlog_do_db = $DB_NAME
read_only = 1
EOF"

ssh_exec "systemctl restart mysql" || {
  echo "ОШИБКА: Не удалось перезапустить MySQL на слейве" >&2
  exit 1
}

# Импорт дампа
echo "Импорт дампа на слейв..."
ssh_exec "mysql -uroot -e \"CREATE DATABASE IF NOT EXISTS $DB_NAME;\"" || {
  echo "ОШИБКА: Не удалось создать БД на слейве" >&2
  exit 1
}

ssh_exec "mysql -uroot $DB_NAME < /tmp/replication_dump.sql && rm /tmp/replication_dump.sql" || {
  echo "ОШИБКА: Не удалось импортировать дамп на слейве" >&2
  exit 1
}

# Настройка репликации
echo "Настройка репликации на слейве..."
ssh_exec "mysql -uroot -e \"STOP SLAVE;\""
ssh_exec "mysql -uroot -e \"CHANGE MASTER TO
  MASTER_HOST='$MASTER_IP',
  MASTER_USER='$REPL_USER',
  MASTER_PASSWORD='$REPL_PASS',
  MASTER_LOG_FILE='$LOG_FILE',
  MASTER_LOG_POS=$LOG_POS;\""

ssh_exec "mysql -uroot -e \"START SLAVE;\"" || {
  echo "ОШИБКА: Не удалось запустить репликацию" >&2
  exit 1
}

# Проверка репликации
echo -e "\nПроверка статуса репликации..."
SLAVE_STATUS=$(ssh_exec "mysql -uroot -e \"SHOW SLAVE STATUS\G\"")
echo "$SLAVE_STATUS" | grep -E "Slave_IO_Running|Slave_SQL_Running|Last_Error"

# Очистка
rm -f $DUMP_FILE

echo -e "\n=== НАСТРОЙКА ЗАВЕРШЕНА ==="
echo "Мастер: $MASTER_IP"
echo "Слейв: $SLAVE_IP"
echo "Пользователь репликации: $REPL_USER"
echo "Тестовая БД: $DB_NAME"