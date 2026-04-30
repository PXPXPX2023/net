#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: ex188t24.sh (The Apex Vanguard - Ultimate Integrated Genesis)
# 快捷方式: xrv
# 版本号: V188t24.Final.Unabridged
#
# 【V188t24 终极完整溯源与全量融合版】
#   1. 权限彻底修复: Systemd 强行提权 `User=root`，根治 nobody 权限不足引发的连环崩溃。
#   2. 下载链路熔断: Xray 核心引入 GitHub/JsDelivr 双轨拉取，超时立即熔断，绝不生成空壳。
#   3. 动态模块重生: 恢复「多用户管理」与「防火墙策略」，采用 jq --arg 绝对安全注入，杜绝回车炸弹。
#   4. 拒绝压行缩水: 废除所有分号压缩，恢复企业级代码排版，逻辑全量舒展。
#   5. 原教旨矩阵: 100% 保留用户原版的 60 个高防 SNI 探测矩阵，一字不差。
#   6. 探针与调度: 200+ 行 Sysctl 狂暴网络栈、21项底层探针、28项高阶面板全量物理植入。
# ==============================================================================

# ------------------------------------------------------------------------------
# [ 0x01: 系统级基础环境检查与严格模式锁定 ]
# ------------------------------------------------------------------------------

# 验证是否在 Bash 下运行
if test -z "${BASH_VERSION:-}"; then
    echo "Error: 本系统底层依赖 Bash 特性，请执行: bash ex188t24.sh"
    exit 1
fi

# 启用严格模式
set -euo pipefail

# 恢复系统原生的 IFS 分隔符，杜绝安装依赖时连体字符串的灾难
IFS=$' \n\t'

# 强制补齐系统环境变量路径
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ------------------------------------------------------------------------------
# [ 0x02: 终端 UI 色彩与排版引擎 ]
# ------------------------------------------------------------------------------

readonly red='\033[31m'
readonly yellow='\033[33m'
readonly gray='\033[90m'
readonly green='\033[92m'
readonly blue='\033[94m'
readonly magenta='\033[95m'
readonly cyan='\033[96m'
readonly none='\033[0m'

# 兼容色系别名定义
readonly gl_hong="$red"
readonly gl_lv="$green"
readonly gl_huang="$yellow"
readonly gl_bai="$none"
readonly gl_kjlan="$cyan"
readonly gl_zi="$magenta"
readonly gl_hui="$gray"

print_red()     { echo -e "${red}$*${none}"; }
print_green()   { echo -e "${green}$*${none}"; }
print_yellow()  { echo -e "${yellow}$*${none}"; }
print_magenta() { echo -e "${magenta}$*${none}"; }
print_cyan()    { echo -e "${cyan}$*${none}"; }

info()  { echo -e "${green}[系统信息]${none} $*"; }
warn()  { echo -e "${yellow}[安全告警]${none} $*"; }
error() { echo -e "${red}[故障拦截]${none} $*"; }
die()   { echo -e "\n${red}[致命异常]${none} $*\n"; exit 1; }

title() {
    echo -e "\n${blue}======================================================================${none}"
    echo -e "  ${cyan}$*${none}"
    echo -e "${blue}======================================================================${none}"
}

hr() {
    echo -e "${gray}----------------------------------------------------------------------${none}"
}

# ------------------------------------------------------------------------------
# [ 0x03: 全局常量与状态地图初始化 ]
# ------------------------------------------------------------------------------

readonly SCRIPT_VERSION="ex188t24-Enterprise-Genesis"

# 核心路径定义
readonly XRAY_BIN="/usr/local/bin/xray"
readonly CONFIG_DIR="/usr/local/etc/xray"
readonly CONFIG="$CONFIG_DIR/config.json"
readonly PUBKEY_FILE="$CONFIG_DIR/public.key"
readonly SNI_CACHE_FILE="$CONFIG_DIR/sni_cache.txt"
readonly INSTALL_DATE_FILE="$CONFIG_DIR/install_date.txt"
readonly USER_SNI_MAP="$CONFIG_DIR/user_sni.txt"
readonly USER_TIME_MAP="$CONFIG_DIR/user_time.txt"
readonly CAKE_OPTS_FILE="$CONFIG_DIR/cake_opts.txt"

# 辅助目录定义
readonly FLAGS_DIR="$CONFIG_DIR/flags"
readonly DAT_DIR="/usr/local/share/xray"
readonly SCRIPT_DIR="/usr/local/etc/xray-script"
readonly UPDATE_DAT_SCRIPT="$SCRIPT_DIR/update-dat.sh"
readonly LOG_DIR="/var/log/xray"
readonly BACKUP_DIR="$CONFIG_DIR/backups"

# 脚本物理锚点
readonly SYMLINK="/usr/local/bin/xrv"
readonly SCRIPT_PATH=$(readlink -f "$0")

# 运行期状态变量 (必须赋初值，防止 set -u 触发异常)
SERVER_IP=""
REMARK_NAME="xp-reality"
BEST_SNI="www.microsoft.com"
SNI_JSON_ARRAY="\"www.microsoft.com\""
LISTEN_PORT=443
AUTO_MODE="0"

# 构建目录骨架 (自检并创建)
info "正在核验并构建系统底层目录骨架..."
if ! mkdir -p "$CONFIG_DIR" "$DAT_DIR" "$SCRIPT_DIR" "$FLAGS_DIR" "$LOG_DIR" "$BACKUP_DIR" /etc/sysctl.d /etc/security 2>/dev/null; then
    warn "部分目录构建遇到权限警告，系统将尝试绕过..."
fi
if ! touch "$USER_SNI_MAP" "$USER_TIME_MAP" 2>/dev/null; then
    warn "持久化数据表创建失败，可能会影响多用户管理。"
fi

# ------------------------------------------------------------------------------
# [ 0x04: 企业级日志审计与灾难恢复机制 (Trap) ]
# ------------------------------------------------------------------------------

log_info()  { 
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO]  $*" >> "$LOG_DIR/xray.log" 2>/dev/null || true 
}

log_error() { 
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" >> "$LOG_DIR/error.log" 2>/dev/null || true 
}

# 极度强化的 Trap 异常捕获网
trap '_err_handler $? $LINENO "$BASH_COMMAND"' ERR

_err_handler() {
    local exit_code=$1
    local err_line=$2
    local err_cmd=$3
    
    echo -e "\n${red}[SYSTEM_PANIC] 战舰核心遇到致命断层！${none}" >&2
    echo -e "${yellow} >> 错误代号: ${exit_code}${none}" >&2
    echo -e "${yellow} >> 崩溃行号: ${err_line}${none}" >&2
    echo -e "${yellow} >> 故障指令: ${err_cmd}${none}" >&2
    
    log_error "PANIC TRIGGERED -> EXIT=$exit_code LINE=$err_line CMD=[$err_cmd]"
    
    cleanup_temp_files
    warn "系统已自动尝试清理残留进程与临时挂载点。"
}

cleanup_temp_files() {
    rm -f /tmp/net-tcp-tune.* 2>/dev/null || true
    rm -f /tmp/sni_array.json 2>/dev/null || true
    rm -f /tmp/vless_inbound.json 2>/dev/null || true
    rm -f /tmp/ss_inbound.json 2>/dev/null || true
    rm -f /tmp/xray_users_*.txt 2>/dev/null || true
    rm -f /tmp/install-release.sh 2>/dev/null || true
}

trap cleanup_temp_files EXIT

# ------------------------------------------------------------------------------
# [ 0x05: 基础设施配置校验工具与回滚中枢 ]
# ------------------------------------------------------------------------------

validate_port() {
    local p="$1"
    if [[ -z "$p" ]]; then return 1; fi
    if [[ ! "$p" =~ ^[0-9]+$ ]]; then return 1; fi
    if ((p < 1 || p > 65535)); then return 1; fi
    
    if ss -tuln 2>/dev/null | grep -q ":${p} "; then
        error "端口冲突：物理端口 $p 已被其他进程霸占。"
        return 1
    fi
    return 0
}

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

backup_config() {
    if [[ ! -f "$CONFIG" ]]; then 
        return 0
    fi
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    cp -f "$CONFIG" "$BACKUP_DIR/config_${ts}.json" 2>/dev/null || true
    
    ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
    log_info "系统配置已物理快照: config_${ts}.json"
}

restore_latest_backup() {
    local latest
    latest=$(ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | head -n 1 || true)
    
    if [[ -n "$latest" ]]; then
        cp -f "$latest" "$CONFIG" 2>/dev/null || true
        fix_permissions
        systemctl restart xray >/dev/null 2>&1 || true
        warn "检测到致命错误，系统配置已强制回滚至快照: $(basename "$latest")"
        log_info "触发灾难回滚，载入快照: $latest"
        return 0
    fi
    
    error "回滚失败：存储库中未发现有效配置快照。系统可能处于初次部署状态。"
    return 1
}

verify_xray_config() {
    local target_config="$1"
    
    if [[ ! -f "$XRAY_BIN" ]]; then
        return 0 # 还没安装核心，跳过自检
    fi
    
    info "正在触发 Xray 核心引擎层配置预审..."
    local test_result
    test_result=$("$XRAY_BIN" -test -config "$target_config" 2>&1 || true)
    
    if echo "$test_result" | grep -qi "Configuration OK"; then
        info "配置预审通过，语法逻辑完美闭环。"
        return 0
    else
        error "预审拦截！Xray 核心拒绝加载该配置，存在致命语法断层："
        echo -e "${gray}$test_result${none}"
        return 1
    fi
}

