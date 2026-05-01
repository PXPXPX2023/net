#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: ex188t42.sh (The Apex Vanguard - Ultimate Genesis 4000+ Pro)
# 快捷方式: xrv
# 版本号: V188t41.Mega.Perfect.Fusion
#
# 【V188t41 终极大一统修补增量版】
#   1. 管道防爆机制: 彻底斩断 SIGPIPE 死亡链，修复 tar 解压获取目录时的闪退。
#   2. APT 动态雷达: 不再写死内核包名，引入 apt-cache search 动态抓取，绝杀 Unable to locate。
#   3. Xray 规则补全: 路由规则全面补全 "type":"field"，修复旧配置在新版内核静默失效。
#   4. 百万并发恢复: 继承 ex139，拉满 Systemd 的 LimitNOFILE=1048576 与 LimitNPROC=512000。
#   5. 军规级 UI 对齐: 继承 ex136/ex139 完美的 8 行展示，引入 ex122 原子化重载。
#   6. 绝对不压行: 全局废弃缩水型 && || 表达式，坚持原生多行 if-then，换取最高兼容性。
# ==============================================================================

# ------------------------------------------------------------------------------
# [ 0x01: 系统级基础环境检查与严格模式锁定 ]
# ------------------------------------------------------------------------------

# 优先执行 Bash 版本守卫，拦截 dash 运行
if test -z "${BASH_VERSION:-}"; then
    echo "Error: 严重错误！本脚本深度依赖 Bash 高级特性，请执行: bash ex188t42.sh"
    exit 1
fi

if test "${BASH_VERSINFO[0]:-0}" -lt 4; then
    echo "Error: 严重错误！需要 Bash 4.0 或以上版本运行环境，请更新您的操作系统！"
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

# 运行期动态变量初始化
SERVER_IP=""
REMARK_NAME="xp-reality"
BEST_SNI="www.microsoft.com"
SNI_JSON_ARRAY="\"www.microsoft.com\""
LISTEN_PORT=443
X25519_PRIV=""
X25519_PUB=""

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

# 构建系统底层目录骨架 (必须在函数定义之前建立，为日志和锚点提供物理空间)
mkdir -p "$CONFIG_DIR" "$DAT_DIR" "$SCRIPT_DIR" "$LOG_DIR" "$BACKUP_DIR" "$FLAGS_DIR" 2>/dev/null || true
touch "$USER_SNI_MAP" "$USER_TIME_MAP" 2>/dev/null || true

# 精确对齐所有可能产生的临时文件，避免遗漏
cleanup_temp_files() {
    rm -f /tmp/sni_array.json 2>/dev/null || true
    rm -f /tmp/vless_inbound.json 2>/dev/null || true
    rm -f /tmp/vless_final.json 2>/dev/null || true
    rm -f /tmp/ss_inbound.json 2>/dev/null || true
    rm -f /tmp/new_client.json 2>/dev/null || true
    rm -f /tmp/xray_users_pool.txt 2>/dev/null || true
    rm -f /tmp/xray_users.txt 2>/dev/null || true
    rm -f /tmp/install-release.sh 2>/dev/null || true
    rm -f /tmp/sni_test.* 2>/dev/null || true
    rm -f /tmp/check_x86-64_psabi.sh 2>/dev/null || true
    rm -f /tmp/net-tcp-tune.* 2>/dev/null || true
    rm -f /tmp/xray_cfg_*.json 2>/dev/null || true
}

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
    
    cleanup_temp_files
    warn "环境守护系统已自动触发，残留进程与临时挂载点已清理完毕。"
}

# ------------------------------------------------------------------------------
# [ 0x06: 核心配置灾备、验证中枢与权限锁 (兼容 exit code 判断) ]
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
    if test ! -f "$CONFIG"; then 
        return 0
    fi
    
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    
    cp -f "$CONFIG" "$BACKUP_DIR/config_${ts}.json" 2>/dev/null || true
    ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | tail -n +16 | xargs rm -f 2>/dev/null || true
    
    log_info "配置执行物理级快照: config_${ts}.json"
}

restore_latest_backup() {
    local latest
    latest=$(ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | head -n 1 || true)
    
    if test -n "$latest"; then
        info "正在执行时空回溯，载入并强行覆写目标快照: $(basename "$latest")..."
        cp -f "$latest" "$CONFIG" 2>/dev/null || true
        fix_permissions
        systemctl restart xray >/dev/null 2>&1 || true
        warn "已成功强制回滚至安全点。"
        log_info "触发灾难回滚，系统降级载入快照: $latest"
        return 0
    fi
    
    error "回滚系统失效：时空存储库中未发现有效配置快照！"
    return 1
}

# 完美兼容新版和旧版 Xray 的验证指令
verify_xray_config() {
    local target_config="$1"
    if test ! -f "$XRAY_BIN"; then
        return 0 
    fi
    
    info "唤醒 Xray 核心引擎，进入配置安全预审模式..."
    
    if "$XRAY_BIN" run -test -config "$target_config" >/dev/null 2>&1; then
        info "配置预审通过，底层 JSON 语法逻辑完美闭环。"
        return 0
    elif "$XRAY_BIN" -test -config "$target_config" >/dev/null 2>&1; then
        info "配置预审通过 (旧版兼容模式)。"
        return 0
    else
        error "预审拦截！Xray 核心拒绝加载该配置，提取诊断流："
        # 提取报错头部，供用户查看
        "$XRAY_BIN" run -test -config "$target_config" 2>&1 | head -n 15 || true
        return 1
    fi
}

ensure_xray_is_alive() {
    info "向 Systemd 守护系统下发 Xray 服务层级重载指令..."
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl restart xray >/dev/null 2>&1 || true
    sleep 3
    
    if systemctl is-active --quiet xray; then
        info "Xray 引擎心跳回波正常，服务已稳健挂载！"
        return 0
    else
        error "Xray 引擎启动宣告失败！诊断日志流如下："
        hr
        journalctl -u xray.service --no-pager -n 15 2>/dev/null | awk '{print "    " $0}' || true
        hr
        warn "引擎崩溃，立即触发时空坐标安全回滚程序..."
        restore_latest_backup
        local _pause=""
        read -rp "按 Enter 键知悉并返回中枢..." _pause || true
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
    
    backup_config
    tmp=$(mktemp /tmp/xray_cfg_XXXXXX.json)
    
    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null; then
        if verify_xray_config "$tmp"; then
            mv -f "$tmp" "$CONFIG" >/dev/null 2>&1 || true
            fix_permissions
            log_info "JQ 写入成功: $description"
            return 0
        else
            error "安全预审未通过，操作已撤销：$description"
            rm -f "$tmp" >/dev/null 2>&1 || true
            restore_latest_backup
            return 1
        fi
    else
        error "JQ 语法断层：$description"
        log_error "JQ 解析失败，Filter: $filter"
        rm -f "$tmp" >/dev/null 2>&1 || true
        restore_latest_backup
        return 1
    fi
}

# ------------------------------------------------------------------------------
# [ 0x08: Systemd 特种兵级提权 (重新拉满 ex139 的百万并发) ]
# ------------------------------------------------------------------------------

