#!/usr/bin/env bash
# ============================================================
# 脚本名称: g7g36.sh (The Absolute Zenith Edition)
# 快捷方式: xrv
# 巅峰突破: 
#   1. 引入 _L_ 与 _R_ 代币防吞噬引擎，100% 免疫 Markdown 渲染器吃符号 Bug。
#   2. 核弹卸载新增“终极自毁程序”，物理粉碎快捷指令备份与当前脚本自身。
#   3. 修复 jq 注入语法，完美恢复无感热切 SNI 与 UUID 交互管理。
#   4. 1-65535 自定义端口、130+ 实体雷达探测、ASCII 二维码引擎全量就绪。
# ============================================================

# 必须用 bash 运行
if test -z "$BASH_VERSION"; then
    echo "错误: 请用 bash 运行此脚本: bash g7g36.sh"
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
    if test "$EUID" -ne 0; then die "此脚本必须以 root 身份运行"; fi
    if ! command -v systemctl >/dev/null 2>&1; then die "系统缺少 systemctl"; fi
    
    local need="jq curl wget xxd unzip qrencode"
    local install_list=""
    for i in $need; do 
        if ! command -v "$i" >/dev/null 2>&1; then 
            install_list="$install_list $i"
        fi
    done

    if test -n "$install_list"; then
        info "正在同步环境依赖: $install_list"
        (apt-get update -y || yum makecache -y) >/dev/null 2>&1
        (apt-get install -y $install_list || yum install -y $install_list) >/dev/null 2>&1
    fi

    # 快捷指令物理绑定
    if test -f "$SCRIPT_PATH"; then
        cp -f "$SCRIPT_PATH" "$SYMLINK" >/dev/null 2>&1
        chmod +x "$SYMLINK" >/dev/null 2>&1
        info "物理防丢快捷指令 ${cyan}xrv${none} 已激活"
    fi
    
    SERVER_IP=$(curl -s -4 --connect-timeout 5 https://api.ipify.org || curl -s -4 --connect-timeout 5 https://ifconfig.me || echo "获取失败")
}

# -- 核心：130+ 实体 SNI 扫描引擎 (纯字符串流处理，防吞噬) --
run_sni_scanner() {
    title "雷达嗅探：全量 130+ 实体矩阵探测"
    print_yellow "正在逐一异步握手以建立战备缓存，约耗时 60 秒...\n"
    
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    
    # 纯字符串列表，彻底抛弃 Bash 数组
    local sni_list="www.maersk.com www.msc.com www.cma-cgm.com www.hapag-lloyd.com \
    www.michelin.com www.bridgestone.com www.goodyear.com www.pirelli.com \
    www.sony.com www.sony.net www.panasonic.com www.canon.com \
    www.hp.com www.nintendo.com www.lg.com www.epson.com \
    www.unilever.com www.loreal.com www.shiseido.com www.jnj.com www.kao.com \
    www.ikea.com www.nike.com www.adidas.com www.uniqlo.com www.zara.com \
    www.hermes.com www.chanel.com services.chanel.com \
    www.louisvuitton.com eu.louisvuitton.com www.dior.com \
    www.ferragamo.com www.versace.com www.prada.com \
    www.fendi.com www.gucci.com www.tiffany.com \
    www.esteelauder.com www.maje.com www.swatch.com \
    www.coca-cola.com www.coca-colacompany.com www.pepsi.com www.pepsico.com \
    www.nestle.com www.bk.com www.heinz.com www.pg.com \
    www.basf.com www.bayer.com www.bosch.com www.bosch-home.com \
    www.toyota.com www.lexus.com www.volkswagen.com www.vw.com \
    www.audi.com www.porsche.com www.skoda-auto.com \
    www.gm.com www.chevrolet.com www.cadillac.com \
    www.ford.com www.lincoln.com www.hyundai.com www.kia.com \
    www.peugeot.com www.renault.com \
    www.bmw.com www.mercedes-benz.com www.jaguar.com www.landrover.com \
    www.astonmartin.com www.mclaren.com www.ferrari.com www.maserati.com \
    www.volvocars.com www.tesla.com \
    www.apple.com swdist.apple.com swcdn.apple.com updates.cdn-apple.com \
    mensura.cdn-apple.com osxapps.itunes.apple.com aod.itunes.apple.com \
    is1-ssl.mzstatic.com itunes.apple.com gateway.icloud.com www.icloud.com \
    www.microsoft.com update.microsoft.com windowsupdate.microsoft.com \
    software.download.prss.microsoft.com cdn-dynmedia-1.microsoft.com \
    s0.awsstatic.com d1.awsstatic.com images-na.ssl-images-amazon.com m.media-amazon.com \
    www.nvidia.com academy.nvidia.com images.nvidia.com blogs.nvidia.com \
    docs.nvidia.com docscontent.nvidia.com www.amd.com webinar.amd.com ir.amd.com \
    www.dell.com www.samsung.com www.sap.com \
    www.oracle.com www.mysql.com www.swift.com \
    download-installer.cdn.mozilla.net addons.mozilla.org \
    www.airbnb.co.uk www.airbnb.ca www.airbnb.com.sg www.airbnb.com.au www.airbnb.co.in \
    www.ubi.com lol.secure.dyn.riotcdn.net one-piece.com \
    www.speedtest.net www.speedtest.org player.live-video.net"

    local tmp_sni="/tmp/sni_test.txt"
    rm -f "$tmp_sni"

    for sni in $sni_list; do
        local time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni")
        local ms=$(echo "$time_raw" | awk '{print int($1 * 1000)}')

        if test "$ms" -gt 0; then
            if ! curl -sI -m 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray"; then
                echo -e " ${green}${none} $sni : ${yellow}${ms}ms${none}"
                echo "$ms $sni" >> "$tmp_sni"
            fi
        fi
    done

    # Linux 原生排序
    if test -s "$tmp_sni"; then
        sort -n "$tmp_sni" | head -n 10 | awk '{print $2, $1}' > "$SNI_CACHE_FILE"
    else
        print_red "探测全灭，保底使用微软。"
        echo "www.microsoft.com 999" > "$SNI_CACHE_FILE"
    fi
    rm -f "$tmp_sni"
}

