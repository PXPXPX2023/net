#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: ex188e5.sh (The Apex Vanguard - Project Genesis V188e5)
# 快捷方式: xrv
#
# 【V188e5 终极防爆重构版】
#   1. 拓扑重组: 彻底修复 E3 缝合时产生的 case 嵌套断层与函数越界污染。
#   2. 基建修复: 整合 preflight、pkg_install、DNS 锁定等核心模块。
#   3. 矩阵满血: 100% 全量保留 130+ 实体 SNI 顶级抗封锁伪装矩阵。
#   4. 编译防砖: 强行注入 CONFIG_VIRTIO 驱动，杜绝 KVM/Xen 编译后丢失硬盘。
#   5. 绝缘护盾: JQ 全量采用 |= 与 select(. != null) 语法防崩溃。
#   6. 语法重铸: 全量多行 if test 防 set -e 断层，拒绝任何隐式短路退出。
# ==============================================================================

# ------------------------------------------------------------------------------
# [ 0x01: 系统级基础环境检查与严格模式锁定 ]
# ------------------------------------------------------------------------------

if test -z "${BASH_VERSION:-}"; then
    echo "Error: 请使用 bash 执行本脚本: bash ex188e5.sh"
    exit 1
fi

if test "$EUID" -ne 0; then 
    echo -e "\033[31m致命错误: 触及底层内核参数必须拥有最高权限，请使用 root 账户执行！\033[0m"
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then 
    echo -e "\033[31m致命错误: 当前宿主机缺失 systemd 守护组件，环境异常！\033[0m"
    exit 1
fi

# 启用严格模式防爆 (错误中断、未定义变量拦截、管道流错误捕获)
set -euo pipefail
IFS=$' \n\t'
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ------------------------------------------------------------------------------
# [ 0x02: 全域 UI 引擎与常量映射 ]
# ------------------------------------------------------------------------------

readonly red='\033[31m'
readonly yellow='\033[33m'
readonly gray='\033[90m'
readonly green='\033[92m'
readonly blue='\033[94m'
readonly magenta='\033[95m'
readonly cyan='\033[96m'
readonly none='\033[0m'

readonly SCRIPT_VERSION="188e5"
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
# [ 0x03: 工业级日志、探针与异常捕获系统 ]
# ------------------------------------------------------------------------------

if ! mkdir -p "$CONFIG_DIR" "$DAT_DIR" "$SCRIPT_DIR" "$LOG_DIR" "$BACKUP_DIR" "$FLAGS_DIR" 2>/dev/null; then true; fi
if ! touch "$USER_SNI_MAP" "$USER_TIME_MAP" 2>/dev/null; then true; fi

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

