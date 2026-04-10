请你完整检阅聊天记录和所有代码之后进行融合、修改、优化、增量，最后再输出一份新的融合修复优化增量脚本代码（叫g7g3.sh）：
#1.xray reality 性能优化，Xray 服务端和客户端配置文件中 开启并使用xtls-rprx-vision；
#2.使用 uTLS 进行伪装；
#3.Vision Seed（Xray-core在25.12.8更新中，推出了“Vision Seed”功能。基本上，它使得“XTLS Vision”中 填充策略的具体数值可自定义，以及加入“预连接”功能以改善使用体验，此次更新允许用户更改“XTLS Vision”进行填充时的4个参数，此次允许用户配置的参数如下：长填充的触发阈值，默认值：900。
长填充的最大填充字节数，默认值：500。
长填充的额外填充字节数，默认值：900。
正常的最大填充字节数，默认值：256。“实际填充字节数最大值”可如此计算：
当“实际数据长度”大于“长填充的触发阈值”，且能够进行“长填充”：
实际填充字节数最大值 = 长填充的最大填充字节数 + 长填充的额外填充字节数。
否则：实际填充字节数最大值 = 正常的最大填充字节数。
值得注意，“最大填充字节数”意味着“实际填充字节数将是随机生成的”，目前并不类似“VLESS加密”配置，允许用户设置“最小填充字节数”呀。），脚本中加入“XTLS Vision”进行填充时的4个参数修改功能；

#4.关于第3点的Vision Seed相关的学习链接在此(https://idcflare.com/t/topic/43912)。
#5.怎么你的代码越写越少了！

#!/bin/bash
# script: g7g2.sh (Optimized & Hardened Edition)
#不要出现1024的字眼！！！我改成xp了！

# 确保以root用户运行
if [[ $EUID -ne 0 ]]; then
    clear
    echo -e "\033[31m错误: 此脚本必须以 root 身份运行!\033[0m" 1>&2
    exit 1
fi

# ==================== 全局变量定义 ====================
SERVER_IP=""
PORT_NUMBER=443
SERVER_SNI="www.amazon.com"
UUID=""
RE_PRIVATE_KEY=""
RE_PUBLIC_KEY=""

LOG_FILE="/var/log/reality_install.log"
BACKUP_DIR="/tmp/reality_backup_$(date +%s)"

# 初始化日志文件
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
touch "$LOG_FILE" 2>/dev/null || LOG_FILE=""

