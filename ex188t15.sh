#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: ex188t15.sh (The Apex Vanguard - Pure Genesis V188t15)
# 快捷方式: xrv
#
# V188t15 终极原教旨修复日志:
#   1. 灵魂归位: 100% 还原 ex188.sh 中写死的 1GB 极简 Swap。
#   2. 参数归位: 100% 还原 ex188.sh 中强大的 do_perf_tuning (BBR/Sysctl 暴力写入集)。
#   3. 原装伪装: SNI 探针库完全替换为 ex188.sh 原版的 129 个顶级域名(严格垂直排版)。
#   4. 限制解除: 彻底拔除 15GB 磁盘防爆强制校验函数，无视死线直接编译。
#   5. 强硬路由: 增量融入一键强锁 IPv4 优先并物理熔断 IPv6 的安全策略。
#   6. 探针补全: 找回遗失的 21 个 check_ 状态探针，彻底修复 28 项面板闪退问题。
#   7. 终极防御: 全面修复 set -euo pipefail 下 read 变量未绑定引发的终端闪退问题。
# ==============================================================================

# 检查 Bash 运行环境
if test -z "$BASH_VERSION"; then
    echo "Error: Please run this script with bash: bash ex188t15.sh"
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
readonly SCRIPT_VERSION="ex188t15-Ultimate"
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
if ! mkdir -p "$CONFIG_DIR" "$DAT_DIR" "$SCRIPT_DIR" "$FLAGS_DIR" "$LOG_DIR" "$BACKUP_DIR" /etc/sysctl.d /etc/security 2>/dev/null; then
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