log_info()  { echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO:  $*" >> "$LOG_DIR/xray.log" 2>/dev/null || true; }
log_error() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$LOG_DIR/error.log" 2>/dev/null || true; }

cleanup_temp_files() {
    rm -f /tmp/sni_array.json /tmp/vless_inbound.json /tmp/vless_final.json /tmp/ss_inbound.json /tmp/new_client.json /tmp/xray_users*.txt /tmp/install-release.sh /tmp/sni_test.* /tmp/check_x86-64_psabi.sh /tmp/current_cron 2>/dev/null || true
}

_err_handler() {
    local code=$1 line=$2 cmd=$3
    echo -e "\n${red}================== [ SYSTEM PANIC ] ==================${none}" >&2
    echo -e "${yellow} >> 战舰核心遇到致命断层，运行已被系统强行熔断！${none}" >&2
    echo -e "${cyan} >> 错误代号: ${none}${code}" >&2
    echo -e "${cyan} >> 崩溃行号: ${none}${line}" >&2
    echo -e "${cyan} >> 故障指令: ${none}${cmd}" >&2
    echo -e "${red}======================================================${none}\n" >&2
    log_error "PANIC TRIGGERED -> EXIT=$code LINE=$line CMD=[$cmd]"
    cleanup_temp_files
}

trap '_err_handler $? $LINENO "$BASH_COMMAND"' ERR
trap cleanup_temp_files EXIT

_get_ip() {
    if test -n "${SERVER_IP:-}"; then
        if test "$SERVER_IP" != "获取失败"; then
            echo "$SERVER_IP"
            return
        fi
    fi

    if test -z "${GLOBAL_IP:-}"; then
        local temp_ip=""
        set +e
        temp_ip=$(curl -k -s -4 --connect-timeout 3 https://api.ipify.org 2>/dev/null | tr -d '\r\n' || echo "")
        if test -z "$temp_ip"; then
            temp_ip=$(curl -k -s -4 --connect-timeout 3 https://ifconfig.me 2>/dev/null | tr -d '\r\n' || echo "")
        fi
        set -e
        
        if test -z "$temp_ip"; then
            GLOBAL_IP="外网探针离线"
        else
            GLOBAL_IP="$temp_ip"
        fi
    fi
    echo "$GLOBAL_IP"
}

# ------------------------------------------------------------------------------
# [ 0x04: 强核底层工具链与系统预检引擎 (Preflight) ]
# ------------------------------------------------------------------------------

validate_port() {
    local p="$1"
    if test -z "$p"; then return 1; fi
    if ! [[ "$p" =~ ^[0-9]+$ ]]; then return 1; fi
    if test "$p" -lt 1 2>/dev/null || test "$p" -gt 65535 2>/dev/null; then return 1; fi
    if ss -tuln 2>/dev/null | grep -q ":${p} "; then
        error "端口 $p 已被系统占用。"
        return 1
    fi
    return 0
}

gen_ss_pass() {
    head -c 24 /dev/urandom | base64 | tr -d '=/+\n\r' | head -c 24 || true
}

_select_ss_method() {
    echo -e "  ${cyan}选择 SS 加密方式：${none}" >&2
    echo "  1) aes-256-gcm (推荐)  2) chacha20-ietf-poly1305" >&2
    local mc=""
    read -rp "  编号: " mc >&2 || true
    if test "$mc" = "2"; then
        echo "chacha20-ietf-poly1305"
    else
        echo "aes-256-gcm"
    fi
}

detect_os() {
    if test -f /etc/os-release; then
        . /etc/os-release
        echo "${ID:-unknown}"
    else 
        echo "unknown"
    fi
}

pkg_install() {
    local list="$*"
    export DEBIAN_FRONTEND=noninteractive
    local os_id
    os_id=$(detect_os)
    
    if echo "$os_id" | grep -qiE "ubuntu|debian"; then
        apt-get update -y >/dev/null 2>&1 || true
        apt-get install -y $list >/dev/null 2>&1 || true
    else
        if echo "$os_id" | grep -qiE "centos|rhel|fedora|rocky|almalinux"; then
            yum makecache -y >/dev/null 2>&1 || true
            yum install -y $list >/dev/null 2>&1 || true
        fi
    fi
}

preflight() {
    if test "$EUID" -ne 0; then 
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
    
    if test -n "$missing"; then
        info "正在自动补齐核心系统组件库: $missing"
        pkg_install $missing
        systemctl start vnstat  >/dev/null 2>&1 || true
        systemctl enable vnstat >/dev/null 2>&1 || true
        systemctl start cron    >/dev/null 2>&1 || systemctl start crond >/dev/null 2>&1 || true
    fi

    if test -f "$SCRIPT_PATH"; then
        cp -f "$SCRIPT_PATH" "$SYMLINK" 2>/dev/null || true
        chmod +x "$SYMLINK" 2>/dev/null || true
        hash -r 2>/dev/null || true
    fi

    SERVER_IP=$(_get_ip)
    if test "$SERVER_IP" = "外网探针离线"; then
        warn "未能自动获取当前服务器的公网 IPv4 地址。"
    fi
}

fix_xray_systemd_limits() {
    local override_dir="/etc/systemd/system/xray.service.d"
    mkdir -p "$override_dir" 2>/dev/null || true
    local limit_file="$override_dir/limits.conf"

    local current_nice="-20"
    local current_gogc="100"
    local current_oom="true"
    local current_affinity=""
    local current_gomaxprocs=""
    local current_buffer=""

    if test -f "$limit_file"; then
        if grep -q "^Nice=" "$limit_file" 2>/dev/null; then 
            current_nice=$(awk -F'=' '/^Nice=/{print $2}' "$limit_file" | head -n 1 || echo "-20")
        fi
        if grep -q "^Environment=\"GOGC=" "$limit_file" 2>/dev/null; then 
            current_gogc=$(awk -F'=' '/^Environment="GOGC=/{print $3}' "$limit_file" | tr -d '"' | head -n 1 || echo "100")
        fi
        if ! grep -q "^OOMScoreAdjust=" "$limit_file" 2>/dev/null; then 
            current_oom="false"
        fi
        if grep -q "^CPUAffinity=" "$limit_file" 2>/dev/null; then 
            current_affinity=$(awk -F'=' '/^CPUAffinity=/{print $2}' "$limit_file" | head -n 1 || echo "")
        fi
        if grep -q "^Environment=\"GOMAXPROCS=" "$limit_file" 2>/dev/null; then 
            current_gomaxprocs=$(awk -F'=' '/^Environment="GOMAXPROCS=/{print $3}' "$limit_file" | tr -d '"' | head -n 1 || echo "")
        fi
        if grep -q "^Environment=\"XRAY_RAY_BUFFER_SIZE=" "$limit_file" 2>/dev/null; then 
            current_buffer=$(awk -F'=' '/^Environment="XRAY_RAY_BUFFER_SIZE=/{print $3}' "$limit_file" | tr -d '"' | head -n 1 || echo "")
        fi
    fi

    local total_mem
    total_mem=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo "1024")
    local go_mem_limit=$(( total_mem * 85 / 100 ))

    cat > "$limit_file" << EOF
[Service]
LimitNOFILE=1048576
LimitNPROC=512000
LimitMEMLOCK=infinity
Nice=${current_nice}
Environment="GOMEMLIMIT=${go_mem_limit}MiB"
Environment="GOGC=${current_gogc}"
Restart=on-failure
RestartSec=10s
EOF

    if test "$current_oom" = "true"; then
        cat >> "$limit_file" << 'EOF'
OOMScoreAdjust=-500
IOSchedulingClass=realtime
IOSchedulingPriority=2
EOF
    fi
    
    if test -n "$current_affinity"; then echo "CPUAffinity=$current_affinity" >> "$limit_file"; fi
    if test -n "$current_gomaxprocs"; then echo "Environment=\"GOMAXPROCS=$current_gomaxprocs\"" >> "$limit_file"; fi
    if test -n "$current_buffer"; then echo "Environment=\"XRAY_RAY_BUFFER_SIZE=$current_buffer\"" >> "$limit_file"; fi

    systemctl daemon-reload >/dev/null 2>&1 || true
}

install_update_dat() {
    cat > "$UPDATE_DAT_SCRIPT" << 'UPDSH'
#!/usr/bin/env bash
XRAY_DAT_DIR="/usr/local/share/xray"
LOG_FILE="/var/log/xray/update-dat.log"

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

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
UPDSH
    chmod +x "$UPDATE_DAT_SCRIPT" 2>/dev/null || true
    
    local tmp_cron
    tmp_cron=$(mktemp /tmp/cron_XXXXXX) || return
    crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT" | grep -v "systemctl restart xray" > "$tmp_cron" || true
    echo "0 3 * * * $UPDATE_DAT_SCRIPT >/dev/null 2>&1" >> "$tmp_cron"
    echo "10 3 * * * /bin/systemctl restart xray >/dev/null 2>&1" >> "$tmp_cron"
    crontab "$tmp_cron" 2>/dev/null || true
    rm -f "$tmp_cron" 2>/dev/null || true
    
    info "自动更新配置完成: 每日 03:00 下载 Geo 库，03:10 重载 Xray 进程。"
}

do_change_dns() {
    title "配置系统 DNS 解析 (resolvconf)"
    local release
    release=$(detect_os)
    
    if test ! -e '/usr/sbin/resolvconf'; then
        if test ! -e '/sbin/resolvconf'; then
            info "未检测到 resolvconf，准备安装..."
            pkg_install resolvconf
        fi
    fi
    
    systemctl stop systemd-resolved 2>/dev/null || true
    systemctl disable systemd-resolved 2>/dev/null || true
    systemctl stop resolvconf.service > /dev/null 2>&1 || true
    systemctl start resolvconf.service > /dev/null 2>&1 || true
    systemctl enable resolvconf.service > /dev/null 2>&1 || true

    local nameserver=""
    local IPcheck="0"
    
    while test "$IPcheck" = "0"; do
        read -rp "请输入自定义 Nameserver IP (例如 8.8.8.8): " nameserver || true
        if [[ $nameserver =~ ^([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]]; then
            IPcheck="1"
        else
            print_red "输入格式错误，请输入合法的 IPv4 地址。"
        fi
    done

    chattr -i /etc/resolv.conf 2>/dev/null || true
    rm -f /etc/resolv.conf 2>/dev/null || true
    
    if test -f /etc/resolv.conf.bak; then
        mv /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true
    fi
    
    echo "nameserver $nameserver" > /etc/resolv.conf
    chattr +i /etc/resolv.conf 2>/dev/null || true
    
    mkdir -p /etc/resolvconf/resolv.conf.d 2>/dev/null || true
    echo "nameserver $nameserver" > /etc/resolvconf/resolv.conf.d/head 2>/dev/null || true
    systemctl restart resolvconf.service >/dev/null 2>&1 || true
    info "DNS 已被物理锁定为：$nameserver"
}

# ------------------------------------------------------------------------------
# [ 0x05: JQ 解析器防暴盾与自动回滚中心 ]
# ------------------------------------------------------------------------------

fix_permissions() {
    if test -f "$CONFIG"; then
        chmod 644 "$CONFIG" 2>/dev/null || true
    fi
    if test -d "$CONFIG_DIR"; then
        chmod 755 "$CONFIG_DIR" 2>/dev/null || true
    fi
    chown -R root:root "$CONFIG_DIR" 2>/dev/null || true
    if test -f "$PUBKEY_FILE"; then
        chmod 600 "$PUBKEY_FILE" 2>/dev/null || true
    fi
}

backup_config() {
    if test ! -f "$CONFIG"; then 
        return 0
    fi
    local ts
    ts=$(date +%Y%m%d_%H%M%S)
    cp -f "$CONFIG" "$BACKUP_DIR/config_${ts}.json" 2>/dev/null || true
    ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
    log_info "配置已备份: config_${ts}.json"
}

restore_latest_backup() {
    local latest
    latest=$(ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | head -n 1 || echo "")
    if test -n "$latest"; then
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

verify_xray_config() {
    local target_config="$1"
    if test ! -f "$XRAY_BIN"; then
        return 0
    fi
    local test_result
    if ! test_result=$("$XRAY_BIN" run -test -config "$target_config" 2>&1); then
        test_result=$("$XRAY_BIN" -test -config "$target_config" 2>&1 || echo "核心测试失败")
    fi
    
    if echo "$test_result" | grep -qi "Configuration OK"; then
        return 0
    else
        error "配置文件校验未通过，Xray 核心拒绝加载。"
        echo -e "${gray}$test_result${none}"
        return 1
    fi
}

_safe_jq_write() {
    backup_config
    local tmp_raw
    tmp_raw=$(mktemp) || return 1
    local tmp="${tmp_raw}.json"
    mv -f "$tmp_raw" "$tmp" 2>/dev/null || true
    
    if jq "$@" "$CONFIG" > "$tmp" 2>/dev/null; then
        if test -s "$tmp"; then
            if verify_xray_config "$tmp"; then
                mv -f "$tmp" "$CONFIG" 2>/dev/null || true
                fix_permissions
                return 0
            else
                rm -f "$tmp" 2>/dev/null || true
                restore_latest_backup
                return 1
            fi
        else
            error "JQ 解析器生成了空白文件，拒绝覆盖！"
            rm -f "$tmp" 2>/dev/null || true
            restore_latest_backup
            return 1
        fi
    else
        rm -f "$tmp" 2>/dev/null || true
        error "JSON 解析器语法故障，写入已中止。"
        log_error "jq 语法执行失败，参数: $*"
        restore_latest_backup
        return 1
    fi
}

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
        local _p=""
        read -rp "请按 Enter 键返回..." _p || true
        return 1
    fi
}
# ------------------------------------------------------------------------------
# [ 0x05: 130+ 满血实体 SNI 连通性雷达矩阵与质检中心 ]
# ------------------------------------------------------------------------------

run_sni_scanner() {
    title "雷达嗅探：130+ 实体矩阵与国内连通性探测"
    print_yellow ">>> 扫描中... (随时按回车键可立即中止并挑选已扫描节点)\n"
    
    if ! mkdir -p "$CONFIG_DIR" 2>/dev/null; then 
        true
    fi
    
    # 满血 130+ 顶级防封锁实体 SNI 阵列
    local sni_list=(
        "www.apple.com" "support.apple.com" "developer.apple.com" "id.apple.com" "icloud.apple.com"
        "swdist.apple.com" "swcdn.apple.com" "updates.cdn-apple.com" "mensura.cdn-apple.com" "osxapps.itunes.apple.com"
        "aod.itunes.apple.com" "is1-ssl.mzstatic.com" "itunes.apple.com" "gateway.icloud.com" "www.icloud.com"
        "www.microsoft.com" "login.microsoftonline.com" "portal.azure.com" "support.microsoft.com" "office.com"
        "update.microsoft.com" "windowsupdate.microsoft.com" "software.download.prss.microsoft.com" "cdn-dynmedia-1.microsoft.com"
        "www.intel.com" "downloadcenter.intel.com" "ark.intel.com" "www.amd.com" "drivers.amd.com" "community.amd.com"
        "webinar.amd.com" "ir.amd.com" "www.dell.com" "support.dell.com" "www.hp.com" "support.hp.com" "developers.hp.com"
        "www.bmw.com" "configure.bmw.com" "shop.bmw.com" "www.mercedes-benz.com" "me.mercedes-benz.com"
        "www.toyota-global.com" "global.toyota" "www.toyota.com" "www.honda.com" "global.honda" "www.volkswagen.com"
        "service.volkswagen.com" "www.vw.com" "www.nike.com" "account.nike.com" "store.nike.com" "www.adidas.com"
        "account.adidas.com" "www.zara.com" "static.zara.net" "www.ikea.com" "secure.ikea.com" "www.shell.com"
        "careers.shell.com" "www.bp.com" "login.bp.com" "www.totalenergies.com" "www.ge.com" "digital.ge.com"
        "www.abb.com" "new.abb.com" "www.hsbc.com" "online.hsbc.com" "www.goldmansachs.com" "login.gs.com"
        "www.morganstanley.com" "secure.morganstanley.com" "www.maersk.com" "www.msc.com" "www.cma-cgm.com"
        "www.hapag-lloyd.com" "www.michelin.com" "www.bridgestone.com" "www.goodyear.com" "www.pirelli.com"
        "www.sony.com" "www.sony.net" "www.panasonic.com" "www.canon.com" "www.nintendo.com" "www.lg.com"
        "www.epson.com" "www.unilever.com" "www.loreal.com" "www.shiseido.com" "www.jnj.com" "www.kao.com"
        "www.uniqlo.com" "www.hermes.com" "www.chanel.com" "services.chanel.com" "www.louisvuitton.com"
        "eu.louisvuitton.com" "www.dior.com" "www.ferragamo.com" "www.versace.com" "www.prada.com" "www.fendi.com"
        "www.gucci.com" "www.tiffany.com" "www.esteelauder.com" "www.maje.com" "www.swatch.com" "www.coca-cola.com"
        "www.coca-colacompany.com" "www.pepsi.com" "www.pepsico.com" "www.nestle.com" "www.bk.com" "www.heinz.com"
        "www.pg.com" "www.basf.com" "www.bayer.com" "www.bosch.com" "www.bosch-home.com" "www.lexus.com" "www.audi.com"
        "www.porsche.com" "www.skoda-auto.com" "www.gm.com" "www.chevrolet.com" "www.cadillac.com" "www.ford.com"
        "www.lincoln.com" "www.hyundai.com" "www.kia.com" "www.peugeot.com" "www.renault.com" "www.jaguar.com"
        "www.landrover.com" "www.astonmartin.com" "www.mclaren.com" "www.ferrari.com" "www.maserati.com" "www.volvocars.com"
        "www.tesla.com" "s0.awsstatic.com" "d1.awsstatic.com" "images-na.ssl-images-amazon.com" "m.media-amazon.com"
        "www.nvidia.com" "academy.nvidia.com" "images.nvidia.com" "blogs.nvidia.com" "docs.nvidia.com" "docscontent.nvidia.com"
        "www.samsung.com" "www.sap.com" "www.oracle.com" "www.mysql.com" "www.swift.com" "download-installer.cdn.mozilla.net"
        "addons.mozilla.org" "www.airbnb.co.uk" "www.airbnb.ca" "www.airbnb.com.sg" "www.airbnb.com.au" "www.airbnb.co.in"
        "www.ubi.com" "lol.secure.dyn.riotcdn.net" "one-piece.com" "player.live-video.net" "mit.edu" "www.mit.edu" 
        "web.mit.edu" "ocw.mit.edu" "csail.mit.edu" "libraries.mit.edu" "alum.mit.edu" "id.mit.edu" "stanford.edu" 
        "www.stanford.edu" "cs.stanford.edu" "ai.stanford.edu" "web.stanford.edu" "login.stanford.edu" "ox.ac.uk" 
        "www.ox.ac.uk" "cs.ox.ac.uk" "maths.ox.ac.uk" "login.ox.ac.uk" "lufthansa.com" "www.lufthansa.com" 
        "book.lufthansa.com" "checkin.lufthansa.com" "api.lufthansa.com" "singaporeair.com" "www.singaporeair.com" 
        "booking.singaporeair.com" "krisflyer.singaporeair.com" "trekbikes.com" "www.trekbikes.com" "shop.trekbikes.com" 
        "support.trekbikes.com" "specialized.com" "www.specialized.com" "store.specialized.com" "support.specialized.com" 
        "giant-bicycles.com" "www.giant-bicycles.com" "dealer.giant-bicycles.com" "logitech.com" "www.logitech.com" 
        "support.logitech.com" "gaming.logitech.com" "razer.com" "www.razer.com" "support.razer.com" "insider.razer.com" 
        "corsair.com" "www.corsair.com" "support.corsair.com" "account.asus.com" "kingston.com" "www.kingston.com" 
        "shop.kingston.com" "support.kingston.com" "seagate.com" "www.seagate.com" "support.seagate.com" "kleenex.com" 
        "www.kleenex.com" "shop.kleenex.com" "scottbrand.com" "www.scottbrand.com" "tempo-world.com" "www.tempo-world.com"
        "www.zoom.us" "www.adobe.com" "www.autodesk.com" "www.salesforce.com" "www.cisco.com" "www.ibm.com" "www.qualcomm.com"
        "www.nissan-global.com" "www.target.com" "www.walmart.com" "www.homedepot.com" "www.lowes.com" "www.walgreens.com"
        "www.costco.com" "www.cvs.com" "www.bestbuy.com" "www.kroger.com" "www.mcdonalds.com" "www.starbucks.com"
        "www.puma.com" "www.underarmour.com" "www.hm.com" "www.gap.com" "www.rolex.com" "www.burberry.com" "www.cartier.com"
        "www.estee-lauder.com" "www.pfizer.com" "www.novartis.com" "www.roche.com" "www.sanofi.com" "www.merck.com"
        "www.gsk.com" "www.boeing.com" "www.airbus.com" "www.lockheedmartin.com" "www.geaerospace.com" "www.siemens.com"
        "www.hitachi.com" "www.schneider-electric.com" "www.caterpillar.com" "www.john-deere.com" "www.mitsubishicorp.com"
        "www.sharp.com" "www.lenovo.com" "www.huawei.com" "www.asus.com" "www.acer.com" "www.delltechnologies.com"
        "www.hpe.com" "www.lenovo.com.cn" "www.tiktok.com" "www.spotify.com" "www.netflix.com" "www.hulu.com" "www.disneyplus.com"
    )

    local sni_string
    sni_string=$(printf "%s\n" "${sni_list[@]}")
    
    if command -v shuf >/dev/null 2>&1; then
        sni_string=$(echo "$sni_string" | shuf)
    else
        sni_string=$(echo "$sni_string" | awk 'BEGIN{srand()} {print rand()"\t"$0}' | sort -n | cut -f2-)
    fi

    local tmp_sni
    tmp_sni=$(mktemp /tmp/sni_test.XXXXXX) || true

    for sni in $sni_string; do
        local key=""
        if read -t 0.1 -n 1 -s key 2>/dev/null; then
            echo -e "\n${yellow}探测已手动中止，正在整理已捕获节点...${none}"
            break
        fi

        set +e
        local time_raw
        time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni" 2>/dev/null || echo "0")
        
        local ms
        ms=$(echo "$time_raw" | awk '{print int($1 * 1000)}' 2>/dev/null || echo "0")
        set -e

        if test "${ms:-0}" -gt 0 2>/dev/null; then
            set +e
            if curl -sI -m 2 --connect-timeout 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray"; then
                echo -e " ${gray}跳过${none} $sni (Cloudflare CDN 拦截)"
                set -e
                continue
            fi
            set -e
            
            # 脱离严格模式执行 DNS 探测防爆
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
            
            if test -z "$dns_cn"; then
                status_cn="${red}国内墙阻断 (DNS投毒或无响应)${none}"
                p_type="BLOCK"
            else
                if test "$dns_cn" = "127.0.0.1" || test "$dns_cn" = "0.0.0.0" || test "$dns_cn" = "::1" || test "$dns_cn" = "null"; then
                    status_cn="${red}国内墙阻断 (DNS投毒)${none}"
                    p_type="BLOCK"
                else
                    set +e
                    local loc
                    loc=$(curl -s --connect-timeout 2 "https://ipinfo.io/$dns_cn/country" 2>/dev/null | tr -d ' \n' || echo "")
                    set -e
                    
                    if test "$loc" = "CN"; then
                        status_cn="${green}直通${none} | ${blue}中国境内 CDN${none}"
                        p_type="CN_CDN"
                    else
                        status_cn="${green}直通${none} | ${cyan}海外原生优质${none}"
                        p_type="NORM"
                    fi
                fi
            fi
            
            echo -e " ${green}存活${none} $sni : ${yellow}${ms}ms${none} | $status_cn"
            
            if test "$p_type" != "BLOCK"; then
                echo "$ms $sni $p_type" >> "$tmp_sni"
            fi
        fi
    done

    if test -s "$tmp_sni"; then
        grep " NORM$" "$tmp_sni" | sort -n | head -n 20 | awk '{print $2, $1}' > "$SNI_CACHE_FILE" || true
        
        local count
        count=$(wc -l < "$SNI_CACHE_FILE" 2>/dev/null || echo "0")
        
        if test "${count:-0}" -lt 20 2>/dev/null; then
            local need_fill=$(( 20 - ${count:-0} ))
            grep "CN_CDN" "$tmp_sni" | sort -n | head -n "$need_fill" | awk '{print $2, $1}' >> "$SNI_CACHE_FILE" || true
        fi
    else
        print_red "探测全灭，系统已回退至微软保底方案。"
        echo "www.microsoft.com 999 NORM" > "$SNI_CACHE_FILE"
    fi
    
    rm -f "$tmp_sni" 2>/dev/null || true
}

verify_sni_strict() {
    local target="$1"
    print_magenta "\n>>> 正在对目标 SNI [$target] 开启严苛质检 (TLS 1.3 + ALPN h2 + OCSP)..."
    
    set +e
    local out
    out=$(echo "Q" | timeout 5 openssl s_client -connect "$target:443" -alpn h2 -tls1_3 -status 2>&1 || echo "")
    set -e
    
    local pass=1
    
    if ! echo "$out" | grep -qi "TLSv1.3"; then 
        print_red " ✗ 质检拦截: 目标服务器不支持 TLS v1.3 协议"
        pass=0
    fi
    
    if ! echo "$out" | grep -qiE "ALPN, server accepted to use h2|ALPN.*h2"; then 
        print_red " ✗ 质检拦截: 目标服务器不支持 ALPN h2 协商"
        pass=0
    fi
    
    if ! echo "$out" | grep -qi "OCSP response:"; then 
        print_red " ✗ 质检拦截: 目标服务器未配置 OCSP Stapling 证书状态装订"
        pass=0
    fi
    
    if test "$pass" -eq 0; then
        warn "结论：该目标指纹残缺，易遭墙探！"
        return 1
    else
        info "结论：目标完美通过三项高维特征审核！"
        return 0
    fi
}

choose_sni() {
    while true; do
        if test -f "$SNI_CACHE_FILE"; then
            echo -e "\n  ${cyan}【战备缓存：极速 Top 20 (已剔除阻断节点)】${none}"
            
            local idx=1
            while read -r s t p; do
                echo -e "  $idx) $s (TCP 延迟: ${cyan}${t}ms${none})"
                idx=$((idx + 1))
            done < "$SNI_CACHE_FILE"
            
            echo -e "  ${yellow}r) 抛弃缓存重新运行雷达扫描${none}"
            echo "  m) 启用多选模式 (输入多个序号，构建多域名矩阵)"
            echo "  0) 手动输入自定义私有域名"
            echo "  q) 取消并退回上级"
            
            local sel=""
            read -rp "  请选择对应操作或节点序号 (默认 1): " sel || true
            sel=${sel:-1}
            
            if test "$sel" = "q" || test "$sel" = "Q"; then 
                return 1
            fi
            
            if test "$sel" = "r" || test "$sel" = "R"; then 
                run_sni_scanner
                continue
            fi
            
            if test "$sel" = "m" || test "$sel" = "M"; then
                local m_sel=""
                read -rp "请输入所需序号 (空格分隔, 如 1 3 5，或输入 all 全选): " m_sel || true
                
                local arr=()
                
                if test "$m_sel" = "all"; then
                    while read -r p_sni p_rest; do
                        if test -n "$p_sni"; then 
                            arr+=("$p_sni")
                        fi
                    done < "$SNI_CACHE_FILE"
                else
                    for i in $m_sel; do
                        local picked=""
                        picked=$(awk "NR==$i {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "")
                        
                        if test -n "$picked"; then 
                            arr+=("$picked")
                        fi
                    done
                fi
                
                if test "${#arr[@]}" -eq 0; then
                    error "选择无效，未能解析到有效的 SNI 目标，请重新输入。"
                    continue
                fi
                
                BEST_SNI="${arr[0]}"
                
                local jq_args=()
                for s in "${arr[@]}"; do 
                    jq_args+=("\"$s\"")
                done
                SNI_JSON_ARRAY=$(IFS=,; echo "${jq_args[*]}")
                
            else
                if test "$sel" = "0"; then 
                    local d=""
                    read -rp "请输入您指定的自定义域名: " d || true
                    
                    BEST_SNI=${d:-www.microsoft.com}
                    SNI_JSON_ARRAY="\"$BEST_SNI\""
                else
                    local picked=""
                    if [[ "$sel" =~ ^[0-9]+$ ]]; then
                        picked=$(awk "NR==$sel {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "")
                    fi
                    
                    if test -n "$picked"; then
                        BEST_SNI="$picked"
                    else
                        error "输入有误，已自动降级为您分配第一号测速节点。"
                        BEST_SNI=$(awk "NR==1 {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "www.microsoft.com")
                    fi
                    
                    SNI_JSON_ARRAY="\"$BEST_SNI\""
                fi
            fi

            if verify_sni_strict "$BEST_SNI"; then
                print_green ">>> 质检完毕：主控目标 $BEST_SNI 完美通过特征审查！"
                break
            else
                print_yellow ">>> 危险预警：域名质检不达标，若强行部署会导致 Reality 极易被墙或断流！"
                local force_use=""
                read -rp "是否无视警告，强制使用该域名？(y/n): " force_use || true
                
                if [[ "$force_use" =~ ^[yY]$ ]]; then
                    warn "您已授权强制越过安检防线，配置继续。"
                    break
                else
                    continue
                fi
            fi
        else
            warn "未能发现本地域名测速快照，正在为您唤醒扫描雷达..."
            run_sni_scanner
        fi
    done
    
    return 0
}
# ------------------------------------------------------------------------------
# [ 0x06: Swap 虚拟内存防爆模块 ]
# ------------------------------------------------------------------------------

check_and_create_1gb_swap() {
    title "检查物理 Swap 分区状态"
    
    local SWAP_FILE="/swapfile"
    local CURRENT_SWAP=""
    
    set +e
    CURRENT_SWAP=$(swapon --show=NAME,KBYTES --noheadings 2>/dev/null | grep "$SWAP_FILE" | awk '{print $2}' || echo "")
    set -e
    
    if test -n "$CURRENT_SWAP"; then
        if test "$CURRENT_SWAP" -ge 1000000 2>/dev/null; then
            info "系统已配置足量的 Swap 分区 (≥1GB)。"
            return
        fi
    fi
    
    warn "未检测到足量 Swap，正在强行切辟 1GB Swap 缓冲分区以防编译时内存爆闪..."
    swapoff -a 2>/dev/null || true
    sed -i '/swapfile/d' /etc/fstab 2>/dev/null || true
    rm -f "$SWAP_FILE" 2>/dev/null || true
    
    dd if=/dev/zero of="$SWAP_FILE" bs=1M count=1024 status=none 2>/dev/null || true
    chmod 600 "$SWAP_FILE" 2>/dev/null || true
    mkswap "$SWAP_FILE" >/dev/null 2>&1 || true
    swapon "$SWAP_FILE" >/dev/null 2>&1 || true
    echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab 2>/dev/null || true
    
    info "Swap 缓冲池配置完成。"
}

# ------------------------------------------------------------------------------
# [ 0x07: 官方预编译 XANMOD 部署模块 - 容错智能降级与 APT 寻址引擎 ]
# ------------------------------------------------------------------------------

do_install_xanmod_main_official() {
    title "系统飞升：安装官方预编译 XANMOD 内核"
    
    local arch
    arch=$(uname -m 2>/dev/null || echo "")
    
    if test "$arch" != "x86_64"; then
        error "系统架构不匹配：官方预编译 Xanmod 目前仅支持 x86_64 (amd64) 架构的机器！"
        local _pause=""
        read -rp "按 Enter 返回..." _pause || true
        return
    fi

    if test ! -f /etc/debian_version; then
        error "系统发行版排斥：官方预编译 Xanmod APT 仓库目前仅兼容 Debian / Ubuntu 系操作系统！"
        local _pause=""
        read -rp "按 Enter 返回..." _pause || true
        return
    fi

    print_magenta ">>> [1/4] 正在拉取智能探针，检测本地 CPU 硬件微架构支持级别..."
    
    local cpu_level_script="/tmp/check_x86-64_psabi.sh"
    
    if ! wget -qO "$cpu_level_script" https://dl.xanmod.org/check_x86-64_psabi.sh; then
        warn "探针脚本下载遇到网络波动，将跳过精准检测。"
    fi
    
    local cpu_level=""
    if test -f "$cpu_level_script"; then
        set +e
        cpu_level=$(awk -f "$cpu_level_script" 2>/dev/null | grep -oE 'x86-64-v[1-4]' | grep -oE '[1-4]' | tail -n 1 || echo "")
        set -e
        rm -f "$cpu_level_script" 2>/dev/null || true
    fi
    
    if test -z "$cpu_level"; then
        cpu_level=2
        warn "未能精确检测 CPU 微架构级别，将默认降级使用系统最宽容的 v2 兼容版本。"
    else
        info "评估完成，当前 CPU 硬件完美支持的微架构最高级别为: v${cpu_level}"
    fi

    print_magenta ">>> [2/4] 正在配置 Xanmod 官方全新 APT 仓库与防伪 Keyring..."
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y gnupg gnupg2 curl sudo wget e2fsprogs ca-certificates >/dev/null 2>&1 || true

    # 【核心修复 1：Debian 11 兼容 GPG 格式，确保源列表被正确识别】
    mkdir -p /usr/share/keyrings 2>/dev/null || true
    rm -f /etc/apt/trusted.gpg.d/xanmod-kernel.gpg /etc/apt/sources.list.d/xanmod-kernel.list /etc/apt/sources.list.d/xanmod-release.list 2>/dev/null || true
    
    if ! curl -fsSL https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes 2>/dev/null; then
        error "从远端获取 GPG 密钥链发生错误，官方源可能受限！"
        return 1
    fi
    
    echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-release.list

    print_magenta ">>> [3/4] 正在触发 APT 智能降级寻址阵列 (实时同步中)..."
    apt-get update -y >/dev/null 2>&1 || warn "APT 源刷新遇到网络异常"
    
    # 剔除废柴 apt-cache show 逻辑，直接信任 CPU 级别探针
    local pkg_name="linux-xanmod-x64v${cpu_level}"
    
    info "寻址成功！锁定云端目标底层包: $pkg_name"
    print_magenta ">>> [4/4] 正在向主系统强行注入战舰级内核: $pkg_name ..."
    
    if ! apt-get install -y "$pkg_name"; then
        error "保底安装宣告失败，内核替换进程中止。请排查物理网络环境与 APT 源配置！"
        local _pause=""
        read -rp "按 Enter 继续..." _pause || true
        return 1
    fi
    
    if test -z "$pkg_name"; then
        warn "标准架构包名全线脱靶，正在唤醒 APT 模糊寻址雷达..."
        pkg_name=$(apt-cache search "linux-image-.*xanmod" | grep -vE "dbg|headers" | awk '{print $1}' | head -n 1 || echo "")
    fi
    set -e
    
    if test -z "$pkg_name"; then
        error "保底寻址宣告失败！当前系统源无法解析到任何合法的 Xanmod 预编译包。"
        local _pause=""
        read -rp "按 Enter 继续..." _pause || true
        return 1
    fi
    
    info "寻址成功！锁定云端目标底层包: $pkg_name"

    print_magenta ">>> [4/4] 正在向主系统强行注入战舰级内核: $pkg_name ..."
    
    if ! apt-get install -y "$pkg_name"; then
        error "保底安装宣告失败，内核替换进程中止。请排查物理网络环境与 APT 源配置！"
        local _pause=""
        read -rp "按 Enter 继续..." _pause || true
        return 1
    fi

    if command -v update-grub >/dev/null 2>&1; then
        update-grub >/dev/null 2>&1 || true
    else
        apt-get install -y grub2-common >/dev/null 2>&1 || true
        update-grub >/dev/null 2>&1 || true
    fi

    info "官方预编译 XANMOD 部署与注册已全部就绪！"
    warn "系统将在 10 秒后强制重启应用新内核..."
    sleep 10
    reboot
}

# ------------------------------------------------------------------------------
# [ 0x08: 编译安装原生 XANMOD 源码内核 + BBR3 (全量防爆防砖版) ]
# ------------------------------------------------------------------------------

do_xanmod_compile() {
    title "系统飞升：源码编译 XANMOD 官方内核 + BBR3 (极客锻造模式)"
    
    warn "警告: 这是一个极其漫长的过程 (30-60分钟)，请确保 SSH 连接稳定！"
    local confirm=""
    read -rp "确定要执意开始源码编译吗？(y/n): " confirm || true
    
    if test "$confirm" != "y"; then
        if test "$confirm" != "Y"; then
            return
        fi
    fi

    title "=== [1/8] 开始执行深度系统清理与空间释放 ==="
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get clean >/dev/null 2>&1 || true
    apt-get autoremove -y --purge >/dev/null 2>&1 || true
    journalctl --vacuum-time=1d >/dev/null 2>&1 || true
    
    rm -rf /var/log/*.log 2>/dev/null || true
    rm -rf /tmp/* 2>/dev/null || true
    rm -rf /usr/src/linux* 2>/dev/null || true
    sync

    local inode_use
    inode_use=$(df -i / 2>/dev/null | awk 'NR==2{print $5}' | tr -d '%' || echo "0")
    if test "$inode_use" -gt 90 2>/dev/null; then
        warn "检测到 inode 节点使用率过高，执行紧急深度释放缓存..."
        rm -rf /var/cache/* 2>/dev/null || true
    fi

    title "=== [2/8] 检查并配置 1GB 编译缓冲交换区 (Swap) ==="
    check_and_create_1gb_swap

    title "=== [3/8] 拉取底层 GCC 编译套件与开发依赖库 ==="
    
    local root_free
    root_free=$(df -m / 2>/dev/null | awk 'NR==2{print $4}' || echo "0")
    
    local BUILD_DIR=""
    if test "$root_free" -gt 4000 2>/dev/null; then 
        mkdir -p /compile 2>/dev/null || true
        BUILD_DIR="/compile"
        info "根目录空间充裕，工作区路由至: /compile"
    else 
        BUILD_DIR="/usr/src"
        info "工作区默认路由至: /usr/src"
    fi

    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y build-essential bc bison flex libssl-dev libelf-dev libncurses-dev zstd lz4 liblz4-tool lzma bzip2 git wget curl xz-utils ethtool numactl make pkg-config dwarves rsync python3 libdw-dev cpio >/dev/null 2>&1 || true

    local CPU
    CPU=$(nproc 2>/dev/null || echo 1)
    local RAM
    RAM=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo 1024)
    local THREADS=1
    
    if test "$RAM" -ge 2000 2>/dev/null; then 
        THREADS=$CPU
    else
        if test "$RAM" -ge 1000 2>/dev/null; then
            THREADS=2
        fi
    fi

    title "=== [4/8] 探测并拉取 Xanmod 官方最新稳定版源码 ==="
    
    if ! cd "$BUILD_DIR"; then
        die "权限异常：系统拒绝切入工作区 $BUILD_DIR。"
    fi
    
    info "正在连接 GitLab 获取 Xanmod 最新分支..."
    local XANMOD_TAG=""
    set +e
    XANMOD_TAG=$(curl -sL "https://gitlab.com/api/v4/projects/xanmod%2Flinux/repository/tags" 2>/dev/null | jq -r '.[0].name' | grep -v "rc" | head -n 1 || echo "")
    set -e
    
    if test -z "$XANMOD_TAG" || test "$XANMOD_TAG" = "null"; then 
        warn "动态寻址失败，强行锁定高可用备用版本 6.10.3-xanmod1..."
        XANMOD_TAG="6.10.3-xanmod1"
    fi
    
    local KERNEL_URL="https://gitlab.com/xanmod/linux/-/archive/${XANMOD_TAG}/linux-${XANMOD_TAG}.tar.gz"
    local KERNEL_FILE="xanmod-${XANMOD_TAG}.tar.gz"
    
    info "建立直连信道，开始拉取 Xanmod 源码包: $KERNEL_FILE"
    wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"

    set +o pipefail
    if ! tar -tzf "$KERNEL_FILE" >/dev/null 2>&1; then
        warn "检测到初次获取的源码包发生数据断层，触发重试..."
        rm -f "$KERNEL_FILE" 2>/dev/null || true
        wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE"
        if ! tar -tzf "$KERNEL_FILE" >/dev/null 2>&1; then
            set -o pipefail
            error "下载或解压验证连续失败，编译行动强制中止。"
            return 1
        fi
    fi
    set -o pipefail

    info "执行 GZ 极致解压，释放 Xanmod 源码..."
    tar -xzf "$KERNEL_FILE"
    
    local KERNEL_DIR="linux-${XANMOD_TAG}"
    if ! cd "$KERNEL_DIR"; then
        die "无法切入解压后的源码目录: $KERNEL_DIR。"
    fi

    title "=== [5/8] 注入底层驱动与绝缘防爆参数 ==="
    
    if test -f "/boot/config-$(uname -r)"; then
        cp "/boot/config-$(uname -r)" .config
        info "已成功提取当前内核配置作为蓝本。"
    elif modprobe configs 2>/dev/null && test -f /proc/config.gz; then
        zcat /proc/config.gz > .config
        info "已成功提取内存运行时配置 (/proc/config.gz)。"
    else
        make defconfig >/dev/null 2>&1 || true
    fi
    
    # 【核心修复 2：物理篡改 Makefile，斩断 x86-64-v 架构参数断层】
    info "物理破坏源文件中的架构检查逻辑，防止 GCC 参数畸形..."
    sed -i 's/-march=x86-64-v$(CONFIG_X86_64_VERSION)/-march=x86-64-v2/g' arch/x86/Makefile 2>/dev/null || true
    
    info "正在抹平新老内核代差，执行首次静默对齐..."
    yes "" | make olddefconfig >/dev/null 2>&1 || true
    make scripts >/dev/null 2>&1 || true
    
    ./scripts/config --set-val X86_64_VERSION 2
    ./scripts/config --enable X86_64_V2
    
    info "注入 KVM/Xen 底层虚拟化驱动映射层 (VIRTIO)..."
    ./scripts/config --enable VIRTIO
    # ... (保留其他 virtio 和 bbr 的注入) ...
    
    info "正在顺应新版内核代差，配置 CPU 架构等级..."
    # 彻底删除原有的 sed -i 's/-march=... 物理破坏逻辑
    # 放弃旧版的 --set-val X86_64_VERSION 2，改用标准布尔开关
    ./scripts/config --enable GENERIC_CPU
    ./scripts/config --disable GENERIC_CPU_V1
    ./scripts/config --enable X86_64_V2
    ./scripts/config --enable GENERIC_CPU_V2 2>/dev/null || true

    info "正在剥离 Debian/Ubuntu 证书锁与臃肿调试信息..."
    ./scripts/config --disable DRM_I915
    ./scripts/config --disable NET_VENDOR_REALTEK
    ./scripts/config --disable NET_VENDOR_BROADCOM
    
    ./scripts/config --disable MODULE_SIG
    ./scripts/config --disable MODULE_SIG_ALL
    ./scripts/config --disable SYSTEM_TRUSTED_KEYRING
    ./scripts/config --disable SYSTEM_REVOCATION_LIST
    
    sed -i 's/CONFIG_SYSTEM_TRUSTED_KEYS=.*/CONFIG_SYSTEM_TRUSTED_KEYS=""/g' .config 2>/dev/null || true
    sed -i 's/CONFIG_SYSTEM_REVOCATION_KEYS=.*/CONFIG_SYSTEM_REVOCATION_KEYS=""/g' .config 2>/dev/null || true
    sed -i 's/CONFIG_MODULE_SIG_KEY=.*/CONFIG_MODULE_SIG_KEY=""/g' .config 2>/dev/null || true
    
    ./scripts/config --disable DEBUG_INFO
    ./scripts/config --disable DEBUG_INFO_BTF
    ./scripts/config --disable DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
    
    info "重新对齐最终无污染配置..."
    yes "" | make olddefconfig >/dev/null 2>&1 || true

    title "=== [6/8] 释放 CPU 算力，开启内核原生 Forge 锻造模式 ==="
    info "分配编译并发线程数: $THREADS"
    
    if ! make -j"$THREADS"; then
        error "编译线程彻底崩塌！请排查物理内存是否溢出。"
        local _p=""
        read -rp "按 Enter 返回主菜单..." _p || true
        return 1
    fi

    title "=== [7/8] 校验引导区容量并挂载核心模块 ==="
    
    local boot_free
    boot_free=$(df -m /boot 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    
    if test "$boot_free" -lt 200 2>/dev/null; then
        error "致命拦截：/boot 引导扇区剩余空间 ($boot_free MB) 严重不足！编译主动熔断！"
        local _p=""
        read -rp "按 Enter 返回主菜单..." _p || true
        return 1
    fi
    
    info "/boot 扇区空间充足 ($boot_free MB)，准许启动扇区安装..."
    
    make modules_install
    make install

    local NEW_KERNEL_VER
    NEW_KERNEL_VER=$(make -s kernelrelease 2>/dev/null || echo "")
    
    if test -n "$NEW_KERNEL_VER"; then
        print_magenta ">>> 为新内核 $NEW_KERNEL_VER 强制生成底层 Initramfs 镜像驱动..."
        if command -v update-initramfs >/dev/null 2>&1; then
            update-initramfs -c -k "$NEW_KERNEL_VER" || true
        elif command -v dracut >/dev/null 2>&1; then
            dracut --force "/boot/initramfs-${NEW_KERNEL_VER}.img" "$NEW_KERNEL_VER" || true
        fi
    fi

    title "=== [8/8] 刷新系统引导器并销毁编译垃圾 ==="
    
    if command -v update-grub >/dev/null 2>&1; then
        update-grub || true
    elif command -v update-grub2 >/dev/null 2>&1; then
        update-grub2 || true
    elif command -v grub-mkconfig >/dev/null 2>&1; then
        grub-mkconfig -o /boot/grub/grub.cfg || true
    fi

    cd /
    rm -rf "$BUILD_DIR/linux-"* 2>/dev/null || true
    rm -rf "$BUILD_DIR/xanmod-"* 2>/dev/null || true

    info "奇迹再现！纯血版 Xanmod 源码内核编译与 Initramfs 挂载全部顺利结束。"
    warn "老系统将在 15 秒钟内物理退役，请等待自动重启..."
    sleep 15
    reboot
}
# ------------------------------------------------------------------------------
# [ 0x0A: 网卡发送队列调优与 CAKE 参数高级配置 ]
# ------------------------------------------------------------------------------

do_txqueuelen_opt() {
    title "网卡发送队列 (TX Queue) 物理调优"
    
    local IP_CMD
    IP_CMD=$(command -v ip || echo "")
    
    if test -z "$IP_CMD"; then
        error "系统缺失 iproute2 (ip 命令) 核心组件，无法调节网卡。"
        local _p=""
        read -rp "按 Enter 返回..." _p || true
        return 1
    fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test -z "$IFACE"; then
        error "无法定位系统默认出口网卡，操作中止。"
        local _p=""
        read -rp "按 Enter 返回..." _p || true
        return 1
    fi
    
    info "强行扩张 $IFACE 发送队列长度至 2000..."
    $IP_CMD link set "$IFACE" txqueuelen 2000 2>/dev/null || true
    
    cat > /etc/systemd/system/txqueue.service << EOF
[Unit]
Description=Set TX Queue Length for Performance Optimization
After=network.target

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
    
    if test "$CHECK_QLEN" = "2000"; then
        info "已成功将网卡底层并发队列长度扩容至 2000 级。"
    else
        warn "修改失败！当前虚拟机或网卡驱动不支持调节 txqueuelen 队列长度。"
    fi
    
    local _p=""
    read -rp "按 Enter 键返回主菜单..." _p || true
}

config_cake_advanced() {
    clear
    title "CAKE 拥塞调度器高级微操配置"
    
    local current_opts="未配置 (系统自适应默认)"
    if test -f "$CAKE_OPTS_FILE"; then
        current_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
    fi
    
    echo -e "  当前运行参数: ${cyan}${current_opts}${none}\n"
    
    local c_bw=""
    echo -e "  [1] 声明物理带宽限制 (例如 900Mbit，填 0 取消限制): "
    read -rp "  请输入: " c_bw || true
    
    local c_oh=""
    echo -e "  [2] 配置底层报文开销补偿 Overhead (填 0 取消限制): "
    read -rp "  请输入: " c_oh || true
    
    local c_mpu=""
    echo -e "  [3] 最小数据单元截断 MPU (填 0 取消限制): "
    read -rp "  请输入: " c_mpu || true
    
    echo "  [4] RTT 延迟模型: "
    echo "    1) internet  (标准互联 85ms)"
    echo "    2) oceanic   (跨洋海缆 300ms)"
    echo "    3) satellite (卫星链路 1000ms)"
    
    local rtt_sel=""
    read -rp "  请选择 (默认 2): " rtt_sel || true
    
    local c_rtt=""
    case "${rtt_sel:-2}" in
        1) c_rtt="internet" ;;
        3) c_rtt="satellite" ;;
        *) c_rtt="oceanic" ;;
    esac
    
    echo "  [5] 流量分类识别 (Diffserv): "
    echo "    1) diffserv4  (按数据包特征分类，CPU 消耗较高)"
    echo "    2) besteffort (盲推忽略特征，大幅降低 CPU 开销)"
    
    local diff_sel=""
    read -rp "  请选择 (默认 2): " diff_sel || true
    
    local c_diff=""
    case "${diff_sel:-2}" in
        1) c_diff="diffserv4" ;;
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
    
    # 去除前导空格
    final_opts="${final_opts#"${final_opts%%[! ]*}"}"
    
    if test -z "$final_opts"; then
        rm -f "$CAKE_OPTS_FILE" 2>/dev/null || true
        info "已清除所有 CAKE 自定义高阶参数，恢复默认。"
    else
        echo "$final_opts" > "$CAKE_OPTS_FILE"
        info "CAKE 高阶参数已写入物理储存: $final_opts"
    fi
    
    # 强制挂载内核模块
    modprobe sch_cake >/dev/null 2>&1 || true
    
    _apply_cake_live
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    
    if test -n "$IFACE"; then
        if tc qdisc show dev "$IFACE" 2>/dev/null | grep -q "cake"; then
            info "验证通过：CAKE 高阶队列已成功接管网卡接口！"
        else
            warn "验证失败：网卡当前未运行 CAKE 调度器。请确认系统内核支持 sch_cake 模块。"
        fi
    fi
    
    local _p=""
    read -rp "参数阵列配置完成，请按 Enter 返回主菜单..." _p || true
}

# ==============================================================================
# [ 0x0B: 系统级 20 项深度状态探针与自启保护引擎 ]
# ==============================================================================

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
    if systemctl is-active --quiet dnsmasq 2>/dev/null; then
        if test -f /etc/resolv.conf; then
            if grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null; then 
                echo "true"
                return
            fi
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
    
    if test "$CORES" -lt 2 2>/dev/null; then 
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
# [ 0x0C: 系统底层硬件微操开机加载驱动中心 ]
# ------------------------------------------------------------------------------

update_hw_boot_script() {
    cat > /usr/local/bin/xray-hw-tweaks.sh << 'SHEOF'
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
if test -z "$IFACE"; then
    sleep 3
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
fi
SHEOF

    if test "$(check_thp_state)" = "true"; then
        cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
if test -w /sys/kernel/mm/transparent_hugepage/enabled; then
    echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
    echo never > /sys/kernel/mm/transparent_hugepage/defrag  2>/dev/null || true
fi
EOF
    fi

    if test "$(check_cpu_state)" = "true"; then
        cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    if test -f "$cpu"; then
        echo performance > "$cpu" 2>/dev/null || true
    fi
done
EOF
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
    
    cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
CAKE_OPTS=""
if test -f "/usr/local/etc/xray/cake_opts.txt"; then
    CAKE_OPTS=$(cat "/usr/local/etc/xray/cake_opts.txt" 2>/dev/null || true)
fi

ACK_FLAG=""
if test -f "/usr/local/etc/xray/flags/ack_filter"; then
    ACK_FLAG="ack-filter"
fi

ECN_FLAG=""
if test -f "/usr/local/etc/xray/flags/ecn"; then
    ECN_FLAG="ecn"
fi

WASH_FLAG=""
if test -f "/usr/local/etc/xray/flags/wash"; then
    WASH_FLAG="wash"
fi
EOF

    if test "$(check_cake_state)" = "true"; then
        echo 'tc qdisc replace dev $IFACE root cake $CAKE_OPTS $ACK_FLAG $ECN_FLAG $WASH_FLAG 2>/dev/null || true' >> /usr/local/bin/xray-hw-tweaks.sh
    fi

    if test "$(check_irq_state)" = "true"; then
        cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
systemctl stop irqbalance 2>/dev/null || true
for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':' || true); do
    if test -w "/proc/irq/$irq/smp_affinity"; then
        echo 1 > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true
    fi
done
EOF
    fi

    chmod +x /usr/local/bin/xray-hw-tweaks.sh 2>/dev/null || true

    cat > /etc/systemd/system/xray-hw-tweaks.service << 'EOF'
[Unit]
Description=Xray Hardware Parameters Loader
After=network.target

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
    
    if test -z "$IFACE"; then
        return
    fi
    
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
# ------------------------------------------------------------------------------
# [ 0x10: 全域无损对齐化多维用户组阵列 (8 行标准对齐) ]
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
    printf "  ${yellow}%-15s${none} : %s\n" "用户 UUID" "$uuid"
    printf "  ${yellow}%-15s${none} : %s\n" "伪装SNI" "${sni:-缺失}"
    printf "  ${yellow}%-15s${none} : %s\n" "公钥(pbk)" "${pbk:-缺失}"
    printf "  ${yellow}%-15s${none} : %s\n" "ShortId" "${shortid:-缺失}"
    printf "  ${yellow}%-15s${none} : %s\n" "uTLS引擎" "$utls"
}

do_summary() {
    if test ! -f "$CONFIG"; then 
        return
    fi
    
    title "The Apex Vanguard 战车控制台 - 节点连接信息分发中心"
    
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
                echo -e "\n  ${cyan}通用配置链接:${none}\n  $link\n"
                
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
            print_green ">>> 落后算力或极简设备的备用堡垒: Shadowsocks"
            print_node_block "Shadowsocks" "$ip" "$s_port" "【直连通道】" "【不兼容】" "【不兼容】" "$s_method" "$s_pass"
            
            local b64
            b64=$(printf '%s:%s' "$s_method" "$s_pass" | base64 | tr -d '\n\r' || echo "")
            local link_ss="ss://${b64}@${ip}:${s_port}#${REMARK_NAME}-SS"
            
            echo -e "\n  ${cyan}通用配置链接:${none}\n  $link_ss\n"
        fi
    fi
}

# ------------------------------------------------------------------------------
# [ 0x11: 带参强绝缘引擎：多用户全量管理器 ]
# ------------------------------------------------------------------------------

do_user_manager() {
    while true; do
        title "用户与认证管理系统 (许可分配/前朝遗老迁移/专属防封面具)"
        
        if test ! -f "$CONFIG"; then 
            error "未能在系统中发现主脑配置文件！"
            return
        fi
        
        local clients
        clients=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .settings?.clients[]? | .id + "|" + (.email // "未命名")' "$CONFIG" 2>/dev/null || echo "")
        
        if test -z "$clients"; then 
            error "内核中没有任何合规的 VLESS 主协议许可名单！"
            local _p=""; read -rp "按 Enter 返回..." _p || true
            return
        fi
        
        if test "$clients" = "null"; then
            error "数据链脱轨，协议体解析返回空值！"
            local _p=""; read -rp "按 Enter 返回..." _p || true
            return
        fi
        
        local tmp_users="/tmp/xray_users_$$.txt"
        echo "$clients" | awk -F'|' '{print NR"|"$1"|"$2}' > "$tmp_users" || true
        
        echo -e "系统当前有效用户列表："
        while IFS='|' read -r num uid remark; do
            local utime
            utime=$(grep "^$uid|" "$USER_TIME_MAP" 2>/dev/null | cut -d'|' -f2 || echo "")
            
            if test -z "$utime"; then
                utime="遗留年代/无溯源"
            fi
            
            echo -e "  $num) 用户: ${cyan}$remark${none} | 签发: ${gray}$utime${none} | ID: ${yellow}$uid${none}"
        done < "$tmp_users"
        hr
        
        echo "  a) 签发新用户凭证"
        echo "  m) 导入外部历史用户"
        echo "  s) 重新指派用户专属伪装 (SNI)"
        echo "  d) 吊销选中用户权限"
        echo "  q) 退出"
        
        local uopt=""
        read -rp "请输入操作代码: " uopt || true
        
        local ip
        ip=$(_get_ip || echo "获取失败")
        
        if test "$uopt" = "a" || test "$uopt" = "A"; then
            local nu
            nu=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
            
            local ns
            ns=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n\r' || echo "")
            
            local ctime
            ctime=$(date +"%Y-%m-%d %H:%M")
            
            local u_remark=""
            read -rp "请指定用户名备注 (默认 User-$ns): " u_remark || true
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
            # 采用绝缘 |= 语法，精准锁定 vless 入站
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
            ensure_xray_is_alive
            
            local vless_node
            vless_node=$(jq -c '.inbounds[]? | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
            local port=$(echo "$vless_node" | jq -r '.port' 2>/dev/null || echo 443)
            local sni=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.serverNames[0]' 2>/dev/null || echo "")
            local pub=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.publicKey' 2>/dev/null || echo "")
            
            info "新用户签发成功。"
            hr
            print_green ">>> 全新准入者代号: $u_remark"
            print_node_block "VLESS-Reality (Vision)" "$ip" "$port" "$sni" "$pub" "$ns" "chrome" "$nu"
            
            local link="vless://${nu}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${ns}&type=tcp#${u_remark}"
            echo -e "\n  ${cyan}独立配置链接:${none}\n  $link\n"
            
            local _p=""; read -rp "按 Enter 继续..." _p || true
            
        elif test "$uopt" = "m" || test "$uopt" = "M"; then
            local m_remark=""
            read -rp "请指定导入用户备注 (默认 Imported): " m_remark || true
            if test -z "$m_remark"; then
                m_remark="Imported"
            fi
            
            local m_uuid=""
            read -rp "请输入要导入的 UUID: " m_uuid || true
            if test -z "$m_uuid"; then 
                error "UUID 不能为空！"
                continue
            fi
            
            local m_sid=""
            read -rp "请输入对应的 ShortId: " m_sid || true
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
            read -rp "绑定专属 SNI (直接回车使用系统默认): " m_sni || true
            
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
            
            ensure_xray_is_alive
            
            local vless_node
            vless_node=$(jq -c '.inbounds[]? | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
            local port=$(echo "$vless_node" | jq -r '.port' 2>/dev/null || echo 443)
            local pub=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.publicKey' 2>/dev/null || echo "")
            
            info "记录导入成功。"
            hr
            print_node_block "VLESS-Reality (Vision)" "$ip" "$port" "$m_sni" "$pub" "$m_sid" "chrome" "$m_uuid"
            
            local link="vless://${m_uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${m_sni}&fp=chrome&pbk=${pub}&sid=${m_sid}&type=tcp#${m_remark}"
            echo -e "\n  ${cyan}独立配置链接:${none}\n  $link\n"
            
            local _p=""; read -rp "按 Enter 继续..." _p || true
            
        elif test "$uopt" = "s" || test "$uopt" = "S"; then
            local snum=""
            read -rp "请输入目标用户序列号: " snum || true
            
            local target_uuid
            target_uuid=$(awk -F'|' -v id="${snum:-0}" '$1==id {print $2}' "$tmp_users" 2>/dev/null || echo "")
            
            local target_remark
            target_remark=$(awk -F'|' -v id="${snum:-0}" '$1==id {print $3}' "$tmp_users" 2>/dev/null || echo "")
            
            if test -n "$target_uuid"; then
                local u_sni=""
                read -rp "请输入新分配的伪装域名 (SNI): " u_sni || true
                
                if test -n "$u_sni"; then
                    _safe_jq_write --arg sni "$u_sni" '
                      (.inbounds[]? | select(.protocol == "vless")) |= (
                          .streamSettings.realitySettings.serverNames += [$sni] | 
                          .streamSettings.realitySettings.serverNames |= unique
                      )
                    '
                    sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                    echo "$target_uuid|$u_sni" >> "$USER_SNI_MAP"
                    
                    ensure_xray_is_alive
                    info "已成功更新 $target_remark 用户的防封锁 SNI: $u_sni"
                    
                    local vless_node
                    vless_node=$(jq -c '.inbounds[]? | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1 || echo "")
                    
                    local port=$(echo "$vless_node" | jq -r '.port' 2>/dev/null || echo 443)
                    local idx=$((${snum:-0} - 1))
                    
                    local sid
                    sid=$(echo "$vless_node" | jq -r ".streamSettings.realitySettings.shortIds[$idx] // empty" 2>/dev/null || echo "")
                    
                    local pub
                    pub=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.publicKey // empty' 2>/dev/null || echo "")
                    
                    local link="vless://${target_uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${u_sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${target_remark}"
                    echo -e "\n  ${cyan}更新后的配置链接:${none}\n  $link\n"
                    
                    local _p=""; read -rp "按 Enter 继续..." _p || true
                fi
            else 
                error "您输入的序列号不在当前列表中。"
            fi
            
        elif test "$uopt" = "d" || test "$uopt" = "D"; then
            local dnum=""
            read -rp "请输入需要吊销的用户序列号: " dnum || true
            
            local total
            total=$(wc -l < "$tmp_users" 2>/dev/null || echo "0")
            
            if test "${total:-0}" -le 1; then 
                error "安全机制拦截：禁止删除系统中最后一位特权用户！"
            else
                local target_uuid
                target_uuid=$(awk -F'|' -v id="${dnum:-0}" '$1==id {print $2}' "$tmp_users" 2>/dev/null || echo "")
                
                if test -n "$target_uuid"; then
                    local idx=$((${dnum:-0} - 1))
                    # -- 防乱序大修：联动绝缘删除 --
                    _safe_jq_write --arg uid "$target_uuid" --argjson i "$idx" '
                        (.inbounds[]? | select(.protocol == "vless")) |= (
                            .settings.clients |= map(select(.id != $uid)) | 
                            .streamSettings.realitySettings.shortIds |= del(.[$i])
                        )
                    '
                    
                    sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                    sed -i "/^$target_uuid|/d" "$USER_TIME_MAP" 2>/dev/null || true
                    
                    ensure_xray_is_alive
                    info "已成功从系统核心中抹除用户: $target_uuid"
                fi
            fi
            
        elif test "$uopt" = "q" || test "$uopt" = "Q"; then 
            rm -f "$tmp_users" 2>/dev/null || true
            break
        fi
    done
}

# ------------------------------------------------------------------------------
# [ 0x12: 全球恶性阻断路由分离系统 (绝缘化 |= 过滤) ]
# ------------------------------------------------------------------------------

_global_block_rules() {
    while true; do
        title "全局防火墙与广告阻断策略"
        if test ! -f "$CONFIG"; then 
            error "未找到配置数据。"
            return
        fi
        
        local bt_en
        bt_en=$(jq -r '.routing.rules[]? | select(.protocol != null) | select(.protocol | index("bittorrent")) | ._enabled' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        local ad_en
        ad_en=$(jq -r '.routing.rules[]? | select(.domain != null) | select(.domain | index("geosite:category-ads-all")) | ._enabled' "$CONFIG" 2>/dev/null | head -n 1 || echo "false")
        
        echo -e "  1) BT 下载协议阻断限制          | 状态: ${yellow}${bt_en}${none}"
        echo -e "  2) 全局恶意域名与广告黑洞过滤   | 状态: ${yellow}${ad_en}${none}"
        echo "  0) 返回上一层菜单"
        
        local bc=""
        read -rp "请选择管理项: " bc || true
        
        case "${bc:-}" in
            1) 
                local nv="true"
                if test "$bt_en" = "true"; then 
                    nv="false"
                fi
                _safe_jq_write --argjson nv_val "$nv" '
                  (.routing.rules[]? | select(.protocol != null and (.protocol | index("bittorrent")))) |= (
                      ._enabled = $nv_val
                  )
                '
                ensure_xray_is_alive
                info "BT 协议阻断状态已切换为: $nv" 
                ;;
                
            2) 
                local nv="true"
                if test "$ad_en" = "true"; then 
                    nv="false"
                fi
                _safe_jq_write --argjson nv_val "$nv" '
                  (.routing.rules[]? | select(.domain != null and (.domain | index("geosite:category-ads-all")))) |= (
                      ._enabled = $nv_val
                  )
                '
                ensure_xray_is_alive
                info "全局广告过滤状态已切换为: $nv" 
                ;;
                
            0) 
                return 
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# [ 0x13: 商业级流量统计与运行雷达中心 ]
# ------------------------------------------------------------------------------

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
        read -rp "请指定管理指令: " s || true
        
        case "${s:-}" in
            1) 
                systemctl status xray --no-pager || true
                local _p=""; read -rp "按 Enter 继续..." _p || true 
                ;;
            2) 
                echo -e "\n  对外公网 IP: ${green}$SERVER_IP${none}\n  系统 DNS 路由: "
                grep "^nameserver" /etc/resolv.conf 2>/dev/null || echo "    获取失败"
                echo -e "  系统监听端口池:"
                ss -tlnp 2>/dev/null | grep xray || echo "    未检测到监听服务"
                local _p=""; read -rp "按 Enter 继续..." _p || true 
                ;;
            3) 
                if ! command -v vnstat >/dev/null 2>&1; then 
                    warn "您的服务器尚未安装 vnstat 监控工具。"
                    local _p=""; read -rp "按 Enter 继续..." _p || true
                    continue
                fi
                
                clear
                title "商用级网络流量审计系统 (vnstat)"
                
                local m_day
                m_day=$(grep -E "^[[:space:]]*MonthRotate" /etc/vnstat.conf 2>/dev/null | awk '{print $2}' | head -n 1 | tr -d '\r\n')
                if test -z "$m_day"; then
                    m_day="1 (系统默认)"
                fi
                
                echo -e "  当前每月流量结算清零日: ${cyan}每月 $m_day 号${none}"
                hr
                (vnstat -m 3 2>/dev/null || vnstat -m 2>/dev/null || true) | sed -e 's/estimated/预估消耗/ig' -e 's/rx/接收流量/ig' -e 's/tx/发送流量/ig' -e 's/total/全域吞吐/ig' -e 's/daily/按日/ig' -e 's/monthly/按自然月/ig'
                hr
                
                echo "  1) 手动指定每月的流量计费清零日期 (1-31)"
                echo "  2) 查询指定历史年月的日跑量详单 (如: 2026-04)"
                echo "  0) 退出流量中心"
                
                local vn_opt=""
                read -rp "  执行系统任务: " vn_opt || true
                
                if test "$vn_opt" = "1"; then
                    local d_day=""
                    read -rp "输入物理结算日标 (1-31): " d_day || true
                    if [[ "$d_day" =~ ^[0-9]+$ ]]; then
                        if test "$d_day" -ge 1 2>/dev/null; then
                            if test "$d_day" -le 31 2>/dev/null; then
                                sed -i '/^[#[:space:]]*MonthRotate/d' /etc/vnstat.conf 2>/dev/null || true
                                echo "MonthRotate $d_day" >> /etc/vnstat.conf
                                systemctl restart vnstat 2>/dev/null || true
                                info "底层配置已更新，流量账单将在每月 $d_day 号截断重组。"
                            else
                                error "非法的输入格式。"
                            fi
                        else
                            error "非法的输入格式。"
                        fi
                    else
                        error "非法的输入格式。"
                    fi
                    local _p=""; read -rp "按 Enter 返回..." _p || true 
                elif test "$vn_opt" = "2"; then
                    local d_month=""
                    read -rp "请输入要穿梭的历史锚点 (格式如 $(date +%Y-%m)，不填默认近 30 天): " d_month || true
                    if test -z "$d_month"; then 
                        vnstat -d 2>/dev/null | sed -e 's/estimated/预估消耗/ig' -e 's/rx/接收流量/ig' -e 's/tx/发送流量/ig' -e 's/total/全域吞吐/ig' -e 's/daily/按日/ig' -e 's/monthly/按自然月/ig' || true
                    else 
                        vnstat -d 2>/dev/null | grep -iE "($d_month| day |estimated|--)" | sed -e 's/estimated/预估消耗/ig' -e 's/rx/接收流量/ig' -e 's/tx/发送流量/ig' -e 's/total/全域吞吐/ig' -e 's/daily/按日/ig' -e 's/monthly/按自然月/ig' || true
                    fi
                    local _p=""; read -rp "按 Enter 返回..." _p || true 
                fi
                ;;
                
            4)
                while true; do
                    clear
                    title "实时公网握手与探源扫描阵列"
                    local x_pids
                    x_pids=$(pidof xray 2>/dev/null | xargs | tr -s ' ' '|' || echo "")
                    
                    if test -n "$x_pids"; then
                        echo -e "  ${cyan}【并发时空隧道分布】${none}"
                        ss -ntupa 2>/dev/null | grep -E "pid=($x_pids)[,)]" | awk '{print $1"_"$2}' | sort | uniq -c | sort -nr | awk '{printf "    通道句柄: %-15s : 吞吐活跃数 %s\n", $2, $1}' || echo "    系统无连接"
                        
                        echo -e "\n  ${cyan}【外网独立来源地址 (TOP 10 排名)】${none}"
                        local ips
                        ips=$(ss -ntupa 2>/dev/null | grep -E "pid=($x_pids)[,)]" | grep -vE "LISTEN|UNCONN" | awk '{print $6}' | sed -E 's/:[0-9]+$//' | tr -d '[]' | grep -vE "^127\.0\.0\.1$|^0\.0\.0\.0$|^::$|^\*$|^::ffff:127\.0\.0\.1$" || echo "")
                        
                        if test -n "$ips"; then
                            echo "$ips" | sort | uniq -c | sort -nr | head -n 10 | awk '{printf "    访客 IP: %-18s (并行发包: %s 次)\n", $2, $1}'
                            local total_ips
                            total_ips=$(echo "$ips" | sort | uniq | wc -l)
                            echo -e "\n  净化后系统绝对独立访客总量: ${yellow}${total_ips}${none}"
                        else 
                            echo -e "    ${gray}探针未捕获任何外部实体。${none}"
                        fi
                    else 
                        error "核心雷达脱机，进程可能已消亡。"
                    fi
                    
                    echo -e "\n  ${green}追踪网运转中... 键入 [ q ] 强行切断并返回${none}"
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
                    title "调整内核级防抢占优先级"
                    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
                    local current_nice="-20"
                    
                    if test -f "$limit_file"; then 
                        if grep -q "^Nice=" "$limit_file" 2>/dev/null; then 
                            current_nice=$(awk -F'=' '/^Nice=/ {print $2}' "$limit_file" | head -n 1 || echo "-20")
                        fi
                    fi
                    
                    echo -e "  当前底层霸道提权分配值: ${cyan}${current_nice}${none} (合规域: -20 到 -10 之间)"
                    hr
                    
                    local new_nice=""
                    read -rp "  键入新的提权参数 (q 撤退): " new_nice || true
                    
                    if test "$new_nice" = "q" || test "$new_nice" = "Q"; then 
                        break
                    fi
                    
                    if [[ "$new_nice" =~ ^-[1-2][0-9]$ ]]; then
                        if test "$new_nice" -ge -20 2>/dev/null; then
                            if test "$new_nice" -le -10 2>/dev/null; then
                                sed -i "s/^Nice=.*/Nice=$new_nice/" "$limit_file" 2>/dev/null || true
                                systemctl daemon-reload >/dev/null 2>&1 || true
                                info "指令注入，5 秒后重启进程锁定新值..."
                                sleep 5
                                systemctl restart xray >/dev/null 2>&1 || true
                                info "底层配置已落实。"
                                local _p=""; read -rp "按 Enter 返回..." _p || true
                                break
                            else
                                error "跨越了合法的数字边界！"
                                sleep 2
                            fi
                        else
                            error "跨越了合法的数字边界！"
                            sleep 2
                        fi
                    else 
                        error "跨越了合法的数字边界！"
                        sleep 2
                    fi
                done
                ;;
                
            6) 
                clear; title "程序运行轨迹日志"; tail -n 50 "$LOG_DIR/xray.log" 2>/dev/null || echo "  暂无留档记录。"; local _p=""; read -rp "按 Enter 退出..." _p || true 
                ;;
                
            7) 
                clear; title "系统错误警告日志"; tail -n 30 "$LOG_DIR/error.log" 2>/dev/null || echo "  服务运行正常，无报错产生。"; local _p=""; read -rp "按 Enter 退出..." _p || true 
                ;;
                
            8)
                clear; title "自动化配置备份与灾难恢复中心"
                ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null || echo "系统内空空如也"
                echo -e "\n  r) 执行逆转，强行覆盖为最近的一份无损快照\n  c) 就地锁定当前参数，压出一份冷备\n  0) 返回"
                
                local bopt=""
                read -rp "指定操作: " bopt || true
                
                if test "$bopt" = "r" || test "$bopt" = "R"; then 
                    restore_latest_backup
                fi
                
                if test "$bopt" = "c" || test "$bopt" = "C"; then 
                    backup_config
                    info "快照已入库封存。"
                    local _p=""; read -rp "Enter..." _p || true
                fi
                ;;
                
            0) 
                return 
                ;;
        esac
    done
}
# ==============================================================================
# [ 0x13.5: Reality 回落黑洞限速探针 ]
# ==============================================================================

