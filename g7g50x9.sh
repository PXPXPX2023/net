#!/usr/bin/env bash
# ============================================================
# 脚本名称: g7g50x9.sh (The Apex Vanguard V7 Edition)
# 快捷方式: xrv
# 巅峰突破: 
#   1. 彻底根治 status 23 权限拦截 Bug，采用 755/644 绝对权限防线穿透。
#   2. 修复交互逻辑死角：选择列表按 q 取消时，外层静默返回，杜绝冗余提示。
#   3. 商用流量计费中心完美汉化，支持按月精准回溯 30 天流量明细。
#   4. 纯净寡头节点库定稿，矩阵全量重组、十六进制防吞噬引擎全量融贯。
# ============================================================

# 必须用 bash 运行
if test -z "$BASH_VERSION"; then
    echo "错误: 请用 bash 运行此脚本: bash g7g50x9.sh"
    exit 1
fi

# -- 颜色定义 (采用 \033 彻底修复 \e 溢出乱码) --
red='\033[31m'; yellow='\033[33m'; gray='\033[90m'; green='\033[92m'
blue='\033[94m'; magenta='\033[95m'; cyan='\033[96m'; none='\033[0m'

# -- 终极防吞噬十六进制常量定义 --
L_B=$(printf '\x5B')
R_B=$(printf '\x5D')

# -- 全局路径与变量 --
XRAY_BIN="/usr/local/bin/xray"
CONFIG_DIR="/usr/local/etc/xray"
CONFIG="$CONFIG_DIR/config.json"
PUBKEY_FILE="$CONFIG_DIR/public.key"
SNI_CACHE_FILE="$CONFIG_DIR/sni_cache.txt"
INSTALL_DATE_FILE="$CONFIG_DIR/install_date.txt"
USER_SNI_MAP="$CONFIG_DIR/user_sni.txt"
USER_TIME_MAP="$CONFIG_DIR/user_time.txt"
DAT_DIR="/usr/local/share/xray"
SCRIPT_DIR="/usr/local/etc/xray-script"
UPDATE_DAT_SCRIPT="$SCRIPT_DIR/update-dat.sh"
SYMLINK="/usr/local/bin/xrv"
SCRIPT_PATH=$(readlink -f "$0")
SERVER_IP=""
REMARK_NAME="xp-reality"
BEST_SNI="www.microsoft.com"
SNI_JSON_ARRAY="\"www.microsoft.com\""
LISTEN_PORT=443

# 初始化环境
mkdir -p "$CONFIG_DIR" "$DAT_DIR" "$SCRIPT_DIR" 2>/dev/null
touch "$USER_SNI_MAP" "$USER_TIME_MAP"

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

