#!/bin/sh
# PAS7_MANAGED=1

# Pathfabric + Xray/REALITY network mode and MTU manager.
# Pathfabric route changes are delegated to its official installer. PAS7 only
# manages its own helper files and the customer-side WireGuard MTU policy.

set -u

PAS7_VERSION='7.0.0'
PAS7_BIN=${PAS7_MANAGED_BIN:-/usr/local/sbin/pas}
# Keep PAS6 paths and unit names to upgrade in place without duplicate timers.
PAS7_CONFIG=${PAS7_CONFIG_FILE:-/etc/pas6-pathfabric.conf}
PAS7_SYSTEMD_DIR=${PAS7_SYSTEMD_DIR:-/etc/systemd/system}
PAS7_SERVICE='pas6-pathfabric-mtu.service'
PAS7_TIMER='pas6-pathfabric-mtu.timer'
PAS7_PF_SERVICE='pathfabric-customer-network.service'
PAS7_PF_STATE=${PAS7_PATHFABRIC_STATE:-/etc/pathfabric/customer-installation.conf}
PAS7_XRAY_SERVICE=${PAS7_XRAY_SERVICE:-xray.service}
PAS7_DROPIN_DIR="$PAS7_SYSTEMD_DIR/$PAS7_PF_SERVICE.d"
PAS7_DROPIN_FILE="$PAS7_DROPIN_DIR/90-pas6-mtu.conf"
PAS7_SERVICE_FILE="$PAS7_SYSTEMD_DIR/$PAS7_SERVICE"
PAS7_TIMER_FILE="$PAS7_SYSTEMD_DIR/$PAS7_TIMER"

say() {
    printf '%s\n' "$*"
}

warn() {
    printf '警告：%s\n' "$*" >&2
}

fail() {
    printf '\n错误：%s\n' "$*" >&2
    exit 1
}

is_uint() {
    case ${1:-} in
        ''|*[!0-9]*) return 1 ;;
        *) return 0 ;;
    esac
}

need_command() {
    command -v "$1" >/dev/null 2>&1 || fail "缺少必要命令：$1"
}

absolute_self_path() {
    self_dir=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd) || return 1
    printf '%s/%s\n' "$self_dir" "$(basename -- "$0")"
}

config_value() {
    key=$1
    [ -f "$PAS7_CONFIG" ] || return 1
    awk -F= -v wanted="$key" '$1 == wanted { sub(/^[^=]*=/, ""); print; exit }' "$PAS7_CONFIG"
}

find_installer() {
    if [ -n "${PATHFABRIC_INSTALLER:-}" ] && [ -f "$PATHFABRIC_INSTALLER" ]; then
        printf '%s\n' "$PATHFABRIC_INSTALLER"
        return 0
    fi

    configured_installer=$(config_value INSTALLER_PATH 2>/dev/null || true)
    if [ -n "$configured_installer" ] && [ -f "$configured_installer" ]; then
        printf '%s\n' "$configured_installer"
        return 0
    fi

    current_dir=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)
    if [ -n "${current_dir:-}" ] && [ -f "$current_dir/pathfabric-install.sh" ]; then
        printf '%s\n' "$current_dir/pathfabric-install.sh"
        return 0
    fi

    if [ -f /root/pathfabric-install.sh ]; then
        printf '%s\n' /root/pathfabric-install.sh
        return 0
    fi

    return 1
}

endpoint_details() {
    raw_endpoint=$(wg show pf-wg endpoints 2>/dev/null | awk 'NR == 1 { print $2 }')
    [ -n "$raw_endpoint" ] && [ "$raw_endpoint" != '(none)' ] || return 1

    case "$raw_endpoint" in
        \[*\]:*)
            hub_family=6
            hub_ip=${raw_endpoint#\[}
            hub_ip=${hub_ip%%\]*}
            wg_overhead=80
            ;;
        *:*)
            hub_family=4
            hub_ip=${raw_endpoint%:*}
            wg_overhead=60
            ;;
        *)
            return 1
            ;;
    esac

    [ -n "$hub_ip" ]
}

route_value() {
    route_text=$1
    route_key=$2
    printf '%s\n' "$route_text" | awk -v wanted="$route_key" \
        '{ for (i = 1; i <= NF; i++) if ($i == wanted) { print $(i + 1); exit } }'
}

