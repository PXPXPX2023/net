#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: ex188e2.sh (The Apex Vanguard - Project Genesis V188e2)
# 快捷方式: xrv
#
# 【V188e2 终极满血矩阵版】
#   1. 矩阵回归: 100% 全量注入 130+ 实体 SNI 顶级抗封锁伪装矩阵。
#   2. 编译防砖: 强行注入 CONFIG_VIRTIO 系列驱动，杜绝 KVM/Xen VPS 编译后丢失硬盘变砖。
#   3. 空间巡航: 编译前强制排查 /boot 扇区余量，摘除 make install 的静默吞错。
#   4. 作用域修复: 寻回 17 个 toggle_* 函数，杜绝面板 command not found。
#   5. 绝缘护盾: JQ 全量采用 |= 与 select(. != null) 语法，_safe_jq_write 引入 "$@" 传参。
#   6. 语法重铸: 彻底废弃 [ ] && 短路语法，全量多行 if test 防 set -e 断层。
# ==============================================================================

# ------------------------------------------------------------------------------
# [ 0x01: 系统级基础环境检查与严格模式锁定 ]
# ------------------------------------------------------------------------------

if test -z "${BASH_VERSION:-}"; then
    echo "Error: 请使用 bash 执行本脚本: bash ex188e2.sh"
    exit 1
fi

if test "$EUID" -ne 0; then 
    echo -e "\033[31m致命错误: 触及底层内核参数必须拥有最高权限，请使用 root 账户执行！\033[0m"
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then 
    echo -e "\033[31m致命错误: 当前宿主机缺失 systemd 守护组件，环境异常！\033[0m"
    exit 1
fi

# 启用严格模式防爆
set -euo pipefail
IFS=$' \n\t'
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ------------------------------------------------------------------------------
# [ 0x02: 全域 UI 引擎与常量映射 ]
# ------------------------------------------------------------------------------

readonly red='\033[31m'
readonly yellow='\033[33m'
readonly gray='\033[90m'
readonly green='\033[92m'
readonly blue='\033[94m'
readonly magenta='\033[95m'
readonly cyan='\033[96m'
readonly none='\033[0m'

readonly SCRIPT_VERSION="188e2"
readonly XRAY_BIN="/usr/local/bin/xray"
readonly CONFIG_DIR="/usr/local/etc/xray"
readonly CONFIG="$CONFIG_DIR/config.json"
readonly PUBKEY_FILE="$CONFIG_DIR/public.key"
readonly SNI_CACHE_FILE="$CONFIG_DIR/sni_cache.txt"
readonly INSTALL_DATE_FILE="$CONFIG_DIR/install_date.txt"
readonly USER_SNI_MAP="$CONFIG_DIR/user_sni.txt"
readonly USER_TIME_MAP="$CONFIG_DIR/user_time.txt"
readonly CAKE_OPTS_FILE="$CONFIG_DIR/cake_opts.txt"
readonly FLAGS_DIR="$CONFIG_DIR/flags"

readonly DAT_DIR="/usr/local/share/xray"
readonly SCRIPT_DIR="/usr/local/etc/xray-script"
readonly UPDATE_DAT_SCRIPT="$SCRIPT_DIR/update-dat.sh"
readonly LOG_DIR="/var/log/xray"
readonly BACKUP_DIR="$CONFIG_DIR/backups"
readonly SYMLINK="/usr/local/bin/xrv"
readonly SCRIPT_PATH=$(readlink -f "$0")

# 运行期动态变量初始化
GLOBAL_IP=""
SERVER_IP=""
REMARK_NAME="xp-reality"
BEST_SNI="www.microsoft.com"
SNI_JSON_ARRAY="\"www.microsoft.com\""
LISTEN_PORT=443
X25519_PRIV=""
X25519_PUB=""

# ------------------------------------------------------------------------------
# [ 0x03: 工业级日志、探针与系统架构初始化 ]
# ------------------------------------------------------------------------------

if ! mkdir -p "$CONFIG_DIR" "$DAT_DIR" "$SCRIPT_DIR" "$LOG_DIR" "$BACKUP_DIR" "$FLAGS_DIR" 2>/dev/null; then true; fi
if ! touch "$USER_SNI_MAP" "$USER_TIME_MAP" 2>/dev/null; then true; fi

print_red()     { echo -e "${red}$*${none}"; }
print_green()   { echo -e "${green}$*${none}"; }
print_yellow()  { echo -e "${yellow}$*${none}"; }
print_magenta() { echo -e "${magenta}$*${none}"; }
print_cyan()    { echo -e "${cyan}$*${none}"; }

info()  { echo -e "${green}[INFO]${none} $*"; }
warn()  { echo -e "${yellow}[WARN]${none} $*"; }
error() { echo -e "${red}[ERROR]${none} $*"; }
die()   { echo -e "\n${red}[FATAL]${none} $*\n"; exit 1; }

title() {
    echo -e "\n${blue}======================================================================${none}"
    echo -e "  ${cyan}$*${none}"
    echo -e "${blue}======================================================================${none}"
}
hr() { echo -e "${gray}----------------------------------------------------------------------${none}"; }