# -- 环境预检 & 定时任务 --
preflight() {
    if test "$EUID" -ne 0; then die "此脚本必须以 root 身份运行"; fi
    if ! command -v systemctl >/dev/null 2>&1; then die "系统缺少 systemctl"; fi
    
    local need="jq curl wget xxd unzip qrencode vnstat cron openssl coreutils"
    local install_list=""
    for i in $need; do 
        if ! command -v "$i" >/dev/null 2>&1; then 
            install_list="$install_list $i"
        fi
    done

    if test -n "$install_list"; then
        info "正在同步工业级依赖: $install_list"
        (apt-get update -y || yum makecache -y) >/dev/null 2>&1
        (apt-get install -y $install_list || yum install -y $install_list) >/dev/null 2>&1
        systemctl start vnstat >/dev/null 2>&1 || true
        systemctl start cron >/dev/null 2>&1 || systemctl start crond >/dev/null 2>&1 || true
    fi

    if test -f "$SCRIPT_PATH"; then
        \cp -f "$SCRIPT_PATH" "$SYMLINK" >/dev/null 2>&1
        chmod +x "$SYMLINK" >/dev/null 2>&1
        hash -r 2>/dev/null
    fi
    
    SERVER_IP=$(curl -s -4 --connect-timeout 5 https://api.ipify.org || curl -s -4 --connect-timeout 5 https://ifconfig.me || echo "获取失败")
}

install_update_dat() {
    cat > "$UPDATE_DAT_SCRIPT" <<'UPDSH'
#!/usr/bin/env bash
XRAY_DAT_DIR="/usr/local/share/xray"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat"
curl -sL -o "$XRAY_DAT_DIR/geoip.dat.new" "$GEOIP_URL" && mv -f "$XRAY_DAT_DIR/geoip.dat.new" "$XRAY_DAT_DIR/geoip.dat"
curl -sL -o "$XRAY_DAT_DIR/geosite.dat.new" "$GEOSITE_URL" && mv -f "$XRAY_DAT_DIR/geosite.dat.new" "$XRAY_DAT_DIR/geosite.dat"
/bin/systemctl restart xray
UPDSH
    chmod +x "$UPDATE_DAT_SCRIPT"
    (crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT"; echo "0 3 * * * $UPDATE_DAT_SCRIPT >/dev/null 2>&1") | crontab -
    info "已配置自动热更: 每天凌晨 3:00 更新 Geo 规则库"
}

# -- 核心：130+ 实体 SNI 扫描引擎 (随机打乱 + 秒停机制 + 纯净列表) --
run_sni_scanner() {
    title "雷达嗅探：130+ 实体矩阵与国内连通性探测"
    print_yellow ">>> 扫描中... (随时按回车键可立即中止并挑选已扫描节点)\n"
    
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    
    local sni_list="www.apple.com support.apple.com developer.apple.com id.apple.com icloud.apple.com \
    swdist.apple.com swcdn.apple.com updates.cdn-apple.com mensura.cdn-apple.com osxapps.itunes.apple.com \
    aod.itunes.apple.com is1-ssl.mzstatic.com itunes.apple.com gateway.icloud.com www.icloud.com \
    www.microsoft.com login.microsoftonline.com portal.azure.com support.microsoft.com office.com \
    update.microsoft.com windowsupdate.microsoft.com software.download.prss.microsoft.com cdn-dynmedia-1.microsoft.com \
    www.intel.com downloadcenter.intel.com ark.intel.com www.amd.com drivers.amd.com community.amd.com \
    webinar.amd.com ir.amd.com www.dell.com support.dell.com www.hp.com support.hp.com developers.hp.com \
    www.bmw.com configure.bmw.com shop.bmw.com www.mercedes-benz.com me.mercedes-benz.com \
    www.toyota-global.com global.toyota www.toyota.com www.honda.com global.honda www.volkswagen.com \
    service.volkswagen.com www.vw.com www.nike.com account.nike.com store.nike.com www.adidas.com \
    account.adidas.com www.zara.com static.zara.net www.ikea.com secure.ikea.com www.shell.com \
    careers.shell.com www.bp.com login.bp.com www.totalenergies.com www.ge.com digital.ge.com \
    www.abb.com new.abb.com www.hsbc.com online.hsbc.com www.goldmansachs.com login.gs.com \
    www.morganstanley.com secure.morganstanley.com www.maersk.com www.msc.com www.cma-cgm.com \
    www.hapag-lloyd.com www.michelin.com www.bridgestone.com www.goodyear.com www.pirelli.com \
    www.sony.com www.sony.net www.panasonic.com www.canon.com www.nintendo.com www.lg.com \
    www.epson.com www.unilever.com www.loreal.com www.shiseido.com www.jnj.com www.kao.com \
    www.uniqlo.com www.hermes.com www.chanel.com services.chanel.com www.louisvuitton.com \
    eu.louisvuitton.com www.dior.com www.ferragamo.com www.versace.com www.prada.com www.fendi.com \
    www.gucci.com www.tiffany.com www.esteelauder.com www.maje.com www.swatch.com www.coca-cola.com \
    www.coca-colacompany.com www.pepsi.com www.pepsico.com www.nestle.com www.bk.com www.heinz.com \
    www.pg.com www.basf.com www.bayer.com www.bosch.com www.bosch-home.com www.lexus.com www.audi.com \
    www.porsche.com www.skoda-auto.com www.gm.com www.chevrolet.com www.cadillac.com www.ford.com \
    www.lincoln.com www.hyundai.com www.kia.com www.peugeot.com www.renault.com www.jaguar.com \
    www.landrover.com www.astonmartin.com www.mclaren.com www.ferrari.com www.maserati.com www.volvocars.com \
    www.tesla.com s0.awsstatic.com d1.awsstatic.com images-na.ssl-images-amazon.com m.media-amazon.com \
    www.nvidia.com academy.nvidia.com images.nvidia.com blogs.nvidia.com docs.nvidia.com docscontent.nvidia.com \
    www.samsung.com www.sap.com www.oracle.com www.mysql.com www.swift.com download-installer.cdn.mozilla.net \
    addons.mozilla.org www.airbnb.co.uk www.airbnb.ca www.airbnb.com.sg www.airbnb.com.au www.airbnb.co.in \
    www.ubi.com lol.secure.dyn.riotcdn.net one-piece.com player.live-video.net mit.edu www.mit.edu web.mit.edu \
    ocw.mit.edu csail.mit.edu libraries.mit.edu alum.mit.edu id.mit.edu stanford.edu www.stanford.edu \
    cs.stanford.edu ai.stanford.edu web.stanford.edu login.stanford.edu ox.ac.uk www.ox.ac.uk cs.ox.ac.uk \
    maths.ox.ac.uk login.ox.ac.uk lufthansa.com www.lufthansa.com book.lufthansa.com checkin.lufthansa.com \
    api.lufthansa.com singaporeair.com www.singaporeair.com booking.singaporeair.com krisflyer.singaporeair.com \
    trekbikes.com www.trekbikes.com shop.trekbikes.com support.trekbikes.com specialized.com www.specialized.com \
    store.specialized.com support.specialized.com giant-bicycles.com www.giant-bicycles.com dealer.giant-bicycles.com \
    logitech.com www.logitech.com support.logitech.com gaming.logitech.com razer.com www.razer.com \
    support.razer.com insider.razer.com corsair.com www.corsair.com support.corsair.com account.asus.com \
    kingston.com www.kingston.com shop.kingston.com support.kingston.com seagate.com www.seagate.com \
    support.seagate.com kleenex.com www.kleenex.com shop.kleenex.com scottbrand.com www.scottbrand.com \
    tempo-world.com www.tempo-world.com"

    if command -v shuf >/dev/null 2>&1; then
        sni_list=$(echo "$sni_list" | tr ' ' '\n' | shuf | tr '\n' ' ')
    else
        sni_list=$(echo "$sni_list" | tr ' ' '\n' | awk 'BEGIN{srand()} {print rand()"\t"$0}' | sort -n | cut -f2- | tr '\n' ' ')
    fi

    local tmp_sni="/tmp/sni_test.txt"
    rm -f "$tmp_sni"

    for sni in $sni_list; do
        read -t 0.1 -n 1 key
        if test $? -eq 0; then
            echo -e "\n${yellow}探测已手动中止，正在整理已捕获节点...${none}"
            break
        fi

        local time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni")
        local ms=$(echo "$time_raw" | awk '{print int($1 * 1000)}')

        if test "${ms:-0}" -gt 0; then
            if curl -sI -m 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray"; then
                echo -e " ${gray}忽略${none} $sni : ${yellow}${ms}ms${none} | ${gray}CF CDN拦截${none}"
                continue
            fi
            
            local doh_res=$(curl -s --connect-timeout 2 "https://dns.alidns.com/resolve?name=$sni&type=1" 2>/dev/null)
            local dns_cn=$(echo "$doh_res" | jq -r '.Answer[]? | select(.type==1 or .type==5) | .data' 2>/dev/null | tail -1)
            
            local status_cn=""
            local p_type="NORM"
            
            if test -z "$dns_cn" || test "$dns_cn" = "127.0.0.1" || test "$dns_cn" = "0.0.0.0" || test "$dns_cn" = "::1"; then
                status_cn="${red}国内墙阻断 (DNS投毒无法使用)${none}"
                p_type="BLOCK"
            else
                local loc=$(curl -s --connect-timeout 2 "https://ipinfo.io/$dns_cn/country" 2>/dev/null | tr -d ' \n')
                if test "$loc" = "CN"; then
                    status_cn="${green}国内直通${none} | ${blue}中国境内部署 CDN${none}"
                    p_type="CN_CDN"
                else
                    status_cn="${green}国内直通${none} | ${cyan}海外原生优质${none}"
                    p_type="NORM"
                fi
            fi
            
            echo -e " ${green}存活${none} $sni : ${yellow}${ms}ms${none} | $status_cn"
            
            if test "$p_type" != "BLOCK"; then
                echo "$ms $sni $p_type" >> "$tmp_sni"
            fi
        fi
    done

    if test -s "$tmp_sni"; then
        grep "NORM" "$tmp_sni" | sort -n | head -n 20 | awk '{print $2, $1}' > "$SNI_CACHE_FILE"
        local c=$(wc -l < "$SNI_CACHE_FILE" 2>/dev/null)
        if test "${c:-0}" -lt 20; then
            grep "CN_CDN" "$tmp_sni" | sort -n | head -n $((20 - ${c:-0})) | awk '{print $2, $1}' >> "$SNI_CACHE_FILE"
        fi
    else
        print_red "探测全灭，保底使用微软。"
        echo "www.microsoft.com 999" > "$SNI_CACHE_FILE"
    fi
    rm -f "$tmp_sni"
}

# -- 终极 Reality 质检 --
verify_sni_strict() {
    print_magenta "\n>>> 正在对 $1 开启严苛质检 (TLS 1.3 + ALPN h2 + OCSP)..."
    local out=$(echo "Q" | timeout 5 openssl s_client -connect "$1:443" -alpn h2 -tls1_3 -status 2>&1)
    local pass=1
    
    if ! echo "$out" | grep -qi "TLSv1.3"; then 
        print_red " ✗ 质检拦截: 目标不支持 TLS v1.3"
        pass=0
    fi
    if ! echo "$out" | grep -qi "ALPN, server accepted to use h2"; then 
        print_red " ✗ 质检拦截: 目标不支持 ALPN h2"
        pass=0
    fi
    if ! echo "$out" | grep -qi "OCSP response:"; then 
        print_red " ✗ 质检拦截: 目标未开启 OCSP Stapling 证书状态装订"
        pass=0
    fi
    
    return $pass
}

# -- 交互选单 (集成多选矩阵 + 彻底修复取消Bug) --
choose_sni() {
    while true; do
        if test -f "$SNI_CACHE_FILE"; then
            echo -e "\n  ${cyan}【战备缓存：极速 Top 20 (已剔除阻断节点)】${none}"
            local idx=1
            while read -r s t; do
                echo -e "  $idx) $s (${cyan}${t}ms${none})"
                idx=$((idx + 1))
            done < "$SNI_CACHE_FILE"
            
            echo -e "  ${yellow}r) 抛弃缓存重新扫描矩阵${none}"
            echo "  m) 矩阵模式 (多选组合/全选 SNI 以防封锁)"
            echo "  0) 手动输入自定义域名"
            echo "  q) 取消并返回"
            
            read -rp "  请选择: " sel
            sel=${sel:-1}
            
            # 【核心交互修复】：按 q 抛出 1 状态码，打断外层循环的后续弹窗
            if test "$sel" = "q"; then return 1; fi
            if test "$sel" = "r"; then run_sni_scanner; continue; fi
            
            if test "$sel" = "m"; then
                read -rp "请输入要组合的序号 (空格分隔, 如 1 3 5, 输入 all 全选): " m_sel
                if test "$m_sel" = "all"; then
                    local arr=($(awk '{print $1}' "$SNI_CACHE_FILE"))
                else
                    local arr=()
                    for i in $m_sel; do
                        local picked=$(awk "NR==$i {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null)
                        if test -n "$picked"; then arr+=("$picked"); fi
                    done
                fi
                
                if test ${#arr[@]} -eq 0; then
                    error "选择无效，请重新选择"
                    continue
                fi
                
                BEST_SNI="${arr[0]}"
                local jq_args=()
                for s in "${arr[@]}"; do jq_args+=("\"$s\""); done
                SNI_JSON_ARRAY=$(IFS=,; echo "${jq_args[*]}")
                
            elif test "$sel" = "0"; then 
                read -rp "输入自定义域名: " d
                BEST_SNI=${d:-www.microsoft.com}
                SNI_JSON_ARRAY="\"$BEST_SNI\""
            else
                local picked=$(awk "NR==$sel {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null)
                if test -n "$picked"; then
                    BEST_SNI="$picked"
                else
                    BEST_SNI=$(awk "NR==1 {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null)
                fi
                SNI_JSON_ARRAY="\"$BEST_SNI\""
            fi

            if verify_sni_strict "$BEST_SNI"; then
                print_green ">>> 主目标 $BEST_SNI 质检完美通过！"
                break
            else
                print_yellow ">>> 域名质检不达标，会导致 Reality 极易被墙或断流，请重新选择！"
                continue
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
    if test "${p:-0}" -ge 1 2>/dev/null && test "${p:-0}" -le 65535 2>/dev/null; then
        return 0
    fi
    return 1
}

# -- 绝对权限防线 (绝杀 status 23 Bug) --
fix_permissions() {
    # 强制修正：配置本体 644 (大家都能读)，目录 755 (大家都能通过)
    chmod 644 "$CONFIG" >/dev/null 2>&1
    chmod 755 "$CONFIG_DIR" >/dev/null 2>&1
    chown root:root "$CONFIG" >/dev/null 2>&1 || true
    chown -R root:root "$CONFIG_DIR" >/dev/null 2>&1 || true
}

# -- 安全写入配置 --
_safe_jq_write() {
    local filter="$1"
    local tmp=$(mktemp)
    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$CONFIG" >/dev/null 2>&1
        fix_permissions
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

# -- 用户管理 (包含创建时间与外部导入SNI配置) --
do_user_manager() {
    while true; do
        title "用户管理 (增删/导入 备注、UUID、ShortId)"
        if ! test -f "$CONFIG"; then error "未发现配置"; return; fi

        local clients=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .settings.clients${L_B}${R_B} | \"\\(.id)|\\(.email // \"无备注\")\"" "$CONFIG" 2>/dev/null)
        if test -z "$clients" || test "$clients" = "null"; then error "未发现 VLESS 节点"; return; fi

        local tmp_users="/tmp/xray_users.txt"
        echo "$clients" | awk -F'|' '{print NR"|"$1"|"$2}' > "$tmp_users"
        
        echo -e "当前用户列表："
        cat "$tmp_users" | while IFS='|' read -r num uid remark; do
            local utime=$(grep "^$uid|" "$USER_TIME_MAP" 2>/dev/null | cut -d'|' -f2)
            utime=${utime:-"未知时间"}
            echo -e "  $num) 备注: ${cyan}$remark${none} | 时间: ${gray}$utime${none} | UUID: ${yellow}$uid${none}"
        done
        hr
        
        echo "  a) 新增本网用户 (自动分配 UUID 与 ShortId)"
        echo "  m) 手动导入外部用户 (平滑迁移老用户的 UUID/ShortId)"
        echo "  s) 修改指定用户的专属 SNI 伪装域名"
        echo "  d) 序号删除用户"
        echo "  q) 退出"
        read -rp "指令: " uopt
        
        if test "$uopt" = "a"; then
            local nu=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || $XRAY_BIN uuid)
            local ns=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n')
            local ctime=$(date +"%Y-%m-%d %H:%M")
            
            read -rp "请输入新用户的专属节点备注 (直接回车默认: User-${ns}): " u_remark
            u_remark=${u_remark:-User-${ns}}
            
            _safe_jq_write "(.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .settings.clients) += ${L_B} {\"id\":\"$nu\",\"flow\":\"xtls-rprx-vision\",\"email\":\"$u_remark\"} ${R_B} | (.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.shortIds) += ${L_B} \"$ns\" ${R_B}"
            echo "$nu|$ctime" >> "$USER_TIME_MAP"
            systemctl restart xray
            
            local port=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .port" "$CONFIG" 2>/dev/null)
            local sni=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.serverNames${L_B}0${R_B}" "$CONFIG" 2>/dev/null)
            local pub=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.publicKey" "$CONFIG" 2>/dev/null)
            
            info "用户分配成功！该用户专属节点信息如下："
            local link="vless://${nu}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${ns}&type=tcp#${u_remark}"
            echo -e "\n  ${cyan}专属分发链接:${none} \n  $link\n"
            if command -v qrencode >/dev/null 2>&1; then 
                echo -e "  ${cyan}手机扫码导入:${none}"
                qrencode -m 2 -t UTF8 "$link"
            fi
            read -rp "按 Enter 继续..." _
            
        elif test "$uopt" = "m"; then
            hr
            echo -e " ${cyan}>>> 外部老用户平滑迁移向导 <<<${none}"
            echo -e " ${yellow}提示: 将外部用户的凭证挂载到本机，生成由本机 IP 和 pbk 构建的新链接！${none}"
            
            read -rp "请输入外部用户的备注 (例如: VIP-User): " m_remark
            m_remark=${m_remark:-ImportedUser}
            
            read -rp "请输入外部用户的 UUID: " m_uuid
            if test -z "$m_uuid"; then error "UUID 不能为空！"; continue; fi
            
            read -rp "请输入外部用户的 ShortId: " m_sid
            if test -z "$m_sid"; then error "ShortId 不能为空！"; continue; fi
            
            local ctime=$(date +"%Y-%m-%d %H:%M")
            _safe_jq_write "(.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .settings.clients) += ${L_B} {\"id\":\"$m_uuid\",\"flow\":\"xtls-rprx-vision\",\"email\":\"$m_remark\"} ${R_B} | (.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.shortIds) += ${L_B} \"$m_sid\" ${R_B}"
            echo "$m_uuid|$ctime" >> "$USER_TIME_MAP"
            
            read -rp "是否需要为该导入用户指定专属 SNI? (直接回车则使用全局默认, 若需要请填写域名): " m_sni
            if test -n "$m_sni"; then
                _safe_jq_write "(.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.serverNames) += ${L_B} \"$m_sni\" ${R_B} | (.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.serverNames) |= unique"
                sed -i "/^$m_uuid|/d" "$USER_SNI_MAP" 2>/dev/null
                echo "$m_uuid|$m_sni" >> "$USER_SNI_MAP"
                info "已为导入用户绑定专属 SNI: $m_sni"
            else
                m_sni=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.serverNames${L_B}0${R_B}" "$CONFIG" 2>/dev/null)
            fi
            
            systemctl restart xray
            
            local port=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .port" "$CONFIG" 2>/dev/null)
            local pub=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.publicKey" "$CONFIG" 2>/dev/null)
            
            info "外部用户导入成功！当前机器专属分发信息如下："
            local link="vless://${m_uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${m_sni}&fp=chrome&pbk=${pub}&sid=${m_sid}&type=tcp#${m_remark}"
            echo -e "\n  ${cyan}专属分发链接:${none} \n  $link\n"
            if command -v qrencode >/dev/null 2>&1; then 
                echo -e "  ${cyan}手机扫码导入:${none}"
                qrencode -m 2 -t UTF8 "$link"
            fi
            read -rp "按 Enter 继续..." _

        elif test "$uopt" = "s"; then
            read -rp "请输入要操作的序号: " snum
            local target_uuid=$(awk -F'|' -v id="${snum:-0}" '$1==id {print $2}' "$tmp_users")
            local target_remark=$(awk -F'|' -v id="${snum:-0}" '$1==id {print $3}' "$tmp_users")
            if test -n "$target_uuid"; then
                read -rp "请输入该用户的专属 SNI 域名: " u_sni
                if test -n "$u_sni"; then
                    _safe_jq_write "(.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.serverNames) += ${L_B} \"$u_sni\" ${R_B} | (.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.serverNames) |= unique"
                    sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null
                    echo "$target_uuid|$u_sni" >> "$USER_SNI_MAP"
                    systemctl restart xray
                    
                    info "已成功为该用户绑定专属 SNI: $u_sni"
                    local port=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .port" "$CONFIG" 2>/dev/null)
                    local sid=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.shortIds${L_B}$((snum-1))${R_B}" "$CONFIG" 2>/dev/null)
                    local pub=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.publicKey" "$CONFIG" 2>/dev/null)
                    
                    local link="vless://${target_uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${u_sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${target_remark}"
                    echo -e "\n  ${cyan}专属更新链接:${none} \n  $link\n"
                    if command -v qrencode >/dev/null 2>&1; then qrencode -m 2 -t UTF8 "$link"; fi
                    read -rp "按 Enter 继续..." _
                fi
            else
                error "序号无效。"
            fi
            
        elif test "$uopt" = "d"; then
            read -rp "请输入要删除的序号: " dnum
            local total=$(wc -l < "$tmp_users" 2>/dev/null)
            if test "${total:-0}" -le 1; then
                error "必须保留至少一个用户！"
            else
                local target_uuid=$(awk -F'|' -v id="${dnum:-0}" '$1==id {print $2}' "$tmp_users")
                if test -n "$target_uuid"; then
                    local idx=$((${dnum:-0}-1))
                    _safe_jq_write "(.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .settings.clients) |= map(select(.id != \"$target_uuid\")) | (.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.shortIds) |= del(.${L_B}${idx}${R_B})"
                    sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null
                    sed -i "/^$target_uuid|/d" "$USER_TIME_MAP" 2>/dev/null
                    systemctl restart xray; info "已成功剔除该用户及其凭证。"
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
        title "屏蔽规则管理 (BT/广告双轨分离拦截)"
        if ! test -f "$CONFIG"; then error "未发现配置"; return; fi
        
        local bt_en=$(jq -r ".routing.rules${L_B}${R_B} | select(.protocol | index(\"bittorrent\")) | ._enabled" "$CONFIG" 2>/dev/null | head -1)
        local ad_en=$(jq -r ".routing.rules${L_B}${R_B} | select(.domain | index(\"geosite:category-ads-all\")) | ._enabled" "$CONFIG" 2>/dev/null | head -1)
        
        echo -e "  1) BT/PT 协议拦截   当前状态: ${yellow}${bt_en}${none}"
        echo -e "  2) 全球广告拦截     当前状态: ${yellow}${ad_en}${none}"
        echo "  0) 返回"
        read -rp "选择: " bc
        case "$bc" in
            1) 
                local nv="true"; if test "$bt_en" = "true"; then nv="false"; fi
                _safe_jq_write "(.routing.rules${L_B}${R_B} | select(.protocol | index(\"bittorrent\")) | ._enabled) = $nv"
                systemctl restart xray; info "BT 屏蔽已切换为: $nv"
                ;;
            2) 
                local nv="true"; if test "$ad_en" = "true"; then nv="false"; fi
                _safe_jq_write "(.routing.rules${L_B}${R_B} | select(.domain | index(\"geosite:category-ads-all\")) | ._enabled) = $nv"
                systemctl restart xray; info "广告屏蔽已切换为: $nv"
                ;;
            0) return ;;
        esac
    done
}

# -- 分发中心 --
do_summary() {
    if ! test -f "$CONFIG"; then return; fi
    title "The Apex Vanguard 节点详情中心"
    
    local v_count=$(jq ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | length" "$CONFIG" 2>/dev/null || echo 0)
    if test "${v_count:-0}" -gt 0; then
        local uuid=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .settings.clients${L_B}0${R_B}.id" "$CONFIG" 2>/dev/null)
        local remark=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .settings.clients${L_B}0${R_B}.email // \"$REMARK_NAME\"" "$CONFIG" 2>/dev/null)
        local port=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .port" "$CONFIG" 2>/dev/null)
        local sid=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.shortIds${L_B}0${R_B}" "$CONFIG" 2>/dev/null)
        local pub=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.publicKey" "$CONFIG" 2>/dev/null)
        
        local target_sni=$(grep "^$uuid|" "$USER_SNI_MAP" 2>/dev/null | cut -d'|' -f2)
        target_sni=${target_sni:-$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.serverNames${L_B}0${R_B}" "$CONFIG" 2>/dev/null)}
        local all_snis=$(jq -r ".inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.serverNames | join(\", \")" "$CONFIG" 2>/dev/null)
        
        if test -n "$uuid" && test "$uuid" != "null"; then
            hr
            printf "  ${cyan}【VLESS-Reality (Vision)】${none}\n"
            printf "  ${yellow}%-16s${none} %s\n" "节点名称:" "$remark"
            printf "  ${yellow}%-16s${none} %s\n" "外网 IP:" "$SERVER_IP"
            printf "  ${yellow}%-16s${none} %s\n" "监听端口:" "$port"
            printf "  ${yellow}%-16s${none} %s\n" "当前主用 SNI:" "$target_sni"
            printf "  ${yellow}%-16s${none} %s\n" "全局容灾矩阵:" "$all_snis"
            printf "  ${yellow}%-16s${none} %s\n" "公钥(pbk):" "$pub"
            printf "  ${yellow}%-16s${none} %s\n" "Short ID:" "$sid"
            printf "  ${yellow}%-16s${none} %s\n" "主用 UUID:" "$uuid"
            
            local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${target_sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${remark}"
            echo -e "\n  ${cyan}通用链接:${none} \n  $link\n"
            if command -v qrencode >/dev/null 2>&1; then
                echo -e "  ${cyan}手机扫码导入 (半高紧凑版):${none}"
                qrencode -m 2 -t UTF8 "$link"
            fi
        fi
    fi

    local s_count=$(jq ".inbounds${L_B}${R_B} | select(.protocol==\"shadowsocks\") | length" "$CONFIG" 2>/dev/null || echo 0)
    if test "${s_count:-0}" -gt 0; then
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
                qrencode -m 2 -t UTF8 "$link_ss"
            fi
        fi
    fi
}

# -- 商用流量与运行状态 --
do_status_menu() {
    while true; do
        title "运行状态与计费中心"
        echo "  1) 服务进程守护状态"
        echo "  2) IP 与 监听网络信息"
        echo "  3) 网卡流量计费核算 (vnstat)"
        echo "  0) 返回主菜单"
        hr
        read -rp "选择: " s
        case "$s" in
            1) systemctl status xray --no-pager; read -rp "按 Enter 继续..." _ ;;
            2) 
                echo -e "\n  公网 IP: ${green}$SERVER_IP${none}"
                hr
                echo -e "  DNS 解析流向: "
                grep "^nameserver" /etc/resolv.conf | awk '{print "    " $0}'
                hr
                echo -e "  Xray 本地监听: "
                ss -tlnp | grep xray | awk '{print "    " $4}'
                read -rp "按 Enter 继续..." _ ;;
            3) 
                if ! command -v vnstat >/dev/null 2>&1; then 
                    warn "未安装 vnstat，无法统计流量。"
                    read -rp "Enter..." _ ; continue
                fi
                clear
                title "商用级网卡流量计费中心"
                local idate=$(cat "$INSTALL_DATE_FILE" 2>/dev/null || echo "未知")
                echo -e "  计费起算日期 (脚本初装日): ${cyan}$idate${none}"
                hr
                (vnstat -m 3 2>/dev/null || vnstat -m 2>/dev/null) | sed -e 's/estimated/估计流量/ig' -e 's/rx/接收/ig' -e 's/tx/发送/ig' -e 's/total/总计/ig' -e 's/daily/按天/ig' -e 's/monthly/按月/ig'
                hr
                echo "  1) 设置/修改 每月重置流量的计费日 (需重启vnstat)"
                echo "  2) 选择某个月，查看某个月按天流量情况"
                echo "  3) 精确调取 最近 3 个自然月的流量季报"
                echo "  q) 退出返回"
                read -rp "  指令: " vn_opt
                case "$vn_opt" in
                    1) 
                        read -rp "请输入新的每月账单清零日 (1-31): " d_day
                        if test "${d_day:-0}" -ge 1 2>/dev/null && test "${d_day:-0}" -le 31 2>/dev/null; then
                            sed -i "s/^MonthRotate .*/MonthRotate $d_day/" /etc/vnstat.conf 2>/dev/null
                            systemctl restart vnstat 2>/dev/null
                            info "流量结算日已重置为每月 $d_day 号 (稍后生效)。"
                        else
                            error "输入日期无效。"
                        fi
                        read -rp "Enter..." _ ;;
                    2)
                        read -rp "请输入要查询的年月 (例如 $(date +%Y-%m)，直接回车显示近30天): " d_month
                        if test -z "$d_month"; then
                            vnstat -d 2>/dev/null | sed -e 's/estimated/估计流量/ig' -e 's/rx/接收/ig' -e 's/tx/发送/ig' -e 's/total/总计/ig' -e 's/daily/按天/ig' -e 's/monthly/按月/ig'
                        else
                            vnstat -d 2>/dev/null | grep -iE "($d_month| day |estimated|--)" | sed -e 's/estimated/估计流量/ig' -e 's/rx/接收/ig' -e 's/tx/发送/ig' -e 's/total/总计/ig' -e 's/daily/按天/ig' -e 's/monthly/按月/ig'
                            if [ $? -ne 0 ]; then
                                echo -e "  ${yellow}未找到 $d_month 的按天数据，显示默认近期记录：${none}"
                                vnstat -d 2>/dev/null | sed -e 's/estimated/估计流量/ig' -e 's/rx/接收/ig' -e 's/tx/发送/ig' -e 's/total/总计/ig' -e 's/daily/按天/ig' -e 's/monthly/按月/ig'
                            fi
                        fi
                        read -rp "Enter..." _ ;;
                    3) 
                        (vnstat -m 3 2>/dev/null || vnstat -m) | sed -e 's/estimated/估计流量/ig' -e 's/rx/接收/ig' -e 's/tx/发送/ig' -e 's/total/总计/ig' -e 's/daily/按天/ig' -e 's/monthly/按月/ig'
                        read -rp "Enter..." _ ;;
                    q) ;;
                esac
                ;;
            0) return ;;
        esac
    done
}

