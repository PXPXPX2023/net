#!/usr/bin/env bash
#==============================================================================
# 脚本名称: ex198e29.sh (The Apex Vanguard - Project Genesis V198e29)
# 快捷方式: xrv
# 【V198e29 终极融合增强版：e28严格防爆框架 + e27全量极客内核/应用层微操】
#==============================================================================

set -Eeuo pipefail
IFS=$' \n\t'
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

#==============================================================================
# 1. 核心常量与全局状态锚定
#==============================================================================
readonly SCRIPT_VERSION="198e29"
readonly BASE_DIR="/usr/local/ex198e29"
readonly LOG_DIR="$BASE_DIR/logs"
readonly BACKUP_DIR="$BASE_DIR/backups"
readonly RUNTIME_DIR="$BASE_DIR/runtime"
readonly LOCK_DIR="$BASE_DIR/locks"
readonly TMP_DIR="/tmp/ex198e29"

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
readonly SYMLINK="/usr/local/bin/xrv"
readonly SCRIPT_PATH=$(readlink -f "$0")

GLOBAL_IP=""
SERVER_IP=""
REMARK_NAME="xp-reality"
BEST_SNI="www.microsoft.com"
SNI_JSON_ARRAY="\"www.microsoft.com\""
LISTEN_PORT=443

#==============================================================================
# 2. 颜色与 UI 引擎
#==============================================================================
readonly red='\033[31m'
readonly green='\033[32m'
readonly yellow='\033[33m'
readonly blue='\033[34m'
readonly magenta='\033[35m'
readonly cyan='\033[36m'
readonly gray='\033[90m'
readonly none='\033[0m'

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

log_info()  { echo "[$(date '+%F %T')] INFO: $*" >> "$LOG_DIR/main.log" 2>/dev/null || true; }
log_warn()  { echo "[$(date '+%F %T')] WARN: $*" >> "$LOG_DIR/main.log" 2>/dev/null || true; }
log_error() { echo "[$(date '+%F %T')] ERROR: $*" >> "$LOG_DIR/error.log" 2>/dev/null || true; }

#==============================================================================
# 3. 严格防爆与异常捕获协议 (TRAP & LOCK)
#==============================================================================
cleanup_runtime() {
    rm -rf /tmp/sni_array.json /tmp/vless_inbound.json /tmp/ss_inbound.json /tmp/new_client.json /tmp/xray_users*.txt /tmp/install-release.sh /tmp/sni_test.* /tmp/check_x86-64_psabi.sh /tmp/current_cron /tmp/kernel-arch.cfg /tmp/lsmod.now 2>/dev/null || true
    find "$TMP_DIR" -mindepth 1 -delete 2>/dev/null || true
}

panic_handler() {
    local exit_code=$1 line=$2 cmd=$3
    echo -e "\n${red}================== [ SYSTEM PANIC ] ==================${none}" >&2
    echo -e "${yellow} >> 战舰核心遇到致命断层，运行已被系统强行熔断！${none}" >&2
    echo -e "${cyan} >> 错误代号: ${none}${exit_code}" >&2
    echo -e "${cyan} >> 崩溃行号: ${none}${line}" >&2
    echo -e "${cyan} >> 故障指令: ${none}${cmd}" >&2
    echo -e "${red}======================================================${none}\n" >&2
    log_error "PANIC exit=$exit_code line=$line cmd=[$cmd]"
    cleanup_runtime
}

trap 'panic_handler $? $LINENO "$BASH_COMMAND"' ERR
trap cleanup_runtime EXIT

acquire_lock() {
    exec 200>"$LOCK_DIR/main.lock"
    flock -n 200 || die "底层守望者警告：前置脚本部署进程仍在运行中，锁定失败。"
}

#==============================================================================
# 4. 环境探测与基础支撑架构
#==============================================================================
detect_virtualization() { systemd-detect-virt 2>/dev/null || echo "unknown"; }
detect_bootloader() {
    if [[ -d /sys/firmware/efi ]]; then echo "uefi"; return; fi
    if command -v grub-install >/dev/null 2>&1; then echo "grub"; return; fi
    echo "unknown"
}
is_container() {
    local virt=$(detect_virtualization)
    case "$virt" in
        openvz|lxc|docker|container-other) return 0 ;;
    esac
    return 1
}

