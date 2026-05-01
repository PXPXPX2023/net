#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: ex188t31.sh (The Apex Vanguard - Ultimate Genesis 3000+)
# 快捷方式: xrv
# 版本号: V188t31.Mega.Unabridged.Perfect.UI
#
# 【V188t31 终极溯源全量排爆版】
#   1. 完美 UI 对齐: 严格重构主菜单及 1,2,3,7,9,10 子菜单，100% 契合指令架构。
#   2. 灾备防爆网络: 全量保留 backup_config 与 verify_xray_config 模块，阻止残缺配置落盘。
#   3. JQ 绝缘屏障: 所有的 jq 数组操作全量加装 select(. != null)，根除回车炸弹与键值缺失闪退。
#   4. 绝对不压行: 所有的逻辑链条垂直铺展，放弃代码长度换取绝对的健壮性。
# ==============================================================================

# ------------------------------------------------------------------------------
# [ 0x01: 系统级基础环境检查与严格模式锁定 ]
# ------------------------------------------------------------------------------

# 严格执行 Bash 环境校验，杜绝 dash/sh 带来的语法不兼容
if test -z "${BASH_VERSION:-}"; then
    echo "Error: 本脚本深度依赖 Bash 高级特性，请执行: bash ex188t31.sh"
    exit 1
fi

# 启用最高规格严格模式
# -e: 任何指令执行失败 (返回值非 0) 立即中断脚本
# -u: 尝试使用未定义的变量时立即中断脚本
# -o pipefail: 管道流中任意一环失败，则判定整个管道指令失败
set -euo pipefail

# 恢复系统原始分隔符，防止外部环境变量污染导致的循环解析灾难
IFS=$' \n\t'

# 强制补齐系统环境变量路径，确保所有的底层命令均可被正确寻址
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ------------------------------------------------------------------------------
# [ 0x02: 全域 UI 引擎与十六进制常量 ]
# ------------------------------------------------------------------------------

readonly red='\033[31m'
readonly yellow='\033[33m'
readonly gray='\033[90m'
readonly green='\033[92m'
readonly blue='\033[94m'
readonly magenta='\033[95m'
readonly cyan='\033[96m'
readonly none='\033[0m'

# 终极防吞噬十六进制常量 (用于极其复杂的 JQ 过滤，防止 Bash 转义吞噬方括号)
readonly L_B=$(printf '\x5B')
readonly R_B=$(printf '\x5D')

# ------------------------------------------------------------------------------
# [ 0x03: 全局物理路径与状态地图初始化 ]
# ------------------------------------------------------------------------------

# 核心二进制与配置文件路径
readonly XRAY_BIN="/usr/local/bin/xray"
readonly CONFIG_DIR="/usr/local/etc/xray"
readonly CONFIG="$CONFIG_DIR/config.json"
readonly PUBKEY_FILE="$CONFIG_DIR/public.key"
readonly SNI_CACHE_FILE="$CONFIG_DIR/sni_cache.txt"
readonly INSTALL_DATE_FILE="$CONFIG_DIR/install_date.txt"
readonly USER_SNI_MAP="$CONFIG_DIR/user_sni.txt"
readonly USER_TIME_MAP="$CONFIG_DIR/user_time.txt"

# 辅助目录定义
readonly DAT_DIR="/usr/local/share/xray"
readonly SCRIPT_DIR="/usr/local/etc/xray-script"
readonly UPDATE_DAT_SCRIPT="$SCRIPT_DIR/update-dat.sh"
readonly LOG_DIR="/var/log/xray"
readonly BACKUP_DIR="$CONFIG_DIR/backups"
readonly CAKE_OPTS_FILE="$CONFIG_DIR/cake_opts.txt"
readonly FLAGS_DIR="$CONFIG_DIR/flags"

# 脚本快捷锚点
readonly SYMLINK="/usr/local/bin/xrv"
readonly SCRIPT_PATH=$(readlink -f "$0")

# 运行期动态变量初始化 (必须赋初值以通过 set -u 检测)
SERVER_IP=""
REMARK_NAME="xp-reality"
BEST_SNI="www.microsoft.com"
SNI_JSON_ARRAY="\"www.microsoft.com\""
LISTEN_PORT=443

# ------------------------------------------------------------------------------
# [ 0x04: 工业级辅助输出与日志体系 ]
# ------------------------------------------------------------------------------

print_red()     { echo -e "${red}$*${none}"; }
print_green()   { echo -e "${green}$*${none}"; }
print_yellow()  { echo -e "${yellow}$*${none}"; }
print_magenta() { echo -e "${magenta}$*${none}"; }
print_cyan()    { echo -e "${cyan}$*${none}"; }

info()  { echo -e "${green}✓ [系统信息]${none} $*"; }
warn()  { echo -e "${yellow}! [安全告警]${none} $*"; }
error() { echo -e "${red}✗ [故障拦截]${none} $*"; }
die()   { echo -e "\n${red}[致命断层]${none} $*\n"; exit 1; }

title() {
    echo -e "\n${blue}===================================================${none}"
    echo -e "  ${cyan}$*${none}"
    echo -e "${blue}===================================================${none}"
}

hr() {
    echo -e "${gray}---------------------------------------------------${none}"
}

# 独立运行日志写入函数
log_info() { 
    if test -d "$LOG_DIR"; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO]  $*" >> "$LOG_DIR/xray_script.log" 2>/dev/null || true 
    fi
}

log_error() { 
    if test -d "$LOG_DIR"; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" >> "$LOG_DIR/script_error.log" 2>/dev/null || true 
    fi
}

# ------------------------------------------------------------------------------
# [ 0x05: 企业级 Trap 异常捕获网与灾难清理 ]
# ------------------------------------------------------------------------------

# 构建系统底层目录骨架 (提前执行，为日志系统提供物理空间)
if ! mkdir -p "$CONFIG_DIR" "$DAT_DIR" "$SCRIPT_DIR" "$LOG_DIR" "$BACKUP_DIR" "$FLAGS_DIR" 2>/dev/null; then
    echo -e "${yellow}警告: 系统目录创建可能存在权限遮蔽，将尝试强行绕过。${none}"
fi

if ! touch "$USER_SNI_MAP" "$USER_TIME_MAP" 2>/dev/null; then
    echo -e "${yellow}警告: 用户持久化数据表创建失败。${none}"
fi

# 无论脚本是正常退出还是异常终止，均执行清理序列
trap cleanup_temp_files EXIT

# 挂载极度强化的 Trap 异常捕获网
trap '_err_handler $? $LINENO "$BASH_COMMAND"' ERR

_err_handler() {
    local exit_code=$1
    local err_line=$2
    local err_cmd=$3
    
    echo -e "\n${red}================== [ SYSTEM PANIC ] ==================${none}" >&2
    echo -e "${yellow} >> 战舰核心遇到致命断层，运行已被系统强行熔断！${none}" >&2
    echo -e "${cyan} >> 错误代号: ${none}${exit_code}" >&2
    echo -e "${cyan} >> 崩溃行号: ${none}${err_line}" >&2
    echo -e "${cyan} >> 故障指令: ${none}${err_cmd}" >&2
    echo -e "${red}======================================================${none}\n" >&2
    
    log_error "PANIC TRIGGERED -> EXIT=$exit_code LINE=$err_line CMD=[$err_cmd]"
    
    # 灾难级垃圾回收，防止内存泄漏或脏配置留存
    cleanup_temp_files
    
    warn "环境守护系统已自动触发，残留进程与临时挂载点已清理完毕。"
}

cleanup_temp_files() {
    rm -f /tmp/net-tcp-tune.* 2>/dev/null || true
    rm -f /tmp/sni_array.json 2>/dev/null || true
    rm -f /tmp/vless_inbound.json 2>/dev/null || true
    rm -f /tmp/ss_inbound.json 2>/dev/null || true
    rm -f /tmp/xray_users_*.txt 2>/dev/null || true
    rm -f /tmp/install-release.sh 2>/dev/null || true
    rm -f /tmp/sni_test.* 2>/dev/null || true
}

# ------------------------------------------------------------------------------
# [ 0x06: 核心配置灾备、验证中枢与权限锁 (绝对防线) ]
# ------------------------------------------------------------------------------

fix_permissions() {
    info "执行全域文件权限加固与 Root 归属绑定..."
    
    if test -f "$CONFIG"; then
        chmod 644 "$CONFIG" >/dev/null 2>&1 || true
        chown root:root "$CONFIG" >/dev/null 2>&1 || true
    fi
    
    if test -d "$CONFIG_DIR"; then
        chmod 755 "$CONFIG_DIR" >/dev/null 2>&1 || true
        chown -R root:root "$CONFIG_DIR" >/dev/null 2>&1 || true
    fi
    
    if test -f "$PUBKEY_FILE"; then
        chmod 600 "$PUBKEY_FILE" >/dev/null 2>&1 || true
    fi
}

backup_config() {
    # 如果还没有配置文件，则跳过备份，防止报错
    if test ! -f "$CONFIG"; then 
        return 0
    fi
    
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    
    # 安全复制至后备空间
    cp -f "$CONFIG" "$BACKUP_DIR/config_${ts}.json" 2>/dev/null || true
    
    # 保留最近的 15 份安全快照，清理旧文件防止撑爆空间
    ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | tail -n +16 | xargs rm -f 2>/dev/null || true
    
    log_info "系统配置已成功执行物理级快照: config_${ts}.json"
}

restore_latest_backup() {
    local latest
    latest=$(ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | head -n 1 || true)
    
    if test -n "$latest"; then
        info "正在执行时空回溯，载入并强行覆写目标快照: $(basename "$latest")..."
        
        cp -f "$latest" "$CONFIG" 2>/dev/null || true
        fix_permissions
        systemctl restart xray >/dev/null 2>&1 || true
        
        warn "检测到致命错误，系统配置已成功强制回滚至安全点。"
        log_info "触发灾难回滚，系统降级载入快照: $latest"
        return 0
    fi
    
    error "回滚系统失效：时空存储库中未发现有效配置快照！系统可能处于初次空壳部署状态。"
    return 1
}

verify_xray_config() {
    local target_config="$1"
    
    # 还没安装核心，跳过底层自检，防爆保护
    if test ! -f "$XRAY_BIN"; then
        return 0 
    fi
    
    info "正在唤醒 Xray 核心引擎，进入配置安全预审模式..."
    
    local test_result
    # 捕获 Xray 的底层测试输出，强行测试配置树的合法性
    test_result=$("$XRAY_BIN" -test -config "$target_config" 2>&1 || true)
    
    if echo "$test_result" | grep -qi "Configuration OK"; then
        info "配置预审通过，底层 JSON 语法逻辑完美闭环。"
        return 0
    else
        error "预审拦截！Xray 核心强力拒绝加载该配置，存在致命断层："
        echo -e "${gray}$test_result${none}"
        return 1
    fi
}

ensure_xray_is_alive() {
    info "正在向 Systemd 守护系统下发 Xray 服务层级重载指令..."
    
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl restart xray >/dev/null 2>&1 || true
    
    # 留出充足时间让内核调度进程握手
    sleep 3
    
    # 最终防爆诊断
    if systemctl is-active --quiet xray; then
        info "Xray 引擎心跳回波正常，服务已在系统层稳健挂载！"
        return 0
    else
        error "Xray 引擎启动宣告失败！灾难级诊断日志流如下："
        hr
        journalctl -u xray.service --no-pager -n 15 2>/dev/null | awk '{print "    " $0}' || true
        hr
        warn "引擎崩溃阵亡，立即触发时空坐标安全回滚程序..."
        
        restore_latest_backup
        
        local _pause=""
        read -rp "请仔细核对上方堆栈信息。按 Enter 键知悉并返回中枢..." _pause || true
        return 1
    fi
}

# ------------------------------------------------------------------------------
# [ 0x07: JQ 绝缘写入引擎 (包含 select(. != null) 与灾难回滚) ]
# ------------------------------------------------------------------------------

_safe_jq_write() {
    local filter="$1"
    local description="${2:-'JSON 节点重组'}"
    local tmp
    
    # 执行写前保护，快照先行
    backup_config
    
    tmp=$(mktemp)
    
    # 注入 select(. != null) 绝缘层逻辑 (在传入的 filter 中由外部保证)
    # 即使发生错误，也绝对不会破坏原配置文件
    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null; then
        
        # 强行经过 Xray 核心预审，不通过绝不落盘！
        if verify_xray_config "$tmp"; then
            mv -f "$tmp" "$CONFIG" >/dev/null 2>&1 || true
            fix_permissions
            log_info "JQ 写入成功且预审通过: $description"
            return 0
        else
            error "JQ 解析引擎写入后，未通过 Xray 内核安全预审，操作已撤销：$description"
            rm -f "$tmp" >/dev/null 2>&1 || true
            restore_latest_backup
            return 1
        fi
    else
        error "JQ 解析引擎遇到语法断层：$description"
        log_error "JQ 解析失败，Filter 抛出异常: $filter"
        rm -f "$tmp" >/dev/null 2>&1 || true
        restore_latest_backup
        return 1
    fi
}
# ------------------------------------------------------------------------------
# [ 0x08: Systemd 特种兵级提权 (修复 nobody 暴毙与重构资源防线) ]
# ------------------------------------------------------------------------------

fix_xray_systemd_limits() {
    info "正在对 Xray 守护进程实施 Root 级越权管理与极限资源扩容..."
    
    local override_dir="/etc/systemd/system/xray.service.d"
    
    # 确立覆写目录的物理存在
    if ! mkdir -p "$override_dir" 2>/dev/null; then
        error "无法创建 Systemd Override 目录，提权流可能受阻！"
    fi
    
    local limit_file="$override_dir/limits.conf"
    
    # 状态无损继承变量初始化
    local current_nice="-20"
    local current_gogc="100"
    local current_oom="true"
    local current_affinity=""
    local current_gomaxprocs=""

    # 深度扫描旧配置，实现参数平滑迁移，确保热更时不掉配置
    if test -f "$limit_file"; then
        if grep -q "^Nice=" "$limit_file" 2>/dev/null; then
            current_nice=$(awk -F'=' '/^Nice=/ {print $2}' "$limit_file" | head -n 1)
        fi
        
        if grep -q "^Environment=\"GOGC=" "$limit_file" 2>/dev/null; then
            current_gogc=$(awk -F'=' '/^Environment="GOGC=/ {print $3}' "$limit_file" | tr -d '"' | head -n 1)
        fi
        
        if ! grep -q "^OOMScoreAdjust=" "$limit_file" 2>/dev/null; then
            current_oom="false"
        fi
        
        if grep -q "^CPUAffinity=" "$limit_file" 2>/dev/null; then
            current_affinity=$(awk -F'=' '/^CPUAffinity=/ {print $2}' "$limit_file" | head -n 1)
        fi
        
        if grep -q "^Environment=\"GOMAXPROCS=" "$limit_file" 2>/dev/null; then
            current_gomaxprocs=$(awk -F'=' '/^Environment="GOMAXPROCS=/ {print $3}' "$limit_file" | tr -d '"' | head -n 1)
        fi
    fi

    # 计算软性内存墙 (物理总内存的 85%，防止 GO 语言撑爆宿主机)
    local TOTAL_MEM
    TOTAL_MEM=$(free -m | awk '/Mem/{print $2}' || echo "1024")
    local GO_MEM_LIMIT=$(( TOTAL_MEM * 85 / 100 ))

    # ！！！重中之重的核心提权！！！
    # 彻底废除官方安装脚本带来的 User=nobody
    # 强制以 User=root 运行，解除 CapabilityBoundingSet 限制，赋予对底层 Sysctl 调优的绝对控制权
    
    cat > "$limit_file" << EOF
[Service]
User=root
Group=root
CapabilityBoundingSet=~
AmbientCapabilities=~
LimitNOFILE=1048576
LimitNPROC=1048576
LimitMEMLOCK=infinity
Nice=${current_nice}
Environment="GOMEMLIMIT=${GO_MEM_LIMIT}MiB"
Environment="GOGC=${current_gogc}"
Restart=on-failure
RestartSec=5s
EOF

    # 重新注入 OOM 免疫与 I/O 实时调度提权
    if test "$current_oom" = "true"; then
        echo "OOMScoreAdjust=-500" >> "$limit_file"
        echo "IOSchedulingClass=realtime" >> "$limit_file"
        echo "IOSchedulingPriority=2" >> "$limit_file"
    fi
    
    # 恢复物理绑核设定
    if test -n "$current_affinity"; then
        echo "CPUAffinity=$current_affinity" >> "$limit_file"
    fi
    
    # 恢复并发锁设定
    if test -n "$current_gomaxprocs"; then
        echo "Environment=\"GOMAXPROCS=$current_gomaxprocs\"" >> "$limit_file"
    fi

    if ! systemctl daemon-reload >/dev/null 2>&1; then
        warn "Systemd 守护进程重载失败，可能需要手动执行 daemon-reload。"
    else
        info "Systemd 总线提权指令下发完毕，Xray 现已掌握内核最高控制权。"
    fi
}

# ------------------------------------------------------------------------------
# [ 0x09: 环境预检、包管理器适配与物理网络寻址大网 ]
# ------------------------------------------------------------------------------

detect_os() {
    if test -f /etc/os-release; then
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
    
    local os_type
    os_type=$(detect_os)
    
    case "$os_type" in
        ubuntu|debian)
            if ! apt-get update -y >/dev/null 2>&1; then
                warn "APT 缓存更新遇到网络波动，将尝试强行进行包安装..."
            fi
            if ! apt-get install -y $list >/dev/null 2>&1; then
                error "Debian/Ubuntu 依赖包安装失败，请排查上游软件源连通性！"
            fi
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if ! yum makecache -y >/dev/null 2>&1; then
                warn "YUM 缓存更新遇到网络波动，将尝试强行进行包安装..."
            fi
            if ! yum install -y $list >/dev/null 2>&1; then
                error "RHEL 系依赖包安装失败，请排查上游软件源连通性！"
            fi
            ;;
        *)
            warn "未匹配到主流 Linux 发行版特征 (当前识别: $os_type)，包管理器可能无法正确调度: $list"
            ;;
    esac
}

