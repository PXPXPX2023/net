#!/bin/sh


set -u

fail() {
    printf '\n错误：%s\n' "$1" >&2
    exit 1
}

find_installer() {
    if [ -n "${PATHFABRIC_INSTALLER:-}" ] && [ -f "$PATHFABRIC_INSTALLER" ]; then
        printf '%s\n' "$PATHFABRIC_INSTALLER"
        return 0
    fi

    script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)
    if [ -n "${script_dir:-}" ] && [ -f "$script_dir/pathfabric-install.sh" ]; then
        printf '%s\n' "$script_dir/pathfabric-install.sh"
        return 0
    fi

    if [ -f /root/pathfabric-install.sh ]; then
        printf '%s\n' /root/pathfabric-install.sh
        return 0
    fi

    return 1
}

collect_state() {
    pf_ip=$(ip -4 -o addr show dev pf-public 2>/dev/null | \
        awk 'NR == 1 { split($4, address, "/"); print address[1] }')

    provider_route=$(ip -4 route show table main default 2>/dev/null | sed -n '1p')
    provider_dev=$(printf '%s\n' "$provider_route" | \
        awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')

    if [ -n "$provider_dev" ]; then
        provider_ip=$(ip -4 -o addr show dev "$provider_dev" scope global 2>/dev/null | \
            awk 'NR == 1 { split($4, address, "/"); print address[1] }')
    else
        provider_ip=''
    fi

    ordinary_route=$(ip -4 route get 1.1.1.1 2>/dev/null | sed -n '1p')
    xray_state=$(systemctl is-active xray.service 2>/dev/null || true)
    xray_address=$(ss -H -lntp 2>/dev/null | \
        awk '$4 ~ /:443$/ && $0 ~ /xray/ { print $4; exit }')

    xray_all_addresses=no
    case "$xray_address" in
        '*:443'|'0.0.0.0:443'|'[::]:443')
            xray_all_addresses=yes
            ;;
    esac

    outbound_mode=unknown
    if [ -n "$pf_ip" ] && printf '%s\n' "$ordinary_route" | grep -Fq "src $pf_ip"; then
        outbound_mode=tunnel
    elif [ -n "$ordinary_route" ]; then
        outbound_mode=default
    fi
}

show_status() {
    collect_state

    printf '\n当前状态\n'
    printf '%s\n' '--------------------------------------------------'
    printf 'Pathfabric 入口 IP：%s\n' "${pf_ip:-未检测到}"
    printf 'VPS 原入口 IP：     %s\n' "${provider_ip:-未检测到}"

    case "$outbound_mode" in
        tunnel)
            printf '%s\n' 'VPS 普通出站：      Pathfabric（tunnel）'
            ;;
        default)
            printf '%s\n' 'VPS 普通出站：      VPS 原线路（default）'
            ;;
        *)
            printf '%s\n' 'VPS 普通出站：      无法检测'
            ;;
    esac

    if [ "$xray_state" = active ]; then
        printf '%s\n' 'Xray 服务：         运行中（active）'
    else
        printf 'Xray 服务：         %s\n' "${xray_state:-未检测到}"
    fi

    if [ "$xray_all_addresses" = yes ]; then
        printf 'Xray TCP 443：       %s（两个入口 IP 均可连接）\n' "$xray_address"
    elif [ -n "$xray_address" ]; then
        printf 'Xray TCP 443：       %s（仅绑定特定地址）\n' "$xray_address"
    else
        printf '%s\n' 'Xray TCP 443：       未检测到监听'
    fi
    printf '%s\n' '--------------------------------------------------'
}

verify_reality_entry() {
    collect_state

    [ -n "$pf_ip" ] || fail '没有检测到 Pathfabric 的 pf-public 公网 IPv4。'
    [ -n "$provider_ip" ] || fail '没有检测到 VPS 原公网 IPv4。'
    [ "$xray_state" = active ] || fail 'xray.service 当前没有运行。'
    [ "$xray_all_addresses" = yes ] || \
        fail 'Xray 没有监听全部地址的 TCP 443；为避免破坏现有配置，脚本已停止。'
}

