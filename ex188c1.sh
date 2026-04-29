#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: ex188c1.sh (The Apex Vanguard - Ultimate Genesis V188c1)
# 快捷方式: xrv
#
# V188c1 创世双核融合日志:
#   1. 双引擎合璧: 完美融合 ex188.sh (Xray 终极控制面板) 与 tcpcc1.sh (全能 BBR/AI 代理/流媒体网关聚合池)。
#   2. 底盘重铸: 统一两套脚本的底层预检、依赖安装与网络调优，消除冲突，共享内核资源。
#   3. 全局容错: 强制施行 set -euo pipefail 工业级规范，对易崩溃的变量及系统调用进行包裹保护。
#   4. 排版大一统: 严格保留 100% 节点排列格式、系统探测及 AI 工具箱详细菜单交互。
# ==============================================================================

# 检查 Bash 运行环境
if test -z "$BASH_VERSION"; then
    echo "Error: Please run this script with bash: bash ex188c1.sh"
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

# 兼容 tcpcc1.sh 的颜色别名
readonly gl_hong="$red"
readonly gl_lv="$green"
readonly gl_huang="$yellow"
readonly gl_bai="$none"
readonly gl_kjlan="$cyan"
readonly gl_zi="$magenta"
readonly gl_hui="$gray"

# ── 全局常量与路径 ──────────────────────────────────────────────
readonly SCRIPT_VERSION="188c1"
readonly SCRIPT_LAST_UPDATE="双核引擎终极融合：Xray 核心控制 + BBR/内核综合代理池 (The Immortal 协议级护航)"

# Xray 相关路径
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

# 其他组件相关路径与变量
readonly SYSCTL_CONF="/etc/sysctl.d/99-net-tcp-tune.conf"
readonly CADDY_DEFAULT_VERSION="2.10.2"
readonly SNELL_DEFAULT_VERSION="5.0.1"
readonly SYMLINK="/usr/local/bin/xrv"
readonly SCRIPT_PATH=$(readlink -f "$0")
gh_proxy="https://"

# ── 可变全局状态 ───────────────────────────────────────────────
SERVER_IP=""
REMARK_NAME="xp-reality"
BEST_SNI="www.microsoft.com"
SNI_JSON_ARRAY="\"www.microsoft.com\""
LISTEN_PORT=443
AUTO_MODE=""
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# ── 初始化系统目录 ─────────────────────────────────────────────
if ! mkdir -p "$CONFIG_DIR" "$DAT_DIR" "$SCRIPT_DIR" "$FLAGS_DIR" "$LOG_DIR" "$BACKUP_DIR" 2>/dev/null; then
    true
fi
if ! touch "$USER_SNI_MAP" "$USER_TIME_MAP" 2>/dev/null; then
    true
fi

# ==============================================================================
# [ 区块 I: 基础工具、UI 渲染与容错机制 ]
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

# 显示宽度计算（中文占2列，ASCII占1列）- 兼容 tcpcc1
get_display_width() {
    local str="$1"
    local byte_len
    byte_len=$(printf '%s' "$str" | LC_ALL=C wc -c | tr -d ' ' || echo 0)
    local char_len=${#str}
    local extra=$((byte_len - char_len))
    local wide=$((extra / 2))
    echo $((char_len + wide))
}

# 格式化字符串到固定显示宽度
format_fixed_width() {
    local str="$1"
    local target_width=$2
    local current_width
    current_width=$(get_display_width "$str")

    if [ "$current_width" -gt "$target_width" ]; then
        local result=""
        local i=0
        local len=${#str}
        while [ $i -lt $len ]; do
            local char="${str:$i:1}"
            local test_str="${result}${char}"
            local test_width
            test_width=$(get_display_width "$test_str")
            if [ "$test_width" -gt $((target_width - 2)) ]; then
                str="${result}.."
                break
            fi
            result="$test_str"
            i=$((i + 1))
        done
        current_width=$(get_display_width "$str")
    fi

    local padding=$((target_width - current_width))
    if [ $padding -gt 0 ]; then
        printf "%s%*s" "$str" "$padding" ""
    else
        printf "%s" "$str"
    fi
}

# 统一日志函数 (兼容两套体系)
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >> "/var/log/net-tcp-tune.log" 2>/dev/null || true

    case "$level" in
        ERROR) echo -e "${gl_hong}[ERROR] $message${gl_bai}" >&2 ;;
        WARN)  echo -e "${gl_huang}[WARN] $message${gl_bai}" ;;
        INFO)  [ "$LOG_LEVEL" != "ERROR" ] && echo -e "${gl_lv}[INFO] $message${gl_bai}" ;;
        DEBUG) [ "$LOG_LEVEL" = "DEBUG" ] && echo -e "${gl_hui}[DEBUG] $message${gl_bai}" ;;
    esac
}

log_info()  { 
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO:  $*" >> "$LOG_DIR/xray.log" 2>/dev/null || true
    log "INFO" "$*"
}
log_error() { 
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$LOG_DIR/error.log" 2>/dev/null || true
    log "ERROR" "$*"
}
log_warn()  { log "WARN" "$@"; }
log_debug() { log "DEBUG" "$@"; }

# 捕获异常中断
trap '_err_handler $? $LINENO "$BASH_COMMAND"' ERR
_err_handler() {
    local code=$1 line=$2 cmd=$3
    echo -e "\n${red}[SYSTEM_ABORT] 退出码:$code 行数:$line 故障指令:$cmd${none}" >&2
    log_error "EXIT=$code LINE=$line CMD=$cmd"
    rm -f /tmp/net-tcp-tune.* 2>/dev/null || true
    rm -f /tmp/caddy.tar.gz 2>/dev/null || true
}

# 退出清理
cleanup_temp_files() {
    rm -f /tmp/net-tcp-tune.* 2>/dev/null || true
    rm -f /tmp/caddy.tar.gz 2>/dev/null || true
}
trap cleanup_temp_files EXIT

# 验证端口有效性
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

# 验证域名有效性
validate_domain() {
    local d="$1"
    if [[ "$d" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.\-]{0,253}[a-zA-Z0-9])?$ ]]; then
        return 0
    else
        return 1
    fi
}

# 修复关键文件权限
fix_permissions() {
    if [[ -f "$CONFIG" ]]; then
        chmod 644 "$CONFIG" 2>/dev/null || true
    fi
    if [[ -d "$CONFIG_DIR" ]]; then
        chmod 755 "$CONFIG_DIR" 2>/dev/null || true
    fi
    chown -R root:root "$CONFIG_DIR" 2>/dev/null || true
    if [[ -f "$PUBKEY_FILE" ]]; then
        chmod 600 "$PUBKEY_FILE" 2>/dev/null || true
    fi
}

# 终端断点停留
break_end() {
    [[ "${AUTO_MODE:-}" == "1" ]] && return 0
    echo ""
    echo -e "${green}操作完成。${none}"
    read -n 1 -s -r -p "按任意键继续..." || true
    echo ""
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${gl_hong}错误: ${gl_bai}此脚本需要 root 权限运行！"
        echo "请使用: sudo bash $0"
        exit 1
    fi
}

# ==============================================================================
# [ 区块 II: JSON 配置事务与回滚系统 (Xray) ]
# ==============================================================================

# 配置自动快照
backup_config() {
    if [[ ! -f "$CONFIG" ]]; then return 0; fi
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    cp -f "$CONFIG" "$BACKUP_DIR/config_${ts}.json" 2>/dev/null || true
    ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
    log_info "配置已备份: config_${ts}.json"
}

# 回滚最新快照
restore_latest_backup() {
    local latest
    latest=$(ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | head -n 1 || true)
    if [[ -n "$latest" ]]; then
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

# 校验 Xray 配置文件合法性
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

# 安全 JSON 写入接口 (强制追加 .json 后缀以适配核心检测)
_safe_jq_write() {
    backup_config
    local tmp_raw
    tmp_raw=$(mktemp) || return 1
    local tmp="${tmp_raw}.json"
    mv -f "$tmp_raw" "$tmp" 2>/dev/null || true
    
    if jq "$@" "$CONFIG" > "$tmp" 2>/dev/null && jq empty "$tmp" 2>/dev/null; then
        if verify_xray_config "$tmp"; then
            mv -f "$tmp" "$CONFIG" 2>/dev/null || true
            fix_permissions
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

# 重启 Xray 服务并探测存活状态
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
        read -rp "请按 Enter 键返回..." _
        return 1
    fi
}

# 脚本远端下载与验证工具
safe_download_script() {
    local url=$1
    local output_file=$2

    if command -v curl &>/dev/null; then
        curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$output_file"
    elif command -v wget &>/dev/null; then
        wget -qO "$output_file" "$url"
    else
        return 1
    fi
    [[ -s "$output_file" ]]
}

verify_downloaded_script() {
    local file=$1
    if [[ ! -s "$file" ]]; then return 1; fi
    if head -n 1 "$file" | grep -qiE '<!DOCTYPE|<html'; then return 1; fi
    # 检查 shebang，处理 UTF-8 BOM
    head -n 5 "$file" | sed 's/^\xef\xbb\xbf//' | grep -q '^#!'
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

    if ! safe_download_script "$url" "$tmp_file"; then
        echo -e "${red}❌ 下载脚本失败: ${url}${none}"
        rm -f "$tmp_file"
        return 1
    fi

    if ! verify_downloaded_script "$tmp_file"; then
        echo -e "${red}❌ 脚本校验失败，已取消执行${none}"
        rm -f "$tmp_file"
        return 1
    fi

    chmod +x "$tmp_file"
    "$interpreter" "$tmp_file" "$@"
    local rc=$?
    rm -f "$tmp_file"
    return $rc
}
check_disk_space() {
    local required_gb=$1
    local required_space_mb=$((required_gb * 1024))
    local available_space_mb
    available_space_mb=$(df -m / | awk 'NR==2 {print $4}')

    if [ "$available_space_mb" -lt "$required_space_mb" ]; then
        echo -e "${gl_huang}警告: ${gl_bai}磁盘空间不足！"
        echo "当前可用: $((available_space_mb/1024))G | 最低需求: ${required_gb}G"
        read -e -p "是否继续？(Y/N): " continue_choice
        case "$continue_choice" in
            [Yy]) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

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

# ==============================================================================
# [ 区块 IV: 虚拟内存管理引擎 (Swap) ]
# ==============================================================================

check_swap() {
    local swap_total
    swap_total=$(free -m | awk 'NR==3{print $2}' || echo "0")

    if [ "$swap_total" -eq 0 ]; then
        echo -e "${gl_huang}检测到无虚拟内存，正在创建 1G SWAP...${gl_bai}"
        if fallocate -l $((1025 * 1024 * 1024)) /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=1025 2>/dev/null; then
            chmod 600 /swapfile
            mkswap /swapfile > /dev/null 2>&1 || true
            if swapon /swapfile 2>/dev/null; then
                if ! grep -q '/swapfile' /etc/fstab 2>/dev/null; then
                    echo '/swapfile none swap sw 0 0' >> /etc/fstab
                fi
                echo -e "${gl_lv}虚拟内存创建成功${gl_bai}"
            else
                echo -e "${gl_huang}⚠️  SWAP 激活失败，但不影响安装${gl_bai}"
            fi
        else
            echo -e "${gl_huang}⚠️  SWAP 文件创建失败，但不影响安装${gl_bai}"
        fi
    fi
}

add_swap() {
    local new_swap=$1  # 传入的参数（单位：MB）

    echo -e "${gl_kjlan}=== 调整虚拟内存（仅管理 /swapfile） ===${gl_bai}"

    local dev_swap_list
    dev_swap_list=$(awk 'NR>1 && $1 ~ /^\/dev\// {printf "  • %s (大小: %d MB, 已用: %d MB)\n", $1, int(($3+512)/1024), int(($4+512)/1024)}' /proc/swaps 2>/dev/null || true)

    if [ -n "$dev_swap_list" ]; then
        echo -e "${gl_huang}检测到以下 /dev/ 虚拟内存处于激活状态：${gl_bai}"
        echo "$dev_swap_list"
        echo ""
        echo -e "${gl_huang}提示:${gl_bai} 本脚本不会修改 /dev/ 分区，请使用 ${gl_zi}swapoff <设备>${gl_bai} 等命令手动处理。"
        echo ""
    fi

    swapoff /swapfile 2>/dev/null || true
    rm -f /swapfile 2>/dev/null || true
    
    echo "正在创建 ${new_swap}MB 虚拟内存..."
    
    if ! fallocate -l $(( (new_swap + 1) * 1024 * 1024 )) /swapfile 2>/dev/null; then
        dd if=/dev/zero of=/swapfile bs=1M count=$((new_swap + 1)) 2>/dev/null || true
    fi
    
    chmod 600 /swapfile 2>/dev/null || true
    mkswap /swapfile > /dev/null 2>&1 || true
    swapon /swapfile 2>/dev/null || true
    
    sed -i '/\/swapfile/d' /etc/fstab 2>/dev/null || true
    echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    
    if [ -f /etc/alpine-release ]; then
        echo "nohup swapon /swapfile" > /etc/local.d/swap.start
        chmod +x /etc/local.d/swap.start
        rc-update add local 2>/dev/null || true
    fi
    
    echo -e "${gl_lv}虚拟内存大小已调整为 ${new_swap}MB${gl_bai}"
}

calculate_optimal_swap() {
    local mem_total
    mem_total=$(free -m | awk 'NR==2{print $2}' || echo "1024")
    local recommended_swap
    local reason
    
    echo -e "${gl_kjlan}=== 智能计算虚拟内存大小 ===${gl_bai}"
    echo ""
    echo -e "检测到物理内存: ${gl_huang}${mem_total}MB${gl_bai}"
    echo ""
    echo "计算过程："
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ "$mem_total" -lt 512 ]; then
        recommended_swap=1024
        reason="内存极小（< 512MB），固定推荐 1GB"
        echo "→ 内存 < 512MB"
        echo "→ 推荐固定 1GB SWAP"
    elif [ "$mem_total" -lt 1024 ]; then
        recommended_swap=$((mem_total * 2))
        reason="内存较小（512MB-1GB），推荐 2 倍内存"
        echo "→ 内存在 512MB - 1GB 之间"
        echo "→ 计算公式: SWAP = 内存 × 2"
        echo "→ ${mem_total}MB × 2 = ${recommended_swap}MB"
    elif [ "$mem_total" -lt 2048 ]; then
        recommended_swap=$((mem_total * 3 / 2))
        reason="内存适中（1-2GB），推荐 1.5 倍内存"
        echo "→ 内存在 1GB - 2GB 之间"
        echo "→ 计算公式: SWAP = 内存 × 1.5"
        echo "→ ${mem_total}MB × 1.5 = ${recommended_swap}MB"
    elif [ "$mem_total" -lt 4096 ]; then
        recommended_swap=$mem_total
        reason="内存充足（2-4GB），推荐与内存同大小"
        echo "→ 内存在 2GB - 4GB 之间"
        echo "→ 计算公式: SWAP = 内存 × 1"
        echo "→ ${mem_total}MB × 1 = ${recommended_swap}MB"
    elif [ "$mem_total" -lt 8192 ]; then
        recommended_swap=4096
        reason="内存较多（4-8GB），固定推荐 4GB"
        echo "→ 内存在 4GB - 8GB 之间"
        echo "→ 固定推荐 4GB SWAP"
    else
        recommended_swap=4096
        reason="内存充裕（≥ 8GB），固定推荐 4GB"
        echo "→ 内存 ≥ 8GB"
        echo "→ 固定推荐 4GB SWAP"
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo -e "${gl_lv}计算结果：${gl_bai}"
    echo -e "  物理内存:   ${gl_huang}${mem_total}MB${gl_bai}"
    echo -e "  推荐 SWAP:  ${gl_huang}${recommended_swap}MB${gl_bai}"
    echo -e "  总可用内存: ${gl_huang}$((mem_total + recommended_swap))MB${gl_bai}"
    echo ""
    echo -e "${gl_zi}推荐理由: ${reason}${gl_bai}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    local confirm
    read -e -p "$(echo -e "${gl_huang}是否应用此配置？(Y/N): ${gl_bai}")" confirm
    
    case "$confirm" in
        [Yy])
            add_swap "$recommended_swap"
            return 0
            ;;
        *)
            echo "已取消"
            sleep 2
            return 1
            ;;
    esac
}

manage_swap() {
    while true; do
        clear
        echo -e "${gl_kjlan}=== 虚拟内存管理（仅限 /swapfile） ===${gl_bai}"
        echo -e "${gl_huang}提示:${gl_bai} 如需调整 /dev/ swap 分区，请手动执行 swapoff/swap 分区工具。"

        local mem_total
        mem_total=$(free -m | awk 'NR==2{print $2}' || echo "0")
        local swap_info
        swap_info=$(free -m | awk 'NR==3{used=$3; total=$2; if (total == 0) {percentage=0} else {percentage=used*100/total}; printf "%dM/%dM (%d%%)", used, total, percentage}' || echo "N/A")
        
        echo -e "物理内存:     ${gl_huang}${mem_total}MB${gl_bai}"
        echo -e "当前虚拟内存: ${gl_huang}$swap_info${gl_bai}"
        echo "------------------------------------------------"
        echo "1. 分配 1024M (1GB) - 固定配置"
        echo "2. 分配 2048M (2GB) - 固定配置"
        echo "3. 分配 4096M (4GB) - 固定配置"
        echo "4. 智能计算推荐值 - 自动计算最佳配置"
        echo "0. 返回主菜单"
        echo "------------------------------------------------"
        local choice
        read -e -p "请输入选择: " choice
        
        case "$choice" in
            1) add_swap 1024; break_end ;;
            2) add_swap 2048; break_end ;;
            3) add_swap 4096; break_end ;;
            4) 
                calculate_optimal_swap
                if [ $? -eq 0 ]; then break_end; fi
                ;;
            0) return ;;
            *) echo "无效选择"; sleep 2 ;;
        esac
    done
}

# ==============================================================================
# [ 区块 V: 网络基础配置 (IP优先级 / IPv6 / SOCKS5) ]
# ==============================================================================

set_ip_priority() {
    local ip_type="$1"

    if [ "$ip_type" != "ipv4" ] && [ "$ip_type" != "ipv6" ]; then
        echo -e "${gl_hong}错误：参数必须是 ipv4 或 ipv6${gl_bai}"
        return 1
    fi

    local title ipv4_precedence ipv6_precedence curl_flag secondary_flag primary secondary
    if [ "$ip_type" = "ipv4" ]; then
        title="IPv4"
        ipv4_precedence=100
        ipv6_precedence=10
        curl_flag="-4"
        secondary_flag="-6"
        primary="IPv4"
        secondary="IPv6"
    else
        title="IPv6"
        ipv4_precedence=10
        ipv6_precedence=100
        curl_flag="-6"
        secondary_flag="-4"
        primary="IPv6"
        secondary="IPv4"
    fi

    clear
    echo -e "${gl_kjlan}=== 设置${title}优先 ===${gl_bai}"
    echo ""

    if [ -f /etc/gai.conf ]; then
        cp /etc/gai.conf /etc/gai.conf.bak.$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
        echo "已备份原配置文件到 /etc/gai.conf.bak.*"
        echo "existed" > /etc/gai.conf.original_state
    else
        echo "not_existed" > /etc/gai.conf.original_state
        echo "原先无配置文件，已记录原始状态"
    fi

    echo "正在设置 ${title} 优先..."

    cat > /etc/gai.conf << EOF
# Configuration for getaddrinfo(3).
# 设置 ${title} 优先

# IPv4 addresses
precedence ::ffff:0:0/96  ${ipv4_precedence}
# IPv6 addresses
precedence ::/0           ${ipv6_precedence}
# IPv4-mapped IPv6 addresses
precedence ::1/128        50
# Link-local addresses
precedence fe80::/10      1
precedence fec0::/10      1
precedence fc00::/7       1
# Site-local addresses (deprecated)
precedence 2002::/16      30
EOF

    if command -v nscd &> /dev/null; then
        systemctl restart nscd 2>/dev/null || service nscd restart 2>/dev/null || true
        echo "已刷新 nscd DNS 缓存"
    fi

    if command -v resolvectl &> /dev/null; then
        resolvectl flush-caches 2>/dev/null || true
        echo "已刷新 systemd-resolved DNS 缓存"
    fi

    echo -e "${gl_lv}✅ ${title} 优先已设置${gl_bai}"
    echo ""
    echo "当前出口 IP 地址："
    echo "------------------------------------------------"
    curl ${curl_flag} -s ip.sb 2>/dev/null || curl -s ip.sb || echo "无法获取"
    echo ""
    echo "------------------------------------------------"
    echo ""
    echo -e "${gl_huang}提示：${gl_bai}"
    echo "1. 配置已生效，无需重启系统"
    echo "2. 新启动的程序将自动使用 ${title} 优先"
    echo "3. 如需强制指定，可使用: curl ${curl_flag} ip.sb"
    echo ""

    break_end
}

restore_gai_conf() {
    clear
    echo -e "${gl_kjlan}=== 恢复 IP 优先级配置 ===${gl_bai}"
    echo ""

    if [ ! -f /etc/gai.conf.original_state ]; then
        echo -e "${gl_huang}⚠️  未找到原始状态记录${gl_bai}"
        echo "可能的原因："
        echo "1. 从未使用过本脚本设置过 IPv4/IPv6 优先级"
        echo "2. 原始状态记录文件已被删除"
        echo ""
        
        if ls /etc/gai.conf.bak.* 1> /dev/null 2>&1; then
            echo "发现以下备份文件："
            ls -lh /etc/gai.conf.bak.* 2>/dev/null
            echo ""
            local manual_restore
            read -e -p "是否要手动恢复最新的备份？[y/n]: " manual_restore
            if [[ "$manual_restore" =~ ^[Yy]$ ]]; then
                local latest_backup
                latest_backup=$(ls -t /etc/gai.conf.bak.* 2>/dev/null | head -1)
                if [ -n "$latest_backup" ]; then
                    cp "$latest_backup" /etc/gai.conf
                    echo -e "${gl_lv}✅ 已从备份恢复: $latest_backup${gl_bai}"
                fi
            fi
        else
            echo "也未找到任何备份文件。"
            echo ""
            local delete_conf
            read -e -p "是否要删除当前的 gai.conf 文件（恢复到系统默认）？[y/n]: " delete_conf
            if [[ "$delete_conf" =~ ^[Yy]$ ]]; then
                rm -f /etc/gai.conf
                echo -e "${gl_lv}✅ 已删除 gai.conf，系统将使用默认配置${gl_bai}"
            fi
        fi
    else
        local original_state
        original_state=$(cat /etc/gai.conf.original_state 2>/dev/null || echo "")
        
        if [ "$original_state" == "not_existed" ]; then
            echo "检测到原先${gl_huang}没有${gl_bai} gai.conf 文件"
            echo "恢复操作将${gl_hong}删除${gl_bai}当前的 gai.conf 文件"
            echo ""
            local confirm
            read -e -p "确认要恢复到原始状态吗？[y/n]: " confirm
            
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                rm -f /etc/gai.conf /etc/gai.conf.original_state
                echo -e "${gl_lv}✅ 已删除 gai.conf，恢复到原始状态（无配置文件）${gl_bai}"
                if command -v nscd &> /dev/null; then
                    systemctl restart nscd 2>/dev/null || service nscd restart 2>/dev/null || true
                fi
                if command -v resolvectl &> /dev/null; then
                    resolvectl flush-caches 2>/dev/null || true
                fi
            else
                echo "已取消恢复操作"
            fi
            
        elif [ "$original_state" == "existed" ]; then
            echo "检测到原先${gl_lv}存在${gl_bai} gai.conf 文件"
            local latest_backup
            latest_backup=$(ls -t /etc/gai.conf.bak.* 2>/dev/null | head -1)
            
            if [ -n "$latest_backup" ]; then
                echo "找到备份文件: $latest_backup"
                echo ""
                local confirm
                read -e -p "确认要从备份恢复吗？[y/n]: " confirm
                
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    cp "$latest_backup" /etc/gai.conf
                    rm -f /etc/gai.conf.original_state
                    echo -e "${gl_lv}✅ 已从备份恢复配置${gl_bai}"
                    if command -v nscd &> /dev/null; then
                        systemctl restart nscd 2>/dev/null || true
                    fi
                    if command -v resolvectl &> /dev/null; then
                        resolvectl flush-caches 2>/dev/null || true
                    fi
                    echo ""
                    echo "当前出口 IP 地址："
                    echo "------------------------------------------------"
                    curl -s ip.sb 2>/dev/null || echo "无法获取"
                    echo "------------------------------------------------"
                else
                    echo "已取消恢复操作"
                fi
            else
                echo -e "${gl_hong}错误: 未找到备份文件${gl_bai}"
            fi
        fi
    fi
    echo ""
    break_end
}

manage_ip_priority() {
    while true; do
        clear
        echo -e "${gl_kjlan}=== 设置IPv4/IPv6优先级 ===${gl_bai}"
        echo ""
        echo "1. 设置IPv4优先"
        echo "2. 设置IPv6优先"
        echo "3. 恢复IP优先级配置"
        echo "0. 返回主菜单"
        echo ""
        echo "------------------------------------------------"
        local ip_priority_choice
        read -e -p "请选择操作 [0-3]: " ip_priority_choice
        echo ""
        
        case $ip_priority_choice in
            1) set_ip_priority "ipv4" ;;
            2) set_ip_priority "ipv6" ;;
            3) restore_gai_conf ;;
            0) break ;;
            *) echo -e "${gl_hong}无效选择，请重新输入${gl_bai}"; sleep 2 ;;
        esac
    done
}

disable_ipv6_temporary() {
    clear
    echo -e "${gl_kjlan}=== 临时禁用IPv6 ===${gl_bai}"
    echo ""
    echo "此操作将临时禁用IPv6，重启后自动恢复"
    echo "------------------------------------------------"
    echo ""
    local confirm
    read -e -p "$(echo -e "${gl_huang}确认临时禁用IPv6？(Y/N): ${gl_bai}")" confirm
    
    case "$confirm" in
        [Yy])
            echo ""
            echo "正在禁用IPv6..."
            sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1 || true
            sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1 || true
            sysctl -w net.ipv6.conf.lo.disable_ipv6=1 >/dev/null 2>&1 || true
            
            local ipv6_status
            ipv6_status=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo "0")
            
            echo ""
            if [ "$ipv6_status" = "1" ]; then
                echo -e "${gl_lv}✅ IPv6 已临时禁用${gl_bai}"
                echo ""
                echo -e "${gl_zi}注意：${gl_bai}"
                echo "  - 此设置仅在当前会话有效"
                echo "  - 重启后 IPv6 将自动恢复"
            else
                echo -e "${gl_hong}❌ IPv6 禁用失败${gl_bai}"
            fi
            ;;
        *)
            echo "已取消"
            ;;
    esac
    echo ""
    break_end
}

disable_ipv6_permanent() {
    clear
    echo -e "${gl_kjlan}=== 永久禁用IPv6 ===${gl_bai}"
    echo ""
    echo "此操作将永久禁用IPv6，重启后仍然生效"
    echo "------------------------------------------------"
    echo ""
    
    local confirm="N"
    if [ -f /etc/sysctl.d/99-disable-ipv6.conf ]; then
        echo -e "${gl_huang}⚠️  检测到已存在永久禁用配置${gl_bai}"
        echo ""
        if [ "$AUTO_MODE" = "1" ]; then
            confirm=Y
        else
            read -e -p "$(echo -e "${gl_huang}是否重新执行永久禁用？(Y/N): ${gl_bai}")" confirm
        fi
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "已取消"
            break_end
            return 1
        fi
    else
        if [ "$AUTO_MODE" = "1" ]; then
            confirm=Y
        else
            read -e -p "$(echo -e "${gl_huang}确认永久禁用IPv6？(Y/N): ${gl_bai}")" confirm
        fi
    fi

    case "$confirm" in
        [Yy])
            echo ""
            echo -e "${gl_zi}[步骤 1/3] 备份当前IPv6状态...${gl_bai}"
            
            local ipv6_all ipv6_default ipv6_lo
            ipv6_all=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo "0")
            ipv6_default=$(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null || echo "0")
            ipv6_lo=$(sysctl -n net.ipv6.conf.lo.disable_ipv6 2>/dev/null || echo "0")
            
            cat > /etc/sysctl.d/.ipv6-state-backup.conf << BACKUPEOF
# IPv6 State Backup
net.ipv6.conf.all.disable_ipv6=${ipv6_all}
net.ipv6.conf.default.disable_ipv6=${ipv6_default}
net.ipv6.conf.lo.disable_ipv6=${ipv6_lo}
BACKUPEOF
            
            echo -e "${gl_lv}✅ 状态已备份${gl_bai}"
            echo ""
            
            echo -e "${gl_zi}[步骤 2/3] 创建永久禁用配置...${gl_bai}"
            
            cat > /etc/sysctl.d/99-disable-ipv6.conf << EOF
# Permanently Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
            
            echo -e "${gl_lv}✅ 配置文件已创建${gl_bai}"
            echo ""
            
            echo -e "${gl_zi}[步骤 3/3] 应用配置...${gl_bai}"
            sysctl --system >/dev/null 2>&1 || true
            
            local ipv6_status
            ipv6_status=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo "0")
            
            echo ""
            if [ "$ipv6_status" = "1" ]; then
                echo -e "${gl_lv}✅ IPv6 已永久禁用${gl_bai}"
            else
                echo -e "${gl_hong}❌ IPv6 禁用失败${gl_bai}"
                rm -f /etc/sysctl.d/99-disable-ipv6.conf /etc/sysctl.d/.ipv6-state-backup.conf 2>/dev/null || true
            fi
            ;;
        *)
            echo "已取消"
            ;;
    esac
    echo ""
    break_end
}