# ==================== 日志与输出模块 ====================
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}\033[0m"
    [[ -n "$LOG_FILE" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$LOG_FILE"
}

print_red()    { print_msg "\033[31m" "$1"; }
print_green()  { print_msg "\033[32m" "$1"; }
print_yellow() { print_msg "\033[33m" "$1"; }

display_green() { echo -e "\033[32m$1\033[0m"; }

log_only() {
    [[ -n "$LOG_FILE" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    log_only "$1"
}

# ==================== 错误处理模块 ====================
cleanup_on_error() {
    log_info "执行错误清理..."
    if command_exists systemctl; then
        systemctl stop xray.service 2>/dev/null || true
    elif command_exists service; then
        service xray stop 2>/dev/null || true
    fi
    rm -f /tmp/xray-install.sh
    log_info "错误清理完成"
}

exit_with_error() {
    print_red "错误: $1"
    cleanup_on_error
    exit 1
}

trap 'exit_with_error "脚本被用户强制中断"' INT TERM

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ==================== 验证与检测模块 ====================
validate_port() {
    [[ "$1" =~ ^[0-9]+$ ]] && [[ "$1" -ge 1 ]] && [[ "$1" -le 65535 ]]
}

validate_domain() {
    [[ "$1" =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]
}

check_network() {
    log_info "正在预检网络连通性..."
    if ! curl -s -I -m 5 https://github.com >/dev/null; then
        print_yellow "警告: 无法顺畅连接至 GitHub，后续 Xray 下载可能会较慢或失败。"
    fi
}

detect_system() {
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
    log_info "检测到系统: $OS_ID $OS_VERSION"
}

init_package_manager() {
    if command_exists apt-get; then
        PKG_MANAGER="apt"
        PKG_UPDATE="apt-get update -y"
        PKG_INSTALL="apt-get install -y"
        # 释放可能存在的 apt 锁
        while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
            log_info "等待 dpkg 锁释放..."; sleep 3
        done
    elif command_exists yum; then
        PKG_MANAGER="yum"; PKG_UPDATE="yum makecache"; PKG_INSTALL="yum install -y"
        yum install -y epel-release 2>/dev/null || true
    elif command_exists dnf; then
        PKG_MANAGER="dnf"; PKG_UPDATE="dnf makecache"; PKG_INSTALL="dnf install -y"
        dnf install -y epel-release 2>/dev/null || true
    else
        exit_with_error "不支持的包管理器 (仅支持 apt/yum/dnf)"
    fi
    log_info "使用包管理器: $PKG_MANAGER"
}

# ==================== 核心安装流程 ====================
install_dependencies() {
    log_info "正在更新软件包并安装核心依赖..."
    eval "$PKG_UPDATE" >/dev/null 2>&1 || print_yellow "软件包列表更新存在错误，尝试强行安装..."
    
    local pkgs="curl wget gawk ca-certificates gnupg unzip"
    [[ "$PKG_MANAGER" == "apt" ]] && pkgs="$pkgs lsb-release"
    
    for i in {1..3}; do
        if eval "$PKG_INSTALL $pkgs" >/dev/null 2>&1; then break; fi
        [[ $i -eq 3 ]] && exit_with_error "基础依赖包安装失败，请检查系统源配置。"
        log_info "依赖安装受阻，第 $i 次重试中..."
        sleep 3
    done
    
    for tool in curl wget awk; do
        command_exists "$tool" || exit_with_error "关键组件 $tool 缺失，脚本无法继续执行。"
    done
    print_green "基础环境依赖部署完毕"
}

get_server_ip() {
    log_only "开始解析公网IP..."
    local ip_apis=("https://ipv4.icanhazip.com/" "http://www.cloudflare.com/cdn-cgi/trace" "https://api.ipify.org")
    
    for api in "${ip_apis[@]}"; do
        if [[ "$api" == *"cloudflare"* ]]; then
            SERVER_IP=$(curl -s -4 -m 5 "$api" | grep "ip=" | awk -F "=" '{print $2}' | tr -d '\r\n')
        else
            SERVER_IP=$(curl -s -4 -m 5 "$api" | tr -d '\r\n')
        fi
        [[ "$SERVER_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] && return 0
    done
    
    # 尝试 IPv6 备用
    SERVER_IP=$(curl -s -6 -m 5 "http://www.cloudflare.com/cdn-cgi/trace" | grep "ip=" | awk -F "=" '{print $2}' | tr -d '\r\n')
    [[ -n "$SERVER_IP" && "$SERVER_IP" == *":"* ]] && return 0
    
    exit_with_error "无法获取到本机的公网 IP 地址，请检查服务器网络。"
}

install_xray_core() {
    log_info "正在从 GitHub 获取 Xray-core..."
    mkdir -p "$BACKUP_DIR"
    [[ -f "/usr/local/etc/xray/config.json" ]] && cp "/usr/local/etc/xray/config.json" "$BACKUP_DIR/config.json.bak"
    
    local script_url="https://github.com/XTLS/Xray-install/raw/main/install-release.sh"
    local local_script="/tmp/xray-install.sh"
    
    for i in {1..3}; do
        if curl -L -s -m 15 "$script_url" -o "$local_script" && grep -q "#!/" "$local_script"; then
            chmod +x "$local_script"
            break
        fi
        [[ $i -eq 3 ]] && exit_with_error "官方安装脚本下载失败。"
        sleep 3
    done
    
    if ! timeout 300 bash "$local_script" install >/dev/null 2>&1; then
        exit_with_error "Xray 内核安装进程失败或超时。"
    fi
    
    if ! /usr/local/bin/xray version >/dev/null 2>&1; then
        exit_with_error "Xray 内核校验失败，可能架构不匹配。"
    fi
    
    rm -f "$local_script"
    print_green "Xray-core 安装成功"
}

generate_crypto_keys() {
    log_info "正在生成 X25519 Reality 密钥对..."
    local raw_keys
    raw_keys=$(/usr/local/bin/xray x25519 2>/dev/null)
    [[ -z "$raw_keys" ]] && exit_with_error "核心引擎生成密钥对失败。"
    
    RE_PRIVATE_KEY=$(echo "$raw_keys" | grep -i "Private key" | awk -F ':' '{print $2}' | tr -d ' \r\n')
    RE_PUBLIC_KEY=$(echo "$raw_keys" | grep -i "Public key" | awk -F ':' '{print $2}' | tr -d ' \r\n')
    
    if [[ -z "$RE_PRIVATE_KEY" || ${#RE_PRIVATE_KEY} -lt 40 ]]; then
        exit_with_error "密钥对解析异常，请尝试重新运行脚本。"
    fi
}

deploy_configuration() {
    log_info "正在下发配置文件..."
    mkdir -p /usr/local/etc/xray
    
    cat > /tmp/xray_config_$$.json <<EOF
{
    "log": { "loglevel": "warning" },
    "inbounds": [
        {
            "port": $PORT_NUMBER,
            "protocol": "vless",
            "settings": {
                "clients": [ { "id": "$UUID", "flow": "xtls-rprx-vision" } ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "show": false,
                    "dest": "$SERVER_SNI:443",
                    "xver": 0,
                    "serverNames": [ "$SERVER_SNI" ],
                    "privateKey": "$RE_PRIVATE_KEY",
                    "shortIds": [ "88" ]
                }
            }
        }
    ],
    "outbounds": [
        { "protocol": "freedom", "tag": "direct" },
        { "protocol": "blackhole", "tag": "blocked" }
    ]    
}
EOF
    
    mv /tmp/xray_config_$$.json /usr/local/etc/xray/config.json
    # 安全加固：私钥文件仅允许 root 读写
    chmod 600 /usr/local/etc/xray/config.json
    
    if ! /usr/local/bin/xray run -test -config /usr/local/etc/xray/config.json >/dev/null 2>&1; then
        exit_with_error "Xray 配置文件格式存在致命错误。"
    fi
    
    log_info "正在拉起 Xray 守护进程..."
    if command_exists systemctl; then
        systemctl enable xray.service >/dev/null 2>&1
        systemctl restart xray.service
        sleep 2
        systemctl is-active --quiet xray.service || exit_with_error "服务启动失败，请检查 systemctl status xray"
    else
        service xray restart || exit_with_error "服务启动失败 (SysVinit)"
    fi
    print_green "Xray 服务已成功运行"
    
    # 写入客户端配置记录
    cat > /usr/local/etc/xray/reclient.json <<EOF
{
    "UUID": "$UUID",
    "端口": $PORT_NUMBER,
    "SNI": "$SERVER_SNI",
    "公钥": "$RE_PUBLIC_KEY"
}
EOF
    chmod 644 /usr/local/etc/xray/reclient.json
}

# ==================== 交互与展现模块 ====================
interactive_setup() {
    UUID=$(python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null)
    [[ -z "$UUID" ]] && exit_with_error "系统缺乏 UUID 生成能力"
    
    echo
    # 获取端口 (带超时和输入校验)
    if read -r -t 15 -p "回车或等待15秒使用默认端口 443，自定义请输入(1-65535)：" input_port; then
        if [[ -z "$input_port" ]]; then 
            PORT_NUMBER=443
        elif validate_port "$input_port"; then 
            PORT_NUMBER="$input_port"
        else 
            print_yellow "\n输入非法，强制回退至默认端口 443"
            PORT_NUMBER=443
        fi
    else
        echo -e "\n超时未操作，使用默认端口 443"
        PORT_NUMBER=443
    fi
    
    echo
    # 获取 SNI
    if read -r -t 30 -p "回车或等待30秒使用默认域名 www.amazon.com，自定义请输入：" input_sni; then
        if [[ -z "$input_sni" ]]; then
            SERVER_SNI="www.amazon.com"
        elif validate_domain "$input_sni"; then
            SERVER_SNI="$input_sni"
        else
            print_yellow "\n域名格式非法，强制回退至 www.amazon.com"
            SERVER_SNI="www.amazon.com"
        fi
    else
        echo -e "\n超时未操作，使用默认域名 www.amazon.com"
        SERVER_SNI="www.amazon.com"
    fi
    echo
}

display_results() {
    clear
    display_green "=========================================="
    display_green "       Reality 极速安装与配置完成         "
    display_green "=========================================="
    echo -e " 服务节点IP\t: \033[33m$SERVER_IP\033[0m"
    echo -e " 监听端口\t: \033[33m$PORT_NUMBER\033[0m"
    echo -e " 目标网站(SNI)\t: \033[33m$SERVER_SNI\033[0m"
    echo -e " UUID 密钥\t: \033[33m$UUID\033[0m"
    echo -e " 公钥(PubKey)\t: \033[33m$RE_PUBLIC_KEY\033[0m"
    echo -e " ShortId\t: 88"#ShortId要随机啊！你怎么写死了，千万不能写死！！！！！！
    echo -e " 流控协议\t: xtls-rprx-vision"
    display_green "=========================================="
    echo
    display_green "一键导入链接 (VLESS URL)："
    echo "vless://$UUID@$SERVER_IP:$PORT_NUMBER?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SERVER_SNI&fp=chrome&pbk=$RE_PUBLIC_KEY&sid=8#ShortId要随机啊！你怎么写死了，千万不能写死！！！！！！8&type=tcp&headerType=none#xp-reality"
    echo
}

# ==================== 主控启动流程 ====================
main() {
    clear
    print_green ">>> 启动 Reality 高阶部署脚本 (g7g2) <<<"
    
    detect_system
    init_package_manager
    check_network
    
    install_dependencies
    get_server_ip
    
    interactive_setup
    
    install_xray_core
    generate_crypto_keys
    deploy_configuration
    
    display_results
    log_only "g7g2.sh 部署任务已圆满结束。"
}

main "$@"

# 1. 确保 Xray 配置目录及其文件对所有用户可读
chmod -R 755 /usr/local/etc/xray

# 2. 如果你的系统使用的是官方安装脚本，尝试将所有权交给 nobody 用户
chown -R nobody:nogroup /usr/local/etc/xray 2>/dev/null || chown -R nobody:nobody /usr/local/etc/xray

# 3. 重启服务
systemctl restart xray




#!/usr/bin/env bash

# ============================================================
# xrayv6.sh – Xray 全功能管理脚本 v6 (修复版)
# 快捷方式: xrv
# 协议: VLESS-Reality + Shadowsocks
# ============================================================

# 必须用 bash 运行
if [ -z "$BASH_VERSION" ]; then
    echo "错误: 请用 bash 运行此脚本: bash xrayv6.sh"
    exit 1
fi

# – 颜色 –––––––––––––––––––––––––
red='\e[31m'; yellow='\e[33m'; gray='\e[90m'; green='\e[92m'
blue='\e[94m'; magenta='\e[95m'; cyan='\e[96m'; none='\e[0m'
_red()     { echo -e "${red}$*${none}";     }
_blue()    { echo -e "${blue}$*${none}";    }
_cyan()    { echo -e "${cyan}$*${none}";    }
_green()   { echo -e "${green}$*${none}";   }
_yellow()  { echo -e "${yellow}$*${none}";  }
_magenta() { echo -e "${magenta}$*${none}"; }
_red_bg()  { echo -e "\e[41m$*${none}";    }

is_err=$(_red_bg  "错误!")
is_warn=$(_red_bg "警告!")

# 日志函数
info()  { echo -e "${green}[✓]${none} $*"; }
warn()  { echo -e "${yellow}[!]${none} $*"; }
error() { echo -e "${red}[✗]${none} $*";   }
die()   { echo -e "\n${is_err} $*\n"; exit 1; }
title() {
    echo -e "\n${blue}===================================================${none}"
    echo -e "  ${cyan}$*${none}"
    echo -e "${blue}===================================================${none}"
}
hr() { echo -e "${gray}--------------------------${none}"; }

msg() {
    case $1 in
        warn) local c=$yellow ;;
        err)  local c=$red    ;;
        ok)   local c=$green  ;;
        *)    local c=$none   ;;
    esac
    local _t; _t=$(date +%T)
    echo -e "${c}${_t}${none}) ${2}"
}

# – 全局路径 –––––––––––––––––––––––
XRAY_BIN="/usr/local/bin/xray"
CONFIG="/usr/local/etc/xray/config.json"
CONFIG_DIR="/usr/local/etc/xray"
SCRIPT_DIR="/usr/local/etc/xray-script"
UPDATE_DAT_SCRIPT="$SCRIPT_DIR/update-dat.sh"
DAT_DIR="/usr/local/share/xray"
LOG_DIR="/var/log/xray"
SCRIPT_PATH=$(realpath "$0")
SYMLINK="/usr/local/bin/xrv"

GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat"

# – 架构检测 –––––––––––––––––––––––
detect_arch() {
    case $(uname -m) in
        amd64|x86_64)      CORE_ARCH="64";        JQ_ARCH="amd64" ;;
        *aarch64*|*armv8*) CORE_ARCH="arm64-v8a"; JQ_ARCH="arm64" ;;
        *) die "仅支持 64 位系统 (x86_64 / aarch64)" ;;
    esac
}

# – 包管理器检测 ——————————————
detect_pkg_manager() {
    PKG_CMD=$(type -P apt-get || type -P yum || true)
    [[ -z "$PKG_CMD" ]] && die "仅支持 apt-get / yum 系统"
}

# – 安装缺失依赖 ——————————————
install_pkg() {
    local need=""
    for i in "$@"; do
        command -v "$i" &>/dev/null || need="$need $i"
    done
    if [[ -n "$need" ]]; then
        msg warn "安装依赖:$need"
        $PKG_CMD install -y $need &>/dev/null || {
            [[ "$PKG_CMD" =~ yum ]] && yum install epel-release -y &>/dev/null
            $PKG_CMD update -y &>/dev/null
            $PKG_CMD install -y $need &>/dev/null || true
        }
    fi
}

# – wget 封装 ———————————————
_wget() {
    [[ -n "${proxy:-}" ]] && export https_proxy=$proxy
    wget --no-check-certificate "$@"
}

# – 获取公网 IP —————————————––
get_server_ip() {
    SERVER_IP=""
    local trace
    trace=$(_wget -4 -qO- "https://one.one.one.one/cdn-cgi/trace" 2>/dev/null | grep "^ip=" || true)
    [[ -n "$trace" ]] && SERVER_IP="${trace#ip=}"
    [[ -z "$SERVER_IP" ]] && SERVER_IP=$(curl -fsSL --max-time 6 "https://api4.ipify.org" 2>/dev/null || true)
    [[ -z "$SERVER_IP" ]] && SERVER_IP=$(curl -fsSL --max-time 6 "https://ifconfig.me" 2>/dev/null || true)
    [[ -z "$SERVER_IP" ]] && SERVER_IP="YOUR_SERVER_IP"
}

# – 初始化检查 ––––––––––––––––––––––
preflight() {
    [[ $EUID -ne 0 ]] && die "当前非 ROOT 用户"
    [[ ! $(type -P systemctl) ]] && die "系统缺少 systemctl"
    detect_arch
    detect_pkg_manager
    install_pkg jq curl wget xxd unzip

    if [[ ! -L "$SYMLINK" ]] || [[ "$(readlink -f "$SYMLINK")" != "$SCRIPT_PATH" ]]; then
        ln -sf "$SCRIPT_PATH" "$SYMLINK"
        chmod +x "$SCRIPT_PATH"
        info "快捷方式 ${cyan}xrv${none} 已绑定 → $SCRIPT_PATH"
    fi
}

# – 配置文件合法性检查 —————––
check_config() {
    if [[ ! -f "$CONFIG" ]]; then
        error "配置文件不存在: $CONFIG"
        warn "请先执行「1. 安装」"
        return 1
    fi
    if ! jq empty "$CONFIG" 2>/dev/null; then
        error "config.json 格式损坏"
        _try_restore_backup
        return 1
    fi
    local vless_count
    vless_count=$(jq '[.inbounds[]? | select(.protocol=="vless")] | length' "$CONFIG" 2>/dev/null || echo 0)
    if [[ "$vless_count" -gt 0 ]]; then
        local cn
        cn=$(jq -r '(.inbounds[]? | select(.protocol=="vless") | .settings.clients) // "null"' "$CONFIG" 2>/dev/null | head -1)
        if [[ "$cn" == "null" ]]; then
            warn "VLESS clients 为 null，自动修复…"
            _safe_jq_write '(.inbounds[] | select(.protocol=="vless") | .settings.clients) = []' || return 1
        fi
    fi
    return 0
}

_try_restore_backup() {
    local bak
    bak=$(ls -t "${CONFIG}.bak."* 2>/dev/null | head -n1 || true)
    if [[ -n "$bak" ]]; then
        warn "发现最近备份: $bak"
        read -rp "是否还原? [y/N]: " ans
        if [[ "$ans" == "y" ]]; then
            cp "$bak" "$CONFIG"
            systemctl restart xray 2>/dev/null || true
            info "已还原并重启 Xray"
        fi
    fi
}

# – 安全 jq 写入 ——————
_safe_jq_write() {
    local filter="$1"
    local tmp; tmp=$(mktemp /tmp/xray_cfg_XXXXXX.json)
    local bak="${CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"

    if [[ ! -f "$CONFIG" ]]; then
        error "配置文件不存在，无法写入"
        rm -f "$tmp"
        return 1
    fi

    cp "$CONFIG" "$bak"
    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null && jq empty "$tmp" 2>/dev/null; then
        mv "$tmp" "$CONFIG"
        return 0
    fi

    error "jq 写入失败，还原备份..."
    cp "$bak" "$CONFIG"
    rm -f "$tmp"
    return 1
}

# – 随机生成工具 ——————————————
gen_uuid() { cat /proc/sys/kernel/random/uuid; }
gen_short_id() {
    local len=$((RANDOM % 2 == 0 ? 8 : 16))
    head -c 32 /dev/urandom | xxd -p | tr -d '\n' | head -c "$len"
    echo
}
gen_ss_pass() {
    head -c 24 /dev/urandom | base64 | tr -d '=/+\n' | head -c 24
    echo
}

gen_x25519() {
    if [[ ! -x "$XRAY_BIN" ]]; then
        die "xray 二进制不存在，无法生成密钥对: $XRAY_BIN"
    fi
    local keys
    keys=$("$XRAY_BIN" x25519 2>/dev/null)
    
    # 改进的匹配逻辑：忽略大小写，并以冒号为分隔符取第二列
    X25519_PRIV=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' ')
    X25519_PUB=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' ')

    if [[ -z "$X25519_PRIV" || -z "$X25519_PUB" ]]; then
        # 最后的保底尝试：针对部分版本输出在括号内的情况
        X25519_PUB=$(echo "$keys" | grep -i "PublicKey" | awk -F': ' '{print $2}' | tr -d ' ')
    fi

    if [[ -z "$X25519_PRIV" || -z "$X25519_PUB" ]]; then
        die "x25519 密钥对抓取失败，请检查输出格式"
    fi
}

derive_pubkey() {
    local priv="$1"
    [[ ! -x "$XRAY_BIN" ]] && echo "" && return
    # 同样的改进逻辑
    "$XRAY_BIN" x25519 -i "$priv" 2>/dev/null | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' '
}

install_update_dat() {
    mkdir -p "$SCRIPT_DIR" "$LOG_DIR"
    cat > "$UPDATE_DAT_SCRIPT" <<'UPDSH'
#!/usr/bin/env bash
set -e
XRAY_DAT_DIR="/usr/local/share/xray"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat"
mkdir -p "$XRAY_DAT_DIR" && cd "$XRAY_DAT_DIR"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 更新 geoip.dat..."
curl -fsSL -o geoip.dat.new "$GEOIP_URL" && mv -f geoip.dat.new geoip.dat
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 更新 geosite.dat..."
curl -fsSL -o geosite.dat.new "$GEOSITE_URL" && mv -f geosite.dat.new geosite.dat
systemctl -q is-active xray && systemctl restart xray && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Xray 已重启"
UPDSH
    chmod +x "$UPDATE_DAT_SCRIPT"
    local job="0 3 * * * $UPDATE_DAT_SCRIPT >> $LOG_DIR/update-dat.log 2>&1"
    (crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT"; echo "$job") | crontab -
    info "cron 任务已配置：每天 03:00 更新 dat"
}

download_dat_now() {
    mkdir -p "$DAT_DIR"
    curl -fsSL -o "$DAT_DIR/geoip.dat" "$GEOIP_URL" && msg ok "geoip.dat 完成"
    curl -fsSL -o "$DAT_DIR/geosite.dat" "$GEOSITE_URL" && msg ok "geosite.dat 完成"
}

_gen_vless_config() {
    local port="$1" uuid="$2" priv="$3" pub="$4" sid="$5" dest="$6" sni="$7"
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG" <<EOF
{
  "log": { "loglevel": "warning" },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {"tag_id":"bt",  "type":"field","protocol":["bittorrent"],"outboundTag":"block","_enabled":true},
      {"tag_id":"cn",  "type":"field","ip":["geoip:cn"],"outboundTag":"block","_enabled":true},
      {"tag_id":"ads", "type":"field","domain":["geosite:category-ads-all"],"outboundTag":"block","_enabled":true}
    ]
  },
  "inbounds": [
    {
      "tag": "vless-reality",
      "listen": "0.0.0.0",
      "port": ${port},
      "protocol": "vless",
      "settings": {
        "clients": [{"id":"${uuid}","flow":"xtls-rprx-vision"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "${dest}:443",
          "serverNames": ["${sni}"],
          "privateKey": "${priv}",
          "publicKey": "${pub}",
          "shortIds": ["${sid}"]
        }
      },
      "sniffing": {"enabled":true,"destOverride":["http","tls","quic"]}
    }
  ],
  "outbounds": [
    {"protocol":"freedom","tag":"direct"},
    {"protocol":"blackhole","tag":"block"}
  ]
}
EOF
}

_gen_ss_config() {
    local port="$1" pass="$2" method="$3"
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG" <<EOF
{
  "log": { "loglevel": "warning" },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {"tag_id":"bt",  "type":"field","protocol":["bittorrent"],"outboundTag":"block","_enabled":true},
      {"tag_id":"cn",  "type":"field","ip":["geoip:cn"],"outboundTag":"block","_enabled":true},
      {"tag_id":"ads", "type":"field","domain":["geosite:category-ads-all"],"outboundTag":"block","_enabled":true}
    ]
  },
  "inbounds": [
    {
      "tag": "shadowsocks",
      "listen": "0.0.0.0",
      "port": ${port},
      "protocol": "shadowsocks",
      "settings": {
        "method": "${method}",
        "password": "${pass}",
        "network": "tcp,udp"
      }
    }
  ],
  "outbounds": [
    {"protocol":"freedom","tag":"direct"},
    {"protocol":"blackhole","tag":"block"}
  ]
}
EOF
}