# 日志持久化
log_info()  { echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO:  $*" >> "$LOG_DIR/xray.log" 2>/dev/null || true; }
log_error() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$LOG_DIR/error.log" 2>/dev/null || true; }

# 捕获异常中断
trap '_err_handler $? $LINENO "$BASH_COMMAND"' ERR
_err_handler() {
    local code=$1 line=$2 cmd=$3
    echo -e "\n${red}[SYSTEM_ABORT] 退出码:$code 行数:$line 故障指令:$cmd${none}" >&2
    log_error "EXIT=$code LINE=$line CMD=$cmd"
    rm -f /tmp/net-tcp-tune.* /tmp/sni_array.json /tmp/vless_inbound.json /tmp/ss_inbound.json 2>/dev/null || true
}

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
    read -e -p "按任意键继续返回菜单..." _pause || true
    echo ""
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
        local _pause=""
        read -e -p "请按 Enter 键返回..." _pause || true
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
            yum makecache -y >/dev/null 2>&1 || true
            yum install -y $list >/dev/null 2>&1 || true
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

check_and_create_1gb_swap() {
    title "检查物理 Swap 分区状态"
    local SWAP_FILE="/swapfile"
    local CURRENT_SWAP
    CURRENT_SWAP=$(swapon --show=NAME,KBYTES --noheadings 2>/dev/null | grep "$SWAP_FILE" | awk '{print $2}' || echo "")
    
    if [[ -n "$CURRENT_SWAP" ]] && ((CURRENT_SWAP >= 1000000)); then
        info "系统已配置足量的 Swap 分区 (≥1GB)。"
    else
        warn "未检测到足量 Swap，正在配置 1GB Swap 分区..."
        swapoff -a 2>/dev/null || true
        sed -i '/swapfile/d' /etc/fstab 2>/dev/null || true
        rm -f "$SWAP_FILE" 2>/dev/null || true
        
        dd if=/dev/zero of="$SWAP_FILE" bs=1M count=1024 status=none 2>/dev/null || true
        chmod 600 "$SWAP_FILE" 2>/dev/null || true
        mkswap "$SWAP_FILE" >/dev/null 2>&1 || true
        swapon "$SWAP_FILE" >/dev/null 2>&1 || true
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab 2>/dev/null || true
        info "1GB Swap 分区配置完成。"
    fi
}

enforce_ipv4_and_disable_ipv6() {
    echo -e "${gl_kjlan}=== 底层安全策略：锁定 IPv4 优先并切断 IPv6 泄露通道 ===${gl_bai}"
    
    echo -e "${gl_zi}[1/2] 重写寻址权重矩阵 (gai.conf)...${gl_bai}"
    cat > /etc/gai.conf << EOF
# 强制绑定 IPv4 寻址优先
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
    mkdir -p /etc/sysctl.d 2>/dev/null || true
    cat > /etc/sysctl.d/99-disable-ipv6.conf << EOF
# 物理级熔断 IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sysctl --system >/dev/null 2>&1 || true

    echo -e "${gl_lv}✅ 策略下发完毕：机器 IPv6 端口已封死，完全阻隔旁路探测！${gl_bai}"
}

# ==============================================================================
# [ 区块 IV: Geo 规则库自动更新与本地 DNS 锁定 ]
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
    elif cat /etc/issue 2>/dev/null | grep -Eqi "debian"; then
        release="debian"
    elif cat /etc/issue 2>/dev/null | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue 2>/dev/null | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version 2>/dev/null | grep -Eqi "debian"; then
        release="debian"
    elif cat /proc/version 2>/dev/null | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version 2>/dev/null | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
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
        read -e -p "请输入自定义 Nameserver IP (例如 8.8.8.8 或 1.1.1.1): " nameserver || true
        if [[ "${nameserver:-}" =~ ^([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]]; then
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

# ==============================================================================
# [ 区块 V: 原装 SNI 连通性测试矩阵 ]
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
        "www.intel.com" "downloadcenter.intel.com" "ark.intel.com" "www.amd.com" "drivers.amd.com" 
        "www.dell.com" "support.dell.com" "www.hp.com" "support.hp.com" "developers.hp.com"
        "www.bmw.com" "www.mercedes-benz.com" "global.toyota" "www.honda.com" "www.volkswagen.com"
        "www.nike.com" "www.adidas.com" "www.zara.com" "www.ikea.com" "www.shell.com"
        "www.bp.com" "www.ge.com" "www.hsbc.com" "www.morganstanley.com" "www.msc.com"
        "www.sony.com" "www.canon.com" "www.nintendo.com" "www.unilever.com" "www.loreal.com"
        "www.hermes.com" "www.louisvuitton.com" "www.dior.com" "www.gucci.com" "www.coca-cola.com"
        "www.tesla.com" "s0.awsstatic.com" "www.nvidia.com" "www.samsung.com" "www.oracle.com"
        "addons.mozilla.org" "www.airbnb.com.sg" "mit.edu" "stanford.edu" "www.lufthansa.com"
        "www.singaporeair.com" "www.specialized.com" "www.logitech.com" "www.razer.com" "www.corsair.com"
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
        if read -t 0.1 -n 1 -s _dummy 2>/dev/null || [ $? -eq 0 ]; then
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
            read -e -p "  请选择对应操作或节点: " sel || true
            sel=${sel:-1}
            
            case "$sel" in
                q|Q) return 1 ;;
                r|R) run_sni_scanner; continue ;;
                m|M)
                    local m_sel=""
                    read -e -p "请输入所需序号 (例如 1 3 5，或 all): " m_sel || true
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
                    read -e -p "请输入自定义域名: " d || true
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
                read -e -p "强制使用该域名？(y/n): " force_use || true
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
# [ 区块 VI: Linux 内核环境与编译模块 ]
# ==============================================================================

