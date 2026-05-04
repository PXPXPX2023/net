#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: ex196e41.sh (The Apex Vanguard - Project Genesis V196e41)
# 快捷方式: xrv
#
# 【V196e41 终极战舰版：粉碎 OOM、动态选库 7.x、全量菜单回归】
#   1. 粉碎 OOM 溢出: 建立 4GB 战舰级 Swap 池，并植入智能并发限流，彻底解决 LD 链接暴毙。
#   2. API 动态分支: 解除 6.x 正则封印，实时抓取包含 7.x 在内最新的 15 个 Xanmod 分支。
#   3. 粉碎编译死结: 物理关闭 CONFIG_IA32_EMULATION，彻底解决 vdso32 与指令集的冲突。
#   4. JQ 绝缘: 100% 覆盖 select(. != null)，深渊级防爆。
# ==============================================================================

if test -z "${BASH_VERSION:-}"; then echo "Error: 请使用 bash 执行本脚本: bash ex196e41.sh"; exit 1; fi
if test "$EUID" -ne 0; then echo -e "\033[31m[致命错误] 触及底层必须拥有最高权限，请使用 root 账户执行！\033[0m"; exit 1; fi

set -euo pipefail
IFS=$' \n\t'
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

readonly red='\033[31m'
readonly yellow='\033[33m'
readonly gray='\033[90m'
readonly green='\033[92m'
readonly blue='\033[94m'
readonly magenta='\033[95m'
readonly cyan='\033[96m'
readonly none='\033[0m'

readonly SCRIPT_VERSION="196e41"
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

_detect_psabi_level() {
    local psabi_output=""
    psabi_output=$(awk 'BEGIN {
        while (!/flags/) if (getline < "/proc/cpuinfo" != 1) exit 1
        if (/lm/&&/cmov/&&/cx8/&&/fpu/&&/fxsr/&&/mmx/&&/syscall/&&/sse2/) level = 1
        if (level == 1 && /cx16/&&/lahf/&&/popcnt/&&/sse4_1/&&/sse4_2/&&/ssse3/) level = 2
        if (level == 2 && /avx/&&/avx2/&&/bmi1/&&/bmi2/&&/f16c/&&/fma/&&/abm/&&/movbe/&&/xsave/) level = 3
        if (level == 3 && /avx512f/&&/avx512bw/&&/avx512cd/&&/avx512dq/&&/avx512vl/) level = 4
        if (level > 0) { print level; exit }
        exit 1
    }' /proc/cpuinfo 2>/dev/null || echo "1")
    local level=$(printf '%s' "$psabi_output" | tr -dc '0-9' | head -c 1)
    if test -z "$level"; then level=1; fi
    echo "$level"
}
# --- ✂️ Part 1 结束，请复制并合并下方的 Part 2 ✂️ ---
# --- ✂️ 紧接在 Part 1 之后粘贴此 Part 2 ✂️ ---

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
    rm -f /tmp/sni_array.json /tmp/vless_inbound.json /tmp/vless_final.json /tmp/ss_inbound.json /tmp/new_client.json /tmp/xray_users*.txt /tmp/install-release.sh /tmp/sni_test.* /tmp/check_x86-64_psabi.sh /tmp/current_cron /tmp/kernel-arch.cfg 2>/dev/null || true
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
        if test -z "$temp_ip"; then temp_ip=$(curl -k -s -4 --connect-timeout 3 https://ifconfig.me 2>/dev/null | tr -d '\r\n' || echo ""); fi
        set -e
        if test -z "$temp_ip"; then GLOBAL_IP="获取失败"; else GLOBAL_IP="$temp_ip"; fi
    fi
    echo "$GLOBAL_IP"
}
# --- ✂️ Part 2 结束，请复制并合并下方的 Part 3 ✂️ ---
# --- ✂️ 紧接在 Part 2 之后粘贴此 Part 3 ✂️ ---

