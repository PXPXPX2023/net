#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: ex182.sh (Xray Advanced Management Script V182)
# 快捷方式: xrv
#
# V182 终极修订日志:
#   1. 致命修复: 补齐遗失的 `magenta` 颜色变量，根除 set -u 严格模式下的 unbound variable 熔断 Bug。
#   2. 全域排雷: 严格复查所有被调用的临时变量与传参，确保无死角兼容 -euo pipefail。
#   3. 极客基盘: 继续保持 130+ SNI 单行展开与 60+ 项网络协议栈参数注入的无损满血状态。
# ==============================================================================

# 强制 Bash 运行环境检测
if test -z "$BASH_VERSION"; then
    echo "错误: 请用 bash 运行: bash ex182.sh"
    exit 1
fi

# 严格模式 (开启错误中断与未定义变量拦截，管道流断裂捕获)
set -euo pipefail
IFS=$'\n\t'

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ── 颜色定义 ──────────────────────────────────────────────────
# V182 修复：已补全丢失的 magenta 变量声明，修复 unbound variable 错误
readonly red='\033[31m'    yellow='\033[33m'  gray='\033[90m'
readonly green='\033[92m'  blue='\033[94m'    magenta='\033[95m'
readonly cyan='\033[96m'   none='\033[0m'

# ── 全局常量与路径 ────────────────────────────────────────────
readonly SCRIPT_VERSION="182"
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

# ── 初始化目录 ────────────────────────────────────────────────
if ! mkdir -p "$CONFIG_DIR" "$DAT_DIR" "$SCRIPT_DIR" "$FLAGS_DIR" "$LOG_DIR" "$BACKUP_DIR" 2>/dev/null; then
    true
fi
if ! touch "$USER_SNI_MAP" "$USER_TIME_MAP" 2>/dev/null; then
    true
fi

# ==============================================================================
# [ 区块 I: 基础工具与容错机制 ]
# ==============================================================================

print_red()    { echo -e "${red}$*${none}"; }
print_green()  { echo -e "${green}$*${none}"; }
print_yellow() { echo -e "${yellow}$*${none}"; }
print_magenta(){ echo -e "${magenta}$*${none}"; }
print_cyan()   { echo -e "${cyan}$*${none}"; }

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

log_info()  { echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO:  $*" >> "$LOG_DIR/xray.log"; }
log_error() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$LOG_DIR/error.log"; }

trap '_err_handler $? $LINENO "$BASH_COMMAND"' ERR
_err_handler() {
    local code=$1 line=$2 cmd=$3
    echo -e "\n${red}[异常中断] 退出码:$code 行数:$line 指令:$cmd${none}" >&2
    log_error "EXIT=$code LINE=$line CMD=$cmd"
}

validate_port() {
    local p="$1"
    if [[ -z "$p" ]]; then return 1; fi
    if [[ ! "$p" =~ ^[0-9]+$ ]]; then return 1; fi
    if ((p < 1 || p > 65535)); then return 1; fi
    if ss -tuln 2>/dev/null | grep -q ":${p} "; then
        print_red "端口 $p 已被占用！"
        return 1
    fi
    return 0
}

validate_domain() {
    local d="$1"
    if [[ "$d" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.\-]{0,253}[a-zA-Z0-9])?$ ]]; then
        return 0
    else
        return 1
    fi
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

# ==============================================================================
# [ 区块 II: JSON 配置事务与回滚系统 ]
# ==============================================================================

backup_config() {
    if [[ ! -f "$CONFIG" ]]; then return 0; fi
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    cp -f "$CONFIG" "$BACKUP_DIR/config_${ts}.json" 2>/dev/null || true
    ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
    log_info "配置快照已保存: config_${ts}.json"
}

restore_latest_backup() {
    local latest
    latest=$(ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | head -1 || true)
    if [[ -n "$latest" ]]; then
        cp -f "$latest" "$CONFIG"
        fix_permissions
        systemctl restart xray >/dev/null 2>&1 || true
        warn "检测到配置错误，已自动回滚至: $(basename "$latest")"
        log_info "触发自动回滚: $latest"
        return 0
    fi
    error "未找到可用的配置备份，还原失败。"
    return 1
}

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
        error "JSON 配置验证失败，Xray 拒绝启动："
        echo -e "${gray}$test_result${none}"
        return 1
    fi
}

_safe_jq_write() {
    backup_config
    local tmp
    tmp=$(mktemp) || return 1
    
    if jq "$@" "$CONFIG" > "$tmp" 2>/dev/null && jq empty "$tmp" 2>/dev/null; then
        if verify_xray_config "$tmp"; then
            mv -f "$tmp" "$CONFIG"
            fix_permissions
            return 0
        else
            rm -f "$tmp" 2>/dev/null || true
            restore_latest_backup
            return 1
        fi
    fi
    
    rm -f "$tmp" 2>/dev/null || true
    error "JSON 解析或写入失败！参数: $*"
    log_error "jq 语法错误，参数: $*"
    restore_latest_backup
    return 1
}

ensure_xray_is_alive() {
    systemctl restart xray >/dev/null 2>&1 || true
    sleep 3
    if systemctl is-active --quiet xray; then
        info "Xray 服务已成功重载并处于运行状态。"
        return 0
    else
        error "Xray 服务启动失败！"
        print_yellow ">>> 截获的服务报错信息："
        hr
        journalctl -u xray.service --no-pager -n 15 | awk '{print "    " $0}' || true
        hr
        restore_latest_backup
        read -rp "请按 Enter 键返回..." _
        return 1
    fi
}

# ==============================================================================
# [ 区块 III: 环境预检与 Limit 调度 ]
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
            warn "未能识别包管理器，请手动安装: $list"
            ;;
    esac
}

preflight() {
    if ((EUID != 0)); then
        die "请使用 root 权限运行此脚本。"
    fi
    if ! command -v systemctl >/dev/null 2>&1; then
        die "系统环境缺失 systemctl，无法继续安装。"
    fi

    local need="jq curl wget xxd unzip qrencode vnstat openssl coreutils sed e2fsprogs pkg-config iproute2 ethtool bc bison flex dwarves rsync python3 cpio"
    local missing=""
    for p in $need; do
        if ! command -v "$p" >/dev/null 2>&1; then
            missing="$missing $p"
        fi
    done
    
    if [[ -n "$missing" ]]; then
        info "检测到缺少必要依赖，正在安装: $missing"
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
        warn "未能自动获取到服务器的公网 IPv4 地址。"
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
    total_mem=$(free -m | awk '/Mem/{print $2}' || echo "1024")
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
    title "检查内存 Swap 分区"
    local SWAP_FILE="/swapfile"
    local CURRENT_SWAP
    CURRENT_SWAP=$(swapon --show=NAME,KBYTES --noheadings 2>/dev/null | grep "$SWAP_FILE" | awk '{print $2}' || echo "")
    
    if [[ -n "$CURRENT_SWAP" ]] && ((CURRENT_SWAP >= 1000000)); then
        info "已存在满足要求的 1GB Swap 分区。"
    else
        warn "Swap 分区不存在或容量不足，正在重建 1GB Swap 分区..."
        swapoff -a 2>/dev/null || true
        sed -i '/swapfile/d' /etc/fstab 2>/dev/null || true
        rm -f "$SWAP_FILE" 2>/dev/null || true
        
        dd if=/dev/zero of="$SWAP_FILE" bs=1M count=1024 status=none
        chmod 600 "$SWAP_FILE"
        mkswap "$SWAP_FILE" >/dev/null 2>&1
        swapon "$SWAP_FILE" >/dev/null 2>&1
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
        info "1GB Swap 分区创建成功并已配置自动挂载。"
    fi
}
# ==============================================================================
# [ 区块 IV: Geo 规则库自动更新与本地 DNS 配置 ]
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

    chmod +x "$UPDATE_DAT_SCRIPT"

    if ! crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT" | grep -v "systemctl restart xray" > /tmp/current_cron; then
        true
    fi
    echo "0 3 * * * $UPDATE_DAT_SCRIPT >/dev/null 2>&1" >> /tmp/current_cron
    echo "10 3 * * * /bin/systemctl restart xray >/dev/null 2>&1" >> /tmp/current_cron
    crontab /tmp/current_cron
    rm -f /tmp/current_cron 2>/dev/null || true

    info "自动更新配置完成: 每日 03:00 下载 Geo 库，03:10 重载 Xray。"
}

