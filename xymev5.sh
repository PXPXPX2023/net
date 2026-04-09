#!/usr/bin/env bash
# ============================================================
#  Xray PRO MAX v5
#  快捷键：xm
#  用法：bash xray_reality_pro_max_v5.sh
# ============================================================
set -euo pipefail

# ===== 全局常量 =====
CONFIG="/usr/local/etc/xray/config.json"
XRAY_BIN="/usr/local/bin/xray"
SCRIPT_PATH="$(realpath "$0")"
SYMLINK="/usr/local/bin/xm"
UPDATE_DAT_SCRIPT="/usr/local/etc/xray-script/update-dat.sh"
XRAY_SCRIPT_DIR="/usr/local/etc/xray-script"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat"
XRAY_DIR="/usr/local/share/xray"

# ===== 颜色 =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }
title() { echo -e "\n${BOLD}${CYAN}$*${NC}"; }
hr()    { echo "------------------------------------------------------------"; }

# ============================================================
#  初始化检查
# ============================================================
preflight() {
    if [[ $EUID -ne 0 ]]; then
        error "请以 root 权限运行此脚本"
        exit 1
    fi
    local missing=()
    for cmd in jq curl systemctl awk; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "缺少依赖，请先安装: ${missing[*]}"
        echo "  Debian/Ubuntu: apt install -y ${missing[*]}"
        echo "  CentOS/RHEL:   yum install -y ${missing[*]}"
        exit 1
    fi
    # 建立 xm 快捷键软链接
    if [[ ! -L "$SYMLINK" ]] || [[ "$(readlink -f "$SYMLINK")" != "$SCRIPT_PATH" ]]; then
        ln -sf "$SCRIPT_PATH" "$SYMLINK"
        chmod +x "$SCRIPT_PATH"
        info "快捷键 xm 已绑定 → $SCRIPT_PATH"
    fi
}

# ============================================================
#  配置文件检查（修复 null 迭代问题）
# ============================================================
check_config() {
    if [[ ! -f "$CONFIG" ]]; then
        error "配置文件不存在: $CONFIG"
        warn "请先执行「安装 / 重装」"
        return 1
    fi
    if ! jq empty "$CONFIG" 2>/dev/null; then
        error "配置文件 JSON 格式损坏"
        _try_restore_backup
        return 1
    fi
    # 检查关键路径是否存在，修复 null 迭代
    local clients_type
    clients_type=$(jq -r '
        if .inbounds == null then "no_inbounds"
        elif (.inbounds | length) == 0 then "empty_inbounds"
        elif .inbounds[0].settings == null then "no_settings"
        elif .inbounds[0].settings.clients == null then "null_clients"
        else "ok"
        end
    ' "$CONFIG" 2>/dev/null || echo "parse_error")

    case "$clients_type" in
        ok) return 0 ;;
        null_clients)
            warn "clients 字段为 null，自动修复中..."
            safe_jq_write '.inbounds[0].settings.clients = []' || return 1
            ;;
        no_settings)
            warn "settings 字段缺失，自动修复中..."
            safe_jq_write '.inbounds[0].settings = {"clients":[],"decryption":"none"}' || return 1
            ;;
        *)
            error "配置结构异常: $clients_type"
            _try_restore_backup
            return 1
            ;;
    esac
    return 0
}

_try_restore_backup() {
    local bak
    bak=$(ls -t "${CONFIG}.bak."* 2>/dev/null | head -n1 || true)
    if [[ -n "$bak" ]]; then
        warn "发现最近备份: $bak"
        read -rp "是否还原此备份? [y/N]: " ans
        [[ "$ans" == "y" ]] && cp "$bak" "$CONFIG" && info "已还原" && systemctl restart xray || true
    fi
}

# ============================================================
#  安全 jq 写入（原子替换 + 自动备份）
# ============================================================
safe_jq_write() {
    local filter="$1"
    local bak_path="${CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"
    local tmp
    tmp=$(mktemp /tmp/xray_config_XXXXXX.json)

    [[ -f "$CONFIG" ]] && cp "$CONFIG" "$bak_path"

    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null && jq empty "$tmp" 2>/dev/null; then
        mv "$tmp" "$CONFIG"
        return 0
    fi

    error "jq 处理失败，正在还原备份..."
    [[ -f "$bak_path" ]] && cp "$bak_path" "$CONFIG"
    rm -f "$tmp"
    return 1
}

