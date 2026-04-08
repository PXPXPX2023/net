#!/usr/bin/env bash
# ============================================================
#  Xray PRO MAX v5
#  用法：bash xray_reality_pro_max_v5.sh
#  快捷键：xm（首次运行后自动建立软链接）
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

info()  { echo -e "${GREEN}[✓]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }
title() { echo -e "\n${BOLD}${CYAN}$*${NC}"; }
hr()    { echo "------------------------------------------------------------"; }

# ===== 初始化检查 =====
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

# ===== 配置文件检查 =====
check_config() {
    if [[ ! -f "$CONFIG" ]]; then
        error "配置文件不存在: $CONFIG"
        warn "请先执行「安装 / 重装」"
        return 1
    fi
    if ! jq empty "$CONFIG" 2>/dev/null; then
        error "配置文件 JSON 格式损坏: $CONFIG"
        local bak
        bak=$(ls -t "${CONFIG}.bak."* 2>/dev/null | head -n1 || true)
        if [[ -n "$bak" ]]; then
            warn "发现最近备份: $bak"
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

    cp "$CONFIG" "$bak_path"

    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null && jq empty "$tmp" 2>/dev/null; then
        mv "$tmp" "$CONFIG"
        info "配置已更新（备份: $bak_path）"
        return 0
    fi

    error "jq 处理失败，正在还原备份..."
    cp "$bak_path" "$CONFIG"
    rm -f "$tmp"
    return 1
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
        echo "  3. 更新规则"
        echo "  4. 查看运行状态"
        echo "  5. 用户管理"
        echo "  6. 全局配置管理"
        echo "  7. 查看配置摘要"
        echo -e "  ${RED}8. 完整卸载 Xray${NC}"
        echo "  0. 退出"
        hr
        read -rp "选择: " num
        case "$num" in
            1) install_xray ;;
            2) upgrade_xray ;;
            3) update_dat ;;
            4) systemctl status xray --no-pager || true ;;
            5) check_config && user_menu ;;
            6) check_config && global_menu ;;
            7) check_config && show_config_summary ;;
            8) uninstall_xray ;;
            0) echo "再见！"; exit 0 ;;
            *) warn "无效选项，请重新输入" ;;
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
        echo "  0. 返回主菜单"
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
        echo "  4. 查看完整配置文件"
        echo "  5. 还原配置备份"
        echo "  0. 返回主菜单"
        hr
        read -rp "选择: " g
        case "$g" in
            1) modify_port ;;
            2) modify_domain ;;
            3) regen_keys ;;
            4) jq . "$CONFIG" ;;
            5) restore_backup ;;
            0) return ;;
            *) warn "无效选项" ;;
        esac
        echo ""
        read -rp "按 Enter 继续..." _
    done
}

# ============================================================
#  查看配置摘要
# ============================================================
show_config_summary() {
    title "===== 当前配置摘要 ====="
    local port dest sni privKey pubKey
    port=$(jq -r '.inbounds[0].port // "未知"' "$CONFIG")
    dest=$(jq -r '.inbounds[0].streamSettings.realitySettings.dest // "未知"' "$CONFIG")
    sni=$(jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0] // "未知"' "$CONFIG")
    privKey=$(jq -r '.inbounds[0].streamSettings.realitySettings.privateKey // ""' "$CONFIG")

    if [[ -n "$privKey" ]] && [[ -x "$XRAY_BIN" ]]; then
        pubKey=$("$XRAY_BIN" x25519 -i "$privKey" 2>/dev/null \
            | grep "Public key" | awk '{print $3}' || echo "计算失败")
    else
        pubKey="（需要 xray 二进制）"
    fi

    local user_count
    user_count=$(jq '.inbounds[0].settings.clients | length' "$CONFIG")

    local xray_ver=""
    [[ -x "$XRAY_BIN" ]] && xray_ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 || echo "未知")

    local svc_status
    svc_status=$(systemctl is-active xray 2>/dev/null || echo "未运行")

    hr
    printf "  %-14s %s\n" "监听端口:"  "$port"
    printf "  %-14s %s\n" "目标域名:"  "$dest"
    printf "  %-14s %s\n" "SNI:"       "$sni"
    printf "  %-14s %s\n" "公钥:"      "$pubKey"
    printf "  %-14s %s\n" "用户数量:"  "$user_count"
    hr
    printf "  %-14s %s\n" "Xray 版本:" "$xray_ver"
    printf "  %-14s %s\n" "服务状态:"  "$svc_status"
    hr
}

