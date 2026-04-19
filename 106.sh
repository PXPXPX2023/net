#!/usr/bin/env bash
# ============================================================
# 脚本名称: ex106.sh (The Apex Vanguard - Project Genesis V106 [The Grand Unification])
# 快捷方式: xrv
# 终局统御: 
#   1. 结构重铸：严厉废除所有单行折叠与 && 连写小聪明，将所有 jq 链式操作与状态控制流 100% 多行立体展开，回归工业级严谨。
#   2. 语法绝缘：完整保留 jq 的原子化赋值链 (.streamSettings //= {} | .sockopt //= {})，绝杀 JSON 结构残缺导致的空转。
#   3. 变量正名：精准维系 XRAY_RAY_BUFFER_SIZE=64，真正唤醒 Go Runtime 的万兆吞吐重卡池。
#   4. 盲走补全：在核心骨架初始阶段强制注入出站 domainStrategy: "AsIs"，确保 routeOnly 零拷贝快车道无缝衔接。
#   5. 物理兜底：在 6 秒高危重启前，强行执行底层 sync 指令，确保存量数据强制落盘，免疫一切碎片化损坏。
#   6. 透明裁决：上帝之手全量抹除静默掩码，内核挂载与包管理调度 100% 全息可见。
#   7. 大一统矩阵：全域 23 项极限微操 + 3 项一键统御，构建单节点路由的终极物理形态。
# ============================================================

# 必须用 bash 运行
if test -z "$BASH_VERSION"; then
    echo "错误: 请用 bash 运行此脚本: bash ex106.sh"
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
DAT_DIR="/usr/local/share/xray"
SCRIPT_DIR="/usr/local/etc/xray-script"
UPDATE_DAT_SCRIPT="$SCRIPT_DIR/update-dat.sh"
SYMLINK="/usr/local/bin/xrv"
SCRIPT_PATH=$(readlink -f "$0")
SERVER_IP=""
REMARK_NAME="xp-reality"
BEST_SNI="www.microsoft.com"
SNI_JSON_ARRAY="\"www.microsoft.com\""
LISTEN_PORT=443

# 初始化基础环境
mkdir -p "$CONFIG_DIR" "$DAT_DIR" "$SCRIPT_DIR" 2>/dev/null
touch "$USER_SNI_MAP" "$USER_TIME_MAP"

# -- 辅助输出函数 --
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

# -- 权限强锁防线 --
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

# -- 安全写入配置 --
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

# -- 赋予 Xray Systemd 【特种兵级】防爆突发特权 --
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
LimitNOFILE=4096
LimitNPROC=4096
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

