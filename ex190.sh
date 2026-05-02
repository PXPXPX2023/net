#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: ex190.sh (Xray & System Advanced Management V190)
# 快捷方式: xrv
#
# 【V190 稳定融合版更新日志】
#   1. 风格重铸: 全面回归 ex100 稳健的专业日志风格，去除多余冗余词汇。
#   2. 编译修复: 在 make scripts 之前提前注入 CONFIG_X86_64_VERSION，根治 x86-64-v 编译错误。
#   3. 源盾升级: 引入完整的 apt-transport-https 与 GPG 规范机制，解决 Debian 源阻断。
#   4. 容错护盾: 全域核心配置采用 select(. != null) 等 jq 绝缘修改，拒绝隐式崩溃。
# ==============================================================================

if test -z "${BASH_VERSION:-}"; then
    echo "Error: 请使用 bash 执行本脚本: bash ex190.sh"
    exit 1
fi

if test "$EUID" -ne 0; then 
    echo -e "\033[31m[错误] 触及底层内核参数必须拥有最高权限，请使用 root 账户执行！\033[0m"
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then 
    echo -e "\033[31m[错误] 当前系统缺失 systemd 守护组件，环境异常！\033[0m"
    exit 1
fi

set -euo pipefail
IFS=$' \n\t'
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

readonly red='\033[31m'
readonly yellow='\033[33m'
readonly gray='\033[90m'
readonly green='\033[92m'
readonly blue='\033[94m'
readonly cyan='\033[96m'
readonly none='\033[0m'

readonly SCRIPT_VERSION="190"
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

GLOBAL_IP=""
SERVER_IP=""
REMARK_NAME="xp-reality"
BEST_SNI="www.microsoft.com"
SNI_JSON_ARRAY="\"www.microsoft.com\""
LISTEN_PORT=443

if ! mkdir -p "$CONFIG_DIR" "$DAT_DIR" "$SCRIPT_DIR" "$LOG_DIR" "$BACKUP_DIR" "$FLAGS_DIR" 2>/dev/null; then true; fi
if ! touch "$USER_SNI_MAP" "$USER_TIME_MAP" 2>/dev/null; then true; fi

print_red()    { echo -e "${red}$*${none}"; }
print_green()  { echo -e "${green}$*${none}"; }
print_yellow() { echo -e "${yellow}$*${none}"; }
print_cyan()   { echo -e "${cyan}$*${none}"; }

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

cleanup_temp_files() {
    rm -f /tmp/sni_array.json /tmp/vless_inbound.json /tmp/vless_final.json /tmp/ss_inbound.json /tmp/new_client.json /tmp/xray_users*.txt /tmp/install-release.sh /tmp/sni_test.* /tmp/check_x86-64_psabi.sh /tmp/current_cron 2>/dev/null || true
}

_err_handler() {
    local code=$1 line=$2 cmd=$3
    echo -e "\n${red}================== [ 异常捕获 ] ==================${none}" >&2
    echo -e "${yellow} >> 进程遇到异常断层，系统防线已触发安全中止！${none}" >&2
    echo -e "${cyan} >> 退出代码: ${none}${code}" >&2
    echo -e "${cyan} >> 错误行号: ${none}${line}" >&2
    echo -e "${cyan} >> 故障指令: ${none}${cmd}" >&2
    echo -e "${red}==================================================${none}\n" >&2
    log_error "PANIC TRIGGERED -> EXIT=$code LINE=$line CMD=[$cmd]"
    cleanup_temp_files
}

trap '_err_handler $? $LINENO "$BASH_COMMAND"' ERR
trap cleanup_temp_files EXIT

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
            GLOBAL_IP="获取失败"
        else
            GLOBAL_IP="$temp_ip"
        fi
    fi
    echo "$GLOBAL_IP"
}

validate_port() {
    local p="$1"
    if test -z "$p"; then return 1; fi
    if ! [[ "$p" =~ ^[0-9]+$ ]]; then return 1; fi
    if test "$p" -lt 1 2>/dev/null || test "$p" -gt 65535 2>/dev/null; then return 1; fi
    if ss -tuln 2>/dev/null | grep -q ":${p} "; then
        error "端口 $p 已被系统占用。"
        return 1
    fi
    return 0
}

gen_ss_pass() { head -c 24 /dev/urandom | base64 | tr -d '=/+\n\r' | head -c 24 || true; }

_select_ss_method() {
    echo -e "  ${cyan}选择 SS 加密方式：${none}" >&2
    echo "  1) aes-256-gcm (推荐)  2) chacha20-ietf-poly1305" >&2
    local mc=""
    read -rp "  编号 (默认 1): " mc >&2 || true
    if test "$mc" = "2"; then echo "chacha20-ietf-poly1305"; else echo "aes-256-gcm"; fi
}

detect_os() {
    if test -f /etc/os-release; then
        . /etc/os-release
        echo "${ID:-unknown}"
    else 
        echo "unknown"
    fi
}

pkg_install() {
    local list="$*"
    export DEBIAN_FRONTEND=noninteractive
    local os_id=$(detect_os)
    set +e
    if echo "$os_id" | grep -qiE "ubuntu|debian"; then
        apt-get update -y >/dev/null 2>&1 || true
        apt-get install -y $list >/dev/null 2>&1 || true
    elif echo "$os_id" | grep -qiE "centos|rhel|fedora|rocky|almalinux"; then
        yum makecache -y >/dev/null 2>&1 || true
        yum install -y $list >/dev/null 2>&1 || true
    fi
    set -e
}

preflight() {
    if test "$EUID" -ne 0; then die "此脚本需要 Root 权限执行。"; fi
    if ! command -v systemctl >/dev/null 2>&1; then die "系统环境缺失 systemctl 组件。"; fi

    local need="jq curl wget xxd unzip qrencode vnstat openssl coreutils sed e2fsprogs pkg-config iproute2 ethtool bc bison flex dwarves rsync python3 cpio apt-transport-https"
    local missing=""
    for p in $need; do
        if ! command -v "$p" >/dev/null 2>&1; then missing="$missing $p"; fi
    done
    
    if test -n "$missing"; then
        info "正在自动安装核心组件: $missing"
        pkg_install $missing
        systemctl start vnstat  >/dev/null 2>&1 || true
        systemctl enable vnstat >/dev/null 2>&1 || true
        systemctl start cron    >/dev/null 2>&1 || systemctl start crond >/dev/null 2>&1 || true
    fi

    if test -f "$SCRIPT_PATH"; then
        cp -f "$SCRIPT_PATH" "$SYMLINK" 2>/dev/null || true
        chmod +x "$SYMLINK" 2>/dev/null || true
        hash -r 2>/dev/null || true
    fi

    SERVER_IP=$(_get_ip)
    if test "$SERVER_IP" = "获取失败"; then warn "未能自动获取当前公网 IP 地址。"; fi
}

fix_xray_systemd_limits() {
    local override_dir="/etc/systemd/system/xray.service.d"
    mkdir -p "$override_dir" 2>/dev/null || true
    local limit_file="$override_dir/limits.conf"

    local current_nice="-20"
    local current_gogc="100"
    local current_oom="true"
    local current_affinity=""
    local current_gomaxprocs=""

    if test -f "$limit_file"; then
        if grep -q "^Nice=" "$limit_file" 2>/dev/null; then current_nice=$(awk -F'=' '/^Nice=/{print $2}' "$limit_file" | head -n 1 || echo "-20"); fi
        if grep -q "^Environment=\"GOGC=" "$limit_file" 2>/dev/null; then current_gogc=$(awk -F'=' '/^Environment="GOGC=/{print $3}' "$limit_file" | tr -d '"' | head -n 1 || echo "100"); fi
        if ! grep -q "^OOMScoreAdjust=" "$limit_file" 2>/dev/null; then current_oom="false"; fi
        if grep -q "^CPUAffinity=" "$limit_file" 2>/dev/null; then current_affinity=$(awk -F'=' '/^CPUAffinity=/{print $2}' "$limit_file" | head -n 1 || echo ""); fi
        if grep -q "^Environment=\"GOMAXPROCS=" "$limit_file" 2>/dev/null; then current_gomaxprocs=$(awk -F'=' '/^Environment="GOMAXPROCS=/{print $3}' "$limit_file" | tr -d '"' | head -n 1 || echo ""); fi
    fi

    local total_mem=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo "1024")
    local go_mem_limit=$(( total_mem * 85 / 100 ))

    cat > "$limit_file" << EOF
[Service]
LimitNOFILE=1048576
LimitNPROC=512000
LimitMEMLOCK=infinity
Nice=${current_nice}
Environment="GOMEMLIMIT=${go_mem_limit}MiB"
Environment="GOGC=${current_gogc}"
Restart=on-failure
RestartSec=10s
EOF

    if test "$current_oom" = "true"; then
        cat >> "$limit_file" << 'EOF'
OOMScoreAdjust=-500
IOSchedulingClass=realtime
IOSchedulingPriority=2
EOF
    fi
    if test -n "$current_affinity"; then echo "CPUAffinity=$current_affinity" >> "$limit_file"; fi
    if test -n "$current_gomaxprocs"; then echo "Environment=\"GOMAXPROCS=$current_gomaxprocs\"" >> "$limit_file"; fi
    systemctl daemon-reload >/dev/null 2>&1 || true
}

install_update_dat() {
    cat > "$UPDATE_DAT_SCRIPT" << 'UPDSH'
#!/usr/bin/env bash
XRAY_DAT_DIR="/usr/local/share/xray"
LOG_FILE="/var/log/xray/update-dat.log"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

dl() {
    local url="$1" out="$2"
    for i in 1 2 3; do
        if curl -fsSL --connect-timeout 10 --max-time 300 -o "$out.tmp" "$url"; then
            mv -f "$out.tmp" "$out"
            log "[INFO] 成功更新: $url"
            return 0
        fi
        log "[WARN] 更新失败重试 [$i/3]: $url"
        sleep 5
    done
    log "[ERROR] 规则库下载失败: $url"
    return 1
}

dl "https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"   "$XRAY_DAT_DIR/geoip.dat"
dl "https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat" "$XRAY_DAT_DIR/geosite.dat"
UPDSH
    chmod +x "$UPDATE_DAT_SCRIPT" 2>/dev/null || true
    
    local tmp_cron=$(mktemp /tmp/cron_XXXXXX) || return
    crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT" | grep -v "systemctl restart xray" > "$tmp_cron" || true
    echo "0 3 * * * $UPDATE_DAT_SCRIPT >/dev/null 2>&1" >> "$tmp_cron"
    echo "10 3 * * * /bin/systemctl restart xray >/dev/null 2>&1" >> "$tmp_cron"
    crontab "$tmp_cron" 2>/dev/null || true
    rm -f "$tmp_cron" 2>/dev/null || true
    info "规则库自动更新已配置: 每日 03:00 下载，03:10 重载 Xray 进程。"
}

