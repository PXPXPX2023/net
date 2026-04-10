#!/usr/bin/env bash

# ============================================================
# g7.sh – Xray 终极融合管理脚本 (Ultimate Fusion)
# 快捷方式: xrv
# 核心功能：双协议支持 / 用户动态管理 / 原子化配置防崩 / 流量监控
# ============================================================

# --- 运行环境强制检查 ---
if [ -z "$BASH_VERSION" ]; then
    echo "错误: 请用 bash 运行此脚本: bash $0"
    exit 1
fi

# --- 颜色与界面定义 ---
red='\e[31m'; yellow='\e[33m'; gray='\e[90m'; green='\e[92m'
blue='\e[94m'; cyan='\e[96m'; none='\e[0m'

_red()   { echo -e "${red}$*${none}"; }
_green() { echo -e "${green}$*${none}"; }
_cyan()  { echo -e "${cyan}$*${none}"; }
_blue()  { echo -e "${blue}$*${none}"; }

info()  { echo -e "${green}[✓]${none} $*"; }
warn()  { echo -e "${yellow}[!]${none} $*"; }
error() { echo -e "${red}[✗]${none} $*";   }
hr()    { echo -e "${gray}---------------------------------------------------${none}"; }
title() {
    echo -e "\n${blue}===================================================${none}"
    echo -e "  ${cyan}$*${none}"
    echo -e "${blue}===================================================${none}"
}

# --- 全局路径配置 ---
XRAY_BIN="/usr/local/bin/xray"
CONFIG_DIR="/usr/local/etc/xray"
CONFIG="$CONFIG_DIR/config.json"
SCRIPT_DIR="/usr/local/etc/xray-script"
DAT_DIR="/usr/local/share/xray"
SYMLINK="/usr/local/bin/xrv"
UPDATE_DAT_SCRIPT="$SCRIPT_DIR/update-dat.sh"

GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat"

# --- 基础依赖与预检 ---
detect_arch_pkg() {
    case $(uname -m) in
        amd64|x86_64) CORE_ARCH="64" ;;
        *aarch64*|*armv8*) CORE_ARCH="arm64-v8a" ;;
        *) error "仅支持 64 位系统 (x86_64 / aarch64)"; exit 1 ;;
    esac

    PKG_CMD=$(type -P apt-get || type -P yum || true)
    [[ -z "$PKG_CMD" ]] && { error "仅支持 apt / yum 包管理器系统"; exit 1; }
}

install_pkg() {
    local need=""
    for i in "$@"; do command -v "$i" &>/dev/null || need="$need $i"; done
    if [[ -n "$need" ]]; then
        warn "正在安装缺失依赖: $need"
        [[ "$PKG_CMD" =~ yum ]] && $PKG_CMD install epel-release -y &>/dev/null
        $PKG_CMD install -y $need &>/dev/null
    fi
}

preflight() {
    [[ $EUID -ne 0 ]] && { error "请以 root 权限运行"; exit 1; }
    detect_arch_pkg
    install_pkg jq curl wget xxd unzip vnstat

    if [[ ! -L "$SYMLINK" ]] || [[ "$(readlink -f "$SYMLINK")" != "$(realpath "$0")" ]]; then
        ln -sf "$(realpath "$0")" "$SYMLINK"
        chmod +x "$(realpath "$0")"
        info "已绑定全局快捷命令: xrv"
    fi
}

get_ip() {
    SERVER_IP=$(curl -s4m 5 https://api4.ipify.org || curl -s4m 5 https://ifconfig.me || echo "YOUR_SERVER_IP")
}

# --- 核心数据安全操作 ---
safe_jq_write() {
    local filter="$1"
    local tmp; tmp=$(mktemp)
    local bak="${CONFIG}.bak.$(date +%s)"
    
    [[ -f "$CONFIG" ]] && cp "$CONFIG" "$bak"
    
    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null && jq type "$tmp" &>/dev/null; then
        mv "$tmp" "$CONFIG"
        return 0
    else
        error "配置文件修改失败，已还原保护"
        [[ -f "$bak" ]] && mv "$bak" "$CONFIG"
        rm -f "$tmp"
        return 1
    fi
}

gen_uuid() { cat /proc/sys/kernel/random/uuid; }
gen_short_id() { head -c 8 /dev/urandom | xxd -p; }

# --- 初始化与安装模块 ---
_write_init_json() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG" <<EOF
{
    "log": { "loglevel": "warning" },
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {"tag_id":"bt", "type":"field","protocol":["bittorrent"],"outboundTag":"block","_enabled":true},
            {"tag_id":"cn", "type":"field","ip":["geoip:cn"],"outboundTag":"block","_enabled":true},
            {"tag_id":"ads", "type":"field","domain":["geosite:category-ads-all"],"outboundTag":"block","_enabled":true}
        ]
    },
    "inbounds": [],
    "outbounds": [{"protocol":"freedom","tag":"direct"},{"protocol":"blackhole","tag":"block"}]
}
EOF
}