_append_ss_inbound() {
    local port=$1 pass=$2 method=$3
    _safe_jq_write ".inbounds += [{
        \"tag\": \"shadowsocks\",
        \"listen\": \"0.0.0.0\",
        \"port\": $port,
        \"protocol\": \"shadowsocks\",
        \"settings\": {
            \"method\": \"$method\",
            \"password\": \"$pass\",
            \"network\": \"tcp,udp\"
        }
    }]"
}

print_vless_link() {
    local uuid="$1" port="$2" sni="$3" priv="$4" sid="$5" label="${6:-xray-reality}"
    local pub
    pub=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.publicKey // ""' "$CONFIG" 2>/dev/null | head -1)
    [[ -z "$pub" ]] && pub=$(derive_pubkey "$priv")
    get_server_ip
    local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp&headerType=none#${label}"
    hr
    _cyan "  VLESS-Reality 连接参数"
    hr
    printf "  ${yellow}%-16s${none} %s\n" "服务器 IP:" "$SERVER_IP"
    printf "  ${yellow}%-16s${none} %s\n" "端口:" "$port"
    printf "  ${yellow}%-16s${none} %s\n" "UUID:" "$uuid"
    printf "  ${yellow}%-16s${none} %s\n" "SNI:" "$sni"
    printf "  ${yellow}%-16s${none} %s\n" "公钥(pbk):" "$pub"
    printf "  ${yellow}%-16s${none} %s\n" "Short ID:" "$sid"
    hr
    echo -e "\n  链接: ${cyan}${link}${none}\n"
}

