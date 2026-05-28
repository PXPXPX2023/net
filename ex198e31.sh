#!/usr/bin/env bash
#==============================================================================
# 脚本名称: ex198e31.sh (The Apex Vanguard - Project Genesis V198e31)
# 快捷方式: xrv
# 【V198e31 终极安全守护版：修复 VPS 虚拟化崩溃、OOM 内存溢出与网卡失联漏洞】
#==============================================================================
if test -z "${BASH_VERSION:-}"; then echo "Error: 请使用 bash 执行本脚本: bash ex198e31.sh"; exit 1; fi
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

readonly SCRIPT_VERSION="198e31"
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
    rm -f /tmp/sni_array.json /tmp/vless_inbound.json /tmp/vless_final.json /tmp/ss_inbound.json /tmp/new_client.json /tmp/xray_users*.txt /tmp/install-release.sh /tmp/sni_test.* /tmp/check_x86-64_psabi.sh /tmp/current_cron /tmp/kernel-arch.cfg /tmp/lsmod.now 2>/dev/null || true
}

check_and_clean_space() {
    info "执行空间释放与清理协议..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get clean >/dev/null 2>&1 || true
    apt-get autoremove -y --purge >/dev/null 2>&1 || true
    journalctl --vacuum-time=1d >/dev/null 2>&1 || true
    # FIX: Softened tmp cleanup to prevent breaking active unix sockets
    rm -rf /var/cache/apt/archives/* /usr/src/linux* /usr/src/bbr* /usr/src/xanmod* /compile/* /root/linux* /root/*.tar* /root/*.gz /root/*.xz 2>/dev/null || true
    sync
}

finalize() {
    info "执行最终收尾清理与固化序列..."
    sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    info "所有底层进程节点流转完毕，Apex Vanguard 环境已彻底就绪。"
}

_err_handler() {
    local code=$1 line=$2 cmd=$3
    echo -e "\n${red}================== [ SYSTEM PANIC ] ==================${none}" >&2
    echo -e "${yellow} >> 战舰核心遇到异常断层，系统自我保护机制触发！${none}" >&2
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

detect_x86_64_level() {
    local script="/tmp/check_x86-64_psabi.sh"
    local level="1"
    
    if curl -fsSL --connect-timeout 5 https://dl.xanmod.org/check_x86-64_psabi.sh -o "$script" 2>/dev/null; then
        chmod +x "$script" 2>/dev/null || true
        level=$(awk -f "$script" 2>/dev/null | grep -oE 'x86-64-v[1-4]' | grep -oE '[1-4]' | tail -n1 || echo "")
        rm -f "$script" 2>/dev/null || true
    fi

    if [[ ! "$level" =~ ^[1-4]$ ]]; then
        level=1
    fi
    echo "$level"
}

_get_safe_march() {
    local lvl="${1:-1}"
    case "$lvl" in
        4) echo "x86-64-v4" ;;
        3) echo "x86-64-v3" ;;
        2) echo "x86-64-v2" ;;
        *) echo "x86-64" ;;
    esac
}

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

    local need="jq curl wget xxd unzip qrencode vnstat cron openssl coreutils sed e2fsprogs pkg-config iproute2 ethtool bc bison flex dwarves rsync python3 cpio apt-transport-https lz4 liblz4-tool pciutils gcc-multilib libc6-dev-i386 zstd iptables"
    local missing=""
    for p in $need; do
        if ! command -v "$p" >/dev/null 2>&1; then missing="$missing $p"; fi
    done
    
    if test -n "$missing"; then
        info "正在同步工业级依赖 (含32/64位全量编译内核套件 & iptables): $missing"
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

check_and_create_swap() {
    title "检查并配置 1050MB Swap 防爆缓冲池"

    local SWAP_FILE="/swapfile"
    local TARGET_SWAP_MB=1050

    if swapon --show | grep -q "^$SWAP_FILE"; then
        local CURRENT_SWAP_MB
        CURRENT_SWAP_MB=$(swapon --show --bytes | awk -v f="$SWAP_FILE" '$1==f {print int($3/1024/1024)}')

        if [ "$CURRENT_SWAP_MB" -ge "$TARGET_SWAP_MB" ]; then
            info "检测到已有 ${CURRENT_SWAP_MB}MB Swap，无需重复创建。"
            return
        else
            warn "检测到 Swap 大小不足 (${CURRENT_SWAP_MB}MB)，准备重建..."
            swapoff "$SWAP_FILE" 2>/dev/null || true
            rm -f "$SWAP_FILE" 2>/dev/null || true
        fi
    fi

    # FIX: Robustly clean existing exact fstab matches without deleting other swaps
    sed -i '\|^/swapfile |d' /etc/fstab 2>/dev/null || true

    info "开始创建 ${TARGET_SWAP_MB}MB Swap..."

    if ! dd if=/dev/zero of="$SWAP_FILE" bs=1M count=${TARGET_SWAP_MB} status=progress 2>/dev/null; then
        warn "Swap 创建失败。"
        return
    fi

    chmod 600 "$SWAP_FILE" || true

    if ! mkswap "$SWAP_FILE" >/dev/null 2>&1; then
        warn "mkswap 失败。"
        rm -f "$SWAP_FILE" 2>/dev/null || true
        return
    fi

    if ! swapon "$SWAP_FILE" >/dev/null 2>&1; then
        warn "swapon 启动失败。"
        rm -f "$SWAP_FILE" 2>/dev/null || true
        return
    fi

    if ! grep -q "^/swapfile " /etc/fstab 2>/dev/null; then
        echo "/swapfile none swap sw,nofail 0 0" >> /etc/fstab
    fi

    sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
    info "1050MB Swap 防爆缓冲池配置完成。"
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

    # FIX: LimitNOFILE reduced to 512000 to prevent startup failure on constrained kernels
    cat > "$limit_file" << EOF
[Service]
LimitNOFILE=512000
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
    title "配置系统 DNS (systemd-resolved 安全模式)"

    if ! systemctl list-unit-files | grep -q "^systemd-resolved"; then
        warn "系统未检测到 systemd-resolved，跳过 DNS 配置。"
        return
    fi

    local IFACE
    IFACE=$(ip route | awk '/default/ {print $5}' | head -n1)

    if [ -z "$IFACE" ]; then
        warn "无法检测默认网卡，DNS 配置终止。"
        return
    fi

    info "检测到主网卡: $IFACE"

    local nameserver=""
    local fallback_dns="1.1.1.1 208.67.222.222"

    while true; do
        read -rp "请输入主 DNS IP (例如 1.1.1.1): " nameserver || true
        if [[ $nameserver =~ ^([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]]; then
            break
        else
            print_red "DNS IP 格式错误，请重新输入。"
        fi
    done

    info "启用 systemd-resolved..."
    systemctl enable systemd-resolved >/dev/null 2>&1 || true
    systemctl restart systemd-resolved >/dev/null 2>&1 || true

    # FIX: Safely symlink resolv.conf without deleting it violently
    if ! readlink /etc/resolv.conf | grep -q "stub-resolv.conf"; then
        cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true
        ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    fi

    mkdir -p /etc/systemd
    cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=${nameserver}
FallbackDNS=${fallback_dns}
DNSStubListener=yes
DNSSEC=no
EOF

    systemctl restart systemd-resolved >/dev/null 2>&1 || true
    resolvectl dns "$IFACE" "$nameserver" 1.1.1.1 208.67.222.222 >/dev/null 2>&1 || true
    resolvectl domain "$IFACE" "~." >/dev/null 2>&1 || true
    sleep 2

    if ping -c1 -W3 google.com >/dev/null 2>&1; then
        info "DNS 配置成功。"
    else
        warn "DNS 解析失败，回退安全配置..."
        cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=1.1.1.1 208.67.222.222
FallbackDNS=9.9.9.9 1.0.0.1
DNSStubListener=yes
DNSSEC=no
EOF
        systemctl restart systemd-resolved >/dev/null 2>&1 || true
        resolvectl dns "$IFACE" 1.1.1.1 208.97.222.222 >/dev/null 2>&1 || true
        sleep 2
    fi
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
        error "Xray 服务启动失败，回滚备份..."
        restore_latest_backup
        return 1
    fi
}

run_sni_scanner() {
    title "雷达嗅探：130+ 实体矩阵与国内连通性探测"
    print_yellow ">>> 扫描进行中... (随时按回车键可立即中止)\n"
    if ! mkdir -p "$CONFIG_DIR" 2>/dev/null; then true; fi
    
    local sni_list=(
        "www.apple.com" "support.apple.com" "developer.apple.com" "id.apple.com" "icloud.apple.com"
        "www.microsoft.com" "login.microsoftonline.com" "portal.azure.com" "support.microsoft.com" "office.com"
        "www.intel.com" "downloadcenter.intel.com" "www.amd.com" "drivers.amd.com" "community.amd.com"
        "www.dell.com" "support.dell.com" "www.hp.com" "support.hp.com" "developers.hp.com"
        "www.bmw.com" "shop.bmw.com" "www.mercedes-benz.com" "me.mercedes-benz.com"
        "www.toyota-global.com" "www.toyota.com" "www.honda.com" "www.volkswagen.com"
        "www.nike.com" "account.nike.com" "store.nike.com" "www.adidas.com"
        "www.zara.com" "static.zara.net" "www.ikea.com" "secure.ikea.com"
        "www.tesla.com" "s0.awsstatic.com" "d1.awsstatic.com" "images-na.ssl-images-amazon.com"
        "www.nvidia.com" "docs.nvidia.com" "www.samsung.com" "www.oracle.com" "www.cisco.com"
        "www.zoom.us" "www.adobe.com" "www.autodesk.com" "www.salesforce.com" "www.ibm.com"
        "www.mcdonalds.com" "www.starbucks.com" "www.rolex.com" "www.burberry.com" "www.cartier.com"
        "www.tiktok.com" "www.netflix.com" "www.hulu.com" "www.disneyplus.com"
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
            echo "  q) 取遇到问题退回上级菜单"
            
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

do_install_xanmod_main_official() {
    title "安装官方预编译 XANMOD 内核 (APT)"
    warn "警告: 更改内核有导致 VPS 无法引导的风险！"
    
    if [[ "$(uname -m)" != "x86_64" ]]; then 
        error "官方源安装当前仅支持 x86_64 架构！"
        local _p=""; read -rp "按 Enter 返回..." _p || true
        return 1
    fi

    export DEBIAN_FRONTEND=noninteractive

    warn "正在同步核心依赖..."
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y curl wget gnupg ca-certificates lsb-release >/dev/null 2>&1 || true

    warn "执行全域 CPU 指令集等级检测..."
    local cpu_level=$(detect_x86_64_level)
    info "架构锁定: x86-64-v${cpu_level}"

    mkdir -p /etc/apt/keyrings
    curl -fsSL --connect-timeout 10 https://dl.xanmod.org/gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/xanmod.gpg 2>/dev/null || true

    echo "deb [signed-by=/etc/apt/keyrings/xanmod.gpg] http://deb.xanmod.org releases main" > /etc/apt/sources.list.d/xanmod-kernel.list
    apt-get update -y >/dev/null 2>&1 || true

    local installed=0
    for lvl in "$cpu_level" 3 2 1; do
        local pkg="linux-xanmod-x64v${lvl}"
        warn "正在尝试拉取并安装: $pkg"
        if apt-get install -y "$pkg"; then
            print_green ">>> 成功注入核心包: $pkg"
            installed=1
            break
        fi
    done

    if [[ "$installed" -ne 1 ]]; then
        error "预编译库全线拉取失败，请检查网络或更换软件源！"
        return 1
    fi

    # FIX: Safely update grub without forcing GRUB_DEFAULT=0 destructively on VPS
    if command -v update-grub >/dev/null 2>&1; then
        update-grub >/dev/null 2>&1 || true
    else
        apt-get install -y grub2-common >/dev/null 2>&1 || true
        update-grub >/dev/null 2>&1 || true
    fi

    warn "Xanmod 内核安装完毕。请根据云服务商要求手动重启验证。"
    local _p=""; read -rp "按 Enter 返回..." _p || true
}

do_kernel_compile_menu() {
    while true; do
        clear
        title "内核管理中心"
        echo -e "  ${red}警告: 在低于 4 核 4GB 的 VPS 上从源码编译内核会导致 100% 死机与云商断网！${none}"
        echo ""
        echo -e "  ${cyan}1) [官方推荐] APT 安装 Xanmod 预编译稳定内核${none}"
        echo -e "  ${gray}2) [已锁定] 手工编译 Xanmod 源码 (防止资源耗尽宕机)${none}"
        echo -e "  ${gray}3) [已锁定] 手工编译 Linux 主线源码 (防止资源耗尽宕机)${none}"
        echo ""
        echo "  0) 返回上级菜单"
        hr
        
        local k_opt=""; read -rp "请下达锻造路径指令 (0-1): " k_opt || true
        case "${k_opt:-}" in
            1) do_install_xanmod_main_official; return ;;
            2|3) warn "因安全策略限制，此功能已被封锁，防止 VPS 被云商挂起。"; sleep 2 ;;
            0) return ;;
        esac
    done
}

do_perf_tuning() {
    title "全域系统网络栈优化 (安全防护版)"
    
    local default_route=$(ip route show default 2>/dev/null | head -n 1)
    if [[ -n "$default_route" ]]; then
        local clean_route=$(echo "$default_route" | sed 's/ initcwnd [0-9]*//g' | sed 's/ initrwnd [0-9]*//g')
        ip route change $clean_route initcwnd 10 initrwnd 10 2>/dev/null || true
        echo "10" > "$CONFIG_DIR/initcwnd.txt"
        info "已成功向网卡默认路由下发优化慢启动参数！"
    fi
    
    info "清理冗余网络配置..."
    truncate -s 0 /etc/sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-sysctl.conf 2>/dev/null || true
    rm -f /etc/sysctl.d/99-network-optimized.conf /etc/sysctl.d/99-bbr*.conf 2>/dev/null || true

    mkdir -p /etc/security/limits.d 2>/dev/null || true
    # FIX: Reasonable process/file limits
    cat > /etc/security/limits.d/99-xray-limits.conf << 'EOF'
root soft nofile 512000
root hard nofile 512000
root soft nproc 512000
root hard nproc 512000

* soft nofile 512000
* hard nofile 512000
* soft nproc 512000
* hard nproc 512000
EOF

    mkdir -p /etc/systemd/system.conf.d 2>/dev/null || true
    cat > /etc/systemd/system.conf.d/99-xray-limits.conf << 'EOF'
[Manager]
DefaultLimitNOFILE=512000
DefaultLimitNPROC=512000
EOF
    systemctl daemon-reexec >/dev/null 2>&1 || true

    # FIX: Safer TCP buffer values (Cloudflare Edge standard)
    info "写入安全的内核 Sysctl 参数..."
    cat > /etc/sysctl.d/99-network-optimized.conf << EOF
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 1

net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 262144
net.ipv4.tcp_tw_reuse = 1
net.ipv4.ip_local_port_range = 1024 65535

fs.file-max = 1048576
vm.swappiness = 10
EOF

    if ! sysctl -p /etc/sysctl.d/99-network-optimized.conf >/dev/null 2>&1; then
        error "Sysctl 参数应用存在错误，部分硬件不支持。"
    else
        info "底层 Sysctl 参数已成功注入 (内存防溢出锁定)。"
    fi
    local _p=""; read -rp "按 Enter 返回菜单..." _p || true
}

