#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: ex188t34ca.sh
# 快捷方式: xrv
# 版本: ca (融合修复优化版)
#
# 修复清单 (相对 ex188t34.sh):
#   [F1] 补全缺失函数 do_txqueuelen_opt / do_perf_tuning
#   [F2] verify_xray_config 改用 exit code 判断，兼容新旧 Xray
#   [F3] 安装循环改为下载到临时文件再执行，修复 $() 展开破坏脚本内容的问题
#   [F4] trap/_err_handler 移到函数定义之后，消除顺序依赖崩溃
#   [F5] 路由规则补全 "type":"field"，修复规则被 Xray 静默忽略的问题
#   [F6] cleanup_temp_files 路径与实际临时文件对齐
#   [F7] 脚本顶部加 bash 版本守卫，防止 dash 运行
#   [F8] 整合 xrayv6.sh 的 gen_x25519()/derive_pubkey() 密钥对完整写入逻辑
#   [F9] banner 及日志中的脚本名改为 ex188t34ca
# ==============================================================================

# [F7] bash 守卫 - 必须在 set -euo pipefail 之前
if [ -z "${BASH_VERSION:-}" ]; then
    echo "Error: 请用 bash 运行: bash ex188t34ca.sh"
    exit 1
fi
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
    echo "Error: 需要 bash 4.0+，当前: $BASH_VERSION"
    exit 1
fi

set -euo pipefail
IFS=$' \n\t'
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ------------------------------------------------------------------------------
# [ 0x02: 颜色与 UI ]
# ------------------------------------------------------------------------------
readonly red='\033[31m'
readonly yellow='\033[33m'
readonly gray='\033[90m'
readonly green='\033[92m'
readonly blue='\033[94m'
readonly magenta='\033[95m'
readonly cyan='\033[96m'
readonly none='\033[0m'

readonly L_B=$(printf '\x5B')
readonly R_B=$(printf '\x5D')

print_red()     { echo -e "${red}$*${none}"; }
print_green()   { echo -e "${green}$*${none}"; }
print_yellow()  { echo -e "${yellow}$*${none}"; }
print_magenta() { echo -e "${magenta}$*${none}"; }
print_cyan()    { echo -e "${cyan}$*${none}"; }

info()  { echo -e "${green}[INFO]${none} $*"; }
warn()  { echo -e "${yellow}[WARN]${none} $*"; }
error() { echo -e "${red}[ERR]${none} $*"; }
die()   { echo -e "\n${red}[FATAL]${none} $*\n"; exit 1; }

title() {
    echo -e "\n${blue}===================================================${none}"
    echo -e "  ${cyan}$*${none}"
    echo -e "${blue}===================================================${none}"
}
hr() { echo -e "${gray}---------------------------------------------------${none}"; }

log_info()  {
    if [ -d "$LOG_DIR" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $*" >> "$LOG_DIR/xray_script.log" 2>/dev/null || true
    fi
}
log_error() {
    if [ -d "$LOG_DIR" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >> "$LOG_DIR/script_error.log" 2>/dev/null || true
    fi
}

# ------------------------------------------------------------------------------
# [ 0x03: 全局路径 ]
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

SERVER_IP=""
REMARK_NAME="xp-reality"
BEST_SNI="www.microsoft.com"
SNI_JSON_ARRAY="\"www.microsoft.com\""
LISTEN_PORT=443

# ------------------------------------------------------------------------------
# [ 0x04: 目录骨架 - 提前建立，为后续所有函数提供物理空间 ]
# ------------------------------------------------------------------------------
mkdir -p "$CONFIG_DIR" "$DAT_DIR" "$SCRIPT_DIR" "$LOG_DIR" "$BACKUP_DIR" "$FLAGS_DIR" 2>/dev/null || true
touch "$USER_SNI_MAP" "$USER_TIME_MAP" 2>/dev/null || true

# ------------------------------------------------------------------------------
# [ 0x05: 清理函数 - [F6] 路径与实际临时文件对齐 ]
# ------------------------------------------------------------------------------
cleanup_temp_files() {
    rm -f /tmp/sni_array.json        2>/dev/null || true
    rm -f /tmp/vless_inbound.json    2>/dev/null || true
    rm -f /tmp/vless_final.json      2>/dev/null || true
    rm -f /tmp/ss_inbound.json       2>/dev/null || true
    rm -f /tmp/new_client.json       2>/dev/null || true
    rm -f /tmp/xray_users_pool.txt   2>/dev/null || true
    rm -f /tmp/install-release.sh    2>/dev/null || true   # [F3] 对齐实际路径
    rm -f /tmp/sni_test.*            2>/dev/null || true
    rm -f /tmp/check_x86-64_psabi.sh 2>/dev/null || true
    rm -f /tmp/net-tcp-tune.*        2>/dev/null || true
    rm -f /tmp/xray_cfg_*.json       2>/dev/null || true
}

# ------------------------------------------------------------------------------
# [ 0x06: 权限与备份核心 ]
# ------------------------------------------------------------------------------
fix_permissions() {
    [ -f "$CONFIG" ]     && chmod 644 "$CONFIG"     && chown root:root "$CONFIG"     2>/dev/null || true
    [ -d "$CONFIG_DIR" ] && chmod 755 "$CONFIG_DIR" && chown -R root:root "$CONFIG_DIR" 2>/dev/null || true
    [ -f "$PUBKEY_FILE" ] && chmod 600 "$PUBKEY_FILE" 2>/dev/null || true
}

backup_config() {
    [ ! -f "$CONFIG" ] && return 0
    local ts; ts=$(date +%Y%m%d_%H%M%S)
    cp -f "$CONFIG" "$BACKUP_DIR/config_${ts}.json" 2>/dev/null || true
    ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | tail -n +16 | xargs rm -f 2>/dev/null || true
    log_info "配置快照: config_${ts}.json"
}

restore_latest_backup() {
    local latest
    latest=$(ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | head -n 1 || true)
    if [ -n "$latest" ]; then
        info "回滚到快照: $(basename "$latest")"
        cp -f "$latest" "$CONFIG" 2>/dev/null || true
        fix_permissions
        systemctl restart xray >/dev/null 2>&1 || true
        warn "已回滚到安全快照"
        log_info "回滚: $latest"
        return 0
    fi
    error "无可用快照，回滚失败"
    return 1
}

# [F2] verify_xray_config - 改用 exit code，兼容新旧 Xray
verify_xray_config() {
    local target_config="$1"
    [ ! -f "$XRAY_BIN" ] && return 0

    info "预审配置文件..."
    # 新版 Xray: xray run -test -config  旧版: xray -test -config  均兼容
    if "$XRAY_BIN" run -test -config "$target_config" >/dev/null 2>&1; then
        info "配置预审通过"
        return 0
    elif "$XRAY_BIN" -test -config "$target_config" >/dev/null 2>&1; then
        info "配置预审通过 (旧版兼容)"
        return 0
    else
        error "配置预审失败，Xray 拒绝加载："
        "$XRAY_BIN" run -test -config "$target_config" 2>&1 | head -20 || true
        return 1
    fi
}

ensure_xray_is_alive() {
    info "重载并启动 Xray..."
    systemctl daemon-reload >/dev/null 2>&1 || true
    systemctl restart xray  >/dev/null 2>&1 || true
    sleep 2
    if systemctl is-active --quiet xray; then
        info "Xray 运行正常"
        return 0
    else
        error "Xray 启动失败，日志："
        hr
        journalctl -u xray.service --no-pager -n 15 2>/dev/null || true
        hr
        warn "触发配置回滚..."
        restore_latest_backup
        local _p=""; read -rp "按 Enter 返回..." _p || true
        return 1
    fi
}

# [F4] trap 移到所有函数定义之后（在脚本末尾 preflight 调用前执行）
# 此处只定义 _err_handler，trap 在函数定义完后再设置
_err_handler() {
    local exit_code=$1
    local err_line=$2
    local err_cmd=$3
    echo -e "\n${red}================== [ SYSTEM PANIC ] ==================${none}" >&2
    echo -e "${yellow} >> 脚本遭遇致命错误，已自动熔断！${none}" >&2
    echo -e "${cyan} >> 错误代号: ${none}${exit_code}" >&2
    echo -e "${cyan} >> 崩溃行号: ${none}${err_line}" >&2
    echo -e "${cyan} >> 故障指令: ${none}${err_cmd}" >&2
    echo -e "${red}======================================================${none}\n" >&2
    log_error "PANIC -> EXIT=$exit_code LINE=$err_line CMD=[$err_cmd]"
    cleanup_temp_files
}

# ------------------------------------------------------------------------------
# [ 0x07: 安全 jq 写入引擎 ]
# ------------------------------------------------------------------------------
_safe_jq_write() {
    local filter="$1"
    local description="${2:-JSON 节点重组}"
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
            error "预审失败，撤销写入: $description"
            rm -f "$tmp" >/dev/null 2>&1 || true
            restore_latest_backup
            return 1
        fi
    else
        error "JQ 解析失败: $description"
        log_error "JQ 失败, Filter: $filter"
        rm -f "$tmp" >/dev/null 2>&1 || true
        restore_latest_backup
        return 1
    fi
}

# ------------------------------------------------------------------------------
# [ 0x08: Systemd 提权 ]
# ------------------------------------------------------------------------------
fix_xray_systemd_limits() {
    info "配置 Xray systemd 资源限制..."
    local override_dir="/etc/systemd/system/xray.service.d"
    mkdir -p "$override_dir" 2>/dev/null || true
    local limit_file="$override_dir/limits.conf"

    local current_nice="-20"
    local current_gogc="100"
    local current_oom="true"
    local current_affinity=""
    local current_gomaxprocs=""

    if [ -f "$limit_file" ]; then
        grep -q "^Nice="              "$limit_file" 2>/dev/null && current_nice=$(awk -F'=' '/^Nice=/{print $2}' "$limit_file" | head -1)
        grep -q "^Environment=\"GOGC=" "$limit_file" 2>/dev/null && current_gogc=$(awk -F'=' '/^Environment="GOGC=/{print $3}' "$limit_file" | tr -d '"' | head -1)
        grep -q "^OOMScoreAdjust="    "$limit_file" 2>/dev/null || current_oom="false"
        grep -q "^CPUAffinity="       "$limit_file" 2>/dev/null && current_affinity=$(awk -F'=' '/^CPUAffinity=/{print $2}' "$limit_file" | head -1)
        grep -q "^Environment=\"GOMAXPROCS=" "$limit_file" 2>/dev/null && current_gomaxprocs=$(awk -F'=' '/^Environment="GOMAXPROCS=/{print $3}' "$limit_file" | tr -d '"' | head -1)
    fi

    local TOTAL_MEM; TOTAL_MEM=$(free -m | awk '/Mem/{print $2}' || echo "1024")
    local GO_MEM_LIMIT=$(( TOTAL_MEM * 85 / 100 ))

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

    if [ "$current_oom" = "true" ]; then
        echo "OOMScoreAdjust=-500"      >> "$limit_file"
        echo "IOSchedulingClass=realtime" >> "$limit_file"
        echo "IOSchedulingPriority=2"   >> "$limit_file"
    fi
    [ -n "$current_affinity"    ] && echo "CPUAffinity=$current_affinity"          >> "$limit_file"
    [ -n "$current_gomaxprocs"  ] && echo "Environment=\"GOMAXPROCS=$current_gomaxprocs\"" >> "$limit_file"

    systemctl daemon-reload >/dev/null 2>&1 || true
    info "Systemd 资源限制已配置"
}

# ------------------------------------------------------------------------------
# [ 0x09: 环境预检与依赖安装 ]
# ------------------------------------------------------------------------------
detect_os() {
    if [ -f /etc/os-release ]; then
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
    local os_type; os_type=$(detect_os)
    case "$os_type" in
        ubuntu|debian)
            apt-get update -y >/dev/null 2>&1 || warn "APT update 失败，继续尝试安装..."
            apt-get install -y $list >/dev/null 2>&1 || error "包安装失败: $list"
            ;;
        centos|rhel|fedora|rocky|almalinux)
            yum makecache -y >/dev/null 2>&1 || true
            yum install -y $list >/dev/null 2>&1 || error "包安装失败: $list"
            ;;
        *)
            warn "未知发行版 ($os_type)，跳过包管理: $list"
            ;;
    esac
}

