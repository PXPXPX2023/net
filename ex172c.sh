#!/usr/bin/env bash
# ============================================================
# 脚本名称: ex172c.sh (The Eternity Evolved - Project Genesis V172)
# 快捷方式: xrv
#
# V172 全量升级要点:
#   1. 安全加固: 全局 ERR trap、配置自动备份回滚、输入消毒
#   2. 协议扩展: 原生整合 NaiveProxy(Caddy)、Hysteria2 双协议
#   3. 稳定性:   set -euo pipefail 严格模式，readonly 全局锚定
#   4. 容错完全: _safe_jq_write 原子化 + jq 节点自愈防爆
#   5. 监控增强: 日志落盘、自动备份、故障自愈
#   6. 内核继承: 完整继承 ex118 全部 25 项微操 + 3 项上帝开关
#   7. 时序绝杀: xray-hw-tweaks 锁死 network-online.target
#   8. 物理锚点: /etc/xray/flags 跨重启永久持久化
#   9. 客户端适配: 输出 Clash/Stash/Sing-Box/Hysteria2 格式配置
# ============================================================

if test -z "$BASH_VERSION"; then
    echo "错误: 请用 bash 运行: bash ex172c.sh"; exit 1
fi

# 严格模式
set -euo pipefail
IFS=$'\n\t'

# ── 颜色 ──────────────────────────────────────────────────────
readonly red='\033[31m'    yellow='\033[33m'  gray='\033[90m'
readonly green='\033[92m'  blue='\033[94m'    magenta='\033[95m'
readonly cyan='\033[96m'   none='\033[0m'

# ── 全局常量路径 ───────────────────────────────────────────────
readonly SCRIPT_VERSION="172"
readonly XRAY_BIN="/usr/local/bin/xray"
readonly CONFIG_DIR="/usr/local/etc/xray"
readonly CONFIG="$CONFIG_DIR/config.json"
readonly PUBKEY_FILE="$CONFIG_DIR/public.key"
readonly SNI_CACHE_FILE="$CONFIG_DIR/sni_cache.txt"
readonly INSTALL_DATE_FILE="$CONFIG_DIR/install_date.txt"
readonly USER_SNI_MAP="$CONFIG_DIR/user_sni.txt"
readonly USER_TIME_MAP="$CONFIG_DIR/user_time.txt"
readonly CAKE_OPTS_FILE="$CONFIG_DIR/cake_opts.txt"
readonly FLAGS_DIR="$CONFIG_DIR/flags"
readonly DAT_DIR="/usr/local/share/xray"
readonly SCRIPT_DIR="/usr/local/etc/xray-script"
readonly UPDATE_DAT_SCRIPT="$SCRIPT_DIR/update-dat.sh"
readonly LOG_DIR="/var/log/xray"
readonly BACKUP_DIR="$CONFIG_DIR/backups"
readonly SYMLINK="/usr/local/bin/xrv"
readonly SCRIPT_PATH=$(readlink -f "$0")

# Caddy/NaiveProxy
readonly CADDY_BIN="/usr/local/bin/caddy"
readonly CADDY_CONF="/etc/caddy/Caddyfile"
readonly CADDY_DATA="/var/lib/caddy"

# Hysteria2
readonly HY2_BIN="/usr/local/bin/hysteria"
readonly HY2_CONF_DIR="/etc/hysteria"
readonly HY2_CONF="$HY2_CONF_DIR/config.yaml"

# ── 可变全局 ──────────────────────────────────────────────────
SERVER_IP=""
REMARK_NAME="xp-reality"
BEST_SNI="www.microsoft.com"
SNI_JSON_ARRAY="\"www.microsoft.com\""
LISTEN_PORT=443

# ── 目录初始化 ────────────────────────────────────────────────
mkdir -p "$CONFIG_DIR" "$DAT_DIR" "$SCRIPT_DIR" "$FLAGS_DIR" \
         "$LOG_DIR" "$BACKUP_DIR" "$HY2_CONF_DIR" 2>/dev/null || true
touch "$USER_SNI_MAP" "$USER_TIME_MAP" 2>/dev/null || true

# ══════════════════════════════════════════════════════════════
# 第一区: 基础工具函数
# ══════════════════════════════════════════════════════════════

# ── 颜色输出 ──────────────────────────────────────────────────
print_red()     { echo -e "${red}$*${none}"; }
print_green()   { echo -e "${green}$*${none}"; }
print_yellow()  { echo -e "${yellow}$*${none}"; }
print_magenta() { echo -e "${magenta}$*${none}"; }
print_cyan()    { echo -e "${cyan}$*${none}"; }
info()   { echo -e "${green}✓${none} $*"; }
warn()   { echo -e "${yellow}!${none} $*"; }
error()  { echo -e "${red}✗${none} $*"; }
die()    { echo -e "\n${red}致命错误${none} $*\n"; exit 1; }
title()  {
    echo -e "\n${blue}===================================================${none}"
    echo -e "  ${cyan}$*${none}"
    echo -e "${blue}===================================================${none}"
}
hr() { echo -e "${gray}---------------------------------------------------${none}"; }

# ── 日志 ──────────────────────────────────────────────────────
log_info()  { echo "[$(date +'%Y-%m-%d %H:%M:%S')] INFO:  $*" >> "$LOG_DIR/xray.log"; }
log_error() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$LOG_DIR/error.log"; }

# ── 全局异常捕获 ───────────────────────────────────────────────
trap '_err_handler $? $LINENO "$BASH_COMMAND"' ERR
_err_handler() {
    local code=$1 line=$2 cmd=$3
    echo -e "\n${red}[ERR] 退出码:$code 行:$line 命令:$cmd${none}" >&2
    log_error "EXIT=$code LINE=$line CMD=$cmd"
}

# ── 输入验证 ──────────────────────────────────────────────────
validate_port() {
    local p="$1"
    [[ -z "$p" ]] && return 1
    [[ ! "$p" =~ ^[0-9]+$ ]] && return 1
    ((p < 1 || p > 65535)) && return 1
    if ss -tuln 2>/dev/null | grep -q ":${p} "; then
        print_red "端口 $p 已被占用！"; return 1
    fi
    return 0
}

validate_domain() {
    local d="$1"
    [[ "$d" =~ ^[a-zA-Z0-9]([a-zA-Z0-9.\-]{0,253}[a-zA-Z0-9])?$ ]] && return 0
    return 1
}

# ── 配置备份/回滚 ─────────────────────────────────────────────
backup_config() {
    [[ -f "$CONFIG" ]] || return 0
    local ts; ts=$(date +%Y%m%d_%H%M%S)
    cp -f "$CONFIG" "$BACKUP_DIR/config_${ts}.json" 2>/dev/null || true
    # 只保留最近 10 份备份
    ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true
    log_info "配置备份: config_${ts}.json"
}

restore_latest_backup() {
    local latest
    latest=$(ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null | head -1)
    if [[ -n "$latest" ]]; then
        cp -f "$latest" "$CONFIG"
        fix_permissions
        systemctl restart xray >/dev/null 2>&1 || true
        info "已回滚到: $(basename "$latest")"
        log_info "配置回滚: $latest"
        return 0
    fi
    return 1
}

# ── 安全写入配置 ───────────────────────────────────────────────
_safe_jq_write() {
    local filter="$1"
    local tmp; tmp=$(mktemp) || return 1
    backup_config
    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null && jq empty "$tmp" 2>/dev/null; then
        mv -f "$tmp" "$CONFIG"
        fix_permissions
        log_info "配置更新成功"
        return 0
    fi
    rm -f "$tmp" 2>/dev/null || true
    log_error "jq 更新失败，filter=$filter"
    return 1
}

# ── 权限 ──────────────────────────────────────────────────────
fix_permissions() {
    [[ -f "$CONFIG" ]]    && chmod 644 "$CONFIG"    2>/dev/null || true
    [[ -d "$CONFIG_DIR" ]] && chmod 755 "$CONFIG_DIR" 2>/dev/null || true
    chown -R root:root "$CONFIG_DIR" 2>/dev/null || true
    [[ -f "$PUBKEY_FILE" ]] && chmod 600 "$PUBKEY_FILE" 2>/dev/null || true
}

# ── 系统检测 ──────────────────────────────────────────────────
detect_os() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release; echo "${ID:-unknown}"
    else echo "unknown"; fi
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)    echo "amd64" ;;
        aarch64|arm64)   echo "arm64" ;;
        armv7l)          echo "armv7" ;;
        *)               echo "unknown"; return 1 ;;
    esac
}

pkg_install() {
    local list="$*"
    export DEBIAN_FRONTEND=noninteractive
    case "$(detect_os)" in
        ubuntu|debian)
            apt-get update -y >/dev/null 2>&1 || true
            apt-get install -y $list >/dev/null 2>&1 || true ;;
        centos|rhel|fedora|rocky|almalinux)
            yum makecache -y >/dev/null 2>&1 || true
            yum install -y $list >/dev/null 2>&1 || true ;;
        *)
            warn "未知 OS，请手动安装: $list" ;;
    esac
}

# ══════════════════════════════════════════════════════════════
# 第二区: 环境预检 / Systemd 调优
# ══════════════════════════════════════════════════════════════

preflight() {
    ((EUID == 0)) || die "必须以 root 运行"
    command -v systemctl >/dev/null 2>&1 || die "缺少 systemctl"

    local need="jq curl wget xxd unzip qrencode vnstat openssl \
                coreutils sed e2fsprogs pkg-config iproute2 ethtool"
    local missing=""
    for p in $need; do
        command -v "$p" >/dev/null 2>&1 || missing="$missing $p"
    done
    [[ -n "$missing" ]] && {
        info "安装依赖:$missing"
        pkg_install $missing
        systemctl start vnstat  2>/dev/null || true
        systemctl enable vnstat 2>/dev/null || true
        systemctl start cron    2>/dev/null || systemctl start crond 2>/dev/null || true
    }

    [[ -f "$SCRIPT_PATH" ]] && {
        cp -f "$SCRIPT_PATH" "$SYMLINK" 2>/dev/null || true
        chmod +x "$SYMLINK" 2>/dev/null || true
        hash -r 2>/dev/null || true
    }

    SERVER_IP=$(
        curl -s -4 --connect-timeout 5 --max-time 10 https://api.ipify.org 2>/dev/null ||
        curl -s -4 --connect-timeout 5 --max-time 10 https://ifconfig.me  2>/dev/null ||
        curl -s -4 --connect-timeout 5 --max-time 10 https://icanhazip.com 2>/dev/null ||
        echo "获取失败"
    )
    [[ "$SERVER_IP" == "获取失败" ]] && warn "无法获取公网 IP"
}

fix_xray_systemd_limits() {
    local override_dir="/etc/systemd/system/xray.service.d"
    mkdir -p "$override_dir"
    local limit_file="$override_dir/limits.conf"

    local current_nice="-20" current_gogc="100" current_oom="true"
    local current_affinity="" current_gomaxprocs="" current_buffer=""

    if [[ -f "$limit_file" ]]; then
        current_nice=$(awk -F'=' '/^Nice=/{print $2}' "$limit_file" | head -1)
        current_gogc=$(awk -F'=' '/^Environment="GOGC=/{print $3}' "$limit_file" | tr -d '"' | head -1)
        grep -q "^OOMScoreAdjust=" "$limit_file" || current_oom="false"
        current_affinity=$(awk -F'=' '/^CPUAffinity=/{print $2}' "$limit_file" | head -1)
        current_gomaxprocs=$(awk -F'=' '/^Environment="GOMAXPROCS=/{print $3}' "$limit_file" | tr -d '"' | head -1)
        current_buffer=$(awk -F'=' '/^Environment="XRAY_RAY_BUFFER_SIZE=/{print $3}' "$limit_file" | tr -d '"' | head -1)
    fi

    local total_mem; total_mem=$(free -m | awk '/Mem/{print $2}')
    local go_mem_limit=$(( total_mem * 85 / 100 ))

    cat > "$limit_file" << EOF
[Service]
LimitNOFILE=1048576
LimitNPROC=512
LimitMEMLOCK=infinity
Nice=${current_nice:-"-20"}
Environment="GOMEMLIMIT=${go_mem_limit}MiB"
Environment="GOGC=${current_gogc:-100}"
Restart=on-failure
RestartSec=10s
EOF
    [[ "${current_oom:-true}" == "true" ]] && cat >> "$limit_file" << 'EOF'
OOMScoreAdjust=-500
IOSchedulingClass=realtime
IOSchedulingPriority=2
EOF
    [[ -n "$current_affinity"    ]] && echo "CPUAffinity=$current_affinity"             >> "$limit_file"
    [[ -n "$current_gomaxprocs"  ]] && echo "Environment=\"GOMAXPROCS=$current_gomaxprocs\""        >> "$limit_file"
    [[ -n "$current_buffer"      ]] && echo "Environment=\"XRAY_RAY_BUFFER_SIZE=$current_buffer\""  >> "$limit_file"

    systemctl daemon-reload >/dev/null 2>&1
}

# ══════════════════════════════════════════════════════════════
# 第三区: SNI 扫描 / 质检 / 选单
# ══════════════════════════════════════════════════════════════