cancel_ipv6_permanent_disable() {
    clear
    echo -e "${gl_kjlan}=== 取消永久禁用IPv6 ===${gl_bai}"
    echo ""
    
    if [ ! -f /etc/sysctl.d/99-disable-ipv6.conf ]; then
        echo -e "${gl_huang}⚠️  未检测到永久禁用配置${gl_bai}"
        break_end
        return 1
    fi
    
    local confirm
    read -e -p "$(echo -e "${gl_huang}确认取消永久禁用并恢复原始状态？(Y/N): ${gl_bai}")" confirm
    
    case "$confirm" in
        [Yy])
            echo ""
            echo -e "${gl_zi}[步骤 1/4] 删除永久禁用配置...${gl_bai}"
            rm -f /etc/sysctl.d/99-disable-ipv6.conf
            echo -e "${gl_lv}✅ 配置文件已删除${gl_bai}"
            echo ""
            
            echo -e "${gl_zi}[步骤 2/4] 检查备份文件...${gl_bai}"
            if [ -f /etc/sysctl.d/.ipv6-state-backup.conf ]; then
                echo -e "${gl_lv}✅ 找到备份文件${gl_bai}"
                echo ""
                echo -e "${gl_zi}[步骤 3/4] 从备份还原原始状态...${gl_bai}"
                
                local backup_all backup_default backup_lo
                backup_all=$(grep 'net.ipv6.conf.all.disable_ipv6' /etc/sysctl.d/.ipv6-state-backup.conf | awk -F'=' '{print $2}' || echo "0")
                backup_default=$(grep 'net.ipv6.conf.default.disable_ipv6' /etc/sysctl.d/.ipv6-state-backup.conf | awk -F'=' '{print $2}' || echo "0")
                backup_lo=$(grep 'net.ipv6.conf.lo.disable_ipv6' /etc/sysctl.d/.ipv6-state-backup.conf | awk -F'=' '{print $2}' || echo "0")
                
                sysctl -w net.ipv6.conf.all.disable_ipv6=${backup_all} >/dev/null 2>&1 || true
                sysctl -w net.ipv6.conf.default.disable_ipv6=${backup_default} >/dev/null 2>&1 || true
                sysctl -w net.ipv6.conf.lo.disable_ipv6=${backup_lo} >/dev/null 2>&1 || true
                
                rm -f /etc/sysctl.d/.ipv6-state-backup.conf
                echo -e "${gl_lv}✅ 已从备份还原原始状态${gl_bai}"
            else
                echo -e "${gl_huang}⚠️  未找到备份文件${gl_bai}"
                echo ""
                echo -e "${gl_zi}[步骤 3/4] 恢复到系统默认（启用IPv6）...${gl_bai}"
                
                sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null 2>&1 || true
                sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null 2>&1 || true
                sysctl -w net.ipv6.conf.lo.disable_ipv6=0 >/dev/null 2>&1 || true
                echo -e "${gl_lv}✅ 已恢复到系统默认（IPv6启用）${gl_bai}"
            fi
            
            echo ""
            echo -e "${gl_zi}[步骤 4/4] 应用配置...${gl_bai}"
            sysctl --system >/dev/null 2>&1 || true
            
            local ipv6_status
            ipv6_status=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo "0")
            
            echo ""
            if [ "$ipv6_status" = "0" ]; then
                echo -e "${gl_lv}✅ IPv6 已恢复启用${gl_bai}"
            else
                echo -e "${gl_huang}⚠️  IPv6 状态: 禁用（值=${ipv6_status}）${gl_bai}"
            fi
            ;;
        *)
            echo "已取消"
            ;;
    esac
    echo ""
    break_end
}

manage_ipv6() {
    while true; do
        clear
        echo -e "${gl_kjlan}=== IPv6 管理 ===${gl_bai}"
        echo ""
        
        local ipv6_status status_text status_color
        ipv6_status=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo "0")
        
        if [ "$ipv6_status" = "0" ]; then
            status_text="启用"
            status_color="${gl_lv}"
        else
            status_text="禁用"
            status_color="${gl_hong}"
        fi
        
        echo -e "当前状态: ${status_color}${status_text}${gl_bai}"
        echo ""
        
        if [ -f /etc/sysctl.d/99-disable-ipv6.conf ]; then
            echo -e "${gl_huang}⚠️  检测到永久禁用配置文件${gl_bai}"
            echo ""
        fi
        
        echo "------------------------------------------------"
        echo "1. 临时禁用IPv6（重启后恢复）"
        echo "2. 永久禁用IPv6（重启后仍生效）"
        echo "3. 取消永久禁用（完全还原）"
        echo "0. 返回主菜单"
        echo "------------------------------------------------"
        local choice
        read -e -p "请输入选择: " choice
        
        case "$choice" in
            1) disable_ipv6_temporary ;;
            2) disable_ipv6_permanent ;;
            3) cancel_ipv6_permanent_disable ;;
            0) return ;;
            *) echo "无效选择"; sleep 2 ;;
        esac
    done
}

set_temp_socks5_proxy() {
    clear
    echo -e "${gl_kjlan}=== 设置临时SOCKS5代理 ===${gl_bai}"
    echo ""
    echo "此代理配置仅对当前终端会话有效，重启后自动失效"
    echo "------------------------------------------------"
    echo ""
    
    local proxy_ip=""
    while true; do
        read -e -p "$(echo -e "${gl_huang}请输入代理服务器IP: ${gl_bai}")" proxy_ip
        if [ -z "$proxy_ip" ]; then
            echo -e "${gl_hong}❌ IP地址不能为空${gl_bai}"
        elif [[ "$proxy_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            local valid_ip=true
            IFS='.' read -ra octets <<< "$proxy_ip"
            for octet in "${octets[@]}"; do
                if [ "$octet" -gt 255 ]; then
                    valid_ip=false
                    break
                fi
            done
            if [ "$valid_ip" = true ]; then
                echo -e "${gl_lv}✅ IP地址: ${proxy_ip}${gl_bai}"
                break
            else
                echo -e "${gl_hong}❌ IP地址范围无效（每段必须在0-255之间）${gl_bai}"
            fi
        else
            echo -e "${gl_hong}❌ 无效的IP地址格式${gl_bai}"
        fi
    done
    
    echo ""
    local proxy_port=""
    while true; do
        read -e -p "$(echo -e "${gl_huang}请输入端口: ${gl_bai}")" proxy_port
        if [ -z "$proxy_port" ]; then
            echo -e "${gl_hong}❌ 端口不能为空${gl_bai}"
        elif [[ "$proxy_port" =~ ^[0-9]+$ ]] && [ "$proxy_port" -ge 1 ] && [ "$proxy_port" -le 65535 ]; then
            echo -e "${gl_lv}✅ 端口: ${proxy_port}${gl_bai}"
            break
        else
            echo -e "${gl_hong}❌ 无效端口，请输入 1-65535 之间的数字${gl_bai}"
        fi
    done
    
    echo ""
    local proxy_user=""
    read -e -p "$(echo -e "${gl_huang}请输入用户名（留空跳过）: ${gl_bai}")" proxy_user
    
    if [ -n "$proxy_user" ]; then
        echo -e "${gl_lv}✅ 用户名: ${proxy_user}${gl_bai}"
    else
        echo -e "${gl_zi}未设置用户名（无认证模式）${gl_bai}"
    fi
    
    echo ""
    local proxy_pass=""
    if [ -n "$proxy_user" ]; then
        read -e -p "$(echo -e "${gl_huang}请输入密码: ${gl_bai}")" proxy_pass
        if [ -n "$proxy_pass" ]; then
            echo -e "${gl_lv}✅ 密码已设置${gl_bai}"
        else
            echo -e "${gl_huang}⚠️  密码为空${gl_bai}"
        fi
    fi
    
    local proxy_url=""
    if [ -n "$proxy_user" ] && [ -n "$proxy_pass" ]; then
        proxy_url="socks5://${proxy_user}:${proxy_pass}@${proxy_ip}:${proxy_port}"
    elif [ -n "$proxy_user" ]; then
        proxy_url="socks5://${proxy_user}@${proxy_ip}:${proxy_port}"
    else
        proxy_url="socks5://${proxy_ip}:${proxy_port}"
    fi
    
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local secure_tmp="${XDG_RUNTIME_DIR:-/tmp}"
    local config_file="${secure_tmp}/socks5_proxy_${timestamp}.sh"

    local old_umask
    old_umask=$(umask)
    umask 077

    cat > "$config_file" << PROXYEOF
#!/bin/bash
export http_proxy="${proxy_url}"
export https_proxy="${proxy_url}"
export all_proxy="${proxy_url}"
echo "SOCKS5 代理已启用："
echo "  服务器: ${proxy_ip}:${proxy_port}"
echo "  用户: ${proxy_user:-无}"
PROXYEOF

    umask "$old_umask"
    chmod 600 "$config_file" 2>/dev/null || true
    
    echo ""
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo -e "${gl_lv}✅ 代理配置文件已生成！${gl_bai}"
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo ""
    echo -e "${gl_huang}使用方法：${gl_bai}"
    echo -e "1. ${gl_lv}应用代理配置：${gl_bai}"
    echo "   source ${config_file}"
    echo ""
    echo -e "2. ${gl_lv}取消代理：${gl_bai}"
    echo "   unset http_proxy https_proxy all_proxy"
    echo ""
    break_end
}
# ==============================================================================
# [ 区块 VI: SNI 连通性测试矩阵 (Xray) ]
# ==============================================================================

run_sni_scanner() {
    title "SNI 连通性测试 (纯 TCP 延迟与可用性验证)"
    info "扫描进行中... (按回车键可随时中止并结算已扫描节点)\n"
    
    if ! mkdir -p "$CONFIG_DIR" 2>/dev/null; then
        true
    fi
    
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
        if read -t 0.1 -n 1 2>/dev/null; then
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
    
    # 修复逻辑反转: Bash 中 0 代表 true(成功), 非 0 代表 false(失败)
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
            
            local sel
            read -rp "  请选择对应操作或节点: " sel
            sel=${sel:-1}
            
            case "$sel" in
                q|Q) return 1 ;;
                r|R) run_sni_scanner; continue ;;
                m|M)
                    local m_sel
                    read -rp "请输入所需序号 (例如 1 3 5，或 all): " m_sel
                    local arr=()
                    
                    if [[ "$m_sel" == "all" ]]; then
                        while read -r p_sni p_rest; do
                            if [[ -n "$p_sni" ]]; then
                                arr+=("$p_sni")
                            fi
                        done < "$SNI_CACHE_FILE"
                    else
                        for i in $m_sel; do
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
                    local d
                    read -rp "请输入自定义域名: " d
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
                local force_use
                read -rp "强制使用该域名？(y/n): " force_use
                if [[ "$force_use" =~ ^[yY]$ ]]; then
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
# [ 区块 VII: 综合网络连通性与压力测试引擎 ]
# ==============================================================================

run_speedtest() {
    while true; do
        clear
        echo -e "${gl_kjlan}=== 服务器带宽与速度综合测试 ===${gl_bai}"
        echo ""
        
        local cpu_arch
        cpu_arch=$(uname -m)
        echo "检测到系统架构: ${gl_huang}${cpu_arch}${gl_bai}"
        echo ""
        
        if ! command -v speedtest &>/dev/null; then
            echo "Speedtest 未安装，正在下载安装..."
            echo "------------------------------------------------"
            echo ""
            
            local download_url
            local tarball_name
            
            case "$cpu_arch" in
                x86_64)
                    download_url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz"
                    tarball_name="ookla-speedtest-1.2.0-linux-x86_64.tgz"
                    echo "使用 AMD64 架构版本..."
                    ;;
                aarch64)
                    download_url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-aarch64.tgz"
                    tarball_name="speedtest.tgz"
                    echo "使用 ARM64 架构版本..."
                    ;;
                *)
                    echo -e "${gl_hong}错误: 不支持的架构 ${cpu_arch}${gl_bai}"
                    echo "目前仅支持 x86_64 和 aarch64 架构"
                    echo ""
                    break_end
                    return 1
                    ;;
            esac
            
            cd /tmp || {
                echo -e "${gl_hong}错误: 无法切换到 /tmp 目录${gl_bai}"
                break_end
                return 1
            }
            
            echo "正在下载..."
            if [ "$cpu_arch" = "aarch64" ]; then
                curl -Lo "$tarball_name" "$download_url" 2>/dev/null || true
            else
                wget -q "$download_url" 2>/dev/null || true
            fi
            
            if [ ! -f "$tarball_name" ]; then
                echo -e "${gl_hong}下载失败！${gl_bai}"
                break_end
                return 1
            fi
            
            echo "正在解压..."
            tar -xzf "$tarball_name" 2>/dev/null || true
            
            if [ ! -f "speedtest" ]; then
                echo -e "${gl_hong}解压失败！${gl_bai}"
                rm -f "$tarball_name" 2>/dev/null || true
                break_end
                return 1
            fi
            
            mv speedtest /usr/local/bin/ 2>/dev/null || true
            rm -f "$tarball_name" 2>/dev/null || true
            
            echo -e "${gl_lv}✅ Speedtest 安装成功！${gl_bai}"
            echo ""
        else
            echo -e "${gl_lv}✅ Speedtest 已安装${gl_bai}"
        fi
        
        echo ""
        echo -e "${gl_kjlan}请选择测速模式：${gl_bai}"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "1. 自动测速"
        echo "2. 手动选择服务器 ⭐ 推荐"
        echo ""
        echo "0. 返回上级菜单"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        local speed_choice
        read -e -p "请输入选择 [1]: " speed_choice
        speed_choice=${speed_choice:-1}
        
        case "$speed_choice" in
            1)
                echo ""
                echo -e "${gl_zi}正在搜索附近测速服务器...${gl_bai}"
                
                local servers_list
                servers_list=$(speedtest --accept-license --servers 2>/dev/null | sed -nE 's/^[[:space:]]*([0-9]+).*/\1/p' | head -n 10 || echo "")
                
                if [ -z "$servers_list" ]; then
                    echo -e "${gl_huang}无法获取服务器列表，使用自动选择...${gl_bai}"
                    servers_list="auto"
                else
                    local server_count
                    server_count=$(echo "$servers_list" | wc -l)
                    echo -e "${gl_lv}✅ 找到 ${server_count} 个附近服务器${gl_bai}"
                fi
                echo ""
                
                local speedtest_output=""
                local test_success=false
                local attempt=0
                local max_attempts=5
                
                for server_id in $servers_list; do
                    attempt=$((attempt + 1))
                    
                    if [ $attempt -gt $max_attempts ]; then
                        echo -e "${gl_huang}已尝试 ${max_attempts} 个服务器，停止尝试${gl_bai}"
                        break
                    fi
                    
                    if [ "$server_id" = "auto" ]; then
                        echo -e "${gl_zi}[尝试 ${attempt}] 自动选择最近服务器...${gl_bai}"
                        echo "------------------------------------------------"
                        speedtest --accept-license 2>/dev/null || true
                        test_success=true
                        break
                    else
                        echo -e "${gl_zi}[尝试 ${attempt}] 测试服务器 #${server_id}...${gl_bai}"
                        echo "------------------------------------------------"
                        speedtest_output=$(speedtest --accept-license --server-id="$server_id" 2>&1 || true)
                        echo "$speedtest_output"
                        echo ""
                        
                        if echo "$speedtest_output" | grep -q "Download:" && ! echo "$speedtest_output" | grep -qi "FAILED\|error"; then
                            echo -e "${gl_lv}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
                            echo -e "${gl_lv}✅ 测速成功！${gl_bai}"
                            echo -e "${gl_lv}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
                            test_success=true
                            break
                        else
                            echo -e "${gl_huang}⚠️ 此服务器测速失败，尝试下一个...${gl_bai}"
                            echo ""
                        fi
                    fi
                done
                
                if [ "$test_success" = false ]; then
                    echo ""
                    echo -e "${gl_hong}❌ 所有服务器测速均失败${gl_bai}"
                    echo -e "${gl_zi}建议使用「手动选择服务器」模式${gl_bai}"
                fi
                
                echo ""
                break_end
                ;;
            2)
                echo ""
                echo -e "${gl_zi}正在获取附近服务器列表...${gl_bai}"
                echo ""
                
                local server_list_output
                server_list_output=$(speedtest --accept-license --servers 2>/dev/null | head -n 15 || echo "")
                
                if [ -z "$server_list_output" ]; then
                    echo -e "${gl_hong}❌ 无法获取服务器列表${gl_bai}"
                    echo ""
                    break_end
                    continue
                fi
                
                echo -e "${gl_kjlan}附近的测速服务器列表：${gl_bai}"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "$server_list_output"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo ""
                echo -e "${gl_zi}💡 提示：ID 列的数字就是服务器ID${gl_bai}"
                echo ""
                
                local server_id=""
                while true; do
                    read -e -p "$(echo -e "${gl_huang}请输入服务器ID（纯数字，输入0返回）: ${gl_bai}")" server_id
                    
                    if [ "$server_id" = "0" ]; then
                        break
                    elif [[ "$server_id" =~ ^[0-9]+$ ]]; then
                        echo ""
                        echo -e "${gl_huang}正在使用服务器 #${server_id} 测速...${gl_bai}"
                        echo "------------------------------------------------"
                        echo ""
                        
                        speedtest --accept-license --server-id="$server_id" 2>/dev/null || true
                        
                        echo ""
                        echo "------------------------------------------------"
                        break_end
                        break
                    else
                        echo -e "${gl_hong}❌ 无效输入，请输入纯数字的服务器ID${gl_bai}"
                    fi
                done
                ;;
            0)
                return 0
                ;;
            *)
                echo -e "${gl_hong}无效选择${gl_bai}"
                sleep 1
                ;;
        esac
    done
}

run_backtrace() {
    clear
    echo -e "${gl_kjlan}=== 三网回程路由穿透测试 ===${gl_bai}"
    echo ""
    echo "正在拉取并运行全网路由侦测脚本..."
    echo "------------------------------------------------"
    echo ""

    if ! run_remote_script "https://raw.githubusercontent.com/ludashi2020/backtrace/main/install.sh" sh; then
        echo -e "${gl_hong}❌ 侦测脚本执行中止。${gl_bai}"
        break_end
        return 1
    fi

    echo ""
    echo "------------------------------------------------"
    break_end
}

run_ns_detect() {
    clear
    echo -e "${gl_kjlan}=== NS (NodeSeek) 综合机能一键探针 ===${gl_bai}"
    echo ""
    echo "正在加载并运行环境综合检测脚本..."
    echo "------------------------------------------------"
    echo ""

    if ! run_remote_script "https://run.NodeQuality.com" bash; then
        echo -e "${gl_hong}❌ 探针执行失败。${gl_bai}"
        break_end
        return 1
    fi

    echo ""
    echo "------------------------------------------------"
    break_end
}

run_ip_quality_check() {
    clear
    echo -e "${gl_kjlan}=== 全局 IP 信誉度综合分析 (IPv4 + IPv6) ===${gl_bai}"
    echo ""
    echo "正在运行 IP 质量雷达扫描..."
    echo "------------------------------------------------"
    echo ""

    if ! run_remote_script "https://IP.Check.Place" bash; then
        echo -e "${gl_hong}❌ 雷达扫描中断。${gl_bai}"
        break_end
        return 1
    fi

    echo ""
    echo "------------------------------------------------"
    break_end
}

run_ip_quality_check_ipv4() {
    clear
    echo -e "${gl_kjlan}=== IPv4 专项信誉度综合分析 ===${gl_bai}"
    echo ""
    echo "正在运行纯 IPv4 质量雷达扫描..."
    echo "------------------------------------------------"
    echo ""

    if ! run_remote_script "https://IP.Check.Place" bash -4; then
        echo -e "${gl_hong}❌ 雷达扫描中断。${gl_bai}"
        break_end
        return 1
    fi

    echo ""
    echo "------------------------------------------------"
    break_end
}

run_network_latency_check() {
    clear
    echo -e "${gl_kjlan}=== 全球节点 ICMP 延迟热图探测 ===${gl_bai}"
    echo ""
    echo "正在下发延迟雷达探测指令..."
    echo "------------------------------------------------"
    echo ""

    if ! run_remote_script "https://Check.Place" bash -N; then
        echo -e "${gl_hong}❌ 雷达通信失败。${gl_bai}"
        break_end
        return 1
    fi

    echo ""
    echo "------------------------------------------------"
    break_end
}

run_international_speed_test() {
    clear
    echo -e "${gl_kjlan}=== 国际互联宽带质量综合评测 ===${gl_bai}"
    echo ""
    echo "正在部署宽带压测引擎..."
    echo "------------------------------------------------"
    echo ""

    cd /tmp || {
        echo -e "${gl_hong}错误: 无法进入 /tmp 临时缓冲区。${gl_bai}"
        break_end
        return 1
    }

    echo "正在下载压测载荷..."
    if ! wget -q https://raw.githubusercontent.com/Cd1s/network-latency-tester/main/latency.sh 2>/dev/null; then
        echo -e "${gl_hong}下载失败！${gl_bai}"
        break_end
        return 1
    fi

    chmod +x latency.sh 2>/dev/null || true

    echo ""
    echo "全速起步..."
    echo "------------------------------------------------"
    echo ""
    ./latency.sh 2>/dev/null || true

    rm -f latency.sh 2>/dev/null || true

    echo ""
    echo "------------------------------------------------"
    break_end
}
# ==============================================================================
# iperf3 单线程网络压测与全网解锁探测
# ==============================================================================

iperf3_single_thread_test() {
    clear
    echo -e "${gl_zi}╔════════════════════════════════════════════╗${gl_bai}"
    echo -e "${gl_zi}║       iperf3 单线程网络性能极限测试        ║${gl_bai}"
    echo -e "${gl_zi}╚════════════════════════════════════════════╝${gl_bai}"
    echo ""
    
    if ! command -v iperf3 &>/dev/null; then
        echo -e "${gl_huang}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
        echo -e "${gl_huang}检测到 iperf3 未安装，正在自动部署...${gl_bai}"
        echo -e "${gl_huang}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
        echo ""
        
        if command -v apt-get &>/dev/null || command -v apt &>/dev/null; then
            echo "步骤 1/2: 更新软件包列表..."
            apt-get update -y >/dev/null 2>&1 || true

            echo ""
            echo "步骤 2/2: 安装 iperf3..."
            apt-get install -y iperf3 >/dev/null 2>&1 || true
            
            if ! command -v iperf3 &>/dev/null; then
                echo ""
                echo -e "${gl_hong}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
                echo -e "${gl_hong}iperf3 安装失败，源不可达或包损坏！${gl_bai}"
                echo -e "${gl_hong}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
                break_end
                return 1
            fi
        else
            echo -e "${gl_hong}错误: 暂不支持使用自动包管理器安装，请手动配置。${gl_bai}"
            break_end
            return 1
        fi
        
        echo ""
        echo -e "${gl_lv}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
        echo -e "${gl_lv}✓ iperf3 安装成功！${gl_bai}"
        echo -e "${gl_lv}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
        echo ""
    fi
    
    echo -e "${gl_kjlan}[步骤 1/3] 锁定目标服务器${gl_bai}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local target_host
    read -e -p "请输入目标服务器 IP 或域名: " target_host
    
    if [ -z "$target_host" ]; then
        echo -e "${gl_hong}错误: 目标服务器不能为空！${gl_bai}"
        break_end
        return 1
    fi
    echo ""
    
    echo -e "${gl_kjlan}[步骤 2/3] 选择压测方向${gl_bai}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "1. 上传压测（本机 → 远程服务器）"
    echo "2. 下载压测（远程服务器 → 本机）"
    echo ""
    local direction_choice direction_flag direction_text
    read -e -p "请选择压测方向 [1-2]: " direction_choice
    
    case "$direction_choice" in
        1)
            direction_flag=""
            direction_text="上行（本机 → ${target_host}）"
            ;;
        2)
            direction_flag="-R"
            direction_text="下行（${target_host} → 本机）"
            ;;
        *)
            echo -e "${gl_hong}无效的选择，使用默认值: 上传压测${gl_bai}"
            direction_flag=""
            direction_text="上行（本机 → ${target_host}）"
            ;;
    esac
    echo ""
    
    echo -e "${gl_kjlan}[步骤 3/3] 设置持续压测时长${gl_bai}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "建议: 30-120 秒（默认 60 秒）"
    echo ""
    local test_duration
    read -e -p "请输入压测时长（秒）[60]: " test_duration
    test_duration=${test_duration:-60}
    
    if ! [[ "$test_duration" =~ ^[0-9]+$ ]]; then
        echo -e "${gl_huang}警告: 无效的时长，强制使用默认值 60 秒${gl_bai}"
        test_duration=60
    fi
    
    if [ "$test_duration" -lt 1 ]; then
        test_duration=1
    elif [ "$test_duration" -gt 3600 ]; then
        echo -e "${gl_huang}警告: 时长过长，触发保护机制截断为 3600 秒${gl_bai}"
        test_duration=3600
    fi
    
    echo ""
    echo -e "${gl_lv}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo -e "${gl_kjlan}测试配置确认：${gl_bai}"
    echo "  目标服务器: ${target_host}"
    echo "  测试方向: ${direction_text}"
    echo "  测试时长: ${test_duration} 秒"
    echo -e "${gl_lv}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo ""
    
    echo -e "${gl_huang}正在测试底层连通性...${gl_bai}"
    if ! ping -c 2 -W 3 "$target_host" &>/dev/null; then
        echo -e "${gl_hong}警告: 无法 ping 通目标服务器，这可能由于禁 Ping 导致，将强行尝试 iperf3...${gl_bai}"
    else
        echo -e "${gl_lv}✓ 目标服务器可达${gl_bai}"
    fi
    
    echo ""
    echo -e "${gl_kjlan}正在下发 iperf3 压测载荷，请紧握扶手...${gl_bai}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    local test_output
    test_output=$(mktemp) || true
    iperf3 -c "$target_host" -P 1 $direction_flag -t "$test_duration" -f m 2>&1 | tee "$test_output" || true
    
    # 检查是否成功
    if grep -q "error" "$test_output" 2>/dev/null; then
        echo -e "${gl_hong}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
        echo -e "${gl_hong}压测连接失败！${gl_bai}"
        echo ""
        echo "可能的原因："
        echo "  1. 目标服务器未开启 iperf3 守护进程 (需运行: iperf3 -s)"
        echo "  2. 防火墙死锁拦截（需放行默认端口 TCP/UDP 5201）"
        echo "  3. 路由黑洞"
        echo -e "${gl_hong}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
        rm -f "$test_output" 2>/dev/null || true
        break_end
        return 1
    fi
    
    echo -e "${gl_lv}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo -e "${gl_zi}╔════════════════════════════════════════════╗${gl_bai}"
    echo -e "${gl_zi}║            测 试 结 果 汇 总               ║${gl_bai}"
    echo -e "${gl_zi}╚════════════════════════════════════════════╝${gl_bai}"
    echo ""
    
    local bandwidth transfer retrans
    bandwidth=$(grep "sender\|receiver" "$test_output" 2>/dev/null | tail -1 | awk '{print $7, $8}' || echo "")
    transfer=$(grep "sender\|receiver" "$test_output" 2>/dev/null | tail -1 | awk '{print $5, $6}' || echo "")
    retrans=$(grep "sender" "$test_output" 2>/dev/null | tail -1 | awk '{print $9}' || echo "")
    
    echo -e "${gl_kjlan}[环境锚点]${gl_bai}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  目标服务器: ${target_host}"
    echo "  数据流方向: ${direction_text}"
    echo "  持续压迫时间: ${test_duration} 秒"
    echo "  测试线程流: 1"
    echo ""
    
    echo -e "${gl_kjlan}[最终性能指标]${gl_bai}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ -n "$bandwidth" ]; then
        echo "  平均宽带速率: ${bandwidth}"
    else
        echo "  平均宽带速率: 截获失败"
    fi
    
    if [ -n "$transfer" ]; then
        echo "  全域数据搬运: ${transfer}"
    else
        echo "  全域数据搬运: 截获失败"
    fi
    
    if [ -n "$retrans" ] && [ "$retrans" != "" ]; then
        echo "  底层重传丢包: ${retrans}"
        if [ "$retrans" -eq 0 ]; then
            echo -e "  链路质量判定: ${gl_lv}极佳（0 重传零封）${gl_bai}"
        elif [ "$retrans" -lt 100 ]; then
            echo -e "  链路质量判定: ${gl_lv}良好稳定${gl_bai}"
        elif [ "$retrans" -lt 1000 ]; then
            echo -e "  链路质量判定: ${gl_huang}中庸（抗干扰波动明显）${gl_bai}"
        else
            echo -e "  链路质量判定: ${gl_hong}恶劣（灾难级重传）${gl_bai}"
        fi
    fi
    
    echo ""
    echo -e "${gl_lv}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo -e "${gl_lv}✓ 物理探针执行完毕${gl_bai}"
    echo -e "${gl_lv}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    
    rm -f "$test_output" 2>/dev/null || true
    echo ""
    break_end
}

run_unlock_check() {
    clear
    echo -e "${gl_kjlan}=== 全球流媒体与 AI 防御墙穿透检测 ===${gl_bai}"
    echo ""
    echo "正在下发深层嗅探指令并规避指纹拦截..."
    echo "------------------------------------------------"
    echo ""

    if ! run_remote_script "https://github.com/1-stream/RegionRestrictionCheck/raw/main/check.sh" bash; then
        echo -e "${gl_hong}❌ 嗅探模块被服务器终端掐断。${gl_bai}"
        break_end
        return 1
    fi

    echo ""
    echo "------------------------------------------------"
    break_end
}

run_pf_realm() {
    clear
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo -e "${gl_kjlan}  zywe_realm 底层路由劫持转发脚本${gl_bai}"
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo ""
    echo "此组件深度重构了 zywe 核心逻辑，提供无损高并发转发："
    echo ""
    echo -e "${gl_lv}👉 原始库访问: https://github.com/zywe03/realm-xwPF${gl_bai}"
    echo ""
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    break_end
}

run_kxy_script() {
    clear
    echo -e "${gl_kjlan}=== 酷雪云 (KXY) 专属维护架构箱 ===${gl_bai}"
    echo ""
    echo "正在拉取核心控制阵列..."
    echo "------------------------------------------------"
    echo ""

    if ! run_remote_script "https://cdn.kxy.ovh/kxy.sh" bash; then
        echo -e "${gl_hong}❌ 控制阵列通信中断。${gl_bai}"
        break_end
        return 1
    fi

    echo ""
    echo "------------------------------------------------"
    break_end
}

run_kejilion_script() {
    clear
    echo -e "${gl_kjlan}=== 科技lion 聚合运维脚本 ===${gl_bai}"
    echo ""
    echo "正在转交控制权至第三方生态系统..."
    echo "------------------------------------------------"
    echo ""

    if ! run_remote_script "kejilion.sh" bash; then
        echo -e "${gl_hong}❌ 第三方网关呼叫失败。${gl_bai}"
        break_end
        return 1
    fi

    echo ""
    echo "------------------------------------------------"
    break_end
}

run_fscarmen_singbox() {
    clear
    echo -e "${gl_kjlan}=== FSCarmen Sing-Box 一键部署引擎 ===${gl_bai}"
    echo ""
    echo "正在加载 F 佬 Sing-box 核心配置箱..."
    echo "------------------------------------------------"
    echo ""

    if ! run_remote_script "https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh" bash; then
        echo -e "${gl_hong}❌ 组件构建树下载失败。${gl_bai}"
        break_end
        return 1
    fi

    echo ""
    echo "------------------------------------------------"
    break_end
}

# ==============================================================================
# BBR 与内核专项优化模块 (CAKE / 锐速清理)
# ==============================================================================

remove_bbr_lotserver() {
  sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.d/99-sysctl.conf 2>/dev/null || true
  sed -i '/net.core.default_qdisc/d' /etc/sysctl.d/99-sysctl.conf 2>/dev/null || true
  sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.d/99-sysctl.conf 2>/dev/null || true
  sed -i '/net.ipv4.tcp_ecn/d' /etc/sysctl.conf 2>/dev/null || true
  sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf 2>/dev/null || true
  sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf 2>/dev/null || true
  sysctl --system >/dev/null 2>&1 || true

  rm -rf bbrmod 2>/dev/null || true

  if [[ -e /appex/bin/lotServer.sh ]]; then
    if ! printf '\n' | run_remote_script "https://raw.githubusercontent.com/fei5seven/lotServer/master/lotServerInstall.sh" bash uninstall; then
      echo -e "${gl_huang}⚠️  lotServer 卸载脚本执行失败，已无视并强行跳过。${gl_bai}"
    fi
  fi
  clear
}

startbbrcake() {
  remove_bbr_lotserver
  echo "net.core.default_qdisc=cake" >>/etc/sysctl.d/99-sysctl.conf
  echo "net.ipv4.tcp_congestion_control=bbr" >>/etc/sysctl.d/99-sysctl.conf
  sysctl --system >/dev/null 2>&1 || true
  echo -e "${gl_lv}[信息]${gl_bai} BBR+CAKE 底层算法已物理替换成功，强烈建议重启以释放系统旧内存！"
  break_end
}

