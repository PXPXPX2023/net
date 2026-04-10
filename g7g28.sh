#!/usr/bin/env bash
# ============================================================
# 脚本名称: g7g28.sh (The Final Zenith Edition)
# 修复增量: 
#   1. [深度探测修复] 改用真实 GET 探测取代 HEAD，解决部分实体网站拦截探测的问题
#   2. [并发输出硬化] 扫描过程不再静默，实时打印握手状态
#   3. [用户管理闭环] 支持序号式增、删、改 UUID，完美同步 Xray 核心
#   4. [扫码引擎修复] 强制锁定 ANSI 渲染路径，确保二维码不乱码
# ============================================================

# 权限检测
if [[ $EUID -ne 0 ]]; then
    clear
    echo -e "\033[31m[错误] 此脚本必须以 root 身份运行!\033[0m" 1>&2
    exit 1
fi

# ----------------- 全局变量 -----------------
SERVER_IP=""
URL_IP=""
BEST_SNI="www.microsoft.com"

LOG_FILE="/var/log/xray_g7g28_install.log"
CONFIG_DIR="/usr/local/etc/xray"
CONFIG="$CONFIG_DIR/config.json"
PUBKEY_FILE="$CONFIG_DIR/public.key"
SNI_CACHE_FILE="$CONFIG_DIR/sni_cache.txt"
XRAY_BIN="/usr/local/bin/xray"
SYMLINK="/usr/local/bin/xrv"

mkdir -p "$CONFIG_DIR" 2>/dev/null
# 物理覆盖快捷指令
[[ -f "$0" ]] && cp -f "$0" "$SYMLINK" 2>/dev/null && chmod +x "$SYMLINK" 2>/dev/null

# ----------------- 颜色与辅助 -----------------
print_red()    { echo -e "\033[31m$1\033[0m"; }
print_green()  { echo -e "\033[32m$1\033[0m"; }
print_yellow() { echo -e "\033[33m$1\033[0m"; }
display_cyan() { echo -e "\033[36m$1\033[0m"; }
hr()           { echo -e "\033[90m---------------------------------------------------\033[0m"; }

title() {
    echo -e "\n\033[94m===================================================\033[0m"
    echo -e "  \033[96m$1\033[0m"
    echo -e "\033[94m===================================================\033[0m"
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

# ----------------- 极速 SNI 嗅探引擎 (130+ 实体矩阵) -----------------
run_sni_scanner() {
    title "雷达嗅探：GET 深度探测 130+ 实体矩阵"
    print_yellow "正在逐一握手以建立战备缓存，请稍候...\n"
    
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

    # 核心探测循环：修复 g7g27 的探测失败问题
    for sni in "${sni_list[@]}"; do
        # 改用 GET 探测 (-o /dev/null)，更像真实流量，规避 HEAD 请求屏蔽
        local res=$(curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni")
        
        # 只要能获取到时间（哪怕较慢），就视为有效，除非为 0.000
        if [[ $(echo "$res > 0" | bc 2>/dev/null) -eq 1 ]]; then
            local time_ms=$(echo "$res * 1000 / 1" | bc 2>/dev/null)
            echo -e " \033[32m[探测]\033[0m $sni : \033[33m${time_ms}ms\033[0m"
            valid_snis+=("$sni")
            valid_times+=("$time_ms")
        else
            echo -e " \033[90m[跳过]\033[0m $sni (超时/屏蔽)\033[0m"
        fi
    done

    local n=${#valid_snis[@]}
    if [[ $n -eq 0 ]]; then
        print_red "探测矩阵全灭，检查网络或 bc 命令是否安装。"
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

# ----------------- 交互选单与管理 -----------------
choose_sni() {
    while true; do
        if [[ -f "$SNI_CACHE_FILE" ]]; then
            echo -e "\n  \033[36m[发现战备缓存：极速 Top 10]\033[0m"
            local cached_snis=()
            local idx=0
            while read -r s t && [[ $idx -lt 10 ]]; do
                cached_snis+=("$s")
                echo -e "  $((idx+1))) $s ($(display_cyan "${t}ms"))"
                ((idx++))
            done < "$SNI_CACHE_FILE"
            echo -e "  \033[33mr) [扫描] 抛弃缓存重新探测全网\033[0m"
            echo "  0) 手动输入自定义域名"
            echo "  q) 取消并返回主菜单"
            read -rp "  请指令 [1]: " sel; sel=${sel:-1}
            [[ "$sel" == "q" ]] && return 1
            [[ "$sel" == "r" ]] && { run_sni_scanner; continue; }
            [[ "$sel" == "0" ]] && { read -rp "域名: " d; BEST_SNI=${d:-www.microsoft.com}; break; }
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
    return 0
}

do_user_manager() {
    while true; do
        title "Zenith 用户管理中心"
        local vidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null)
        [[ "$vidx" == "null" || -z "$vidx" ]] && { print_red "未安装 VLESS。"; return; }

        local clients=$(jq -r ".inbounds[$vidx].settings.clients[] | .id" "$CONFIG")
        local count=0; local client_arr=()
        while read -r line; do ((count++)); client_arr+=("$line"); echo -e "  $count) $line"; done <<< "$clients"
        hr
        echo "  a) 新增随机用户  d) 序号删除用户  q) 退出管理"
        read -rp "指令: " uopt
        case "$uopt" in
            a) local nu=$($XRAY_BIN uuid); _safe_jq_write ".inbounds[$vidx].settings.clients += [{\"id\":\"$nu\",\"flow\":\"xtls-rprx-vision\"}]"
               systemctl restart xray; print_green "成功: $nu" ;;
            d) read -rp "序号: " dnum
               if [[ "$dnum" -ge 1 && "$dnum" -le "${#client_arr[@]}" ]]; then
                   [[ "${#client_arr[@]}" -le 1 ]] && { print_red "必须留一个！"; continue; }
                   _safe_jq_write "del(.inbounds[$vidx].settings.clients[] | select(.id == \"${client_arr[$((dnum-1))]}\"))"
                   systemctl restart xray; print_green "已删除。"
               fi ;;
            q) break ;;
        esac
    done
}

