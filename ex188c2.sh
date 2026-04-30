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
# ==============================================================================
# [ 区块 IV: 虚拟内存管理引擎 (Swap) ]
# ==============================================================================

check_and_suggest_swap() {
    local mem_total
    mem_total=$(free -m 2>/dev/null | awk 'NR==2{print $2}' || echo "1024")
    local swap_total
    swap_total=$(free -m 2>/dev/null | awk 'NR==3{print $2}' || echo "0")
    local recommended_swap=0
    local need_swap=0
    
    if [ "$mem_total" -lt 2048 ]; then
        need_swap=1
    elif [ "$mem_total" -lt 4096 ] && [ "$swap_total" -eq 0 ]; then
        need_swap=1
    fi
    
    if [ "$need_swap" -eq 0 ]; then
        return 0
    fi
    
    if [ "$mem_total" -lt 512 ]; then recommended_swap=1024
    elif [ "$mem_total" -lt 1024 ]; then recommended_swap=$((mem_total * 2))
    elif [ "$mem_total" -lt 2048 ]; then recommended_swap=$((mem_total * 3 / 2))
    elif [ "$mem_total" -lt 4096 ]; then recommended_swap=$mem_total
    else recommended_swap=4096; fi
    
    echo -e "\n${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo -e "${gl_huang}雷达探测：物理内存告急，存在因 OOM 宕机的极大风险！${gl_bai}"
    echo -e "  物理内存: ${gl_huang}${mem_total}MB${gl_bai} | 现存 Swap: ${gl_huang}${swap_total}MB${gl_bai}"
    echo -e "  系统建议配置防爆池大小: ${gl_lv}${recommended_swap}MB${gl_bai}"
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}\n"
    
    local confirm
    if [ "$AUTO_MODE" = "1" ]; then 
        confirm=Y
    else 
        read -e -p "$(echo -e "${gl_huang}是否授予权限自动开辟虚拟缓冲地带？(Y/N): ${gl_bai}")" confirm || true
    fi

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        add_swap "$recommended_swap"
    else
        echo -e "${gl_huang}已驳回建议，跳过操作。${gl_bai}"
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
    
    echo -e "${gl_lv}✅ 物理缓存区挂载完毕，容错上限被强行拉升至 ${new_swap}MB！${gl_bai}"
}

manage_swap() {
    while true; do
        clear
        echo -e "${gl_kjlan}=== 防 OOM 虚拟内存(Swap)控制中心 ===${gl_bai}"
        local mem_total
        mem_total=$(free -m 2>/dev/null | awk 'NR==2{print $2}' || echo "N/A")
        local swap_info
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
        local choice
        read -e -p "决策输入: " choice || true
        
        case "$choice" in
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
# [ 区块 V: 网络基础安全与 DNS 管控 ]
# ==============================================================================

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

    if command -v nscd &> /dev/null; then
        systemctl restart nscd 2>/dev/null || service nscd restart 2>/dev/null || true
    fi
    if command -v resolvectl &> /dev/null; then
        resolvectl flush-caches 2>/dev/null || true
    fi

    echo -e "${gl_zi}[2/2] 从内核系统总线上彻底焊死 IPv6 协议栈...${gl_bai}"
    cat > /etc/sysctl.d/99-disable-ipv6.conf << EOF
# 物理级熔断 IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sysctl --system >/dev/null 2>&1 || true

    echo -e "${gl_lv}✅ 策略下发完毕：机器 IPv6 端口已封死，完全阻隔旁路探测！${gl_bai}"
}

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

# ==============================================================================
# [ 区块 VI: Linux 内核环境与编译模块 (XanMod) ]
# ==============================================================================

