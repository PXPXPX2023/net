#!/usr/bin/env bash
# ============================================================
# 脚本名称: g7g39.sh (The Pinnacle Ascendant Edition)
# 快捷方式: xrv
# 巅峰突破: 
#   1. 启用十六进制 \x5B \x5D 全局变量引擎，物理级免疫 Markdown 吞噬 Bug。
#   2. 恢复 VLESS / Shadowsocks 双协议共存系统。
#   3. 130+ 实体矩阵新增 Cloudflare CDN 精准物理探测与直观标记。
#   4. 引入半块 UTF8 渲染技术，终端二维码视觉体积直接缩小 50%。
#   5. 完美移植 9) 运行状态模块 (包含 IP、DNS、vnstat 网卡级流量统计)。
# ============================================================

# 必须用 bash 运行
if test -z "$BASH_VERSION"; then
    echo "错误: 请用 bash 运行此脚本: bash g7g39.sh"
    exit 1
fi

# -- 颜色定义 --
red='\e[31m'; yellow='\e[33m'; gray='\e[90m'; green='\e[92m'
blue='\e[94m'; magenta='\e[95m'; cyan='\e[96m'; none='\e[0m'

# -- 终极防吞噬十六进制常量定义 (规避底层渲染器吃符号 Bug) --
L_B=$(printf '\x5B')
R_B=$(printf '\x5D')

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

info()  { echo -e "${green}✓${none} $*"; }
warn()  { echo -e "${yellow}!${none} $*"; }
error() { echo -e "${red}✗${none} $*";   }
die()   { echo -e "\n${red}致命错误${none} $*\n"; exit 1; }

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
    
    # 增加 vnstat 以支持流量统计
    local need="jq curl wget xxd unzip qrencode vnstat"
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
        systemctl start vnstat >/dev/null 2>&1 || true
    fi

    # 快捷指令物理绑定
    if test -f "$SCRIPT_PATH"; then
        cp -f "$SCRIPT_PATH" "$SYMLINK" >/dev/null 2>&1
        chmod +x "$SYMLINK" >/dev/null 2>&1
        info "物理防丢快捷指令 ${cyan}xrv${none} 已激活"
    fi
    
    SERVER_IP=$(curl -s -4 --connect-timeout 5 https://api.ipify.org || curl -s -4 --connect-timeout 5 https://ifconfig.me || echo "获取失败")
}

# -- 核心：130+ 实体 SNI 扫描引擎 (带 CF 探测，纯字符串防吞噬) --
run_sni_scanner() {
    title "雷达嗅探：全量 130+ 实体矩阵探测"
    print_yellow "正在执行深度握手测试并物理鉴定 CDN，耗时约 60 秒...\n"
    
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    
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
            # 物理鉴定 Cloudflare 拦截墙
            if curl -sI -m 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray"; then
                echo -e " ${green}存活${none} $sni : ${yellow}${ms}ms${none} | ${red}CF 拦截网${none}"
                echo "$ms $sni YES_CF" >> "$tmp_sni"
            else
                echo -e " ${green}存活${none} $sni : ${yellow}${ms}ms${none} | ${cyan}原生直连${none}"
                echo "$ms $sni NO_CF" >> "$tmp_sni"
            fi
        fi
    done

    # 优先筛选原生节点，排满 10 个，不足用 CF 凑数
    if test -s "$tmp_sni"; then
        grep "NO_CF" "$tmp_sni" | sort -n | head -n 10 | awk '{print $2, $1}' > "$SNI_CACHE_FILE"
        local c=$(wc -l < "$SNI_CACHE_FILE")
        if test "$c" -lt 10; then
            grep "YES_CF" "$tmp_sni" | sort -n | head -n $((10 - c)) | awk '{print $2, $1}' >> "$SNI_CACHE_FILE"
        fi
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
            echo -e "\n  ${cyan}战备缓存：极速 Top 10 (已优先原生直连)${none}"
            local idx=1
            while read -r s t; do
                echo -e "  $idx) $s (${cyan}${t}ms${none})"
                idx=$((idx + 1))
            done < "$SNI_CACHE_FILE"
            
            echo -e "  ${yellow}r) 抛弃缓存重新扫描矩阵${none}"
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
    if test -z "$p"; then return 1; fi
    local check=$(echo "$p" | tr -d '0-9')
    if test -n "$check"; then return 1; fi
    if test "$p" -ge 1 2>/dev/null && test "$p" -le 65535 2>/dev/null; then
        return 0
    fi
    return 1
}

# -- 安全写入配置 (jq 注入) --
_safe_jq_write() {
    local filter="$1"
    local tmp=$(mktemp)
    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$CONFIG" >/dev/null 2>&1
        chmod 600 "$CONFIG" >/dev/null 2>&1
        return 0
    fi
    rm -f "$tmp" >/dev/null 2>&1
    return 1
}

