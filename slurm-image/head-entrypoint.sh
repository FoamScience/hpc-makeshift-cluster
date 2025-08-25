#!/bin/bash

set -eo pipefail

sed -i 's/bind-address.*/bind-address = 0.0.0.0/g' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/^\[mysqld\]/a innodb_buffer_pool_size = 4G\ninnodb_lock_wait_timeout = 900' /etc/mysql/mariadb.conf.d/50-server.cnf
chown -R slurmuser: /home/slurmuser

function error_with_msg {
    if [[ "$count" -eq 0 ]]
    then
        echo
        echo >&2 "$1"
        exit 1
    fi
}

if [ ! -d "/var/lib/mysql/mysql" ]
then
    echo "[mysqld]\nskip-host-cache\nskip-name-resolve" > /etc/my.cnf.d/docker.cnf
    echo "- Initializing database"
    /usr/bin/mysql_install_db --user=mysql &> /dev/null
    echo "- Database initialized"
fi

if [ ! -d "/var/lib/mysql/slurm_acct_db" ]
then
    /usr/bin/mysqld_safe &

    for count in {30..0}; do
        if echo "SELECT 1" | mysql &> /dev/null
        then
            break
        fi
        echo "- Starting MariaDB to create Slurm account database"
        sleep 1
    done

    error_with_msg "MariaDB did not start"

    echo "- Creating Slurm acct database"
    mysql -e "CREATE DATABASE IF NOT EXISTS slurm_acct_db;"
    mysql -e "CREATE USER IF NOT EXISTS 'slurm'@'%' IDENTIFIED BY 'password';"
    mysql -e "CREATE USER IF NOT EXISTS 'slurm'@'localhost' IDENTIFIED BY 'password';"
    mysql -e "GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurm'@'%';"
    mysql -e "GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurm'@'localhost';"
    mysql -e "FLUSH PRIVILEGES;"
    echo "- Slurm acct database created. Stopping MariaDB"
    kill $(cat /var/run/mysqld/mysqld.pid)

    for count in {30..0}; do
        if echo "SELECT 1" | mysql &> /dev/null
        then
            sleep 1
        else
            break
        fi
    done

    error_with_msg "MariaDB did not stop"
fi

echo "- Starting supervisord process manager"
/usr/bin/supervisord --configuration /etc/supervisor/supervisord.conf

echo "- Starting all HEAD Services..."
for service in munged mysqld slurmdbd slurmctld slurmrestd
do
    /usr/bin/supervisorctl start "$service:*"
done

echo "- Waiting for the cluster to become available"
for count in {20..0}; do
    if timeout 1 sinfo -h -o "%P %a" | grep -q "^debug.*up$"; then
        break
    else
        sleep 1
    fi
done
error_with_msg "Slurm partitions failed to start successfully within 20secs."

echo "- Cluster is now available"

tail -F /var/log/slurm/slurmrestd.log 2>/dev/null || tail -f /dev/null
