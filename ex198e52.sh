#!/usr/bin/env bash
#==============================================================================
# 脚本名称: ex198e52.sh (The Apex Vanguard - Project Genesis V198e52)
# 快捷方式: xrv
# 【V198e52 净化稳态版：去重覆盖 + 持久化自检 + 安全极速默认】
#==============================================================================
if test -z "${BASH_VERSION:-}"; then echo "Error: 请使用 bash 执行本脚本: bash ex198e52.sh"; exit 1; fi
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

readonly SCRIPT_VERSION="198e52"
readonly XRAY_BIN="/usr/local/bin/xray"
readonly CONFIG_DIR="/usr/local/etc/xray"
readonly CONFIG="$CONFIG_DIR/config.json"
readonly PUBKEY_FILE="$CONFIG_DIR/public.key"
readonly SNI_CACHE_FILE="$CONFIG_DIR/sni_cache.txt"
readonly INSTALL_DATE_FILE="$CONFIG_DIR/install_date.txt"
readonly SCRIPT_VERSION_FILE="$CONFIG_DIR/script_version.txt"
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
SNI_JSON_ARRAY='["www.microsoft.com"]'
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
    info "执行安全空间释放协议（仅清理脚本构建缓存，不破坏系统全局配置）..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get clean >/dev/null 2>&1 || true
    apt-get autoremove -y --purge >/dev/null 2>&1 || true
    journalctl --vacuum-time=2d >/dev/null 2>&1 || true

    # V198e52: 不再 rm -rf /tmp/*、不再删除全部 /var/log/*.log，避免误删 socket/锁文件/审计日志导致服务异常。
    rm -rf \
        /tmp/sni_array.json /tmp/vless_inbound.json /tmp/vless_final.json /tmp/ss_inbound.json \
        /tmp/new_client.json /tmp/xray_users*.txt /tmp/install-release.sh /tmp/sni_test.* \
        /tmp/check_x86-64_psabi.sh /tmp/current_cron /tmp/kernel-arch.cfg /tmp/lsmod.now \
        /usr/src/linux* /usr/src/bbr* /usr/src/xanmod* /compile/* \
        /root/linux* /root/*.tar* /root/*.gz /root/*.xz /var/cache/apt/archives/* \
        2>/dev/null || true
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


_cpu_level_from_lscpu() {
    local flags level
    flags="$(LC_ALL=C lscpu 2>/dev/null | awk -F: '/Flags|Features/{print $2}' | tr ' ' '\n' | sort -u | tr '\n' ' ')"
    if echo "$flags" | grep -qw avx512f && echo "$flags" | grep -qw avx512bw && echo "$flags" | grep -qw avx512vl; then level=4
    elif echo "$flags" | grep -qw avx2 && echo "$flags" | grep -qw bmi2 && echo "$flags" | grep -qw fma; then level=3
    elif echo "$flags" | grep -qw sse4_2 && echo "$flags" | grep -qw popcnt; then level=2
    else level=1; fi
    echo "$level"
}

detect_x86_64_level_remote_optional() {
    local script="/tmp/check_x86-64_psabi.sh" level=""
    if curl -fsSL --connect-timeout 5 https://dl.xanmod.org/check_x86-64_psabi.sh -o "$script" 2>/dev/null; then
        chmod +x "$script" 2>/dev/null || true
        level=$(bash "$script" 2>/dev/null | grep -oE 'x86-64-v[1-4]' | grep -oE '[1-4]' | tail -n1 || true)
        rm -f "$script" 2>/dev/null || true
    fi
    if [[ "$level" =~ ^[1-4]$ ]]; then echo "$level"; else detect_x86_64_level; fi
}

_apply_mss_chain_e52() {
    modprobe iptable_mangle >/dev/null 2>&1 || true
    modprobe xt_TCPMSS >/dev/null 2>&1 || true
    iptables -t mangle -N XRAY_MSS_CLAMP 2>/dev/null || true
    iptables -t mangle -F XRAY_MSS_CLAMP 2>/dev/null || true
    iptables -t mangle -A XRAY_MSS_CLAMP -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
    iptables -t mangle -C POSTROUTING -j XRAY_MSS_CLAMP 2>/dev/null || iptables -t mangle -A POSTROUTING -j XRAY_MSS_CLAMP 2>/dev/null || true
}

_e52_pause() { local _p=""; read -rp "按 Enter 继续..." _p || true; }

detect_x86_64_level() {
    local cache="$CONFIG_DIR/cpu_level.txt" level=""
    if test -s "$cache"; then
        level=$(cat "$cache" 2>/dev/null | tr -cd '1-4' | head -c1 || true)
        if [[ "$level" =~ ^[1-4]$ ]]; then echo "$level"; return 0; fi
    fi
    level=$(_cpu_level_from_lscpu)
    mkdir -p "$CONFIG_DIR" 2>/dev/null || true
    echo "$level" > "$cache" 2>/dev/null || true
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

valid_domain() {
    local d="${1:-}"
    [[ "$d" =~ ^([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$ ]]
}

json_array_from_args() {
    # 安全生成 JSON 数组，避免手动拼接域名时因特殊字符破坏 config.json。
    if command -v jq >/dev/null 2>&1; then
        jq -nc '$ARGS.positional' --args "$@"
    else
        local out="[" first=1 item
        for item in "$@"; do
            item=${item//\\/\\\\}; item=${item//\"/\\\"}
            if test "$first" -eq 0; then out+=","; fi
            out+="\"$item\""; first=0
        done
        out+="]"; echo "$out"
    fi
}

set_sni_json_array() {
    local arr=("$@")
    if test "${#arr[@]}" -eq 0; then arr=("www.microsoft.com"); fi
    BEST_SNI="${arr[0]}"
    SNI_JSON_ARRAY=$(json_array_from_args "${arr[@]}")
}

cpu_mask_all() {
    # 生成 Linux smp_affinity 掩码，兼容 64 核以上场景，避免 $((1<<CPU)) 溢出。
    local cores="${1:-$(nproc 2>/dev/null || echo 1)}"
    if ! [[ "$cores" =~ ^[0-9]+$ ]] || test "$cores" -lt 1 2>/dev/null; then cores=1; fi
    python3 - "$cores" <<'PY' 2>/dev/null || awk -v n="$cores" 'BEGIN{ if(n<=1) print "1"; else if(n>=31) print "ffffffff"; else printf "%x\n", (2^n)-1 }'
import sys
n=int(sys.argv[1])
print(format((1 << n) - 1, 'x'))
PY
}

choose_best_qdisc() {
    # V198e52: 极速代理默认 fq + BBR。CAKE 不再作为默认项，避免弱 CPU VPS 因整形/分类开销反降速。
    # 如遇高 bufferbloat/丢包，可在高级菜单里手动开启 CAKE。
    echo "fq"
}
validate_port() {
    local p="$1"
    if test -z "$p"; then return 1; fi
    if ! [[ "$p" =~ ^[0-9]+$ ]]; then return 1; fi
    if test "$p" -lt 1 2>/dev/null || test "$p" -gt 65535 2>/dev/null; then return 1; fi
    # 使用精确端口匹配，避免 :4433 被误判成 :443。
    if ss -H -tuln 2>/dev/null | awk '{print $5}' | grep -Eq "(^|:|\])${p}$"; then error "端口 $p 已被系统占用。"; return 1; fi
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
    repair_dns_if_broken || true
    local need="jq curl wget xxd unzip qrencode vnstat cron openssl coreutils sed e2fsprogs pkg-config iproute2 ethtool bc bison flex dwarves rsync python3 cpio apt-transport-https lz4 liblz4-tool gcc-multilib libc6-dev-i386 zstd iptables"
    local missing="" p
    for p in $need; do if ! command -v "$p" >/dev/null 2>&1; then missing="$missing $p"; fi; done
    if test -n "$missing"; then
        info "正在同步依赖: $missing"
        pkg_install $missing
        systemctl start vnstat  >/dev/null 2>&1 || true
        systemctl enable vnstat >/dev/null 2>&1 || true
        systemctl start cron    >/dev/null 2>&1 || systemctl start crond >/dev/null 2>&1 || true
    fi
    repair_dns_if_broken || true
    if test -f "$SCRIPT_PATH"; then
        cp -f "$SCRIPT_PATH" "$SYMLINK" 2>/dev/null || true
        chmod +x "$SYMLINK" 2>/dev/null || true
        hash -r 2>/dev/null || true
    fi
    SERVER_IP=$(_get_ip)
    if test "$SERVER_IP" = "获取失败"; then warn "未能自动获取当前公网 IP 地址。"; fi
}



_swap_total_mb() {
    free -m 2>/dev/null | awk '/^Swap:/ {print int($2)}' || echo 0
}

_swap_used_mb() {
    free -m 2>/dev/null | awk '/^Swap:/ {print int($3)}' || echo 0
}

_zram_supported() {
    modprobe -n zram >/dev/null 2>&1 || lsmod 2>/dev/null | grep -q '^zram'
}

_remove_fstab_path() {
    local p="$1" tmp=""
    test -f /etc/fstab || return 0
    tmp=$(mktemp /tmp/fstab_swap_XXXXXX) || return 0
    awk -v p="$p" 'BEGIN{changed=0} $1==p && $3=="swap" {changed=1; next} {print}' /etc/fstab > "$tmp" 2>/dev/null || { rm -f "$tmp"; return 0; }
    cat "$tmp" > /etc/fstab 2>/dev/null || true
    rm -f "$tmp" 2>/dev/null || true
}

_disable_swap_path_if_safe() {
    local name="$1" type="${2:-}" reason="${3:-}"
    test -n "$name" || return 0
    if swapon --show=NAME --noheadings 2>/dev/null | awk '{print $1}' | grep -qx "$name"; then
        warn "关闭超额 Swap: $name ${reason}"
        swapoff "$name" 2>/dev/null || true
    fi
    _remove_fstab_path "$name"
    if test "$type" = "file" && test -f "$name"; then
        rm -f "$name" 2>/dev/null || true
    fi
}

_disable_all_file_swaps() {
    # 只自动删除普通 swap 文件；不删除 swap 分区，避免误伤云厂商/用户磁盘布局。
    swapon --show=NAME,TYPE --noheadings 2>/dev/null | while read -r name type; do
        if test "$type" = "file"; then
            _disable_swap_path_if_safe "$name" "$type" "(总 Swap 上限 1024MB，清理文件型 Swap)"
        fi
    done
    sed -i '\|^/swapfile[[:space:]]|d' /etc/fstab 2>/dev/null || true
}

_write_swap_sysctl_e52() {
    mkdir -p /etc/sysctl.d 2>/dev/null || true
    cat > /etc/sysctl.d/98-xray-swap.conf << 'EOF_SWAP_SYSCTL_E51'
vm.swappiness = 10
vm.vfs_cache_pressure = 50
EOF_SWAP_SYSCTL_E51
    sysctl -p /etc/sysctl.d/98-xray-swap.conf >/dev/null 2>&1 || true
}

_setup_swapfile_1024_e52() {
    local SWAP_FILE="/swapfile" TARGET_SWAP_MB=1024 root_free_mb current_mb
    _disable_all_file_swaps
    root_free_mb=$(df -Pm / 2>/dev/null | awk 'NR==2{print int($4)}' || echo 0)
    if test "$root_free_mb" -lt 1300 2>/dev/null; then
        warn "根分区可用空间约 ${root_free_mb}MB，不足以安全创建 1GB /swapfile，已跳过。"
        return 0
    fi
    rm -f "$SWAP_FILE" 2>/dev/null || true
    info "ZRAM 不可用，创建兜底 /swapfile=1024MB。"
    if command -v fallocate >/dev/null 2>&1; then
        fallocate -l "${TARGET_SWAP_MB}M" "$SWAP_FILE" 2>/dev/null || dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$TARGET_SWAP_MB" status=none 2>/dev/null || true
    else
        dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$TARGET_SWAP_MB" status=none 2>/dev/null || true
    fi
    if test ! -s "$SWAP_FILE"; then warn "/swapfile 创建失败。"; rm -f "$SWAP_FILE" 2>/dev/null || true; return 0; fi
    chmod 600 "$SWAP_FILE" 2>/dev/null || true
    mkswap "$SWAP_FILE" >/dev/null 2>&1 || { warn "mkswap /swapfile 失败。"; rm -f "$SWAP_FILE" 2>/dev/null || true; return 0; }
    swapon -p 10 "$SWAP_FILE" >/dev/null 2>&1 || { warn "swapon /swapfile 失败，可能是云厂商限制。"; rm -f "$SWAP_FILE" 2>/dev/null || true; return 0; }
    echo "/swapfile none swap sw,nofail 0 0" >> /etc/fstab
}

_setup_zram_1024_e52() {
    local ZRAM_SIZE="1024" zdev="/dev/zram0"
    # e52 规则：总 Swap 上限 1024MB。ZRAM 可用时优先保留 ZRAM，删除 /swapfile 等文件型 Swap。
    _disable_all_file_swaps
    cat > /usr/local/bin/xray-zram.sh <<'EOF_ZRAM_E51'
#!/usr/bin/env bash
set -e
ZRAM_SIZE_MB="1024"
modprobe zram num_devices=1 2>/dev/null || true
if [ -e /sys/block/zram0/reset ]; then
    swapoff /dev/zram0 2>/dev/null || true
    echo 1 > /sys/block/zram0/reset 2>/dev/null || true
fi
echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || true
echo "${ZRAM_SIZE_MB}M" > /sys/block/zram0/disksize
mkswap /dev/zram0 >/dev/null 2>&1
swapon -p 100 /dev/zram0
EOF_ZRAM_E51
    chmod +x /usr/local/bin/xray-zram.sh 2>/dev/null || true
    cat > /etc/systemd/system/xray-zram.service <<'EOF_ZRAM_SRV_E51'
[Unit]
Description=Xray ZRAM Setup Capped At 1024MB
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/xray-zram.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF_ZRAM_SRV_E51
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable xray-zram.service >/dev/null 2>&1 || true
    systemctl restart xray-zram.service >/dev/null 2>&1 || true
}

enforce_swap_cap_1024_e52() {
    title "检查并执行 Swap 总量上限 1024MB（优先 ZRAM，删除超额文件型 Swap）"
    mkdir -p "$BACKUP_DIR" 2>/dev/null || true
    cp -a /etc/fstab "$BACKUP_DIR/fstab.swapcap.$(date +%Y%m%d_%H%M%S).bak" 2>/dev/null || true

    # 如果当前 Swap 已经被使用，仍可切换；swapoff 失败时保守跳过对应项，避免破坏正在使用的内存页。
    if _zram_supported; then
        info "检测到 ZRAM 支持：启用 /dev/zram0=1024MB，并删除 /swapfile/其它文件型 Swap，避免总 Swap 超过 1GB。"
        _setup_zram_1024_e52
    else
        warn "ZRAM 不支持：使用 /swapfile=1024MB 作为唯一脚本管理 Swap。"
        systemctl disable xray-zram.service --now >/dev/null 2>&1 || true
        rm -f /etc/systemd/system/xray-zram.service /usr/local/bin/xray-zram.sh 2>/dev/null || true
        _setup_swapfile_1024_e52
    fi

    _write_swap_sysctl_e52

    local total nonfile
    total=$(_swap_total_mb)
    nonfile=$(swapon --show=NAME,TYPE --noheadings 2>/dev/null | awk '$2!="file" && $1 !~ /zram/ {print $1}' | xargs echo 2>/dev/null || true)
    if test "${total:-0}" -gt 1024 2>/dev/null; then
        if test -n "$nonfile"; then
            warn "当前 Swap 总量约 ${total}MB，仍超过 1024MB；检测到非文件型/非ZRAM Swap：$nonfile。为避免误伤磁盘分区，脚本不自动删除它们。"
        else
            warn "当前 Swap 总量约 ${total}MB，仍超过 1024MB；可能是内核统计/旧 swapoff 未完成，请执行 swapon --show 复核。"
        fi
    else
        info "Swap 总量已控制在 ${total}MB / 1024MB 以内。"
    fi
}

check_and_create_swap() {
    enforce_swap_cap_1024_e52
}


dns_local_listener_ok() {
    ss -H -lunpt 2>/dev/null | awk '{print $5}' | grep -Eq '(^|:|\])53$'
}

write_static_resolv_conf() {
    # 不默认 chattr +i，避免后续系统网络管理器无法接管；只在 DNS 已坏时写入可用静态 DNS。
    chattr -i /etc/resolv.conf 2>/dev/null || true
    rm -f /etc/resolv.conf 2>/dev/null || true
    cat > /etc/resolv.conf <<'EOF_RESOLV'
nameserver 1.1.1.1
nameserver 8.8.8.8
nameserver 208.67.222.222
options timeout:2 attempts:2 rotate
EOF_RESOLV
    chmod 644 /etc/resolv.conf 2>/dev/null || true
}

repair_dns_if_broken() {
    # 修复历史版本把 /etc/resolv.conf 指向 127.0.0.1，但 dnsmasq/systemd-resolved 未运行导致全系统解析失败的问题。
    local need_fix=0
    if test ! -s /etc/resolv.conf; then
        need_fix=1
    elif grep -Eq '^nameserver[[:space:]]+(127\.0\.0\.1|::1)[[:space:]]*$' /etc/resolv.conf 2>/dev/null && ! dns_local_listener_ok; then
        need_fix=1
    elif grep -Eq '^nameserver[[:space:]]+127\.0\.0\.53[[:space:]]*$' /etc/resolv.conf 2>/dev/null; then
        if ! systemctl is-active --quiet systemd-resolved 2>/dev/null && ! dns_local_listener_ok; then
            need_fix=1
        fi
    fi

    if test "$need_fix" -eq 1; then
        warn "检测到 resolv.conf 指向本地解析器但 53 端口无监听，自动切换为稳态静态 DNS。"
        systemctl stop dnsmasq >/dev/null 2>&1 || true
        systemctl disable dnsmasq >/dev/null 2>&1 || true
        systemctl stop resolvconf >/dev/null 2>&1 || true
        systemctl disable resolvconf >/dev/null 2>&1 || true
        systemctl stop systemd-resolved >/dev/null 2>&1 || true
        systemctl disable systemd-resolved >/dev/null 2>&1 || true
        write_static_resolv_conf
        return 0
    fi

    if ! getent hosts api.ipify.org >/dev/null 2>&1; then
        if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 || ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
            warn "检测到 IP 网络可达但域名解析失败，自动写入稳态静态 DNS。"
            write_static_resolv_conf
        fi
    fi
}

verify_dns_available() {
    if getent hosts api.ipify.org >/dev/null 2>&1 || getent hosts google.com >/dev/null 2>&1; then
        return 0
    fi
    repair_dns_if_broken
    getent hosts api.ipify.org >/dev/null 2>&1 || getent hosts google.com >/dev/null 2>&1
}


install_update_dat() {
    mkdir -p "$SCRIPT_DIR" "$DAT_DIR" "$LOG_DIR" 2>/dev/null || true
    cat > "$UPDATE_DAT_SCRIPT" <<'UPDSH_E44'
#!/usr/bin/env bash
set -u
XRAY_DAT_DIR="/usr/local/share/xray"
LOG_FILE="/var/log/xray/update-dat.log"
mkdir -p "$XRAY_DAT_DIR" "$(dirname "$LOG_FILE")" 2>/dev/null || true
log_msg() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }
dl_if_changed() {
    local url="$1" out="$2" tmp="$2.tmp.$$"
    if ! curl -fsSL --connect-timeout 10 --max-time 300 -o "$tmp" "$url"; then
        rm -f "$tmp" 2>/dev/null || true
        log_msg "[WARN] 下载失败，保留旧文件: $url"
        return 1
    fi
    if test -s "$out" && cmp -s "$tmp" "$out"; then
        rm -f "$tmp" 2>/dev/null || true
        log_msg "[INFO] 未变化: $(basename "$out")"
        return 0
    fi
    mv -f "$tmp" "$out"
    log_msg "[INFO] 已更新: $(basename "$out")"
    echo changed >> /tmp/xray-dat-changed.$$ 2>/dev/null || true
    return 0
}
rm -f /tmp/xray-dat-changed.$$ 2>/dev/null || true
ok=0
dl_if_changed "https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat" "$XRAY_DAT_DIR/geoip.dat" || ok=1
dl_if_changed "https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat" "$XRAY_DAT_DIR/geosite.dat" || ok=1
if test -s /tmp/xray-dat-changed.$$ && systemctl is-active --quiet xray; then
    log_msg "[INFO] dat 文件已变化，重启 Xray 使规则生效。"
    systemctl restart xray >/dev/null 2>&1 || true
fi
rm -f /tmp/xray-dat-changed.$$ 2>/dev/null || true
exit "$ok"
UPDSH_E44
    chmod +x "$UPDATE_DAT_SCRIPT" 2>/dev/null || true
    cat > /etc/systemd/system/xray-dat-update.service <<EOF_SERVICE_E44
[Unit]
Description=Xray geoip/geosite dat safe updater
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$UPDATE_DAT_SCRIPT
EOF_SERVICE_E44
    cat > /etc/systemd/system/xray-dat-update.timer <<'EOF_TIMER_E44'
[Unit]
Description=Daily Xray dat update timer

[Timer]
OnCalendar=*-*-* 03:00:00
RandomizedDelaySec=20m
Persistent=true

[Install]
WantedBy=timers.target
EOF_TIMER_E44
    local tmp_cron
    tmp_cron=$(mktemp /tmp/cron_e52_XXXXXX) || true
    if test -n "${tmp_cron:-}"; then
        crontab -l 2>/dev/null | awk -v upd="$UPDATE_DAT_SCRIPT" '$0 ~ upd {next} $0 == "10 3 * * * /bin/systemctl restart xray >/dev/null 2>&1" {next} {print}' > "$tmp_cron" || true
        crontab "$tmp_cron" 2>/dev/null || true
        rm -f "$tmp_cron" 2>/dev/null || true
    fi
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable --now xray-dat-update.timer >/dev/null 2>&1 || true
    info "已配置 systemd timer 更新 geoip/geosite；仅在文件变化时重启 Xray。"
}

do_change_dns() {
    title "配置系统 DNS（V198e52 稳态静态模式）"

    warn "为避免再次出现 /etc/resolv.conf 指向 127.0.0.1 但本地 53 端口无服务的问题，本功能默认写入静态 DNS。"
    echo -e "  1) Cloudflare + Google + OpenDNS  ${cyan}(推荐)${none}"
    echo -e "  2) OpenDNS + Google"
    echo -e "  0) 手动输入一个主 DNS IPv4"
    local sel nameserver fallback_dns
    read -rp "请选择 DNS 方案 (默认 1): " sel || true
    sel=${sel:-1}
    case "$sel" in
        2) nameserver="208.67.222.222"; fallback_dns="8.8.8.8 1.1.1.1" ;;
        0)
            while true; do
                read -rp "请输入主 DNS IP (例如 1.1.1.1): " nameserver || true
                if [[ $nameserver =~ ^([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]]; then
                    break
                fi
                print_red "DNS IP 格式错误，请重新输入。"
            done
            fallback_dns="1.1.1.1 8.8.8.8 208.67.222.222" ;;
        *) nameserver="1.1.1.1"; fallback_dns="8.8.8.8 208.67.222.222" ;;
    esac

    systemctl stop dnsmasq >/dev/null 2>&1 || true
    systemctl disable dnsmasq >/dev/null 2>&1 || true
    systemctl stop resolvconf >/dev/null 2>&1 || true
    systemctl disable resolvconf >/dev/null 2>&1 || true
    systemctl stop systemd-resolved >/dev/null 2>&1 || true
    systemctl disable systemd-resolved >/dev/null 2>&1 || true

    chattr -i /etc/resolv.conf 2>/dev/null || true
    rm -f /etc/resolv.conf 2>/dev/null || true
    {
        echo "nameserver ${nameserver}"
        for ns in $fallback_dns; do echo "nameserver $ns"; done
        echo "options timeout:2 attempts:2 rotate"
    } | awk '!seen[$0]++' > /etc/resolv.conf
    chmod 644 /etc/resolv.conf 2>/dev/null || true

    if getent hosts api.ipify.org >/dev/null 2>&1 || getent hosts google.com >/dev/null 2>&1; then
        info "DNS 配置成功。"
    else
        warn "DNS 仍异常；IP 网络若可达，请检查云厂商防火墙或上游 UDP/53 策略。"
    fi

    info "当前 resolv.conf："
    sed 's/^/    /' /etc/resolv.conf 2>/dev/null || true
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
        "www.hpe.com" "www.tiktok.com" "www.spotify.com" "www.netflix.com" "www.hulu.com" "www.disneyplus.com"
    )

    local sni_string=$(printf "%s\n" "${sni_list[@]}")
    if command -v shuf >/dev/null 2>&1; then
        sni_string=$(echo "$sni_string" | shuf)
    else
        sni_string=$(echo "$sni_string" | awk 'BEGIN{srand()} {print rand()"\t"$0}' | sort -n | cut -f2-)
    fi

    local tmp_sni
    tmp_sni=$(mktemp /tmp/sni_test.XXXXXX) || tmp_sni="/tmp/sni_test.$$"

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
    print_magenta "\n>>> 正在针对目标 SNI [$target] 开启质检 (SNI / TLS 1.3 / ALPN h2)..."
    if ! valid_domain "$target"; then print_red " ✗ 域名格式非法，拒绝写入配置"; return 1; fi
    set +e
    local out=$(echo "Q" | timeout 6 openssl s_client -servername "$target" -connect "$target:443" -alpn h2 -tls1_3 -status 2>&1 || echo "")
    set -e
    local pass=1
    if ! echo "$out" | grep -qi "TLSv1.3"; then print_red " ✗ 质检拦截: 目标服务器未启用 TLS v1.3 协议"; pass=0; fi
    if ! echo "$out" | grep -qiE "ALPN, server accepted to use h2|ALPN.*h2"; then print_red " ✗ 质检拦截: 目标服务器不支持 ALPN h2 协商"; pass=0; fi
    if ! echo "$out" | grep -qi "OCSP response:"; then warn "OCSP Stapling 未发现：这不是致命问题，V198e52 仅提示不强制淘汰。"; fi
    if test "$pass" -eq 0; then warn "该域名 TLS 指纹不完整，强制使用可能导致连接质量下降。"; return 1; else info "质检通过：TLS/SNI/ALPN 关键特征合规。"; return 0; fi
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
                        if test -n "$p_sni" && valid_domain "$p_sni"; then arr+=("$p_sni"); fi
                    done < "$SNI_CACHE_FILE"
                else
                    for i in $m_sel; do
                        local picked=$(awk "NR==$i {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "")
                        if test -n "$picked" && valid_domain "$picked"; then arr+=("$picked"); fi
                    done
                fi
                if test "${#arr[@]}" -eq 0; then error "选择无效，未能解析到目标 SNI，请重试。"; continue; fi
                set_sni_json_array "${arr[@]}"
            else
                if test "$sel" = "0"; then 
                    local d=""
                    read -rp "请输入自定义的 SNI 域名: " d || true
                    BEST_SNI=${d:-www.microsoft.com}
                    if ! valid_domain "$BEST_SNI"; then error "域名格式非法。"; continue; fi
                    set_sni_json_array "$BEST_SNI"
                else
                    local picked=""
                    if [[ "$sel" =~ ^[0-9]+$ ]]; then picked=$(awk "NR==$sel {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo ""); fi
                    if test -n "$picked"; then
                        BEST_SNI="$picked"
                    else
                        error "输入序号有误，默认选择第一号测速节点。"
                        BEST_SNI=$(awk "NR==1 {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "www.microsoft.com")
                    fi
                    if ! valid_domain "$BEST_SNI"; then error "域名格式非法，已回退默认值。"; BEST_SNI="www.microsoft.com"; fi
                    set_sni_json_array "$BEST_SNI"
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
    title "系统飞升：安装官方预编译 XANMOD 内核 (APT 双轨融合版)"
    
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
        local _p=""; read -rp "按 Enter 返回主菜单..." _p || true
        return 1
    fi

    info "预编译核心注入成功，开始执行 GRUB 霸权接管 (破解云镜像强锁)..."
    sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/g' /etc/default/grub 2>/dev/null || true
    sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/g' /etc/default/grub.d/*.cfg 2>/dev/null || true
    if command -v grub-set-default >/dev/null 2>&1; then
        grub-set-default 0 >/dev/null 2>&1 || true
    fi
    
    if command -v update-grub >/dev/null 2>&1; then
        update-grub >/dev/null 2>&1 || true
    else
        apt-get install -y grub2-common >/dev/null 2>&1 || true
        update-grub >/dev/null 2>&1 || true
    fi

    warn "Xanmod 内核安装完成。重启后才会进入新内核。"
    local rb_now=""; read -rp "是否现在重启宿主机？(y/N): " rb_now || true
    if [[ "$rb_now" =~ ^[yY]$ ]]; then reboot; fi
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
        mkdir -p /compile 2>/dev/null || true
        BUILD_DIR="/compile"
    else 
        BUILD_DIR="/usr/src"
    fi

    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if ! cd "$BUILD_DIR"; then die "权限异常：系统拒绝切入工作区 $BUILD_DIR。"; fi
}

_execute_compilation() {
    local extra_make_args="${1:-}"
    local make_flags="${2:-}"
    
    info ">>> 执行物理内存探伤并评估安全编译并发数 (防 OOM 强杀)..."
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
        if gcc -E - -fcf-protection=none </dev/null >/dev/null 2>&1; then
            make_flags="$make_flags -fcf-protection=none"
        fi
        # [还原 e12 的 eval 核心，确保引号逃逸正常]
        if ! eval "$cmd KCFLAGS=\"$make_flags\" $extra_make_args"; then
            error "编译崩塌！这通常是由于系统 OOM 强杀导致的，请检查 Swap 是否被云商系统屏蔽。"
            local _p=""; read -rp "按 Enter 返回主菜单..." _p || true
            return 1
        fi
    else
        if ! $cmd $extra_make_args; then
            error "编译崩塌！这通常是由于系统 OOM 强杀导致的，请检查 Swap 是否被云商系统屏蔽。"
            local _p=""; read -rp "按 Enter 返回主菜单..." _p || true
            return 1
        fi
    fi

    info "编译成功！正在部署内核与构建模块 (严格按序执行)..."
    make modules_install >/dev/null 2>&1 || true
    make install >/dev/null 2>&1 || true

    local COMPILED_VER=$(make kernelversion 2>/dev/null || echo "")
    if test -n "$COMPILED_VER"; then 
        info "内核 ($COMPILED_VER) 已注入宿主机核心。"
        info ">>> 生成强绑定的 initramfs 引导..."
        if command -v update-initramfs >/dev/null 2>&1; then
            update-initramfs -c -k "$COMPILED_VER" >/dev/null 2>&1 || true
        elif command -v dracut >/dev/null 2>&1; then
            dracut --force "/boot/initramfs-${COMPILED_VER}.img" "$COMPILED_VER" >/dev/null 2>&1 || true
        fi
    fi

    info "保留旧版内核以备万一，执行 GRUB 霸权强制接管..."
    sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/g' /etc/default/grub 2>/dev/null || true
    sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=0/g' /etc/default/grub.d/*.cfg 2>/dev/null || true
    if command -v grub-set-default >/dev/null 2>&1; then
        grub-set-default 0 >/dev/null 2>&1 || true
    fi
    update-grub >/dev/null 2>&1 || true

    info "=== 注入网卡与 RPS 软中断特化守护进程 ==="
    if test -n "$IFACE"; then
        cat > /usr/local/bin/nic-optimize.sh <<EOF_NIC
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IFACE="$IFACE"
# V198e52: 纯代理吞吐优先保留 GRO/GSO/TSO，降低 CPU 压力；仅关闭 LRO，避免破坏转发语义。
ethtool -K \$IFACE gro on gso on tso on lro off rx-gro-hw on tx-udp-segmentation on 2>/dev/null || true
ethtool -C \$IFACE adaptive-rx on 2>/dev/null || true
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

        local CPU_COUNT=$(nproc 2>/dev/null || echo 1)
        local CPU_MASK=$(cpu_mask_all "$CPU_COUNT")
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
    finalize
    info "内核编译与结构优化已全部就绪。重启后才会进入新内核。"
    local rb_now=""; read -rp "是否现在重启宿主机？(y/N): " rb_now || true
    if [[ "$rb_now" =~ ^[yY]$ ]]; then reboot; fi
}

_compile_kernel_mainline() {
    local bbr_type="${1:-bbr}"
    local title_suffix="BBR"
    if [ "$bbr_type" = "bbr3" ]; then title_suffix="BBR3"; fi
    
    title "系统飞升：极客编译 Linux 官方主线最新内核 (源码版 + $title_suffix)"
    warn "多核编译引擎已激活，请确保 Swap 容量充足！"
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
        warn "动态寻址失败，启用容灾通道下载稳定版！"
        KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.tar.xz"
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
        make olddefconfig >/dev/null 2>&1 || true
    elif test -f "/proc/config.gz"; then
        info "正在从内存解压当前运行中的内核配置以防断网..."
        zcat /proc/config.gz > .config
        make olddefconfig >/dev/null 2>&1 || true
    else
        warn "未找到宿主机配置！启用 defconfig..."
        make defconfig >/dev/null 2>&1 || true
    fi

    info ">>> 强制内建 VPS 核心存储与网络驱动..."
    ./scripts/config --enable CONFIG_VIRTIO
    ./scripts/config --enable CONFIG_VIRTIO_PCI
    ./scripts/config --enable CONFIG_VIRTIO_NET
    ./scripts/config --enable CONFIG_VIRTIO_BLK
    ./scripts/config --enable CONFIG_VIRTIO_CONSOLE
    ./scripts/config --enable CONFIG_EXT4_FS
    ./scripts/config --enable CONFIG_NVME_CORE
    ./scripts/config --enable CONFIG_BLK_DEV_NVME

    info ">>> 强制内建 CAKE 与 FQ 队列控制模块..."
    ./scripts/config --enable CONFIG_NET_SCH_CAKE
    ./scripts/config --enable CONFIG_NET_SCH_FQ
    ./scripts/config --enable CONFIG_NET_SCH_FQ_CODEL

    sed -i 's/CONFIG_SYSTEM_TRUSTED_KEYS=.*/CONFIG_SYSTEM_TRUSTED_KEYS=""/g' .config 2>/dev/null || true
    sed -i 's/CONFIG_SYSTEM_REVOCATION_KEYS=.*/CONFIG_SYSTEM_REVOCATION_KEYS=""/g' .config 2>/dev/null || true
    sed -i 's/CONFIG_MODULE_SIG_KEY=.*/CONFIG_MODULE_SIG_KEY=""/g' .config 2>/dev/null || true
    ./scripts/config --disable CONFIG_DEBUG_INFO
    ./scripts/config --disable CONFIG_DEBUG_INFO_BTF
    ./scripts/config --disable CONFIG_MODULE_SIG

    ./scripts/config --disable CONFIG_X86_X32
    ./scripts/config --disable CONFIG_IA32_EMULATION
    ./scripts/config --disable CONFIG_COMPAT

    ./scripts/config --disable CONFIG_CC_HAS_IBT
    ./scripts/config --disable CONFIG_X86_KERNEL_IBT

    local final_march=$(_get_safe_march "$cpu_level")
    ./scripts/config --set-str CONFIG_MARCH "$final_march" 2>/dev/null || true

    if [ "$bbr_type" = "bbr3" ]; then
        info ">>> 检测到强开 BBR3 指令，通过 curl 热拉取 BBR3 协议补丁..."
        if curl -fsSL --connect-timeout 10 https://raw.githubusercontent.com/google/bbr/main/patches/bbr3.patch -o bbr3.patch; then
            if patch -p1 < bbr3.patch >/dev/null 2>&1; then
                info "BBR3 代码树 Patch 合入成功！"
            else
                warn "BBR3 Patch 合入警告 (可能版本已原生支持或代码重构)"
            fi
        else
            warn "BBR3 补丁服务器访问受阻，已跳过外部补丁挂载。"
        fi
        ./scripts/config --enable CONFIG_TCP_CONG_BBR
        ./scripts/config --enable CONFIG_DEFAULT_BBR
        ./scripts/config --enable CONFIG_TCP_BBR3 2>/dev/null || true
    else
        ./scripts/config --enable CONFIG_TCP_CONG_BBR 2>/dev/null || true
        ./scripts/config --enable CONFIG_DEFAULT_BBR 2>/dev/null || true
    fi
    
    info ">> 正在生成最终架构图谱，二次加固防爆盾..."
    make olddefconfig >/dev/null 2>&1 || true

    _execute_compilation "" "-march=$final_march"
}