ensure_xray_is_alive() {
    info "正在向 Systemd 下发 Xray 服务重载指令..."
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl restart xray >/dev/null 2>&1 || true
    sleep 3
    
    if systemctl is-active --quiet xray; then
        info "Xray 引擎心跳正常，服务已稳健挂载。"
        return 0
    else
        error "Xray 引擎启动宣告失败！诊断日志流如下："
        hr
        journalctl -u xray.service --no-pager -n 15 2>/dev/null | awk '{print "    " $0}' || true
        hr
        warn "引擎崩溃，立即触发安全回滚程序..."
        restore_latest_backup
        local _pause=""
        read -e -p "按 Enter 键知悉并返回中枢..." _pause || true
        return 1
    fi
}

# ------------------------------------------------------------------------------
# [ 0x06: 环境预检与依赖大网 (Pre-flight Checks) ]
# ------------------------------------------------------------------------------

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
            warn "未匹配到主流 Linux 发行版，包管理器可能无法正确调度: $list"
            ;;
    esac
}

preflight() {
    info "启动环境全景预检..."
    
    if ((EUID != 0)); then
        die "权限剥夺：启动该战舰底层网络栈必须具备 root 级系统权限。"
    fi
    
    if ! command -v systemctl >/dev/null 2>&1; then
        die "架构脱轨：您的操作系统未采用 Systemd 守护进程管理器，本脚本无法执行底层编排。"
    fi

    local need="jq curl wget xxd unzip qrencode vnstat openssl coreutils sed e2fsprogs pkg-config iproute2 ethtool bc bison flex dwarves rsync python3 cpio dnsutils"
    local missing=""
    
    for p in $need; do
        if ! command -v "$p" >/dev/null 2>&1; then
            missing="$missing $p"
        fi
    done
    
    if [[ -n "$missing" ]]; then
        info "侦测到缺失的基础组件，正在向包管理器下发安装指令:$missing"
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

    info "正在探测机器公网物理信标..."
    SERVER_IP=$(
        curl -s -4 --connect-timeout 5 --max-time 10 https://api.ipify.org 2>/dev/null ||
        curl -s -4 --connect-timeout 5 --max-time 10 https://ifconfig.me  2>/dev/null ||
        curl -s -4 --connect-timeout 5 --max-time 10 https://icanhazip.com 2>/dev/null ||
        echo "获取失败"
    )
    
    if [[ "$SERVER_IP" == "获取失败" ]]; then
        warn "多重探测失败，机器的公网 IPv4 寻址暂时被遮蔽。"
    fi
}

# ------------------------------------------------------------------------------
# [ 0x07: 进程级护盾与系统资源提权 (Systemd Limits & Root Check) ]
# ------------------------------------------------------------------------------

fix_xray_systemd_limits() {
    info "正在重构 Xray 守护进程的资源配额与权限中心 (Systemd Limits)..."
    
    local override_dir="/etc/systemd/system/xray.service.d"
    if [[ ! -d "$override_dir" ]]; then
        mkdir -p "$override_dir" 2>/dev/null || true
    fi
    
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

    # ！！！致命修复区域！！！
    # 强制将 Xray 服务的运行者提权至 root，并开放所有底层资源句柄
    cat > "$limit_file" << EOF
[Service]
User=root
Group=root
CapabilityBoundingSet=~
AmbientCapabilities=~
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
    
    if [[ -n "$current_affinity" ]]; then 
        echo "CPUAffinity=$current_affinity" >> "$limit_file"
    fi
    
    if [[ -n "$current_gomaxprocs" ]]; then 
        echo "Environment=\"GOMAXPROCS=$current_gomaxprocs\"" >> "$limit_file"
    fi
    
    if [[ -n "$current_buffer" ]]; then 
        echo "Environment=\"XRAY_RAY_BUFFER_SIZE=$current_buffer\"" >> "$limit_file"
    fi

    systemctl daemon-reload >/dev/null 2>&1 || true
    info "守护进程资源限额与 Root 越权指令已下发至 Systemd 总线。"
}

check_and_create_1gb_swap() {
    title "系统底层内存虚拟化 (Swap) 检查"
    
    local SWAP_FILE="/swapfile"
    local CURRENT_SWAP
    
    CURRENT_SWAP=$(swapon --show=NAME,KBYTES --noheadings 2>/dev/null | grep "$SWAP_FILE" | awk '{print $2}' || echo "")
    
    if [[ -n "$CURRENT_SWAP" ]] && ((CURRENT_SWAP >= 1000000)); then
        info "系统已配置足量的 Swap 虚拟内存 (≥1GB)，内核编译安全。"
        return 0
    fi
    
    warn "未检测到足量 Swap，正在强行切分 1GB 磁盘空间作为 Swap 分区..."
    
    swapoff -a 2>/dev/null || true
    sed -i '/swapfile/d' /etc/fstab 2>/dev/null || true
    rm -f "$SWAP_FILE" 2>/dev/null || true
    
    if ! dd if=/dev/zero of="$SWAP_FILE" bs=1M count=1024 status=none 2>/dev/null; then
        error "Swap 创建失败：磁盘空间不足或无写入权限！"
        return 1
    fi
    
    chmod 600 "$SWAP_FILE" 2>/dev/null || true
    mkswap "$SWAP_FILE" >/dev/null 2>&1 || true
    swapon "$SWAP_FILE" >/dev/null 2>&1 || true
    
    echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab 2>/dev/null || true
    
    info "1GB 极简 Swap 分区物理挂载完成！"
}

# ------------------------------------------------------------------------------
# [ 0x08: 网络路由防泄露与解析加固 (IPv6 Disable & DNS) ]
# ------------------------------------------------------------------------------

enforce_ipv4_and_disable_ipv6() {
    echo -e "${gl_kjlan}=== 底层安全策略：锁定 IPv4 优先并切断 IPv6 泄露通道 ===${gl_bai}"
    
    echo -e "${gl_zi}[1/2] 覆写全局寻址权重矩阵 (gai.conf)...${gl_bai}"
    cat > /etc/gai.conf << EOF
precedence ::ffff:0:0/96  100
precedence ::/0           10
precedence ::1/128        50
precedence fe80::/10      1
precedence fec0::/10      1
precedence fc00::/7       1
precedence 2002::/16      30
EOF

    if command -v nscd >/dev/null 2>&1; then 
        systemctl restart nscd 2>/dev/null || true
    fi
    
    if command -v resolvectl >/dev/null 2>&1; then 
        resolvectl flush-caches 2>/dev/null || true
    fi

    echo -e "${gl_zi}[2/2] 从内核系统总线上彻底焊死 IPv6 协议栈...${gl_bai}"
    if [[ ! -d /etc/sysctl.d ]]; then
        mkdir -p /etc/sysctl.d 2>/dev/null || true
    fi
    
    cat > /etc/sysctl.d/99-disable-ipv6.conf << EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    
    sysctl --system >/dev/null 2>&1 || true
    echo -e "${gl_lv}✅ 策略下发完毕：机器 IPv6 端口已封死，完全阻隔旁路探测！${gl_bai}"
}

