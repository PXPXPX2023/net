#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: ex188t9.sh (The Apex Vanguard - Ultimate Xray Genesis V188t9)
# 快捷方式: xrv
#
# V188t9 终极溯源修复日志:
#   1. 满血回归: 100% 恢复 Xray 专属的 28 项高级调优菜单（包含 Nice=-20 提权）。
#   2. 核心架构: 保留 VLESS-Reality 与 SS-2022 双轨引擎及 SNI 雷达扫描矩阵。
#   3. 底盘增量: 完美融合 Swap 智能池、强制 IPv4 优先、物理熔断 IPv6。
#   4. 极致编译: 集成 Kernel.org 源码编译 BBRv3 功能，并增加磁盘防爆校验。
#   5. 终极容错: 全局 set -euo pipefail 加固，交互变量绝对安全，拒绝闪退。
# ==============================================================================

# 检查 Bash 运行环境
if test -z "$BASH_VERSION"; then
    echo "Error: Please run this script with bash."
    exit 1
fi

# 启用严格模式 (错误中断、未定义变量拦截、管道流错误捕获)
set -euo pipefail
IFS=$'\n\t'

# 补齐环境变量
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ── 颜色与日志前缀定义 ──────────────────────────────────────────
readonly red='\033[31m'
readonly yellow='\033[33m'
readonly gray='\033[90m'
readonly green='\033[92m'
readonly blue='\033[94m'
readonly magenta='\033[95m'
readonly cyan='\033[96m'
readonly none='\033[0m'

# 兼容色系别名
readonly gl_hong="$red"
readonly gl_lv="$green"
readonly gl_huang="$yellow"
readonly gl_bai="$none"
readonly gl_kjlan="$cyan"
readonly gl_zi="$magenta"
readonly gl_hui="$gray"

# ── 全局常量与路径 ──────────────────────────────────────────────
readonly SCRIPT_VERSION="188t9-Ultimate"
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

readonly SYSCTL_CONF="/etc/sysctl.d/99-net-tcp-tune.conf"

# ── 可变全局状态 ───────────────────────────────────────────────
SERVER_IP=""
REMARK_NAME="xp-reality"
BEST_SNI="www.microsoft.com"
SNI_JSON_ARRAY="\"www.microsoft.com\""
LISTEN_PORT=443
AUTO_MODE="0"

# ── 初始化系统目录 ─────────────────────────────────────────────
if ! mkdir -p "$CONFIG_DIR" "$DAT_DIR" "$SCRIPT_DIR" "$FLAGS_DIR" "$LOG_DIR" "$BACKUP_DIR" /etc/sysctl.d /etc/security 2>/dev/null; then
    true
fi
if ! touch "$USER_SNI_MAP" "$USER_TIME_MAP" 2>/dev/null; then
    true
fi

# ==============================================================================
# [ 区块 I: 基础工具、UI 渲染与全局容错护盾 ]
# ==============================================================================

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

# 显示宽度计算（中文占2列，ASCII占1列）
get_display_width() {
    local str="$1"
    local byte_len
    byte_len=$(printf '%s' "$str" | LC_ALL=C wc -c | tr -d ' ' || echo 0)
    local char_len=${#str}
    local extra=$((byte_len - char_len))
    local wide=$((extra / 2))
    echo $((char_len + wide))
}

# 统一日志函数
log_info()  { echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO:  $*" >> "$LOG_DIR/xray.log" 2>/dev/null || true; }
log_error() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$LOG_DIR/error.log" 2>/dev/null || true; }
log_warn()  { echo "[$(date +'%Y-%m-%d %H:%M:%S')] WARN:  $*" >> "$LOG_DIR/xray.log" 2>/dev/null || true; }

# 捕获异常中断
trap '_err_handler $? $LINENO "$BASH_COMMAND"' ERR
_err_handler() {
    local code=$1 line=$2 cmd=$3
    echo -e "\n${red}[SYSTEM_ABORT] 退出码:$code 行数:$line 故障指令:$cmd${none}" >&2
    log_error "EXIT=$code LINE=$line CMD=$cmd"
    rm -f /tmp/net-tcp-tune.* /tmp/sni_array.json /tmp/vless_inbound.json /tmp/ss_inbound.json 2>/dev/null || true
}

# 退出清理
cleanup_temp_files() {
    rm -f /tmp/net-tcp-tune.* /tmp/sni_array.json /tmp/vless_inbound.json /tmp/ss_inbound.json 2>/dev/null || true
}
trap cleanup_temp_files EXIT

# 终端断点停留
break_end() {
    if [[ "${AUTO_MODE:-0}" == "1" ]]; then return 0; fi
    echo ""
    echo -e "${green}操作完成。${none}"
    local _pause=""
    read -n 1 -s -r -p "按任意键继续返回菜单..." _pause || true
    echo ""
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${gl_hong}错误: ${gl_bai}核心操作被拒，需要 root 权限提升！"
        echo "指令: sudo bash $0"
        exit 1
    fi
}

validate_port() {
    local p="$1"
    if [[ -z "$p" ]]; then return 1; fi
    if [[ ! "$p" =~ ^[0-9]+$ ]]; then return 1; fi
    if ((p < 1 || p > 65535)); then return 1; fi
    if ss -tuln 2>/dev/null | grep -q ":${p} "; then
        error "端口 $p 已被系统占用。"
        return 1
    fi
    return 0
}

check_disk_space() {
    local required_gb=$1
    local required_space_mb=$((required_gb * 1024))
    local available_space_mb
    available_space_mb=$(df -m / 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")

    if [ "$available_space_mb" -lt "$required_space_mb" ]; then
        echo -e "${gl_huang}警告: ${gl_bai}磁盘空间不足！"
        echo "当前可用: $((available_space_mb/1024))G | 最低需求: ${required_gb}G"
        local continue_choice=""
        read -e -p "是否强制继续？(Y/N): " continue_choice || true
        case "${continue_choice:-}" in
            [Yy]) return 0 ;;
            *) return 1 ;;
        esac
    fi
    return 0
}

# ==============================================================================
# [ 区块 II: JSON 配置事务与回滚系统 (Xray) ]
# ==============================================================================

backup_config() {
    if [[ ! -f "$CONFIG" ]]; then return 0; fi
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    cp -f "$CONFIG" "$BACKUP_DIR/config_${ts}.json" 2>/dev/null || true
    ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
    log_info "配置已备份: config_${ts}.json"
}

restore_latest_backup() {
    local latest
    latest=$(ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | head -n 1 || true)
    if [[ -n "$latest" ]]; then
        cp -f "$latest" "$CONFIG" 2>/dev/null || true
        chmod 644 "$CONFIG" 2>/dev/null || true
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
    if [[ ! -f "$XRAY_BIN" ]]; then
        return 0
    fi
    local test_result
    test_result=$("$XRAY_BIN" -test -config "$target_config" 2>&1 || true)
    if echo "$test_result" | grep -qi "Configuration OK"; then
        return 0
    else
        error "配置文件校验未通过，Xray 核心拒绝加载。"
        echo -e "${gray}$test_result${none}"
        return 1
    fi
}

_safe_jq_write() {
    backup_config
    local tmp_raw
    tmp_raw=$(mktemp) || return 1
    local tmp="${tmp_raw}.json"
    mv -f "$tmp_raw" "$tmp" 2>/dev/null || true
    
    if jq "$@" "$CONFIG" > "$tmp" 2>/dev/null && jq empty "$tmp" 2>/dev/null; then
        if verify_xray_config "$tmp"; then
            mv -f "$tmp" "$CONFIG" 2>/dev/null || true
            chmod 644 "$CONFIG" 2>/dev/null || true
            return 0
        else
            rm -f "$tmp" 2>/dev/null || true
            restore_latest_backup
            return 1
        fi
    fi
    
    rm -f "$tmp" 2>/dev/null || true
    error "JSON 解析器遇到严重错误，写入已中止。"
    log_error "jq 语法执行失败，参数: $*"
    restore_latest_backup
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
        error "Xray 服务启动失败，请检查以下错误日志："
        hr
        journalctl -u xray.service --no-pager -n 15 2>/dev/null | awk '{print "    " $0}' || true
        hr
        restore_latest_backup
        local _pause=""
        read -e -p "请按 Enter 键返回..." _pause || true
        return 1
    fi
}

run_remote_script() {
    local url=$1
    local interpreter=${2:-bash}
    shift 2

    local tmp_file
    tmp_file=$(mktemp /tmp/net-tcp-tune.XXXXXX) || {
        echo -e "${red}❌ 无法创建临时文件${none}"
        return 1
    }

    if command -v curl &>/dev/null; then
        curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$tmp_file" 2>/dev/null || true
    elif command -v wget &>/dev/null; then
        wget -qO "$tmp_file" "$url" 2>/dev/null || true
    else
        rm -f "$tmp_file"
        return 1
    fi

    if [[ ! -s "$tmp_file" ]]; then
        rm -f "$tmp_file"
        return 1
    fi

    chmod +x "$tmp_file"
    "$interpreter" "$tmp_file" "$@"
    local rc=$?
    rm -f "$tmp_file"
    return $rc
}

# ==============================================================================
# [ 区块 III: 环境预装、Limits提权配置与系统净化 ]
# ==============================================================================

detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "${ID:-unknown}"
    else 
        echo "unknown"
    fi
}

pkg_install() {
    local list="$*"
    export DEBIAN_FRONTEND=noninteractive
    case "$(detect_os)" in
        ubuntu|debian)
            apt-get update -y >/dev/null 2>&1 || true
            apt-get install -y $list >/dev/null 2>&1 || true
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if command -v dnf &>/dev/null; then
                dnf makecache -y >/dev/null 2>&1 || true
                dnf install -y $list >/dev/null 2>&1 || true
            else
                yum makecache -y >/dev/null 2>&1 || true
                yum install -y $list >/dev/null 2>&1 || true
            fi
            ;;
        *)
            warn "未匹配到系统包管理器，请手动安装: $list"
            ;;
    esac
}

preflight() {
    if ((EUID != 0)); then
        die "此脚本需要 Root 权限执行。"
    fi
    if ! command -v systemctl >/dev/null 2>&1; then
        die "系统环境缺失 systemctl 组件。"
    fi

    local need="jq curl wget xxd unzip qrencode vnstat openssl coreutils sed e2fsprogs pkg-config iproute2 ethtool bc bison flex dwarves rsync python3 cpio zstd tar"
    local missing=""
    for p in $need; do
        if ! command -v "$p" >/dev/null 2>&1; then
            missing="$missing $p"
        fi
    done
    
    if [[ -n "$missing" ]]; then
        info "正在安装缺失的系统组件: $missing"
        pkg_install $missing
        systemctl start vnstat  >/dev/null 2>&1 || true
        systemctl enable vnstat >/dev/null 2>&1 || true
        systemctl start cron    >/dev/null 2>&1 || systemctl start crond >/dev/null 2>&1 || true
    fi

    if [[ -f "$SCRIPT_PATH" ]]; then
        cp -f "$SCRIPT_PATH" "$SYMLINK" 2>/dev/null || true
        chmod +x "$SYMLINK" 2>/dev/null || true
        hash -r 2>/dev/null || true
    fi

    SERVER_IP=$(
        curl -s -4 --connect-timeout 5 --max-time 10 https://api.ipify.org 2>/dev/null ||
        curl -s -4 --connect-timeout 5 --max-time 10 https://ifconfig.me  2>/dev/null ||
        curl -s -4 --connect-timeout 5 --max-time 10 https://icanhazip.com 2>/dev/null ||
        echo "获取失败"
    )
    if [[ "$SERVER_IP" == "获取失败" ]]; then
        warn "未能自动获取当前服务器的公网 IPv4 地址。"
    fi
}

# 核心修复：还原极限调优 Limits 提权 (Nice=-20)
fix_xray_systemd_limits() {
    local override_dir="/etc/systemd/system/xray.service.d"
    if ! mkdir -p "$override_dir" 2>/dev/null; then true; fi
    local limit_file="$override_dir/limits.conf"

    local current_nice="-20"
    local current_gogc="100"
    local current_oom="true"
    local current_affinity=""
    local current_gomaxprocs=""
    local current_buffer=""

    if [[ -f "$limit_file" ]]; then
        current_nice=$(awk -F'=' '/^Nice=/{print $2}' "$limit_file" 2>/dev/null | head -n 1 || echo "-20")
        current_gogc=$(awk -F'=' '/^Environment="GOGC=/{print $3}' "$limit_file" 2>/dev/null | tr -d '"' | head -n 1 || echo "100")
        if ! grep -q "^OOMScoreAdjust=" "$limit_file" 2>/dev/null; then
            current_oom="false"
        fi
        current_affinity=$(awk -F'=' '/^CPUAffinity=/{print $2}' "$limit_file" 2>/dev/null | head -n 1 || echo "")
        current_gomaxprocs=$(awk -F'=' '/^Environment="GOMAXPROCS=/{print $3}' "$limit_file" 2>/dev/null | tr -d '"' | head -n 1 || echo "")
        current_buffer=$(awk -F'=' '/^Environment="XRAY_RAY_BUFFER_SIZE=/{print $3}' "$limit_file" 2>/dev/null | tr -d '"' | head -n 1 || echo "")
    fi

    local total_mem
    total_mem=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo "1024")
    local go_mem_limit=$(( total_mem * 85 / 100 ))

    cat > "$limit_file" << EOF
