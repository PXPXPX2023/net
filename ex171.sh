#!/usr/bin/env bash
# ████████╗██╗  ██╗███████╗    █████╗ ██████╗ ███████╗██╗  ██╗
# ╚══██╔══╝██║  ██║██╔════╝    ██╔══██╗██╔══██╗██╔════╝╚██╗██╔╝
#    ██║   ███████║█████╗      ███████║██████╔╝█████╗   ╚███╔╝ 
#    ██║   ██╔══██║██╔══╝      ██╔══██║██╔═══╝ ██╔══╝   ██╔██╗ 
#    ██║   ██║  ██║███████╗    ██║  ██║██║     ███████╗██╔╝ ██╗
#    ╚═╝   ╚═╝  ╚═╝╚══════╝    ╚═╝  ╚═╝╚═╝     ╚══════╝╚═╝  ╚═╝
# ==============================================================================
# 脚本名称: ex171.sh (The Apex Vanguard - Project Genesis V171 [Absolute Horizon])
# 快捷方式: xrv
# ==============================================================================
# 终极溯源重铸宣言 (绝对防截断、全量展开、自检闭环、绝对持久化版): 
#   1. 时序绝杀：将所有 hw-tweaks 服务的挂载点强制升级为 network-online.target，彻底粉碎现代 Linux 快启动导致的网卡探针空转，确保 CAKE/RPS 物理重启后 100% 命中。
#   2. 绝对路径锚定：为开机底盘注入全局 PATH 环境变量，免疫极其简陋的 OS 模版下 ethtool/tc 指令未入环境导致的静默执行失败。
#   3. 状态机绝杀：物理锚点池 (/etc/xray/flags) 深度护航 ack-filter/ecn/wash，跨越重启与重载，实现真正的绝对持久化。
#   4. 卸载防爆：补全状态机中的 jq 原子化容错 (.sniffing // {})，免疫因用户手动删减 JSON 节点导致的一键关闭爆破。
#   5. 拯救多用户：彻底修正 jq 传参丢失的 Bug (采用 "$@" 和 --argjson)，全面恢复增删改查与独立 SNI 绑定能力。
#   6. 编译防砖：坚守 Kernel 主线拉取、继承宿主驱动配置、强制 update-initramfs 生成镜像、绝对保留旧内核退路。
# ==============================================================================

# ==============================================================================
# [ 00. 基础环境、内核与安全防线严格校验 ]
# ==============================================================================
if test -z "$BASH_VERSION"; then
    echo "======================================================================"
    echo " 致命错误: 本脚本采用了大量高级 Bash 独有特性、数组遍历与管道流机制。"
    echo " 请严格使用 bash 运行本脚本，命令格式: bash ex171.sh"
    echo "======================================================================"
    exit 1
fi

if test "$EUID" -ne 0; then 
    echo -e "\033[31m======================================================================\033[0m"
    echo -e "\033[31m 致命错误: 您的权限层级不足！\033[0m"
    echo -e "\033[31m 本脚本将深度干预 Linux 内核网络栈、CPU 调度、网卡固件与系统底层限制。\033[0m"
    echo -e "\033[31m 请务必切换至 root 账户 (执行 sudo -i) 后再次运行！\033[0m"
    echo -e "\033[31m======================================================================\033[0m"
    exit 1
fi

if ! command -v systemctl >/dev/null 2>&1; then 
    echo -e "\033[31m======================================================================\033[0m"
    echo -e "\033[31m 致命架构错误: 无法探测到 systemd 守护系统！\033[0m"
    echo -e "\033[31m 当前宿主机可能使用了精简版容器 (如 LXC/OpenVZ 弱化版) 或老旧架构。\033[0m"
    echo -e "\033[31m 为了保证核心服务的稳定存活与开机自启，本战车仅支持标准的 Systemd 生态环境。\033[0m"
    echo -e "\033[31m======================================================================\033[0m"
    exit 1
fi

# ==============================================================================
# [ 01. 终端工业级色彩与 UI 占位符定义 ]
# ==============================================================================
red='\033[31m'
yellow='\033[33m'
gray='\033[90m'
green='\033[92m'
blue='\033[94m'
magenta='\033[95m'
cyan='\033[96m'
none='\033[0m'

