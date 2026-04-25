#!/usr/bin/env bash
# ============================================================
# 脚本名称: ex145.sh (The Apex Vanguard - Project Genesis V145 [Absolute Horizon])
# 快捷方式: xrv
# 终极修复宣言: 
#   1. 1GB Swap 信仰：实装纯正 1GB 永久 Swap 管理器 (自动校验、卸载溢出、写死 fstab)。
#   2. 内核编译防爆：撤销对内核 CPU 架构 (x86-64-v*) 的鲁莽干预，修复 L1_CACHE_SHIFT 空指针报错；仅静默卸载证书与注入 BBR3。
#   3. 物理装甲回归：百万并发锁 (limits.conf)、60+ 行极限 Sysctl 参数、cc1.sh 守护进程与 do_change_dns 底层锁死完整保留。
#   4. 核心大一统：28 项全域微操矩阵、回落探针 (菜单 8)、8 行军规排版、ShortId 防漂移联动删除无一缺席。
#   5. 拒绝代码阉割：所有 jq 管道流与多行判断逻辑全面铺开，严禁任何降低可读性的单行压缩。
# ============================================================

# 必须用 bash 运行
if test -z "$BASH_VERSION"; then
    echo "错误: 请用 bash 运行此脚本: bash ex145.sh"
    exit 1
fi

# -- 颜色定义 --
red='\033[31m'
yellow='\033[33m'
gray='\033[90m'
green='\033[92m'
blue='\033[94m'
magenta='\033[95m'
cyan='\033[96m'
none='\033[0m'

# -- 全局路径与变量 --
XRAY_BIN="/usr/local/bin/xray"
CONFIG_DIR="/usr/local/etc/xray"
CONFIG="$CONFIG_DIR/config.json"
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

# 初始化基础环境
mkdir -p "$CONFIG_DIR" "$DAT_DIR" "$SCRIPT_DIR" "$FLAGS_DIR" 2>/dev/null
touch "$USER_SNI_MAP" "$USER_TIME_MAP"

# -- 辅助输出 --
print_red()     { echo -e "${red}$*${none}"; }
print_green()   { echo -e "${green}$*${none}"; }
print_yellow()  { echo -e "${yellow}$*${none}"; }
print_magenta() { echo -e "${magenta}$*${none}"; }
print_cyan()    { echo -e "${cyan}$*${none}"; }

info()  { echo -e "${green}✓${none} $*"; }
warn()  { echo -e "${yellow}!${none} $*"; }
error() { echo -e "${red}✗${none} $*";   }
die()   { echo -e "\n${red}致命错误${none} $*\n"; exit 1; }

title() {
    echo -e "\n${blue}===================================================${none}"
    echo -e "  ${cyan}$*${none}"
    echo -e "${blue}===================================================${none}"
}
hr() { 
    echo -e "${gray}---------------------------------------------------${none}" 
}

