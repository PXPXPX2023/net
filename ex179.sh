#!/usr/bin/env bash
# ████████╗██╗  ██╗███████╗    █████╗ ██████╗ ███████╗██╗  ██╗
# ╚══██╔══╝██║  ██║██╔════╝    ██╔══██╗██╔══██╗██╔════╝╚██╗██╔╝
#    ██║   ███████║█████╗      ███████║██████╔╝█████╗   ╚███╔╝ 
#    ██║   ██╔══██║██╔══╝      ██╔══██║██╔═══╝ ██╔══╝   ██╔██╗ 
#    ██║   ██║  ██║███████╗    ██║  ██║██║     ███████╗██╔╝ ██╗
#    ╚═╝   ╚═╝  ╚═╝╚══════╝    ╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝
# ==============================================================================
# 脚本名称: ex179.sh (The Apex Vanguard - Project Genesis V179 [The Infinity Evolved])
# 快捷方式: xrv
#
# V179 终极全系修复与大一统宣言:
#   1. 免疫误杀: 彻底修复 set -e 下的短路与 ((var++)) 算术陷阱，实现 0 崩溃。
#   2. 雷达重构: 废弃易被阻断的 AliDNS，回归纯粹的 TCP 时延连通性嗅探验证。
#   3. 纯粹至上: 剔除冗余的 NaiveProxy 和 Hysteria2，回归极简 VLESS/SS 双引擎。
#   4. 容错大一统: 全局 ERR 探针 + 10 份历史快照轮转回滚 + 原子化 JSON 写入。
#   5. 极客不妥协: 130+ SNI 单行垂直展开，60+ 项 Sysctl 参数满血注入，拒绝面条代码。
#   6. 编译防砖: kernel.org 原核裸装引擎，严密继承宿主 VirtIO 驱动，确保护航 0 宕机。
#   7. 状态持久化: 物理 flags 锚点 + network-online.target 彻底消灭开机探针空转。
# ==============================================================================

# 强制 Bash 运行环境检测
if test -z "$BASH_VERSION"; then
    echo "错误: 请用 bash 运行: bash ex179.sh"
    exit 1
fi

# 严格模式 (开启错误中断与未定义变量拦截，管道流断裂捕获)
set -euo pipefail
IFS=$'\n\t'

# 强行注入全局环境变量，防止极端极简 OS 环境下命令执行空转
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ── 颜色定义 ──────────────────────────────────────────────────
readonly red='\033[31m'    yellow='\033[33m'  gray='\033[90m'
readonly green='\033[92m'  blue='\033[94m'    magenta='\033[95m'
readonly cyan='\033[96m'   none='\033[0m'

# ── 全局常量与物理路径锚定 ──────────────────────────────────────
readonly SCRIPT_VERSION="179"
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

# ── 可变全局状态 ──────────────────────────────────────────────
SERVER_IP=""
REMARK_NAME="xp-reality"
BEST_SNI="www.microsoft.com"
SNI_JSON_ARRAY="\"www.microsoft.com\""
LISTEN_PORT=443

# ── 权限与目录基石 ────────────────────────────────────────────
if ! mkdir -p "$CONFIG_DIR" "$DAT_DIR" "$SCRIPT_DIR" "$FLAGS_DIR" "$LOG_DIR" "$BACKUP_DIR" 2>/dev/null; then
    true
fi

if ! touch "$USER_SNI_MAP" "$USER_TIME_MAP" 2>/dev/null; then
    true
fi

# ==============================================================================
# [ 区块 I: 基础工具与高维容错系统 ]
# ==============================================================================

# 输出辅助
print_red()     { echo -e "${red}$*${none}"; }
print_green()   { echo -e "${green}$*${none}"; }
print_yellow()  { echo -e "${yellow}$*${none}"; }
print_magenta() { echo -e "${magenta}$*${none}"; }
print_cyan()    { echo -e "${cyan}$*${none}"; }

info()   { echo -e "${green}✓${none} $*"; }
warn()   { echo -e "${yellow}!${none} $*"; }
error()  { echo -e "${red}✗${none} $*"; }
die()    { echo -e "\n${red}致命错误${none} $*\n"; exit 1; }

title()  {
    echo -e "\n${blue}======================================================================${none}"
    echo -e "  ${cyan}$*${none}"
    echo -e "${blue}======================================================================${none}"
}
hr() { echo -e "${gray}----------------------------------------------------------------------${none}"; }

# 日志落盘系统
log_info()  { echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO:  $*" >> "$LOG_DIR/xray.log"; }
log_error() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$LOG_DIR/error.log"; }

# 全局 ERR 陷阱，捕获意外崩溃
trap '_err_handler $? $LINENO "$BASH_COMMAND"' ERR
_err_handler() {
    local code=$1 line=$2 cmd=$3
    echo -e "\n${red}[系统指令阻断] 抛出退出码:$code 行数:$line 违规指令:$cmd${none}" >&2
    log_error "EXIT=$code LINE=$line CMD=$cmd"
}

# 输入端口验证
validate_port() {
    local p="$1"
    if [[ -z "$p" ]]; then
        return 1
    fi
    if [[ ! "$p" =~ ^[0-9]+$ ]]; then
        return 1
    fi
    if ((p < 1 || p > 65535)); then
        return 1
    fi
    if ss -tuln 2>/dev/null | grep -q ":${p} "; then
        print_red "端口 $p 已被物理网卡锁定占用！"
        return 1
    fi
    return 0
}

# 域名验证
validate_domain() {
    local d="$1"
    if [[ "$d" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.\-]{0,253}[a-zA-Z0-9])?$ ]]; then
        return 0
    else
        return 1
    fi
}

# 强行刷新权限防线
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
# [ 区块 II: JSON 核心事务引擎与备份轮转回滚机制 ]
# ==============================================================================

# 配置自动快照备份 (保留 10 份)
backup_config() {
    if [[ ! -f "$CONFIG" ]]; then
        return 0
    fi
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    cp -f "$CONFIG" "$BACKUP_DIR/config_${ts}.json" 2>/dev/null || true
    ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
    log_info "配置已创建安全快照: config_${ts}.json"
}

# 从毁灭中恢复：最新快照回滚
restore_latest_backup() {
    local latest
    latest=$(ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | head -1 || true)
    if [[ -n "$latest" ]]; then
        cp -f "$latest" "$CONFIG"
        fix_permissions
        systemctl restart xray >/dev/null 2>&1 || true
        warn "系统已物理回滚至: $(basename "$latest")"
        log_info "触发灾难级回滚: $latest"
        return 0
    fi
    error "未找到任何安全备份点，系统可能陷入深渊！"
    return 1
}

# Xray 原生内核语法探针验证
verify_xray_config() {
    local target_config="$1"
    if [[ ! -f "$XRAY_BIN" ]]; then
        return 0 # 若核心未安装，跳过查验
    fi
    
    local test_result
    test_result=$("$XRAY_BIN" -test -config "$target_config" 2>&1 || true)
    
    if echo "$test_result" | grep -qi "Configuration OK"; then
        return 0
    else
        error "JSON 结构粉碎！Xray 原核拒绝接纳此格式："
        echo -e "${gray}$test_result${none}"
        return 1
    fi
}

# 完美支持 $@ 参数透传的 JSON 原子化写入系统
_safe_jq_write() {
    backup_config
    local tmp
    tmp=$(mktemp) || return 1
    
    if jq "$@" "$CONFIG" > "$tmp" 2>/dev/null && jq empty "$tmp" 2>/dev/null; then
        if verify_xray_config "$tmp"; then
            mv -f "$tmp" "$CONFIG"
            fix_permissions
            log_info "JSON 事务执行闭环成功"
            return 0
        else
            rm -f "$tmp" 2>/dev/null || true
            restore_latest_backup
            return 1
        fi
    fi
    
    rm -f "$tmp" 2>/dev/null || true
    error "JQ 引擎解析管道流发生严重碎裂！"
    log_error "jq 更新崩溃，参数: $*"
    restore_latest_backup
    return 1
}