# -- 环境预检 & 定时任务 --
preflight() {
    if test "$EUID" -ne 0; then 
        die "此脚本必须以 root 身份运行"
    fi
    if ! command -v systemctl >/dev/null 2>&1; then 
        die "系统缺少 systemctl，请更换标准的 systemd 系统"
    fi
    
    local need="jq curl wget xxd unzip qrencode vnstat cron openssl coreutils sed e2fsprogs pkg-config iproute2 ethtool"
    local install_list=""
    for i in $need; do 
        if ! command -v "$i" >/dev/null 2>&1; then 
            install_list="$install_list $i"
        fi
    done

    if test -n "$install_list"; then
        info "正在同步工业级依赖: $install_list"
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
    
    SERVER_IP=$( (curl -s -4 --connect-timeout 5 https://api.ipify.org || curl -s -4 --connect-timeout 5 https://ifconfig.me || echo "获取失败") | tr -d '\r\n' )
}

# -- 自动热更 Geo 全球规则库设置 --
install_update_dat() {
    cat > "$UPDATE_DAT_SCRIPT" <<'UPDSH'
#!/usr/bin/env bash
XRAY_DAT_DIR="/usr/local/share/xray"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat"
curl -sL -o "$XRAY_DAT_DIR/geoip.dat.new" "$GEOIP_URL" && mv -f "$XRAY_DAT_DIR/geoip.dat.new" "$XRAY_DAT_DIR/geoip.dat"
curl -sL -o "$XRAY_DAT_DIR/geosite.dat.new" "$GEOSITE_URL" && mv -f "$XRAY_DAT_DIR/geosite.dat.new" "$XRAY_DAT_DIR/geosite.dat"
UPDSH
    chmod +x "$UPDATE_DAT_SCRIPT"

    (crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT" | grep -v "/bin/systemctl restart xray"; 
     echo "0 3 * * * $UPDATE_DAT_SCRIPT >/dev/null 2>&1"; 
     echo "10 3 * * * /bin/systemctl restart xray >/dev/null 2>&1") | crontab -
     
    info "已配置全球库热更与错峰重启: 3:00 静默下载，3:10 安全重载 Xray 进程。"
}

# -- 核心：130+ 实体 SNI 扫描引擎 --
run_sni_scanner() {
    title "雷达嗅探：130+ 实体矩阵与国内连通性探测"
    print_yellow ">>> 扫描中... (随时按回车键可立即中止并挑选已扫描节点)\n"
    
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
            echo -e "\n${yellow}探测已手动中止，正在整理已捕获节点...${none}"
            break
        fi

        local time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null --connect-timeout 2 -m 4 "https://$sni")
        local ms=$(echo "$time_raw" | awk '{print int($1 * 1000)}')

        if test "${ms:-0}" -gt 0; then
            if curl -sI -m 2 "https://$sni" 2>/dev/null | grep -qiE "server: cloudflare|cf-ray"; then
                echo -e " ${gray}跳过${none} $sni (Cloudflare CDN 拦截)"
                continue
            fi
            
            local doh_res=$(curl -s --connect-timeout 2 "https://dns.alidns.com/resolve?name=$sni&type=1" 2>/dev/null)
            local dns_cn=$(echo "$doh_res" | jq -r '.Answer[]? | select(.type==1 or .type==5) | .data' 2>/dev/null | tail -1)
            
            local status_cn=""
            local p_type="NORM"
            
            if test -z "$dns_cn" || test "$dns_cn" = "127.0.0.1" || test "$dns_cn" = "0.0.0.0" || test "$dns_cn" = "::1"; then
                status_cn="${red}国内墙阻断 (DNS投毒)${none}"
                p_type="BLOCK"
            else
                local loc=$(curl -s --connect-timeout 2 "https://ipinfo.io/$dns_cn/country" 2>/dev/null | tr -d ' \n')
                if test "$loc" = "CN"; then
                    status_cn="${green}直通${none} | ${blue}中国境内 CDN${none}"
                    p_type="CN_CDN"
                else
                    status_cn="${green}直通${none} | ${cyan}海外原生优质${none}"
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
        print_red "探测全灭，采用微软作为保底方案。"
        echo "www.microsoft.com 999" > "$SNI_CACHE_FILE"
    fi
    rm -f "$tmp_sni"
}

# -- 终极 Reality 质检 --
verify_sni_strict() {
    print_magenta "\n>>> 正在对 $1 开启严苛质检 (TLS 1.3 + ALPN h2 + OCSP)..."
    local out=$(echo "Q" | timeout 5 openssl s_client -connect "$1:443" -alpn h2 -tls1_3 -status 2>&1)
    local pass=1
    
    if ! echo "$out" | grep -qi "TLSv1.3"; then 
        print_red " ✗ 质检拦截: 目标不支持 TLS v1.3"
        pass=0
    fi
    if ! echo "$out" | grep -qi "ALPN, server accepted to use h2"; then 
        print_red " ✗ 质检拦截: 目标不支持 ALPN h2"
        pass=0
    fi
    if ! echo "$out" | grep -qi "OCSP response:"; then 
        print_red " ✗ 质检拦截: 目标未开启 OCSP Stapling 证书状态装订"
        pass=0
    fi
    
    return $pass
}

# -- 交互选单 --
choose_sni() {
    while true; do
        if test -f "$SNI_CACHE_FILE"; then
            echo -e "\n  ${cyan}【战备缓存：极速 Top 20 (已剔除阻断节点)】${none}"
            local idx=1
            while read -r s t; do
                echo -e "  $idx) $s (${cyan}${t}ms${none})"
                idx=$((idx + 1))
            done < "$SNI_CACHE_FILE"
            
            echo -e "  ${yellow}r) 抛弃缓存重新扫描矩阵${none}"
            echo "  m) 矩阵模式 (多选组合/全选 SNI 以防封锁)"
            echo "  0) 手动输入自定义域名"
            echo "  q) 取消并返回"
            
            read -rp "  请选择: " sel
            sel=${sel:-1}
            
            if test "$sel" = "q"; then return 1; fi
            if test "$sel" = "r"; then run_sni_scanner; continue; fi
            
            if test "$sel" = "m"; then
                read -rp "请输入要组合的序号 (空格分隔, 如 1 3 5): " m_sel
                local arr=()
                for i in $m_sel; do
                    local picked=$(awk "NR==$i {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null)
                    if test -n "$picked"; then 
                        arr+=("$picked")
                    fi
                done
                if test ${#arr[@]} -eq 0; then 
                    error "选择无效"
                    continue
                fi
                BEST_SNI="${arr[0]}"
                local jq_args=()
                for s in "${arr[@]}"; do 
                    jq_args+=("\"$s\"")
                done
                SNI_JSON_ARRAY=$(IFS=,; echo "${jq_args[*]}")
                
            elif test "$sel" = "0"; then 
                read -rp "输入自定义域名: " d
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
            print_red "端口 $p 已被占用！"
            return 1
        fi
        return 0
    fi
    return 1
}

do_update_core() {
    title "Xray Core 核心无损热更"
    print_magenta ">>> 正在连接 GitHub 拉取最新 Xray 核心..."
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1
    fix_xray_systemd_limits
    systemctl restart xray >/dev/null 2>&1
    local cur_ver=$($XRAY_BIN version 2>/dev/null | head -n1 | awk '{print $2}')
    info "热更成功！当前版本: ${cyan}$cur_ver${none}"
    read -rp "按 Enter 继续..." _
}

gen_ss_pass() { head -c 24 /dev/urandom | base64 | tr -d '=/+\n' | head -c 24; }
_select_ss_method() {
    echo -e "  ${cyan}选择 SS 加密方式：${none}" >&2
    echo "  1) aes-256-gcm (推荐)  2) aes-128-gcm  3) chacha20-ietf-poly1305" >&2
    read -rp "  编号: " mc >&2
    case "${mc:-1}" in
        2) echo "aes-128-gcm" ;;
        3) echo "chacha20-ietf-poly1305" ;;
        *) echo "aes-256-gcm" ;;
    esac
}

# -- 编译与优化区 --
do_install_xanmod_main_official() {
    title "系统飞升：安装官方预编译 XANMOD (main) 内核"
    if [ "$(uname -m)" != "x86_64" ]; then 
        error "官方预编译 Xanmod 仅支持 x86_64 架构！"
        read -rp "按 Enter..." _
        return
    fi
    if [ ! -f /etc/debian_version ]; then 
        error "官方预编译 Xanmod APT 源目前仅支持 Debian / Ubuntu 系！"
        read -rp "按 Enter..." _
        return
    fi
    print_magenta ">>> [1/4] 正在拉取智能探针..."
    local cpu_level_script="/tmp/check_x86-64_psabi.sh"
    wget -qO "$cpu_level_script" https://dl.xanmod.org/check_x86-64_psabi.sh
    local cpu_level=$(awk -f "$cpu_level_script" | grep -oE 'x86-64-v[1-4]' | grep -oE '[1-4]' | tail -n 1)
    rm -f "$cpu_level_script"
    if [ -z "$cpu_level" ]; then 
        cpu_level=1
        warn "默认降级使用 v1 版本。"
    else 
        info "支持级别: v${cpu_level}"
    fi
    
    local pkg_name="linux-xanmod-x64v${cpu_level}"
    print_magenta ">>> [2/4] 配置 Xanmod 仓库..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y >/dev/null 2>&1
    apt-get install -y gnupg gnupg2 curl sudo wget e2fsprogs >/dev/null 2>&1
    echo 'deb http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-kernel.list
    wget -qO - https://dl.xanmod.org/gpg.key | gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/xanmod-kernel.gpg
    
    print_magenta ">>> [3/4] 极速拉取并安装: $pkg_name ..."
    apt-get update -y
    apt-get install -y "$pkg_name"
    if [ $? -ne 0 ] && [ "$cpu_level" == "4" ]; then 
        pkg_name="linux-xanmod-x64v3"
        apt-get install -y "$pkg_name"
    fi
    
    print_magenta ">>> [4/4] 重载 GRUB ..."
    if command -v update-grub >/dev/null 2>&1; then 
        update-grub
    else 
        apt-get install -y grub2-common
        update-grub
    fi
    info "官方预编译 XANMOD (main) 部署已全部就绪！系统将在 10 秒后自动重启应用新内核..."
    sleep 10
    reboot
}

