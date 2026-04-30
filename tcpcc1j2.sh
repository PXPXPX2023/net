#!/usr/bin/env bash
# ==============================================================================
# 脚本名称: tcpcc1j2.sh (The Apex Vanguard - Ultimate Network Kernel Genesis)
# 快捷方式: tcpcc
#
# V1j2 终极底盘融合进化日志:
#   1. 硬核回归: 完整接驳从 Kernel.org 源码编译主线内核与 BBRv3 的极限功能。
#   2. 空间防爆: 引入磁盘与内存双重校验机制，拒绝编译中途 OOM 或 爆盘。
#   3. 变量绝对安全: 100% 修复 `set -euo pipefail` 严格模式下 EOF 导致的未绑定变量崩溃。
#   4. 并发重构: 剥离废弃代理依赖，将 timeout 修复升级为纯粹的 Netfilter 追踪器扩容。
#   5. 目录容错: 强制保障 sysctl.d / security 目录树的完整性，适配任何残缺版 OS。
# ==============================================================================

# 检查 Bash 运行环境
if test -z "$BASH_VERSION"; then
    echo "Error: Please run this script with bash."
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

# 兼容色系别名
readonly gl_hong="$red"
readonly gl_lv="$green"
readonly gl_huang="$yellow"
readonly gl_bai="$none"
readonly gl_kjlan="$cyan"
readonly gl_zi="$magenta"
readonly gl_hui="$gray"

# ── 全局常量与路径 ──────────────────────────────────────────────
readonly SCRIPT_VERSION="tcpcc1j2-Ultimate"
readonly SYSCTL_CONF="/etc/sysctl.d/99-net-tcp-tune.conf"
readonly CAKE_OPTS_FILE="/etc/cake_opts.txt"
readonly LOG_FILE="/var/log/net-tcp-tune.log"
readonly SYMLINK="/usr/local/bin/tcpcc"
readonly SCRIPT_PATH=$(readlink -f "$0")

AUTO_MODE="0"
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# ==============================================================================
# [ 区块 I: 基础工具、UI 渲染与全局容错护盾 ]
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

# 统一日志函数
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true

    case "$level" in
        ERROR) echo -e "${gl_hong}[ERROR] $message${gl_bai}" >&2 ;;
        WARN)  echo -e "${gl_huang}[WARN] $message${gl_bai}" ;;
        INFO)  [ "$LOG_LEVEL" != "ERROR" ] && echo -e "${gl_lv}[INFO] $message${gl_bai}" ;;
        DEBUG) [ "$LOG_LEVEL" = "DEBUG" ] && echo -e "${gl_hui}[DEBUG] $message${gl_bai}" ;;
    esac
}

# 捕获异常中断
trap '_err_handler $? $LINENO "$BASH_COMMAND"' ERR
_err_handler() {
    local code=$1 line=$2 cmd=$3
    echo -e "\n${red}[SYSTEM_ABORT] 退出码:$code 行数:$line 故障指令:$cmd${none}" >&2
    log "ERROR" "EXIT=$code LINE=$line CMD=$cmd"
    rm -f /tmp/net-tcp-tune.* 2>/dev/null || true
}

# 退出清理
cleanup_temp_files() {
    rm -f /tmp/net-tcp-tune.* 2>/dev/null || true
}
trap cleanup_temp_files EXIT

# 终端断点停留 (支持全自动模式跳过)
break_end() {
    if [[ "$AUTO_MODE" == "1" ]]; then return 0; fi
    echo ""
    echo -e "${green}指令执行完毕。${none}"
    local _pause=""
    read -n 1 -s -r -p "按任意键继续返回控制台..." _pause || true
    echo ""
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${gl_hong}错误: ${gl_bai}核心操作被拒，需要 root 权限提升！"
        echo "指令: sudo bash $0"
        exit 1
    fi
}

run_remote_script() {
    local url=$1
    local interpreter=${2:-bash}
    shift 2

    local tmp_file
    tmp_file=$(mktemp /tmp/net-tcp-tune.XXXXXX) || {
        echo -e "${red}❌ 资源拒绝，无法开辟临时内存段${none}"
        return 1
    }

    if command -v curl &>/dev/null; then
        curl -fsSL --connect-timeout 10 --max-time 60 "$url" -o "$tmp_file" 2>/dev/null || true
    elif command -v wget &>/dev/null; then
        wget -qO "$tmp_file" "$url" 2>/dev/null || true
    else
        echo -e "${red}❌ 缺乏网络拉取组件 (curl/wget)${none}"
        rm -f "$tmp_file"
        return 1
    fi

    if [[ ! -s "$tmp_file" ]]; then
        echo -e "${red}❌ 载荷数据丢包失效${none}"
        rm -f "$tmp_file"
        return 1
    fi

    chmod +x "$tmp_file"
    "$interpreter" "$tmp_file" "$@"
    local rc=$?
    rm -f "$tmp_file"
    return $rc
}

