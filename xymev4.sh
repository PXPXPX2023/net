#!/usr/bin/env bash
# ============================================================
#  Xray PRO MAX v5
#  用法：bash xray_reality_pro_max_v5.sh
#  快捷键：xm（由脚本末尾自动建立软链接）
# ============================================================
set -euo pipefail

# ===== 全局常量 =====
CONFIG="/usr/local/etc/xray/config.json"
XRAY_BIN="/usr/local/bin/xray"
SCRIPT_PATH="$(realpath "$0")"
SYMLINK="/usr/local/bin/xm"

# ===== 颜色 =====
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${GREEN}[✓]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
error()   { echo -e "${RED}[✗]${NC} $*"; }
title()   { echo -e "\n${BOLD}${CYAN}$*${NC}"; }

# ===== 初始化检查 =====
preflight() {
    # Root 权限
    if [[ $EUID -ne 0 ]]; then
        error "请以 root 权限运行此脚本"
        exit 1
    fi

    # 依赖检查
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

    # 建立快捷键软链接
    if [[ ! -L "$SYMLINK" ]] || [[ "$(readlink -f "$SYMLINK")" != "$SCRIPT_PATH" ]]; then
        ln -sf "$SCRIPT_PATH" "$SYMLINK"
        chmod +x "$SCRIPT_PATH"
        info "快捷键 xm 已绑定 → $SCRIPT_PATH"
    fi
}

# ===== 配置文件检查 =====
check_config() {
    if [[ ! -f "$CONFIG" ]]; then
        error "配置文件不存在: $CONFIG"
        warn "请先执行「安装 / 重装」"
        return 1
    fi
    # 验证 JSON 合法性
    if ! jq empty "$CONFIG" 2>/dev/null; then
        error "配置文件 JSON 格式损坏: $CONFIG"
        local bak
        bak=$(ls -t "${CONFIG}.bak."* 2>/dev/null | head -n1 || true)
        if [[ -n "$bak" ]]; then
            warn "发现备份: $bak"
            read -rp "是否还原此备份? [y/N]: " ans
            [[ "$ans" == "y" ]] && cp "$bak" "$CONFIG" && info "已还原" || true
        fi
        return 1
    fi
    return 0
}

# ===== 安全 jq 写入（自动备份 + 原子替换）=====
safe_jq_write() {
    local filter="$1"
    local bak_path="${CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"
    local tmp
    tmp=$(mktemp /tmp/xray_config_XXXXXX.json)

    # 备份
    cp "$CONFIG" "$bak_path"

    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null; then
        # 验证输出合法性
        if jq empty "$tmp" 2>/dev/null; then
            mv "$tmp" "$CONFIG"
            info "配置已更新（备份: $bak_path）"
            return 0
        fi
    fi

    error "jq 处理失败，正在还原备份..."
    cp "$bak_path" "$CONFIG"
    rm -f "$tmp"
    return 1
}

# ===== 菜单 =====
menu() {
    while true; do
        title "====== Xray PRO MAX v5 ======"
        echo "  1. 安装 / 重装"
        echo "  2. 更新核心"
        echo "  3. 更新规则"
        echo "  4. 查看状态"
        echo "  5. 用户管理"
        echo "  6. 查看配置摘要"
        echo "  0. 退出"
        echo "=============================="
        read -rp "选择: " num
        case "$num" in
            1) install_xray ;;
            2) upgrade_xray ;;
            3) update_dat ;;
            4) systemctl status xray --no-pager || true ;;
            5) check_config && user_menu ;;
            6) check_config && show_config_summary ;;
            0) echo "再见！"; exit 0 ;;
            *) warn "无效选项，请重新输入" ;;
        esac
        echo ""
        read -rp "按 Enter 返回主菜单..." _
    done
}