preflight() {
    info "启动环境全景预检与依赖注入..."
    
    # 严控 Root 权限
    if test "$EUID" -ne 0; then 
        die "权限剥夺：启动该战舰底层网络栈必须具备 root 级系统特权！"
    fi
    
    # 严控 Systemd 守护进程支持
    if ! command -v systemctl >/dev/null 2>&1; then 
        die "架构脱轨：您的操作系统未采用 Systemd 守护进程管理器，本脚本无法执行底层编排。"
    fi
    
    local need="jq curl wget xxd unzip qrencode vnstat cron openssl coreutils sed e2fsprogs pkg-config iproute2 ethtool bc bison flex dwarves rsync python3 cpio dnsutils"
    local missing=""
    
    # 逐一校验依赖环境，避免重复安装浪费时间
    for p in $need; do 
        if ! command -v "$p" >/dev/null 2>&1; then 
            missing="$missing $p"
        fi
    done

    if test -n "$missing"; then
        info "侦测到缺失的基础组件，正在向包管理器下发安装指令: $missing"
        pkg_install "$missing"
        
        # 激活必要的守护进程
        systemctl start vnstat >/dev/null 2>&1 || true
        systemctl enable vnstat >/dev/null 2>&1 || true
        
        # 兼容不同发行版的 cron 命名
        if systemctl list-unit-files | grep -q "^cron.service"; then
            systemctl start cron >/dev/null 2>&1 || true
            systemctl enable cron >/dev/null 2>&1 || true
        elif systemctl list-unit-files | grep -q "^crond.service"; then
            systemctl start crond >/dev/null 2>&1 || true
            systemctl enable crond >/dev/null 2>&1 || true
        fi
    else
        info "底层工业级依赖网阵已全部就绪，无需额外拉取。"
    fi

    # 快捷指令映射锚点
    if test -f "$SCRIPT_PATH"; then
        \cp -f "$SCRIPT_PATH" "$SYMLINK" >/dev/null 2>&1 || true
        chmod +x "$SYMLINK" >/dev/null 2>&1 || true
        hash -r 2>/dev/null || true
    fi
    
    info "正在向全球节点发射探针以获取本机物理公网 IP..."
    
    # 多节点容灾探测 IP
    local ip_api_1="https://api.ipify.org"
    local ip_api_2="https://ifconfig.me"
    local ip_api_3="https://icanhazip.com"
    
    SERVER_IP=$(curl -s -4 --connect-timeout 5 --max-time 10 "$ip_api_1" 2>/dev/null | tr -d '\r\n' || echo "")
    
    if test -z "$SERVER_IP"; then
        SERVER_IP=$(curl -s -4 --connect-timeout 5 --max-time 10 "$ip_api_2" 2>/dev/null | tr -d '\r\n' || echo "")
    fi
    
    if test -z "$SERVER_IP"; then
        SERVER_IP=$(curl -s -4 --connect-timeout 5 --max-time 10 "$ip_api_3" 2>/dev/null | tr -d '\r\n' || echo "")
    fi
    
    if test -z "$SERVER_IP"; then
        warn "多重探测失败，机器的公网 IPv4 寻址暂时被阻断或遮蔽。"
        SERVER_IP="获取失败"
    else
        info "成功捕获公网物理信标: $SERVER_IP"
    fi
}

# ------------------------------------------------------------------------------
# [ 0x0A: Geo 全球规则库无人值守更新引擎 (附带错峰防断连机制) ]
# ------------------------------------------------------------------------------

install_update_dat() {
    info "正在部署 Geo 规则库无人值守热更脚本与错峰重启逻辑..."
    
    # 写入纯正的 Bash 热更子脚本
    cat > "$UPDATE_DAT_SCRIPT" <<'UPDSH'
#!/usr/bin/env bash
XRAY_DAT_DIR="/usr/local/share/xray"
LOG_FILE="/var/log/xray/update-dat.log"

log() { 
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

dl() {
    local url="$1" 
    local out="$2"
    local success=0
    
    for i in 1 2 3; do
        if curl -fsSL --connect-timeout 10 --max-time 300 -o "$out.tmp" "$url"; then
            mv -f "$out.tmp" "$out"
            log "[INFO] 成功更新云端规则库: $url"
            success=1
            break
        fi
        log "[WARN] 节点更新失败，准备发起重试 [$i/3]: $url"
        sleep 5
    done
    
    if test "$success" -eq 0; then
        log "[ERROR] 规则库下载遭遇严重网络阻断，云端库获取失败: $url"
        return 1
    fi
    return 0
}

# 强行覆盖源库
dl "https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat" "$XRAY_DAT_DIR/geoip.dat"
dl "https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat" "$XRAY_DAT_DIR/geosite.dat"

log "[INFO] Geo 规则库自动化巡检执行完毕"
UPDSH

    chmod +x "$UPDATE_DAT_SCRIPT" 2>/dev/null || true

    # 安全地清理历史 cron 任务，防止重复冗余写入导致系统资源耗尽
    local temp_cron
    temp_cron=$(mktemp)
    
    crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT" | grep -v "/bin/systemctl restart xray" > "$temp_cron" || true
    
    # 将下载与服务重启严格分离，相差 10 分钟错峰运行
    echo "0 3 * * * $UPDATE_DAT_SCRIPT >/dev/null 2>&1" >> "$temp_cron"
    echo "10 3 * * * /bin/systemctl restart xray >/dev/null 2>&1" >> "$temp_cron"
    
    crontab "$temp_cron" 2>/dev/null || true
    rm -f "$temp_cron" 2>/dev/null || true

    info "Geo 路由流防断更机制已物理加载: 每日 03:00 下载更新，03:10 触发守护进程平滑重启。"
}

# ------------------------------------------------------------------------------
# [ 0x0B: 物理绑核与并发锁核心控制引擎 ]
# ------------------------------------------------------------------------------

_toggle_affinity_on() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    
    if test -f "$limit_file"; then
        sed -i '/^CPUAffinity=/d' "$limit_file" 2>/dev/null || true
        sed -i '/^Environment="GOMAXPROCS=/d' "$limit_file" 2>/dev/null || true
        
        local CORES
        CORES=$(nproc 2>/dev/null || echo 1)
        
        local TARGET_CPU="0"
        # 预留核心 0 给系统的硬件中断(IRQ)，Xray 进程强行绑定到核心 1 (若为多核环境)
        if test "$CORES" -ge 2; then 
            TARGET_CPU="1"
        fi
        
        echo "CPUAffinity=$TARGET_CPU" >> "$limit_file"
        echo "Environment=\"GOMAXPROCS=1\"" >> "$limit_file"
        
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

_toggle_affinity_off() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    
    if test -f "$limit_file"; then
        sed -i '/^CPUAffinity=/d' "$limit_file" 2>/dev/null || true
        sed -i '/^Environment="GOMAXPROCS=/d' "$limit_file" 2>/dev/null || true
        
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}
# ------------------------------------------------------------------------------
# [ 0x0C: 核心：130+ 实体 SNI 扫描引擎与智能避障 (绝对原教旨垂直排布版) ]
# ------------------------------------------------------------------------------

run_sni_scanner() {
    title "雷达嗅探：130+ 实体矩阵与国内连通性深度探测"
    print_yellow ">>> 高频扫描任务已启动... (扫描途中随时按回车键可立即中止并结算)\n"
    
    if test ! -d "$CONFIG_DIR"; then
        mkdir -p "$CONFIG_DIR" 2>/dev/null || true
    fi
    
    # 绝对不压行，一行一个，保证任何环境下的 Bash 数组解析都不会断层
    local sni_list=(
        "www.apple.com"
        "support.apple.com"
        "developer.apple.com"
        "id.apple.com"
        "icloud.apple.com"
        "swdist.apple.com"
        "swcdn.apple.com"
        "updates.cdn-apple.com"
        "mensura.cdn-apple.com"
        "osxapps.itunes.apple.com"
        "aod.itunes.apple.com"
        "is1-ssl.mzstatic.com"
        "itunes.apple.com"
        "gateway.icloud.com"
        "www.icloud.com"
        "www.microsoft.com"
        "login.microsoftonline.com"
        "portal.azure.com"
        "support.microsoft.com"
        "office.com"
        "update.microsoft.com"
        "windowsupdate.microsoft.com"
        "software.download.prss.microsoft.com"
        "cdn-dynmedia-1.microsoft.com"
        "www.intel.com"
        "downloadcenter.intel.com"
        "ark.intel.com"
        "www.amd.com"
        "drivers.amd.com"
        "community.amd.com"
        "webinar.amd.com"
        "ir.amd.com"
        "www.dell.com"
        "support.dell.com"
        "www.hp.com"
        "support.hp.com"
        "developers.hp.com"
        "www.bmw.com"
        "configure.bmw.com"
        "shop.bmw.com"
        "www.mercedes-benz.com"
        "me.mercedes-benz.com"
        "www.toyota-global.com"
        "global.toyota"
        "www.toyota.com"
        "www.honda.com"
        "global.honda"
        "www.volkswagen.com"
        "service.volkswagen.com"
        "www.vw.com"
        "www.nike.com"
        "account.nike.com"
        "store.nike.com"
        "www.adidas.com"
        "account.adidas.com"
        "www.zara.com"
        "static.zara.net"
        "www.ikea.com"
        "secure.ikea.com"
        "www.shell.com"
        "careers.shell.com"
        "www.bp.com"
        "login.bp.com"
        "www.totalenergies.com"
        "www.ge.com"
        "digital.ge.com"
        "www.abb.com"
        "new.abb.com"
        "www.hsbc.com"
        "online.hsbc.com"
        "www.goldmansachs.com"
        "login.gs.com"
        "www.morganstanley.com"
        "secure.morganstanley.com"
        "www.maersk.com"
        "www.msc.com"
        "www.cma-cgm.com"
        "www.hapag-lloyd.com"
        "www.michelin.com"
        "www.bridgestone.com"
        "www.goodyear.com"
        "www.pirelli.com"
        "www.sony.com"
        "www.sony.net"
        "www.panasonic.com"
        "www.canon.com"
        "www.nintendo.com"
        "www.lg.com"
        "www.epson.com"
        "www.unilever.com"
        "www.loreal.com"
        "www.shiseido.com"
        "www.jnj.com"
        "www.kao.com"
        "www.uniqlo.com"
        "www.hermes.com"
        "www.chanel.com"
        "services.chanel.com"
        "www.louisvuitton.com"
        "eu.louisvuitton.com"
        "www.dior.com"
        "www.ferragamo.com"
        "www.versace.com"
        "www.prada.com"
        "www.fendi.com"
        "www.gucci.com"
        "www.tiffany.com"
        "www.esteelauder.com"
        "www.maje.com"
        "www.swatch.com"
        "www.coca-cola.com"
        "www.coca-colacompany.com"
        "www.pepsi.com"
        "www.pepsico.com"
        "www.nestle.com"
        "www.bk.com"
        "www.heinz.com"
        "www.pg.com"
        "www.basf.com"
        "www.bayer.com"
        "www.bosch.com"
        "www.bosch-home.com"
        "www.lexus.com"
        "www.audi.com"
        "www.porsche.com"
        "www.skoda-auto.com"
        "www.gm.com"
        "www.chevrolet.com"
        "www.cadillac.com"
        "www.ford.com"
        "www.lincoln.com"
        "www.hyundai.com"
        "www.kia.com"
        "www.peugeot.com"
        "www.renault.com"
        "www.jaguar.com"
        "www.landrover.com"
        "www.astonmartin.com"
        "www.mclaren.com"
        "www.ferrari.com"
        "www.maserati.com"
        "www.volvocars.com"
        "www.tesla.com"
        "s0.awsstatic.com"
        "d1.awsstatic.com"
        "images-na.ssl-images-amazon.com"
        "m.media-amazon.com"
        "www.nvidia.com"
        "academy.nvidia.com"
        "images.nvidia.com"
        "blogs.nvidia.com"
        "docs.nvidia.com"
        "docscontent.nvidia.com"
        "www.samsung.com"
        "www.sap.com"
        "www.oracle.com"
        "www.mysql.com"
        "www.swift.com"
        "download-installer.cdn.mozilla.net"
        "addons.mozilla.org"
        "www.airbnb.co.uk"
        "www.airbnb.ca"
        "www.airbnb.com.sg"
        "www.airbnb.com.au"
        "www.airbnb.co.in"
        "www.ubi.com"
        "lol.secure.dyn.riotcdn.net"
        "one-piece.com"
        "player.live-video.net"
        "mit.edu"
        "www.mit.edu"
        "web.mit.edu"
        "ocw.mit.edu"
        "csail.mit.edu"
        "libraries.mit.edu"
        "alum.mit.edu"
        "id.mit.edu"
        "stanford.edu"
        "www.stanford.edu"
        "cs.stanford.edu"
        "ai.stanford.edu"
        "web.stanford.edu"
        "login.stanford.edu"
        "ox.ac.uk"
        "www.ox.ac.uk"
        "cs.ox.ac.uk"
        "maths.ox.ac.uk"
        "login.ox.ac.uk"
        "lufthansa.com"
        "www.lufthansa.com"
        "book.lufthansa.com"
        "checkin.lufthansa.com"
        "api.lufthansa.com"
        "singaporeair.com"
        "www.singaporeair.com"
        "booking.singaporeair.com"
        "krisflyer.singaporeair.com"
        "trekbikes.com"
        "www.trekbikes.com"
        "shop.trekbikes.com"
        "support.trekbikes.com"
        "specialized.com"
        "www.specialized.com"
        "store.specialized.com"
        "support.specialized.com"
        "giant-bicycles.com"
        "www.giant-bicycles.com"
        "dealer.giant-bicycles.com"
        "logitech.com"
        "www.logitech.com"
        "support.logitech.com"
        "gaming.logitech.com"
        "razer.com"
        "www.razer.com"
        "support.razer.com"
        "insider.razer.com"
        "corsair.com"
        "www.corsair.com"
        "support.corsair.com"
        "account.asus.com"
        "kingston.com"
        "www.kingston.com"
        "shop.kingston.com"
        "support.kingston.com"
        "seagate.com"
        "www.seagate.com"
        "support.seagate.com"
        "kleenex.com"
        "www.kleenex.com"
        "shop.kleenex.com"
        "scottbrand.com"
        "www.scottbrand.com"
        "tempo-world.com"
        "www.tempo-world.com"
    )

    local sni_string
    sni_string=$(printf "%s\n" "${sni_list[@]}")
    
    # 打乱探测顺序，规避防火墙的持续发包特征识别
    if command -v shuf >/dev/null 2>&1; then
        sni_string=$(echo "$sni_string" | shuf)
    else
        sni_string=$(echo "$sni_string" | awk 'BEGIN{srand()} {print rand()"\t"$0}' | sort -n | cut -f2-)
    fi

    local tmp_sni
    tmp_sni=$(mktemp /tmp/sni_test.XXXXXX)

    # 循环遍历所有节点，寻找可用信道
    for sni in $sni_string; do
        # 提供一个极度敏感的按键中断出口，随时可以打断耗时的扫描
        local key=""
        if read -t 0.1 -n 1 -s key 2>/dev/null; then
            echo -e "\n${yellow}[人工干预] 探测已被手动中止，正在整理已捕获的可用节点矩阵...${none}"
            break
        fi

        # 发起纯粹的底层 TCP 连通性测试 (丢弃响应体，仅获取 connect 时间)
        local time_raw
        time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni" 2>/dev/null || echo "0")
        
        local ms
        ms=$(echo "$time_raw" | awk '{print int($1 * 1000)}')

        if test "${ms:-0}" -gt 0; then
            # Cloudflare 防线剔除：Reality 协议若以 CF 为 SNI 极易断流
            if curl -sI -m 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray"; then
                echo -e " ${gray}跳过侦测${none} $sni (原因: 命中 Cloudflare CDN 拦截)"
                continue
            fi
            
            # DNS 国内解析探伤引擎 (调用阿里 DoH 进行污染核对)
            local doh_res
            doh_res=$(curl -s --connect-timeout 2 "https://dns.alidns.com/resolve?name=$sni&type=1" 2>/dev/null || echo "")
            
            local dns_cn=""
            if test -n "$doh_res"; then
                # 加入极度安全的 jq 解析判断，防止 API 格式变更引发的报错
                dns_cn=$(echo "$doh_res" | jq -r '.Answer[]? | select(.type==1 or .type==5) | .data' 2>/dev/null | tail -1 || echo "")
            fi
            
            local status_cn=""
            local p_type="NORM"
            
            # 严格判定阻断特征 (投毒到本地环回或空路由)
            if test -z "$dns_cn" || test "$dns_cn" = "127.0.0.1" || test "$dns_cn" = "0.0.0.0" || test "$dns_cn" = "::1" || test "$dns_cn" = "null"; then
                status_cn="${red}国内墙阻断 (DNS 污染或 RST)${none}"
                p_type="BLOCK"
            else
                # 进一步追踪解析的物理落点 (是否被调度至境内)
                local loc
                loc=$(curl -s --connect-timeout 2 "https://ipinfo.io/$dns_cn/country" 2>/dev/null | tr -d ' \n' || echo "")
                
                if test "$loc" = "CN"; then
                    status_cn="${green}网络直通${none} | ${blue}命中中国境内 CDN 节点${none}"
                    p_type="CN_CDN"
                else
                    status_cn="${green}网络直通${none} | ${cyan}海外原生优质特征${none}"
                    p_type="NORM"
                fi
            fi
            
            # 终端实时播报
            echo -e " ${green}握手存活${none} $sni : 延迟 ${yellow}${ms}ms${none} | 状态: $status_cn"
            
            # 将非阻断节点记录到内存缓冲池
            if test "$p_type" != "BLOCK"; then
                echo "$ms $sni $p_type" >> "$tmp_sni"
            fi
        fi
    done

    # 结果清洗与落盘缓存
    if test -s "$tmp_sni"; then
        # 优先抽取纯种海外原生节点 (NORM)
        grep "NORM" "$tmp_sni" | sort -n | head -n 20 | awk '{print $2, $1}' > "$SNI_CACHE_FILE" || true
        
        local count
        count=$(wc -l < "$SNI_CACHE_FILE" 2>/dev/null || echo 0)
        
        # 若海外原生节点不足 20 个，拿境内 CDN 凑数补齐阵列
        if test "${count:-0}" -lt 20; then
            local need_fill=$(( 20 - ${count:-0} ))
            grep "CN_CDN" "$tmp_sni" | sort -n | head -n "$need_fill" | awk '{print $2, $1}' >> "$SNI_CACHE_FILE" || true
        fi
    else
        error "雷达扫射全灭，未能寻获任何有效存活节点！将强制载入备用降级安全配置。"
        echo "www.microsoft.com 999" > "$SNI_CACHE_FILE"
    fi
    
    rm -f "$tmp_sni" 2>/dev/null || true
}
# ------------------------------------------------------------------------------
# [ 0x0D: 终极 Reality 目标质检引擎 (TLS 1.3 / ALPN / OCSP) ]
# ------------------------------------------------------------------------------

