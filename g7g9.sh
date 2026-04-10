#!/usr/bin/env bash
# ============================================================
# 脚本名称: g7g9.sh (Grandmaster Industrial Fusion Edition)
# 核心增量与 Bug 修复: 
#   1. 修复 IPv6 链接未被 [] 闭合导致的客户端解析崩溃问题。
#   2. 修复 Vision Seed 输入非数字导致 jq JSON 结构断裂的致命 Bug。
#   3. 修复纯净系统 crontab 初始化报错造成的脏数据污染。
#   4. 修复管道符 (curl | bash) 运行时快捷命令软链接创建失败的异常。
#   5. 补全系统卸载残留，增加 systemd 守护进程文件粉碎。
# ============================================================

# ----------------- 基础环境与全局变量 -----------------
if [[ $EUID -ne 0 ]]; then
    clear
    echo -e "\033[31m[错误] 此脚本必须以 root 身份运行!\033[0m" 1>&2
    exit 1
fi

SERVER_IP=""
URL_IP=""
PORT_NUMBER=443
SERVER_SNI="www.amazon.com"

LOG_FILE="/var/log/xray_g7g9_install.log"
CONFIG_DIR="/usr/local/etc/xray"
CONFIG="$CONFIG_DIR/config.json"
SCRIPT_DIR="/usr/local/etc/xray-script"
UPDATE_DAT_SCRIPT="$SCRIPT_DIR/update-dat.sh"
DAT_DIR="/usr/local/share/xray"
XRAY_BIN="/usr/local/bin/xray"
SYMLINK="/usr/local/bin/xrv"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
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

# ----------------- 系统检测 -----------------
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
    [[ "$OS_ID" == "unknown" ]] && print_yellow "无法准确识别系统发行版，将尝试继续..."
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
    log_only "检测到包管理器: $PKG_MANAGER"
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

    local pkgs="curl wget gawk jq ca-certificates gnupg unzip vnstat xxd cron"
    [[ "$PKG_MANAGER" == "apt" ]] && pkgs="$pkgs lsb-release cron"
    [[ "$PKG_MANAGER" == "yum" || "$PKG_MANAGER" == "dnf" ]] && pkgs="$pkgs cronie"

    retry_count=0
    while [[ $retry_count -lt 3 ]]; do
        eval "$PKG_INSTALL $pkgs" >/dev/null 2>&1 && break
        retry_count=$((retry_count + 1))
        log_warn "依赖安装受阻，重试 $retry_count/3..."; sleep 3
    done
    
    for tool in curl jq xxd vnstat; do
        command_exists "$tool" || exit_with_error "关键依赖 $tool 安装失败，请检查软件源！"
    done
}