_compile_kernel_xanmod() {
    title "系统飞升：极客源码编译 真·Xanmod 内核 (全自动防爆防卡死版)"
    warn "多核编译引擎已激活，请确保 Swap 容量充足！"
    local confirm=""; read -rp "确定要开始极客源码编译吗？(y/n): " confirm || true
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then return; fi
    
    local cpu_level=$(detect_x86_64_level)
    info "全局探针完成，CPU 等级锁定: x86-64-v${cpu_level}"

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y build-essential bc flex bison libssl-dev libelf-dev libncurses-dev dwarves git curl wget lz4 liblz4-tool gcc-multilib libc6-dev-i386 zstd rsync >/dev/null 2>&1 || true
    
    _fetch_xanmod_tags
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
        LATEST_TAG=$(curl -sL --connect-timeout 10 https://gitlab.com/api/v4/projects/xanmod%2Flinux/repository/tags?per_page=100 | jq -r '.[].name' 2>/dev/null | grep -vE "rc|beta" | grep -E "^[6-9]\.[0-9]+\.[0-9]+(-rt)?-xanmod[0-9]+$" | sort -V -r | head -n 1 || echo "6.18.25-rt-xanmod1")
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
        make olddefconfig >/dev/null 2>&1 || true
    elif test -f "/proc/config.gz"; then
        info "正在从内存解压当前运行中的内核配置以防断网..."
        zcat /proc/config.gz > .config
        make olddefconfig >/dev/null 2>&1 || true
    else
        warn "未找到宿主机配置！启用 defconfig..."
        make defconfig >/dev/null 2>&1 || true
    fi

    info ">>> 强制内建 VPS 核心存储与网络驱动..."
    ./scripts/config --enable CONFIG_VIRTIO
    ./scripts/config --enable CONFIG_VIRTIO_PCI
    ./scripts/config --enable CONFIG_VIRTIO_NET
    ./scripts/config --enable CONFIG_VIRTIO_BLK
    ./scripts/config --enable CONFIG_VIRTIO_CONSOLE
    ./scripts/config --enable CONFIG_EXT4_FS
    ./scripts/config --enable CONFIG_NVME_CORE
    ./scripts/config --enable CONFIG_BLK_DEV_NVME

    info ">>> 强制内建 CAKE 与 FQ 队列控制模块..."
    ./scripts/config --enable CONFIG_NET_SCH_CAKE
    ./scripts/config --enable CONFIG_NET_SCH_FQ
    ./scripts/config --enable CONFIG_NET_SCH_FQ_CODEL

    sed -i 's/CONFIG_SYSTEM_TRUSTED_KEYS=.*/CONFIG_SYSTEM_TRUSTED_KEYS=""/g' .config 2>/dev/null || true
    sed -i 's/CONFIG_SYSTEM_REVOCATION_KEYS=.*/CONFIG_SYSTEM_REVOCATION_KEYS=""/g' .config 2>/dev/null || true
    sed -i 's/CONFIG_MODULE_SIG_KEY=.*/CONFIG_MODULE_SIG_KEY=""/g' .config 2>/dev/null || true

    ./scripts/config --disable CONFIG_DEBUG_INFO
    ./scripts/config --disable CONFIG_DEBUG_INFO_BTF
    ./scripts/config --disable CONFIG_MODULE_SIG

    ./scripts/config --disable CONFIG_X86_X32
    ./scripts/config --disable CONFIG_IA32_EMULATION
    ./scripts/config --disable CONFIG_COMPAT

    ./scripts/config --disable CONFIG_CC_HAS_IBT
    ./scripts/config --disable CONFIG_X86_KERNEL_IBT

    local final_march=$(_get_safe_march "$cpu_level")
    ./scripts/config --set-str CONFIG_MARCH "$final_march" 2>/dev/null || true
    
    ./scripts/config --enable CONFIG_TCP_CONG_BBR 2>/dev/null || true
    ./scripts/config --enable CONFIG_DEFAULT_BBR 2>/dev/null || true
    ./scripts/config --enable CONFIG_TCP_BBR3 2>/dev/null || true
    
    info ">> 正在执行依赖树重组与收尾固化 (去除指令集干预，原汁原味构建)..."
    make olddefconfig >/dev/null 2>&1 || true

    sed -i -E 's/-march=x86-64-v\$\([^)]+\)//g' arch/x86/Makefile 2>/dev/null || true
    sed -i -E 's/-march=x86-64-v\$\{[^}]+\}//g' arch/x86/Makefile 2>/dev/null || true
    
    _execute_compilation "" "-march=$final_march"
}

do_kernel_compile_menu() {
    while true; do
        clear
        title "极客内核源码锻造中心 (多核极速·全自动防变砖版)"
        echo "  [已修复] vdso32 / cc1 编译架构冲突问题 (彻底禁用 32位兼容层)"
        echo "  [已修复] 重启断网卡 busybox 问题 (强制内建 Virtio/EXT4/NVME)"
        echo "  [已生效] 解封多核并发全火力编译，1GB Swap 提供底层护航！"
        echo ""
        echo -e "  ${cyan}1) [官方推荐] APT 安装 Xanmod 预编译稳定内核 (含 BBR3)${none}"
        echo "     - 融合第三方 psABI 智能探测，直接拉取官方 DEB 包，极速稳妥"
        echo ""
        echo -e "  ${magenta}2) [极客源码] 手工编译 真·Xanmod 极客内核 (支持指定 Tag + BBR3) ${none}"
        echo "     - 源码直连 GitLab API，自动选择最安全配置进行极速构建"
        echo ""
        echo -e "  ${yellow}3) [极客源码] 手工编译 Linux 官方主线内核 (Mainline + BBR3) ${none}"
        echo "     - 源码直连 Kernel.org，100% 纯净开源树"
        echo ""
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

do_perf_tuning() {
    title "极客压榨：全域系统底层网络栈结构重塑"
    warn "警告: 此操作将深度注入内核级极限并发参数，执行完毕必须重启宿主机！"
    
    local confirm=""
    read -rp "确定要继续吗？(y/n): " confirm || true
    if test "$confirm" != "y" && test "$confirm" != "Y"; then return; fi

    info ">>> 扒开内核态，提取正在活跃的 TCP 连接状态 (ss -ti)..."
    
    local latency=""
    set +e
    latency=$(ss -ti 2>/dev/null | awk -F 'rtt:' 'NF>1 {split($2, a, " "); split(a[1], b, "/"); total+=b[1]; count++} END {if(count>0) print int(total/count); else print 150}')
    set -e
    
    if ! [[ "$latency" =~ ^[0-9]+$ ]]; then latency=150; fi
    
    local tcp_init_cwnd=$((latency / 20 + 10))
    [[ $tcp_init_cwnd -gt 32 ]] && tcp_init_cwnd=32
    [[ $tcp_init_cwnd -lt 10 ]] && tcp_init_cwnd=10
    
    info "测算平均真实 RTT: ${latency}ms -> 赋予最佳发包窗口 (initcwnd): ${tcp_init_cwnd}"
    
    local default_route=$(ip route show default 2>/dev/null | head -n 1)
    if [[ -n "$default_route" ]]; then
        local clean_route=$(echo "$default_route" | sed 's/ initcwnd [0-9]*//g' | sed 's/ initrwnd [0-9]*//g')
        ip route change $clean_route initcwnd $tcp_init_cwnd initrwnd $tcp_init_cwnd 2>/dev/null || true
        echo "$tcp_init_cwnd" > "$CONFIG_DIR/initcwnd.txt"
        info "已成功向网卡默认路由下发极速慢启动参数！"
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
    rm -f /etc/systemd/system/net-speeder.service /etc/systemd/system/multi-user.target.wants/net-speeder.service 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true

    mkdir -p "$BACKUP_DIR/sysctl" 2>/dev/null || true
    for f in /etc/sysctl.conf /etc/sysctl.d/99-sysctl.conf /etc/sysctl.d/99-network-optimized.conf; do
        if test -f "$f"; then cp -af "$f" "$BACKUP_DIR/sysctl/$(basename "$f").$(date +%Y%m%d_%H%M%S).bak" 2>/dev/null || true; fi
    done
    : > /etc/sysctl.d/99-network-optimized.conf
    # 不再清空 /etc/sysctl.conf 和系统自带 /usr/lib/sysctl.d，避免误删发行版安全参数。
    rm -f /etc/sysctl.d/99-bbr*.conf /etc/sysctl.d/99-ipv6-disable.conf /etc/sysctl.d/99-pro*.conf /etc/sysctl.d/99-xanmod-bbr3.conf 2>/dev/null || true

    info "配置系统高并发进程限制 (Limits，V198e52 稳态安全版)..."
    write_safe_global_limits
    # 不再 daemon-reexec；避免在热更新/远程 SSH 场景触发 systemd 管理器重载副作用。
    systemctl daemon-reload >/dev/null 2>&1 || true

    local target_qdisc="$(choose_best_qdisc)"
    mkdir -p /etc/modules-load.d 2>/dev/null || true
    if test "$target_qdisc" = "cake"; then echo "sch_cake" > /etc/modules-load.d/cake.conf 2>/dev/null || true; else rm -f /etc/modules-load.d/cake.conf 2>/dev/null || true; fi

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
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = ${new_scale}
net.ipv4.tcp_app_win = ${new_app}
net.ipv4.tcp_moderate_rcvbuf = 1

net.core.rmem_default = 3990577
net.core.wmem_default = 3990577
net.core.rmem_max = 57108868
net.core.wmem_max = 57108868
net.ipv4.tcp_rmem = 4096 3990577 57108868
net.ipv4.tcp_wmem = 4096 3990577 57108868
net.ipv4.udp_rmem_min = 4096
net.ipv4.udp_wmem_min = 4096

net.core.dev_weight = 64
net.core.dev_weight_tx_bias = 1
net.core.dev_weight_rx_bias = 1
net.core.netdev_budget = 300

net.ipv4.igmp_max_memberships = 200
net.ipv4.route.flush = 1
net.ipv4.tcp_slow_start_after_idle = 0

vm.swappiness = 10
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
net.ipv4.tcp_fastopen = 0
net.ipv4.tcp_reordering = 3
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_tso_win_divisor = 6

kernel.pid_max = 4194304
# kernel.threads-max = 85536  # 不强行压低发行版默认线程上限
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

vm.vfs_cache_pressure = 50
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.ip_forward = 0
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.tcp_early_retrans = 3
net.ipv4.neigh.default.unres_qlen = 3000
net.ipv4.conf.all.route_localnet = 0
net.ipv4.tcp_orphan_retries = 8
net.ipv4.conf.all.forwarding = 0

net.ipv4.ipfrag_max_dist = 32
# net.ipv4.ipfrag_secret_interval = 200  # 新内核已移除，保留注释避免 sysctl 噪音
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
fs.protected_regular = 1
fs.protected_symlinks = 1

net.core.rps_sock_flow_entries = 131072
net.core.flow_limit_table_len = 131072
net.ipv4.tcp_workaround_signed_windows = 1
vm.dirty_ratio = 35
vm.overcommit_memory = 0
kernel.sysrq = 1

# 默认不强制关闭 IPv6，避免 IPv6-only / 双栈 VPS 因禁用 IPv6 出现断流；如需禁用请自行单独配置。
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1
# net.ipv6.conf.lo.disable_ipv6 = 1

vm.max_map_count = 262144
net.ipv4.tcp_child_ehash_entries = 65535
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.tcp_stdurg = 0
net.ipv4.tcp_challenge_ack_limit = 1000
net.ipv4.tcp_comp_sack_delay_ns = 50000
net.ipv4.tcp_comp_sack_nr = 1
net.ipv4.tcp_fwmark_accept = 1
net.ipv4.tcp_invalid_ratelimit = 800
net.ipv4.tcp_l3mdev_accept = 1

net.core.tstamp_allow_data = 1
net.core.netdev_tstamp_prequeue = 1
kernel.randomize_va_space = 2

#net.ipv4.tcp_mem = 65536 131072 262144
#net.ipv4.udp_mem = 65536 131072 262144
net.ipv4.tcp_recovery = 0x1
net.ipv4.tcp_dsack = 1

# kernel.shmmax = 67108864  # 不强行压低共享内存上限
# kernel.shmall = 16777216

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

    local sysctl_log="/tmp/xray-sysctl-apply.log"
    if ! sysctl -p /etc/sysctl.d/99-network-optimized.conf >"$sysctl_log" 2>&1; then
        warn "部分 Sysctl 参数在当前内核/云厂商环境不支持，已自动忽略，不中断优化流程。详情: $sysctl_log"
    else
        info "底层 Sysctl 参数已成功注入。"
        rm -f "$sysctl_log" 2>/dev/null || true
    fi

    info "植入底层 MTU/MSS 钳制抗丢包规则 (自适应兼容 iptables/nftables)..."
    modprobe iptable_mangle >/dev/null 2>&1 || true
    modprobe xt_TCPMSS >/dev/null 2>&1 || true
    iptables -t mangle -C POSTROUTING -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || iptables -t mangle -A POSTROUTING -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || warn "当前系统内核模块不完整，已安全跳过 MSS 注入。"
}

do_txqueuelen_opt() {
    title "网卡发送队列 (TX Queue) 调优"
    local IP_CMD=$(command -v ip || echo "")
    if test -z "$IP_CMD"; then error "系统缺失 iproute2 (ip 命令) 核心组件。"; local _p=""; read -rp "按 Enter 返回..." _p || true; return 1; fi
    local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if test -z "$IFACE"; then error "无法定位系统默认出口网卡。"; local _p=""; read -rp "按 Enter 返回..." _p || true; return 1; fi
    info "正在修改 $IFACE 发送队列长度至 3000..."
    $IP_CMD link set "$IFACE" txqueuelen 3000 2>/dev/null || true
    
    cat > /etc/systemd/system/txqueue.service << EOF
[Unit]
Description=Set TX Queue Length for Low Latency
After=network.target

[Service]
Type=oneshot
ExecStart=$IP_CMD link set $IFACE txqueuelen 3000
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable txqueue >/dev/null 2>&1 || true
    systemctl start txqueue >/dev/null 2>&1 || true
    
    local CHECK_QLEN=$($IP_CMD link show "$IFACE" 2>/dev/null | grep -o 'qlen [0-9]*' | awk '{print $2}' || echo "")
    if test "$CHECK_QLEN" = "3000"; then info "已成功将网卡底层并发队列长度扩容至 3000 级。"; else warn "当前虚拟机或网卡驱动不支持调节 txqueuelen。"; fi
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
check_dnsmasq_state() { if systemctl is-active dnsmasq >/dev/null 2>&1 && grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null; then echo "true"; else echo "false"; fi; }
check_thp_state() { if [ ! -f "/sys/kernel/mm/transparent_hugepage/enabled" ] || [ ! -w "/sys/kernel/mm/transparent_hugepage/enabled" ]; then echo "unsupported"; return; fi; if grep -q '\[never\]' /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null; then echo "true"; else echo "false"; fi; }
check_mtu_state() { if [ ! -f "/proc/sys/net/ipv4/tcp_mtu_probing" ] || [ ! -w "/proc/sys/net/ipv4/tcp_mtu_probing" ]; then echo "unsupported"; return; fi; if [ "$(sysctl -n net.ipv4.tcp_mtu_probing 2>/dev/null)" = "1" ]; then echo "true"; else echo "false"; fi; }
check_cpu_state() { if [ ! -d "/sys/devices/system/cpu/cpu0/cpufreq" ] || [ ! -w "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor" ]; then echo "unsupported"; return; fi; if grep -q 'performance' /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null; then echo "true"; else echo "false"; fi; }
check_ring_state() { local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo ""); if [ -z "$IFACE" ] || ! command -v ethtool >/dev/null 2>&1 || ! ethtool -g "$IFACE" >/dev/null 2>&1; then echo "unsupported"; return; fi; local curr_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Current hardware settings" | grep "RX:" | head -1 | awk '{print $2}'); if [ -z "$curr_rx" ]; then echo "unsupported"; return; fi; if [ "$curr_rx" = "512" ]; then echo "true"; else echo "false"; fi; }
check_zram_state() { if ! modprobe -n zram >/dev/null 2>&1 && ! lsmod 2>/dev/null | grep -q zram; then echo "unsupported"; return; fi; if swapon --show 2>/dev/null | grep -q 'zram'; then echo "true"; else echo "false"; fi; }
check_journal_state() { if [ ! -f "/etc/systemd/journald.conf" ]; then echo "unsupported"; return; fi; if grep -q '^Storage=volatile' /etc/systemd/journald.conf 2>/dev/null; then echo "true"; else echo "false"; fi; }
check_irq_state() { local CORES=$(nproc 2>/dev/null || echo 1); if test "$CORES" -lt 2 2>/dev/null; then echo "unsupported"; return; fi; local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo ""); if test -z "$IFACE"; then echo "false"; return; fi; local irq=$(grep "$IFACE" /proc/interrupts 2>/dev/null | head -n 1 | awk '{print $1}' | tr -d ':' || echo ""); if test -n "$irq"; then local want=$(cpu_mask_all "$CORES" | tr 'A-F' 'a-f'); local got=$(cat "/proc/irq/$irq/smp_affinity" 2>/dev/null | tr -d ',' | tr 'A-F' 'a-f' || echo ""); if test "$got" = "$want"; then echo "true"; else echo "false"; fi; else echo "false"; fi; }


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


toggle_dnsmasq() {
    if [ "$(check_dnsmasq_state)" = "true" ]; then
        systemctl stop dnsmasq >/dev/null 2>&1 || true
        systemctl disable dnsmasq >/dev/null 2>&1 || true
        write_static_resolv_conf
        _safe_jq_write '.dns = {"servers":["https://1.1.1.1/dns-query","https://208.67.222.222/dns-query","https://doh.opendns.com/dns-query"], "queryStrategy":"UseIPv4"}'
        return 0
    fi

    export DEBIAN_FRONTEND=noninteractive
    repair_dns_if_broken
    apt-get update -y >/dev/null 2>&1 || yum makecache -y >/dev/null 2>&1 || true
    apt-get install -y dnsmasq >/dev/null 2>&1 || yum install -y dnsmasq >/dev/null 2>&1 || true

    if ! command -v dnsmasq >/dev/null 2>&1; then
        warn "dnsmasq 未安装成功，保持静态 DNS，避免 resolv.conf 指向无人监听的 127.0.0.1。"
        write_static_resolv_conf
        return 0
    fi

    systemctl stop systemd-resolved 2>/dev/null || true
    systemctl disable systemd-resolved 2>/dev/null || true
    systemctl stop resolvconf 2>/dev/null || true
    systemctl disable resolvconf 2>/dev/null || true

    cat > /etc/dnsmasq.conf <<EOF
port=53
listen-address=127.0.0.1
bind-interfaces
cache-size=10000
min-cache-ttl=300
neg-ttl=60
all-servers
server=1.1.1.1
server=1.0.0.1
server=208.67.222.222
server=8.8.8.8
no-resolv
no-poll
domain-needed
bogus-priv
dns-forward-max=1024
EOF

    systemctl enable dnsmasq >/dev/null 2>&1 || true
    if systemctl restart dnsmasq >/dev/null 2>&1 && dns_local_listener_ok; then
        cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true
        chattr -i /etc/resolv.conf 2>/dev/null || true
        echo "nameserver 127.0.0.1" > /etc/resolv.conf
        chmod 644 /etc/resolv.conf 2>/dev/null || true
        if getent hosts api.ipify.org >/dev/null 2>&1 || getent hosts google.com >/dev/null 2>&1; then
            _safe_jq_write '.dns = {"servers":["127.0.0.1"], "queryStrategy":"UseIPv4"}'
            info "dnsmasq 已启用并通过解析验证。"
        else
            warn "dnsmasq 已启动但解析验证失败，回退静态 DNS。"
            systemctl stop dnsmasq >/dev/null 2>&1 || true
            systemctl disable dnsmasq >/dev/null 2>&1 || true
            write_static_resolv_conf
        fi
    else
        warn "dnsmasq 未能监听 127.0.0.1:53，已回退静态 DNS。"
        systemctl stop dnsmasq >/dev/null 2>&1 || true
        systemctl disable dnsmasq >/dev/null 2>&1 || true
        write_static_resolv_conf
    fi
}

toggle_thp() { if [ "$(check_thp_state)" = "true" ]; then echo always > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true; echo always > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true; else echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true; echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true; fi; update_hw_boot_script; }
toggle_mtu() { local conf="/etc/sysctl.d/99-network-optimized.conf"; if [ "$(check_mtu_state)" = "true" ]; then sed -i 's/^net.ipv4.tcp_mtu_probing.*/net.ipv4.tcp_mtu_probing = 0/' "$conf" 2>/dev/null || true; else if grep -q "net.ipv4.tcp_mtu_probing" "$conf" 2>/dev/null; then sed -i 's/^net.ipv4.tcp_mtu_probing.*/net.ipv4.tcp_mtu_probing = 1/' "$conf" 2>/dev/null || true; else echo "net.ipv4.tcp_mtu_probing = 1" >> "$conf"; fi; fi; sysctl -p "$conf" >/dev/null 2>&1 || true; }
toggle_cpu() { if [ "$(check_cpu_state)" = "unsupported" ]; then return; fi; if [ "$(check_cpu_state)" = "true" ]; then for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do if [ -f "$cpu" ]; then echo schedutil > "$cpu" 2>/dev/null || echo ondemand > "$cpu" 2>/dev/null || true; fi; done; else for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do if [ -f "$cpu" ]; then echo performance > "$cpu" 2>/dev/null || true; fi; done; fi; update_hw_boot_script; }
toggle_ring() { local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo ""); if [ "$(check_ring_state)" = "unsupported" ] || [ -z "$IFACE" ]; then return; fi; if [ "$(check_ring_state)" = "true" ]; then local max_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Pre-set maximums" | grep "RX:" | head -1 | awk '{print $2}'); if [ -n "$max_rx" ]; then ethtool -G "$IFACE" rx "$max_rx" tx "$max_rx" 2>/dev/null || true; fi; else ethtool -G "$IFACE" rx 512 tx 512 2>/dev/null || true; fi; update_hw_boot_script; }
toggle_zram() {
    # e52：废弃旧“按内存倍数创建 ZRAM”的 toggle，统一走 1024MB 总 Swap 上限策略。
    enforce_swap_cap_1024_e52
}
toggle_journal() { local conf="/etc/systemd/journald.conf"; if [ "$(check_journal_state)" = "unsupported" ]; then return; fi; if [ "$(check_journal_state)" = "true" ]; then sed -i 's/^Storage=volatile/#Storage=auto/' "$conf" 2>/dev/null || true; systemctl restart systemd-journald >/dev/null 2>&1 || true; else if grep -q "^#Storage=" "$conf" 2>/dev/null; then sed -i 's/^#Storage=.*/Storage=volatile/' "$conf" 2>/dev/null || true; elif grep -q "^Storage=" "$conf" 2>/dev/null; then sed -i 's/^Storage=.*/Storage=volatile/' "$conf" 2>/dev/null || true; else echo "Storage=volatile" >> "$conf"; fi; systemctl restart systemd-journald >/dev/null 2>&1 || true; fi; }
toggle_process_priority() { local limit_file="/etc/systemd/system/xray.service.d/limits.conf"; if [ ! -f "$limit_file" ]; then return; fi; if grep -q "^OOMScoreAdjust=-500" "$limit_file" 2>/dev/null; then sed -i '/^OOMScoreAdjust=/d' "$limit_file" 2>/dev/null || true; sed -i '/^IOSchedulingClass=/d' "$limit_file" 2>/dev/null || true; sed -i '/^IOSchedulingPriority=/d' "$limit_file" 2>/dev/null || true; else echo "OOMScoreAdjust=-500" >> "$limit_file"; echo "IOSchedulingClass=best-effort" >> "$limit_file"; echo "IOSchedulingPriority=0" >> "$limit_file"; fi; systemctl daemon-reload >/dev/null 2>&1 || true; }
toggle_routeonly() { if [ "$(check_routeonly_state)" = "true" ]; then _safe_jq_write '(.inbounds[]? | select(. != null) | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly) = false'; else _safe_jq_write '(.inbounds[]? | select(. != null) | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly) = true'; fi; }


toggle_irq() { local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo ""); if [ -z "$IFACE" ]; then return; fi; if [ "$(check_irq_state)" = "true" ]; then systemctl start irqbalance 2>/dev/null || true; systemctl enable irqbalance 2>/dev/null || true; else systemctl stop irqbalance 2>/dev/null || true; systemctl disable irqbalance 2>/dev/null || true; local CPU=$(nproc 2>/dev/null || echo 1); local MASK=$(cpu_mask_all "$CPU"); for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || true); do echo "$MASK" > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true; done; fi; update_hw_boot_script; }


