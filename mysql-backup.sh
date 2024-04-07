#!/bin/bash

BACKUPDIR=$HOME/backup/mysql
DAYS=7
TIMESTAMP=$(date +"%Y%m%d%H%M")

CONTAINER=$(docker ps --format '{{.Names}}:{{.Image}}' | grep 'mysql\|mariadb' | cut -d":" -f1)

if [ ! -d $BACKUPDIR ]; then
    echo -e "Creating backup directory:\n $BACKUPDIR\n"
    mkdir -p $BACKUPDIR
fi

echo -e "Start $TIMESTAMP Backup for Databases: \n"

for i in $CONTAINER; do
    DATABASE_USER_ENV=$(docker exec $i env | grep -E 'MYSQL_USER|MARIADB_USER' | cut -d"=" -f1)

    case "$DATABASE_USER_ENV" in
        MYSQL_USER)
            DATABASE_USER=$(docker exec $i printenv MYSQL_USER)
            DATABASE_PASSWORD=$(docker exec $i printenv MYSQL_PASSWORD)
            ;;
        MARIADB_USER)
            DATABASE_USER=$(docker exec $i printenv MARIADB_USER)
            DATABASE_PASSWORD=$(docker exec $i printenv MARIADB_PASSWORD)
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

    MYSQL_PWD=$(docker exec $i env | grep MYSQL_ROOT_PASSWORD | cut -d"=" -f2)

    if [ -n "$DATABASE_PASSWORD" ]; then
        DATABASE_PASSWORD_OPTION="-p$DATABASE_PASSWORD"
    else
        DATABASE_PASSWORD_OPTION=""
    fi

    if docker exec $i test -e /usr/bin/mysqldump; then
        DATABASES=$(docker exec -e MYSQL_PWD=$MYSQL_PWD $i mysql -u $DATABASE_USER $DATABASE_PASSWORD_OPTION -s -e "show databases" | grep -Ev "(Database|information_schema|performance_schema|mysql)")
        for MYSQL_DATABASE in $DATABASES; do
            echo -e " create MYSQL Backup for Database on Container:\n  * $MYSQL_DATABASE DB on $i \n";
            docker exec -e MYSQL_PWD=$MYSQL_PWD $i /usr/bin/mysqldump -u $DATABASE_USER $DATABASE_PASSWORD_OPTION $MYSQL_DATABASE | gzip > $BACKUPDIR/$i-$MYSQL_DATABASE-$TIMESTAMP.sql.gz
        done        
    elif docker exec $i test -e /usr/bin/mariadb-dump; then
        DATABASES=$(docker exec -e MYSQL_PWD=$MYSQL_PWD $i mariadb -u $DATABASE_USER $DATABASE_PASSWORD_OPTION -s -e "show databases" | grep -Ev "(Database|information_schema|performance_schema|mysql)")
        for MYSQL_DATABASE in $DATABASES; do
            echo -e " create MariaDB Backup for Database on Container:\n  * $MYSQL_DATABASE DB on $i \n";
            docker exec -e MYSQL_PWD=$MYSQL_PWD $i /usr/bin/mariadb-dump -u $DATABASE_USER $DATABASE_PASSWORD_OPTION $MYSQL_DATABASE | gzip > $BACKUPDIR/$i-$MYSQL_DATABASE-$TIMESTAMP.sql.gz
        done
    else
        echo " ERROR: cannot find dump command for container $i!"
    fi
    OLD_BACKUPS=$(ls -1 $BACKUPDIR/$i*.gz | wc -l)
    if [ $OLD_BACKUPS -gt $DAYS ]; then
        find $BACKUPDIR -name "$i*.gz" -daystart -mtime +$DAYS -delete
    fi
done

echo -e "Backup for Databases completed\n"