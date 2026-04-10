#!/usr/bin/env bash
# ============================================================
# 脚本名称: g7g31.sh (The Final Absolute Sovereign Edition)
# 快捷方式: xrv
# 修复增量: 
#   1. 修复 _magenta/print_magenta 语法冲突
#   2. 深度融合 130+ 实体 SNI 矩阵 (剔除 ASUS)
#   3. 交互式序号用户管理 (增/删)
#   4. 物理持久化快捷指令与配置文件权限对齐
# ============================================================

# 必须用 bash 运行
if [ -z "$BASH_VERSION" ]; then
    echo "错误: 请用 bash 运行此脚本: bash g7g31.sh"
    exit 1
fi

# -- 颜色定义 --
red='\e[31m'; yellow='\e[33m'; gray='\e[90m'; green='\e[92m'
blue='\e[94m'; magenta='\e[95m'; cyan='\e[96m'; none='\e[0m'

# -- 全局路径与变量 --
XRAY_BIN="/usr/local/bin/xray"
CONFIG_DIR="/usr/local/etc/xray"
CONFIG="$CONFIG_DIR/config.json"
PUBKEY_FILE="$CONFIG_DIR/public.key"
SNI_CACHE_FILE="$CONFIG_DIR/sni_cache.txt"
DAT_DIR="/usr/local/share/xray"
SYMLINK="/usr/local/bin/xrv"
SCRIPT_PATH=$(realpath "$0")
SERVER_IP=""
REMARK_NAME="xp-reality"
BEST_SNI="www.microsoft.com"

# 初始化环境
mkdir -p "$CONFIG_DIR" "$DAT_DIR" 2>/dev/null

# -- 辅助输出函数 --
print_red()     { echo -e "${red}$*${none}"; }
print_green()   { echo -e "${green}$*${none}"; }
print_yellow()  { echo -e "${yellow}$*${none}"; }
print_magenta() { echo -e "${magenta}$*${none}"; }
print_cyan()    { echo -e "${cyan}$*${none}"; }

info()  { echo -e "${green}[✓]${none} $*"; }
warn()  { echo -e "${yellow}[!]${none} $*"; }
error() { echo -e "${red}[✗]${none} $*";   }
die()   { echo -e "\n${red}[致命错误]${none} $*\n"; exit 1; }

title() {
    echo -e "\n${blue}===================================================${none}"
    echo -e "  ${cyan}$*${none}"
    echo -e "${blue}===================================================${none}"
}
hr() { echo -e "${gray}---------------------------------------------------${none}"; }