# ===== 用户菜单 =====
user_menu() {
    while true; do
        title "------ 用户管理 ------"
        echo "  1. 查看用户"
        echo "  2. 新增用户"
        echo "  3. 修改用户信息"
        echo "  4. 删除用户"
        echo "  0. 返回主菜单"
        echo "----------------------"
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

# ===== 配置摘要 =====
show_config_summary() {
    title "===== 当前配置摘要 ====="
    local port dest serverName pubKey
    port=$(jq -r '.inbounds[0].port // "未知"' "$CONFIG")
    dest=$(jq -r '.inbounds[0].streamSettings.realitySettings.dest // "未知"' "$CONFIG")
    serverName=$(jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0] // "未知"' "$CONFIG")
    # 计算公钥（如果 xray 存在）
    local privKey
    privKey=$(jq -r '.inbounds[0].streamSettings.realitySettings.privateKey // ""' "$CONFIG")
    if [[ -n "$privKey" ]] && [[ -x "$XRAY_BIN" ]]; then
        pubKey=$("$XRAY_BIN" x25519 -i "$privKey" 2>/dev/null | grep "Public key" | awk '{print $3}' || echo "计算失败")
    else
        pubKey="（需要 xray 二进制）"
    fi

    printf "  %-12s %s\n" "监听端口:" "$port"
    printf "  %-12s %s\n" "目标域名:" "$dest"
    printf "  %-12s %s\n" "SNI:" "$serverName"
    printf "  %-12s %s\n" "公钥:" "$pubKey"
    echo ""
    local user_count
    user_count=$(jq '.inbounds[0].settings.clients | length' "$CONFIG")
    printf "  %-12s %s\n" "用户数量:" "$user_count"
}

# ===== 查看用户 =====
list_users() {
    title "===== 当前用户列表 ====="
    local count
    count=$(jq '.inbounds[0].settings.clients | length' "$CONFIG")
    if [[ "$count" -eq 0 ]]; then
        warn "暂无用户"
        return
    fi
    printf "%-4s %-25s %s\n" "No." "Email" "UUID"
    echo "------------------------------------------------------------"
    jq -r '.inbounds[0].settings.clients[] | "\(.email) \(.id)"' "$CONFIG" \
        | awk '{printf "%-4d %-25s %s\n", NR, $1, $2}'
    echo ""
    info "共 $count 个用户"
}

# ===== 新增用户 =====
add_user() {
    title "===== 新增用户 ====="
    read -rp "输入用户名(email): " EMAIL
    if [[ -z "$EMAIL" ]]; then
        warn "用户名不能为空"
        return
    fi

    # 检查是否已存在
    local exists
    exists=$(jq -r --arg e "$EMAIL" '.inbounds[0].settings.clients[] | select(.email==$e) | .email' "$CONFIG")
    if [[ -n "$exists" ]]; then
        error "用户 $EMAIL 已存在"
        return
    fi

    local UUID
    UUID=$(cat /proc/sys/kernel/random/uuid)

    safe_jq_write \
        ".inbounds[0].settings.clients += [{\"id\":\"$UUID\",\"flow\":\"xtls-rprx-vision\",\"email\":\"$EMAIL\"}]" \
        || return 1

    systemctl restart xray
    info "新增成功"
    echo ""
    printf "  %-10s %s\n" "Email:" "$EMAIL"
    printf "  %-10s %s\n" "UUID:" "$UUID"
}

# ===== 删除用户 =====
delete_user() {
    title "===== 删除用户 ====="
    list_users
    read -rp "输入要删除的用户名(email，留空取消): " EMAIL
    [[ -z "$EMAIL" ]] && warn "已取消" && return

    # 确认
    local exists
    exists=$(jq -r --arg e "$EMAIL" '.inbounds[0].settings.clients[] | select(.email==$e) | .email' "$CONFIG")
    if [[ -z "$exists" ]]; then
        error "用户 $EMAIL 不存在"
        return
    fi

    read -rp "确认删除用户 ${EMAIL}? [y/N]: " confirm
    [[ "$confirm" != "y" ]] && warn "已取消" && return

    safe_jq_write \
        "del(.inbounds[0].settings.clients[] | select(.email==\"$EMAIL\"))" \
        || return 1

    systemctl restart xray
    info "已删除用户: $EMAIL"
}

# ===== 修改用户信息（仅用户维度，不动全局配置）=====
modify_user() {
    title "===== 修改用户信息 ====="
    list_users
    read -rp "输入要修改的用户名(email，留空取消): " OLD_EMAIL
    [[ -z "$OLD_EMAIL" ]] && warn "已取消" && return

    local exists
    exists=$(jq -r --arg e "$OLD_EMAIL" \
        '.inbounds[0].settings.clients[] | select(.email==$e) | .email' "$CONFIG")
    if [[ -z "$exists" ]]; then
        error "用户 $OLD_EMAIL 不存在"
        return
    fi

    read -rp "新用户名(email，留空保持 $OLD_EMAIL): " NEW_EMAIL
    [[ -z "$NEW_EMAIL" ]] && NEW_EMAIL="$OLD_EMAIL"

    read -rp "是否重新生成 UUID? [y/N]: " regen_uuid
    local UUID
    UUID=$(jq -r --arg e "$OLD_EMAIL" \
        '.inbounds[0].settings.clients[] | select(.email==$e) | .id' "$CONFIG")
    if [[ "$regen_uuid" == "y" ]]; then
        UUID=$(cat /proc/sys/kernel/random/uuid)
    fi

    safe_jq_write \
        "(.inbounds[0].settings.clients[] | select(.email==\"$OLD_EMAIL\") | .email) = \"$NEW_EMAIL\" |
         (.inbounds[0].settings.clients[] | select(.email==\"$NEW_EMAIL\") | .id) = \"$UUID\"" \
        || return 1

    systemctl restart xray
    info "修改完成"
    echo ""
    printf "  %-10s %s\n" "Email:" "$NEW_EMAIL"
    printf "  %-10s %s\n" "UUID:" "$UUID"
}

# ===== 全局配置修改（端口 / 域名 / 密钥）独立入口 =====
modify_global() {
    title "===== 修改全局配置 ====="
    warn "此操作会影响所有用户连接，请谨慎操作"
    echo ""

    local cur_port cur_dest cur_sni
    cur_port=$(jq -r '.inbounds[0].port' "$CONFIG")
    cur_dest=$(jq -r '.inbounds[0].streamSettings.realitySettings.dest' "$CONFIG")
    cur_sni=$(jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0]' "$CONFIG")

    read -rp "新端口（当前 $cur_port，留空不变）: " NEW_PORT
    [[ -z "$NEW_PORT" ]] && NEW_PORT="$cur_port"

    read -rp "新目标域名（当前 $cur_dest，留空不变）: " NEW_DEST
    [[ -z "$NEW_DEST" ]] && NEW_DEST="$cur_dest"

    read -rp "新 SNI（当前 $cur_sni，留空同目标域名）: " NEW_SNI
    [[ -z "$NEW_SNI" ]] && NEW_SNI="${NEW_DEST%%:*}"

    read -rp "是否重新生成 x25519 密钥对? [y/N]: " regen_key

    local PRIVATE_KEY
    PRIVATE_KEY=$(jq -r '.inbounds[0].streamSettings.realitySettings.privateKey' "$CONFIG")

    if [[ "$regen_key" == "y" ]]; then
        if [[ ! -x "$XRAY_BIN" ]]; then
            error "xray 二进制不存在，无法生成密钥: $XRAY_BIN"
            return
        fi
        local KEYS
        KEYS=$("$XRAY_BIN" x25519)
        PRIVATE_KEY=$(echo "$KEYS" | grep "Private key" | awk '{print $3}')
        local PUBLIC_KEY
        PUBLIC_KEY=$(echo "$KEYS" | grep "Public key" | awk '{print $3}')
        info "新密钥对已生成"
        printf "  %-12s %s\n" "私钥:" "$PRIVATE_KEY"
        printf "  %-12s %s\n" "公钥:" "$PUBLIC_KEY"
    fi

    # 端口校验
    if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || (( NEW_PORT < 1 || NEW_PORT > 65535 )); then
        error "端口号无效: $NEW_PORT"
        return
    fi

    read -rp "确认应用以上修改? [y/N]: " confirm
    [[ "$confirm" != "y" ]] && warn "已取消" && return

    safe_jq_write \
        ".inbounds[0].port = $NEW_PORT |
         .inbounds[0].streamSettings.realitySettings.dest = \"${NEW_DEST%%:*}:443\" |
         .inbounds[0].streamSettings.realitySettings.serverNames = [\"$NEW_SNI\"] |
         .inbounds[0].streamSettings.realitySettings.privateKey = \"$PRIVATE_KEY\"" \
        || return 1

    systemctl restart xray
    info "全局配置已更新，Xray 已重启"
}

# ===== 安装 / 重装 =====
install_xray() {
    title "===== 安装 / 重装 Xray ====="
    if systemctl is-active --quiet xray 2>/dev/null; then
        warn "检测到 Xray 正在运行，重装会覆盖二进制文件（配置保留）"
    fi
    read -rp "确认继续? [y/N]: " confirm
    [[ "$confirm" != "y" ]] && warn "已取消" && return

    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    info "安装完成"
}

# ===== 更新核心 =====
upgrade_xray() {
    title "===== 更新 Xray 核心 ====="
    echo "正在获取可用版本..."
    local versions
    versions=$(curl -fsSL https://api.github.com/repos/XTLS/Xray-core/releases \
        | grep tag_name | cut -d '"' -f 4 | head -n 10)

    if [[ -z "$versions" ]]; then
        error "获取版本列表失败，请检查网络"
        return
    fi

    echo ""
    echo "最近 10 个版本："
    echo "$versions" | awk '{print NR". "$0}'
    echo ""

    read -rp "输入版本号（例如 v1.8.10，留空取消）: " VERSION
    [[ -z "$VERSION" ]] && warn "已取消" && return

    # 格式校验
    if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        error "版本号格式不正确: $VERSION（应为 vX.Y.Z）"
        return
    fi

    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" \
        @ install -u root -v "$VERSION"
    info "已更新到 $VERSION"
}

# ===== 更新规则 =====
update_dat() {
    local script="/usr/local/etc/xray-script/update-dat.sh"
    if [[ ! -f "$script" ]]; then
        error "规则更新脚本不存在: $script"
        return
    fi
    bash "$script"
    info "规则已更新"
}

# ===== 入口 =====
preflight
menu