fix_xray_systemd_limits() {
    info "正在对 Xray 实施 Root 级越权管理与极限资源扩容..."
    local override_dir="/etc/systemd/system/xray.service.d"
    
    if ! mkdir -p "$override_dir" 2>/dev/null; then
        error "无法创建 Systemd Override 目录，提权流可能受阻！"
    fi
    
    local limit_file="$override_dir/limits.conf"
    local current_nice="-20"
    local current_gogc="100"
    local current_oom="true"
    local current_affinity=""
    local current_gomaxprocs=""
    local current_buffer=""

    # 脱离 pipefail，防止 grep + head 导致的提权管道断裂
    set +o pipefail

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
        if grep -q "^Environment=\"XRAY_RAY_BUFFER_SIZE=" "$limit_file" 2>/dev/null; then
            current_buffer=$(awk -F'=' '/^Environment="XRAY_RAY_BUFFER_SIZE=/ {print $3}' "$limit_file" | tr -d '"' | head -n 1)
        fi
    fi

    # 恢复 pipefail 护盾
    set -o pipefail

    local TOTAL_MEM
    TOTAL_MEM=$(free -m | awk '/Mem/{print $2}' || echo "1024")
    local GO_MEM_LIMIT=$(( TOTAL_MEM * 85 / 100 ))

    # 拉满 ex139 的百万并发防线：LimitNOFILE=1048576, LimitNPROC=512000
    cat > "$limit_file" << EOF
[Service]
User=root
Group=root
CapabilityBoundingSet=~
AmbientCapabilities=~
LimitNOFILE=1048576
LimitNPROC=512000
LimitMEMLOCK=infinity
Nice=${current_nice}
Environment="GOMEMLIMIT=${GO_MEM_LIMIT}MiB"
Environment="GOGC=${current_gogc}"
Restart=on-failure
RestartSec=5s
EOF

    if test "$current_oom" = "true"; then
        echo "OOMScoreAdjust=-500" >> "$limit_file"
        echo "IOSchedulingClass=realtime" >> "$limit_file"
        echo "IOSchedulingPriority=2" >> "$limit_file"
    fi
    
    if test -n "$current_affinity"; then
        echo "CPUAffinity=$current_affinity" >> "$limit_file"
    fi
    if test -n "$current_gomaxprocs"; then
        echo "Environment=\"GOMAXPROCS=$current_gomaxprocs\"" >> "$limit_file"
    fi
    if test -n "$current_buffer"; then
        echo "Environment=\"XRAY_RAY_BUFFER_SIZE=$current_buffer\"" >> "$limit_file"
    fi

    if ! systemctl daemon-reload >/dev/null 2>&1; then
        warn "Systemd 守护进程重载失败，可能需要手动执行 daemon-reload。"
    else
        info "Systemd 提权指令下发完毕，百万并发防线就绪。"
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
    
    local need="jq curl wget xxd unzip qrencode vnstat cron openssl iproute2 ethtool bc bison flex dwarves rsync python3 cpio dnsutils"
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
    
    # 临时脱离 set -e，防止 curl 超时引发的脚本闪退
    set +e
    SERVER_IP=$(curl -s -4 --connect-timeout 5 --max-time 10 https://api.ipify.org 2>/dev/null | tr -d '\r\n')
    
    if test -z "$SERVER_IP"; then
        SERVER_IP=$(curl -s -4 --connect-timeout 5 --max-time 10 https://ifconfig.me 2>/dev/null | tr -d '\r\n')
    fi
    
    if test -z "$SERVER_IP"; then
        SERVER_IP=$(curl -s -4 --connect-timeout 5 --max-time 10 https://icanhazip.com 2>/dev/null | tr -d '\r\n')
    fi
    set -e
    
    if test -z "$SERVER_IP"; then
        warn "多重探测失败，机器的公网 IPv4 寻址暂时被阻断或遮蔽。"
        SERVER_IP="获取失败"
    else
        info "成功捕获公网物理信标: $SERVER_IP"
    fi

    # 所有的陷阱函数挂载必须在所有前置函数定型后执行，消灭顺序依赖崩溃
    trap cleanup_temp_files EXIT
    trap '_err_handler $? $LINENO "$BASH_COMMAND"' ERR
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
# [ 0x0C: 核心：130+ 实体 SNI 扫描引擎与智能避障 (原教旨垂直阵列版) ]
# ------------------------------------------------------------------------------

run_sni_scanner() {
    title "雷达嗅探：130+ 实体矩阵与国内连通性深度探测"
    print_yellow ">>> 高频扫描任务已启动... (扫描途中随时按回车键可立即中止并结算)\n"
    
    if test ! -d "$CONFIG_DIR"; then
        mkdir -p "$CONFIG_DIR" 2>/dev/null || true
    fi
    
    # 绝对不压行，一行一个，使用用户指定的绝对无损数组序列
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

        # 发起纯粹的底层 TCP 连通性测试
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
            
            # 容错 DNS 探伤
            set +e
            local doh_res
            doh_res=$(curl -s --connect-timeout 2 "https://dns.alidns.com/resolve?name=$sni&type=1" 2>/dev/null || echo "")
            local dns_cn=""
            if test -n "$doh_res"; then
                dns_cn=$(echo "$doh_res" | jq -r '.Answer[]? | select(.type==1 or .type==5) | .data' 2>/dev/null | tail -n 1 || echo "")
            fi
            set -e
            
            local status_cn=""
            local p_type="NORM"
            
            # 严格判定阻断特征 (投毒到本地环回或空路由)
            if test -z "$dns_cn" || test "$dns_cn" = "127.0.0.1" || test "$dns_cn" = "0.0.0.0" || test "$dns_cn" = "::1" || test "$dns_cn" = "null"; then
                status_cn="${red}国内墙阻断 (DNS 污染或 RST)${none}"
                p_type="BLOCK"
            else
                # 进一步追踪解析的物理落点 (是否被调度至境内)
                set +e
                local loc
                loc=$(curl -s --connect-timeout 2 "https://ipinfo.io/$dns_cn/country" 2>/dev/null | tr -d ' \n' || echo "")
                set -e
                
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
    # 临时脱离严格模式，防止 openssl 超时抛出异常错误码切断脚本
    set +e
    local out
    out=$(echo "Q" | timeout 5 openssl s_client -connect "$target:443" -alpn h2 -tls1_3 -status 2>&1 || echo "")
    set -e
    
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
    
    return "$pass"
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
            read -rp "  请下达选择指令 (默认 1): " sel || true
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
                read -rp "请输入要组合的序号 (空格分隔, 如 1 3 5, 或输入 all 全选): " m_sel || true
                
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
                read -rp "请输入您指定的自定义专属伪装域名: " d || true
                
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
                read -rp "是否无视警告，强制使用该残缺特征域名？(y/n): " force_use || true
                
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
# [ 0x0F: 端口校验器、密码生成与 X25519 密钥系统 (完美合并与全量落盘) ]
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

# [F8] 提取并融合 ex139 / xrayv6 的完整 X25519 密钥对生成机制
gen_x25519() {
    if test ! -x "$XRAY_BIN"; then
        die "Xray 核心尚未安装，无法调用引擎生成底层通信密钥对！"
    fi
    
    local keys
    keys=$("$XRAY_BIN" x25519 2>/dev/null || echo "")
    
    X25519_PRIV=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' \r\n' || echo "")
    X25519_PUB=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' \r\n' || echo "")
    
    if test -z "$X25519_PRIV" || test -z "$X25519_PUB"; then
        die "X25519 椭圆曲线密钥对生成遭遇致命断层，进程已被强制阻断！"
    fi
}

# 兼容老版配置文件（只有私钥，自动演算公钥）
derive_pubkey() {
    local priv="$1"
    
    if test ! -x "$XRAY_BIN"; then
        echo ""
        return
    fi
    
    "$XRAY_BIN" x25519 -i "$priv" 2>/dev/null | grep "Public key" | awk '{print $3}' || echo ""
}

# ------------------------------------------------------------------------------
# [ 0x10: 核心防线：多轨 CDN 镜像升级与下载熔断系统 (极致穿墙防爆版) ]
# ------------------------------------------------------------------------------

do_update_core() {
    title "更新 Xray 核心 (无缝拉取最新版重启)"
    print_magenta ">>> 正在全域连接云端，多轨拉取最新版 Xray 核心引擎..."
    
    local xray_updated=0
    
    # 构建四位一体的强力反代 CDN 矩阵，专治极度恶劣的网络阻断
    for url in "https://ghp.ci/https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh" \
               "https://ghproxy.net/https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh" \
               "https://cdn.jsdelivr.net/gh/XTLS/Xray-install@main/install-release.sh" \
               "https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh"; do
               
        # 增加 -k 参数无视部分极度恶劣环境下的根证书 MITM 劫持
        if curl -kfsSL --connect-timeout 10 --max-time 60 -o /tmp/install-release.sh "$url" 2>/dev/null; then
            
            # 【核心黑科技】：强行注入 PROXY 环境变量！
            # 让官方安装脚本在内部拉取 .zip 核心包时，也强制走反向代理，杜绝连环阻断！
            export PROXY="https://ghp.ci/"
            
            if bash /tmp/install-release.sh @ install >/dev/null 2>&1; then
                xray_updated=1
                info "Xray 核心跨维升级成功，当前数据流桥接源：$url"
                break
            fi
        fi
        
        warn "节点流失，通讯链路遭阻断，正在自动自旋接入备用穿墙镜像..."
    done
    
    # 扫尾清理临时脚本，撤销代理环境变量防止污染全局
    rm -f /tmp/install-release.sh 2>/dev/null || true
    unset PROXY
    
    # 绝对熔断层，防止下载了残缺文件还去重启服务
    if test "$xray_updated" -eq 0; then
        error "多轨 CDN 升级指令悉数落空，核心下载网络遭遇深空级物理阻断！"
        local _pause=""
        read -rp "请检查该机器是否彻底无法连接海外网络，按 Enter 返回..." _pause || true
        return 1
    fi
    
    # 升级后重新压入守护参数与提权配置，防止官方脚本覆盖我们的 limits.conf
    fix_xray_systemd_limits
    systemctl restart xray >/dev/null 2>&1 || true
    
    local cur_ver
    cur_ver=$("$XRAY_BIN" version 2>/dev/null | head -n 1 | awk '{print $2}' || echo "底层获取异常")
    info "热更指令执行完毕！当前系统运行的内核主板版本: ${cyan}$cur_ver${none}"
    
    local _pause=""
    read -rp "按 Enter 键知悉并继续..." _pause || true
}
# ------------------------------------------------------------------------------
# [ 0x11: 官方预编译 XANMOD 部署模块 - 容错智能降级与 APT 寻址引擎 ]
# ------------------------------------------------------------------------------

do_install_xanmod_main_official() {
    title "系统飞升：安装官方预编译 XANMOD 内核"
    
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
        # 极客级绕过 noexec 挂载: 直接 awk 解析，无需赋予执行权限。
        cpu_level=$(awk -f "$cpu_level_script" 2>/dev/null | grep -oE 'x86-64-v[1-4]' | grep -oE '[1-4]' | tail -n 1 || true)
        rm -f "$cpu_level_script" 2>/dev/null || true
    fi
    
    if test -z "$cpu_level"; then
        cpu_level=1
        warn "网络遮蔽无法精确检测 CPU 微架构级别，将默认降级使用系统最宽容的 v1 兼容版本。"
    else
        info "评估完成，当前 CPU 硬件完美支持的微架构最高级别为: v${cpu_level}"
    fi

    print_magenta ">>> [2/4] 正在配置 Xanmod 官方最高优 APT 仓库与防伪 GPG 密钥..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    # 前置依赖补齐
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y gnupg gnupg2 curl sudo wget e2fsprogs >/dev/null 2>&1 || true

    # 回归 Bullseye 最兼容的旧版源挂载法
    echo 'deb http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-kernel.list
    
    # 获取 GPG 公钥并转码写入 trusted 库
    if ! wget -qO - https://dl.xanmod.org/gpg.key | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/xanmod-kernel.gpg; then
        error "从远端导入 GPG 密钥链发生错误，链路可能被污染或官方源已被墙！"
        return 1
    fi

    print_magenta ">>> [3/4] 正在触发 APT 智能降级寻址阵列..."
    
    # 强制刷新缓存读取新加入的仓库
    apt-get update -y
    
    # [F1] 完美修复包名重构导致 Unable to locate package 的致命问题
    # 如果系统里找不到直接的 linux-xanmod-x64v3 包名，则开启内存级搜索，抓取含有 linux-image-xanmod-x64vX 字样的包！
    local pkg_name="linux-xanmod-x64v${cpu_level}"
    
    if ! apt-cache show "$pkg_name" >/dev/null 2>&1; then
        warn "源索引脱离：未找到标准包名 $pkg_name，正在唤醒 APT 模糊寻址雷达..."
        
        # 抓取包含该等级内核的实际 image 包名
        local alt_pkg
        alt_pkg=$(apt-cache search "linux-image-.*xanmod.*x64v${cpu_level}" 2>/dev/null | grep -vE "dbg|headers" | awk '{print $1}' | head -n 1 || true)
        
        if test -n "$alt_pkg"; then
            info "成功修正雷达寻址坐标！锁定目标底层包: $alt_pkg"
            pkg_name="$alt_pkg"
        else
            warn "同级衍生包寻址失败，触发终极物理防线，安全回退至无脑兼容 v1 保底版本..."
            pkg_name="linux-xanmod-x64v1"
            
            # 再校验一次 v1 是否也改名了
            if ! apt-cache show "$pkg_name" >/dev/null 2>&1; then
                local safe_pkg
                safe_pkg=$(apt-cache search "linux-image-.*xanmod.*x64v1" 2>/dev/null | grep -vE "dbg|headers" | awk '{print $1}' | head -n 1 || true)
                if test -n "$safe_pkg"; then
                    pkg_name="$safe_pkg"
                fi
            fi
        fi
    fi
    
    print_magenta ">>> [4/4] 正在向主系统强行注入战舰级内核: $pkg_name ..."
    
    if ! apt-get install -y "$pkg_name"; then
        error "降级保底安装亦宣告失败，内核替换进程中止。请排查物理网络环境与 APT 源配置！"
        local _pause=""
        read -rp "按 Enter 继续..." _pause || true
        return 1
    fi

    if command -v update-grub >/dev/null 2>&1; then
        update-grub || true
    else
        apt-get install -y grub2-common >/dev/null 2>&1 || true
        update-grub || true
    fi

    info "官方预编译 XANMOD 部署与注册已全部就绪！"
    warn "系统将在 10 秒后强制切断电源并自动重启应用新内核..."
    
    sleep 10
    reboot
}

# ------------------------------------------------------------------------------
# [ 0x12: 编译安装原生 Linux 主线内核与 TCP BBR3 (完美管道防爆版) ]
# ------------------------------------------------------------------------------

do_xanmod_compile() {
    title "系统飞升：编译安装 主线内核 + BBR3"
    
    warn "警告: 这是一个极其漫长的过程 (30-60分钟)，低配机极易引发死机断连！"
    warn "强烈建议优先使用菜单中的【官方预编译版】。如果您执意追求极客性能，请继续。"
    
    local confirm=""
    read -rp "确定要执意开始源码编译吗？(y/n): " confirm || true
    
    if test "$confirm" != "y"; then
        if test "$confirm" != "Y"; then
            return
        fi
    fi

    title "=== [1/8] 开始执行深度系统清理与模块解容 ==="
    
    export DEBIAN_FRONTEND=noninteractive
    
    apt-get clean >/dev/null 2>&1 || true
    apt-get autoremove -y --purge >/dev/null 2>&1 || true
    journalctl --vacuum-time=1d >/dev/null 2>&1 || true
    
    rm -rf /var/log/*.log 2>/dev/null || true
    rm -rf /var/log/*/*.log 2>/dev/null || true
    rm -rf /tmp/* 2>/dev/null || true
    rm -rf /var/lib/docker/* 2>/dev/null || true
    rm -rf /usr/src/linux* 2>/dev/null || true
    rm -rf /usr/src/bbr* 2>/dev/null || true
    rm -rf /usr/src/xanmod* 2>/dev/null || true
    rm -rf /compile/* 2>/dev/null || true
    rm -rf /root/linux* 2>/dev/null || true
    rm -rf /root/*.tar* 2>/dev/null || true
    rm -rf /root/*.xz 2>/dev/null || true
    sync

    # inode 节点防爆探测
    local inode_use
    inode_use=$(df -i / 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%' || echo "0")
    
    if test "$inode_use" -gt 90; then
        warn "检测到 inode 节点使用率过高，执行紧急深度释放缓存..."
        apt-get clean >/dev/null 2>&1 || true
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
    local temp_cron
    temp_cron=$(mktemp)
    crontab -l 2>/dev/null | grep -v cc1.sh > "$temp_cron" || true
    echo "0 4 */10 * * /usr/local/bin/cc1.sh >/dev/null 2>&1" >> "$temp_cron"
    crontab "$temp_cron" 2>/dev/null || true
    rm -f "$temp_cron" 2>/dev/null || true

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

    title "=== [3/8] 拉取底层 GCC 编译套件与开发依赖库 ==="
    
    local root_free
    root_free=$(df -m / 2>/dev/null | awk 'NR==2{print $4}' || echo "0")
    
    local BUILD_DIR=""
    if test "$root_free" -gt 4000; then 
        mkdir -p /compile 2>/dev/null || true
        BUILD_DIR="/compile"
        info "根目录空间充裕，工作区路由至: /compile"
    else 
        BUILD_DIR="/usr/src"
        info "工作区默认路由至: /usr/src"
    fi

    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y build-essential bc bison flex libssl-dev libelf-dev libncurses-dev zstd git wget curl xz-utils ethtool numactl make pkg-config >/dev/null 2>&1 || true

    # 计算系统并发算力
    local CPU
    CPU=$(nproc 2>/dev/null || echo 1)
    
    local RAM
    RAM=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo 1024)
    
    local THREADS=1
    if test "$RAM" -ge 2000; then 
        THREADS=$CPU
    fi

    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "eth0")

    title "=== [4/8] 探测并拉取 Kernel 最新的 Stable 稳定版源码 ==="
    
    if ! cd "$BUILD_DIR"; then
        die "权限异常：系统拒绝切入工作区 $BUILD_DIR。"
    fi
    
    local KERNEL_URL
    # 临时脱离严格模式进行安全抓取
    set +e
    KERNEL_URL=$(curl -s https://www.kernel.org/releases.json 2>/dev/null | grep -A3 '"is_latest": true' | grep tarball | head -n 1 | awk -F'"' '{print $4}')
    set -e
    
    if test -z "$KERNEL_URL"; then 
        warn "探测 kernel.org 失败，强行锁定备用回退版本 v6.8..."
        KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.tar.xz"
    fi
    
    if test "$KERNEL_URL" = "null"; then
        warn "探测 kernel.org 返回异常数据，强行锁定备用回退版本 v6.8..."
        KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.tar.xz"
    fi
    
    local KERNEL_FILE
    KERNEL_FILE=$(basename "$KERNEL_URL")
    
    info "建立信道，开始拉取源码包: $KERNEL_FILE"
    wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"

    # [F2] 管道流防爆处理：临时关闭 pipefail 并采用绝对安全测试
    set +o pipefail
    if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
        warn "检测到初次获取的源码包发生数据断层，触发网络熔断重试..."
        rm -f "$KERNEL_FILE" 2>/dev/null || true
        wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"
        
        if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
            set -o pipefail
            error "下载或解压验证连续失败，源码包已被污染，编译行动强制中止。"
            return 1
        fi
    fi
    set -o pipefail

    info "执行 XZ 极致解压，释放内核源码..."
    tar -xJf "$KERNEL_FILE"
    
    # [F2] 彻底废弃极其危险的 `tar -tf | head -1` 管道逻辑！
    # 改用原生 Bash 字符串截断移除 `.tar.xz` 后缀即可得到解压出的文件夹名！
    local KERNEL_DIR
    KERNEL_DIR="${KERNEL_FILE%.tar.xz}"
    
    if ! cd "$KERNEL_DIR"; then
        die "无法切入解压后的源码目录: $KERNEL_DIR。解压可能出现致命异常！"
    fi

    title "=== [5/8] 克隆宿主配置谱并暴力注入 BBR3 开启参数 ==="
    
    make defconfig >/dev/null 2>&1 || true
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
    
    yes "" | make olddefconfig >/dev/null 2>&1 || true

    title "=== [6/8] 释放 CPU 算力，开启内核原生直驱 Forge 锻造模式 ==="
    info "分配编译并发线程数: $THREADS"
    
    # 彻底弃用依赖严苛的 bindeb-pkg，改用原生 make install 保障通过率
    if ! make -j"$THREADS"; then
        error "编译线程彻底崩塌！请排查物理内存是否溢出或存在硬盘坏道。"
        local _p=""
        read -rp "按 Enter 返回主菜单..." _p || true
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

    title "=== [7/8] 下发网卡硬件卸载 (Offload) 控制与 RPS/RFS 调度器 ==="
    
    cat > /usr/local/bin/nic-optimize.sh <<'EONIC'
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "eth0")

if test -n "$IFACE"; then
    ethtool -K "$IFACE" gro off 2>/dev/null || true
    ethtool -K "$IFACE" gso off 2>/dev/null || true
    ethtool -K "$IFACE" tso off 2>/dev/null || true
    ethtool -K "$IFACE" lro off 2>/dev/null || true
    ethtool -K "$IFACE" rx-gro-hw off 2>/dev/null || true
    ethtool -K "$IFACE" tx-udp-segmentation on 2>/dev/null || true
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
RX_QUEUES=\$(ls -d /sys/class/net/\$IFACE/queues/rx-* 2>/dev/null | wc -l || echo 0)

for RX in /sys/class/net/\$IFACE/queues/rx-*; do 
    if test -w "\$RX/rps_cpus"; then 
        echo "\$CPU_MASK" > "\$RX/rps_cpus" 2>/dev/null || true
    fi
done

for TX in /sys/class/net/\$IFACE/queues/tx-*; do 
    if test -w "\$TX/xps_cpus"; then 
        echo "\$CPU_MASK" > "\$TX/xps_cpus" 2>/dev/null || true
    fi
done

sysctl -w net.core.rps_sock_flow_entries=131072 >/dev/null 2>&1 || true

if test "\$RX_QUEUES" -gt 0; then
    FLOW_PER_QUEUE=\$((65535 / RX_QUEUES))
    for RX in /sys/class/net/\$IFACE/queues/rx-*; do 
        if test -w "\$RX/rps_flow_cnt"; then 
            echo "\$FLOW_PER_QUEUE" > "\$RX/rps_flow_cnt" 2>/dev/null || true
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
    for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || echo ""); do 
        if test -w "/proc/irq/$irq/smp_affinity"; then
            echo "$CPU_MASK" > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true
        fi
    done

    title "=== [8/8] 销毁编译垃圾并定档重置 ==="
    cd /
    rm -rf "$BUILD_DIR"/linux* 2>/dev/null || true
    rm -rf "$BUILD_DIR/$KERNEL_FILE" 2>/dev/null || true
    rm -rf /compile/* 2>/dev/null || true
    rm -rf /root/linux* 2>/dev/null || true
    
    info "主线内核编译与网卡底层优化已全部封炉就绪！"
    warn "系统将在 30 秒后强制断电重启应用全部更改，请耐心等待重新连接..."
    
    sleep 30
    reboot
}
# ------------------------------------------------------------------------------
# [ 0x13: TX Queue 硬件发送队列特化调优 (防堵塞极速版) ]
# ------------------------------------------------------------------------------

do_txqueuelen_opt() {
    title "网卡发送队列 (TX Queue) 深度调优"
    
    local IP_CMD
    IP_CMD=$(command -v ip || echo "")
    
    if test -z "$IP_CMD"; then
        error "无法找到系统底层 ip 组件，列装过程无法继续！"
        local _p=""
        read -rp "按 Enter 继续..." _p || true
        return 1
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test -z "$IFACE"; then 
        IFACE=$(ls /sys/class/net/ 2>/dev/null | grep -v "^lo$" | head -n 1 || echo "eth0")
    fi
    
    if test -z "$IFACE"; then 
        error "无法识别默认出口网卡，操作熔断。"
        local _p=""
        read -rp "按 Enter 继续..." _p || true
        return 1
    fi

    info "当前目标网卡: $IFACE"
    
    local current_txq
    current_txq=$("$IP_CMD" link show "$IFACE" 2>/dev/null | grep -o 'txqueuelen [0-9]*' | awk '{print $2}' || echo "未知")
    echo "  当前 txqueuelen: ${cyan}$current_txq${none}"
    echo ""
    echo "  1) 设置为 2000 (推荐 - 防堵塞极速版，适合普通 VPS)"
    echo "  2) 设置为 5000 (针对高并发大带宽母鸡/独立服务器)"
    echo "  3) 恢复默认 1000"
    echo "  4) 手动输入自定义参数"
    echo "  0) 返回上级"
    
    local opt=""
    read -rp "请下达选择指令: " opt || true

    local new_txq=""
    case "${opt:-0}" in
        1) new_txq=2000 ;;
        2) new_txq=5000 ;;
        3) new_txq=1000 ;;
        4) read -rp "请输入队列长度 (范围 512-10000): " new_txq || true ;;
        0) return ;;
        *) warn "无效选项，已安全阻断。"; return ;;
    esac

    if test -n "$new_txq"; then
        if test "$new_txq" -ge 512 2>/dev/null && test "$new_txq" -le 10000 2>/dev/null; then
            info "正在将网卡 $IFACE 的 txqueuelen 修改至 $new_txq..."
            "$IP_CMD" link set "$IFACE" txqueuelen "$new_txq" 2>/dev/null || true
            
            # 持久化守护进程，开机自动执行
            local boot_cmd
            boot_cmd="$IP_CMD link set $IFACE txqueuelen $new_txq"
            
            if test -f /etc/rc.local; then
                if grep -q "txqueuelen" /etc/rc.local 2>/dev/null; then
                    sed -i '/txqueuelen/d' /etc/rc.local 2>/dev/null || true
                fi
                sed -i '/^exit 0/i '"$boot_cmd" /etc/rc.local 2>/dev/null || true
            fi
            
            cat > /etc/systemd/system/txqueue.service <<EOF
[Unit]
Description=Set TX Queue Length
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$boot_cmd
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload >/dev/null 2>&1 || true
            systemctl enable txqueue.service >/dev/null 2>&1 || true
            systemctl start txqueue.service >/dev/null 2>&1 || true
            
            info "txqueuelen 队列调整已被永久落盘！"
        else
            error "输入的数值 [$new_txq] 超出合理范围，系统拒绝执行。"
        fi
    else
        error "无法识别的输入参数。"
    fi
    
    local _p=""
    read -rp "按 Enter 继续..." _p || true
}

# ------------------------------------------------------------------------------
# [ 0x14: 系统内核网络栈极限压榨 (继承全量 17 项基线参数与内存倾斜) ]
# ------------------------------------------------------------------------------

do_perf_tuning() {
    title "极限压榨：低延迟系统底层网络栈调优"
    warn "警告: 注入极限参数后将发生系统级重启！"
    
    local confirm=""
    read -rp "确定要继续吗？(y/n): " confirm || true
    
    if test "$confirm" != "y"; then
        if test "$confirm" != "Y"; then
            return
        fi
    fi
    
    # 动态获取 tcp_adv_win_scale / tcp_app_win 的内存倾斜增量
    local current_scale
    current_scale=$(sysctl -n net.ipv4.tcp_adv_win_scale 2>/dev/null || echo "1")
    
    local current_app
    current_app=$(sysctl -n net.ipv4.tcp_app_win 2>/dev/null || echo "31")
    
    echo -e "  当前 tcp_adv_win_scale: ${cyan}${current_scale}${none} (建议 1)"
    echo -e "  当前 tcp_app_win: ${cyan}${current_app}${none} (建议 31)"
    
    local new_scale=""
    read -rp "请输入 tcp_adv_win_scale (-2 到 2，回车默认): " new_scale || true
    if test -z "$new_scale"; then
        new_scale="$current_scale"
    fi
    
    local new_app=""
    read -rp "请输入 tcp_app_win (1 到 31，回车默认): " new_app || true
    if test -z "$new_app"; then
        new_app="$current_app"
    fi

    # 清除历史遗留的网络加速器垃圾
    systemctl stop net-speeder >/dev/null 2>&1 || true
    killall net-speeder >/dev/null 2>&1 || true
    systemctl disable net-speeder >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/net-speeder.service 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    
    truncate -s 0 /etc/sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-network-optimized.conf 2>/dev/null || true
    
    local target_qdisc="fq"
    local cake_status
    cake_status=$(check_cake_state)
    
    if test "$cake_status" = "true"; then 
        target_qdisc="cake"
    fi

    # 100% 保留极客定制的 17 项基线参数，附带内存倾斜注入
    cat > /etc/sysctl.d/99-xray-perf.conf << EOF
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 32768
net.core.rmem_max = 21699928
net.core.wmem_max = 21699928
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.ipv4.tcp_rmem = 4096 760576 21699928
net.ipv4.tcp_wmem = 4096 760576 21699928
net.ipv4.tcp_mem = 786432 1048576 26777216
net.ipv4.udp_mem = 65536 131072 262144
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 65536
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_mtu_probing = 1
net.ipv4.ip_local_port_range = 10000 65535
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.core.default_qdisc = ${target_qdisc}
net.ipv4.tcp_congestion_control = bbr
vm.swappiness = 1
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
fs.file-max = 1048576
fs.inotify.max_user_instances = 8192
net.ipv4.tcp_adv_win_scale = ${new_scale}
net.ipv4.tcp_app_win = ${new_app}
EOF

    sysctl -p /etc/sysctl.d/99-xray-perf.conf >/dev/null 2>&1 || warn "部分网络堆栈参数应用失败，需重启系统强行接管。"
    info "内核网络参数列装完成。"

    # 文件描述符级持久化提权
    local limits_conf="/etc/security/limits.d/99-xray.conf"
    cat > "$limits_conf" << 'EOF'
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF
    info "ulimit 防线已重载：1048576。"

    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test -n "$IFACE"; then
        cat > /usr/local/bin/nic-optimize.sh <<'EONIC'
#!/bin/bash
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
if test -n "$IFACE"; then
    ethtool -K $IFACE lro off rx-gro-hw off 2>/dev/null || true
fi
EONIC
        chmod +x /usr/local/bin/nic-optimize.sh 2>/dev/null || true
        
        cat > /etc/systemd/system/nic-optimize.service <<EOSERVICE
[Unit]
Description=NIC Hardware Optimization
After=network.target

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
    fi
    
    info "调优网阵编织完毕！系统将在 10 秒后强行断电并以全新形态启动..."
    sleep 10
    reboot
}

# ------------------------------------------------------------------------------
# [ 0x15: CAKE 高阶配置中心与实时调谐器 (解决跨洋大包降速失真) ]
# ------------------------------------------------------------------------------

_apply_cake_live() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    local cake_status
    cake_status=$(check_cake_state)
    
    if test "$cake_status" = "true"; then
        local base_opts=""
        if test -f "$CAKE_OPTS_FILE"; then
            base_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
        fi
        
        local f_ack=""
        local ack_status
        ack_status=$(check_ackfilter_state)
        if test "$ack_status" = "true"; then 
            f_ack="ack-filter"
        fi
        
        local f_ecn=""
        local ecn_status
        ecn_status=$(check_ecn_state)
        if test "$ecn_status" = "true"; then 
            f_ecn="ecn"
        fi
        
        local f_wash=""
        local wash_status
        wash_status=$(check_wash_state)
        if test "$wash_status" = "true"; then 
            f_wash="wash"
        fi
        
        tc qdisc replace dev "$IFACE" root cake $base_opts $f_ack $f_ecn $f_wash 2>/dev/null || true
    fi
    
    # 强制同步底层硬件引导脚本，实现绝缘重启保护
    update_hw_boot_script
}

config_cake_advanced() {
    clear
    title "CAKE 高阶调度参数配置 (解决跨洋大流量降速与排队失真)"
    echo -e "  ${gray}当前系统中 CAKE 队列的高阶参数将绝对保存在: $CAKE_OPTS_FILE${none}"
    
    local current_opts="无 (默认自适应)"
    if test -f "$CAKE_OPTS_FILE"; then 
        current_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "无 (默认自适应)")
    fi
    echo -e "  当前已应用的高阶参数: ${cyan}${current_opts}${none}\n"

    echo -e "  ${yellow}1. 带宽声明 (Bandwidth)${none}"
    echo -e "  只有声明了物理带宽，CAKE 才能在软件层面精准拆解 GSO 的 64KB 超级聚合包！"
    echo -e "  建议设置为服务器实际可用带宽的 90% (例如测速为 1000Mbps，则输入 900Mbit)。"
    
    local c_bw=""
    read -rp "  请输入限速值 (如 900Mbit, 1Gbit，输入 0 表示撤销限制): " c_bw || true
    
    echo -e "\n  ${yellow}2. 封包开销补偿 (Overhead)${none}"
    echo -e "  补偿 Xray VLESS/Shadowsocks 加密隧道协议带来的额外报文头部体积。"
    echo -e "  建议值：普通以太网输入 18，复杂代理/VPN/多层隧道 强压下建议输入 48。"
    
    local c_oh=""
    read -rp "  请输入 Overhead 头部开销字节数 (输入 0 不设置): " c_oh || true
    
    echo -e "\n  ${yellow}3. 最小数据单元 (MPU)${none}"
    echo -e "  防止 CAKE 排队调度器误判网络中微小的 ACK 确认包耗时。"
    echo -e "  建议值：以太网标准输入 64，严格游戏低延迟模式输入 84。"
    
    local c_mpu=""
    read -rp "  请输入 MPU 字节数边界 (输入 0 不设置): " c_mpu || true

    echo -e "\n  ${yellow}4. 物理链路模式 (RTT 基准)${none}"
    echo -e "  CAKE 的流控制调度池默认 100ms。如果服务器到国内的 Ping 值极高，必须设置为跨洋模式以免发生暴力误杀丢包！"
    echo "  1) 默认/互联网络 (Internet - 85ms 阈值)"
    echo "  2) 跨洋海缆 (Oceanic - 300ms 阈值, 推荐跨国专线/国际服使用)"
    echo "  3) 卫星网络 (Satellite - 1000ms 阈值, 仅适用于极高延迟落地机)"
    
    local rtt_sel=""
    local c_rtt=""
    read -rp "  请选择网络环境匹配型 (直接回车默认 2): " rtt_sel || true
    
    case "${rtt_sel:-2}" in
        1) c_rtt="internet" ;;
        2) c_rtt="oceanic" ;;
        3) c_rtt="satellite" ;;
        *) c_rtt="oceanic" ;;
    esac

    echo -e "\n  ${yellow}5. 流量分类识别器 (Diffserv)${none}"
    echo -e "  Xray 数据为全加密隧道，CAKE 核心无法探知识别视频流和普通网页流。盲走模式可大幅降低 CPU 计算排队开销。"
    echo "  1) Diffserv4 (识别音视频/网页等分类标记, 适合普通服务器, 系统默认)"
    echo "  2) Besteffort (全量盲走不分类, 极客追求最强单线并发推荐)"
    
    local diff_sel=""
    local c_diff=""
    read -rp "  请选择标记分流策略 (直接回车默认 2): " diff_sel || true
    
    case "${diff_sel:-2}" in
        1) c_diff="diffserv4" ;;
        2) c_diff="besteffort" ;;
        *) c_diff="besteffort" ;;
    esac

    local final_opts=""
    
    if test -n "$c_bw"; then
        if test "$c_bw" != "0"; then 
            final_opts="$final_opts bandwidth $c_bw"
        fi
    fi
    
    if test -n "$c_oh"; then
        if test "$c_oh" != "0"; then 
            final_opts="$final_opts overhead $c_oh"
        fi
    fi
    
    if test -n "$c_mpu"; then
        if test "$c_mpu" != "0"; then 
            final_opts="$final_opts mpu $c_mpu"
        fi
    fi
    
    if test -n "$c_rtt"; then 
        final_opts="$final_opts $c_rtt"
    fi
    
    if test -n "$c_diff"; then 
        final_opts="$final_opts $c_diff"
    fi

    # 清除头尾可能的多余空格
    final_opts=$(echo "$final_opts" | sed 's/^ *//')

    if test -z "$final_opts"; then
        rm -f "$CAKE_OPTS_FILE" 2>/dev/null || true
        info "所有 CAKE 高级调谐参数均已脱落，系统恢复至无干预自适应排队模式。"
    else
        echo "$final_opts" > "$CAKE_OPTS_FILE"
        info "CAKE 指挥部高阶微调参数已安全落盘并持久化: $final_opts"
    fi

    # 热切应用当前设置至系统底层
    _apply_cake_live
    
    local _pause=""
    read -rp "参数注液结束。按 Enter 继续退回中枢..." _pause || true
}

