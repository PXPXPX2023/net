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

show_status() {
    pf_ip=$(ip -4 -o addr show dev pf-public 2>/dev/null | awk 'NR == 1 { split($4, address, "/"); print address[1] }')
    route_result=$(ip -4 route get 1.1.1.1 2>/dev/null | sed -n '1p')

    printf '\n当前状态\n'
    printf '%s\n' '----------------------------------------'

    if [ -n "$pf_ip" ]; then
        printf 'Pathfabric 公网 IPv4：%s\n' "$pf_ip"
    else
        printf '%s\n' 'Pathfabric 公网 IPv4：未检测到 pf-public 接口'
    fi

    if [ -n "$pf_ip" ] && printf '%s\n' "$route_result" | grep -Fq "src $pf_ip"; then
        printf '%s\n' '普通出站模式：Pathfabric 出口（tunnel）'
    elif [ -n "$route_result" ]; then
        printf '%s\n' '普通出站模式：VPS 原出口（default）'
    else
        printf '%s\n' '普通出站模式：无法检测'
    fi

    if [ -n "$route_result" ]; then
        printf '当前路由：%s\n' "$route_result"
    fi
    printf '%s\n\n' '----------------------------------------'
}

switch_mode() {
    requested_mode=$1

    case "$requested_mode" in
        tunnel)
            printf '%s\n' '正在切换到 Pathfabric 出口……'
            ;;
        default)
            printf '%s\n' '正在切换回 VPS 原出口……'
            ;;
        *)
            fail "未知模式：$requested_mode"
            ;;
    esac

    "$installer" --switch-gateway --unattended --default-gateway="$requested_mode"
    result=$?

    if [ "$result" -ne 0 ]; then
        fail "切换失败。请查看上方 Pathfabric 官方安装器输出；自动回滚可能仍在处理。"
    fi

    printf '%s\n' '切换完成。'
    show_status
}

if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo "$0" "$@"
    fi
    fail '请以 root 用户运行此脚本。'
fi

[ -f /etc/pathfabric/customer-installation.conf ] || \
    fail '没有检测到 Pathfabric 安装状态，请先完成 Pathfabric 官方安装。'

installer=$(find_installer) || \
    fail '找不到 pathfabric-install.sh。请把本脚本放到官方安装器旁边，或设置 PATHFABRIC_INSTALLER。'

if [ ! -x "$installer" ]; then
    chmod 700 "$installer" || fail '无法为 Pathfabric 官方安装器设置执行权限。'
fi

case "${1:-}" in
    1|pathfabric|tunnel)
        switch_mode tunnel
        exit 0
        ;;
    2|original|provider|default)
        switch_mode default
        exit 0
        ;;
    3|status)
        show_status
        exit 0
        ;;
    -h|--help|help)
        printf '%s\n' "用法：$0 [pathfabric|original|status]"
        printf '%s\n' '  pathfabric  普通出站流量改走 Pathfabric'
        printf '%s\n' '  original    普通出站流量改走 VPS 原网络'
        printf '%s\n' '  status      查看当前出站状态'
        exit 0
        ;;
    '')
        ;;
    *)
        fail "未知选项：$1。可用选项为 pathfabric、original 或 status。"
        ;;
esac

show_status
printf '%s\n' '说明：本脚本只切换 VPS 的普通出站网络，不修改 Xray/REALITY 配置。'
printf '%s\n' '请选择：'
printf '%s\n' '  1) 切换到 Pathfabric 出口（tunnel）'
printf '%s\n' '  2) 切换回 VPS 原出口（default）'
printf '%s\n' '  3) 只查看当前状态'
printf '%s\n' '  0) 退出'
printf '输入 0-3：'
IFS= read -r choice

case "$choice" in
    1)
        switch_mode tunnel
        ;;
    2)
        switch_mode default
        ;;
    3)
        show_status
        ;;
    0|q|Q)
        printf '%s\n' '已退出，没有修改网络。'
        ;;
    *)
        fail '输入无效，没有修改网络。'
        ;;
esac