run_sni_scanner() {
    title "雷达嗅探：全球 CDN 矩阵扫描"
    print_yellow ">>> 扫描中... (回车可中止)\n"

    local sni_list=(
        "www.apple.com" "support.apple.com" "developer.apple.com" "id.apple.com"
        "www.microsoft.com" "login.microsoftonline.com" "portal.azure.com" "office.com"
        "www.intel.com" "downloadcenter.intel.com" "www.amd.com" "www.nvidia.com"
        "www.dell.com" "www.hp.com" "www.bmw.com" "www.mercedes-benz.com"
        "global.toyota" "www.honda.com" "www.volkswagen.com" "www.tesla.com"
        "www.nike.com" "www.adidas.com" "www.ikea.com" "www.shell.com"
        "www.ge.com" "www.hsbc.com" "www.morganstanley.com" "www.msc.com"
        "www.sony.com" "www.canon.com" "www.nintendo.com" "www.samsung.com"
        "www.oracle.com" "addons.mozilla.org" "mit.edu" "stanford.edu"
        "www.lufthansa.com" "www.singaporeair.com" "www.logitech.com"
        "www.razer.com" "www.corsair.com" "www.hermes.com" "www.coca-cola.com"
        "s0.awsstatic.com" "www.airbnb.com" "github.com" "www.loreal.com"
        "www.louisvuitton.com" "www.dior.com" "www.gucci.com" "www.rolex.com"
        "www.unilever.com" "www.bp.com" "www.specialized.com" "www.ubisoft.com"
        "www.ea.com" "www.epicgames.com" "www.spotify.com" "www.booking.com"
    )

    local sni_string
    if command -v shuf >/dev/null 2>&1; then
        sni_string=$(printf "%s\n" "${sni_list[@]}" | shuf)
    else
        sni_string=$(printf "%s\n" "${sni_list[@]}" | awk 'BEGIN{srand()} {print rand()"\t"$0}' | sort -n | cut -f2-)
    fi

    local tmp_sni; tmp_sni=$(mktemp)
    local scan_count=0

    for sni in $sni_string; do
        read -t 0.1 -n 1 2>/dev/null && {
            echo -e "\n${yellow}已中止${none}"; break
        } || true

        local time_raw ms
        time_raw=$(LC_ALL=C curl -sL -w "%{time_connect}" -o /dev/null \
                   --connect-timeout 2 -m 4 "https://$sni" 2>/dev/null || echo "0")
        ms=$(echo "$time_raw" | awk '{print int($1*1000)}')

        if ((ms > 0)); then
            # 过滤 Cloudflare
            if curl -sI -m 2 --connect-timeout 2 "https://$sni" 2>/dev/null | \
               grep -qiE "server: cloudflare|cf-ray"; then
                echo -e " ${gray}跳过${none} $sni (Cloudflare)"; continue
            fi

            local doh_res dns_cn loc p_type status_cn
            doh_res=$(curl -s --connect-timeout 2 \
                "https://dns.alidns.com/resolve?name=$sni&type=1" 2>/dev/null || echo "")
            dns_cn=$(echo "$doh_res" | \
                jq -r '.Answer[]? | select(.type==1 or .type==5) | .data' 2>/dev/null | tail -1)

            if [[ -z "$dns_cn" || "$dns_cn" == "127.0.0.1" || "$dns_cn" == "0.0.0.0" ]]; then
                status_cn="${red}DNS投毒${none}"; p_type="BLOCK"
            else
                loc=$(curl -s --connect-timeout 2 "https://ipinfo.io/$dns_cn/country" \
                      2>/dev/null | tr -d ' \n' || echo "")
                if [[ "$loc" == "CN" ]]; then
                    status_cn="${green}直通${none}|${blue}CN-CDN${none}"; p_type="CN_CDN"
                else
                    status_cn="${green}直通${none}|${cyan}海外优质${none}"; p_type="NORM"
                fi
            fi

            echo -e " ${green}存活${none} $sni : ${yellow}${ms}ms${none} | $status_cn"
            [[ "$p_type" != "BLOCK" ]] && echo "$ms $sni $p_type" >> "$tmp_sni"
        fi

        ((scan_count++))
        ((scan_count >= 60)) && break
    done

    if [[ -s "$tmp_sni" ]]; then
        {
            grep " NORM$" "$tmp_sni"   | sort -n | head -15
            grep " CN_CDN$" "$tmp_sni" | sort -n | head -5
        } | awk '{print $2, $1}' > "$SNI_CACHE_FILE"
    else
        print_red "扫描无结果，使用保底方案。"
        echo "www.microsoft.com 999" > "$SNI_CACHE_FILE"
    fi
    rm -f "$tmp_sni"
}

verify_sni_strict() {
    print_magenta "\n>>> 质检: $1 (TLS1.3 + ALPN h2 + OCSP)"
    local out; out=$(echo "Q" | timeout 5 openssl s_client \
        -connect "$1:443" -alpn h2 -tls1_3 -status 2>&1 || echo "")
    local pass=1
    echo "$out" | grep -qi "TLSv1.3"               || { print_red " ✗ 不支持 TLS 1.3";   pass=0; }
    echo "$out" | grep -qi "ALPN.*h2"               || { print_red " ✗ 不支持 ALPN h2";   pass=0; }
    echo "$out" | grep -qi "OCSP response"          || { print_red " ✗ 无 OCSP Stapling"; pass=0; }
    ((pass == 1)) && info "质检通过: $1"
    return $pass
}

choose_sni() {
    while true; do
        [[ ! -f "$SNI_CACHE_FILE" ]] && run_sni_scanner

        echo -e "\n  ${cyan}【缓存节点 Top】${none}"
        local idx=1
        while read -r s t; do
            echo -e "  $idx) $s ${cyan}(${t}ms)${none}"; ((idx++))
        done < "$SNI_CACHE_FILE"

        hr
        echo "  r) 重新扫描    m) 矩阵多选    0) 手动输入    q) 取消"
        read -rp "  选择: " sel; sel=${sel:-1}

        case "$sel" in
            q|Q) return 1 ;;
            r|R) run_sni_scanner; continue ;;
            m|M)
                read -rp "序号(空格分隔): " m_sel
                local arr=()
                for i in $m_sel; do
                    local pk; pk=$(awk "NR==$i {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "")
                    [[ -n "$pk" ]] && arr+=("$pk")
                done
                ((${#arr[@]} == 0)) && { error "无效"; continue; }
                BEST_SNI="${arr[0]}"
                local jqa=(); for s in "${arr[@]}"; do jqa+=("\"$s\""); done
                SNI_JSON_ARRAY=$(IFS=,; echo "${jqa[*]}")
                ;;
            0)
                read -rp "域名: " d
                BEST_SNI=${d:-www.microsoft.com}
                SNI_JSON_ARRAY="\"$BEST_SNI\""
                ;;
            *)
                if [[ "$sel" =~ ^[0-9]+$ ]]; then
                    local pk; pk=$(awk "NR==$sel {print \$1}" "$SNI_CACHE_FILE" 2>/dev/null || echo "")
                    BEST_SNI=${pk:-$(awk 'NR==1{print $1}' "$SNI_CACHE_FILE")}
                    SNI_JSON_ARRAY="\"$BEST_SNI\""
                else
                    error "无效"; continue
                fi
                ;;
        esac

        verify_sni_strict "$BEST_SNI" && break || { warn "质检失败，重新选择"; sleep 2; }
    done
    return 0
}

# ══════════════════════════════════════════════════════════════
# 第四区: Xray 核心安装 / 规则库
# ══════════════════════════════════════════════════════════════

install_update_dat() {
    cat > "$UPDATE_DAT_SCRIPT" << 'UPDSH'
#!/usr/bin/env bash
XRAY_DAT_DIR="/usr/local/share/xray"
LOG_FILE="/var/log/xray/update-dat.log"
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

dl() {
    local url="$1" out="$2"
    for i in 1 2 3; do
        curl -fsSL --connect-timeout 10 --max-time 300 -o "$out.tmp" "$url" && \
            mv -f "$out.tmp" "$out" && log "OK: $url" && return 0
        log "重试[$i]: $url"; sleep 5
    done
    log "FAIL: $url"; return 1
}

dl "https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"   "$XRAY_DAT_DIR/geoip.dat"
dl "https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat" "$XRAY_DAT_DIR/geosite.dat"
log "规则库更新完成"
UPDSH
    chmod +x "$UPDATE_DAT_SCRIPT"

    (crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT" | grep -v "systemctl restart xray"
     echo "0 3 * * * $UPDATE_DAT_SCRIPT >/dev/null 2>&1"
     echo "10 3 * * * /bin/systemctl restart xray >/dev/null 2>&1") | crontab -

    info "规则库热更: 03:00 下载 03:10 重载"
}

do_update_core() {
    title "Xray Core 无损热更"
    print_magenta ">>> 拉取最新版本..."
    bash -c "$(curl -fsSL --connect-timeout 10 \
        https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1
    fix_xray_systemd_limits
    systemctl restart xray >/dev/null 2>&1
    local ver; ver=$("$XRAY_BIN" version 2>/dev/null | head -1 | awk '{print $2}')
    info "热更完成！版本: ${cyan}$ver${none}"
    read -rp "按 Enter 继续..." _
}

gen_ss_pass() { head -c 24 /dev/urandom | base64 | tr -d '=/+\n' | head -c 24; }
_select_ss_method() {
    echo -e "  ${cyan}SS 加密方式：${none}" >&2
    echo "  1) aes-256-gcm  2) aes-128-gcm  3) chacha20-ietf-poly1305" >&2
    read -rp "  编号(默认1): " mc >&2
    case "${mc:-1}" in 2) echo "aes-128-gcm" ;; 3) echo "chacha20-ietf-poly1305" ;; *) echo "aes-256-gcm" ;; esac
}

# ══════════════════════════════════════════════════════════════
# 第五区: NaiveProxy (Caddy forwardproxy)
# ══════════════════════════════════════════════════════════════

install_caddy_naive() {
    title "安装 Caddy + NaiveProxy"

    local arch; arch=$(detect_arch)
    local os_id; os_id=$(detect_os)

    # 方式一：用 xcaddy 编译（Debian/Ubuntu 优先）
    if command -v xcaddy >/dev/null 2>&1 || \
       (apt-get install -y xcaddy golang-go >/dev/null 2>&1 && command -v xcaddy >/dev/null 2>&1); then
        print_magenta ">>> 编译 Caddy + forwardproxy..."
        xcaddy build \
            --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@naive \
            --output "$CADDY_BIN" >/dev/null 2>&1
    else
        # 方式二：下载预编译二进制
        print_magenta ">>> 下载预编译 Caddy..."
        local caddy_url="https://github.com/klzgrad/naiveproxy/releases/latest/download/naiveproxy-linux-${arch}.tar.xz"
        warn "xcaddy 不可用，请手动编译或下载带 forwardproxy 的 Caddy"
        warn "参考: https://github.com/klzgrad/naiveproxy"
        return 1
    fi

    chmod +x "$CADDY_BIN"
    mkdir -p /etc/caddy "$CADDY_DATA"

    # Caddy 系统用户
    id caddy &>/dev/null || useradd --system --home "$CADDY_DATA" \
        --shell /usr/sbin/nologin caddy 2>/dev/null || true

    cat > /etc/systemd/system/caddy.service << 'EOF'
[Unit]
Description=Caddy NaiveProxy
Documentation=https://caddyserver.com/docs/
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/local/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/local/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
AmbientCapabilities=CAP_NET_BIND_SERVICE
ReadWritePaths=/var/lib/caddy /var/log/caddy

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    info "Caddy 服务已注册"
}

config_naive() {
    local domain="$1" email="$2" user="$3" pass="$4" port="${5:-8443}"

    mkdir -p /etc/caddy
    cat > "$CADDY_CONF" << EOF
{
  admin off
  log {
    output file /var/log/caddy/access.log { roll_size 10mb roll_keep 5 }
    level WARN
  }
}

${domain}:${port} {
  tls ${email}

  route {
    forward_proxy {
      basic_auth ${user} ${pass}
      hide_ip
      hide_via
      probe_resistance
    }
    reverse_proxy https://www.bing.com {
      header_up Host {upstream_hostport}
      header_up X-Forwarded-For {remote_host}
    }
  }
}
EOF
    mkdir -p /var/log/caddy
    chown -R caddy:caddy /var/log/caddy "$CADDY_DATA" 2>/dev/null || true
    systemctl enable caddy
    systemctl restart caddy
    info "NaiveProxy 已配置: ${domain}:${port}"
    log_info "NaiveProxy 配置完成 domain=$domain port=$port"
}

# ══════════════════════════════════════════════════════════════
# 第六区: Hysteria2
# ══════════════════════════════════════════════════════════════

install_hysteria2() {
    title "安装 Hysteria2"
    print_magenta ">>> 下载 Hysteria2..."
    bash <(curl -fsSL https://get.hy2.sh/) >/dev/null 2>&1 || {
        error "Hysteria2 自动安装失败"
        warn "请手动: https://hysteria.network/docs/getting-started/"
        return 1
    }
    info "Hysteria2 安装完成"
}

config_hysteria2() {
    local domain="$1" port="$2" pass="$3" email="$4"

    mkdir -p "$HY2_CONF_DIR"
    cat > "$HY2_CONF" << EOF
listen: :${port}

tls:
  cert: /etc/hysteria/server.crt
  key:  /etc/hysteria/server.key

acme:
  domains:
    - ${domain}
  email: ${email}

auth:
  type: password
  password: ${pass}

masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true

bandwidth:
  up: 1 gbps
  down: 1 gbps
EOF

    cat > /etc/systemd/system/hysteria-server.service << 'EOF'
[Unit]
Description=Hysteria2 Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=on-failure
RestartSec=10s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable hysteria-server
    systemctl restart hysteria-server
    info "Hysteria2 已配置: ${domain}:${port}"
    log_info "Hysteria2 配置完成 domain=$domain port=$port"
}

# ══════════════════════════════════════════════════════════════
# 第七区: 系统底层微操 (完整继承 ex118 全部 25 项)
# ══════════════════════════════════════════════════════════════