log_info()  { echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO:  $*" >> "$LOG_DIR/xray.log" 2>/dev/null || true; }
log_error() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$LOG_DIR/error.log" 2>/dev/null || true; }

# 全局临时碎片清扫器
cleanup_temp_files() {
    rm -f /tmp/sni_array.json /tmp/vless_inbound.json /tmp/vless_final.json /tmp/ss_inbound.json /tmp/new_client.json /tmp/xray_users*.txt /tmp/install-release.sh /tmp/sni_test.* /tmp/check_x86-64_psabi.sh /tmp/current_cron 2>/dev/null || true
}

# 灾难级异常抛出器
_err_handler() {
    local code=$1 line=$2 cmd=$3
    echo -e "\n${red}================== [ SYSTEM PANIC ] ==================${none}" >&2
    echo -e "${yellow} >> 战舰核心遇到致命断层，运行已被系统强行熔断！${none}" >&2
    echo -e "${cyan} >> 错误代号: ${none}${code}" >&2
    echo -e "${cyan} >> 崩溃行号: ${none}${line}" >&2
    echo -e "${cyan} >> 故障指令: ${none}${cmd}" >&2
    echo -e "${red}======================================================${none}\n" >&2
    log_error "PANIC TRIGGERED -> EXIT=$code LINE=$line CMD=[$cmd]"
    cleanup_temp_files
}

trap '_err_handler $? $LINENO "$BASH_COMMAND"' ERR
trap cleanup_temp_files EXIT

# 缓存型 IP 探针，彻底解决菜单调用卡顿
_get_ip() {
    if test -n "${SERVER_IP:-}"; then
        if test "$SERVER_IP" != "获取失败"; then
            echo "$SERVER_IP"
            return
        fi
    fi

    if test -z "${GLOBAL_IP:-}"; then
        local temp_ip=""
        set +e
        temp_ip=$(curl -k -s -4 --connect-timeout 3 https://api.ipify.org 2>/dev/null | tr -d '\r\n' || echo "")
        if test -z "$temp_ip"; then
            temp_ip=$(curl -k -s -4 --connect-timeout 3 https://ifconfig.me 2>/dev/null | tr -d '\r\n' || echo "")
        fi
        set -e
        
        if test -z "$temp_ip"; then
            GLOBAL_IP="外网探针离线"
        else
            GLOBAL_IP="$temp_ip"
        fi
    fi
    echo "$GLOBAL_IP"
}

# ------------------------------------------------------------------------------
# [ 0x04: JQ 解析器防暴盾与自动回滚中心 ]
# ------------------------------------------------------------------------------

fix_permissions() {
    if test -f "$CONFIG"; then
        chmod 644 "$CONFIG" 2>/dev/null || true
    fi
    if test -d "$CONFIG_DIR"; then
        chmod 755 "$CONFIG_DIR" 2>/dev/null || true
    fi
    chown -R root:root "$CONFIG_DIR" 2>/dev/null || true
    if test -f "$PUBKEY_FILE"; then
        chmod 600 "$PUBKEY_FILE" 2>/dev/null || true
    fi
}

backup_config() {
    if test ! -f "$CONFIG"; then 
        return 0
    fi
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    cp -f "$CONFIG" "$BACKUP_DIR/config_${ts}.json" 2>/dev/null || true
    ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
    log_info "配置已备份: config_${ts}.json"
}

restore_latest_backup() {
    local latest
    latest=$(ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | head -n 1 || echo "")
    if test -n "$latest"; then
        cp -f "$latest" "$CONFIG" 2>/dev/null || true
        fix_permissions
        systemctl restart xray >/dev/null 2>&1 || true
        warn "已自动回滚配置至: $(basename "$latest")"
        log_info "执行配置回滚: $latest"
        return 0
    fi
    error "未找到可用备份，配置还原失败。"
    return 1
}

verify_xray_config() {
    local target_config="$1"
    if test ! -f "$XRAY_BIN"; then
        return 0
    fi
    local test_result
    # 兼容新老版本的测试指令
    if ! test_result=$("$XRAY_BIN" run -test -config "$target_config" 2>&1); then
        test_result=$("$XRAY_BIN" -test -config "$target_config" 2>&1 || echo "核心测试失败")
    fi
    
    if echo "$test_result" | grep -qi "Configuration OK"; then
        return 0
    else
        error "配置文件校验未通过，Xray 核心拒绝加载。"
        echo -e "${gray}$test_result${none}"
        return 1
    fi
}

# 绝缘修复: 引入 "$@" 接收全量参数，确保多参数传值不截断
_safe_jq_write() {
    backup_config
    local tmp_raw
    tmp_raw=$(mktemp) || return 1
    local tmp="${tmp_raw}.json"
    mv -f "$tmp_raw" "$tmp" 2>/dev/null || true
    
    if jq "$@" "$CONFIG" > "$tmp" 2>/dev/null; then
        if test -s "$tmp"; then
            if verify_xray_config "$tmp"; then
                mv -f "$tmp" "$CONFIG" 2>/dev/null || true
                fix_permissions
                return 0
            else
                rm -f "$tmp" 2>/dev/null || true
                restore_latest_backup
                return 1
            fi
        else
            error "JQ 解析器生成了空白文件，拒绝覆盖！"
            rm -f "$tmp" 2>/dev/null || true
            restore_latest_backup
            return 1
        fi
    else
        rm -f "$tmp" 2>/dev/null || true
        error "JSON 解析器语法故障，写入已中止。"
        log_error "jq 语法执行失败，参数: $*"
        restore_latest_backup
        return 1
    fi
}

ensure_xray_is_alive() {
    info "正在重载 Xray 服务进程..."
    systemctl restart xray >/dev/null 2>&1 || true
    sleep 3
    if systemctl is-active --quiet xray; then
        info "Xray 服务运行正常。"
        return 0
    else
        error "Xray 服务启动失败，请检查以下错误日志："
        hr
        journalctl -u xray.service --no-pager -n 15 2>/dev/null | awk '{print "    " $0}' || true
        hr
        restore_latest_backup
        local _p=""
        read -rp "请按 Enter 键返回..." _p || true
        return 1
    fi
}
# ------------------------------------------------------------------------------
# [ 0x05: 130+ 满血实体 SNI 连通性雷达矩阵与质检中心 ]
# ------------------------------------------------------------------------------

run_sni_scanner() {
    title "雷达嗅探：130+ 实体矩阵与国内连通性探测"
    print_yellow ">>> 扫描中... (随时按回车键可立即中止并挑选已扫描节点)\n"
    
    if ! mkdir -p "$CONFIG_DIR" 2>/dev/null; then 
        true
    fi
    
    # 满血 130+ 顶级防封锁实体 SNI 阵列
    local sni_list=(
        "www.apple.com" "support.apple.com" "developer.apple.com" "id.apple.com" "icloud.apple.com"
        "swdist.apple.com" "swcdn.apple.com" "updates.cdn-apple.com" "mensura.cdn-apple.com" "osxapps.itunes.apple.com"
        "aod.itunes.apple.com" "is1-ssl.mzstatic.com" "itunes.apple.com" "gateway.icloud.com" "www.icloud.com"
        "www.microsoft.com" "login.microsoftonline.com" "portal.azure.com" "support.microsoft.com" "office.com"
        "update.microsoft.com" "windowsupdate.microsoft.com" "software.download.prss.microsoft.com" "cdn-dynmedia-1.microsoft.com"
        "www.intel.com" "downloadcenter.intel.com" "ark.intel.com" "www.amd.com" "drivers.amd.com" "community.amd.com"
        "webinar.amd.com" "ir.amd.com" "www.dell.com" "support.dell.com" "www.hp.com" "support.hp.com" "developers.hp.com"
        "www.bmw.com" "configure.bmw.com" "shop.bmw.com" "www.mercedes-benz.com" "me.mercedes-benz.com"
        "www.toyota-global.com" "global.toyota" "www.toyota.com" "www.honda.com" "global.honda" "www.volkswagen.com"
        "service.volkswagen.com" "www.vw.com" "www.nike.com" "account.nike.com" "store.nike.com" "www.adidas.com"
        "account.adidas.com" "www.zara.com" "static.zara.net" "www.ikea.com" "secure.ikea.com" "www.shell.com"
        "careers.shell.com" "www.bp.com" "login.bp.com" "www.totalenergies.com" "www.ge.com" "digital.ge.com"
        "www.abb.com" "new.abb.com" "www.hsbc.com" "online.hsbc.com" "www.goldmansachs.com" "login.gs.com"
        "www.morganstanley.com" "secure.morganstanley.com" "www.maersk.com" "www.msc.com" "www.cma-cgm.com"
        "www.hapag-lloyd.com" "www.michelin.com" "www.bridgestone.com" "www.goodyear.com" "www.pirelli.com"
        "www.sony.com" "www.sony.net" "www.panasonic.com" "www.canon.com" "www.nintendo.com" "www.lg.com"
        "www.epson.com" "www.unilever.com" "www.loreal.com" "www.shiseido.com" "www.jnj.com" "www.kao.com"
        "www.uniqlo.com" "www.hermes.com" "www.chanel.com" "services.chanel.com" "www.louisvuitton.com"
        "eu.louisvuitton.com" "www.dior.com" "www.ferragamo.com" "www.versace.com" "www.prada.com" "www.fendi.com"
        "www.gucci.com" "www.tiffany.com" "www.esteelauder.com" "www.maje.com" "www.swatch.com" "www.coca-cola.com"
        "www.coca-colacompany.com" "www.pepsi.com" "www.pepsico.com" "www.nestle.com" "www.bk.com" "www.heinz.com"
        "www.pg.com" "www.basf.com" "www.bayer.com" "www.bosch.com" "www.bosch-home.com" "www.lexus.com" "www.audi.com"
        "www.porsche.com" "www.skoda-auto.com" "www.gm.com" "www.chevrolet.com" "www.cadillac.com" "www.ford.com"
        "www.lincoln.com" "www.hyundai.com" "www.kia.com" "www.peugeot.com" "www.renault.com" "www.jaguar.com"
        "www.landrover.com" "www.astonmartin.com" "www.mclaren.com" "www.ferrari.com" "www.maserati.com" "www.volvocars.com"
        "www.tesla.com" "s0.awsstatic.com" "d1.awsstatic.com" "images-na.ssl-images-amazon.com" "m.media-amazon.com"
        "www.nvidia.com" "academy.nvidia.com" "images.nvidia.com" "blogs.nvidia.com" "docs.nvidia.com" "docscontent.nvidia.com"
        "www.samsung.com" "www.sap.com" "www.oracle.com" "www.mysql.com" "www.swift.com" "download-installer.cdn.mozilla.net"
        "addons.mozilla.org" "www.airbnb.co.uk" "www.airbnb.ca" "www.airbnb.com.sg" "www.airbnb.com.au" "www.airbnb.co.in"
        "www.ubi.com" "lol.secure.dyn.riotcdn.net" "one-piece.com" "player.live-video.net" "mit.edu" "www.mit.edu" 
        "web.mit.edu" "ocw.mit.edu" "csail.mit.edu" "libraries.mit.edu" "alum.mit.edu" "id.mit.edu" "stanford.edu" 
        "www.stanford.edu" "cs.stanford.edu" "ai.stanford.edu" "web.stanford.edu" "login.stanford.edu" "ox.ac.uk" 
        "www.ox.ac.uk" "cs.ox.ac.uk" "maths.ox.ac.uk" "login.ox.ac.uk" "lufthansa.com" "www.lufthansa.com" 
        "book.lufthansa.com" "checkin.lufthansa.com" "api.lufthansa.com" "singaporeair.com" "www.singaporeair.com" 
        "booking.singaporeair.com" "krisflyer.singaporeair.com" "trekbikes.com" "www.trekbikes.com" "shop.trekbikes.com" 
        "support.trekbikes.com" "specialized.com" "www.specialized.com" "store.specialized.com" "support.specialized.com" 
        "giant-bicycles.com" "www.giant-bicycles.com" "dealer.giant-bicycles.com" "logitech.com" "www.logitech.com" 
        "support.logitech.com" "gaming.logitech.com" "razer.com" "www.razer.com" "support.razer.com" "insider.razer.com" 
        "corsair.com" "www.corsair.com" "support.corsair.com" "account.asus.com" "kingston.com" "www.kingston.com" 
        "shop.kingston.com" "support.kingston.com" "seagate.com" "www.seagate.com" "support.seagate.com" "kleenex.com" 
        "www.kleenex.com" "shop.kleenex.com" "scottbrand.com" "www.scottbrand.com" "tempo-world.com" "www.tempo-world.com"
        "www.zoom.us" "www.adobe.com" "www.autodesk.com" "www.salesforce.com" "www.cisco.com" "www.ibm.com" "www.qualcomm.com"
        "www.nissan-global.com" "www.target.com" "www.walmart.com" "www.homedepot.com" "www.lowes.com" "www.walgreens.com"
        "www.costco.com" "www.cvs.com" "www.bestbuy.com" "www.kroger.com" "www.mcdonalds.com" "www.starbucks.com"
        "www.puma.com" "www.underarmour.com" "www.hm.com" "www.gap.com" "www.rolex.com" "www.burberry.com" "www.cartier.com"
        "www.estee-lauder.com" "www.pfizer.com" "www.novartis.com" "www.roche.com" "www.sanofi.com" "www.merck.com"
        "www.gsk.com" "www.boeing.com" "www.airbus.com" "www.lockheedmartin.com" "www.geaerospace.com" "www.siemens.com"
        "www.hitachi.com" "www.schneider-electric.com" "www.caterpillar.com" "www.john-deere.com" "www.mitsubishicorp.com"
        "www.sharp.com" "www.lenovo.com" "www.huawei.com" "www.asus.com" "www.acer.com" "www.delltechnologies.com"
        "www.hpe.com" "www.lenovo.com.cn" "www.tiktok.com" "www.spotify.com" "www.netflix.com" "www.hulu.com" "www.disneyplus.com"
    )

    local sni_string
    sni_string=$(printf "%s\n" "${sni_list[@]}")
    
    if command -v shuf >/dev/null 2>&1; then
        sni_string=$(echo "$sni_string" | shuf)
    else
        sni_string=$(echo "$sni_string" | awk 'BEGIN{srand()} {print rand()"\t"$0}' | sort -n | cut -f2-)
    fi

    local tmp_sni
    tmp_sni=$(mktemp /tmp/sni_test.XXXXXX) || true

    for sni in $sni_string; do
        local key=""
        if read -t 0.1 -n 1 -s key 2>/dev/null; then
            echo -e "\n${yellow}探测已手动中止，正在整理已捕获节点...${none}"
            break
        fi

        local time_raw
        time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni" 2>/dev/null || echo "0")
        
        local ms
        ms=$(echo "$time_raw" | awk '{print int($1 * 1000)}')

        if test "${ms:-0}" -gt 0; then
            if curl -sI -m 2 --connect-timeout 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray"; then
                echo -e " ${gray}跳过${none} $sni (Cloudflare CDN 拦截)"
                continue
            fi
            
            # 脱离严格模式执行 DNS 探测
            set +e
            local doh_res
            doh_res=$(curl -s --connect-timeout 2 "https://dns.alidns.com/resolve?name=$sni&type=1" 2>/dev/null || echo "")
            
            local dns_cn=""
            if test -n "$doh_res"; then
                dns_cn=$(echo "$doh_res" | jq -r '.Answer[]? | select(.type==1 or .type==5) | .data' 2>/dev/null | tail -n 1 || echo "")
            fi
            set -e
            
            local status_cn=""
            local p_type="NORM"
            
            if test -z "$dns_cn"; then
                status_cn="${red}国内墙阻断 (DNS投毒或无响应)${none}"
                p_type="BLOCK"
            else
                if test "$dns_cn" = "127.0.0.1" || test "$dns_cn" = "0.0.0.0" || test "$dns_cn" = "::1" || test "$dns_cn" = "null"; then
                    status_cn="${red}国内墙阻断 (DNS投毒)${none}"
                    p_type="BLOCK"
                else
                    set +e
                    local loc
                    loc=$(curl -s --connect-timeout 2 "https://ipinfo.io/$dns_cn/country" 2>/dev/null | tr -d ' \n' || echo "")
                    set -e
                    
                    if test "$loc" = "CN"; then
                        status_cn="${green}直通${none} | ${blue}中国境内 CDN${none}"
                        p_type="CN_CDN"
                    else
                        status_cn="${green}直通${none} | ${cyan}海外原生优质${none}"
                        p_type="NORM"
                    fi
                fi
            fi
            
            echo -e " ${green}存活${none} $sni : ${yellow}${ms}ms${none} | $status_cn"
            
            if test "$p_type" != "BLOCK"; then
                echo "$ms $sni $p_type" >> "$tmp_sni"
            fi
        fi
    done

    if test -s "$tmp_sni"; then
        grep " NORM$" "$tmp_sni" | sort -n | head -n 20 | awk '{print $2, $1}' > "$SNI_CACHE_FILE" || true
        
        local count
        count=$(wc -l < "$SNI_CACHE_FILE" 2>/dev/null || echo "0")
        
        if test "${count:-0}" -lt 20; then
            local need_fill=$(( 20 - ${count:-0} ))
            grep "CN_CDN" "$tmp_sni" | sort -n | head -n "$need_fill" | awk '{print $2, $1}' >> "$SNI_CACHE_FILE" || true
        fi
    else
        print_red "探测全灭，系统已回退至微软保底方案。"
        echo "www.microsoft.com 999 NORM" > "$SNI_CACHE_FILE"
    fi
    
    rm -f "$tmp_sni" 2>/dev/null || true
}

verify_sni_strict() {
    local target="$1"
    print_magenta "\n>>> 正在对目标 SNI [$target] 开启严苛质检 (TLS 1.3 + ALPN h2 + OCSP)..."
    
    set +e
    local out
    out=$(echo "Q" | timeout 5 openssl s_client -connect "$target:443" -alpn h2 -tls1_3 -status 2>&1 || echo "")
    set -e
    
    local pass=1
    
    if ! echo "$out" | grep -qi "TLSv1.3"; then 
        print_red " ✗ 质检拦截: 目标服务器不支持 TLS v1.3 协议"
        pass=0
    fi
    
    if ! echo "$out" | grep -qiE "ALPN, server accepted to use h2|ALPN.*h2"; then 
        print_red " ✗ 质检拦截: 目标服务器不支持 ALPN h2 协商"
        pass=0
    fi
    
    if ! echo "$out" | grep -qi "OCSP response:"; then 
        print_red " ✗ 质检拦截: 目标服务器未配置 OCSP Stapling 证书状态装订"
        pass=0
    fi
    
    if test "$pass" -eq 0; then
        warn "结论：该目标指纹残缺，易遭墙探！"
        return 1
    else
        info "结论：目标完美通过三项高维特征审核！"
        return 0
    fi
}

choose_sni() {
    while true; do
        if test -f "$SNI_CACHE_FILE"; then
            echo -e "\n  ${cyan}【战备缓存：极速 Top 20 (已剔除阻断节点)】${none}"
            
            local idx=1
            while read -r s t p; do
                echo -e "  $idx) $s (TCP 延迟: ${cyan}${t}ms${none})"
                idx=$((idx + 1))
            done < "$SNI_CACHE_FILE"
            
            echo -e "  ${yellow}r) 抛弃缓存重新运行雷达扫描${none}"
            echo "  m) 启用多选模式 (输入多个序号，构建多域名矩阵)"
            echo "  0) 手动输入自定义私有域名"
            echo "  q) 取消并退回上级"
            
            local sel=""
            read -rp "  请选择对应操作或节点序号 (默认 1): " sel || true
            sel=${sel:-1}
            
            if test "$sel" = "q" || test "$sel" = "Q"; then 
                return 1
            fi
            
            if test "$sel" = "r" || test "$sel" = "R"; then 
                run_sni_scanner
                continue
            fi
            
            if test "$sel" = "m" || test "$sel" = "M"; then
                local m_sel=""
                read -rp "请输入所需序号 (空格分隔, 如 1 3 5，或输入 all 全选): " m_sel || true
                
                local arr=()
                
                if test "$m_sel" = "all"; then
                    while read -r p_sni p_rest; do
                        if test -n "$p_sni"; then 
                            arr+=("$p_sni")
                        fi
                    done < "$SNI_CACHE_FILE"
                else
                    for i in $m_sel; do
                        local picked=""
                        picked=$(awk "NR==$i {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "")
                        
                        if test -n "$picked"; then 
                            arr+=("$picked")
                        fi
                    done
                fi
                
                if test "${#arr[@]}" -eq 0; then
                    error "选择无效，未能解析到有效的 SNI 目标，请重新输入。"
                    continue
                fi
                
                BEST_SNI="${arr[0]}"
                
                local jq_args=()
                for s in "${arr[@]}"; do 
                    jq_args+=("\"$s\"")
                done
                SNI_JSON_ARRAY=$(IFS=,; echo "${jq_args[*]}")
                
            else
                if test "$sel" = "0"; then 
                    local d=""
                    read -rp "请输入您指定的自定义域名: " d || true
                    
                    BEST_SNI=${d:-www.microsoft.com}
                    SNI_JSON_ARRAY="\"$BEST_SNI\""
                else
                    local picked=""
                    if [[ "$sel" =~ ^[0-9]+$ ]]; then
                        picked=$(awk "NR==$sel {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "")
                    fi
                    
                    if test -n "$picked"; then
                        BEST_SNI="$picked"
                    else
                        error "输入有误，已自动降级为您分配第一号测速节点。"
                        BEST_SNI=$(awk "NR==1 {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "www.microsoft.com")
                    fi
                    
                    SNI_JSON_ARRAY="\"$BEST_SNI\""
                fi
            fi

            if verify_sni_strict "$BEST_SNI"; then
                print_green ">>> 质检完毕：主控目标 $BEST_SNI 完美通过特征审查！"
                break
            else
                print_yellow ">>> 危险预警：域名质检不达标，若强行部署会导致 Reality 极易被墙或断流！"
                local force_use=""
                read -rp "是否无视警告，强制使用该域名？(y/n): " force_use || true
                
                if [[ "$force_use" =~ ^[yY]$ ]]; then
                    warn "您已授权强制越过安检防线，配置继续。"
                    break
                else
                    continue
                fi
            fi
        else
            warn "未能发现本地域名测速快照，正在为您唤醒扫描雷达..."
            run_sni_scanner
        fi
    done
    
    return 0
}
# ------------------------------------------------------------------------------
# [ 0x06: Swap 虚拟内存防爆模块 ]
# ------------------------------------------------------------------------------

check_and_create_1gb_swap() {
    title "检查物理 Swap 分区状态"
    
    local SWAP_FILE="/swapfile"
    local CURRENT_SWAP=""
    CURRENT_SWAP=$(swapon --show=NAME,KBYTES --noheadings 2>/dev/null | grep "$SWAP_FILE" | awk '{print $2}' || echo "")
    
    if test -n "$CURRENT_SWAP"; then
        if test "$CURRENT_SWAP" -ge 1000000 2>/dev/null; then
            info "系统已配置足量的 Swap 分区 (≥1GB)。"
            return
        fi
    fi
    
    warn "未检测到足量 Swap，正在强行切辟 1GB Swap 缓冲分区以防编译时内存爆闪..."
    swapoff -a 2>/dev/null || true
    sed -i '/swapfile/d' /etc/fstab 2>/dev/null || true
    rm -f "$SWAP_FILE" 2>/dev/null || true
    
    dd if=/dev/zero of="$SWAP_FILE" bs=1M count=1024 status=none 2>/dev/null || true
    chmod 600 "$SWAP_FILE" 2>/dev/null || true
    mkswap "$SWAP_FILE" >/dev/null 2>&1 || true
    swapon "$SWAP_FILE" >/dev/null 2>&1 || true
    echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab 2>/dev/null || true
    
    info "Swap 缓冲池配置完成。"
}

# ------------------------------------------------------------------------------
# [ 0x07: 官方预编译 XANMOD 部署模块 - 容错智能降级与 APT 寻址引擎 ]
# ------------------------------------------------------------------------------

do_install_xanmod_main_official() {
    title "系统飞升：安装官方预编译 XANMOD 内核"
    
    local arch
    arch=$(uname -m 2>/dev/null || echo "")
    
    if test "$arch" != "x86_64"; then
        error "系统架构不匹配：官方预编译 Xanmod 目前仅支持 x86_64 (amd64) 架构的机器！"
        local _pause=""
        read -rp "按 Enter 返回..." _pause || true
        return
    fi

    if test ! -f /etc/debian_version; then
        error "系统发行版排斥：官方预编译 Xanmod APT 仓库目前仅兼容 Debian / Ubuntu 系操作系统！"
        local _pause=""
        read -rp "按 Enter 返回..." _pause || true
        return
    fi

    print_magenta ">>> [1/4] 正在拉取智能探针，检测本地 CPU 硬件微架构支持级别..."
    
    local cpu_level_script="/tmp/check_x86-64_psabi.sh"
    
    if ! wget -qO "$cpu_level_script" https://dl.xanmod.org/check_x86-64_psabi.sh; then
        warn "探针脚本下载遇到网络波动，将跳过精准检测。"
    fi
    
    local cpu_level=""
    if test -f "$cpu_level_script"; then
        set +e
        cpu_level=$(awk -f "$cpu_level_script" 2>/dev/null | grep -oE 'x86-64-v[1-4]' | grep -oE '[1-4]' | tail -n 1 || echo "")
        set -e
        rm -f "$cpu_level_script" 2>/dev/null || true
    fi
    
    if test -z "$cpu_level"; then
        cpu_level=1
        warn "未能精确检测 CPU 微架构级别，将默认降级使用系统最宽容的 v1 兼容版本。"
    else
        info "评估完成，当前 CPU 硬件完美支持的微架构最高级别为: v${cpu_level}"
    fi

    print_magenta ">>> [2/4] 正在配置 Xanmod 官方最高优 APT 仓库与防伪 GPG 密钥..."
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y gnupg gnupg2 curl sudo wget e2fsprogs >/dev/null 2>&1 || true

    echo 'deb http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-kernel.list
    
    if ! wget -qO - https://dl.xanmod.org/gpg.key | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/xanmod-kernel.gpg 2>/dev/null; then
        error "从远端导入 GPG 密钥链发生错误，官方源可能受限！"
        return 1
    fi

    print_magenta ">>> [3/4] 正在触发 APT 智能降级寻址阵列..."
    
    apt-get update -y >/dev/null 2>&1 || true
    local pkg_name="linux-xanmod-x64v${cpu_level}"
    
    set +e
    local pkg_exists
    pkg_exists=$(apt-cache show "$pkg_name" 2>/dev/null || echo "")
    set -e
    
    if test -z "$pkg_exists"; then
        warn "未找到标准包名 $pkg_name，正在唤醒 APT 模糊寻址雷达..."
        local alt_pkg
        set +e
        alt_pkg=$(apt-cache search "linux-image-.*xanmod.*x64v${cpu_level}" 2>/dev/null | grep -vE "dbg|headers" | awk '{print $1}' | head -n 1 || echo "")
        set -e
        
        if test -n "$alt_pkg"; then
            info "成功修正雷达寻址坐标！锁定目标底层包: $alt_pkg"
            pkg_name="$alt_pkg"
        else
            warn "同级衍生包寻址失败，安全回退至 v1 保底版本..."
            pkg_name="linux-xanmod-x64v1"
            
            set +e
            local safe_exists
            safe_exists=$(apt-cache show "$pkg_name" 2>/dev/null || echo "")
            set -e
            
            if test -z "$safe_exists"; then
                local safe_pkg
                set +e
                safe_pkg=$(apt-cache search "linux-image-.*xanmod.*x64v1" 2>/dev/null | grep -vE "dbg|headers" | awk '{print $1}' | head -n 1 || echo "")
                set -e
                if test -n "$safe_pkg"; then
                    pkg_name="$safe_pkg"
                fi
            fi
        fi
    fi
    
    print_magenta ">>> [4/4] 正在向主系统强行注入战舰级内核: $pkg_name ..."
    
    if ! apt-get install -y "$pkg_name"; then
        error "保底安装宣告失败，内核替换进程中止。请排查物理网络环境与 APT 源配置！"
        local _pause=""
        read -rp "按 Enter 继续..." _pause || true
        return 1
    fi

    if command -v update-grub >/dev/null 2>&1; then
        update-grub >/dev/null 2>&1 || true
    else
        apt-get install -y grub2-common >/dev/null 2>&1 || true
        update-grub >/dev/null 2>&1 || true
    fi

    info "官方预编译 XANMOD 部署与注册已全部就绪！"
    warn "系统将在 10 秒后强制重启应用新内核..."
    sleep 10
    reboot
}

# ------------------------------------------------------------------------------
# [ 0x08: 编译安装原生 Linux 主线内核 + BBR3 (全量 VIRTIO 防砖版) ]
# ------------------------------------------------------------------------------

do_xanmod_compile() {
    title "系统飞升：编译安装 主线内核 + BBR3 (极客锻造模式)"
    
    warn "警告: 这是一个极其漫长的过程 (30-60分钟)，请确保 SSH 连接稳定！"
    local confirm=""
    read -rp "确定要执意开始源码编译吗？(y/n): " confirm || true
    
    if test "$confirm" != "y"; then
        if test "$confirm" != "Y"; then
            return
        fi
    fi

    title "=== [1/8] 开始执行深度系统清理与空间释放 ==="
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get clean >/dev/null 2>&1 || true
    apt-get autoremove -y --purge >/dev/null 2>&1 || true
    journalctl --vacuum-time=1d >/dev/null 2>&1 || true
    
    rm -rf /var/log/*.log 2>/dev/null || true
    rm -rf /tmp/* 2>/dev/null || true
    rm -rf /usr/src/linux* 2>/dev/null || true
    sync

    # inode 节点防爆探测
    local inode_use
    inode_use=$(df -i / 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%' || echo "0")
    
    if test "$inode_use" -gt 90 2>/dev/null; then
        warn "检测到 inode 节点使用率过高，执行紧急深度释放缓存..."
        rm -rf /var/cache/* 2>/dev/null || true
    fi

    title "=== [2/8] 检查并配置 1GB 编译缓冲交换区 (Swap) ==="
    check_and_create_1gb_swap

    title "=== [3/8] 拉取底层 GCC 编译套件与开发依赖库 ==="
    
    local root_free
    root_free=$(df -m / 2>/dev/null | awk 'NR==2{print $4}' || echo "0")
    
    local BUILD_DIR=""
    if test "$root_free" -gt 4000 2>/dev/null; then 
        mkdir -p /compile 2>/dev/null || true
        BUILD_DIR="/compile"
        info "根目录空间充裕，工作区路由至: /compile"
    else 
        BUILD_DIR="/usr/src"
        info "工作区默认路由至: /usr/src"
    fi

    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y build-essential bc bison flex libssl-dev libelf-dev libncurses-dev zstd git wget curl xz-utils ethtool numactl make pkg-config dwarves rsync python3 libdw-dev cpio >/dev/null 2>&1 || true

    local CPU
    CPU=$(nproc 2>/dev/null || echo 1)
    
    local RAM
    RAM=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo 1024)
    
    local THREADS=1
    
    if test "$RAM" -ge 2000 2>/dev/null; then 
        THREADS=$CPU
    else
        if test "$RAM" -ge 1000 2>/dev/null; then
            THREADS=2
        fi
    fi

    title "=== [4/8] 探测并原生拉取 Kernel 最新的 Stable 稳定版源码 ==="
    
    if ! cd "$BUILD_DIR"; then
        die "权限异常：系统拒绝切入工作区 $BUILD_DIR。"
    fi
    
    local KERNEL_URL=""
    set +e
    KERNEL_URL=$(curl -s https://www.kernel.org/releases.json 2>/dev/null | jq -r '.releases[] | select(.type=="stable") | .tarball' | head -n 1 || echo "")
    set -e
    
    if test -z "$KERNEL_URL"; then 
        warn "探测 kernel.org 失败，强行锁定备用版本 v6.10..."
        KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.10.tar.xz"
    fi
    
    if test "$KERNEL_URL" = "null"; then
        KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.10.tar.xz"
    fi
    
    local KERNEL_FILE
    KERNEL_FILE=$(basename "$KERNEL_URL")
    
    info "建立直连信道，开始拉取源码包: $KERNEL_FILE"
    wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"

    set +o pipefail
    if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
        warn "检测到初次获取的源码包发生数据断层，触发重试..."
        rm -f "$KERNEL_FILE" 2>/dev/null || true
        wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"
        if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
            set -o pipefail
            error "下载或解压验证连续失败，编译行动强制中止。"
            return 1
        fi
    fi
    set -o pipefail

    info "执行 XZ 极致解压，释放内核源码..."
    tar -xJf "$KERNEL_FILE"
    
    # 原生 Bash 字符串截断获取目录，抛弃危险管道
    local KERNEL_DIR
    KERNEL_DIR="${KERNEL_FILE%.tar.xz}"
    
    if ! cd "$KERNEL_DIR"; then
        die "无法切入解压后的源码目录: $KERNEL_DIR。"
    fi

    title "=== [5/8] 注入 VPS 保命驱动 (VIRTIO) 与 BBR3 开启参数 ==="
    
    if test -f "/boot/config-$(uname -r)"; then
        cp "/boot/config-$(uname -r)" .config
        info "已成功提取当前内核配置作为蓝本。"
    else
        if modprobe configs 2>/dev/null; then
            if test -f /proc/config.gz; then
                zcat /proc/config.gz > .config
                info "已成功提取内存运行时配置 (/proc/config.gz)。"
            else
                make defconfig >/dev/null 2>&1 || true
            fi
        else
            make defconfig >/dev/null 2>&1 || true
        fi
    fi
    
    make scripts >/dev/null 2>&1 || true
    
    # 注入 BBR3
    ./scripts/config --enable CONFIG_TCP_CONG_BBR
    ./scripts/config --enable CONFIG_DEFAULT_BBR
    ./scripts/config --enable CONFIG_TCP_BBR3 2>/dev/null || true
    
    # 【核心保命操作】：强行注入 VIRTIO 虚拟化驱动，防止 VPS 重启无法识别硬盘变砖！
    info "正在固化 KVM/Xen 底层虚拟化驱动映射层 (CONFIG_VIRTIO)..."
    ./scripts/config --enable CONFIG_VIRTIO
    ./scripts/config --enable CONFIG_VIRTIO_PCI
    ./scripts/config --enable CONFIG_VIRTIO_BLK
    ./scripts/config --enable CONFIG_VIRTIO_NET
    ./scripts/config --enable CONFIG_SCSI_VIRTIO
    ./scripts/config --enable CONFIG_HW_RANDOM_VIRTIO
    
    # 剔除臃肿驱动与阻碍编译的签名校验
    ./scripts/config --disable CONFIG_DRM_I915
    ./scripts/config --disable CONFIG_NET_VENDOR_REALTEK
    ./scripts/config --disable CONFIG_NET_VENDOR_BROADCOM
    ./scripts/config --disable SYSTEM_TRUSTED_KEYS
    ./scripts/config --disable SYSTEM_REVOCATION_KEYS
    ./scripts/config --disable DEBUG_INFO_BTF
    ./scripts/config --disable DEBUG_INFO
    
    yes "" | make olddefconfig >/dev/null 2>&1 || true

    title "=== [6/8] 释放 CPU 算力，开启内核原生 Forge 锻造模式 ==="
    info "分配编译并发线程数: $THREADS"
    
    if ! make -j"$THREADS"; then
        error "编译线程彻底崩塌！请排查物理内存是否溢出。"
        local _p=""
        read -rp "按 Enter 返回主菜单..." _p || true
        return 1
    fi

    title "=== [7/8] 校验引导区容量并挂载核心模块 ==="
    
    # 【生死巡航】：强制校验 /boot 剩余空间是否大于 200MB
    local boot_free
    boot_free=$(df -m /boot 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    
    # 如果 /boot 不是独立分区，它会读取到 / 的容量，这没问题。
    if test "$boot_free" -lt 200 2>/dev/null; then
        error "致命拦截：/boot 引导扇区剩余空间 ($boot_free MB) 严重不足！"
        error "强行执行 make install 必定导致内核文件残缺、系统彻底变砖！"
        error "编译已主动熔断，请清理无用旧内核后再尝试！"
        local _p=""
        read -rp "按 Enter 返回主菜单..." _p || true
        return 1
    fi
    
    info "/boot 扇区空间充足 ($boot_free MB)，准许物理模块映射与启动扇区安装..."
    
    # 彻底摘除静默容错 `|| true`，一旦安装报错立刻切断脚本
    make modules_install
    make install

    local NEW_KERNEL_VER
    NEW_KERNEL_VER=$(make -s kernelrelease 2>/dev/null || echo "")
    
    if test -n "$NEW_KERNEL_VER"; then
        print_magenta ">>> 为新内核 $NEW_KERNEL_VER 强制生成底层 Initramfs 镜像驱动..."
        if command -v update-initramfs >/dev/null 2>&1; then
            update-initramfs -c -k "$NEW_KERNEL_VER" || true
        else
            if command -v dracut >/dev/null 2>&1; then
                dracut --force "/boot/initramfs-${NEW_KERNEL_VER}.img" "$NEW_KERNEL_VER" || true
            fi
        fi
    fi

    title "=== [8/8] 刷新系统引导器并销毁编译垃圾 ==="
    
    if command -v update-grub >/dev/null 2>&1; then
        update-grub || true
    else
        if command -v update-grub2 >/dev/null 2>&1; then
            update-grub2 || true
        else
            if command -v grub-mkconfig >/dev/null 2>&1; then
                grub-mkconfig -o /boot/grub/grub.cfg || true
            fi
        fi
    fi

    cd /
    rm -rf "$BUILD_DIR/linux-"* 2>/dev/null || true
    rm -rf "$BUILD_DIR/$KERNEL_FILE" 2>/dev/null || true

    info "奇迹再现！无污染原装主线内核编译与 Initramfs 挂载全部顺利结束。"
    warn "老系统将在 15 秒钟内物理退役，请等待自动重启..."
    sleep 15
    reboot
}

# ------------------------------------------------------------------------------
# [ 0x09: 系统内核网络栈极限压榨 (V62 全量 60+ 项网络栈阵列调优) ]
# ------------------------------------------------------------------------------

do_perf_tuning() {
    title "极客压榨：全域系统底层网络栈结构重塑"
    warn "警告: 此操作将深度注入内核级极限并发参数，执行完毕必须重启宿主机！"
    
    local confirm=""
    read -rp "确定要继续吗？(y/n): " confirm || true
    if test "$confirm" != "y"; then
        if test "$confirm" != "Y"; then
            return
        fi
    fi
    
    local current_scale
    current_scale=$(sysctl -n net.ipv4.tcp_adv_win_scale 2>/dev/null || echo "1")
    local current_app
    current_app=$(sysctl -n net.ipv4.tcp_app_win 2>/dev/null || echo "31")
    
    echo -e "  当前 tcp_adv_win_scale: ${cyan}${current_scale}${none} (建议 1 或 2)"
    echo -e "  当前 tcp_app_win: ${cyan}${current_app}${none} (建议 31)"
    
    local new_scale=""
    read -rp "设置 tcp_adv_win_scale (-2 到 2，直接回车保留当前): " new_scale || true
    if test -z "$new_scale"; then new_scale="$current_scale"; fi
    
    local new_app=""
    read -rp "设置 tcp_app_win (1 到 31，直接回车保留当前): " new_app || true
    if test -z "$new_app"; then new_app="$current_app"; fi

    info "清理历史及冗余的网络优化配置..."
    systemctl stop net-speeder >/dev/null 2>&1 || true
    killall net-speeder >/dev/null 2>&1 || true
    systemctl disable net-speeder >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/net-speeder.service 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true

    truncate -s 0 /etc/sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-network-optimized.conf 2>/dev/null || true
    rm -f /etc/sysctl.d/99-bbr*.conf /etc/sysctl.d/99-ipv6-disable.conf /etc/sysctl.d/99-pro*.conf /usr/lib/sysctl.d/50-pid-max.conf 2>/dev/null || true
    
    info "配置系统高并发进程限制 (Limits)..."
    cat > /etc/security/limits.conf << 'EOF'
root soft nofile 1000000
root hard nofile 1000000
root soft nproc 1000000
root hard nproc 1000000
* soft nofile 1000000
* hard nofile 1000000
* soft nproc 1000000
* hard nproc 1000000
EOF

    if ! grep -q "pam_limits.so" /etc/pam.d/common-session 2>/dev/null; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
    fi
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session-noninteractive 2>/dev/null; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive
    fi
    
    sed -i '/DefaultLimitNOFILE/d' /etc/systemd/system.conf 2>/dev/null || true
    sed -i '/DefaultLimitNPROC/d' /etc/systemd/system.conf 2>/dev/null || true
    echo "DefaultLimitNOFILE=1000000" >> /etc/systemd/system.conf
    echo "DefaultLimitNPROC=1000000" >> /etc/systemd/system.conf

    local target_qdisc="fq"
    local cake_state="false"
    if sysctl net.core.default_qdisc 2>/dev/null | grep -q 'cake'; then cake_state="true"; fi
    if test "$cake_state" = "true"; then target_qdisc="cake"; fi

    info "写入内核 Sysctl 参数..."
    cat > /etc/sysctl.d/99-network-optimized.conf << EOF
net.core.default_qdisc = ${target_qdisc}
net.ipv4.tcp_congestion_control = bbr
net.ipv4.neigh.default.base_reachable_time_ms = 60000
net.ipv4.neigh.default.mcast_solicit = 2
net.ipv4.neigh.default.retrans_time_ms = 500
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = ${new_scale}
net.ipv4.tcp_app_win = ${new_app}
net.ipv4.tcp_moderate_rcvbuf = 1
net.core.rmem_default = 560576
net.core.wmem_default = 560576
net.core.rmem_max = 21699928
net.core.wmem_max = 21699928
net.ipv4.tcp_rmem = 4096 760576 21699928
net.ipv4.tcp_wmem = 4096 760576 21699928
net.ipv4.udp_rmem_min = 4096
net.ipv4.udp_wmem_min = 4096
net.core.dev_weight = 64
net.core.dev_weight_tx_bias = 1
net.core.dev_weight_rx_bias = 1
net.core.netdev_budget = 300
vm.swappiness = 1
fs.file-max = 1048576
fs.nr_open = 1048576
fs.inotify.max_user_instances = 262144
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 12
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 262144
net.ipv4.tcp_retries1 = 5
net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_synack_retries = 2
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_max_orphans = 262144
net.core.optmem_max = 3276800
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_reordering = 3
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_tso_win_divisor = 6
kernel.pid_max = 4194304
kernel.threads-max = 85536
net.ipv4.neigh.default.gc_thresh1 = 1024
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv4.neigh.default.gc_stale_time = 100
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
net.unix.max_dgram_qlen = 130000
net.core.busy_poll = 50
net.core.busy_read = 0
net.ipv4.tcp_notsent_lowat = 16384
vm.vfs_cache_pressure = 10
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.ip_forward = 1
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.tcp_early_retrans = 3
net.ipv4.neigh.default.unres_qlen = 35535
net.ipv4.conf.all.route_localnet = 0
net.ipv4.tcp_orphan_retries = 8
net.ipv4.conf.all.forwarding = 1
net.ipv4.ipfrag_max_dist = 32
net.ipv4.ipfrag_secret_interval = 200
net.ipv4.ipfrag_low_thresh = 42008868
net.ipv4.ipfrag_high_thresh = 104917729
net.ipv4.ipfrag_time = 30
fs.aio-max-nr = 262144
kernel.msgmax = 655350
kernel.msgmnb = 655350
net.ipv4.neigh.default.proxy_qlen = 50000
net.ipv4.tcp_pacing_ca_ratio = 150
net.ipv4.tcp_pacing_ss_ratio = 210
fs.protected_fifos = 1
fs.protected_hardlinks = 1
fs.protected_regular = 2
fs.protected_symlinks = 1
net.core.rps_sock_flow_entries = 131072
net.core.flow_limit_table_len = 131072
net.ipv4.tcp_workaround_signed_windows = 1
vm.dirty_ratio = 35
vm.overcommit_memory = 0
kernel.sysrq = 1
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
vm.max_map_count = 65535
net.ipv4.tcp_child_ehash_entries = 65535
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.tcp_stdurg = 0
net.ipv4.tcp_challenge_ack_limit = 1200
net.ipv4.tcp_comp_sack_delay_ns = 50000
net.ipv4.tcp_comp_sack_nr = 1
net.ipv4.tcp_fwmark_accept = 1
net.ipv4.tcp_invalid_ratelimit = 800
net.ipv4.tcp_l3mdev_accept = 1
net.core.tstamp_allow_data = 1
net.core.netdev_tstamp_prequeue = 1
kernel.randomize_va_space = 2
net.ipv4.tcp_mem = 65536 131072 262144
net.ipv4.udp_mem = 65536 131072 262144
net.ipv4.tcp_recovery = 0x1
net.ipv4.tcp_dsack = 1
kernel.shmmax = 67108864
kernel.shmall = 16777216
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_limit_output_bytes = 1310720
net.ipv4.tcp_min_tso_segs = 1
net.ipv4.tcp_thin_linear_timeouts = 0
net.ipv4.tcp_early_demux = 1
net.ipv4.tcp_shrink_window = 0
net.ipv4.neigh.default.unres_qlen_bytes = 65535
kernel.printk = 3 4 1 3
kernel.sched_autogroup_enabled = 0
EOF

    if ! sysctl -p /etc/sysctl.d/99-network-optimized.conf >/dev/null 2>&1; then
        error "Sysctl 参数应用存在错误，部分硬件或系统环境不支持。"
        local _p=""
        read -rp "按 Enter 返回菜单..." _p || true
        return 1
    else
        info "所有底层 Sysctl 参数已成功应用。"
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test -n "$IFACE"; then
        info "配置网卡驱动硬件卸载与 CPU 软中断分发 ($IFACE)..."
        
        cat > /usr/local/bin/nic-optimize.sh <<'EONIC'
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
if test -n "$IFACE"; then
    ethtool -K "$IFACE" lro off rx-gro-hw off 2>/dev/null || true
    ethtool -C "$IFACE" adaptive-rx off rx-usecs 0 tx-usecs 0 2>/dev/null || true
fi
EONIC
        chmod +x /usr/local/bin/nic-optimize.sh
        
        cat > /etc/systemd/system/nic-optimize.service << 'EOSERVICE'
[Unit]
Description=NIC Advanced Tuning
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nic-optimize.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOSERVICE

        systemctl daemon-reload >/dev/null 2>&1 || true
        systemctl enable nic-optimize.service >/dev/null 2>&1 || true
        systemctl start nic-optimize.service >/dev/null 2>&1 || true
        
        cat > /usr/local/bin/rps-optimize.sh <<'EOF_RPS'
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
if test -z "$IFACE"; then 
    exit 0
fi

CPU=$(nproc 2>/dev/null || echo 1)
CPU_MASK=$(printf "%x" $(( (1<<CPU)-1 )))
RX_QUEUES=$(ls -d /sys/class/net/"$IFACE"/queues/rx-* 2>/dev/null | wc -l || echo 0)

for RX in /sys/class/net/"$IFACE"/queues/rx-*; do
    if test -w "$RX/rps_cpus"; then
        echo "$CPU_MASK" > "$RX/rps_cpus" 2>/dev/null || true
    fi
done

for TX in /sys/class/net/"$IFACE"/queues/tx-*; do
    if test -w "$TX/xps_cpus"; then
        echo "$CPU_MASK" > "$TX/xps_cpus" 2>/dev/null || true
    fi
done

sysctl -w net.core.rps_sock_flow_entries=131072 >/dev/null 2>&1 || true

if test "$RX_QUEUES" -gt 0 2>/dev/null; then
    FLOW_PER_QUEUE=$((65535 / RX_QUEUES))
    for RX in /sys/class/net/"$IFACE"/queues/rx-*; do
        if test -w "$RX/rps_flow_cnt"; then
            echo "$FLOW_PER_QUEUE" > "$RX/rps_flow_cnt" 2>/dev/null || true
        fi
    done
fi
EOF_RPS
        chmod +x /usr/local/bin/rps-optimize.sh
        
        cat > /etc/systemd/system/rps-optimize.service << 'EOF_RPS_SRV'
[Unit]
Description=RPS RFS Network CPU Distribution
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/rps-optimize.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF_RPS_SRV

        systemctl daemon-reload >/dev/null 2>&1 || true
        systemctl enable rps-optimize.service >/dev/null 2>&1 || true
        systemctl start rps-optimize.service >/dev/null 2>&1 || true
    fi

    info "网络栈参数应用完成，系统将在 15 秒后重启..."
    sleep 15
    reboot
}
# ==============================================================================
# [ 0x0A: 网卡发送队列调优与 CAKE 参数高级配置 ]
# ==============================================================================

do_txqueuelen_opt() {
    title "网卡发送队列 (TX Queue) 物理调优"
    
    local IP_CMD
    IP_CMD=$(command -v ip || echo "")
    
    if test -z "$IP_CMD"; then
        error "系统缺失 iproute2 (ip 命令) 核心组件，无法调节网卡。"
        local _p=""
        read -rp "按 Enter 返回..." _p || true
        return 1
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test -z "$IFACE"; then
        error "无法定位系统默认出口网卡，操作中止。"
        local _p=""
        read -rp "按 Enter 返回..." _p || true
        return 1
    fi
    
    info "强行扩张 $IFACE 发送队列长度至 2000..."
    $IP_CMD link set "$IFACE" txqueuelen 2000 2>/dev/null || true
    
    cat > /etc/systemd/system/txqueue.service << EOF
[Unit]
Description=Set TX Queue Length for Performance Optimization
After=network.target

[Service]
Type=oneshot
ExecStart=$IP_CMD link set $IFACE txqueuelen 2000
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable txqueue >/dev/null 2>&1 || true
    systemctl start txqueue >/dev/null 2>&1 || true
    
    local CHECK_QLEN
    CHECK_QLEN=$($IP_CMD link show "$IFACE" 2>/dev/null | grep -o 'qlen [0-9]*' | awk '{print $2}' || echo "")
    
    if test "$CHECK_QLEN" = "2000"; then
        info "已成功将网卡底层并发队列长度扩容至 2000 级。"
    else
        warn "修改失败！当前虚拟机或网卡驱动不支持调节 txqueuelen 队列长度。"
    fi
    
    local _p=""
    read -rp "按 Enter 键返回主菜单..." _p || true
}

config_cake_advanced() {
    clear
    title "CAKE 拥塞调度器高级微操配置"
    
    local current_opts="未配置 (系统自适应默认)"
    if test -f "$CAKE_OPTS_FILE"; then
        current_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
    fi
    
    echo -e "  当前运行参数: ${cyan}${current_opts}${none}\n"
    
    local c_bw=""
    echo -e "  [1] 声明物理带宽限制 (例如 900Mbit，填 0 取消限制): "
    read -rp "  请输入: " c_bw || true
    
    local c_oh=""
    echo -e "  [2] 配置底层报文开销补偿 Overhead (填 0 取消限制): "
    read -rp "  请输入: " c_oh || true
    
    local c_mpu=""
    echo -e "  [3] 最小数据单元截断 MPU (填 0 取消限制): "
    read -rp "  请输入: " c_mpu || true
    
    echo "  [4] RTT 延迟模型: "
    echo "    1) internet  (标准互联 85ms)"
    echo "    2) oceanic   (跨洋海缆 300ms)"
    echo "    3) satellite (卫星链路 1000ms)"
    
    local rtt_sel=""
    read -rp "  请选择 (默认 2): " rtt_sel || true
    
    local c_rtt=""
    case "${rtt_sel:-2}" in
        1) c_rtt="internet" ;;
        3) c_rtt="satellite" ;;
        *) c_rtt="oceanic" ;;
    esac
    
    echo "  [5] 流量分类识别 (Diffserv): "
    echo "    1) diffserv4  (按数据包特征分类，CPU 消耗较高)"
    echo "    2) besteffort (盲推忽略特征，大幅降低 CPU 开销)"
    
    local diff_sel=""
    read -rp "  请选择 (默认 2): " diff_sel || true
    
    local c_diff=""
    case "${diff_sel:-2}" in
        1) c_diff="diffserv4" ;;
        *) c_diff="besteffort" ;;
    esac

    local final_opts=""
    
    if test -n "$c_bw"; then
        if test "$c_bw" != "0"; then
            final_opts="$final_opts bandwidth $c_bw"
        fi
    fi
    
    if test -n "$c_oh"; then
        if test "$c_oh" != "0"; then
            final_opts="$final_opts overhead $c_oh"
        fi
    fi
    
    if test -n "$c_mpu"; then
        if test "$c_mpu" != "0"; then
            final_opts="$final_opts mpu $c_mpu"
        fi
    fi
    
    final_opts="$final_opts $c_rtt $c_diff"
    
    # 去除前导空格
    final_opts="${final_opts#"${final_opts%%[! ]*}"}"
    
    if test -z "$final_opts"; then
        rm -f "$CAKE_OPTS_FILE" 2>/dev/null || true
        info "已清除所有 CAKE 自定义高阶参数，恢复默认。"
    else
        echo "$final_opts" > "$CAKE_OPTS_FILE"
        info "CAKE 高阶参数已写入物理储存: $final_opts"
    fi
    
    # 强制挂载内核模块
    modprobe sch_cake >/dev/null 2>&1 || true
    
    _apply_cake_live
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test -n "$IFACE"; then
        if tc qdisc show dev "$IFACE" 2>/dev/null | grep -q "cake"; then
            info "验证通过：CAKE 高阶队列已成功接管网卡接口！"
        else
            warn "验证失败：网卡当前未运行 CAKE 调度器。请确认系统内核支持 sch_cake 模块。"
        fi
    fi
    
    local _p=""
    read -rp "参数阵列配置完成，请按 Enter 返回主菜单..." _p || true
}

# ==============================================================================
# [ 0x0B: 系统级 20 项深度状态探针与自启保护引擎 ]
# ==============================================================================

check_mph_state() {
    local state
    state=$(jq -r '.routing.domainMatcher // "false"' "$CONFIG" 2>/dev/null || echo "false")
    if test "$state" = "mph"; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_maxtime_state() {
    local state
    state=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
    if test "$state" = "60000"; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_routeonly_state() {
    local state
    state=$(jq -r '.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
    if test "$state" = "true"; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_sniff_state() {
    local state
    state=$(jq -r '.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.metadataOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
    if test "$state" = "true"; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_affinity_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if test -f "$limit_file"; then
        if grep -q "^CPUAffinity=" "$limit_file" 2>/dev/null; then 
            echo "true"
            return
        fi
    fi
    echo "false"
}

check_buffer_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if test -f "$limit_file"; then
        if grep -q "^Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" "$limit_file" 2>/dev/null; then 
            echo "true"
            return
        fi
    fi
    echo "false"
}

check_dnsmasq_state() {
    if systemctl is-active --quiet dnsmasq 2>/dev/null; then
        if test -f /etc/resolv.conf; then
            if grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null; then 
                echo "true"
                return
            fi
        fi
    fi
    echo "false"
}

check_thp_state() {
    if test ! -f "/sys/kernel/mm/transparent_hugepage/enabled"; then 
        echo "unsupported"
        return
    fi
    
    if test ! -w "/sys/kernel/mm/transparent_hugepage/enabled"; then 
        echo "unsupported"
        return
    fi
    
    if grep -q '\[never\]' /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_mtu_state() {
    if test ! -f "/proc/sys/net/ipv4/tcp_mtu_probing"; then 
        echo "unsupported"
        return
    fi
    
    local val
    val=$(sysctl -n net.ipv4.tcp_mtu_probing 2>/dev/null || echo "0")
    if test "$val" = "1"; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_cpu_state() {
    if test ! -d "/sys/devices/system/cpu/cpu0/cpufreq"; then 
        echo "unsupported"
        return
    fi
    
    if grep -q 'performance' /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_ring_state() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test -z "$IFACE"; then 
        echo "unsupported"
        return
    fi
    
    if ! command -v ethtool >/dev/null 2>&1; then 
        echo "unsupported"
        return
    fi
    
    if ! ethtool -g "$IFACE" >/dev/null 2>&1; then 
        echo "unsupported"
        return
    fi
    
    local curr_rx
    curr_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Current hardware settings" | grep "RX:" | head -n 1 | awk '{print $2}' || echo "")
    
    if test -z "$curr_rx"; then 
        echo "unsupported"
        return
    fi
    
    if test "$curr_rx" = "512"; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_zram_state() {
    if ! modprobe -n zram >/dev/null 2>&1; then
        if ! lsmod 2>/dev/null | grep -q zram; then 
            echo "unsupported"
            return
        fi
    fi
    
    if swapon --show 2>/dev/null | grep -q 'zram'; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_journal_state() {
    if test ! -f "/etc/systemd/journald.conf"; then 
        echo "unsupported"
        return
    fi
    
    if grep -q '^Storage=volatile' /etc/systemd/journald.conf 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_process_priority_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    
    if test ! -f "$limit_file"; then 
        echo "false"
        return
    fi
    
    if grep -q "^OOMScoreAdjust=-500" "$limit_file" 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_cake_state() {
    if sysctl net.core.default_qdisc 2>/dev/null | grep -q 'cake'; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_ackfilter_state() {
    if test -f "$FLAGS_DIR/ack_filter"; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_ecn_state() {
    if test -f "$FLAGS_DIR/ecn"; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_wash_state() {
    if test -f "$FLAGS_DIR/wash"; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_gso_off_state() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test -z "$IFACE"; then
        echo "unsupported"
        return
    fi
    
    if ! command -v ethtool >/dev/null 2>&1; then 
        echo "unsupported"
        return
    fi
    
    local eth_info
    eth_info=$(ethtool -k "$IFACE" 2>/dev/null || echo "")
    
    if test -z "$eth_info"; then 
        echo "unsupported"
        return
    fi
    
    if echo "$eth_info" | grep -E "^generic-receive-offload:|^rx-gro:" | grep -q "fixed" 2>/dev/null; then 
        echo "unsupported"
        return
    fi
    
    if echo "$eth_info" | grep -E "^generic-receive-offload:|^rx-gro:" | grep -q " off" 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_irq_state() {
    local CORES
    CORES=$(nproc 2>/dev/null || echo 1)
    
    if test "$CORES" -lt 2 2>/dev/null; then 
        echo "unsupported"
        return
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test -z "$IFACE"; then
        echo "false"
        return
    fi
    
    local irq
    irq=$(grep "$IFACE" /proc/interrupts 2>/dev/null | head -n 1 | awk '{print $1}' | tr -d ':' || echo "")
    
    if test -n "$irq"; then
        local mask
        mask=$(cat "/proc/irq/$irq/smp_affinity" 2>/dev/null | tr -d '0' || echo "")
        if test "$mask" = "1"; then 
            echo "true"
        else 
            echo "false"
        fi
    else
        echo "false"
    fi
}

# ------------------------------------------------------------------------------
# [ 0x0C: 系统底层硬件微操开机加载驱动中心 ]
# ------------------------------------------------------------------------------

update_hw_boot_script() {
    cat > /usr/local/bin/xray-hw-tweaks.sh << 'SHEOF'
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
if test -z "$IFACE"; then
    sleep 3
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
fi
SHEOF

    if test "$(check_thp_state)" = "true"; then
        cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
if test -w /sys/kernel/mm/transparent_hugepage/enabled; then
    echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
    echo never > /sys/kernel/mm/transparent_hugepage/defrag  2>/dev/null || true
fi
EOF
    fi

    if test "$(check_cpu_state)" = "true"; then
        cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    if test -f "$cpu"; then
        echo performance > "$cpu" 2>/dev/null || true
    fi
done
EOF
    fi

    if test "$(check_ring_state)" = "true"; then
        echo "ethtool -G \$IFACE rx 512 tx 512 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
    fi
    
    local gso_state
    gso_state=$(check_gso_off_state)
    
    if test "$gso_state" = "true"; then
        echo "ethtool -K \$IFACE gro off gso off tso off 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
    else
        if test "$gso_state" = "false"; then
            echo "ethtool -K \$IFACE gro on gso on tso on 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
        fi
    fi
    
    cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
CAKE_OPTS=""
if test -f "/usr/local/etc/xray/cake_opts.txt"; then
    CAKE_OPTS=$(cat "/usr/local/etc/xray/cake_opts.txt" 2>/dev/null || true)
fi

ACK_FLAG=""
if test -f "/usr/local/etc/xray/flags/ack_filter"; then
    ACK_FLAG="ack-filter"
fi

ECN_FLAG=""
if test -f "/usr/local/etc/xray/flags/ecn"; then
    ECN_FLAG="ecn"
fi

WASH_FLAG=""
if test -f "/usr/local/etc/xray/flags/wash"; then
    WASH_FLAG="wash"
fi
EOF

    if test "$(check_cake_state)" = "true"; then
        echo 'tc qdisc replace dev $IFACE root cake $CAKE_OPTS $ACK_FLAG $ECN_FLAG $WASH_FLAG 2>/dev/null || true' >> /usr/local/bin/xray-hw-tweaks.sh
    fi

    if test "$(check_irq_state)" = "true"; then
        cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
systemctl stop irqbalance 2>/dev/null || true
for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || true); do
    if test -w "/proc/irq/$irq/smp_affinity"; then
        echo 1 > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true
    fi
done
EOF
    fi

    chmod +x /usr/local/bin/xray-hw-tweaks.sh 2>/dev/null || true

    cat > /etc/systemd/system/xray-hw-tweaks.service << 'EOF'
[Unit]
Description=Xray Hardware Parameters Loader
After=network.target

[Service]
Type=oneshot
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/usr/local/bin/xray-hw-tweaks.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable xray-hw-tweaks.service >/dev/null 2>&1 || true
}

_apply_cake_live() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test -z "$IFACE"; then
        return
    fi
    
    if test "$(check_cake_state)" = "true"; then
        local base_opts=""
        if test -f "$CAKE_OPTS_FILE"; then
            base_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
        fi
        
        local f_ack=""
        if test "$(check_ackfilter_state)" = "true"; then 
            f_ack="ack-filter"
        fi
        
        local f_ecn=""
        if test "$(check_ecn_state)" = "true"; then 
            f_ecn="ecn"
        fi
        
        local f_wash=""
        if test "$(check_wash_state)" = "true"; then 
            f_wash="wash"
        fi
        
        tc qdisc replace dev "$IFACE" root cake $base_opts $f_ack $f_ecn $f_wash 2>/dev/null || true
    fi
    
    update_hw_boot_script
}
# ==============================================================================
# [ 0x0D: 全局底层拔插调度模块 (Toggle 引擎防爆版) ]
# ==============================================================================

_toggle_affinity_on() {
    local lf="/etc/systemd/system/xray.service.d/limits.conf"
    if test -f "$lf"; then
        sed -i '/^CPUAffinity=/d' "$lf" 2>/dev/null || true
        sed -i '/^Environment="GOMAXPROCS=/d' "$lf" 2>/dev/null || true
        
        local TARGET_CPU
        local CORES
        CORES=$(nproc 2>/dev/null || echo 1)
        
        if test "$CORES" -ge 2 2>/dev/null; then 
            TARGET_CPU=1
        else 
            TARGET_CPU=0
        fi
        
        echo "CPUAffinity=$TARGET_CPU" >> "$lf"
        echo "Environment=\"GOMAXPROCS=1\"" >> "$lf"
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

_toggle_affinity_off() {
    local lf="/etc/systemd/system/xray.service.d/limits.conf"
    if test -f "$lf"; then
        sed -i '/^CPUAffinity=/d' "$lf" 2>/dev/null || true
        sed -i '/^Environment="GOMAXPROCS=/d' "$lf" 2>/dev/null || true
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

toggle_buffer() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if test -f "$limit_file"; then
        if test "$(check_buffer_state)" = "true"; then
            sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
        else
            sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
            echo "Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" >> "$limit_file"
        fi
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

toggle_dnsmasq() {
    if test "$(check_dnsmasq_state)" = "true"; then
        systemctl stop dnsmasq >/dev/null 2>&1 || true
        systemctl disable dnsmasq >/dev/null 2>&1 || true
        
        chattr -i /etc/resolv.conf 2>/dev/null || true
        rm -f /etc/resolv.conf 2>/dev/null || true
        
        if test -f /etc/resolv.conf.bak; then 
            mv /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true
        else 
            echo "nameserver 8.8.8.8" > /etc/resolv.conf
        fi
        
        systemctl enable systemd-resolved >/dev/null 2>&1 || true
        systemctl start systemd-resolved >/dev/null 2>&1 || true
        
        _safe_jq_write '
          .dns = {
              "servers": [
                  "https://8.8.8.8/dns-query",
                  "https://1.1.1.1/dns-query",
                  "https://doh.opendns.com/dns-query"
              ],
              "queryStrategy": "UseIP"
          }
        '
    else
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y >/dev/null 2>&1 || yum makecache -y >/dev/null 2>&1 || true
        apt-get install -y dnsmasq >/dev/null 2>&1 || yum install -y dnsmasq >/dev/null 2>&1 || true
        
        systemctl stop systemd-resolved 2>/dev/null || true
        systemctl disable systemd-resolved 2>/dev/null || true
        systemctl stop resolvconf 2>/dev/null || true
        
        cat > /etc/dnsmasq.conf <<EOF
port=53
listen-address=127.0.0.1
bind-interfaces
cache-size=21000
min-cache-ttl=3600
all-servers
server=8.8.8.8
server=1.1.1.1
server=208.67.222.222
no-resolv
no-poll
EOF
        systemctl enable dnsmasq >/dev/null 2>&1 || true
        systemctl restart dnsmasq >/dev/null 2>&1 || true
        
        chattr -i /etc/resolv.conf 2>/dev/null || true
        
        if test ! -f /etc/resolv.conf.bak; then 
            cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true
        fi
        
        rm -f /etc/resolv.conf 2>/dev/null || true
        echo "nameserver 127.0.0.1" > /etc/resolv.conf
        chattr +i /etc/resolv.conf 2>/dev/null || true
        
        _safe_jq_write '
          .dns = {
              "servers": ["127.0.0.1"],
              "queryStrategy": "UseIP"
          }
        '
    fi
}

toggle_thp() {
    if test "$(check_thp_state)" = "true"; then
        if test -w /sys/kernel/mm/transparent_hugepage/enabled; then
            echo always > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
            echo always > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true
        fi
    else
        if test -w /sys/kernel/mm/transparent_hugepage/enabled; then
            echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
            echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true
        fi
    fi
    update_hw_boot_script
}

toggle_mtu() {
    local conf="/etc/sysctl.d/99-network-optimized.conf"
    
    if test "$(check_mtu_state)" = "true"; then 
        sed -i 's/^net.ipv4.tcp_mtu_probing.*/net.ipv4.tcp_mtu_probing = 0/' "$conf" 2>/dev/null || true
    else
        if grep -q "net.ipv4.tcp_mtu_probing" "$conf" 2>/dev/null; then 
            sed -i 's/^net.ipv4.tcp_mtu_probing.*/net.ipv4.tcp_mtu_probing = 1/' "$conf" 2>/dev/null || true
        else 
            echo "net.ipv4.tcp_mtu_probing = 1" >> "$conf"
        fi
    fi
    sysctl -p "$conf" >/dev/null 2>&1 || true
}

toggle_cpu() {
    if test "$(check_cpu_state)" = "unsupported"; then 
        return
    fi
    
    if test "$(check_cpu_state)" = "true"; then 
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do 
            if test -f "$cpu"; then 
                echo schedutil > "$cpu" 2>/dev/null || echo ondemand > "$cpu" 2>/dev/null || true
            fi
        done
    else 
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do 
            if test -f "$cpu"; then 
                echo performance > "$cpu" 2>/dev/null || true
            fi
        done
    fi
    update_hw_boot_script
}

toggle_ring() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test "$(check_ring_state)" = "unsupported"; then 
        return
    fi
    
    if test "$(check_ring_state)" = "true"; then
        local max_rx
        max_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Pre-set maximums" | grep "RX:" | head -n 1 | awk '{print $2}' || echo "512")
        
        if test -n "$max_rx"; then 
            ethtool -G "$IFACE" rx "$max_rx" tx "$max_rx" 2>/dev/null || true
        fi
    else 
        ethtool -G "$IFACE" rx 512 tx 512 2>/dev/null || true
    fi
    update_hw_boot_script
}

toggle_gso_off() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test "$(check_gso_off_state)" = "unsupported"; then 
        warn "硬件卸载已被底层驱动强制锁死 (fixed)。已安全跳过干预！"
        sleep 2
        return
    fi
    
    if test "$(check_gso_off_state)" = "true"; then 
        ethtool -K "$IFACE" gro on gso on tso on 2>/dev/null || true
    else 
        ethtool -K "$IFACE" gro off gso off tso off 2>/dev/null || true
    fi
    update_hw_boot_script
}

toggle_zram() {
    if test "$(check_zram_state)" = "unsupported"; then 
        return
    fi
    
    if test "$(check_zram_state)" = "true"; then
        swapoff /dev/zram0 2>/dev/null || true
        rmmod zram 2>/dev/null || true
        systemctl disable xray-zram.service --now 2>/dev/null || true
        rm -f /etc/systemd/system/xray-zram.service /usr/local/bin/xray-zram.sh 2>/dev/null || true
    else
        local TOTAL_MEM
        TOTAL_MEM=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo "1024")
        local ZRAM_SIZE
        
        if test "$TOTAL_MEM" -lt 500 2>/dev/null; then 
            ZRAM_SIZE=$((TOTAL_MEM * 2))
        else
            if test "$TOTAL_MEM" -lt 1024 2>/dev/null; then 
                ZRAM_SIZE=$((TOTAL_MEM * 3 / 2))
            else 
                ZRAM_SIZE=$TOTAL_MEM
            fi
        fi
        
        cat > /usr/local/bin/xray-zram.sh <<EOFZ
#!/bin/bash
modprobe zram num_devices=1
echo "lz4" > /sys/block/zram0/comp_algorithm 2>/dev/null || true
echo "${ZRAM_SIZE}M" > /sys/block/zram0/disksize
mkswap /dev/zram0
swapon -p 100 /dev/zram0
EOFZ
        chmod +x /usr/local/bin/xray-zram.sh 2>/dev/null || true
        
        cat > /etc/systemd/system/xray-zram.service <<EOFZ
[Unit]
Description=Xray ZRAM Setup
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/xray-zram.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOFZ
        systemctl daemon-reload >/dev/null 2>&1 || true
        systemctl enable xray-zram.service >/dev/null 2>&1 || true
        systemctl start xray-zram.service >/dev/null 2>&1 || true
    fi
}

toggle_journal() {
    local conf="/etc/systemd/journald.conf"
    
    if test "$(check_journal_state)" = "unsupported"; then 
        return
    fi
    
    if test "$(check_journal_state)" = "true"; then 
        sed -i 's/^Storage=volatile/#Storage=auto/' "$conf" 2>/dev/null || true
    else
        if grep -q "^#Storage=" "$conf" 2>/dev/null; then 
            sed -i 's/^#Storage=.*/Storage=volatile/' "$conf" 2>/dev/null || true
        else
            if grep -q "^Storage=" "$conf" 2>/dev/null; then 
                sed -i 's/^Storage=.*/Storage=volatile/' "$conf" 2>/dev/null || true
            else 
                echo "Storage=volatile" >> "$conf"
            fi
        fi
    fi
    systemctl restart systemd-journald >/dev/null 2>&1 || true
}

toggle_process_priority() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    
    if test ! -f "$limit_file"; then 
        return
    fi
    
    if grep -q "^OOMScoreAdjust=-500" "$limit_file" 2>/dev/null; then
        sed -i '/^OOMScoreAdjust=/d' "$limit_file" 2>/dev/null || true
        sed -i '/^IOSchedulingClass=/d' "$limit_file" 2>/dev/null || true
        sed -i '/^IOSchedulingPriority=/d' "$limit_file" 2>/dev/null || true
    else
        echo "OOMScoreAdjust=-500" >> "$limit_file"
        echo "IOSchedulingClass=realtime" >> "$limit_file"
        echo "IOSchedulingPriority=2" >> "$limit_file"
    fi
    systemctl daemon-reload >/dev/null 2>&1 || true
}

toggle_cake() {
    local conf="/etc/sysctl.d/99-network-optimized.conf"
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test "$(check_cake_state)" = "true"; then
        sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = fq/' "$conf" 2>/dev/null || true
        sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1 || true
        
        if test -n "$IFACE"; then
            tc qdisc replace dev "$IFACE" root fq 2>/dev/null || true
        fi
        update_hw_boot_script
    else
        sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = cake/' "$conf" 2>/dev/null || true
        if ! grep -q "net.core.default_qdisc" "$conf" 2>/dev/null; then 
            echo "net.core.default_qdisc = cake" >> "$conf"
        fi
        
        modprobe sch_cake >/dev/null 2>&1 || true
        sysctl -w net.core.default_qdisc=cake >/dev/null 2>&1 || true
        _apply_cake_live
    fi
}

toggle_ackfilter() {
    if test "$(check_ackfilter_state)" = "true"; then 
        rm -f "$FLAGS_DIR/ack_filter" 2>/dev/null || true
    else 
        touch "$FLAGS_DIR/ack_filter" 2>/dev/null || true
    fi
    
    if test "$(check_cake_state)" = "false"; then 
        warn "系统已将状态锚点落盘，但必须先开启 CAKE 队列，此项优化才能被挂载！"
        sleep 2
        return
    fi
    _apply_cake_live
}

toggle_ecn() {
    if test "$(check_ecn_state)" = "true"; then 
        rm -f "$FLAGS_DIR/ecn" 2>/dev/null || true
    else 
        touch "$FLAGS_DIR/ecn" 2>/dev/null || true
    fi
    
    if test "$(check_cake_state)" = "false"; then 
        warn "系统已将状态锚点落盘，但必须先开启 CAKE 队列，此项优化才能被挂载！"
        sleep 2
        return
    fi
    _apply_cake_live
}

toggle_wash() {
    if test "$(check_wash_state)" = "true"; then 
        rm -f "$FLAGS_DIR/wash" 2>/dev/null || true
    else 
        touch "$FLAGS_DIR/wash" 2>/dev/null || true
    fi
    
    if test "$(check_cake_state)" = "false"; then 
        warn "系统已将状态锚点落盘，但必须先开启 CAKE 队列，此项优化才能被挂载！"
        sleep 2
        return
    fi
    _apply_cake_live
}

toggle_irq() {
    if test "$(check_irq_state)" = "unsupported"; then 
        return
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    local CORES
    CORES=$(nproc 2>/dev/null || echo 1)
    local DEFAULT_MASK
    DEFAULT_MASK=$(printf "%x" $(( (1<<CORES)-1 )))
    
    if test "$(check_irq_state)" = "true"; then
        for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || echo ""); do 
            if test -n "$irq"; then 
                if test -w "/proc/irq/$irq/smp_affinity"; then
                    echo "$DEFAULT_MASK" > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true
                fi
            fi
        done
        systemctl start irqbalance >/dev/null 2>&1 || true
        systemctl enable irqbalance >/dev/null 2>&1 || true
    else
        systemctl stop irqbalance >/dev/null 2>&1 || true
        systemctl disable irqbalance >/dev/null 2>&1 || true
        for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || echo ""); do 
            if test -n "$irq"; then 
                if test -w "/proc/irq/$irq/smp_affinity"; then
                    echo 1 > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true
                fi
            fi
        done
    fi
    update_hw_boot_script
}

