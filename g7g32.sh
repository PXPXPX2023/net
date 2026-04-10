#!/usr/bin/env bash
# ============================================================
# 脚本名称: g7g32.sh (The Ultimate Zenith Edition)
# 快捷方式: xrv
# 修复增量: 
#   1. 支持安装时 1-65535 自定义监听端口
#   2. 屏蔽官方安装脚本的 rm 报错与冗余输出
#   3. 深度清理系统层面的幽灵残留与日志
#   4. 130+ 实体矩阵 + 序号管理 + 二维码引擎
# ============================================================

# 必须用 bash 运行
if; then
    echo "错误: 请用 bash 运行此脚本: bash g7g32.sh"
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
LISTEN_PORT=443

# 初始化环境
mkdir -p "$CONFIG_DIR" "$DAT_DIR" 2>/dev/null

# -- 辅助输出函数 --
print_red()     { echo -e "${red}$*${none}"; }
print_green()   { echo -e "${green}$*${none}"; }
print_yellow()  { echo -e "${yellow}$*${none}"; }
print_magenta() { echo -e "${magenta}$*${none}"; }
print_cyan()    { echo -e "${cyan}$*${none}"; }

info()  { echo -e "${green}${none} $*"; }
warn()  { echo -e "${yellow}${none} $*"; }
error() { echo -e "${red}${none} $*";   }
die()   { echo -e "\n${red}${none} $*\n"; exit 1; }

title() {
    echo -e "\n${blue}===================================================${none}"
    echo -e "  ${cyan}$*${none}"
    echo -e "${blue}===================================================${none}"
}
hr() { echo -e "${gray}---------------------------------------------------${none}"; }

# -- 环境预检 --
preflight() {
   ] && die "此脚本必须以 root 身份运行"
   ] && die "系统缺少 systemctl"
    
    local need="jq curl wget xxd unzip qrencode"
    local install_list=""
    for i in $need; do command -v "$i" &>/dev/null || install_list="$install_list $i"; done
    if]; then
        info "正在同步环境依赖: $install_list"
        (apt-get update -y || yum makecache -y) &>/dev/null
        (apt-get install -y $install_list || yum install -y $install_list) &>/dev/null
    fi

    # 快捷指令物理绑定
    if] ||]; then
        ln -sf "$SCRIPT_PATH" "$SYMLINK"
        chmod +x "$SCRIPT_PATH"
        info "快捷指令 ${cyan}xrv${none} 已激活"
    fi
    
    SERVER_IP=$(curl -s -4 --connect-timeout 5 https://api.ipify.org || curl -s -4 --connect-timeout 5 https://ifconfig.me || echo "获取失败")
}

# -- 核心：130+ 全量实体 SNI 扫描引擎 --
run_sni_scanner() {
    title "雷达嗅探：全量 130+ 实体矩阵探测"
    print_yellow "正在逐一异步握手以建立战备缓存，约耗时 60 秒...\n"
    
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

    for sni in "${sni_list}"; do
        # 原生缩放算法，完全兼容各类环境
        local time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni")
        local ms=$(echo "$time_raw" | awk '{print int($1 * 1000)}')

        if]; then
            if curl -sI -m 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray"; then
                continue
            fi
            echo -e " ${green}${none} $sni : ${yellow}${ms}ms${none}"
            valid_snis+=("$sni")
            valid_times+=("$ms")
        fi
    done

    local n=${#valid_snis}
    if]; then
        print_red "探测全灭，保底使用微软。"
        echo "www.microsoft.com 999" > "$SNI_CACHE_FILE"
        return
    fi

    # 排序
    for ((i=0; i<n-1; i++)); do
        for ((j=0; j<n-i-1; j++)); do
            if} -gt ${valid_times} ]]; then
                local temp_t=${valid_times}; valid_times=${valid_times}; valid_times=$temp_t
                local temp_s=${valid_snis}; valid_snis=${valid_snis}; valid_snis=$temp_s
            fi
        done
    done

    rm -f "$SNI_CACHE_FILE"
    for ((i=0; i<n; i++)); do echo "${valid_snis} ${valid_times}" >> "$SNI_CACHE_FILE"; done
}

