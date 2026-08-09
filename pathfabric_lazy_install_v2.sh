#!/usr/bin/env bash
set -Eeuo pipefail

# Pathfabric Lazy Installer v2
# Default: Pathfabric inbound + provider/VPS original outbound.
# Handles both installers with embedded WG keys and customer-held WG keys.

PF_INSTALLER="/root/pathfabric-install.sh"
PF_STATE="/etc/pathfabric/customer-installation.conf"
LOG="/root/pathfabric-lazy-install.log"
MODE="${PF_MODE:-default}"
NEW_KEY="/root/pathfabric-new.key"
NEW_PUB="/root/pathfabric-new.pub"

R='\033[0m'; G='\033[32m'; Y='\033[33m'; C='\033[36m'; RED='\033[31m'
info(){ printf "%b[INFO]%b %s\n" "$C" "$R" "$*"; }
ok(){ printf "%b[ OK ]%b %s\n" "$G" "$R" "$*"; }
warn(){ printf "%b[WARN]%b %s\n" "$Y" "$R" "$*"; }
die(){ printf "%b[FAIL]%b %s\n" "$RED" "$R" "$*" >&2; exit 1; }

[[ ${EUID:-$(id -u)} -eq 0 ]] || die "请使用 root 运行。"
[[ "$(uname -m)" == "x86_64" ]] || die "Pathfabric 官方 Linux installer 当前要求 x86_64；当前：$(uname -m)"
command -v systemctl >/dev/null 2>&1 || die "未检测到 systemd。"

printf '\n============================================================\n'
printf ' Pathfabric 懒人一键安装 v2\n'
printf ' 默认模式：PF 入站 + VPS/Provider 原线路出站\n'
printf '============================================================\n\n'

install_dep(){
  command -v "$1" >/dev/null 2>&1 && return 0
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$2"
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y "$2"
  elif command -v yum >/dev/null 2>&1; then
    yum install -y "$2"
  else
    die "缺少 $1，且无法自动安装依赖。"
  fi
}

valid_wg_key(){
  local f="$1" pub
  [[ -f "$f" && -s "$f" ]] || return 1
  chmod 600 "$f" 2>/dev/null || return 1
  pub="$(wg pubkey < "$f" 2>/dev/null || true)"
  [[ -n "$pub" ]]
}

run_install(){
  local key="${1:-}" rc
  : > "$LOG.tmp"
  set +e
  if [[ -n "$key" ]]; then
    "$PF_INSTALLER" --install --unattended --default-gateway="$MODE" \
      --wireguard-private-key-file="$key" 2>&1 | tee "$LOG.tmp"
  else
    "$PF_INSTALLER" --install --unattended --default-gateway="$MODE" 2>&1 | tee "$LOG.tmp"
  fi
  rc=${PIPESTATUS[0]}
  set -e
  cat "$LOG.tmp" >> "$LOG"
  rm -f "$LOG.tmp"
  return "$rc"
}

if [[ -f "$PF_STATE" ]]; then
  ok "检测到现有 Pathfabric 官方安装状态，不重复 --install。"