# -- SS 工具 --
gen_ss_pass() {
    head -c 24 /dev/urandom | base64 | tr -d '=/+\n' | head -c 24
}
_select_ss_method() {
    echo -e "  ${cyan}选择 SS 加密方式：${none}" >&2
    echo "  1) aes-256-gcm (推荐)  2) aes-128-gcm  3) chacha20-ietf-poly1305" >&2
    read -rp "  编号: " mc >&2
    case "${mc:-1}" in
        2) echo "aes-128-gcm" ;;
        3) echo "chacha20-ietf-poly1305" ;;
        *) echo "aes-256-gcm" ;;
    esac
}

# -- 用户管理 (十六进制防吞噬) --
do_user_manager() {
    while true; do
        title "UUID 权限与管理"
        if ! test -f "$CONFIG"; then error "未发现配置"; return; fi

        # 使用物理字符组装 jq，防 Markdown 吃符号
        local clients=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .settings.clients${L_B}${R_B} | .id" "$CONFIG" 2>/dev/null)
        if test -z "$clients" || test "$clients" = "null"; then error "未发现 VLESS 节点"; return; fi

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
            _safe_jq_write "(.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .settings.clients) += ${L_B} {\"id\":\"$nu\",\"flow\":\"xtls-rprx-vision\"} ${R_B}"
            systemctl restart xray; info "已新增: $nu"
            
        elif test "$uopt" = "d"; then
            read -rp "请输入要删除的序号: " dnum
            local total=$(wc -l < "$tmp_users")
            if test "$total" -le 1; then
                error "必须保留至少一个用户！"
            else
                local target_uuid=$(awk -v id="$dnum" '$1==id {print $2}' "$tmp_users")
                if test -n "$target_uuid"; then
                    _safe_jq_write "(.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .settings.clients) |= map(select(.id != \"$target_uuid\"))"
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

# -- 屏蔽规则管理 --
_global_block_rules() {
    while true; do
        title "屏蔽规则管理"
        if ! test -f "$CONFIG"; then error "未发现配置"; return; fi
        local bt_en=$(jq -r ".routing.rules${L_B}${R_B} | select(.protocol | index(\"bittorrent\")) | ._enabled" "$CONFIG" 2>/dev/null | head -1)
        
        echo "  1) BT/PT 屏蔽开关 当前状态: ${yellow}${bt_en}${none}"
        echo "  0) 返回"
        read -rp "选择: " bc
        if test "$bc" = "0"; then return; fi
        
        local nv="true"; if test "$bt_en" = "true"; then nv="false"; fi
        _safe_jq_write "(.routing.rules${L_B}${R_B} | select(.protocol | index(\"bittorrent\")) | ._enabled) = $nv"
        systemctl restart xray; info "已切换 BT 屏蔽状态为: $nv"
    done
}

# -- 分发中心 (双协议输出 + 缩半体积二维码) --
do_summary() {
    if ! test -f "$CONFIG"; then return; fi
    title "The Pinnacle 节点详情中心"
    
    # -- VLESS 解析 --
    local v_count=$(jq ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | length" "$CONFIG" 2>/dev/null || echo 0)
    if test "$v_count" -gt 0; then
        # 物理级提取字段防吞噬
        local uuid=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .settings.clients${L_B}0${R_B}.id" "$CONFIG" 2>/dev/null)
        local port=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .port" "$CONFIG" 2>/dev/null)
        local sni=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.serverNames${L_B}0${R_B}" "$CONFIG" 2>/dev/null)
        local sid=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.shortIds${L_B}0${R_B}" "$CONFIG" 2>/dev/null)
        local pub=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.publicKey" "$CONFIG" 2>/dev/null)
        
        if test -n "$uuid" && test "$uuid" != "null"; then
            hr
            printf "  ${cyan}【VLESS-Reality (Vision)】${none}\n"
            printf "  ${yellow}%-16s${none} %s\n" "备注名称:" "$REMARK_NAME"
            printf "  ${yellow}%-16s${none} %s\n" "外网 IP:" "$SERVER_IP"
            printf "  ${yellow}%-16s${none} %s\n" "监听端口:" "$port"
            printf "  ${yellow}%-16s${none} %s\n" "伪装 SNI:" "$sni"
            printf "  ${yellow}%-16s${none} %s\n" "公钥(pbk):" "$pub"
            printf "  ${yellow}%-16s${none} %s\n" "Short ID:" "$sid"
            printf "  ${yellow}%-16s${none} %s\n" "用户 UUID:" "$uuid"
            
            local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${REMARK_NAME}"
            echo -e "\n  ${cyan}通用链接:${none} \n  $link\n"
            
            if command -v qrencode >/dev/null 2>&1; then
                echo -e "  ${cyan}手机扫码导入 (缩小版 50%):${none}"
                # 使用 -t UTF8 半块字符大幅缩小高度，不辣眼睛
                qrencode -t UTF8 "$link"
            fi
        fi
    fi

    # -- SS 解析 --
    local s_count=$(jq ".inbounds${L_B}${R_B} | select(.protocol==\"shadowsocks\") | length" "$CONFIG" 2>/dev/null || echo 0)
    if test "$s_count" -gt 0; then
        local s_port=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"shadowsocks\") | .port" "$CONFIG" 2>/dev/null)
        local s_pass=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"shadowsocks\") | .settings.password" "$CONFIG" 2>/dev/null)
        local s_method=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"shadowsocks\") | .settings.method" "$CONFIG" 2>/dev/null)
        
        if test -n "$s_port" && test "$s_port" != "null"; then
            hr
            printf "  ${cyan}【Shadowsocks】${none}\n"
            printf "  ${yellow}%-16s${none} %s\n" "端口:" "$s_port"
            printf "  ${yellow}%-16s${none} %s\n" "密码:" "$s_pass"
            printf "  ${yellow}%-16s${none} %s\n" "加密方式:" "$s_method"
            
            local b64=$(printf '%s' "${s_method}:${s_pass}" | base64 | tr -d '\n')
            local link_ss="ss://${b64}@${SERVER_IP}:${s_port}#${REMARK_NAME}-SS"
            echo -e "\n  ${cyan}通用链接:${none} \n  $link_ss\n"
            
            if command -v qrencode >/dev/null 2>&1; then
                echo -e "  ${cyan}手机扫码导入 (缩小版 50%):${none}"
                qrencode -t UTF8 "$link_ss"
            fi
        fi
    fi
}