validate_port() {
    local p="$1"
    if test -z "$p"; then return 1; fi
    if ! [[ "$p" =~ ^[0-9]+$ ]]; then return 1; fi
    if test "$p" -lt 1 2>/dev/null || test "$p" -gt 65535 2>/dev/null; then return 1; fi
    if ss -tuln 2>/dev/null | grep -q ":${p} "; then error "端口 $p 已被系统占用。"; return 1; fi
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
    if test -f /etc/os-release; then . /etc/os-release; echo "${ID:-unknown}"; else echo "unknown"; fi
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
# --- ✂️ Part 3 结束，请复制并合并下方的 Part 4 ✂️ ---
# --- ✂️ 紧接在 Part 3 之后粘贴此 Part 4 ✂️ ---

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
# --- ✂️ Part 4 结束，请复制并合并下方的 Part 5 ✂️ ---
# --- ✂️ 紧接在 Part 4 之后粘贴此 Part 5 ✂️ ---

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
# --- ✂️ Part 5 结束，请复制并合并下方的 Part 6 ✂️ ---
# --- ✂️ 紧接在 Part 5 之后粘贴此 Part 6 ✂️ ---

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
# --- ✂️ Part 6 结束，请复制并合并下方的 Part 7 ✂️ ---
# --- ✂️ 紧接在 Part 6 之后粘贴此 Part 7 ✂️ ---

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
# --- ✂️ Part 7 结束，请复制并合并下方的 Part 8 ✂️ ---
# --- ✂️ 紧接在 Part 7 之后粘贴此 Part 8 ✂️ ---

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

check_and_create_swap() {
    title "检查并配置物理 Swap 防爆缓冲池"
    local SWAP_FILE="/swapfile"
    local CURRENT_SWAP=""
    
    set +e
    CURRENT_SWAP=$(swapon --show=NAME,KBYTES --noheadings 2>/dev/null | grep "$SWAP_FILE" | awk '{print $2}' || echo "")
    set -e
    
    if test -n "$CURRENT_SWAP" && test "$CURRENT_SWAP" -ge 3000000 2>/dev/null; then
        info "系统已配置足量的战舰级 Swap 分区 (≥3GB)，足以抵御内核 LD 并发冲击。"
        return
    fi
    
    warn "检测到 Swap 缓冲池不足！大型内核链接阶段极易触发物理内存溢出 (OOM)..."
    warn "正在强行切辟 4GB 战舰级 Swap 缓冲分区..."
    swapoff -a 2>/dev/null || true
    sed -i '/swapfile/d' /etc/fstab 2>/dev/null || true
    rm -f "$SWAP_FILE" 2>/dev/null || true
    
    local root_free=$(df -m / 2>/dev/null | awk 'NR==2{print $4}' || echo "0")
    local swap_size=4096
    if test "$root_free" -lt 6000 2>/dev/null; then swap_size=2048; fi
    if test "$root_free" -lt 3000 2>/dev/null; then swap_size=1024; fi

    info "根据磁盘可用空间 ($root_free MB)，动态分配缓冲池大小为: ${swap_size}MB"
    
    if ! fallocate -l ${swap_size}M "$SWAP_FILE" 2>/dev/null; then
        warn "fallocate 创建失败，触发容灾降级，正使用 dd 建立 Swap (可能耗时较长)..."
        dd if=/dev/zero of="$SWAP_FILE" bs=1M count=${swap_size} status=none 2>/dev/null || true
    fi
    
    chmod 600 "$SWAP_FILE" 2>/dev/null || true
    mkswap "$SWAP_FILE" >/dev/null 2>&1 || true
    swapon "$SWAP_FILE" >/dev/null 2>&1 || true
    echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab 2>/dev/null || true
    info "Swap 防爆缓冲池组建完成。"
}
# --- ✂️ Part 8 结束，请复制并合并下方的 Part 9 ✂️ ---
# --- ✂️ 紧接在 Part 8 之后粘贴此 Part 9 ✂️ ---

do_install_xanmod_official_fusion() {
    title "系统飞升：安装官方预编译 XANMOD 内核 (APT 双轨融合版)"
    
    local cpu_arch=$(uname -m 2>/dev/null || echo "")
    if [ "$cpu_arch" != "x86_64" ]; then 
        error "官方源安装当前仅支持 x86_64 架构！"; return 1
    fi
    if [ ! -r /etc/os-release ]; then
        error "无法确定操作系统类型！"; return 1
    fi
    
    . /etc/os-release
    if [ "$ID" != "debian" ] && [ "$ID" != "ubuntu" ]; then
        error "官方源仅支持 Debian 和 Ubuntu 系统！"; return 1
    fi

    local os_codename="${VERSION_CODENAME:-}"
    if ! echo "bookworm trixie forky sid noble plucky questing resolute faye gigi wilma xia zara zena" | grep -qw "$os_codename"; then
        os_codename="releases"
    fi
    
    if echo "jammy focal bullseye buster" | grep -qw "$os_codename" || [ "$os_codename" = "releases" ]; then
        warn "XanMod 官方可能已停止对老系统($os_codename)的 APT 支持，将尝试降级使用 releases 通道。"
        os_codename="releases"
    fi

    local psabi_level=$(_detect_psabi_level)
    if [ "$psabi_level" -gt 3 ]; then psabi_level=3; fi
    info "智能侦测完成：当前 CPU 支持 x86-64-v${psabi_level}"

    info "正在配置官方 APT 溯源仓库..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y wget gnupg ca-certificates >/dev/null 2>&1 || true

    local keyring="/usr/share/keyrings/xanmod-archive-keyring.gpg"
    local list_file="/etc/apt/sources.list.d/xanmod-release.list"
    local key_url="https://dl.xanmod.org/archive.key"

    mkdir -p /usr/share/keyrings /etc/apt/sources.list.d 2>/dev/null || true
    if ! wget -qO - "$key_url" | gpg --dearmor -o "$keyring" --yes 2>/dev/null; then
        error "官方密钥下载失败，XanMod 源配置异常！"
        return 1
    fi
    chmod 644 "$keyring" 2>/dev/null || true
    echo "deb [signed-by=$keyring] http://deb.xanmod.org $os_codename main" > "$list_file"

    apt-get update -y >/dev/null 2>&1 || true
    
    local pkg_name=""
    local installed=false
    local prefix_list="linux-xanmod linux-xanmod-lts"
    
    for prefix in $prefix_list; do
        local level="$psabi_level"
        while [ "$level" -ge 1 ]; do
            local package="${prefix}-x64v${level}"
            if apt-cache policy "$package" 2>/dev/null | grep -q 'Candidate: [^ ]'; then
                info "锁定最优兼容包: $package"
                if apt-get install -y "$package"; then
                    pkg_name="$package"
                    installed=true
                    print_green ">>> 成功安装核心包: $pkg_name"
                    break 2
                fi
            fi
            level=$((level - 1))
        done
    done

    if [ "$installed" = "false" ]; then
        error "软件源中未找到适配此 CPU 的 XanMod 内核包！"
        return 1
    fi

    info "预编译核心注入成功，重载 GRUB..."
    update-grub >/dev/null 2>&1 || true
    warn "系统将在 10 秒后重启以激活新内核..."
    sleep 10
    reboot
}
# --- ✂️ Part 9 结束，请复制并合并下方的 Part 10 ✂️ ---
# --- ✂️ 紧接在 Part 9 之后粘贴此 Part 10 ✂️ ---

_fetch_xanmod_tags() {
    info "正在连接 GitLab API 实时检索最新 Xanmod 内核分支库..."
    local api_url="https://gitlab.com/api/v4/projects/xanmod%2Flinux/repository/tags?per_page=50"
    local tags_json=""
    set +e
    tags_json=$(curl -sL --connect-timeout 10 "$api_url")
    set -e
    
    local default_tag="6.18.25-rt-xanmod1"
    local fallback_tags=("$default_tag" "7.0.2-xanmod1" "6.13.4-xanmod1")
    
    if test -z "$tags_json" || echo "$tags_json" | grep -q "message"; then
        warn "API 检索超时或受阻，启用本地备用版本清单..."
        TAG_LIST=("${fallback_tags[@]}")
    else
        # 解除 6.x 限制：使用 ^[6-9]\. 允许 7.x 及以上内核的实时探测
        mapfile -t TAG_LIST < <(echo "$tags_json" | jq -r '.[].name' | grep -vE "rc|beta" | grep -E "^[6-9]\.[0-9]+\.[0-9]+(-rt)?-xanmod[0-9]+$" | head -n 15)
        # 强制植入用户指定的置顶默认防爆版
        if [[ ! " ${TAG_LIST[*]} " =~ " ${default_tag} " ]]; then
            TAG_LIST=("$default_tag" "${TAG_LIST[@]}")
        fi
    fi
    
    echo -e "\n${cyan}【检索到的最新 Xanmod 内核分支 (实时动态)】${none}"
    local i=1
    for tag in "${TAG_LIST[@]}"; do
        if [ "$tag" = "$default_tag" ]; then
            echo -e "  ${magenta}$i) $tag (预设防爆推荐版)${none}"
        else
            echo -e "  $i) $tag"
        fi
        i=$((i + 1))
    done
    echo "  0) 手动输入特定的 Tag 名称"
    
    local sel=""
    read -rp "请输入所需编译的版本编号 (默认 1): " sel || true
    sel=${sel:-1}
    
    if test "$sel" = "0"; then
        read -rp "请精准输入 Tag 名称 (例如 7.0.2-xanmod1): " LATEST_TAG
    else
        local idx=$((sel - 1))
        LATEST_TAG="${TAG_LIST[$idx]:-$default_tag}"
    fi
    info "已锁定目标编译版本: $LATEST_TAG"
}

_prepare_compile_env() {
    info "=== 开始执行深度系统清理与模块解容 ==="
    export DEBIAN_FRONTEND=noninteractive
    apt-get clean >/dev/null 2>&1 || true
    apt-get autoremove -y --purge >/dev/null 2>&1 || true
    journalctl --vacuum-time=1d >/dev/null 2>&1 || true
    
    rm -rf /var/log/*.log /var/log/*/*.log /tmp/* /var/lib/docker/* /usr/src/linux* /usr/src/bbr* /usr/src/xanmod* /compile/* /root/linux* /root/*.tar* /root/*.gz /root/*.xz 2>/dev/null || true
    sync

    local inode_use=$(df -i / 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%' || echo "0")
    if test "$inode_use" -gt 90 2>/dev/null; then apt-get clean >/dev/null 2>&1 || true; rm -rf /var/cache/* 2>/dev/null || true; fi

    check_and_create_swap

    local root_free=$(df -m / 2>/dev/null | awk 'NR==2{print $4}' || echo "0")
    BUILD_DIR=""
    if test "$root_free" -gt 4000 2>/dev/null; then 
        mkdir -p /compile 2>/dev/null || true
        BUILD_DIR="/compile"
    else 
        BUILD_DIR="/usr/src"
    fi

    info "=== 拉取核心编译套件 ==="
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y build-essential bc bison flex libssl-dev libelf-dev libncurses-dev zstd git wget curl xz-utils ethtool numactl make pkg-config dwarves rsync python3 libdw-dev cpio jq >/dev/null 2>&1 || true

    CPU=$(nproc 2>/dev/null || echo 1)
    local RAM=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo 1024)
    THREADS=$CPU
    
    # 【智能防爆】：如果物理内存极低，在链接阶段依然可能因为高并发导致 OOM
    if test "$RAM" -lt 3000 2>/dev/null; then 
        if test "$THREADS" -gt 2 2>/dev/null; then THREADS=2; fi
        info "物理内存限制 ($RAM MB)，为防止多核并发链接引发系统 OOM，强制锁定编译线程为 $THREADS。"
    fi
    
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if ! cd "$BUILD_DIR"; then die "权限异常：系统拒绝切入工作区 $BUILD_DIR。"; fi
}
# --- ✂️ Part 10 结束，请复制并合并下方的 Part 11 ✂️ ---
# --- ✂️ 紧接在 Part 10 之后粘贴此 Part 11 ✂️ ---

_execute_compilation() {
    local extra_make_args="${1:-}"
    info "=== 开启多核并发编译 (线程数: $THREADS) ==="
    if ! make -j"$THREADS" $extra_make_args; then
        error "编译线程彻底崩塌！这通常是由于物理内存加上 Swap 依然耗尽导致的 OOM。"
        local _p=""; read -rp "按 Enter 返回主菜单..." _p || true
        return 1
    fi

    info "编译成功！正在部署内核与构建模块..."
    make modules_install >/dev/null 2>&1 || true
    make install >/dev/null 2>&1 || true

    local COMPILED_VER=$(make kernelversion 2>/dev/null || echo "")
    if test -n "$COMPILED_VER"; then info "内核 ($COMPILED_VER) 已注入宿主机核心。"; fi

    # 【绝对核心修复】：保留所有旧版内核作为 GRUB 备用防爆退路，不再进行任何 dpkg purge 的自杀式删除！
    info "保留旧版内核以备万一，正在安全重载 GRUB..."
    update-grub >/dev/null 2>&1 || true

    info "=== 注入网卡与 RPS 软中断特化守护进程 ==="
    if test -n "$IFACE"; then
        cat > /usr/local/bin/nic-optimize.sh <<EOF_NIC
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IFACE="$IFACE"
ethtool -K \$IFACE gro off gso off tso off lro off rx-gro-hw off tx-udp-segmentation on 2>/dev/null || true
ethtool -C \$IFACE adaptive-rx off rx-usecs 0 tx-usecs 0 2>/dev/null || true
EOF_NIC
        chmod +x /usr/local/bin/nic-optimize.sh 2>/dev/null || true

        cat > /etc/systemd/system/nic-optimize.service <<'EOSERVICE'
[Unit]
Description=NIC Hardware Optimization
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/nic-optimize.sh
TimeoutSec=30
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOSERVICE
        systemctl daemon-reload >/dev/null 2>&1 || true
        systemctl enable nic-optimize.service >/dev/null 2>&1 || true
        systemctl start nic-optimize.service >/dev/null 2>&1 || true

        local RXMAX=$(ethtool -g "$IFACE" 2>/dev/null | awk '/RX:/ {print $2; exit}' || echo "")
        if test -n "$RXMAX"; then ethtool -G "$IFACE" rx "$RXMAX" tx "$RXMAX" 2>/dev/null || true; fi

        local CPU_MASK=$(printf "%x" $(( (1<<CPU)-1 )))
        cat > /usr/local/bin/rps-optimize.sh <<EOF_RPS
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IFACE="$IFACE"
CPU_MASK="$CPU_MASK"
RX_QUEUES=\$(ls -d /sys/class/net/\$IFACE/queues/rx-* 2>/dev/null | wc -l || echo 0)
for RX in /sys/class/net/\$IFACE/queues/rx-*; do
    if test -w "\$RX/rps_cpus"; then echo "\$CPU_MASK" > "\$RX/rps_cpus" 2>/dev/null || true; fi
done
for TX in /sys/class/net/\$IFACE/queues/tx-*; do
    if test -w "\$TX/xps_cpus"; then echo "\$CPU_MASK" > "\$TX/xps_cpus" 2>/dev/null || true; fi
done
sysctl -w net.core.rps_sock_flow_entries=131072 >/dev/null 2>&1 || true
if test "\$RX_QUEUES" -gt 0 2>/dev/null; then
    FLOW_PER_QUEUE=\$((65535 / RX_QUEUES))
    for RX in /sys/class/net/\$IFACE/queues/rx-*; do
        if test -w "\$RX/rps_flow_cnt"; then echo "\$FLOW_PER_QUEUE" > "\$RX/rps_flow_cnt" 2>/dev/null || true; fi
    done
fi
EOF_RPS
        chmod +x /usr/local/bin/rps-optimize.sh 2>/dev/null || true

        cat > /etc/systemd/system/rps-optimize.service <<'EOF_RPS_SRV'
[Unit]
Description=RPS RFS Network CPU Optimization
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

        for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || true); do 
            if test -w "/proc/irq/$irq/smp_affinity"; then echo "$CPU_MASK" > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true; fi
        done
    fi

    cd /
    rm -rf "$BUILD_DIR/"* "$BUILD_DIR/$KERNEL_FILE" /compile/* /root/linux* /root/*.tar* 2>/dev/null || true
    info "内核编译与结构优化已全部就绪！系统将在 30 秒后强制重启..."
    sleep 30
    reboot
}
# --- ✂️ Part 11 结束，请复制并合并下方的 Part 12 ✂️ ---
# --- ✂️ 紧接在 Part 11 之后粘贴此 Part 12 ✂️ ---

_compile_kernel_mainline() {
    local bbr_type="${1:-bbr}"
    local title_suffix="BBR"
    if [ "$bbr_type" = "bbr3" ]; then title_suffix="BBR3"; fi
    
    title "系统飞升：极客编译 Linux 官方主线最新内核 (源码版 + $title_suffix)"
    warn "警告: 此过程将极度消耗 CPU 与内存 (约 30-60 分钟)，低配机极易死机！"
    local confirm=""; read -rp "确定要开始编译吗？(y/n): " confirm || true
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then return; fi
    _prepare_compile_env

    info "=== 动态连接 Kernel.org 溯源官方最新主线源码 ==="
    set +e
    local KERNEL_URL=$(curl -s https://www.kernel.org/releases.json | jq -r '.releases[] | select(.id != null and .moniker=="mainline") | .source' | head -n 1)
    if test -z "$KERNEL_URL" || test "$KERNEL_URL" = "null"; then
        warn "动态寻址失败，启用容灾通道下载稳定版！"
        KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.14.tar.xz"
    fi
    set -e
    
    local KERNEL_FILE=$(basename "$KERNEL_URL")
    info "正在拉取真·官方主线源码包: $KERNEL_FILE"
    wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"

    set +o pipefail
    if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
        warn "压缩包校验失败，重试..."
        rm -f "$KERNEL_FILE" 2>/dev/null || true
        wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"
        if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then error "源码包损坏。"; set -e; return 1; fi
    fi
    set -o pipefail

    info "执行极限解压..."
    tar -xJf "$KERNEL_FILE"
    local KERNEL_DIR=$(tar -tf "$KERNEL_FILE" | head -1 | cut -d/ -f1)
    if ! cd "$KERNEL_DIR"; then die "解压后目录切入失败。"; fi

    info "=== 生成并清洗内核配置 (纯净主线 + 极速补齐) ==="
    
    if test -f "/boot/config-$(uname -r)"; then
        info "正在继承当前宿主机驱动配置以保证完美兼容..."
        cp "/boot/config-$(uname -r)" .config
        
        info ">> 启动自动依赖补全：粉碎 make 交互式卡死陷阱..."
        make olddefconfig >/dev/null 2>&1 || true
        
        info ">> 启动终极清道夫：物理抹除宿主机自带的 PEM 签名证书依赖..."
        sed -i 's/CONFIG_SYSTEM_TRUSTED_KEYS=.*/CONFIG_SYSTEM_TRUSTED_KEYS=""/g' .config 2>/dev/null || true
        sed -i 's/CONFIG_SYSTEM_REVOCATION_KEYS=.*/CONFIG_SYSTEM_REVOCATION_KEYS=""/g' .config 2>/dev/null || true
        sed -i 's/CONFIG_MODULE_SIG_KEY=.*/CONFIG_MODULE_SIG_KEY=""/g' .config 2>/dev/null || true
    else
        warn "未找到宿主机驱动配置文件，启用回退 defconfig 模式..."
        make defconfig >/dev/null 2>&1 || true
    fi

    # 【终极防爆】：物理斩除 32 位兼容层，防止 x86-64-vX 编译 32 位目标时暴毙
    info ">> 正在斩除 32位 (IA32) 兼容层，彻底粉碎 vdso32 与指令集的编译冲突..."
    ./scripts/config --disable CONFIG_IA32_EMULATION
    ./scripts/config --disable CONFIG_X86_X32
    ./scripts/config --disable CONFIG_COMPAT_32
    ./scripts/config --disable CONFIG_COMPAT

    # 移除危险的 Debug 及模块签名限制
    ./scripts/config --disable CONFIG_MODULE_SIG
    ./scripts/config --disable CONFIG_MODULE_SIG_ALL
    ./scripts/config --disable CONFIG_MODULE_SIG_FORCE
    ./scripts/config --disable CONFIG_DEBUG_INFO
    ./scripts/config --disable CONFIG_DEBUG_INFO_BTF
    
    ./scripts/config --enable CONFIG_TCP_CONG_BBR 2>/dev/null || true
    ./scripts/config --enable CONFIG_DEFAULT_BBR 2>/dev/null || true
    
    if [ "$bbr_type" = "bbr3" ]; then
        info ">>> 检测到强开 BBR3 指令，注入 BBR3 协议栈..."
        ./scripts/config --enable CONFIG_TCP_BBR3 2>/dev/null || true
    fi
    
    info ">> 正在生成最终架构图谱，二次加固防爆盾..."
    make olddefconfig >/dev/null 2>&1 || true
    
    _execute_compilation ""
}
# --- ✂️ Part 12 结束，请复制并合并下方的 Part 13 ✂️ ---
# --- ✂️ 紧接在 Part 12 之后粘贴此 Part 13 ✂️ ---

_compile_kernel_xanmod() {
    title "系统飞升：极客源码编译 真·Xanmod 内核 (全自动防爆防卡死版)"
    warn "警告: 此过程将极度消耗 CPU 与内存 (约 30-60 分钟)，低配机极易死机！"
    local confirm=""; read -rp "确定要开始极客源码编译吗？(y/n): " confirm || true
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then return; fi
    
    # 调用 API 获取动态内核版本菜单
    _fetch_xanmod_tags
    
    local psabi_val=$(_detect_psabi_level)
    info ">> 智能探针预警：将强制以 x86-64-v${psabi_val} 指令集等级进行精准编译！"

    _prepare_compile_env

    info "=== 开始拉取 GitLab 指定的 Xanmod 官方源码 [ ${LATEST_TAG} ] ==="
    local KERNEL_URL="https://gitlab.com/xanmod/linux/-/archive/${LATEST_TAG}/linux-${LATEST_TAG}.tar.gz"
    local KERNEL_FILE="${LATEST_TAG}.tar.gz"
    
    wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"

    set +o pipefail
    if ! tar -tzf "$KERNEL_FILE" >/dev/null 2>&1; then
        warn "指定的版本压缩包拉取或校验失败，触发全网降级检索..."
        rm -f "$KERNEL_FILE" 2>/dev/null || true
        set +e
        LATEST_TAG=$(curl -sL --connect-timeout 10 https://gitlab.com/api/v4/projects/xanmod%2Flinux/repository/tags | jq -r '.[].name' 2>/dev/null | grep -vE "rc|beta" | grep -E "^[6-9]\.[0-9]+\.[0-9]+(-rt)?-xanmod[0-9]+$" | head -n 1 || echo "6.18.25-rt-xanmod1")
        set -e
        KERNEL_URL="https://gitlab.com/xanmod/linux/-/archive/${LATEST_TAG}/linux-${LATEST_TAG}.tar.gz"
        KERNEL_FILE="${LATEST_TAG}.tar.gz"
        info "正在重试拉取兜底稳定版源码包: $KERNEL_FILE"
        wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"
        if ! tar -tzf "$KERNEL_FILE" >/dev/null 2>&1; then error "源码包彻底损坏。"; set -e; return 1; fi
    fi
    set -o pipefail

    info "执行极限解压..."
    tar -xzf "$KERNEL_FILE"
    local KERNEL_DIR=$(tar -tf "$KERNEL_FILE" | head -1 | cut -d/ -f1)
    if ! cd "$KERNEL_DIR"; then die "解压后目录切入失败。"; fi

    info "=== 生成并清洗内核配置 (真·Xanmod + 继承驱动防断网) ==="
    
    if test -f "/boot/config-$(uname -r)"; then
        info "正在继承当前宿主机驱动配置以保证完美兼容..."
        cp "/boot/config-$(uname -r)" .config
        
        info ">> 正在抹杀所有交互式提问 (执行 make olddefconfig)..."
        make olddefconfig >/dev/null 2>&1 || true
        
        sed -i 's/CONFIG_SYSTEM_TRUSTED_KEYS=.*/CONFIG_SYSTEM_TRUSTED_KEYS=""/g' .config 2>/dev/null || true
        sed -i 's/CONFIG_SYSTEM_REVOCATION_KEYS=.*/CONFIG_SYSTEM_REVOCATION_KEYS=""/g' .config 2>/dev/null || true
        sed -i 's/CONFIG_MODULE_SIG_KEY=.*/CONFIG_MODULE_SIG_KEY=""/g' .config 2>/dev/null || true
    else
        warn "未找到宿主机驱动配置文件，启用回退 defconfig 模式..."
        make defconfig >/dev/null 2>&1 || true
    fi

    # 【神级防爆 1】：直接关闭 32 位兼容层，这是阻断 vdso32 编译崩溃的最强真理！
    info ">> 正在斩除 32位 (IA32) 兼容层，彻底粉碎 vdso32 与指令集的编译冲突..."
    ./scripts/config --disable CONFIG_IA32_EMULATION
    ./scripts/config --disable CONFIG_X86_X32
    ./scripts/config --disable CONFIG_COMPAT_32
    ./scripts/config --disable CONFIG_COMPAT

    # 【神级防爆 2】：VDSO32 底层补丁防御 (为旧内核打底，防止残骸触发报错)
    if test -f "arch/x86/entry/vdso/Makefile"; then
        echo 'KBUILD_CFLAGS_32 := $(filter-out -march=x86-64-v% -fcf-protection%, $(KBUILD_CFLAGS_32))' >> arch/x86/entry/vdso/Makefile
        echo 'CFLAGS_REMOVE_vclock_gettime.o += -march=x86-64-v1 -march=x86-64-v2 -march=x86-64-v3 -march=x86-64-v4 -fcf-protection=branch' >> arch/x86/entry/vdso/Makefile
    fi

    # 精准限定 CONFIG_X86_64_VERSION，写入合法架构性能！
    info ">> 正在将 Xanmod 专有 CPU 控制参数硬编码锁定至等级 ${psabi_val}..."
    ./scripts/config --disable CONFIG_GENERIC_CPU2 2>/dev/null || true
    ./scripts/config --disable CONFIG_GENERIC_CPU3 2>/dev/null || true
    ./scripts/config --disable CONFIG_GENERIC_CPU4 2>/dev/null || true
    ./scripts/config --enable CONFIG_GENERIC_CPU1 2>/dev/null || true
    ./scripts/config --enable CONFIG_GENERIC_CPU 2>/dev/null || true
    ./scripts/config --set-val CONFIG_X86_64_VERSION "$psabi_val" 2>/dev/null || true

    ./scripts/config --disable CONFIG_DEBUG_INFO
    ./scripts/config --disable CONFIG_DEBUG_INFO_BTF
    ./scripts/config --disable CONFIG_MODULE_SIG
    
    ./scripts/config --enable CONFIG_TCP_CONG_BBR 2>/dev/null || true
    ./scripts/config --enable CONFIG_DEFAULT_BBR 2>/dev/null || true
    ./scripts/config --enable CONFIG_TCP_BBR3 2>/dev/null || true
    
    info ">> 正在执行依赖树重组与收尾固化..."
    make olddefconfig >/dev/null 2>&1 || true
    
    _execute_compilation "CONFIG_X86_64_VERSION=$psabi_val"
}
# --- ✂️ Part 13 结束，请复制并合并下方的 Part 14 ✂️ ---
# --- ✂️ 紧接在 Part 13 之后粘贴此 Part 14 ✂️ ---

# ------------------------------------------------------------------------------
# [ 0x09: 系统内核网络栈极限压榨 (全量 60+ 项网络栈阵列调优) ]
# ------------------------------------------------------------------------------
do_perf_tuning() {
    title "极客压榨：全域系统底层网络栈结构重塑"
    warn "警告: 此操作将深度注入内核级极限并发参数，执行完毕必须重启宿主机！"
    
    local confirm=""
    read -rp "确定要继续吗？(y/n): " confirm || true
    if test "$confirm" != "y" && test "$confirm" != "Y"; then return; fi
    
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
    rm -f /etc/systemd/system/net-speeder.service /etc/systemd/system/multi-user.target.wants/net-speeder.service 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true

    truncate -s 0 /etc/sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-network-optimized.conf 2>/dev/null || true
    rm -f /etc/sysctl.d/99-bbr*.conf /etc/sysctl.d/99-ipv6-disable.conf /etc/sysctl.d/99-pro*.conf /etc/sysctl.d/99-xanmod-bbr3.conf /usr/lib/sysctl.d/50-pid-max.conf /usr/lib/sysctl.d/99-protect-links.conf 2>/dev/null || true

    info "配置系统高并发进程限制 (Limits)..."
    cat > /etc/security/limits.conf << 'EOF'
root soft nofile 1000000
root hard nofile 1000000
root soft nproc 1000000
root hard nproc 1000000
root soft core 1000000
root hard core 1000000
root soft stack 1000000
root hard stack 1000000

* soft nofile 1000000
* hard nofile 1000000
* soft nproc 1000000
* hard nproc 1000000
* soft core 1000000
* hard core 1000000
* soft stack 1000000
* hard stack 1000000
EOF

    if ! grep -q "pam_limits.so" /etc/pam.d/common-session 2>/dev/null; then echo "session required pam_limits.so" >> /etc/pam.d/common-session; fi
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session-noninteractive 2>/dev/null; then echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive; fi
    
    sed -i '/DefaultLimitNOFILE/d' /etc/systemd/system.conf 2>/dev/null || true
    sed -i '/DefaultLimitNPROC/d' /etc/systemd/system.conf 2>/dev/null || true
    echo "DefaultLimitNOFILE=1000000" >> /etc/systemd/system.conf
    echo "DefaultLimitNPROC=1000000" >> /etc/systemd/system.conf

    local target_qdisc="fq"
    local cake_state="false"
    if sysctl net.core.default_qdisc 2>/dev/null | grep -q 'cake'; then cake_state="true"; fi
    if test "$cake_state" = "true"; then target_qdisc="cake"; fi

    info "写入内核 Sysctl 协议栈参数..."
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

net.ipv4.igmp_max_memberships = 200
net.ipv4.route.flush = 1
net.ipv4.tcp_slow_start_after_idle = 0

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
        info "底层 Sysctl 参数已成功注入。"
    fi
}

# --- ✂️ Part 14 结束，请复制并合并下方的 Part 15 ✂️ ---
# --- ✂️ 紧接在 Part 14 之后粘贴此 Part 15 ✂️ ---

do_txqueuelen_opt() {
    title "网卡发送队列 (TX Queue) 调优"
    local IP_CMD=$(command -v ip || echo "")
    if test -z "$IP_CMD"; then error "系统缺失 iproute2 (ip 命令) 核心组件。"; local _p=""; read -rp "按 Enter 返回..." _p || true; return 1; fi
    local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if test -z "$IFACE"; then error "无法定位系统默认出口网卡。"; local _p=""; read -rp "按 Enter 返回..." _p || true; return 1; fi
    info "正在修改 $IFACE 发送队列长度至 12000..."
    $IP_CMD link set "$IFACE" txqueuelen 12000 2>/dev/null || true
    
    cat > /etc/systemd/system/txqueue.service << EOF
[Unit]
Description=Set TX Queue Length for Low Latency
After=network.target

[Service]
Type=oneshot
ExecStart=$IP_CMD link set $IFACE txqueuelen 12000
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable txqueue >/dev/null 2>&1 || true
    systemctl start txqueue >/dev/null 2>&1 || true
    
    local CHECK_QLEN=$($IP_CMD link show "$IFACE" 2>/dev/null | grep -o 'qlen [0-9]*' | awk '{print $2}' || echo "")
    if test "$CHECK_QLEN" = "12000"; then info "已成功将网卡底层并发队列长度扩容至 12000 级。"; else warn "当前虚拟机或网卡驱动不支持调节 txqueuelen。"; fi
    local _p=""; read -rp "按 Enter 键返回主菜单..." _p || true
}

config_cake_advanced() {
    clear; title "CAKE 拥塞调度器高级微操配置"
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
    
    if test -z "$final_opts"; then rm -f "$CAKE_OPTS_FILE" 2>/dev/null || true; info "已清除所有 CAKE 自定义参数。"; else echo "$final_opts" > "$CAKE_OPTS_FILE"; info "CAKE 高阶参数已写入物理储存。"; fi
    
    modprobe sch_cake >/dev/null 2>&1 || true
    _apply_cake_live
    local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if test -n "$IFACE"; then if tc qdisc show dev "$IFACE" 2>/dev/null | grep -q "cake"; then info "验证通过：CAKE 已成功接管网卡接口！"; else warn "验证失败：网卡未运行 CAKE。"; fi; fi
    local _p=""; read -rp "按 Enter 返回主菜单..." _p || true
}

check_mph_state() { local state=$(jq -r 'select(.routing != null) | .routing.domainMatcher // "false"' "$CONFIG" 2>/dev/null); if [ "$state" = "mph" ]; then echo "true"; else echo "false"; fi; }
check_maxtime_state() { local state=$(jq -r '.inbounds[]? | select(. != null) | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff // "false"' "$CONFIG" 2>/dev/null | head -n 1); if [ "$state" = "60000" ]; then echo "true"; else echo "false"; fi; }
check_routeonly_state() { local state=$(jq -r '.inbounds[]? | select(. != null) | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1); if [ "$state" = "true" ]; then echo "true"; else echo "false"; fi; }
check_sniff_state() { local state=$(jq -r '.inbounds[]? | select(. != null) | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.metadataOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1); if [ "$state" = "true" ]; then echo "true"; else echo "false"; fi; }
check_affinity_state() { local limit_file="/etc/systemd/system/xray.service.d/limits.conf"; if [ -f "$limit_file" ] && grep -q "^CPUAffinity=" "$limit_file" 2>/dev/null; then echo "true"; else echo "false"; fi; }
check_buffer_state() { local limit_file="/etc/systemd/system/xray.service.d/limits.conf"; if [ -f "$limit_file" ] && grep -q "^Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" "$limit_file" 2>/dev/null; then echo "true"; else echo "false"; fi; }
check_dnsmasq_state() { if systemctl is-active dnsmasq >/dev/null 2>&1 && grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null; then echo "true"; else echo "false"; fi; }
check_thp_state() { if [ ! -f "/sys/kernel/mm/transparent_hugepage/enabled" ] || [ ! -w "/sys/kernel/mm/transparent_hugepage/enabled" ]; then echo "unsupported"; return; fi; if grep -q '\[never\]' /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null; then echo "true"; else echo "false"; fi; }
check_mtu_state() { if [ ! -f "/proc/sys/net/ipv4/tcp_mtu_probing" ] || [ ! -w "/proc/sys/net/ipv4/tcp_mtu_probing" ]; then echo "unsupported"; return; fi; if [ "$(sysctl -n net.ipv4.tcp_mtu_probing 2>/dev/null)" = "1" ]; then echo "true"; else echo "false"; fi; }
check_cpu_state() { if [ ! -d "/sys/devices/system/cpu/cpu0/cpufreq" ] || [ ! -w "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor" ]; then echo "unsupported"; return; fi; if grep -q 'performance' /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null; then echo "true"; else echo "false"; fi; }
check_ring_state() { local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo ""); if [ -z "$IFACE" ] || ! command -v ethtool >/dev/null 2>&1 || ! ethtool -g "$IFACE" >/dev/null 2>&1; then echo "unsupported"; return; fi; local curr_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Current hardware settings" | grep "RX:" | head -1 | awk '{print $2}'); if [ -z "$curr_rx" ]; then echo "unsupported"; return; fi; if [ "$curr_rx" = "512" ]; then echo "true"; else echo "false"; fi; }
check_zram_state() { if ! modprobe -n zram >/dev/null 2>&1 && ! lsmod 2>/dev/null | grep -q zram; then echo "unsupported"; return; fi; if swapon --show 2>/dev/null | grep -q 'zram'; then echo "true"; else echo "false"; fi; }
check_journal_state() { if [ ! -f "/etc/systemd/journald.conf" ]; then echo "unsupported"; return; fi; if grep -q '^Storage=volatile' /etc/systemd/journald.conf 2>/dev/null; then echo "true"; else echo "false"; fi; }
check_process_priority_state() { local limit_file="/etc/systemd/system/xray.service.d/limits.conf"; if [ ! -f "$limit_file" ]; then echo "false"; return; fi; if grep -q "^OOMScoreAdjust=-500" "$limit_file" 2>/dev/null; then echo "true"; else echo "false"; fi; }
check_cake_state() { if sysctl net.core.default_qdisc 2>/dev/null | grep -q 'cake'; then echo "true"; else echo "false"; fi; }
check_ackfilter_state() { if test -f "$FLAGS_DIR/ack_filter"; then echo "true"; else echo "false"; fi; }
check_ecn_state() { if test -f "$FLAGS_DIR/ecn"; then echo "true"; else echo "false"; fi; }
check_wash_state() { if test -f "$FLAGS_DIR/wash"; then echo "true"; else echo "false"; fi; }
check_gso_off_state() { local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo ""); if test -z "$IFACE" || ! command -v ethtool >/dev/null 2>&1; then echo "unsupported"; return; fi; local eth_info=$(ethtool -k "$IFACE" 2>/dev/null || echo ""); if echo "$eth_info" | grep -E "^generic-receive-offload:|^rx-gro:" | grep -q "fixed" 2>/dev/null; then echo "unsupported"; return; fi; if echo "$eth_info" | grep -E "^generic-receive-offload:|^rx-gro:" | grep -q " off" 2>/dev/null; then echo "true"; else echo "false"; fi; }
check_irq_state() { local CORES=$(nproc 2>/dev/null || echo 1); if test "$CORES" -lt 2 2>/dev/null; then echo "unsupported"; return; fi; local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo ""); if test -z "$IFACE"; then echo "false"; return; fi; local irq=$(grep "$IFACE" /proc/interrupts 2>/dev/null | head -n 1 | awk '{print $1}' | tr -d ':' || echo ""); if test -n "$irq"; then local mask=$(cat "/proc/irq/$irq/smp_affinity" 2>/dev/null | tr -d '0' || echo ""); if test "$mask" = "1"; then echo "true"; else echo "false"; fi; else echo "false"; fi; }
# --- ✂️ Part 15 结束，请复制并合并下方的 Part 16 ✂️ ---
# --- ✂️ 紧接在 Part 15 之后粘贴此 Part 16 ✂️ ---

update_hw_boot_script() {
    cat << 'EOF' > /usr/local/bin/xray-hw-tweaks.sh
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
if test -z "$IFACE"; then sleep 3; IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo ""); fi
EOF

    if [ "$(check_thp_state)" = "true" ]; then cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
if test -w /sys/kernel/mm/transparent_hugepage/enabled; then echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true; echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true; fi
EOF
    fi

    if [ "$(check_cpu_state)" = "true" ]; then cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do if test -f "$cpu"; then echo performance > "$cpu" 2>/dev/null || true; fi; done
EOF
    fi

    if [ "$(check_ring_state)" = "true" ]; then echo "ethtool -G \$IFACE rx 512 tx 512 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh; fi
    if [ "$(check_gso_off_state)" = "true" ]; then echo "ethtool -K \$IFACE gro off gso off tso off 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh; elif [ "$(check_gso_off_state)" = "false" ]; then echo "ethtool -K \$IFACE gro on gso on tso on 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh; fi
    
    cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
CAKE_OPTS=""
if test -f "/usr/local/etc/xray/cake_opts.txt"; then CAKE_OPTS=$(cat "/usr/local/etc/xray/cake_opts.txt" 2>/dev/null || true); fi
ACK_FLAG=""; if test -f "/usr/local/etc/xray/flags/ack_filter"; then ACK_FLAG="ack-filter"; fi
ECN_FLAG=""; if test -f "/usr/local/etc/xray/flags/ecn"; then ECN_FLAG="ecn"; fi
WASH_FLAG=""; if test -f "/usr/local/etc/xray/flags/wash"; then WASH_FLAG="wash"; fi
EOF

    if [ "$(check_cake_state)" = "true" ]; then echo 'tc qdisc replace dev $IFACE root cake $CAKE_OPTS $ACK_FLAG $ECN_FLAG $WASH_FLAG 2>/dev/null || true' >> /usr/local/bin/xray-hw-tweaks.sh; fi
    if [ "$(check_irq_state)" = "true" ]; then cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
systemctl stop irqbalance 2>/dev/null || true
for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || true); do if test -w "/proc/irq/$irq/smp_affinity"; then echo 1 > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true; fi; done
EOF
    fi

    chmod +x /usr/local/bin/xray-hw-tweaks.sh 2>/dev/null || true

    cat << 'EOF' > /etc/systemd/system/xray-hw-tweaks.service
[Unit]
Description=Xray Hardware Tweaks
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/xray-hw-tweaks.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable xray-hw-tweaks.service >/dev/null 2>&1 || true
}

_apply_cake_live() {
    local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if test -z "$IFACE"; then return; fi
    if test "$(check_cake_state)" = "true"; then
        local base_opts=""; if test -f "$CAKE_OPTS_FILE"; then base_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo ""); fi
        local f_ack=""; if test "$(check_ackfilter_state)" = "true"; then f_ack="ack-filter"; fi
        local f_ecn=""; if test "$(check_ecn_state)" = "true"; then f_ecn="ecn"; fi
        local f_wash=""; if test "$(check_wash_state)" = "true"; then f_wash="wash"; fi
        tc qdisc replace dev "$IFACE" root cake $base_opts $f_ack $f_ecn $f_wash 2>/dev/null || true
    fi
    update_hw_boot_script
}

_toggle_affinity_on() { local limit_file="/etc/systemd/system/xray.service.d/limits.conf"; if [ -f "$limit_file" ]; then sed -i '/^CPUAffinity=/d' "$limit_file" 2>/dev/null || true; sed -i '/^Environment="GOMAXPROCS=/d' "$limit_file" 2>/dev/null || true; local CORES=$(nproc 2>/dev/null || echo 1); local TARGET_CPU="0"; if [ "$CORES" -ge 2 ]; then TARGET_CPU="1"; fi; echo "CPUAffinity=$TARGET_CPU" >> "$limit_file"; echo "Environment=\"GOMAXPROCS=1\"" >> "$limit_file"; systemctl daemon-reload >/dev/null 2>&1 || true; fi; }
_toggle_affinity_off() { local limit_file="/etc/systemd/system/xray.service.d/limits.conf"; if [ -f "$limit_file" ]; then sed -i '/^CPUAffinity=/d' "$limit_file" 2>/dev/null || true; sed -i '/^Environment="GOMAXPROCS=/d' "$limit_file" 2>/dev/null || true; systemctl daemon-reload >/dev/null 2>&1 || true; fi; }

toggle_dnsmasq() {
    if [ "$(check_dnsmasq_state)" = "true" ]; then
        systemctl stop dnsmasq >/dev/null 2>&1 || true; systemctl disable dnsmasq >/dev/null 2>&1 || true; chattr -i /etc/resolv.conf 2>/dev/null || true; rm -f /etc/resolv.conf 2>/dev/null || true; if [ -f /etc/resolv.conf.bak ]; then mv /etc/resolv.conf.bak /etc/resolv.conf; else echo "nameserver 8.8.8.8" > /etc/resolv.conf; fi; systemctl enable systemd-resolved >/dev/null 2>&1 || true; systemctl start systemd-resolved >/dev/null 2>&1 || true; _safe_jq_write 'select(.dns != null) | .dns = {"servers":["https://8.8.8.8/dns-query","https://1.1.1.1/dns-query","https://doh.opendns.com/dns-query"], "queryStrategy":"UseIP"}'
    else
        export DEBIAN_FRONTEND=noninteractive; apt-get update -y >/dev/null 2>&1 || yum makecache -y >/dev/null 2>&1 || true; apt-get install -y dnsmasq >/dev/null 2>&1 || yum install -y dnsmasq >/dev/null 2>&1 || true; systemctl stop systemd-resolved 2>/dev/null || true; systemctl disable systemd-resolved 2>/dev/null || true; systemctl stop resolvconf 2>/dev/null || true
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
        systemctl enable dnsmasq >/dev/null 2>&1 || true; systemctl restart dnsmasq >/dev/null 2>&1 || true; chattr -i /etc/resolv.conf 2>/dev/null || true; if [ ! -f /etc/resolv.conf.bak ]; then cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true; fi; rm -f /etc/resolv.conf 2>/dev/null || true; echo "nameserver 127.0.0.1" > /etc/resolv.conf; chattr +i /etc/resolv.conf 2>/dev/null || true; _safe_jq_write 'select(.dns != null) | .dns = {"servers":["127.0.0.1"], "queryStrategy":"UseIP"}'
    fi
}

toggle_thp() { if [ "$(check_thp_state)" = "true" ]; then echo always > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true; echo always > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true; else echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true; echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true; fi; update_hw_boot_script; }
toggle_mtu() { local conf="/etc/sysctl.d/99-network-optimized.conf"; if [ "$(check_mtu_state)" = "true" ]; then sed -i 's/^net.ipv4.tcp_mtu_probing.*/net.ipv4.tcp_mtu_probing = 0/' "$conf" 2>/dev/null || true; else if grep -q "net.ipv4.tcp_mtu_probing" "$conf" 2>/dev/null; then sed -i 's/^net.ipv4.tcp_mtu_probing.*/net.ipv4.tcp_mtu_probing = 1/' "$conf" 2>/dev/null || true; else echo "net.ipv4.tcp_mtu_probing = 1" >> "$conf"; fi; fi; sysctl -p "$conf" >/dev/null 2>&1 || true; }
toggle_cpu() { if [ "$(check_cpu_state)" = "unsupported" ]; then return; fi; if [ "$(check_cpu_state)" = "true" ]; then for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do if [ -f "$cpu" ]; then echo schedutil > "$cpu" 2>/dev/null || echo ondemand > "$cpu" 2>/dev/null || true; fi; done; else for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do if [ -f "$cpu" ]; then echo performance > "$cpu" 2>/dev/null || true; fi; done; fi; update_hw_boot_script; }
toggle_ring() { local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo ""); if [ "$(check_ring_state)" = "unsupported" ] || [ -z "$IFACE" ]; then return; fi; if [ "$(check_ring_state)" = "true" ]; then local max_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Pre-set maximums" | grep "RX:" | head -1 | awk '{print $2}'); if [ -n "$max_rx" ]; then ethtool -G "$IFACE" rx "$max_rx" tx "$max_rx" 2>/dev/null || true; fi; else ethtool -G "$IFACE" rx 512 tx 512 2>/dev/null || true; fi; update_hw_boot_script; }
toggle_zram() { if [ "$(check_zram_state)" = "unsupported" ]; then return; fi; if [ "$(check_zram_state)" = "true" ]; then swapoff /dev/zram0 2>/dev/null || true; rmmod zram 2>/dev/null || true; systemctl disable xray-zram.service --now 2>/dev/null || true; rm -f /etc/systemd/system/xray-zram.service /usr/local/bin/xray-zram.sh; else local TOTAL_MEM=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo "1024"); local ZRAM_SIZE; if [ "$TOTAL_MEM" -lt 500 ]; then ZRAM_SIZE=$((TOTAL_MEM * 2)); elif [ "$TOTAL_MEM" -lt 1024 ]; then ZRAM_SIZE=$((TOTAL_MEM * 3 / 2)); else ZRAM_SIZE=$TOTAL_MEM; fi; cat > /usr/local/bin/xray-zram.sh <<EOFZ
#!/bin/bash
modprobe zram num_devices=1; echo "lz4" > /sys/block/zram0/comp_algorithm 2>/dev/null || true; echo "${ZRAM_SIZE}M" > /sys/block/zram0/disksize; mkswap /dev/zram0; swapon -p 100 /dev/zram0
EOFZ
chmod +x /usr/local/bin/xray-zram.sh 2>/dev/null || true; cat > /etc/systemd/system/xray-zram.service <<EOFZ
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
systemctl daemon-reload >/dev/null 2>&1 || true; systemctl enable xray-zram.service >/dev/null 2>&1 || true; systemctl start xray-zram.service >/dev/null 2>&1 || true; fi; }
toggle_journal() { local conf="/etc/systemd/journald.conf"; if [ "$(check_journal_state)" = "unsupported" ]; then return; fi; if [ "$(check_journal_state)" = "true" ]; then sed -i 's/^Storage=volatile/#Storage=auto/' "$conf" 2>/dev/null || true; systemctl restart systemd-journald >/dev/null 2>&1 || true; else if grep -q "^#Storage=" "$conf" 2>/dev/null; then sed -i 's/^#Storage=.*/Storage=volatile/' "$conf" 2>/dev/null || true; elif grep -q "^Storage=" "$conf" 2>/dev/null; then sed -i 's/^Storage=.*/Storage=volatile/' "$conf" 2>/dev/null || true; else echo "Storage=volatile" >> "$conf"; fi; systemctl restart systemd-journald >/dev/null 2>&1 || true; fi; }
toggle_process_priority() { local limit_file="/etc/systemd/system/xray.service.d/limits.conf"; if [ ! -f "$limit_file" ]; then return; fi; if grep -q "^OOMScoreAdjust=-500" "$limit_file" 2>/dev/null; then sed -i '/^OOMScoreAdjust=/d' "$limit_file" 2>/dev/null || true; sed -i '/^IOSchedulingClass=/d' "$limit_file" 2>/dev/null || true; sed -i '/^IOSchedulingPriority=/d' "$limit_file" 2>/dev/null || true; else echo "OOMScoreAdjust=-500" >> "$limit_file"; echo "IOSchedulingClass=realtime" >> "$limit_file"; echo "IOSchedulingPriority=2" >> "$limit_file"; fi; systemctl daemon-reload >/dev/null 2>&1 || true; }
toggle_buffer() { local limit_file="/etc/systemd/system/xray.service.d/limits.conf"; if [ ! -f "$limit_file" ]; then return; fi; if grep -q "XRAY_RAY_BUFFER_SIZE=64" "$limit_file" 2>/dev/null; then sed -i '/XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true; else echo "Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" >> "$limit_file"; fi; systemctl daemon-reload >/dev/null 2>&1 || true; }
toggle_routeonly() { if [ "$(check_routeonly_state)" = "true" ]; then _safe_jq_write '(.inbounds[]? | select(. != null) | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly) = false'; else _safe_jq_write '(.inbounds[]? | select(. != null) | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly) = true'; fi; }
toggle_cake_qdisc() { local conf="/etc/sysctl.d/99-network-optimized.conf"; local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo ""); if [ -z "$IFACE" ]; then return; fi; if [ "$(check_cake_state)" = "true" ]; then sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = fq/' "$conf" 2>/dev/null || true; sysctl -p "$conf" >/dev/null 2>&1 || true; tc qdisc replace dev "$IFACE" root fq >/dev/null 2>&1 || true; else sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = cake/' "$conf" 2>/dev/null || true; sysctl -p "$conf" >/dev/null 2>&1 || true; _apply_cake_live; fi; }
toggle_cake_flag() { local flag="$1"; if [ ! -d "$FLAGS_DIR" ]; then mkdir -p "$FLAGS_DIR"; fi; if [ -f "$FLAGS_DIR/$flag" ]; then rm -f "$FLAGS_DIR/$flag" 2>/dev/null || true; else touch "$FLAGS_DIR/$flag" 2>/dev/null || true; fi; _apply_cake_live; }
toggle_gso() { local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo ""); if [ -z "$IFACE" ]; then return; fi; if [ "$(check_gso_off_state)" = "true" ]; then ethtool -K "$IFACE" gro on gso on tso on 2>/dev/null || true; else ethtool -K "$IFACE" gro off gso off tso off 2>/dev/null || true; fi; update_hw_boot_script; }
toggle_irq() { local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo ""); if [ -z "$IFACE" ]; then return; fi; if [ "$(check_irq_state)" = "true" ]; then systemctl start irqbalance 2>/dev/null || true; systemctl enable irqbalance 2>/dev/null || true; local CPU=$(nproc 2>/dev/null || echo 1); local MASK=$(printf "%x" $(( (1<<CPU)-1 ))); for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || true); do echo "$MASK" > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true; done; else systemctl stop irqbalance 2>/dev/null || true; systemctl disable irqbalance 2>/dev/null || true; for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || true); do echo 1 > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true; done; fi; update_hw_boot_script; }
# --- ✂️ Part 16 结束，请复制并合并下方的 Part 17 ✂️ ---
# --- ✂️ 紧接在 Part 16 之后粘贴此 Part 17 ✂️ ---