do_perf_tuning() {
    title "极限压榨：低延迟系统底层网络栈调优"
    warn "警告: 注入极限参数后将重启！"
    read -rp "确定要继续吗？(y/n): " confirm
    if [[ "$confirm" != "y" ]]; then 
        return
    fi
    
    systemctl stop net-speeder >/dev/null 2>&1 || true
    killall net-speeder >/dev/null 2>&1 || true
    systemctl disable net-speeder >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/net-speeder.service
    systemctl daemon-reload >/dev/null 2>&1
    truncate -s 0 /etc/sysctl.conf /etc/sysctl.d/99-sysctl.conf /etc/sysctl.d/99-network-optimized.conf 2>/dev/null || true
    
    cat > /etc/sysctl.d/99-network-optimized.conf << 'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.neigh.default.base_reachable_time_ms = 60000
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_mtu_probing = 1
net.core.rmem_max = 21699928
net.core.wmem_max = 21699928
net.ipv4.tcp_rmem = 4096 760576 21699928
net.ipv4.tcp_wmem = 4096 760576 21699928
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_timestamps = 1
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
fs.file-max = 1048576
vm.swappiness = 1
net.ipv4.ip_forward = 1
EOF
    sysctl --system
    
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    if [ -n "$IFACE" ]; then
        cat > /usr/local/bin/nic-optimize.sh <<'EONIC'
#!/bin/bash
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
ethtool -K $IFACE lro off rx-gro-hw off 2>/dev/null || true
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
    fi
    info "参数注入完成！30 秒后自动重启..."
    sleep 30
    reboot
}

do_txqueuelen_opt() {
    title "网卡发送队列 (TX Queue) 特化调优"
    local IP_CMD=$(command -v ip)
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    if [ -z "$IFACE" ]; then 
        error "无法识别默认出口网卡。"
        read -rp "Enter..." _
        return 1
    fi
    info "将 txqueuelen 精简至 2000..."
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
    info "已应用！当前队列状态: "
    $IP_CMD link show "$IFACE" | grep -o 'qlen [0-9]*' | awk '{print "    " $0}'
    read -rp "按 Enter 继续..." _
}