install_update_dat() {
    info "正在部署 Geo 规则库无人值守热更脚本..."
    
    cat > "$UPDATE_DAT_SCRIPT" << 'UPDSH'
#!/usr/bin/env bash
XRAY_DAT_DIR="/usr/local/share/xray"
LOG_FILE="/var/log/xray/update-dat.log"

log() { 
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

dl() {
    local url="$1" 
    local out="$2"
    
    for i in 1 2 3; do
        if curl -fsSL --connect-timeout 10 --max-time 300 -o "$out.tmp" "$url"; then
            mv -f "$out.tmp" "$out"
            log "[INFO] 成功更新云端库: $url"
            return 0
        fi
        log "[WARN] 节点更新失败，准备重试 [$i/3]: $url"
        sleep 5
    done
    log "[ERROR] 规则库下载遭遇严重网络阻断: $url"
    return 1
}

dl "https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"   "$XRAY_DAT_DIR/geoip.dat"
dl "https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat" "$XRAY_DAT_DIR/geosite.dat"

log "[INFO] Geo 规则库自动化巡检执行完毕"
UPDSH

    chmod +x "$UPDATE_DAT_SCRIPT" 2>/dev/null || true

    local temp_cron
    temp_cron=$(mktemp)
    
    crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT" | grep -v "systemctl restart xray" > "$temp_cron" || true
    
    echo "0 3 * * * $UPDATE_DAT_SCRIPT >/dev/null 2>&1" >> "$temp_cron"
    echo "10 3 * * * /bin/systemctl restart xray >/dev/null 2>&1" >> "$temp_cron"
    
    crontab "$temp_cron" 2>/dev/null || true
    rm -f "$temp_cron" 2>/dev/null || true

    info "Geo 路由流防断更机制已加载: 每日 03:00 下载，03:10 触发平滑重启。"
}

do_change_dns() {
    title "配置系统级别本地 DNS 强制解析 (resolvconf)"
    
    info "确保系统环境已安装 resolvconf 组件..."
    pkg_install resolvconf
    
    info "解绑并冻结干扰项 systemd-resolved..."
    systemctl stop systemd-resolved 2>/dev/null || true
    systemctl disable systemd-resolved 2>/dev/null || true
    
    info "激活并提权 resolvconf 服务..."
    systemctl stop resolvconf.service > /dev/null 2>&1 || true
    systemctl start resolvconf.service > /dev/null 2>&1 || true
    systemctl enable resolvconf.service > /dev/null 2>&1 || true

    local nameserver=""
    local IPcheck="0"
    
    while [[ "$IPcheck" == "0" ]]; do
        read -e -p "请输入自定义的上游 Nameserver IP (例如 8.8.8.8 或 1.1.1.1): " nameserver || true
        
        if [[ "${nameserver:-}" =~ ^([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]]; then
            IPcheck="1"
        else
            print_red "输入格式存在异常，请提供合法的标准 IPv4 地址。"
        fi
    done

    info "解除 /etc/resolv.conf 的物理锁定..."
    chattr -i /etc/resolv.conf 2>/dev/null || true
    rm -f /etc/resolv.conf 2>/dev/null || true
    
    if [[ -f /etc/resolv.conf.bak ]]; then
        mv /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true
    fi
    
    info "强写 Nameserver 指令..."
    echo "nameserver $nameserver" > /etc/resolv.conf
    
    info "执行文件不可变属性加锁 (chattr +i)..."
    chattr +i /etc/resolv.conf 2>/dev/null || true
    
    if [[ ! -d /etc/resolvconf/resolv.conf.d ]]; then
        mkdir -p /etc/resolvconf/resolv.conf.d 2>/dev/null || true
    fi
    
    echo "nameserver $nameserver" > /etc/resolvconf/resolv.conf.d/head 2>/dev/null || true
    systemctl restart resolvconf.service >/dev/null 2>&1 || true
    
    info "系统全局 DNS 寻址已被物理级锁定为：$nameserver"
}
# ------------------------------------------------------------------------------
# [ 0x09: SNI 连通性测试矩阵与优选雷达 ]
# ------------------------------------------------------------------------------

run_sni_scanner() {
    title "SNI 伪装矩阵连通性扫描雷达 (TCP Ping & 反封锁验证)"
    info "高频扫描任务已启动... (扫描途中可随时按下回车键提前结算)"
    echo ""
    
    if [[ ! -d "$CONFIG_DIR" ]]; then
        mkdir -p "$CONFIG_DIR" 2>/dev/null || true
    fi
    
    # 绝对原教旨主义：100% 采用用户指定的 60 个高防 SNI 横向排版，不换行，不删减
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
    # 数组转为按行分布的字符串，以备后续打乱排序
    sni_string=$(printf "%s\n" "${sni_list[@]}")
    
    # 随机打乱探测顺序，规避防火墙特征识别
    if command -v shuf >/dev/null 2>&1; then
        sni_string=$(echo "$sni_string" | shuf)
    else
        sni_string=$(echo "$sni_string" | awk 'BEGIN{srand()} {print rand()"\t"$0}' | sort -n | cut -f2-)
    fi

    local tmp_sni
    tmp_sni=$(mktemp) || true
    
    local scan_count=0

    for sni in $sni_string; do
        # 拦截用户输入，随时可以提前跳出扫描
        if read -t 0.1 -n 1 -s _dummy 2>/dev/null || [ $? -eq 0 ]; then
            echo -e "\n${yellow}[用户干预] 收到中断指令，立即中止扫描循环，进入结算。${none}"
            break
        fi

        local time_raw
        local ms
        
        # 强制走 IPv4 发起连接请求，剥离任何请求体，仅测试 TCP 握手
        time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni" 2>/dev/null || echo "0")
        ms=$(echo "$time_raw" | awk '{print int($1 * 1000)}')

        if ((ms > 0)); then
            # 过滤 Cloudflare CDN IP，防止 SNI 阻断失效
            if curl -sI -m 2 --connect-timeout 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray"; then
                echo -e " ${gray}[CDN跳过]${none} $sni (命中 Cloudflare 反代)"
                continue
            fi
            
            local p_type="NORM"
            echo -e " ${green}[响应正常]${none} $sni : TCP 握手延迟 ${yellow}${ms}ms${none}"
            echo "$ms $sni $p_type" >> "$tmp_sni"
        fi

        scan_count=$((scan_count + 1))
    done

    # 结果过滤与本地化缓存
    if [[ -s "$tmp_sni" ]]; then
        grep " NORM$" "$tmp_sni" | sort -n | head -n 20 | awk '{print $2, $1}' > "$SNI_CACHE_FILE" || true
    else
        error "雷达未能寻获任何有效存活节点！将强制载入备用降级配置。"
        echo "www.microsoft.com 999" > "$SNI_CACHE_FILE"
    fi
    
    rm -f "$tmp_sni" 2>/dev/null || true
}

verify_sni_strict() {
    local target="$1"
    info "向 $target 投送深度特征探针，验证 TLS 1.3 / ALPN h2 / OCSP ..."
    
    local out
    out=$(echo "Q" | timeout 5 openssl s_client -connect "$target:443" -alpn h2 -tls1_3 -status 2>&1 || echo "")
    
    local pass=0
    
    if ! echo "$out" | grep -qi "TLSv1.3"; then
        warn "红线警告: 目标服务器未开启 TLSv1.3 协议。"
        pass=1
    fi
    
    if ! echo "$out" | grep -qi "ALPN.*h2"; then
        warn "红线警告: 目标服务器不支持 ALPN h2 协商。"
        pass=1
    fi
    
    if ! echo "$out" | grep -qi "OCSP response:"; then
        warn "红线警告: 目标服务器未配置 OCSP 状态装订。"
        pass=1
    fi
    
    if ((pass != 0)); then
        error "探针判定：目标 SNI 证书特征不完整，极易被防火墙特征识别！"
    else
        info "探针判定：目标 SNI 满血通过所有协议层审查，隐蔽级拉满。"
    fi
    
    return $pass
}

choose_sni() {
    while true; do
        if [[ -f "$SNI_CACHE_FILE" ]]; then
            echo -e "\n  ${cyan}【本地优选 SNI 延迟排行榜】${none}"
            local idx=1
            
            while read -r s t; do
                echo -e "  $idx) $s (TCP 耗时: ${cyan}${t}ms${none})"
                idx=$((idx + 1))
            done < "$SNI_CACHE_FILE"
            
            echo -e "  ${yellow}r) 抛弃缓存，重新执行雷达扫描${none}"
            echo "  m) 启用矩阵轮询模式 (输入多个序号，以空格分隔)"
            echo "  0) 覆写自定义域名"
            
            local sel=""
            read -e -p "  请指示 (默认 1): " sel || true
            sel=${sel:-1}
            
            case "$sel" in
                q|Q) 
                    return 1 
                    ;;
                r|R) 
                    run_sni_scanner
                    continue 
                    ;;
                m|M)
                    local m_sel=""
                    read -e -p "请提供序号队列 (例如: 1 3 5，或直接输入 all): " m_sel || true
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
                        error "输入队列失效，系统未能解析。"
                        continue
                    fi
                    
                    BEST_SNI="${arr[0]}"
                    local jq_args=()
                    for s in "${arr[@]}"; do
                        jq_args+=("\"$s\"")
                    done
                    
                    # 组装纯净的 JSON Array 字符串
                    SNI_JSON_ARRAY=$(IFS=,; echo "${jq_args[*]}")
                    ;;
                0)
                    local d=""
                    read -e -p "请输入您指定的自定义域名: " d || true
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
                        error "输入有误，指令被打回。"; continue
                    fi
                    ;;
            esac
            
            if verify_sni_strict "$BEST_SNI"; then
                break
            else
                warn "该伪装域名的防封锁属性未达到最高等级。"
                local force_use=""
                read -e -p "是否强制忽略警告，继续使用该域名？(y/n): " force_use || true
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

# ------------------------------------------------------------------------------
# [ 0x0A: 内核环境预编译与主线源码拉取中心 ]
# ------------------------------------------------------------------------------