# ----------------- 数据防护与高强度生成器 -----------------
get_server_ip_silent() {
    [[ -n "$SERVER_IP" ]] && return 0
    log_info "尝试静默获取服务器公网 IP..."
    local ip_sources=("https://api4.ipify.org" "https://ipv4.icanhazip.com" "http://www.cloudflare.com/cdn-cgi/trace")
    
    for source in "${ip_sources[@]}"; do
        if [[ "$source" == *"cloudflare"* ]]; then
            SERVER_IP=$(curl -s -4 --connect-timeout 5 "$source" 2>/dev/null | grep "ip=" | awk -F "=" '{print $2}' | tr -d '\r\n')
        else
            SERVER_IP=$(curl -s -4 --connect-timeout 5 "$source" 2>/dev/null | tr -d '\r\n')
        fi
        [[ "$SERVER_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] && break
    done
    
    # IPv6 回退尝试
    if [[ -z "$SERVER_IP" ]]; then
        SERVER_IP=$(curl -s -6 --connect-timeout 5 "http://www.cloudflare.com/cdn-cgi/trace" 2>/dev/null | grep "ip=" | awk -F "=" '{print $2}' | tr -d '\r\n')
        [[ -z "$SERVER_IP" || "$SERVER_IP" != *":"* ]] && exit_with_error "无法获取服务器 IP，请检查网络出口"
    fi
    
    # 修复 Bug 1：自动处理 IPv6 的 URL 包装
    if [[ "$SERVER_IP" == *":"* ]]; then
        URL_IP="[$SERVER_IP]"
    else
        URL_IP="$SERVER_IP"
    fi
}

_fix_permissions() {
    chmod 600 "$CONFIG" 2>/dev/null
    chown nobody:nogroup "$CONFIG" 2>/dev/null || chown nobody:nobody "$CONFIG" 2>/dev/null
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

gen_uuid() { cat /proc/sys/kernel/random/uuid; }
gen_short_id() { head -c 8 /dev/urandom | xxd -p | tr -d '\n'; }
gen_ss_pass() { head -c 24 /dev/urandom | base64 | tr -d '=/+\n' | head -c 24; }
gen_x25519() {
    local raw; raw=$("$XRAY_BIN" x25519 2>/dev/null)
    [[ -z "$raw" ]] && exit_with_error "核心引擎生成 X25519 密钥对失败"
    
    X25519_PRIV=$(echo "$raw" | grep -iE "(private|privatekey)" | awk -F ':' '{print $2}' | tr -d ' \r\n\t')
    X25519_PUB=$(echo "$raw" | grep -iE "password" | awk -F ':' '{print $2}' | tr -d ' \r\n\t')
    [[ -z "$X25519_PUB" ]] && X25519_PUB=$(echo "$raw" | grep -iE "(public|publickey)" | awk -F ':' '{print $2}' | tr -d ' \r\n\t')
    
    if [[ -z "$X25519_PRIV" || -z "$X25519_PUB" || ${#X25519_PRIV} -lt 40 ]]; then
        exit_with_error "密钥对解析异常"
    fi
}

validate_port() { [[ -n "$1" && "$1" =~ ^[0-9]+$ && "$1" -ge 1 && "$1" -le 65535 ]]; }
validate_domain() { [[ -n "$1" && "$1" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; }
validate_integer() { [[ -n "$1" && "$1" =~ ^[0-9]+$ ]]; } # 修复 Bug 2: 纯数字校验

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
    # 修复 Bug 3: 排除 "no crontab for root" 脏数据
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
    
    # 修复 Bug 4: 防止 curl | bash 时的无效软链
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
    fi
    
    install_xray_core
    _init_base_config
    setup_cron_dat
    get_server_ip_silent
    
    echo -e "  [拓扑模式选择]\n  1) VLESS-Reality + XTLS Vision (主推大杀器)\n  2) Shadowsocks (经典备用)\n  3) 两者均安装"
    read -rp "  请选择 [1]: " choice
    choice=${choice:-1}
    
    if [[ "$choice" == "1" || "$choice" == "3" ]]; then
        echo ""
        read -r -t 15 -p "VLESS 监听端口(1-65535) [回车默认 443]: " p
        if ! validate_port "$p"; then p=443; fi
        
        read -r -t 30 -p "目标伪装域名(Dest) [回车默认 www.amazon.com]: " d
        if ! validate_domain "$d"; then d="www.amazon.com"; fi
        
        read -rp "SNI(留空同域名): " s
        s=${s:-$d}
        
        gen_x25519
        local uuid=$(gen_uuid); local sid=$(gen_short_id)
        
        _safe_jq_write ".inbounds += [{
          \"tag\": \"vless-reality\", \"listen\": \"0.0.0.0\", \"port\": $p, \"protocol\": \"vless\",
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
              \"privateKey\": \"$X25519_PRIV\", \"publicKey\": \"$X25519_PUB\", \"shortIds\": [\"$sid\"]
            }
          },
          \"sniffing\": {\"enabled\":true,\"destOverride\":[\"http\",\"tls\",\"quic\"]}
        }]"
        log_info "VLESS-Reality (Vision) 配置生成完毕"
    fi
    
    if [[ "$choice" == "2" || "$choice" == "3" ]]; then
        echo ""
        read -r -t 15 -p "SS 监听端口(1-65535) [回车默认 8388]: " sp
        if ! validate_port "$sp"; then sp=8388; fi
        # 防冲突检查：如果同选了3且端口冲突
        if [[ "$choice" == "3" && "$sp" == "$p" ]]; then
            log_warn "检测到 SS 端口与 VLESS 冲突，SS 自动顺延至 8388"
            sp=8388
        fi
        
        local pass=$(gen_ss_pass)
        _safe_jq_write ".inbounds += [{
            \"tag\": \"shadowsocks\", \"listen\": \"0.0.0.0\", \"port\": $sp, \"protocol\": \"shadowsocks\",
            \"settings\": { \"method\": \"aes-256-gcm\", \"password\": \"$pass\", \"network\": \"tcp,udp\" }
        }]"
        log_info "Shadowsocks 备用配置生成完毕"
    fi

    if [[ "$SERVICE_MANAGER" == "systemctl" ]]; then
        systemctl enable xray &>/dev/null
        systemctl restart xray
    else
        service xray restart
    fi
    
    print_green "\n底层网络拓扑构建完毕！"
    do_summary
    read -rp "按 Enter 返回总控台..." _
}

# ----------------- 核心热升级管理 -----------------
do_upgrade_core() {
    title "更新 / 降级 Xray 核心引擎"
    local cur_ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 | awk '{print $2}')
    echo -e "  当前已装版本: \033[32m${cur_ver:-未知}\033[0m"
    log_info "正在从 GitHub 获取最新 Release 列表..."
    
    local versions; versions=$(curl -fsSL -m 10 https://api.github.com/repos/XTLS/Xray-core/releases | grep '"tag_name"' | cut -d'"' -f4 | head -n 10)
    [[ -z "$versions" ]] && { log_err "获取列表失败，可能触发了 GitHub API 限制"; read -rp "按 Enter 返回..."; return; }
    
    local i=1; local ver_arr=()
    while IFS= read -r v; do 
        echo -e "  $i) \033[36m$v\033[0m"
        ver_arr+=("$v")
        ((i++))
    done <<< "$versions"
    echo "  0) 取消返回"
    hr
    read -rp "  请选择目标版本编号 [0]: " sel
    [[ "$sel" == "0" || -z "$sel" ]] && return
    
    local VERSION="${ver_arr[$((sel-1))]}"
    [[ -z "$VERSION" ]] && { print_red "输入无效"; return; }
    
    log_info "正在为您热替换核心至 $VERSION ..."
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -v "$VERSION" >/dev/null 2>&1
    _fix_permissions
    
    if [[ "$SERVICE_MANAGER" == "systemctl" ]]; then systemctl restart xray; else service xray restart; fi
    print_green "Xray 核心已成功切换至 $VERSION"
    read -rp "按 Enter 返回..." _
}

# ----------------- 用户配额管理中心 -----------------
do_user_manager() {
    while true; do
        title "多用户权限与 UUID 管理"
        local vidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null)
        if [[ "$vidx" == "null" || -z "$vidx" ]]; then
            print_yellow "未发现 VLESS-Reality 配置，此功能不可用。"
            read -rp "按 Enter 返回..."; return
        fi

        echo -e "当前已挂载 UUID 列表:"
        jq -r ".inbounds[$vidx].settings.clients[] | \"  - \(.id)\"" "$CONFIG"
        hr
        echo "  1) 新增一个随机 UUID 用户"
        echo "  2) 删除指定 UUID 用户"
        echo "  0) 返回上级菜单"
        read -rp "  请选择操作: " uopt
        
        case "$uopt" in
            1) 
               local new_uuid=$(gen_uuid)
               _safe_jq_write ".inbounds[$vidx].settings.clients += [{
                 \"id\": \"$new_uuid\", \"flow\": \"xtls-rprx-vision\",
                 \"padding\": { \"triggerThreshold\": 900, \"maxLengthLong\": 500, \"extraLengthLong\": 900, \"maxLengthShort\": 256 }
               }]"
               if [[ "$SERVICE_MANAGER" == "systemctl" ]]; then systemctl restart xray; else service xray restart; fi
               print_green "新用户已下发生效: $new_uuid"
               ;;
            2)
               read -rp "  粘贴需要吊销的 UUID: " duid
               [[ -z "$duid" ]] && continue
               _safe_jq_write "del(.inbounds[$vidx].settings.clients[] | select(.id == \"$duid\"))"
               if [[ "$SERVICE_MANAGER" == "systemctl" ]]; then systemctl restart xray; else service xray restart; fi
               print_green "操作完成。若该 UUID 存在，现已被彻底吊销。"
               ;;
            0) break ;;
            *) print_red "无效选项" ;;
        esac
    done
}

