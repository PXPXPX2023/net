#!/usr/bin/env bash
# ============================================================
# 脚本名称: g7g27.sh (The Supreme Integration Edition)
# 修复增量: 
#   1. [用户管理] 交互式序号增删 UUID，实时同步 Xray
#   2. [SNI 引擎] 物理对齐 130+ 实体域名，优化嗅探成功率
#   3. [扫码分发] 终端 ASCII 二维码显示，手机秒导
#   4. [交互闭环] 增加 q/0 退出机制，防止扫描陷阱
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
HAS_IPV4=false
HAS_IPV6=false
BEST_SNI="www.microsoft.com"

LOG_FILE="/var/log/xray_g7g27_install.log"
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
    title "雷达嗅探：正在并发探测 130+ 全球实体域名"
    print_yellow "正在逐一握手以建立战备缓存，约耗时 1 分钟...\n"
    
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
        # 探测 2s 超时，握手 4s 超时
        local res=$(LC_ALL=C curl -sI --connect-timeout 2 -m 4 -w "\n%{time_connect}" --tls13 "https://$sni" 2>/dev/null)
        [[ -z "$res" ]] && continue
        if echo "$res" | grep -qiE "server: cloudflare|cf-ray|cf-cache-status"; then continue; fi

        local time_ms=$(echo "$res" | tail -n 1 | awk '{print int($1 * 1000)}')
        if [[ -n "$time_ms" && "$time_ms" -gt 0 ]]; then
            echo -e " \033[32m[探测成功]\033[0m $sni : \033[33m${time_ms}ms\033[0m"
            valid_snis+=("$sni")
            valid_times+=("$time_ms")
        fi
    done

    local n=${#valid_snis[@]}
    if [[ $n -eq 0 ]]; then
        print_red "扫描受限，使用微软保底。"
        echo "www.microsoft.com 999" > "$SNI_CACHE_FILE"
        return
    fi

    # 排序
    for ((i=0; i<n-1; i++)); do
        for ((j=0; j<n-i-1; j++)); do
            if [[ ${valid_times[j]} -gt ${valid_times[j+1]} ]]; then
                local temp_t=${valid_times[j]}; valid_times[j]=${valid_times[j+1]}; valid_times[j+1]=$temp_t
                local temp_s=${valid_snis[j]}; valid_snis[j]=${valid_snis[j+1]}; valid_snis[j+1]=$temp_s
            fi
        done
    done

    # 写入缓存
    rm -f "$SNI_CACHE_FILE"
    for ((i=0; i<n; i++)); do
        echo "${valid_snis[i]} ${valid_times[i]}" >> "$SNI_CACHE_FILE"
    done
}

# ----------------- 智能选单与交互 -----------------
choose_sni() {
    while true; do
        if [[ -f "$SNI_CACHE_FILE" ]]; then
            echo -e "\n  \033[36m[发现战备缓存：近期极速 Top 10]\033[0m"
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
            read -rp "  请下达指令 [1]: " sel; sel=${sel:-1}
            [[ "$sel" == "q" ]] && return 1
            [[ "$sel" == "r" ]] && { run_sni_scanner; continue; }
            [[ "$sel" == "0" ]] && { read -rp "输入域名: " d; BEST_SNI=${d:-www.microsoft.com}; break; }
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

# ----------------- 用户管理 (交互增删) -----------------
do_user_manager() {
    while true; do
        title "多用户权限管理"
        local vidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null)
        if [[ "$vidx" == "null" || -z "$vidx" ]]; then
            print_red "未安装 VLESS 协议。"; return
        fi

        echo -e "当前用户列表："
        local clients=$(jq -r ".inbounds[$vidx].settings.clients[] | .id" "$CONFIG")
        local count=0
        local client_arr=()
        while read -r line; do
            ((count++))
            client_arr+=("$line")
            echo -e "  $count) $line"
        done <<< "$clients"
        hr
        echo "  a) 新增随机用户"
        echo "  d) 删除指定序号用户"
        echo "  q) 返回主菜单"
        read -rp "操作: " uopt
        case "$uopt" in
            a)
                local nu=$($XRAY_BIN uuid)
                _safe_jq_write ".inbounds[$vidx].settings.clients += [{\"id\":\"$nu\",\"flow\":\"xtls-rprx-vision\"}]"
                systemctl restart xray; print_green "新增成功: $nu" ;;
            d)
                read -rp "请输入要删除的用户序号: " dnum
                if [[ "$dnum" -ge 1 && "$dnum" -le "${#client_arr[@]}" ]]; then
                    if [[ "${#client_arr[@]}" -le 1 ]]; then
                        print_red "必须保留至少一个用户。"; continue
                    fi
                    local target_uuid="${client_arr[$((dnum-1))]}"
                    _safe_jq_write "del(.inbounds[$vidx].settings.clients[] | select(.id == \"$target_uuid\"))"
                    systemctl restart xray; print_green "用户已移除。"
                else
                    print_red "序号错误。"
                fi ;;
            q) break ;;
        esac
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