_get_ip() {
    if test -n "${SERVER_IP:-}"; then if test "$SERVER_IP" != "获取失败"; then echo "$SERVER_IP"; return; fi; fi
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
    if [[ ! "$level" =~ ^[1-4]$ ]]; then level=1; fi
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
    
    mkdir -p "$BASE_DIR" "$LOG_DIR" "$BACKUP_DIR" "$RUNTIME_DIR" "$LOCK_DIR" "$TMP_DIR" "$CONFIG_DIR" "$DAT_DIR" "$SCRIPT_DIR" "$FLAGS_DIR" 2>/dev/null || true
    touch "$USER_SNI_MAP" "$USER_TIME_MAP" 2>/dev/null || true
    
    acquire_lock
    local virt=$(detect_virtualization)
    local boot=$(detect_bootloader)
    log_info "预检启动 - 虚拟化: $virt | Bootloader: $boot"

    local need="jq curl wget xxd unzip qrencode vnstat cron openssl ca-certificates gnupg python3 build-essential git htop tar xz-utils bc ethtool iproute2 socat"
    local missing=""
    for p in $need; do
        if ! command -v "$p" >/dev/null 2>&1; then missing="$missing $p"; fi
    done
    
    if test -n "$missing"; then
        info "正在同步工业级依赖框架: $missing"
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

#==============================================================================
# 5. e28 引入的高级网络与硬件自适应调优
#==============================================================================
get_default_iface() { ip route | awk '/default/ {print $5}' | head -n1; }
get_total_mem_mb() { free -m | awk '/Mem/ {print $2}'; }

check_and_create_swap() {
    title "检查并配置防爆 Swap 缓冲池"
    local SWAP_FILE="/swapfile"
    local mem=$(get_total_mem_mb)
    local target_swap_mb=1050
    if (( mem <= 1024 )); then target_swap_mb=2048; fi

    if swapon --show | grep -q "^$SWAP_FILE"; then
        local CURRENT_SWAP_MB=$(swapon --show --bytes | awk -v f="$SWAP_FILE" '$1==f {print int($3/1024/1024)}')
        if [ "$CURRENT_SWAP_MB" -ge "$target_swap_mb" ]; then
            info "检测到已有 ${CURRENT_SWAP_MB}MB Swap，无需重复创建。"
            return
        else
            warn "检测到 Swap 大小不足，准备重建..."
            swapoff "$SWAP_FILE" 2>/dev/null || true
            rm -f "$SWAP_FILE" 2>/dev/null || true
        fi
    fi

    sed -i '\|^/swapfile |d' /etc/fstab 2>/dev/null || true
    info "开始创建 ${target_swap_mb}MB 物理 Swap..."

    if ! fallocate -l ${target_swap_mb}M "$SWAP_FILE" 2>/dev/null; then
        dd if=/dev/zero of="$SWAP_FILE" bs=1M count=${target_swap_mb} status=progress 2>/dev/null || true
    fi

    chmod 600 "$SWAP_FILE" || true
    if ! mkswap "$SWAP_FILE" >/dev/null 2>&1; then warn "mkswap 失败。"; rm -f "$SWAP_FILE" 2>/dev/null || true; return; fi
    if ! swapon "$SWAP_FILE" >/dev/null 2>&1; then warn "swapon 失败。"; rm -f "$SWAP_FILE" 2>/dev/null || true; return; fi
    if ! grep -q "^/swapfile " /etc/fstab 2>/dev/null; then echo "/swapfile none swap sw,nofail 0 0" >> /etc/fstab; fi
    sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
    info "Swap 防爆缓冲池配置完成。"
}

configure_oom_protection() {
    sysctl -w vm.min_free_kbytes=262144 >/dev/null 2>&1 || true
    sysctl -w vm.watermark_scale_factor=200 >/dev/null 2>&1 || true
    mkdir -p /etc/systemd/system.conf.d 2>/dev/null || true
    cat > /etc/systemd/system.conf.d/oom.conf <<EOF
[Manager]
DefaultMemoryAccounting=yes
DefaultTasksAccounting=yes
EOF
    systemctl daemon-reexec >/dev/null 2>&1 || true
}

adaptive_nic_tuning() {
    local iface=$(get_default_iface)
    [[ -z "$iface" ]] && return
    local cpu=$(nproc 2>/dev/null || echo 1)
    local mem=$(get_total_mem_mb)
    info "自适应 NIC 队列与硬件卸载引擎分析中..."

    if (( cpu <= 2 )); then
        ethtool -K "$iface" gro off tso off gso off 2>/dev/null || true
    else
        ethtool -K "$iface" gro on tso on gso on 2>/dev/null || true
    fi

    if (( mem >= 4096 )); then
        sysctl -w net.core.netdev_max_backlog=250000 >/dev/null 2>&1 || true
    else
        sysctl -w net.core.netdev_max_backlog=65536 >/dev/null 2>&1 || true
    fi
}

configure_rps() {
    local iface=$(get_default_iface)
    [[ -z "$iface" ]] && return
    local cores=$(nproc 2>/dev/null || echo 1)
    local mask=$(python3 -c "print(hex((1<<$cores)-1)[2:])" 2>/dev/null || echo "1")
    info "正在挂载网卡 RPS/RFS 软中断核心派发锁..."

    for q in /sys/class/net/$iface/queues/rx-*; do
        [[ ! -d "$q" ]] && continue
        echo "$mask" > "$q/rps_cpus" 2>/dev/null || true
    done

    local mem=$(get_total_mem_mb)
    if (( mem <= 1024 )); then
        sysctl -w net.core.rps_sock_flow_entries=8192 >/dev/null 2>&1 || true
    elif (( mem <= 4096 )); then
        sysctl -w net.core.rps_sock_flow_entries=32768 >/dev/null 2>&1 || true
    else
        sysctl -w net.core.rps_sock_flow_entries=65536 >/dev/null 2>&1 || true
    fi
}

install_kernel_watchdog() {
    info "注入 Kernel Watchdog 内核防爆变砖重置守护线程..."
    mkdir -p /usr/local/ex198e29/watchdog
cat > /usr/local/ex198e29/watchdog/kernel-watchdog.sh <<'EOF'
#!/usr/bin/env bash
BOOT_OK_FILE="/boot/.kernel_boot_ok"
ROLLBACK_KERNEL_FILE="/boot/.rollback_kernel"
sleep 300
if [[ ! -f "$BOOT_OK_FILE" ]]; then
    if [[ -f "$ROLLBACK_KERNEL_FILE" ]]; then
        PREV_KERNEL=$(cat "$ROLLBACK_KERNEL_FILE")
        if command -v grub-set-default >/dev/null 2>&1; then
            grub-set-default "$PREV_KERNEL"
            update-grub || true
            reboot
        fi
    fi
fi
EOF
    chmod +x /usr/local/ex198e29/watchdog/kernel-watchdog.sh
cat > /etc/systemd/system/kernel-watchdog.service <<EOF
[Unit]
Description=Kernel Watchdog
[Service]
Type=simple
ExecStart=/usr/local/ex198e29/watchdog/kernel-watchdog.sh
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable kernel-watchdog >/dev/null 2>&1 || true
}

mark_kernel_boot_success() { touch /boot/.kernel_boot_ok 2>/dev/null || true; }

#==============================================================================
# 6. Xray 系统控制、文件权限与防截断 JQ 处理
#==============================================================================
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
mkdir -p /var/log/xray 2>/dev/null || true
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

#==============================================================================
# 7. 内核编译与 GRUB 强控中心 (Apex Kernel Vanguard)
#==============================================================================
check_and_clean_space() {
    info "执行严格的空间释放与清理协议..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get clean >/dev/null 2>&1 || true
    apt-get autoremove -y --purge >/dev/null 2>&1 || true
    journalctl --vacuum-time=1d >/dev/null 2>&1 || true
    rm -rf /var/log/*.log /var/log/*/*.log /tmp/* /var/lib/docker/* /usr/src/linux* /usr/src/bbr* /usr/src/xanmod* /compile/* /root/linux* /root/*.tar* /root/*.gz /root/*.xz /var/cache/apt/archives/* 2>/dev/null || true
    sync
}

finalize() {
    info "执行最终收尾清理与固化序列..."
    sync && echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    info "所有底层进程节点流转完毕，Apex Vanguard 环境已彻底就绪。"
}

do_install_xanmod_main_official() {
    title "系统飞升：安装官方预编译 XANMOD 内核 (APT 双轨融合版)"
    if [[ "$(uname -m)" != "x86_64" ]]; then 
        error "官方源安装当前仅支持 x86_64 架构！"
        local _p=""; read -rp "按 Enter 返回..." _p || true; return 1
    fi
    export DEBIAN_FRONTEND=noninteractive
    warn "正在同步核心依赖..."
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y curl wget gnupg ca-certificates lsb-release >/dev/null 2>&1 || true

    warn "执行全域 CPU 指令集等级检测..."
    local cpu_level=$(detect_x86_64_level)
    info "架构锁定: x86-64-v${cpu_level}"

    warn "正在配置现代化 APT 溯源仓库 (Keyrings 模式)..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL --connect-timeout 10 https://dl.xanmod.org/gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/xanmod.gpg 2>/dev/null || true
    echo "deb [signed-by=/etc/apt/keyrings/xanmod.gpg] http://deb.xanmod.org releases main" > /etc/apt/sources.list.d/xanmod-kernel.list
    apt-get update -y >/dev/null 2>&1 || true

    local installed=0
    info "开始遍历寻找最优预编译包..."
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
        local _p=""; read -rp "按 Enter 返回主菜单..." _p || true; return 1
    fi

    info "执行 GRUB 霸权接管 (破解云镜像强锁)..."
    sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/g' /etc/default/grub 2>/dev/null || true
    sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/g' /etc/default/grub.d/*.cfg 2>/dev/null || true
    if command -v grub-set-default >/dev/null 2>&1; then grub-set-default 0 >/dev/null 2>&1 || true; fi
    if command -v update-grub >/dev/null 2>&1; then
        update-grub >/dev/null 2>&1 || true
    else
        apt-get install -y grub2-common >/dev/null 2>&1 || true
        update-grub >/dev/null 2>&1 || true
    fi

    install_kernel_watchdog
    warn "Xanmod 内核安装并强制指定默认引导完毕，系统将在 10 秒后强制重启..."
    sleep 10
    reboot
}

_fetch_xanmod_tags() {
    info "正在连接 GitLab API 实时检索最新 Xanmod 内核分支库..."
    local api_url="https://gitlab.com/api/v4/projects/xanmod%2Flinux/repository/tags?per_page=100"
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
        mapfile -t TAG_LIST < <(echo "$tags_json" | jq -r '.[].name' | grep -vE "rc|beta" | grep -E "^[6-9]\.[0-9]+\.[0-9]+(-rt)?-xanmod[0-9]+$" | sort -V -r | head -n 15)
        if [[ ! " ${TAG_LIST[*]} " =~ " ${default_tag} " ]]; then
            TAG_LIST=("$default_tag" "${TAG_LIST[@]}")
        fi
    fi
    
    echo -e "\n${cyan}【检索到的最新 Xanmod 内核分支 (工业倒序排位)】${none}"
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
    check_and_clean_space
    local inode_use=$(df -i / 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%' || echo "0")
    if test "$inode_use" -gt 90 2>/dev/null; then apt-get clean >/dev/null 2>&1 || true; rm -rf /var/cache/* 2>/dev/null || true; fi

    local root_free=$(df -m / 2>/dev/null | awk 'NR==2{print $4}' || echo "0")
    BUILD_DIR=""
    if test "$root_free" -gt 4000 2>/dev/null; then 
        mkdir -p /compile 2>/dev/null || true; BUILD_DIR="/compile"
    else 
        BUILD_DIR="/usr/src"
    fi

    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if ! cd "$BUILD_DIR"; then die "权限异常：系统拒绝切入工作区 $BUILD_DIR。"; fi
}

_execute_compilation() {
    local extra_make_args="${1:-}"
    local make_flags="${2:-}"
    local mem_mb=$(free -m 2>/dev/null | awk '/Mem/{print $2}' | head -n 1 || echo "1024")
    local swp_mb=$(free -m 2>/dev/null | awk '/Swap/{print $2}' | head -n 1 || echo "0")
    local total_mb=$((mem_mb + swp_mb))
    local CPU_CORES=$(nproc 2>/dev/null || echo 1)
    
    local safe_threads=$((total_mb / 1500))
    if test "$safe_threads" -lt 1 2>/dev/null; then safe_threads=1; fi
    if test "$safe_threads" -gt "$CPU_CORES" 2>/dev/null; then safe_threads=$CPU_CORES; fi
    THREADS=$safe_threads
    
    info "=== 已分配多核编译火力: $THREADS 线程 (系统总可用池 ${total_mb}MB) ==="
    local cmd="make -j$THREADS"
    
    if test -n "$make_flags"; then
        info ">>> 强制执行底层编译注入指令: $make_flags"
        if gcc -E - -fcf-protection=none </dev/null >/dev/null 2>&1; then make_flags="$make_flags -fcf-protection=none"; fi
        if ! eval "$cmd KCFLAGS=\"$make_flags\" $extra_make_args"; then
            error "编译崩塌！请检查 Swap 是否被云商系统屏蔽。"
            local _p=""; read -rp "按 Enter 返回..." _p || true; return 1
        fi
    else
        if ! $cmd $extra_make_args; then
            error "编译崩塌！请检查 Swap 是否被云商系统屏蔽。"
            local _p=""; read -rp "按 Enter 返回..." _p || true; return 1
        fi
    fi

    info "编译成功！正在部署内核与构建模块..."
    make modules_install >/dev/null 2>&1 || true
    make install >/dev/null 2>&1 || true

    local COMPILED_VER=$(make kernelversion 2>/dev/null || echo "")
    if test -n "$COMPILED_VER"; then 
        info "内核 ($COMPILED_VER) 已注入宿主机核心。"
        if command -v update-initramfs >/dev/null 2>&1; then
            update-initramfs -c -k "$COMPILED_VER" >/dev/null 2>&1 || true
        elif command -v dracut >/dev/null 2>&1; then
            dracut --force "/boot/initramfs-${COMPILED_VER}.img" "$COMPILED_VER" >/dev/null 2>&1 || true
        fi
    fi

    info "执行 GRUB 霸权强制接管..."
    sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/g' /etc/default/grub 2>/dev/null || true
    sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/g' /etc/default/grub.d/*.cfg 2>/dev/null || true
    if command -v grub-set-default >/dev/null 2>&1; then grub-set-default 0 >/dev/null 2>&1 || true; fi
    update-grub >/dev/null 2>&1 || true

    cd /
    rm -rf "$BUILD_DIR/"* "$BUILD_DIR/$KERNEL_FILE" /compile/* /root/linux* /root/*.tar* 2>/dev/null || true
    finalize
    install_kernel_watchdog
    info "内核编译与结构优化已全部就绪！系统将在 30 秒后强制重启..."
    sleep 30
    reboot
}

_compile_kernel_mainline() {
    local bbr_type="${1:-bbr}"
    local title_suffix="BBR"
    if [ "$bbr_type" = "bbr3" ]; then title_suffix="BBR3"; fi
    
    title "系统飞升：极客编译 Linux 官方主线最新内核 (源码版 + $title_suffix)"
    local confirm=""; read -rp "确定要开始编译吗？(y/n): " confirm || true
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then return; fi
    
    local cpu_level=$(detect_x86_64_level)
    info "全局探针完成，CPU 等级锁定: x86-64-v${cpu_level}"
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y build-essential bc flex bison libssl-dev libelf-dev libncurses-dev dwarves git curl wget lz4 liblz4-tool gcc-multilib libc6-dev-i386 zstd rsync >/dev/null 2>&1 || true

    _prepare_compile_env

    info "=== 动态连接 Kernel.org 溯源官方最新主线源码 ==="
    set +e
    local KERNEL_URL=$(curl -s https://www.kernel.org/releases.json | jq -r '.releases[] | select(.id != null and .moniker=="mainline") | .source' | head -n 1)
    if test -z "$KERNEL_URL" || test "$KERNEL_URL" = "null"; then
        KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.tar.xz"
    fi
    set -e
    
    local KERNEL_FILE=$(basename "$KERNEL_URL")
    wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"

    set +o pipefail
    if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
        rm -f "$KERNEL_FILE" 2>/dev/null || true
        wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"
        if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then error "源码包损坏。"; set -e; return 1; fi
    fi
    set -o pipefail

    tar -xJf "$KERNEL_FILE"
    local KERNEL_DIR=$(tar -tf "$KERNEL_FILE" | head -1 | cut -d/ -f1)
    if ! cd "$KERNEL_DIR"; then die "解压后目录切入失败。"; fi

    info "=== 生成并清洗内核配置 (纯净主线 + 极速补齐) ==="
    if test -f "/boot/config-$(uname -r)"; then
        cp "/boot/config-$(uname -r)" .config; make olddefconfig >/dev/null 2>&1 || true
    elif test -f "/proc/config.gz"; then
        zcat /proc/config.gz > .config; make olddefconfig >/dev/null 2>&1 || true
    else
        make defconfig >/dev/null 2>&1 || true
    fi

    ./scripts/config --enable CONFIG_VIRTIO --enable CONFIG_VIRTIO_PCI --enable CONFIG_VIRTIO_NET --enable CONFIG_VIRTIO_BLK --enable CONFIG_VIRTIO_CONSOLE --enable CONFIG_EXT4_FS --enable CONFIG_NVME_CORE --enable CONFIG_BLK_DEV_NVME
    ./scripts/config --enable CONFIG_NET_SCH_CAKE --enable CONFIG_NET_SCH_FQ --enable CONFIG_NET_SCH_FQ_CODEL
    sed -i 's/CONFIG_SYSTEM_TRUSTED_KEYS=.*/CONFIG_SYSTEM_TRUSTED_KEYS=""/g' .config 2>/dev/null || true
    sed -i 's/CONFIG_SYSTEM_REVOCATION_KEYS=.*/CONFIG_SYSTEM_REVOCATION_KEYS=""/g' .config 2>/dev/null || true
    sed -i 's/CONFIG_MODULE_SIG_KEY=.*/CONFIG_MODULE_SIG_KEY=""/g' .config 2>/dev/null || true
    ./scripts/config --disable CONFIG_DEBUG_INFO --disable CONFIG_DEBUG_INFO_BTF --disable CONFIG_MODULE_SIG
    ./scripts/config --disable CONFIG_X86_X32 --disable CONFIG_IA32_EMULATION --disable CONFIG_COMPAT
    ./scripts/config --disable CONFIG_CC_HAS_IBT --disable CONFIG_X86_KERNEL_IBT

    local final_march=$(_get_safe_march "$cpu_level")
    ./scripts/config --set-str CONFIG_MARCH "$final_march" 2>/dev/null || true

    if [ "$bbr_type" = "bbr3" ]; then
        if curl -fsSL --connect-timeout 10 https://raw.githubusercontent.com/google/bbr/main/patches/bbr3.patch -o bbr3.patch; then
            patch -p1 < bbr3.patch >/dev/null 2>&1 || true
        fi
        ./scripts/config --enable CONFIG_TCP_CONG_BBR --enable CONFIG_DEFAULT_BBR --enable CONFIG_TCP_BBR3 2>/dev/null || true
    else
        ./scripts/config --enable CONFIG_TCP_CONG_BBR --enable CONFIG_DEFAULT_BBR 2>/dev/null || true
    fi
    make olddefconfig >/dev/null 2>&1 || true
    _execute_compilation "" "-march=$final_march"
}

_compile_kernel_xanmod() {
    title "系统飞升：极客源码编译 真·Xanmod 内核 (全自动防爆防卡死版)"
    local confirm=""; read -rp "确定要开始极客源码编译吗？(y/n): " confirm || true
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then return; fi
    
    local cpu_level=$(detect_x86_64_level)
    info "全局探针完成，CPU 等级锁定: x86-64-v${cpu_level}"

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y build-essential bc flex bison libssl-dev libelf-dev libncurses-dev dwarves git curl wget lz4 liblz4-tool gcc-multilib libc6-dev-i386 zstd rsync >/dev/null 2>&1 || true
    
    _fetch_xanmod_tags
    _prepare_compile_env

    local KERNEL_URL="https://gitlab.com/xanmod/linux/-/archive/${LATEST_TAG}/linux-${LATEST_TAG}.tar.gz"
    local KERNEL_FILE="${LATEST_TAG}.tar.gz"
    wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"

    set +o pipefail
    if ! tar -tzf "$KERNEL_FILE" >/dev/null 2>&1; then
        rm -f "$KERNEL_FILE" 2>/dev/null || true
        set +e
        LATEST_TAG=$(curl -sL --connect-timeout 10 https://gitlab.com/api/v4/projects/xanmod%2Flinux/repository/tags?per_page=100 | jq -r '.[].name' 2>/dev/null | grep -vE "rc|beta" | grep -E "^[6-9]\.[0-9]+\.[0-9]+(-rt)?-xanmod[0-9]+$" | sort -V -r | head -n 1 || echo "6.18.25-rt-xanmod1")
        set -e
        KERNEL_URL="https://gitlab.com/xanmod/linux/-/archive/${LATEST_TAG}/linux-${LATEST_TAG}.tar.gz"
        KERNEL_FILE="${LATEST_TAG}.tar.gz"
        wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"
        if ! tar -tzf "$KERNEL_FILE" >/dev/null 2>&1; then error "源码包彻底损坏。"; set -e; return 1; fi
    fi
    set -o pipefail

    tar -xzf "$KERNEL_FILE"
    local KERNEL_DIR=$(tar -tf "$KERNEL_FILE" | head -1 | cut -d/ -f1)
    if ! cd "$KERNEL_DIR"; then die "解压后目录切入失败。"; fi

    if test -f "/boot/config-$(uname -r)"; then
        cp "/boot/config-$(uname -r)" .config; make olddefconfig >/dev/null 2>&1 || true
    elif test -f "/proc/config.gz"; then
        zcat /proc/config.gz > .config; make olddefconfig >/dev/null 2>&1 || true
    else
        make defconfig >/dev/null 2>&1 || true
    fi

    ./scripts/config --enable CONFIG_VIRTIO --enable CONFIG_VIRTIO_PCI --enable CONFIG_VIRTIO_NET --enable CONFIG_VIRTIO_BLK --enable CONFIG_VIRTIO_CONSOLE --enable CONFIG_EXT4_FS --enable CONFIG_NVME_CORE --enable CONFIG_BLK_DEV_NVME
    ./scripts/config --enable CONFIG_NET_SCH_CAKE --enable CONFIG_NET_SCH_FQ --enable CONFIG_NET_SCH_FQ_CODEL
    sed -i 's/CONFIG_SYSTEM_TRUSTED_KEYS=.*/CONFIG_SYSTEM_TRUSTED_KEYS=""/g' .config 2>/dev/null || true
    sed -i 's/CONFIG_SYSTEM_REVOCATION_KEYS=.*/CONFIG_SYSTEM_REVOCATION_KEYS=""/g' .config 2>/dev/null || true
    sed -i 's/CONFIG_MODULE_SIG_KEY=.*/CONFIG_MODULE_SIG_KEY=""/g' .config 2>/dev/null || true
    ./scripts/config --disable CONFIG_DEBUG_INFO --disable CONFIG_DEBUG_INFO_BTF --disable CONFIG_MODULE_SIG
    ./scripts/config --disable CONFIG_X86_X32 --disable CONFIG_IA32_EMULATION --disable CONFIG_COMPAT
    ./scripts/config --disable CONFIG_CC_HAS_IBT --disable CONFIG_X86_KERNEL_IBT

    local final_march=$(_get_safe_march "$cpu_level")
    ./scripts/config --set-str CONFIG_MARCH "$final_march" 2>/dev/null || true
    ./scripts/config --enable CONFIG_TCP_CONG_BBR --enable CONFIG_DEFAULT_BBR --enable CONFIG_TCP_BBR3 2>/dev/null || true
    make olddefconfig >/dev/null 2>&1 || true

    sed -i -E 's/-march=x86-64-v\$\([^)]+\)//g' arch/x86/Makefile 2>/dev/null || true
    sed -i -E 's/-march=x86-64-v\$\{[^}]+\}//g' arch/x86/Makefile 2>/dev/null || true
    _execute_compilation "" "-march=$final_march"
}

do_kernel_compile_menu() {
    while true; do
        clear
        title "极客内核源码锻造中心 (多核极速·全自动防变砖版)"
        echo "  1) [官方推荐] APT 安装 Xanmod 预编译稳定内核 (含 BBR3)"
        echo "  2) [极客源码] 手工编译 真·Xanmod 极客内核 (支持指定 Tag + BBR3)"
        echo "  3) [极客源码] 手工编译 Linux 官方主线内核 (Mainline + BBR3)"
        echo "  0) 返回上级菜单"
        hr
        local k_opt=""; read -rp "请下达锻造路径指令 (0-3): " k_opt || true
        case "${k_opt:-}" in
            1) do_install_xanmod_main_official; return ;;
            2) _compile_kernel_xanmod; return ;;
            3) _compile_kernel_mainline "bbr3"; return ;;
            0) return ;;
        esac
    done
}