# ----------------- Vision Seed 深度定制 -----------------
do_vision_seed_config() {
    title "XTLS Vision Seed (Padding) 参数微调"
    local vidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null)
    [[ "$vidx" == "null" || -z "$vidx" ]] && { print_red "未找到 VLESS 配置"; read -rp "按 Enter 返回..."; return; }

    display_cyan "调整 Xray (25.12.8+) 的 XTLS Vision 数据包随机填充策略。"
    display_cyan "修改后将自动同步至当前节点下的所有 UUID 用户！(回车保持现状)"
    echo ""
    
    local c_pad=$(jq ".inbounds[$vidx].settings.clients[0].padding" "$CONFIG")
    local cur_trig=$(echo "$c_pad" | jq -r ".triggerThreshold // 900")
    local cur_ml=$(echo "$c_pad"   | jq -r ".maxLengthLong // 500")
    local cur_el=$(echo "$c_pad"   | jq -r ".extraLengthLong // 900")
    local cur_ms=$(echo "$c_pad"   | jq -r ".maxLengthShort // 256")

    read -rp " 1. 长填充触发阈值 (默认 900) [$cur_trig]: " val_trig
    read -rp " 2. 长填充最大字节 (默认 500) [$cur_ml]: " val_ml
    read -rp " 3. 长填充额外字节 (默认 900) [$cur_el]: " val_el
    read -rp " 4. 正常最大字节数 (默认 256) [$cur_ms]: " val_ms

    # 修复 Bug 2: 严格类型校验，输入非法字母直接回退
    if ! validate_integer "$val_trig"; then val_trig=$cur_trig; fi
    if ! validate_integer "$val_ml"; then val_ml=$cur_ml; fi
    if ! validate_integer "$val_el"; then val_el=$cur_el; fi
    if ! validate_integer "$val_ms"; then val_ms=$cur_ms; fi

    _safe_jq_write "
      .inbounds[$vidx].settings.clients |= map(
        .padding = {
          \"triggerThreshold\": $val_trig,
          \"maxLengthLong\": $val_ml,
          \"extraLengthLong\": $val_el,
          \"maxLengthShort\": $val_ms
        }
      )
    "
    if [[ "$SERVICE_MANAGER" == "systemctl" ]]; then systemctl restart xray; else service xray restart; fi
    print_green "全局 Vision Seed 参数已同步注入并重启服务！"
    read -rp "按 Enter 返回..." _
}