# ============================================================
#  生成默认配置（融合 reality + routing + outbounds）
# ============================================================
generate_default_config() {
    local port="$1"
    local uuid="$2"
    local private_key="$3"
    local short_id="$4"
    local dest_domain="$5"
    local sni="$6"

    mkdir -p "$(dirname "$CONFIG")"
    cat > "$CONFIG" <<EOF
{
    "log": {
        "loglevel": "warning"
    },
    "routing": {
        "domainStrategy": "IPIfNonMatch",
        "rules": [
            {
                "type": "field",
                "protocol": ["bittorrent"],
                "outboundTag": "block"
            },
            {
                "type": "field",
                "ip": ["geoip:private"],
                "outboundTag": "block"
            },
            {
                "type": "field",
                "ip": ["geoip:cn"],
                "outboundTag": "block"
            },
            {
                "type": "field",
                "domain": ["geosite:category-ads-all"],
                "outboundTag": "block"
            }
        ]
    },
    "inbounds": [
        {
            "tag": "xray-xtls-reality",
            "listen": "0.0.0.0",
            "port": ${port},
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${uuid}",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "dest": "${dest_domain}:443",
                    "serverNames": ["${sni}"],
                    "privateKey": "${private_key}",
                    "shortIds": ["${short_id}"]
                }
            },
            "sniffing": {
                "enabled": true,
                "destOverride": ["http", "tls", "quic"]
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
}
EOF
}

# ============================================================
#  随机 Short ID 生成
# ============================================================
gen_short_id() {
    # 随机长度 8 或 16 的十六进制串
    local len=$((RANDOM % 2 == 0 ? 8 : 16))
    head -c 32 /dev/urandom | xxd -p | tr -d '\n' | head -c "$len"
}

# ============================================================
#  安装 update-dat.sh 脚本 + cron
# ============================================================
install_update_dat() {
    mkdir -p "$XRAY_SCRIPT_DIR"
    cat > "$UPDATE_DAT_SCRIPT" <<'UPDATESCRIPT'
#!/usr/bin/env bash
set -e

XRAY_DIR="/usr/local/share/xray"
GEOIP_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"
GEOSITE_URL="https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat"

[ -d "$XRAY_DIR" ] || mkdir -p "$XRAY_DIR"
cd "$XRAY_DIR"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始更新 geoip.dat..."
curl -fsSL -o geoip.dat.new "$GEOIP_URL"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 开始更新 geosite.dat..."
curl -fsSL -o geosite.dat.new "$GEOSITE_URL"

mv -f geoip.dat.new geoip.dat
mv -f geosite.dat.new geosite.dat

echo "[$(date '+%Y-%m-%d %H:%M:%S')] dat 更新完成"
systemctl -q is-active xray && systemctl restart xray && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Xray 已重启"
UPDATESCRIPT

    chmod +x "$UPDATE_DAT_SCRIPT"
    info "update-dat.sh 已写入: $UPDATE_DAT_SCRIPT"

    # 安装 cron（每天凌晨3点）
    local cron_job="0 3 * * * $UPDATE_DAT_SCRIPT >> /var/log/xray/update-dat.log 2>&1"
    # 创建日志目录
    mkdir -p /var/log/xray
    # 去重后写入
    if crontab -l 2>/dev/null | grep -qF "$UPDATE_DAT_SCRIPT"; then
        info "cron 任务已存在，跳过"
    else
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        info "已添加 cron 任务：每天 03:00 自动更新 dat"
    fi
}

# ============================================================
#  主菜单
# ============================================================
menu() {
    while true; do
        clear
        echo -e "${BOLD}${CYAN}"
        echo "  ╔══════════════════════════════╗"
        echo "  ║    Xray PRO MAX v5           ║"
        echo "  ╚══════════════════════════════╝"
        echo -e "${NC}"
        echo "  1. 安装 / 重装"
        echo "  2. 更新核心"
        echo "  3. 立即更新规则 (dat)"
        echo "  4. 查看运行状态"
        echo "  5. 用户管理"
        echo "  6. 全局配置管理"
        echo "  7. 查看配置摘要"
        echo "  8. 导出用户配置"
        echo -e "  ${RED}9. 完整卸载 Xray${NC}"
        echo "  0. 退出"
        hr
        read -rp "选择: " num
        case "$num" in
            1) install_xray ;;
            2) upgrade_xray ;;
            3) run_update_dat ;;
            4) systemctl status xray --no-pager || true ;;
            5) check_config && user_menu ;;
            6) check_config && global_menu ;;
            7) check_config && show_config_summary ;;
            8) check_config && export_user_config ;;
            9) uninstall_xray ;;
            0) echo "再见！"; exit 0 ;;
            *) warn "无效选项" ;;
        esac
        echo ""
        read -rp "按 Enter 返回主菜单..." _
    done
}

# ============================================================
#  用户管理菜单
# ============================================================
user_menu() {
    while true; do
        title "------ 用户管理 ------"
        echo "  1. 查看用户"
        echo "  2. 新增用户"
        echo "  3. 修改用户"
        echo "  4. 删除用户"
        echo "  0. 返回"
        hr
        read -rp "选择: " u
        case "$u" in
            1) list_users ;;
            2) add_user ;;
            3) modify_user ;;
            4) delete_user ;;
            0) return ;;
            *) warn "无效选项" ;;
        esac
        echo ""
        read -rp "按 Enter 继续..." _
    done
}