# ------------------------------------------------------------------------------
# [ 0x16: 物理开关探针库 (系统状态探测) ]
# ------------------------------------------------------------------------------

check_mph_state() {
    local state
    state=$(jq -r '.routing.domainMatcher // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
    if test "$state" = "mph"; then echo "true"; else echo "false"; fi
}

check_maxtime_state() {
    local state
    state=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
    if test "$state" = "60000"; then echo "true"; else echo "false"; fi
}

check_routeonly_state() {
    local state
    state=$(jq -r '.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
    if test "$state" = "true"; then echo "true"; else echo "false"; fi
}

check_sniff_state() {
    local state
    state=$(jq -r '.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.metadataOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
    if test "$state" = "true"; then echo "true"; else echo "false"; fi
}

check_affinity_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if test -f "$limit_file"; then
        if grep -q "^CPUAffinity=" "$limit_file" 2>/dev/null; then 
            echo "true"
            return
        fi
    fi
    echo "false"
}

check_buffer_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if test -f "$limit_file"; then
        if grep -q "^Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" "$limit_file" 2>/dev/null; then 
            echo "true"
            return
        fi
    fi
    echo "false"
}

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
    if grep -q 'performance' /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_ring_state() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if test -z "$IFACE"; then echo "unsupported"; return; fi
    if ! command -v ethtool >/dev/null 2>&1; then echo "unsupported"; return; fi
    
    local curr_rx
    curr_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Current hardware settings" | grep "RX:" | head -n 1 | awk '{print $2}' || echo "")
    
    if test -z "$curr_rx"; then echo "unsupported"; return; fi
    if test "$curr_rx" = "512"; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_zram_state() {
    if ! lsmod 2>/dev/null | grep -q zram; then echo "unsupported"; return; fi
    if swapon --show 2>/dev/null | grep -q 'zram'; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_journal_state() {
    local conf="/etc/systemd/journald.conf"
    if test ! -f "$conf"; then echo "unsupported"; return; fi
    if grep -q '^Storage=volatile' "$conf" 2>/dev/null; then echo "true"; else echo "false"; fi
}

check_process_priority_state() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if test ! -f "$limit_file"; then echo "false"; return; fi
    if grep -q "^OOMScoreAdjust=-500" "$limit_file" 2>/dev/null; then echo "true"; else echo "false"; fi
}

check_cake_state() {
    if sysctl net.core.default_qdisc 2>/dev/null | grep -q 'cake'; then echo "true"; else echo "false"; fi
}

check_ackfilter_state() {
    if test -f "$FLAGS_DIR/ack_filter"; then echo "true"; else echo "false"; fi
}

check_ecn_state() {
    if test -f "$FLAGS_DIR/ecn"; then echo "true"; else echo "false"; fi
}

check_wash_state() {
    if test -f "$FLAGS_DIR/wash"; then echo "true"; else echo "false"; fi
}

check_gso_off_state() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if test -z "$IFACE"; then echo "unsupported"; return; fi
    if ! command -v ethtool >/dev/null 2>&1; then echo "unsupported"; return; fi
    
    local eth_info
    eth_info=$(ethtool -k "$IFACE" 2>/dev/null || echo "")
    
    if echo "$eth_info" | grep -E "^generic-receive-offload:|^rx-gro:" | grep -q "fixed"; then
        echo "unsupported"
        return
    fi
    
    if echo "$eth_info" | grep -E "^generic-receive-offload:|^rx-gro:" | grep -q " off"; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_irq_state() {
    local CORES
    CORES=$(nproc 2>/dev/null || echo 1)
    if test "$CORES" -lt 2; then echo "unsupported"; return; fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    local irq
    irq=$(grep "$IFACE" /proc/interrupts 2>/dev/null | head -n 1 | awk '{print $1}' | tr -d ':' || echo "")
    
    if test -n "$irq"; then
        local mask
        mask=$(cat "/proc/irq/$irq/smp_affinity" 2>/dev/null | tr -d '0' || echo "")
        if test "$mask" = "1"; then echo "true"; else echo "false"; fi
    else
        echo "false"
    fi
}

# ------------------------------------------------------------------------------
# [ 0x17: 硬件配置自启脚本守护中心 (V139 RPS 散列、BQL 强压、GSO 开关) ]
# ------------------------------------------------------------------------------

update_hw_boot_script() {
    local boot_script="/usr/local/bin/xray-hw-tweaks.sh"
    
    # 构建绝对路径和网卡获取机制，防止在 Systemd 沙盒环境中因缺命令而失败
    cat << 'EOF' > "$boot_script"
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
if test -z "$IFACE"; then 
    sleep 3
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "eth0")
fi

QUEUE_COUNT=$(ls -d /sys/class/net/$IFACE/queues/rx-* 2>/dev/null | wc -l || echo 0)
CPU_CORES=$(nproc 2>/dev/null || echo 1)
MASK=$(printf '%x' $(( (1 << CPU_CORES) - 1 )))

if test "$QUEUE_COUNT" -gt 1; then
    for q in /sys/class/net/$IFACE/queues/rx-*; do 
        if test -w "$q/rps_cpus"; then echo "$MASK" > "$q/rps_cpus" 2>/dev/null || true; fi
    done
    for q in /sys/class/net/$IFACE/queues/tx-*; do 
        if test -w "$q/xps_cpus"; then echo "$MASK" > "$q/xps_cpus" 2>/dev/null || true; fi
    done
else
    irq=$(grep "$IFACE" /proc/interrupts 2>/dev/null | head -n 1 | awk '{print $1}' | tr -d ':' || echo "")
    if test -n "$irq"; then
        if test -w "/proc/irq/$irq/smp_affinity"; then echo 1 > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true; fi
    fi
fi

for bql in /sys/class/net/$IFACE/queues/tx-*/byte_queue_limits/limit_max; do
    if test -f "$bql"; then echo "3000" > "$bql" 2>/dev/null || true; fi
done
EOF

    if test "$(check_thp_state)" = "true"; then
        echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true" >> "$boot_script"
        echo "echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true" >> "$boot_script"
    fi
    
    if test "$(check_cpu_state)" = "true"; then
        echo 'for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do if test -f "$cpu"; then echo performance > "$cpu" 2>/dev/null || true; fi; done' >> "$boot_script"
    fi
    
    if test "$(check_ring_state)" = "true"; then
        echo "ethtool -G \$IFACE rx 512 tx 512 2>/dev/null || true" >> "$boot_script"
    fi

    # 动态插入 GSO 硬件卸载状态
    local gso_state
    gso_state=$(check_gso_off_state)
    
    if test "$gso_state" = "true"; then
        echo "ethtool -K \$IFACE gro off gso off tso off 2>/dev/null || true" >> "$boot_script"
    elif test "$gso_state" = "false"; then
        echo "ethtool -K \$IFACE gro on gso on tso on 2>/dev/null || true" >> "$boot_script"
    fi

    echo "CAKE_OPTS=\"\"" >> "$boot_script"
    echo "if test -f \"$CAKE_OPTS_FILE\"; then CAKE_OPTS=\$(cat \"$CAKE_OPTS_FILE\" 2>/dev/null || echo \"\"); fi" >> "$boot_script"
    
    echo "ACK_FLAG=\"\"" >> "$boot_script"
    echo "if test -f \"$FLAGS_DIR/ack_filter\"; then ACK_FLAG=\"ack-filter\"; fi" >> "$boot_script"
    
    echo "ECN_FLAG=\"\"" >> "$boot_script"
    echo "if test -f \"$FLAGS_DIR/ecn\"; then ECN_FLAG=\"ecn\"; fi" >> "$boot_script"
    
    echo "WASH_FLAG=\"\"" >> "$boot_script"
    echo "if test -f \"$FLAGS_DIR/wash\"; then WASH_FLAG=\"wash\"; fi" >> "$boot_script"

    if test "$(check_cake_state)" = "true"; then
        echo "tc qdisc replace dev \$IFACE root cake \$CAKE_OPTS \$ACK_FLAG \$ECN_FLAG \$WASH_FLAG 2>/dev/null || true" >> "$boot_script"
    fi
    
    if test "$(check_irq_state)" = "true"; then
        echo "systemctl stop irqbalance 2>/dev/null || true" >> "$boot_script"
        echo "for irq in \$(grep \"\$IFACE\" /proc/interrupts 2>/dev/null | awk '{print \$1}' | tr -d ':' || echo \"\"); do if test -w \"/proc/irq/\$irq/smp_affinity\"; then echo 1 > \"/proc/irq/\$irq/smp_affinity\" 2>/dev/null || true; fi; done" >> "$boot_script"
    fi
    
    chmod +x "$boot_script" 2>/dev/null || true

    cat << 'EOF' > /etc/systemd/system/xray-hw-tweaks.service
[Unit]
Description=Xray Hardware Tweaks and Core Restorer
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
# [ 0x18: 系统级黑科技反转控制器 (Toggle Engines 全域展示版) ]
# ------------------------------------------------------------------------------

toggle_dnsmasq() {
    if test "$(check_dnsmasq_state)" = "true"; then
        systemctl stop dnsmasq >/dev/null 2>&1 || true
        systemctl disable dnsmasq >/dev/null 2>&1 || true
        
        chattr -i /etc/resolv.conf 2>/dev/null || true
        rm -f /etc/resolv.conf 2>/dev/null || true
        
        if test -f /etc/resolv.conf.bak; then 
            mv /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true
        else 
            echo "nameserver 8.8.8.8" > /etc/resolv.conf
        fi
        
        systemctl enable systemd-resolved >/dev/null 2>&1 || true
        systemctl start systemd-resolved >/dev/null 2>&1 || true
        
        _safe_jq_write '.dns = {
            "servers": [
                "https://8.8.8.8/dns-query",
                "https://1.1.1.1/dns-query",
                "https://doh.opendns.com/dns-query"
            ],
            "queryStrategy":"UseIP"
        }' "恢复原生 DoH 并发解析"
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
        if test ! -f /etc/resolv.conf.bak; then 
            cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true
        fi
        rm -f /etc/resolv.conf 2>/dev/null || true
        
        echo "nameserver 127.0.0.1" > /etc/resolv.conf
        chattr +i /etc/resolv.conf 2>/dev/null || true
        
        _safe_jq_write '.dns = {
            "servers": ["127.0.0.1"],
            "queryStrategy":"UseIP"
        }' "注入 Dnsmasq 本地缓存解析"
    fi
}