do_change_dns() {
    title "配置系统级 DNS 锁定防漂移"
    local release=$(detect_os)
    if test ! -e '/usr/sbin/resolvconf' && test ! -e '/sbin/resolvconf'; then
        info "安装 resolvconf..."
        pkg_install resolvconf
    fi
    
    systemctl stop systemd-resolved 2>/dev/null || true
    systemctl disable systemd-resolved 2>/dev/null || true
    systemctl stop resolvconf.service > /dev/null 2>&1 || true
    systemctl start resolvconf.service > /dev/null 2>&1 || true
    systemctl enable resolvconf.service > /dev/null 2>&1 || true

    local nameserver=""
    local IPcheck="0"
    while test "$IPcheck" = "0"; do
        read -rp "请输入要锁定的 Nameserver IP (推荐 8.8.8.8): " nameserver || true
        if [[ $nameserver =~ ^([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]]; then
            IPcheck="1"
        else
            print_red "格式错误，请输入合法的 IPv4 地址。"
        fi
    done

    chattr -i /etc/resolv.conf 2>/dev/null || true
    rm -f /etc/resolv.conf 2>/dev/null || true
    if test -f /etc/resolv.conf.bak; then mv /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true; fi
    
    echo "nameserver $nameserver" > /etc/resolv.conf
    chattr +i /etc/resolv.conf 2>/dev/null || true
    
    mkdir -p /etc/resolvconf/resolv.conf.d 2>/dev/null || true
    echo "nameserver $nameserver" > /etc/resolvconf/resolv.conf.d/head 2>/dev/null || true
    systemctl restart resolvconf.service >/dev/null 2>&1 || true
    info "DNS 已强制锁定为：$nameserver"
}

fix_permissions() {
    if test -f "$CONFIG"; then chmod 644 "$CONFIG" 2>/dev/null || true; fi
    if test -d "$CONFIG_DIR"; then chmod 755 "$CONFIG_DIR" 2>/dev/null || true; fi
    chown -R root:root "$CONFIG_DIR" 2>/dev/null || true
    if test -f "$PUBKEY_FILE"; then chmod 600 "$PUBKEY_FILE" 2>/dev/null || true; fi
}

backup_config() {
    if test ! -f "$CONFIG"; then return 0; fi
    local ts=$(date +%Y%m%d_%H%M%S)
    cp -f "$CONFIG" "$BACKUP_DIR/config_${ts}.json" 2>/dev/null || true
    ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
}

restore_latest_backup() {
    local latest=$(ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | head -n 1 || echo "")
    if test -n "$latest"; then
        cp -f "$latest" "$CONFIG" 2>/dev/null || true
        fix_permissions
        systemctl restart xray >/dev/null 2>&1 || true
        warn "已自动回滚至上次正确的配置: $(basename "$latest")"
        return 0
    fi
    error "没有找到可用的配置备份。"
    return 1
}

verify_xray_config() {
    local target_config="$1"
    if test ! -f "$XRAY_BIN"; then return 0; fi
    local test_result
    set +e
    if ! test_result=$("$XRAY_BIN" run -test -config "$target_config" 2>&1); then
        test_result=$("$XRAY_BIN" -test -config "$target_config" 2>&1 || echo "核心测试失败")
    fi
    set -e
    if echo "$test_result" | grep -qi "Configuration OK"; then
        return 0
    else
        error "配置文件安全校验失败！"
        echo -e "${gray}$test_result${none}"
        return 1
    fi
}

_safe_jq_write() {
    backup_config
    local tmp_raw=$(mktemp) || return 1
    local tmp="${tmp_raw}.json"
    mv -f "$tmp_raw" "$tmp" 2>/dev/null || true
    
    set +e
    jq "$@" "$CONFIG" > "$tmp" 2>/dev/null
    local jq_res=$?
    set -e
    
    if test $jq_res -eq 0; then
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
            rm -f "$tmp" 2>/dev/null || true
            restore_latest_backup
            return 1
        fi
    else
        rm -f "$tmp" 2>/dev/null || true
        log_error "jq 修改失败，已放弃本次操作。"
        restore_latest_backup
        return 1
    fi
}

ensure_xray_is_alive() {
    info "正在重启 Xray 服务..."
    systemctl restart xray >/dev/null 2>&1 || true
    sleep 3
    if systemctl is-active --quiet xray; then
        info "Xray 服务运行正常。"
        return 0
    else
        error "Xray 服务启动失败，详情见日志："
        hr
        journalctl -u xray.service --no-pager -n 15 2>/dev/null | awk '{print "    " $0}' || true
        hr
        restore_latest_backup
        local _p=""; read -rp "按 Enter 继续..." _p || true
        return 1
    fi
}

run_sni_scanner() {
    title "连通性测速：130+ 实体 SNI 矩阵雷达扫描"
    print_yellow ">>> 扫描进行中... (随时按回车键可立即中止)\n"
    if ! mkdir -p "$CONFIG_DIR" 2>/dev/null; then true; fi
    
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
    )

    local sni_string=$(printf "%s\n" "${sni_list[@]}")
    if command -v shuf >/dev/null 2>&1; then
        sni_string=$(echo "$sni_string" | shuf)
    else
        sni_string=$(echo "$sni_string" | awk 'BEGIN{srand()} {print rand()"\t"$0}' | sort -n | cut -f2-)
    fi

    local tmp_sni=$(mktemp /tmp/sni_test.XXXXXX) || true

    for sni in $sni_string; do
        local key=""
        if read -t 0.1 -n 1 -s key 2>/dev/null; then
            echo -e "\n${yellow}用户主动中止探测，正在保存已有结果...${none}"
            break
        fi

        set +e
        local time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni" 2>/dev/null || echo "0")
        local ms=$(echo "$time_raw" | awk '{print int($1 * 1000)}' 2>/dev/null || echo "0")
        
        if test "${ms:-0}" -gt 0 2>/dev/null; then
            if curl -sI -m 2 --connect-timeout 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray"; then
                echo -e " ${gray}跳过${none} $sni (包含 Cloudflare CDN 特征)"
                continue
            fi
            
            local doh_res=$(curl -s --connect-timeout 2 "https://dns.alidns.com/resolve?name=$sni&type=1" 2>/dev/null || echo "")
            local dns_cn=""
            if test -n "$doh_res"; then
                dns_cn=$(echo "$doh_res" | jq -r '.Answer[]? | select(.type==1 or .type==5) | .data' 2>/dev/null | tail -n 1 || echo "")
            fi
            
            local status_cn=""
            local p_type="NORM"
            
            if test -z "$dns_cn" || test "$dns_cn" = "127.0.0.1" || test "$dns_cn" = "0.0.0.0" || test "$dns_cn" = "::1" || test "$dns_cn" = "null"; then
                status_cn="${red}国内墙阻断 (DNS投毒)${none}"
                p_type="BLOCK"
            else
                local loc=$(curl -s --connect-timeout 2 "https://ipinfo.io/$dns_cn/country" 2>/dev/null | tr -d ' \n' || echo "")
                if test "$loc" = "CN"; then
                    status_cn="${green}直通${none} | ${blue}中国境内解析${none}"
                    p_type="CN_CDN"
                else
                    status_cn="${green}直通${none} | ${cyan}海外原生节点${none}"
                    p_type="NORM"
                fi
            fi
            
            echo -e " ${green}存活${none} $sni : ${yellow}${ms}ms${none} | $status_cn"
            if test "$p_type" != "BLOCK"; then echo "$ms $sni $p_type" >> "$tmp_sni"; fi
        fi
        set -e
    done

    if test -s "$tmp_sni"; then
        grep " NORM$" "$tmp_sni" | sort -n | head -n 20 | awk '{print $2, $1}' > "$SNI_CACHE_FILE" || true
        local count=$(wc -l < "$SNI_CACHE_FILE" 2>/dev/null || echo "0")
        if test "${count:-0}" -lt 20 2>/dev/null; then
            local need_fill=$(( 20 - ${count:-0} ))
            grep "CN_CDN" "$tmp_sni" | sort -n | head -n "$need_fill" | awk '{print $2, $1}' >> "$SNI_CACHE_FILE" || true
        fi
    else
        print_red "探测列表全线超时，将默认使用保底配置。"
        echo "www.microsoft.com 999 NORM" > "$SNI_CACHE_FILE"
    fi
    rm -f "$tmp_sni" 2>/dev/null || true
}

verify_sni_strict() {
    local target="$1"
    print_magenta "\n>>> 正在针对目标 SNI [$target] 开启高维质检 (TLS 1.3 / ALPN / OCSP)..."
    set +e
    local out=$(echo "Q" | timeout 5 openssl s_client -connect "$target:443" -alpn h2 -tls1_3 -status 2>&1 || echo "")
    set -e
    local pass=1
    if ! echo "$out" | grep -qi "TLSv1.3"; then print_red " [✗] 质检不达标: 目标服务器未启用 TLS v1.3"; pass=0; fi
    if ! echo "$out" | grep -qiE "ALPN, server accepted to use h2|ALPN.*h2"; then print_red " [✗] 质检不达标: 目标不支持 ALPN h2"; pass=0; fi
    if ! echo "$out" | grep -qi "OCSP response:"; then print_red " [✗] 质检不达标: 目标未装订 OCSP Stapling 状态"; pass=0; fi
    if test "$pass" -eq 0; then warn "该域名指纹不全，强制使用可能导致 Reality 被阻断！"; return 1; else info "质检通过：各项协议特征合规。"; return 0; fi
}

choose_sni() {
    while true; do
        if test -f "$SNI_CACHE_FILE"; then
            echo -e "\n  ${cyan}【本地连通性测速结果 - Top 20】${none}"
            local idx=1
            while read -r s t p; do
                echo -e "  $idx) $s (响应延迟: ${cyan}${t}ms${none})"
                idx=$((idx + 1))
            done < "$SNI_CACHE_FILE"
            
            echo -e "  ${yellow}r) 重新运行全面探测扫描${none}"
            echo "  m) 启用多选模式 (输入多个序号，构建多域名矩阵)"
            echo "  0) 手动输入自定义私有域名"
            echo "  q) 取消并返回上级菜单"
            
            local sel=""
            read -rp "  请输入对应的编号 (默认 1): " sel || true
            sel=${sel:-1}
            
            if test "$sel" = "q" || test "$sel" = "Q"; then return 1; fi
            if test "$sel" = "r" || test "$sel" = "R"; then run_sni_scanner; continue; fi
            if test "$sel" = "m" || test "$sel" = "M"; then
                local m_sel=""
                read -rp "请输入所需序号 (空格分隔, 如 1 3 5，或输入 all 选定全部): " m_sel || true
                local arr=()
                if test "$m_sel" = "all"; then
                    while read -r p_sni p_rest; do
                        if test -n "$p_sni"; then arr+=("$p_sni"); fi
                    done < "$SNI_CACHE_FILE"
                else
                    for i in $m_sel; do
                        local picked=$(awk "NR==$i {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "")
                        if test -n "$picked"; then arr+=("$picked"); fi
                    done
                fi
                if test "${#arr[@]}" -eq 0; then error "选择无效，未能解析到目标 SNI，请重试。"; continue; fi
                BEST_SNI="${arr[0]}"
                local jq_args=()
                for s in "${arr[@]}"; do jq_args+=("\"$s\""); done
                SNI_JSON_ARRAY=$(IFS=,; echo "${jq_args[*]}")
            else
                if test "$sel" = "0"; then 
                    local d=""
                    read -rp "请输入自定义的 SNI 域名: " d || true
                    BEST_SNI=${d:-www.microsoft.com}
                    SNI_JSON_ARRAY="\"$BEST_SNI\""
                else
                    local picked=""
                    if [[ "$sel" =~ ^[0-9]+$ ]]; then picked=$(awk "NR==$sel {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo ""); fi
                    if test -n "$picked"; then
                        BEST_SNI="$picked"
                    else
                        error "输入序号有误，默认选择第一号测速节点。"
                        BEST_SNI=$(awk "NR==1 {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "www.microsoft.com")
                    fi
                    SNI_JSON_ARRAY="\"$BEST_SNI\""
                fi
            fi

            if verify_sni_strict "$BEST_SNI"; then
                print_green ">>> 质检完毕，目标域名特征完好！"
                break
            else
                print_yellow ">>> 危险预警：该域名不满足各项高级 TLS 特征，强行使用会极大增加封禁概率。"
                local force_use=""
                read -rp "是否无视警告，强制绑定该域名？(y/n): " force_use || true
                if [[ "$force_use" =~ ^[yY]$ ]]; then warn "您已授权强行越过质检防线。"; break; else continue; fi
            fi
        else
            warn "未能发现测速缓存快照，正在重新初始化探测引擎..."
            run_sni_scanner
        fi
    done
    return 0
}
# ------------------------------------------------------------------------------
# [ 0x13: 商业级流量统计与运行雷达中心 ]
# ------------------------------------------------------------------------------

do_status_menu() {
    while true; do
        clear
        title "系统监控与网络流量审计"
        echo "  1) 查看系统底层进程状态"
        echo "  2) 审查网络入口与路由解析配置"
        echo "  3) 调取网卡全域流量核算总账 (vnstat)"
        echo "  4) 追踪实时网络连接与独立访问者溯源"
        echo "  5) 调整系统内核级进程抢占权重 (Nice 值)"
        echo "  6) 审查应用运行事件日志"
        echo "  7) 审查系统错误异常日志"
        echo "  8) 自动化灾难备份与配置恢复"
        echo "  0) 返回主菜单"
        hr
        
        local s=""
        read -rp "请指定管理指令: " s || true
        
        case "${s:-}" in
            1) 
                systemctl status xray --no-pager || true
                local _p=""; read -rp "按 Enter 继续..." _p || true 
                ;;
            2) 
                echo -e "\n  对外公网 IP: ${green}$SERVER_IP${none}\n  系统 DNS 路由: "
                grep "^nameserver" /etc/resolv.conf 2>/dev/null || echo "    获取失败"
                echo -e "  系统监听端口池:"
                ss -tlnp 2>/dev/null | grep xray || echo "    未检测到监听服务"
                local _p=""; read -rp "按 Enter 继续..." _p || true 
                ;;
            3) 
                if ! command -v vnstat >/dev/null 2>&1; then 
                    warn "您的服务器尚未安装 vnstat 监控工具。"
                    local _p=""; read -rp "按 Enter 继续..." _p || true
                    continue
                fi
                
                clear
                title "商用级网络流量审计系统 (vnstat)"
                
                local m_day
                m_day=$(grep -E "^[[:space:]]*MonthRotate" /etc/vnstat.conf 2>/dev/null | awk '{print $2}' | head -n 1 | tr -d '\r\n')
                if test -z "$m_day"; then
                    m_day="1 (系统默认)"
                fi
                
                echo -e "  当前每月流量结算清零日: ${cyan}每月 $m_day 号${none}"
                hr
                (vnstat -m 3 2>/dev/null || vnstat -m 2>/dev/null || true) | sed -e 's/estimated/预估消耗/ig' -e 's/rx/接收流量/ig' -e 's/tx/发送流量/ig' -e 's/total/全域吞吐/ig' -e 's/daily/按日/ig' -e 's/monthly/按自然月/ig'
                hr
                
                echo "  1) 手动指定每月的流量计费清零日期 (1-31)"
                echo "  2) 查询指定历史年月的日跑量详单 (如: 2026-04)"
                echo "  0) 退出流量中心"
                
                local vn_opt=""
                read -rp "  执行系统任务: " vn_opt || true
                
                if test "$vn_opt" = "1"; then
                    local d_day=""
                    read -rp "输入物理结算日标 (1-31): " d_day || true
                    if [[ "$d_day" =~ ^[0-9]+$ ]]; then
                        if test "$d_day" -ge 1 2>/dev/null; then
                            if test "$d_day" -le 31 2>/dev/null; then
                                sed -i '/^[#[:space:]]*MonthRotate/d' /etc/vnstat.conf 2>/dev/null || true
                                echo "MonthRotate $d_day" >> /etc/vnstat.conf
                                systemctl restart vnstat 2>/dev/null || true
                                info "底层配置已更新，流量账单将在每月 $d_day 号截断重组。"
                            else
                                error "非法的输入格式。"
                            fi
                        else
                            error "非法的输入格式。"
                        fi
                    else
                        error "非法的输入格式。"
                    fi
                    local _p=""; read -rp "按 Enter 返回..." _p || true 
                elif test "$vn_opt" = "2"; then
                    local d_month=""
                    read -rp "请输入要穿梭的历史锚点 (格式如 $(date +%Y-%m)，不填默认近 30 天): " d_month || true
                    if test -z "$d_month"; then 
                        vnstat -d 2>/dev/null | sed -e 's/estimated/预估消耗/ig' -e 's/rx/接收流量/ig' -e 's/tx/发送流量/ig' -e 's/total/全域吞吐/ig' -e 's/daily/按日/ig' -e 's/monthly/按自然月/ig' || true
                    else 
                        vnstat -d 2>/dev/null | grep -iE "($d_month| day |estimated|--)" | sed -e 's/estimated/预估消耗/ig' -e 's/rx/接收流量/ig' -e 's/tx/发送流量/ig' -e 's/total/全域吞吐/ig' -e 's/daily/按日/ig' -e 's/monthly/按自然月/ig' || true
                    fi
                    local _p=""; read -rp "按 Enter 返回..." _p || true 
                fi
                ;;
                
            4)
                while true; do
                    clear
                    title "实时公网握手与探源扫描阵列"
                    local x_pids
                    x_pids=$(pidof xray 2>/dev/null | xargs | tr -s ' ' '|' || echo "")
                    
                    if test -n "$x_pids"; then
                        echo -e "  ${cyan}【并发时空隧道分布】${none}"
                        ss -ntupa 2>/dev/null | grep -E "pid=($x_pids)[,)]" | awk '{print $1"_"$2}' | sort | uniq -c | sort -nr | awk '{printf "    通道句柄: %-15s : 吞吐活跃数 %s\n", $2, $1}' || echo "    系统无连接"
                        
                        echo -e "\n  ${cyan}【外网独立来源地址 (TOP 10 排名)】${none}"
                        local ips
                        ips=$(ss -ntupa 2>/dev/null | grep -E "pid=($x_pids)[,)]" | grep -vE "LISTEN|UNCONN" | awk '{print $6}' | sed -E 's/:[0-9]+$//' | tr -d '[]' | grep -vE "^127\.0\.0\.1$|^0\.0\.0\.0$|^::$|^\*$|^::ffff:127\.0\.0\.1$" || echo "")
                        
                        if test -n "$ips"; then
                            echo "$ips" | sort | uniq -c | sort -nr | head -n 10 | awk '{printf "    访客 IP: %-18s (并行发包: %s 次)\n", $2, $1}'
                            local total_ips
                            total_ips=$(echo "$ips" | sort | uniq | wc -l)
                            echo -e "\n  净化后系统绝对独立访客总量: ${yellow}${total_ips}${none}"
                        else 
                            echo -e "    ${gray}探针未捕获任何外部实体。${none}"
                        fi
                    else 
                        error "核心雷达脱机，进程可能已消亡。"
                    fi
                    
                    echo -e "\n  ${green}追踪网运转中... 键入 [ q ] 强行切断并返回${none}"
                    local cmd=""
                    if read -t 2 -n 1 -s cmd 2>/dev/null; then
                        if test "$cmd" = "q" || test "$cmd" = "Q" || test "$cmd" = $'\e'; then 
                            break
                        fi
                    fi
                done
                ;;
                
            5)
                while true; do
                    clear
                    title "调整内核级防抢占优先级"
                    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
                    local current_nice="-20"
                    
                    if test -f "$limit_file"; then 
                        if grep -q "^Nice=" "$limit_file" 2>/dev/null; then 
                            current_nice=$(awk -F'=' '/^Nice=/ {print $2}' "$limit_file" | head -n 1 || echo "-20")
                        fi
                    fi
                    
                    echo -e "  当前底层霸道提权分配值: ${cyan}${current_nice}${none} (合规域: -20 到 -10 之间)"
                    hr
                    
                    local new_nice=""
                    read -rp "  键入新的提权参数 (q 撤退): " new_nice || true
                    
                    if test "$new_nice" = "q" || test "$new_nice" = "Q"; then 
                        break
                    fi
                    
                    if [[ "$new_nice" =~ ^-[1-2][0-9]$ ]]; then
                        if test "$new_nice" -ge -20 2>/dev/null; then
                            if test "$new_nice" -le -10 2>/dev/null; then
                                sed -i "s/^Nice=.*/Nice=$new_nice/" "$limit_file" 2>/dev/null || true
                                systemctl daemon-reload >/dev/null 2>&1 || true
                                info "指令注入，5 秒后重启进程锁定新值..."
                                sleep 5
                                systemctl restart xray >/dev/null 2>&1 || true
                                info "底层配置已落实。"
                                local _p=""; read -rp "按 Enter 返回..." _p || true
                                break
                            else
                                error "跨越了合法的数字边界！"
                                sleep 2
                            fi
                        else
                            error "跨越了合法的数字边界！"
                            sleep 2
                        fi
                    else 
                        error "跨越了合法的数字边界！"
                        sleep 2
                    fi
                done
                ;;
                
            6) 
                clear; title "程序运行轨迹日志"; tail -n 50 "$LOG_DIR/xray.log" 2>/dev/null || echo "  暂无留档记录。"; local _p=""; read -rp "按 Enter 退出..." _p || true 
                ;;
                
            7) 
                clear; title "系统错误警告日志"; tail -n 30 "$LOG_DIR/error.log" 2>/dev/null || echo "  服务运行正常，无报错产生。"; local _p=""; read -rp "按 Enter 退出..." _p || true 
                ;;
                
            8)
                clear; title "自动化配置备份与灾难恢复中心"
                ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null || echo "系统内空空如也"
                echo -e "\n  r) 执行逆转，强行覆盖为最近的一份无损快照\n  c) 就地锁定当前参数，压出一份冷备\n  0) 返回"
                
                local bopt=""
                read -rp "指定操作: " bopt || true
                
                if test "$bopt" = "r" || test "$bopt" = "R"; then 
                    restore_latest_backup
                fi
                
                if test "$bopt" = "c" || test "$bopt" = "C"; then 
                    backup_config
                    info "快照已入库封存。"
                    local _p=""; read -rp "Enter..." _p || true
                fi
                ;;
                
            0) 
                return 
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# [ 0x06: Swap 虚拟内存防爆模块 ]
# ------------------------------------------------------------------------------