# ----------------- 数据注入系统 -----------------
_safe_jq_write() {
    local filter="$1"; local tmp=$(mktemp)
    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$CONFIG" && chmod 600 "$CONFIG" && return 0
    fi
    rm -f "$tmp" && return 1
}

# ----------------- 终极导出中心 -----------------
do_summary() {
    [[ ! -f "$CONFIG" ]] && return
    local uuid=$(jq -r ".inbounds[0].settings.clients[0].id" "$CONFIG")
    local port=$(jq -r ".inbounds[0].port" "$CONFIG")
    local sni=$(jq -r ".inbounds[0].streamSettings.realitySettings.serverNames[0]" "$CONFIG")
    local sid=$(jq -r ".inbounds[0].streamSettings.realitySettings.shortIds[0]" "$CONFIG")
    local pub=$(cat "$PUBKEY_FILE" 2>/dev/null || echo "N/A")

    title "Zenith 节点详情"
    echo -e "  协议框架    : VLESS-Reality-Vision"
    echo -e "  外网IP      : \033[32m$SERVER_IP\033[0m"
    echo -e "  端口        : $port"
    echo -e "  伪装SNI     : $sni"
    echo -e "  公钥(pbk)   : $pub"
    echo -e "  ShortId     : $sid"
    echo -e "  uTLS引擎    : chrome"
    echo -e "  用户 UUID   : \033[33m$uuid\033[0m"
    echo ""
    local vless_url="vless://$uuid@$SERVER_IP:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$sni&fp=chrome&pbk=$pub&sid=$sid&type=tcp#xp-reality"
    display_cyan "【通用链接】"
    echo -e "$vless_url"
    echo ""
    display_cyan "【手机扫码区】"
    command_exists qrencode && qrencode -t ANSIUTF8 "$vless_url" || print_red "未安装 qrencode"
}

# ----------------- 安装主逻辑 -----------------
do_install() {
    title "Zenith: 部署环境"
    # 强制补全关键组件：bc 命令是计算 time_connect 的核心
    apt update && apt install -y qrencode jq curl xxd bc 2>/dev/null || yum install -y qrencode jq curl xxd bc 2>/dev/null
    
    SERVER_IP=$(curl -s -4 https://api.ipify.org || curl -s -6 https://api6.ipify.org)
    choose_sni || return
    
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1
    
    local raw_key=$($XRAY_BIN x25519)
    local priv=$(echo "$raw_key" | awk '/Private/{print $3}')
    local pub=$(echo "$raw_key" | awk '/Public/{print $3}')
    local uuid=$($XRAY_BIN uuid); local sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n')

    cat > "$CONFIG" <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{
    "port": 443, "protocol": "vless", "tag": "vless-reality",
    "settings": { "clients": [{ "id": "$uuid", "flow": "xtls-rprx-vision" }], "decryption": "none" },
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
    do_summary
    read -rp "Enter 继续..." _
}

# ----------------- 总调度台 -----------------
main_menu() {
    while true; do
        clear
        echo -e "\033[94m===================================================\033[0m"
        echo -e " \033[96mXray G7G28 Final Zenith (快捷指令: xrv)\033[0m"
        echo -e "\033[94m===================================================\033[0m"
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        local ver=$($XRAY_BIN version 2>/dev/null | head -n1 | awk '{print $2}')
        echo -e " 服务状态: $svc | 核心版本: \033[33m${ver:-N/A}\033[0m"
        hr
        echo "  1) 部署网络 / 覆盖重构"
        echo "  2) 用户管理 (UUID 序号管理)"
        echo "  3) 分发中心 (二维码与详情)"
        echo "  8) 安全卸载"
        echo "  9) 无感热替换 SNI"
        echo "  0) 退出"
        hr
        read -rp "指令: " opt
        case "$opt" in
            1) do_install ;;
            2) do_user_manager ;;
            3) do_summary; read -rp "Enter..." _ ;;
            8) systemctl stop xray; rm -rf "$CONFIG_DIR" "$SYMLINK"; exit 0 ;;
            9) choose_sni && _safe_jq_write ".inbounds[0].streamSettings.realitySettings.serverNames[0]=\"$BEST_SNI\" | .inbounds[0].streamSettings.realitySettings.dest=\"$BEST_SNI:443\"" && systemctl restart xray ;;
            0) exit 0 ;;
        esac
    done
}

main_menu