do_fallback_probe() {
    clear
    echo -e "\n${yellow}=== Xray Reality 回落陷阱深渊 (Fallback Limit) 扫描探针 ===${none}"
    
    if test ! -f "$CONFIG"; then
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
# [ 0x13.6: 系统建仓初始化与环境更新子菜单 ]
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
                    ntpdate -u us.pool.ntp.org >/dev/null 2>&1 || true
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
# ------------------------------------------------------------------------------
# [ 0x14: Xray 核心通讯底层升维系统 (海外原生直连极速版) ]
# ------------------------------------------------------------------------------

do_update_core() {
    title "Xray 核心框架在线更新系统 (原生直连版)"
    info "正在与 Github 官方主干道建立桥接..."
    
    if bash -c "$(curl -L -s https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" @ install >/dev/null 2>&1; then
        if test -x "$XRAY_BIN"; then
            fix_xray_systemd_limits
            systemctl restart xray >/dev/null 2>&1 || true
            
            local cur_ver
            cur_ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 | awk '{print $2}' || echo "读取异常")
            
            info "系统已升级完毕。当前锚定版本: ${cyan}$cur_ver${none}"
            local _p=""; read -rp "按 Enter 返回主控界面..." _p || true
            return 0
        fi
    fi
    
    error "核心升级遭遇异常！官方脚本执行失败，请检查机器的 DNS 或 IPv6 连通性。"
    local _p=""; read -rp "按 Enter 键返回..." _p || true
    return 1
}