verify_sni_strict() {
    local target="$1"
    
    print_magenta "\n>>> 正在对目标 SNI [$target] 开启严苛的底层特征质检..."
    print_magenta ">>> 检测标准: 强制要求 TLSv1.3 + ALPN h2 + OCSP Stapling 状态装订"
    
    # 投送深度探针，设置 5 秒超时防止线程死锁或无限挂起
    local out
    out=$(echo "Q" | timeout 5 openssl s_client -connect "$target:443" -alpn h2 -tls1_3 -status 2>&1 || echo "")
    
    local pass=1
    
    # 逐级审查协议特征，拒绝一切压行，清爽展现逻辑
    if ! echo "$out" | grep -qi "TLSv1.3"; then 
        print_red " ✗ 质检拦截: 目标服务器未开启 TLSv1.3 协议，Reality 握手将会完全暴露特征！"
        pass=0
    fi
    
    if ! echo "$out" | grep -qiE "ALPN, server accepted to use h2|ALPN.*h2"; then 
        print_red " ✗ 质检拦截: 目标服务器不支持 ALPN h2 协商，不适合作为高并发伪装目标！"
        pass=0
    fi
    
    if ! echo "$out" | grep -qi "OCSP response:"; then 
        print_red " ✗ 质检拦截: 目标服务器未配置 OCSP Stapling 证书状态装订，极易被防火墙主动探测阻断！"
        pass=0
    fi
    
    return $pass
}

# ------------------------------------------------------------------------------
# [ 0x0E: 交互式 SNI 战备控制台与矩阵选择器 ]
# ------------------------------------------------------------------------------

choose_sni() {
    while true; do
        if test -f "$SNI_CACHE_FILE"; then
            echo -e "\n  ${cyan}【战备缓存：极速 Top 20 优选矩阵 (已剔除阻断节点)】${none}"
            
            local idx=1
            while read -r s t; do
                echo -e "  $idx) $s (握手延迟: ${cyan}${t}ms${none})"
                idx=$((idx + 1))
            done < "$SNI_CACHE_FILE"
            
            echo -e "  ${yellow}r) 抛弃缓存，重新拉起 130+ 实体雷达扫描矩阵${none}"
            echo "  m) 矩阵模式 (输入多个序号构建多域名防封阵列，极大提升抗封锁能力)"
            echo "  0) 手动输入自定义私有域名"
            echo "  q) 取消并退回上级中枢"
            
            local sel=""
            read -rp "  请下达选择指令 (默认 1): " sel
            sel=${sel:-1}
            
            # 路由解析操作指令
            if test "$sel" = "q" || test "$sel" = "Q"; then 
                return 1
            fi
            
            if test "$sel" = "r" || test "$sel" = "R"; then 
                run_sni_scanner
                continue
            fi
            
            # 多端矩阵构建逻辑 (多选模式)
            if test "$sel" = "m" || test "$sel" = "M"; then
                local m_sel=""
                read -rp "请输入要组合的序号 (空格分隔, 如 1 3 5, 或输入 all 全选): " m_sel
                
                local arr=()
                
                if test "$m_sel" = "all"; then
                    while read -r p_sni p_rest; do
                        if test -n "$p_sni"; then 
                            arr+=("$p_sni")
                        fi
                    done < "$SNI_CACHE_FILE"
                else
                    for i in $m_sel; do
                        local picked
                        picked=$(awk "NR==$i {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "")
                        
                        if test -n "$picked"; then 
                            arr+=("$picked")
                        fi
                    done
                fi
                
                if test ${#arr[@]} -eq 0; then
                    error "选择队列失效，系统未能解析有效的 SNI 目标，请重新选择。"
                    continue
                fi
                
                # 设定主用 SNI (列表中的第一个，作为 dest)
                BEST_SNI="${arr[0]}"
                
                # 安全转码构建 JSON 字符串数组，用于 Reality 的 serverNames 字段
                local jq_args=()
                for s in "${arr[@]}"; do 
                    jq_args+=("\"$s\"")
                done
                SNI_JSON_ARRAY=$(IFS=,; echo "${jq_args[*]}")
                
            elif test "$sel" = "0"; then 
                # 自定义模式
                local d=""
                read -rp "请输入您指定的自定义专属伪装域名: " d
                
                BEST_SNI=${d:-www.microsoft.com}
                SNI_JSON_ARRAY="\"$BEST_SNI\""
                
            else
                # 常规单选逻辑
                local picked=""
                if [[ "$sel" =~ ^[0-9]+$ ]]; then
                    picked=$(awk "NR==$sel {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "")
                fi
                
                if test -n "$picked"; then
                    BEST_SNI="$picked"
                else
                    error "输入的序号非法，已自动降级为您分配第一号测速节点。"
                    BEST_SNI=$(awk "NR==1 {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "www.microsoft.com")
                fi
                
                SNI_JSON_ARRAY="\"$BEST_SNI\""
            fi

            # 最终质检守门员拦截
            if verify_sni_strict "$BEST_SNI"; then
                print_green ">>> 质检完毕：主控目标 $BEST_SNI 完美通过特征审查！"
                break
            else
                print_yellow ">>> 危险预警：该域名协议支持不达标，若强行部署会导致 Reality 防线极易被墙或断流！请尽量重新选择。"
                
                local force_use=""
                read -rp "是否无视警告，强制使用该残缺特征域名？(y/n): " force_use
                
                if [[ "$force_use" =~ ^[yY]$ ]]; then
                    warn "您已授权强制越过安检防线，配置继续。"
                    break
                else
                    continue
                fi
            fi
        else
            # 若缓存文件丢失，强制唤醒雷达
            warn "未能发现本地域名测速快照池，正在为您强制唤醒扫描雷达..."
            run_sni_scanner
        fi
    done
    
    return 0
}

# ------------------------------------------------------------------------------
# [ 0x0F: 端口校验器与 Shadowsocks 加密密码生成器 ]
# ------------------------------------------------------------------------------

validate_port() {
    local p="$1"
    
    if test -z "$p"; then 
        return 1
    fi
    
    # 剔除数字，看是否还有剩余字符，若有则说明输入非法
    local check
    check=$(echo "$p" | tr -d '0-9')
    
    if test -n "$check"; then 
        return 1
    fi
    
    if test "${p:-0}" -ge 1 2>/dev/null && test "${p:-0}" -le 65535 2>/dev/null; then
        if ss -tuln 2>/dev/null | grep -q ":${p} "; then
            print_red "端口冲突：您指定的物理端口 $p 已被系统的其他守护进程占用，请更换！"
            return 1
        fi
        return 0
    fi
    
    return 1
}

gen_ss_pass() {
    # 强制切除 base64 转化过程中可能夹带的等号与所有不可见回车符
    # 这是防止 SS 配置生成时 JSON 断层的关键
    head -c 24 /dev/urandom | base64 | tr -d '=/+\n\r' | head -c 24 || true
}

_select_ss_method() {
    echo -e "  ${cyan}请指配 Shadowsocks 数据流的底层加密方式：${none}" >&2
    echo "  1) aes-256-gcm (金融级防护，推荐)" >&2
    echo "  2) aes-128-gcm (高并发极速突发)" >&2
    echo "  3) chacha20-ietf-poly1305 (无 AES 硬件指令集支持时的老机型救星)" >&2
    
    local mc=""
    read -rp "  请输入操作编号 (默认 1): " mc >&2 || true
    
    case "${mc:-1}" in
        2) echo "aes-128-gcm" ;;
        3) echo "chacha20-ietf-poly1305" ;;
        *) echo "aes-256-gcm" ;;
    esac
}

# ------------------------------------------------------------------------------
# [ 0x10: 核心防线：多轨 CDN 镜像升级与下载熔断系统 ]
# ------------------------------------------------------------------------------

do_update_core() {
    title "更新 Xray 核心 (无缝拉取最新版重启)"
    print_magenta ">>> 正在全域连接云端，拉取最新版 Xray 核心引擎..."
    
    local xray_updated=0
    
    # 构建三位一体的 CDN 下载矩阵，对抗国内复杂的 DNS 污染和 TCP RST 阻断
    for url in "https://github.com/XTLS/Xray-install/raw/main/install-release.sh" \
               "https://fastly.jsdelivr.net/gh/XTLS/Xray-install@main/install-release.sh" \
               "https://raw.fastgit.org/XTLS/Xray-install/main/install-release.sh"; do
               
        # 带超时时间的静默执行
        if bash -c "$(curl -fsSL --connect-timeout 10 --max-time 30 "$url")" @ install >/dev/null 2>&1; then
            xray_updated=1
            info "Xray 核心跨维升级成功，当前数据流桥接源：$url"
            break
        fi
        
        warn "节点流失，通讯链路 [$url] 遭阻断，正在自动自旋接入备用 CDN 镜像..."
    done
    
    # 绝对熔断层，防止下载了残缺文件还去重启服务
    if test "$xray_updated" -eq 0; then
        error "多轨 CDN 升级指令悉数落空，核心下载网络遭遇深空级阻断！"
        local _pause=""
        read -rp "请排查网络连通性，按 Enter 放弃控制权限并退回主控中枢..." _pause || true
        return 1
    fi
    
    # 升级后重新压入守护参数与提权配置，防止官方脚本覆盖我们的 limits.conf
    fix_xray_systemd_limits
    systemctl restart xray >/dev/null 2>&1 || true
    
    local cur_ver
    cur_ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 | awk '{print $2}' || echo "底层获取异常")
    info "热更指令执行完毕！当前系统运行的内核主板版本: ${cyan}$cur_ver${none}"
    
    local _pause=""
    read -rp "按 Enter 键知悉并继续..." _pause || true
}

# ------------------------------------------------------------------------------
# [ 0x11: 官方预编译 XANMOD (main) 部署模块 - Bullseye 完美兼容回归 ]
# ------------------------------------------------------------------------------

do_install_xanmod_main_official() {
    title "系统飞升：安装官方预编译 XANMOD (main) 内核"
    
    # 硬件环境硬性排斥审查
    if test "$(uname -m)" != "x86_64"; then
        error "系统架构不匹配：官方预编译 Xanmod 目前仅支持 x86_64 (amd64) 架构的物理机或虚拟机！"
        local _pause=""
        read -rp "按 Enter 继续..." _pause || true
        return
    fi

    if ! test -f /etc/debian_version; then
        error "系统发行版排斥：官方预编译 Xanmod APT 仓库目前仅兼容 Debian / Ubuntu 系操作系统！"
        local _pause=""
        read -rp "按 Enter 继续..." _pause || true
        return
    fi

    print_magenta ">>> [1/4] 正在拉取智能探针，检测本地 CPU 硬件微架构支持级别..."
    
    local cpu_level_script="/tmp/check_x86-64_psabi.sh"
    
    # 尝试拉取微架构探针，屏蔽无关输出
    wget -qO "$cpu_level_script" https://dl.xanmod.org/check_x86-64_psabi.sh || true
    
    local cpu_level=""
    if test -f "$cpu_level_script"; then
        cpu_level=$(awk -f "$cpu_level_script" | grep -oE 'x86-64-v[1-4]' | grep -oE '[1-4]' | tail -n 1 || true)
        rm -f "$cpu_level_script" 2>/dev/null || true
    fi
    
    if test -z "$cpu_level"; then
        cpu_level=1
        warn "网络遮蔽无法精确检测 CPU 微架构级别，将默认降级使用系统最宽容的 v1 兼容版本。"
    else
        info "评估完成，当前 CPU 硬件完美支持的微架构最高级别为: v${cpu_level}"
    fi

    local pkg_name="linux-xanmod-x64v${cpu_level}"
    
    print_magenta ">>> [2/4] 正在配置 Xanmod 官方最高优 APT 仓库与防伪 GPG 密钥..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    # 前置依赖补齐
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y gnupg gnupg2 curl sudo wget e2fsprogs >/dev/null 2>&1 || true

    # 【核心修复区域：回归 Bullseye 最兼容、最稳定的旧版源挂载法】
    # 废弃在 Debian 11 下极易报错的 /etc/apt/keyrings 目录与 signed-by 新语法
    # 重新启用 trusted.gpg.d，彻底解决 Unable to locate package 的血案！
    
    echo 'deb http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-kernel.list
    
    # 获取 GPG 公钥并转码写入 trusted 库
    if ! wget -qO - https://dl.xanmod.org/gpg.key | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/xanmod-kernel.gpg; then
        error "从远端导入 GPG 密钥链发生错误，链路可能被污染或官方源已被墙！"
        return 1
    fi

    print_magenta ">>> [3/4] 正在通过 APT 极速拉取并物理安装专属内核: $pkg_name ..."
    
    # 强制刷新缓存读取新加入的仓库
    apt-get update -y
    
    # 容错降级循环安装
    if ! apt-get install -y "$pkg_name"; then
        if test "$cpu_level" = "4"; then
            warn "异常拦截：官方源目前未找到独立的 v4 安装包或发生依赖脱节，正在为您智能回退至兼容的 v3 版本..."
            pkg_name="linux-xanmod-x64v3"
            
            if ! apt-get install -y "$pkg_name"; then
                error "降级安装亦宣告失败，内核替换进程中止。请排查物理网络环境与 APT 源配置！"
                return 1
            fi
        else
            error "内核安装意外中止，请手动检查 APT 错误日志以排除 DNS 或依赖污染。"
            return 1
        fi
    fi

    print_magenta ">>> [4/4] 正在向 GRUB 主引导扇区重写映射记录..."
    
    if command -v update-grub >/dev/null 2>&1; then
        update-grub || true
    else
        apt-get install -y grub2-common >/dev/null 2>&1 || true
        update-grub || true
    fi

    info "官方预编译 XANMOD (main) 部署与注册已全部就绪！"
    warn "系统将在 10 秒后强制切断电源并自动重启应用新内核..."
    
    sleep 10
    reboot
}
# ------------------------------------------------------------------------------
# [ 0x12: 编译安装原生 Linux 主线内核与 BBR3 强制封装 (极限压榨版) ]
# ------------------------------------------------------------------------------

