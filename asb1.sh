#!/bin/bash
# ===== 阈值配置 =====
THRESHOLD_15M=3
THRESHOLD_24H=10
THRESHOLD_72H=20
# ===== ipset 名称 =====
SET_15M="ssh_blacklist_15m"
SET_24H="ssh_blacklist_24h"
SET_72H="ssh_blacklist_72h"
# ===== 创建 ipset =====
ipset create $SET_15M hash:net -exist
ipset create $SET_24H hash:net -exist
ipset create $SET_72H hash:net -exist
# ===== iptables 绑定 =====
iptables -C INPUT -m set --match-set $SET_15M src -j DROP 2>/dev/null || \
iptables -I INPUT -m set --match-set $SET_15M src -j DROP

iptables -C INPUT -m set --match-set $SET_24H src -j DROP 2>/dev/null || \
iptables -I INPUT -m set --match-set $SET_24H src -j DROP

iptables -C INPUT -m set --match-set $SET_72H src -j DROP 2>/dev/null || \
iptables -I INPUT -m set --match-set $SET_72H src -j DROP

# ===== 函数：处理窗口 =====
process_window() {
    local TIME_WINDOW="$1"
    local THRESHOLD="$2"
    local SET_NAME="$3"

    SINCE_TIME=$(date -d "$TIME_WINDOW ago" "+%Y-%m-%d %H:%M:%S")

    LOGS=$(journalctl -u ssh --since="$SINCE_TIME" --no-pager 2>/dev/null)

    IPS=$(echo "$LOGS" | grep "Failed password" | awk '{print $(NF-3)}')

    echo "$IPS" | awk -F. '{print $1"."$2"."$3".0/24"}' | sort | uniq -c | while read COUNT NET; do
        if [ "$COUNT" -ge "$THRESHOLD" ]; then
            ipset add $SET_NAME $NET -exist >/dev/null 2>&1
        fi
    done
}
# ===== 执行三层 =====
process_window "15 minutes" $THRESHOLD_15M $SET_15M
process_window "24 hours"   $THRESHOLD_24H $SET_24H
process_window "72 hours"   $THRESHOLD_72H $SET_72H
