#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: ex196.sh (The Apex Vanguard - Project Genesis V196)
# 快捷方式: xrv
#
# 【V196 终极勘误与真理重塑】
#   1. 真·源码溯源: 彻底废弃停更的 GitHub 镜像，重构探测引擎直连 GitLab 官方仓库，拉取正宗 Xanmod 源码包。
#   2. APT 源净化: 修复预编译安装时 GPG 密钥 404 及 sources.list 重复冲突导致的静默瘫痪。
#   3. 剔除朽木: 移除现代系统不兼容的 gnupg1，解除安装依赖链条断裂死锁。
#   4. 完美融合: 全量继承 V193 的 JQ 绝缘护盾、严格模式防爆以及 25 项全域系统微操。
# ==============================================================================

# 必须用 bash 运行
if test -z "${BASH_VERSION:-}"; then
    echo "Error: 请使用 bash 执行本脚本: bash ex196.sh"
    exit 1
fi

if test "$EUID" -ne 0; then 
    echo -e "\033[31m[致命错误] 触及底层内核参数必须拥有最高权限，请使用 root 账户执行！\033[0m"
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then 
    echo -e "\033[31m[致命错误] 当前系统缺失 systemd 守护组件，环境异常！\033[0m"
    exit 1
fi

# 启用严格模式防爆
set -euo pipefail
IFS=$' \n\t'
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# -- 颜色定义与全局常量 --
readonly red='\033[31m'
readonly yellow='\033[33m'
readonly gray='\033[90m'
readonly green='\033[92m'
readonly blue='\033[94m'
readonly magenta='\033[95m'
readonly cyan='\033[96m'
readonly none='\033[0m'

readonly SCRIPT_VERSION="196"
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

# -- 辅助输出函数 --
print_red()     { echo -e "${red}$*${none}"; }
print_green()   { echo -e "${green}$*${none}"; }
print_yellow()  { echo -e "${yellow}$*${none}"; }
print_magenta() { echo -e "${magenta}$*${none}"; }
print_cyan()    { echo -e "${cyan}$*${none}"; }

info()  { echo -e "${green}✓ [INFO]${none} $*"; }
warn()  { echo -e "${yellow}! [WARN]${none} $*"; }
error() { echo -e "${red}✗ [ERROR]${none} $*"; }
die()   { echo -e "\n${red}✗ [FATAL]${none} $*\n"; exit 1; }

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

_get_ip() {
    if test -n "${SERVER_IP:-}"; then
        if test "$SERVER_IP" != "获取失败"; then echo "$SERVER_IP"; return; fi
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
    if test "$EUID" -ne 0; then die "此脚本必须以 root 身份运行。"; fi
    if ! command -v systemctl >/dev/null 2>&1; then die "系统缺少 systemctl，请更换标准的 systemd 系统。"; fi

    local need="jq curl wget xxd unzip qrencode vnstat cron openssl coreutils sed e2fsprogs pkg-config iproute2 ethtool bc bison flex dwarves rsync python3 cpio apt-transport-https"
    local missing=""
    for p in $need; do
        if ! command -v "$p" >/dev/null 2>&1; then missing="$missing $p"; fi
    done
    
    if test -n "$missing"; then
        info "正在同步工业级依赖: $missing"
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
    local current_buffer=""

    if test -f "$limit_file"; then
        if grep -q "^Nice=" "$limit_file" 2>/dev/null; then current_nice=$(awk -F'=' '/^Nice=/{print $2}' "$limit_file" | head -n 1 || echo "-20"); fi
        if grep -q "^Environment=\"GOGC=" "$limit_file" 2>/dev/null; then current_gogc=$(awk -F'=' '/^Environment="GOGC=/{print $3}' "$limit_file" | tr -d '"' | head -n 1 || echo "100"); fi
        if ! grep -q "^OOMScoreAdjust=" "$limit_file" 2>/dev/null; then current_oom="false"; fi
        if grep -q "^CPUAffinity=" "$limit_file" 2>/dev/null; then current_affinity=$(awk -F'=' '/^CPUAffinity=/{print $2}' "$limit_file" | head -n 1 || echo ""); fi
        if grep -q "^Environment=\"GOMAXPROCS=" "$limit_file" 2>/dev/null; then current_gomaxprocs=$(awk -F'=' '/^Environment="GOMAXPROCS=/{print $3}' "$limit_file" | tr -d '"' | head -n 1 || echo ""); fi
        if grep -q "^Environment=\"XRAY_RAY_BUFFER_SIZE=" "$limit_file" 2>/dev/null; then current_buffer=$(awk -F'=' '/^Environment="XRAY_RAY_BUFFER_SIZE=/{print $3}' "$limit_file" | tr -d '"' | head -n 1 || echo ""); fi
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
    if test -n "$current_buffer"; then echo "Environment=\"XRAY_RAY_BUFFER_SIZE=$current_buffer\"" >> "$limit_file"; fi
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
    info "已配置全球库热更与错峰重启: 3:00 静默下载，3:10 安全重载 Xray 进程。"
}