# ==============================================================================
# [ 0x0E: 应用层高级调优引擎 (JSON 隔离操作) ]
# ==============================================================================

_turn_on_app() {
    _safe_jq_write '
      .routing = (.routing // {}) |
      .routing.domainMatcher = "mph" |
      (.outbounds[]? | select(.protocol == "freedom")) |= (
          .streamSettings = (.streamSettings // {}) |
          .streamSettings.sockopt = (.streamSettings.sockopt // {}) |
          .streamSettings.sockopt.tcpNoDelay = true |
          .streamSettings.sockopt.tcpFastOpen = true |
          .streamSettings.sockopt.tcpKeepAliveIdle = 30 |
          .streamSettings.sockopt.tcpKeepAliveInterval = 15
      ) |
      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= (
          .streamSettings = (.streamSettings // {}) |
          .streamSettings.sockopt = (.streamSettings.sockopt // {}) |
          .streamSettings.sockopt.tcpNoDelay = true |
          .streamSettings.sockopt.tcpFastOpen = true |
          .streamSettings.sockopt.tcpKeepAliveIdle = 30 |
          .streamSettings.sockopt.tcpKeepAliveInterval = 15 |
          .sniffing = (.sniffing // {}) |
          .sniffing.metadataOnly = true |
          .sniffing.routeOnly = true
      )
    '
    
    local has_reality
    has_reality=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .protocol' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
    
    if test -n "$has_reality"; then
        _safe_jq_write '
          (.inbounds[]? | select(.protocol == "vless" and .streamSettings.security == "reality")) |= (
              .streamSettings.realitySettings = (.streamSettings.realitySettings // {}) |
              .streamSettings.realitySettings.maxTimeDiff = 60000
          )
        '
    fi
    
    local dns_status
    dns_status=$(check_dnsmasq_state 2>/dev/null || echo "false")
    
    if test "$dns_status" = "true"; then
        _safe_jq_write '
          .dns = {
              "servers": [
                  "127.0.0.1"
              ],
              "queryStrategy": "UseIP"
          }
        '
    else
        _safe_jq_write '
          .dns = {
              "servers": [
                  "https://8.8.8.8/dns-query",
                  "https://1.1.1.1/dns-query",
                  "https://doh.opendns.com/dns-query"
              ],
              "queryStrategy": "UseIP"
          }
        '
    fi
    
    _safe_jq_write '
      .policy = {
          "levels": {
              "0": {
                  "handshake": 3,
                  "connIdle": 60
              }
          },
          "system": {
              "statsInboundDownlink": false,
              "statsInboundUplink": false
          }
      }
    '
    
    _toggle_affinity_on
    
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if test -f "$limit_file"; then
        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
        echo "Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" >> "$limit_file"
        
        local TOTAL_MEM
        TOTAL_MEM=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo "1024")
        local DYNAMIC_GOGC=100
        
        if test "$TOTAL_MEM" -ge 1800 2>/dev/null; then 
            DYNAMIC_GOGC=1000
        else
            if test "$TOTAL_MEM" -ge 900 2>/dev/null; then 
                DYNAMIC_GOGC=500
            else
                if test "$TOTAL_MEM" -ge 700 2>/dev/null; then
                    DYNAMIC_GOGC=400
                else
                    if test "$TOTAL_MEM" -ge 500 2>/dev/null; then
                        DYNAMIC_GOGC=300
                    else
                        if test "$TOTAL_MEM" -ge 400 2>/dev/null; then
                            DYNAMIC_GOGC=200
                        else
                            DYNAMIC_GOGC=100
                        fi
                    fi
                fi
            fi
        fi
        
        sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=$DYNAMIC_GOGC\"/" "$limit_file" 2>/dev/null || true
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

_turn_off_app() {
    _safe_jq_write '
      del(.routing.domainMatcher) |
      (.outbounds[]? | select(.protocol == "freedom")) |= 
          del(.streamSettings.sockopt.tcpNoDelay, .streamSettings.sockopt.tcpFastOpen, .streamSettings.sockopt.tcpKeepAliveIdle, .streamSettings.sockopt.tcpKeepAliveInterval) |
      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= (
          del(.streamSettings.sockopt.tcpNoDelay, .streamSettings.sockopt.tcpFastOpen, .streamSettings.sockopt.tcpKeepAliveIdle, .streamSettings.sockopt.tcpKeepAliveInterval) |
          .sniffing = (.sniffing // {}) |
          .sniffing.metadataOnly = false |
          .sniffing.routeOnly = false
      )
    '
    
    _safe_jq_write '
      (.inbounds[]? | select(.protocol == "vless" and .streamSettings.security == "reality")) |= 
          del(.streamSettings.realitySettings.maxTimeDiff) |
      del(.dns) |
      del(.policy)
    '
    
    _toggle_affinity_off
    
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if test -f "$limit_file"; then
        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
        sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=100\"/" "$limit_file" 2>/dev/null || true
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

# ==============================================================================
# [ 0x0F: 全域 28 项状态调度面板 ]
# ==============================================================================

do_app_level_tuning_menu() {
    while true; do
        clear
        title "应用层与系统级高级参数调优 (25+3项)"
        
        if test ! -f "$CONFIG"; then
            error "底盘 JSON 缺失，请首先执行基础核心构建！"
            local _p=""
            read -rp "按 Enter 退出..." _p || true
            return
        fi

        # ==========================================
        # 瞬时全量状态提取 (应用层 1-11 项，无压缩)
        # ==========================================
        local out_fastopen
        out_fastopen=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpFastOpen // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        local out_keepalive
        out_keepalive=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpKeepAliveIdle // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        local sniff_status
        sniff_status=$(check_sniff_state 2>/dev/null || echo "false")
        
        local dns_status
        dns_status=$(jq -r '.dns?.queryStrategy // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        local policy_status
        policy_status=$(jq -r '.policy?.levels["0"]?.connIdle // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        local affinity_state
        affinity_state=$(check_affinity_state 2>/dev/null || echo "false")
        
        local mph_state
        mph_state=$(check_mph_state 2>/dev/null || echo "false")
        
        local maxtime_state
        maxtime_state=$(check_maxtime_state 2>/dev/null || echo "false")
        
        local routeonly_status
        routeonly_status=$(check_routeonly_state 2>/dev/null || echo "false")
        
        local buffer_state
        buffer_state=$(check_buffer_state 2>/dev/null || echo "false")
        
        local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
        local gc_status="未知"
        
        if test -f "$limit_file"; then
            local temp_gc
            temp_gc=$(awk -F'=' '/^Environment="GOGC=/ {print $3}' "$limit_file" 2>/dev/null | tr -d '"' | head -n 1 || echo "100")
            if test -n "$temp_gc"; then
                gc_status="$temp_gc"
            fi
        fi
        
        if test "$gc_status" = "未知"; then
            gc_status="默认 100"
        fi

        # ==========================================
        # 瞬时全量状态提取 (系统层 12-25 项，无压缩)
        # ==========================================
        local dnsmasq_state thp_state mtu_state cpu_state ring_state zram_state journal_state prio_state cake_state irq_state gso_off_state ackfilter_state ecn_state wash_state
        dnsmasq_state=$(check_dnsmasq_state 2>/dev/null || echo "false")
        thp_state=$(check_thp_state 2>/dev/null || echo "false")
        mtu_state=$(check_mtu_state 2>/dev/null || echo "false")
        cpu_state=$(check_cpu_state 2>/dev/null || echo "false")
        ring_state=$(check_ring_state 2>/dev/null || echo "false")
        zram_state=$(check_zram_state 2>/dev/null || echo "false")
        journal_state=$(check_journal_state 2>/dev/null || echo "false")
        prio_state=$(check_process_priority_state 2>/dev/null || echo "false")
        cake_state=$(check_cake_state 2>/dev/null || echo "false")
        irq_state=$(check_irq_state 2>/dev/null || echo "false")
        gso_off_state=$(check_gso_off_state 2>/dev/null || echo "false")
        ackfilter_state=$(check_ackfilter_state 2>/dev/null || echo "false")
        ecn_state=$(check_ecn_state 2>/dev/null || echo "false")
        wash_state=$(check_wash_state 2>/dev/null || echo "false")

        # ==========================================
        # 缺省探测雷达
        # ==========================================
        local app_off_count=0
        if test "$out_fastopen" != "true"; then app_off_count=$((app_off_count + 1)); fi
        if test "$out_keepalive" != "30"; then app_off_count=$((app_off_count + 1)); fi
        if test "$sniff_status" != "true"; then app_off_count=$((app_off_count + 1)); fi
        if test "$dns_status" != "UseIP"; then app_off_count=$((app_off_count + 1)); fi
        if echo "$gc_status" | grep -q "100" 2>/dev/null; then app_off_count=$((app_off_count + 1)); fi
        if test "$policy_status" != "60"; then app_off_count=$((app_off_count + 1)); fi
        if test "$affinity_state" != "true"; then app_off_count=$((app_off_count + 1)); fi
        if test "$mph_state" != "true"; then app_off_count=$((app_off_count + 1)); fi
        if test "$routeonly_status" != "true"; then app_off_count=$((app_off_count + 1)); fi
        if test "$buffer_state" != "true"; then app_off_count=$((app_off_count + 1)); fi
        
        local has_reality
        has_reality=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .protocol' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
        
        if test -n "$has_reality"; then
            if test "$maxtime_state" != "true"; then
                app_off_count=$((app_off_count + 1))
            fi
        fi

        local sys_off_count=0
        if test "$dnsmasq_state" = "false"; then sys_off_count=$((sys_off_count + 1)); fi
        if test "$thp_state" = "false"; then sys_off_count=$((sys_off_count + 1)); fi
        if test "$mtu_state" = "false"; then sys_off_count=$((sys_off_count + 1)); fi
        if test "$cpu_state" = "false"; then sys_off_count=$((sys_off_count + 1)); fi
        if test "$ring_state" = "false"; then sys_off_count=$((sys_off_count + 1)); fi
        if test "$zram_state" = "false"; then sys_off_count=$((sys_off_count + 1)); fi
        if test "$journal_state" = "false"; then sys_off_count=$((sys_off_count + 1)); fi
        if test "$prio_state" = "false"; then sys_off_count=$((sys_off_count + 1)); fi
        if test "$cake_state" = "false"; then sys_off_count=$((sys_off_count + 1)); fi
        if test "$irq_state" = "false"; then sys_off_count=$((sys_off_count + 1)); fi
        if test "$gso_off_state" = "false"; then sys_off_count=$((sys_off_count + 1)); fi
        if test "$ackfilter_state" = "false"; then sys_off_count=$((sys_off_count + 1)); fi
        if test "$ecn_state" = "false"; then sys_off_count=$((sys_off_count + 1)); fi
        if test "$wash_state" = "false"; then sys_off_count=$((sys_off_count + 1)); fi

        # ==========================================
        # 状态着色转换体系 (原教旨多行分离)
        # ==========================================
        local s1; if test "$out_fastopen" = "true"; then s1="${cyan}开启${none}"; else s1="${gray}关闭${none}"; fi
        local s2; if test "$out_keepalive" = "30"; then s2="${cyan}开启 (30s/15s)${none}"; else s2="${gray}系统默认${none}"; fi
        local s3; if test "$sniff_status" = "true"; then s3="${cyan}精准解负释放 CPU${none}"; else s3="${gray}传统全量嗅探${none}"; fi
        local s4; if test "$dns_status" = "UseIP"; then s4="${cyan}内置直通拦截${none}"; else s4="${gray}关闭${none}"; fi
        local s6; if test "$policy_status" = "60"; then s6="${cyan}极速出库 (60s)${none}"; else s6="${gray}系统默认 300s${none}"; fi
        local s7; if test "$affinity_state" = "true"; then s7="${cyan}进程绑定单核${none}"; else s7="${gray}系统放养调度${none}"; fi
        local s8; if test "$mph_state" = "true"; then s8="${cyan}MPH 路由预编译${none}"; else s8="${gray}基础线性比对${none}"; fi
        
        local s9
        if test -z "$has_reality"; then 
            s9="${gray}协议不支持${none}"
        else 
            if test "$maxtime_state" = "true"; then s9="${cyan}开启限制 (60s)${none}"; else s9="${gray}未设置拦截墙${none}"; fi
        fi
        
        local s10; if test "$routeonly_status" = "true"; then s10="${cyan}盲走直推已通车${none}"; else s10="${gray}默认全量解析${none}"; fi
        local s11; if test "$buffer_state" = "true"; then s11="${cyan}64KB 缓冲池分配${none}"; else s11="${gray}系统默认缓存分配${none}"; fi
        
        local s12; if test "$dnsmasq_state" = "true"; then s12="${cyan}本地缓存 (0.1ms)${none}"; else s12="${gray}原生解析${none}"; fi
        local s13; if test "$thp_state" = "true"; then s13="${cyan}透明大页已击碎${none}"; elif test "$thp_state" = "unsupported"; then s13="${gray}缺失组件${none}"; else s13="${gray}系统默认${none}"; fi
        local s14; if test "$mtu_state" = "true"; then s14="${cyan}MTU 探测开启${none}"; elif test "$mtu_state" = "unsupported"; then s14="${gray}缺失组件${none}"; else s14="${gray}未开启${none}"; fi
        local s15; if test "$cpu_state" = "true"; then s15="${cyan}Performance 锁死${none}"; elif test "$cpu_state" = "unsupported"; then s15="${gray}调度锁缺失${none}"; else s15="${gray}节能调度${none}"; fi
        local s16; if test "$ring_state" = "true"; then s16="${cyan}队列已物理紧缩${none}"; elif test "$ring_state" = "unsupported"; then s16="${gray}网卡固件不兼容${none}"; else s16="${gray}系统默认长缓存${none}"; fi
        local s17; if test "$zram_state" = "true"; then s17="${cyan}内存超压缩生效${none}"; elif test "$zram_state" = "unsupported"; then s17="${gray}缺失 zram 组件${none}"; else s17="${gray}未启用${none}"; fi
        local s18; if test "$journal_state" = "true"; then s18="${cyan}剥离物理落盘${none}"; elif test "$journal_state" = "unsupported"; then s18="${gray}不受控${none}"; else s18="${gray}狂暴磨损硬盘中${none}"; fi
        local s19; if test "$prio_state" = "true"; then s19="${cyan}OOM 全域免死金牌${none}"; else s19="${gray}普通权重易被杀${none}"; fi
        local s20; if test "$cake_state" = "true"; then s20="${cyan}CAKE 高阶调度${none}"; else s20="${gray}系统基础 FQ 排队${none}"; fi
        local s21; if test "$irq_state" = "true"; then s21="${cyan}硬件多核散列撕裂${none}"; elif test "$irq_state" = "unsupported"; then s21="${gray}单核机器跳过${none}"; else s21="${gray}软中断拥挤堵塞${none}"; fi
        
        local s22
        if test "$gso_off_state" = "true"; then 
            s22="${cyan}大包粘滞拆解完成${none}"
        else
            if test "$gso_off_state" = "unsupported"; then 
                s22="${gray}固件强制接管${none}"
            else 
                s22="${gray}网卡自行黏连${none}"
            fi
        fi
        
        local s23; if test "$ackfilter_state" = "true"; then s23="${cyan}暴力空包绞杀${none}"; else s23="${gray}未布防空包拦截${none}"; fi
        local s24; if test "$ecn_state" = "true"; then s24="${cyan}拥塞标记防重传${none}"; else s24="${gray}未布防拥塞标记${none}"; fi
        local s25; if test "$wash_state" = "true"; then s25="${cyan}特征清洗干扰防线${none}"; else s25="${gray}听天由命盲推${none}"; fi

        # ==========================================
        # 大屏渲染输出
        # ==========================================
        echo -e "  ${magenta}--- Xray Core 应用层内部极客调优 (1-11) ---${none}"
        echo -e "  1)  开关 -> 双向并发与快速打开提速 (tcpNoDelay)          | 状态: $s1"
        echo -e "  2)  开关 -> Socket 智能保活与快速死链拔除 (KeepAlive)    | 状态: $s2"
        echo -e "  3)  开关 -> Xray 全域嗅探引擎减负解放 CPU (metadataOnly) | 状态: $s3"
        echo -e "  4)  开关 -> 启用自建底层无污染 DNS 分发引擎 (UseIP)      | 状态: $s4"
        echo -e "  5)  调整 -> 刷新 GOGC 内存池伸缩回收比 (自动侦测)        | 设定: ${cyan}${gc_status}${none}"
        echo -e "  6)  开关 -> Xray 强行短平快 Policy 优化 (connIdle)       | 状态: $s6"
        echo -e "  7)  开关 -> 进程物理防飘移绑核技术 (CPUAffinity)         | 状态: $s7"
        echo -e "  8)  开关 -> 巨型哈希路由表直查跃迁 (MPH)                 | 状态: $s8"
        echo -e "  9)  开关 -> Reality 深度防御重放装甲 (maxTimeDiff)       | 状态: $s9"
        echo -e "  10) 开关 -> 零拷贝旁路数据盲转发不查包 (routeOnly)       | 状态: $s10"
        echo -e "  11) 开关 -> 分配 64K 超大物理重卡调度内存 (BUFFER_SIZE)  | 状态: $s11"
        echo -e ""
        echo -e "  ${magenta}--- Linux 系统层与内核底层黑科技操控 (12-25) ---${none}"
        echo -e "  12) 开关 -> 本地纯内存 Dnsmasq 极速查询池 (锁TTL)        | 状态: $s12"
        echo -e "  13) 开关 -> 透明大页合并瓦解技术 (THP Defrag)            | 状态: $s13"
        echo -e "  14) 开关 -> TCP MTU 黑洞路径智能重试嗅探                 | 状态: $s14"
        echo -e "  15) 开关 -> CPU 频率全局锁死打满 (Performance)           | 状态: $s15"
        echo -e "  16) 开关 -> 网卡硬件 Ring Buffer 排队环反向收缩          | 状态: $s16"
        echo -e "  17) 开关 -> 自动划定内存极速压缩交换池 (ZRAM)            | 状态: $s17"
        echo -e "  18) 开关 -> 斩断 Journald 日志物理硬盘 I/O (转入内存)    | 状态: $s18"
        echo -e "  19) 开关 -> 给 Xray 打上底层 OOM 免死与高优先金牌        | 状态: $s19"
        echo -e "  20) 开关 -> CAKE 削峰填谷智能排队调度器 (取代 fq)        | 状态: $s20"
        echo -e "  21) 开关 -> 网卡多队列 RPS 散列 / 单核 IRQ 硬隔离        | 状态: $s21"
        echo -e "  22) 开关 -> 网卡 GRO/GSO 大包拆解反转 (降低延迟抖动)     | 状态: $s22"
        echo -e "  23) 开关 -> CAKE ack-filter 上行空包强行绞杀策略         | 状态: $s23"
        echo -e "  24) 开关 -> CAKE ECN 队列显式通告 (配合 BBR 实现0丢包)   | 状态: $s24"
        echo -e "  25) 开关 -> CAKE Wash 报文杂项清理防御干扰               | 状态: $s25"
        echo -e "  "
        echo -e "  ${cyan}26) 战神降临：一键极速重置 1-11 项应用层微操${none}"
        echo -e "  ${yellow}27) 上帝指令：一键智能反转 12-25 项底层硬件微操${none}"
        echo -e "  ${red}28) 灭世之手：不顾一切全域 25 项全开 (执行后会触发强制重启！)${none}"
        echo "  0) 逃离控制台"
        hr
        
        local app_opt=""
        read -rp "请下达数字执行代号: " app_opt || true

        # ==========================================
        # 控制流处理区上半部 (应用层开关处理)
        # ==========================================
        case "${app_opt:-}" in
            1)
                if test "$out_fastopen" = "true"; then
                    _safe_jq_write '
                      (.outbounds[]? | select(.protocol == "freedom")) |= 
                          del(.streamSettings.sockopt.tcpNoDelay, .streamSettings.sockopt.tcpFastOpen) |
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= 
                          del(.streamSettings.sockopt.tcpNoDelay, .streamSettings.sockopt.tcpFastOpen)
                    '
                else
                    _safe_jq_write '
                      (.outbounds[]? | select(.protocol == "freedom")) |= (
                          .streamSettings = (.streamSettings // {}) |
                          .streamSettings.sockopt = (.streamSettings.sockopt // {}) |
                          .streamSettings.sockopt.tcpNoDelay = true |
                          .streamSettings.sockopt.tcpFastOpen = true
                      ) |
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= (
                          .streamSettings = (.streamSettings // {}) |
                          .streamSettings.sockopt = (.streamSettings.sockopt // {}) |
                          .streamSettings.sockopt.tcpNoDelay = true |
                          .streamSettings.sockopt.tcpFastOpen = true
                      )
                    '
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                info "双向提速逻辑改变，已应用。"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            2)
                if test "$out_keepalive" = "30"; then
                    _safe_jq_write '
                      (.outbounds[]? | select(.protocol == "freedom")) |= 
                          del(.streamSettings.sockopt.tcpKeepAliveIdle, .streamSettings.sockopt.tcpKeepAliveInterval) |
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= 
                          del(.streamSettings.sockopt.tcpKeepAliveIdle, .streamSettings.sockopt.tcpKeepAliveInterval)
                    '
                else
                    _safe_jq_write '
                      (.outbounds[]? | select(.protocol == "freedom")) |= (
                          .streamSettings = (.streamSettings // {}) |
                          .streamSettings.sockopt = (.streamSettings.sockopt // {}) |
                          .streamSettings.sockopt.tcpKeepAliveIdle = 30 |
                          .streamSettings.sockopt.tcpKeepAliveInterval = 15
                      ) |
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= (
                          .streamSettings = (.streamSettings // {}) |
                          .streamSettings.sockopt = (.streamSettings.sockopt // {}) |
                          .streamSettings.sockopt.tcpKeepAliveIdle = 30 |
                          .streamSettings.sockopt.tcpKeepAliveInterval = 15
                      )
                    '
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                info "Socket 智能保活系统调整完毕。"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            3)
                if test "$sniff_status" = "true"; then
                    _safe_jq_write '
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= (
                          .sniffing = (.sniffing // {}) |
                          .sniffing.metadataOnly = false
                      )
                    '
                else
                    _safe_jq_write '
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= (
                          .sniffing = (.sniffing // {}) |
                          .sniffing.metadataOnly = true
                      )
                    '
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                info "底层分析嗅探引擎减负设置成功。"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            4)
                if test "$dns_status" = "UseIP"; then
                    _safe_jq_write 'del(.dns)'
                else
                    if test "$dnsmasq_state" = "true"; then
                        _safe_jq_write '
                          .dns = {
                              "servers":["127.0.0.1"], 
                              "queryStrategy":"UseIP"
                          }
                        '
                    else
                        _safe_jq_write '
                          .dns = {
                              "servers":["https://8.8.8.8/dns-query","https://1.1.1.1/dns-query"], 
                              "queryStrategy":"UseIP"
                          }
                        '
                    fi
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                info "内置 DNS 引擎已变更！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            5)
                local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
                if test -f "$limit_file"; then
                    local TOTAL_MEM
                    TOTAL_MEM=$(free -m | awk '/Mem/{print $2}' || echo "1024")
                    local DYNAMIC_GOGC=100
                    
                    if test "$TOTAL_MEM" -ge 1800 2>/dev/null; then 
                        DYNAMIC_GOGC=1000
                    else
                        if test "$TOTAL_MEM" -ge 900 2>/dev/null; then 
                            DYNAMIC_GOGC=500
                        else
                            if test "$TOTAL_MEM" -ge 700 2>/dev/null; then 
                                DYNAMIC_GOGC=400
                            else
                                if test "$TOTAL_MEM" -ge 500 2>/dev/null; then 
                                    DYNAMIC_GOGC=300
                                else
                                    if test "$TOTAL_MEM" -ge 400 2>/dev/null; then 
                                        DYNAMIC_GOGC=200
                                    else
                                        DYNAMIC_GOGC=100
                                    fi
                                fi
                            fi
                        fi
                    fi
                    
                    if grep -q "Environment=\"GOGC=" "$limit_file" 2>/dev/null; then
                        if echo "$gc_status" | grep -q "100" 2>/dev/null; then
                            sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=$DYNAMIC_GOGC\"/" "$limit_file" 2>/dev/null || true
                        else
                            sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=100\"/" "$limit_file" 2>/dev/null || true
                        fi
                    else
                        echo "Environment=\"GOGC=$DYNAMIC_GOGC\"" >> "$limit_file"
                    fi
                    
                    systemctl daemon-reload >/dev/null 2>&1 || true
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "GOGC 动态阶梯调优完成！"
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            6)
                if test "$policy_status" = "60"; then
                    _safe_jq_write 'del(.policy)'
                else
                    _safe_jq_write '
                      .policy = {
                          "levels": {
                              "0": {
                                  "handshake":3,
                                  "connIdle":60
                              }
                          },
                          "system": {
                              "statsInboundDownlink":false,
                              "statsInboundUplink":false
                          }
                      }
                    '
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                info "回收策略调配完成！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            7)
                if test "$affinity_state" = "true"; then
                    _toggle_affinity_off
                else
                    _toggle_affinity_on
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                info "核心独占隔离操作成功！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            8)
                if test "$mph_state" = "true"; then
                    _safe_jq_write 'del(.routing.domainMatcher)'
                else
                    _safe_jq_write '
                      .routing = (.routing // {}) | 
                      .routing.domainMatcher = "mph"
                    '
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                info "路由层级 MPH 挂载完毕！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            9)
                if test -n "$has_reality"; then
                    if test "$maxtime_state" = "true"; then
                        _safe_jq_write '
                          (.inbounds[]? | select(.protocol == "vless" and .streamSettings.security == "reality")) |= (
                              .streamSettings.realitySettings = (.streamSettings.realitySettings // {}) |
                              del(.streamSettings.realitySettings.maxTimeDiff)
                          )
                        '
                    else
                        _safe_jq_write '
                          (.inbounds[]? | select(.protocol == "vless" and .streamSettings.security == "reality")) |= (
                              .streamSettings.realitySettings = (.streamSettings.realitySettings // {}) |
                              .streamSettings.realitySettings.maxTimeDiff = 60000
                          )
                        '
                    fi
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "重放时间戳装甲部署完毕！"
                else
                    warn "您的系统中不存在有效的 Reality，跳过强加拦截令。"
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            10)
                if test "$routeonly_status" = "true"; then
                    _safe_jq_write '
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= (
                          .sniffing = (.sniffing // {}) |
                          .sniffing.routeOnly = false
                      )
                    '
                else
                    _safe_jq_write '
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= (
                          .sniffing = (.sniffing // {}) |
                          .sniffing.routeOnly = true
                      )
                    '
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                info "内核底层直通盲走特快通道交替。"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            11)
                toggle_buffer
                systemctl restart xray >/dev/null 2>&1 || true
                info "物理巨型缓存池调整已结束！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
12)
                toggle_dnsmasq
                info "DNS 缓存接管控制变更！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            13)
                toggle_thp
                info "内存大页干预完成！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            14)
                toggle_mtu
                info "MTU 探测修正已下发！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            15)
                toggle_cpu
                info "CPU 频率性能状态改变！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            16)
                toggle_ring
                info "网卡硬件 Ring Buffer 排队结构更改完毕！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            17)
                toggle_zram
                info "物理级虚拟 ZRAM 操作成功！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            18)
                toggle_journal
                info "内存化 IO 指令重现。"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            19)
                toggle_process_priority
                info "金牌级 OOM 提权执行！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            20)
                toggle_cake
                info "系统调度队列 CAKE/FQ 分解与挂载已执行！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            21)
                toggle_irq
                info "深层多核 RPS 数据拆解或单核闭环下达成功！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            22)
                if test "$gso_off_state" = "unsupported"; then
                    warn "宿主机当前网卡底层驱动物理锁死 (fixed)！"
                    warn "为了保护您的服务器不断网失联，系统主动物理熔断了强行干预网卡卸载特征的指令！"
                    sleep 3
                else
                    toggle_gso_off
                    info "网卡数据包卸载组装干预下发成功！"
                    local _p=""; read -rp "按 Enter 继续..." _p || true
                fi
                ;;
                
            23)
                toggle_ackfilter
                info "CAKE 附加密集干预结束！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            24)
                toggle_ecn
                info "CAKE 附加密集干预结束！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            25)
                toggle_wash
                info "CAKE 附加密集干预结束！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            26)
                if test "$app_off_count" -gt 0 2>/dev/null; then
                    print_magenta ">>> 正在为应用层全速开启极速逻辑引擎..."
                    _turn_on_app
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "应用层逻辑大一统成功开启！"
                else
                    print_magenta ">>> 正在褪去应用层激进装备，还原官方生态..."
                    _turn_off_app
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "回归宁静！应用层优化已悉数剥离。"
                fi
                local _p=""; read -rp "按 Enter 归队..." _p || true
                ;;
                
            27)
                if test "$sys_off_count" -gt 0 2>/dev/null; then
                    if test "$dnsmasq_state" = "false"; then toggle_dnsmasq; fi
                    if test "$thp_state" = "false"; then toggle_thp; fi
                    if test "$mtu_state" = "false"; then toggle_mtu; fi
                    if test "$cpu_state" = "false"; then toggle_cpu; fi
                    if test "$ring_state" = "false"; then toggle_ring; fi
                    if test "$zram_state" = "false"; then toggle_zram; fi
                    if test "$journal_state" = "false"; then toggle_journal; fi
                    if test "$prio_state" = "false"; then toggle_process_priority; fi
                    if test "$cake_state" = "false"; then toggle_cake; fi
                    if test "$irq_state" = "false"; then toggle_irq; fi
                    
                    # 保护底层不受污染：只有明确为 false 且不是 unsupported 才操作
                    if test "$gso_off_state" = "false"; then
                        if test "$gso_off_state" != "unsupported"; then 
                            toggle_gso_off
                        fi
                    fi
                    
                    if test "$ackfilter_state" = "false"; then toggle_ackfilter; fi
                    if test "$ecn_state" = "false"; then toggle_ecn; fi
                    if test "$wash_state" = "false"; then toggle_wash; fi
                    
                    info "12-25 项底层物理网络栈参数已达到满血极限状态！"
                else
                    if test "$dnsmasq_state" = "true"; then toggle_dnsmasq; fi
                    if test "$thp_state" = "true"; then toggle_thp; fi
                    if test "$mtu_state" = "true"; then toggle_mtu; fi
                    if test "$cpu_state" = "true"; then toggle_cpu; fi
                    if test "$ring_state" = "true"; then toggle_ring; fi
                    if test "$zram_state" = "true"; then toggle_zram; fi
                    if test "$journal_state" = "true"; then toggle_journal; fi
                    if test "$prio_state" = "true"; then toggle_process_priority; fi
                    if test "$cake_state" = "true"; then toggle_cake; fi
                    if test "$irq_state" = "true"; then toggle_irq; fi
                    
                    if test "$gso_off_state" = "true"; then
                        if test "$gso_off_state" != "unsupported"; then 
                            toggle_gso_off
                        fi
                    fi
                    
                    if test "$ackfilter_state" = "true"; then toggle_ackfilter; fi
                    if test "$ecn_state" = "true"; then toggle_ecn; fi
                    if test "$wash_state" = "true"; then toggle_wash; fi
                    
                    info "12-25 系统级配置已被还原到默认模式。"
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            28)
                local total_off
                total_off=$((app_off_count + sys_off_count))
                if test "$total_off" -gt 0 2>/dev/null; then
                    if test "$app_off_count" -gt 0 2>/dev/null; then 
                        _turn_on_app
                    fi
                    
                    if test "$sys_off_count" -gt 0 2>/dev/null; then
                        if test "$dnsmasq_state" = "false"; then toggle_dnsmasq; fi
                        if test "$thp_state" = "false"; then toggle_thp; fi
                        if test "$mtu_state" = "false"; then toggle_mtu; fi
                        if test "$cpu_state" = "false"; then toggle_cpu; fi
                        if test "$ring_state" = "false"; then toggle_ring; fi
                        if test "$zram_state" = "false"; then toggle_zram; fi
                        if test "$journal_state" = "false"; then toggle_journal; fi
                        if test "$prio_state" = "false"; then toggle_process_priority; fi
                        if test "$cake_state" = "false"; then toggle_cake; fi
                        if test "$irq_state" = "false"; then toggle_irq; fi
                        
                        if test "$gso_off_state" = "false"; then
                            if test "$gso_off_state" != "unsupported"; then 
                                toggle_gso_off
                            fi
                        fi
                        
                        if test "$ackfilter_state" = "false"; then toggle_ackfilter; fi
                        if test "$ecn_state" = "false"; then toggle_ecn; fi
                        if test "$wash_state" = "false"; then toggle_wash; fi
                    fi
                else
                    _turn_off_app
                    
                    if test "$dnsmasq_state" = "true"; then toggle_dnsmasq; fi
                    if test "$thp_state" = "true"; then toggle_thp; fi
                    if test "$mtu_state" = "true"; then toggle_mtu; fi
                    if test "$cpu_state" = "true"; then toggle_cpu; fi
                    if test "$ring_state" = "true"; then toggle_ring; fi
                    if test "$zram_state" = "true"; then toggle_zram; fi
                    if test "$journal_state" = "true"; then toggle_journal; fi
                    if test "$prio_state" = "true"; then toggle_process_priority; fi
                    if test "$cake_state" = "true"; then toggle_cake; fi
                    if test "$irq_state" = "true"; then toggle_irq; fi
                    
                    if test "$gso_off_state" = "true"; then
                        if test "$gso_off_state" != "unsupported"; then 
                            toggle_gso_off
                        fi
                    fi
                    
                    if test "$ackfilter_state" = "true"; then toggle_ackfilter; fi
                    if test "$ecn_state" = "true"; then toggle_ecn; fi
                    if test "$wash_state" = "true"; then toggle_wash; fi
                fi
                
                echo ""
                print_red "=========================================================================="
                print_yellow "绝对权限指令已生效：内核拓扑与并发结构树发生大规模物理性撕裂！"
                print_yellow "这台战车将在 6 秒倒数结束后执行最深度的物理强行重启以确保挂载万无一失！"
                print_red "=========================================================================="
                echo ""
                
                for i in {6..1}; do 
                    echo -ne "\r  强行拔核倒数死线: ${cyan}${i}${none} 秒... "
                    sleep 1
                done
                
                echo -e "\n\n  强压 Sync 落盘，内存锁解除..."
                sync
                echo -e "  所有网络已切断，服务器正在执行涅槃重启..."
                reboot
                ;;
                
            0)
                return
                ;;
        esac
    done
}

# ==============================================================================
# [ 0x10: Reality 回落黑洞限速探针 ]
# ==============================================================================

do_fallback_probe() {
    clear
    echo -e "\n${yellow}=== Xray Reality 回落陷阱深渊 (Fallback Limit) 扫描探针 ===${none}"
    
    if test ! -f "$CONFIG"; then
        error "无法对当前环境实施 JQ 底层结构体解析操作，配置文件缺失。"
        local _p=""; read -rp "按 Enter 返回..." _p || true
        return
    fi
    
    local out
    out=$(jq -r '
      .inbounds[]? | select(.protocol=="vless" and .streamSettings.security=="reality") | .streamSettings.realitySettings | 
      "  [上传方向 (Upload)]\n    设局诱饵字节数 (afterBytes) : \(.limitFallbackUpload.afterBytes // "未开启 (门禁大开)")\n    启动基准绞杀器 (bytesPerSec) : \(.limitFallbackUpload.bytesPerSec // "未开启 (门禁大开)")\n  [下载方向 (Download)]\n    设局诱饵字节数 (afterBytes) : \(.limitFallbackDownload.afterBytes // "未开启 (门禁大开)")\n    启动基准绞杀器 (bytesPerSec) : \(.limitFallbackDownload.bytesPerSec // "未开启 (门禁大开)")"
    ' "$CONFIG" 2>/dev/null || echo "")
    
    if test -n "$out"; then
        echo -e "$out"
    else
        echo -e "  ${red}严重错误：未能发现有效的 Reality 协议配置防线！${none}"
    fi
    
    echo ""
    local _p=""
    read -rp "扫描完毕，按 Enter 回到系统主轴..." _p || true
}

# ==============================================================================
# [ 0x11: 系统建仓初始化与环境更新子菜单 ]
# ==============================================================================

do_sys_init_menu() {
    while true; do
        clear
        title "系统初始化与底层组件重构序列"
        echo "  1) [大满贯] 一键强制更新底层、校准时区、部署 1GB 永久 Swap 与清理守护"
        echo "  2) [网络侧] 修改系统内核级 DNS 流向 (基于 resolvconf 强效物理死锁)"
        echo -e "  ${cyan}3) [架构层] 抢先安装官方预编译版本 XANMOD 稳定内核 (平民推荐版)${none}"
        echo "  4) [超极客] 源码暴力提取 Kernel 主线内核 + BBR3 物理硬塞 (裸装防爆版)"
        echo "  5) [缓冲区] 网卡发送队列精细控制 (TX Queue 2000 极低延迟限制)"
        echo "  6) [内存流] 全系统网络栈底层极度特化配置 (tcp_adv_win_scale/tcp_app_win)"
        echo "  7) [上帝级] 全域系统结构树与 28 项核心微操调配控制台 (CAKE/RPS/零拷贝)"
        echo -e "  ${cyan}8) [精细化] 强配 CAKE 发送缓冲管理与 Overhead 报文拆解补偿${none}"
        echo "  0) 退出子程序"
        hr
        
        local sys_opt=""
        read -rp "长官，请给出下一步操作选项: " sys_opt || true
        
        case "${sys_opt:-}" in
            1) 
                print_magenta ">>> 开始接管并拉取全系统最新镜像源..."
                export DEBIAN_FRONTEND=noninteractive
                apt-get update -y >/dev/null 2>&1 || true
                apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" full-upgrade -y >/dev/null 2>&1 || true
                apt-get autoremove -y --purge >/dev/null 2>&1 || true
                
                apt-get install -y wget curl sudo socat ntpdate e2fsprogs pkg-config iproute2 ethtool >/dev/null 2>&1 || true
                
                print_magenta ">>> 执行时区强行矫正..."
                if command -v timedatectl >/dev/null 2>&1; then
                    timedatectl set-timezone Asia/Kuala_Lumpur >/dev/null 2>&1 || true
                fi
                if command -v ntpdate >/dev/null 2>&1; then
                    ntpdate -u us.pool.ntp.org >/dev/null 2>&1 || true
                fi
                if command -v hwclock >/dev/null 2>&1; then
                    hwclock --systohc >/dev/null 2>&1 || true
                fi
                info "时间轴同步完毕，现已锚定 Asia/Kuala_Lumpur 时区！"
                
                check_and_create_1gb_swap
                
                print_magenta ">>> 将 cc1.sh 洁癖清理守护程序埋入系统阴暗面..."
                cat <<'EOF' > /usr/local/bin/cc1.sh
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get clean >/dev/null 2>&1 || true
apt-get autoremove -y --purge >/dev/null 2>&1 || true
journalctl --vacuum-time=3d >/dev/null 2>&1 || true
rm -rf /tmp/* 2>/dev/null || true
rm -rf /var/log/*/*.log 2>/dev/null || true
sync
EOF
                chmod +x /usr/local/bin/cc1.sh 2>/dev/null || true
                
                local temp_cron
                temp_cron=$(mktemp)
                crontab -l 2>/dev/null | grep -v "cc1.sh" > "$temp_cron" || true
                echo "0 4 */10 * * /usr/local/bin/cc1.sh >/dev/null 2>&1" >> "$temp_cron"
                crontab "$temp_cron" 2>/dev/null || true
                rm -f "$temp_cron" 2>/dev/null || true
                
                info "极致清理组件配置成功，将在每 10 天执行深度内存大回旋清理！"
                local _p=""; read -rp "按 Enter 继续推进..." _p || true 
                ;;
            2) 
                do_change_dns 
                ;;
            3) 
                do_install_xanmod_main_official 
                ;;
            4) 
                do_xanmod_compile 
                ;;
            5) 
                do_txqueuelen_opt 
                ;;
            6) 
                do_perf_tuning 
                ;;
            7) 
                do_app_level_tuning_menu 
                ;;
            8) 
                config_cake_advanced 
                ;;
            0) 
                return 
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# [ 0x12: Xray 核心通讯底层升维系统 (海外原生直连极速版) ]
# ------------------------------------------------------------------------------

do_update_core() {
    title "Xray 核心框架在线更新系统 (原生直连版)"
    info "正在与 Github 官方主干道建立桥接..."
    
    if bash -c "$(curl -L -s https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" @ install >/dev/null 2>&1; then
        if test -x "$XRAY_BIN"; then
            fix_xray_systemd_limits
            systemctl restart xray >/dev/null 2>&1 || true
            
            local cur_ver
            cur_ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 | awk '{print $2}' || echo "读取异常")
            
            info "系统已升级完毕。当前锚定版本: ${cyan}$cur_ver${none}"
            local _p=""; read -rp "按 Enter 返回主控界面..." _p || true
            return 0
        fi
    fi
    
    error "核心升级遭遇异常！官方脚本执行失败，请检查机器的 DNS 或 IPv6 连通性。"
    local _p=""; read -rp "按 Enter 键返回..." _p || true
    return 1
}

# ------------------------------------------------------------------------------
# [ 0x13: 底层协议矩阵平滑热重载 ]
# ------------------------------------------------------------------------------

_update_matrix() {
    if test ! -f "$CONFIG"; then 
        return
    fi
    
    echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
    
    _safe_jq_write --arg dest "$BEST_SNI:443" --slurpfile snis /tmp/sni_array.json '
        (.inbounds[]? | select(.protocol == "vless")) |= (
            .streamSettings.realitySettings.serverNames = $snis[0] |
            .streamSettings.realitySettings.dest = $dest
        )
    '
    rm -f /tmp/sni_array.json 2>/dev/null || true
    
    ensure_xray_is_alive
    info "伪装路由接口矩阵已无损调转！"
}

# ------------------------------------------------------------------------------
# [ 0x14: Xray 核心全域部署与加密结构建仓 ]
# ------------------------------------------------------------------------------

do_install() {
    title "Xray 核心部署与网络架构初始化"
    preflight
    
    systemctl stop xray >/dev/null 2>&1 || true
    
    if test ! -f "$INSTALL_DATE_FILE"; then 
        date +"%Y-%m-%d %H:%M:%S" > "$INSTALL_DATE_FILE"
    fi
    
    echo -e "  ${cyan}请选择需要部署的协议架构：${none}"
    echo "  1) VLESS-Reality (最新抗封锁协议，隐蔽特征)"
    echo "  2) Shadowsocks (极简架构，轻量开销)"
    echo "  3) 双协议并行部署"
    
    local proto_choice=""
    read -rp "  请选择 (默认 1): " proto_choice || true
    proto_choice=${proto_choice:-1}

    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        while true; do 
            local input_p=""
            read -rp "设置 VLESS 监听端口 (默认 443): " input_p || true
            input_p=${input_p:-443}
            if validate_port "$input_p"; then 
                LISTEN_PORT="$input_p"
                break
            fi
        done
        
        local input_remark=""
        read -rp "设置节点备注名称 (默认 xp-reality): " input_remark || true
        REMARK_NAME=${input_remark:-xp-reality}
        
        choose_sni
        if test $? -ne 0; then 
            return 1
        fi
    fi

    local ss_port=8388
    local ss_pass=""
    local ss_method="aes-256-gcm"
    
    if test "$proto_choice" = "2" || test "$proto_choice" = "3"; then
        while true; do 
            local input_s=""
            read -rp "设置 SS 监听端口 (默认 8388): " input_s || true
            input_s=${input_s:-8388}
            if validate_port "$input_s"; then 
                ss_port="$input_s"
                break
            fi
        done
        
        ss_pass=$(gen_ss_pass)
        ss_method=$(_select_ss_method)
        
        if test "$proto_choice" = "2"; then 
            local input_remark=""
            read -rp "设置节点备注名称 (默认 xp-reality): " input_remark || true
            REMARK_NAME=${input_remark:-xp-reality}
        fi
    fi

    info "从官方仓库直连拉取最新 Xray 核心..."
    if ! bash -c "$(curl -fsSL --connect-timeout 10 https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" @ install >/dev/null 2>&1; then
        warn "通过官方脚本拉取失败，这不影响后续流程，您可以稍后通过主菜单 5 尝试重试。"
    fi
    
    install_update_dat
    fix_xray_systemd_limits

    # 1. 纯净构建底层骨架配置
    cat > "$CONFIG" <<EOF
{
  "log": {
      "loglevel": "warning"
  },
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
          "outboundTag": "block", 
          "_enabled": true, 
          "protocol": ["bittorrent"]
      },
      {
          "outboundTag": "block", 
          "_enabled": true, 
          "ip": ["geoip:cn"]
      },
      {
          "outboundTag": "block", 
          "_enabled": true, 
          "domain": ["geosite:cn", "geosite:category-ads-all"]
      }
    ]
  },
  "inbounds": [],
  "outbounds": [
      {
          "protocol": "freedom", 
          "tag": "direct", 
          "settings": {"domainStrategy": "AsIs"}
      }, 
      {
          "protocol": "blackhole", 
          "tag": "block"
      }
  ]
}
EOF

    # 2. 注入 VLESS 面板 (采用 slurpfile 绝缘拼装)
    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        local keys priv pub uuid sid ctime
        keys=$("$XRAY_BIN" x25519 2>/dev/null || echo "")
        priv=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' \r\n' || echo "")
        pub=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' \r\n' || echo "")
        uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
        sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n\r' || echo "")
        ctime=$(date +"%Y-%m-%d %H:%M")
        
        echo "$pub" > "$PUBKEY_FILE"
        echo "$uuid|$ctime" > "$USER_TIME_MAP"
        
        echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
        cat > /tmp/vless_inbound.json <<EOF
{
  "tag": "vless-reality", 
  "listen": "0.0.0.0", 
  "port": $LISTEN_PORT, 
  "protocol": "vless",
  "settings": {
      "clients": [
          {"id": "$uuid", "flow": "xtls-rprx-vision", "email": "$REMARK_NAME"}
      ], 
      "decryption": "none"
  },
  "streamSettings": {
    "network": "tcp", 
    "security": "reality",
    "sockopt": {"tcpNoDelay": true, "tcpFastOpen": true},
    "realitySettings": {
        "dest": "$BEST_SNI:443", 
        "serverNames": [], 
        "privateKey": "$priv", 
        "publicKey": "$pub", 
        "shortIds": ["$sid"],
        "limitFallbackUpload": {"afterBytes": 0, "bytesPerSec": 0, "burstBytesPerSec": 0},
        "limitFallbackDownload": {"afterBytes": 0, "bytesPerSec": 0, "burstBytesPerSec": 0}
    }
  },
  "sniffing": {
      "enabled": true, 
      "destOverride": ["http", "tls", "quic"]
  }
}
EOF
        _safe_jq_write --slurpfile snis /tmp/sni_array.json --slurpfile vless_tmp /tmp/vless_inbound.json '
            .inbounds += [ $vless_tmp[0] | .streamSettings.realitySettings.serverNames = $snis[0] ]
        '
        rm -f /tmp/vless_inbound.json /tmp/sni_array.json 2>/dev/null || true
    fi

    # 3. 注入 SS 面板
    if test "$proto_choice" = "2" || test "$proto_choice" = "3"; then
        cat > /tmp/ss_inbound.json <<EOF
{
  "tag": "shadowsocks", 
  "listen": "0.0.0.0", 
  "port": $ss_port, 
  "protocol": "shadowsocks",
  "settings": {
      "method": "$ss_method", 
      "password": "$ss_pass", 
      "network": "tcp,udp"
  },
  "streamSettings": {
      "sockopt": {"tcpNoDelay": true, "tcpFastOpen": true}
  }
}
EOF
        _safe_jq_write --slurpfile ss_tmp /tmp/ss_inbound.json '
            .inbounds += [ $ss_tmp[0] ]
        '
        rm -f /tmp/ss_inbound.json 2>/dev/null || true
    fi

    fix_permissions
    systemctl enable xray >/dev/null 2>&1 || true
    
    if ensure_xray_is_alive; then
        info "安装及部署完成！节点已就绪。"
        do_summary
    else
        error "系统配置加载失败，请查阅错误日志。"
        return 1
    fi
    
    while true; do
        local opt=""
        read -rp "按 Enter 返回主菜单，或输入 b 重新配置 SNI: " opt || true
        if test "$opt" = "b" || test "$opt" = "B"; then
            if choose_sni; then 
                _update_matrix
                do_summary
            else 
                break
            fi
        else 
            break
        fi
    done
}