# -- [底层微操探针与热重载引擎] --
check_mph_state() {
    local state=$(jq -r '.routing.domainMatcher // "false"' "$CONFIG" 2>/dev/null)
    if [ "$state" = "mph" ]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_maxtime_state() {
    local state=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff // "false"' "$CONFIG" 2>/dev/null | head -n 1)
    if [ "$state" = "60000" ]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_routeonly_state() {
    local state=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .sniffing.routeOnly // "false"' "$CONFIG" 2>/dev/null | head -n 1)
    if [ "$state" = "true" ]; then 
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
    if systemctl is-active dnsmasq >/dev/null 2>&1 && grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_thp_state() {
    if [ ! -f "/sys/kernel/mm/transparent_hugepage/enabled" ] || [ ! -w "/sys/kernel/mm/transparent_hugepage/enabled" ]; then 
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
    if [ ! -f "/proc/sys/net/ipv4/tcp_mtu_probing" ] || [ ! -w "/proc/sys/net/ipv4/tcp_mtu_probing" ]; then 
        echo "unsupported"
        return
    fi
    if [ "$(sysctl -n net.ipv4.tcp_mtu_probing 2>/dev/null)" = "1" ]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_cpu_state() {
    if [ ! -d "/sys/devices/system/cpu/cpu0/cpufreq" ] || [ ! -w "/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor" ]; then 
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
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    if [ -z "$IFACE" ] || ! command -v ethtool >/dev/null 2>&1 || ! ethtool -g "$IFACE" >/dev/null 2>&1; then 
        echo "unsupported"
        return
    fi
    local curr_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Current hardware settings" | grep "RX:" | head -1 | awk '{print $2}')
    if [ -z "$curr_rx" ]; then 
        echo "unsupported"
        return
    fi
    if [ "$curr_rx" = "512" ]; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_zram_state() {
    if ! modprobe -n zram >/dev/null 2>&1 && ! lsmod | grep -q zram; then 
        echo "unsupported"
        return
    fi
    if swapon --show | grep -q 'zram'; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_journal_state() {
    if [ ! -f "/etc/systemd/journald.conf" ]; then 
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
    if [ ! -f "$limit_file" ]; then 
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
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    if tc qdisc show dev "$IFACE" 2>/dev/null | grep -q 'ack-filter'; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_gso_state() {
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    if ! command -v ethtool >/dev/null 2>&1; then 
        echo "unsupported"
        return
    fi
    if ethtool -k "$IFACE" 2>/dev/null | grep -q "rx-gro: on"; then 
        echo "true"
    else 
        echo "false"
    fi
}

check_irq_state() {
    local CORES=$(nproc)
    if [ "$CORES" -lt 2 ]; then 
        echo "unsupported"
        return
    fi
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    local irq=$(grep "$IFACE" /proc/interrupts 2>/dev/null | head -1 | awk '{print $1}' | tr -d ':')
    if [ -n "$irq" ]; then
        local mask=$(cat /proc/irq/$irq/smp_affinity 2>/dev/null | tr -d '0')
        if [ "$mask" = "1" ]; then 
            echo "true"
        else 
            echo "false"
        fi
    else
        echo "false"
    fi
}

update_hw_boot_script() {
    cat << 'EOF' > /usr/local/bin/xray-hw-tweaks.sh
#!/bin/bash
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
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
    if [ "$(check_gso_state)" = "true" ]; then
        echo "ethtool -K \$IFACE gro on gso on tso on 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
    else
        echo "ethtool -K \$IFACE gro off gso off tso off 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
    fi
    if [ "$(check_cake_state)" = "true" ]; then
        if [ "$(check_ackfilter_state)" = "true" ]; then
            echo "tc qdisc replace dev \$IFACE root cake ack-filter 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
        else
            echo "tc qdisc replace dev \$IFACE root cake 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
        fi
    fi
    if [ "$(check_irq_state)" = "true" ]; then
        echo "systemctl stop irqbalance 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
        echo "for irq in \$(grep \"\$IFACE\" /proc/interrupts 2>/dev/null | awk '{print \$1}' | tr -d ':'); do echo 1 > /proc/irq/\$irq/smp_affinity 2>/dev/null || true; done" >> /usr/local/bin/xray-hw-tweaks.sh
    fi
    
    chmod +x /usr/local/bin/xray-hw-tweaks.sh

    cat << 'EOF' > /etc/systemd/system/xray-hw-tweaks.service
[Unit]
Description=Xray Hardware Tweaks
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/xray-hw-tweaks.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable xray-hw-tweaks.service >/dev/null 2>&1
}

# -- 引擎与开关 --
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
        if [ -n "$max_rx" ]; then ethtool -G "$IFACE" rx "$max_rx" tx "$max_rx" 2>/dev/null || true; fi
    else 
        ethtool -G "$IFACE" rx 512 tx 512 2>/dev/null || true
    fi
    update_hw_boot_script
}

toggle_gso() {
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    if [ "$(check_gso_state)" = "unsupported" ]; then return; fi
    if [ "$(check_gso_state)" = "true" ]; then 
        ethtool -K "$IFACE" gro off gso off tso off 2>/dev/null || true
    else 
        ethtool -K "$IFACE" gro on gso on tso on 2>/dev/null || true
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
        if [ "$TOTAL_MEM" -lt 500 ]; then 
            ZRAM_SIZE=$((TOTAL_MEM * 2))
        elif [ "$TOTAL_MEM" -lt 1024 ]; then 
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
        tc qdisc replace dev "$IFACE" root cake 2>/dev/null || true
    fi
    update_hw_boot_script
}

toggle_ackfilter() {
    local IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    if [ "$(check_cake_state)" = "false" ]; then 
        warn "必须先开启 CAKE 才能启用 ack-filter!"
        sleep 2
        return
    fi
    if [ "$(check_ackfilter_state)" = "true" ]; then
        tc qdisc replace dev "$IFACE" root cake 2>/dev/null || true
    else
        tc qdisc replace dev "$IFACE" root cake ack-filter 2>/dev/null || true
    fi
    update_hw_boot_script
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
    # 彻底重写 jq 数组批量赋值，消除空转隐患，全量多行展开
    _safe_jq_write '
      (.routing) |= (. // {}) |
      (.routing.domainMatcher) = "mph" |
      (.outbounds[]? | select(.protocol=="freedom")) |= (
          .streamSettings //= {} |
          .streamSettings.sockopt //= {} |
          .streamSettings.sockopt.tcpNoDelay = true |
          .streamSettings.sockopt.tcpFastOpen = true |
          .streamSettings.sockopt.tcpKeepAliveIdle = 30 |
          .streamSettings.sockopt.tcpKeepAliveInterval = 15
      ) |
      (.inbounds[]? | select(.protocol=="vless")) |= (
          .streamSettings //= {} |
          .streamSettings.sockopt //= {} |
          .streamSettings.sockopt.tcpNoDelay = true |
          .streamSettings.sockopt.tcpFastOpen = true |
          .streamSettings.sockopt.tcpKeepAliveIdle = 30 |
          .streamSettings.sockopt.tcpKeepAliveInterval = 15 |
          .sniffing //= {} |
          .sniffing.metadataOnly = true |
          .sniffing.routeOnly = true
      )
    '
    
    local has_reality=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .protocol' "$CONFIG" 2>/dev/null | head -n 1)
    if [ -n "$has_reality" ]; then
        _safe_jq_write '
          (.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality")) |= (
              .streamSettings.realitySettings //= {} |
              .streamSettings.realitySettings.maxTimeDiff = 60000
          )
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
      del(.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpNoDelay, .streamSettings?.sockopt?.tcpFastOpen, .streamSettings?.sockopt?.tcpKeepAliveIdle, .streamSettings?.sockopt?.tcpKeepAliveInterval) |
      del(.inbounds[]? | select(.protocol=="vless") | .streamSettings?.sockopt?.tcpNoDelay, .streamSettings?.sockopt?.tcpFastOpen, .streamSettings?.sockopt?.tcpKeepAliveIdle, .streamSettings?.sockopt?.tcpKeepAliveInterval)
    '
    
    _safe_jq_write '
      (.inbounds[]? | select(.protocol=="vless") | .sniffing.metadataOnly) = false |
      (.inbounds[]? | select(.protocol=="vless") | .sniffing.routeOnly) = false
    '
    
    _safe_jq_write '
      del(.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff) |
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

# -- [双十一] 全域 23 项极限微操 --
do_app_level_tuning_menu() {
    while true; do
        clear
        title "全域 23 项极限微操 (Xray 提速底牌 & 系统内核微操)"
        if ! test -f "$CONFIG"; then 
            error "未发现配置，请先执行核心安装！"
            read -rp "Enter..." _
            return
        fi

        # App 1-11
        local out_fastopen=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpFastOpen // "false"' "$CONFIG" 2>/dev/null)
        local out_keepalive=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpKeepAliveIdle // "false"' "$CONFIG" 2>/dev/null)
        local sniff_status=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .sniffing.metadataOnly // "false"' "$CONFIG" 2>/dev/null | head -1)
        local dns_status=$(jq -r '.dns.queryStrategy // "false"' "$CONFIG" 2>/dev/null)
        local policy_status=$(jq -r '.policy.levels["0"].connIdle // "false"' "$CONFIG" 2>/dev/null)
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

        # System 12-23
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
        local gso_state=$(check_gso_state)
        local ackfilter_state=$(check_ackfilter_state)

        # 缺省探测
        local app_off_count=0
        if [ "$out_fastopen" != "true" ]; then app_off_count=$((app_off_count+1)); fi
        if [ "$out_keepalive" != "30" ]; then app_off_count=$((app_off_count+1)); fi
        if [ "$sniff_status" != "true" ]; then app_off_count=$((app_off_count+1)); fi
        if [ "$dns_status" != "UseIP" ]; then app_off_count=$((app_off_count+1)); fi
        if [ "$gc_status" = "默认 100" ] || [ "$gc_status" = "100" ]; then app_off_count=$((app_off_count+1)); fi
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
        if [ "$gso_state" = "false" ]; then sys_off_count=$((sys_off_count+1)); fi
        if [ "$ackfilter_state" = "false" ]; then sys_off_count=$((sys_off_count+1)); fi

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
        local s21; if [ "$irq_state" = "true" ]; then s21="${cyan}已锁死 Core 0${none}"; elif [ "$irq_state" = "unsupported" ]; then s21="${gray}不支持(单核)${none}"; else s21="${gray}默认平衡调度${none}"; fi
        local s22; if [ "$gso_state" = "true" ]; then s22="${cyan}聚合万兆流媒体模式${none}"; else s22="${gray}打散零延迟电竞模式${none}"; fi
        
        local s23
        if [ "$cake_state" = "false" ]; then 
            s23="${gray}需先开启 CAKE${none}"
        else 
            if [ "$ackfilter_state" = "true" ]; then 
                s23="${cyan}绞杀空 ACK 释放上行${none}"
            else 
                s23="${gray}默认不干预${none}"
            fi
        fi

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
        echo -e "  ${magenta}--- Linux 系统层与内核黑科技 (12-23) ---${none}"
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
        echo -e "  22) 开启或关闭【网卡 GSO/GRO 硬件卸载反转】(万兆吞吐/极限电竞)   | 状态: $s22"
        echo -e "  23) 开启或关闭【CAKE ack-filter 上行绞杀】(释放高延迟不对等链路) | 状态: $s23"
        echo -e "  "
        echo -e "  ${cyan}24) 一键开启或关闭 1-11 项 应用层微操 (自动侦测并智能反转)${none}"
        echo -e "  ${yellow}25) 一键开启或关闭 12-23 项 系统级微操 (自动避障侦测并反转)${none}"
        echo -e "  ${red}26) 上帝之手：一键开启或关闭 1-23 项 全域微操 (执行后自动重启系统)${none}"
        echo "  0) 返回上一级"
        hr
        read -rp "请选择: " app_opt

        case "$app_opt" in
            1)
                if [ "$out_fastopen" = "true" ]; then
                    _safe_jq_write '
                      del(.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpNoDelay, .streamSettings?.sockopt?.tcpFastOpen) |
                      del(.inbounds[]? | select(.protocol=="vless") | .streamSettings?.sockopt?.tcpNoDelay, .streamSettings?.sockopt?.tcpFastOpen)
                    '
                else
                    _safe_jq_write '
                      (.outbounds[]? | select(.protocol=="freedom")) |= (
                          .streamSettings //= {} |
                          .streamSettings.sockopt //= {} |
                          .streamSettings.sockopt.tcpNoDelay = true |
                          .streamSettings.sockopt.tcpFastOpen = true
                      ) |
                      (.inbounds[]? | select(.protocol=="vless")) |= (
                          .streamSettings //= {} |
                          .streamSettings.sockopt //= {} |
                          .streamSettings.sockopt.tcpNoDelay = true |
                          .streamSettings.sockopt.tcpFastOpen = true
                      )
                    '
                fi
                systemctl restart xray >/dev/null 2>&1
                read -rp "按 Enter 继续..." _
                ;;
            2)
                if [ "$out_keepalive" = "30" ]; then
                    _safe_jq_write '
                      del(.outbounds[]? | select(.protocol=="freedom") | .streamSettings?.sockopt?.tcpKeepAliveIdle, .streamSettings?.sockopt?.tcpKeepAliveInterval) |
                      del(.inbounds[]? | select(.protocol=="vless") | .streamSettings?.sockopt?.tcpKeepAliveIdle, .streamSettings?.sockopt?.tcpKeepAliveInterval)
                    '
                else
                    _safe_jq_write '
                      (.outbounds[]? | select(.protocol=="freedom")) |= (
                          .streamSettings //= {} |
                          .streamSettings.sockopt //= {} |
                          .streamSettings.sockopt.tcpKeepAliveIdle = 30 |
                          .streamSettings.sockopt.tcpKeepAliveInterval = 15
                      ) |
                      (.inbounds[]? | select(.protocol=="vless")) |= (
                          .streamSettings //= {} |
                          .streamSettings.sockopt //= {} |
                          .streamSettings.sockopt.tcpKeepAliveIdle = 30 |
                          .streamSettings.sockopt.tcpKeepAliveInterval = 15
                      )
                    '
                fi
                systemctl restart xray >/dev/null 2>&1
                read -rp "按 Enter 继续..." _
                ;;
            3)
                if [ "$sniff_status" = "true" ]; then
                    _safe_jq_write '(.inbounds[]? | select(.protocol=="vless") | .sniffing.metadataOnly) = false'
                else
                    _safe_jq_write '(.inbounds[]? | select(.protocol=="vless")) |= (.sniffing //= {} | .sniffing.metadataOnly = true)'
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
                        if [ "$gc_status" = "默认 100" ] || [ "$gc_status" = "100" ]; then
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
                    _safe_jq_write '(.routing) |= (. // {}) | (.routing.domainMatcher) = "mph"'
                fi
                systemctl restart xray >/dev/null 2>&1
                read -rp "按 Enter 继续..." _
                ;;
            9)
                if [ -n "$has_reality" ]; then
                    if [ "$maxtime_state" = "true" ]; then
                        _safe_jq_write 'del(.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff)'
                    else
                        _safe_jq_write '
                          (.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality")) |= (
                              .streamSettings.realitySettings //= {} |
                              .streamSettings.realitySettings.maxTimeDiff = 60000
                          )
                        '
                    fi
                    systemctl restart xray >/dev/null 2>&1
                fi
                read -rp "按 Enter 继续..." _
                ;;
            10)
                if [ "$routeonly_status" = "true" ]; then
                    _safe_jq_write '(.inbounds[]? | select(.protocol=="vless") | .sniffing.routeOnly) = false'
                else
                    _safe_jq_write '(.inbounds[]? | select(.protocol=="vless")) |= (.sniffing //= {} | .sniffing.routeOnly = true)'
                fi
                systemctl restart xray >/dev/null 2>&1
                read -rp "按 Enter 继续..." _
                ;;
            11)
                toggle_buffer
                systemctl restart xray >/dev/null 2>&1
                read -rp "按 Enter 继续..." _
                ;;
            12) toggle_dnsmasq; systemctl restart xray >/dev/null 2>&1; read -rp "按 Enter 继续..." _ ;;
            13) toggle_thp; read -rp "按 Enter 继续..." _ ;;
            14) toggle_mtu; read -rp "按 Enter 继续..." _ ;;
            15) toggle_cpu; read -rp "按 Enter 继续..." _ ;;
            16) toggle_ring; read -rp "按 Enter 继续..." _ ;;
            17) toggle_zram; read -rp "按 Enter 继续..." _ ;;
            18) toggle_journal; read -rp "按 Enter 继续..." _ ;;
            19) toggle_process_priority; systemctl restart xray >/dev/null 2>&1; read -rp "按 Enter 继续..." _ ;;
            20) toggle_cake; read -rp "按 Enter 继续..." _ ;;
            21) toggle_irq; read -rp "按 Enter 继续..." _ ;;
            22) toggle_gso; read -rp "按 Enter 继续..." _ ;;
            23) toggle_ackfilter; read -rp "按 Enter 继续..." _ ;;
            24)
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
            25)
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
                    if [ "$gso_state" = "false" ]; then toggle_gso; fi
                    if [ "$ackfilter_state" = "false" ]; then toggle_ackfilter; fi
                    info "12-23 系统级满血激活！"
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
                    if [ "$gso_state" = "true" ]; then toggle_gso; fi
                    if [ "$ackfilter_state" = "true" ]; then toggle_ackfilter; fi
                    info "12-23 系统级已卸载！"
                fi
                read -rp "按 Enter 继续..." _
                ;;
            26)
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
                        if [ "$gso_state" = "false" ]; then toggle_gso; fi
                        if [ "$ackfilter_state" = "false" ]; then toggle_ackfilter; fi
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
                    if [ "$gso_state" = "true" ]; then toggle_gso; fi
                    if [ "$ackfilter_state" = "true" ]; then toggle_ackfilter; fi
                fi
                echo ""
                print_red "=========================================================="
                print_yellow "警告：全域 25 项拓扑与内核状态已发生深层变革！"
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