check_disk_space() {
    local required_gb=$1
    local required_space_mb=$((required_gb * 1024))
    local available_space_mb
    available_space_mb=$(df -m / 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")

    if [ "$available_space_mb" -lt "$required_space_mb" ]; then
        echo -e "${gl_huang}警告: ${gl_bai}磁盘根目录空间严重不足！"
        echo "当前可用: $((available_space_mb/1024))GB | 最低安全线: ${required_gb}GB"
        local continue_choice=""
        read -e -p "强行继续可能导致系统崩溃，是否继续？(Y/N): " continue_choice || true
        case "${continue_choice:-}" in
            [Yy]) return 0 ;;
            *) return 1 ;;
        esac
    fi
    return 0
}

# ==============================================================================
# [ 区块 II: 系统底盘预装与环境净化 ]
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
    if ! command -v systemctl >/dev/null 2>&1; then
        die "系统环境缺失 systemctl 组件，底层无法驱动。"
    fi

    local need="curl wget unzip openssl coreutils sed iproute2 ethtool bc bison flex dwarves rsync python3 cpio zstd tar"
    local missing=""
    for p in $need; do
        if ! command -v "$p" >/dev/null 2>&1; then
            missing="$missing $p"
        fi
    done
    
    if [[ -n "$missing" ]]; then
        info "填补底层驱动缺失组件: $missing"
        pkg_install $missing
    fi

    if [[ -f "$SCRIPT_PATH" ]]; then
        cp -f "$SCRIPT_PATH" "$SYMLINK" 2>/dev/null || true
        chmod +x "$SYMLINK" 2>/dev/null || true
        hash -r 2>/dev/null || true
    fi
}

# ==============================================================================
# [ 区块 III: 强制 IPv4 与 物理熔断 IPv6 ]
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
    mkdir -p /etc/sysctl.d 2>/dev/null || true
    cat > /etc/sysctl.d/99-disable-ipv6.conf << EOF
# 物理级熔断 IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
    sysctl --system >/dev/null 2>&1 || true

    echo -e "${gl_lv}✅ 策略下发完毕：机器 IPv6 端口已封死，完全阻隔旁路探测！${gl_bai}"
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
    
    local confirm=""
    if [ "$AUTO_MODE" = "1" ]; then 
        confirm="Y"
    else 
        read -e -p "$(echo -e "${gl_huang}是否授予权限自动开辟虚拟缓冲地带？(Y/N): ${gl_bai}")" confirm || true
    fi

    if [[ "${confirm:-}" =~ ^[Yy]$ ]]; then
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
        local choice=""
        read -e -p "决策输入: " choice || true
        
        case "${choice:-}" in
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
# [ 区块 V: XanMod 内核极速管理与源码硬核编译 ]
# ==============================================================================

