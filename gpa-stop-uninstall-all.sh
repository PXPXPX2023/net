#!/usr/bin/env bash
set -Eeuo pipefail
umask 0027

SCRIPT_VERSION="1.0.0"
MODE=""
DRY_RUN=0
YES_DELETE=0

ALL_UNITS=(
    gpa-collector.service
    gpa-daily.service
    gpa-daily.timer
    gpa-finance.service
    gpa-finance.timer
)

UNIT_TARGETS=(
    /etc/systemd/system/gpa-collector.service
    /etc/systemd/system/gpa-daily.service
    /etc/systemd/system/gpa-daily.timer
    /etc/systemd/system/gpa-finance.service
    /etc/systemd/system/gpa-finance.timer
    /etc/systemd/system/multi-user.target.wants/gpa-collector.service
    /etc/systemd/system/timers.target.wants/gpa-daily.timer
    /etc/systemd/system/timers.target.wants/gpa-finance.timer
)

PROGRAM_TARGETS=(
    /usr/local/bin/gpa
    /etc/logrotate.d/gpa-stock-radar
    /opt/gpa-stock-radar
)

DATA_TARGETS=(
    /etc/gpa-stock-radar
    /var/lib/gpa-stock-radar
    /var/log/gpa-stock-radar
)

KNOWN_INSTALLER_TARGETS=(
    /root/gpa_stock_radar_v1
    /root/gpa_stock_radar_v1.v0.1.0-backup
    /root/gpa_stock_radar_v1.v0.1.0.backup
    /root/gpa_stock_radar_v2
    /root/gpa_stock_radar_overseas_v2
    /root/gpa_stock_radar_china_v2
    /root/gpa-stock-radar-v0.1.0.tar.gz
    /root/gpa-stock-radar-v0.1.0.tar.gz.sha256
    /root/gpa-stock-radar-v0.1.1.tar.gz
    /root/gpa-stock-radar-v0.1.1.tar.gz.sha256
    /root/gpa-stock-radar-v0.2.0-overseas.tar.gz
    /root/gpa-stock-radar-v0.2.0-overseas.tar.gz.sha256
    /root/gpa-stock-radar-v0.2.0-china.tar.gz
    /root/gpa-stock-radar-v0.2.0-china.tar.gz.sha256
)

usage() {
    printf '%s\n' \
        "GPA 通用停止/卸载工具 v${SCRIPT_VERSION}" \
        '' \
        '适用于：v0.1.0、v0.1.1、v0.2.0 海外版、v0.2.0 中国境内版。' \
        '' \
        '用法：' \
        '  bash gpa-stop-uninstall-all.sh --stop' \
        '      完全停止并禁用 GPA 服务和定时器，不删除文件。' \
        '' \
        '  bash gpa-stop-uninstall-all.sh --remove-app' \
        '      卸载程序、命令和 systemd 单元，保留配置、Token、数据库和报告。' \
        '' \
        '  bash gpa-stop-uninstall-all.sh --purge --yes-delete-all-data' \
        '      完全卸载并永久删除默认配置、Token、数据库、报告、日志和已知安装包。' \
        '' \
        '可选：--dry-run 只显示将执行的操作，不作改动。' \
        '不带参数运行时会显示交互菜单。'
}

die() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

print_cmd() {
    printf '  +'
    printf ' %q' "$@"
    printf '\n'
}

run_ignore() {
    if [[ $DRY_RUN -eq 1 ]]; then
        print_cmd "$@"
        return 0
    fi
    "$@" >/dev/null 2>&1 || true
}

is_approved_target() {
    local candidate=$1
    local approved
    for approved in \
        "${UNIT_TARGETS[@]}" \
        "${PROGRAM_TARGETS[@]}" \
        "${DATA_TARGETS[@]}" \
        "${KNOWN_INSTALLER_TARGETS[@]}"; do
        if [[ "$candidate" == "$approved" ]]; then
            return 0
        fi
    done
    return 1
}