[Service]
LimitNOFILE=1048576
LimitNPROC=512000
LimitMEMLOCK=infinity
Nice=${current_nice:-"-20"}
Environment="GOMEMLIMIT=${go_mem_limit}MiB"
Environment="GOGC=${current_gogc:-100}"
Restart=on-failure
RestartSec=10s
EOF

    if [[ "${current_oom:-true}" == "true" ]]; then
        cat >> "$limit_file" << 'EOF'
OOMScoreAdjust=-500
IOSchedulingClass=realtime
IOSchedulingPriority=2
EOF
    fi
    
    if [[ -n "$current_affinity" ]]; then echo "CPUAffinity=$current_affinity" >> "$limit_file"; fi
    if [[ -n "$current_gomaxprocs" ]]; then echo "Environment=\"GOMAXPROCS=$current_gomaxprocs\"" >> "$limit_file"; fi
    if [[ -n "$current_buffer" ]]; then echo "Environment=\"XRAY_RAY_BUFFER_SIZE=$current_buffer\"" >> "$limit_file"; fi

    systemctl daemon-reload >/dev/null 2>&1 || true
}

# ==============================================================================
# [ 区块 IV: 虚拟内存 Swap 智能池与强制 IPv4 ]
# ==============================================================================

enforce_ipv4_and_disable_ipv6() {
    echo -e "${gl_kjlan}=== 底层安全策略：锁定 IPv4 优先并切断 IPv6 泄露通道 ===${gl_bai}"
    echo -e "${gl_zi}[1/2] 重写寻址权重矩阵 (gai.conf)...${gl_bai}"
    cat > /etc/gai.conf << EOF
precedence ::ffff:0:0/96  100
precedence ::/0           10
precedence ::1/128        50
precedence fe80::/10      1
precedence fec0::/10      1
precedence fc00::/7       1
precedence 2002::/16      30
EOF
    if command -v nscd &> /dev/null; then systemctl restart nscd 2>/dev/null || true; fi
    if command -v resolvectl &> /dev/null; then resolvectl flush-caches 2>/dev/null || true; fi

    echo -e "${gl_zi}[2/2] 从内核系统总线上彻底焊死 IPv6 协议栈...${gl_bai}"
    cat > /etc/sysctl.d/99-disable-ipv6.conf << EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sysctl --system >/dev/null 2>&1 || true
    echo -e "${gl_lv}✅ 机器 IPv6 端口已封死，完全阻隔旁路探测！${gl_bai}"
}

check_and_suggest_swap() {
    local mem_total
    mem_total=$(free -m 2>/dev/null | awk 'NR==2{print $2}' || echo "1024")
    local swap_total
    swap_total=$(free -m 2>/dev/null | awk 'NR==3{print $2}' || echo "0")
    local recommended_swap=0
    local need_swap=0
    
    if [ "$mem_total" -lt 2048 ]; then need_swap=1; elif [ "$mem_total" -lt 4096 ] && [ "$swap_total" -eq 0 ]; then need_swap=1; fi
    if [ "$need_swap" -eq 0 ]; then return 0; fi
    
    if [ "$mem_total" -lt 512 ]; then recommended_swap=1024
    elif [ "$mem_total" -lt 1024 ]; then recommended_swap=$((mem_total * 2))
    elif [ "$mem_total" -lt 2048 ]; then recommended_swap=$((mem_total * 3 / 2))
    elif [ "$mem_total" -lt 4096 ]; then recommended_swap=$mem_total
    else recommended_swap=4096; fi
    
    echo -e "\n${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo -e "${gl_huang}雷达探测：物理内存较低，存在编译或高并发 OOM 的宕机风险！${gl_bai}"
    echo -e "  物理内存: ${gl_huang}${mem_total}MB${gl_bai} | 现存 Swap: ${gl_huang}${swap_total}MB${gl_bai}"
    echo -e "  系统建议配置防爆池大小: ${gl_lv}${recommended_swap}MB${gl_bai}"
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}\n"
    
    local confirm=""
    if [ "$AUTO_MODE" = "1" ]; then 
        confirm="Y"
    else 
        read -e -p "$(echo -e "${gl_huang}是否授予权限自动开辟虚拟缓冲地带？(Y/N): ${gl_bai}")" confirm || true
    fi

    if [[ "${confirm:-}" =~ ^[Yy]$ ]]; then
        add_swap "$recommended_swap"
    else
        echo -e "${gl_huang}已驳回建议，跳过 Swap 操作。${gl_bai}"
    fi
}

add_swap() {
    local new_swap=$1
    echo -e "${gl_zi}正在磁盘中强行划取 ${new_swap}MB 作为虚拟内存...${gl_bai}"
    swapoff /swapfile 2>/dev/null || true
    rm -f /swapfile 2>/dev/null || true
    if ! fallocate -l $(( (new_swap + 1) * 1024 * 1024 )) /swapfile 2>/dev/null; then
        dd if=/dev/zero of=/swapfile bs=1M count=$((new_swap + 1)) 2>/dev/null || true
    fi
    chmod 600 /swapfile 2>/dev/null || true
    mkswap /swapfile > /dev/null 2>&1 || true
    swapon /swapfile 2>/dev/null || true
    sed -i '/\/swapfile/d' /etc/fstab 2>/dev/null || true
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    if [ -f /etc/alpine-release ]; then
        echo "nohup swapon /swapfile" > /etc/local.d/swap.start 2>/dev/null || true
        chmod +x /etc/local.d/swap.start 2>/dev/null || true
        rc-update add local 2>/dev/null || true
    fi
    echo -e "${gl_lv}✅ 容错上限被强行拉升至 ${new_swap}MB！${gl_bai}"
}

manage_swap() {
    while true; do
        clear
        echo -e "${gl_kjlan}=== 防 OOM 虚拟内存(Swap)控制中心 ===${gl_bai}"
        local mem_total swap_info choice=""
        mem_total=$(free -m 2>/dev/null | awk 'NR==2{print $2}' || echo "N/A")
        swap_info=$(free -m 2>/dev/null | awk 'NR==3{used=$3; total=$2; if(total==0) p=0; else p=used*100/total; printf "%dM/%dM (%d%%)", used, total, p}' || echo "N/A")
        
        echo -e "物理内存定额:   ${gl_huang}${mem_total}MB${gl_bai}"
        echo -e "目前驻留 Swap:  ${gl_huang}$swap_info${gl_bai}"
        echo "------------------------------------------------"
        echo "1. 挂载定额: 1024M (1GB)"
        echo "2. 挂载定额: 2048M (2GB)"
        echo "3. 挂载定额: 4096M (4GB)"
        echo "4. 智能推算 (评估内存动态匹配)"
        echo "0. 回到主控台"
        echo "------------------------------------------------"
        read -e -p "决策输入: " choice || true
        case "${choice:-}" in
            1) add_swap 1024; break_end ;;
            2) add_swap 2048; break_end ;;
            3) add_swap 4096; break_end ;;
            4) check_and_suggest_swap; break_end ;;
            0) return ;;
            *) echo -e "${gl_hong}非法代码${gl_bai}"; sleep 1 ;;
        esac
    done
}
# ==============================================================================
# [ 区块 V: XanMod 内核极速管理与源码硬核编译 ]
# ==============================================================================

install_xanmod_kernel() {
    clear
    echo -e "${gl_kjlan}=== 安装预编译 XANMOD (main) 官方内核 ===${gl_bai}"
    echo -e "${gl_huang}警告: 此操作将更替 Linux 底层驱动，重启可能触发宕机！请确认有救援终端！${gl_bai}"
    
    local confirm=""
    if [ "${AUTO_MODE:-0}" = "1" ]; then 
        confirm="Y"
    else 
        read -e -p "你确信要执行物理级换核吗？(Y/n): " confirm || true
    fi
    
    if [[ ! "${confirm:-Y}" =~ ^[Yy]$ ]]; then 
        echo "指令解除"
        return 1
    fi
    
    if [[ "$(uname -m)" != "x86_64" ]]; then 
        echo -e "${gl_hong}❌ XanMod 官方库仅开放对 x86_64 的支持。${gl_bai}"
        break_end; return 1
    fi
    if [[ ! -f /etc/debian_version ]]; then 
        echo -e "${gl_hong}❌ 此部署通道仅能识别 Debian / Ubuntu 族系。${gl_bai}"
        break_end; return 1
    fi

    local cpu_level_script="/tmp/check_x86-64_psabi.sh"
    local cpu_level="1"
    if wget -qO "$cpu_level_script" https://dl.xanmod.org/check_x86-64_psabi.sh 2>/dev/null; then
        cpu_level=$(awk -f "$cpu_level_script" 2>/dev/null | grep -oE 'x86-64-v[1-4]' | grep -oE '[1-4]' | tail -n 1 || echo "1")
        rm -f "$cpu_level_script" 2>/dev/null || true
    fi
    echo -e "${gl_zi}底层芯片探勘: 适配至架构等级 v${cpu_level}${gl_bai}"
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y gnupg gnupg2 curl sudo wget e2fsprogs >/dev/null 2>&1 || true
    
    echo 'deb http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-kernel.list
    if ! wget -qO - https://dl.xanmod.org/gpg.key 2>/dev/null | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/xanmod-kernel.gpg; then
        echo -e "${gl_hong}❌ 通信加密凭证 GPG 获取失败，无法建立可信连接。${gl_bai}"
        return 1
    fi
    
    local pkg_name="linux-xanmod-x64v${cpu_level}"
    echo -e "正在向物理层强行注入内核包: ${gl_huang}$pkg_name${gl_bai} ..."
    apt-get update -y >/dev/null 2>&1 || true
    if ! apt-get install -y "$pkg_name"; then
        if [[ "$cpu_level" == "4" ]]; then 
            echo -e "${gl_huang}v4 旗舰版部署失败，自动退守 v3 防线...${gl_bai}"
            if ! apt-get install -y "linux-xanmod-x64v3"; then 
                echo -e "${gl_hong}❌ 备用内核亦无法写入，终止行动。${gl_bai}"
                return 1
            fi
        else
            echo -e "${gl_hong}❌ 内核写入进程崩溃。${gl_bai}"
            return 1
        fi
    fi
    
    if command -v update-grub >/dev/null 2>&1; then update-grub 2>/dev/null || true; fi
    echo -e "${gl_lv}✅ 核心包体灌装完毕！将在下次点火时正式接管系统！${gl_bai}"
    return 0
}