print_ss_link() {
    local pass="$1" method="$2" port="$3" label="${4:-xray-ss}"
    get_server_ip
    local b64; b64=$(printf '%s' "${method}:${pass}" | base64 | tr -d '\n')
    local link="ss://${b64}@${SERVER_IP}:${port}#${label}"
    hr
    _cyan "  Shadowsocks 连接参数"
    hr
    printf "  ${yellow}%-16s${none} %s\n" "端口:" "$port"
    printf "  ${yellow}%-16s${none} %s\n" "密码:" "$pass"
    printf "  ${yellow}%-16s${none} %s\n" "加密方式:" "$method"
    hr
    echo -e "\n  链接: ${cyan}${link}${none}\n"
}

input_port() {
    local p
    while true; do
        read -rp "$1 [${2:-}]: " p
        [[ -z "$p" ]] && p="$2"
        if [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 1 && p <= 65535 )); then echo "$p"; return; fi
        error "端口无效 (1-65535)"
    done
}

input_domain() {
    local d
    while true; do
        read -rp "输入目标域名 (如 www.microsoft.com): " d
        [[ -n "$d" ]] && echo "$d" && return
        error "域名不能为空"
    done
}

_select_ss_method() {
    echo "  选择 SS 加密方式：" >&2
    echo "  1) aes-256-gcm (推荐) 2) aes-128-gcm 3) chacha20-ietf-poly1305 4) 2022-blake3-aes-256-gcm" >&2
    read -rp "  编号 [1]: " mc >&2
    case "${mc:-1}" in
        2) echo "aes-128-gcm" ;;
        3) echo "chacha20-ietf-poly1305" ;;
        4) echo "2022-blake3-aes-256-gcm" ;;
        *) echo "aes-256-gcm" ;;
    esac
}

_print_all_links() {
    [[ ! -f "$CONFIG" ]] && return
    local v_count; v_count=$(jq '[.inbounds[]? | select(.protocol=="vless")] | length' "$CONFIG" 2>/dev/null || echo 0)
    if [[ "$v_count" -gt 0 ]]; then
        local v_port v_uuid v_priv v_sid v_sni
        v_port=$(jq -r '.inbounds[] | select(.protocol=="vless") | .port' "$CONFIG" | head -1)
        v_uuid=$(jq -r '.inbounds[] | select(.protocol=="vless") | .settings.clients[0].id' "$CONFIG" | head -1)
        v_priv=$(jq -r '.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.privateKey' "$CONFIG" | head -1)
        v_sid=$(jq -r '.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.shortIds[0]' "$CONFIG" | head -1)
        v_sni=$(jq -r '.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0]' "$CONFIG" | head -1)
        print_vless_link "$v_uuid" "$v_port" "$v_sni" "$v_priv" "$v_sid"
    fi
    local s_count; s_count=$(jq '[.inbounds[]? | select(.protocol=="shadowsocks")] | length' "$CONFIG" 2>/dev/null || echo 0)
    if [[ "$s_count" -gt 0 ]]; then
        local s_port s_pass s_method
        s_port=$(jq -r '.inbounds[] | select(.protocol=="shadowsocks") | .port' "$CONFIG" | head -1)
        s_pass=$(jq -r '.inbounds[] | select(.protocol=="shadowsocks") | .settings.password' "$CONFIG" | head -1)
        s_method=$(jq -r '.inbounds[] | select(.protocol=="shadowsocks") | .settings.method' "$CONFIG" | head -1)
        print_ss_link "$s_pass" "$s_method" "$s_port"
    fi
}

_get_vless_idx() { jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null; }
_get_ss_idx() { jq '[.inbounds | to_entries[] | select(.value.protocol=="shadowsocks")] | .[0].key' "$CONFIG" 2>/dev/null; }

