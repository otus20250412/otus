#!/bin/bash

# Проверка прав root
if [ "$(id -u)" -ne 0 ]; then
  echo "Запустите скрипт с правами root: sudo $0" >&2
  exit 1
fi

# Обновление системы
apt update && apt upgrade -y
apt install mc

# Установка компонентов
apt install -y nginx apache2 mysql-server php libapache2-mod-php php-mysql

MYSQL_USER="root"
NEW_PASS="Testpass1$"

# Выполнение SQL команд
mysql -u"$MYSQL_USER" -e "
ALTER USER 'root'@'localhost' IDENTIFIED WITH 'caching_sha2_password' BY '$NEW_PASS';
CREATE DATABASE IF NOT EXISTS Otus_test;
USE Otus_test;
CREATE TABLE IF NOT EXISTS request_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    request_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    source_ip VARCHAR(45) NOT NULL,
    request_url VARCHAR(255) NOT NULL,
    destination_port INT NOT NULL,
    user_agent VARCHAR(255),
    referrer VARCHAR(255)
);
"

# Полная очистка дефолтных конфигов
rm -f /etc/nginx/sites-enabled/*
rm -f /etc/apache2/sites-enabled/*

# Настройка Apache
echo "ServerName localhost" > /etc/apache2/conf-available/servername.conf
a2enconf servername

echo "# Apache ports" > /etc/apache2/ports.conf
for port in 8080 8081 8082; do
  echo "Listen $port" >> /etc/apache2/ports.conf
  
  # Создаем контент для каждого порта
  webroot="/var/www/port-$port"
  mkdir -p $webroot
  
  cat > $webroot/index.php <<EOF
<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Данные для подключения к MySQL (ЗАМЕНИТЕ НА СВОИ!)
\$db_host = 'localhost';
\$db_user = 'root';
\$db_pass = 'Testpass1$';
\$db_name = 'Otus_test';

// Подключение к БД
try {
    \$conn = new PDO("mysql:host=\$db_host;dbname=\$db_name", \$db_user, \$db_pass);
    \$conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException \$e) {
    die("Ошибка подключения к MySQL: " . \$e->getMessage());
}

// Запись данных в БД
try {
    \$source_ip = \$_SERVER['REMOTE_ADDR'];
    \$request_url = \$_SERVER['REQUEST_URI'];
    \$destination_port = $port; // Здесь порт вставляется из bash-переменной
    \$user_agent = \$_SERVER['HTTP_USER_AGENT'] ?? 'Unknown';
    \$referrer = \$_SERVER['HTTP_REFER'] ?? 'None';

    \$sql = "INSERT INTO request_logs (source_ip, request_url, destination_port, user_agent, referrer)
            VALUES (?, ?, ?, ?, ?)";
    \$stmt = \$conn->prepare(\$sql);
    \$stmt->execute([\$source_ip, \$request_url, \$destination_port, \$user_agent, \$referrer]);

    // Получение логов
    \$logs = \$conn->query("SELECT * FROM request_logs ORDER BY request_time DESC LIMIT 50")->fetchAll();
} catch (PDOException \$e) {
    die("Ошибка SQL: " . \$e->getMessage());
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>Port $port</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h1>Порт: $port</h1>

    <h2>История запросов</h2>
    <table>
        <tr>
            <th>Время</th>
            <th>IP</th>
            <th>Порт</th>
            <th>User Agent</th>
            <th>Referrer</th>
        </tr>
        <?php foreach (\$logs as \$log): ?>
        <tr>
            <td><?= htmlspecialchars(\$log['request_time']) ?></td>
            <td><?= htmlspecialchars(\$log['source_ip']) ?></td>
            <td><?= htmlspecialchars(\$log['destination_port']) ?></td>
            <td><?= htmlspecialchars(substr(\$log['user_agent'], 0, 30)) ?></td>
            <td><?= htmlspecialchars(\$log['referrer']) ?></td>
        </tr>
        <?php endforeach; ?>
    </table>
</body>
</html>
EOF

  # Конфиг виртуального хоста
  cat > /etc/apache2/sites-available/port-$port.conf <<EOF
<VirtualHost *:$port>
    DocumentRoot $webroot
    ErrorLog \${APACHE_LOG_DIR}/error-$port.log
    CustomLog \${APACHE_LOG_DIR}/access-$port.log combined
    
    <Directory $webroot>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

  a2ensite port-$port.conf
done

# Настройка Nginx
cat > /etc/nginx/conf.d/load-balancer.conf <<'EOF'
upstream backend {
    server 127.0.0.1:8080;
    server 127.0.0.1:8081;
    server 127.0.0.1:8082;
}

server {
    listen 80 default_server;
    server_name _;
    
    # Отключаем доступ к корневой директории Nginx
    location = / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Обработка всех остальных запросов
    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    # Прямой доступ к конкретным серверам
    location ~ ^/port(8080|8081|8082)/?$ {
        proxy_pass http://127.0.0.1:$1/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

# Удаляем дефолтный сайт Nginx
rm -f /etc/nginx/sites-enabled/default

# Настройка прав
chown -R www-data:www-data /var/www/port-*
chmod -R 755 /var/www/port-*

# Перезапуск служб
systemctl restart apache2
systemctl restart nginx
systemctl enable apache2 nginx mysql

# Проверка
echo "
Настройка завершена!

Проверьте работу:
1. Балансировка:       http://localhost/
   (обновите несколько раз чтобы увидеть разные порты)

2. Прямой доступ:
   http://localhost/port8080
   http://localhost/port8081
   http://localhost/port8082

3. Проверка портов:
   netstat -tulnp | grep -E '80|8080|8081|8082'
"