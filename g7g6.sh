#!/usr/bin/env bash
# ============================================================
# 脚本名称: g7g6.sh (Grandmaster All-in-One Edition)
# 论坛支持: https://xp.day
# 核心增量: 
#   1. 完美集成：安装/卸载/探针/多用户/规则更新/核心热升级
#   2. 性能巅峰：XTLS-Vision + uTLS 指纹 + 16位高强短ID
#   3. 高阶调优：支持 Vision Seed 参数全用户动态同步
#   4. 自动化：后台驻留 Cron 守护，每日凌晨更新 Geo 库
# ============================================================

# ----------------- 基础环境与安全防线 -----------------
if [ -z "$BASH_VERSION" ]; then
    echo "错误: 请用 bash 运行此脚本: bash $0"
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    clear
    echo -e "\033[31m[错误] 此脚本必须以 root 身份运行!\033[0m" 1>&2
    exit 1
fi

# ----------------- 全局变量 & 颜色系统 -----------------
SERVER_IP=""
LOG_FILE="/var/log/xray_g7g6_install.log"
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

# ----------------- 系统检测与网络预检 -----------------
detect_system() {
    case $(uname -m) in
        amd64|x86_64) CORE_ARCH="64" ;;
        *aarch64*|*armv8*) CORE_ARCH="arm64-v8a" ;;
        *) die "系统架构不支持 (仅限 x86_64 / aarch64)" ;;
    esac

    if command -v apt-get &>/dev/null; then
        PKG_CMD="apt-get"; PKG_UPDATE="apt-get update -y"; PKG_INSTALL="apt-get install -y"
        while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do info "等待 dpkg 锁..."; sleep 2; done
    elif command -v yum &>/dev/null; then
        PKG_CMD="yum"; PKG_UPDATE="yum makecache"; PKG_INSTALL="yum install -y"
        yum install -y epel-release 2>/dev/null || true
    elif command -v dnf &>/dev/null; then
        PKG_CMD="dnf"; PKG_UPDATE="dnf makecache"; PKG_INSTALL="dnf install -y"
    else
        die "不支持的包管理器 (需 apt/yum/dnf)"
    fi
}

install_dependencies() {
    info "校准系统环境并安装底层依赖..."
    eval "$PKG_UPDATE" >/dev/null 2>&1
    local pkgs="curl wget gawk jq ca-certificates gnupg unzip vnstat xxd cron"
    [[ "$PKG_CMD" == "apt-get" ]] && pkgs="$pkgs lsb-release cron"
    [[ "$PKG_CMD" == "yum" || "$PKG_CMD" == "dnf" ]] && pkgs="$pkgs cronie"
    
    eval "$PKG_INSTALL $pkgs" >/dev/null 2>&1
    for tool in curl jq xxd vnstat; do
        command -v "$tool" &>/dev/null || die "关键工具 $tool 安装失败!"
    done
}