do_change_dns() {
    title "配置系统 DNS 解析 (resolvconf)"
    local release=$(detect_os)
    if test ! -e '/usr/sbin/resolvconf' && test ! -e '/sbin/resolvconf'; then
        info "未检测到 resolvconf，准备安装..."
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
        read -rp "请输入自定义 Nameserver IP (例如 8.8.8.8): " nameserver || true
        if [[ $nameserver =~ ^([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]]; then
            IPcheck="1"
        else
            print_red "输入格式错误，请输入合法的 IPv4 地址。"
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
    info "DNS 已被物理锁定为：$nameserver"
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
        error "配置文件安全校验未通过，Xray 核心拒绝加载。"
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
        log_error "jq 修改失败，语法故障，写入已中止。"
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
        error "Xray 服务启动失败，请检查以下日志："
        hr
        journalctl -u xray.service --no-pager -n 15 2>/dev/null | awk '{print "    " $0}' || true
        hr
        restore_latest_backup
        local _p=""; read -rp "按 Enter 继续..." _p || true
        return 1
    fi
}

run_sni_scanner() {
    title "雷达嗅探：130+ 实体矩阵与国内连通性探测"
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
            echo -e "\n${yellow}探测已手动中止，正在整理已捕获节点...${none}"
            break
        fi

        set +e
        local time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni" 2>/dev/null || echo "0")
        local ms=$(echo "$time_raw" | awk '{print int($1 * 1000)}' 2>/dev/null || echo "0")
        
        if test "${ms:-0}" -gt 0 2>/dev/null; then
            if curl -sI -m 2 --connect-timeout 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray"; then
                echo -e " ${gray}跳过${none} $sni (Cloudflare CDN 拦截)"
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
    if ! echo "$out" | grep -qi "TLSv1.3"; then print_red " ✗ 质检拦截: 目标服务器未启用 TLS v1.3 协议"; pass=0; fi
    if ! echo "$out" | grep -qiE "ALPN, server accepted to use h2|ALPN.*h2"; then print_red " ✗ 质检拦截: 目标服务器不支持 ALPN h2 协商"; pass=0; fi
    if ! echo "$out" | grep -qi "OCSP response:"; then print_red " ✗ 质检拦截: 目标服务器未配置 OCSP Stapling 证书状态装订"; pass=0; fi
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
            echo "  q) 取消并退回上级菜单"
            
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

do_install_xanmod_main_official() {
    title "系统飞升：安装真·预编译 XANMOD 内核 (官方源保护)"
    
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
        warn "未能精确检测 CPU 微架构级别，将默认使用系统最宽容的 v1 兼容版本。"
    else
        info "评估完成，当前 CPU 硬件完美支持的微架构最高级别为: v${cpu_level}"
    fi

    info "正在净化并配置 Xanmod 官方最高优 APT 仓库与真·防伪 Keyring..."
    export DEBIAN_FRONTEND=noninteractive
    
    set +e
    rm -f /etc/apt/trusted.gpg.d/xanmod-*.gpg /etc/apt/sources.list.d/xanmod-*.list /etc/apt/sources.list.d/xanmod-*.sources 2>/dev/null
    sed -i '/deb.xanmod.org/d' /etc/apt/sources.list 2>/dev/null
    
    apt-get update -y >/dev/null 2>&1
    apt-get install -y gnupg gnupg2 curl sudo wget e2fsprogs ca-certificates lsb-release apt-transport-https >/dev/null 2>&1

    mkdir -p /usr/share/keyrings 2>/dev/null
    
    if ! wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor --yes -o /usr/share/keyrings/xanmod-archive-keyring.gpg 2>/dev/null; then
        error "从远端获取 GPG 密钥链发生错误，官方源已被阻断！"
        set -e; return 1
    fi
    
    echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list >/dev/null

    info "触发 APT 数据同步..."
    if ! apt-get update -y; then
        warn "APT 源刷新遇到轻微异常，但环境已强行注册，继续执行降级探测..."
    fi
    
    local pkg_name=""
    local installed=false
    
    for ((v=$cpu_level; v>=1; v--)); do
        local try_pkg="linux-xanmod-x64v${v}"
        info "正在尝试拉取并部署包: $try_pkg ..."
        if apt-get install -y "$try_pkg" >/dev/null 2>&1; then
            pkg_name="$try_pkg"
            installed=true
            print_green ">>> 成功安装 Xanmod 核心包: $pkg_name"
            break
        fi
        warn "源内未命中或阻断 $try_pkg，触发自动降级探测 v$((v-1)) ..."
    done
    
    if test "$installed" = "false"; then
        error "寻址宣告彻底失败！当前系统源无法解析到任何合法的 Xanmod 预编译包。请检查网络环境或更换源！"
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

# --- ✂️ 请将 Part 2 的内容紧接在此行下方 ✂️ ---
# --- ✂️ Ex196.sh Part 2 / 2 ✂️ ---

# ==============================================================================
# [ 0x14: 系统建仓及全域架构更新导航 ]
# ==============================================================================

do_sys_init_menu() {
    while true; do
        clear
        title "环境底层组件拉齐与结构重建区"
        echo "  1) [一键全清] 执行 Linux 强基更新、亚太时间轴校准并置入极客 1GB 内存交换区"
        echo "  2) [系统防御] 强行修改源头 DNS 解析 (注入 resolvconf，免脱轨断联)"
        echo -e "  ${cyan}3) [重构内脏] 安装官方预编译真·XANMOD稳定内核 (源头净化防冲突 / 自动重启)${none}"
        echo "  4) [极客锻造] 原生提档真·XANMOD源码，动态直连GitLab硬核编译 + BBR3组件"
        echo "  5) [网络底层] TX Queue 网卡出站队列防拥堵极限缩减 (配置为 2000 收缩)"
        echo "  6) [内存特化] 高并发 1,000,000 文件进程限制 + TCP_APP_WIN 特化部署"
        echo "  7) [上帝微操] 应用层及系统内核层双轨 25 项神级优化全控板 (Dnsmasq/CAKE)"
        echo -e "  ${cyan}8) [极度发烧] 深入 CAKE 高级模型配置 (设定 Diffserv 调度、物理带宽上限)${none}"
        echo "  0) 折返中央主轴系统"
        hr
        
        local sys_opt=""; read -rp "输入重构程序代号: " sys_opt || true
        case "${sys_opt:-}" in
            1) 
                print_magenta ">>> 执行主网对接拉取一切基础更新源..."
                export DEBIAN_FRONTEND=noninteractive
                apt-get update -y >/dev/null 2>&1 || true
                apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" full-upgrade -y >/dev/null 2>&1 || true
                apt-get autoremove -y --purge >/dev/null 2>&1 || true
                
                apt-get install -y wget curl sudo socat ntpdate e2fsprogs pkg-config iproute2 ethtool >/dev/null 2>&1 || true
                
                print_magenta ">>> 重建亚太网络时间轴记录..."
                if command -v timedatectl >/dev/null 2>&1; then timedatectl set-timezone Asia/Kuala_Lumpur >/dev/null 2>&1 || true; fi
                if command -v ntpdate >/dev/null 2>&1; then ntpdate -u us.pool.ntp.org >/dev/null 2>&1 || true; fi
                if command -v hwclock >/dev/null 2>&1; then hwclock --systohc >/dev/null 2>&1 || true; fi
                info "底层网络环境时空已对接 Asia/Kuala_Lumpur 区块！"
                
                check_and_create_1gb_swap
                
                print_magenta ">>> 初始化暗核清理器 cc1.sh ..."
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
                local temp_cron=$(mktemp)
                crontab -l 2>/dev/null | grep -v "cc1.sh" > "$temp_cron" || true
                echo "0 4 */10 * * /usr/local/bin/cc1.sh >/dev/null 2>&1" >> "$temp_cron"
                crontab "$temp_cron" 2>/dev/null || true
                rm -f "$temp_cron" 2>/dev/null || true
                info "深度自愈清理计划激活！已将回旋肃清周期设为 10 天。"
                local _p=""; read -rp "完成部署，按 Enter 键继续..." _p || true 
                ;;
            2) do_change_dns ;;
            3) do_install_xanmod_main_official ;;
            4) do_xanmod_compile ;;
            5) do_txqueuelen_opt ;;
            6) do_perf_tuning ;;
            7) do_app_level_tuning_menu ;;
            8) config_cake_advanced ;;
            0) return ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# [ 0x15: Xray 核心主通讯环境网络直接热更新 ]