do_change_dns() {
    title "配置系统 DNS 解析 (resolvconf)"
    
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
        read -rp "请输入自定义 Nameserver IP (例如 8.8.8.8 或 1.1.1.1): " nameserver
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
    
    info "DNS 已被锁定为：$nameserver"
}

# ==============================================================================
# [ 区块 V: SNI 连通性测试矩阵 ]
# ==============================================================================
run_sni_scanner() {
    title "SNI 连通性测试 (TCP 延迟与可用性验证)"
    info "扫描进行中... (按回车键可随时中止并结算已扫描节点)\n"
    
    if ! mkdir -p "$CONFIG_DIR" 2>/dev/null; then
        true
    fi
    
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
        print_red "[ERROR] 未发现可用节点，回退为默认配置。"
        echo "www.microsoft.com 999" > "$SNI_CACHE_FILE"
    fi
    
    rm -f "$tmp_sni" 2>/dev/null || true
}

verify_sni_strict() {
    local target="$1"
    info "正在检查 $target 的 TLS 1.3 / ALPN / OCSP 支持情况..."
    
    local out
    out=$(echo "Q" | timeout 5 openssl s_client -connect "$target:443" -alpn h2 -tls1_3 -status 2>&1 || echo "")
    local pass=1
    
    if ! echo "$out" | grep -qi "TLSv1.3"; then
        warn "验证失败: 不支持 TLS v1.3"
        pass=0
    fi
    if ! echo "$out" | grep -qi "ALPN.*h2"; then
        warn "验证失败: 不支持 ALPN h2"
        pass=0
    fi
    if ! echo "$out" | grep -qi "OCSP response:"; then
        warn "验证失败: 未返回 OCSP 状态"
        pass=0
    fi
    
    if ((pass == 0)); then
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
            
            read -rp "  请选择对应操作或节点: " sel
            sel=${sel:-1}
            
            case "$sel" in
                q|Q) return 1 ;;
                r|R) run_sni_scanner; continue ;;
                m|M)
                    read -rp "请输入所需序号 (例如 1 3 5，或 all): " m_sel
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
# [ 区块 VI: Linux 内核源码编译与驱动继承系统 ]
# ==============================================================================

do_xanmod_compile() {
    title "系统内核源码提取与 BBR3 编译"
    warn "源码编译耗时较长 (30-60 分钟)，期间请勿中断 SSH 连接。"
    read -rp "确定要开始编译内核吗？(y/n): " confirm
    
    if [[ "$confirm" != "y" ]]; then
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
            error "源码包损坏，终止安装。"
            return 1
        fi
    fi

    tar -xJf "$KERNEL_FILE"
    local KERNEL_DIR
    KERNEL_DIR=$(tar -tf "$KERNEL_FILE" | head -1 | cut -d/ -f1)
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
            read -rp "确定强制继续吗？(y/n): " force_k
            if [[ "$force_k" != "y" ]]; then 
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
        error "编译过程中断，请检查内存或硬盘空间是否充足。"
        read -rp "按 Enter 返回..." _
        return 1
    fi

    info "开始安装内核模块与引导文件..."
    make modules_install || true
    make install || true

    local NEW_KERNEL_VER
    NEW_KERNEL_VER=$(make -s kernelrelease || echo "")
    
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
    
    read -rp "是否继续执行调优？(y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        return
    fi
    
    local current_scale
    current_scale=$(sysctl -n net.ipv4.tcp_adv_win_scale 2>/dev/null || echo "1")
    local current_app
    current_app=$(sysctl -n net.ipv4.tcp_app_win 2>/dev/null || echo "31")
    
    echo -e "  当前 tcp_adv_win_scale: ${cyan}${current_scale}${none} (建议 1 或 2)"
    echo -e "  当前 tcp_app_win: ${cyan}${current_app}${none} (建议 31)"
    
    read -rp "设置 tcp_adv_win_scale (-2 到 2，直接回车保留当前): " new_scale
    new_scale=${new_scale:-$current_scale}
    
    read -rp "设置 tcp_app_win (1 到 31，直接回车保留当前): " new_app
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
        error "Sysctl 参数应用存在错误，部分硬件或系统不支持。"
        read -rp "按 Enter 返回菜单..." _
        return 1
    else
        info "所有底层 Sysctl 参数应用完毕。"
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if [[ -n "$IFACE" ]]; then
        info "配置网卡驱动与 CPU RPS 分发 ($IFACE)..."
        
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
                info "网卡硬件队列守护配置成功。"
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
        read -rp "按 Enter 返回..." _
        return 1
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if [[ -z "$IFACE" ]]; then
        error "无法定位系统默认出口网卡。"
        read -rp "按 Enter 返回..." _
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
    read -rp "按 Enter 返回..." _
}

config_cake_advanced() {
    clear
    title "CAKE 调度器高级配置"
    
    local current_opts="未配置 (自适应)"
    if [[ -f "$CAKE_OPTS_FILE" ]]; then
        current_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
    fi
    echo -e "  当前运行参数: ${cyan}${current_opts}${none}\n"
    
    read -rp "  [1] 服务器可用带宽 (例如 900Mbit, 回车跳过): " c_bw
    read -rp "  [2] 封装报文开销补偿 (建议 VPN/代理输入 48, 回车跳过): " c_oh
    read -rp "  [3] 最小数据单元 (建议 64, 回车跳过): " c_mpu
    
    echo "  [4] RTT 延迟模型: "
    echo "    1) internet  (标准 85ms)"
    echo "    2) oceanic   (跨国长距离 300ms)"
    echo "    3) satellite (卫星 1000ms)"
    read -rp "  请选择 (默认 2): " rtt_sel
    
    local c_rtt=""
    case "${rtt_sel:-2}" in
        1) c_rtt="internet" ;;
        3) c_rtt="satellite" ;;
        *) c_rtt="oceanic" ;;
    esac
    
    echo "  [5] Diffserv 分流策略: "
    echo "    1) diffserv4  (系统解析包特征分类)"
    echo "    2) besteffort (盲推忽略特征, 减少 CPU 开销)"
    read -rp "  请选择 (默认 2): " diff_sel
    
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
        info "已清除所有 CAKE 自定义参数。"
    else
        echo "$final_opts" > "$CAKE_OPTS_FILE"
        info "CAKE 参数已更新为: $final_opts"
    fi
    
    _apply_cake_live
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if tc qdisc show dev "$IFACE" 2>/dev/null | grep -q "cake"; then
        info "CAKE 队列已接管网卡接口。"
    else
        warn "网卡当前未运行 CAKE 调度器。请确认系统支持。"
    fi
    
    read -rp "配置完成，请按 Enter 返回..." _
}