_turn_off_app() {
    _safe_jq_write '
      del(.routing.domainMatcher) | 
      del(.outbounds[]? | select(. != null) | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpNoDelay, .streamSettings?.sockopt?.tcpFastOpen, .streamSettings?.sockopt?.tcpKeepAliveIdle, .streamSettings?.sockopt?.tcpKeepAliveInterval) | 
      del(.inbounds[]?  | select(. != null) | select(.protocol=="vless")   | .streamSettings?.sockopt?.tcpNoDelay, .streamSettings?.sockopt?.tcpFastOpen, .streamSettings?.sockopt?.tcpKeepAliveIdle, .streamSettings?.sockopt?.tcpKeepAliveInterval)
    '
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
        title "全域 25 项系统级及应用层微操管理中心（V198e52 稳态极速）"
        if ! test -f "$CONFIG"; then error "未发现配置，请先执行核心部署！"; _e52_pause; return; fi
        local out_fastopen out_nodelay out_keepalive sniff_status routeonly_status buffer_state dns_status policy_status affinity_state mph_state maxtime_state has_reality limit_file gc_status
        out_fastopen=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpFastOpen // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        out_nodelay=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpNoDelay // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        out_keepalive=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpKeepAliveIdle // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        sniff_status=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .sniffing.metadataOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        routeonly_status=$(check_routeonly_state)
        buffer_state=$(check_buffer_state)
        dns_status=$(jq -r 'select(.dns != null) | .dns.queryStrategy // "false"' "$CONFIG" 2>/dev/null)
        policy_status=$(jq -r 'select(.policy != null) | .policy.levels["0"].connIdle // "false"' "$CONFIG" 2>/dev/null)
        affinity_state=$(check_affinity_state)
        mph_state=$(check_mph_state)
        maxtime_state=$(check_maxtime_state)
        has_reality=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .protocol' "$CONFIG" 2>/dev/null | head -n 1)
        limit_file="/etc/systemd/system/xray.service.d/limits.conf"
        gc_status="未知"; if test -f "$limit_file"; then gc_status=$(awk -F'=' '/^Environment="GOGC=/ {print $3}' "$limit_file" | tr -d '"' | head -1); gc_status=${gc_status:-"默认 100"}; fi
        local dnsmasq_state thp_state mtu_state cpu_state ring_state cake_state ackfilter_state ecn_state wash_state gso_state irq_state zram_state journal_state prio_state
        dnsmasq_state=$(check_dnsmasq_state); thp_state=$(check_thp_state); mtu_state=$(check_mtu_state); cpu_state=$(check_cpu_state); ring_state=$(check_ring_state); cake_state=$(check_cake_state); ackfilter_state=$(check_ackfilter_state); ecn_state=$(check_ecn_state); wash_state=$(check_wash_state); gso_state=$(check_gso_off_state); irq_state=$(check_irq_state); zram_state=$(check_zram_state); journal_state=$(check_journal_state); prio_state=$(check_process_priority_state)
        local s1 s1f s2 s3 s4 s5 s6 s8 s9 s10 s11 s12 s13 s14 s15 s16 s17 s18 s19 s20 s21 s22 s23 s24 s25
        s1=$([ "$out_nodelay" = "true" ] && echo "${cyan}已开启${none}" || echo "${gray}未开启${none}")
        s1f=$([ "$out_fastopen" = "true" ] && echo "${yellow}已开启（不建议默认）${none}" || echo "${gray}默认关闭${none}")
        s2=$([ "$out_keepalive" = "30" ] && echo "${cyan}已开启 (30s/15s)${none}" || echo "${gray}系统默认${none}")
        s3=$([ "$sniff_status" = "true" ] && echo "${cyan}已开启${none}" || echo "${gray}未开启${none}")
        s4=$([ "$routeonly_status" = "true" ] && echo "${cyan}已开启${none}" || echo "${gray}未开启${none}")
        s5=$([ "$buffer_state" = "true" ] && echo "${cyan}已收缩 (128KB)${none}" || echo "${gray}系统默认${none}")
        s6=$([ "$dns_status" = "UseIPv4" ] && echo "${cyan}已开启 IPv4 优先${none}" || echo "${gray}未开启${none}")
        s8=$([ "$policy_status" = "260" ] && echo "${cyan}已开启 (闲置260s/握手3s)${none}" || echo "${gray}默认/非260s${none}")
        s9=$([ "$affinity_state" = "true" ] && echo "${cyan}已绑核锁死${none}" || echo "${gray}系统调度${none}")
        s10=$([ "$mph_state" = "true" ] && echo "${cyan}MPH 算法就绪${none}" || echo "${gray}未开启${none}")
        s11=$([ -z "$has_reality" ] || [ "$has_reality" = "null" ] && echo "${gray}跳过 (无 Reality)${none}" || ([ "$maxtime_state" = "true" ] && echo "${cyan}时间锁 (60s) 已开启${none}" || echo "${gray}未开启${none}"))
        s12=$([ "$dnsmasq_state" = "true" ] && echo "${cyan}已开启内存解析${none}" || echo "${gray}未开启${none}")
        s13=$([ "$thp_state" = "true" ] && echo "${cyan}已关闭 THP${none}" || ([ "$thp_state" = "unsupported" ] && echo "${gray}不支持${none}" || echo "${gray}系统默认${none}"))
        s14=$([ "$mtu_state" = "true" ] && echo "${cyan}智能探测中${none}" || ([ "$mtu_state" = "unsupported" ] && echo "${gray}不支持${none}" || echo "${gray}未开启${none}"))
        s15=$([ "$cpu_state" = "true" ] && echo "${cyan}全核性能模式${none}" || ([ "$cpu_state" = "unsupported" ] && echo "${gray}不支持${none}" || echo "${gray}节能降频中${none}"))
        s16=$([ "$ring_state" = "true" ] && echo "${cyan}RX/TX自适应最大值${none}" || ([ "$ring_state" = "unsupported" ] && echo "${gray}不支持${none}" || echo "${gray}未按硬件上限设置${none}"))
        s17=$([ "$cake_state" = "true" ] && echo "${cyan}CAKE 已挂载${none}" || echo "${gray}默认 (FQ)${none}")
        s18=$([ "$ackfilter_state" = "true" ] && echo "${cyan}开启 (ACK 压缩)${none}" || echo "${gray}未开启${none}")
        s19=$([ "$ecn_state" = "true" ] && echo "${cyan}开启 (抗丢包)${none}" || echo "${gray}未开启${none}")
        s20=$([ "$wash_state" = "true" ] && echo "${cyan}开启 (清空无用标记)${none}" || echo "${gray}未开启${none}")
        s21=$([ "$gso_state" = "true" ] && echo "${yellow}已主动关闭卸载（排障模式）${none}" || ([ "$gso_state" = "unsupported" ] && echo "${gray}不支持${none}" || echo "${cyan}极速默认保留（未主动关闭）${none}"))
        s22=$([ "$irq_state" = "true" ] && echo "${cyan}单核硬锁死${none}" || ([ "$irq_state" = "unsupported" ] && echo "${gray}不支持${none}" || echo "${gray}系统乱序分发${none}"))
        s23=$([ "$zram_state" = "true" ] && echo "${cyan}已挂载 ZRAM${none}" || ([ "$zram_state" = "unsupported" ] && echo "${gray}不支持${none}" || echo "${gray}未启用${none}"))
        s24=$([ "$journal_state" = "true" ] && echo "${cyan}纯内存极极速化${none}" || ([ "$journal_state" = "unsupported" ] && echo "${gray}不支持${none}" || echo "${gray}磁盘 IO 写入${none}"))
        s25=$([ "$prio_state" = "true" ] && echo "${cyan}OOM免死提权${none}" || echo "${gray}系统默认调度${none}")
        echo -e "  ${magenta}--- Xray Core 应用层内部调优 (1-11) ---${none}"
        echo -e "  1) TCP NoDelay 小包低延迟（默认开启）                 | 状态: $s1"
        echo -e "  1f) TCP FastOpen 独立开关（默认关闭，排障后再开）      | 状态: $s1f"
        echo -e "  2) Socket 智能保活心跳 (KeepAlive)                   | 状态: $s2"
        echo -e "  3) 嗅探引擎减负 (metadataOnly 解放 CPU)              | 状态: $s3"
        echo -e "  4) 路由纯净解析 (routeOnly 规避冗余查询)             | 状态: $s4"
        echo -e "  5) Xray 内存碎片收缩 (Buffer Size 强缩至 128KB)       | 状态: $s5"
        echo -e "  6) 内置并发 DoH / Dnsmasq 路由分发 (Native DNS)      | 状态: $s6"
        echo -e "  7) GOGC 内存阶梯动态调优 (自动侦测物理内存)          | 设定: ${cyan}${gc_status}${none}"
        echo -e "  8) Policy 策略组优化 (连接生命周期极速回收)          | 状态: $s8"
        echo -e "  9) 智能物理绑核 & GOMAXPROCS 调度 (适配多核复用)     | 状态: $s9"
        echo -e "  10) Minimal Perfect Hash (MPH) 路由匹配极速降维引擎  | 状态: $s10"
        echo -e "  11) Reality 防重放装甲 (maxTimeDiff 时间偏移拦截)    | 状态: $s11\n"
        echo -e "  ${magenta}--- Linux 系统层与内核硬件级微操 (12-25) ---${none}"
        echo -e "  12) 【Dnsmasq 本地极速内存缓存引擎 (锁TTL)】         | 状态: $s12"
        echo -e "  13) 【透明大页 (THP - Transparent Huge Pages)】      | 状态: $s13"
        echo -e "  14) 【TCP PMTU 黑洞智能探测 (Probing=1)】            | 状态: $s14"
        echo -e "  15) 【CPU 频率调度器锁定 (Performance 全开)】        | 状态: $s15"
        echo -e "  16) 【网卡硬件环形缓冲区 (Ring Buffer)】(自适应最大值（按RX/TX硬件上限）)    | 状态: $s16"
        echo -e "  17) 【CAKE 拥塞调度器】(可选：抗缓冲膨胀，极速默认 FQ)            | 状态: $s17"
        echo -e "  18)  ├── 子项: CAKE Ack Filter (TCP 确认包过滤)      | 状态: $s18"
        echo -e "  19)  ├── 子项: CAKE ECN (开启显式拥塞通知防断流)     | 状态: $s19"
        echo -e "  20)  └── 子项: CAKE WASH (清洗冗余拥塞标记)          | 状态: $s20"
        echo -e "  21) 【网卡 GSO/GRO 硬件卸载控制】(可选：排障用，极速默认保留)     | 状态: $s21"
        echo -e "  22) 【网卡 IRQ 中断多核分发绑定】(中断锁定防漂移)    | 状态: $s22"
        echo -e "  23) 【ZRAM】(总 Swap 上限 1024MB，优先ZRAM删除超额Swap)    | 状态: $s23"
        echo -e "  24) 【日志系统 Journald 纯内存化】(斩断磁盘羁绊)     | 状态: $s24"
        echo -e "  25) 【系统进程级防杀抢占 (OOM/Nice 提权)】           | 状态: $s25\n"
        echo -e "  ${cyan}26) 一键幂等开启 1-11 项 应用层微操（不反向关闭）${none}"
        echo -e "  ${yellow}27) 一键执行安全系统级微操（不自动开 CAKE/不关闭 GSO/不收缩 Ring）${none}"
        echo -e "  ${red}28) 极速稳态一键打通：应用层 + 安全系统级微操 (执行后重启 Xray)${none}"
        echo "  0) 返回上一级"; hr
        local app_opt=""; read -rp "请下达操作指令: " app_opt || true
        case "$app_opt" in
            1) apply_xray_nodelay_default; systemctl restart xray >/dev/null 2>&1 || true; info "TCP NoDelay 已幂等开启。"; _e52_pause ;;
            1f|1F) if [ "$out_fastopen" = "true" ]; then _safe_jq_write '(.outbounds[]? | select(.streamSettings?.sockopt? != null) | .streamSettings.sockopt.tcpFastOpen)=false | (.inbounds[]? | select(.streamSettings?.sockopt? != null) | .streamSettings.sockopt.tcpFastOpen)=false'; info "TCP FastOpen 已关闭。"; else _safe_jq_write '(.outbounds[]? | select(.streamSettings?.sockopt? != null) | .streamSettings.sockopt.tcpFastOpen)=true | (.inbounds[]? | select(.streamSettings?.sockopt? != null) | .streamSettings.sockopt.tcpFastOpen)=true'; warn "TCP FastOpen 已开启；如跨境握手不稳请关闭。"; fi; systemctl restart xray >/dev/null 2>&1 || true; _e52_pause ;;
            2|3|4|5|6) apply_xray_keep_2_to_6_defaults; remove_xray_env_buffer; systemctl restart xray >/dev/null 2>&1 || true; info "2-6 项已按稳态默认幂等固化。"; _e52_pause ;;
            7) set_xray_gogc_300; systemctl daemon-reload >/dev/null 2>&1 || true; systemctl restart xray >/dev/null 2>&1 || true; info "GOGC=300 已固化。"; _e52_pause ;;
            8) force_apply_xray_core_defaults_e52; remove_xray_env_buffer; systemctl restart xray >/dev/null 2>&1 || true; info "Policy=260s + Buffer=128KB 已固化。"; _e52_pause ;;
            9) apply_xray_cpu_schedule_default; systemctl daemon-reload >/dev/null 2>&1 || true; systemctl restart xray >/dev/null 2>&1 || true; info "CPU 调度已按单核/多核自动检测固化。"; _e52_pause ;;
            10) _safe_jq_write '.routing |= (. // {}) | .routing.domainMatcher = "mph"'; systemctl restart xray >/dev/null 2>&1 || true; info "MPH 已开启。"; _e52_pause ;;
            11) if [ -z "$has_reality" ] || [ "$has_reality" = "null" ]; then error "无 Reality 支持。"; else _safe_jq_write '(.inbounds[]? | select(. != null) | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff) = 60000'; systemctl restart xray >/dev/null 2>&1 || true; info "Reality 时间锁已开启。"; fi; _e52_pause ;;
            12) enable_dnsmasq_cache_safely; systemctl restart xray >/dev/null 2>&1 || true; _e52_pause ;;
            13) enable_thp_never_default; _e52_pause ;;
            14) apply_hotupdate_fast_sysctl; _e52_pause ;;
            15) enable_cpu_performance_default; _e52_pause ;;
            16) toggle_ring; _e52_pause ;;
            17) toggle_cake_qdisc; update_hw_boot_script; _e52_pause ;;
            18) toggle_cake_flag "ack_filter"; update_hw_boot_script; _e52_pause ;;
            19) toggle_cake_flag "ecn"; update_hw_boot_script; _e52_pause ;;
            20) toggle_cake_flag "wash"; update_hw_boot_script; _e52_pause ;;
            21) toggle_gso; _e52_pause ;;
            22) toggle_irq; _e52_pause ;;
            23) enable_zram_default; _e52_pause ;;
            24) enable_journald_volatile_default; _e52_pause ;;
            25) apply_process_priority_default; systemctl restart xray >/dev/null 2>&1 || true; _e52_pause ;;
            26) _turn_on_app; systemctl restart xray >/dev/null 2>&1 || true; info "应用层 1-11 已幂等激活。"; _e52_pause ;;
            27) apply_safe_turbo_defaults; systemctl restart xray >/dev/null 2>&1 || true; info "安全系统级微操已幂等落地。"; _e52_pause ;;
            28) _turn_on_app; apply_safe_turbo_defaults; systemctl restart xray >/dev/null 2>&1 || true; info "极速稳态一键打通完成。"; _e52_pause ;;
            0) return ;;
        esac
    done
}

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



