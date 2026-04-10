#!/usr/bin/env bash
# ============================================================
# 脚本名称: g7g21.sh (Ultimate Cache & Hot-Swap Edition)

# 定制增量与重构特性: 
#   1. [战备缓存] 引入 sni_cache.txt 本地持久化，130+ 寡头域名扫一次管一辈子。
#   2. [智能复用] 交互层新增缓存读取与 `r` 键一键全网重新雷达测速功能。
#   3. [无感热切] 主菜单新增功能 9：实现一秒无感更换节点 SNI，无需破坏已有 UUID 与底层密钥。
#   4. [终极实体盾] 保留 130+ 海运/轮胎/快消/家电/硬件等跨国实体寡头免死金牌矩阵。
# ============================================================

# ----------------- 基础环境与全局变量 -----------------
if [[ $EUID -ne 0 ]]; then
    clear
    echo -e "\033[31m[错误] 此脚本必须以 root 身份运行!\033[0m" 1>&2
    exit 1
fi

SERVER_IP=""
URL_IP=""
HAS_IPV4=false
HAS_IPV6=false
BEST_SNI="www.microsoft.com"

LOG_FILE="/var/log/xray_g7g21_install.log"
CONFIG_DIR="/usr/local/etc/xray"
CONFIG="$CONFIG_DIR/config.json"
PUBKEY_FILE="$CONFIG_DIR/public.key"
SNI_CACHE_FILE="$CONFIG_DIR/sni_cache.txt"
SCRIPT_DIR="/usr/local/etc/xray-script"
UPDATE_DAT_SCRIPT="$SCRIPT_DIR/update-dat.sh"
DAT_DIR="/usr/local/share/xray"
XRAY_BIN="/usr/local/bin/xray"
SYMLINK="/usr/local/bin/xrv"

mkdir -p "$(dirname "$LOG_FILE")" "$CONFIG_DIR" 2>/dev/null
touch "$LOG_FILE" 2>/dev/null || LOG_FILE=""

