#!/usr/bin/env bash
# ============================================================
# 脚本名称: g7g25.sh (The Master Convergence Edition)
# 融合特性: 
#   1. [全量融合] g7g21 战备缓存热切 + g7g24 物理持久化快捷键
#   2. [终极实体盾] 完整注入 130+ 跨国实体寡头免死金牌 SNI 矩阵
#   3. [架构纠偏] 修正 VLESS-Reality 的 Padding 注入位置，解决核心崩溃
#   4. [链接标准化] 修复 SS 链接 Base64url 编码，适配所有客户端
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

LOG_FILE="/var/log/xray_g7g25_install.log"
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

# 物理持久化快捷指令 (g7g24 核心特性)
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
log_err()  { echo -e "\033[31m[✗]\033[0m $1"; }
exit_with_error() { print_red "致命错误: $1"; exit 1; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

# ----------------- 极速 SNI 嗅探引擎 (内核扫描层) -----------------
run_sni_scanner() {
    print_yellow "\n[深度雷达] 正在启动 4000ms 极速扫描，全网遍历 130+ 实体寡头..."
    print_yellow "预计耗时 60-90 秒，完成后将记录至战备缓存...\n"
    
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
        local res
        # 异步连接探测 (connect 2s / max 4s)
        res=$(LC_ALL=C curl -sI --connect-timeout 2 -m 4 -w "\n%{time_connect}" --tls13 "https://$sni" 2>/dev/null)
        
        [[ -z "$res" ]] && continue
        if echo "$res" | grep -qiE "server: cloudflare|cf-ray|cf-cache-status"; then continue; fi

        local time_ms=$(echo "$res" | tail -n 1 | awk '{print int($1 * 1000)}')

        if [[ -n "$time_ms" && "$time_ms" -gt 0 ]]; then
            echo -e " \033[32m[+]\033[0m $sni : \033[33m${time_ms}ms\033[0m"
            valid_snis+=("$sni")
            valid_times+=("$time_ms")
        fi
    done

    local n=${#valid_snis[@]}
    if [[ $n -eq 0 ]]; then
        print_red "\n=> 极端情况：网络受阻，写入保底配置"
        echo "www.microsoft.com 999" > "$SNI_CACHE_FILE"
        return
    fi

    # 冒泡排序
    for ((i=0; i<n-1; i++)); do
        for ((j=0; j<n-i-1; j++)); do
            if [[ ${valid_times[j]} -gt ${valid_times[j+1]} ]]; then
                local temp_t=${valid_times[j]}; valid_times[j]=${valid_times[j+1]}; valid_times[j+1]=$temp_t
                local temp_s=${valid_snis[j]}; valid_snis[j]=${valid_snis[j+1]}; valid_snis[j+1]=$temp_s
            fi
        done
    done

    # 写入缓存库
    rm -f "$SNI_CACHE_FILE"
    for ((i=0; i<n; i++)); do
        echo "${valid_snis[i]} ${valid_times[i]}" >> "$SNI_CACHE_FILE"
    done
    print_green "\n嗅探完毕！已建立本地防墙战备缓存库。"
}

# ----------------- 交互选单 (带缓存识别) -----------------
choose_sni() {
    while true; do
        if [[ -f "$SNI_CACHE_FILE" ]]; then
            echo -e "\n  \033[36m[发现本地节点缓存！展示 Top 10 极速赢家]\033[0m"
            local cached_snis=()
            local cached_times=()
            local idx=0
            while read -r s t; do
                [[ -z "$s" || -z "$t" ]] && continue
                cached_snis+=("$s")
                cached_times+=("$t")
                ((idx++))
                [[ $idx -ge 10 ]] && break
            done < "$SNI_CACHE_FILE"

            for ((i=0; i<${#cached_snis[@]}; i++)); do
                local ms_color="\033[32m"
                [[ ${cached_times[i]} -gt 150 ]] && ms_color="\033[33m"
                [[ ${cached_times[i]} -gt 300 ]] && ms_color="\033[31m"
                echo -e "  $((i+1))) ${cached_snis[i]} (近期延迟: ${ms_color}${cached_times[i]}ms\033[0m)"
            done
            echo -e "  \033[33mr) [扫描] 抛弃缓存全网重新雷达测速\033[0m"
            echo "  0) 手动输入自定义域名"

            read -rp "  请指令 [1]: " sel
            sel=${sel:-1}
            if [[ "$sel" == "r" ]]; then run_sni_scanner; continue; fi
            if [[ "$sel" == "0" ]]; then read -rp "域名: " d; BEST_SNI=${d:-www.microsoft.com}; break; fi
            if [[ "$sel" -ge 1 && "$sel" -le "${#cached_snis[@]}" ]]; then
                BEST_SNI="${cached_snis[$((sel-1))]}"
                break
            else
                BEST_SNI="${cached_snis[0]}"
                break
            fi
        else
            run_sni_scanner
        fi
    done
    print_green "=> 已锁定核心伪装层: $BEST_SNI"
}

# ----------------- 数据防护与生成器 -----------------
_safe_jq_write() {
    local filter="$1"; local tmp; tmp=$(mktemp /tmp/xray_cfg_XXXXXX.json)
    local bak="${CONFIG}.bak.$(date +%s)"
    [[ -f "$CONFIG" ]] && cp "$CONFIG" "$bak"
    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null && jq empty "$tmp" 2>/dev/null; then
        mv "$tmp" "$CONFIG"
        chmod 600 "$CONFIG"; return 0
    fi
    log_err "JSON 原子注入失败，自动回滚!"
    [[ -f "$bak" ]] && mv "$bak" "$CONFIG"
    rm -f "$tmp"; return 1
}

gen_uuid() { "$XRAY_BIN" uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid; }
gen_short_id() { head -c 8 /dev/urandom | xxd -p | tr -d '\n'; }
gen_ss_pass() { head -c 24 /dev/urandom | base64 | tr -d '=/+\n' | head -c 24; }

# ----------------- 安装主逻辑 (全量融合) -----------------
do_install() {
    title "Master Convergence: 部署网络"
    SERVER_IP=$(curl -s -4 https://api.ipify.org || curl -s -6 https://api6.ipify.org)
    
    echo -e "\n  [拓扑模式选择]"
    echo "  1) VLESS-Reality + XTLS Vision (推荐)"
    echo "  2) Shadowsocks"
    echo "  3) 全部安装"
    read -rp "  请选择 [1]: " choice; choice=${choice:-1}

    choose_sni
    
    # 核心安装
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1
    
    local raw_key=$($XRAY_BIN x25519)
    local priv=$(echo "$raw_key" | awk '/Private/{print $3}')
    local pub=$(echo "$raw_key" | awk '/Public/{print $3}')
    local uuid=$(gen_uuid); local sid=$(gen_short_id)

    # 初始化工业级配置结构
    cat > "$CONFIG" <<EOF
{
  "log": { "loglevel": "warning" },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {"tag_id":"bt", "type":"field","protocol":["bittorrent"],"outboundTag":"block","_enabled":true},
      {"tag_id":"cn", "type":"field","ip":["geoip:cn"],"outboundTag":"block","_enabled":true},
      {"tag_id":"ads","type":"field","domain":["geosite:category-ads-all"],"outboundTag":"block","_enabled":true}
    ]
  },
  "inbounds": [],
  "outbounds": [{"protocol":"freedom","tag":"direct"},{"protocol":"blackhole","tag":"block"}]
}
EOF

    if [[ "$choice" == "1" || "$choice" == "3" ]]; then
        # 架构修正：g7g21 的 Padding 注入位置修正
        _safe_jq_write ".inbounds += [{
          \"tag\": \"vless-reality\", \"port\": 443, \"protocol\": \"vless\",
          \"settings\": {
            \"clients\": [{ \"id\": \"$uuid\", \"flow\": \"xtls-rprx-vision\" }],
            \"decryption\": \"none\"
          },
          \"streamSettings\": {
            \"network\": \"tcp\", \"security\": \"reality\",
            \"realitySettings\": {
              \"dest\": \"$BEST_SNI:443\", \"serverNames\": [\"$BEST_SNI\"],
              \"privateKey\": \"$priv\", \"shortIds\": [\"$sid\"]
            }
          },
          \"sniffing\": {\"enabled\":true,\"destOverride\":[\"http\",\"tls\",\"quic\"]}
        }]"
        echo "$pub" > "$PUBKEY_FILE"
    fi

    if [[ "$choice" == "2" || "$choice" == "3" ]]; then
        local ss_pass=$(gen_ss_pass)
        _safe_jq_write ".inbounds += [{
            \"tag\": \"shadowsocks\", \"port\": 8388, \"protocol\": \"shadowsocks\",
            \"settings\": { \"method\": \"aes-256-gcm\", \"password\": \"$ss_pass\", \"network\": \"tcp,udp\" }
        }]"
    fi

    systemctl restart xray
    print_green "\n网络拓扑构建完毕！"
    do_summary
    read -rp "按 Enter 返回总控台..." _
}