# ==============================================================================
# [ 区块 IX: 系统状态探针与自启保护 ]
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
# (为防止大模型物理截断，代码第三部分到此安全驻留。)
# (控制台操作选项、功能交互模块以及主菜单将包含在接下来的 Part 4 中！)
# ==============================================================================
# ==============================================================================
# [ 区块 VIII (续): 应用层微操全景矩阵与管理面板 ]
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
        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
        echo "Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" >> "$limit_file"
        
        local TOTAL_MEM
        TOTAL_MEM=$(free -m | awk '/Mem/{print $2}' || echo "1024")
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
        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file" 2>/dev/null || true
        sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=100\"/" "$limit_file" 2>/dev/null || true
        systemctl daemon-reload >/dev/null 2>&1 || true
    fi
}

do_app_level_tuning_menu() {
    while true; do
        clear
        title "网络应用层与系统级高级调优面板 (25项)"
        if [[ ! -f "$CONFIG" ]]; then 
            error "未发现系统配置，请先执行安装。"
            read -rp "按 Enter 返回..." _
            return
        fi

        # ==========================================
        # 抓取应用层探针 (App 1-11)
        # ==========================================
        local out_fastopen
        out_fastopen=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpFastOpen // "false"' "$CONFIG" 2>/dev/null | head -1 || echo "false")
        local out_keepalive
        out_keepalive=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpKeepAliveIdle // "false"' "$CONFIG" 2>/dev/null | head -1 || echo "false")
        local sniff_status
        sniff_status=$(check_sniff_state)
        local dns_status
        dns_status=$(jq -r '.dns.queryStrategy // "false"' "$CONFIG" 2>/dev/null | head -1 || echo "false")
        local policy_status
        policy_status=$(jq -r '.policy.levels["0"].connIdle // "false"' "$CONFIG" 2>/dev/null | head -1 || echo "false")
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
        if [[ -f "$limit_file" ]]; then
            gc_status=$(awk -F'=' '/^Environment="GOGC=/ {print $3}' "$limit_file" 2>/dev/null | tr -d '"' | head -1 || echo "100")
            gc_status=${gc_status:-"100 (默认)"}
        fi

        # ==========================================
        # 抓取系统层探针 (System 12-25)
        # ==========================================
        local dnsmasq_state=$(check_dnsmasq_state)
        local thp_state=$(check_thp_state)
        local mtu_state=$(check_mtu_state)
        local cpu_state=$(check_cpu_state)
        local ring_state=$(check_ring_state)
        local zram_state=$(check_zram_state)
        local journal_state=$(check_journal_state)
        local prio_state=$(check_process_priority_state)
        local cake_state=$(check_cake_state)
        local irq_state=$(check_irq_state)
        local gso_off_state=$(check_gso_off_state)
        local ackfilter_state=$(check_ackfilter_state)
        local ecn_state=$(check_ecn_state)
        local wash_state=$(check_wash_state)

        local app_off_count=0
        if [[ "$out_fastopen" != "true" ]]; then app_off_count=$((app_off_count + 1)); fi
        if [[ "$out_keepalive" != "30" ]]; then app_off_count=$((app_off_count + 1)); fi
        if [[ "$sniff_status" != "true" ]]; then app_off_count=$((app_off_count + 1)); fi
        if [[ "$dns_status" != "UseIP" ]]; then app_off_count=$((app_off_count + 1)); fi
        if [[ "$gc_status" == "100 (默认)" || "$gc_status" == "100" ]]; then app_off_count=$((app_off_count + 1)); fi
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

        # ==========================================
        # 终端渲染大屏
        # ==========================================
        local s1; if [[ "$out_fastopen" == "true" ]]; then s1="${cyan}开启${none}"; else s1="${gray}关闭${none}"; fi
        local s2; if [[ "$out_keepalive" == "30" ]]; then s2="${cyan}开启 (30s/15s)${none}"; else s2="${gray}系统默认${none}"; fi
        local s3; if [[ "$sniff_status" == "true" ]]; then s3="${cyan}开启${none}"; else s3="${gray}关闭${none}"; fi
        local s4; if [[ "$dns_status" == "UseIP" ]]; then s4="${cyan}开启${none}"; else s4="${gray}关闭${none}"; fi
        local s6; if [[ "$policy_status" == "60" ]]; then s6="${cyan}开启 (闲置60s)${none}"; else s6="${gray}默认 300s${none}"; fi
        local s7; if [[ "$affinity_state" == "true" ]]; then s7="${cyan}绑定单核${none}"; else s7="${gray}系统调度${none}"; fi
        local s8; if [[ "$mph_state" == "true" ]]; then s8="${cyan}MPH 路由${none}"; else s8="${gray}常规路由${none}"; fi
        
        local s9
        if [[ -z "$has_reality" ]]; then 
            s9="${gray}N/A${none}"
        else 
            if [[ "$maxtime_state" == "true" ]]; then s9="${cyan}严格 60s 防线${none}"; else s9="${gray}不限制${none}"; fi
        fi
        
        local s10; if [[ "$routeonly_status" == "true" ]]; then s10="${cyan}启用直通${none}"; else s10="${gray}默认过滤${none}"; fi
        local s11; if [[ "$buffer_state" == "true" ]]; then s11="${cyan}64KB 缓冲池${none}"; else s11="${gray}默认轻型${none}"; fi
        local s12; if [[ "$dnsmasq_state" == "true" ]]; then s12="${cyan}本地缓存加速${none}"; else s12="${gray}原生 DoH${none}"; fi
        
        local s13; if [[ "$thp_state" == "true" ]]; then s13="${cyan}关闭 THP${none}"; elif [[ "$thp_state" == "unsupported" ]]; then s13="${gray}不支持${none}"; else s13="${gray}开启 THP${none}"; fi
        local s14; if [[ "$mtu_state" == "true" ]]; then s14="${cyan}开启 MTU 探测${none}"; elif [[ "$mtu_state" == "unsupported" ]]; then s14="${gray}不支持${none}"; else s14="${gray}未开启${none}"; fi
        local s15; if [[ "$cpu_state" == "true" ]]; then s15="${cyan}高性能模式${none}"; elif [[ "$cpu_state" == "unsupported" ]]; then s15="${gray}不支持${none}"; else s15="${gray}节能模式${none}"; fi
        local s16; if [[ "$ring_state" == "true" ]]; then s16="${cyan}环形缓冲收缩${none}"; elif [[ "$ring_state" == "unsupported" ]]; then s16="${gray}不支持${none}"; else s16="${gray}系统默认${none}"; fi
        local s17; if [[ "$zram_state" == "true" ]]; then s17="${cyan}开启 ZRAM${none}"; elif [[ "$zram_state" == "unsupported" ]]; then s17="${gray}不支持${none}"; else s17="${gray}未开启${none}"; fi
        local s18; if [[ "$journal_state" == "true" ]]; then s18="${cyan}纯内存日志${none}"; elif [[ "$journal_state" == "unsupported" ]]; then s18="${gray}不支持${none}"; else s18="${gray}磁盘写入${none}"; fi
        local s19; if [[ "$prio_state" == "true" ]]; then s19="${cyan}进程提权 (OOM防杀)${none}"; else s19="${gray}默认优先度${none}"; fi
        local s20; if [[ "$cake_state" == "true" ]]; then s20="${cyan}CAKE 队列${none}"; else s20="${gray}FQ 队列${none}"; fi
        local s21; if [[ "$irq_state" == "true" ]]; then s21="${cyan}硬中断隔离${none}"; elif [[ "$irq_state" == "unsupported" ]]; then s21="${gray}不支持${none}"; else s21="${gray}系统负载均衡${none}"; fi
        
        local s22
        if [[ "$gso_off_state" == "true" ]]; then 
            s22="${cyan}硬件卸载禁用 (低延迟)${none}"
        elif [[ "$gso_off_state" == "unsupported" ]]; then 
            s22="${gray}驱动锁定无法修改${none}"
        else 
            s22="${gray}系统默认硬件卸载${none}"
        fi
        
        local s23; if [[ "$ackfilter_state" == "true" ]]; then s23="${cyan}ACK 过滤开启${none}"; else s23="${gray}未开启${none}"; fi
        local s24; if [[ "$ecn_state" == "true" ]]; then s24="${cyan}ECN 标记开启${none}"; else s24="${gray}未开启${none}"; fi
        local s25; if [[ "$wash_state" == "true" ]]; then s25="${cyan}Wash 数据清洗开启${none}"; else s25="${gray}未开启${none}"; fi

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
        echo -e "  ${magenta}--- Linux 系统及内核高级网络调优 (12-25) ---${none}"
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
        echo -e "  ${red}28) 一键执行: 应用全量极限网络调优 (执行后将自动重启)${none}"
        echo "  0) 返回上一级菜单"
        hr
        read -rp "请选择要调整的配置项: " app_opt

        if [[ "$app_opt" == "0" ]]; then return; fi
        
        case "$app_opt" in
            1)
                if [[ "$out_fastopen" == "true" ]]; then
                    _safe_jq_write '
                      .outbounds = [
                          .outbounds[]? | if (.protocol == "freedom") then
                              del(.streamSettings.sockopt.tcpNoDelay, .streamSettings.sockopt.tcpFastOpen)
                          else . end
                      ] |
                      .inbounds = [
                          .inbounds[]? | if (.protocol == "vless" or .protocol == "shadowsocks") then
                              del(.streamSettings.sockopt.tcpNoDelay, .streamSettings.sockopt.tcpFastOpen)
                          else . end
                      ]
                    '
                else
                    _safe_jq_write '
                      .outbounds = [
                          .outbounds[]? | if (.protocol == "freedom") then
                              .streamSettings = (.streamSettings // {}) |
                              .streamSettings.sockopt = (.streamSettings.sockopt // {}) |
                              .streamSettings.sockopt.tcpNoDelay = true |
                              .streamSettings.sockopt.tcpFastOpen = true
                          else . end
                      ] |
                      .inbounds = [
                          .inbounds[]? | if (.protocol == "vless" or .protocol == "shadowsocks") then
                              .streamSettings = (.streamSettings // {}) |
                              .streamSettings.sockopt = (.streamSettings.sockopt // {}) |
                              .streamSettings.sockopt.tcpNoDelay = true |
                              .streamSettings.sockopt.tcpFastOpen = true
                          else . end
                      ]
                    '
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                read -rp "设置已应用，按 Enter 继续..." _
                ;;
            2)
                if [[ "$out_keepalive" == "30" ]]; then
                    _safe_jq_write '
                      .outbounds = [
                          .outbounds[]? | if (.protocol == "freedom") then
                              del(.streamSettings.sockopt.tcpKeepAliveIdle, .streamSettings.sockopt.tcpKeepAliveInterval)
                          else . end
                      ] |
                      .inbounds = [
                          .inbounds[]? | if (.protocol == "vless" or .protocol == "shadowsocks") then
                              del(.streamSettings.sockopt.tcpKeepAliveIdle, .streamSettings.sockopt.tcpKeepAliveInterval)
                          else . end
                      ]
                    '
                else
                    _safe_jq_write '
                      .outbounds = [
                          .outbounds[]? | if (.protocol == "freedom") then
                              .streamSettings = (.streamSettings // {}) |
                              .streamSettings.sockopt = (.streamSettings.sockopt // {}) |
                              .streamSettings.sockopt.tcpKeepAliveIdle = 30 |
                              .streamSettings.sockopt.tcpKeepAliveInterval = 15
                          else . end
                      ] |
                      .inbounds = [
                          .inbounds[]? | if (.protocol == "vless" or .protocol == "shadowsocks") then
                              .streamSettings = (.streamSettings // {}) |
                              .streamSettings.sockopt = (.streamSettings.sockopt // {}) |
                              .streamSettings.sockopt.tcpKeepAliveIdle = 30 |
                              .streamSettings.sockopt.tcpKeepAliveInterval = 15
                          else . end
                      ]
                    '
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                read -rp "设置已应用，按 Enter 继续..." _
                ;;
            3)
                if [[ "$sniff_status" == "true" ]]; then
                    _safe_jq_write '
                      .inbounds = [
                          .inbounds[]? | if (.protocol == "vless" or .protocol == "shadowsocks") then
                              .sniffing.metadataOnly = false
                          else . end
                      ]
                    '
                else
                    _safe_jq_write '
                      .inbounds = [
                          .inbounds[]? | if (.protocol == "vless" or .protocol == "shadowsocks") then
                              .sniffing = (.sniffing // {}) |
                              .sniffing.metadataOnly = true
                          else . end
                      ]
                    '
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                read -rp "设置已应用，按 Enter 继续..." _
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
                read -rp "设置已应用，按 Enter 继续..." _
                ;;
            5)
                if [[ -f "$limit_file" ]]; then
                    local TOTAL_MEM
                    TOTAL_MEM=$(free -m | awk '/Mem/{print $2}' || echo "1024")
                    local DYNAMIC_GOGC=100
                    if ((TOTAL_MEM >= 1800)); then 
                        DYNAMIC_GOGC=1000
                    elif ((TOTAL_MEM >= 900)); then 
                        DYNAMIC_GOGC=500
                    else 
                        DYNAMIC_GOGC=300
                    fi
                    
                    if grep -q "Environment=\"GOGC=" "$limit_file"; then
                        if [[ "$gc_status" == "100 (默认)" || "$gc_status" == "100" ]]; then
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
                read -rp "设置已应用，按 Enter 继续..." _
                ;;
            6)
                if [[ "$policy_status" == "60" ]]; then
                    _safe_jq_write 'del(.policy)'
                else
                    _safe_jq_write '.policy = {"levels":{"0":{"handshake":3,"connIdle":60}},"system":{"statsInboundDownlink":false,"statsInboundUplink":false}}'
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                read -rp "设置已应用，按 Enter 继续..." _
                ;;
            7)
                if [[ "$affinity_state" == "true" ]]; then
                    _toggle_affinity_off
                else
                    _toggle_affinity_on
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                read -rp "设置已应用，按 Enter 继续..." _
                ;;
            8)
                if [[ "$mph_state" == "true" ]]; then
                    _safe_jq_write 'del(.routing.domainMatcher)'
                else
                    _safe_jq_write '.routing = (.routing // {}) | .routing.domainMatcher = "mph"'
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                read -rp "设置已应用，按 Enter 继续..." _
                ;;
            9)
                if [[ -n "$has_reality" ]]; then
                    if [[ "$maxtime_state" == "true" ]]; then
                        _safe_jq_write '
                          .inbounds = [
                              .inbounds[]? | if (.protocol == "vless" and .streamSettings.security == "reality") then
                                  del(.streamSettings.realitySettings.maxTimeDiff)
                              else . end
                          ]
                        '
                    else
                        _safe_jq_write '
                          .inbounds = [
                              .inbounds[]? | if (.protocol == "vless" and .streamSettings.security == "reality") then
                                  .streamSettings.realitySettings = (.streamSettings.realitySettings // {}) |
                                  .streamSettings.realitySettings.maxTimeDiff = 60000
                              else . end
                          ]
                        '
                    fi
                    systemctl restart xray >/dev/null 2>&1 || true
                fi
                read -rp "设置已应用，按 Enter 继续..." _
                ;;
            10)
                if [[ "$routeonly_status" == "true" ]]; then
                    _safe_jq_write '
                      .inbounds = [
                          .inbounds[]? | if (.protocol == "vless" or .protocol == "shadowsocks") then
                              .sniffing.routeOnly = false
                          else . end
                      ]
                    '
                else
                    _safe_jq_write '
                      .inbounds = [
                          .inbounds[]? | if (.protocol == "vless" or .protocol == "shadowsocks") then
                              .sniffing = (.sniffing // {}) |
                              .sniffing.routeOnly = true
                          else . end
                      ]
                    '
                fi
                systemctl restart xray >/dev/null 2>&1 || true
                read -rp "设置已应用，按 Enter 继续..." _
                ;;
            11) toggle_buffer; systemctl restart xray >/dev/null 2>&1 || true; read -rp "设置已应用，按 Enter 继续..." _ ;;
            12) toggle_dnsmasq; read -rp "设置已应用，按 Enter 继续..." _ ;;
            13) toggle_thp; read -rp "设置已应用，按 Enter 继续..." _ ;;
            14) toggle_mtu; read -rp "设置已应用，按 Enter 继续..." _ ;;
            15) toggle_cpu; read -rp "设置已应用，按 Enter 继续..." _ ;;
            16) toggle_ring; read -rp "设置已应用，按 Enter 继续..." _ ;;
            17) toggle_zram; read -rp "设置已应用，按 Enter 继续..." _ ;;
            18) toggle_journal; read -rp "设置已应用，按 Enter 继续..." _ ;;
            19) toggle_process_priority; systemctl restart xray >/dev/null 2>&1 || true; read -rp "设置已应用，按 Enter 继续..." _ ;;
            20) toggle_cake; read -rp "设置已应用，按 Enter 继续..." _ ;;
            21) toggle_irq; read -rp "设置已应用，按 Enter 继续..." _ ;;
            22) 
                if [[ "$gso_off_state" == "unsupported" ]]; then
                    warn "驱动处于锁定状态，无法更改硬件卸载。"
                    sleep 2
                else
                    toggle_gso_off
                    read -rp "设置已应用，按 Enter 继续..." _ 
                fi
                ;;
            23) toggle_ackfilter; read -rp "设置已应用，按 Enter 继续..." _ ;;
            24) toggle_ecn; read -rp "设置已应用，按 Enter 继续..." _ ;;
            25) toggle_wash; read -rp "设置已应用，按 Enter 继续..." _ ;;
            26)
                if ((app_off_count > 0)); then
                    info "正在开启应用层全量参数..."
                    _turn_on_app
                    systemctl restart xray >/dev/null 2>&1 || true
                else
                    info "正在恢复应用层默认配置..."
                    _turn_off_app
                    systemctl restart xray >/dev/null 2>&1 || true
                fi
                read -rp "执行完毕，按 Enter 继续..." _
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
                    info "12-25 系统级满血激活！"
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
                    info "12-25 系统级已恢复默认状态！"
                fi
                read -rp "执行完毕，按 Enter 继续..." _
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
                warn "全域网络栈及内核调优参数已变更。"
                info "系统将在 5 秒后自动重启应用配置..."
                sleep 5
                sync
                reboot
                ;;
        esac
    done
}