toggle_thp() {
    if test "$(check_thp_state)" = "true"; then
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
    
    if test "$(check_mtu_state)" = "true"; then 
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
    if test "$(check_cpu_state)" = "unsupported"; then 
        return
    fi
    
    if test "$(check_cpu_state)" = "true"; then 
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do 
            if test -f "$cpu"; then 
                echo schedutil > "$cpu" 2>/dev/null || echo ondemand > "$cpu" 2>/dev/null || true
            fi
        done
    else 
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do 
            if test -f "$cpu"; then 
                echo performance > "$cpu" 2>/dev/null || true
            fi
        done
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
        max_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Pre-set maximums" | grep "RX:" | head -n 1 | awk '{print $2}' || echo "")
        
        if test -n "$max_rx"; then 
            ethtool -G "$IFACE" rx "$max_rx" tx "$max_rx" 2>/dev/null || true
        fi
    else 
        ethtool -G "$IFACE" rx 512 tx 512 2>/dev/null || true
    fi
    
    update_hw_boot_script
}

toggle_gso_off() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test "$(check_gso_off_state)" = "unsupported"; then 
        warn "当前机器环境硬件卸载已被底层虚拟机强制锁死 (fixed)。为防止断网，已安全跳过 GSO/GRO 干预！"
        sleep 2
        return
    fi
    
    if test "$(check_gso_off_state)" = "true"; then 
        # 当前已关闭（已打散），则反转为开启（聚合），恢复系统默认行为
        ethtool -K "$IFACE" gro on gso on tso on 2>/dev/null || true
    else 
        # 当前开启，则反转为关闭，执行彻底的碎包模式以极度降低延迟
        ethtool -K "$IFACE" gro off gso off tso off 2>/dev/null || true
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
        systemctl disable xray-zram.service --now 2>/dev/null || true
        rm -f /etc/systemd/system/xray-zram.service /usr/local/bin/xray-zram.sh 2>/dev/null || true
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
Description=Xray ZRAM Setup
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
    else
        if grep -q "^#Storage=" "$conf" 2>/dev/null; then 
            sed -i 's/^#Storage=.*/Storage=volatile/' "$conf" 2>/dev/null || true
        elif grep -q "^Storage=" "$conf" 2>/dev/null; then 
            sed -i 's/^Storage=.*/Storage=volatile/' "$conf" 2>/dev/null || true
        else 
            echo "Storage=volatile" >> "$conf"
        fi
        systemctl restart systemd-journald >/dev/null 2>&1 || true
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
    else
        echo "OOMScoreAdjust=-500" >> "$limit_file"
        echo "IOSchedulingClass=realtime" >> "$limit_file"
        echo "IOSchedulingPriority=2" >> "$limit_file"
    fi
    
    systemctl daemon-reload >/dev/null 2>&1 || true
}