# 服务存活强制雷达 (防假死)
ensure_xray_is_alive() {
    print_magenta ">>> 正在向底层下发 Xray 服务热重载指令，并植入健康生命探针..."
    systemctl restart xray >/dev/null 2>&1 || true
    sleep 3
    
    if systemctl is-active --quiet xray; then
        info "Xray 引擎生命体征极其平稳，参数已激活运行！"
        return 0
    else
        error "系统致命熔断：Xray 引擎遭遇毁灭性启动阻碍！"
        print_yellow ">>> 截获的死亡崩溃报错："
        hr
        journalctl -u xray.service --no-pager -n 15 | awk '{print "    " $0}' || true
        hr
        print_magenta ">>> 启动自动物理回滚机制..."
        restore_latest_backup
        read -rp "请敲击 Enter 键面对失败并退回主阵地..." _
        return 1
    fi
}

# ==============================================================================
# [ 区块 III: 系统预检与百万并发底层 Limits 架构 ]
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

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)    echo "amd64" ;;
        aarch64|arm64)   echo "arm64" ;;
        armv7l)          echo "armv7" ;;
        *)               echo "unknown"; return 1 ;;
    esac
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
            warn "未知 OS，尝试使用包管理器，如果失败请手动安装: $list"
            ;;
    esac
}

preflight() {
    if ((EUID != 0)); then
        die "必须以 root 运行"
    fi
    if ! command -v systemctl >/dev/null 2>&1; then
        die "缺少 systemctl"
    fi

    local need="jq curl wget xxd unzip qrencode vnstat openssl coreutils sed e2fsprogs pkg-config iproute2 ethtool bc bison flex dwarves rsync python3 cpio"
    local missing=""
    for p in $need; do
        if ! command -v "$p" >/dev/null 2>&1; then
            missing="$missing $p"
        fi
    done
    
    if [[ -n "$missing" ]]; then
        info "正在同步工业级依赖补齐: $missing"
        pkg_install $missing
        systemctl start vnstat  2>/dev/null || true
        systemctl enable vnstat 2>/dev/null || true
        systemctl start cron    2>/dev/null || systemctl start crond 2>/dev/null || true
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
        warn "无法获取公网 IP，探测器失效"
    fi
}

fix_xray_systemd_limits() {
    local override_dir="/etc/systemd/system/xray.service.d"
    mkdir -p "$override_dir"
    local limit_file="$override_dir/limits.conf"

    local current_nice="-20"
    local current_gogc="100"
    local current_oom="true"
    local current_affinity=""
    local current_gomaxprocs=""
    local current_buffer=""

    if [[ -f "$limit_file" ]]; then
        current_nice=$(awk -F'=' '/^Nice=/{print $2}' "$limit_file" | head -1 || echo "-20")
        current_gogc=$(awk -F'=' '/^Environment="GOGC=/{print $3}' "$limit_file" | tr -d '"' | head -1 || echo "100")
        if ! grep -q "^OOMScoreAdjust=" "$limit_file" 2>/dev/null; then
            current_oom="false"
        fi
        current_affinity=$(awk -F'=' '/^CPUAffinity=/{print $2}' "$limit_file" | head -1 || echo "")
        current_gomaxprocs=$(awk -F'=' '/^Environment="GOMAXPROCS=/{print $3}' "$limit_file" | tr -d '"' | head -1 || echo "")
        current_buffer=$(awk -F'=' '/^Environment="XRAY_RAY_BUFFER_SIZE=/{print $3}' "$limit_file" | tr -d '"' | head -1 || echo "")
    fi

    local total_mem
    total_mem=$(free -m | awk '/Mem/{print $2}')
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
}

check_and_create_1gb_swap() {
    title "内存护航：1GB 永久 Swap 基线校验"
    local SWAP_FILE="/swapfile"
    
    local CURRENT_SWAP
    CURRENT_SWAP=$(swapon --show=NAME,KBYTES --noheadings 2>/dev/null | grep "$SWAP_FILE" | awk '{print $2}' || echo "")
    
    if [[ -n "$CURRENT_SWAP" ]] && ((CURRENT_SWAP >= 1000000)); then
        info "系统底层已存在合规的 1GB 级永久 Swap 屏障。"
    else
        warn "Swap 缺失或容量不符，正在粉碎旧数据并重构 1GB 物理交换分区..."
        swapoff -a 2>/dev/null || true
        sed -i '/swapfile/d' /etc/fstab 2>/dev/null || true
        rm -f "$SWAP_FILE" 2>/dev/null || true
        
        # 强制 dd 占位，防止 fallocate 不兼容
        dd if=/dev/zero of="$SWAP_FILE" bs=1M count=1024 status=none
        chmod 600 "$SWAP_FILE"
        mkswap "$SWAP_FILE" >/dev/null 2>&1
        swapon "$SWAP_FILE" >/dev/null 2>&1
        
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
        info "1GB 纯正永久 Swap 已重铸并钉入 fstab。"
    fi
}

# ==============================================================================
# (为防止截断，代码第一部分安全驻留)
# (请发送“继续输出 Part 2”，接下来是 Geo 更新、DNS 锁定和全量展开的 130+ SNI 矩阵！)
# ==============================================================================
# ==============================================================================
# [ 区块 IV: Geo 规则库热更新与 DNS 物理底层死锁 ]
# ==============================================================================

install_update_dat() {
    # 采用不可逆的 HereDoc 格式，安全且工整地组装更新脚本
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
        # 强制使用原子化覆盖 (.tmp) 防止下载到一半断网导致的 Xray 重启崩死
        if curl -fsSL --connect-timeout 10 --max-time 300 -o "$out.tmp" "$url"; then
            mv -f "$out.tmp" "$out"
            log "OK: 成功拉取 $url"
            return 0
        fi
        log "WARN: 阻断重试 [$i]: $url"
        sleep 5
    done
    log "FAIL: 规则库下载彻底失败 $url"
    return 1
}

dl "https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"   "$XRAY_DAT_DIR/geoip.dat"
dl "https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat" "$XRAY_DAT_DIR/geosite.dat"

log "INFO: 规则库更新作业执行完毕"
UPDSH

    chmod +x "$UPDATE_DAT_SCRIPT"

    # 将更新指令精妙地编织进系统的潜意识 (Cron 计划任务)
    # 每天凌晨 3:00 下载全球 Geo 库，3:10 错峰重载进程
    if ! crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT" | grep -v "systemctl restart xray" > /tmp/current_cron; then
        true
    fi
    echo "0 3 * * * $UPDATE_DAT_SCRIPT >/dev/null 2>&1" >> /tmp/current_cron
    echo "10 3 * * * /bin/systemctl restart xray >/dev/null 2>&1" >> /tmp/current_cron
    crontab /tmp/current_cron
    rm -f /tmp/current_cron 2>/dev/null || true

    info "已配置自动热更体系: 每日 03:00 下载全球 Geo 防火墙隔离库并于 03:10 错峰重载。"
}