_turn_on_app() {
    _safe_jq_write '
      (.routing) |= (. // {}) |
      (.routing.domainMatcher) = "mph" |
      (.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings) |= (. // {}) |
      (.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings.sockopt) |= (. // {}) |
      (.inbounds[]? | select(. != null) | select(.protocol=="vless") | .streamSettings) |= (. // {}) |
      (.inbounds[]? | select(. != null) | select(.protocol=="vless") | .streamSettings.sockopt) |= (. // {}) |
      (.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings.sockopt.tcpNoDelay) = true |
      (.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings.sockopt.tcpFastOpen) = true |
      (.inbounds[]? | select(. != null) | select(.protocol=="vless") | .streamSettings.sockopt.tcpNoDelay) = true |
      (.inbounds[]? | select(. != null) | select(.protocol=="vless") | .streamSettings.sockopt.tcpFastOpen) = true |
      (.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings.sockopt.tcpKeepAliveIdle) = 30 |
      (.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings.sockopt.tcpKeepAliveInterval) = 15 |
      (.inbounds[]? | select(. != null) | select(.protocol=="vless") | .streamSettings.sockopt.tcpKeepAliveIdle) = 30 |
      (.inbounds[]? | select(. != null) | select(.protocol=="vless") | .streamSettings.sockopt.tcpKeepAliveInterval) = 15
    '
    _safe_jq_write '(.inbounds[]? | select(. != null) | select(.protocol=="vless") | .sniffing.metadataOnly) = true | (.inbounds[]? | select(. != null) | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly) = true'
    
    local has_reality=$(jq -r '.inbounds[]? | select(. != null) | select(.protocol=="vless" and .streamSettings?.security=="reality") | .protocol' "$CONFIG" 2>/dev/null | head -n 1)
    if [ -n "$has_reality" ] && [ "$has_reality" != "null" ]; then _safe_jq_write '(.inbounds[]? | select(. != null) | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff) = 60000'; fi
    
    if [ "$(check_dnsmasq_state)" = "true" ]; then _safe_jq_write 'select(.dns != null) | .dns = {"servers":["127.0.0.1"], "queryStrategy":"UseIP"}'; else _safe_jq_write 'select(.dns != null) | .dns = {"servers":["https://8.8.8.8/dns-query","https://1.1.1.1/dns-query","https://doh.opendns.com/dns-query"], "queryStrategy":"UseIP"}'; fi
    _safe_jq_write 'select(.policy != null) | .policy = {"levels":{"0":{"handshake":3,"connIdle":60}},"system":{"statsInboundDownlink":false,"statsInboundUplink":false}}'
    
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if [ -f "$limit_file" ]; then
        [ "$(check_buffer_state)" = "false" ] && echo "Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" >> "$limit_file"
        _toggle_affinity_on
        local TOTAL_MEM=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo "1024"); local DYNAMIC_GOGC=100
        if [ "$TOTAL_MEM" -ge 1800 ]; then DYNAMIC_GOGC=1000; elif [ "$TOTAL_MEM" -ge 900 ]; then DYNAMIC_GOGC=500; elif [ "$TOTAL_MEM" -ge 700 ]; then DYNAMIC_GOGC=400; elif [ "$TOTAL_MEM" -ge 500 ]; then DYNAMIC_GOGC=300; elif [ "$TOTAL_MEM" -ge 400 ]; then DYNAMIC_GOGC=200; else DYNAMIC_GOGC=100; fi
        if grep -q "Environment=\"GOGC=" "$limit_file" 2>/dev/null; then sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=$DYNAMIC_GOGC\"/" "$limit_file" 2>/dev/null || true; else echo "Environment=\"GOGC=$DYNAMIC_GOGC\"" >> "$limit_file"; fi
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

_turn_off_app() {
    _safe_jq_write 'del(select(.routing != null) | .routing.domainMatcher) | del(.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpNoDelay, .streamSettings?.sockopt?.tcpFastOpen, .streamSettings?.sockopt?.tcpKeepAliveIdle, .streamSettings?.sockopt?.tcpKeepAliveInterval) | del(.inbounds[]? | select(. != null) | select(.protocol=="vless") | .streamSettings?.sockopt?.tcpNoDelay, .streamSettings?.sockopt?.tcpFastOpen, .streamSettings?.sockopt?.tcpKeepAliveIdle, .streamSettings?.sockopt?.tcpKeepAliveInterval)'
    _safe_jq_write '(.inbounds[]? | select(. != null) | select(.protocol=="vless") | .sniffing.metadataOnly) = false | (.inbounds[]? | select(. != null) | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly) = false'
    _safe_jq_write 'del(.inbounds[]? | select(. != null) | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff)'
    _safe_jq_write 'del(.dns)'
    _safe_jq_write 'del(.policy)'
    
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if [ -f "$limit_file" ]; then
        sed -i '/XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
        _toggle_affinity_off
        if grep -q "Environment=\"GOGC=" "$limit_file" 2>/dev/null; then sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=100\"/" "$limit_file" 2>/dev/null || true; else echo "Environment=\"GOGC=100\"" >> "$limit_file"; fi
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

do_app_level_tuning_menu() {
    while true; do
        clear
        title "全域 25 项系统级及应用层微操管理中心"
        if ! test -f "$CONFIG"; then error "未发现配置，请先执行核心部署！"; local _p=""; read -rp "按 Enter 返回..." _p || true; return; fi

        local out_fastopen=$(jq -r '.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpFastOpen // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        local out_keepalive=$(jq -r '.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpKeepAliveIdle // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        local sniff_status=$(jq -r '.inbounds[]? | select(. != null) | select(.protocol=="vless") | .sniffing.metadataOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        local routeonly_status=$(check_routeonly_state)
        local buffer_state=$(check_buffer_state)
        local dns_status=$(jq -r 'select(.dns != null) | .dns.queryStrategy // "false"' "$CONFIG" 2>/dev/null)
        local policy_status=$(jq -r 'select(.policy != null) | .policy.levels["0"].connIdle // "false"' "$CONFIG" 2>/dev/null)
        local affinity_state=$(check_affinity_state)
        local mph_state=$(check_mph_state)
        local maxtime_state=$(check_maxtime_state)
        
        local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
        local gc_status="未知"
        if [ -f "$limit_file" ]; then gc_status=$(awk -F'=' '/^Environment="GOGC=/ {print $3}' "$limit_file" | tr -d '"' | head -1); gc_status=${gc_status:-"默认 100"}; fi

        local dnsmasq_state=$(check_dnsmasq_state); local thp_state=$(check_thp_state); local mtu_state=$(check_mtu_state); local cpu_state=$(check_cpu_state); local ring_state=$(check_ring_state); local cake_state=$(check_cake_state); local ackfilter_state=$(check_ackfilter_state); local ecn_state=$(check_ecn_state); local wash_state=$(check_wash_state); local gso_state=$(check_gso_off_state); local irq_state=$(check_irq_state); local zram_state=$(check_zram_state); local journal_state=$(check_journal_state); local prio_state=$(check_process_priority_state)

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
        
        local has_reality=$(jq -r '.inbounds[]? | select(. != null) | select(.protocol=="vless" and .streamSettings?.security=="reality") | .protocol' "$CONFIG" 2>/dev/null | head -n 1)
        if [ -n "$has_reality" ] && [ "$has_reality" != "null" ]; then [ "$maxtime_state" != "true" ] && app_off_count=$((app_off_count+1)); fi

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
        local s24=$([ "$journal_state" = "true" ] && echo "${cyan}纯内存极极速化${none}" || ([ "$journal_state" = "unsupported" ] && echo "${gray}不支持${none}" || echo "${gray}磁盘 IO 写入${none}"))
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
        
        local app_opt=""; read -rp "请下达操作指令: " app_opt || true
        case "$app_opt" in
            1) if [ "$out_fastopen" = "true" ]; then _safe_jq_write 'del(.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpNoDelay, .streamSettings?.sockopt?.tcpFastOpen) | del(.inbounds[]? | select(. != null) | select(.protocol=="vless") | .streamSettings?.sockopt?.tcpNoDelay, .streamSettings?.sockopt?.tcpFastOpen)'; info "双向并发提速 (FastOpen) 已关闭。"; else _turn_on_app; info "双向并发提速 (FastOpen) 等应用层已全域重置！"; fi; systemctl restart xray >/dev/null 2>&1 || true; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            2) if [ "$out_keepalive" = "30" ]; then _safe_jq_write 'del(.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpKeepAliveIdle, .streamSettings?.sockopt?.tcpKeepAliveInterval) | del(.inbounds[]? | select(. != null) | select(.protocol=="vless") | .streamSettings?.sockopt?.tcpKeepAliveIdle, .streamSettings?.sockopt?.tcpKeepAliveInterval)'; info "Socket 智能保活心跳已关闭。"; else _turn_on_app; info "Socket 保活心跳等全域微操已写入！"; fi; systemctl restart xray >/dev/null 2>&1 || true; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            3) if [ "$sniff_status" = "true" ]; then _safe_jq_write '(.inbounds[]? | select(. != null) | select(.protocol=="vless") | .sniffing.metadataOnly) = false'; info "嗅探引擎减负已关闭。"; else _safe_jq_write '(.inbounds[]? | select(. != null) | select(.protocol=="vless") | .sniffing.metadataOnly) = true'; info "嗅探引擎减负已开启！"; fi; systemctl restart xray >/dev/null 2>&1 || true; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            4) toggle_routeonly; systemctl restart xray >/dev/null 2>&1 || true; info "路由纯净解析配置已应用！"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            5) toggle_buffer; systemctl restart xray >/dev/null 2>&1 || true; info "底层 Buffer 数据缓冲区限额已调整！"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            6) toggle_dnsmasq; systemctl restart xray >/dev/null 2>&1 || true; info "DNS 引擎流向已重构。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            7) if [ -f "$limit_file" ]; then local TOTAL_MEM=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo "1024"); local DYNAMIC_GOGC=100; if [ "$TOTAL_MEM" -ge 1800 ]; then DYNAMIC_GOGC=1000; elif [ "$TOTAL_MEM" -ge 900 ]; then DYNAMIC_GOGC=500; elif [ "$TOTAL_MEM" -ge 700 ]; then DYNAMIC_GOGC=400; elif [ "$TOTAL_MEM" -ge 500 ]; then DYNAMIC_GOGC=300; elif [ "$TOTAL_MEM" -ge 400 ]; then DYNAMIC_GOGC=200; else DYNAMIC_GOGC=100; fi; if grep -q "Environment=\"GOGC=" "$limit_file"; then if [ "$gc_status" = "默认 100" ] || [ "$gc_status" = "100" ]; then sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=$DYNAMIC_GOGC\"/" "$limit_file"; info "GOGC 动态阶梯调优完成！"; else sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=100\"/" "$limit_file"; info "GOGC 已恢复保底阈值: 100"; fi; else echo "Environment=\"GOGC=$DYNAMIC_GOGC\"" >> "$limit_file"; info "GOGC 动态调优完成！"; fi; systemctl daemon-reload >/dev/null 2>&1 || true; systemctl restart xray >/dev/null 2>&1 || true; else error "未找到配置环境！"; fi; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            8) if [ "$policy_status" = "60" ]; then _safe_jq_write 'del(.policy)'; info "Xray 策略组回收已关闭。"; else _safe_jq_write 'select(.policy != null) | .policy = {"levels":{"0":{"handshake":3,"connIdle":60}},"system":{"statsInboundDownlink":false,"statsInboundUplink":false}}'; info "策略组生命周期优化已开启。"; fi; systemctl restart xray >/dev/null 2>&1 || true; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            9) if [ "$affinity_state" = "true" ]; then _toggle_affinity_off; systemctl restart xray >/dev/null 2>&1 || true; info "物理绑核已解除。"; else _toggle_affinity_on; systemctl restart xray >/dev/null 2>&1 || true; info "硬绑定核心已破除并发限制！"; fi; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            10) if [ "$mph_state" = "true" ]; then _safe_jq_write 'del(select(.routing != null) | .routing.domainMatcher)'; systemctl restart xray >/dev/null 2>&1 || true; info "MPH 算法关闭。"; else _safe_jq_write 'select(.routing != null) | (.routing) |= (. // {}) | (.routing.domainMatcher) = "mph"'; systemctl restart xray >/dev/null 2>&1 || true; info "MPH 极速匹配启用！"; fi; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            11) if [ -z "$has_reality" ] || [ "$has_reality" = "null" ]; then error "无 Reality 支持。"; else if [ "$maxtime_state" = "true" ]; then _safe_jq_write 'del(.inbounds[]? | select(. != null) | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff)'; systemctl restart xray >/dev/null 2>&1 || true; info "Reality 时间锁已解除。"; else _safe_jq_write '(.inbounds[]? | select(. != null) | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff) = 60000'; systemctl restart xray >/dev/null 2>&1 || true; info "60秒时间防线激活！"; fi; fi; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            12) toggle_dnsmasq; systemctl restart xray >/dev/null 2>&1 || true; info "操作已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            13) toggle_thp; info "操作已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            14) toggle_mtu; info "操作已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            15) toggle_cpu; info "操作已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            16) toggle_ring; info "操作已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            17) toggle_cake_qdisc; info "操作已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            18) toggle_cake_flag "ack_filter"; info "操作已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            19) toggle_cake_flag "ecn"; info "操作已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            20) toggle_cake_flag "wash"; info "操作已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            21) toggle_gso; info "操作已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            22) toggle_irq; info "操作已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            23) toggle_zram; info "操作已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            24) toggle_journal; info "操作已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            25) toggle_process_priority; systemctl restart xray >/dev/null 2>&1 || true; info "操作已执行。"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            26) if [ "$app_off_count" -gt 0 ]; then print_magenta ">>> 全域开启 1-11 项..."; _turn_on_app; systemctl restart xray >/dev/null 2>&1 || true; info "应用层微操已全域激活！"; else print_magenta ">>> 恢复 1-11 项..."; _turn_off_app; systemctl restart xray >/dev/null 2>&1 || true; info "已回归出厂标准！"; fi; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            27) if [ "$sys_off_count" -gt 0 ]; then [ "$dnsmasq_state" = "false" ] && toggle_dnsmasq >/dev/null 2>&1 || true; if [ -f "/sys/kernel/mm/transparent_hugepage/enabled" ]; then [ "$(check_thp_state)" = "false" ] && toggle_thp >/dev/null 2>&1 || true; fi; [ "$mtu_state" = "false" ] && toggle_mtu >/dev/null 2>&1 || true; if [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then [ "$(check_cpu_state)" = "false" ] && toggle_cpu >/dev/null 2>&1 || true; fi; [ "$ring_state" = "false" ] && toggle_ring >/dev/null 2>&1 || true; [ "$cake_state" = "false" ] && toggle_cake_qdisc >/dev/null 2>&1 || true; [ "$ackfilter_state" = "false" ] && toggle_cake_flag "ack_filter" >/dev/null 2>&1 || true; [ "$ecn_state" = "false" ] && toggle_cake_flag "ecn" >/dev/null 2>&1 || true; [ "$wash_state" = "false" ] && toggle_cake_flag "wash" >/dev/null 2>&1 || true; [ "$gso_state" = "false" ] && toggle_gso >/dev/null 2>&1 || true; [ "$irq_state" = "false" ] && toggle_irq >/dev/null 2>&1 || true; [ "$zram_state" = "false" ] && toggle_zram >/dev/null 2>&1 || true; [ "$journal_state" = "false" ] && toggle_journal >/dev/null 2>&1 || true; [ "$prio_state" = "false" ] && toggle_process_priority >/dev/null 2>&1 || true; systemctl restart xray >/dev/null 2>&1 || true; info "底层优化全激活！"; else [ "$dnsmasq_state" = "true" ] && toggle_dnsmasq >/dev/null 2>&1 || true; if [ -f "/sys/kernel/mm/transparent_hugepage/enabled" ]; then [ "$(check_thp_state)" = "true" ] && toggle_thp >/dev/null 2>&1 || true; fi; [ "$mtu_state" = "true" ] && toggle_mtu >/dev/null 2>&1 || true; if [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then [ "$(check_cpu_state)" = "true" ] && toggle_cpu >/dev/null 2>&1 || true; fi; [ "$ring_state" = "true" ] && toggle_ring >/dev/null 2>&1 || true; [ "$cake_state" = "true" ] && toggle_cake_qdisc >/dev/null 2>&1 || true; [ "$ackfilter_state" = "true" ] && toggle_cake_flag "ack_filter" >/dev/null 2>&1 || true; [ "$ecn_state" = "true" ] && toggle_cake_flag "ecn" >/dev/null 2>&1 || true; [ "$wash_state" = "true" ] && toggle_cake_flag "wash" >/dev/null 2>&1 || true; [ "$gso_state" = "true" ] && toggle_gso >/dev/null 2>&1 || true; [ "$irq_state" = "true" ] && toggle_irq >/dev/null 2>&1 || true; [ "$zram_state" = "true" ] && toggle_zram >/dev/null 2>&1 || true; [ "$journal_state" = "true" ] && toggle_journal >/dev/null 2>&1 || true; [ "$prio_state" = "true" ] && toggle_process_priority >/dev/null 2>&1 || true; systemctl restart xray >/dev/null 2>&1 || true; info "底层微操已重置！"; fi; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            28)
                if [ "$((app_off_count + sys_off_count))" -gt 0 ]; then
                    if [ "$app_off_count" -gt 0 ]; then print_magenta ">>> 正在激活应用层..."; _turn_on_app; fi
                    if [ "$sys_off_count" -gt 0 ]; then
                        print_magenta ">>> 正在激活底层..."; [ "$dnsmasq_state" = "false" ] && toggle_dnsmasq >/dev/null 2>&1 || true; if [ -f "/sys/kernel/mm/transparent_hugepage/enabled" ]; then [ "$(check_thp_state)" = "false" ] && toggle_thp >/dev/null 2>&1 || true; fi; [ "$mtu_state" = "false" ] && toggle_mtu >/dev/null 2>&1 || true; if [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then [ "$(check_cpu_state)" = "false" ] && toggle_cpu >/dev/null 2>&1 || true; fi; [ "$ring_state" = "false" ] && toggle_ring >/dev/null 2>&1 || true; [ "$cake_state" = "false" ] && toggle_cake_qdisc >/dev/null 2>&1 || true; [ "$ackfilter_state" = "false" ] && toggle_cake_flag "ack_filter" >/dev/null 2>&1 || true; [ "$ecn_state" = "false" ] && toggle_cake_flag "ecn" >/dev/null 2>&1 || true; [ "$wash_state" = "false" ] && toggle_cake_flag "wash" >/dev/null 2>&1 || true; [ "$gso_state" = "false" ] && toggle_gso >/dev/null 2>&1 || true; [ "$irq_state" = "false" ] && toggle_irq >/dev/null 2>&1 || true; [ "$zram_state" = "false" ] && toggle_zram >/dev/null 2>&1 || true; [ "$journal_state" = "false" ] && toggle_journal >/dev/null 2>&1 || true; [ "$prio_state" = "false" ] && toggle_process_priority >/dev/null 2>&1 || true
                    fi
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "上帝之手：1-25 项优化已满血注入！"
                else
                    print_magenta ">>> 执行系统回卷..."; _turn_off_app; [ "$dnsmasq_state" = "true" ] && toggle_dnsmasq >/dev/null 2>&1 || true; if [ -f "/sys/kernel/mm/transparent_hugepage/enabled" ]; then [ "$(check_thp_state)" = "true" ] && toggle_thp >/dev/null 2>&1 || true; fi; [ "$mtu_state" = "true" ] && toggle_mtu >/dev/null 2>&1 || true; if [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then [ "$(check_cpu_state)" = "true" ] && toggle_cpu >/dev/null 2>&1 || true; fi; [ "$ring_state" = "true" ] && toggle_ring >/dev/null 2>&1 || true; [ "$cake_state" = "true" ] && toggle_cake_qdisc >/dev/null 2>&1 || true; [ "$ackfilter_state" = "true" ] && toggle_cake_flag "ack_filter" >/dev/null 2>&1 || true; [ "$ecn_state" = "true" ] && toggle_cake_flag "ecn" >/dev/null 2>&1 || true; [ "$wash_state" = "true" ] && toggle_cake_flag "wash" >/dev/null 2>&1 || true; [ "$gso_state" = "true" ] && toggle_gso >/dev/null 2>&1 || true; [ "$irq_state" = "true" ] && toggle_irq >/dev/null 2>&1 || true; [ "$zram_state" = "true" ] && toggle_zram >/dev/null 2>&1 || true; [ "$journal_state" = "true" ] && toggle_journal >/dev/null 2>&1 || true; [ "$prio_state" = "true" ] && toggle_process_priority >/dev/null 2>&1 || true; systemctl restart xray >/dev/null 2>&1 || true; info "引擎已降维并恢复为标准参数！"
                fi
                echo ""; print_red "=========================================================="; print_yellow "警告：全域拓扑与内核状态已发生重大变更！"; print_yellow "系统必须在 6 秒后执行物理重启！"; print_red "=========================================================="; echo ""
                for i in {6..1}; do echo -ne "\r  重启序列: ${cyan}${i}${none} ... "; sleep 1; done
                echo -e "\n\n  正在重启，请重新登录服务器..."; reboot
                ;;
            0) return ;;
        esac
    done
}
# --- ✂️ Part 17 结束，请复制并合并下方的 Part 18 ✂️ ---
# --- ✂️ 紧接在 Part 17 之后粘贴此 Part 18 ✂️ ---