link_mtu_for_dev() {
    mtu_dev=$1
    ip -o link show dev "$mtu_dev" 2>/dev/null | \
        awk '{ for (i = 1; i <= NF; i++) if ($i == "mtu") { print $(i + 1); exit } }'
}

probe_ipv4_path_mtu() {
    probe_host=$1
    probe_upper=$2

    is_uint "$probe_upper" || return 1
    [ "$probe_upper" -ge 576 ] || return 1
    command -v ping >/dev/null 2>&1 || return 1

    probe_low=576
    probe_high=$probe_upper
    probe_best=0

    while [ "$probe_low" -le "$probe_high" ]; do
        probe_mid=$(((probe_low + probe_high) / 2))
        probe_payload=$((probe_mid - 28))

        if ping -4 -c 1 -W 1 -M do -s "$probe_payload" "$probe_host" >/dev/null 2>&1; then
            probe_best=$probe_mid
            probe_low=$((probe_mid + 1))
        else
            probe_high=$((probe_mid - 1))
        fi
    done

    [ "$probe_best" -ge 576 ] || return 1
    printf '%s\n' "$probe_best"
}

minimum_positive() {
    minimum=''
    for candidate in "$@"; do
        if is_uint "$candidate" && [ "$candidate" -gt 0 ]; then
            if [ -z "$minimum" ] || [ "$candidate" -lt "$minimum" ]; then
                minimum=$candidate
            fi
        fi
    done
    [ -n "$minimum" ] || return 1
    printf '%s\n' "$minimum"
}

write_config() {
    installer_path=$1
    config_hub_ip=$2
    config_hub_family=$3
    config_underlay_dev=$4
    config_underlay_mtu=$5
    config_wg_mtu=$6
    config_mtu_mode=$7

    config_dir=$(dirname -- "$PAS7_CONFIG")
    mkdir -p "$config_dir" || fail "无法创建配置目录：$config_dir"
    config_tmp=$(mktemp "$config_dir/.pas6-pathfabric.conf.XXXXXX") || fail '无法创建临时配置文件。'

    umask 077
    {
        printf 'PAS7_VERSION=%s\n' "$PAS7_VERSION"
        printf 'INSTALLER_PATH=%s\n' "$installer_path"
        printf 'HUB_IP=%s\n' "$config_hub_ip"
        printf 'HUB_FAMILY=%s\n' "$config_hub_family"
        printf 'UNDERLAY_DEV=%s\n' "$config_underlay_dev"
        printf 'UNDERLAY_MTU=%s\n' "$config_underlay_mtu"
        printf 'WG_MTU=%s\n' "$config_wg_mtu"
        printf 'MTU_MODE=%s\n' "$config_mtu_mode"
    } >"$config_tmp" || {
        rm -f "$config_tmp"
        fail '无法写入 PAS7 配置。'
    }

    chmod 600 "$config_tmp" || {
        rm -f "$config_tmp"
        fail '无法保护 PAS7 配置权限。'
    }
    mv -f "$config_tmp" "$PAS7_CONFIG" || fail '无法安装 PAS7 配置。'
}

