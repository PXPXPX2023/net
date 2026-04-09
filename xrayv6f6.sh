#!/usr/bin/env bash

# ============================================================

# xrayv6.sh – Xray 全功能管理脚本 v6

# 快捷方式: xrv

# 协议: VLESS-Reality + Shadowsocks

# 运行方式: bash xrayv6.sh

# ============================================================

# 必须用 bash 运行，拒绝 sh / dash

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
hr() { echo -e "${gray}––––––––––––––––––––––––––${none}"; }

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
[[ -z "$PKG_CMD" ]] && die "仅支持 ${yellow}apt-get${none} / ${yellow}yum${none} 系统"
}

# – 安装缺失依赖 ——————————————

install_pkg() {
local need=""
for i in "$@"; do
command -v "$i" &>/dev/null || need="$need $i"
done
if [[ -n "$need" ]]; then
msg warn "安装依赖:$need"
# shellcheck disable=SC2086
$PKG_CMD install -y $need &>/dev/null || {
[[ "$PKG_CMD" =~ yum ]] && yum install epel-release -y &>/dev/null
$PKG_CMD update -y &>/dev/null
# shellcheck disable=SC2086
$PKG_CMD install -y $need &>/dev/null || true
}
fi
}

# – wget 封装 ———————————————

_wget() {
[[ -n "${proxy:-}" ]] && export https_proxy=$proxy
wget –no-check-certificate "$@"
}

# – 获取公网 IP —————————————––

get_server_ip() {
SERVER_IP=""
local trace
trace=$(_wget -4 -qO- https://one.one.one.one/cdn-cgi/trace 2>/dev/null | grep "^ip=" || true)
[[ -n "$trace" ]] && SERVER_IP="${trace#ip=}"
[[ -z "$SERVER_IP" ]] &&   
SERVER_IP=$(curl -fsSL –max-time 6 https://api4.ipify.org 2>/dev/null || true)
[[ -z "$SERVER_IP" ]] &&   
SERVER_IP=$(curl -fsSL –max-time 6 https://ifconfig.me 2>/dev/null || true)
[[ -z "$SERVER_IP" ]] && SERVER_IP="YOUR_SERVER_IP"
}

# – 初始化检查 ––––––––––––––––––––––

preflight() {
[[ $EUID -ne 0 ]] && die "当前非 ${yellow}ROOT${none} 用户"
[[ ! $(type -P systemctl) ]] && die "系统缺少 ${yellow}systemctl${none}"
detect_arch
detect_pkg_manager
install_pkg jq curl wget xxd unzip

```
# 建立 xrv 快捷方式
if [[ ! -L "$SYMLINK" ]] || [[ "$(readlink -f "$SYMLINK")" != "$SCRIPT_PATH" ]]; then
    ln -sf "$SCRIPT_PATH" "$SYMLINK"
    chmod +x "$SCRIPT_PATH"
    info "快捷方式 ${cyan}xrv${none} 已绑定 → $SCRIPT_PATH"
fi
```

}

# – 配置文件合法性检查 + null 自动修复 —————––

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
# 检查并修复 VLESS clients 为 null
local vless_count
vless_count=$(jq '[.inbounds[]? | select(.protocol=="vless")] | length' "$CONFIG" 2>/dev/null || echo 0)
if [[ "$vless_count" -gt 0 ]]; then
local cn
cn=$(jq -r '(.inbounds[]? | select(.protocol=="vless") | .settings.clients) // "null"'   
"$CONFIG" 2>/dev/null | head -1)
if [[ "$cn" == "null" ]]; then
warn "VLESS clients 为 null，自动修复…"
_safe_jq_write   
'(.inbounds[] | select(.protocol=="vless") | .settings.clients) = []' || return 1
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

# – 安全 jq 写入（原子替换 + 自动备份）——————

*safe_jq_write() {
local filter="$1"
local tmp; tmp=$(mktemp /tmp/xray_cfg_XXXXXX.json)
local bak="${CONFIG}.bak.$(date +%Y%m%d*%H%M%S)"

```
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
```

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

# – 生成 x25519 密钥对 ————————————

# 输出到全局变量 X25519_PRIV / X25519_PUB

gen_x25519() {
if [[ ! -x "$XRAY_BIN" ]]; then
die "xray 二进制不存在，无法生成密钥对: $XRAY_BIN"
fi
local keys
keys=$("$XRAY_BIN" x25519 2>/dev/null)
X25519_PRIV=$(echo "$keys" | grep "Private key" | awk '{print $3}')
X25519_PUB=$(echo "$keys"  | grep "Public key"  | awk '{print $3}')
if [[ -z "$X25519_PRIV" || -z "$X25519_PUB" ]]; then
die "x25519 密钥对生成失败，输出为空"
fi
}

# 由私钥推导公钥

derive_pubkey() {
local priv="$1"
[[ ! -x "$XRAY_BIN" ]] && echo "" && return
"$XRAY_BIN" x25519 -i "$priv" 2>/dev/null | grep "Public key" | awk '{print $3}'
}

# – 写入 update-dat.sh + cron —————————–

install_update_dat() {
mkdir -p "$SCRIPT_DIR" "$LOG_DIR"
cat > "$UPDATE_DAT_SCRIPT" <<'UPDSH'
#!/usr/bin/env bash
set -e
XRAY_DAT_DIR="/usr/local/share/xray"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat"
mkdir -p "$XRAY_DAT_DIR" && cd "$XRAY_DAT_DIR"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 更新 geoip.dat…"
curl -fsSL -o geoip.dat.new   "$GEOIP_URL"   && mv -f geoip.dat.new   geoip.dat
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 更新 geosite.dat…"
curl -fsSL -o geosite.dat.new "$GEOSITE_URL" && mv -f geosite.dat.new geosite.dat
echo "[$(date '+%Y-%m-%d %H:%M:%S')] dat 更新完成"
systemctl -q is-active xray && systemctl restart xray   
&& echo "[$(date '+%Y-%m-%d %H:%M:%S')] Xray 已重启"
UPDSH
chmod +x "$UPDATE_DAT_SCRIPT"
local job="0 3 * * * $UPDATE_DAT_SCRIPT >> $LOG_DIR/update-dat.log 2>&1"
if ! crontab -l 2>/dev/null | grep -qF "$UPDATE_DAT_SCRIPT"; then
(crontab -l 2>/dev/null; echo "$job") | crontab -
info "cron 任务已添加：每天 03:00 自动更新 dat"
else
info "cron 任务已存在"
fi
}

# – 立即下载 dat ——————————————

download_dat_now() {
mkdir -p "$DAT_DIR"
msg warn "下载 geoip.dat…"
if curl -fsSL -o "$DAT_DIR/geoip.dat.new" "$GEOIP_URL"; then
mv -f "$DAT_DIR/geoip.dat.new" "$DAT_DIR/geoip.dat"
msg ok "geoip.dat 完成"
else
error "geoip.dat 下载失败"
fi
msg warn "下载 geosite.dat…"
if curl -fsSL -o "$DAT_DIR/geosite.dat.new" "$GEOSITE_URL"; then
mv -f "$DAT_DIR/geosite.dat.new" "$DAT_DIR/geosite.dat"
msg ok "geosite.dat 完成"
else
error "geosite.dat 下载失败"
fi
}

# – 生成 VLESS-Reality config.json ———————–

# 用法: _gen_vless_config port uuid priv pub sid dest sni

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
{"tag_id":"cn",  "type":"field","ip":["geoip:cn"],        "outboundTag":"block","_enabled":true},
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

# – 生成纯 SS config.json ———————————

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
{"tag_id":"cn",  "type":"field","ip":["geoip:cn"],        "outboundTag":"block","_enabled":true},
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

# – 追加 SS inbound —————————————

_append_ss_inbound() {
local port="$1" pass="$2" method="$3"
_safe_jq_write   
".inbounds += [{
"tag": "shadowsocks",
"listen": "0.0.0.0",
"port": ${port},
"protocol": "shadowsocks",
"settings": {
"method": "${method}",
"password": "${pass}",
"network": "tcp,udp"
}
}]"
}

# – 打印 VLESS 链接 —————————————

print_vless_link() {
local uuid="$1" port="$2" sni="$3" priv="$4" sid="$5" label="${6:-xray-reality}"
# 优先从 config 读取已存储的公钥，否则实时推导
local pub
pub=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.publicKey // ""'   
"$CONFIG" 2>/dev/null | head -1)
[[ -z "$pub" ]] && pub=$(derive_pubkey "$priv")

```
get_server_ip
local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp&headerType=none#${label}"
hr
_cyan "  VLESS-Reality 连接参数"
hr
printf "  ${yellow}%-16s${none} %s\n" "服务器 IP:"   "$SERVER_IP"
printf "  ${yellow}%-16s${none} %s\n" "端口:"        "$port"
printf "  ${yellow}%-16s${none} %s\n" "UUID:"        "$uuid"
printf "  ${yellow}%-16s${none} %s\n" "Flow:"        "xtls-rprx-vision"
printf "  ${yellow}%-16s${none} %s\n" "传输:"        "tcp"
printf "  ${yellow}%-16s${none} %s\n" "安全:"        "reality"
printf "  ${yellow}%-16s${none} %s\n" "SNI:"         "$sni"
printf "  ${yellow}%-16s${none} %s\n" "Fingerprint:" "chrome"
printf "  ${yellow}%-16s${none} %s\n" "公钥(pbk):"  "$pub"
printf "  ${yellow}%-16s${none} %s\n" "Short ID:"   "$sid"
hr
echo ""
_green "  vless:// 链接（clash / v2rayN / sing-box / Shadowrocket）："
echo ""
echo -e "  ${cyan}${link}${none}"
echo ""
hr
```

}

# – 打印 SS 链接 ——————————————

print_ss_link() {
local pass="$1" method="$2" port="$3" label="${4:-xray-ss}"
get_server_ip
local b64; b64=$(printf '%s' "${method}:${pass}" | base64 | tr -d '\n')
local link="ss://${b64}@${SERVER_IP}:${port}#${label}"
hr
_cyan "  Shadowsocks 连接参数"
hr
printf "  ${yellow}%-16s${none} %s\n" "服务器 IP:"  "$SERVER_IP"
printf "  ${yellow}%-16s${none} %s\n" "端口:"       "$port"
printf "  ${yellow}%-16s${none} %s\n" "密码:"       "$pass"
printf "  ${yellow}%-16s${none} %s\n" "加密方式:"   "$method"
hr
echo ""
_green "  ss:// 链接："
echo ""
echo -e "  ${cyan}${link}${none}"
echo ""
hr
}

# – 端口输入校验 ——————————————

input_port() {
local prompt="$1" default="${2:-}"
local p
while true; do
if [[ -n "$default" ]]; then
read -rp "${prompt} [${default}]: " p
[[ -z "$p" ]] && p="$default"
else
read -rp "${prompt}: " p
fi
if [[ "$p" =~ ^[0-9]+$ ]] && (( p >= 1 && p <= 65535 )); then
break
fi
error "端口无效，范围 1-65535"
done
echo "$p"
}

# – 域名输入校验 ——————————————

input_domain() {
local d
while true; do
read -rp "输入目标域名（如 www.microsoft.com）: " d
[[ -n "$d" ]] && break
error "域名不能为空"
done
echo "$d"
}

# – SS 加密方式选择（独立函数，输出到变量避免 echo 污染）-

_select_ss_method() {
# 用全局变量传出，避免子 shell echo 污染
echo "  选择 SS 加密方式：" >&2
echo "  1) aes-256-gcm（推荐）" >&2
echo "  2) aes-128-gcm" >&2
echo "  3) chacha20-ietf-poly1305" >&2
echo "  4) 2022-blake3-aes-256-gcm" >&2
local mc
read -rp "  编号 [1]: " mc >&2 || true
case "${mc:-1}" in
2) SS_METHOD="aes-128-gcm" ;;
3) SS_METHOD="chacha20-ietf-poly1305" ;;
4) SS_METHOD="2022-blake3-aes-256-gcm" ;;
*) SS_METHOD="aes-256-gcm" ;;
esac
echo "$SS_METHOD"
}