# ============================================================
#  用户操作
# ============================================================
list_users() {
    title "===== 当前用户列表 ====="
    local count
    count=$(jq '.inbounds[0].settings.clients | length' "$CONFIG")
    if [[ "$count" -eq 0 ]]; then
        warn "暂无用户"
        return
    fi
    printf "%-4s %-28s %s\n" "No." "Email" "UUID"
    hr
    jq -r '.inbounds[0].settings.clients[] | "\(.email) \(.id)"' "$CONFIG" \
        | awk '{printf "%-4d %-28s %s\n", NR, $1, $2}'
    hr
    info "共 $count 个用户"
}

add_user() {
    title "===== 新增用户 ====="
    read -rp "输入用户名(email): " EMAIL
    if [[ -z "$EMAIL" ]]; then
        warn "用户名不能为空"
        return
    fi

    local exists
    exists=$(jq -r --arg e "$EMAIL" \
        '.inbounds[0].settings.clients[] | select(.email==$e) | .email' "$CONFIG")
    if [[ -n "$exists" ]]; then
        error "用户 $EMAIL 已存在"
        return
    fi

    local UUID
    UUID=$(cat /proc/sys/kernel/random/uuid)

    safe_jq_write \
        ".inbounds[0].settings.clients += \
         [{\"id\":\"$UUID\",\"flow\":\"xtls-rprx-vision\",\"email\":\"$EMAIL\"}]" \
        || return 1

    systemctl restart xray
    info "新增成功"
    hr
    printf "  %-10s %s\n" "Email:" "$EMAIL"
    printf "  %-10s %s\n" "UUID:"  "$UUID"
    hr
}