# ============================================================
#  全局配置菜单
# ============================================================
global_menu() {
    while true; do
        title "------ 全局配置管理 ------"
        echo "  1. 修改监听端口"
        echo "  2. 修改目标域名 / SNI"
        echo "  3. 重新生成 x25519 密钥对"
        echo "  4. 重新生成 Short ID"
        echo "  5. 查看完整配置文件"
        echo "  6. 还原配置备份"
        echo "  0. 返回"
        hr
        read -rp "选择: " g
        case "$g" in
            1) modify_port ;;
            2) modify_domain ;;
            3) regen_keys ;;
            4) regen_short_id ;;
            5) jq . "$CONFIG" ;;
            6) restore_backup ;;
            0) return ;;
            *) warn "无效选项" ;;
        esac
        echo ""
        read -rp "按 Enter 继续..." _
    done
}

# ============================================================
#  配置摘要
# ============================================================
show_config_summary() {
    title "===== 当前配置摘要 ====="
    local port dest sni privKey pubKey shortIds user_count xray_ver svc_status
    port=$(jq -r '.inbounds[0].port // "未知"' "$CONFIG")
    dest=$(jq -r '.inbounds[0].streamSettings.realitySettings.dest // "未知"' "$CONFIG")
    sni=$(jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0] // "未知"' "$CONFIG")
    privKey=$(jq -r '.inbounds[0].streamSettings.realitySettings.privateKey // ""' "$CONFIG")
    shortIds=$(jq -r '.inbounds[0].streamSettings.realitySettings.shortIds | join(", ")' "$CONFIG" 2>/dev/null || echo "未知")

    if [[ -n "$privKey" ]] && [[ -x "$XRAY_BIN" ]]; then
        pubKey=$("$XRAY_BIN" x25519 -i "$privKey" 2>/dev/null \
            | grep "Public key" | awk '{print $3}' || echo "计算失败")
    else
        pubKey="（需要 xray 二进制）"
    fi

    user_count=$(jq 'if .inbounds[0].settings.clients == null then 0 else .inbounds[0].settings.clients | length end' "$CONFIG" 2>/dev/null || echo 0)
    [[ -x "$XRAY_BIN" ]] && xray_ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 || echo "未知") || xray_ver="未安装"
    svc_status=$(systemctl is-active xray 2>/dev/null || echo "未运行")

    hr
    printf "  %-14s %s\n" "监听端口:"  "$port"
    printf "  %-14s %s\n" "目标域名:"  "$dest"
    printf "  %-14s %s\n" "SNI:"       "$sni"
    printf "  %-14s %s\n" "公钥:"      "$pubKey"
    printf "  %-14s %s\n" "Short ID:"  "$shortIds"
    printf "  %-14s %s\n" "用户数量:"  "$user_count"
    hr
    printf "  %-14s %s\n" "Xray 版本:" "$xray_ver"
    printf "  %-14s %s\n" "服务状态:"  "$svc_status"
    hr
}

# ============================================================
#  查看用户（序号显示）
# ============================================================
list_users() {
    title "===== 当前用户列表 ====="
    local count
    count=$(jq 'if .inbounds[0].settings.clients == null then 0 else .inbounds[0].settings.clients | length end' "$CONFIG" 2>/dev/null || echo 0)
    if [[ "$count" -eq 0 ]]; then
        warn "暂无用户"
        return 1
    fi
    printf "%-4s %-36s %s\n" "No." "UUID" "Flow"
    hr
    jq -r '.inbounds[0].settings.clients[] | "\(.id) \(.flow // "无")"' "$CONFIG" \
        | awk '{printf "%-4d %-36s %s\n", NR, $1, $2}'
    hr
    info "共 $count 个用户"
    return 0
}

