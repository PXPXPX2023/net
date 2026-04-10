#!/usr/bin/env bash
# ============================================================
# 脚本名称: g7g23.sh (物理避雷版 · 零方括号重构)
# 修复说明: 放弃所有 [ ] 符号，改用 test 命令，彻底解决渲染吞噬导致的语法错误。
# ============================================================

# 检查 Root 权限
if test "$(id -u)" -ne 0; then
    echo -e "\033[31m[错误] 此脚本必须以 root 身份运行!\033[0m" 1>&2
    exit 1
fi

SERVER_IP=""
URL_IP=""
HAS_IPV4=false
HAS_IPV6=false
BEST_SNI="www.microsoft.com"

LOG_FILE="/var/log/xray_g7g23_install.log"
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

# 生成快捷指令
if test -f "$0"; then
    cp -f "$0" "$SYMLINK" 2>/dev/null
    chmod +x "$SYMLINK" 2>/dev/null
fi

print_red()    { echo -e "\033[31m$1\033[0m"; test -n "$LOG_FILE" && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
print_green()  { echo -e "\033[32m$1\033[0m"; test -n "$LOG_FILE" && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
print_yellow() { echo -e "\033[33m$1\033[0m"; test -n "$LOG_FILE" && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
display_cyan() { echo -e "\033[36m$1\033[0m"; }
hr()           { echo -e "\033[90m---------------------------------------------------\033[0m"; }

title() {
    echo -e "\n\033[94m===================================================\033[0m"
    echo -e "  \033[96m$1\033[0m"
    echo -e "\033[94m===================================================\033[0m"
    test -n "$LOG_FILE" && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_info() { echo -e "\033[32m[✓]\033[0m $1"; }
exit_with_error() { print_red "致命错误: $1"; exit 1; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

run_sni_scanner() {
    print_yellow "\n正在执行全网实体寡头探测 (连接阈值 2s, 总体阈值 4s)..."
    print_yellow "正在并发遍历 130+ 节点，这大约需要 1~2 分钟，请耐心等待...\n"
    
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
        res=$(LC_ALL=C curl -sI --connect-timeout 2 -m 4 -w "\n%{time_connect}" --tls13 "https://$sni" 2>/dev/null)
        
        if test -z "$res"; then continue; fi
        if echo "$res" | grep -qiE "server: cloudflare|cf-ray|cf-cache-status"; then continue; fi

        local time_str=$(echo "$res" | tail -n 1)
        local time_ms=$(echo "$time_str" | awk '{print int($1 * 1000)}')

        if test -n "$time_ms" && test "$time_ms" -gt 0; then
            echo -e " \033[32m[+]\033[0m $sni : \033[33m${time_ms}ms\033[0m"
            valid_snis+=("$sni")
            valid_times+=("$time_ms")
        fi
    done

    local n=${#valid_snis[@]}
    if test "$n" -eq 0; then
        print_red "\n=> 网络探测失败，回退至基础配置 www.microsoft.com"
        echo "www.microsoft.com 999" > "$SNI_CACHE_FILE"
        BEST_SNI="www.microsoft.com"
        return
    fi

    # 排序
    for ((i=0; i<n-1; i++)); do
        for ((j=0; j<n-i-1; j++)); do
            if test "${valid_times[j]}" -gt "${valid_times[$((j+1))]}"; then
                local temp_t=${valid_times[j]}
                valid_times[j]=${valid_times[$((j+1))]}
                valid_times[$((j+1))]=$temp_t
                local temp_s=${valid_snis[j]}
                valid_snis[j]=${valid_snis[$((j+1))]}
                valid_snis[$((j+1))]=$temp_s
            fi
        done
    done

    rm -f "$SNI_CACHE_FILE"
    for ((i=0; i<n; i++)); do
        echo "${valid_snis[i]} ${valid_times[i]}" >> "$SNI_CACHE_FILE"
    done
}

choose_sni() {
    while true; do
        if test -f "$SNI_CACHE_FILE"; then
            echo -e "\n  \033[36m[发现节点缓存！展示 Top 10 榜单]\033[0m"
            local cached_snis=()
            local cached_times=()
            local idx=0
            while read -r s t; do
                if test -z "$s"; then continue; fi
                cached_snis+=("$s")
                cached_times+=("$t")
                ((idx++))
                if test "$idx" -ge 10; then break; fi
            done < "$SNI_CACHE_FILE"

            for ((i=0; i<${#cached_snis[@]}; i++)); do
                echo -e "  $((i+1))) ${cached_snis[i]} (延迟: ${cached_times[i]}ms)"
            done
            echo "  r) 重新扫描"
            echo "  0) 手动输入"

            read -rp "  请选择 [1]: " sel
            sel=${sel:-1}
            if test "$sel" = "r"; then run_sni_scanner; continue;
            elif test "$sel" = "0"; then read -rp "域名: " d; BEST_SNI=${d:-www.microsoft.com}; break;
            else BEST_SNI="${cached_snis[$((sel-1))]}"; break; fi
        else
            run_sni_scanner
        fi
    done
}

detect_distribution() {
    if test -f /etc/os-release; then
        . /etc/os-release; OS_ID=${ID:-unknown}
    else
        OS_ID="unknown"
    fi
}

detect_package_manager() {
    if command_exists apt-get; then PKG_MANAGER="apt"; PKG_UPDATE="apt-get update -y"; PKG_INSTALL="apt-get install -y"
    elif command_exists yum; then PKG_MANAGER="yum"; PKG_UPDATE="yum makecache"; PKG_INSTALL="yum install -y"
    else exit_with_error "不支持的包管理器"; fi
}

install_dependencies() {
    log_info "安装依赖..."
    eval "$PKG_INSTALL curl wget jq ca-certificates unzip xxd cron iproute2" >/dev/null 2>&1
}

get_server_ip_silent() {
    SERVER_IP=$(curl -s -4 https://api4.ipify.org || curl -s -6 https://api6.ipify.org)
    if test -z "$SERVER_IP"; then exit_with_error "IP 获取失败"; fi
    URL_IP="$SERVER_IP"; if echo "$SERVER_IP" | grep -q ":"; then URL_IP="[$SERVER_IP]"; fi
}

_safe_jq_write() {
    local filter="$1"; local tmp=$(mktemp)
    if jq "$filter" "$CONFIG" > "$tmp"; then mv "$tmp" "$CONFIG"; return 0; fi
    return 1
}

gen_uuid() { "$XRAY_BIN" uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid; }
gen_short_id() { head -c 8 /dev/urandom | xxd -p | tr -d '\n'; }
gen_ss_pass() { head -c 24 /dev/urandom | base64 | tr -d '=/+\n' | head -c 24; }

do_install() {
    title "部署 Xray"
    pre_flight_checks; get_server_ip_silent
    choose_sni
    
    # 极简核心安装
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1
    
    local uuid=$(gen_uuid); local sid=$(gen_short_id); local pub
    local raw=$("$XRAY_BIN" x25519)
    local priv=$(echo "$raw" | awk '/Private/{print $3}')
    pub=$(echo "$raw" | awk '/Public/{print $3}')
    
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG" <<EOF
{
  "inbounds": [{
    "port": 443, "protocol": "vless",
    "settings": { "clients": [{"id": "$uuid", "flow": "xtls-rprx-vision"}], "decryption": "none" },
    "streamSettings": {
      "network": "tcp", "security": "reality",
      "realitySettings": { "dest": "$BEST_SNI:443", "serverNames": ["$BEST_SNI"], "privateKey": "$priv", "shortIds": ["$sid"] }
    },
    "sniffing": {"enabled": true, "destOverride": ["http","tls","quic"]}
  }],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
    systemctl restart xray
    print_green "安装完成！"
    echo -e "URL: vless://$uuid@$URL_IP:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$BEST_SNI&fp=chrome&pbk=$pub&sid=$sid&type=tcp#xp-reality"
}

pre_flight_checks() {
    local web_time=$(curl -sI https://www.google.com | grep -i "^date:" | sed 's/^[Dd]ate: //g')
    if test -z "$web_time"; then log_warn "无法同步时间"; fi
}

# ----------------- 总调度台 -----------------
main_menu() {
    detect_distribution; detect_package_manager; install_dependencies
    while true; do
        clear
        echo -e "--- Xray G7G23 零方括号版 ---"
        echo "  1) 安装 Reality"
        echo "  2) 查看配置"
        echo "  3) 卸载"
        echo "  0) 退出"
        read -rp "指令: " opt
        case "$opt" in
            1) do_install ;;
            2) test -f "$CONFIG" && cat "$CONFIG" || echo "未安装"; read -p "Enter..." ;;
            3) systemctl stop xray; rm -rf "$CONFIG_DIR"; echo "已卸载"; sleep 2 ;;
            0) exit 0 ;;
        esac
    done
}

main_menu