# ----------------- 分发链接与节点展示 -----------------
do_summary() {
    title "终端节点分发中心"
    [[ ! -f "$CONFIG" ]] && { print_red "未找到配置文件，请先执行安装"; return; }
    get_server_ip_silent
    
    local vidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null)
    if [[ "$vidx" != "null" && -n "$vidx" ]]; then
        local port=$(jq -r ".inbounds[$vidx].port" "$CONFIG")
        local pub=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.publicKey" "$CONFIG")
        local sni=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.serverNames[0]" "$CONFIG")
        local sid=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.shortIds[0]" "$CONFIG")
        
        echo -e "为该节点选择 \033[33muTLS 指纹防反制策略\033[0m:"
        echo " 1) chrome (默认)  2) firefox  3) safari  4) ios  5) edge"
        read -rp "选项 [1]: " fp_sel
        case "${fp_sel:-1}" in
            2) utls_fp="firefox" ;; 3) utls_fp="safari" ;; 4) utls_fp="ios" ;; 5) utls_fp="edge" ;; *) utls_fp="chrome" ;;
        esac

        hr
        display_cyan "【VLESS-Reality 专属节点】"
        echo -e " 协议框架\t: \033[32mVLESS + Reality + XTLS Vision\033[0m"
        echo -e " 外网IP\t\t: \033[33m$SERVER_IP\033[0m"
        echo -e " 端口\t\t: \033[33m$port\033[0m"
        echo -e " 伪装SNI\t: \033[33m$sni\033[0m"
        echo -e " 公钥(pbk)\t: \033[33m$pub\033[0m"
        echo -e " ShortId\t: \033[33m$sid\033[0m"
        echo -e " uTLS引擎\t: \033[33m$utls_fp\033[0m"
        hr
        print_green "多用户独立导入链接 (已植入 xp 安全后缀):"
        
        jq -r ".inbounds[$vidx].settings.clients[].id" "$CONFIG" | while read -r uuid; do
            echo -e "\n\033[33m用户 UUID:\033[0m $uuid"
            echo "vless://$uuid@${URL_IP}:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$sni&fp=$utls_fp&pbk=$pub&sid=$sid&type=tcp&headerType=none#xp-reality"
        done
        echo ""
    fi
    
    local sidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="shadowsocks")] | .[0].key' "$CONFIG" 2>/dev/null)
    if [[ "$sidx" != "null" && -n "$sidx" ]]; then
        local sport=$(jq -r ".inbounds[$sidx].port" "$CONFIG")
        local spass=$(jq -r ".inbounds[$sidx].settings.password" "$CONFIG")
        local smethod=$(jq -r ".inbounds[$sidx].settings.method" "$CONFIG")
        local b64=$(printf '%s' "${smethod}:${spass}" | base64 | tr -d '\n')
        
        display_cyan "【Shadowsocks 备用节点】"
        echo -e " 端口: $sport | 密码: $spass | 加密: $smethod"
        print_green " ss://${b64}@${URL_IP}:${sport}#xp-ss"
        echo ""
    fi
}