# ── 状态检测函数 ──────────────────────────────────────────────
check_mph_state()      { [[ "$(jq -r '.routing.domainMatcher // "x"' "$CONFIG" 2>/dev/null)" == "mph" ]] && echo "true" || echo "false"; }
check_maxtime_state()  { local v; v=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .streamSettings.realitySettings.maxTimeDiff // "0"' "$CONFIG" 2>/dev/null | head -1); [[ "$v" == "60000" ]] && echo "true" || echo "false"; }
check_routeonly_state(){ local v; v=$(jq -r '.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.routeOnly // "false"' "$CONFIG" 2>/dev/null | head -1); [[ "$v" == "true" ]] && echo "true" || echo "false"; }
check_sniff_state()    { local v; v=$(jq -r '.inbounds[]? | select(.protocol=="vless" or .protocol=="shadowsocks") | .sniffing.metadataOnly // "false"' "$CONFIG" 2>/dev/null | head -1); [[ "$v" == "true" ]] && echo "true" || echo "false"; }
check_affinity_state() { grep -q "^CPUAffinity=" /etc/systemd/system/xray.service.d/limits.conf 2>/dev/null && echo "true" || echo "false"; }
check_buffer_state()   { grep -q 'XRAY_RAY_BUFFER_SIZE=64' /etc/systemd/system/xray.service.d/limits.conf 2>/dev/null && echo "true" || echo "false"; }
check_dnsmasq_state()  { systemctl is-active dnsmasq >/dev/null 2>&1 && grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null && echo "true" || echo "false"; }
check_cake_state()     { sysctl net.core.default_qdisc 2>/dev/null | grep -q 'cake' && echo "true" || echo "false"; }
check_ackfilter_state(){ [[ -f "$FLAGS_DIR/ack_filter" ]] && echo "true" || echo "false"; }
check_ecn_state()      { [[ -f "$FLAGS_DIR/ecn" ]]        && echo "true" || echo "false"; }
check_wash_state()     { [[ -f "$FLAGS_DIR/wash" ]]       && echo "true" || echo "false"; }

check_thp_state() {
    local f="/sys/kernel/mm/transparent_hugepage/enabled"
    [[ ! -f "$f" || ! -w "$f" ]] && echo "unsupported" && return
    grep -q '\[never\]' "$f" 2>/dev/null && echo "true" || echo "false"
}
check_mtu_state() {
    [[ ! -f "/proc/sys/net/ipv4/tcp_mtu_probing" ]] && echo "unsupported" && return
    [[ "$(sysctl -n net.ipv4.tcp_mtu_probing 2>/dev/null)" == "1" ]] && echo "true" || echo "false"
}
check_cpu_state() {
    [[ ! -d "/sys/devices/system/cpu/cpu0/cpufreq" ]] && echo "unsupported" && return
    grep -q 'performance' /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null && echo "true" || echo "false"
}
check_ring_state() {
    local IFACE; IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
    [[ -z "$IFACE" ]] || ! command -v ethtool >/dev/null 2>&1 && echo "unsupported" && return
    local rx; rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Current hardware" | grep "RX:" | head -1 | awk '{print $2}')
    [[ -z "$rx" ]] && echo "unsupported" && return
    [[ "$rx" == "512" ]] && echo "true" || echo "false"
}
check_zram_state() {
    modprobe -n zram >/dev/null 2>&1 || lsmod | grep -q zram || { echo "unsupported"; return; }
    swapon --show 2>/dev/null | grep -q 'zram' && echo "true" || echo "false"
}
check_journal_state() {
    [[ ! -f "/etc/systemd/journald.conf" ]] && echo "unsupported" && return
    grep -q '^Storage=volatile' /etc/systemd/journald.conf 2>/dev/null && echo "true" || echo "false"
}
check_process_priority_state() {
    grep -q "^OOMScoreAdjust=-500" /etc/systemd/system/xray.service.d/limits.conf 2>/dev/null && echo "true" || echo "false"
}
check_gso_off_state() {
    local IFACE; IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
    ! command -v ethtool >/dev/null 2>&1 && echo "unsupported" && return
    local info; info=$(ethtool -k "$IFACE" 2>/dev/null || echo "")
    [[ -z "$info" ]] && echo "unsupported" && return
    echo "$info" | grep -E "^generic-receive-offload:|^rx-gro:" | grep -q "fixed" && echo "unsupported" && return
    echo "$info" | grep -E "^generic-receive-offload:|^rx-gro:" | grep -q " off" && echo "true" || echo "false"
}
check_irq_state() {
    local CORES; CORES=$(nproc)
    ((CORES < 2)) && echo "unsupported" && return
    local IFACE; IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
    local irq; irq=$(grep "$IFACE" /proc/interrupts 2>/dev/null | head -1 | awk '{print $1}' | tr -d ':')
    [[ -n "$irq" ]] || { echo "false"; return; }
    local mask; mask=$(cat "/proc/irq/$irq/smp_affinity" 2>/dev/null | tr -d '0')
    [[ "$mask" == "1" ]] && echo "true" || echo "false"
}

# ── Toggle 引擎 ───────────────────────────────────────────────
_toggle_affinity_on() {
    local lf="/etc/systemd/system/xray.service.d/limits.conf"
    [[ ! -f "$lf" ]] && return
    sed -i '/^CPUAffinity=/d;/^Environment="GOMAXPROCS=/d' "$lf"
    local TARGET_CPU; TARGET_CPU=$( (($(nproc) >= 2)) && echo "1" || echo "0" )
    echo "CPUAffinity=$TARGET_CPU" >> "$lf"
    echo "Environment=\"GOMAXPROCS=1\"" >> "$lf"
    systemctl daemon-reload
}
_toggle_affinity_off() {
    local lf="/etc/systemd/system/xray.service.d/limits.conf"
    [[ ! -f "$lf" ]] && return
    sed -i '/^CPUAffinity=/d;/^Environment="GOMAXPROCS=/d' "$lf"
    systemctl daemon-reload
}
toggle_buffer() {
    local lf="/etc/systemd/system/xray.service.d/limits.conf"
    [[ ! -f "$lf" ]] && return
    sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$lf"
    [[ "$(check_buffer_state)" != "true" ]] && echo "Environment=\"XRAY_RAY_BUFFER_SIZE=64\"" >> "$lf"
    systemctl daemon-reload
}

toggle_dnsmasq() {
    if [[ "$(check_dnsmasq_state)" == "true" ]]; then
        systemctl stop dnsmasq; systemctl disable dnsmasq
        chattr -i /etc/resolv.conf 2>/dev/null || true
        [[ -f /etc/resolv.conf.bak ]] && mv -f /etc/resolv.conf.bak /etc/resolv.conf \
            || echo "nameserver 8.8.8.8" > /etc/resolv.conf
        systemctl enable systemd-resolved 2>/dev/null || true
        systemctl start  systemd-resolved 2>/dev/null || true
        _safe_jq_write '.dns = {"servers":["https://8.8.8.8/dns-query","https://1.1.1.1/dns-query","https://doh.opendns.com/dns-query"],"queryStrategy":"UseIP"}'
    else
        pkg_install dnsmasq
        systemctl stop systemd-resolved 2>/dev/null || true
        systemctl disable systemd-resolved 2>/dev/null || true
        cat > /etc/dnsmasq.conf << 'EOF'
port=53
listen-address=127.0.0.1
bind-interfaces
cache-size=21000
min-cache-ttl=3600
all-servers
server=8.8.8.8
server=1.1.1.1
server=208.67.222.222
no-resolv
no-poll
EOF
        systemctl enable dnsmasq; systemctl restart dnsmasq
        chattr -i /etc/resolv.conf 2>/dev/null || true
        [[ ! -f /etc/resolv.conf.bak ]] && cp /etc/resolv.conf /etc/resolv.conf.bak 2>/dev/null || true
        echo "nameserver 127.0.0.1" > /etc/resolv.conf
        chattr +i /etc/resolv.conf 2>/dev/null || true
        _safe_jq_write '.dns = {"servers":["127.0.0.1"],"queryStrategy":"UseIP"}'
    fi
}

toggle_thp() {
    local f_en="/sys/kernel/mm/transparent_hugepage/enabled"
    local f_df="/sys/kernel/mm/transparent_hugepage/defrag"
    [[ "$(check_thp_state)" == "unsupported" ]] && return
    if [[ "$(check_thp_state)" == "true" ]]; then
        echo always > "$f_en" 2>/dev/null || true
        echo always > "$f_df" 2>/dev/null || true
    else
        echo never  > "$f_en" 2>/dev/null || true
        echo never  > "$f_df" 2>/dev/null || true
    fi
    update_hw_boot_script
}

toggle_mtu() {
    local conf="/etc/sysctl.d/99-network-optimized.conf"
    [[ "$(check_mtu_state)" == "unsupported" ]] && return
    if [[ "$(check_mtu_state)" == "true" ]]; then
        sed -i 's/^net.ipv4.tcp_mtu_probing.*/net.ipv4.tcp_mtu_probing = 0/' "$conf" 2>/dev/null || true
    else
        grep -q "net.ipv4.tcp_mtu_probing" "$conf" 2>/dev/null \
            && sed -i 's/^net.ipv4.tcp_mtu_probing.*/net.ipv4.tcp_mtu_probing = 1/' "$conf" \
            || echo "net.ipv4.tcp_mtu_probing = 1" >> "$conf"
    fi
    sysctl -p "$conf" >/dev/null 2>&1 || true
}

toggle_cpu() {
    [[ "$(check_cpu_state)" == "unsupported" ]] && return
    local target
    [[ "$(check_cpu_state)" == "true" ]] && target="schedutil" || target="performance"
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        [[ -f "$cpu" ]] && echo "$target" > "$cpu" 2>/dev/null || true
    done
    update_hw_boot_script
}

toggle_ring() {
    [[ "$(check_ring_state)" == "unsupported" ]] && return
    local IFACE; IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    if [[ "$(check_ring_state)" == "true" ]]; then
        local max_rx; max_rx=$(ethtool -g "$IFACE" 2>/dev/null | grep -A4 "Pre-set maximums" | grep "RX:" | head -1 | awk '{print $2}')
        [[ -n "$max_rx" ]] && ethtool -G "$IFACE" rx "$max_rx" tx "$max_rx" 2>/dev/null || true
    else
        ethtool -G "$IFACE" rx 512 tx 512 2>/dev/null || true
    fi
    update_hw_boot_script
}

toggle_gso_off() {
    [[ "$(check_gso_off_state)" == "unsupported" ]] && return
    local IFACE; IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    if [[ "$(check_gso_off_state)" == "true" ]]; then
        ethtool -K "$IFACE" gro on  gso on  tso on  2>/dev/null || true
    else
        ethtool -K "$IFACE" gro off gso off tso off 2>/dev/null || true
    fi
    update_hw_boot_script
}

toggle_zram() {
    [[ "$(check_zram_state)" == "unsupported" ]] && return
    if [[ "$(check_zram_state)" == "true" ]]; then
        swapoff /dev/zram0 2>/dev/null || true
        rmmod zram 2>/dev/null || true
        systemctl disable --now xray-zram.service 2>/dev/null || true
        rm -f /etc/systemd/system/xray-zram.service /usr/local/bin/xray-zram.sh
    else
        local total; total=$(free -m | awk '/Mem/{print $2}')
        local sz
        ((total < 500))  && sz=$((total*2)) || \
        ((total < 1024)) && sz=$((total*3/2)) || sz=$total

        cat > /usr/local/bin/xray-zram.sh << EOFZ
#!/bin/bash
modprobe zram num_devices=1
echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || true
echo "${sz}M" > /sys/block/zram0/disksize
mkswap /dev/zram0
swapon -p 100 /dev/zram0
EOFZ
        chmod +x /usr/local/bin/xray-zram.sh
        cat > /etc/systemd/system/xray-zram.service << 'EOFZ'
[Unit]
Description=Xray ZRAM
After=network.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/xray-zram.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOFZ
        systemctl daemon-reload; systemctl enable --now xray-zram.service
    fi
}

toggle_journal() {
    [[ "$(check_journal_state)" == "unsupported" ]] && return
    local conf="/etc/systemd/journald.conf"
    if [[ "$(check_journal_state)" == "true" ]]; then
        sed -i 's/^Storage=volatile/#Storage=auto/' "$conf" 2>/dev/null || true
    else
        grep -q "^Storage=" "$conf" 2>/dev/null \
            && sed -i 's/^Storage=.*/Storage=volatile/' "$conf" \
            || echo "Storage=volatile" >> "$conf"
    fi
    systemctl restart systemd-journald
}

toggle_process_priority() {
    local lf="/etc/systemd/system/xray.service.d/limits.conf"
    [[ ! -f "$lf" ]] && return
    if grep -q "^OOMScoreAdjust=-500" "$lf"; then
        sed -i '/^OOMScoreAdjust=/d;/^IOSchedulingClass=/d;/^IOSchedulingPriority=/d' "$lf"
    else
        { echo "OOMScoreAdjust=-500"; echo "IOSchedulingClass=realtime"; echo "IOSchedulingPriority=2"; } >> "$lf"
    fi
    systemctl daemon-reload
}

toggle_cake() {
    local conf="/etc/sysctl.d/99-network-optimized.conf"
    local IFACE; IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    local cake_opts; cake_opts=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
    if [[ "$(check_cake_state)" == "true" ]]; then
        sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = fq/' "$conf" 2>/dev/null || true
        sysctl -w net.core.default_qdisc=fq >/dev/null 2>&1 || true
        tc qdisc replace dev "$IFACE" root fq 2>/dev/null || true
    else
        grep -q "net.core.default_qdisc" "$conf" 2>/dev/null \
            && sed -i 's/^net.core.default_qdisc.*/net.core.default_qdisc = cake/' "$conf" \
            || echo "net.core.default_qdisc = cake" >> "$conf"
        modprobe sch_cake 2>/dev/null || true
        sysctl -w net.core.default_qdisc=cake >/dev/null 2>&1 || true
        local af=""; [[ "$(check_ackfilter_state)" == "true" ]] && af="ack-filter"
        local ef=""; [[ "$(check_ecn_state)" == "true" ]]       && ef="ecn"
        local wf=""; [[ "$(check_wash_state)" == "true" ]]      && wf="wash"
        tc qdisc replace dev "$IFACE" root cake $cake_opts $af $ef $wf 2>/dev/null || true
    fi
    update_hw_boot_script
}

toggle_ackfilter() {
    [[ "$(check_ackfilter_state)" == "true" ]] && rm -f "$FLAGS_DIR/ack_filter" || touch "$FLAGS_DIR/ack_filter"
    [[ "$(check_cake_state)" == "false" ]] && { warn "CAKE 未启用，设置已保存待生效"; sleep 2; return; }
    _apply_cake_live
}
toggle_ecn() {
    [[ "$(check_ecn_state)" == "true" ]] && rm -f "$FLAGS_DIR/ecn" || touch "$FLAGS_DIR/ecn"
    [[ "$(check_cake_state)" == "false" ]] && { warn "CAKE 未启用，设置已保存待生效"; sleep 2; return; }
    _apply_cake_live
}
toggle_wash() {
    [[ "$(check_wash_state)" == "true" ]] && rm -f "$FLAGS_DIR/wash" || touch "$FLAGS_DIR/wash"
    [[ "$(check_cake_state)" == "false" ]] && { warn "CAKE 未启用，设置已保存待生效"; sleep 2; return; }
    _apply_cake_live
}

toggle_irq() {
    [[ "$(check_irq_state)" == "unsupported" ]] && return
    local IFACE; IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    local CORES; CORES=$(nproc)
    if [[ "$(check_irq_state)" == "true" ]]; then
        local default_mask; default_mask=$(printf "%x" $(( (1<<CORES)-1 )))
        for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':'); do
            echo "$default_mask" > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true
        done
        systemctl start  irqbalance 2>/dev/null || true
        systemctl enable irqbalance 2>/dev/null || true
    else
        systemctl stop    irqbalance 2>/dev/null || true
        systemctl disable irqbalance 2>/dev/null || true
        for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':'); do
            echo 1 > "/proc/irq/$irq/smp_affinity" 2>/dev/null || true
        done
    fi
    update_hw_boot_script
}

_apply_cake_live() {
    local IFACE; IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    [[ "$(check_cake_state)" != "true" ]] && return
    local base; base=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "")
    local af=""; [[ "$(check_ackfilter_state)" == "true" ]] && af="ack-filter"
    local ef=""; [[ "$(check_ecn_state)" == "true" ]]       && ef="ecn"
    local wf=""; [[ "$(check_wash_state)" == "true" ]]      && wf="wash"
    # shellcheck disable=SC2086
    tc qdisc replace dev "$IFACE" root cake $base $af $ef $wf 2>/dev/null || true
    update_hw_boot_script
}

# ── 开机底盘脚本生成器 ─────────────────────────────────────────
update_hw_boot_script() {
    cat > /usr/local/bin/xray-hw-tweaks.sh << 'SHEOF'
#!/bin/bash
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}')
if [ -z "$IFACE" ]; then sleep 3; IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}'); fi
SHEOF

    [[ "$(check_thp_state)" == "true" ]] && cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