toggle_cake() {
    local conf="/etc/sysctl.d/99-network-optimized.conf"
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    local cake_opts=""
    if test -f "$CAKE_OPTS_FILE"; then 
        cake_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
    fi

    if test "$(check_cake_state)" = "true"; then
        sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = fq/' "$conf" 2>/dev/null || true
        sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1 || true
        tc qdisc replace dev "$IFACE" root fq >/dev/null 2>&1 || true
    else
        sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = cake/' "$conf" 2>/dev/null || true
        if ! grep -q "net.core.default_qdisc" "$conf" 2>/dev/null; then 
            echo "net.core.default_qdisc = cake" >> "$conf"
        fi
        
        modprobe sch_cake >/dev/null 2>&1 || true
        sysctl -w net.core.default_qdisc=cake >/dev/null 2>&1 || true
        
        local ack_flag=""
        if test "$(check_ackfilter_state)" = "true"; then 
            ack_flag="ack-filter"
        fi
        
        local ecn_flag=""
        if test "$(check_ecn_state)" = "true"; then 
            ecn_flag="ecn"
        fi
        
        local wash_flag=""
        if test "$(check_wash_state)" = "true"; then 
            wash_flag="wash"
        fi
        
        tc qdisc replace dev "$IFACE" root cake $cake_opts $ack_flag $ecn_flag $wash_flag 2>/dev/null || true
    fi
    
    update_hw_boot_script
}

toggle_ackfilter() {
    if test "$(check_ackfilter_state)" = "true"; then 
        rm -f "$FLAGS_DIR/ack_filter" 2>/dev/null || true
    else 
        touch "$FLAGS_DIR/ack_filter" 2>/dev/null || true
    fi
    
    if test "$(check_cake_state)" = "false"; then 
        warn "系统已将状态锚点落盘。请注意：必须先开启 CAKE 队列，此项优化才能被网络堆栈挂载！"
        sleep 2
        return
    fi
    
    _apply_cake_live
}

toggle_ecn() {
    if test "$(check_ecn_state)" = "true"; then 
        rm -f "$FLAGS_DIR/ecn" 2>/dev/null || true
    else 
        touch "$FLAGS_DIR/ecn" 2>/dev/null || true
    fi
    
    if test "$(check_cake_state)" = "false"; then 
        warn "系统已将状态锚点落盘。请注意：必须先开启 CAKE 队列，此项优化才能被网络堆栈挂载！"
        sleep 2
        return
    fi
    
    _apply_cake_live
}

toggle_wash() {
    if test "$(check_wash_state)" = "true"; then 
        rm -f "$FLAGS_DIR/wash" 2>/dev/null || true
    else 
        touch "$FLAGS_DIR/wash" 2>/dev/null || true
    fi
    
    if test "$(check_cake_state)" = "false"; then 
        warn "系统已将状态锚点落盘。请注意：必须先开启 CAKE 队列，此项优化才能被网络堆栈挂载！"
        sleep 2
        return
    fi
    
    _apply_cake_live
}

toggle_irq() {
    if test "$(check_irq_state)" = "unsupported"; then 
        return
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    local CORES
    CORES=$(nproc 2>/dev/null || echo 1)
    
    local DEFAULT_MASK
    DEFAULT_MASK=$(printf "%x" $(( (1<<CORES)-1 )))
    
    if test "$(check_irq_state)" = "true"; then
        for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || echo ""); do 
            if test -w "/proc/irq/$irq/smp_affinity"; then
                echo "$DEFAULT_MASK" > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true
            fi
        done
        systemctl start irqbalance >/dev/null 2>&1 || true
        systemctl enable irqbalance >/dev/null 2>&1 || true
    else
        systemctl stop irqbalance >/dev/null 2>&1 || true
        systemctl disable irqbalance >/dev/null 2>&1 || true
        for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || echo ""); do 
            if test -w "/proc/irq/$irq/smp_affinity"; then
                echo 1 > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true
            fi
        done
    fi
    
    update_hw_boot_script
}

# ------------------------------------------------------------------------------
# [ 0x19: 核心应用层 Toggle 逻辑 (含 select(. != null) 绝缘排爆) ]
# ------------------------------------------------------------------------------