detect_mtu_profile() {
    detection_quiet=${1:-no}

    endpoint_details || fail '无法从 pf-wg 读取 Pathfabric Hub 端点。'

    if [ "$hub_family" -eq 4 ]; then
        route_line=$(ip -4 route get "$hub_ip" 2>/dev/null | sed -n '1p')
    else
        route_line=$(ip -6 route get "$hub_ip" 2>/dev/null | sed -n '1p')
    fi
    [ -n "$route_line" ] || fail '无法读取到 Pathfabric Hub 的底层路由。'

    underlay_dev=$(route_value "$route_line" dev)
    [ -n "$underlay_dev" ] || fail '无法识别 Pathfabric Hub 使用的底层网卡。'

    route_mtu=$(route_value "$route_line" mtu)
    dev_mtu=$(link_mtu_for_dev "$underlay_dev")
    is_uint "$dev_mtu" || fail "无法读取底层网卡 $underlay_dev 的 MTU。"

    probe_mtu=''
    if [ "$hub_family" -eq 4 ]; then
        if is_uint "$route_mtu" && [ "$route_mtu" -lt "$dev_mtu" ]; then
            probe_mtu=$route_mtu
        else
            probe_limit=$dev_mtu
            probe_mtu=$(probe_ipv4_path_mtu "$hub_ip" "$probe_limit" 2>/dev/null || true)
        fi

        refreshed_route=$(ip -4 route get "$hub_ip" 2>/dev/null | sed -n '1p')
        refreshed_mtu=$(route_value "$refreshed_route" mtu)
        if is_uint "$refreshed_mtu"; then
            route_mtu=$refreshed_mtu
        fi
    fi

    underlay_mtu=$(minimum_positive "$route_mtu" "$probe_mtu" "$dev_mtu") || \
        fail '无法确定到 Pathfabric Hub 的底层 MTU。'
    calculated_wg_mtu=$((underlay_mtu - wg_overhead))

    if [ "$calculated_wg_mtu" -gt 1420 ]; then
        calculated_wg_mtu=1420
    fi
    [ "$calculated_wg_mtu" -ge 1000 ] || \
        fail "自动计算的 WireGuard MTU 过低：$calculated_wg_mtu"

    installer=$(find_installer) || fail '找不到 pathfabric-install.sh。'
    write_config "$installer" "$hub_ip" "$hub_family" "$underlay_dev" "$underlay_mtu" "$calculated_wg_mtu" auto

    profile_underlay_mtu=$underlay_mtu
    profile_wg_mtu=$calculated_wg_mtu
    profile_hub_ip=$hub_ip
    profile_hub_family=$hub_family
    profile_underlay_dev=$underlay_dev
    profile_mtu_mode=auto

    if [ "$detection_quiet" != yes ]; then
        say ''
        say 'MTU 自动检测完成'
        say '--------------------------------------------------'
        say "Hub 端点：          $profile_hub_ip（IPv$profile_hub_family）"
        say "底层网卡：          $profile_underlay_dev"
        say "底层路径 MTU：      $profile_underlay_mtu"
        say "WireGuard 封装开销：$wg_overhead"
        say "pf-wg 目标 MTU：    $profile_wg_mtu"
        say '--------------------------------------------------'
    fi
}

load_or_detect_profile() {
    force_detection=${1:-no}
    endpoint_details || return 1

    saved_hub_ip=$(config_value HUB_IP 2>/dev/null || true)
    saved_hub_family=$(config_value HUB_FAMILY 2>/dev/null || true)
    saved_underlay_mtu=$(config_value UNDERLAY_MTU 2>/dev/null || true)
    saved_wg_mtu=$(config_value WG_MTU 2>/dev/null || true)
    saved_underlay_dev=$(config_value UNDERLAY_DEV 2>/dev/null || true)
    saved_mtu_mode=$(config_value MTU_MODE 2>/dev/null || true)

    case "$saved_mtu_mode" in
        auto|manual) ;;
        '') saved_mtu_mode=legacy ;;
        *) saved_mtu_mode=invalid ;;
    esac

    saved_mtu_valid=no
    if is_uint "$saved_wg_mtu" && \
       [ "$saved_wg_mtu" -ge 1000 ] && \
       [ "$saved_wg_mtu" -le 1420 ]; then
        saved_mtu_valid=yes
    fi

    if [ "$force_detection" != yes ] && \
       [ "$saved_hub_ip" = "$hub_ip" ] && \
       [ "$saved_hub_family" = "$hub_family" ] && \
       is_uint "$saved_underlay_mtu" && \
       [ "$saved_mtu_valid" = yes ] && \
       [ "$saved_mtu_mode" != invalid ]; then
        profile_hub_ip=$saved_hub_ip
        profile_hub_family=$saved_hub_family
        profile_underlay_mtu=$saved_underlay_mtu
        profile_wg_mtu=$saved_wg_mtu
        profile_underlay_dev=$saved_underlay_dev
        profile_mtu_mode=$saved_mtu_mode

        # PAS6 had no policy field. Preserve its effective value during upgrade
        # instead of unexpectedly changing a live tunnel.
        if [ "$saved_mtu_mode" = legacy ]; then
            profile_installer=$(find_installer) || return 1
            write_config "$profile_installer" "$profile_hub_ip" "$profile_hub_family" \
                "$profile_underlay_dev" "$profile_underlay_mtu" "$profile_wg_mtu" manual
            profile_mtu_mode=manual
        fi
        return 0
    fi

    # A provider-specified manual MTU remains authoritative if the hub endpoint
    # changes. Refresh path metadata, then restore the manual value.
    if [ "$force_detection" != yes ] && \
       { [ "$saved_mtu_mode" = manual ] || [ "$saved_mtu_mode" = legacy ]; } && \
       [ "$saved_mtu_valid" = yes ]; then
        preserved_wg_mtu=$saved_wg_mtu
        detect_mtu_profile yes
        write_config "$installer" "$profile_hub_ip" "$profile_hub_family" \
            "$profile_underlay_dev" "$profile_underlay_mtu" "$preserved_wg_mtu" manual
        profile_wg_mtu=$preserved_wg_mtu
        profile_mtu_mode=manual
        return 0
    fi

    detect_mtu_profile yes
}