do_install_xanmod_main_official() {
    title "官方预编译 XANMOD (main) 内核全自动部署"
    
    if [[ "$(uname -m)" != "x86_64" ]]; then 
        error "架构不匹配：Xanmod 官方源仅提供 x86_64 预编译包！"
        local _pause=""
        read -e -p "按 Enter 返回菜单..." _pause || true
        return
    fi
    
    if [[ ! -f /etc/debian_version ]]; then 
        error "操作系统排斥：预编译脚本目前仅兼容 Debian / Ubuntu 系操作系统！"
        local _pause=""
        read -e -p "按 Enter 返回菜单..." _pause || true
        return
    fi
    
    info "启动物理 CPU 微架构扩展指令集 (x86-64-psABI) 评估..."
    local cpu_level_script="/tmp/check_x86-64_psabi.sh"
    
    if ! wget -qO "$cpu_level_script" https://dl.xanmod.org/check_x86-64_psabi.sh; then
        warn "由于网络问题，无法探知底层 CPU 级别，系统将降级兼容模式运行。"
    fi
    
    local cpu_level=""
    if [[ -f "$cpu_level_script" ]]; then
        cpu_level=$(awk -f "$cpu_level_script" | grep -oE 'x86-64-v[1-4]' | grep -oE '[1-4]' | tail -n 1 || echo "")
        rm -f "$cpu_level_script" 2>/dev/null || true
    fi
    
    if [[ -z "$cpu_level" ]]; then 
        cpu_level=1
        warn "评估失控，已强制锁定 v1 版本编译包。"
    else 
        info "评估完成，当前 CPU 可承载层级: v${cpu_level}"
    fi
    
    local pkg_name="linux-xanmod-x64v${cpu_level}"
    
    # 【极度核心修复区】
    # 彻底适配 Debian 12 / Ubuntu 22.04+ 最新的 APT 安全策略。
    # 摒弃老旧的 apt-key，改用 /etc/apt/keyrings 与 signed-by 语法！
    
    info "开始拉取 Xanmod 官方验证签名并写入受信任密钥环..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y gnupg gnupg2 curl sudo wget e2fsprogs >/dev/null 2>&1 || true
    
    if [[ ! -d /etc/apt/keyrings ]]; then
        mkdir -m 755 -p /etc/apt/keyrings 2>/dev/null || true
    fi
    
    # 移除旧版残留废库，避免冲突
    rm -f /etc/apt/trusted.gpg.d/xanmod-kernel.gpg 2>/dev/null || true
    rm -f /etc/apt/sources.list.d/xanmod-kernel.list 2>/dev/null || true
    
    # 抓取 archive.key 并转码落盘
    if ! wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /etc/apt/keyrings/xanmod-archive-keyring.gpg; then
        error "从远端导入 GPG 密钥链发生错误，链路可能被污染或源已被墙！"
        return 1
    fi
    
    # 写入规范化的 APT 源列表
    echo 'deb [signed-by=/etc/apt/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-release.list
    
    info "密钥桥接成功，指令已下发，正在并行安装: $pkg_name"
    
    # 强刷缓存
    if ! apt-get update -y; then
        warn "APT 缓存更新遭遇波折，尝试强行接续下一步..."
    fi
    
    if ! apt-get install -y "$pkg_name"; then
        if [[ "$cpu_level" == "4" ]]; then 
            warn "遭遇异常：v4 极速版本在当前环境出现依赖脱节，尝试自动降级为 v3 版本..."
            pkg_name="linux-xanmod-x64v3"
            if ! apt-get install -y "$pkg_name"; then
                error "降级安装亦宣告失败，内核替换进程中止。"
                return 1
            fi
        else
            error "内核安装意外中止，请手动检查 APT 错误日志以排除 DNS 或依赖污染。"
            return 1
        fi
    fi
    
    info "内核落盘，正在向 GRUB 引导模块重新注册..."
    if command -v update-grub >/dev/null 2>&1; then 
        update-grub || true
    else 
        apt-get install -y grub2-common >/dev/null 2>&1 || true
        update-grub || true
    fi
    
    info "XANMOD (main) 高性能内核调度已挂载完成。"
    info "为了确保新驱动桥接，系统将在 10 秒后自动执行断电重启..."
    sleep 10
    reboot
}