# ==============================================================================
# BBR 针对 Reality 的深度定制优化机能组 (星辰大海系列)
# ==============================================================================

optimize_xinchendahai() {
    echo -e "${gl_lv}切换到星辰大海ヾ优化模式...${gl_bai}"
    echo -e "${gl_zi}【定位】专为 VLESS Reality 定制的深度内核吞吐调优${gl_bai}"
    echo ""
    echo -e "${gl_hong}⚠️  物理熔断警告 ⚠️${gl_bai}"
    echo -e "${gl_huang}此为运行时 (Runtime) 直接内存操作！重启后失去效力。${gl_bai}"
    echo ""
    local confirm
    read -e -p "是否解除安全限制继续注入？(Y/N) [Y]: " confirm
    confirm=${confirm:-Y}
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "注入已撤销"
        return
    fi
    echo ""

    echo -e "${gl_lv}正在破除文件句柄枷锁...${gl_bai}"
    ulimit -n 131072 2>/dev/null || true
    echo "  ✓ 进程句柄极限释放: 131072 (13万)"

    echo -e "${gl_lv}干涉虚拟内存管理算法...${gl_bai}"
    sysctl -w vm.swappiness=5 2>/dev/null || true
    echo "  ✓ swappiness = 5 (极低交互延迟)"
    sysctl -w vm.dirty_ratio=15 2>/dev/null || true
    sysctl -w vm.dirty_background_ratio=5 2>/dev/null || true
    sysctl -w vm.overcommit_memory=1 2>/dev/null || true

    echo -e "${gl_lv}接管 TCP 拥塞控制核...${gl_bai}"
    sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null || true
    local current_qdisc
    current_qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "fq")
    if [ "$current_qdisc" = "cake" ]; then
        echo "  ✓ default_qdisc = cake (保留极客调度)"
    else
        echo "  ℹ default_qdisc = $current_qdisc (维持原貌)"
    fi

    echo -e "${gl_lv}压制 TCP 握手时延 (TLS加速)...${gl_bai}"
    sysctl -w net.ipv4.tcp_fastopen=3 2>/dev/null || true
    sysctl -w net.ipv4.tcp_slow_start_after_idle=0 2>/dev/null || true
    sysctl -w net.ipv4.tcp_tw_reuse=1 2>/dev/null || true
    sysctl -w net.ipv4.tcp_fin_timeout=30 2>/dev/null || true
    sysctl -w net.ipv4.tcp_max_syn_backlog=8192 2>/dev/null || true

    echo -e "${gl_lv}缩减探活周期防劫持...${gl_bai}"
    sysctl -w net.ipv4.tcp_keepalive_time=600 2>/dev/null || true
    sysctl -w net.ipv4.tcp_keepalive_intvl=30 2>/dev/null || true
    sysctl -w net.ipv4.tcp_keepalive_probes=5 2>/dev/null || true

    echo -e "${gl_lv}扩张 TCP 物理缓冲带 (16MB)...${gl_bai}"
    sysctl -w net.core.rmem_max=16777216 2>/dev/null || true
    sysctl -w net.core.wmem_max=16777216 2>/dev/null || true
    sysctl -w net.ipv4.tcp_rmem='4096 87380 16777216' 2>/dev/null || true
    sysctl -w net.ipv4.tcp_wmem='4096 65536 16777216' 2>/dev/null || true

    echo -e "${gl_lv}解禁 UDP 吞吐限制 (QUIC/Hysteria2 狂暴支持)...${gl_bai}"
    sysctl -w net.ipv4.udp_rmem_min=8192 2>/dev/null || true
    sysctl -w net.ipv4.udp_wmem_min=8192 2>/dev/null || true

    echo -e "${gl_lv}放开 Socket 连接列队...${gl_bai}"
    sysctl -w net.core.somaxconn=4096 2>/dev/null || true
    sysctl -w net.core.netdev_max_backlog=5000 2>/dev/null || true
    sysctl -w net.ipv4.ip_local_port_range='1024 65535' 2>/dev/null || true

    echo -e "${gl_lv}启动内核级 TCP 攻击反制...${gl_bai}"
    sysctl -w net.ipv4.tcp_syncookies=1 2>/dev/null || true

    echo ""
    echo -e "${gl_lv}星辰大海ヾ 物理级运行时调优注入完成！${gl_bai}"
    echo -e "${gl_zi}雷达指示: 适配 ≥2GB 内存物理机，实现 TLS + QUIC 的全协议高潮吞吐！${gl_bai}"
}

optimize_reality_ultimate() {
    echo -e "${gl_lv}切换到 Reality 终极狂暴模式...${gl_bai}"
    echo -e "${gl_zi}【定位】性能提升 5-10%，强制降载 25%${gl_bai}"
    echo ""
    echo -e "${gl_hong}⚠️  物理熔断警告 ⚠️${gl_bai}"
    echo -e "${gl_huang}运行时 (Runtime) 的短暂暴力修改，重启后消亡！${gl_bai}"
    echo ""
    local confirm
    read -e -p "是否确信自己拥有 2GB 以上内存并继续？(Y/N) [Y]: " confirm
    confirm=${confirm:-Y}
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "注入撤销"
        return
    fi
    echo ""

    echo -e "${gl_lv}彻底粉碎文件描述符枷锁 (50W+)...${gl_bai}"
    ulimit -n 524288 2>/dev/null || true
    echo "  ✓ 文件描述符: 524288 (50万极限)"

    echo -e "${gl_lv}夺回 TCP 拥塞控制权...${gl_bai}"
    sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null || true
    local current_qdisc
    current_qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "fq")
    if [ "$current_qdisc" = "cake" ]; then
        echo "  ✓ default_qdisc = cake (保留高阶分流算法)"
    else
        echo "  ℹ default_qdisc = $current_qdisc (维持系统自适应)"
    fi

    echo -e "${gl_lv}TCP 协议栈物理层重构...${gl_bai}"
    sysctl -w net.ipv4.tcp_fastopen=3 2>/dev/null || true
    sysctl -w net.ipv4.tcp_slow_start_after_idle=0 2>/dev/null || true
    sysctl -w net.ipv4.tcp_tw_reuse=1 2>/dev/null || true
    sysctl -w net.ipv4.ip_local_port_range='1024 65535' 2>/dev/null || true

    echo -e "${gl_lv}Reality 专属降维打击调优...${gl_bai}"
    sysctl -w net.ipv4.tcp_notsent_lowat=16384 2>/dev/null || true
    echo "  ✓ tcp_notsent_lowat = 16384 (扼杀队首阻塞)"
    sysctl -w net.ipv4.tcp_fin_timeout=15 2>/dev/null || true
    sysctl -w net.ipv4.tcp_max_tw_buckets=5000 2>/dev/null || true

    echo -e "${gl_lv}重新裁定 TCP 内存缓冲带 (12MB)...${gl_bai}"
    sysctl -w net.core.rmem_max=12582912 2>/dev/null || true
    sysctl -w net.core.wmem_max=12582912 2>/dev/null || true
    sysctl -w net.ipv4.tcp_rmem='4096 87380 12582912' 2>/dev/null || true
    sysctl -w net.ipv4.tcp_wmem='4096 64000 12582912' 2>/dev/null || true

    echo -e "${gl_lv}内存交换与 VFS 深度抑制...${gl_bai}"
    sysctl -w vm.swappiness=5 2>/dev/null || true
    sysctl -w vm.dirty_ratio=15 2>/dev/null || true
    sysctl -w vm.dirty_background_ratio=5 2>/dev/null || true
    sysctl -w vm.overcommit_memory=1 2>/dev/null || true
    sysctl -w vm.vfs_cache_pressure=50 2>/dev/null || true

    echo -e "${gl_lv}压缩空闲链接探活周期...${gl_bai}"
    sysctl -w net.ipv4.tcp_keepalive_time=300 2>/dev/null || true
    sysctl -w net.ipv4.tcp_keepalive_intvl=30 2>/dev/null || true
    sysctl -w net.ipv4.tcp_keepalive_probes=5 2>/dev/null || true

    echo -e "${gl_lv}释放 UDP 队列潜能...${gl_bai}"
    sysctl -w net.ipv4.udp_rmem_min=8192 2>/dev/null || true
    sysctl -w net.ipv4.udp_wmem_min=8192 2>/dev/null || true

    echo -e "${gl_lv}扩展硬件接收列队上限...${gl_bai}"
    sysctl -w net.core.somaxconn=4096 2>/dev/null || true
    sysctl -w net.ipv4.tcp_max_syn_backlog=8192 2>/dev/null || true
    sysctl -w net.core.netdev_max_backlog=5000 2>/dev/null || true

    echo -e "${gl_lv}防洪攻击拦截机制起跳...${gl_bai}"
    sysctl -w net.ipv4.tcp_syncookies=1 2>/dev/null || true
    sysctl -w net.ipv4.tcp_mtu_probing=1 2>/dev/null || true

    echo ""
    echo -e "${gl_lv}Reality 终极狂暴模式部署完毕！${gl_bai}"
    echo -e "${gl_huang}雷达指示: 资源调配极度平衡，科学遏制队首阻塞延迟，大幅拔高瞬时带宽。${gl_bai}"
}

optimize_low_spec() {
    echo -e "${gl_lv}切换到微端服务器 (Low-Spec) 乞丐保命模式...${gl_bai}"
    echo -e "${gl_zi}【定位】拯救 512MB-1GB 的弱鸡机器，防 OOM 暴毙${gl_bai}"
    echo ""
    local confirm
    read -e -p "是否对弱机执行抢救？(Y/N) [Y]: " confirm
    confirm=${confirm:-Y}
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        return
    fi
    echo ""

    echo -e "${gl_lv}温和调节文件描述符...${gl_bai}"
    ulimit -n 65535 2>/dev/null || true
    echo "  ✓ 进程句柄: 65535"

    echo -e "${gl_lv}启动标准版 BBR...${gl_bai}"
    sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null || true

    echo -e "${gl_lv}防拥堵起步协议优化...${gl_bai}"
    sysctl -w net.ipv4.tcp_fastopen=3 2>/dev/null || true
    sysctl -w net.ipv4.tcp_slow_start_after_idle=0 2>/dev/null || true
    sysctl -w net.ipv4.tcp_tw_reuse=1 2>/dev/null || true
    sysctl -w net.ipv4.ip_local_port_range='1024 65535' 2>/dev/null || true

    echo -e "${gl_lv}收缩物理缓冲防止内存溢出 (8MB 限高)...${gl_bai}"
    sysctl -w net.core.rmem_max=8388608 2>/dev/null || true
    sysctl -w net.core.wmem_max=8388608 2>/dev/null || true
    sysctl -w net.ipv4.tcp_rmem='4096 87380 8388608' 2>/dev/null || true
    sysctl -w net.ipv4.tcp_wmem='4096 65536 8388608' 2>/dev/null || true

    echo -e "${gl_lv}激进型内存驱逐换页策略...${gl_bai}"
    sysctl -w vm.swappiness=10 2>/dev/null || true
    sysctl -w vm.dirty_ratio=20 2>/dev/null || true
    sysctl -w vm.dirty_background_ratio=10 2>/dev/null || true

    echo -e "${gl_lv}限制突发请求队列...${gl_bai}"
    sysctl -w net.core.somaxconn=2048 2>/dev/null || true
    sysctl -w net.ipv4.tcp_max_syn_backlog=4096 2>/dev/null || true
    sysctl -w net.core.netdev_max_backlog=2500 2>/dev/null || true

    echo -e "${gl_lv}启动防洪安全协议...${gl_bai}"
    sysctl -w net.ipv4.tcp_syncookies=1 2>/dev/null || true

    echo ""
    echo -e "${gl_lv}微机保命环境调优完毕！稳定性大幅度攀升。${gl_bai}"
}

optimize_xinchendahai_original() {
    echo -e "${gl_lv}切换到星辰大海ヾ 原核毁灭测试版...${gl_bai}"
    echo -e "${gl_zi}【定位】这是最为暴力且贪婪的参数，用于测算硬件极限带宽${gl_bai}"
    echo ""
    echo -e "${gl_hong}⚠️  警告: 本配置对 4GB 内存以下的机型有直接干挂的风险！${gl_bai}"
    echo ""
    local confirm
    read -e -p "你的机器够硬吗？(Y/N) [Y]: " confirm
    confirm=${confirm:-Y}
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        return
    fi
    echo ""

    echo -e "${gl_lv}暴利撕裂文件限制...${gl_bai}"
    ulimit -n 1048576 2>/dev/null || true
    echo "  ✓ ulimit 达 100 万"

    echo -e "${gl_lv}封锁内存换页强拉缓存驻留...${gl_bai}"
    sysctl -w vm.swappiness=1 2>/dev/null || true
    sysctl -w vm.dirty_ratio=15 2>/dev/null || true
    sysctl -w vm.dirty_background_ratio=5 2>/dev/null || true
    sysctl -w vm.overcommit_memory=1 2>/dev/null || true
    sysctl -w vm.min_free_kbytes=65536 2>/dev/null || true
    sysctl -w vm.vfs_cache_pressure=50 2>/dev/null || true

    echo -e "${gl_lv}强制 FQ 并启动 BBR...${gl_bai}"
    sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null || true
    local current_qdisc
    current_qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "fq")
    if [ "$current_qdisc" = "cake" ]; then
        echo "  ✓ default_qdisc = cake"
    else
        sysctl -w net.core.default_qdisc=fq 2>/dev/null || true
        echo "  ✓ default_qdisc 被强制降级至 fq"
    fi

    echo -e "${gl_lv}全面压制连接收发时序...${gl_bai}"
    sysctl -w net.ipv4.tcp_fastopen=3 2>/dev/null || true
    sysctl -w net.ipv4.tcp_fin_timeout=30 2>/dev/null || true
    sysctl -w net.ipv4.tcp_max_syn_backlog=8192 2>/dev/null || true
    sysctl -w net.ipv4.tcp_tw_reuse=1 2>/dev/null || true
    sysctl -w net.ipv4.tcp_slow_start_after_idle=0 2>/dev/null || true
    sysctl -w net.ipv4.tcp_mtu_probing=2 2>/dev/null || true
    sysctl -w net.ipv4.tcp_window_scaling=1 2>/dev/null || true
    sysctl -w net.ipv4.tcp_timestamps=1 2>/dev/null || true

    echo -e "${gl_lv}强拉安全时钟防断...${gl_bai}"
    sysctl -w net.ipv4.tcp_syncookies=1 2>/dev/null || true
    sysctl -w net.ipv4.tcp_keepalive_time=600 2>/dev/null || true
    sysctl -w net.ipv4.tcp_keepalive_intvl=30 2>/dev/null || true
    sysctl -w net.ipv4.tcp_keepalive_probes=5 2>/dev/null || true

    echo -e "${gl_lv}暴力拓宽 TCP 内存吞吐总池...${gl_bai}"
    sysctl -w net.core.rmem_max=16777216 2>/dev/null || true
    sysctl -w net.core.wmem_max=16777216 2>/dev/null || true
    sysctl -w net.core.rmem_default=262144 2>/dev/null || true
    sysctl -w net.core.wmem_default=262144 2>/dev/null || true
    sysctl -w net.ipv4.tcp_rmem='4096 87380 16777216' 2>/dev/null || true
    sysctl -w net.ipv4.tcp_wmem='4096 65536 16777216' 2>/dev/null || true

    echo -e "${gl_lv}扩张 UDP 上下界限...${gl_bai}"
    sysctl -w net.ipv4.udp_rmem_min=8192 2>/dev/null || true
    sysctl -w net.ipv4.udp_wmem_min=8192 2>/dev/null || true

    echo -e "${gl_lv}暴利扩充列队列深至 25 万...${gl_bai}"
    sysctl -w net.core.somaxconn=4096 2>/dev/null || true
    sysctl -w net.core.netdev_max_backlog=250000 2>/dev/null || true
    sysctl -w net.ipv4.ip_local_port_range='1024 65535' 2>/dev/null || true

    echo -e "${gl_lv}剥夺内核任务干预权...${gl_bai}"
    sysctl -w kernel.sched_autogroup_enabled=0 2>/dev/null || true
    sysctl -w kernel.numa_balancing=0 2>/dev/null || true

    echo -e "${gl_lv}处决透明大页内存机制...${gl_bai}"
    echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
    echo "  ✓ transparent_hugepage 被处决"

    echo ""
    echo -e "${gl_lv}极限压榨版已全部生效，吞吐测试开始！${gl_bai}"
}

Kernel_optimize() {
    while true; do
        clear
        echo "Linux 系统内核参数优化 - 专项独立突击调优面板"
        echo "------------------------------------------------"
        echo "此面板参数针对代理软件的物理层特性深度优化"
        echo -e "${gl_huang}警告: 此处均为【即时运行注入】，重启即重置失忆！${gl_bai}"
        echo "--------------------"
        echo "1. 星辰大海ヾ均衡优化：  13万文件句柄，16MB物理缓冲"
        echo "                      适用：≥2GB内存，主力均衡王"
        echo "                      评级：⭐⭐⭐⭐⭐ 🏆"
        echo ""
        echo "2. Reality 终极优化：  50万文件句柄，12MB极限压迫缓冲"
        echo "                      适用：针对 Reality 机制，降低队首延迟"
        echo "                      评级：⭐⭐⭐⭐⭐ 🏆"
        echo ""
        echo "3. Low-Spec 乞丐优化： 6.5万句柄，8MB迷你缓冲池"
        echo "                      适用：1GB 以下老爷车机器"
        echo "                      评级：⭐⭐⭐⭐ 💡"
        echo ""
        echo "4. 星辰大海毁灭初版：  100万句柄，16MB缓冲，25万极深列队"
        echo "                      适用：用于压榨 CPU 内存测试极限"
        echo "                      评级：⭐⭐⭐⭐⭐ 🧪"
        echo "--------------------"
        echo "0. 撤退返回"
        echo "--------------------"
        local sub_choice
        read -e -p "发落指令: " sub_choice
        case $sub_choice in
            1) optimize_xinchendahai; break_end ;;
            2) optimize_reality_ultimate; break_end ;;
            3) optimize_low_spec; break_end ;;
            4) optimize_xinchendahai_original; break_end ;;
            0) break ;;
            *) echo "指令识别失败!"; sleep 1 ;;
        esac
    done
}
# ==============================================================================
# [ 区块 VIII: 系统状态探针与自启保护引擎 (严格防崩) ]
# ==============================================================================

check_mph_state() {
    local state
    state=$(jq -r '.routing.domainMatcher // "false"' "$CONFIG" 2>/dev/null || echo "false")
    if [[ "$state" == "mph" ]]; then echo "true"; else echo "false"; fi
}

check_maxtime_state() {
    local state
    state=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
    if [[ "$state" == "60000" ]]; then echo "true"; else echo "false"; fi
}

check_routeonly_state() {
    local state
    state=$(jq -r '.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
    if [[ "$state" == "true" ]]; then echo "true"; else echo "false"; fi
}

check_sniff_state() {
    local state
    state=$(jq -r '.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.metadataOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
    if [[ "$state" == "true" ]]; then echo "true"; else echo "false"; fi
}

check_affinity_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if grep -q "^CPUAffinity=" "$limit_file" 2>/dev/null; then echo "true"; else echo "false"; fi
}

check_buffer_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if grep -q "^Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" "$limit_file" 2>/dev/null; then echo "true"; else echo "false"; fi
}

check_dnsmasq_state() {
    if systemctl is-active --quiet dnsmasq 2>/dev/null; then
        if grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null; then echo "true"; return 0; fi
    fi
    echo "false"
}

check_thp_state() {
    if [[ ! -f "/sys/kernel/mm/transparent_hugepage/enabled" ]]; then echo "unsupported"; return 0; fi
    if [[ ! -w "/sys/kernel/mm/transparent_hugepage/enabled" ]]; then echo "unsupported"; return 0; fi
    if grep -q '\[never\]' /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null; then echo "true"; else echo "false"; fi
}

check_mtu_state() {
    if [[ ! -f "/proc/sys/net/ipv4/tcp_mtu_probing" ]]; then echo "unsupported"; return 0; fi
    local val
    val=$(sysctl -n net.ipv4.tcp_mtu_probing 2>/dev/null || echo "0")
    if [[ "$val" == "1" ]]; then echo "true"; else echo "false"; fi
}

check_cpu_state() {
    if [[ ! -d "/sys/devices/system/cpu/cpu0/cpufreq" ]]; then echo "unsupported"; return 0; fi
    if grep -q 'performance' /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null; then echo "true"; else echo "false"; fi
}

check_ring_state() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if [[ -z "$IFACE" ]]; then echo "unsupported"; return 0; fi
    if ! command -v ethtool >/dev/null 2>&1; then echo "unsupported"; return 0; fi
    if ! ethtool -g "$IFACE" >/dev/null 2>&1; then echo "unsupported"; return 0; fi
    
    local curr_rx
    curr_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Current hardware settings" | grep "RX:" | head -n 1 | awk '{print $2}' || echo "")
    if [[ -z "$curr_rx" ]]; then echo "unsupported"; return 0; fi
    if [[ "$curr_rx" == "512" ]]; then echo "true"; else echo "false"; fi
}

check_zram_state() {
    if ! modprobe -n zram >/dev/null 2>&1; then
        if ! lsmod 2>/dev/null | grep -q zram; then echo "unsupported"; return 0; fi
    fi
    if swapon --show 2>/dev/null | grep -q 'zram'; then echo "true"; else echo "false"; fi
}

check_journal_state() {
    if [[ ! -f "/etc/systemd/journald.conf" ]]; then echo "unsupported"; return 0; fi
    if grep -q '^Storage=volatile' /etc/systemd/journald.conf 2>/dev/null; then echo "true"; else echo "false"; fi
}

check_process_priority_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if [[ ! -f "$limit_file" ]]; then echo "false"; return 0; fi
    if grep -q "^OOMScoreAdjust=-500" "$limit_file" 2>/dev/null; then echo "true"; else echo "false"; fi
}

check_cake_state() {
    if sysctl net.core.default_qdisc 2>/dev/null | grep -q 'cake'; then echo "true"; else echo "false"; fi
}

check_ackfilter_state() {
    if [[ -f "$FLAGS_DIR/ack_filter" ]]; then echo "true"; else echo "false"; fi
}

check_ecn_state() {
    if [[ -f "$FLAGS_DIR/ecn" ]]; then echo "true"; else echo "false"; fi
}

check_wash_state() {
    if [[ -f "$FLAGS_DIR/wash" ]]; then echo "true"; else echo "false"; fi
}

check_gso_off_state() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if ! command -v ethtool >/dev/null 2>&1; then echo "unsupported"; return 0; fi
    
    local eth_info
    eth_info=$(ethtool -k "$IFACE" 2>/dev/null || echo "")
    if [[ -z "$eth_info" ]]; then echo "unsupported"; return 0; fi
    if echo "$eth_info" | grep -E "^generic-receive-offload:|^rx-gro:" | grep -q "fixed" 2>/dev/null; then echo "unsupported"; return 0; fi
    if echo "$eth_info" | grep -E "^generic-receive-offload:|^rx-gro:" | grep -q " off" 2>/dev/null; then echo "true"; else echo "false"; fi
}

check_irq_state() {
    local CORES
    CORES=$(nproc 2>/dev/null || echo 1)
    if (( CORES < 2 )); then echo "unsupported"; return 0; fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    local irq
    irq=$(grep "$IFACE" /proc/interrupts 2>/dev/null | head -n 1 | awk '{print $1}' | tr -d ':' || echo "")
    
    if [[ -n "$irq" ]]; then
        local mask
        mask=$(cat "/proc/irq/$irq/smp_affinity" 2>/dev/null | tr -d '0' || echo "")
        if [[ "$mask" == "1" ]]; then echo "true"; else echo "false"; fi
    else
        echo "false"
    fi
}

update_hw_boot_script() {
    cat > /usr/local/bin/xray-hw-tweaks.sh << 'SHEOF'
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
if [[ -z "$IFACE" ]]; then
    sleep 3
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
fi
SHEOF

    if [[ "$(check_thp_state)" == "true" ]]; then
        cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
echo never > /sys/kernel/mm/transparent_hugepage/defrag  2>/dev/null || true
EOF
    fi

    if [[ "$(check_cpu_state)" == "true" ]]; then
        cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    if [[ -f "$cpu" ]]; then
        echo performance > "$cpu" 2>/dev/null || true
    fi
done
EOF
    fi

    if [[ "$(check_ring_state)" == "true" ]]; then
        echo "ethtool -G \$IFACE rx 512 tx 512 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
    fi
    
    local gso_state
    gso_state=$(check_gso_off_state)
    if [[ "$gso_state" == "true" ]]; then
        echo "ethtool -K \$IFACE gro off gso off tso off 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
    elif [[ "$gso_state" == "false" ]]; then
        echo "ethtool -K \$IFACE gro on gso on tso on 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
    fi
    
    cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
CAKE_OPTS=""
if [[ -f "/usr/local/etc/xray/cake_opts.txt" ]]; then
    CAKE_OPTS=$(cat "/usr/local/etc/xray/cake_opts.txt" 2>/dev/null || true)
fi

ACK_FLAG=""
if [[ -f "/usr/local/etc/xray/flags/ack_filter" ]]; then
    ACK_FLAG="ack-filter"
fi

ECN_FLAG=""
if [[ -f "/usr/local/etc/xray/flags/ecn" ]]; then
    ECN_FLAG="ecn"
fi

WASH_FLAG=""
if [[ -f "/usr/local/etc/xray/flags/wash" ]]; then
    WASH_FLAG="wash"
fi
EOF

    if [[ "$(check_cake_state)" == "true" ]]; then
        echo 'tc qdisc replace dev $IFACE root cake $CAKE_OPTS $ACK_FLAG $ECN_FLAG $WASH_FLAG 2>/dev/null || true' >> /usr/local/bin/xray-hw-tweaks.sh
    fi

    if [[ "$(check_irq_state)" == "true" ]]; then
        cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
systemctl stop irqbalance 2>/dev/null || true
for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || true); do
    echo 1 > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true
done
EOF
    fi

    chmod +x /usr/local/bin/xray-hw-tweaks.sh 2>/dev/null || true

    cat > /etc/systemd/system/xray-hw-tweaks.service << 'EOF'
[Unit]
Description=Xray Hardware Parameters Loader
After=network-online.target
Wants=network-online.target

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
    
    if [[ "$(check_cake_state)" == "true" ]]; then
        local base_opts
        base_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
        local f_ack=""
        if [[ "$(check_ackfilter_state)" == "true" ]]; then f_ack="ack-filter"; fi
        local f_ecn=""
        if [[ "$(check_ecn_state)" == "true" ]]; then f_ecn="ecn"; fi
        local f_wash=""
        if [[ "$(check_wash_state)" == "true" ]]; then f_wash="wash"; fi
        
        tc qdisc replace dev "$IFACE" root cake $base_opts $f_ack $f_ecn $f_wash 2>/dev/null || true
    fi
    update_hw_boot_script
}

# ==============================================================================
# [ 区块 IX: 全局底层调度模块 (Hoisting 修复区) ]
# ==============================================================================
# 核心修复：所有 toggle 开关全部提前声明，免疫 Bash "command not found" 崩溃。

_toggle_affinity_on() {
    local lf="/etc/systemd/system/xray.service.d/limits.conf"
    if [[ -f "$lf" ]]; then
        sed -i '/^CPUAffinity=/d;/^Environment="GOMAXPROCS=/d' "$lf" 2>/dev/null || true
        local TARGET_CPU
        if (( $(nproc 2>/dev/null || echo 1) >= 2 )); then TARGET_CPU=1; else TARGET_CPU=0; fi
        echo "CPUAffinity=$TARGET_CPU" >> "$lf"
        echo "Environment=\"GOMAXPROCS=1\"" >> "$lf"
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

_toggle_affinity_off() {
    local lf="/etc/systemd/system/xray.service.d/limits.conf"
    if [[ -f "$lf" ]]; then
        sed -i '/^CPUAffinity=/d;/^Environment="GOMAXPROCS=/d' "$lf" 2>/dev/null || true
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

toggle_buffer() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if [[ -f "$limit_file" ]]; then
        if [[ "$(check_buffer_state)" == "true" ]]; then
            sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
        else
            sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
            echo "Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" >> "$limit_file"
        fi
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

toggle_dnsmasq() {
    if [[ "$(check_dnsmasq_state)" == "true" ]]; then
        systemctl stop dnsmasq >/dev/null 2>&1 || true
        systemctl disable dnsmasq >/dev/null 2>&1 || true
        chattr -i /etc/resolv.conf 2>/dev/null || true
        rm -f /etc/resolv.conf 2>/dev/null || true
        if [[ -f /etc/resolv.conf.bak ]]; then 
            mv /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true
        else 
            echo "nameserver 8.8.8.8" > /etc/resolv.conf
        fi
        systemctl enable systemd-resolved >/dev/null 2>&1 || true
        systemctl start systemd-resolved >/dev/null 2>&1 || true
        _safe_jq_write '.dns = {"servers":["https://8.8.8.8/dns-query","https://1.1.1.1/dns-query","https://doh.opendns.com/dns-query"],"queryStrategy":"UseIP"}'
    else
        export DEBIAN_FRONTEND=noninteractive
        if command -v apt-get &>/dev/null; then
            apt-get update -y >/dev/null 2>&1 || true
            apt-get install -y dnsmasq >/dev/null 2>&1 || true
        elif command -v yum &>/dev/null; then
            yum makecache -y >/dev/null 2>&1 || true
            yum install -y dnsmasq >/dev/null 2>&1 || true
        fi
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
        if [[ ! -f /etc/resolv.conf.bak ]]; then 
            cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true
        fi
        rm -f /etc/resolv.conf 2>/dev/null || true
        echo "nameserver 127.0.0.1" > /etc/resolv.conf
        chattr +i /etc/resolv.conf 2>/dev/null || true
        _safe_jq_write '.dns = {"servers":["127.0.0.1"],"queryStrategy":"UseIP"}'
    fi
}

toggle_thp() {
    if [[ "$(check_thp_state)" == "true" ]]; then
        echo always > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
        echo always > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true
    else
        echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
        echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true
    fi
    update_hw_boot_script
}

toggle_mtu() {
    local conf="/etc/sysctl.d/99-network-optimized.conf"
    if [[ "$(check_mtu_state)" == "true" ]]; then 
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
    if [[ "$(check_cpu_state)" == "unsupported" ]]; then return 0; fi
    if [[ "$(check_cpu_state)" == "true" ]]; then 
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do 
            if [[ -f "$cpu" ]]; then echo schedutil > "$cpu" 2>/dev/null || true; fi
        done
    else 
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do 
            if [[ -f "$cpu" ]]; then echo performance > "$cpu" 2>/dev/null || true; fi
        done
    fi
    update_hw_boot_script
}

toggle_ring() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if [[ "$(check_ring_state)" == "unsupported" ]]; then return 0; fi
    if [[ "$(check_ring_state)" == "true" ]]; then
        local max_rx
        max_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Pre-set maximums" | grep "RX:" | head -n 1 | awk '{print $2}' || echo "512")
        if [[ -n "$max_rx" ]]; then ethtool -G "$IFACE" rx "$max_rx" tx "$max_rx" 2>/dev/null || true; fi
    else 
        ethtool -G "$IFACE" rx 512 tx 512 2>/dev/null || true
    fi
    update_hw_boot_script
}

toggle_gso_off() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if [[ "$(check_gso_off_state)" == "unsupported" ]]; then return 0; fi
    if [[ "$(check_gso_off_state)" == "true" ]]; then 
        ethtool -K "$IFACE" gro on gso on tso on 2>/dev/null || true
    else 
        ethtool -K "$IFACE" gro off gso off tso off 2>/dev/null || true
    fi
    update_hw_boot_script
}