echo never > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
echo never > /sys/kernel/mm/transparent_hugepage/defrag  2>/dev/null || true
EOF

    [[ "$(check_cpu_state)" == "true" ]] && cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -f "$cpu" ] && echo performance > "$cpu" 2>/dev/null || true
done
EOF

    [[ "$(check_ring_state)" == "true" ]] && \
        echo "ethtool -G \$IFACE rx 512 tx 512 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh

    local gso_st; gso_st=$(check_gso_off_state)
    [[ "$gso_st" == "true" ]]  && echo "ethtool -K \$IFACE gro off gso off tso off 2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh
    [[ "$gso_st" == "false" ]] && echo "ethtool -K \$IFACE gro on  gso on  tso on  2>/dev/null || true" >> /usr/local/bin/xray-hw-tweaks.sh

    # CAKE 动态参数注入
    cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
CAKE_OPTS=""; [ -f "/usr/local/etc/xray/cake_opts.txt" ] && CAKE_OPTS=$(cat "/usr/local/etc/xray/cake_opts.txt")
ACK_FLAG="";  [ -f "/usr/local/etc/xray/flags/ack_filter" ] && ACK_FLAG="ack-filter"
ECN_FLAG="";  [ -f "/usr/local/etc/xray/flags/ecn" ]        && ECN_FLAG="ecn"
WASH_FLAG=""; [ -f "/usr/local/etc/xray/flags/wash" ]       && WASH_FLAG="wash"
EOF

    [[ "$(check_cake_state)" == "true" ]] && \
        echo 'tc qdisc replace dev $IFACE root cake $CAKE_OPTS $ACK_FLAG $ECN_FLAG $WASH_FLAG 2>/dev/null || true' \
            >> /usr/local/bin/xray-hw-tweaks.sh

    [[ "$(check_irq_state)" == "true" ]] && cat >> /usr/local/bin/xray-hw-tweaks.sh << 'EOF'
systemctl stop irqbalance 2>/dev/null || true
for irq in $(grep "$IFACE" /proc/interrupts 2>/dev/null | awk '{print $1}' | tr -d ':'); do
    echo 1 > /proc/irq/$irq/smp_affinity 2>/dev/null || true
done
EOF

    chmod +x /usr/local/bin/xray-hw-tweaks.sh

    # [时序绝杀] 强制 network-online.target
    cat > /etc/systemd/system/xray-hw-tweaks.service << 'EOF'
[Unit]
Description=Xray Hardware Tweaks
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=/usr/local/bin/xray-hw-tweaks.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable xray-hw-tweaks.service >/dev/null 2>&1
}

# ── CAKE 高阶参数配置 ──────────────────────────────────────────
config_cake_advanced() {
    clear; title "CAKE 高阶调度参数配置"
    local cur; cur=$(cat "$CAKE_OPTS_FILE" 2>/dev/null || echo "无 (默认)")
    echo -e "  当前参数: ${cyan}${cur}${none}\n"

    read -rp "  1) 带宽声明 (如 900Mbit/1Gbit，0=不限): " c_bw
    read -rp "  2) Overhead 字节补偿 (以太网=18,VPN=48，0=不设): " c_oh
    read -rp "  3) MPU 最小包大小 (64或84，0=不设): " c_mpu
    echo    "  4) RTT模式: 1)Internet(85ms) 2)Oceanic(300ms,推荐) 3)Satellite(1000ms)"
    read -rp "     选择(默认2): " rtt_sel
    echo    "  5) 分类: 1)Diffserv4  2)Besteffort(推荐,盲走)"
    read -rp "     选择(默认2): " diff_sel

    local opts=""
    [[ -n "$c_bw"  && "$c_bw"  != "0" ]] && opts="$opts bandwidth $c_bw"
    [[ -n "$c_oh"  && "$c_oh"  != "0" ]] && opts="$opts overhead $c_oh"
    [[ -n "$c_mpu" && "$c_mpu" != "0" ]] && opts="$opts mpu $c_mpu"
    case "${rtt_sel:-2}" in 1) opts="$opts internet";; 3) opts="$opts satellite";; *) opts="$opts oceanic";; esac
    case "${diff_sel:-2}" in 1) opts="$opts diffserv4";; *) opts="$opts besteffort";; esac
    opts="${opts#"${opts%%[! ]*}"}"  # ltrim

    if [[ -z "$opts" ]]; then rm -f "$CAKE_OPTS_FILE"; info "已清除，恢复默认"
    else echo "$opts" > "$CAKE_OPTS_FILE"; info "CAKE 参数已保存: $opts"; fi

    _apply_cake_live
    read -rp "按 Enter 继续..." _
}

# ── 网络栈调优 ────────────────────────────────────────────────
do_perf_tuning() {
    title "极限网络栈调优"
    warn "此操作将重写 sysctl 并重启！"
    read -rp "确定继续? (y/n): " confirm
    [[ "$confirm" != "y" ]] && return

    systemctl stop net-speeder 2>/dev/null || true
    killall net-speeder 2>/dev/null || true
    rm -f /etc/systemd/system/net-speeder.service
    systemctl daemon-reload >/dev/null 2>&1

    local target_qdisc="fq"
    [[ "$(check_cake_state)" == "true" ]] && target_qdisc="cake"

    cat > /etc/sysctl.d/99-network-optimized.conf << EOF
net.core.default_qdisc = ${target_qdisc}
net.ipv4.tcp_congestion_control = bbr
net.ipv4.neigh.default.base_reachable_time_ms = 60000
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_mtu_probing = 1
net.core.rmem_max = 21699928
net.core.wmem_max = 21699928
net.ipv4.tcp_rmem = 4096 760576 21699928
net.ipv4.tcp_wmem = 4096 760576 21699928
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_timestamps = 1
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
fs.file-max = 1048576
vm.swappiness = 1
net.ipv4.ip_forward = 1
EOF
    sysctl --system >/dev/null 2>&1

    local IFACE; IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    if [[ -n "$IFACE" ]]; then
        cat > /usr/local/bin/nic-optimize.sh << 'EONIC'
#!/bin/bash
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
ethtool -K $IFACE lro off rx-gro-hw off 2>/dev/null || true
EONIC
        chmod +x /usr/local/bin/nic-optimize.sh
        cat > /etc/systemd/system/nic-optimize.service << 'EOSERVICE'
[Unit]
Description=NIC Hardware Optimization
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/nic-optimize.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOSERVICE
        systemctl daemon-reload
        systemctl enable --now nic-optimize.service >/dev/null 2>&1
    fi

    info "调优完成！30 秒后重启..."
    sleep 30; reboot
}

do_txqueuelen_opt() {
    title "TX Queue 发送队列调优"
    local IFACE; IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
    [[ -z "$IFACE" ]] && { error "无法获取网卡"; read -rp "Enter..." _; return 1; }
    ip link set "$IFACE" txqueuelen 2000
    cat > /etc/systemd/system/txqueue.service << EOF
[Unit]
Description=Set TX Queue Length
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=$(command -v ip) link set $IFACE txqueuelen 2000
RemainAfterExit=true
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload; systemctl enable --now txqueue >/dev/null 2>&1
    info "txqueuelen=2000 已应用"
    ip link show "$IFACE" | grep -o 'qlen [0-9]*'
    read -rp "按 Enter 继续..." _
}

do_install_xanmod_main_official() {
    title "安装官方 XANMOD 预编译内核"
    [[ "$(uname -m)" != "x86_64" ]] && { error "仅支持 x86_64"; read -rp "Enter..." _; return; }
    [[ ! -f /etc/debian_version ]] && { error "仅支持 Debian/Ubuntu"; read -rp "Enter..." _; return; }

    print_magenta ">>> [1/4] 检测 CPU 向量等级..."
    local lvl_script="/tmp/check_x86-64_psabi.sh"
    wget -qO "$lvl_script" https://dl.xanmod.org/check_x86-64_psabi.sh
    local cpu_level; cpu_level=$(awk -f "$lvl_script" 2>/dev/null | grep -oE '[1-4]' | tail -1)
    rm -f "$lvl_script"
    cpu_level=${cpu_level:-1}
    info "CPU 向量等级: v${cpu_level}"

    local pkg="linux-xanmod-x64v${cpu_level}"
    print_magenta ">>> [2/4] 配置 Xanmod APT 源..."
    pkg_install gnupg gnupg2 curl sudo wget
    echo 'deb http://deb.xanmod.org releases main' > /etc/apt/sources.list.d/xanmod-kernel.list
    wget -qO - https://dl.xanmod.org/gpg.key | gpg --dearmor --yes \
        -o /etc/apt/trusted.gpg.d/xanmod-kernel.gpg

    print_magenta ">>> [3/4] 安装 $pkg..."
    apt-get update -y
    apt-get install -y "$pkg" || \
        (warn "降级尝试 v3..."; apt-get install -y "linux-xanmod-x64v3")

    print_magenta ">>> [4/4] 更新 GRUB..."
    command -v update-grub >/dev/null 2>&1 || pkg_install grub2-common
    update-grub

    info "XANMOD 已就绪！10 秒后重启..."
    sleep 10; reboot
}

# ══════════════════════════════════════════════════════════════
# 第八区: 应用层全域 25 项 + 一键上帝开关
# ══════════════════════════════════════════════════════════════