install_xanmod_kernel() {
    clear
    echo -e "${gl_kjlan}=== 安装预编译 XANMOD (main) 官方内核 ===${gl_bai}"
    echo -e "${gl_huang}警告: 内核升级可能导致失联，操作前请确保有 VNC/Console 备用！${gl_bai}"
    
    local confirm
    if [ "$AUTO_MODE" = "1" ]; then 
        confirm=Y
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
    echo -e "${gl_zi}侦测到本机 CPU 支持级别: v${cpu_level}${gl_bai}"
    
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
    title "Kernel.org 主线源码提取与 BBRv3 硬核编译"
    warn "源码编译对 CPU 会造成持续 30-60 分钟的高热压榨，期间如 SSH 断裂将前功尽弃。"
    local confirm
    read -e -p "$(echo -e "${gl_huang}警告：确定要从沙盒编译内核吗？(Y/N): ${gl_bai}")" confirm || true
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then return; fi
    
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
        KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.10.tar.xz"
    fi
    
    KERNEL_FILE=$(basename "$KERNEL_URL")
    wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"

    if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
        rm -f "$KERNEL_FILE" 2>/dev/null || true
        wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"
        if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
            error "源码加密包被腐蚀，无法解压。"
            return 1
        fi
    fi

    tar -xJf "$KERNEL_FILE"
    KERNEL_DIR=$(tar -tf "$KERNEL_FILE" | head -n 1 | cut -d/ -f1)
    if ! cd "$KERNEL_DIR"; then die "源码仓库解构失败"; fi

    info "嗅探现役硬件参数并装填 BBRv3 开关..."
    if [[ -f "/boot/config-$(uname -r)" ]]; then
        cp "/boot/config-$(uname -r)" .config
    else
        if modprobe configs 2>/dev/null && [[ -f /proc/config.gz ]]; then
            zcat /proc/config.gz > .config 2>/dev/null || true
        else
            warn "未找到底层引路文件！盲眼编译可能引发系统绝症。"
            local force_k
            read -e -p "$(echo -e "${gl_huang}赌一把？(y/N): ${gl_bai}")" force_k || true
            if [[ ! "$force_k" =~ ^[Yy]$ ]]; then return 1; fi
            make defconfig 2>/dev/null || true
        fi
    fi
    
    make scripts >/dev/null 2>&1 || true
    ./scripts/config --enable CONFIG_TCP_CONG_BBR || true
    ./scripts/config --enable CONFIG_DEFAULT_BBR || true
    ./scripts/config --enable CONFIG_TCP_BBR3 2>/dev/null || true
    ./scripts/config --disable CONFIG_DRM_I915 || true
    ./scripts/config --disable SYSTEM_TRUSTED_KEYS || true
    ./scripts/config --disable DEBUG_INFO_BTF || true
    yes "" | make olddefconfig >/dev/null 2>&1 || true

    info "火炉已被点燃，引擎即将满载狂飙..."
    local CPU RAM THREADS
    CPU=$(nproc 2>/dev/null || echo 1)
    RAM=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo 1024)
    THREADS=1
    if ((RAM >= 2000)); then THREADS=$CPU; elif ((RAM >= 1000)); then THREADS=2; fi
    
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
        if command -v update-initramfs >/dev/null 2>&1; then
            update-initramfs -c -k "$NEW_KERNEL_VER" >/dev/null 2>&1 || true
        elif command -v dracut >/dev/null 2>&1; then
            dracut --force "/boot/initramfs-${NEW_KERNEL_VER}.img" "$NEW_KERNEL_VER" >/dev/null 2>&1 || true
        fi
    fi

    if command -v update-grub >/dev/null 2>&1; then update-grub >/dev/null 2>&1 || true; fi

    cd /
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
    
    local confirm
    read -e -p "你清楚自己在干什么并确定拔除 XanMod 吗？(y/N): " confirm || true
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        apt purge -y 'linux-*xanmod*' >/dev/null 2>&1 || true
        update-grub >/dev/null 2>&1 || true
        rm -f /etc/apt/sources.list.d/xanmod-release.list /usr/share/keyrings/xanmod-archive-keyring.gpg 2>/dev/null || true
        echo -e "${gl_lv}✅ 装甲已被剥离。${gl_bai}"
    fi
    break_end
}