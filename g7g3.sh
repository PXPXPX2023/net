#!/usr/bin/env bash
# ============================================================
# 脚本名称: g7g3.sh (Ultimate Fusion & Vision Seed Edition)
# 核心亮点: 
#   1. g7g2 强悍底层 + v6 丰富交互界面的完美融合
#   2. 强制开启 xtls-rprx-vision 流控
#   3. uTLS 伪装机制深度植入
#   4. 首发支持 Xray-core 25.12.8+ 的 Vision Seed 填充参数自定义
#   5. 完全随机的 ShortId 及安全权限隔离
# ============================================================

# ----------------- 基础环境校验 -----------------
if [ -z "$BASH_VERSION" ]; then
    echo "错误: 请用 bash 运行此脚本: bash $0"
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    clear
    echo -e "\033[31m[错误] 此脚本必须以 root 身份运行!\033[0m" 1>&2
    exit 1
fi

# ----------------- 全局变量 & 颜色定义 -----------------
SERVER_IP=""
LOG_FILE="/var/log/xray_g7g3_install.log"
CONFIG_DIR="/usr/local/etc/xray"
CONFIG="$CONFIG_DIR/config.json"
SCRIPT_DIR="/usr/local/etc/xray-script"
UPDATE_DAT_SCRIPT="$SCRIPT_DIR/update-dat.sh"
DAT_DIR="/usr/local/share/xray"
XRAY_BIN="/usr/local/bin/xray"
SYMLINK="/usr/local/bin/xrv"

red='\e[31m'; yellow='\e[33m'; gray='\e[90m'; green='\e[92m'
blue='\e[94m'; cyan='\e[96m'; none='\e[0m'
_red()     { echo -e "${red}$*${none}"; }
_green()   { echo -e "${green}$*${none}"; }
_yellow()  { echo -e "${yellow}$*${none}"; }
_cyan()    { echo -e "${cyan}$*${none}"; }

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
touch "$LOG_FILE" 2>/dev/null || LOG_FILE=""

# ----------------- 日志与输出模块 -----------------
log_only() { [[ -n "$LOG_FILE" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }
info()  { echo -e "${green}[✓]${none} $1"; log_only "[INFO] $1"; }
warn()  { echo -e "${yellow}[!]${none} $1"; log_only "[WARN] $1"; }
error() { echo -e "${red}[✗]${none} $1"; log_only "[ERROR] $1"; }
die()   { echo -e "\n${red}[致命错误] $1${none}\n"; log_only "[FATAL] $1"; exit 1; }
hr()    { echo -e "${gray}---------------------------------------------------${none}"; }
title() {
    echo -e "\n${blue}===================================================${none}"
    echo -e "  ${cyan}$1${none}"
    echo -e "${blue}===================================================${none}"
}

# ----------------- 核心系统检测 -----------------
detect_arch() {
    case $(uname -m) in
        amd64|x86_64) CORE_ARCH="64" ;;
        *aarch64*|*armv8*) CORE_ARCH="arm64-v8a" ;;
        *) die "仅支持 64 位系统 (x86_64 / aarch64)" ;;
    esac
}

init_package_manager() {
    if command -v apt-get &>/dev/null; then
        PKG_CMD="apt-get"
        PKG_UPDATE="apt-get update -y"
        PKG_INSTALL="apt-get install -y"
        while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do info "等待 dpkg 锁释放..."; sleep 2; done
    elif command -v yum &>/dev/null; then
        PKG_CMD="yum"
        PKG_UPDATE="yum makecache"
        PKG_INSTALL="yum install -y"
        yum install -y epel-release 2>/dev/null || true
    elif command -v dnf &>/dev/null; then
        PKG_CMD="dnf"
        PKG_UPDATE="dnf makecache"
        PKG_INSTALL="dnf install -y"
    else
        die "不支持的包管理器 (仅支持 apt/yum/dnf)"
    fi
}

install_dependencies() {
    info "检查并安装基础依赖..."
    eval "$PKG_UPDATE" >/dev/null 2>&1
    local pkgs="curl wget gawk jq ca-certificates gnupg unzip vnstat xxd"
    [[ "$PKG_CMD" == "apt-get" ]] && pkgs="$pkgs lsb-release"
    
    eval "$PKG_INSTALL $pkgs" >/dev/null 2>&1 || warn "依赖安装可能存在警告，尝试继续..."
    for tool in curl jq xxd; do
        command -v "$tool" &>/dev/null || die "关键组件 $tool 缺失，请检查源!"
    done
}