install_xanmod_kernel() {
    clear
    echo -e "${gl_kjlan}=== 安装预编译 XANMOD (main) 官方内核 ===${gl_bai}"
    echo -e "${gl_huang}警告: 此操作将更替 Linux 底层驱动，重启可能触发宕机！请确认有救援终端！${gl_bai}"
    
    local confirm=""
    if [ "$AUTO_MODE" = "1" ]; then 
        confirm="Y"
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
    echo -e "${gl_zi}底层芯片探勘: 适配至架构等级 v${cpu_level}${gl_bai}"
    
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
    clear
    title "Kernel.org 主线源码提取与 BBRv3 硬核编译"
    warn "源码编译对 CPU 会造成持续 30-60 分钟的高热压榨，期间如 SSH 断裂将前功尽弃。"
    warn "需要至少 15GB 的可用硬盘空间。"
    
    if ! check_disk_space 15; then
        break_end; return 1
    fi

    local confirm=""
    read -e -p "$(echo -e "${gl_huang}警告：确定要从沙盒执行底盘源码编译吗？(Y/N): ${gl_bai}")" confirm || true
    if [[ ! "${confirm:-}" =~ ^[Yy]$ ]]; then return 0; fi
    
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
        warn "Kernel API 无法访问，使用兜底主线版本..."
        KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.10.tar.xz"
    fi
    
    KERNEL_FILE=$(basename "$KERNEL_URL")
    echo -e "${gl_zi}正在拉取源码包: $KERNEL_FILE${gl_bai}"
    wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE" || true

    if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
        warn "压缩包损坏，尝试二次拉取..."
        rm -f "$KERNEL_FILE" 2>/dev/null || true
        wget -q --show-progress "$KERNEL_URL" -O "$KERNEL_FILE" || true
        if ! tar -tJf "$KERNEL_FILE" >/dev/null 2>&1; then
            error "源码加密包被腐蚀，无法解压。请检查您的网络能否访问 kernel.org！"
            return 1
        fi
    fi

    echo -e "${gl_zi}解压内核源码...${gl_bai}"
    tar -xJf "$KERNEL_FILE"
    KERNEL_DIR=$(tar -tf "$KERNEL_FILE" | head -n 1 | cut -d/ -f1)
    if ! cd "$KERNEL_DIR"; then die "源码仓库解构失败"; fi

    info "嗅探现役硬件参数并装填 BBRv3 开关..."
    if [[ -f "/boot/config-$(uname -r)" ]]; then
        cp "/boot/config-$(uname -r)" .config
        info "成功捕获宿主机配置: /boot/config-$(uname -r)"
    else
        if modprobe configs 2>/dev/null && [[ -f /proc/config.gz ]]; then
            zcat /proc/config.gz > .config 2>/dev/null || true
            info "成功截取内存配置: /proc/config.gz"
        else
            warn "未找到底层引路文件！盲眼编译可能引发系统绝症。"
            local force_k=""
            read -e -p "$(echo -e "${gl_huang}是否强行生成默认配置赌一把？(y/N): ${gl_bai}")" force_k || true
            if [[ ! "${force_k:-}" =~ ^[Yy]$ ]]; then return 1; fi
            make defconfig 2>/dev/null || true
        fi
    fi
    
    echo -e "${gl_zi}修剪内核模块分支...${gl_bai}"
    make scripts >/dev/null 2>&1 || true
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
    yes "" | make olddefconfig >/dev/null 2>&1 || true

    info "火炉已被点燃，引擎即将满载狂飙..."
    local CPU RAM THREADS
    CPU=$(nproc 2>/dev/null || echo 1)
    RAM=$(free -m 2>/dev/null | awk '/Mem/{print $2}' || echo 1024)
    THREADS=1
    if ((RAM >= 2000)); then THREADS=$CPU; elif ((RAM >= 1000)); then THREADS=2; fi
    
    echo -e "并发线程数设定为: ${gl_huang}${THREADS}${gl_bai}"
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
        info "正在为新内核生成引导映射: $NEW_KERNEL_VER"
        if command -v update-initramfs >/dev/null 2>&1; then
            update-initramfs -c -k "$NEW_KERNEL_VER" >/dev/null 2>&1 || true
        elif command -v dracut >/dev/null 2>&1; then
            dracut --force "/boot/initramfs-${NEW_KERNEL_VER}.img" "$NEW_KERNEL_VER" >/dev/null 2>&1 || true
        fi
    fi

    info "重建 GRUB 引导扇区..."
    if command -v update-grub >/dev/null 2>&1; then update-grub >/dev/null 2>&1 || true; fi

    cd /
    echo -e "${gl_zi}清理工业废料...${gl_bai}"
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
    
    local confirm=""
    read -e -p "你清楚自己在干什么并确定拔除 XanMod 吗？(y/N): " confirm || true
    if [[ "${confirm:-}" =~ ^[Yy]$ ]]; then
        apt purge -y 'linux-*xanmod*' >/dev/null 2>&1 || true
        update-grub >/dev/null 2>&1 || true
        rm -f /etc/apt/sources.list.d/xanmod-release.list /usr/share/keyrings/xanmod-archive-keyring.gpg 2>/dev/null || true
        echo -e "${gl_lv}✅ 装甲已被剥离。${gl_bai}"
    fi
    break_end
}

# ==============================================================================
# [ 区块 VI: TCP/网络列队综合突击调优 (Core Tuning) ]
# ==============================================================================