backup_hotupdate_snapshot() {
    local ts dir
    ts=$(date +%Y%m%d_%H%M%S)
    dir="$BACKUP_DIR/hotupdate_${ts}"
    mkdir -p "$dir" "$BACKUP_DIR" 2>/dev/null || true

    cp -a "$CONFIG" "$dir/config.json" 2>/dev/null || true
    cp -a "$PUBKEY_FILE" "$dir/public.key" 2>/dev/null || true
    cp -a "$USER_SNI_MAP" "$dir/user_sni.txt" 2>/dev/null || true
    cp -a "$USER_TIME_MAP" "$dir/user_time.txt" 2>/dev/null || true
    cp -a /etc/systemd/system/xray.service.d "$dir/xray.service.d" 2>/dev/null || true
    cp -a /etc/sysctl.d/99-network-optimized.conf "$dir/99-network-optimized.conf" 2>/dev/null || true
    cp -a /etc/sysctl.d/99-xray-hotupdate-fast.conf "$dir/99-xray-hotupdate-fast.conf" 2>/dev/null || true
    cp -a /usr/local/bin/xrv "$dir/xrv.old" 2>/dev/null || true
    cp -a /usr/local/bin/xray-origin-guard.sh "$dir/xray-origin-guard.sh.old" 2>/dev/null || true
    echo "$dir"
}

install_self_entrypoint() {
    mkdir -p "$SCRIPT_DIR" 2>/dev/null || true
    if test -f "$SCRIPT_PATH"; then
        cp -f "$SCRIPT_PATH" "$SYMLINK" 2>/dev/null || true
        cp -f "$SCRIPT_PATH" "$SCRIPT_DIR/ex198e52.sh" 2>/dev/null || true
        chmod +x "$SYMLINK" "$SCRIPT_DIR/ex198e52.sh" 2>/dev/null || true
    fi
    echo "$SCRIPT_VERSION" > "$SCRIPT_VERSION_FILE" 2>/dev/null || true
    hash -r 2>/dev/null || true
}

ensure_public_key_cache() {
    if test -s "$PUBKEY_FILE"; then chmod 600 "$PUBKEY_FILE" 2>/dev/null || true; return 0; fi
    if test ! -f "$CONFIG" || test ! -x "$XRAY_BIN" || ! command -v jq >/dev/null 2>&1; then return 0; fi
    local pub priv out
    pub=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.publicKey // empty' "$CONFIG" 2>/dev/null | head -n 1 || true)
    if test -n "$pub" && test "$pub" != "null"; then
        echo "$pub" > "$PUBKEY_FILE" 2>/dev/null || true
        chmod 600 "$PUBKEY_FILE" 2>/dev/null || true
        return 0
    fi
    priv=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.privateKey // empty' "$CONFIG" 2>/dev/null | head -n 1 || true)
    if test -n "$priv" && test "$priv" != "null"; then
        out=$("$XRAY_BIN" x25519 -i "$priv" 2>/dev/null || true)
        pub=$(echo "$out" | awk -F': ' 'tolower($1) ~ /public/ {print $2}' | tr -d ' \r\n' | head -n 1)
        if test -n "$pub"; then
            echo "$pub" > "$PUBKEY_FILE" 2>/dev/null || true
            chmod 600 "$PUBKEY_FILE" 2>/dev/null || true
        fi
    fi
}