_turn_on_app() {
    _safe_jq_write '
      .routing = (.routing // {}) | .routing.domainMatcher = "mph" |
      .outbounds = [.outbounds[]? | if .protocol == "freedom" then
          .streamSettings = (.streamSettings // {}) |
          .streamSettings.sockopt = (.streamSettings.sockopt // {}) |
          .streamSettings.sockopt.tcpNoDelay = true |
          .streamSettings.sockopt.tcpFastOpen = true |
          .streamSettings.sockopt.tcpKeepAliveIdle = 30 |
          .streamSettings.sockopt.tcpKeepAliveInterval = 15
        else . end] |
      .inbounds = [.inbounds[]? | if (.protocol == "vless" or .protocol == "shadowsocks") then
          .streamSettings = (.streamSettings // {}) |
          .streamSettings.sockopt = (.streamSettings.sockopt // {}) |
          .streamSettings.sockopt.tcpNoDelay = true |
          .streamSettings.sockopt.tcpFastOpen = true |
          .streamSettings.sockopt.tcpKeepAliveIdle = 30 |
          .streamSettings.sockopt.tcpKeepAliveInterval = 15 |
          .sniffing = (.sniffing // {}) |
          .sniffing.metadataOnly = true | .sniffing.routeOnly = true
        else . end]
    '

    local has_reality; has_reality=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .protocol' "$CONFIG" 2>/dev/null | head -1)
    [[ -n "$has_reality" ]] && _safe_jq_write '
      .inbounds = [.inbounds[]? | if (.protocol == "vless" and .streamSettings.security == "reality") then
          .streamSettings.realitySettings = (.streamSettings.realitySettings // {}) |
          .streamSettings.realitySettings.maxTimeDiff = 60000
        else . end]
    '

    local dns_srv
    if [[ "$(check_dnsmasq_state)" == "true" ]]; then
        dns_srv='["127.0.0.1"]'
    else
        dns_srv='["https://8.8.8.8/dns-query","https://1.1.1.1/dns-query","https://doh.opendns.com/dns-query"]'
    fi
    _safe_jq_write ".dns = {\"servers\":${dns_srv},\"queryStrategy\":\"UseIP\"}"

    _safe_jq_write '.policy = {"levels":{"0":{"handshake":3,"connIdle":60}},"system":{"statsInboundDownlink":false,"statsInboundUplink":false}}'
    _toggle_affinity_on

    local lf="/etc/systemd/system/xray.service.d/limits.conf"
    if [[ -f "$lf" ]]; then
        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$lf"
        echo 'Environment="XRAY_RAY_BUFFER_SIZE=64"' >> "$lf"
        local total_mem; total_mem=$(free -m | awk '/Mem/{print $2}')
        local gc=100
        ((total_mem >= 1800)) && gc=1000 || ((total_mem >= 900)) && gc=500 || gc=300
        sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=$gc\"/" "$lf"
        systemctl daemon-reload
    fi
}

_turn_off_app() {
    _safe_jq_write '
      del(.routing.domainMatcher) |
      .outbounds = [.outbounds[]? | if .protocol == "freedom" then
          del(.streamSettings.sockopt.tcpNoDelay,.streamSettings.sockopt.tcpFastOpen,
              .streamSettings.sockopt.tcpKeepAliveIdle,.streamSettings.sockopt.tcpKeepAliveInterval)
        else . end] |
      .inbounds = [.inbounds[]? | if (.protocol=="vless" or .protocol=="shadowsocks") then
          del(.streamSettings.sockopt.tcpNoDelay,.streamSettings.sockopt.tcpFastOpen,
              .streamSettings.sockopt.tcpKeepAliveIdle,.streamSettings.sockopt.tcpKeepAliveInterval) |
          .sniffing = (.sniffing // {}) |
          .sniffing.metadataOnly = false | .sniffing.routeOnly = false
        else . end]
    '
    _safe_jq_write '
      .inbounds = [.inbounds[]? | if (.protocol=="vless" and .streamSettings.security=="reality") then
          del(.streamSettings.realitySettings.maxTimeDiff)
        else . end] | del(.dns) | del(.policy)
    '
    _toggle_affinity_off
    local lf="/etc/systemd/system/xray.service.d/limits.conf"
    if [[ -f "$lf" ]]; then
        sed -i '/^Environment="XRAY_RAY_BUFFER_SIZE=/d' "$lf"
        sed -i 's/^Environment="GOGC=.*/Environment="GOGC=100"/' "$lf"
        systemctl daemon-reload
    fi
}

do_app_level_tuning_menu() {
    while true; do
        clear; title "全域 25 项极限微操 + 3 项上帝开关"
        [[ ! -f "$CONFIG" ]] && { error "未发现配置"; read -rp "Enter..." _; return; }

        # ── 读取所有状态 ──
        local out_fo;    out_fo=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpFastOpen // "false"' "$CONFIG" 2>/dev/null | head -1)
        local out_ka;    out_ka=$(jq -r '.outbounds[]? | select(.protocol=="freedom") | .streamSettings.sockopt.tcpKeepAliveIdle // "0"' "$CONFIG" 2>/dev/null | head -1)
        local sniff_st;  sniff_st=$(check_sniff_state)
        local dns_st;    dns_st=$(jq -r '.dns.queryStrategy // "false"' "$CONFIG" 2>/dev/null | head -1)
        local pol_st;    pol_st=$(jq -r '.policy.levels["0"].connIdle // "0"' "$CONFIG" 2>/dev/null | head -1)
        local aff_st;    aff_st=$(check_affinity_state)
        local mph_st;    mph_st=$(check_mph_state)
        local maxt_st;   maxt_st=$(check_maxtime_state)
        local ro_st;     ro_st=$(check_routeonly_state)
        local buf_st;    buf_st=$(check_buffer_state)
        local lf="/etc/systemd/system/xray.service.d/limits.conf"
        local gc_st;     gc_st=$(awk -F'=' '/^Environment="GOGC=/{print $3}' "$lf" 2>/dev/null | tr -d '"' | head -1); gc_st=${gc_st:-100}
        local has_reality; has_reality=$(jq -r '.inbounds[]? | select(.protocol=="vless" and .streamSettings?.security=="reality") | .protocol' "$CONFIG" 2>/dev/null | head -1)

        local dnsmasq_st=$(check_dnsmasq_state) thp_st=$(check_thp_state) mtu_st=$(check_mtu_state)
        local cpu_st=$(check_cpu_state) ring_st=$(check_ring_state) zram_st=$(check_zram_state)
        local jnl_st=$(check_journal_state) prio_st=$(check_process_priority_state)
        local cake_st=$(check_cake_state) irq_st=$(check_irq_state) gso_st=$(check_gso_off_state)
        local ack_st=$(check_ackfilter_state) ecn_st=$(check_ecn_state) wash_st=$(check_wash_state)

        # ── UI 状态映射宏 ──
        local _on="${cyan}已开启${none}" _off="${gray}未开启${none}" _uns="${gray}不支持${none}"
        s1()  { [[ "$out_fo"  == "true"  ]] && echo "$_on" || echo "$_off"; }
        s2()  { [[ "$out_ka"  == "30"    ]] && echo "${cyan}已开启(30s/15s)${none}" || echo "$_off"; }
        s3()  { [[ "$sniff_st" == "true" ]] && echo "$_on" || echo "$_off"; }
        s4()  { [[ "$dns_st"  == "UseIP" ]] && echo "$_on" || echo "$_off"; }
        s5()  { echo "${cyan}${gc_st}${none}"; }
        s6()  { [[ "$pol_st"  == "60"    ]] && echo "${cyan}已开启(60s)${none}" || echo "$_off"; }
        s7()  { [[ "$aff_st"  == "true"  ]] && echo "${cyan}已锁死单核${none}" || echo "$_off"; }
        s8()  { [[ "$mph_st"  == "true"  ]] && echo "${cyan}MPH就绪${none}" || echo "$_off"; }
        s9()  { [[ -z "$has_reality" ]] && echo "${gray}无Reality${none}" || { [[ "$maxt_st" == "true" ]] && echo "${cyan}防重放(60s)${none}" || echo "$_off"; }; }
        s10() { [[ "$ro_st"   == "true"  ]] && echo "${cyan}盲走快车道${none}" || echo "$_off"; }
        s11() { [[ "$buf_st"  == "true"  ]] && echo "${cyan}巨型重卡池(64K)${none}" || echo "$_off"; }
        s12() { [[ "$dnsmasq_st" == "true"    ]] && echo "${cyan}内存极速缓存${none}" || echo "$_off"; }
        s13() { [[ "$thp_st" == "unsupported" ]] && echo "$_uns" || { [[ "$thp_st" == "true" ]] && echo "${cyan}THP已关闭${none}" || echo "$_off"; }; }
        s14() { [[ "$mtu_st" == "unsupported" ]] && echo "$_uns" || { [[ "$mtu_st" == "true" ]] && echo "${cyan}PMTU探测中${none}" || echo "$_off"; }; }
        s15() { [[ "$cpu_st" == "unsupported"  ]] && echo "$_uns" || { [[ "$cpu_st" == "true" ]] && echo "${cyan}全核火力${none}" || echo "$_off"; }; }
        s16() { [[ "$ring_st" == "unsupported" ]] && echo "$_uns" || { [[ "$ring_st" == "true" ]] && echo "${cyan}Ring收缩${none}" || echo "$_off"; }; }
        s17() { [[ "$zram_st" == "unsupported" ]] && echo "$_uns" || { [[ "$zram_st" == "true" ]] && echo "${cyan}ZRAM已挂载${none}" || echo "$_off"; }; }
        s18() { [[ "$jnl_st" == "unsupported"  ]] && echo "$_uns" || { [[ "$jnl_st" == "true" ]] && echo "${cyan}日志内存化${none}" || echo "$_off"; }; }
        s19() { [[ "$prio_st" == "true"  ]] && echo "${cyan}OOM免死/IO抢占${none}" || echo "$_off"; }
        s20() { [[ "$cake_st" == "true"  ]] && echo "${cyan}CAKE削峰中${none}" || echo "$_off"; }
        s21() { [[ "$irq_st" == "unsupported" ]] && echo "$_uns" || { [[ "$irq_st" == "true" ]] && echo "${cyan}IRQ锁Core0${none}" || echo "$_off"; }; }
        s22() { [[ "$gso_st" == "unsupported" ]] && echo "$_uns" || { [[ "$gso_st" == "true" ]] && echo "${cyan}GSO已打散${none}" || echo "$_off"; }; }
        s23() { [[ "$ack_st" == "true"   ]] && echo "${cyan}ACK绞杀中${none}" || echo "$_off"; }
        s24() { [[ "$ecn_st" == "true"   ]] && echo "${cyan}ECN零丢包${none}" || echo "$_off"; }
        s25() { [[ "$wash_st" == "true"  ]] && echo "${cyan}Wash清洗中${none}" || echo "$_off"; }

        echo -e "  ${magenta}─── Xray 应用层 (1-11) ───────────────────────────────────${none}"
        printf "  1)  双向并发提速 (tcpNoDelay/FastOpen)              | %s\n" "$(s1)"
        printf "  2)  Socket 智能保活心跳 (KeepAlive Idle=30s)        | %s\n" "$(s2)"
        printf "  3)  嗅探引擎减负 (metadataOnly)                     | %s\n" "$(s3)"
        printf "  4)  内置并发DoH/Dnsmasq 路由分发                    | %s\n" "$(s4)"
        printf "  5)  GOGC 内存阶梯飙车调优                           | %s\n" "$(s5)"
        printf "  6)  Xray Policy 策略组极速回收                      | %s\n" "$(s6)"
        printf "  7)  进程绑核 & GOMAXPROCS                           | %s\n" "$(s7)"
        printf "  8)  MPH 路由极速降维引擎                            | %s\n" "$(s8)"
        printf "  9)  Reality 防重放 (maxTimeDiff=60s)                | %s\n" "$(s9)"
        printf "  10) 零拷贝旁路盲转发 (routeOnly)                    | %s\n" "$(s10)"
        printf "  11) XRAY_RAY_BUFFER_SIZE=64 巨型重卡池              | %s\n" "$(s11)"
        echo -e "  ${magenta}─── Linux 系统层 (12-25) ──────────────────────────────────${none}"
        printf "  12) Dnsmasq 本地内存缓存(21000并发/锁TTL)           | %s\n" "$(s12)"
        printf "  13) 透明大页 THP (关闭=优化)                        | %s\n" "$(s13)"
        printf "  14) TCP PMTU 黑洞智能探测                           | %s\n" "$(s14)"
        printf "  15) CPU 频率 Performance 锁定                       | %s\n" "$(s15)"
        printf "  16) Ring Buffer 反向收缩 (512)                      | %s\n" "$(s16)"
        printf "  17) ZRAM 内存压缩交换                               | %s\n" "$(s17)"
        printf "  18) Journald 纯内存日志                             | %s\n" "$(s18)"
        printf "  19) OOM免杀/IO实时调度抢占                          | %s\n" "$(s19)"
        printf "  20) CAKE 智能队列 (取代fq)                          | %s\n" "$(s20)"
        printf "  21) 网卡硬中断 IRQ 锁死 Core0                       | %s\n" "$(s21)"
        printf "  22) GSO/GRO 卸载反转 (打散小包降延迟)               | %s\n" "$(s22)"
        printf "  23) CAKE ack-filter 绞杀上行 ACK                    | %s\n" "$(s23)"
        printf "  24) CAKE ECN 零丢包平滑降速                         | %s\n" "$(s24)"
        printf "  25) CAKE Wash 报文清洗(免疫路由ECN头污染)           | %s\n" "$(s25)"
        echo -e ""
        echo -e "  ${cyan}26) 一键开关 1-11 应用层 (自动侦测反转)${none}"
        echo -e "  ${yellow}27) 一键开关 12-25 系统层 (自动避障反转)${none}"
        echo -e "  ${red}28) 创世之手：一键开关 1-25 全域 (执行后强制重启)${none}"
        echo -e "  0) 返回"
        hr
        read -rp "选择: " app_opt

        # ── 统计 off 数量用于上帝开关方向判断 ──
        local app_off=0 sys_off=0
        [[ "$out_fo"     != "true"  ]] && ((app_off++)); [[ "$out_ka"   != "30"   ]] && ((app_off++))
        [[ "$sniff_st"   != "true"  ]] && ((app_off++)); [[ "$dns_st"   != "UseIP"]] && ((app_off++))
        [[ "$gc_st"      == "100"   ]] && ((app_off++)); [[ "$pol_st"   != "60"   ]] && ((app_off++))
        [[ "$aff_st"     != "true"  ]] && ((app_off++)); [[ "$mph_st"   != "true" ]] && ((app_off++))
        [[ "$ro_st"      != "true"  ]] && ((app_off++)); [[ "$buf_st"   != "true" ]] && ((app_off++))
        [[ -n "$has_reality" && "$maxt_st" != "true" ]] && ((app_off++))

        for st in "$dnsmasq_st" "$thp_st" "$mtu_st" "$cpu_st" "$ring_st" "$zram_st" \
                  "$jnl_st" "$prio_st" "$cake_st" "$irq_st" "$gso_st" \
                  "$ack_st" "$ecn_st" "$wash_st"; do
            [[ "$st" == "false" ]] && ((sys_off++))
        done

        case "$app_opt" in
            1)  # FastOpen
                if [[ "$out_fo" == "true" ]]; then
                    _safe_jq_write '
                      .outbounds=[.outbounds[]? | if .protocol=="freedom" then del(.streamSettings.sockopt.tcpNoDelay,.streamSettings.sockopt.tcpFastOpen) else . end] |
                      .inbounds=[.inbounds[]? | if (.protocol=="vless" or .protocol=="shadowsocks") then del(.streamSettings.sockopt.tcpNoDelay,.streamSettings.sockopt.tcpFastOpen) else . end]
                    '
                else
                    _safe_jq_write '
                      .outbounds=[.outbounds[]? | if .protocol=="freedom" then .streamSettings=(.streamSettings//{})|.streamSettings.sockopt=(.streamSettings.sockopt//{})|.streamSettings.sockopt.tcpNoDelay=true|.streamSettings.sockopt.tcpFastOpen=true else . end] |
                      .inbounds=[.inbounds[]? | if (.protocol=="vless" or .protocol=="shadowsocks") then .streamSettings=(.streamSettings//{})|.streamSettings.sockopt=(.streamSettings.sockopt//{})|.streamSettings.sockopt.tcpNoDelay=true|.streamSettings.sockopt.tcpFastOpen=true else . end]
                    '
                fi; systemctl restart xray >/dev/null 2>&1; read -rp "Enter..." _ ;;
            2)  # KeepAlive
                if [[ "$out_ka" == "30" ]]; then
                    _safe_jq_write '
                      .outbounds=[.outbounds[]? | if .protocol=="freedom" then del(.streamSettings.sockopt.tcpKeepAliveIdle,.streamSettings.sockopt.tcpKeepAliveInterval) else . end] |
                      .inbounds=[.inbounds[]? | if (.protocol=="vless" or .protocol=="shadowsocks") then del(.streamSettings.sockopt.tcpKeepAliveIdle,.streamSettings.sockopt.tcpKeepAliveInterval) else . end]
                    '
                else
                    _safe_jq_write '
                      .outbounds=[.outbounds[]? | if .protocol=="freedom" then .streamSettings=(.streamSettings//{})|.streamSettings.sockopt=(.streamSettings.sockopt//{})|.streamSettings.sockopt.tcpKeepAliveIdle=30|.streamSettings.sockopt.tcpKeepAliveInterval=15 else . end] |
                      .inbounds=[.inbounds[]? | if (.protocol=="vless" or .protocol=="shadowsocks") then .streamSettings=(.streamSettings//{})|.streamSettings.sockopt=(.streamSettings.sockopt//{})|.streamSettings.sockopt.tcpKeepAliveIdle=30|.streamSettings.sockopt.tcpKeepAliveInterval=15 else . end]
                    '
                fi; systemctl restart xray >/dev/null 2>&1; read -rp "Enter..." _ ;;
            3)  # metadataOnly
                if [[ "$sniff_st" == "true" ]]; then
                    _safe_jq_write '.inbounds=[.inbounds[]? | if (.protocol=="vless" or .protocol=="shadowsocks") then .sniffing.metadataOnly=false else . end]'
                else
                    _safe_jq_write '.inbounds=[.inbounds[]? | if (.protocol=="vless" or .protocol=="shadowsocks") then .sniffing=(.sniffing//{})|.sniffing.metadataOnly=true else . end]'
                fi; systemctl restart xray >/dev/null 2>&1; read -rp "Enter..." _ ;;
            4)  # DNS
                if [[ "$dns_st" == "UseIP" ]]; then
                    _safe_jq_write 'del(.dns)'
                else
                    if [[ "$(check_dnsmasq_state)" == "true" ]]; then
                        _safe_jq_write '.dns={"servers":["127.0.0.1"],"queryStrategy":"UseIP"}'
                    else
                        _safe_jq_write '.dns={"servers":["https://8.8.8.8/dns-query","https://1.1.1.1/dns-query"],"queryStrategy":"UseIP"}'
                    fi
                fi; systemctl restart xray >/dev/null 2>&1; read -rp "Enter..." _ ;;
            5)  # GOGC
                if [[ -f "$lf" ]]; then
                    local total_mem; total_mem=$(free -m | awk '/Mem/{print $2}')
                    local new_gc=100
                    ((total_mem >= 1800)) && new_gc=1000 || ((total_mem >= 900)) && new_gc=500 || new_gc=300
                    if [[ "$gc_st" == "100" ]]; then
                        sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=$new_gc\"/" "$lf"
                    else
                        sed -i "s/^Environment=\"GOGC=.*/Environment=\"GOGC=100\"/" "$lf"
                    fi
                    systemctl daemon-reload; systemctl restart xray >/dev/null 2>&1
                fi; read -rp "Enter..." _ ;;
            6)  # Policy
                [[ "$pol_st" == "60" ]] && _safe_jq_write 'del(.policy)' || \
                    _safe_jq_write '.policy={"levels":{"0":{"handshake":3,"connIdle":60}},"system":{"statsInboundDownlink":false,"statsInboundUplink":false}}'
                systemctl restart xray >/dev/null 2>&1; read -rp "Enter..." _ ;;
            7)  # Affinity
                [[ "$aff_st" == "true" ]] && _toggle_affinity_off || _toggle_affinity_on
                systemctl restart xray >/dev/null 2>&1; read -rp "Enter..." _ ;;
            8)  # MPH
                [[ "$mph_st" == "true" ]] && _safe_jq_write 'del(.routing.domainMatcher)' || \
                    _safe_jq_write '.routing=(.routing//{})|.routing.domainMatcher="mph"'
                systemctl restart xray >/dev/null 2>&1; read -rp "Enter..." _ ;;
            9)  # maxTimeDiff
                if [[ -n "$has_reality" ]]; then
                    if [[ "$maxt_st" == "true" ]]; then
                        _safe_jq_write '.inbounds=[.inbounds[]? | if (.protocol=="vless" and .streamSettings.security=="reality") then del(.streamSettings.realitySettings.maxTimeDiff) else . end]'
                    else
                        _safe_jq_write '.inbounds=[.inbounds[]? | if (.protocol=="vless" and .streamSettings.security=="reality") then .streamSettings.realitySettings=(.streamSettings.realitySettings//{})|.streamSettings.realitySettings.maxTimeDiff=60000 else . end]'
                    fi
                    systemctl restart xray >/dev/null 2>&1
                fi; read -rp "Enter..." _ ;;
            10) # routeOnly
                if [[ "$ro_st" == "true" ]]; then
                    _safe_jq_write '.inbounds=[.inbounds[]? | if (.protocol=="vless" or .protocol=="shadowsocks") then .sniffing.routeOnly=false else . end]'
                else
                    _safe_jq_write '.inbounds=[.inbounds[]? | if (.protocol=="vless" or .protocol=="shadowsocks") then .sniffing=(.sniffing//{})|.sniffing.routeOnly=true else . end]'
                fi; systemctl restart xray >/dev/null 2>&1; read -rp "Enter..." _ ;;
            11) toggle_buffer; systemctl restart xray >/dev/null 2>&1; read -rp "Enter..." _ ;;
            12) toggle_dnsmasq;          read -rp "Enter..." _ ;;
            13) toggle_thp;              read -rp "Enter..." _ ;;
            14) toggle_mtu;              read -rp "Enter..." _ ;;
            15) toggle_cpu;              read -rp "Enter..." _ ;;
            16) toggle_ring;             read -rp "Enter..." _ ;;
            17) toggle_zram;             read -rp "Enter..." _ ;;
            18) toggle_journal;          read -rp "Enter..." _ ;;
            19) toggle_process_priority; read -rp "Enter..." _ ;;
            20) toggle_cake;             read -rp "Enter..." _ ;;
            21) toggle_irq;              read -rp "Enter..." _ ;;
            22)
                if [[ "$gso_st" == "unsupported" ]]; then
                    warn "网卡驱动锁死，不可更改"; sleep 2
                else
                    toggle_gso_off; read -rp "Enter..." _
                fi ;;
            23) toggle_ackfilter;        read -rp "Enter..." _ ;;
            24) toggle_ecn;              read -rp "Enter..." _ ;;
            25) toggle_wash;             read -rp "Enter..." _ ;;
            26) # 上帝开关 应用层
                if ((app_off > 0)); then _turn_on_app;  info "1-11 已全开"
                else                     _turn_off_app; info "1-11 已全关"; fi
                systemctl restart xray >/dev/null 2>&1; read -rp "Enter..." _ ;;
            27) # 上帝开关 系统层
                local _action; ((sys_off > 0)) && _action="open" || _action="close"
                for fn in dnsmasq thp mtu cpu ring zram journal process_priority cake irq gso_off ackfilter ecn wash; do
                    local st_var="${fn}_st"
                    local cur_st="${!st_var:-false}"
                    if [[ "$_action" == "open"  && "$cur_st" == "false" ]]; then "toggle_$fn" 2>/dev/null || true
                    elif [[ "$_action" == "close" && "$cur_st" == "true"  ]]; then "toggle_$fn" 2>/dev/null || true; fi
                done
                info "12-25 系统层操作完毕"; read -rp "Enter..." _ ;;
            28) # 创世之手
                if (( (app_off + sys_off) > 0 )); then
                    ((app_off > 0)) && _turn_on_app
                    ((sys_off > 0)) && {
                        for fn in dnsmasq thp mtu cpu ring zram journal process_priority cake irq gso_off ackfilter ecn wash; do
                            local st_var="${fn}_st"; local cur_st="${!st_var:-false}"
                            [[ "$cur_st" == "false" ]] && "toggle_$fn" 2>/dev/null || true
                        done
                    }
                else
                    _turn_off_app
                    for fn in dnsmasq thp mtu cpu ring zram journal process_priority cake irq gso_off ackfilter ecn wash; do
                        local st_var="${fn}_st"; local cur_st="${!st_var:-false}"
                        [[ "$cur_st" == "true" ]] && "toggle_$fn" 2>/dev/null || true
                    done
                fi
                echo -e "\n${red}全域变更完成！6 秒后强制重启${none}"
                for i in {6..1}; do echo -ne "\r  重启: ${cyan}${i}s${none}..."; sleep 1; done
                sync; reboot ;;
            0) return ;;
        esac
    done
}