# -- 交互选单 --
choose_sni() {
    while true; do
        if test -f "$SNI_CACHE_FILE"; then
            echo -e "\n  ${cyan}【战备缓存：极速 Top 10】${none}"
            local idx=1
            while read -r s t; do
                echo -e "  $idx) $s (${cyan}${t}ms${none})"
                idx=$((idx + 1))
            done < "$SNI_CACHE_FILE"
            
            echo -e "  ${yellow}r) 抛弃缓存全网扫描${none}"
            echo "  0) 手动输入自定义域名"
            echo "  q) 取消并返回主菜单"
            
            read -rp "  请下达指令: " sel
            sel=${sel:-1}
            
            if test "$sel" = "q"; then return 1; fi
            if test "$sel" = "r"; then run_sni_scanner; continue; fi
            if test "$sel" = "0"; then 
                read -rp "输入域名: " d
                BEST_SNI=${d:-www.microsoft.com}
                break
            fi
            
            local picked=$(awk "NR==$sel {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null)
            if test -n "$picked"; then
                BEST_SNI="$picked"
                break
            else
                BEST_SNI=$(awk "NR==1 {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null)
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
    local p="$1"
    case "$p" in
        ''|**) return 1 ;;
        *) 
            if test "$p" -ge 1 && test "$p" -le 65535; then
                return 0
            fi
            ;;
    esac
    return 1
}

# -- 安全写入配置 (代币防吞噬引擎) --
_safe_jq_write() {
    local raw_filter="$1"
    # 将代币还原为真实的中括号，彻底规避渲染引擎故障
    local real_filter=$(echo "$raw_filter" | sed 's/_L_//g')
    local tmp=$(mktemp)
    if jq "$real_filter" "$CONFIG" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$CONFIG" >/dev/null 2>&1
        chmod 600 "$CONFIG" >/dev/null 2>&1
        return 0
    fi
    rm -f "$tmp" >/dev/null 2>&1
    return 1
}