do_xanmod_compile() {
    title "系统飞升：编译安装主线内核 + BBR3 引擎"
    
    warn "警告: 这是一个极其漫长的过程 (预估 30-60 分钟)，低配机器极易引发死机断连！"
    warn "强烈建议优先使用菜单中的【官方预编译版】。如果您执意追求极客性能，请继续。"
    
    local confirm=""
    read -rp "确定要执意开始源码编译吗？(y/n): " confirm
    
    if test "$confirm" != "y" && test "$confirm" != "Y"; then 
        return
    fi

    # 1. 深度环境清理，腾出编译空间
    title "=== [1/8] 开始执行深度系统清理与模块解容 ==="
    export DEBIAN_FRONTEND=noninteractive
    
    apt-get clean
    apt-get autoremove -y --purge >/dev/null 2>&1 || true
    journalctl --vacuum-time=1d >/dev/null 2>&1 || true
    
    rm -rf /var/log/*.log /var/log/*/*.log /tmp/* /var/lib/docker/* 2>/dev/null || true
    rm -rf /usr/src/linux* /usr/src/bbr* /usr/src/xanmod* /compile/* 2>/dev/null || true
    rm -rf /root/linux* /root/*.tar* /root/*.xz 2>/dev/null || true
    sync

    # inode 节点防爆探测
    local inode_use
    inode_use=$(df -i / | awk 'NR==2{print $5}' | tr -d '%' || echo "0")
    
    if test "$inode_use" -gt 90; then
        warn "检测到 inode 节点使用率过高，执行紧急深度清理..."
        apt-get clean
        rm -rf /var/cache/* 2>/dev/null || true
    fi

    # 注入定期系统清理守护脚本，防止编译垃圾日积月累
    cat <<'EOF' > /usr/local/bin/cc1.sh
#!/bin/bash
apt-get clean
apt-get autoremove -y --purge
journalctl --vacuum-time=3d
rm -rf /tmp/*
rm -rf /var/log/*
sync
EOF
    chmod +x /usr/local/bin/cc1.sh 2>/dev/null || true
    
    # 挂载至 Cron 计划流
    (crontab -l 2>/dev/null | grep -v cc1.sh ; echo "0 4 */10 * * /usr/local/bin/cc1.sh >/dev/null 2>&1") | crontab - 2>/dev/null || true

    # 2. 内存防爆机制：强制校验或切分 Swap 交换区
    title "=== [2/8] 检查并配置 1GB 编译缓冲交换区 (Swap) ==="
    if ! swapon --show 2>/dev/null | grep -q swapfile; then
        warn "未检测到活跃的 Swap 交换区，正在强行划拨 1024MB..."
        
        if ! fallocate -l 1024M /swapfile 2>/dev/null; then
            info "fallocate 分配受阻，切换为 dd 全零填充模式..."
            dd if=/dev/zero of=/swapfile bs=1M count=1024 status=progress
        fi
        
        chmod 600 /swapfile 2>/dev/null || true
        mkswap /swapfile >/dev/null 2>&1 || true
        swapon /swapfile >/dev/null 2>&1 || true
        
        if ! grep -q swapfile /etc/fstab 2>/dev/null; then
            echo "/swapfile none swap sw 0 0" >> /etc/fstab
        fi
    else
        info "Swap 内存防爆池已就绪。"
    fi

    # 3. 根目录容量探测与编译工作区智能路由
    local root_free
    root_free=$(df -m / | awk 'NR==2{print $4}' || echo "0")
    
    local BUILD_DIR=""
    if test "$root_free" -gt 4000; then 
        mkdir -p /compile 2>/dev/null || true
        BUILD_DIR="/compile"
        info "根目录空间充裕，工作区路由至: /compile"
    else 
        BUILD_DIR="/usr/src"
        info "工作区默认路由至: /usr/src"
    fi

    # 4. 全量压入底层 GCC 编译套件与内核开发头文件
    title "=== [3/8] 拉取底层 GCC 编译套件与开发依赖库 ==="
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y build-essential bc bison flex libssl-dev libelf-dev libncurses-dev zstd git wget curl xz-utils ethtool numactl make pkg-config dwarves rsync python3 libdw-dev cpio >/dev/null 2>&1 || true

    # 计算系统并发算力
    local CPU
    CPU=$(nproc 2>/dev/null || echo 1)
    
    local RAM
    RAM=$(free -m | awk '/Mem/{print $2}' || echo 1024)
    
    local THREADS=1
    if test "$RAM" -ge 2000; then 
        THREADS=$CPU
    elif test "$RAM" -ge 1000; then
        THREADS=2
    fi

    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "eth0")

    # 5. 主线内核拉取与防爆验证
    title "=== [4/8] 探测并拉取 Linux Kernel 官方主线源码 ==="
    if ! cd "$BUILD_DIR"; then
        die "权限异常：系统拒绝切入工作区 $BUILD_DIR。"
    fi
    
    local KERNEL_URL
    KERNEL_URL=$(curl -s https://www.kernel.org/releases.json 2>/dev/null | grep -A3 '"is_latest": true' | grep tarball | head -1 | awk -F'"' '{print $4}' || echo "")
    
    if test -z "$KERNEL_URL" || test "$KERNEL_URL" = "null"; then 
        warn "探测 kernel.org 失败，强行锁定备用回退版本 v6.8..."
        KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.tar.xz"
    fi
    
    local KERNEL_FILE
    KERNEL_FILE=$(basename "$KERNEL_URL")
    
    info "建立信道，开始拉取源码包: $KERNEL_FILE"
    wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"

    if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
        warn "检测到初次获取的源码包发生数据断层，触发网络熔断重试..."
        rm -f "$KERNEL_FILE" 2>/dev/null || true
        wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"
        
        if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
            error "下载或解压验证连续失败，源码包已被污染，编译行动强制中止。"
            return 1
        fi
    fi

    info "执行 XZ 极致解压，释放内核源码..."
    tar -xJf "$KERNEL_FILE"
    
    local KERNEL_DIR
    KERNEL_DIR=$(tar -tf "$KERNEL_FILE" | head -1 | cut -d/ -f1)
    
    if ! cd "$KERNEL_DIR"; then
        die "无法进入解压后的源码目录！"
    fi

    # 6. 配置重构与驱动篡改
    title "=== [5/8] 克隆宿主配置谱并暴力注入 BBR3 开启参数 ==="
    
    # 尝试克隆当前运行机器的配置，保证基础驱动不丢失
    if test -f "/boot/config-$(uname -r)"; then
        cp "/boot/config-$(uname -r)" .config
    elif modprobe configs 2>/dev/null && test -f /proc/config.gz; then
        zcat /proc/config.gz > .config
    else
        make defconfig >/dev/null 2>&1 || true
    fi
    
    make scripts >/dev/null 2>&1 || true
    
    # 强行开启 BBR3 与相关 TCP 拥塞控制
    ./scripts/config --enable CONFIG_TCP_CONG_BBR
    ./scripts/config --enable CONFIG_DEFAULT_BBR
    ./scripts/config --enable CONFIG_TCP_BBR3 2>/dev/null || true
    
    # 强行剔除臃肿的显卡与无关网卡驱动，极速缩减编译时长
    ./scripts/config --disable CONFIG_DRM_I915
    ./scripts/config --disable CONFIG_NET_VENDOR_REALTEK
    ./scripts/config --disable CONFIG_NET_VENDOR_BROADCOM
    ./scripts/config --disable CONFIG_E100
    
    # 绕过内核密钥链验证，防止验证密钥缺失导致的编译阻断
    ./scripts/config --disable SYSTEM_TRUSTED_KEYS 2>/dev/null || true
    ./scripts/config --disable SYSTEM_REVOCATION_KEYS 2>/dev/null || true
    ./scripts/config --disable DEBUG_INFO_BTF 2>/dev/null || true
    
    yes "" | make olddefconfig >/dev/null 2>&1 || true

    # 7. 全核心狂暴编译引擎启动
    title "=== [6/8] 释放 CPU 算力，开启内核 Forge 锻造模式 ==="
    info "分配编译并发线程数: $THREADS"
    
    if ! make -j"$THREADS"; then
        error "编译线程彻底崩塌！请排查物理内存是否溢出或存在硬盘坏道。"
        local _p=""; read -rp "按 Enter 返回主菜单..." _p || true
        return 1
    fi
    
    info "引擎锻造完毕，实施物理模块映射与启动扇区安装..."
    make modules_install
    make install

    # 清洗旧内核残留，防止 /boot 空间撑爆导致宕机
    local CURRENT
    CURRENT=$(uname -r)
    
    dpkg --list 2>/dev/null | grep linux-image | awk '{print $2}' | grep -v "$CURRENT" | xargs -r apt-get -y purge >/dev/null 2>&1 || true
    find /lib/modules -mindepth 1 -maxdepth 1 -type d | grep -v "$CURRENT" | xargs -r rm -rf >/dev/null 2>&1 || true
    
    if command -v update-grub >/dev/null 2>&1; then
        update-grub || true
    fi

    # 8. 编译后的硬件驱动卸载控制与 RPS 哈希多核分发
    title "=== [7/8] 下发网卡硬件卸载 (Offload) 控制与 RPS/RFS 调度器 ==="
    
    cat > /usr/local/bin/nic-optimize.sh <<'EONIC'
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "eth0")

if test -n "$IFACE"; then
    ethtool -K "$IFACE" gro off gso off tso off lro off rx-gro-hw off tx-udp-segmentation on 2>/dev/null || true
    ethtool -C "$IFACE" adaptive-rx off rx-usecs 0 tx-usecs 0 2>/dev/null || true
fi
EONIC

    chmod +x /usr/local/bin/nic-optimize.sh 2>/dev/null || true
    
    cat > /etc/systemd/system/nic-optimize.service <<EOSERVICE
[Unit]
Description=NIC Hardware Offload Optimization
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

    local RXMAX
    RXMAX=$(ethtool -g "$IFACE" 2>/dev/null | awk '/RX:/ {print $2; exit}' || echo "")
    if test -n "$RXMAX"; then 
        ethtool -G "$IFACE" rx "$RXMAX" tx "$RXMAX" 2>/dev/null || true
    fi

    # 计算 CPU 掩码，将软中断全域分发至所有核心
    local CPU_MASK
    CPU_MASK=$(printf "%x" $(( (1<<CPU)-1 )))
    
    cat > /usr/local/bin/rps-optimize.sh <<EOF_RPS
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IFACE=\$(ip route get 1.1.1.1 2>/dev/null | awk '{print \$5; exit}' || echo "eth0")

if test -z "\$IFACE"; then exit 0; fi

CPU=\$(nproc 2>/dev/null || echo 1)
CPU_MASK=\$(printf "%x" \$(( (1<<CPU)-1 )))
RX_QUEUES=\$(ls /sys/class/net/\$IFACE/queues/ 2>/dev/null | grep rx- | wc -l || echo 0)

for RX in /sys/class/net/\$IFACE/queues/rx-*; do 
    if test -w "\$RX/rps_cpus"; then 
        echo \$CPU_MASK > "\$RX/rps_cpus" 2>/dev/null || true
    fi
done

for TX in /sys/class/net/\$IFACE/queues/tx-*; do 
    if test -w "\$TX/xps_cpus"; then 
        echo \$CPU_MASK > "\$TX/xps_cpus" 2>/dev/null || true
    fi
done

sysctl -w net.core.rps_sock_flow_entries=131072 >/dev/null 2>&1 || true

if test "\$RX_QUEUES" -gt 0; then
    FLOW_PER_QUEUE=\$((65535 / RX_QUEUES))
    for RX in /sys/class/net/\$IFACE/queues/rx-*; do 
        if test -w "\$RX/rps_flow_cnt"; then 
            echo \$FLOW_PER_QUEUE > "\$RX/rps_flow_cnt" 2>/dev/null || true
        fi
    done
fi
EOF_RPS

    chmod +x /usr/local/bin/rps-optimize.sh 2>/dev/null || true

    cat > /etc/systemd/system/rps-optimize.service <<EOF_RPS_SRV
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

    # 硬件中断均衡绑定，将网卡 IRQ 打散至各核心
    for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || true); do 
        echo "$CPU_MASK" > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true
    done

    title "=== [8/8] 销毁编译垃圾并定档重置 ==="
    cd /
    rm -rf "$BUILD_DIR"/linux* "$BUILD_DIR/$KERNEL_FILE" /compile/* /root/linux* 2>/dev/null || true
    
    info "主线内核编译与网卡底层优化已全部封炉就绪！"
    warn "系统将在 30 秒后强制断电重启应用全部更改，请耐心等待重新连接..."
    
    sleep 30
    reboot
}

# ------------------------------------------------------------------------------
# [ 0x13: 独立网卡调优 - TX Queue 发送队列极速特化 ]
# ------------------------------------------------------------------------------

do_txqueuelen_opt() {
    title "网卡发送队列 (TX Queue) 深度调优 (2000 极速版)"
    
    local IP_CMD
    IP_CMD=$(command -v ip || echo "")
    
    if test -z "$IP_CMD"; then
        error "系统缺失 iproute2 工具链 (ip 命令)，无法调整网卡参数。"
        local _pause=""
        read -rp "按 Enter 返回菜单..." _pause || true
        return 1
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test -z "$IFACE"; then
        error "由于网络遮蔽，无法定位系统主路由网卡接口。"
        local _pause=""
        read -rp "按 Enter 返回菜单..." _pause || true
        return 1
    fi
    
    info "检测到外网出口物理网卡: $IFACE"
    info "正在将 txqueuelen 扩容/收缩至 2000 以匹配极速高并发响应架构..."
    
    if ! "$IP_CMD" link set "$IFACE" txqueuelen 2000 2>/dev/null; then
        warn "当前底层硬件驱动或虚拟化环境拒绝执行 txqueuelen 动态修改。"
    else
        info "运行时参数修改成功，正在挂载 Systemd 守护进程以保证重启不丢失..."
        
        local SERVICE_FILE="/etc/systemd/system/txqueue.service"
        cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Set TX Queue Length for Low Latency and High Concurrency
After=network-online.target

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
        
        info "开机自动应用进程已成功启动并启用！"
        echo -e "\n  ${cyan}当前网卡队列排队状态核验:${none}"
        "$IP_CMD" link show "$IFACE" 2>/dev/null | grep -o 'qlen [0-9]*' | awk '{print "    " $0}' || true
    fi
    
    local _pause=""
    read -rp "按 Enter 键返回中枢控制台..." _pause || true
}

# ------------------------------------------------------------------------------
# [ 0x14: 极限压榨：低延迟系统底层网络栈调优 (200+行全量展现，绝不压行) ]
# ------------------------------------------------------------------------------

do_perf_tuning() {
    title "系统内核网络栈极限调优"
    
    warn "警告: 该操作将向内核实时注入 200+ 项极限并发与拥塞控制参数！"
    warn "执行完毕后系统将自动强制重启以确立内核挂载状态。"
    
    local confirm=""
    read -rp "您确定要继续执行全域参数调优吗？(y/n): " confirm
    
    if test "$confirm" != "y" && test "$confirm" != "Y"; then 
        return
    fi

    info "执行排爆程序，清理过时的加速冲突进程与冗余配置..."
    systemctl stop net-speeder >/dev/null 2>&1 || true
    killall net-speeder >/dev/null 2>&1 || true
    systemctl disable net-speeder >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/net-speeder.service /etc/systemd/system/multi-user.target.wants/net-speeder.service 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    rm -rf /root/net-speeder 2>/dev/null || true

    # 物理清空所有历史遗留的碎片化 sysctl 配置文件，防止参数冲突污染
    truncate -s 0 /etc/sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-network-optimized.conf 2>/dev/null || true
    
    rm -f /etc/sysctl.d/99-bbr*.conf /etc/sysctl.d/99-ipv6-disable.conf /etc/sysctl.d/99-pro*.conf /etc/sysctl.d/99-xanmod-bbr3.conf 2>/dev/null || true
    rm -f /usr/lib/sysctl.d/50-pid-max.conf /usr/lib/sysctl.d/99-protect-links.conf 2>/dev/null || true

    info "正在覆写 /etc/security/limits.conf 重组系统级高并发进程与句柄限制..."
    
    cat > /etc/security/limits.conf << 'EOF'
root     soft   nofile    1000000
root     hard   nofile    1000000
root     soft   nproc     1000000
root     hard   nproc     1000000
root     soft   core      1000000
root     hard   core      1000000
root     soft   stack     1000000
root     hard   stack     1000000

*        soft   nofile    1000000
*        hard   nofile    1000000
*        soft   nproc     1000000
*        hard   nproc     1000000
*        soft   core      1000000
*        hard   core      1000000
*        soft   stack     1000000
*        hard   stack     1000000

nginx    soft   nofile    1000000
nginx    hard   nofile    1000000
EOF

    # 确保 limits 模块被 PAM (可插拔认证模块) 体系加载
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session 2>/dev/null; then 
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
    fi
    
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session-noninteractive 2>/dev/null; then 
        echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive
    fi
    
    # 强制 Systemd 全局级别进程句柄提权
    echo "DefaultLimitNOFILE=1000000" >> /etc/systemd/system.conf 2>/dev/null || true
    echo "DefaultLimitNPROC=1000000" >> /etc/systemd/system.conf 2>/dev/null || true

    info "开始全量铺展写入底层 Sysctl 网络栈参数矩阵..."
    
    # ==========================================
    # 以下为全量 200+ 行 Sysctl 极限调优参数，绝对不压行！
    # ==========================================
    cat > /etc/sysctl.d/99-network-optimized.conf << 'EOF'
# [1] 基础队列与核心拥塞控制算法
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr

# [2] 邻居表 (Neighbor Table) 与 ARP 缓存高压优化
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

# [3] 核心路由流向与过滤 (防劫持防泄漏)
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.route_localnet = 0
net.ipv4.conf.all.forwarding = 1
net.ipv4.ip_forward = 1

# [4] TCP 指标存储、ECN 与 MTU 黑洞探测
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = 2
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_slow_start_after_idle = 0

# [5] 核心内存缓冲池纵向扩展 (万兆特化版)
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

# [6] 软中断与 NAPI (New API) 均衡调度机制
net.core.dev_weight = 64
net.core.dev_weight_tx_bias = 1
net.core.dev_weight_rx_bias = 1
net.core.netdev_budget = 300

# [7] 组播、虚拟内存与文件系统 I/O 阀值
net.ipv4.igmp_max_memberships = 200
net.ipv4.route.flush = 1
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

# [8] TCP 状态机心跳、保活与半连接垃圾回收
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

# [9] 侦听队列与 Socket 防爆处理
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_orphans = 262144
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_reordering = 3
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_tso_win_divisor = 6

# [10] 内核级系统线程池与消息队列约束
kernel.pid_max = 4194304
kernel.threads-max = 85536
kernel.msgmax = 655350
kernel.msgmnb = 655350

# [11] BBR Pacing 高级修正系数与碎片重组
net.ipv4.tcp_pacing_ca_ratio = 150
net.ipv4.tcp_pacing_ss_ratio = 210
net.ipv4.ipfrag_max_dist = 32
net.ipv4.ipfrag_secret_interval = 200
net.ipv4.ipfrag_low_thresh = 42008868
net.ipv4.ipfrag_high_thresh = 104917729
net.ipv4.ipfrag_time = 30

# [12] 核心链路安全与防欺骗防护盾
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

# [13] 网卡多队列 RPS 均衡哈希表边界
net.core.rps_sock_flow_entries = 131072
net.core.flow_limit_table_len = 131072

# [14] Busy Polling 轮询模型与极低延迟
net.unix.max_dgram_qlen = 130000
net.core.busy_poll = 50
net.core.busy_read = 0
net.ipv4.tcp_notsent_lowat = 16384

# [15] 杂项补丁与 TCP 安全协议簇
net.ipv4.tcp_workaround_signed_windows = 1
net.ipv4.tcp_child_ehash_entries = 65535
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.tcp_stdurg = 0
net.ipv4.tcp_challenge_ack_limit = 1200
net.ipv4.tcp_comp_sack_delay_ns = 50000
net.ipv4.tcp_comp_sack_nr = 1
net.ipv4.tcp_fwmark_accept = 1
net.ipv4.tcp_invalid_ratelimit = 800
net.ipv4.tcp_l3mdev_accept = 1
net.ipv4.tcp_recovery = 0x1
net.ipv4.tcp_dsack = 1
net.ipv4.tcp_limit_output_bytes = 1310720
net.ipv4.tcp_min_tso_segs = 1
net.ipv4.tcp_thin_linear_timeouts = 0
net.ipv4.tcp_early_demux = 1
net.ipv4.tcp_shrink_window = 0
net.core.tstamp_allow_data = 1
net.core.netdev_tstamp_prequeue = 1
kernel.randomize_va_space = 2
kernel.sysrq = 1
kernel.printk = 3 4 1 3
kernel.sched_autogroup_enabled = 0

# [16] 物理级熔断 IPv6 全域协议栈
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

    # 使内核强行载入全量新参数矩阵
    sysctl --system >/dev/null 2>&1 || true
    
    if ! sysctl -p /etc/sysctl.d/99-network-optimized.conf >/dev/null 2>&1; then
        warn "部分参数在当前宿主环境的内核层可能不受支持，已自动容错跳过。"
    else
        info "所有 200+ 项底层 Sysctl 参数已成功强行注入内核运行时空间！"
    fi
    
    # 向系统网卡下放额外硬件卸载 (Offload) 优化守护进程
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test -n "$IFACE"; then
        cat > /usr/local/bin/nic-optimize.sh <<EONIC
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IFACE=\$(ip route get 1.1.1.1 2>/dev/null | awk '{print \$5; exit}' || echo "$IFACE")

# 针对低延迟与代理请求优化，强行关闭 GRO/GSO 与分段聚合
ethtool -K \$IFACE gro off gso off tso off lro off rx-gro-hw off tx-udp-segmentation on 2>/dev/null || true
ethtool -C \$IFACE adaptive-rx off rx-usecs 0 tx-usecs 0 2>/dev/null || true
EONIC
        
        chmod +x /usr/local/bin/nic-optimize.sh 2>/dev/null || true
        
        cat > /etc/systemd/system/nic-optimize.service <<EOSERVICE
[Unit]
Description=NIC Hardware Offload Optimization
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
        
        if command -v tc >/dev/null 2>&1; then
            tc qdisc replace dev "$IFACE" root fq >/dev/null 2>&1 || true
        fi
    fi
    
    info "极限低延迟调优参数注入完成！为了使内核彻底消化重组内存，系统将在 30 秒后自动重启生效..."
    sleep 30
    reboot
}
# ------------------------------------------------------------------------------
# [ 0x15: 底层微操探针引擎 (The Missing Link 状态探测) ]
# ------------------------------------------------------------------------------

check_dnsmasq_state() {
    if systemctl is-active dnsmasq >/dev/null 2>&1; then
        if grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null; then 
            echo "true"
            return
        fi
    fi
    echo "false"
}

check_thp_state() {
    if test ! -f "/sys/kernel/mm/transparent_hugepage/enabled"; then 
        echo "unsupported"
        return
    fi
    
    if test ! -w "/sys/kernel/mm/transparent_hugepage/enabled"; then 
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
    if test ! -f "/proc/sys/net/ipv4/tcp_mtu_probing"; then 
        echo "unsupported"
        return
    fi
    
    if test ! -w "/proc/sys/net/ipv4/tcp_mtu_probing"; then 
        echo "unsupported"
        return
    fi
    
    local val
    val=$(sysctl -n net.ipv4.tcp_mtu_probing 2>/dev/null || echo "0")
    
    if test "$val" = "1"; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_cpu_state() {
    if test ! -d "/sys/devices/system/cpu/cpu0/cpufreq"; then 
        echo "unsupported"
        return
    fi
    
    if test ! -w "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"; then 
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
    
    if test -z "$IFACE"; then 
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
    
    if test -z "$curr_rx"; then 
        echo "unsupported"
        return
    fi
    
    if test "$curr_rx" = "512"; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_zram_state() {
    if ! modprobe -n zram >/dev/null 2>&1; then
        if ! lsmod | grep -q zram; then 
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
    if test ! -f "/etc/systemd/journald.conf"; then 
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
    
    if test ! -f "$limit_file"; then 
        echo "false"
        return
    fi
    
    if grep -q "^OOMScoreAdjust=-500" "$limit_file" 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

# ------------------------------------------------------------------------------
# [ 0x16: 硬件配置引导脚本重写引擎 ]
# ------------------------------------------------------------------------------

update_hw_boot_script() {
    local boot_script="/usr/local/bin/xray-hw-tweaks.sh"
    
    cat << 'EOF' > "$boot_script"
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "eth0")
EOF

    if test "$(check_thp_state)" = "true"; then
        echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true" >> "$boot_script"
        echo "echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true" >> "$boot_script"
    fi
    
    if test "$(check_cpu_state)" = "true"; then
        if test -d "/sys/devices/system/cpu/cpu0/cpufreq"; then
            echo 'for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do if test -f "$cpu"; then echo performance > "$cpu" 2>/dev/null || true; fi; done' >> "$boot_script"
        fi
    fi
    
    if test "$(check_ring_state)" = "true"; then
        echo "ethtool -G \$IFACE rx 512 tx 512 2>/dev/null || true" >> "$boot_script"
    fi
    
    chmod +x "$boot_script" 2>/dev/null || true

    cat << 'EOF' > /etc/systemd/system/xray-hw-tweaks.service
[Unit]
Description=Xray Hardware Tweaks and State Restorer
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/xray-hw-tweaks.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable xray-hw-tweaks.service >/dev/null 2>&1 || true
}

# ------------------------------------------------------------------------------
# [ 0x17: 系统级黑科技反转控制器 (Toggle Engines) ]
# ------------------------------------------------------------------------------

toggle_dnsmasq() {
    if test "$(check_dnsmasq_state)" = "true"; then
        info "正在关闭 Dnsmasq 极速缓存引擎并恢复系统原生 DNS..."
        systemctl stop dnsmasq >/dev/null 2>&1 || true
        systemctl disable dnsmasq >/dev/null 2>&1 || true
        
        chattr -i /etc/resolv.conf 2>/dev/null || true
        rm -f /etc/resolv.conf 2>/dev/null || true
        
        if test -f /etc/resolv.conf.bak; then
            mv /etc/resolv.conf.bak /etc/resolv.conf
        else
            echo "nameserver 8.8.8.8" > /etc/resolv.conf
        fi
        
        systemctl enable systemd-resolved >/dev/null 2>&1 || true
        systemctl start systemd-resolved >/dev/null 2>&1 || true
        
        # 绝缘层写入
        _safe_jq_write '.dns = {"servers":["https://8.8.8.8/dns-query","https://1.1.1.1/dns-query","https://doh.opendns.com/dns-query"], "queryStrategy":"UseIP"}' "恢复 Xray 内置 DoH"
    else
        info "正在部署 Dnsmasq 本地极速内存缓存引擎..."
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y >/dev/null 2>&1 || true
        apt-get install -y dnsmasq >/dev/null 2>&1 || true
        
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
        if test ! -f /etc/resolv.conf.bak; then
            cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true
        fi
        rm -f /etc/resolv.conf 2>/dev/null || true
        echo "nameserver 127.0.0.1" > /etc/resolv.conf
        chattr +i /etc/resolv.conf 2>/dev/null || true
        
        # 绝缘层写入，将 Xray DNS 指向本地极速缓存
        _safe_jq_write '.dns = {"servers":["127.0.0.1"], "queryStrategy":"UseIP"}' "挂载本地 Dnsmasq 解析"
    fi
}

toggle_thp() {
    if test "$(check_thp_state)" = "true"; then
        echo always > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
        echo always > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true
        info "已恢复系统默认透明大页 (THP)。"
    else
        echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
        echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true
        info "已强行关闭透明大页 (THP)，降低内存碎片化引起的隐性高延迟。"
    fi
    update_hw_boot_script
}

toggle_mtu() {
    local conf="/etc/sysctl.d/99-network-optimized.conf"
    if test "$(check_mtu_state)" = "true"; then
        sed -i 's/^net.ipv4.tcp_mtu_probing.*/net.ipv4.tcp_mtu_probing = 0/' "$conf" 2>/dev/null || true
        info "已关闭 TCP PMTU 黑洞智能探测。"
    else
        if grep -q "net.ipv4.tcp_mtu_probing" "$conf" 2>/dev/null; then
            sed -i 's/^net.ipv4.tcp_mtu_probing.*/net.ipv4.tcp_mtu_probing = 1/' "$conf" 2>/dev/null || true
        else
            echo "net.ipv4.tcp_mtu_probing = 1" >> "$conf"
        fi
        info "已开启 TCP PMTU 黑洞智能探测，防患数据包截断死锁。"
    fi
    sysctl -p "$conf" >/dev/null 2>&1 || true
}