modify_user() {
    title "===== 修改用户 ====="
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

    read -rp "新用户名(email，留空保持不变): " NEW_EMAIL
    [[ -z "$NEW_EMAIL" ]] && NEW_EMAIL="$OLD_EMAIL"

    local UUID
    UUID=$(jq -r --arg e "$OLD_EMAIL" \
        '.inbounds[0].settings.clients[] | select(.email==$e) | .id' "$CONFIG")

    read -rp "是否重新生成 UUID? [y/N]: " regen
    [[ "$regen" == "y" ]] && UUID=$(cat /proc/sys/kernel/random/uuid)

    safe_jq_write \
        "(.inbounds[0].settings.clients[] | select(.email==\"$OLD_EMAIL\") | .email) = \"$NEW_EMAIL\" |
         (.inbounds[0].settings.clients[] | select(.email==\"$NEW_EMAIL\") | .id) = \"$UUID\"" \
        || return 1

    systemctl restart xray
    info "修改完成"
    hr
    printf "  %-10s %s\n" "Email:" "$NEW_EMAIL"
    printf "  %-10s %s\n" "UUID:"  "$UUID"
    hr
}

delete_user() {
    title "===== 删除用户 ====="
    list_users
    read -rp "输入要删除的用户名(email，留空取消): " EMAIL
    [[ -z "$EMAIL" ]] && warn "已取消" && return

    local exists
    exists=$(jq -r --arg e "$EMAIL" \
        '.inbounds[0].settings.clients[] | select(.email==$e) | .email' "$CONFIG")
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

# ============================================================
#  全局配置操作
# ============================================================
modify_port() {
    title "===== 修改监听端口 ====="
    local cur_port
    cur_port=$(jq -r '.inbounds[0].port' "$CONFIG")
    echo "当前端口: $cur_port"
    read -rp "新端口（留空取消）: " NEW_PORT
    [[ -z "$NEW_PORT" ]] && warn "已取消" && return

    if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || (( NEW_PORT < 1 || NEW_PORT > 65535 )); then
        error "端口号无效: $NEW_PORT（范围 1-65535）"
        return
    fi

    safe_jq_write ".inbounds[0].port = $NEW_PORT" || return 1
    systemctl restart xray
    info "端口已更改: $cur_port → $NEW_PORT，Xray 已重启"
}

modify_domain() {
    title "===== 修改目标域名 / SNI ====="
    local cur_dest cur_sni
    cur_dest=$(jq -r '.inbounds[0].streamSettings.realitySettings.dest' "$CONFIG")
    cur_sni=$(jq -r '.inbounds[0].streamSettings.realitySettings.serverNames[0]' "$CONFIG")

    echo "当前目标域名: $cur_dest"
    echo "当前 SNI:      $cur_sni"
    hr

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
    printf "  %-12s %s\n" "目标域名:" "${NEW_DEST}:443"
    printf "  %-12s %s\n" "SNI:"      "$NEW_SNI"
}

regen_keys() {
    title "===== 重新生成 x25519 密钥对 ====="
    if [[ ! -x "$XRAY_BIN" ]]; then
        error "xray 二进制不存在: $XRAY_BIN"
        return
    fi

    warn "重新生成密钥后，所有客户端需同步更新公钥才能连接！"
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
    info "密钥对已更新，Xray 已重启"
    hr
    printf "  %-10s %s\n" "私钥:" "$PRIVATE_KEY"
    printf "  %-10s %s\n" "公钥:" "$PUBLIC_KEY"
    hr
    warn "请将公钥更新到所有客户端配置中！"
}

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
        bak_time=$(stat -c "%y" "$bak" 2>/dev/null | cut -d'.' -f1 || echo "未知时间")
        printf "  %d. %-50s [%s]\n" "$i" "$(basename "$bak")" "$bak_time"
        bak_list+=("$bak")
        ((i++))
    done <<< "$backups"
    hr

    read -rp "选择序号（留空取消）: " sel
    [[ -z "$sel" ]] && warn "已取消" && return

    if ! [[ "$sel" =~ ^[0-9]+$ ]] || (( sel < 1 || sel > ${#bak_list[@]} )); then
        error "无效序号"
        return
    fi

    local chosen="${bak_list[$((sel-1))]}"
    warn "将还原: $chosen"
    read -rp "确认? [y/N]: " confirm
    [[ "$confirm" != "y" ]] && warn "已取消" && return

    cp "$CONFIG" "${CONFIG}.before_restore.$(date +%Y%m%d_%H%M%S)"
    cp "$chosen" "$CONFIG"
    systemctl restart xray
    info "已还原备份，Xray 已重启"
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
    echo "  • xm 快捷键:      $SYMLINK"
    echo "  • 本脚本:         $SCRIPT_PATH"
    hr
    echo ""

    # 两次确认
    read -rp "第一次确认：确定要完整卸载 Xray? [yes/N]: " c1
    if [[ "$c1" != "yes" ]]; then
        warn "已取消卸载"
        return
    fi

    read -rp "第二次确认：此操作不可恢复，继续? [yes/N]: " c2
    if [[ "$c2" != "yes" ]]; then
        warn "已取消卸载"
        return
    fi

    echo ""
    warn "开始卸载，请稍候..."
    echo ""

    # ---------- 1. 停止并禁用服务 ----------
    if systemctl is-active --quiet xray 2>/dev/null; then
        systemctl stop xray
        info "Xray 服务已停止"
    fi
    if systemctl is-enabled --quiet xray 2>/dev/null; then
        systemctl disable xray
        info "Xray 开机自启已禁用"
    fi

    # ---------- 2. 删除 systemd 服务文件 ----------
    local service_dirs=(
        "/etc/systemd/system"
        "/lib/systemd/system"
        "/usr/lib/systemd/system"
    )
    for dir in "${service_dirs[@]}"; do
        for svc in xray.service "xray@.service"; do
            if [[ -f "$dir/$svc" ]]; then
                rm -f "$dir/$svc"
                info "已删除: $dir/$svc"
            fi
        done
    done
    systemctl daemon-reload
    info "systemd 已重载"

    # ---------- 3. 删除二进制 ----------
    for bin in /usr/local/bin/xray /usr/local/bin/xray-bootarg; do
        if [[ -f "$bin" ]]; then
            rm -f "$bin"
            info "已删除: $bin"
        fi
    done

    # ---------- 4. 删除规则 dat 文件 ----------
    for dat in /usr/local/share/xray/geoip.dat /usr/local/share/xray/geosite.dat; do
        if [[ -f "$dat" ]]; then
            rm -f "$dat"
            info "已删除: $dat"
        fi
    done
    rmdir /usr/local/share/xray 2>/dev/null && info "已删除: /usr/local/share/xray" || true

    # ---------- 5. 备份配置目录后删除 ----------
    if [[ -d "/usr/local/etc/xray" ]]; then
        local cfg_backup="/root/xray_config_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
        if tar -czf "$cfg_backup" -C "/usr/local/etc" xray 2>/dev/null; then
            info "配置已备份至: $cfg_backup"
        else
            warn "配置备份失败，跳过（直接删除）"
        fi
        rm -rf /usr/local/etc/xray
        info "已删除配置目录: /usr/local/etc/xray"
    fi

    # ---------- 6. 删除日志目录 ----------
    if [[ -d "/var/log/xray" ]]; then
        rm -rf /var/log/xray
        info "已删除日志目录: /var/log/xray"
    fi

    # ---------- 7. 可选：删除 xray-script ----------
    if [[ -d "/usr/local/etc/xray-script" ]]; then
        read -rp "是否同时删除 xray-script (/usr/local/etc/xray-script)? [y/N]: " del_script
        if [[ "$del_script" == "y" ]]; then
            rm -rf /usr/local/etc/xray-script
            info "已删除: /usr/local/etc/xray-script"
        fi
    fi

    # ---------- 8. 删除 xm 快捷键软链接 ----------
    if [[ -L "$SYMLINK" ]]; then
        rm -f "$SYMLINK"
        info "已删除快捷键: $SYMLINK"
    fi

    # ---------- 9. 清理 PATH hash ----------
    hash -r 2>/dev/null || true

    echo ""
    hr
    info "Xray 已完整卸载完成"
    [[ -f "$cfg_backup" ]] && warn "配置备份保留于: $cfg_backup"
    hr
    echo ""

    # ---------- 10. 可选：删除本脚本 ----------
    read -rp "是否同时删除本管理脚本 ($SCRIPT_PATH)? [y/N]: " del_self
    if [[ "$del_self" == "y" ]]; then
        (sleep 1 && rm -f "$SCRIPT_PATH") &
        info "本脚本将在 1 秒后自动删除"
    fi

    echo ""
    info "感谢使用 Xray PRO MAX v5，再见！"
    exit 0
}

# ============================================================
#  安装 / 更新
# ============================================================
install_xray() {
    title "===== 安装 / 重装 Xray ====="
    if systemctl is-active --quiet xray 2>/dev/null; then
        warn "检测到 Xray 正在运行，重装只覆盖二进制，配置文件保留"
    fi
    read -rp "确认继续? [y/N]: " confirm
    [[ "$confirm" != "y" ]] && warn "已取消" && return
    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
    info "安装完成"
}

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

    if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        error "版本号格式不正确: $VERSION（应为 vX.Y.Z）"
        return
    fi

    bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" \
        @ install -u root -v "$VERSION"
    info "已更新到 $VERSION"
}

update_dat() {
    local script="/usr/local/etc/xray-script/update-dat.sh"
    if [[ ! -f "$script" ]]; then
        error "规则更新脚本不存在: $script"
        return
    fi
    bash "$script"
    info "规则已更新"
}

# ============================================================
#  入口
# ============================================================
preflight
menu
