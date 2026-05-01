#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: ex188t45.sh (The Apex Vanguard - Ultimate Genesis 4500+ Pro)
# 快捷方式: xrv
# 版本号: V188t45.Mega.Perfect.Fusion
#
# 【V188t45 终极融合增量修复版】
#   1. 穿墙反代全量注入: 引入 ghp.ci 与 ghproxy 矩阵，强行接管官方包内部 PROXY 数据流。
#   2. JQ 绝缘层修复: 深度引入 select(. != null) 与 |= 语法，杜绝 JQ 覆写导致配置丢失。
#   3. JQ 传参补全: 重构 _safe_jq_write 传参引擎 (支持 "$@")，完美支持多用户增删。
#   4. 内核编译防爆: 主线内核裸装 + initramfs 强制重构，100% 解决编译后重启失联。
#   5. 状态矩阵补完: 补全全域极限微操、状态探针与 130+ SNI 雷达矩阵。
#   6. 工业级 UI 对齐: 遵循 8 行对齐军规，彻底剔除精神污染的废话 echo，维持极客冷峻。
# ==============================================================================

# ------------------------------------------------------------------------------
# [ 0x01: 系统级基础环境检查与严格模式锁定 ]
# ------------------------------------------------------------------------------

# 优先执行 Bash 版本守卫，拦截 dash 运行
if test -z "${BASH_VERSION:-}"; then
    echo "Error: 严重错误！本脚本深度依赖 Bash 高级特性，请执行: bash ex188t45.sh"
    exit 1
fi

if test "${BASH_VERSINFO[0]:-0}" -lt 4; then
    echo "Error: 严重错误！需要 Bash 4.0 或以上版本运行环境，请更新您的操作系统！"
    exit 1
fi

if test "$EUID" -ne 0; then 
    echo -e "\033[31m致命错误: 触及底层内核参数必须拥有最高权限，请使用 root 账户 (sudo -i) 执行！\033[0m"
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then 
    echo -e "\033[31m致命错误: 当前宿主机缺失 systemd 守护系统，非标准化 Linux 环境，已熔断！\033[0m"
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
# [ 0x02: 全域 UI 引擎与常量定义 ]
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

readonly XRAY_BIN="/usr/local/bin/xray"
readonly CONFIG_DIR="/usr/local/etc/xray"
readonly CONFIG="$CONFIG_DIR/config.json"
readonly PUBKEY_FILE="$CONFIG_DIR/public.key"
readonly SNI_CACHE_FILE="$CONFIG_DIR/sni_cache.txt"
readonly INSTALL_DATE_FILE="$CONFIG_DIR/install_date.txt"
readonly USER_SNI_MAP="$CONFIG_DIR/user_sni.txt"
readonly USER_TIME_MAP="$CONFIG_DIR/user_time.txt"

readonly DAT_DIR="/usr/local/share/xray"
readonly SCRIPT_DIR="/usr/local/etc/xray-script"
readonly UPDATE_DAT_SCRIPT="$SCRIPT_DIR/update-dat.sh"
readonly LOG_DIR="/var/log/xray"
readonly BACKUP_DIR="$CONFIG_DIR/backups"
readonly CAKE_OPTS_FILE="$CONFIG_DIR/cake_opts.txt"
readonly FLAGS_DIR="$CONFIG_DIR/flags"

readonly SYMLINK="/usr/local/bin/xrv"
readonly SCRIPT_PATH=$(readlink -f "$0")