# ----------------- 颜色输出与日志系统 -----------------
print_red()    { echo -e "\033[31m$1\033[0m"; [[ -n "$LOG_FILE" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
print_green()  { echo -e "\033[32m$1\033[0m"; [[ -n "$LOG_FILE" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
print_yellow() { echo -e "\033[33m$1\033[0m"; [[ -n "$LOG_FILE" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

display_cyan() { echo -e "\033[36m$1\033[0m"; }
hr()           { echo -e "\033[90m---------------------------------------------------\033[0m"; }
title() {
    echo -e "\n\033[94m===================================================\033[0m"
    echo -e "  \033[96m$1\033[0m"
    echo -e "\033[94m===================================================\033[0m"
}

log_only() { [[ -n "$LOG_FILE" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
log_info() { echo -e "\033[32m[✓]\033[0m $1"; log_only "$1"; }
log_warn() { echo -e "\033[33m[!]\033[0m $1"; log_only "[WARN] $1"; }
log_err()  { echo -e "\033[31m[✗]\033[0m $1"; log_only "[ERROR] $1"; }

exit_with_error() {
    print_red "致命错误: $1"
    exit 1
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

# ----------------- 极速 SNI 嗅探引擎 (内核扫描层) -----------------
run_sni_scanner() {
    print_yellow "\n[深度雷达] 正在启动 1000ms 极速淘汰制扫描，全网遍历 130+ 实体寡头..."
    print_yellow "预计耗时约 60 秒，完成后将永久记录至本地缓存...\n"
    
    local sni_list=(
        "www.maersk.com" "www.msc.com" "www.cma-cgm.com" "www.hapag-lloyd.com"
        "www.michelin.com" "www.bridgestone.com" "www.goodyear.com" "www.pirelli.com"
        "www.sony.com" "www.sony.net" "www.panasonic.com" "www.canon.com"
        "www.hp.com" "www.nintendo.com" "www.lg.com" "www.epson.com" "www.asus.com"
        "www.unilever.com" "www.loreal.com" "www.shiseido.com" "www.jnj.com" "www.kao.com"
        "www.ikea.com" "www.nike.com" "www.adidas.com" "www.uniqlo.com" "www.zara.com"
        "www.hermes.com" "www.chanel.com" "services.chanel.com"
        "www.louisvuitton.com" "eu.louisvuitton.com" "www.dior.com"
        "www.ferragamo.com" "www.versace.com" "www.prada.com"
        "www.fendi.com" "www.gucci.com" "www.tiffany.com"
        "www.esteelauder.com" "www.maje.com" "www.swatch.com"
        "www.coca-cola.com" "www.coca-colacompany.com" "www.pepsi.com" "www.pepsico.com"
        "www.nestle.com" "www.bk.com" "www.heinz.com" "www.pg.com"
        "www.basf.com" "www.bayer.com" "www.bosch.com" "www.bosch-home.com"
        "www.toyota.com" "www.lexus.com" "www.volkswagen.com" "www.vw.com" 
        "www.audi.com" "www.porsche.com" "www.skoda-auto.com"
        "www.gm.com" "www.chevrolet.com" "www.cadillac.com"
        "www.ford.com" "www.lincoln.com" "www.hyundai.com" "www.kia.com"
        "www.peugeot.com" "www.renault.com"
        "www.bmw.com" "www.mercedes-benz.com" "www.jaguar.com" "www.landrover.com" 
        "www.astonmartin.com" "www.mclaren.com" "www.ferrari.com" "www.maserati.com"
        "www.volvocars.com" "www.tesla.com"
        "www.apple.com" "swdist.apple.com" "swcdn.apple.com" "updates.cdn-apple.com"
        "mensura.cdn-apple.com" "osxapps.itunes.apple.com" "aod.itunes.apple.com"
        "is1-ssl.mzstatic.com" "itunes.apple.com" "gateway.icloud.com" "www.icloud.com"
        "www.microsoft.com" "update.microsoft.com" "windowsupdate.microsoft.com"
        "software.download.prss.microsoft.com" "cdn-dynmedia-1.microsoft.com"
        "s0.awsstatic.com" "d1.awsstatic.com" "images-na.ssl-images-amazon.com" "m.media-amazon.com"
        "www.nvidia.com" "academy.nvidia.com" "images.nvidia.com" "blogs.nvidia.com"
        "docs.nvidia.com" "docscontent.nvidia.com" "www.amd.com" "webinar.amd.com" "ir.amd.com"
        "www.cisco.com" "www.dell.com" "www.samsung.com" "www.sap.com"
        "www.oracle.com" "www.mysql.com" "www.swift.com"
        "download-installer.cdn.mozilla.net" "addons.mozilla.org"
        "www.airbnb.co.uk" "www.airbnb.ca" "www.airbnb.com.sg" "www.airbnb.com.au" "www.airbnb.co.in"
        "www.ubi.com" "lol.secure.dyn.riotcdn.net" "one-piece.com"
        "www.speedtest.net" "www.speedtest.org" "player.live-video.net"
    )

    local valid_snis=()
    local valid_times=()

    for sni in "${sni_list[@]}"; do
        local res
        res=$(LC_ALL=C curl -sI -m 1 -w "\n%{time_connect}" --tls13 "https://$sni" 2>/dev/null)
        
        [[ -z "$res" ]] && continue
        
        # 防 CF 白嫖
        if echo "$res" | grep -qiE "server: cloudflare|cf-ray|cf-cache-status"; then
            continue
        fi

        local time_str
        time_str=$(echo "$res" | tail -n 1)
        local time_ms
        time_ms=$(echo "$time_str" | awk '{print int($1 * 1000)}')

        if [[ -n "$time_ms" && "$time_ms" -gt 0 ]]; then
            echo -e " \033[32m[+]\033[0m $sni : \033[33m${time_ms}ms\033[0m"
            valid_snis+=("$sni")
            valid_times+=("$time_ms")
        fi
    done

    local n=${#valid_snis[@]}
    if [[ $n -eq 0 ]]; then
        print_red "\n=> 极端情况：网络严重受阻，自动回退写入保底配置"
        echo "www.microsoft.com 999" > "$SNI_CACHE_FILE"
        return
    fi

    # 冒泡排序
    for ((i=0; i<n-1; i++)); do
        for ((j=0; j<n-i-1; j++)); do
            if [[ ${valid_times[j]} -gt ${valid_times[j+1]} ]]; then
                local temp_t=${valid_times[j]}
                valid_times[j]=${valid_times[j+1]}
                valid_times[j+1]=$temp_t
                
                local temp_s=${valid_snis[j]}
                valid_snis[j]=${valid_snis[j+1]}
                valid_snis[j+1]=$temp_s
            fi
        done
    done

    # 写入缓存库持久化
    rm -f "$SNI_CACHE_FILE"
    for ((i=0; i<n; i++)); do
        echo "${valid_snis[i]} ${valid_times[i]}" >> "$SNI_CACHE_FILE"
    done
    print_green "\n嗅探完毕！已永久建立本地防墙战备缓存库。"
}

# ----------------- 智能交互选单 (带缓存识别) -----------------
choose_sni() {
    while true; do
        if [[ -f "$SNI_CACHE_FILE" ]]; then
            echo -e "\n  \033[36m[发现本地节点缓存！为您展示 Top 10 历史极速赢家]\033[0m"
            local cached_snis=()
            local cached_times=()
            local idx=0
            
            while read -r s t; do
                [[ -z "$s" || -z "$t" ]] && continue
                cached_snis+=("$s")
                cached_times+=("$t")
                ((idx++))
                [[ $idx -ge 10 ]] && break
            done < "$SNI_CACHE_FILE"

            for ((i=0; i<${#cached_snis[@]}; i++)); do
                local ms_color="\033[32m"
                [[ ${cached_times[i]} -gt 150 ]] && ms_color="\033[33m"
                [[ ${cached_times[i]} -gt 300 ]] && ms_color="\033[31m"
                echo -e "  $((i+1))) ${cached_snis[i]} (近期缓存延迟: ${ms_color}${cached_times[i]}ms\033[0m)"
            done
            echo -e "  \033[33mr) [执行新扫描] 抛弃缓存，全网重新雷达测速\033[0m"
            echo "  0) 手动输入其他自定义域名"

            read -rp "  请下达指令 [默认回车选 1，即最优缓存]: " sel
            sel=${sel:-1}

            if [[ "$sel" == "r" || "$sel" == "R" ]]; then
                run_sni_scanner
                continue # 扫完重新循环本函数，读取新缓存
            elif [[ "$sel" == "0" ]]; then
                read -rp "  请输入自定义域名: " custom_sni
                BEST_SNI=${custom_sni:-www.microsoft.com}
                break
            elif [[ "$sel" -ge 1 && "$sel" -le "${#cached_snis[@]}" ]] 2>/dev/null; then
                BEST_SNI="${cached_snis[$((sel-1))]}"
                break
            else
                BEST_SNI="${cached_snis[0]}"
                break
            fi
        else
            # 首次执行，强制进行扫描
            run_sni_scanner
        fi
    done
    print_green "=> 已为您锁定核心伪装层: $BEST_SNI"
}

# ----------------- 系统检测与依赖 -----------------
detect_distribution() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_ID=${ID:-unknown}
        OS_VERSION=${VERSION_ID:-unknown}
    elif [[ -f /etc/redhat-release ]]; then
        OS_ID=$(grep -qi "centos" /etc/redhat-release && echo "centos" || echo "rhel")
    elif [[ -f /etc/debian_version ]]; then
        OS_ID="debian"
    else
        OS_ID="unknown"
    fi
    log_only "检测到系统: $OS_ID $OS_VERSION"
}

detect_package_manager() {
    if command_exists apt-get; then
        PKG_MANAGER="apt"; PKG_UPDATE="apt-get update -y"; PKG_INSTALL="apt-get install -y"
        while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
            log_warn "等待 dpkg 锁释放..."; sleep 3
        done
    elif command_exists yum; then
        PKG_MANAGER="yum"; PKG_UPDATE="yum makecache"; PKG_INSTALL="yum install -y"
        yum install -y epel-release 2>/dev/null || true
    elif command_exists dnf; then
        PKG_MANAGER="dnf"; PKG_UPDATE="dnf makecache"; PKG_INSTALL="dnf install -y"
        dnf install -y epel-release 2>/dev/null || true
    else
        exit_with_error "不支持的包管理器，请使用 apt/yum/dnf 系统"
    fi
}

check_service_manager() {
    if command_exists systemctl && systemctl --version >/dev/null 2>&1; then
        SERVICE_MANAGER="systemctl"
    elif command_exists service; then
        SERVICE_MANAGER="service"
    else
        exit_with_error "不支持的服务管理器(需 systemd/sysvinit)"
    fi
}

install_dependencies() {
    log_info "更新软件包列表并安装底层依赖..."
    local retry_count=0
    while [[ $retry_count -lt 3 ]]; do
        eval "$PKG_UPDATE" >/dev/null 2>&1 && break
        retry_count=$((retry_count + 1))
        log_warn "软件源更新失败，重试 $retry_count/3..."; sleep 3
    done

    local pkgs="curl wget gawk jq ca-certificates gnupg unzip vnstat xxd cron iproute2"
    [[ "$PKG_MANAGER" == "apt" ]] && pkgs="$pkgs lsb-release cron iproute2 net-tools"
    [[ "$PKG_MANAGER" == "yum" || "$PKG_MANAGER" == "dnf" ]] && pkgs="$pkgs cronie iproute net-tools"

    retry_count=0
    while [[ $retry_count -lt 3 ]]; do
        eval "$PKG_INSTALL $pkgs" >/dev/null 2>&1 && break
        retry_count=$((retry_count + 1))
        log_warn "依赖安装受阻，重试 $retry_count/3..."; sleep 3
    done
    
    for tool in curl jq xxd vnstat awk; do
        command_exists "$tool" || exit_with_error "关键依赖 $tool 安装失败，请检查软件源！"
    done
}

# ----------------- 防火墙自动化管理 -----------------
open_firewall_port() {
    local port=$1
    local proto=$2
    log_info "尝试在本地防火墙放行端口 ${port}/${proto}..."
    
    if command_exists ufw && ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw allow "${port}/${proto}" >/dev/null 2>&1
    fi
    if command_exists firewall-cmd && systemctl is-active --quiet firewalld 2>/dev/null; then
        firewall-cmd --permanent --add-port="${port}/${proto}" >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
    fi
    if command_exists iptables; then
        if ! iptables -C INPUT -p "${proto}" --dport "${port}" -j ACCEPT 2>/dev/null; then
            iptables -I INPUT -p "${proto}" --dport "${port}" -j ACCEPT 2>/dev/null
            command_exists netfilter-persistent && netfilter-persistent save >/dev/null 2>&1
            command_exists service && service iptables save >/dev/null 2>&1
        fi
    fi
}

# ----------------- 前置硬核环境自检 -----------------
pre_flight_checks() {
    log_info "执行安装前置环境预检 (Pre-flight Checks)..."

    local free_mem=$(free -m 2>/dev/null | awk '/^Mem:/{print $4}')
    if [[ -n "$free_mem" && "$free_mem" -lt 50 ]]; then
        log_warn "系统可用内存不足 50MB，存在 OOM (内存溢出) 风险！"
    fi

    if curl -s -4 -m 3 https://cloudflare.com/cdn-cgi/trace | grep -q "ip="; then HAS_IPV4=true; fi
    if curl -s -6 -m 3 https://cloudflare.com/cdn-cgi/trace | grep -q "ip="; then HAS_IPV6=true; fi
    
    if [[ "$HAS_IPV4" == "false" && "$HAS_IPV6" == "false" ]]; then
        exit_with_error "服务器无外网连通性，请检查网络配置！"
    fi

    local stack_msg="网络栈状态: "
    [[ "$HAS_IPV4" == "true" ]] && stack_msg+="[IPv4 正常] "
    [[ "$HAS_IPV6" == "true" ]] && stack_msg+="[IPv6 正常]"
    log_info "$stack_msg"

    local web_time=$(curl -sI -m 5 https://www.cloudflare.com 2>/dev/null | grep -i "^date:" | sed 's/^[Dd]ate: //g' | tr -d '\r')
    if [[ -n "$web_time" ]]; then
        local web_ts=$(date -d "$web_time" +%s 2>/dev/null)
        local local_ts=$(date +%s)
        if [[ -n "$web_ts" ]]; then
            local diff=$(( local_ts - web_ts ))
            [[ $diff -lt 0 ]] && diff=$(( -diff ))
            if (( diff > 60 )); then
                log_err "系统时间与标准时间相差 $diff 秒！"
                print_red "=================================================="
                print_red "XTLS-Reality 协议对系统时间极度敏感（误差需小于60秒）！"
                print_red "若时间偏差过大，安装后将100%无法连接并直接断流。"
                print_red "=================================================="
                print_yellow "请手动校准时间后再运行本脚本。"
                exit_with_error "时间校验失败，安装已安全阻断。"
            fi
        fi
    fi
}

check_port_occupied() {
    local port=$1
    if command_exists ss; then
        ss -tuln 2>/dev/null | grep -q ":$port " && return 0
    elif command_exists netstat; then
        netstat -tuln 2>/dev/null | grep -q ":$port " && return 0
    fi
    return 1 
}

# ----------------- 数据防护与生成器 -----------------
get_server_ip_silent() {
    [[ -n "$SERVER_IP" ]] && return 0
    log_info "正在提取服务器公网出口 IP..."
    local ip_sources=("https://api4.ipify.org" "https://ipv4.icanhazip.com" "http://www.cloudflare.com/cdn-cgi/trace")
    
    if [[ "$HAS_IPV4" == "true" ]]; then
        for source in "${ip_sources[@]}"; do
            if [[ "$source" == *"cloudflare"* ]]; then
                SERVER_IP=$(curl -s -4 --connect-timeout 5 "$source" 2>/dev/null | grep "ip=" | awk -F "=" '{print $2}' | tr -d '\r\n')
            else
                SERVER_IP=$(curl -s -4 --connect-timeout 5 "$source" 2>/dev/null | tr -d '\r\n')
            fi
            [[ "$SERVER_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] && break
        done
    fi
    
    if [[ -z "$SERVER_IP" && "$HAS_IPV6" == "true" ]]; then
        SERVER_IP=$(curl -s -6 --connect-timeout 5 "http://www.cloudflare.com/cdn-cgi/trace" 2>/dev/null | grep "ip=" | awk -F "=" '{print $2}' | tr -d '\r\n')
    fi

    [[ -z "$SERVER_IP" ]] && exit_with_error "IP 获取失败，请检查防火墙或路由配置！"
    
    if [[ "$SERVER_IP" == *":"* ]]; then
        URL_IP="[$SERVER_IP]"
    else
        URL_IP="$SERVER_IP"
    fi
}

_fix_permissions() {
    chmod 600 "$CONFIG" 2>/dev/null
    chown nobody:nogroup "$CONFIG" 2>/dev/null || chown nobody:nobody "$CONFIG" 2>/dev/null
    if [[ -f "$PUBKEY_FILE" ]]; then
        chmod 600 "$PUBKEY_FILE" 2>/dev/null
        chown nobody:nogroup "$PUBKEY_FILE" 2>/dev/null || chown nobody:nobody "$PUBKEY_FILE" 2>/dev/null
    fi
}

_safe_jq_write() {
    local filter="$1"
    local tmp; tmp=$(mktemp /tmp/xray_cfg_XXXXXX.json)
    local bak="${CONFIG}.bak.$(date +%s)"
    [[ -f "$CONFIG" ]] && cp "$CONFIG" "$bak"
    
    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null && jq empty "$tmp" 2>/dev/null; then
        mv "$tmp" "$CONFIG"
        _fix_permissions
        return 0
    fi
    log_err "JSON 原子注入失败，触发自动回滚保护!"
    [[ -f "$bak" ]] && mv "$bak" "$CONFIG"
    rm -f "$tmp"
    return 1
}

gen_uuid() {
    if [[ -x "$XRAY_BIN" ]]; then
        "$XRAY_BIN" uuid 2>/dev/null
    elif [[ -r /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    else
        cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 32 | head -n 1 | sed 's/^\(........\)\(....\)\(....\)\(....\)\(............\)$/\1-\2-\3-\4-\5/'
    fi
}
gen_short_id() { head -c 8 /dev/urandom | xxd -p | tr -d '\n'; }
gen_ss_pass() { head -c 24 /dev/urandom | base64 | tr -d '=/+\n' | head -c 24; }
gen_x25519() {
    local raw; raw=$("$XRAY_BIN" x25519 2>/dev/null)
    [[ -z "$raw" ]] && exit_with_error "核心引擎生成 X25519 密钥对失败"
    
    X25519_PRIV=$(echo "$raw" | grep -iE "(private|privatekey)" | awk -F ':' '{print $2}' | tr -d ' \r\n\t')
    X25519_PUB=$(echo "$raw" | grep -iE "password" | awk -F ':' '{print $2}' | tr -d ' \r\n\t')
    [[ -z "$X25519_PUB" ]] && X25519_PUB=$(echo "$raw" | grep -iE "(public|publickey)" | awk -F ':' '{print $2}' | tr -d ' \r\n\t')
}

validate_port() { [[ -n "$1" && "$1" =~ ^[0-9]+$ && "$1" -ge 1 && "$1" -le 65535 ]]; }
validate_integer() { [[ -n "$1" && "$1" =~ ^[0-9]+$ ]]; }

# ----------------- 自动化运维 (Cron) -----------------
setup_cron_dat() {
    mkdir -p "$SCRIPT_DIR" "$DAT_DIR"
    cat > "$UPDATE_DAT_SCRIPT" <<'EOF'
#!/usr/bin/env bash
curl -fsSL -o /usr/local/share/xray/geoip.dat https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat
curl -fsSL -o /usr/local/share/xray/geosite.dat https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat
systemctl restart xray
EOF
    chmod +x "$UPDATE_DAT_SCRIPT"
    (crontab -l 2>/dev/null | grep -v "no crontab" | grep -v "$UPDATE_DAT_SCRIPT"; echo "0 3 * * * $UPDATE_DAT_SCRIPT") | crontab -
    log_info "已注入底层守护：每天凌晨 3:00 自动更新 Geo 规则库"
}

# ----------------- Xray 核心架构部署 -----------------
install_xray_core() {
    log_info "从 GitHub 拉取并验证 Xray-core..."
    local install_url="https://github.com/XTLS/Xray-install/raw/main/install-release.sh"
    local script_path="/tmp/xray-install.sh"
    
    local retry=0
    while [[ $retry -lt 3 ]]; do
        if curl -L -s --connect-timeout 10 "$install_url" -o "$script_path" && grep -q "#!/" "$script_path"; then
            chmod +x "$script_path"; break
        fi
        retry=$((retry + 1))
        log_warn "官方脚本下载受阻，重试 $retry/3..."; sleep 3
    done
    [[ $retry -eq 3 ]] && exit_with_error "核心安装脚本获取失败"
    
    timeout 300 bash "$script_path" install >/dev/null 2>&1 || exit_with_error "Xray 核心写入超时或失败"
    rm -f "$script_path"
    
    chmod -R 755 /usr/local/etc/xray
    _fix_permissions
    
    if [[ -f "$0" ]]; then
        local real_path=$(realpath "$0" 2>/dev/null)
        if [[ -n "$real_path" && ! -L "$SYMLINK" ]]; then
            ln -sf "$real_path" "$SYMLINK"
            chmod +x "$real_path"
        fi
    fi
}

_init_base_config() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG" <<EOF
{
  "log": { "loglevel": "warning" },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {"tag_id":"bt", "type":"field","protocol":["bittorrent"],"outboundTag":"block","_enabled":true},
      {"tag_id":"cn", "type":"field","ip":["geoip:cn"],"outboundTag":"block","_enabled":true},
      {"tag_id":"ads","type":"field","domain":["geosite:category-ads-all"],"outboundTag":"block","_enabled":true}
    ]
  },
  "inbounds": [],
  "outbounds": [
    {"protocol":"freedom","tag":"direct"},
    {"protocol":"blackhole","tag":"block"}
  ]
}
EOF
}

do_install() {
    title "全新部署 / 重构 Xray 网络"
    if [[ "$SERVICE_MANAGER" == "systemctl" ]] && systemctl is-active --quiet xray 2>/dev/null; then
        print_yellow "检测到 Xray 正在运行，继续操作将覆盖所有已有节点!"
        read -rp "是否继续覆写? [y/N]: " c; [[ "$c" != "y" ]] && return
        systemctl stop xray 2>/dev/null
    else
        service xray stop 2>/dev/null
    fi
    
    pre_flight_checks
    get_server_ip_silent

    echo -e "\n  [拓扑模式选择]"
    echo "  1) VLESS-Reality + XTLS Vision (推荐)"
    echo "  2) Shadowsocks (落地机器用)"
    echo "  3) 安装 1 和 2"
    read -rp "  请选择 [1]: " choice
    choice=${choice:-1}
    
    local p=443
    local d="www.microsoft.com"
    local s="www.microsoft.com"
    local sp=8388
    
    if [[ "$choice" == "1" || "$choice" == "3" ]]; then
        echo ""
        while true; do
            read -r -t 15 -p "VLESS 监听端口(1-65535) [回车默认 443]: " input_p
            if validate_port "$input_p"; then p="$input_p"; else p=443; fi
            if check_port_occupied "$p"; then print_red "端口 $p 已经被占用！请更换！"; else break; fi
        done
        
        echo -e "\n  [智能 SNI 伪装目标设置]"
        choose_sni
        d="$BEST_SNI"
        
        read -rp "SNI(留空同域名): " input_s
        s=${input_s:-$d}
    fi
    
    if [[ "$choice" == "2" || "$choice" == "3" ]]; then
        echo ""
        while true; do
            read -r -t 15 -p "SS 监听端口(1-65535) [回车默认 8388]: " input_sp
            if validate_port "$input_sp"; then sp="$input_sp"; else sp=8388; fi
            if [[ "$choice" == "3" && "$sp" == "$p" ]]; then print_red "SS 端口不能与 VLESS 相同！"; continue; fi
            if check_port_occupied "$sp"; then print_red "端口 $sp 已经被占用！请更换！"; else break; fi
        done
    fi

    echo ""
    hr
    install_xray_core
    _init_base_config
    setup_cron_dat
    
    if [[ "$choice" == "1" || "$choice" == "3" ]]; then
        open_firewall_port "$p" "tcp"
        gen_x25519
        local uuid=$(gen_uuid); local sid=$(gen_short_id)
        
        echo "$X25519_PUB" > "$PUBKEY_FILE"
        _fix_permissions
        
        _safe_jq_write ".inbounds += [{
          \"tag\": \"vless-reality\", \"port\": $p, \"protocol\": \"vless\",
          \"settings\": {
            \"clients\": [{
              \"id\": \"$uuid\", \"flow\": \"xtls-rprx-vision\",
              \"padding\": { \"triggerThreshold\": 900, \"maxLengthLong\": 500, \"extraLengthLong\": 900, \"maxLengthShort\": 256 }
            }], \"decryption\": \"none\"
          },
          \"streamSettings\": {
            \"network\": \"tcp\", \"security\": \"reality\",
            \"realitySettings\": {
              \"dest\": \"$d:443\", \"serverNames\": [\"$s\"],
              \"privateKey\": \"$X25519_PRIV\", \"shortIds\": [\"$sid\"]
            }
          },
          \"sniffing\": {\"enabled\":true,\"destOverride\":[\"http\",\"tls\",\"quic\"]}
        }]"
        log_info "VLESS-Reality (Vision) 配置装载完毕"
    fi
    
    if [[ "$choice" == "2" || "$choice" == "3" ]]; then
        open_firewall_port "$sp" "tcp"
        open_firewall_port "$sp" "udp"
        local pass=$(gen_ss_pass)
        _safe_jq_write ".inbounds += [{
            \"tag\": \"shadowsocks\", \"port\": $sp, \"protocol\": \"shadowsocks\",
            \"settings\": { \"method\": \"aes-256-gcm\", \"password\": \"$pass\", \"network\": \"tcp,udp\" }
        }]"
        log_info "Shadowsocks 备用配置装载完毕"
    fi

    log_info "正在拉起 Xray 核心服务并执行终期自检..."
    if [[ "$SERVICE_MANAGER" == "systemctl" ]]; then
        systemctl enable xray &>/dev/null
        systemctl restart xray
        sleep 2
        if ! systemctl is-active --quiet xray; then
            print_red "\n警告：Xray 服务启动失败！配置文件可能存在违规项！"
            systemctl status xray --no-pager | grep -iE "(error|fail)" | head -n 5
            read -rp "按 Enter 继续..." _
            return
        fi
    else
        service xray restart
    fi
    
    print_green "\n底层网络拓扑构建完毕！且服务已成功运行！"
    do_summary
    read -rp "按 Enter 返回总控台..." _
}

# ----------------- 独立工具：无感热替换 SNI -----------------
do_change_sni() {
    title "热插拔：一键无感更换 SNI 伪装层"
    local vidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null)
    if [[ "$vidx" == "null" || -z "$vidx" ]]; then
        print_yellow "未发现 VLESS-Reality 配置，此功能不可用。"
        read -rp "按 Enter 返回..."; return
    fi

    local cur_sni=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.serverNames[0]" "$CONFIG")
    echo -e "当前正在使用的宿主 SNI: \033[33m$cur_sni\033[0m"
    hr
    
    choose_sni
    local new_sni="$BEST_SNI"
    
    if [[ "$cur_sni" == "$new_sni" ]]; then
        print_yellow "\n伪装层未发生改变，取消操作。"
        read -rp "按 Enter 返回..."; return
    fi

    log_info "正在通过 jq 原子化改写底层路由..."
    _safe_jq_write "
      .inbounds[$vidx].streamSettings.realitySettings.serverNames[0] = \"$new_sni\" |
      .inbounds[$vidx].streamSettings.realitySettings.dest = \"$new_sni:443\"
    "
    
    if [[ "$SERVICE_MANAGER" == "systemctl" ]]; then systemctl restart xray; else service xray restart; fi
    print_green "\n成功！SNI 已无感变更为: $new_sni ，您的 UUID 和底层私钥完全不受影响。"
    do_summary
    read -rp "按 Enter 返回..." _
}

# ----------------- 其他常规管理功能 (缩略) -----------------
# (用户管理、节点展示等保持与上一版完全一致，此处直接拼装...)

do_user_manager() {
    while true; do
        title "多用户权限与 UUID 管理"
        local vidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null)
        if [[ "$vidx" == "null" || -z "$vidx" ]]; then
            print_yellow "未发现 VLESS-Reality 配置，不可用。"; read -rp "按 Enter 返回..."; return
        fi
        echo -e "当前挂载 UUID 列表:"; jq -r ".inbounds[$vidx].settings.clients[] | \"  - \(.id)\"" "$CONFIG"
        hr
        echo "  1) 新增一个随机 UUID"; echo "  2) 删除指定 UUID"; echo "  0) 返回"
        read -rp "操作: " uopt
        case "$uopt" in
            1) local nu=$(gen_uuid); _safe_jq_write ".inbounds[$vidx].settings.clients += [{\"id\":\"$nu\",\"flow\":\"xtls-rprx-vision\",\"padding\":{\"triggerThreshold\":900,\"maxLengthLong\":500,\"extraLengthLong\":900,\"maxLengthShort\":256}}]"; systemctl restart xray 2>/dev/null || service xray restart; print_green "新增成功: $nu" ;;
            2) local c=$(jq ".inbounds[$vidx].settings.clients|length" "$CONFIG"); if [[ "$c" -le 1 ]]; then print_red "至少需保留1个UUID！"; continue; fi; read -rp "输入要删除的 UUID: " du; [[ -z "$du" ]] && continue; _safe_jq_write "del(.inbounds[$vidx].settings.clients[] | select(.id == \"$du\"))"; systemctl restart xray 2>/dev/null || service xray restart; print_green "删除完成" ;;
            0) break ;;
        esac
    done
}

do_vision_seed_config() {
    title "XTLS Vision Seed (Padding) 参数微调"
    local vidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null)
    [[ "$vidx" == "null" || -z "$vidx" ]] && return
    local c_pad=$(jq ".inbounds[$vidx].settings.clients[0].padding" "$CONFIG")
    local cur_trig=$(echo "$c_pad" | jq -r ".triggerThreshold // 900")
    local cur_ml=$(echo "$c_pad" | jq -r ".maxLengthLong // 500")
    local cur_el=$(echo "$c_pad" | jq -r ".extraLengthLong // 900")
    local cur_ms=$(echo "$c_pad" | jq -r ".maxLengthShort // 256")

    read -rp " 1. 长填充触发阈值 [$cur_trig]: " val_trig
    read -rp " 2. 长填充最大字节 [$cur_ml]: " val_ml
    read -rp " 3. 长填充额外字节 [$cur_el]: " val_el
    read -rp " 4. 正常最大字节数 [$cur_ms]: " val_ms

    if ! validate_integer "$val_trig"; then val_trig=$cur_trig; fi
    if ! validate_integer "$val_ml"; then val_ml=$cur_ml; fi
    if ! validate_integer "$val_el"; then val_el=$cur_el; fi
    if ! validate_integer "$val_ms"; then val_ms=$cur_ms; fi

    _safe_jq_write ".inbounds[$vidx].settings.clients |= map(.padding = {\"triggerThreshold\": $val_trig,\"maxLengthLong\": $val_ml,\"extraLengthLong\": $val_el,\"maxLengthShort\": $val_ms})"
    systemctl restart xray 2>/dev/null || service xray restart
    print_green "参数注入成功！"; read -rp "按 Enter 返回..." _
}

do_upgrade_core() {
    title "更新 / 降级 Xray 核心引擎"
    local cur_ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 | awk '{print $2}')
    echo -e "当前版本: \033[32m${cur_ver}\033[0m"
    local vs=$(curl -fsSL -m 10 https://api.github.com/repos/XTLS/Xray-core/releases | grep '"tag_name"' | cut -d'"' -f4 | head -n 10)
    [[ -z "$vs" ]] && return
    local i=1; local arr=(); while IFS= read -r v; do echo " $i) $v"; arr+=("$v"); ((i++)); done <<< "$vs"
    read -rp "选择版本 [0 取消]: " sel; [[ "$sel" == "0" || -z "$sel" ]] && return
    local ver="${arr[$((sel-1))]}"; [[ -n "$ver" ]] && bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -v "$ver" >/dev/null 2>&1
    systemctl restart xray 2>/dev/null || service xray restart; print_green "切换成功"; read -rp "按 Enter 返回..." _
}

do_summary() {
    title "终端节点分发中心"
    [[ ! -f "$CONFIG" ]] && return
    get_server_ip_silent
    local vidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null)
    if [[ "$vidx" != "null" && -n "$vidx" ]]; then
        local port=$(jq -r ".inbounds[$vidx].port" "$CONFIG")
        local sni=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.serverNames[0]" "$CONFIG")
        local sid=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.shortIds[0]" "$CONFIG")
        local primary_uuid=$(jq -r ".inbounds[$vidx].settings.clients[0].id" "$CONFIG")
        local pub=$(cat "$PUBKEY_FILE" 2>/dev/null)
        echo -e " 1) chrome (默认) 2) firefox 3) safari 4) ios"
        read -rp "指纹选择 [1]: " fp_sel
        case "${fp_sel:-1}" in 2) utls="firefox" ;; 3) utls="safari" ;; 4) utls="ios" ;; *) utls="chrome" ;; esac
        hr
        display_cyan "【VLESS-Reality】IP: $SERVER_IP | 端口: $port | SNI: $sni"
        jq -r ".inbounds[$vidx].settings.clients[].id" "$CONFIG" | while read -r u; do
            echo -e "\033[33m$u\033[0m\nvless://$u@${URL_IP}:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$sni&fp=$utls&pbk=$pub&sid=$sid&type=tcp&headerType=none#xp-reality"
        done
        echo ""
    fi
    local sidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="shadowsocks")] | .[0].key' "$CONFIG" 2>/dev/null)
    if [[ "$sidx" != "null" && -n "$sidx" ]]; then
        local sport=$(jq -r ".inbounds[$sidx].port" "$CONFIG")
        local spass=$(jq -r ".inbounds[$sidx].settings.password" "$CONFIG")
        local sm=$(jq -r ".inbounds[$sidx].settings.method" "$CONFIG")
        local b64=$(printf '%s' "${sm}:${spass}" | base64 | tr -d '\n')
        display_cyan "【Shadowsocks】\n ss://${b64}@${URL_IP}:${sport}#xp-ss\n"
    fi
}