preflight() {
    info "系统环境预检..."
    [ "$EUID" -ne 0 ] && die "需要 root 权限"
    command -v systemctl >/dev/null 2>&1 || die "系统缺少 systemctl"

    local need="jq curl wget xxd unzip qrencode vnstat cron openssl iproute2 ethtool bc"
    local missing=""
    for p in $need; do
        command -v "$p" >/dev/null 2>&1 || missing="$missing $p"
    done
    if [ -n "$missing" ]; then
        info "安装缺失依赖:$missing"
        pkg_install "$missing"
        systemctl start  vnstat >/dev/null 2>&1 || true
        systemctl enable vnstat >/dev/null 2>&1 || true
        if systemctl list-unit-files | grep -q "^cron.service"; then
            systemctl start cron  >/dev/null 2>&1 || true
            systemctl enable cron >/dev/null 2>&1 || true
        elif systemctl list-unit-files | grep -q "^crond.service"; then
            systemctl start crond  >/dev/null 2>&1 || true
            systemctl enable crond >/dev/null 2>&1 || true
        fi
    fi

    # 快捷方式
    if [ -f "$SCRIPT_PATH" ]; then
        cp -f "$SCRIPT_PATH" "$SYMLINK" >/dev/null 2>&1 || true
        chmod +x "$SYMLINK" >/dev/null 2>&1 || true
        hash -r 2>/dev/null || true
    fi

    info "获取公网 IP..."
    SERVER_IP=$(curl -s -4 --connect-timeout 5 --max-time 10 https://api.ipify.org  2>/dev/null | tr -d '\r\n' || echo "")
    [ -z "$SERVER_IP" ] && SERVER_IP=$(curl -s -4 --connect-timeout 5 --max-time 10 https://ifconfig.me   2>/dev/null | tr -d '\r\n' || echo "")
    [ -z "$SERVER_IP" ] && SERVER_IP=$(curl -s -4 --connect-timeout 5 --max-time 10 https://icanhazip.com 2>/dev/null | tr -d '\r\n' || echo "")
    [ -z "$SERVER_IP" ] && { warn "公网 IP 获取失败"; SERVER_IP="获取失败"; } || info "公网 IP: $SERVER_IP"

    # [F4] 在所有函数定义完毕后才挂载 trap
    trap cleanup_temp_files EXIT
    trap '_err_handler $? $LINENO "$BASH_COMMAND"' ERR
}

# ------------------------------------------------------------------------------
# [ 0x0A: Geo 规则更新 ]
# ------------------------------------------------------------------------------
install_update_dat() {
    info "部署 Geo 规则自动更新..."
    cat > "$UPDATE_DAT_SCRIPT" <<'UPDSH'
#!/usr/bin/env bash
XRAY_DAT_DIR="/usr/local/share/xray"
LOG_FILE="/var/log/xray/update-dat.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }
dl() {
    local url="$1" out="$2" ok=0
    for i in 1 2 3; do
        curl -fsSL --connect-timeout 10 --max-time 300 -o "$out.tmp" "$url" && mv -f "$out.tmp" "$out" && log "更新成功: $url" && ok=1 && break
        log "重试[$i/3]: $url"; sleep 5
    done
    [ "$ok" -eq 0 ] && log "下载失败: $url" && return 1; return 0
}
dl "https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"   "$XRAY_DAT_DIR/geoip.dat"
dl "https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat" "$XRAY_DAT_DIR/geosite.dat"
log "Geo 规则更新完毕"
UPDSH
    chmod +x "$UPDATE_DAT_SCRIPT" 2>/dev/null || true

    local temp_cron; temp_cron=$(mktemp)
    crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT" | grep -v "systemctl restart xray" > "$temp_cron" || true
    echo "0 3 * * * $UPDATE_DAT_SCRIPT >/dev/null 2>&1"           >> "$temp_cron"
    echo "10 3 * * * /bin/systemctl restart xray >/dev/null 2>&1" >> "$temp_cron"
    crontab "$temp_cron" 2>/dev/null || true
    rm -f "$temp_cron" 2>/dev/null || true
    info "cron 已配置: 每日 03:00 更新 Geo，03:10 重启 Xray"
}

# ------------------------------------------------------------------------------
# [ 0x0B: 绑核控制 ]
# ------------------------------------------------------------------------------
_toggle_affinity_on() {
    local lf="/etc/systemd/system/xray.service.d/limits.conf"
    [ ! -f "$lf" ] && return
    sed -i '/^CPUAffinity=/d'             "$lf" 2>/dev/null || true
    sed -i '/^Environment="GOMAXPROCS=/d' "$lf" 2>/dev/null || true
    local CORES; CORES=$(nproc 2>/dev/null || echo 1)
    local TARGET_CPU="0"
    [ "$CORES" -ge 2 ] && TARGET_CPU="1"
    echo "CPUAffinity=$TARGET_CPU"        >> "$lf"
    echo "Environment=\"GOMAXPROCS=1\""  >> "$lf"
    systemctl daemon-reload >/dev/null 2>&1 || true
}

_toggle_affinity_off() {
    local lf="/etc/systemd/system/xray.service.d/limits.conf"
    [ ! -f "$lf" ] && return
    sed -i '/^CPUAffinity=/d'             "$lf" 2>/dev/null || true
    sed -i '/^Environment="GOMAXPROCS=/d' "$lf" 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true
}

# ------------------------------------------------------------------------------
# [ 0x0C: SNI 扫描器 ]
# ------------------------------------------------------------------------------
run_sni_scanner() {
    title "SNI 矩阵扫描"
    print_yellow ">>> 扫描中... (按 Enter 可中断)\n"

    local sni_list=(
        "www.apple.com" "support.apple.com" "developer.apple.com" "id.apple.com"
        "www.microsoft.com" "login.microsoftonline.com" "support.microsoft.com"
        "www.intel.com" "www.amd.com" "www.dell.com" "www.hp.com"
        "www.bmw.com" "www.mercedes-benz.com" "www.toyota.com" "www.honda.com"
        "www.volkswagen.com" "www.nike.com" "www.adidas.com" "www.ikea.com"
        "www.hsbc.com" "www.goldmansachs.com" "www.morganstanley.com"
        "www.sony.com" "www.panasonic.com" "www.canon.com" "www.nintendo.com"
        "www.samsung.com" "www.sap.com" "www.oracle.com" "www.swift.com"
        "s0.awsstatic.com" "www.nvidia.com" "www.lg.com" "www.epson.com"
        "www.logitech.com" "www.razer.com" "www.corsair.com" "www.seagate.com"
        "www.tesla.com" "www.audi.com" "www.porsche.com" "www.ferrari.com"
        "www.lufthansa.com" "www.singaporeair.com" "mit.edu" "stanford.edu"
        "www.ox.ac.uk" "www.unilever.com" "www.loreal.com" "www.jnj.com"
        "www.gucci.com" "www.prada.com" "www.dior.com" "www.hermes.com"
        "www.coca-cola.com" "www.nestle.com" "www.bayer.com" "www.bosch.com"
        "www.ford.com" "www.chevrolet.com" "www.hyundai.com" "www.kia.com"
        "www.volvocars.com" "www.maersk.com" "www.airbnb.com"
        "player.live-video.net" "download-installer.cdn.mozilla.net"
        "www.kingston.com" "logitech.com" "corsair.com" "razer.com"
    )

    local sni_string
    sni_string=$(printf "%s\n" "${sni_list[@]}")
    command -v shuf >/dev/null 2>&1 && sni_string=$(echo "$sni_string" | shuf) || \
        sni_string=$(echo "$sni_string" | awk 'BEGIN{srand()}{print rand()"\t"$0}' | sort -n | cut -f2-)

    local tmp_sni; tmp_sni=$(mktemp /tmp/sni_test.XXXXXX)

    for sni in $sni_string; do
        local key=""
        read -t 0.1 -n 1 -s key 2>/dev/null && {
            echo -e "\n${yellow}[中断] 扫描已停止${none}"; break
        } || true

        local time_raw; time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni" 2>/dev/null || echo "0")
        local ms; ms=$(echo "$time_raw" | awk '{print int($1*1000)}')

        if [ "${ms:-0}" -gt 0 ]; then
            curl -sI -m 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray" && {
                echo -e " ${gray}跳过${none} $sni (Cloudflare)"
                continue
            }
            local doh_res; doh_res=$(curl -s --connect-timeout 2 "https://dns.alidns.com/resolve?name=$sni&type=1" 2>/dev/null || echo "")
            local dns_cn=""; [ -n "$doh_res" ] && dns_cn=$(echo "$doh_res" | jq -r '.Answer[]? | select(.type==1 or .type==5) | .data' 2>/dev/null | tail -1 || echo "")
            local p_type="NORM"
            local status_cn
            if [ -z "$dns_cn" ] || [ "$dns_cn" = "127.0.0.1" ] || [ "$dns_cn" = "0.0.0.0" ] || [ "$dns_cn" = "null" ]; then
                status_cn="${red}DNS 污染${none}"; p_type="BLOCK"
            else
                local loc; loc=$(curl -s --connect-timeout 2 "https://ipinfo.io/$dns_cn/country" 2>/dev/null | tr -d ' \n' || echo "")
                if [ "$loc" = "CN" ]; then
                    status_cn="${green}直通${none}|${blue}境内 CDN${none}"; p_type="CN_CDN"
                else
                    status_cn="${green}直通${none}|${cyan}海外原生${none}"; p_type="NORM"
                fi
            fi
            echo -e " ${green}存活${none} $sni : ${yellow}${ms}ms${none} | $status_cn"
            [ "$p_type" != "BLOCK" ] && echo "$ms $sni $p_type" >> "$tmp_sni"
        fi
    done

    if [ -s "$tmp_sni" ]; then
        grep "NORM"   "$tmp_sni" | sort -n | head -n 20 | awk '{print $2,$1}' >  "$SNI_CACHE_FILE" || true
        local count; count=$(wc -l < "$SNI_CACHE_FILE" 2>/dev/null || echo 0)
        if [ "${count:-0}" -lt 20 ]; then
            local need_fill=$(( 20 - ${count:-0} ))
            grep "CN_CDN" "$tmp_sni" | sort -n | head -n "$need_fill" | awk '{print $2,$1}' >> "$SNI_CACHE_FILE" || true
        fi
    else
        error "未找到有效节点，使用默认值"
        echo "www.microsoft.com 999" > "$SNI_CACHE_FILE"
    fi
    rm -f "$tmp_sni" 2>/dev/null || true
}

# ------------------------------------------------------------------------------
# [ 0x0D: SNI 质检 ]
# ------------------------------------------------------------------------------
verify_sni_strict() {
    local target="$1"
    print_magenta "\n>>> 质检 [$target] TLS1.3/ALPN h2/OCSP..."
    local out; out=$(echo "Q" | timeout 5 openssl s_client -connect "$target:443" -alpn h2 -tls1_3 -status 2>&1 || echo "")
    local pass=1
    echo "$out" | grep -qi "TLSv1.3"                  || { print_red " X TLS1.3 不支持"; pass=0; }
    echo "$out" | grep -qiE "ALPN.*h2|server accepted.*h2" || { print_red " X ALPN h2 不支持"; pass=0; }
    echo "$out" | grep -qi "OCSP response:"            || { print_red " X OCSP Stapling 缺失"; pass=0; }
    return $pass
}

# ------------------------------------------------------------------------------
# [ 0x0E: SNI 选择器 ]
# ------------------------------------------------------------------------------
choose_sni() {
    while true; do
        if [ -f "$SNI_CACHE_FILE" ]; then
            echo -e "\n  ${cyan}[ Top 20 可用 SNI ]${none}"
            local idx=1
            while read -r s t; do
                echo -e "  $idx) $s (${cyan}${t}ms${none})"
                idx=$(( idx + 1 ))
            done < "$SNI_CACHE_FILE"
            echo -e "  ${yellow}r) 重新扫描${none}"
            echo "  m) 多选矩阵模式"
            echo "  0) 手动输入"
            echo "  q) 取消"
            local sel=""
            read -rp "  选择 [1]: " sel
            sel=${sel:-1}
            [ "$sel" = "q" ] || [ "$sel" = "Q" ] && return 1
            if [ "$sel" = "r" ] || [ "$sel" = "R" ]; then run_sni_scanner; continue; fi
            if [ "$sel" = "m" ] || [ "$sel" = "M" ]; then
                local m_sel=""
                read -rp "序号 (空格分隔, all=全选): " m_sel
                local arr=()
                if [ "$m_sel" = "all" ]; then
                    while read -r p_sni _; do [ -n "$p_sni" ] && arr+=("$p_sni"); done < "$SNI_CACHE_FILE"
                else
                    for i in $m_sel; do
                        local picked; picked=$(awk "NR==$i{print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "")
                        [ -n "$picked" ] && arr+=("$picked")
                    done
                fi
                [ ${#arr[@]} -eq 0 ] && error "选择无效" && continue
                BEST_SNI="${arr[0]}"
                local jq_args=()
                for s in "${arr[@]}"; do jq_args+=("\"$s\""); done
                SNI_JSON_ARRAY=$(IFS=,; echo "${jq_args[*]}")
            elif [ "$sel" = "0" ]; then
                local d=""
                read -rp "自定义域名: " d
                BEST_SNI=${d:-www.microsoft.com}
                SNI_JSON_ARRAY="\"$BEST_SNI\""
            else
                local picked=""
                [[ "$sel" =~ ^[0-9]+$ ]] && picked=$(awk "NR==$sel{print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "")
                if [ -n "$picked" ]; then BEST_SNI="$picked"
                else
                    error "序号无效，使用第1个"
                    BEST_SNI=$(awk "NR==1{print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "www.microsoft.com")
                fi
                SNI_JSON_ARRAY="\"$BEST_SNI\""
            fi

            if verify_sni_strict "$BEST_SNI"; then
                print_green ">>> 质检通过: $BEST_SNI"
                break
            else
                print_yellow ">>> 该域名不符合最优标准，建议重选"
                local force=""
                read -rp "强制使用? [y/N]: " force
                [[ "$force" =~ ^[yY]$ ]] && warn "已强制使用" && break || continue
            fi
        else
            warn "未找到扫描缓存，启动扫描..."
            run_sni_scanner
        fi
    done
    return 0
}

# ------------------------------------------------------------------------------
# [ 0x0F: 工具函数 ]
# ------------------------------------------------------------------------------
validate_port() {
    local p="$1"
    [ -z "$p" ] && return 1
    [[ "$p" =~ ^[0-9]+$ ]] || return 1
    [ "$p" -ge 1 ] && [ "$p" -le 65535 ] || return 1
    ss -tuln 2>/dev/null | grep -q ":${p} " && { print_red "端口 $p 已被占用"; return 1; } || return 0
}

gen_ss_pass() {
    head -c 24 /dev/urandom | base64 | tr -d '=/+\n\r' | head -c 24
    echo
}

# [F8] 密钥对生成 - 完整写入私钥和公钥
gen_x25519() {
    [ ! -x "$XRAY_BIN" ] && die "xray 未安装，无法生成密钥对"
    local keys; keys=$("$XRAY_BIN" x25519 2>/dev/null)
    X25519_PRIV=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' \r\n')
    X25519_PUB=$(echo  "$keys" | grep -i "Public"  | awk -F': ' '{print $2}' | tr -d ' \r\n')
    [ -z "$X25519_PRIV" ] || [ -z "$X25519_PUB" ] && die "x25519 密钥对生成失败"
}

derive_pubkey() {
    local priv="$1"
    [ ! -x "$XRAY_BIN" ] && echo "" && return
    "$XRAY_BIN" x25519 -i "$priv" 2>/dev/null | grep "Public key" | awk '{print $3}'
}

_select_ss_method() {
    echo -e "  ${cyan}SS 加密方式：${none}"     >&2
    echo "  1) aes-256-gcm (推荐)"              >&2
    echo "  2) aes-128-gcm"                     >&2
    echo "  3) chacha20-ietf-poly1305"          >&2
    local mc=""
    read -rp "  编号 [1]: " mc >&2 || true
    case "${mc:-1}" in
        2) echo "aes-128-gcm" ;;
        3) echo "chacha20-ietf-poly1305" ;;
        *) echo "aes-256-gcm" ;;
    esac
}

# ------------------------------------------------------------------------------
# [ 0x10: 更新核心 - [F3] 改为下载到文件再执行 ]
# ------------------------------------------------------------------------------
do_update_core() {
    title "更新 Xray 核心"
    local updated=0
    for url in \
        "https://github.com/XTLS/Xray-install/raw/main/install-release.sh" \
        "https://fastly.jsdelivr.net/gh/XTLS/Xray-install@main/install-release.sh"; do
        # [F3] 下载到临时文件，避免 $() 展开破坏脚本内容
        if curl -fsSL --connect-timeout 10 --max-time 60 -o /tmp/install-release.sh "$url" 2>/dev/null; then
            if bash /tmp/install-release.sh @ install >/dev/null 2>&1; then
                updated=1
                info "核心更新成功 (源: $url)"
                break
            fi
        fi
        warn "源 [$url] 失败，尝试备用..."
    done
    rm -f /tmp/install-release.sh 2>/dev/null || true
    [ "$updated" -eq 0 ] && { error "所有源均失败"; read -rp "按 Enter 返回..." _ || true; return 1; }
    fix_xray_systemd_limits
    systemctl restart xray >/dev/null 2>&1 || true
    local ver; ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 | awk '{print $2}' || echo "未知")
    info "当前版本: ${cyan}$ver${none}"
    read -rp "按 Enter 继续..." _ || true
}

# ------------------------------------------------------------------------------
# [ 0x11: Xanmod 安装 ]
# ------------------------------------------------------------------------------
do_install_xanmod_main_official() {
    title "安装 XANMOD 预编译内核"
    [ "$(uname -m)" != "x86_64" ]      && { error "仅支持 x86_64"; read -rp "按 Enter..." _ || true; return; }
    [ ! -f /etc/debian_version ]       && { error "仅支持 Debian/Ubuntu"; read -rp "按 Enter..." _ || true; return; }

    print_magenta ">>> [1/4] 检测 CPU 微架构..."
    local cpu_level_script="/tmp/check_x86-64_psabi.sh"
    wget -qO "$cpu_level_script" https://dl.xanmod.org/check_x86-64_psabi.sh 2>/dev/null || true
    local cpu_level=""
    [ -f "$cpu_level_script" ] && cpu_level=$(awk -f "$cpu_level_script" 2>/dev/null | grep -oE 'x86-64-v[1-4]' | grep -oE '[1-4]' | tail -1 || true)
    rm -f "$cpu_level_script" 2>/dev/null || true
    [ -z "$cpu_level" ] && { cpu_level=1; warn "无法检测微架构，使用 v1"; } || info "CPU 微架构: v${cpu_level}"

    local pkg_name="linux-xanmod-x64v${cpu_level}"
    print_magenta ">>> [2/4] 配置 Xanmod APT 源..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y gnupg gnupg2 curl wget >/dev/null 2>&1 || true
    echo 'deb http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-kernel.list
    wget -qO - https://dl.xanmod.org/gpg.key | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/xanmod-kernel.gpg \
        || { error "GPG 密钥导入失败"; return 1; }

    print_magenta ">>> [3/4] 安装 $pkg_name..."
    apt-get update -y
    apt-cache show "$pkg_name" >/dev/null 2>&1 || { warn "包 $pkg_name 不存在，回退到 v1"; pkg_name="linux-xanmod-x64v1"; }
    apt-get install -y "$pkg_name" || { error "安装失败"; read -rp "按 Enter..." _ || true; return 1; }

    print_magenta ">>> [4/4] 更新 GRUB..."
    command -v update-grub >/dev/null 2>&1 && update-grub || { apt-get install -y grub2-common >/dev/null 2>&1 || true; update-grub || true; }

    info "Xanmod 安装完毕，10 秒后重启..."
    sleep 10; reboot
}

# ------------------------------------------------------------------------------
# [ 0x12: 源码编译 Xanmod + BBR3 ]
# ------------------------------------------------------------------------------
do_xanmod_compile() {
    title "源码编译 Xanmod + BBR3"
    warn "耗时 30-60 分钟，低配机慎用！"
    local confirm=""
    read -rp "确认编译? (y/n): " confirm
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && return

    export DEBIAN_FRONTEND=noninteractive
    apt-get clean >/dev/null 2>&1 || true
    apt-get autoremove -y --purge >/dev/null 2>&1 || true
    rm -rf /tmp/* /var/log/*.log /usr/src/linux* /compile/* /root/linux* 2>/dev/null || true
    sync

    # Swap
    if ! swapon --show 2>/dev/null | grep -q swapfile; then
        fallocate -l 1024M /swapfile 2>/dev/null || dd if=/dev/zero of=/swapfile bs=1M count=1024 status=progress
        chmod 600 /swapfile; mkswap /swapfile >/dev/null; swapon /swapfile >/dev/null
        grep -q swapfile /etc/fstab || echo "/swapfile none swap sw 0 0" >> /etc/fstab
    fi

    apt-get update -y >/dev/null || true
    apt-get install -y build-essential bc bison flex libssl-dev libelf-dev libncurses-dev zstd git wget curl xz-utils make >/dev/null || true

    local CPU; CPU=$(nproc 2>/dev/null || echo 1)
    local RAM;  RAM=$(free -m | awk '/Mem/{print $2}' || echo 1024)
    local THREADS=1; [ "$RAM" -ge 2000 ] && THREADS=$CPU

    local root_free; root_free=$(df -m / | awk 'NR==2{print $4}' || echo 0)
    local BUILD_DIR="/usr/src"
    [ "$root_free" -gt 4000 ] && { mkdir -p /compile 2>/dev/null || true; BUILD_DIR="/compile"; }

    cd "$BUILD_DIR"
    local KERNEL_URL; KERNEL_URL=$(curl -s https://www.kernel.org/releases.json 2>/dev/null | grep -A3 '"is_latest": true' | grep tarball | head -1 | awk -F'"' '{print $4}' || echo "")
    [ -z "$KERNEL_URL" ] || [ "$KERNEL_URL" = "null" ] && KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.8.tar.xz"

    local KERNEL_FILE; KERNEL_FILE=$(basename "$KERNEL_URL")
    info "下载内核: $KERNEL_FILE"
    wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"
    tar -tJf "$KERNEL_FILE" >/dev/null 2>&1 || { rm -f "$KERNEL_FILE"; wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"; }

    info "解压内核源码..."
    tar -xJf "$KERNEL_FILE"
    local KERNEL_DIR; KERNEL_DIR=$(tar -tf "$KERNEL_FILE" | head -1 | cut -d/ -f1)
    cd "$KERNEL_DIR"

    make defconfig >/dev/null 2>&1 || true
    make scripts   >/dev/null 2>&1 || true
    ./scripts/config --enable CONFIG_TCP_CONG_BBR
    ./scripts/config --enable CONFIG_DEFAULT_BBR
    ./scripts/config --enable CONFIG_TCP_BBR3 2>/dev/null || true
    ./scripts/config --disable CONFIG_DRM_I915
    yes "" | make olddefconfig >/dev/null 2>&1 || true

    info "编译中 (线程数: $THREADS)..."
    make -j"$THREADS" || { error "编译失败"; read -rp "按 Enter..." _ || true; return 1; }
    make modules_install
    make install

    local CURRENT; CURRENT=$(uname -r)
    dpkg --list 2>/dev/null | grep linux-image | awk '{print $2}' | grep -v "$CURRENT" | xargs -r apt-get -y purge >/dev/null 2>&1 || true
    command -v update-grub >/dev/null 2>&1 && update-grub || true

    cd /
    rm -rf "$BUILD_DIR"/linux* 2>/dev/null || true
    info "编译完成，30 秒后重启..."
    sleep 30; reboot
}

# ------------------------------------------------------------------------------
# [ 0x13: TX Queue 调优 - [F1] 补全缺失函数 ]
# ------------------------------------------------------------------------------
do_txqueuelen_opt() {
    title "网卡发送队列 (TX Queue) 深度调优"
    local IFACE; IFACE=$(ip route show default 2>/dev/null | awk '/default/{print $5}' | head -1 || echo "")
    [ -z "$IFACE" ] && IFACE=$(ls /sys/class/net/ 2>/dev/null | grep -v "^lo$" | head -1 || echo "eth0")

    info "当前网卡: $IFACE"
    local current_txq; current_txq=$(ip link show "$IFACE" 2>/dev/null | grep -o 'txqueuelen [0-9]*' | awk '{print $2}' || echo "1000")
    echo "当前 txqueuelen: $current_txq"
    echo ""
    echo "  1) 设置为 2000 (推荐 - 防堵塞极速版)"
    echo "  2) 设置为 5000 (高带宽大流量服务器)"
    echo "  3) 恢复默认 1000"
    echo "  4) 手动输入"
    echo "  0) 返回"
    read -rp "选择: " opt || true

    local new_txq=""
    case "${opt:-0}" in
        1) new_txq=2000 ;;
        2) new_txq=5000 ;;
        3) new_txq=1000 ;;
        4) read -rp "输入值 (512-10000): " new_txq || true ;;
        0) return ;;
        *) warn "无效选项"; return ;;
    esac

    if [ -n "$new_txq" ] && [ "$new_txq" -ge 512 ] && [ "$new_txq" -le 10000 ] 2>/dev/null; then
        ip link set "$IFACE" txqueuelen "$new_txq" 2>/dev/null || true
        # 持久化：写入 rc.local 或 systemd
        local boot_cmd="ip link set $IFACE txqueuelen $new_txq"
        if [ -f /etc/rc.local ]; then
            grep -q "txqueuelen" /etc/rc.local && sed -i '/txqueuelen/d' /etc/rc.local
            sed -i '/^exit 0/i '"$boot_cmd" /etc/rc.local 2>/dev/null || true
        fi
        info "txqueuelen 已设置为 $new_txq (立即生效 + 持久化)"
    else
        error "无效数值"
    fi
    read -rp "按 Enter 继续..." _ || true
}

# ------------------------------------------------------------------------------
# [ 0x14: 内核网络栈调优 - [F1] 补全缺失函数 ]
# ------------------------------------------------------------------------------
do_perf_tuning() {
    title "系统内核网络栈极限调优"
    warn "此操作将修改 sysctl 参数并重启系统！"
    read -rp "确认继续? [y/N]: " confirm || true
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && { warn "已取消"; return; }

    local conf="/etc/sysctl.d/99-xray-perf.conf"
    cat > "$conf" << 'EOF'
# ---- TCP/IP 网络栈极限调优 ----
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 32768
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
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
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
vm.swappiness = 10
vm.dirty_ratio = 15
vm.dirty_background_ratio = 5
fs.file-max = 1048576
fs.inotify.max_user_instances = 8192
EOF

    sysctl -p "$conf" >/dev/null 2>&1 || warn "部分参数应用失败（可能需重启生效）"
    info "内核网络参数已写入 $conf"

    # ulimit 持久化
    local limits_conf="/etc/security/limits.d/99-xray.conf"
    cat > "$limits_conf" << 'EOF'
* soft nofile 1048576
* hard nofile 1048576
root soft nofile 1048576
root hard nofile 1048576
EOF
    info "ulimit 已写入 $limits_conf"

    info "调优完成，10 秒后重启使内核参数完全生效..."
    sleep 10
    reboot
}
# ------------------------------------------------------------------------------
# [ 0x1C: 核心安装 - [F3][F5][F8] 三项关键修复 ]
# ------------------------------------------------------------------------------
do_install() {
    clear
    title "核心部署 (VLESS-Reality / Shadowsocks)"
    preflight

    info "停止旧版 Xray..."
    systemctl stop xray >/dev/null 2>&1 || true
    [ ! -f "$INSTALL_DATE_FILE" ] && date +"%Y-%m-%d %H:%M:%S" > "$INSTALL_DATE_FILE"

    echo -e "\n  ${cyan}选择协议：${none}"
    echo "  1) VLESS-Reality (推荐)"
    echo "  2) Shadowsocks"
    echo "  3) 两个都装"
    local proto_choice=""
    read -rp "  编号 [1]: " proto_choice
    proto_choice=${proto_choice:-1}

    # 收集 VLESS 参数
    local vless_port="443" vless_remark="xp-reality"
    if [ "$proto_choice" = "1" ] || [ "$proto_choice" = "3" ]; then
        while true; do
            local ip=""
            read -rp "VLESS 端口 [443]: " ip; ip=${ip:-443}
            validate_port "$ip" && vless_port="$ip" && break
        done
        local ir=""
        read -rp "节点别名 [xp-reality]: " ir
        vless_remark=${ir:-xp-reality}
        REMARK_NAME="$vless_remark"
        choose_sni || { warn "SNI 选择取消，中止安装"; return 1; }
    fi

    # 收集 SS 参数
    local ss_port=8388 ss_pass="" ss_method="aes-256-gcm"
    if [ "$proto_choice" = "2" ] || [ "$proto_choice" = "3" ]; then
        while true; do
            local sp=""
            read -rp "SS 端口 [8388]: " sp; sp=${sp:-8388}
            validate_port "$sp" && ss_port="$sp" && break
        done
        ss_pass=$(gen_ss_pass)
        ss_method=$(_select_ss_method)
        if [ "$proto_choice" = "2" ]; then
            local sr=""
            read -rp "节点别名 [xp-ss]: " sr
            REMARK_NAME=${sr:-xp-ss}
        fi
    fi

    # [F3] 下载到临时文件再执行，避免 $() 展开破坏脚本
    print_magenta "\n>>> 下载并安装 Xray 核心..."
    local xray_installed=0
    for url in \
        "https://github.com/XTLS/Xray-install/raw/main/install-release.sh" \
        "https://fastly.jsdelivr.net/gh/XTLS/Xray-install@main/install-release.sh"; do
        if curl -fsSL --connect-timeout 10 --max-time 60 -o /tmp/install-release.sh "$url" 2>/dev/null; then
            if bash /tmp/install-release.sh @ install >/dev/null 2>&1; then
                xray_installed=1
                info "核心安装成功 (源: $url)"
                break
            fi
        fi
        warn "源 [$url] 失败，尝试备用..."
    done
    rm -f /tmp/install-release.sh 2>/dev/null || true
    [ "$xray_installed" -eq 0 ] && die "所有安装源均失败，请检查网络"

    install_update_dat
    fix_xray_systemd_limits

    # [F5][F8] 生成配置 - 补全 "type":"field" + 写入公钥私钥
    info "生成配置文件..."

    # 底层骨架 - [F5] 每条路由规则加上 "type":"field"
    cat > "$CONFIG" << 'CFGEOF'
{
  "log": { "loglevel": "warning" },
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "outboundTag": "block",
        "_enabled": true,
        "protocol": ["bittorrent"]
      },
      {
        "type": "field",
        "outboundTag": "block",
        "_enabled": true,
        "ip": ["geoip:cn"]
      },
      {
        "type": "field",
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
      "streamSettings": {
        "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true }
      }
    },
    { "protocol": "blackhole", "tag": "block" }
  ]
}
CFGEOF

    # VLESS inbound
    if [ "$proto_choice" = "1" ] || [ "$proto_choice" = "3" ]; then
        # [F8] 使用 gen_x25519() 生成密钥对，两者都写入配置
        gen_x25519
        local priv="$X25519_PRIV"
        local pub="$X25519_PUB"
        local uuid; uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
        local sid; sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n\r')
        local ctime; ctime=$(date +"%Y-%m-%d %H:%M")

        echo "$pub" > "$PUBKEY_FILE"
        echo "$uuid|$ctime" > "$USER_TIME_MAP"

        echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
        cat > /tmp/vless_inbound.json << EOF
{
  "tag": "vless-reality",
  "listen": "0.0.0.0",
  "port": $vless_port,
  "protocol": "vless",
  "settings": {
    "clients": [
      { "id": "$uuid", "flow": "xtls-rprx-vision", "email": "$vless_remark" }
    ],
    "decryption": "none"
  },
  "streamSettings": {
    "network": "tcp",
    "security": "reality",
    "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true },
    "realitySettings": {
      "dest": "$BEST_SNI:443",
      "serverNames": [],
      "privateKey": "$priv",
      "publicKey": "$pub",
      "shortIds": ["$sid"]
    }
  },
  "sniffing": { "enabled": true, "destOverride": ["http","tls","quic"] }
}
EOF
        # 合并 SNI 数组并追加到全局配置
        if jq --slurpfile snis /tmp/sni_array.json \
            '.streamSettings.realitySettings.serverNames = $snis[0]' \
            /tmp/vless_inbound.json > /tmp/vless_final.json 2>/dev/null; then
            jq '.inbounds += [input]' "$CONFIG" /tmp/vless_final.json > "$CONFIG.tmp" 2>/dev/null \
                && mv -f "$CONFIG.tmp" "$CONFIG" >/dev/null 2>&1 || true
        fi
        rm -f /tmp/vless_inbound.json /tmp/vless_final.json /tmp/sni_array.json 2>/dev/null || true
    fi

    # SS inbound
    if [ "$proto_choice" = "2" ] || [ "$proto_choice" = "3" ]; then
        cat > /tmp/ss_inbound.json << EOF
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
    "sockopt": { "tcpNoDelay": true, "tcpFastOpen": true }
  }
}
EOF
        jq '.inbounds += [input]' "$CONFIG" /tmp/ss_inbound.json > "$CONFIG.tmp" 2>/dev/null \
            && mv -f "$CONFIG.tmp" "$CONFIG" >/dev/null 2>&1 || true
        rm -f /tmp/ss_inbound.json 2>/dev/null || true
    fi

    fix_permissions
    backup_config
    systemctl enable xray >/dev/null 2>&1 || true
    ensure_xray_is_alive && info "部署完成！" || { error "服务启动失败"; return 1; }

    do_summary

    while true; do
        local opt=""
        read -rp "按 Enter 返回，或输入 b 重选 SNI: " opt || true
        if [ "$opt" = "b" ] || [ "$opt" = "B" ]; then
            choose_sni && _update_matrix && do_summary || break
        else
            break
        fi
    done
}

# ------------------------------------------------------------------------------
# [ 0x1B: SNI 矩阵热切 ]
# ------------------------------------------------------------------------------
_update_matrix() {
    [ ! -f "$CONFIG" ] && { error "配置不存在"; return 1; }
    info "热切 SNI 矩阵..."
    echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
    backup_config
    if ! jq --arg dest "$BEST_SNI:443" --slurpfile snis /tmp/sni_array.json '
        .inbounds = [
            .inbounds[]? | if (.protocol == "vless") then
                .streamSettings.realitySettings.serverNames = $snis[0] |
                .streamSettings.realitySettings.dest = $dest
            else . end
        ]' "$CONFIG" > "$CONFIG.tmp" 2>/dev/null; then
        error "JQ 处理失败"; rm -f /tmp/sni_array.json "$CONFIG.tmp" 2>/dev/null || true
        restore_latest_backup; return 1
    fi
    if verify_xray_config "$CONFIG.tmp"; then
        mv -f "$CONFIG.tmp" "$CONFIG" >/dev/null 2>&1 || true
        fix_permissions
        systemctl restart xray >/dev/null 2>&1 || true
        info "SNI 矩阵已更新"
    else
        error "预审失败"; rm -f "$CONFIG.tmp" 2>/dev/null || true; restore_latest_backup
    fi
    rm -f /tmp/sni_array.json 2>/dev/null || true
}

# ------------------------------------------------------------------------------
# [ 0x1D: 节点详情与二维码 ]
# ------------------------------------------------------------------------------
do_summary() {
    [ ! -f "$CONFIG" ] && return
    clear
    title "节点详情中心"
    local ip="$SERVER_IP"
    [ -z "$ip" ] || [ "$ip" = "获取失败" ] && {
        ip=$(curl -s -4 --connect-timeout 5 https://api.ipify.org 2>/dev/null | tr -d '\r\n' || echo "未知")
    }

    # VLESS
    local client_count; client_count=$(jq '[.inbounds[]? | select(.protocol=="vless" and .settings != null) | .settings.clients[]?] | length' "$CONFIG" 2>/dev/null || echo 0)
    if [ "${client_count:-0}" -gt 0 ]; then
        local port; port=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .port // empty' "$CONFIG" 2>/dev/null | head -1)
        local pub;  pub=$(jq  -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.publicKey // empty' "$CONFIG" 2>/dev/null | head -1)
        # 如公钥字段为空，尝试从私钥推导（[F8] 向后兼容旧配置）
        if [ -z "$pub" ]; then
            local priv; priv=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.privateKey // empty' "$CONFIG" 2>/dev/null | head -1)
            [ -n "$priv" ] && pub=$(derive_pubkey "$priv")
        fi
        local all_snis; all_snis=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames | join(", ")' "$CONFIG" 2>/dev/null | head -1)
        local main_sni; main_sni=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0] // empty' "$CONFIG" 2>/dev/null | head -1)

        local i=0
        while [ $i -lt "$client_count" ]; do
            local uuid; uuid=$(jq -r ".inbounds[]? | select(.protocol==\"vless\") | .settings.clients[$i].id // empty" "$CONFIG" 2>/dev/null)
            local remark; remark=$(jq -r ".inbounds[]? | select(.protocol==\"vless\") | .settings.clients[$i].email // \"$REMARK_NAME\"" "$CONFIG" 2>/dev/null)
            local sid; sid=$(jq -r ".inbounds[]? | select(.protocol==\"vless\") | .streamSettings.realitySettings.shortIds[$i] // empty" "$CONFIG" 2>/dev/null)
            local target_sni; target_sni=$(grep "^$uuid|" "$USER_SNI_MAP" 2>/dev/null | cut -d'|' -f2 || echo "")
            target_sni=${target_sni:-$main_sni}

            if [ -n "$uuid" ] && [ "$uuid" != "null" ]; then
                hr
                printf "  ${cyan}【VLESS-Reality - 用户 %d】${none}\n" $((i+1))
                printf "  ${yellow}%-16s${none} %s\n" "别名:"   "$remark"
                printf "  ${yellow}%-16s${none} %s\n" "IP:"     "$ip"
                printf "  ${yellow}%-16s${none} %s\n" "端口:"   "$port"
                printf "  ${yellow}%-16s${none} %s\n" "UUID:"   "$uuid"
                printf "  ${yellow}%-16s${none} %s\n" "SNI:"    "$target_sni"
                printf "  ${yellow}%-16s${none} %s\n" "矩阵:"   "$all_snis"
                printf "  ${yellow}%-16s${none} %s\n" "公钥:"   "$pub"
                printf "  ${yellow}%-16s${none} %s\n" "ShortID:" "$sid"
                local link="vless://${uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${target_sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${remark}"
                echo -e "\n  ${cyan}链接:${none}\n  $link\n"
                command -v qrencode >/dev/null 2>&1 && qrencode -m 2 -t UTF8 "$link"
            fi
            i=$(( i + 1 ))
        done
    fi

    # Shadowsocks
    local sc; sc=$(jq '[.inbounds[]? | select(.protocol=="shadowsocks")] | length' "$CONFIG" 2>/dev/null || echo 0)
    if [ "${sc:-0}" -gt 0 ]; then
        local s_port; s_port=$(jq -r '.inbounds[]? | select(.protocol=="shadowsocks") | .port // empty' "$CONFIG" 2>/dev/null | head -1)
        local s_pass; s_pass=$(jq -r '.inbounds[]? | select(.protocol=="shadowsocks") | .settings.password // empty' "$CONFIG" 2>/dev/null | head -1)
        local s_method; s_method=$(jq -r '.inbounds[]? | select(.protocol=="shadowsocks") | .settings.method // empty' "$CONFIG" 2>/dev/null | head -1)
        if [ -n "$s_port" ] && [ "$s_port" != "null" ]; then
            hr
            printf "  ${cyan}【Shadowsocks】${none}\n"
            printf "  ${yellow}%-16s${none} %s\n" "端口:"   "$s_port"
            printf "  ${yellow}%-16s${none} %s\n" "密码:"   "$s_pass"
            printf "  ${yellow}%-16s${none} %s\n" "加密:"   "$s_method"
            local b64; b64=$(printf '%s' "${s_method}:${s_pass}" | base64 | tr -d '\n')
            local link_ss="ss://${b64}@${ip}:${s_port}#${REMARK_NAME}-SS"
            echo -e "\n  ${cyan}链接:${none}\n  $link_ss\n"
            command -v qrencode >/dev/null 2>&1 && qrencode -m 2 -t UTF8 "$link_ss"
        fi
    fi
    hr
}

# ------------------------------------------------------------------------------
# [ 0x1E: 用户管理 ]
# ------------------------------------------------------------------------------
do_user_manager() {
    while true; do
        clear
        title "用户管理"
        [ ! -f "$CONFIG" ] && { error "请先安装"; read -rp "按 Enter..." _ || true; return; }

        local clients; clients=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .settings != null) | .settings.clients[]? | select(.id != null) | .id + "|" + (.email // "无备注")' "$CONFIG" 2>/dev/null || echo "")
        [ -z "$clients" ] && { error "无 VLESS 用户"; read -rp "按 Enter..." _ || true; return; }

        local tmp_users="/tmp/xray_users_pool.txt"
        echo "$clients" | awk -F'|' '{print NR"|"$1"|"$2}' > "$tmp_users"

        echo "当前用户："
        while IFS='|' read -r num uid remark; do
            local utime; utime=$(grep "^$uid|" "$USER_TIME_MAP" 2>/dev/null | cut -d'|' -f2 || echo "未知")
            echo -e "  $num) ${cyan}$remark${none} | ${gray}$utime${none} | ${yellow}$uid${none}"
        done < "$tmp_users"
        hr
        echo "  a) 新增用户    m) 导入外部用户    s) 绑定专属 SNI    d) 删除用户    q) 退出"
        local uopt=""; read -rp "指令: " uopt || true

        case "${uopt:-}" in
        a|A)
            local nu; nu=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
            local ns; ns=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n\r')
            local ctime; ctime=$(date +"%Y-%m-%d %H:%M")
            local u_remark=""; read -rp "用户别名 [User-${ns}]: " u_remark || true
            u_remark=${u_remark:-User-${ns}}

            cat > /tmp/new_client.json << EOF
{"id":"$nu","flow":"xtls-rprx-vision","email":"$u_remark"}
EOF
            local ok=0
            if jq '(.inbounds[]? | select(.protocol=="vless" and .settings != null) | .settings.clients) += [input]' \
                "$CONFIG" /tmp/new_client.json > "$CONFIG.tmp1" 2>/dev/null; then
                if jq --arg sid "$ns" \
                    '(.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.shortIds) += [$sid]' \
                    "$CONFIG.tmp1" > "$CONFIG" 2>/dev/null; then
                    echo "$nu|$ctime" >> "$USER_TIME_MAP"
                    fix_permissions
                    systemctl restart xray >/dev/null 2>&1 || true
                    ok=1
                fi
            fi
            rm -f /tmp/new_client.json "$CONFIG.tmp1" 2>/dev/null || true
            if [ "$ok" -eq 1 ]; then
                local port; port=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .port // empty' "$CONFIG" 2>/dev/null | head -1)
                local sni;  sni=$(jq  -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0] // empty' "$CONFIG" 2>/dev/null | head -1)
                local pub;  pub=$(jq  -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.publicKey // empty' "$CONFIG" 2>/dev/null | head -1)
                [ -z "$pub" ] && { local priv2; priv2=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.privateKey // empty' "$CONFIG" 2>/dev/null | head -1); pub=$(derive_pubkey "$priv2"); }
                info "新增用户成功"
                hr
                printf "  ${yellow}%-14s${none} %s\n" "别名:" "$u_remark"
                printf "  ${yellow}%-14s${none} %s\n" "UUID:" "$nu"
                printf "  ${yellow}%-14s${none} %s\n" "ShortID:" "$ns"
                local link="vless://${nu}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${ns}&type=tcp#${u_remark}"
                echo -e "\n  ${cyan}链接:${none}\n  $link\n"
                command -v qrencode >/dev/null 2>&1 && qrencode -m 2 -t UTF8 "$link"
            else
                error "新增用户失败"
            fi
            read -rp "按 Enter 继续..." _ || true
            ;;
        m|M)
            local m_remark=""; read -rp "别名 [Imported]: " m_remark || true; m_remark=${m_remark:-Imported}
            local m_uuid="";   read -rp "UUID: " m_uuid || true
            [ -z "$m_uuid" ] && { error "UUID 不能为空"; sleep 2; continue; }
            local m_sid="";    read -rp "ShortId: " m_sid || true
            [ -z "$m_sid"  ] && { error "ShortId 不能为空"; sleep 2; continue; }
            local ctime; ctime=$(date +"%Y-%m-%d %H:%M")

            cat > /tmp/new_client.json << EOF
{"id":"$m_uuid","flow":"xtls-rprx-vision","email":"$m_remark"}
EOF
            local ok=0
            if jq '(.inbounds[]? | select(.protocol=="vless" and .settings != null) | .settings.clients) += [input]' \
                "$CONFIG" /tmp/new_client.json > "$CONFIG.tmp1" 2>/dev/null; then
                if jq --arg sid "$m_sid" \
                    '(.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.shortIds) += [$sid]' \
                    "$CONFIG.tmp1" > "$CONFIG" 2>/dev/null; then
                    echo "$m_uuid|$ctime (导入)" >> "$USER_TIME_MAP"; ok=1
                fi
            fi
            rm -f /tmp/new_client.json "$CONFIG.tmp1" 2>/dev/null || true
            [ "$ok" -eq 1 ] && fix_permissions && systemctl restart xray >/dev/null 2>&1 || true
            [ "$ok" -eq 1 ] && info "导入成功" || error "导入失败"
            read -rp "按 Enter 继续..." _ || true
            ;;
        s|S)
            local snum=""; read -rp "用户序号: " snum || true
            local target_uuid; target_uuid=$(awk -F'|' -v id="${snum:-0}" '$1==id{print $2}' "$tmp_users" 2>/dev/null || echo "")
            [ -z "$target_uuid" ] && { error "无效序号"; read -rp "按 Enter..." _ || true; continue; }
            local u_sni=""; read -rp "专属 SNI 域名: " u_sni || true
            [ -z "$u_sni" ] && { warn "已取消"; read -rp "按 Enter..." _ || true; continue; }
            if jq --arg sni "$u_sni" \
                '(.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) += [$sni] |
                 (.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) |= unique' \
                "$CONFIG" > "$CONFIG.tmp" 2>/dev/null; then
                mv -f "$CONFIG.tmp" "$CONFIG" 2>/dev/null || true
                sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                echo "$target_uuid|$u_sni" >> "$USER_SNI_MAP"
                fix_permissions; systemctl restart xray >/dev/null 2>&1 || true
                info "已为该用户绑定专属 SNI: $u_sni"
            else
                error "操作失败"
            fi
            read -rp "按 Enter 继续..." _ || true
            ;;
        d|D)
            local dnum=""; read -rp "要删除的序号: " dnum || true
            local total; total=$(wc -l < "$tmp_users" 2>/dev/null || echo 0)
            if [ "${total:-0}" -le 1 ]; then
                error "必须保留至少一个用户"
            else
                local target_uuid; target_uuid=$(awk -F'|' -v id="${dnum:-0}" '$1==id{print $2}' "$tmp_users" 2>/dev/null || echo "")
                if [ -n "$target_uuid" ]; then
                    local idx=$(( ${dnum:-0} - 1 ))
                    if jq --arg uid "$target_uuid" --argjson i "$idx" \
                        '(.inbounds[]? | select(.protocol=="vless" and .settings != null) | .settings.clients) |= map(select(.id != $uid)) |
                         (.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.shortIds) |= del(.[$i])' \
                        "$CONFIG" > "$CONFIG.tmp" 2>/dev/null; then
                        mv -f "$CONFIG.tmp" "$CONFIG" 2>/dev/null || true
                        sed -i "/^$target_uuid|/d" "$USER_SNI_MAP"  2>/dev/null || true
                        sed -i "/^$target_uuid|/d" "$USER_TIME_MAP" 2>/dev/null || true
                        fix_permissions; systemctl restart xray >/dev/null 2>&1 || true
                        info "用户已删除"
                    else
                        error "删除失败"
                    fi
                else
                    error "无效序号"
                fi
            fi
            read -rp "按 Enter 继续..." _ || true
            ;;
        q|Q) rm -f "$tmp_users" 2>/dev/null || true; break ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# [ 0x1F: Block 规则管理 - [F5] 确保 type:field 在 toggle 时保留 ]
# ------------------------------------------------------------------------------
_global_block_rules() {
    while true; do
        clear
        title "屏蔽规则管理"
        [ ! -f "$CONFIG" ] && { error "请先安装"; read -rp "按 Enter..." _ || true; return; }

        local bt_en;  bt_en=$(jq  -r '.routing.rules[]? | select(.protocol != null) | select(.protocol | index("bittorrent")) | ._enabled // "true"' "$CONFIG" 2>/dev/null | head -1 || echo "true")
        local cn_en;  cn_en=$(jq  -r '.routing.rules[]? | select(.ip != null) | select(.ip | index("geoip:cn")) | ._enabled // "true"' "$CONFIG" 2>/dev/null | head -1 || echo "true")
        local ad_en;  ad_en=$(jq  -r '.routing.rules[]? | select(.domain != null) | select(.domain | index("geosite:category-ads-all")) | ._enabled // "true"' "$CONFIG" 2>/dev/null | head -1 || echo "true")

        local sb; [ "$bt_en" = "true" ] && sb="${green}开${none}" || sb="${red}关${none}"
        local sc; [ "$cn_en" = "true" ] && sc="${green}开${none}" || sc="${red}关${none}"
        local sa; [ "$ad_en" = "true" ] && sa="${green}开${none}" || sa="${red}关${none}"

        echo -e "  1) BT/PT 屏蔽          状态: $sb"
        echo -e "  2) 中国 IP 屏蔽        状态: $sc"
        echo -e "  3) 广告域名屏蔽        状态: $sa"
        echo "  0) 返回"
        local b_opt=""; read -rp "选择: " b_opt || true

        local tag="" nv=""
        case "${b_opt:-}" in
            1) tag="bittorrent"; [ "$bt_en" = "true" ] && nv="false" || nv="true"
               # [F5] 切换时保留 type:field
               jq --argjson nv "$nv" '(.routing.rules[] | select(.protocol != null) | select(.protocol | index("bittorrent")) | ._enabled) = $nv' \
                   "$CONFIG" > "$CONFIG.tmp" 2>/dev/null && mv -f "$CONFIG.tmp" "$CONFIG" || true
               fix_permissions; systemctl restart xray >/dev/null 2>&1 || true
               info "BT 屏蔽 -> $nv"
               ;;
            2) tag="geoip:cn"; [ "$cn_en" = "true" ] && nv="false" || nv="true"
               jq --argjson nv "$nv" '(.routing.rules[] | select(.ip != null) | select(.ip | index("geoip:cn")) | ._enabled) = $nv' \
                   "$CONFIG" > "$CONFIG.tmp" 2>/dev/null && mv -f "$CONFIG.tmp" "$CONFIG" || true
               fix_permissions; systemctl restart xray >/dev/null 2>&1 || true
               info "CN-IP 屏蔽 -> $nv"
               ;;
            3) tag="ads"; [ "$ad_en" = "true" ] && nv="false" || nv="true"
               jq --argjson nv "$nv" '(.routing.rules[] | select(.domain != null) | select(.domain | index("geosite:category-ads-all")) | ._enabled) = $nv' \
                   "$CONFIG" > "$CONFIG.tmp" 2>/dev/null && mv -f "$CONFIG.tmp" "$CONFIG" || true
               fix_permissions; systemctl restart xray >/dev/null 2>&1 || true
               info "广告屏蔽 -> $nv"
               ;;
            0) return ;;
            *) warn "无效选项" ;;
        esac
        read -rp "按 Enter 继续..." _ || true
    done
}

# ------------------------------------------------------------------------------
# [ 0x20: 运行状态 ]
# ------------------------------------------------------------------------------
do_status_menu() {
    while true; do
        clear
        title "运行状态与流量"
        echo "  1) 服务状态"
        echo "  2) IP / DNS / 监听信息"
        echo "  3) 流量统计 (vnstat)"
        echo "  4) 设置每月计费重置日"
        echo "  5) 实时连接统计 (雷达模式)"
        echo "  0) 返回"
        hr
        local s=""; read -rp "选择: " s || true
        case "${s:-}" in
        1) systemctl status xray --no-pager || true; read -rp "按 Enter..." _ || true ;;
        2)
            echo -e "\n  公网 IP: ${green}$SERVER_IP${none}"
            hr
            echo "  DNS:"
            grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print "    "$0}' || echo "    无"
            hr
            echo "  Xray 监听:"
            ss -tlnp 2>/dev/null | grep xray | awk '{print "    "$4}' || echo "    未检测到"
            read -rp "按 Enter..." _ || true
            ;;
        3)
            command -v vnstat >/dev/null 2>&1 || { warn "vnstat 未安装"; read -rp "按 Enter..." _ || true; continue; }
            clear; title "流量统计"
            vnstat -m 3 2>/dev/null | sed 's/estimated/估计/ig;s/rx/接收/ig;s/tx/发送/ig;s/total/合计/ig' || true
            read -rp "按 Enter..." _ || true
            ;;
        4)
            local current_day; current_day=$(grep -E "^MonthRotate" /etc/vnstat.conf 2>/dev/null | awk '{print $2}' || echo "1")
            echo "当前计费重置日: ${cyan}$current_day 号${none}"
            local d_day=""; read -rp "新重置日 (1-31): " d_day || true
            if [ "${d_day:-0}" -ge 1 ] 2>/dev/null && [ "${d_day:-0}" -le 31 ] 2>/dev/null; then
                sed -i '/^[# \t]*MonthRotate/d' /etc/vnstat.conf 2>/dev/null || true
                echo "MonthRotate $d_day" >> /etc/vnstat.conf
                systemctl restart vnstat >/dev/null 2>&1 || true
                info "已设置为每月 $d_day 号"
            else
                error "无效日期"
            fi
            read -rp "按 Enter..." _ || true
            ;;
        5)
            while true; do
                clear
                title "实时连接统计 (雷达)"
                local x_pids; x_pids=$(pidof xray 2>/dev/null | xargs | tr -s ' ' '|' || echo "")
                if [ -n "$x_pids" ]; then
                    echo -e "  ${cyan}连接状态分布${none}"
                    ss -ntupa 2>/dev/null | grep -E "pid=($x_pids)[,)]" | awk '{print $1"_"$2}' | sort | uniq -c | sort -nr | awk '{printf "    %-15s: %s\n",$2,$1}' || echo "    静默中..."
                    echo -e "\n  ${cyan}来源 IP TOP10${none}"
                    local ips; ips=$(ss -ntupa 2>/dev/null | grep -E "pid=($x_pids)[,)]" | grep -vE "LISTEN|UNCONN" | awk '{print $6}' | sed -E 's/:[0-9]+$//' | tr -d '[]' | grep -vE "^127\.|^0\.0\.0\.0$|^::$" || echo "")
                    if [ -n "$ips" ]; then
                        echo "$ips" | sort | uniq -c | sort -nr | head -10 | awk '{printf "    IP: %-20s 连接数: %s\n",$2,$1}'
                        echo -e "\n  独立 IP 数: ${yellow}$(echo "$ips" | sort -u | wc -l)${none}"
                    else
                        echo -e "    ${gray}暂无外部连接${none}"
                    fi
                else
                    echo -e "  ${red}Xray 未运行${none}"
                fi
                echo -e "\n  ${gray}每 2 秒刷新 | q=退出 r=立即刷新${none}"
                local cmd=""
                if read -t 2 -n 1 -s cmd 2>/dev/null; then
                    [ "$cmd" = "q" ] || [ "$cmd" = "Q" ] && break
                fi
            done
            ;;
        0) return ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# [ 0x21: 卸载 ]
# ------------------------------------------------------------------------------
do_uninstall() {
    title "彻底卸载 Xray"
    warn "将删除 Xray 及所有配置，系统调优参数保留"
    local confirm=""; read -rp "确认? (y/N): " confirm || true
    [ "$confirm" != "y" ] && [ "$confirm" != "Y" ] && return

    local temp_date=""
    [ -f "$INSTALL_DATE_FILE" ] && temp_date=$(cat "$INSTALL_DATE_FILE" 2>/dev/null || echo "")

    systemctl stop    xray >/dev/null 2>&1 || true
    systemctl disable xray >/dev/null 2>&1 || true

    # Dnsmasq 清理
    systemctl stop dnsmasq >/dev/null 2>&1 || true
    systemctl disable dnsmasq >/dev/null 2>&1 || true
    export DEBIAN_FRONTEND=noninteractive
    apt-get purge -y dnsmasq >/dev/null 2>&1 || yum remove -y dnsmasq >/dev/null 2>&1 || true
    chattr -i /etc/resolv.conf 2>/dev/null || true
    [ -f /etc/resolv.conf.bak ] && mv -f /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true
    systemctl enable systemd-resolved >/dev/null 2>&1 || true
    systemctl start  systemd-resolved >/dev/null 2>&1 || true

    rm -rf /etc/systemd/system/xray.service    2>/dev/null || true
    rm -rf /etc/systemd/system/xray.service.d  2>/dev/null || true
    rm -rf /lib/systemd/system/xray*           2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1 || true

    rm -rf "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SCRIPT_DIR" /var/log/xray* 2>/dev/null || true

    (crontab -l 2>/dev/null | grep -v "update-dat.sh" | grep -v "systemctl restart xray") | crontab - 2>/dev/null || true
    rm -f "$SYMLINK" 2>/dev/null || true

    [ -n "$temp_date" ] && { mkdir -p "$CONFIG_DIR" 2>/dev/null || true; echo "$temp_date" > "$INSTALL_DATE_FILE"; }

    cleanup_temp_files
    print_green "卸载完成"
    exit 0
}

# ------------------------------------------------------------------------------
# [ 0x22: 系统初始化菜单 ]
# ------------------------------------------------------------------------------
do_sys_init_menu() {
    while true; do
        clear
        title "系统组件安装与优化"
        echo "  1) 更新系统 + 安装常用工具 + 校准时区"
        echo "  2) 安装 XANMOD 预编译内核 (推荐，自动重启)"
        echo "  3) 源码编译 Xanmod + BBR3 (极客流，自动重启)"
        echo "  4) 网卡 TX Queue 深度调优"
        echo "  5) 内核网络栈极限调优 (自动重启)"
        echo "  0) 返回"
        hr
        local sys_opt=""; read -rp "选择: " sys_opt || true
        case "${sys_opt:-}" in
            1)
                print_magenta ">>> 更新系统..."
                export DEBIAN_FRONTEND=noninteractive
                apt-get update -y >/dev/null 2>&1 || true
                apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" full-upgrade -y >/dev/null 2>&1 || true
                apt-get install -y wget curl sudo socat ntpdate iproute2 ethtool >/dev/null 2>&1 || true
                command -v timedatectl >/dev/null 2>&1 && timedatectl set-timezone Asia/Kuala_Lumpur >/dev/null 2>&1 || true
                command -v ntpdate     >/dev/null 2>&1 && ntpdate us.pool.ntp.org >/dev/null 2>&1 || true
                command -v hwclock     >/dev/null 2>&1 && hwclock --systohc >/dev/null 2>&1 || true
                info "完成！时区: Asia/Kuala_Lumpur"
                read -rp "按 Enter..." _ || true
                ;;
            2) do_install_xanmod_main_official ;;
            3) do_xanmod_compile ;;
            4) do_txqueuelen_opt ;;
            5) do_perf_tuning ;;
            0) return ;;
            *) warn "无效选项" ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# [ 0x22: 主菜单 - [F9] 脚本名改为 ex188t34ca ]
# ------------------------------------------------------------------------------
main_menu() {
    while true; do
        clear
        echo -e "${blue}===================================================${none}"
        echo -e "  ${magenta}ex188t34ca - Apex Vanguard Genesis (ca 修复版)${none}"
        local svc; svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        [ "$svc" = "active" ] && svc="${green}运行中${none}" || svc="${red}停止${none}"
        echo -e "  状态: $svc | 快捷: ${cyan}xrv${none} | IP: ${yellow}$SERVER_IP${none}"
        echo -e "  内核: ${yellow}$(uname -r)${none} | 脚本: $(basename "$0")"
        echo -e "${blue}===================================================${none}"
        echo "  1) 安装 / 重装 (VLESS/SS 双协议)"
        echo "  2) 用户管理 (增删/导入/专属 SNI)"
        echo "  3) 节点详情与二维码"
        echo "  4) 手动更新 Geo 规则"
        echo "  5) 更新 Xray 核心"
        echo "  6) 热切 SNI 矩阵"
        echo "  7) 屏蔽规则管理 (BT/CN-IP/广告)"
        echo "  9) 运行状态 (IP/DNS/流量)"
        echo "  10) 系统安装与优化"
        echo "  0) 退出"
        echo -e "  ${red}88) 彻底卸载${none}"
        hr
        local num=""; read -rp "选择: " num || true
        case "${num:-}" in
        1) do_install ;;
        2) do_user_manager ;;
        3)
            do_summary
            while true; do
                local rb=""; read -rp "Enter 返回 / b 重选 SNI: " rb || true
                if [ "$rb" = "b" ] || [ "$rb" = "B" ]; then
                    choose_sni && _update_matrix && do_summary || break
                else break; fi
            done
            ;;
        4)
            print_magenta ">>> 更新 Geo 规则..."
            bash "$UPDATE_DAT_SCRIPT" >/dev/null 2>&1 || true
            ensure_xray_is_alive
            info "Geo 更新完成"
            read -rp "按 Enter..." _ || true
            ;;
        5) do_update_core ;;
        6)
            if choose_sni; then
                _update_matrix; do_summary
                while true; do
                    local rb=""; read -rp "Enter 返回 / b 继续: " rb || true
                    [ "$rb" = "b" ] || [ "$rb" = "B" ] && choose_sni && _update_matrix && do_summary || break
                done
            fi
            ;;
        7)  _global_block_rules ;;
        9)  do_status_menu ;;
        10) do_sys_init_menu ;;
        88) do_uninstall ;;
        0)  exit 0 ;;
        *)  echo -e "${red}无效选项${none}"; sleep 1 ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# 引擎点火
# ------------------------------------------------------------------------------
preflight
main_menu
