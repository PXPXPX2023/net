#!/bin/bash

# ===== 配置 =====
THRESHOLD=2
SET_NAME="ssh_blacklist"
LOG_CMD="journalctl -u ssh --since '2 minutes ago' --no-pager"

# ===== 初始化 ipset =====
ipset create $SET_NAME hash:net -exist

# 绑定 iptables（只执行一次）
iptables -C INPUT -m set --match-set $SET_NAME src -j DROP 2>/dev/null
if [ $? -ne 0 ]; then
    iptables -I INPUT -m set --match-set $SET_NAME src -j DROP
fi

# ===== 提取失败登录 IP =====
IPS=$($LOG_CMD | grep "Failed password" | awk '{print $(NF-3)}')

# ===== 转换为 /24 并统计 =====
echo "$IPS" | awk -F. '{print $1"."$2"."$3".0/24"}' | sort | uniq -c | while read COUNT NET; do
    if [ "$COUNT" -ge "$THRESHOLD" ]; then
        echo "[BAN] $NET (hits: $COUNT)"
        ipset add $SET_NAME $NET -exist
    fi
done