check_and_create_1gb_swap() {
    title "检查物理 Swap 分区状态"
    local SWAP_FILE="/swapfile"
    local CURRENT_SWAP=""
    
    set +e
    CURRENT_SWAP=$(swapon --show=NAME,KBYTES --noheadings 2>/dev/null | grep "$SWAP_FILE" | awk '{print $2}' || echo "")
    set -e
    
    if test -n "$CURRENT_SWAP" && test "$CURRENT_SWAP" -ge 1000000 2>/dev/null; then
        info "系统已配置足量的 Swap 分区 (≥1GB)。"
        return
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
# 【终极核心修复 1】：预编译官方 XANMOD 部署模块 (破壁降级引擎与 GPG 安全防爆)
# ------------------------------------------------------------------------------

do_install_xanmod_main_official() {
    title "系统飞升：安装预编译 XANMOD 内核 (纯净官方源保护)"
    
    local arch=$(uname -m 2>/dev/null || echo "")
    if test "$arch" != "x86_64"; then
        error "系统架构不匹配：仅支持 x86_64！"
        local _p=""; read -rp "按 Enter 返回..." _p || true
        return 1
    fi
    
    if test ! -f /etc/debian_version; then
        error "系统发行版排斥：官方预编译 Xanmod 仓库目前仅兼容 Debian / Ubuntu 系！"
        local _p=""; read -rp "按 Enter 返回..." _p || true
        return 1
    fi

    info "正在拉取智能探针，检测本地 CPU 硬件微架构支持级别..."
    local cpu_level_script="/tmp/check_x86-64_psabi.sh"
    
    set +e
    if ! wget -qO "$cpu_level_script" https://dl.xanmod.org/check_x86-64_psabi.sh 2>/dev/null; then
        warn "探针脚本下载遇到网络波动，将跳过精准检测。"
    fi
    
    local cpu_level=""
    if test -f "$cpu_level_script"; then
        chmod +x "$cpu_level_script" 2>/dev/null || true
        cpu_level=$(awk -f "$cpu_level_script" 2>/dev/null | grep -oE 'x86-64-v[1-4]' | grep -oE '[1-4]' | tail -n 1 || echo "")
        rm -f "$cpu_level_script" 2>/dev/null || true
    fi
    set -e
    
    if test -z "$cpu_level"; then
        cpu_level=1
        warn "未能精确检测 CPU 微架构级别，将默认降级使用系统最宽容的 v1 兼容版本。"
    else
        info "评估完成，当前 CPU 硬件完美支持的微架构最高级别为: v${cpu_level}"
    fi

    info "正在配置 Xanmod 官方最高优 APT 仓库与防伪 Keyring..."
    export DEBIAN_FRONTEND=noninteractive
    
    set +e
    # 强制拉取底层安全证书与验证链，防止 Debian 11/12 因证书未授权拦截 APT 源
    apt-get update -y >/dev/null 2>&1
    apt-get install -y gnupg gnupg2 gnupg1 curl sudo wget e2fsprogs ca-certificates lsb-release apt-transport-https >/dev/null 2>&1

    # 深度重构：彻底清除旧版无效或冲突的源
    mkdir -p /usr/share/keyrings 2>/dev/null
    rm -f /etc/apt/trusted.gpg.d/xanmod-*.gpg /etc/apt/sources.list.d/xanmod-*.list /etc/apt/sources.list.d/xanmod-*.sources 2>/dev/null
    sed -i '/deb.xanmod.org/d' /etc/apt/sources.list 2>/dev/null
    
    # 采用最新官方标准的 gpg.key，并强制采用 ASCII-armored 解码存入 keyrings
    if ! curl -fsSL https://dl.xanmod.org/gpg.key | gpg --dearmor --yes -o /usr/share/keyrings/xanmod-archive-keyring.gpg 2>/dev/null; then
        error "从远端获取 GPG 密钥链发生错误，官方源可能受限！"
        set -e; return 1
    fi
    
    echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list >/dev/null

    info "正在触发 APT 智能降级寻址阵列 (容错同步中)..."
    
    # 开启容错：即使源有 warning 也不允许中断
    apt-get update -y || warn "APT 源刷新遇到轻微异常，尝试继续向后寻址..."
    
    local pkg_name=""
    local installed=false
    
    # 【智能原生降级引擎】：从 CPU 最高级开始探测并强制实弹安装，失败则降级
    for ((v=$cpu_level; v>=1; v--)); do
        local try_pkg="linux-xanmod-x64v${v}"
        info "正在尝试拉取并部署包: $try_pkg ..."
        if apt-get install -y "$try_pkg"; then
            pkg_name="$try_pkg"
            installed=true
            break
        fi
        warn "源内未命中或阻断 $try_pkg，触发自动降级探测 v$((v-1)) ..."
    done
    
    # 如果标准架构全部失联，启动备用模糊雷达
    if [ "$installed" = "false" ]; then
        warn "标准架构包名全线脱靶，正在唤醒 APT 模糊寻址雷达..."
        local alt_pkg=$(apt-cache search "linux-image-.*xanmod" | grep -vE "dbg|headers" | awk '{print $1}' | sort -V | tail -n 1 || echo "")
        if [ -n "$alt_pkg" ]; then
            info "成功修正坐标！锁定兼容内核包: $alt_pkg"
            if apt-get install -y "$alt_pkg"; then
                pkg_name="$alt_pkg"
                installed=true
            fi
        fi
    fi
    
    if [ "$installed" = "false" ]; then
        error "保底寻址宣告失败！当前系统源无法解析到任何合法的 Xanmod 预编译包。"
        error "这通常意味着您的系统(如 Debian 10)可能存在源冲突或已被官方彻底抛弃。"
        local _p=""; read -rp "按 Enter 继续..." _p || true
        set -e; return 1
    fi
    set -e

    info "预编译核心注入成功，正在重载 GRUB 引导..."
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
# 【终极核心修复 2】：源码暴力编译 Xanmod (物理歼灭 Makefile Bug)
# ------------------------------------------------------------------------------

do_xanmod_compile() {
    title "系统飞升：源码编译 XANMOD 官方内核 + BBR3 (极客锻造模式)"
    
    warn "警告: 这是一个极其漫长的过程 (30-60分钟)，低配机极易引发死机断连！强烈建议优先使用预编译版。"
    local confirm=""
    read -rp "确定要执意开始源码编译吗？(y/n): " confirm || true
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then return; fi

    title "=== [1/8] 开始执行深度系统清理与空间释放 ==="
    export DEBIAN_FRONTEND=noninteractive
    apt-get clean >/dev/null 2>&1 || true
    apt-get autoremove -y --purge >/dev/null 2>&1 || true
    journalctl --vacuum-time=1d >/dev/null 2>&1 || true
    rm -rf /var/log/*.log /tmp/* /usr/src/linux* /usr/src/xanmod* /compile/* 2>/dev/null || true
    sync

    local inode_use=$(df -i / 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%' || echo "0")
    if test "$inode_use" -gt 90 2>/dev/null; then
        warn "检测到 inode 节点使用率过高，执行紧急释放缓存..."
        rm -rf /var/cache/* 2>/dev/null || true
    fi

    title "=== [2/8] 检查并配置 1GB 编译缓冲交换区 (Swap) ==="
    check_and_create_1gb_swap

    title "=== [3/8] 拉取底层 GCC 编译套件与开发依赖库 ==="
    local root_free=$(df -m / 2>/dev/null | awk 'NR==2{print $4}' || echo "0")
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
    # 强制补全 liblz4-tool 以修复 LZ4 压缩工具丢失引起的打包断层
    apt-get install -y build-essential bc bison flex libssl-dev libelf-dev libncurses-dev zstd lz4 liblz4-tool lzma bzip2 git wget curl xz-utils ethtool numactl make pkg-config dwarves rsync python3 libdw-dev cpio >/dev/null 2>&1 || true

    local CPU=$(nproc 2>/dev/null || echo 1)
    local RAM=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo 1024)
    local THREADS=1
    if test "$RAM" -ge 2000 2>/dev/null; then THREADS=$CPU; elif test "$RAM" -ge 1000 2>/dev/null; then THREADS=2; fi

    title "=== [4/8] 探测并拉取 Xanmod 官方最新稳定版源码 ==="
    if ! cd "$BUILD_DIR"; then die "权限异常：系统拒绝切入工作区 $BUILD_DIR。"; fi
    
    info "正在连接 GitLab 获取 Xanmod 最新分支..."
    set +e
    local XANMOD_TAG=$(curl -sL "https://gitlab.com/api/v4/projects/xanmod%2Flinux/repository/tags" 2>/dev/null | jq -r '.[0].name' | grep -v "rc" | head -n 1 || echo "")
    if test -z "$XANMOD_TAG" || test "$XANMOD_TAG" = "null"; then 
        warn "动态寻址失败，强行锁定高可用备用版本 6.10.3-xanmod1..."
        XANMOD_TAG="6.10.3-xanmod1"
    fi
    set -e
    
    local KERNEL_URL="https://gitlab.com/xanmod/linux/-/archive/${XANMOD_TAG}/linux-${XANMOD_TAG}.tar.gz"
    local KERNEL_FILE="xanmod-${XANMOD_TAG}.tar.gz"
    
    info "建立直连信道，开始拉取 Xanmod 源码包: $KERNEL_FILE"
    wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"

    set +o pipefail
    if ! tar -tzf "$KERNEL_FILE" >/dev/null 2>&1; then
        warn "初次获取源码包断层，触发重试..."
        rm -f "$KERNEL_FILE" 2>/dev/null || true
        wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"
        if ! tar -tzf "$KERNEL_FILE" >/dev/null 2>&1; then
            error "下载解压连续失败，编译强制中止。"
            set -e; return 1
        fi
    fi
    set -o pipefail

    info "执行 GZ 极致解压，释放 Xanmod 源码..."
    tar -xzf "$KERNEL_FILE"
    
    local KERNEL_DIR=$(tar -tzf "$KERNEL_FILE" | head -1 | cut -f1 -d"/")
    if ! cd "$KERNEL_DIR"; then die "无法切入解压后的源码目录: $KERNEL_DIR。"; fi

    title "=== [5/8] 注入底层驱动与绝缘防爆参数 ==="
    set +e 
    if test -f "/boot/config-$(uname -r)"; then
        cp "/boot/config-$(uname -r)" .config
        info "已成功提取当前内核配置作为蓝本。"
    elif modprobe configs 2>/dev/null && test -f /proc/config.gz; then
        zcat /proc/config.gz > .config
        info "已成功提取内存运行时配置 (/proc/config.gz)。"
    else
        make defconfig >/dev/null 2>&1 || true
    fi
    
    # 【核心防御：物理歼灭 Makefile 架构报错 Bug】
    # 必须在单引号内原样匹配带有 $ 符号的变量并替换！防止展开成空字符串。
    info "物理破坏 Makefile 架构验证逻辑，彻底斩断 GCC 编译错误链条..."
    sed -i 's/-march=x86-64-v$(CONFIG_X86_64_VERSION)/-march=x86-64-v2/g' arch/x86/Makefile 2>/dev/null || true

    info "正在抹平新老内核代差，执行首次静默对齐..."
    yes "" | make olddefconfig >/dev/null 2>&1 || true
    make scripts >/dev/null 2>&1 || true
    
    # 手动强硬锁定基础架构，防止脚本回滚
    ./scripts/config --set-val X86_64_VERSION 2 2>/dev/null || true
    ./scripts/config --enable X86_64_V2 2>/dev/null || true
    ./scripts/config --disable GENERIC_CPU 2>/dev/null || true
    
    info "注入 KVM/Xen 底层虚拟化驱动映射层 (VIRTIO)..."
    ./scripts/config --enable VIRTIO 2>/dev/null || true
    ./scripts/config --enable VIRTIO_PCI 2>/dev/null || true
    ./scripts/config --enable VIRTIO_BLK 2>/dev/null || true
    ./scripts/config --enable VIRTIO_NET 2>/dev/null || true
    ./scripts/config --enable SCSI_VIRTIO 2>/dev/null || true
    ./scripts/config --enable HW_RANDOM_VIRTIO 2>/dev/null || true
    
    info "注入 TCP BBR v3..."
    ./scripts/config --enable TCP_CONG_BBR 2>/dev/null || true
    ./scripts/config --enable DEFAULT_BBR 2>/dev/null || true
    ./scripts/config --enable TCP_BBR3 2>/dev/null || true
    
    info "正在剥离 Debian/Ubuntu 证书锁与臃肿调试信息..."
    ./scripts/config --disable DRM_I915 2>/dev/null || true
    ./scripts/config --disable NET_VENDOR_REALTEK 2>/dev/null || true
    ./scripts/config --disable NET_VENDOR_BROADCOM 2>/dev/null || true
    
    ./scripts/config --disable MODULE_SIG 2>/dev/null || true
    ./scripts/config --disable MODULE_SIG_ALL 2>/dev/null || true
    ./scripts/config --disable SYSTEM_TRUSTED_KEYRING 2>/dev/null || true
    ./scripts/config --disable SYSTEM_REVOCATION_LIST 2>/dev/null || true
    
    sed -i 's/CONFIG_SYSTEM_TRUSTED_KEYS=.*/CONFIG_SYSTEM_TRUSTED_KEYS=""/g' .config 2>/dev/null || true
    sed -i 's/CONFIG_SYSTEM_REVOCATION_KEYS=.*/CONFIG_SYSTEM_REVOCATION_KEYS=""/g' .config 2>/dev/null || true
    sed -i 's/CONFIG_MODULE_SIG_KEY=.*/CONFIG_MODULE_SIG_KEY=""/g' .config 2>/dev/null || true
    
    ./scripts/config --disable DEBUG_INFO 2>/dev/null || true
    ./scripts/config --disable DEBUG_INFO_BTF 2>/dev/null || true
    ./scripts/config --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT 2>/dev/null || true
    
    info "再次对齐最终无污染配置..."
    yes "" | make olddefconfig >/dev/null 2>&1 || true
    set -e

    title "=== [6/8] 释放 CPU 算力，开启内核原生 Forge 锻造模式 ==="
    info "分配编译并发线程数: $THREADS"
    
    if ! make -j"$THREADS"; then
        error "编译线程彻底崩塌！请排查物理内存是否溢出。"
        local _p=""; read -rp "按 Enter 返回主菜单..." _p || true
        return 1
    fi

    title "=== [7/8] 校验引导区容量并挂载核心模块 ==="
    local boot_free=$(df -m /boot 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    if test "$boot_free" -lt 200 2>/dev/null; then
        error "致命拦截：/boot 引导扇区剩余空间 ($boot_free MB) 严重不足！编译主动熔断！"
        local _p=""; read -rp "按 Enter 返回主菜单..." _p || true
        return 1
    fi
    
    info "/boot 扇区空间充足 ($boot_free MB)，准许启动扇区安装..."
    make modules_install
    make install

    local NEW_KERNEL_VER=$(make -s kernelrelease 2>/dev/null || echo "")
    if test -n "$NEW_KERNEL_VER"; then
        print_magenta ">>> 为新内核 $NEW_KERNEL_VER 强制生成底层 Initramfs 镜像驱动..."
        if command -v update-initramfs >/dev/null 2>&1; then
            update-initramfs -c -k "$NEW_KERNEL_VER" || true
        elif command -v dracut >/dev/null 2>&1; then
            dracut --force "/boot/initramfs-${NEW_KERNEL_VER}.img" "$NEW_KERNEL_VER" || true
        fi
    fi

    title "=== [8/8] 刷新系统引导器并销毁编译垃圾 ==="
    if command -v update-grub >/dev/null 2>&1; then
        update-grub >/dev/null 2>&1 || true
    else
        apt-get install -y grub2-common >/dev/null 2>&1 || true
        update-grub >/dev/null 2>&1 || true
    fi

    cd /
    rm -rf "$BUILD_DIR/linux-"* "$BUILD_DIR/$KERNEL_FILE" >/dev/null 2>&1 || true
    
    info "奇迹再现！纯血版 Xanmod 源码内核编译与 Initramfs 挂载全部顺利结束。"
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
    
    local current_scale=$(sysctl -n net.ipv4.tcp_adv_win_scale 2>/dev/null || echo "1")
    local current_app=$(sysctl -n net.ipv4.tcp_app_win 2>/dev/null || echo "31")
    
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
        local _p=""; read -rp "按 Enter 返回菜单..." _p || true
        return 1
    else
        info "所有底层 Sysctl 参数已成功应用。"
    fi
    
    local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
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
if test -z "$IFACE"; then exit 0; fi

CPU=$(nproc 2>/dev/null || echo 1)
CPU_MASK=$(printf "%x" $(( (1<<CPU)-1 )))
RX_QUEUES=$(ls -d /sys/class/net/"$IFACE"/queues/rx-* 2>/dev/null | wc -l || echo 0)

for RX in /sys/class/net/"$IFACE"/queues/rx-*; do
    if test -w "$RX/rps_cpus"; then echo "$CPU_MASK" > "$RX/rps_cpus" 2>/dev/null || true; fi
done

for TX in /sys/class/net/"$IFACE"/queues/tx-*; do
    if test -w "$TX/xps_cpus"; then echo "$CPU_MASK" > "$TX/xps_cpus" 2>/dev/null || true; fi
done

sysctl -w net.core.rps_sock_flow_entries=131072 >/dev/null 2>&1 || true

if test "$RX_QUEUES" -gt 0 2>/dev/null; then
    FLOW_PER_QUEUE=$((65535 / RX_QUEUES))
    for RX in /sys/class/net/"$IFACE"/queues/rx-*; do
        if test -w "$RX/rps_flow_cnt"; then echo "$FLOW_PER_QUEUE" > "$RX/rps_flow_cnt" 2>/dev/null || true; fi
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

# ------------------------------------------------------------------------------
# [ 0x0A: 网卡发送队列调优与 CAKE 参数高级配置 ]
# ------------------------------------------------------------------------------

do_txqueuelen_opt() {
    title "网卡发送队列 (TX Queue) 物理调优"
    local IP_CMD=$(command -v ip || echo "")
    if test -z "$IP_CMD"; then
        error "系统缺失 iproute2 (ip 命令) 核心组件，无法调节网卡。"
        local _p=""; read -rp "按 Enter 返回..." _p || true
        return 1
    fi
    local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if test -z "$IFACE"; then
        error "无法定位系统默认出口网卡，操作中止。"
        local _p=""; read -rp "按 Enter 返回..." _p || true
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
    
    local CHECK_QLEN=$($IP_CMD link show "$IFACE" 2>/dev/null | grep -o 'qlen [0-9]*' | awk '{print $2}' || echo "")
    if test "$CHECK_QLEN" = "2000"; then info "已成功将网卡底层并发队列长度扩容至 2000 级。"; else warn "修改失败！当前虚拟机或网卡驱动不支持调节 txqueuelen 队列长度。"; fi
    local _p=""; read -rp "按 Enter 键返回主菜单..." _p || true
}

config_cake_advanced() {
    clear
    title "CAKE 拥塞调度器高级微操配置"
    local current_opts="未配置 (系统自适应默认)"
    if test -f "$CAKE_OPTS_FILE"; then current_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo ""); fi
    echo -e "  当前运行参数: ${cyan}${current_opts}${none}\n"
    
    local c_bw=""; read -rp "  [1] 声明物理带宽限制 (例如 900Mbit，填 0 取消限制): " c_bw || true
    local c_oh=""; read -rp "  [2] 配置底层报文开销补偿 Overhead (填 0 取消限制): " c_oh || true
    local c_mpu=""; read -rp "  [3] 最小数据单元截断 MPU (填 0 取消限制): " c_mpu || true
    
    echo "  [4] RTT 延迟模型: "
    echo "    1) internet  (标准互联 85ms)"
    echo "    2) oceanic   (跨洋海缆 300ms)"
    echo "    3) satellite (卫星链路 1000ms)"
    local rtt_sel=""; read -rp "  请选择 (默认 2): " rtt_sel || true
    local c_rtt=""
    case "${rtt_sel:-2}" in
        1) c_rtt="internet" ;;
        3) c_rtt="satellite" ;;
        *) c_rtt="oceanic" ;;
    esac
    
    echo "  [5] 流量分类识别 (Diffserv): "
    echo "    1) diffserv4  (按数据包特征分类，CPU 消耗较高)"
    echo "    2) besteffort (盲推忽略特征，大幅降低 CPU 开销)"
    local diff_sel=""; read -rp "  请选择 (默认 2): " diff_sel || true
    local c_diff=""
    case "${diff_sel:-2}" in
        1) c_diff="diffserv4" ;;
        *) c_diff="besteffort" ;;
    esac

    local final_opts=""
    if test -n "$c_bw" && test "$c_bw" != "0"; then final_opts="$final_opts bandwidth $c_bw"; fi
    if test -n "$c_oh" && test "$c_oh" != "0"; then final_opts="$final_opts overhead $c_oh"; fi
    if test -n "$c_mpu" && test "$c_mpu" != "0"; then final_opts="$final_opts mpu $c_mpu"; fi
    final_opts="$final_opts $c_rtt $c_diff"
    final_opts="${final_opts#"${final_opts%%[! ]*}"}"
    
    if test -z "$final_opts"; then
        rm -f "$CAKE_OPTS_FILE" 2>/dev/null || true
        info "已清除所有 CAKE 自定义高阶参数，恢复默认。"
    else
        echo "$final_opts" > "$CAKE_OPTS_FILE"
        info "CAKE 高阶参数已写入物理储存: $final_opts"
    fi
    
    modprobe sch_cake >/dev/null 2>&1 || true
    _apply_cake_live
    
    local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if test -n "$IFACE"; then
        if tc qdisc show dev "$IFACE" 2>/dev/null | grep -q "cake"; then
            info "验证通过：CAKE 高阶队列已成功接管网卡接口！"
        else
            warn "验证失败：网卡当前未运行 CAKE 调度器。请确认系统内核支持 sch_cake 模块。"
        fi
    fi
    local _p=""; read -rp "参数阵列配置完成，请按 Enter 返回主菜单..." _p || true
}
# ------------------------------------------------------------------------------
# [ 0x0D: 扩展微操组件切换逻辑 (涵盖 ex188e5 的 25 项底层分支) ]
# ------------------------------------------------------------------------------

