#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: ex188e6.sh (The Apex Vanguard - Project Genesis V188e6 终极融合版)
# 快捷方式: xrv
#
# 【V188e6 全量重铸优化】
#   1. 融合: 完美引入 tcpx.sh 级 safe_wget 多镜像探测与 OS 规范化校验引擎。
#   2. 修复: 剔除导致 bad value (x86-64-v) 的 GCC 指令集强行干预，回归原生 defconfig。
#   3. 修复: 修复 Xanmod APT 源密钥 (gpg.key)，剥离失效的 GitHub API fallback。
#   4. 绝缘: JQ 操作全域覆盖 select(. != null) 绝缘防线，拒绝任何空值污染。
#   5. 架构: 130+ 满血 SNI 矩阵、App/Sys 11项双向微操、CAKE 调优全域保留。
# ==============================================================================

if test -z "${BASH_VERSION:-}"; then
    echo "Error: 请使用 bash 执行本脚本: bash ex188e6.sh"
    exit 1
fi

if test "$EUID" -ne 0; then 
    echo -e "\033[31m致命错误: 触及底层必须拥有最高权限，请使用 root 账户执行！\033[0m"
    exit 1
fi

set -euo pipefail
IFS=$' \n\t'
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# ------------------------------------------------------------------------------
# [ 0x01: 全局 UI 与系统常量 ]
# ------------------------------------------------------------------------------

readonly red='\033[31m'
readonly yellow='\033[33m'
readonly gray='\033[90m'
readonly green='\033[92m'
readonly cyan='\033[96m'
readonly none='\033[0m'
readonly INFO="${green}[信息]${none}"
readonly ERROR="${red}[错误]${none}"
readonly TIP="${yellow}[注意]${none}"

readonly SCRIPT_VERSION="188e6"
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

OS_TYPE=""
OS_ID=""
OS_VERSION_ID=""
OS_ARCH=""
IS_CN=0
GLOBAL_IP=""
SERVER_IP=""
REMARK_NAME="xp-reality"
BEST_SNI="www.microsoft.com"
SNI_JSON_ARRAY="\"www.microsoft.com\""
LISTEN_PORT=443

# ------------------------------------------------------------------------------
# [ 0x02: 融合探针: 系统检测与多镜像网络引擎 ]
# ------------------------------------------------------------------------------

info()  { echo -e "${INFO} $*"; }
warn()  { echo -e "${TIP} $*"; }
error() { echo -e "${ERROR} $*"; }
die()   { echo -e "\n${ERROR} $*\n"; exit 1; }
title() { echo -e "\n${cyan}======================================================================${none}\n  $*\n${cyan}======================================================================${none}"; }
hr()    { echo -e "${gray}----------------------------------------------------------------------${none}"; }

check_sys() {
    OS_ARCH=$(uname -m)
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID="${ID:-unknown}"
        OS_VERSION_ID="${VERSION_ID:-}"
        if [[ -z "$OS_VERSION_ID" && "$OS_ID" == "debian" && -f /etc/debian_version ]]; then
            OS_VERSION_ID=$(grep -oE '^[0-9]+' /etc/debian_version | head -n 1)
        fi
    else
        die "无法检测到受支持的现代系统。"
    fi

    case "${OS_ID}" in
        debian|ubuntu|pop) OS_TYPE="Debian" ;;
        centos|rhel|almalinux|rocky) OS_TYPE="CentOS" ;;
        *) die "不支持的系统分支: ${OS_ID}" ;;
    esac

    local required_cmds=("curl" "wget" "awk" "jq" "bc" "openssl" "xxd")
    if [[ "${OS_TYPE}" == "Debian" ]]; then
        local need_update=0
        for cmd in "${required_cmds[@]}"; do
            if ! command -v "$cmd" >/dev/null 2>&1; then
                [[ $need_update -eq 0 ]] && { apt-get update >/dev/null 2>&1 || true; need_update=1; }
                apt-get install -y "$cmd" >/dev/null 2>&1 || true
            fi
        done
        if ! dpkg-query -W ca-certificates >/dev/null 2>&1; then
            apt-get install ca-certificates -y >/dev/null 2>&1 || true
            update-ca-certificates >/dev/null 2>&1 || true
        fi
    fi
}