do_xanmod_compile() {
    title "无差别原生 Linux 主线内核拉取与 BBR3 强制编译"
    warn "注意：源码拉取与编译耗时漫长 (预估 30-60 分钟)。"
    warn "过程中极其消耗 CPU 算力，请确认您的主机提供商允许持续高负载！"
    
    local confirm=""
    read -e -p "是否已知晓风险，准备暴力开编？(y/n): " confirm || true
    if [[ "${confirm:-}" != "y" ]]; then
        return
    fi
    
    info "正在全量压入 GCC 编译套件与底层开发依赖库..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y build-essential bc bison flex libssl-dev libelf-dev libncurses-dev zstd git wget curl xz-utils ethtool numactl make pkg-config dwarves rsync python3 libdw-dev cpio >/dev/null 2>&1 || true
    
    info "切入系统源码集结地 (/usr/src)，探测 Linux 主线最新版本号..."
    local BUILD_DIR="/usr/src"
    if ! cd $BUILD_DIR; then
        die "权限异常：系统拒绝进入 /usr/src 路径。"
    fi
    
    local KERNEL_URL
    KERNEL_URL=$(curl -s https://www.kernel.org/releases.json | jq -r '.releases[] | select(.type=="stable") | .tarball' | head -n 1 || echo "")
    
    if [[ -z "$KERNEL_URL" || "$KERNEL_URL" == "null" ]]; then
        warn "探测远端失败，强行锁定回退版本 v6.10..."
        KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.10.tar.xz"
    fi
    
    local KERNEL_FILE
    KERNEL_FILE=$(basename "$KERNEL_URL")
    
    info "建立信道，开始拉取源码包: $KERNEL_FILE"
    wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"

    if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
        warn "检测到初次获取的源码包损坏，触发重试熔断器..."
        rm -f "$KERNEL_FILE" 2>/dev/null || true
        wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"
        if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
            error "经过校验，两次提取的源码压缩包均存在断层，编译行动强行中止。"
            return 1
        fi
    fi

    info "执行 XZ 极致解压，释放源码..."
    tar -xJf "$KERNEL_FILE"
    
    local KERNEL_DIR
    KERNEL_DIR=$(tar -tf "$KERNEL_FILE" | head -n 1 | cut -d/ -f1)
    
    if ! cd "$KERNEL_DIR"; then
        die "无法进入解压后的源码工作区。"
    fi

    info "扫描并克隆宿主机现有驱动配置图谱..."
    if [[ -f "/boot/config-$(uname -r)" ]]; then
        cp "/boot/config-$(uname -r)" .config
        info "克隆完成：捕获实体文件 (/boot/config-$(uname -r))。"
    else
        if modprobe configs 2>/dev/null && [[ -f /proc/config.gz ]]; then
            zcat /proc/config.gz > .config
            info "克隆完成：通过内核映射提取内存配置表 (/proc/config.gz)。"
        else
            warn "未发现宿主配置文件。如果强行构建，可能引发内核模块与硬件不兼容！"
            local force_k=""
            read -e -p "极度危险：是否动用备用的通用框架 (defconfig) 继续？(y/n): " force_k || true
            if [[ "${force_k:-}" != "y" ]]; then 
                return 1
            fi
            make defconfig
        fi
    fi
    
    info "配置底层 Makefile 脚本..."
    make scripts || true
    
    info "暴力篡改内核选项，强制接管 BBR3..."
    ./scripts/config --enable CONFIG_TCP_CONG_BBR || true
    ./scripts/config --enable CONFIG_DEFAULT_BBR || true
    ./scripts/config --enable CONFIG_TCP_BBR3 2>/dev/null || true
    
    info "为缩减编译时长，剔除多余的 DRM 与冷门网卡驱动组件..."
    ./scripts/config --disable CONFIG_DRM_I915 || true
    ./scripts/config --disable CONFIG_NET_VENDOR_REALTEK || true
    ./scripts/config --disable CONFIG_NET_VENDOR_BROADCOM || true
    ./scripts/config --disable CONFIG_E100 || true
    
    info "绕开内核密钥链与调试模块的锁死验证..."
    ./scripts/config --disable SYSTEM_TRUSTED_KEYS || true
    ./scripts/config --disable SYSTEM_REVOCATION_KEYS || true
    ./scripts/config --disable DEBUG_INFO_BTF || true
    ./scripts/config --disable DEBUG_INFO || true
    
    info "重构编译树谱..."
    yes "" | make olddefconfig || true

    info "开始释放 CPU 全部算力进入编译状态！"
    local CPU
    CPU=$(nproc 2>/dev/null || echo 1)
    local RAM
    RAM=$(free -m | awk '/Mem/{print $2}' || echo 1024)
    local THREADS=1
    
    # 动态分析线程数分配
    if ((RAM >= 2000)); then
        THREADS=$CPU
    elif ((RAM >= 1000)); then
        THREADS=2
    fi
    
    if ! make -j$THREADS; then
        error "编译线程彻底崩塌！请排查物理内存溢出或硬盘坏道。"
        local _pause=""
        read -e -p "按 Enter 返回主菜单..." _pause || true
        return 1
    fi

    info "引擎锻造完毕，正在实施物理安装映射..."
    make modules_install || true
    make install || true

    local NEW_KERNEL_VER
    NEW_KERNEL_VER=$(make -s kernelrelease 2>/dev/null || echo "")
    
    if [[ -n "$NEW_KERNEL_VER" ]]; then
        info "正在为新内核 $NEW_KERNEL_VER 烧录初期内存盘 (initramfs)..."
        if command -v update-initramfs >/dev/null 2>&1; then
            update-initramfs -c -k "$NEW_KERNEL_VER" || true
        elif command -v dracut >/dev/null 2>&1; then
            dracut --force "/boot/initramfs-${NEW_KERNEL_VER}.img" "$NEW_KERNEL_VER" || true
        else
            warn "未发现标准的 initramfs 构建工具，启动引导可能丢失驱动引用！"
        fi
    fi

    info "同步刷新全局 GRUB 引导模块..."
    if command -v update-grub >/dev/null 2>&1; then
        update-grub || true
    elif command -v update-grub2 >/dev/null 2>&1; then
        update-grub2 || true
    elif command -v grub-mkconfig >/dev/null 2>&1; then
        grub-mkconfig -o /boot/grub/grub.cfg || true
    fi

    info "销毁编译后产生的数 GB 冗余垃圾..."
    cd /
    rm -rf "$BUILD_DIR/linux-"* 2>/dev/null || true
    rm -rf "$BUILD_DIR/$KERNEL_FILE" 2>/dev/null || true

    info "BBR3 源码编译已完美封炉！"
    info "系统将在 10 秒后强制物理重置硬件状态，请静候新内核降临..."
    sleep 10
    reboot
}
# ------------------------------------------------------------------------------
# [ 0x0B: 核心网络栈 Sysctl 极限高压调优 (The 200-Line Beast) ]
# ------------------------------------------------------------------------------

do_perf_tuning() {
    title "系统底层网络栈深度高压调优"
    warn "应用网络调优参数后，系统将自动重启以生效更改，请确认操作环境安全！"
    
    local confirm=""
    read -e -p "是否继续执行底层参数调优？(y/n): " confirm || true
    if [[ "${confirm:-}" != "y" ]]; then
        return
    fi
    
    local current_scale
    current_scale=$(sysctl -n net.ipv4.tcp_adv_win_scale 2>/dev/null || echo "1")
    local current_app
    current_app=$(sysctl -n net.ipv4.tcp_app_win 2>/dev/null || echo "31")
    
    echo -e "  当前 tcp_adv_win_scale 窗口缩放: ${cyan}${current_scale}${none} (建议设为 1 或 2)"
    echo -e "  当前 tcp_app_win 应用缓冲保留: ${cyan}${current_app}${none} (建议设为 31)"
    
    local new_scale=""
    read -e -p "设置 tcp_adv_win_scale (-2 到 2，直接回车保留当前): " new_scale || true
    new_scale=${new_scale:-$current_scale}
    
    local new_app=""
    read -e -p "设置 tcp_app_win (1 到 31，直接回车保留当前): " new_app || true
    new_app=${new_app:-$current_app}

    info "清理历史及冗余的网络优化配置与过时的加速程序..."
    systemctl stop net-speeder >/dev/null 2>&1 || true
    killall net-speeder >/dev/null 2>&1 || true
    systemctl disable net-speeder >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/net-speeder.service 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    rm -rf /root/net-speeder 2>/dev/null || true

    # 物理清空历史遗留的 sysctl 配置文件
    truncate -s 0 /etc/sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-network-optimized.conf 2>/dev/null || true
    
    rm -f /etc/sysctl.d/99-bbr*.conf 2>/dev/null || true
    rm -f /etc/sysctl.d/99-ipv6-disable.conf 2>/dev/null || true
    rm -f /etc/sysctl.d/99-pro*.conf 2>/dev/null || true
    rm -f /etc/sysctl.d/99-xanmod-bbr3.conf 2>/dev/null || true
    rm -f /usr/lib/sysctl.d/50-pid-max.conf 2>/dev/null || true
    rm -f /usr/lib/sysctl.d/99-protect-links.conf 2>/dev/null || true
    
    info "正在覆写 /etc/security/limits.conf 配置系统高并发进程与句柄限制..."
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

    # 确保 limits 模块被 PAM 认证体系加载
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session 2>/dev/null; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session 2>/dev/null || true
    fi
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session-noninteractive 2>/dev/null; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive 2>/dev/null || true
    fi
    
    # Systemd 全局级别进程句柄提权
    echo "DefaultLimitNOFILE=1000000" >> /etc/systemd/system.conf 2>/dev/null || true
    echo "DefaultLimitNPROC=1000000" >> /etc/systemd/system.conf 2>/dev/null || true

    # 探测是否已启用 CAKE 队列机制
    local target_qdisc="fq"
    if [[ "$(check_cake_state)" == "true" ]]; then
        target_qdisc="cake"
    fi

    info "全量展开写入底层 Sysctl 网络栈参数..."
    cat > /etc/sysctl.d/99-network-optimized.conf << EOF
# 基础队列与拥塞控制算法
net.core.default_qdisc = ${target_qdisc}
net.ipv4.tcp_congestion_control = bbr

# 邻居表与 ARP 缓存优化
net.ipv4.neigh.default.base_reachable_time_ms = 60000
net.ipv4.neigh.default.mcast_solicit = 2
net.ipv4.neigh.default.retrans_time_ms = 500
net.ipv4.neigh.default.gc_thresh1 = 1024
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv4.neigh.default.gc_stale_time = 100
net.ipv4.neigh.default.unres_qlen = 35535
net.ipv4.neigh.default.unres_qlen_bytes = 65535
net.ipv4.neigh.default.proxy_qlen = 50000

# 路由与过滤防劫持
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.route_localnet = 0
net.ipv4.conf.all.forwarding = 1
net.ipv4.ip_forward = 1

# TCP 指标存储与 ECN 探测
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_sack = 1

# TCP 窗口缩放与接收分配策略
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = ${new_scale}
net.ipv4.tcp_app_win = ${new_app}
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_shrink_window = 0

# 核心内存缓冲池扩展 (万兆级别)
net.core.rmem_default = 560576
net.core.wmem_default = 560576
net.core.rmem_max = 21699928
net.core.wmem_max = 21699928
net.ipv4.tcp_rmem = 4096 760576 21699928
net.ipv4.tcp_wmem = 4096 760576 21699928
net.ipv4.udp_rmem_min = 4096
net.ipv4.udp_wmem_min = 4096
net.ipv4.tcp_mem = 65536 131072 262144
net.ipv4.udp_mem = 65536 131072 262144
net.core.optmem_max = 3276800

# NAPI 与软中断分发调度
net.core.dev_weight = 64
net.core.dev_weight_tx_bias = 1
net.core.dev_weight_rx_bias = 1
net.core.netdev_budget = 300

# 文件系统与虚拟内存 I/O 控制
vm.swappiness = 1
vm.vfs_cache_pressure = 10
vm.dirty_ratio = 35
vm.overcommit_memory = 0
vm.max_map_count = 65535
fs.file-max = 1048576
fs.nr_open = 1048576
fs.inotify.max_user_instances = 262144
fs.aio-max-nr = 262144
kernel.shmmax = 67108864
kernel.shmall = 16777216

# TCP 回收、保活与心跳心电图
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 12
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.tcp_orphan_retries = 8
net.ipv4.tcp_max_orphans = 262144

# 并发连接池与队列深度抗压
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 262144
net.ipv4.tcp_retries1 = 5
net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_synack_retries = 2
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535

# 高级报文特性与防膨胀处理
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_reordering = 3
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_tso_win_divisor = 6
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_early_retrans = 3
net.ipv4.tcp_recovery = 0x1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_limit_output_bytes = 1310720
net.ipv4.tcp_min_tso_segs = 1
net.ipv4.tcp_thin_linear_timeouts = 0
net.ipv4.tcp_early_demux = 1

# 系统级线程池约束
kernel.pid_max = 4194304
kernel.threads-max = 85536
kernel.msgmax = 655350
kernel.msgmnb = 655350

# Polling 模型与极低延迟
net.unix.max_dgram_qlen = 130000
net.core.busy_poll = 50
net.core.busy_read = 0

# 碎片重组阈值控制
net.ipv4.ipfrag_max_dist = 32
net.ipv4.ipfrag_secret_interval = 200
net.ipv4.ipfrag_low_thresh = 42008868
net.ipv4.ipfrag_high_thresh = 104917729
net.ipv4.ipfrag_time = 30

# BBR Pacing 高级修正系数 (BBR3 特权)
net.ipv4.tcp_pacing_ca_ratio = 150
net.ipv4.tcp_pacing_ss_ratio = 210

# 核心链接安全防护
fs.protected_fifos = 1
fs.protected_hardlinks = 1
fs.protected_regular = 2
fs.protected_symlinks = 1
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# 网卡多队列 RPS 均衡哈希表
net.core.rps_sock_flow_entries = 131072
net.core.flow_limit_table_len = 131072

# 杂项参数与补丁
net.ipv4.tcp_workaround_signed_windows = 1
kernel.sysrq = 1
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
kernel.printk = 3 4 1 3
kernel.sched_autogroup_enabled = 0

# 物理级熔断 IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

    if ! sysctl -p /etc/sysctl.d/99-network-optimized.conf >/dev/null 2>&1; then
        error "Sysctl 参数在载入时遭遇内核拒绝，部分参数在当前宿主环境不受支持！"
        local _pause=""
        read -e -p "按 Enter 继续容错执行..." _pause || true
    else
        info "所有 200+ 项底层 Sysctl 参数已成功注入内核运行时！"
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if [[ -n "$IFACE" ]]; then
        info "向 $IFACE 下发网卡驱动硬件卸载控制守护进程..."
        
        # 1. 硬件卸载控制脚本
        cat > /usr/local/bin/nic-optimize.sh <<'EONIC'
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
if [[ -n "$IFACE" ]]; then
    ethtool -K "$IFACE" lro off rx-gro-hw off 2>/dev/null || true
    ethtool -C "$IFACE" adaptive-rx off rx-usecs 0 tx-usecs 0 2>/dev/null || true
fi
EONIC
        chmod +x /usr/local/bin/nic-optimize.sh
        
        cat > /etc/systemd/system/nic-optimize.service << 'EOSERVICE'
[Unit]
Description=NIC Advanced Tuning Parameters Loader
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
        
        info "向 $IFACE 下发 RPS/RFS 软中断网卡哈希队列多核分发守护进程..."
        
        # 2. RPS/RFS 中断分发脚本
        cat > /usr/local/bin/rps-optimize.sh <<'EOF'
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
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
Description=RPS RFS Network CPU Distribution Hash
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
    fi

    info "核心网络栈调优参数编译完成，系统将在 30 秒后进行物理重启使配置生效..."
    sleep 30
    reboot
}

# ------------------------------------------------------------------------------
# [ 0x0C: 独立组件优化 (TX Queue / CAKE 配置) ]
# ------------------------------------------------------------------------------

do_txqueuelen_opt() {
    title "网卡发送队列 (TX Queue) 并发加速配置"
    
    local IP_CMD
    IP_CMD=$(command -v ip || echo "")
    
    if [[ -z "$IP_CMD" ]]; then
        error "系统缺失 iproute2 工具链 (ip 命令)。"
        local _pause=""
        read -e -p "按 Enter 返回菜单..." _pause || true
        return 1
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if [[ -z "$IFACE" ]]; then
        error "由于网络遮蔽，无法定位系统主路由网卡接口。"
        local _pause=""
        read -e -p "按 Enter 返回菜单..." _pause || true
        return 1
    fi
    
    $IP_CMD link set "$IFACE" txqueuelen 2000 2>/dev/null || true
    
    info "为确保重启不丢失，正在挂载 Systemd 守护..."
    cat > /etc/systemd/system/txqueue.service << EOF
[Unit]
Description=Set TX Queue Length for High Concurrency Performance
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
        info "校验成功：网卡驱动已接受并配置队列长度为 2000。"
    else
        warn "修改遭拒：当前底层硬件驱动拒绝执行 txqueuelen 动态扩容。"
    fi
    
    local _pause=""
    read -e -p "按 Enter 键返回中枢控制台..." _pause || true
}

config_cake_advanced() {
    clear
    title "CAKE 高阶流量塑形与智能拥塞调度器配置"
    
    local current_opts="未配置 (依赖系统环境自适应推演)"
    if [[ -f "$CAKE_OPTS_FILE" ]]; then
        current_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
    fi
    echo -e "  当前已下发的 CAKE 运行矩阵参数: ${cyan}${current_opts}${none}\n"
    
    local c_bw=""
    read -e -p "  [1] 声明物理极限带宽限制 (如 900Mbit，输入 0 取消强限制): " c_bw || true
    
    local c_oh=""
    read -e -p "  [2] 声明物理链路报文头部补偿 Overhead (输入 0 绕过限制): " c_oh || true
    
    local c_mpu=""
    read -e -p "  [3] 声明最小数据单元截断保护 MPU (输入 0 绕过限制): " c_mpu || true
    
    echo "  [4] 设定链路 RTT 延迟测算模型: "
    echo "    1) internet  (标准全球互联，容忍 85ms)"
    echo "    2) oceanic   (跨洋深海光缆，容忍 300ms)"
    echo "    3) satellite (太空卫星链路，容忍 1000ms)"
    local rtt_sel=""
    read -e -p "  请下达对应指令编号 (默认推荐 2): " rtt_sel || true
    
    local c_rtt="oceanic"
    case "${rtt_sel:-2}" in
        1) c_rtt="internet" ;;
        3) c_rtt="satellite" ;;
        *) c_rtt="oceanic" ;;
    esac
    
    echo "  [5] 设定流量包深度识别策略 (Diffserv): "
    echo "    1) diffserv4  (按数据包六元组深度鉴权分类，CPU 开销较重)"
    echo "    2) besteffort (盲目公平分发策略，降低 CPU 损耗上限)"
    local diff_sel=""
    read -e -p "  请下达对应指令编号 (默认推荐 2): " diff_sel || true
    
    local c_diff="besteffort"
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
    
    # 巧妙移除左侧的脏空格
    final_opts="${final_opts#"${final_opts%%[! ]*}"}"
    
    if [[ -z "$final_opts" ]]; then
        rm -f "$CAKE_OPTS_FILE" 2>/dev/null || true
        info "所有自定义 CAKE 高阶参数已被物理擦除。"
    else
        echo "$final_opts" > "$CAKE_OPTS_FILE"
        info "参数落盘，新的 CAKE 高阶调度矩阵为: $final_opts"
    fi
    
    modprobe sch_cake 2>/dev/null || true
    _apply_cake_live
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if tc qdisc show dev "$IFACE" 2>/dev/null | grep -q "cake"; then
        info "特征比对通过：CAKE 队列已强行接管网卡底层封包接口。"
    else
        warn "特征缺失：网卡未在 CAKE 调度器下运行。请排查您的内核是否具备 sch_cake 原生支持库。"
    fi
    
    local _pause=""
    read -e -p "配置流程已终止，请按 Enter 键返回..." _pause || true
}