print_node_block() {
    local protocol="$1" ip="$2" port="$3" sni="$4" pbk="$5" shortid="$6" utls="$7" uuid="$8"
    printf "  ${yellow}%-15s${none} : %s\n" "协议框架" "$protocol"
    printf "  ${yellow}%-15s${none} : %s\n" "外网IP" "$ip"
    printf "  ${yellow}%-15s${none} : %s\n" "端口" "$port"
    printf "  ${yellow}%-15s${none} : %s\n" "用户 UUID" "$uuid"
    printf "  ${yellow}%-15s${none} : %s\n" "伪装SNI" "${sni:-缺失}"
    printf "  ${yellow}%-15s${none} : %s\n" "公钥(pbk)" "${pbk:-缺失}"
    printf "  ${yellow}%-15s${none} : %s\n" "ShortId" "${shortid:-缺失}"
    printf "  ${yellow}%-15s${none} : %s\n" "uTLS引擎" "$utls"
}

do_summary() {
    if test ! -f "$CONFIG"; then return; fi
    title "Xray 配置网络及授权明细"
    local ip=$(_get_ip || echo "获取失败")
    
    local client_count=$(jq -r '.inbounds[]? | select(. != null) | select(.protocol=="vless") | .settings.clients | length' "$CONFIG" 2>/dev/null || echo 0)
    
    if test "${client_count:-0}" -gt 0; then
        local port=$(jq -r '.inbounds[]? | select(. != null) | select(.protocol=="vless") | .port' "$CONFIG" 2>/dev/null || echo "443")
        local pub=$(jq -r '.inbounds[]? | select(. != null) | select(.protocol=="vless") | .streamSettings.realitySettings.publicKey // "缺失"' "$CONFIG" 2>/dev/null)
        local all_snis=$(jq -r '.inbounds[]? | select(. != null) | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames | join(", ") // "缺失"' "$CONFIG" 2>/dev/null)
        local main_sni=$(jq -r '.inbounds[]? | select(. != null) | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0] // "缺失"' "$CONFIG" 2>/dev/null)
        
        for ((i=0; i<client_count; i++)); do
            local uuid=$(jq -r ".inbounds[]? | select(. != null) | select(.protocol==\"vless\") | .settings.clients[$i].id" "$CONFIG" 2>/dev/null || echo "")
            local remark=$(jq -r ".inbounds[]? | select(. != null) | select(.protocol==\"vless\") | .settings.clients[$i].email // \"$REMARK_NAME\"" "$CONFIG" 2>/dev/null)
            local sid=$(jq -r ".inbounds[]? | select(. != null) | select(.protocol==\"vless\") | .streamSettings.realitySettings.shortIds[$i] // \"缺失\"" "$CONFIG" 2>/dev/null)
            
            local target_sni=$(grep "^$uuid|" "$USER_SNI_MAP" 2>/dev/null | cut -d'|' -f2 || echo "")
            if test -z "$target_sni"; then target_sni="$main_sni"; fi
            
            if test -n "$uuid" && test "$uuid" != "null"; then
                hr
                printf "  ${cyan}【VLESS-Reality (Vision) - 客户端授权 %d】${none}\n" $((i+1))
                printf "  ${yellow}%-16s${none} %s\n" "节点代号:" "$remark"
                printf "  ${yellow}%-16s${none} %s\n" "外网 IP:" "$ip"
                printf "  ${yellow}%-16s${none} %s\n" "监听端口:" "$port"
                printf "  ${yellow}%-16s${none} %s\n" "主用 UUID:" "$uuid"
                printf "  ${yellow}%-16s${none} %s\n" "专属配置 SNI:" "$target_sni"
                printf "  ${yellow}%-16s${none} %s\n" "可用 SNI 矩阵:" "$all_snis"
                printf "  ${yellow}%-16s${none} %s\n" "公钥 (pbk):" "$pub"
                printf "  ${yellow}%-16s${none} %s\n" "Short ID:" "$sid"
                
                local link="vless://${uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${target_sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${remark}"
                echo -e "\n  ${cyan}原生配置链接:${none} \n  $link\n"
                if command -v qrencode >/dev/null 2>&1; then 
                    echo -e "  ${cyan}客户端扫码导入 (短边码):${none}"
                    qrencode -m 2 -t UTF8 "$link"
                fi
            fi
        done
    fi

    local ss_inbound=$(jq -c '.inbounds[]? | select(. != null) | select(.protocol=="shadowsocks")' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
    if test -n "$ss_inbound" && test "$ss_inbound" != "null"; then
        local s_port=$(echo "$ss_inbound" | jq -r '.port' 2>/dev/null || echo 8388)
        local s_pass=$(echo "$ss_inbound" | jq -r '.settings.password' 2>/dev/null || echo "")
        local s_method=$(echo "$ss_inbound" | jq -r '.settings.method' 2>/dev/null || echo "aes-256-gcm")
        
        hr
        printf "  ${cyan}【Shadowsocks 后备通道】${none}\n"
        printf "  ${yellow}%-16s${none} %s\n" "端口:" "$s_port"
        printf "  ${yellow}%-16s${none} %s\n" "密码:" "$s_pass"
        printf "  ${yellow}%-16s${none} %s\n" "加密规格:" "$s_method"
        
        local b64=$(printf '%s:%s' "$s_method" "$s_pass" | base64 | tr -d '\n\r' || echo "")
        local link_ss="ss://${b64}@${ip}:${s_port}#${REMARK_NAME}-SS"
        echo -e "\n  ${cyan}配置导入链接:${none} \n  $link_ss\n"
        if command -v qrencode >/dev/null 2>&1; then qrencode -m 2 -t UTF8 "$link_ss"; fi
    fi
}

do_user_manager() {
    while true; do
        title "控制面: 账户生命周期管理"
        if test ! -f "$CONFIG"; then error "核心环境未就绪。"; return; fi
        
        local clients=$(jq -r '.inbounds[]? | select(. != null) | select(.protocol=="vless") | .settings?.clients[]? | .id + "|" + (.email // "未命名")' "$CONFIG" 2>/dev/null || echo "")
        if test -z "$clients" || test "$clients" = "null"; then 
            error "未配置任何可修改的 VLESS 权限。"
            local _p=""; read -rp "按 Enter 返回..." _p || true
            return
        fi
        
        local tmp_users="/tmp/xray_users_$$.txt"
        echo "$clients" | awk -F'|' '{print NR"|"$1"|"$2}' > "$tmp_users" || true
        
        echo -e "已注册持有人列表："
        while IFS='|' read -r num uid remark; do
            local utime=$(grep "^$uid|" "$USER_TIME_MAP" 2>/dev/null | cut -d'|' -f2 || echo "")
            if test -z "$utime"; then utime="外部输入"; fi
            echo -e "  $num) 代号: ${cyan}$remark${none} | 录入日: ${gray}$utime${none} | ID: ${yellow}$uid${none}"
        done < "$tmp_users"
        hr
        
        echo "  a) 创建底层用户凭证 (自动分配资源)"
        echo "  m) 强制导入外部迁移用户 (补全历史凭据)"
        echo "  s) 为账户重定向专用的高匿面具 (SNI)"
        echo "  d) 永久撤销账户授权"
        echo "  q) 取消并关闭"
        
        local uopt=""; read -rp "输入执行命令: " uopt || true
        local ip=$(_get_ip || echo "获取失败")
        
        if test "$uopt" = "a" || test "$uopt" = "A"; then
            local nu=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
            local ns=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n\r' || echo "")
            local ctime=$(date +"%Y-%m-%d %H:%M")
            local u_remark=""; read -rp "指定账户备注 (直接回车默认 User-$ns): " u_remark || true
            if test -z "$u_remark"; then u_remark="User-${ns}"; fi
            
            cat > /tmp/new_client.json <<EOF
{ "id": "$nu", "flow": "xtls-rprx-vision", "email": "$u_remark" }
EOF
            _safe_jq_write --argjson new_client "$(< /tmp/new_client.json)" '(.inbounds[]? | select(. != null) | select(.protocol == "vless")) |= (.settings.clients += [$new_client])'
            _safe_jq_write --arg sid "$ns" '(.inbounds[]? | select(. != null) | select(.protocol == "vless")) |= (.streamSettings.realitySettings.shortIds += [$sid])'
            rm -f /tmp/new_client.json 2>/dev/null || true
            
            echo "$nu|$ctime" >> "$USER_TIME_MAP"
            ensure_xray_is_alive
            
            local vless_node=$(jq -c '.inbounds[]? | select(. != null) | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
            local port=$(echo "$vless_node" | jq -r '.port' 2>/dev/null || echo 443)
            local sni=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.serverNames[0]' 2>/dev/null || echo "")
            local pub=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.publicKey' 2>/dev/null || echo "")
            
            info "创建指令已完成。"
            hr
            print_node_block "VLESS-Reality (Vision)" "$ip" "$port" "$sni" "$pub" "$ns" "chrome" "$nu"
            local link="vless://${nu}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${ns}&type=tcp#${u_remark}"
            echo -e "\n  ${cyan}专用节点参数已生成:${none}\n  $link\n"
            local _p=""; read -rp "按 Enter 继续..." _p || true
            
        elif test "$uopt" = "m" || test "$uopt" = "M"; then
            local m_remark=""; read -rp "指定输入的用户备注 (默认 Imported): " m_remark || true
            if test -z "$m_remark"; then m_remark="Imported"; fi
            local m_uuid=""; read -rp "输入该账户的 UUID: " m_uuid || true
            if test -z "$m_uuid"; then error "UUID 信息缺失。"; continue; fi
            local m_sid=""; read -rp "输入该账户的 ShortId: " m_sid || true
            if test -z "$m_sid"; then error "ShortId 信息缺失。"; continue; fi
            
            local ctime=$(date +"%Y-%m-%d %H:%M")
            cat > /tmp/new_client.json <<EOF
{ "id": "$m_uuid", "flow": "xtls-rprx-vision", "email": "$m_remark" }
EOF
            _safe_jq_write --argjson new_client "$(< /tmp/new_client.json)" '(.inbounds[]? | select(. != null) | select(.protocol == "vless")) |= (.settings.clients += [$new_client])'
            _safe_jq_write --arg sid "$m_sid" '(.inbounds[]? | select(. != null) | select(.protocol == "vless")) |= (.streamSettings.realitySettings.shortIds += [$sid])'
            rm -f /tmp/new_client.json 2>/dev/null || true
            echo "$m_uuid|$ctime" >> "$USER_TIME_MAP"
            
            local m_sni=""; read -rp "锁定独立伪装 SNI 域 (回车套用主线设定): " m_sni || true
            if test -n "$m_sni"; then
                _safe_jq_write --arg sni "$m_sni" '(.inbounds[]? | select(. != null) | select(.protocol == "vless")) |= (.streamSettings.realitySettings.serverNames += [$sni] | .streamSettings.realitySettings.serverNames |= unique)'
                sed -i "/^$m_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                echo "$m_uuid|$m_sni" >> "$USER_SNI_MAP"
                info "底层伪装锚定成功: $m_sni"
            else
                m_sni=$(jq -r '.inbounds[]? | select(. != null) | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0] // empty' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
            fi
            ensure_xray_is_alive
            
            local vless_node=$(jq -c '.inbounds[]? | select(. != null) | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
            local port=$(echo "$vless_node" | jq -r '.port' 2>/dev/null || echo 443)
            local pub=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.publicKey' 2>/dev/null || echo "")
            
            info "历史权限挂载验证完成。"
            hr
            print_node_block "VLESS-Reality (Vision)" "$ip" "$port" "$m_sni" "$pub" "$m_sid" "chrome" "$m_uuid"
            local link="vless://${m_uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${m_sni}&fp=chrome&pbk=${pub}&sid=${m_sid}&type=tcp#${m_remark}"
            echo -e "\n  ${cyan}配置重组链:${none}\n  $link\n"
            local _p=""; read -rp "按 Enter 继续..." _p || true
            
        elif test "$uopt" = "s" || test "$uopt" = "S"; then
            local snum=""; read -rp "目标序号: " snum || true
            local target_uuid=$(awk -F'|' -v id="${snum:-0}" '$1==id {print $2}' "$tmp_users" 2>/dev/null || echo "")
            local target_remark=$(awk -F'|' -v id="${snum:-0}" '$1==id {print $3}' "$tmp_users" 2>/dev/null || echo "")
            
            if test -n "$target_uuid"; then
                local u_sni=""; read -rp "强制重定向 SNI: " u_sni || true
                if test -n "$u_sni"; then
                    _safe_jq_write --arg sni "$u_sni" '(.inbounds[]? | select(. != null) | select(.protocol == "vless")) |= (.streamSettings.realitySettings.serverNames += [$sni] | .streamSettings.realitySettings.serverNames |= unique)'
                    sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                    echo "$target_uuid|$u_sni" >> "$USER_SNI_MAP"
                    ensure_xray_is_alive
                    info "$target_remark 面具替换完毕，新特征: $u_sni"
                    
                    local vless_node=$(jq -c '.inbounds[]? | select(. != null) | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
                    local port=$(echo "$vless_node" | jq -r '.port' 2>/dev/null || echo 443)
                    local idx=$((${snum:-0} - 1))
                    local sid=$(echo "$vless_node" | jq -r ".streamSettings.realitySettings.shortIds[$idx] // empty" 2>/dev/null || echo "")
                    local pub=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.publicKey // empty' 2>/dev/null || echo "")
                    local link="vless://${target_uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${u_sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${target_remark}"
                    echo -e "\n  ${cyan}刷新下发链接:${none}\n  $link\n"
                    local _p=""; read -rp "按 Enter 继续..." _p || true
                fi
            else 
                error "无效寻址序号。"
            fi
            
        elif test "$uopt" = "d" || test "$uopt" = "D"; then
            local dnum=""; read -rp "下达强制吊销许可的序号: " dnum || true
            local total=$(wc -l < "$tmp_users" 2>/dev/null || echo "0")
            if test "${total:-0}" -le 1; then 
                error "核心保护规则已触发：您不能注销唯一驻留节点账户！"
            else
                local target_uuid=$(awk -F'|' -v id="${dnum:-0}" '$1==id {print $2}' "$tmp_users" 2>/dev/null || echo "")
                if test -n "$target_uuid"; then
                    local idx=$((${dnum:-0} - 1))
                    _safe_jq_write --arg uid "$target_uuid" --argjson i "$idx" '(.inbounds[]? | select(. != null) | select(.protocol == "vless")) |= (.settings.clients |= map(select(.id != $uid)) | .streamSettings.realitySettings.shortIds |= del(.[$i]))'
                    sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                    sed -i "/^$target_uuid|/d" "$USER_TIME_MAP" 2>/dev/null || true
                    ensure_xray_is_alive
                    info "权限网剥离成功，$target_uuid 所有相关连接口已永久关闭。"
                fi
            fi
        elif test "$uopt" = "q" || test "$uopt" = "Q"; then 
            rm -f "$tmp_users" 2>/dev/null || true
            break
        fi
    done
}

_global_block_rules() {
    while true; do
        title "安全防火墙体系设定"
        if test ! -f "$CONFIG"; then error "未解析到配置。"; return; fi
        local bt_en=$(jq -r '.routing.rules[]? | select(.protocol != null) | select(.protocol | index("bittorrent")) | ._enabled // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        local ad_en=$(jq -r '.routing.rules[]? | select(.domain != null) | select(.domain | index("geosite:category-ads-all")) | ._enabled // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        
        echo -e "  1) P2P/BT 协议强力阻隔控制      | 目前状态: ${yellow}${bt_en}${none}"
        echo -e "  2) Geosite 黑名单与流氓广告过滤 | 目前状态: ${yellow}${ad_en}${none}"
        echo "  0) 退出返回"
        
        local bc=""; read -rp "请下达开关指令: " bc || true
        case "${bc:-}" in
            1) local nv="true"; if test "$bt_en" = "true"; then nv="false"; fi; _safe_jq_write --argjson nv_val "$nv" '(.routing.rules[]? | select(.protocol != null and (.protocol | index("bittorrent")))) |= (._enabled = $nv_val)'; ensure_xray_is_alive; info "BT 协议阻断墙修改为: $nv" ;;
            2) local nv="true"; if test "$ad_en" = "true"; then nv="false"; fi; _safe_jq_write --argjson nv_val "$nv" '(.routing.rules[]? | select(.domain != null and (.domain | index("geosite:category-ads-all")))) |= (._enabled = $nv_val)'; ensure_xray_is_alive; info "黑洞过滤系统修改为: $nv" ;;
            0) return ;;
        esac
    done
}

do_fallback_probe() {
    clear
    title "Reality 回落陷阱深渊侦测引擎 (Fallback)"
    if test ! -f "$CONFIG"; then error "无法对接底层 JQ 环境结构树配置！"; local _p=""; read -rp "按 Enter 返回..." _p || true; return; fi
    local out=$(jq -r '
      .inbounds[]? | select(. != null) | select(.protocol=="vless" and .streamSettings.security=="reality") | .streamSettings.realitySettings | 
      "  [发射管 (Upload)]\n    前置设局诱饵拦截 (afterBytes) : \(.limitFallbackUpload.afterBytes // "安全门全开")\n    防扫描绞杀器 (bytesPerSec) : \(.limitFallbackUpload.bytesPerSec // "安全门全开")\n  [下沉流 (Download)]\n    前置设局诱饵拦截 (afterBytes) : \(.limitFallbackDownload.afterBytes // "安全门全开")\n    防扫描绞杀器 (bytesPerSec) : \(.limitFallbackDownload.bytesPerSec // "安全门全开")"
    ' "$CONFIG" 2>/dev/null || echo "")
    if test -n "$out"; then echo -e "$out"; else echo -e "  ${red}致命警告：网络中不存在有效的 Reality 配置基体！${none}"; fi
    echo ""; local _p=""; read -rp "核查结束，按 Enter 键返回..." _p || true
}
# --- ✂️ Part 18 结束，请复制并合并下方的 Part 19 ✂️ ---
# --- ✂️ 紧接在 Part 18 之后粘贴此 Part 19 ✂️ ---

do_status_menu() {
    while true; do
        clear
        title "主控台: 监控及账单核心"
        echo "  1) [系统守护] 追踪主线程服务健康率"
        echo "  2) [全网穿透] 检测基础外网及监听位态"
        echo "  3) [总计账单] 调取网卡出入核算账册 (vnstat)"
        echo "  4) [雷达扫描] 实时反制追踪系统内部驻留连接 IP"
        echo "  5) [底层微操] 人工赋予 Xray 高配内存抢占锁 (Nice)"
        echo "  6) [数据留痕] 翻阅应用层历史指令"
        echo "  7) [故障分析] 获取崩溃回溯报告"
        echo "  8) [灾难规避] 无损拉取快照与覆盖回退"
        echo "  0) 返回中控区"
        hr
        local s=""; read -rp "执行指令: " s || true
        case "${s:-}" in
            1) systemctl status xray --no-pager || true; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            2) echo -e "\n  [公网物理层] IP地址: ${green}$SERVER_IP${none}\n  [解析路由流] nameserver: "; grep "^nameserver" /etc/resolv.conf 2>/dev/null || echo "    读取被拒"; echo -e "  [协议通讯录] 内网穿透口:"; ss -tlnp 2>/dev/null | grep xray || echo "    进程无响应"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            3) if ! command -v vnstat >/dev/null 2>&1; then warn "未安装 vnstat。"; local _p=""; read -rp "Enter..." _p || true; continue; fi; clear; title "底层网卡流量计费审计中心"; local m_day=$(grep -E "^[[:space:]]*MonthRotate" /etc/vnstat.conf 2>/dev/null | awk '{print $2}' | head -n 1 | tr -d '\r\n'); if test -z "$m_day"; then m_day="1 (默认)"; fi; echo -e "  [全局锚定] 结算日：${cyan}自然月 $m_day 号${none}"; hr; (vnstat -m 3 2>/dev/null || vnstat -m 2>/dev/null || true) | sed -e 's/estimated/模型预估/ig' -e 's/rx/接收流量/ig' -e 's/tx/出站推送/ig' -e 's/total/并发总计/ig' -e 's/daily/日志按日/ig' -e 's/monthly/汇总按月/ig'; hr; echo "  1) 指定特定日期进行跨月账单裁断 (1-31)"; echo "  2) 下达历史账单日跑量穿梭溯源 (如 2026-04)"; echo "  0) 返回主操作台"; local vn_opt=""; read -rp "  键入操作码: " vn_opt || true; if test "$vn_opt" = "1"; then local d_day=""; read -rp "请决定强制切断日 (1-31): " d_day || true; if [[ "$d_day" =~ ^[0-9]+$ ]] && test "$d_day" -ge 1 2>/dev/null && test "$d_day" -le 31 2>/dev/null; then sed -i '/^[#[:space:]]*MonthRotate/d' /etc/vnstat.conf 2>/dev/null || true; echo "MonthRotate $d_day" >> /etc/vnstat.conf; systemctl restart vnstat 2>/dev/null || true; info "计费核心配置更新，流量将于每个月 $d_day 日清空重算。"; else error "跨界拦截，数字溢出。"; fi; local _p=""; read -rp "Enter..." _p || true; elif test "$vn_opt" = "2"; then local d_month=""; read -rp "穿梭位点 (如 $(date +%Y-%m)): " d_month || true; if test -z "$d_month"; then vnstat -d 2>/dev/null | sed -e 's/estimated/预估/ig' -e 's/rx/接收/ig' -e 's/tx/出站/ig' -e 's/total/总计/ig' -e 's/daily/按日/ig' -e 's/monthly/按月/ig' || true; else vnstat -d 2>/dev/null | grep -iE "($d_month| day |estimated|--)" | sed -e 's/estimated/预估/ig' -e 's/rx/接收/ig' -e 's/tx/出站/ig' -e 's/total/总计/ig' -e 's/daily/按日/ig' -e 's/monthly/按月/ig' || true; fi; local _p=""; read -rp "Enter..." _p || true; fi ;;
            4) while true; do clear; title "雷达守望：深空网络实时拓扑连接图"; local x_pids=$(pidof xray 2>/dev/null | xargs | tr -s ' ' '|' || echo ""); if test -n "$x_pids"; then echo -e "  ${cyan}【底层驻留句柄分布态势】${none}"; ss -ntupa 2>/dev/null | grep -E "pid=($x_pids)[,)]" | awk '{print $1"_"$2}' | sort | uniq -c | sort -nr | awk '{printf "    网络层级: %-15s : 并行活数 %s\n", $2, $1}' || echo "    网关待机"; echo -e "\n  ${cyan}【独立外部 IP 数据池溯源 (Top 10)】${none}"; local ips=$(ss -ntupa 2>/dev/null | grep -E "pid=($x_pids)[,)]" | grep -vE "LISTEN|UNCONN" | awk '{print $6}' | sed -E 's/:[0-9]+$//' | tr -d '[]' | grep -vE "^127\.0\.0\.1$|^0\.0\.0\.0$|^::$|^\*$|^::ffff:127\.0\.0\.1$" || echo ""); if test -n "$ips"; then echo "$ips" | sort | uniq -c | sort -nr | head -n 10 | awk '{printf "    嗅探 IP: %-18s (并发信标数: %s)\n", $2, $1}'; local total_ips=$(echo "$ips" | sort | uniq | wc -l); echo -e "\n  [净化汇总] 全局不同外部物理连接 IP 总计: ${yellow}${total_ips}${none}"; else echo -e "    ${gray}无外部游荡者接入。${none}"; fi; else error "主机服务未响应。"; fi; echo -e "\n  ${green}追踪防卫模式运行中 (每 2 秒自刷刷新)... 键入 [ q ] 切断网络视图。${none}"; local cmd=""; if read -t 2 -n 1 -s cmd 2>/dev/null; then if test "$cmd" = "q" || test "$cmd" = "Q" || test "$cmd" = $'\e'; then break; fi; fi; done ;;
            5) while true; do clear; title "强制篡夺 CPU 底层分配表"; local limit_file="/etc/systemd/system/xray.service.d/limits.conf"; local current_nice="-20"; if test -f "$limit_file" && grep -q "^Nice=" "$limit_file" 2>/dev/null; then current_nice=$(awk -F'=' '/^Nice=/ {print $2}' "$limit_file" | head -n 1 || echo "-20"); fi; echo -e "  Xray 内核抢占权值定位: ${cyan}${current_nice}${none} (工业域: -20 到 -10)"; hr; local new_nice=""; read -rp "  写入系统优先级设定 (q 退出): " new_nice || true; if test "$new_nice" = "q" || test "$new_nice" = "Q"; then break; fi; if [[ "$new_nice" =~ ^-[1-2][0-9]$ ]] && test "$new_nice" -ge -20 2>/dev/null && test "$new_nice" -le -10 2>/dev/null; then sed -i "s/^Nice=.*/Nice=$new_nice/" "$limit_file" 2>/dev/null || true; systemctl daemon-reload >/dev/null 2>&1 || true; info "指令确认下发！由于抢夺底层权力，5 秒后重启进程验证..."; sleep 5; systemctl restart xray >/dev/null 2>&1 || true; info "权重交接完成。"; local _p=""; read -rp "Enter..." _p || true; break; else error "数据溢出限制门槛！"; sleep 2; fi; done ;;
            6) clear; title "全局核心通讯日志流"; tail -n 50 "$LOG_DIR/xray.log" 2>/dev/null || echo "  档案库真空。"; local _p=""; read -rp "按 Enter 回退..." _p || true ;;
            7) clear; title "全系统深空错误异常告警"; tail -n 30 "$LOG_DIR/error.log" 2>/dev/null || echo "  无异常。"; local _p=""; read -rp "按 Enter 回退..." _p || true ;;
            8) clear; title "高可用与灾难管理快照备份"; ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null || echo "当前冷备库空白。"; echo -e "\n  r) 系统反卷引擎：强行以最近正确的冷库替换现网逻辑\n  c) 物理抽帧冷封存：为当下的全局网络环境创建防灾记录\n  0) 取消动作"; local bopt=""; read -rp "抉择代码: " bopt || true; if test "$bopt" = "r" || test "$bopt" = "R"; then restore_latest_backup; fi; if test "$bopt" = "c" || test "$bopt" = "C"; then backup_config; info "已生成永久保存副本。"; local _p=""; read -rp "Enter..." _p || true; fi ;;
            0) return ;;
        esac
    done
}