#==============================================================================
# 8. SNI 测速与特征重定向分析
#==============================================================================
run_sni_scanner() {
    title "雷达嗅探：130+ 实体矩阵与国内连通性探测"
    print_yellow ">>> 扫描进行中... (随时按回车键可立即中止)\n"
    local sni_list=(
        "www.apple.com" "support.apple.com" "developer.apple.com" "id.apple.com" "icloud.apple.com"
        "www.microsoft.com" "login.microsoftonline.com" "portal.azure.com" "support.microsoft.com" "office.com"
        "www.intel.com" "downloadcenter.intel.com" "ark.intel.com" "www.amd.com" "drivers.amd.com" "community.amd.com"
        "www.dell.com" "support.dell.com" "www.hp.com" "support.hp.com" "developers.hp.com"
        "www.bmw.com" "configure.bmw.com" "shop.bmw.com" "www.mercedes-benz.com" "me.mercedes-benz.com"
        "www.toyota-global.com" "global.toyota" "www.toyota.com" "www.honda.com" "global.honda" "www.volkswagen.com"
        "www.nike.com" "account.nike.com" "store.nike.com" "www.adidas.com"
        "www.zara.com" "static.zara.net" "www.ikea.com" "secure.ikea.com" "www.shell.com"
        "www.sony.com" "www.sony.net" "www.panasonic.com" "www.canon.com" "www.nintendo.com" "www.lg.com"
        "www.coca-cola.com" "www.coca-colacompany.com" "www.pepsi.com" "www.pepsico.com" "www.nestle.com"
        "www.tesla.com" "s0.awsstatic.com" "d1.awsstatic.com" "images-na.ssl-images-amazon.com" "m.media-amazon.com"
        "www.nvidia.com" "academy.nvidia.com" "images.nvidia.com" "blogs.nvidia.com" "docs.nvidia.com"
        "www.samsung.com" "www.sap.com" "www.oracle.com" "www.mysql.com" "www.swift.com" "download-installer.cdn.mozilla.net"
        "www.zoom.us" "www.adobe.com" "www.autodesk.com" "www.salesforce.com" "www.cisco.com" "www.ibm.com" "www.qualcomm.com"
        "www.tiktok.com" "www.netflix.com" "www.hulu.com" "www.disneyplus.com"
    )
    local sni_string=$(printf "%s\n" "${sni_list[@]}")
    if command -v shuf >/dev/null 2>&1; then sni_string=$(echo "$sni_string" | shuf); else sni_string=$(echo "$sni_string" | awk 'BEGIN{srand()} {print rand()"\t"$0}' | sort -n | cut -f2-); fi
    local tmp_sni=$(mktemp /tmp/sni_test.XXXXXX) || true

    for sni in $sni_string; do
        local key=""
        if read -t 0.1 -n 1 -s key 2>/dev/null; then echo -e "\n${yellow}探测已手动中止...${none}"; break; fi
        set +e
        local time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni" 2>/dev/null || echo "0")
        local ms=$(echo "$time_raw" | awk '{print int($1 * 1000)}' 2>/dev/null || echo "0")
        
        if test "${ms:-0}" -gt 0 2>/dev/null; then
            if curl -sI -m 2 --connect-timeout 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray"; then continue; fi
            local doh_res=$(curl -s --connect-timeout 2 "https://dns.alidns.com/resolve?name=$sni&type=1" 2>/dev/null || echo "")
            local dns_cn=$(echo "$doh_res" | jq -r '.Answer[]? | select(.type==1 or .type==5) | .data' 2>/dev/null | tail -n 1 || echo "")
            local p_type="NORM"
            if test -z "$dns_cn" || test "$dns_cn" = "127.0.0.1" || test "$dns_cn" = "0.0.0.0" || test "$dns_cn" = "::1" || test "$dns_cn" = "null"; then
                p_type="BLOCK"
            else
                local loc=$(curl -s --connect-timeout 2 "https://ipinfo.io/$dns_cn/country" 2>/dev/null | tr -d ' \n' || echo "")
                if test "$loc" = "CN"; then p_type="CN_CDN"; else p_type="NORM"; fi
            fi
            if test "$p_type" != "BLOCK"; then echo "$ms $sni $p_type" >> "$tmp_sni"; fi
            echo -e " ${green}存活${none} $sni : ${yellow}${ms}ms${none} | 类型: $p_type"
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
        echo "www.microsoft.com 999 NORM" > "$SNI_CACHE_FILE"
    fi
    rm -f "$tmp_sni" 2>/dev/null || true
}

