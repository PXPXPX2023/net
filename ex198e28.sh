#!/usr/bin/env bash
# ==============================================================================
# ex198e28.sh
# Project Genesis Apex Vanguard V198e28
# 工业级 VPS / Xray / Reality / Xanmod / BBRv3 综合框架
# 基于 ex198e27.sh 完整重构与增量修复
# ==============================================================================

set -Eeuo pipefail
IFS=$' \n\t'

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ==============================================================================
# GLOBAL
# ==============================================================================

readonly SCRIPT_VERSION="198e28"

readonly BASE_DIR="/usr/local/ex198e28"
readonly LOG_DIR="$BASE_DIR/logs"
readonly BACKUP_DIR="$BASE_DIR/backup"
readonly RUNTIME_DIR="$BASE_DIR/runtime"
readonly LOCK_DIR="$BASE_DIR/locks"
readonly FLAGS_DIR="$BASE_DIR/flags"
readonly TMP_DIR="/tmp/ex198e28"

readonly XRAY_DIR="/usr/local/etc/xray"
readonly CONFIG_DIR="$XRAY_DIR/config.d"
readonly MAIN_CONFIG="$XRAY_DIR/config.json"

mkdir -p \
    "$BASE_DIR" \
    "$LOG_DIR" \
    "$BACKUP_DIR" \
    "$RUNTIME_DIR" \
    "$LOCK_DIR" \
    "$FLAGS_DIR" \
    "$TMP_DIR"

# ==============================================================================
# COLOR
# ==============================================================================

readonly red='\033[31m'
readonly green='\033[32m'
readonly yellow='\033[33m'
readonly blue='\033[34m'
readonly magenta='\033[35m'
readonly cyan='\033[36m'
readonly gray='\033[90m'
readonly none='\033[0m'

# ==============================================================================
# UI
# ==============================================================================

info() {
    echo -e "${green}[INFO]${none} $*"
}

warn() {
    echo -e "${yellow}[WARN]${none} $*"
}

error() {
    echo -e "${red}[ERROR]${none} $*"
}

die() {
    echo -e "${red}[FATAL]${none} $*"
    exit 1
}

# ==============================================================================
# LOG
# ==============================================================================

log_info() {
    echo "[$(date '+%F %T')] INFO: $*" >> "$LOG_DIR/main.log"
}

log_warn() {
    echo "[$(date '+%F %T')] WARN: $*" >> "$LOG_DIR/main.log"
}

log_error() {
    echo "[$(date '+%F %T')] ERROR: $*" >> "$LOG_DIR/error.log"
}

# ==============================================================================
# TRAP
# ==============================================================================

panic_handler() {

    local exit_code="$1"
    local line="$2"
    local cmd="$3"

    echo
    error "SYSTEM PANIC"
    echo "EXIT : $exit_code"
    echo "LINE : $line"
    echo "CMD  : $cmd"
    echo

    log_error "PANIC exit=$exit_code line=$line cmd=$cmd"

    cleanup_runtime
}

trap 'panic_handler $? $LINENO "$BASH_COMMAND"' ERR

# ==============================================================================
# SAFE REMOVE
# ==============================================================================

safe_rm_rf() {

    local target="$1"

    case "$target" in
        ""|"/"|"/root"|"/usr"|"/etc"|"/var"|"/bin"|"/sbin")
            error "危险路径已拦截: $target"
            return 1
        ;;
    esac

    [[ ! -e "$target" ]] && return 0

    rm -rf --one-file-system "$target"
}

cleanup_runtime() {
    find "$TMP_DIR" -mindepth 1 -delete 2>/dev/null || true
}

# ==============================================================================
# LOCK
# ==============================================================================

acquire_lock() {

    exec 200>"$LOCK_DIR/main.lock"

    flock -n 200 || die "脚本已经在运行"
}

# ==============================================================================
# ENV DETECTION
# ==============================================================================

detect_virtualization() {
    systemd-detect-virt 2>/dev/null || echo "unknown"
}

is_container() {

    local virt
    virt=$(detect_virtualization)

    case "$virt" in
        openvz|lxc|docker|container-other)
            return 0
        ;;
    esac

    return 1
}

# ==============================================================================
# BOOTLOADER
# ==============================================================================

detect_bootloader() {

    if [[ -d /sys/firmware/efi ]]; then
        echo "uefi"
        return
    fi

    if command -v grub-install >/dev/null 2>&1; then
        echo "grub"
        return
    fi

    echo "unknown"
}

# ==============================================================================
# NETWORK
# ==============================================================================

get_default_iface() {
    ip route | awk '/default/ {print $5}' | head -n1
}

get_total_mem_mb() {
    free -m | awk '/Mem/ {print $2}'
}

# ==============================================================================
# DNS SAFE MODE
# ==============================================================================