get_server_ip() {
    info "正在解析服务器对外 IP..."
    local ip_apis=("https://api4.ipify.org" "https://ipv4.icanhazip.com" "http://www.cloudflare.com/cdn-cgi/trace")
    for api in "${ip_apis[@]}"; do
        if [[ "$api" == *"cloudflare"* ]]; then
            SERVER_IP=$(curl -s -4 -m 5 "$api" | grep "ip=" | awk -F "=" '{print $2}' | tr -d '\r\n')
        else
            SERVER_IP=$(curl -s -4 -m 5 "$api" | tr -d '\r\n')
        fi
        [[ "$SERVER_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] && return 0
    done
    die "无法获取公网 IP，请检查服务器网络!"
}

# ----------------- 数据安全与生成工具 -----------------
_safe_jq_write() {
    local filter="$1"
    local tmp; tmp=$(mktemp /tmp/xray_cfg_XXXXXX.json)
    local bak="${CONFIG}.bak.$(date +%s)"
    [[ -f "$CONFIG" ]] && cp "$CONFIG" "$bak"
    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null && jq empty "$tmp" 2>/dev/null; then
        mv "$tmp" "$CONFIG"
        chmod 600 "$CONFIG" # 权限收紧，保护私钥
        return 0
    fi
    error "JSON 注入失败，已回滚"
    [[ -f "$bak" ]] && mv "$bak" "$CONFIG"
    rm -f "$tmp"
    return 1
}

gen_uuid() { cat /proc/sys/kernel/random/uuid; }
gen_short_id() { head -c 8 /dev/urandom | xxd -p | tr -d '\n'; } # 彻底解决写死问题，16位随机十六进制
gen_ss_pass() { head -c 24 /dev/urandom | base64 | tr -d '=/+\n' | head -c 24; }

gen_x25519() {
    local keys; keys=$("$XRAY_BIN" x25519 2>/dev/null)
    [[ -z "$keys" ]] && die "核心引擎生成密钥对失败"
    X25519_PRIV=$(echo "$keys" | awk '/Private key:/ {print $3}' | tr -d '\r\n')
    X25519_PUB=$(echo "$keys"  | awk '/Public key:/ {print $3}' | tr -d '\r\n')
    [[ -z "$X25519_PRIV" ]] && die "密钥解析失败，请检查核心版本"
}

# ----------------- 核心配置下发 -----------------
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

_add_vless_reality() {
    local port="$1" dest="$2" sni="$3"
    gen_x25519
    local uuid=$(gen_uuid); local sid=$(gen_short_id)
    
    # 注入 VLESS + XTLS Vision + 默认 Vision Seed 填充参数
    _safe_jq_write ".inbounds += [{
      \"tag\": \"vless-reality\",
      \"listen\": \"0.0.0.0\",
      \"port\": $port,
      \"protocol\": \"vless\",
      \"settings\": {
        \"clients\": [{
          \"id\": \"$uuid\",
          \"flow\": \"xtls-rprx-vision\",
          \"padding\": {
            \"triggerThreshold\": 900,
            \"maxLengthLong\": 500,
            \"extraLengthLong\": 900,
            \"maxLengthShort\": 256
          }
        }],
        \"decryption\": \"none\"
      },
      \"streamSettings\": {
        \"network\": \"tcp\",
        \"security\": \"reality\",
        \"realitySettings\": {
          \"dest\": \"$dest:443\",
          \"serverNames\": [\"$sni\"],
          \"privateKey\": \"$X25519_PRIV\",
          \"publicKey\": \"$X25519_PUB\",
          \"shortIds\": [\"$sid\"]
        }
      },
      \"sniffing\": {\"enabled\":true,\"destOverride\":[\"http\",\"tls\",\"quic\"]}
    }]"
}

# ----------------- 安装及依赖 -----------------
install_xray_core() {
    info "正在从 GitHub 获取 Xray-core..."
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    [[ ! -x "$XRAY_BIN" ]] && die "Xray 安装失败"
    
    # 强制修正权限，给 nobody 运行环境，同时确保 xrv 快捷键映射
    chmod -R 755 /usr/local/etc/xray
    chown -R nobody:nogroup /usr/local/etc/xray 2>/dev/null || chown -R nobody:nobody /usr/local/etc/xray
    
    if [[ ! -L "$SYMLINK" ]]; then
        ln -sf "$(realpath "$0")" "$SYMLINK"
        chmod +x "$(realpath "$0")"
    fi
}