do_update_core() {
    title "Xray 主心骨环境内核迭代"
    info "强联通官方源更新通道..."
    if bash -c "$(curl -L -s https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" @ install >/dev/null 2>&1; then
        if test -x "$XRAY_BIN"; then
            fix_xray_systemd_limits; systemctl restart xray >/dev/null 2>&1 || true
            local cur_ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 | awk '{print $2}' || echo "检索故障")
            info "全流程覆盖结束，当前主线跃迁到: ${cyan}$cur_ver${none}"
            local _p=""; read -rp "按 Enter 返回..." _p || true; return 0
        fi
    fi
    error "遭遇官方源封锁或 IPv6 数据穿透故障，拉取阻隔。"; local _p=""; read -rp "Enter..." _p || true; return 1
}

_update_matrix() {
    if test ! -f "$CONFIG"; then return; fi
    echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
    _safe_jq_write --arg dest "$BEST_SNI:443" --slurpfile snis /tmp/sni_array.json '
        (.inbounds[]? | select(. != null) | select(.protocol == "vless")) |= (
            .streamSettings.realitySettings.serverNames = $snis[0] |
            .streamSettings.realitySettings.dest = $dest
        )'
    rm -f /tmp/sni_array.json 2>/dev/null || true
    ensure_xray_is_alive; info "网络架构及反识别面具重构完毕，防封加载上线！"
}