do_install() {
    title "全新安装 Xray"
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    _write_init_json
    
    echo -e "请选择需要开启的协议:\n1) VLESS-Reality (推荐)\n2) Shadowsocks\n3) 两者均开启"
    read -rp "选择 [1]: " choice
    
    case ${choice:-1} in
        1) _setup_vless ;;
        2) _setup_ss ;;
        3) _setup_vless; _setup_ss ;;
    esac
    
    _setup_crontab_dat
    systemctl restart xray
    info "Xray 核心与配置安装完成！"
    do_summary
}

_setup_vless() {
    local port=$(input_port "VLESS 监听端口" "443")
    local domain=$(read -rp "  目标域名 [www.microsoft.com]: " d && echo ${d:-www.microsoft.com})
    
    local keys=$($XRAY_BIN x25519 2>/dev/null)
    local priv=$(echo "$keys" | grep "Private key" | awk '{print $3}')
    local pub=$(echo "$keys" | grep "Public key" | awk '{print $3}')
    local uuid=$(gen_uuid)
    local sid=$(gen_short_id)

    safe_jq_write ".inbounds += [{
        \"tag\": \"vless-reality\", \"port\": $port, \"protocol\": \"vless\",
        \"settings\": { \"clients\": [{\"id\":\"$uuid\",\"flow\":\"xtls-rprx-vision\"}], \"decryption\": \"none\" },
        \"streamSettings\": { \"network\": \"tcp\", \"security\": \"reality\",
            \"realitySettings\": { \"dest\": \"$domain:443\", \"serverNames\": [\"$domain\"], \"privateKey\": \"$priv\", \"publicKey\": \"$pub\", \"shortIds\": [\"$sid\"] }
        },
        \"sniffing\": {\"enabled\":true,\"destOverride\":[\"http\",\"tls\",\"quic\"]}
    }]"
}

_setup_ss() {
    local port=$(input_port "Shadowsocks 端口" "8388")
    local pass=$(head -c 16 /dev/urandom | base64 | tr -d '=/+\n' | head -c 16)
    safe_jq_write ".inbounds += [{
        \"tag\": \"shadowsocks\", \"port\": $port, \"protocol\": \"shadowsocks\",
        \"settings\": { \"method\": \"aes-256-gcm\", \"password\": \"$pass\", \"network\": \"tcp,udp\" }
    }]"
}

# --- 用户管理与展示模块 ---
do_user_menu() {
    while true; do
        title "VLESS 用户管理"
        echo "1) 查看所有用户节点链接"
        echo "2) 添加新用户 (随机 UUID)"
        echo "3) 删除指定用户"
        echo "0) 返回主菜单"
        hr
        read -rp "选择: " opt
        case "$opt" in
            1) do_summary; read -rp "按回车继续..." ;;
            2) _add_vless_user ;;
            3) _del_vless_user ;;
            0) break ;;
        esac
    done
}

_add_vless_user() {
    local vidx=$(jq '[.inbounds[].protocol == "vless"] | index(true)' "$CONFIG")
    [[ "$vidx" == "null" ]] && { error "未找到 VLESS 配置，请先安装"; return; }
    
    local new_uuid=$(gen_uuid)
    safe_jq_write ".inbounds[$vidx].settings.clients += [{\"id\":\"$new_uuid\",\"flow\":\"xtls-rprx-vision\"}]"
    systemctl restart xray
    info "已添加新用户: $new_uuid"
}

_del_vless_user() {
    local vidx=$(jq '[.inbounds[].protocol == "vless"] | index(true)' "$CONFIG")
    [[ "$vidx" == "null" ]] && { error "未找到 VLESS 配置"; return; }
    
    echo -e "当前用户列表:"
    jq -r ".inbounds[$vidx].settings.clients[].id" "$CONFIG" | awk '{print " - "$0}'
    hr
    read -rp "请输入要删除的 UUID (为空取消): " duid
    [[ -z "$duid" ]] && return
    
    safe_jq_write "del(.inbounds[$vidx].settings.clients[] | select(.id == \"$duid\"))"
    systemctl restart xray
    info "用户已删除 (如果存在)。"
}