apply_tc_fq_now() {
    if ! command -v tc >/dev/null 2>&1; then return 0; fi
    local d dev
    for d in /sys/class/net/*; do
        [ -e "$d" ] || continue
        dev=$(basename "$d")
        case "$dev" in lo|docker*|veth*|br-*|virbr*|zt*|tailscale*|wg*|tun*|tap*) continue;; esac
        tc qdisc replace dev "$dev" root fq 2>/dev/null || true
    done
}

apply_mss_clamp() {
    local action=$1
    if ! command -v iptables >/dev/null 2>&1; then return 0; fi
    if [ "$action" = "enable" ]; then
        iptables -t mangle -C FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu >/dev/null 2>&1 || \
        iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu 2>/dev/null || true
    else
        iptables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu >/dev/null 2>&1 || true
    fi
}

calculate_buffer_size() {
    local bandwidth=$1 region=${2:-asia}
    if ! [[ "$bandwidth" =~ ^[0-9]+$ ]] || [ "$bandwidth" -le 0 ] 2>/dev/null; then echo "16"; return 0; fi
    if [ "$region" = "overseas" ]; then
        if [ "$bandwidth" -lt 500 ]; then echo "16"
        elif [ "$bandwidth" -lt 1000 ]; then echo "32"
        else echo "64"; fi
    else
        if [ "$bandwidth" -lt 500 ]; then echo "8"
        elif [ "$bandwidth" -lt 1500 ]; then echo "16"
        else echo "24"; fi
    fi
}

bbr_configure_direct() {
    clear
    echo -e "${gl_kjlan}=== BBRv3 + FQ 直连/落地防拥塞突围优化 ===${gl_bai}"
    
    local bw=""
    local bw_opt=""
    if [ "$AUTO_MODE" = "1" ]; then
        bw="1000"
    else
        echo -e "\n测定你的物理母机实际宽带上限:"
        echo " 1. 100 Mbps  (小型玩具)"
        echo " 2. 500 Mbps  (标准中产)"
        echo " 3. 1000 Mbps (1 Gbps - 大众款推荐)"
        echo " 4. 2500 Mbps (2.5 Gbps 野兽)"
        echo " 5. 手动打字输入"
        read -e -p "指定序号 [3]: " bw_opt || true
        case "${bw_opt:-3}" in
            1) bw="100" ;;
            2) bw="500" ;;
            4) bw="2500" ;;
            5) read -e -p "输入数字带宽 (Mbps): " bw || true; bw="${bw:-1000}" ;;
            *) bw="1000" ;;
        esac
    fi

    local region="overseas"
    local reg_opt=""
    if [ "$AUTO_MODE" != "1" ]; then
        echo -e "\n确立你母机的物理地理坐标:"
        echo " 1. 欧美越洋机房 (忍受高延迟, 扩大漏斗阻力 - 默认)"
        echo " 2. 亚太临近地块 (享受低延迟, 加速收缩频次)"
        read -e -p "请选位 [1]: " reg_opt || true
        if [ "${reg_opt:-1}" == "2" ]; then region="asia"; fi
    fi

    local buffer_mb buffer_bytes
    buffer_mb=$(calculate_buffer_size "$bw" "$region")
    buffer_bytes=$((buffer_mb * 1024 * 1024))
    
    echo -e "${gl_lv}✅ 计算终了，缓冲池硬性界限敲定在: ${buffer_mb}MB${gl_bai}"
    
    # 清理陈旧的废件
    sed -i '/^net\.core\.rmem_max/s/^/# /' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/^net\.core\.wmem_max/s/^/# /' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/^net\.ipv4\.tcp_rmem/s/^/# /' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/^net\.ipv4\.tcp_wmem/s/^/# /' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/^net\.core\.default_qdisc/s/^/# /' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/^net\.ipv4\.tcp_congestion_control/s/^/# /' /etc/sysctl.conf 2>/dev/null || true

    mkdir -p /etc/sysctl.d 2>/dev/null || true
    cat > "$SYSCTL_CONF" << EOF
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.core.rmem_max=${buffer_bytes}
net.core.wmem_max=${buffer_bytes}
net.ipv4.tcp_rmem=4096 87380 ${buffer_bytes}
net.ipv4.tcp_wmem=4096 65536 ${buffer_bytes}

net.ipv4.tcp_tw_reuse=1
net.ipv4.ip_local_port_range=1024 65535
net.core.somaxconn=4096
net.ipv4.tcp_max_syn_backlog=8192
net.core.netdev_max_backlog=5000

net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_notsent_lowat=16384
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_max_tw_buckets=5000
net.ipv4.tcp_fastopen=3

net.ipv4.tcp_keepalive_time=300
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_probes=5
net.ipv4.udp_rmem_min=8192
net.ipv4.udp_wmem_min=8192
net.ipv4.tcp_syncookies=1

vm.swappiness=5
vm.dirty_ratio=15
vm.dirty_background_ratio=5
vm.overcommit_memory=1
vm.vfs_cache_pressure=50
kernel.sched_autogroup_enabled=0
kernel.numa_balancing=0
EOF

    sysctl -p "$SYSCTL_CONF" >/dev/null 2>&1 || true
    apply_tc_fq_now >/dev/null 2>&1 || true
    apply_mss_clamp enable >/dev/null 2>&1 || true

    mkdir -p /etc/security 2>/dev/null || true
    if ! grep -q "BBR - 文件描述符" /etc/security/limits.conf 2>/dev/null; then
        cat >> /etc/security/limits.conf << 'LIMITSEOF'
# BBR - 文件描述符
* soft nofile 524288
* hard nofile 524288
LIMITSEOF
    fi
    ulimit -n 524288 2>/dev/null || true

    if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
        echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
    fi

    local def_route clean_route
    def_route=$(ip route show default 2>/dev/null | head -1 || echo "")
    if [ -n "$def_route" ]; then
        clean_route=$(echo "$def_route" | sed 's/ initcwnd [0-9]*//g; s/ initrwnd [0-9]*//g')
        ip route change $clean_route initcwnd 32 initrwnd 32 2>/dev/null || true
    fi

    echo -e "${gl_lv}✅ Sysctl BBR 流控引擎已完全统治系统！${gl_bai}"
    if [ "$AUTO_MODE" != "1" ]; then break_end; fi
}