do_install() {
    title "安装 / 重装 Xray"
    if systemctl is-active --quiet xray 2>/dev/null; then
        warn "检测到 Xray 正在运行"
        read -rp "重装将保留配置，继续? [y/N]: " c
        [[ "$c" != "y" ]] && return
    fi

    echo -e "  1) VLESS-Reality (推荐)  2) Shadowsocks  3) 两个都安装"
    read -rp "  输入编号 [1]: " proto_choice
    proto_choice=${proto_choice:-1}

    msg warn "下载并安装 Xray 核心..."
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    
    case "$proto_choice" in
        1) _init_vless_config ;;
        2) _init_ss_config ;;
        3) 
           _init_vless_config
           msg warn "继续配置 Shadowsocks..."
           local sp; sp=$(input_port "SS 监听端口" "8388")
           local spa; spa=$(gen_ss_pass)
           local sm; sm=$(_select_ss_method)
           _append_ss_inbound "$sp" "$spa" "$sm"
           ;;
    esac

    install_update_dat
    download_dat_now
    systemctl enable xray &>/dev/null
    systemctl restart xray
    msg ok "安装完成"
    _print_all_links
    read -rp "按 Enter 返回主菜单..." _
}

_init_vless_config() {
    local port uuid priv pub sid dest sni
    port=$(input_port "VLESS 监听端口" "443")
    dest=$(input_domain)
    read -rp "SNI (留空同域名 [$dest]): " sni
    [[ -z "$sni" ]] && sni="$dest"
    gen_x25519
    uuid=$(gen_uuid); sid=$(gen_short_id)
    _gen_vless_config "$port" "$uuid" "$X25519_PRIV" "$X25519_PUB" "$sid" "$dest" "$sni"
}

_init_ss_config() {
    local port pass method
    port=$(input_port "SS 监听端口" "8388")
    pass=$(gen_ss_pass)
    method=$(_select_ss_method)
    _gen_ss_config "$port" "$pass" "$method"
}

do_upgrade_core() {
    title "更新 Xray 核心"
    local cur_ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 || echo "未知")
    echo "  当前版本: $cur_ver"
    local versions; versions=$(curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases | grep '"tag_name"' | cut -d'"' -f4 | head -n 15)
    [[ -z "$versions" ]] && error "获取失败" && return
    
    local i=1; local ver_arr=()
    while IFS= read -r v; do echo "  $i) $v"; ver_arr+=("$v"); ((i++)); done <<< "$versions"
    read -rp "  选择版本编号: " sel
    [[ -z "$sel" ]] && return
    local VERSION="${ver_arr[$((sel-1))]}"
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -v "$VERSION"
    systemctl restart xray
    msg ok "已更新到 $VERSION"
}

do_status_menu() {
    while true; do
        title "查看运行状态"
        echo "  1) 服务状态 2) IP&DNS 3) 流量统计 0) 返回"
        read -rp "选择: " s
        case "$s" in
            1) systemctl status xray --no-pager ;;
            2) _status_ip_dns ;;
            3) _status_traffic ;;
            0) return ;;
        esac
    done
}

_status_ip_dns() {
    get_server_ip
    echo -e "\n  公网 IP: ${green}$SERVER_IP${none}"
    hr
    grep "^nameserver" /etc/resolv.conf
    hr
    ss -tlnp | grep xray
    read -rp "按 Enter 继续..." _
}

_status_traffic() {
    if ! command -v vnstat &>/dev/null; then install_pkg vnstat; systemctl start vnstat; fi
    local iface; iface=$(ip route show default | awk '/default/{print $5}' | head -1)
    vnstat -i "$iface"
    read -rp "按 Enter 继续..." _
}

_vless_client_count() { jq '[.inbounds[]? | select(.protocol=="vless") | .settings.clients[]?] | length' "$CONFIG" 2>/dev/null || echo 0; }

_list_users() {
    title "当前 VLESS 用户"
    local count=$(_vless_client_count)
    [[ "$count" -eq 0 ]] && warn "暂无用户" && return 1
    jq -r '.inbounds[] | select(.protocol=="vless") | .settings.clients[] | "\(.id) \(.flow // "无")"' "$CONFIG" | awk '{printf "  %d. UUID: %s  Flow: %s\n", NR, $1, $2}'
    return 0
}

_add_user() {
    local vidx; vidx=$(_get_vless_idx)
    local uuid=$(gen_uuid); local sid=$(gen_short_id)
    _safe_jq_write ".inbounds[$vidx].settings.clients += [{\"id\":\"$uuid\",\"flow\":\"xtls-rprx-vision\"}] | .inbounds[$vidx].streamSettings.realitySettings.shortIds += [\"$sid\"]"
    systemctl restart xray
    info "已添加用户: $uuid"
}

_delete_user() {
    _list_users || return
    read -rp "输入要删除的序号: " sel
    [[ -z "$sel" ]] && return
    local vidx; vidx=$(_get_vless_idx)
    _safe_jq_write "del(.inbounds[$vidx].settings.clients[$((sel-1))])"
    systemctl restart xray
    info "已删除"
}

_global_block_rules() {
    while true; do
        title "屏蔽规则管理"
        local bt_en; bt_en=$(jq -r '.routing.rules[] | select(.tag_id=="bt") | ._enabled' "$CONFIG")
        echo "  1) BT 屏蔽 [$bt_en] 0) 返回"
        read -rp "选择: " bc
        [[ "$bc" == "0" ]] && return
        local nv; [[ "$bt_en" == "true" ]] && nv="false" || nv="true"
        _safe_jq_write "(.routing.rules[] | select(.tag_id==\"bt\") | ._enabled) = $nv"
        systemctl restart xray
    done
}

do_summary() {
    title "配置摘要"
    [[ ! -f "$CONFIG" ]] && return
    jq . "$CONFIG"
}

do_uninstall() {
    read -rp "确定完整卸载? [yes/N]: " c1
    [[ "$c1" != "yes" ]] && return
    systemctl stop xray; systemctl disable xray
    rm -rf "$CONFIG_DIR" "$LOG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SYMLINK"
    info "卸载完成"
    exit 0
}

main_menu() {
    while true; do
        clear
        echo -e "${blue}  Xray 全功能管理脚本 v6  (xrv)${none}"
        local svc; svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        echo -e "  状态: ${svc}\n"
        echo "  1) 安装 2) 更新核心 3) 更新规则 4) 运行状态 5) 用户管理"
        echo "  6) 规则管理 7) 查看配置 8) 卸载 0) 退出"
        hr
        read -rp "选择: " num
        case "$num" in
            1) do_install ;;
            2) do_upgrade_core ;;
            3) bash "$UPDATE_DAT_SCRIPT" ;;
            4) do_status_menu ;;
            5) _add_user ;;
            6) _global_block_rules ;;
            7) do_summary; read -rp "Enter 继续..." _ ;;
            8) do_uninstall ;;
            0) exit 0 ;;
        esac
    done
}

preflight
main_menu

# 1. 确保 Xray 配置目录及其文件对所有用户可读
chmod -R 755 /usr/local/etc/xray
# 2. 如果你的系统使用的是官方安装脚本，尝试将所有权交给 nobody 用户
chown -R nobody:nogroup /usr/local/etc/xray 2>/dev/null || chown -R nobody:nobody /usr/local/etc/xray
# 3. 重启服务
systemctl restart xray
#!/usr/bin/env bash

# ============================================================
# xrayv6.sh – Xray 全功能管理脚本 v6 (修复版)
# 快捷方式: xrv
# 协议: VLESS-Reality + Shadowsocks
# ============================================================

# 必须用 bash 运行
if [ -z "$BASH_VERSION" ]; then
    echo "错误: 请用 bash 运行此脚本: bash xrayv6.sh"
    exit 1
fi

# – 颜色 –––––––––––––––––––––––––
red='\e[31m'; yellow='\e[33m'; gray='\e[90m'; green='\e[92m'
blue='\e[94m'; magenta='\e[95m'; cyan='\e[96m'; none='\e[0m'
_red()     { echo -e "${red}$*${none}";     }
_blue()    { echo -e "${blue}$*${none}";    }
_cyan()    { echo -e "${cyan}$*${none}";    }
_green()   { echo -e "${green}$*${none}";   }
_yellow()  { echo -e "${yellow}$*${none}";  }
_magenta() { echo -e "${magenta}$*${none}"; }
_red_bg()  { echo -e "\e[41m$*${none}";    }