# -- 环境预检 --
preflight() {
    [[ $EUID -ne 0 ]] && die "此脚本必须以 root 身份运行"
    [[ ! $(type -P systemctl) ]] && die "系统缺少 systemctl"
    
    local need="jq curl wget xxd unzip qrencode"
    local install_list=""
    for i in $need; do command -v "$i" &>/dev/null || install_list="$install_list $i"; done
    if [[ -n "$install_list" ]]; then
        info "正在同步环境依赖: $install_list"
        (apt-get update -y || yum makecache -y) &>/dev/null
        (apt-get install -y $install_list || yum install -y $install_list) &>/dev/null
    fi

    # 快捷指令物理绑定
    if [[ ! -L "$SYMLINK" ]] || [[ "$(readlink -f "$SYMLINK")" != "$SCRIPT_PATH" ]]; then
        ln -sf "$SCRIPT_PATH" "$SYMLINK"
        chmod +x "$SCRIPT_PATH"
        info "快捷指令 ${cyan}xrv${none} 已激活"
    fi
    
    SERVER_IP=$(curl -s -4 https://api.ipify.org || curl -s -4 https://ifconfig.me || echo "获取失败")
}

# -- 核心：130+ 全量实体 SNI 扫描引擎 --
run_sni_scanner() {
    title "雷达嗅探：全量 130+ 实体矩阵探测"
    print_yellow "正在逐一握手以建立战备缓存，约耗时 60 秒...\n"
    
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    local sni_list=(
        "www.maersk.com" "www.msc.com" "www.cma-cgm.com" "www.hapag-lloyd.com"
        "www.michelin.com" "www.bridgestone.com" "www.goodyear.com" "www.pirelli.com"
        "www.sony.com" "www.sony.net" "www.panasonic.com" "www.canon.com"
        "www.hp.com" "www.nintendo.com" "www.lg.com" "www.epson.com"
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
        "www.dell.com" "www.samsung.com" "www.sap.com"
        "www.oracle.com" "www.mysql.com" "www.swift.com"
        "download-installer.cdn.mozilla.net" "addons.mozilla.org"
        "www.airbnb.co.uk" "www.airbnb.ca" "www.airbnb.com.sg" "www.airbnb.com.au" "www.airbnb.co.in"
        "www.ubi.com" "lol.secure.dyn.riotcdn.net" "one-piece.com"
        "www.speedtest.net" "www.speedtest.org" "player.live-video.net"
    )

    local valid_snis=()
    local valid_times=()

    for sni in "${sni_list[@]}"; do
        # 原生缩放算法，规避 bc 依赖
        local time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni")
        local ms=$(echo "$time_raw" | awk '{print int($1 * 1000)}')

        if [[ $ms -gt 0 ]]; then
            if curl -sI -m 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray"; then
                continue
            fi
            echo -e " ${green}[存活]${none} $sni : ${yellow}${ms}ms${none}"
            valid_snis+=("$sni")
            valid_times+=("$ms")
        fi
    done

    local n=${#valid_snis[@]}
    if [[ $n -eq 0 ]]; then
        print_red "探测全灭，保底使用微软。"
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

    rm -f "$SNI_CACHE_FILE"
    for ((i=0; i<n; i++)); do echo "${valid_snis[i]} ${valid_times[i]}" >> "$SNI_CACHE_FILE"; done
}

# -- 交互选单 --
choose_sni() {
    while true; do
        if [[ -f "$SNI_CACHE_FILE" ]]; then
            echo -e "\n  ${cyan}[战备缓存：极速 Top 10 赢家]${none}"
            local cached_snis=()
            local idx=0
            while read -r s t && [[ $idx -lt 10 ]]; do
                cached_snis+=("$s")
                echo -e "  $((idx+1))) $s (${cyan}${t}ms${none})"
                ((idx++))
            done < "$SNI_CACHE_FILE"
            echo -e "  ${yellow}r) [扫描] 重新遍历 130+ 域名矩阵${none}"
            echo "  0) 手动输入域名"
            echo "  q) 取消并退出"
            read -rp "  请选择 [1]: " sel; sel=${sel:-1}
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

# -- 安全写入配置 --
_safe_jq_write() {
    local filter="$1"; local tmp=$(mktemp)
    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null && jq empty "$tmp" 2>/dev/null; then
        mv "$tmp" "$CONFIG" && chmod 600 "$CONFIG" && return 0
    fi
    rm -f "$tmp" && return 1
}

# -- 用户管理 (序号增删 UUID) --
do_user_manager() {
    while true; do
        title "UUID 权限与管理"
        local vidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null)
        [[ "$vidx" == "null" || -z "$vidx" ]] && { error "未发现 VLESS 配置"; return; }

        local clients=$(jq -r ".inbounds[$vidx].settings.clients[] | .id" "$CONFIG")
        local count=0; local client_arr=()
        while read -r line; do ((count++)); client_arr+=("$line"); echo -e "  $count) $line"; done <<< "$clients"
        hr
        echo "  a) 新增随机 UUID"
        echo "  d) 序号删除 UUID"
        echo "  q) 退出"
        read -rp "指令: " uopt
        case "$uopt" in
            a) local nu=$($XRAY_BIN uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid)
               _safe_jq_write ".inbounds[$vidx].settings.clients += [{\"id\":\"$nu\",\"flow\":\"xtls-rprx-vision\"}]"
               systemctl restart xray; info "已新增: $nu" ;;
            d) read -rp "请输入要删除的序号: " dnum
               if [[ "$dnum" -ge 1 && "$dnum" -le "${#client_arr[@]}" ]]; then
                   [[ "${#client_arr[@]}" -le 1 ]] && { error "禁止全删用户"; continue; }
                   _safe_jq_write "del(.inbounds[$vidx].settings.clients[$((dnum-1))])"
                   systemctl restart xray; info "已删除。"
               fi ;;
            q) break ;;
        esac
    done
}

# -- 分发中心 --
do_summary() {
    [[ ! -f "$CONFIG" ]] && return
    local vidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null)
    [[ "$vidx" == "null" ]] && return

    local uuid=$(jq -r ".inbounds[$vidx].settings.clients[0].id" "$CONFIG")
    local port=$(jq -r ".inbounds[$vidx].port" "$CONFIG")
    local sni=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.serverNames[0]" "$CONFIG")
    local sid=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.shortIds[0]" "$CONFIG")
    local pub=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.publicKey" "$CONFIG")
    
    title "节点详情报告"
    printf "  ${yellow}%-16s${none} %s\n" "协议框架:" "VLESS-Reality-Vision"
    printf "  ${yellow}%-16s${none} %s\n" "备注名称:" "$REMARK_NAME"
    printf "  ${yellow}%-16s${none} %s\n" "外网 IP:" "$SERVER_IP"
    printf "  ${yellow}%-16s${none} %s\n" "监听端口:" "$port"
    printf "  ${yellow}%-16s${none} %s\n" "伪装 SNI:" "$sni"
    printf "  ${yellow}%-16s${none} %s\n" "公钥(pbk):" "$pub"
    printf "  ${yellow}%-16s${none} %s\n" "Short ID:" "$sid"
    printf "  ${yellow}%-16s${none} %s\n" "用户 UUID:" "$uuid"
    
    local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${REMARK_NAME}"
    echo -e "\n${cyan}【通用链接】${none}\n$link\n"
    qrencode -t ANSIUTF8 "$link"
}