switch_gateway() {
    gateway_mode=$1

    "$installer" --switch-gateway --unattended --default-gateway="$gateway_mode"
    result=$?
    [ "$result" -eq 0 ] || \
        fail 'Pathfabric 切换失败。请检查上方官方安装器输出，自动回滚可能仍在处理。'
}

print_client_choice() {
    selected_name=$1
    selected_ip=$2

    printf '\n%s\n' '服务器端切换成功。'
    printf '客户端请选择：%s\n' "$selected_name"
    printf '客户端“服务器地址”：%s\n' "$selected_ip"
    printf '%s\n' 'UUID、公钥、端口、serverName 和 shortId 保持原样。'
}

apply_mode() {
    requested_mode=$1
    verify_reality_entry

    case "$requested_mode" in
        full)
            printf '%s\n' '正在启用：Pathfabric 入站 + Pathfabric 出站……'
            switch_gateway tunnel
            collect_state
            print_client_choice 'Pathfabric IP 节点' "$pf_ip"
            ;;
        entry)
            printf '%s\n' '正在启用：Pathfabric 入站 + VPS 原出站……'
            switch_gateway default
            collect_state
            print_client_choice 'Pathfabric IP 节点' "$pf_ip"
            ;;
        original)
            printf '%s\n' '正在恢复：VPS 原 IP 入站 + VPS 原出站……'
            switch_gateway default
            collect_state
            print_client_choice 'VPS 原 IP 节点' "$provider_ip"
            ;;
        *)
            fail "未知模式：$requested_mode"
            ;;
    esac

    show_status
}

show_help() {
    printf '%s\n' "用法：$0 [full|entry|original|status]"
    printf '%s\n' '  full      Pathfabric 入站 + Pathfabric 出站'
    printf '%s\n' '  entry     Pathfabric 入站 + VPS 原出站'
    printf '%s\n' '  original  VPS 原 IP 入站 + VPS 原出站'
    printf '%s\n' '  status    只查看当前状态'
}

case "${1:-}" in
    -h|--help|help)
        show_help
        exit 0
        ;;
esac

if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo "$0" "$@"
    fi
    fail '请以 root 用户运行此脚本。'
fi

[ -f /etc/pathfabric/customer-installation.conf ] || \
    fail '没有检测到 Pathfabric 安装状态，请先完成 Pathfabric 官方安装。'

installer=$(find_installer) || \
    fail '找不到 pathfabric-install.sh。请把 pas5.sh 放到官方安装器旁边。'

if [ ! -x "$installer" ]; then
    chmod 700 "$installer" || fail '无法为 Pathfabric 官方安装器设置执行权限。'
fi

case "${1:-}" in
    1|full|pathfabric)
        apply_mode full
        exit 0
        ;;
    2|entry|inbound)
        apply_mode entry
        exit 0
        ;;
    3|original|provider|default)
        apply_mode original
        exit 0
        ;;
    4|status)
        show_status
        exit 0
        ;;
    '')
        ;;
    *)
        fail "未知选项：$1。请使用 full、entry、original 或 status。"
        ;;
esac

show_status
printf '\n%s\n' '请选择模式：'
printf '%s\n' '  1) Pathfabric 入站 + Pathfabric 出站'
printf '%s\n' '  2) Pathfabric 入站 + VPS 原出站（当前 default 逻辑）'
printf '%s\n' '  3) VPS 原 IP 入站 + VPS 原出站'
printf '%s\n' '  4) 只查看状态'
printf '%s\n' '  0) 退出'
printf '输入 0-4：'
IFS= read -r choice

case "$choice" in
    1)
        apply_mode full
        ;;
    2)
        apply_mode entry
        ;;
    3)
        apply_mode original
        ;;
    4)
        show_status
        ;;
    0|q|Q)
        printf '%s\n' '已退出，没有修改网络。'
        ;;
    *)
        fail '输入无效，没有修改网络。'
        ;;
esac