# – 打印所有协议链接 –––––––––––––––––––

_print_all_links() {
[[ ! -f "$CONFIG" ]] && return

```
local vless_count
vless_count=$(jq '[.inbounds[]? | select(.protocol=="vless")] | length' "$CONFIG" 2>/dev/null || echo 0)
if [[ "$vless_count" -gt 0 ]]; then
    local v_port v_uuid v_priv v_sid v_sni
    v_port=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .port' "$CONFIG" | head -1)
    v_uuid=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .settings.clients[0].id' "$CONFIG" | head -1)
    v_priv=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.privateKey' "$CONFIG" | head -1)
    v_sid=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.shortIds[0]' "$CONFIG" | head -1)
    v_sni=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0]' "$CONFIG" | head -1)
    print_vless_link "$v_uuid" "$v_port" "$v_sni" "$v_priv" "$v_sid"
fi

local ss_count
ss_count=$(jq '[.inbounds[]? | select(.protocol=="shadowsocks")] | length' "$CONFIG" 2>/dev/null || echo 0)
if [[ "$ss_count" -gt 0 ]]; then
    local s_port s_pass s_method
    s_port=$(jq -r '.inbounds[]? | select(.protocol=="shadowsocks") | .port' "$CONFIG" | head -1)
    s_pass=$(jq -r '.inbounds[]? | select(.protocol=="shadowsocks") | .settings.password' "$CONFIG" | head -1)
    s_method=$(jq -r '.inbounds[]? | select(.protocol=="shadowsocks") | .settings.method' "$CONFIG" | head -1)
    print_ss_link "$s_pass" "$s_method" "$s_port"
fi
```

}

# – 获取 VLESS inbound 在 inbounds 数组里的索引 –––––

_get_vless_idx() {
jq '[.inbounds | to_entries[] | select(.value.protocol=="vless")] | .[0].key' "$CONFIG" 2>/dev/null
}

# – 获取 SS inbound 在 inbounds 数组里的索引 ———––

_get_ss_idx() {
jq '[.inbounds | to_entries[] | select(.value.protocol=="shadowsocks")] | .[0].key' "$CONFIG" 2>/dev/null
}

# +==========================================================+

# |                   1. 安装 / 重装                         |

# +==========================================================+