# ----------------- 独立工具：无感热替换 SNI -----------------
do_change_sni() {
    title "热插拔：无感更换 SNI 伪装源"
    local vidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null)
    if [[ "$vidx" == "null" || -z "$vidx" ]]; then
        print_yellow "未发现 VLESS 配置。"; return
    fi
    
    choose_sni
    _safe_jq_write "
      .inbounds[$vidx].streamSettings.realitySettings.serverNames[0] = \"$BEST_SNI\" |
      .inbounds[$vidx].streamSettings.realitySettings.dest = \"$BEST_SNI:443\"
    "
    systemctl restart xray
    print_green "无感变更为: $BEST_SNI"
    do_summary
}

# ----------------- 分发中心 (Base64url 修正) -----------------
do_summary() {
    title "节点分享分发"
    [[ ! -f "$CONFIG" ]] && return
    local vidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null)
    if [[ "$vidx" != "null" ]]; then
        local uuid=$(jq -r ".inbounds[$vidx].settings.clients[0].id" "$CONFIG")
        local sni=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.serverNames[0]" "$CONFIG")
        local sid=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.shortIds[0]" "$CONFIG")
        local pub=$(cat "$PUBKEY_FILE" 2>/dev/null || echo "N/A")
        display_cyan "【VLESS-Reality (Vision)】"
        echo -e "vless://$uuid@$SERVER_IP:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$sni&fp=chrome&pbk=$pub&sid=$sid&type=tcp#xp-reality"
    fi

    local sidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="shadowsocks")] | .[0].key' "$CONFIG" 2>/dev/null)
    if [[ "$sidx" != "null" ]]; then
        local spass=$(jq -r ".inbounds[$sidx].settings.password" "$CONFIG")
        local sm=$(jq -r ".inbounds[$sidx].settings.method" "$CONFIG")
        # 修复：Shadowsocks 标准 Base64url (无填充)
        local b64=$(printf '%s' "${sm}:${spass}" | base64 | tr '+/' '-_' | tr -d '=')
        display_cyan "\n【Shadowsocks (GCM)】"
        echo -e "ss://${b64}@$SERVER_IP:8388#xp-ss"
    fi
}

