#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: ex188c2.sh (Xray Advanced Management & Core Tuning V188c2)
# 快捷方式: xrv
#
# V188c2 终极融合增强版日志:
#   1. 精准断舍离: 完整继承 ex188.sh 的所有 Xray 控制与面板排版，完美剔除外部冗余代理。
#   2. 增量融合: 从 tcpcc 提取并植入 Swap 智能管理、IPv4 强优先/IPv6 物理熔断。
#   3. 极客预设: 增量加入四大运行时内核调优预设（星辰大海/Reality狂暴/低配救机等）。
#   4. 全自动托管: 新增一键自动化底盘托管 (XanMod -> Swap -> IPv4 -> 内核调优)。
#   5. 容错加固: 严格遵循 set -euo pipefail，绝不漏掉任何一个 toggle 开关与环境探针。
# ==============================================================================

# 检查 Bash 运行环境
if test -z "$BASH_VERSION"; then
    echo "Error: Please run this script with bash: bash ex188c2.sh"
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

# 兼容 tcpcc 的颜色别名
readonly gl_hong="$red"
readonly gl_lv="$green"
readonly gl_huang="$yellow"
readonly gl_bai="$none"
readonly gl_kjlan="$cyan"
readonly gl_zi="$magenta"
readonly gl_hui="$gray"

# ── 全局常量与路径 ──────────────────────────────────────────────
readonly SCRIPT_VERSION="188c2"
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

# ── 可变全局状态 ───────────────────────────────────────────────
SERVER_IP=""
REMARK_NAME="xp-reality"
BEST_SNI="www.microsoft.com"
SNI_JSON_ARRAY="\"www.microsoft.com\""
LISTEN_PORT=443
AUTO_MODE="0"

# ── 初始化系统目录 ─────────────────────────────────────────────
if ! mkdir -p "$CONFIG_DIR" "$DAT_DIR" "$SCRIPT_DIR" "$FLAGS_DIR" "$LOG_DIR" "$BACKUP_DIR" 2>/dev/null; then
    true
fi
if ! touch "$USER_SNI_MAP" "$USER_TIME_MAP" 2>/dev/null; then
    true
fi

# ==============================================================================
# [ 区块 I: 基础工具与容错机制 ]
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

# 终端断点停留 (支持全自动模式跳过)
break_end() {
    if [[ "$AUTO_MODE" == "1" ]]; then return 0; fi
    echo ""
    echo -e "${green}指令执行完毕。${none}"
    read -n 1 -s -r -p "按任意键继续返回菜单..." || true
    echo ""
}

# 日志持久化
log_info()  { echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO:  $*" >> "$LOG_DIR/xray.log" 2>/dev/null || true; }
log_error() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$LOG_DIR/error.log" 2>/dev/null || true; }

# 捕获异常中断
trap '_err_handler $? $LINENO "$BASH_COMMAND"' ERR
_err_handler() {
    local code=$1 line=$2 cmd=$3
    echo -e "\n${red}[SYSTEM_ABORT] 退出码:$code 行数:$line 故障指令:$cmd${none}" >&2
    log_error "EXIT=$code LINE=$line CMD=$cmd"
}

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

# ==============================================================================
# [ 区块 II: JSON 配置事务与回滚系统 ]
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

# ==============================================================================
# [ 区块 III: 环境预检与系统限制配置 (Limits) ]
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

    local need="jq curl wget xxd unzip qrencode vnstat openssl coreutils sed e2fsprogs pkg-config iproute2 ethtool bc bison flex dwarves rsync python3 cpio"
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