do_install() {
title "安装 / 重装 Xray"

```
if systemctl is-active --quiet xray 2>/dev/null; then
    warn "检测到 Xray 正在运行"
    read -rp "重装将覆盖二进制文件，配置保留。继续? [y/N]: " c
    [[ "$c" != "y" ]] && warn "已取消" && return
fi

# 选择协议
echo ""
echo "  请选择要安装的协议："
echo "  1) VLESS-Reality（推荐，抗封锁）"
echo "  2) Shadowsocks"
echo "  3) 两个都安装"
hr
read -rp "  输入编号 [1-3]: " proto_choice
[[ ! "$proto_choice" =~ ^[1-3]$ ]] && error "无效选项" && return

# 安装 Xray 核心
msg warn "下载并安装 Xray 核心..."
bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
msg ok "Xray 核心安装完成"

echo ""
msg warn "开始初始化配置..."

case "$proto_choice" in
    1)
        _init_vless_config
        ;;
    2)
        _init_ss_config
        ;;
    3)
        _init_vless_config
        echo ""
        msg warn "继续配置 Shadowsocks..."
        local ss_port ss_pass ss_method
        ss_port=$(input_port "SS 监听端口" "8388")
        ss_pass=$(gen_ss_pass)
        ss_method=$(_select_ss_method)
        _append_ss_inbound "$ss_port" "$ss_pass" "$ss_method"
        msg ok "Shadowsocks 已追加"
        ;;
esac

# 安装 update-dat.sh + cron
msg warn "安装 dat 自动更新脚本..."
install_update_dat

# 立即下载 dat
msg warn "下载 geo 规则文件..."
download_dat_now

# 开机自启 + 启动
systemctl enable xray &>/dev/null
systemctl restart xray
msg ok "Xray 已开机自启并已启动"

# 输出所有连接信息
echo ""
title "安装完成 — 连接信息"
_print_all_links

echo ""
read -rp "按 Enter 返回主菜单..." _
```

}

# 引导 VLESS-Reality 配置

_init_vless_config() {
local port uuid priv pub sid dest sni

```
port=$(input_port "VLESS 监听端口" "443")
dest=$(input_domain)
read -rp "SNI（留空同目标域名 [$dest]）: " sni
[[ -z "$sni" ]] && sni="$dest"

msg warn "生成 x25519 密钥对..."
gen_x25519                 # 写入 X25519_PRIV / X25519_PUB
priv="$X25519_PRIV"
pub="$X25519_PUB"

uuid=$(gen_uuid)
sid=$(gen_short_id)

# 写入配置（公钥私钥都存入）
_gen_vless_config "$port" "$uuid" "$priv" "$pub" "$sid" "$dest" "$sni"

msg ok "VLESS-Reality 配置已生成"
hr
printf "  %-16s %s\n" "端口:"     "$port"
printf "  %-16s %s\n" "目标域名:" "$dest:443"
printf "  %-16s %s\n" "SNI:"      "$sni"
printf "  %-16s %s\n" "UUID:"     "$uuid"
printf "  %-16s %s\n" "私钥:"     "$priv"
printf "  %-16s %s\n" "公钥:"     "$pub"
printf "  %-16s %s\n" "Short ID:" "$sid"
hr
```

}

# 引导纯 SS 配置

_init_ss_config() {
local port pass method
port=$(input_port "SS 监听端口" "8388")
pass=$(gen_ss_pass)
method=$(_select_ss_method)
_gen_ss_config "$port" "$pass" "$method"
msg ok "Shadowsocks 配置已生成"
hr
printf "  %-14s %s\n" "端口:"     "$port"
printf "  %-14s %s\n" "密码:"     "$pass"
printf "  %-14s %s\n" "加密方式:" "$method"
hr
}

# +==========================================================+

# |                   2. 更新 Xray 核心                      |

# +==========================================================+

do_upgrade_core() {
title "更新 Xray 核心"

```
local cur_ver=""
[[ -x "$XRAY_BIN" ]] && cur_ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 || echo "未知")
echo ""
printf "  当前版本: ${yellow}%s${none}\n" "$cur_ver"
echo ""

msg warn "获取版本列表..."
local versions
versions=$(curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases \
    | grep '"tag_name"' | cut -d'"' -f4 | head -n 15)
if [[ -z "$versions" ]]; then
    error "获取版本列表失败，请检查网络"; return
fi

echo "  最近 15 个版本："
hr
local i=1
local ver_arr=()
while IFS= read -r v; do
    printf "  ${cyan}%2d${none}) %s\n" "$i" "$v"
    ver_arr+=("$v")
    ((i++))
done <<< "$versions"
hr
echo ""
read -rp "  输入编号选择版本（留空取消）: " sel
[[ -z "$sel" ]] && warn "已取消" && return
if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > ${#ver_arr[@]} )); then
    error "无效编号"; return
fi

local VERSION="${ver_arr[$((sel-1))]}"
echo ""
read -rp "  确认升级到 ${yellow}${VERSION}${none}? [y/N]: " confirm
[[ "$confirm" != "y" ]] && warn "已取消" && return

bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" \
    @ install -u root -v "$VERSION"
systemctl enable xray &>/dev/null
systemctl restart xray
msg ok "已升级到 $VERSION，Xray 已重启"

echo ""
read -rp "按 Enter 返回主菜单..." _
```

}

# +==========================================================+

# |                   3. 立即更新 geo 规则                   |

# +==========================================================+

do_update_dat() {
title "立即更新 geo 规则"
if [[ ! -f "$UPDATE_DAT_SCRIPT" ]]; then
warn "update-dat.sh 不存在，正在创建…"
install_update_dat
fi
bash "$UPDATE_DAT_SCRIPT"
msg ok "dat 规则更新完成"
echo ""
read -rp "按 Enter 返回主菜单…" _
}

# +==========================================================+

# |          4. 查看运行状态（xray / IP / DNS / 流量）       |

# +==========================================================+

do_status_menu() {
while true; do
title "查看运行状态"
echo "  1) Xray 服务状态"
echo "  2) 实时 IP 连接 & DNS 管理"
echo "  3) 流量统计（vnstat）"
echo "  f) 返回主菜单"
hr
read -rp "选择: " s
case "$s" in
1) systemctl status xray –no-pager || true ;;
2) _status_ip_dns ;;
3) _status_traffic ;;
f|F|0) return ;;
*) warn "无效选项" ;;
esac
echo ""
read -rp "按 Enter 继续…" _
done
}

_status_ip_dns() {
title "IP 连接 & DNS 信息"
get_server_ip
echo ""
printf "  ${yellow}%-18s${none} %s\n" "服务器公网 IP:" "$SERVER_IP"

```
echo ""
_cyan "  当前 DNS 配置："
hr
grep "^nameserver" /etc/resolv.conf 2>/dev/null || echo "  无 nameserver 配置"
hr

echo ""
_cyan "  端口监听情况："
hr
if command -v ss &>/dev/null; then
    local conn
    conn=$(ss -tnp 2>/dev/null | grep -c "xray" 2>/dev/null || echo 0)
    printf "  xray 进程连接数: ${green}%s${none}\n\n" "$conn"
    ss -tlnp 2>/dev/null | grep "LISTEN" | head -20 || true
else
    netstat -tlnp 2>/dev/null | grep "LISTEN" | head -20 || true
fi
hr

echo ""
echo "  DNS 操作："
echo "  1) 查看完整 resolv.conf"
echo "  2) 永久修改 DNS"
echo "  0) 返回"
read -rp "选择: " d
case "$d" in
    1) echo ""; cat /etc/resolv.conf ;;
    2)
        echo ""
        echo "  推荐 DNS："
        echo "  1) 1.1.1.1 + 1.0.0.1（Cloudflare）"
        echo "  2) 8.8.8.8 + 8.8.4.4（Google）"
        echo "  3) 手动输入"
        read -rp "  选择: " dc
        local dns1="" dns2=""
        case "$dc" in
            1) dns1="1.1.1.1"; dns2="1.0.0.1" ;;
            2) dns1="8.8.8.8"; dns2="8.8.4.4" ;;
            3)
                read -rp "  主 DNS: " dns1
                read -rp "  备 DNS: " dns2
                ;;
            *) warn "已取消"; return ;;
        esac
        chattr -i /etc/resolv.conf 2>/dev/null || true
        {
            echo "nameserver $dns1"
            [[ -n "$dns2" ]] && echo "nameserver $dns2"
        } > /etc/resolv.conf
        chattr +i /etc/resolv.conf 2>/dev/null || true
        info "DNS 已设置: $dns1 / ${dns2} （已锁定防覆盖）"
        ;;
esac
```

}