do_xanmod_compile() {
    clear
    title "Kernel.org 主线源码提取与 BBRv3 硬核编译"
    warn "源码编译对 CPU 会造成持续 30-60 分钟的高热压榨，期间如 SSH 断裂将前功尽弃。"
    warn "需要至少 15GB 的可用硬盘空间。"
    
    if ! check_disk_space 15; then
        break_end; return 1
    fi

    local confirm=""
    read -e -p "$(echo -e "${gl_huang}警告：确定要从沙盒执行底盘源码编译吗？(Y/N): ${gl_bai}")" confirm || true
    if [[ ! "${confirm:-}" =~ ^[Yy]$ ]]; then return 0; fi
    
    info "拉取铁匠铺依赖..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y build-essential bc bison flex libssl-dev libelf-dev libncurses-dev zstd git wget curl xz-utils ethtool numactl make pkg-config dwarves rsync python3 libdw-dev cpio >/dev/null 2>&1 || true
    
    check_and_suggest_swap

    info "潜入 Kernel 官方母库..."
    local BUILD_DIR="/usr/src"
    if ! cd $BUILD_DIR; then die "无法渗透入 /usr/src"; fi
    
    local KERNEL_URL KERNEL_FILE KERNEL_DIR
    KERNEL_URL=$(curl -s https://www.kernel.org/releases.json 2>/dev/null | jq -r '.releases[] | select(.type=="stable") | .tarball' 2>/dev/null | head -n 1 || echo "")
    if [[ -z "$KERNEL_URL" || "$KERNEL_URL" == "null" ]]; then
        warn "Kernel API 无法访问，使用兜底主线版本..."
        KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.10.tar.xz"
    fi
    
    KERNEL_FILE=$(basename "$KERNEL_URL")
    echo -e "${gl_zi}正在拉取源码包: $KERNEL_FILE${gl_bai}"
    wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE" || true

    if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
        warn "压缩包损坏，尝试二次拉取..."
        rm -f "$KERNEL_FILE" 2>/dev/null || true
        wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE" || true
        if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
            error "源码加密包被腐蚀，无法解压。请检查您的网络能否访问 kernel.org！"
            return 1
        fi
    fi

    echo -e "${gl_zi}解压内核源码...${gl_bai}"
    tar -xJf "$KERNEL_FILE"
    KERNEL_DIR=$(tar -tf "$KERNEL_FILE" | head -n 1 | cut -d/ -f1)
    if ! cd "$KERNEL_DIR"; then die "源码仓库解构失败"; fi

    info "嗅探现役硬件参数并装填 BBRv3 开关..."
    if [[ -f "/boot/config-$(uname -r)" ]]; then
        cp "/boot/config-$(uname -r)" .config
        info "成功捕获宿主机配置: /boot/config-$(uname -r)"
    else
        if modprobe configs 2>/dev/null && [[ -f /proc/config.gz ]]; then
            zcat /proc/config.gz > .config 2>/dev/null || true
            info "成功截取内存配置: /proc/config.gz"
        else
            warn "未找到底层引路文件！盲眼编译可能引发系统绝症。"
            local force_k=""
            read -e -p "$(echo -e "${gl_huang}是否强行生成默认配置赌一把？(y/N): ${gl_bai}")" force_k || true
            if [[ ! "${force_k:-}" =~ ^[Yy]$ ]]; then return 1; fi
            make defconfig 2>/dev/null || true
        fi
    fi
    
    echo -e "${gl_zi}修剪内核模块分支...${gl_bai}"
    make scripts >/dev/null 2>&1 || true
    ./scripts/config --enable CONFIG_TCP_CONG_BBR || true
    ./scripts/config --enable CONFIG_DEFAULT_BBR || true
    ./scripts/config --enable CONFIG_TCP_BBR3 2>/dev/null || true
    ./scripts/config --disable CONFIG_DRM_I915 || true
    ./scripts/config --disable CONFIG_NET_VENDOR_REALTEK || true
    ./scripts/config --disable CONFIG_NET_VENDOR_BROADCOM || true
    ./scripts/config --disable CONFIG_E100 || true
    ./scripts/config --disable SYSTEM_TRUSTED_KEYS || true
    ./scripts/config --disable SYSTEM_REVOCATION_KEYS || true
    ./scripts/config --disable DEBUG_INFO_BTF || true
    ./scripts/config --disable DEBUG_INFO || true
    yes "" | make olddefconfig >/dev/null 2>&1 || true

    info "火炉已被点燃，引擎即将满载狂飙..."
    local CPU RAM THREADS
    CPU=$(nproc 2>/dev/null || echo 1)
    RAM=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo 1024)
    THREADS=1
    if ((RAM >= 2000)); then THREADS=$CPU; elif ((RAM >= 1000)); then THREADS=2; fi
    
    echo -e "并发线程数设定为: ${gl_huang}${THREADS}${gl_bai}"
    if ! make -j$THREADS; then
        error "锻造炉发生坍塌！很可能是内存或硬盘不堪重负爆了。"
        break_end; return 1
    fi

    info "淬火成功！模块准备写入主板..."
    make modules_install >/dev/null 2>&1 || true
    make install >/dev/null 2>&1 || true

    local NEW_KERNEL_VER
    NEW_KERNEL_VER=$(make -s kernelrelease 2>/dev/null || echo "")
    if [[ -n "$NEW_KERNEL_VER" ]]; then
        info "正在为新内核生成引导映射: $NEW_KERNEL_VER"
        if command -v update-initramfs >/dev/null 2>&1; then
            update-initramfs -c -k "$NEW_KERNEL_VER" >/dev/null 2>&1 || true
        elif command -v dracut >/dev/null 2>&1; then
            dracut --force "/boot/initramfs-${NEW_KERNEL_VER}.img" "$NEW_KERNEL_VER" >/dev/null 2>&1 || true
        fi
    fi

    info "重建 GRUB 引导扇区..."
    if command -v update-grub >/dev/null 2>&1; then update-grub >/dev/null 2>&1 || true; fi

    cd /
    echo -e "${gl_zi}清理工业废料...${gl_bai}"
    rm -rf "$BUILD_DIR/linux-"* 2>/dev/null || true
    rm -rf "$BUILD_DIR/$KERNEL_FILE" 2>/dev/null || true

    echo -e "${gl_lv}✅ 内核源码被完美熔铸！宿主机将在 10 秒后强行脱机重启验证防线...${gl_bai}"
    sleep 10
    reboot
}

uninstall_xanmod() {
    echo -e "${gl_huang}警告: 您正在申请拆除核心装甲 (XanMod)${gl_bai}"
    local non_xanmod_kernels
    non_xanmod_kernels=$(dpkg -l 2>/dev/null | grep '^ii' | grep 'linux-image-' | grep -v 'xanmod' | grep -v 'dbg' | wc -l || echo "0")
    if [ "$non_xanmod_kernels" -eq 0 ]; then
        echo -e "${gl_hong}❌ 致命警告：系统中无备用引擎！继续拆除意味着自杀！${gl_bai}"
        echo -e "先打个底: ${gl_lv}apt install -y linux-image-amd64${gl_bai}"
        break_end; return 1
    fi
    
    local confirm=""
    read -e -p "你清楚自己在干什么并确定拔除 XanMod 吗？(y/N): " confirm || true
    if [[ "${confirm:-}" =~ ^[Yy]$ ]]; then
        apt purge -y 'linux-*xanmod*' >/dev/null 2>&1 || true
        update-grub >/dev/null 2>&1 || true
        rm -f /etc/apt/sources.list.d/xanmod-release.list /usr/share/keyrings/xanmod-archive-keyring.gpg 2>/dev/null || true
        echo -e "${gl_lv}✅ 装甲已被剥离。${gl_bai}"
    fi
    break_end
}

# ==============================================================================
# [ 区块 VI: TCP/网络列队综合突击调优 (Core Tuning) ]
# ==============================================================================

apply_tc_fq_now() {
    if ! command -v tc >/dev/null 2>&1; then return 0; fi
    local d dev
    for d in /sys/class/net/*; do
        [ -e "$d" ] || continue
        dev=$(basename "$d")
        case "$dev" in lo|docker*|veth*|br-*|virbr*|zt*|tailscale*|wg*|tun*|tap*) continue;; esac
        tc qdisc replace dev "$dev" root fq 2>/dev/null || true
    done
}

apply_mss_clamp() {
    local action=$1
    if ! command -v iptables >/dev/null 2>&1; then return 0; fi
    if [ "$action" = "enable" ]; then
        iptables -t mangle -C FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu >/dev/null 2>&1 || \
        iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
    else
        iptables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu >/dev/null 2>&1 || true
    fi
}

calculate_buffer_size() {
    local bandwidth=$1 region=${2:-asia}
    if ! [[ "$bandwidth" =~ ^[0-9]+$ ]] || [ "$bandwidth" -le 0 ] 2>/dev/null; then echo "16"; return 0; fi
    if [ "$region" = "overseas" ]; then
        if [ "$bandwidth" -lt 500 ]; then echo "16"
        elif [ "$bandwidth" -lt 1000 ]; then echo "32"
        else echo "64"; fi
    else
        if [ "$bandwidth" -lt 500 ]; then echo "8"
        elif [ "$bandwidth" -lt 1500 ]; then echo "16"
        else echo "24"; fi
    fi
}

bbr_configure_direct() {
    clear
    echo -e "${gl_kjlan}=== BBRv3 + FQ 直连/落地防拥塞突围优化 ===${gl_bai}"
    
    local bw="" bw_opt=""
    if [ "${AUTO_MODE:-0}" = "1" ]; then
        bw="1000"
    else
        echo -e "\n测定你的物理母机实际宽带上限:"
        echo " 1. 100 Mbps  (小型玩具)"
        echo " 2. 500 Mbps  (标准中产)"
        echo " 3. 1000 Mbps (1 Gbps - 大众款推荐)"
        echo " 4. 2500 Mbps (2.5 Gbps 野兽)"
        echo " 5. 手动打字输入"
        read -e -p "指定序号 [3]: " bw_opt || true
        case "${bw_opt:-3}" in
            1) bw="100" ;;
            2) bw="500" ;;
            4) bw="2500" ;;
            5) read -e -p "输入数字带宽 (Mbps): " bw || true; bw="${bw:-1000}" ;;
            *) bw="1000" ;;
        esac
    fi

    local region="overseas" reg_opt=""
    if [ "${AUTO_MODE:-0}" != "1" ]; then
        echo -e "\n确立你母机的物理地理坐标:"
        echo " 1. 欧美越洋机房 (忍受高延迟, 扩大漏斗阻力 - 默认)"
        echo " 2. 亚太临近地块 (享受低延迟, 加速收缩频次)"
        read -e -p "请选位 [1]: " reg_opt || true
        if [ "${reg_opt:-1}" == "2" ]; then region="asia"; fi
    fi

    local buffer_mb buffer_bytes
    buffer_mb=$(calculate_buffer_size "$bw" "$region")
    buffer_bytes=$((buffer_mb * 1024 * 1024))
    
    echo -e "${gl_lv}✅ 计算终了，缓冲池硬性界限敲定在: ${buffer_mb}MB${gl_bai}"
    
    # 清理陈旧的废件
    sed -i '/^net\.core\.rmem_max/s/^/# /' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/^net\.core\.wmem_max/s/^/# /' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/^net\.ipv4\.tcp_rmem/s/^/# /' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/^net\.ipv4\.tcp_wmem/s/^/# /' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/^net\.core\.default_qdisc/s/^/# /' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/^net\.ipv4\.tcp_congestion_control/s/^/# /' /etc/sysctl.conf 2>/dev/null || true

    mkdir -p /etc/sysctl.d 2>/dev/null || true
    cat > "$SYSCTL_CONF" << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=${buffer_bytes}
net.core.wmem_max=${buffer_bytes}
net.ipv4.tcp_rmem=4096 87380 ${buffer_bytes}
net.ipv4.tcp_wmem=4096 65536 ${buffer_bytes}

net.ipv4.tcp_tw_reuse=1
net.ipv4.ip_local_port_range=1024 65535
net.core.somaxconn=4096
net.ipv4.tcp_max_syn_backlog=8192
net.core.netdev_max_backlog=5000

net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_notsent_lowat=16384
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_max_tw_buckets=5000
net.ipv4.tcp_fastopen=3

net.ipv4.tcp_keepalive_time=300
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_probes=5
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.ipv4.tcp_syncookies=1

vm.swappiness=5
vm.dirty_ratio=15
vm.dirty_background_ratio=5
vm.overcommit_memory=1
vm.vfs_cache_pressure=50
kernel.sched_autogroup_enabled=0
kernel.numa_balancing=0
EOF

    sysctl -p "$SYSCTL_CONF" >/dev/null 2>&1 || true
    apply_tc_fq_now >/dev/null 2>&1 || true
    apply_mss_clamp enable >/dev/null 2>&1 || true

    mkdir -p /etc/security 2>/dev/null || true
    if ! grep -q "BBR - 文件描述符" /etc/security/limits.conf 2>/dev/null; then
        cat >> /etc/security/limits.conf << 'LIMITSEOF'
# BBR - 文件描述符
* soft nofile 524288
* hard nofile 524288
LIMITSEOF
    fi
    ulimit -n 524288 2>/dev/null || true

    if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
        echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
    fi

    local def_route clean_route
    def_route=$(ip route show default 2>/dev/null | head -1 || echo "")
    if [ -n "$def_route" ]; then
        clean_route=$(echo "$def_route" | sed 's/ initcwnd [0-9]*//g; s/ initrwnd [0-9]*//g')
        ip route change $clean_route initcwnd 32 initrwnd 32 2>/dev/null || true
    fi

    echo -e "${gl_lv}✅ Sysctl BBR 流控引擎已完全统治系统！${gl_bai}"
    if [ "${AUTO_MODE:-0}" != "1" ]; then break_end; fi
}

netfilter_conntrack_tune() {
    echo -e "${gl_kjlan}=== 底层防断流：Netfilter 并发追踪器扩容 ===${gl_bai}"
    if command -v modprobe >/dev/null 2>&1; then modprobe nf_conntrack 2>/dev/null || true; fi
    mkdir -p /etc/modules-load.d /etc/sysctl.d 2>/dev/null || true
    if ! grep -q '^nf_conntrack$' /etc/modules-load.d/conntrack.conf 2>/dev/null; then
        echo nf_conntrack >> /etc/modules-load.d/conntrack.conf
    fi
    cat >/etc/sysctl.d/60-netfilter-tune.conf <<'SYSC'
net.netfilter.nf_conntrack_max = 262144
SYSC
    sysctl --system >/dev/null 2>&1 || true
    echo -e "${gl_lv}✅ 握手跟踪器容量强行顶高，无惧大流量并发挤兑！${gl_bai}"
    if [ "${AUTO_MODE:-0}" != "1" ]; then break_end; fi
}

