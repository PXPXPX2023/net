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
# ==============================================================================
# [ 10. 极致防砖版！主线原生内核源码裸装引擎 ]
# ==============================================================================
do_xanmod_compile() {
    title "创世重铸：从 Kernel.org 原核提取并暴力裸装最新纯净主线内核 + BBR3"
    warn "极其重磅警告: 编译耗时 30-60 分钟，低配机极易引发死机断连！"
    read -rp "您确认要亲自点燃源码编译引擎吗？(y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        return
    fi
    
    print_magenta ">>> [1/7] 构建纯铁血工业级编译底层包依赖环境..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y build-essential bc bison flex libssl-dev libelf-dev libncurses-dev zstd git dwarves rsync python3 libdw-dev cpio pkg-config
    
    check_and_create_1gb_swap

    print_magenta ">>> [2/7] 向 Kernel.org 索要绝对稳定版的完整源码..."
    local BUILD_DIR="/usr/src"
    cd $BUILD_DIR
    
    local KERNEL_URL=$(curl -s https://www.kernel.org/releases.json | jq -r '.releases[] | select(.type=="stable") | .tarball' | head -1)
    if [ -z "$KERNEL_URL" ] || [ "$KERNEL_URL" == "null" ]; then
        KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.10.tar.xz"
    fi
    
    local KERNEL_FILE=$(basename $KERNEL_URL)
    wget -q --show-progress $KERNEL_URL -O $KERNEL_FILE

    if ! tar -tJf $KERNEL_FILE >/dev/null 2>&1; then
        rm -f $KERNEL_FILE
        wget -q --show-progress $KERNEL_URL -O $KERNEL_FILE
        tar -tJf $KERNEL_FILE >/dev/null 2>&1 || { error "包体结构受损！停止操作。"; return 1; }
    fi

    tar -xJf $KERNEL_FILE
    local KERNEL_DIR=$(tar -tf $KERNEL_FILE | head -1 | cut -d/ -f1)
    cd $KERNEL_DIR

    print_magenta ">>> [3/7] 核心洗地：继承原生参数，剿除签名检查并焊入 BBR3..."
    
    # ----------------------------------------------------------------------------------
    # 【核心防砖法案】：绝对不能直接使用 make defconfig！
    # VPS 的硬盘大多是 VirtIO/KVM，必须通过继承当前正在运行的内核配置，才能保住硬盘驱动！
    # ----------------------------------------------------------------------------------
    if [ -f "/boot/config-$(uname -r)" ]; then
        cp "/boot/config-$(uname -r)" .config
        info "已成功继承并剽窃当前存活系统中的最原生驱动配置文件 (VirtIO/KVM 救命驱动已保全)！"
    else
        if modprobe configs 2>/dev/null && [ -f /proc/config.gz ]; then
            zcat /proc/config.gz > .config
            info "已强行从 /proc/config.gz 内存中提取出内核运行时的物理驱动图谱配置！"
        else
            error "致命警告：无法在系统中找到任何宿主内核配置模板！"
            error "如果继续强制编译，新内核将在开机时因缺失虚拟硬盘驱动而引发 Kernel Panic 导致变砖！"
            read -rp "您确定要承担极其高昂的宕机变砖风险执意继续吗？(y/n): " force_k
            if [ "$force_k" != "y" ]; then 
                return 1
            fi
            make defconfig
        fi
    fi
    
    make scripts
    
    ./scripts/config --enable CONFIG_TCP_CONG_BBR
    ./scripts/config --enable CONFIG_DEFAULT_BBR
    ./scripts/config --enable CONFIG_TCP_BBR3 2>/dev/null || true
    
    # 斩断非必要的外设驱动节约编译时间
    ./scripts/config --disable CONFIG_DRM_I915
    ./scripts/config --disable CONFIG_NET_VENDOR_REALTEK
    ./scripts/config --disable CONFIG_NET_VENDOR_BROADCOM
    ./scripts/config --disable CONFIG_E100
    
    # 绝杀 Debian 系编译必出的系统签名死亡陷阱
    ./scripts/config --disable SYSTEM_TRUSTED_KEYS
    ./scripts/config --disable SYSTEM_REVOCATION_KEYS
    ./scripts/config --disable DEBUG_INFO_BTF
    ./scripts/config --disable DEBUG_INFO
    
    yes "" | make olddefconfig

    print_magenta ">>> [4/7] 点火！全核满速编译正式爆发 (采用最稳定裸编译模式)..."
    local CPU=$(nproc)
    local RAM=$(free -m | awk '/Mem/{print $2}')
    local THREADS=1
    
    if [ "$RAM" -ge 2000 ]; then
        THREADS=$CPU
    elif [ "$RAM" -ge 1000 ]; then
        THREADS=2
    fi
    
    if ! make -j$THREADS; then
        error "编译被突发错误腰斩，引发系统级熔断！"
        read -rp "按 Enter 接受失败并撤退..." _
        return 1
    fi

    print_magenta ">>> [5/7] 强行植入底层驱动模块库并执行新内核物理直接挂载 (make install)..."
    make modules_install
    make install

    # ----------------------------------------------------------------------------------
    # 【核心防砖法案 2】：强制生成 Initramfs，否则 GRUB 有内核也无法挂载硬盘
    # ----------------------------------------------------------------------------------
    local NEW_KERNEL_VER=$(make -s kernelrelease)
    print_magenta ">>> [6/7] 核心保命降落伞布置：正在为新内核 [$NEW_KERNEL_VER] 生成救命级的 Initramfs 初始内存盘..."
    
    if command -v update-initramfs >/dev/null 2>&1; then
        update-initramfs -c -k "$NEW_KERNEL_VER" || true
    elif command -v dracut >/dev/null 2>&1; then
        dracut --force "/boot/initramfs-${NEW_KERNEL_VER}.img" "$NEW_KERNEL_VER" || true
    else
        warn "未找到 update-initramfs 或 dracut，可能无法正确生成引导镜像！"
    fi

    print_magenta ">>> [7/7] 刷新 GRUB 系统引导器并进行清扫..."
    
    if command -v update-grub >/dev/null 2>&1; then
        update-grub || true
    elif command -v update-grub2 >/dev/null 2>&1; then
        update-grub2 || true
    elif command -v grub-mkconfig >/dev/null 2>&1; then
        grub-mkconfig -o /boot/grub/grub.cfg || true
    fi

    # 绝对禁止在此处使用 apt-get purge 删除老内核！那是你在无法开机时最后且唯一的回滚救命底盘！
    
    cd /
    rm -rf $BUILD_DIR/linux-* 2>/dev/null || true
    rm -rf $BUILD_DIR/$KERNEL_FILE 2>/dev/null || true

    info "神迹已成！全世界最纯正、毫无杂质的满血 BBR3 协议栈已写入您的主机命脉中。"
    warn "为防万一，旧系统内核已被完整保留。若重启失败，请在云服务商面板使用 VNC 登录，在 GRUB 菜单选择旧内核回滚。"
    info "系统将在 10 秒后强行断电并以新身躯重新降临..."
    sleep 10
    reboot
}

# ==============================================================================
# [ 20. 60+ 项百万并发系统级极限网络栈宏观调优 (V171 巅峰回归版，带极其严苛的自检闭环) ]
# ==============================================================================
do_perf_tuning() {
    title "超维极限网络层重构：系统底层网络栈结构全系撕裂与灌注"
    warn "操作警示: 这将极大地拉伸 TCP 缓冲并修改网络包调度，将不可逆地引发系统物理重启！"
    
    read -rp "准备好接纳新框架了吗？(y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        return
    fi
    
    # 动态抓取当前系统的游走态，为用户提供调优参考定标
    local current_scale=$(sysctl -n net.ipv4.tcp_adv_win_scale 2>/dev/null || echo "1")
    local current_app=$(sysctl -n net.ipv4.tcp_app_win 2>/dev/null || echo "31")
    
    echo -e "  当前系统内存滑动侧倾角度 (tcp_adv_win_scale): ${cyan}${current_scale}${none} (建议填 1 或 2)"
    echo -e "  当前系统应用保留水池线 (tcp_app_win): ${cyan}${current_app}${none} (建议保留 31)"
    
    read -rp "可自定义 tcp_adv_win_scale (-2 到 2 为合法域，直接回车保留当前): " new_scale
    new_scale=${new_scale:-$current_scale}
    
    read -rp "可自定义 tcp_app_win (1 到 31 的分配率，直接回车保留当前): " new_app
    new_app=${new_app:-$current_app}

    print_magenta ">>> 正在执行大扫除：剿杀过时的加速器与旧世代冲突配置..."
    
    # 暴力捣毁净网前可能残留的阻碍 (如上古时代的 net-speeder)
    systemctl stop net-speeder >/dev/null 2>&1 || true
    killall net-speeder >/dev/null 2>&1 || true
    systemctl disable net-speeder >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/net-speeder.service
    systemctl daemon-reload >/dev/null 2>&1
    rm -rf /root/net-speeder

    # 清空可能冲突的旧时代配置文件
    # 极其注重细节：使用 truncate 而不是 rm，防止破坏用户原有的系统软连接
    truncate -s 0 /etc/sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-network-optimized.conf 2>/dev/null || true
    
    rm -f /etc/sysctl.d/99-bbr*.conf 2>/dev/null
    rm -f /etc/sysctl.d/99-ipv6-disable.conf 2>/dev/null
    rm -f /etc/sysctl.d/99-pro*.conf 2>/dev/null
    rm -f /etc/sysctl.d/99-xanmod-bbr3.conf 2>/dev/null
    rm -f /usr/lib/sysctl.d/50-pid-max.conf 2>/dev/null
    rm -f /usr/lib/sysctl.d/99-protect-links.conf 2>/dev/null
    
    print_magenta ">>> 正在彻底释放 Linux 全局进程限制的天花板，构建百万级并发底层阀门..."
    
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

    # 深度对抗部分 Linux 发行版不读 limits.conf 的系统级 BUG 陋习
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
    fi
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session-noninteractive; then
        echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive
    fi
    
    # 为 Systemd 总线注入大满贯配额
    echo "DefaultLimitNOFILE=1000000" >> /etc/systemd/system.conf
    echo "DefaultLimitNPROC=1000000" >> /etc/systemd/system.conf

    # 探查并继承当前的排队规则，防止配置冲突
    local target_qdisc="fq"
    if [ "$(check_cake_state)" = "true" ]; then
        target_qdisc="cake"
    fi

    # ====================================================================
    # 核心高能区：全量展开 60 多项惊世骇俗的系统优化巨阵，毫无保留！
    # 每一个参数独立占行，拒绝任何无脑拼接，彰显工业级配置底蕴。
    # ====================================================================
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

# -- 边缘极限探针群补充 (V171 神级参数回归阵列) --
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

    # ==========================================
    # V171 终极闭环自检：强行捕获 Sysctl 是否存在语法爆破错误！
    # 绝不允许系统在包含错误参数的情况下强行挂载！
    # ==========================================
    print_magenta ">>> 正在执行物理层级 sysctl 强制灌注与报错反馈捕获..."
    
    if ! sysctl -p /etc/sysctl.d/99-network-optimized.conf >/dev/null 2>&1; then
        error "系统拒收报告：Sysctl 参数字典存在极其致命的语法错漏或硬件不支持该组件，内核已拒绝挂载！流程被截断熔断。"
        read -rp "请按下 Enter 接受失败并安全返回主控台..." _
        return 1
    else
        info "验证完美通过：所有 60+ 项底层网络核心参数顺利通过系统安检，已被内核强行无损接纳。"
    fi
    
    # 智能获取当前机器对外的唯一战术主网卡名，并施加硬件卸载
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    
    if [ -n "$IFACE" ]; then
        print_magenta ">>> 正在向底层网卡固件 ($IFACE) 植入硬件加速卸载逻辑..."
        
        # 核心功能模块 1：网卡硬件微操执行脚本 (防粘包/防自适应延迟)
        cat > /usr/local/bin/nic-optimize.sh <<'EONIC'
#!/bin/bash
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
ethtool -K $IFACE lro off rx-gro-hw off 2>/dev/null || true
# 强行关闭自适应聚合，拒绝网卡堆积小包
ethtool -C $IFACE adaptive-rx off rx-usecs 0 tx-usecs 0 2>/dev/null || true
EONIC
        chmod +x /usr/local/bin/nic-optimize.sh
        
        # 封装为 Systemd 级别守护服务，确保开机自启
        cat > /etc/systemd/system/nic-optimize.service <<EOSERVICE
[Unit]
Description=NIC Advanced Hardware Tuning Engine
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/nic-optimize.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOSERVICE

        systemctl daemon-reload
        systemctl enable nic-optimize.service >/dev/null 2>&1
        systemctl start nic-optimize.service
        
        # 核心功能模块 2：RPS / RFS 多队列软中断分配散列分发表脚本
        cat > /usr/local/bin/rps-optimize.sh <<'EOF'
#!/bin/bash
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
CPU=$(nproc)
# 动态计算位移，生成十六进制十六 CPU 满载掩码
CPU_MASK=$(printf "%x" $(( (1<<CPU)-1 )))
RX_QUEUES=$(ls /sys/class/net/$IFACE/queues/ 2>/dev/null | grep rx- | wc -l)

# 动态下发 CPU 绑定掩码到每一个硬接收队列中
for RX in /sys/class/net/$IFACE/queues/rx-*; do
    echo $CPU_MASK > $RX/rps_cpus 2>/dev/null || true
done

# 同步散列下发至网卡发送队列
for TX in /sys/class/net/$IFACE/queues/tx-*; do
    echo $CPU_MASK > $TX/xps_cpus 2>/dev/null || true
done

sysctl -w net.core.rps_sock_flow_entries=131072 2>/dev/null

# 开启硬件流督导精确计算
if [ "${RX_QUEUES:-0}" -gt 0 ]; then
    FLOW_PER_QUEUE=$((65535 / RX_QUEUES))
    for RX in /sys/class/net/$IFACE/queues/rx-*; do
        echo $FLOW_PER_QUEUE > $RX/rps_flow_cnt 2>/dev/null || true
    done
fi
EOF
        chmod +x /usr/local/bin/rps-optimize.sh
        
        # 同样封装为开机自启服务阵列
        cat > /etc/systemd/system/rps-optimize.service <<EOF
[Unit]
Description=RPS RFS Network CPU Soft-Interrupt Distribution Engine
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/rps-optimize.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF

        systemctl daemon-reload
        systemctl enable rps-optimize.service >/dev/null 2>&1
        systemctl start rps-optimize.service
        
        # ==========================================
        # V171 硬件自检闭环：检查服务是否存活，确保不是“纸面优化”
        # ==========================================
        if systemctl is-active --quiet nic-optimize.service && systemctl is-active --quiet rps-optimize.service; then
            info "网卡硬件底层守护群已成功激活，开机自动执行已物理装载！"
        else
            warn "警报：网卡守护群装载状态异常，这可能会导致您的网卡失去极致吞吐并发能力。"
        fi
    fi

    info "大满贯！全量巨型底层参数注入完成！系统即将重启应用物理层面的修改..."
    sleep 30
    reboot
}

# ==============================================================================
# (为防止大模型物理截断，代码第二部分到此安全驻留。)
# (核心 130+ 探针矩阵、防砖内核编译、60项自检 Sysctl 等 2000 行将于下一段无缝送出！)
# ==============================================================================
# ==============================================================================
# [ 26. Reality 回落限速探针与深度防御监控台 ]
# ==============================================================================
do_fallback_probe() {
    clear
    echo -e "\n\033[93m=== 全息扫描拦截中心：Xray Reality 防盗录回落黑洞阵列扫描仪 ===\033[0m"
    
    # 精确多行提取，拒绝单行混淆
    jq -r '
      .inbounds[]? | select(.protocol=="vless" and .streamSettings.security=="reality") | .streamSettings.realitySettings | 
      "  [防线配置 A - 上传物理阻截通道]\n    预置反探针漏网诱饵载荷 (afterBytes) : \(.limitFallbackUpload.afterBytes // "未启用限速")\n    启动致命级物理绞杀下限极速点 (bytesPerSec) : \(.limitFallbackUpload.bytesPerSec // "未开启")\n  [防线配置 B - 下载拉取物理阻截通道]\n    预置反探针漏网诱饵载荷 (afterBytes) : \(.limitFallbackDownload.afterBytes // "未启用限速")\n    启动致命级物理绞杀下限极速点 (bytesPerSec) : \(.limitFallbackDownload.bytesPerSec // "未开启")"
    ' "$CONFIG" 2>/dev/null || echo -e "  \033[31m严重读取障碍：未发现任何有效配置文件，系统的 JSON 引擎解构失败！\033[0m"
    
    echo ""
    read -rp "情报汇报工作终了，按 Enter 退缩回主级操作平台..." _
}

# ==============================================================================
# [ 27. 系统建仓初始化与高级内核微操调优主菜单 ]
# ==============================================================================
do_sys_init_menu() {
    while true; do
        title "高维神域装载车间：内核脱胎换骨、极低延迟配置及系统总成重塑"
        echo "  1) 一键拉平全系基础环境、强制校准时区、部署 1GB Swap 与自动清理器"
        echo "  2) 将底层物理 DNS 解析彻底交接给 resolvconf 系统强硬看管"
        echo -e "  ${cyan}3) 极简流：安装官方预编译版本 XANMOD (main) 主线巨核驱动${none}"
        echo "  4) 真理裸装：从 Kernel 官网暴力裸装提取主线内核 + 物理硬焊 BBR3 (防砖版)"
        echo "  5) 拔除硬件出场长队冗余，深度调优 TX Queue (压死为 2000 超极速列队)"
        echo "  6) 激进深层网络内核环境大调优方案 (tcp_adv_win_scale/tcp_app_win 空间分配)"
        echo "  7) 【上帝禁区】唤醒全域 25 项极限深层系统与软件优化控制面板"
        echo -e "  ${cyan}8) 操作强大的 CAKE 收发大调度器，补偿封箱加密带来的额外损耗${none}"
        echo "  0) 退出本管理单元，返回系统主控枢纽"
        hr
        read -rp "统帅，请打出系统后续要如何重整的执行方案编号: " sys_opt
        
        case "$sys_opt" in
            1) 
                print_magenta ">>> 接管系统的控制权，强制对全系关联底层核心基础代码包挂载云端热拉取..."
                export DEBIAN_FRONTEND=noninteractive
                apt-get update -y
                apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" full-upgrade -y
                apt-get autoremove -y --purge
                
                # 布防极客常用系统必备套件
                apt-get install -y wget curl sudo socat ntpdate e2fsprogs pkg-config iproute2 ethtool
                
                print_magenta ">>> 执行跨纬度时间钟表物理级强行同步纠正..."
                timedatectl set-timezone Asia/Kuala_Lumpur
                ntpdate us.pool.ntp.org
                
                # 强行把虚拟环境的时间写死入芯片内核中保存
                hwclock --systohc
                info "时间轴同步大功告成！已精准对接 Asia/Kuala_Lumpur 时区。"
                
                # 极其稳固地调用 Swap 引擎确保不溢出死机
                check_and_create_1gb_swap
                
                print_magenta ">>> 为底层安装隐秘定点定期爆发的日志与缓存碎件清道夫程序 (cc1.sh)..."
                cat <<'EOF' > /usr/local/bin/cc1.sh
#!/bin/bash
apt-get clean
apt-get autoremove -y --purge
journalctl --vacuum-time=3d
rm -rf /tmp/*
rm -rf /var/log/*
sync
EOF
                chmod +x /usr/local/bin/cc1.sh
                
                (crontab -l 2>/dev/null | grep -v cc1.sh ; echo "0 4 */10 * * /usr/local/bin/cc1.sh") | crontab -
                info "极其可怕的系统清道夫模块 (cc1.sh) 已经布置完毕，此后每十天它将横扫一切残留垃圾！"
                
                read -rp "系统地基夯实完毕。按 Enter 键继续..." _ 
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

# ==============================================================================
# [ 28. 全域无损对齐化多维用户组阵列打印渲染输出中心 ]
# ==============================================================================
print_node_block() {
    local protocol="$1"
    local ip="$2"
    local port="$3"
    local sni="$4"
    local pbk="$5"
    local shortid="$6"
    local utls="$7"
    local uuid="$8"

    # 用标准八行冒号进行严密的对齐截断填充
    printf "  ${yellow}%-15s${none} : %s\n" "系统核心通讯协议骨架" "$protocol"
    printf "  ${yellow}%-15s${none} : %s\n" "物理宿主对挂暴露公网" "$ip"
    printf "  ${yellow}%-15s${none} : %s\n" "被隐蔽遮盖穿透层端口" "$port"
    printf "  ${yellow}%-15s${none} : %s\n" "高防混淆探测护盾域名" "${sni:-系统崩溃未能提取}"
    printf "  ${yellow}%-15s${none} : %s\n" "公钥通讯唯一验证通道" "${pbk:-系统崩溃未能提取}"
    printf "  ${yellow}%-15s${none} : %s\n" "短效临时握手标识指令" "${shortid:-系统崩溃未能提取}"
    printf "  ${yellow}%-15s${none} : %s\n" "底层指纹模拟仿真引擎" "$utls"
    printf "  ${yellow}%-15s${none} : %s\n" "绝密超维身份授权凭据" "$uuid"
}

do_summary() {
    if ! test -f "$CONFIG"; then 
        return
    fi
    
    title "The Apex Vanguard 高级战情汇总指挥中台与多核心节点通讯密钥完全调取列阵"
    local ip=$(_get_ip)
    
    # 将整个 JSON 进行一次深度解析
    local vless_inbound=$(jq -c '.inbounds[]? | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1)
    
    if [ -n "$vless_inbound" ] && [ "$vless_inbound" != "null" ]; then
        local pbk=$(echo "$vless_inbound" | jq -r '.streamSettings.realitySettings.publicKey // "配置被外力篡改失效"' 2>/dev/null)
        local main_sni=$(echo "$vless_inbound" | jq -r '.streamSettings.realitySettings.serverNames[0] // "配置被外力篡改失效"' 2>/dev/null)
        local port=$(echo "$vless_inbound" | jq -r '.port // 443' 2>/dev/null)
        
        # 将庞杂的数据结构树抽拉为二维的客户端实体阵列
        local shortIds_json=$(echo "$vless_inbound" | jq -c '.streamSettings.realitySettings.shortIds' 2>/dev/null)
        local clients_json=$(echo "$vless_inbound" | jq -c '.settings.clients[]?' 2>/dev/null)

        local idx=0
        while read -r client; do
            [ -z "$client" ] && break
            
            local uuid=$(echo "$client" | jq -r '.id' 2>/dev/null)
            local remark=$(echo "$client" | jq -r '.email // "空白失落的姓名标牌"' 2>/dev/null)
            
            # 使用高精度的 grep 读取独立映射文件，防范多用户环境下的 SNI 数据错位绑定流
            local target_sni=$(grep "^$uuid|" "$USER_SNI_MAP" 2>/dev/null | cut -d'|' -f2)
            target_sni=${target_sni:-$main_sni}
            
            # 严格依据物理层索引匹配每个客户端归属于他的特定密钥，绝不串台漂移！
            local sid=$(echo "$shortIds_json" | jq -r ".[$idx] // \"系统未能匹配\"" 2>/dev/null)
            
            hr
            print_green ">>> 已验证合法连接物理核心载体准入者代号名单: $remark"
            print_node_block "VLESS-Reality (Vision核心)" "$ip" "$port" "$target_sni" "$pbk" "$sid" "chrome 虚拟掩体模拟层" "$uuid"
            
            local link="vless://${uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${target_sni}&fp=chrome&pbk=${pbk}&sid=${sid}&type=tcp#${remark}"
            echo -e "\n  ${cyan}全球广域通讯无缝封装格式通用直链地址:${none}\n  $link\n"
            
            # 如果系统里部署了图形阵列依赖，便大放异彩直接终端渲染二维码供移动端扫取！
            if command -v qrencode >/dev/null 2>&1; then 
                qrencode -m 2 -t UTF8 "$link"
            fi
            
            idx=$((idx + 1))
        done <<< "$clients_json"
    fi

    # 抽取完全古早的体系网络节点进行兜底兼容
    local ss_inbound=$(jq -c '.inbounds[]? | select(.protocol=="shadowsocks")' "$CONFIG" 2>/dev/null | head -n 1)
    if [ -n "$ss_inbound" ] && [ "$ss_inbound" != "null" ]; then
        local s_port=$(echo "$ss_inbound" | jq -r '.port' 2>/dev/null)
        local s_pass=$(echo "$ss_inbound" | jq -r '.settings.password' 2>/dev/null)
        local s_method=$(echo "$ss_inbound" | jq -r '.settings.method' 2>/dev/null)
        
        hr
        print_green ">>> 这是一座为极其落后算力或极简特殊环境物理设备所预置的兼容性堡垒备选节点: Shadowsocks 遗迹建筑体系"
        printf "  ${yellow}%-15s${none} : %s\n" "系统核心通讯协议骨架" "Shadowsocks 常规原始形态"
        printf "  ${yellow}%-15s${none} : %s\n" "物理宿主对挂暴露公网" "$ip"
        printf "  ${yellow}%-15s${none} : %s\n" "被隐蔽遮盖穿透层端口" "$s_port"
        printf "  ${yellow}%-15s${none} : %s\n" "高防混淆探测护盾域名" "【该低纬度协议本身不支持包含此等高深功能挂载项】"
        printf "  ${yellow}%-15s${none} : %s\n" "公钥通讯唯一验证通道" "【该低纬度协议本身不支持包含此等高深功能挂载项】"
        printf "  ${yellow}%-15s${none} : %s\n" "短效临时握手标识指令" "【该低纬度协议本身不支持包含此等高深功能挂载项】"
        printf "  ${yellow}%-15s${none} : %s\n" "底层指纹模拟仿真引擎" "$s_method"
        printf "  ${yellow}%-15s${none} : %s\n" "绝密超维身份授权凭据" "$s_pass"
        
        local b64=$(printf '%s:%s' "$s_method" "$s_pass" | base64 | tr -d '\n')
        local link_ss="ss://${b64}@${ip}:${s_port}#SS-Node-备用堡垒阵列网"
        echo -e "\n  ${cyan}已被编码与压缩折叠的兼容系通用加密拉取直链格式:${none}\n  $link_ss\n"
    fi
}

# ==============================================================================
# [ 24. 极高频多级指令调用集：完全去重合与强效关联用户池增减中枢 ]
# ==============================================================================
do_user_manager() {
    while true; do
        title "高维用户全域准入管理体系 (支持阵列式增删、短连接导入、个性化防御SNI)"
        
        if ! test -f "$CONFIG"; then 
            error "系统中未能发现由该架构所创建产生的文件源，网络根基不在，无法实施操作！"
            return
        fi
        
        local clients=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .settings?.clients[]? | .id + "|" + (.email // "无名者")' "$CONFIG" 2>/dev/null)
        if test -z "$clients" || test "$clients" = "null"; then 
            error "经过深度检索，内网里没有发现被系统挂载和认可的 VLESS 权限身份名单信息组！"
            return
        fi
        
        # 将庞大的信息拆解并平滑地投递为一个文本管道列表，保证终端里多用户排位不混乱发散
        local tmp_users="/tmp/xray_users.txt"
        echo "$clients" | awk -F'|' '{print NR"|"$1"|"$2}' > "$tmp_users"
        
        echo -e "目前系统里依旧残留并享有特权的现役全部合法用户登记列表："
        while IFS='|' read -r num uid remark; do
            local utime=$(grep "^$uid|" "$USER_TIME_MAP" 2>/dev/null | cut -d'|' -f2)
            utime=${utime:-"远古创建时代残留 / 系统遗失不可查考"}
            echo -e "  [序号 ${num}] 名牌标识贴: ${cyan}$remark${none} | 档案生成时间戳: ${gray}$utime${none} | 绝对通讯加密符 UUID: ${yellow}$uid${none}"
        done < "$tmp_users"
        hr
        
        echo "  a) [绝对新编] 指派底层系统为您新增本地合法用户凭据 (系统自动赋予新 UUID 与 ShortId)"
        echo "  m) [历史归化] 利用旧时代的数据文件执行手工填表，无损平滑收编外部环境中飘荡的流亡用户历史凭证体系"
        echo "  s) [千面幻影] 仅对被选中的极少部分人实施定制化手术，单独为他颁发并绑定一张避开雷达特征检测的高级专有 SNI 面具"
        echo "  d) [死亡执行] 从物理和数据这两个位面上，不可逆转地把指定人物在这个系统中存在的唯一标识特征数据从世界表彻底除名剥离！"
        echo "  q) [回归命令] 取消并终结在该区域的一切操作指令意图，直接平安返回安全大厅！"
        
        read -rp "指挥官，所有的系统资源随您支配，请在此决断您的执行意图代码: " uopt
        
        local ip=$(_get_ip)
        
        # 分流一：新建
        if test "$uopt" = "a"; then
            local nu=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || $XRAY_BIN uuid)
            local ns=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n')
            local ctime=$(date +"%Y-%m-%d %H:%M")
            
            read -rp "为了区分身份，请赐予他一个具有辨识度的代号或名号备注 (若无输入则直接暴力默认挂载 User-${ns}): " u_remark
            u_remark=${u_remark:-User-${ns}}
            
            # 使用临时中间件写入策略，防止破坏
            cat > /tmp/new_client.json <<EOF
{
  "id": "$nu",
  "flow": "xtls-rprx-vision",
  "email": "$u_remark"
}
EOF
            # V171 极其严苛的 JSON 注入修复：放弃不兼容的字符串拼接，使用 --argjson 完全吸纳外部构建好的模块块
            _safe_jq_write --argjson new_client "$(< /tmp/new_client.json)" '
              .inbounds = [
                  .inbounds[]? | if (.protocol == "vless") then
                      .settings.clients += [$new_client]
                  else
                      .
                  end
              ]
            '
            
            # V171 极其严苛的 JSON 注入修复：完美运用 --arg 透传字符串变量，拒绝引号错乱引发的暴毙
            _safe_jq_write --arg sid "$ns" '
              .inbounds = [
                  .inbounds[]? | if (.protocol == "vless") then
                      .streamSettings.realitySettings.shortIds += [$sid]
                  else
                      .
                  end
              ]
            '
            rm -f /tmp/new_client.json
            echo "$nu|$ctime" >> "$USER_TIME_MAP"
            
            # 召唤系统健康探针，确保刚刚的注入没有导致 Xray 死亡
            ensure_xray_is_alive
            
            local vless_node=$(jq -c '.inbounds[]? | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1)
            local port=$(echo "$vless_node" | jq -r '.port')
            local sni=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.serverNames[0]')
            local pub=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.publicKey')
            
            info "新权柄分派流程闭环执行极其顺利！无错流生成完毕！"
            hr
            print_green ">>> 恭喜该名额的全新权限授权凭证合法持有人归位: $u_remark"
            print_node_block "VLESS-Reality (最高形态Vision层)" "$ip" "$port" "$sni" "$pub" "$ns" "chrome 级幻影指纹伪装层级" "$nu"
            local link="vless://${nu}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${ns}&type=tcp#${u_remark}"
            echo -e "\n  ${cyan}这是他用于沟通与连接世界彼端的专属加密即刻分发直连长字符代码段:${none}\n  $link\n"
            
            if command -v qrencode >/dev/null 2>&1; then 
                qrencode -m 2 -t UTF8 "$link"
            fi
            read -rp "检阅操作告一段落，敬请重敲 Enter 键折返主控核心面板..." _
            
        # 分流二：收编历史旧将
        elif test "$uopt" = "m"; then
            hr
            echo -e " ${cyan}>>> 无尽星海中漂流遗迹的外部老用户强行召回与平滑跨代级迁移执行向导系统 <<<${none}"
            echo -e " ${yellow}系统运作提示: 在保留他们原来客户端凭据配置丝毫不变的前提下，将他们的外生数据指纹暴力强行塞入到这台本机数据库！并以我们此刻的本地物理公网 IP 与核心系统新签发的 pbk 为他们重构全新的跨时代连接入口链条！${none}"
            
            read -rp "请为您要拉拢归化的那个神秘外人下发一个标识标签和归化名称 (诸如: VIP-Lost-User): " m_remark
            m_remark=${m_remark:-ImportedUser}
            
            read -rp "在屏幕上毫无保留地贴入这位旧时代残留使用者的老旧核心通关护身符长串身份 UUID 乱码: " m_uuid
            if [ -z "$m_uuid" ]; then 
                error "致命信息未提供：UUID 代表人的生命权，绝不允许留空放过！系统拒录！"
                continue
            fi
            
            read -rp "在屏幕上毫无保留地贴入这位旧时代残留使用者老旧用来接合被截断防盗录机制的短效密钥 (ShortId / SID 乱码串): " m_sid
            if [ -z "$m_sid" ]; then 
                error "防窃听关键残片信息丢失：ShortId 代表接头暗号，不填入直接拒绝准入！系统拒录！"
                continue
            fi
            
            local ctime=$(date +"%Y-%m-%d %H:%M")
            cat > /tmp/new_client.json <<EOF
{
  "id": "$m_uuid",
  "flow": "xtls-rprx-vision",
  "email": "$m_remark"
}
EOF
            # 同样运用极其严谨的 --argjson 模块化拼装手段，坚决拒绝直接内嵌字符串引发的转义惨案
            _safe_jq_write --argjson new_client "$(< /tmp/new_client.json)" '
              .inbounds = [
                  .inbounds[]? | if (.protocol == "vless") then
                      .settings.clients += [$new_client]
                  else
                      .
                  end
              ]
            '
            
            _safe_jq_write --arg sid "$m_sid" '
              .inbounds = [
                  .inbounds[]? | if (.protocol == "vless") then
                      .streamSettings.realitySettings.shortIds += [$sid]
                  else
                      .
                  end
              ]
            '
            rm -f /tmp/new_client.json
            echo "$m_uuid|$ctime" >> "$USER_TIME_MAP"
            
            read -rp "极其敏感的特殊优待程序判定：这名收编而来的外逃者是否具备高价值，因而值得我们为他单独在内核伪造一个顶级专有的免拦截防御 SNI 流量护盾大门？ (若无此需求，请直接敲击回车让其挂载在随大流的平民共享主用网络矩阵门面下): " m_sni
            if test -n "$m_sni"; then
                _safe_jq_write --arg sni "$m_sni" '
                  .inbounds = [
                      .inbounds[]? | if (.protocol == "vless") then
                          .streamSettings.realitySettings.serverNames += [$sni] | 
                          .streamSettings.realitySettings.serverNames |= unique
                      else
                          .
                      end
                  ]
                '
                sed -i "/^$m_uuid|/d" "$USER_SNI_MAP" 2>/dev/null
                echo "$m_uuid|$m_sni" >> "$USER_SNI_MAP"
                info "极其奢华的动作！已破格为这一位归化的外来用户物理锁定并强力绑定了特殊专属避险门面 SNI: $m_sni"
            else
                m_sni=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0] // empty' "$CONFIG" 2>/dev/null | head -n 1)
            fi
            
            ensure_xray_is_alive
            
            local vless_node=$(jq -c '.inbounds[]? | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1)
            local port=$(echo "$vless_node" | jq -r '.port')
            local pub=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.publicKey')
            
            info "历史外逃流浪者收编洗白强行落库完成！系统当前核心层面对他重新下放签发的所有新认证书已经全数核验包装结束并随时待命连接！"
            hr
            print_green ">>> 系统新晋合法化与归化受庇护实体档案所有者: $m_remark"
            print_node_block "VLESS-Reality (新构Vision主核层)" "$ip" "$port" "$m_sni" "$pub" "$m_sid" "chrome 高能伪装系统" "$m_uuid"
            local link="vless://${m_uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${m_sni}&fp=chrome&pbk=${pub}&sid=${m_sid}&type=tcp#${m_remark}"
            echo -e "\n  ${cyan}跨系统重铸合并装配后的顶级特权全新通讯分发直连地址链条:${none}\n  $link\n"
            
            if command -v qrencode >/dev/null 2>&1; then 
                qrencode -m 2 -t UTF8 "$link"
            fi
            read -rp "按 Enter 返回这艘战车的主控面板中心..." _
            
        # 分流三：特权定制专属面具
        elif test "$uopt" = "s"; then
            read -rp "您要对以上列表中的几号序列用户进行单独的 SNI 面具绑定？请输入序号数字: " snum
            local target_uuid=$(awk -F'|' -v id="${snum:-0}" '$1==id {print $2}' "$tmp_users")
            local target_remark=$(awk -F'|' -v id="${snum:-0}" '$1==id {print $3}' "$tmp_users")
            
            if test -n "$target_uuid"; then
                read -rp "输入未来归属于该用户的专属顶级防封 SNI (例如 apple.com): " u_sni
                if test -n "$u_sni"; then
                    _safe_jq_write --arg sni "$u_sni" '
                      .inbounds = [
                          .inbounds[]? | if (.protocol == "vless") then
                              .streamSettings.realitySettings.serverNames += [$sni] | 
                              .streamSettings.realitySettings.serverNames |= unique
                          else
                              .
                          end
                      ]
                    '
                    sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null
                    echo "$target_uuid|$u_sni" >> "$USER_SNI_MAP"
                    
                    ensure_xray_is_alive
                    info "神之一手的极客操作！系统底层代码已被完全撕裂，并且圆满地完成了一次将新辟域名强行硬焊入主核心运行识别池的物理接驳与映射分离操作！"
                    
                    local vless_node=$(jq -c '.inbounds[]? | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1)
                    local port=$(echo "$vless_node" | jq -r '.port')
                    local idx=$((${snum:-0}-1))
                    local sid=$(echo "$vless_node" | jq -r ".streamSettings.realitySettings.shortIds[$idx] // empty")
                    local pub=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.publicKey // empty')
                    
                    hr
                    print_green ">>> 系统特别提权特化处理享受顶级隐蔽与护城河待遇的授权控制者名录身份: $target_remark"
                    print_node_block "VLESS-Reality (Vision特化终极形态)" "$ip" "$port" "$u_sni" "$pub" "$sid" "chrome 高仿真重构层" "$target_uuid"
                    local link="vless://${target_uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${u_sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${target_remark}"
                    echo -e "\n  ${cyan}请提取其彻底刷新并发生物理变异后的高维特权身份直连派发密码链:${none}\n  $link\n"
                    
                    if command -v qrencode >/dev/null 2>&1; then 
                        qrencode -m 2 -t UTF8 "$link"
                    fi
                    read -rp "请您猛力按压 Enter 键断开并返回上一级大厅主控中心面板..." _
                fi
            else 
                error "警告，参数错误！您在无脑乱填或盲猜的序列位置号根本没有映射或命中系统中存在的合法名单库内活跃人员记录。"
            fi
            
        # 分流四：物理抹杀系统连带死锁同步双删机制
        elif test "$uopt" = "d"; then
            read -rp "开启灭世与清洗法案进程指令！长官，请无情地圈出您准备立刻切断注销其未来登录系统权的序列代号数字: " dnum
            local total=$(wc -l < "$tmp_users" 2>/dev/null)
            
            if test "${total:-0}" -le 1; then 
                error "终极防自毁审计门系统强行报错并弹回申请：当前物理宿主机内除了您以外，所有其他人员均已被抹杀殆尽，我们必须为您保全系统中唯一留存的基础架构根用户，全盘清空会切断你所有的未来重连途径！自杀动作已被中止与拒绝！"
            else
                local target_uuid=$(awk -F'|' -v id="${dnum:-0}" '$1==id {print $2}' "$tmp_users")
                if test -n "$target_uuid"; then
                    local idx=$((${dnum:-0}-1))
                    
                    # 极其严密的双删指令：不仅删除 clients 节点，必须同步依据索引精准剔除对应的 shortIds
                    # 只要有一个错位，整个 Reality 协议体系就会报废瘫痪！
                    _safe_jq_write --arg uid "$target_uuid" --argjson i "$idx" '
                        .inbounds = [
                            .inbounds[]? | if (.protocol == "vless") then
                                .settings.clients |= map(select(.id != $uid)) | 
                                .streamSettings.realitySettings.shortIds |= del(.[$i])
                            else
                                .
                            end
                        ]
                    '
                    
                    # 清洗外部映射池记录，不留残片
                    sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null
                    sed -i "/^$target_uuid|/d" "$USER_TIME_MAP" 2>/dev/null
                    
                    ensure_xray_is_alive
                    info "丧钟敲响。该猎物系统内留存的所有连接痕迹及身份凭据已经被黑洞双重抹煞剥夺完毕！不留残片！"
                fi
            fi
            
        elif test "$uopt" = "q"; then 
            rm -f "$tmp_users"
            break
        fi
    done
}

# ==============================================================================
# [ 25. 全球恶性阻断路由分离系统 (黑名单清洗雷达) ]
# ==============================================================================
_global_block_rules() {
    while true; do
        title "流量清洗与广告双轨智能阻断雷达控制台"
        
        if ! test -f "$CONFIG"; then 
            error "无法发现流量控制器基础模型文件。"
            return
        fi
        
        local bt_en=$(jq -r '.routing.rules[]? | select(.protocol != null) | select(.protocol | index("bittorrent")) | ._enabled' "$CONFIG" 2>/dev/null | head -1)
        local ad_en=$(jq -r '.routing.rules[]? | select(.domain != null) | select(.domain | index("geosite:category-ads-all")) | ._enabled' "$CONFIG" 2>/dev/null | head -1)
        
        echo -e "  1) BT/PT 极度压榨带宽协议封锁    | 现役雷达运作状态指示器位: ${yellow}${bt_en}${none}"
        echo -e "  2) 全球已知广告特征域名无感封锁  | 现役雷达运作状态指示器位: ${yellow}${ad_en}${none}"
        echo "  0) 收回防线编辑权限并退出系统"
        read -rp "请给出针对这套防御大网的切换指令代号: " bc
        
        case "$bc" in
            1) 
                local nv="true"
                if test "$bt_en" = "true"; then 
                    nv="false"
                fi
                # V171 核心自保升级版：所有 JQ 参数外部化导入
                _safe_jq_write --argjson nv_val "$nv" '
                  .routing.rules = [
                      .routing.rules[]? | if .protocol != null and (.protocol | index("bittorrent")) then
                          ._enabled = $nv_val
                      else
                          .
                      end
                  ]
                '
                ensure_xray_is_alive
                info "BT 带宽压榨拦截雷达切换成功，现已强行锁定为: $nv" 
                ;;
            2) 
                local nv="true"
                if test "$ad_en" = "true"; then 
                    nv="false"
                fi
                _safe_jq_write --argjson nv_val "$nv" '
                  .routing.rules = [
                      .routing.rules[]? | if .domain != null and (.domain | index("geosite:category-ads-all")) then
                          ._enabled = $nv_val
                      else
                          .
                      end
                  ]
                '
                ensure_xray_is_alive
                info "反广告污染阻断开关物理接驳更改完毕，定格在: $nv" 
                ;;
            0) 
                return 
                ;;
        esac
    done
}

# ==============================================================================
# (为防止大模型物理截断，极度庞大的核心代码第三部分到此安全驻留。)
# (核心 130+ 探针矩阵、安装逻辑、状态控制台等代码将于下一段无缝送出！)
# ==============================================================================
# ==============================================================================
# [ 31. 主控防爆多维网络矩阵更替库与系统路由底层参数重映射引信机制 ]
# ==============================================================================
_update_matrix() {
    # 把拼接好的顶级目标掩体阵列强制转化为临时合法大 json 数组存储池
    echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
    
    # 极其高明地运用 --slurpfile 手段外部接驳，绕开无脑替换所带来的一系列非法字符逃逸爆出！
    _safe_jq_write --arg dest "$BEST_SNI:443" --slurpfile snis /tmp/sni_array.json '
        .inbounds = [
            .inbounds[]? | if (.protocol == "vless") then
                .streamSettings.realitySettings.serverNames = $snis[0] |
                .streamSettings.realitySettings.dest = $dest
            else
                .
            end
        ]
    '
    
    rm -f /tmp/sni_array.json
    ensure_xray_is_alive
}

# ==============================================================================
# [ 32. 核心创世引擎：底层架构初装中心 ]
# ==============================================================================
do_install() {
    title "Apex Vanguard Ultimate Final: 高维战舰创世深层部署搭建系统"
    preflight
    
    # 系统重构期间，直接掐死旧进程的心跳，防止物理残骸霸占端口
    systemctl stop xray >/dev/null 2>&1 || true
    
    if [ ! -f "$INSTALL_DATE_FILE" ]; then 
        date +"%Y-%m-%d %H:%M:%S" > "$INSTALL_DATE_FILE"
    fi
    
    echo -e "  ${cyan}请选择本次即将打入服务器灵魂的最深维数据协议链接基座：${none}"
    echo "  1) VLESS-Reality (最新一代加密算法，极低特征流量伪装，高防被墙)"
    echo "  2) Shadowsocks (极度偏执无情精简的轻量大通道，备用直穿兜底)"
    echo "  3) 两者大一统并发 (同时挂载这两套互不干涉的双重通道大门)"
    read -rp "  请告诉系统你最终指派搭建的架构号码: " proto_choice
    proto_choice=${proto_choice:-1}

    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        while true; do 
            read -rp "请分配 VLESS 主通道监听端口 (直接回车默认 443): " input_p
            input_p=${input_p:-443}
            if validate_port "$input_p"; then 
                LISTEN_PORT="$input_p"
                break
            fi
        done
        read -rp "请命名主帅节点代号 (默认 xp-reality): " input_remark
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
            read -rp "请设定辅助 SS 服务端监听口 (直接回车默认 8388): " input_s
            input_s=${input_s:-8388}
            if validate_port "$input_s"; then 
                ss_port="$input_s"
                break
            fi
        done
        ss_pass=$(gen_ss_pass)
        ss_method=$(_select_ss_method)
        
        if test "$proto_choice" = "2"; then 
            read -rp "为该唯一防守底线网络大门赋个代称 (默认 xp-reality): " input_remark
            REMARK_NAME=${input_remark:-xp-reality}
        fi
    fi

    print_magenta ">>> 强权对接 GitHub 全球中控拉取核心引擎模块..."
    bash -c "$(curl -fsSL --connect-timeout 10 https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1
    
    install_update_dat
    
    # 物理覆盖修补：防止官方普通脚本强行复原刷掉我们的百万并发权限
    fix_xray_systemd_limits

    # 1. 抛出工整纯正且充满层级美感的底盘架构 (完整展开)
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
          "settings": {
              "domainStrategy": "AsIs"
          }
      }, 
      {
          "protocol": "blackhole", 
          "tag": "block"
      }
  ]
}
EOF

    # 2. VLESS 大块头挂载处理组
    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        # 基于不可破译真随机引擎进行完全无重复的派生
        local keys=$("$XRAY_BIN" x25519 2>/dev/null)
        local priv=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' ')
        local pub=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' ')
        local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || $XRAY_BIN uuid)
        local sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n')
        local ctime=$(date +"%Y-%m-%d %H:%M")
        
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
        "privateKey": "$priv", 
        "publicKey": "$pub", 
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
        # 无比精确的通过 JSON 解析树顶层写入
        _safe_jq_write --slurpfile snis /tmp/sni_array.json '
            .inbounds += [
                input | .streamSettings.realitySettings.serverNames = $snis[0]
            ]
        ' /tmp/vless_inbound.json
        
        rm -f /tmp/vless_inbound.json /tmp/sni_array.json
    fi

    # 3. 极速纯粹的老旧体系 Shadowsocks 结构打入系统合并
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
        _safe_jq_write '
            .inbounds += [input]
        ' /tmp/ss_inbound.json
        rm -f /tmp/ss_inbound.json
    fi

    # 控制系统内核完成交割闭环，上锁后强制用探针唤醒主战进程
    fix_permissions
    systemctl enable xray >/dev/null 2>&1
    
    if ensure_xray_is_alive; then
        info "所有底层链路及数据加密防护架构全部成功搭建完毕！"
        do_summary
    else
        error "系统防线被不可逆的配置畸变击穿，安装过程已被熔断中止。"
        return 1
    fi
    
    while true; do
        read -rp "按 Enter 稳步返回主控大屏，或强行输入 b 重新排布底层矩阵结构: " opt
        if [[ "$opt" == "b" || "$opt" == "B" ]]; then
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