verify_sni_strict() {
    local target="$1"
    print_magenta "\n>>> 正在针对目标 SNI [$target] 开启高维质检..."
    set +e
    local out=$(echo "Q" | timeout 5 openssl s_client -connect "$target:443" -alpn h2 -tls1_3 -status 2>&1 || echo "")
    set -e
    local pass=1
    if ! echo "$out" | grep -qi "TLSv1.3"; then print_red " ✗ 未启用 TLS v1.3"; pass=0; fi
    if ! echo "$out" | grep -qiE "ALPN, server accepted to use h2|ALPN.*h2"; then print_red " ✗ 不支持 ALPN h2"; pass=0; fi
    if ! echo "$out" | grep -qi "OCSP response:"; then print_red " ✗ 未配置 OCSP"; pass=0; fi
    if test "$pass" -eq 0; then warn "域名指纹不全！"; return 1; else info "质检通过。"; return 0; fi
}

choose_sni() {
    while true; do
        if test -f "$SNI_CACHE_FILE"; then
            echo -e "\n  ${cyan}【本地连通性测速结果】${none}"
            local idx=1
            while read -r s t p; do echo -e "  $idx) $s (${cyan}${t}ms${none})"; idx=$((idx + 1)); done < "$SNI_CACHE_FILE"
            echo -e "  ${yellow}r) 重新运行扫描${none} | m) 多选模式 | 0) 手动输入 | q) 退出"
            local sel=""; read -rp "  请输入对应的编号 (默认 1): " sel || true; sel=${sel:-1}
            
            if test "$sel" = "q" || test "$sel" = "Q"; then return 1; fi
            if test "$sel" = "r" || test "$sel" = "R"; then run_sni_scanner; continue; fi
            if test "$sel" = "m" || test "$sel" = "M"; then
                local m_sel=""; read -rp "请输入所需序号 (空格分隔, 如 1 3 5，或 all): " m_sel || true
                local arr=()
                if test "$m_sel" = "all"; then
                    while read -r p_sni p_rest; do if test -n "$p_sni"; then arr+=("$p_sni"); fi; done < "$SNI_CACHE_FILE"
                else
                    for i in $m_sel; do local picked=$(awk "NR==$i {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo ""); if test -n "$picked"; then arr+=("$picked"); fi; done
                fi
                if test "${#arr[@]}" -eq 0; then continue; fi
                BEST_SNI="${arr[0]}"
                local jq_args=()
                for s in "${arr[@]}"; do jq_args+=("\"$s\""); done
                SNI_JSON_ARRAY=$(IFS=,; echo "${jq_args[*]}")
            else
                if test "$sel" = "0"; then 
                    local d=""; read -rp "输入自定义 SNI: " d || true; BEST_SNI=${d:-www.microsoft.com}; SNI_JSON_ARRAY="\"$BEST_SNI\""
                else
                    local picked=""; if [[ "$sel" =~ ^[0-9]+$ ]]; then picked=$(awk "NR==$sel {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo ""); fi
                    if test -n "$picked"; then BEST_SNI="$picked"; else BEST_SNI=$(awk "NR==1 {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "www.microsoft.com"); fi
                    SNI_JSON_ARRAY="\"$BEST_SNI\""
                fi
            fi

            if verify_sni_strict "$BEST_SNI"; then break; else
                local force_use=""; read -rp "是否无视警告，强制绑定？(y/n): " force_use || true
                if [[ "$force_use" =~ ^[yY]$ ]]; then warn "授权强制挂载。"; break; else continue; fi
            fi
        else
            run_sni_scanner
        fi
    done
    return 0
}

#==============================================================================
# 9. 高阶系统内核性能重塑与极客配置下发
#==============================================================================
configure_dns_safe() {
    if is_container; then warn "容器环境跳过 DNS 重构"; return; fi
    if [[ ! -L /etc/resolv.conf ]]; then if lsattr /etc/resolv.conf 2>/dev/null | grep -q 'i'; then warn "resolv.conf immutable，跳过"; return; fi; fi
    mkdir -p /etc/systemd
    cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=1.1.1.1 208.67.222.222
FallbackDNS=9.9.9.9 1.0.0.1
DNSSEC=no
DNSStubListener=yes
EOF
    systemctl enable systemd-resolved || true
    systemctl restart systemd-resolved || true
    rm -f /etc/resolv.conf || true
    ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
    info "DNS 系统已使用 systemd-resolved 重定向为纯净线路。"
}

do_perf_tuning() {
    title "全域系统底层网络栈结构重塑"
    info "写入最新高并发防抗延迟 Sysctl 协议栈参数..."
    truncate -s 0 /etc/sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-sysctl.conf 2>/dev/null || true
    
    cat > /etc/sysctl.d/99-network-optimized.conf << EOF
fs.file-max = 2097152
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.netdev_max_backlog = 250000
net.core.somaxconn = 65535
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 600
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
vm.swappiness = 10
vm.vfs_cache_pressure = 50
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 262144
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
    sysctl --system >/dev/null 2>&1 || true
    
    mkdir -p /etc/security/limits.d 2>/dev/null || true
    cat > /etc/security/limits.d/99-xray-limits.conf << 'EOF'
* soft nofile 1000000
* hard nofile 1000000
root soft nofile 1000000
root hard nofile 1000000
EOF
    info "底层参数重塑完成。已自动禁用 IPv6 以收敛协议栈泄漏风险。"
}

do_txqueuelen_opt() {
    local IP_CMD=$(command -v ip || echo "")
    if test -z "$IP_CMD"; then return; fi
    local IFACE=$(get_default_iface)
    if test -z "$IFACE"; then return; fi
    $IP_CMD link set "$IFACE" txqueuelen 12000 2>/dev/null || true
    cat > /etc/systemd/system/txqueue.service << EOF
[Unit]
Description=Set TX Queue Length
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
    info "已将出站队列缓冲 txqueuelen 压缩至极致降低延迟。"
}

#==============================================================================
# 10. 全量应用层 28 项状态追踪与一键干预系统
#==============================================================================
check_routeonly_state() { local state=$(jq -r '.inbounds[]? | select(. != null) | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1); if [ "$state" = "true" ]; then echo "true"; else echo "false"; fi; }
check_buffer_state() { local limit_file="/etc/systemd/system/xray.service.d/limits.conf"; if [ -f "$limit_file" ] && grep -q "^Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" "$limit_file" 2>/dev/null; then echo "true"; else echo "false"; fi; }
check_affinity_state() { local limit_file="/etc/systemd/system/xray.service.d/limits.conf"; if [ -f "$limit_file" ] && grep -q "^CPUAffinity=" "$limit_file" 2>/dev/null; then echo "true"; else echo "false"; fi; }
check_dnsmasq_state() { if systemctl is-active dnsmasq >/dev/null 2>&1 && grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null; then echo "true"; else echo "false"; fi; }
check_cake_state() { if sysctl net.core.default_qdisc 2>/dev/null | grep -q 'cake'; then echo "true"; else echo "false"; fi; }

_turn_on_app() {
    _safe_jq_write '
      (.routing) |= (. // {}) |
      (.routing.domainMatcher) = "mph" |
      (.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings) |= (. // {}) |
      (.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings.sockopt) |= (. // {}) |
      (.inbounds[]?  | select(. != null) | select(.protocol=="vless") | .streamSettings) |= (. // {}) |
      (.inbounds[]?  | select(. != null) | select(.protocol=="vless") | .streamSettings.sockopt) |= (. // {}) |
      (.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings.sockopt.tcpNoDelay) = true |
      (.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings.sockopt.tcpFastOpen) = true |
      (.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings.sockopt.tcpKeepAliveIdle) = 30 |
      (.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings.sockopt.tcpKeepAliveInterval) = 15 |
      (.inbounds[]?  | select(. != null) | select(.protocol=="vless") | .streamSettings.sockopt.tcpNoDelay) = true |
      (.inbounds[]?  | select(. != null) | select(.protocol=="vless") | .streamSettings.sockopt.tcpFastOpen) = true |
      (.inbounds[]?  | select(. != null) | select(.protocol=="vless") | .streamSettings.sockopt.reusePort) = true |
      (.inbounds[]?  | select(. != null) | select(.protocol=="vless") | .streamSettings.sockopt.tcpKeepAliveIdle) = 30 |
      (.inbounds[]?  | select(. != null) | select(.protocol=="vless") | .streamSettings.sockopt.tcpKeepAliveInterval) = 15
    '
    _safe_jq_write '(.inbounds[]? | select(. != null) | select(.protocol=="vless") | .sniffing.metadataOnly) = true | (.inbounds[]? | select(. != null) | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly) = true'
    
    local has_reality=$(jq -r '.inbounds[]? | select(. != null) | select(.protocol=="vless" and .streamSettings?.security=="reality") | .protocol' "$CONFIG" 2>/dev/null | head -n 1)
    if [ -n "$has_reality" ] && [ "$has_reality" != "null" ]; then _safe_jq_write '(.inbounds[]? | select(. != null) | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff) = 60000'; fi
    
    _safe_jq_write '.dns = {"servers":["https://1.1.1.1/dns-query"], "queryStrategy":"UseIP"}'
    _safe_jq_write '.policy = {"levels":{"0":{"handshake":3,"connIdle":60}},"system":{"statsInboundDownlink":false,"statsInboundUplink":false}}'
}

do_app_level_tuning_menu() {
    while true; do
        clear; title "应用层及系统内核微操管理中心"
        if ! test -f "$CONFIG"; then error "配置未就绪！"; return; fi
        
        local out_fastopen=$(jq -r '.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpFastOpen // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        local mph_state=$(jq -r 'select(.routing != null) | .routing.domainMatcher // "false"' "$CONFIG" 2>/dev/null)
        
        echo -e "  [当前状态快速诊断]"
        echo -e "  FastOpen: $([ "$out_fastopen" = "true" ] && echo "${cyan}开启${none}" || echo "关闭") | MPH匹配: $([ "$mph_state" = "mph" ] && echo "${cyan}开启${none}" || echo "关闭")"
        echo -e "  CAKE算法: $([ "$(check_cake_state)" = "true" ] && echo "${cyan}开启${none}" || echo "关闭(FQ)") | 内存DNS: $([ "$(check_dnsmasq_state)" = "true" ] && echo "${cyan}开启${none}" || echo "关闭")"
        hr
        echo -e "  ${cyan}1) 一键打通全系应用层微操 (并发连接/缓冲收缩/防重放时间锁/智能路由)${none}"
        echo -e "  ${yellow}2) 启用/关闭 CAKE 极客网卡排队调度器${none}"
        echo "  0) 返回"
        
        local app_opt=""; read -rp "输入指令: " app_opt || true
        case "$app_opt" in
            1) _turn_on_app; systemctl restart xray >/dev/null 2>&1 || true; info "全量应用层压榨启动！"; local _p=""; read -rp "Enter..." _p || true ;;
            2) 
                local conf="/etc/sysctl.d/99-network-optimized.conf"
                if [ "$(check_cake_state)" = "true" ]; then
                    sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = fq/' "$conf" 2>/dev/null || true
                    sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1 || true
                else
                    modprobe sch_cake >/dev/null 2>&1 || true
                    sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = cake/' "$conf" 2>/dev/null || true
                    sysctl -w net.core.default_qdisc=cake >/dev/null 2>&1 || true
                fi
                info "拥塞控制层已变更！"; local _p=""; read -rp "Enter..." _p || true
                ;;
            0) return ;;
        esac
    done
}

#==============================================================================
# 11. Xray 核心架构安装与用户流转中心
#==============================================================================
print_node_block() {
    local protocol="$1" ip="$2" port="$3" sni="$4" pbk="$5" shortid="$6" utls="$7" uuid="$8"
    printf "  ${yellow}%-15s${none} : %s\n" "协议框架" "$protocol"
    printf "  ${yellow}%-15s${none} : %s\n" "外网IP" "$ip"
    printf "  ${yellow}%-15s${none} : %s\n" "端口" "$port"
    printf "  ${yellow}%-15s${none} : %s\n" "用户 UUID" "$uuid"
    printf "  ${yellow}%-15s${none} : %s\n" "伪装SNI" "${sni:-缺失}"
    printf "  ${yellow}%-15s${none} : %s\n" "公钥(pbk)" "${pbk:-缺失}"
    printf "  ${yellow}%-15s${none} : %s\n" "ShortId" "${shortid:-缺失}"
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
                printf "  ${cyan}【VLESS-Reality (Vision) - 授权 %d】${none}\n" $((i+1))
                printf "  ${yellow}%-16s${none} %s\n" "节点代号:" "$remark"
                printf "  ${yellow}%-16s${none} %s\n" "外网 IP:" "$ip"
                printf "  ${yellow}%-16s${none} %s\n" "监听端口:" "$port"
                printf "  ${yellow}%-16s${none} %s\n" "主用 UUID:" "$uuid"
                printf "  ${yellow}%-16s${none} %s\n" "专属伪装 SNI:" "$target_sni"
                local link="vless://${uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${target_sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${remark}"
                echo -e "\n  ${cyan}配置链接:${none} \n  $link\n"
                if command -v qrencode >/dev/null 2>&1; then qrencode -m 2 -t UTF8 "$link"; fi
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
        local b64=$(printf '%s:%s' "$s_method" "$s_pass" | base64 | tr -d '\n\r' || echo "")
        local link_ss="ss://${b64}@${ip}:${s_port}#${REMARK_NAME}-SS"
        echo -e "\n  ${cyan}导入链接:${none} \n  $link_ss\n"
    fi
}

do_user_manager() {
    while true; do
        title "控制面: 账户生命周期管理"
        if test ! -f "$CONFIG"; then error "核心环境未就绪。"; return; fi
        local clients=$(jq -r '.inbounds[]? | select(. != null) | select(.protocol=="vless") | .settings?.clients[]? | .id + "|" + (.email // "未命名")' "$CONFIG" 2>/dev/null || echo "")
        if test -z "$clients" || test "$clients" = "null"; then error "未配置 VLESS。"; local _p=""; read -rp "Enter..." _p || true; return; fi
        
        local tmp_users="/tmp/xray_users_$$.txt"
        echo "$clients" | awk -F'|' '{print NR"|"$1"|"$2}' > "$tmp_users" || true
        
        while IFS='|' read -r num uid remark; do echo -e "  $num) 代号: ${cyan}$remark${none} | ID: ${yellow}$uid${none}"; done < "$tmp_users"
        hr
        echo "  a) 创建新账户 | d) 注销账户 | q) 退出"
        local uopt=""; read -rp "指令: " uopt || true
        local ip=$(_get_ip || echo "获取失败")
        
        if test "$uopt" = "a" || test "$uopt" = "A"; then
            local nu=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
            local ns=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n\r' || echo "")
            local u_remark=""; read -rp "账户备注: " u_remark || true; u_remark=${u_remark:-User-$ns}
            cat > /tmp/new_client.json <<EOF
{ "id": "$nu", "flow": "xtls-rprx-vision", "email": "$u_remark" }
EOF
            _safe_jq_write --argjson new_client "$(< /tmp/new_client.json)" '(.inbounds[]? | select(. != null) | select(.protocol == "vless")) |= (.settings.clients += [$new_client])'
            _safe_jq_write --arg sid "$ns" '(.inbounds[]? | select(. != null) | select(.protocol == "vless")) |= (.streamSettings.realitySettings.shortIds += [$sid])'
            rm -f /tmp/new_client.json 2>/dev/null || true
            ensure_xray_is_alive
            info "创建指令已完成。"
            local _p=""; read -rp "Enter..." _p || true
        elif test "$uopt" = "d" || test "$uopt" = "D"; then
            local dnum=""; read -rp "吊销序号: " dnum || true
            local target_uuid=$(awk -F'|' -v id="${dnum:-0}" '$1==id {print $2}' "$tmp_users" 2>/dev/null || echo "")
            if test -n "$target_uuid"; then
                local idx=$((${dnum:-0} - 1))
                _safe_jq_write --arg uid "$target_uuid" --argjson i "$idx" '(.inbounds[]? | select(. != null) | select(.protocol == "vless")) |= (.settings.clients |= map(select(.id != $uid)) | .streamSettings.realitySettings.shortIds |= del(.[$i]))'
                sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                ensure_xray_is_alive
                info "账户 $target_uuid 已关闭。"
            fi
        elif test "$uopt" = "q" || test "$uopt" = "Q"; then rm -f "$tmp_users" 2>/dev/null || true; break; fi
    done
}

do_install() {
    title "Apex Vanguard: 高维协议建仓与底层核心网组建"
    preflight
    systemctl stop xray >/dev/null 2>&1 || true
    
    echo "  1) VLESS-Reality (极致安全伪装)  2) Shadowsocks  3) 双通道并行部署"
    local proto_choice=""; read -rp "  执行命令编号 (默认 1): " proto_choice || true; proto_choice=${proto_choice:-1}

    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        while true; do local input_p=""; read -rp "VLESS 端口 (默认 443): " input_p || true; input_p=${input_p:-443}; if validate_port "$input_p"; then LISTEN_PORT="$input_p"; break; fi; done
        local input_remark=""; read -rp "VLESS 节点标识 (默认 xp-reality): " input_remark || true; REMARK_NAME=${input_remark:-xp-reality}
        choose_sni; if test $? -ne 0; then return 1; fi
    fi

    local ss_port=8388; local ss_pass=""; local ss_method="aes-256-gcm"
    if test "$proto_choice" = "2" || test "$proto_choice" = "3"; then
        while true; do local input_s=""; read -rp "SS 端口 (默认 8388): " input_s || true; input_s=${input_s:-8388}; if validate_port "$input_s"; then ss_port="$input_s"; break; fi; done
        ss_pass=$(gen_ss_pass); ss_method=$(_select_ss_method)
    fi

    info "拉取最新 Xray 核心..."
    if ! bash -c "$(curl -fsSL --connect-timeout 10 https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" @ install >/dev/null 2>&1; then warn "安装可能中断，请排查。"; fi
    install_update_dat; fix_xray_systemd_limits

    cat > "$CONFIG" <<EOF
{ "log": { "loglevel": "warning" }, "routing": { "domainStrategy": "AsIs", "rules": [ { "outboundTag": "block", "_enabled": true, "protocol": ["bittorrent"] }, { "outboundTag": "block", "_enabled": true, "ip": ["geoip:cn"] }, { "outboundTag": "block", "_enabled": true, "domain": ["geosite:cn", "geosite:category-ads-all"] } ] }, "inbounds": [], "outbounds": [ { "protocol": "freedom", "tag": "direct", "settings": {"domainStrategy": "AsIs"} }, { "protocol": "blackhole", "tag": "block" } ] }
EOF

    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        local keys=$("$XRAY_BIN" x25519 2>/dev/null || echo ""); local priv=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' \r\n' || echo ""); local pub=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' \r\n' || echo "")
        local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid); local sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n\r' || echo "")
        echo "$pub" > "$PUBKEY_FILE"; echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
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
    if ensure_xray_is_alive; then info "配置装载生效！"; do_summary; else error "启动失败。"; return 1; fi
    local _p=""; read -rp "部署完成，按 Enter 返回主菜单..." _p || true
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
    ensure_xray_is_alive; info "防封 SNI 面具漂移重构完毕！"
}

do_uninstall() {
    title "终极清理器：彻底摧毁生态并回卷"
    local confirm=""; read -rp "此操作不可逆！确认摧毁一切？(y/n): " confirm || true
    if test "$confirm" != "y"; then return; fi
    systemctl stop xray >/dev/null 2>&1 || true; systemctl disable xray >/dev/null 2>&1 || true
    rm -rf /etc/systemd/system/xray* /lib/systemd/system/xray* "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" "$BASE_DIR" >/dev/null 2>&1 || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    info "系统已深度格式化归零。"; exit 0
}

do_sys_init_menu() {
    while true; do
        clear; title "环境底层拉齐与增量调优中心"
        echo "  1) [系统防御] DNS 纯净重构与防劫持 (Resolvconf 拦截)"
        echo "  2) [内存防爆] 部署 1050MB 自适应 Swap 及 OOM 守护"
        echo "  3) [极限压榨] 网卡自适应调优与 RPS/RFS 软中断并发挂载"
        echo "  4) [系统飞升] Xanmod 预编译安装与 极客全量内核源码锻造"
        echo "  5) [全局应用] 强行修改 Sysctl + Limits 全局极客参数栈"
        echo "  6) [微操核心] 深入 Xray 协议与系统层 25 项进阶状态调度板"
        echo "  0) 返回主轴"
        hr
        local sys_opt=""; read -rp "输入代号: " sys_opt || true
        case "${sys_opt:-}" in
            1) configure_dns_safe; local _p=""; read -rp "Enter..." _p || true ;;
            2) check_and_create_swap; configure_oom_protection; local _p=""; read -rp "Enter..." _p || true ;;
            3) adaptive_nic_tuning; configure_rps; do_txqueuelen_opt; local _p=""; read -rp "Enter..." _p || true ;;
            4) do_kernel_compile_menu ;;
            5) do_perf_tuning; local _p=""; read -rp "Enter..." _p || true ;;
            6) do_app_level_tuning_menu ;;
            0) return ;;
        esac
    done
}