do_txqueuelen_opt() {
    title "网卡发送队列 (TX Queue) 调优"
    local IP_CMD=$(command -v ip || echo "")
    local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if test -z "$IFACE"; then error "无法定位系统默认出口网卡。"; return 1; fi
    
    # FIX: Exclude virtual interfaces from extreme txqueuelen manipulation
    if ethtool -i "$IFACE" 2>/dev/null | grep -qi "virtio"; then
        error "检测到 Virtio 虚拟网卡，调整 txqueuelen 可能导致宿主机断网，已强制拦截！"
        local _p=""; read -rp "按 Enter 返回..." _p || true; return 1
    fi

    info "正在修改 $IFACE 发送队列长度至 5000..."
    $IP_CMD link set "$IFACE" txqueuelen 5000 2>/dev/null || true
    
    cat > /etc/systemd/system/txqueue.service << EOF
[Unit]
Description=Set TX Queue Length for Low Latency
After=network.target

[Service]
Type=oneshot
ExecStart=$IP_CMD link set $IFACE txqueuelen 5000
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable txqueue >/dev/null 2>&1 || true
    systemctl start txqueue >/dev/null 2>&1 || true
    info "已成功将网卡底层并发队列长度调优。"
    local _p=""; read -rp "按 Enter 键返回主菜单..." _p || true
}