toggle_buffer() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if [ ! -f "$limit_file" ]; then return; fi
    if grep -q "XRAY_RAY_BUFFER_SIZE=64" "$limit_file"; then
        sed -i '/XRAY_RAY_BUFFER_SIZE=/d' "$limit_file"
    else
        echo "Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" >> "$limit_file"
    fi
    systemctl daemon-reload
}

toggle_routeonly() {
    if [ "$(check_routeonly_state)" = "true" ]; then
        _safe_jq_write '(.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly) = false'
    else
        _safe_jq_write '(.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly) = true'
    fi
}

toggle_cake_qdisc() {
    local conf="/etc/sysctl.d/99-network-optimized.conf"
    local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if [ -z "$IFACE" ]; then return; fi
    
    if [ "$(check_cake_state)" = "true" ]; then
        sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = fq/' "$conf" 2>/dev/null || true
        sysctl -p "$conf" >/dev/null 2>&1 || true
        tc qdisc replace dev "$IFACE" root fq >/dev/null 2>&1 || true
    else
        sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = cake/' "$conf" 2>/dev/null || true
        sysctl -p "$conf" >/dev/null 2>&1 || true
        _apply_cake_live
    fi
}

toggle_cake_flag() {
    local flag="$1"
    if [ ! -d "$FLAGS_DIR" ]; then mkdir -p "$FLAGS_DIR"; fi
    if [ -f "$FLAGS_DIR/$flag" ]; then 
        rm -f "$FLAGS_DIR/$flag"
    else 
        touch "$FLAGS_DIR/$flag"
    fi
    _apply_cake_live
}