_get_ip() {
    if [ -z "$GLOBAL_IP" ]; then
        GLOBAL_IP=$( (curl -s -4 --connect-timeout 5 https://api.ipify.org || curl -s -4 --connect-timeout 5 https://ifconfig.me || echo "获取失败") | tr -d '\r\n' )
    fi
    echo "$GLOBAL_IP"
}

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

_safe_jq_write() {
    local filter="$1"
    local tmp=$(mktemp)
    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$CONFIG" >/dev/null 2>&1
        fix_permissions
        return 0
    fi
    rm -f "$tmp" >/dev/null 2>&1
    return 1
}

# 恢复系统级百万并发权限锁定
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

# -- V145 新增: 1GB 永久 Swap 自动管理器 --
check_and_create_1gb_swap() {
    print_magenta ">>> 正在执行 1GB 永久 Swap 基线校验..."
    local SWAP_FILE="/swapfile"
    
    # 提取当前 /swapfile 的大小 (KB)
    local CURRENT_SWAP=$(swapon --show=NAME,KBYTES --noheadings 2>/dev/null | grep "$SWAP_FILE" | awk '{print $2}')
    
    # 判断是否在 1GB (1048576 KB) 左右的容差范围内
    if [[ -n "$CURRENT_SWAP" ]] && [[ "$CURRENT_SWAP" =~ ^1048 ]]; then
        info "系统已存在规范的 1GB 永久 Swap，基线校验通过。"
    else
        warn "检测到 Swap 缺失或容量不符，正在重置并强制分配 1GB 永久 Swap 空间..."
        swapoff -a 2>/dev/null || true
        sed -i '/swapfile/d' /etc/fstab
        rm -f "$SWAP_FILE" 2>/dev/null
        
        # 使用 dd 强行开辟 1024MB 空间
        dd if=/dev/zero of="$SWAP_FILE" bs=1M count=1024 status=none
        chmod 600 "$SWAP_FILE"
        mkswap "$SWAP_FILE" >/dev/null 2>&1
        swapon "$SWAP_FILE" >/dev/null 2>&1
        
        # 写入 fstab 实现永久生效
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
        info "1GB 永久 Swap 已重建并写入系统底盘。"
    fi
}

preflight() {
    if test "$EUID" -ne 0; then die "此脚本必须以 root 身份运行"; fi
    if ! command -v systemctl >/dev/null 2>&1; then die "系统缺少 systemctl"; fi
    
    local need="jq curl wget xxd unzip qrencode vnstat cron openssl coreutils sed e2fsprogs pkg-config iproute2 ethtool bc bison flex"
    local install_list=""
    for i in $need; do 
        if ! command -v "$i" >/dev/null 2>&1; then 
            install_list="$install_list $i"
        fi
    done

    if test -n "$install_list"; then
        info "同步工业级依赖: $install_list"
        export DEBIAN_FRONTEND=noninteractive
        (apt-get update -y || yum makecache -y) >/dev/null 2>&1
        (apt-get install -y $install_list || yum install -y $install_list) >/dev/null 2>&1
        systemctl start vnstat >/dev/null 2>&1 || true
        systemctl start cron >/dev/null 2>&1 || systemctl start crond >/dev/null 2>&1 || true
    fi

    if test -f "$SCRIPT_PATH"; then
        \cp -f "$SCRIPT_PATH" "$SYMLINK" >/dev/null 2>&1
        chmod +x "$SYMLINK" >/dev/null 2>&1
        hash -r 2>/dev/null
    fi
    SERVER_IP=$(_get_ip)
}

install_update_dat() {
    cat > "$UPDATE_DAT_SCRIPT" <<'UPDSH'
#!/usr/bin/env bash
XRAY_DAT_DIR="/usr/local/share/xray"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat"
curl -sL --connect-timeout 10 -o "$XRAY_DAT_DIR/geoip.dat.new" "$GEOIP_URL" && mv -f "$XRAY_DAT_DIR/geoip.dat.new" "$XRAY_DAT_DIR/geoip.dat"
curl -sL --connect-timeout 10 -o "$XRAY_DAT_DIR/geosite.dat.new" "$GEOSITE_URL" && mv -f "$XRAY_DAT_DIR/geosite.dat.new" "$XRAY_DAT_DIR/geosite.dat"
UPDSH
    chmod +x "$UPDATE_DAT_SCRIPT"
    (crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT" | grep -v "/bin/systemctl restart xray"; 
     echo "0 3 * * * $UPDATE_DAT_SCRIPT >/dev/null 2>&1"; 
     echo "10 3 * * * /bin/systemctl restart xray >/dev/null 2>&1") | crontab -
    info "已配置自动热更: 每天凌晨 3:00 更新 Geo 库"
}

# 内部 DNS 解析物理强锁
do_change_dns() {
    title "修改系统 DNS 解析 (底层锁定防漂移)"
    local release=""
    if [ -f /etc/redhat-release ]; then 
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

    if [ ! -e '/usr/sbin/resolvconf' ] && [ ! -e '/sbin/resolvconf' ]; then
        print_yellow "正在安装必要的环境依赖 resolvconf..."
        if [ "${release}" == "centos" ]; then 
            yum -y install resolvconf > /dev/null 2>&1
        else 
            export DEBIAN_FRONTEND=noninteractive
            apt-get update > /dev/null 2>&1
            apt-get -y install resolvconf > /dev/null 2>&1
        fi
    fi
    
    systemctl stop systemd-resolved 2>/dev/null || true
    systemctl disable systemd-resolved 2>/dev/null || true
    systemctl stop resolvconf.service > /dev/null 2>&1 || true
    systemctl start resolvconf.service > /dev/null 2>&1 || true
    systemctl enable resolvconf.service > /dev/null 2>&1 || true

    local nameserver=""
    local IPcheck="0"
    while [ "$IPcheck" == "0" ]; do
        read -rp "请输入要强行锁定的新 Nameserver IP (例如 8.8.8.8): " nameserver
        if [[ $nameserver =~ ^([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])\.([0-9]{1,2}|1[0-9][0-9]|2[0-4][0-9]|25[0-5])$ ]]; then
            IPcheck="1"
        else 
            print_red "IPv4 格式错误！"
        fi
    done

    chattr -i /etc/resolv.conf 2>/dev/null || true
    rm -f /etc/resolv.conf 2>/dev/null || true
    mv /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true
    echo "nameserver $nameserver" > /etc/resolv.conf
    chattr +i /etc/resolv.conf 2>/dev/null || true
    
    mkdir -p /etc/resolvconf/resolv.conf.d 2>/dev/null
    echo "nameserver $nameserver" > /etc/resolvconf/resolv.conf.d/head 2>/dev/null
    systemctl restart resolvconf.service >/dev/null 2>&1
    
    info "已锁定 DNS 流向为 $nameserver"
}

run_sni_scanner() {
    title "雷达嗅探：130+ 实体矩阵与国内连通性探测"
    print_yellow ">>> 扫描中... (随时按回车键可立即中止)\n"
    mkdir -p "$CONFIG_DIR" 2>/dev/null
    
    local sni_list=(
        "www.apple.com" "support.apple.com" "developer.apple.com" "id.apple.com" "icloud.apple.com" 
        "www.microsoft.com" "login.microsoftonline.com" "portal.azure.com" "support.microsoft.com" "office.com" 
        "www.intel.com" "downloadcenter.intel.com" "ark.intel.com" "www.amd.com" "drivers.amd.com" 
        "www.dell.com" "support.dell.com" "www.hp.com" "support.hp.com" "developers.hp.com" 
        "www.bmw.com" "www.mercedes-benz.com" "global.toyota" "www.honda.com" "www.volkswagen.com" 
        "www.nike.com" "www.adidas.com" "www.zara.com" "www.ikea.com" "www.shell.com" 
        "www.bp.com" "www.ge.com" "www.hsbc.com" "www.morganstanley.com" "www.msc.com" 
        "www.sony.com" "www.canon.com" "www.nintendo.com" "www.unilever.com" "www.loreal.com" 
        "www.hermes.com" "www.louisvuitton.com" "www.dior.com" "www.gucci.com" "www.coca-cola.com" 
        "www.tesla.com" "s0.awsstatic.com" "www.nvidia.com" "www.samsung.com" "www.oracle.com" 
        "addons.mozilla.org" "www.airbnb.com.sg" "mit.edu" "stanford.edu" "www.lufthansa.com" 
        "www.singaporeair.com" "www.specialized.com" "www.logitech.com" "www.razer.com" "www.corsair.com"
    )

    local sni_string=$(printf "%s\n" "${sni_list[@]}")
    if command -v shuf >/dev/null 2>&1; then 
        sni_string=$(echo "$sni_string" | shuf)
    else 
        sni_string=$(echo "$sni_string" | awk 'BEGIN{srand()} {print rand()"\t"$0}' | sort -n | cut -f2-)
    fi

    local tmp_sni=$(mktemp /tmp/sni_test.XXXXXX)
    for sni in $sni_string; do
        read -t 0.1 -n 1 key
        if test $? -eq 0; then 
            echo -e "\n${yellow}已手动中止...${none}"
            break
        fi

        local time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni")
        local ms=$(echo "$time_raw" | awk '{print int($1 * 1000)}')

        if test "${ms:-0}" -gt 0; then
            if curl -sI -m 2 --connect-timeout 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray"; then 
                continue
            fi
            local doh_res=$(curl -s --connect-timeout 2 "https://dns.alidns.com/resolve?name=$sni&type=1" 2>/dev/null)
            local dns_cn=$(echo "$doh_res" | jq -r '.Answer[]? | select(.type==1 or .type==5) | .data' 2>/dev/null | tail -1)
            
            local status_cn=""
            local p_type="NORM"
            if test -z "$dns_cn" || test "$dns_cn" = "127.0.0.1" || test "$dns_cn" = "0.0.0.0" || test "$dns_cn" = "::1"; then 
                status_cn="${red}阻断${none}"
                p_type="BLOCK"
            else
                local loc=$(curl -s --connect-timeout 2 "https://ipinfo.io/$dns_cn/country" 2>/dev/null | tr -d ' \n')
                if test "$loc" = "CN"; then 
                    status_cn="${green}直通${none} (CDN)"
                    p_type="CN_CDN"
                else 
                    status_cn="${green}直通${none} (原生)"
                    p_type="NORM"
                fi
            fi
            echo -e " ${green}存活${none} $sni : ${yellow}${ms}ms${none} | $status_cn"
            if test "$p_type" != "BLOCK"; then 
                echo "$ms $sni $p_type" >> "$tmp_sni"
            fi
        fi
    done

    if test -s "$tmp_sni"; then
        grep "NORM" "$tmp_sni" | sort -n | head -n 20 | awk '{print $2, $1}' > "$SNI_CACHE_FILE"
        local count=$(wc -l < "$SNI_CACHE_FILE" 2>/dev/null)
        if test "${count:-0}" -lt 20; then 
            grep "CN_CDN" "$tmp_sni" | sort -n | head -n $((20 - ${count:-0})) | awk '{print $2, $1}' >> "$SNI_CACHE_FILE"
        fi
    else
        print_red "探测全灭，采用微软保底。"
        echo "www.microsoft.com 999" > "$SNI_CACHE_FILE"
    fi
    rm -f "$tmp_sni"
}

verify_sni_strict() {
    print_magenta "\n>>> 质检 $1 (TLS 1.3/h2/OCSP)..."
    local out=$(echo "Q" | timeout 5 openssl s_client -connect "$1:443" -alpn h2 -tls1_3 -status 2>&1)
    local pass=1
    if ! echo "$out" | grep -qi "TLSv1.3"; then pass=0; fi
    if ! echo "$out" | grep -qi "ALPN, server accepted to use h2"; then pass=0; fi
    if ! echo "$out" | grep -qi "OCSP response:"; then pass=0; fi
    if [ "$pass" -eq 0 ]; then 
        print_red " ✗ 质检未通过"
    else 
        print_green " ✓ 质检通过"
    fi
    return $pass
}

choose_sni() {
    while true; do
        if test -f "$SNI_CACHE_FILE"; then
            echo -e "\n  ${cyan}【战备缓存：极速 Top 20】${none}"
            local idx=1
            while read -r s t; do 
                echo -e "  $idx) $s (${cyan}${t}ms${none})"
                idx=$((idx + 1))
            done < "$SNI_CACHE_FILE"
            
            echo -e "  ${yellow}r) 重新扫描矩阵${none}"
            echo "  m) 矩阵模式 (多选防封)"
            echo "  0) 手动输入域名"
            read -rp "  请选择: " sel
            sel=${sel:-1}
            
            if test "$sel" = "q"; then return 1; fi
            if test "$sel" = "r"; then 
                run_sni_scanner
                continue
            fi
            
            if test "$sel" = "m"; then
                read -rp "输入序号 (空格分隔): " m_sel
                local arr=()
                for i in $m_sel; do 
                    local picked=$(awk "NR==$i {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null)
                    if test -n "$picked"; then 
                        arr+=("$picked")
                    fi
                done
                if test ${#arr[@]} -eq 0; then 
                    error "无效"
                    continue
                fi
                BEST_SNI="${arr[0]}"
                local jq_args=()
                for s in "${arr[@]}"; do 
                    jq_args+=("\"$s\"")
                done
                SNI_JSON_ARRAY=$(IFS=,; echo "${jq_args[*]}")
            elif test "$sel" = "0"; then 
                read -rp "自定义域名: " d
                BEST_SNI=${d:-www.microsoft.com}
                SNI_JSON_ARRAY="\"$BEST_SNI\""
            else
                local picked=$(awk "NR==$sel {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null)
                if test -n "$picked"; then 
                    BEST_SNI="$picked"
                else 
                    BEST_SNI=$(awk "NR==1 {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null)
                fi
                SNI_JSON_ARRAY="\"$BEST_SNI\""
            fi
            
            if verify_sni_strict "$BEST_SNI"; then 
                break
            else 
                continue
            fi
        else 
            run_sni_scanner
        fi
    done
    return 0
}

validate_port() {
    local p="$1"
    if test -z "$p"; then return 1; fi
    local check=$(echo "$p" | tr -d '0-9')
    if test -n "$check"; then return 1; fi
    if test "${p:-0}" -ge 1 2>/dev/null && test "${p:-0}" -le 65535 2>/dev/null; then
        if ss -tuln | grep -q ":${p} "; then 
            print_red "端口占用！"
            return 1
        fi
        return 0
    fi
    return 1
}

do_update_core() {
    title "Xray 核心无损热更"
    bash -c "$(curl -fsSL --connect-timeout 10 https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1
    fix_xray_systemd_limits
    systemctl restart xray >/dev/null 2>&1
    local cur_ver=$($XRAY_BIN version 2>/dev/null | head -n1 | awk '{print $2}')
    info "已更新至: ${cyan}$cur_ver${none}"
    read -rp "按 Enter 继续..." _
}

gen_ss_pass() { head -c 24 /dev/urandom | base64 | tr -d '=/+\n' | head -c 24; }

_select_ss_method() {
    echo -e "  ${cyan}选择 SS 加密方式：${none}" >&2
    echo "  1) aes-256-gcm  2) aes-128-gcm  3) chacha20-ietf-poly1305" >&2
    read -rp "  编号: " mc >&2
    case "${mc:-1}" in 
        2) echo "aes-128-gcm" ;; 
        3) echo "chacha20-ietf-poly1305" ;; 
        *) echo "aes-256-gcm" ;; 
    esac
}

# -- 编译与优化区 --
do_install_xanmod_main_official() {
    title "系统飞升：安装官方预编译 XANMOD"
    if [ "$(uname -m)" != "x86_64" ]; then 
        error "仅支持 x86_64"
        return
    fi
    local cpu_level_script="/tmp/check_x86-64_psabi.sh"
    wget -qO "$cpu_level_script" https://dl.xanmod.org/check_x86-64_psabi.sh
    local cpu_level=$(awk -f "$cpu_level_script" | grep -oE 'x86-64-v[1-4]' | grep -oE '[1-4]' | tail -n 1)
    rm -f "$cpu_level_script"
    if [ -z "$cpu_level" ]; then 
        cpu_level=1
    fi
    local pkg_name="linux-xanmod-x64v${cpu_level}"
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1
    apt-get install -y gnupg gnupg2 curl sudo wget e2fsprogs >/dev/null 2>&1
    echo 'deb http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-kernel.list
    wget -qO - https://dl.xanmod.org/gpg.key | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/xanmod-kernel.gpg
    
    apt-get update -y
    apt-get install -y "$pkg_name"
    
    if [ $? -ne 0 ] && [ "$cpu_level" == "4" ]; then 
        pkg_name="linux-xanmod-x64v3"
        apt-get install -y "$pkg_name"
    fi
    if command -v update-grub >/dev/null 2>&1; then 
        update-grub
    else 
        apt-get install -y grub2-common
        update-grub
    fi
    
    info "XANMOD 部署就绪！10秒后重启..."
    sleep 10
    reboot
}

# V145 完美修复: 拒绝修改架构等级，解决 L1_CACHE_SHIFT 报错
do_xanmod_compile() {
    title "源码编译安装 Xanmod 内核 + TCP BBRv3"
    warn "警告: 源码编译耗时 30分钟 ~ 2小时，此操作具有较高风险！"
    read -rp "确定要继续吗？(y/n): " confirm
    if [[ "$confirm" != "y" ]]; then return; fi
    
    print_magenta ">>> [1/5] 安装底层编译核心依赖包..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y build-essential libncurses-dev bison flex libssl-dev libelf-dev bc git curl dwarves debhelper rsync python3 libdw-dev zstd lz4 cpio pkg-config
    
    # 物理调用 1GB Swap 确保编译不会宕机
    check_and_create_1gb_swap

    print_magenta ">>> [2/5] 获取 Xanmod 源码 (内置 BBR3 补丁)..."
    mkdir -p /usr/src
    cd /usr/src
    rm -rf linux-xanmod
    git clone --depth=1 https://gitlab.com/xanmod/linux.git linux-xanmod
    cd linux-xanmod

    print_magenta ">>> [3/5] 初始化原生基底并执行防爆破注入..."
    # 使用 Xanmod 原生的架构配置，绝不乱碰 CONFIG_GENERIC_CPU 防止缓存指针错乱！
    make defconfig
    
    # BBR3 物理注入
    ./scripts/config --enable CONFIG_TCP_CONG_BBR
    ./scripts/config --disable CONFIG_DEFAULT_CUBIC
    ./scripts/config --enable CONFIG_DEFAULT_BBR
    
    # 绝杀 Debian 编译签名与调试信息陷阱
    ./scripts/config --disable SYSTEM_TRUSTED_KEYS
    ./scripts/config --disable SYSTEM_REVOCATION_KEYS
    ./scripts/config --disable DEBUG_INFO_BTF
    ./scripts/config --disable DEBUG_INFO
    
    yes "" | make olddefconfig

    print_magenta ">>> [4/5] 全核全速编译中，请耐心等待 (切勿中断)..."
    local THREADS=$(nproc)
    local TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_MEM" -lt 2000 ] && [ "$THREADS" -gt 2 ]; then 
        THREADS=2
    fi
    
    if ! make -j${THREADS} bindeb-pkg; then
        error "内核编译遭遇致命错误，流程已熔断！请上翻查看 make 报错信息。"
        read -rp "按 Enter 返回主菜单..." _
        return 1
    fi

    print_magenta ">>> [5/5] 安装生成的 Linux 核心驱动包..."
    cd /usr/src
    dpkg -i linux-image-*xanmod*.deb linux-headers-*xanmod*.deb 2>/dev/null || true
    update-grub 2>/dev/null || true
    
    info "源码编译已封顶！底层驱动架构已焕然一新。"
    info "请务必重启服务器以应用崭新的 BBR3 协议栈！"
    read -rp "按 Enter 返回主菜单..." _
}

do_perf_tuning() {
    title "极限压榨：低延迟系统底层网络栈调优"
    warn "警告: 注入全域极限参数后将重启！"
    read -rp "确定要继续吗？(y/n): " confirm
    if [[ "$confirm" != "y" ]]; then return; fi
    
    local current_scale=$(sysctl -n net.ipv4.tcp_adv_win_scale 2>/dev/null || echo "1")
    local current_app=$(sysctl -n net.ipv4.tcp_app_win 2>/dev/null || echo "31")
    echo -e "  当前 tcp_adv_win_scale: ${cyan}${current_scale}${none} (建议 1)"
    echo -e "  当前 tcp_app_win: ${cyan}${current_app}${none} (建议 31)"
    read -rp "请输入 tcp_adv_win_scale (-2 到 2，回车默认): " new_scale
    new_scale=${new_scale:-$current_scale}
    read -rp "请输入 tcp_app_win (1 到 31，回车默认): " new_app
    new_app=${new_app:-$current_app}

    systemctl stop net-speeder >/dev/null 2>&1 || true
    killall net-speeder >/dev/null 2>&1 || true
    systemctl disable net-speeder >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/net-speeder.service
    systemctl daemon-reload >/dev/null 2>&1
    rm -rf /root/net-speeder

    truncate -s 0 /etc/sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-sysctl.conf 2>/dev/null || true
    truncate -s 0 /etc/sysctl.d/99-network-optimized.conf 2>/dev/null || true
    rm -f /etc/sysctl.d/99-bbr*.conf /etc/sysctl.d/99-ipv6-disable.conf /etc/sysctl.d/99-pro*.conf /etc/sysctl.d/99-xanmod-bbr3.conf /usr/lib/sysctl.d/50-pid-max.conf /usr/lib/sysctl.d/99-protect-links.conf 2>/dev/null
    
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

    if ! grep -q "pam_limits.so" /etc/pam.d/common-session; then 
        echo "session required pam_limits.so" >> /etc/pam.d/common-session
    fi
    if ! grep -q "pam_limits.so" /etc/pam.d/common-session-noninteractive; then 
        echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive
    fi
    
    echo "DefaultLimitNOFILE=1000000" >> /etc/systemd/system.conf
    echo "DefaultLimitNPROC=1000000" >> /etc/systemd/system.conf

    local target_qdisc="fq"
    if [ "$(check_cake_state)" = "true" ]; then 
        target_qdisc="cake"
    fi

    # 全量 60+ 行基线参数
    cat > /etc/sysctl.d/99-network-optimized.conf << EOF
net.core.default_qdisc = ${target_qdisc}
net.ipv4.tcp_congestion_control = bbr
net.ipv4.neigh.default.base_reachable_time_ms = 60000
net.ipv4.neigh.default.mcast_solicit = 2
net.ipv4.neigh.default.retrans_time_ms = 500
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_sack = 1
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
net.core.dev_weight = 64
net.core.dev_weight_tx_bias = 1
net.core.dev_weight_rx_bias = 1
net.core.netdev_budget = 300
net.ipv4.igmp_max_memberships = 200
net.ipv4.route.flush = 1
net.ipv4.tcp_slow_start_after_idle = 0
vm.swappiness = 1
fs.file-max = 1048576
fs.nr_open = 1048576
fs.inotify.max_user_instances = 262144
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
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_max_orphans = 262144
net.core.optmem_max = 3276800
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_reordering = 3
net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_tso_win_divisor = 6
kernel.pid_max = 4194304
kernel.threads-max = 85536
net.ipv4.neigh.default.gc_thresh1 = 1024
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv4.neigh.default.gc_stale_time = 100
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
net.unix.max_dgram_qlen = 130000
net.core.busy_poll = 50
net.core.busy_read = 0
net.ipv4.tcp_notsent_lowat = 16384
vm.vfs_cache_pressure = 10
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.ip_forward = 1
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
fs.aio-max-nr = 262144
kernel.msgmax = 655350
kernel.msgmnb = 655350
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
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
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
    sysctl --system >/dev/null 2>&1
    
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    if [ -n "$IFACE" ]; then
        cat > /usr/local/bin/nic-optimize.sh <<'EONIC'
#!/bin/bash
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
ethtool -K $IFACE lro off rx-gro-hw off 2>/dev/null || true
ethtool -C $IFACE adaptive-rx off rx-usecs 0 tx-usecs 0 2>/dev/null || true
EONIC
        chmod +x /usr/local/bin/nic-optimize.sh
        
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
        systemctl daemon-reload
        systemctl enable nic-optimize.service
        systemctl start nic-optimize.service
        
        cat > /usr/local/bin/rps-optimize.sh <<'EOF'
#!/bin/bash
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
CPU=$(nproc)
CPU_MASK=$(printf "%x" $(( (1<<CPU)-1 )))
RX_QUEUES=$(ls /sys/class/net/$IFACE/queues/ 2>/dev/null | grep rx- | wc -l)

for RX in /sys/class/net/$IFACE/queues/rx-*; do 
    echo $CPU_MASK > $RX/rps_cpus 2>/dev/null || true
done
for TX in /sys/class/net/$IFACE/queues/tx-*; do 
    echo $CPU_MASK > $TX/xps_cpus 2>/dev/null || true
done

sysctl -w net.core.rps_sock_flow_entries=131072 2>/dev/null
if [ "${RX_QUEUES:-0}" -gt 0 ]; then
    FLOW_PER_QUEUE=$((65535 / RX_QUEUES))
    for RX in /sys/class/net/$IFACE/queues/rx-*; do 
        echo $FLOW_PER_QUEUE > $RX/rps_flow_cnt 2>/dev/null || true
    done
fi
EOF
        chmod +x /usr/local/bin/rps-optimize.sh
        
        cat > /etc/systemd/system/rps-optimize.service <<EOF
[Unit]
Description=RPS RFS Network CPU Optimization
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/rps-optimize.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable rps-optimize.service
        systemctl start rps-optimize.service
    fi

    info "极致低延迟参数注入完成！系统将在 30 秒后重启..."
    sleep 30
    reboot
}

do_txqueuelen_opt() {
    title "TX Queue 调优"
    local IP_CMD=$(command -v ip)
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    if [ -z "$IFACE" ]; then 
        error "无法识别网卡。"
        return 1
    fi
    $IP_CMD link set "$IFACE" txqueuelen 2000
    
    cat > /etc/systemd/system/txqueue.service <<EOF
[Unit]
Description=Set TX Queue Length
After=network-online.target
[Service]
Type=oneshot
ExecStart=$IP_CMD link set $IFACE txqueuelen 2000
RemainAfterExit=true
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable txqueue >/dev/null 2>&1
    systemctl start txqueue
    info "已应用 txqueuelen 2000"
    read -rp "Enter 继续..." _
}

config_cake_advanced() {
    clear
    title "CAKE 高阶调度配置"
    local current_opts="无"
    if [ -f "$CAKE_OPTS_FILE" ]; then 
        current_opts=$(cat "$CAKE_OPTS_FILE")
    fi
    echo -e "  当前参数: ${cyan}${current_opts}${none}\n"
    
    read -rp "  带宽限速 (如 900Mbit, 0 禁用): " c_bw
    read -rp "  Overhead (如 48, 0 禁用): " c_oh
    read -rp "  MPU (如 84, 0 禁用): " c_mpu
    
    echo "  RTT模式: 1) internet  2) oceanic  3) satellite"
    read -rp "  选择(默认2): " rtt_sel
    case "${rtt_sel:-2}" in 
        1) c_rtt="internet" ;; 
        2) c_rtt="oceanic" ;; 
        3) c_rtt="satellite" ;; 
        *) c_rtt="oceanic" ;; 
    esac
    
    echo "  识别模式: 1) diffserv4  2) besteffort"
    read -rp "  选择(默认2): " diff_sel
    case "${diff_sel:-2}" in 
        1) c_diff="diffserv4" ;; 
        2) c_diff="besteffort" ;; 
        *) c_diff="besteffort" ;; 
    esac

    local final_opts=""
    if [ -n "$c_bw" ] && [ "$c_bw" != "0" ]; then final_opts="$final_opts bandwidth $c_bw"; fi
    if [ -n "$c_oh" ] && [ "$c_oh" != "0" ]; then final_opts="$final_opts overhead $c_oh"; fi
    if [ -n "$c_mpu" ] && [ "$c_mpu" != "0" ]; then final_opts="$final_opts mpu $c_mpu"; fi
    
    final_opts="$final_opts $c_rtt $c_diff"
    final_opts=$(echo "$final_opts" | sed 's/^ *//')
    
    if [ -z "$final_opts" ]; then 
        rm -f "$CAKE_OPTS_FILE"
        info "已清除 CAKE 参数。"
    else 
        echo "$final_opts" > "$CAKE_OPTS_FILE"
        info "已保存: $final_opts"
    fi
    
    _apply_cake_live
    read -rp "Enter 继续..." _
}