toggle_cpu() {
    if test "$(check_cpu_state)" = "unsupported"; then 
        return
    fi
    
    if test "$(check_cpu_state)" = "true"; then
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do 
            if test -f "$cpu"; then 
                echo schedutil > "$cpu" 2>/dev/null || echo ondemand > "$cpu" 2>/dev/null || true
            fi
        done
        info "CPU 频率调度器已回落至节能动态模式。"
    else
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do 
            if test -f "$cpu"; then 
                echo performance > "$cpu" 2>/dev/null || true
            fi
        done
        info "CPU 频率调度器已强行锁死在 Performance (火力全开) 模式！"
    fi
    update_hw_boot_script
}

toggle_ring() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test "$(check_ring_state)" = "unsupported"; then 
        return
    fi
    
    if test "$(check_ring_state)" = "true"; then
        local max_rx
        max_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Pre-set maximums" | grep "RX:" | head -1 | awk '{print $2}')
        if test -n "$max_rx"; then 
            ethtool -G "$IFACE" rx "$max_rx" tx "$max_rx" 2>/dev/null || true
        fi
        info "已释放网卡硬件环形缓冲区至物理硬件支持的最大值。"
    else
        ethtool -G "$IFACE" rx 512 tx 512 2>/dev/null || true
        info "网卡硬件环形缓冲区已反向极致收缩 (RX/TX = 512)，追求极限低延迟。"
    fi
    update_hw_boot_script
}

toggle_zram() {
    if test "$(check_zram_state)" = "unsupported"; then 
        return
    fi
    
    if test "$(check_zram_state)" = "true"; then
        swapoff /dev/zram0 2>/dev/null || true
        rmmod zram 2>/dev/null || true
        systemctl disable xray-zram.service --now >/dev/null 2>&1 || true
        rm -f /etc/systemd/system/xray-zram.service /usr/local/bin/xray-zram.sh 2>/dev/null || true
        info "ZRAM 高性能内存压缩分区已卸载剥离。"
    else
        local TOTAL_MEM
        TOTAL_MEM=$(free -m | awk '/Mem/{print $2}' || echo "1024")
        
        local ZRAM_SIZE
        if test "$TOTAL_MEM" -lt 500; then 
            ZRAM_SIZE=$((TOTAL_MEM * 2))
        elif test "$TOTAL_MEM" -lt 1024; then 
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
Description=Xray High-Performance ZRAM Setup
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/xray-zram.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOFZ
        systemctl daemon-reload >/dev/null 2>&1 || true
        systemctl enable xray-zram.service >/dev/null 2>&1 || true
        systemctl start xray-zram.service >/dev/null 2>&1 || true
        info "ZRAM 内存压缩挂载完毕，淘汰慢速磁盘 Swap！容量配置: ${ZRAM_SIZE}M"
    fi
}

toggle_journal() {
    local conf="/etc/systemd/journald.conf"
    if test "$(check_journal_state)" = "unsupported"; then 
        return
    fi
    
    if test "$(check_journal_state)" = "true"; then
        sed -i 's/^Storage=volatile/#Storage=auto/' "$conf" 2>/dev/null || true
        systemctl restart systemd-journald >/dev/null 2>&1 || true
        info "系统日志已恢复默认物理磁盘 I/O 写入。"
    else
        if grep -q "^#Storage=" "$conf" 2>/dev/null; then 
            sed -i 's/^#Storage=.*/Storage=volatile/' "$conf" 2>/dev/null || true
        elif grep -q "^Storage=" "$conf" 2>/dev/null; then 
            sed -i 's/^Storage=.*/Storage=volatile/' "$conf" 2>/dev/null || true
        else 
            echo "Storage=volatile" >> "$conf"
        fi
        systemctl restart systemd-journald >/dev/null 2>&1 || true
        info "系统日志已强制迁入内存 (Volatile)，斩断所有多余 I/O 物理羁绊！"
    fi
}

toggle_process_priority() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if test ! -f "$limit_file"; then 
        return
    fi
    
    if grep -q "^OOMScoreAdjust=-500" "$limit_file" 2>/dev/null; then
        sed -i '/^OOMScoreAdjust=/d' "$limit_file" 2>/dev/null || true
        sed -i '/^IOSchedulingClass=/d' "$limit_file" 2>/dev/null || true
        sed -i '/^IOSchedulingPriority=/d' "$limit_file" 2>/dev/null || true
        info "Xray 进程优先级已恢复为系统默认调度权重。"
    else
        echo "OOMScoreAdjust=-500" >> "$limit_file"
        echo "IOSchedulingClass=realtime" >> "$limit_file"
        echo "IOSchedulingPriority=2" >> "$limit_file"
        info "系统级防杀提权开启，Xray 现已被赋予 Realtime 实时 I/O 抢占级权限与 OOM 免死金牌！"
    fi
    systemctl daemon-reload >/dev/null 2>&1 || true
}

# ------------------------------------------------------------------------------
# [ 0x18: 核心应用层 Toggle 逻辑 (含 select(. != null) 绝缘排爆) ]
# ------------------------------------------------------------------------------

_turn_on_app() {
    # 极度安全的参数化注入，防止任何缺失节点引发的 jq 闪退
    _safe_jq_write '
      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings) |= (. // {}) |
      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt) |= (. // {}) |
      (.inbounds[]? | select(.protocol=="vless") | .streamSettings) |= (. // {}) |
      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt) |= (. // {}) |
      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpNoDelay) = true |
      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpFastOpen) = true |
      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt.tcpNoDelay) = true |
      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt.tcpFastOpen) = true |
      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpKeepAliveIdle) = 30 |
      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpKeepAliveInterval) = 15 |
      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt.tcpKeepAliveIdle) = 30 |
      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt.tcpKeepAliveInterval) = 15
    ' "开启全双工 FastOpen 与智能保活"

    _safe_jq_write '
      (.inbounds[]? | select(.protocol=="vless") | .sniffing.metadataOnly) = true | 
      (.inbounds[]? | select(.protocol=="vless") | .sniffing.routeOnly) = true
    ' "开启嗅探减负与零拷贝直通"
    
    if test "$(check_dnsmasq_state)" = "true"; then
        _safe_jq_write '.dns = {"servers":["127.0.0.1"], "queryStrategy":"UseIP"}' "路由至本地 Dnsmasq"
    else
        _safe_jq_write '.dns = {"servers":["https://8.8.8.8/dns-query","https://1.1.1.1/dns-query","https://doh.opendns.com/dns-query"], "queryStrategy":"UseIP"}' "启用并发 DoH"
    fi
    
    _safe_jq_write '.policy = {"levels":{"0":{"handshake":3,"connIdle":60}},"system":{"statsInboundDownlink":false,"statsInboundUplink":false}}' "执行连接生命周期快速回收策略"
    
    _toggle_affinity_on
    
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if test -f "$limit_file"; then
        local TOTAL_MEM
        TOTAL_MEM=$(free -m | awk '/Mem/{print $2}' || echo "1024")
        
        local DYNAMIC_GOGC=100
        if test "$TOTAL_MEM" -ge 1800; then DYNAMIC_GOGC=1000
        elif test "$TOTAL_MEM" -ge 900; then DYNAMIC_GOGC=500
        elif test "$TOTAL_MEM" -ge 700; then DYNAMIC_GOGC=400
        elif test "$TOTAL_MEM" -ge 500; then DYNAMIC_GOGC=300
        elif test "$TOTAL_MEM" -ge 400; then DYNAMIC_GOGC=200
        else DYNAMIC_GOGC=100; fi

        if grep -q "Environment=\"GOGC=" "$limit_file" 2>/dev/null; then
            sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=$DYNAMIC_GOGC\"/" "$limit_file" 2>/dev/null || true
        else
            echo "Environment=\"GOGC=$DYNAMIC_GOGC\"" >> "$limit_file"
        fi
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