# ============================================================
#  新增用户（端口自选、UUID/ShortID/密钥随机）
# ============================================================
add_user() {
    title "===== 新增用户 ====="

    # 端口
    local cur_port
    cur_port=$(jq -r '.inbounds[0].port // 0' "$CONFIG")
    echo "当前监听端口: $cur_port"
    read -rp "是否修改端口? [y/N]: " change_port
    if [[ "$change_port" == "y" ]]; then
        _input_port
        local NEW_PORT="$_PORT"
        if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || (( NEW_PORT < 1 || NEW_PORT > 65535 )); then
            error "端口号无效"; return
        fi
        safe_jq_write ".inbounds[0].port = $NEW_PORT" || return 1
        info "端口已更新: $NEW_PORT"
    fi

    # 随机 UUID
    local UUID
    UUID=$(cat /proc/sys/kernel/random/uuid)

    # 随机 Short ID
    local SHORT_ID
    SHORT_ID=$(gen_short_id)

    # 将新用户追加（不含 email）
    safe_jq_write \
        ".inbounds[0].settings.clients += [{\"id\":\"$UUID\",\"flow\":\"xtls-rprx-vision\"}] |
         .inbounds[0].streamSettings.realitySettings.shortIds += [\"$SHORT_ID\"]" \
        || return 1

    systemctl restart xray
    info "新增用户成功"
    hr
    printf "  %-12s %s\n" "UUID:"      "$UUID"
    printf "  %-12s %s\n" "Short ID:"  "$SHORT_ID"
    hr
    warn "请将以上信息填入客户端"
}

_input_port() {
    read -rp "输入端口 (1-65535): " _PORT
}

# ============================================================
#  修改用户（按序号）
# ============================================================
modify_user() {
    title "===== 修改用户 ====="
    list_users || return
    local count
    count=$(jq '.inbounds[0].settings.clients | length' "$CONFIG")

    read -rp "输入用户序号（留空取消）: " SEL
    [[ -z "$SEL" ]] && warn "已取消" && return
    if ! [[ "$SEL" =~ ^[0-9]+$ ]] || (( SEL < 1 || SEL > count )); then
        error "无效序号"; return
    fi
    local IDX=$(( SEL - 1 ))

    local OLD_UUID
    OLD_UUID=$(jq -r ".inbounds[0].settings.clients[$IDX].id" "$CONFIG")

    read -rp "是否重新生成 UUID? [y/N]: " regen_uuid
    local NEW_UUID="$OLD_UUID"
    [[ "$regen_uuid" == "y" ]] && NEW_UUID=$(cat /proc/sys/kernel/random/uuid)

    read -rp "是否重新生成 Short ID? [y/N]: " regen_sid
    if [[ "$regen_sid" == "y" ]]; then
        local NEW_SID
        NEW_SID=$(gen_short_id)
        # 追加新 short id（保留旧的）
        safe_jq_write \
            "(.inbounds[0].settings.clients[$IDX].id) = \"$NEW_UUID\" |
             .inbounds[0].streamSettings.realitySettings.shortIds += [\"$NEW_SID\"]" \
            || return 1
        info "修改完成"
        printf "  %-12s %s\n" "UUID:"      "$NEW_UUID"
        printf "  %-12s %s\n" "新 Short ID:" "$NEW_SID"
    else
        safe_jq_write \
            "(.inbounds[0].settings.clients[$IDX].id) = \"$NEW_UUID\"" \
            || return 1
        info "修改完成"
        printf "  %-12s %s\n" "UUID:" "$NEW_UUID"
    fi

    systemctl restart xray
}

# ============================================================
#  删除用户（按序号）
# ============================================================
delete_user() {
    title "===== 删除用户 ====="
    list_users || return
    local count
    count=$(jq '.inbounds[0].settings.clients | length' "$CONFIG")

    read -rp "输入要删除的用户序号（留空取消）: " SEL
    [[ -z "$SEL" ]] && warn "已取消" && return
    if ! [[ "$SEL" =~ ^[0-9]+$ ]] || (( SEL < 1 || SEL > count )); then
        error "无效序号"; return
    fi
    local IDX=$(( SEL - 1 ))

    local DEL_UUID
    DEL_UUID=$(jq -r ".inbounds[0].settings.clients[$IDX].id" "$CONFIG")

    read -rp "确认删除用户 #${SEL} (${DEL_UUID})? [y/N]: " confirm
    [[ "$confirm" != "y" ]] && warn "已取消" && return

    safe_jq_write "del(.inbounds[0].settings.clients[$IDX])" || return 1
    systemctl restart xray
    info "已删除用户 #${SEL}: $DEL_UUID"
}

# ============================================================
#  导出用户配置（生成可直接使用的连接参数）
# ============================================================
export_user_config() {
    title "===== 导出用户配置 ====="
    list_users || return
    local count
    count=$(jq '.inbounds[0].settings.clients | length' "$CONFIG")

    read -rp "输入要导出的用户序号（留空取消）: " SEL
    [[ -z "$SEL" ]] && warn "已取消" && return
    if ! [[ "$SEL" =~ ^[0-9]+$ ]] || (( SEL < 1 || SEL > count )); then
        error "无效序号"; return
    fi
    local IDX=$(( SEL - 1 ))

    local UUID privKey pubKey port sni shortIds shortId
    UUID=$(jq -r ".inbounds[0].settings.clients[$IDX].id" "$CONFIG")
    port=$(jq -r '.inbounds[0].port' "$CONFIG")
    sni=$(jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0]' "$CONFIG")
    privKey=$(jq -r '.inbounds[0].streamSettings.realitySettings.privateKey' "$CONFIG")
    shortIds=$(jq -r '.inbounds[0].streamSettings.realitySettings.shortIds | join(",")' "$CONFIG")
    # 取第一个 short id 用于链接
    shortId=$(jq -r '.inbounds[0].streamSettings.realitySettings.shortIds[0] // ""' "$CONFIG")

    # 计算公钥
    if [[ -x "$XRAY_BIN" ]]; then
        pubKey=$("$XRAY_BIN" x25519 -i "$privKey" 2>/dev/null \
            | grep "Public key" | awk '{print $3}' || echo "计算失败")
    else
        pubKey="（需要 xray 二进制）"
    fi

    # 获取服务器 IP
    local SERVER_IP
    SERVER_IP=$(curl -fsSL --max-time 5 https://api4.ipify.org 2>/dev/null \
        || curl -fsSL --max-time 5 https://ifconfig.me 2>/dev/null \
        || echo "YOUR_SERVER_IP")

    # 生成 VLESS 链接
    local VLESS_LINK
    VLESS_LINK="vless://${UUID}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pubKey}&sid=${shortId}&type=tcp&headerType=none#xray-reality-$(date +%m%d)"

    echo ""
    hr
    title ">>> 用户 #${SEL} 配置参数 <<<"
    hr
    printf "  %-16s %s\n" "服务器 IP:"   "$SERVER_IP"
    printf "  %-16s %s\n" "端口:"        "$port"
    printf "  %-16s %s\n" "UUID:"        "$UUID"
    printf "  %-16s %s\n" "加密:"        "none"
    printf "  %-16s %s\n" "Flow:"        "xtls-rprx-vision"
    printf "  %-16s %s\n" "传输协议:"    "tcp"
    printf "  %-16s %s\n" "安全:"        "reality"
    printf "  %-16s %s\n" "SNI:"         "$sni"
    printf "  %-16s %s\n" "Fingerprint:" "chrome"
    printf "  %-16s %s\n" "公钥(pbk):"  "$pubKey"
    printf "  %-16s %s\n" "Short ID:"   "$shortId"
    printf "  %-16s %s\n" "所有 ShortIDs:" "$shortIds"
    hr
    echo ""
    echo -e "${BOLD}VLESS 链接（可直接导入客户端）：${NC}"
    echo ""
    echo "$VLESS_LINK"
    echo ""
    hr

    # 可选：保存到文件
    read -rp "是否保存到文件 /root/xray_user_${SEL}.txt? [y/N]: " save
    if [[ "$save" == "y" ]]; then
        {
            echo "=== Xray VLESS Reality 用户配置 #${SEL} ==="
            echo "导出时间: $(date '+%Y-%m-%d %H:%M:%S')"
            echo ""
            echo "服务器 IP:      $SERVER_IP"
            echo "端口:           $port"
            echo "UUID:           $UUID"
            echo "加密:           none"
            echo "Flow:           xtls-rprx-vision"
            echo "传输协议:       tcp"
            echo "安全:           reality"
            echo "SNI:            $sni"
            echo "Fingerprint:    chrome"
            echo "公钥(pbk):      $pubKey"
            echo "Short ID:       $shortId"
            echo "所有 ShortIDs:  $shortIds"
            echo ""
            echo "VLESS 链接:"
            echo "$VLESS_LINK"
        } > "/root/xray_user_${SEL}.txt"
        info "已保存至: /root/xray_user_${SEL}.txt"
    fi
}

# ============================================================
#  全局配置：端口
# ============================================================
modify_port() {
    title "===== 修改监听端口 ====="
    local cur_port
    cur_port=$(jq -r '.inbounds[0].port' "$CONFIG")
    echo "当前端口: $cur_port"
    read -rp "新端口（留空取消）: " NEW_PORT
    [[ -z "$NEW_PORT" ]] && warn "已取消" && return
    if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || (( NEW_PORT < 1 || NEW_PORT > 65535 )); then
        error "端口号无效"; return
    fi
    safe_jq_write ".inbounds[0].port = $NEW_PORT" || return 1
    systemctl restart xray
    info "端口已更改: $cur_port → $NEW_PORT"
}

# ============================================================
#  全局配置：域名 / SNI（用户自己输入）
# ============================================================
modify_domain() {
    title "===== 修改目标域名 / SNI ====="
    local cur_dest cur_sni
    cur_dest=$(jq -r '.inbounds[0].streamSettings.realitySettings.dest' "$CONFIG")
    cur_sni=$(jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0]' "$CONFIG")
    echo "当前目标域名: $cur_dest"
    echo "当前 SNI:      $cur_sni"
    hr
    echo "提示：目标域名应为支持 TLS 1.3 的域名（例：www.microsoft.com）"
    read -rp "新目标域名（不含端口，留空保持不变）: " NEW_DEST
    [[ -z "$NEW_DEST" ]] && NEW_DEST="${cur_dest%%:*}"
    read -rp "新 SNI（留空同目标域名）: " NEW_SNI
    [[ -z "$NEW_SNI" ]] && NEW_SNI="$NEW_DEST"

    safe_jq_write \
        ".inbounds[0].streamSettings.realitySettings.dest = \"${NEW_DEST}:443\" |
         .inbounds[0].streamSettings.realitySettings.serverNames = [\"$NEW_SNI\"]" \
        || return 1
    systemctl restart xray
    info "域名已更新，Xray 已重启"
    printf "  目标域名: %s:443\n" "$NEW_DEST"
    printf "  SNI:      %s\n" "$NEW_SNI"
}

# ============================================================
#  重新生成 x25519 密钥对
# ============================================================
regen_keys() {
    title "===== 重新生成 x25519 密钥对 ====="
    [[ ! -x "$XRAY_BIN" ]] && error "xray 二进制不存在" && return
    warn "重新生成密钥后，所有客户端需同步更新公钥！"
    read -rp "确认继续? [y/N]: " confirm
    [[ "$confirm" != "y" ]] && warn "已取消" && return

    local KEYS PRIVATE_KEY PUBLIC_KEY
    KEYS=$("$XRAY_BIN" x25519)
    PRIVATE_KEY=$(echo "$KEYS" | grep "Private key" | awk '{print $3}')
    PUBLIC_KEY=$(echo "$KEYS"  | grep "Public key"  | awk '{print $3}')

    safe_jq_write \
        ".inbounds[0].streamSettings.realitySettings.privateKey = \"$PRIVATE_KEY\"" \
        || return 1
    systemctl restart xray
    info "密钥对已更新"
    hr
    printf "  %-10s %s\n" "私钥:" "$PRIVATE_KEY"
    printf "  %-10s %s\n" "公钥:" "$PUBLIC_KEY"
    hr
    warn "请将公钥更新到所有客户端！"
}

# ============================================================
#  重新生成 Short ID
# ============================================================
regen_short_id() {
    title "===== 重新生成 Short ID ====="
    local cur_ids
    cur_ids=$(jq -r '.inbounds[0].streamSettings.realitySettings.shortIds | join(", ")' "$CONFIG" 2>/dev/null)
    echo "当前 Short IDs: $cur_ids"
    echo ""
    echo "  1. 追加一个新 Short ID"
    echo "  2. 替换所有 Short ID（重置）"
    echo "  0. 取消"
    read -rp "选择: " opt
    case "$opt" in
        1)
            local NEW_SID
            NEW_SID=$(gen_short_id)
            safe_jq_write \
                ".inbounds[0].streamSettings.realitySettings.shortIds += [\"$NEW_SID\"]" \
                || return 1
            info "已追加 Short ID: $NEW_SID"
            ;;
        2)
            local NEW_SID
            NEW_SID=$(gen_short_id)
            safe_jq_write \
                ".inbounds[0].streamSettings.realitySettings.shortIds = [\"$NEW_SID\"]" \
                || return 1
            info "Short ID 已重置: $NEW_SID"
            warn "客户端需同步更新 Short ID"
            ;;
        0) warn "已取消" ;;
        *) warn "无效选项" ;;
    esac
    systemctl restart xray 2>/dev/null || true
}