toggle_gso() {
    local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if [ -z "$IFACE" ]; then return; fi
    if [ "$(check_gso_off_state)" = "true" ]; then
        ethtool -K "$IFACE" gro on gso on tso on 2>/dev/null || true
    else
        ethtool -K "$IFACE" gro off gso off tso off 2>/dev/null || true
    fi
    update_hw_boot_script
}

toggle_irq() {
    local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if [ -z "$IFACE" ]; then return; fi
    if [ "$(check_irq_state)" = "true" ]; then
        systemctl start irqbalance 2>/dev/null || true
        systemctl enable irqbalance 2>/dev/null || true
        local CPU=$(nproc 2>/dev/null || echo 1)
        local MASK=$(printf "%x" $(( (1<<CPU)-1 )))
        for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || true); do
            echo "$MASK" > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true
        done
    else
        systemctl stop irqbalance 2>/dev/null || true
        systemctl disable irqbalance 2>/dev/null || true
        for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || true); do
            echo 1 > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true
        done
    fi
    update_hw_boot_script
}

_turn_on_app() {
    _safe_jq_write '
      (.routing) |= (. // {}) |
      (.routing.domainMatcher) = "mph" |
      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings) |= (. // {}) |
      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt) |= (. // {}) |
      (.inbounds[]? | select(.protocol=="vless") | .streamSettings) |= (. // {}) |
      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt) |= (. // {}) |
      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpNoDelay) = true |
      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpFastOpen) = true |
      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt.tcpNoDelay) = true |
      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt.tcpFastOpen) = true |
      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpKeepAliveIdle) = 30 |
      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpKeepAliveInterval) = 15 |
      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt.tcpKeepAliveIdle) = 30 |
      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt.tcpKeepAliveInterval) = 15
    '
    _safe_jq_write '(.inbounds[]? | select(.protocol=="vless") | .sniffing.metadataOnly) = true | (.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly) = true'
    
    local has_reality=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .protocol' "$CONFIG" 2>/dev/null | head -n 1)
    if [ -n "$has_reality" ] && [ "$has_reality" != "null" ]; then
        _safe_jq_write '(.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff) = 60000'
    fi
    
    if [ "$(check_dnsmasq_state)" = "true" ]; then
        _safe_jq_write '.dns = {"servers":["127.0.0.1"], "queryStrategy":"UseIP"}'
    else
        _safe_jq_write '.dns = {"servers":["https://8.8.8.8/dns-query","https://1.1.1.1/dns-query","https://doh.opendns.com/dns-query"], "queryStrategy":"UseIP"}'
    fi
    
    _safe_jq_write '.policy = {"levels":{"0":{"handshake":3,"connIdle":60}},"system":{"statsInboundDownlink":false,"statsInboundUplink":false}}'
    
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if [ -f "$limit_file" ]; then
        [ "$(check_buffer_state)" = "false" ] && echo "Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" >> "$limit_file"
        _toggle_affinity_on
        
        local TOTAL_MEM=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo "1024")
        local DYNAMIC_GOGC=100
        if [ "$TOTAL_MEM" -ge 1800 ]; then DYNAMIC_GOGC=1000
        elif [ "$TOTAL_MEM" -ge 900 ]; then DYNAMIC_GOGC=500
        elif [ "$TOTAL_MEM" -ge 700 ]; then DYNAMIC_GOGC=400
        elif [ "$TOTAL_MEM" -ge 500 ]; then DYNAMIC_GOGC=300
        elif [ "$TOTAL_MEM" -ge 400 ]; then DYNAMIC_GOGC=200
        else DYNAMIC_GOGC=100; fi

        if grep -q "Environment=\"GOGC=" "$limit_file"; then
            sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=$DYNAMIC_GOGC\"/" "$limit_file"
        else
            echo "Environment=\"GOGC=$DYNAMIC_GOGC\"" >> "$limit_file"
        fi
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