migrate_legacy_user_maps() {
    if test ! -f "$CONFIG" || ! command -v jq >/dev/null 2>&1; then return 0; fi
    mkdir -p "$CONFIG_DIR" 2>/dev/null || true
    touch "$USER_SNI_MAP" "$USER_TIME_MAP" 2>/dev/null || true

    local now rows line uid remark sni
    now=$(date +"%Y-%m-%d %H:%M")
    rows=$(jq -r '
      .inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") as $in |
      (($in.streamSettings.realitySettings.serverNames[0] // (($in.streamSettings.realitySettings.dest // "www.microsoft.com:443") | split(":")[0]))) as $sni |
      $in.settings.clients[]? | [.id, (.email // "legacy"), $sni] | @tsv
    ' "$CONFIG" 2>/dev/null || true)

    while IFS=$'\t' read -r uid remark sni; do
        test -n "${uid:-}" || continue
        if ! grep -q "^${uid}|" "$USER_TIME_MAP" 2>/dev/null; then
            echo "${uid}|${now}" >> "$USER_TIME_MAP"
        fi
        if test -n "${sni:-}" && ! grep -q "^${uid}|" "$USER_SNI_MAP" 2>/dev/null; then
            echo "${uid}|${sni}" >> "$USER_SNI_MAP"
        fi
    done <<< "$rows"
}


apply_hotupdate_fast_sysctl() {
    title "热更新极速网络栈参数（非重装、可重复执行）"
    mkdir -p /etc/sysctl.d 2>/dev/null || true
    local adv app qdisc
    # V198e52: 热更新默认固化你实测稳定的高 RTT 代理窗口组合。
    adv=1
    app=31
    qdisc=$(choose_best_qdisc)

    cat > /etc/sysctl.d/99-xray-hotupdate-fast.conf <<EOF_SYSCTL
net.core.default_qdisc = ${qdisc}
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = ${adv}
net.ipv4.tcp_app_win = ${app}
net.ipv4.tcp_moderate_rcvbuf = 1
net.core.rmem_default = 3990577
net.core.wmem_default = 3990577
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 3990577 67108864
net.ipv4.tcp_wmem = 4096 3990577 67108864
net.ipv4.udp_rmem_min = 4096
net.ipv4.udp_wmem_min = 4096
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.core.rps_sock_flow_entries = 131072
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 12
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_fastopen = 0
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.ip_forward = 0
net.ipv4.conf.all.forwarding = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
vm.swappiness = 10
vm.vfs_cache_pressure = 50
fs.file-max = 1048576
fs.nr_open = 1048576
EOF_SYSCTL

    local log="/tmp/xray-hotupdate-sysctl.log"
    if sysctl -p /etc/sysctl.d/99-xray-hotupdate-fast.conf >"$log" 2>&1; then
        info "热更新极速网络栈参数已应用。"
        rm -f "$log" 2>/dev/null || true
    else
        warn "部分热更新 Sysctl 参数不被当前内核支持，已跳过不兼容项。详情: $log"
    fi

    modprobe iptable_mangle >/dev/null 2>&1 || true
    modprobe xt_TCPMSS >/dev/null 2>&1 || true
    iptables -t mangle -C POSTROUTING -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || \
        iptables -t mangle -A POSTROUTING -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
}

enable_dnsmasq_cache_safely() {
    # V198e52: 默认启用 dnsmasq，但必须通过监听与解析验证后才接管 resolv.conf。
    # 任一步失败均回退静态 DNS，避免重演 nameserver 127.0.0.1 但 53 端口无人监听的断网问题。
    title "安全启用 Dnsmasq 本地极速缓存（失败自动回退）"
    repair_dns_if_broken
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || yum makecache -y >/dev/null 2>&1 || true
    apt-get install -y dnsmasq >/dev/null 2>&1 || yum install -y dnsmasq >/dev/null 2>&1 || true

    if ! command -v dnsmasq >/dev/null 2>&1; then
        warn "dnsmasq 未安装成功，保持静态 DNS。"
        write_static_resolv_conf
        return 0
    fi

    systemctl stop systemd-resolved 2>/dev/null || true
    systemctl disable systemd-resolved 2>/dev/null || true
    systemctl stop resolvconf 2>/dev/null || true
    systemctl disable resolvconf 2>/dev/null || true

    cat > /etc/dnsmasq.conf <<'EOF_DNSMASQ_V38'
port=53
listen-address=127.0.0.1
bind-interfaces
cache-size=20000
min-cache-ttl=300
max-cache-ttl=86400
neg-ttl=60
all-servers
server=1.1.1.1
server=1.0.0.1
server=8.8.8.8
server=208.67.222.222
no-resolv
no-poll
domain-needed
bogus-priv
dns-forward-max=1024
EOF_DNSMASQ_V38

    systemctl enable dnsmasq >/dev/null 2>&1 || true
    if systemctl restart dnsmasq >/dev/null 2>&1 && dns_local_listener_ok; then
        chattr -i /etc/resolv.conf 2>/dev/null || true
        cp -a /etc/resolv.conf "$BACKUP_DIR/resolv.conf.before-dnsmasq.$(date +%Y%m%d_%H%M%S).bak" 2>/dev/null || true
        echo "nameserver 127.0.0.1" > /etc/resolv.conf
        chmod 644 /etc/resolv.conf 2>/dev/null || true
        if getent hosts api.ipify.org >/dev/null 2>&1 || getent hosts google.com >/dev/null 2>&1; then
            _safe_jq_write '.dns = {"servers":["127.0.0.1"], "queryStrategy":"UseIPv4"}' >/dev/null 2>&1 || true
            info "dnsmasq 已启用并接管本机解析。"
            return 0
        fi
    fi

    warn "dnsmasq 未通过监听/解析验证，自动回退静态 DNS。"
    systemctl stop dnsmasq >/dev/null 2>&1 || true
    systemctl disable dnsmasq >/dev/null 2>&1 || true
    write_static_resolv_conf
    _safe_jq_write '.dns = {"servers":["https://1.1.1.1/dns-query","https://208.67.222.222/dns-query","https://doh.opendns.com/dns-query"], "queryStrategy":"UseIPv4"}' >/dev/null 2>&1 || true
    return 0
}

apply_txqueue_3000_default() {
    # V198e52: 默认 3000，不再用 12000，避免队列过深导致排队延迟和 bufferbloat。
    local IP_CMD IFACE
    IP_CMD=$(command -v ip || echo "")
    test -n "$IP_CMD" || return 0
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    test -n "$IFACE" || return 0
    $IP_CMD link set "$IFACE" txqueuelen 3000 2>/dev/null || true
    cat > /etc/systemd/system/txqueue.service <<EOF_TXQ_V38
[Unit]
Description=Set TX Queue Length for Stable Low Latency
After=network.target

[Service]
Type=oneshot
ExecStart=$IP_CMD link set $IFACE txqueuelen 3000
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF_TXQ_V38
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable txqueue >/dev/null 2>&1 || true
    systemctl restart txqueue >/dev/null 2>&1 || true
}

enable_thp_never_default() {
    # 网络代理低延迟优先：THP 默认关闭，降低延迟毛刺。
    if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
        echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
    fi
    if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
        echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true
    fi
    update_hw_boot_script >/dev/null 2>&1 || true
}

enable_cpu_performance_default() {
    # VPS 不支持 cpufreq 时静默跳过。
    local touched=0 cpu
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if test -f "$cpu"; then
            echo performance > "$cpu" 2>/dev/null || true
            touched=1
        fi
    done
    if test "$touched" -eq 1; then update_hw_boot_script >/dev/null 2>&1 || true; fi
}


enable_zram_default() {
    # e52：ZRAM 开启同时执行总 Swap 上限 1024MB；ZRAM 可用时删除 /swapfile，避免 2GB+ Swap。
    enforce_swap_cap_1024_e52
}


enable_journald_volatile_default() {
    local conf="/etc/systemd/journald.conf"
    test -f "$conf" || return 0
    cp -a "$conf" "$BACKUP_DIR/journald.conf.$(date +%Y%m%d_%H%M%S).bak" 2>/dev/null || true
    if grep -q '^Storage=' "$conf" 2>/dev/null; then
        sed -i 's/^Storage=.*/Storage=volatile/' "$conf" 2>/dev/null || true
    elif grep -q '^#Storage=' "$conf" 2>/dev/null; then
        sed -i 's/^#Storage=.*/Storage=volatile/' "$conf" 2>/dev/null || true
    else
        echo 'Storage=volatile' >> "$conf"
    fi
    systemctl restart systemd-journald >/dev/null 2>&1 || true
}




get_xray_listen_ports() {
    local ports=""
    if test -f "$CONFIG" && command -v jq >/dev/null 2>&1; then
        ports=$(jq -r '.inbounds[]? | select(.port != null) | .port' "$CONFIG" 2>/dev/null | awk '/^[0-9]+$/ && $1>=1 && $1<=65535 {print $1}' | sort -n | uniq || true)
    fi
    if test -z "$ports" && [[ "${LISTEN_PORT:-}" =~ ^[0-9]+$ ]]; then ports="$LISTEN_PORT"; fi
    if test -z "$ports"; then ports="443"; fi
    echo "$ports"
}

get_ssh_listen_ports() {
    local ports=""
    # V198e52: 优先从当前监听态识别 SSH 端口，避免 sshd_config 使用 Include/云镜像改名时误判为 22。
    ports=$(ss -H -tlnp 2>/dev/null | awk '
        /sshd/ {
            a=$4
            gsub(/\[|\]/, "", a)
            sub(/^.*:/, "", a)
            if (a ~ /^[0-9]+$/ && a>=1 && a<=65535) print a
        }' | sort -n | uniq || true)

    if test -z "$ports" && test -f /etc/ssh/sshd_config; then
        ports=$(awk 'BEGIN{IGNORECASE=1} /^[[:space:]]*Port[[:space:]]+[0-9]+/ {print $2}' /etc/ssh/sshd_config 2>/dev/null | awk '/^[0-9]+$/ && $1>=1 && $1<=65535 {print $1}' | sort -n | uniq || true)
    fi

    if test -z "$ports"; then ports="22"; fi
    echo "$ports"
}

origin_guard_status() {
    title "Origin Guard 入口防滥用状态"
    if systemctl is-active --quiet xray-origin-guard.service 2>/dev/null; then
        info "xray-origin-guard.service 正在运行。"
    else
        warn "xray-origin-guard.service 未运行。"
    fi
    echo -e "\n${cyan}【受保护 Xray 端口】${none}"
    if test -f "$SCRIPT_DIR/guard_ports.conf"; then sed 's/^/  - /' "$SCRIPT_DIR/guard_ports.conf"; else get_xray_listen_ports | sed 's/^/  - /'; fi
    echo -e "\n${cyan}【iptables v4 摘要】${none}"
    iptables -S XRAY_ORIGIN_GUARD 2>/dev/null | sed 's/^/  /' || warn "未发现 IPv4 Guard 链。"
    echo -e "\n${cyan}【iptables v6 摘要】${none}"
    ip6tables -S XRAY_ORIGIN_GUARD 2>/dev/null | sed 's/^/  /' || true
    local _p=""; read -rp "按 Enter 返回..." _p || true
}

remove_origin_guard() {
    local mode="${1:-manual}"
    title "移除 Origin Guard 入口防滥用规则"
    systemctl stop xray-origin-guard.service >/dev/null 2>&1 || true
    systemctl disable xray-origin-guard.service >/dev/null 2>&1 || true
    if test -x /usr/local/bin/xray-origin-guard.sh; then
        /usr/local/bin/xray-origin-guard.sh remove >/dev/null 2>&1 || true
    else
        iptables -D INPUT -j XRAY_ORIGIN_GUARD 2>/dev/null || true
        iptables -F XRAY_ORIGIN_GUARD 2>/dev/null || true
        iptables -X XRAY_ORIGIN_GUARD 2>/dev/null || true
        ip6tables -D INPUT -j XRAY_ORIGIN_GUARD 2>/dev/null || true
        ip6tables -F XRAY_ORIGIN_GUARD 2>/dev/null || true
        ip6tables -X XRAY_ORIGIN_GUARD 2>/dev/null || true
    fi
    rm -f /etc/systemd/system/xray-origin-guard.service /usr/local/bin/xray-origin-guard.sh "$SCRIPT_DIR/guard_ports.conf" "$SCRIPT_DIR/guard_ssh_ports.conf" 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    info "Origin Guard 已移除。"
    if test "$mode" != "auto"; then local _p=""; read -rp "按 Enter 返回..." _p || true; fi
}

install_origin_guard() {
    local mode="${1:-manual}"
    title "Origin Guard：防止 VPS 被当成 Cloudflare CDN 源站 / 明文 HTTP 源站 / 扫描器流量池"

    local ports
    ports="$(get_xray_listen_ports)"
    local ssh_ports
    ssh_ports="$(get_ssh_listen_ports)"
    mkdir -p "$SCRIPT_DIR" 2>/dev/null || true
    printf "%s\n" $ports | awk '/^[0-9]+$/ && $1>=1 && $1<=65535 {print $1}' | sort -n | uniq > "$SCRIPT_DIR/guard_ports.conf"
    printf "%s\n" $ssh_ports | awk '/^[0-9]+$/ && $1>=1 && $1<=65535 {print $1}' | sort -n | uniq > "$SCRIPT_DIR/guard_ssh_ports.conf"

    echo -e "  将保护的 Xray 端口: ${cyan}$(tr '\n' ' ' < "$SCRIPT_DIR/guard_ports.conf")${none}"
    echo -e "  将放行的 SSH 端口:  ${cyan}$(tr '\n' ' ' < "$SCRIPT_DIR/guard_ssh_ports.conf")${none}"
    echo -e "  策略: 阻断 Cloudflare 官方代理来源访问 Xray 端口、阻断常见 CF 源站端口、限制单 IP 新建连接、拒绝明文 HTTP 方法探测。"
    if test "$mode" != "auto"; then
        local confirm=""
        read -rp "确认写入并启用 Origin Guard？(y/N): " confirm || true
        if [[ ! "$confirm" =~ ^[yY]$ ]]; then return 0; fi
    fi

    cat > /usr/local/bin/xray-origin-guard.sh <<'GUARDSH'
#!/usr/bin/env bash
set -u
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

PORT_FILE="/usr/local/etc/xray-script/guard_ports.conf"
SSH_FILE="/usr/local/etc/xray-script/guard_ssh_ports.conf"
CHAIN="XRAY_ORIGIN_GUARD"
COMMON_CF_PORTS="80 8080 8880 2052 2053 2082 2083 2086 2087 2095 2096 8443"
CF4_URL="https://www.cloudflare.com/ips-v4"
CF6_URL="https://www.cloudflare.com/ips-v6"

read_list() {
    local f="$1"
    if test -f "$f"; then
        awk '/^[0-9]+$/ && $1>=1 && $1<=65535 {print $1}' "$f" | sort -n | uniq
    fi
}

in_list() {
    local x="$1"; shift
    local i
    for i in "$@"; do test "$x" = "$i" && return 0; done
    return 1
}

ipt4() { command -v iptables >/dev/null 2>&1 && iptables "$@" 2>/dev/null || true; }
ipt6() { command -v ip6tables >/dev/null 2>&1 && ip6tables "$@" 2>/dev/null || true; }

remove_family() {
    local bin="$1"
    command -v "$bin" >/dev/null 2>&1 || return 0
    while "$bin" -D INPUT -j "$CHAIN" 2>/dev/null; do :; done
    "$bin" -F "$CHAIN" 2>/dev/null || true
    "$bin" -X "$CHAIN" 2>/dev/null || true
}

apply_family_v4() {
    command -v iptables >/dev/null 2>&1 || return 0
    iptables -N "$CHAIN" 2>/dev/null || iptables -F "$CHAIN" 2>/dev/null || true
    iptables -C INPUT -j "$CHAIN" 2>/dev/null || iptables -I INPUT 1 -j "$CHAIN" 2>/dev/null || true

    ipt4 -A "$CHAIN" -i lo -j RETURN
    ipt4 -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN

    local p
    for p in "${SSH_PORTS[@]}"; do
        ipt4 -A "$CHAIN" -p tcp --dport "$p" -j RETURN
    done

    local tmp4="/tmp/cloudflare-ips-v4.$$"
    if command -v curl >/dev/null 2>&1 && curl -fsSL --connect-timeout 5 --max-time 15 "$CF4_URL" -o "$tmp4" 2>/dev/null; then
        while read -r cidr; do
            test -n "$cidr" || continue
            for p in "${XRAY_PORTS[@]}"; do
                ipt4 -A "$CHAIN" -p tcp -s "$cidr" --dport "$p" -j REJECT --reject-with tcp-reset
            done
        done < "$tmp4"
    fi
    rm -f "$tmp4" 2>/dev/null || true

    local cp
    for cp in $COMMON_CF_PORTS; do
        in_list "$cp" "${XRAY_PORTS[@]}" && continue
        in_list "$cp" "${SSH_PORTS[@]}" && continue
        ipt4 -A "$CHAIN" -p tcp --dport "$cp" -j REJECT --reject-with tcp-reset
    done

    for p in "${XRAY_PORTS[@]}"; do
        ipt4 -A "$CHAIN" -p tcp --dport "$p" -m string --algo bm --string "GET " -j REJECT --reject-with tcp-reset
        ipt4 -A "$CHAIN" -p tcp --dport "$p" -m string --algo bm --string "POST " -j REJECT --reject-with tcp-reset
        ipt4 -A "$CHAIN" -p tcp --dport "$p" -m string --algo bm --string "HEAD " -j REJECT --reject-with tcp-reset
        ipt4 -A "$CHAIN" -p tcp --dport "$p" -m string --algo bm --string "Host:" -j REJECT --reject-with tcp-reset
        ipt4 -A "$CHAIN" -p tcp --dport "$p" -m conntrack --ctstate NEW -m connlimit --connlimit-above 96 --connlimit-mask 32 -j REJECT --reject-with tcp-reset
        ipt4 -A "$CHAIN" -p tcp --dport "$p" -m conntrack --ctstate NEW -m hashlimit --hashlimit-mode srcip --hashlimit-name "xray_${p}_new" --hashlimit-above 120/minute --hashlimit-burst 240 -j DROP
        ipt4 -A "$CHAIN" -p tcp --dport "$p" -j RETURN
    done

    ipt4 -A "$CHAIN" -j RETURN
}

apply_family_v6() {
    command -v ip6tables >/dev/null 2>&1 || return 0
    ip6tables -N "$CHAIN" 2>/dev/null || ip6tables -F "$CHAIN" 2>/dev/null || true
    ip6tables -C INPUT -j "$CHAIN" 2>/dev/null || ip6tables -I INPUT 1 -j "$CHAIN" 2>/dev/null || true

    ipt6 -A "$CHAIN" -i lo -j RETURN
    ipt6 -A "$CHAIN" -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN

    local p
    for p in "${SSH_PORTS[@]}"; do
        ipt6 -A "$CHAIN" -p tcp --dport "$p" -j RETURN
    done

    local tmp6="/tmp/cloudflare-ips-v6.$$"
    if command -v curl >/dev/null 2>&1 && curl -fsSL --connect-timeout 5 --max-time 15 "$CF6_URL" -o "$tmp6" 2>/dev/null; then
        while read -r cidr; do
            test -n "$cidr" || continue
            for p in "${XRAY_PORTS[@]}"; do
                ipt6 -A "$CHAIN" -p tcp -s "$cidr" --dport "$p" -j REJECT --reject-with tcp-reset
            done
        done < "$tmp6"
    fi
    rm -f "$tmp6" 2>/dev/null || true

    local cp
    for cp in $COMMON_CF_PORTS; do
        in_list "$cp" "${XRAY_PORTS[@]}" && continue
        in_list "$cp" "${SSH_PORTS[@]}" && continue
        ipt6 -A "$CHAIN" -p tcp --dport "$cp" -j REJECT --reject-with tcp-reset
    done

    for p in "${XRAY_PORTS[@]}"; do
        ipt6 -A "$CHAIN" -p tcp --dport "$p" -m string --algo bm --string "GET " -j REJECT --reject-with tcp-reset
        ipt6 -A "$CHAIN" -p tcp --dport "$p" -m string --algo bm --string "POST " -j REJECT --reject-with tcp-reset
        ipt6 -A "$CHAIN" -p tcp --dport "$p" -m string --algo bm --string "HEAD " -j REJECT --reject-with tcp-reset
        ipt6 -A "$CHAIN" -p tcp --dport "$p" -m string --algo bm --string "Host:" -j REJECT --reject-with tcp-reset
        ipt6 -A "$CHAIN" -p tcp --dport "$p" -m conntrack --ctstate NEW -m connlimit --connlimit-above 96 --connlimit-mask 64 -j REJECT --reject-with tcp-reset
        ipt6 -A "$CHAIN" -p tcp --dport "$p" -m conntrack --ctstate NEW -m hashlimit --hashlimit-mode srcip --hashlimit-name "xray6_${p}_new" --hashlimit-above 120/minute --hashlimit-burst 240 -j DROP
        ipt6 -A "$CHAIN" -p tcp --dport "$p" -j RETURN
    done

    ipt6 -A "$CHAIN" -j RETURN
}

ACTION="${1:-apply}"
mapfile -t XRAY_PORTS < <(read_list "$PORT_FILE")
mapfile -t SSH_PORTS < <(read_list "$SSH_FILE")
test "${#XRAY_PORTS[@]}" -gt 0 || XRAY_PORTS=(443)
test "${#SSH_PORTS[@]}" -gt 0 || SSH_PORTS=(22)

case "$ACTION" in
    apply|start)
        remove_family iptables
        remove_family ip6tables
        apply_family_v4
        apply_family_v6
        ;;
    remove|stop)
        remove_family iptables
        remove_family ip6tables
        ;;
    status)
        iptables -S "$CHAIN" 2>/dev/null || true
        ip6tables -S "$CHAIN" 2>/dev/null || true
        ;;
    *)
        echo "Usage: $0 {apply|remove|status}" >&2
        exit 2
        ;;
esac
GUARDSH
    chmod +x /usr/local/bin/xray-origin-guard.sh 2>/dev/null || true

    cat > /etc/systemd/system/xray-origin-guard.service << 'EOF'
[Unit]
Description=Xray Origin Guard anti-abuse firewall
After=network-online.target xray.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/xray-origin-guard.sh apply
ExecStop=/usr/local/bin/xray-origin-guard.sh remove
RemainAfterExit=yes
TimeoutSec=45

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable xray-origin-guard.service >/dev/null 2>&1 || true
    if systemctl restart xray-origin-guard.service >/dev/null 2>&1; then
        info "Origin Guard 已启用：Cloudflare CDN 代理来源、明文 HTTP 探测和异常新建连接将被收敛。"
    else
        warn "Origin Guard 服务启动失败，可能是系统缺少 iptables 扩展模块。你可在状态菜单查看详情。"
        systemctl status xray-origin-guard.service --no-pager -n 20 2>/dev/null || true
    fi

    if test "$mode" != "auto"; then
        local _p=""; read -rp "按 Enter 返回..." _p || true
    fi
}

harden_xray_reality_profile() {
    if test ! -f "$CONFIG" || ! command -v jq >/dev/null 2>&1; then return 0; fi
    _safe_jq_write '
      .log.access = "none" |
      .log.error = "none" |
      .log.loglevel = "warning" |
      .routing.domainStrategy = "AsIs" |
      .routing.domainMatcher = "mph" |
      (.inbounds[]? | select(.protocol=="vless" and .streamSettings.security=="reality") | .streamSettings.realitySettings.show) = false |
      (.inbounds[]? | select(.protocol=="vless" and .streamSettings.security=="reality") | .streamSettings.realitySettings.maxTimeDiff) = 60000 |
      (.inbounds[]? | select(.protocol=="vless" and .streamSettings.security=="reality") | .streamSettings.realitySettings.limitFallbackUpload) = {"afterBytes":0,"bytesPerSec":0,"burstBytesPerSec":0} |
      (.inbounds[]? | select(.protocol=="vless" and .streamSettings.security=="reality") | .streamSettings.realitySettings.limitFallbackDownload) = {"afterBytes":0,"bytesPerSec":0,"burstBytesPerSec":0} |
      (.inbounds[]? | select(.protocol=="vless" and .streamSettings.security=="reality") | .settings.decryption) = "none" |
      (.inbounds[]? | select(.protocol=="vless" and .streamSettings.security=="reality") | .settings.clients[]?.flow) = "xtls-rprx-vision" |
      (.inbounds[]? | select(.protocol=="vless" and .streamSettings.security=="reality") | .sniffing.enabled) = true |
      (.inbounds[]? | select(.protocol=="vless" and .streamSettings.security=="reality") | .sniffing.metadataOnly) = true |
      (.inbounds[]? | select(.protocol=="vless" and .streamSettings.security=="reality") | .sniffing.routeOnly) = true
    ' >/dev/null 2>&1 || true
}


_global_block_rules() {
    while true; do
        title "安全防火墙体系设定"
        if test ! -f "$CONFIG"; then error "未解析到配置。"; return; fi
        local bt_en=$(jq -r '.routing.rules[]? | select(.protocol != null) | select(.protocol | index("bittorrent")) | ._enabled // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        local ad_en=$(jq -r '.routing.rules[]? | select(.domain != null) | select(.domain | index("geosite:category-ads-all")) | ._enabled // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        local og_state="${red}未运行${none}"
        if systemctl is-active --quiet xray-origin-guard.service 2>/dev/null; then og_state="${green}运行中${none}"; fi

        echo -e "  1) P2P/BT 协议强力阻隔控制          | 目前状态: ${yellow}${bt_en}${none}"
        echo -e "  2) Geosite 黑名单与流氓广告过滤     | 目前状态: ${yellow}${ad_en}${none}"
        echo -e "  3) Origin Guard 防 CDN 源站滥用     | 目前状态: ${og_state}"
        echo "  4) 查看 Origin Guard 当前规则"
        echo "  5) 移除 Origin Guard 防火墙规则"
        echo "  6) 重新固化 Reality 隐稳配置"
        echo "  0) 退出返回"

        local bc=""; read -rp "请下达开关指令: " bc || true
        case "${bc:-}" in
            1) local nv="true"; if test "$bt_en" = "true"; then nv="false"; fi; _safe_jq_write --argjson nv_val "$nv" '(.routing.rules[]? | select(.protocol != null and (.protocol | index("bittorrent")))) |= (._enabled = $nv_val)'; ensure_xray_is_alive; info "BT 协议阻断墙修改为: $nv" ;;
            2) local nv="true"; if test "$ad_en" = "true"; then nv="false"; fi; _safe_jq_write --argjson nv_val "$nv" '(.routing.rules[]? | select(.domain != null and (.domain | index("geosite:category-ads-all")))) |= (._enabled = $nv_val)'; ensure_xray_is_alive; info "黑洞过滤系统修改为: $nv" ;;
            3) install_origin_guard ;;
            4) origin_guard_status ;;
            5) remove_origin_guard ;;
            6) harden_xray_reality_profile; ensure_xray_is_alive; info "Reality 隐稳参数已重新固化。"; local _p=""; read -rp "按 Enter 返回..." _p || true ;;
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
    echo "$SNI_JSON_ARRAY" > /tmp/sni_array.json
    _safe_jq_write --arg dest "$BEST_SNI:443" --slurpfile snis /tmp/sni_array.json '
        (.inbounds[]? | select(. != null) | select(.protocol == "vless")) |= (
            .streamSettings.realitySettings.serverNames = $snis[0] |
            .streamSettings.realitySettings.dest = $dest
        )'
    rm -f /tmp/sni_array.json 2>/dev/null || true
    harden_xray_reality_profile
    if systemctl is-enabled --quiet xray-origin-guard.service 2>/dev/null; then install_origin_guard auto; fi
    ensure_xray_is_alive; info "网络架构及反识别面具重构完毕，隐稳参数与入口守卫已同步刷新。"
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
{ "log": { "loglevel": "warning", "access": "none", "error": "none" }, "routing": { "domainStrategy": "AsIs", "domainMatcher": "mph", "rules": [ { "outboundTag": "block", "_enabled": true, "protocol": ["bittorrent"] }, { "outboundTag": "block", "_enabled": true, "domain": ["geosite:category-ads-all"] } ] }, "dns": { "servers": ["https://1.1.1.1/dns-query", "https://208.67.222.222/dns-query"], "queryStrategy": "UseIPv4" }, "policy": { "levels": { "0": { "handshake": 3, "connIdle": 260, "uplinkOnly": 2, "downlinkOnly": 5 } }, "system": { "statsInboundDownlink": false, "statsInboundUplink": false } }, "inbounds": [], "outbounds": [ { "protocol": "freedom", "tag": "direct", "settings": {"domainStrategy": "AsIs"}, "streamSettings": { "sockopt": { "tcpNoDelay": true, "tcpFastOpen": false, "tcpKeepAliveIdle": 30, "tcpKeepAliveInterval": 15 } } }, { "protocol": "blackhole", "tag": "block" } ] }
EOF

    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        local keys=$("$XRAY_BIN" x25519 2>/dev/null || echo ""); local priv=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' \r\n' || echo ""); local pub=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' \r\n' || echo ""); local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid); local sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n\r' || echo ""); local ctime=$(date +"%Y-%m-%d %H:%M")
        echo "$pub" > "$PUBKEY_FILE"; echo "$uuid|$ctime" > "$USER_TIME_MAP"; echo "$SNI_JSON_ARRAY" > /tmp/sni_array.json
        cat > /tmp/vless_inbound.json <<EOF
{ "tag": "vless-reality", "listen": "0.0.0.0", "port": $LISTEN_PORT, "protocol": "vless", "settings": { "clients": [ {"id": "$uuid", "flow": "xtls-rprx-vision", "email": "$REMARK_NAME"} ], "decryption": "none" }, "streamSettings": { "network": "tcp", "security": "reality", "sockopt": {"tcpNoDelay": true, "tcpFastOpen": false, "tcpKeepAliveIdle": 30, "tcpKeepAliveInterval": 15}, "realitySettings": { "show": false, "dest": "$BEST_SNI:443", "serverNames": [], "privateKey": "$priv", "publicKey": "$pub", "shortIds": ["$sid"], "maxTimeDiff": 60000, "limitFallbackUpload": {"afterBytes": 0, "bytesPerSec": 0, "burstBytesPerSec": 0}, "limitFallbackDownload": {"afterBytes": 0, "bytesPerSec": 0, "burstBytesPerSec": 0} } }, "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"], "metadataOnly": true, "routeOnly": true } }
EOF
        _safe_jq_write --slurpfile snis /tmp/sni_array.json --slurpfile vless_tmp /tmp/vless_inbound.json '.inbounds += [ $vless_tmp[0] | .streamSettings.realitySettings.serverNames = $snis[0] ]'
        rm -f /tmp/vless_inbound.json /tmp/sni_array.json 2>/dev/null || true
    fi

    if test "$proto_choice" = "2" || test "$proto_choice" = "3"; then
        cat > /tmp/ss_inbound.json <<EOF
{ "tag": "shadowsocks", "listen": "0.0.0.0", "port": $ss_port, "protocol": "shadowsocks", "settings": { "method": "$ss_method", "password": "$ss_pass", "network": "tcp,udp" }, "streamSettings": { "sockopt": {"tcpNoDelay": true, "tcpFastOpen": false, "tcpKeepAliveIdle": 30, "tcpKeepAliveInterval": 15} }, "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"], "metadataOnly": true, "routeOnly": true } }
EOF
        _safe_jq_write --slurpfile ss_tmp /tmp/ss_inbound.json '.inbounds += [ $ss_tmp[0] ]'
        rm -f /tmp/ss_inbound.json 2>/dev/null || true
    fi

    fix_permissions; systemctl enable xray >/dev/null 2>&1 || true
    if ensure_xray_is_alive; then harden_xray_reality_profile; remove_origin_guard auto >/dev/null 2>&1 || true; info "所有架构配置装载确认生效！通讯网络已打开。Origin Guard 默认不自动启用，避免重启后误伤真实链路。"; do_summary; else error "贯通服务进程失败，请检查日志。"; return 1; fi
    finalize
    while true; do local opt=""; read -rp "按 Enter 返回，亦或输入 b 即刻执行 SNI 的漂移: " opt || true; if test "$opt" = "b" || test "$opt" = "B"; then if choose_sni; then _update_matrix; do_summary; else break; fi; else break; fi; done
}