# ══════════════════════════════════════════════════════════════
# 第九区: 安装主逻辑 (VLESS/SS/Naive/Hysteria2)
# ══════════════════════════════════════════════════════════════

do_install() {
    title "V172 多协议核心部署"
    preflight
    systemctl stop xray 2>/dev/null || true
    [[ ! -f "$INSTALL_DATE_FILE" ]] && date +"%Y-%m-%d %H:%M:%S" > "$INSTALL_DATE_FILE"

    echo -e "  ${cyan}请选择安装的协议：${none}"
    echo "  1) VLESS-Reality (强力防封，推荐)"
    echo "  2) Shadowsocks"
    echo "  3) VLESS-Reality + Shadowsocks"
    echo "  4) VLESS-Reality + NaiveProxy (Clash/Stash 兼容)"
    echo "  5) VLESS-Reality + Hysteria2 (UDP 加速)"
    echo "  6) 全家桶 (VLESS + SS + NaiveProxy + Hysteria2)"
    read -rp "  编号(默认1): " proto_choice
    proto_choice=${proto_choice:-1}

    # ── VLESS 参数 ──
    if [[ "$proto_choice" =~ ^[1345 6]$ ]]; then
        while true; do
            read -rp "VLESS 端口(默认443): " input_p; input_p=${input_p:-443}
            validate_port "$input_p" && LISTEN_PORT="$input_p" && break
        done
        read -rp "节点备注(默认xp-reality): " input_r; REMARK_NAME=${input_r:-xp-reality}
        choose_sni || return 1
    fi

    # ── SS 参数 ──
    local ss_port=8388 ss_pass="" ss_method="aes-256-gcm"
    if [[ "$proto_choice" =~ ^[236]$ ]]; then
        while true; do
            read -rp "SS 端口(默认8388): " input_s; input_s=${input_s:-8388}
            validate_port "$input_s" && ss_port="$input_s" && break
        done
        ss_pass=$(gen_ss_pass)
        ss_method=$(_select_ss_method)
    fi

    # ── Naive 参数 ──
    local naive_domain="" naive_email="" naive_user="naive" naive_pass="" naive_port=8443
    if [[ "$proto_choice" =~ ^[46]$ ]]; then
        read -rp "NaiveProxy 域名(必须已解析到本机): " naive_domain
        while ! validate_domain "$naive_domain"; do
            error "域名格式无效"; read -rp "重新输入: " naive_domain
        done
        read -rp "邮箱(用于ACME证书): " naive_email
        naive_email=${naive_email:-admin@${naive_domain}}
        read -rp "Naive 用户名(默认naive): " naive_user; naive_user=${naive_user:-naive}
        naive_pass=$(gen_ss_pass)
        while true; do
            read -rp "Naive 端口(默认8443): " np; np=${np:-8443}
            validate_port "$np" && naive_port="$np" && break
        done
    fi

    # ── Hysteria2 参数 ──
    local hy2_domain="" hy2_email="" hy2_pass="" hy2_port=443
    if [[ "$proto_choice" =~ ^[56]$ ]]; then
        read -rp "Hysteria2 域名: " hy2_domain
        read -rp "Hysteria2 邮箱: " hy2_email; hy2_email=${hy2_email:-admin@${hy2_domain}}
        hy2_pass=$(gen_ss_pass)
        while true; do
            read -rp "Hysteria2 端口(默认443，注意与VLESS不同端口): " hp; hp=${hp:-443}
            validate_port "$hp" && hy2_port="$hp" && break
        done
    fi

    # ── 安装 Xray ──
    print_magenta ">>> 安装 Xray Core..."
    bash -c "$(curl -fsSL --connect-timeout 10 https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1
    install_update_dat
    fix_xray_systemd_limits

    # ── 基础配置骨架 ──
    cat > "$CONFIG" << 'EOF'
{
  "log":{"loglevel":"warning"},
  "routing":{
    "domainStrategy":"AsIs",
    "rules":[
      {"outboundTag":"block","_enabled":true,"protocol":["bittorrent"]},
      {"outboundTag":"block","_enabled":true,"ip":["geoip:cn"]},
      {"outboundTag":"block","_enabled":true,"domain":["geosite:cn","geosite:category-ads-all"]}
    ]
  },
  "inbounds":[],
  "outbounds":[
    {"protocol":"freedom","tag":"direct","settings":{"domainStrategy":"AsIs"}},
    {"protocol":"blackhole","tag":"block"}
  ]
}
EOF

    # ── VLESS-Reality 入站 ──
    if [[ "$proto_choice" =~ ^[1345 6]$ ]]; then
        local keys priv pub uuid sid ctime
        keys=$("$XRAY_BIN" x25519 2>/dev/null)
        priv=$(echo "$keys" | grep -i "Private" | awk -F': ' '{print $2}' | tr -d ' ')
        pub=$(echo  "$keys" | grep -i "Public"  | awk -F': ' '{print $2}' | tr -d ' ')
        uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
        sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n')
        ctime=$(date +"%Y-%m-%d %H:%M")

        echo "$pub" > "$PUBKEY_FILE"
        echo "$uuid|$ctime" > "$USER_TIME_MAP"

        echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
        local vless_inbound
        vless_inbound=$(cat << EOF
{
  "tag":"vless-reality","listen":"0.0.0.0","port":$LISTEN_PORT,"protocol":"vless",
  "settings":{
    "clients":[{"id":"$uuid","flow":"xtls-rprx-vision","email":"$REMARK_NAME"}],
    "decryption":"none"
  },
  "streamSettings":{
    "network":"tcp","security":"reality",
    "sockopt":{"tcpNoDelay":true,"tcpFastOpen":true},
    "realitySettings":{
      "dest":"$BEST_SNI:443","serverNames":[],
      "privateKey":"$priv","publicKey":"$pub","shortIds":["$sid"]
    }
  },
  "sniffing":{"enabled":true,"destOverride":["http","tls","quic"]}
}
EOF
)
        echo "$vless_inbound" > /tmp/vless_tmp.json
        jq --slurpfile snis /tmp/sni_array.json '.streamSettings.realitySettings.serverNames=$snis[0]' \
            /tmp/vless_tmp.json > /tmp/vless_final.json
        jq '.inbounds += [input]' "$CONFIG" /tmp/vless_final.json > "$CONFIG.tmp" && mv -f "$CONFIG.tmp" "$CONFIG"
        rm -f /tmp/vless_tmp.json /tmp/vless_final.json /tmp/sni_array.json
    fi

    # ── SS 入站 ──
    if [[ "$proto_choice" =~ ^[236]$ ]]; then
        local ss_inbound
        ss_inbound=$(cat << EOF
{
  "tag":"shadowsocks","listen":"0.0.0.0","port":$ss_port,"protocol":"shadowsocks",
  "settings":{"method":"$ss_method","password":"$ss_pass","network":"tcp,udp"},
  "streamSettings":{"sockopt":{"tcpNoDelay":true,"tcpFastOpen":true}}
}
EOF
)
        echo "$ss_inbound" > /tmp/ss_tmp.json
        jq '.inbounds += [input]' "$CONFIG" /tmp/ss_tmp.json > "$CONFIG.tmp" && mv -f "$CONFIG.tmp" "$CONFIG"
        rm -f /tmp/ss_tmp.json
    fi

    fix_permissions
    systemctl enable xray >/dev/null 2>&1
    systemctl restart xray >/dev/null 2>&1

    # ── Naive ──
    if [[ "$proto_choice" =~ ^[46]$ && -n "$naive_domain" ]]; then
        install_caddy_naive || warn "Caddy 安装失败，跳过 NaiveProxy"
        command -v "$CADDY_BIN" >/dev/null 2>&1 && config_naive "$naive_domain" "$naive_email" "$naive_user" "$naive_pass" "$naive_port"
    fi

    # ── Hysteria2 ──
    if [[ "$proto_choice" =~ ^[56]$ && -n "$hy2_domain" ]]; then
        install_hysteria2 || warn "Hysteria2 安装失败，跳过"
        command -v "$HY2_BIN" >/dev/null 2>&1 && config_hysteria2 "$hy2_domain" "$hy2_port" "$hy2_pass" "$hy2_email"
    fi

    info "所有协议部署完成！"
    log_info "协议安装完成: proto_choice=$proto_choice"
    do_summary
    read -rp "按 Enter 返回主菜单，或 b 重配 SNI: " opt
    if [[ "$opt" == "b" || "$opt" == "B" ]]; then
        choose_sni && _update_matrix && do_summary
    fi
}

# ══════════════════════════════════════════════════════════════
# 第十区: 分发中心 / 用户管理 / 屏蔽规则
# ══════════════════════════════════════════════════════════════