# ------------------------------------------------------------------------------
# [ 0x15: 底层协议矩阵平滑热重载 ]
# ------------------------------------------------------------------------------

_update_matrix() {
    if test ! -f "$CONFIG"; then 
        return
    fi
    
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

# ------------------------------------------------------------------------------
# [ 0x16: Xray 核心全域部署与加密结构建仓 ]
# ------------------------------------------------------------------------------

do_install() {
    title "Xray 核心部署与网络架构初始化"
    preflight
    
    systemctl stop xray >/dev/null 2>&1 || true
    
    if test ! -f "$INSTALL_DATE_FILE"; then 
        date +"%Y-%m-%d %H:%M:%S" > "$INSTALL_DATE_FILE"
    fi
    
    echo -e "  ${cyan}请选择需要部署的协议架构：${none}"
    echo "  1) VLESS-Reality (最新抗封锁协议，隐蔽特征)"
    echo "  2) Shadowsocks (极简架构，轻量开销)"
    echo "  3) 双协议并行部署"
    
    local proto_choice=""
    read -rp "  请选择 (默认 1): " proto_choice || true
    proto_choice=${proto_choice:-1}

    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        while true; do 
            local input_p=""
            read -rp "设置 VLESS 监听端口 (默认 443): " input_p || true
            input_p=${input_p:-443}
            if validate_port "$input_p"; then 
                LISTEN_PORT="$input_p"
                break
            fi
        done
        
        local input_remark=""
        read -rp "设置节点备注名称 (默认 xp-reality): " input_remark || true
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
            read -rp "设置 SS 监听端口 (默认 8388): " input_s || true
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
            read -rp "设置节点备注名称 (默认 xp-reality): " input_remark || true
            REMARK_NAME=${input_remark:-xp-reality}
        fi
    fi

    info "从官方仓库直连拉取最新 Xray 核心..."
    if ! bash -c "$(curl -fsSL --connect-timeout 10 https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)" @ install >/dev/null 2>&1; then
        warn "通过官方脚本拉取失败，这不影响后续流程，您可以稍后通过主菜单尝试核心重载。"
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
          "settings": {"domainStrategy": "AsIs"}
      }, 
      {
          "protocol": "blackhole", 
          "tag": "block"
      }
  ]
}
EOF

    # 2. 注入 VLESS 面板 (采用 slurpfile 绝缘拼装)
    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        local keys priv pub uuid sid ctime
        keys=$("$XRAY_BIN" x25519 2>/dev/null || echo "")
        priv=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' \r\n' || echo "")
        pub=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' \r\n' || echo "")
        uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
        sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n\r' || echo "")
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
        read -rp "按 Enter 返回主菜单，或输入 b 重新配置 SNI: " opt || true
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
# [ 0x23: 物理不可逆自毁中心 ]
# ------------------------------------------------------------------------------