# ============================================================
#  还原备份
# ============================================================
restore_backup() {
    title "===== 还原配置备份 ====="
    local backups
    backups=$(ls -t "${CONFIG}.bak."* 2>/dev/null || true)
    if [[ -z "$backups" ]]; then
        warn "没有找到任何备份文件"
        return
    fi
    echo "可用备份（从新到旧）："
    hr
    local i=1
    local bak_list=()
    while IFS= read -r bak; do
        local bak_time
        bak_time=$(stat -c "%y" "$bak" 2>/dev/null | cut -d'.' -f1 || echo "未知")
        printf "  %d. %-45s [%s]\n" "$i" "$(basename "$bak")" "$bak_time"
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
    read -rp "确认还原: $(basename "$chosen")? [y/N]: " confirm
    [[ "$confirm" != "y" ]] && warn "已取消" && return

    cp "$CONFIG" "${CONFIG}.before_restore.$(date +%Y%m%d_%H%M%S)"
    cp "$chosen" "$CONFIG"
    systemctl restart xray
    info "已还原备份，Xray 已重启"
}

# ============================================================
#  更新 dat
# ============================================================
run_update_dat() {
    title "===== 立即更新规则 (dat) ====="
    if [[ ! -f "$UPDATE_DAT_SCRIPT" ]]; then
        warn "update-dat.sh 不存在，正在创建..."
        install_update_dat
    fi
    bash "$UPDATE_DAT_SCRIPT"
    info "dat 规则更新完成"
}