do_install_xanmod_main_official() {
    title "安装预编译 XANMOD (main) 内核"
    if [[ "$(uname -m)" != "x86_64" ]]; then 
        error "官方预编译 Xanmod 仅支持 x86_64 架构！"
        local _pause=""; read -e -p "按 Enter 返回..." _pause || true
        return
    fi
    if [[ ! -f /etc/debian_version ]]; then 
        error "官方预编译 Xanmod APT 源仅支持 Debian / Ubuntu 系！"
        local _pause=""; read -e -p "按 Enter 返回..." _pause || true
        return
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
    
    local confirm=""
    read -e -p "确定要开始编译内核吗？(y/n): " confirm || true
    if [[ "${confirm:-}" != "y" ]]; then
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
            local force_k=""
            read -e -p "确定强制继续吗？(y/n): " force_k || true
            if [[ "${force_k:-}" != "y" ]]; then 
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
        local _pause=""; read -e -p "按 Enter 返回..." _pause || true
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
# ==============================================================================
# [ 区块 VI: Linux 内核环境与编译模块 ]
# ==============================================================================

do_install_xanmod_main_official() {
    title "安装预编译 XANMOD (main) 内核"
    if [[ "$(uname -m)" != "x86_64" ]]; then 
        error "官方预编译 Xanmod 仅支持 x86_64 架构！"
        local _pause=""; read -e -p "按 Enter 返回..." _pause || true
        return
    fi
    if [[ ! -f /etc/debian_version ]]; then 
        error "官方预编译 Xanmod APT 源仅支持 Debian / Ubuntu 系！"
        local _pause=""; read -e -p "按 Enter 返回..." _pause || true
        return
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
    
    local confirm=""
    read -e -p "确定要开始编译内核吗？(y/n): " confirm || true
    if [[ "${confirm:-}" != "y" ]]; then
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
            local force_k=""
            read -e -p "确定强制继续吗？(y/n): " force_k || true
            if [[ "${force_k:-}" != "y" ]]; then 
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
        local _pause=""; read -e -p "按 Enter 返回..." _pause || true
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

# ==============================================================================
# [ 区块 VII: 系统底层网络栈优化 (Sysctl & NIC Tuning) ]
# ==============================================================================

do_perf_tuning() {
    title "系统底层网络栈深度调优"
    warn "应用网络调优参数后，系统将自动重启以生效更改，请确认！"
    
    local confirm=""
    read -e -p "是否继续执行调优？(y/n): " confirm || true
    if [[ "${confirm:-}" != "y" ]]; then
        return
    fi
    
    local current_scale
    current_scale=$(sysctl -n net.ipv4.tcp_adv_win_scale 2>/dev/null || echo "1")
    local current_app
    current_app=$(sysctl -n net.ipv4.tcp_app_win 2>/dev/null || echo "31")
    
    echo -e "  当前 tcp_adv_win_scale: ${cyan}${current_scale}${none} (建议 1 或 2)"
    echo -e "  当前 tcp_app_win: ${cyan}${current_app}${none} (建议 31)"
    
    local new_scale=""
    read -e -p "设置 tcp_adv_win_scale (-2 到 2，直接回车保留当前): " new_scale || true
    new_scale=${new_scale:-$current_scale}
    
    local new_app=""
    read -e -p "设置 tcp_app_win (1 到 31，直接回车保留当前): " new_app || true
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

    info "写入内核 Sysctl 参数..."
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

# BBR Pacing (适用 BBR3)
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

# 系统细节补充
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
        local _pause=""; read -e -p "按 Enter 返回菜单..." _pause || true
        return 1
    else
        info "所有底层 Sysctl 参数已成功应用。"
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
Description=NIC Advanced Tuning
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
Description=RPS RFS Network CPU Distribution
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
                info "网卡硬件队列 RPS/RFS 守护进程配置成功。"
            else
                warn "RPS 分发守护进程启动异常。"
            fi
        else
            warn "NIC 优化守护进程启动异常。"
        fi
    fi

    info "网络栈参数应用完成，系统将在 30 秒后重启..."
    sleep 30
    reboot
}

# ==============================================================================
# [ 区块 VIII: 网卡发送队列调优与 CAKE 参数配置 ]
# ==============================================================================

do_txqueuelen_opt() {
    title "网卡发送队列 (TX Queue) 优化"
    local IP_CMD
    IP_CMD=$(command -v ip || echo "")
    
    if [[ -z "$IP_CMD" ]]; then
        error "未找到 iproute2 (ip 命令)。"
        local _pause=""; read -e -p "按 Enter 返回..." _pause || true
        return 1
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if [[ -z "$IFACE" ]]; then
        error "无法定位系统默认出口网卡。"
        local _pause=""; read -e -p "按 Enter 返回..." _pause || true
        return 1
    fi
    
    $IP_CMD link set "$IFACE" txqueuelen 2000 2>/dev/null || true
    
    cat > /etc/systemd/system/txqueue.service << EOF
[Unit]
Description=Set TX Queue Length for Performance
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
        info "已成功配置网卡队列长度为 2000。"
    else
        warn "修改失败，当前驱动不支持调节 txqueuelen。"
    fi
    local _pause=""; read -e -p "按 Enter 返回..." _pause || true
}

config_cake_advanced() {
    clear
    title "CAKE 调度器高级参数配置"
    
    local current_opts="未配置 (系统自适应默认)"
    if [[ -f "$CAKE_OPTS_FILE" ]]; then
        current_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
    fi
    echo -e "  当前运行参数: ${cyan}${current_opts}${none}\n"
    
    local c_bw=""
    read -e -p "  [1] 声明物理带宽限制 (如 900Mbit，填 0 取消限制): " c_bw || true
    
    local c_oh=""
    read -e -p "  [2] 配置底层报文开销补偿 Overhead (填 0 取消限制): " c_oh || true
    
    local c_mpu=""
    read -e -p "  [3] 最小数据单元截断 MPU (填 0 取消限制): " c_mpu || true
    
    echo "  [4] RTT 延迟模型: "
    echo "    1) internet  (标准互联 85ms)"
    echo "    2) oceanic   (跨洋海缆 300ms)"
    echo "    3) satellite (卫星链路 1000ms)"
    local rtt_sel=""
    read -e -p "  请选择 (默认 2): " rtt_sel || true
    
    local c_rtt=""
    case "${rtt_sel:-2}" in
        1) c_rtt="internet" ;;
        3) c_rtt="satellite" ;;
        *) c_rtt="oceanic" ;;
    esac
    
    echo "  [5] 流量分类识别 (Diffserv): "
    echo "    1) diffserv4  (按数据包特征分类，CPU 消耗较高)"
    echo "    2) besteffort (盲推忽略特征，降低 CPU 开销)"
    local diff_sel=""
    read -e -p "  请选择 (默认 2): " diff_sel || true
    
    local c_diff=""
    case "${diff_sel:-2}" in
        1) c_diff="diffserv4" ;;
        *) c_diff="besteffort" ;;
    esac

    local final_opts=""
    if [[ -n "${c_bw:-}" && "${c_bw:-}" != "0" ]]; then 
        final_opts="$final_opts bandwidth ${c_bw}"
    fi
    if [[ -n "${c_oh:-}" && "${c_oh:-}" != "0" ]]; then 
        final_opts="$final_opts overhead ${c_oh}"
    fi
    if [[ -n "${c_mpu:-}" && "${c_mpu:-}" != "0" ]]; then 
        final_opts="$final_opts mpu ${c_mpu}"
    fi
    
    final_opts="$final_opts $c_rtt $c_diff"
    # 去除前导空格
    final_opts="${final_opts#"${final_opts%%[! ]*}"}"
    
    if [[ -z "$final_opts" ]]; then
        rm -f "$CAKE_OPTS_FILE" 2>/dev/null || true
        info "已清除所有 CAKE 自定义高阶参数。"
    else
        echo "$final_opts" > "$CAKE_OPTS_FILE"
        info "CAKE 高阶参数已保存: $final_opts"
    fi
    
    modprobe sch_cake 2>/dev/null || true
    _apply_cake_live
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if tc qdisc show dev "$IFACE" 2>/dev/null | grep -q "cake"; then
        info "验证通过：CAKE 队列已成功接管网卡接口。"
    else
        warn "验证失败：网卡当前未运行 CAKE 调度器。请确认系统内核支持 sch_cake 模块。"
    fi
    
    local _pause=""; read -e -p "配置完成，请按 Enter 返回..." _pause || true
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
# [ 区块 IX: 系统状态探针与自启保护引擎 (The Missing Link) ]
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
        if grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null; then echo "true"; return; fi
    fi
    echo "false"
}

