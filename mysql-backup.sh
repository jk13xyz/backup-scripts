#!/bin/bash

BACKUPDIR=$HOME/backup/mysql
DAYS=7
TIMESTAMP=$(date +"%Y%m%d%H%M")

CONTAINER=$(docker ps --format '{{.Names}}:{{.Image}}' | grep 'mysql\|mariadb' | cut -d":" -f1)

echo -e "Start $TIMESTAMP Backup for Databases: \n"
if [ ! -d $BACKUPDIR ]; then
	mkdir -p $BACKUPDIR
fi

for i in $CONTAINER; do
    MYSQL_PWD=$(docker exec $i env | grep MYSQL_ROOT_PASSWORD | cut -d"=" -f2)

	if docker exec $i test -e /usr/bin/mysqldump; then
    	DATABASES=$(docker exec -e MYSQL_PWD=$MYSQL_PWD $i mysql -uroot -s -e "show databases" | grep -Ev "(Database|information_schema|performance_schema|mysql)")
    	for MYSQL_DATABASE in $DATABASES; do
	    	echo -e " create MYSQL Backup for Database on Container:\n  * $MYSQL_DATABASE DB on $i";
	    	docker exec -e MYSQL_DATABASE=$MYSQL_DATABASE -e MYSQL_PWD=$MYSQL_PWD \
				$i /usr/bin/mysqldump -u root $MYSQL_DATABASE | gzip > $BACKUPDIR/$i-$MYSQL_DATABASE-$TIMESTAMP.sql.gz
		done		
	elif docker exec $i test -e /usr/bin/mariadb-dump; then
    	DATABASES=$(docker exec -e MYSQL_PWD=$MYSQL_PWD $i mariadb -uroot -s -e "show databases" | grep -Ev "(Database|information_schema|performance_schema|mysql)")
    	for MYSQL_DATABASE in $DATABASES; do
	    	echo -e " create MariaDB Backup for Database on Container:\n  * $MYSQL_DATABASE DB on $i";
	    	docker exec -e MYSQL_DATABASE=$MYSQL_DATABASE -e MYSQL_PWD=$MYSQL_PWD \
				$i /usr/bin/mariadb-dump -u root $MYSQL_DATABASE | gzip > $BACKUPDIR/$i-$MYSQL_DATABASE-$TIMESTAMP.sql.gz
		done
	else
	    echo " ERROR: cannot find dump command for container $i!"
	fi
	OLD_BACKUPS=$(ls -1 $BACKUPDIR/$i*.gz |wc -l)
	if [ $OLD_BACKUPS -gt $DAYS ]; then
		find $BACKUPDIR -name "$i*.gz" -daystart -mtime +$DAYS -delete
	fi
done
echo -e "\n$TIMESTAMP Backup for Databases completed\n"