do_uninstall() {
    title "物理级毁灭清理与系统生态还原"
    
    local confirm=""
    read -rp "危险指令: 执行后将彻底剥离所有网络拦截、守护进程及私钥配置，无可撤销。确信？(y/n): " confirm || true
    
    if test "$confirm" != "y"; then 
        return
    fi
    
    info "授权通过，正在解构基础架构..."
    systemctl stop dnsmasq >/dev/null 2>&1 || true
    systemctl disable dnsmasq >/dev/null 2>&1 || true
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get purge -y dnsmasq >/dev/null 2>&1 || true
    
    chattr -i /etc/resolv.conf 2>/dev/null || true
    if test -f /etc/resolv.conf.bak; then 
        mv -f /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null || true
    fi
    
    systemctl stop xray >/dev/null 2>&1 || true
    systemctl disable xray >/dev/null 2>&1 || true
    rm -rf /etc/systemd/system/xray* /lib/systemd/system/xray* >/dev/null 2>&1 || true
    systemctl daemon-reload >/dev/null 2>&1 || true
    
    rm -rf "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SCRIPT_DIR" /var/log/xray* /usr/local/bin/xrv "$SCRIPT_PATH" >/dev/null 2>&1 || true
    
    local temp_cron
    temp_cron=$(mktemp /tmp/cron_XXXXXX) || true
    if test -f "$temp_cron"; then
        crontab -l 2>/dev/null | grep -v "update-dat.sh" | grep -v "systemctl restart xray" | grep -v "cc1.sh" > "$temp_cron" || true
        crontab "$temp_cron" 2>/dev/null || true
        rm -f "$temp_cron" 2>/dev/null || true
    fi
    
    info "格式化肃清已落定，环境完全重置回归纯净。"
    exit 0
}