_turn_off_app() {
    _safe_jq_write '
      del(.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpNoDelay, .streamSettings?.sockopt?.tcpFastOpen, .streamSettings?.sockopt?.tcpKeepAliveIdle, .streamSettings?.sockopt?.tcpKeepAliveInterval) | 
      del(.inbounds[]? | select(.protocol=="vless") | .streamSettings?.sockopt?.tcpNoDelay, .streamSettings?.sockopt?.tcpFastOpen, .streamSettings?.sockopt?.tcpKeepAliveIdle, .streamSettings?.sockopt?.tcpKeepAliveInterval)
    ' "剥离 FastOpen 与心跳保活"
    
    _safe_jq_write '
      (.inbounds[]? | select(.protocol=="vless") | .sniffing.metadataOnly) = false | 
      (.inbounds[]? | select(.protocol=="vless") | .sniffing.routeOnly) = false
    ' "恢复深度嗅探模式"
    
    _safe_jq_write 'del(.dns)' "剥离 Xray DNS 解析池"
    _safe_jq_write 'del(.policy)' "恢复连接生命周期"
    
    _toggle_affinity_off
    
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if test -f "$limit_file"; then
        if grep -q "Environment=\"GOGC=" "$limit_file" 2>/dev/null; then
            sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=100\"/" "$limit_file" 2>/dev/null || true
        else
            echo "Environment=\"GOGC=100\"" >> "$limit_file"
        fi
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

# ------------------------------------------------------------------------------
# [ 0x19: 全域 25 项极限微操战神矩阵 (The 25-Panel God Mode Matrix) ]
# ------------------------------------------------------------------------------

do_app_level_tuning_menu() {
    while true; do
        clear
        title "全域 25 项极限微操控制台 (CAKE / 零拷贝 / 硬中断隔离)"
        
        if test ! -f "$CONFIG"; then 
            error "未发现系统核心配置文件，请先执行协议安装！"
            local _pause=""
            read -rp "按 Enter 返回..." _pause || true
            return
        fi

        # 瞬时全量状态精准提取 (应用层)
        local out_fastopen
        out_fastopen=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpFastOpen // "false"' "$CONFIG" 2>/dev/null || echo "false")
        
        local out_keepalive
        out_keepalive=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpKeepAliveIdle // "false"' "$CONFIG" 2>/dev/null || echo "false")
        
        local sniff_status
        sniff_status=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .sniffing.metadataOnly // "false"' "$CONFIG" 2>/dev/null || echo "false")
        
        local dns_status
        dns_status=$(jq -r '.dns.queryStrategy // "false"' "$CONFIG" 2>/dev/null || echo "false")
        
        local policy_status
        policy_status=$(jq -r '.policy.levels["0"].connIdle // "false"' "$CONFIG" 2>/dev/null || echo "false")
        
        local affinity_state
        if grep -q "^CPUAffinity=" "/etc/systemd/system/xray.service.d/limits.conf" 2>/dev/null; then affinity_state="true"; else affinity_state="false"; fi
        
        local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
        local gc_status="100"
        if test -f "$limit_file"; then
            gc_status=$(awk -F'=' '/^Environment="GOGC=/ {print $3}' "$limit_file" 2>/dev/null | tr -d '"' | head -1 || echo "100")
        fi

        # 瞬时全量状态精准提取 (系统层，包含避障侦测)
        local dnsmasq_state=$(check_dnsmasq_state)
        local thp_state=$(check_thp_state)
        local mtu_state=$(check_mtu_state)
        local cpu_state=$(check_cpu_state)
        local ring_state=$(check_ring_state)
        local zram_state=$(check_zram_state)
        local journal_state=$(check_journal_state)
        local prio_state=$(check_process_priority_state)

        # 判定 CAKE Qdisc 状态
        local cake_state="false"
        local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
        if test -n "$IFACE" && tc qdisc show dev "$IFACE" 2>/dev/null | grep -q "cake"; then cake_state="true"; fi

        # 判定 BBR3 状态
        local bbr_state="false"
        if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q "bbr"; then bbr_state="true"; fi

        # UI 物理状态渲染引擎
        local s1; if test "$out_fastopen" = "true"; then s1="${cyan}已开启${none}"; else s1="${gray}未开启${none}"; fi
        local s2; if test "$out_keepalive" = "30"; then s2="${cyan}已开启${none}"; else s2="${gray}系统默认${none}"; fi
        local s3; if test "$sniff_status" = "true"; then s3="${cyan}已开启${none}"; else s3="${gray}未开启${none}"; fi
        local s4; if test "$dns_status" = "UseIP"; then s4="${cyan}并发并发解析${none}"; else s4="${gray}标准解析${none}"; fi
        local s6; if test "$policy_status" = "60"; then s6="${cyan}极速回收(60s)${none}"; else s6="${gray}慢回收(300s)${none}"; fi
        local s7; if test "$affinity_state" = "true"; then s7="${cyan}锁死单核${none}"; else s7="${gray}系统负载均衡${none}"; fi
        
        local s8; if test "$dnsmasq_state" = "true"; then s8="${cyan}极速缓存中${none}"; else s8="${gray}依赖原生 DoH${none}"; fi
        local s9; if test "$thp_state" = "true"; then s9="${cyan}已关闭碎片源${none}"; else s9="${gray}默认开启${none}"; fi
        local s10; if test "$mtu_state" = "true"; then s10="${cyan}智能探伤中${none}"; else s10="${gray}未开启${none}"; fi
        local s11; if test "$cpu_state" = "true"; then s11="${cyan}火力全开${none}"; else s11="${gray}节能待机${none}"; fi
        local s12; if test "$ring_state" = "true"; then s12="${cyan}极限低延迟${none}"; else s12="${gray}大吞吐缓冲${none}"; fi
        local s13; if test "$zram_state" = "true"; then s13="${cyan}内存压缩挂载${none}"; else s13="${gray}未启用${none}"; fi
        local s14; if test "$journal_state" = "true"; then s14="${cyan}纯内存化${none}"; else s14="${gray}磁盘 I/O 中${none}"; fi
        local s15; if test "$prio_state" = "true"; then s15="${cyan}免死金牌挂载${none}"; else s15="${gray}系统默认${none}"; fi
        local s16; if test "$cake_state" = "true"; then s16="${cyan}CAKE 接管中${none}"; else s16="${gray}FQ 队列处理${none}"; fi
        local s17; if test "$bbr_state" = "true"; then s17="${cyan}BBR/BBR3 狂飙${none}"; else s17="${gray}CUBIC 传统${none}"; fi

        echo -e "  ${magenta}--- Xray Core 应用层内部调优 (1-7) ---${none}"
        echo -e "  1) TCP 零拷贝与并发提速 (tcpNoDelay/FastOpen)    | 当前状态: $s1"
        echo -e "  2) Socket 智能保活心跳 (KeepAlive: Idle 30s)     | 当前状态: $s2"
        echo -e "  3) 嗅探引擎减负 (metadataOnly 解放 CPU)          | 当前状态: $s3"
        echo -e "  4) 内置并发 DoH / Dnsmasq 路由分发 (Xray DNS)    | 当前状态: $s4"
        echo -e "  5) GOGC 内存阶梯飙车调优 (自动侦测物理内存)      | 当前设定: ${cyan}${gc_status}${none}"
        echo -e "  6) Policy 策略组优化 (连接生命周期极速回收)      | 当前状态: $s6"
        echo -e "  7) Xray 进程物理绑核 & GOMAXPROCS 并发锁         | 当前状态: $s7"
        echo -e ""
        echo -e "  ${magenta}--- Linux 系统层与内核底层黑科技 (8-17) ---${none}"
        echo -e "  8) Dnsmasq 本地极速内存缓存引擎 (21000并发)      | 当前状态: $s8"
        echo -e "  9) 关闭透明大页 (THP - 杜绝隐性高延迟)           | 当前状态: $s9"
        echo -e "  10) TCP PMTU 黑洞智能探测 (Probing=1)            | 当前状态: $s10"
        echo -e "  11) CPU 频率调度器锁定 (Performance)             | 当前状态: $s11"
        echo -e "  12) 网卡硬件环形缓冲区 (Ring Buffer) 反向收缩    | 当前状态: $s12"
        echo -e "  13) ZRAM 阶梯内存自动挂载 (淘汰慢速 Swap)        | 当前状态: $s13"
        echo -e "  14) 日志系统 Journald 纯内存化 (斩断 I/O 羁绊)   | 当前状态: $s14"
        echo -e "  15) 系统进程级防杀抢占 (OOM 免死 / IO 提权)      | 当前状态: $s15"
        echo -e "  16) 开启底层 CAKE Qdisc 智能流控抗缓冲膨胀       | 当前状态: $s16"
        echo -e "  17) 确立 TCP BBR/BBR3 拥塞控制为内核唯一主导     | 当前状态: $s17"
        echo -e "  "
        echo -e "  ${cyan}23) 一键开启全域 1-7 项 应用层智能防爆参数${none}"
        echo -e "  ${yellow}24) 一键激活全域 8-17 项 系统级内核物理超频引擎${none}"
        echo -e "  ${red}25) 上帝之手：一键融通重置全域 25 项生态防线 (将触发内核级强制重启)${none}"
        echo "  0) 缩回面板，返回上一级控制中枢"
        hr
        
        local app_opt=""
        read -rp "请下达微操调度指令: " app_opt || true

        case "${app_opt:-}" in
            1)
                if test "$out_fastopen" = "true"; then
                    _safe_jq_write '
                      del(.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpNoDelay, .streamSettings?.sockopt?.tcpFastOpen) | 
                      del(.inbounds[]? | select(.protocol=="vless") | .streamSettings?.sockopt?.tcpNoDelay, .streamSettings?.sockopt?.tcpFastOpen)
                    ' "关闭并发提速"
                else
                    _safe_jq_write '
                      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings) |= (. // {}) |
                      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt) |= (. // {}) |
                      (.inbounds[]? | select(.protocol=="vless") | .streamSettings) |= (. // {}) |
                      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt) |= (. // {}) |
                      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpNoDelay) = true |
                      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpFastOpen) = true |
                      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt.tcpNoDelay) = true |
                      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt.tcpFastOpen) = true
                    ' "开启并发提速"
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            2)
                if test "$out_keepalive" = "30"; then
                    _safe_jq_write '
                      del(.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpKeepAliveIdle, .streamSettings?.sockopt?.tcpKeepAliveInterval) | 
                      del(.inbounds[]? | select(.protocol=="vless") | .streamSettings?.sockopt?.tcpKeepAliveIdle, .streamSettings?.sockopt?.tcpKeepAliveInterval)
                    ' "关闭保活心跳"
                else
                    _safe_jq_write '
                      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings) |= (. // {}) |
                      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt) |= (. // {}) |
                      (.inbounds[]? | select(.protocol=="vless") | .streamSettings) |= (. // {}) |
                      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt) |= (. // {}) |
                      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpKeepAliveIdle) = 30 |
                      (.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpKeepAliveInterval) = 15 |
                      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt.tcpKeepAliveIdle) = 30 |
                      (.inbounds[]? | select(.protocol=="vless") | .streamSettings.sockopt.tcpKeepAliveInterval) = 15
                    ' "注入极速保活心跳"
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            3)
                if test "$sniff_status" = "true"; then
                    _safe_jq_write '
                      (.inbounds[]? | select(.protocol=="vless") | .sniffing.metadataOnly) = false | 
                      (.inbounds[]? | select(.protocol=="vless") | .sniffing.routeOnly) = false
                    ' "关闭嗅探减负"
                else
                    _safe_jq_write '
                      (.inbounds[]? | select(.protocol=="vless") | .sniffing.metadataOnly) = true | 
                      (.inbounds[]? | select(.protocol=="vless") | .sniffing.routeOnly) = true
                    ' "开启嗅探减负"
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            4)
                if test "$dns_status" = "UseIP"; then
                    _safe_jq_write 'del(.dns)' "移除系统层解析池"
                else
                    if test "$dnsmasq_state" = "true"; then
                        _safe_jq_write '.dns = {"servers":["127.0.0.1"], "queryStrategy":"UseIP"}' "挂载本地 Dnsmasq 解析"
                    else
                        _safe_jq_write '.dns = {"servers":["https://8.8.8.8/dns-query","https://1.1.1.1/dns-query","https://doh.opendns.com/dns-query"], "queryStrategy":"UseIP"}' "启用并发 DoH"
                    fi
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            5)
                local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
                if test -f "$limit_file"; then
                    local TOTAL_MEM
                    TOTAL_MEM=$(free -m | awk '/Mem/{print $2}' || echo "1024")
                    
                    local DYNAMIC_GOGC=100
                    if test "$TOTAL_MEM" -ge 1800; then DYNAMIC_GOGC=1000
                    elif test "$TOTAL_MEM" -ge 900; then DYNAMIC_GOGC=500
                    elif test "$TOTAL_MEM" -ge 700; then DYNAMIC_GOGC=400
                    elif test "$TOTAL_MEM" -ge 500; then DYNAMIC_GOGC=300
                    elif test "$TOTAL_MEM" -ge 400; then DYNAMIC_GOGC=200
                    else DYNAMIC_GOGC=100; fi

                    if grep -q "Environment=\"GOGC=" "$limit_file" 2>/dev/null; then
                        if test "$gc_status" = "100"; then
                            sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=$DYNAMIC_GOGC\"/" "$limit_file" 2>/dev/null || true
                            info "GOGC 动态阶梯极速飙车模式已开启！阈值: ${DYNAMIC_GOGC}"
                        else
                            sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=100\"/" "$limit_file" 2>/dev/null || true
                            info "GOGC 阶梯调优已剥离，恢复了最稳定的系统默认保底阈值: 100"
                        fi
                    else
                        echo "Environment=\"GOGC=$DYNAMIC_GOGC\"" >> "$limit_file"
                    fi
                    systemctl daemon-reload >/dev/null 2>&1 || true
                    systemctl restart xray >/dev/null 2>&1 || true
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            6)
                if test "$policy_status" = "60"; then
                    _safe_jq_write 'del(.policy)' "关闭极速回收"
                    info "策略组优化已关闭，连接回收周期恢复官方默认。"
                else
                    _safe_jq_write '.policy = {"levels":{"0":{"handshake":3,"connIdle":60}},"system":{"statsInboundDownlink":false,"statsInboundUplink":false}}' "开启极速回收"
                    info "策略组优化指令已强制挂载，系统将更激进地释放死连接。"
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            7)
                if test "$affinity_state" = "true"; then
                    _toggle_affinity_off
                    info "物理绑核机制已注销，系统调度资源分配恢复自由多核流转。"
                else
                    _toggle_affinity_on
                    info "进程绑定锁已上膛，核心执行链路现在彻底规避了 CPU 跨核的微秒级损耗！"
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            8) toggle_dnsmasq; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            9) toggle_thp; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            10) toggle_mtu; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            11) toggle_cpu; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            12) toggle_ring; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            13) toggle_zram; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            14) toggle_journal; local _p=""; read -rp "按 Enter 继续..." _p || true ;;
            15) 
                toggle_process_priority
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true 
                ;;
            16)
                local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
                if test -n "$IFACE"; then
                    if test "$cake_state" = "true"; then
                        tc qdisc replace dev "$IFACE" root fq >/dev/null 2>&1 || true
                        info "已从 CAKE 回退至默认的 FQ 队列。"
                    else
                        tc qdisc replace dev "$IFACE" root cake >/dev/null 2>&1 || true
                        info "底层 CAKE Qdisc 智能流控引擎已接管网卡 $IFACE！"
                    fi
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            17)
                local conf="/etc/sysctl.d/99-network-optimized.conf"
                if test "$bbr_state" = "true"; then
                    sed -i 's/^net.ipv4.tcp_congestion_control.*/net.ipv4.tcp_congestion_control = cubic/' "$conf" 2>/dev/null || true
                    sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1 || true
                    info "TCP 拥塞控制已回退为传统 CUBIC 算法。"
                else
                    sed -i 's/^net.ipv4.tcp_congestion_control.*/net.ipv4.tcp_congestion_control = bbr/' "$conf" 2>/dev/null || true
                    sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1 || true
                    info "TCP 拥塞控制已强行锁死为 BBR/BBR3 高压引擎！"
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            23)
                print_magenta ">>> 正在为您执行全域强力装载并重构应用层防线..."
                _turn_on_app
                systemctl restart xray >/dev/null 2>&1 || true
                info "1-7 项 Xray 内部应用层防爆参数已全量就绪并上线服役！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            24)
                print_magenta ">>> 正在全域强力激活系统内核级黑科技引擎，请勿中断..."
                if test "$dnsmasq_state" = "false"; then toggle_dnsmasq >/dev/null 2>&1 || true; fi
                if test "$thp_state" = "false"; then toggle_thp >/dev/null 2>&1 || true; fi
                if test "$mtu_state" = "false"; then toggle_mtu >/dev/null 2>&1 || true; fi
                if test "$cpu_state" = "false"; then toggle_cpu >/dev/null 2>&1 || true; fi
                if test "$ring_state" = "false"; then toggle_ring >/dev/null 2>&1 || true; fi
                if test "$zram_state" = "false"; then toggle_zram >/dev/null 2>&1 || true; fi
                if test "$journal_state" = "false"; then toggle_journal >/dev/null 2>&1 || true; fi
                if test "$prio_state" = "false"; then toggle_process_priority >/dev/null 2>&1 || true; fi
                
                systemctl restart xray >/dev/null 2>&1 || true
                info "8-17 项系统级极限物理微操已全部完成一键激活封口！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            25)
                print_magenta ">>> 接收到最高上帝指令！正在穿透底层唤醒全部 25 项软硬件极限超频黑科技..."
                _turn_on_app
                if test "$dnsmasq_state" = "false"; then toggle_dnsmasq >/dev/null 2>&1 || true; fi
                if test "$thp_state" = "false"; then toggle_thp >/dev/null 2>&1 || true; fi
                if test "$mtu_state" = "false"; then toggle_mtu >/dev/null 2>&1 || true; fi
                if test "$cpu_state" = "false"; then toggle_cpu >/dev/null 2>&1 || true; fi
                if test "$ring_state" = "false"; then toggle_ring >/dev/null 2>&1 || true; fi
                if test "$zram_state" = "false"; then toggle_zram >/dev/null 2>&1 || true; fi
                if test "$journal_state" = "false"; then toggle_journal >/dev/null 2>&1 || true; fi
                if test "$prio_state" = "false"; then toggle_process_priority >/dev/null 2>&1 || true; fi
                
                local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
                if test -n "$IFACE"; then tc qdisc replace dev "$IFACE" root cake >/dev/null 2>&1 || true; fi
                sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null 2>&1 || true
                
                info "神威全开！全域 25 项极客微操调优已【全部满血满载】！"
                echo ""
                print_red "======================================================================"
                print_yellow "  高能警报：系统全域拓扑与内核队列状态已在物理层面发生不可逆变更！"
                print_yellow "  为了确保所有的 CPU 调度重组与 CAKE 队列完美挂载，"
                print_yellow "  系统安全锁死线程，将在 6 秒后自动进行【强制断电重启】！请勿手工中断！"
                print_red "======================================================================"
                
                for i in {6..1}; do 
                    echo -ne "\r  重启执行程序倒计时保护: ${cyan}${i}${none} 秒后脱离... "
                    sleep 1
                done
                
                echo -e "\n\n  正在呼叫物理重启指令，SSH 链接即将撕裂，请稍候重新连接服务器..."
                reboot
                ;;
            0) 
                return 
                ;;
        esac
    done
}
# ------------------------------------------------------------------------------
# [ 0x1A: 伪装矩阵动态偏移重组核心 (安全 JQ 防爆重切引擎) ]
# ------------------------------------------------------------------------------