_status_traffic() {
title "流量统计"
if ! command -v vnstat &>/dev/null; then
warn "vnstat 未安装，正在自动安装…"
install_pkg vnstat
systemctl enable vnstat &>/dev/null
systemctl start vnstat &>/dev/null
msg ok "vnstat 已安装并启动（需收集一段时间数据后方可显示统计）"
fi

```
local iface
iface=$(ip route show default 2>/dev/null | awk '/default/{print $5}' | head -1)
[[ -z "$iface" ]] && iface=$(ls /sys/class/net/ 2>/dev/null | grep -v "^lo$" | head -1)

echo ""
_cyan "  流量统计 — 网卡: ${yellow}${iface}${none}"
hr

# 月统计起始日
mkdir -p "$SCRIPT_DIR"
local stat_file="$SCRIPT_DIR/traffic_start_day"
local start_day
if [[ -f "$stat_file" ]]; then
    start_day=$(cat "$stat_file")
else
    warn "未设置每月流量统计起始日"
    read -rp "请输入每月起始日（1-28）: " start_day
    if [[ "$start_day" =~ ^([1-9]|[12][0-9]|28)$ ]]; then
        echo "$start_day" > "$stat_file"
        info "起始日已保存: 每月 ${start_day} 日"
    else
        error "无效日期，使用默认值 1"
        start_day=1
    fi
fi

echo "  月统计起始日: 每月 ${yellow}${start_day}${none} 日"
echo ""

if command -v vnstat &>/dev/null; then
    echo "  本月流量（vnstat）："
    hr
    vnstat -i "$iface" --oneline 2>/dev/null | awk -F';' '{
        if (NF>=10) printf "  发送: %s\n  接收: %s\n  总计: %s\n", $9, $8, $10
    }' || vnstat -i "$iface" 2>/dev/null | tail -20 || true
    hr
    echo ""
    echo "  月度详细统计："
    vnstat -i "$iface" -m 2>/dev/null | tail -20 || true
fi

echo ""
echo "  操作："
echo "  1) 修改月统计起始日"
echo "  2) 查看日统计"
echo "  3) 查看实时流量"
echo "  0) 返回"
read -rp "选择: " tc
case "$tc" in
    1)
        read -rp "新起始日（1-28）: " nd
        if [[ "$nd" =~ ^([1-9]|[12][0-9]|28)$ ]]; then
            echo "$nd" > "$stat_file"
            info "已更新为每月 $nd 日"
        else
            error "无效日期"
        fi
        ;;
    2) vnstat -i "$iface" -d 2>/dev/null | tail -20 || true ;;
    3) vnstat -i "$iface" -l 2>/dev/null || true ;;
esac
```

}

# +==========================================================+

# |                5. 用户管理（VLESS clients）               |

# +==========================================================+

do_user_menu() {
while true; do
title "用户管理"
if ! check_config; then
read -rp "按 Enter 返回…" _; return
fi
echo "  1) 查看用户"
echo "  2) 新增用户"
echo "  3) 修改用户"
echo "  4) 删除用户"
echo "  f) 返回主菜单"
hr
read -rp "选择: " u
case "$u" in
1) _list_users  ;;
2) _add_user    ;;
3) _modify_user ;;
4) _delete_user ;;
f|F|0) return   ;;
*) warn "无效选项" ;;
esac
echo ""
read -rp "按 Enter 继续…" _
done
}

_vless_client_count() {
jq '[.inbounds[]? | select(.protocol=="vless") | .settings.clients[]?] | length'   
"$CONFIG" 2>/dev/null || echo 0
}

_list_users() {
title "当前 VLESS 用户"
local count; count=$(_vless_client_count)
if [[ "$count" -eq 0 ]]; then
warn "暂无用户"; return 1
fi
printf "  ${cyan}%-4s %-38s %-20s${none}\n" "No." "UUID" "Flow"
hr
jq -r '.inbounds[]? | select(.protocol=="vless") | .settings.clients[]? | "(.id) (.flow // "无")"'   
"$CONFIG" 2>/dev/null | awk '{printf "  %-4d %-38s %-20s\n", NR, $1, $2}'
hr
info "共 $count 个用户"
return 0
}

_add_user() {
title "新增 VLESS 用户"

```
# 可选修改端口
local cur_port
cur_port=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .port' "$CONFIG" | head -1)
echo "  当前 VLESS 端口: ${yellow}${cur_port}${none}"
read -rp "  是否修改端口? [y/N]: " cp_ans
if [[ "$cp_ans" == "y" ]]; then
    local np; np=$(input_port "新端口" "$cur_port")
    local vidx; vidx=$(_get_vless_idx)
    _safe_jq_write ".inbounds[$vidx].port = $np" || return
    info "端口已更新: $cur_port → $np"
fi

local uuid sid
uuid=$(gen_uuid)
sid=$(gen_short_id)
local vidx; vidx=$(_get_vless_idx)

_safe_jq_write \
    ".inbounds[$vidx].settings.clients += [{\"id\":\"${uuid}\",\"flow\":\"xtls-rprx-vision\"}] |
     .inbounds[$vidx].streamSettings.realitySettings.shortIds += [\"${sid}\"]" \
    || return

systemctl restart xray
info "新增用户成功"
hr
printf "  %-12s %s\n" "UUID:"     "$uuid"
printf "  %-12s %s\n" "Short ID:" "$sid"
hr

# 输出完整链接
local v_port v_priv v_sni
v_port=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .port' "$CONFIG" | head -1)
v_priv=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.privateKey' "$CONFIG" | head -1)
v_sni=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0]' "$CONFIG" | head -1)
print_vless_link "$uuid" "$v_port" "$v_sni" "$v_priv" "$sid"
```

}

_modify_user() {
title "修改 VLESS 用户"
_list_users || return
local count; count=$(_vless_client_count)

```
read -rp "输入用户序号（留空取消）: " sel
[[ -z "$sel" ]] && warn "已取消" && return
if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > count )); then
    error "无效序号"; return
fi
local idx=$(( sel - 1 ))
local old_uuid
old_uuid=$(jq -r ".inbounds[]? | select(.protocol==\"vless\") | .settings.clients[$idx].id" \
           "$CONFIG" 2>/dev/null | head -1)

read -rp "重新生成 UUID? [y/N]: " ru
local new_uuid="$old_uuid"
[[ "$ru" == "y" ]] && new_uuid=$(gen_uuid)

read -rp "追加新 Short ID? [y/N]: " rs
local vidx; vidx=$(_get_vless_idx)
local filter
filter=".inbounds[$vidx].settings.clients[$idx].id = \"$new_uuid\""
if [[ "$rs" == "y" ]]; then
    local new_sid; new_sid=$(gen_short_id)
    filter+=" | .inbounds[$vidx].streamSettings.realitySettings.shortIds += [\"$new_sid\"]"
    info "新 Short ID: $new_sid"
fi

_safe_jq_write "$filter" || return
systemctl restart xray
info "修改完成 — UUID: $new_uuid"
```

}