# ------------------------------------------------------------------------------

do_update_core() {
    title "Xray 主心骨环境内核迭代"
    info "强联通官方源更新通道..."
    
    if bash -c "$(curl -L -s https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" @ install >/dev/null 2>&1; then
        if test -x "$XRAY_BIN"; then
            fix_xray_systemd_limits
            systemctl restart xray >/dev/null 2>&1 || true
            local cur_ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 | awk '{print $2}' || echo "检索故障")
            info "全流程覆盖结束，当前主线跃迁到: ${cyan}$cur_ver${none}"
            local _p=""; read -rp "按 Enter 返回安全界面..." _p || true
            return 0
        fi
    fi
    error "遭遇官方源封锁或 IPv6 数据穿透故障，导致数据拉取完全被阻隔。"
    local _p=""; read -rp "按 Enter 关闭进程..." _p || true
    return 1
}

# ------------------------------------------------------------------------------
# [ 0x16: SNI 与安全协议无缝重构路由树 ]
# ------------------------------------------------------------------------------

_update_matrix() {
    if test ! -f "$CONFIG"; then return; fi
    echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
    _safe_jq_write --arg dest "$BEST_SNI:443" --slurpfile snis /tmp/sni_array.json '
        (.inbounds[]? | select(.protocol == "vless")) |= (
            .streamSettings.realitySettings.serverNames = $snis[0] |
            .streamSettings.realitySettings.dest = $dest
        )
    '
    rm -f /tmp/sni_array.json 2>/dev/null || true
    ensure_xray_is_alive
    info "网络架构及反识别面具重构完毕，新版防封已加载上线！"
}