# 状态探针
check_mph_state() { 
    local state=$(jq -r '.routing.domainMatcher // "false"' "$CONFIG" 2>/dev/null)
    if [ "$state" = "mph" ]; then echo "true"; else echo "false"; fi
}
check_maxtime_state() { 
    local state=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff // "false"' "$CONFIG" 2>/dev/null | head -n 1)
    if [ "$state" = "60000" ]; then echo "true"; else echo "false"; fi
}
check_routeonly_state() { 
    local state=$(jq -r '.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1)
    if [ "$state" = "true" ]; then echo "true"; else echo "false"; fi
}
check_sniff_state() { 
    local state=$(jq -r '.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.metadataOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1)
    if [ "$state" = "true" ]; then echo "true"; else echo "false"; fi
}
check_affinity_state() { 
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if grep -q "^CPUAffinity=" "$limit_file" 2>/dev/null; then echo "true"; else echo "false"; fi
}
check_buffer_state() { 
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if grep -q "^Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" "$limit_file" 2>/dev/null; then echo "true"; else echo "false"; fi
}
check_dnsmasq_state() { 
    if systemctl is-active dnsmasq >/dev/null 2>&1 && grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null; then echo "true"; else echo "false"; fi
}
check_thp_state() { 
    if [ ! -f "/sys/kernel/mm/transparent_hugepage/enabled" ] || [ ! -w "/sys/kernel/mm/transparent_hugepage/enabled" ]; then echo "unsupported"; return; fi
    if grep -q '\[never\]' /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null; then echo "true"; else echo "false"; fi
}
check_mtu_state() { 
    if [ ! -f "/proc/sys/net/ipv4/tcp_mtu_probing" ] || [ ! -w "/proc/sys/net/ipv4/tcp_mtu_probing" ]; then echo "unsupported"; return; fi
    if [ "$(sysctl -n net.ipv4.tcp_mtu_probing 2>/dev/null)" = "1" ]; then echo "true"; else echo "false"; fi
}
check_cpu_state() { 
    if [ ! -d "/sys/devices/system/cpu/cpu0/cpufreq" ] || [ ! -w "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor" ]; then echo "unsupported"; return; fi
    if grep -q 'performance' /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null; then echo "true"; else echo "false"; fi
}
check_ring_state() { 
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    if [ -z "$IFACE" ] || ! command -v ethtool >/dev/null 2>&1 || ! ethtool -g "$IFACE" >/dev/null 2>&1; then echo "unsupported"; return; fi
    local curr_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Current hardware settings" | grep "RX:" | head -1 | awk '{print $2}')
    if [ -z "$curr_rx" ]; then echo "unsupported"; return; fi
    if [ "$curr_rx" = "512" ]; then echo "true"; else echo "false"; fi
}
check_zram_state() { 
    if ! modprobe -n zram >/dev/null 2>&1 && ! lsmod | grep -q zram; then echo "unsupported"; return; fi
    if swapon --show | grep -q 'zram'; then echo "true"; else echo "false"; fi
}
check_journal_state() { 
    if [ ! -f "/etc/systemd/journald.conf" ]; then echo "unsupported"; return; fi
    if grep -q '^Storage=volatile' /etc/systemd/journald.conf 2>/dev/null; then echo "true"; else echo "false"; fi
}
check_process_priority_state() { 
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if [ ! -f "$limit_file" ]; then echo "false"; return; fi
    if grep -q "^OOMScoreAdjust=-500" "$limit_file" 2>/dev/null; then echo "true"; else echo "false"; fi
}
check_cake_state() { 
    if sysctl net.core.default_qdisc 2>/dev/null | grep -q 'cake'; then echo "true"; else echo "false"; fi
}

check_ackfilter_state() { 
    if [ -f "$FLAGS_DIR/ack_filter" ]; then echo "true"; else echo "false"; fi
}
check_ecn_state() { 
    if [ -f "$FLAGS_DIR/ecn" ]; then echo "true"; else echo "false"; fi
}
check_wash_state() { 
    if [ -f "$FLAGS_DIR/wash" ]; then echo "true"; else echo "false"; fi
}

check_gso_off_state() { 
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    if ! command -v ethtool >/dev/null 2>&1; then echo "unsupported"; return; fi
    local eth_info=$(ethtool -k "$IFACE" 2>/dev/null)
    if [ -z "$eth_info" ]; then echo "unsupported"; return; fi
    
    # 记住用户的警告：机器不能强制禁用 GSO/GRO (fixed)
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
    local CORES=$(nproc)
    if [ "$CORES" -lt 2 ]; then echo "unsupported"; return; fi
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    local irq=$(grep "$IFACE" /proc/interrupts 2>/dev/null | head -1 | awk '{print $1}' | tr -d ':')
    if [ -n "$irq" ]; then 
        local mask=$(cat /proc/irq/$irq/smp_affinity 2>/dev/null | tr -d '0')
        if [ "$mask" = "1" ]; then echo "true"; else echo "false"; fi
    else 
        echo "false"
    fi
}

update_hw_boot_script() {
    cat << 'EOF' > /usr/local/bin/xray-hw-tweaks.sh
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
if [ -z "$IFACE" ]; then sleep 3; IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}'); fi

for bql in /sys/class/net/$IFACE/queues/tx-*/byte_queue_limits/limit_max; do
    if [ -f "$bql" ]; then echo "3000" > "$bql" 2>/dev/null; fi
done
EOF
    
    if [ "$(check_thp_state)" = "true" ]; then 
        echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null" >> /usr/local/bin/xray-hw-tweaks.sh
        echo "echo never > /sys/kernel/mm/transparent_hugepage/defrag 2>/dev/null" >> /usr/local/bin/xray-hw-tweaks.sh
    fi
    
    if [ "$(check_cpu_state)" = "true" ] && [ -d "/sys/devices/system/cpu/cpu0/cpufreq" ]; then 
        echo 'for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do if [ -f "$cpu" ]; then echo performance > "$cpu" 2>/dev/null || true; fi; done' >> /usr/local/bin/xray-hw-tweaks.sh
    fi
    
    if [ "$(check_ring_state)" = "true" ]; then 
        echo "ethtool -G \$IFACE rx 512 tx 512 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
    fi
    
    local gso_state=$(check_gso_off_state)
    if [ "$gso_state" = "true" ]; then 
        echo "ethtool -K \$IFACE gro off gso off tso off 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
    elif [ "$gso_state" = "false" ]; then 
        echo "ethtool -K \$IFACE gro on gso on tso on 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
    fi
    
    echo "CAKE_OPTS=\"\"" >> /usr/local/bin/xray-hw-tweaks.sh
    echo "if [ -f \"/usr/local/etc/xray/cake_opts.txt\" ]; then CAKE_OPTS=\$(cat \"/usr/local/etc/xray/cake_opts.txt\"); fi" >> /usr/local/bin/xray-hw-tweaks.sh
    echo "ACK_FLAG=\"\"; if [ -f \"/usr/local/etc/xray/flags/ack_filter\" ]; then ACK_FLAG=\"ack-filter\"; fi" >> /usr/local/bin/xray-hw-tweaks.sh
    echo "ECN_FLAG=\"\"; if [ -f \"/usr/local/etc/xray/flags/ecn\" ]; then ECN_FLAG=\"ecn\"; fi" >> /usr/local/bin/xray-hw-tweaks.sh
    echo "WASH_FLAG=\"\"; if [ -f \"/usr/local/etc/xray/flags/wash\" ]; then WASH_FLAG=\"wash\"; fi" >> /usr/local/bin/xray-hw-tweaks.sh

    if [ "$(check_cake_state)" = "true" ]; then 
        echo "tc qdisc replace dev \$IFACE root cake \$CAKE_OPTS \$ACK_FLAG \$ECN_FLAG \$WASH_FLAG 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
    fi
    
    if [ "$(check_irq_state)" = "true" ]; then
        echo "systemctl stop irqbalance 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
        echo "for irq in \$(grep \"\$IFACE\" /proc/interrupts 2>/dev/null | awk '{print \$1}' | tr -d ':'); do echo 1 > /proc/irq/\$irq/smp_affinity 2>/dev/null || true; done" >> /usr/local/bin/xray-hw-tweaks.sh
    fi
    
    chmod +x /usr/local/bin/xray-hw-tweaks.sh
    
    cat << 'EOF' > /etc/systemd/system/xray-hw-tweaks.service
[Unit]
Description=Xray Hardware Tweaks
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
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable xray-hw-tweaks.service >/dev/null 2>&1
}

_apply_cake_live() {
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    if [ "$(check_cake_state)" = "true" ]; then
        local base_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null)
        local f_ack=""
        if [ "$(check_ackfilter_state)" = "true" ]; then f_ack="ack-filter"; fi
        local f_ecn=""
        if [ "$(check_ecn_state)" = "true" ]; then f_ecn="ecn"; fi
        local f_wash=""
        if [ "$(check_wash_state)" = "true" ]; then f_wash="wash"; fi
        
        tc qdisc replace dev "$IFACE" root cake $base_opts $f_ack $f_ecn $f_wash 2>/dev/null || true
    fi
    update_hw_boot_script
}