kernel_optimize_geek() {
    while true; do
        clear
        echo -e "${gl_kjlan}=== Linux 内核即时极客指令台 (仅限老手) ===${gl_bai}"
        echo -e "${gl_huang}警告：以下四个档位皆为即时发作指令，无视报错强行越权，重启则失忆退散！${gl_bai}"
        echo " --------------------"
        echo " 1. ⚔️ 星辰大海ヾ均衡姿态 (13万句柄/16M缓冲) - 适合日用"
        echo " 2. 🚀 Reality 终极狂暴 (50万句柄/12M压迫缓冲) - 无脑降延迟"
        echo " 3. 🛡️ Low-Spec 乞丐救命模式 (6万句柄/8M微池) - 1G内存防暴毙专供"
        echo " 4. 🌋 毁天灭地吞吐压榨版 (100万句柄/16M缓冲/25万深队列) - 烧卡测试专用"
        echo " 0. 撤离防线"
        echo " --------------------"
        local k_opt=""
        read -e -p "下达注入命令 [0-4]: " k_opt || true
        case "${k_opt:-}" in
            1) 
                ulimit -n 131072 2>/dev/null || true
                sysctl -w net.core.rmem_max=16777216 2>/dev/null || true
                sysctl -w net.core.wmem_max=16777216 2>/dev/null || true
                sysctl -w net.ipv4.tcp_rmem='4096 87380 16777216' 2>/dev/null || true
                sysctl -w net.ipv4.tcp_wmem='4096 65536 16777216' 2>/dev/null || true
                sysctl -w vm.swappiness=5 2>/dev/null || true
                sysctl -w net.ipv4.tcp_fastopen=3 2>/dev/null || true
                echo -e "${gl_lv}均衡型星辰战衣披戴成功！${gl_bai}"; break_end ;;
            2) 
                ulimit -n 524288 2>/dev/null || true
                sysctl -w net.ipv4.tcp_notsent_lowat=16384 2>/dev/null || true
                sysctl -w net.core.rmem_max=12582912 2>/dev/null || true
                sysctl -w net.core.wmem_max=12582912 2>/dev/null || true
                sysctl -w net.ipv4.tcp_rmem='4096 87380 12582912' 2>/dev/null || true
                sysctl -w net.ipv4.tcp_wmem='4096 64000 12582912' 2>/dev/null || true
                echo -e "${gl_lv}狂暴姿态全开！降维打击机制运转中！${gl_bai}"; break_end ;;
            3)
                ulimit -n 65535 2>/dev/null || true
                sysctl -w net.core.rmem_max=8388608 2>/dev/null || true
                sysctl -w net.core.wmem_max=8388608 2>/dev/null || true
                sysctl -w vm.swappiness=10 2>/dev/null || true
                echo -e "${gl_lv}救机气囊已弹出，稳定高于一切！${gl_bai}"; break_end ;;
            4)
                ulimit -n 1048576 2>/dev/null || true
                sysctl -w net.core.rmem_max=16777216 2>/dev/null || true
                sysctl -w net.core.wmem_max=16777216 2>/dev/null || true
                sysctl -w net.core.somaxconn=4096 2>/dev/null || true
                sysctl -w net.core.netdev_max_backlog=250000 2>/dev/null || true
                echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
                echo -e "${gl_lv}极限压榨模式拉满！${gl_bai}"; break_end ;;
            0) return ;;
            *) echo -e "${gl_hong}无法解析该代码${gl_bai}"; sleep 1 ;;
        esac
    done
}

do_txqueuelen_opt() {
    title "网卡发射队列 (TX Queue) 缩圈提速"
    local IP_CMD
    IP_CMD=$(command -v ip || echo "")
    if [[ -z "$IP_CMD" ]]; then error "环境干瘪，iproute2 工具丢失。"; read -rp "Enter..." _ || true; return 1; fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if [[ -z "$IFACE" ]]; then error "核心探针无法定位出口网卡设备！"; read -rp "Enter..." _ || true; return 1; fi
    
    $IP_CMD link set "$IFACE" txqueuelen 2000 2>/dev/null || true
    
    cat > /etc/systemd/system/txqueue.service << EOF
[Unit]
Description=Set Ultimate Low Latency TX Queue Length for Fast Path
After=network-online.target
Wants=network-online.target

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
    if [[ "$CHECK_QLEN" == "2000" ]]; then
        info "已切断冗余缓冲，网卡物理队列已被严格限定为 2000！"
    else
        warn "网卡底层固件不接受指令，修改未在物理层生效！"
    fi
    read -rp "按 Enter 返回..." _ || true
}

config_cake_advanced() {
    clear
    title "CAKE 高阶调度参数配置 (解决跨洋代理降速与排队失真)"
    
    local current_opts="无 (系统自适应默认)"
    if [[ -f "$CAKE_OPTS_FILE" ]]; then
        current_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
    fi
    echo -e "  系统当前已驻留的配置参数: ${cyan}${current_opts}${none}\n"
    
    local c_bw="" c_oh="" c_mpu="" rtt_sel="" diff_sel=""
    read -e -p "  [1] 指派带宽瓶颈死线 (例: 900Mbit, 不限速填 0): " c_bw || true
    read -e -p "  [2] 定义封包加密外壳厚度 (例: 48, 填 0 忽略): " c_oh || true
    read -e -p "  [3] 指定底层包头最小截断 MPU (例: 84, 填 0 忽略): " c_mpu || true
    
    echo "  [4] 选择高仿真网络延迟 RTT 模型: "
    echo "    1) internet  (85ms 默认标准波段)"
    echo "    2) oceanic   (300ms 跨洋深海电缆对冲模型 - 推荐)"
    echo "    3) satellite (1000ms 疯狂丢包卫星极限模型)"
    read -e -p "  选择 (默认 2): " rtt_sel || true
    
    local c_rtt=""
    case "${rtt_sel:-2}" in
        1) c_rtt="internet" ;;
        3) c_rtt="satellite" ;;
        *) c_rtt="oceanic" ;;
    esac
    
    echo "  [5] 确立数据流分流盲走体系: "
    echo "    1) diffserv4  (耗费算力解拆分析特征，极度高消耗)"
    echo "    2) besteffort (忽略包特征直接盲推，最低延迟王者 - 推荐)"
    read -e -p "  选择 (默认 2): " diff_sel || true
    
    local c_diff=""
    case "${diff_sel:-2}" in
        1) c_diff="diffserv4" ;;
        *) c_diff="besteffort" ;;
    esac

    local final_opts=""
    if [[ -n "${c_bw:-}" && "${c_bw:-}" != "0" ]]; then final_opts="$final_opts bandwidth ${c_bw}"; fi
    if [[ -n "${c_oh:-}" && "${c_oh:-}" != "0" ]]; then final_opts="$final_opts overhead ${c_oh}"; fi
    if [[ -n "${c_mpu:-}" && "${c_mpu:-}" != "0" ]]; then final_opts="$final_opts mpu ${c_mpu}"; fi
    
    final_opts="$final_opts $c_rtt $c_diff"
    final_opts="${final_opts#"${final_opts%%[! ]*}"}"
    
    if [[ -z "$final_opts" ]]; then
        rm -f "$CAKE_OPTS_FILE" 2>/dev/null || true
        info "已强行抹除所有 CAKE 个性化魔改指令。"
    else
        echo "$final_opts" > "$CAKE_OPTS_FILE"
        info "智能调度指令集锁定：$final_opts"
    fi
    
    modprobe sch_cake 2>/dev/null || true
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if [[ -n "$IFACE" ]]; then
        tc qdisc replace dev "$IFACE" root cake $final_opts 2>/dev/null || true
        if tc qdisc show dev "$IFACE" 2>/dev/null | grep -q "cake"; then
            info "自检极佳：核心 CAKE 调度器已极其稳固地接管出口网卡！"
        else
            warn "危机：物理层网卡队列未反馈 CAKE 状态，请确保内核支持 sch_cake！"
        fi
    fi
    read -rp "Enter 继续..." _ || true
}

# ==============================================================================
# [ 区块 VII: SNI 连通性测试矩阵 ]
# ==============================================================================

run_sni_scanner() {
    title "SNI 连通性测试 (纯 TCP 延迟与可用性验证)"
    info "扫描进行中... (按回车键可随时中止并结算已扫描节点)\n"
    
    if ! mkdir -p "$CONFIG_DIR" 2>/dev/null; then true; fi
    
    local sni_list=(
        "www.apple.com" "support.apple.com" "developer.apple.com" "id.apple.com" "icloud.apple.com"
        "www.microsoft.com" "login.microsoftonline.com" "portal.azure.com" "support.microsoft.com" "office.com"
        "www.intel.com" "downloadcenter.intel.com" "ark.intel.com"
        "www.amd.com" "drivers.amd.com"
        "www.dell.com" "support.dell.com"
        "www.hp.com" "support.hp.com" "developers.hp.com"
        "www.bmw.com" "www.mercedes-benz.com" "global.toyota" "www.honda.com" "www.volkswagen.com"
        "www.nike.com" "www.adidas.com" "www.zara.com" "www.ikea.com"
        "www.shell.com" "www.bp.com" "www.ge.com"
        "www.hsbc.com" "www.morganstanley.com"
        "www.msc.com"
        "www.sony.com" "www.canon.com" "www.nintendo.com"
        "www.unilever.com" "www.loreal.com"
        "www.hermes.com" "www.louisvuitton.com" "www.dior.com" "www.gucci.com"
        "www.coca-cola.com" "www.pepsico.com" "www.nestle.com"
        "www.tesla.com" "www.ford.com" "www.audi.com" "www.hyundai.com" "www.nissan-global.com" "www.porsche.com"
        "s0.awsstatic.com"
        "www.nvidia.com" "www.samsung.com" "www.oracle.com"
        "addons.mozilla.org"
        "www.airbnb.com.sg"
        "mit.edu" "stanford.edu"
        "www.lufthansa.com" "www.singaporeair.com"
        "www.specialized.com"
        "www.logitech.com" "www.razer.com" "www.corsair.com"
        "www.zoom.us" "www.adobe.com" "www.autodesk.com" "www.salesforce.com" "www.cisco.com" "www.ibm.com" "www.qualcomm.com"
        "www.target.com" "www.walmart.com" "www.homedepot.com" "www.lowes.com" "www.walgreens.com" "www.costco.com" "www.cvs.com" "www.bestbuy.com" "www.kroger.com"
        "www.mcdonalds.com" "www.starbucks.com"
        "www.jnj.com" "www.pg.com"
        "www.puma.com" "www.underarmour.com" "www.hm.com" "www.uniqlo.com" "www.gap.com"
        "www.rolex.com" "www.chanel.com" "www.prada.com" "www.burberry.com" "www.cartier.com" "www.estee-lauder.com" "www.shiseido.com"
        "www.pfizer.com" "www.novartis.com" "www.roche.com" "www.sanofi.com" "www.merck.com" "www.bayer.com" "www.gsk.com"
        "www.boeing.com" "www.airbus.com" "www.lockheedmartin.com" "www.geaerospace.com"
        "www.siemens.com" "www.bosch.com" "www.hitachi.com" "www.schneider-electric.com" "www.abb.com" "www.caterpillar.com" "www.john-deere.com" "www.mitsubishicorp.com"
        "www.sony.net" "www.panasonic.com" "www.sharp.com" "www.lg.com" "www.lenovo.com" "www.huawei.com" "www.asus.com" "www.acer.com" "www.delltechnologies.com" "www.hpe.com" "www.lenovo.com.cn"
        "www.tiktok.com"
        "www.spotify.com"
        "www.netflix.com" "www.hulu.com" "www.disneyplus.com"
    )

    local sni_string
    sni_string=$(printf "%s\n" "${sni_list[@]}")
    if command -v shuf >/dev/null 2>&1; then
        sni_string=$(echo "$sni_string" | shuf)
    else
        sni_string=$(echo "$sni_string" | awk 'BEGIN{srand()} {print rand()"\t"$0}' | sort -n | cut -f2-)
    fi

    local tmp_sni
    tmp_sni=$(mktemp) || true
    
    local scan_count=0

    for sni in $sni_string; do
        if read -t 0.1 -n 1 _dummy 2>/dev/null || [ $? -eq 0 ]; then
            echo -e "\n${yellow}[INFO] 用户取消，停止扫描。${none}"
            break
        fi

        local time_raw ms
        time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni" 2>/dev/null || echo "0")
        ms=$(echo "$time_raw" | awk '{print int($1 * 1000)}')

        if ((ms > 0)); then
            if curl -sI -m 2 --connect-timeout 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray"; then
                echo -e " ${gray}[SKIP]${none} $sni (命中 Cloudflare)"
                continue
            fi
            
            local p_type="NORM"
            local status_cn="${green}连通性正常${none}"
            
            echo -e " ${green}[OK]${none} $sni : TCP 延迟 ${yellow}${ms}ms${none} | 状态: $status_cn"
            echo "$ms $sni $p_type" >> "$tmp_sni"
        fi

        scan_count=$((scan_count + 1))
    done

    if [[ -s "$tmp_sni" ]]; then
        grep " NORM$" "$tmp_sni" | sort -n | head -n 20 | awk '{print $2, $1}' > "$SNI_CACHE_FILE" || true
    else
        error "未发现可用节点，回退为默认配置。"
        echo "www.microsoft.com 999" > "$SNI_CACHE_FILE"
    fi
    
    rm -f "$tmp_sni" 2>/dev/null || true
}

