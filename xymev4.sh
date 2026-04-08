#!/usr/bin/env bash
set -e

CONFIG="/usr/local/etc/xray/config.json"

# ===== 菜单 =====
menu() {
    echo ""
    echo "====== Xray PRO MAX v4 ======"
    echo "1. 安装 / 重装"
    echo "2. 更新核心"
    echo "3. 更新规则"
    echo "4. 查看状态"
    echo "5. 用户管理"
    echo "0. 退出"
    echo "============================="
    read -p "选择: " num

    case "$num" in
        1) install_xray ;;
        2) upgrade_xray ;;
        3) update_dat ;;
        4) systemctl status xray --no-pager ;;
        5) user_menu ;;
        0) exit ;;
    esac
}

# ===== 用户菜单 =====
user_menu() {
    echo ""
    echo "------ 用户管理 ------"
    echo "1. 查看用户"
    echo "2. 新增用户"
    echo "3. 修改用户"
    echo "4. 删除用户"
    echo "0. 返回"
    read -p "选择: " u

    case "$u" in
        1) list_users ;;
        2) add_user ;;
        3) modify_user ;;
        4) delete_user ;;
        0) menu ;;
    esac
}

# ===== 查看用户 =====
list_users() {
    echo "当前用户："
    jq -r '.inbounds[0].settings.clients[] | "\(.email) | \(.id)"' $CONFIG
}

# ===== 新增用户 =====
add_user() {
    read -p "输入用户名(email): " EMAIL
    UUID=$(cat /proc/sys/kernel/random/uuid)

    jq ".inbounds[0].settings.clients += [{\"id\":\"$UUID\",\"flow\":\"xtls-rprx-vision\",\"email\":\"$EMAIL\"}]" \
    $CONFIG > tmp.json && mv tmp.json $CONFIG

    systemctl restart xray

    echo "新增成功：$EMAIL | $UUID"
}

# ===== 删除用户 =====
delete_user() {
    list_users
    read -p "输入要删除的用户名(email): " EMAIL

    jq "del(.inbounds[0].settings.clients[] | select(.email==\"$EMAIL\"))" \
    $CONFIG > tmp.json && mv tmp.json $CONFIG

    systemctl restart xray
    echo "已删除: $EMAIL"
}

# ===== 修改用户 =====
modify_user() {

    list_users
    read -p "输入要修改的用户名(email): " OLD_EMAIL

    read -p "新用户名(email): " NEW_EMAIL
    read -p "新端口: " NEW_PORT
    read -p "新域名: " NEW_DOMAIN

    UUID=$(cat /proc/sys/kernel/random/uuid)
    XRAY_BIN="/usr/local/bin/xray"

    KEYS=$($XRAY_BIN x25519)
    PRIVATE_KEY=$(echo "$KEYS" | grep "Private key" | awk '{print $3}')

    # 修改用户
    jq "(.inbounds[0].settings.clients[] | select(.email==\"$OLD_EMAIL\") | .email)=\"$NEW_EMAIL\" |
        (.inbounds[0].settings.clients[] | select(.email==\"$NEW_EMAIL\") | .id)=\"$UUID\"" \
        $CONFIG > tmp.json && mv tmp.json $CONFIG

    # 修改端口+域名+密钥
    jq ".inbounds[0].port=$NEW_PORT |
        .inbounds[0].streamSettings.realitySettings.dest=\"$NEW_DOMAIN:443\" |
        .inbounds[0].streamSettings.realitySettings.serverNames=[\"$NEW_DOMAIN\"] |
        .inbounds[0].streamSettings.realitySettings.privateKey=\"$PRIVATE_KEY\"" \
        $CONFIG > tmp.json && mv tmp.json $CONFIG

    systemctl restart xray

    echo "修改完成"
    echo "新UUID: $UUID"
}

# ===== 占位函数（兼容你原脚本）=====
install_xray(){ bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install; }
upgrade_xray(){ echo "获取可用版本..."
    curl -s https://api.github.com/repos/XTLS/Xray-core/releases \
    | grep tag_name | cut -d '"' -f 4 | head -n 10

    read -p "输入要升级的版本号（例如 v1.8.10）: " VERSION

    if [[ -z "$VERSION" ]]; then
        echo "取消"
        exit 1
    fi

    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root -v $VERSION; }
update_dat(){ bash /usr/local/etc/xray-script/update-dat.sh; }

menu

ln -sf /root/xray_reality_pro_max_v4.sh /usr/local/bin/xm