# ==============================================================================
# [ 区块 IX: Xray 核心架构安装与部署主逻辑 ]
# ==============================================================================
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
    read -rp "  请选择 (默认 1): " proto_choice
    proto_choice=${proto_choice:-1}

    if [[ "$proto_choice" == "1" || "$proto_choice" == "3" ]]; then
        while true; do 
            read -rp "请设置 VLESS 监听端口 (默认 443): " input_p
            input_p=${input_p:-443}
            if validate_port "$input_p"; then 
                LISTEN_PORT="$input_p"
                break
            fi
        done
        read -rp "请设置节点备注名 (默认 xp-reality): " input_remark
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
            read -rp "请设置 SS 监听端口 (默认 8388): " input_s
            input_s=${input_s:-8388}
            if validate_port "$input_s"; then 
                ss_port="$input_s"
                break
            fi
        done
        ss_pass=$(head -c 24 /dev/urandom | base64 | tr -d '=/+\n' | head -c 24)
        
        echo -e "  ${cyan}选择 SS 加密方式：${none}"
        echo "  1) aes-256-gcm (推荐)  2) aes-128-gcm  3) chacha20-ietf-poly1305"
        read -rp "  选择编号: " mc
        case "${mc:-1}" in
            2) ss_method="aes-128-gcm" ;;
            3) ss_method="chacha20-ietf-poly1305" ;;
            *) ss_method="aes-256-gcm" ;;
        esac
        
        if [[ "$proto_choice" == "2" ]]; then 
            read -rp "请设置节点备注名 (默认 xp-reality): " input_remark
            REMARK_NAME=${input_remark:-xp-reality}
        fi
    fi

    info "正在拉取 Xray 最新核心组件..."
    if ! bash -c "$(curl -fsSL --connect-timeout 10 https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1; then
        warn "通过官方脚本拉取 Xray 发生异常，您可以稍后通过菜单 5 尝试重新更新。"
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

    # === V182 核心修复: JQ 组合 JSON 绝对隔离写入 ===
    if [[ "$proto_choice" == "1" || "$proto_choice" == "3" ]]; then
        local keys priv pub uuid sid ctime
        keys=$("$XRAY_BIN" x25519 2>/dev/null || echo "")
        priv=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' ' || echo "")
        pub=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' ' || echo "")
        uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
        sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n')
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
        # 强制采用 --slurpfile 引用为内部变量，避免 JQ 语法树交叉污染
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
        info "安装完成！网络节点已就绪。"
        do_summary
    else
        error "系统配置加载失败，请通过日志系统排查。"
        return 1
    fi
    
    while true; do
        read -rp "按 Enter 返回菜单，或输入 b 重新配置 SNI 防火墙矩阵: " opt
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
# [ 区块 X: 节点信息分发与系统管理大厅 ]
# ==============================================================================