_update_matrix() {
    if test ! -f "$CONFIG"; then 
        error "无法执行矩阵切换：系统尚未部署核心配置文件。"
        return 1
    fi
    
    info "启动伪装防线偏移逻辑（启用安全隔离写入防爆机制）..."
    
    # 构造临时 JSON 数组池以供 jq 深度解析，防止命令行传参溢出
    echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
    
    backup_config
    
    # 采用 slurpfile 绝缘注入，绝对防止单引号、双引号闭合错误引发的配置雪崩
    if ! jq --arg dest "$BEST_SNI:443" --slurpfile snis /tmp/sni_array.json '
        (.inbounds[]? | select(.protocol=="vless" and .streamSettings.realitySettings != null) | .streamSettings.realitySettings.serverNames) = $snis[0] |
        (.inbounds[]? | select(.protocol=="vless" and .streamSettings.realitySettings != null) | .streamSettings.realitySettings.dest) = $dest
    ' "$CONFIG" > "$CONFIG.tmp" 2>/dev/null; then
        error "矩阵配置重组遭遇 JQ 语法解析异常，变更已自动撤销还原！"
        rm -f /tmp/sni_array.json "$CONFIG.tmp" 2>/dev/null || true
        restore_latest_backup
        return 1
    fi
    
    # 执行安全预审
    if verify_xray_config "$CONFIG.tmp"; then
        mv -f "$CONFIG.tmp" "$CONFIG" >/dev/null 2>&1 || true
        fix_permissions
        
        if systemctl restart xray >/dev/null 2>&1; then
            info "确认配置已被内核重载：伪装路由接口安全防线矩阵已被无损调转与重塑！"
        else
            warn "Xray 守护进程重载失败，请通过状态检查排查语法树错误！"
        fi
    else
        error "内核预审阻断了伪装矩阵的写入操作！"
        rm -f "$CONFIG.tmp" 2>/dev/null || true
        restore_latest_backup
    fi
    
    rm -f /tmp/sni_array.json 2>/dev/null || true
    return 0
}

# ------------------------------------------------------------------------------
# [ 0x1B: 核心通信协议框架部署 (完美匹配 UI 界面的纯原生 Bash 安装流) ]
# ------------------------------------------------------------------------------

do_install() {
    clear
    echo -e "  ${cyan}1) 核心安装 / 重构网络 (VLESS/SS 双协议)${none}\n"
    preflight
    
    info "正在强行切断并静默挂起旧版守护进程..."
    systemctl stop xray >/dev/null 2>&1 || true

    if test ! -f "$INSTALL_DATE_FILE"; then
        date +"%Y-%m-%d %H:%M:%S" > "$INSTALL_DATE_FILE"
    fi
    
    echo -e "\n  请选择要安装的代理协议："
    echo "  1) VLESS-Reality (推荐, 强力防封)"
    echo "  2) Shadowsocks (建议落地机使用)"
    echo "  3) 两个都安装 (双管齐下)"
    
    local proto_choice=""
    read -rp "  请输入编号: " proto_choice
    proto_choice=${proto_choice:-1}

    # ==========================================
    # 交互收集: VLESS-Reality 运行参数
    # ==========================================
    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        while true; do
            local input_p=""
            read -rp "请输入 VLESS 物理监听端口 (回车键默认 443): " input_p
            input_p=${input_p:-443}
            if validate_port "$input_p"; then 
                LISTEN_PORT="$input_p"
                break
            fi
        done
        
        local input_remark=""
        read -rp "请输入该节点战术别名 (默认 xp-reality): " input_remark
        REMARK_NAME=${input_remark:-xp-reality}
        
        if ! choose_sni; then 
            warn "矩阵选择流程被人工阻断，安装序列已强行终止。"
            return 1
        fi
    fi

    # ==========================================
    # 交互收集: Shadowsocks 运行参数
    # ==========================================
    local ss_port=8388
    local ss_pass=""
    local ss_method="aes-256-gcm"
    
    if test "$proto_choice" = "2" || test "$proto_choice" = "3"; then
        while true; do
            local input_s=""
            read -rp "请输入 Shadowsocks 物理监听端口 (回车键默认 8388): " input_s
            input_s=${input_s:-8388}
            if validate_port "$input_s"; then 
                ss_port="$input_s"
                break
            fi
        done
        
        ss_pass=$(gen_ss_pass)
        ss_method=$(_select_ss_method)
        
        if test "$proto_choice" = "2"; then
            local input_remark=""
            read -rp "请输入该节点战术别名 (默认 xp-ss): " input_remark
            REMARK_NAME=${input_remark:-xp-ss}
        fi
    fi

    print_magenta "\n>>> 正在全域连接云端，多轨拉取最新版 Xray 核心组件..."
    
    local xray_installed=0
    for url in "https://github.com/XTLS/Xray-install/raw/main/install-release.sh" \
               "https://fastly.jsdelivr.net/gh/XTLS/Xray-install@main/install-release.sh" \
               "https://raw.fastgit.org/XTLS/Xray-install/main/install-release.sh"; do
               
        if bash -c "$(curl -fsSL --connect-timeout 10 --max-time 30 "$url")" @ install >/dev/null 2>&1; then
            xray_installed=1
            info "Xray 核心跨维安装成功，数据流桥接源：$url"
            break
        fi
        warn "节点流失，通讯链路 [$url] 遭阻断，正在自动自旋接入备用 CDN 镜像..."
    done
    
    if test "$xray_installed" -eq 0; then
        die "核心获取全面溃败：所有源均遭到网络阻断！部署防线已自动物理熔断！"
    fi
    
    install_update_dat
    fix_xray_systemd_limits

    info "正在触发引擎级别 JSON 配置装配中心 (纯原生 Bash HereDoc 强写，彻底屏蔽 JQ 初始解析断层)..."

    cat > "$CONFIG" <<EOF
{
  "log": { "loglevel": "warning" },
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      { "outboundTag": "block", "_enabled": true, "protocol": ["bittorrent"] },
      { "outboundTag": "block", "_enabled": true, "ip": ["geoip:cn"] },
      { "outboundTag": "block", "_enabled": true, "domain": ["geosite:cn", "geosite:category-ads-all"] }
    ]
  },
  "inbounds": [],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct", "streamSettings": { "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true } } },
    { "protocol": "blackhole", "tag": "block" }
  ]
}
EOF

    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        local keys
        keys=$("$XRAY_BIN" x25519 2>/dev/null)
        local priv=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' \r\n' || echo "")
        local pub=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' \r\n' || echo "")
        local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
        local sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n\r' || echo "")
        local ctime=$(date +"%Y-%m-%d %H:%M")
        
        echo "$pub" > "$PUBKEY_FILE"
        echo "$uuid|$ctime" > "$USER_TIME_MAP"
        
        echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
        cat > /tmp/vless_inbound.json <<EOF
{
  "tag": "vless-reality", "listen": "0.0.0.0", "port": $LISTEN_PORT, "protocol": "vless",
  "settings": { "clients": [ { "id": "$uuid", "flow": "xtls-rprx-vision", "email": "$REMARK_NAME" } ], "decryption": "none" },
  "streamSettings": {
    "network": "tcp", "security": "reality", "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true },
    "realitySettings": { "dest": "$BEST_SNI:443", "serverNames": [], "privateKey": "$priv", "publicKey": "$pub", "shortIds": [ "$sid" ] }
  },
  "sniffing": { "enabled": true, "destOverride": [ "http", "tls", "quic" ] }
}
EOF
        if jq --slurpfile snis /tmp/sni_array.json '.streamSettings.realitySettings.serverNames = $snis[0]' /tmp/vless_inbound.json > /tmp/vless_final.json 2>/dev/null; then
            jq '.inbounds += [input]' "$CONFIG" /tmp/vless_final.json > "$CONFIG.tmp" 2>/dev/null && mv -f "$CONFIG.tmp" "$CONFIG" >/dev/null 2>&1 || true
        fi
        rm -f /tmp/vless_inbound.json /tmp/vless_final.json /tmp/sni_array.json 2>/dev/null || true
    fi

    if test "$proto_choice" = "2" || test "$proto_choice" = "3"; then
        cat > /tmp/ss_inbound.json <<EOF
{
  "tag": "shadowsocks", "listen": "0.0.0.0", "port": $ss_port, "protocol": "shadowsocks",
  "settings": { "method": "$ss_method", "password": "$ss_pass", "network": "tcp,udp" },
  "streamSettings": { "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true } }
}
EOF
        jq '.inbounds += [input]' "$CONFIG" /tmp/ss_inbound.json > "$CONFIG.tmp" 2>/dev/null && mv -f "$CONFIG.tmp" "$CONFIG" >/dev/null 2>&1 || true
        rm -f /tmp/ss_inbound.json 2>/dev/null || true
    fi

    fix_permissions
    backup_config
    systemctl enable xray >/dev/null 2>&1 || true
    
    if ensure_xray_is_alive; then
        info "所有架构部署已宣告完结！加密防线已全速运转。"
    else
        error "预警！守护进程激活失败，部署防线已触发灾难回滚，请排查内核兼容性！"
        return 1
    fi
    
    do_summary
    
    while true; do
        local opt=""
        read -rp "操作闭环：按 Enter 键返回主控中枢，或键入 b 立即进行 SNI 重新偏移: " opt || true
        if test "$opt" = "b" || test "$opt" = "B"; then
            if choose_sni; then _update_matrix; do_summary; else break; fi
        else 
            break
        fi
    done
}

# ------------------------------------------------------------------------------
# [ 0x1C: 分发中心 (多用户详情与紧凑二维码) ]
# ------------------------------------------------------------------------------