check_dnsmasq_state() { if systemctl is-active dnsmasq >/dev/null 2>&1 && grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null; then echo "true"; else echo "false"; fi; }

toggle_dnsmasq() {
    if [ "$(check_dnsmasq_state)" = "true" ]; then
        systemctl stop dnsmasq >/dev/null 2>&1 || true; systemctl disable dnsmasq >/dev/null 2>&1 || true
        # FIX: Safe restoration of resolv.conf
        if [ -f /etc/resolv.conf.bak ]; then
            rm -f /etc/resolv.conf 2>/dev/null || true
            cp /etc/resolv.conf.bak /etc/resolv.conf
        else
            echo "nameserver 1.1.1.1" > /etc/resolv.conf
        fi
        systemctl enable systemd-resolved >/dev/null 2>&1 || true; systemctl start systemd-resolved >/dev/null 2>&1 || true
    else
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y >/dev/null 2>&1 || true
        apt-get install -y dnsmasq >/dev/null 2>&1 || true
        systemctl stop systemd-resolved 2>/dev/null || true
        systemctl disable systemd-resolved 2>/dev/null || true
        cat > /etc/dnsmasq.conf <<EOF
port=53
listen-address=127.0.0.1
bind-interfaces
cache-size=10000
server=1.1.1.1
server=8.8.8.8
domain-needed
bogus-priv
EOF
        systemctl enable dnsmasq >/dev/null 2>&1 || true; systemctl restart dnsmasq >/dev/null 2>&1 || true
        if [ ! -f /etc/resolv.conf.bak ]; then cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true; fi
        rm -f /etc/resolv.conf 2>/dev/null || true
        echo "nameserver 127.0.0.1" > /etc/resolv.conf
    fi
}