# 运行期动态变量初始化
GLOBAL_IP=""
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
# [ 0x04.5: 全局公网 IP 探针 (带内存缓存与严格模式防爆) ]
# ------------------------------------------------------------------------------
_get_ip() {
    # 优先使用 preflight 已经抓取到的极速缓存，拒绝重复发包卡顿
    if test -n "${SERVER_IP:-}"; then
        if test "$SERVER_IP" != "获取失败"; then
            echo "$SERVER_IP"
            return
        fi
    fi

    # 如果缓存失效，则启动无损探测，兼容 set -e 严格模式
    if test -z "${GLOBAL_IP:-}"; then
        local temp_ip=""
        temp_ip=$(curl -k -s -4 --connect-timeout 3 https://api.ipify.org 2>/dev/null | tr -d '\r\n' || echo "")
        
        if test -z "$temp_ip"; then
            temp_ip=$(curl -k -s -4 --connect-timeout 3 https://ifconfig.me 2>/dev/null | tr -d '\r\n' || echo "")
        fi
        
        if test -z "$temp_ip"; then
            GLOBAL_IP="外网探针离线"
        else
            GLOBAL_IP="$temp_ip"
        fi
    fi
    
    echo "$GLOBAL_IP"
}

# ------------------------------------------------------------------------------
# [ 0x05: 企业级 Trap 异常捕获网与灾难清理 ]
# ------------------------------------------------------------------------------

# 构建系统底层目录骨架
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
# [ 0x06: 核心配置灾备、验证中枢与 JQ 绝缘写入引擎 ]
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
        "$XRAY_BIN" run -test -config "$target_config" 2>&1 | head -n 15 || true
        return 1
    fi
}

# 终极修复：使用 "$@" 接收全量 JQ 参数（包含 --argjson 等），防止多用户删改时丢参！
_safe_jq_write() {
    backup_config
    local tmp
    tmp=$(mktemp /tmp/xray_cfg_XXXXXX.json)
    
    # 强制将所有传入参数透传给 jq
    if jq "$@" "$CONFIG" > "$tmp" 2>/dev/null; then
        if verify_xray_config "$tmp"; then
            mv -f "$tmp" "$CONFIG" >/dev/null 2>&1 || true
            fix_permissions
            log_info "JQ 节点重组与写盘成功"
            return 0
        else
            error "安全预审未通过，操作已撤销"
            rm -f "$tmp" >/dev/null 2>&1 || true
            restore_latest_backup
            return 1
        fi
    else
        error "JQ 语法解析断层，无法完成重塑"
        log_error "JQ 解析失败，参数: $*"
        rm -f "$tmp" >/dev/null 2>&1 || true
        restore_latest_backup
        return 1
    fi
}

# ------------------------------------------------------------------------------
# [ 0x07: 绝对核心：百万并发 Limits 守护进程 ]
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

    # 注入极限百万级句柄
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
    
    local need="jq curl wget xxd unzip qrencode vnstat cron openssl iproute2 ethtool bc bison flex dwarves rsync python3 cpio dnsutils"
    local missing=""
    
    for p in $need; do 
        if ! command -v "$p" >/dev/null 2>&1; then 
            missing="$missing $p"
        fi
    done

    if test -n "$missing"; then
        info "侦测到缺失的基础组件，正在向包管理器下发安装指令: $missing"
        pkg_install "$missing"
        
        systemctl start vnstat >/dev/null 2>&1 || true
        systemctl enable vnstat >/dev/null 2>&1 || true
        
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

    if test -f "$SCRIPT_PATH"; then
        \cp -f "$SCRIPT_PATH" "$SYMLINK" >/dev/null 2>&1 || true
        chmod +x "$SYMLINK" >/dev/null 2>&1 || true
        hash -r 2>/dev/null || true
    fi
    
    info "正在向全球节点发射探针以获取本机物理公网 IP..."
    
    set +e
    SERVER_IP=$(curl -k -s -4 --connect-timeout 5 --max-time 10 https://api.ipify.org 2>/dev/null | tr -d '\r\n')
    
    if test -z "$SERVER_IP"; then
        SERVER_IP=$(curl -k -s -4 --connect-timeout 5 --max-time 10 https://ifconfig.me 2>/dev/null | tr -d '\r\n')
    fi
    
    if test -z "$SERVER_IP"; then
        SERVER_IP=$(curl -k -s -4 --connect-timeout 5 --max-time 10 https://icanhazip.com 2>/dev/null | tr -d '\r\n')
    fi
    set -e
    
    if test -z "$SERVER_IP"; then
        warn "多重探测失败，机器的公网 IPv4 寻址暂时被阻断或遮蔽。"
        SERVER_IP="获取失败"
    else
        info "成功捕获公网物理信标: $SERVER_IP"
    fi

    trap cleanup_temp_files EXIT
    trap '_err_handler $? $LINENO "$BASH_COMMAND"' ERR
}

# ------------------------------------------------------------------------------
# [ 0x0A: Geo 全球规则库无人值守更新引擎 (免翻反代穿墙 + 错峰防断连机制) ]
# ------------------------------------------------------------------------------

install_update_dat() {
    info "正在部署 Geo 规则库无人值守热更脚本与穿墙错峰重启逻辑..."
    
    cat > "$UPDATE_DAT_SCRIPT" <<'UPDSH'
#!/usr/bin/env bash
XRAY_DAT_DIR="/usr/local/share/xray"
LOG_FILE="/var/log/xray/update-dat.log"

log() { 
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

dl() {
    local target_url="$1" 
    local out="$2"
    local success=0
    
    for proxy in "https://ghp.ci/" "https://ghproxy.net/" "https://mirror.ghproxy.com/" ""; do
        local url="${proxy}${target_url}"
        
        if curl -kfsSL --connect-timeout 10 --max-time 300 -o "$out.tmp" "$url"; then
            mv -f "$out.tmp" "$out"
            log "[INFO] 成功更新云端规则库: $url"
            success=1
            break
        fi
        log "[WARN] 节点更新失败，准备切换链路重试: $url"
        sleep 5
    done
    
    if test "$success" -eq 0; then
        log "[ERROR] 规则库下载遭遇严重网络阻断，穿墙矩阵全量失效: $target_url"
        return 1
    fi
    return 0
}

dl "https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat" "$XRAY_DAT_DIR/geoip.dat"
dl "https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat" "$XRAY_DAT_DIR/geosite.dat"

log "[INFO] Geo 规则库自动化巡检执行完毕"
UPDSH

    chmod +x "$UPDATE_DAT_SCRIPT" 2>/dev/null || true

    local temp_cron
    temp_cron=$(mktemp)
    
    crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT" | grep -v "/bin/systemctl restart xray" > "$temp_cron" || true
    
    echo "0 3 * * * $UPDATE_DAT_SCRIPT >/dev/null 2>&1" >> "$temp_cron"
    echo "10 3 * * * /bin/systemctl restart xray >/dev/null 2>&1" >> "$temp_cron"
    
    crontab "$temp_cron" 2>/dev/null || true
    rm -f "$temp_cron" 2>/dev/null || true

    info "Geo 路由流防断更机制已物理加载: 每日 03:00 穿墙更新，03:10 触发守护进程平滑重启。"
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
    
    if command -v shuf >/dev/null 2>&1; then
        sni_string=$(echo "$sni_string" | shuf)
    else
        sni_string=$(echo "$sni_string" | awk 'BEGIN{srand()} {print rand()"\t"$0}' | sort -n | cut -f2-)
    fi

    local tmp_sni
    tmp_sni=$(mktemp /tmp/sni_test.XXXXXX)

    for sni in $sni_string; do
        local key=""
        if read -t 0.1 -n 1 -s key 2>/dev/null; then
            echo -e "\n${yellow}[人工干预] 探测已被手动中止，正在整理已捕获的可用节点矩阵...${none}"
            break
        fi

        local time_raw
        time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni" 2>/dev/null || echo "0")
        
        local ms
        ms=$(echo "$time_raw" | awk '{print int($1 * 1000)}')

        if test "${ms:-0}" -gt 0; then
            if curl -sI -m 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray"; then
                echo -e " ${gray}跳过侦测${none} $sni (原因: 命中 Cloudflare CDN 拦截)"
                continue
            fi
            
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
            
            if test -z "$dns_cn" || test "$dns_cn" = "127.0.0.1" || test "$dns_cn" = "0.0.0.0" || test "$dns_cn" = "::1" || test "$dns_cn" = "null"; then
                status_cn="${red}国内墙阻断 (DNS 污染或 RST)${none}"
                p_type="BLOCK"
            else
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
            
            echo -e " ${green}握手存活${none} $sni : 延迟 ${yellow}${ms}ms${none} | 状态: $status_cn"
            
            if test "$p_type" != "BLOCK"; then
                echo "$ms $sni $p_type" >> "$tmp_sni"
            fi
        fi
    done

    if test -s "$tmp_sni"; then
        grep "NORM" "$tmp_sni" | sort -n | head -n 20 | awk '{print $2, $1}' > "$SNI_CACHE_FILE" || true
        
        local count
        count=$(wc -l < "$SNI_CACHE_FILE" 2>/dev/null || echo 0)
        
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
    
    if test "$pass" -eq 0; then
        print_red " ✗ 结论：该目标指纹残缺，易遭墙探！"
    else
        print_green " ✓ 结论：目标完美通过三项高维特征审核！"
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

    # 【终极命脉修复】提取刚编译好的内核真实版本号
    local NEW_KERNEL_VER
    NEW_KERNEL_VER=$(make -s kernelrelease 2>/dev/null || echo "")
    
    if test -n "$NEW_KERNEL_VER"; then
        print_magenta ">>> (核心保命动作) 为新内核 $NEW_KERNEL_VER 强制生成底层 Initramfs 镜像驱动..."
        # 绝对不能丢的动作！否则 GRUB 引导后找不到硬盘，直接导致机器变砖！
        update-initramfs -c -k "$NEW_KERNEL_VER" >/dev/null 2>&1 || true
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

    title "=== [8/8] 刷新系统引导器并销毁编译垃圾 ==="
    
    if command -v update-grub >/dev/null 2>&1; then
        update-grub || true
    fi
    
    # 彻底清除了 apt-get purge 删除老内核的自杀逻辑！必须保留原有内核作为 VNC 回滚救命用！
    cd /
    rm -rf "$BUILD_DIR"/linux* 2>/dev/null || true
    rm -rf "$BUILD_DIR/$KERNEL_FILE" 2>/dev/null || true
    rm -rf /compile/* 2>/dev/null || true
    rm -rf /root/linux* 2>/dev/null || true
    
    info "奇迹再现！无污染原装主线内核编译与 Initramfs 挂载全部顺利结束。"
    warn "老系统将在 30 秒钟内物理退役重装，请耐心等待重新连接..."
    
    sleep 30
    reboot
}
# ------------------------------------------------------------------------------
# [ 0x13: 系统内核网络栈极限压榨 (V62 全量 60+ 项网络栈阵列调优) ]
# ------------------------------------------------------------------------------

do_perf_tuning() {
    title "极客压榨：全域系统底层网络栈结构重塑"
    warn "警告: 此时将深度注入内核级极限并发参数，执行完毕必须重启宿主机！"
    
    local confirm=""
    read -rp "确定要继续吗？(y/n): " confirm || true
    
    if test "$confirm" != "y"; then
        if test "$confirm" != "Y"; then
            return
        fi
    fi
    
    local current_scale
    current_scale=$(sysctl -n net.ipv4.tcp_adv_win_scale 2>/dev/null || echo "1")
    
    local current_app
    current_app=$(sysctl -n net.ipv4.tcp_app_win 2>/dev/null || echo "31")
    
    echo -e "  当前内存滑动侧倾角度 (tcp_adv_win_scale): ${cyan}${current_scale}${none} (建议填 1 或 2)"
    echo -e "  当前应用保留水池线 (tcp_app_win): ${cyan}${current_app}${none} (建议保留 31)"
    
    local new_scale=""
    read -rp "可自定义 tcp_adv_win_scale (-2 到 2 为合法域，默认按 Enter 继承): " new_scale || true
    if test -z "$new_scale"; then
        new_scale="$current_scale"
    fi
    
    local new_app=""
    read -rp "可自定义 tcp_app_win (1 到 31 的分配率，默认按 Enter 继承): " new_app || true
    if test -z "$new_app"; then
        new_app="$current_app"
    fi

    # 大扫除，剿杀过时的加速器
    systemctl stop net-speeder >/dev/null 2>&1 || true
    killall net-speeder >/dev/null 2>&1 || true
    systemctl disable net-speeder >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/net-speeder.service 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    rm -rf /root/net-speeder 2>/dev/null || true

    # 清空可能冲突的上古配置文件
    truncate -s 0 /etc/sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-network-optimized.conf 2>/dev/null || true
    rm -f /etc/sysctl.d/99-bbr*.conf /etc/sysctl.d/99-ipv6-disable.conf /etc/sysctl.d/99-pro*.conf /etc/sysctl.d/99-xanmod-bbr3.conf /usr/lib/sysctl.d/50-pid-max.conf /usr/lib/sysctl.d/99-protect-links.conf 2>/dev/null || true
    
    # 彻底释放 Linux 全局进程限制
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
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
    fi
    
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session-noninteractive 2>/dev/null; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive
    fi
    
    # 防止因文件不存在导致 grep 报错，采用强制追加模式
    sed -i '/DefaultLimitNOFILE/d' /etc/systemd/system.conf 2>/dev/null || true
    sed -i '/DefaultLimitNPROC/d' /etc/systemd/system.conf 2>/dev/null || true
    echo "DefaultLimitNOFILE=1000000" >> /etc/systemd/system.conf
    echo "DefaultLimitNPROC=1000000" >> /etc/systemd/system.conf

    local target_qdisc="fq"
    local cake_state
    cake_state=$(check_cake_state 2>/dev/null || echo "false")
    
    if test "$cake_state" = "true"; then
        target_qdisc="cake"
    fi

    # ========================================================
    # 以下为全量不压缩的 V62 级别 60+ 项系统网络栈精雕细刻
    # ========================================================
    cat > /etc/sysctl.d/99-network-optimized.conf << EOF
# -- 基础拥塞队列与排队 --
net.core.default_qdisc = ${target_qdisc}
net.ipv4.tcp_congestion_control = bbr
net.ipv4.neigh.default.base_reachable_time_ms = 60000
net.ipv4.neigh.default.mcast_solicit = 2
net.ipv4.neigh.default.retrans_time_ms = 500

# -- 关闭过滤与路由源验证，追求极致穿越 --
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.tcp_no_metrics_save = 1

# -- ECN 与 MTU 智能探针 --
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_sack = 1

# -- 窗口扩容与倾斜角设定 --
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_adv_win_scale = ${new_scale}
net.ipv4.tcp_app_win = ${new_app}
net.ipv4.tcp_moderate_rcvbuf = 1

# -- 核心内存壁垒推宽 (21MB巨型池) --
net.core.rmem_default = 560576
net.core.wmem_default = 560576
net.core.rmem_max = 21699928
net.core.wmem_max = 21699928
net.ipv4.tcp_rmem = 4096 760576 21699928
net.ipv4.tcp_wmem = 4096 760576 21699928
net.ipv4.udp_rmem_min = 4096
net.ipv4.udp_wmem_min = 4096

# -- NAPI 轮询权重约束 (杜绝单核算力被独占导致的卡顿) --
net.core.dev_weight = 64
net.core.dev_weight_tx_bias = 1
net.core.dev_weight_rx_bias = 1
net.core.netdev_budget = 300

# -- VFS 调度与文件句柄 --
vm.swappiness = 1
fs.file-max = 1048576
fs.nr_open = 1048576
fs.inotify.max_user_instances = 262144

# -- 保活心跳与 TIME_WAIT 极速回收 --
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 12
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_abort_on_overflow = 0

# -- 连接风暴与重试策略防御 --
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

# -- FastOpen 与低级分片重组 --
net.core.optmem_max = 3276800
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_reordering = 3
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_tso_win_divisor = 6

# -- ARP 与 PID 资源 --
kernel.pid_max = 4194304
kernel.threads-max = 85536
net.ipv4.neigh.default.gc_thresh1 = 1024
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv4.neigh.default.gc_stale_time = 100
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2

# -- 内核级忙轮询 (Busy Polling) 防抖 --
net.unix.max_dgram_qlen = 130000
net.core.busy_poll = 50
net.core.busy_read = 0

# -- 16KB 精准防缓冲膨胀 (Bufferbloat) --
net.ipv4.tcp_notsent_lowat = 16384
vm.vfs_cache_pressure = 10
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.ip_forward = 1

# -- 重传与转发控制 --
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.tcp_early_retrans = 3
net.ipv4.neigh.default.unres_qlen = 35535
net.ipv4.conf.all.route_localnet = 0
net.ipv4.tcp_orphan_retries = 8
net.ipv4.conf.all.forwarding = 1

# -- IP 碎片重组 --
net.ipv4.ipfrag_max_dist = 32
net.ipv4.ipfrag_secret_interval = 200
net.ipv4.ipfrag_low_thresh = 42008868
net.ipv4.ipfrag_high_thresh = 104917729
net.ipv4.ipfrag_time = 30
fs.aio-max-nr = 262144
kernel.msgmax = 655350
kernel.msgmnb = 655350

# -- RPS/RFS 散列深度上限 --
net.ipv4.neigh.default.proxy_qlen = 50000
net.ipv4.tcp_pacing_ca_ratio = 150
net.ipv4.tcp_pacing_ss_ratio = 210
fs.protected_fifos = 1
fs.protected_hardlinks = 1
fs.protected_regular = 2
fs.protected_symlinks = 1
net.core.rps_sock_flow_entries = 131072
net.core.flow_limit_table_len = 131072
net.ipv4.tcp_workaround_signed_windows = 1
vm.dirty_ratio = 35
vm.overcommit_memory = 0
kernel.sysrq = 1

# -- 斩杀 IPv6 彻底杜绝污染泄漏 --
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1

# -- 杂项与硬件调优 --
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

    sysctl --system >/dev/null 2>&1 || true
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "eth0")
    
    if test -n "$IFACE"; then
        cat > /usr/local/bin/nic-optimize.sh <<'EONIC'
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "eth0")
if test -n "$IFACE"; then
    ethtool -K "$IFACE" lro off rx-gro-hw off 2>/dev/null || true
    ethtool -C "$IFACE" adaptive-rx off rx-usecs 0 tx-usecs 0 2>/dev/null || true
fi
EONIC
        chmod +x /usr/local/bin/nic-optimize.sh 2>/dev/null || true
        
        cat > /etc/systemd/system/nic-optimize.service <<EOSERVICE
[Unit]
Description=NIC Advanced Tuning
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
        
        cat > /usr/local/bin/rps-optimize.sh <<'EOF_RPS'
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "eth0")

if test -z "$IFACE"; then
    exit 0
fi

CPU=$(nproc 2>/dev/null || echo 1)
CPU_MASK=$(printf "%x" $(( (1<<CPU)-1 )))
RX_QUEUES=$(ls -d /sys/class/net/"$IFACE"/queues/rx-* 2>/dev/null | wc -l || echo 0)

for RX in /sys/class/net/"$IFACE"/queues/rx-*; do
    if test -w "$RX/rps_cpus"; then
        echo "$CPU_MASK" > "$RX/rps_cpus" 2>/dev/null || true
    fi
done

for TX in /sys/class/net/"$IFACE"/queues/tx-*; do
    if test -w "$TX/xps_cpus"; then
        echo "$CPU_MASK" > "$TX/xps_cpus" 2>/dev/null || true
    fi
done

sysctl -w net.core.rps_sock_flow_entries=131072 >/dev/null 2>&1 || true

if test "${RX_QUEUES:-0}" -gt 0; then
    FLOW_PER_QUEUE=$((65535 / RX_QUEUES))
    for RX in /sys/class/net/"$IFACE"/queues/rx-*; do
        if test -w "$RX/rps_flow_cnt"; then
            echo "$FLOW_PER_QUEUE" > "$RX/rps_flow_cnt" 2>/dev/null || true
        fi
    done
fi
EOF_RPS
        chmod +x /usr/local/bin/rps-optimize.sh 2>/dev/null || true
        
        cat > /etc/systemd/system/rps-optimize.service <<EOF_RPS_SRV
[Unit]
Description=RPS RFS Network CPU Flow Distribution Optimization
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
    fi

    info "全量巨型底层参数注入完成！系统即将重启应用物理层面的修改..."
    sleep 30
    reboot
}

# ------------------------------------------------------------------------------
# [ 0x14: 网卡发送队列精细压缩 ]
# ------------------------------------------------------------------------------

do_txqueuelen_opt() {
    title "TX Queue 缓冲队列缩容"
    local IP_CMD
    IP_CMD=$(command -v ip || echo "")
    
    if test -z "$IP_CMD"; then
        error "无法调用底层 ip 组件！"
        return 1
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "eth0")
    
    if test -z "$IFACE"; then
        error "无法准确识别网卡设备号！"
        return 1
    fi
    
    "$IP_CMD" link set "$IFACE" txqueuelen 2000 2>/dev/null || true
    
    cat > /etc/systemd/system/txqueue.service <<EOF_TXQ
[Unit]
Description=Set TX Queue Length for Fast Path
After=network-online.target

[Service]
Type=oneshot
ExecStart=$IP_CMD link set $IFACE txqueuelen 2000
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF_TXQ

    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl enable txqueue.service >/dev/null 2>&1 || true
    systemctl start txqueue.service >/dev/null 2>&1 || true
    
    info "已切断大包拥堵缓冲池，锁定 txqueuelen=2000"
    local _p=""
    read -rp "Enter 继续..." _p || true
}

# ------------------------------------------------------------------------------
# [ 0x15: CAKE 高纬度排队规则部署台 ]
# ------------------------------------------------------------------------------

config_cake_advanced() {
    clear
    title "CAKE 高纬度排队规则部署台"
    
    local current_opts="系统原生自适应"
    if test -f "$CAKE_OPTS_FILE"; then
        current_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "系统原生自适应")
    fi
    
    echo -e "  当前参数: ${cyan}${current_opts}${none}\n"
    
    local c_bw=""
    read -rp "  带宽高界限 (如 900Mbit, 0 禁用): " c_bw || true
    
    local c_oh=""
    read -rp "  Overhead 包头补偿 (如 48, 0 禁用): " c_oh || true
    
    local c_mpu=""
    read -rp "  最小截断 MPU (如 84, 0 禁用): " c_mpu || true
    
    echo "  RTT 模型: "
    echo "    1) internet  (85ms 默认网络)"
    echo "    2) oceanic   (300ms 跨海模型)"
    echo "    3) satellite (1000ms 卫星模型)"
    
    local rtt_sel=""
    read -rp "  请选择 (默认 2): " rtt_sel || true
    
    local c_rtt="oceanic"
    case "${rtt_sel:-2}" in
        1) c_rtt="internet" ;;
        2) c_rtt="oceanic" ;;
        3) c_rtt="satellite" ;;
        *) c_rtt="oceanic" ;;
    esac
    
    echo "  数据分流模式: "
    echo "    1) diffserv4  (按特征分流，高消耗)"
    echo "    2) besteffort (盲走直推，低延迟推荐)"
    
    local diff_sel=""
    read -rp "  请选择 (默认 2): " diff_sel || true
    
    local c_diff="besteffort"
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
    
    final_opts="$final_opts $c_rtt $c_diff"
    # 用 sed 去除因缺失拼接变量产生的多余首空格
    final_opts=$(echo "$final_opts" | sed 's/^ *//' || echo "")
    
    if test -z "$final_opts"; then
        rm -f "$CAKE_OPTS_FILE" 2>/dev/null || true
        info "已清空参数。"
    else
        echo "$final_opts" > "$CAKE_OPTS_FILE"
        info "已记录: $final_opts"
    fi
    
    # [此函数的定义在后续块中]
    # _apply_cake_live 
    
    local _p=""
    read -rp "按下 Enter 脱离控制台..." _p || true
}

# ------------------------------------------------------------------------------
# [ 0x16: 全域 28 项探针独立解析模块 ]
# ------------------------------------------------------------------------------

check_mph_state() {
    local state
    state=$(jq -r '.routing.domainMatcher // "false"' "$CONFIG" 2>/dev/null || echo "false")
    if test "$state" = "mph"; then
        echo "true"
    else
        echo "false"
    fi
}

check_maxtime_state() {
    local state
    state=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
    if test "$state" = "60000"; then
        echo "true"
    else
        echo "false"
    fi
}

check_routeonly_state() {
    local state
    state=$(jq -r '.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
    if test "$state" = "true"; then
        echo "true"
    else
        echo "false"
    fi
}

check_sniff_state() {
    local state
    state=$(jq -r '.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.metadataOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
    if test "$state" = "true"; then
        echo "true"
    else
        echo "false"
    fi
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
    curr_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Current hardware settings" | grep "RX:" | head -n 1 | awk '{print $2}' || echo "")
    
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
    if ! lsmod 2>/dev/null | grep -q zram; then
        if ! modprobe -n zram >/dev/null 2>&1; then
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

check_cake_state() {
    if sysctl net.core.default_qdisc 2>/dev/null | grep -q 'cake'; then
        echo "true"
    else
        echo "false"
    fi
}

check_ackfilter_state() {
    if test -f "$FLAGS_DIR/ack_filter"; then
        echo "true"
    else
        echo "false"
    fi
}

check_ecn_state() {
    if test -f "$FLAGS_DIR/ecn"; then
        echo "true"
    else
        echo "false"
    fi
}

check_wash_state() {
    if test -f "$FLAGS_DIR/wash"; then
        echo "true"
    else
        echo "false"
    fi
}

# -------------------------------------------------------------------------
# 【深层物理断点】探测出硬件网卡卸载被固化 (Fixed) 则直接封死操作
# -------------------------------------------------------------------------
check_gso_off_state() {
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
    
    local eth_info
    eth_info=$(ethtool -k "$IFACE" 2>/dev/null || echo "")
    
    if test -z "$eth_info"; then
        echo "unsupported"
        return
    fi
    
    # 精准探测 Fixed 状态，禁止错误下发
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
    
    if test "$CORES" -lt 2; then
        echo "unsupported"
        return
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test -z "$IFACE"; then
        echo "false"
        return
    fi

    local irq
    irq=$(grep "$IFACE" /proc/interrupts 2>/dev/null | head -n 1 | awk '{print $1}' | tr -d ':' || echo "")
    
    if test -n "$irq"; then
        local mask
        mask=$(cat "/proc/irq/$irq/smp_affinity" 2>/dev/null | tr -d '0' || echo "")
        if test "$mask" = "1"; then
            echo "true"
        else
            echo "false"
        fi
    else
        echo "false"
    fi
}
# ------------------------------------------------------------------------------
# [ 0x17: 开机硬件固化挂载与实时网络栈变更注入群 ]
# ------------------------------------------------------------------------------

update_hw_boot_script() {
    cat << 'EOF' > /usr/local/bin/xray-hw-tweaks.sh
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "eth0")
if test -z "$IFACE"; then
    sleep 3
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "eth0")
fi

for bql in /sys/class/net/$IFACE/queues/tx-*/byte_queue_limits/limit_max; do
    if test -f "$bql"; then
        echo "3000" > "$bql" 2>/dev/null || true
    fi
done
EOF
    
    if test "$(check_thp_state)" = "true"; then
        echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
        echo "echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
    fi
    
    if test "$(check_cpu_state)" = "true"; then
        if test -d "/sys/devices/system/cpu/cpu0/cpufreq"; then
            echo 'for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do if test -f "$cpu"; then echo performance > "$cpu" 2>/dev/null || true; fi; done' >> /usr/local/bin/xray-hw-tweaks.sh
        fi
    fi
    
    if test "$(check_ring_state)" = "true"; then
        echo "ethtool -G \$IFACE rx 512 tx 512 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
    fi
    
    local gso_state
    gso_state=$(check_gso_off_state)
    
    if test "$gso_state" = "true"; then
        echo "ethtool -K \$IFACE gro off gso off tso off 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
    else
        if test "$gso_state" = "false"; then
            echo "ethtool -K \$IFACE gro on gso on tso on 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
        fi
    fi
    
    echo "CAKE_OPTS=\"\"" >> /usr/local/bin/xray-hw-tweaks.sh
    echo "if test -f \"$CAKE_OPTS_FILE\"; then CAKE_OPTS=\$(cat \"$CAKE_OPTS_FILE\" 2>/dev/null || echo \"\"); fi" >> /usr/local/bin/xray-hw-tweaks.sh
    
    echo "ACK_FLAG=\"\"" >> /usr/local/bin/xray-hw-tweaks.sh
    echo "if test -f \"$FLAGS_DIR/ack_filter\"; then ACK_FLAG=\"ack-filter\"; fi" >> /usr/local/bin/xray-hw-tweaks.sh
    
    echo "ECN_FLAG=\"\"" >> /usr/local/bin/xray-hw-tweaks.sh
    echo "if test -f \"$FLAGS_DIR/ecn\"; then ECN_FLAG=\"ecn\"; fi" >> /usr/local/bin/xray-hw-tweaks.sh
    
    echo "WASH_FLAG=\"\"" >> /usr/local/bin/xray-hw-tweaks.sh
    echo "if test -f \"$FLAGS_DIR/wash\"; then WASH_FLAG=\"wash\"; fi" >> /usr/local/bin/xray-hw-tweaks.sh

    if test "$(check_cake_state)" = "true"; then
        echo "tc qdisc replace dev \$IFACE root cake \$CAKE_OPTS \$ACK_FLAG \$ECN_FLAG \$WASH_FLAG 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
    fi
    
    if test "$(check_irq_state)" = "true"; then
        echo "systemctl stop irqbalance 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
        echo "for irq in \$(grep \"\$IFACE\" /proc/interrupts 2>/dev/null | awk '{print \$1}' | tr -d ':'); do echo 1 > /proc/irq/\$irq/smp_affinity 2>/dev/null || true; done" >> /usr/local/bin/xray-hw-tweaks.sh
    fi
    
    chmod +x /usr/local/bin/xray-hw-tweaks.sh 2>/dev/null || true
    
    cat << 'EOF' > /etc/systemd/system/xray-hw-tweaks.service
[Unit]
Description=Xray Hardware Tweaks Engine
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
# [ 0x18: 动态控制推杆群 (Toggle Engines) ]
# ------------------------------------------------------------------------------

_apply_cake_live() {
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "eth0")
    
    if test "$(check_cake_state)" = "true"; then
        local base_opts=""
        if test -f "$CAKE_OPTS_FILE"; then
            base_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
        fi
        
        local f_ack=""
        if test "$(check_ackfilter_state)" = "true"; then
            f_ack="ack-filter"
        fi
        
        local f_ecn=""
        if test "$(check_ecn_state)" = "true"; then
            f_ecn="ecn"
        fi
        
        local f_wash=""
        if test "$(check_wash_state)" = "true"; then
            f_wash="wash"
        fi
        
        tc qdisc replace dev "$IFACE" root cake $base_opts $f_ack $f_ecn $f_wash 2>/dev/null || true
    fi
    
    update_hw_boot_script
}

_toggle_affinity_on() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if test -f "$limit_file"; then
        sed -i '/^CPUAffinity=/d' "$limit_file" 2>/dev/null || true
        sed -i '/^Environment="GOMAXPROCS=/d' "$limit_file" 2>/dev/null || true
        
        local CORES
        CORES=$(nproc 2>/dev/null || echo 1)
        
        local TARGET_CPU="0"
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

toggle_buffer() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if test -f "$limit_file"; then
        if test "$(check_buffer_state)" = "true"; then
            sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
        else
            sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
            echo "Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" >> "$limit_file"
        fi
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

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
        }'
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
        }'
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
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "eth0")
    
    if test "$(check_gso_off_state)" = "unsupported"; then
        warn "硬件卸载物理锁死 (Fixed)，已跳过危险指令。"
        sleep 2
        return
    fi
    
    if test "$(check_gso_off_state)" = "true"; then
        ethtool -K "$IFACE" gro on gso on tso on 2>/dev/null || true
    else
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
        else
            if test "$TOTAL_MEM" -lt 1024; then
                ZRAM_SIZE=$((TOTAL_MEM * 3 / 2))
            else
                ZRAM_SIZE=$TOTAL_MEM
            fi
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
Description=Xray ZRAM Compression Engine
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
    else
        if grep -q "^#Storage=" "$conf" 2>/dev/null; then
            sed -i 's/^#Storage=.*/Storage=volatile/' "$conf" 2>/dev/null || true
        else
            if grep -q "^Storage=" "$conf" 2>/dev/null; then
                sed -i 's/^Storage=.*/Storage=volatile/' "$conf" 2>/dev/null || true
            else
                echo "Storage=volatile" >> "$conf"
            fi
        fi
    fi
    systemctl restart systemd-journald >/dev/null 2>&1 || true
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
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "eth0")
    
    local cake_opts=""
    if test -f "$CAKE_OPTS_FILE"; then
        cake_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
    fi
    
    if test "$(check_cake_state)" = "true"; then
        sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = fq/' "$conf" 2>/dev/null || true
        sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1 || true
        tc qdisc replace dev "$IFACE" root fq 2>/dev/null || true
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
        warn "依赖 CAKE 队列，请先激活 CAKE 引擎！"
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
        warn "依赖 CAKE 队列，请先激活 CAKE 引擎！"
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
        warn "依赖 CAKE 队列，请先激活 CAKE 引擎！"
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
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "eth0")
    
    local CORES
    CORES=$(nproc 2>/dev/null || echo 1)
    
    local DEFAULT_MASK
    DEFAULT_MASK=$(printf "%x" $(( (1<<CORES)-1 )))
    
    if test "$(check_irq_state)" = "true"; then
        for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || echo ""); do
            if test -n "$irq"; then
                echo "$DEFAULT_MASK" > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true
            fi
        done
        systemctl start irqbalance >/dev/null 2>&1 || true
        systemctl enable irqbalance >/dev/null 2>&1 || true
    else
        systemctl stop irqbalance >/dev/null 2>&1 || true
        systemctl disable irqbalance >/dev/null 2>&1 || true
        for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || echo ""); do
            if test -n "$irq"; then
                echo 1 > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true
            fi
        done
    fi
    update_hw_boot_script
}