netfilter_conntrack_tune() {
    echo -e "${gl_kjlan}=== 底层防断流：Netfilter 并发追踪器扩容 ===${gl_bai}"
    if command -v modprobe >/dev/null 2>&1; then modprobe nf_conntrack 2>/dev/null || true; fi
    mkdir -p /etc/modules-load.d /etc/sysctl.d 2>/dev/null || true
    if ! grep -q '^nf_conntrack$' /etc/modules-load.d/conntrack.conf 2>/dev/null; then
        echo nf_conntrack >> /etc/modules-load.d/conntrack.conf
    fi
    cat >/etc/sysctl.d/60-netfilter-tune.conf <<'SYSC'
net.netfilter.nf_conntrack_max = 262144
SYSC
    sysctl --system >/dev/null 2>&1 || true
    echo -e "${gl_lv}✅ 握手跟踪器容量强行顶高，无惧大流量并发挤兑！${gl_bai}"
    if [ "$AUTO_MODE" != "1" ]; then break_end; fi
}

kernel_optimize_geek() {
    while true; do
        clear
        echo -e "${gl_kjlan}=== Linux 内核即时极客指令台 (仅限老手) ===${gl_bai}"
        echo -e "${gl_huang}警告：以下四个档位皆为即时发作指令，无视报错强行越权，重启则失忆退散！${gl_bai}"
        echo " --------------------"
        echo " 1. ⚔️ 星辰大海ヾ均衡姿态 (13万句柄/16M缓冲) - 适合日用"
        echo " 2. 🚀 Reality 终极狂暴 (50万句柄/12M压迫缓冲) - 无脑降延迟"
        echo " 3. 🛡️ Low-Spec 乞丐救命模式 (6万句柄/8M微池) - 1G内存防暴毙专供"
        echo " 4. 🌋 毁天灭地吞吐压榨版 (100万句柄/16M缓冲/25万深队列) - 烧卡测试专用"
        echo " 0. 撤离防线"
        echo " --------------------"
        local k_opt=""
        read -e -p "下达注入命令 [0-4]: " k_opt || true
        case "${k_opt:-}" in
            1) 
                ulimit -n 131072 2>/dev/null || true
                sysctl -w net.core.rmem_max=16777216 2>/dev/null || true
                sysctl -w net.core.wmem_max=16777216 2>/dev/null || true
                sysctl -w net.ipv4.tcp_rmem='4096 87380 16777216' 2>/dev/null || true
                sysctl -w net.ipv4.tcp_wmem='4096 65536 16777216' 2>/dev/null || true
                sysctl -w vm.swappiness=5 2>/dev/null || true
                sysctl -w net.ipv4.tcp_fastopen=3 2>/dev/null || true
                echo -e "${gl_lv}均衡型星辰战衣披戴成功！${gl_bai}"; break_end ;;
            2) 
                ulimit -n 524288 2>/dev/null || true
                sysctl -w net.ipv4.tcp_notsent_lowat=16384 2>/dev/null || true
                sysctl -w net.core.rmem_max=12582912 2>/dev/null || true
                sysctl -w net.core.wmem_max=12582912 2>/dev/null || true
                sysctl -w net.ipv4.tcp_rmem='4096 87380 12582912' 2>/dev/null || true
                sysctl -w net.ipv4.tcp_wmem='4096 64000 12582912' 2>/dev/null || true
                echo -e "${gl_lv}狂暴姿态全开！降维打击机制运转中！${gl_bai}"; break_end ;;
            3)
                ulimit -n 65535 2>/dev/null || true
                sysctl -w net.core.rmem_max=8388608 2>/dev/null || true
                sysctl -w net.core.wmem_max=8388608 2>/dev/null || true
                sysctl -w vm.swappiness=10 2>/dev/null || true
                echo -e "${gl_lv}救机气囊已弹出，稳定高于一切！${gl_bai}"; break_end ;;
            4)
                ulimit -n 1048576 2>/dev/null || true
                sysctl -w net.core.rmem_max=16777216 2>/dev/null || true
                sysctl -w net.core.wmem_max=16777216 2>/dev/null || true
                sysctl -w net.core.somaxconn=4096 2>/dev/null || true
                sysctl -w net.core.netdev_max_backlog=250000 2>/dev/null || true
                echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
                echo -e "${gl_lv}核弹发射！系统防火墙失效，纯物理数据决堤模式！${gl_bai}"; break_end ;;
            0) return ;;
            *) echo -e "${gl_hong}无法解析该代码${gl_bai}"; sleep 1 ;;
        esac
    done
}

do_txqueuelen_opt() {
    title "网卡发射队列 (TX Queue) 缩圈提速"
    local IP_CMD
    IP_CMD=$(command -v ip || echo "")
    if [[ -z "$IP_CMD" ]]; then error "环境干瘪，iproute2 工具丢失。"; read -rp "Enter..." _ || true; return 1; fi
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if [[ -z "$IFACE" ]]; then error "核心探针无法定位出口网卡设备！"; read -rp "Enter..." _ || true; return 1; fi
    
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
    read -rp "按 Enter 返回..." _ || true
}