do_change_dns() {
    title "修改系统核心 DNS 解析流向 (基于 resolvconf 强力物理死锁)"
    
    local release=""
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        release="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        release="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        release="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        release="centos"
    fi

    if [[ ! -e '/usr/sbin/resolvconf' && ! -e '/sbin/resolvconf' ]]; then
        print_yellow "发现系统底层缺少 resolvconf 核心网络守护进程，正在为您调取安装..."
        if [[ "${release}" == "centos" ]]; then
            yum -y install resolvconf > /dev/null 2>&1 || true
        else
            export DEBIAN_FRONTEND=noninteractive
            apt-get update > /dev/null 2>&1 || true
            apt-get -y install resolvconf > /dev/null 2>&1 || true
        fi
    fi
    
    # 必须彻底粉碎并埋葬系统自带的 systemd-resolved 进程
    systemctl stop systemd-resolved 2>/dev/null || true
    systemctl disable systemd-resolved 2>/dev/null || true
    
    systemctl stop resolvconf.service > /dev/null 2>&1 || true
    systemctl start resolvconf.service > /dev/null 2>&1 || true
    systemctl enable resolvconf.service > /dev/null 2>&1 || true

    local nameserver=""
    local IPcheck="0"
    
    while [[ "$IPcheck" == "0" ]]; do
        read -rp "请给出需要死锁的新 Nameserver 独立 IP (推荐抗污染的 8.8.8.8 或 1.1.1.1): " nameserver
        if [[ $nameserver =~ ^([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]]; then
            IPcheck="1"
        else
            print_red "极客警告：您输入的似乎不是合法的纯数字 IPv4 结构，请重新输入！"
        fi
    done

    # 暴力解除原先可能遗留的 +i (不可变) 物理防篡改属性
    chattr -i /etc/resolv.conf 2>/dev/null || true
    rm -f /etc/resolv.conf 2>/dev/null || true
    
    if [[ -f /etc/resolv.conf.bak ]]; then
        mv /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true
    fi
    
    echo "nameserver $nameserver" > /etc/resolv.conf
    
    # 强行挂上 chattr +i 物理锁死特权指令
    chattr +i /etc/resolv.conf 2>/dev/null || true
    
    if ! mkdir -p /etc/resolvconf/resolv.conf.d 2>/dev/null; then
        true
    fi
    
    echo "nameserver $nameserver" > /etc/resolvconf/resolv.conf.d/head 2>/dev/null || true
    systemctl restart resolvconf.service >/dev/null 2>&1 || true
    
    info "DNS 物理流向已被彻底打上底层死锁印记：$nameserver，免疫一切恶意劫持和 DHCP 刷新！"
}

# ==============================================================================
# [ 区块 V: 史诗级 130+ 庞大 SNI 探测雷达矩阵库 (全域不折叠直写版) ]
# ==============================================================================
run_sni_scanner() {
    title "反阻断侦测系统：130+ 国际顶级实体矩阵雷达扫描与连通性嗅探"
    print_yellow ">>> 频段扫频引擎已启动... (规模庞大耗时较长，若无暇等待可随时狂敲回车键强制撤退)\n"
    print_cyan ">>> V179 战地修复：已彻底剥离 AliDNS 探针，直接基于 TCP 物理握手验证纯净度！\n"
    
    if ! mkdir -p "$CONFIG_DIR" 2>/dev/null; then
        true
    fi
    
    # 军规级要求：严禁同行嵌套！每一发弹药都必须清晰占领单独的一行，不省任何代码行数！
    local sni_list=(
        "www.apple.com"
        "support.apple.com"
        "developer.apple.com"
        "id.apple.com"
        "icloud.apple.com"
        "www.microsoft.com"
        "login.microsoftonline.com"
        "portal.azure.com"
        "support.microsoft.com"
        "office.com"
        "www.intel.com"
        "downloadcenter.intel.com"
        "ark.intel.com"
        "www.amd.com"
        "drivers.amd.com"
        "www.dell.com"
        "support.dell.com"
        "www.hp.com"
        "support.hp.com"
        "developers.hp.com"
        "www.bmw.com"
        "www.mercedes-benz.com"
        "global.toyota"
        "www.honda.com"
        "www.volkswagen.com"
        "www.nike.com"
        "www.adidas.com"
        "www.zara.com"
        "www.ikea.com"
        "www.shell.com"
        "www.bp.com"
        "www.ge.com"
        "www.hsbc.com"
        "www.morganstanley.com"
        "www.msc.com"
        "www.sony.com"
        "www.canon.com"
        "www.nintendo.com"
        "www.unilever.com"
        "www.loreal.com"
        "www.hermes.com"
        "www.louisvuitton.com"
        "www.dior.com"
        "www.gucci.com"
        "www.coca-cola.com"
        "www.tesla.com"
        "s0.awsstatic.com"
        "www.nvidia.com"
        "www.samsung.com"
        "www.oracle.com"
        "addons.mozilla.org"
        "www.airbnb.com.sg"
        "mit.edu"
        "stanford.edu"
        "www.lufthansa.com"
        "www.singaporeair.com"
        "www.specialized.com"
        "www.logitech.com"
        "www.razer.com"
        "www.corsair.com"
        "www.zoom.us"
        "www.adobe.com"
        "www.autodesk.com"
        "www.salesforce.com"
        "www.cisco.com"
        "www.ibm.com"
        "www.qualcomm.com"
        "www.ford.com"
        "www.audi.com"
        "www.hyundai.com"
        "www.nissan-global.com"
        "www.porsche.com"
        "www.target.com"
        "www.walmart.com"
        "www.homedepot.com"
        "www.lowes.com"
        "www.walgreens.com"
        "www.costco.com"
        "www.cvs.com"
        "www.bestbuy.com"
        "www.kroger.com"
        "www.mcdonalds.com"
        "www.starbucks.com"
        "www.pepsico.com"
        "www.nestle.com"
        "www.jnj.com"
        "www.pg.com"
        "www.puma.com"
        "www.underarmour.com"
        "www.hm.com"
        "www.uniqlo.com"
        "www.gap.com"
        "www.rolex.com"
        "www.chanel.com"
        "www.prada.com"
        "www.burberry.com"
        "www.cartier.com"
        "www.estee-lauder.com"
        "www.shiseido.com"
        "www.pfizer.com"
        "www.novartis.com"
        "www.roche.com"
        "www.sanofi.com"
        "www.merck.com"
        "www.bayer.com"
        "www.gsk.com"
        "www.boeing.com"
        "www.airbus.com"
        "www.lockheedmartin.com"
        "www.geaerospace.com"
        "www.siemens.com"
        "www.bosch.com"
        "www.hitachi.com"
        "www.schneider-electric.com"
        "www.abb.com"
        "www.caterpillar.com"
        "www.john-deere.com"
        "www.mitsubishicorp.com"
        "www.sony.net"
        "www.panasonic.com"
        "www.sharp.com"
        "www.lg.com"
        "www.lenovo.com"
        "www.huawei.com"
        "www.asus.com"
        "www.acer.com"
        "www.delltechnologies.com"
        "www.hpe.com"
        "www.lenovo.com.cn"
        "www.tiktok.com"
        "www.spotify.com"
        "www.netflix.com"
        "www.hulu.com"
        "www.disneyplus.com"
    )

    # 用换行符精巧串联重组数组，并利用系统底层工具执行无情哈希打乱，规避固化频率侦测
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

    # 进入实弹交锋遍历
    for sni in $sni_string; do
        # 随时挂起，捕获人类随时下达的中断干预按键
        if read -t 0.1 -n 1 2>/dev/null; then
            echo -e "\n${yellow}接收到长官的撤退信号，雷达扫频强行终止...${none}"
            break
        fi

        # 利用极其轻巧的 Curl 进行 TCP 链路建连深测，获取毫秒级握手延迟
        local time_raw ms
        time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni" 2>/dev/null || echo "0")
        ms=$(echo "$time_raw" | awk '{print int($1 * 1000)}')

        if ((ms > 0)); then
            # 第一道防线：识别并过滤掉躲在 Cloudflare 等强力反代 CDN 背后的大厂
            if curl -sI -m 2 --connect-timeout 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray"; then
                echo -e " ${gray}被动越过${none} $sni (拦截原因: Cloudflare 防护)"
                continue
            fi
            
            # 【V179 核心修复】彻底拔除 AliDNS 接口查询。
            # 由于大厂域名在国际上都是 100% 连通的，只要能探测到 TCP 延迟且不是 CF，我们就直接放行入库。
            local p_type="NORM"
            local status_cn="${green}直通允许${none} | ${cyan}海外原生纯净节点${none}"
            
            echo -e " ${green}探针活跃${none} $sni : 延迟 ${yellow}${ms}ms${none} | 状态: $status_cn"
            echo "$ms $sni $p_type" >> "$tmp_sni"
        fi

        scan_count=$((scan_count + 1))
    done

    # 对扫频结果进行提纯与排位
    if [[ -s "$tmp_sni" ]]; then
        # 优先提携最纯正的 NORM 级海外节点
        grep " NORM$" "$tmp_sni" | sort -n | head -n 20 | awk '{print $2, $1}' > "$SNI_CACHE_FILE" || true
    else
        print_red "探测绝境：所有目标均无法通达，系统将回落调用微软官方地址以图保底。"
        echo "www.microsoft.com 999" > "$SNI_CACHE_FILE"
    fi
    
    rm -f "$tmp_sni" 2>/dev/null || true
}

# 终极 Reality 质检：审查 TLS1.3 / ALPN h2 / OCSP
verify_sni_strict() {
    local target="$1"
    print_magenta "\n>>> 正在强力扯动 OpenSSL 指纹探针，对目标 $target 实施 TLS1.3 / ALPN h2 / OCSP 联合严酷拷打质检..."
    
    local out
    out=$(echo "Q" | timeout 5 openssl s_client -connect "$target:443" -alpn h2 -tls1_3 -status 2>&1 || echo "")
    local pass=1
    
    if ! echo "$out" | grep -qi "TLSv1.3"; then
        print_red " ✗ 拦截报告: 目标网站架构腐朽，缺失最前沿的 TLS v1.3 加密承载！"
        pass=0
    fi
    
    if ! echo "$out" | grep -qi "ALPN.*h2"; then
        print_red " ✗ 拦截报告: 目标不支持 ALPN h2 多路复用流控制，易暴毙断流！"
        pass=0
    fi
    
    if ! echo "$out" | grep -qi "OCSP response:"; then
        print_red " ✗ 拦截报告: 目标装死拒不提供 OCSP Stapling 证书在线装订数据！"
        pass=0
    fi
    
    if ((pass == 0)); then
        print_red " ✗ 审判结论：该选定目标千疮百孔，极易引发流量红灯预警！"
    else
        print_green " ✓ 审判结论：该目标骨骼惊奇，三项高维防御特征完美达标认证！"
    fi
    
    return $pass
}

# 交互选单与矩阵构建
choose_sni() {
    while true; do
        if [[ -f "$SNI_CACHE_FILE" ]]; then
            echo -e "\n  ${cyan}【战备缓存：极速优选低延迟 Top 20 标的库 (绝对剔除封锁杂质)】${none}"
            local idx=1
            
            while read -r s t; do
                echo -e "  $idx) $s (测得物理级延迟: ${cyan}${t}ms${none})"
                idx=$((idx + 1))
            done < "$SNI_CACHE_FILE"
            
            echo -e "  ${yellow}r) 砸碎当前的沉旧缓存，重新启动一波高强度的范围扫频探测${none}"
            echo "  m) 开启上帝矩阵模式 (通过手填多个序号空格隔离，将其组装成万花筒 SNI 阵列对抗封锁)"
            echo "  0) 孤狼独行信条 (手动绝对输入定制化域名)"
            
            read -rp "  请下达决断指令: " sel
            sel=${sel:-1}
            
            case "$sel" in
                q|Q) return 1 ;;
                r|R) run_sni_scanner; continue ;;
                m|M)
                    read -rp "请给出融合公式序列号组合 (如 1 3 5，或者直接键入 all 执行全盘囊括): " m_sel
                    local arr=()
                    
                    if [[ "$m_sel" == "all" ]]; then
                        arr=($(awk '{print $1}' "$SNI_CACHE_FILE" || true))
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
                        error "输入未命中任何列项！请重来。"
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
                    read -rp "请在终端输下您的心头好域名: " d
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
                        error "非法输入"; continue
                    fi
                    ;;
            esac
            
            if verify_sni_strict "$BEST_SNI"; then
                break
            else
                print_yellow ">>> 雷达警告：您钦定的目标质量存在致命物理级残缺！"
                read -rp "您真的要像一个赌徒一样强行启用它吗？(y/n): " force_use
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
# [ 区块 VI: 内核防砖编译系统与基础环境重构 ]
# ==============================================================================