_delete_user() {
title "删除 VLESS 用户"
_list_users || return
local count; count=$(_vless_client_count)

```
read -rp "输入要删除的用户序号（留空取消）: " sel
[[ -z "$sel" ]] && warn "已取消" && return
if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > count )); then
    error "无效序号"; return
fi
local idx=$(( sel - 1 ))
local del_uuid
del_uuid=$(jq -r ".inbounds[]? | select(.protocol==\"vless\") | .settings.clients[$idx].id" \
           "$CONFIG" 2>/dev/null | head -1)

read -rp "确认删除用户 #${sel} (${del_uuid})? [y/N]: " confirm
[[ "$confirm" != "y" ]] && warn "已取消" && return

local vidx; vidx=$(_get_vless_idx)
_safe_jq_write "del(.inbounds[$vidx].settings.clients[$idx])" || return
systemctl restart xray
info "已删除用户 #${sel}: $del_uuid"
```

}

# +==========================================================+

# |                  6. 全局配置管理                          |

# +==========================================================+

do_global_menu() {
while true; do
title "全局配置管理"
if ! check_config; then
read -rp "按 Enter 返回…" _; return
fi
echo "  1) 修改监听端口"
echo "  2) 修改目标域名 / SNI"
echo "  3) 重新生成 x25519 密钥对"
echo "  4) 重新生成 Short ID"
echo "  5) Block 规则独立开关（BT / CN-IP / 广告）"
echo "  6) 查看完整配置文件"
echo "  7) 还原配置备份"
echo "  f) 返回主菜单"
hr
read -rp "选择: " g
case "$g" in
1) _global_port        ;;
2) _global_domain      ;;
3) _global_regen_key   ;;
4) _global_regen_sid   ;;
5) _global_block_rules ;;
6) jq . "$CONFIG"      ;;
7) _restore_backup     ;;
f|F|0) return          ;;
*) warn "无效选项"     ;;
esac
echo ""
read -rp "按 Enter 继续…" _
done
}

_global_port() {
local vidx; vidx=$(_get_vless_idx)
local cur; cur=$(jq -r ".inbounds[$vidx].port" "$CONFIG")
echo "  当前 VLESS 端口: ${yellow}${cur}${none}"
local np; np=$(input_port "新端口" "$cur")
_safe_jq_write ".inbounds[$vidx].port = $np" || return
systemctl restart xray
info "端口已更改: $cur → $np"
}

_global_domain() {
local vidx; vidx=$(_get_vless_idx)
local cur_dest cur_sni
cur_dest=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.dest" "$CONFIG")
cur_sni=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.serverNames[0]" "$CONFIG")
echo "  当前目标域名: ${yellow}${cur_dest}${none}"
echo "  当前 SNI:     ${yellow}${cur_sni}${none}"
echo ""
local nd; nd=$(input_domain)
read -rp "SNI（留空同域名 [$nd]）: " ns
[[ -z "$ns" ]] && ns="$nd"
_safe_jq_write   
".inbounds[$vidx].streamSettings.realitySettings.dest = "${nd}:443" |
.inbounds[$vidx].streamSettings.realitySettings.serverNames = ["$ns"]" || return
systemctl restart xray
info "域名已更新 → $nd:443 | SNI: $ns"
}

_global_regen_key() {
local vidx; vidx=$(_get_vless_idx)
[[ ! -x "$XRAY_BIN" ]] && error "xray 二进制不存在" && return
warn "重新生成密钥后，所有客户端需同步更新公钥！"
read -rp "确认? [y/N]: " c
[[ "$c" != "y" ]] && warn "已取消" && return

```
gen_x25519   # 写入 X25519_PRIV / X25519_PUB

_safe_jq_write \
    ".inbounds[$vidx].streamSettings.realitySettings.privateKey = \"$X25519_PRIV\" |
     .inbounds[$vidx].streamSettings.realitySettings.publicKey  = \"$X25519_PUB\"" || return
systemctl restart xray
info "密钥已更新"
hr
printf "  %-8s %s\n" "私钥:" "$X25519_PRIV"
printf "  %-8s %s\n" "公钥:" "$X25519_PUB"
hr
warn "请将公钥更新到所有客户端！"
```

}

_global_regen_sid() {
local vidx; vidx=$(_get_vless_idx)
local cur_ids
cur_ids=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.shortIds | join(", ")" "$CONFIG" 2>/dev/null)
echo "  当前 Short IDs: ${yellow}${cur_ids}${none}"
echo ""
echo "  1) 追加一个新 Short ID"
echo "  2) 替换全部 Short ID（重置）"
echo "  0) 取消"
read -rp "选择: " opt
local new_sid; new_sid=$(gen_short_id)
case "$opt" in
1)
_safe_jq_write   
".inbounds[$vidx].streamSettings.realitySettings.shortIds += ["$new_sid"]" || return
info "已追加 Short ID: $new_sid"
;;
2)
warn "替换后客户端需同步更新 Short ID"
read -rp "确认? [y/N]: " c
[[ "$c" != "y" ]] && warn "已取消" && return
_safe_jq_write   
".inbounds[$vidx].streamSettings.realitySettings.shortIds = ["$new_sid"]" || return
info "Short ID 已重置: $new_sid"
;;
0) warn "已取消"; return ;;
*) warn "无效选项"; return ;;
esac
systemctl restart xray
}

# Block 规则独立开关

_global_block_rules() {
title "Block 规则独立开关"
while true; do
local bt_en cn_en ads_en
bt_en=$(jq -r  '.routing.rules[]? | select(.tag_id=="bt")  | ._enabled' "$CONFIG" 2>/dev/null || echo "false")
cn_en=$(jq -r  '.routing.rules[]? | select(.tag_id=="cn")  | ._enabled' "$CONFIG" 2>/dev/null || echo "false")
ads_en=$(jq -r '.routing.rules[]? | select(.tag_id=="ads") | ._enabled' "$CONFIG" 2>/dev/null || echo "false")

```
    local s_bt s_cn s_ads
    [[ "$bt_en"  == "true" ]] && s_bt="${green}[开]${none}"  || s_bt="${red}[关]${none}"
    [[ "$cn_en"  == "true" ]] && s_cn="${green}[开]${none}"  || s_cn="${red}[关]${none}"
    [[ "$ads_en" == "true" ]] && s_ads="${green}[开]${none}" || s_ads="${red}[关]${none}"

    echo ""
    echo -e "  1) BT / 下载流量屏蔽     $s_bt  （防 GFW 封禁）"
    echo -e "  2) 中国 IP 屏蔽           $s_cn  （防流量溯源）"
    echo -e "  3) 广告域名屏蔽           $s_ads"
    echo "  0) 返回"
    hr
    read -rp "  输入编号切换开关: " bc

    local tag new_val
    case "$bc" in
        1) tag="bt";  [[ "$bt_en"  == "true" ]] && new_val="false" || new_val="true" ;;
        2) tag="cn";  [[ "$cn_en"  == "true" ]] && new_val="false" || new_val="true" ;;
        3) tag="ads"; [[ "$ads_en" == "true" ]] && new_val="false" || new_val="true" ;;
        0) return ;;
        *) warn "无效选项"; continue ;;
    esac

    _safe_jq_write \
        "(.routing.rules[] | select(.tag_id==\"$tag\") | ._enabled) = $new_val" || continue
    systemctl restart xray
    [[ "$new_val" == "true" ]] && info "$tag 屏蔽已启用" || info "$tag 屏蔽已关闭"
done
```

}