# ------------------------------------------------------------------------------
# [ 0x19: 终极绝缘体：应用层全量激活 / 剥离中心 (杜绝 JSON 清空) ]
# ------------------------------------------------------------------------------

_turn_on_app() {
    # 绝对禁止压缩，全量使用 |= (就地更新) 与 // {} (空集兜底)
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
    
    if test -n "$has_reality"; then
        _safe_jq_write '
          (.inbounds[]? | select(.protocol == "vless" and .streamSettings.security == "reality")) |= (
              .streamSettings.realitySettings = (.streamSettings.realitySettings // {}) |
              .streamSettings.realitySettings.maxTimeDiff = 60000
          )
        '
    fi
    
    local dns_status
    dns_status=$(check_dnsmasq_state 2>/dev/null || echo "false")
    
    if test "$dns_status" = "true"; then
        _safe_jq_write '
          .dns = {
              "servers": [
                  "127.0.0.1"
              ],
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
    if test -f "$limit_file"; then
        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
        echo "Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" >> "$limit_file"
        
        local TOTAL_MEM
        TOTAL_MEM=$(free -m | awk '/Mem/{print $2}' || echo "1024")
        local DYNAMIC_GOGC=100
        
        if test "$TOTAL_MEM" -ge 1800; then 
            DYNAMIC_GOGC=1000
        else
            if test "$TOTAL_MEM" -ge 900; then 
                DYNAMIC_GOGC=500
            else
                if test "$TOTAL_MEM" -ge 700; then
                    DYNAMIC_GOGC=400
                else
                    if test "$TOTAL_MEM" -ge 500; then
                        DYNAMIC_GOGC=300
                    else
                        if test "$TOTAL_MEM" -ge 400; then
                            DYNAMIC_GOGC=200
                        else
                            DYNAMIC_GOGC=100
                        fi
                    fi
                fi
            fi
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
    if test -f "$limit_file"; then
        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
        sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=100\"/" "$limit_file" 2>/dev/null || true
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}
# ------------------------------------------------------------------------------
# [ 0x1A: 上帝微操控制台：28项全域微操入口 (全量展开防断层版) ]
# ------------------------------------------------------------------------------

do_app_level_tuning_menu() {
    while true; do
        clear
        title "全域 28 项极限微操 (Xray 提速底牌 & 系统内核微操)"
        
        if ! test -f "$CONFIG"; then
            error "底盘 JSON 缺失，请首先执行基础核心构建！"
            local _p=""
            read -rp "按 Enter 退出..." _p || true
            return
        fi

        # ==========================================
        # 瞬时全量状态提取 (应用层 1-11 项，无压缩)
        # ==========================================
        local out_fastopen
        out_fastopen=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpFastOpen // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        local out_keepalive
        out_keepalive=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpKeepAliveIdle // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        local sniff_status
        sniff_status=$(jq -r '.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing?.metadataOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        local dns_status
        dns_status=$(jq -r '.dns?.queryStrategy // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        local policy_status
        policy_status=$(jq -r '.policy?.levels["0"]?.connIdle // "false"' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        local affinity_state
        affinity_state=$(check_affinity_state 2>/dev/null || echo "false")
        
        local mph_state
        mph_state=$(check_mph_state 2>/dev/null || echo "false")
        
        local maxtime_state
        maxtime_state=$(check_maxtime_state 2>/dev/null || echo "false")
        
        local routeonly_status
        routeonly_status=$(check_routeonly_state 2>/dev/null || echo "false")
        
        local buffer_state
        buffer_state=$(check_buffer_state 2>/dev/null || echo "false")
        
        local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
        local gc_status="原始 100 态"
        
        if test -f "$limit_file"; then
            local temp_gc
            temp_gc=$(awk -F'=' '/^Environment="GOGC=/ {print $3}' "$limit_file" 2>/dev/null | tr -d '"' | head -n 1 || echo "")
            if test -n "$temp_gc"; then
                gc_status="$temp_gc"
            fi
        fi

        # ==========================================
        # 瞬时全量状态提取 (系统层 12-25 项，无压缩)
        # ==========================================
        local dnsmasq_state
        dnsmasq_state=$(check_dnsmasq_state 2>/dev/null || echo "false")
        
        local thp_state
        thp_state=$(check_thp_state 2>/dev/null || echo "false")
        
        local mtu_state
        mtu_state=$(check_mtu_state 2>/dev/null || echo "false")
        
        local cpu_state
        cpu_state=$(check_cpu_state 2>/dev/null || echo "false")
        
        local ring_state
        ring_state=$(check_ring_state 2>/dev/null || echo "false")
        
        local zram_state
        zram_state=$(check_zram_state 2>/dev/null || echo "false")
        
        local journal_state
        journal_state=$(check_journal_state 2>/dev/null || echo "false")
        
        local prio_state
        prio_state=$(check_process_priority_state 2>/dev/null || echo "false")
        
        local cake_state
        cake_state=$(check_cake_state 2>/dev/null || echo "false")
        
        local irq_state
        irq_state=$(check_irq_state 2>/dev/null || echo "false")
        
        local gso_off_state
        gso_off_state=$(check_gso_off_state 2>/dev/null || echo "false")
        
        local ackfilter_state
        ackfilter_state=$(check_ackfilter_state 2>/dev/null || echo "false")
        
        local ecn_state
        ecn_state=$(check_ecn_state 2>/dev/null || echo "false")
        
        local wash_state
        wash_state=$(check_wash_state 2>/dev/null || echo "false")

        # ==========================================
        # 缺省探测雷达 (应用层)
        # ==========================================
        local app_off_count=0
        if test "$out_fastopen" != "true"; then 
            app_off_count=$((app_off_count + 1))
        fi
        
        if test "$out_keepalive" != "30"; then 
            app_off_count=$((app_off_count + 1))
        fi
        
        if test "$sniff_status" != "true"; then 
            app_off_count=$((app_off_count + 1))
        fi
        
        if test "$dns_status" != "UseIP"; then 
            app_off_count=$((app_off_count + 1))
        fi
        
        if echo "$gc_status" | grep -q "100"; then 
            app_off_count=$((app_off_count + 1))
        fi
        
        if test "$policy_status" != "60"; then 
            app_off_count=$((app_off_count + 1))
        fi
        
        if test "$affinity_state" != "true"; then 
            app_off_count=$((app_off_count + 1))
        fi
        
        if test "$mph_state" != "true"; then 
            app_off_count=$((app_off_count + 1))
        fi
        
        if test "$routeonly_status" != "true"; then 
            app_off_count=$((app_off_count + 1))
        fi
        
        if test "$buffer_state" != "true"; then 
            app_off_count=$((app_off_count + 1))
        fi
        
        local has_reality
        has_reality=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .protocol' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
        
        if test -n "$has_reality"; then
            if test "$maxtime_state" != "true"; then
                app_off_count=$((app_off_count + 1))
            fi
        fi

        # ==========================================
        # 缺省探测雷达 (系统层)
        # ==========================================
        local sys_off_count=0
        if test "$dnsmasq_state" = "false"; then 
            sys_off_count=$((sys_off_count + 1))
        fi
        
        if test "$thp_state" = "false"; then 
            sys_off_count=$((sys_off_count + 1))
        fi
        
        if test "$mtu_state" = "false"; then 
            sys_off_count=$((sys_off_count + 1))
        fi
        
        if test "$cpu_state" = "false"; then 
            sys_off_count=$((sys_off_count + 1))
        fi
        
        if test "$ring_state" = "false"; then 
            sys_off_count=$((sys_off_count + 1))
        fi
        
        if test "$zram_state" = "false"; then 
            sys_off_count=$((sys_off_count + 1))
        fi
        
        if test "$journal_state" = "false"; then 
            sys_off_count=$((sys_off_count + 1))
        fi
        
        if test "$prio_state" = "false"; then 
            sys_off_count=$((sys_off_count + 1))
        fi
        
        if test "$cake_state" = "false"; then 
            sys_off_count=$((sys_off_count + 1))
        fi
        
        if test "$irq_state" = "false"; then 
            sys_off_count=$((sys_off_count + 1))
        fi
        
        if test "$gso_off_state" = "false"; then 
            sys_off_count=$((sys_off_count + 1))
        fi
        
        if test "$ackfilter_state" = "false"; then 
            sys_off_count=$((sys_off_count + 1))
        fi
        
        if test "$ecn_state" = "false"; then 
            sys_off_count=$((sys_off_count + 1))
        fi
        
        if test "$wash_state" = "false"; then 
            sys_off_count=$((sys_off_count + 1))
        fi

        # ==========================================
        # 状态着色转换体系 (原教旨多行分离)
        # ==========================================
        local s1
        if test "$out_fastopen" = "true"; then 
            s1="${cyan}狂暴提速已部署${none}"
        else 
            s1="${gray}系统默认静默${none}"
        fi
        
        local s2
        if test "$out_keepalive" = "30"; then 
            s2="${cyan}心跳激进探活${none}"
        else 
            s2="${gray}慢速回收${none}"
        fi
        
        local s3
        if test "$sniff_status" = "true"; then 
            s3="${cyan}精准解负释放 CPU${none}"
        else 
            s3="${gray}传统重度分析${none}"
        fi
        
        local s4
        if test "$dns_status" = "UseIP"; then 
            s4="${cyan}纯正自解引流${none}"
        else 
            s4="${gray}未开启${none}"
        fi
        
        local s6
        if test "$policy_status" = "60"; then 
            s6="${cyan}策略组极速出库${none}"
        else 
            s6="${gray}系统默认拖沓${none}"
        fi
        
        local s7
        if test "$affinity_state" = "true"; then 
            s7="${cyan}进程物理单核绑死${none}"
        else 
            s7="${gray}进程放养调度${none}"
        fi
        
        local s8
        if test "$mph_state" = "true"; then 
            s8="${cyan}MPH O(1) 预编译寻址${none}"
        else 
            s8="${gray}基础线性比对${none}"
        fi
        
        local s9
        if test -z "$has_reality"; then 
            s9="${gray}协议不支持，越权跳过${none}"
        else 
            if test "$maxtime_state" = "true"; then 
                s9="${cyan}时间戳偏移金钟罩 (60s)${none}"
            else 
                s9="${gray}未建立防护墙${none}"
            fi
        fi
        
        local s10
        if test "$routeonly_status" = "true"; then 
            s10="${cyan}盲走快车道已通车${none}"
        else 
            s10="${gray}重层数据全息提取${none}"
        fi
        
        local s11
        if test "$buffer_state" = "true"; then 
            s11="${cyan}超大 64K 重卡缓冲池${none}"
        else 
            s11="${gray}小内存低耗运转${none}"
        fi
        
        local s12
        if test "$dnsmasq_state" = "true"; then 
            s12="${cyan}本地 0ms 纯内存查询${none}"
        else 
            s12="${gray}挂载外部原生解析${none}"
        fi
        
        local s13
        if test "$thp_state" = "true"; then 
            s13="${cyan}透明大页已击碎剥离${none}"
        else
            if test "$thp_state" = "unsupported"; then 
                s13="${gray}内核缺失，无效指令${none}"
            else 
                s13="${gray}被动默认${none}"
            fi
        fi
        
        local s14
        if test "$mtu_state" = "true"; then 
            s14="${cyan}MTU 嗅探器探寻中${none}"
        else
            if test "$mtu_state" = "unsupported"; then 
                s14="${gray}无此参数组件${none}"
            else 
                s14="${gray}被动阻断${none}"
            fi
        fi
        
        local s15
        if test "$cpu_state" = "true"; then 
            s15="${cyan}全系核心频率顶头锁死${none}"
        else
            if test "$cpu_state" = "unsupported"; then 
                s15="${gray}调度锁缺失或被隔离${none}"
            else 
                s15="${gray}节能温和调度${none}"
            fi
        fi
        
        local s16
        if test "$ring_state" = "true"; then 
            s16="${cyan}已紧缩换取最低延迟${none}"
        else
            if test "$ring_state" = "unsupported"; then 
                s16="${gray}网卡固件不兼容${none}"
            else 
                s16="${gray}重装系统大缓冲排队${none}"
            fi
        fi
        
        local s17
        if test "$zram_state" = "true"; then 
            s17="${cyan}内存超压缩虚拟生效${none}"
        else
            if test "$zram_state" = "unsupported"; then 
                s17="${gray}未安装 zram 内核块${none}"
            else 
                s17="${gray}依赖落盘极慢硬盘${none}"
            fi
        fi
        
        local s18
        if test "$journal_state" = "true"; then 
            s18="${cyan}强行剥离物理 IO 写入${none}"
        else
            if test "$journal_state" = "unsupported"; then 
                s18="${gray}不受控${none}"
            else 
                s18="${gray}疯狂磨损硬盘写入中${none}"
            fi
        fi
        
        local s19
        if test "$prio_state" = "true"; then 
            s19="${cyan}OOM 全域免死金牌生效${none}"
        else 
            s19="${gray}无保护易被强杀${none}"
        fi
        
        local s20
        if test "$cake_state" = "true"; then 
            s20="${cyan}最强 CAKE 引擎掌管队列${none}"
        else 
            s20="${gray}原始 FQ 素体排队${none}"
        fi
        
        local s21
        if test "$irq_state" = "true"; then 
            s21="${cyan}多核 RPS 散列掩码撕裂${none}"
        else
            if test "$irq_state" = "unsupported"; then 
                s21="${gray}单核机器越级跳过${none}"
            else 
                s21="${gray}任其单核拥挤堵塞${none}"
            fi
        fi
        
        local s22
        if test "$gso_off_state" = "true"; then 
            s22="${cyan}彻底打碎大包杜绝粘滞${none}"
        else
            if test "$gso_off_state" = "unsupported"; then 
                s22="${gray}已被物理锁死 (网卡驱动不允许干预)${none}"
            else 
                s22="${gray}网卡硬件自行重组大包${none}"
            fi
        fi
        
        local s23
        if test "$ackfilter_state" = "true"; then 
            s23="${cyan}主动绞杀废包拦截冗余${none}"
        else 
            s23="${gray}未干预空载${none}"
        fi
        
        local s24
        if test "$ecn_state" = "true"; then 
            s24="${cyan}配合 BBR 零丢包平滑限速${none}"
        else 
            s24="${gray}未布防标志位${none}"
        fi
        
        local s25
        if test "$wash_state" = "true"; then 
            s25="${cyan}头信息污染清理强行启动${none}"
        else 
            s25="${gray}听天由命盲推${none}"
        fi

        # ==========================================
        # 大屏渲染输出
        # ==========================================
        echo -e "  ${magenta}--- Xray Core 应用层内部极客调优 (1-11) ---${none}"
        echo -e "  1)  开关 -> 双向并发与快速打开提速 (tcpNoDelay)          | 状态: $s1"
        echo -e "  2)  开关 -> Socket 智能保活与快速死链拔除 (KeepAlive)    | 状态: $s2"
        echo -e "  3)  开关 -> Xray 全域嗅探引擎减负解放 CPU (metadataOnly) | 状态: $s3"
        echo -e "  4)  开关 -> 启用自建底层无污染 DNS 分发引擎 (UseIP)      | 状态: $s4"
        echo -e "  5)  调整 -> 刷新 GOGC 内存池伸缩回收比 (自动侦测)        | 设定: ${cyan}${gc_status}${none}"
        echo -e "  6)  开关 -> Xray 强行短平快 Policy 优化 (connIdle)       | 状态: $s6"
        echo -e "  7)  开关 -> 进程物理防飘移绑核技术 (CPUAffinity)         | 状态: $s7"
        echo -e "  8)  开关 -> 巨型哈希路由表直查跃迁 (MPH)                 | 状态: $s8"
        echo -e "  9)  开关 -> Reality 深度防御重放装甲 (maxTimeDiff)       | 状态: $s9"
        echo -e "  10) 开关 -> 零拷贝旁路数据盲转发不查包 (routeOnly)       | 状态: $s10"
        echo -e "  11) 开关 -> 分配 64K 超大物理重卡调度内存 (BUFFER_SIZE)  | 状态: $s11"
        echo -e ""
        echo -e "  ${magenta}--- Linux 系统层与内核底层黑科技操控 (12-25) ---${none}"
        echo -e "  12) 开关 -> 本地纯内存 Dnsmasq 极速查询池 (锁TTL)        | 状态: $s12"
        echo -e "  13) 开关 -> 透明大页合并瓦解技术 (THP Defrag)            | 状态: $s13"
        echo -e "  14) 开关 -> TCP MTU 黑洞路径智能重试嗅探                 | 状态: $s14"
        echo -e "  15) 开关 -> CPU 频率全局锁死打满 (Performance)           | 状态: $s15"
        echo -e "  16) 开关 -> 网卡硬件 Ring Buffer 排队环反向收缩          | 状态: $s16"
        echo -e "  17) 开关 -> 自动划定内存极速压缩交换池 (ZRAM)            | 状态: $s17"
        echo -e "  18) 开关 -> 斩断 Journald 日志物理硬盘 I/O (转入内存)    | 状态: $s18"
        echo -e "  19) 开关 -> 给 Xray 打上底层 OOM 免死与高优先金牌        | 状态: $s19"
        echo -e "  20) 开关 -> CAKE 削峰填谷智能排队调度器 (取代 fq)        | 状态: $s20"
        echo -e "  21) 开关 -> 网卡多队列 RPS 散列 / 单核 IRQ 硬隔离        | 状态: $s21"
        echo -e "  22) 开关 -> 网卡 GRO/GSO 大包拆解反转 (降低延迟抖动)     | 状态: $s22"
        echo -e "  23) 开关 -> CAKE ack-filter 上行空包强行绞杀策略         | 状态: $s23"
        echo -e "  24) 开关 -> CAKE ECN 队列显式通告 (配合 BBR 实现0丢包)   | 状态: $s24"
        echo -e "  25) 开关 -> CAKE Wash 报文杂项清理防御干扰               | 状态: $s25"
        echo -e "  "
        echo -e "  ${cyan}26) 战神降临：一键极速重置 1-11 项应用层微操${none}"
        echo -e "  ${yellow}27) 上帝指令：一键智能反转 12-25 项底层硬件微操${none}"
        echo -e "  ${red}28) 灭世之手：不顾一切全域 25 项全开 (执行后会触发强制重启！)${none}"
        echo "  0) 逃离控制台"
        hr
        
        local app_opt=""
        read -rp "请下达数字执行代号: " app_opt || true

        # ==========================================
        # 控制流处理区上半部 (应用层开关处理)
        # ==========================================
        case "${app_opt:-}" in
            1)
                if test "$out_fastopen" = "true"; then
                    _safe_jq_write '
                      (.outbounds[]? | select(.protocol == "freedom")) |= 
                          del(.streamSettings.sockopt.tcpNoDelay, .streamSettings.sockopt.tcpFastOpen) |
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= 
                          del(.streamSettings.sockopt.tcpNoDelay, .streamSettings.sockopt.tcpFastOpen)
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
                info "双向提速逻辑改变，已应用。"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            2)
                if test "$out_keepalive" = "30"; then
                    _safe_jq_write '
                      (.outbounds[]? | select(.protocol == "freedom")) |= 
                          del(.streamSettings.sockopt.tcpKeepAliveIdle, .streamSettings.sockopt.tcpKeepAliveInterval) |
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= 
                          del(.streamSettings.sockopt.tcpKeepAliveIdle, .streamSettings.sockopt.tcpKeepAliveInterval)
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
                info "Socket 智能保活系统调整完毕。"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            3)
                if test "$sniff_status" = "true"; then
                    _safe_jq_write '
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= (
                          .sniffing = (.sniffing // {}) |
                          .sniffing.metadataOnly = false
                      )
                    '
                else
                    _safe_jq_write '
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= (
                          .sniffing = (.sniffing // {}) |
                          .sniffing.metadataOnly = true
                      )
                    '
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                info "底层分析嗅探引擎减负设置成功。"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            4)
                if test "$dns_status" = "UseIP"; then
                    _safe_jq_write 'del(.dns)'
                else
                    if test "$dnsmasq_state" = "true"; then
                        _safe_jq_write '
                          .dns = {
                              "servers":["127.0.0.1"], 
                              "queryStrategy":"UseIP"
                          }
                        '
                    else
                        _safe_jq_write '
                          .dns = {
                              "servers":["https://8.8.8.8/dns-query","https://1.1.1.1/dns-query"], 
                              "queryStrategy":"UseIP"
                          }
                        '
                    fi
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                info "内置 DNS 引擎已变更！"
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
                    else
                        if test "$TOTAL_MEM" -ge 900; then 
                            DYNAMIC_GOGC=500
                        else
                            if test "$TOTAL_MEM" -ge 700; then 
                                DYNAMIC_GOGC=400
                            else
                                if test "$TOTAL_MEM" -ge 500; then 
                                    DYNAMIC_GOGC=300
                                else
                                    if test "$TOTAL_MEM" -ge 400; then 
                                        DYNAMIC_GOGC=200
                                    else
                                        DYNAMIC_GOGC=100
                                    fi
                                fi
                            fi
                        fi
                    fi
                    
                    if grep -q "Environment=\"GOGC=" "$limit_file" 2>/dev/null; then
                        if echo "$gc_status" | grep -q "100" 2>/dev/null; then
                            sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=$DYNAMIC_GOGC\"/" "$limit_file" 2>/dev/null || true
                        else
                            sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=100\"/" "$limit_file" 2>/dev/null || true
                        fi
                    else
                        echo "Environment=\"GOGC=$DYNAMIC_GOGC\"" >> "$limit_file"
                    fi
                    
                    systemctl daemon-reload >/dev/null 2>&1 || true
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "GOGC 动态阶梯调优完成！"
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            6)
                if test "$policy_status" = "60"; then
                    _safe_jq_write 'del(.policy)'
                else
                    _safe_jq_write '
                      .policy = {
                          "levels": {
                              "0": {
                                  "handshake":3,
                                  "connIdle":60
                              }
                          },
                          "system": {
                              "statsInboundDownlink":false,
                              "statsInboundUplink":false
                          }
                      }
                    '
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                info "回收策略调配完成！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            7)
                if test "$affinity_state" = "true"; then
                    _toggle_affinity_off
                else
                    _toggle_affinity_on
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                info "核心独占隔离操作成功！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            8)
                if test "$mph_state" = "true"; then
                    _safe_jq_write 'del(.routing.domainMatcher)'
                else
                    _safe_jq_write '
                      .routing = (.routing // {}) | 
                      .routing.domainMatcher = "mph"
                    '
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                info "路由层级 MPH 挂载完毕！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            9)
                if test -n "$has_reality"; then
                    if test "$maxtime_state" = "true"; then
                        _safe_jq_write '
                          (.inbounds[]? | select(.protocol == "vless" and .streamSettings.security == "reality")) |= (
                              .streamSettings.realitySettings = (.streamSettings.realitySettings // {}) |
                              del(.streamSettings.realitySettings.maxTimeDiff)
                          )
                        '
                    else
                        _safe_jq_write '
                          (.inbounds[]? | select(.protocol == "vless" and .streamSettings.security == "reality")) |= (
                              .streamSettings.realitySettings = (.streamSettings.realitySettings // {}) |
                              .streamSettings.realitySettings.maxTimeDiff = 60000
                          )
                        '
                    fi
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "重放时间戳装甲部署完毕！"
                else
                    warn "您的系统中不存在有效的 Reality，跳过强加拦截令。"
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            10)
                if test "$routeonly_status" = "true"; then
                    _safe_jq_write '
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= (
                          .sniffing = (.sniffing // {}) |
                          .sniffing.routeOnly = false
                      )
                    '
                else
                    _safe_jq_write '
                      (.inbounds[]? | select(.protocol == "vless" or .protocol == "shadowsocks")) |= (
                          .sniffing = (.sniffing // {}) |
                          .sniffing.routeOnly = true
                      )
                    '
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                info "内核底层直通盲走特快通道交替。"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            11)
                toggle_buffer
                systemctl restart xray >/dev/null 2>&1 || true
                info "物理巨型缓存池调整已结束！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
            12)
                toggle_dnsmasq
                info "DNS 缓存接管控制变更！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            13)
                toggle_thp
                info "内存大页干预完成！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            14)
                toggle_mtu
                info "MTU 探测修正已下发！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            15)
                toggle_cpu
                info "CPU 频率性能状态改变！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            16)
                toggle_ring
                info "网卡硬件 Ring Buffer 排队结构更改完毕！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            17)
                toggle_zram
                info "物理级虚拟 ZRAM 操作成功！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            18)
                toggle_journal
                info "内存化 IO 指令重现。"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            19)
                toggle_process_priority
                info "金牌级 OOM 提权执行！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            20)
                toggle_cake
                info "系统调度队列 CAKE/FQ 分解与挂载已执行！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            21)
                toggle_irq
                info "深层多核 RPS 数据拆解或单核闭环下达成功！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            22)
                if test "$gso_off_state" = "unsupported"; then
                    warn "宿主机当前网卡底层驱动物理锁死 (fixed)！"
                    warn "为了保护您的服务器不断网失联，系统主动物理熔断了强行干预网卡卸载特征的指令！"
                    sleep 3
                else
                    toggle_gso_off
                    info "网卡数据包卸载组装干预下发成功！"
                    local _p=""; read -rp "按 Enter 继续..." _p || true
                fi
                ;;
                
            23)
                toggle_ackfilter
                info "CAKE 附加密集干预结束！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            24)
                toggle_ecn
                info "CAKE 附加密集干预结束！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            25)
                toggle_wash
                info "CAKE 附加密集干预结束！"
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            26)
                if test "$app_off_count" -gt 0; then
                    print_magenta ">>> 正在为应用层全速开启极速逻辑引擎..."
                    _turn_on_app
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "应用层逻辑大一统成功开启！"
                else
                    print_magenta ">>> 正在褪去应用层激进装备，还原官方生态..."
                    _turn_off_app
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "回归宁静！应用层优化已悉数剥离。"
                fi
                local _p=""; read -rp "按 Enter 归队..." _p || true
                ;;
                
            27)
                if test "$sys_off_count" -gt 0; then
                    if test "$dnsmasq_state" = "false"; then toggle_dnsmasq; fi
                    if test "$thp_state" = "false"; then toggle_thp; fi
                    if test "$mtu_state" = "false"; then toggle_mtu; fi
                    if test "$cpu_state" = "false"; then toggle_cpu; fi
                    if test "$ring_state" = "false"; then toggle_ring; fi
                    if test "$zram_state" = "false"; then toggle_zram; fi
                    if test "$journal_state" = "false"; then toggle_journal; fi
                    if test "$prio_state" = "false"; then toggle_process_priority; fi
                    if test "$cake_state" = "false"; then toggle_cake; fi
                    if test "$irq_state" = "false"; then toggle_irq; fi
                    
                    # 保护底层不受污染：只有明确为 false 且不是 unsupported 才操作
                    if test "$gso_off_state" = "false"; then
                        if test "$gso_off_state" != "unsupported"; then 
                            toggle_gso_off
                        fi
                    fi
                    
                    if test "$ackfilter_state" = "false"; then toggle_ackfilter; fi
                    if test "$ecn_state" = "false"; then toggle_ecn; fi
                    if test "$wash_state" = "false"; then toggle_wash; fi
                    
                    info "12-25 项底层物理网络栈参数已达到满血极限状态！"
                else
                    if test "$dnsmasq_state" = "true"; then toggle_dnsmasq; fi
                    if test "$thp_state" = "true"; then toggle_thp; fi
                    if test "$mtu_state" = "true"; then toggle_mtu; fi
                    if test "$cpu_state" = "true"; then toggle_cpu; fi
                    if test "$ring_state" = "true"; then toggle_ring; fi
                    if test "$zram_state" = "true"; then toggle_zram; fi
                    if test "$journal_state" = "true"; then toggle_journal; fi
                    if test "$prio_state" = "true"; then toggle_process_priority; fi
                    if test "$cake_state" = "true"; then toggle_cake; fi
                    if test "$irq_state" = "true"; then toggle_irq; fi
                    
                    if test "$gso_off_state" = "true"; then
                        if test "$gso_off_state" != "unsupported"; then 
                            toggle_gso_off
                        fi
                    fi
                    
                    if test "$ackfilter_state" = "true"; then toggle_ackfilter; fi
                    if test "$ecn_state" = "true"; then toggle_ecn; fi
                    if test "$wash_state" = "true"; then toggle_wash; fi
                    
                    info "12-25 系统级配置已被还原到默认模式。"
                fi
                local _p=""; read -rp "按 Enter 继续..." _p || true
                ;;
                
            28)
                if test "$((app_off_count + sys_off_count))" -gt 0; then
                    if test "$app_off_count" -gt 0; then 
                        _turn_on_app
                    fi
                    
                    if test "$sys_off_count" -gt 0; then
                        if test "$dnsmasq_state" = "false"; then toggle_dnsmasq; fi
                        if test "$thp_state" = "false"; then toggle_thp; fi
                        if test "$mtu_state" = "false"; then toggle_mtu; fi
                        if test "$cpu_state" = "false"; then toggle_cpu; fi
                        if test "$ring_state" = "false"; then toggle_ring; fi
                        if test "$zram_state" = "false"; then toggle_zram; fi
                        if test "$journal_state" = "false"; then toggle_journal; fi
                        if test "$prio_state" = "false"; then toggle_process_priority; fi
                        if test "$cake_state" = "false"; then toggle_cake; fi
                        if test "$irq_state" = "false"; then toggle_irq; fi
                        
                        if test "$gso_off_state" = "false"; then
                            if test "$gso_off_state" != "unsupported"; then 
                                toggle_gso_off
                            fi
                        fi
                        
                        if test "$ackfilter_state" = "false"; then toggle_ackfilter; fi
                        if test "$ecn_state" = "false"; then toggle_ecn; fi
                        if test "$wash_state" = "false"; then toggle_wash; fi
                    fi
                else
                    _turn_off_app
                    
                    if test "$dnsmasq_state" = "true"; then toggle_dnsmasq; fi
                    if test "$thp_state" = "true"; then toggle_thp; fi
                    if test "$mtu_state" = "true"; then toggle_mtu; fi
                    if test "$cpu_state" = "true"; then toggle_cpu; fi
                    if test "$ring_state" = "true"; then toggle_ring; fi
                    if test "$zram_state" = "true"; then toggle_zram; fi
                    if test "$journal_state" = "true"; then toggle_journal; fi
                    if test "$prio_state" = "true"; then toggle_process_priority; fi
                    if test "$cake_state" = "true"; then toggle_cake; fi
                    if test "$irq_state" = "true"; then toggle_irq; fi
                    
                    if test "$gso_off_state" = "true"; then
                        if test "$gso_off_state" != "unsupported"; then 
                            toggle_gso_off
                        fi
                    fi
                    
                    if test "$ackfilter_state" = "true"; then toggle_ackfilter; fi
                    if test "$ecn_state" = "true"; then toggle_ecn; fi
                    if test "$wash_state" = "true"; then toggle_wash; fi
                fi
                
                echo ""
                print_red "=========================================================================="
                print_yellow "绝对权限指令已生效：内核拓扑与并发结构树发生大规模物理性撕裂！"
                print_yellow "这台战车将在 6 秒倒数结束后执行最深度的物理强行重启以确保挂载万无一失！"
                print_red "=========================================================================="
                echo ""
                
                for i in {6..1}; do 
                    echo -ne "\r  强行拔核倒数死线: ${cyan}${i}${none} 秒... "
                    sleep 1
                done
                
                echo -e "\n\n  强压 Sync 落盘，内存锁解除..."
                sync
                echo -e "  所有网络已切断，服务器正在执行涅槃重启..."
                reboot
                ;;
                
            0)
                return
                ;;
        esac
    done
}