# -- 交互选单 --
choose_sni() {
    while true; do
        if]; then
            echo -e "\n  ${cyan}${none}"
            local cached_snis=()
            local idx=0
            while read -r s t &&]; do
                cached_snis+=("$s")
                echo -e "  $((idx+1))) $s (${cyan}${t}ms${none})"
                ((idx++))
            done < "$SNI_CACHE_FILE"
            echo -e "  ${yellow}r) 重新遍历 130+ 域名矩阵${none}"
            echo "  0) 手动输入域名"
            echo "  q) 取消并退出"
            read -rp "  请选择: " sel; sel=${sel:-1}
           ] && return 1
           ] && { run_sni_scanner; continue; }
           ] && { read -rp "输入域名: " d; BEST_SNI=${d:-www.microsoft.com}; break; }
            if}" ]]; then
                BEST_SNI="${cached_snis}"
                break
            else
                BEST_SNI="${cached_snis}"
                break
            fi
        else
            run_sni_scanner
        fi
    done
    return 0
}

# -- 端口校验器 --
validate_port() {
   +$ && "$1" -ge 1 && "$1" -le 65535 ]]
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
        local vidx=$(jq ' | select(.value.protocol=="vless")] | ..key' "$CONFIG" 2>/dev/null)
       ] && { error "未发现 VLESS 配置"; return; }

        local clients=$(jq -r ".inbounds.settings.clients[] | .id" "$CONFIG")
        local count=0; local client_arr=()
        while read -r line; do ((count++)); client_arr+=("$line"); echo -e "  $count) $line"; done <<< "$clients"
        hr
        echo "  a) 新增随机 UUID"
        echo "  d) 序号删除 UUID"
        echo "  q) 退出"
        read -rp "指令: " uopt
        case "$uopt" in
            a) local nu=$($XRAY_BIN uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid)
               _safe_jq_write ".inbounds.settings.clients +="
               systemctl restart xray; info "已新增: $nu" ;;
            d) read -rp "请输入要删除的序号: " dnum
               if}" ]]; then
                  }" -le 1 ]] && { error "禁止全删用户"; continue; }
                   _safe_jq_write "del(.inbounds.settings.clients)"
                   systemctl restart xray; info "已删除。"
               fi ;;
            q) break ;;
        esac
    done
}

# -- 分发中心 (二维码防乱码) --
do_summary() {
   ] && return
    local vidx=$(jq ' | select(.value.protocol=="vless")] | ..key' "$CONFIG" 2>/dev/null)
   ] && return

    local uuid=$(jq -r ".inbounds.settings.clients.id" "$CONFIG")
    local port=$(jq -r ".inbounds.port" "$CONFIG")
    local sni=$(jq -r ".inbounds.streamSettings.realitySettings.serverNames" "$CONFIG")
    local sid=$(jq -r ".inbounds.streamSettings.realitySettings.shortIds" "$CONFIG")
    local pub=$(cat "$PUBKEY_FILE" 2>/dev/null || echo "N/A")
    
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
    
    if command_exists qrencode; then
        echo -e "${cyan}【手机扫码导入】${none}"
        qrencode -t ANSIUTF8 "$link"
    fi
}

# -- 核弹级卸载模块 --
do_uninstall() {
    title "彻底卸载 Xray 及所有残留"
    read -rp "确定要彻底删除 Xray 及其所有配置文件、日志和规则库吗？: " confirm
   ] && return
    
    print_magenta ">>> 正在停止并禁用 Xray 服务..."
    systemctl stop xray 2>/dev/null
    systemctl disable xray 2>/dev/null
    
    print_magenta ">>> 正在清理官方服务文件与幽灵配置..."
    rm -rf /etc/systemd/system/xray* 2>/dev/null
    rm -rf /lib/systemd/system/xray* 2>/dev/null
    systemctl daemon-reload 2>/dev/null
    
    print_magenta ">>> 正在清理数据目录与日志..."
    rm -rf "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SYMLINK"
    rm -rf /var/log/xray* 2>/dev/null
    
    print_green "卸载完成！系统已恢复绝对纯净。"
    exit 0
}