*restore_backup() {
local backups
backups=$(ls -t "${CONFIG}.bak."* 2>/dev/null || true)
if [[ -z "$backups" ]]; then
warn "没有找到任何备份文件"; return
fi
echo "  可用备份（从新到旧）："
hr
local i=1
local bak_list=()
while IFS= read -r bak; do
local bt; bt=$(stat -c "%y" "$bak" 2>/dev/null | cut -d'.' -f1 || echo "未知")
printf "  ${cyan}%d${none}. %-45s [%s]\n" "$i" "$(basename "$bak")" "$bt"
bak_list+=("$bak")
((i++))
done <<< "$backups"
hr
read -rp "选择序号（留空取消）: " sel
[[ -z "$sel" ]] && warn "已取消" && return
if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > ${#bak_list[@]} )); then
error "无效序号"; return
fi
local chosen="${bak_list[$((sel-1))]}"
read -rp "确认还原 $(basename "$chosen")? [y/N]: " c
[[ "$c" != "y" ]] && warn "已取消" && return
cp "$CONFIG" "${CONFIG}.before_restore.$(date +%Y%m%d*%H%M%S)"
cp "$chosen" "$CONFIG"
systemctl restart xray
info "已还原并重启 Xray"
}

# +==========================================================+

# |                   7. 查看配置摘要                         |

# +==========================================================+

do_summary() {
title "配置摘要"
if [[ ! -f "$CONFIG" ]]; then
warn "配置文件不存在"; return
fi

```
# VLESS
local vc; vc=$(jq '[.inbounds[]? | select(.protocol=="vless")] | length' "$CONFIG" 2>/dev/null || echo 0)
if [[ "$vc" -gt 0 ]]; then
    local v_port v_dest v_sni v_priv v_pub v_sids v_ucount
    local vidx; vidx=$(_get_vless_idx)
    v_port=$(jq -r   ".inbounds[$vidx].port" "$CONFIG")
    v_dest=$(jq -r   ".inbounds[$vidx].streamSettings.realitySettings.dest" "$CONFIG")
    v_sni=$(jq -r    ".inbounds[$vidx].streamSettings.realitySettings.serverNames[0]" "$CONFIG")
    v_priv=$(jq -r   ".inbounds[$vidx].streamSettings.realitySettings.privateKey" "$CONFIG")
    v_pub=$(jq -r    ".inbounds[$vidx].streamSettings.realitySettings.publicKey // \"\"" "$CONFIG")
    v_sids=$(jq -r   ".inbounds[$vidx].streamSettings.realitySettings.shortIds | join(\", \")" "$CONFIG")
    v_ucount=$(jq    ".inbounds[$vidx].settings.clients | length" "$CONFIG" 2>/dev/null || echo 0)

    # 公钥：优先读已存储，否则实时推导
    [[ -z "$v_pub" ]] && v_pub=$(derive_pubkey "$v_priv")

    _cyan "  VLESS-Reality"
    hr
    printf "  ${yellow}%-16s${none} %s\n" "监听端口:"  "$v_port"
    printf "  ${yellow}%-16s${none} %s\n" "目标域名:"  "$v_dest"
    printf "  ${yellow}%-16s${none} %s\n" "SNI:"       "$v_sni"
    printf "  ${yellow}%-16s${none} %s\n" "私钥:"      "$v_priv"
    printf "  ${yellow}%-16s${none} %s\n" "公钥:"      "$v_pub"
    printf "  ${yellow}%-16s${none} %s\n" "Short IDs:" "$v_sids"
    printf "  ${yellow}%-16s${none} %s\n" "用户数量:"  "$v_ucount"
    hr
fi

# SS
local sc; sc=$(jq '[.inbounds[]? | select(.protocol=="shadowsocks")] | length' "$CONFIG" 2>/dev/null || echo 0)
if [[ "$sc" -gt 0 ]]; then
    local sidx; sidx=$(_get_ss_idx)
    local s_port s_pass s_method
    s_port=$(jq -r ".inbounds[$sidx].port" "$CONFIG")
    s_pass=$(jq -r ".inbounds[$sidx].settings.password" "$CONFIG")
    s_method=$(jq -r ".inbounds[$sidx].settings.method" "$CONFIG")
    _cyan "  Shadowsocks"
    hr
    printf "  ${yellow}%-16s${none} %s\n" "监听端口:"  "$s_port"
    printf "  ${yellow}%-16s${none} %s\n" "加密方式:"  "$s_method"
    printf "  ${yellow}%-16s${none} %s\n" "密码:"      "$s_pass"
    hr
fi

# Block 规则
_cyan "  Block 规则状态"
hr
local bt_en cn_en ads_en
bt_en=$(jq -r  '.routing.rules[]? | select(.tag_id=="bt")  | ._enabled' "$CONFIG" 2>/dev/null || echo "false")
cn_en=$(jq -r  '.routing.rules[]? | select(.tag_id=="cn")  | ._enabled' "$CONFIG" 2>/dev/null || echo "false")
ads_en=$(jq -r '.routing.rules[]? | select(.tag_id=="ads") | ._enabled' "$CONFIG" 2>/dev/null || echo "false")
local _b; _b() { [[ "$1" == "true" ]] && echo -e "${green}启用${none}" || echo -e "${red}关闭${none}"; }
printf "  %-14s %s\n" "BT 屏蔽:"    "$(_b "$bt_en")"
printf "  %-14s %s\n" "CN-IP 屏蔽:" "$(_b "$cn_en")"
printf "  %-14s %s\n" "广告屏蔽:"   "$(_b "$ads_en")"
hr

# Xray 版本 + 服务状态
local xv="" sv
[[ -x "$XRAY_BIN" ]] && xv=$("$XRAY_BIN" version 2>/dev/null | head -n1 || echo "未知")
sv=$(systemctl is-active xray 2>/dev/null || echo "未运行")
printf "  ${yellow}%-16s${none} %s\n" "Xray 版本:" "$xv"
printf "  ${yellow}%-16s${none} %s\n" "服务状态:" "$sv"
hr
```

}

# +==========================================================+

# |                   8. 导出用户配置                         |

# +==========================================================+

do_export() {
title "导出用户配置"
check_config || return
_list_users || return
local count; count=$(_vless_client_count)

```
read -rp "输入要导出的用户序号（留空取消）: " sel
[[ -z "$sel" ]] && warn "已取消" && return
if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > count )); then
    error "无效序号"; return
fi
local idx=$(( sel - 1 ))
local vidx; vidx=$(_get_vless_idx)

local uuid port sni priv pub sid
uuid=$(jq -r ".inbounds[$vidx].settings.clients[$idx].id" "$CONFIG")
port=$(jq -r ".inbounds[$vidx].port" "$CONFIG")
sni=$(jq -r  ".inbounds[$vidx].streamSettings.realitySettings.serverNames[0]" "$CONFIG")
priv=$(jq -r ".inbounds[$vidx].streamSettings.realitySettings.privateKey" "$CONFIG")
pub=$(jq -r  ".inbounds[$vidx].streamSettings.realitySettings.publicKey // \"\"" "$CONFIG")
sid=$(jq -r  ".inbounds[$vidx].streamSettings.realitySettings.shortIds[0]" "$CONFIG")
[[ -z "$pub" ]] && pub=$(derive_pubkey "$priv")

print_vless_link "$uuid" "$port" "$sni" "$priv" "$sid" "xray-user-${sel}"

read -rp "保存到文件 /root/xray_user_${sel}.txt? [y/N]: " sv
if [[ "$sv" == "y" ]]; then
    get_server_ip
    local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp&headerType=none#xray-user-${sel}"
    {
        echo "=== Xray VLESS Reality 用户 #${sel} ==="
        echo "导出时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "服务器 IP:      $SERVER_IP"
        echo "端口:           $port"
        echo "UUID:           $uuid"
        echo "Flow:           xtls-rprx-vision"
        echo "传输:           tcp"
        echo "安全:           reality"
        echo "SNI:            $sni"
        echo "Fingerprint:    chrome"
        echo "私钥:           $priv"
        echo "公钥(pbk):      $pub"
        echo "Short ID:       $sid"
        echo ""
        echo "vless:// 链接:"
        echo "$link"
    } > "/root/xray_user_${sel}.txt"
    info "已保存至: /root/xray_user_${sel}.txt"
fi

echo ""
read -rp "按 Enter 返回主菜单..." _
```

}

# +==========================================================+

# |                  9. 协议管理（Shadowsocks）               |

# +==========================================================+

do_protocol_menu() {
while true; do
title "协议管理 — Shadowsocks"
if ! check_config; then
read -rp "按 Enter 返回…" _; return
fi
local ss_exists
ss_exists=$(jq '[.inbounds[]? | select(.protocol=="shadowsocks")] | length' "$CONFIG" 2>/dev/null || echo 0)
local ss_status
[[ "$ss_exists" -gt 0 ]] && ss_status="${green}已启用${none}" || ss_status="${red}未启用${none}"
echo -e "  Shadowsocks 状态: $ss_status"
echo ""
echo "  1) 添加 / 重新配置 Shadowsocks"
echo "  2) 查看 SS 连接信息"
echo "  3) 修改 SS 密码"
echo "  4) 修改 SS 端口"
echo "  5) 修改 SS 加密方式"
echo "  6) 删除 Shadowsocks"
echo "  f) 返回主菜单"
hr
read -rp "选择: " p
case "$p" in
1) _proto_add_ss    ;;
2) _proto_show_ss   ;;
3) _proto_ss_pass   ;;
4) _proto_ss_port   ;;
5) _proto_ss_method ;;
6) _proto_del_ss    ;;
f|F|0) return       ;;
*) warn "无效选项"  ;;
esac
echo ""
read -rp "按 Enter 继续…" _
done
}

