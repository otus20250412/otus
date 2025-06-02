#!/bin/bash

# Конфигурационные параметры
MASTER_IP="192.168.1.100"
SLAVE_IP="192.168.1.101"
SLAVE_SSH_USER="root"
SLAVE_SSH_PASS="111111"
MYSQL_ROOT_PASS="Testpass1$"
REPL_USER="replicator"
REPL_PASS="strong_repl_password"
DB_NAME="Otus_test"
GIT_REPO="https://[personal access token]@github.com/otus20250412/otus.git"
BACKUP_DIR="/tmp/mysql_backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql"
ARCHIVE_FILE="${BACKUP_FILE}.tar.gz"
GIT_CLONE_DIR="/tmp/otus_repo"

# Функция для выполнения команд на слейве через SSH
execute_on_slave() {
    sshpass -p "$SLAVE_SSH_PASS" ssh -o StrictHostKeyChecking=no "${SLAVE_SSH_USER}@${SLAVE_IP}" "$@"
}

# Функция для проверки ошибок
check_error() {
    if [ $? -ne 0 ]; then
        echo "Ошибка: $1"
        exit 1
    fi
}

execute_on_slave "git config --global user.email 'P_A_V_L_I_K@mail.ru'"
execute_on_slave "git config --global user.name 'Miskevich Pavel'"

echo "1. Останавливаем репликацию на слейве"
execute_on_slave "mysql -u root -p'${MYSQL_ROOT_PASS}' -e 'STOP SLAVE;'"
check_error "Не удалось остановить репликацию"

echo "2. Делаем бекап БД ${DB_NAME}"
execute_on_slave "mkdir -p ${BACKUP_DIR}"
execute_on_slave "mysqldump -u root -p'${MYSQL_ROOT_PASS}' --databases ${DB_NAME} > ${BACKUP_FILE}"
check_error "Не удалось создать бекап базы данных"

echo "3. Архивируем бэкап"
execute_on_slave "tar -czvf ${ARCHIVE_FILE} ${BACKUP_FILE}"
check_error "Не удалось архивировать бекап"

echo "4. Делаем push в репозиторий GitHub"
execute_on_slave "rm -rf ${GIT_CLONE_DIR} && mkdir -p ${GIT_CLONE_DIR}"
execute_on_slave "git clone ${GIT_REPO} ${GIT_CLONE_DIR}"
execute_on_slave "cp ${ARCHIVE_FILE} ${GIT_CLONE_DIR}/"
execute_on_slave "cd ${GIT_CLONE_DIR} && git add . && git commit -m 'Add MySQL backup ${TIMESTAMP}' && git push origin master"
check_error "Не удалось выполнить push в репозиторий GitHub"

echo "5. Возобновляем репликацию"
execute_on_slave "mysql -u root -p'${MYSQL_ROOT_PASS}' -e 'START SLAVE;'"
check_error "Не удалось возобновить репликацию"

echo "6. Проверяем работу репликации на SLAVE"
REPL_STATUS=$(execute_on_slave "mysql -u root -p'${MYSQL_ROOT_PASS}' -e 'SHOW SLAVE STATUS\G' | grep -E 'Slave_IO_Running|Slave_SQL_Running'")
echo "Статус репликации:"
echo "$REPL_STATUS"

# Проверяем, что оба процесса репликации работают
if echo "$REPL_STATUS" | grep -q "Yes"; then
    echo "Репликация работает нормально"
else
    echo "Внимание: есть проблемы с репликацией!"
    exit 1
fi

echo "Все операции успешно завершены"
