#!/usr/bin/env bash
# ============================================================
# 脚本名称: g7g26.sh (The Elite Convergence Edition)
# 融合特性: 
#   1. [排版进化] 工业级参数对齐输出矩阵，节点信息极简美学
#   2. [全量融合] g7g25 缓存热切 + g7g24 物理持久化快捷键
#   3. [终极实体盾] 完整注入 130+ 跨国实体寡头免死金牌 SNI 矩阵
#   4. [核心加固] 修正 Vision 协议 JSON 规范，确保 100% 握手成功率
# ============================================================

# ----------------- 基础环境与全局变量 -----------------
if [[ $EUID -ne 0 ]]; then
    clear
    echo -e "\033[31m[错误] 此脚本必须以 root 身份运行!\033[0m" 1>&2
    exit 1
fi

SERVER_IP=""
URL_IP=""
HAS_IPV4=false
HAS_IPV6=false
BEST_SNI="www.microsoft.com"

LOG_FILE="/var/log/xray_g7g26_install.log"
CONFIG_DIR="/usr/local/etc/xray"
CONFIG="$CONFIG_DIR/config.json"
PUBKEY_FILE="$CONFIG_DIR/public.key"
SNI_CACHE_FILE="$CONFIG_DIR/sni_cache.txt"
SCRIPT_DIR="/usr/local/etc/xray-script"
UPDATE_DAT_SCRIPT="$SCRIPT_DIR/update-dat.sh"
DAT_DIR="/usr/local/share/xray"
XRAY_BIN="/usr/local/bin/xray"
SYMLINK="/usr/local/bin/xrv"

mkdir -p "$(dirname "$LOG_FILE")" "$CONFIG_DIR" 2>/dev/null
touch "$LOG_FILE" 2>/dev/null || LOG_FILE=""

# 物理持久化快捷指令
if [[ -f "$0" ]]; then
    cp -f "$0" "$SYMLINK" 2>/dev/null
    chmod +x "$SYMLINK" 2>/dev/null
fi