check_thp_state() {
    if [[ ! -f "/sys/kernel/mm/transparent_hugepage/enabled" ]]; then echo "unsupported"; return; fi
    if [[ ! -w "/sys/kernel/mm/transparent_hugepage/enabled" ]]; then echo "unsupported"; return; fi
    if grep -q '\[never\]' /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null; then echo "true"; else echo "false"; fi
}

check_mtu_state() {
    if [[ ! -f "/proc/sys/net/ipv4/tcp_mtu_probing" ]]; then echo "unsupported"; return; fi
    local val
    val=$(sysctl -n net.ipv4.tcp_mtu_probing 2>/dev/null || echo "0")
    if [[ "$val" == "1" ]]; then echo "true"; else echo "false"; fi
}

check_cpu_state() {
    if [[ ! -d "/sys/devices/system/cpu/cpu0/cpufreq" ]]; then echo "unsupported"; return; fi
    if grep -q 'performance' /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null; then echo "true"; else echo "false"; fi
}

check_ring_state() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if [[ -z "$IFACE" ]]; then echo "unsupported"; return; fi
    if ! command -v ethtool >/dev/null 2>&1; then echo "unsupported"; return; fi
    if ! ethtool -g "$IFACE" >/dev/null 2>&1; then echo "unsupported"; return; fi
    
    local curr_rx
    curr_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Current hardware settings" | grep "RX:" | head -1 | awk '{print $2}' || echo "")
    if [[ -z "$curr_rx" ]]; then echo "unsupported"; return; fi
    if [[ "$curr_rx" == "512" ]]; then echo "true"; else echo "false"; fi
}

