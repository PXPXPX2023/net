#!/bin/bash

THRESHOLD_NET=2
SET_NET="ssh_blacklist_net"

SINCE_TIME=$(date -d "15 minutes ago" "+%Y-%m-%d %H:%M:%S")

LOGS=$(journalctl -u ssh --since="$SINCE_TIME" --no-pager 2>/dev/null)

ipset create $SET_NET hash:net -exist

iptables -C INPUT -m set --match-set $SET_NET src -j DROP 2>/dev/null || \
iptables -I INPUT -m set --match-set $SET_NET src -j DROP

IPS=$(echo "$LOGS" | grep "Failed password" | awk '{print $(NF-3)}')

echo "$IPS" | awk -F. '{print $1"."$2"."$3".0/24"}' | sort | uniq -c | while read COUNT NET; do
    if [ "$COUNT" -ge "$THRESHOLD_NET" ]; then
        ipset add $SET_NET $NET -exist >/dev/null 2>&1
    fi
done