do_uninstall() {
    title "终极断供清理器：彻底摧毁当前生态环境并回卷"
    local confirm=""; read -rp "此指令将摧毁私钥及配置 (网卡保留)，您明确此行为吗？(y/n): " confirm || true
    if test "$confirm" != "y"; then return; fi
    info "开始核心粉碎..."
    remove_origin_guard auto >/dev/null 2>&1 || true
    systemctl stop dnsmasq >/dev/null 2>&1 || true; systemctl disable dnsmasq >/dev/null 2>&1 || true; export DEBIAN_FRONTEND=noninteractive; apt-get purge -y dnsmasq >/dev/null 2>&1 || true
    chattr -i /etc/resolv.conf 2>/dev/null || true; if test -f /etc/resolv.conf.bak; then mv -f /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true; fi
    systemctl stop resolvconf.service >/dev/null 2>&1 || true; systemctl disable resolvconf.service >/dev/null 2>&1 || true
    if systemctl list-unit-files | grep -q systemd-resolved 2>/dev/null; then systemctl enable systemd-resolved >/dev/null 2>&1 || true; systemctl start systemd-resolved >/dev/null 2>&1 || true; fi
    systemctl stop xray >/dev/null 2>&1 || true; systemctl disable xray >/dev/null 2>&1 || true; rm -rf /etc/systemd/system/xray* /lib/systemd/system/xray* >/dev/null 2>&1 || true; systemctl daemon-reload >/dev/null 2>&1 || true
    rm -rf "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SCRIPT_DIR" /var/log/xray* /usr/local/bin/xrv "$SCRIPT_PATH" >/dev/null 2>&1 || true
    local temp_cron=$(mktemp /tmp/cron_XXXXXX) || true; if test -f "$temp_cron"; then crontab -l 2>/dev/null | grep -v "update-dat.sh" | grep -v "systemctl restart xray" | grep -v "cc1.sh" > "$temp_cron" || true; crontab "$temp_cron" 2>/dev/null || true; rm -f "$temp_cron" 2>/dev/null || true; fi
    info "物理痕迹及配置文件已完全格式化，现网回归系统纯净初始状态！"; exit 0
}

do_sys_init_menu() {
    while true; do
        clear
        title "环境底层组件拉齐与结构重建区 (V198e52 稳态极速版)"
        echo "  1) [一键全清] 执行 Linux 强基更新、亚太时间轴校准并置入极客 1GB 内存交换区"
        echo "  2) [系统防御] 强行修改源头 DNS 解析 (注入 resolvconf，免脱轨断联)"
        echo -e "  ${cyan}3) [重构内脏] 双轨飞升：官方 APT 预编译直装 或 极客全量源码锻造${none}"
        echo "  4) [网络底层] TX Queue 网卡出站队列防拥堵极限缩减 (配置为 3000 稳态低延迟)"
        echo "  5) [极限压榨] 全域系统底层网络栈结构重塑 (Limits + Sysctl + MSS钳制)"
        echo "  6) [上帝微操] 应用层及系统内核层双轨 25 项神级优化全控板 (Dnsmasq/CAKE)"
        echo -e "  ${cyan}7) [极度发烧] 深入 CAKE 高级模型配置 (设定 Diffserv 调度、物理带宽上限)${none}"
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
                
                print_magenta ">>> 同步系统时间（不强制改时区，避免影响日志/审计/计划任务）..."
                if command -v timedatectl >/dev/null 2>&1; then timedatectl set-ntp true >/dev/null 2>&1 || true; fi
                if command -v ntpdate >/dev/null 2>&1; then ntpdate -u pool.ntp.org >/dev/null 2>&1 || true; fi
                if command -v hwclock >/dev/null 2>&1; then hwclock --systohc >/dev/null 2>&1 || true; fi
                info "系统时间已同步，保留原有时区设置。"
                
                check_and_create_swap
                
                print_magenta ">>> 初始化暗核清理器 cc1.sh ..."
                cat <<'EOF' > /usr/local/bin/cc1.sh
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get clean >/dev/null 2>&1 || true
apt-get autoremove -y --purge >/dev/null 2>&1 || true
journalctl --vacuum-time=3d >/dev/null 2>&1 || true
rm -rf /tmp/sni_array.json /tmp/vless_inbound.json /tmp/ss_inbound.json /tmp/xray_users*.txt /tmp/sni_test.* /var/cache/apt/archives/* 2>/dev/null || true
journalctl --vacuum-size=100M >/dev/null 2>&1 || true
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
            3) do_kernel_compile_menu ;;
            4) do_txqueuelen_opt ;;
            5) do_perf_tuning ;;
            6) do_app_level_tuning_menu ;;
            7) config_cake_advanced ;;
            0) return ;;
        esac
    done
}

main_menu() {
    while true; do
        clear
        echo -e "${blue}======================================================================${none}"
        echo -e "  ${magenta}Xray System Advanced Management V198e52 - (The Apex Vanguard)${none}"
        
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        if test "$svc" = "active"; then svc="${green}平稳在线 (Running)${none}"; else svc="${red}离线静默 (Stopped)${none}"; fi
        local sys_ver=$(uname -r 2>/dev/null || echo "未探测到数据")
        echo -e "  引擎态势: $svc | 全局快捷指令: ${cyan}xrv${none} | 外部识别 IP: ${yellow}$(_get_ip || echo "探测异常")${none}"
        echo -e "  系统装配内核: ${cyan}${sys_ver}${none} | 微架构侦测: x64-v${yellow}$(detect_x86_64_level)${none}"
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
        echo -e "  ${cyan}11) 从 ex198e32/ex198e33/ex198e34/ex198e35/ex198e36/ex198e37/ex198e38/ex198e39/ex198e40/ex198e41/ex198e42/ex198e43 稳态热更新到 V198e52${none}"
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
            11) hot_update_from_legacy ;;
            88) do_uninstall ;;
            0) exit 0 ;;
            *) echo -e "${red}错误拦截：代码解析为空值！${none}"; sleep 1 ;;
        esac
    done
}


rescue_after_v35_breakage() {
    title "V198e52 紧急修复：撤销旧版重启后断流风险项"
    warn "将关闭 Origin Guard、修复 DNS/limits、清理 XRAY_ORIGIN_GUARD 链、写入稳态网络参数、关闭 ECN/TFO，并重启 Xray。"

    remove_origin_guard auto >/dev/null 2>&1 || true
    repair_dns_if_broken
    write_safe_global_limits

    # 兼容手动残留：确保链被清理干净。
    while iptables -D INPUT -j XRAY_ORIGIN_GUARD 2>/dev/null; do :; done
    iptables -F XRAY_ORIGIN_GUARD 2>/dev/null || true
    iptables -X XRAY_ORIGIN_GUARD 2>/dev/null || true
    while ip6tables -D INPUT -j XRAY_ORIGIN_GUARD 2>/dev/null; do :; done
    ip6tables -F XRAY_ORIGIN_GUARD 2>/dev/null || true
    ip6tables -X XRAY_ORIGIN_GUARD 2>/dev/null || true

    mkdir -p /etc/sysctl.d 2>/dev/null || true
    cat > /etc/sysctl.d/99-xray-hotupdate-fast.conf <<'EOF_RESCUE_SYSCTL'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 0
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 1
net.ipv4.tcp_app_win = 31
net.ipv4.tcp_moderate_rcvbuf = 1
net.core.rmem_default = 3990577
net.core.wmem_default = 3990577
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.ipv4.tcp_rmem = 4096 3990577 67108864
net.ipv4.tcp_wmem = 4096 3990577 67108864
net.ipv4.udp_rmem_min = 4096
net.ipv4.udp_wmem_min = 4096
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 12
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_fastopen = 0
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_notsent_lowat = 16384
vm.swappiness = 10
vm.vfs_cache_pressure = 50
fs.file-max = 1048576
fs.nr_open = 1048576
EOF_RESCUE_SYSCTL
    sysctl -p /etc/sysctl.d/99-xray-hotupdate-fast.conf >/dev/null 2>&1 || true

    if test -f "$CONFIG" && command -v jq >/dev/null 2>&1; then
        backup_config
        _safe_jq_write '
          (.outbounds[]? | select(.streamSettings?.sockopt? != null) | .streamSettings.sockopt.tcpFastOpen) = false |
          (.inbounds[]? | select(.streamSettings?.sockopt? != null) | .streamSettings.sockopt.tcpFastOpen) = false |
          (.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.show) = false
        ' >/dev/null 2>&1 || true
    fi

    fix_xray_systemd_limits
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl restart xray >/dev/null 2>&1 || true

    if systemctl is-active --quiet xray; then
        info "紧急修复完成：Xray 正在运行，Origin Guard 已关闭，ECN/TFO 已改为稳态。"
    else
        error "Xray 仍未正常运行，请查看：journalctl -u xray --no-pager -n 80"
        return 1
    fi
}



#==============================================================================
# V198e52 覆盖层：e37/e38 稳态热更新专用
# - NoDelay 与 FastOpen 分离：默认只开 NoDelay，FastOpen 保持关闭
# - GOGC 固定 300
# - Policy connIdle 固定 260s
# - CPU 绑核/GOMAXPROCS 自动检测单核/多核，不再错误锁死单核
# - Dnsmasq 必须监听与解析通过后才接管 resolv.conf
# - THP=never、ZRAM、OOM/Nice/LimitNOFILE/LimitSTACK 默认落地
#==============================================================================

set_or_replace_line() {
    local file="$1" key_regex="$2" line="$3"
    touch "$file" 2>/dev/null || true
    if grep -Eq "$key_regex" "$file" 2>/dev/null; then
        sed -i "s|$key_regex.*|$line|" "$file" 2>/dev/null || true
    else
        echo "$line" >> "$file"
    fi
}

xray_cpu_list() {
    local n="${1:-$(nproc 2>/dev/null || echo 1)}" i out=""
    if ! [[ "$n" =~ ^[0-9]+$ ]] || test "$n" -lt 1 2>/dev/null; then n=1; fi
    for ((i=0;i<n;i++)); do out+="${i} "; done
    echo "${out% }"
}

set_xray_gogc_300() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    mkdir -p "$(dirname "$limit_file")" 2>/dev/null || true
    set_or_replace_line "$limit_file" '^Environment="GOGC=' 'Environment="GOGC=300"'
}



_toggle_affinity_on() { apply_xray_cpu_schedule_default; }
_toggle_affinity_off() { local limit_file="/etc/systemd/system/xray.service.d/limits.conf"; if [ -f "$limit_file" ]; then sed -i '/^CPUAffinity=/d;/^Environment="GOMAXPROCS=/d' "$limit_file" 2>/dev/null || true; systemctl daemon-reload >/dev/null 2>&1 || true; fi; }













#==============================================================================
# V198e52 最终覆盖层：128KB Buffer 单位修正 + systemd 环境变量清理
# 关键原则：config.json 的 policy.levels["0"].bufferSize 单位为 KB；
#           systemd 的 XRAY_RAY_BUFFER_SIZE 单位为 MB，禁止再用它表达 64/128KB。
#==============================================================================




toggle_buffer() {
    # V198e52：只在 config.json 的 KB 单位中切换 64/128，永不再写 systemd MB 环境变量。
    local v=""
    v=$(jq -r '.policy.levels["0"].bufferSize // empty' "$CONFIG" 2>/dev/null || echo "")
    if test "$v" = "128"; then
        warn "正在切回稳态低内存档：64KB。"
        apply_xray_buffer_kb 64
    else
        info "正在切换到吞吐测试档：128KB。"
        apply_xray_buffer_kb 128
    fi
    systemctl restart xray >/dev/null 2>&1 || true
}










#==============================================================================
# V198e52 覆盖修复层：修正 e40 残留状态/持久化问题
# 目标：Policy=260 + Buffer=128KB 强制幂等；禁用 systemd MB 单位 Buffer；
#       默认 FQ，不显示/固化 CAKE 子项残留；极速默认保留 GRO/GSO/TSO。
#==============================================================================
























#==============================================================================
# V198e52 最终覆盖层：去重与幂等化修正
# 目标：
#   1) 彻底禁用 systemd XRAY_RAY_BUFFER_SIZE，统一使用 config.json 的 128KB。
#   2) 修复 26 号菜单反向关闭风险，热更新只做幂等开启。
#   3) Policy=260 / Buffer=128 / NoDelay on / FastOpen off 强制一致。
#   4) 默认 FQ，不保留 CAKE 子项残留 flag。
#   5) 默认保留 GRO/GSO/TSO，避免旧启动脚本继续关闭硬件卸载。
#   6) limits.conf 不重复写 LimitNOFILE/LimitSTACK/Nice/OOM。
#==============================================================================















_turn_on_app() {
    apply_xray_keep_2_to_6_defaults
    set_xray_gogc_300
    fix_xray_systemd_limits
    systemctl daemon-reload >/dev/null 2>&1 || true
}

_get_qdisc_text() {
    local IFACE
    IFACE=$(_get_default_iface)
    if test -n "$IFACE" && command -v tc >/dev/null 2>&1; then tc qdisc show dev "$IFACE" 2>/dev/null || true; fi
}

check_cake_state() {
    local q default_qdisc
    q=$(_get_qdisc_text)
    if echo "$q" | grep -Eq '(^| )root (cake|.* cake )'; then echo "true"; return; fi
    default_qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "")
    if test "$default_qdisc" = "cake"; then echo "true"; else echo "false"; fi
}




toggle_cake_qdisc() {
    local IFACE conf
    IFACE=$(_get_default_iface)
    conf="/etc/sysctl.d/99-network-optimized.conf"
    if test -z "$IFACE"; then return; fi
    if test "$(check_cake_state)" = "true"; then
        apply_fq_qdisc_default
    else
        mkdir -p /etc/modules-load.d 2>/dev/null || true
        echo "sch_cake" > /etc/modules-load.d/cake.conf 2>/dev/null || true
        modprobe sch_cake >/dev/null 2>&1 || true
        mkdir -p /etc/sysctl.d 2>/dev/null || true
        if test -f "$conf" && grep -q '^net.core.default_qdisc' "$conf" 2>/dev/null; then
            sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = cake/' "$conf" 2>/dev/null || true
        else
            echo 'net.core.default_qdisc = cake' >> "$conf"
        fi
        sysctl -w net.core.default_qdisc=cake >/dev/null 2>&1 || true
        _apply_cake_live
    fi
    update_hw_boot_script
}

toggle_cake_flag() {
    local flag="$1"
    mkdir -p "$FLAGS_DIR" 2>/dev/null || true
    if test "$(check_cake_state)" != "true"; then
        warn "CAKE 当前未启用，子项 flag 不写入，避免状态误显示。"
        clear_cake_child_flags_default
        update_hw_boot_script
        return 0
    fi
    if test -f "$FLAGS_DIR/$flag"; then rm -f "$FLAGS_DIR/$flag" 2>/dev/null || true; else touch "$FLAGS_DIR/$flag" 2>/dev/null || true; fi
    _apply_cake_live
    update_hw_boot_script
}










#==============================================================================
# V198e52 最终覆盖层：强校验热更新 + 重启后持久化修正
# 设计目标：
#   1) 修复 e42 的 _safe_jq_write 因 Xray 测试输出不含固定字符串而静默回滚的问题。
#   2) Policy=260 与 Buffer=128KB 必须落地；失败则明确报错，不再吞掉。
#   3) systemd 中禁止保留 XRAY_RAY_BUFFER_SIZE，统一用 config.json 的 KB 单位。
#   4) GSO/GRO/TSO 默认保留；只有用户手动 toggle 时才显示“已关闭卸载”。
#   5) xray-hw-tweaks.service 使用 network-online，并在启动后再次应用硬件默认项。
#==============================================================================

_get_default_iface() {
    ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || true
}

verify_xray_config() {
    local target_config="$1"
    if test ! -s "$target_config"; then
        error "配置文件为空或不存在：$target_config"
        return 1
    fi
    if ! jq empty "$target_config" >/dev/null 2>&1; then
        error "配置文件不是合法 JSON：$target_config"
        return 1
    fi
    if test ! -x "$XRAY_BIN"; then
        # Xray 尚未存在时，只做 JSON 校验。
        return 0
    fi

    local out rc
    set +e
    out=$("$XRAY_BIN" run -test -config "$target_config" 2>&1)
    rc=$?
    set -e
    if test "$rc" -eq 0; then
        return 0
    fi

    # 兼容少数旧版命令格式。
    set +e
    out=$("$XRAY_BIN" -test -config "$target_config" 2>&1)
    rc=$?
    set -e
    if test "$rc" -eq 0; then
        return 0
    fi

    error "Xray 配置测试失败，已拒绝写入。"
    echo -e "${gray}${out}${none}"
    return 1
}

_safe_jq_write() {
    # V198e52：以退出码为准，不再强制搜索 Configuration OK 字符串。
    test -f "$CONFIG" || return 1
    backup_config
    local tmp
    tmp=$(mktemp /tmp/xray.safejq.XXXXXX.json) || return 1

    set +e
    jq "$@" "$CONFIG" > "$tmp" 2>/tmp/xray.safejq.err
    local jq_res=$?
    set -e

    if test "$jq_res" -ne 0 || test ! -s "$tmp"; then
        error "jq 修改失败，写入中止。"
        sed 's/^/    /' /tmp/xray.safejq.err 2>/dev/null || true
        rm -f "$tmp" /tmp/xray.safejq.err 2>/dev/null || true
        restore_latest_backup >/dev/null 2>&1 || true
        return 1
    fi

    if verify_xray_config "$tmp"; then
        mv -f "$tmp" "$CONFIG"
        rm -f /tmp/xray.safejq.err 2>/dev/null || true
        fix_permissions
        return 0
    fi

    rm -f "$tmp" /tmp/xray.safejq.err 2>/dev/null || true
    restore_latest_backup >/dev/null 2>&1 || true
    return 1
}

remove_xray_env_buffer() {
    # 彻底删除 systemd 里的 MB 单位 Buffer 环境变量，避免 128KB 被误写成 128MB。
    local p f changed=0
    mkdir -p "$BACKUP_DIR" 2>/dev/null || true
    for p in /etc/systemd/system/xray.service /etc/systemd/system/xray.service.d; do
        if test -e "$p"; then
            while IFS= read -r f; do
                test -n "$f" || continue
                cp -a "$f" "$BACKUP_DIR/$(basename "$f").remove_buffer_env.e43.$(date +%Y%m%d_%H%M%S).bak" 2>/dev/null || true
                sed -i '/XRAY_RAY_BUFFER_SIZE/d' "$f" 2>/dev/null || true
                changed=1
            done < <(grep -RIl 'XRAY_RAY_BUFFER_SIZE' "$p" 2>/dev/null || true)
        fi
    done
    if test "$changed" -eq 1; then systemctl daemon-reload >/dev/null 2>&1 || true; fi
}

write_safe_global_limits() {
    mkdir -p /etc/security/limits.d /etc/systemd/system.conf.d "$BACKUP_DIR" 2>/dev/null || true
    cp -a /etc/security/limits.d/99-xray-limits.conf \
        "$BACKUP_DIR/99-xray-limits.conf.e43.$(date +%Y%m%d_%H%M%S).bak" 2>/dev/null || true
    cp -a /etc/systemd/system.conf.d/99-xray-limits.conf \
        "$BACKUP_DIR/systemd-99-xray-limits.conf.e43.$(date +%Y%m%d_%H%M%S).bak" 2>/dev/null || true

    cat > /etc/security/limits.d/99-xray-limits.conf <<'EOF_E44_LIMITS'
root soft nofile 1048576
root hard nofile 1048576
root soft nproc 65535
root hard nproc 65535
root soft core 0
root hard core unlimited
root soft stack 8192
root hard stack 65536

* soft nofile 1048576
* hard nofile 1048576
* soft nproc 65535
* hard nproc 65535
* soft core 0
* hard core unlimited
* soft stack 8192
* hard stack 65536
EOF_E44_LIMITS

    if test -f /etc/pam.d/common-session && ! grep -q "pam_limits.so" /etc/pam.d/common-session 2>/dev/null; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
    fi
    if test -f /etc/pam.d/common-session-noninteractive && ! grep -q "pam_limits.so" /etc/pam.d/common-session-noninteractive 2>/dev/null; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive
    fi

    cat > /etc/systemd/system.conf.d/99-xray-limits.conf <<'EOF_E44_MANAGER_LIMITS'
[Manager]
DefaultLimitNOFILE=1048576
DefaultLimitNPROC=65535
DefaultLimitSTACK=8M
DefaultTasksMax=80%
EOF_E44_MANAGER_LIMITS
}

apply_xray_cpu_schedule_default() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    mkdir -p "$(dirname "$limit_file")" 2>/dev/null || true
    local cores target_cpu
    cores=$(nproc 2>/dev/null || echo 1)
    if ! [[ "$cores" =~ ^[0-9]+$ ]] || test "$cores" -lt 1 2>/dev/null; then cores=1; fi
    if test "$cores" -eq 1 2>/dev/null; then
        target_cpu="0"
    else
        target_cpu="0-$((cores-1))"
    fi
    sed -i '/^CPUAffinity=/d;/^Environment="GOMAXPROCS=/d' "$limit_file" 2>/dev/null || true
    echo "CPUAffinity=$target_cpu" >> "$limit_file"
    echo "Environment=\"GOMAXPROCS=$cores\"" >> "$limit_file"
    systemctl daemon-reload >/dev/null 2>&1 || true
}

check_affinity_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if test -f "$limit_file" && grep -q '^CPUAffinity=' "$limit_file" 2>/dev/null && grep -q '^Environment="GOMAXPROCS=' "$limit_file" 2>/dev/null; then
        echo "true"
    else
        echo "false"
    fi
}

fix_xray_systemd_limits() {
    write_safe_global_limits
    local override_dir="/etc/systemd/system/xray.service.d" limit_file
    mkdir -p "$override_dir" 2>/dev/null || true
    limit_file="$override_dir/limits.conf"
    local total_mem go_mem_limit cores gomax affinity
    total_mem=$(free -m 2>/dev/null | awk '/Mem/{print int($2)}' || echo "1024")
    go_mem_limit=$(( total_mem * 80 / 100 )); if test "$go_mem_limit" -lt 128 2>/dev/null; then go_mem_limit=128; fi
    cores=$(nproc 2>/dev/null || echo 1); if ! [[ "$cores" =~ ^[0-9]+$ ]] || test "$cores" -lt 1 2>/dev/null; then cores=1; fi
    gomax="$cores"; affinity=""
    if test "$cores" -gt 1 2>/dev/null; then affinity=$(seq -s ' ' 0 $((cores-1)) 2>/dev/null || true); fi
    cat > "$limit_file" <<EOF_LIMIT_E44
[Service]
LimitNOFILE=1048576
LimitNPROC=262144
LimitMEMLOCK=infinity
LimitSTACK=8M
TasksMax=infinity
Nice=-10
OOMScoreAdjust=-500
IOSchedulingClass=best-effort
IOSchedulingPriority=0
Environment="GOMEMLIMIT=${go_mem_limit}MiB"
Environment="GOGC=300"
Environment="GOMAXPROCS=${gomax}"
Restart=on-failure
RestartSec=5s
EOF_LIMIT_E44
    if test -n "$affinity"; then echo "CPUAffinity=$affinity" >> "$limit_file"; fi
    grep -RIl 'XRAY_RAY_BUFFER_SIZE' /etc/systemd/system/xray.service /etc/systemd/system/xray.service.d 2>/dev/null | xargs -r sed -i '/XRAY_RAY_BUFFER_SIZE/d'
    systemctl daemon-reload >/dev/null 2>&1 || true
}

apply_process_priority_default() { fix_xray_systemd_limits; }

check_process_priority_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if test -f "$limit_file" \
       && grep -q '^OOMScoreAdjust=-500' "$limit_file" 2>/dev/null \
       && grep -q '^Nice=-10' "$limit_file" 2>/dev/null \
       && grep -q '^LimitNOFILE=1048576' "$limit_file" 2>/dev/null \
       && grep -q '^LimitSTACK=8M' "$limit_file" 2>/dev/null \
       && ! grep -q 'XRAY_RAY_BUFFER_SIZE' "$limit_file" 2>/dev/null; then
        echo "true"
    else
        echo "false"
    fi
}

force_apply_xray_core_defaults_e52() {
    # 一次性强事务写入，避免多次 _safe_jq_write 中途失败却被吞掉。
    test -f "$CONFIG" || return 1
    _safe_jq_write '
      .log = (.log // {}) |
      .log.access = "none" |
      .log.error = "none" |
      .log.loglevel = "warning" |
      .routing = (.routing // {}) |
      .routing.domainStrategy = "AsIs" |
      .routing.domainMatcher = "mph" |
      .dns = (.dns // {}) |
      .dns.servers = (.dns.servers // ["https://1.1.1.1/dns-query", "https://208.67.222.222/dns-query"]) |
      .dns.queryStrategy = "UseIPv4" |
      .policy = (.policy // {}) |
      .policy.levels = (.policy.levels // {}) |
      .policy.levels["0"] = (.policy.levels["0"] // {}) |
      .policy.levels["0"].handshake = 3 |
      .policy.levels["0"].connIdle = 260 |
      .policy.levels["0"].uplinkOnly = 2 |
      .policy.levels["0"].downlinkOnly = 5 |
      .policy.levels["0"].bufferSize = 128 |
      .policy.system = (.policy.system // {}) |
      .policy.system.statsInboundDownlink = false |
      .policy.system.statsInboundUplink = false |
      (.outbounds[]? | select(.protocol=="freedom") | .settings) |= (. // {}) |
      (.outbounds[]? | select(.protocol=="freedom") | .settings.domainStrategy) = "AsIs" |
      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings) |= (. // {}) |
      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt) |= (. // {}) |
      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpNoDelay) = true |
      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpFastOpen) = false |
      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpKeepAliveIdle) = 30 |
      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpKeepAliveInterval) = 15 |
      (.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .streamSettings) |= (. // {}) |
      (.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .streamSettings.sockopt) |= (. // {}) |
      (.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .streamSettings.sockopt.tcpNoDelay) = true |
      (.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .streamSettings.sockopt.tcpFastOpen) = false |
      (.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .streamSettings.sockopt.tcpKeepAliveIdle) = 30 |
      (.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .streamSettings.sockopt.tcpKeepAliveInterval) = 15 |
      (.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing) |= (. // {}) |
      (.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.enabled) = true |
      (.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.metadataOnly) = true |
      (.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly) = true |
      (.inbounds[]? | select(.protocol=="vless") | .settings.clients[]?) |= (. + {"flow":"xtls-rprx-vision"}) |
      (.inbounds[]? | select(.streamSettings.realitySettings? != null) | .streamSettings.realitySettings.show) = false |
      (.inbounds[]? | select(.streamSettings.realitySettings? != null) | .streamSettings.realitySettings.maxTimeDiff) = 60000
    '
}

apply_xray_policy_260_default() { force_apply_xray_core_defaults_e52 >/dev/null 2>&1 || return 1; }
apply_xray_buffer_kb() { local kb="${1:-128}"; if test "$kb" != "128"; then warn "V198e52 默认只固化 128KB；如需其它值请手动改 config.json。"; fi; force_apply_xray_core_defaults_e52 >/dev/null 2>&1 || return 1; remove_xray_env_buffer; }
apply_xray_buffer_128_default() { force_apply_xray_core_defaults_e52 >/dev/null 2>&1 || return 1; remove_xray_env_buffer; }
apply_xray_nodelay_default() { force_apply_xray_core_defaults_e52 >/dev/null 2>&1 || return 1; }
apply_xray_fastopen_off_default() { force_apply_xray_core_defaults_e52 >/dev/null 2>&1 || return 1; }
apply_xray_keep_2_to_6_defaults() { force_apply_xray_core_defaults_e52 >/dev/null 2>&1 || return 1; }
hot_patch_xray_config() { force_apply_xray_core_defaults_e52; }

check_buffer_state() {
    local v=""
    v=$(jq -r '.policy.levels["0"].bufferSize // empty' "$CONFIG" 2>/dev/null || echo "")
    if test "$v" = "128" && ! systemctl cat xray 2>/dev/null | grep -qi 'XRAY_RAY_BUFFER_SIZE'; then echo "true"; else echo "false"; fi
}

check_policy_260_state() {
    local v=""
    v=$(jq -r '.policy.levels["0"].connIdle // empty' "$CONFIG" 2>/dev/null || echo "")
    if test "$v" = "260"; then echo "true"; else echo "false"; fi
}

clear_cake_child_flags_default() {
    rm -f "$FLAGS_DIR/ack_filter" "$FLAGS_DIR/ecn" "$FLAGS_DIR/wash" 2>/dev/null || true
}

check_ackfilter_state() { if test "$(check_cake_state 2>/dev/null || echo false)" = "true" && test -f "$FLAGS_DIR/ack_filter"; then echo "true"; else echo "false"; fi; }
check_ecn_state()       { if test "$(check_cake_state 2>/dev/null || echo false)" = "true" && test -f "$FLAGS_DIR/ecn"; then echo "true"; else echo "false"; fi; }
check_wash_state()      { if test "$(check_cake_state 2>/dev/null || echo false)" = "true" && test -f "$FLAGS_DIR/wash"; then echo "true"; else echo "false"; fi; }

apply_fq_qdisc_default() {
    local IFACE conf
    IFACE=$(_get_default_iface); conf="/etc/sysctl.d/99-xray-hotupdate-fast.conf"
    mkdir -p /etc/sysctl.d "$FLAGS_DIR" 2>/dev/null || true
    rm -f "$FLAGS_DIR/ack_filter" "$FLAGS_DIR/ecn" "$FLAGS_DIR/wash" 2>/dev/null || true
    sed -i '/^sch_cake$/d' /etc/modules-load.d/cake.conf 2>/dev/null || true
    if test -f "$conf" && grep -q '^net.core.default_qdisc' "$conf" 2>/dev/null; then sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = fq/' "$conf" 2>/dev/null || true; else echo 'net.core.default_qdisc = fq' >> "$conf"; fi
    sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1 || true
    if test -n "$IFACE" && command -v tc >/dev/null 2>&1; then tc qdisc replace dev "$IFACE" root fq 2>/dev/null || true; fi
}

check_gso_off_state() { if test -f "$FLAGS_DIR/gso_off"; then echo "true"; else echo "false"; fi; }

apply_gso_gro_on_default() {
    local IFACE
    mkdir -p "$FLAGS_DIR" 2>/dev/null || true
    rm -f "$FLAGS_DIR/gso_off" 2>/dev/null || true
    IFACE=$(_get_default_iface)
    if test -n "$IFACE" && command -v ethtool >/dev/null 2>&1; then
        ethtool -K "$IFACE" gro on gso on tso on 2>/dev/null || true
        ethtool -K "$IFACE" lro off rx-gro-hw on tx-udp-segmentation on 2>/dev/null || true
        ethtool -C "$IFACE" adaptive-rx on 2>/dev/null || true
    fi
}

toggle_gso() {
    local IFACE
    IFACE=$(_get_default_iface)
    if test -z "$IFACE" || ! command -v ethtool >/dev/null 2>&1; then return; fi
    mkdir -p "$FLAGS_DIR" 2>/dev/null || true
    if test -f "$FLAGS_DIR/gso_off"; then
        rm -f "$FLAGS_DIR/gso_off" 2>/dev/null || true
        apply_gso_gro_on_default
        info "GRO/GSO/TSO 已恢复为极速默认保留。"
    else
        touch "$FLAGS_DIR/gso_off" 2>/dev/null || true
        ethtool -K "$IFACE" gro off gso off tso off 2>/dev/null || true
        warn "已关闭 GRO/GSO/TSO，仅建议排障短测，不建议长期。"
    fi
    update_hw_boot_script
}

update_hw_boot_script() {
    cat > /usr/local/bin/xray-hw-tweaks.sh <<'EOF_E44_HW'
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
CONFIG_DIR="/usr/local/etc/xray"
FLAGS_DIR="$CONFIG_DIR/flags"
CAKE_OPTS_FILE="$CONFIG_DIR/cake_opts.txt"
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || true)
want_cake=0
if grep -q '^net.core.default_qdisc[[:space:]]*=[[:space:]]*cake' /etc/sysctl.d/99-xray-hotupdate-fast.conf 2>/dev/null; then want_cake=1; fi
if grep -q '^sch_cake$' /etc/modules-load.d/cake.conf 2>/dev/null; then want_cake=1; fi
if test -n "$IFACE"; then
    if test -f "$FLAGS_DIR/gso_off"; then ethtool -K "$IFACE" gro off gso off tso off 2>/dev/null || true
    else ethtool -K "$IFACE" gro on gso on tso on 2>/dev/null || true; ethtool -K "$IFACE" lro off rx-gro-hw on tx-udp-segmentation on 2>/dev/null || true; fi
    ethtool -C "$IFACE" adaptive-rx on 2>/dev/null || true
    ip link set dev "$IFACE" txqueuelen 3000 2>/dev/null || true
    if command -v tc >/dev/null 2>&1; then
        if test "$want_cake" -eq 1; then
            modprobe sch_cake >/dev/null 2>&1 || true
            CAKE_OPTS=""; test -s "$CAKE_OPTS_FILE" && CAKE_OPTS=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || true)
            ACK=""; ECN=""; WASH=""; test -f "$FLAGS_DIR/ack_filter" && ACK="ack-filter"; test -f "$FLAGS_DIR/ecn" && ECN="ecn"; test -f "$FLAGS_DIR/wash" && WASH="wash"
            tc qdisc replace dev "$IFACE" root cake $CAKE_OPTS $ACK $ECN $WASH 2>/dev/null || tc qdisc replace dev "$IFACE" root fq 2>/dev/null || true
            sysctl -w net.core.default_qdisc=cake >/dev/null 2>&1 || true
        else
            tc qdisc replace dev "$IFACE" root fq 2>/dev/null || true
            sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1 || true
        fi
    fi
fi
if test -w /sys/kernel/mm/transparent_hugepage/enabled; then echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true; fi
if test -w /sys/kernel/mm/transparent_hugepage/defrag; then echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true; fi
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do test -f "$cpu" && echo performance > "$cpu" 2>/dev/null || true; done
if test -f "$CONFIG_DIR/initcwnd.txt"; then
    CWND_VAL=$(cat "$CONFIG_DIR/initcwnd.txt" 2>/dev/null || echo "10"); DEF_ROUTE=$(ip route show default 2>/dev/null | head -n 1)
    if test -n "$DEF_ROUTE"; then CLEAN_ROUTE=$(echo "$DEF_ROUTE" | sed 's/ initcwnd [0-9]*//g' | sed 's/ initrwnd [0-9]*//g'); ip route change $CLEAN_ROUTE initcwnd "$CWND_VAL" initrwnd "$CWND_VAL" 2>/dev/null || true; fi
fi
modprobe iptable_mangle >/dev/null 2>&1 || true
modprobe xt_TCPMSS >/dev/null 2>&1 || true
iptables -t mangle -N XRAY_MSS_CLAMP 2>/dev/null || true
iptables -t mangle -F XRAY_MSS_CLAMP 2>/dev/null || true
iptables -t mangle -A XRAY_MSS_CLAMP -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
iptables -t mangle -C POSTROUTING -j XRAY_MSS_CLAMP 2>/dev/null || iptables -t mangle -A POSTROUTING -j XRAY_MSS_CLAMP 2>/dev/null || true
EOF_E44_HW
    chmod +x /usr/local/bin/xray-hw-tweaks.sh 2>/dev/null || true
    cat > /etc/systemd/system/xray-hw-tweaks.service <<'EOF_E44_SVC'
[Unit]
Description=Xray Hardware Tweaks Safe Defaults
Wants=network-online.target
After=network-online.target
Before=xray.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/xray-hw-tweaks.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF_E44_SVC
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable xray-hw-tweaks.service >/dev/null 2>&1 || true
    /usr/local/bin/xray-hw-tweaks.sh >/dev/null 2>&1 || true
}