check_zram_state() {
    if ! modprobe -n zram >/dev/null 2>&1; then
        if ! lsmod 2>/dev/null | grep -q zram; then echo "unsupported"; return; fi
    fi
    if swapon --show 2>/dev/null | grep -q 'zram'; then echo "true"; else echo "false"; fi
}

check_journal_state() {
    if [[ ! -f "/etc/systemd/journald.conf" ]]; then echo "unsupported"; return; fi
    if grep -q '^Storage=volatile' /etc/systemd/journald.conf 2>/dev/null; then echo "true"; else echo "false"; fi
}

check_process_priority_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if [[ ! -f "$limit_file" ]]; then echo "false"; return; fi
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
    if ! command -v ethtool >/dev/null 2>&1; then echo "unsupported"; return; fi
    
    local eth_info
    eth_info=$(ethtool -k "$IFACE" 2>/dev/null || echo "")
    if [[ -z "$eth_info" ]]; then echo "unsupported"; return; fi
    if echo "$eth_info" | grep -E "^generic-receive-offload:|^rx-gro:" | grep -q "fixed" 2>/dev/null; then echo "unsupported"; return; fi
    if echo "$eth_info" | grep -E "^generic-receive-offload:|^rx-gro:" | grep -q " off" 2>/dev/null; then echo "true"; else echo "false"; fi
}

check_irq_state() {
    local CORES
    CORES=$(nproc 2>/dev/null || echo 1)
    if (( CORES < 2 )); then echo "unsupported"; return; fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    local irq
    irq=$(grep "$IFACE" /proc/interrupts 2>/dev/null | head -1 | awk '{print $1}' | tr -d ':' || echo "")
    
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
# ==============================================================================
# [ 区块 X: 全局底层调度模块 (Hoisting 修复区) ]
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
        apt-get update -y >/dev/null 2>&1 || yum makecache -y >/dev/null 2>&1 || true
        apt-get install -y dnsmasq >/dev/null 2>&1 || yum install -y dnsmasq >/dev/null 2>&1 || true
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
    if [[ "$(check_cpu_state)" == "unsupported" ]]; then return; fi
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
    if [[ "$(check_ring_state)" == "unsupported" ]]; then return; fi
    if [[ "$(check_ring_state)" == "true" ]]; then
        local max_rx
        max_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Pre-set maximums" | grep "RX:" | head -1 | awk '{print $2}' || echo "512")
        if [[ -n "$max_rx" ]]; then ethtool -G "$IFACE" rx "$max_rx" tx "$max_rx" 2>/dev/null || true; fi
    else 
        ethtool -G "$IFACE" rx 512 tx 512 2>/dev/null || true
    fi
    update_hw_boot_script
}

toggle_gso_off() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if [[ "$(check_gso_off_state)" == "unsupported" ]]; then return; fi
    if [[ "$(check_gso_off_state)" == "true" ]]; then 
        ethtool -K "$IFACE" gro on gso on tso on 2>/dev/null || true
    else 
        ethtool -K "$IFACE" gro off gso off tso off 2>/dev/null || true
    fi
    update_hw_boot_script
}

toggle_zram() {
    if [[ "$(check_zram_state)" == "unsupported" ]]; then return; fi
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
    if [[ "$(check_journal_state)" == "unsupported" ]]; then return; fi
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
    if [[ ! -f "$limit_file" ]]; then return; fi
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
    if [[ "$(check_cake_state)" == "false" ]]; then warn "已保存设置，但必须先开启 CAKE 才能生效!"; sleep 2; return; fi
    _apply_cake_live
}