# -- 核弹级自毁卸载 --
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
    rm -rf "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SCRIPT_DIR" >/dev/null 2>&1
    rm -rf /var/log/xray* >/dev/null 2>&1
    
    (crontab -l 2>/dev/null | grep -v "update-dat.sh") | crontab - 2>/dev/null
    
    rm -f "/usr/local/bin/xrv" >/dev/null 2>&1
    rm -f "$SCRIPT_PATH" >/dev/null 2>&1
    hash -r 2>/dev/null
    
    print_green "卸载完成！系统、快捷指令及脚本自身已被完全物理粉碎。"
    exit 0
}

# -- 安装主逻辑 --
do_install() {
    title "Apex Vanguard V7: 核心部署"
    preflight
    
    date +"%Y-%m-%d %H:%M:%S" > "$INSTALL_DATE_FILE"
    
    echo -e "  ${cyan}请选择要安装的代理协议：${none}"
    echo "  1) VLESS-Reality (推荐, 强力防封)"
    echo "  2) Shadowsocks (建议落地机使用)"
    echo "  3) 两个都安装 (双管齐下)"
    read -rp "  请输入编号: " proto_choice
    proto_choice=${proto_choice:-1}

    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        while true; do
            read -rp "请输入 VLESS 监听端口 (回车键默认443): " input_p
            input_p=${input_p:-443}
            if validate_port "$input_p"; then LISTEN_PORT="$input_p"; break; fi
            print_red "端口无效，请输入 1-65535 之间的纯数字。"
        done
        read -rp "请输入节点别名 (默认 xp-reality): " input_remark
        REMARK_NAME=${input_remark:-xp-reality}
        choose_sni || return 1
    fi

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
        if test "$proto_choice" = "2"; then
            read -rp "请输入节点别名 (默认 xp-reality): " input_remark
            REMARK_NAME=${input_remark:-xp-reality}
        fi
    fi

    print_magenta ">>> 正在静默拉取官方核心组件 (已屏蔽冗余日志)..."
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1
    
    install_update_dat

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
    sed "s/_L_/${L_B}/g; s/_R_/${R_B}/g" "$CONFIG.tmp" > "$CONFIG"
    rm -f "$CONFIG.tmp"

    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        local keys=$("$XRAY_BIN" x25519 2>/dev/null)
        local priv=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' ')
        local pub=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' ')
        local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || $XRAY_BIN uuid)
        local sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n')
        local ctime=$(date +"%Y-%m-%d %H:%M")
        
        echo "$pub" > "$PUBKEY_FILE"
        echo "$uuid|$ctime" > "$USER_TIME_MAP"
        
        local VLESS_INBOUND='{
            "tag": "vless-reality",
            "listen": "0.0.0.0",
            "port": '"$LISTEN_PORT"',
            "protocol": "vless",
            "settings": {
                "clients": _L_ { "id": "'"$uuid"'", "flow": "xtls-rprx-vision", "email": "'"$REMARK_NAME"'" } _R_,
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "dest": "'"$BEST_SNI"':443",
                    "serverNames": _L_ '"$SNI_JSON_ARRAY"' _R_,
                    "privateKey": "'"$priv"'",
                    "publicKey": "'"$pub"'",
                    "shortIds": _L_ "'"$sid"'" _R_
                }
            },
            "sniffing": { "enabled": true, "destOverride": _L_ "http", "tls", "quic" _R_ }
        }'
        VLESS_INBOUND=$(echo "$VLESS_INBOUND" | sed "s/_L_/${L_B}/g; s/_R_/${R_B}/g")
        _safe_jq_write ".inbounds += ${L_B} ${VLESS_INBOUND} ${R_B}"
    fi

    if test "$proto_choice" = "2" || test "$proto_choice" = "3"; then
        local SS_INBOUND='{
            "tag": "shadowsocks",
            "listen": "0.0.0.0",
            "port": '"$ss_port"',
            "protocol": "shadowsocks",
            "settings": {
                "method": "'"$ss_method"'",
                "password": "'"$ss_pass"'",
                "network": "tcp,udp"
            }
        }'
        SS_INBOUND=$(echo "$SS_INBOUND" | sed "s/_L_/${L_B}/g; s/_R_/${R_B}/g")
        _safe_jq_write ".inbounds += ${L_B} ${SS_INBOUND} ${R_B}"
    fi

    fix_permissions
    
    systemctl enable xray >/dev/null 2>&1
    systemctl restart xray >/dev/null 2>&1
    
    info "网络架构部署完成！"
    do_summary
    
    while true; do
        read -rp "按 Enter 返回主菜单，或输入 b 重选 SNI 矩阵: " opt
        if [[ "$opt" == "b" || "$opt" == "B" ]]; then
            choose_sni
            if test $? -eq 0; then
                _safe_jq_write "(.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.serverNames) = ${L_B} $SNI_JSON_ARRAY ${R_B} | (.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.dest) = \"$BEST_SNI:443\"" && systemctl restart xray >/dev/null 2>&1 && do_summary
            else
                break
            fi
        else
            break
        fi
    done
}