apply_safe_turbo_defaults() {
    title "V198e52 净化安全极速包：DNS 前置 + Swap≤1024MB + 强校验 + 重启持久化"
    repair_dns_if_broken
    check_and_create_swap
    fix_xray_systemd_limits
    apply_hotupdate_fast_sysctl
    apply_fq_qdisc_default
    apply_txqueue_3000_default
    apply_gso_gro_on_default
    enable_thp_never_default
    enable_cpu_performance_default
    enable_zram_default
    enable_journald_volatile_default
    set_xray_gogc_300
    enable_dnsmasq_cache_safely
    clear_cake_child_flags_default
    update_hw_boot_script
    _apply_mss_chain_e52
    repair_dns_if_broken
    force_apply_xray_core_defaults_e52
    remove_xray_env_buffer
}

verify_e52_post_state() {
    local fail=0 buf pol env cron_bad
    buf=$(jq -r '.policy.levels["0"].bufferSize // empty' "$CONFIG" 2>/dev/null || echo "")
    pol=$(jq -r '.policy.levels["0"].connIdle // empty' "$CONFIG" 2>/dev/null || echo "")
    env=$(systemctl cat xray 2>/dev/null | grep -i 'XRAY_RAY_BUFFER_SIZE' || true)
    cron_bad=$(crontab -l 2>/dev/null | grep -F "$UPDATE_DAT_SCRIPT" || true)
    local swap_total
    swap_total=$(_swap_total_mb)
    if test "${swap_total:-0}" -gt 1024 2>/dev/null; then error "Swap 总量超过 1024MB：当前约 ${swap_total}MB"; fail=1; fi
    if test "$buf" != "128"; then error "Buffer 未落地：当前值=${buf:-MISSING}"; fail=1; fi
    if test "$pol" != "260"; then error "Policy connIdle 未落地：当前值=${pol:-MISSING}"; fail=1; fi
    if test -n "$env"; then error "systemd 仍残留 XRAY_RAY_BUFFER_SIZE：$env"; fail=1; fi
    if test -n "$cron_bad"; then warn "检测到旧 cron 仍含 update-dat 脚本，建议手动检查 crontab -l。"; fi
    systemctl is-enabled xray-dat-update.timer >/dev/null 2>&1 || warn "xray-dat-update.timer 未启用，dat 自动更新可能不可用。"
    return "$fail"
}

hot_update_from_legacy() {
    title "V198e52 净化稳态热更新：Swap≤1024MB + 去重覆盖 + 持久化自检"
    if test ! -f "$CONFIG"; then die "未找到 $CONFIG，不能热更新。请先确认 Xray 已安装。"; fi
    if ! jq empty "$CONFIG" >/dev/null 2>&1; then die "现有 config.json 不是合法 JSON，拒绝热更新，避免节点损坏。"; fi
    local ts bdir
    ts=$(date +%Y%m%d_%H%M%S); bdir="$BACKUP_DIR/hotupdate_e52_${ts}"
    mkdir -p "$bdir" 2>/dev/null || true
    cp -a "$CONFIG" "$bdir/config.json.bak" 2>/dev/null || true
    cp -a "$PUBKEY_FILE" "$bdir/public.key.bak" 2>/dev/null || true
    cp -a "$USER_SNI_MAP" "$bdir/user_sni.txt.bak" 2>/dev/null || true
    cp -a "$USER_TIME_MAP" "$bdir/user_time.txt.bak" 2>/dev/null || true
    cp -a /etc/resolv.conf "$bdir/resolv.conf.bak" 2>/dev/null || true
    cp -a /etc/systemd/system/xray.service.d "$bdir/xray.service.d.bak" 2>/dev/null || true
    cp -a /usr/local/bin/xray-hw-tweaks.sh "$bdir/xray-hw-tweaks.sh.bak" 2>/dev/null || true
    crontab -l > "$bdir/crontab.bak" 2>/dev/null || true
    info "已创建热更新快照：$bdir"
    install_self_entrypoint
    repair_dns_if_broken
    install_update_dat
    remove_origin_guard auto >/dev/null 2>&1 || true
    apply_safe_turbo_defaults
    migrate_legacy_user_maps
    ensure_public_key_cache
    force_apply_xray_core_defaults_e52
    remove_xray_env_buffer
    fix_permissions
    echo "$SCRIPT_VERSION" > "$SCRIPT_VERSION_FILE" 2>/dev/null || true
    if ! verify_e52_post_state; then error "V198e52 关键状态校验失败，已保留快照：$bdir"; return 1; fi
    ensure_xray_is_alive
    info "V198e52 热更新完成：Swap≤1024MB、Buffer=128KB、Policy=260s、FQ 默认、GRO/GSO/TSO 保留、dat timer 安全化已落地。"
}


#==============================================================================
# V198e52 Ring Buffer 自适应最大值覆盖层
# 目标：不再用统一 512/1024/2048；读取 Pre-set maximums，RX/TX 分别拉到硬件上限。
#==============================================================================
_ring_parse_value_e52() {
    local section="$1" key="$2" iface="$3"
    ethtool -g "$iface" 2>/dev/null | awk -v section="$section" -v key="$key" '
        $0 ~ section {flag=1; next}
        flag && $0 ~ /^[[:space:]]*[A-Za-z ]+:/ {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1)
            if ($1 == key ":" && $2 ~ /^[0-9]+$/) {print $2; exit}
        }
    '
}

_ring_max_rx_e52() { local i="$1"; _ring_parse_value_e52 "Pre-set maximums" "RX" "$i"; }
_ring_max_tx_e52() { local i="$1"; _ring_parse_value_e52 "Pre-set maximums" "TX" "$i"; }
_ring_cur_rx_e52() { local i="$1"; _ring_parse_value_e52 "Current hardware settings" "RX" "$i"; }
_ring_cur_tx_e52() { local i="$1"; _ring_parse_value_e52 "Current hardware settings" "TX" "$i"; }