do_summary() {
    if [[ ! -f "$CONFIG" ]]; then 
        return
    fi
    title "Xray 节点连接信息"
    
    local client_count
    client_count=$(jq '.inbounds[]? | select(.protocol=="vless") | .settings.clients | length' "$CONFIG" 2>/dev/null || echo 0)
    
    if ((client_count > 0)); then
        local port pub main_sni
        port=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .port' "$CONFIG" 2>/dev/null || echo "")
        pub=$(jq -r  '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.publicKey' "$CONFIG" 2>/dev/null || echo "")
        main_sni=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0]' "$CONFIG" 2>/dev/null || echo "")

        for ((i=0; i<client_count; i++)); do
            local uuid remark sid target_sni
            uuid=$(jq -r ".inbounds[]? | select(.protocol==\"vless\") | .settings.clients[$i].id" "$CONFIG" 2>/dev/null || echo "")
            remark=$(jq -r ".inbounds[]? | select(.protocol==\"vless\") | .settings.clients[$i].email // \"$REMARK_NAME\"" "$CONFIG" 2>/dev/null || echo "")
            sid=$(jq -r ".inbounds[]? | select(.protocol==\"vless\") | .streamSettings.realitySettings.shortIds[$i]" "$CONFIG" 2>/dev/null || echo "")
            
            target_sni=$(grep "^$uuid|" "$USER_SNI_MAP" 2>/dev/null | cut -d'|' -f2 || echo "")
            if [[ -z "$target_sni" ]]; then
                target_sni=$main_sni
            fi

            if [[ -z "$uuid" || "$uuid" == "null" ]]; then 
                continue
            fi
            
            hr
            echo -e "  ${cyan}【协议: VLESS-Reality (Vision) | 备注: $remark】${none}"
            printf "  ${yellow}%-12s${none} %s\n" "主机地址:" "$SERVER_IP"
            printf "  ${yellow}%-12s${none} %s\n" "通信端口:" "$port"
            printf "  ${yellow}%-12s${none} %s\n" "用户凭证:" "$uuid"
            printf "  ${yellow}%-12s${none} %s\n" "伪装域名:" "$target_sni"
            printf "  ${yellow}%-12s${none} %s\n" "防重放ID:" "$sid"
            
            local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${target_sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${remark}"
            echo -e "\n  ${cyan}配置链接:${none} $link\n"
            if command -v qrencode >/dev/null 2>&1; then 
                qrencode -m 2 -t UTF8 "$link"
            fi
        done
    fi

    local has_ss
    has_ss=$(jq -r '.inbounds[]? | select(.protocol=="shadowsocks") | .protocol' "$CONFIG" 2>/dev/null | head -1 || echo "")
    if [[ -n "$has_ss" && "$has_ss" != "null" ]]; then
        local s_port s_pass s_method
        s_port=$(jq -r '.inbounds[]? | select(.protocol=="shadowsocks") | .port' "$CONFIG" 2>/dev/null || echo "")
        s_pass=$(jq -r '.inbounds[]? | select(.protocol=="shadowsocks") | .settings.password' "$CONFIG" 2>/dev/null || echo "")
        s_method=$(jq -r '.inbounds[]? | select(.protocol=="shadowsocks") | .settings.method' "$CONFIG" 2>/dev/null || echo "")
        
        hr
        echo -e "  ${cyan}【协议: Shadowsocks】${none}"
        printf "  ${yellow}%-12s${none} %s\n" "通信端口:" "$s_port"
        printf "  ${yellow}%-12s${none} %s\n" "访问密码:" "$s_pass"
        printf "  ${yellow}%-12s${none} %s\n" "加密方式:" "$s_method"
        
        local b64
        b64=$(printf '%s' "${s_method}:${s_pass}" | base64 | tr -d '\n' || echo "")
        local ss_link="ss://${b64}@${SERVER_IP}:${s_port}#${REMARK_NAME}-SS"
        echo -e "\n  ${cyan}配置链接:${none} $ss_link\n"
        if command -v qrencode >/dev/null 2>&1; then 
            qrencode -m 2 -t UTF8 "$ss_link"
        fi
    fi

    hr
    echo -e "  ${gray}配置主文档: $CONFIG | 数据备份库: $BACKUP_DIR${none}"
}