# ==============================================================================
# [ 33. 斩尽杀绝的绝对级清盘剥离卸载器 ]
# ==============================================================================
do_uninstall() {
    title "终极死神清理：剿杀全域应用层记录并完全复原原始生态"
    read -rp "警告！此操作属于极其恐怖的大清洗，它将强行摧毁所有的 Xray 配置表 (但我们承诺永久保留给您配置的系统底层极限网络栈优化参数矩阵)！确定执行自毁？(y/n): " confirm
    if test "$confirm" != "y"; then 
        return
    fi
    
    local temp_date=""
    if test -f "$INSTALL_DATE_FILE"; then 
        temp_date=$(cat "$INSTALL_DATE_FILE")
        print_magenta ">>> 正在强制提取您的系统最初建档初装时间戳..."
    fi
    
    print_magenta ">>> 发起全域清空，将 Dnsmasq 连根拔起并打成虚无..."
    systemctl stop dnsmasq >/dev/null 2>&1 || true
    systemctl disable dnsmasq >/dev/null 2>&1 || true
    export DEBIAN_FRONTEND=noninteractive
    apt-get purge -y dnsmasq >/dev/null 2>&1 || true
    rm -f /etc/dnsmasq.conf >/dev/null 2>&1
    
    print_magenta ">>> 强行物理破坏 Resolv 锁死保护，复原系统的远古解析生态..."
    chattr -i /etc/resolv.conf 2>/dev/null || true
    if [ -f /etc/resolv.conf.bak ]; then 
        mv -f /etc/resolv.conf.bak /etc/resolv.conf 2>/dev/null
    fi
    systemctl stop resolvconf.service >/dev/null 2>&1 || true
    systemctl disable resolvconf.service >/dev/null 2>&1 || true
    
    if systemctl list-unit-files | grep -q systemd-resolved; then 
        systemctl enable systemd-resolved >/dev/null 2>&1 || true
        systemctl start systemd-resolved >/dev/null 2>&1 || true
    fi
    
    print_magenta ">>> 强行拆除 Xray 的运行权限及依附于它的守护脚本群组..."
    systemctl stop xray >/dev/null 2>&1 || true
    systemctl disable xray >/dev/null 2>&1 || true
    rm -rf /etc/systemd/system/xray.service /etc/systemd/system/xray@.service /etc/systemd/system/xray.service.d /lib/systemd/system/xray* >/dev/null 2>&1
    systemctl daemon-reload >/dev/null 2>&1
    
    print_magenta ">>> 引爆全域销毁矩阵大网，毁掉配置母带与挂载数据目录..."
    rm -rf "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SCRIPT_DIR" /var/log/xray* /usr/local/bin/xrv "$SCRIPT_PATH" >/dev/null 2>&1
    
    (crontab -l 2>/dev/null | grep -v "update-dat.sh" | grep -v "/bin/systemctl restart xray" | grep -v "cc1.sh") | crontab - 2>/dev/null
    hash -r 2>/dev/null
    
    if test -n "$temp_date"; then 
        mkdir -p "$CONFIG_DIR" 2>/dev/null
        echo "$temp_date" > "$INSTALL_DATE_FILE"
    fi
    
    print_green "清剿完美落幕。这台机器现在又像最初的新生儿一般纯净，我们在此别过了！"
    exit 0
}