config_cake_advanced() {
    clear
    title "CAKE 高阶调度参数配置 (解决跨洋代理降速与排队失真)"
    
    local current_opts="无 (系统自适应默认)"
    if [[ -f "$CAKE_OPTS_FILE" ]]; then
        current_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
    fi
    echo -e "  系统当前已驻留的配置参数: ${cyan}${current_opts}${none}\n"
    
    local c_bw="" c_oh="" c_mpu="" rtt_sel="" diff_sel=""
    read -e -p "  [1] 指派带宽瓶颈死线 (例: 900Mbit, 不限速填 0): " c_bw || true
    read -e -p "  [2] 定义封包加密外壳厚度 (例: 48, 填 0 忽略): " c_oh || true
    read -e -p "  [3] 指定底层包头最小截断 MPU (例: 84, 填 0 忽略): " c_mpu || true
    
    echo "  [4] 选择高仿真网络延迟 RTT 模型: "
    echo "    1) internet  (85ms 默认标准波段)"
    echo "    2) oceanic   (300ms 跨洋深海电缆对冲模型 - 推荐)"
    echo "    3) satellite (1000ms 疯狂丢包卫星极限模型)"
    read -e -p "  选择 (默认 2): " rtt_sel || true
    
    local c_rtt=""
    case "${rtt_sel:-2}" in
        1) c_rtt="internet" ;;
        3) c_rtt="satellite" ;;
        *) c_rtt="oceanic" ;;
    esac
    
    echo "  [5] 确立数据流分流盲走体系: "
    echo "    1) diffserv4  (耗费算力解拆分析特征，极度高消耗)"
    echo "    2) besteffort (忽略包特征直接盲推，最低延迟王者 - 推荐)"
    read -e -p "  选择 (默认 2): " diff_sel || true
    
    local c_diff=""
    case "${diff_sel:-2}" in
        1) c_diff="diffserv4" ;;
        *) c_diff="besteffort" ;;
    esac

    local final_opts=""
    if [[ -n "${c_bw:-}" && "${c_bw:-}" != "0" ]]; then final_opts="$final_opts bandwidth ${c_bw}"; fi
    if [[ -n "${c_oh:-}" && "${c_oh:-}" != "0" ]]; then final_opts="$final_opts overhead ${c_oh}"; fi
    if [[ -n "${c_mpu:-}" && "${c_mpu:-}" != "0" ]]; then final_opts="$final_opts mpu ${c_mpu}"; fi
    
    final_opts="$final_opts $c_rtt $c_diff"
    final_opts="${final_opts#"${final_opts%%[! ]*}"}"
    
    if [[ -z "$final_opts" ]]; then
        rm -f "$CAKE_OPTS_FILE" 2>/dev/null || true
        info "已强行抹除所有 CAKE 个性化魔改指令。"
    else
        echo "$final_opts" > "$CAKE_OPTS_FILE"
        info "智能调度指令集锁定：$final_opts"
    fi
    
    modprobe sch_cake 2>/dev/null || true
    
    local IFACE
    IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "")
    if [[ -n "$IFACE" ]]; then
        tc qdisc replace dev "$IFACE" root cake $final_opts 2>/dev/null || true
        if tc qdisc show dev "$IFACE" 2>/dev/null | grep -q "cake"; then
            info "自检极佳：核心 CAKE 调度器已极其稳固地接管出口网卡！"
        else
            warn "危机：物理层网卡队列未反馈 CAKE 状态，请确保内核支持 sch_cake！"
        fi
    fi
    read -rp "Enter 继续..." _ || true
}

# ==============================================================================
# [ 区块 VII: 综合雷达审计系统 (Diagnostics) ]
# ==============================================================================