verify_sni_strict() {
    local target="$1"
    info "正在检查 $target 的 TLS 1.3 / ALPN / OCSP 支持情况..."
    
    local out
    out=$(echo "Q" | timeout 5 openssl s_client -connect "$target:443" -alpn h2 -tls1_3 -status 2>&1 || echo "")
    
    local pass=0
    
    if ! echo "$out" | grep -qi "TLSv1.3"; then
        warn "验证失败: 不支持 TLS v1.3"
        pass=1
    fi
    if ! echo "$out" | grep -qi "ALPN.*h2"; then
        warn "验证失败: 不支持 ALPN h2"
        pass=1
    fi
    if ! echo "$out" | grep -qi "OCSP response:"; then
        warn "验证失败: 未返回 OCSP 状态"
        pass=1
    fi
    
    if ((pass != 0)); then
        error "目标特征不完整，存在安全隐患。"
    else
        info "目标特征验证通过。"
    fi
    
    return $pass
}

choose_sni() {
    while true; do
        if [[ -f "$SNI_CACHE_FILE" ]]; then
            echo -e "\n  ${cyan}【已缓存优质 SNI 列表】${none}"
            local idx=1
            
            while read -r s t; do
                echo -e "  $idx) $s (TCP 延迟: ${cyan}${t}ms${none})"
                idx=$((idx + 1))
            done < "$SNI_CACHE_FILE"
            
            echo -e "  ${yellow}r) 重新运行扫描${none}"
            echo "  m) 启用多选模式 (输入多个序号，空格分隔)"
            echo "  0) 手动输入域名"
            
            local sel=""
            read -rp "  请选择对应操作或节点: " sel || true
            sel=${sel:-1}
            
            case "$sel" in
                q|Q) return 1 ;;
                r|R) run_sni_scanner; continue ;;
                m|M)
                    local m_sel=""
                    read -rp "请输入所需序号 (例如 1 3 5，或 all): " m_sel || true
                    local arr=()
                    
                    if [[ "${m_sel:-}" == "all" ]]; then
                        while read -r p_sni p_rest; do
                            if [[ -n "$p_sni" ]]; then
                                arr+=("$p_sni")
                            fi
                        done < "$SNI_CACHE_FILE"
                    else
                        for i in ${m_sel:-}; do
                            local picked
                            picked=$(awk "NR==$i {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "")
                            if [[ -n "$picked" ]]; then
                                arr+=("$picked")
                            fi
                        done
                    fi
                    
                    if ((${#arr[@]} == 0)); then
                        error "无效选择，请重新输入。"
                        continue
                    fi
                    
                    BEST_SNI="${arr[0]}"
                    local jq_args=()
                    for s in "${arr[@]}"; do
                        jq_args+=("\"$s\"")
                    done
                    SNI_JSON_ARRAY=$(IFS=,; echo "${jq_args[*]}")
                    ;;
                0)
                    local d=""
                    read -rp "请输入自定义域名: " d || true
                    BEST_SNI=${d:-www.microsoft.com}
                    SNI_JSON_ARRAY="\"$BEST_SNI\""
                    ;;
                *)
                    if [[ "$sel" =~ ^[0-9]+$ ]]; then
                        local picked
                        picked=$(awk "NR==$sel {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "")
                        if [[ -n "$picked" ]]; then
                            BEST_SNI="$picked"
                        else
                            BEST_SNI=$(awk "NR==1 {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "www.microsoft.com")
                        fi
                        SNI_JSON_ARRAY="\"$BEST_SNI\""
                    else
                        error "输入有误"; continue
                    fi
                    ;;
            esac
            
            if verify_sni_strict "$BEST_SNI"; then
                break
            else
                warn "目标不符合最佳实践标准。"
                local force_use=""
                read -rp "强制使用该域名？(y/n): " force_use || true
                if [[ "${force_use:-}" =~ ^[yY]$ ]]; then
                    break
                else
                    continue
                fi
            fi
        else
            run_sni_scanner
        fi
    done
    return 0
}
# ==============================================================================
# [ 区块 VIII: Xray 应用层高级调优引擎 (JSON 隔离操作) ]
# ==============================================================================

_turn_on_app() {
    # 采用安全护盾语法 (|=) 杜绝数组崩溃
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
    if [[ -n "$has_reality" ]]; then
        _safe_jq_write '
          (.inbounds[]? | select(.protocol == "vless" and .streamSettings.security == "reality")) |= (
              .streamSettings.realitySettings = (.streamSettings.realitySettings // {}) |
              .streamSettings.realitySettings.maxTimeDiff = 60000
          )
        '
    fi
    
    if [[ "$(check_dnsmasq_state)" == "true" ]]; then
        _safe_jq_write '.dns = {"servers": ["127.0.0.1"], "queryStrategy": "UseIP"}'
    else
        _safe_jq_write '.dns = {"servers": ["https://8.8.8.8/dns-query", "https://1.1.1.1/dns-query", "https://doh.opendns.com/dns-query"], "queryStrategy": "UseIP"}'
    fi
    
    _safe_jq_write '
      .policy = {
          "levels": {"0": {"handshake": 3, "connIdle": 60}},
          "system": {"statsInboundDownlink": false, "statsInboundUplink": false}
      }
    '
    
    _toggle_affinity_on
    
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if [[ -f "$limit_file" ]]; then
        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
        echo "Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" >> "$limit_file"
        
        local TOTAL_MEM
        TOTAL_MEM=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo "1024")
        local DYNAMIC_GOGC=100
        if ((TOTAL_MEM >= 1800)); then 
            DYNAMIC_GOGC=1000
        elif ((TOTAL_MEM >= 900)); then 
            DYNAMIC_GOGC=500
        else 
            DYNAMIC_GOGC=300
        fi
        
        sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=$DYNAMIC_GOGC\"/" "$limit_file" 2>/dev/null || true
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

_turn_off_app() {
    # 采用安全护盾语法 (|=) 杜绝数组崩溃，加入 sniffing 容错免疫暴力删减
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
    if [[ -f "$limit_file" ]]; then
        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
        sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=100\"/" "$limit_file" 2>/dev/null || true
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

# ==============================================================================
# [ 区块 IX: 全域 28 项状态调度面板 ]
# ==============================================================================

do_app_level_tuning_menu() {
    while true; do
        clear
        title "应用层与系统级高级参数调优 (25项)"
        if [[ ! -f "$CONFIG" ]]; then 
            error "系统配置文件未找到，请先执行部署。"
            local _pause=""
            read -e -p "按 Enter 返回..." _pause || true
            return
        fi

        # 状态探针获取
        local out_fastopen out_keepalive sniff_status dns_status policy_status affinity_state mph_state maxtime_state routeonly_status buffer_state
        out_fastopen=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpFastOpen // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        out_keepalive=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpKeepAliveIdle // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        sniff_status=$(check_sniff_state)
        dns_status=$(jq -r '.dns.queryStrategy // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        policy_status=$(jq -r '.policy.levels["0"].connIdle // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        affinity_state=$(check_affinity_state)
        mph_state=$(check_mph_state)
        maxtime_state=$(check_maxtime_state)
        routeonly_status=$(check_routeonly_state)
        buffer_state=$(check_buffer_state)
        
        local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
        local gc_status="未知"
        if [[ -f "$limit_file" ]]; then
            gc_status=$(awk -F'=' '/^Environment="GOGC=/ {print $3}' "$limit_file" 2>/dev/null | tr -d '"' | head -n 1 || echo "100")
            gc_status=${gc_status:-"默认 100"}
        fi

        local dnsmasq_state thp_state mtu_state cpu_state ring_state zram_state journal_state prio_state cake_state irq_state gso_off_state ackfilter_state ecn_state wash_state
        dnsmasq_state=$(check_dnsmasq_state)
        thp_state=$(check_thp_state)
        mtu_state=$(check_mtu_state)
        cpu_state=$(check_cpu_state)
        ring_state=$(check_ring_state)
        zram_state=$(check_zram_state)
        journal_state=$(check_journal_state)
        prio_state=$(check_process_priority_state)
        cake_state=$(check_cake_state)
        irq_state=$(check_irq_state)
        gso_off_state=$(check_gso_off_state)
        ackfilter_state=$(check_ackfilter_state)
        ecn_state=$(check_ecn_state)
        wash_state=$(check_wash_state)

        # 统计未开启项
        local app_off_count=0
        if [[ "$out_fastopen" != "true" ]]; then app_off_count=$((app_off_count + 1)); fi
        if [[ "$out_keepalive" != "30" ]]; then app_off_count=$((app_off_count + 1)); fi
        if [[ "$sniff_status" != "true" ]]; then app_off_count=$((app_off_count + 1)); fi
        if [[ "$dns_status" != "UseIP" ]]; then app_off_count=$((app_off_count + 1)); fi
        if [[ "$gc_status" == "默认 100" || "$gc_status" == "100" ]]; then app_off_count=$((app_off_count + 1)); fi
        if [[ "$policy_status" != "60" ]]; then app_off_count=$((app_off_count + 1)); fi
        if [[ "$affinity_state" != "true" ]]; then app_off_count=$((app_off_count + 1)); fi
        if [[ "$mph_state" != "true" ]]; then app_off_count=$((app_off_count + 1)); fi
        if [[ "$routeonly_status" != "true" ]]; then app_off_count=$((app_off_count + 1)); fi
        if [[ "$buffer_state" != "true" ]]; then app_off_count=$((app_off_count + 1)); fi
        
        local has_reality
        has_reality=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .protocol' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
        if [[ -n "$has_reality" ]]; then 
            if [[ "$maxtime_state" != "true" ]]; then 
                app_off_count=$((app_off_count + 1))
            fi
        fi

        local sys_off_count=0
        if [[ "$dnsmasq_state" == "false" ]]; then sys_off_count=$((sys_off_count + 1)); fi
        if [[ "$thp_state" == "false" ]]; then sys_off_count=$((sys_off_count + 1)); fi
        if [[ "$mtu_state" == "false" ]]; then sys_off_count=$((sys_off_count + 1)); fi
        if [[ "$cpu_state" == "false" ]]; then sys_off_count=$((sys_off_count + 1)); fi
        if [[ "$ring_state" == "false" ]]; then sys_off_count=$((sys_off_count + 1)); fi
        if [[ "$zram_state" == "false" ]]; then sys_off_count=$((sys_off_count + 1)); fi
        if [[ "$journal_state" == "false" ]]; then sys_off_count=$((sys_off_count + 1)); fi
        if [[ "$prio_state" == "false" ]]; then sys_off_count=$((sys_off_count + 1)); fi
        if [[ "$cake_state" == "false" ]]; then sys_off_count=$((sys_off_count + 1)); fi
        if [[ "$irq_state" == "false" ]]; then sys_off_count=$((sys_off_count + 1)); fi
        if [[ "$gso_off_state" == "false" ]]; then sys_off_count=$((sys_off_count + 1)); fi
        if [[ "$ackfilter_state" == "false" ]]; then sys_off_count=$((sys_off_count + 1)); fi
        if [[ "$ecn_state" == "false" ]]; then sys_off_count=$((sys_off_count + 1)); fi
        if [[ "$wash_state" == "false" ]]; then sys_off_count=$((sys_off_count + 1)); fi

        # 状态文案
        local s1; if [[ "$out_fastopen" == "true" ]]; then s1="${cyan}开启${none}"; else s1="${gray}关闭${none}"; fi
        local s2; if [[ "$out_keepalive" == "30" ]]; then s2="${cyan}开启 (30s/15s)${none}"; else s2="${gray}系统默认${none}"; fi
        local s3; if [[ "$sniff_status" == "true" ]]; then s3="${cyan}开启${none}"; else s3="${gray}关闭${none}"; fi
        local s4; if [[ "$dns_status" == "UseIP" ]]; then s4="${cyan}开启${none}"; else s4="${gray}关闭${none}"; fi
        local s6; if [[ "$policy_status" == "60" ]]; then s6="${cyan}开启 (闲置 60s)${none}"; else s6="${gray}系统默认 300s${none}"; fi
        local s7; if [[ "$affinity_state" == "true" ]]; then s7="${cyan}绑定单核${none}"; else s7="${gray}系统调度${none}"; fi
        local s8; if [[ "$mph_state" == "true" ]]; then s8="${cyan}MPH 路由开启${none}"; else s8="${gray}常规路由${none}"; fi
        
        local s9
        if [[ -z "$has_reality" ]]; then 
            s9="${gray}N/A${none}"
        else 
            if [[ "$maxtime_state" == "true" ]]; then s9="${cyan}开启限制 (60s)${none}"; else s9="${gray}未开启${none}"; fi
        fi
        
        local s10; if [[ "$routeonly_status" == "true" ]]; then s10="${cyan}直通开启${none}"; else s10="${gray}默认全量嗅探${none}"; fi
        local s11; if [[ "$buffer_state" == "true" ]]; then s11="${cyan}64KB 缓冲池${none}"; else s11="${gray}默认内存分配${none}"; fi
        
        local s12; if [[ "$dnsmasq_state" == "true" ]]; then s12="${cyan}本地缓存 (0.1ms)${none}"; else s12="${gray}原生 DoH${none}"; fi
        local s13; if [[ "$thp_state" == "true" ]]; then s13="${cyan}已关闭 THP${none}"; elif [[ "$thp_state" == "unsupported" ]]; then s13="${gray}不支持${none}"; else s13="${gray}系统默认开启${none}"; fi
        local s14; if [[ "$mtu_state" == "true" ]]; then s14="${cyan}MTU 探测开启${none}"; elif [[ "$mtu_state" == "unsupported" ]]; then s14="${gray}不支持${none}"; else s14="${gray}未开启${none}"; fi
        local s15; if [[ "$cpu_state" == "true" ]]; then s15="${cyan}Performance 模式${none}"; elif [[ "$cpu_state" == "unsupported" ]]; then s15="${gray}不支持${none}"; else s15="${gray}节能调度${none}"; fi
        local s16; if [[ "$ring_state" == "true" ]]; then s16="${cyan}队列已收缩${none}"; elif [[ "$ring_state" == "unsupported" ]]; then s16="${gray}不支持${none}"; else s16="${gray}系统默认缓冲${none}"; fi
        local s17; if [[ "$zram_state" == "true" ]]; then s17="${cyan}已挂载 ZRAM${none}"; elif [[ "$zram_state" == "unsupported" ]]; then s17="${gray}不支持${none}"; else s17="${gray}未启用${none}"; fi
        local s18; if [[ "$journal_state" == "true" ]]; then s18="${cyan}纯内存日志${none}"; elif [[ "$journal_state" == "unsupported" ]]; then s18="${gray}不支持${none}"; else s18="${gray}磁盘 I/O 写入${none}"; fi
        local s19; if [[ "$prio_state" == "true" ]]; then s19="${cyan}进程提权 (OOM防杀)${none}"; else s19="${gray}默认优先级${none}"; fi
        local s20; if [[ "$cake_state" == "true" ]]; then s20="${cyan}CAKE 调度开启${none}"; else s20="${gray}默认 FQ 队列${none}"; fi
        local s21; if [[ "$irq_state" == "true" ]]; then s21="${cyan}网卡硬中断隔离${none}"; elif [[ "$irq_state" == "unsupported" ]]; then s21="${gray}不支持 (单核)${none}"; else s21="${gray}系统负载均衡${none}"; fi
        
        local s22
        if [[ "$gso_off_state" == "true" ]]; then 
            s22="${cyan}硬件卸载禁用 (低延迟)${none}"
        elif [[ "$gso_off_state" == "unsupported" ]]; then 
            s22="${gray}不支持 (底层驱动锁死)${none}"
        else 
            s22="${gray}未设置 (系统默认聚合)${none}"
        fi
        
        local s23; if [[ "$ackfilter_state" == "true" ]]; then s23="${cyan}ACK 过滤开启${none}"; else s23="${gray}未开启${none}"; fi
        local s24; if [[ "$ecn_state" == "true" ]]; then s24="${cyan}ECN 拥塞标记开启${none}"; else s24="${gray}未开启 (暴力丢包)${none}"; fi
        local s25; if [[ "$wash_state" == "true" ]]; then s25="${cyan}Wash 报文清洗开启${none}"; else s25="${gray}未开启${none}"; fi

        echo -e "  ${magenta}--- Xray 应用层高级调优 (1-11) ---${none}"
        echo -e "  1)  并发提速策略 (tcpNoDelay/FastOpen)                | 状态: $s1"
        echo -e "  2)  Socket 智能保活机制 (KeepAlive)                   | 状态: $s2"
        echo -e "  3)  嗅探引擎优化 (metadataOnly)                       | 状态: $s3"
        echo -e "  4)  内置并发 DoH 路由分发 (Xray Native DNS)           | 状态: $s4"
        echo -e "  5)  配置 GOGC 内存阶梯分配与回收策略                  | 设定: ${cyan}${gc_status}${none}"
        echo -e "  6)  连接生命周期快速回收策略 (Policy)                 | 状态: $s6"
        echo -e "  7)  Xray 进程绑核与线程锁定 (CPUAffinity/GOMAXPROCS)  | 状态: $s7"
        echo -e "  8)  MPH (Minimal Perfect Hash) 路由降维匹配           | 状态: $s8"
        echo -e "  9)  Reality 防重放时间偏移拦截 (maxTimeDiff)          | 状态: $s9"
        echo -e "  10) 零拷贝旁路盲转发 (routeOnly)                      | 状态: $s10"
        echo -e "  11) 大容量缓冲池配置 (RAY_BUFFER_SIZE=64)             | 状态: $s11"
        echo -e ""
        echo -e "  ${magenta}--- Linux 系统及内核高级调优 (12-25) ---${none}"
        echo -e "  12) 本地 DNS 高速缓存引擎 (Dnsmasq)                   | 状态: $s12"
        echo -e "  13) 内存透明大页管理 (THP Defrag)                     | 状态: $s13"
        echo -e "  14) TCP MTU 黑洞智能探测 (Probing)                    | 状态: $s14"
        echo -e "  15) CPU 高性能调度锁定 (Performance Governor)         | 状态: $s15"
        echo -e "  16) 网卡环形缓冲区调优 (Ring Buffer)                  | 状态: $s16"
        echo -e "  17) 挂载高性能内存压缩分区 (ZRAM)                     | 状态: $s17"
        echo -e "  18) 日志系统 I/O 隔离 (Journald Volatile)             | 状态: $s18"
        echo -e "  19) 进程防中断与 I/O 提权 (OOM/Priority)              | 状态: $s19"
        echo -e "  20) CAKE 智能拥塞管理队列 (取代 FQ)                   | 状态: $s20"
        echo -e "  21) 网卡硬中断物理绑定 (IRQ Pinning)                  | 状态: $s21"
        echo -e "  22) 网卡硬件卸载状态控制 (GSO/GRO)                    | 状态: $s22"
        echo -e "  23) CAKE 上行确认包过滤 (ACK-Filter)                  | 状态: $s23"
        echo -e "  24) CAKE 显式拥塞控制 (ECN Marking)                   | 状态: $s24"
        echo -e "  25) CAKE 报文特征清洗 (Wash)                          | 状态: $s25"
        echo -e "  "
        echo -e "  ${cyan}26) 批量执行: 开启/恢复 应用层设置 (1-11 项)${none}"
        echo -e "  ${yellow}27) 批量执行: 开启/恢复 系统级设置 (12-25 项)${none}"
        echo -e "  ${red}28) 一键应用全量网络调优并重启系统${none}"
        echo "  0) 返回上一级菜单"
        hr
        local app_opt=""
        read -e -p "请选择需要调整的配置项: " app_opt || true

        if [[ "${app_opt:-}" == "0" || -z "${app_opt:-}" ]]; then return; fi
        
        case "$app_opt" in
            1)
                if [[ "$out_fastopen" == "true" ]]; then
                    _safe_jq_write '
                      (.outbounds[]? | select(.protocol == "freedom")) |= del(.streamSettings.sockopt.tcpNoDelay, .streamSettings.sockopt.tcpFastOpen) |
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= del(.streamSettings.sockopt.tcpNoDelay, .streamSettings.sockopt.tcpFastOpen)
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
                local _pause=""
                read -e -p "配置已更新，按 Enter 继续..." _pause || true
                ;;
            2)
                if [[ "$out_keepalive" == "30" ]]; then
                    _safe_jq_write '
                      (.outbounds[]? | select(.protocol == "freedom")) |= del(.streamSettings.sockopt.tcpKeepAliveIdle, .streamSettings.sockopt.tcpKeepAliveInterval) |
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= del(.streamSettings.sockopt.tcpKeepAliveIdle, .streamSettings.sockopt.tcpKeepAliveInterval)
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
                local _pause=""
                read -e -p "配置已更新，按 Enter 继续..." _pause || true
                ;;
            3)
                if [[ "$sniff_status" == "true" ]]; then
                    _safe_jq_write '(.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= (.sniffing.metadataOnly = false)'
                else
                    _safe_jq_write '(.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= (.sniffing = (.sniffing // {}) | .sniffing.metadataOnly = true)'
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _pause=""
                read -e -p "配置已更新，按 Enter 继续..." _pause || true
                ;;
            4)
                if [[ "$dns_status" == "UseIP" ]]; then
                    _safe_jq_write 'del(.dns)'
                else
                    if [[ "$(check_dnsmasq_state)" == "true" ]]; then
                        _safe_jq_write '.dns = {"servers":["127.0.0.1"], "queryStrategy":"UseIP"}'
                    else
                        _safe_jq_write '.dns = {"servers":["https://8.8.8.8/dns-query","https://1.1.1.1/dns-query"], "queryStrategy":"UseIP"}'
                    fi
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _pause=""
                read -e -p "配置已更新，按 Enter 继续..." _pause || true
                ;;
            5)
                local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
                if [[ -f "$limit_file" ]]; then
                    local TOTAL_MEM
                    TOTAL_MEM=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo "1024")
                    local DYNAMIC_GOGC=100
                    if ((TOTAL_MEM >= 1800)); then 
                        DYNAMIC_GOGC=1000
                    elif ((TOTAL_MEM >= 900)); then 
                        DYNAMIC_GOGC=500
                    else 
                        DYNAMIC_GOGC=300
                    fi
                    
                    if grep -q "Environment=\"GOGC=" "$limit_file"; then
                        if [[ "$gc_status" == "默认 100" || "$gc_status" == "100" ]]; then
                            sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=$DYNAMIC_GOGC\"/" "$limit_file" 2>/dev/null || true
                        else
                            sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=100\"/" "$limit_file" 2>/dev/null || true
                        fi
                    else
                        echo "Environment=\"GOGC=$DYNAMIC_GOGC\"" >> "$limit_file"
                    fi
                    systemctl daemon-reload >/dev/null 2>&1 || true
                    systemctl restart xray >/dev/null 2>&1 || true
                fi
                local _pause=""
                read -e -p "配置已更新，按 Enter 继续..." _pause || true
                ;;
            6)
                if [[ "$policy_status" == "60" ]]; then
                    _safe_jq_write 'del(.policy)'
                else
                    _safe_jq_write '.policy = {"levels":{"0":{"handshake":3,"connIdle":60}},"system":{"statsInboundDownlink":false,"statsInboundUplink":false}}'
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _pause=""
                read -e -p "配置已更新，按 Enter 继续..." _pause || true
                ;;
            7)
                if [[ "$affinity_state" == "true" ]]; then _toggle_affinity_off; else _toggle_affinity_on; fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _pause=""
                read -e -p "配置已更新，按 Enter 继续..." _pause || true
                ;;
            8)
                if [[ "$mph_state" == "true" ]]; then
                    _safe_jq_write 'del(.routing.domainMatcher)'
                else
                    _safe_jq_write '.routing = (.routing // {}) | .routing.domainMatcher = "mph"'
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _pause=""
                read -e -p "配置已更新，按 Enter 继续..." _pause || true
                ;;
            9)
                if [[ -n "$has_reality" ]]; then
                    if [[ "$maxtime_state" == "true" ]]; then
                        _safe_jq_write '(.inbounds[]? | select(.protocol == "vless" and .streamSettings.security == "reality")) |= del(.streamSettings.realitySettings.maxTimeDiff)'
                    else
                        _safe_jq_write '(.inbounds[]? | select(.protocol == "vless" and .streamSettings.security == "reality")) |= (.streamSettings.realitySettings = (.streamSettings.realitySettings // {}) | .streamSettings.realitySettings.maxTimeDiff = 60000)'
                    fi
                    systemctl restart xray >/dev/null 2>&1 || true
                fi
                local _pause=""
                read -e -p "配置已更新，按 Enter 继续..." _pause || true
                ;;
            10)
                if [[ "$routeonly_status" == "true" ]]; then
                    _safe_jq_write '(.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= (.sniffing.routeOnly = false)'
                else
                    _safe_jq_write '(.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= (.sniffing = (.sniffing // {}) | .sniffing.routeOnly = true)'
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _pause=""
                read -e -p "配置已更新，按 Enter 继续..." _pause || true
                ;;
            11) toggle_buffer; systemctl restart xray >/dev/null 2>&1 || true; local _pause=""; read -e -p "配置已更新，按 Enter 继续..." _pause || true ;;
            12) toggle_dnsmasq; local _pause=""; read -e -p "配置已应用，按 Enter 继续..." _pause || true ;;
            13) toggle_thp; local _pause=""; read -e -p "配置已应用，按 Enter 继续..." _pause || true ;;
            14) toggle_mtu; local _pause=""; read -e -p "配置已应用，按 Enter 继续..." _pause || true ;;
            15) toggle_cpu; local _pause=""; read -e -p "配置已应用，按 Enter 继续..." _pause || true ;;
            16) toggle_ring; local _pause=""; read -e -p "配置已应用，按 Enter 继续..." _pause || true ;;
            17) toggle_zram; local _pause=""; read -e -p "配置已应用，按 Enter 继续..." _pause || true ;;
            18) toggle_journal; local _pause=""; read -e -p "配置已应用，按 Enter 继续..." _pause || true ;;
            19) toggle_process_priority; systemctl restart xray >/dev/null 2>&1 || true; local _pause=""; read -e -p "配置已应用，按 Enter 继续..." _pause || true ;;
            20) toggle_cake; local _pause=""; read -e -p "配置已应用，按 Enter 继续..." _pause || true ;;
            21) toggle_irq; local _pause=""; read -e -p "配置已应用，按 Enter 继续..." _pause || true ;;
            22) 
                if [[ "$gso_off_state" == "unsupported" ]]; then
                    warn "当前硬件驱动不支持修改卸载状态。"
                    sleep 2
                else
                    toggle_gso_off
                    local _pause=""
                    read -e -p "配置已应用，按 Enter 继续..." _pause || true 
                fi
                ;;
            23) toggle_ackfilter; local _pause=""; read -e -p "配置已应用，按 Enter 继续..." _pause || true ;;
            24) toggle_ecn; local _pause=""; read -e -p "配置已应用，按 Enter 继续..." _pause || true ;;
            25) toggle_wash; local _pause=""; read -e -p "配置已应用，按 Enter 继续..." _pause || true ;;
            26)
                if ((app_off_count > 0)); then
                    info "一键开启应用层参数..."
                    _turn_on_app
                    systemctl restart xray >/dev/null 2>&1 || true
                else
                    info "恢复应用层默认配置..."
                    _turn_off_app
                    systemctl restart xray >/dev/null 2>&1 || true
                fi
                local _pause=""
                read -e -p "执行完毕，按 Enter 继续..." _pause || true
                ;;
            27)
                if ((sys_off_count > 0)); then
                    if [[ "$dnsmasq_state" == "false" ]]; then toggle_dnsmasq; fi
                    if [[ "$thp_state" == "false" ]]; then toggle_thp; fi
                    if [[ "$mtu_state" == "false" ]]; then toggle_mtu; fi
                    if [[ "$cpu_state" == "false" ]]; then toggle_cpu; fi
                    if [[ "$ring_state" == "false" ]]; then toggle_ring; fi
                    if [[ "$zram_state" == "false" ]]; then toggle_zram; fi
                    if [[ "$journal_state" == "false" ]]; then toggle_journal; fi
                    if [[ "$prio_state" == "false" ]]; then toggle_process_priority; fi
                    if [[ "$cake_state" == "false" ]]; then toggle_cake; fi
                    if [[ "$irq_state" == "false" ]]; then toggle_irq; fi
                    if [[ "$gso_off_state" == "false" ]]; then toggle_gso_off; fi
                    if [[ "$ackfilter_state" == "false" ]]; then toggle_ackfilter; fi
                    if [[ "$ecn_state" == "false" ]]; then toggle_ecn; fi
                    if [[ "$wash_state" == "false" ]]; then toggle_wash; fi
                    info "系统级设置已全量激活。"
                else
                    if [[ "$dnsmasq_state" == "true" ]]; then toggle_dnsmasq; fi
                    if [[ "$thp_state" == "true" ]]; then toggle_thp; fi
                    if [[ "$mtu_state" == "true" ]]; then toggle_mtu; fi
                    if [[ "$cpu_state" == "true" ]]; then toggle_cpu; fi
                    if [[ "$ring_state" == "true" ]]; then toggle_ring; fi
                    if [[ "$zram_state" == "true" ]]; then toggle_zram; fi
                    if [[ "$journal_state" == "true" ]]; then toggle_journal; fi
                    if [[ "$prio_state" == "true" ]]; then toggle_process_priority; fi
                    if [[ "$cake_state" == "true" ]]; then toggle_cake; fi
                    if [[ "$irq_state" == "true" ]]; then toggle_irq; fi
                    if [[ "$gso_off_state" == "true" ]]; then toggle_gso_off; fi
                    if [[ "$ackfilter_state" == "true" ]]; then toggle_ackfilter; fi
                    if [[ "$ecn_state" == "true" ]]; then toggle_ecn; fi
                    if [[ "$wash_state" == "true" ]]; then toggle_wash; fi
                    info "系统级设置已恢复默认状态。"
                fi
                local _pause=""
                read -e -p "执行完毕，按 Enter 继续..." _pause || true
                ;;
            28)
                if (((app_off_count + sys_off_count) > 0)); then
                    if ((app_off_count > 0)); then _turn_on_app; fi
                    if ((sys_off_count > 0)); then
                        if [[ "$dnsmasq_state" == "false" ]]; then toggle_dnsmasq; fi
                        if [[ "$thp_state" == "false" ]]; then toggle_thp; fi
                        if [[ "$mtu_state" == "false" ]]; then toggle_mtu; fi
                        if [[ "$cpu_state" == "false" ]]; then toggle_cpu; fi
                        if [[ "$ring_state" == "false" ]]; then toggle_ring; fi
                        if [[ "$zram_state" == "false" ]]; then toggle_zram; fi
                        if [[ "$journal_state" == "false" ]]; then toggle_journal; fi
                        if [[ "$prio_state" == "false" ]]; then toggle_process_priority; fi
                        if [[ "$cake_state" == "false" ]]; then toggle_cake; fi
                        if [[ "$irq_state" == "false" ]]; then toggle_irq; fi
                        if [[ "$gso_off_state" == "false" ]]; then toggle_gso_off; fi
                        if [[ "$ackfilter_state" == "false" ]]; then toggle_ackfilter; fi
                        if [[ "$ecn_state" == "false" ]]; then toggle_ecn; fi
                        if [[ "$wash_state" == "false" ]]; then toggle_wash; fi
                    fi
                else
                    _turn_off_app
                    if [[ "$dnsmasq_state" == "true" ]]; then toggle_dnsmasq; fi
                    if [[ "$thp_state" == "true" ]]; then toggle_thp; fi
                    if [[ "$mtu_state" == "true" ]]; then toggle_mtu; fi
                    if [[ "$cpu_state" == "true" ]]; then toggle_cpu; fi
                    if [[ "$ring_state" == "true" ]]; then toggle_ring; fi
                    if [[ "$zram_state" == "true" ]]; then toggle_zram; fi
                    if [[ "$journal_state" == "true" ]]; then toggle_journal; fi
                    if [[ "$prio_state" == "true" ]]; then toggle_process_priority; fi
                    if [[ "$cake_state" == "true" ]]; then toggle_cake; fi
                    if [[ "$irq_state" == "true" ]]; then toggle_irq; fi
                    if [[ "$gso_off_state" == "true" ]]; then toggle_gso_off; fi
                    if [[ "$ackfilter_state" == "true" ]]; then toggle_ackfilter; fi
                    if [[ "$ecn_state" == "true" ]]; then toggle_ecn; fi
                    if [[ "$wash_state" == "true" ]]; then toggle_wash; fi
                fi
                echo ""
                info "所有网络与系统调优参数已注入。"
                warn "系统将在 5 秒后自动重启应用配置..."
                sleep 5
                sync
                reboot
                ;;
        esac
    done
}