# ----------------- 服务器大盘监控 -----------------
do_status() {
    title "服务器资源与网络探针"
    display_cyan "[核心服务运行状态]"
    if [[ "$SERVICE_MANAGER" == "systemctl" ]]; then
        systemctl status xray --no-pager | head -n 8
    else
        service xray status | head -n 8
    fi
    hr
    if command_exists vnstat; then
        display_cyan "[物理网卡流量审计]"
        local iface=$(ip route show default | awk '/default/{print $5}' | head -1)
        vnstat -i "$iface"
    fi
    read -rp "按 Enter 返回主控台..." _
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
        echo -e "     \033[96mXray G7G9 版 (任意位置输入 xrv 唤醒)\033[0m"
        echo -e "\033[94m===================================================\033[0m"
        
        local svc="inactive"
        if [[ "$SERVICE_MANAGER" == "systemctl" ]]; then
            systemctl is-active --quiet xray 2>/dev/null && svc="active"
        else
            service xray status 2>/dev/null | grep -q "running" && svc="active"
        fi
        
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
               if [[ "$SERVICE_MANAGER" == "systemctl" ]]; then systemctl restart xray; else service xray restart; fi
               print_green "Geo 库已云端同步完成"; read -rp "按 Enter 返回..." _ ;;
            8) 
               if [[ "$SERVICE_MANAGER" == "systemctl" ]]; then 
                   systemctl stop xray; systemctl disable xray
                   rm -f /etc/systemd/system/xray.service; systemctl daemon-reload
               else 
                   service xray stop
               fi
               # 修复 Bug 3: 清除 Crontab
               crontab -l 2>/dev/null | grep -v "no crontab" | grep -v "$UPDATE_DAT_SCRIPT" | crontab -
               rm -rf "$CONFIG_DIR" "$LOG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SYMLINK" "$SCRIPT_DIR"
               print_green "服务已剥离，数据已粉碎。"; exit 0 ;;
            0) exit 0 ;;
            *) print_red "指令无法识别" ;;
        esac
    done
}

# 拦截异常中断
trap 'print_red "\n脚本被中断"; exit 1' INT TERM

# -> 启动
main_menu