do_install() {
    title "Apex Vanguard Ultimate Final: 高维协议建仓与底层核心网组建"
    preflight
    systemctl stop xray >/dev/null 2>&1 || true
    if test ! -f "$INSTALL_DATE_FILE"; then date +"%Y-%m-%d %H:%M:%S" > "$INSTALL_DATE_FILE"; fi
    
    echo -e "  ${cyan}决定本次将要搭载的网络体系：${none}"
    echo "  1) VLESS-Reality (极致安全伪装架构 / 防止主动探测阻断)"
    echo "  2) Shadowsocks (抛却重负载，极速穿透轻量备用网)"
    echo "  3) 启用高可用并行搭载系统 (双通道并发部署)"
    local proto_choice=""; read -rp "  执行命令编号 (回车默认 1): " proto_choice || true
    proto_choice=${proto_choice:-1}

    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        while true; do local input_p=""; read -rp "分配 VLESS 监听端口 (回车默认 443): " input_p || true; input_p=${input_p:-443}; if validate_port "$input_p"; then LISTEN_PORT="$input_p"; break; fi; done
        local input_remark=""; read -rp "规划 VLESS 节点基础标识名 (默认 xp-reality): " input_remark || true; REMARK_NAME=${input_remark:-xp-reality}
        choose_sni; if test $? -ne 0; then return 1; fi
    fi

    local ss_port=8388; local ss_pass=""; local ss_method="aes-256-gcm"
    if test "$proto_choice" = "2" || test "$proto_choice" = "3"; then
        while true; do local input_s=""; read -rp "分配 SS 端口 (默认 8388): " input_s || true; input_s=${input_s:-8388}; if validate_port "$input_s"; then ss_port="$input_s"; break; fi; done
        ss_pass=$(gen_ss_pass); ss_method=$(_select_ss_method)
        if test "$proto_choice" = "2"; then local input_remark=""; read -rp "配置 SS 标识 (默认 xp-reality): " input_remark || true; REMARK_NAME=${input_remark:-xp-reality}; fi
    fi

    info "从中心枢纽拉取最新的 Xray 核心主程序执行安装流..."
    if ! bash -c "$(curl -fsSL --connect-timeout 10 https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" @ install >/dev/null 2>&1; then warn "主脚本直连失败，稍后请在控制面板尝试执行手动核心更新操作。"; fi
    install_update_dat; fix_xray_systemd_limits

    cat > "$CONFIG" <<EOF
{ "log": { "loglevel": "warning" }, "routing": { "domainStrategy": "AsIs", "rules": [ { "outboundTag": "block", "_enabled": true, "protocol": ["bittorrent"] }, { "outboundTag": "block", "_enabled": true, "ip": ["geoip:cn"] }, { "outboundTag": "block", "_enabled": true, "domain": ["geosite:cn", "geosite:category-ads-all"] } ] }, "inbounds": [], "outbounds": [ { "protocol": "freedom", "tag": "direct", "settings": {"domainStrategy": "AsIs"} }, { "protocol": "blackhole", "tag": "block" } ] }
EOF

    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        local keys=$("$XRAY_BIN" x25519 2>/dev/null || echo ""); local priv=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' \r\n' || echo ""); local pub=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' \r\n' || echo ""); local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid); local sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n\r' || echo ""); local ctime=$(date +"%Y-%m-%d %H:%M")
        echo "$pub" > "$PUBKEY_FILE"; echo "$uuid|$ctime" > "$USER_TIME_MAP"; echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
        cat > /tmp/vless_inbound.json <<EOF
{ "tag": "vless-reality", "listen": "0.0.0.0", "port": $LISTEN_PORT, "protocol": "vless", "settings": { "clients": [ {"id": "$uuid", "flow": "xtls-rprx-vision", "email": "$REMARK_NAME"} ], "decryption": "none" }, "streamSettings": { "network": "tcp", "security": "reality", "sockopt": {"tcpNoDelay": true, "tcpFastOpen": true}, "realitySettings": { "dest": "$BEST_SNI:443", "serverNames": [], "privateKey": "$priv", "publicKey": "$pub", "shortIds": ["$sid"], "limitFallbackUpload": {"afterBytes": 0, "bytesPerSec": 0, "burstBytesPerSec": 0}, "limitFallbackDownload": {"afterBytes": 0, "bytesPerSec": 0, "burstBytesPerSec": 0} } }, "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] } }
EOF
        _safe_jq_write --slurpfile snis /tmp/sni_array.json --slurpfile vless_tmp /tmp/vless_inbound.json '.inbounds += [ $vless_tmp[0] | .streamSettings.realitySettings.serverNames = $snis[0] ]'
        rm -f /tmp/vless_inbound.json /tmp/sni_array.json 2>/dev/null || true
    fi

    if test "$proto_choice" = "2" || test "$proto_choice" = "3"; then
        cat > /tmp/ss_inbound.json <<EOF
{ "tag": "shadowsocks", "listen": "0.0.0.0", "port": $ss_port, "protocol": "shadowsocks", "settings": { "method": "$ss_method", "password": "$ss_pass", "network": "tcp,udp" }, "streamSettings": { "sockopt": {"tcpNoDelay": true, "tcpFastOpen": true} } }
EOF
        _safe_jq_write --slurpfile ss_tmp /tmp/ss_inbound.json '.inbounds += [ $ss_tmp[0] ]'
        rm -f /tmp/ss_inbound.json 2>/dev/null || true
    fi

    fix_permissions; systemctl enable xray >/dev/null 2>&1 || true
    if ensure_xray_is_alive; then info "所有架构配置装载确认生效！通讯网络已打开。"; do_summary; else error "贯通服务进程失败，请检查日志。"; return 1; fi
    while true; do local opt=""; read -rp "按 Enter 返回，亦或输入 b 即刻执行 SNI 的漂移: " opt || true; if test "$opt" = "b" || test "$opt" = "B"; then if choose_sni; then _update_matrix; do_summary; else break; fi; else break; fi; done
}