_toggle_affinity_on() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if [ -f "$limit_file" ]; then
        sed -i '/^CPUAffinity=/d' "$limit_file"
        sed -i '/^Environment="GOMAXPROCS=/d' "$limit_file"
        local CORES=$(nproc)
        local TARGET_CPU="0"
        if [ "$CORES" -ge 2 ]; then TARGET_CPU="1"; fi
        
        echo "CPUAffinity=$TARGET_CPU" >> "$limit_file"
        echo "Environment=\"GOMAXPROCS=1\"" >> "$limit_file"
        systemctl daemon-reload
    fi
}

_toggle_affinity_off() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if [ -f "$limit_file" ]; then 
        sed -i '/^CPUAffinity=/d' "$limit_file"
        sed -i '/^Environment="GOMAXPROCS=/d' "$limit_file"
        systemctl daemon-reload
    fi
}

toggle_buffer() {
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if [ -f "$limit_file" ]; then
        if [ "$(check_buffer_state)" = "true" ]; then 
            sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file"
        else 
            sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file"
            echo "Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" >> "$limit_file"
        fi
        systemctl daemon-reload
    fi
}

toggle_dnsmasq() {
    if [ "$(check_dnsmasq_state)" = "true" ]; then
        systemctl stop dnsmasq
        systemctl disable dnsmasq
        chattr -i /etc/resolv.conf 2>/dev/null || true
        rm -f /etc/resolv.conf 2>/dev/null || true
        
        if [ -f /etc/resolv.conf.bak ]; then 
            mv /etc/resolv.conf.bak /etc/resolv.conf
        else 
            echo "nameserver 8.8.8.8" > /etc/resolv.conf
        fi
        
        systemctl enable systemd-resolved >/dev/null 2>&1 || true
        systemctl start systemd-resolved >/dev/null 2>&1 || true
        
        _safe_jq_write '
          .dns = {
            "servers": [
              "https://8.8.8.8/dns-query",
              "https://1.1.1.1/dns-query",
              "https://doh.opendns.com/dns-query"
            ],
            "queryStrategy":"UseIP"
          }
        '
    else
        export DEBIAN_FRONTEND=noninteractive
        apt-get update || yum makecache
        apt-get install -y dnsmasq || yum install -y dnsmasq
        
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
        systemctl enable dnsmasq
        systemctl restart dnsmasq
        
        chattr -i /etc/resolv.conf 2>/dev/null || true
        if [ ! -f /etc/resolv.conf.bak ]; then 
            cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true
        fi
        rm -f /etc/resolv.conf 2>/dev/null || true
        echo "nameserver 127.0.0.1" > /etc/resolv.conf
        chattr +i /etc/resolv.conf 2>/dev/null || true
        
        _safe_jq_write '
          .dns = {
            "servers": ["127.0.0.1"],
            "queryStrategy":"UseIP"
          }
        '
    fi
}

toggle_thp() { 
    if [ "$(check_thp_state)" = "true" ]; then 
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
    if [ "$(check_mtu_state)" = "true" ]; then 
        sed -i 's/^net.ipv4.tcp_mtu_probing.*/net.ipv4.tcp_mtu_probing = 0/' "$conf" 2>/dev/null || true
    else 
        if grep -q "net.ipv4.tcp_mtu_probing" "$conf" 2>/dev/null; then 
            sed -i 's/^net.ipv4.tcp_mtu_probing.*/net.ipv4.tcp_mtu_probing = 1/' "$conf"
        else 
            echo "net.ipv4.tcp_mtu_probing = 1" >> "$conf"
        fi
    fi
    sysctl -p "$conf" >/dev/null 2>&1
}

toggle_cpu() { 
    if [ "$(check_cpu_state)" = "unsupported" ]; then return; fi
    if [ "$(check_cpu_state)" = "true" ]; then 
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do 
            if [ -f "$cpu" ]; then echo schedutil > "$cpu" 2>/dev/null || true; fi
        done
    else 
        for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do 
            if [ -f "$cpu" ]; then echo performance > "$cpu" 2>/dev/null || true; fi
        done
    fi
    update_hw_boot_script
}

toggle_ring() { 
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    if [ "$(check_ring_state)" = "unsupported" ]; then return; fi
    if [ "$(check_ring_state)" = "true" ]; then 
        local max_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Pre-set maximums" | grep "RX:" | head -1 | awk '{print $2}')
        if [ -n "$max_rx" ]; then 
            ethtool -G "$IFACE" rx "$max_rx" tx "$max_rx" 2>/dev/null || true
        fi
    else 
        ethtool -G "$IFACE" rx 512 tx 512 2>/dev/null || true
    fi
    update_hw_boot_script
}

toggle_gso_off() { 
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    if [ "$(check_gso_off_state)" = "unsupported" ]; then 
        warn "网卡底层驱动锁死 (fixed)，无法强行打散，已安全跳过以防断流"
        sleep 2
        return
    fi
    if [ "$(check_gso_off_state)" = "true" ]; then 
        ethtool -K "$IFACE" gro on gso on tso on 2>/dev/null || true
    else 
        ethtool -K "$IFACE" gro off gso off tso off 2>/dev/null || true
    fi
    update_hw_boot_script
}

toggle_zram() {
    if [ "$(check_zram_state)" = "unsupported" ]; then return; fi
    if [ "$(check_zram_state)" = "true" ]; then 
        swapoff /dev/zram0 2>/dev/null || true
        rmmod zram 2>/dev/null || true
        systemctl disable xray-zram.service --now 2>/dev/null || true
        rm -f /etc/systemd/system/xray-zram.service /usr/local/bin/xray-zram.sh
    else
        local TOTAL_MEM=$(free -m | awk '/Mem/{print $2}')
        local ZRAM_SIZE
        if [ "$TOTAL_MEM" -lt 500 ]; then ZRAM_SIZE=$((TOTAL_MEM * 2))
        elif [ "$TOTAL_MEM" -lt 1024 ]; then ZRAM_SIZE=$((TOTAL_MEM * 3 / 2))
        else ZRAM_SIZE=$TOTAL_MEM; fi
        
        cat > /usr/local/bin/xray-zram.sh <<EOFZ
#!/bin/bash
modprobe zram num_devices=1
echo "lz4" > /sys/block/zram0/comp_algorithm 2>/dev/null || true
echo "${ZRAM_SIZE}M" > /sys/block/zram0/disksize
mkswap /dev/zram0
swapon -p 100 /dev/zram0
EOFZ
        chmod +x /usr/local/bin/xray-zram.sh
        
        cat > /etc/systemd/system/xray-zram.service <<EOFZ
[Unit]
Description=Xray ZRAM
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/xray-zram.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOFZ
        systemctl daemon-reload
        systemctl enable xray-zram.service
        systemctl start xray-zram.service
    fi
}

toggle_journal() { 
    local conf="/etc/systemd/journald.conf"
    if [ "$(check_journal_state)" = "unsupported" ]; then return; fi
    if [ "$(check_journal_state)" = "true" ]; then 
        sed -i 's/^Storage=volatile/#Storage=auto/' "$conf" 2>/dev/null || true
    else 
        if grep -q "^#Storage=" "$conf" 2>/dev/null; then 
            sed -i 's/^#Storage=.*/Storage=volatile/' "$conf"
        elif grep -q "^Storage=" "$conf" 2>/dev/null; then 
            sed -i 's/^Storage=.*/Storage=volatile/' "$conf"
        else 
            echo "Storage=volatile" >> "$conf"
        fi
    fi
    systemctl restart systemd-journald
}

toggle_process_priority() { 
    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
    if [ ! -f "$limit_file" ]; then return; fi
    if grep -q "^OOMScoreAdjust=-500" "$limit_file"; then 
        sed -i '/^OOMScoreAdjust=/d' "$limit_file"
        sed -i '/^IOSchedulingClass=/d' "$limit_file"
        sed -i '/^IOSchedulingPriority=/d' "$limit_file"
    else 
        echo "OOMScoreAdjust=-500" >> "$limit_file"
        echo "IOSchedulingClass=realtime" >> "$limit_file"
        echo "IOSchedulingPriority=2" >> "$limit_file"
    fi
    systemctl daemon-reload
}

toggle_cake() {
    local conf="/etc/sysctl.d/99-network-optimized.conf"
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    local cake_opts=""
    
    if [ -f "$CAKE_OPTS_FILE" ]; then 
        cake_opts=$(cat "$CAKE_OPTS_FILE")
    fi
    
    if [ "$(check_cake_state)" = "true" ]; then 
        sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = fq/' "$conf" 2>/dev/null || true
        sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1
        tc qdisc replace dev "$IFACE" root fq 2>/dev/null || true
    else 
        sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = cake/' "$conf" 2>/dev/null || true
        if ! grep -q "net.core.default_qdisc" "$conf" 2>/dev/null; then 
            echo "net.core.default_qdisc = cake" >> "$conf"
        fi
        modprobe sch_cake || true
        sysctl -w net.core.default_qdisc=cake >/dev/null 2>&1
        
        local ack_flag=""
        if [ "$(check_ackfilter_state)" = "true" ]; then ack_flag="ack-filter"; fi
        local ecn_flag=""
        if [ "$(check_ecn_state)" = "true" ]; then ecn_flag="ecn"; fi
        local wash_flag=""
        if [ "$(check_wash_state)" = "true" ]; then wash_flag="wash"; fi
        
        tc qdisc replace dev "$IFACE" root cake $cake_opts $ack_flag $ecn_flag $wash_flag 2>/dev/null || true
    fi
    update_hw_boot_script
}

toggle_ackfilter() { 
    if [ "$(check_ackfilter_state)" = "true" ]; then rm -f "$FLAGS_DIR/ack_filter"; else touch "$FLAGS_DIR/ack_filter"; fi
    if [ "$(check_cake_state)" = "false" ]; then warn "必须先开启 CAKE"; sleep 2; return; fi
    _apply_cake_live
}
toggle_ecn() { 
    if [ "$(check_ecn_state)" = "true" ]; then rm -f "$FLAGS_DIR/ecn"; else touch "$FLAGS_DIR/ecn"; fi
    if [ "$(check_cake_state)" = "false" ]; then warn "必须先开启 CAKE"; sleep 2; return; fi
    _apply_cake_live
}
toggle_wash() { 
    if [ "$(check_wash_state)" = "true" ]; then rm -f "$FLAGS_DIR/wash"; else touch "$FLAGS_DIR/wash"; fi
    if [ "$(check_cake_state)" = "false" ]; then warn "必须先开启 CAKE"; sleep 2; return; fi
    _apply_cake_live
}

toggle_irq() {
    if [ "$(check_irq_state)" = "unsupported" ]; then return; fi
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    local CORES=$(nproc)
    local DEFAULT_MASK=$(printf "%x" $(( (1<<CORES)-1 )))
    
    if [ "$(check_irq_state)" = "true" ]; then
        for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':'); do 
            echo "$DEFAULT_MASK" > /proc/irq/$irq/smp_affinity 2>/dev/null || true
        done
        systemctl start irqbalance 2>/dev/null || true
        systemctl enable irqbalance 2>/dev/null || true
    else
        systemctl stop irqbalance 2>/dev/null || true
        systemctl disable irqbalance 2>/dev/null || true
        for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':'); do 
            echo 1 > /proc/irq/$irq/smp_affinity 2>/dev/null || true
        done
    fi
    update_hw_boot_script
}

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
    
    local has_reality=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .protocol' "$CONFIG" 2>/dev/null | head -n 1)
    if [ -n "$has_reality" ]; then
        _safe_jq_write '
          .inbounds = [
              .inbounds[]? | if (.protocol == "vless" and .streamSettings.security == "reality") then
                  .streamSettings.realitySettings = (.streamSettings.realitySettings // {}) |
                  .streamSettings.realitySettings.maxTimeDiff = 60000
              else . end
          ]
        '
    fi
    
    if [ "$(check_dnsmasq_state)" = "true" ]; then
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
    if [ -f "$limit_file" ]; then
        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file"
        echo "Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" >> "$limit_file"
        
        local TOTAL_MEM=$(free -m | awk '/Mem/{print $2}')
        local DYNAMIC_GOGC=100
        if [ "$TOTAL_MEM" -ge 1800 ]; then 
            DYNAMIC_GOGC=1000
        elif [ "$TOTAL_MEM" -ge 900 ]; then 
            DYNAMIC_GOGC=500
        else 
            DYNAMIC_GOGC=300
        fi
        
        sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=$DYNAMIC_GOGC\"/" "$limit_file"
        systemctl daemon-reload
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
    if [ -f "$limit_file" ]; then
        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$limit_file"
        sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=100\"/" "$limit_file"
        systemctl daemon-reload
    fi
}