do_user_manager() {
    while true; do
        title "用户与认证管理"
        if [[ ! -f "$CONFIG" ]]; then 
            error "未发现有效配置文件。"
            return
        fi

        local clients
        clients=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .settings?.clients[]? | .id + "|" + (.email // "无备注")' "$CONFIG" 2>/dev/null || echo "")
        if [[ -z "$clients" || "$clients" == "null" ]]; then 
            error "未提取到 VLESS 用户记录。"
            return
        fi

        local tmp_users="/tmp/xray_users_$$.txt"
        echo "$clients" | awk -F'|' '{print NR"|"$1"|"$2}' > "$tmp_users" || true
        
        echo -e "系统当前已授权用户列表："
        while IFS='|' read -r num uid remark; do
            local utime
            utime=$(grep "^$uid|" "$USER_TIME_MAP" 2>/dev/null | cut -d'|' -f2 || echo "未知")
            echo -e "  $num) 用户: ${cyan}$remark${none} | 签发: ${gray}$utime${none} | ID: ${yellow}$uid${none}"
        done < "$tmp_users"
        hr
        
        echo "  a) 自动新增用户"
        echo "  m) 外部导入指定用户"
        echo "  s) 重新指派用户伪装 SNI"
        echo "  d) 吊销选中用户凭证"
        echo "  q) 退出"
        read -rp "请输入操作代码: " uopt

        case "$uopt" in
            a|A)
                local nu sid ctime u_remark
                nu=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
                sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n' || echo "")
                ctime=$(date +"%Y-%m-%d %H:%M")
                read -rp "请指派用户备注名 (默认 User-$sid): " u_remark
                u_remark=${u_remark:-User-${sid}}

                _safe_jq_write --arg id "$nu" --arg email "$u_remark" '
                    (.inbounds[]? | select(.protocol=="vless") | .settings.clients) += [{"id":$id,"flow":"xtls-rprx-vision","email":$email}]
                '
                _safe_jq_write --arg sid "$sid" '
                    (.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.shortIds) += [$sid]
                '

                echo "$nu|$ctime" >> "$USER_TIME_MAP"
                ensure_xray_is_alive

                local port pub sni
                port=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .port' "$CONFIG" 2>/dev/null | head -1)
                pub=$(jq -r  '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.publicKey' "$CONFIG" 2>/dev/null | head -1)
                sni=$(jq -r  '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0]' "$CONFIG" 2>/dev/null | head -1)
                
                local link="vless://${nu}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${u_remark}"
                info "用户授权成功。"; echo -e "\n  ${cyan}配置链接:${none} $link\n"
                read -rp "按 Enter 继续..." _
                ;;
            m|M)
                local m_remark m_uuid m_sid ctime
                read -rp "请提供外部用户备注 (默认 ImportedUser): " m_remark
                m_remark=${m_remark:-ImportedUser}
                read -rp "请提供外部 UUID: " m_uuid
                if [[ -z "$m_uuid" ]]; then continue; fi
                read -rp "请提供外部 ShortId: " m_sid
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
                read -rp "为他指定专属 SNI (直接回车则使用默认): " m_sni
                if [[ -n "$m_sni" ]]; then
                    _safe_jq_write --arg sni "$m_sni" '
                        (.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) += [$sni] |
                        (.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) |= unique
                    '
                    sed -i "/^$m_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                    echo "$m_uuid|$m_sni" >> "$USER_SNI_MAP"
                else
                    m_sni=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0]' "$CONFIG" 2>/dev/null | head -1)
                fi

                ensure_xray_is_alive
                local port pub
                port=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .port' "$CONFIG" 2>/dev/null | head -1)
                pub=$(jq -r  '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.publicKey' "$CONFIG" 2>/dev/null | head -1)
                
                local link="vless://${m_uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${m_sni}&fp=chrome&pbk=${pub}&sid=${m_sid}&type=tcp#${m_remark}"
                info "导入成功！"; echo -e "\n  ${cyan}配置链接:${none} $link\n"
                read -rp "按 Enter 继续..." _
                ;;
            s|S)
                local snum t_uuid t_remark u_sni
                read -rp "输入列表中的序号: " snum
                t_uuid=$(awk -F'|' -v id="${snum:-0}" '$1==id{print $2}' "$tmp_users" 2>/dev/null || echo "")
                t_remark=$(awk -F'|' -v id="${snum:-0}" '$1==id{print $3}' "$tmp_users" 2>/dev/null || echo "")
                
                if [[ -n "$t_uuid" ]]; then
                    read -rp "指派新的专属顶级 SNI: " u_sni
                    if [[ -n "$u_sni" ]]; then
                        _safe_jq_write --arg sni "$u_sni" '
                            (.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) += [$sni] |
                            (.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) |= unique
                        '
                        sed -i "/^$t_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                        echo "$t_uuid|$u_sni" >> "$USER_SNI_MAP"
                        
                        ensure_xray_is_alive
                        info "物理 SNI 绑定成功: $u_sni"
                        
                        local port idx sid pub
                        port=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .port' "$CONFIG" 2>/dev/null | head -1)
                        idx=$(( ${snum:-0} - 1 ))
                        sid=$(jq -r ".inbounds[]? | select(.protocol==\"vless\") | .streamSettings.realitySettings.shortIds[$idx]" "$CONFIG" 2>/dev/null || echo "")
                        pub=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.publicKey' "$CONFIG" 2>/dev/null | head -1)
                        
                        local link="vless://${t_uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${u_sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${t_remark}"
                        echo -e "\n  ${cyan}刷新后的特权直连:${none} $link\n"
                        read -rp "按 Enter 继续..." _
                    fi
                else 
                    error "无效序号！"
                fi
                ;;
            d|D)
                local dnum total t_uuid idx
                read -rp "输入欲吊销的序号: " dnum
                total=$(wc -l < "$tmp_users" 2>/dev/null || echo 0)
                
                if ((total <= 1)); then 
                    error "系统必须保留至少一个活跃凭证！"
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
                        info "凭证 $t_uuid 已被吊销。"
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
        title "全局防火墙阻断策略管理"
        if [[ ! -f "$CONFIG" ]]; then 
            return
        fi
        
        local bt_en ad_en
        bt_en=$(jq -r '.routing.rules[]? | select(.protocol != null) | select(.protocol | index("bittorrent")) | ._enabled' "$CONFIG" 2>/dev/null | head -1 || echo "false")
        ad_en=$(jq -r '.routing.rules[]? | select(.domain != null) | select(.domain | index("geosite:category-ads-all")) | ._enabled' "$CONFIG" 2>/dev/null | head -1 || echo "false")
        
        echo -e "  1) BT 下载协议阻断限制  | 状态: ${yellow}${bt_en:-未知}${none}"
        echo -e "  2) 全球广告域名黑洞过滤 | 状态: ${yellow}${ad_en:-未知}${none}"
        echo "  0) 返回"
        read -rp "请选择: " bc
        
        case "$bc" in
            1)
                local nv="true"
                if [[ "$bt_en" == "true" ]]; then nv="false"; fi
                _safe_jq_write --argjson nv "$nv" '
                  .routing.rules = [
                      .routing.rules[]? | if .protocol != null and (.protocol | index("bittorrent")) then
                          ._enabled = $nv
                      else . end
                  ]
                '
                ensure_xray_is_alive; info "BT 限制状态已变更为: $nv" 
                ;;
            2)
                local nv="true"
                if [[ "$ad_en" == "true" ]]; then nv="false"; fi
                _safe_jq_write --argjson nv "$nv" '
                  .routing.rules = [
                      .routing.rules[]? | if .domain != null and (.domain | index("geosite:category-ads-all")) then
                          ._enabled = $nv
                      else . end
                  ]
                '
                ensure_xray_is_alive; info "广告过滤状态已变更为: $nv" 
                ;;
            0) return ;;
        esac
    done
}

