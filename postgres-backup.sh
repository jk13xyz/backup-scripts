#!/bin/bash

BACKUPDIR=$HOME/backup/postgres
DAYS=7
TIMESTAMP=$(date +"%Y%m%d%H%M")

CONTAINER=$(docker ps --format '{{.Names}}:{{.Image}}' | grep 'postgres' | cut -d":" -f1)

if [ ! -d $BACKUPDIR ]; then
    echo -e "Creating backup directory:\n $BACKUPDIR\n"
    mkdir -p $BACKUPDIR
fi

echo -e "Start $TIMESTAMP Backup for Databases: \n"

for i in $CONTAINER; do

    DATABASE_USER_ENV=$(docker exec $i env | grep -E 'POSTGRES_USER' | cut -d"=" -f1)

    case "$DATABASE_USER_ENV" in
        POSTGRES_USER)
            DATABASE_USER=$(docker exec $i printenv POSTGRES_USER)
            DATABASE_PASSWORD=$(docker exec $i printenv POSTGRES_PASSWORD)
            ;;            
        *)
            DATABASE_USER="postgres"
            DATABASE_PASSWORD=$(docker exec $i printenv POSTGRES_PASSWORD)    
        
            ;;
    esac

    POSTGRES_PASSWORD=$(docker exec $i env | grep POSTGRES_PASSWORD | cut -d"=" -f2)

    if docker exec $i test -e /usr/bin/pg_dump; then
        DATABASES=$(docker exec -e PGPASSWORD=$POSTGRES_PASSWORD $i psql -U postgres -lqt | cut -d \| -f 1 | grep -vE 'template[01]|postgres')
        for PG_DATABASE in $DATABASES; do
            echo -e "Creating PostgreSQL backup for database on container:\n  * $PG_DATABASE DB on $i \n";
            docker exec -e PGPASSWORD=$POSTGRES_PASSWORD $i /usr/bin/pg_dump -U postgres $PG_DATABASE | gzip > $BACKUPDIR/$i-$PG_DATABASE-$TIMESTAMP.sql.gz
        done
    else
        echo "ERROR: Cannot find dump command for container $i!"
    fi

    OLD_BACKUPS=$(ls -1 $BACKUPDIR/$i*.gz | wc -l)
    if [ $OLD_BACKUPS -gt $DAYS ]; then
        find $BACKUPDIR -name "$i*.gz" -daystart -mtime +$DAYS -delete
    fi
done

echo -e "Backup for Databases completed\n"