do_app_level_tuning_menu() {
    while true; do
        clear
        title "全域 28 项极限微操 (Xray 提速底牌 & 系统内核微操)"
        if ! test -f "$CONFIG"; then 
            error "未发现配置，请先执行核心安装！"
            read -rp "Enter..." _
            return
        fi

        # App 1-11
        local out_fastopen=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpFastOpen // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        local out_keepalive=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpKeepAliveIdle // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        local sniff_status=$(jq -r '.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.metadataOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        local dns_status=$(jq -r '.dns.queryStrategy // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        local policy_status=$(jq -r '.policy.levels["0"].connIdle // "false"' "$CONFIG" 2>/dev/null | head -n 1)
        local affinity_state=$(check_affinity_state)
        local mph_state=$(check_mph_state)
        local maxtime_state=$(check_maxtime_state)
        local routeonly_status=$(check_routeonly_state)
        local buffer_state=$(check_buffer_state)
        
        local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
        local gc_status="未知"
        if [ -f "$limit_file" ]; then
            gc_status=$(awk -F'=' '/^Environment="GOGC=/ {print $3}' "$limit_file" | tr -d '"' | head -1)
            gc_status=${gc_status:-"默认 100"}
        fi

        # System 12-25
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

        # 缺省探测
        local app_off_count=0
        if [ "$out_fastopen" != "true" ]; then app_off_count=$((app_off_count+1)); fi
        if [ "$out_keepalive" != "30" ]; then app_off_count=$((app_off_count+1)); fi
        if [ "$sniff_status" != "true" ]; then app_off_count=$((app_off_count+1)); fi
        if [ "$dns_status" != "UseIP" ]; then app_off_count=$((app_off_count+1)); fi
        if [[ "$gc_status" == *"100" ]]; then app_off_count=$((app_off_count+1)); fi
        if [ "$policy_status" != "60" ]; then app_off_count=$((app_off_count+1)); fi
        if [ "$affinity_state" != "true" ]; then app_off_count=$((app_off_count+1)); fi
        if [ "$mph_state" != "true" ]; then app_off_count=$((app_off_count+1)); fi
        if [ "$routeonly_status" != "true" ]; then app_off_count=$((app_off_count+1)); fi
        if [ "$buffer_state" != "true" ]; then app_off_count=$((app_off_count+1)); fi
        
        local has_reality=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .protocol' "$CONFIG" 2>/dev/null | head -n 1)
        if [ -n "$has_reality" ]; then 
            if [ "$maxtime_state" != "true" ]; then 
                app_off_count=$((app_off_count+1))
            fi
        fi

        local sys_off_count=0
        if [ "$dnsmasq_state" = "false" ]; then sys_off_count=$((sys_off_count+1)); fi
        if [ "$thp_state" = "false" ]; then sys_off_count=$((sys_off_count+1)); fi
        if [ "$mtu_state" = "false" ]; then sys_off_count=$((sys_off_count+1)); fi
        if [ "$cpu_state" = "false" ]; then sys_off_count=$((sys_off_count+1)); fi
        if [ "$ring_state" = "false" ]; then sys_off_count=$((sys_off_count+1)); fi
        if [ "$zram_state" = "false" ]; then sys_off_count=$((sys_off_count+1)); fi
        if [ "$journal_state" = "false" ]; then sys_off_count=$((sys_off_count+1)); fi
        if [ "$prio_state" = "false" ]; then sys_off_count=$((sys_off_count+1)); fi
        if [ "$cake_state" = "false" ]; then sys_off_count=$((sys_off_count+1)); fi
        if [ "$irq_state" = "false" ]; then sys_off_count=$((sys_off_count+1)); fi
        if [ "$gso_off_state" = "false" ] && [ "$gso_off_state" != "unsupported" ]; then sys_off_count=$((sys_off_count+1)); fi
        if [ "$ackfilter_state" = "false" ]; then sys_off_count=$((sys_off_count+1)); fi
        if [ "$ecn_state" = "false" ]; then sys_off_count=$((sys_off_count+1)); fi
        if [ "$wash_state" = "false" ]; then sys_off_count=$((sys_off_count+1)); fi

        # UI 状态映射
        local s1; if [ "$out_fastopen" = "true" ]; then s1="${cyan}已开启${none}"; else s1="${gray}未开启${none}"; fi
        local s2; if [ "$out_keepalive" = "30" ]; then s2="${cyan}已开启 (30s/15s)${none}"; else s2="${gray}系统默认${none}"; fi
        local s3; if [ "$sniff_status" = "true" ]; then s3="${cyan}已开启${none}"; else s3="${gray}未开启${none}"; fi
        local s4; if [ "$dns_status" = "UseIP" ]; then s4="${cyan}已开启${none}"; else s4="${gray}未开启${none}"; fi
        local s6; if [ "$policy_status" = "60" ]; then s6="${cyan}已开启 (闲置60s/握手3s)${none}"; else s6="${gray}默认 300s 慢回收${none}"; fi
        local s7; if [ "$affinity_state" = "true" ]; then s7="${cyan}已锁死单核 (零切换)${none}"; else s7="${gray}默认 (系统调度)${none}"; fi
        local s8; if [ "$mph_state" = "true" ]; then s8="${cyan}O(1) 预编译算法就绪${none}"; else s8="${gray}默认 (Linear/AC机)${none}"; fi
        
        local s9
        if [ -z "$has_reality" ]; then 
            s9="${gray}无 Reality (已跳过)${none}"
        else 
            if [ "$maxtime_state" = "true" ]; then 
                s9="${cyan}绝对防线 (60s)${none}"
            else 
                s9="${gray}默认 (不设防)${none}"
            fi
        fi
        
        local s10; if [ "$routeonly_status" = "true" ]; then s10="${cyan}盲走快车道已通车${none}"; else s10="${gray}默认全量嗅探${none}"; fi
        local s11; if [ "$buffer_state" = "true" ]; then s11="${cyan}巨型重卡池 (64K)${none}"; else s11="${gray}默认轻型内存分配${none}"; fi
        
        local s12; if [ "$dnsmasq_state" = "true" ]; then s12="${cyan}极速内存解析中 (0.1ms)${none}"; else s12="${gray}依赖原生 DoH${none}"; fi
        local s13; if [ "$thp_state" = "true" ]; then s13="${cyan}已关闭 THP${none}"; elif [ "$thp_state" = "unsupported" ]; then s13="${gray}不支持${none}"; else s13="${gray}系统默认${none}"; fi
        local s14; if [ "$mtu_state" = "true" ]; then s14="${cyan}智能探测中${none}"; elif [ "$mtu_state" = "unsupported" ]; then s14="${gray}不支持${none}"; else s14="${gray}未开启${none}"; fi
        local s15; if [ "$cpu_state" = "true" ]; then s15="${cyan}全核火力全开${none}"; elif [ "$cpu_state" = "unsupported" ]; then s15="${gray}不支持${none}"; else s15="${gray}节能待机${none}"; fi
        local s16; if [ "$ring_state" = "true" ]; then s16="${cyan}已反向收缩${none}"; elif [ "$ring_state" = "unsupported" ]; then s16="${gray}不支持${none}"; else s16="${gray}系统大缓冲${none}"; fi
        local s17; if [ "$zram_state" = "true" ]; then s17="${cyan}已挂载 ZRAM${none}"; elif [ "$zram_state" = "unsupported" ]; then s17="${gray}不支持${none}"; else s17="${gray}未启用${none}"; fi
        local s18; if [ "$journal_state" = "true" ]; then s18="${cyan}纯内存极速化${none}"; elif [ "$journal_state" = "unsupported" ]; then s18="${gray}不支持${none}"; else s18="${gray}磁盘 IO 写入中${none}"; fi
        local s19; if [ "$prio_state" = "true" ]; then s19="${cyan}OOM免死 / IO抢占${none}"; else s19="${gray}系统默认调度${none}"; fi
        local s20; if [ "$cake_state" = "true" ]; then s20="${cyan}CAKE 削峰填谷中${none}"; else s20="${gray}默认 FQ 队列${none}"; fi
        local s21; if [ "$irq_state" = "true" ]; then s21="${cyan}多核 RPS 散列 / 单核硬中断隔离${none}"; elif [ "$irq_state" = "unsupported" ]; then s21="${gray}不支持(单核)${none}"; else s21="${gray}默认平衡调度${none}"; fi
        
        local s22
        if [ "$gso_off_state" = "true" ]; then 
            s22="${cyan}已打散 (零延迟电竞模式)${none}"
        elif [ "$gso_off_state" = "unsupported" ]; then 
            s22="${gray}不支持 (底层驱动锁死，已安全跳过)${none}"
        else 
            s22="${gray}未打散 (系统默认万兆聚合)${none}"
        fi
        
        local s23; if [ "$ackfilter_state" = "true" ]; then s23="${cyan}绞杀空 ACK 释放上行${none}"; else s23="${gray}默认不干预${none}"; fi
        local s24; if [ "$ecn_state" = "true" ]; then s24="${cyan}显式拥塞警告 (0 丢包平滑降速)${none}"; else s24="${gray}默认 (传统暴力丢包)${none}"; fi
        local s25; if [ "$wash_state" = "true" ]; then s25="${cyan}强力清除干扰乱码${none}"; else s25="${gray}默认不干预${none}"; fi

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
        echo -e "  21) 开启或关闭【网卡硬中断物理隔离】(RPS 散列 / Hard IRQ)        | 状态: $s21"
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
        read -rp "请选择: " app_opt

        case "$app_opt" in
            1)
                if [ "$out_fastopen" = "true" ]; then
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
                systemctl restart xray >/dev/null 2>&1
                read -rp "按 Enter 继续..." _
                ;;
            2)
                if [ "$out_keepalive" = "30" ]; then
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
                systemctl restart xray >/dev/null 2>&1
                read -rp "按 Enter 继续..." _
                ;;
            3)
                if [ "$sniff_status" = "true" ]; then
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
                systemctl restart xray >/dev/null 2>&1
                read -rp "按 Enter 继续..." _
                ;;
            4)
                if [ "$dns_status" = "UseIP" ]; then
                    _safe_jq_write 'del(.dns)'
                else
                    if [ "$dnsmasq_state" = "true" ]; then
                        _safe_jq_write '.dns = {"servers":["127.0.0.1"], "queryStrategy":"UseIP"}'
                    else
                        _safe_jq_write '.dns = {"servers":["https://8.8.8.8/dns-query","https://1.1.1.1/dns-query"], "queryStrategy":"UseIP"}'
                    fi
                fi
                systemctl restart xray >/dev/null 2>&1
                read -rp "按 Enter 继续..." _
                ;;
            5)
                local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
                if [ -f "$limit_file" ]; then
                    local TOTAL_MEM=$(free -m | awk '/Mem/{print $2}')
                    local DYNAMIC_GOGC=100
                    if [ "$TOTAL_MEM" -ge 1800 ]; then 
                        DYNAMIC_GOGC=1000
                    elif [ "$TOTAL_MEM" -ge 900 ]; then 
                        DYNAMIC_GOGC=500
                    else 
                        DYNAMIC_GOGC=300
                    fi
                    
                    if grep -q "Environment=\"GOGC=" "$limit_file"; then
                        if [[ "$gc_status" == *"100" ]]; then
                            sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=$DYNAMIC_GOGC\"/" "$limit_file"
                        else
                            sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=100\"/" "$limit_file"
                        fi
                    else
                        echo "Environment=\"GOGC=$DYNAMIC_GOGC\"" >> "$limit_file"
                    fi
                    systemctl daemon-reload
                    systemctl restart xray >/dev/null 2>&1
                fi
                read -rp "按 Enter 继续..." _
                ;;
            6)
                if [ "$policy_status" = "60" ]; then
                    _safe_jq_write 'del(.policy)'
                else
                    _safe_jq_write '.policy = {"levels":{"0":{"handshake":3,"connIdle":60}},"system":{"statsInboundDownlink":false,"statsInboundUplink":false}}'
                fi
                systemctl restart xray >/dev/null 2>&1
                read -rp "按 Enter 继续..." _
                ;;
            7)
                if [ "$affinity_state" = "true" ]; then
                    _toggle_affinity_off
                else
                    _toggle_affinity_on
                fi
                systemctl restart xray >/dev/null 2>&1
                read -rp "按 Enter 继续..." _
                ;;
            8)
                if [ "$mph_state" = "true" ]; then
                    _safe_jq_write 'del(.routing.domainMatcher)'
                else
                    _safe_jq_write '.routing = (.routing // {}) | .routing.domainMatcher = "mph"'
                fi
                systemctl restart xray >/dev/null 2>&1
                read -rp "按 Enter 继续..." _
                ;;
            9)
                if [ -n "$has_reality" ]; then
                    if [ "$maxtime_state" = "true" ]; then
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
                    systemctl restart xray >/dev/null 2>&1
                fi
                read -rp "按 Enter 继续..." _
                ;;
            10)
                if [ "$routeonly_status" = "true" ]; then
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
                systemctl restart xray >/dev/null 2>&1
                read -rp "按 Enter 继续..." _
                ;;
            11)
                toggle_buffer
                systemctl restart xray >/dev/null 2>&1
                read -rp "按 Enter 继续..." _
                ;;
            12) toggle_dnsmasq; read -rp "按 Enter 继续..." _ ;;
            13) toggle_thp; read -rp "按 Enter 继续..." _ ;;
            14) toggle_mtu; read -rp "按 Enter 继续..." _ ;;
            15) toggle_cpu; read -rp "按 Enter 继续..." _ ;;
            16) toggle_ring; read -rp "按 Enter 继续..." _ ;;
            17) toggle_zram; read -rp "按 Enter 继续..." _ ;;
            18) toggle_journal; read -rp "按 Enter 继续..." _ ;;
            19) toggle_process_priority; read -rp "按 Enter 继续..." _ ;;
            20) toggle_cake; read -rp "按 Enter 继续..." _ ;;
            21) toggle_irq; read -rp "按 Enter 继续..." _ ;;
            22) 
                if [ "$gso_off_state" = "unsupported" ]; then
                    warn "当前网卡底层驱动锁死 (fixed)，无法更改卸载状态！"
                    sleep 2
                else
                    toggle_gso_off
                    read -rp "按 Enter 继续..." _ 
                fi
                ;;
            23) toggle_ackfilter; read -rp "按 Enter 继续..." _ ;;
            24) toggle_ecn; read -rp "按 Enter 继续..." _ ;;
            25) toggle_wash; read -rp "按 Enter 继续..." _ ;;
            26)
                if [ "$app_off_count" -gt 0 ]; then
                    print_magenta ">>> 全域开启 1-11 项..."
                    _turn_on_app
                    systemctl restart xray >/dev/null 2>&1
                    info "已开启！"
                else
                    print_magenta ">>> 全域恢复 1-11 项..."
                    _turn_off_app
                    systemctl restart xray >/dev/null 2>&1
                    info "已关闭！"
                fi
                read -rp "按 Enter 继续..." _
                ;;
            27)
                if [ "$sys_off_count" -gt 0 ]; then
                    if [ "$dnsmasq_state" = "false" ]; then toggle_dnsmasq; fi
                    if [ "$thp_state" = "false" ]; then toggle_thp; fi
                    if [ "$mtu_state" = "false" ]; then toggle_mtu; fi
                    if [ "$cpu_state" = "false" ]; then toggle_cpu; fi
                    if [ "$ring_state" = "false" ]; then toggle_ring; fi
                    if [ "$zram_state" = "false" ]; then toggle_zram; fi
                    if [ "$journal_state" = "false" ]; then toggle_journal; fi
                    if [ "$prio_state" = "false" ]; then toggle_process_priority; fi
                    if [ "$cake_state" = "false" ]; then toggle_cake; fi
                    if [ "$irq_state" = "false" ]; then toggle_irq; fi
                    if [ "$gso_off_state" = "false" ] && [ "$gso_off_state" != "unsupported" ]; then toggle_gso_off; fi
                    if [ "$ackfilter_state" = "false" ]; then toggle_ackfilter; fi
                    if [ "$ecn_state" = "false" ]; then toggle_ecn; fi
                    if [ "$wash_state" = "false" ]; then toggle_wash; fi
                    info "12-25 系统级满血激活！"
                else
                    if [ "$dnsmasq_state" = "true" ]; then toggle_dnsmasq; fi
                    if [ "$thp_state" = "true" ]; then toggle_thp; fi
                    if [ "$mtu_state" = "true" ]; then toggle_mtu; fi
                    if [ "$cpu_state" = "true" ]; then toggle_cpu; fi
                    if [ "$ring_state" = "true" ]; then toggle_ring; fi
                    if [ "$zram_state" = "true" ]; then toggle_zram; fi
                    if [ "$journal_state" = "true" ]; then toggle_journal; fi
                    if [ "$prio_state" = "true" ]; then toggle_process_priority; fi
                    if [ "$cake_state" = "true" ]; then toggle_cake; fi
                    if [ "$irq_state" = "true" ]; then toggle_irq; fi
                    if [ "$gso_off_state" = "true" ] && [ "$gso_off_state" != "unsupported" ]; then toggle_gso_off; fi
                    if [ "$ackfilter_state" = "true" ]; then toggle_ackfilter; fi
                    if [ "$ecn_state" = "true" ]; then toggle_ecn; fi
                    if [ "$wash_state" = "true" ]; then toggle_wash; fi
                    info "12-25 系统级已卸载！"
                fi
                read -rp "按 Enter 继续..." _
                ;;
            28)
                if [ "$((app_off_count + sys_off_count))" -gt 0 ]; then
                    if [ "$app_off_count" -gt 0 ]; then 
                        _turn_on_app
                    fi
                    if [ "$sys_off_count" -gt 0 ]; then
                        if [ "$dnsmasq_state" = "false" ]; then toggle_dnsmasq; fi
                        if [ "$thp_state" = "false" ]; then toggle_thp; fi
                        if [ "$mtu_state" = "false" ]; then toggle_mtu; fi
                        if [ "$cpu_state" = "false" ]; then toggle_cpu; fi
                        if [ "$ring_state" = "false" ]; then toggle_ring; fi
                        if [ "$zram_state" = "false" ]; then toggle_zram; fi
                        if [ "$journal_state" = "false" ]; then toggle_journal; fi
                        if [ "$prio_state" = "false" ]; then toggle_process_priority; fi
                        if [ "$cake_state" = "false" ]; then toggle_cake; fi
                        if [ "$irq_state" = "false" ]; then toggle_irq; fi
                        if [ "$gso_off_state" = "false" ] && [ "$gso_off_state" != "unsupported" ]; then toggle_gso_off; fi
                        if [ "$ackfilter_state" = "false" ]; then toggle_ackfilter; fi
                        if [ "$ecn_state" = "false" ]; then toggle_ecn; fi
                        if [ "$wash_state" = "false" ]; then toggle_wash; fi
                    fi
                else
                    _turn_off_app
                    if [ "$dnsmasq_state" = "true" ]; then toggle_dnsmasq; fi
                    if [ "$thp_state" = "true" ]; then toggle_thp; fi
                    if [ "$mtu_state" = "true" ]; then toggle_mtu; fi
                    if [ "$cpu_state" = "true" ]; then toggle_cpu; fi
                    if [ "$ring_state" = "true" ]; then toggle_ring; fi
                    if [ "$zram_state" = "true" ]; then toggle_zram; fi
                    if [ "$journal_state" = "true" ]; then toggle_journal; fi
                    if [ "$prio_state" = "true" ]; then toggle_process_priority; fi
                    if [ "$cake_state" = "true" ]; then toggle_cake; fi
                    if [ "$irq_state" = "true" ]; then toggle_irq; fi
                    if [ "$gso_off_state" = "true" ] && [ "$gso_off_state" != "unsupported" ]; then toggle_gso_off; fi
                    if [ "$ackfilter_state" = "true" ]; then toggle_ackfilter; fi
                    if [ "$ecn_state" = "true" ]; then toggle_ecn; fi
                    if [ "$wash_state" = "true" ]; then toggle_wash; fi
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