# ============================================================
#  安装 / 重装
# ============================================================
install_xray() {
    title "===== 安装 / 重装 Xray ====="
    if systemctl is-active --quiet xray 2>/dev/null; then
        warn "检测到 Xray 正在运行，重装只覆盖二进制，配置文件保留"
    fi
    read -rp "确认继续? [y/N]: " confirm
    [[ "$confirm" != "y" ]] && warn "已取消" && return

    # 安装 Xray 核心
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    info "Xray 核心安装完成"

    # 如果配置不存在，引导初始化
    if [[ ! -f "$CONFIG" ]]; then
        echo ""
        warn "未检测到配置文件，开始初始化配置..."
        _init_config
    fi

    # 安装/更新 update-dat.sh
    install_update_dat

    # 立即下载 dat
    echo ""
    read -rp "是否立即下载 dat 规则文件? [Y/n]: " dl_dat
    if [[ "$dl_dat" != "n" ]]; then
        bash "$UPDATE_DAT_SCRIPT" || warn "dat 下载失败，可稍后手动执行选项3"
    fi

    # 开机自启
    systemctl enable xray
    systemctl restart xray
    info "Xray 已设置开机自启并已启动"
    echo ""
    show_config_summary
}

# 初始化配置（引导输入）
_init_config() {
    echo ""
    title ">>> 初始化 Xray 配置 <<<"
    echo ""

    # 端口
    local PORT
    while true; do
        read -rp "监听端口 (1-65535，推荐 443): " PORT
        [[ -z "$PORT" ]] && PORT=443
        [[ "$PORT" =~ ^[0-9]+$ ]] && (( PORT >= 1 && PORT <= 65535 )) && break
        error "端口无效，请重新输入"
    done

    # 域名
    echo ""
    echo "请输入回落目标域名（需支持 TLS 1.3，例：www.microsoft.com）"
    local DEST_DOMAIN
    while true; do
        read -rp "目标域名: " DEST_DOMAIN
        [[ -n "$DEST_DOMAIN" ]] && break
        error "域名不能为空"
    done

    # SNI
    read -rp "SNI（留空同目标域名）: " SNI
    [[ -z "$SNI" ]] && SNI="$DEST_DOMAIN"

    # 生成密钥对
    echo ""
    info "正在生成 x25519 密钥对..."
    local KEYS PRIVATE_KEY PUBLIC_KEY
    KEYS=$("$XRAY_BIN" x25519)
    PRIVATE_KEY=$(echo "$KEYS" | grep "Private key" | awk '{print $3}')
    PUBLIC_KEY=$(echo "$KEYS"  | grep "Public key"  | awk '{print $3}')

    # 生成 UUID 和 Short ID
    local UUID SHORT_ID
    UUID=$(cat /proc/sys/kernel/random/uuid)
    SHORT_ID=$(gen_short_id)

    # 写入配置
    mkdir -p "$(dirname "$CONFIG")"
    generate_default_config "$PORT" "$UUID" "$PRIVATE_KEY" "$SHORT_ID" "$DEST_DOMAIN" "$SNI"
    info "配置文件已生成: $CONFIG"

    echo ""
    hr
    title ">>> 初始配置信息（请保存）<<<"
    hr
    printf "  %-16s %s\n" "端口:"       "$PORT"
    printf "  %-16s %s\n" "目标域名:"   "${DEST_DOMAIN}:443"
    printf "  %-16s %s\n" "SNI:"        "$SNI"
    printf "  %-16s %s\n" "UUID:"       "$UUID"
    printf "  %-16s %s\n" "私钥:"       "$PRIVATE_KEY"
    printf "  %-16s %s\n" "公钥:"       "$PUBLIC_KEY"
    printf "  %-16s %s\n" "Short ID:"  "$SHORT_ID"
    hr
}