do_summary() {
    [[ ! -f "$CONFIG" ]] && return
    title "V172 节点分发中心"

    # ── VLESS-Reality 节点 ──
    local client_count; client_count=$(jq '.inbounds[]? | select(.protocol=="vless") | .settings.clients | length' "$CONFIG" 2>/dev/null || echo 0)
    if ((client_count > 0)); then
        local port; port=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .port' "$CONFIG" 2>/dev/null)
        local pub;  pub=$(jq -r  '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.publicKey' "$CONFIG" 2>/dev/null)
        local main_sni; main_sni=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0]' "$CONFIG" 2>/dev/null)

        for ((i=0; i<client_count; i++)); do
            local uuid remark sid target_sni
            uuid=$(jq -r ".inbounds[]? | select(.protocol==\"vless\") | .settings.clients[$i].id" "$CONFIG" 2>/dev/null)
            remark=$(jq -r ".inbounds[]? | select(.protocol==\"vless\") | .settings.clients[$i].email // \"$REMARK_NAME\"" "$CONFIG" 2>/dev/null)
            sid=$(jq -r ".inbounds[]? | select(.protocol==\"vless\") | .streamSettings.realitySettings.shortIds[$i]" "$CONFIG" 2>/dev/null)
            target_sni=$(grep "^$uuid|" "$USER_SNI_MAP" 2>/dev/null | cut -d'|' -f2 || echo "")
            target_sni=${target_sni:-$main_sni}

            [[ -z "$uuid" || "$uuid" == "null" ]] && continue
            hr
            echo -e "  ${cyan}【VLESS-Reality | $remark】${none}"
            printf "  ${yellow}%-12s${none} %s\n" "IP:"   "$SERVER_IP"
            printf "  ${yellow}%-12s${none} %s\n" "端口:" "$port"
            printf "  ${yellow}%-12s${none} %s\n" "UUID:" "$uuid"
            printf "  ${yellow}%-12s${none} %s\n" "SNI:"  "$target_sni"
            printf "  ${yellow}%-12s${none} %s\n" "SID:"  "$sid"
            local link="vless://${uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${target_sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${remark}"
            echo -e "\n  ${cyan}链接:${none} $link\n"
            command -v qrencode >/dev/null 2>&1 && qrencode -m 2 -t UTF8 "$link"
        done
    fi

    # ── SS 节点 ──
    local has_ss; has_ss=$(jq -r '.inbounds[]? | select(.protocol=="shadowsocks") | .protocol' "$CONFIG" 2>/dev/null | head -1)
    if [[ -n "$has_ss" && "$has_ss" != "null" ]]; then
        local s_port s_pass s_method
        s_port=$(jq -r '.inbounds[]? | select(.protocol=="shadowsocks") | .port' "$CONFIG" 2>/dev/null)
        s_pass=$(jq -r '.inbounds[]? | select(.protocol=="shadowsocks") | .settings.password' "$CONFIG" 2>/dev/null)
        s_method=$(jq -r '.inbounds[]? | select(.protocol=="shadowsocks") | .settings.method' "$CONFIG" 2>/dev/null)
        hr
        echo -e "  ${cyan}【Shadowsocks】${none}"
        printf "  ${yellow}%-12s${none} %s\n" "端口:"   "$s_port"
        printf "  ${yellow}%-12s${none} %s\n" "密码:"   "$s_pass"
        printf "  ${yellow}%-12s${none} %s\n" "加密:"   "$s_method"
        local b64; b64=$(printf '%s' "${s_method}:${s_pass}" | base64 | tr -d '\n')
        local ss_link="ss://${b64}@${SERVER_IP}:${s_port}#${REMARK_NAME}-SS"
        echo -e "\n  ${cyan}链接:${none} $ss_link\n"
        command -v qrencode >/dev/null 2>&1 && qrencode -m 2 -t UTF8 "$ss_link"
    fi

    # ── NaiveProxy 节点 ──
    if [[ -f "$CADDY_CONF" ]]; then
        local np_user np_pass np_domain np_port
        np_user=$(awk '/basic_auth/{print $2}' "$CADDY_CONF" 2>/dev/null | head -1)
        np_pass=$(awk '/basic_auth/{print $3}' "$CADDY_CONF" 2>/dev/null | head -1)
        np_port=$(grep -oP ':\K[0-9]+' "$CADDY_CONF" 2>/dev/null | head -1)
        np_domain=$(awk 'NR==1 && /^[a-zA-Z0-9]/{sub(/:.*/,"",$1); print $1}' "$CADDY_CONF" 2>/dev/null)
        if [[ -n "$np_user" ]]; then
            hr
            echo -e "  ${cyan}【NaiveProxy (Clash/Stash)】${none}"
            printf "  ${yellow}%-12s${none} %s\n" "域名:"   "$np_domain"
            printf "  ${yellow}%-12s${none} %s\n" "端口:"   "$np_port"
            printf "  ${yellow}%-12s${none} %s\n" "用户:"   "$np_user"
            printf "  ${yellow}%-12s${none} %s\n" "密码:"   "$np_pass"
            local np_link="https://${np_user}:${np_pass}@${np_domain}:${np_port}#NaiveProxy"
            echo -e "\n  ${cyan}Clash/Stash 配置:${none}"
            cat << EOF
  - name: "NaiveProxy-${np_domain}"
    type: http
    server: ${np_domain}
    port: ${np_port}
    username: ${np_user}
    password: ${np_pass}
    tls: true
    sni: ${np_domain}
    skip-cert-verify: false
EOF
            echo -e "\n  ${cyan}分享链接:${none} $np_link"
        fi
    fi

    # ── Hysteria2 节点 ──
    if [[ -f "$HY2_CONF" ]] && systemctl is-active hysteria-server >/dev/null 2>&1; then
        local hy2_domain hy2_port hy2_pass
        hy2_port=$(awk '/^listen:/{gsub(/:/,"",$2); print $2}' "$HY2_CONF" 2>/dev/null)
        hy2_pass=$(awk '/password:/{print $2}' "$HY2_CONF" 2>/dev/null | head -1)
        hy2_domain=$(awk '/^  - /{print $2}' "$HY2_CONF" 2>/dev/null | head -1)
        hr
        echo -e "  ${cyan}【Hysteria2 (UDP 加速)】${none}"
        printf "  ${yellow}%-12s${none} %s\n" "域名:" "$hy2_domain"
        printf "  ${yellow}%-12s${none} %s\n" "端口:" "$hy2_port"
        printf "  ${yellow}%-12s${none} %s\n" "密码:" "$hy2_pass"
        local hy2_link="hysteria2://${hy2_pass}@${hy2_domain}:${hy2_port}?sni=${hy2_domain}#Hysteria2"
        echo -e "\n  ${cyan}Clash Meta / Sing-Box 链接:${none} $hy2_link"
        echo -e "\n  ${cyan}Clash Meta 配置:${none}"
        cat << EOF
  - name: "Hysteria2-${hy2_domain}"
    type: hysteria2
    server: ${hy2_domain}
    port: ${hy2_port}
    password: ${hy2_pass}
    sni: ${hy2_domain}
    skip-cert-verify: false
EOF
    fi

    hr
    echo -e "  ${gray}配置文件: $CONFIG | 备份目录: $BACKUP_DIR${none}"
}

do_user_manager() {
    while true; do
        title "用户管理 (增删/导入/专属SNI)"
        [[ ! -f "$CONFIG" ]] && { error "未发现配置"; return; }

        local clients; clients=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .settings?.clients[]? | .id + "|" + (.email // "无备注")' "$CONFIG" 2>/dev/null)
        [[ -z "$clients" || "$clients" == "null" ]] && { error "无 VLESS 节点"; return; }

        local tmp_users="/tmp/xray_users_$$.txt"
        echo "$clients" | awk -F'|' '{print NR"|"$1"|"$2}' > "$tmp_users"
        while IFS='|' read -r num uid remark; do
            local utime; utime=$(grep "^$uid|" "$USER_TIME_MAP" 2>/dev/null | cut -d'|' -f2 || echo "未知")
            echo -e "  $num) ${cyan}$remark${none} | ${gray}$utime${none} | ${yellow}$uid${none}"
        done < "$tmp_users"
        hr
        echo "  a) 新增用户    m) 导入外部    s) 修改SNI    d) 删除    q) 退出"
        read -rp "指令: " uopt

        case "$uopt" in
            a|A)
                local nu sid ctime
                nu=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || "$XRAY_BIN" uuid)
                sid=$(head -c 8 /dev/urandom | xxd -p | tr -d '\n')
                ctime=$(date +"%Y-%m-%d %H:%M")
                read -rp "备注: " u_remark; u_remark=${u_remark:-User-${sid}}

                jq --arg id "$nu" --arg email "$u_remark" \
                    '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"id":$id,"flow":"xtls-rprx-vision","email":$email}]' \
                    "$CONFIG" > "$CONFIG.tmp" && mv -f "$CONFIG.tmp" "$CONFIG"
                jq --arg sid "$sid" \
                    '(.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.shortIds) += [$sid]' \
                    "$CONFIG" > "$CONFIG.tmp" && mv -f "$CONFIG.tmp" "$CONFIG"

                echo "$nu|$ctime" >> "$USER_TIME_MAP"
                fix_permissions; systemctl restart xray >/dev/null 2>&1

                local port pub sni
                port=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .port' "$CONFIG" | head -1)
                pub=$(jq -r  '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.publicKey' "$CONFIG" | head -1)
                sni=$(jq -r  '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0]' "$CONFIG" | head -1)
                local link="vless://${nu}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pub}&sid=${sid}&type=tcp#${u_remark}"
                info "创建成功"; echo -e "\n  ${cyan}链接:${none} $link\n"
                command -v qrencode >/dev/null 2>&1 && qrencode -m 2 -t UTF8 "$link"
                read -rp "Enter..." _ ;;

            m|M)
                read -rp "备注: " m_remark; m_remark=${m_remark:-ImportedUser}
                read -rp "UUID: " m_uuid; [[ -z "$m_uuid" ]] && continue
                read -rp "ShortId: " m_sid; [[ -z "$m_sid" ]] && continue
                local ctime; ctime=$(date +"%Y-%m-%d %H:%M")

                jq --arg id "$m_uuid" --arg email "$m_remark" \
                    '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"id":$id,"flow":"xtls-rprx-vision","email":$email}]' \
                    "$CONFIG" > "$CONFIG.tmp" && mv -f "$CONFIG.tmp" "$CONFIG"
                jq --arg sid "$m_sid" \
                    '(.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.shortIds) += [$sid]' \
                    "$CONFIG" > "$CONFIG.tmp" && mv -f "$CONFIG.tmp" "$CONFIG"
                echo "$m_uuid|$ctime" >> "$USER_TIME_MAP"

                read -rp "专属SNI(回车默认): " m_sni
                if [[ -n "$m_sni" ]]; then
                    jq --arg sni "$m_sni" \
                        '(.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) += [$sni] |
                         (.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) |= unique' \
                        "$CONFIG" > "$CONFIG.tmp" && mv -f "$CONFIG.tmp" "$CONFIG"
                    echo "$m_uuid|$m_sni" >> "$USER_SNI_MAP"
                else
                    m_sni=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames[0]' "$CONFIG" | head -1)
                fi

                fix_permissions; systemctl restart xray >/dev/null 2>&1
                local port pub
                port=$(jq -r '.inbounds[]? | select(.protocol=="vless") | .port' "$CONFIG" | head -1)
                pub=$(jq -r  '.inbounds[]? | select(.protocol=="vless") | .streamSettings.realitySettings.publicKey' "$CONFIG" | head -1)
                local link="vless://${m_uuid}@${SERVER_IP}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${m_sni}&fp=chrome&pbk=${pub}&sid=${m_sid}&type=tcp#${m_remark}"
                info "导入成功"; echo -e "\n  ${cyan}链接:${none} $link\n"
                command -v qrencode >/dev/null 2>&1 && qrencode -m 2 -t UTF8 "$link"
                read -rp "Enter..." _ ;;

            s|S)
                read -rp "序号: " snum
                local t_uuid t_remark
                t_uuid=$(awk -F'|' -v id="${snum:-0}" '$1==id{print $2}' "$tmp_users")
                t_remark=$(awk -F'|' -v id="${snum:-0}" '$1==id{print $3}' "$tmp_users")
                if [[ -n "$t_uuid" ]]; then
                    read -rp "专属SNI: " u_sni
                    if [[ -n "$u_sni" ]]; then
                        jq --arg sni "$u_sni" \
                            '(.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) += [$sni] |
                             (.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.serverNames) |= unique' \
                            "$CONFIG" > "$CONFIG.tmp" && mv -f "$CONFIG.tmp" "$CONFIG"
                        sed -i "/^$t_uuid|/d" "$USER_SNI_MAP" 2>/dev/null; echo "$t_uuid|$u_sni" >> "$USER_SNI_MAP"
                        fix_permissions; systemctl restart xray >/dev/null 2>&1; info "SNI 绑定: $u_sni"
                    fi
                    read -rp "Enter..." _
                else error "无效序号"; fi ;;

            d|D)
                read -rp "序号: " dnum
                local total; total=$(wc -l < "$tmp_users" 2>/dev/null)
                if ((total <= 1)); then error "至少保留一个用户"
                else
                    local t_uuid; t_uuid=$(awk -F'|' -v id="${dnum:-0}" '$1==id{print $2}' "$tmp_users")
                    if [[ -n "$t_uuid" ]]; then
                        local idx=$(( ${dnum:-0} - 1 ))
                        jq --arg uid "$t_uuid" --argjson i "$idx" \
                            '(.inbounds[] | select(.protocol=="vless") | .settings.clients) |= map(select(.id != $uid)) |
                             (.inbounds[] | select(.protocol=="vless") | .streamSettings.realitySettings.shortIds) |= del(.[$i])' \
                            "$CONFIG" > "$CONFIG.tmp" && mv -f "$CONFIG.tmp" "$CONFIG"
                        sed -i "/^$t_uuid|/d" "$USER_SNI_MAP" 2>/dev/null
                        sed -i "/^$t_uuid|/d" "$USER_TIME_MAP" 2>/dev/null
                        fix_permissions; systemctl restart xray >/dev/null 2>&1; info "已删除"
                    fi
                fi ;;
            q|Q) rm -f "$tmp_users"; break ;;
        esac
    done
}

_global_block_rules() {
    while true; do
        title "屏蔽规则管理 (BT/广告)"
        [[ ! -f "$CONFIG" ]] && { error "未发现配置"; return; }
        local bt_en; bt_en=$(jq -r '.routing.rules[]? | select(.protocol != null) | select(.protocol | index("bittorrent")) | ._enabled' "$CONFIG" 2>/dev/null | head -1)
        local ad_en; ad_en=$(jq -r '.routing.rules[]? | select(.domain != null) | select(.domain | index("geosite:category-ads-all")) | ._enabled' "$CONFIG" 2>/dev/null | head -1)
        echo -e "  1) BT/PT 协议拦截   | ${yellow}${bt_en:-未知}${none}"
        echo -e "  2) 全球广告拦截     | ${yellow}${ad_en:-未知}${none}"
        echo    "  0) 返回"
        read -rp "选择: " bc
        case "$bc" in
            1)
                local nv="true"; [[ "$bt_en" == "true" ]] && nv="false"
                jq --argjson nv "$nv" '.routing.rules=[.routing.rules[]? | if .protocol != null and (.protocol | index("bittorrent")) then ._enabled=$nv else . end]' \
                    "$CONFIG" > "$CONFIG.tmp" && mv -f "$CONFIG.tmp" "$CONFIG"
                fix_permissions; systemctl restart xray >/dev/null 2>&1; info "BT拦截: $nv" ;;
            2)
                local nv="true"; [[ "$ad_en" == "true" ]] && nv="false"
                jq --argjson nv "$nv" '.routing.rules=[.routing.rules[]? | if .domain != null and (.domain | index("geosite:category-ads-all")) then ._enabled=$nv else . end]' \
                    "$CONFIG" > "$CONFIG.tmp" && mv -f "$CONFIG.tmp" "$CONFIG"
                fix_permissions; systemctl restart xray >/dev/null 2>&1; info "广告拦截: $nv" ;;
            0) return ;;
        esac
    done
}

