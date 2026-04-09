#!/usr/bin/env bash

# ==========================================================
# Xray 全功能管理脚本 v6 Pro（工业级重构版）
# 特性：
# - 每用户独立 Reality（核心改造）
# - 稳定 jq 写入
# - 多 inbound 架构
# ==========================================================

set -e

CONFIG="/usr/local/etc/xray/config.json"
XRAY_BIN="/usr/local/bin/xray"
LOG_DIR="/var/log/xray"

green="\033[32m"
red="\033[31m"
yellow="\033[33m"
blue="\033[36m"
none="\033[0m"

# ==========================================================
# 基础函数
# ==========================================================

msg() { echo -e "$@"; }
info() { msg "${green}[INFO]${none} $*"; }
warn() { msg "${yellow}[WARN]${none} $*"; }
error() { msg "${red}[ERROR]${none} $*"; }

title() {
    echo ""
    echo "════════════════════════════════"
    echo "  $*"
    echo "════════════════════════════════"
}

hr() { echo "--------------------------------"; }

# ==========================================================
# 安全 jq 写入
# ==========================================================

_safe_jq_write() {
    local filter="$1"
    local tmp=$(mktemp)
    jq "$filter" "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
}

# ==========================================================
# Reality 工具
# ==========================================================

gen_reality_keys() {
    "$XRAY_BIN" x25519 | awk '
    /Private key:/ {priv=$3}
    /Public key:/ {pub=$3}
    END{print priv "|" pub}'
}

gen_short_id() {
    openssl rand -hex 8
}

gen_uuid() {
    "$XRAY_BIN" uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid
}

get_server_ip() {
    SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
}

# ==========================================================
# 创建独立用户 inbound（核心）
# ==========================================================

add_vless_user() {

    title "新增用户（独立 Reality）"

    local uuid port domain keys priv pub sid

    uuid=$(gen_uuid)
    port=$(shuf -i20000-40000 -n1)

    read -rp "输入 SNI 域名（如：www.cloudflare.com）: " domain
    [[ -z "$domain" ]] && warn "必须输入域名" && return

    keys=$(gen_reality_keys)
    priv=${keys%|*}
    pub=${keys#*|}

    sid=$(gen_short_id)

    jq --arg uuid "$uuid" \
       --arg port "$port" \
       --arg domain "$domain" \
       --arg priv "$priv" \
       --arg sid "$sid" \
       '
       .inbounds += [{
         "port": ($port|tonumber),
         "protocol": "vless",
         "settings": {
           "clients": [{
             "id": $uuid,
             "flow": "xtls-rprx-vision"
           }],
           "decryption": "none"
         },
         "streamSettings": {
           "network": "tcp",
           "security": "reality",
           "realitySettings": {
             "show": false,
             "dest": ($domain + ":443"),
             "xver": 0,
             "serverNames": [$domain],
             "privateKey": $priv,
             "shortIds": [$sid]
           }
         }
       }]
       ' "$CONFIG" > tmp.json && mv tmp.json "$CONFIG"

    systemctl restart xray

    get_server_ip

    echo ""
    info "用户创建成功"
    echo ""

    echo "vless://${uuid}@${SERVER_IP}:${port}?security=reality&sni=${domain}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#user-${port}"
}

# ==========================================================
# 列出用户
# ==========================================================

list_users() {
    jq -r '
    .inbounds[]
    | select(.protocol=="vless")
    | "\(.port) | \(.settings.clients[0].id)"
    ' "$CONFIG"
}

# ==========================================================
# 删除用户
# ==========================================================

delete_user() {

    list_users

    read -rp "输入端口删除用户: " dp

    _safe_jq_write "del(.inbounds[] | select(.port==$dp))"

    systemctl restart xray

    info "已删除"
}

# ==========================================================
# Shadowsocks（修复 index bug）
# ==========================================================

add_ss() {

    local port pass method
    port=8388
    pass=$(openssl rand -base64 12)
    method="aes-128-gcm"

    jq --arg port "$port" \
       --arg pass "$pass" \
       --arg method "$method" \
       '
       .inbounds += [{
         "port": ($port|tonumber),
         "protocol": "shadowsocks",
         "settings": {
           "method": $method,
           "password": $pass
         }
       }]
       ' "$CONFIG" > tmp.json && mv tmp.json "$CONFIG"

    systemctl restart xray

    echo "ss://${method}:${pass}@$(hostname -I | awk '{print $1}'):${port}"
}

# ==========================================================
# 导出用户（修复 Reality 读取错误）
# ==========================================================

export_user() {

    list_users

    read -rp "输入端口导出: " ep

    local data
    data=$(jq -r "
    .inbounds[]
    | select(.port==$ep)
    | [
        .settings.clients[0].id,
        .streamSettings.realitySettings.serverNames[0],
        .streamSettings.realitySettings.privateKey,
        .streamSettings.realitySettings.shortIds[0]
      ] | @tsv
    " "$CONFIG")

    [[ -z "$data" ]] && error "不存在" && return

    read uuid sni priv sid <<< "$data"

    pub=$(echo "$priv" | xargs -I{} "$XRAY_BIN" x25519 -i {} 2>/dev/null | awk '/Public/{print $3}')

    get_server_ip

    echo "vless://${uuid}@${SERVER_IP}:${ep}?security=reality&sni=${sni}&pbk=${pub}&sid=${sid}"
}

# ==========================================================
# 主菜单
# ==========================================================

main_menu() {

    while true; do

        title "Xray 管理"

        echo "1. 新增用户（独立 Reality）"
        echo "2. 删除用户"
        echo "3. 查看用户"
        echo "4. 导出配置"
        echo "5. 添加 SS"
        echo "0. 退出"

        read -rp "选择: " num

        case "$num" in
            1) add_vless_user ;;
            2) delete_user ;;
            3) list_users ;;
            4) export_user ;;
            5) add_ss ;;
            0) exit ;;
        esac
    done
}

main_menu