_turn_off_app() {
    _safe_jq_write 'del(.routing.domainMatcher) | del(.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpNoDelay, .streamSettings?.sockopt?.tcpFastOpen, .streamSettings?.sockopt?.tcpKeepAliveIdle, .streamSettings?.sockopt?.tcpKeepAliveInterval) | del(.inbounds[]? | select(.protocol=="vless") | .streamSettings?.sockopt?.tcpNoDelay, .streamSettings?.sockopt?.tcpFastOpen, .streamSettings?.sockopt?.tcpKeepAliveIdle, .streamSettings?.sockopt?.tcpKeepAliveInterval)'
    _safe_jq_write '(.inbounds[]? | select(.protocol=="vless") | .sniffing.metadataOnly) = false | (.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly) = false'
    _safe_jq_write 'del(.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff)'
    _safe_jq_write 'del(.dns)'
    _safe_jq_write 'del(.policy)'
    
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if [ -f "$limit_file" ]; then
        sed -i '/XRAY_RAY_BUFFER_SIZE=/d' "$limit_file"
        _toggle_affinity_off
        if grep -q "Environment=\"GOGC=" "$limit_file"; then
            sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=100\"/" "$limit_file"
        else
            echo "Environment=\"GOGC=100\"" >> "$limit_file"
        fi
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

# ------------------------------------------------------------------------------
# [ 0x0E: 全域 25 项极限微操控制台 (完整融合 ex188e5 矩阵) ]
# ------------------------------------------------------------------------------

do_app_level_tuning_menu() {
    while true; do
        clear
        title "全域 25 项系统级及应用层微操管理中心"
        if ! test -f "$CONFIG"; then 
            error "未发现配置，请先执行核心部署！"
            local _p=""; read -rp "按 Enter 返回..." _p || true
            return
        fi

        # ---------------- 应用层参数侦测 ----------------
        local out_fastopen=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpFastOpen // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        local out_keepalive=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpKeepAliveIdle // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        local sniff_status=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .sniffing.metadataOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        local routeonly_status=$(check_routeonly_state)
        local buffer_state=$(check_buffer_state)
        local dns_status=$(jq -r '.dns.queryStrategy // "false"' "$CONFIG" 2>/dev/null)
        local policy_status=$(jq -r '.policy.levels["0"].connIdle // "false"' "$CONFIG" 2>/dev/null)
        local affinity_state=$(check_affinity_state)
        local mph_state=$(check_mph_state)
        local maxtime_state=$(check_maxtime_state)
        
        local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
        local gc_status="未知"
        if [ -f "$limit_file" ]; then
            gc_status=$(awk -F'=' '/^Environment="GOGC=/ {print $3}' "$limit_file" | tr -d '"' | head -1)
            gc_status=${gc_status:-"默认 100"}
        fi

        # ---------------- 系统层参数侦测 ----------------
        local dnsmasq_state=$(check_dnsmasq_state)
        local thp_state=$(check_thp_state)
        local mtu_state=$(check_mtu_state)
        local cpu_state=$(check_cpu_state)
        local ring_state=$(check_ring_state)
        local cake_state=$(check_cake_state)
        local ackfilter_state=$(check_ackfilter_state)
        local ecn_state=$(check_ecn_state)
        local wash_state=$(check_wash_state)
        local gso_state=$(check_gso_off_state)
        local irq_state=$(check_irq_state)
        local zram_state=$(check_zram_state)
        local journal_state=$(check_journal_state)
        local prio_state=$(check_process_priority_state)

        # ---------------- 状态映射与计算 ----------------
        local app_off_count=0
        [ "$out_fastopen" != "true" ] && app_off_count=$((app_off_count+1))
        [ "$out_keepalive" != "30" ] && app_off_count=$((app_off_count+1))
        [ "$sniff_status" != "true" ] && app_off_count=$((app_off_count+1))
        [ "$routeonly_status" != "true" ] && app_off_count=$((app_off_count+1))
        [ "$buffer_state" != "true" ] && app_off_count=$((app_off_count+1))
        [ "$dns_status" != "UseIP" ] && app_off_count=$((app_off_count+1))
        if [ "$gc_status" = "默认 100" ] || [ "$gc_status" = "100" ]; then app_off_count=$((app_off_count+1)); fi
        [ "$policy_status" != "60" ] && app_off_count=$((app_off_count+1))
        [ "$affinity_state" != "true" ] && app_off_count=$((app_off_count+1))
        [ "$mph_state" != "true" ] && app_off_count=$((app_off_count+1))
        
        local has_reality=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .protocol' "$CONFIG" 2>/dev/null | head -n 1)
        if [ -n "$has_reality" ] && [ "$has_reality" != "null" ]; then
            [ "$maxtime_state" != "true" ] && app_off_count=$((app_off_count+1))
        fi

        local sys_off_count=0
        [ "$dnsmasq_state" = "false" ] && sys_off_count=$((sys_off_count+1))
        [ "$thp_state" = "false" ] && sys_off_count=$((sys_off_count+1))
        [ "$mtu_state" = "false" ] && sys_off_count=$((sys_off_count+1))
        [ "$cpu_state" = "false" ] && sys_off_count=$((sys_off_count+1))
        [ "$ring_state" = "false" ] && sys_off_count=$((sys_off_count+1))
        [ "$cake_state" = "false" ] && sys_off_count=$((sys_off_count+1))
        [ "$ackfilter_state" = "false" ] && sys_off_count=$((sys_off_count+1))
        [ "$ecn_state" = "false" ] && sys_off_count=$((sys_off_count+1))
        [ "$wash_state" = "false" ] && sys_off_count=$((sys_off_count+1))
        [ "$gso_state" = "false" ] && sys_off_count=$((sys_off_count+1))
        [ "$irq_state" = "false" ] && sys_off_count=$((sys_off_count+1))
        [ "$zram_state" = "false" ] && sys_off_count=$((sys_off_count+1))
        [ "$journal_state" = "false" ] && sys_off_count=$((sys_off_count+1))
        [ "$prio_state" = "false" ] && sys_off_count=$((sys_off_count+1))

        # ---------------- UI 输出层 ----------------
        local s1=$([ "$out_fastopen" = "true" ] && echo "${cyan}已开启${none}" || echo "${gray}未开启${none}")
        local s2=$([ "$out_keepalive" = "30" ] && echo "${cyan}已开启 (30s/15s)${none}" || echo "${gray}系统默认${none}")
        local s3=$([ "$sniff_status" = "true" ] && echo "${cyan}已开启${none}" || echo "${gray}未开启${none}")
        local s4=$([ "$routeonly_status" = "true" ] && echo "${cyan}已开启${none}" || echo "${gray}未开启${none}")
        local s5=$([ "$buffer_state" = "true" ] && echo "${cyan}已收缩 (64KB)${none}" || echo "${gray}系统默认${none}")
        local s6=$([ "$dns_status" = "UseIP" ] && echo "${cyan}已开启${none}" || echo "${gray}未开启${none}")
        local s8=$([ "$policy_status" = "60" ] && echo "${cyan}已开启 (闲置60s/握手3s)${none}" || echo "${gray}默认 300s${none}")
        local s9=$([ "$affinity_state" = "true" ] && echo "${cyan}已绑核锁死${none}" || echo "${gray}系统调度${none}")
        local s10=$([ "$mph_state" = "true" ] && echo "${cyan}MPH 算法就绪${none}" || echo "${gray}未开启${none}")
        local s11=$([ -z "$has_reality" ] || [ "$has_reality" = "null" ] && echo "${gray}跳过 (无 Reality)${none}" || ([ "$maxtime_state" = "true" ] && echo "${cyan}时间锁 (60s) 已开启${none}" || echo "${gray}未开启${none}"))
        
        local s12=$([ "$dnsmasq_state" = "true" ] && echo "${cyan}已开启内存解析${none}" || echo "${gray}未开启${none}")
        local s13=$([ "$thp_state" = "true" ] && echo "${cyan}已关闭 THP${none}" || ([ "$thp_state" = "unsupported" ] && echo "${gray}不支持${none}" || echo "${gray}系统默认${none}"))
        local s14=$([ "$mtu_state" = "true" ] && echo "${cyan}智能探测中${none}" || ([ "$mtu_state" = "unsupported" ] && echo "${gray}不支持${none}" || echo "${gray}未开启${none}"))
        local s15=$([ "$cpu_state" = "true" ] && echo "${cyan}全核性能模式${none}" || ([ "$cpu_state" = "unsupported" ] && echo "${gray}不支持${none}" || echo "${gray}节能降频中${none}"))
        local s16=$([ "$ring_state" = "true" ] && echo "${cyan}环形反向收缩${none}" || ([ "$ring_state" = "unsupported" ] && echo "${gray}不支持${none}" || echo "${gray}大缓冲(延迟高)${none}"))
        local s17=$([ "$cake_state" = "true" ] && echo "${cyan}CAKE 已挂载${none}" || echo "${gray}默认 (FQ)${none}")
        local s18=$([ "$ackfilter_state" = "true" ] && echo "${cyan}开启 (ACK 压缩)${none}" || echo "${gray}未开启${none}")
        local s19=$([ "$ecn_state" = "true" ] && echo "${cyan}开启 (抗丢包)${none}" || echo "${gray}未开启${none}")
        local s20=$([ "$wash_state" = "true" ] && echo "${cyan}开启 (清空无用标记)${none}" || echo "${gray}未开启${none}")
        local s21=$([ "$gso_state" = "true" ] && echo "${cyan}已卸载 (降低 CPU I/O)${none}" || ([ "$gso_state" = "unsupported" ] && echo "${gray}不支持${none}" || echo "${gray}未开启${none}"))
        local s22=$([ "$irq_state" = "true" ] && echo "${cyan}单核硬锁死${none}" || ([ "$irq_state" = "unsupported" ] && echo "${gray}不支持${none}" || echo "${gray}系统乱序分发${none}"))
        local s23=$([ "$zram_state" = "true" ] && echo "${cyan}已挂载 ZRAM${none}" || ([ "$zram_state" = "unsupported" ] && echo "${gray}不支持${none}" || echo "${gray}未启用${none}"))
        local s24=$([ "$journal_state" = "true" ] && echo "${cyan}纯内存极速化${none}" || ([ "$journal_state" = "unsupported" ] && echo "${gray}不支持${none}" || echo "${gray}磁盘 IO 写入${none}"))
        local s25=$([ "$prio_state" = "true" ] && echo "${cyan}OOM免死提权${none}" || echo "${gray}系统默认调度${none}")

        echo -e "  ${magenta}--- Xray Core 应用层内部调优 (1-11) ---${none}"
        echo -e "  1) 双向并发提速 (tcpNoDelay/FastOpen)                | 状态: $s1"
        echo -e "  2) Socket 智能保活心跳 (KeepAlive)                   | 状态: $s2"
        echo -e "  3) 嗅探引擎减负 (metadataOnly 解放 CPU)              | 状态: $s3"
        echo -e "  4) 路由纯净解析 (routeOnly 规避冗余查询)             | 状态: $s4"
        echo -e "  5) Xray 内存碎片收缩 (Buffer Size 强缩至 64KB)       | 状态: $s5"
        echo -e "  6) 内置并发 DoH / Dnsmasq 路由分发 (Native DNS)      | 状态: $s6"
        echo -e "  7) GOGC 内存阶梯动态调优 (自动侦测物理内存)          | 设定: ${cyan}${gc_status}${none}"
        echo -e "  8) Policy 策略组优化 (连接生命周期极速回收)          | 状态: $s8"
        echo -e "  9) 进程物理绑核 & GOMAXPROCS 并发锁 (零切换损耗)     | 状态: $s9"
        echo -e "  10) Minimal Perfect Hash (MPH) 路由匹配极速降维引擎  | 状态: $s10"
        echo -e "  11) Reality 防重放装甲 (maxTimeDiff 时间偏移拦截)    | 状态: $s11"
        echo -e ""
        echo -e "  ${magenta}--- Linux 系统层与内核硬件级微操 (12-25) ---${none}"
        echo -e "  12) 【Dnsmasq 本地极速内存缓存引擎 (锁TTL)】         | 状态: $s12"
        echo -e "  13) 【透明大页 (THP - Transparent Huge Pages)】      | 状态: $s13"
        echo -e "  14) 【TCP PMTU 黑洞智能探测 (Probing=1)】            | 状态: $s14"
        echo -e "  15) 【CPU 频率调度器锁定 (Performance 全开)】        | 状态: $s15"
        echo -e "  16) 【网卡硬件环形缓冲区 (Ring Buffer) 极速收缩】    | 状态: $s16"
        echo -e "  17) 【CAKE 拥塞调度器】(取代默认 FQ 算法)            | 状态: $s17"
        echo -e "  18)  ├── 子项: CAKE Ack Filter (TCP 确认包过滤)      | 状态: $s18"
        echo -e "  19)  ├── 子项: CAKE ECN (开启显式拥塞通知防断流)     | 状态: $s19"
        echo -e "  20)  └── 子项: CAKE WASH (清洗冗余拥塞标记)          | 状态: $s20"
        echo -e "  21) 【网卡 GSO/GRO 硬件卸载控制】(解除 I/O 封印)     | 状态: $s21"
        echo -e "  22) 【网卡 IRQ 中断多核分发绑定】(中断锁定防漂移)    | 状态: $s22"
        echo -e "  23) 【ZRAM】(淘汰慢速 Swap，阶梯内存自动检测挂载)    | 状态: $s23"
        echo -e "  24) 【日志系统 Journald 纯内存化】(斩断磁盘羁绊)     | 状态: $s24"
        echo -e "  25) 【系统进程级防杀抢占 (OOM/Nice 提权)】           | 状态: $s25"
        echo -e "  "
        echo -e "  ${cyan}26) 一键执行 1-11 项 应用层微操 (自动反转状态)${none}"
        echo -e "  ${yellow}27) 一键执行 12-25 项 系统级微操 (自动反转状态)${none}"
        echo -e "  ${red}28) 上帝之手：1-25 项全域极客微操一键打通 (执行后强制重启)${none}"
        echo "  0) 返回上一级"
        hr
        
        local app_opt=""
        read -rp "请下达操作指令: " app_opt || true

        case "$app_opt" in
            1)
                if [ "$out_fastopen" = "true" ]; then
                    _safe_jq_write 'del(.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpNoDelay, .streamSettings?.sockopt?.tcpFastOpen) | del(.inbounds[]? | select(.protocol=="vless") | .streamSettings?.sockopt?.tcpNoDelay, .streamSettings?.sockopt?.tcpFastOpen)'
                    info "双向并发提速 (FastOpen) 已关闭。"
                else
                    _safe_jq_write '
                      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings) |= (. // {}) |
                      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt) |= (. // {}) |
                      (.inbounds[]? | select(.protocol=="vless") | .streamSettings) |= (. // {}) |
                      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt) |= (. // {}) |
                      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpNoDelay) = true |
                      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpFastOpen) = true |
                      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt.tcpNoDelay) = true |
                      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt.tcpFastOpen) = true
                    '
                    info "双向并发提速 (FastOpen) 已全域开启！"
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            2)
                if [ "$out_keepalive" = "30" ]; then
                    _safe_jq_write 'del(.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpKeepAliveIdle, .streamSettings?.sockopt?.tcpKeepAliveInterval) | del(.inbounds[]? | select(.protocol=="vless") | .streamSettings?.sockopt?.tcpKeepAliveIdle, .streamSettings?.sockopt?.tcpKeepAliveInterval)'
                    info "Socket 智能保活心跳已关闭。"
                else
                    _safe_jq_write '
                      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings) |= (. // {}) |
                      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt) |= (. // {}) |
                      (.inbounds[]? | select(.protocol=="vless") | .streamSettings) |= (. // {}) |
                      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt) |= (. // {}) |
                      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpKeepAliveIdle) = 30 |
                      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpKeepAliveInterval) = 15 |
                      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt.tcpKeepAliveIdle) = 30 |
                      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt.tcpKeepAliveInterval) = 15
                    '
                    info "Socket 智能保活心跳已极速注入！"
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            3)
                if [ "$sniff_status" = "true" ]; then
                    _safe_jq_write '(.inbounds[]? | select(.protocol=="vless") | .sniffing.metadataOnly) = false'
                    info "嗅探引擎减负已关闭，恢复深度探包。"
                else
                    _safe_jq_write '(.inbounds[]? | select(.protocol=="vless") | .sniffing.metadataOnly) = true'
                    info "嗅探引擎减负已开启！"
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            4)
                toggle_routeonly
                systemctl restart xray >/dev/null 2>&1 || true
                info "路由纯净解析配置已应用！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            5)
                toggle_buffer
                systemctl restart xray >/dev/null 2>&1 || true
                info "底层 Buffer 数据缓冲区限额已调整！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            6)
                if [ "$dns_status" = "UseIP" ]; then
                    _safe_jq_write 'del(.dns)'
                    info "内置 DNS 路由分发已移除。"
                else
                    if [ "$dnsmasq_state" = "true" ]; then
                        _safe_jq_write '.dns = {"servers":["127.0.0.1"], "queryStrategy":"UseIP"}'
                        info "DNS 已接通本地 Dnsmasq 内存极速引擎！"
                    else
                        _safe_jq_write '.dns = {"servers":["https://8.8.8.8/dns-query","https://1.1.1.1/dns-query","https://doh.opendns.com/dns-query"], "queryStrategy":"UseIP"}'
                        info "DNS 已开启 DoH 加密并发！"
                    fi
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            7)
                if [ -f "$limit_file" ]; then
                    local TOTAL_MEM=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo "1024")
                    local DYNAMIC_GOGC=100
                    if [ "$TOTAL_MEM" -ge 1800 ]; then DYNAMIC_GOGC=1000
                    elif [ "$TOTAL_MEM" -ge 900 ]; then DYNAMIC_GOGC=500
                    elif [ "$TOTAL_MEM" -ge 700 ]; then DYNAMIC_GOGC=400
                    elif [ "$TOTAL_MEM" -ge 500 ]; then DYNAMIC_GOGC=300
                    elif [ "$TOTAL_MEM" -ge 400 ]; then DYNAMIC_GOGC=200
                    else DYNAMIC_GOGC=100; fi

                    if grep -q "Environment=\"GOGC=" "$limit_file"; then
                        if [ "$gc_status" = "默认 100" ] || [ "$gc_status" = "100" ]; then
                            sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=$DYNAMIC_GOGC\"/" "$limit_file"
                            info "GOGC 动态阶梯调优完成！自动锁定阈值: ${DYNAMIC_GOGC}"
                        else
                            sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=100\"/" "$limit_file"
                            info "GOGC 阶梯调优已关闭，已恢复保底阈值: 100"
                        fi
                    else
                        echo "Environment=\"GOGC=$DYNAMIC_GOGC\"" >> "$limit_file"
                        info "GOGC 动态调优完成！"
                    fi
                    systemctl daemon-reload >/dev/null 2>&1 || true
                    systemctl restart xray >/dev/null 2>&1 || true
                else
                    error "未找到配置环境，请先执行核心安装！"
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            8)
                if [ "$policy_status" = "60" ]; then
                    _safe_jq_write 'del(.policy)'
                    info "Xray 策略组极速回收已关闭，恢复官方默认限制。"
                else
                    _safe_jq_write '.policy = {"levels":{"0":{"handshake":3,"connIdle":60}},"system":{"statsInboundDownlink":false,"statsInboundUplink":false}}'
                    info "Xray 策略组优化成功！强制压缩连接存活生命周期。"
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            9)
                if [ "$affinity_state" = "true" ]; then
                    _toggle_affinity_off
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "物理绑核与并发锁已解除，恢复自由调度。"
                else
                    _toggle_affinity_on
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "Xray 进程已成功硬绑定核心，并发性能限制已破除！"
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            10)
                if [ "$mph_state" = "true" ]; then
                    _safe_jq_write 'del(.routing.domainMatcher)'
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "MPH 路由匹配已关闭，恢复普通寻址。"
                else
                    _safe_jq_write '(.routing) |= (. // {}) | (.routing.domainMatcher) = "mph"'
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "Minimal Perfect Hash (MPH) 算法已强力注入，查表时间降维！"
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            11)
                if [ -z "$has_reality" ] || [ "$has_reality" = "null" ]; then
                    error "未检测到 Reality 协议支持，操作被阻断。"
                else
                    if [ "$maxtime_state" = "true" ]; then
                        _safe_jq_write 'del(.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff)'
                        systemctl restart xray >/dev/null 2>&1 || true
                        info "Reality 防重放时间偏移锁已解除。"
                    else
                        _safe_jq_write '(.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff) = 60000'
                        systemctl restart xray >/dev/null 2>&1 || true
                        info "Reality 60秒防重放锁已激活！"
                    fi
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            12) toggle_dnsmasq; systemctl restart xray >/dev/null 2>&1 || true; info "操作指令已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            13) toggle_thp; info "操作指令已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            14) toggle_mtu; info "操作指令已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            15) toggle_cpu; info "操作指令已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            16) toggle_ring; info "操作指令已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            17) toggle_cake_qdisc; info "操作指令已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            18) toggle_cake_flag "ack_filter"; info "操作指令已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            19) toggle_cake_flag "ecn"; info "操作指令已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            20) toggle_cake_flag "wash"; info "操作指令已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            21) toggle_gso; info "操作指令已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            22) toggle_irq; info "操作指令已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            23) toggle_zram; info "操作指令已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            24) toggle_journal; info "操作指令已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            25) toggle_process_priority; systemctl restart xray >/dev/null 2>&1 || true; info "操作指令已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            26)
                if [ "$app_off_count" -gt 0 ]; then
                    print_magenta ">>> 正在全域强力开启 1-11 项，请耐心等待..."
                    _turn_on_app
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "应用层极致微操已全域激活！"
                else
                    print_magenta ">>> 正在全域恢复 1-11 项，请耐心等待..."
                    _turn_off_app
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "应用层设置已全部回归出厂标准！"
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            27)
                if [ "$sys_off_count" -gt 0 ]; then
                    [ "$dnsmasq_state" = "false" ] && toggle_dnsmasq >/dev/null 2>&1 || true
                    if [ -f "/sys/kernel/mm/transparent_hugepage/enabled" ]; then [ "$(check_thp_state)" = "false" ] && toggle_thp >/dev/null 2>&1 || true; fi
                    [ "$mtu_state" = "false" ] && toggle_mtu >/dev/null 2>&1 || true
                    if [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then [ "$(check_cpu_state)" = "false" ] && toggle_cpu >/dev/null 2>&1 || true; fi
                    [ "$ring_state" = "false" ] && toggle_ring >/dev/null 2>&1 || true
                    [ "$cake_state" = "false" ] && toggle_cake_qdisc >/dev/null 2>&1 || true
                    [ "$ackfilter_state" = "false" ] && toggle_cake_flag "ack_filter" >/dev/null 2>&1 || true
                    [ "$ecn_state" = "false" ] && toggle_cake_flag "ecn" >/dev/null 2>&1 || true
                    [ "$wash_state" = "false" ] && toggle_cake_flag "wash" >/dev/null 2>&1 || true
                    [ "$gso_state" = "false" ] && toggle_gso >/dev/null 2>&1 || true
                    [ "$irq_state" = "false" ] && toggle_irq >/dev/null 2>&1 || true
                    [ "$zram_state" = "false" ] && toggle_zram >/dev/null 2>&1 || true
                    [ "$journal_state" = "false" ] && toggle_journal >/dev/null 2>&1 || true
                    [ "$prio_state" = "false" ] && toggle_process_priority >/dev/null 2>&1 || true
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "系统底层 14 项优化已全部激活！(不支持的特性自动规避)"
                else
                    [ "$dnsmasq_state" = "true" ] && toggle_dnsmasq >/dev/null 2>&1 || true
                    if [ -f "/sys/kernel/mm/transparent_hugepage/enabled" ]; then [ "$(check_thp_state)" = "true" ] && toggle_thp >/dev/null 2>&1 || true; fi
                    [ "$mtu_state" = "true" ] && toggle_mtu >/dev/null 2>&1 || true
                    if [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then [ "$(check_cpu_state)" = "true" ] && toggle_cpu >/dev/null 2>&1 || true; fi
                    [ "$ring_state" = "true" ] && toggle_ring >/dev/null 2>&1 || true
                    [ "$cake_state" = "true" ] && toggle_cake_qdisc >/dev/null 2>&1 || true
                    [ "$ackfilter_state" = "true" ] && toggle_cake_flag "ack_filter" >/dev/null 2>&1 || true
                    [ "$ecn_state" = "true" ] && toggle_cake_flag "ecn" >/dev/null 2>&1 || true
                    [ "$wash_state" = "true" ] && toggle_cake_flag "wash" >/dev/null 2>&1 || true
                    [ "$gso_state" = "true" ] && toggle_gso >/dev/null 2>&1 || true
                    [ "$irq_state" = "true" ] && toggle_irq >/dev/null 2>&1 || true
                    [ "$zram_state" = "true" ] && toggle_zram >/dev/null 2>&1 || true
                    [ "$journal_state" = "true" ] && toggle_journal >/dev/null 2>&1 || true
                    [ "$prio_state" = "true" ] && toggle_process_priority >/dev/null 2>&1 || true
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "系统底层微操已全部拆除还原！"
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            28)
                if [ "$((app_off_count + sys_off_count))" -gt 0 ]; then
                    if [ "$app_off_count" -gt 0 ]; then 
                        print_magenta ">>> 正在激活应用层..."
                        _turn_on_app
                    fi
                    if [ "$sys_off_count" -gt 0 ]; then
                        print_magenta ">>> 正在激活系统底层架构..."
                        [ "$dnsmasq_state" = "false" ] && toggle_dnsmasq >/dev/null 2>&1 || true
                        if [ -f "/sys/kernel/mm/transparent_hugepage/enabled" ]; then [ "$(check_thp_state)" = "false" ] && toggle_thp >/dev/null 2>&1 || true; fi
                        [ "$mtu_state" = "false" ] && toggle_mtu >/dev/null 2>&1 || true
                        if [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then [ "$(check_cpu_state)" = "false" ] && toggle_cpu >/dev/null 2>&1 || true; fi
                        [ "$ring_state" = "false" ] && toggle_ring >/dev/null 2>&1 || true
                        [ "$cake_state" = "false" ] && toggle_cake_qdisc >/dev/null 2>&1 || true
                        [ "$ackfilter_state" = "false" ] && toggle_cake_flag "ack_filter" >/dev/null 2>&1 || true
                        [ "$ecn_state" = "false" ] && toggle_cake_flag "ecn" >/dev/null 2>&1 || true
                        [ "$wash_state" = "false" ] && toggle_cake_flag "wash" >/dev/null 2>&1 || true
                        [ "$gso_state" = "false" ] && toggle_gso >/dev/null 2>&1 || true
                        [ "$irq_state" = "false" ] && toggle_irq >/dev/null 2>&1 || true
                        [ "$zram_state" = "false" ] && toggle_zram >/dev/null 2>&1 || true
                        [ "$journal_state" = "false" ] && toggle_journal >/dev/null 2>&1 || true
                        [ "$prio_state" = "false" ] && toggle_process_priority >/dev/null 2>&1 || true
                    fi
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "上帝之手：1-25 项全域极致优化已满血注入！"
                else
                    print_magenta ">>> 正在执行全域系统回卷..."
                    _turn_off_app
                    [ "$dnsmasq_state" = "true" ] && toggle_dnsmasq >/dev/null 2>&1 || true
                    if [ -f "/sys/kernel/mm/transparent_hugepage/enabled" ]; then [ "$(check_thp_state)" = "true" ] && toggle_thp >/dev/null 2>&1 || true; fi
                    [ "$mtu_state" = "true" ] && toggle_mtu >/dev/null 2>&1 || true
                    if [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then [ "$(check_cpu_state)" = "true" ] && toggle_cpu >/dev/null 2>&1 || true; fi
                    [ "$ring_state" = "true" ] && toggle_ring >/dev/null 2>&1 || true
                    [ "$cake_state" = "true" ] && toggle_cake_qdisc >/dev/null 2>&1 || true
                    [ "$ackfilter_state" = "true" ] && toggle_cake_flag "ack_filter" >/dev/null 2>&1 || true
                    [ "$ecn_state" = "true" ] && toggle_cake_flag "ecn" >/dev/null 2>&1 || true
                    [ "$wash_state" = "true" ] && toggle_cake_flag "wash" >/dev/null 2>&1 || true
                    [ "$gso_state" = "true" ] && toggle_gso >/dev/null 2>&1 || true
                    [ "$irq_state" = "true" ] && toggle_irq >/dev/null 2>&1 || true
                    [ "$zram_state" = "true" ] && toggle_zram >/dev/null 2>&1 || true
                    [ "$journal_state" = "true" ] && toggle_journal >/dev/null 2>&1 || true
                    [ "$prio_state" = "true" ] && toggle_process_priority >/dev/null 2>&1 || true
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "系统与网络引擎均已降维并恢复为标准安全参数！"
                fi
                
                echo ""
                print_red "=========================================================="
                print_yellow "警告：全域拓扑与内核状态已发生重大变更！"
                print_yellow "系统必须在 6 秒后执行物理强制重启，请勿切断连接！"
                print_red "=========================================================="
                echo ""
                for i in {6..1}; do
                    echo -ne "\r  重启执行序列: ${cyan}${i}${none} ... "
                    sleep 1
                done
                echo -e "\n\n  正在重启，请稍候重新登录服务器..."
                reboot
                ;;
            0)
                return
                ;;
        esac
    done
}
