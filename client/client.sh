#!/bin/sh

request_number=1
while true; do
    if wget -q -T 3 -O /dev/null "${SERVER_URL}/health?request=${request_number}"; then
        if [ -s /shared/access.log ]; then
            printf 'Read from /shared/access.log: '
            tail -n 1 /shared/access.log
        fi
        request_number=$((request_number + 1))
    else
        printf 'Waiting for %s\n' "$SERVER_URL" >&2
    fi
    sleep 5
done