# ============================================================
#  更新核心（列出版本让用户确认）
# ============================================================
upgrade_xray() {
    title "===== 更新 Xray 核心 ====="
    echo "正在获取可用版本..."
    local versions
    versions=$(curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases \
        | grep tag_name | cut -d '"' -f 4 | head -n 15)
    if [[ -z "$versions" ]]; then
        error "获取版本列表失败，请检查网络"
        return
    fi

    local current_ver=""
    [[ -x "$XRAY_BIN" ]] && current_ver=$("$XRAY_BIN" version 2>/dev/null | grep -oP 'Xray \K[0-9.]+' | head -n1 || echo "未知")

    echo ""
    echo "当前版本: ${current_ver:-未安装}"
    echo ""
    echo "可用版本（最近15个）："
    hr
    echo "$versions" | awk '{printf "  %2d. %s\n", NR, $0}'
    hr
    echo ""
    read -rp "输入版本号（例 v1.8.10，留空取消）: " VERSION
    [[ -z "$VERSION" ]] && warn "已取消" && return
    if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        error "版本号格式不正确（应为 vX.Y.Z）"
        return
    fi
    read -rp "确认升级到 $VERSION? [y/N]: " confirm
    [[ "$confirm" != "y" ]] && warn "已取消" && return

    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" \
        @ install -u root -v "$VERSION"

    # 确保开机自启
    systemctl enable xray 2>/dev/null || true
    systemctl restart xray
    info "已升级到 $VERSION，Xray 已重启"
}