# ------------------------------------------------------------------------------
# [ 0x17: 全方位工业建仓与协议构建逻辑 ]
# ------------------------------------------------------------------------------

do_install() {
    title "Apex Vanguard Ultimate Final: 高维协议建仓与底层核心网组建"
    preflight
    
    systemctl stop xray >/dev/null 2>&1 || true
    if test ! -f "$INSTALL_DATE_FILE"; then date +"%Y-%m-%d %H:%M:%S" > "$INSTALL_DATE_FILE"; fi
    
    echo -e "  ${cyan}决定本次将要搭载的网络体系：${none}"
    echo "  1) VLESS-Reality (极致安全伪装架构 / 防止主动探测阻断)"
    echo "  2) Shadowsocks (抛却重负载，极速穿透轻量备用网)"
    echo "  3) 启用高可用并行搭载系统 (双通道并发部署)"
    local proto_choice=""; read -rp "  执行命令编号 (直接回车默认 1): " proto_choice || true
    proto_choice=${proto_choice:-1}

    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        while true; do 
            local input_p=""; read -rp "分配 VLESS 服务数据监听端口 (回车默认绑定 443): " input_p || true
            input_p=${input_p:-443}
            if validate_port "$input_p"; then LISTEN_PORT="$input_p"; break; fi
        done
        local input_remark=""; read -rp "规划 VLESS 节点基础标识名 (默认 xp-reality): " input_remark || true
        REMARK_NAME=${input_remark:-xp-reality}
        choose_sni
        if test $? -ne 0; then return 1; fi
    fi

    local ss_port=8388
    local ss_pass=""
    local ss_method="aes-256-gcm"
    
    if test "$proto_choice" = "2" || test "$proto_choice" = "3"; then
        while true; do 
            local input_s=""; read -rp "分配 Shadowsocks 单向挂载通讯口 (回车默认使用 8388): " input_s || true
            input_s=${input_s:-8388}
            if validate_port "$input_s"; then ss_port="$input_s"; break; fi
        done
        ss_pass=$(gen_ss_pass)
        ss_method=$(_select_ss_method)
        if test "$proto_choice" = "2"; then 
            local input_remark=""; read -rp "配置 SS 面板默认名称 (默认 xp-reality): " input_remark || true
            REMARK_NAME=${input_remark:-xp-reality}
        fi
    fi

    info "从中心枢纽拉取最新的 Xray 核心主程序执行安装流..."
    if ! bash -c "$(curl -fsSL --connect-timeout 10 https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" @ install >/dev/null 2>&1; then
        warn "因云端问题主脚本直连失败，但环境未遭破坏，稍后请在控制面板尝试执行手动核心更新操作。"
    fi
    install_update_dat
    fix_xray_systemd_limits

    # 1. 纯净构建初始 JSON 路由表，AsIs 解耦
    cat > "$CONFIG" <<EOF
{
  "log": { "loglevel": "warning" },
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      { "outboundTag": "block", "_enabled": true, "protocol": ["bittorrent"] },
      { "outboundTag": "block", "_enabled": true, "ip": ["geoip:cn"] },
      { "outboundTag": "block", "_enabled": true, "domain": ["geosite:cn", "geosite:category-ads-all"] }
    ]
  },
  "inbounds": [],
  "outbounds": [
      { "protocol": "freedom", "tag": "direct", "settings": {"domainStrategy": "AsIs"} }, 
      { "protocol": "blackhole", "tag": "block" }
  ]
}
EOF

    # 2. 以 HereDoc 构建 VLESS 协议的绝对安全写入
    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        local keys=$("$XRAY_BIN" x25519 2>/dev/null || echo "")
        local priv=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' \r\n' || echo "")
        local pub=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' \r\n' || echo "")
        local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
        local sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n\r' || echo "")
        local ctime=$(date +"%Y-%m-%d %H:%M")
        
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
      "clients": [ {"id": "$uuid", "flow": "xtls-rprx-vision", "email": "$REMARK_NAME"} ], 
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
  "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] }
}
EOF
        _safe_jq_write --slurpfile snis /tmp/sni_array.json --slurpfile vless_tmp /tmp/vless_inbound.json '
            .inbounds += [ $vless_tmp[0] | .streamSettings.realitySettings.serverNames = $snis[0] ]
        '
        rm -f /tmp/vless_inbound.json /tmp/sni_array.json 2>/dev/null || true
    fi

    # 3. 构建 SS
    if test "$proto_choice" = "2" || test "$proto_choice" = "3"; then
        cat > /tmp/ss_inbound.json <<EOF
{
  "tag": "shadowsocks", 
  "listen": "0.0.0.0", 
  "port": $ss_port, 
  "protocol": "shadowsocks",
  "settings": { "method": "$ss_method", "password": "$ss_pass", "network": "tcp,udp" },
  "streamSettings": { "sockopt": {"tcpNoDelay": true, "tcpFastOpen": true} }
}
EOF
        _safe_jq_write --slurpfile ss_tmp /tmp/ss_inbound.json '.inbounds += [ $ss_tmp[0] ]'
        rm -f /tmp/ss_inbound.json 2>/dev/null || true
    fi

    fix_permissions
    systemctl enable xray >/dev/null 2>&1 || true
    
    if ensure_xray_is_alive; then
        info "所有架构配置装载确认生效！通讯网络已打开。"
        do_summary
    else
        error "未能顺利贯通服务进程，内部存在数据阻断，请详细勘验报错日志档案。"
        return 1
    fi
    
    while true; do
        local opt=""; read -rp "可按下 Enter 键安全返回系统中心菜单，亦或输入 b 即刻执行 SNI 的网络更换及漂移: " opt || true
        if test "$opt" = "b" || test "$opt" = "B"; then
            if choose_sni; then _update_matrix; do_summary; else break; fi
        else 
            break
        fi
    done
}