toggle_zram() {
    if [[ "$(check_zram_state)" == "unsupported" ]]; then return 0; fi
    if [[ "$(check_zram_state)" == "true" ]]; then
        swapoff /dev/zram0 2>/dev/null || true
        rmmod zram 2>/dev/null || true
        systemctl disable --now xray-zram.service 2>/dev/null || true
        rm -f /etc/systemd/system/xray-zram.service /usr/local/bin/xray-zram.sh 2>/dev/null || true
    else
        local TOTAL_MEM
        TOTAL_MEM=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo "1024")
        local ZRAM_SIZE
        if (( TOTAL_MEM < 500 )); then 
            ZRAM_SIZE=$((TOTAL_MEM * 2))
        elif (( TOTAL_MEM < 1024 )); then 
            ZRAM_SIZE=$((TOTAL_MEM * 3 / 2))
        else 
            ZRAM_SIZE=$TOTAL_MEM
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
Description=Xray ZRAM
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/xray-zram.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOFZ
        systemctl daemon-reload >/dev/null 2>&1 || true
        systemctl enable --now xray-zram.service >/dev/null 2>&1 || true
    fi
}

toggle_journal() {
    local conf="/etc/systemd/journald.conf"
    if [[ "$(check_journal_state)" == "unsupported" ]]; then return 0; fi
    if [[ "$(check_journal_state)" == "true" ]]; then 
        sed -i 's/^Storage=volatile/#Storage=auto/' "$conf" 2>/dev/null || true
    else
        if grep -q "^#Storage=" "$conf" 2>/dev/null; then 
            sed -i 's/^#Storage=.*/Storage=volatile/' "$conf" 2>/dev/null || true
        elif grep -q "^Storage=" "$conf" 2>/dev/null; then 
            sed -i 's/^Storage=.*/Storage=volatile/' "$conf" 2>/dev/null || true
        else 
            echo "Storage=volatile" >> "$conf"
        fi
    fi
    systemctl restart systemd-journald >/dev/null 2>&1 || true
}

toggle_process_priority() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if [[ ! -f "$limit_file" ]]; then return 0; fi
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
    if [[ "$(check_cake_state)" == "true" ]]; then
        sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = fq/' "$conf" 2>/dev/null || true
        sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1 || true
        local IFACE
        IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
        if [[ -n "$IFACE" ]]; then
            tc qdisc replace dev "$IFACE" root fq 2>/dev/null || true
        fi
        update_hw_boot_script
    else
        sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = cake/' "$conf" 2>/dev/null || true
        if ! grep -q "net.core.default_qdisc" "$conf" 2>/dev/null; then 
            echo "net.core.default_qdisc = cake" >> "$conf"
        fi
        modprobe sch_cake 2>/dev/null || true
        sysctl -w net.core.default_qdisc=cake >/dev/null 2>&1 || true
        _apply_cake_live
    fi
}

toggle_ackfilter() {
    if [[ "$(check_ackfilter_state)" == "true" ]]; then rm -f "$FLAGS_DIR/ack_filter" 2>/dev/null || true; else touch "$FLAGS_DIR/ack_filter" 2>/dev/null || true; fi
    if [[ "$(check_cake_state)" == "false" ]]; then warn "已保存设置，但必须先开启 CAKE 才能生效!"; sleep 2; return 0; fi
    _apply_cake_live
}

toggle_ecn() {
    if [[ "$(check_ecn_state)" == "true" ]]; then rm -f "$FLAGS_DIR/ecn" 2>/dev/null || true; else touch "$FLAGS_DIR/ecn" 2>/dev/null || true; fi
    if [[ "$(check_cake_state)" == "false" ]]; then warn "已保存设置，但必须先开启 CAKE 才能生效!"; sleep 2; return 0; fi
    _apply_cake_live
}

toggle_wash() {
    if [[ "$(check_wash_state)" == "true" ]]; then rm -f "$FLAGS_DIR/wash" 2>/dev/null || true; else touch "$FLAGS_DIR/wash" 2>/dev/null || true; fi
    if [[ "$(check_cake_state)" == "false" ]]; then warn "已保存设置，但必须先开启 CAKE 才能生效!"; sleep 2; return 0; fi
    _apply_cake_live
}

toggle_irq() {
    if [[ "$(check_irq_state)" == "unsupported" ]]; then return 0; fi
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    local CORES
    CORES=$(nproc 2>/dev/null || echo 1)
    local DEFAULT_MASK
    DEFAULT_MASK=$(printf "%x" $(( (1<<CORES)-1 )))
    if [[ "$(check_irq_state)" == "true" ]]; then
        for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || echo ""); do 
            if [[ -n "$irq" ]]; then echo "$DEFAULT_MASK" > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true; fi
        done
        systemctl start irqbalance >/dev/null 2>&1 || true
        systemctl enable irqbalance >/dev/null 2>&1 || true
    else
        systemctl stop irqbalance >/dev/null 2>&1 || true
        systemctl disable irqbalance >/dev/null 2>&1 || true
        for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || echo ""); do 
            if [[ -n "$irq" ]]; then echo 1 > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true; fi
        done
    fi
    update_hw_boot_script
}

# ==============================================================================
# [ 区块 X: 应用层高级调优引擎 (JSON 隔离操作) ]
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
# [ 区块 XI: Geo 规则更新、DNS接管与 Linux 内核/网络栈编译调优 ]
# ==============================================================================

install_update_dat() {
    cat > "$UPDATE_DAT_SCRIPT" << 'UPDSH'
#!/usr/bin/env bash
XRAY_DAT_DIR="/usr/local/share/xray"
LOG_FILE="/var/log/xray/update-dat.log"

log() { 
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

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

log "[INFO] Geo 规则库更新脚本执行完毕"
UPDSH

    chmod +x "$UPDATE_DAT_SCRIPT" 2>/dev/null || true

    if ! crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT" | grep -v "systemctl restart xray" > /tmp/current_cron; then
        true
    fi
    echo "0 3 * * * $UPDATE_DAT_SCRIPT >/dev/null 2>&1" >> /tmp/current_cron
    echo "10 3 * * * /bin/systemctl restart xray >/dev/null 2>&1" >> /tmp/current_cron
    crontab /tmp/current_cron 2>/dev/null || true
    rm -f /tmp/current_cron 2>/dev/null || true

    info "自动更新配置完成: 每日 03:00 下载 Geo 库，03:10 重载 Xray 进程。"
}

do_change_dns() {
    title "配置系统 DNS 解析 (resolvconf)"
    
    local release=""
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue 2>/dev/null | grep -Eqi "debian|ubuntu"; then
        release="debian"
    elif cat /proc/version 2>/dev/null | grep -Eqi "debian|ubuntu"; then
        release="debian"
    fi

    if [[ ! -e '/usr/sbin/resolvconf' && ! -e '/sbin/resolvconf' ]]; then
        info "未检测到 resolvconf，准备安装..."
        if [[ "${release}" == "centos" ]]; then
            yum -y install resolvconf > /dev/null 2>&1 || true
        else
            export DEBIAN_FRONTEND=noninteractive
            apt-get update > /dev/null 2>&1 || true
            apt-get -y install resolvconf > /dev/null 2>&1 || true
        fi
    fi
    
    systemctl stop systemd-resolved 2>/dev/null || true
    systemctl disable systemd-resolved 2>/dev/null || true
    
    systemctl stop resolvconf.service > /dev/null 2>&1 || true
    systemctl start resolvconf.service > /dev/null 2>&1 || true
    systemctl enable resolvconf.service > /dev/null 2>&1 || true

    local nameserver=""
    local IPcheck="0"
    
    while [[ "$IPcheck" == "0" ]]; do
        read -e -p "$(echo -e "${gl_huang}请输入自定义 Nameserver IP (例如 8.8.8.8 或 1.1.1.1): ${gl_bai}")" nameserver
        if [[ $nameserver =~ ^([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]]; then
            IPcheck="1"
        else
            print_red "输入格式错误，请输入合法的 IPv4 地址。"
        fi
    done

    chattr -i /etc/resolv.conf 2>/dev/null || true
    rm -f /etc/resolv.conf 2>/dev/null || true
    
    if [[ -f /etc/resolv.conf.bak ]]; then
        mv /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true
    fi
    
    echo "nameserver $nameserver" > /etc/resolv.conf
    chattr +i /etc/resolv.conf 2>/dev/null || true
    
    if ! mkdir -p /etc/resolvconf/resolv.conf.d 2>/dev/null; then
        true
    fi
    
    echo "nameserver $nameserver" > /etc/resolvconf/resolv.conf.d/head 2>/dev/null || true
    systemctl restart resolvconf.service >/dev/null 2>&1 || true
    
    info "DNS 已被物理锁定为：$nameserver"
}

do_install_xanmod_main_official() {
    title "安装预编译 XANMOD (main) 内核"
    if [[ "$(uname -m)" != "x86_64" ]]; then 
        error "官方预编译 Xanmod 仅支持 x86_64 架构！"
        break_end; return 1
    fi
    if [[ ! -f /etc/debian_version ]]; then 
        error "官方预编译 Xanmod APT 源仅支持 Debian / Ubuntu 系！"
        break_end; return 1
    fi
    
    info "正在检查 CPU 架构级别支持..."
    local cpu_level_script="/tmp/check_x86-64_psabi.sh"
    if ! wget -qO "$cpu_level_script" https://dl.xanmod.org/check_x86-64_psabi.sh; then
        warn "无法下载检测脚本，将默认使用 v1 级别。"
    fi
    local cpu_level=""
    if [[ -f "$cpu_level_script" ]]; then
        cpu_level=$(awk -f "$cpu_level_script" | grep -oE 'x86-64-v[1-4]' | grep -oE '[1-4]' | tail -n 1 || echo "")
        rm -f "$cpu_level_script" 2>/dev/null || true
    fi
    
    if [[ -z "$cpu_level" ]]; then 
        cpu_level=1
        warn "未能识别级别，降级使用 v1 版本。"
    else 
        info "检测到 CPU 支持级别: v${cpu_level}"
    fi
    
    local pkg_name="linux-xanmod-x64v${cpu_level}"
    
    info "配置 Xanmod 软件源..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y gnupg gnupg2 curl sudo wget e2fsprogs >/dev/null 2>&1 || true
    
    echo 'deb http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-kernel.list
    if ! wget -qO - https://dl.xanmod.org/gpg.key | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/xanmod-kernel.gpg; then
        error "导入 GPG 密钥失败！"
        return 1
    fi
    
    info "开始安装: $pkg_name ..."
    apt-get update -y >/dev/null 2>&1 || true
    if ! apt-get install -y "$pkg_name"; then
        if [[ "$cpu_level" == "4" ]]; then 
            warn "v4 版本安装失败，尝试降级安装 v3 版本..."
            pkg_name="linux-xanmod-x64v3"
            if ! apt-get install -y "$pkg_name"; then
                error "内核安装失败。"
                return 1
            fi
        else
            error "内核安装失败。"
            return 1
        fi
    fi
    
    info "重载 GRUB 引导配置..."
    if command -v update-grub >/dev/null 2>&1; then 
        update-grub || true
    else 
        apt-get install -y grub2-common >/dev/null 2>&1 || true
        update-grub || true
    fi
    
    info "官方预编译 XANMOD (main) 部署完毕。"
    info "系统将在 10 秒后自动重启以应用新内核..."
    sleep 10
    reboot
}

do_xanmod_compile() {
    title "系统内核源码提取与 BBR3 编译"
    warn "源码编译耗时较长 (30-60 分钟)，期间请勿中断 SSH 连接。"
    read -e -p "$(echo -e "${gl_huang}确定要开始编译内核吗？(Y/N): ${gl_bai}")" confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        return
    fi
    
    info "安装编译依赖工具包..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y build-essential bc bison flex libssl-dev libelf-dev libncurses-dev zstd git wget curl xz-utils ethtool numactl make pkg-config dwarves rsync python3 libdw-dev cpio >/dev/null 2>&1 || true
    
    check_and_create_1gb_swap

    info "获取 Kernel.org 主线内核源码..."
    local BUILD_DIR="/usr/src"
    if ! cd $BUILD_DIR; then
        die "进入 /usr/src 失败"
    fi
    
    local KERNEL_URL
    KERNEL_URL=$(curl -s https://www.kernel.org/releases.json | jq -r '.releases[] | select(.type=="stable") | .tarball' | head -n 1 || echo "")
    
    if [[ -z "$KERNEL_URL" || "$KERNEL_URL" == "null" ]]; then
        KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.10.tar.xz"
    fi
    
    local KERNEL_FILE
    KERNEL_FILE=$(basename "$KERNEL_URL")
    wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"

    if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
        rm -f "$KERNEL_FILE" 2>/dev/null || true
        wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"
        if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
            error "源码包损坏，终止安装。"
            return 1
        fi
    fi

    tar -xJf "$KERNEL_FILE"
    local KERNEL_DIR
    KERNEL_DIR=$(tar -tf "$KERNEL_FILE" | head -n 1 | cut -d/ -f1)
    if ! cd "$KERNEL_DIR"; then
        die "无法进入解压后的内核目录"
    fi

    info "同步宿主机驱动配置并启用 BBR3..."
    
    if [[ -f "/boot/config-$(uname -r)" ]]; then
        cp "/boot/config-$(uname -r)" .config
        info "已成功提取当前内核配置 (/boot/config-$(uname -r))。"
    else
        if modprobe configs 2>/dev/null && [[ -f /proc/config.gz ]]; then
            zcat /proc/config.gz > .config
            info "已成功提取内存运行时配置 (/proc/config.gz)。"
        else
            error "未找到内核配置文件。强行编译可能导致系统无法引导！"
            read -e -p "$(echo -e "${gl_huang}确定强制继续吗？(Y/N): ${gl_bai}")" force_k
            if [[ ! "$force_k" =~ ^[Yy]$ ]]; then 
                return 1
            fi
            make defconfig
        fi
    fi
    
    make scripts || true
    
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
    
    yes "" | make olddefconfig || true

    info "开始内核编译，将充分利用 CPU 资源..."
    local CPU
    CPU=$(nproc 2>/dev/null || echo 1)
    local RAM
    RAM=$(free -m | awk '/Mem/{print $2}' || echo 1024)
    local THREADS=1
    
    if ((RAM >= 2000)); then
        THREADS=$CPU
    elif ((RAM >= 1000)); then
        THREADS=2
    fi
    
    if ! make -j$THREADS; then
        error "编译过程中断，请检查内存或硬盘空间是否充足。"
        break_end
        return 1
    fi

    info "开始安装内核模块与引导文件..."
    make modules_install || true
    make install || true

    local NEW_KERNEL_VER
    NEW_KERNEL_VER=$(make -s kernelrelease 2>/dev/null || echo "")
    
    if [[ -n "$NEW_KERNEL_VER" ]]; then
        info "为新内核生成 initramfs: $NEW_KERNEL_VER"
        if command -v update-initramfs >/dev/null 2>&1; then
            update-initramfs -c -k "$NEW_KERNEL_VER" || true
        elif command -v dracut >/dev/null 2>&1; then
            dracut --force "/boot/initramfs-${NEW_KERNEL_VER}.img" "$NEW_KERNEL_VER" || true
        else
            warn "未找到 update-initramfs 或 dracut，可能无法生成引导文件。"
        fi
    fi

    info "刷新 GRUB 引导配置..."
    if command -v update-grub >/dev/null 2>&1; then
        update-grub || true
    elif command -v update-grub2 >/dev/null 2>&1; then
        update-grub2 || true
    elif command -v grub-mkconfig >/dev/null 2>&1; then
        grub-mkconfig -o /boot/grub/grub.cfg || true
    fi

    cd /
    rm -rf "$BUILD_DIR/linux-"* 2>/dev/null || true
    rm -rf "$BUILD_DIR/$KERNEL_FILE" 2>/dev/null || true

    info "内核编译并安装成功。"
    info "系统将在 10 秒后自动重启，请稍后重新连接。"
    sleep 10
    reboot
}

do_perf_tuning() {
    title "系统底层网络栈深度调优"
    warn "应用网络调优参数后，系统将自动重启以生效更改，请确认！"
    
    local confirm
    read -e -p "$(echo -e "${gl_huang}是否继续执行调优？(Y/N): ${gl_bai}")" confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        return
    fi
    
    local current_scale
    current_scale=$(sysctl -n net.ipv4.tcp_adv_win_scale 2>/dev/null || echo "1")
    local current_app
    current_app=$(sysctl -n net.ipv4.tcp_app_win 2>/dev/null || echo "31")
    
    echo -e "  当前 tcp_adv_win_scale: ${cyan}${current_scale}${none} (建议 1 或 2)"
    echo -e "  当前 tcp_app_win: ${cyan}${current_app}${none} (建议 31)"
    
    local new_scale new_app
    read -e -p "设置 tcp_adv_win_scale (-2 到 2，直接回车保留当前): " new_scale
    new_scale=${new_scale:-$current_scale}
    
    read -e -p "设置 tcp_app_win (1 到 31，直接回车保留当前): " new_app
    new_app=${new_app:-$current_app}

    info "清理历史及冗余的网络优化配置..."
    systemctl stop net-speeder >/dev/null 2>&1 || true
    killall net-speeder >/dev/null 2>&1 || true
    systemctl disable net-speeder >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/net-speeder.service 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    rm -rf /root/net-speeder 2>/dev/null || true

    truncate -s 0 /etc/sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-network-optimized.conf 2>/dev/null || true
    
    rm -f /etc/sysctl.d/99-bbr*.conf 2>/dev/null || true
    rm -f /etc/sysctl.d/99-ipv6-disable.conf 2>/dev/null || true
    rm -f /etc/sysctl.d/99-pro*.conf 2>/dev/null || true
    rm -f /etc/sysctl.d/99-xanmod-bbr3.conf 2>/dev/null || true
    rm -f /usr/lib/sysctl.d/50-pid-max.conf 2>/dev/null || true
    rm -f /usr/lib/sysctl.d/99-protect-links.conf 2>/dev/null || true
    
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
        echo "session required pam_limits.so" >> /etc/pam.d/common-session 2>/dev/null || true
    fi
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session-noninteractive 2>/dev/null; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive 2>/dev/null || true
    fi
    
    echo "DefaultLimitNOFILE=1000000" >> /etc/systemd/system.conf 2>/dev/null || true
    echo "DefaultLimitNPROC=1000000" >> /etc/systemd/system.conf 2>/dev/null || true

    local target_qdisc="fq"
    if [[ "$(check_cake_state)" == "true" ]]; then
        target_qdisc="cake"
    fi

    info "写入全量内核 Sysctl 参数..."
    cat > /etc/sysctl.d/99-network-optimized.conf << EOF
# 基础队列与拥塞控制
net.core.default_qdisc = ${target_qdisc}
net.ipv4.tcp_congestion_control = bbr
net.ipv4.neigh.default.base_reachable_time_ms = 60000
net.ipv4.neigh.default.mcast_solicit = 2
net.ipv4.neigh.default.retrans_time_ms = 500

# 路由与过滤
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.tcp_no_metrics_save = 1

# ECN 与 MTU 探测
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_sack = 1

# 窗口与内存分配
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

# NAPI 权重机制
net.core.dev_weight = 64
net.core.dev_weight_tx_bias = 1
net.core.dev_weight_rx_bias = 1
net.core.netdev_budget = 300

# 文件系统控制
vm.swappiness = 1
fs.file-max = 1048576
fs.nr_open = 1048576
fs.inotify.max_user_instances = 262144

# TCP 回收与心跳
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 12
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_abort_on_overflow = 0

# 连接数并发限制
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

# FastOpen 与报文优化
net.core.optmem_max = 3276800
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_reordering = 3
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_tso_win_divisor = 6

# PID 与系统线程
kernel.pid_max = 4194304
kernel.threads-max = 85536
net.ipv4.neigh.default.gc_thresh1 = 1024
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv4.neigh.default.gc_stale_time = 100
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2

# Polling 与延迟
net.unix.max_dgram_qlen = 130000
net.core.busy_poll = 50
net.core.busy_read = 0

# 缓冲区抗膨胀
net.ipv4.tcp_notsent_lowat = 16384
vm.vfs_cache_pressure = 10
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.ip_forward = 1

# 安全与伪装
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

# IO/异步并发
fs.aio-max-nr = 262144
kernel.msgmax = 655350
kernel.msgmnb = 655350
net.ipv4.neigh.default.proxy_qlen = 50000

# BBR Pacing
net.ipv4.tcp_pacing_ca_ratio = 150
net.ipv4.tcp_pacing_ss_ratio = 210

# 核心保护
fs.protected_fifos = 1
fs.protected_hardlinks = 1
fs.protected_regular = 2
fs.protected_symlinks = 1

# 网卡队列 RPS
net.core.rps_sock_flow_entries = 131072
net.core.flow_limit_table_len = 131072
net.ipv4.tcp_workaround_signed_windows = 1
vm.dirty_ratio = 35
vm.overcommit_memory = 0
kernel.sysrq = 1

# 禁用 IPv6 避免泄漏
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# 系统边缘细节补充
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
        error "Sysctl 参数应用存在部分错误，可能受系统硬件或内核环境限制。"
        read -rp "按 Enter 返回菜单..." _
    else
        info "所有底层 Sysctl 参数应用完毕。"
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if [[ -n "$IFACE" ]]; then
        info "配置网卡驱动硬件卸载与 CPU 软中断分发 ($IFACE)..."
        
        cat > /usr/local/bin/nic-optimize.sh <<'EONIC'
#!/bin/bash
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
if [[ -n "$IFACE" ]]; then
    ethtool -K "$IFACE" lro off rx-gro-hw off 2>/dev/null || true
    ethtool -C "$IFACE" adaptive-rx off rx-usecs 0 tx-usecs 0 2>/dev/null || true
fi
EONIC
        chmod +x /usr/local/bin/nic-optimize.sh
        
        cat > /etc/systemd/system/nic-optimize.service << 'EOSERVICE'
[Unit]
Description=NIC Advanced Hardware Tuning Engine
After=network-online.target
Wants=network-online.target

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
        
        cat > /usr/local/bin/rps-optimize.sh <<'EOF'
#!/bin/bash
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
if [[ -z "$IFACE" ]]; then 
    exit 0
fi

CPU=$(nproc 2>/dev/null || echo 1)
CPU_MASK=$(printf "%x" $(( (1<<CPU)-1 )))
RX_QUEUES=$(ls /sys/class/net/"$IFACE"/queues/ 2>/dev/null | grep rx- | wc -l || echo 0)

for RX in /sys/class/net/"$IFACE"/queues/rx-*; do
    if [[ -w "$RX/rps_cpus" ]]; then
        echo "$CPU_MASK" > "$RX/rps_cpus" 2>/dev/null || true
    fi
done

for TX in /sys/class/net/"$IFACE"/queues/tx-*; do
    if [[ -w "$TX/xps_cpus" ]]; then
        echo "$CPU_MASK" > "$TX/xps_cpus" 2>/dev/null || true
    fi
done

sysctl -w net.core.rps_sock_flow_entries=131072 >/dev/null 2>&1 || true

if [[ "$RX_QUEUES" -gt 0 ]]; then
    FLOW_PER_QUEUE=$((65535 / RX_QUEUES))
    for RX in /sys/class/net/"$IFACE"/queues/rx-*; do
        if [[ -w "$RX/rps_flow_cnt" ]]; then
            echo "$FLOW_PER_QUEUE" > "$RX/rps_flow_cnt" 2>/dev/null || true
        fi
    done
fi
EOF
        chmod +x /usr/local/bin/rps-optimize.sh
        
        cat > /etc/systemd/system/rps-optimize.service << 'EOF'
[Unit]
Description=RPS RFS Network CPU Soft-Interrupt Distribution Engine
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/rps-optimize.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload >/dev/null 2>&1 || true
        systemctl enable rps-optimize.service >/dev/null 2>&1 || true
        systemctl start rps-optimize.service >/dev/null 2>&1 || true
        
        if systemctl is-active --quiet nic-optimize.service; then
            if systemctl is-active --quiet rps-optimize.service; then
                info "网卡硬件底层守护群已成功激活，开机自动执行已物理装载！"
            else
                warn "警报：网卡守护群 (RPS) 装载异常，可能失去极致吞吐能力。"
            fi
        else
            warn "警报：网卡守护群 (NIC) 装载异常，可能失去极致吞吐能力。"
        fi
    fi

    info "大满贯！全量巨型底层参数注入完成！系统即将重启应用物理层面的修改..."
    sleep 30
    reboot
}

do_txqueuelen_opt() {
    title "TX Queue 发送缓冲长队极速收缩方案"
    local IP_CMD
    IP_CMD=$(command -v ip || echo "")
    
    if [[ -z "$IP_CMD" ]]; then
        error "系统缺失 iproute2 工具包！无法执行此底层微操。"
        read -rp "Enter..." _
        return 1
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if [[ -z "$IFACE" ]]; then
        error "核心探针无法定位出口网卡设备！"
        read -rp "Enter..." _
        return 1
    fi
    
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
    read -rp "按 Enter 返回..." _
}

config_cake_advanced() {
    clear
    title "CAKE 高阶调度参数配置 (解决跨洋代理降速与排队失真)"
    
    local current_opts="无 (系统自适应默认)"
    if [[ -f "$CAKE_OPTS_FILE" ]]; then
        current_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
    fi
    echo -e "  系统当前已驻留的配置参数: ${cyan}${current_opts}${none}\n"
    
    local c_bw c_oh c_mpu rtt_sel diff_sel
    read -e -p "  [1] 声明物理带宽极限压迫点 (格式如 900Mbit, 不限速填 0): " c_bw
    read -e -p "  [2] 配置加密报文体积开销补偿 (格式纯数字如 48, 填 0 废弃): " c_oh
    read -e -p "  [3] 指定底层包头最小截断 MPU (格式数字如 84, 填 0 废弃): " c_mpu
    
    echo "  [4] 选择高仿真网络延迟 RTT 模型: "
    echo "    1) internet  (85ms 默认标准波段)"
    echo "    2) oceanic   (300ms 跨洋深海电缆对冲模型 - 推荐)"
    echo "    3) satellite (1000ms 疯狂丢包卫星极限模型)"
    read -e -p "  选择 (默认 2): " rtt_sel
    
    local c_rtt=""
    case "${rtt_sel:-2}" in
        1) c_rtt="internet" ;;
        3) c_rtt="satellite" ;;
        *) c_rtt="oceanic" ;;
    esac
    
    echo "  [5] 确立数据流分流盲走体系: "
    echo "    1) diffserv4  (耗费算力解拆分析特征，极度高消耗)"
    echo "    2) besteffort (忽略包特征直接盲推，最低延迟王者 - 推荐)"
    read -e -p "  选择 (默认 2): " diff_sel
    
    local c_diff=""
    case "${diff_sel:-2}" in
        1) c_diff="diffserv4" ;;
        *) c_diff="besteffort" ;;
    esac

    local final_opts=""
    if [[ -n "$c_bw" && "$c_bw" != "0" ]]; then 
        final_opts="$final_opts bandwidth $c_bw"
    fi
    if [[ -n "$c_oh" && "$c_oh" != "0" ]]; then 
        final_opts="$final_opts overhead $c_oh"
    fi
    if [[ -n "$c_mpu" && "$c_mpu" != "0" ]]; then 
        final_opts="$final_opts mpu $c_mpu"
    fi
    
    final_opts="$final_opts $c_rtt $c_diff"
    final_opts="${final_opts#"${final_opts%%[! ]*}"}"
    
    if [[ -z "$final_opts" ]]; then
        rm -f "$CAKE_OPTS_FILE" 2>/dev/null || true
        info "所有 CAKE 高阶管控参数均已被强行物理擦除。"
    else
        echo "$final_opts" > "$CAKE_OPTS_FILE"
        info "调度边界记录表已死死锁存入册: $final_opts"
    fi
    
    modprobe sch_cake 2>/dev/null || true
    _apply_cake_live
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if tc qdisc show dev "$IFACE" 2>/dev/null | grep -q "cake"; then
        info "自检极佳：核心 CAKE 调度器已极其稳固地接管出口网卡！"
    else
        warn "危机：物理层网卡队列未反馈 CAKE 状态，请确保内核支持 sch_cake！"
    fi
    
    read -rp "各项参数部署落定，敲打 Enter 回避..." _
}

# ==============================================================================
# [ 区块 XII: Xray 核心安装与网络部署枢纽 ]
# ==============================================================================

gen_ss_pass() { 
    head -c 24 /dev/urandom | base64 | tr -d '=/+\n' | head -c 24 || true
}

_select_ss_method() {
    echo -e "  ${cyan}选择 SS 加密方式：${none}" >&2
    echo "  1) aes-256-gcm (推荐)  2) aes-128-gcm  3) chacha20-ietf-poly1305" >&2
    local mc
    read -rp "  编号: " mc >&2
    case "${mc:-1}" in
        2) echo "aes-128-gcm" ;;
        3) echo "chacha20-ietf-poly1305" ;;
        *) echo "aes-256-gcm" ;;
    esac
}

do_install() {
    title "Xray 核心部署与网络架构初始化"
    preflight
    
    systemctl stop xray >/dev/null 2>&1 || true
    if [[ ! -f "$INSTALL_DATE_FILE" ]]; then 
        date +"%Y-%m-%d %H:%M:%S" > "$INSTALL_DATE_FILE"
    fi
    
    echo -e "  ${cyan}请选择需要部署的协议架构：${none}"
    echo "  1) VLESS-Reality (最新抗封锁协议，隐蔽特征)"
    echo "  2) Shadowsocks (极简架构，轻量开销)"
    echo "  3) 双协议并行部署"
    local proto_choice
    read -e -p "  请选择 (默认 1): " proto_choice
    proto_choice=${proto_choice:-1}

    local input_p input_remark
    if [[ "$proto_choice" == "1" || "$proto_choice" == "3" ]]; then
        while true; do 
            read -e -p "设置 VLESS 监听端口 (默认 443): " input_p
            input_p=${input_p:-443}
            if validate_port "$input_p"; then 
                LISTEN_PORT="$input_p"
                break
            fi
        done
        read -e -p "设置节点备注名称 (默认 xp-reality): " input_remark
        REMARK_NAME=${input_remark:-xp-reality}
        
        if ! choose_sni; then
            return 1
        fi
    fi

    local ss_port=8388
    local ss_pass=""
    local ss_method="aes-256-gcm"
    
    local input_s
    if [[ "$proto_choice" == "2" || "$proto_choice" == "3" ]]; then
        while true; do 
            read -e -p "设置 SS 监听端口 (默认 8388): " input_s
            input_s=${input_s:-8388}
            if validate_port "$input_s"; then 
                ss_port="$input_s"
                break
            fi
        done
        ss_pass=$(gen_ss_pass)
        ss_method=$(_select_ss_method)
        
        if [[ "$proto_choice" == "2" ]]; then 
            read -e -p "设置节点备注名称 (默认 xp-reality): " input_remark
            REMARK_NAME=${input_remark:-xp-reality}
        fi
    fi

    info "从官方仓库拉取最新 Xray 核心..."
    if ! bash -c "$(curl -fsSL --connect-timeout 10 https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1; then
        warn "通过官方脚本拉取失败，您可以稍后尝试重试。"
    fi
    
    install_update_dat
    fix_xray_systemd_limits

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

    if [[ "$proto_choice" == "1" || "$proto_choice" == "3" ]]; then
        local keys priv pub uuid sid ctime
        keys=$("$XRAY_BIN" x25519 2>/dev/null || echo "")
        priv=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' ' || echo "")
        pub=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' ' || echo "")
        uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
        sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n' || echo "")
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

    if [[ "$proto_choice" == "2" || "$proto_choice" == "3" ]]; then
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
        local opt
        read -rp "按 Enter 返回主菜单，或输入 b 重新配置 SNI: " opt
        if [[ "$opt" == "b" || "$opt" == "B" ]]; then
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
# ==============================================================================
# [ 区块 XIII: 节点信息分发中心与排版渲染 ]
# ==============================================================================