_apply_ring_target_value_e52() {
    local IFACE max_rx max_tx
    IFACE=$(_get_default_iface 2>/dev/null || ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    test -n "$IFACE" || return 1
    command -v ethtool >/dev/null 2>&1 || return 1
    ethtool -g "$IFACE" >/dev/null 2>&1 || return 1
    max_rx=$(_ring_max_rx_e52 "$IFACE")
    max_tx=$(_ring_max_tx_e52 "$IFACE")
    [[ "${max_rx:-}" =~ ^[0-9]+$ ]] || return 1
    [[ "${max_tx:-}" =~ ^[0-9]+$ ]] || max_tx="$max_rx"
    mkdir -p "$CONFIG_DIR" "$FLAGS_DIR" 2>/dev/null || true
    echo "$max_rx" > "$CONFIG_DIR/ring_target_rx.txt" 2>/dev/null || true
    echo "$max_tx" > "$CONFIG_DIR/ring_target_tx.txt" 2>/dev/null || true
    echo "max" > "$CONFIG_DIR/ring_mode.txt" 2>/dev/null || true
    # 兼容旧状态检查文件：写 RX 目标，但 e52 真正以 ring_target_rx/tx 为准。
    echo "$max_rx" > "$CONFIG_DIR/ring_target.txt" 2>/dev/null || true
    echo "${max_rx} ${max_tx}"
}

apply_ring_max_adaptive_default() {
    local IFACE max_rx max_tx curr_rx curr_tx
    IFACE=$(_get_default_iface 2>/dev/null || ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if test -z "$IFACE" || ! command -v ethtool >/dev/null 2>&1 || ! ethtool -g "$IFACE" >/dev/null 2>&1; then
        warn "当前网卡不支持 Ring Buffer 查询/设置，已跳过。"
        return 0
    fi
    max_rx=$(_ring_max_rx_e52 "$IFACE")
    max_tx=$(_ring_max_tx_e52 "$IFACE")
    curr_rx=$(_ring_cur_rx_e52 "$IFACE")
    curr_tx=$(_ring_cur_tx_e52 "$IFACE")
    if ! [[ "${max_rx:-}" =~ ^[0-9]+$ ]]; then
        warn "未能识别 RX Ring 最大值，已跳过。"
        return 0
    fi
    if ! [[ "${max_tx:-}" =~ ^[0-9]+$ ]]; then max_tx="$max_rx"; fi
    mkdir -p "$CONFIG_DIR" "$FLAGS_DIR" 2>/dev/null || true
    echo "$max_rx" > "$CONFIG_DIR/ring_target_rx.txt" 2>/dev/null || true
    echo "$max_tx" > "$CONFIG_DIR/ring_target_tx.txt" 2>/dev/null || true
    echo "$max_rx" > "$CONFIG_DIR/ring_target.txt" 2>/dev/null || true
    echo "max" > "$CONFIG_DIR/ring_mode.txt" 2>/dev/null || true
    rm -f "$FLAGS_DIR/ring_low_latency" 2>/dev/null || true
    touch "$FLAGS_DIR/ring_max_adaptive" 2>/dev/null || true
    ethtool -G "$IFACE" rx "$max_rx" tx "$max_tx" 2>/dev/null || \
      ethtool -G "$IFACE" rx "$max_rx" 2>/dev/null || true
    info "Ring Buffer 自适应最大值已落地：$IFACE RX=${max_rx}, TX=${max_tx}（原 RX=${curr_rx:-?}, TX=${curr_tx:-?}）。"
    update_hw_boot_script >/dev/null 2>&1 || true
}

# 保留菜单 16 入口，但 e52 不再“低延迟收缩”，而是 RX/TX 分别使用硬件最大值。
apply_ring_low_latency_default() { apply_ring_max_adaptive_default; }
toggle_ring() { apply_ring_max_adaptive_default; }

check_ring_state() {
    local IFACE max_rx max_tx curr_rx curr_tx
    IFACE=$(_get_default_iface 2>/dev/null || ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if test -z "$IFACE" || ! command -v ethtool >/dev/null 2>&1 || ! ethtool -g "$IFACE" >/dev/null 2>&1; then echo "unsupported"; return; fi
    max_rx=$(_ring_max_rx_e52 "$IFACE"); max_tx=$(_ring_max_tx_e52 "$IFACE")
    curr_rx=$(_ring_cur_rx_e52 "$IFACE"); curr_tx=$(_ring_cur_tx_e52 "$IFACE")
    [[ "${max_rx:-}" =~ ^[0-9]+$ ]] || { echo "unsupported"; return; }
    [[ "${max_tx:-}" =~ ^[0-9]+$ ]] || max_tx="$max_rx"
    [[ "${curr_rx:-}" =~ ^[0-9]+$ ]] || { echo "unsupported"; return; }
    [[ "${curr_tx:-}" =~ ^[0-9]+$ ]] || curr_tx="$max_tx"
    if test "$curr_rx" -eq "$max_rx" 2>/dev/null && test "$curr_tx" -eq "$max_tx" 2>/dev/null; then echo "true"; else echo "false"; fi
}

update_hw_boot_script() {
    cat > /usr/local/bin/xray-hw-tweaks.sh <<'EOF_E51_HW'
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
CONFIG_DIR="/usr/local/etc/xray"
FLAGS_DIR="$CONFIG_DIR/flags"
CAKE_OPTS_FILE="$CONFIG_DIR/cake_opts.txt"
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || true)
ring_value() {
    local section="$1" key="$2" iface="$3"
    ethtool -g "$iface" 2>/dev/null | awk -v section="$section" -v key="$key" '
        $0 ~ section {flag=1; next}
        flag && $0 ~ /^[[:space:]]*[A-Za-z ]+:/ {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $1)
            if ($1 == key ":" && $2 ~ /^[0-9]+$/) {print $2; exit}
        }
    '
}
want_cake=0
if grep -q '^net.core.default_qdisc[[:space:]]*=[[:space:]]*cake' /etc/sysctl.d/99-xray-hotupdate-fast.conf 2>/dev/null; then want_cake=1; fi
if grep -q '^sch_cake$' /etc/modules-load.d/cake.conf 2>/dev/null; then want_cake=1; fi
if test -n "$IFACE"; then
    if test -f "$FLAGS_DIR/gso_off"; then
        ethtool -K "$IFACE" gro off gso off tso off 2>/dev/null || true
    else
        ethtool -K "$IFACE" gro on gso on tso on 2>/dev/null || true
        ethtool -K "$IFACE" lro off rx-gro-hw on tx-udp-segmentation on 2>/dev/null || true
    fi
    ethtool -C "$IFACE" adaptive-rx on 2>/dev/null || true
    ip link set dev "$IFACE" txqueuelen 3000 2>/dev/null || true
    if test -f "$FLAGS_DIR/ring_max_adaptive" && command -v ethtool >/dev/null 2>&1 && ethtool -g "$IFACE" >/dev/null 2>&1; then
        MAX_RX=$(ring_value "Pre-set maximums" "RX" "$IFACE")
        MAX_TX=$(ring_value "Pre-set maximums" "TX" "$IFACE")
        if echo "${MAX_RX:-}" | grep -Eq '^[0-9]+$'; then
            if ! echo "${MAX_TX:-}" | grep -Eq '^[0-9]+$'; then MAX_TX="$MAX_RX"; fi
            echo "$MAX_RX" > "$CONFIG_DIR/ring_target_rx.txt" 2>/dev/null || true
            echo "$MAX_TX" > "$CONFIG_DIR/ring_target_tx.txt" 2>/dev/null || true
            echo "$MAX_RX" > "$CONFIG_DIR/ring_target.txt" 2>/dev/null || true
            echo "max" > "$CONFIG_DIR/ring_mode.txt" 2>/dev/null || true
            ethtool -G "$IFACE" rx "$MAX_RX" tx "$MAX_TX" 2>/dev/null || ethtool -G "$IFACE" rx "$MAX_RX" 2>/dev/null || true
        fi
    fi
    if command -v tc >/dev/null 2>&1; then
        if test "$want_cake" -eq 1; then
            modprobe sch_cake >/dev/null 2>&1 || true
            CAKE_OPTS=""; test -s "$CAKE_OPTS_FILE" && CAKE_OPTS=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || true)
            ACK=""; ECN=""; WASH=""; test -f "$FLAGS_DIR/ack_filter" && ACK="ack-filter"; test -f "$FLAGS_DIR/ecn" && ECN="ecn"; test -f "$FLAGS_DIR/wash" && WASH="wash"
            tc qdisc replace dev "$IFACE" root cake $CAKE_OPTS $ACK $ECN $WASH 2>/dev/null || tc qdisc replace dev "$IFACE" root fq 2>/dev/null || true
            sysctl -w net.core.default_qdisc=cake >/dev/null 2>&1 || true
        else
            tc qdisc replace dev "$IFACE" root fq 2>/dev/null || true
            sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1 || true
        fi
    fi
fi
if test -w /sys/kernel/mm/transparent_hugepage/enabled; then echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true; fi
if test -w /sys/kernel/mm/transparent_hugepage/defrag; then echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true; fi
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do test -f "$cpu" && echo performance > "$cpu" 2>/dev/null || true; done
if test -f "$CONFIG_DIR/initcwnd.txt"; then
    CWND_VAL=$(cat "$CONFIG_DIR/initcwnd.txt" 2>/dev/null || echo "10"); DEF_ROUTE=$(ip route show default 2>/dev/null | head -n 1)
    if test -n "$DEF_ROUTE"; then CLEAN_ROUTE=$(echo "$DEF_ROUTE" | sed 's/ initcwnd [0-9]*//g' | sed 's/ initrwnd [0-9]*//g'); ip route change $CLEAN_ROUTE initcwnd "$CWND_VAL" initrwnd "$CWND_VAL" 2>/dev/null || true; fi
fi
modprobe iptable_mangle >/dev/null 2>&1 || true
modprobe xt_TCPMSS >/dev/null 2>&1 || true
iptables -t mangle -N XRAY_MSS_CLAMP 2>/dev/null || true
iptables -t mangle -F XRAY_MSS_CLAMP 2>/dev/null || true
iptables -t mangle -A XRAY_MSS_CLAMP -p tcp -m tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
iptables -t mangle -C POSTROUTING -j XRAY_MSS_CLAMP 2>/dev/null || iptables -t mangle -A POSTROUTING -j XRAY_MSS_CLAMP 2>/dev/null || true
EOF_E51_HW
    chmod +x /usr/local/bin/xray-hw-tweaks.sh 2>/dev/null || true
    cat > /etc/systemd/system/xray-hw-tweaks.service <<'EOF_E51_SVC'
[Unit]
Description=Xray Hardware Tweaks Safe Defaults
Wants=network-online.target
After=network-online.target
Before=xray.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/xray-hw-tweaks.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF_E51_SVC
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable xray-hw-tweaks.service >/dev/null 2>&1 || true
    /usr/local/bin/xray-hw-tweaks.sh >/dev/null 2>&1 || true
}

apply_safe_turbo_defaults() {
    title "V198e52 稳态极速包：Dnsmasq + ZRAM≤1024MB + Ring RX/TX自适应最大值"
    repair_dns_if_broken
    check_and_create_swap
    fix_xray_systemd_limits
    apply_hotupdate_fast_sysctl
    apply_fq_qdisc_default
    apply_txqueue_3000_default
    apply_gso_gro_on_default
    apply_ring_max_adaptive_default
    enable_thp_never_default
    enable_cpu_performance_default
    enable_zram_default
    enable_journald_volatile_default
    set_xray_gogc_300
    enable_dnsmasq_cache_safely
    clear_cake_child_flags_default
    update_hw_boot_script
    _apply_mss_chain_e52
    repair_dns_if_broken
    force_apply_xray_core_defaults_e52
    remove_xray_env_buffer
}

verify_e52_post_state() {
    local fail=0 buf pol env cron_bad dns_state ring_state zram_state swap_total
    buf=$(jq -r '.policy.levels["0"].bufferSize // empty' "$CONFIG" 2>/dev/null || echo "")
    pol=$(jq -r '.policy.levels["0"].connIdle // empty' "$CONFIG" 2>/dev/null || echo "")
    env=$(systemctl cat xray 2>/dev/null | grep -i 'XRAY_RAY_BUFFER_SIZE' || true)
    cron_bad=$(crontab -l 2>/dev/null | grep -F "$UPDATE_DAT_SCRIPT" || true)
    dns_state=$(check_dnsmasq_state)
    ring_state=$(check_ring_state)
    zram_state=$(check_zram_state)
    swap_total=$(_swap_total_mb)
    if test "${swap_total:-0}" -gt 1024 2>/dev/null; then error "Swap 总量超过 1024MB：当前约 ${swap_total}MB"; fail=1; fi
    if test "$buf" != "128"; then error "Buffer 未落地：当前值=${buf:-MISSING}"; fail=1; fi
    if test "$pol" != "260"; then error "Policy connIdle 未落地：当前值=${pol:-MISSING}"; fail=1; fi
    if test -n "$env"; then error "systemd 仍残留 XRAY_RAY_BUFFER_SIZE：$env"; fail=1; fi
    if test "$dns_state" != "true"; then warn "Dnsmasq 未处于接管状态；可能是安装失败、端口 53 被占用或系统不允许。已保留静态 DNS 防断联。"; fi
    if test "$ring_state" = "false"; then warn "Ring Buffer 未能设置到 RX/TX 硬件最大值；可能是云厂商虚拟网卡限制。"; fi
    if test "$zram_state" != "true"; then warn "ZRAM 未处于 1024MB 上限模式；若系统不支持 ZRAM，则会使用 /swapfile 兜底。"; fi
    if test -n "$cron_bad"; then warn "检测到旧 cron 仍含 update-dat 脚本，建议手动检查 crontab -l。"; fi
    systemctl is-enabled xray-dat-update.timer >/dev/null 2>&1 || warn "xray-dat-update.timer 未启用，dat 自动更新可能不可用。"
    return "$fail"
}


#==============================================================================
# V198e52 kernel forge safety overrides
# 目的：热更新不碰内核；内核实验区修复 e51 架构回退、源码编译门槛、关键安装校验、Ring TX=RXMAX 等风险。
#==============================================================================

_kernel_downlevel_sequence_e52() {
    local lvl="${1:-1}"
    case "$lvl" in
        4) echo "4 3 2 1" ;;
        3) echo "3 2 1" ;;
        2) echo "2 1" ;;
        *) echo "1" ;;
    esac
}

_kernel_boot_artifacts_ok_e52() {
    local kver="${1:-}"
    test -n "$kver" || return 1
    test -s "/boot/vmlinuz-$kver" || return 1
    test -d "/lib/modules/$kver" || return 1
    if test ! -s "/boot/initrd.img-$kver"; then
        if command -v update-initramfs >/dev/null 2>&1; then
            update-initramfs -c -k "$kver" >/dev/null 2>&1 || return 1
        elif command -v dracut >/dev/null 2>&1; then
            dracut --force "/boot/initramfs-${kver}.img" "$kver" >/dev/null 2>&1 || return 1
        else
            return 1
        fi
    fi
    test -s "/boot/initrd.img-$kver" || test -s "/boot/initramfs-${kver}.img"
}

_kernel_pre_reboot_verify_e52() {
    local kver="${1:-}"
    if ! _kernel_boot_artifacts_ok_e52 "$kver"; then
        error "新内核启动文件校验失败：$kver。已拒绝修改 GRUB 默认项。"
        return 1
    fi
    if command -v update-grub >/dev/null 2>&1; then
        update-grub >/dev/null 2>&1 || { error "update-grub 失败，拒绝提示重启。"; return 1; }
    elif command -v grub2-mkconfig >/dev/null 2>&1; then
        grub2-mkconfig -o /boot/grub2/grub.cfg >/dev/null 2>&1 || { error "grub2-mkconfig 失败，拒绝提示重启。"; return 1; }
    else
        warn "未找到 update-grub/grub2-mkconfig，请手动确认引导项。"
    fi
    return 0
}

_kernel_source_precheck_e52() {
    local root_free boot_free mem_mb swap_mb total_mb
    root_free=$(df -Pm / 2>/dev/null | awk 'NR==2{print int($4)}' || echo 0)
    boot_free=$(df -Pm /boot 2>/dev/null | awk 'NR==2{print int($4)}' || echo 0)
    if ! [[ "${boot_free:-}" =~ ^[0-9]+$ ]]; then boot_free=0; fi
    if test "$boot_free" -eq 0 2>/dev/null; then boot_free="$root_free"; fi
    mem_mb=$(free -m 2>/dev/null | awk '/^Mem:/ {print int($2)}' || echo 0)
    swap_mb=$(free -m 2>/dev/null | awk '/^Swap:/ {print int($2)}' || echo 0)
    total_mb=$((mem_mb + swap_mb))

    echo "  当前可用空间 /: ${root_free}MB；/boot: ${boot_free}MB；内存+Swap: ${total_mb}MB"
    if test "${root_free:-0}" -lt 12000 2>/dev/null; then
        warn "源码编译需要至少 12GB 根分区可用空间，推荐 20GB+。当前不足，已拒绝。"
        return 1
    fi
    if test "${boot_free:-0}" -lt 300 2>/dev/null; then
        warn "/boot 可用空间不足 300MB，生成 initramfs/GRUB 有风险，已拒绝。"
        return 1
    fi
    if test "${total_mb:-0}" -lt 4096 2>/dev/null; then
        warn "源码编译建议内存+Swap 至少 4GB。当前不足，已拒绝。"
        return 1
    fi
    if test ! -d /boot || test ! -w /boot; then
        warn "/boot 不可写，已拒绝源码内核安装。"
        return 1
    fi
    return 0
}

_kernel_source_locked_e52() {
    title "高风险源码内核实验区已上锁"
    warn "源码编译内核可能导致 GRUB 卡死、busybox、断网、模块缺失。"
    warn "ex198e52 默认不在 1GB 小内存翻墙 VPS 上执行源码内核编译。"
    _kernel_source_precheck_e52 || { _e52_pause; return 0; }
    echo ""
    warn "资源门槛已满足，但仍必须有 VPS 快照 / VNC / 救援模式。"
    echo "  若你仍要继续，请手工设置环境变量后重新运行："
    echo "  export XRAY_ALLOW_SOURCE_KERNEL_COMPILE=1"
    echo "  然后再进入该菜单。"
    if test "${XRAY_ALLOW_SOURCE_KERNEL_COMPILE:-0}" != "1"; then
        _e52_pause
        return 0
    fi
    warn "检测到 XRAY_ALLOW_SOURCE_KERNEL_COMPILE=1，但 e52 仍建议使用 APT 预编译内核。源码编译入口已安全中止。"
    _e52_pause
    return 0
}

do_install_xanmod_main_official() {
    title "高风险内核实验区：APT 安装 XanMod 预编译内核（架构安全回退版）"

    if [[ "$(uname -m)" != "x86_64" ]]; then
        error "官方 XanMod APT 源安装当前仅支持 x86_64 架构。"
        _e52_pause
        return 0
    fi

    warn "此操作会安装新内核并要求重启；请确认 VPS 有快照/VNC/救援模式。"
    local confirm=""
    read -rp "确认继续安装 XanMod 预编译内核？(y/N): " confirm || true
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then return 0; fi

    export DEBIAN_FRONTEND=noninteractive
    repair_dns_if_broken || true

    apt-get update -y >/dev/null 2>&1 || { error "apt-get update 失败，请先修复软件源/DNS。"; _e52_pause; return 0; }
    apt-get install -y curl wget gnupg ca-certificates lsb-release >/dev/null 2>&1 || { error "安装 APT 基础依赖失败。"; _e52_pause; return 0; }

    local cpu_level levels lvl pkg installed kver
    cpu_level=$(detect_x86_64_level)
    levels=$(_kernel_downlevel_sequence_e52 "$cpu_level")
    info "CPU 架构锁定: x86-64-v${cpu_level}；只允许向下回退：${levels}"

    mkdir -p /etc/apt/keyrings
    if ! curl -fsSL --connect-timeout 10 https://dl.xanmod.org/gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/xanmod.gpg >/dev/null 2>&1; then
        error "XanMod GPG key 获取失败，已中止。"
        _e52_pause
        return 0
    fi
    echo "deb [signed-by=/etc/apt/keyrings/xanmod.gpg] http://deb.xanmod.org releases main" > /etc/apt/sources.list.d/xanmod-kernel.list
    apt-get update -y >/dev/null 2>&1 || { error "XanMod 源 apt update 失败，已中止。"; _e52_pause; return 0; }

    installed=0
    for lvl in $levels; do
        pkg="linux-xanmod-x64v${lvl}"
        warn "尝试安装：$pkg"
        if apt-get install -y "$pkg"; then
            installed=1
            info "已安装：$pkg"
            break
        fi
    done

    if test "$installed" -ne 1; then
        error "没有成功安装任何与当前 CPU 兼容的 XanMod 预编译内核。"
        _e52_pause
        return 0
    fi

    kver=$(ls -t /boot/vmlinuz-*xanmod* 2>/dev/null | head -n 1 | sed 's|/boot/vmlinuz-||' || true)
    if test -z "$kver"; then
        error "未在 /boot 找到 XanMod vmlinuz，拒绝修改 GRUB 默认项。"
        _e52_pause
        return 0
    fi

    if ! _kernel_pre_reboot_verify_e52 "$kver"; then
        _e52_pause
        return 0
    fi

    warn "XanMod 内核已安装并通过启动文件校验：$kver"
    warn "当前不会自动强制 reboot；你可在确认控制台/VNC可用后手动重启。"
    local rb_now=""
    read -rp "是否现在重启宿主机？(y/N): " rb_now || true
    if [[ "$rb_now" =~ ^[yY]$ ]]; then reboot; fi
    return 0
}

_prepare_compile_env() {
    info "源码内核编译环境安全门禁检查..."
    if ! _kernel_source_precheck_e52; then
        return 1
    fi
    check_and_clean_space
    local root_free
    root_free=$(df -Pm / 2>/dev/null | awk 'NR==2{print int($4)}' || echo 0)
    if test "$root_free" -gt 20000 2>/dev/null; then
        mkdir -p /compile 2>/dev/null || true
        BUILD_DIR="/compile"
    else
        BUILD_DIR="/usr/src"
    fi
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    cd "$BUILD_DIR" || return 1
}

_execute_compilation() {
    local extra_make_args="${1:-}"
    local make_flags="${2:-}"

    info "执行源码内核编译（关键安装步骤 fail-fast，不再吞掉错误）..."
    local mem_mb swp_mb total_mb CPU_CORES THREADS cmd COMPILED_VER
    mem_mb=$(free -m 2>/dev/null | awk '/^Mem:/ {print int($2)}' | head -n 1 || echo 1024)
    swp_mb=$(free -m 2>/dev/null | awk '/^Swap:/ {print int($2)}' | head -n 1 || echo 0)
    total_mb=$((mem_mb + swp_mb))
    CPU_CORES=$(nproc 2>/dev/null || echo 1)
    THREADS=$((total_mb / 1800))
    test "$THREADS" -lt 1 2>/dev/null && THREADS=1
    test "$THREADS" -gt "$CPU_CORES" 2>/dev/null && THREADS=$CPU_CORES
    cmd="make -j$THREADS"
    info "安全编译线程：$THREADS（内存+Swap ${total_mb}MB）"

    if test -n "$make_flags"; then
        if gcc -E - -fcf-protection=none </dev/null >/dev/null 2>&1; then
            make_flags="$make_flags -fcf-protection=none"
        fi
        eval "$cmd KCFLAGS=\"\$make_flags\" $extra_make_args" || return 1
    else
        $cmd $extra_make_args || return 1
    fi

    make modules_install || return 1
    make install || return 1

    COMPILED_VER=$(make kernelversion 2>/dev/null || echo "")
    test -n "$COMPILED_VER" || { error "无法识别编译后的 kernelversion。"; return 1; }

    if command -v update-initramfs >/dev/null 2>&1; then
        update-initramfs -c -k "$COMPILED_VER" || return 1
    elif command -v dracut >/dev/null 2>&1; then
        dracut --force "/boot/initramfs-${COMPILED_VER}.img" "$COMPILED_VER" || return 1
    else
        error "缺少 update-initramfs/dracut，无法生成 initramfs。"
        return 1
    fi

    _kernel_pre_reboot_verify_e52 "$COMPILED_VER" || return 1

    if test -n "${IFACE:-}" && command -v ethtool >/dev/null 2>&1; then
        local RXMAX TXMAX
        RXMAX=$(ethtool -g "$IFACE" 2>/dev/null | awk 'BEGIN{s=0} /Pre-set maximums:/{s=1;next} s && /^[[:space:]]*RX:/{print $2; exit}' || echo "")
        TXMAX=$(ethtool -g "$IFACE" 2>/dev/null | awk 'BEGIN{s=0} /Pre-set maximums:/{s=1;next} s && /^[[:space:]]*TX:/{print $2; exit}' || echo "")
        if [[ "${RXMAX:-}" =~ ^[0-9]+$ ]] && [[ "${TXMAX:-}" =~ ^[0-9]+$ ]]; then
            ethtool -G "$IFACE" rx "$RXMAX" tx "$TXMAX" 2>/dev/null || ethtool -G "$IFACE" rx "$RXMAX" 2>/dev/null || true
        fi
    fi

    info "源码内核安装链路已通过：$COMPILED_VER。请确认有控制台/VNC后再重启。"
    return 0
}

_compile_kernel_xanmod() {
    _kernel_source_locked_e52
}

_compile_kernel_mainline() {
    _kernel_source_locked_e52
}

do_kernel_compile_menu() {
    while true; do
        clear
        title "高风险内核实验区（V198e52 安全门禁版）"
        echo "  说明：热更新不会自动安装/编译内核。此菜单只供手动实验。"
        echo "  [修复] XanMod APT 只按 CPU 等级向下回退，禁止 v1/v2 机器误试 v3/v4。"
        echo "  [修复] 源码编译增加 12GB 磁盘 / 4GB 内存+Swap / /boot 校验门槛。"
        echo "  [修复] modules_install / make install / initramfs / update-grub 不再静默忽略失败。"
        echo "  [修复] Ring Buffer 安装后按 RX/TX 最大值分别设置，不再 TX=RXMAX。"
        echo ""
        echo -e "  ${cyan}1) [相对推荐] APT 安装 XanMod 预编译内核（仍需快照/VNC）${none}"
        echo -e "  ${magenta}2) [高风险锁定] 源码编译 XanMod（默认拒绝小内存 VPS）${none}"
        echo -e "  ${yellow}3) [高风险锁定] 源码编译 Linux Mainline（默认拒绝小内存 VPS）${none}"
        echo "  0) 返回上级菜单"
        hr
        local k_opt=""
        read -rp "请下达实验区指令 (0-3): " k_opt || true
        case "${k_opt:-}" in
            1) do_install_xanmod_main_official; return 0 ;;
            2) _compile_kernel_xanmod; return 0 ;;
            3) _compile_kernel_mainline "bbr3"; return 0 ;;
            0) return 0 ;;
        esac
    done
}


if test "${1:-}" = "--rescue" || test "${1:-}" = "--fix-v35"; then
    preflight
    rescue_after_v35_breakage
    exit $?
fi

if test "${1:-}" = "--hot-update" || test "${1:-}" = "--migrate"; then
    preflight
    hot_update_from_legacy auto
    exit $?
fi

preflight
main_menu

#==============================================================================
# EOF - Apex Vanguard V198e52 System Advanced Control Ready.
#==============================================================================