is_err=$(_red_bg  "错误!")
is_warn=$(_red_bg "警告!")

# 日志函数
info()  { echo -e "${green}[✓]${none} $*"; }
warn()  { echo -e "${yellow}[!]${none} $*"; }
error() { echo -e "${red}[✗]${none} $*";   }
die()   { echo -e "\n${is_err} $*\n"; exit 1; }
title() {
    echo -e "\n${blue}===================================================${none}"
    echo -e "  ${cyan}$*${none}"
    echo -e "${blue}===================================================${none}"
}
hr() { echo -e "${gray}--------------------------${none}"; }

msg() {
    case $1 in
        warn) local c=$yellow ;;
        err)  local c=$red    ;;
        ok)   local c=$green  ;;
        *)    local c=$none   ;;
    esac
    local _t; _t=$(date +%T)
    echo -e "${c}${_t}${none}) ${2}"
}

# – 全局路径 –––––––––––––––––––––––
XRAY_BIN="/usr/local/bin/xray"
CONFIG="/usr/local/etc/xray/config.json"
CONFIG_DIR="/usr/local/etc/xray"
SCRIPT_DIR="/usr/local/etc/xray-script"
UPDATE_DAT_SCRIPT="$SCRIPT_DIR/update-dat.sh"
DAT_DIR="/usr/local/share/xray"
LOG_DIR="/var/log/xray"
SCRIPT_PATH=$(realpath "$0")
SYMLINK="/usr/local/bin/xrv"

GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat"

# – 架构检测 –––––––––––––––––––––––
detect_arch() {
    case $(uname -m) in
        amd64|x86_64)      CORE_ARCH="64";        JQ_ARCH="amd64" ;;
        *aarch64*|*armv8*) CORE_ARCH="arm64-v8a"; JQ_ARCH="arm64" ;;
        *) die "仅支持 64 位系统 (x86_64 / aarch64)" ;;
    esac
}

# – 包管理器检测 ——————————————
detect_pkg_manager() {
    PKG_CMD=$(type -P apt-get || type -P yum || true)
    [[ -z "$PKG_CMD" ]] && die "仅支持 apt-get / yum 系统"
}

# – 安装缺失依赖 ——————————————
install_pkg() {
    local need=""
    for i in "$@"; do
        command -v "$i" &>/dev/null || need="$need $i"
    done
    if [[ -n "$need" ]]; then
        msg warn "安装依赖:$need"
        $PKG_CMD install -y $need &>/dev/null || {
            [[ "$PKG_CMD" =~ yum ]] && yum install epel-release -y &>/dev/null
            $PKG_CMD update -y &>/dev/null
            $PKG_CMD install -y $need &>/dev/null || true
        }
    fi
}

# – wget 封装 ———————————————
_wget() {
    [[ -n "${proxy:-}" ]] && export https_proxy=$proxy
    wget --no-check-certificate "$@"
}

# – 获取公网 IP —————————————––
get_server_ip() {
    SERVER_IP=""
    local trace
    trace=$(_wget -4 -qO- "https://one.one.one.one/cdn-cgi/trace" 2>/dev/null | grep "^ip=" || true)
    [[ -n "$trace" ]] && SERVER_IP="${trace#ip=}"
    [[ -z "$SERVER_IP" ]] && SERVER_IP=$(curl -fsSL --max-time 6 "https://api4.ipify.org" 2>/dev/null || true)
    [[ -z "$SERVER_IP" ]] && SERVER_IP=$(curl -fsSL --max-time 6 "https://ifconfig.me" 2>/dev/null || true)
    [[ -z "$SERVER_IP" ]] && SERVER_IP="YOUR_SERVER_IP"
}

# – 初始化检查 ––––––––––––––––––––––
preflight() {
    [[ $EUID -ne 0 ]] && die "当前非 ROOT 用户"
    [[ ! $(type -P systemctl) ]] && die "系统缺少 systemctl"
    detect_arch
    detect_pkg_manager
    install_pkg jq curl wget xxd unzip

    if [[ ! -L "$SYMLINK" ]] || [[ "$(readlink -f "$SYMLINK")" != "$SCRIPT_PATH" ]]; then
        ln -sf "$SCRIPT_PATH" "$SYMLINK"
        chmod +x "$SCRIPT_PATH"
        info "快捷方式 ${cyan}xrv${none} 已绑定 → $SCRIPT_PATH"
    fi
}

# – 配置文件合法性检查 —————––
check_config() {
    if [[ ! -f "$CONFIG" ]]; then
        error "配置文件不存在: $CONFIG"
        warn "请先执行「1. 安装」"
        return 1
    fi
    if ! jq empty "$CONFIG" 2>/dev/null; then
        error "config.json 格式损坏"
        _try_restore_backup
        return 1
    fi
    local vless_count
    vless_count=$(jq '[.inbounds[]? | select(.protocol=="vless")] | length' "$CONFIG" 2>/dev/null || echo 0)
    if [[ "$vless_count" -gt 0 ]]; then
        local cn
        cn=$(jq -r '(.inbounds[]? | select(.protocol=="vless") | .settings.clients) // "null"' "$CONFIG" 2>/dev/null | head -1)
        if [[ "$cn" == "null" ]]; then
            warn "VLESS clients 为 null，自动修复…"
            _safe_jq_write '(.inbounds[] | select(.protocol=="vless") | .settings.clients) = []' || return 1
        fi
    fi
    return 0
}

_try_restore_backup() {
    local bak
    bak=$(ls -t "${CONFIG}.bak."* 2>/dev/null | head -n1 || true)
    if [[ -n "$bak" ]]; then
        warn "发现最近备份: $bak"
        read -rp "是否还原? [y/N]: " ans
        if [[ "$ans" == "y" ]]; then
            cp "$bak" "$CONFIG"
            systemctl restart xray 2>/dev/null || true
            info "已还原并重启 Xray"
        fi
    fi
}

# – 安全 jq 写入 ——————
_safe_jq_write() {
    local filter="$1"
    local tmp; tmp=$(mktemp /tmp/xray_cfg_XXXXXX.json)
    local bak="${CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"

    if [[ ! -f "$CONFIG" ]]; then
        error "配置文件不存在，无法写入"
        rm -f "$tmp"
        return 1
    fi

    cp "$CONFIG" "$bak"
    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null && jq empty "$tmp" 2>/dev/null; then
        mv "$tmp" "$CONFIG"
        return 0
    fi

    error "jq 写入失败，还原备份..."
    cp "$bak" "$CONFIG"
    rm -f "$tmp"
    return 1
}

# – 随机生成工具 ——————————————
gen_uuid() { cat /proc/sys/kernel/random/uuid; }
gen_short_id() {
    local len=$((RANDOM % 2 == 0 ? 8 : 16))
    head -c 32 /dev/urandom | xxd -p | tr -d '\n' | head -c "$len"
    echo
}
gen_ss_pass() {
    head -c 24 /dev/urandom | base64 | tr -d '=/+\n' | head -c 24
    echo
}

gen_x25519() {
    if [[ ! -x "$XRAY_BIN" ]]; then
        die "xray 二进制不存在，无法生成密钥对: $XRAY_BIN"
    fi
    local keys
    keys=$("$XRAY_BIN" x25519 2>/dev/null)
    
    # 改进的匹配逻辑：忽略大小写，并以冒号为分隔符取第二列
    X25519_PRIV=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' ')
    X25519_PUB=$(echo "$keys" | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' ')

    if [[ -z "$X25519_PRIV" || -z "$X25519_PUB" ]]; then
        # 最后的保底尝试：针对部分版本输出在括号内的情况
        X25519_PUB=$(echo "$keys" | grep -i "PublicKey" | awk -F': ' '{print $2}' | tr -d ' ')
    fi

    if [[ -z "$X25519_PRIV" || -z "$X25519_PUB" ]]; then
        die "x25519 密钥对抓取失败，请检查输出格式"
    fi
}

derive_pubkey() {
    local priv="$1"
    [[ ! -x "$XRAY_BIN" ]] && echo "" && return
    # 同样的改进逻辑
    "$XRAY_BIN" x25519 -i "$priv" 2>/dev/null | grep -i "Public" | awk -F': ' '{print $2}' | tr -d ' '
}