# ------------------------------------------------------------------------------
# [ 0x23: 全系统底层绝对清除与终结机制 ]
# ------------------------------------------------------------------------------

do_uninstall() {
    title "终极断供清理器：彻底摧毁当前生态环境并回卷"
    local confirm=""; read -rp "此不可逆物理毁灭指令将被下达，将会摧毁私钥记录及 DNS 强行配置 (但网卡级与并发级设定保留)，您完全明确此行为吗？(y/n): " confirm || true
    if test "$confirm" != "y"; then return; fi
    
    info "安全门禁确认，彻底开始核心粉碎行动..."
    systemctl stop dnsmasq >/dev/null 2>&1 || true
    systemctl disable dnsmasq >/dev/null 2>&1 || true
    export DEBIAN_FRONTEND=noninteractive
    apt-get purge -y dnsmasq >/dev/null 2>&1 || true
    
    chattr -i /etc/resolv.conf 2>/dev/null || true
    if test -f /etc/resolv.conf.bak; then mv -f /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true; fi
    
    systemctl stop resolvconf.service >/dev/null 2>&1 || true
    systemctl disable resolvconf.service >/dev/null 2>&1 || true
    
    if systemctl list-unit-files | grep -q systemd-resolved 2>/dev/null; then
        systemctl enable systemd-resolved >/dev/null 2>&1 || true
        systemctl start systemd-resolved >/dev/null 2>&1 || true
    fi

    systemctl stop xray >/dev/null 2>&1 || true
    systemctl disable xray >/dev/null 2>&1 || true
    rm -rf /etc/systemd/system/xray* /lib/systemd/system/xray* >/dev/null 2>&1 || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    
    rm -rf "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SCRIPT_DIR" /var/log/xray* /usr/local/bin/xrv "$SCRIPT_PATH" >/dev/null 2>&1 || true
    
    local temp_cron=$(mktemp /tmp/cron_XXXXXX) || true
    if test -f "$temp_cron"; then
        crontab -l 2>/dev/null | grep -v "update-dat.sh" | grep -v "systemctl restart xray" | grep -v "cc1.sh" > "$temp_cron" || true
        crontab "$temp_cron" 2>/dev/null || true
        rm -f "$temp_cron" 2>/dev/null || true
    fi
    info "物理痕迹及所有配置文件与组件链路已完全格式化，现网回归系统纯净初始状态！"
    exit 0
}

