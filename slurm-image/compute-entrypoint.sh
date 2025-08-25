#!/bin/bash

set -eo pipefail

function error_with_msg {
    if [[ "$count" -eq 0 ]]
    then
        echo
        echo >&2 "$1"
        exit 1
    fi
}

echo "- Starting supervisord process manager"
/usr/bin/supervisord --configuration /etc/supervisor/supervisord.conf

echo "- Starting all COMPUTE Services..."
for service in munged slurmd
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

tail -F /var/log/slurm/slurmd.log 2>/dev/null || tail -f /dev/null
