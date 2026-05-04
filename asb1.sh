#!/bin/bash

# ===== 配置 =====
THRESHOLD=2
SET_NAME="ssh_blacklist"

# 时间窗口
SINCE_TIME=$(date -d "2 minutes ago" "+%Y-%m-%d %H:%M:%S")

# 获取日志（静默）
LOGS=$(journalctl -u ssh --since="$SINCE_TIME" --no-pager 2>/dev/null)

# 初始化 ipset
ipset create $SET_NAME hash:net -exist

# 绑定 iptables（只执行一次）
iptables -C INPUT -m set --match-set $SET_NAME src -j DROP 2>/dev/null || \
iptables -I INPUT -m set --match-set $SET_NAME src -j DROP

# 提取IP（静默）
IPS=$(echo "$LOGS" | grep "Failed password" | awk '{print $(NF-3)}')

# 转换为 /24 并统计（无输出）
echo "$IPS" | awk -F. '{print $1"."$2"."$3".0/24"}' | sort | uniq -c | while read COUNT NET; do
    if [ "$COUNT" -ge "$THRESHOLD" ]; then
        ipset add $SET_NAME $NET -exist >/dev/null 2>&1
    fi
done