current_interface_mtu() {
    link_mtu_for_dev pf-wg
}

apply_mtu_profile() {
    force_detection=${1:-no}
    load_or_detect_profile "$force_detection" || fail '无法加载或生成 MTU 配置。'

    current_mtu=$(current_interface_mtu)
    is_uint "$current_mtu" || fail '无法读取 pf-wg 当前 MTU。'

    if [ "$current_mtu" -ne "$profile_wg_mtu" ]; then
        ip link set dev pf-wg mtu "$profile_wg_mtu" || fail '无法修改 pf-wg MTU。'
    fi

    verified_mtu=$(current_interface_mtu)
    [ "$verified_mtu" = "$profile_wg_mtu" ] || \
        fail "pf-wg MTU 校验失败，当前为 ${verified_mtu:-未知}。"

    mtu_changed=no
    if [ "$current_mtu" -ne "$verified_mtu" ]; then
        mtu_changed=yes
    fi
}

collect_state() {
    pf_ip=$(ip -4 -o addr show dev pf-public 2>/dev/null | \
        awk 'NR == 1 { split($4, address, "/"); print address[1] }')

    provider_route=$(ip -4 route show table main default 2>/dev/null | sed -n '1p')
    provider_dev=$(route_value "$provider_route" dev)
    if [ -n "$provider_dev" ]; then
        provider_ip=$(ip -4 -o addr show dev "$provider_dev" scope global 2>/dev/null | \
            awk 'NR == 1 { split($4, address, "/"); print address[1] }')
    else
        provider_ip=''
    fi

    ordinary_route=$(ip -4 route get 1.1.1.1 2>/dev/null | sed -n '1p')
    xray_state=$(systemctl is-active "$PAS7_XRAY_SERVICE" 2>/dev/null || true)
    xray_address=$(ss -H -lntp 2>/dev/null | \
        awk '$4 ~ /:443$/ && $0 ~ /xray/ { print $4; exit }')
    actual_wg_mtu=$(current_interface_mtu 2>/dev/null || true)
    desired_wg_mtu=$(config_value WG_MTU 2>/dev/null || true)
    saved_underlay_mtu=$(config_value UNDERLAY_MTU 2>/dev/null || true)
    saved_mtu_mode=$(config_value MTU_MODE 2>/dev/null || true)

    xray_all_addresses=no
    case "$xray_address" in
        '*:443'|'0.0.0.0:443'|'[::]:443') xray_all_addresses=yes ;;
    esac

    outbound_mode=unknown
    if [ -n "$pf_ip" ] && printf '%s\n' "$ordinary_route" | grep -Fq "src $pf_ip"; then
        outbound_mode=tunnel
    elif [ -n "$ordinary_route" ]; then
        outbound_mode=default
    fi
}

unit_enabled_state() {
    enabled_state=$(systemctl is-enabled "$1" 2>/dev/null || true)
    if [ -n "$enabled_state" ]; then
        printf '%s\n' "$enabled_state"
    else
        printf 'disabled\n'
    fi
}

mtu_mode_description() {
    case ${1:-} in
        auto) printf '自动探测\n' ;;
        manual) printf '手动固定\n' ;;
        legacy|'') printf '继承旧配置\n' ;;
        *) printf '未知\n' ;;
    esac
}