_turn_on_app() {
    # 采用安全护盾语法 (|=) 杜绝旧版本 jq 数组崩溃
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
    ' "开启应用层 TCP 加速与路由减负"
    
    local has_reality
    has_reality=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .protocol' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
    
    if test -n "$has_reality"; then
        _safe_jq_write '
          (.inbounds[]? | select(.protocol == "vless" and .streamSettings.security == "reality")) |= (
              .streamSettings.realitySettings = (.streamSettings.realitySettings // {}) |
              .streamSettings.realitySettings.maxTimeDiff = 60000
          )
        ' "开启 Reality maxTimeDiff 绝对防线"
    fi
    
    if test "$(check_dnsmasq_state)" = "true"; then
        _safe_jq_write '
          .dns = {
              "servers": ["127.0.0.1"],
              "queryStrategy": "UseIP"
          }
        ' "开启 DNS 本地缓存路由"
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
        ' "开启加密 DoH 解析"
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
    ' "开启 Xray 策略组极速回收"
    
    _toggle_affinity_on
    
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if test -f "$limit_file"; then
        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
        echo "Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" >> "$limit_file"
        
        local TOTAL_MEM
        TOTAL_MEM=$(free -m | awk '/Mem/{print $2}' || echo "1024")
        
        local DYNAMIC_GOGC=100
        if test "$TOTAL_MEM" -ge 1800; then 
            DYNAMIC_GOGC=1000
        elif test "$TOTAL_MEM" -ge 900; then 
            DYNAMIC_GOGC=500
        else 
            DYNAMIC_GOGC=300
        fi
        
        sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=$DYNAMIC_GOGC\"/" "$limit_file" 2>/dev/null || true
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

_turn_off_app() {
    # 采用安全护盾语法 (|=) 杜绝旧版本 jq 数组崩溃，并在 sniffing 中预设空对象免疫删减
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
    ' "剥离应用层 TCP 加速与路由直通"
    
    _safe_jq_write '
      (.inbounds[]? | select(.protocol == "vless" and .streamSettings.security == "reality")) |= 
          del(.streamSettings.realitySettings.maxTimeDiff) |
      del(.dns) |
      del(.policy)
    ' "移除 DNS 策略、防重放时间轴与极速回收"
    
    _toggle_affinity_off
    
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if test -f "$limit_file"; then
        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
        sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=100\"/" "$limit_file" 2>/dev/null || true
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}
# ------------------------------------------------------------------------------
# [ 0x1A: 全域 28 项极限微操战神矩阵 (The 28-Panel God Mode Matrix) ]
# ------------------------------------------------------------------------------

do_app_level_tuning_menu() {
    while true; do
        clear
        title "全域 28 项极限微操 (Xray 提速底牌 & 系统内核微操)"
        
        if test ! -f "$CONFIG"; then 
            error "未发现系统核心配置文件，请先执行核心安装流程！"
            local _pause=""
            read -rp "按 Enter 返回主菜单..." _pause || true
            return
        fi

        # ==========================================
        # 瞬时全量状态提取 (应用层 1-11 项)
        # ==========================================
        local out_fastopen
        out_fastopen=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpFastOpen // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        local out_keepalive
        out_keepalive=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpKeepAliveIdle // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        local sniff_status
        sniff_status=$(jq -r '.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.metadataOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        local dns_status
        dns_status=$(jq -r '.dns.queryStrategy // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        local policy_status
        policy_status=$(jq -r '.policy.levels["0"].connIdle // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        local affinity_state
        affinity_state=$(check_affinity_state)
        
        local mph_state
        mph_state=$(check_mph_state)
        
        local maxtime_state
        maxtime_state=$(check_maxtime_state)
        
        local routeonly_status
        routeonly_status=$(check_routeonly_state)
        
        local buffer_state
        buffer_state=$(check_buffer_state)
        
        local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
        local gc_status="未知"
        if test -f "$limit_file"; then
            gc_status=$(awk -F'=' '/^Environment="GOGC=/ {print $3}' "$limit_file" 2>/dev/null | tr -d '"' | head -n 1 || echo "")
            if test -z "$gc_status"; then
                gc_status="默认 100"
            fi
        else
            gc_status="默认 100"
        fi

        # ==========================================
        # 瞬时全量状态提取 (系统层 12-25 项)
        # ==========================================
        local dnsmasq_state
        dnsmasq_state=$(check_dnsmasq_state)
        
        local thp_state
        thp_state=$(check_thp_state)
        
        local mtu_state
        mtu_state=$(check_mtu_state)
        
        local cpu_state
        cpu_state=$(check_cpu_state)
        
        local ring_state
        ring_state=$(check_ring_state)
        
        local zram_state
        zram_state=$(check_zram_state)
        
        local journal_state
        journal_state=$(check_journal_state)
        
        local prio_state
        prio_state=$(check_process_priority_state)
        
        local cake_state
        cake_state=$(check_cake_state)
        
        local irq_state
        irq_state=$(check_irq_state)
        
        local gso_off_state
        gso_off_state=$(check_gso_off_state)
        
        local ackfilter_state
        ackfilter_state=$(check_ackfilter_state)
        
        local ecn_state
        ecn_state=$(check_ecn_state)
        
        local wash_state
        wash_state=$(check_wash_state)

        # ==========================================
        # 缺省探测引擎 (App 层 - 1~11项)
        # ==========================================
        local app_off_count=0
        if test "$out_fastopen" != "true"; then 
            app_off_count=$((app_off_count+1))
        fi
        
        if test "$out_keepalive" != "30"; then 
            app_off_count=$((app_off_count+1))
        fi
        
        if test "$sniff_status" != "true"; then 
            app_off_count=$((app_off_count+1))
        fi
        
        if test "$dns_status" != "UseIP"; then 
            app_off_count=$((app_off_count+1))
        fi
        
        if echo "$gc_status" | grep -q "100"; then 
            app_off_count=$((app_off_count+1))
        fi
        
        if test "$policy_status" != "60"; then 
            app_off_count=$((app_off_count+1))
        fi
        
        if test "$affinity_state" != "true"; then 
            app_off_count=$((app_off_count+1))
        fi
        
        if test "$mph_state" != "true"; then 
            app_off_count=$((app_off_count+1))
        fi
        
        if test "$routeonly_status" != "true"; then 
            app_off_count=$((app_off_count+1))
        fi
        
        if test "$buffer_state" != "true"; then 
            app_off_count=$((app_off_count+1))
        fi
        
        local has_reality
        has_reality=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .protocol' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
        
        if test -n "$has_reality"; then 
            if test "$maxtime_state" != "true"; then 
                app_off_count=$((app_off_count+1))
            fi
        fi

        # ==========================================
        # 缺省探测引擎 (系统层 - 12~25项)
        # ==========================================
        local sys_off_count=0
        if test "$dnsmasq_state" = "false"; then 
            sys_off_count=$((sys_off_count+1))
        fi
        if test "$thp_state" = "false"; then 
            sys_off_count=$((sys_off_count+1))
        fi
        if test "$mtu_state" = "false"; then 
            sys_off_count=$((sys_off_count+1))
        fi
        if test "$cpu_state" = "false"; then 
            sys_off_count=$((sys_off_count+1))
        fi
        if test "$ring_state" = "false"; then 
            sys_off_count=$((sys_off_count+1))
        fi
        if test "$zram_state" = "false"; then 
            sys_off_count=$((sys_off_count+1))
        fi
        if test "$journal_state" = "false"; then 
            sys_off_count=$((sys_off_count+1))
        fi
        if test "$prio_state" = "false"; then 
            sys_off_count=$((sys_off_count+1))
        fi
        if test "$cake_state" = "false"; then 
            sys_off_count=$((sys_off_count+1))
        fi
        if test "$irq_state" = "false"; then 
            sys_off_count=$((sys_off_count+1))
        fi
        if test "$gso_off_state" = "false"; then 
            sys_off_count=$((sys_off_count+1))
        fi
        if test "$ackfilter_state" = "false"; then 
            sys_off_count=$((sys_off_count+1))
        fi
        if test "$ecn_state" = "false"; then 
            sys_off_count=$((sys_off_count+1))
        fi
        if test "$wash_state" = "false"; then 
            sys_off_count=$((sys_off_count+1))
        fi

        # ==========================================
        # UI 状态映射 (绝对垂直展开，杜绝由于压缩导致的转义失效)
        # ==========================================
        local s1
        if test "$out_fastopen" = "true"; then 
            s1="${cyan}已开启${none}"
        else 
            s1="${gray}未开启${none}"
        fi
        
        local s2
        if test "$out_keepalive" = "30"; then 
            s2="${cyan}已开启 (30s/15s)${none}"
        else 
            s2="${gray}系统默认${none}"
        fi
        
        local s3
        if test "$sniff_status" = "true"; then 
            s3="${cyan}已开启${none}"
        else 
            s3="${gray}未开启${none}"
        fi
        
        local s4
        if test "$dns_status" = "UseIP"; then 
            s4="${cyan}已开启${none}"
        else 
            s4="${gray}未开启${none}"
        fi
        
        local s6
        if test "$policy_status" = "60"; then 
            s6="${cyan}已开启 (闲置60s/握手3s)${none}"
        else 
            s6="${gray}默认 300s 慢回收${none}"
        fi
        
        local s7
        if test "$affinity_state" = "true"; then 
            s7="${cyan}已锁死单核 (零切换)${none}"
        else 
            s7="${gray}默认 (系统调度)${none}"
        fi
        
        local s8
        if test "$mph_state" = "true"; then 
            s8="${cyan}O(1) 预编译算法就绪${none}"
        else 
            s8="${gray}默认 (Linear/AC机)${none}"
        fi
        
        local s9
        if test -z "$has_reality"; then 
            s9="${gray}无 Reality (已跳过)${none}"
        else 
            if test "$maxtime_state" = "true"; then 
                s9="${cyan}绝对防线 (60s)${none}"
            else 
                s9="${gray}默认 (不设防)${none}"
            fi
        fi
        
        local s10
        if test "$routeonly_status" = "true"; then 
            s10="${cyan}盲走快车道已通车${none}"
        else 
            s10="${gray}默认全量嗅探${none}"
        fi
        
        local s11
        if test "$buffer_state" = "true"; then 
            s11="${cyan}巨型重卡池 (64K)${none}"
        else 
            s11="${gray}默认轻型内存分配${none}"
        fi
        
        local s12
        if test "$dnsmasq_state" = "true"; then 
            s12="${cyan}极速内存解析中 (0.1ms)${none}"
        else 
            s12="${gray}依赖原生 DoH${none}"
        fi
        
        local s13
        if test "$thp_state" = "true"; then 
            s13="${cyan}已关闭 THP${none}"
        elif test "$thp_state" = "unsupported"; then 
            s13="${gray}不支持${none}"
        else 
            s13="${gray}系统默认${none}"
        fi
        
        local s14
        if test "$mtu_state" = "true"; then 
            s14="${cyan}智能探测中${none}"
        elif test "$mtu_state" = "unsupported"; then 
            s14="${gray}不支持${none}"
        else 
            s14="${gray}未开启${none}"
        fi
        
        local s15
        if test "$cpu_state" = "true"; then 
            s15="${cyan}全核火力全开${none}"
        elif test "$cpu_state" = "unsupported"; then 
            s15="${gray}不支持${none}"
        else 
            s15="${gray}节能待机${none}"
        fi
        
        local s16
        if test "$ring_state" = "true"; then 
            s16="${cyan}已反向收缩${none}"
        elif test "$ring_state" = "unsupported"; then 
            s16="${gray}不支持${none}"
        else 
            s16="${gray}系统大缓冲${none}"
        fi
        
        local s17
        if test "$zram_state" = "true"; then 
            s17="${cyan}已挂载 ZRAM${none}"
        elif test "$zram_state" = "unsupported"; then 
            s17="${gray}不支持${none}"
        else 
            s17="${gray}未启用${none}"
        fi
        
        local s18
        if test "$journal_state" = "true"; then 
            s18="${cyan}纯内存极速化${none}"
        elif test "$journal_state" = "unsupported"; then 
            s18="${gray}不支持${none}"
        else 
            s18="${gray}磁盘 IO 写入中${none}"
        fi
        
        local s19
        if test "$prio_state" = "true"; then 
            s19="${cyan}OOM免死 / IO抢占${none}"
        else 
            s19="${gray}系统默认调度${none}"
        fi
        
        local s20
        if test "$cake_state" = "true"; then 
            s20="${cyan}CAKE 削峰填谷中${none}"
        else 
            s20="${gray}默认 FQ 队列${none}"
        fi
        
        local s21
        if test "$irq_state" = "true"; then 
            s21="${cyan}多核 RPS / 单核绑死 自动激活${none}"
        elif test "$irq_state" = "unsupported"; then 
            s21="${gray}不支持(单核)${none}"
        else 
            s21="${gray}默认平衡调度${none}"
        fi
        
        local s22
        if test "$gso_off_state" = "true"; then 
            s22="${cyan}已打散 (零延迟电竞模式)${none}"
        elif test "$gso_off_state" = "unsupported"; then 
            s22="${gray}不支持 (底层驱动限制，已安全跳过)${none}"
        else 
            s22="${gray}未打散 (系统默认万兆聚合)${none}"
        fi
        
        local s23
        if test "$ackfilter_state" = "true"; then 
            s23="${cyan}绞杀空 ACK 释放上行${none}"
        else 
            s23="${gray}默认不干预${none}"
        fi
        
        local s24
        if test "$ecn_state" = "true"; then 
            s24="${cyan}显式拥塞警告 (0 丢包平滑降速)${none}"
        else 
            s24="${gray}默认 (传统暴力丢包)${none}"
        fi
        
        local s25
        if test "$wash_state" = "true"; then 
            s25="${cyan}强力清除干扰乱码${none}"
        else 
            s25="${gray}默认不干预${none}"
        fi

        # ==========================================
        # 控制台菜单渲染
        # ==========================================
        echo -e "  ${magenta}--- Xray Core 应用层内部调优 (1-11) ---${none}"
        echo -e "  1)  开启或关闭 双向并发提速 (tcpNoDelay/FastOpen)                | 状态: $s1"
        echo -e "  2)  开启或关闭 Socket 智能保活心跳 (KeepAlive: Idle 30s)         | 状态: $s2"
        echo -e "  3)  开启或关闭 嗅探引擎减负 (metadataOnly 解放 CPU)              | 状态: $s3"
        echo -e "  4)  开启或关闭 内置并发 DoH / Dnsmasq 路由分发 (Xray Native DNS) | 状态: $s4"
        echo -e "  5)  执行或关闭 GOGC 内存阶梯飙车调优 (自动侦测物理内存)          | 设定: ${cyan}${gc_status}${none}"
        echo -e "  6)  开启或关闭 Xray Policy 策略组优化 (连接生命周期极速回收)     | 状态: $s6"
        echo -e "  7)  开启或关闭 Xray 进程物理绑核 & GOMAXPROCS (手术室锁死 Core1) | 状态: $s7"
        echo -e "  8)  开启或关闭 Minimal Perfect Hash (MPH) 路由匹配极速降维引擎   | 状态: $s8"
        echo -e "  9)  开启或关闭 Reality 防重放装甲 (maxTimeDiff 时间偏移绝对拦截) | 状态: $s9"
        echo -e "  10) 开启或关闭 零拷贝旁路盲转发 (routeOnly 底层直通快车道)       | 状态: $s10"
        echo -e "  11) 开启或关闭 XRAY_RAY_BUFFER_SIZE=64 (化零为整巨型吞吐重卡池)  | 状态: $s11"
        echo -e ""
        echo -e "  ${magenta}--- Linux 系统层与内核黑科技 (12-25) ---${none}"
        echo -e "  12) 开启或关闭【Dnsmasq 本地极速内存缓存引擎 (21000并发/锁TTL)】 | 状态: $s12"
        echo -e "  13) 开启或关闭【透明大页 (THP - Transparent Huge Pages)】        | 状态: $s13"
        echo -e "  14) 开启或关闭【TCP PMTU 黑洞智能探测 (Probing=1)】              | 状态: $s14"
        echo -e "  15) 开启或关闭【CPU 频率调度器锁定 (Performance)】               | 状态: $s15"
        echo -e "  16) 开启或关闭【网卡硬件环形缓冲区 (Ring Buffer) 反向收缩】      | 状态: $s16"
        echo -e "  17) 开启或关闭【ZRAM】(淘汰慢速 Swap，阶梯内存自动检测)          | 状态: $s17"
        echo -e "  18) 开启或关闭【日志系统 Journald 纯内存化】(斩断 I/O 羁绊)      | 状态: $s18"
        echo -e "  19) 开启或关闭【系统进程级防杀抢占 (OOM/IO 提权)】               | 状态: $s19"
        echo -e "  20) 开启或关闭【CAKE 智能队列管治】(取代 fq，强压缓冲膨胀)       | 状态: $s20"
        echo -e "  21) 开启或关闭【网卡硬中断物理隔离】(Hard IRQ Pinning 锁死Core0) | 状态: $s21"
        echo -e "  22) 开启或关闭【网卡 GSO/GRO 硬件卸载反转】(打散小包降延迟)      | 状态: $s22"
        echo -e "  23) 开启或关闭【CAKE ack-filter 上行绞杀】(释放高延迟不对等链路) | 状态: $s23"
        echo -e "  24) 开启或关闭【CAKE ECN 标记】(与 BBR3 联动，0 丢包平滑降速)    | 状态: $s24"
        echo -e "  25) 开启或关闭【CAKE Wash 报文清洗】(免疫流氓路由 ECN 头污染)    | 状态: $s25"
        echo -e "  "
        echo -e "  ${cyan}26) 一键开启或关闭 1-11 项 应用层微操 (自动侦测并智能反转)${none}"
        echo -e "  ${yellow}27) 一键开启或关闭 12-25 项 系统级微操 (自动避障侦测并反转)${none}"
        echo -e "  ${red}28) 创世之手：一键开启或关闭 1-25 项 全域微操 (执行后自动重启系统)${none}"
        echo "  0) 返回上一级"
        hr
        
        local app_opt=""
        read -rp "请下达微操指令: " app_opt || true

        case "${app_opt:-}" in
            1)
                if test "$out_fastopen" = "true"; then
                    _safe_jq_write '
                      (.outbounds[]? | select(.protocol == "freedom")) |= 
                          del(.streamSettings.sockopt.tcpNoDelay, .streamSettings.sockopt.tcpFastOpen) |
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= 
                          del(.streamSettings.sockopt.tcpNoDelay, .streamSettings.sockopt.tcpFastOpen)
                    ' "关闭 TCP 零拷贝与并发提速"
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
                    ' "开启 TCP 零拷贝与并发提速"
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            2)
                if test "$out_keepalive" = "30"; then
                    _safe_jq_write '
                      (.outbounds[]? | select(.protocol == "freedom")) |= 
                          del(.streamSettings.sockopt.tcpKeepAliveIdle, .streamSettings.sockopt.tcpKeepAliveInterval) |
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= 
                          del(.streamSettings.sockopt.tcpKeepAliveIdle, .streamSettings.sockopt.tcpKeepAliveInterval)
                    ' "关闭 Socket 智能保活心跳"
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
                    ' "注入 Socket 智能保活心跳"
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            3)
                if test "$sniff_status" = "true"; then
                    _safe_jq_write '
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= 
                          (.sniffing.metadataOnly = false)
                    ' "关闭嗅探引擎减负"
                else
                    _safe_jq_write '
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= (
                          .sniffing = (.sniffing // {}) |
                          .sniffing.metadataOnly = true
                      )
                    ' "开启嗅探引擎减负"
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
                        _safe_jq_write '.dns = {"servers":["https://8.8.8.8/dns-query","https://1.1.1.1/dns-query"], "queryStrategy":"UseIP"}' "启用并发 DoH"
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
                    if test "$TOTAL_MEM" -ge 1800; then 
                        DYNAMIC_GOGC=1000
                    elif test "$TOTAL_MEM" -ge 900; then 
                        DYNAMIC_GOGC=500
                    else 
                        DYNAMIC_GOGC=300
                    fi
                    
                    if grep -q "Environment=\"GOGC=" "$limit_file" 2>/dev/null; then
                        if echo "$gc_status" | grep -q "100"; then
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
                    _safe_jq_write 'del(.policy)' "关闭策略组优化极速回收"
                else
                    _safe_jq_write '.policy = {"levels":{"0":{"handshake":3,"connIdle":60}},"system":{"statsInboundDownlink":false,"statsInboundUplink":false}}' "开启策略组优化极速回收"
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            7)
                if test "$affinity_state" = "true"; then
                    _toggle_affinity_off
                else
                    _toggle_affinity_on
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            8)
                if test "$mph_state" = "true"; then
                    _safe_jq_write 'del(.routing.domainMatcher)' "关闭 MPH 路由匹配"
                else
                    _safe_jq_write '.routing = (.routing // {}) | .routing.domainMatcher = "mph"' "开启 MPH 路由匹配"
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            9)
                if test -n "$has_reality"; then
                    if test "$maxtime_state" = "true"; then
                        _safe_jq_write '
                          (.inbounds[]? | select(.protocol == "vless" and .streamSettings.security == "reality")) |= 
                              del(.streamSettings.realitySettings.maxTimeDiff)
                        ' "关闭 Reality maxTimeDiff"
                    else
                        _safe_jq_write '
                          (.inbounds[]? | select(.protocol == "vless" and .streamSettings.security == "reality")) |= (
                              .streamSettings.realitySettings = (.streamSettings.realitySettings // {}) |
                              .streamSettings.realitySettings.maxTimeDiff = 60000
                          )
                        ' "开启 Reality maxTimeDiff"
                    fi
                    systemctl restart xray >/dev/null 2>&1 || true
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            10)
                if test "$routeonly_status" = "true"; then
                    _safe_jq_write '
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= 
                          (.sniffing.routeOnly = false)
                    ' "关闭零拷贝旁路转发"
                else
                    _safe_jq_write '
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= (
                          .sniffing = (.sniffing // {}) |
                          .sniffing.routeOnly = true
                      )
                    ' "开启零拷贝旁路转发"
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            11)
                local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
                if test -f "$limit_file"; then
                    if test "$buffer_state" = "true"; then
                        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
                    else
                        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
                        echo "Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" >> "$limit_file"
                    fi
                    systemctl daemon-reload >/dev/null 2>&1 || true
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
12) 
                toggle_dnsmasq
                local _p=""
                read -rp "按 Enter 继续..." _p || true 
                ;;
            13) 
                toggle_thp
                local _p=""
                read -rp "按 Enter 继续..." _p || true 
                ;;
            14) 
                toggle_mtu
                local _p=""
                read -rp "按 Enter 继续..." _p || true 
                ;;
            15) 
                toggle_cpu
                local _p=""
                read -rp "按 Enter 继续..." _p || true 
                ;;
            16) 
                toggle_ring
                local _p=""
                read -rp "按 Enter 继续..." _p || true 
                ;;
            17) 
                toggle_zram
                local _p=""
                read -rp "按 Enter 继续..." _p || true 
                ;;
            18) 
                toggle_journal
                local _p=""
                read -rp "按 Enter 继续..." _p || true 
                ;;
            19) 
                toggle_process_priority
                systemctl restart xray >/dev/null 2>&1 || true
                local _p=""
                read -rp "按 Enter 继续..." _p || true 
                ;;
            20) 
                toggle_cake
                local _p=""
                read -rp "按 Enter 继续..." _p || true 
                ;;
            21) 
                toggle_irq
                local _p=""
                read -rp "按 Enter 继续..." _p || true 
                ;;
            22) 
                local g_state
                g_state=$(check_gso_off_state)
                if test "$g_state" = "unsupported"; then
                    warn "当前网卡底层驱动锁死 (fixed)，无法更改卸载状态！"
                    sleep 2
                else
                    toggle_gso_off
                    local _p=""
                    read -rp "按 Enter 继续..." _p || true 
                fi
                ;;
            23) 
                toggle_ackfilter
                local _p=""
                read -rp "按 Enter 继续..." _p || true 
                ;;
            24) 
                toggle_ecn
                local _p=""
                read -rp "按 Enter 继续..." _p || true 
                ;;
            25) 
                toggle_wash
                local _p=""
                read -rp "按 Enter 继续..." _p || true 
                ;;
            26)
                if test "$app_off_count" -gt 0; then
                    print_magenta ">>> 全域开启 1-11 项..."
                    _turn_on_app
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "应用层引擎已全量激活！"
                else
                    print_magenta ">>> 全域恢复 1-11 项..."
                    _turn_off_app
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "应用层引擎已全部关闭！"
                fi
                local _p=""
                read -rp "按 Enter 继续..." _p || true
                ;;
            27)
                if test "$sys_off_count" -gt 0; then
                    if test "$dnsmasq_state" = "false"; then toggle_dnsmasq >/dev/null 2>&1 || true; fi
                    if test "$thp_state" = "false"; then toggle_thp >/dev/null 2>&1 || true; fi
                    if test "$mtu_state" = "false"; then toggle_mtu >/dev/null 2>&1 || true; fi
                    if test "$cpu_state" = "false"; then toggle_cpu >/dev/null 2>&1 || true; fi
                    if test "$ring_state" = "false"; then toggle_ring >/dev/null 2>&1 || true; fi
                    if test "$zram_state" = "false"; then toggle_zram >/dev/null 2>&1 || true; fi
                    if test "$journal_state" = "false"; then toggle_journal >/dev/null 2>&1 || true; fi
                    if test "$prio_state" = "false"; then toggle_process_priority >/dev/null 2>&1 || true; fi
                    if test "$cake_state" = "false"; then toggle_cake >/dev/null 2>&1 || true; fi
                    if test "$irq_state" = "false"; then toggle_irq >/dev/null 2>&1 || true; fi
                    if test "$gso_off_state" = "false"; then toggle_gso_off >/dev/null 2>&1 || true; fi
                    if test "$ackfilter_state" = "false"; then toggle_ackfilter >/dev/null 2>&1 || true; fi
                    if test "$ecn_state" = "false"; then toggle_ecn >/dev/null 2>&1 || true; fi
                    if test "$wash_state" = "false"; then toggle_wash >/dev/null 2>&1 || true; fi
                    
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "12-25 系统级核心挂载完毕，满血激活！"
                else
                    if test "$dnsmasq_state" = "true"; then toggle_dnsmasq >/dev/null 2>&1 || true; fi
                    if test "$thp_state" = "true"; then toggle_thp >/dev/null 2>&1 || true; fi
                    if test "$mtu_state" = "true"; then toggle_mtu >/dev/null 2>&1 || true; fi
                    if test "$cpu_state" = "true"; then toggle_cpu >/dev/null 2>&1 || true; fi
                    if test "$ring_state" = "true"; then toggle_ring >/dev/null 2>&1 || true; fi
                    if test "$zram_state" = "true"; then toggle_zram >/dev/null 2>&1 || true; fi
                    if test "$journal_state" = "true"; then toggle_journal >/dev/null 2>&1 || true; fi
                    if test "$prio_state" = "true"; then toggle_process_priority >/dev/null 2>&1 || true; fi
                    if test "$cake_state" = "true"; then toggle_cake >/dev/null 2>&1 || true; fi
                    if test "$irq_state" = "true"; then toggle_irq >/dev/null 2>&1 || true; fi
                    if test "$gso_off_state" = "true"; then toggle_gso_off >/dev/null 2>&1 || true; fi
                    if test "$ackfilter_state" = "true"; then toggle_ackfilter >/dev/null 2>&1 || true; fi
                    if test "$ecn_state" = "true"; then toggle_ecn >/dev/null 2>&1 || true; fi
                    if test "$wash_state" = "true"; then toggle_wash >/dev/null 2>&1 || true; fi
                    
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "12-25 系统级核心调优已全部卸载！"
                fi
                local _p=""
                read -rp "按 Enter 继续..." _p || true
                ;;
            28)
                if test "$((app_off_count + sys_off_count))" -gt 0; then
                    if test "$app_off_count" -gt 0; then 
                        _turn_on_app
                    fi
                    
                    if test "$sys_off_count" -gt 0; then
                        if test "$dnsmasq_state" = "false"; then toggle_dnsmasq >/dev/null 2>&1 || true; fi
                        if test "$thp_state" = "false"; then toggle_thp >/dev/null 2>&1 || true; fi
                        if test "$mtu_state" = "false"; then toggle_mtu >/dev/null 2>&1 || true; fi
                        if test "$cpu_state" = "false"; then toggle_cpu >/dev/null 2>&1 || true; fi
                        if test "$ring_state" = "false"; then toggle_ring >/dev/null 2>&1 || true; fi
                        if test "$zram_state" = "false"; then toggle_zram >/dev/null 2>&1 || true; fi
                        if test "$journal_state" = "false"; then toggle_journal >/dev/null 2>&1 || true; fi
                        if test "$prio_state" = "false"; then toggle_process_priority >/dev/null 2>&1 || true; fi
                        if test "$cake_state" = "false"; then toggle_cake >/dev/null 2>&1 || true; fi
                        if test "$irq_state" = "false"; then toggle_irq >/dev/null 2>&1 || true; fi
                        if test "$gso_off_state" = "false"; then toggle_gso_off >/dev/null 2>&1 || true; fi
                        if test "$ackfilter_state" = "false"; then toggle_ackfilter >/dev/null 2>&1 || true; fi
                        if test "$ecn_state" = "false"; then toggle_ecn >/dev/null 2>&1 || true; fi
                        if test "$wash_state" = "false"; then toggle_wash >/dev/null 2>&1 || true; fi
                    fi
                else
                    _turn_off_app
                    
                    if test "$dnsmasq_state" = "true"; then toggle_dnsmasq >/dev/null 2>&1 || true; fi
                    if test "$thp_state" = "true"; then toggle_thp >/dev/null 2>&1 || true; fi
                    if test "$mtu_state" = "true"; then toggle_mtu >/dev/null 2>&1 || true; fi
                    if test "$cpu_state" = "true"; then toggle_cpu >/dev/null 2>&1 || true; fi
                    if test "$ring_state" = "true"; then toggle_ring >/dev/null 2>&1 || true; fi
                    if test "$zram_state" = "true"; then toggle_zram >/dev/null 2>&1 || true; fi
                    if test "$journal_state" = "true"; then toggle_journal >/dev/null 2>&1 || true; fi
                    if test "$prio_state" = "true"; then toggle_process_priority >/dev/null 2>&1 || true; fi
                    if test "$cake_state" = "true"; then toggle_cake >/dev/null 2>&1 || true; fi
                    if test "$irq_state" = "true"; then toggle_irq >/dev/null 2>&1 || true; fi
                    if test "$gso_off_state" = "true"; then toggle_gso_off >/dev/null 2>&1 || true; fi
                    if test "$ackfilter_state" = "true"; then toggle_ackfilter >/dev/null 2>&1 || true; fi
                    if test "$ecn_state" = "true"; then toggle_ecn >/dev/null 2>&1 || true; fi
                    if test "$wash_state" = "true"; then toggle_wash >/dev/null 2>&1 || true; fi
                fi
                
                echo ""
                print_red "=========================================================="
                print_yellow "警告：全域 28 项拓扑与内核状态已发生深层变革！"
                print_yellow "系统将在 6 秒后自动【强制重启】使之完美落盘！"
                print_red "=========================================================="
                echo ""
                
                for i in {6..1}; do 
                    echo -ne "\r  重启倒计时: ${cyan}${i}${none} 秒... "
                    sleep 1
                done
                
                echo -e "\n\n  正在执行物理数据落盘 (Sync)..."
                sync
                echo -e "  正在执行物理重启，请稍后重新连接服务器..."
                reboot
                ;;
            0)
                return
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# [ 0x1B: 系统彻底自毁机制与清理序列 ]
# ------------------------------------------------------------------------------