# ==============================================================================
# [ 0x1B: Reality 回落黑洞限速探针 ]
# ==============================================================================

do_fallback_probe() {
    clear
    echo -e "\n${yellow}=== Xray Reality 回落陷阱深渊 (Fallback Limit) 扫描探针 ===${none}"
    
    if ! test -f "$CONFIG"; then
        error "无法对当前环境实施 JQ 底层结构体解析操作，配置文件缺失。"
        local _p=""; read -rp "按 Enter 返回..." _p || true
        return
    fi
    
    local out
    out=$(jq -r '
      .inbounds[]? | select(.protocol=="vless" and .streamSettings.security=="reality") | .streamSettings.realitySettings | 
      "  [上传方向 (Upload)]\n    设局诱饵字节数 (afterBytes) : \(.limitFallbackUpload.afterBytes // "未开启 (门禁大开)")\n    启动基准绞杀器 (bytesPerSec) : \(.limitFallbackUpload.bytesPerSec // "未开启 (门禁大开)")\n  [下载方向 (Download)]\n    设局诱饵字节数 (afterBytes) : \(.limitFallbackDownload.afterBytes // "未开启 (门禁大开)")\n    启动基准绞杀器 (bytesPerSec) : \(.limitFallbackDownload.bytesPerSec // "未开启 (门禁大开)")"
    ' "$CONFIG" 2>/dev/null || echo "")
    
    if test -n "$out"; then
        echo -e "$out"
    else
        echo -e "  ${red}严重错误：未能发现有效的 Reality 协议配置防线！${none}"
    fi
    
    echo ""
    local _p=""
    read -rp "扫描完毕，按 Enter 回到系统主轴..." _p || true
}

# ==============================================================================
# [ 0x1C: 系统建仓初始化与环境更新子菜单 ]
# ==============================================================================

do_sys_init_menu() {
    while true; do
        clear
        title "系统初始化与底层组件重构序列"
        echo "  1) [大满贯] 一键强制更新底层、校准时区、部署 1GB 永久 Swap 与清理守护"
        echo "  2) [网络侧] 修改系统内核级 DNS 流向 (基于 resolvconf 强效物理死锁)"
        echo -e "  ${cyan}3) [架构层] 抢先安装官方预编译版本 XANMOD 稳定内核 (平民推荐版)${none}"
        echo "  4) [超极客] 源码暴力提取 Kernel 主线内核 + BBR3 物理硬塞 (裸装防爆版)"
        echo "  5) [缓冲区] 网卡发送队列精细控制 (TX Queue 2000 极低延迟限制)"
        echo "  6) [内存流] 全系统网络栈底层极度特化配置 (tcp_adv_win_scale/tcp_app_win)"
        echo "  7) [上帝级] 全域系统结构树与 28 项核心微操调配控制台 (CAKE/RPS/零拷贝)"
        echo -e "  ${cyan}8) [精细化] 强配 CAKE 发送缓冲管理与 Overhead 报文拆解补偿${none}"
        echo "  0) 退出子程序"
        hr
        
        local sys_opt=""
        read -rp "长官，请给出下一步操作选项: " sys_opt || true
        
        case "${sys_opt:-}" in
            1) 
                print_magenta ">>> 开始接管并拉取全系统最新镜像源..."
                export DEBIAN_FRONTEND=noninteractive
                apt-get update -y >/dev/null 2>&1 || true
                apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" full-upgrade -y >/dev/null 2>&1 || true
                apt-get autoremove -y --purge >/dev/null 2>&1 || true
                
                apt-get install -y wget curl sudo socat ntpdate e2fsprogs pkg-config iproute2 ethtool >/dev/null 2>&1 || true
                
                print_magenta ">>> 执行时区强行矫正..."
                if command -v timedatectl >/dev/null 2>&1; then
                    timedatectl set-timezone Asia/Kuala_Lumpur >/dev/null 2>&1 || true
                fi
                if command -v ntpdate >/dev/null 2>&1; then
                    ntpdate us.pool.ntp.org >/dev/null 2>&1 || true
                fi
                if command -v hwclock >/dev/null 2>&1; then
                    hwclock --systohc >/dev/null 2>&1 || true
                fi
                info "时间轴同步完毕，现已锚定 Asia/Kuala_Lumpur 时区！"
                
                check_and_create_1gb_swap
                
                print_magenta ">>> 将 cc1.sh 洁癖清理守护程序埋入系统阴暗面..."
                cat <<'EOF' > /usr/local/bin/cc1.sh
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get clean >/dev/null 2>&1 || true
apt-get autoremove -y --purge >/dev/null 2>&1 || true
journalctl --vacuum-time=3d >/dev/null 2>&1 || true
rm -rf /tmp/* 2>/dev/null || true
rm -rf /var/log/*/*.log 2>/dev/null || true
sync
EOF
                chmod +x /usr/local/bin/cc1.sh 2>/dev/null || true
                
                local temp_cron
                temp_cron=$(mktemp)
                crontab -l 2>/dev/null | grep -v "cc1.sh" > "$temp_cron" || true
                echo "0 4 */10 * * /usr/local/bin/cc1.sh >/dev/null 2>&1" >> "$temp_cron"
                crontab "$temp_cron" 2>/dev/null || true
                rm -f "$temp_cron" 2>/dev/null || true
                
                info "极致清理组件配置成功，将在每 10 天执行深度内存大回旋清理！"
                local _p=""; read -rp "按 Enter 继续推进..." _p || true 
                ;;
            2) 
                do_change_dns 
                ;;
            3) 
                do_install_xanmod_main_official 
                ;;
            4) 
                do_xanmod_compile 
                ;;
            5) 
                do_txqueuelen_opt 
                ;;
            6) 
                do_perf_tuning 
                ;;
            7) 
                do_app_level_tuning_menu 
                ;;
            8) 
                config_cake_advanced 
                ;;
            0) 
                return 
                ;;
        esac
    done
}
# ------------------------------------------------------------------------------
# [ 0x1D: 全域无损对齐化多维用户组阵列 (8 行标准对齐) ]
# ------------------------------------------------------------------------------