remove_exact_path() {
    local target=$1
    is_approved_target "$target" || die "拒绝删除未列入白名单的路径：$target"
    [[ "$target" == /* ]] || die "拒绝非绝对路径：$target"
    case "$target" in
        /|/root|/opt|/etc|/var|/var/lib|/var/log|/usr|/usr/local)
            die "拒绝删除过宽路径：$target"
            ;;
    esac
    if [[ $DRY_RUN -eq 1 ]]; then
        print_cmd rm -rf -- "$target"
        return 0
    fi
    if [[ ! -e "$target" && ! -L "$target" ]]; then
        return 0
    fi
    rm -rf -- "$target"
}

gpa_pids() {
    pgrep -f '/opt/gpa-stock-radar/venv/bin/python.*-m[[:space:]]+gpa_stock_radar' 2>/dev/null || true
}

terminate_gpa_processes() {
    local -a pids=()
    local pid
    mapfile -t pids < <(gpa_pids)
    if ((${#pids[@]} == 0)); then
        return 0
    fi
    printf '[INFO] 发现 GPA 进程：%s\n' "${pids[*]}"
    for pid in "${pids[@]}"; do
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        ((pid > 1)) || continue
        if [[ $DRY_RUN -eq 1 ]]; then
            print_cmd kill -TERM "$pid"
        else
            kill -TERM "$pid" 2>/dev/null || true
        fi
    done
    [[ $DRY_RUN -eq 1 ]] && return 0

    for _ in {1..20}; do
        mapfile -t pids < <(gpa_pids)
        ((${#pids[@]} == 0)) && return 0
        sleep 0.25
    done
    mapfile -t pids < <(gpa_pids)
    for pid in "${pids[@]}"; do
        [[ "$pid" =~ ^[0-9]+$ ]] || continue
        ((pid > 1)) || continue
        kill -KILL "$pid" 2>/dev/null || true
    done
}

stop_all() {
    local unit
    local -a remaining=()
    printf '[1/3] 停止并禁用 GPA 服务与定时器……\n'
    if command -v systemctl >/dev/null 2>&1; then
        for unit in "${ALL_UNITS[@]}"; do
            run_ignore systemctl disable --now "$unit"
            run_ignore systemctl stop "$unit"
            run_ignore systemctl reset-failed "$unit"
        done
    fi
    printf '[2/3] 终止不受 systemd 管理的 GPA 进程……\n'
    terminate_gpa_processes
    printf '[3/3] 核验停止状态……\n'
    if [[ $DRY_RUN -eq 0 ]]; then
        mapfile -t remaining < <(gpa_pids)
        if ((${#remaining[@]} > 0)); then
            printf '[WARN] 仍发现 GPA 进程：%s\n' "${remaining[*]}" >&2
            return 1
        fi
    fi
    printf '[OK] GPA 后台采集、盘后任务和财报定时任务已停止并禁用。\n'
}

remove_program() {
    local target
    stop_all
    printf '[INFO] 删除程序、快捷命令、systemd 单元和日志轮转配置……\n'
    for target in "${UNIT_TARGETS[@]}" "${PROGRAM_TARGETS[@]}"; do
        remove_exact_path "$target"
    done
    if command -v systemctl >/dev/null 2>&1; then
        run_ignore systemctl daemon-reload
        run_ignore systemctl reset-failed
    fi
}

confirm_purge() {
    [[ $YES_DELETE -eq 1 ]] && return 0
    [[ -t 0 ]] || die '彻底卸载必须增加 --yes-delete-all-data，或在终端交互运行。'
    printf '\n[危险] 这会永久删除：\n'
    printf '  /etc/gpa-stock-radar（含 Token）\n'
    printf '  /var/lib/gpa-stock-radar（含数据库、备份和全部报告）\n'
    printf '  /var/log/gpa-stock-radar\n'
    printf '请输入“彻底删除GPA”确认：'
    local answer
    read -r answer
    [[ "$answer" == '彻底删除GPA' ]] || die '确认文字不匹配，已取消。'
}

purge_all() {
    local target
    confirm_purge
    remove_program
    printf '[INFO] 永久删除 GPA 配置、数据、报告和日志……\n'
    for target in "${DATA_TARGETS[@]}"; do
        remove_exact_path "$target"
    done
    printf '[INFO] 删除 /root 下已知的四个版本源码目录和安装压缩包……\n'
    for target in "${KNOWN_INSTALLER_TARGETS[@]}"; do
        remove_exact_path "$target"
    done
    if [[ $DRY_RUN -eq 1 ]]; then
        print_cmd userdel gparadar
        print_cmd groupdel gparadar
    else
        if getent passwd gparadar >/dev/null 2>&1; then
            userdel gparadar 2>/dev/null || true
        fi
        if getent group gparadar >/dev/null 2>&1; then
            groupdel gparadar 2>/dev/null || true
        fi
    fi
    printf '[OK] GPA 四个版本的共用安装、默认数据和已知安装文件已完全清除。\n'
    printf '[说明] 为避免误删其他系统日志，systemd journal 的历史记录会等待系统正常轮转。\n'
    printf '[说明] 放在其他自定义目录的迁移备份不会自动删除，请自行核对。\n'
}

interactive_menu() {
    printf '\nGPA 四版本通用停止/卸载工具\n'
    printf '  1) 完全停止并禁用（不删除文件）\n'
    printf '  2) 卸载程序，保留配置/数据/报告\n'
    printf '  3) 完全卸载并永久删除全部默认数据\n'
    printf '  0) 退出\n'
    printf '请选择：'
    local choice
    read -r choice
    case "$choice" in
        1) MODE=stop ;;
        2) MODE=remove-app ;;
        3) MODE=purge ;;
        0) exit 0 ;;
        *) die '选择无效。' ;;
    esac
}

while (($#)); do
    case "$1" in
        --stop)
            [[ -z "$MODE" ]] || die '只能选择一种操作模式。'
            MODE=stop
            ;;
        --remove-app)
            [[ -z "$MODE" ]] || die '只能选择一种操作模式。'
            MODE=remove-app
            ;;
        --purge)
            [[ -z "$MODE" ]] || die '只能选择一种操作模式。'
            MODE=purge
            ;;
        --yes-delete-all-data|--yes)
            YES_DELETE=1
            ;;
        --dry-run)
            DRY_RUN=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf '未知参数：%s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

if [[ -z "$MODE" ]]; then
    [[ -t 0 ]] || { usage; exit 2; }
    interactive_menu
fi

if [[ ${EUID} -ne 0 && $DRY_RUN -eq 0 ]]; then
    die '请使用 root 权限运行，例如：sudo bash gpa-stop-uninstall-all.sh --stop'
fi

printf 'GPA 通用工具 v%s｜模式=%s｜dry-run=%s\n' "$SCRIPT_VERSION" "$MODE" "$DRY_RUN"

case "$MODE" in
    stop)
        stop_all
        ;;
    remove-app)
        remove_program
        printf '[OK] 程序已卸载；以下资料已保留：\n'
        printf '  /etc/gpa-stock-radar\n'
        printf '  /var/lib/gpa-stock-radar\n'
        printf '  /var/log/gpa-stock-radar\n'
        ;;
    purge)
        purge_all
        ;;
    *)
        die "内部模式错误：$MODE"
        ;;
esac