do_fallback_probe() {
    clear
    echo -e "\n\033[93m=== Xray Reality 回落限速 (Fallback Limit) 探针 ===\033[0m"
    jq -r '
      .inbounds[]? | select(.protocol=="vless" and .streamSettings.security=="reality") | .streamSettings.realitySettings | 
      "  [上传方向 (Upload)]\n    诱饵大小 (afterBytes) : \(.limitFallbackUpload.afterBytes // "未设置 (不限速)")\n    基准限速 (bytesPerSec) : \(.limitFallbackUpload.bytesPerSec // "未设置 (不限速)")\n  [下载方向 (Download)]\n    诱饵大小 (afterBytes) : \(.limitFallbackDownload.afterBytes // "未设置 (不限速)")\n    基准限速 (bytesPerSec) : \(.limitFallbackDownload.bytesPerSec // "未设置 (不限速)")"
    ' "$CONFIG" 2>/dev/null || echo -e "  \033[31m读取失败：未找到配置文件或 jq 解析错误\033[0m"
    echo ""
    read -rp "按 Enter 继续..." _
}

do_sys_init_menu() {
    while true; do
        title "初次安装、更新系统组件"
        echo "  1) 一键更新系统、校准时区、自动部署 1GB 永久 Swap 与清理守护"
        echo "  2) 修改系统 DNS 解析 (底层 resolvconf 强锁防漂移)"
        echo -e "  ${cyan}3) 必须先安装 XANMOD (main) 官方预编译内核 (推荐)${none}"
        echo "  4) 先完成3），编译安装 Xanmod 内核 + BBR3 (极客防爆版)"
        echo "  5) 网卡发送队列 (TX Queue) 深度调优 (2000 极速版)"
        echo "  6) 系统内核网络栈极限调优 (含 tcp_adv_win_scale 与 tcp_app_win)"
        echo "  7) 全域 28 项极限微操 (CAKE/RPS 散列/零拷贝/聚合反转)"
        echo -e "  ${cyan}8) 配置 CAKE 高阶调度参数 (Bandwidth/Overhead/MPU 针对虚机硬件卸载)${none}"
        echo "  0) 返回主菜单"
        hr
        read -rp "请选择: " sys_opt
        case "$sys_opt" in
            1) 
                print_magenta ">>> 拉取系统更新..."
                export DEBIAN_FRONTEND=noninteractive
                apt-get update -y
                apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" full-upgrade -y
                apt-get autoremove -y --purge
                apt-get install -y wget curl sudo socat ntpdate e2fsprogs pkg-config iproute2 ethtool
                timedatectl set-timezone Asia/Kuala_Lumpur
                ntpdate us.pool.ntp.org
                hwclock --systohc
                info "组件拉平，时区校准 Asia/Kuala_Lumpur！"
                
                check_and_create_1gb_swap
                
                print_magenta ">>> 注入定期清理任务 (cc1.sh) ..."
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
                info "系统级洁癖守护 (cc1.sh) 已部署！"
                read -rp "按 Enter 继续..." _ 
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
    if ! test -f "$CONFIG"; then return; fi
    title "The Apex Vanguard 节点详情中心"
    local ip=$(_get_ip)
    
    local vless_inbound=$(jq -c '.inbounds[]? | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1)
    if [ -n "$vless_inbound" ] && [ "$vless_inbound" != "null" ]; then
        local pbk=$(echo "$vless_inbound" | jq -r '.streamSettings.realitySettings.publicKey // "缺失"' 2>/dev/null)
        local main_sni=$(echo "$vless_inbound" | jq -r '.streamSettings.realitySettings.serverNames[0] // "缺失"' 2>/dev/null)
        local port=$(echo "$vless_inbound" | jq -r '.port // 443' 2>/dev/null)
        local shortIds_json=$(echo "$vless_inbound" | jq -c '.streamSettings.realitySettings.shortIds' 2>/dev/null)
        local clients_json=$(echo "$vless_inbound" | jq -c '.settings.clients[]?' 2>/dev/null)

        local idx=0
        while read -r client; do
            [ -z "$client" ] && break
            local uuid=$(echo "$client" | jq -r '.id' 2>/dev/null)
            local remark=$(echo "$client" | jq -r '.email // "无备注"' 2>/dev/null)
            local target_sni=$(grep "^$uuid|" "$USER_SNI_MAP" 2>/dev/null | cut -d'|' -f2)
            target_sni=${target_sni:-$main_sni}
            
            local sid=$(echo "$shortIds_json" | jq -r ".[$idx] // \"缺失\"" 2>/dev/null)
            
            hr
            print_green ">>> 用户备注: $remark"
            print_node_block "VLESS-Reality (Vision)" "$ip" "$port" "$target_sni" "$pbk" "$sid" "chrome" "$uuid"
            
            local link="vless://${uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${target_sni}&fp=chrome&pbk=${pbk}&sid=${sid}&type=tcp#${remark}"
            echo -e "\n  ${cyan}通用链接:${none}\n  $link\n"
            if command -v qrencode >/dev/null 2>&1; then qrencode -m 2 -t UTF8 "$link"; fi
            
            idx=$((idx + 1))
        done <<< "$clients_json"
    fi

    local ss_inbound=$(jq -c '.inbounds[]? | select(.protocol=="shadowsocks")' "$CONFIG" 2>/dev/null | head -n 1)
    if [ -n "$ss_inbound" ] && [ "$ss_inbound" != "null" ]; then
        local s_port=$(echo "$ss_inbound" | jq -r '.port' 2>/dev/null)
        local s_pass=$(echo "$ss_inbound" | jq -r '.settings.password' 2>/dev/null)
        local s_method=$(echo "$ss_inbound" | jq -r '.settings.method' 2>/dev/null)
        hr
        print_green ">>> 落地节点: Shadowsocks"
        printf "  ${yellow}%-15s${none} : %s\n" "协议框架" "Shadowsocks"
        printf "  ${yellow}%-15s${none} : %s\n" "外网IP" "$ip"
        printf "  ${yellow}%-15s${none} : %s\n" "端口" "$s_port"
        printf "  ${yellow}%-15s${none} : %s\n" "伪装SNI" "-"
        printf "  ${yellow}%-15s${none} : %s\n" "公钥(pbk)" "-"
        printf "  ${yellow}%-15s${none} : %s\n" "ShortId" "-"
        printf "  ${yellow}%-15s${none} : %s\n" "uTLS引擎" "-"
        printf "  ${yellow}%-15s${none} : %s\n" "用户 UUID" "${s_method}:${s_pass}"
        
        local b64=$(printf '%s:%s' "$s_method" "$s_pass" | base64 | tr -d '\n')
        local link_ss="ss://${b64}@${ip}:${s_port}#SS-Node"
        echo -e "\n  ${cyan}通用链接:${none}\n  $link_ss\n"
    fi
}