show_status() {
    collect_state
    service_enabled=$(unit_enabled_state "$PAS7_SERVICE")
    timer_enabled=$(unit_enabled_state "$PAS7_TIMER")

    say ''
    say "PAS7 v$PAS7_VERSION 当前状态"
    say '--------------------------------------------------'
    say "Pathfabric 入口 IP： ${pf_ip:-未检测到}"
    say "VPS 原入口 IP：      ${provider_ip:-未检测到}"

    case "$outbound_mode" in
        tunnel) say 'VPS 普通出站：       Pathfabric（tunnel）' ;;
        default) say 'VPS 普通出站：       VPS 原线路（default）' ;;
        *) say 'VPS 普通出站：       无法检测' ;;
    esac

    say "底层路径 MTU：       ${saved_underlay_mtu:-未检测}"
    say "MTU 策略：            $(mtu_mode_description "$saved_mtu_mode")"
    say "pf-wg 当前/目标 MTU：${actual_wg_mtu:-未知}/${desired_wg_mtu:-未检测}"

    if [ "$actual_wg_mtu" = "$desired_wg_mtu" ] && [ -n "$actual_wg_mtu" ]; then
        say 'MTU 持久修复：       已生效'
    else
        say 'MTU 持久修复：       当前不一致'
    fi

    say "Xray 服务：          ${xray_state:-未检测到}"
    if [ "$xray_all_addresses" = yes ]; then
        say "Xray TCP 443：      $xray_address（两个入口 IP 均可连接）"
    elif [ -n "$xray_address" ]; then
        say "Xray TCP 443：      $xray_address（仅绑定特定地址）"
    else
        say 'Xray TCP 443：      未检测到监听'
    fi

    say "开机修复服务：       $service_enabled"
    say "周期修复定时器：     $timer_enabled"
    say '--------------------------------------------------'
}

verify_environment() {
    [ -f "$PAS7_PF_STATE" ] || fail '没有检测到 Pathfabric 安装状态。'
    ip link show dev pf-wg >/dev/null 2>&1 || fail '没有检测到 pf-wg 接口。'
    ip link show dev pf-public >/dev/null 2>&1 || fail '没有检测到 pf-public 接口。'
    installer=$(find_installer) || fail '找不到 pathfabric-install.sh。'
    [ -x "$installer" ] || chmod 700 "$installer" || fail '无法设置官方安装器权限。'
}

verify_reality() {
    collect_state
    [ -n "$pf_ip" ] || fail '没有检测到 Pathfabric 公网 IPv4。'
    [ -n "$provider_ip" ] || fail '没有检测到 VPS 原公网 IPv4。'
    [ "$xray_state" = active ] || fail "$PAS7_XRAY_SERVICE 当前没有运行。"
    [ "$xray_all_addresses" = yes ] || \
        fail 'Xray 没有监听全部地址的 TCP 443；PAS7 不会擅自改写 Xray 配置。'
}