configure_dns_safe() {

    if is_container; then
        warn "容器环境跳过 DNS 重构"
        return
    fi

    if [[ ! -L /etc/resolv.conf ]]; then

        if lsattr /etc/resolv.conf 2>/dev/null | grep -q 'i'; then
            warn "resolv.conf immutable，跳过"
            return
        fi
    fi

    mkdir -p /etc/systemd

    cat > /etc/systemd/resolved.conf <<EOF
[Resolve]
DNS=1.1.1.1
FallbackDNS=9.9.9.9
DNSSEC=no
DNSStubListener=yes
EOF

    systemctl enable systemd-resolved || true
    systemctl restart systemd-resolved || true

    rm -f /etc/resolv.conf || true

    ln -sf \
        /run/systemd/resolve/stub-resolv.conf \
        /etc/resolv.conf
}

# ==============================================================================
# SWAP
# ==============================================================================

ensure_swap() {

    if swapon --show | grep -q '/swapfile'; then
        info "swap 已存在"
        return
    fi

    local mem
    mem=$(get_total_mem_mb)

    local swap_mb=2048

    if (( mem <= 1024 )); then
        swap_mb=4096
    fi

    info "创建 ${swap_mb}MB swap"

    fallocate -l ${swap_mb}M /swapfile || \
        dd if=/dev/zero of=/swapfile bs=1M count=$swap_mb

    chmod 600 /swapfile

    mkswap /swapfile
    swapon /swapfile

    grep -q '/swapfile' /etc/fstab || \
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
}

# ==============================================================================
# OOM PROTECTION
# ==============================================================================

configure_oom_protection() {

    sysctl -w vm.min_free_kbytes=262144
    sysctl -w vm.watermark_scale_factor=200

    mkdir -p /etc/systemd/system.conf.d

    cat > /etc/systemd/system.conf.d/oom.conf <<EOF
[Manager]
DefaultMemoryAccounting=yes
DefaultTasksAccounting=yes
EOF
}

# ==============================================================================
# CPU MASK
# ==============================================================================

generate_cpumask() {

    local cores
    cores=$(nproc)

    python3 - <<PY
cores=$cores
mask=(1<<cores)-1
print(hex(mask)[2:])
PY
}

# ==============================================================================
# RPS/RFS
# ==============================================================================

configure_rps() {

    local iface
    iface=$(get_default_iface)

    [[ -z "$iface" ]] && return

    local mask
    mask=$(generate_cpumask)

    info "配置 RPS/RFS"

    for q in /sys/class/net/$iface/queues/rx-*; do

        [[ ! -d "$q" ]] && continue

        echo "$mask" > "$q/rps_cpus" 2>/dev/null || true
    done

    local mem
    mem=$(get_total_mem_mb)

    if (( mem <= 1024 )); then
        sysctl -w net.core.rps_sock_flow_entries=8192
    elif (( mem <= 4096 )); then
        sysctl -w net.core.rps_sock_flow_entries=32768
    else
        sysctl -w net.core.rps_sock_flow_entries=65536
    fi
}

# ==============================================================================
# NIC TUNING
# ==============================================================================

adaptive_nic_tuning() {

    local iface
    iface=$(get_default_iface)

    [[ -z "$iface" ]] && return

    local cpu
    cpu=$(nproc)

    local mem
    mem=$(get_total_mem_mb)

    info "自适应 NIC 调优"

    if (( cpu <= 2 )); then

        ethtool -K "$iface" gro off || true
        ethtool -K "$iface" tso off || true
        ethtool -K "$iface" gso off || true

    else

        ethtool -K "$iface" gro on || true
        ethtool -K "$iface" tso on || true
        ethtool -K "$iface" gso on || true
    fi

    if (( mem >= 4096 )); then
        sysctl -w net.core.netdev_max_backlog=250000
    else
        sysctl -w net.core.netdev_max_backlog=65536
    fi
}

# ==============================================================================
# SYSCTL
# ==============================================================================

apply_sysctl_profile() {

cat > /etc/sysctl.d/99-ex198e28.conf <<EOF
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
EOF

    sysctl --system
}

# ==============================================================================
# XRAY CONFIG.D
# ==============================================================================

ensure_xray_layout() {

    mkdir -p \
        "$CONFIG_DIR/inbounds" \
        "$CONFIG_DIR/outbounds" \
        "$CONFIG_DIR/routing" \
        "$CONFIG_DIR/dns" \
        "$CONFIG_DIR/policies"
}

# ==============================================================================
# JSON SAFE WRITE
# ==============================================================================

safe_json_write() {

    local target="$1"

    local tmp
    tmp=$(mktemp)

    cat > "$tmp"

    jq empty "$tmp" >/dev/null

    mv "$tmp" "$target"
}

# ==============================================================================
# XRAY MERGE
# ==============================================================================

merge_xray_configs() {

    local tmp
    tmp=$(mktemp)

    find "$CONFIG_DIR" -type f -name '*.json' | sort | while read -r f; do
        jq . "$f" >/dev/null || die "JSON错误: $f"
    done

    jq -s '
        reduce .[] as $item (
            {};
            . * $item
        )
    ' \
    $(find "$CONFIG_DIR" -type f -name '*.json' | sort) \
    > "$tmp"

    mv "$tmp" "$MAIN_CONFIG"
}