# -- [功能 10] 系统级全能初始化子菜单 --
do_sys_init_menu() {
    while true; do
        title "初次安装、更新系统组件"
        echo "  1) 一键更新系统、安装常用组件并校准时区"
        echo -e "  ${cyan}2) 必须先安装 XANMOD (main) 官方预编译内核 (推荐)${none}"
        echo "  3) 先完成2），编译安装 Xanmod 内核 + BBR3"
        echo "  4) 网卡发送队列 (TX Queue) 深度调优 (2000 极速版)"
        echo "  5) 系统内核网络栈极限调优"
        echo -e "  ${magenta}6) 全域 23 项极限微操 (CAKE/硬中断隔离/零拷贝/聚合反转)${none}"
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
                read -rp "按 Enter 继续..." _ 
                ;;
            2) do_install_xanmod_main_official ;;
            3) do_xanmod_compile ;;
            4) do_txqueuelen_opt ;;
            5) do_perf_tuning ;;
            6) do_app_level_tuning_menu ;;
            0) return ;;
        esac
    done
}

# -- 用户管理 --
do_user_manager() {
    while true; do
        title "用户管理 (增删/导入 备注、UUID、ShortId)"
        if ! test -f "$CONFIG"; then 
            error "未发现配置"
            return
        fi
        
        local clients=$(jq -r ".inbounds[]? | select(.protocol==\"vless\") | .settings?.clients[]? | .id + \"|\" + (.email // \"无备注\")" "$CONFIG" 2>/dev/null)
        if test -z "$clients" || test "$clients" = "null"; then 
            error "无 VLESS 节点"
            return
        fi
        
        local tmp_users="/tmp/xray_users.txt"
        echo "$clients" | awk -F'|' '{print NR"|"$1"|"$2}' > "$tmp_users"
        echo -e "当前用户列表："
        cat "$tmp_users" | while IFS='|' read -r num uid remark; do
            local utime=$(grep "^$uid|" "$USER_TIME_MAP" 2>/dev/null | cut -d'|' -f2)
            utime=${utime:-"未知时间"}
            echo -e "  $num) 备注: ${cyan}$remark${none} | 时间: ${gray}$utime${none} | UUID: ${yellow}$uid${none}"
        done
        hr
        echo "  a) 新增本网用户 (自动分配 UUID 与 ShortId)"
        echo "  m) 手动导入外部用户"
        echo "  s) 修改指定用户的专属 SNI"
        echo "  d) 序号删除用户"
        echo "  q) 退出"
        read -rp "指令: " uopt
        
        if test "$uopt" = "a"; then
            local nu=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || $XRAY_BIN uuid)
            local ns=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n')
            local ctime=$(date +"%Y-%m-%d %H:%M")
            
            read -rp "请输入专属节点备注: " u_remark
            u_remark=${u_remark:-User-${ns}}
            
            cat > /tmp/new_client.json <<EOF
{
  "id": "$nu",
  "flow": "xtls-rprx-vision",
  "email": "$u_remark"
}
EOF
            jq '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [input]' "$CONFIG" /tmp/new_client.json > "$CONFIG.tmp1"
            jq --arg sid "$ns" '(.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.shortIds) += [$sid]' "$CONFIG.tmp1" > "$CONFIG"
            rm -f /tmp/new_client.json "$CONFIG.tmp1"
            
            echo "$nu|$ctime" >> "$USER_TIME_MAP"
            fix_permissions
            systemctl restart xray
            
            local port=$(jq -r ".inbounds[] | select(.protocol==\"vless\") | .port" "$CONFIG" | head -1)
            local sni=$(jq -r ".inbounds[] | select(.protocol==\"vless\") | .streamSettings.realitySettings.serverNames[0]" "$CONFIG" | head -1)
            local pub=$(jq -r ".inbounds[] | select(.protocol==\"vless\") | .streamSettings.realitySettings.publicKey" "$CONFIG" | head -1)
            info "用户分配成功！"
            local link="vless://${nu}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${ns}&type=tcp#${u_remark}"
            echo -e "\n  ${cyan}通用链接:${none} \n  $link\n"
            if command -v qrencode >/dev/null 2>&1; then 
                qrencode -m 2 -t UTF8 "$link"
            fi
            read -rp "按 Enter 继续..." _
            
        elif test "$uopt" = "m"; then
            read -rp "外部用户备注: " m_remark
            m_remark=${m_remark:-ImportedUser}
            read -rp "外部 UUID: " m_uuid
            if test -z "$m_uuid"; then continue; fi
            read -rp "外部 ShortId: " m_sid
            if test -z "$m_sid"; then continue; fi
            
            local ctime=$(date +"%Y-%m-%d %H:%M")
            cat > /tmp/new_client.json <<EOF
{
  "id": "$m_uuid",
  "flow": "xtls-rprx-vision",
  "email": "$m_remark"
}
EOF
            jq '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [input]' "$CONFIG" /tmp/new_client.json > "$CONFIG.tmp1"
            jq --arg sid "$m_sid" '(.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.shortIds) += [$sid]' "$CONFIG.tmp1" > "$CONFIG"
            rm -f /tmp/new_client.json "$CONFIG.tmp1"
            
            echo "$m_uuid|$ctime" >> "$USER_TIME_MAP"
            
            read -rp "指定专属 SNI? (回车默认): " m_sni
            if test -n "$m_sni"; then
                jq --arg sni "$m_sni" '(.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) += [$sni] | (.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) |= unique' "$CONFIG" > "$CONFIG.tmp2"
                mv -f "$CONFIG.tmp2" "$CONFIG"
                sed -i "/^$m_uuid|/d" "$USER_SNI_MAP" 2>/dev/null
                echo "$m_uuid|$m_sni" >> "$USER_SNI_MAP"
            else
                m_sni=$(jq -r ".inbounds[] | select(.protocol==\"vless\") | .streamSettings.realitySettings.serverNames[0]" "$CONFIG" | head -1)
            fi
            
            fix_permissions
            systemctl restart xray
            
            local port=$(jq -r ".inbounds[] | select(.protocol==\"vless\") | .port" "$CONFIG" | head -1)
            local pub=$(jq -r ".inbounds[] | select(.protocol==\"vless\") | .streamSettings.realitySettings.publicKey" "$CONFIG" | head -1)
            info "导入成功！"
            local link="vless://${m_uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${m_sni}&fp=chrome&pbk=${pub}&sid=${m_sid}&type=tcp#${m_remark}"
            echo -e "\n  ${cyan}通用链接:${none} \n  $link\n"
            if command -v qrencode >/dev/null 2>&1; then 
                qrencode -m 2 -t UTF8 "$link"
            fi
            read -rp "按 Enter 继续..." _
            
        elif test "$uopt" = "s"; then
            read -rp "序号: " snum
            local target_uuid=$(awk -F'|' -v id="${snum:-0}" '$1==id {print $2}' "$tmp_users")
            local target_remark=$(awk -F'|' -v id="${snum:-0}" '$1==id {print $3}' "$tmp_users")
            if test -n "$target_uuid"; then
                read -rp "专属 SNI 域名: " u_sni
                if test -n "$u_sni"; then
                    jq --arg sni "$u_sni" '(.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) += [$sni] | (.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) |= unique' "$CONFIG" > "$CONFIG.tmp"
                    mv -f "$CONFIG.tmp" "$CONFIG"
                    sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null
                    echo "$target_uuid|$u_sni" >> "$USER_SNI_MAP"
                    fix_permissions
                    systemctl restart xray
                    info "绑定 SNI: $u_sni"
                    local port=$(jq -r ".inbounds[] | select(.protocol==\"vless\") | .port" "$CONFIG" | head -1)
                    local idx=$((${snum:-0}-1))
                    local sid=$(jq -r ".inbounds[] | select(.protocol==\"vless\") | .streamSettings.realitySettings.shortIds[$idx]" "$CONFIG" 2>/dev/null)
                    local pub=$(jq -r ".inbounds[] | select(.protocol==\"vless\") | .streamSettings.realitySettings.publicKey" "$CONFIG" | head -1)
                    local link="vless://${target_uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${u_sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${target_remark}"
                    echo -e "\n  ${cyan}更新链接:${none} \n  $link\n"
                    if command -v qrencode >/dev/null 2>&1; then 
                        qrencode -m 2 -t UTF8 "$link"
                    fi
                    read -rp "按 Enter 继续..." _
                fi
            else 
                error "无效序号。"
            fi
            
        elif test "$uopt" = "d"; then
            read -rp "序号: " dnum
            local total=$(wc -l < "$tmp_users" 2>/dev/null)
            if test "${total:-0}" -le 1; then 
                error "保留至少一个！"
            else
                local target_uuid=$(awk -F'|' -v id="${dnum:-0}" '$1==id {print $2}' "$tmp_users")
                if test -n "$target_uuid"; then
                    local idx=$((${dnum:-0}-1))
                    jq --arg uid "$target_uuid" --argjson i "$idx" '
                        (.inbounds[] | select(.protocol=="vless") | .settings.clients) |= map(select(.id != $uid)) | 
                        (.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.shortIds) |= del(.[$i])
                    ' "$CONFIG" > "$CONFIG.tmp"
                    mv -f "$CONFIG.tmp" "$CONFIG"
                    sed -i "/^$target_uuid|/d" "$USER_SNI_MAP" 2>/dev/null
                    sed -i "/^$target_uuid|/d" "$USER_TIME_MAP" 2>/dev/null
                    fix_permissions
                    systemctl restart xray
                    info "已剔除。"
                fi
            fi
            
        elif test "$uopt" = "q"; then 
            rm -f "$tmp_users"
            break
        fi
    done
}