main_menu() {
    while true; do
        clear
        echo -e "${blue}======================================================================${none}"
        echo -e "  ${magenta}Xray Advanced Core V198e29 - (The Apex Vanguard Fusion)${none}"
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        if test "$svc" = "active"; then svc="${green}平稳在线 (Running)${none}"; else svc="${red}离线静默 (Stopped)${none}"; fi
        echo -e "  状态: $svc | 快捷指令: ${cyan}xrv${none} | IP: ${yellow}$(_get_ip || echo "探测异常")${none}"
        echo -e "${blue}======================================================================${none}"
        echo "  1) 部署底座全加密双轨网关 (VLESS/SS)"
        echo "  2) 用户凭证与 UUID 调度台"
        echo "  3) 节点多维链接下发中心"
        echo "  4) 防火墙数据库强制穿透热重载"
        echo "  5) 强制触发 SNI 测速与特征面具矩阵漂移"
        echo "  6) 高阶底层基建：内核锻造 / 软中断网卡 / 高并发队列极客全控板"
        echo "  0) 退出"
        echo -e "  ${red}88) 自毁并卸载所有部署${none}"
        hr
        local num=""; read -rp "请输入指令: " num || true
        case "${num:-}" in
            1) do_install ;;
            2) do_user_manager ;;
            3) do_summary; local _p=""; read -rp "Enter 退出..." _p || true ;;
            4) bash "$UPDATE_DAT_SCRIPT" >/dev/null 2>&1 || true; ensure_xray_is_alive; info "配置热加载完毕！"; local _p=""; read -rp "Enter..." _p || true ;;
            5) if choose_sni; then _update_matrix; do_summary; local _p=""; read -rp "Enter..." _p || true; fi ;;
            6) do_sys_init_menu ;;
            88) do_uninstall ;;
            0) exit 0 ;;
        esac
    done
}

preflight
main_menu