# ============================================================
#  完整卸载
# ============================================================
uninstall_xray() {
    clear
    title "===== 完整卸载 Xray ====="
    echo ""
    echo -e "${RED}${BOLD}  ⚠  警告：此操作将彻底删除以下所有内容：${NC}"
    hr
    echo "  • Xray 服务进程（停止 + 禁用）"
    echo "  • Xray 二进制:    /usr/local/bin/xray"
    echo "  • 配置目录:       /usr/local/etc/xray/"
    echo "  • 日志目录:       /var/log/xray/"
    echo "  • 规则文件:       /usr/local/share/xray/*.dat"
    echo "  • systemd 服务文件"
    echo "  • cron 定时任务"
    echo "  • xray-script 目录"
    echo "  • xm 快捷键:      $SYMLINK"
    echo "  • 本脚本:         $SCRIPT_PATH"
    hr
    echo ""
    read -rp "第一次确认：确定要完整卸载? [yes/N]: " c1
    [[ "$c1" != "yes" ]] && warn "已取消" && return
    read -rp "第二次确认：不可恢复，继续? [yes/N]: " c2
    [[ "$c2" != "yes" ]] && warn "已取消" && return

    echo ""
    warn "开始卸载..."

    # 1. 停止服务
    systemctl stop xray 2>/dev/null && info "服务已停止" || true
    systemctl disable xray 2>/dev/null && info "开机自启已禁用" || true

    # 2. systemd 文件
    for dir in /etc/systemd/system /lib/systemd/system /usr/lib/systemd/system; do
        for svc in xray.service "xray@.service"; do
            [[ -f "$dir/$svc" ]] && rm -f "$dir/$svc" && info "已删除: $dir/$svc"
        done
    done
    systemctl daemon-reload

    # 3. 二进制
    for bin in /usr/local/bin/xray /usr/local/bin/xray-bootarg; do
        [[ -f "$bin" ]] && rm -f "$bin" && info "已删除: $bin"
    done

    # 4. dat 文件
    for dat in /usr/local/share/xray/geoip.dat /usr/local/share/xray/geosite.dat; do
        [[ -f "$dat" ]] && rm -f "$dat" && info "已删除: $dat"
    done
    rmdir /usr/local/share/xray 2>/dev/null || true

    # 5. 备份并删除配置
    local cfg_backup=""
    if [[ -d "/usr/local/etc/xray" ]]; then
        cfg_backup="/root/xray_config_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        tar -czf "$cfg_backup" -C "/usr/local/etc" xray 2>/dev/null \
            && info "配置已备份: $cfg_backup" || warn "配置备份失败"
        rm -rf /usr/local/etc/xray
        info "已删除配置目录: /usr/local/etc/xray"
    fi

    # 6. 日志
    [[ -d "/var/log/xray" ]] && rm -rf /var/log/xray && info "已删除日志目录"

    # 7. xray-script + cron
    if [[ -d "$XRAY_SCRIPT_DIR" ]]; then
        rm -rf "$XRAY_SCRIPT_DIR"
        info "已删除: $XRAY_SCRIPT_DIR"
    fi
    # 移除 cron 任务
    crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT" | crontab - 2>/dev/null || true
    info "已移除 cron 定时任务"

    # 8. 快捷键
    [[ -L "$SYMLINK" ]] && rm -f "$SYMLINK" && info "已删除快捷键: $SYMLINK"

    hash -r 2>/dev/null || true

    hr
    info "Xray 已完整卸载"
    [[ -n "$cfg_backup" ]] && warn "配置备份保留于: $cfg_backup"
    hr
    echo ""
    read -rp "是否同时删除本脚本 ($SCRIPT_PATH)? [y/N]: " del_self
    if [[ "$del_self" == "y" ]]; then
        (sleep 1 && rm -f "$SCRIPT_PATH") &
        info "本脚本将在 1 秒后删除"
    fi
    echo ""
    info "感谢使用 Xray PRO MAX v5，再见！"
    exit 0
}

# ============================================================
#  入口
# ============================================================
preflight
menu