# -- 主菜单 --
main_menu() {
    while true; do
        clear
        echo -e "${blue}===================================================${none}"
        echo -e "  ${magenta}Xray G7G50x9 The Apex Vanguard V7 Edition${none}"
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        if test "$svc" = "active"; then svc="${green}运行中${none}"; else svc="${red}停止${none}"; fi
        echo -e "  状态: $svc | 快捷指令: ${cyan}xrv${none}"
        echo -e "${blue}===================================================${none}"
        echo "  1) 核心安装 / 重构网络 (VLESS/SS 双协议)"
        echo "  2) 用户管理 (增删/导入/专属 SNI 挂载)"
        echo "  3) 分发中心 (多用户详情与紧凑二维码)"
        echo "  4) 手动更新 Geo 规则库 (已夜间自动热更)"
        echo "  5) 屏蔽规则管理 (BT/广告双轨拦截)"
        echo -e "  ${cyan}6) 无感热切 SNI 矩阵 (单选/多选/全选防封阵列)${none}"
        echo "  8) 彻底卸载 (清空一切痕迹)"
        echo "  9) 运行状态 (IP/DNS/计费流量统计)"
        echo "  0) 退出"
        hr
        read -rp "选择: " num
        case "$num" in
            1) do_install ;;
            2) do_user_manager ;;
            3) 
               do_summary 
               while true; do
                   read -rp "按 Enter 返回，或输入 b 重新分配矩阵 SNI: " rb
                   if [[ "$rb" == "b" || "$rb" == "B" ]]; then
                       choose_sni
                       if test $? -eq 0; then
                           _safe_jq_write "(.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.serverNames) = ${L_B} $SNI_JSON_ARRAY ${R_B} | (.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.dest) = \"$BEST_SNI:443\"" && systemctl restart xray >/dev/null 2>&1 && do_summary
                       else
                           break
                       fi
                   else
                       break
                   fi
               done
               ;;
            4) print_magenta ">>> 正在同步最新规则库..."; bash -c "$(curl -fsSL https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" @ install-geodata >/dev/null 2>&1; systemctl restart xray >/dev/null 2>&1; info "Geo 更新成功" ;;
            5) _global_block_rules ;;
            6) 
               choose_sni
               if test $? -eq 0; then
                   _safe_jq_write "(.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.serverNames) = ${L_B} $SNI_JSON_ARRAY ${R_B} | (.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.dest) = \"$BEST_SNI:443\"" && systemctl restart xray >/dev/null 2>&1 && do_summary
                   while true; do
                       read -rp "按 Enter 返回主菜单，或输入 b 继续重新分配矩阵: " rb
                       if [[ "$rb" == "b" || "$rb" == "B" ]]; then
                           choose_sni
                           if test $? -eq 0; then
                               _safe_jq_write "(.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.serverNames) = ${L_B} $SNI_JSON_ARRAY ${R_B} | (.inbounds${L_B}${R_B} | select(.protocol==\"vless\") | .streamSettings.realitySettings.dest) = \"$BEST_SNI:443\"" && systemctl restart xray >/dev/null 2>&1 && do_summary
                           else
                               break
                           fi
                       else
                           break
                       fi
                   done
               fi
               ;;
            8) do_uninstall ;;
            9) do_status_menu ;;
            0) exit 0 ;;
        esac
    done
}

preflight
main_menu