# ----------------- 总调度台 -----------------
main_menu() {
    while true; do
        clear
        echo -e "\033[94m===================================================\033[0m"
        echo -e " \033[96mXray G7G25 Master Convergence (输入 xrv 唤醒)\033[0m"
        echo -e "\033[94m===================================================\033[0m"
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        local cur_ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 | awk '{print $2}')
        echo -e " 服务状态: $svc | 版本: \033[33m${cur_ver:-N/A}\033[0m | $([[ -f $SNI_CACHE_FILE ]] && echo "缓存就绪" || echo "缓存未建立")"
        hr
        echo "  1) 部署网络 / 覆盖重构"
        echo "  2) 用户管理 (UUID)"
        echo "  3) 分享节点 (查看配置)"
        echo "  7) 强制更新 Geo 规则库"
        echo "  8) 彻底安全卸载"
        echo -e "  \033[96m9) [专属特权] 无感热替换 SNI 伪装\033[0m"
        echo "  0) 退出"
        hr
        read -rp "请下达指令: " opt
        case "$opt" in
            1) do_install ;;
            2) title "UUID 列表"; jq -r ".inbounds[0].settings.clients[].id" "$CONFIG"; read -p "Enter..." ;;
            3) do_summary; read -rp "按 Enter 返回..." _ ;;
            7) curl -fsSL -o "$DAT_DIR/geoip.dat" "https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"; curl -fsSL -o "$DAT_DIR/geosite.dat" "https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat"; systemctl restart xray; print_green "Geo 同步完成" ;;
            8) systemctl stop xray; rm -f "$SYMLINK"; rm -rf "$CONFIG_DIR" "$DAT_DIR"; print_green "卸载完成"; exit 0 ;;
            9) do_change_sni ;;
            0) exit 0 ;;
        esac
    done
}

trap 'print_red "\n中断"; exit 1' INT TERM
main_menu