do_status() {
    title "服务器资源探针"
    systemctl status xray --no-pager 2>/dev/null | head -n 8 || service xray status | head -n 8
    hr
    command_exists vnstat && vnstat -i $(ip route show default | awk '/default/{print $5}' | head -1)
    read -rp "按 Enter 返回..." _
}

# ----------------- 总调度台 -----------------
main_menu() {
    detect_distribution
    detect_package_manager
    check_service_manager
    install_dependencies

    while true; do
        clear
        echo -e "\033[94m===================================================\033[0m"
        echo -e " \033[96mXray G7G21 本地缓存与热插拔终极版 (输入 xrv 唤醒)\033[0m"
        echo -e "\033[94m===================================================\033[0m"
        
        local svc="inactive"
        if [[ "$SERVICE_MANAGER" == "systemctl" ]]; then systemctl is-active --quiet xray 2>/dev/null && svc="active"
        else service xray status 2>/dev/null | grep -q "running" && svc="active"; fi
        local cur_ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 | awk '{print $2}')
        local st_str=$([[ "$svc" == "active" ]] && echo -e "\033[32m▶ 稳定运行\033[0m" || echo -e "\033[31m■ 脱机停止\033[0m")
        echo -e "  服务状态: $st_str | 版本: \033[33m${cur_ver:-N/A}\033[0m\n"
        
        echo "  1) 核心重装 / 覆盖网络拓扑"
        echo "  2) 用户管理 (UUID 增删控制)"
        echo "  3) 节点分享 (查看所有链接及 uTLS 调整)"
        echo "  4) 高阶调优 (Vision Seed 动态 Padding)"
        echo "  5) 系统探针 (流量与运行日志)"
        echo "  6) 在线更新 / 降级 Xray 核心引擎"
        echo "  7) 强制刷新 Geo 路由规则库"
        echo "  8) 安全卸载 (清理所有痕迹)"
        echo -e "  \033[96m9) [专属特权] 无感热替换 SNI 伪装源\033[0m"
        echo "  0) 退出总控台"
        hr
        read -rp "请下达指令: " opt
        case "$opt" in
            1) do_install ;;
            2) do_user_manager ;;
            3) do_summary; read -rp "按 Enter 返回..." _ ;;
            4) do_vision_seed_config ;;
            5) do_status ;;
            6) do_upgrade_core ;;
            7) 
               curl -fsSL -o "$DAT_DIR/geoip.dat" "https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"
               curl -fsSL -o "$DAT_DIR/geosite.dat" "https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat"
               systemctl restart xray 2>/dev/null || service xray restart; print_green "Geo 库同步完成"; read -rp "按 Enter 返回..." _ ;;
            8) 
               systemctl stop xray 2>/dev/null; systemctl disable xray 2>/dev/null; service xray stop 2>/dev/null
               rm -f /etc/systemd/system/xray*.service; systemctl daemon-reload 2>/dev/null
               crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT" | crontab -
               rm -rf "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SYMLINK" "$SCRIPT_DIR"
               print_green "服务彻底粉碎。"; exit 0 ;;
            9) do_change_sni ;;
            0) exit 0 ;;
            *) print_red "无效指令" ;;
        esac
    done
}

trap 'print_red "\n中断"; exit 1' INT TERM
main_menu