# ----------------- 颜色输出与日志系统 -----------------
print_red()    { echo -e "\033[31m$1\033[0m"; [[ -n "$LOG_FILE" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
print_green()  { echo -e "\033[32m$1\033[0m"; [[ -n "$LOG_FILE" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
print_yellow() { echo -e "\033[33m$1\033[0m"; [[ -n "$LOG_FILE" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

display_cyan() { echo -e "\033[36m$1\033[0m"; }
hr()           { echo -e "\033[90m---------------------------------------------------\033[0m"; }
title() {
    echo -e "\n\033[94m===================================================\033[0m"
    echo -e "  \033[96m$1\033[0m"
    echo -e "\033[94m===================================================\033[0m"
}

log_info() { echo -e "\033[32m[✓]\033[0m $1"; }
exit_with_error() { print_red "致命错误: $1"; exit 1; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

# ----------------- 极速 SNI 嗅探引擎 (内核扫描层) -----------------
run_sni_scanner() {
    print_yellow "\n[雷达扫描] 正在探测 130+ 实体寡头矩阵，约耗时 60-90s..."
    
    local sni_list=(
        "www.maersk.com" "www.msc.com" "www.cma-cgm.com" "www.hapag-lloyd.com"
        "www.michelin.com" "www.bridgestone.com" "www.goodyear.com" "www.pirelli.com"
        "www.sony.com" "www.sony.net" "www.panasonic.com" "www.canon.com"
        "www.hp.com" "www.nintendo.com" "www.lg.com" "www.epson.com" "www.asus.com"
        "www.unilever.com" "www.loreal.com" "www.shiseido.com" "www.jnj.com" "www.kao.com"
        "www.ikea.com" "www.nike.com" "www.adidas.com" "www.uniqlo.com" "www.zara.com"
        "www.hermes.com" "www.chanel.com" "services.chanel.com"
        "www.louisvuitton.com" "eu.louisvuitton.com" "www.dior.com"
        "www.ferragamo.com" "www.versace.com" "www.prada.com"
        "www.fendi.com" "www.gucci.com" "www.tiffany.com"
        "www.esteelauder.com" "www.maje.com" "www.swatch.com"
        "www.coca-cola.com" "www.coca-colacompany.com" "www.pepsi.com" "www.pepsico.com"
        "www.nestle.com" "www.bk.com" "www.heinz.com" "www.pg.com"
        "www.basf.com" "www.bayer.com" "www.bosch.com" "www.bosch-home.com"
        "www.toyota.com" "www.lexus.com" "www.volkswagen.com" "www.vw.com" 
        "www.audi.com" "www.porsche.com" "www.skoda-auto.com"
        "www.gm.com" "www.chevrolet.com" "www.cadillac.com"
        "www.ford.com" "www.lincoln.com" "www.hyundai.com" "www.kia.com"
        "www.peugeot.com" "www.renault.com"
        "www.bmw.com" "www.mercedes-benz.com" "www.jaguar.com" "www.landrover.com" 
        "www.astonmartin.com" "www.mclaren.com" "www.ferrari.com" "www.maserati.com"
        "www.volvocars.com" "www.tesla.com"
        "www.apple.com" "swdist.apple.com" "swcdn.apple.com" "updates.cdn-apple.com"
        "mensura.cdn-apple.com" "osxapps.itunes.apple.com" "aod.itunes.apple.com"
        "is1-ssl.mzstatic.com" "itunes.apple.com" "gateway.icloud.com" "www.icloud.com"
        "www.microsoft.com" "update.microsoft.com" "windowsupdate.microsoft.com"
        "software.download.prss.microsoft.com" "cdn-dynmedia-1.microsoft.com"
        "s0.awsstatic.com" "d1.awsstatic.com" "images-na.ssl-images-amazon.com" "m.media-amazon.com"
        "www.nvidia.com" "academy.nvidia.com" "images.nvidia.com" "blogs.nvidia.com"
        "docs.nvidia.com" "docscontent.nvidia.com" "www.amd.com" "webinar.amd.com" "ir.amd.com"
        "www.cisco.com" "www.dell.com" "www.samsung.com" "www.sap.com"
        "www.oracle.com" "www.mysql.com" "www.swift.com"
        "download-installer.cdn.mozilla.net" "addons.mozilla.org"
        "www.airbnb.co.uk" "www.airbnb.ca" "www.airbnb.com.sg" "www.airbnb.com.au" "www.airbnb.co.in"
        "www.ubi.com" "lol.secure.dyn.riotcdn.net" "one-piece.com"
        "www.speedtest.net" "www.speedtest.org" "player.live-video.net"
    )

    local valid_snis=()
    local valid_times=()

    for sni in "${sni_list[@]}"; do
        local res=$(LC_ALL=C curl -sI --connect-timeout 2 -m 4 -w "\n%{time_connect}" --tls13 "https://$sni" 2>/dev/null)
        [[ -z "$res" ]] && continue
        if echo "$res" | grep -qiE "server: cloudflare|cf-ray|cf-cache-status"; then continue; fi

        local time_ms=$(echo "$res" | tail -n 1 | awk '{print int($1 * 1000)}')
        if [[ -n "$time_ms" && "$time_ms" -gt 0 ]]; then
            echo -e " \033[32m[探测]\033[0m $sni : \033[33m${time_ms}ms\033[0m"
            valid_snis+=("$sni")
            valid_times+=("$time_ms")
        fi
    done

    local n=${#valid_snis[@]}
    if [[ $n -eq 0 ]]; then
        echo "www.microsoft.com 999" > "$SNI_CACHE_FILE"
        return
    fi

    # 排序并持久化
    for ((i=0; i<n-1; i++)); do
        for ((j=0; j<n-i-1; j++)); do
            if [[ ${valid_times[j]} -gt ${valid_times[j+1]} ]]; then
                local temp_t=${valid_times[j]}; valid_times[j]=${valid_times[j+1]}; valid_times[j+1]=$temp_t
                local temp_s=${valid_snis[j]}; valid_snis[j]=${valid_snis[j+1]}; valid_snis[j+1]=$temp_s
            fi
        done
    done

    rm -f "$SNI_CACHE_FILE"
    for ((i=0; i<n; i++)); do
        echo "${valid_snis[i]} ${valid_times[i]}" >> "$SNI_CACHE_FILE"
    done
}

# ----------------- 智能选单与交互 -----------------
choose_sni() {
    while true; do
        if [[ -f "$SNI_CACHE_FILE" ]]; then
            echo -e "\n  \033[36m[发现本地战备缓存 - Top 10]\033[0m"
            local cached_snis=()
            local cached_times=()
            local idx=0
            while read -r s t && [[ $idx -lt 10 ]]; do
                cached_snis+=("$s"); cached_times+=("$t")
                echo -e "  $((idx+1))) $s ($(display_cyan "${t}ms"))"
                ((idx++))
            done < "$SNI_CACHE_FILE"
            echo -e "  \033[33mr) [重扫] 抛弃缓存全网扫描\033[0m"
            echo "  0) 手动输入自定义域名"
            read -rp "  请下达指令 [1]: " sel; sel=${sel:-1}
            if [[ "$sel" == "r" ]]; then run_sni_scanner; continue; fi
            if [[ "$sel" == "0" ]]; then read -rp "域名: " d; BEST_SNI=${d:-www.microsoft.com}; break; fi
            BEST_SNI="${cached_snis[$((sel-1))]}"; break
        else
            run_sni_scanner
        fi
    done
}

# ----------------- 数据注入系统 -----------------
_safe_jq_write() {
    local filter="$1"; local tmp=$(mktemp)
    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$CONFIG"
        chmod 600 "$CONFIG"; return 0
    fi
    rm -f "$tmp"; return 1
}

# ----------------- 工业级安装主逻辑 -----------------
do_install() {
    title "Elite Convergence: 部署 Xray 网络"
    SERVER_IP=$(curl -s -4 https://api.ipify.org || curl -s -6 https://api6.ipify.org)
    URL_IP="$SERVER_IP"; [[ "$SERVER_IP" == *":"* ]] && URL_IP="[$SERVER_IP]"
    
    choose_sni
    
    # 核心下载
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1
    
    local raw_key=$($XRAY_BIN x25519)
    local priv=$(echo "$raw_key" | awk '/Private/{print $3}')
    local pub=$(echo "$raw_key" | awk '/Public/{print $3}')
    local uuid=$($XRAY_BIN uuid)
    local sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n')

    # 初始化纯净 JSON
    cat > "$CONFIG" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": 443, "protocol": "vless", "tag": "vless-reality",
    "settings": {
      "clients": [{ "id": "$uuid", "flow": "xtls-rprx-vision" }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "tcp", "security": "reality",
      "realitySettings": {
        "dest": "$BEST_SNI:443", "serverNames": ["$BEST_SNI"],
        "privateKey": "$priv", "shortIds": ["$sid"]
      }
    },
    "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] }
  }],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF
    echo "$pub" > "$PUBKEY_FILE"
    systemctl restart xray
    print_green "\n网络拓扑构建完毕，核心服务已启动。"
    do_summary
    read -rp "按 Enter 返回总控台..." _
}

# ----------------- 无感热替换 -----------------
do_change_sni() {
    title "热插拔：无感更换 SNI 伪装层"
    choose_sni
    _safe_jq_write ".inbounds[0].streamSettings.realitySettings.serverNames[0] = \"$BEST_SNI\" | .inbounds[0].streamSettings.realitySettings.dest = \"$BEST_SNI:443\""
    systemctl restart xray
    print_green "无感变更为: $BEST_SNI"
    do_summary
}

# ----------------- 终极导出中心 (Elite Alignment) -----------------
do_summary() {
    [[ ! -f "$CONFIG" ]] && return
    local uuid=$(jq -r ".inbounds[0].settings.clients[0].id" "$CONFIG")
    local port=$(jq -r ".inbounds[0].port" "$CONFIG")
    local sni=$(jq -r ".inbounds[0].streamSettings.realitySettings.serverNames[0]" "$CONFIG")
    local sid=$(jq -r ".inbounds[0].streamSettings.realitySettings.shortIds[0]" "$CONFIG")
    local pub=$(cat "$PUBKEY_FILE" 2>/dev/null || echo "需重新生成")

    title "Elite Convergence 节点详情"
    display_cyan "【VLESS-Reality (Vision)】"
    echo -e " 协议框架       : VLESS-Reality-Vision"
    echo -e " 外网IP         : \033[32m$SERVER_IP\033[0m"
    echo -e " 端口           : $port"
    echo -e " 伪装SNI        : $sni"
    echo -e " 公钥(pbk)      : $pub"
    echo -e " ShortId        : $sid"
    echo -e " uTLS引擎       : chrome"
    echo -e " 用户 UUID      : \033[33m$uuid\033[0m"
    echo ""
    display_cyan "【通用导入链接】"
    echo -e "\033[36mvless://$uuid@$URL_IP:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$sni&fp=chrome&pbk=$pub&sid=$sid&type=tcp#xp-reality\033[0m"
    echo ""
}

# ----------------- 总调度台 -----------------
main_menu() {
    while true; do
        clear
        echo -e "\033[94m===================================================\033[0m"
        echo -e " \033[96mXray G7G26 Master Elite (输入 xrv 唤醒)\033[0m"
        echo -e "\033[94m===================================================\033[0m"
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        local ver=$($XRAY_BIN version 2>/dev/null | head -n1 | awk '{print $2}')
        echo -e " 服务状态: $svc | 核心版本: \033[33m${ver:-N/A}\033[0m"
        hr
        echo "  1) 部署网络 (安装 VLESS-Reality)"
        echo "  2) 用户管理 (UUID)"
        echo "  3) 节点详情 (分发中心)"
        echo "  8) 安全卸载"
        echo -e "  \033[96m9) [专属特权] 无感热替换 SNI\033[0m"
        echo "  0) 退出"
        hr
        read -rp "指令: " opt
        case "$opt" in
            1) do_install ;;
            2) title "UUID 列表"; jq -r ".inbounds[0].settings.clients[].id" "$CONFIG"; read -p "Enter..." ;;
            3) do_summary; read -rp "按 Enter 返回..." _ ;;
            8) systemctl stop xray; rm -f "$SYMLINK"; rm -rf "$CONFIG_DIR"; print_green "已彻底粉碎"; exit 0 ;;
            9) do_change_sni ;;
            0) exit 0 ;;
        esac
    done
}

trap 'print_red "\n中断"; exit 1' INT TERM
main_menu