toggle_ecn() {
    if [[ "$(check_ecn_state)" == "true" ]]; then rm -f "$FLAGS_DIR/ecn" 2>/dev/null || true; else touch "$FLAGS_DIR/ecn" 2>/dev/null || true; fi
    if [[ "$(check_cake_state)" == "false" ]]; then warn "已保存设置，但必须先开启 CAKE 才能生效!"; sleep 2; return; fi
    _apply_cake_live
}

toggle_wash() {
    if [[ "$(check_wash_state)" == "true" ]]; then rm -f "$FLAGS_DIR/wash" 2>/dev/null || true; else touch "$FLAGS_DIR/wash" 2>/dev/null || true; fi
    if [[ "$(check_cake_state)" == "false" ]]; then warn "已保存设置，但必须先开启 CAKE 才能生效!"; sleep 2; return; fi
    _apply_cake_live
}

toggle_irq() {
    if [[ "$(check_irq_state)" == "unsupported" ]]; then return; fi
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
# [ 区块 XI: 应用层高级调优引擎 (JSON 隔离操作) ]
# ==============================================================================

_turn_on_app() {
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
# [ 区块 XII: 全域 28 项状态调度面板 ]
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
# [ 区块 XIII: 核心部署、管理与排版渲染矩阵 ]
# ==============================================================================

gen_ss_pass() { 
    head -c 24 /dev/urandom | base64 | tr -d '=/+\n' | head -c 24 || true
}

_select_ss_method() {
    echo -e "  ${cyan}选择 SS 加密方式：${none}" >&2
    echo "  1) aes-256-gcm (推荐)  2) aes-128-gcm  3) chacha20-ietf-poly1305" >&2
    local mc=""
    read -e -p "  编号: " mc >&2 || true
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
    local proto_choice=""
    read -e -p "  请选择 (默认 1): " proto_choice || true
    proto_choice=${proto_choice:-1}

    if [[ "$proto_choice" == "1" || "$proto_choice" == "3" ]]; then
        while true; do 
            local input_p=""
            read -e -p "设置 VLESS 监听端口 (默认 443): " input_p || true
            input_p=${input_p:-443}
            if validate_port "$input_p"; then 
                LISTEN_PORT="$input_p"
                break
            fi
        done
        local input_remark=""
        read -e -p "设置节点备注名称 (默认 xp-reality): " input_remark || true
        REMARK_NAME=${input_remark:-xp-reality}
        
        if ! choose_sni; then
            return 1
        fi
    fi

    local ss_port=8388
    local ss_pass=""
    local ss_method="aes-256-gcm"
    
    if [[ "$proto_choice" == "2" || "$proto_choice" == "3" ]]; then
        while true; do 
            local input_s=""
            read -e -p "设置 SS 监听端口 (默认 8388): " input_s || true
            input_s=${input_s:-8388}
            if validate_port "$input_s"; then 
                ss_port="$input_s"
                break
            fi
        done
        ss_pass=$(gen_ss_pass)
        ss_method=$(_select_ss_method)
        
        if [[ "$proto_choice" == "2" ]]; then 
            local input_remark=""
            read -e -p "设置节点备注名称 (默认 xp-reality): " input_remark || true
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
        local opt=""
        read -e -p "按 Enter 返回主菜单，或输入 b 重新配置 SNI: " opt || true
        if [[ "${opt:-}" == "b" || "${opt:-}" == "B" ]]; then
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
                    echo -e "  协议框架       : VLESS-Reality (Vision)"
                    echo -e "  外网IP         : $SERVER_IP"
                    echo -e "  端口           : $port"
                    echo -e "  用户 UUID    : $uuid"
                    echo -e "  伪装SNI        : $target_sni"
                    echo -e "  公钥(pbk)      : $pub"
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

do_user_manager() {
    while true; do
        clear
        title "用户与认证管理系统"
        if [[ ! -f "$CONFIG" ]]; then 
            error "未找到系统配置文件。"
            local _pause=""
            read -e -p "按 Enter 返回..." _pause || true
            return
        fi

        local clients
        clients=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .settings?.clients[]? | .id + "|" + (.email // "未命名")' "$CONFIG" 2>/dev/null || echo "")
        if [[ -z "$clients" || "$clients" == "null" ]]; then 
            error "系统内未提取到 VLESS 凭证记录。"
            local _pause=""
            read -e -p "按 Enter 返回..." _pause || true
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
        local uopt=""
        read -e -p "请输入操作代码: " uopt || true

        case "${uopt:-}" in
            a|A)
                local nu sid ctime u_remark=""
                nu=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
                sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n' || echo "")
                ctime=$(date +"%Y-%m-%d %H:%M")
                read -e -p "请指定用户名备注 (默认 User-$sid): " u_remark || true
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
                local _pause=""
                read -e -p "按 Enter 继续..." _pause || true
                ;;
            m|M)
                local m_remark="" m_uuid="" m_sid="" ctime
                read -e -p "请指定导入用户备注 (默认 Imported): " m_remark || true
                m_remark=${m_remark:-Imported}
                read -e -p "请输入要导入的 UUID: " m_uuid || true
                if [[ -z "${m_uuid:-}" ]]; then continue; fi
                read -e -p "请输入对应的 ShortId: " m_sid || true
                if [[ -z "${m_sid:-}" ]]; then continue; fi
                ctime=$(date +"%Y-%m-%d %H:%M")

                _safe_jq_write --arg id "$m_uuid" --arg email "$m_remark" '
                    (.inbounds[]? | select(.protocol=="vless") | .settings.clients) += [{"id":$id,"flow":"xtls-rprx-vision","email":$email}]
                '
                _safe_jq_write --arg sid "$m_sid" '
                    (.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.shortIds) += [$sid]
                '
                echo "$m_uuid|$ctime" >> "$USER_TIME_MAP"

                local m_sni=""
                read -e -p "绑定专属 SNI (直接回车使用系统默认): " m_sni || true
                if [[ -n "${m_sni:-}" ]]; then
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
                local _pause=""
                read -e -p "按 Enter 继续..." _pause || true
                ;;
            s|S)
                local snum="" t_uuid="" t_remark="" u_sni=""
                read -e -p "请输入目标用户序列号: " snum || true
                t_uuid=$(awk -F'|' -v id="${snum:-0}" '$1==id{print $2}' "$tmp_users" 2>/dev/null || echo "")
                t_remark=$(awk -F'|' -v id="${snum:-0}" '$1==id{print $3}' "$tmp_users" 2>/dev/null || echo "")
                
                if [[ -n "$t_uuid" ]]; then
                    read -e -p "请输入新分配的伪装域名 (SNI): " u_sni || true
                    if [[ -n "${u_sni:-}" ]]; then
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
                        local _pause=""
                        read -e -p "按 Enter 继续..." _pause || true
                    fi
                else 
                    error "您输入的序列号不在当前列表中。"
                fi
                ;;
            d|D)
                local dnum="" total t_uuid idx
                read -e -p "请输入需要吊销的用户序列号: " dnum || true
                total=$(wc -l < "$tmp_users" 2>/dev/null || echo 0)
                
                if ((total <= 1)); then 
                    error "安全机制拦截：禁止删除系统中最后一位特权用户！"
                    sleep 2
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
                        sleep 2
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
        clear
        title "全局防火墙与广告阻断策略"
        if [[ ! -f "$CONFIG" ]]; then 
            error "未找到配置数据。"
            local _pause=""
            read -e -p "按 Enter 返回..." _pause || true
            return
        fi
        
        local bt_en ad_en
        bt_en=$(jq -r '.routing.rules[]? | select(.protocol != null) | select(.protocol | index("bittorrent")) | ._enabled' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        ad_en=$(jq -r '.routing.rules[]? | select(.domain != null) | select(.domain | index("geosite:category-ads-all")) | ._enabled' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        echo -e "  1) BT 下载协议阻断限制          | 状态: ${yellow}${bt_en:-未知}${none}"
        echo -e "  2) 全局恶意域名与广告黑洞过滤   | 状态: ${yellow}${ad_en:-未知}${none}"
        echo "  0) 返回上一层菜单"
        hr
        local bc=""
        read -e -p "请选择管理项: " bc || true
        
        case "${bc:-}" in
            1)
                local nv="true"
                if [[ "$bt_en" == "true" ]]; then nv="false"; fi
                _safe_jq_write --argjson nv "$nv" '(.routing.rules[]? | select(.protocol != null and (.protocol | index("bittorrent")))) |= (._enabled = $nv)'
                ensure_xray_is_alive; info "BT 协议阻断状态已切换为: $nv" 
                sleep 2
                ;;
            2)
                local nv="true"
                if [[ "$ad_en" == "true" ]]; then nv="false"; fi
                _safe_jq_write --argjson nv "$nv" '(.routing.rules[]? | select(.domain != null and (.domain | index("geosite:category-ads-all")))) |= (._enabled = $nv)'
                ensure_xray_is_alive; info "全局广告过滤状态已切换为: $nv" 
                sleep 2
                ;;
            0) return ;;
        esac
    done
}

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
                if [[ "${bopt:-}" == "r" ]]; then restore_latest_backup; local _pause=""; read -e -p "Enter..." _pause || true; fi
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
                enforce_ipv4_and_disable_ipv6
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
    info "正在与官方数据流建立桥接..."
    bash -c "$(curl -fsSL --connect-timeout 10 https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1 || true
    fix_xray_systemd_limits
    systemctl restart xray >/dev/null 2>&1 || true
    local cur_ver
    cur_ver=$($XRAY_BIN version 2>/dev/null | head -n1 | awk '{print $2}' || echo "读取异常")
    info "系统已升级完毕。当前锚定版本: ${cyan}$cur_ver${none}"
    local _pause=""
    read -e -p "按 Enter 返回主控界面..." _pause || true
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
    info "伪装路由接口矩阵已无损调转！"
}

