#!/usr/bin/env bash
# bash fonts colors
red='\e[31m'
yellow='\e[33m'
gray='\e[90m'
green='\e[92m'
blue='\e[94m'
magenta='\e[95m'
cyan='\e[96m'
none='\e[0m'

_red() { echo -e "${red}$*${none}"; }
_blue() { echo -e "${blue}$*${none}"; }
_cyan() { echo -e "${cyan}$*${none}"; }
_green() { echo -e "${green}$*${none}"; }
_yellow() { echo -e "${yellow}$*${none}"; }
_magenta() { echo -e "${magenta}$*${none}"; }
_red_bg() { echo -e "\e[41m$*${none}"; }

is_err=$(_red_bg "错误!")
is_warn=$(_red_bg "警告!")

err() { echo -e "\n${is_err} $*\n" && exit 1; }
warn() { echo -e "\n${is_warn} $*\n"; }

# ==========================================
# 【需修改】请在这里填入你的 GitHub 用户名
# ==========================================
author="your_github_username"

# 环境检查
[[ $EUID != 0 ]] && err "当前非 ${yellow}ROOT用户.${none}"

cmd=$(command -v apt-get || command -v yum)
[[ -z "$cmd" ]] && err "此脚本仅支持 ${yellow}(Ubuntu / Debian / CentOS)${none}."

[[ -z $(command -v systemctl) ]] && err "系统缺少 systemctl, 请尝试修复: ${cmd} update -y; ${cmd} install systemd -y"

case $(uname -m) in
amd64 | x86_64)  is_jq_arch="amd64"; is_core_arch="64" ;;
*aarch64* | *armv8*) is_jq_arch="arm64"; is_core_arch="arm64-v8a" ;;
*) err "此脚本仅支持 64 位系统 (x86_64 或 arm64)..." ;;
esac

# 核心变量
is_core="xray"
is_core_name="Xray"
is_core_dir="/etc/$is_core"
is_core_bin="$is_core_dir/bin/$is_core"
is_core_repo="xtls/$is_core-core"
is_conf_dir="$is_core_dir/conf"
is_log_dir="/var/log/$is_core"
is_sh_bin="/usr/local/bin/$is_core"
is_sh_dir="$is_core_dir/sh"
is_sh_repo="$author/$is_core"
is_config_json="$is_core_dir/config.json"
is_pkg=("wget" "unzip") # 改为数组

# 安全创建临时目录
tmpdir=$(mktemp -d "/tmp/${is_core}-tmp.XXXXXX" 2>/dev/null || mkdir -p "/tmp/${is_core}-tmp-$RANDOM" && echo "/tmp/${is_core}-tmp-$RANDOM")
tmpcore="$tmpdir/tmpcore"
tmpsh="$tmpdir/tmpsh"
tmpjq="$tmpdir/tmpjq"

load() { . "$is_sh_dir/src/$1"; }

_wget() {
    [[ -n "$proxy" ]] && export https_proxy="$proxy"
    wget --no-check-certificate "$@"
}

msg() {
    local color
    case "$1" in
        warn) color="$yellow" ;;
        err)  color="$red" ;;
        ok)   color="$green" ;;
    esac
    echo -e "${color}$(date +'%T')${none}) ${2}"
}

show_help() {
    echo -e "Usage: $0 [-f <path> | -l | -p <addr> | -v <ver> | -h]"
    echo -e "  -f, --core-file <path>   自定义本地核心压缩包路径"
    echo -e "  -l, --local-install      本地安装模式 (使用当前目录下的脚本)"
    echo -e "  -p, --proxy <addr>       使用代理下载"
    echo -e "  -v, --core-version <ver> 指定核心版本"
    echo -e "  -h, --help               显示帮助"
    exit 0
}

# [优化点 2 & 3]：同步安装依赖，使用标准的 Bash 数组
install_pkg_sync() {
    local missing_pkgs=()
    for pkg in "${is_pkg[@]}"; do
        [[ -z $(command -v "$pkg") ]] && missing_pkgs+=("$pkg")
    done
    
    if [[ ${#missing_pkgs[@]} -gt 0 ]]; then
        msg warn "正在安装缺失依赖: ${missing_pkgs[*]}"
        $cmd update -y &>/dev/null || true
        [[ "$cmd" =~ yum ]] && yum install epel-release -y &>/dev/null
        if ! $cmd install -y "${missing_pkgs[@]}" &>/dev/null; then
            err "依赖包安装失败，请手动执行: $cmd install -y ${missing_pkgs[*]}"
        fi
    fi
}

download() {
    local link="" name="" tmpfile=""
    case "$1" in
    core)
        link="https://github.com/${is_core_repo}/releases/latest/download/${is_core}-linux-${is_core_arch}.zip"
        [[ -n "$is_core_ver" ]] && link="https://github.com/${is_core_repo}/releases/download/${is_core_ver}/${is_core}-linux-${is_core_arch}.zip"
        name="$is_core_name"
        tmpfile="$tmpcore"
        ;;
    sh)
        link="https://github.com/${is_sh_repo}/releases/latest/download/code.zip"
        name="管理脚本"
        tmpfile="$tmpsh"
        ;;
    jq)
        link="https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-$is_jq_arch"
        name="jq"
        tmpfile="$tmpjq"
        ;;
    esac

    msg warn "正在下载 ${name}..."
    _wget -t 3 -q -c "$link" -O "$tmpfile" || err "下载 ${name} 失败: $link"
}