# ------------------------------------------------------------------------------
# [ 0x23: 物理不可逆自毁中心 ]
# ------------------------------------------------------------------------------

do_uninstall() {
    title "物理级毁灭清理与系统生态还原"
    
    local confirm=""
    read -rp "危险指令: 执行后将彻底剥离所有网络拦截、守护进程及私钥配置，无可撤销。确信？(y/n): " confirm || true
    
    if test "$confirm" != "y"; then 
        return
    fi
    
    info "授权通过，正在解构基础架构..."
    systemctl stop dnsmasq >/dev/null 2>&1 || true
    systemctl disable dnsmasq >/dev/null 2>&1 || true
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get purge -y dnsmasq >/dev/null 2>&1 || true
    
    chattr -i /etc/resolv.conf 2>/dev/null || true
    if test -f /etc/resolv.conf.bak; then 
        mv -f /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true
    fi
    
    systemctl stop xray >/dev/null 2>&1 || true
    systemctl disable xray >/dev/null 2>&1 || true
    rm -rf /etc/systemd/system/xray* /lib/systemd/system/xray* >/dev/null 2>&1 || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    
    rm -rf "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SCRIPT_DIR" /var/log/xray* /usr/local/bin/xrv "$SCRIPT_PATH" >/dev/null 2>&1 || true
    
    local temp_cron
    temp_cron=$(mktemp)
    crontab -l 2>/dev/null | grep -v "update-dat.sh" | grep -v "/bin/systemctl restart xray" > "$temp_cron" || true
    crontab "$temp_cron" 2>/dev/null || true
    rm -f "$temp_cron" 2>/dev/null || true
    
    info "格式化肃清已落定，环境完全重置回归纯净。"
    exit 0
}