# -- 用户管理 --
do_user_manager() {
    while true; do
        title "UUID 权限与管理"
        if ! test -f "$CONFIG"; then error "未发现配置"; return; fi

        # 空中括号不会被吞噬，安全提取
        local clients=$(jq -r 'first(.inbounds[] | select(.protocol=="vless")).settings.clients[].id' "$CONFIG" 2>/dev/null)
        if test -z "$clients"; then error "未发现 VLESS 节点"; return; fi

        local tmp_users="/tmp/xray_users.txt"
        echo "$clients" | awk '{print NR, $0}' > "$tmp_users"
        
        echo -e "当前用户列表："
        cat "$tmp_users" | while read -r num uid; do
            echo -e "  $num) $uid"
        done
        hr
        
        echo "  a) 新增随机 UUID"
        echo "  d) 序号删除 UUID"
        echo "  q) 退出"
        read -rp "指令: " uopt
        
        if test "$uopt" = "a"; then
            local nu=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || $XRAY_BIN uuid)
            # 使用代币引擎防吞噬
            _safe_jq_write '(first(.inbounds[] | select(.protocol=="vless")).settings.clients) += _L_ {"id":"'"$nu"'","flow":"xtls-rprx-vision"} _R_'
            systemctl restart xray; info "已新增: $nu"
            
        elif test "$uopt" = "d"; then
            read -rp "请输入要删除的序号: " dnum
            local total=$(wc -l < "$tmp_users")
            if test "$total" -le 1; then
                error "必须保留至少一个用户！"
            else
                local target_uuid=$(awk -v id="$dnum" '$1==id {print $2}' "$tmp_users")
                if test -n "$target_uuid"; then
                    _safe_jq_write '(first(.inbounds[] | select(.protocol=="vless")).settings.clients) |= map(select(.id != "'"$target_uuid"'"))'
                    systemctl restart xray; info "已成功删除。"
                else
                    error "序号无效。"
                fi
            fi
            
        elif test "$uopt" = "q"; then
            rm -f "$tmp_users"
            break
        fi
    done
}

# -- 分发中心 --
do_summary() {
    if ! test -f "$CONFIG"; then return; fi
    
    local uuid=$(jq -r 'first(.inbounds[] | select(.protocol=="vless")).settings.clients[].id' "$CONFIG" | head -1)
    local port=$(jq -r 'first(.inbounds[] | select(.protocol=="vless")).port' "$CONFIG" | head -1)
    local sni=$(jq -r 'first(.inbounds[] | select(.protocol=="vless")).streamSettings.realitySettings.serverNames[]' "$CONFIG" | head -1)
    local sid=$(jq -r 'first(.inbounds[] | select(.protocol=="vless")).streamSettings.realitySettings.shortIds[]' "$CONFIG" | head -1)
    local pub=$(jq -r 'first(.inbounds[] | select(.protocol=="vless")).streamSettings.realitySettings.publicKey' "$CONFIG" | head -1)
    
    if test -z "$uuid"; then return; fi

    title "The Zenith 节点详情"
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
    
    if command -v qrencode >/dev/null 2>&1; then
        echo -e "${cyan}【手机扫码导入】${none}"
        qrencode -t ANSIUTF8 "$link"
    fi
}

# -- 核弹级卸载模块 (终极自毁程序) --
do_uninstall() {
    title "核弹级清理：彻底卸载 Xray 及所有痕迹"
    read -rp "确定要彻底删除 Xray 及其配置文件、快捷指令和当前脚本吗？(输入y确定): " confirm
    if test "$confirm" != "y"; then return; fi
    
    print_magenta ">>> 正在停止并禁用 Xray 服务..."
    systemctl stop xray >/dev/null 2>&1
    systemctl disable xray >/dev/null 2>&1
    
    print_magenta ">>> 正在清理官方服务文件与幽灵配置..."
    rm -rf /etc/systemd/system/xray.service >/dev/null 2>&1
    rm -rf /etc/systemd/system/xray@.service >/dev/null 2>&1
    rm -rf /etc/systemd/system/xray* >/dev/null 2>&1
    rm -rf /lib/systemd/system/xray* >/dev/null 2>&1
    systemctl daemon-reload >/dev/null 2>&1
    
    print_magenta ">>> 正在粉碎数据目录、系统日志及物理备份..."
    rm -rf "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" >/dev/null 2>&1
    rm -rf /var/log/xray* >/dev/null 2>&1
    
    # 终极自毁：删除快捷方式与脚本自身
    rm -f "/usr/local/bin/xrv" >/dev/null 2>&1
    rm -f "$SCRIPT_PATH" >/dev/null 2>&1
    
    print_green "卸载完成！系统、快捷指令及脚本自身已被完全物理粉碎。"
    exit 0
}