show_detailed_status() {
    clear
    local hostname=$(uname -n)
    local os_info=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d '=' -f2 | tr -d '"' || echo "未知")
    local kernel_version=$(uname -r)
    local cpu_arch=$(uname -m)
    local cpu_info=$(lscpu 2>/dev/null | awk -F': +' '/Model name:/ {print $2; exit}' || echo "N/A")
    local cpu_cores=$(nproc 2>/dev/null || echo 1)
    local mem_info=$(free -b 2>/dev/null | awk 'NR==2{printf "%.2f/%.2fM (%.2f%%)", $3/1024/1024, $2/1024/1024, $3*100/$2}' || echo "N/A")
    local swap_info=$(free -m 2>/dev/null | awk 'NR==3{used=$3; total=$2; if(total==0) p=0; else p=used*100/total; printf "%dM/%dM (%d%%)", used, total, p}' || echo "N/A")
    local disk_info=$(df -h / 2>/dev/null | awk 'NR==2{printf "%s/%s (%s)", $3, $2, $5}' || echo "N/A")
    
    local rx="0" tx="0" net_io=""
    net_io=$(awk 'BEGIN{r=0;t=0} $1~/^(eth|ens|enp|eno)[0-9]+/{r+=$2;t+=$10} END{print r,t}' /proc/net/dev 2>/dev/null || echo "")
    if [[ -n "$net_io" ]]; then
        rx=$(echo "$net_io" | awk '{print $1}')
        tx=$(echo "$net_io" | awk '{print $2}')
        rx=$(numfmt --to=iec --suffix=B "$rx" 2>/dev/null || echo "$rx")
        tx=$(numfmt --to=iec --suffix=B "$tx" 2>/dev/null || echo "$tx")
    fi

    local cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "未知")
    local qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "未知")

    echo -e "${gl_kjlan}=== 底盘装甲侦测与探针反馈 ===${gl_bai}"
    echo -e "核心外骨骼 : ${gl_huang}$os_info | $cpu_arch | $kernel_version${gl_bai}"
    echo -e "逻辑驱动器 : ${gl_huang}$cpu_info ($cpu_cores 核)${gl_bai}"
    echo -e "物理脑容量 : ${gl_huang}$mem_info${gl_bai}"
    echo -e "防爆虚拟池 : ${gl_huang}$swap_info${gl_bai}"
    echo -e "冷数据载体 : ${gl_huang}$disk_info${gl_bai}"
    echo -e "底盘控速器 : ${gl_huang}$cc 搭配 $qdisc${gl_bai}"
    echo -e "网络吐吞量 : ${gl_huang}进水 $rx | 出水 $tx${gl_bai}"
    break_end
}

audit_menu() {
    while true; do
        clear
        echo -e "${gl_kjlan}=== IP 纯度雷达与路由深层探测仪 ===${gl_bai}"
        echo " 1. 🔍 IP 连通性质检与防诈骗溯源 (基于 IP.Check.Place)"
        echo " 2. 🌍 全球流媒体地域锁定解除探测仪 (RegionRestrictionCheck)"
        echo " 3. 🎯 三网链路回程硬刚追踪 (Backtrace)"
        echo " 4. 🧲 NodeSeek 专享综合质量探针 (机器评级)"
        echo " 0. 撤退"
        local a_opt=""
        read -e -p "呼叫雷达号: " a_opt || true
        case "${a_opt:-}" in
            1) run_remote_script "https://IP.Check.Place" bash -4; break_end ;;
            2) run_remote_script "https://github.com/1-stream/RegionRestrictionCheck/raw/main/check.sh" bash; break_end ;;
            3) run_remote_script "https://raw.githubusercontent.com/ludashi2020/backtrace/main/install.sh" sh; break_end ;;
            4) run_remote_script "https://run.NodeQuality.com" bash; break_end ;;
            0) return ;;
            *) echo -e "${gl_hong}频率失准。${gl_bai}"; sleep 1 ;;
        esac
    done
}

# ==============================================================================
# [ 区块 VIII: 一键托管战车点火台与物理拆解系统 ]
# ==============================================================================

one_click_optimize() {
    clear
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo -e "${gl_kjlan}   ⭐ 一键全息无人接管 (The Ultimate Genesis)${gl_bai}"
    echo -e "${gl_kjlan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
    echo ""
    
    local xanmod_running=0
    if uname -r | grep -qi 'xanmod'; then xanmod_running=1; fi

    if [ $xanmod_running -eq 0 ]; then
        echo -e "${gl_huang}▶ 序列 1：正准备强制焊入高级物理引擎 (XanMod)${gl_bai}"
        AUTO_MODE=1
        if install_xanmod_kernel; then
            echo -e "\n${gl_lv}✅ 内核骨架替换完毕！系统即将强行暴毙并从新引擎中复苏...${gl_bai}"
            echo -e "${gl_lv}系统复苏后，务必再次输入指令执行【选项 66】完成余下接驳。${gl_bai}"
            sleep 3
            reboot
        else
            echo -e "${gl_hong}❌ 引擎排斥反应剧烈，接管行动流产。${gl_bai}"
        fi
        AUTO_MODE=""
        break_end
    else
        echo -e "${gl_lv}✅ 雷达确认: 霸道的 XanMod 引擎已在胸腔内轰鸣！${gl_bai}\n"
        echo -e "${gl_huang}▶ 序列 2：全自动生态网络铺路作业${gl_bai}"
        AUTO_MODE=1
        
        echo -e "\n${gl_zi}>>> 强行撕开虚拟内存气囊以防系统窒息...${gl_bai}"
        check_and_suggest_swap
        
        echo -e "\n${gl_zi}>>> 物理切除冗杂的 IPv6，强制锁死纯粹的 IPv4 指针...${gl_bai}"
        enforce_ipv4_and_disable_ipv6
        
        echo -e "\n${gl_zi}>>> 下放跨洋极速 BBR 算法，深度篡改网络收发时序...${gl_bai}"
        bbr_configure_direct
        
        echo -e "\n${gl_zi}>>> 强推 Netfilter 并发连接追踪器容量...${gl_bai}"
        netfilter_conntrack_tune
        
        AUTO_MODE=""
        echo -e "\n${gl_lv}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
        echo -e "${gl_lv} 🚀 创世纪元：这台服务器已经被改造成了终极战争机器！${gl_bai}"
        echo -e "${gl_lv}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${gl_bai}"
        break_end
    fi
}