do_user_manager() {
    while true; do
        title "用户管理 (增删/导入 备注、UUID、ShortId)"
        if ! test -f "$CONFIG"; then error "未发现配置"; return; fi
        
        local clients=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .settings?.clients[]? | .id + "|" + (.email // "无备注")' "$CONFIG" 2>/dev/null)
        if test -z "$clients" || test "$clients" = "null"; then error "无 VLESS 节点"; return; fi
        
        local tmp_users="/tmp/xray_users.txt"
        echo "$clients" | awk -F'|' '{print NR"|"$1"|"$2}' > "$tmp_users"
        echo -e "当前用户列表："
        while IFS='|' read -r num uid remark; do
            local utime=$(grep "^$uid|" "$USER_TIME_MAP" 2>/dev/null | cut -d'|' -f2); utime=${utime:-"未知时间"}
            echo -e "  $num) 备注: ${cyan}$remark${none} | 时间: ${gray}$utime${none} | UUID: ${yellow}$uid${none}"
        done < "$tmp_users"
        hr
        echo "  a) 新增本网用户 (自动分配 UUID 与 ShortId)"
        echo "  m) 手动导入外部用户"
        echo "  s) 修改指定用户的专属 SNI"
        echo "  d) 序号删除用户 (安全物理销毁)"
        echo "  q) 退出"
        read -rp "指令: " uopt
        
        local ip=$(_get_ip)
        
        if test "$uopt" = "a"; then
            local nu=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || $XRAY_BIN uuid)
            local ns=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n')
            local ctime=$(date +"%Y-%m-%d %H:%M")
            read -rp "请输入专属节点备注: " u_remark; u_remark=${u_remark:-User-${ns}}
            
            cat > /tmp/new_client.json <<EOF
{
  "id": "$nu",
  "flow": "xtls-rprx-vision",
  "email": "$u_remark"
}
EOF
            _safe_jq_write '
              .inbounds = [
                  .inbounds[]? | if (.protocol == "vless") then
                      .settings.clients += [input]
                  else . end
              ]
            ' < /tmp/new_client.json
            
            _safe_jq_write --arg sid "$ns" '
              .inbounds = [
                  .inbounds[]? | if (.protocol == "vless") then
                      .streamSettings.realitySettings.shortIds += [$sid]
                  else . end
              ]
            '
            rm -f /tmp/new_client.json; echo "$nu|$ctime" >> "$USER_TIME_MAP"; systemctl restart xray >/dev/null 2>&1
            
            local vless_node=$(jq -c '.inbounds[]? | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1)
            local port=$(echo "$vless_node" | jq -r '.port')
            local sni=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.serverNames[0]')
            local pub=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.publicKey')
            
            info "用户分配成功！"
            hr; print_green ">>> 用户备注: $u_remark"
            print_node_block "VLESS-Reality (Vision)" "$ip" "$port" "$sni" "$pub" "$ns" "chrome" "$nu"
            local link="vless://${nu}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${ns}&type=tcp#${u_remark}"
            echo -e "\n  ${cyan}通用链接:${none}\n  $link\n"; command -v qrencode >/dev/null && qrencode -m 2 -t UTF8 "$link"
            read -rp "按 Enter 继续..." _
            
        elif test "$uopt" = "m"; then
            read -rp "外部用户备注: " m_remark; m_remark=${m_remark:-ImportedUser}
            read -rp "外部 UUID: " m_uuid; [ -z "$m_uuid" ] && continue
            read -rp "外部 ShortId: " m_sid; [ -z "$m_sid" ] && continue
            
            local ctime=$(date +"%Y-%m-%d %H:%M")
            cat > /tmp/new_client.json <<EOF
{
  "id": "$m_uuid",
  "flow": "xtls-rprx-vision",
  "email": "$m_remark"
}
EOF
            _safe_jq_write '
              .inbounds = [
                  .inbounds[]? | if (.protocol == "vless") then
                      .settings.clients += [input]
                  else . end
              ]
            ' < /tmp/new_client.json
            _safe_jq_write --arg sid "$m_sid" '
              .inbounds = [
                  .inbounds[]? | if (.protocol == "vless") then
                      .streamSettings.realitySettings.shortIds += [$sid]
                  else . end
              ]
            '
            rm -f /tmp/new_client.json; echo "$m_uuid|$ctime" >> "$USER_TIME_MAP"
            
            read -rp "指定专属 SNI? (回车默认): " m_sni
            if test -n "$m_sni"; then
                _safe_jq_write --arg sni "$m_sni" '
                  .inbounds = [
                      .inbounds[]? | if (.protocol == "vless") then
                          .streamSettings.realitySettings.serverNames += [$sni] | 
                          .streamSettings.realitySettings.serverNames |= unique
                      else . end
                  ]
                '
                sed -i "/^$m_uuid|/d" "$USER_SNI_MAP" 2>/dev/null; echo "$m_uuid|$m_sni" >> "$USER_SNI_MAP"
            else
                m_sni=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0] // empty' "$CONFIG" 2>/dev/null | head -n 1)
            fi
            systemctl restart xray >/dev/null 2>&1
            
            local vless_node=$(jq -c '.inbounds[]? | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1)
            local port=$(echo "$vless_node" | jq -r '.port')
            local pub=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.publicKey')
            
            info "导入成功！"
            hr; print_green ">>> 用户备注: $m_remark"
            print_node_block "VLESS-Reality (Vision)" "$ip" "$port" "$m_sni" "$pub" "$m_sid" "chrome" "$m_uuid"
            local link="vless://${m_uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${m_sni}&fp=chrome&pbk=${pub}&sid=${m_sid}&type=tcp#${m_remark}"
            echo -e "\n  ${cyan}通用链接:${none}\n  $link\n"; command -v qrencode >/dev/null && qrencode -m 2 -t UTF8 "$link"
            read -rp "按 Enter 继续..." _
            
        elif test "$uopt" = "s"; then
            read -rp "序号: " snum
            local target_uuid=$(awk -F'|' -v id="${snum:-0}" '$1==id {print $2}' "$tmp_users")
            local target_remark=$(awk -F'|' -v id="${snum:-0}" '$1==id {print $3}' "$tmp_users")
            if test -n "$target_uuid"; then
                read -rp "专属 SNI 域名: " u_sni
                if test -n "$u_sni"; then
                    _safe_jq_write --arg sni "$u_sni" '
                      .inbounds = [
                          .inbounds[]? | if (.protocol == "vless") then
                              .streamSettings.realitySettings.serverNames += [$sni] | 
                              .streamSettings.realitySettings.serverNames |= unique
                          else . end
                      ]
                    '
                    sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null; echo "$target_uuid|$u_sni" >> "$USER_SNI_MAP"
                    systemctl restart xray >/dev/null 2>&1; info "绑定 SNI: $u_sni"
                    
                    local vless_node=$(jq -c '.inbounds[]? | select(.protocol=="vless")' "$CONFIG" 2>/dev/null | head -n 1)
                    local port=$(echo "$vless_node" | jq -r '.port')
                    local idx=$((${snum:-0}-1))
                    local sid=$(echo "$vless_node" | jq -r ".streamSettings.realitySettings.shortIds[$idx] // empty")
                    local pub=$(echo "$vless_node" | jq -r '.streamSettings.realitySettings.publicKey // empty')
                    
                    hr; print_green ">>> 用户备注: $target_remark"
                    print_node_block "VLESS-Reality (Vision)" "$ip" "$port" "$u_sni" "$pub" "$sid" "chrome" "$target_uuid"
                    local link="vless://${target_uuid}@${ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${u_sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${target_remark}"
                    echo -e "\n  ${cyan}更新链接:${none}\n  $link\n"; command -v qrencode >/dev/null && qrencode -m 2 -t UTF8 "$link"
                    read -rp "按 Enter 继续..." _
                fi
            else error "无效序号。"; fi
            
        elif test "$uopt" = "d"; then
            read -rp "序号: " dnum; local total=$(wc -l < "$tmp_users" 2>/dev/null)
            if test "${total:-0}" -le 1; then error "必须至少保留一个核心用户！"
            else
                local target_uuid=$(awk -F'|' -v id="${dnum:-0}" '$1==id {print $2}' "$tmp_users")
                if test -n "$target_uuid"; then
                    local idx=$((${dnum:-0}-1))
                    _safe_jq_write --arg uid "$target_uuid" --argjson i "$idx" '
                        .inbounds = [
                            .inbounds[]? | if (.protocol == "vless") then
                                .settings.clients |= map(select(.id != $uid)) | 
                                .streamSettings.realitySettings.shortIds |= del(.[$i])
                            else . end
                        ]
                    '
                    sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null; sed -i "/^$target_uuid|/d" "$USER_TIME_MAP" 2>/dev/null
                    fix_permissions
                    systemctl restart xray >/dev/null 2>&1; info "物理销毁完成。"
                fi
            fi
        elif test "$uopt" = "q"; then rm -f "$tmp_users"; break; fi
    done
}

_global_block_rules() {
    while true; do
        title "屏蔽规则管理 (BT/广告双轨分离拦截)"
        if ! test -f "$CONFIG"; then 
            error "未发现配置"
            return
        fi
        
        local bt_en=$(jq -r '.routing.rules[]? | select(.protocol != null) | select(.protocol | index("bittorrent")) | ._enabled' "$CONFIG" 2>/dev/null | head -1)
        local ad_en=$(jq -r '.routing.rules[]? | select(.domain != null) | select(.domain | index("geosite:category-ads-all")) | ._enabled' "$CONFIG" 2>/dev/null | head -1)
        
        echo -e "  1) BT/PT 协议拦截   当前状态: ${yellow}${bt_en}${none}"
        echo -e "  2) 全球广告拦截     当前状态: ${yellow}${ad_en}${none}"
        echo "  0) 返回"
        read -rp "选择: " bc
        
        case "$bc" in
            1) 
                local nv="true"
                if test "$bt_en" = "true"; then nv="false"; fi
                _safe_jq_write '
                  .routing.rules = [
                      .routing.rules[]? | if .protocol != null and (.protocol | index("bittorrent")) then
                          ._enabled = '"$nv"'
                      else . end
                  ]
                '
                systemctl restart xray
                info "BT 屏蔽切换为: $nv" 
                ;;
            2) 
                local nv="true"
                if test "$ad_en" = "true"; then nv="false"; fi
                _safe_jq_write '
                  .routing.rules = [
                      .routing.rules[]? | if .domain != null and (.domain | index("geosite:category-ads-all")) then
                          ._enabled = '"$nv"'
                      else . end
                  ]
                '
                systemctl restart xray
                info "广告屏蔽切换为: $nv" 
                ;;
            0) 
                return 
                ;;
        esac
    done
}

_update_matrix() {
    echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
    jq --arg dest "$BEST_SNI:443" --slurpfile snis /tmp/sni_array.json '
        .inbounds = [
            .inbounds[]? | if (.protocol == "vless") then
                .streamSettings.realitySettings.serverNames = $snis[0] |
                .streamSettings.realitySettings.dest = $dest
            else . end
        ]
    ' "$CONFIG" > "$CONFIG.tmp"
    if [ $? -eq 0 ]; then 
        mv -f "$CONFIG.tmp" "$CONFIG"
        fix_permissions
        systemctl restart xray >/dev/null 2>&1
    fi
    rm -f /tmp/sni_array.json
}