# ==============================================================================
# [ 区块 X: 实时探针与系统调度中心 ]
# ==============================================================================

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
        read -e -p "请指定管理指令: " s || true
        
        case "${s:-}" in
            1) systemctl status xray --no-pager || true; local _pause=""; read -e -p "按 Enter 继续..." _pause || true ;;
            2) 
                echo -e "\n  对外公网 IP: ${green}$SERVER_IP${none}\n  系统 DNS 路由: "
                grep "^nameserver" /etc/resolv.conf 2>/dev/null || echo "    获取失败"
                echo -e "  系统监听端口池:"
                ss -tlnp 2>/dev/null | grep xray || echo "    未检测到监听服务"
                local _pause=""
                read -e -p "按 Enter 继续..." _pause || true 
                ;;
            3) 
                if ! command -v vnstat >/dev/null 2>&1; then 
                    warn "您的服务器尚未安装 vnstat 监控工具。"
                    local _pause=""
                    read -e -p "按 Enter 继续..." _pause || true
                    continue
                fi
                clear; title "商用级网络流量审计系统 (vnstat)"
                
                local m_day
                m_day=$(grep -E "^[[:space:]]*MonthRotate" /etc/vnstat.conf 2>/dev/null | awk '{print $2}' | head -n 1 | tr -d '\r\n')
                m_day=${m_day:-"1 (系统默认)"}
                echo -e "  当前每月流量结算清零日: ${cyan}每月 $m_day 号${none}"
                hr
                (vnstat -m 3 2>/dev/null || vnstat -m 2>/dev/null || true) | sed -e 's/estimated/预估消耗/ig' -e 's/rx/接收流量/ig' -e 's/tx/发送流量/ig' -e 's/total/全域吞吐/ig' -e 's/daily/按日/ig' -e 's/monthly/按自然月/ig'
                hr
                echo "  1) 手动指定每月的流量计费清零日期 (1-31)"
                echo "  2) 查询指定历史年月的日跑量详单 (如: 2026-04)"
                echo "  0) 退出流量中心"
                local vn_opt=""
                read -e -p "  执行系统任务: " vn_opt || true
                case "${vn_opt:-}" in
                    1) 
                        local d_day=""
                        read -e -p "输入物理结算日标 (1-31): " d_day || true
                        if [[ "${d_day:-}" =~ ^[0-9]+$ ]] && (( d_day >= 1 && d_day <= 31 )); then
                            sed -i '/^[#[:space:]]*MonthRotate/d' /etc/vnstat.conf 2>/dev/null || true
                            echo "MonthRotate $d_day" >> /etc/vnstat.conf
                            systemctl restart vnstat 2>/dev/null || true
                            info "底层配置已更新，流量账单将在每月 $d_day 号截断重组。"
                        else 
                            error "非法的输入格式。"
                        fi
                        local _pause=""
                        read -e -p "按 Enter 返回..." _pause || true 
                        ;;
                    2)
                        local d_month=""
                        read -e -p "请输入要穿梭的历史锚点 (格式如 $(date +%Y-%m)，不填默认近 30 天): " d_month || true
                        if [[ -z "${d_month:-}" ]]; then 
                            vnstat -d 2>/dev/null | sed -e 's/estimated/预估消耗/ig' -e 's/rx/接收流量/ig' -e 's/tx/发送流量/ig' -e 's/total/全域吞吐/ig' -e 's/daily/按日/ig' -e 's/monthly/按自然月/ig' || true
                        else 
                            vnstat -d 2>/dev/null | grep -iE "(${d_month:-}| day |estimated|--)" | sed -e 's/estimated/预估消耗/ig' -e 's/rx/接收流量/ig' -e 's/tx/发送流量/ig' -e 's/total/全域吞吐/ig' -e 's/daily/按日/ig' -e 's/monthly/按自然月/ig' || true
                        fi
                        local _pause=""
                        read -e -p "按 Enter 返回..." _pause || true 
                        ;;
                    0|q|Q) 
                        ;;
                esac
                ;;
            4)
                while true; do
                    clear; title "实时外网连接追踪系统"
                    local x_pids
                    x_pids=$(pidof xray 2>/dev/null | xargs | tr -s ' ' '|' || echo "")
                    if [[ -n "$x_pids" ]]; then
                        echo -e "  ${cyan}【并发握手状态监控】${none}"
                        ss -ntupa 2>/dev/null | grep -E "pid=($x_pids)[,)]" | awk '{print $1"_"$2}' | sort | uniq -c | sort -nr | awk '{printf "    通道句柄: %-15s : 吞吐活跃数 %s\n", $2, $1}' || echo "    系统无连接"
                        echo -e "\n  ${cyan}【外部访问来源追溯 (TOP 10 排名)】${none}"
                        local ips
                        ips=$(ss -ntupa 2>/dev/null | grep -E "pid=($x_pids)[,)]" | grep -vE "LISTEN|UNCONN" | awk '{print $6}' | sed -E 's/:[0-9]+$//' | tr -d '[]' | grep -vE "^127\.0\.0\.1$|^0\.0\.0\.0$|^::$|^\*$|^::ffff:127\.0\.0\.1$" || echo "")
                        if [[ -n "$ips" ]]; then
                            echo "$ips" | sort | uniq -c | sort -nr | head -n 10 | awk '{printf "    访客 IP: %-18s (并行发包: %s 次)\n", $2, $1}'
                            local total_ips
                            total_ips=$(echo "$ips" | sort | uniq | wc -l)
                            echo -e "\n  净化后系统绝对独立访客总量: ${yellow}${total_ips}${none}"
                        else 
                            echo -e "    ${gray}监听正常，当前暂无外部连接传入。${none}"
                        fi
                    else 
                        error "核心雷达脱机，进程可能已消亡。"
                    fi
                    echo -e "\n  ${green}追踪探针运行中... [ q ] 中止${none}"
                    local cmd=""
                    if read -t 2 -n 1 -s cmd 2>/dev/null; then
                        if [[ "${cmd:-}" == "q" || "${cmd:-}" == "Q" || "${cmd:-}" == $'\e' ]]; then break; fi
                    fi
                done
                ;;
            5)
                while true; do
                    clear; title "修改内核级进程调度抢占权重"
                    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
                    local current_nice="-20"
                    if [[ -f "$limit_file" ]]; then 
                        if grep -q "^Nice=" "$limit_file" 2>/dev/null; then 
                            current_nice=$(awk -F'=' '/^Nice=/ {print $2}' "$limit_file" | head -n 1 || echo "-20")
                        fi
                    fi
                    echo -e "  当前调度优先级参数 (Nice): ${cyan}${current_nice}${none} (有效控制区间: -20 到 -10 之间)"
                    hr
                    local new_nice=""
                    read -e -p "  请指定新抢占权重 (q 退出): " new_nice || true
                    if [[ "${new_nice:-}" == "q" || "${new_nice:-}" == "Q" ]]; then break; fi
                    if [[ "${new_nice:-}" =~ ^-[1-2][0-9]$ ]] && ((new_nice >= -20 && new_nice <= -10)); then
                        sed -i "s/^Nice=.*/Nice=$new_nice/" "$limit_file" 2>/dev/null || true
                        systemctl daemon-reload >/dev/null 2>&1 || true
                        info "设置已记录，5 秒后重启进程应用更改..."
                        sleep 5; systemctl restart xray >/dev/null 2>&1 || true
                        info "内核提权配置完成。"
                        local _pause=""
                        read -e -p "按 Enter 返回..." _pause || true; break
                    else 
                        error "输入不在有效区间内！"
                        sleep 2
                    fi
                done
                ;;
            6) clear; title "程序运行轨迹日志"; tail -n 50 "$LOG_DIR/xray.log" 2>/dev/null || echo "  暂无留档记录。"; local _pause=""; read -e -p "按 Enter 退出..." _pause || true ;;
            7) clear; title "系统错误警告日志"; tail -n 30 "$LOG_DIR/error.log" 2>/dev/null || echo "  服务运行正常，无报错产生。"; local _pause=""; read -e -p "按 Enter 退出..." _pause || true ;;
            8)
                clear; title "自动化配置备份与灾难恢复中心"
                ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null || echo "系统内空空如也"
                echo -e "\n  r) 立即回滚至最新有效快照\n  c) 为当前环境手动创建配置快照\n  0) 退出"
                local bopt=""
                read -e -p "执行操作: " bopt || true
                if [[ "${bopt:-}" == "r" ]]; then restore_latest_backup; fi
                if [[ "${bopt:-}" == "c" ]]; then backup_config; info "快照已安全建立"; local _pause=""; read -e -p "Enter..." _pause || true; fi
                ;;
            0) return ;;
        esac
    done
}