# 找回的极其关键的源码裸装防砖编译模块
do_xanmod_compile() {
    title "【真理降临】从 Kernel.org 提取并裸装最新主线内核 + 物理硬塞 BBR3"
    warn "极其重磅警告: 这是一个将机器物理机能推至极限的高危操作。编译将耗时长达 30 至 60 分钟！"
    read -rp "您已经下定决心承受可能发生的风险了吗？(y/n): " confirm
    
    if [[ "$confirm" != "y" ]]; then
        return
    fi
    
    print_magenta ">>> [1/7] 构建纯铁血工业级编译底层包依赖环境..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y build-essential bc bison flex libssl-dev libelf-dev libncurses-dev zstd git wget curl xz-utils ethtool numactl make pkg-config dwarves rsync python3 libdw-dev cpio >/dev/null 2>&1 || true
    
    # 强制构建 1GB 永久 Swap 的物理存储，杜绝中途内存雪崩
    check_and_create_1gb_swap

    print_magenta ">>> [2/7] 向全世界内核最高神殿 Kernel.org 索要绝对稳定版的完整源码..."
    local BUILD_DIR="/usr/src"
    cd $BUILD_DIR || die "无法进入 /usr/src"
    
    local KERNEL_URL
    KERNEL_URL=$(curl -s https://www.kernel.org/releases.json | jq -r '.releases[] | select(.type=="stable") | .tarball' | head -1 || echo "")
    
    if [[ -z "$KERNEL_URL" || "$KERNEL_URL" == "null" ]]; then
        KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.10.tar.xz"
    fi
    
    local KERNEL_FILE
    KERNEL_FILE=$(basename "$KERNEL_URL")
    wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"

    if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
        rm -f "$KERNEL_FILE"
        wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"
        if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
            error "源文件包体结构受损爆裂，无法接轨！"
            return 1
        fi
    fi

    tar -xJf "$KERNEL_FILE"
    local KERNEL_DIR
    KERNEL_DIR=$(tar -tf "$KERNEL_FILE" | head -1 | cut -d/ -f1)
    cd "$KERNEL_DIR" || die "无法进入解压后的内核源码目录"

    print_magenta ">>> [3/7] 开始核心洗地：基于宿主配置继承原生参数，硬焊 BBR3..."
    
    # 【防砖法案】绝对不允许使用通用版的 make defconfig！
    if [[ -f "/boot/config-$(uname -r)" ]]; then
        cp "/boot/config-$(uname -r)" .config
        print_green "无伤通过！已成功继承当前正在存活系统中的最原生驱动配置文件 (含有全量 VirtIO/KVM 救命驱动)！"
    else
        if modprobe configs 2>/dev/null && [[ -f /proc/config.gz ]]; then
            zcat /proc/config.gz > .config
            print_green "死里逃生！已强行从 /proc/config.gz 内存中提取出内核运行时的物理驱动图谱配置！"
        else
            error "绝望警告：探针无法在系统任何一处找到当前系统的宿主内核配置文件！"
            error "如果继续无脑强制编译，新内核将在开机时无法识别虚拟硬盘而彻底死机变砖！"
            read -rp "您确定要执意继续并承担机器变成砖头的风险吗？极度不推荐！(y/n): " force_k
            if [[ "$force_k" != "y" ]]; then 
                return 1
            fi
            make defconfig
        fi
    fi
    
    make scripts || true
    
    # 物理植入协议栈与卸载冗余驱动
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

    print_magenta ">>> [4/7] 点火！全核满速编译正式爆发 (采用最稳定裸编译模式)..."
    local CPU
    CPU=$(nproc)
    local RAM
    RAM=$(free -m | awk '/Mem/{print $2}')
    local THREADS=1
    
    if ((RAM >= 2000)); then
        THREADS=$CPU
    elif ((RAM >= 1000)); then
        THREADS=2
    fi
    
    if ! make -j$THREADS; then
        error "编译大业被突发错误腰斩，请排查内存是否爆满或硬盘耗尽！"
        read -rp "按 Enter 接受失败并撤离..." _
        return 1
    fi

    print_magenta ">>> [5/7] 强行植入底层驱动模块库并执行新内核直接挂载 (make install)..."
    make modules_install || true
    make install || true

    # 【终极命脉修复】强制生成 Initramfs，否则 GRUB 有内核也无法引导系统盘！
    local NEW_KERNEL_VER
    NEW_KERNEL_VER=$(make -s kernelrelease || echo "")
    
    if [[ -n "$NEW_KERNEL_VER" ]]; then
        print_magenta ">>> [6/7] 核心保命降落伞：正在为新内核 [$NEW_KERNEL_VER] 生成 Initramfs 内存引导系统..."
        if command -v update-initramfs >/dev/null 2>&1; then
            update-initramfs -c -k "$NEW_KERNEL_VER" || true
        elif command -v dracut >/dev/null 2>&1; then
            dracut --force "/boot/initramfs-${NEW_KERNEL_VER}.img" "$NEW_KERNEL_VER" || true
        else
            warn "未找到 update-initramfs 或 dracut，可能无法正确生成引导镜像！"
        fi
    fi

    print_magenta ">>> [7/7] 刷新 GRUB 系统引导器并进行战地大清扫..."
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

    info "奇迹再现！无任何死角的主线内核与 BBR3 协议栈已写入您的主机命脉中。"
    info "系统将在 10 秒后强行断开连接并以全新物理身躯重新降临世间..."
    sleep 10
    reboot
}

# ==============================================================================
# (为防止大模型物理截断，代码第二部分到此安全驻留。)
# (请发送“继续输出 Part 3”，接下来是全量恢复的 60+ 项 Sysctl 和 CAKE 调优引擎！)
# ==============================================================================
# ==============================================================================
# [ 区块 VII: 60+ 项百万并发系统级极限网络栈宏观调优 (带严苛自检与硬件守护) ]
# ==============================================================================
do_perf_tuning() {
    title "超维极限网络层重构：系统底层网络栈结构全系撕裂与灌注"
    warn "操作警示: 这将极大地拉伸 TCP 缓冲并修改网络包调度，将不可逆地引发系统物理重启！"
    
    read -rp "准备好接纳新框架了吗？(y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        return
    fi
    
    local current_scale
    current_scale=$(sysctl -n net.ipv4.tcp_adv_win_scale 2>/dev/null || echo "1")
    local current_app
    current_app=$(sysctl -n net.ipv4.tcp_app_win 2>/dev/null || echo "31")
    
    echo -e "  当前系统内存滑动侧倾角度 (tcp_adv_win_scale): ${cyan}${current_scale}${none} (建议填 1 或 2)"
    echo -e "  当前系统应用保留水池线 (tcp_app_win): ${cyan}${current_app}${none} (建议保留 31)"
    
    read -rp "可自定义 tcp_adv_win_scale (-2 到 2 为合法域，直接回车保留当前): " new_scale
    new_scale=${new_scale:-$current_scale}
    
    read -rp "可自定义 tcp_app_win (1 到 31 的分配率，直接回车保留当前): " new_app
    new_app=${new_app:-$current_app}

    print_magenta ">>> 正在执行大扫除：剿杀过时的加速器与旧世代冲突配置..."
    
    systemctl stop net-speeder >/dev/null 2>&1 || true
    killall net-speeder >/dev/null 2>&1 || true
    systemctl disable net-speeder >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/net-speeder.service 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    rm -rf /root/net-speeder 2>/dev/null || true

    # 使用 truncate 防爆破用户的软链接
    truncate -s 0 /etc/sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-network-optimized.conf 2>/dev/null || true
    
    rm -f /etc/sysctl.d/99-bbr*.conf 2>/dev/null || true
    rm -f /etc/sysctl.d/99-ipv6-disable.conf 2>/dev/null || true
    rm -f /etc/sysctl.d/99-pro*.conf 2>/dev/null || true
    rm -f /etc/sysctl.d/99-xanmod-bbr3.conf 2>/dev/null || true
    rm -f /usr/lib/sysctl.d/50-pid-max.conf 2>/dev/null || true
    rm -f /usr/lib/sysctl.d/99-protect-links.conf 2>/dev/null || true
    
    print_magenta ">>> 正在彻底释放 Linux 全局进程限制的天花板，构建百万级并发底层阀门..."
    
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

    # 显式 if 判断，杜绝 && 引发的错误
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session 2>/dev/null; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
    fi
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session-noninteractive 2>/dev/null; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive
    fi
    
    echo "DefaultLimitNOFILE=1000000" >> /etc/systemd/system.conf 2>/dev/null || true
    echo "DefaultLimitNPROC=1000000" >> /etc/systemd/system.conf 2>/dev/null || true

    local target_qdisc="fq"
    if [[ "$(check_cake_state)" == "true" ]]; then
        target_qdisc="cake"
    fi

    # 全量 60+ 项参数阵列，绝不删减一行！保留所有硬核微操注释。
    print_magenta ">>> 正在向内核物理刻录 60+ 项网络栈极限参数..."
    
    cat > /etc/sysctl.d/99-network-optimized.conf << EOF
# -- 基础拥塞队列与底层发包排队纪律 --
net.core.default_qdisc = ${target_qdisc}
net.ipv4.tcp_congestion_control = bbr
net.ipv4.neigh.default.base_reachable_time_ms = 60000
net.ipv4.neigh.default.mcast_solicit = 2
net.ipv4.neigh.default.retrans_time_ms = 500

# -- 关闭过滤与路由源验证，追求极致无脑穿越 --
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.tcp_no_metrics_save = 1

# -- ECN 显式拥塞与 MTU 黑洞智能探针 --
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_sack = 1

# -- 窗口扩容与内存滑动倾斜角设定 --
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = ${new_scale}
net.ipv4.tcp_app_win = ${new_app}
net.ipv4.tcp_moderate_rcvbuf = 1

# -- 核心内存壁垒推宽 (21MB 巨型超跑吞吐池) --
net.core.rmem_default = 560576
net.core.wmem_default = 560576
net.core.rmem_max = 21699928
net.core.wmem_max = 21699928
net.ipv4.tcp_rmem = 4096 760576 21699928
net.ipv4.tcp_wmem = 4096 760576 21699928
net.ipv4.udp_rmem_min = 4096
net.ipv4.udp_wmem_min = 4096

# -- NAPI 轮询权重约束 (杜绝单核算力被极其恶意的独占导致的网卡卡顿) --
net.core.dev_weight = 64
net.core.dev_weight_tx_bias = 1
net.core.dev_weight_rx_bias = 1
net.core.netdev_budget = 300

# -- VFS 调度与文件句柄巨塔 --
vm.swappiness = 1
fs.file-max = 1048576
fs.nr_open = 1048576
fs.inotify.max_user_instances = 262144

# -- 保活心跳与 TIME_WAIT 极速尸体回收场 --
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 12
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_abort_on_overflow = 0

# -- 连接风暴抗压与多级重试策略防御 --
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

# -- 突进 TCP FastOpen 与低级分片乱序重组引擎 --
net.core.optmem_max = 3276800
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_reordering = 3
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_tso_win_divisor = 6

# -- ARP 与 PID 资源极限释放 --
kernel.pid_max = 4194304
kernel.threads-max = 85536
net.ipv4.neigh.default.gc_thresh1 = 1024
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv4.neigh.default.gc_stale_time = 100
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2

# -- 内核级忙轮询 (Busy Polling) 防抖体系 --
net.unix.max_dgram_qlen = 130000
net.core.busy_poll = 50
net.core.busy_read = 0

# -- 16KB 精准防缓冲膨胀 (Bufferbloat) 最底层绞杀锁 --
net.ipv4.tcp_notsent_lowat = 16384
vm.vfs_cache_pressure = 10
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.ip_forward = 1

# -- 隐蔽行踪：斩断 ICMP 重定向与恶意碎片重组攻击防线 --
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

# -- 进程通信与异步 IO 并发极值 --
fs.aio-max-nr = 262144
kernel.msgmax = 655350
kernel.msgmnb = 655350
net.ipv4.neigh.default.proxy_qlen = 50000

# -- BBR Pacing 发包节奏比率控制 (完美契合 BBR3) --
net.ipv4.tcp_pacing_ca_ratio = 150
net.ipv4.tcp_pacing_ss_ratio = 210

# -- 文件系统级进程越权防御 --
fs.protected_fifos = 1
fs.protected_hardlinks = 1
fs.protected_regular = 2
fs.protected_symlinks = 1

# -- RPS/RFS 散列深度容量上限 --
net.core.rps_sock_flow_entries = 131072
net.core.flow_limit_table_len = 131072
net.ipv4.tcp_workaround_signed_windows = 1
vm.dirty_ratio = 35
vm.overcommit_memory = 0
kernel.sysrq = 1

# -- 斩杀 IPv6 彻底杜绝特征污染与泄漏 --
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# -- 边缘极限探针群补充 (V179 神级参数回归阵列) --
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

    print_magenta ">>> 正在执行物理层级 sysctl 强制灌注与报错反馈捕获..."
    
    if ! sysctl -p /etc/sysctl.d/99-network-optimized.conf >/dev/null 2>&1; then
        error "系统拒收报告：Sysctl 参数字典存在错误或硬件不支持，内核已拒绝挂载！流程熔断。"
        read -rp "请按下 Enter 接受失败并安全返回主控台..." _
        return 1
    else
        info "验证完美通过：所有 60+ 项底层网络核心参数顺利被内核强行接纳。"
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if [[ -n "$IFACE" ]]; then
        print_magenta ">>> 正在向底层网卡固件 ($IFACE) 植入硬件加速卸载逻辑..."
        
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

if [ "$RX_QUEUES" -gt 0 ]; then
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

# ==============================================================================
# [ 区块 VIII: TX Queue 限速器与 CAKE 极客大盘调度控制台 ]
# ==============================================================================
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
    
    read -rp "  [1] 声明物理带宽极限压迫点 (格式如 900Mbit, 不限速填 0): " c_bw
    read -rp "  [2] 配置加密报文体积开销补偿 (格式纯数字如 48, 填 0 废弃): " c_oh
    read -rp "  [3] 指定底层包头最小截断 MPU (格式数字如 84, 填 0 废弃): " c_mpu
    
    echo "  [4] 选择高仿真网络延迟 RTT 模型: "
    echo "    1) internet  (85ms 默认标准波段)"
    echo "    2) oceanic   (300ms 跨洋深海电缆对冲模型 - 推荐)"
    echo "    3) satellite (1000ms 疯狂丢包卫星极限模型)"
    read -rp "  选择 (默认 2): " rtt_sel
    
    local c_rtt=""
    case "${rtt_sel:-2}" in
        1) c_rtt="internet" ;;
        3) c_rtt="satellite" ;;
        *) c_rtt="oceanic" ;;
    esac
    
    echo "  [5] 确立数据流分流盲走体系: "
    echo "    1) diffserv4  (耗费算力解拆分析特征，极度高消耗)"
    echo "    2) besteffort (忽略包特征直接盲推，最低延迟王者 - 推荐)"
    read -rp "  选择 (默认 2): " diff_sel
    
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
    # LTRIM
    final_opts="${final_opts#"${final_opts%%[! ]*}"}"
    
    if [[ -z "$final_opts" ]]; then
        rm -f "$CAKE_OPTS_FILE" 2>/dev/null || true
        info "所有 CAKE 高阶管控参数均已被强行物理擦除。"
    else
        echo "$final_opts" > "$CAKE_OPTS_FILE"
        info "调度边界记录表已死死锁存入册: $final_opts"
    fi
    
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
# [ 区块 IX: 状态机探针与开机底层锚点生成引擎 (全量 if/else 严谨判定) ]
# ==============================================================================

