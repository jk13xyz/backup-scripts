#!/bin/bash

BACKUPDIR=$HOME/backup/databases
DAYS=7
TIMESTAMP=$(date +"%Y%m%d%H%M")

CONTAINER=$(docker ps --format '{{.Names}}:{{.Image}}' | grep 'mysql\|mariadb\|postgres' | cut -d":" -f1)

echo -e "Start $TIMESTAMP Backup for Databases: \n"
if [ ! -d $BACKUPDIR ]; then
    mkdir -p $BACKUPDIR
fi

get_database_password_required() {
    case "$1" in
        MYSQL_ROOT_PASSWORD|MYSQL_PASSWORD|MARIADB_ROOT_PASSWORD|MARIADB_PASSWORD|POSTGRES_PASSWORD)
            echo "yes"
            ;;
        *)
            echo "no"
            ;;
    esac
}

for i in $CONTAINER; do

    if docker exec $i printenv MYSQL_USER >/dev/null 2>&1; then
        DATABASE_TYPE="MySQL"
    elif docker exec $i printenv MARIADB_USER >/dev/null 2>&1; then
        DATABASE_TYPE="MariaDB"
    elif docker exec $i printenv POSTGRES_USER >/dev/null 2>&1; then
        DATABASE_TYPE="PostgreSQL"
    else
        DATABASE_TYPE="Unknown"
    fi

    DATABASE_USER_ENV=$(docker exec $i env | grep -E 'MYSQL_USER|MARIADB_USER|POSTGRES_USER' | cut -d"=" -f1)

    case "$DATABASE_USER_ENV" in
        MYSQL_USER)
            DATABASE_USER=$(docker exec $i printenv MYSQL_USER)
            DATABASE_PASSWORD=$(docker exec $i printenv MYSQL_PASSWORD)
            ;;
        MARIADB_USER)
            DATABASE_USER=$(docker exec $i printenv MARIADB_USER)
            DATABASE_PASSWORD=$(docker exec $i printenv MARIADB_PASSWORD)
            ;;
        POSTGRES_USER)
            DATABASE_USER=$(docker exec $i printenv POSTGRES_USER)
            DATABASE_PASSWORD=$(docker exec $i printenv POSTGRES_PASSWORD)
            ;;            
        *)
            ROOT_DATABASE_USER_ENV=$(docker exec $i env | grep -E 'MYSQL_ROOT_USER|MARIADB_ROOT_USER' | cut -d"=" -f1)
            case "$ROOT_DATABASE_USER_ENV" in
                MYSQL_ROOT_USER)
                    DATABASE_USER=$(docker exec $i printenv MYSQL_ROOT_USER)
                    DATABASE_PASSWORD=$(docker exec $i printenv MYSQL_ROOT_PASSWORD)
                    ;;
                MARIADB_ROOT_USER)
                    DATABASE_USER=$(docker exec $i printenv MARIADB_ROOT_USER)
                    DATABASE_PASSWORD=$(docker exec $i printenv MARIADB_ROOT_PASSWORD)
                    ;;
                *)
                    DATABASE_USER="root"
                    ;;
            esac
            ;;
    esac

    MYSQLDUMP_LOCATION=$(docker exec $i which mysqldump)
    MARIADB_DUMP_LOCATION=$(docker exec $i which mariadb-dump)
    PSQL_LOCATION=$(docker exec $i which psql)
    PG_DUMP_LOCATION=$(docker exec $i which pg_dump)

    if [ -n "$MYSQLDUMP_LOCATION" ]; then
        DATABASE_TYPE="MySQL"
        DUMP_COMMAND="$MYSQLDUMP_LOCATION -u $DATABASE_USER --p$DATABASE_PASSWORD"
    elif [ -n "$MARIADB_DUMP_LOCATION" ]; then
        DATABASE_TYPE="MariaDB"
        DUMP_COMMAND="$MARIADB_DUMP_LOCATION -u $DATABASE_USER -p$DATABASE_PASSWORD"
    elif [ -n "$PG_DUMP_LOCATION" ]; then
        DATABASE_TYPE="PostgreSQL"
        DUMP_COMMAND="$PG_DUMP_LOCATION -U $DATABASE_USER"
    else
        DATABASE_TYPE="Unknown"
        DUMP_COMMAND=""
    fi

    if [ -n "$DUMP_COMMAND" ]; then
        if [ "$DATABASE_TYPE" = "MySQL" ]; then
            DATABASES=$(docker exec $i $DUMP_COMMAND -e "show databases" | grep -Ev "(Database|information_schema|performance_schema|mysql)")
            for d in $DATABASES; do
                echo -e "Creating $DATABASE_TYPE Backup for Container:\n $d DB on $i";
                docker exec $i $DUMP_COMMAND $d | gzip > $BACKUPDIR/$i-$d-$TIMESTAMP.sql.gz
            done
        elif [ "$DATABASE_TYPE" = "MariaDB" ]; then
            DATABASES=$(docker exec -e MYSQL_PWD=$DATABASE_PASSWORD $i mariadb -u $DATABASE_USER -s -e "show databases" | grep -Ev "(Database|information_schema|performance_schema|mysql)")
            for d in $DATABASES; do
                echo -e "Creating $DATABASE_TYPE Backup for Container:\n $d DB on $i";
                docker exec $i $DUMP_COMMAND $d | gzip > $BACKUPDIR/$i-$d-$TIMESTAMP.sql.gz
            done
        elif [ "$DATABASE_TYPE" = "PostgreSQL" ]; then
            DATABASES=$(docker exec -e PGPASSWORD=$DATABASE_PASSWORD $i psql -U postgres -lqt | cut -d \| -f 1 | grep -vE 'template[01]|postgres')
            for d in $DATABASES; do
                echo -e "Creating $DATABASE_TYPE Backup for Container:\n $d DB on $i";
                docker exec -e PGPASSWORD=$DATABASE_PASSWORD $i $DUMP_COMMAND $d | gzip > $BACKUPDIR/$i-$d-$TIMESTAMP.sql.gz
            done
        fi
    else
        echo " ERROR: cannot find dump command for container $i!"
    fi

    OLD_BACKUPS=$(ls -1 $BACKUPDIR/$i*.gz | wc -l)
    if [ $OLD_BACKUPS -gt $DAYS ]; then
        find $BACKUPDIR -name "$i*.gz" -daystart -mtime +$DAYS -delete
    fi

done

echo -e "\n$TIMESTAMP Backup for Databases completed\n"