do_install() {
    title "全新安装 / 重置 Xray"
    if systemctl is-active --quiet xray 2>/dev/null; then
        warn "Xray 正在运行，继续将覆盖配置!"
        read -rp "是否继续? [y/N]: " c; [[ "$c" != "y" ]] && return
    fi
    
    install_xray_core
    _init_base_config
    
    echo -e "  [协议选择]\n  1) VLESS-Reality + uTLS (推荐)\n  2) Shadowsocks"
    read -rp "  请选择 [1]: " choice
    
    if [[ "${choice:-1}" == "1" ]]; then
        read -rp "  VLESS 监听端口 [443]: " p; p=${p:-443}
        read -rp "  目标域名 (Dest) [www.amazon.com]: " d; d=${d:-www.amazon.com}
        read -rp "  SNI (留空同域名): " s; s=${s:-$d}
        _add_vless_reality "$p" "$d" "$s"
    else
        read -rp "  SS 监听端口 [8388]: " p; p=${p:-8388}
        local pass=$(gen_ss_pass)
        _safe_jq_write ".inbounds += [{
            \"tag\": \"shadowsocks\", \"port\": $p, \"protocol\": \"shadowsocks\",
            \"settings\": { \"method\": \"aes-256-gcm\", \"password\": \"$pass\", \"network\": \"tcp,udp\" }
        }]"
    fi

    systemctl enable xray &>/dev/null
    systemctl restart xray
    info "安装完毕！"
    do_summary
    read -rp "按 Enter 返回主菜单..." _
}

# ----------------- Vision Seed 参数动态调整 -----------------
do_vision_seed_config() {
    title "XTLS Vision Seed (Padding) 参数微调"
    local vidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null)
    [[ "$vidx" == "null" || -z "$vidx" ]] && { error "未找到 VLESS-Reality 配置"; read -rp "按 Enter 返回..."; return; }

    _cyan "当前 Xray (25.12.8+) 支持深度自定义 XTLS Vision 的填充策略。"
    _cyan "合理的填充可以有效抵抗特征识别。留空则保持当前值或默认值。"
    echo ""
    
    local cur_trig=$(jq -r ".inbounds[$vidx].settings.clients[0].padding.triggerThreshold // 900" "$CONFIG")
    local cur_ml=$(jq -r ".inbounds[$vidx].settings.clients[0].padding.maxLengthLong // 500" "$CONFIG")
    local cur_el=$(jq -r ".inbounds[$vidx].settings.clients[0].padding.extraLengthLong // 900" "$CONFIG")
    local cur_ms=$(jq -r ".inbounds[$vidx].settings.clients[0].padding.maxLengthShort // 256" "$CONFIG")

    read -rp " 1. 长填充触发阈值 (默认 900) [$cur_trig]: " val_trig
    read -rp " 2. 长填充最大字节 (默认 500) [$cur_ml]: " val_ml
    read -rp " 3. 长填充额外字节 (默认 900) [$cur_el]: " val_el
    read -rp " 4. 正常最大字节数 (默认 256) [$cur_ms]: " val_ms

    val_trig=${val_trig:-$cur_trig}
    val_ml=${val_ml:-$cur_ml}
    val_el=${val_el:-$cur_el}
    val_ms=${val_ms:-$cur_ms}

    # 动态写入所有 Client 的 padding
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
    systemctl restart xray
    info "Vision Seed 参数已更新并重启服务！"
    read -rp "按 Enter 返回..." _
}