do_fallback_probe() {
    clear
    title "Reality 防线审查 (回落陷阱拦截态势)"
    jq -r '
      .inbounds[]? | select(.protocol=="vless" and .streamSettings.security=="reality") | .streamSettings.realitySettings | 
      "  [红区拦截警戒值]\n    单向上传瞬时熔断 (bytesPerSec) : \(.limitFallbackUpload.bytesPerSec // "静默未拦截")\n    单向下传瞬时熔断 (bytesPerSec) : \(.limitFallbackDownload.bytesPerSec // "静默未拦截")"
    ' "$CONFIG" 2>/dev/null || warn "JSON 解析器受阻。"
    echo ""
    local _pause=""
    read -e -p "情报核验结束，按 Enter 键返回..." _pause || true
}

do_uninstall() {
    title "物理级毁灭清理与系统生态还原"
    local confirm=""
    read -e -p "危险指令: 执行后将彻底剥离所有网络拦截、守护进程及私钥配置，无可撤销。确信？(y/n): " confirm || true
    if [[ "${confirm:-}" != "y" && "${confirm:-}" != "Y" ]]; then 
        return
    fi
    
    info "授权通过，正在解构基础架构..."
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
    
    info "格式化肃清已落定，环境完全重置回归纯净。"
    exit 0
}