get_server_ip() {
    [[ -n "$SERVER_IP" ]] && return 0
    info "精准定位公网 IP 中..."
    local apis=("https://api4.ipify.org" "https://ipv4.icanhazip.com" "http://www.cloudflare.com/cdn-cgi/trace")
    for api in "${apis[@]}"; do
        if [[ "$api" == *"cloudflare"* ]]; then
            SERVER_IP=$(curl -s -4 -m 5 "$api" | grep "ip=" | awk -F "=" '{print $2}' | tr -d '\r\n')
        else
            SERVER_IP=$(curl -s -4 -m 5 "$api" | tr -d '\r\n')
        fi
        [[ "$SERVER_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] && return 0
    done
    die "无法获取 IPv4 地址，请检查机器网络出口!"
}

# ----------------- 数据防护与高强度生成器 -----------------
_fix_permissions() {
    chmod 600 "$CONFIG"
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
    error "JSON 逻辑重组失败，已自动触发回滚保护!"
    [[ -f "$bak" ]] && mv "$bak" "$CONFIG"
    rm -f "$tmp"
    return 1
}

gen_uuid() { cat /proc/sys/kernel/random/uuid; }
gen_short_id() { head -c 8 /dev/urandom | xxd -p | tr -d '\n'; }
gen_ss_pass() { head -c 24 /dev/urandom | base64 | tr -d '=/+\n' | head -c 24; }
gen_x25519() {
    local keys; keys=$("$XRAY_BIN" x25519 2>/dev/null)
    [[ -z "$keys" ]] && die "Xray 引擎生成 X25519 密钥对失败"
    X25519_PRIV=$(echo "$keys" | awk '/Private key:/ {print $3}' | tr -d '\r\n')
    X25519_PUB=$(echo "$keys"  | awk '/Public key:/ {print $3}' | tr -d '\r\n')
    [[ -z "$X25519_PRIV" ]] && die "密钥流解析失败"
}

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
    (crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT"; echo "0 3 * * * $UPDATE_DAT_SCRIPT") | crontab -
    info "已注入底层守护：每天凌晨 3:00 自动更新 Geo 规则库"
}

# ----------------- Xray 核心架构部署 -----------------
install_xray_core() {
    info "拉取 Xray-core 最新核心..."
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    [[ ! -x "$XRAY_BIN" ]] && die "Xray 核心写入失败"
    
    chmod -R 755 /usr/local/etc/xray
    _fix_permissions
    
    if [[ ! -L "$SYMLINK" ]]; then
        ln -sf "$(realpath "$0")" "$SYMLINK"
        chmod +x "$(realpath "$0")"
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
    if systemctl is-active --quiet xray 2>/dev/null; then
        warn "检测到 Xray 正在运行，继续操作将覆盖所有已有节点!"
        read -rp "是否继续覆写? [y/N]: " c; [[ "$c" != "y" ]] && return
    fi
    
    install_xray_core
    _init_base_config
    setup_cron_dat
    
    echo -e "  [拓扑模式选择]\n  1) VLESS-Reality + XTLS Vision (主推大杀器)\n  2) Shadowsocks (经典备用)"
    read -rp "  请选择 [1]: " choice
    
    if [[ "${choice:-1}" == "1" ]]; then
        read -rp "  VLESS 监听端口 [443]: " p; p=${p:-443}
        read -rp "  目标域名(Dest) [www.amazon.com]: " d; d=${d:-www.amazon.com}
        read -rp "  SNI伪装(留空同域名): " s; s=${s:-$d}
        
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
    info "底层网络拓扑构建完毕！"
    do_summary
    read -rp "按 Enter 返回总控台..." _
}

# ----------------- 核心热升级管理 -----------------
do_upgrade_core() {
    title "更新 / 降级 Xray 核心引擎"
    local cur_ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 | awk '{print $2}')
    echo -e "  当前已装版本: ${green}${cur_ver:-未知}${none}"
    info "正在从 GitHub 获取最新 Release 列表..."
    
    local versions; versions=$(curl -fsSL -m 10 https://api.github.com/repos/XTLS/Xray-core/releases | grep '"tag_name"' | cut -d'"' -f4 | head -n 10)
    [[ -z "$versions" ]] && { error "获取版本列表失败，请检查服务器网络。"; read -rp "按 Enter 返回..."; return; }
    
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
    [[ -z "$VERSION" ]] && { error "输入无效"; return; }
    
    info "正在为您替换核心至 $VERSION ..."
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -v "$VERSION"
    _fix_permissions
    systemctl restart xray
    info "Xray 核心已成功切换至 $VERSION"
    read -rp "按 Enter 返回..." _
}

# ----------------- 用户配额管理中心 -----------------
do_user_manager() {
    while true; do
        title "多用户权限与 UUID 管理"
        local vidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null)
        if [[ "$vidx" == "null" || -z "$vidx" ]]; then
            warn "未发现 VLESS-Reality 配置，此功能不可用。"
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
               # 新增用户自动继承 Padding 框架
               _safe_jq_write ".inbounds[$vidx].settings.clients += [{
                 \"id\": \"$new_uuid\", \"flow\": \"xtls-rprx-vision\",
                 \"padding\": { \"triggerThreshold\": 900, \"maxLengthLong\": 500, \"extraLengthLong\": 900, \"maxLengthShort\": 256 }
               }]"
               systemctl restart xray
               info "新用户已下发生效: $new_uuid"
               ;;
            2)
               read -rp "  粘贴需要吊销的 UUID: " duid
               [[ -z "$duid" ]] && continue
               _safe_jq_write "del(.inbounds[$vidx].settings.clients[] | select(.id == \"$duid\"))"
               systemctl restart xray
               info "若该 UUID 存在，现已被彻底吊销。"
               ;;
            0) break ;;
            *) error "无效选项" ;;
        esac
    done
}

# ----------------- Vision Seed 深度定制 -----------------
do_vision_seed_config() {
    title "XTLS Vision Seed (Padding) 参数微调"
    local vidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null)
    [[ "$vidx" == "null" || -z "$vidx" ]] && { error "未找到 VLESS 配置"; read -rp "按 Enter 返回..."; return; }

    _cyan "调整 Xray (25.12.8+) 的 XTLS Vision 数据包随机填充策略。"
    _cyan "修改后将自动同步至当前节点下的所有 UUID 用户！(回车保持现状)"
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

    val_trig=${val_trig:-$cur_trig}; val_ml=${val_ml:-$cur_ml}
    val_el=${val_el:-$cur_el};       val_ms=${val_ms:-$cur_ms}

    # 使用 jq map 功能，一键更新所有用户的 padding
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
    info "全局 Vision Seed 参数已同步注入并重启服务！"
    read -rp "按 Enter 返回..." _
}