# ----------------- 节点摘要展示 (集成 uTLS 与随机 ShortId) -----------------
do_summary() {
    title "节点连接信息配置"
    [[ ! -f "$CONFIG" ]] && { error "未找到 config.json"; return; }
    get_server_ip
    
    # 检测 VLESS
    local vidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null)
    if [[ "$vidx" != "null" && -n "$vidx" ]]; then
        local port=$(jq -r ".inbounds[$vidx].port" "$CONFIG")
        local pub=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.publicKey" "$CONFIG")
        local sni=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.serverNames[0]" "$CONFIG")
        local sid=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.shortIds[0]" "$CONFIG")
        local uuid=$(jq -r ".inbounds[$vidx].settings.clients[0].id" "$CONFIG")
        
        # 让用户选择 uTLS 伪装
        echo -e "请选择客户端使用的 ${yellow}uTLS 指纹伪装${none} (影响分享链接):"
        echo " 1) chrome (默认推荐)  2) firefox  3) safari  4) ios  5) edge"
        read -rp "选择 [1]: " fp_sel
        case "${fp_sel:-1}" in
            2) utls_fp="firefox" ;;
            3) utls_fp="safari" ;;
            4) utls_fp="ios" ;;
            5) utls_fp="edge" ;;
            *) utls_fp="chrome" ;;
        esac

        hr
        _cyan "【VLESS-Reality 专属节点】"
        echo -e " 协议类型\t: \033[32mVLESS + Reality + XTLS Vision\033[0m"
        echo -e " 服务器IP\t: \033[33m$SERVER_IP\033[0m"
        echo -e " 端口\t\t: \033[33m$port\033[0m"
        echo -e " UUID\t\t: \033[33m$uuid\033[0m"
        echo -e " SNI\t\t: \033[33m$sni\033[0m"
        echo -e " PublicKey\t: \033[33m$pub\033[0m"
        echo -e " ShortId\t: \033[33m$sid\033[0m"
        echo -e " uTLS伪装\t: \033[33m$utls_fp\033[0m"
        hr
        _green "一键导入链接 (已剔除1024, 加入uTLS与流控):"
        echo "vless://$uuid@$SERVER_IP:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$sni&fp=$utls_fp&pbk=$pub&sid=$sid&type=tcp&headerType=none#xp-reality"
        echo ""
    fi
    
    # 检测 SS
    local sidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="shadowsocks")] | .[0].key' "$CONFIG" 2>/dev/null)
    if [[ "$sidx" != "null" && -n "$sidx" ]]; then
        local sport=$(jq -r ".inbounds[$sidx].port" "$CONFIG")
        local spass=$(jq -r ".inbounds[$sidx].settings.password" "$CONFIG")
        local smethod=$(jq -r ".inbounds[$sidx].settings.method" "$CONFIG")
        local b64=$(printf '%s' "${smethod}:${spass}" | base64 | tr -d '\n')
        
        _cyan "【Shadowsocks 备用节点】"
        echo -e " 端口: $sport | 密码: $spass | 加密: $smethod"
        _green " ss://${b64}@${SERVER_IP}:${sport}#xp-ss"
        echo ""
    fi
}

# ----------------- 运维状态查看 -----------------
do_status() {
    title "服务器运维面板"
    systemctl status xray --no-pager | head -n 10
    hr
    if command -v vnstat &>/dev/null; then
        _cyan "【网卡流量统计】"
        local iface=$(ip route show default | awk '/default/{print $5}' | head -1)
        vnstat -i "$iface"
    else
        warn "未安装 vnstat，无法显示流量"
    fi
    read -rp "按 Enter 返回主菜单..." _
}

# ----------------- 主菜单交互 -----------------
main_menu() {
    detect_arch
    init_package_manager
    install_dependencies

    while true; do
        clear
        echo -e "${blue}===================================================${none}"
        echo -e "       ${cyan}Xray G7G3 终极版管理平台 (全局命令: xrv)${none}"
        echo -e "${blue}===================================================${none}"
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        echo -e "  服务状态: $([[ "$svc" == "active" ]] && _green "▶ 运行中" || _red "■ 已停止")\n"
        
        echo "  1) 全新安装 / 重置配置"
        echo "  2) 查看节点链接 (含 uTLS 伪装切换)"
        echo "  3) 高级配置: XTLS Vision Seed 参数调整"
        echo "  4) 查看服务状态及流量"
        echo "  5) 强制更新 Geo 规则库"
        echo "  8) 彻底卸载 Xray"
        echo "  0) 退出"
        hr
        read -rp "请输入选项: " opt
        case "$opt" in
            1) do_install ;;
            2) do_summary; read -rp "按 Enter 返回..." _ ;;
            3) do_vision_seed_config ;;
            4) do_status ;;
            5) 
               curl -fsSL -o "$DAT_DIR/geoip.dat" "https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"
               curl -fsSL -o "$DAT_DIR/geosite.dat" "https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat"
               systemctl restart xray; info "Geo 库已更新"; read -rp "按 Enter 返回..." _ ;;
            8) 
               systemctl stop xray; systemctl disable xray
               rm -rf "$CONFIG_DIR" "$LOG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SYMLINK"
               info "已彻底卸载"; exit 0 ;;
            0) exit 0 ;;
            *) error "无效选项" ;;
        esac
    done
}

# 启动主程序
main_menu