_proto_add_ss() {
local ss_exists
ss_exists=$(jq '[.inbounds[]? | select(.protocol=="shadowsocks")] | length' "$CONFIG" 2>/dev/null || echo 0)
if [[ "$ss_exists" -gt 0 ]]; then
warn "Shadowsocks 已存在，将重新配置"
_safe_jq_write 'del(.inbounds[] | select(.protocol=="shadowsocks"))' || return
fi
local port pass method
port=$(input_port "SS 监听端口" "8388")
pass=$(gen_ss_pass)
method=$(_select_ss_method)
_append_ss_inbound "$port" "$pass" "$method" || return
systemctl restart xray
info "Shadowsocks 已配置"
print_ss_link "$pass" "$method" "$port"
}

_proto_show_ss() {
local sc; sc=$(jq '[.inbounds[]? | select(.protocol=="shadowsocks")] | length' "$CONFIG" 2>/dev/null || echo 0)
[[ "$sc" -eq 0 ]] && warn "Shadowsocks 未配置" && return
local sidx; sidx=$(_get_ss_idx)
local s_port s_pass s_method
s_port=$(jq -r ".inbounds[$sidx].port" "$CONFIG")
s_pass=$(jq -r ".inbounds[$sidx].settings.password" "$CONFIG")
s_method=$(jq -r ".inbounds[$sidx].settings.method" "$CONFIG")
print_ss_link "$s_pass" "$s_method" "$s_port"
}

_proto_ss_pass() {
local sc; sc=$(jq '[.inbounds[]? | select(.protocol=="shadowsocks")] | length' "$CONFIG" 2>/dev/null || echo 0)
[[ "$sc" -eq 0 ]] && warn "Shadowsocks 未配置" && return
local new_pass; new_pass=$(gen_ss_pass)
local sidx; sidx=$(_get_ss_idx)
_safe_jq_write ".inbounds[$sidx].settings.password = "$new_pass"" || return
systemctl restart xray
info "SS 密码已更新: $new_pass"
}

_proto_ss_port() {
local sc; sc=$(jq '[.inbounds[]? | select(.protocol=="shadowsocks")] | length' "$CONFIG" 2>/dev/null || echo 0)
[[ "$sc" -eq 0 ]] && warn "Shadowsocks 未配置" && return
local sidx; sidx=$(_get_ss_idx)
local cur_port; cur_port=$(jq -r ".inbounds[$sidx].port" "$CONFIG")
local np; np=$(input_port "新端口" "$cur_port")
_safe_jq_write ".inbounds[$sidx].port = $np" || return
systemctl restart xray
info "SS 端口已更改: $cur_port → $np"
}

_proto_ss_method() {
local sc; sc=$(jq '[.inbounds[]? | select(.protocol=="shadowsocks")] | length' "$CONFIG" 2>/dev/null || echo 0)
[[ "$sc" -eq 0 ]] && warn "Shadowsocks 未配置" && return
local method; method=$(_select_ss_method)
local sidx; sidx=$(_get_ss_idx)
_safe_jq_write ".inbounds[$sidx].settings.method = "$method"" || return
systemctl restart xray
info "SS 加密方式已更改为: $method"
}

_proto_del_ss() {
local sc; sc=$(jq '[.inbounds[]? | select(.protocol=="shadowsocks")] | length' "$CONFIG" 2>/dev/null || echo 0)
[[ "$sc" -eq 0 ]] && warn "Shadowsocks 未配置" && return
read -rp "确认删除 Shadowsocks? [y/N]: " c
[[ "$c" != "y" ]] && warn "已取消" && return
_safe_jq_write 'del(.inbounds[] | select(.protocol=="shadowsocks"))' || return
systemctl restart xray
info "Shadowsocks 已删除"
}

# +==========================================================+

# |                  10. 一键更改                             |

# +==========================================================+

do_quick_change() {
title "一键更改"
check_config || return
echo "  选择要更改的内容："
echo "  1) VLESS 端口"
echo "  2) VLESS 用户 UUID"
echo "  3) 目标域名 / SNI"
echo "  4) Short ID（追加或重置）"
echo "  5) x25519 密钥对"
echo "  6) SS 密码"
echo "  7) SS 端口"
echo "  8) SS 加密方式"
echo "  f) 返回主菜单"
hr
read -rp "选择: " qc
case "$qc" in
1) _global_port       ;;
2) _modify_user       ;;
3) _global_domain     ;;
4) _global_regen_sid  ;;
5) _global_regen_key  ;;
6) _proto_ss_pass     ;;
7) _proto_ss_port     ;;
8) _proto_ss_method   ;;
f|F|0) return         ;;
*) warn "无效选项"    ;;
esac
echo ""
read -rp "按 Enter 返回主菜单…" _
}

# +==========================================================+