update_hw_boot_script() {
    cat << 'EOF' > /usr/local/bin/xray-hw-tweaks.sh
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
EOF
    # FIX: Ensure ethtool hardware commands don't run on virtio which crashes
    cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
if ! ethtool -i "$IFACE" 2>/dev/null | grep -qi "virtio"; then
    ethtool -K $IFACE gro off gso off tso off 2>/dev/null || true
fi
EOF
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

do_status_menu() {
    while true; do
        clear
        title "主控台: 监控及账单核心"
        echo "  1) [系统守护] 追踪主线程服务健康率"
        echo "  2) [全网穿透] 检测基础外网及监听位态"
        echo "  3) [总计账单] 调取网卡出入核算账册 (vnstat)"
        echo "  0) 返回中控区"
        hr
        local s=""; read -rp "执行指令: " s || true
        case "${s:-}" in
            1) systemctl status xray --no-pager || true; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            2) echo -e "\n  [公网物理层] IP地址: ${green}$SERVER_IP${none}"; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            3) 
                if ! command -v vnstat >/dev/null 2>&1; then warn "未安装 vnstat。"; local _p=""; read -rp "Enter..." _p || true; continue; fi
                clear; title "底层网卡流量计费审计中心"
                vnstat -m 2>/dev/null || true
                local _p=""; read -rp "按 Enter 返回主操作台..." _p || true
                ;;
            0) return ;;
        esac
    done
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
    title "Apex Vanguard: 高维协议建仓与底层核心网组建 (安全版)"
    preflight
    systemctl stop xray >/dev/null 2>&1 || true
    if test ! -f "$INSTALL_DATE_FILE"; then date +"%Y-%m-%d %H:%M:%S" > "$INSTALL_DATE_FILE"; fi
    
    echo -e "  ${cyan}决定本次将要搭载的网络体系：${none}"
    echo "  1) VLESS-Reality (极致安全伪装架构 / 防止主动探测阻断)"
    echo "  2) Shadowsocks (抛却重负载，极速穿透轻量备用网)"
    local proto_choice=""; read -rp "  执行命令编号 (回车默认 1): " proto_choice || true
    proto_choice=${proto_choice:-1}

    if test "$proto_choice" = "1"; then
        while true; do local input_p=""; read -rp "分配 VLESS 监听端口 (回车默认 443): " input_p || true; input_p=${input_p:-443}; if validate_port "$input_p"; then LISTEN_PORT="$input_p"; break; fi; done
        local input_remark=""; read -rp "规划 VLESS 节点基础标识名 (默认 xp-reality): " input_remark || true; REMARK_NAME=${input_remark:-xp-reality}
        choose_sni; if test $? -ne 0; then return 1; fi
    fi

    local ss_port=8388; local ss_pass=""; local ss_method="aes-256-gcm"
    if test "$proto_choice" = "2"; then
        while true; do local input_s=""; read -rp "分配 SS 端口 (默认 8388): " input_s || true; input_s=${input_s:-8388}; if validate_port "$input_s"; then ss_port="$input_s"; break; fi; done
        ss_pass=$(gen_ss_pass); ss_method=$(_select_ss_method)
        local input_remark=""; read -rp "配置 SS 标识 (默认 xp-reality): " input_remark || true; REMARK_NAME=${input_remark:-xp-reality}
    fi

    info "从中心枢纽拉取最新的 Xray 核心主程序执行安装流..."
    if ! bash -c "$(curl -fsSL --connect-timeout 10 https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" @ install >/dev/null 2>&1; then warn "主脚本直连失败，稍后请在控制面板尝试执行手动核心更新操作。"; fi
    install_update_dat; fix_xray_systemd_limits

    cat > "$CONFIG" <<EOF
{ "log": { "loglevel": "warning" }, "routing": { "domainStrategy": "AsIs", "rules": [ { "outboundTag": "block", "_enabled": true, "protocol": ["bittorrent"] }, { "outboundTag": "block", "_enabled": true, "ip": ["geoip:cn"] }, { "outboundTag": "block", "_enabled": true, "domain": ["geosite:cn", "geosite:category-ads-all"] } ] }, "inbounds": [], "outbounds": [ { "protocol": "freedom", "tag": "direct", "settings": {"domainStrategy": "AsIs"} }, { "protocol": "blackhole", "tag": "block" } ] }
EOF

    if test "$proto_choice" = "1"; then
        local keys=$("$XRAY_BIN" x25519 2>/dev/null || echo ""); local priv=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' \r\n' || echo ""); local pub=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' \r\n' || echo ""); local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid); local sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n\r' || echo ""); local ctime=$(date +"%Y-%m-%d %H:%M")
        echo "$pub" > "$PUBKEY_FILE"; echo "$uuid|$ctime" > "$USER_TIME_MAP"; echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
        cat > /tmp/vless_inbound.json <<EOF
{ "tag": "vless-reality", "listen": "0.0.0.0", "port": $LISTEN_PORT, "protocol": "vless", "settings": { "clients": [ {"id": "$uuid", "flow": "xtls-rprx-vision", "email": "$REMARK_NAME"} ], "decryption": "none" }, "streamSettings": { "network": "tcp", "security": "reality", "sockopt": {"tcpNoDelay": true, "tcpFastOpen": true}, "realitySettings": { "dest": "$BEST_SNI:443", "serverNames": [], "privateKey": "$priv", "publicKey": "$pub", "shortIds": ["$sid"] } }, "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] } }
EOF
        _safe_jq_write --slurpfile snis /tmp/sni_array.json --slurpfile vless_tmp /tmp/vless_inbound.json '.inbounds += [ $vless_tmp[0] | .streamSettings.realitySettings.serverNames = $snis[0] ]'
        rm -f /tmp/vless_inbound.json /tmp/sni_array.json 2>/dev/null || true
    fi

    if test "$proto_choice" = "2"; then
        cat > /tmp/ss_inbound.json <<EOF
{ "tag": "shadowsocks", "listen": "0.0.0.0", "port": $ss_port, "protocol": "shadowsocks", "settings": { "method": "$ss_method", "password": "$ss_pass", "network": "tcp,udp" }, "streamSettings": { "sockopt": {"tcpNoDelay": true, "tcpFastOpen": true} } }
EOF
        _safe_jq_write --slurpfile ss_tmp /tmp/ss_inbound.json '.inbounds += [ $ss_tmp[0] ]'
        rm -f /tmp/ss_inbound.json 2>/dev/null || true
    fi

    fix_permissions; systemctl enable xray >/dev/null 2>&1 || true
    if ensure_xray_is_alive; then info "所有架构配置装载确认生效！"; else error "贯通服务进程失败，请检查日志。"; return 1; fi
    finalize
}