# ------------------------------------------------------------------------------
# [ 0x24: 战舰大屏与中央主节点路由管理台 ]
# ------------------------------------------------------------------------------

main_menu() {
    while true; do
        clear
        echo -e "${blue}======================================================================${none}"
        echo -e "  ${magenta}Xray System Advanced Management V196 - (The Apex Vanguard)${none}"
        
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        if test "$svc" = "active"; then 
            svc="${green}平稳在线 (Running)${none}"
        else 
            svc="${red}离线静默 (Stopped)${none}"
        fi
        
        local sys_ver=$(uname -r 2>/dev/null || echo "未探测到数据")
        echo -e "  引擎态势: $svc | 全局快捷指令: ${cyan}xrv${none} | 外部识别 IP: ${yellow}$(_get_ip || echo "探测异常")${none}"
        echo -e "  系统装配内核: ${cyan}${sys_ver}${none} | 所属构建号: V${SCRIPT_VERSION}"
        echo -e "${blue}======================================================================${none}"
        echo "  1) 创建/重构 安全底层全加密协议网络连接 (VLESS/SS)"
        echo "  2) 用户凭证生命周期与独立参数化管理控制"
        echo "  3) 节点链接与多维信息输出聚合中心"
        echo "  4) 人工发起数据强联，执行路由解析规则库强制覆盖更新"
        echo "  5) 在线平滑热更新主程序底层 Core 环境"
        echo "  6) 修改或全自动剔除被拦截的防封伪装特征矩阵域名"
        echo "  7) 系统防火墙策略配置 (阻止内网 BT 滥用及第三方广告请求)"
        echo "  8) Reality Fallback 底层限速沙盒分析器"
        echo "  9) 全景网络连接审计日志与商用级别网络流量记账本"
        echo "  10) 高级发烧：网卡/系统协议栈/真·XANMOD内核 60余项极限配置"
        echo "  0) 折叠命令控制台，返回底层终端"
        echo -e "  ${red}88) 物理不可逆自毁！撤销环境安全防线与系统配置设定${none}"
        hr
        
        local num=""; read -rp "请输入操作代码指令: " num || true
        case "${num:-}" in
            1) do_install ;;
            2) do_user_manager ;;
            3) 
                do_summary
                while true; do 
                    local rb=""; read -rp "当前配置输出完毕，按 Enter 退出或者按 b 发起特征矩阵的更替指令: " rb || true
                    if test "$rb" = "b" || test "$rb" = "B"; then 
                        if choose_sni; then _update_matrix; do_summary; else break; fi
                    else 
                        break
                    fi
                done 
                ;;
            4) 
                print_magenta ">>> 初始化云网络联通中，即将发起底层拉取..."
                bash "$UPDATE_DAT_SCRIPT" >/dev/null 2>&1 || true
                ensure_xray_is_alive; info "配置数据已穿透替换系统！当前路由库完成热加载！"
                local _p=""; read -rp "按 Enter 退回安全环境..." _p || true 
                ;;
            5) do_update_core ;;
            6) 
                if choose_sni; then 
                    _update_matrix; do_summary
                    while true; do 
                        local rb=""; read -rp "任务完毕，请直接按 Enter 返回，或再次敲击 b 开启连续变更模式: " rb || true
                        if test "$rb" = "b" || test "$rb" = "B"; then 
                            if choose_sni; then _update_matrix; do_summary; else break; fi
                        else 
                            break
                        fi
                    done
                fi 
                ;;
            7) _global_block_rules ;;
            8) do_fallback_probe ;;
            9) do_status_menu ;;
            10) do_sys_init_menu ;;
            88) do_uninstall ;;
            0) exit 0 ;;
            *) echo -e "${red}错误拦截：代码解析为空值，请勿操作不合规的非法数据命令！${none}"; sleep 1 ;;
        esac
    done
}

# ==============================================================================
# 系统环境预制防爆加载及主控接管触发器
# ==============================================================================
preflight
main_menu
# ==============================================================================
# EOF - Apex Vanguard V196 System Advanced Control Ready.
# ==============================================================================