# ==============================================================================
# [ 区块 XI: 监控日志与系统重构 ]
# ==============================================================================

do_status_menu() {
    while true; do
        title "系统运行状态与流量统计监控"
        echo "  1) 查看 Xray 服务运行状态"
        echo "  2) 查看本机网络入口与解析路由"
        echo "  3) 查看服务器网卡流量统计 (vnstat)"
        echo "  4) [系统级] 查看实时网络连接及归属追踪"
        echo "  5) [高级调整] 修改系统对 Xray 进程的调度权重 (Nice)"
        echo "  6) 查看 Xray 应用运行日志"
        echo "  7) 查看 Xray 系统错误日志"
        echo "  8) 管理自动配置备份与灾备恢复"
        echo "  0) 返回主菜单"
        hr
        read -rp "请选择: " s
        
        case "$s" in
            1) systemctl status xray --no-pager || true; read -rp "按 Enter 继续..." _ ;;
            2) 
                echo -e "\n  公网 IP: ${green}$SERVER_IP${none}\n  DNS 路由记录: "
                grep "^nameserver" /etc/resolv.conf 2>/dev/null || echo "    读取异常"
                echo -e "  服务监听端口:"
                ss -tlnp 2>/dev/null | grep xray || echo "    暂未监听"
                read -rp "按 Enter 继续..." _ 
                ;;
            3) 
                if ! command -v vnstat >/dev/null 2>&1; then 
                    warn "vnstat 未安装，无法执行该功能。"
                    read -rp "按 Enter 继续..." _
                    continue
                fi
                clear; title "服务器网卡流量数据统计"
                (vnstat -m 3 2>/dev/null || true)
                read -rp "查阅完毕，按 Enter 返回..." _
                ;;
            4)
                while true; do
                    clear; title "实时连接追踪网络"
                    local x_pids=$(pidof xray 2>/dev/null | xargs | tr -s ' ' '|' || echo "")
                    if [[ -n "$x_pids" ]]; then
                        echo -e "  ${cyan}【端口并发概览】${none}"
                        ss -ntupa 2>/dev/null | grep -E "pid=($x_pids)[,)]" | awk '{print $1"_"$2}' | sort | uniq -c | sort -nr | awk '{printf "    通道状态: %-15s : 活跃链接数 %s\n", $2, $1}' || echo "    暂无连接"
                        echo -e "\n  ${cyan}【外网独立 IP 追踪 (TOP 10)】${none}"
                        local ips=$(ss -ntupa 2>/dev/null | grep -E "pid=($x_pids)[,)]" | grep -vE "LISTEN|UNCONN" | awk '{print $6}' | sed -E 's/:[0-9]+$//' | tr -d '[]' | grep -vE "^127\.0\.0\.1$|^0\.0\.0\.0$|^::$|^\*$|^::ffff:127\.0\.0\.1$" || echo "")
                        if [[ -n "$ips" ]]; then
                            echo "$ips" | sort | uniq -c | sort -nr | head -n 10 | awk '{printf "    来源 IP: %-18s (并发数: %s)\n", $2, $1}'
                            local total_ips=$(echo "$ips" | sort | uniq | wc -l)
                            echo -e "\n  当前独立访客总数: ${yellow}${total_ips}${none}"
                        else 
                            echo -e "    ${gray}无外部连接。${none}"
                        fi
                    else 
                        echo -e "  ${red}未探测到服务进程！${none}"
                    fi
                    echo -e "\n  ${green}实时雷达运行中... [ q ] 退出${none}"
                    if read -t 2 -n 1 -s cmd 2>/dev/null; then
                        if [[ "$cmd" == "q" || "$cmd" == "Q" || "$cmd" == $'\e' ]]; then break; fi
                    fi
                done
                ;;
            5)
                while true; do
                    clear; title "系统级调度提权 (Nice)"
                    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
                    local current_nice="-20"
                    if [[ -f "$limit_file" ]]; then 
                        if grep -q "^Nice=" "$limit_file" 2>/dev/null; then 
                            current_nice=$(awk -F'=' '/^Nice=/ {print $2}' "$limit_file" | head -1 || echo "-20")
                        fi
                    fi
                    echo -e "  当前调度权重 (Nice): ${cyan}${current_nice}${none} (有效范围: -20 到 -10)"
                    hr
                    read -rp "  输入新权重 (q 退出): " new_nice
                    if [[ "$new_nice" == "q" || "$new_nice" == "Q" ]]; then break; fi
                    if [[ "$new_nice" =~ ^-[1-2][0-9]$ ]] && ((new_nice >= -20 && new_nice <= -10)); then
                        sed -i "s/^Nice=.*/Nice=$new_nice/" "$limit_file" 2>/dev/null || true
                        systemctl daemon-reload >/dev/null 2>&1 || true
                        info "配置已应用，5 秒后重启服务生效..."
                        sleep 5; systemctl restart xray >/dev/null 2>&1 || true
                        info "提权完成。"
                        read -rp "按 Enter 返回..." _; break
                    else 
                        error "输入格式越界！"
                        sleep 2
                    fi
                done
                ;;
            6) clear; title "应用运行日志"; tail -n 50 "$LOG_DIR/xray.log" 2>/dev/null || echo "  无记录。"; read -rp "按 Enter 返回..." _ ;;
            7) clear; title "系统错误日志"; tail -n 30 "$LOG_DIR/error.log" 2>/dev/null || echo "  无异常。"; read -rp "按 Enter 返回..." _ ;;
            8)
                clear; title "灾备快照系统"
                ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null || echo "暂无备份"
                echo -e "\n  r) 恢复至最近快照\n  c) 建立当前配置快照\n  0) 返回"
                read -rp "选择操作: " bopt
                if [[ "$bopt" == "r" ]]; then restore_latest_backup; fi
                if [[ "$bopt" == "c" ]]; then backup_config; info "快照已生成"; read -rp "Enter..." _; fi
                ;;
            0) return ;;
        esac
    done
}