main_menu() {
    while true; do
        clear
        echo -e "${blue}======================================================================${none}"
        echo -e "  ${magenta}Xray System Management V198e31 - (The Apex Vanguard - Safe Mode)${none}"
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        if test "$svc" = "active"; then svc="${green}平稳在线 (Running)${none}"; else svc="${red}离线静默 (Stopped)${none}"; fi
        local sys_ver=$(uname -r 2>/dev/null || echo "未探测到数据")
        echo -e "  引擎态势: $svc | 全局快捷指令: ${cyan}xrv${none} | 外部识别 IP: ${yellow}$(_get_ip || echo "探测异常")${none}"
        echo -e "  系统装配内核: ${cyan}${sys_ver}${none} | 微架构侦测: x64-v${yellow}$(detect_x86_64_level)${none}"
        echo -e "${blue}======================================================================${none}"
        echo "  1) 创建/重构 安全底层全加密协议网络连接"
        echo "  2) DNS 独立解析引擎配置 (系统级防劫持)"
        echo "  3) 高性能内核与物理防拥堵协议部署 (Sysctl安全级)"
        echo "  4) 全景网络连接审计日志与状态账本"
        echo "  0) 退出系统"
        hr
        
        local num=""; read -rp "请输入操作代码指令: " num || true
        case "${num:-}" in
            1) do_install ;;
            2) toggle_dnsmasq; local _p=""; read -rp "执行完毕，按 Enter 继续..." _p || true ;;
            3) do_perf_tuning ;;
            4) do_status_menu ;;
            0) exit 0 ;;
            *) echo -e "${red}错误拦截：代码解析为空值！${none}"; sleep 1 ;;
        esac
    done
}

preflight
main_menu