do_uninstall() {
    title "终极断供清理器：彻底摧毁当前生态环境并回卷"
    local confirm=""; read -rp "此指令将摧毁私钥及配置 (网卡保留)，您明确此行为吗？(y/n): " confirm || true
    if test "$confirm" != "y"; then return; fi
    info "开始核心粉碎..."
    systemctl stop dnsmasq >/dev/null 2>&1 || true; systemctl disable dnsmasq >/dev/null 2>&1 || true; export DEBIAN_FRONTEND=noninteractive; apt-get purge -y dnsmasq >/dev/null 2>&1 || true
    chattr -i /etc/resolv.conf 2>/dev/null || true; if test -f /etc/resolv.conf.bak; then mv -f /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true; fi
    systemctl stop resolvconf.service >/dev/null 2>&1 || true; systemctl disable resolvconf.service >/dev/null 2>&1 || true
    if systemctl list-unit-files | grep -q systemd-resolved 2>/dev/null; then systemctl enable systemd-resolved >/dev/null 2>&1 || true; systemctl start systemd-resolved >/dev/null 2>&1 || true; fi
    systemctl stop xray >/dev/null 2>&1 || true; systemctl disable xray >/dev/null 2>&1 || true; rm -rf /etc/systemd/system/xray* /lib/systemd/system/xray* >/dev/null 2>&1 || true; systemctl daemon-reload >/dev/null 2>&1 || true
    rm -rf "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SCRIPT_DIR" /var/log/xray* /usr/local/bin/xrv "$SCRIPT_PATH" >/dev/null 2>&1 || true
    local temp_cron=$(mktemp /tmp/cron_XXXXXX) || true; if test -f "$temp_cron"; then crontab -l 2>/dev/null | grep -v "update-dat.sh" | grep -v "systemctl restart xray" | grep -v "cc1.sh" > "$temp_cron" || true; crontab "$temp_cron" 2>/dev/null || true; rm -f "$temp_cron" 2>/dev/null || true; fi
    info "物理痕迹及配置文件已完全格式化，现网回归系统纯净初始状态！"; exit 0
}
# --- ✂️ Part 19 结束，请复制并合并下方的 Part 20 ✂️ ---
# --- ✂️ 紧接在 Part 19 之后粘贴此 Part 20 ✂️ ---