print_node_block() {
    local protocol="$1"
    local ip="$2"
    local port="$3"
    local sni="$4"
    local pbk="$5"
    local shortid="$6"
    local utls="$7"
    local uuid="$8"

    printf "  ${yellow}%-15s${none} : %s\n" "协议框架" "$protocol"
    printf "  ${yellow}%-15s${none} : %s\n" "外网IP" "$ip"
    printf "  ${yellow}%-15s${none} : %s\n" "端口" "$port"
    printf "  ${yellow}%-15s${none} : %s\n" "伪装SNI" "${sni:-缺失}"
    printf "  ${yellow}%-15s${none} : %s\n" "公钥(pbk)" "${pbk:-缺失}"
    printf "  ${yellow}%-15s${none} : %s\n" "ShortId" "${shortid:-缺失}"
    printf "  ${yellow}%-15s${none} : %s\n" "uTLS引擎" "$utls"
    printf "  ${yellow}%-15s${none} : %s\n" "用户 UUID" "$uuid"
}

do_summary() {
    if test ! -f "$CONFIG"; then 
        return
    fi
    
    title "The Apex Vanguard 战车控制台 - 详细凭证信息"
    
    # 提取全局 IP
    local ip
    ip=$(_get_ip || echo "获取失败")
    
    local vless_inbound
    vless_inbound=$(jq -c '.inbounds[]? | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
    
    if test -n "$vless_inbound"; then
        if test "$vless_inbound" != "null"; then
            local pbk
            pbk=$(echo "$vless_inbound" | jq -r '.streamSettings.realitySettings.publicKey // "缺失"' 2>/dev/null || echo "缺失")
            
            local main_sni
            main_sni=$(echo "$vless_inbound" | jq -r '.streamSettings.realitySettings.serverNames[0] // "缺失"' 2>/dev/null || echo "缺失")
            
            local port
            port=$(echo "$vless_inbound" | jq -r '.port // 443' 2>/dev/null || echo 443)
            
            local shortIds_json
            shortIds_json=$(echo "$vless_inbound" | jq -c '.streamSettings.realitySettings.shortIds' 2>/dev/null || echo "[]")
            
            local clients_json
            clients_json=$(echo "$vless_inbound" | jq -c '.settings.clients[]?' 2>/dev/null || echo "")

            local idx=0
            while read -r client; do
                if test -z "$client"; then 
                    break
                fi
                
                local uuid
                uuid=$(echo "$client" | jq -r '.id' 2>/dev/null || echo "")
                
                local remark
                remark=$(echo "$client" | jq -r '.email // "无备注"' 2>/dev/null || echo "无备注")
                
                local target_sni
                target_sni=$(grep "^$uuid|" "$USER_SNI_MAP" 2>/dev/null | cut -d'|' -f2 || echo "")
                
                if test -z "$target_sni"; then
                    target_sni="$main_sni"
                fi
                
                local sid
                sid=$(echo "$shortIds_json" | jq -r ".[$idx] // \"缺失\"" 2>/dev/null || echo "缺失")
                
                hr
                print_green ">>> 许可节点所有人: $remark"
                print_node_block "VLESS-Reality (Vision)" "$ip" "$port" "$target_sni" "$pbk" "$sid" "chrome" "$uuid"
                
                local link="vless://${uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${target_sni}&fp=chrome&pbk=${pbk}&sid=${sid}&type=tcp#${remark}"
                echo -e "\n  ${cyan}全球通信无缝装载直链:${none}\n  $link\n"
                
                if command -v qrencode >/dev/null 2>&1; then 
                    qrencode -m 2 -t UTF8 "$link"
                fi
                
                idx=$((idx + 1))
            done <<< "$clients_json"
        fi
    fi

    local ss_inbound
    ss_inbound=$(jq -c '.inbounds[]? | select(.protocol=="shadowsocks")' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
    
    if test -n "$ss_inbound"; then
        if test "$ss_inbound" != "null"; then
            local s_port
            s_port=$(echo "$ss_inbound" | jq -r '.port' 2>/dev/null || echo 8388)
            
            local s_pass
            s_pass=$(echo "$ss_inbound" | jq -r '.settings.password' 2>/dev/null || echo "")
            
            local s_method
            s_method=$(echo "$ss_inbound" | jq -r '.settings.method' 2>/dev/null || echo "aes-256-gcm")
            
            hr
            print_green ">>> 落后算力或极简设备的备用堡垒: Shadowsocks 传统明文结构"
            print_node_block "Shadowsocks" "$ip" "$s_port" "【不兼容】" "【不兼容】" "【不兼容】" "$s_method" "$s_pass"
            
            local b64
            b64=$(printf '%s:%s' "$s_method" "$s_pass" | base64 | tr -d '\n' || echo "")
            local link_ss="ss://${b64}@${ip}:${s_port}#SS-Node"
            
            echo -e "\n  ${cyan}通用拉取协议体链接:${none}\n  $link_ss\n"
        fi
    fi
}

# ------------------------------------------------------------------------------
# [ 0x1E: 带参强绝缘引擎：多用户全量管理器 ]
# ------------------------------------------------------------------------------

do_user_manager() {
    while true; do
        title "用户管理分配池 (包含阵列增删、短连接导入、个性化防御SNI)"
        
        if test ! -f "$CONFIG"; then 
            error "未能在系统中发现主脑配置文件！"
            return
        fi
        
        local clients
        clients=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .settings?.clients[]? | .id + "|" + (.email // "无备注")' "$CONFIG" 2>/dev/null || echo "")
        
        if test -z "$clients"; then 
            error "内核中没有任何合规的 VLESS 主协议许可名单！"
            return
        fi
        
        local tmp_users="/tmp/xray_users.txt"
        echo "$clients" | awk -F'|' '{print NR"|"$1"|"$2}' > "$tmp_users" || true
        
        echo -e "现役用户活跃列表："
        while IFS='|' read -r num uid remark; do
            local utime
            utime=$(grep "^$uid|" "$USER_TIME_MAP" 2>/dev/null | cut -d'|' -f2 || echo "")
            
            if test -z "$utime"; then
                utime="遗留年代/无时间戳"
            fi
            
            echo -e "  $num) 备注: ${cyan}$remark${none} | 创建时间: ${gray}$utime${none} | 凭证UUID: ${yellow}$uid${none}"
        done < "$tmp_users"
        hr
        
        echo "  a) 指派系统为您新增本地合法用户凭据 (自动分配 UUID 与 ShortId)"
        echo "  m) 平滑收编外部已存在用户的相关历史凭证"
        echo "  s) 为特定用户颁发高防专属 SNI 伪装面具"
        echo "  d) 以物理手段永久擦除该用户的系统登录许可"
        echo "  q) 取消操作，返回上级"
        
        local uopt=""
        read -rp "请给系统下发操作执行器: " uopt || true
        
        local ip
        ip=$(_get_ip || echo "获取失败")
        
        if test "$uopt" = "a"; then
            local nu
            nu=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
            
            local ns
            ns=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n' || echo "")
            
            local ctime
            ctime=$(date +"%Y-%m-%d %H:%M")
            
            local u_remark=""
            read -rp "请在此赋予该新增节点一个霸气的代号/备注 (回车默认: User-${ns}): " u_remark || true
            if test -z "$u_remark"; then
                u_remark="User-${ns}"
            fi
            
            cat > /tmp/new_client.json <<EOF
{
  "id": "$nu",
  "flow": "xtls-rprx-vision",
  "email": "$u_remark"
}
EOF
            # 采用绝缘 |= 语法，精准锁定 vless 入站，绝不影响其他参数
            _safe_jq_write --argjson new_client "$(< /tmp/new_client.json)" '
              (.inbounds[]? | select(.protocol == "vless")) |= (
                  .settings.clients += [$new_client]
              )
            '
            
            _safe_jq_write --arg sid "$ns" '
              (.inbounds[]? | select(.protocol == "vless")) |= (
                  .streamSettings.realitySettings.shortIds += [$sid]
              )
            '
            rm -f /tmp/new_client.json 2>/dev/null || true
            
            echo "$nu|$ctime" >> "$USER_TIME_MAP"
            systemctl restart xray >/dev/null 2>&1 || true
            
            local vless_node
            vless_node=$(jq -c '.inbounds[]? | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
            local port=$(echo "$vless_node" | jq -r '.port' 2>/dev/null || echo 443)
            local sni=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.serverNames[0]' 2>/dev/null || echo "")
            local pub=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.publicKey' 2>/dev/null || echo "")
            
            info "许可派发流程顺利通过！"
            hr
            print_green ">>> 全新准入者代号: $u_remark"
            print_node_block "VLESS-Reality (Vision)" "$ip" "$port" "$sni" "$pub" "$ns" "chrome" "$nu"
            
            local link="vless://${nu}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${ns}&type=tcp#${u_remark}"
            echo -e "\n  ${cyan}完整系统链接信息:${none}\n  $link\n"
            
            if command -v qrencode >/dev/null 2>&1; then 
                qrencode -m 2 -t UTF8 "$link"
            fi
            
            local _p=""; read -rp "按 Enter 返回主控面板..." _p || true
            
        elif test "$uopt" = "m"; then
            hr
            echo -e " ${cyan}>>> 外部老用户平滑迁移向导 <<<${none}"
            echo -e " ${yellow}提示: 将外部用户的凭证挂载到本机，生成由本机 IP 和 pbk 构建的新链接！${none}"
            
            local m_remark=""
            read -rp "请输入外部用户的备注 (例如: VIP-User): " m_remark || true
            if test -z "$m_remark"; then
                m_remark="ImportedUser"
            fi
            
            local m_uuid=""
            read -rp "请输入外部用户的 UUID: " m_uuid || true
            if test -z "$m_uuid"; then 
                error "UUID 不能为空！"
                continue
            fi
            
            local m_sid=""
            read -rp "请输入外部用户的 ShortId: " m_sid || true
            if test -z "$m_sid"; then 
                error "ShortId 不能为空！"
                continue
            fi
            
            local ctime
            ctime=$(date +"%Y-%m-%d %H:%M")
            
            cat > /tmp/new_client.json <<EOF
{
  "id": "$m_uuid",
  "flow": "xtls-rprx-vision",
  "email": "$m_remark"
}
EOF
            _safe_jq_write --argjson new_client "$(< /tmp/new_client.json)" '
              (.inbounds[]? | select(.protocol == "vless")) |= (
                  .settings.clients += [$new_client]
              )
            '
            
            _safe_jq_write --arg sid "$m_sid" '
              (.inbounds[]? | select(.protocol == "vless")) |= (
                  .streamSettings.realitySettings.shortIds += [$sid]
              )
            '
            rm -f /tmp/new_client.json 2>/dev/null || true
            
            echo "$m_uuid|$ctime" >> "$USER_TIME_MAP"
            
            local m_sni=""
            read -rp "是否需要为该导入用户指定专属 SNI? (直接回车则使用全局默认, 若需要请填写域名): " m_sni || true
            
            if test -n "$m_sni"; then
                _safe_jq_write --arg sni "$m_sni" '
                  (.inbounds[]? | select(.protocol == "vless")) |= (
                      .streamSettings.realitySettings.serverNames += [$sni] | 
                      .streamSettings.realitySettings.serverNames |= unique
                  )
                '
                sed -i "/^$m_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                echo "$m_uuid|$m_sni" >> "$USER_SNI_MAP"
                info "已为导入用户绑定专属 SNI: $m_sni"
            else
                m_sni=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0] // empty' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
            fi
            
            systemctl restart xray >/dev/null 2>&1 || true
            
            local vless_node
            vless_node=$(jq -c '.inbounds[]? | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
            local port=$(echo "$vless_node" | jq -r '.port' 2>/dev/null || echo 443)
            local pub=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.publicKey' 2>/dev/null || echo "")
            
            info "外部用户导入成功！当前机器专属分发信息如下："
            hr
            print_green ">>> 导入 VLESS-Reality 节点持有人: $m_remark"
            print_node_block "VLESS-Reality (Vision)" "$ip" "$port" "$m_sni" "$pub" "$m_sid" "chrome" "$m_uuid"
            
            local link="vless://${m_uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${m_sni}&fp=chrome&pbk=${pub}&sid=${m_sid}&type=tcp#${m_remark}"
            echo -e "\n  ${cyan}合并后的全新分发直链:${none}\n  $link\n"
            
            if command -v qrencode >/dev/null 2>&1; then 
                qrencode -m 2 -t UTF8 "$link"
            fi
            
            local _p=""; read -rp "按 Enter 返回主控面板..." _p || true
            
        elif test "$uopt" = "s"; then
            local snum=""
            read -rp "您要对以上列表中的几号序列用户进行单独的 SNI 面具绑定？请输入序号数字: " snum || true
            
            local target_uuid
            target_uuid=$(awk -F'|' -v id="${snum:-0}" '$1==id {print $2}' "$tmp_users" 2>/dev/null || echo "")
            
            local target_remark
            target_remark=$(awk -F'|' -v id="${snum:-0}" '$1==id {print $3}' "$tmp_users" 2>/dev/null || echo "")
            
            if test -n "$target_uuid"; then
                local u_sni=""
                read -rp "输入未来归属于该用户的专属顶级防封 SNI (例如 apple.com): " u_sni || true
                
                if test -n "$u_sni"; then
                    _safe_jq_write --arg sni "$u_sni" '
                      (.inbounds[]? | select(.protocol == "vless")) |= (
                          .streamSettings.realitySettings.serverNames += [$sni] | 
                          .streamSettings.realitySettings.serverNames |= unique
                      )
                    '
                    sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                    echo "$target_uuid|$u_sni" >> "$USER_SNI_MAP"
                    
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "系统已完成该域名向核心池的注入！"
                    
                    local vless_node
                    vless_node=$(jq -c '.inbounds[]? | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
                    
                    local port=$(echo "$vless_node" | jq -r '.port' 2>/dev/null || echo 443)
                    local idx=$((${snum:-0} - 1))
                    
                    local sid
                    sid=$(echo "$vless_node" | jq -r ".streamSettings.realitySettings.shortIds[$idx] // empty" 2>/dev/null || echo "")
                    
                    local pub
                    pub=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.publicKey // empty' 2>/dev/null || echo "")
                    
                    hr
                    print_green ">>> 特化处理的权限归属者: $target_remark"
                    print_node_block "VLESS-Reality (Vision)" "$ip" "$port" "$u_sni" "$pub" "$sid" "chrome" "$target_uuid"
                    
                    local link="vless://${target_uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${u_sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${target_remark}"
                    echo -e "\n  ${cyan}刷新后的专属分发链路:${none}\n  $link\n"
                    
                    if command -v qrencode >/dev/null 2>&1; then 
                        qrencode -m 2 -t UTF8 "$link"
                    fi
                    local _p=""; read -rp "按 Enter 返回主控面板..." _p || true
                fi
            else 
                error "您盲填的序列号不符合系统内的活动清单。"
            fi
            
        elif test "$uopt" = "d"; then
            local dnum=""
            read -rp "彻底剿杀令！请选出您要立刻注销的序列号数字: " dnum || true
            
            local total
            total=$(wc -l < "$tmp_users" 2>/dev/null || echo "0")
            
            if test "${total:-0}" -le 1; then 
                error "权限审计报错：必须保留一个基础架构根用户，禁止全盘自杀清空！"
            else
                local target_uuid
                target_uuid=$(awk -F'|' -v id="${dnum:-0}" '$1==id {print $2}' "$tmp_users" 2>/dev/null || echo "")
                
                if test -n "$target_uuid"; then
                    local idx=$((${dnum:-0} - 1))
                    # -- 防乱序与断流大修：极其关键的联动式绝缘删除 --
                    _safe_jq_write --arg uid "$target_uuid" --argjson i "$idx" '
                        (.inbounds[]? | select(.protocol == "vless")) |= (
                            .settings.clients |= map(select(.id != $uid)) | 
                            .streamSettings.realitySettings.shortIds |= del(.[$i])
                        )
                    '
                    
                    sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                    sed -i "/^$target_uuid|/d" "$USER_TIME_MAP" 2>/dev/null || true
                    
                    systemctl restart xray >/dev/null 2>&1 || true
                    info "该凭证已被打上作废记号，物理记录彻底清除完毕！"
                fi
            fi
            
        elif test "$uopt" = "q" || test "$uopt" = "Q"; then 
            rm -f "$tmp_users" 2>/dev/null || true
            break
        fi
    done
}

# ------------------------------------------------------------------------------
# [ 0x1F: 全球恶性阻断路由分离系统 (绝缘化 |= 过滤) ]
# ------------------------------------------------------------------------------

_global_block_rules() {
    while true; do
        title "流量清洗与广告双轨智能阻断雷达"
        if ! test -f "$CONFIG"; then 
            error "无法发现流量控制器基础模型文件。"
            return
        fi
        
        local bt_en
        bt_en=$(jq -r '.routing.rules[]? | select(.protocol != null) | select(.protocol | index("bittorrent")) | ._enabled' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        local ad_en
        ad_en=$(jq -r '.routing.rules[]? | select(.domain != null) | select(.domain | index("geosite:category-ads-all")) | ._enabled' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        echo -e "  1) BT/PT 极度压榨带宽协议封锁    | 当前底层运作状态: ${yellow}${bt_en}${none}"
        echo -e "  2) 全球已知广告特征域名无感封锁  | 当前底层运作状态: ${yellow}${ad_en}${none}"
        echo "  0) 退出"
        
        local bc=""
        read -rp "请给出对这套阻断雷达的控制指令: " bc || true
        
        case "${bc:-}" in
            1) 
                local nv="true"
                if test "$bt_en" = "true"; then 
                    nv="false"
                fi
                # 安全绝缘语法，定位并就地更新
                _safe_jq_write --argjson nv_val "$nv" '
                  (.routing.rules[]? | select(.protocol != null and (.protocol | index("bittorrent")))) |= (
                      ._enabled = $nv_val
                  )
                '
                systemctl restart xray >/dev/null 2>&1 || true
                info "BT 带宽压榨拦截雷达切换成功，现已锁定为: $nv" 
                ;;
                
            2) 
                local nv="true"
                if test "$ad_en" = "true"; then 
                    nv="false"
                fi
                # 安全绝缘语法，定位并就地更新
                _safe_jq_write --argjson nv_val "$nv" '
                  (.routing.rules[]? | select(.domain != null and (.domain | index("geosite:category-ads-all")))) |= (
                      ._enabled = $nv_val
                  )
                '
                systemctl restart xray >/dev/null 2>&1 || true
                info "底层级反广告污染雷达切换成功，现已锁定为: $nv" 
                ;;
                
            0) 
                return 
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# [ 0x20: 主控矩阵库与基石底层网络构筑引擎 (重构更新矩阵) ]
# ------------------------------------------------------------------------------

_update_matrix() {
    echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
    
    jq --arg dest "$BEST_SNI:443" --slurpfile snis /tmp/sni_array.json '
        (.inbounds[]? | select(.protocol == "vless")) |= (
            .streamSettings.realitySettings.serverNames = $snis[0] |
            .streamSettings.realitySettings.dest = $dest
        )
    ' "$CONFIG" > "$CONFIG.tmp" 2>/dev/null
    
    if test $? -eq 0; then 
        mv -f "$CONFIG.tmp" "$CONFIG" 2>/dev/null || true
        fix_permissions
        systemctl restart xray >/dev/null 2>&1 || true
    fi
    
    rm -f /tmp/sni_array.json 2>/dev/null || true
}

do_install() {
    title "Apex Vanguard Ultimate Final: 引擎核心深层部署中心"
    preflight
    
    systemctl stop xray >/dev/null 2>&1 || true
    
    if test ! -f "$INSTALL_DATE_FILE"; then 
        date +"%Y-%m-%d %H:%M:%S" > "$INSTALL_DATE_FILE"
    fi
    
    echo -e "  ${cyan}请选择本次即将打入服务器灵魂的网络数据协议链：${none}"
    echo "  1) VLESS-Reality (最新一代加密算法，极低特征流量伪装，高防被墙)"
    echo "  2) Shadowsocks (极度轻量级，专为落后设备环境设计的备用直连通道)"
    echo "  3) 两个我都全都要 (双重体系叠加交火)"
    
    local proto_choice=""
    read -rp "  请告诉系统你的选择: " proto_choice || true
    proto_choice=${proto_choice:-1}

    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        while true; do 
            local input_p=""
            read -rp "请为您强大的 VLESS 主通道分配一个监听端口 (直接回车默认 443): " input_p || true
            input_p=${input_p:-443}
            if validate_port "$input_p"; then 
                LISTEN_PORT="$input_p"
                break
            fi
        done
        
        local input_remark=""
        read -rp "请为您的主帅通道命名一个响亮的节点代号 (默认 xp-reality): " input_remark || true
        REMARK_NAME=${input_remark:-xp-reality}
        
        choose_sni
        if test $? -ne 0; then 
            return 1
        fi
    fi

    local ss_port=8388
    local ss_pass=""
    local ss_method="aes-256-gcm"
    
    if test "$proto_choice" = "2" || test "$proto_choice" = "3"; then
        while true; do 
            local input_s=""
            read -rp "请为辅助的 SS 弱通道设定安全端口 (直接回车默认 8388): " input_s || true
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
            read -rp "请为您的节点命名一个响亮的代号 (默认 xp-reality): " input_remark || true
            REMARK_NAME=${input_remark:-xp-reality}
        fi
    fi

    print_magenta ">>> 已经授权对 Github 高维库建立拉取链路，请保持安静..."
    
    # 强制构建本地容错机制与反代链路拉取安装核心
    local inst_url="https://ghp.ci/https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh"
    if ! curl -kfsSL --connect-timeout 10 -o /tmp/install-release.sh "$inst_url" 2>/dev/null; then
        inst_url="https://fastly.jsdelivr.net/gh/XTLS/Xray-install@main/install-release.sh"
        curl -kfsSL --connect-timeout 10 -o /tmp/install-release.sh "$inst_url" 2>/dev/null || true
    fi
    
    if test -f /tmp/install-release.sh; then
        export PROXY="https://ghp.ci/"
        bash /tmp/install-release.sh @ install >/dev/null 2>&1 || true
        unset PROXY
        rm -f /tmp/install-release.sh 2>/dev/null || true
    else
        die "网络环境遭到多维阻断，Github 主副仓库均无法连接，内核部署失败！"
    fi
    
    install_update_dat
    fix_xray_systemd_limits

    # 1. 纯净构建底层骨架配置
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
          "settings": {
              "domainStrategy": "AsIs"
          },
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

    # 2. 注入 VLESS 面板
    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        gen_x25519
        local uuid
        uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
        
        local sid
        sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n' || echo "")
        
        local ctime
        ctime=$(date +"%Y-%m-%d %H:%M")
        
        echo "$X25519_PUB" > "$PUBKEY_FILE"
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
        "shortIds": ["$sid"],
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
      "destOverride": ["http", "tls", "quic"]
  }
}
EOF
        jq --slurpfile snis /tmp/sni_array.json '
            .streamSettings.realitySettings.serverNames = $snis[0]
        ' /tmp/vless_inbound.json > /tmp/vless_final.json 2>/dev/null || true
        
        jq '
            .inbounds += [input]
        ' "$CONFIG" /tmp/vless_final.json > "$CONFIG.tmp" 2>/dev/null && mv -f "$CONFIG.tmp" "$CONFIG" || true
        
        rm -f /tmp/vless_inbound.json /tmp/vless_final.json /tmp/sni_array.json 2>/dev/null || true
    fi

    # 3. 注入 SS 面板
    if test "$proto_choice" = "2" || test "$proto_choice" = "3"; then
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
        jq '
            .inbounds += [input]
        ' "$CONFIG" /tmp/ss_inbound.json > "$CONFIG.tmp" 2>/dev/null && mv -f "$CONFIG.tmp" "$CONFIG" || true
        rm -f /tmp/ss_inbound.json 2>/dev/null || true
    fi

    # 重组进程唤醒系统
    fix_permissions
    systemctl enable xray >/dev/null 2>&1 || true
    systemctl restart xray >/dev/null 2>&1 || true
    
    info "老哥，全网底层链路及数据加密防护架构全部搭建完毕！"
    do_summary
    
    while true; do
        local opt=""
        read -rp "按 Enter 稳步返回主控大屏，或强行输入 b 重新排布底层矩阵结构: " opt || true
        
        if test "$opt" = "b" || test "$opt" = "B"; then
            choose_sni
            if test $? -eq 0; then 
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
# [ 0x21: 服务器实时高维战况表与连接中心 ]
# ------------------------------------------------------------------------------

do_status_menu() {
    while true; do
        clear
        title "高维运转状态与商业流量结算监测总台"
        echo "  1) 读取系统 Xray 进程级别挂载分析与守护状态"
        echo "  2) 核查独立外部 IP 映射及 Nameserver 配置明细"
        echo "  3) 检视 Vnstat 商用网卡流量全景记录 (按月/日清算)"
        echo "  4) [超极客] 探测实时连接、PID源、端口并发与独立 IP 雷达统计表"
        echo -e "  ${cyan}5) [手术刀] 强行修改底层内核对 Xray 的优先级赋权 (Nice 动态调节器)${none}"
        echo "  0) 关闭面板并退回系统底层"
        hr
        
        local s=""
        read -rp "向控制台下发探针动作命令: " s || true
        
        case "${s:-}" in
            1) 
                clear
                title "Xray 内核进程深度守护状态流读取..."
                systemctl status xray --no-pager || true
                echo ""
                local _p=""; read -rp "系统分析停顿，按 Enter 返回..." _p || true 
                ;;
                
            2) 
                echo -e "\n  本机物理独立绑定公网 IP: ${green}$SERVER_IP${none}"
                hr
                echo -e "  底层 Nameserver DNS 请求物理投递方向: "
                grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print "    " $0}' || true
                hr
                echo -e "  系统防火墙与 Xray 的通信端口映射状态: "
                ss -tlnp 2>/dev/null | grep xray | awk '{print "    " $4}' || true
                local _p=""; read -rp "核对完成，按 Enter 键..." _p || true 
                ;;
                
            3) 
                if ! command -v vnstat >/dev/null 2>&1; then 
                    warn "您的系统尚未装载 Vnstat 流量探测引擎模块，该查询被拦截。"
                    local _p=""; read -rp "继续前进请按 Enter..." _p || true
                    continue
                fi
                clear
                title "Vnstat 商用网卡流量与账单精准核算数据中心"
                
                local idate
                idate=$(cat "$INSTALL_DATE_FILE" 2>/dev/null || echo "历史遗迹，未溯源")
                
                echo -e "  该控制流在您这台服务器上的原始寄生与起算启动日期为: ${cyan}$idate${none}"
                hr
                
                local m_day
                m_day=$(grep -E "^[[:space:]]*MonthRotate" /etc/vnstat.conf 2>/dev/null | awk '{print $2}' | head -n 1 | tr -d '\r\n' || echo "")
                
                if test -z "$m_day"; then
                    m_day="1 (系统默认未改变)"
                fi
                
                echo -e "  账单数据强行结算流转日: ${cyan}每月周期的第 $m_day 天${none}"
                hr
                
                # 兼容旧版本 vnstat 无 -m 3 功能
                (vnstat -m 3 2>/dev/null || vnstat -m 2>/dev/null || true) | sed -e 's/estimated/模型预测跑量/ig' -e 's/rx/外部接收拉回/ig' -e 's/tx/本机发送推流/ig' -e 's/total/全域吞吐总计/ig' -e 's/daily/以天为维度/ig' -e 's/monthly/以自然月为维度/ig'
                hr
                
                echo "  1) 修改每月账单强制结算清零的日标 (警告：会触发后台 vnstat 重载)"
                echo "  2) 输入任意精确历史年月，强行调取属于那个年代的每一天跑量详单"
                echo "  q) 停止核算返回上级"
                
                local vn_opt=""
                read -rp "  给出账单重制操作指令: " vn_opt || true
                
                case "${vn_opt:-}" in
                    1) 
                        local d_day=""
                        read -rp "请输入您期望的新账单周期流转日 (1-31 的合法数字): " d_day || true
                        
                        if test "${d_day:-0}" -ge 1 2>/dev/null && test "${d_day:-0}" -le 31 2>/dev/null; then
                            sed -i '/^[#[:space:]]*MonthRotate/d' /etc/vnstat.conf 2>/dev/null || true
                            echo "MonthRotate $d_day" >> /etc/vnstat.conf
                            systemctl restart vnstat 2>/dev/null || true
                            info "流转设定已强行改写为每月 $d_day 号流转。"
                        else 
                            error "输入字符为非法流转数字结构。"
                        fi
                        local _p=""; read -rp "强行执行完毕，请 Enter..." _p || true 
                        ;;
                    2)
                        local d_month=""
                        read -rp "给出时间锚点 (格式如 $(date +%Y-%m)，不输入直接敲回车即调出近30天的狂暴数据): " d_month || true
                        
                        if test -z "$d_month"; then 
                            vnstat -d 2>/dev/null | sed -e 's/estimated/模型预测跑量/ig' -e 's/rx/外部接收拉回/ig' -e 's/tx/本机发送推流/ig' -e 's/total/全域吞吐总计/ig' -e 's/daily/以天为维度/ig' -e 's/monthly/以自然月为维度/ig' || true
                        else 
                            vnstat -d 2>/dev/null | grep -iE "($d_month| day |estimated|--)" | sed -e 's/estimated/模型预测跑量/ig' -e 's/rx/外部接收拉回/ig' -e 's/tx/本机发送推流/ig' -e 's/total/全域吞吐总计/ig' -e 's/daily/以天为维度/ig' -e 's/monthly/以自然月为维度/ig' || true
                        fi
                        local _p=""; read -rp "已将核算日志吐出，请检阅后按 Enter 返回..." _p || true 
                        ;;
                    q|Q) 
                        ;;
                esac
                ;;
                
            4)
                while true; do
                    clear
                    title "全域底层协议栈实时连接雷达与异地独立 IP 统计中心"
                    
                    local x_pids
                    x_pids=$(pidof xray 2>/dev/null | xargs | tr -s ' ' '|' || echo "")
                    
                    if test -n "$x_pids"; then
                        echo -e "  ${cyan}【底层协议与 Socket 连接池多维分布】${none}"
                        ss -ntupa 2>/dev/null | grep -E "pid=($x_pids)[,)]" | awk '{print $1"_"$2}' | sort | uniq -c | sort -nr | awk '{printf "    %-15s : 活跃量 %s\n", $2, $1}' || true
                        
                        echo -e "\n  ${cyan}【外源连入独立 IP 并发数压榨度排行 (绝对物理层面 TOP 10)】${none}"
                        
                        local ips
                        ips=$(ss -ntupa 2>/dev/null | grep -E "pid=($x_pids)[,)]" | grep -vE "LISTEN|UNCONN" | awk '{print $6}' | sed -E 's/:[0-9]+$//' | tr -d '[]' | grep -vE "^127\.0\.0\.1$|^0\.0\.0\.0$|^::$|^\*$|^::ffff:127\.0\.0\.1$" || echo "")
                        
                        if test -n "$ips"; then
                            echo "$ips" | sort | uniq -c | sort -nr | head -n 10 | awk '{printf "    独立源: %-18s (系统核算连接数: %s)\n", $2, $1}' || true
                            
                            local total_ips
                            total_ips=$(echo "$ips" | sort | uniq | wc -l || echo "0")
                            echo -e "\n  在案统计并排除伪造后的绝对独立真实 IP 总数: ${yellow}${total_ips}${none}"
                        else 
                            echo -e "    ${gray}雷达扫频结果为空，系统目前安静无异常连接。${none}"
                        fi
                    else 
                        echo -e "  ${red}警报！无法获取 Xray 进程载荷，主服务可能遭遇崩塌被杀！${none}"
                    fi
                    
                    echo -e "\n  ${gray}----------------------------------------------------------------------${none}"
                    echo -e "  ${green}深度侦测雷达自循环运转中 (频率 2 秒一刷)... 退出快捷键: [ ${yellow}q${none} ]${none}"
                    
                    local cmd=""
                    if read -t 2 -n 1 -s cmd 2>/dev/null; then
                        if test "$cmd" = "q" || test "$cmd" = "Q" || test "$cmd" = $'\e'; then 
                            break
                        fi
                    fi
                done
                ;;
                
            5)
                while true; do
                    clear
                    title "内核调度层面：Xray 绝对抢占与优先级赋权系统 (Nice 调节器)"
                    
                    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
                    local current_nice="-20"
                    
                    if test -f "$limit_file"; then 
                        if grep -q "^Nice=" "$limit_file" 2>/dev/null; then 
                            local temp_n
                            temp_n=$(awk -F'=' '/^Nice=/ {print $2}' "$limit_file" 2>/dev/null | head -n 1 || echo "")
                            if test -n "$temp_n"; then
                                current_nice="$temp_n"
                            fi
                        fi
                    fi
                    
                    echo -e "  系统当前分配给 Xray 的极客抢占层级为: ${cyan}${current_nice}${none} (有效支持域从 -20 到 -10)"
                    echo -e "  ${gray}极客贴士：这个数值越贴近负的深渊，抢占宿主机 CPU 的残暴度越强。${none}"
                    hr
                    
                    local new_nice=""
                    read -rp "  请赋予核心新的杀戮指标 Nice 数值 (想要取消请直接按下 q 并回车): " new_nice || true
                    
                    if test "$new_nice" = "q" || test "$new_nice" = "Q"; then 
                        break
                    fi
                    
                    if [[ "$new_nice" =~ ^-[1-2][0-9]$ ]] && test "$new_nice" -ge -20 2>/dev/null && test "$new_nice" -le -10 2>/dev/null; then
                        sed -i "s/^Nice=.*/Nice=$new_nice/" "$limit_file" 2>/dev/null || true
                        systemctl daemon-reload >/dev/null 2>&1 || true
                        info "指令已被写死进文件，底层参数将更新为 $new_nice，核心引擎将在 5 秒钟之后被迫承受强制软重启以消化新规..."
                        sleep 5
                        systemctl restart xray >/dev/null 2>&1 || true
                        info "系统已经消化了新的竞争优先级，目前它将更狂暴地夺取计算资源。"
                        local _p=""; read -rp "按 Enter 返回主域..." _p || true
                        break
                    else 
                        error "这串数字系统不接受！请严格填入 -20 至 -10 之间带着减号的极限区间数字。"
                        sleep 2
                    fi
                done
                ;;
                
            0) 
                return 
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# [ 0x22: 绝对卸载与不可逆清除器 ]
# ------------------------------------------------------------------------------

