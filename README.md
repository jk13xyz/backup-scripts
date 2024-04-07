# jk13xyz/backup-scripts

This repo contains Shell scripts made to automate the backup of database containers. 

These scripts were made for use with Linux. They may work with other operating systems, but I have not tested that.

**Obvious disclaimer: Use with caution. Do not try to hold me accountable for anything that goes awry.**

## How it works

The script loops through every available MySQL, MariaDB or PostgreSQL container, depending on the script used.

**db-backup.sh** handles the backup of all three database systems.

**mysql-backup.sh** handles the backup of MySQL and MariaDB.

**postgres-backup.sh** handles the backup of PostreSQL.

In order for the scripts to work, credentials of a user with access to a specific database must be passed. The script is setup to use the credentials of "regular" users first, before attempting to use root/superuser credentials. 

Especially with databases containing multiple tables for different services, use of a superuser, or at least a user with enough privileges to read all available tables is required!

The script searches for the following environmental variables:

MySQL and MariaDB:

- MYSQL_USER
- MYSQL_PASSWORD
- MYSQL_ROOT_USER
- MYSQL_ROOT_PASSWORD

MariaDB:

- MARIADB_USER
- MARIADB_USER_PASSWORD
- MARIADB_ROOT_USER
- MARIADB_ROOT_PASSWORD

PostgreSQL:

- POSTGRES_USER
- POSTGRES_PASSWORD

The script automatically deletes all backups older than 7 days. This may be adjusted by editing the $DAYS variable at the top of the script.

By default, the script backups to $HOME/backup/databases. This may be adjust as well to your liking ($BACKUPDIR).

**Please note:** This will only work with Docker. Podman would require adjustments. Any kind of container orchestration systems such as k8s are completely untested and are 99.9% unlikely to work.

## How to use it

### Manual

1. Download the scripts with git clone https://github.com/jk13xyz/backup-scripts.git
2. Navigate to the scripts location
3. Open a terminal shell of your choice and enter, for example:

``` sh
    ./db-backup.sh
```

Replace the name of the script, depending on which one you may want to use.

### Cronjob

1. Ensure you have cron and crontab installed (you should by default).
2. Execute the following command:

``` sh
echo "0 6 * * * /home/user/scripts/db-backup.sh > /dev/stdout 2>&1" >> /etc/crontab
crontab /etc/crontab
```

**Please adjust the paths and commands accordingly.** The exact details can vary depending on your Distro. 

This setup would run a cronjob every morning at 6 o'clock.
