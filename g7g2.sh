#!/bin/bash
# script: g7g2.sh (Optimized & Hardened Edition)

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
    echo -e " ShortId\t: 88"
    echo -e " 流控协议\t: xtls-rprx-vision"
    display_green "=========================================="
    echo
    display_green "一键导入链接 (VLESS URL)："
    echo "vless://$UUID@$SERVER_IP:$PORT_NUMBER?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SERVER_SNI&fp=chrome&pbk=$RE_PUBLIC_KEY&sid=88&type=tcp&headerType=none#xp-reality"
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