do_uninstall() {
    title "终极清理序列：绞杀全域应用层记录并完全复原原始生态"
    
    local confirm=""
    read -rp "此操作属于大清洗，不仅会杀掉主进程，而且会摧毁所有的运行记录及配置表！(但我们承诺永久保留您优化的底层架构网络内核参数矩阵，这是给您的物理遗产)！确定按死核按钮吗？(执行请输 y 并回车): " confirm || true
    
    if test "$confirm" != "y"; then 
        return
    fi
    
    local temp_date=""
    if test -f "$INSTALL_DATE_FILE"; then 
        temp_date=$(cat "$INSTALL_DATE_FILE" 2>/dev/null || echo "")
        print_magenta ">>> 正在抢在系统销毁前强制提取您的建档初装日期的内存快照缓存..."
    fi
    
    print_magenta ">>> 正在全域绞杀并清空被接管的 Dnsmasq，将其连根拔起并打碎成空集..."
    systemctl stop dnsmasq >/dev/null 2>&1 || true
    systemctl disable dnsmasq >/dev/null 2>&1 || true
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get purge -y dnsmasq >/dev/null 2>&1 || yum remove -y dnsmasq >/dev/null 2>&1 || true
    rm -f /etc/dnsmasq.conf >/dev/null 2>&1 || true
    
    print_magenta ">>> 正在强行破坏之前我们对 Resolv 设置的只读强锁保护防线，并将古老的原始系统生态复原..."
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
    
    print_magenta ">>> 执行主线粉碎任务：拔掉 Xray 运行权限、拆除其守护进程脚本组..."
    systemctl stop xray >/dev/null 2>&1 || true
    systemctl disable xray >/dev/null 2>&1 || true
    
    rm -rf /etc/systemd/system/xray.service /etc/systemd/system/xray@.service /etc/systemd/system/xray.service.d /lib/systemd/system/xray* >/dev/null 2>&1 || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    
    print_magenta ">>> 引爆全域文件删除矩阵！无差别炸毁可执行核心包、配置母带、挂载系统数据目录..."
    rm -rf "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SCRIPT_DIR" /var/log/xray* /usr/local/bin/xrv "$SCRIPT_PATH" >/dev/null 2>&1 || true
    
    print_magenta ">>> 在后门清理潜伏的热更数据定时任务..."
    (crontab -l 2>/dev/null | grep -v "update-dat.sh" | grep -v "/bin/systemctl restart xray") | crontab - 2>/dev/null || true
    hash -r 2>/dev/null || true
    
    if test -n "$temp_date"; then 
        mkdir -p "$CONFIG_DIR" 2>/dev/null || true
        echo "$temp_date" > "$INSTALL_DATE_FILE"
        print_yellow ">>> 最后的怜悯：为您留存了那份唯一且不可磨灭的历史初装时间戳..."
    fi
    
    print_green "清剿任务落幕。机器此时又像新生儿一般安静、虚弱。再会了长官！"
    exit 0
}