write_persistence_units() {
    mkdir -p "$PAS7_SYSTEMD_DIR" "$PAS7_DROPIN_DIR" || fail '无法创建 systemd 配置目录。'

    service_tmp=$(mktemp "$PAS7_SYSTEMD_DIR/.pas6-service.XXXXXX") || fail '无法创建服务临时文件。'
    timer_tmp=$(mktemp "$PAS7_SYSTEMD_DIR/.pas6-timer.XXXXXX") || fail '无法创建定时器临时文件。'
    dropin_tmp=$(mktemp "$PAS7_DROPIN_DIR/.pas6-dropin.XXXXXX") || fail '无法创建后置修复临时文件。'

    {
        say '[Unit]'
        say 'Description=PAS7 Pathfabric WireGuard MTU repair'
        say 'Wants=network-online.target pathfabric-customer-network.service'
        say 'After=network-online.target pathfabric-customer-network.service'
        say "Before=$PAS7_XRAY_SERVICE"
        say "ConditionPathExists=$PAS7_PF_STATE"
        say ''
        say '[Service]'
        say 'Type=oneshot'
        say "ExecStart=$PAS7_BIN --systemd-repair"
        say ''
        say '[Install]'
        say 'WantedBy=multi-user.target'
    } >"$service_tmp"

    {
        say '[Unit]'
        say 'Description=Periodically verify PAS7 Pathfabric MTU'
        say ''
        say '[Timer]'
        say 'OnBootSec=20s'
        say 'OnUnitActiveSec=60s'
        say 'AccuracySec=5s'
        say 'Persistent=true'
        say "Unit=$PAS7_SERVICE"
        say ''
        say '[Install]'
        say 'WantedBy=timers.target'
    } >"$timer_tmp"

    {
        say '[Service]'
        say "ExecStartPost=-$PAS7_BIN --systemd-repair"
    } >"$dropin_tmp"

    chmod 644 "$service_tmp" "$timer_tmp" "$dropin_tmp" || fail '无法设置 systemd 文件权限。'
    mv -f "$service_tmp" "$PAS7_SERVICE_FILE" || fail '无法安装 PAS7 服务。'
    mv -f "$timer_tmp" "$PAS7_TIMER_FILE" || fail '无法安装 PAS7 定时器。'
    mv -f "$dropin_tmp" "$PAS7_DROPIN_FILE" || fail '无法安装 Pathfabric 后置修复。'
}

install_shortcut_and_persistence() {
    install_quiet=${1:-no}
    self_path=$(absolute_self_path) || fail '无法确定 pas7.sh 文件路径。'

    if [ -e "$PAS7_BIN" ] && \
       ! grep -Fqx '# PAS7_MANAGED=1' "$PAS7_BIN" 2>/dev/null && \
       ! grep -Fqx '# PAS6_MANAGED=1' "$PAS7_BIN" 2>/dev/null; then
        fail "$PAS7_BIN 已存在且不属于 PAS6/PAS7，为避免覆盖已停止。"
    fi

    if [ "$self_path" != "$PAS7_BIN" ]; then
        install -m 0755 "$self_path" "$PAS7_BIN" || fail '无法安装 pas 快捷命令。'
    else
        chmod 755 "$PAS7_BIN" || fail '无法修复 pas 快捷命令权限。'
    fi

    load_or_detect_profile no || fail 'MTU 自动检测失败。'
    write_persistence_units
    systemctl daemon-reload || fail 'systemd 重新加载失败。'
    systemctl enable "$PAS7_SERVICE" >/dev/null 2>&1 || fail '无法启用开机 MTU 修复服务。'
    systemctl enable --now "$PAS7_TIMER" >/dev/null 2>&1 || fail '无法启用 MTU 修复定时器。'
    systemctl start "$PAS7_SERVICE" || fail '首次 MTU 修复失败。'

    if [ "$install_quiet" != yes ]; then
        say ''
        say 'PAS7 已安装：'
        say "  快捷命令：$PAS7_BIN（直接输入 pas）"
        say '  开机修复：已启用'
        say '  周期检查：每 60 秒一次'
        say '  官方服务后置修复：已启用'
    fi
}

ensure_installed() {
    if [ ! -x "$PAS7_BIN" ] || \
       ! grep -Fqx '# PAS7_MANAGED=1' "$PAS7_BIN" 2>/dev/null || \
       [ ! -f "$PAS7_SERVICE_FILE" ] || \
       [ ! -f "$PAS7_TIMER_FILE" ] || \
       [ ! -f "$PAS7_DROPIN_FILE" ]; then
        install_shortcut_and_persistence no
    fi
}

restart_xray() {
    if systemctl is-active --quiet "$PAS7_XRAY_SERVICE"; then
        systemctl restart "$PAS7_XRAY_SERVICE" || fail 'Xray 重启失败。'
        systemctl is-active --quiet "$PAS7_XRAY_SERVICE" || fail 'Xray 重启后未恢复运行。'
        say 'Xray 已重启，旧 TCP 连接已释放，将重新协商 MSS。'
    fi
}

switch_gateway() {
    gateway_mode=$1
    "$installer" --switch-gateway --unattended --default-gateway="$gateway_mode"
    result=$?
    [ "$result" -eq 0 ] || \
        fail 'Pathfabric 切换失败。请检查官方安装器输出，自动回滚可能仍在处理。'
}