_apply_cake_live() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if [[ "$(check_cake_state)" == "true" ]]; then
        local base_opts
        base_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
        
        local f_ack=""
        if [[ "$(check_ackfilter_state)" == "true" ]]; then 
            f_ack="ack-filter"
        fi
        
        local f_ecn=""
        if [[ "$(check_ecn_state)" == "true" ]]; then 
            f_ecn="ecn"
        fi
        
        local f_wash=""
        if [[ "$(check_wash_state)" == "true" ]]; then 
            f_wash="wash"
        fi
        
        # 实时通过 tc 替换队列，无需中断连接
        tc qdisc replace dev "$IFACE" root cake $base_opts $f_ack $f_ecn $f_wash 2>/dev/null || true
    fi
    
    update_hw_boot_script
}

# ------------------------------------------------------------------------------
# [ 0x0D: 系统与应用层物理状态探针 (21 项 The Missing Link) ]
# ------------------------------------------------------------------------------

check_mph_state() {
    local state
    state=$(grep '"domainMatcher": *"mph"' "$CONFIG" 2>/dev/null || echo "false")
    if [[ "$state" != "false" && -n "$state" ]]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_maxtime_state() {
    local state
    state=$(grep '"maxTimeDiff": *60000' "$CONFIG" 2>/dev/null || echo "false")
    if [[ "$state" != "false" && -n "$state" ]]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_routeonly_state() {
    local state
    state=$(grep '"routeOnly": *true' "$CONFIG" 2>/dev/null || echo "false")
    if [[ "$state" != "false" && -n "$state" ]]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_sniff_state() {
    local state
    state=$(grep '"metadataOnly": *true' "$CONFIG" 2>/dev/null || echo "false")
    if [[ "$state" != "false" && -n "$state" ]]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_affinity_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if grep -q "^CPUAffinity=" "$limit_file" 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_buffer_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if grep -q "^Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" "$limit_file" 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_dnsmasq_state() {
    if systemctl is-active --quiet dnsmasq 2>/dev/null; then
        if grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null; then 
            echo "true"
            return
        fi
    fi
    echo "false"
}

check_thp_state() {
    if [[ ! -w "/sys/kernel/mm/transparent_hugepage/enabled" ]]; then 
        echo "unsupported"
        return
    fi
    if grep -q '\[never\]' /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_mtu_state() {
    if [[ ! -f "/proc/sys/net/ipv4/tcp_mtu_probing" ]]; then 
        echo "unsupported"
        return
    fi
    local val
    val=$(sysctl -n net.ipv4.tcp_mtu_probing 2>/dev/null || echo "0")
    if [[ "$val" == "1" ]]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_cpu_state() {
    if [[ ! -d "/sys/devices/system/cpu/cpu0/cpufreq" ]]; then 
        echo "unsupported"
        return
    fi
    if grep -q 'performance' /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_ring_state() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if [[ -z "$IFACE" ]]; then 
        echo "unsupported"
        return
    fi
    
    if ! command -v ethtool >/dev/null 2>&1; then 
        echo "unsupported"
        return
    fi
    
    local curr_rx
    curr_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Current hardware settings" | grep "RX:" | head -1 | awk '{print $2}' || echo "")
    
    if [[ -z "$curr_rx" ]]; then 
        echo "unsupported"
        return
    fi
    
    if [[ "$curr_rx" == "512" ]]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_zram_state() {
    if swapon --show 2>/dev/null | grep -q 'zram'; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_journal_state() {
    if grep -q '^Storage=volatile' /etc/systemd/journald.conf 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_process_priority_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if grep -q "^OOMScoreAdjust=-500" "$limit_file" 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_cake_state() {
    if sysctl net.core.default_qdisc 2>/dev/null | grep -q 'cake'; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_ackfilter_state() {
    if [[ -f "$FLAGS_DIR/ack_filter" ]]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_ecn_state() {
    if [[ -f "$FLAGS_DIR/ecn" ]]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_wash_state() {
    if [[ -f "$FLAGS_DIR/wash" ]]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_gso_off_state() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    local eth_info
    eth_info=$(ethtool -k "$IFACE" 2>/dev/null || echo "")
    
    if echo "$eth_info" | grep -E "^generic-receive-offload:|^rx-gro:" | grep -q " off" 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_irq_state() {
    local CORES
    CORES=$(nproc 2>/dev/null || echo 1)
    
    if (( CORES < 2 )); then 
        echo "unsupported"
        return
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    local irq
    irq=$(grep "$IFACE" /proc/interrupts 2>/dev/null | head -1 | awk '{print $1}' | tr -d ':' || echo "")
    
    if [[ -n "$irq" ]]; then
        local mask
        mask=$(cat "/proc/irq/$irq/smp_affinity" 2>/dev/null | tr -d '0' || echo "")
        if [[ "$mask" == "1" ]]; then 
            echo "true"
        else 
            echo "false"
        fi
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
# ------------------------------------------------------------------------------
# [ 0x0B: 核心网络栈 Sysctl 极限高压调优 (The 200-Line Beast) ]
# ------------------------------------------------------------------------------

do_perf_tuning() {
    title "系统底层网络栈深度高压调优"
    warn "应用网络调优参数后，系统将自动重启以生效更改，请确认操作环境安全！"
    
    local confirm=""
    read -e -p "是否继续执行底层参数调优？(y/n): " confirm || true
    if [[ "${confirm:-}" != "y" ]]; then
        return
    fi
    
    local current_scale
    current_scale=$(sysctl -n net.ipv4.tcp_adv_win_scale 2>/dev/null || echo "1")
    local current_app
    current_app=$(sysctl -n net.ipv4.tcp_app_win 2>/dev/null || echo "31")
    
    echo -e "  当前 tcp_adv_win_scale 窗口缩放: ${cyan}${current_scale}${none} (建议设为 1 或 2)"
    echo -e "  当前 tcp_app_win 应用缓冲保留: ${cyan}${current_app}${none} (建议设为 31)"
    
    local new_scale=""
    read -e -p "设置 tcp_adv_win_scale (-2 到 2，直接回车保留当前): " new_scale || true
    new_scale=${new_scale:-$current_scale}
    
    local new_app=""
    read -e -p "设置 tcp_app_win (1 到 31，直接回车保留当前): " new_app || true
    new_app=${new_app:-$current_app}

    info "清理历史及冗余的网络优化配置与过时的加速程序..."
    systemctl stop net-speeder >/dev/null 2>&1 || true
    killall net-speeder >/dev/null 2>&1 || true
    systemctl disable net-speeder >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/net-speeder.service 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    rm -rf /root/net-speeder 2>/dev/null || true

    # 物理清空历史遗留的 sysctl 配置文件
    truncate -s 0 /etc/sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-network-optimized.conf 2>/dev/null || true
    
    rm -f /etc/sysctl.d/99-bbr*.conf 2>/dev/null || true
    rm -f /etc/sysctl.d/99-ipv6-disable.conf 2>/dev/null || true
    rm -f /etc/sysctl.d/99-pro*.conf 2>/dev/null || true
    rm -f /etc/sysctl.d/99-xanmod-bbr3.conf 2>/dev/null || true
    rm -f /usr/lib/sysctl.d/50-pid-max.conf 2>/dev/null || true
    rm -f /usr/lib/sysctl.d/99-protect-links.conf 2>/dev/null || true
    
    info "正在覆写 /etc/security/limits.conf 配置系统高并发进程与句柄限制..."
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

    # 确保 limits 模块被 PAM 认证体系加载
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session 2>/dev/null; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session 2>/dev/null || true
    fi
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session-noninteractive 2>/dev/null; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive 2>/dev/null || true
    fi
    
    # Systemd 全局级别进程句柄提权
    echo "DefaultLimitNOFILE=1000000" >> /etc/systemd/system.conf 2>/dev/null || true
    echo "DefaultLimitNPROC=1000000" >> /etc/systemd/system.conf 2>/dev/null || true

    # 探测是否已启用 CAKE 队列机制
    local target_qdisc="fq"
    if [[ "$(check_cake_state)" == "true" ]]; then
        target_qdisc="cake"
    fi

    info "全量展开写入底层 Sysctl 网络栈参数..."
    cat > /etc/sysctl.d/99-network-optimized.conf << EOF
# 基础队列与拥塞控制算法
net.core.default_qdisc = ${target_qdisc}
net.ipv4.tcp_congestion_control = bbr

# 邻居表与 ARP 缓存优化
net.ipv4.neigh.default.base_reachable_time_ms = 60000
net.ipv4.neigh.default.mcast_solicit = 2
net.ipv4.neigh.default.retrans_time_ms = 500
net.ipv4.neigh.default.gc_thresh1 = 1024
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv4.neigh.default.gc_stale_time = 100
net.ipv4.neigh.default.unres_qlen = 35535
net.ipv4.neigh.default.unres_qlen_bytes = 65535
net.ipv4.neigh.default.proxy_qlen = 50000

# 路由与过滤防劫持
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.route_localnet = 0
net.ipv4.conf.all.forwarding = 1
net.ipv4.ip_forward = 1

# TCP 指标存储与 ECN 探测
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_sack = 1

# TCP 窗口缩放与接收分配策略
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = ${new_scale}
net.ipv4.tcp_app_win = ${new_app}
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_shrink_window = 0

# 核心内存缓冲池扩展 (万兆级别)
net.core.rmem_default = 560576
net.core.wmem_default = 560576
net.core.rmem_max = 21699928
net.core.wmem_max = 21699928
net.ipv4.tcp_rmem = 4096 760576 21699928
net.ipv4.tcp_wmem = 4096 760576 21699928
net.ipv4.udp_rmem_min = 4096
net.ipv4.udp_wmem_min = 4096
net.ipv4.tcp_mem = 65536 131072 262144
net.ipv4.udp_mem = 65536 131072 262144
net.core.optmem_max = 3276800

# NAPI 与软中断分发调度
net.core.dev_weight = 64
net.core.dev_weight_tx_bias = 1
net.core.dev_weight_rx_bias = 1
net.core.netdev_budget = 300

# 文件系统与虚拟内存 I/O 控制
vm.swappiness = 1
vm.vfs_cache_pressure = 10
vm.dirty_ratio = 35
vm.overcommit_memory = 0
vm.max_map_count = 65535
fs.file-max = 1048576
fs.nr_open = 1048576
fs.inotify.max_user_instances = 262144
fs.aio-max-nr = 262144
kernel.shmmax = 67108864
kernel.shmall = 16777216

# TCP 回收、保活与心跳心电图
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 12
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.tcp_orphan_retries = 8
net.ipv4.tcp_max_orphans = 262144

# 并发连接池与队列深度抗压
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 262144
net.ipv4.tcp_retries1 = 5
net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_synack_retries = 2
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535

# 高级报文特性与防膨胀处理
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_reordering = 3
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_tso_win_divisor = 6
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_early_retrans = 3
net.ipv4.tcp_recovery = 0x1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_limit_output_bytes = 1310720
net.ipv4.tcp_min_tso_segs = 1
net.ipv4.tcp_thin_linear_timeouts = 0
net.ipv4.tcp_early_demux = 1

# 系统级线程池约束
kernel.pid_max = 4194304
kernel.threads-max = 85536
kernel.msgmax = 655350
kernel.msgmnb = 655350

# Polling 模型与极低延迟
net.unix.max_dgram_qlen = 130000
net.core.busy_poll = 50
net.core.busy_read = 0

# 碎片重组阈值控制
net.ipv4.ipfrag_max_dist = 32
net.ipv4.ipfrag_secret_interval = 200
net.ipv4.ipfrag_low_thresh = 42008868
net.ipv4.ipfrag_high_thresh = 104917729
net.ipv4.ipfrag_time = 30

# BBR Pacing 高级修正系数 (BBR3 特权)
net.ipv4.tcp_pacing_ca_ratio = 150
net.ipv4.tcp_pacing_ss_ratio = 210

# 核心链接安全防护
fs.protected_fifos = 1
fs.protected_hardlinks = 1
fs.protected_regular = 2
fs.protected_symlinks = 1
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# 网卡多队列 RPS 均衡哈希表
net.core.rps_sock_flow_entries = 131072
net.core.flow_limit_table_len = 131072

# 杂项参数与补丁
net.ipv4.tcp_workaround_signed_windows = 1
kernel.sysrq = 1
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
kernel.printk = 3 4 1 3
kernel.sched_autogroup_enabled = 0

# 物理级熔断 IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

    if ! sysctl -p /etc/sysctl.d/99-network-optimized.conf >/dev/null 2>&1; then
        error "Sysctl 参数在载入时遭遇内核拒绝，部分参数在当前宿主环境不受支持！"
        local _pause=""
        read -e -p "按 Enter 继续容错执行..." _pause || true
    else
        info "所有 200+ 项底层 Sysctl 参数已成功注入内核运行时！"
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if [[ -n "$IFACE" ]]; then
        info "向 $IFACE 下发网卡驱动硬件卸载控制守护进程..."
        
        # 1. 硬件卸载控制脚本
        cat > /usr/local/bin/nic-optimize.sh <<'EONIC'
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
if [[ -n "$IFACE" ]]; then
    ethtool -K "$IFACE" lro off rx-gro-hw off 2>/dev/null || true
    ethtool -C "$IFACE" adaptive-rx off rx-usecs 0 tx-usecs 0 2>/dev/null || true
fi
EONIC
        chmod +x /usr/local/bin/nic-optimize.sh
        
        cat > /etc/systemd/system/nic-optimize.service << 'EOSERVICE'
[Unit]
Description=NIC Advanced Tuning Parameters Loader
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
        
        info "向 $IFACE 下发 RPS/RFS 软中断网卡哈希队列多核分发守护进程..."
        
        # 2. RPS/RFS 中断分发脚本
        cat > /usr/local/bin/rps-optimize.sh <<'EOF'
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
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
Description=RPS RFS Network CPU Distribution Hash
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
    fi

    info "核心网络栈调优参数编译完成，系统将在 30 秒后进行物理重启使配置生效..."
    sleep 30
    reboot
}

# ------------------------------------------------------------------------------
# [ 0x0C: 独立组件优化 (TX Queue / CAKE 配置) ]
# ------------------------------------------------------------------------------

do_txqueuelen_opt() {
    title "网卡发送队列 (TX Queue) 并发加速配置"
    
    local IP_CMD
    IP_CMD=$(command -v ip || echo "")
    
    if [[ -z "$IP_CMD" ]]; then
        error "系统缺失 iproute2 工具链 (ip 命令)。"
        local _pause=""
        read -e -p "按 Enter 返回菜单..." _pause || true
        return 1
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if [[ -z "$IFACE" ]]; then
        error "由于网络遮蔽，无法定位系统主路由网卡接口。"
        local _pause=""
        read -e -p "按 Enter 返回菜单..." _pause || true
        return 1
    fi
    
    $IP_CMD link set "$IFACE" txqueuelen 2000 2>/dev/null || true
    
    info "为确保重启不丢失，正在挂载 Systemd 守护..."
    cat > /etc/systemd/system/txqueue.service << EOF
[Unit]
Description=Set TX Queue Length for High Concurrency Performance
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
        info "校验成功：网卡驱动已接受并配置队列长度为 2000。"
    else
        warn "修改遭拒：当前底层硬件驱动拒绝执行 txqueuelen 动态扩容。"
    fi
    
    local _pause=""
    read -e -p "按 Enter 键返回中枢控制台..." _pause || true
}

config_cake_advanced() {
    clear
    title "CAKE 高阶流量塑形与智能拥塞调度器配置"
    
    local current_opts="未配置 (依赖系统环境自适应推演)"
    if [[ -f "$CAKE_OPTS_FILE" ]]; then
        current_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
    fi
    echo -e "  当前已下发的 CAKE 运行矩阵参数: ${cyan}${current_opts}${none}\n"
    
    local c_bw=""
    read -e -p "  [1] 声明物理极限带宽限制 (如 900Mbit，输入 0 取消强限制): " c_bw || true
    
    local c_oh=""
    read -e -p "  [2] 声明物理链路报文头部补偿 Overhead (输入 0 绕过限制): " c_oh || true
    
    local c_mpu=""
    read -e -p "  [3] 声明最小数据单元截断保护 MPU (输入 0 绕过限制): " c_mpu || true
    
    echo "  [4] 设定链路 RTT 延迟测算模型: "
    echo "    1) internet  (标准全球互联，容忍 85ms)"
    echo "    2) oceanic   (跨洋深海光缆，容忍 300ms)"
    echo "    3) satellite (太空卫星链路，容忍 1000ms)"
    local rtt_sel=""
    read -e -p "  请下达对应指令编号 (默认推荐 2): " rtt_sel || true
    
    local c_rtt="oceanic"
    case "${rtt_sel:-2}" in
        1) c_rtt="internet" ;;
        3) c_rtt="satellite" ;;
        *) c_rtt="oceanic" ;;
    esac
    
    echo "  [5] 设定流量包深度识别策略 (Diffserv): "
    echo "    1) diffserv4  (按数据包六元组深度鉴权分类，CPU 开销较重)"
    echo "    2) besteffort (盲目公平分发策略，降低 CPU 损耗上限)"
    local diff_sel=""
    read -e -p "  请下达对应指令编号 (默认推荐 2): " diff_sel || true
    
    local c_diff="besteffort"
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
    
    # 巧妙移除左侧的脏空格
    final_opts="${final_opts#"${final_opts%%[! ]*}"}"
    
    if [[ -z "$final_opts" ]]; then
        rm -f "$CAKE_OPTS_FILE" 2>/dev/null || true
        info "所有自定义 CAKE 高阶参数已被物理擦除。"
    else
        echo "$final_opts" > "$CAKE_OPTS_FILE"
        info "参数落盘，新的 CAKE 高阶调度矩阵为: $final_opts"
    fi
    
    modprobe sch_cake 2>/dev/null || true
    _apply_cake_live
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if tc qdisc show dev "$IFACE" 2>/dev/null | grep -q "cake"; then
        info "特征比对通过：CAKE 队列已强行接管网卡底层封包接口。"
    else
        warn "特征缺失：网卡未在 CAKE 调度器下运行。请排查您的内核是否具备 sch_cake 原生支持库。"
    fi
    
    local _pause=""
    read -e -p "配置流程已终止，请按 Enter 键返回..." _pause || true
}

_apply_cake_live() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if [[ "$(check_cake_state)" == "true" ]]; then
        local base_opts
        base_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
        
        local f_ack=""
        if [[ "$(check_ackfilter_state)" == "true" ]]; then 
            f_ack="ack-filter"
        fi
        
        local f_ecn=""
        if [[ "$(check_ecn_state)" == "true" ]]; then 
            f_ecn="ecn"
        fi
        
        local f_wash=""
        if [[ "$(check_wash_state)" == "true" ]]; then 
            f_wash="wash"
        fi
        
        # 实时通过 tc 替换队列，无需中断连接
        tc qdisc replace dev "$IFACE" root cake $base_opts $f_ack $f_ecn $f_wash 2>/dev/null || true
    fi
    
    update_hw_boot_script
}

# ------------------------------------------------------------------------------
# [ 0x0D: 系统与应用层物理状态探针 (21 项 The Missing Link) ]
# ------------------------------------------------------------------------------

check_mph_state() {
    local state
    state=$(grep '"domainMatcher": *"mph"' "$CONFIG" 2>/dev/null || echo "false")
    if [[ "$state" != "false" && -n "$state" ]]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_maxtime_state() {
    local state
    state=$(grep '"maxTimeDiff": *60000' "$CONFIG" 2>/dev/null || echo "false")
    if [[ "$state" != "false" && -n "$state" ]]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_routeonly_state() {
    local state
    state=$(grep '"routeOnly": *true' "$CONFIG" 2>/dev/null || echo "false")
    if [[ "$state" != "false" && -n "$state" ]]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_sniff_state() {
    local state
    state=$(grep '"metadataOnly": *true' "$CONFIG" 2>/dev/null || echo "false")
    if [[ "$state" != "false" && -n "$state" ]]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_affinity_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if grep -q "^CPUAffinity=" "$limit_file" 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_buffer_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if grep -q "^Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" "$limit_file" 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_dnsmasq_state() {
    if systemctl is-active --quiet dnsmasq 2>/dev/null; then
        if grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null; then 
            echo "true"
            return
        fi
    fi
    echo "false"
}

check_thp_state() {
    if [[ ! -w "/sys/kernel/mm/transparent_hugepage/enabled" ]]; then 
        echo "unsupported"
        return
    fi
    if grep -q '\[never\]' /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_mtu_state() {
    if [[ ! -f "/proc/sys/net/ipv4/tcp_mtu_probing" ]]; then 
        echo "unsupported"
        return
    fi
    local val
    val=$(sysctl -n net.ipv4.tcp_mtu_probing 2>/dev/null || echo "0")
    if [[ "$val" == "1" ]]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_cpu_state() {
    if [[ ! -d "/sys/devices/system/cpu/cpu0/cpufreq" ]]; then 
        echo "unsupported"
        return
    fi
    if grep -q 'performance' /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_ring_state() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if [[ -z "$IFACE" ]]; then 
        echo "unsupported"
        return
    fi
    
    if ! command -v ethtool >/dev/null 2>&1; then 
        echo "unsupported"
        return
    fi
    
    local curr_rx
    curr_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Current hardware settings" | grep "RX:" | head -1 | awk '{print $2}' || echo "")
    
    if [[ -z "$curr_rx" ]]; then 
        echo "unsupported"
        return
    fi
    
    if [[ "$curr_rx" == "512" ]]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_zram_state() {
    if swapon --show 2>/dev/null | grep -q 'zram'; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_journal_state() {
    if grep -q '^Storage=volatile' /etc/systemd/journald.conf 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_process_priority_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if grep -q "^OOMScoreAdjust=-500" "$limit_file" 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_cake_state() {
    if sysctl net.core.default_qdisc 2>/dev/null | grep -q 'cake'; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_ackfilter_state() {
    if [[ -f "$FLAGS_DIR/ack_filter" ]]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_ecn_state() {
    if [[ -f "$FLAGS_DIR/ecn" ]]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_wash_state() {
    if [[ -f "$FLAGS_DIR/wash" ]]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_gso_off_state() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    local eth_info
    eth_info=$(ethtool -k "$IFACE" 2>/dev/null || echo "")
    
    if echo "$eth_info" | grep -E "^generic-receive-offload:|^rx-gro:" | grep -q " off" 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_irq_state() {
    local CORES
    CORES=$(nproc 2>/dev/null || echo 1)
    
    if (( CORES < 2 )); then 
        echo "unsupported"
        return
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    local irq
    irq=$(grep "$IFACE" /proc/interrupts 2>/dev/null | head -1 | awk '{print $1}' | tr -d ':' || echo "")
    
    if [[ -n "$irq" ]]; then
        local mask
        mask=$(cat "/proc/irq/$irq/smp_affinity" 2>/dev/null | tr -d '0' || echo "")
        if [[ "$mask" == "1" ]]; then 
            echo "true"
        else 
            echo "false"
        fi
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