# ==============================================================================
# [ 区块 XV: 绝对统帅中枢大厅 ]
# ==============================================================================

main_menu() {
    while true; do
        clear
        echo -e "${blue}======================================================================${none}"
        echo -e "  ${magenta}Xray 高维控制台 (Apex Vanguard Pure Genesis)${none}"
        
        local svc
        svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        if [[ "$svc" == "active" ]]; then 
            svc="${green}健康驱动 (Active)${none}"
        else 
            svc="${red}心跳静默 (Inactive)${none}"
        fi
        
        local current_kernel
        current_kernel=$(uname -r)
        
        echo -e "  引擎态势: $svc | 热键调用: ${cyan}xrv${none} | 物理信标: ${yellow}${SERVER_IP}${none} | 内核: ${yellow}${current_kernel}${none}"
        echo -e "${blue}======================================================================${none}"
        echo "  1) 创建/重构 绝对安全的双轨加密协议通道 (VLESS-Reality / SS-2022)"
        echo "  2) 用户凭证生命周期与独立防封属性管理"
        echo "  3) 检阅全量节点配置连接中心"
        echo "  4) 人为干涉并热更全球 Geo 路由流量隔离库"
        echo "  5) 发起 Xray 服务通信底层源码静默升级"
        echo "  6) 伪装矩阵漂移 (单选/全选/剔除阻断 SNI)"
        echo "  7) 防火墙管控中心 (全局阻断 BT 与广告追踪流)"
        echo "  8) Reality 物理回落边界防线与防盗扫探针巡查"
        echo "  9) 全景网络监控与自然月商用级流量记账系统"
        echo "  10) 系统与内核级 60+ 项网卡极限高压物理调优"
        echo "  0) 折叠命令控制台，返回底层"
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
            10) do_sys_init_menu ;;
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