install_update_dat() {
    mkdir -p "$SCRIPT_DIR" "$LOG_DIR"
    cat > "$UPDATE_DAT_SCRIPT" <<'UPDSH'
#!/usr/bin/env bash
set -e
XRAY_DAT_DIR="/usr/local/share/xray"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat"
mkdir -p "$XRAY_DAT_DIR" && cd "$XRAY_DAT_DIR"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 更新 geoip.dat..."
curl -fsSL -o geoip.dat.new "$GEOIP_URL" && mv -f geoip.dat.new geoip.dat
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 更新 geosite.dat..."
curl -fsSL -o geosite.dat.new "$GEOSITE_URL" && mv -f geosite.dat.new geosite.dat
systemctl -q is-active xray && systemctl restart xray && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Xray 已重启"
UPDSH
    chmod +x "$UPDATE_DAT_SCRIPT"
    local job="0 3 * * * $UPDATE_DAT_SCRIPT >> $LOG_DIR/update-dat.log 2>&1"
    (crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT"; echo "$job") | crontab -
    info "cron 任务已配置：每天 03:00 更新 dat"
}

download_dat_now() {
    mkdir -p "$DAT_DIR"
    curl -fsSL -o "$DAT_DIR/geoip.dat" "$GEOIP_URL" && msg ok "geoip.dat 完成"
    curl -fsSL -o "$DAT_DIR/geosite.dat" "$GEOSITE_URL" && msg ok "geosite.dat 完成"
}

_gen_vless_config() {
    local port="$1" uuid="$2" priv="$3" pub="$4" sid="$5" dest="$6" sni="$7"
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG" <<EOF
{
  "log": { "loglevel": "warning" },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {"tag_id":"bt",  "type":"field","protocol":["bittorrent"],"outboundTag":"block","_enabled":true},
      {"tag_id":"cn",  "type":"field","ip":["geoip:cn"],"outboundTag":"block","_enabled":true},
      {"tag_id":"ads", "type":"field","domain":["geosite:category-ads-all"],"outboundTag":"block","_enabled":true}
    ]
  },
  "inbounds": [
    {
      "tag": "vless-reality",
      "listen": "0.0.0.0",
      "port": ${port},
      "protocol": "vless",
      "settings": {
        "clients": [{"id":"${uuid}","flow":"xtls-rprx-vision"}],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "${dest}:443",
          "serverNames": ["${sni}"],
          "privateKey": "${priv}",
          "publicKey": "${pub}",
          "shortIds": ["${sid}"]
        }
      },
      "sniffing": {"enabled":true,"destOverride":["http","tls","quic"]}
    }
  ],
  "outbounds": [
    {"protocol":"freedom","tag":"direct"},
    {"protocol":"blackhole","tag":"block"}
  ]
}
EOF
}

_gen_ss_config() {
    local port="$1" pass="$2" method="$3"
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG" <<EOF
{
  "log": { "loglevel": "warning" },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {"tag_id":"bt",  "type":"field","protocol":["bittorrent"],"outboundTag":"block","_enabled":true},
      {"tag_id":"cn",  "type":"field","ip":["geoip:cn"],"outboundTag":"block","_enabled":true},
      {"tag_id":"ads", "type":"field","domain":["geosite:category-ads-all"],"outboundTag":"block","_enabled":true}
    ]
  },
  "inbounds": [
    {
      "tag": "shadowsocks",
      "listen": "0.0.0.0",
      "port": ${port},
      "protocol": "shadowsocks",
      "settings": {
        "method": "${method}",
        "password": "${pass}",
        "network": "tcp,udp"
      }
    }
  ],
  "outbounds": [
    {"protocol":"freedom","tag":"direct"},
    {"protocol":"blackhole","tag":"block"}
  ]
}
EOF
}

_append_ss_inbound() {
    local port=$1 pass=$2 method=$3
    _safe_jq_write ".inbounds += [{
        \"tag\": \"shadowsocks\",
        \"listen\": \"0.0.0.0\",
        \"port\": $port,
        \"protocol\": \"shadowsocks\",
        \"settings\": {
            \"method\": \"$method\",
            \"password\": \"$pass\",
            \"network\": \"tcp,udp\"
        }
    }]"
}

print_vless_link() {
    local uuid="$1" port="$2" sni="$3" priv="$4" sid="$5" label="${6:-xray-reality}"
    local pub
    pub=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.publicKey // ""' "$CONFIG" 2>/dev/null | head -1)
    [[ -z "$pub" ]] && pub=$(derive_pubkey "$priv")
    get_server_ip
    local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp&headerType=none#${label}"
    hr
    _cyan "  VLESS-Reality 连接参数"
    hr
    printf "  ${yellow}%-16s${none} %s\n" "服务器 IP:" "$SERVER_IP"
    printf "  ${yellow}%-16s${none} %s\n" "端口:" "$port"
    printf "  ${yellow}%-16s${none} %s\n" "UUID:" "$uuid"
    printf "  ${yellow}%-16s${none} %s\n" "SNI:" "$sni"
    printf "  ${yellow}%-16s${none} %s\n" "公钥(pbk):" "$pub"
    printf "  ${yellow}%-16s${none} %s\n" "Short ID:" "$sid"
    hr
    echo -e "\n  链接: ${cyan}${link}${none}\n"
}

print_ss_link() {
    local pass="$1" method="$2" port="$3" label="${4:-xray-ss}"
    get_server_ip
    local b64; b64=$(printf '%s' "${method}:${pass}" | base64 | tr -d '\n')
    local link="ss://${b64}@${SERVER_IP}:${port}#${label}"
    hr
    _cyan "  Shadowsocks 连接参数"
    hr
    printf "  ${yellow}%-16s${none} %s\n" "端口:" "$port"
    printf "  ${yellow}%-16s${none} %s\n" "密码:" "$pass"
    printf "  ${yellow}%-16s${none} %s\n" "加密方式:" "$method"
    hr
    echo -e "\n  链接: ${cyan}${link}${none}\n"
}

input_port() {
    local p
    while true; do
        read -rp "$1 [${2:-}]: " p
        [[ -z "$p" ]] && p="$2"
        if [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 1 && p <= 65535 )); then echo "$p"; return; fi
        error "端口无效 (1-65535)"
    done
}

input_domain() {
    local d
    while true; do
        read -rp "输入目标域名 (如 www.microsoft.com): " d
        [[ -n "$d" ]] && echo "$d" && return
        error "域名不能为空"
    done
}

_select_ss_method() {
    echo "  选择 SS 加密方式：" >&2
    echo "  1) aes-256-gcm (推荐) 2) aes-128-gcm 3) chacha20-ietf-poly1305 4) 2022-blake3-aes-256-gcm" >&2
    read -rp "  编号 [1]: " mc >&2
    case "${mc:-1}" in
        2) echo "aes-128-gcm" ;;
        3) echo "chacha20-ietf-poly1305" ;;
        4) echo "2022-blake3-aes-256-gcm" ;;
        *) echo "aes-256-gcm" ;;
    esac
}

_print_all_links() {
    [[ ! -f "$CONFIG" ]] && return
    local v_count; v_count=$(jq '[.inbounds[]? | select(.protocol=="vless")] | length' "$CONFIG" 2>/dev/null || echo 0)
    if [[ "$v_count" -gt 0 ]]; then
        local v_port v_uuid v_priv v_sid v_sni
        v_port=$(jq -r '.inbounds[] | select(.protocol=="vless") | .port' "$CONFIG" | head -1)
        v_uuid=$(jq -r '.inbounds[] | select(.protocol=="vless") | .settings.clients[0].id' "$CONFIG" | head -1)
        v_priv=$(jq -r '.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.privateKey' "$CONFIG" | head -1)
        v_sid=$(jq -r '.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.shortIds[0]' "$CONFIG" | head -1)
        v_sni=$(jq -r '.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0]' "$CONFIG" | head -1)
        print_vless_link "$v_uuid" "$v_port" "$v_sni" "$v_priv" "$v_sid"
    fi
    local s_count; s_count=$(jq '[.inbounds[]? | select(.protocol=="shadowsocks")] | length' "$CONFIG" 2>/dev/null || echo 0)
    if [[ "$s_count" -gt 0 ]]; then
        local s_port s_pass s_method
        s_port=$(jq -r '.inbounds[] | select(.protocol=="shadowsocks") | .port' "$CONFIG" | head -1)
        s_pass=$(jq -r '.inbounds[] | select(.protocol=="shadowsocks") | .settings.password' "$CONFIG" | head -1)
        s_method=$(jq -r '.inbounds[] | select(.protocol=="shadowsocks") | .settings.method' "$CONFIG" | head -1)
        print_ss_link "$s_pass" "$s_method" "$s_port"
    fi
}