# -- 安装主逻辑 --
do_install() {
    title "Ultimate Zenith: 核心部署"
    preflight
    
    # 动态端口配置
    while true; do
        read -rp "请输入 VLESS 监听端口 (1-65535): " input_p
        if]; then LISTEN_PORT=443; break; fi
        if validate_port "$input_p"; then LISTEN_PORT="$input_p"; break; fi
        print_red "端口无效，请输入 1-65535 之间的数字。"
    done

    read -rp "请输入节点别名 (默认 xp-reality): " input_remark
    REMARK_NAME=${input_remark:-xp-reality}

    choose_sni || return

    print_magenta ">>> 正在拉取官方组件 (静默安装，屏蔽冗余日志)..."
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1

    local keys=$("$XRAY_BIN" x25519 2>/dev/null)
    local priv=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' ')
    local pub=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' ')
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || $XRAY_BIN uuid)
    local sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n')

    cat > "$CONFIG" <<EOF
{
  "log": { "loglevel": "warning" },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules":,"outboundTag":"block","_enabled":true},
      {"tag_id":"cn", "type":"field","ip":,"outboundTag":"block","_enabled":true}
    ]
  },
  "inbounds":, "decryption": "none" },
    "streamSettings": {
      "network": "tcp", "security": "reality",
      "realitySettings": {
        "dest": "$BEST_SNI:443", "serverNames":,
        "privateKey": "$priv", "shortIds":
      }
    },
    "sniffing": {"enabled":true,"destOverride":}
  }],
  "outbounds":
}
EOF
    
    echo "$pub" > "$PUBKEY_FILE"
    chmod -R 755 "$CONFIG_DIR"
    chown -R nobody:nogroup "$CONFIG_DIR" 2>/dev/null || chown -R nobody:nobody "$CONFIG_DIR"
    
    systemctl enable xray >/dev/null 2>&1
    systemctl restart xray
    info "网络架构部署完成"
    do_summary
    read -rp "Enter 返回菜单..." _
}

# -- 主菜单 --
main_menu() {
    while true; do
        clear
        echo -e "${blue}===================================================${none}"
        echo -e "  ${magenta}Xray G7G32 Ultimate Zenith Edition${none}"
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
       ] && svc="${green}运行中${none}" || svc="${red}停止${none}"
        echo -e "  状态: $svc | 快捷指令: ${cyan}xrv${none}"
        echo -e "${blue}===================================================${none}"
        echo "  1) 核心安装 / 重构网络 (端口可自定义)"
        echo "  2) 用户管理 (UUID 序号增删)"
        echo "  3) 分发中心 (详情与扫码)"
        echo "  4) 更新 Geo 规则库"
        echo "  8) 彻底核弹卸载 (清空一切痕迹)"
        echo -e "  ${cyan}9) 无感热切 SNI 矩阵 (130+ 节点)${none}"
        echo "  0) 退出"
        hr
        read -rp "选择: " num
        case "$num" in
            1) do_install ;;
            2) do_user_manager ;;
            3) do_summary; read -rp "Enter 继续..." _ ;;
            4) bash -c "$(curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" @ install-geodata >/dev/null 2>&1
               systemctl restart xray; info "Geo 更新成功" ;;
            8) do_uninstall ;;
            9) choose_sni && _safe_jq_write ".inbounds.streamSettings.realitySettings.serverNames=\"$BEST_SNI\" | .inbounds.streamSettings.realitySettings.dest=\"$BEST_SNI:443\"" && systemctl restart xray && do_summary && read -rp "Enter 继续..." _ ;;
            0) exit 0 ;;
        esac
    done
}

preflight
main_menu