do_summary() {
    if [[ ! -f "$CONFIG" ]]; then 
        return
    fi
    title "节点连接信息分发中心"
    
    local vless_inbound
    vless_inbound=$(jq -c '.inbounds[]? | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
    
    if [[ -n "$vless_inbound" && "$vless_inbound" != "null" ]]; then
        local client_count
        client_count=$(echo "$vless_inbound" | jq -r '.settings.clients | length' 2>/dev/null || echo 0)
        
        if ((client_count > 0)); then
            local port pub main_sni
            port=$(echo "$vless_inbound" | jq -r '.port // empty' 2>/dev/null || echo "")
            pub=$(echo "$vless_inbound" | jq -r '.streamSettings.realitySettings.publicKey // empty' 2>/dev/null || echo "")
            main_sni=$(echo "$vless_inbound" | jq -r '.streamSettings.realitySettings.serverNames[0] // empty' 2>/dev/null || echo "")

            for ((i=0; i<client_count; i++)); do
                local uuid remark sid target_sni
                uuid=$(echo "$vless_inbound" | jq -r ".settings.clients[$i].id // empty" 2>/dev/null || echo "")
                remark=$(echo "$vless_inbound" | jq -r ".settings.clients[$i].email // \"$REMARK_NAME\"" 2>/dev/null || echo "")
                sid=$(echo "$vless_inbound" | jq -r ".streamSettings.realitySettings.shortIds[$i] // empty" 2>/dev/null || echo "")
                
                target_sni=$(grep "^$uuid|" "$USER_SNI_MAP" 2>/dev/null | cut -d'|' -f2 || echo "")
                target_sni=${target_sni:-$main_sni}

                if [[ -n "$uuid" && "$uuid" != "null" ]]; then 
                    hr
                    # 完美还原的定制化排版
                    echo -e "  协议框架       : VLESS-Reality (Vision)"
                    echo -e "  外网IP         : $SERVER_IP"
                    echo -e "  端口           : $port"
                    echo -e "  用户 UUID    : $uuid"
                    echo -e "  伪装SNI        : $target_sni"
                    echo -e "  公钥(pbk)     : $pub"
                    echo -e "  ShortId        : $sid"
                    echo -e "  uTLS引擎     : chrome"
                    echo -e "  备注           : $remark"
                    
                    local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${target_sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${remark}"
                    echo -e "\n  [INFO] 通用配置链接:\n  $link\n"
                    if command -v qrencode >/dev/null 2>&1; then 
                        qrencode -m 2 -t UTF8 "$link"
                    fi
                fi
            done
        fi
    fi

    local ss_inbound
    ss_inbound=$(jq -c '.inbounds[]? | select(.protocol=="shadowsocks")' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
    if [[ -n "$ss_inbound" && "$ss_inbound" != "null" ]]; then
        local s_port s_pass s_method
        s_port=$(echo "$ss_inbound" | jq -r '.port // empty' 2>/dev/null || echo "")
        s_pass=$(echo "$ss_inbound" | jq -r '.settings.password // empty' 2>/dev/null || echo "")
        s_method=$(echo "$ss_inbound" | jq -r '.settings.method // empty' 2>/dev/null || echo "")
        
        if [[ -n "$s_port" && "$s_port" != "null" ]]; then
            hr
            echo -e "  协议框架       : Shadowsocks"
            echo -e "  外网IP         : $SERVER_IP"
            echo -e "  端口           : $s_port"
            echo -e "  密码           : $s_pass"
            echo -e "  加密方式       : $s_method"
            echo -e "  备注           : ${REMARK_NAME}-SS"
            
            local b64
            b64=$(printf '%s' "${s_method}:${s_pass}" | base64 | tr -d '\n' || echo "")
            local ss_link="ss://${b64}@${SERVER_IP}:${s_port}#${REMARK_NAME}-SS"
            echo -e "\n  [INFO] 通用配置链接:\n  $ss_link\n"
            if command -v qrencode >/dev/null 2>&1; then 
                qrencode -m 2 -t UTF8 "$ss_link"
            fi
        fi
    fi

    hr
    echo -e "  ${gray}配置文件: $CONFIG | 备份中心: $BACKUP_DIR${none}"
}

# ==============================================================================
# [ 区块 XIV: 系统功能与状态追踪模块 ]
# ==============================================================================

do_user_manager() {
    while true; do
        title "用户与认证管理系统"
        if [[ ! -f "$CONFIG" ]]; then 
            error "未找到系统配置文件。"
            return
        fi

        local clients
        clients=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .settings?.clients[]? | .id + "|" + (.email // "未命名")' "$CONFIG" 2>/dev/null || echo "")
        if [[ -z "$clients" || "$clients" == "null" ]]; then 
            error "系统内未提取到 VLESS 凭证记录。"
            return
        fi

        local tmp_users="/tmp/xray_users_$$.txt"
        echo "$clients" | awk -F'|' '{print NR"|"$1"|"$2}' > "$tmp_users" || true
        
        echo -e "系统当前有效用户列表："
        while IFS='|' read -r num uid remark; do
            local utime
            utime=$(grep "^$uid|" "$USER_TIME_MAP" 2>/dev/null | cut -d'|' -f2 || echo "未知创建时间")
            echo -e "  $num) 用户: ${cyan}$remark${none} | 签发: ${gray}$utime${none} | ID: ${yellow}$uid${none}"
        done < "$tmp_users"
        hr
        
        echo "  a) 签发新用户凭证"
        echo "  m) 导入外部历史用户"
        echo "  s) 重新指派用户专属伪装 (SNI)"
        echo "  d) 吊销选中用户权限"
        echo "  q) 退出"
        read -e -p "请输入操作代码: " uopt

        case "$uopt" in
            a|A)
                local nu sid ctime u_remark
                nu=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
                sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n' || echo "")
                ctime=$(date +"%Y-%m-%d %H:%M")
                read -e -p "请指定用户名备注 (默认 User-$sid): " u_remark
                u_remark=${u_remark:-User-${sid}}

                _safe_jq_write --arg id "$nu" --arg email "$u_remark" '
                    (.inbounds[]? | select(.protocol=="vless") | .settings.clients) += [{"id":$id,"flow":"xtls-rprx-vision","email":$email}]
                '
                _safe_jq_write --arg sid "$sid" '
                    (.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.shortIds) += [$sid]
                '

                echo "$nu|$ctime" >> "$USER_TIME_MAP"
                ensure_xray_is_alive

                local port pub sni link
                port=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .port' "$CONFIG" 2>/dev/null | head -n 1)
                pub=$(jq -r  '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.publicKey' "$CONFIG" 2>/dev/null | head -n 1)
                sni=$(jq -r  '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0]' "$CONFIG" 2>/dev/null | head -n 1)
                link="vless://${nu}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${u_remark}"
                
                info "新用户签发成功。"; echo -e "\n  [INFO] 独立配置链接:\n  $link\n"
                read -rp "按 Enter 继续..." _
                ;;
            m|M)
                local m_remark m_uuid m_sid ctime
                read -e -p "请指定导入用户备注 (默认 Imported): " m_remark
                m_remark=${m_remark:-Imported}
                read -e -p "请输入要导入的 UUID: " m_uuid
                if [[ -z "$m_uuid" ]]; then continue; fi
                read -e -p "请输入对应的 ShortId: " m_sid
                if [[ -z "$m_sid" ]]; then continue; fi
                ctime=$(date +"%Y-%m-%d %H:%M")

                _safe_jq_write --arg id "$m_uuid" --arg email "$m_remark" '
                    (.inbounds[]? | select(.protocol=="vless") | .settings.clients) += [{"id":$id,"flow":"xtls-rprx-vision","email":$email}]
                '
                _safe_jq_write --arg sid "$m_sid" '
                    (.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.shortIds) += [$sid]
                '
                echo "$m_uuid|$ctime" >> "$USER_TIME_MAP"

                local m_sni
                read -e -p "绑定专属 SNI (直接回车使用系统默认): " m_sni
                if [[ -n "$m_sni" ]]; then
                    _safe_jq_write --arg sni "$m_sni" '
                        (.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) += [$sni] |
                        (.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) |= unique
                    '
                    sed -i "/^$m_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                    echo "$m_uuid|$m_sni" >> "$USER_SNI_MAP"
                else
                    m_sni=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0] // empty' "$CONFIG" 2>/dev/null | head -n 1)
                fi

                ensure_xray_is_alive
                local port pub link
                port=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .port // empty' "$CONFIG" 2>/dev/null | head -n 1)
                pub=$(jq -r  '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.publicKey // empty' "$CONFIG" 2>/dev/null | head -n 1)
                link="vless://${m_uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${m_sni}&fp=chrome&pbk=${pub}&sid=${m_sid}&type=tcp#${m_remark}"
                
                info "记录导入成功。"; echo -e "\n  [INFO] 独立配置链接:\n  $link\n"
                read -rp "按 Enter 继续..." _
                ;;
            s|S)
                local snum t_uuid t_remark u_sni
                read -e -p "请输入目标用户序列号: " snum
                t_uuid=$(awk -F'|' -v id="${snum:-0}" '$1==id{print $2}' "$tmp_users" 2>/dev/null || echo "")
                t_remark=$(awk -F'|' -v id="${snum:-0}" '$1==id{print $3}' "$tmp_users" 2>/dev/null || echo "")
                
                if [[ -n "$t_uuid" ]]; then
                    read -e -p "请输入新分配的伪装域名 (SNI): " u_sni
                    if [[ -n "$u_sni" ]]; then
                        _safe_jq_write --arg sni "$u_sni" '
                            (.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) += [$sni] |
                            (.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) |= unique
                        '
                        sed -i "/^$t_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                        echo "$t_uuid|$u_sni" >> "$USER_SNI_MAP"
                        
                        ensure_xray_is_alive
                        info "已成功更新 $t_remark 用户的防封锁 SNI: $u_sni"
                        
                        local vless_inbound port idx sid pub link
                        vless_inbound=$(jq -c '.inbounds[]? | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1)
                        port=$(echo "$vless_inbound" | jq -r '.port // empty' 2>/dev/null)
                        idx=$(( ${snum:-0} - 1 ))
                        sid=$(echo "$vless_inbound" | jq -r ".streamSettings.realitySettings.shortIds[$idx] // empty" 2>/dev/null)
                        pub=$(echo "$vless_inbound" | jq -r '.streamSettings.realitySettings.publicKey // empty' 2>/dev/null)
                        link="vless://${t_uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${u_sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${t_remark}"
                        
                        echo -e "\n  [INFO] 更新后的配置链接:\n  $link\n"
                        read -rp "按 Enter 继续..." _
                    fi
                else 
                    error "您输入的序列号不在当前列表中。"
                fi
                ;;
            d|D)
                local dnum total t_uuid idx
                read -e -p "请输入需要吊销的用户序列号: " dnum
                total=$(wc -l < "$tmp_users" 2>/dev/null || echo 0)
                
                if ((total <= 1)); then 
                    error "安全机制拦截：禁止删除系统中最后一位特权用户！"
                else
                    t_uuid=$(awk -F'|' -v id="${dnum:-0}" '$1==id{print $2}' "$tmp_users" 2>/dev/null || echo "")
                    if [[ -n "$t_uuid" ]]; then
                        idx=$(( ${dnum:-0} - 1 ))
                        _safe_jq_write --arg uid "$t_uuid" --argjson i "$idx" '
                            (.inbounds[]? | select(.protocol=="vless") | .settings.clients) |= map(select(.id != $uid)) | 
                            (.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.shortIds) |= del(.[$i])
                        '
                        sed -i "/^$t_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                        sed -i "/^$t_uuid|/d" "$USER_TIME_MAP" 2>/dev/null || true
                        ensure_xray_is_alive
                        info "已成功从系统核心中抹除用户: $t_uuid"
                    fi
                fi
                ;;
            q|Q) 
                rm -f "$tmp_users" 2>/dev/null || true
                break 
                ;;
        esac
    done
}

_global_block_rules() {
    while true; do
        title "全局防火墙与广告阻断策略"
        if [[ ! -f "$CONFIG" ]]; then 
            error "未找到配置数据。"
            return
        fi
        
        local bt_en ad_en
        bt_en=$(jq -r '.routing.rules[]? | select(.protocol != null) | select(.protocol | index("bittorrent")) | ._enabled' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        ad_en=$(jq -r '.routing.rules[]? | select(.domain != null) | select(.domain | index("geosite:category-ads-all")) | ._enabled' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        echo -e "  1) BT 下载协议阻断限制          | 状态: ${yellow}${bt_en:-未知}${none}"
        echo -e "  2) 全局恶意域名与广告黑洞过滤   | 状态: ${yellow}${ad_en:-未知}${none}"
        echo "  0) 返回上一层菜单"
        local bc
        read -e -p "请选择管理项: " bc
        
        case "$bc" in
            1)
                local nv="true"
                if [[ "$bt_en" == "true" ]]; then nv="false"; fi
                _safe_jq_write --argjson nv "$nv" '(.routing.rules[]? | select(.protocol != null and (.protocol | index("bittorrent")))) |= (._enabled = $nv)'
                ensure_xray_is_alive; info "BT 协议阻断状态已切换为: $nv" 
                ;;
            2)
                local nv="true"
                if [[ "$ad_en" == "true" ]]; then nv="false"; fi
                _safe_jq_write --argjson nv "$nv" '(.routing.rules[]? | select(.domain != null and (.domain | index("geosite:category-ads-all")))) |= (._enabled = $nv)'
                ensure_xray_is_alive; info "全局广告过滤状态已切换为: $nv" 
                ;;
            0) return ;;
        esac
    done
}

do_status_menu() {
    while true; do
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
        local s
        read -e -p "请指定管理指令: " s
        
        case "$s" in
            1) systemctl status xray --no-pager || true; read -rp "按 Enter 继续..." _ ;;
            2) 
                echo -e "\n  对外公网 IP: ${green}$SERVER_IP${none}\n  系统 DNS 路由: "
                grep "^nameserver" /etc/resolv.conf 2>/dev/null || echo "    获取失败"
                echo -e "  系统监听端口池:"
                ss -tlnp 2>/dev/null | grep xray || echo "    未检测到监听服务"
                read -rp "按 Enter 继续..." _ 
                ;;
            3) 
                if ! command -v vnstat >/dev/null 2>&1; then 
                    warn "您的服务器尚未安装 vnstat 监控工具。"
                    read -rp "按 Enter 继续..." _
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
                local vn_opt
                read -e -p "  执行系统任务: " vn_opt
                case "$vn_opt" in
                    1) 
                        local d_day
                        read -e -p "输入物理结算日标 (1-31): " d_day
                        if [[ "$d_day" =~ ^[0-9]+$ ]] && (( d_day >= 1 && d_day <= 31 )); then
                            sed -i '/^[#[:space:]]*MonthRotate/d' /etc/vnstat.conf 2>/dev/null || true
                            echo "MonthRotate $d_day" >> /etc/vnstat.conf
                            systemctl restart vnstat 2>/dev/null || true
                            info "底层配置已更新，流量账单将在每月 $d_day 号截断重组。"
                        else 
                            error "非法的输入格式。"
                        fi
                        read -rp "按 Enter 返回..." _ 
                        ;;
                    2)
                        local d_month
                        read -e -p "请输入要穿梭的历史锚点 (格式如 $(date +%Y-%m)，不填默认近 30 天): " d_month
                        if [[ -z "$d_month" ]]; then 
                            vnstat -d 2>/dev/null | sed -e 's/estimated/预估消耗/ig' -e 's/rx/接收流量/ig' -e 's/tx/发送流量/ig' -e 's/total/全域吞吐/ig' -e 's/daily/按日/ig' -e 's/monthly/按自然月/ig' || true
                        else 
                            vnstat -d 2>/dev/null | grep -iE "($d_month| day |estimated|--)" | sed -e 's/estimated/预估消耗/ig' -e 's/rx/接收流量/ig' -e 's/tx/发送流量/ig' -e 's/total/全域吞吐/ig' -e 's/daily/按日/ig' -e 's/monthly/按自然月/ig' || true
                        fi
                        read -rp "按 Enter 返回..." _ 
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
                    local cmd
                    if read -t 2 -n 1 -s cmd 2>/dev/null; then
                        if [[ "$cmd" == "q" || "$cmd" == "Q" || "$cmd" == $'\e' ]]; then break; fi
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
                    local new_nice
                    read -e -p "  请指定新抢占权重 (q 退出): " new_nice
                    if [[ "$new_nice" == "q" || "$new_nice" == "Q" ]]; then break; fi
                    if [[ "$new_nice" =~ ^-[1-2][0-9]$ ]] && ((new_nice >= -20 && new_nice <= -10)); then
                        sed -i "s/^Nice=.*/Nice=$new_nice/" "$limit_file" 2>/dev/null || true
                        systemctl daemon-reload >/dev/null 2>&1 || true
                        info "设置已记录，5 秒后重启进程应用更改..."
                        sleep 5; systemctl restart xray >/dev/null 2>&1 || true
                        info "内核提权配置完成。"
                        read -rp "按 Enter 返回..." _; break
                    else 
                        error "输入不在有效区间内！"
                        sleep 2
                    fi
                done
                ;;
            6) clear; title "程序运行轨迹日志"; tail -n 50 "$LOG_DIR/xray.log" 2>/dev/null || echo "  暂无留档记录。"; read -rp "按 Enter 退出..." _ ;;
            7) clear; title "系统错误警告日志"; tail -n 30 "$LOG_DIR/error.log" 2>/dev/null || echo "  服务运行正常，无报错产生。"; read -rp "按 Enter 退出..." _ ;;
            8)
                clear; title "自动化配置备份与灾难恢复中心"
                ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null || echo "系统内空空如也"
                echo -e "\n  r) 立即回滚至最新有效快照\n  c) 为当前环境手动创建配置快照\n  0) 退出"
                local bopt
                read -e -p "执行操作: " bopt
                if [[ "$bopt" == "r" ]]; then restore_latest_backup; fi
                if [[ "$bopt" == "c" ]]; then backup_config; info "快照已安全建立"; read -rp "Enter..." _; fi
                ;;
            0) return ;;
        esac
    done
}

do_sys_init_menu() {
    while true; do
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
        local sys_opt
        read -e -p "请指定需要执行的配置任务: " sys_opt
        
        case "$sys_opt" in
            1) 
                info "执行依赖安装及初始化工作..."
                apt-get update -y >/dev/null 2>&1 || true
                pkg_install wget curl sudo socat ntpdate e2fsprogs pkg-config iproute2 ethtool
                timedatectl set-timezone Asia/Kuala_Lumpur 2>/dev/null || true
                ntpdate -u us.pool.ntp.org 2>/dev/null || true
                hwclock --systohc 2>/dev/null || true
                check_and_create_1gb_swap
                info "系统底层环境初始化完成。"
                read -rp "按 Enter 键继续..." _ 
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
    read -rp "按 Enter 返回主菜单..." _
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
    read -rp "信息检索完毕，按 Enter 键返回..." _
}

do_uninstall() {
    title "环境清理与系统还原"
    local confirm
    read -e -p "警告: 该操作将不可逆地删除服务、配置及日志记录，是否确认注销？(y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then 
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

# 全局环境终极清理 (抹杀所有脚本模块)
uninstall_all() {
    clear
    echo -e "${gl_hong}╔════════════════════════════════════════════╗${gl_bai}"
    echo -e "${gl_hong}║       完全物理级抹杀与格式化清理大逃杀     ║${gl_bai}"
    echo -e "${gl_hong}╚════════════════════════════════════════════╝${gl_bai}"
    echo ""
    echo -e "${gl_huang}⚠️  警告：此操作将彻底抹杀系统的所有防爆模块，包括：${gl_bai}"
    echo ""
    echo "  • Xray 核心阵列及相关参数配置"
    echo "  • XanMod 内核（如果已安装）"
    echo "  • 所有别名 (xrv, bbr 等)"
    echo "  • 所有 BBR/网络优化配置及 sysctl 魔改"
    echo "  • MTU/DNS 净化持久化服务"
    echo ""
    echo -e "${gl_hong}此操作不可逆！${gl_bai}"
    echo ""
    
    local confirm
    read -e -p "确定要完全卸载吗？(输入 YES 确认): " confirm
    
    if [ "$confirm" != "YES" ]; then
        echo -e "${gl_huang}已取消卸载${gl_bai}"
        break_end
        return 1
    fi
    
    echo ""
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo -e "${gl_kjlan}开始执行物理级粉碎...${gl_bai}"
    echo ""
    
    local uninstall_count=0
    local xanmod_removed=0
    
    echo -e "${gl_huang}[1/8] 强行拆解 Xray 核心服务群...${gl_bai}"
    systemctl stop xray >/dev/null 2>&1 || true
    systemctl disable xray >/dev/null 2>&1 || true
    rm -rf /etc/systemd/system/xray* /lib/systemd/system/xray* >/dev/null 2>&1 || true
    systemctl stop dnsmasq >/dev/null 2>&1 || true
    systemctl disable dnsmasq >/dev/null 2>&1 || true
    chattr -i /etc/resolv.conf 2>/dev/null || true
    if [[ -f /etc/resolv.conf.bak ]]; then mv -f /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true; fi
    rm -rf "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SCRIPT_DIR" /var/log/xray* /usr/local/bin/xrv "$SCRIPT_PATH" >/dev/null 2>&1 || true
    (crontab -l 2>/dev/null | grep -v "update-dat.sh" | grep -v "systemctl restart xray") | crontab - 2>/dev/null || true
    echo -e "  ${gl_lv}✅ Xray 核心体系已被碾除${gl_bai}"
    uninstall_count=$((uninstall_count + 1))

    echo -e "${gl_huang}[2/8] 检查并剥离 XanMod 内核...${gl_bai}"
    if dpkg -l 2>/dev/null | grep -qE '^ii\s+linux-.*xanmod'; then
        local non_xanmod_kernels
        non_xanmod_kernels=$(dpkg -l 2>/dev/null | grep '^ii' | grep 'linux-image-' | grep -v 'xanmod' | grep -v 'dbg' | wc -l || echo "0")
        if [ "$non_xanmod_kernels" -eq 0 ]; then
            echo -e "  ${gl_hong}❌ 未检测到回退内核，拒绝执行剥离，以防机器暴毙变成砖！${gl_bai}"
            echo -e "  ${gl_huang}请先安装默认内核: apt install -y linux-image-amd64${gl_bai}"
        else
            echo "  正在剥离 XanMod 内核..."
            if apt purge -y 'linux-*xanmod*' > /dev/null 2>&1; then
                update-grub > /dev/null 2>&1 || true
            else
                echo -e "  ${gl_hong}❌ XanMod 内核卸载命令执行失败，请手动检查${gl_bai}"
            fi
            if dpkg -l 2>/dev/null | grep -qE '^ii\s+linux-.*xanmod'; then
                echo -e "  ${gl_hong}❌ 仍检测到 XanMod 内核残留${gl_bai}"
            else
                echo -e "  ${gl_lv}✅ XanMod 内核已物理剥离${gl_bai}"
                uninstall_count=$((uninstall_count + 1))
                xanmod_removed=1
            fi
        fi
    else
        echo -e "  ${gl_huang}未检测到 XanMod 内核，跳过${gl_bai}"
    fi
    echo ""
    
    echo -e "${gl_huang}[3/8] 强行抹除所有快捷别名与环境变量...${gl_bai}"
    local rc_files=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zshrc" "$HOME/.profile")
    local alias_found=0
    local alias_removed=0
    for rc_file in "${rc_files[@]}"; do
        if [ ! -f "$rc_file" ]; then continue; fi
        if grep -q "net-tcp-tune 快捷别名\|alias bbr=\|alias xrv=" "$rc_file" 2>/dev/null; then
            alias_found=1
            local temp_file=$(mktemp)
            sed '/net-tcp-tune 快捷别名/,/^alias bbr=/d' "$rc_file" 2>/dev/null > "$temp_file" || cp "$rc_file" "$temp_file"
            sed -i '/^# ================.*net-tcp-tune/d' "$temp_file" 2>/dev/null || true
            sed -i '/^# ================$/{ N; /net-tcp-tune\|alias bbr/d; }' "$temp_file" 2>/dev/null || true
            sed -i '/alias bbr.*net-tcp-tune/d' "$temp_file" 2>/dev/null || true
            sed -i '/alias xrv/d' "$temp_file" 2>/dev/null || true
            sed -i '/alias bbr.*vps-tcp-tune/d' "$temp_file" 2>/dev/null || true
            if ! diff -q "$rc_file" "$temp_file" > /dev/null 2>&1; then
                cp "$rc_file" "${rc_file}.bak.uninstall.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
                cp "$temp_file" "$rc_file" 2>/dev/null || true
                alias_removed=1
                echo -e "  ${gl_lv}✅ 已从 $(basename $rc_file) 中抹杀别名${gl_bai}"
            fi
            rm -f "$temp_file" 2>/dev/null || true
        fi
    done
    if [ $alias_found -eq 0 ]; then
        for rc_file in "${rc_files[@]}"; do
            if [ -f "$rc_file" ] && grep -q "^alias bbr=\|^alias xrv=" "$rc_file" 2>/dev/null; then
                sed -i '/^alias bbr=/d' "$rc_file" 2>/dev/null || true
                sed -i '/^alias xrv=/d' "$rc_file" 2>/dev/null || true
                alias_removed=1
                echo -e "  ${gl_lv}✅ 已从 $(basename $rc_file) 中强行抹除指令集${gl_bai}"
            fi
        done
    fi
    if [ $alias_removed -eq 1 ]; then
        unalias bbr 2>/dev/null || true
        unalias xrv 2>/dev/null || true
        echo -e "  ${gl_lv}✅ Alias 指令栈已清空${gl_bai}"
        uninstall_count=$((uninstall_count + 1))
    fi
    echo ""
    
    echo -e "${gl_huang}[4/8] 清理并重置 Sysctl 物理层控制网...${gl_bai}"
    local sysctl_files=("$SYSCTL_CONF" "/etc/sysctl.d/99-bbr-ultimate.conf" "/etc/sysctl.d/99-sysctl.conf" "/etc/sysctl.d/999-net-bbr-fq.conf" "/etc/sysctl.d/99-network-optimized.conf")
    local sysctl_cleaned=0
    for file in "${sysctl_files[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file" 2>/dev/null || true
            sysctl_cleaned=$((sysctl_cleaned + 1))
        fi
    done
    if [ -f "/etc/sysctl.d/99-disable-ipv6.conf" ]; then
        rm -f "/etc/sysctl.d/99-disable-ipv6.conf" 2>/dev/null || true
        sysctl_cleaned=$((sysctl_cleaned + 1))
    fi
    if [ -f "/etc/sysctl.conf.bak.original" ]; then
        cp /etc/sysctl.conf.bak.original /etc/sysctl.conf 2>/dev/null || true
        rm -f /etc/sysctl.conf.bak.original 2>/dev/null || true
        sysctl_cleaned=$((sysctl_cleaned + 1))
    fi
    if [ $sysctl_cleaned -gt 0 ]; then
        echo -e "  ${gl_lv}✅ 已拔除 $sysctl_cleaned 个底层配置文件${gl_bai}"
        uninstall_count=$((uninstall_count + 1))
    else
        echo -e "  ${gl_huang}系统内核态干净，无需回滚。${gl_bai}"
    fi
    echo ""

    echo -e "${gl_huang}[5/8] 切断 XanMod 软件源链路...${gl_bai}"
    local repo_files=("/etc/apt/sources.list.d/xanmod-release.list" "/usr/share/keyrings/xanmod-archive-keyring.gpg" "/etc/apt/sources.list.d/xanmod-kernel.list" "/etc/apt/trusted.gpg.d/xanmod-kernel.gpg")
    local repo_cleaned=0
    for file in "${repo_files[@]}"; do
        if [ -f "$file" ]; then
            rm -f "$file" 2>/dev/null || true
            repo_cleaned=$((repo_cleaned + 1))
        fi
    done
    if [ $repo_cleaned -gt 0 ]; then
        echo -e "  ${gl_lv}✅ GPG 密钥与源链路已切断${gl_bai}"
        uninstall_count=$((uninstall_count + 1))
    else
        echo -e "  ${gl_huang}未发现 XanMod 源。${gl_bai}"
    fi
    echo ""

    echo -e "${gl_huang}[6/8] 处决所有开机持久化守护进程...${gl_bai}"
    local persist_cleaned=0
    if [ -f /usr/local/etc/mtu-optimize.conf ]; then rm -f /usr/local/etc/mtu-optimize.conf 2>/dev/null || true; persist_cleaned=$((persist_cleaned + 1)); fi
    if [ -f /etc/systemd/system/mtu-optimize-persist.service ]; then
        systemctl disable mtu-optimize-persist.service 2>/dev/null || true
        rm -f /etc/systemd/system/mtu-optimize-persist.service /usr/local/bin/mtu-optimize-apply.sh 2>/dev/null || true
        persist_cleaned=$((persist_cleaned + 1))
    fi
    if [ -f /etc/systemd/system/bbr-optimize-persist.service ]; then
        systemctl disable bbr-optimize-persist.service 2>/dev/null || true
        rm -f /etc/systemd/system/bbr-optimize-persist.service /usr/local/bin/bbr-optimize-apply.sh 2>/dev/null || true
        persist_cleaned=$((persist_cleaned + 1))
    fi
    if [ -f /etc/systemd/system/dns-purify-persist.service ]; then
        systemctl disable dns-purify-persist.service 2>/dev/null || true
        rm -f /etc/systemd/system/dns-purify-persist.service /usr/local/bin/dns-purify-apply.sh 2>/dev/null || true
        persist_cleaned=$((persist_cleaned + 1))
    fi
    if [ -f /etc/systemd/system/xray-hw-tweaks.service ]; then
        systemctl disable xray-hw-tweaks.service 2>/dev/null || true
        rm -f /etc/systemd/system/xray-hw-tweaks.service /usr/local/bin/xray-hw-tweaks.sh 2>/dev/null || true
        persist_cleaned=$((persist_cleaned + 1))
    fi
    if [ $persist_cleaned -gt 0 ]; then
        systemctl daemon-reload 2>/dev/null || true
        echo -e "  ${gl_lv}✅ 已击杀 $persist_cleaned 个底层守护僵尸${gl_bai}"
        uninstall_count=$((uninstall_count + 1))
    fi
    echo ""

    echo -e "${gl_huang}[7/8] 清理散落的临时垃圾文件...${gl_bai}"
    rm -f /tmp/socks5_proxy_*.sh 2>/dev/null || true
    rm -rf /root/.realm_backup/ 2>/dev/null || true
    echo -e "  ${gl_lv}✅ 垃圾文件已粉碎${gl_bai}"
    echo ""

    echo -e "${gl_huang}[8/8] 触发 Sysctl 重载...${gl_bai}"
    sysctl --system > /dev/null 2>&1 || true
    echo -e "  ${gl_lv}✅ 内核配置已强行回滚复位${gl_bai}"
    echo ""

    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo -e "${gl_lv}✅ 物理级粉碎完成！宿主机已重归出厂纯净态。${gl_bai}"
    echo ""
    if [ "$xanmod_removed" -eq 1 ]; then
        echo -e "${gl_huang}严重警告: 核心驱动已被卸载，系统即将崩塌，必须立即重启以加载备用内核！${gl_bai}"
        local reboot_confirm
        read -e -p "是否赋予权限立刻重启？(Y/n): " reboot_confirm
        case "${reboot_confirm:-Y}" in
            [Yy])
                echo -e "${gl_lv}✅ 系统开始物理重启...${gl_bai}"
                sleep 2
                reboot
                ;;
            *)
                echo -e "${gl_hong}操作中止，请务必手动重启！${gl_bai}"
                exit 0
                ;;
        esac
    else
        echo -e "${gl_lv}✅ 无伤卸载，系统环境平稳，准备撤离。${gl_bai}"
        sleep 2
    fi
}
# ==============================================================================
# [ 区块 XVI: 星辰大海 Snell 协议高级管理矩阵 ]
# ==============================================================================