# ----------------- 终端二维码引擎 -----------------
show_qr() {
    local url="$1"
    if command_exists qrencode; then
        echo ""
        qrencode -t ANSIUTF8 "$url"
    else
        print_yellow "未安装 qrencode，无法显示二维码。"
    fi
}

# ----------------- 安装主逻辑 -----------------
do_install() {
    title "Supreme Integration: 部署环境"
    # 环境依赖补齐
    apt update && apt install -y qrencode jq curl xxd 2>/dev/null || yum install -y qrencode jq curl xxd 2>/dev/null
    
    SERVER_IP=$(curl -s -4 https://api.ipify.org || curl -s -6 https://api6.ipify.org)
    URL_IP="$SERVER_IP"; [[ "$SERVER_IP" == *":"* ]] && URL_IP="[$SERVER_IP]"
    
    choose_sni || return
    
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1
    
    local raw_key=$($XRAY_BIN x25519)
    local priv=$(echo "$raw_key" | awk '/Private/{print $3}')
    local pub=$(echo "$raw_key" | awk '/Public/{print $3}')
    local uuid=$($XRAY_BIN uuid)
    local sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n')

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
    print_green "\n网络拓扑部署成功！"
    do_summary
    read -rp "按 Enter 返回主菜单..." _
}

# ----------------- 无感热替换 -----------------
do_change_sni() {
    title "热插拔：无感更换 SNI"
    choose_sni || return
    _safe_jq_write ".inbounds[0].streamSettings.realitySettings.serverNames[0] = \"$BEST_SNI\" | .inbounds[0].streamSettings.realitySettings.dest = \"$BEST_SNI:443\""
    systemctl restart xray; print_green "热更成功。"
    do_summary
}

# ----------------- 终极导出与分发中心 -----------------
do_summary() {
    [[ ! -f "$CONFIG" ]] && return
    local uuid=$(jq -r ".inbounds[0].settings.clients[0].id" "$CONFIG")
    local port=$(jq -r ".inbounds[0].port" "$CONFIG")
    local sni=$(jq -r ".inbounds[0].streamSettings.realitySettings.serverNames[0]" "$CONFIG")
    local sid=$(jq -r ".inbounds[0].streamSettings.realitySettings.shortIds[0]" "$CONFIG")
    local pub=$(cat "$PUBKEY_FILE" 2>/dev/null || echo "N/A")

    title "Elite 节点详情"
    display_cyan "【VLESS-Reality (Vision)】"
    echo -e "  协议框架    : VLESS-Reality-Vision"
    echo -e "  外网IP      : \033[32m$SERVER_IP\033[0m"
    echo -e "  端口        : $port"
    echo -e "  伪装SNI     : $sni"
    echo -e "  公钥(pbk)   : $pub"
    echo -e "  ShortId     : $sid"
    echo -e "  uTLS引擎    : chrome"
    echo -e "  用户 UUID   : \033[33m$uuid\033[0m"
    echo ""
    local vless_url="vless://$uuid@$URL_IP:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$sni&fp=chrome&pbk=$pub&sid=$sid&type=tcp#xp-reality"
    display_cyan "【通用导入链接】"
    echo -e "$vless_url"
    echo ""
    display_cyan "【手机扫码区】"
    show_qr "$vless_url"
}

# ----------------- 总调度台 -----------------
main_menu() {
    while true; do
        clear
        echo -e "\033[94m===================================================\033[0m"
        echo -e " \033[96mXray G7G27 Supreme Integration (输入 xrv 唤醒)\033[0m"
        echo -e "\033[94m===================================================\033[0m"
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        local ver=$($XRAY_BIN version 2>/dev/null | head -n1 | awk '{print $2}')
        echo -e " 服务状态: $svc | 核心版本: \033[33m${ver:-N/A}\033[0m"
        hr
        echo "  1) 部署网络 / 覆盖重构"
        echo "  2) 用户管理 (UUID 序号增删)"
        echo "  3) 分发中心 (详情与二维码)"
        echo "  8) 安全卸载"
        echo -e "  \033[96m9) [专属特权] 无感热替换 SNI\033[0m"
        echo "  0) 退出"
        hr
        read -rp "指令: " opt
        case "$opt" in
            1) do_install ;;
            2) do_user_manager ;;
            3) do_summary; read -rp "按 Enter 返回..." _ ;;
            8) systemctl stop xray; rm -f "$SYMLINK"; rm -rf "$CONFIG_DIR"; print_green "已彻底粉碎"; exit 0 ;;
            9) do_change_sni ;;
            0) exit 0 ;;
        esac
    done
}

trap 'print_red "\n中断"; exit 1' INT TERM
main_menu