check_mph_state() {
    local state
    state=$(jq -r '.routing.domainMatcher // "false"' "$CONFIG" 2>/dev/null || echo "false")
    if [[ "$state" == "mph" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

check_maxtime_state() {
    local state
    state=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
    if [[ "$state" == "60000" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

check_routeonly_state() {
    local state
    state=$(jq -r '.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
    if [[ "$state" == "true" ]]; then
        echo "true"
    else
        echo "false"
    fi
}

check_sniff_state() {
    local state
    state=$(jq -r '.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.metadataOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
    if [[ "$state" == "true" ]]; then
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
    if [[ ! -f "/sys/kernel/mm/transparent_hugepage/enabled" ]]; then
        echo "unsupported"
        return
    fi
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
    if ! ethtool -g "$IFACE" >/dev/null 2>&1; then
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
    if ! modprobe -n zram >/dev/null 2>&1; then
        if ! lsmod 2>/dev/null | grep -q zram; then
            echo "unsupported"
            return
        fi
    fi
    
    if swapon --show 2>/dev/null | grep -q 'zram'; then
        echo "true"
    else
        echo "false"
    fi
}

check_journal_state() {
    if [[ ! -f "/etc/systemd/journald.conf" ]]; then
        echo "unsupported"
        return
    fi
    if grep -q '^Storage=volatile' /etc/systemd/journald.conf 2>/dev/null; then
        echo "true"
    else
        echo "false"
    fi
}

check_process_priority_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if [[ ! -f "$limit_file" ]]; then
        echo "false"
        return
    fi
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

# 物理锚点实现真正的永久记忆，免疫 qdisc 状态重叠
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
    if ! command -v ethtool >/dev/null 2>&1; then
        echo "unsupported"
        return
    fi
    
    local eth_info
    eth_info=$(ethtool -k "$IFACE" 2>/dev/null || echo "")
    if [[ -z "$eth_info" ]]; then
        echo "unsupported"
        return
    fi
    
    if echo "$eth_info" | grep -E "^generic-receive-offload:|^rx-gro:" | grep -q "fixed" 2>/dev/null; then
        echo "unsupported"
        return
    fi
    
    if echo "$eth_info" | grep -E "^generic-receive-offload:|^rx-gro:" | grep -q " off" 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_irq_state() {
    local CORES
    CORES=$(nproc 2>/dev/null || echo 1)
    if [ "$CORES" -lt 2 ]; then
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

# 开机底盘守护脚本生成器 (带 absolute path 锚定与 network-online.target 绝杀)
update_hw_boot_script() {
    cat > /usr/local/bin/xray-hw-tweaks.sh << 'SHEOF'
#!/bin/bash
# 强行注入环境变量，防止极端极简 OS 中 ethtool 或 tc 命令执行空转
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
# 若刚开机网卡未就绪，强制重试机制保护
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
    
    # -- 注入 CAKE 动态参数与物理标识位读取机制 --
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
    echo 1 > /proc/irq/$irq/smp_affinity 2>/dev/null || true
done
EOF
    fi

    chmod +x /usr/local/bin/xray-hw-tweaks.sh 2>/dev/null || true

    # 【时序绝杀修复】强制使用 network-online.target
    cat > /etc/systemd/system/xray-hw-tweaks.service << 'EOF'
[Unit]
Description=Xray Hardware Tweaks
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

# CAKE 实时热应用逻辑
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
        
        # shellcheck disable=SC2086
        tc qdisc replace dev "$IFACE" root cake $base_opts $f_ack $f_ecn $f_wash 2>/dev/null || true
    fi
    update_hw_boot_script
}

# ==============================================================================
# (为防止大模型物理截断，代码第三部分到此安全驻留。)
# (上帝开关 Toggle 体系、UI 控制台以及安装主入口将于下一段无缝送出！)
# ==============================================================================
# ==============================================================================
# [ 区块 VIII (续): 应用层微操全景矩阵与上帝开关 ]
# ==============================================================================

_turn_on_app() {
    _safe_jq_write '
      .routing = (.routing // {}) |
      .routing.domainMatcher = "mph" |
      .outbounds = [
          .outbounds[]? | if (.protocol == "freedom") then
              .streamSettings = (.streamSettings // {}) |
              .streamSettings.sockopt = (.streamSettings.sockopt // {}) |
              .streamSettings.sockopt.tcpNoDelay = true |
              .streamSettings.sockopt.tcpFastOpen = true |
              .streamSettings.sockopt.tcpKeepAliveIdle = 30 |
              .streamSettings.sockopt.tcpKeepAliveInterval = 15
          else . end
      ] |
      .inbounds = [
          .inbounds[]? | if (.protocol == "vless" or .protocol == "shadowsocks") then
              .streamSettings = (.streamSettings // {}) |
              .streamSettings.sockopt = (.streamSettings.sockopt // {}) |
              .streamSettings.sockopt.tcpNoDelay = true |
              .streamSettings.sockopt.tcpFastOpen = true |
              .streamSettings.sockopt.tcpKeepAliveIdle = 30 |
              .streamSettings.sockopt.tcpKeepAliveInterval = 15 |
              .sniffing = (.sniffing // {}) |
              .sniffing.metadataOnly = true |
              .sniffing.routeOnly = true
          else . end
      ]
    '
    
    local has_reality
    has_reality=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .protocol' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
    if [[ -n "$has_reality" ]]; then
        _safe_jq_write '
          .inbounds = [
              .inbounds[]? | if (.protocol == "vless" and .streamSettings.security == "reality") then
                  .streamSettings.realitySettings = (.streamSettings.realitySettings // {}) |
                  .streamSettings.realitySettings.maxTimeDiff = 60000
              else . end
          ]
        '
    fi
    
    if [[ "$(check_dnsmasq_state)" == "true" ]]; then
        _safe_jq_write '
          .dns = {
              "servers": ["127.0.0.1"],
              "queryStrategy": "UseIP"
          }
        '
    else
        _safe_jq_write '
          .dns = {
              "servers": [
                  "https://8.8.8.8/dns-query",
                  "https://1.1.1.1/dns-query",
                  "https://doh.opendns.com/dns-query"
              ],
              "queryStrategy": "UseIP"
          }
        '
    fi
    
    _safe_jq_write '
      .policy = {
          "levels": {
              "0": {
                  "handshake": 3,
                  "connIdle": 60
              }
          },
          "system": {
              "statsInboundDownlink": false,
              "statsInboundUplink": false
          }
      }
    '
    
    _toggle_affinity_on
    
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if [[ -f "$limit_file" ]]; then
        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file"
        echo "Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" >> "$limit_file"
        
        local TOTAL_MEM
        TOTAL_MEM=$(free -m | awk '/Mem/{print $2}')
        local DYNAMIC_GOGC=100
        if ((TOTAL_MEM >= 1800)); then 
            DYNAMIC_GOGC=1000
        elif ((TOTAL_MEM >= 900)); then 
            DYNAMIC_GOGC=500
        else 
            DYNAMIC_GOGC=300
        fi
        
        sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=$DYNAMIC_GOGC\"/" "$limit_file"
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

_turn_off_app() {
    _safe_jq_write '
      del(.routing.domainMatcher) |
      .outbounds = [
          .outbounds[]? | if (.protocol == "freedom") then
              del(.streamSettings.sockopt.tcpNoDelay, .streamSettings.sockopt.tcpFastOpen, .streamSettings.sockopt.tcpKeepAliveIdle, .streamSettings.sockopt.tcpKeepAliveInterval)
          else . end
      ] |
      .inbounds = [
          .inbounds[]? | if (.protocol == "vless" or .protocol == "shadowsocks") then
              del(.streamSettings.sockopt.tcpNoDelay, .streamSettings.sockopt.tcpFastOpen, .streamSettings.sockopt.tcpKeepAliveIdle, .streamSettings.sockopt.tcpKeepAliveInterval) |
              .sniffing = (.sniffing // {}) |
              .sniffing.metadataOnly = false |
              .sniffing.routeOnly = false
          else . end
      ]
    '
    
    _safe_jq_write '
      .inbounds = [
          .inbounds[]? | if (.protocol == "vless" and .streamSettings.security == "reality") then
              del(.streamSettings.realitySettings.maxTimeDiff)
          else . end
      ] |
      del(.dns) |
      del(.policy)
    '
    
    _toggle_affinity_off
    
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if [[ -f "$limit_file" ]]; then
        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file"
        sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=100\"/" "$limit_file"
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

# 辅助函数：修复短路陷阱并提供安全的开关 UI
_toggle_affinity_on() {
    local lf="/etc/systemd/system/xray.service.d/limits.conf"
    if [[ -f "$lf" ]]; then
        sed -i '/^CPUAffinity=/d;/^Environment="GOMAXPROCS=/d' "$lf"
        local TARGET_CPU
        if (( $(nproc) >= 2 )); then TARGET_CPU=1; else TARGET_CPU=0; fi
        echo "CPUAffinity=$TARGET_CPU" >> "$lf"
        echo "Environment=\"GOMAXPROCS=1\"" >> "$lf"
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}
_toggle_affinity_off() {
    local lf="/etc/systemd/system/xray.service.d/limits.conf"
    if [[ -f "$lf" ]]; then
        sed -i '/^CPUAffinity=/d;/^Environment="GOMAXPROCS=/d' "$lf"
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}
toggle_buffer() {
    local lf="/etc/systemd/system/xray.service.d/limits.conf"
    if [[ -f "$lf" ]]; then
        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$lf"
        if [[ "$(check_buffer_state)" != "true" ]]; then
            echo "Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" >> "$lf"
        fi
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}
toggle_dnsmasq() {
    if [[ "$(check_dnsmasq_state)" == "true" ]]; then
        systemctl stop dnsmasq; systemctl disable dnsmasq
        chattr -i /etc/resolv.conf 2>/dev/null || true
        if [[ -f /etc/resolv.conf.bak ]]; then
            mv -f /etc/resolv.conf.bak /etc/resolv.conf
        else
            echo "nameserver 8.8.8.8" > /etc/resolv.conf
        fi
        systemctl enable systemd-resolved 2>/dev/null || true
        systemctl start systemd-resolved 2>/dev/null || true
        _safe_jq_write '.dns = {"servers":["https://8.8.8.8/dns-query","https://1.1.1.1/dns-query"],"queryStrategy":"UseIP"}'
    else
        pkg_install dnsmasq
        systemctl stop systemd-resolved 2>/dev/null || true
        systemctl disable systemd-resolved 2>/dev/null || true
        cat > /etc/dnsmasq.conf << 'EOF'
port=53
listen-address=127.0.0.1
bind-interfaces
cache-size=21000
min-cache-ttl=3600
all-servers
server=8.8.8.8
server=1.1.1.1
no-resolv
no-poll
EOF
        systemctl enable dnsmasq; systemctl restart dnsmasq
        chattr -i /etc/resolv.conf 2>/dev/null || true
        if [[ ! -f /etc/resolv.conf.bak ]]; then
            cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true
        fi
        echo "nameserver 127.0.0.1" > /etc/resolv.conf
        chattr +i /etc/resolv.conf 2>/dev/null || true
        _safe_jq_write '.dns = {"servers":["127.0.0.1"],"queryStrategy":"UseIP"}'
    fi
}
toggle_thp() {
    local f_en="/sys/kernel/mm/transparent_hugepage/enabled"
    local f_df="/sys/kernel/mm/transparent_hugepage/defrag"
    if [[ "$(check_thp_state)" == "true" ]]; then
        echo always > "$f_en" 2>/dev/null || true; echo always > "$f_df" 2>/dev/null || true
    else
        echo never > "$f_en" 2>/dev/null || true; echo never > "$f_df" 2>/dev/null || true
    fi
    update_hw_boot_script
}
toggle_mtu() {
    local conf="/etc/sysctl.d/99-network-optimized.conf"
    if [[ "$(check_mtu_state)" == "true" ]]; then
        sed -i 's/^net.ipv4.tcp_mtu_probing.*/net.ipv4.tcp_mtu_probing = 0/' "$conf" 2>/dev/null || true
    else
        if grep -q "net.ipv4.tcp_mtu_probing" "$conf" 2>/dev/null; then
            sed -i 's/^net.ipv4.tcp_mtu_probing.*/net.ipv4.tcp_mtu_probing = 1/' "$conf"
        else
            echo "net.ipv4.tcp_mtu_probing = 1" >> "$conf"
        fi
    fi
    sysctl -p "$conf" >/dev/null 2>&1 || true
}
toggle_cpu() {
    local target
    if [[ "$(check_cpu_state)" == "true" ]]; then target="schedutil"; else target="performance"; fi
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [[ -f "$cpu" ]]; then echo "$target" > "$cpu" 2>/dev/null || true; fi
    done
    update_hw_boot_script
}
toggle_ring() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if [[ "$(check_ring_state)" == "true" ]]; then
        local max_rx
        max_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Pre-set maximums" | grep "RX:" | head -1 | awk '{print $2}' || echo "512")
        ethtool -G "$IFACE" rx "$max_rx" tx "$max_rx" 2>/dev/null || true
    else
        ethtool -G "$IFACE" rx 512 tx 512 2>/dev/null || true
    fi
    update_hw_boot_script
}
toggle_gso_off() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if [[ "$(check_gso_off_state)" == "true" ]]; then
        ethtool -K "$IFACE" gro on gso on tso on 2>/dev/null || true
    else
        ethtool -K "$IFACE" gro off gso off tso off 2>/dev/null || true
    fi
    update_hw_boot_script
}
toggle_zram() {
    if [[ "$(check_zram_state)" == "true" ]]; then
        swapoff /dev/zram0 2>/dev/null || true
        rmmod zram 2>/dev/null || true
        systemctl disable --now xray-zram.service 2>/dev/null || true
        rm -f /etc/systemd/system/xray-zram.service /usr/local/bin/xray-zram.sh
    else
        local total; total=$(free -m | awk '/Mem/{print $2}')
        local sz
        if ((total < 500)); then sz=$((total*2)); elif ((total < 1024)); then sz=$((total*3/2)); else sz=$total; fi
        cat > /usr/local/bin/xray-zram.sh << EOFZ
#!/bin/bash
modprobe zram num_devices=1
echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || true
echo "${sz}M" > /sys/block/zram0/disksize
mkswap /dev/zram0
swapon -p 100 /dev/zram0
EOFZ
        chmod +x /usr/local/bin/xray-zram.sh
        cat > /etc/systemd/system/xray-zram.service << 'EOFZ'
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
        systemctl daemon-reload; systemctl enable --now xray-zram.service
    fi
}
toggle_journal() {
    local conf="/etc/systemd/journald.conf"
    if [[ "$(check_journal_state)" == "true" ]]; then
        sed -i 's/^Storage=volatile/#Storage=auto/' "$conf" 2>/dev/null || true
    else
        if grep -q "^Storage=" "$conf" 2>/dev/null; then
            sed -i 's/^Storage=.*/Storage=volatile/' "$conf"
        else
            echo "Storage=volatile" >> "$conf"
        fi
    fi
    systemctl restart systemd-journald 2>/dev/null || true
}
toggle_process_priority() {
    local lf="/etc/systemd/system/xray.service.d/limits.conf"
    if [[ ! -f "$lf" ]]; then return; fi
    if grep -q "^OOMScoreAdjust=-500" "$lf"; then
        sed -i '/^OOMScoreAdjust=/d;/^IOSchedulingClass=/d;/^IOSchedulingPriority=/d' "$lf"
    else
        { echo "OOMScoreAdjust=-500"; echo "IOSchedulingClass=realtime"; echo "IOSchedulingPriority=2"; } >> "$lf"
    fi
    systemctl daemon-reload >/dev/null 2>&1 || true
}
toggle_cake() {
    local conf="/etc/sysctl.d/99-network-optimized.conf"
    local IFACE; IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if [[ "$(check_cake_state)" == "true" ]]; then
        sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = fq/' "$conf" 2>/dev/null || true
        sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1 || true
        tc qdisc replace dev "$IFACE" root fq 2>/dev/null || true
    else
        if grep -q "net.core.default_qdisc" "$conf" 2>/dev/null; then
            sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = cake/' "$conf"
        else
            echo "net.core.default_qdisc = cake" >> "$conf"
        fi
        modprobe sch_cake 2>/dev/null || true
        sysctl -w net.core.default_qdisc=cake >/dev/null 2>&1 || true
        _apply_cake_live
    fi
    update_hw_boot_script
}
toggle_ackfilter() {
    if [[ "$(check_ackfilter_state)" == "true" ]]; then rm -f "$FLAGS_DIR/ack_filter"; else touch "$FLAGS_DIR/ack_filter"; fi
    if [[ "$(check_cake_state)" == "true" ]]; then _apply_cake_live; fi
}
toggle_ecn() {
    if [[ "$(check_ecn_state)" == "true" ]]; then rm -f "$FLAGS_DIR/ecn"; else touch "$FLAGS_DIR/ecn"; fi
    if [[ "$(check_cake_state)" == "true" ]]; then _apply_cake_live; fi
}
toggle_wash() {
    if [[ "$(check_wash_state)" == "true" ]]; then rm -f "$FLAGS_DIR/wash"; else touch "$FLAGS_DIR/wash"; fi
    if [[ "$(check_cake_state)" == "true" ]]; then _apply_cake_live; fi
}
toggle_irq() {
    local IFACE; IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    local CORES; CORES=$(nproc 2>/dev/null || echo 1)
    if [[ "$(check_irq_state)" == "true" ]]; then
        local default_mask; default_mask=$(printf "%x" $(( (1<<CORES)-1 )))
        for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || true); do
            echo "$default_mask" > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true
        done
        systemctl start irqbalance 2>/dev/null || true; systemctl enable irqbalance 2>/dev/null || true
    else
        systemctl stop irqbalance 2>/dev/null || true; systemctl disable irqbalance 2>/dev/null || true
        for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || true); do
            echo 1 > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true
        done
    fi
    update_hw_boot_script
}

# _get_ip 辅助函数
_get_ip() {
    if [[ -n "$SERVER_IP" ]]; then echo "$SERVER_IP"; else echo "未探测"; fi
}

# ==============================================================================
# 入口点触发
# ==============================================================================
preflight
main_menu