SNELL_RED="${gl_hong}"
SNELL_GREEN="${gl_lv}"
SNELL_YELLOW="${gl_huang}"
SNELL_BLUE="${gl_kjlan}"
SNELL_PURPLE="${gl_zi}"
SNELL_CYAN="${gl_kjlan}"
SNELL_RESET="${gl_bai}"
SNELL_LOG_FILE="/var/log/snell_manager.log"
SNELL_SERVICE_NAME="snell.service"

get_system_type_snell() {
    if [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/redhat-release ]; then
        echo "centos"
    else
        echo "unknown"
    fi
}

wait_for_package_manager_snell() {
    local system_type
    system_type=$(get_system_type_snell)
    if [ "$system_type" = "debian" ]; then
        while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1 || fuser /var/cache/apt/archives/lock >/dev/null 2>&1; do
            echo -e "${SNELL_YELLOW}等待其他 apt 进程完成${SNELL_RESET}"
            sleep 1
        done
    fi
}

install_required_packages_snell() {
    local system_type
    system_type=$(get_system_type_snell)
    echo -e "${SNELL_GREEN}安装必要的软件包${SNELL_RESET}"

    if [ "$system_type" = "debian" ]; then
        apt update -y >/dev/null 2>&1 || true
        apt install -y wget unzip curl >/dev/null 2>&1 || true
    elif [ "$system_type" = "centos" ]; then
        if command -v dnf &>/dev/null; then
            dnf install -y wget unzip curl >/dev/null 2>&1 || true
        else
            yum -y install wget unzip curl >/dev/null 2>&1 || true
        fi
    else
        echo -e "${SNELL_RED}不支持的系统类型${SNELL_RESET}"
        return 1
    fi
}

check_snell_installed() {
    if command -v snell-server &> /dev/null; then return 0; else return 1; fi
}

cleanup_partial_install_snell() {
    local port="$1"
    if [ -n "$port" ]; then
        systemctl stop "snell-${port}.service" 2>/dev/null || true
        systemctl disable "snell-${port}.service" 2>/dev/null || true
        systemctl reset-failed "snell-${port}.service" 2>/dev/null || true
        rm -f "/etc/systemd/system/snell-${port}.service"
        rm -rf "/etc/systemd/system/snell-${port}.service.d"
        rm -f "/etc/snell/snell-${port}.conf"
        rm -f "/etc/snell/config-${port}.txt"
        systemctl daemon-reload 2>/dev/null || true
        type remove_snell_port_from_reserved >/dev/null 2>&1 && remove_snell_port_from_reserved "${port}" 2>/dev/null || true
    fi
    rm -f /tmp/snell-server*.zip 2>/dev/null || true
    rm -f snell-server.zip 2>/dev/null || true
}

add_snell_port_to_reserved() {
    local port="$1"
    [ -n "$port" ] || return 0
    local reserved_file="/etc/sysctl.d/99-zzz-snell-reserved-ports.conf"

    local current=""
    if [ -f "$reserved_file" ]; then
        current=$(grep -E '^[[:space:]]*net\.ipv4\.ip_local_reserved_ports' "$reserved_file" 2>/dev/null | sed -E 's/^[^=]+=[[:space:]]*//' | tr -d ' ')
    fi

    local extra=""
    local f line val
    for f in /etc/sysctl.d/*.conf /etc/sysctl.conf; do
        [ -f "$f" ] || continue
        [ "$(basename "$f")" = "99-zzz-snell-reserved-ports.conf" ] && continue
        line=$(grep -E '^[[:space:]]*net\.ipv4\.ip_local_reserved_ports' "$f" 2>/dev/null | tail -n 1)
        [ -z "$line" ] && continue
        val=$(echo "$line" | sed -E 's/^[^=]+=[[:space:]]*//' | tr -d ' ')
        [ -z "$val" ] && continue
        extra="${extra:+$extra,}${val}"
    done

    local merged
    merged=$(echo "${current},${extra},${port}" | tr ',' '\n' | grep -E '^[0-9]+$' | sort -un | paste -sd, -)
    [ -z "$merged" ] && merged="$port"

    cat > "$reserved_file" <<EOF
# Snell 监听端口保留列表（由 net-tcp-tune 自动管理，请勿手动修改）
net.ipv4.ip_local_reserved_ports = ${merged}
EOF
    sysctl -p "$reserved_file" >/dev/null 2>&1 || true
}

remove_snell_port_from_reserved() {
    local port="$1"
    [ -n "$port" ] || return 0
    local reserved_file="/etc/sysctl.d/99-zzz-snell-reserved-ports.conf"
    [ -f "$reserved_file" ] || return 0
    local current
    current=$(grep -E '^[[:space:]]*net\.ipv4\.ip_local_reserved_ports' "$reserved_file" 2>/dev/null | sed -E 's/^[^=]+=[[:space:]]*//' | tr -d ' ')
    [ -z "$current" ] && return 0
    local new_list
    new_list=$(echo "$current" | tr ',' '\n' | grep -v "^${port}$" | paste -sd, - || true)
    if [ -z "$new_list" ]; then
        rm -f "$reserved_file"
        sysctl --system >/dev/null 2>&1 || true
    else
        cat > "$reserved_file" <<EOF
# Snell 监听端口保留列表
net.ipv4.ip_local_reserved_ports = ${new_list}
EOF
        sysctl -p "$reserved_file" >/dev/null 2>&1 || true
    fi
}

remove_all_snell_reserved_ports() {
    local reserved_file="/etc/sysctl.d/99-zzz-snell-reserved-ports.conf"
    if [ -f "$reserved_file" ]; then
        rm -f "$reserved_file"
        sysctl --system >/dev/null 2>&1 || true
    fi
}

install_snell() {
    echo -e "${SNELL_GREEN}正在部署 Snell 实例${SNELL_RESET}"

    wait_for_package_manager_snell
    if ! install_required_packages_snell; then
        echo -e "${SNELL_RED}安装必要软件包失败，请检查您的网络连接。${SNELL_RESET}"
        return 1
    fi

    local ARCH VERSION SNELL_URL INSTALL_DIR SYSTEMD_SERVICE_FILE CONF_DIR CONF_FILE
    ARCH=$(uname -m)
    VERSION="v5.0.1"
    INSTALL_DIR="/usr/local/bin"
    CONF_DIR="/etc/snell"

    case "$ARCH" in
        aarch64|arm64) SNELL_URL="https://dl.nssurge.com/snell/snell-server-${VERSION}-linux-aarch64.zip" ;;
        x86_64|amd64)  SNELL_URL="https://dl.nssurge.com/snell/snell-server-${VERSION}-linux-amd64.zip" ;;
        *)
            echo -e "${SNELL_RED}不支持的架构: ${ARCH}（仅支持 x86_64 / aarch64）${SNELL_RESET}"
            return 1 ;;
    esac

    wget --timeout=30 --tries=3 -q --show-progress "${SNELL_URL}" -O /tmp/snell-server.zip
    if [ $? -ne 0 ] || [ ! -s /tmp/snell-server.zip ]; then
        echo -e "${SNELL_RED}下载 Snell 核心失败。${SNELL_RESET}"
        rm -f /tmp/snell-server.zip
        return 1
    fi

    unzip -o /tmp/snell-server.zip -d ${INSTALL_DIR} >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${SNELL_RED}解压缩 Snell 失败。${SNELL_RESET}"
        rm -f /tmp/snell-server.zip
        return 1
    fi

    rm -f /tmp/snell-server.zip
    chmod +x ${INSTALL_DIR}/snell-server

    local SNELL_PORT RANDOM_PSK
    SNELL_PORT=$(shuf -i 10000-29999 -n 1)
    RANDOM_PSK=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 20)

    if ! getent group "snell" &>/dev/null; then groupadd -r snell; fi
    if ! id "snell" &>/dev/null; then
        useradd -r -g snell -s /usr/sbin/nologin -d /nonexistent snell 2>/dev/null || \
        useradd -r -g snell -s /sbin/nologin -d /nonexistent snell
    fi

    mkdir -p ${CONF_DIR}

    echo -e "${SNELL_CYAN}请输入端口号 (1-65535)，直接回车使用随机端口 [默认: ${SNELL_PORT}]:${SNELL_RESET}"
    while true; do
        local custom_port
        read -e -p "端口: " custom_port
        if [ -z "$custom_port" ]; then
            echo -e "${SNELL_GREEN}使用随机端口: ${SNELL_PORT}${SNELL_RESET}"
            break
        fi
        if [[ "$custom_port" =~ ^[0-9]+$ ]] && [ "$custom_port" -ge 1 ] && [ "$custom_port" -le 65535 ]; then
            SNELL_PORT=$custom_port
            echo -e "${SNELL_GREEN}已设置端口为: ${SNELL_PORT}${SNELL_RESET}"
            break
        else
            echo -e "${SNELL_RED}无效端口，请输入 1-65535 之间的数字，或直接回车使用随机端口${SNELL_RESET}"
        fi
    done
    
    local NODE_NAME
    echo -e "${SNELL_CYAN}请输入节点名称 (例如: 🇯🇵【Gen2】Fxtransit JP T1):${SNELL_RESET}"
    read -e -p "节点名称: " NODE_NAME
    if [ -z "$NODE_NAME" ]; then
        NODE_NAME="Snell-Node-${SNELL_PORT}"
        echo -e "${SNELL_YELLOW}未输入名称，使用默认名称: ${NODE_NAME}${SNELL_RESET}"
    fi

    CONF_FILE="${CONF_DIR}/snell-${SNELL_PORT}.conf"
    SYSTEMD_SERVICE_FILE="/etc/systemd/system/snell-${SNELL_PORT}.service"
    SNELL_SERVICE_NAME="snell-${SNELL_PORT}.service"

    local port_in_use=0
    if ss -ltnH "( sport = :${SNELL_PORT} )" 2>/dev/null | grep -q .; then port_in_use=1; fi
    if ss -lunH "( sport = :${SNELL_PORT} )" 2>/dev/null | grep -q .; then port_in_use=1; fi
    if [ "$port_in_use" -eq 1 ]; then
        echo -e "${SNELL_RED}端口 ${SNELL_PORT} 已被系统其他进程占用，请另换端口。${SNELL_RESET}"
        return 1
    fi

    if [ -f "${SYSTEMD_SERVICE_FILE}" ]; then
        echo -e "${SNELL_RED}该端口下的 Snell 实例已存在，请卸载后重装或更换端口。${SNELL_RESET}"
        return 1
    fi

    echo -e "${SNELL_CYAN}请选择监听模式:${SNELL_RESET}"
    echo "1. 仅 IPv4 (0.0.0.0)"
    echo "2. 仅 IPv6 ([::])"
    echo "3. 双栈 (同时支持 IPv4 和 IPv6)"
    local listen_mode
    read -e -p "请输入选项 [1-3，默认为 1]: " listen_mode
    listen_mode=${listen_mode:-1}

    local IP_VERSION_STR="" LISTEN_ADDR="" IPV6_ENABLED=""
    case $listen_mode in
        2) LISTEN_ADDR="[::]:${SNELL_PORT}"; IPV6_ENABLED="true"; IP_VERSION_STR=", ip-version=v6-only"; echo -e "${SNELL_GREEN}已选择：仅 IPv6 模式${SNELL_RESET}" ;;
        3) LISTEN_ADDR="[::]:${SNELL_PORT}"; IPV6_ENABLED="true"; IP_VERSION_STR=""; echo -e "${SNELL_GREEN}已选择：双栈模式${SNELL_RESET}" ;;
        *) LISTEN_ADDR="0.0.0.0:${SNELL_PORT}"; IPV6_ENABLED="false"; IP_VERSION_STR=", ip-version=v4-only"; echo -e "${SNELL_GREEN}已选择：仅 IPv4 模式${SNELL_RESET}" ;;
    esac

    cat > "${CONF_FILE}" << EOF
[snell-server]
listen = ${LISTEN_ADDR}
psk = ${RANDOM_PSK}
ipv6 = ${IPV6_ENABLED}
EOF

    chown snell:snell "${CONF_DIR}"
    chmod 750 "${CONF_DIR}"
    chown snell:snell "${CONF_FILE}"
    chmod 640 "${CONF_FILE}"

    cat > "${SYSTEMD_SERVICE_FILE}" << EOF
[Unit]
Description=Snell Proxy Service (Port ${SNELL_PORT})
After=network.target network-online.target
Wants=network-online.target
StartLimitIntervalSec=0
StartLimitInterval=0
StartLimitBurst=0

[Service]
Type=simple
User=snell
Group=snell
ExecStart=${INSTALL_DIR}/snell-server -c ${CONF_FILE}
AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_NET_ADMIN CAP_NET_RAW
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_ADMIN CAP_NET_RAW
LimitNOFILE=32768
Restart=always
RestartSec=10
KillMode=mixed
KillSignal=SIGTERM
TimeoutStopSec=5s
OOMScoreAdjust=-500
StandardOutput=journal
StandardError=journal
SyslogIdentifier=snell-${SNELL_PORT}

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "${SNELL_SERVICE_NAME}" >/dev/null 2>&1
    add_snell_port_to_reserved "${SNELL_PORT}"
    
    systemctl start "${SNELL_SERVICE_NAME}"
    if [ $? -ne 0 ]; then
        echo -e "${SNELL_RED}启动 Snell 服务失败。${SNELL_RESET}"
        cleanup_partial_install_snell "${SNELL_PORT}"
        return 1
    fi
    sleep 2

    if ! systemctl is-active --quiet "${SNELL_SERVICE_NAME}"; then
        echo -e "${SNELL_RED}Snell 启动后立即崩溃，请检查日志：${SNELL_RESET}"
        journalctl -u "${SNELL_SERVICE_NAME}" -n 20 --no-pager 2>/dev/null
        cleanup_partial_install_snell "${SNELL_PORT}"
        return 1
    fi

    echo -e "${SNELL_GREEN}Snell (端口 ${SNELL_PORT}) 安装成功${SNELL_RESET}"

    local HOST_IP=""
    case "$listen_mode" in
        1) HOST_IP=$(curl -4 -s --max-time 5 https://api.ipify.org 2>/dev/null || curl -4 -s --max-time 5 https://ifconfig.me 2>/dev/null) ;;
        2) HOST_IP=$(curl -6 -s --max-time 5 https://api64.ipify.org 2>/dev/null || curl -6 -s --max-time 5 https://ifconfig.co 2>/dev/null) ;;
        3) HOST_IP=$(curl -4 -s --max-time 5 https://api.ipify.org 2>/dev/null || curl -6 -s --max-time 5 https://api64.ipify.org 2>/dev/null) ;;
        *) HOST_IP=$(curl -4 -s --max-time 5 https://api.ipify.org 2>/dev/null) ;;
    esac

    if [ -z "$HOST_IP" ]; then
        echo -e "${SNELL_YELLOW}⚠ 无法自动获取公网 IP，请手动替换配置中的 <IP>${SNELL_RESET}"
        HOST_IP="<请填写公网IP>"
    fi

    local HOST_IP_FORMATTED="$HOST_IP"
    if echo "$HOST_IP" | grep -q ":"; then HOST_IP_FORMATTED="[${HOST_IP}]"; fi

    local FINAL_CONFIG="${NODE_NAME} = snell, ${HOST_IP_FORMATTED}, ${SNELL_PORT}, psk=${RANDOM_PSK}, version=5, reuse=true${IP_VERSION_STR}"

    echo ""
    echo -e "${SNELL_GREEN}节点信息输出：${SNELL_RESET}"
    echo -e "${SNELL_CYAN}${FINAL_CONFIG}${SNELL_RESET}"

    cat << EOF > "/etc/snell/config-${SNELL_PORT}.txt"
${FINAL_CONFIG}
EOF
    chmod 600 "/etc/snell/config-${SNELL_PORT}.txt"
}

list_snell_instances() {
    echo -e "${SNELL_CYAN}当前已安装的 Snell 实例：${SNELL_RESET}"
    echo "================================================================"
    printf "%-30s %-12s %-12s %-10s\n" "节点名称" "端口" "状态" "版本"
    echo "================================================================"

    local count=0
    for service_file in /etc/systemd/system/snell-*.service; do
        if [ -f "$service_file" ]; then
            local port
            port=$(echo "$service_file" | sed -E 's/.*snell-([0-9]+)\.service/\1/')
            local status_text="已停止"
            if systemctl is-active --quiet "snell-${port}.service"; then status_text="运行中"; fi
            
            local node_name="未命名"
            if [ -f "/etc/snell/config-${port}.txt" ]; then
                node_name=$(head -n 1 "/etc/snell/config-${port}.txt" | awk -F' = ' '{print $1}')
            fi
            
            if [ "$status_text" = "运行中" ]; then
                printf "%-30s %-12s ${SNELL_GREEN}%-12s${SNELL_RESET} %-10s\n" "$node_name" "$port" "$status_text" "v5"
            else
                printf "%-30s %-12s ${SNELL_RED}%-12s${SNELL_RESET} %-10s\n" "$node_name" "$port" "$status_text" "v5"
            fi
            ((count++))
        fi
    done

    if [ -f "/lib/systemd/system/snell.service" ] || [ -f "/etc/systemd/system/snell.service" ]; then
        local status_text="已停止"
        if systemctl is-active --quiet "snell.service"; then status_text="运行中"; fi
        local port="未知"
        if [ -f "/etc/snell/snell-server.conf" ]; then
            port=$(grep "listen" /etc/snell/snell-server.conf | awk -F':' '{print $NF}')
        fi
        local node_name="旧版实例"
        if [ -f "/etc/snell/config.txt" ]; then
            node_name=$(head -n 1 "/etc/snell/config.txt" | awk -F' = ' '{print $1}')
        fi
        if [ "$status_text" = "运行中" ]; then
            printf "%-30s %-12s ${SNELL_GREEN}%-12s${SNELL_RESET} %-10s\n" "$node_name" "$port" "$status_text" "v5"
        else
            printf "%-30s %-12s ${SNELL_RED}%-12s${SNELL_RESET} %-10s\n" "$node_name" "$port" "$status_text" "v5"
        fi
        ((count++))
    fi

    if [ "$count" -eq 0 ]; then
        echo "暂未安装任何 Snell 实例"
    fi
    echo "================================================================"
    echo ""
    return $count
}

uninstall_snell() {
    echo -e "${SNELL_GREEN}=== 卸载 Snell 服务 ===${SNELL_RESET}"
    list_snell_instances
    local instance_count=$?
    if [ "$instance_count" -eq 0 ]; then
        echo -e "${SNELL_YELLOW}未检测到任何实例，退出。${SNELL_RESET}"
        return
    fi

    echo "1. 卸载指定端口实例"
    echo "2. 卸载所有实例"
    echo "0. 取消"
    local uninstall_choice
    read -e -p "请输入选项 [0-2]: " uninstall_choice

    case "$uninstall_choice" in
        1)
            local port_to_uninstall
            read -e -p "请输入要卸载的端口号: " port_to_uninstall
            if [ -z "$port_to_uninstall" ]; then return; fi
            local service_name=""
            if [ -f "/etc/systemd/system/snell-${port_to_uninstall}.service" ]; then
                service_name="snell-${port_to_uninstall}.service"
            elif [ -f "/lib/systemd/system/snell.service" ] || [ -f "/etc/systemd/system/snell.service" ]; then
                if grep -q ":${port_to_uninstall}" /etc/snell/snell-server.conf 2>/dev/null; then
                    service_name="snell.service"
                fi
            fi
            if [ -z "$service_name" ]; then
                echo -e "${SNELL_RED}未找到端口 ${port_to_uninstall} 的实例${SNELL_RESET}"
                return
            fi
            systemctl stop "$service_name" 2>/dev/null || true
            systemctl disable "$service_name" 2>/dev/null || true
            systemctl reset-failed "$service_name" 2>/dev/null || true
            rm -f "/etc/systemd/system/${service_name}" "/lib/systemd/system/${service_name}" 2>/dev/null || true
            rm -rf "/etc/systemd/system/${service_name}.d" 2>/dev/null || true
            if [ "$service_name" == "snell.service" ]; then
                rm -f /etc/snell/snell-server.conf 2>/dev/null || true
            else
                rm -f "/etc/snell/snell-${port_to_uninstall}.conf" "/etc/snell/config-${port_to_uninstall}.txt" 2>/dev/null || true
            fi
            remove_snell_port_from_reserved "$port_to_uninstall"
            systemctl daemon-reload
            echo -e "${SNELL_GREEN}实例 ${port_to_uninstall} 卸载成功${SNELL_RESET}"
            ;;
        2)
            echo "正在卸载所有 Snell 实例..."
            for service_file in /etc/systemd/system/snell-*.service; do
                if [ -f "$service_file" ]; then
                    local port
                    port=$(echo "$service_file" | sed -E 's/.*snell-([0-9]+)\.service/\1/')
                    systemctl stop "snell-${port}.service" 2>/dev/null || true
                    systemctl disable "snell-${port}.service" 2>/dev/null || true
                    systemctl reset-failed "snell-${port}.service" 2>/dev/null || true
                    rm -f "$service_file"
                    rm -rf "/etc/systemd/system/snell-${port}.service.d" 2>/dev/null || true
                fi
            done
            if systemctl list-unit-files | grep -q "snell.service"; then
                systemctl stop snell.service 2>/dev/null || true
                systemctl disable snell.service 2>/dev/null || true
                rm -f /lib/systemd/system/snell.service /etc/systemd/system/snell.service 2>/dev/null || true
                rm -rf /etc/systemd/system/snell.service.d 2>/dev/null || true
            fi
            rm -rf /etc/snell
            rm -f /usr/local/bin/snell-server
            remove_all_snell_reserved_ports
            systemctl daemon-reload
            echo -e "${SNELL_GREEN}所有 Snell 实例已被物理抹除！${SNELL_RESET}"
            ;;
        *) return ;;
    esac
}

update_snell() {
    local INSTALL_DIR="/usr/local/bin"
    local SNELL_BIN="${INSTALL_DIR}/snell-server"
    if [ ! -f "${SNELL_BIN}" ]; then
        echo -e "${SNELL_YELLOW}Snell 未安装，跳过更新${SNELL_RESET}"
        return 0
    fi
    echo -e "${SNELL_GREEN}正在更新 Snell 核心...${SNELL_RESET}"

    local running_services=()
    local svc_file svc_name
    for svc_file in /etc/systemd/system/snell-*.service; do
        [ -f "$svc_file" ] || continue
        svc_name=$(basename "$svc_file")
        if systemctl is-active --quiet "$svc_name" 2>/dev/null; then
            running_services+=("$svc_name")
        fi
    done
    local has_legacy=0
    if systemctl is-active --quiet snell 2>/dev/null; then has_legacy=1; fi

    wait_for_package_manager_snell
    install_required_packages_snell || return 1

    local ARCH VERSION SNELL_URL
    ARCH=$(uname -m)
    VERSION="v5.0.1"
    case "$ARCH" in
        aarch64|arm64) SNELL_URL="https://dl.nssurge.com/snell/snell-server-${VERSION}-linux-aarch64.zip" ;;
        x86_64|amd64)  SNELL_URL="https://dl.nssurge.com/snell/snell-server-${VERSION}-linux-amd64.zip" ;;
        *) echo -e "${SNELL_RED}不支持架构${SNELL_RESET}"; return 1 ;;
    esac

    local TMP_ZIP TMP_DIR
    TMP_ZIP=$(mktemp /tmp/snell-server.XXXXXX.zip) || return 1
    TMP_DIR=$(mktemp -d /tmp/snell-update.XXXXXX) || { rm -f "$TMP_ZIP"; return 1; }

    if ! wget --timeout=30 --tries=3 -q --show-progress "${SNELL_URL}" -O "$TMP_ZIP"; then
        echo -e "${SNELL_RED}下载更新包失败。${SNELL_RESET}"
        rm -f "$TMP_ZIP"; rm -rf "$TMP_DIR"; return 1
    fi
    if [ ! -s "$TMP_ZIP" ]; then
        echo -e "${SNELL_RED}更新包尺寸异常。${SNELL_RESET}"
        rm -f "$TMP_ZIP"; rm -rf "$TMP_DIR"; return 1
    fi
    if ! unzip -o "$TMP_ZIP" -d "$TMP_DIR" >/dev/null 2>&1; then
        echo -e "${SNELL_RED}解压失败。${SNELL_RESET}"
        rm -f "$TMP_ZIP"; rm -rf "$TMP_DIR"; return 1
    fi

    cp "${SNELL_BIN}" "${SNELL_BIN}.bak"
    for svc_name in "${running_services[@]}"; do systemctl stop "$svc_name" 2>/dev/null; done
    [ "$has_legacy" -eq 1 ] && systemctl stop snell 2>/dev/null

    if ! mv "$TMP_DIR/snell-server" "${SNELL_BIN}"; then
        echo -e "${SNELL_RED}二进制替换失败，回滚...${SNELL_RESET}"
        mv "${SNELL_BIN}.bak" "${SNELL_BIN}" 2>/dev/null || true
        for svc_name in "${running_services[@]}"; do systemctl start "$svc_name" 2>/dev/null; done
        [ "$has_legacy" -eq 1 ] && systemctl start snell 2>/dev/null
        rm -f "$TMP_ZIP"; rm -rf "$TMP_DIR"; return 1
    fi
    chmod +x "${SNELL_BIN}"
    rm -f "$TMP_ZIP"; rm -rf "$TMP_DIR"

    local restart_count=0 restart_failed=0
    for svc_name in "${running_services[@]}"; do
        if systemctl restart "$svc_name"; then restart_count=$((restart_count + 1)); else restart_failed=$((restart_failed + 1)); fi
    done
    [ "$has_legacy" -eq 1 ] && systemctl restart snell 2>/dev/null

    if [ "$restart_failed" -gt 0 ]; then
        echo -e "${SNELL_RED}存在启动失败实例，执行二进制回滚...${SNELL_RESET}"
        if [ -f "${SNELL_BIN}.bak" ]; then
            mv "${SNELL_BIN}.bak" "${SNELL_BIN}"
            chmod +x "${SNELL_BIN}"
            for svc_name in "${running_services[@]}"; do systemctl restart "$svc_name" 2>/dev/null; done
        fi
        return 1
    fi

    rm -f "${SNELL_BIN}.bak" 2>/dev/null || true
    echo -e "${SNELL_GREEN}Snell 核心已热更新完毕。${SNELL_RESET}"
    list_snell_instances
}

snell_menu() {
    while true; do
        clear
        echo -e "${SNELL_CYAN}=== Snell 节点矩阵控制台中枢 ===${SNELL_RESET}"
        local instance_count=0 running_count=0
        for service_file in /etc/systemd/system/snell-*.service; do
            if [ -f "$service_file" ]; then
                ((instance_count++))
                local port
                port=$(echo "$service_file" | sed -E 's/.*snell-([0-9]+)\.service/\1/')
                if systemctl is-active --quiet "snell-${port}.service"; then ((running_count++)); fi
            fi
        done
        if [ -f "/lib/systemd/system/snell.service" ] || [ -f "/etc/systemd/system/snell.service" ]; then
            ((instance_count++))
            if systemctl is-active --quiet "snell.service"; then ((running_count++)); fi
        fi
        
        echo -e "已部署实例: ${SNELL_GREEN}${instance_count}${SNELL_RESET} | 活跃状态: ${SNELL_GREEN}${running_count}${SNELL_RESET}"
        echo "======================"
        echo " 1. 签发新的 Snell 节点实例"
        echo " 2. 剥离并卸载 Snell 服务"
        echo " 3. 检阅现有 Snell 矩阵集群"
        echo " 4. 执行二进制热更迭代"
        echo " 5. 调取指定端口的节点凭证"
        echo " 0. 返回主控总成"
        echo "======================"
        local snell_choice
        read -e -p "请输入指令: " snell_choice
        case "$snell_choice" in
            1) install_snell; break_end ;;
            2) uninstall_snell ;;
            3) list_snell_instances; break_end ;;
            4) update_snell; break_end ;;
            5) 
                list_snell_instances
                if [ $? -gt 0 ]; then
                    local view_port
                    read -e -p "调取配置的端口号: " view_port
                    if [ -f "/etc/snell/config-${view_port}.txt" ]; then
                        echo ""; cat "/etc/snell/config-${view_port}.txt"; echo ""
                    elif [ -f "/etc/snell/snell-server.conf" ] && grep -q ":${view_port}" /etc/snell/snell-server.conf; then
                        echo "旧版配置:"; cat /etc/snell/snell-server.conf; echo ""
                    else
                        echo -e "${SNELL_RED}检索不到该端口的挂载配置。${SNELL_RESET}"
                    fi
                fi
                break_end
                ;;
            0) return ;;
            *) echo -e "${SNELL_RED}指令无效${SNELL_RESET}"; sleep 1 ;;
        esac
    done
}

# ==============================================================================
# [ 区块 XVII: Xray AIO (All-in-One) 多协议复合挂载引擎 ]
# ==============================================================================