do_sys_init_menu() {
    while true; do
        clear
        title "系统环境部署与编译配置工具"
        echo "  1) 同步时区、配置必要依赖库与 Swap 虚拟内存"
        echo "  2) 接管并强校验本地 DNS (resolvconf)"
        echo -e "  ${cyan}3) 必须先安装 XANMOD (main) 官方预编译内核 (推荐)${none}"
        echo "  4) 先完成3），编译部署 Linux Kernel 官方主线内核并开启 BBR3"
        echo "  5) 配置网卡发送队列 (TX Queue) 并发加速"
        echo "  6) 写入系统内核网络栈高速调优参数集"
        echo "  7) 网络应用层与系统级高级参数全量控制面板"
        echo "  8) 配置高级 CAKE 队列与网络流量调度参数"
        echo "  0) 返回系统主界面"
        hr
        local sys_opt=""
        read -e -p "请指定需要执行的配置任务: " sys_opt || true
        
        case "${sys_opt:-}" in
            1) 
                info "执行依赖安装及初始化工作..."
                apt-get update -y >/dev/null 2>&1 || true
                pkg_install wget curl sudo socat ntpdate e2fsprogs pkg-config iproute2 ethtool
                timedatectl set-timezone Asia/Kuala_Lumpur 2>/dev/null || true
                ntpdate -u us.pool.ntp.org 2>/dev/null || true
                hwclock --systohc 2>/dev/null || true
                check_and_create_1gb_swap
                info "系统底层环境初始化完成。"
                local _pause=""
                read -e -p "按 Enter 键继续..." _pause || true 
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