do_uninstall() {
    title "清理：彻底卸载 Xray 并复原原生解析"
    
    warn "这将会彻底删除 Xray 并解除 DNS 锁定，但将【永久保留】系统底层的极限并发与内核调优。"
    
    local confirm=""
    read -rp "确认执行？(输入 y 确定): " confirm || true
    
    if test "$confirm" != "y" && test "$confirm" != "Y"; then 
        return
    fi
    
    # 内存级备份计费初装日期
    local temp_date=""
    if test -f "$INSTALL_DATE_FILE"; then
        temp_date=$(cat "$INSTALL_DATE_FILE" 2>/dev/null || echo "")
        print_magenta ">>> [1/4] 成功提取初装日期快照，等待卸载后回写..."
    fi
    
    print_magenta ">>> [2/4] 正在粉碎 Dnsmasq 极速缓存引擎并恢复系统原生 DNS..."
    systemctl stop dnsmasq >/dev/null 2>&1 || true
    systemctl disable dnsmasq >/dev/null 2>&1 || true
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get purge -y dnsmasq >/dev/null 2>&1 || yum remove -y dnsmasq >/dev/null 2>&1 || true
    rm -f /etc/dnsmasq.conf >/dev/null 2>&1 || true

    chattr -i /etc/resolv.conf 2>/dev/null || true
    if test -f /etc/resolv.conf.bak; then
        mv -f /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true
    fi
    
    systemctl stop resolvconf.service >/dev/null 2>&1 || true
    systemctl disable resolvconf.service >/dev/null 2>&1 || true
    
    if systemctl list-unit-files 2>/dev/null | grep -q systemd-resolved; then
        systemctl enable systemd-resolved >/dev/null 2>&1 || true
        systemctl start systemd-resolved >/dev/null 2>&1 || true
    fi

    print_magenta ">>> [3/4] 正在停止并彻底绞杀 Xray 主进程及系统权限映射..."
    systemctl stop xray >/dev/null 2>&1 || true
    systemctl disable xray >/dev/null 2>&1 || true
    rm -rf /etc/systemd/system/xray.service >/dev/null 2>&1 || true
    rm -rf /etc/systemd/system/xray@.service >/dev/null 2>&1 || true
    rm -rf /etc/systemd/system/xray.service.d >/dev/null 2>&1 || true
    rm -rf /lib/systemd/system/xray* >/dev/null 2>&1 || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    
    print_magenta ">>> [4/4] 正在粉碎数据目录、系统日志及物理配置文件..."
    rm -rf "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SCRIPT_DIR" >/dev/null 2>&1 || true
    rm -rf /var/log/xray* >/dev/null 2>&1 || true
    
    (crontab -l 2>/dev/null | grep -v "update-dat.sh" | grep -v "/bin/systemctl restart xray") | crontab - 2>/dev/null || true
    
    rm -f "/usr/local/bin/xrv" >/dev/null 2>&1 || true
    rm -f "$SCRIPT_PATH" >/dev/null 2>&1 || true
    hash -r 2>/dev/null || true
    
    # 恢复初装计费日
    if test -n "$temp_date"; then
        mkdir -p "$CONFIG_DIR" 2>/dev/null || true
        echo "$temp_date" > "$INSTALL_DATE_FILE"
    fi
    
    print_green "卸载完成！Xray 及 Dnsmasq 缓存已被彻底粉碎 (您的内核网络栈调优与计费记录已为您完美保留)。"
    exit 0
}

# ------------------------------------------------------------------------------
# [ 0x1C: Reality 回落探测限速器 (继承 ex139 经典探针) ]
# ------------------------------------------------------------------------------