get_ip() {
    ip=$(_wget -4 -qO- https://one.one.one.one/cdn-cgi/trace | awk -F= '/ip=/{print $2}')
    [[ -z "$ip" ]] && ip=$(_wget -6 -qO- https://one.one.one.one/cdn-cgi/trace | awk -F= '/ip=/{print $2}')
    export ip
    [[ -z "$ip" ]] && err "获取服务器外网 IP 失败."
}

pass_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -f|--core-file) [[ ! -f "$2" ]] && err "($2) 文件不存在."; is_core_file="$2"; shift 2 ;;
        -l|--local-install)
            [[ ! -f "${PWD}/src/core.sh" || ! -f "${PWD}/${is_core}.sh" ]] && err "当前目录 ($PWD) 结构不完整.";
            local_install=1; shift 1 ;;
        -p|--proxy) proxy="$2"; shift 2 ;;
        -v|--core-version) is_core_ver="v${2#v}"; shift 2 ;;
        -h|--help) show_help ;;
        *) err "未知参数: $1";;
        esac
    done
    [[ -n "$is_core_ver" && -n "$is_core_file" ]] && err "无法同时使用 -v 和 -f 参数."
}

exit_and_clean() {
    rm -rf "$tmpdir"
    [[ "$1" == "ok" ]] && exit 0
    echo -e "\n反馈问题: https://github.com/${is_sh_repo}/issues"
    exit 1
}

main() {
    [[ -f "$is_sh_bin" && -d "$is_core_dir/bin" ]] && err "检测到已安装，如需重装请使用 ${green}${is_core} reinstall${none} 命令."
    
    [[ $# -gt 0 ]] && pass_args "$@"

    clear
    echo -e "\n........... $is_core_name script by $author ..........\n"

    # 1. 优先解决依赖问题 (同步执行，避免后续所有并发隐患)
    install_pkg_sync

    # 2. 检查 jq
    [[ -z $(command -v jq) ]] && jq_not_found=1

    # 3. 准备文件 (并发下载)
    msg warn "初始化下载任务..."
    [[ -z "$is_core_file" ]] && download core &
    [[ -z "$local_install" ]] && download sh &
    [[ -n "$jq_not_found" ]] && download jq &
    get_ip &
    wait # 等待所有下载和网络请求完毕

    # 4. 验证本地文件格式
    if [[ -n "$is_core_file" ]]; then
        msg warn "正在使用本地核心: $is_core_file"
        cp -f "$is_core_file" "$tmpcore"
    fi
    
    mkdir -p "$tmpdir/testzip"
    if ! unzip -qo "$tmpcore" -d "$tmpdir/testzip"; then
        err "核心压缩包解压失败，请检查文件是否损坏."
    fi
    for i in "$is_core" geoip.dat geosite.dat; do
        [[ ! -f "$tmpdir/testzip/$i" ]] && err "压缩包内缺失必要文件: $i"
    done

    # 5. 开始部署系统级文件
    msg warn "部署文件和权限..."
    mkdir -p "$is_sh_dir" "$is_core_dir/bin" "$is_conf_dir" "$is_log_dir"

    # [优化点 1]：精准拷贝，抛弃危险的 $PWD/*
    if [[ -n "$local_install" ]]; then
        cp -rf "$PWD/src" "$PWD/${is_core}.sh" "$is_sh_dir/"
    else
        unzip -qo "$tmpsh" -d "$is_sh_dir"
    fi

    cp -rf "$tmpdir/testzip/"* "$is_core_dir/bin/"

    # [优化点 4]：更安全的 .bashrc 处理
    [[ -z $(grep "alias $is_core=" "${HOME}/.bashrc" 2>/dev/null) ]] && echo "alias $is_core=$is_sh_bin" >> "${HOME}/.bashrc"
    ln -sf "$is_sh_dir/$is_core.sh" "$is_sh_bin"

    if [[ -n "$jq_not_found" ]]; then
        mv -f "$tmpjq" /usr/bin/jq
        chmod +x /usr/bin/jq
    fi

    chmod +x "$is_core_bin" "$is_sh_bin"

    # 同步时间 (容错处理)
    timedatectl set-ntp true &>/dev/null || msg warn "\e[4m提示: 无法设置系统自动同步时间, 可能会影响 VMess 协议.\e[0m"

    # 6. 生成配置与注册服务
    msg ok "生成配置文件并注册服务..."
    load systemd.sh
    is_new_install=1
    install_service "$is_core" &>/dev/null

    load core.sh
    add reality

    msg ok "安装完成！"
    exit_and_clean ok
}

main "$@"