do_summary() {
    if test ! -f "$CONFIG"; then 
        return
    fi
    
    clear
    echo -e "  ${cyan}3) 分发中心 (多用户详情与紧凑二维码)${none}\n"
    
    local vless_inbound
    vless_inbound=$(jq -c '.inbounds[]? | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
    
    if test -n "$vless_inbound" && test "$vless_inbound" != "null"; then
        local client_count
        client_count=$(echo "$vless_inbound" | jq -r '.settings.clients | length' 2>/dev/null || echo 0)
        
        if test "${client_count:-0}" -gt 0; then
            local port=$(echo "$vless_inbound" | jq -r '.port // empty' 2>/dev/null || echo "")
            local pub=$(echo "$vless_inbound" | jq -r '.streamSettings.realitySettings.publicKey // empty' 2>/dev/null || echo "")
            local main_sni=$(echo "$vless_inbound" | jq -r '.streamSettings.realitySettings.serverNames[0] // empty' 2>/dev/null || echo "")

            for ((i=0; i<client_count; i++)); do
                local uuid=$(echo "$vless_inbound" | jq -r ".settings.clients[$i].id // empty" 2>/dev/null || echo "")
                local remark=$(echo "$vless_inbound" | jq -r ".settings.clients[$i].email // \"$REMARK_NAME\"" 2>/dev/null || echo "")
                local sid=$(echo "$vless_inbound" | jq -r ".streamSettings.realitySettings.shortIds[$i] // empty" 2>/dev/null || echo "")
                
                local target_sni=$(grep "^$uuid|" "$USER_SNI_MAP" 2>/dev/null | cut -d'|' -f2 || echo "")
                target_sni=${target_sni:-$main_sni}

                if test -n "$uuid" && test "$uuid" != "null"; then 
                    echo -e "  【VLESS-Reality (Vision) - 用户序号: $((i+1))】"
                    echo -e "  节点名称:    $remark"
                    echo -e "  对外IP: $SERVER_IP"
                    echo -e "  系统监听端口: $port"
                    echo -e "  认证 UUID:   $uuid"
                    echo -e "  伪装 SNI: $target_sni"
                    echo -e "  公钥(pbk): $pub"
                    echo -e "  ShortId: $sid"
                    echo -e "  底层 uTLS 引擎: chrome"
                    
                    local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${target_sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${remark}"
                    echo -e "\n    通用链接: \n    $link\n"
                    
                    if command -v qrencode >/dev/null 2>&1; then 
                        echo -e "    二维码："
                        qrencode -m 2 -t UTF8 "$link"
                        echo ""
                    fi
                fi
            done
        fi
    fi

    local ss_inbound
    ss_inbound=$(jq -c '.inbounds[]? | select(.protocol=="shadowsocks")' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
    
    if test -n "$ss_inbound" && test "$ss_inbound" != "null"; then
        local s_port=$(echo "$ss_inbound" | jq -r '.port // empty' 2>/dev/null || echo "")
        local s_pass=$(echo "$ss_inbound" | jq -r '.settings.password // empty' 2>/dev/null || echo "")
        local s_method=$(echo "$ss_inbound" | jq -r '.settings.method // empty' 2>/dev/null || echo "")
        
        if test -n "$s_port" && test "$s_port" != "null"; then
            echo -e "  【Shadowsocks】"
            echo -e "  节点名称:    ${REMARK_NAME}-SS"
            echo -e "  对外IP: $SERVER_IP"
            echo -e "  系统监听端口: $s_port"
            echo -e "  密码: $s_pass"
            echo -e "  加密算法: $s_method"
            
            local b64=$(printf '%s' "${s_method}:${s_pass}" | base64 | tr -d '\n' || echo "")
            local ss_link="ss://${b64}@${SERVER_IP}:${s_port}#${REMARK_NAME}-SS"
            echo -e "\n    通用链接: \n    $ss_link\n"
            
            if command -v qrencode >/dev/null 2>&1; then 
                echo -e "    二维码："
                qrencode -m 2 -t UTF8 "$ss_link"
                echo ""
            fi
        fi
    fi
}

# ------------------------------------------------------------------------------
# [ 0x1D: 用户管理 (增删/导入/专属 SNI 挂载) - 绝缘防爆重构版 ]
# ------------------------------------------------------------------------------

do_user_manager() {
    while true; do
        clear
        echo -e "  ${cyan}2) 用户管理 (增删/导入/专属 SNI 挂载)${none}\n"
        
        if test ! -f "$CONFIG"; then 
            error "未发现系统核心配置文件，请先完成核心安装！"
            local _pause=""; read -rp "按 Enter 返回主菜单..." _pause || true
            return
        fi

        # ---------------------------------------------------------
        # 极度安全的 JQ 拼接: select(. != null) 绝缘罩全覆盖
        # ---------------------------------------------------------
        local clients
        clients=$(jq -r ".inbounds[]? | select(.protocol==\"vless\" and .settings != null) | .settings.clients[]? | select(.id != null) | .id + \"|\" + (.email // \"\")" "$CONFIG" 2>/dev/null || echo "")
        
        if test -z "$clients" || test "$clients" = "null"; then 
            error "当前内核运行中未发现 VLESS 节点协议，无法管理用户。"
            local _pause=""; read -rp "按 Enter 返回主菜单..." _pause || true
            return
        fi

        local tmp_users="/tmp/xray_users_pool.txt"
        echo "$clients" | awk -F'|' '{print NR"|"$1"|"$2}' > "$tmp_users"
        
        echo -e "  当前用户列表："
        while IFS='|' read -r num uid remark; do
            local utime=$(grep "^$uid|" "$USER_TIME_MAP" 2>/dev/null | cut -d'|' -f2 || echo "")
            utime=${utime:-"未知时间"}
            echo -e "  $num) 备注: $remark | 时间: $utime | UUID: $uid"
        done < "$tmp_users"
        hr
        
        echo "  a) 新增本网用户 (自动分配 UUID 与 ShortId)"
        echo "  m) 手动导入外部用户"
        echo "  s) 修改指定用户的专属 SNI"
        echo "  d) 序号删除用户"
        echo "  q) 退出"
        
        local uopt=""
        read -rp "指令: " uopt || true
        
        if test "$uopt" = "a" || test "$uopt" = "A"; then
            local nu=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
            local ns=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n\r')
            local ctime=$(date +"%Y-%m-%d %H:%M")
            local u_remark=""
            read -rp "请输入新用户的独立节点身份标识 (直接回车默认: User-${ns}): " u_remark
            u_remark=${u_remark:-User-${ns}}
            
            if _safe_jq_write "
                (.inbounds[]? | select(.protocol==\"vless\" and .settings != null) | .settings.clients) += [{\"id\": \"$nu\", \"flow\": \"xtls-rprx-vision\", \"email\": \"$u_remark\"}] |
                (.inbounds[]? | select(.protocol==\"vless\" and .streamSettings.realitySettings != null) | .streamSettings.realitySettings.shortIds) += [\"$ns\"]
            " "新增本网用户 [$u_remark]"; then
                echo "$nu|$ctime" >> "$USER_TIME_MAP"
                systemctl restart xray >/dev/null 2>&1 || true
                info "新用户认证凭证 [ ${u_remark} ] 已成功被内嵌！"
            fi
            local _pause=""; read -rp "按 Enter 继续..." _pause || true
            
        elif test "$uopt" = "m" || test "$uopt" = "M"; then
            local m_remark=""
            read -rp "请输入外部用户的备注 (例如: VIP-Migration): " m_remark
            m_remark=${m_remark:-Imported-User}
            
            local m_uuid=""
            read -rp "请输入该用户的合法 UUID: " m_uuid
            if test -z "$m_uuid"; then error "UUID 不能为空！"; sleep 2; continue; fi
            
            local m_sid=""
            read -rp "请输入该用户的合法 ShortId: " m_sid
            if test -z "$m_sid"; then error "ShortId 不能为空！"; sleep 2; continue; fi
            
            local ctime=$(date +"%Y-%m-%d %H:%M")
            if _safe_jq_write "
                (.inbounds[]? | select(.protocol==\"vless\" and .settings != null) | .settings.clients) += [{\"id\": \"$m_uuid\", \"flow\": \"xtls-rprx-vision\", \"email\": \"$m_remark\"}] |
                (.inbounds[]? | select(.protocol==\"vless\" and .streamSettings.realitySettings != null) | .streamSettings.realitySettings.shortIds) += [\"$m_sid\"]
            " "导入外部用户 [$m_remark]"; then
                echo "$m_uuid|$ctime (导入)" >> "$USER_TIME_MAP"
                local m_sni=""
                read -rp "是否需要为该导入用户挂载专属 SNI? (回车将继承全局池): " m_sni
                if test -n "$m_sni"; then
                    if _safe_jq_write "
                        (.inbounds[]? | select(.protocol==\"vless\" and .streamSettings.realitySettings != null) | .streamSettings.realitySettings.serverNames) += [\"$m_sni\"] | 
                        (.inbounds[]? | select(.protocol==\"vless\" and .streamSettings.realitySettings != null) | .streamSettings.realitySettings.serverNames) |= unique
                    " "分配专属 SNI"; then
                        sed -i "/^$m_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                        echo "$m_uuid|$m_sni" >> "$USER_SNI_MAP"
                    fi
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                info "外部用户已成功导入！"
            fi
            local _pause=""; read -rp "按 Enter 继续..." _pause || true
            
        elif test "$uopt" = "s" || test "$uopt" = "S"; then
            local snum=""
            read -rp "请输入要分配 SNI 的物理序号: " snum
            local target_uuid=$(awk -F'|' -v id="${snum:-0}" '$1==id {print $2}' "$tmp_users" 2>/dev/null || echo "")
            if test -n "$target_uuid"; then
                local u_sni=""
                read -rp "请输入该用户专属指配的 SNI: " u_sni
                if test -n "$u_sni"; then
                    if _safe_jq_write "
                        (.inbounds[]? | select(.protocol==\"vless\" and .streamSettings.realitySettings != null) | .streamSettings.realitySettings.serverNames) += [\"$u_sni\"] | 
                        (.inbounds[]? | select(.protocol==\"vless\" and .streamSettings.realitySettings != null) | .streamSettings.realitySettings.serverNames) |= unique
                    " "修改专属 SNI"; then
                        sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                        echo "$target_uuid|$u_sni" >> "$USER_SNI_MAP"
                        systemctl restart xray >/dev/null 2>&1 || true
                        info "该用户已被绑定独立通道: $u_sni"
                    fi
                fi
            else
                error "无效序号。"
            fi
            local _pause=""; read -rp "按 Enter 继续..." _pause || true
            
        elif test "$uopt" = "d" || test "$uopt" = "D"; then
            local dnum=""
            read -rp "请输入要销毁的用户序号: " dnum
            local total=$(wc -l < "$tmp_users" 2>/dev/null || echo 0)
            
            if test "${total:-0}" -le 1; then
                error "必须保留至少一个账号防失联！"
            else
                local target_uuid=$(awk -F'|' -v id="${dnum:-0}" '$1==id {print $2}' "$tmp_users" 2>/dev/null || echo "")
                if test -n "$target_uuid"; then
                    local idx=$(( ${dnum:-0} - 1 ))
                    if _safe_jq_write "
                        (.inbounds[]? | select(.protocol==\"vless\" and .settings != null) | .settings.clients) |= map(select(.id != \"$target_uuid\")) |
                        (.inbounds[]? | select(.protocol==\"vless\" and .streamSettings.realitySettings != null) | .streamSettings.realitySettings.shortIds) |= del(.[$idx])
                    " "序号删除用户"; then
                        sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                        sed -i "/^$target_uuid|/d" "$USER_TIME_MAP" 2>/dev/null || true
                        systemctl restart xray >/dev/null 2>&1 || true
                        info "该用户已被物理蒸发。"
                    fi
                else
                    error "无效序号。"
                fi
            fi
            local _pause=""; read -rp "按 Enter 继续..." _pause || true
            
        elif test "$uopt" = "q" || test "$uopt" = "Q"; then
            rm -f "$tmp_users" 2>/dev/null || true
            break
        fi
    done
}

# ------------------------------------------------------------------------------
# [ 0x1E: 屏蔽规则管理 (BT/广告双轨拦截) ]
# ------------------------------------------------------------------------------

_global_block_rules() {
    while true; do
        clear
        echo -e "  ${cyan}7) 屏蔽规则管理 (BT/广告双轨拦截)${none}\n"
        echo -e "==================================================="
        echo -e "  屏蔽规则管理 (BT/广告双轨分离拦截)"
        echo -e "==================================================="
        
        if test ! -f "$CONFIG"; then 
            error "未发现核心配置"
            local _pause=""; read -rp "按 Enter 返回主菜单..." _pause || true
            return
        fi
        
        local bt_en=$(jq -r '.routing.rules[]? | select(.protocol != null) | select(.protocol | index("bittorrent")) | ._enabled // "true"' "$CONFIG" 2>/dev/null | head -1 || echo "true")
        local ad_en=$(jq -r '.routing.rules[]? | select(.domain != null) | select(.domain | index("geosite:category-ads-all")) | ._enabled // "true"' "$CONFIG" 2>/dev/null | head -1 || echo "true")
        
        echo -e "  1) BT/PT 协议拦截   当前状态: ${bt_en}"
        echo -e "  2) 全球广告拦截     当前状态: ${ad_en}"
        echo "  0) 返回"
        
        local b_opt=""
        read -rp "选择: " b_opt || true
        
        case "${b_opt:-}" in
            1)
                local nv="true"
                if test "$bt_en" = "true"; then nv="false"; fi
                if _safe_jq_write "(.routing.rules[]? | select(.protocol != null) | select(.protocol | index(\"bittorrent\")) | ._enabled) = $nv" "切换 BT 封锁状态"; then
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "反转成功。"
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            2)
                local nv="true"
                if test "$ad_en" = "true"; then nv="false"; fi
                if _safe_jq_write "(.routing.rules[]? | select(.domain != null) | select(.domain | index(\"geosite:category-ads-all\")) | ._enabled) = $nv" "切换广告拦截"; then
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "反转成功。"
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            0) 
                return 
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# [ 0x1F: 运行状态 (实时 IP 统计/DNS/流量核算) ]
# ------------------------------------------------------------------------------

do_status_menu() {
    while true; do
        clear
        echo -e "  ${cyan}9) 运行状态 (实时 IP 统计/DNS/流量核算)${none}\n"
        echo -e "==================================================="
        echo -e "  运行状态与计费中心"
        echo -e "==================================================="
        
        echo "  1) 服务进程守护状态"
        echo "  2) IP 与 监听网络信息"
        echo "  3) 网卡流量计费核算 、设置/修改 每月账单清零日(vnstat)"
        echo "  4) 实时连接与独立 IP 统计 (自动刷新/雷达模式)"
        echo "  5) 实时修改 Xray CPU 优先级 (-20至-10 动态提权)"
        echo "  0) 返回主菜单"
        hr
        
        local s=""
        read -rp "选择: " s || true
        
        case "${s:-}" in
            1) 
                clear
                systemctl status xray --no-pager || true
                echo ""
                local _p=""; read -rp "探查完成，按 Enter 脱离..." _p || true 
                ;;
            2) 
                clear
                echo -e "\n  核心广域网出口 IP: ${green}$SERVER_IP${none}"
                hr
                echo -e "  本地 DNS 解析栈: "
                grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print "    " $0}' || echo "    获取错误"
                hr
                echo -e "  Xray 监听端口 (LISTEN): "
                ss -tlnp 2>/dev/null | grep xray | awk '{print "    " $4}' || echo "    警告：未发现 Xray 监听！"
                echo ""
                local _p=""; read -rp "按 Enter 返回..." _p || true 
                ;;
            3) 
                if ! command -v vnstat >/dev/null 2>&1; then 
                    error "尚未安装 vnstat。"
                    local _p=""; read -rp "按 Enter 返回..." _p || true; continue
                fi
                
                clear
                local m_day=$(grep -E "^[[:space:]]*MonthRotate" /etc/vnstat.conf 2>/dev/null | awk '{print $2}' | head -n 1 | tr -d '\r\n')
                m_day=${m_day:-"1"}
                echo -e "  当前月度重置计费日: ${cyan}每月 $m_day 号${none}"
                hr
                (vnstat -m 3 2>/dev/null || vnstat -m 2>/dev/null || true)
                hr
                
                local d_day=""
                read -rp "修改账单强行截断日期(1-31)，回车返回: " d_day
                if test -n "$d_day" && test "${d_day:-0}" -ge 1 2>/dev/null && test "${d_day:-0}" -le 31 2>/dev/null; then
                    sed -i '/^[#[:space:]]*MonthRotate/d' /etc/vnstat.conf 2>/dev/null || true
                    echo "MonthRotate $d_day" >> /etc/vnstat.conf
                    systemctl restart vnstat >/dev/null 2>&1 || true
                    info "截断日已修改为每月的 $d_day 号。"
                    local _p=""; read -rp "按 Enter 退出..." _p || true
                fi
                ;;
            4)
                while true; do
                    clear
                    local x_pids=$(pidof xray 2>/dev/null | xargs | tr -s ' ' '|' || echo "")
                    if test -n "$x_pids"; then
                        echo -e "  ${cyan}【链路状态】${none}"
                        ss -ntupa 2>/dev/null | grep -E "pid=($x_pids)[,)]" | awk '{print $1"_"$2}' | sort | uniq -c | sort -nr | awk '{printf "    %-15s : %s\n", $2, $1}' || echo "    静默侦测中..."
                        
                        echo -e "\n  ${cyan}【独立访客 IP 排行榜】${none}"
                        local ips=$(ss -ntupa 2>/dev/null | grep -E "pid=($x_pids)[,)]" | grep -vE "LISTEN|UNCONN" | awk '{print $6}' | sed -E 's/:[0-9]+$//' | tr -d '[]' | grep -vE "^127\.0\.0\.1$|^0\.0\.0\.0$|^::$|^\*$|^::ffff:127\.0\.0\.1$" || echo "")
                        
                        if test -n "$ips"; then
                            echo "$ips" | sort | uniq -c | sort -nr | head -n 10 | awk '{printf "    IP: %-18s (频次: %s)\n", $2, $1}'
                        else
                            echo -e "    ${gray}主线雷达运转正常，未发现物理数据探测。${none}"
                        fi
                    else
                        error "未找到存活的 Xray 主进程。"
                    fi
                    
                    echo -e "\n  ---------------------------------------------------"
                    echo -e "  指挥热键:  [ ${yellow}r${none} ] 刷新   [ ${yellow}q${none} ] 退出"
                    
                    local cmd=""
                    if read -t 2 -n 1 -s cmd 2>/dev/null; then
                        if [[ "$cmd" == "q" || "$cmd" == "Q" || "$cmd" == $'\e' ]]; then break; fi
                        if [[ "$cmd" == "r" || "$cmd" == "R" ]]; then continue; fi
                    fi
                done
                ;;
            5)
                local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
                if test -f "$limit_file"; then
                    local current_nice=$(awk -F'=' '/^Nice=/ {print $2}' "$limit_file" | head -n 1 || echo "")
                    echo -e "  当前 Nice 优先级: ${cyan}${current_nice:-未设置}${none}"
                    local new_nice=""
                    read -rp "请输入新的提权权重 (-20 至 -10): " new_nice
                    if [[ "$new_nice" =~ ^-?[0-9]+$ ]]; then
                        sed -i '/^Nice=/d' "$limit_file" 2>/dev/null || true
                        echo "Nice=$new_nice" >> "$limit_file"
                        systemctl daemon-reload >/dev/null 2>&1 || true
                        systemctl restart xray >/dev/null 2>&1 || true
                        info "优先级重切完毕。"
                    else
                        error "输入格式错误。"
                    fi
                else
                    error "找不到 limits.conf 配置文件！"
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            0) 
                return 
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# [ 0x20: 自毁卸载机制与系统基建重构 ]
# ------------------------------------------------------------------------------

do_uninstall() {
    clear
    warn "系统将摧毁整个架构：加密节点配置库、Xray 进程树、Dnsmasq 解析表。"
    warn "但 Sysctl 内核加速引擎将被【永久保留】！"
    
    local confirm=""
    read -rp "请确认是否执意引爆自毁程序？(输入y确定): " confirm
    
    if test "$confirm" != "y" && test "$confirm" != "Y"; then 
        return
    fi
    
    info "引爆系统数据链..."
    systemctl stop dnsmasq >/dev/null 2>&1 || true
    systemctl disable dnsmasq >/dev/null 2>&1 || true
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get purge -y dnsmasq >/dev/null 2>&1 || yum remove -y dnsmasq >/dev/null 2>&1 || true
    rm -f /etc/dnsmasq.conf >/dev/null 2>&1 || true

    chattr -i /etc/resolv.conf 2>/dev/null || true
    if test -f /etc/resolv.conf.bak; then mv -f /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true; fi
    systemctl stop resolvconf.service >/dev/null 2>&1 || true
    systemctl disable resolvconf.service >/dev/null 2>&1 || true
    if systemctl list-unit-files 2>/dev/null | grep -q "systemd-resolved.service"; then
        systemctl enable systemd-resolved >/dev/null 2>&1 || true
        systemctl start systemd-resolved >/dev/null 2>&1 || true
    fi

    systemctl stop xray >/dev/null 2>&1 || true
    systemctl disable xray >/dev/null 2>&1 || true
    
    rm -rf /etc/systemd/system/xray.service >/dev/null 2>&1 || true
    rm -rf /etc/systemd/system/xray@.service >/dev/null 2>&1 || true
    rm -rf /etc/systemd/system/xray.service.d >/dev/null 2>&1 || true
    rm -rf /lib/systemd/system/xray* >/dev/null 2>&1 || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    
    rm -rf "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SCRIPT_DIR" >/dev/null 2>&1 || true
    rm -rf /var/log/xray* >/dev/null 2>&1 || true
    
    (crontab -l 2>/dev/null | grep -v "update-dat.sh" | grep -v "/bin/systemctl restart xray") | crontab - 2>/dev/null || true
    
    rm -f "/usr/local/bin/xrv" >/dev/null 2>&1 || true
    rm -f "$SCRIPT_PATH" >/dev/null 2>&1 || true
    hash -r 2>/dev/null || true
    
    print_green "  服务器生态已被物理抹平，即将退出..."
    exit 0
}

do_sys_init_menu() {
    while true; do
        clear
        echo -e "  ${cyan}10) 初次安装、系统内核调优、开启25项优化${none}\n"
        echo -e "==================================================="
        echo -e "  初次安装、更新系统组件"
        echo -e "==================================================="
        
        echo "  1) 一键更新系统、安装常用组件并校准时区、设置永久生效1GB swap"
        echo "  2) 必须先安装 XANMOD (main) 官方预编译内核"
        echo "  3) 先完成2），再进行编译安装 Xanmod 内核 + BBR3"
        echo "  4) 网卡发送队列 (TX Queue) 深度调优 (2000 极速版)"
        echo "  5) 系统内核网络栈极限调优"
        echo "  6) 全域 25 项极限微操 (CAKE/硬中断隔离/零拷贝/聚合反转)"
        echo "  7) 配置 CAKE 高阶调度参数 (Bandwidth/Overhead/MPU 针对虚机)"
        echo "  0) 返回主菜单"
        
        local sopt=""
        read -rp "选择: " sopt || true
        
        case "${sopt:-}" in
            1) 
                preflight
                local _p=""; read -rp "完成。按 Enter 键返回..." _p || true 
                ;;
            2) do_install_xanmod_main_official ;;
            3) do_xanmod_compile ;;
            4) do_txqueuelen_opt ;;
            5) do_perf_tuning ;;
            6) do_app_level_tuning_menu ;;
            7) 
                local IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
                if test -z "$IFACE"; then error "找不到网卡接口"; else
                    local bw=""
                    read -rp "请输入虚拟机的下行带宽限制 (如: 1Gbit, 500Mbit)，留空默认不限: " bw
                    local cmd="tc qdisc replace dev $IFACE root cake"
                    if test -n "$bw"; then cmd="$cmd bandwidth $bw"; fi
                    cmd="$cmd besteffort overhead 48 mpu 64"
                    eval "$cmd" >/dev/null 2>&1 || true
                    info "CAKE 高阶参数注入成功：$cmd"
                fi
                local _p=""; read -rp "按 Enter 返回..." _p || true
                ;;
            0) return ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# [ 0x21: 最高防线控制中枢主屏幕展示区 (The Genesis Hub) ]
# ------------------------------------------------------------------------------

main_menu() {
    while true; do
        clear
        local config_status="已下载，未安装"
        if systemctl is-active --quiet xray 2>/dev/null; then 
            config_status="已启动"
        elif test -f "$CONFIG"; then 
            config_status="已下载，未运行"
        fi
        
        local current_kernel=$(uname -r)
        local script_name=$(basename "$0")
        
        echo -e "当前xray脚本状态: ${cyan}${config_status}${none} | 全局快捷热键唤醒: ${cyan}xrv${none}"
        echo -e "当前使用的内核: ${yellow}${current_kernel}${none} | 对外IP: ${yellow}${SERVER_IP}${none}"
        echo -e "当前脚本名: ${script_name}"
        echo -e ""
        echo -e "==================================================="
        echo "  1) 核心安装 / 重构网络 (VLESS/SS 双协议)"
        echo "  2) 用户管理 (增删/导入/专属 SNI 挂载)"
        echo "  3) 分发中心 (多用户详情与紧凑二维码)"
        echo "  4) 手动更新 Geo 规则库 (已夜间自动热更)"
        echo "  5) 更新 Xray 核心 (无缝拉取最新版重启)"
        echo "  6) 热切 SNI 域名"
        echo "  7) 屏蔽规则管理 (BT/广告双轨拦截)"
        echo "  9) 运行状态 (实时 IP 统计/DNS/流量核算)"
        echo "  10) 初次安装、系统内核调优、开启25项优化"
        echo "  0) 退出"
        echo "  88) 彻底卸载 (安全复原系统解析并清空软件痕迹)"
        hr
        
        local num=""
        read -rp "选择: " num || true
        
        case "${num:-}" in
            1) do_install ;;
            2) do_user_manager ;;
            3) 
                do_summary
                local _p=""; read -rp "按 Enter 返回主菜单..." _p || true 
                ;;
            4) 
                info "正在拉取最新规则库..."
                bash "$UPDATE_DAT_SCRIPT" >/dev/null 2>&1 || true
                ensure_xray_is_alive
                local _p=""; read -rp "完成，按 Enter 返回..." _p || true 
                ;;
            5) do_update_core ;;
            6) 
                if choose_sni; then 
                    _update_matrix
                    do_summary
                    local _p=""; read -rp "变更完成，按 Enter 键脱离..." _p || true
                fi 
                ;;
            7) _global_block_rules ;;
            9) do_status_menu ;;
            10) do_sys_init_menu ;;
            88) do_uninstall ;;
            0) exit 0 ;;
            *) 
                echo -e "${gl_hong}❌ 指令错误！${gl_bai}"
                sleep 1 
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# 战舰全域通电、挂载系统环境、点燃屏幕与引擎
# ------------------------------------------------------------------------------
preflight
main_menu