do_summary() {
    [[ ! -f "$CONFIG" ]] && { error "未发现配置文件"; return; }
    get_ip
    title "当前节点信息与状态"
    
    # 解析 VLESS
    local vidx=$(jq '[.inbounds[].protocol == "vless"] | index(true)' "$CONFIG")
    if [[ "$vidx" != "null" ]]; then
        local port=$(jq -r ".inbounds[$vidx].port" "$CONFIG")
        local pub=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.publicKey" "$CONFIG")
        local sni=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.serverNames[0]" "$CONFIG")
        local sid=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.shortIds[0]" "$CONFIG")
        
        _cyan "【VLESS-Reality 节点】"
        jq -c ".inbounds[$vidx].settings.clients[]" "$CONFIG" | while read -r user; do
            local uid=$(echo "$user" | jq -r .id)
            _yellow "UUID: $uid"
            echo "vless://$uid@$SERVER_IP:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$sni&fp=chrome&pbk=$pub&sid=$sid&type=tcp#xrv-vless"
        done
        hr
    fi

    # 解析 Shadowsocks
    local sidx=$(jq '[.inbounds[].protocol == "shadowsocks"] | index(true)' "$CONFIG")
    if [[ "$sidx" != "null" ]]; then
        local sport=$(jq -r ".inbounds[$sidx].port" "$CONFIG")
        local spass=$(jq -r ".inbounds[$sidx].settings.password" "$CONFIG")
        local smethod=$(jq -r ".inbounds[$sidx].settings.method" "$CONFIG")
        local ss_base64=$(echo -n "${smethod}:${spass}" | base64 -w 0)
        
        _cyan "【Shadowsocks 节点】"
        _yellow "端口: $sport | 密码: $spass | 加密: $smethod"
        echo "ss://${ss_base64}@${SERVER_IP}:${sport}#xrv-ss"
        hr
    fi
}

# --- 辅助工具模块 ---
input_port() {
    while true; do
        read -rp "  $1 [$2]: " p
        p=${p:-$2}
        [[ "$p" =~ ^[0-9]+$ ]] && ((p>=1 && p<=65535)) && echo "$p" && return
        error "无效端口，请输入 1-65535 之间的数字"
    done
}

_setup_crontab_dat() {
    mkdir -p "$SCRIPT_DIR"
    cat > "$UPDATE_DAT_SCRIPT" <<EOF
#!/bin/bash
curl -L -o $DAT_DIR/geoip.dat $GEOIP_URL
curl -L -o $DAT_DIR/geosite.dat $GEOSITE_URL
systemctl restart xray
EOF
    chmod +x "$UPDATE_DAT_SCRIPT"
    (crontab -l 2>/dev/null | grep -v "update-dat.sh"; echo "0 3 * * * $UPDATE_DAT_SCRIPT") | crontab -
}

do_status() {
    title "系统运行状态监控"
    local svc=$(systemctl is-active xray 2>/dev/null || echo "offline")
    echo -e "Xray 核心状态: $([[ $svc == "active" ]] && _green "运行中 (Active)" || _red "已停止 (Offline)")"
    echo -e "监听网络端口: "
    ss -tlnp | grep xray | awk '{print "  - "$4}'
    hr
    _cyan "网卡流量统计 (vnstat):"
    vnstat -i $(ip route show default | awk '/default/{print $5}') 2>/dev/null || warn "流量统计尚无足够数据或网卡未识别"
    hr
}

# --- 交互主菜单 ---
main_menu() {
    while true; do
        clear
        echo -e "${blue}===================================================${none}"
        echo -e "     Xray G7 终极融合版 (全局命令: xrv)            "
        echo -e "${blue}===================================================${none}"
        local svc=$(systemctl is-active xray 2>/dev/null || echo "offline")
        echo -e "  服务状态: $([[ $svc == "active" ]] && _green "✓ 运行中" || _red "✗ 未运行")"
        echo ""
        echo "  1) 全新安装 / 重置 Xray"
        echo "  2) VLESS 用户管理 (增删查)"
        echo "  3) 查看所有节点连接信息"
        echo "  4) 查看系统与流量状态"
        echo "  5) 强制更新 Geo 规则库"
        echo "  10) 彻底卸载清理"
        echo "  0) 退出脚本"
        hr
        read -rp "请输入选项: " num
        case "$num" in
            1) do_install; read -rp "按回车继续..." ;;
            2) do_user_menu ;;
            3) do_summary; read -rp "按回车继续..." ;;
            4) do_status; read -rp "按回车继续..." ;;
            5) bash "$UPDATE_DAT_SCRIPT"; info "Geo 规则库更新完毕"; read -rp "按回车继续..." ;;
            10) 
               systemctl stop xray; systemctl disable xray; 
               rm -rf "$CONFIG_DIR" "$XRAY_BIN" "$SCRIPT_DIR" "$SYMLINK"; 
               info "已彻底卸载并清理残留"; exit 0 ;;
            0) exit 0 ;;
            *) error "无效选项" ;;
        esac
    done
}

# --- 启动流程 ---
preflight
main_menu