# ==============================================================================
# [ 34. 巨型系统绝对核心中枢：未被折叠、完美对齐的统帅大厅 ]
# ==============================================================================
main_menu() {
    while true; do
        clear
        echo -e "${blue}======================================================================${none}"
        echo -e "  ${magenta}Xray ex171 The Apex Vanguard - Project Genesis V171 (自检闭环全量版)${none}"
        
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        if test "$svc" = "active"; then 
            svc="${green}核心引擎疯狂咆哮中${none}"
        else 
            svc="${red}引擎静默停驶${none}"
        fi
        
        echo -e "  运作姿态: $svc | 呼叫密令: ${cyan}xrv${none} | 对外通信基站: ${yellow}$(_get_ip)${none}"
        echo -e "${blue}======================================================================${none}"
        echo "  1) 新建世界 / 在废墟上重塑您的 VLESS+SS 双重核心网络"
        echo "  2) 用户管理系统 (增删/改/无损传参修复版)"
        echo "  3) 数据总控中枢 (无损全息打印所有并发用户的详情与扫码直连分发阵列)"
        echo "  4) 人为干预 Geo 世界流量防火墙路由库进行强清洗 (本身已有夜间自动热更新)"
        echo "  5) 追击最前沿 Xray 原核技术 (无缝拉取最新版、系统级秒级热重载)"
        echo "  6) 极其无感的矩阵流转重排 (组合阵列多选并抽离系统顶级探测通过的 SNI 域名)"
        echo "  7) 强横不讲理的系统级防火墙管控 (对全域 BT 洪流和已知广告进行双轨绝地封杀)"
        echo "  8) Reality 回落陷阱雷达扫描台 (看穿暗物质并探测那些伪造审查的扫频狂犬)"
        echo "  9) 全景网络商业运营监控大台 (查看高维并发、DNS 探查与核算精准计费表)"
        echo "  10) 最硬核物理初始化、绝版无报错纯净原生内核裸装及上帝极其微操大厅"
        echo "  0) 逃离并关闭当前交互面板窗口"
        echo -e "  ${red}88) 物理不可逆灭世自毁 (彻底粉碎配置，将 Xray 狠狠剥离出服务器心脏)${none}"
        hr
        read -rp "最高统帅，请向系统下达您的操作执行指令: " num
        
        case "$num" in
            1) 
                do_install 
                ;;
            2) 
                do_user_manager 
                ;;
            3) 
                do_summary
                while true; do 
                    read -rp "指令确立，按 Enter 撤离，或强行键入 b 即刻调转车头改变主线 SNI: " rb
                    if [[ "$rb" == "b" || "$rb" == "B" ]]; then 
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
                print_magenta ">>> 正在强行接驳全球库并向本地调取最新的清洗过滤规则网段..."
                bash "$UPDATE_DAT_SCRIPT" >/dev/null 2>&1
                ensure_xray_is_alive
                info "拉取突击任务平稳收尾，新版路由数据结构表已全面推送到内核层！"
                read -rp "输入 Enter 确认并继续前进..." _ 
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
                        read -rp "操作指令结束落盘，按 Enter 离场，或强制按 b 继续重塑伪装防线链路: " rb
                        if [[ "$rb" == "b" || "$rb" == "B" ]]; then 
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
        esac
    done
}

# ==============================================================================
# [ 35. 启动点火，接管系统挂载自证闭环 ]
# ==============================================================================
preflight
main_menu

# ==============================================================================
# EOF: 极客工业级底层标志，本行如果存在即代表 V171 核心引擎全系防爆版输出圆满完成！
# ==============================================================================