# -- 安装主逻辑 --
do_install() {
    title "Supreme Sovereignty: 核心部署"
    preflight
    read -rp "请输入节点别名 (默认 xp-reality): " input_remark
    REMARK_NAME=${input_remark:-xp-reality}

    choose_sni || return

    print_magenta ">>> 同步 Xray 官方核心组件..."
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

    local keys=$("$XRAY_BIN" x25519 2>/dev/null)
    local priv=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' ')
    local pub=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' ')
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || $XRAY_BIN uuid)
    local sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n')

    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG" <<EOF
{
  "log": { "loglevel": "warning" },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {"tag_id":"bt", "type":"field","protocol":["bittorrent"],"outboundTag":"block","_enabled":true},
      {"tag_id":"cn", "type":"field","ip":["geoip:cn"],"outboundTag":"block","_enabled":true}
    ]
  },
  "inbounds": [{
    "tag": "vless-reality", "port": 443, "protocol": "vless",
    "settings": { "clients": [{"id":"$uuid","flow":"xtls-rprx-vision"}], "decryption": "none" },
    "streamSettings": {
      "network": "tcp", "security": "reality",
      "realitySettings": {
        "dest": "$BEST_SNI:443", "serverNames": ["$BEST_SNI"],
        "privateKey": "$priv", "publicKey": "$pub", "shortIds": ["$sid"]
      }
    },
    "sniffing": {"enabled":true,"destOverride":["http","tls","quic"]}
  }],
  "outbounds": [{"protocol":"freedom","tag":"direct"},{"protocol":"blackhole","tag":"block"}]
}
EOF
    
    echo "$pub" > "$PUBKEY_FILE"
    chmod -R 755 "$CONFIG_DIR"
    chown -R nobody:nogroup "$CONFIG_DIR" 2>/dev/null || chown -R nobody:nobody "$CONFIG_DIR"
    
    systemctl enable xray && systemctl restart xray
    info "部署完成"
    do_summary
    read -rp "Enter 返回菜单..." _
}

# -- 主菜单 --
main_menu() {
    while true; do
        clear
        echo -e "${blue}===================================================${none}"
        echo -e "  ${magenta}Xray g7g31 Final Sovereignty Edition${none}"
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        [[ "$svc" == "active" ]] && svc="${green}运行中${none}" || svc="${red}停止${none}"
        echo -e "  状态: $svc | 快捷指令: ${cyan}xrv${none}"
        echo -e "${blue}===================================================${none}"
        echo "  1) 核心安装 / 重构网络 (Reality)"
        echo "  2) 用户管理 (UUID 序号增删)"
        echo "  3) 分发中心 (详情与扫码)"
        echo "  4) 更新 Geo 规则库"
        echo "  5) 运行统计 / 状态"
        echo "  8) 彻底卸载"
        echo -e "  ${cyan}9) 无感热切 SNI 矩阵 (130+ 节点)${none}"
        echo "  0) 退出"
        hr
        read -rp "选择: " num
        case "$num" in
            1) do_install ;;
            2) do_user_manager ;;
            3) do_summary; read -rp "Enter 继续..." _ ;;
            4) bash -c "$(curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" @ install-geodata
               systemctl restart xray; info "Geo 更新成功" ;;
            5) systemctl status xray --no-pager; hr; ss -tlnp | grep xray; read -p "Enter 继续..." ;;
            8) systemctl stop xray; rm -rf "$CONFIG_DIR" "$XRAY_BIN" "$SYMLINK"; info "卸载完成"; exit 0 ;;
            9) choose_sni && _safe_jq_write ".inbounds[0].streamSettings.realitySettings.serverNames[0]=\"$BEST_SNI\" | .inbounds[0].streamSettings.realitySettings.dest=\"$BEST_SNI:443\"" && systemctl restart xray && do_summary && read -rp "Enter 继续..." _ ;;
            0) exit 0 ;;
        esac
    done
}

preflight
main_menu