do_install() {
    title "Apex Vanguard Ultimate Final: 核心部署"
    preflight
    systemctl stop xray >/dev/null 2>&1 || true
    
    if [ ! -f "$INSTALL_DATE_FILE" ]; then 
        date +"%Y-%m-%d %H:%M:%S" > "$INSTALL_DATE_FILE"
    fi
    
    echo -e "  ${cyan}请选择要安装的代理协议：${none}"
    echo "  1) VLESS-Reality (推荐, 强力防封)"
    echo "  2) Shadowsocks (建议落地机使用)"
    echo "  3) 两个都安装 (双管齐下)"
    read -rp "  请输入编号: " proto_choice
    proto_choice=${proto_choice:-1}

    if test "$proto_choice" = "1" || test "$proto_choice" = "3"; then
        while true; do 
            read -rp "请输入 VLESS 监听端口 (回车默认443): " input_p
            input_p=${input_p:-443}
            if validate_port "$input_p"; then 
                LISTEN_PORT="$input_p"
                break
            fi
        done
        read -rp "请输入节点别名 (默认 xp-reality): " input_remark
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
            read -rp "请输入 SS 监听端口 (回车默认8388): " input_s
            input_s=${input_s:-8388}
            if validate_port "$input_s"; then 
                ss_port="$input_s"
                break
            fi
        done
        ss_pass=$(gen_ss_pass)
        ss_method=$(_select_ss_method)
        if test "$proto_choice" = "2"; then 
            read -rp "请输入节点别名 (默认 xp-reality): " input_remark
            REMARK_NAME=${input_remark:-xp-reality}
        fi
    fi

    print_magenta ">>> 正在静默拉取官方核心组件..."
    bash -c "$(curl -fsSL --connect-timeout 10 https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1
    install_update_dat
    fix_xray_systemd_limits

    # 初始化配置骨架
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
        ' /tmp/vless_inbound.json > /tmp/vless_final.json
        
        jq '
            .inbounds += [input]
        ' "$CONFIG" /tmp/vless_final.json > "$CONFIG.tmp" && mv -f "$CONFIG.tmp" "$CONFIG"
        rm -f /tmp/vless_inbound.json /tmp/vless_final.json /tmp/sni_array.json
    fi

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
        ' "$CONFIG" /tmp/ss_inbound.json > "$CONFIG.tmp" && mv -f "$CONFIG.tmp" "$CONFIG"
        rm -f /tmp/ss_inbound.json
    fi

    fix_permissions
    systemctl enable xray >/dev/null 2>&1
    systemctl restart xray >/dev/null 2>&1
    
    info "网络架构部署完成！"
    do_summary
    
    while true; do
        read -rp "按 Enter 返回主菜单，或输入 b 重配矩阵: " opt
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

do_status_menu() {
    while true; do
        title "运行状态与计费中心"
        echo "  1) 服务进程守护状态"
        echo "  2) IP 与 监听网络信息"
        echo "  3) 网卡流量计费核算 (vnstat)"
        echo "  4) 实时连接与独立 IP 统计 (自动刷新/雷达模式)"
        echo -e "  ${cyan}5) 实时修改 Xray CPU 优先级 (-20至-10 动态提权)${none}"
        echo "  0) 返回主菜单"
        hr
        read -rp "选择: " s
        case "$s" in
            1) 
                clear
                title "Xray 进程守护状态"
                systemctl status xray --no-pager || true
                echo ""
                read -rp "按 Enter 继续..." _ 
                ;;
            2) 
                echo -e "\n  公网 IP: ${green}$SERVER_IP${none}"
                hr
                echo -e "  DNS 解析流向: "
                grep "^nameserver" /etc/resolv.conf | awk '{print "    " $0}'
                hr
                echo -e "  Xray 本地监听: "
                ss -tlnp | grep xray | awk '{print "    " $4}'
                read -rp "按 Enter 继续..." _ 
                ;;
            3) 
                if ! command -v vnstat >/dev/null 2>&1; then 
                    warn "未安装 vnstat"
                    read -rp "Enter..." _
                    continue
                fi
                clear
                title "商用级网卡流量计费中心"
                local m_day=$(grep -E "^[[:space:]]*MonthRotate" /etc/vnstat.conf 2>/dev/null | awk '{print $2}' | head -n 1 | tr -d '\r\n')
                m_day=${m_day:-"1 (默认)"}
                echo -e "  每月重置日: ${cyan}每月 $m_day 号${none}"
                hr
                (vnstat -m 3 2>/dev/null || vnstat -m 2>/dev/null) | sed -e 's/estimated/估计流量/ig' -e 's/rx/接收/ig' -e 's/tx/发送/ig' -e 's/total/总计/ig' -e 's/daily/按天/ig' -e 's/monthly/按月/ig'
                hr
                echo "  1) 设置/修改 每月账单清零日"
                echo "  2) 查看看某个月按天详情"
                echo "  q) 返回"
                read -rp "  指令: " vn_opt
                case "$vn_opt" in
                    1) 
                        read -rp "请输入新清零日 (1-31): " d_day
                        if test "${d_day:-0}" -ge 1 2>/dev/null && test "${d_day:-0}" -le 31 2>/dev/null; then
                            sed -i '/^[#[:space:]]*MonthRotate/d' /etc/vnstat.conf 2>/dev/null
                            echo "MonthRotate $d_day" >> /etc/vnstat.conf
                            systemctl restart vnstat 2>/dev/null
                            info "已重置为每月 $d_day 号。"
                        else 
                            error "无效。"
                        fi
                        read -rp "Enter..." _ 
                        ;;
                    2)
                        read -rp "年月 (如 $(date +%Y-%m)，回车近30天): " d_month
                        if test -z "$d_month"; then 
                            vnstat -d 2>/dev/null | sed -e 's/estimated/估计流量/ig' -e 's/rx/接收/ig' -e 's/tx/发送/ig' -e 's/total/总计/ig' -e 's/daily/按天/ig' -e 's/monthly/按月/ig'
                        else 
                            vnstat -d 2>/dev/null | grep -iE "($d_month| day |estimated|--)" | sed -e 's/estimated/估计流量/ig' -e 's/rx/接收/ig' -e 's/tx/发送/ig' -e 's/total/总计/ig' -e 's/daily/按天/ig' -e 's/monthly/按月/ig'
                        fi
                        read -rp "Enter..." _ 
                        ;;
                    q) 
                        ;;
                esac
                ;;
            4)
                while true; do
                    clear
                    title "商用级实时连接与独立 IP 统计"
                    local x_pids=$(pidof xray | xargs | tr -s ' ' '|')
                    if [ -n "$x_pids" ]; then
                        echo -e "  ${cyan}【连接池状态分布】${none}"
                        ss -ntupa | grep -E "pid=($x_pids)[,)]" | awk '{print $1"_"$2}' | sort | uniq -c | sort -nr | awk '{printf "    %-15s : %s\n", $2, $1}'
                        echo -e "\n  ${cyan}【来源 IP 排行 (TOP 10)】${none}"
                        local ips=$(ss -ntupa | grep -E "pid=($x_pids)[,)]" | grep -vE "LISTEN|UNCONN" | awk '{print $6}' | sed -E 's/:[0-9]+$//' | tr -d '[]' | grep -vE "^127\.0\.0\.1$|^0\.0\.0\.0$|^::$|^\*$|^::ffff:127\.0\.0\.1$")
                        if [ -n "$ips" ]; then
                            echo "$ips" | sort | uniq -c | sort -nr | head -n 10 | awk '{printf "    IP: %-18s (并发: %s)\n", $2, $1}'
                            local total_ips=$(echo "$ips" | sort | uniq | wc -l)
                            echo -e "\n  独立外部 IP 总数: ${yellow}${total_ips}${none}"
                        else 
                            echo -e "    ${gray}暂无外部真实连接。${none}"
                        fi
                    else 
                        echo -e "  ${red}Xray 进程未运行。${none}"
                    fi
                    echo -e "\n  ${gray}---------------------------------------------------${none}"
                    echo -e "  ${green}雷达运行中 (每 2 秒自动刷新)... 快捷键: [ ${yellow}q${none} ] 返回${none}"
                    read -t 2 -n 1 -s cmd
                    if [[ "$cmd" == "q" || "$cmd" == "Q" || "$cmd" == $'\e' ]]; then break; fi
                done
                ;;
            5)
                while true; do
                    clear
                    title "实时修改 Xray CPU 优先级 (Nice 调度)"
                    local limit_file="/etc/systemd/system/xray.service.d/limits.conf"
                    local current_nice="-20"
                    if [ -f "$limit_file" ]; then 
                        if grep -q "^Nice=" "$limit_file"; then 
                            current_nice=$(awk -F'=' '/^Nice=/ {print $2}' "$limit_file" | head -1)
                        fi
                    fi
                    echo -e "  当前 Xray Nice: ${cyan}${current_nice}${none} (-20至-10)"
                    hr
                    read -rp "  新 Nice 值 (q 返回): " new_nice
                    if [[ "$new_nice" == "q" || "$new_nice" == "Q" ]]; then break; fi
                    if [[ "$new_nice" =~ ^-[1-2][0-9]$ ]] && [ "$new_nice" -ge -20 ] && [ "$new_nice" -le -10 ]; then
                        sed -i "s/^Nice=.*/Nice=$new_nice/" "$limit_file"
                        systemctl daemon-reload
                        info "更新为 $new_nice，5 秒后重启..."
                        sleep 5
                        systemctl restart xray
                        info "已生效。"
                        read -rp "Enter..." _
                        break
                    else 
                        error "无效数字！"
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

do_uninstall() {
    title "清理：彻底卸载 Xray 并复原原生解析"
    read -rp "永久保留底层调优，粉碎 Xray？(输入 y 确定): " confirm
    if test "$confirm" != "y"; then return; fi
    
    local temp_date=""
    if test -f "$INSTALL_DATE_FILE"; then 
        temp_date=$(cat "$INSTALL_DATE_FILE")
        print_magenta ">>> 提取初装日期快照..."
    fi
    
    print_magenta ">>> 粉碎 Dnsmasq 并恢复 DNS..."
    systemctl stop dnsmasq >/dev/null 2>&1 || true
    systemctl disable dnsmasq >/dev/null 2>&1 || true
    export DEBIAN_FRONTEND=noninteractive
    apt-get purge -y dnsmasq >/dev/null 2>&1 || true
    rm -f /etc/dnsmasq.conf >/dev/null 2>&1
    
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
    
    print_magenta ">>> 彻底绞杀 Xray 主进程..."
    systemctl stop xray >/dev/null 2>&1 || true
    systemctl disable xray >/dev/null 2>&1 || true
    rm -rf /etc/systemd/system/xray.service /etc/systemd/system/xray@.service /etc/systemd/system/xray.service.d /lib/systemd/system/xray* >/dev/null 2>&1
    systemctl daemon-reload >/dev/null 2>&1
    
    print_magenta ">>> 粉碎数据目录..."
    rm -rf "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SCRIPT_DIR" /var/log/xray* /usr/local/bin/xrv "$SCRIPT_PATH" >/dev/null 2>&1
    (crontab -l 2>/dev/null | grep -v "update-dat.sh" | grep -v "/bin/systemctl restart xray") | crontab - 2>/dev/null
    hash -r 2>/dev/null
    
    if test -n "$temp_date"; then 
        mkdir -p "$CONFIG_DIR" 2>/dev/null
        echo "$temp_date" > "$INSTALL_DATE_FILE"
    fi
    
    print_green "卸载完成！"
    exit 0
}

main_menu() {
    while true; do
        clear
        echo -e "${blue}===================================================${none}"
        echo -e "  ${magenta}Xray ex145 The Apex Vanguard - Project Genesis V145${none}"
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        if test "$svc" = "active"; then 
            svc="${green}运行中${none}"
        else 
            svc="${red}停止${none}"
        fi
        echo -e "  状态: $svc | 快捷指令: ${cyan}xrv${none} | IP: ${yellow}$(_get_ip)${none}"
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
        echo "  10) 初次安装、系统内核调优、全域微操矩阵"
        echo "  0) 退出"
        echo -e "  ${red}88) 彻底卸载 (安全复原系统解析并清空软件痕迹)${none}"
        hr
        read -rp "选择: " num
        case "$num" in
            1) do_install ;;
            2) do_user_manager ;;
            3) 
                do_summary
                while true; do 
                    read -rp "按 Enter 返回，或 b 重选 SNI: " rb
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
                print_magenta ">>> 同步最新规则库..."
                bash "$UPDATE_DAT_SCRIPT" >/dev/null 2>&1
                systemctl restart xray >/dev/null 2>&1
                info "更新成功"
                read -rp "Enter..." _ 
                ;;
            5) do_update_core ;;
            6) 
                choose_sni
                if test $? -eq 0; then 
                    _update_matrix
                    do_summary
                    while true; do 
                        read -rp "按 Enter 返回，或 b 继续分配: " rb
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
            7) _global_block_rules ;;
            8) do_fallback_probe ;;
            9) do_status_menu ;;
            10) do_sys_init_menu ;;
            88) do_uninstall ;;
            0) exit 0 ;;
        esac
    done
}

preflight
main_menu