do_update_core() {
    title "Xray 核心框架在线更新系统"
    info "正在与官方存储库建立连接..."
    bash -c "$(curl -fsSL --connect-timeout 10 https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1 || true
    fix_xray_systemd_limits
    systemctl restart xray >/dev/null 2>&1 || true
    local cur_ver
    cur_ver=$($XRAY_BIN version 2>/dev/null | head -n1 | awk '{print $2}' || echo "读取异常")
    info "系统已更新完毕。版本追踪: ${cyan}$cur_ver${none}"
    local _pause=""
    read -e -p "按 Enter 返回主菜单..." _pause || true
}

_update_matrix() {
    if [[ ! -f "$CONFIG" ]]; then return; fi
    echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
    _safe_jq_write --arg dest "$BEST_SNI:443" --slurpfile snis /tmp/sni_array.json '
        (.inbounds[]? | select(.protocol == "vless")) |= (
            .streamSettings.realitySettings.serverNames = $snis[0] |
            .streamSettings.realitySettings.dest = $dest
        )
    '
    rm -f /tmp/sni_array.json 2>/dev/null || true
    ensure_xray_is_alive
    info "安全伪装网络接口已被更新并应用。"
}

do_fallback_probe() {
    clear
    title "Reality 回落保护参数审查"
    jq -r '
      .inbounds[]? | select(.protocol=="vless" and .streamSettings.security=="reality") | .streamSettings.realitySettings | 
      "  [防线策略设定]\n    上传封锁阈值限制 (bytesPerSec) : \(.limitFallbackUpload.bytesPerSec // "未开启")\n    下载封锁阈值限制 (bytesPerSec) : \(.limitFallbackDownload.bytesPerSec // "未开启")"
    ' "$CONFIG" 2>/dev/null || warn "配置文件解析时遇到错误。"
    echo ""
    local _pause=""
    read -e -p "信息检索完毕，按 Enter 键返回..." _pause || true
}

do_uninstall() {
    title "环境清理与系统还原"
    local confirm=""
    read -e -p "警告: 该操作将不可逆地删除服务、配置及日志记录，是否确认注销？(y/n): " confirm || true
    if [[ "${confirm:-}" != "y" && "${confirm:-}" != "Y" ]]; then 
        return
    fi
    
    info "启动注销及反部署流程..."
    systemctl stop dnsmasq >/dev/null 2>&1 || true
    systemctl disable dnsmasq >/dev/null 2>&1 || true
    apt-get purge -y dnsmasq >/dev/null 2>&1 || true
    
    chattr -i /etc/resolv.conf 2>/dev/null || true
    if [[ -f /etc/resolv.conf.bak ]]; then 
        mv -f /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true
    fi
    
    systemctl stop xray >/dev/null 2>&1 || true
    systemctl disable xray >/dev/null 2>&1 || true
    rm -rf /etc/systemd/system/xray* /lib/systemd/system/xray* >/dev/null 2>&1 || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    
    rm -rf "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SCRIPT_DIR" /var/log/xray* /usr/local/bin/xrv "$SCRIPT_PATH" >/dev/null 2>&1 || true
    
    (crontab -l 2>/dev/null | grep -v "update-dat.sh" | grep -v "/bin/systemctl restart xray") | crontab - 2>/dev/null || true
    
    info "清理操作已完毕，系统恢复原态。"
    exit 0
}

# ==============================================================================
# [ 区块 XI: 全息主控制台与无人托管引擎 ]
# ==============================================================================

one_click_optimize() {
    clear
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo -e "${gl_kjlan}   ⭐ 一键全息无人接管 (The Ultimate Genesis)${gl_bai}"
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo ""
    
    local xanmod_running=0
    if uname -r | grep -qi 'xanmod'; then xanmod_running=1; fi

    if [ $xanmod_running -eq 0 ]; then
        echo -e "${gl_huang}▶ 序列 1：正准备强制焊入高级物理引擎 (XanMod)${gl_bai}"
        AUTO_MODE=1
        if install_xanmod_kernel; then
            echo -e "\n${gl_lv}✅ 内核骨架替换完毕！系统即将强行脱机并从新引擎中复苏...${gl_bai}"
            echo -e "${gl_lv}系统复苏后，务必再次输入指令执行【选项 66】完成余下接驳。${gl_bai}"
            sleep 3
            reboot
        else
            echo -e "${gl_hong}❌ 引擎排斥反应剧烈，接管行动流产。${gl_bai}"
        fi
        AUTO_MODE=""
        break_end
    else
        echo -e "${gl_lv}✅ 雷达确认: 霸道的 XanMod 引擎已在胸腔内轰鸣！${gl_bai}\n"
        echo -e "${gl_huang}▶ 序列 2：全自动生态网络铺路作业${gl_bai}"
        AUTO_MODE=1
        
        echo -e "\n${gl_zi}>>> 强行撕开虚拟内存气囊以防系统窒息...${gl_bai}"
        check_and_suggest_swap
        
        echo -e "\n${gl_zi}>>> 物理切除冗杂的 IPv6，强制锁死纯粹的 IPv4 指针...${gl_bai}"
        enforce_ipv4_and_disable_ipv6
        
        echo -e "\n${gl_zi}>>> 下放跨洋极速 BBR 算法，深度篡改网络收发时序...${gl_bai}"
        bbr_configure_direct
        
        AUTO_MODE=""
        echo -e "\n${gl_lv}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
        echo -e "${gl_lv} 🚀 创世纪元：底层环境已被改造成终极战争机器，请在主菜单执行部署！${gl_bai}"
        echo -e "${gl_lv}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
        break_end
    fi
}

main_menu() {
    while true; do
        clear
        echo -e "${blue}======================================================================${none}"
        echo -e "  ${magenta}Xray 高维控制台 (Apex Vanguard V188t9 Ultimate)${none}"
        
        local svc
        svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        if [[ "$svc" == "active" ]]; then 
            svc="${green}健康驱动 (Active)${none}"
        else 
            svc="${red}心跳静默 (Inactive)${none}"
        fi
        
        local current_kernel
        current_kernel=$(uname -r)
        
        echo -e "  引擎态势: $svc | 热键调用: ${cyan}xrv${none} | 内核: ${yellow}${current_kernel}${none}"
        echo -e "${blue}======================================================================${none}"
        echo "  1) 创建/重构 绝对安全的双轨加密协议通道 (VLESS-Reality / SS-2022)"
        echo "  2) 用户凭证生命周期与独立防封属性管理"
        echo "  3) 检阅全量节点配置连接中心"
        echo "  4) 人为干涉并热更全球 Geo 路由流量隔离库"
        echo "  5) 发起 Xray 服务通信底层源码静默升级"
        echo "  6) 伪装矩阵漂移 (单选/全选/剔除阻断 SNI)"
        echo "  7) 全局防火墙与广告阻断策略 (屏蔽 BT 与广告数据流)"
        echo "  8) Reality 物理回落边界防线与防盗扫探针巡查"
        echo "  9) 全景网络监控与自然月商用级流量记账系统"
        echo "  10) 应用层与系统级 28 项高级调优控制台 (TCP/Limits/内核魔改)"
        echo "  11) 底层物理网络栈突击调度台 (网卡队列/CAKE/BBR/Swap 管理)"
        echo "  0) 退出"
        echo -e "  ${yellow}66) The Genesis：一键全息底盘托管 (懒人重装专供)${none}"
        echo -e "  ${red}88) 执行深层物理格式化，将所有环境抹杀殆尽${none}"
        hr
        local num=""
        read -e -p "请下达命令代号: " num || true
        
        case "${num:-}" in
            1) do_install ;;
            2) do_user_manager ;;
            3) 
                do_summary
                while true; do 
                    local rb=""
                    read -e -p "按 Enter 退回，或敲击 b 开启伪装矩阵漂移: " rb || true
                    if [[ "${rb:-}" == "b" || "${rb:-}" == "B" ]]; then 
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
                info "发出信号流获取云端最新基库..."
                bash "$UPDATE_DAT_SCRIPT" >/dev/null 2>&1 || true
                ensure_xray_is_alive
                local _pause=""
                read -e -p "库文件已物理覆盖，按 Enter 继续..." _pause || true 
                ;;
            5) do_update_core ;;
            6) 
                if choose_sni; then 
                    _update_matrix
                    do_summary
                    local _pause=""
                    read -e -p "指令已写入守护核心，按 Enter 继续..." _pause || true
                fi 
                ;;
            7) _global_block_rules ;;
            8) do_fallback_probe ;;
            9) do_status_menu ;;
            10) do_app_level_tuning_menu ;;
            11) do_sys_init_menu ;;
            66) one_click_optimize ;;
            88) do_uninstall ;;
            0) exit 0 ;;
            *) echo -e "${gl_hong}❌ 指令未能被中枢识别${gl_bai}"; sleep 1 ;;
        esac
    done
}

# ==============================================================================
# 系统入口接引与自检防御闭环
# ==============================================================================
preflight
main_menu