print_red()     { echo -e "${red}$*${none}"; }
print_green()   { echo -e "${green}$*${none}"; }
print_yellow()  { echo -e "${yellow}$*${none}"; }
print_magenta() { echo -e "${magenta}$*${none}"; }
print_cyan()    { echo -e "${cyan}$*${none}"; }

info()  { echo -e "${green}[系统反馈] ✓${none} $*"; }
warn()  { echo -e "${yellow}[安全预警] !${none} $*"; }
error() { echo -e "${red}[内核熔断] ✗${none} $*"; }

die() { 
    echo -e "\n${red}================== [极度致命故障引发系统大熔断] ==================${none}"
    echo -e "${red}$*${none}"
    echo -e "${red}====================================================================${none}\n"
    exit 1
}

title() {
    echo -e "\n${blue}======================================================================${none}"
    echo -e "  ${cyan}>>> $* <<<${none}"
    echo -e "${blue}======================================================================${none}"
}

hr() {
    echo -e "${gray}----------------------------------------------------------------------${none}"
}

# ==============================================================================
# [ 02. 全局核心物理路径与运行态结构变量注册 ]
# ==============================================================================
XRAY_BIN="/usr/local/bin/xray"
CONFIG_DIR="/usr/local/etc/xray"
CONFIG="$CONFIG_DIR/config.json"
CONFIG_BACKUP="$CONFIG_DIR/config.json.bak"
PUBKEY_FILE="$CONFIG_DIR/public.key"
SNI_CACHE_FILE="$CONFIG_DIR/sni_cache.txt"
INSTALL_DATE_FILE="$CONFIG_DIR/install_date.txt"
USER_SNI_MAP="$CONFIG_DIR/user_sni.txt"
USER_TIME_MAP="$CONFIG_DIR/user_time.txt"
CAKE_OPTS_FILE="$CONFIG_DIR/cake_opts.txt"
FLAGS_DIR="$CONFIG_DIR/flags"
DAT_DIR="/usr/local/share/xray"
SCRIPT_DIR="/usr/local/etc/xray-script"
UPDATE_DAT_SCRIPT="$SCRIPT_DIR/update-dat.sh"
SYMLINK="/usr/local/bin/xrv"
SCRIPT_PATH=$(readlink -f "$0")

GLOBAL_IP=""
SERVER_IP=""
REMARK_NAME="xp-reality"
BEST_SNI="www.microsoft.com"
SNI_JSON_ARRAY="\"www.microsoft.com\""
LISTEN_PORT=443

# ==============================================================================
# [ 03. 核心目录树拓扑构建与物理基石初始化 ]
# ==============================================================================
mkdir -p "$CONFIG_DIR" 2>/dev/null
mkdir -p "$DAT_DIR" 2>/dev/null
mkdir -p "$SCRIPT_DIR" 2>/dev/null
mkdir -p "$FLAGS_DIR" 2>/dev/null
touch "$USER_SNI_MAP"
touch "$USER_TIME_MAP"

# ==============================================================================
# [ 04. 权限与安全物理锁定机制 ]
# ==============================================================================
fix_permissions() {
    if test -f "$CONFIG"; then
        chmod 644 "$CONFIG" >/dev/null 2>&1
    fi
    if test -d "$CONFIG_DIR"; then
        chmod 755 "$CONFIG_DIR" >/dev/null 2>&1
    fi
    chown root:root "$CONFIG" >/dev/null 2>&1 || true
    chown -R root:root "$CONFIG_DIR" >/dev/null 2>&1 || true
}