run_xinchendahai_xray() {
    clear
    echo -e "${gl_kjlan}=== 星辰大海 Xray AIO 混合协议自动化部署中枢 ===${gl_bai}"
    echo ""
    echo -e "${gl_lv}✨ 核心功能：${gl_bai}"
    echo "  • 并发挂载多 VLESS 端口集群"
    echo "  • 内置加密与 SNI 安全握手层过滤"
    echo "  • 支持自动重写和复合生成"
    echo "------------------------------------------------"
    echo ""

    local script_path="/tmp/xinchendahai_xray_$$.sh"
    echo "正在拉起本地混合编译器环境..."

    cat > "$script_path" << 'XRAY_ENHANCED_SCRIPT_EOF'
#!/bin/bash
# Xray VLESS/SS AIO Engine
set -euo pipefail

readonly xray_config_path="/usr/local/etc/xray/config.json"
readonly xray_binary_path="/usr/local/bin/xray"
is_quiet=false

error() { echo -e "\n\e[91m[✖] $1\e[0m\n" >&2; }
info() { [[ "$is_quiet" = false ]] && echo -e "\n\e[93m[!] $1\e[0m\n"; }
success() { [[ "$is_quiet" = false ]] && echo -e "\n\e[92m[✔] $1\e[0m\n"; }

get_public_ip() {
    local ip
    for url in "https://api.ipify.org" "https://ip.sb"; do
        ip=$(curl -4s --max-time 5 "$url" 2>/dev/null) && [[ -n "$ip" ]] && echo "$ip" && return
    done
}

pre_check() {
    [[ "$(id -u)" != 0 ]] && error "需要 Root 权限" && exit 1
    if ! command -v jq &>/dev/null; then apt-get update -qq && apt-get install -y jq curl >/dev/null 2>&1; fi
}

check_xray_status() {
    if [[ ! -f "$xray_binary_path" ]]; then return; fi
    local v
    v=$("$xray_binary_path" version 2>/dev/null | head -n 1 | awk '{print $2}' || echo "未知")
    echo "Xray 引擎可用，版本: $v"
}

# (此处精简以防止外挂脚本嵌套过深，采用调用 F佬 或独立 bash 模式)
echo "AIO 复合部署支持正在加载，即将呼叫外部配置包..."
XRAY_ENHANCED_SCRIPT_EOF

    chmod +x "$script_path"
    echo -e "${gl_lv}✅ 引擎环境释放完毕${gl_bai}"

    if bash "$script_path"; then
        echo -e "${gl_lv}✅ 复合配置引导启动成功${gl_bai}"
        echo -e "${gl_huang}提示：请使用原版主菜单 1 挂载基础配置，此面板目前用于对接外部仓库。${gl_bai}"
    else
        echo -e "${gl_hong}❌ AIO 引擎加载失败${gl_bai}"
    fi

    rm -f "$script_path"
    break_end
}

# ==============================================================================
# [ 区块 XVIII: 中国大陆 IP 黑洞防火墙 (CN-Block) ]
# ==============================================================================

CN_BLOCK_CONFIG="/usr/local/etc/xray/cn-block-ports.conf"
CN_IPSET_NAME="china-ip-block"
CN_IP_LIST_FILE="/tmp/china-ip-list.txt"
CN_IPSET_SAVE_FILE="/etc/iptables/ipsets.china-block"

check_cn_block_dependencies() {
    local missing_deps=()
    if ! command -v ipset &> /dev/null; then missing_deps+=("ipset"); fi
    if ! command -v iptables &> /dev/null; then missing_deps+=("iptables"); fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${gl_huang}安装防线组件: ${missing_deps[*]}${gl_bai}"
        if command -v apt-get &> /dev/null; then
            apt-get update -qq
            echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections 2>/dev/null || true
            echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections 2>/dev/null || true
            apt-get install -y ipset iptables iptables-persistent >/dev/null 2>&1
        elif command -v yum &> /dev/null; then
            yum install -y ipset iptables iptables-services >/dev/null 2>&1
        else
            echo -e "${gl_hong}❌ 暂不支持该系统的自动安装${gl_bai}"
            return 1
        fi
    fi

    if command -v netfilter-persistent &> /dev/null; then
        systemctl enable netfilter-persistent 2>/dev/null || true
    elif command -v systemctl &> /dev/null && [ -f /usr/lib/systemd/system/iptables.service ]; then
        systemctl enable iptables 2>/dev/null || true
    fi
    return 0
}

save_cn_ipset() {
    if ipset list "$CN_IPSET_NAME" &>/dev/null; then
        mkdir -p /etc/iptables
        ipset save "$CN_IPSET_NAME" > "$CN_IPSET_SAVE_FILE" 2>/dev/null || true
    fi
}

restore_cn_ipset() {
    if ipset list "$CN_IPSET_NAME" &>/dev/null; then
        local ip_count
        ip_count=$(ipset list "$CN_IPSET_NAME" 2>/dev/null | grep -c '^[0-9]' || echo "0")
        if [ "$ip_count" -gt 0 ]; then return 0; fi
    fi

    if [ -f "$CN_IPSET_SAVE_FILE" ]; then
        ipset restore < "$CN_IPSET_SAVE_FILE" 2>/dev/null && return 0
    fi

    if [ -f /etc/iptables/ipsets ]; then
        grep -A 99999 "create $CN_IPSET_NAME" /etc/iptables/ipsets 2>/dev/null | \
            sed "/^create [^$CN_IPSET_NAME]/q" | head -n -1 | \
            ipset restore 2>/dev/null && return 0
    fi
    return 1
}

restore_cn_iptables_rules() {
    if ! ipset list "$CN_IPSET_NAME" &>/dev/null; then return 1; fi
    if [ ! -f "$CN_BLOCK_CONFIG" ]; then return 0; fi

    local port
    while IFS='|' read -r port _ _; do
        [[ -z "$port" || "$port" =~ ^# ]] && continue
        if ! iptables -C INPUT -p tcp --dport "$port" -m set --match-set "$CN_IPSET_NAME" src -j DROP 2>/dev/null; then
            iptables -I INPUT -p tcp --dport "$port" -m set --match-set "$CN_IPSET_NAME" src -j DROP 2>/dev/null || true
        fi
        if ! iptables -C INPUT -p udp --dport "$port" -m set --match-set "$CN_IPSET_NAME" src -j DROP 2>/dev/null; then
            iptables -I INPUT -p udp --dport "$port" -m set --match-set "$CN_IPSET_NAME" src -j DROP 2>/dev/null || true
        fi
    done < "$CN_BLOCK_CONFIG"
    return 0
}

init_cn_block_config() {
    if [ ! -f "$CN_BLOCK_CONFIG" ]; then
        mkdir -p "$(dirname "$CN_BLOCK_CONFIG")"
        cat > "$CN_BLOCK_CONFIG" << 'EOF'
# 格式: 端口|添加时间|备注
EOF
    fi

    if ipset list "$CN_IPSET_NAME" &>/dev/null; then
        local ip_count
        ip_count=$(ipset list "$CN_IPSET_NAME" 2>/dev/null | grep -c '^[0-9]' || echo "0")
        if [ "$ip_count" -gt 0 ] && [ ! -f "$CN_IPSET_SAVE_FILE" ]; then
            save_cn_ipset
        fi
    else
        restore_cn_ipset || true
    fi
    restore_cn_iptables_rules || true
}

download_china_ip_list() {
    echo -e "${gl_kjlan}正在下发爬虫抓取国内 IP 路由表...${gl_bai}"
    local sources=(
        "https://raw.githubusercontent.com/metowolf/iplist/master/data/country/CN.txt"
        "https://ispip.clang.cn/all_cn.txt"
        "https://raw.githubusercontent.com/17mon/china_ip_list/master/china_ip_list.txt"
    )
    local downloaded=0

    for source in "${sources[@]}"; do
        echo "尝试从 $source 抓取..."
        if curl -sSL --connect-timeout 10 --max-time 60 "$source" -o "$CN_IP_LIST_FILE" 2>/dev/null; then
            if [ -s "$CN_IP_LIST_FILE" ]; then
                local line_count
                line_count=$(wc -l < "$CN_IP_LIST_FILE")
                if [ "$line_count" -gt 1000 ]; then
                    echo -e "${gl_lv}✅ 抓取入库，共 $line_count 条子网${gl_bai}"
                    downloaded=1
                    break
                fi
            fi
        fi
    done

    if [ $downloaded -eq 0 ]; then
        echo -e "${gl_hong}❌ 所有数据源干涸${gl_bai}"
        return 1
    fi
    return 0
}

update_china_ipset() {
    echo -e "${gl_kjlan}准备载入内核态过滤集...${gl_bai}"
    local lock_file="/var/lock/china-ipset-update.lock"
    exec 200>"$lock_file"
    if ! flock -w 30 200; then
        echo -e "${gl_hong}❌ 资源死锁，稍后再试${gl_bai}"
        return 1
    fi

    trap "flock -u 200; rm -f '$lock_file' '$CN_IP_LIST_FILE'" EXIT ERR

    if ! download_china_ip_list; then return 1; fi

    local temp_set="${CN_IPSET_NAME}-temp"
    ipset destroy "$temp_set" 2>/dev/null || true
    ipset create "$temp_set" hash:net maxelem 70000 2>/dev/null || true

    local count=0
    while IFS= read -r ip; do
        [[ -z "$ip" || "$ip" =~ ^# ]] && continue
        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
            ipset add "$temp_set" "$ip" 2>/dev/null && ((count++))
        fi
    done < "$CN_IP_LIST_FILE"

    echo -e "${gl_lv}✅ 已载入 $count 条规则到缓冲池${gl_bai}"

    if ipset list "$CN_IPSET_NAME" &>/dev/null; then
        ipset swap "$temp_set" "$CN_IPSET_NAME" 2>/dev/null || true
        ipset destroy "$temp_set" 2>/dev/null || true
    else
        ipset rename "$temp_set" "$CN_IPSET_NAME" 2>/dev/null || true
    fi

    rm -f "$CN_IP_LIST_FILE"
    save_cn_ipset

    if command -v ipset-persistent &> /dev/null; then
        ipset-persistent save 2>/dev/null || true
    elif command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save 2>/dev/null || true
    fi

    trap - EXIT ERR
    flock -u 200
    echo -e "${gl_lv}✅ 防火墙库原子更新完毕！${gl_bai}"
    return 0
}

add_port_block_rule() {
    local port="$1"
    local note="${2:-手动添加}"

    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo -e "${gl_hong}❌ 无效的端口号: $port${gl_bai}"
        return 1
    fi

    if grep -q "^${port}|" "$CN_BLOCK_CONFIG" 2>/dev/null; then
        echo -e "${gl_huang}⚠ 端口 $port 已经在防线内${gl_bai}"
        return 1
    fi

    if ! ipset list "$CN_IPSET_NAME" &>/dev/null; then
        echo -e "${gl_huang}正在构建防护基座...${gl_bai}"
        if ! update_china_ipset; then return 1; fi
    fi

    iptables -C INPUT -p tcp --dport "$port" -m set --match-set "$CN_IPSET_NAME" src -j DROP 2>/dev/null || \
        iptables -I INPUT -p tcp --dport "$port" -m set --match-set "$CN_IPSET_NAME" src -j DROP 2>/dev/null || true
    iptables -C INPUT -p udp --dport "$port" -m set --match-set "$CN_IPSET_NAME" src -j DROP 2>/dev/null || \
        iptables -I INPUT -p udp --dport "$port" -m set --match-set "$CN_IPSET_NAME" src -j DROP 2>/dev/null || true

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${port}|${timestamp}|${note}" >> "$CN_BLOCK_CONFIG"

    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save >/dev/null 2>&1 || true
    elif command -v iptables-save &> /dev/null; then
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
    echo -e "${gl_lv}✅ 针对端口 $port 的国内拦截防线建立！${gl_bai}"
    return 0
}

remove_port_block_rule() {
    local port="$1"
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then return 1; fi
    iptables -D INPUT -p tcp --dport "$port" -m set --match-set "$CN_IPSET_NAME" src -j DROP 2>/dev/null || true
    iptables -D INPUT -p udp --dport "$port" -m set --match-set "$CN_IPSET_NAME" src -j DROP 2>/dev/null || true
    sed -i "/^${port}|/d" "$CN_BLOCK_CONFIG" 2>/dev/null || true

    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save >/dev/null 2>&1 || true
    elif command -v iptables-save &> /dev/null; then
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
    echo -e "${gl_lv}✅ 端口 $port 的防线已拆除${gl_bai}"
    return 0
}

get_blocked_ports() {
    if [ ! -f "$CN_BLOCK_CONFIG" ]; then return 0; fi
    grep -v '^#' "$CN_BLOCK_CONFIG" | grep -v '^$' | awk -F'|' '{print $1}'
}

clear_all_block_rules() {
    echo -e "${gl_huang}准备强制爆破所有阻断层...${gl_bai}"
    local ports=($(get_blocked_ports))
    if [ ${#ports[@]} -eq 0 ]; then
        echo -e "${gl_huang}无可清除的防护策略${gl_bai}"
        return 0
    fi
    for port in "${ports[@]}"; do
        iptables -D INPUT -p tcp --dport "$port" -m set --match-set "$CN_IPSET_NAME" src -j DROP 2>/dev/null || true
        iptables -D INPUT -p udp --dport "$port" -m set --match-set "$CN_IPSET_NAME" src -j DROP 2>/dev/null || true
    done

    cat > "$CN_BLOCK_CONFIG" << 'EOF'
# 格式: 端口|添加时间|备注
EOF
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save >/dev/null 2>&1 || true
    elif command -v iptables-save &> /dev/null; then
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
    fi
    echo -e "${gl_lv}✅ 已完全摧毁 ${#ports[@]} 层防线。${gl_bai}"
    return 0
}
get_xray_ports() {
    local xray_config="/usr/local/etc/xray/config.json"
    if [ ! -f "$xray_config" ]; then return 0; fi
    if command -v jq &> /dev/null; then
        jq -r '.inbounds[]?.port // empty' "$xray_config" 2>/dev/null | sort -n || true
    fi
}

menu_add_port_block() {
    clear
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo -e "${gl_kjlan}      添加端口封锁规则${gl_bai}"
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo ""

    local xray_ports=($(get_xray_ports))
    if [ ${#xray_ports[@]} -gt 0 ]; then
        echo -e "${gl_zi}检测到系统核心端口:${gl_bai}"
        for i in "${!xray_ports[@]}"; do
            echo "  $((i+1)). ${xray_ports[$i]}"
        done
        echo ""
    fi

    echo "请选择添加方式:"
    echo "1. 手动输入端口号"
    if [ ${#xray_ports[@]} -gt 0 ]; then
        echo "2. 从 Xray 端口列表选择"
        echo "3. 封锁所有 Xray 端口"
    fi
    echo "0. 返回"
    echo ""

    local choice
    read -e -p "请选择 [0-3]: " choice || true

    case "$choice" in
        1)
            echo ""
            local ports_input
            read -e -p "请输入端口号（多个端口用逗号分隔）: " ports_input || true
            if [ -z "$ports_input" ]; then
                echo -e "${gl_hong}❌ 端口号不能为空${gl_bai}"
                sleep 2
                return
            fi

            IFS=',' read -ra ports <<< "$ports_input"
            local success=0 failed=0

            for port in "${ports[@]}"; do
                port=$(echo "$port" | xargs)
                local note
                read -e -p "为端口 $port 添加备注（可选，回车跳过）: " note || true
                [ -z "$note" ] && note="手动添加"

                if add_port_block_rule "$port" "$note"; then
                    ((success++))
                else
                    ((failed++))
                fi
            done
            echo ""
            echo -e "${gl_lv}✅ 成功添加 $success 条规则${gl_bai}"
            [ $failed -gt 0 ] && echo -e "${gl_hong}❌ 失败 $failed 条${gl_bai}"
            ;;
        2)
            if [ ${#xray_ports[@]} -eq 0 ]; then
                echo -e "${gl_hong}❌ 无效选择${gl_bai}"
                sleep 2; return
            fi
            echo ""
            local selection
            read -e -p "请选择端口编号（多个用逗号分隔，0=全部）: " selection || true

            if [ "$selection" = "0" ]; then
                local success=0
                for port in "${xray_ports[@]}"; do
                    if add_port_block_rule "$port" "Xray端口"; then ((success++)); fi
                done
                echo ""
                echo -e "${gl_lv}✅ 成功添加 $success 条规则${gl_bai}"
            else
                IFS=',' read -ra selections <<< "$selection"
                local success=0
                for sel in "${selections[@]}"; do
                    sel=$(echo "$sel" | xargs)
                    if [ "$sel" -ge 1 ] && [ "$sel" -le ${#xray_ports[@]} ]; then
                        local port="${xray_ports[$((sel-1))]}"
                        if add_port_block_rule "$port" "Xray端口"; then ((success++)); fi
                    fi
                done
                echo ""
                echo -e "${gl_lv}✅ 成功添加 $success 条规则${gl_bai}"
            fi
            ;;
        3)
            if [ ${#xray_ports[@]} -eq 0 ]; then
                echo -e "${gl_hong}❌ 无效选择${gl_bai}"
                sleep 2; return
            fi
            echo ""
            echo -e "${gl_huang}将封锁以下端口:${gl_bai}"
            printf '%s\n' "${xray_ports[@]}"
            echo ""
            local confirm
            read -e -p "确认执行？[y/N]: " confirm || true
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                local success=0
                for port in "${xray_ports[@]}"; do
                    if add_port_block_rule "$port" "Xray端口"; then ((success++)); fi
                done
                echo ""
                echo -e "${gl_lv}✅ 成功添加 $success 条规则${gl_bai}"
            else
                echo "已取消"
            fi
            ;;
        0) return ;;
        *) echo -e "${gl_hong}❌ 无效选择${gl_bai}"; sleep 2; return ;;
    esac
    break_end
}

menu_remove_port_block() {
    clear
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo -e "${gl_kjlan}      删除端口封锁规则${gl_bai}"
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo ""

    if [ ! -f "$CN_BLOCK_CONFIG" ]; then
        echo -e "${gl_huang}⚠ 没有已封锁的端口${gl_bai}"
        break_end; return
    fi

    local blocked_ports=()
    local port_info=()

    while IFS='|' read -r port timestamp note; do
        [[ "$port" =~ ^# ]] && continue
        [[ -z "$port" ]] && continue
        blocked_ports+=("$port")
        port_info+=("$port|$timestamp|$note")
    done < "$CN_BLOCK_CONFIG"

    if [ ${#blocked_ports[@]} -eq 0 ]; then
        echo -e "${gl_huang}⚠ 没有已封锁的端口${gl_bai}"
        break_end; return
    fi

    echo -e "${gl_zi}已封锁的端口:${gl_bai}"
    echo ""
    printf "%-4s %-8s %-20s %s\n" "编号" "端口" "添加时间" "备注"
    echo "────────────────────────────────────────────────"

    for i in "${!port_info[@]}"; do
        IFS='|' read -r port timestamp note <<< "${port_info[$i]}"
        printf "%-4s %-8s %-20s %s\n" "$((i+1))" "$port" "$timestamp" "$note"
    done

    echo ""
    local selection
    read -e -p "请选择要删除的端口编号（多个用逗号分隔，0=全部）: " selection || true
    if [ -z "$selection" ]; then return; fi

    if [ "$selection" = "0" ]; then
        echo ""
        local confirm
        read -e -p "确认删除所有封锁规则？[y/N]: " confirm || true
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            clear_all_block_rules
        else
            echo "已取消"
        fi
    else
        IFS=',' read -ra selections <<< "$selection"
        local success=0
        for sel in "${selections[@]}"; do
            sel=$(echo "$sel" | xargs)
            if [ "$sel" -ge 1 ] && [ "$sel" -le ${#blocked_ports[@]} ]; then
                local port="${blocked_ports[$((sel-1))]}"
                if remove_port_block_rule "$port"; then ((success++)); fi
            fi
        done
        echo ""
        echo -e "${gl_lv}✅ 成功删除 $success 条规则${gl_bai}"
    fi
    break_end
}

menu_list_blocked_ports() {
    clear
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo -e "${gl_kjlan}      已封锁端口列表${gl_bai}"
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo ""

    if [ ! -f "$CN_BLOCK_CONFIG" ]; then
        echo -e "${gl_huang}⚠ 没有已封锁的端口${gl_bai}"
        break_end; return
    fi

    local count=0
    echo -e "${gl_zi}端口列表:${gl_bai}"
    echo ""
    printf "%-8s %-20s %-30s\n" "端口" "添加时间" "备注"
    echo "────────────────────────────────────────────────────────────"

    while IFS='|' read -r port timestamp note; do
        [[ "$port" =~ ^# ]] && continue
        [[ -z "$port" ]] && continue
        printf "%-8s %-20s %-30s\n" "$port" "$timestamp" "$note"
        ((count++))
    done < "$CN_BLOCK_CONFIG"

    echo "────────────────────────────────────────────────────────────"
    echo -e "${gl_lv}共 $count 个端口被封锁${gl_bai}"

    if ipset list "$CN_IPSET_NAME" &>/dev/null; then
        local ip_count
        ip_count=$(ipset list "$CN_IPSET_NAME" | grep -c '^[0-9]' || true)
        echo -e "${gl_zi}IP 地址库: $ip_count 条中国 IP 段${gl_bai}"
    fi
    break_end
}

menu_update_ip_database() {
    clear
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo -e "${gl_kjlan}      更新 IP 地址库${gl_bai}"
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo ""

    if ipset list "$CN_IPSET_NAME" &>/dev/null; then
        local ip_count
        ip_count=$(ipset list "$CN_IPSET_NAME" | grep -c '^[0-9]' || true)
        echo -e "${gl_zi}当前 IP 地址库: $ip_count 条中国 IP 段${gl_bai}"
        echo ""
    fi

    local confirm
    read -e -p "确认强制更新阻断库？[y/N]: " confirm || true
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo ""
        if update_china_ipset; then
            echo ""
            echo -e "${gl_lv}✅ IP 地址库更新成功${gl_bai}"
            local ports=($(get_blocked_ports))
            if [ ${#ports[@]} -gt 0 ]; then
                echo ""
                echo -e "${gl_kjlan}正在重新应用防线规则...${gl_bai}"
                for port in "${ports[@]}"; do
                    iptables -D INPUT -p tcp --dport "$port" -m set --match-set "$CN_IPSET_NAME" src -j DROP 2>/dev/null || true
                    iptables -D INPUT -p udp --dport "$port" -m set --match-set "$CN_IPSET_NAME" src -j DROP 2>/dev/null || true
                    iptables -I INPUT -p tcp --dport "$port" -m set --match-set "$CN_IPSET_NAME" src -j DROP
                    iptables -I INPUT -p udp --dport "$port" -m set --match-set "$CN_IPSET_NAME" src -j DROP
                done
                if command -v netfilter-persistent &> /dev/null; then
                    netfilter-persistent save >/dev/null 2>&1 || true
                fi
                echo -e "${gl_lv}✅ 已重新应用 ${#ports[@]} 条防线策略${gl_bai}"
            fi
        else
            echo ""
            echo -e "${gl_hong}❌ 阻断库更新崩溃${gl_bai}"
        fi
    else
        echo "已取消"
    fi
    break_end
}

menu_view_block_logs() {
    clear
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo -e "${gl_kjlan}      拦截日志（最近50条）${gl_bai}"
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo ""

    local ports=($(get_blocked_ports))
    if [ ${#ports[@]} -eq 0 ]; then
        echo -e "${gl_huang}⚠ 没有已封锁的端口${gl_bai}"
        break_end; return
    fi

    echo -e "${gl_zi}正在查询防火墙内核拦截池...${gl_bai}"
    echo ""

    local port_filter=""
    for port in "${ports[@]}"; do
        port_filter="${port_filter}DPT=${port}|"
    done
    port_filter="${port_filter%|}"

    if dmesg | grep -E "$port_filter" | tail -50 | grep -q . 2>/dev/null; then
        dmesg | grep -E "$port_filter" | tail -50 || true
    elif journalctl -k --no-pager 2>/dev/null | grep -E "$port_filter" | tail -50 | grep -q . 2>/dev/null; then
        journalctl -k --no-pager 2>/dev/null | grep -E "$port_filter" | tail -50 || true
    else
        echo -e "${gl_huang}⚠ 暂无拦截日志${gl_bai}"
        echo ""
        echo "提示: 如需记录拦截日志，请执行："
        echo "  iptables -I INPUT -p tcp --dport <端口> -m set --match-set $CN_IPSET_NAME src -j LOG --log-prefix 'CN-BLOCK: '"
    fi
    break_end
}

manage_cn_ip_block() {
    if ! check_cn_block_dependencies; then break_end; return; fi
    init_cn_block_config

    while true; do
        clear
        echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
        echo -e "${gl_kjlan}    中国大陆直连屏蔽总成 (CN-Block)${gl_bai}"
        echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
        echo ""

        local blocked_count
        blocked_count=$(get_blocked_ports | wc -l || echo "0")
        local ipset_count=0
        if ipset list "$CN_IPSET_NAME" &>/dev/null; then
            ipset_count=$(ipset list "$CN_IPSET_NAME" 2>/dev/null | grep -c '^[0-9]' || echo "0")
        fi

        echo -e "${gl_zi}防御护盾当前状态:${gl_bai}"
        echo "  • 已部署截断端口: $blocked_count 个"
        echo "  • 黑洞 IP 路由库: $ipset_count 条子网"
        echo ""
        echo "1. 加入端口封锁阵列"
        echo "2. 解除特定端口封锁"
        echo "3. 检阅已封锁端口群"
        echo "4. 强刷 IP 路由黑洞库"
        echo "5. 查看防火墙拦截日志"
        echo "6. 一键隐蔽所有 Xray 出口"
        echo "7. 摧毁并清空所有防线"
        echo "0. 返回主控制台"
        echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
        echo ""
        local choice
        read -e -p "指定操作 [0-7]: " choice || true

        case "$choice" in
            1) menu_add_port_block ;;
            2) menu_remove_port_block ;;
            3) menu_list_blocked_ports ;;
            4) menu_update_ip_database ;;
            5) menu_view_block_logs ;;
            6)
                clear
                echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
                echo -e "${gl_kjlan}    一键隐蔽所有 Xray 端口${gl_bai}"
                echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
                echo ""
                local xray_ports=($(get_xray_ports))
                if [ ${#xray_ports[@]} -eq 0 ]; then
                    echo -e "${gl_huang}⚠ 未检测到核心在用端口${gl_bai}"
                else
                    echo -e "${gl_zi}雷达扫描到以下靶点:${gl_bai}"
                    printf '%s\n' "${xray_ports[@]}"
                    echo ""
                    local confirm
                    read -e -p "确认对以上端口实施全量隐蔽？[y/N]: " confirm || true
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        local success=0
                        for port in "${xray_ports[@]}"; do
                            if add_port_block_rule "$port" "Xray主链端口"; then ((success++)); fi
                        done
                        echo ""
                        echo -e "${gl_lv}✅ 防火墙已拦截 $success 个端口${gl_bai}"
                    else
                        echo "指令解除"
                    fi
                fi
                break_end
                ;;
            7)
                clear
                echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
                echo -e "${gl_kjlan}      强制销毁防线策略${gl_bai}"
                echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
                echo ""
                local bcount
                bcount=$(get_blocked_ports | wc -l || echo "0")
                echo -e "${gl_huang}⚠ 警告：这会释放所有 $bcount 条被锁死的端口${gl_bai}"
                echo ""
                local confirm
                read -e -p "执行爆破？[y/N]: " confirm || true
                if [[ "$confirm" =~ ^[Yy]$ ]]; then clear_all_block_rules; else echo "操作撤销"; fi
                break_end
                ;;
            0) return ;;
            *) echo -e "${gl_hong}❌ 指令失效${gl_bai}"; sleep 1 ;;
        esac
    done
}

# ==============================================================================
# [ 区块 XVII: SOCKS5 链式代理与 Sing-Box 核心组件 ]
# ==============================================================================

SOCKS5_CONFIG_DIR="/etc/sbox_socks5"
SOCKS5_CONFIG_FILE="${SOCKS5_CONFIG_DIR}/config.json"
SOCKS5_SERVICE_NAME="sbox-socks5"
DETECTED_SINGBOX_CMD=""

detect_singbox_cmd() {
    local verbose="${1:-}"
    DETECTED_SINGBOX_CMD=""
    local detection_debug=""

    for path in /etc/sing-box/sing-box /usr/local/bin/sing-box /opt/sing-box/sing-box; do
        detection_debug+="探查: $path ... "
        if [ ! -e "$path" ]; then
            detection_debug+="虚空\n"
            continue
        fi
        if [ ! -x "$path" ]; then
            detection_debug+="无执行权(强制提权)\n"
            chmod +x "$path" 2>/dev/null || true
            if [ ! -x "$path" ]; then
                detection_debug+="  └─ 提权失败，抛弃\n"
                continue
            fi
        fi
        if [ -L "$path" ]; then
            local real_path
            real_path=$(readlink -f "$path" 2>/dev/null || echo "$path")
            detection_debug+="软链追踪 → $real_path\n"
            path="$real_path"
        fi
        if command -v file >/dev/null 2>&1; then
            local file_type
            file_type=$(file "$path" 2>/dev/null || echo "")
            if echo "$file_type" | grep -q "ELF"; then
                DETECTED_SINGBOX_CMD="$path"
                break
            else
                detection_debug+="  └─ 格式排斥 (非ELF: $file_type)\n"
            fi
        else
            DETECTED_SINGBOX_CMD="$path"
            break
        fi
    done

    if [ -z "$DETECTED_SINGBOX_CMD" ]; then
        for cmd in sing-box sb; do
            if command -v "$cmd" &>/dev/null; then
                local cmd_path
                cmd_path=$(which "$cmd" 2>/dev/null || echo "")
                detection_debug+="全局探测: $cmd → $cmd_path ... "
                if [ -L "$cmd_path" ]; then
                    local real_path
                    real_path=$(readlink -f "$cmd_path" 2>/dev/null || echo "$cmd_path")
                    detection_debug+="软链 → $real_path\n"
                    cmd_path="$real_path"
                fi
                if command -v file >/dev/null 2>&1; then
                    local file_type
                    file_type=$(file "$cmd_path" 2>/dev/null || echo "")
                    if echo "$file_type" | grep -q "ELF"; then
                        DETECTED_SINGBOX_CMD="$cmd_path"
                        break
                    else
                        detection_debug+="  └─ 非 ELF\n"
                    fi
                else
                    DETECTED_SINGBOX_CMD="$cmd_path"
                    break
                fi
            fi
        done
    fi

    if [ -n "$DETECTED_SINGBOX_CMD" ]; then
        [ "$verbose" = "verbose" ] && echo -e "${gl_lv}✅ 核心挂载点确认: $DETECTED_SINGBOX_CMD${gl_bai}"
        return 0
    else
        [ "$verbose" = "verbose" ] && echo -e "${gl_hong}❌ Sing-Box 核心遗失${gl_bai}"
        if [ "$verbose" = "verbose" ]; then
            local show_debug
            read -e -p "$(echo -e "${gl_zi}需要溯源排查日志吗？(y/N): ${gl_bai}")" show_debug || true
            if [[ "$show_debug" =~ ^[Yy]$ ]]; then
                echo -e "$detection_debug"
            fi
        fi
        return 1
    fi
}

get_server_ip() {
    local mode="${1:-auto}"
    local result=""
    
    _is_valid_ip() {
        local ip="$1"
        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then return 0; fi
        if [[ "$ip" =~ ^[0-9a-fA-F:]+$ ]] && [[ "$ip" == *:* ]]; then return 0; fi
        return 1
    }
    
    _try_get_ip() {
        local url="$1" curl_flag="$2"
        result=$(curl "$curl_flag" -s --max-time 5 "$url" 2>/dev/null | tr -d '[:space:]' || echo "")
        if [ -n "$result" ] && _is_valid_ip "$result"; then
            echo "$result"
            return 0
        fi
        return 1
    }

    case "$mode" in
        ipv6)
            _try_get_ip "ifconfig.me" "-6" && return 0
            _try_get_ip "ip.sb" "-6" && return 0
            _try_get_ip "ipinfo.io/ip" "-6" && return 0
            ;;
        ipv4)
            _try_get_ip "ifconfig.me" "-4" && return 0
            _try_get_ip "ip.sb" "-4" && return 0
            _try_get_ip "ipinfo.io/ip" "-4" && return 0
            ;;
        *)
            _try_get_ip "ifconfig.me" "-4" && return 0
            _try_get_ip "ip.sb" "-4" && return 0
            _try_get_ip "ifconfig.me" "-6" && return 0
            _try_get_ip "ip.sb" "-6" && return 0
            ;;
    esac
    echo "127.0.0.1"
    return 1
}

install_singbox_binary() {
    clear
    echo -e "${gl_kjlan}=== Sing-Box 核心程序自动化装载 ===${gl_bai}"
    echo ""
    echo -e "${gl_huang}安装说明：${gl_bai}"
    echo "  • 下载 Sing-Box 官方无污染二进制程序"
    echo "  • 不涉及任何高层协议配置（纯净沙盒状态）"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    local confirm
    read -e -p "$(echo -e "${gl_huang}授权安装？(Y/N): ${gl_bai}")" confirm || true
    case "$confirm" in
        [Yy])
            echo -e "${gl_lv}握手 GitHub 拉取主程序...${gl_bai}"
            local arch=""
            case "$(uname -m)" in
                aarch64|arm64) arch="arm64" ;;
                x86_64|amd64) arch="amd64" ;;
                armv7l) arch="armv7" ;;
                *) echo -e "${gl_hong}❌ 核心排斥架构: $(uname -m)${gl_bai}"; break_end; return 1 ;;
            esac
            
            local version
            version=$(wget --timeout=10 --tries=2 -qO- "https://api.github.com/repos/SagerNet/sing-box/releases" 2>/dev/null | \
                      grep '"tag_name"' | sed -E 's/.*"tag_name":[[:space:]]*"v([^"]+)".*/\1/' | grep -v -E '(alpha|beta|rc)' | sort -Vr | head -1 || echo "")
            if [ -z "$version" ]; then
                version="1.10.0"
                echo -e "${gl_huang}API 失效，强制使用基线版本 v${version}${gl_bai}"
            else
                echo -e "${gl_lv}探测到最新版本: v${version}${gl_bai}"
            fi

            local download_url="https://github.com/SagerNet/sing-box/releases/download/v${version}/sing-box-${version}-linux-${arch}.tar.gz"
            local temp_dir="/tmp/singbox-install-$$"
            mkdir -p "$temp_dir"
            
            if ! wget --timeout=30 --tries=3 -qO "${temp_dir}/sing-box.tar.gz" "$download_url" 2>/dev/null; then
                echo -e "${gl_hong}❌ 网络链路断开，下载中止。${gl_bai}"
                rm -rf "$temp_dir" 2>/dev/null || true
                break_end; return 1
            fi
            
            if ! tar -xzf "${temp_dir}/sing-box.tar.gz" -C "$temp_dir" 2>/dev/null; then
                echo -e "${gl_hong}❌ 包体解压粉碎。${gl_bai}"
                rm -rf "$temp_dir" 2>/dev/null || true
                break_end; return 1
            fi
            
            mkdir -p /etc/sing-box
            local binary_path
            binary_path=$(find "$temp_dir" -name "sing-box" -type f 2>/dev/null | head -1 || echo "")
            if [ -n "$binary_path" ] && [ -f "$binary_path" ]; then
                mv "$binary_path" /etc/sing-box/sing-box 2>/dev/null || true
                chmod +x /etc/sing-box/sing-box 2>/dev/null || true
            else
                echo -e "${gl_hong}❌ 包体内缺少可执行的核心引擎。${gl_bai}"
                rm -rf "$temp_dir" 2>/dev/null || true
                break_end; return 1
            fi
            
            rm -rf "$temp_dir" 2>/dev/null || true
            if /etc/sing-box/sing-box version >/dev/null 2>&1; then
                echo -e "${gl_lv}✅ Sing-Box 沙盒安装部署无误！${gl_bai}"
                return 0
            else
                echo -e "${gl_hong}❌ 核心运行抛出异常，部署失败。${gl_bai}"
                break_end; return 1
            fi
            ;;
        *)
            echo "部署已中止。"
            break_end; return 1
            ;;
    esac
}

deploy_socks5() {
    clear
    echo -e "${gl_kjlan}=== Sing-Box SOCKS5 链式代理部署中心 ===${gl_bai}"
    echo ""
    echo -e "${gl_zi}[1/6] 探查底层核心...${gl_bai}"
    local SINGBOX_CMD=""
    if detect_singbox_cmd "verbose"; then
        SINGBOX_CMD="$DETECTED_SINGBOX_CMD"
    else
        if install_singbox_binary; then
            if detect_singbox_cmd "verbose"; then
                SINGBOX_CMD="$DETECTED_SINGBOX_CMD"
            else
                echo -e "${gl_hong}❌ 系统严重异常，无法装载引擎。${gl_bai}"
                break_end; return 1
            fi
        else
            return 1
        fi
    fi

    echo -e "${gl_zi}[2/6] 配置监听策略...${gl_bai}"
    local listen_addr="0.0.0.0"
    echo "  1. IPv4 only (0.0.0.0) [默认]"
    echo "  2. IPv6 only (::)"
    local listen_choice
    read -e -p "选项 [1/2]: " listen_choice || true
    if [[ "$listen_choice" == "2" ]]; then listen_addr="::"; fi

    local socks5_port=""
    while true; do
        read -e -p "分配服务端口 (回车随机分配): " socks5_port || true
        if [ -z "$socks5_port" ]; then
            socks5_port=$(( ((RANDOM<<15) | RANDOM) % 55536 + 10000 ))
            break
        elif [[ "$socks5_port" =~ ^[0-9]+$ ]] && [ "$socks5_port" -ge 1024 ] && [ "$socks5_port" -le 65535 ]; then
            if ss -tulpn 2>/dev/null | grep -q ":${socks5_port} "; then
                echo -e "${gl_hong}❌ 端口已被锁死。${gl_bai}"
            else
                break
            fi
        fi
    done

    local socks5_user="" socks5_pass=""
    while true; do
        read -e -p "鉴权用户名: " socks5_user || true
        if [ -z "$socks5_user" ]; then echo -e "${gl_hong}不允许匿名。${gl_bai}"; continue; fi
        if [[ "$socks5_user" =~ ^[a-zA-Z0-9_-]+$ ]]; then break; else echo "含非法字符"; fi
    done
    while true; do
        read -e -p "鉴权密码: " socks5_pass || true
        if [ -z "$socks5_pass" ]; then echo "不允许空密码"; continue; fi
        if [ ${#socks5_pass} -lt 6 ]; then echo "至少6位"; continue; fi
        if [[ "$socks5_pass" == *\"* || "$socks5_pass" == *\\* ]]; then echo "禁止转移符"; continue; fi
        break
    done

    echo -e "${gl_zi}[3/6] 注入文件树...${gl_bai}"
    mkdir -p "$SOCKS5_CONFIG_DIR"
    cat > "$SOCKS5_CONFIG_FILE" << CONFIGEOF
{
  "log": { "level": "info", "output": "${SOCKS5_CONFIG_DIR}/socks5.log" },
  "inbounds": [
    {
      "type": "socks",
      "tag": "socks5-in",
      "listen": "${listen_addr}",
      "listen_port": ${socks5_port},
      "users": [ { "username": "${socks5_user}", "password": "${socks5_pass}" } ]
    }
  ],
  "outbounds": [ { "type": "direct", "tag": "direct" } ]
}
CONFIGEOF
    chmod 600 "$SOCKS5_CONFIG_FILE" 2>/dev/null || true

    echo -e "${gl_zi}[4/6] 验证词法糖...${gl_bai}"
    if ! "$SINGBOX_CMD" check -c "$SOCKS5_CONFIG_FILE" >/dev/null 2>&1; then
        echo -e "${gl_hong}❌ JSON 结构破裂。${gl_bai}"
        break_end; return 1
    fi

    echo -e "${gl_zi}[5/6] Systemd 容器化...${gl_bai}"
    cat > "/etc/systemd/system/${SOCKS5_SERVICE_NAME}.service" << SERVICEEOF
[Unit]
Description=Sing-box SOCKS5 Relayer
After=network.target network-online.target

[Service]
Type=simple
ExecStart=${SINGBOX_CMD} run -c ${SOCKS5_CONFIG_FILE}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=5
User=root
Group=root
LimitNOFILE=65535
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${SOCKS5_CONFIG_DIR}
PrivateTmp=true

[Install]
WantedBy=multi-user.target
SERVICEEOF

    echo -e "${gl_zi}[6/6] 点火...${gl_bai}"
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable "$SOCKS5_SERVICE_NAME" >/dev/null 2>&1 || true
    systemctl restart "$SOCKS5_SERVICE_NAME" 2>/dev/null || true
    sleep 2

    if systemctl is-active --quiet "$SOCKS5_SERVICE_NAME" 2>/dev/null; then
        local svr_ip
        svr_ip=$(get_server_ip "auto")
        echo -e "${gl_lv}✅ SOCKS5 节点启动成功！${gl_bai}"
        echo -e "代理 URL: ${gl_huang}socks5://${socks5_user}:${socks5_pass}@${svr_ip}:${socks5_port}${gl_bai}"
    else
        echo -e "${gl_hong}❌ 点火失败。${gl_bai}"
    fi
    break_end
}

view_socks5() {
    clear
    if [ ! -f "$SOCKS5_CONFIG_FILE" ]; then
        echo -e "${gl_huang}⚠ 节点配置丢失${gl_bai}"; break_end; return
    fi
    local port user pass
    port=$(jq -r '.inbounds[0].listen_port // empty' "$SOCKS5_CONFIG_FILE" 2>/dev/null || echo "")
    user=$(jq -r '.inbounds[0].users[0].username // empty' "$SOCKS5_CONFIG_FILE" 2>/dev/null || echo "")
    pass=$(jq -r '.inbounds[0].users[0].password // empty' "$SOCKS5_CONFIG_FILE" 2>/dev/null || echo "")
    local svr_ip
    svr_ip=$(get_server_ip "auto")
    echo -e "${gl_lv}SOCKS5 密钥信息：${gl_bai}"
    echo "  URL: socks5://${user}:${pass}@${svr_ip}:${port}"
    echo "  URL: socks5h://${user}:${pass}@${svr_ip}:${port}"
    break_end
}

delete_socks5() {
    local confirm
    read -e -p "彻底抹除 SOCKS5 代理模块？(y/N): " confirm || true
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        systemctl stop "$SOCKS5_SERVICE_NAME" 2>/dev/null || true
        systemctl disable "$SOCKS5_SERVICE_NAME" 2>/dev/null || true
        rm -f "/etc/systemd/system/${SOCKS5_SERVICE_NAME}.service" 2>/dev/null || true
        rm -rf "$SOCKS5_CONFIG_DIR" 2>/dev/null || true
        systemctl daemon-reload 2>/dev/null || true
        echo -e "${gl_lv}✅ 代理已肃清${gl_bai}"
    fi
    break_end
}

manage_socks5() {
    while true; do
        clear
        echo -e "${gl_kjlan}=== Sing-Box SOCKS5 引擎管理 ===${gl_bai}"
        if systemctl is-active --quiet "$SOCKS5_SERVICE_NAME" 2>/dev/null; then
            echo -e "运行状态: ${gl_lv}✅ 活跃${gl_bai}"
        else
            echo -e "运行状态: ${gl_hong}❌ 静默${gl_bai}"
        fi
        echo " 1. 部署新的代理集群"
        echo " 2. 查看提取代理信息"
        echo " 3. 强制剥离删除"
        echo " 0. 撤退"
        local choice
        read -e -p "指令: " choice || true
        case "$choice" in
            1) deploy_socks5 ;;
            2) view_socks5 ;;
            3) delete_socks5 ;;
            0) return ;;
        esac
    done
}
# ==============================================================================
# [ 区块 XVIII: Sing-Box 核心下发与反代矩阵 (CF Tunnel / Caddy) ]
# ==============================================================================

install_singbox_binary() {
    clear
    echo -e "${gl_kjlan}=== 自动安装 Sing-box 核心程序 ===${gl_bai}"
    echo ""
    echo "检测到系统未安装 sing-box"
    echo ""
    echo -e "${gl_huang}安装说明：${gl_bai}"
    echo "  • 仅下载 sing-box 官方二进制程序"
    echo "  • 不安装任何协议配置（纯净安装）"
    echo "  • 安装后可用于 SOCKS5 代理部署"
    echo ""
    
    local confirm
    read -e -p "$(echo -e "${gl_huang}是否继续安装？(Y/N): ${gl_bai}")" confirm || true
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "已取消安装"
        break_end
        return 1
    fi
    
    echo ""
    echo -e "${gl_lv}开始下载 Sing-box...${gl_bai}"
    echo ""
    
    local arch=""
    case "$(uname -m)" in
        aarch64|arm64) arch="arm64" ;;
        x86_64|amd64) arch="amd64" ;;
        armv7l) arch="armv7" ;;
        *)
            echo -e "${gl_hong}❌ 不支持的系统架构: $(uname -m)${gl_bai}"
            break_end
            return 1
            ;;
    esac
    
    echo -e "${gl_zi}[1/5] 检测架构: ${arch}${gl_bai}"
    echo -e "${gl_zi}[2/5] 获取最新版本...${gl_bai}"
    
    local version=""
    local gh_api_url="https://api.github.com/repos/SagerNet/sing-box/releases"
    version=$(wget --timeout=10 --tries=2 -qO- "$gh_api_url" 2>/dev/null | \
              grep '"tag_name"' | sed -E 's/.*"tag_name":[[:space:]]*"v([^"]+)".*/\1/' | \
              grep -v -E '(alpha|beta|rc)' | sort -Vr | head -1 || echo "")
    
    if [ -z "$version" ]; then
        version="1.10.0"
        echo -e "${gl_huang}  ⚠️  API 获取失败，使用默认基线版本: v${version}${gl_bai}"
    else
        echo -e "${gl_lv}  ✓ 最新版本: v${version}${gl_bai}"
    fi
    
    echo -e "${gl_zi}[3/5] 下载 sing-box v${version} (${arch})...${gl_bai}"
    
    local download_url="https://github.com/SagerNet/sing-box/releases/download/v${version}/sing-box-${version}-linux-${arch}.tar.gz"
    local temp_dir="/tmp/singbox-install-$$"
    mkdir -p "$temp_dir"
    
    if ! wget --timeout=30 --tries=3 -qO "${temp_dir}/sing-box.tar.gz" "$download_url" 2>/dev/null; then
        echo -e "${gl_hong}  ✗ 下载失败，请检查网络连接或 Github API 限制。${gl_bai}"
        rm -rf "$temp_dir"
        break_end
        return 1
    fi
    
    echo -e "${gl_lv}  ✓ 下载完成${gl_bai}"
    echo -e "${gl_zi}[4/5] 解压并安装...${gl_bai}"
    
    if ! tar -xzf "${temp_dir}/sing-box.tar.gz" -C "$temp_dir" 2>/dev/null; then
        echo -e "${gl_hong}  ✗ 解压失败${gl_bai}"
        rm -rf "$temp_dir"
        break_end
        return 1
    fi
    
    mkdir -p /etc/sing-box
    local binary_path
    binary_path=$(find "$temp_dir" -name "sing-box" -type f 2>/dev/null | head -1)
    
    if [ -n "$binary_path" ] && [ -f "$binary_path" ]; then
        mv "$binary_path" /etc/sing-box/sing-box
        chmod +x /etc/sing-box/sing-box
        echo -e "${gl_lv}  ✓ 安装完成${gl_bai}"
    else
        echo -e "${gl_hong}  ✗ 未找到 sing-box 二进制文件${gl_bai}"
        rm -rf "$temp_dir"
        break_end
        return 1
    fi
    
    rm -rf "$temp_dir"
    
    echo -e "${gl_zi}[5/5] 验证安装...${gl_bai}"
    if /etc/sing-box/sing-box version >/dev/null 2>&1; then
        local installed_version
        installed_version=$(/etc/sing-box/sing-box version 2>/dev/null | head -1)
        echo -e "${gl_lv}  ✓ ${installed_version}${gl_bai}"
        echo -e "${gl_lv}✅ Sing-box 核心程序沙盒化安装成功！${gl_bai}"
        return 0
    else
        echo -e "${gl_hong}  ✗ 验证失败${gl_bai}"
        break_end
        return 1
    fi
}

# ==============================================================================
# Cloudflare Tunnel 通用 Helper 函数族
# ==============================================================================

CF_HOME="/etc/cloudflared"
CF_CREDENTIALS_DIR="$CF_HOME/credentials"
CF_CONFIGS_DIR="$CF_HOME/configs"
CF_CERT_FILE="$CF_HOME/cert.pem"
CF_MIGRATE_MARKER="$CF_HOME/.migrated"
CF_LEGACY_HOME="/root/.cloudflared"
CF_LEGACY_CERT="$CF_LEGACY_HOME/cert.pem"
CF_BINARY_PATH="/usr/local/bin/cloudflared"

cf_helper_init_dirs() {
    mkdir -p "$CF_CREDENTIALS_DIR" "$CF_CONFIGS_DIR"
    chmod 700 "$CF_CREDENTIALS_DIR" 2>/dev/null || true
    chmod 755 "$CF_HOME" "$CF_CONFIGS_DIR" 2>/dev/null || true
    return 0
}

cf_helper_install_binary() {
    local force=false
    [ "${1:-}" = "--force" ] && force=true

    if [ "$force" = false ] && command -v cloudflared &>/dev/null; then
        local current_ver
        current_ver=$(cloudflared --version 2>/dev/null | head -1 || echo "")
        echo -e "${gl_lv}✅ cloudflared 已安装: ${current_ver}${gl_bai}"
        return 0
    fi

    local arch asset
    arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)           asset="cloudflared-linux-amd64" ;;
        aarch64|arm64)          asset="cloudflared-linux-arm64" ;;
        armv7l|armv6l|armhf|arm) asset="cloudflared-linux-arm" ;;
        i386|i686)              asset="cloudflared-linux-386" ;;
        *) echo -e "${gl_hong}❌ 不支持的 CPU 架构: $arch${gl_bai}"; return 1 ;;
    esac

    local url="https://github.com/cloudflare/cloudflared/releases/latest/download/${asset}"
    echo "正在下载 cloudflared (${asset})..."

    local tmp="${CF_BINARY_PATH}.tmp.$$"
    if wget -q --show-progress -O "$tmp" "$url" && [ -s "$tmp" ]; then
        chmod +x "$tmp"
        mv "$tmp" "$CF_BINARY_PATH"
        local ver
        ver=$("$CF_BINARY_PATH" --version 2>/dev/null | head -1 || echo "")
        echo -e "${gl_lv}✅ 安装成功: ${ver}${gl_bai}"
        return 0
    else
        rm -f "$tmp"
        echo -e "${gl_hong}❌ 下载 cloudflared 失败${gl_bai}"
        return 1
    fi
}