print_client_choice() {
    choice_name=$1
    choice_ip=$2
    say ''
    say '服务器端处理完成。'
    say "客户端请选择：$choice_name"
    say "客户端服务器地址：$choice_ip"
    say 'UUID、公钥、端口、serverName 和 shortId 保持不变。'
}

apply_mode() {
    requested_mode=$1
    verify_environment
    verify_reality

    case "$requested_mode" in
        full)
            say '正在启用：Pathfabric 入站 + Pathfabric 出站……'
            warn '此模式此前性能异常；Hub MTU 调整后请重新测试并记录结果。'
            switch_gateway tunnel
            ;;
        entry)
            say '正在启用：Pathfabric 入站 + VPS 原出站……'
            switch_gateway default
            ;;
        original)
            say '正在恢复：VPS 原 IP 入站 + VPS 原出站……'
            switch_gateway default
            ;;
        *)
            fail "未知模式：$requested_mode"
            ;;
    esac

    apply_mtu_profile no
    say "pf-wg MTU 已按$(mtu_mode_description "$profile_mtu_mode")策略校正为 $profile_wg_mtu。"
    restart_xray
    collect_state

    case "$requested_mode" in
        full|entry) print_client_choice 'Pathfabric IP 节点' "$pf_ip" ;;
        original) print_client_choice 'VPS 原 IP 节点' "$provider_ip" ;;
    esac
    show_status
}

set_manual_mtu() {
    requested_mtu=${1:-}
    is_uint "$requested_mtu" || fail 'MTU 必须是 1000 到 1420 之间的整数。'
    [ "$requested_mtu" -ge 1000 ] && [ "$requested_mtu" -le 1420 ] || \
        fail 'MTU 必须是 1000 到 1420 之间的整数。'

    verify_environment
    load_or_detect_profile no || fail '无法加载或生成 MTU 配置。'
    profile_installer=$(find_installer) || fail '找不到 pathfabric-install.sh。'
    write_config "$profile_installer" "$profile_hub_ip" "$profile_hub_family" \
        "$profile_underlay_dev" "$profile_underlay_mtu" "$requested_mtu" manual
    apply_mtu_profile no

    say "pf-wg MTU 已手动固定为 $requested_mtu。"
    say '该数值会在切换模式、Pathfabric 重建接口及 VPS 重启后自动恢复。'
    restart_xray
    show_status
}

enable_auto_mtu() {
    verify_environment
    detect_mtu_profile no
    apply_mtu_profile no
    say "已恢复自动探测策略，pf-wg MTU 设置为 $profile_wg_mtu。"
    restart_xray
    show_status
}

prompt_manual_mtu() {
    current_target=$(config_value WG_MTU 2>/dev/null || true)
    say ''
    say "当前目标 MTU：${current_target:-未检测}"
    say 'Pathfabric 网络团队当前建议值：1240'
    printf '输入要手动固定的 MTU（1000-1420，直接回车取消）：'
    IFS= read -r requested_mtu
    [ -n "$requested_mtu" ] || {
        say '已取消，没有修改 MTU。'
        return 0
    }
    set_manual_mtu "$requested_mtu"
}

systemd_repair() {
    [ -f "$PAS7_PF_STATE" ] || exit 0
    ip link show dev pf-wg >/dev/null 2>&1 || exit 0

    if ! load_or_detect_profile no; then
        warn 'systemd 修复无法加载 MTU 配置。'
        exit 0
    fi

    current_mtu=$(current_interface_mtu 2>/dev/null || true)
    if [ "$current_mtu" != "$profile_wg_mtu" ]; then
        if ip link set dev pf-wg mtu "$profile_wg_mtu"; then
            say "PAS7：已将 pf-wg MTU 从 ${current_mtu:-未知} 修复为 $profile_wg_mtu。"
        else
            warn 'systemd 修复无法修改 pf-wg MTU。'
        fi
    fi
    exit 0
}