# ==============================================================================
# [ 05. 动态探针：异地独立 IP 获取与容灾重试流 ]
# ==============================================================================
_get_ip() {
    if [ -z "$GLOBAL_IP" ]; then
        GLOBAL_IP=$(curl -s -4 --connect-timeout 5 https://api.ipify.org 2>/dev/null)
        if [ -z "$GLOBAL_IP" ]; then
            GLOBAL_IP=$(curl -s -4 --connect-timeout 5 https://ifconfig.me 2>/dev/null)
        fi
        if [ -z "$GLOBAL_IP" ]; then
            GLOBAL_IP="未知_网络连接异常"
        fi
    fi
    echo "$GLOBAL_IP" | tr -d '\r\n'
}

# ==============================================================================
# [ 06. 极其严密的 JSON 事务级安全读写引擎 (带备份、测试、回滚闭环) ]
# ==============================================================================
backup_system_state() {
    if test -f "$CONFIG"; then
        \cp -f "$CONFIG" "$CONFIG_BACKUP" >/dev/null 2>&1
    fi
}

restore_system_state() {
    if test -f "$CONFIG_BACKUP"; then
        \cp -f "$CONFIG_BACKUP" "$CONFIG" >/dev/null 2>&1
        fix_permissions
        systemctl restart xray >/dev/null 2>&1
        warn "已物理回滚至上一个安全的配置快照！"
    else
        error "严重事故：未能找到安全备份点，系统可能陷入瘫痪！"
    fi
}

verify_xray_config() {
    local target_config="$1"
    if [ ! -f "$XRAY_BIN" ]; then
        warn "Xray 核心尚未安装，跳过配置语法核验。"
        return 0
    fi
    
    local test_result
    test_result=$("$XRAY_BIN" -test -config "$target_config" 2>&1)
    
    if echo "$test_result" | grep -qi "Configuration OK"; then
        return 0
    else
        error "JSON 结构崩溃！Xray 引擎拒绝接纳此格式："
        echo -e "${gray}$test_result${none}"
        return 1
    fi
}

_safe_jq_write() {
    backup_system_state
    local tmp=$(mktemp)
    
    # 完美接收所有参数 (包含 --arg, --argjson 等)
    if jq "$@" "$CONFIG" > "$tmp" 2>/dev/null; then
        if verify_xray_config "$tmp"; then
            mv "$tmp" "$CONFIG" >/dev/null 2>&1
            fix_permissions
            return 0
        else
            error "逻辑被截断：新的配置结构不符合 Xray 语法规范，拒绝覆盖物理文件！"
            rm -f "$tmp" >/dev/null 2>&1
            restore_system_state
            return 1
        fi
    else
        error "JQ 引擎解析管道流发生严重碎裂，执行中止！"
        rm -f "$tmp" >/dev/null 2>&1
        restore_system_state
        return 1
    fi
}

# 存活强制雷达
restart_and_verify_xray() {
    print_magenta ">>> 正在向底层下发 Xray 服务热重载指令..."
    systemctl restart xray >/dev/null 2>&1
    sleep 3
    
    if systemctl is-active --quiet xray; then
        info "Xray 引擎生命体征平稳，配置已成功映射入内存。"
        return 0
    else
        error "Xray 启动遭遇滑铁卢，进程已当场暴毙！"
        print_yellow ">>> 提取最后 15 行系统死亡日志："
        hr
        journalctl -u xray.service --no-pager -n 15 | awk '{print "    " $0}'
        hr
        print_red ">>> 判定：配置结构存在致命语法畸变或端口大碰撞！"
        print_magenta ">>> 正在启动安全回滚机制..."
        restore_system_state
        read -rp "请敲击 Enter 键面对失败并退回主阵地..." _
        return 1
    fi
}

# ==============================================================================
# [ 07. 百万并发 Systemd 内核调度限流器 (Limits.conf) ]
# ==============================================================================
fix_xray_systemd_limits() {
    local override_dir="/etc/systemd/system/xray.service.d"
    mkdir -p "$override_dir" 2>/dev/null
    local limit_file="$override_dir/limits.conf"
    
    local current_nice="-20"
    local current_gogc="100"
    local current_oom="true"
    local current_affinity=""
    local current_gomaxprocs=""
    local current_buffer=""

    if [ -f "$limit_file" ]; then
        if grep -q "^Nice=" "$limit_file"; then
            current_nice=$(awk -F'=' '/^Nice=/ {print $2}' "$limit_file" | head -1)
        fi
        if grep -q "^Environment=\"GOGC=" "$limit_file"; then
            current_gogc=$(awk -F'=' '/^Environment="GOGC=/ {print $3}' "$limit_file" | tr -d '"' | head -1)
        fi
        if ! grep -q "^OOMScoreAdjust=" "$limit_file"; then
            current_oom="false"
        fi
        if grep -q "^CPUAffinity=" "$limit_file"; then
            current_affinity=$(awk -F'=' '/^CPUAffinity=/ {print $2}' "$limit_file" | head -1)
        fi
        if grep -q "^Environment=\"GOMAXPROCS=" "$limit_file"; then
            current_gomaxprocs=$(awk -F'=' '/^Environment="GOMAXPROCS=/ {print $3}' "$limit_file" | tr -d '"' | head -1)
        fi
        if grep -q "^Environment=\"XRAY_RAY_BUFFER_SIZE=" "$limit_file"; then
            current_buffer=$(awk -F'=' '/^Environment="XRAY_RAY_BUFFER_SIZE=/ {print $3}' "$limit_file" | tr -d '"' | head -1)
        fi
    fi

    local TOTAL_MEM=$(free -m | awk '/Mem/{print $2}')
    local GO_MEM_LIMIT=$(( TOTAL_MEM * 85 / 100 ))

    cat > "$limit_file" << EOF
[Service]
LimitNOFILE=1048576
LimitNPROC=512000
LimitMEMLOCK=infinity
Nice=${current_nice}
Environment="GOMEMLIMIT=${GO_MEM_LIMIT}MiB"
Environment="GOGC=${current_gogc}"
EOF

    if [ "$current_oom" = "true" ]; then
        echo "OOMScoreAdjust=-500" >> "$limit_file"
        echo "IOSchedulingClass=realtime" >> "$limit_file"
        echo "IOSchedulingPriority=2" >> "$limit_file"
    fi
    
    if [ -n "$current_affinity" ]; then
        echo "CPUAffinity=$current_affinity" >> "$limit_file"
    fi
    
    if [ -n "$current_gomaxprocs" ]; then
        echo "Environment=\"GOMAXPROCS=$current_gomaxprocs\"" >> "$limit_file"
    fi
    
    if [ -n "$current_buffer" ]; then
        echo "Environment=\"XRAY_RAY_BUFFER_SIZE=$current_buffer\"" >> "$limit_file"
    fi

    systemctl daemon-reload >/dev/null 2>&1
}

# ==============================================================================
# [ 08. 物理 1GB Swap 信仰卫士 ]
# ==============================================================================
check_and_create_1gb_swap() {
    title "内存护航：1GB 永久 Swap 基线校验"
    local SWAP_FILE="/swapfile"
    local TARGET_SIZE_KB=1048576
    
    local CURRENT_SWAP=$(swapon --show=NAME,KBYTES --noheadings 2>/dev/null | grep "$SWAP_FILE" | awk '{print $2}')
    
    if [[ -n "$CURRENT_SWAP" ]] && [[ "$CURRENT_SWAP" -ge 1000000 ]]; then
        info "检测到已存在合规的 1GB 级永久 Swap，验证通过。"
    else
        warn "Swap 缺失或容量不符，正在重构 1GB 永久交换分区..."
        swapoff -a 2>/dev/null || true
        sed -i '/swapfile/d' /etc/fstab
        rm -f "$SWAP_FILE"
        
        # 使用 dd 保证物理块连续性
        dd if=/dev/zero of="$SWAP_FILE" bs=1M count=1024 status=progress
        chmod 600 "$SWAP_FILE"
        mkswap "$SWAP_FILE" >/dev/null 2>&1
        swapon "$SWAP_FILE" >/dev/null 2>&1
        
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
        info "1GB 永久 Swap 创建并挂载完毕。"
    fi
}

# ==============================================================================
# [ 09. 环境预检与依赖对齐 ]
# ==============================================================================
preflight() {
    local need="jq curl wget xxd unzip qrencode vnstat cron openssl coreutils sed e2fsprogs pkg-config iproute2 ethtool bc bison flex"
    local install_list=""
    
    for i in $need; do
        if ! command -v "$i" >/dev/null 2>&1; then
            install_list="$install_list $i"
        fi
    done

    if [ -n "$install_list" ]; then
        info "同步缺失依赖: $install_list"
        export DEBIAN_FRONTEND=noninteractive
        (apt-get update -y || yum makecache -y) >/dev/null 2>&1
        (apt-get install -y $install_list || yum install -y $install_list) >/dev/null 2>&1
        
        systemctl start vnstat >/dev/null 2>&1 || true
        systemctl enable cron >/dev/null 2>&1 || true
        systemctl start cron >/dev/null 2>&1 || true
    fi

    # 快捷指令同步
    if [ -f "$SCRIPT_PATH" ]; then
        \cp -f "$SCRIPT_PATH" "$SYMLINK"
        chmod +x "$SYMLINK"
        hash -r 2>/dev/null
    fi
    
    SERVER_IP=$(_get_ip)
}

# ==============================================================================
# (第一部分结束，请立刻发送“继续输出”拉取下一段核心代码)
# ==============================================================================