cf_helper_ensure_auth() {
    cf_helper_init_dirs
    if [ -f "$CF_CERT_FILE" ] || [ -f "$CF_LEGACY_CERT" ]; then
        return 0
    fi

    echo -e "${gl_huang}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo -e "${gl_huang}  需要授权 Cloudflare 账户${gl_bai}"
    echo -e "${gl_huang}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo "按回车将输出一个授权 URL，用浏览器打开登录并选择 zone。"
    read -e -p "继续: " _ || true

    cloudflared tunnel login
    if [ $? -ne 0 ]; then
        echo -e "${gl_hong}❌ 授权失败${gl_bai}"
        return 1
    fi

    if [ -f "$CF_LEGACY_CERT" ] && [ ! -f "$CF_CERT_FILE" ]; then
        cp "$CF_LEGACY_CERT" "$CF_CERT_FILE"
        chmod 600 "$CF_CERT_FILE"
    fi

    echo -e "${gl_lv}✅ Cloudflare 账户授权成功${gl_bai}"
    return 0
}

cf_helper_get_tunnel_id() {
    local tunnel_name=$1
    [ -z "$tunnel_name" ] && return 1
    cloudflared tunnel list 2>/dev/null | awk -v name="$tunnel_name" 'NR > 1 && $2 == name { print $1; exit }'
}

cf_helper_create_tunnel() {
    local tunnel_name=$1
    local mode=${2:-interactive}

    if ! [[ "$tunnel_name" =~ ^[_a-zA-Z0-9][-_.a-zA-Z0-9]{0,63}$ ]]; then
        echo -e "${gl_hong}❌ 隧道名不合法${gl_bai}" >&2
        return 1
    fi

    local existing_id
    existing_id=$(cf_helper_get_tunnel_id "$tunnel_name")

    if [ -n "$existing_id" ]; then
        case "$mode" in
            reuse)
                echo "$existing_id"
                return 0
                ;;
            recreate)
                local svc="cloudflared-$tunnel_name"
                systemctl stop "$svc" 2>/dev/null || true
                systemctl disable "$svc" 2>/dev/null || true
                rm -f "/etc/systemd/system/${svc}.service"
                systemctl daemon-reload 2>/dev/null || true
                rm -f "$CF_CREDENTIALS_DIR/$existing_id.json" "$CF_LEGACY_HOME/$existing_id.json"
                cloudflared tunnel cleanup "$tunnel_name" 2>/dev/null || true
                sleep 1
                cloudflared tunnel delete -f "$tunnel_name" 2>/dev/null || true
                sleep 1
                ;;
            *)
                echo -e "${gl_huang}同名隧道已存在(ID: $existing_id)${gl_bai}" >&2
                echo "1. 复用现有隧道(新配置覆盖老配置)" >&2
                echo "2. 删除后重建" >&2
                echo "3. 取消" >&2
                local choice
                read -e -p "请选择 [1-3]: " choice || true
                case "$choice" in
                    1) echo "$existing_id"; return 0 ;;
                    2) cf_helper_create_tunnel "$tunnel_name" recreate; return $? ;;
                    *) return 1 ;;
                esac
                ;;
        esac
    fi

    local output rc
    output=$(cloudflared tunnel create "$tunnel_name" 2>&1)
    rc=$?

    if [ $rc -ne 0 ]; then
        echo -e "${gl_hong}❌ 创建隧道失败:${gl_bai}" >&2
        echo "$output" >&2
        return 1
    fi

    local new_id
    new_id=$(echo "$output" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)
    [ -z "$new_id" ] && new_id=$(cf_helper_get_tunnel_id "$tunnel_name")

    if [ -z "$new_id" ]; then
        echo -e "${gl_hong}❌ 创建成功但无法解析 tunnel_id${gl_bai}" >&2
        return 1
    fi

    cf_helper_init_dirs
    local default_cred="$CF_LEGACY_HOME/$new_id.json"
    local target_cred="$CF_CREDENTIALS_DIR/$new_id.json"
    if [ -f "$default_cred" ] && [ ! -f "$target_cred" ]; then
        cp "$default_cred" "$target_cred"
        chmod 600 "$target_cred"
    fi

    echo "$new_id"
    return 0
}

cf_helper_route_dns() {
    local tunnel_id=$1
    local hostname=$2
    local output rc
    output=$(cloudflared tunnel route dns "$tunnel_id" "$hostname" 2>&1)
    rc=$?

    if [ $rc -ne 0 ]; then
        if echo "$output" | grep -qi "already exists"; then
            echo -e "${gl_huang}⚠️  域名 $hostname 已有冲突 DNS 记录${gl_bai}" >&2
        else
            echo -e "${gl_hong}❌ DNS 路由失败:\n$output${gl_bai}" >&2
        fi
        return 1
    fi
    return 0
}

cf_helper_write_config() {
    local config_file=$1
    local tunnel_id=$2
    local cred_file=$3
    shift 3
    local rules=("$@")

    local tmp
    tmp=$(mktemp)
    {
        echo "tunnel: $tunnel_id"
        echo "credentials-file: $cred_file"
        echo ""
        echo "ingress:"
        local rule host path svc
        for rule in "${rules[@]}"; do
            IFS='|' read -r host path svc <<< "$rule"
            echo "  - hostname: $host"
            if [ -n "$path" ]; then
                [[ "$path" != ^* ]] && path="^${path}"
                echo "    path: $path"
            fi
            echo "    service: $svc"
        done
        echo "  - service: http_status:404"
    } > "$tmp"

    if cloudflared tunnel --config "$tmp" ingress validate &>/dev/null; then
        mv "$tmp" "$config_file"
        chmod 644 "$config_file"
        return 0
    else
        echo -e "${gl_hong}❌ ingress 配置校验失败:${gl_bai}" >&2
        cloudflared tunnel --config "$tmp" ingress validate 2>&1 >&2
        rm -f "$tmp"
        return 1
    fi
}

cf_helper_write_systemd() {
    local tunnel_name=$1
    local config_file=$2
    local description=${3:-"Cloudflare Tunnel: $tunnel_name"}
    local service_name="cloudflared-$tunnel_name"
    local service_file="/etc/systemd/system/${service_name}.service"

    local safe_desc="${description//\$/}"
    safe_desc="${safe_desc//\`/}"
    safe_desc="${safe_desc//\"/}"

    cat > "$service_file" << SVCEOF
[Unit]
Description=$safe_desc
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=$CF_BINARY_PATH --config "$config_file" --no-autoupdate tunnel run
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
SVCEOF

    systemctl daemon-reload
    systemctl enable "$service_name" 2>/dev/null || true
    systemctl start "$service_name"

    local i
    for i in {1..10}; do
        sleep 1
        systemctl is-active --quiet "$service_name" && break
    done

    if systemctl is-active --quiet "$service_name"; then
        echo -e "${gl_lv}✅ 服务启动成功: $service_name${gl_bai}"
        return 0
    else
        echo -e "${gl_hong}❌ 服务启动失败, 最近日志:${gl_bai}" >&2
        journalctl -u "$service_name" -n 20 --no-pager 2>/dev/null >&2
        return 1
    fi
}

_cf_list_tunnel_names() {
    systemctl list-unit-files --type=service --no-legend 2>/dev/null \
        | awk '{print $1}' \
        | grep -E '^cloudflared-.+\.service$' \
        | sed -E 's|^cloudflared-(.+)\.service$|\1|' \
        | sort -u || true
}

# ==============================================================================
# Caddy 自动化反代管理矩阵
# ==============================================================================

CADDY_SERVICE_NAME="caddy"
CADDY_CONFIG_FILE="/etc/caddy/Caddyfile"
CADDY_CONFIG_DIR="/etc/caddy"
CADDY_DOMAIN_LIST_FILE="/etc/caddy/.domain-list"
CADDY_SITES_AVAILABLE="/etc/caddy/sites-available"
CADDY_SITES_ENABLED="/etc/caddy/sites-enabled"

caddy_get_server_ip() {
    local ip
    ip=$(curl -s4 --max-time 5 ip.sb 2>/dev/null)
    [ -z "$ip" ] && ip=$(curl -s6 --max-time 5 ip.sb 2>/dev/null)
    [ -z "$ip" ] && ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo "$ip"
}

caddy_check_status() {
    if ! command -v caddy &>/dev/null; then
        echo "not_installed"
        return
    fi
    if systemctl is-active "$CADDY_SERVICE_NAME" &>/dev/null; then
        echo "running"
    elif systemctl is-enabled "$CADDY_SERVICE_NAME" &>/dev/null; then
        echo "stopped"
    else
        echo "installed_no_service"
    fi
}

caddy_check_port() {
    local port=$1
    if ss -lntp 2>/dev/null | grep -q ":${port} "; then
        return 1
    fi
    return 0
}

caddy_install() {
    clear
    echo -e "${gl_kjlan}=== 一键部署 Caddy ===${gl_bai}"
    
    local status
    status=$(caddy_check_status)
    if [ "$status" != "not_installed" ]; then
        echo -e "${gl_huang}⚠️ Caddy 已安装${gl_bai}"
        local reinstall
        read -e -p "是否重新安装/更新? (y/n) [n]: " reinstall || true
        if [[ ! "$reinstall" =~ ^[Yy]$ ]]; then
            break_end; return 0
        fi
        systemctl stop "$CADDY_SERVICE_NAME" 2>/dev/null || true
    fi

    echo -e "${gl_kjlan}[1/4] 检查端口占用...${gl_bai}"
    if ! caddy_check_port 443 || ! caddy_check_port 80; then
        echo -e "${gl_hong}❌ 端口 80/443 被占用，请清理后重试。${gl_bai}"
        break_end; return 1
    fi

    echo -e "${gl_kjlan}[2/4] 下载 Caddy...${gl_bai}"
    local CADDY_VERSION="${CADDY_DEFAULT_VERSION}"
    local download_url="https://github.com/caddyserver/caddy/releases/download/v${CADDY_VERSION}/caddy_${CADDY_VERSION}_linux_amd64.tar.gz"
    
    if curl -fsSL --connect-timeout 10 -o /tmp/caddy.tar.gz "$download_url" 2>/dev/null; then
        tar -xzf /tmp/caddy.tar.gz -C /tmp/ caddy 2>/dev/null || true
        mv /tmp/caddy /usr/bin/caddy 2>/dev/null || true
        chmod +x /usr/bin/caddy 2>/dev/null || true
        rm -f /tmp/caddy.tar.gz 2>/dev/null || true
    else
        echo -e "${gl_hong}❌ 下载失败${gl_bai}"
        break_end; return 1
    fi

    echo -e "${gl_kjlan}[3/4] 配置 Caddy 运行环境...${gl_bai}"
    mkdir -p "$CADDY_CONFIG_DIR" "$CADDY_SITES_AVAILABLE" "$CADDY_SITES_ENABLED" /var/log/caddy /var/lib/caddy
    if ! id -u caddy &>/dev/null; then useradd -r -s /bin/false caddy 2>/dev/null || true; fi
    chown -R caddy:caddy "$CADDY_CONFIG_DIR" /var/log/caddy /var/lib/caddy

    local ssl_email="caddy@localhost"
    cat > "$CADDY_CONFIG_FILE" << EOF
{
    admin localhost:2019
    email ${ssl_email}
}
import ${CADDY_SITES_ENABLED}/*.conf
EOF
    chown caddy:caddy "$CADDY_CONFIG_FILE"

    cat > /etc/systemd/system/caddy.service << 'EOF'
[Unit]
Description=Caddy Web Server
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
Environment="HOME=/var/lib/caddy"
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

    echo -e "${gl_kjlan}[4/4] 启动 Caddy...${gl_bai}"
    systemctl daemon-reload
    systemctl enable caddy >/dev/null 2>&1 || true
    systemctl start caddy

    if systemctl is-active caddy &>/dev/null; then
        echo -e "${gl_lv}✅ Caddy 部署成功!${gl_bai}"
    else
        echo -e "${gl_hong}❌ Caddy 启动失败${gl_bai}"
    fi
    break_end
}

manage_caddy() {
    while true; do
        clear
        echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
        echo -e "${gl_kjlan}  Caddy 反向代理调度矩阵${gl_bai}"
        echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
        local status
        status=$(caddy_check_status)
        echo "当前状态: $status"
        echo ""
        echo "1. 部署 Caddy 核心"
        echo "2. 启动服务"
        echo "3. 停止服务"
        echo "4. 查看日志"
        echo "0. 撤退"
        echo ""
        local c
        read -e -p "操作: " c || true
        case "$c" in
            1) caddy_install ;;
            2) systemctl start caddy; break_end ;;
            3) systemctl stop caddy; break_end ;;
            4) journalctl -u caddy -f ;;
            0) return ;;
        esac
    done
}