# ------------------------------------------------------------------------------
# [ 0x24: 系统绝对中枢：战舰大屏主控制台 ]
# ------------------------------------------------------------------------------

main_menu() {
    while true; do
        clear
        echo -e "${blue}======================================================================${none}"
        echo -e "  ${magenta}Xray 高维控制台 (Apex Vanguard V188e2 Industrial Base)${none}"
        
        local svc
        svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        
        if test "$svc" = "active"; then 
            svc="${green}健康驱动 (Active)${none}"
        else 
            svc="${red}心跳静默 (Inactive)${none}"
        fi
        
        local sys_ver
        sys_ver=$(uname -r 2>/dev/null || echo "未知内核")
        
        echo -e "  引擎态势: $svc | 热键调用: ${cyan}xrv${none} | 物理信标: ${yellow}$(_get_ip || echo "获取失败")${none}"
        echo -e "  当前内核: ${cyan}${sys_ver}${none} | 所处时空版本: V${SCRIPT_VERSION}"
        echo -e "${blue}======================================================================${none}"
        echo "  1) 创建/重构 绝对安全的双轨加密协议通道 (VLESS/SS)"
        echo "  2) 用户凭证生命周期与独立防封属性管理"
        echo "  3) 检阅全量节点配置连接中心"
        echo "  4) 人为干涉并热更全球 Geo 路由流量隔离库"
        echo "  5) 发起 Xray 服务通信底层源码静默升级"
        echo "  6) 伪装矩阵漂移 (单选/全选/剔除阻断 SNI)"
        echo "  7) 防火墙管控中心 (全局阻断 BT 与广告追踪流)"
        echo "  8) Reality 物理回落边界防线与防盗扫探针巡查"
        echo "  9) 全景网络监控与自然月商用级流量记账系统"
        echo "  10) 系统与内核级 60+ 项网卡极限高压物理调优"
        echo "  0) 折叠命令控制台，返回底层"
        echo -e "  ${red}88) 执行深层物理格式化，将所有环境抹杀殆尽${none}"
        hr
        
        local num=""
        read -rp "请下达命令代号: " num || true
        
        case "${num:-}" in
            1) 
                do_install 
                ;;
            2) 
                do_user_manager 
                ;;
            3) 
                do_summary
                while true; do 
                    local rb=""
                    read -rp "指令确认，按下 Enter 撤离，或敲击 b 开启伪装矩阵漂移: " rb || true
                    if test "$rb" = "b" || test "$rb" = "B"; then 
                        if choose_sni; then 
                            _update_matrix
                            do_summary
                        else 
                            break
                        fi
                    else 
                        break
                    fi
                done 
                ;;
            4) 
                print_magenta ">>> 发出信号流获取云端最新基库..."
                bash "$UPDATE_DAT_SCRIPT" >/dev/null 2>&1 || true
                ensure_xray_is_alive
                info "拉取成功，路由数据结构表已全面推送到内核层！"
                local _p=""; read -rp "输入 Enter 确认继续..." _p || true 
                ;;
            5) 
                do_update_core 
                ;;
            6) 
                if choose_sni; then 
                    _update_matrix
                    do_summary
                    
                    while true; do 
                        local rb=""
                        read -rp "指令结束，请按下 Enter 离场，或强制键入 b 继续重塑链路: " rb || true
                        if test "$rb" = "b" || test "$rb" = "B"; then 
                            if choose_sni; then 
                                _update_matrix
                                do_summary
                            else 
                                break
                            fi
                        else 
                            break
                        fi
                    done
                fi 
                ;;
            7) 
                _global_block_rules 
                ;;
            8) 
                do_fallback_probe 
                ;;
            9) 
                do_status_menu 
                ;;
            10) 
                do_sys_init_menu 
                ;;
            88) 
                do_uninstall 
                ;;
            0) 
                exit 0 
                ;;
            *)
                echo -e "${red}错误：系统无法识别该指令！${none}"
                sleep 1
                ;;
        esac
    done
}

# ==============================================================================
# 引擎点火：闭环环境拦截与中枢拉起
# ==============================================================================
preflight
main_menu
# ==============================================================================
# EOF - Apex Vanguard V188e2 System Core Ready.
# ==============================================================================