# |                  11. Xray 命令                            |

# +==========================================================+

do_xray_cmd_menu() {
while true; do
title "Xray 命令"
echo "  1) 查看版本"
echo "  2) 生成新 x25519 密钥对"
echo "  3) 生成随机 UUID"
echo "  4) 测试配置文件"
echo "  5) 查看 Xray 日志（实时，Ctrl+C 退出）"
echo "  6) 查看 Xray 错误日志"
echo "  f) 返回主菜单"
hr
read -rp "选择: " xc
case "$xc" in
1)
[[ -x "$XRAY_BIN" ]] && "$XRAY_BIN" version || error "xray 未安装"
;;
2)
if [[ ! -x "$XRAY_BIN" ]]; then
error "xray 未安装"
else
local keys; keys=$("$XRAY_BIN" x25519 2>/dev/null)
local p; p=$(echo "$keys" | grep "Private key" | awk '{print $3}')
local pub; pub=$(echo "$keys" | grep "Public key" | awk '{print $3}')
hr
printf "  %-10s %s\n" "私钥:" "$p"
printf "  %-10s %s\n" "公钥:" "$pub"
hr
fi
;;
3)
gen_uuid
;;
4)
if [[ ! -f "$CONFIG" ]]; then
error "配置文件不存在"
else
"$XRAY_BIN" run -test -config "$CONFIG" 2>&1   
&& msg ok "配置文件测试通过"   
|| error "配置文件存在错误"
fi
;;
5)
journalctl -u xray -f –no-pager 2>/dev/null   
|| tail -f "$LOG_DIR/access.log" 2>/dev/null   
|| warn "无法读取日志"
;;
6)
journalctl -u xray -p err –no-pager 2>/dev/null | tail -50   
|| tail -50 "$LOG_DIR/error.log" 2>/dev/null   
|| warn "无法读取错误日志"
;;
f|F|0) return ;;
*) warn "无效选项" ;;
esac
echo ""
read -rp "按 Enter 继续…" _
done
}

# +==========================================================+

# |                  12. 完整卸载                             |

# +==========================================================+

do_uninstall() {
clear
title "完整卸载 Xray"
echo ""
echo -e "  ${is_warn} ${red}此操作将彻底删除以下所有内容，不可恢复：${none}"
hr
echo "  • Xray 服务（停止 + 禁用）"
echo "  • Xray 二进制:  /usr/local/bin/xray"
echo "  • 配置目录:     $CONFIG_DIR/"
echo "  • 日志目录:     $LOG_DIR/"
echo "  • 规则文件:     $DAT_DIR/*.dat"
echo "  • systemd 服务文件"
echo "  • cron 定时任务"
echo "  • xray-script 目录: $SCRIPT_DIR/"
echo "  • xrv 快捷方式: $SYMLINK"
echo "  • 本脚本:       $SCRIPT_PATH"
hr
echo ""
read -rp "第一次确认：确定要完整卸载? [yes/N]: " c1
[[ "$c1" != "yes" ]] && warn "已取消" && return
read -rp "第二次确认：不可恢复，继续? [yes/N]: " c2
[[ "$c2" != "yes" ]] && warn "已取消" && return

```
echo ""
msg warn "开始卸载..."

systemctl stop    xray 2>/dev/null && info "服务已停止"     || true
systemctl disable xray 2>/dev/null && info "开机自启已禁用" || true

for d in /etc/systemd/system /lib/systemd/system /usr/lib/systemd/system; do
    for s in xray.service "xray@.service"; do
        [[ -f "$d/$s" ]] && rm -f "$d/$s" && info "已删除: $d/$s"
    done
done
systemctl daemon-reload && info "systemd 已重载"

for bin in /usr/local/bin/xray /usr/local/bin/xray-bootarg; do
    [[ -f "$bin" ]] && rm -f "$bin" && info "已删除: $bin"
done

for dat in "$DAT_DIR/geoip.dat" "$DAT_DIR/geosite.dat"; do
    [[ -f "$dat" ]] && rm -f "$dat" && info "已删除: $dat"
done
rmdir "$DAT_DIR" 2>/dev/null || true

local cfg_bak=""
if [[ -d "$CONFIG_DIR" ]]; then
    cfg_bak="/root/xray_config_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    if tar -czf "$cfg_bak" -C "/usr/local/etc" xray 2>/dev/null; then
        info "配置已备份: $cfg_bak"
    else
        warn "配置备份失败"
        cfg_bak=""
    fi
    rm -rf "$CONFIG_DIR"
    info "已删除: $CONFIG_DIR"
fi

[[ -d "$LOG_DIR" ]] && rm -rf "$LOG_DIR" && info "已删除日志目录"

if [[ -d "$SCRIPT_DIR" ]]; then
    rm -rf "$SCRIPT_DIR"
    info "已删除: $SCRIPT_DIR"
fi
crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT" | crontab - 2>/dev/null || true
info "已移除 cron 任务"

[[ -L "$SYMLINK" ]] && rm -f "$SYMLINK" && info "已删除快捷方式: $SYMLINK"
hash -r 2>/dev/null || true

hr
info "Xray 已完整卸载"
[[ -n "$cfg_bak" ]] && warn "配置备份保留于: $cfg_bak"
hr
echo ""
read -rp "是否同时删除本脚本 ($SCRIPT_PATH)? [y/N]: " ds
if [[ "$ds" == "y" ]]; then
    (sleep 1 && rm -f "$SCRIPT_PATH") &
    info "本脚本将在 1 秒后删除"
fi
echo ""
msg ok "卸载完成"
exit 0
```

}

# +==========================================================+

# |                       主菜单                              |

# +==========================================================+

show_banner() {
clear
echo -e "${blue}"
echo "  +===========================================+"
echo "  |       Xray 全功能管理脚本 v6              |"
echo "  |       快捷方式: xrv                       |"
echo "  +===========================================+"
echo -e "${none}"
}

main_menu() {
while true; do
show_banner
local svc; svc=$(systemctl is-active xray 2>/dev/null || echo "未运行")
local svc_color
[[ "$svc" == "active" ]] && svc_color=$green || svc_color=$red
echo -e "  Xray 状态: ${svc_color}${svc}${none}"
echo ""
echo "   1) 安装 / 重装"
echo "   2) 更新 Xray 核心"
echo "   3) 立即更新 geo 规则"
echo "   4) 查看运行状态（IP / DNS / 流量）"
echo "   5) 用户管理（VLESS）"
echo "   6) 全局配置管理"
echo "   7) 查看配置摘要"
echo "   8) 导出用户配置"
echo "   9) 协议管理（Shadowsocks）"
echo "  10) 一键更改"
echo "  11) Xray 命令"
echo -e "  ${red}12) 完整卸载${none}"
echo "   0) 退出"
hr
read -rp "选择: " num
case "$num" in
1)  do_install         ;;
2)  do_upgrade_core    ;;
3)  do_update_dat      ;;
4)  do_status_menu     ;;
5)  do_user_menu       ;;
6)  do_global_menu     ;;
7)  do_summary; echo ""; read -rp "按 Enter 返回…" _ ;;
8)  do_export          ;;
9)  do_protocol_menu   ;;
10) do_quick_change    ;;
11) do_xray_cmd_menu   ;;
12) do_uninstall       ;;
0)  echo "再见！"; exit 0 ;;
*)  warn "无效选项，请输入 0-12" ;;
esac
done
}

# – 入口 –––––––––––––––––––––––––

preflight
main_menu