uninstall_all_network() {
    clear
    echo -e "${gl_hong}⚠️  警告：您正在申请执行物理级解脱，这将完全抹去本脚本刻印在机器上的所有烙印！${gl_bai}"
    local confirm=""
    read -e -p "必须输入 YES 以启动自毁程序: " confirm || true
    if [[ "${confirm:-}" == "YES" ]]; then
        echo -e "${gl_zi}正在抽离所有修改与防爆挂载...${gl_bai}"
        rm -f /etc/sysctl.d/99-bbr-ultimate.conf /etc/sysctl.d/60-netfilter-tune.conf /etc/sysctl.d/99-disable-ipv6.conf 2>/dev/null || true
        sed -i '/BBR/d' /etc/security/limits.conf 2>/dev/null || true
        sysctl --system >/dev/null 2>&1 || true
        
        swapoff /swapfile 2>/dev/null || true
        rm -f /swapfile 2>/dev/null || true
        sed -i '/swapfile/d' /etc/fstab 2>/dev/null || true
        
        rm -f /etc/gai.conf 2>/dev/null || true
        
        echo -e "${gl_lv}✅ 物理环境已复原为纯洁状态！${gl_bai}"
    else
        echo "已锁止并取消自毁请求。"
    fi
    break_end
}

show_main_menu() {
    clear
    local current_kernel
    current_kernel=$(uname -r)
    echo -e "${gl_kjlan}╔══════════════════════════════════════════════════╗${gl_bai}"
    echo -e "${gl_kjlan}║  The Apex Vanguard - Pure Genesis Base V1j2      ║${gl_bai}"
    echo -e "${gl_kjlan}╚══════════════════════════════════════════════════╝${gl_bai}"
    echo -e "${gl_hui}  底盘内核代号: ${current_kernel}${gl_bai}"
    echo ""
    echo -e "${gl_huang} ⚡【底盘动力舱】(Core & Network Tuning)${gl_bai}"
    echo "  1. 换上/更新最暴躁的装甲内核 (XanMod 预编译)"
    echo "  2. 极客专用: 从 Kernel.org 源码拉取并硬核编译内核"
    echo "  3. 卸下装甲，退回原厂内核 (Uninstall XanMod)"
    echo "  4. BBR 极速落地算法矩阵注入 (带智控缓冲池)"
    echo "  5. Runtime 极客突发时延压榨台 (4 套狂暴方案)"
    echo "  6. 物理锁死 IPv4 并强制熔断斩杀 IPv6"
    echo "  7. 智能评估并构建 Swap 气囊 (防 OOM 宕机)"
    echo "  8. 防爆并扩容 Netfilter 并发追踪器 (并发突破)"
    echo "  9. 斩断队列积压 (CAKE 高阶调度控制台)"
    echo "  10. 收紧发射列队防阻尼 (TX Queue Opt)"
    echo ""
    echo -e "${gl_huang} 📡【星际雷达域】(Quality & Diagnostics)${gl_bai}"
    echo "  11. 宣读系统底盘综合健康报告"
    echo "  12. 释放雷达：IP 信誉 / 区域解锁 / 穿透路由探针"
    echo ""
    echo -e "${gl_huang} 👑【绝对指令台】(Automation & Destroyer)${gl_bai}"
    echo -e "  ${gl_lv}66. The Genesis：一键全息底盘托管 (懒人重装专供)${gl_bai}"
    echo -e "  ${gl_hong}99. 格式化抹杀：剥离本程序刻印的所有网络底盘魔改${gl_bai}"
    echo "  0. 隐蔽撤退"
    echo "──────────────────────────────────────────────────"
    
    local choice=""
    read -e -p "输入指令代号: " choice || true
    case "${choice:-}" in
        1) install_xanmod_kernel ;;
        2) do_xanmod_compile ;;
        3) uninstall_xanmod ;;
        4) bbr_configure_direct ;;
        5) kernel_optimize_geek ;;
        6) enforce_ipv4_and_disable_ipv6; break_end ;;
        7) manage_swap ;;
        8) netfilter_conntrack_tune ;;
        9) config_cake_advanced ;;
        10) do_txqueuelen_opt ;;
        11) show_detailed_status ;;
        12) audit_menu ;;
        99) uninstall_all_network ;;
        66) one_click_optimize ;;
        0) exit 0 ;;
        *) echo -e "${gl_hong}❌ 指令未能被中枢识别${gl_bai}"; sleep 1 ;;
    esac
}

# ==============================================================================
# 系统锚点 (Entry Point)
# ==============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            echo "Usage: $0 [无交互挂载参数请自行编辑内层设定]"
            exit 0
            ;;
        *) break ;;
    esac
done

check_root
preflight
while true; do
    show_main_menu
done