main_menu() {
    while true; do
        clear
        echo -e "${blue}======================================================================${none}"
        echo -e "  ${magenta}Xray System Advanced Management V196e41 - (The Apex Vanguard)${none}"
        
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        if test "$svc" = "active"; then svc="${green}平稳在线 (Running)${none}"; else svc="${red}离线静默 (Stopped)${none}"; fi
        local sys_ver=$(uname -r 2>/dev/null || echo "未探测到数据")
        echo -e "  引擎态势: $svc | 全局快捷指令: ${cyan}xrv${none} | 外部识别 IP: ${yellow}$(_get_ip || echo "探测异常")${none}"
        echo -e "  系统装配内核: ${cyan}${sys_ver}${none} | 微架构侦测: x64-v${yellow}$(_detect_psabi_level)${none}"
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
        echo "  10) 高级发烧：内核双轨编译(APT/源码)/网络/应用层 60余项极限全控板"
        echo "  0) 折叠命令控制台，返回底层终端"
        echo -e "  ${red}88) 物理不可逆自毁！撤销环境安全防线与系统配置设定${none}"
        hr
        
        local num=""; read -rp "请输入操作代码指令: " num || true
        case "${num:-}" in
            1) do_install ;;
            2) do_user_manager ;;
            3) do_summary; while true; do local rb=""; read -rp "输出完毕，按 Enter 退出或者按 b 发起特征替换: " rb || true; if test "$rb" = "b" || test "$rb" = "B"; then if choose_sni; then _update_matrix; do_summary; else break; fi; else break; fi; done ;;
            4) print_magenta ">>> 初始化云网络联通..."; bash "$UPDATE_DAT_SCRIPT" >/dev/null 2>&1 || true; ensure_xray_is_alive; info "配置已穿透替换系统！当前路由库完成热加载！"; local _p=""; read -rp "按 Enter 退回..." _p || true ;;
            5) do_update_core ;;
            6) if choose_sni; then _update_matrix; do_summary; while true; do local rb=""; read -rp "任务完毕，按 Enter 返回，或按 b 连续变更: " rb || true; if test "$rb" = "b" || test "$rb" = "B"; then if choose_sni; then _update_matrix; do_summary; else break; fi; else break; fi; done; fi ;;
            7) _global_block_rules ;;
            8) do_fallback_probe ;;
            9) do_status_menu ;;
            10) do_sys_init_menu ;;
            88) do_uninstall ;;
            0) exit 0 ;;
            *) echo -e "${red}错误拦截：代码解析为空值！${none}"; sleep 1 ;;
        esac
    done
}

preflight
main_menu

# ==============================================================================
# EOF - Apex Vanguard V196e41 System Advanced Control Ready.
# ==============================================================================
# --- ✂️ Part 20 结束，所有代码拼接完毕。请运行 bash ex196e41.sh ---