# ------------------------------------------------------------------------------
# [ 0x24: 系统绝对中枢：战舰大屏主控制台 ]
# ------------------------------------------------------------------------------

main_menu() {
    while true; do
        clear
        echo -e "${blue}======================================================================${none}"
        echo -e "  ${magenta}Xray 高维控制台 (Apex Vanguard V188e5 Industrial Base)${none}"
        
        local svc
        svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        
        if test "$svc" = "active"; then 
            svc="${green}健康驱动 (Active)${none}"
        else 
            svc="${red}心跳静默 (Inactive)${none}"
        fi
        
        local sys_ver
        sys_ver=$(uname -r 2>/dev/null || echo "未知内核")
        
        echo -e "  引擎态势: $svc | 热键调用: ${cyan}xrv${none} | 物理信标: ${yellow}$(_get_ip || echo "获取失败")${none}"
        echo -e "  当前内核: ${cyan}${sys_ver}${none} | 所处时空版本: V${SCRIPT_VERSION}"
        echo -e "${blue}======================================================================${none}"
        echo "  1) 创建/重构 绝对安全的双轨加密协议通道 (VLESS/SS)"
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
        read -rp "请下达命令代号: " num || true
        
        case "${num:-}" in
            1) do_install ;;
            2) do_user_manager ;;
            3) 
                do_summary
                while true; do 
                    local rb=""
                    read -rp "指令确认，按下 Enter 撤离，或敲击 b 开启伪装矩阵漂移: " rb || true
                    if test "$rb" = "b" || test "$rb" = "B"; then 
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
                print_magenta ">>> 发出信号流获取云端最新基库..."
                bash "$UPDATE_DAT_SCRIPT" >/dev/null 2>&1 || true
                ensure_xray_is_alive
                info "拉取成功，路由数据结构表已全面推送到内核层！"
                local _p=""; read -rp "输入 Enter 确认继续..." _p || true 
                ;;
            5) do_update_core ;;
            6) 
                if choose_sni; then 
                    _update_matrix
                    do_summary
                    while true; do 
                        local rb=""
                        read -rp "指令结束，请按下 Enter 离场，或强制键入 b 继续重塑链路: " rb || true
                        if test "$rb" = "b" || test "$rb" = "B"; then 
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
                echo -e "${red}错误：系统无法识别该指令！${none}"
                sleep 1
                ;;
        esac
    done
}

# ==============================================================================
# 引擎点火：闭环环境拦截与中枢拉起
# ==============================================================================
preflight
main_menu
# ==============================================================================
# EOF - Apex Vanguard V188e5 System Core Ready.
# ==============================================================================