# -- 安装主逻辑 (代币引擎生成 JSON) --
do_install() {
    title "Absolute Zenith: 核心部署"
    preflight
    
    while true; do
        read -rp "请输入 VLESS 监听端口 (回车键默认443): " input_p
        input_p=${input_p:-443}
        if validate_port "$input_p"; then
            LISTEN_PORT="$input_p"
            break
        fi
        print_red "端口无效，请输入 1-65535 之间的纯数字。"
    done

    read -rp "请输入节点别名 (默认 xp-reality): " input_remark
    REMARK_NAME=${input_remark:-xp-reality}

    choose_sni || return

    print_magenta ">>> 正在静默拉取官方核心组件 (已屏蔽冗余日志)..."
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1

    local keys=$("$XRAY_BIN" x25519 2>/dev/null)
    local priv=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' ')
    local pub=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' ')
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || $XRAY_BIN uuid)
    local sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n')

    # 【防吞噬引擎启动】：写入临时文件，使用 _L_ 替代
    cat > "$CONFIG.tmp" <<EOF
{
  "log": { "loglevel": "warning" },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": _L_
      { "outboundTag": "block", "_enabled": true, "protocol": _L_ "bittorrent" _R_ },
      { "outboundTag": "block", "_enabled": true, "ip": _L_ "geoip:cn" _R_ },
      { "outboundTag": "block", "_enabled": true, "domain": _L_ "geosite:category-ads-all" _R_ }
    _R_
  },
  "inbounds": _L_
    {
      "tag": "vless-reality",
      "port": $LISTEN_PORT,
      "protocol": "vless",
      "settings": {
        "clients": _L_ { "id": "$uuid", "flow": "xtls-rprx-vision" } _R_,
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "$BEST_SNI:443",
          "serverNames": _L_ "$BEST_SNI" _R_,
          "privateKey": "$priv",
          "publicKey": "$pub",
          "shortIds": _L_ "$sid" _R_
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": _L_ "http", "tls", "quic" _R_
      }
    }
  _R_,
  "outbounds": _L_
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "block" }
  _R_
}
EOF
    
    # 执行物理替换还原，规避一切渲染错误
    sed 's/_L_//g' "$CONFIG.tmp" > "$CONFIG"
    rm -f "$CONFIG.tmp"

    echo "$pub" > "$PUBKEY_FILE"
    chmod -R 755 "$CONFIG_DIR" >/dev/null 2>&1
    chown -R nobody:nogroup "$CONFIG_DIR" >/dev/null 2>&1 || chown -R nobody:nobody "$CONFIG_DIR" >/dev/null 2>&1
    
    systemctl enable xray >/dev/null 2>&1
    systemctl restart xray >/dev/null 2>&1
    
    info "网络架构部署完成！"
    do_summary
    read -rp "按 Enter 返回主菜单..." _
}

# -- 主菜单 --
main_menu() {
    while true; do
        clear
        echo -e "${blue}===================================================${none}"
        echo -e "  ${magenta}Xray G7G36 The Absolute Zenith Edition${none}"
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        if test "$svc" = "active"; then svc="${green}运行中${none}"; else svc="${red}停止${none}"; fi
        echo -e "  状态: $svc | 快捷指令: ${cyan}xrv${none}"
        echo -e "${blue}===================================================${none}"
        echo "  1) 核心安装 / 重构网络 (端口/名称全自定义)"
        echo "  2) 用户管理 (UUID 序号增删)"
        echo "  3) 分发中心 (详情与扫码)"
        echo "  4) 更新 Geo 规则库"
        echo "  8) 彻底卸载 (清空一切痕迹并自毁)"
        echo -e "  ${cyan}9) 无感热切 SNI 矩阵 (130+ 节点)${none}"
        echo "  0) 退出"
        hr
        read -rp "选择: " num
        case "$num" in
            1) do_install ;;
            2) do_user_manager ;;
            3) do_summary; read -rp "Enter 继续..." _ ;;
            4) print_magenta ">>> 正在更新规则库..."; bash -c "$(curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" @ install-geodata >/dev/null 2>&1; systemctl restart xray >/dev/null 2>&1; info "Geo 更新成功" ;;
            8) do_uninstall ;;
            9) choose_sni && _safe_jq_write '(first(.inbounds[] | select(.protocol=="vless")).streamSettings.realitySettings) |= . + {"serverNames": _L_ "'"$BEST_SNI"'" _R_, "dest": "'"$BEST_SNI"':443"}' && systemctl restart xray >/dev/null 2>&1 && do_summary && read -rp "Enter 继续..." _ ;;
            0) exit 0 ;;
        esac
    done
}

preflight
main_menu