remove_pas7() {
    say '这只会删除 PAS7 快捷命令和持久化修复，不会卸载 Pathfabric 或 Xray。'
    printf '确认删除 PAS7？[y/N]：'
    IFS= read -r answer
    case "$answer" in
        y|Y|yes|YES)
            systemctl disable --now "$PAS7_TIMER" >/dev/null 2>&1 || true
            systemctl disable --now "$PAS7_SERVICE" >/dev/null 2>&1 || true
            rm -f "$PAS7_TIMER_FILE" "$PAS7_SERVICE_FILE" "$PAS7_DROPIN_FILE" "$PAS7_CONFIG"
            rmdir "$PAS7_DROPIN_DIR" 2>/dev/null || true
            systemctl daemon-reload || true
            systemctl reset-failed "$PAS7_SERVICE" "$PAS7_TIMER" >/dev/null 2>&1 || true
            rm -f "$PAS7_BIN"
            say 'PAS7 已删除；Pathfabric 和 Xray 未被修改。'
            ;;
        *)
            say '已取消。'
            ;;
    esac
}

show_help() {
    say "PAS7 v$PAS7_VERSION"
    say "用法：$0 [entry|full|original|status|mtu|redetect|repair|uninstall]"
    say '  entry     Pathfabric 入站 + VPS 原出站（推荐）'
    say '  full      Pathfabric 入站 + Pathfabric 出站（实验）'
    say '  original  VPS 原 IP 入站 + VPS 原出站'
    say '  status    查看 IP、路由、Xray、MTU 与持久化状态'
    say '  mtu 1240  手动固定 pf-wg MTU，切换和重启后仍有效'
    say '  mtu auto  取消手动值，恢复自动路径 MTU 探测'
    say '  mtu status 查看当前 MTU 策略与状态'
    say '  redetect  mtu auto 的兼容别名'
    say '  repair    重装 pas 快捷命令和持久化修复'
    say '  uninstall 仅删除 PAS7，不卸载 Pathfabric/Xray'
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
    fail '请以 root 用户运行 PAS7。'
fi

need_command ip
need_command wg
need_command awk
need_command systemctl
need_command ss

case "${1:-}" in
    --systemd-repair)
        systemd_repair
        ;;
esac

verify_environment

case "${1:-}" in
    install|repair)
        install_shortcut_and_persistence no
        show_status
        exit 0
        ;;
    uninstall)
        remove_pas7
        exit 0
        ;;
esac

ensure_installed

case "${1:-}" in
    1|entry|inbound)
        apply_mode entry
        exit 0
        ;;
    2|full|pathfabric)
        apply_mode full
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
    mtu)
        case "${2:-status}" in
            auto|redetect)
                [ -z "${3:-}" ] || fail '用法：pas mtu auto'
                enable_auto_mtu
                ;;
            status)
                [ -z "${3:-}" ] || fail '用法：pas mtu status'
                show_status
                ;;
            *)
                [ -z "${3:-}" ] || fail '用法：pas mtu 1240'
                set_manual_mtu "$2"
                ;;
        esac
        exit 0
        ;;
    5)
        prompt_manual_mtu
        exit 0
        ;;
    6|redetect)
        enable_auto_mtu
        exit 0
        ;;
    '')
        ;;
    *)
        fail "未知选项：$1。请运行 pas --help。"
        ;;
esac

show_status
say ''
say '请选择模式：'
say '  1) Pathfabric 入站 + VPS 原出站（推荐）'
say '  2) Pathfabric 入站 + Pathfabric 出站（实验，修复后待复测）'
say '  3) VPS 原 IP 入站 + VPS 原出站'
say '  4) 查看状态'
say '  5) 手动固定 pf-wg MTU（Pathfabric 当前建议 1240）'
say '  6) 取消手动值并恢复自动探测'
say '  7) 修复 pas 快捷命令和开机持久化'
say '  8) 删除 PAS7（不卸载 Pathfabric/Xray）'
say '  0) 退出'
printf '输入 0-8：'
IFS= read -r menu_choice

case "$menu_choice" in
    1) apply_mode entry ;;
    2) apply_mode full ;;
    3) apply_mode original ;;
    4) show_status ;;
    5) prompt_manual_mtu ;;
    6) enable_auto_mtu ;;
    7) install_shortcut_and_persistence no; show_status ;;
    8) remove_pas7 ;;
    0|q|Q) say '已退出，没有修改网络。' ;;
    *) fail '输入无效，没有修改网络。' ;;
esac
