#!/bin/bash

# Конфигурационные параметры
MYSQL_ROOT_PASS="Testpass1$"  # Пароль root MySQL
GIT_REPO="https://[personal access token]@github.com/otus20250412/otus.git"
LOCAL_WORK_DIR="/home/vboxuser"
GIT_CLONE_DIR="$LOCAL_WORK_DIR/repo"
EXTRACT_DIR="$LOCAL_WORK_DIR/extracted"

# Функция для проверки ошибок
check_error() {
    if [ $? -ne 0 ]; then
        echo "Ошибка: $1"
        exit 1
    fi
}

echo "=============================================="
echo "Скрипт восстановления MySQL из бекапа в GitHub"
echo "Выполняется на сервере: $(hostname)"
echo "IP адрес: $(hostname -I | awk '{print $1}')"
echo "=============================================="

echo "1. Подготовка рабочей директории"
#sudo rm -rf "$LOCAL_WORK_DIR"
sudo mkdir -p "$LOCAL_WORK_DIR"
check_error "Не удалось подготовить рабочую директорию"
#sudo chown -R $(whoami):$(whoami) "$LOCAL_WORK_DIR"
sudo chown -R vboxuser:vboxuser /home/vboxuser/

echo "2. Клонирование репозитория с бекапами"
git clone "$GIT_REPO" "$GIT_CLONE_DIR"
check_error "Не удалось клонировать репозиторий"

echo "3. Поиск последнего бекапа"
LATEST_BACKUP=$(ls -t "$GIT_CLONE_DIR"/*.tar.gz | head -n 1)
check_error "Не удалось найти бекапы в репозитории"

if [ -z "$LATEST_BACKUP" ]; then
    echo "Ошибка: не найдены файлы бекапов в репозитории"
    exit 1
fi

echo "Найден последний бекап: $LATEST_BACKUP"

echo "4. Извлечение бекапа из архива"
mkdir -p "$EXTRACT_DIR"
tar -xzvf "$LATEST_BACKUP" -C "$EXTRACT_DIR"
check_error "Не удалось извлечь бекап из архива"

BACKUP_SQL=$(find "$EXTRACT_DIR" -name "*.sql" | head -n 1)
check_error "Не удалось найти SQL файл в архиве"

if [ -z "$BACKUP_SQL" ]; then
    echo "Ошибка: не найден SQL файл в распакованном архиве"
    exit 1
fi

echo "Найден SQL файл: $BACKUP_SQL"

echo "5. Восстановление базы данных из бекапа"
#echo "Удаление существующей базы данных (если есть)"
#mysql -u root -p"${MYSQL_ROOT_PASS}" -e "DROP DATABASE IF EXISTS Otus_test;"
#check_error "Не удалось удалить существующую базу данных"

echo "Создание новой базы данных, если надо"
mysql -u root -p"${MYSQL_ROOT_PASS}" -e "CREATE DATABASE IF NOT EXISTS Otus_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
check_error "Не удалось создать новую базу данных"

echo "Импорт данных из бекапа"
mysql -u root -p"${MYSQL_ROOT_PASS}" Otus_test < "$BACKUP_SQL"
check_error "Не удалось восстановить базу данных из бекапа"

echo "6. Проверка восстановленной базы данных"
DB_CHECK=$(mysql -u root -p"${MYSQL_ROOT_PASS}" -e "SHOW DATABASES LIKE 'Otus_test';" | grep -o Otus_test)
check_error "Не удалось проверить восстановленную базу данных"

TABLE_COUNT=$(mysql -u root -p"${MYSQL_ROOT_PASS}" Otus_test -e "SHOW TABLES;" | wc -l)
check_error "Не удалось проверить таблицы в восстановленной базе"

if [ "$DB_CHECK" == "Otus_test" ] && [ "$TABLE_COUNT" -gt 0 ]; then
    echo "База данных Otus_test успешно восстановлена!"
    echo "Количество таблиц в базе: $((TABLE_COUNT-1))"
else
    echo "Ошибка: база данных Otus_test не была восстановлена или не содержит таблиц"
    exit 1
fi

echo "7. Очистка временных файлов"
sudo rm -rf "$LOCAL_WORK_DIR"
check_error "Не удалось очистить временные файлы"

echo "=============================================="
echo "Восстановление из бекапа успешно завершено!"
echo "=============================================="