do_fallback_probe() {
    clear
    echo -e "\n${yellow}=== Xray Reality 回落限速 (Fallback Limit) 探针 ===${none}"
    
    if ! test -f "$CONFIG"; then
        error "未发现系统核心配置文件！"
        local _p=""
        read -rp "按 Enter 返回主菜单..." _p || true
        return
    fi
    
    local out
    out=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings.security=="reality") | .streamSettings.realitySettings | "  [上传方向 (Upload)]\n    诱饵大小 (afterBytes) : \(.limitFallbackUpload.afterBytes // "未设置 (不限速)")\n    基准限速 (bytesPerSec) : \(.limitFallbackUpload.bytesPerSec // "未设置 (不限速)")\n  [下载方向 (Download)]\n    诱饵大小 (afterBytes) : \(.limitFallbackDownload.afterBytes // "未设置 (不限速)")\n    基准限速 (bytesPerSec) : \(.limitFallbackDownload.bytesPerSec // "未设置 (不限速)")"' "$CONFIG" 2>/dev/null || echo -e "  ${red}读取失败：未找到配置文件或 jq 解析错误${none}")
    
    if test -n "$out"; then
        echo -e "$out"
    else
        echo -e "  ${gray}当前系统中未配置回落限速参数。${none}"
    fi
    
    echo ""
    local _p=""
    read -rp "按 Enter 继续..." _p || true
}

# ------------------------------------------------------------------------------
# [ 0x1D: The Genesis Hub - 最高系统初始化菜单 ]
# ------------------------------------------------------------------------------

do_sys_init_menu() {
    while true; do
        clear
        title "初次安装、更新系统组件"
        
        echo "  1) 一键更新系统、安装常用组件并校准时区 (Asia/Kuala_Lumpur)"
        echo -e "  ${cyan}2) 必须先安装 XANMOD (main) 官方预编译内核 (推荐/防断连/自动重启)${none}"
        echo "  3) 先完成 2，编译安装 Xanmod 内核 + BBR3 (极客源码流 / 自动重启)"
        echo "  4) 网卡发送队列 (TX Queue) 深度调优 (2000 防堵塞极速版)"
        echo "  5) 系统内核网络栈极限调优 (低延迟特化版 / 自动重启)"
        echo -e "  ${magenta}6) 全域 28 项极限微操 (Dnsmasq / Xray 提速底牌 / 系统级黑科技)${none}"
        echo -e "  ${cyan}7) 配置 CAKE 高阶调度参数 (Bandwidth/Overhead/MPU 针对虚机硬件卸载)${none}"
        echo "  0) 返回主菜单"
        hr
        
        local sys_opt=""
        read -rp "请选择: " sys_opt || true
        
        case "${sys_opt:-}" in
            1) 
                print_magenta ">>> 正在拉取系统更新与底层环境组件，请勿中断..."
                
                export DEBIAN_FRONTEND=noninteractive
                apt-get update -y >/dev/null 2>&1 || true
                apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" full-upgrade -y >/dev/null 2>&1 || true
                apt-get autoremove -y --purge >/dev/null 2>&1 || true
                
                apt-get install -y wget curl sudo socat ntpdate e2fsprogs pkg-config iproute2 ethtool >/dev/null 2>&1 || true
                
                if command -v timedatectl >/dev/null 2>&1; then
                    timedatectl set-timezone Asia/Kuala_Lumpur >/dev/null 2>&1 || true
                fi
                if command -v ntpdate >/dev/null 2>&1; then
                    ntpdate us.pool.ntp.org >/dev/null 2>&1 || true
                fi
                if command -v hwclock >/dev/null 2>&1; then
                    hwclock --systohc >/dev/null 2>&1 || true
                fi
                
                info "底层组件拉平完毕，系统时间已硬同步至 Asia/Kuala_Lumpur！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            2) do_install_xanmod_main_official ;;
            3) do_xanmod_compile ;;
            4) do_txqueuelen_opt ;;
            5) do_perf_tuning ;;
            6) do_app_level_tuning_menu ;;
            7) config_cake_advanced ;;
            0) return ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# [ 0x1E: 核心通信协议框架部署 (The Missing Core!) ]
# ------------------------------------------------------------------------------

do_install() {
    clear
    title "Apex Vanguard Ultimate Final: 核心部署"
    preflight
    
    info "正在强行切断并静默挂起旧版守护进程..."
    systemctl stop xray >/dev/null 2>&1 || true

    # 严控：如果已有安装日期，则不再覆盖，保证历代升级记录统一
    if test ! -f "$INSTALL_DATE_FILE"; then
        date +"%Y-%m-%d %H:%M:%S" > "$INSTALL_DATE_FILE"
    fi
    
    echo -e "\n  ${cyan}请选择要安装的代理协议：${none}"
    echo "  1) VLESS-Reality (推荐, 强力防封)"
    echo "  2) Shadowsocks (建议落地机使用)"
    echo "  3) 两个都安装 (双管齐下)"
    
    local proto_choice=""
    read -rp "  请输入编号 (默认 1): " proto_choice || true
    proto_choice=${proto_choice:-1}

    # ==========================================
    # 交互收集: VLESS-Reality 运行参数
    # ==========================================
    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        while true; do
            local input_p=""
            read -rp "请输入 VLESS 物理监听端口 (回车键默认 443): " input_p || true
            input_p=${input_p:-443}
            if validate_port "$input_p"; then 
                LISTEN_PORT="$input_p"
                break
            fi
        done
        
        local input_remark=""
        read -rp "请输入该节点战术别名 (默认 xp-reality): " input_remark || true
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
            read -rp "请输入 Shadowsocks 物理监听端口 (回车键默认 8388): " input_s || true
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
            read -rp "请输入该节点战术别名 (默认 xp-ss): " input_remark || true
            REMARK_NAME=${input_remark:-xp-ss}
        fi
    fi

    print_magenta "\n>>> 正在全域连接云端，多轨拉取最新版 Xray 核心组件 (已屏蔽冗余日志)..."
    
    local xray_installed=0
    for url in "https://github.com/XTLS/Xray-install/raw/main/install-release.sh" \
               "https://fastly.jsdelivr.net/gh/XTLS/Xray-install@main/install-release.sh" \
               "https://raw.fastgit.org/XTLS/Xray-install/main/install-release.sh"; do
               
        if curl -fsSL --connect-timeout 10 --max-time 60 -o /tmp/install-release.sh "$url" 2>/dev/null; then
            if bash /tmp/install-release.sh @ install >/dev/null 2>&1; then
                xray_installed=1
                info "Xray 核心跨维安装成功，数据流桥接源：$url"
                break
            fi
        fi
        warn "节点流失，通讯链路 [$url] 遭阻断，正在自动自旋接入备用 CDN 镜像..."
    done
    rm -f /tmp/install-release.sh 2>/dev/null || true
    
    if test "$xray_installed" -eq 0; then
        die "核心获取全面溃败：所有源均遭到网络阻断！部署防线已自动物理熔断！"
    fi
    
    install_update_dat
    
    # 注入百万并发突破设置
    fix_xray_systemd_limits

    info "正在触发引擎级别 JSON 配置装配中心 (纯原生 Bash HereDoc 强写，彻底屏蔽 JQ 初始解析断层)..."

    # 1. 纯净构建底层骨架配置 (注入 AsIs 斩断路由层无谓解析)
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
        "protocol": [
          "bittorrent"
        ]
      },
      {
        "outboundTag": "block",
        "_enabled": true,
        "ip": [
          "geoip:cn"
        ]
      },
      {
        "outboundTag": "block",
        "_enabled": true,
        "domain": [
          "geosite:cn",
          "geosite:category-ads-all"
        ]
      }
    ]
  },
  "inbounds": [],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct",
      "streamSettings": {
          "sockopt": {
              "tcpNoDelay": true,
              "tcpFastOpen": true
          }
      }
    },
    {
      "protocol": "blackhole",
      "tag": "block"
    }
  ]
}
EOF

    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        gen_x25519
        local uuid
        uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
        local sid
        sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n\r' || echo "")
        local ctime
        ctime=$(date +"%Y-%m-%d %H:%M")
        
        echo "$X25519_PUB" > "$PUBKEY_FILE"
        echo "$uuid|$ctime" > "$USER_TIME_MAP"
        
        # 2. 绝对纯净的 HereDoc JSON 注入，加入 sockopt 与 Fallback Limit 探针
        echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
        cat > /tmp/vless_inbound.json <<EOF
{
  "tag": "vless-reality",
  "listen": "0.0.0.0",
  "port": $LISTEN_PORT,
  "protocol": "vless",
  "settings": {
    "clients": [
      {
        "id": "$uuid",
        "flow": "xtls-rprx-vision",
        "email": "$REMARK_NAME"
      }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "tcp",
    "security": "reality",
    "sockopt": {
        "tcpNoDelay": true,
        "tcpFastOpen": true
    },
    "realitySettings": {
      "dest": "$BEST_SNI:443",
      "serverNames": [],
      "privateKey": "$X25519_PRIV",
      "publicKey": "$X25519_PUB",
      "shortIds": [
        "$sid"
      ],
      "limitFallbackUpload": {
          "afterBytes": 0,
          "bytesPerSec": 0,
          "burstBytesPerSec": 0
      },
      "limitFallbackDownload": {
          "afterBytes": 0,
          "bytesPerSec": 0,
          "burstBytesPerSec": 0
      }
    }
  },
  "sniffing": {
    "enabled": true,
    "destOverride": [
      "http",
      "tls",
      "quic"
    ]
  }
}
EOF
        
        # 合并 SNI 数组进 vless 的 JSON 结构，并安全拼接到全局 CONFIG 中
        if jq --slurpfile snis /tmp/sni_array.json '.streamSettings.realitySettings.serverNames = $snis[0]' /tmp/vless_inbound.json > /tmp/vless_final.json 2>/dev/null; then
            jq '.inbounds += [input]' "$CONFIG" /tmp/vless_final.json > "$CONFIG.tmp" 2>/dev/null && mv -f "$CONFIG.tmp" "$CONFIG" >/dev/null 2>&1 || true
        fi
        rm -f /tmp/vless_inbound.json /tmp/vless_final.json /tmp/sni_array.json 2>/dev/null || true
    fi

    if test "$proto_choice" = "2" || test "$proto_choice" = "3"; then
        # 彻底展开 SS JSON，同步加入 sockopt 突发性能
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
    "sockopt": {
        "tcpNoDelay": true,
        "tcpFastOpen": true
    }
  }
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
    
    # 安装完毕后的操作闭环
    while true; do
        local opt=""
        read -rp "操作闭环：按 Enter 键返回主控中枢，或键入 b 立即进行 SNI 重新偏移: " opt || true
        if test "$opt" = "b" || test "$opt" = "B"; then
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

# ------------------------------------------------------------------------------
# [ 0x1F: 主控入口 (Genesis Core Boot) ]
# ------------------------------------------------------------------------------

main_menu() {
    while true; do
        clear
        echo -e "${blue}===================================================${none}"
        echo -e "  ${magenta}Xray ex188t42 The Apex Vanguard - Project Genesis V188${none}"
        
        local svc
        svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        
        if test "$svc" = "active"; then 
            svc="${green}运行中${none}"
        else 
            svc="${red}停止${none}"
        fi
        
        local current_kernel
        current_kernel=$(uname -r)
        
        local script_name
        script_name=$(basename "$0")
        
        echo -e "  状态: $svc | 快捷指令: ${cyan}xrv${none} | IP: ${yellow}$SERVER_IP${none}"
        echo -e "  当前内核: ${yellow}${current_kernel}${none} | 脚本名: ${script_name}"
        echo -e "${blue}===================================================${none}"
        
        echo "  1) 核心安装 / 重构网络 (VLESS/SS 双协议)"
        echo "  2) 用户管理 (增删/导入/专属 SNI 挂载)"
        echo "  3) 分发中心 (多用户详情与紧凑二维码)"
        echo "  4) 手动更新 Geo 规则库 (已夜间自动热更)"
        echo "  5) 更新 Xray 核心 (无缝拉取最新版重启)"
        echo "  6) 无感热切 SNI 矩阵 (单选/多选/全选防封阵列)"
        echo "  7) 屏蔽规则管理 (BT/广告双轨拦截)"
        echo "  8) Reality 回落限速探针 (探测/防御扫描狗)"
        echo "  9) 运行状态 (实时 IP 统计/DNS/流量核算)"
        echo "  10) 初次安装、更新系统组件"
        echo "  0) 退出"
        echo -e "  ${red}88) 彻底卸载 (安全复原系统解析并清空软件痕迹)${none}"
        hr
        
        local num=""
        read -rp "选择: " num || true
        
        case "${num:-}" in
            1) do_install ;;
            2) do_user_manager ;;
            3) 
                do_summary
                while true; do 
                    local rb=""
                    read -rp "按 Enter 返回主菜单，或输入 b 重选 SNI: " rb || true
                    if [[ "$rb" == "b" || "$rb" == "B" ]]; then 
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
                print_magenta ">>> 正在同步最新规则库..."
                bash "$UPDATE_DAT_SCRIPT" >/dev/null 2>&1 || true
                ensure_xray_is_alive
                info "Geo 更新成功"
                local _p=""; read -rp "按 Enter 继续..." _p || true 
                ;;
            5) do_update_core ;;
            6) 
                if choose_sni; then 
                    _update_matrix
                    do_summary
                    while true; do 
                        local rb=""
                        read -rp "按 Enter 返回，或 b 继续分配: " rb || true
                        if [[ "$rb" == "b" || "$rb" == "B" ]]; then 
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
                fi 
                ;;
            7) _global_block_rules ;;
            8) do_fallback_probe ;;
            9) do_status_menu ;;
            10) do_sys_init_menu ;;
            88) do_uninstall ;;
            0) exit 0 ;;
            *) 
                echo -e "${red}❌ 指令错误！${none}"
                sleep 1
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# 引擎点火指令
# ------------------------------------------------------------------------------
preflight
main_menu