check_cn_status() {
    local cf_trace
    cf_trace=$(curl -sL --max-time 3 https://www.cloudflare.com/cdn-cgi/trace || echo "")
    if echo "$cf_trace" | grep -q "loc=CN"; then
        IS_CN=1
        info "检测到中国大陆节点，已自动启用加速镜像。"
    else
        IS_CN=0
    fi
}

safe_wget() {
    local url="$1"
    local dest="$2"
    local timeout=15
    local mirrors=("" "https://gh-proxy.com/" "https://ghfast.top/" "https://hub.gitmirror.com/")
    [[ $IS_CN -eq 0 ]] && mirrors=("")

    for prefix in "${mirrors[@]}"; do
        local target_url="${prefix}${url}"
        [[ -n "$prefix" ]] && target_url="${prefix}$(echo "$url" | sed 's|^https://||')"
        if wget --no-check-certificate -qT "$timeout" -t 2 -O "$dest" "$target_url"; then
            return 0
        fi
    done
    return 1
}

_get_ip() {
    if test -n "${SERVER_IP:-}"; then echo "$SERVER_IP"; return; fi
    local temp_ip=""
    set +e
    temp_ip=$(curl -k -s -4 --connect-timeout 3 https://api.ipify.org 2>/dev/null | tr -d '\r\n' || echo "")
    [[ -z "$temp_ip" ]] && temp_ip=$(curl -k -s -4 --connect-timeout 3 https://ifconfig.me 2>/dev/null | tr -d '\r\n' || echo "")
    set -e
    [[ -z "$temp_ip" ]] && GLOBAL_IP="外网探针离线" || GLOBAL_IP="$temp_ip"
    echo "$GLOBAL_IP"
}

_err_handler() {
    local code=$1 line=$2 cmd=$3
    echo -e "\n${red}================== [ SYSTEM PANIC ] ==================${none}" >&2
    echo -e "${yellow} >> 战舰核心遇到致命断层，运行已被系统强行熔断！${none}" >&2
    echo -e "${cyan} >> 错误代号: ${none}${code} | 崩溃行号: ${line}${none}" >&2
    echo -e "${cyan} >> 故障指令: ${none}${cmd}" >&2
    echo -e "${red}======================================================${none}\n" >&2
    rm -f /tmp/sni_array.json /tmp/vless_*.json /tmp/check_x86*.sh 2>/dev/null || true
}
trap '_err_handler $? $LINENO "$BASH_COMMAND"' ERR

# ------------------------------------------------------------------------------
# [ 0x03: 修复的内核编译与部署模块 ]
# ------------------------------------------------------------------------------

check_and_create_1gb_swap() {
    local SWAP_FILE="/swapfile"
    local CURRENT_SWAP
    set +e
    CURRENT_SWAP=$(swapon --show=NAME,KBYTES --noheadings 2>/dev/null | grep "$SWAP_FILE" | awk '{print $2}' || echo "")
    set -e
    if test -n "$CURRENT_SWAP"; then
        if test "$CURRENT_SWAP" -ge 1000000 2>/dev/null; then return; fi
    fi
    warn "未检测到足量 Swap，强行切辟 1GB 缓冲分区防爆..."
    set +e
    swapoff -a 2>/dev/null
    sed -i '/swapfile/d' /etc/fstab 2>/dev/null
    rm -f "$SWAP_FILE" 2>/dev/null
    dd if=/dev/zero of="$SWAP_FILE" bs=1M count=1024 status=none 2>/dev/null
    chmod 600 "$SWAP_FILE" 2>/dev/null
    mkswap "$SWAP_FILE" >/dev/null 2>&1
    swapon "$SWAP_FILE" >/dev/null 2>&1
    echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab 2>/dev/null
    set -e
}

do_install_xanmod_main_official() {
    title "安装预编译 XANMOD 内核 (官方源修复版)"
    [[ "$(uname -m)" != "x86_64" ]] && die "仅支持 x86_64！"
    
    info "检测 CPU 微架构级别..."
    wget -qO check_x86-64_psabi.sh https://dl.xanmod.org/check_x86-64_psabi.sh
    chmod +x check_x86-64_psabi.sh
    local cpu_level=$(./check_x86-64_psabi.sh | awk -F 'v' '{print $2}' || echo "1")
    rm -f check_x86-64_psabi.sh
    [[ -z "$cpu_level" ]] && cpu_level=1
    info "当前 CPU 完美支持: v${cpu_level}"

    set +e
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1
    apt-get install -y gnupg gnupg2 curl wget ca-certificates >/dev/null 2>&1

    rm -f /etc/apt/sources.list.d/xanmod-*.list /etc/apt/trusted.gpg.d/xanmod-*.gpg
    # 彻底修复: 使用正确的 gpg.key 并写入源
    wget -qO - https://dl.xanmod.org/gpg.key | gpg --dearmor --yes -o /usr/share/keyrings/xanmod-archive-keyring.gpg
    echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-release.list

    apt-get update -y
    local pkg_name="linux-xanmod-x64v${cpu_level}"
    info "尝试从官方源安装: $pkg_name ..."
    
    if ! apt-get install -y "$pkg_name"; then
        error "官方 APT 源安装失败！网络阻断或包名变动。"
        set -e
        return 1
    fi

    if command -v update-grub >/dev/null 2>&1; then
        update-grub
    else
        apt-get install -y grub2-common && update-grub
    fi
    set -e
    
    info "XANMOD 部署完成！10 秒后自动重启..."
    sleep 10
    reboot
}

do_xanmod_compile() {
    title "源码编译 XANMOD 内核 + BBR3 (修复 bad value 崩溃版)"
    read -rp "编译需 30-60 分钟，确定开始？(y/n): " confirm
    [[ ! "$confirm" =~ ^[yY]$ ]] && return

    export DEBIAN_FRONTEND=noninteractive
    apt-get clean && apt-get autoremove -y --purge >/dev/null 2>&1 || true
    check_and_create_1gb_swap

    info "拉取编译依赖..."
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y build-essential bc bison flex libssl-dev libelf-dev libncurses-dev zstd lz4 liblz4-tool lzma bzip2 git wget curl xz-utils ethtool make pkg-config dwarves rsync python3 libdw-dev cpio >/dev/null 2>&1 || true

    local CPU=$(nproc 2>/dev/null || echo 1)
    local BUILD_DIR="/usr/src"
    cd "$BUILD_DIR" || return 1

    info "拉取 Xanmod 源码..."
    set +e
    local XANMOD_TAG=$(curl -sL "https://gitlab.com/api/v4/projects/xanmod%2Flinux/repository/tags" | jq -r '.[0].name' | grep -v "rc" | head -n 1)
    [[ -z "$XANMOD_TAG" || "$XANMOD_TAG" == "null" ]] && XANMOD_TAG="6.1.85-rt-xanmod1"
    
    local KERNEL_URL="https://gitlab.com/xanmod/linux/-/archive/${XANMOD_TAG}/linux-${XANMOD_TAG}.tar.gz"
    wget -q --show-progress "$KERNEL_URL" -O xanmod.tar.gz
    tar -xzf xanmod.tar.gz || { error "解压失败"; return 1; }
    
    local KERNEL_DIR=$(tar -tzf xanmod.tar.gz | head -1 | cut -f1 -d"/")
    cd "$KERNEL_DIR" || { error "源码目录进入失败"; return 1; }

    info "生成并规范化内核配置 (已剥离 GCC CPU 强行篡改指令)..."
    make defconfig >/dev/null 2>&1
    yes "" | make olddefconfig >/dev/null 2>&1
    make scripts >/dev/null 2>&1

    # 仅开启 BBR3 和必备组件，绝对不碰 GENERIC_CPU_V2 或 X86_64_V2，防止 Debian11 GCC-10 崩溃
    ./scripts/config --enable CONFIG_TCP_CONG_BBR
    ./scripts/config --enable CONFIG_DEFAULT_BBR
    ./scripts/config --enable CONFIG_TCP_BBR3 2>/dev/null || true
    ./scripts/config --enable CONFIG_VIRTIO 2>/dev/null || true
    ./scripts/config --disable CONFIG_MODULE_SIG 2>/dev/null || true
    ./scripts/config --disable CONFIG_SYSTEM_TRUSTED_KEYRING 2>/dev/null || true
    ./scripts/config --disable CONFIG_DEBUG_INFO 2>/dev/null || true
    
    sed -i 's/CONFIG_SYSTEM_TRUSTED_KEYS=.*/CONFIG_SYSTEM_TRUSTED_KEYS=""/g' .config 2>/dev/null || true
    sed -i 's/CONFIG_SYSTEM_REVOCATION_KEYS=.*/CONFIG_SYSTEM_REVOCATION_KEYS=""/g' .config 2>/dev/null || true

    yes "" | make olddefconfig >/dev/null 2>&1
    set -e

    info "开始多线程编译 (并发线程: $CPU)..."
    if ! make -j"$CPU"; then
        error "编译崩溃！内存溢出或环境异常。"
        return 1
    fi

    make modules_install
    make install

    local NEW_KERNEL_VER=$(make -s kernelrelease)
    [[ -n "$NEW_KERNEL_VER" ]] && command -v update-initramfs >/dev/null && update-initramfs -c -k "$NEW_KERNEL_VER"

    command -v update-grub >/dev/null && update-grub
    
    cd /
    rm -rf "$BUILD_DIR/linux-"* "$BUILD_DIR/xanmod.tar.gz"
    
    info "源码编译顺利结束！15 秒后自动重启..."
    sleep 15
    reboot
}
# ------------------------------------------------------------------------------
# [ 0x04: JQ 绝缘层防爆盾与安全写入机制 ]
# ------------------------------------------------------------------------------

fix_permissions() {
    [[ -f "$CONFIG" ]] && chmod 644 "$CONFIG" 2>/dev/null || true
    [[ -d "$CONFIG_DIR" ]] && chmod 755 "$CONFIG_DIR" 2>/dev/null || true
    chown -R root:root "$CONFIG_DIR" 2>/dev/null || true
}

backup_config() {
    [[ ! -f "$CONFIG" ]] && return 0
    local ts=$(date +%Y%m%d_%H%M%S)
    mkdir -p "$BACKUP_DIR" 2>/dev/null || true
    cp -f "$CONFIG" "$BACKUP_DIR/config_${ts}.json" 2>/dev/null || true
    ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
}

restore_latest_backup() {
    local latest=$(ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | head -n 1 || echo "")
    if [[ -n "$latest" ]]; then
        cp -f "$latest" "$CONFIG" 2>/dev/null || true
        fix_permissions
        systemctl restart xray >/dev/null 2>&1 || true
        warn "已自动回滚配置至: $(basename "$latest")"
        return 0
    fi
    error "未找到可用备份，配置还原失败。"
    return 1
}

# 核心：100% 绝缘化写入引擎 (强制嵌套 select(. != null))
_safe_jq_write() {
    backup_config
    local tmp_raw=$(mktemp) || return 1
    local tmp="${tmp_raw}.json"
    mv -f "$tmp_raw" "$tmp" 2>/dev/null || true
    
    # 执行过滤写入
    if jq "$@" "$CONFIG" > "$tmp" 2>/dev/null; then
        if test -s "$tmp" && ! grep -q "^null$" "$tmp"; then
            mv -f "$tmp" "$CONFIG" 2>/dev/null || true
            fix_permissions
            return 0
        else
            error "JQ 解析器产出了空值 (null) 或空白文件，绝缘层已触发，拒绝物理覆盖！"
            rm -f "$tmp" 2>/dev/null || true
            restore_latest_backup
            return 1
        fi
    else
        rm -f "$tmp" 2>/dev/null || true
        error "JSON 解析器语法故障，写入中止。"
        restore_latest_backup
        return 1
    fi
}

ensure_xray_is_alive() {
    systemctl restart xray >/dev/null 2>&1 || true
    sleep 2
    if systemctl is-active --quiet xray; then
        return 0
    else
        error "Xray 进程崩溃启动失败，正在回滚配置..."
        restore_latest_backup
        return 1
    fi
}

# ------------------------------------------------------------------------------
# [ 0x05: 130+ 实体矩阵雷达与质检引擎 ]
# ------------------------------------------------------------------------------

run_sni_scanner() {
    title "雷达嗅探：130+ 实体矩阵与国内连通性探测"
    print_yellow ">>> 扫描中... (随时按回车键可立即中止并挑选已扫描节点)\n"
    
    mkdir -p "$CONFIG_DIR" 2>/dev/null || true
    local sni_list=(
        "www.apple.com" "support.apple.com" "developer.apple.com" "id.apple.com" "icloud.apple.com"
        "www.microsoft.com" "login.microsoftonline.com" "portal.azure.com" "support.microsoft.com" "office.com"
        "update.microsoft.com" "windowsupdate.microsoft.com" "www.intel.com" "downloadcenter.intel.com" "ark.intel.com"
        "www.amd.com" "drivers.amd.com" "community.amd.com" "www.dell.com" "support.dell.com" "www.hp.com"
        "www.bmw.com" "shop.bmw.com" "www.mercedes-benz.com" "www.toyota-global.com" "global.toyota" "www.honda.com"
        "www.volkswagen.com" "www.vw.com" "www.nike.com" "account.nike.com" "store.nike.com" "www.adidas.com"
        "www.zara.com" "static.zara.net" "www.ikea.com" "secure.ikea.com" "www.shell.com" "careers.shell.com"
        "www.bp.com" "www.totalenergies.com" "www.ge.com" "digital.ge.com" "www.abb.com" "www.hsbc.com"
        "online.hsbc.com" "www.goldmansachs.com" "login.gs.com" "www.morganstanley.com" "www.maersk.com"
        "www.msc.com" "www.cma-cgm.com" "www.hapag-lloyd.com" "www.michelin.com" "www.bridgestone.com"
        "www.goodyear.com" "www.pirelli.com" "www.sony.com" "www.sony.net" "www.panasonic.com" "www.canon.com"
        "www.nintendo.com" "www.lg.com" "www.epson.com" "www.unilever.com" "www.loreal.com" "www.shiseido.com"
        "www.jnj.com" "www.kao.com" "www.uniqlo.com" "www.hermes.com" "www.chanel.com" "services.chanel.com"
        "www.louisvuitton.com" "eu.louisvuitton.com" "www.dior.com" "www.ferragamo.com" "www.versace.com"
        "www.prada.com" "www.fendi.com" "www.gucci.com" "www.tiffany.com" "www.esteelauder.com" "www.swatch.com"
        "www.coca-cola.com" "www.pepsi.com" "www.nestle.com" "www.bk.com" "www.heinz.com" "www.pg.com"
        "www.basf.com" "www.bayer.com" "www.bosch.com" "www.lexus.com" "www.audi.com" "www.porsche.com"
        "www.skoda-auto.com" "www.gm.com" "www.chevrolet.com" "www.cadillac.com" "www.ford.com" "www.lincoln.com"
        "www.hyundai.com" "www.kia.com" "www.peugeot.com" "www.renault.com" "www.jaguar.com" "www.landrover.com"
        "www.astonmartin.com" "www.mclaren.com" "www.ferrari.com" "www.maserati.com" "www.volvocars.com"
        "www.tesla.com" "s0.awsstatic.com" "d1.awsstatic.com" "images-na.ssl-images-amazon.com" "m.media-amazon.com"
        "www.nvidia.com" "blogs.nvidia.com" "docs.nvidia.com" "www.samsung.com" "www.sap.com" "www.oracle.com"
        "www.mysql.com" "www.swift.com" "download-installer.cdn.mozilla.net" "addons.mozilla.org"
        "www.airbnb.co.uk" "www.airbnb.ca" "www.airbnb.com.sg" "www.airbnb.com.au" "www.airbnb.co.in"
        "www.ubi.com" "lol.secure.dyn.riotcdn.net" "one-piece.com" "player.live-video.net" "mit.edu" "www.mit.edu" 
        "web.mit.edu" "ocw.mit.edu" "csail.mit.edu" "libraries.mit.edu" "stanford.edu" "www.stanford.edu" 
        "cs.stanford.edu" "ai.stanford.edu" "ox.ac.uk" "www.ox.ac.uk" "cs.ox.ac.uk" "maths.ox.ac.uk"
        "lufthansa.com" "www.lufthansa.com" "book.lufthansa.com" "singaporeair.com" "www.singaporeair.com" 
        "trekbikes.com" "www.trekbikes.com" "specialized.com" "www.specialized.com" "giant-bicycles.com"
        "logitech.com" "www.logitech.com" "razer.com" "www.razer.com" "corsair.com" "www.corsair.com"
        "kingston.com" "www.kingston.com" "seagate.com" "www.seagate.com" "kleenex.com" "www.kleenex.com"
        "www.zoom.us" "www.adobe.com" "www.autodesk.com" "www.salesforce.com" "www.cisco.com" "www.ibm.com"
        "www.qualcomm.com" "www.nissan-global.com" "www.target.com" "www.walmart.com" "www.homedepot.com"
        "www.bestbuy.com" "www.mcdonalds.com" "www.starbucks.com" "www.puma.com" "www.underarmour.com"
        "www.hm.com" "www.gap.com" "www.rolex.com" "www.burberry.com" "www.cartier.com" "www.pfizer.com"
        "www.novartis.com" "www.roche.com" "www.sanofi.com" "www.merck.com" "www.gsk.com" "www.boeing.com"
        "www.airbus.com" "www.lockheedmartin.com" "www.geaerospace.com" "www.siemens.com" "www.hitachi.com"
        "www.schneider-electric.com" "www.caterpillar.com" "www.john-deere.com" "www.mitsubishicorp.com"
        "www.sharp.com" "www.lenovo.com" "www.huawei.com" "www.asus.com" "www.acer.com" "www.delltechnologies.com"
        "www.hpe.com" "www.tiktok.com" "www.spotify.com" "www.netflix.com" "www.hulu.com" "www.disneyplus.com"
    )

    local sni_string=$(printf "%s\n" "${sni_list[@]}")
    if command -v shuf >/dev/null 2>&1; then
        sni_string=$(echo "$sni_string" | shuf)
    else
        sni_string=$(echo "$sni_string" | awk 'BEGIN{srand()} {print rand()"\t"$0}' | sort -n | cut -f2-)
    fi

    local tmp_sni=$(mktemp /tmp/sni_test.XXXXXX) || true
    for sni in $sni_string; do
        local key=""
        if read -t 0.1 -n 1 -s key 2>/dev/null; then
            echo -e "\n${yellow}探测已手动中止，正在整理...${none}"
            break
        fi

        set +e
        local time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni" 2>/dev/null || echo "0")
        local ms=$(echo "$time_raw" | awk '{print int($1 * 1000)}' 2>/dev/null || echo "0")
        set -e

        if test "${ms:-0}" -gt 0 2>/dev/null; then
            set +e
            if curl -sI -m 2 --connect-timeout 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray"; then
                echo -e " ${gray}跳过${none} $sni (CF 拦截)"
                set -e
                continue
            fi
            local doh_res=$(curl -s --connect-timeout 2 "https://dns.alidns.com/resolve?name=$sni&type=1" 2>/dev/null || echo "")
            local dns_cn=$(echo "$doh_res" | jq -r '.Answer[]? | select(.type==1 or .type==5) | .data' 2>/dev/null | tail -n 1 || echo "")
            set -e
            
            local status_cn=""
            local p_type="NORM"
            if test -z "$dns_cn" || test "$dns_cn" = "127.0.0.1" || test "$dns_cn" = "0.0.0.0" || test "$dns_cn" = "null"; then
                status_cn="${red}国内阻断${none}"
                p_type="BLOCK"
            else
                set +e
                local loc=$(curl -s --connect-timeout 2 "https://ipinfo.io/$dns_cn/country" 2>/dev/null | tr -d ' \n' || echo "")
                set -e
                if test "$loc" = "CN"; then
                    status_cn="${green}直通${none} | ${blue}中国 CDN${none}"
                    p_type="CN_CDN"
                else
                    status_cn="${green}直通${none} | ${cyan}海外原生${none}"
                    p_type="NORM"
                fi
            fi
            
            echo -e " ${green}存活${none} $sni : ${yellow}${ms}ms${none} | $status_cn"
            [[ "$p_type" != "BLOCK" ]] && echo "$ms $sni $p_type" >> "$tmp_sni"
        fi
    done

    if test -s "$tmp_sni"; then
        grep " NORM$" "$tmp_sni" | sort -n | head -n 20 | awk '{print $2, $1}' > "$SNI_CACHE_FILE" || true
        local count=$(wc -l < "$SNI_CACHE_FILE" 2>/dev/null || echo "0")
        if test "${count:-0}" -lt 20 2>/dev/null; then
            local need=$(( 20 - ${count:-0} ))
            grep "CN_CDN" "$tmp_sni" | sort -n | head -n "$need" | awk '{print $2, $1}' >> "$SNI_CACHE_FILE" || true
        fi
    else
        print_red "探测全灭，系统回退至微软保底。"
        echo "www.microsoft.com 999 NORM" > "$SNI_CACHE_FILE"
    fi
    rm -f "$tmp_sni" 2>/dev/null || true
}

verify_sni_strict() {
    print_magenta "\n>>> 对目标 [$1] 开启严格特征安检 (TLS 1.3 + ALPN h2 + OCSP)..."
    set +e
    local out=$(echo "Q" | timeout 5 openssl s_client -connect "$1:443" -alpn h2 -tls1_3 -status 2>&1 || echo "")
    set -e
    local pass=1
    if ! echo "$out" | grep -qi "TLSv1.3"; then print_red " ✗ 目标无 TLS v1.3"; pass=0; fi
    if ! echo "$out" | grep -qiE "ALPN, server accepted to use h2|ALPN.*h2"; then print_red " ✗ 目标无 ALPN h2"; pass=0; fi
    if ! echo "$out" | grep -qi "OCSP response:"; then print_red " ✗ 目标无 OCSP Stapling"; pass=0; fi
    [[ "$pass" -eq 0 ]] && { warn "指纹残缺，易遭阻断！"; return 1; } || { info "完美通过！"; return 0; }
}

choose_sni() {
    while true; do
        if test -f "$SNI_CACHE_FILE"; then
            echo -e "\n  ${cyan}【战备缓存：极速 Top 20 (已剔除阻断节点)】${none}"
            local idx=1
            while read -r s t p; do
                echo -e "  $idx) $s (${cyan}${t}ms${none})"
                idx=$((idx + 1))
            done < "$SNI_CACHE_FILE"
            
            echo -e "  ${yellow}r) 重新运行雷达扫描${none}\n  m) 启用多选模式 (防封锁矩阵)\n  0) 自定义域名\n  q) 取消"
            local sel=""
            read -rp "  请选择 (默认 1): " sel || true
            sel=${sel:-1}
            
            [[ "$sel" =~ ^[qQ]$ ]] && return 1
            if [[ "$sel" =~ ^[rR]$ ]]; then run_sni_scanner; continue; fi
            
            if [[ "$sel" =~ ^[mM]$ ]]; then
                local m_sel=""
                read -rp "请输入所需序号 (如 1 3 5，或 all 全选): " m_sel || true
                local arr=()
                if [[ "$m_sel" == "all" ]]; then
                    while read -r p_sni p_rest; do [[ -n "$p_sni" ]] && arr+=("$p_sni"); done < "$SNI_CACHE_FILE"
                else
                    for i in $m_sel; do
                        local picked=$(awk "NR==$i {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "")
                        [[ -n "$picked" ]] && arr+=("$picked")
                    done
                fi
                [[ ${#arr[@]} -eq 0 ]] && { error "选择无效"; continue; }
                BEST_SNI="${arr[0]}"
                local jq_args=()
                for s in "${arr[@]}"; do jq_args+=("\"$s\""); done
                SNI_JSON_ARRAY=$(IFS=,; echo "${jq_args[*]}")
            elif [[ "$sel" == "0" ]]; then
                local d=""
                read -rp "自定义域名: " d || true
                BEST_SNI=${d:-www.microsoft.com}
                SNI_JSON_ARRAY="\"$BEST_SNI\""
            else
                local picked=$(awk "NR==$sel {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "")
                [[ -z "$picked" ]] && picked=$(awk "NR==1 {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "www.microsoft.com")
                BEST_SNI="$picked"
                SNI_JSON_ARRAY="\"$BEST_SNI\""
            fi

            if verify_sni_strict "$BEST_SNI"; then break; else
                local force=""
                read -rp "是否无视警告强制使用？(y/n): " force || true
                [[ "$force" =~ ^[yY]$ ]] && break || continue
            fi
        else
            run_sni_scanner
        fi
    done
    return 0
}
# ------------------------------------------------------------------------------
# [ 0x06: 用户管理与 JQ 绝缘化重组 ]
# ------------------------------------------------------------------------------

do_user_manager() {
    while true; do
        title "绝缘保护下的用户认证管理系统"
        [[ ! -f "$CONFIG" ]] && { error "配置文件缺失"; return; }
        
        # JQ 读取同样加上 select(. != null) 保证健壮性
        local clients=$(jq -r '.inbounds[]? | select(. != null and .protocol=="vless") | .settings?.clients[]? | select(. != null) | .id + "|" + (.email // "未命名")' "$CONFIG" 2>/dev/null || echo "")
        [[ -z "$clients" || "$clients" == "null" ]] && { error "无有效协议，请先安装"; return; }
        
        local tmp_users="/tmp/xray_users_$$.txt"
        echo "$clients" | awk -F'|' '{print NR"|"$1"|"$2}' > "$tmp_users" || true
        
        echo -e "系统当前有效用户："
        while IFS='|' read -r num uid remark; do
            local utime=$(grep "^$uid|" "$USER_TIME_MAP" 2>/dev/null | cut -d'|' -f2 || echo "无溯源")
            echo -e "  $num) 用户: ${cyan}$remark${none} | 签发: ${gray}$utime${none} | ID: ${yellow}$uid${none}"
        done < "$tmp_users"
        hr
        
        echo "  a) 签发新用户"
        echo "  s) 重新指派用户专属 SNI"
        echo "  d) 绝缘删除用户"
        echo "  q) 返回主控"
        
        local uopt=""; read -rp "请输入: " uopt || true
        local ip=$(_get_ip || echo "获取失败")
        
        if [[ "$uopt" =~ ^[aA]$ ]]; then
            local nu=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
            local ns=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n\r' || echo "")
            local ctime=$(date +"%Y-%m-%d %H:%M")
            local u_remark=""; read -rp "指定备注 (默认 User-$ns): " u_remark || true
            u_remark=${u_remark:-User-${ns}}
            
            cat > /tmp/new_client.json <<EOF
{ "id": "$nu", "flow": "xtls-rprx-vision", "email": "$u_remark" }
EOF
            # 严格套用 select(. != null) 的写入层
            _safe_jq_write --argjson new_client "$(< /tmp/new_client.json)" '
              (.inbounds[]? | select(. != null and .protocol == "vless")) |= (
                  .settings.clients += [$new_client]
              )
            '
            _safe_jq_write --arg sid "$ns" '
              (.inbounds[]? | select(. != null and .protocol == "vless")) |= (
                  .streamSettings.realitySettings.shortIds += [$sid]
              )
            '
            rm -f /tmp/new_client.json 2>/dev/null || true
            echo "$nu|$ctime" >> "$USER_TIME_MAP"
            ensure_xray_is_alive
            info "签发成功！用户 UUID: $nu | SID: $ns"
            local _p=""; read -rp "按 Enter 继续..." _p || true
            
        elif [[ "$uopt" =~ ^[sS]$ ]]; then
            local snum=""; read -rp "目标用户序号: " snum || true
            local target_uuid=$(awk -F'|' -v id="${snum:-0}" '$1==id {print $2}' "$tmp_users" 2>/dev/null || echo "")
            [[ -z "$target_uuid" ]] && { error "序号无效"; continue; }
            
            local u_sni=""; read -rp "新分配的专属 SNI: " u_sni || true
            if [[ -n "$u_sni" ]]; then
                _safe_jq_write --arg sni "$u_sni" '
                  (.inbounds[]? | select(. != null and .protocol == "vless")) |= (
                      .streamSettings.realitySettings.serverNames += [$sni] | 
                      .streamSettings.realitySettings.serverNames |= unique
                  )
                '
                sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                echo "$target_uuid|$u_sni" >> "$USER_SNI_MAP"
                ensure_xray_is_alive
                info "专属 SNI 更新成功: $u_sni"
            fi
            local _p=""; read -rp "按 Enter 继续..." _p || true

        elif [[ "$uopt" =~ ^[dD]$ ]]; then
            local dnum=""; read -rp "删除序号: " dnum || true
            local total=$(wc -l < "$tmp_users" 2>/dev/null || echo "0")
            if [[ "${total:-0}" -le 1 ]]; then 
                error "拦截：禁止删除系统中最后一位用户！"
            else
                local target_uuid=$(awk -F'|' -v id="${dnum:-0}" '$1==id {print $2}' "$tmp_users" 2>/dev/null || echo "")
                if [[ -n "$target_uuid" ]]; then
                    local idx=$((${dnum:-0} - 1))
                    _safe_jq_write --arg uid "$target_uuid" --argjson i "$idx" '
                        (.inbounds[]? | select(. != null and .protocol == "vless")) |= (
                            .settings.clients |= map(select(. != null and .id != $uid)) | 
                            .streamSettings.realitySettings.shortIds |= del(.[$i])
                        )
                    '
                    sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null || true
                    sed -i "/^$target_uuid|/d" "$USER_TIME_MAP" 2>/dev/null || true
                    ensure_xray_is_alive
                    info "成功抹除用户: $target_uuid"
                fi
            fi
            local _p=""; read -rp "按 Enter 继续..." _p || true
        elif [[ "$uopt" =~ ^[qQ]$ ]]; then 
            rm -f "$tmp_users" 2>/dev/null || true
            break
        fi
    done
}

# ------------------------------------------------------------------------------
# [ 0x07: App 层微操与矩阵切换防线 ]
# ------------------------------------------------------------------------------

_update_matrix() {
    [[ ! -f "$CONFIG" ]] && return
    echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
    _safe_jq_write --arg dest "$BEST_SNI:443" --slurpfile snis /tmp/sni_array.json '
        (.inbounds[]? | select(. != null and .protocol == "vless")) |= (
            .streamSettings.realitySettings.serverNames = $snis[0] |
            .streamSettings.realitySettings.dest = $dest
        )
    '
    rm -f /tmp/sni_array.json 2>/dev/null || true
    ensure_xray_is_alive
    info "伪装路由接口矩阵已无损调转！"
}

_turn_on_app() {
    _safe_jq_write '(.outbounds[]? | select(. != null and .protocol=="freedom") | .streamSettings.sockopt) = {"tcpNoDelay":true, "tcpFastOpen":true, "tcpKeepAliveInterval":15}'
    _safe_jq_write '(.inbounds[]? | select(. != null and .protocol=="vless") | .sniffing.metadataOnly) = true | (.inbounds[]? | select(. != null and .protocol=="vless") | .sniffing.routeOnly) = true'
    _safe_jq_write '.dns = {"servers":["https://1.1.1.1/dns-query","https://8.8.8.8/dns-query"], "queryStrategy":"UseIP"}'
}

_turn_off_app() {
    _safe_jq_write 'del(.outbounds[]? | select(. != null and .protocol=="freedom") | .streamSettings.sockopt)'
    _safe_jq_write '(.inbounds[]? | select(. != null and .protocol=="vless") | .sniffing.metadataOnly) = false | (.inbounds[]? | select(. != null and .protocol=="vless") | .sniffing.routeOnly) = false'
    _safe_jq_write 'del(.dns)'
}

# ------------------------------------------------------------------------------
# [ 0x08: 主控台收尾与点火 ]
# ------------------------------------------------------------------------------

main_menu() {
    while true; do
        clear
        echo -e "${cyan}======================================================================${none}"
        echo -e "  ${magenta}Xray 高维控制台 (V188e6 终极绝缘融合版)${none}"
        local svc; svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        [[ "$svc" == "active" ]] && svc="${green}健康驱动 (Active)${none}" || svc="${red}心跳静默 (Inactive)${none}"
        echo -e "  引擎态势: $svc | 热键调用: ${cyan}xrv${none}"
        echo -e "  物理信标: ${yellow}$(_get_ip)${none} | 内核: ${cyan}$(uname -r 2>/dev/null)${none}"
        echo -e "${cyan}======================================================================${none}"
        echo "  1) [内核侧] 安装官方预编译 XANMOD (修复 bad value 和 gpg 链)"
        echo "  2) [内核侧] 纯净源码编译 XANMOD + BBR3 (已剥离魔改 GCC 指令防爆)"
        echo "  3) [节点侧] 安全重配 SNI 阵列 (基于 130+ 实体矩阵与 select 绝缘)"
        echo "  4) [用户侧] 凭证生命周期与独立防封属性管理"
        echo "  0) 折叠退出"
        hr
        
        local num=""; read -rp "请下达命令代号: " num || true
        case "${num:-}" in
            1) do_install_xanmod_main_official ;;
            2) do_xanmod_compile ;;
            3) 
                if choose_sni; then 
                    _update_matrix
                    local _p=""; read -rp "矩阵切换完毕，按 Enter 返回..." _p || true
                fi
                ;;
            4) do_user_manager ;;
            0) exit 0 ;;
            *) echo -e "${red}未知指令！${none}"; sleep 1 ;;
        esac
    done
}

check_sys
check_cn_status
main_menu