else
  install_dep curl curl
  install_dep wg wireguard-tools
  install_dep ip iproute2

  PF_URL="${PF_URL:-${1:-}}"
  if [[ -z "$PF_URL" ]]; then
    printf '粘贴 Pathfabric 后台刚生成的 installer URL：\n> '
    IFS= read -r PF_URL
  fi
  [[ "$PF_URL" =~ ^https?:// ]] || die "installer URL 格式不正确。"

  umask 077
  info "下载官方 service-specific installer..."
  curl -fL --retry 2 --connect-timeout 15 -o "$PF_INSTALLER" "$PF_URL"
  chmod 700 "$PF_INSTALLER"
  [[ -s "$PF_INSTALLER" ]] || die "下载文件为空；链接可能已使用或过期。"
  "$PF_INSTALLER" --help >/dev/null 2>&1 || die "下载内容不是有效 Pathfabric installer。"

  : > "$LOG"
  info "先尝试 installer 内置 WireGuard 私钥（如果有）。"
  if run_install ""; then
    ok "Pathfabric 安装成功。"
  else
    if ! grep -Fqi 'requires --wireguard-private-key-file' "$LOG"; then
      die "官方 installer 返回其他错误，请查看：$LOG"
    fi

    warn "该 installer 不含 WireGuard 私钥；开始自动寻找本机已有的匹配私钥。"

    declare -a candidates=()
    [[ -n "${PF_KEY:-}" ]] && candidates+=("$PF_KEY")
    for f in \
      /root/pathfabric.key \
      /root/private.key \
      /root/pathfabric-new.key \
      /etc/wireguard/pathfabric-private.key; do
      [[ -f "$f" ]] && candidates+=("$f")
    done
    while IFS= read -r f; do
      candidates+=("$f")
    done < <(find /root -maxdepth 2 -type f \( -name '*.key' -o -name '*wireguard*' -o -name '*wg*key*' \) 2>/dev/null | sort -u)

    # de-duplicate while preserving order
    declare -A seen=()
    matched=0
    for key in "${candidates[@]:-}"; do
      [[ -n "$key" ]] || continue
      [[ -z "${seen[$key]:-}" ]] || continue
      seen[$key]=1
      valid_wg_key "$key" || continue
      pub="$(wg pubkey < "$key")"
      info "尝试本机密钥：$key"
      info "其公钥：$pub"
      if run_install "$key"; then
        ok "找到匹配密钥并安装成功：$key"
        matched=1
        break
      fi
      if grep -Fqi 'does not match the public key configured for this Pathfabric service' "$LOG"; then
        warn "该密钥与当前 Pathfabric Service 不匹配，继续找下一个。"
      elif [[ -f "$PF_STATE" ]]; then
        matched=1
        break
      fi
    done

    if [[ "$matched" -ne 1 && ! -f "$PF_STATE" ]]; then
      warn "本机没有找到与当前 Service 匹配的 WireGuard 私钥。"
      if [[ ! -s "$NEW_KEY" ]] || ! valid_wg_key "$NEW_KEY"; then
        umask 077
        wg genkey > "$NEW_KEY"
        wg pubkey < "$NEW_KEY" > "$NEW_PUB"
        chmod 600 "$NEW_KEY"
        chmod 644 "$NEW_PUB"
      else
        wg pubkey < "$NEW_KEY" > "$NEW_PUB"
      fi
      newpub="$(cat "$NEW_PUB")"
      printf '\n============================================================\n'
      printf ' 只差 Pathfabric 后台这一步（无法由 VPS 代替）\n'
      printf '============================================================\n'
      printf '当前 installer 没带私钥，而且旧私钥全部不匹配。\n\n'
      printf '最省事方案 A【推荐】：\n'
      printf '  1. Pathfabric 后台 → 当前 Service → Configuration。\n'
      printf '  2. 重新生成/Rotate WireGuard key，让 Pathfabric 生成并持有密钥。\n'
      printf '  3. 不要先取走/下载 WireGuard generated configuration。\n'
      printf '  4. 直接 Generate Installer，复制新的 installer URL。\n'
      printf '  5. 再运行本脚本并粘贴新 URL；届时不需要 private.key。\n\n'
      printf '方案 B【使用 VPS 自己的固定密钥】：\n'
      printf '  把下面这个 PUBLIC KEY 填到当前 Service 的 WireGuard Public Key：\n\n'
      printf '  %s\n\n' "$newpub"
      printf '  私钥已经安全保存在：%s\n' "$NEW_KEY"
      printf '  后台保存后重新 Generate Installer，再运行本脚本。\n\n'
      die "当前这条 installer URL 无法完成安装；原因是服务器端绑定的公钥没有对应私钥。"
    fi
  fi
fi

printf '\n============================================================\n'
printf ' 安装后自检\n'
printf '============================================================\n'

[[ -f "$PF_STATE" ]] && ok "状态文件：$PF_STATE" || warn "未发现状态文件。"

printf '\n[Interfaces]\n'
ip -br addr 2>/dev/null | grep -E 'pf-wg|pf-gre|pf-ipip|pf-public|ens|eth' || true

printf '\n[Policy rules]\n'
ip rule 2>/dev/null | grep -E '29000|29010|29020|29030|29040' || true

printf '\n[Table 4242]\n'
ip route show table 4242 2>/dev/null || true

printf '\n[WireGuard]\n'
wg show pf-wg 2>/dev/null || wg show 2>/dev/null || true

printf '\n[MTU]\n'
for dev in pf-wg pf-gre pf-ipip; do
  [[ -e "/sys/class/net/$dev/mtu" ]] && printf '%s mtu=%s\n' "$dev" "$(cat "/sys/class/net/$dev/mtu")"
done

printf '\n[Public IPv4]\n'
provider_ip="$(curl -4fsS --max-time 10 https://api.ipify.org 2>/dev/null || true)"
printf '普通出站 IPv4: %s\n' "${provider_ip:-检测失败}"

pf_ip="$(ip -4 -o addr show dev pf-public 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1 || true)"
if [[ -n "$pf_ip" ]]; then
  printf 'Pathfabric IPv4: %s\n' "$pf_ip"
  bound_ip="$(curl -4fsS --max-time 12 --interface "$pf_ip" https://api.ipify.org 2>/dev/null || true)"
  printf '绑定 PF IP 出站: %s\n' "${bound_ip:-检测失败}"
else
  warn "未检测到 pf-public IPv4。"
fi

printf '\n[TCP 443]\n'
ss -lntp 2>/dev/null | grep -E '(:443[[:space:]])' || true

printf '\n============================================================\n'
ok "流程结束。默认：PF 入站 + VPS 原线路普通出站。"
printf 'installer: %s\n' "$PF_INSTALLER"
printf '日志:      %s\n' "$LOG"
printf '\n切到 PF 全局出站：\n  %s --switch-gateway --unattended --default-gateway=tunnel\n' "$PF_INSTALLER"
printf '\n切回 VPS 原出站：\n  %s --switch-gateway --unattended --default-gateway=default\n' "$PF_INSTALLER"
printf '\n卸载：\n  %s --uninstall --unattended\n\n' "$PF_INSTALLER"