do_sys_init_menu() {
    while true; do
        title "系统级环境初始化与组件安装"
        echo "  1) 安装核心依赖、清理系统冗余并同步时区"
        echo "  2) 系统级锁定本地 DNS (resolvconf)"
        echo "  3) 从 Linux Kernel 官方直接编译原版内核并启用 BBR3"
        echo "  4) 网卡发送队列 (TX Queue) 性能调优"
        echo "  5) 深入配置系统 Sysctl 网络栈底层极速参数"
        echo "  6) 网络应用层与系统级高级调优 (25项)"
        echo "  7) 配置高级 CAKE 网络调度控制引擎"
        echo "  0) 返回主菜单"
        hr
        read -rp "请选择您的操作: " sys_opt
        
        case "$sys_opt" in
            1) 
                info "正在拉取依赖与时区同步..."
                apt-get update -y >/dev/null 2>&1 || true
                pkg_install wget curl sudo socat ntpdate e2fsprogs pkg-config iproute2 ethtool
                timedatectl set-timezone Asia/Kuala_Lumpur 2>/dev/null || true
                ntpdate -u us.pool.ntp.org 2>/dev/null || true
                hwclock --systohc 2>/dev/null || true
                check_and_create_1gb_swap
                info "初始化完毕。"
                read -rp "按 Enter 继续..." _ 
                ;;
            2) do_change_dns ;;
            3) do_xanmod_compile ;;
            4) do_txqueuelen_opt ;;
            5) do_perf_tuning ;;
            6) do_app_level_tuning_menu ;;
            7) config_cake_advanced ;;
            0) return ;;
        esac
    done
}

do_update_core() {
    title "Xray 核心在线更新"
    info "获取官方释放的最新构建包..."
    bash -c "$(curl -fsSL --connect-timeout 10 https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1 || true
    fix_xray_systemd_limits
    systemctl restart xray >/dev/null 2>&1 || true
    local cur_ver
    cur_ver=$($XRAY_BIN version 2>/dev/null | head -n1 | awk '{print $2}' || echo "获取异常")
    info "已应用最新核心，当前检测版本: ${cyan}$cur_ver${none}"
    read -rp "按 Enter 返回..." _
}

_update_matrix() {
    if [[ ! -f "$CONFIG" ]]; then return; fi
    echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
    _safe_jq_write --arg dest "$BEST_SNI:443" --slurpfile snis /tmp/sni_array.json '
        .inbounds = [
            .inbounds[]? | if (.protocol == "vless") then
                .streamSettings.realitySettings.serverNames = $snis[0] |
                .streamSettings.realitySettings.dest = $dest
            else . end
        ]
    '
    rm -f /tmp/sni_array.json 2>/dev/null || true
    ensure_xray_is_alive
    info "已成功切换服务器伪装入口。"
}

do_fallback_probe() {
    clear
    title "Reality 回落 (Fallback) 防火墙参数查看"
    jq -r '
      .inbounds[]? | select(.protocol=="vless" and .streamSettings.security=="reality") | .streamSettings.realitySettings | 
      "  [拦截参数详情]\n    上传拦截阈值 (bytesPerSec) : \(.limitFallbackUpload.bytesPerSec // "未开启")\n    下载拦截阈值 (bytesPerSec) : \(.limitFallbackDownload.bytesPerSec // "未开启")"
    ' "$CONFIG" 2>/dev/null || warn "JSON 数据提取发生错误。"
    echo ""
    read -rp "按 Enter 返回上一级..." _
}

do_uninstall() {
    title "彻底卸载 Xray 及相关组件"
    read -rp "该操作将清除全部 Xray 软件运行残留及数据配置，是否继续？(y/n): " confirm
    if [[ "$confirm" != "y" ]]; then 
        return
    fi
    
    info "开始反部署并清理核心..."
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
    
    info "卸载作业已全部成功完成。服务器运行环境已复原。"
    exit 0
}

# ==============================================================================
# [ 区块 XII: 顶层调度与用户操作菜单 ]
# ==============================================================================
main_menu() {
    while true; do
        clear
        echo -e "${blue}======================================================================${none}"
        echo -e "  ${magenta}Xray 高级管理脚本 (专业版 V182)${none}"
        
        local svc
        svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        if [[ "$svc" == "active" ]]; then 
            svc="${green}运行中 (Active)${none}"
        else 
            svc="${red}未运行 (Inactive)${none}"
        fi
        
        echo -e "  服务状态: $svc | 系统命令: ${cyan}xrv${none} | 对外通信地址: ${yellow}${SERVER_IP}${none}"
        echo -e "${blue}======================================================================${none}"
        echo "  1) Xray 核心部署与网络架构初始化"
        echo "  2) 用户与认证管理"
        echo "  3) Xray 节点连接信息"
        echo "  4) 强制刷新 Geo 地理路由数据库"
        echo "  5) Xray 服务组件在线热升级"
        echo "  6) 重新规划安全伪装网络 (SNI)"
        echo "  7) 全局防火墙阻断策略管理 (BT/广告)"
        echo "  8) 查看 Reality 回落防御参数"
        echo "  9) 系统运行状态与流量统计监控"
        echo "  10) 系统级环境初始化与组件安装"
        echo "  0) 退出"
        echo -e "  ${red}88) 卸载 Xray 及清理运行环境${none}"
        hr
        read -rp "请输入对应的操作编号: " num
        
        case "$num" in
            1) do_install ;;
            2) do_user_manager ;;
            3) 
                do_summary
                while true; do 
                    read -rp "按 Enter 返回主菜单，或输入 b 重新选择 SNI: " rb
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
                info "请求最新分发规则与 IP 资产库..."
                bash "$UPDATE_DAT_SCRIPT" >/dev/null 2>&1 || true
                ensure_xray_is_alive
                read -rp "操作已执行，按 Enter 继续..." _ 
                ;;
            5) do_update_core ;;
            6) 
                if choose_sni; then 
                    _update_matrix
                    do_summary
                    read -rp "按 Enter 键返回主菜单..." _
                fi 
                ;;
            7) _global_block_rules ;;
            8) do_fallback_probe ;;
            9) do_status_menu ;;
            10) do_sys_init_menu ;;
            88) do_uninstall ;;
            0) exit 0 ;;
        esac
    done
}

# ==============================================================================
# 系统入口加载与循环启动
# ==============================================================================
preflight
main_menu