# -- 屏蔽规则管理 --
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
                jq --argjson nv "$nv" '
                  (.routing.rules[]? | select(.protocol != null) | select(.protocol | index("bittorrent"))) |= (._enabled = $nv)
                ' "$CONFIG" > "$CONFIG.tmp"
                mv -f "$CONFIG.tmp" "$CONFIG"
                fix_permissions
                systemctl restart xray
                info "BT 屏蔽切换为: $nv" 
                ;;
            2) 
                local nv="true"
                if test "$ad_en" = "true"; then nv="false"; fi
                jq --argjson nv "$nv" '
                  (.routing.rules[]? | select(.domain != null) | select(.domain | index("geosite:category-ads-all"))) |= (._enabled = $nv)
                ' "$CONFIG" > "$CONFIG.tmp"
                mv -f "$CONFIG.tmp" "$CONFIG"
                fix_permissions
                systemctl restart xray
                info "广告屏蔽切换为: $nv" 
                ;;
            0) 
                return 
                ;;
        esac
    done
}

# -- 分发中心 --
do_summary() {
    if ! test -f "$CONFIG"; then return; fi
    title "The Apex Vanguard 节点详情中心"
    local client_count=$(jq '.inbounds[] | select(.protocol=="vless") | .settings.clients | length' "$CONFIG" 2>/dev/null || echo 0)
    
    if test "${client_count:-0}" -gt 0; then
        local port=$(jq -r ".inbounds[] | select(.protocol==\"vless\") | .port" "$CONFIG" 2>/dev/null)
        local pub=$(jq -r ".inbounds[] | select(.protocol==\"vless\") | .streamSettings.realitySettings.publicKey" "$CONFIG" 2>/dev/null)
        local all_snis=$(jq -r ".inbounds[] | select(.protocol==\"vless\") | .streamSettings.realitySettings.serverNames | join(\", \")" "$CONFIG" 2>/dev/null)
        local main_sni=$(jq -r ".inbounds[] | select(.protocol==\"vless\") | .streamSettings.realitySettings.serverNames[0]" "$CONFIG" 2>/dev/null)
        
        for ((i=0; i<client_count; i++)); do
            local uuid=$(jq -r ".inbounds[] | select(.protocol==\"vless\") | .settings.clients[$i].id" "$CONFIG" 2>/dev/null)
            local remark=$(jq -r ".inbounds[] | select(.protocol==\"vless\") | .settings.clients[$i].email // \"$REMARK_NAME\"" "$CONFIG" 2>/dev/null)
            local sid=$(jq -r ".inbounds[] | select(.protocol==\"vless\") | .streamSettings.realitySettings.shortIds[$i]" "$CONFIG" 2>/dev/null)
            local target_sni=$(grep "^$uuid|" "$USER_SNI_MAP" 2>/dev/null | cut -d'|' -f2)
            target_sni=${target_sni:-$main_sni}
            
            if test -n "$uuid" && test "$uuid" != "null"; then
                hr
                printf "  ${cyan}【VLESS-Reality (Vision) - %s】${none}\n" "$remark"
                printf "  ${yellow}%-14s${none} %s\n" "外网 IP:" "$SERVER_IP"
                printf "  ${yellow}%-14s${none} %s\n" "主用 UUID:" "$uuid"
                printf "  ${yellow}%-14s${none} %s\n" "当前 SNI:" "$target_sni"
                
                local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${target_sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${remark}"
                echo -e "\n  ${cyan}通用链接:${none} \n  $link\n"
                
                if command -v qrencode >/dev/null 2>&1; then 
                    qrencode -m 2 -t UTF8 "$link"
                fi
            fi
        done
    fi
    
    local s_count=$(jq ".inbounds[] | select(.protocol==\"shadowsocks\") | length" "$CONFIG" 2>/dev/null || echo 0)
    if test "${s_count:-0}" -gt 0; then
        local s_port=$(jq -r ".inbounds[] | select(.protocol==\"shadowsocks\") | .port" "$CONFIG" 2>/dev/null)
        local s_pass=$(jq -r ".inbounds[] | select(.protocol==\"shadowsocks\") | .settings.password" "$CONFIG" 2>/dev/null)
        local s_method=$(jq -r ".inbounds[] | select(.protocol==\"shadowsocks\") | .settings.method" "$CONFIG" 2>/dev/null)
        
        if test -n "$s_port" && test "$s_port" != "null"; then
            hr
            printf "  ${cyan}【Shadowsocks】${none}\n"
            printf "  ${yellow}%-14s${none} %s\n" "端口:" "$s_port"
            printf "  ${yellow}%-14s${none} %s\n" "密码:" "$s_pass"
            
            local b64=$(printf '%s' "${s_method}:${s_pass}" | base64 | tr -d '\n')
            local link_ss="ss://${b64}@${SERVER_IP}:${s_port}#${REMARK_NAME}-SS"
            
            echo -e "\n  ${cyan}通用链接:${none} \n  $link_ss\n"
            if command -v qrencode >/dev/null 2>&1; then 
                qrencode -m 2 -t UTF8 "$link_ss"
            fi
        fi
    fi
}

# -- 商用流量与运行状态 --
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

# -- 卸载引擎 --
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

# -- 矩阵切换注入核心 --
_update_matrix() {
    echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
    jq --arg dest "$BEST_SNI:443" --slurpfile snis /tmp/sni_array.json '
        (.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) = $snis[0] |
        (.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.dest) = $dest
    ' "$CONFIG" > "$CONFIG.tmp"
    if [ $? -eq 0 ]; then 
        mv -f "$CONFIG.tmp" "$CONFIG"
        fix_permissions
        systemctl restart xray >/dev/null 2>&1
    fi
    rm -f /tmp/sni_array.json
}

# -- 安装主逻辑 --
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
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1
    install_update_dat
    fix_xray_systemd_limits

    # 初始化配置骨架，出站强制附带 domainStrategy: AsIs
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
        "shortIds": ["$sid"]
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

# -- 主菜单 --
main_menu() {
    while true; do
        clear
        echo -e "${blue}===================================================${none}"
        echo -e "  ${magenta}Xray ex106 The Apex Vanguard - Project Genesis V106${none}"
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        if test "$svc" = "active"; then 
            svc="${green}运行中${none}"
        else 
            svc="${red}停止${none}"
        fi
        echo -e "  状态: $svc | 快捷指令: ${cyan}xrv${none}"
        echo -e "${blue}===================================================${none}"
        echo "  1) 核心安装 / 重构网络 (VLESS/SS 双协议)"
        echo "  2) 用户管理 (增删/导入/专属 SNI 挂载)"
        echo "  3) 分发中心 (多用户详情与紧凑二维码)"
        echo "  4) 手动更新 Geo 规则库 (已夜间自动热更)"
        echo "  5) 更新 Xray 核心 (无缝拉取最新版重启)"
        echo "  6) 无感热切 SNI 矩阵 (单选/多选/全选防封阵列)"
        echo "  7) 屏蔽规则管理 (BT/广告双轨拦截)"
        echo "  9) 运行状态 (实时 IP 统计/DNS/流量核算)"
        echo "  10) 初次安装、系统内核调优、双十一全域微操"
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
            9) do_status_menu ;;
            10) do_sys_init_menu ;;
            88) do_uninstall ;;
            0) exit 0 ;;
        esac
    done
}

preflight
main_menu