_get_vless_idx() { jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null; }
_get_ss_idx() { jq '[.inbounds | to_entries[] | select(.value.protocol=="shadowsocks")] | .[0].key' "$CONFIG" 2>/dev/null; }

do_install() {
    title "安装 / 重装 Xray"
    if systemctl is-active --quiet xray 2>/dev/null; then
        warn "检测到 Xray 正在运行"
        read -rp "重装将保留配置，继续? [y/N]: " c
        [[ "$c" != "y" ]] && return
    fi

    echo -e "  1) VLESS-Reality (推荐)  2) Shadowsocks  3) 两个都安装"
    read -rp "  输入编号 [1]: " proto_choice
    proto_choice=${proto_choice:-1}

    msg warn "下载并安装 Xray 核心..."
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    
    case "$proto_choice" in
        1) _init_vless_config ;;
        2) _init_ss_config ;;
        3) 
           _init_vless_config
           msg warn "继续配置 Shadowsocks..."
           local sp; sp=$(input_port "SS 监听端口" "8388")
           local spa; spa=$(gen_ss_pass)
           local sm; sm=$(_select_ss_method)
           _append_ss_inbound "$sp" "$spa" "$sm"
           ;;
    esac

    install_update_dat
    download_dat_now
    systemctl enable xray &>/dev/null
    systemctl restart xray
    msg ok "安装完成"
    _print_all_links
    read -rp "按 Enter 返回主菜单..." _
}

_init_vless_config() {
    local port uuid priv pub sid dest sni
    port=$(input_port "VLESS 监听端口" "443")
    dest=$(input_domain)
    read -rp "SNI (留空同域名 [$dest]): " sni
    [[ -z "$sni" ]] && sni="$dest"
    gen_x25519
    uuid=$(gen_uuid); sid=$(gen_short_id)
    _gen_vless_config "$port" "$uuid" "$X25519_PRIV" "$X25519_PUB" "$sid" "$dest" "$sni"
}

_init_ss_config() {
    local port pass method
    port=$(input_port "SS 监听端口" "8388")
    pass=$(gen_ss_pass)
    method=$(_select_ss_method)
    _gen_ss_config "$port" "$pass" "$method"
}

do_upgrade_core() {
    title "更新 Xray 核心"
    local cur_ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 || echo "未知")
    echo "  当前版本: $cur_ver"
    local versions; versions=$(curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases | grep '"tag_name"' | cut -d'"' -f4 | head -n 15)
    [[ -z "$versions" ]] && error "获取失败" && return
    
    local i=1; local ver_arr=()
    while IFS= read -r v; do echo "  $i) $v"; ver_arr+=("$v"); ((i++)); done <<< "$versions"
    read -rp "  选择版本编号: " sel
    [[ -z "$sel" ]] && return
    local VERSION="${ver_arr[$((sel-1))]}"
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -v "$VERSION"
    systemctl restart xray
    msg ok "已更新到 $VERSION"
}

do_status_menu() {
    while true; do
        title "查看运行状态"
        echo "  1) 服务状态 2) IP&DNS 3) 流量统计 0) 返回"
        read -rp "选择: " s
        case "$s" in
            1) systemctl status xray --no-pager ;;
            2) _status_ip_dns ;;
            3) _status_traffic ;;
            0) return ;;
        esac
    done
}

_status_ip_dns() {
    get_server_ip
    echo -e "\n  公网 IP: ${green}$SERVER_IP${none}"
    hr
    grep "^nameserver" /etc/resolv.conf
    hr
    ss -tlnp | grep xray
    read -rp "按 Enter 继续..." _
}

_status_traffic() {
    if ! command -v vnstat &>/dev/null; then install_pkg vnstat; systemctl start vnstat; fi
    local iface; iface=$(ip route show default | awk '/default/{print $5}' | head -1)
    vnstat -i "$iface"
    read -rp "按 Enter 继续..." _
}

_vless_client_count() { jq '[.inbounds[]? | select(.protocol=="vless") | .settings.clients[]?] | length' "$CONFIG" 2>/dev/null || echo 0; }

_list_users() {
    title "当前 VLESS 用户"
    local count=$(_vless_client_count)
    [[ "$count" -eq 0 ]] && warn "暂无用户" && return 1
    jq -r '.inbounds[] | select(.protocol=="vless") | .settings.clients[] | "\(.id) \(.flow // "无")"' "$CONFIG" | awk '{printf "  %d. UUID: %s  Flow: %s\n", NR, $1, $2}'
    return 0
}

_add_user() {
    local vidx; vidx=$(_get_vless_idx)
    local uuid=$(gen_uuid); local sid=$(gen_short_id)
    _safe_jq_write ".inbounds[$vidx].settings.clients += [{\"id\":\"$uuid\",\"flow\":\"xtls-rprx-vision\"}] | .inbounds[$vidx].streamSettings.realitySettings.shortIds += [\"$sid\"]"
    systemctl restart xray
    info "已添加用户: $uuid"
}

_delete_user() {
    _list_users || return
    read -rp "输入要删除的序号: " sel
    [[ -z "$sel" ]] && return
    local vidx; vidx=$(_get_vless_idx)
    _safe_jq_write "del(.inbounds[$vidx].settings.clients[$((sel-1))])"
    systemctl restart xray
    info "已删除"
}

_global_block_rules() {
    while true; do
        title "屏蔽规则管理"
        local bt_en; bt_en=$(jq -r '.routing.rules[] | select(.tag_id=="bt") | ._enabled' "$CONFIG")
        echo "  1) BT 屏蔽 [$bt_en] 0) 返回"
        read -rp "选择: " bc
        [[ "$bc" == "0" ]] && return
        local nv; [[ "$bt_en" == "true" ]] && nv="false" || nv="true"
        _safe_jq_write "(.routing.rules[] | select(.tag_id==\"bt\") | ._enabled) = $nv"
        systemctl restart xray
    done
}

do_summary() {
    title "配置摘要"
    [[ ! -f "$CONFIG" ]] && return
    jq . "$CONFIG"
}

do_uninstall() {
    read -rp "确定完整卸载? [yes/N]: " c1
    [[ "$c1" != "yes" ]] && return
    systemctl stop xray; systemctl disable xray
    rm -rf "$CONFIG_DIR" "$LOG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SYMLINK"
    info "卸载完成"
    exit 0
}

main_menu() {
    while true; do
        clear
        echo -e "${blue}  Xray 全功能管理脚本 v6  (xrv)${none}"
        local svc; svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        echo -e "  状态: ${svc}\n"
        echo "  1) 安装 2) 更新核心 3) 更新规则 4) 运行状态 5) 用户管理"
        echo "  6) 规则管理 7) 查看配置 8) 卸载 0) 退出"
        hr
        read -rp "选择: " num
        case "$num" in
            1) do_install ;;
            2) do_upgrade_core ;;
            3) bash "$UPDATE_DAT_SCRIPT" ;;
            4) do_status_menu ;;
            5) _add_user ;;
            6) _global_block_rules ;;
            7) do_summary; read -rp "Enter 继续..." _ ;;
            8) do_uninstall ;;
            0) exit 0 ;;
        esac
    done
}

preflight
main_menu


# 1. 确保 Xray 配置目录及其文件对所有用户可读
chmod -R 755 /usr/local/etc/xray

# 2. 如果你的系统使用的是官方安装脚本，尝试将所有权交给 nobody 用户
chown -R nobody:nogroup /usr/local/etc/xray 2>/dev/null || chown -R nobody:nobody /usr/local/etc/xray

# 3. 重启服务
systemctl restart xray