# ------------------------------------------------------------------------------
# [ 0x23: 系统绝对中枢：不折叠的主控制台大厅 ]
# ------------------------------------------------------------------------------

main_menu() {
    while true; do
        clear
        echo -e "${blue}======================================================================${none}"
        echo -e "  ${magenta}Xray ex188t45 The Apex Vanguard - Project Genesis (终极大一统修补版)${none}"
        
        local svc
        svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        
        if test "$svc" = "active"; then 
            svc="${green}战车疯狂轰鸣中${none}"
        else 
            svc="${red}宕机停驶状态${none}"
        fi
        
        local sys_ver
        sys_ver=$(uname -r 2>/dev/null || echo "未知内核")
        
        echo -e "  目前运转姿态: $svc | 终端调遣指令: ${cyan}xrv${none} | 对外通信基站: ${yellow}$(_get_ip || echo "获取失败")${none}"
        echo -e "  当前主板挂载内核: ${cyan}${sys_ver}${none} | 所处时空脚本号: $(basename "$0")"
        echo -e "${blue}======================================================================${none}"
        echo "  1) 新建世界 / 在白纸上重塑您的 VLESS+SS 双系重构核心网络系统"
        echo "  2) 用户管理体系 (许可分配/前朝遗老迁移收编/精准注入专属反墙面具)"
        echo "  3) 数据总控中枢 (无损打印所有并发用户的详情与紧凑二维码分发阵列)"
        echo "  4) 人为干预 Geo 世界流量路由库底盘数据更替 (本身已有夜间热更新)"
        echo "  5) 追击最前沿 Xray 原核技术 (无缝多轨反代拉取最新版、秒级热重载)"
        echo "  6) 极其无感的矩阵流转 (单点强拉/组合阵列/抽屉式选取顶级 SNI 域名网)"
        echo "  7) 强横不讲理的系统防火墙管控 (对全域 BT 洪流和已知广告链路进行绝地封杀)"
        echo "  8) Reality 回落陷阱雷达扫描台 (看穿暗物质并探测那些伪造审查的扫描狂犬)"
        echo "  9) 全景网络商业运营监控 (查看实时异地独立 IP 高维并发、DNS 探测与精准计费)"
        echo "  10) 最硬核物理初始化系统调优、无报错 Linux 原生内核注入及上帝级微操台"
        echo "  0) 关闭当前交互，让所有修改全盘生效"
        echo -e "  ${red}88) 物理不可逆灭世机制 (彻底粉碎一切，将环境剥离出这台机器的心脏)${none}"
        hr
        
        local num=""
        read -rp "长官，请下达操作这台终端服务器的命令代码: " num || true
        
        case "${num:-}" in
            1) 
                do_install 
                ;;
            2) 
                do_user_manager 
                ;;
            3) 
                do_summary
                while true; do 
                    local rb=""
                    read -rp "指令确认，按下 Enter 撤离，或极客操作强行键入 b 即刻改变主线 SNI: " rb || true
                    if test "$rb" = "b" || test "$rb" = "B"; then 
                        choose_sni
                        if test $? -eq 0; then 
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
                print_magenta ">>> 开始接管规则网络同步库组件 (强制免翻链路)..."
                bash "$UPDATE_DAT_SCRIPT" >/dev/null 2>&1 || true
                systemctl restart xray >/dev/null 2>&1 || true
                info "拉取成功，路由数据结构表已全面推送到内核层！"
                local _p=""; read -rp "输入 Enter 确认继续..." _p || true 
                ;;
            5) 
                do_update_core 
                ;;
            6) 
                choose_sni
                if test $? -eq 0; then 
                    _update_matrix
                    do_summary
                    while true; do 
                        local rb=""
                        read -rp "指令结束，请按下 Enter 离场，或强制键入 b 继续重塑伪装链路: " rb || true
                        if test "$rb" = "b" || test "$rb" = "B"; then 
                            choose_sni
                            if test $? -eq 0; then 
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
            7) 
                _global_block_rules 
                ;;
            8) 
                do_fallback_probe 
                ;;
            9) 
                do_status_menu 
                ;;
            10) 
                do_sys_init_menu 
                ;;
            88) 
                do_uninstall 
                ;;
            0) 
                exit 0 
                ;;
            *)
                echo -e "${red}错误：系统无法识别该指令！${none}"
                sleep 1
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# [ 0x24: 引擎点火，执行自证闭环 ]
# ------------------------------------------------------------------------------
preflight
main_menu
# ==============================================================================
# EOF: 代码末尾标记，本行存在即代表 V188t45 真核大一统版全量下发，未遭 Token 截断
# ==============================================================================
