#!/bin/bash

# ===== 配置 =====
THRESHOLD_IP=3
THRESHOLD_NET=4
SET_IP="ssh_blacklist_ip"
SET_NET="ssh_blacklist_net"

# 时间窗口（建议和 cron 一致）
SINCE_TIME=$(date -d "5 minutes ago" "+%Y-%m-%d %H:%M:%S")

# 获取日志
LOGS=$(journalctl -u ssh --since="$SINCE_TIME" --no-pager 2>/dev/null)

# 初始化 ipset
ipset create $SET_IP hash:ip -exist
ipset create $SET_NET hash:net -exist

# 绑定 iptables（只执行一次）
iptables -C INPUT -m set --match-set $SET_IP src -j DROP 2>/dev/null || \
iptables -I INPUT -m set --match-set $SET_IP src -j DROP

iptables -C INPUT -m set --match-set $SET_NET src -j DROP 2>/dev/null || \
iptables -I INPUT -m set --match-set $SET_NET src -j DROP

# 提取 IP
IPS=$(echo "$LOGS" | grep "Failed password" | awk '{print $(NF-3)}')

# ===== 单 IP 统计 =====
echo "$IPS" | sort | uniq -c | while read COUNT IP; do
    if [ "$COUNT" -ge "$THRESHOLD_IP" ]; then
        ipset add $SET_IP $IP -exist >/dev/null 2>&1
    fi
done

# ===== /24 统计 =====
echo "$IPS" | awk -F. '{print $1"."$2"."$3".0/24"}' | sort | uniq -c | while read COUNT NET; do
    if [ "$COUNT" -ge "$THRESHOLD_NET" ]; then
        ipset add $SET_NET $NET -exist >/dev/null 2>&1
    fi
done