# -- 运行状态模块 --
do_status_menu() {
    while true; do
        title "运行状态中心"
        echo "  1) 服务运行状态 (systemctl)"
        echo "  2) IP 与 监听端口信息"
        echo "  3) 网卡流量统计 (vnstat)"
        echo "  0) 返回主菜单"
        hr
        read -rp "选择: " s
        case "$s" in
            1) systemctl status xray --no-pager; read -rp "按 Enter 继续..." _ ;;
            2) 
                echo -e "\n  公网 IP: ${green}$SERVER_IP${none}"
                hr
                echo -e "  DNS 解析配置: "
                grep "^nameserver" /etc/resolv.conf | awk '{print "    " $0}'
                hr
                echo -e "  Xray 监听端口: "
                ss -tlnp | grep xray | awk '{print "    " $4}'
                read -rp "按 Enter 继续..." _ ;;
            3) 
                if ! command -v vnstat >/dev/null 2>&1; then 
                    warn "未安装 vnstat，无法统计流量。"
                else
                    local iface=$(ip route show default | awk '/default/{print $5}' | head -1)
                    vnstat -i "$iface"
                fi
                read -rp "按 Enter 继续..." _ ;;
            0) return ;;
        esac
    done
}

# -- 核弹级卸载模块 (终极自毁程序) --
do_uninstall() {
    title "清理：彻底卸载 Xray 及所有痕迹"
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

# -- 安装主逻辑 (防吞噬代币引擎) --
do_install() {
    title "Pinnacle Ascendant: 核心部署"
    preflight
    
    echo -e "  ${cyan}请选择要安装的代理协议：${none}"
    echo "  1) VLESS-Reality (推荐, 强力防封)"
    echo "  2) Shadowsocks (建议落地机使用)"
    echo "  3) 两个都安装 (双管齐下)"
    read -rp "  请输入编号: " proto_choice
    proto_choice=${proto_choice:-1}

    # 采集 VLESS 参数
    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        while true; do
            read -rp "请输入 VLESS 监听端口 (回车键默认443): " input_p
            input_p=${input_p:-443}
            if validate_port "$input_p"; then LISTEN_PORT="$input_p"; break; fi
            print_red "端口无效，请输入 1-65535 之间的纯数字。"
        done
        read -rp "请输入节点别名 (默认 xp-reality): " input_remark
        REMARK_NAME=${input_remark:-xp-reality}
        choose_sni || return
    fi

    # 采集 SS 参数
    local ss_port=8388; local ss_pass=""; local ss_method="aes-256-gcm"
    if test "$proto_choice" = "2" || test "$proto_choice" = "3"; then
        while true; do
            read -rp "请输入 SS 监听端口 (回车键默认8388): " input_s
            input_s=${input_s:-8388}
            if validate_port "$input_s"; then ss_port="$input_s"; break; fi
            print_red "端口无效，请输入 1-65535 之间的纯数字。"
        done
        ss_pass=$(gen_ss_pass)
        ss_method=$(_select_ss_method)
        # 如果单独选 SS 也要输节点名
        if test "$proto_choice" = "2"; then
            read -rp "请输入节点别名 (默认 xp-reality): " input_remark
            REMARK_NAME=${input_remark:-xp-reality}
        fi
    fi

    print_magenta ">>> 正在静默拉取官方核心组件 (已屏蔽冗余日志)..."
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1

    # 【ASCII Hex 物理防吞噬引擎】：用代币 _L_ 和 _R_ 写入模板，屏蔽渲染器攻击
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
  "inbounds": _L_ _R_,
  "outbounds": _L_
    { "protocol": "freedom", "tag": "direct" },
    { "protocol": "blackhole", "tag": "block" }
  _R_
}
EOF
    # 底层恢复为原生 JSON 数组
    sed "s/_L_/${L_B}/g; s/_R_/${R_B}/g" "$CONFIG.tmp" > "$CONFIG"
    rm -f "$CONFIG.tmp"

    # 动态注入 VLESS
    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        local keys=$("$XRAY_BIN" x25519 2>/dev/null)
        local priv=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' ')
        local pub=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' ')
        local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || $XRAY_BIN uuid)
        local sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n')
        
        echo "$pub" > "$PUBKEY_FILE"
        
        local VLESS_INBOUND='{
            "tag": "vless-reality",
            "listen": "0.0.0.0",
            "port": '$LISTEN_PORT',
            "protocol": "vless",
            "settings": {
                "clients": _L_ { "id": "'$uuid'", "flow": "xtls-rprx-vision" } _R_,
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "dest": "'$BEST_SNI':443",
                    "serverNames": _L_ "'$BEST_SNI'" _R_,
                    "privateKey": "'$priv'",
                    "publicKey": "'$pub'",
                    "shortIds": _L_ "'$sid'" _R_
                }
            },
            "sniffing": { "enabled": true, "destOverride": _L_ "http", "tls", "quic" _R_ }
        }'
        VLESS_INBOUND=$(echo "$VLESS_INBOUND" | sed "s/_L_/${L_B}/g; s/_R_/${R_B}/g")
        _safe_jq_write ".inbounds += ${L_B} ${VLESS_INBOUND} ${R_B}"
    fi

    # 动态注入 SS
    if test "$proto_choice" = "2" || test "$proto_choice" = "3"; then
        local SS_INBOUND='{
            "tag": "shadowsocks",
            "listen": "0.0.0.0",
            "port": '$ss_port',
            "protocol": "shadowsocks",
            "settings": {
                "method": "'$ss_method'",
                "password": "'$ss_pass'",
                "network": "tcp,udp"
            }
        }'
        _safe_jq_write ".inbounds += ${L_B} ${SS_INBOUND} ${R_B}"
    fi

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
        echo -e "  ${magenta}Xray G7G39 The Pinnacle Ascendant Edition${none}"
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        if test "$svc" = "active"; then svc="${green}运行中${none}"; else svc="${red}停止${none}"; fi
        echo -e "  状态: $svc | 快捷指令: ${cyan}xrv${none}"
        echo -e "${blue}===================================================${none}"
        echo "  1) 核心安装 / 重构网络 (VLESS/SS 双协议)"
        echo "  2) 用户管理 (UUID 序号增删)"
        echo "  3) 分发中心 (详情与缩小版二维码)"
        echo "  4) 更新 Geo 规则库"
        echo "  5) 屏蔽规则管理 (BT/广告拦截)"
        echo -e "  ${cyan}6) 无感热切 SNI 矩阵 (带 CF 探测)${none}"
        echo "  8) 彻底卸载 (清空一切痕迹并自毁)"
        echo "  9) 运行状态 (服务/IP/流量统计)"
        echo "  0) 退出"
        hr
        read -rp "选择: " num
        case "$num" in
            1) do_install ;;
            2) do_user_manager ;;
            3) do_summary; read -rp "Enter 继续..." _ ;;
            4) print_magenta ">>> 正在更新规则库..."; bash -c "$(curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" @ install-geodata >/dev/null 2>&1; systemctl restart xray >/dev/null 2>&1; info "Geo 更新成功" ;;
            5) _global_block_rules ;;
            6) choose_sni && _safe_jq_write "(.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.serverNames) = ${L_B} \"$BEST_SNI\" ${R_B} | (.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.dest) = \"$BEST_SNI:443\"" && systemctl restart xray >/dev/null 2>&1 && do_summary && read -rp "Enter 继续..." _ ;;
            8) do_uninstall ;;
            9) do_status_menu ;;
            0) exit 0 ;;
        esac
    done
}

preflight
main_menu