# ----------------- 分发链接与节点展示 -----------------
do_summary() {
    title "终端节点分发中心"
    [[ ! -f "$CONFIG" ]] && { error "未找到配置文件，请先安装"; return; }
    get_server_ip
    
    local vidx=$(jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null)
    if [[ "$vidx" != "null" && -n "$vidx" ]]; then
        local port=$(jq -r ".inbounds[$vidx].port" "$CONFIG")
        local pub=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.publicKey" "$CONFIG")
        local sni=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.serverNames[0]" "$CONFIG")
        local sid=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.shortIds[0]" "$CONFIG")
        
        echo -e "为该节点选择 ${yellow}uTLS 指纹防反制策略${none}:"
        echo " 1) chrome (默认)  2) firefox  3) safari  4) ios  5) edge"
        read -rp "选项 [1]: " fp_sel
        case "${fp_sel:-1}" in
            2) utls_fp="firefox" ;; 3) utls_fp="safari" ;; 4) utls_fp="ios" ;; 5) utls_fp="edge" ;; *) utls_fp="chrome" ;;
        esac

        hr
        _cyan "【VLESS-Reality 专属节点】"
        echo -e " 协议框架\t: \033[32mVLESS + Reality + XTLS Vision\033[0m"
        echo -e " 外网IP\t\t: \033[33m$SERVER_IP\033[0m"
        echo -e " 端口\t\t: \033[33m$port\033[0m"
        echo -e " 伪装SNI\t: \033[33m$sni\033[0m"
        echo -e " 公钥(pbk)\t: \033[33m$pub\033[0m"
        echo -e " ShortId\t: \033[33m$sid\033[0m"
        echo -e " uTLS引擎\t: \033[33m$utls_fp\033[0m"
        hr
        _green "多用户独立导入链接 (已植入 xp 安全后缀):"
        
        jq -r ".inbounds[$vidx].settings.clients[].id" "$CONFIG" | while read -r uuid; do
            echo -e "\n${yellow}用户 UUID:${none} $uuid"
            echo "vless://$uuid@$SERVER_IP:$port?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$sni&fp=$utls_fp&pbk=$pub&sid=$sid&type=tcp&headerType=none#xp-reality"
        done
        echo ""
    fi
    
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

# ----------------- 服务器大盘监控 -----------------
do_status() {
    title "服务器资源与网络探针"
    echo -e "${cyan}[核心服务运行状态]${none}"
    systemctl status xray --no-pager | head -n 8
    hr
    if command -v vnstat &>/dev/null; then
        echo -e "${cyan}[物理网卡流量审计]${none}"
        local iface=$(ip route show default | awk '/default/{print $5}' | head -1)
        vnstat -i "$iface"
    fi
    read -rp "按 Enter 返回主控台..." _
}

# ----------------- 总调度台 -----------------
main_menu() {
    detect_system
    install_dependencies

    while true; do
        clear
        echo -e "${blue}===================================================${none}"
        echo -e "     ${cyan}Xray G7G6 终极宇宙版 (任意位置输入 xrv 唤醒)${none}"
        echo -e "${blue}===================================================${none}"
        local svc=$(systemctl is-active xray 2>/dev/null || echo "inactive")
        local cur_ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 | awk '{print $2}')
        echo -e "  服务状态: $([[ "$svc" == "active" ]] && _green "▶ 稳定运行" || _red "■ 脱机停止") | 版本: ${yellow}${cur_ver:-N/A}${none}\n"
        
        echo "  1) 核心重装 / 覆盖网络拓扑"
        echo "  2) 用户管理 (UUID 增删控制)"
        echo "  3) 节点分享 (查看所有链接及 uTLS 调整)"
        echo "  4) 高阶调优 (Vision Seed 动态 Padding)"
        echo "  5) 系统探针 (流量与运行日志)"
        echo "  6) 在线更新 Xray 核心引擎"
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
               systemctl restart xray; info "Geo 库已云端同步完成"; read -rp "按 Enter 返回..." _ ;;
            8) 
               systemctl stop xray; systemctl disable xray
               crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT" | crontab -
               rm -rf "$CONFIG_DIR" "$LOG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SYMLINK" "$SCRIPT_DIR"
               info "服务已剥离，数据已粉碎。"; exit 0 ;;
            0) exit 0 ;;
            *) error "指令无法识别" ;;
        esac
    done
}

# -> 启动
main_menu