# ══════════════════════════════════════════════════════════════
# 第十一区: 运行状态与监控
# ══════════════════════════════════════════════════════════════

do_status_menu() {
    while true; do
        title "运行状态与计费中心"
        echo "  1) 服务状态"
        echo "  2) 网络信息"
        echo "  3) 流量计费 (vnstat)"
        echo "  4) 实时连接 (IP统计雷达)"
        echo "  5) CPU优先级调整"
        echo "  6) 查看操作日志"
        echo "  7) 查看错误日志"
        echo "  8) 配置备份管理"
        echo "  0) 返回"
        hr; read -rp "选择: " s

        case "$s" in
            1)
                clear; title "服务状态"
                for svc in xray caddy hysteria-server; do
                    local st; st=$(systemctl is-active "$svc" 2>/dev/null || echo "未安装")
                    printf "  %-20s %s\n" "$svc:" "${st}"
                done
                echo ""; systemctl status xray --no-pager 2>/dev/null || true
                read -rp "Enter..." _ ;;
            2)
                echo -e "\n  公网 IP: ${green}$SERVER_IP${none}"
                hr
                echo -e "  DNS:"
                grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print "    "$0}' || echo "    无法读取"
                hr
                echo -e "  Xray 监听:"
                ss -tlnp 2>/dev/null | grep xray | awk '{print "    "$4}' || echo "    未监听"
                read -rp "Enter..." _ ;;
            3)
                command -v vnstat >/dev/null 2>&1 || { warn "未安装 vnstat"; read -rp "Enter..." _; continue; }
                clear; title "流量计费"
                local m_day; m_day=$(grep -E "^[[:space:]]*MonthRotate" /etc/vnstat.conf 2>/dev/null | awk '{print $2}' | head -1 || echo "1")
                echo -e "  清零日: 每月 ${cyan}$m_day${none} 号"
                hr
                vnstat -m 3 2>/dev/null || vnstat -m 2>/dev/null || warn "vnstat 数据未就绪"
                hr
                echo "  1) 设置清零日    2) 按天详情    q) 返回"
                read -rp "  指令: " vn_opt
                case "$vn_opt" in
                    1) read -rp "清零日(1-31): " d_day
                       if ((d_day >= 1 && d_day <= 31)); then
                           sed -i '/^[#[:space:]]*MonthRotate/d' /etc/vnstat.conf 2>/dev/null
                           echo "MonthRotate $d_day" >> /etc/vnstat.conf
                           systemctl restart vnstat 2>/dev/null; info "已设置: $d_day 号"
                       else error "无效"; fi; read -rp "Enter..." _ ;;
                    2) vnstat -d 2>/dev/null || warn "数据不足"; read -rp "Enter..." _ ;;
                esac ;;
            4)
                while true; do
                    clear; title "实时连接雷达 (q退出)"
                    local x_pids; x_pids=$(pidof xray 2>/dev/null | xargs | tr -s ' ' '|' || echo "")
                    if [[ -n "$x_pids" ]]; then
                        echo -e "  ${cyan}【连接分布】${none}"
                        ss -ntupa 2>/dev/null | grep -E "pid=($x_pids)[,)]" | awk '{print $1"_"$2}' | sort | uniq -c | sort -nr | \
                            awk '{printf "    %-15s : %s\n",$2,$1}' || echo "    暂无连接"
                        echo -e "\n  ${cyan}【来源IP Top10】${none}"
                        local ips; ips=$(ss -ntupa 2>/dev/null | grep -E "pid=($x_pids)[,)]" | grep -vE "LISTEN|UNCONN" | \
                            awk '{print $6}' | sed -E 's/:[0-9]+$//' | tr -d '[]' | \
                            grep -vE "^127\.|^0\.0\.0\.0$|^::$|^\*$" || echo "")
                        if [[ -n "$ips" ]]; then
                            echo "$ips" | sort | uniq -c | sort -nr | head -10 | \
                                awk '{printf "    %-20s (并发:%s)\n",$2,$1}'
                            echo -e "\n  独立IP: ${yellow}$(echo "$ips" | sort -u | wc -l)${none}"
                        else echo -e "    ${gray}无外部连接${none}"; fi
                    else echo -e "  ${red}Xray 未运行${none}"; fi
                    read -t 2 -n 1 -s cmd && [[ "$cmd" =~ [qQ] ]] && break || true
                done ;;
            5)
                local lf="/etc/systemd/system/xray.service.d/limits.conf"
                local cur_nice; cur_nice=$(awk -F'=' '/^Nice=/{print $2}' "$lf" 2>/dev/null | head -1 || echo "-20")
                echo -e "  当前 Nice: ${cyan}$cur_nice${none}"
                read -rp "  新值(-20 到 -10，q退出): " new_nice
                [[ "$new_nice" =~ ^[qQ]$ ]] && continue
                if [[ "$new_nice" =~ ^-[12][0-9]?$ ]] && ((new_nice >= -20 && new_nice <= -10)); then
                    sed -i "s/^Nice=.*/Nice=$new_nice/" "$lf"
                    systemctl daemon-reload; systemctl restart xray >/dev/null 2>&1; info "已更新: $new_nice"
                else error "无效值"; fi
                read -rp "Enter..." _ ;;
            6)
                clear; title "操作日志 (最近50行)"
                tail -50 "$LOG_DIR/xray.log" 2>/dev/null || echo "  暂无日志"
                read -rp "Enter..." _ ;;
            7)
                clear; title "错误日志 (最近30行)"
                tail -30 "$LOG_DIR/error.log" 2>/dev/null || echo "  暂无错误"
                read -rp "Enter..." _ ;;
            8)
                clear; title "配置备份管理"
                local backups; backups=$(ls -t "$BACKUP_DIR"/config_*.json 2>/dev/null || echo "")
                if [[ -z "$backups" ]]; then
                    echo "  暂无备份"
                else
                    local idx=1
                    while read -r bfile; do
                        echo -e "  $idx) $(basename "$bfile")  ($(du -h "$bfile" | cut -f1))"
                        ((idx++))
                    done <<< "$backups"
                    hr
                    echo "  r) 回滚到最新备份    c) 立即备份当前配置    0) 返回"
                    read -rp "  选择: " bopt
                    case "$bopt" in
                        r) restore_latest_backup ;;
                        c) backup_config; info "备份完成" ;;
                        0) ;;
                    esac
                fi
                read -rp "Enter..." _ ;;
            0) return ;;
        esac
    done
}

# ══════════════════════════════════════════════════════════════
# 第十二区: 系统初始化子菜单
# ══════════════════════════════════════════════════════════════

do_sys_init_menu() {
    while true; do
        title "系统初始化 / 内核调优"
        echo "  1) 更新系统、安装组件、校准时区"
        echo "  2) 安装 XANMOD 官方预编译内核 (推荐 x86_64/Debian)"
        echo "  3) 网卡 TX Queue 深度调优 (2000 极速)"
        echo "  4) 系统内核网络栈极限调优 (重启)"
        echo "  5) 全域 25 项极限微操矩阵"
        echo "  6) CAKE 高阶参数配置"
        echo "  0) 返回"
        hr; read -rp "选择: " opt
        case "$opt" in
            1)
                export DEBIAN_FRONTEND=noninteractive
                apt-get update -y >/dev/null 2>&1 || true
                apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" full-upgrade -y >/dev/null 2>&1 || true
                apt-get autoremove -y --purge >/dev/null 2>&1 || true
                pkg_install wget curl sudo socat ntpdate e2fsprogs pkg-config iproute2 ethtool
                timedatectl set-timezone Asia/Kuala_Lumpur 2>/dev/null || true
                ntpdate -u us.pool.ntp.org 2>/dev/null || true; hwclock --systohc 2>/dev/null || true
                info "更新完成，时区: Asia/Kuala_Lumpur"
                read -rp "Enter..." _ ;;
            2) do_install_xanmod_main_official ;;
            3) do_txqueuelen_opt ;;
            4) do_perf_tuning ;;
            5) do_app_level_tuning_menu ;;
            6) config_cake_advanced ;;
            0) return ;;
        esac
    done
}

# ══════════════════════════════════════════════════════════════
# 第十三区: SNI 矩阵热切 / 卸载
# ══════════════════════════════════════════════════════════════

_update_matrix() {
    [[ ! -f "$CONFIG" ]] && return
    backup_config
    echo "[$SNI_JSON_ARRAY]" > /tmp/sni_array.json
    jq --arg dest "$BEST_SNI:443" --slurpfile snis /tmp/sni_array.json \
        '.inbounds=[.inbounds[]? | if .protocol=="vless" then
           .streamSettings.realitySettings.serverNames=$snis[0] |
           .streamSettings.realitySettings.dest=$dest
         else . end]' "$CONFIG" > "$CONFIG.tmp"
    mv -f "$CONFIG.tmp" "$CONFIG"
    fix_permissions; systemctl restart xray >/dev/null 2>&1
    rm -f /tmp/sni_array.json
    info "SNI 矩阵已切换: $BEST_SNI"
    log_info "SNI 矩阵更新: $BEST_SNI"
}

do_uninstall() {
    title "彻底卸载 Xray + NaiveProxy + Hysteria2"
    read -rp "输入 y 确认彻底卸载: " confirm
    [[ "$confirm" != "y" ]] && return

    local saved_date=""
    [[ -f "$INSTALL_DATE_FILE" ]] && saved_date=$(cat "$INSTALL_DATE_FILE")

    print_magenta ">>> 停止并移除 Dnsmasq..."
    systemctl stop    dnsmasq >/dev/null 2>&1 || true
    systemctl disable dnsmasq >/dev/null 2>&1 || true
    apt-get purge -y dnsmasq >/dev/null 2>&1 || true
    chattr -i /etc/resolv.conf 2>/dev/null || true
    [[ -f /etc/resolv.conf.bak ]] && mv -f /etc/resolv.conf.bak /etc/resolv.conf \
        || echo "nameserver 8.8.8.8" > /etc/resolv.conf
    systemctl enable systemd-resolved 2>/dev/null || true
    systemctl start  systemd-resolved 2>/dev/null || true

    print_magenta ">>> 停止并移除 Caddy/NaiveProxy..."
    systemctl stop    caddy >/dev/null 2>&1 || true
    systemctl disable caddy >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/caddy.service "$CADDY_BIN"
    rm -rf /etc/caddy "$CADDY_DATA" /var/log/caddy

    print_magenta ">>> 停止并移除 Hysteria2..."
    systemctl stop    hysteria-server >/dev/null 2>&1 || true
    systemctl disable hysteria-server >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/hysteria-server.service "$HY2_BIN"
    rm -rf "$HY2_CONF_DIR"

    print_magenta ">>> 停止并移除 Xray..."
    systemctl stop    xray >/dev/null 2>&1 || true
    systemctl disable xray >/dev/null 2>&1 || true
    rm -rf /etc/systemd/system/xray.service /etc/systemd/system/xray.service.d \
           /lib/systemd/system/xray* "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" \
           "$SCRIPT_DIR" /var/log/xray "$SYMLINK" "$SCRIPT_PATH"

    (crontab -l 2>/dev/null | grep -v "update-dat.sh" | grep -v "restart xray") | crontab - 2>/dev/null || true
    systemctl daemon-reload >/dev/null 2>&1

    [[ -n "$saved_date" ]] && {
        mkdir -p "$CONFIG_DIR" 2>/dev/null
        echo "$saved_date" > "$INSTALL_DATE_FILE"
    }

    print_green "卸载完成！"
    log_info "完整卸载执行"
    exit 0
}

# ══════════════════════════════════════════════════════════════
# 第十四区: 主菜单
# ══════════════════════════════════════════════════════════════

main_menu() {
    while true; do
        clear
        echo -e "${blue}===================================================${none}"
        echo -e "  ${magenta}Xray ex172c The Eternity Evolved  V${SCRIPT_VERSION}${none}"

        local xray_st caddy_st hy2_st
        xray_st=$(systemctl is-active xray          2>/dev/null || echo "inactive")
        caddy_st=$(systemctl is-active caddy         2>/dev/null || echo "inactive")
        hy2_st=$(systemctl is-active hysteria-server 2>/dev/null || echo "inactive")

        local c_x c_c c_h
        [[ "$xray_st"  == "active" ]] && c_x="${green}运行中${none}" || c_x="${red}停止${none}"
        [[ "$caddy_st" == "active" ]] && c_c="${green}运行中${none}" || c_c="${gray}停止/未装${none}"
        [[ "$hy2_st"   == "active" ]] && c_h="${green}运行中${none}" || c_h="${gray}停止/未装${none}"

        echo -e "  Xray: $c_x | Caddy: $c_c | Hy2: $c_h"
        echo -e "  公网 IP: ${cyan}${SERVER_IP}${none} | 快捷: ${cyan}xrv${none}"
        echo -e "${blue}===================================================${none}"
        echo "  1) 核心安装 / 重构 (VLESS/SS/NaiveProxy/Hysteria2)"
        echo "  2) 用户管理 (增删/导入/专属SNI)"
        echo "  3) 分发中心 (多协议节点 + 二维码)"
        echo "  4) 手动更新 Geo 规则库"
        echo "  5) 更新 Xray Core"
        echo "  6) 热切 SNI 矩阵"
        echo "  7) 屏蔽规则管理 (BT/广告)"
        echo "  9) 运行状态与监控"
        echo "  10) 系统初始化 / 内核调优 / 全域微操"
        echo "  0) 退出"
        echo -e "  ${red}88) 彻底卸载${none}"
        hr
        read -rp "选择: " num

        case "$num" in
            1) do_install ;;
            2) do_user_manager ;;
            3)
                do_summary
                read -rp "Enter返回，b切换SNI: " rb
                [[ "$rb" =~ ^[bB]$ ]] && choose_sni && _update_matrix && do_summary
                ;;
            4)
                print_magenta ">>> 同步规则库..."
                bash "$UPDATE_DAT_SCRIPT" >/dev/null 2>&1
                systemctl restart xray >/dev/null 2>&1
                info "更新成功"; read -rp "Enter..." _ ;;
            5) do_update_core ;;
            6)
                choose_sni && _update_matrix && do_summary
                read -rp "Enter返回，b继续: " rb
                [[ "$rb" =~ ^[bB]$ ]] && choose_sni && _update_matrix && do_summary
                ;;
            7) _global_block_rules ;;
            9) do_status_menu ;;
            10) do_sys_init_menu ;;
            88) do_uninstall ;;
            0) exit 0 ;;
        esac
    done
}

# ══════════════════════════════════════════════════════════════
# 入口
# ══════════════════════════════════════════════════════════════
preflight
main_menu