# ==============================================================================
# XRAY VERIFY
# ==============================================================================

validate_xray_config() {

    if ! command -v xray >/dev/null 2>&1; then
        warn "未安装 xray"
        return
    fi

    xray run -test -config "$MAIN_CONFIG"
}

# ==============================================================================
# BBR VERIFY
# ==============================================================================

verify_bbr3() {

    if sysctl net.ipv4.tcp_available_congestion_control \
        | grep -qi bbr3; then

        info "BBRv3 已启用"

    else

        warn "BBRv3 不存在"
    fi
}

# ==============================================================================
# KERNEL WATCHDOG
# ==============================================================================

install_kernel_watchdog() {

    mkdir -p /usr/local/ex198e28/watchdog

cat > /usr/local/ex198e28/watchdog/kernel-watchdog.sh <<'EOF'
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

    chmod +x /usr/local/ex198e28/watchdog/kernel-watchdog.sh

cat > /etc/systemd/system/kernel-watchdog.service <<EOF
[Unit]
Description=Kernel Watchdog

[Service]
Type=simple
ExecStart=/usr/local/ex198e28/watchdog/kernel-watchdog.sh

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable kernel-watchdog
}

mark_kernel_boot_success() {
    touch /boot/.kernel_boot_ok
}

# ==============================================================================
# SNI SCORE
# ==============================================================================

score_sni() {

    local host="$1"
    local score=0

    local out

    out=$(timeout 5 openssl s_client \
        -connect "$host:443" \
        -tls1_3 \
        -alpn h2 \
        </dev/null 2>/dev/null || true)

    if echo "$out" | grep -qi "TLSv1.3"; then
        ((score+=40))
    fi

    if echo "$out" | grep -qi "h2"; then
        ((score+=30))
    fi

    if echo "$out" | grep -qi "OCSP"; then
        ((score+=10))
    fi

    local t
    t=$(curl -o /dev/null -s -w '%{time_connect}' https://$host || echo 10)

    local ms
    ms=$(awk "BEGIN {print int($t*1000)}")

    if (( ms <= 100 )); then
        ((score+=20))
    elif (( ms <= 300 )); then
        ((score+=10))
    fi

    echo "$score"
}

# ==============================================================================
# COMPILE THREADS
# ==============================================================================

safe_compile_threads() {

    local mem
    mem=$(get_total_mem_mb)

    local cpu
    cpu=$(nproc)

    local threads=$(( mem / 1500 ))

    (( threads < 1 )) && threads=1
    (( threads > cpu )) && threads=$cpu

    echo "$threads"
}

# ==============================================================================
# PRECHECK
# ==============================================================================

preflight() {

    [[ "$EUID" -ne 0 ]] && die "必须使用 root"

    acquire_lock

    local virt
    virt=$(detect_virtualization)

    info "虚拟化环境: $virt"

    local boot
    boot=$(detect_bootloader)

    info "Bootloader: $boot"

    apt-get update -y

    apt-get install -y \
        curl \
        wget \
        jq \
        bc \
        ethtool \
        iproute2 \
        qrencode \
        openssl \
        ca-certificates \
        gnupg \
        python3 \
        build-essential \
        git \
        htop \
        unzip \
        tar \
        xz-utils
}

# ==============================================================================
# MENU
# ==============================================================================

main_menu() {

    while true; do

        echo
        echo "================ ex198e28 ================="
        echo "1. 系统预检"
        echo "2. DNS 安全配置"
        echo "3. 安装 Swap"
        echo "4. OOM 防护"
        echo "5. NIC 自适应优化"
        echo "6. RPS/RFS 动态优化"
        echo "7. 应用 sysctl"
        echo "8. 初始化 Xray config.d"
        echo "9. 合并 Xray 配置"
        echo "10. 验证 Xray 配置"
        echo "11. 安装 Kernel Watchdog"
        echo "12. 验证 BBRv3"
        echo "0. 退出"
        echo "==========================================="
        echo

        read -rp "选择: " opt

        case "$opt" in

            1)
                preflight
            ;;

            2)
                configure_dns_safe
            ;;

            3)
                ensure_swap
            ;;

            4)
                configure_oom_protection
            ;;

            5)
                adaptive_nic_tuning
            ;;

            6)
                configure_rps
            ;;

            7)
                apply_sysctl_profile
            ;;

            8)
                ensure_xray_layout
            ;;

            9)
                merge_xray_configs
            ;;

            10)
                validate_xray_config
            ;;

            11)
                install_kernel_watchdog
            ;;

            12)
                verify_bbr3
            ;;

            0)
                exit 0
            ;;

            *)
                warn "无效选项"
            ;;

        esac

    done
}

# ==============================================================================
# ENTRY
# ==============================================================================

main_menu
