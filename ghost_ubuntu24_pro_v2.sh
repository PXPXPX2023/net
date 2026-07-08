#!/usr/bin/env bash
# ghost_ubuntu24_pro_v2.sh
# Ghost CMS one-key installer/maintenance script for Ubuntu 24.04 LTS minimal.
# Stack: Ubuntu 24 + Node.js 22 LTS + MySQL 8 + Nginx + systemd + Ghost-CLI + Let's Encrypt HTTPS.
# Designed for GitHub raw download execution.

set -Eeuo pipefail
IFS=$'\n\t'
shopt -s inherit_errexit 2>/dev/null || true

VERSION="v2.0.0"

STATE_DIR="/etc/ghost-onekey"
CONFIG_FILE="$STATE_DIR/config.env"
LEGACY_CONFIG_FILE="/etc/ghost-onekey.conf"
LOG_DIR="/var/log/ghost-onekey"
LOG_FILE="$LOG_DIR/run.log"
BACKUP_DIR_DEFAULT="/var/backups/ghost-onekey"
SUDOERS_TEMP="/etc/sudoers.d/90-ghost-onekey-temp"
LOCK_FILE="/run/ghost-onekey.lock"

ACTION="install"
DOMAIN=""
EMAIL=""
ADMIN_DOMAIN=""
INSTALL_DIR="/var/www/ghost"
ADMIN_USER="ghostmgr"
DB_NAME="ghost_prod"
DB_USER="ghost_user"
DB_PASS=""
PORT="2368"
BACKUP_DIR="$BACKUP_DIR_DEFAULT"
RESTORE_FILE=""
ENABLE_UFW="0"
SKIP_DNS_CHECK="0"
FORCE_OS="0"
YES="0"
NO_PRE_RESTORE_BACKUP="0"
NODE_MAJOR="22"
PUBLIC_IP=""

CLI_DOMAIN=""
CLI_EMAIL=""
CLI_ADMIN_DOMAIN=""
CLI_INSTALL_DIR=""
CLI_ADMIN_USER=""
CLI_DB_NAME=""
CLI_DB_USER=""
CLI_DB_PASS=""
CLI_PORT=""
CLI_BACKUP_DIR=""

TMP_WORKDIR=""

info() { echo -e "[INFO] $*"; }
warn() { echo -e "[WARN] $*" >&2; }
err()  { echo -e "[ERROR] $*" >&2; }
die()  { err "$*"; exit 1; }

quote() { printf '%q' "$1"; }

cleanup() {
  rm -f "$SUDOERS_TEMP" 2>/dev/null || true
  [[ -n "${TMP_WORKDIR:-}" && -d "$TMP_WORKDIR" ]] && rm -rf "$TMP_WORKDIR" || true
}

on_error() {
  local ec=$?
  local line=${BASH_LINENO[0]:-unknown}
  err "èæ¬æ§è¡å¤±è´¥ï¼éåºç ï¼$ecï¼ä½ç½®ï¼line $line"
  err "æ¥å¿ï¼$LOG_FILE"
  cleanup
  exit "$ec"
}
trap on_error ERR
trap cleanup EXIT

usage() {
  cat <<USAGE
Ghost Ubuntu 24 Pro One-Key Script $VERSION

ç¨æ³ï¼
  sudo bash ghost_ubuntu24_pro_v2.sh install --domain example.com --email admin@example.com
  sudo bash ghost_ubuntu24_pro_v2.sh --domain example.com --email admin@example.com

ç»´æ¤å½ä»¤ï¼
  sudo bash ghost_ubuntu24_pro_v2.sh status
  sudo bash ghost_ubuntu24_pro_v2.sh backup
  sudo bash ghost_ubuntu24_pro_v2.sh update
  sudo bash ghost_ubuntu24_pro_v2.sh rollback
  sudo bash ghost_ubuntu24_pro_v2.sh restart
  sudo bash ghost_ubuntu24_pro_v2.sh logs
  sudo bash ghost_ubuntu24_pro_v2.sh doctor
  sudo bash ghost_ubuntu24_pro_v2.sh renew-ssl --email admin@example.com
  sudo bash ghost_ubuntu24_pro_v2.sh restore --file /var/backups/ghost-onekey/ghost-full-xxxx.tar.gz --domain example.com --email admin@example.com
  sudo bash ghost_ubuntu24_pro_v2.sh uninstall --yes
  sudo bash ghost_ubuntu24_pro_v2.sh self-check

åæ°ï¼
  --domain DOMAIN              ä¸»ç«ååï¼ä¾å¦ example.comï¼ä¸è¦å¸¦ http:// æ https://
  --email EMAIL                Let's Encrypt è¯ä¹¦éç¥é®ç®±
  --admin-domain DOMAIN        å¯éï¼ç¬ç«åå°ååï¼ä¾å¦ admin.example.com
  --install-dir PATH           é»è®¤ /var/www/ghostï¼å¿é¡»æ¯ç©ºç®å½æä¸å­å¨
  --admin-user USER            é»è®¤ ghostmgrï¼ä¸è½æ¯ root æ ghost
  --db-name NAME               é»è®¤ ghost_prod
  --db-user USER               é»è®¤ ghost_user
  --db-pass PASS               å¯éï¼ä¸å¡«èªå¨çæï¼ä¸å»ºè®®æå¨å¡«å
  --port PORT                  Ghost æ¬å°çå¬ç«¯å£ï¼é»è®¤ 2368
  --backup-dir PATH            é»è®¤ /var/backups/ghost-onekey
  --file PATH                  restore ä½¿ç¨çå¤ä»½å
  --enable-ufw                 å¯ç¨ UFW å¹¶æ¾è¡ OpenSSH + Nginx Full
  --skip-dns-check             è·³è¿åå A è®°å½æ ¡éªï¼ä»å¨ä½ æç¡®ç¥é DNS æ²¡é®é¢æ¶ä½¿ç¨
  --force-os                   é Ubuntu 24.04 æ¶å¼ºå¶ç»§ç»­ï¼ä¸æ¨è
  --no-pre-restore-backup      restore åä¸èªå¨å¤ä»½ç°æç«ç¹
  --yes, -y                    å¸è½½ç­å±é©æä½ç¡®è®¤
  -h, --help                   æ¾ç¤ºå¸®å©

GitHub ä¸è½½æ§è¡ç¤ºä¾ï¼
  curl -fsSL https://raw.githubusercontent.com/ä½ çç¨æ·å/ä½ çä»åº/main/ghost_ubuntu24_pro_v2.sh -o ghost_ubuntu24_pro_v2.sh
  chmod +x ghost_ubuntu24_pro_v2.sh
  sudo ./ghost_ubuntu24_pro_v2.sh --domain example.com --email admin@example.com

éè¦ï¼
  1) åå A è®°å½å¿é¡»åæåæ¬ VPS å¬ç½ IPv4ï¼Ghost-CLI SSL æè½æåç­¾åã
  2) Cloudflare é¦æ¬¡å®è£å»ºè®®å³é­æ©äºä»£çï¼è¯ä¹¦æåååæå¼ï¼SSL/TLS è®¾ä¸º Full (strict)ã
  3) å¤ä»½ååå«æ°æ®åºãcontentãéç½®æä»¶ï¼å¯è½åå«ææä¿¡æ¯ï¼ä¸è¦ä¸ä¼ å°å¬å¼ä»åºã
USAGE
}

parse_args() {
  if [[ $# -gt 0 ]]; then
    case "$1" in
      install|status|backup|update|rollback|restart|logs|doctor|renew-ssl|restore|uninstall|self-check)
        ACTION="$1"; shift ;;
    esac
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --domain) DOMAIN="${2:-}"; CLI_DOMAIN="$DOMAIN"; shift 2 ;;
      --email) EMAIL="${2:-}"; CLI_EMAIL="$EMAIL"; shift 2 ;;
      --admin-domain) ADMIN_DOMAIN="${2:-}"; CLI_ADMIN_DOMAIN="$ADMIN_DOMAIN"; shift 2 ;;
      --install-dir) INSTALL_DIR="${2:-}"; CLI_INSTALL_DIR="$INSTALL_DIR"; shift 2 ;;
      --admin-user) ADMIN_USER="${2:-}"; CLI_ADMIN_USER="$ADMIN_USER"; shift 2 ;;
      --db-name) DB_NAME="${2:-}"; CLI_DB_NAME="$DB_NAME"; shift 2 ;;
      --db-user) DB_USER="${2:-}"; CLI_DB_USER="$DB_USER"; shift 2 ;;
      --db-pass) DB_PASS="${2:-}"; CLI_DB_PASS="$DB_PASS"; shift 2 ;;
      --port) PORT="${2:-}"; CLI_PORT="$PORT"; shift 2 ;;
      --backup-dir) BACKUP_DIR="${2:-}"; CLI_BACKUP_DIR="$BACKUP_DIR"; shift 2 ;;
      --file) RESTORE_FILE="${2:-}"; shift 2 ;;
      --enable-ufw) ENABLE_UFW="1"; shift ;;
      --skip-dns-check) SKIP_DNS_CHECK="1"; shift ;;
      --force-os) FORCE_OS="1"; shift ;;
      --no-pre-restore-backup) NO_PRE_RESTORE_BACKUP="1"; shift ;;
      --yes|-y) YES="1"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "æªç¥åæ°ï¼$1ãè¿è¡ --help æ¥çç¨æ³ã" ;;
    esac
  done
}

init_logging() {
  mkdir -p "$LOG_DIR"
  touch "$LOG_FILE"
  chmod 700 "$LOG_DIR"
  chmod 600 "$LOG_FILE"
  exec > >(tee -a "$LOG_FILE") 2>&1
}

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "è¯·ç¨ root æ§è¡ï¼sudo ./ghost_ubuntu24_pro_v2.sh ..."
}

acquire_lock() {
  exec 9>"$LOCK_FILE"
  flock -n 9 || die "å·²æ ghost-onekey ä»»å¡å¨è¿è¡ï¼$LOCK_FILE"
}

apply_cli_overrides() {
  [[ -n "$CLI_DOMAIN" ]] && DOMAIN="$CLI_DOMAIN"
  [[ -n "$CLI_EMAIL" ]] && EMAIL="$CLI_EMAIL"
  [[ -n "$CLI_ADMIN_DOMAIN" ]] && ADMIN_DOMAIN="$CLI_ADMIN_DOMAIN"
  [[ -n "$CLI_INSTALL_DIR" ]] && INSTALL_DIR="$CLI_INSTALL_DIR"
  [[ -n "$CLI_ADMIN_USER" ]] && ADMIN_USER="$CLI_ADMIN_USER"
  [[ -n "$CLI_DB_NAME" ]] && DB_NAME="$CLI_DB_NAME"
  [[ -n "$CLI_DB_USER" ]] && DB_USER="$CLI_DB_USER"
  [[ -n "$CLI_DB_PASS" ]] && DB_PASS="$CLI_DB_PASS"
  [[ -n "$CLI_PORT" ]] && PORT="$CLI_PORT"
  [[ -n "$CLI_BACKUP_DIR" ]] && BACKUP_DIR="$CLI_BACKUP_DIR"
}

load_config_if_exists() {
  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
  elif [[ -f "$LEGACY_CONFIG_FILE" ]]; then
    warn "æ£æµå° v1 éç½®æä»¶ï¼$LEGACY_CONFIG_FILEï¼å°å¼å®¹è¯»åå¹¶å¨åç»­ä¿å­ä¸º v2 éç½®ã"
    # shellcheck source=/dev/null
    source "$LEGACY_CONFIG_FILE"
  fi
  VERSION="v2.0.0"
  apply_cli_overrides
}

save_config() {
  mkdir -p "$STATE_DIR"
  chmod 700 "$STATE_DIR"
  umask 077
  {
    printf 'VERSION=%q\n' "$VERSION"
    printf 'DOMAIN=%q\n' "$DOMAIN"
    printf 'EMAIL=%q\n' "$EMAIL"
    printf 'ADMIN_DOMAIN=%q\n' "$ADMIN_DOMAIN"
    printf 'INSTALL_DIR=%q\n' "$INSTALL_DIR"
    printf 'ADMIN_USER=%q\n' "$ADMIN_USER"
    printf 'DB_NAME=%q\n' "$DB_NAME"
    printf 'DB_USER=%q\n' "$DB_USER"
    printf 'DB_PASS=%q\n' "$DB_PASS"
    printf 'PORT=%q\n' "$PORT"
    printf 'BACKUP_DIR=%q\n' "$BACKUP_DIR"
    printf 'NODE_MAJOR=%q\n' "$NODE_MAJOR"
  } > "$CONFIG_FILE"
  chmod 600 "$CONFIG_FILE"
}

validate_domain() {
  local d="$1"
  [[ -n "$d" ]] || die "ç¼ºå° --domain"
  [[ ! "$d" =~ ^https?:// ]] || die "--domain ä¸è¦å¸¦ http:// æ https://ï¼åªå¡« example.com"
  [[ "$d" != */* ]] || die "--domain ä¸è¦å¸¦è·¯å¾ï¼åªå¡« example.com"
  [[ "$d" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$ ]] || die "ååæ ¼å¼ä¸æ­£ç¡®ï¼$d"
}

validate_email() {
  local e="$1"
  [[ -n "$e" ]] || die "ç¼ºå° --email"
  [[ "$e" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] || die "é®ç®±æ ¼å¼ä¸æ­£ç¡®ï¼$e"
}

validate_port() {
  [[ "$PORT" =~ ^[0-9]+$ ]] || die "ç«¯å£å¿é¡»æ¯æ°å­"
  (( PORT >= 1024 && PORT <= 65535 )) || die "ç«¯å£èå´åºä¸º 1024-65535"
}

validate_paths_and_names() {
  [[ "$ADMIN_USER" != "root" && "$ADMIN_USER" != "ghost" ]] || die "--admin-user ä¸è½æ¯ root æ ghost"
  [[ "$ADMIN_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "--admin-user åªåè®¸ Linux ç¨æ·åæ ¼å¼ï¼å°åå­æ¯/æ°å­/_/-"
  [[ "$DB_NAME" =~ ^[A-Za-z0-9_]{1,64}$ ]] || die "--db-name åªåè®¸å­æ¯ãæ°å­ãä¸åçº¿ï¼æé¿ 64"
  [[ "$DB_USER" =~ ^[A-Za-z0-9_]{1,32}$ ]] || die "--db-user åªåè®¸å­æ¯ãæ°å­ãä¸åçº¿ï¼æé¿ 32"
  [[ "$INSTALL_DIR" = /* ]] || die "--install-dir å¿é¡»æ¯ç»å¯¹è·¯å¾"
  [[ "$BACKUP_DIR" = /* ]] || die "--backup-dir å¿é¡»æ¯ç»å¯¹è·¯å¾"
  [[ "$INSTALL_DIR" =~ ^/[A-Za-z0-9._/@:+-]+$ ]] || die "--install-dir ä¸åè®¸ç©ºæ ¼ãå¼å·ç­å¤æå­ç¬¦"
  [[ "$BACKUP_DIR" =~ ^/[A-Za-z0-9._/@:+-]+$ ]] || die "--backup-dir ä¸åè®¸ç©ºæ ¼ãå¼å·ç­å¤æå­ç¬¦"
  [[ "$DB_PASS" != *"'"* && "$DB_PASS" != *"\\"* && "$DB_PASS" != *$'\n'* ]] || die "--db-pass ä¸åè®¸åå«åå¼å·ãåææ ææ¢è¡"
}

require_domain_email_for_install_like() {
  [[ -n "$DOMAIN" ]] || die "$ACTION éè¦ --domain example.com"
  [[ -n "$EMAIL" ]] || die "$ACTION éè¦ --email admin@example.com"
  validate_domain "$DOMAIN"
  validate_email "$EMAIL"
  if [[ -n "$ADMIN_DOMAIN" ]]; then
    validate_domain "$ADMIN_DOMAIN"
  fi
  validate_port
  validate_paths_and_names
}

check_os() {
  [[ -f /etc/os-release ]] || die "æ æ³è¯å«ç³»ç»ï¼ç¼ºå° /etc/os-release"
  # shellcheck source=/dev/null
  source /etc/os-release
  if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
    if [[ "$FORCE_OS" == "1" ]]; then
      warn "å½åç³»ç»æ¯ ${PRETTY_NAME:-unknown}ï¼å·²ä½¿ç¨ --force-os å¼ºå¶ç»§ç»­ã"
    else
      die "æ¬èæ¬é»è®¤åªæ¯æ Ubuntu 24.04 LTSãå½åï¼${PRETTY_NAME:-unknown}ãå¦ç¡®è®¤å¼å®¹ï¼å¯å  --force-osã"
    fi
  fi
}

rand_pass() {
  local p
  p="$(dd if=/dev/urandom bs=64 count=1 2>/dev/null | base64 | tr -dc 'A-Za-z0-9_@%+=:.,-~')"
  p="${p:0:36}"
  if [[ ${#p} -lt 24 ]]; then
    p="ghost$(date +%s%N)$(od -An -N8 -tx1 /dev/urandom 2>/dev/null | tr -d ' \n')"
  fi
  printf '%s' "$p"
}

get_public_ip() {
  PUBLIC_IP="$(curl -4fsS --max-time 8 https://api.ipify.org 2>/dev/null || true)"
  if [[ -z "$PUBLIC_IP" ]]; then
    PUBLIC_IP="$(curl -4fsS --max-time 8 https://ifconfig.me 2>/dev/null || true)"
  fi
  [[ -n "$PUBLIC_IP" ]] || warn "æ æ³è·åæ¬æºå¬ç½ IPv4ï¼å°åªæ£æ¥ååæ¯å¦æ A è®°å½ã"
}

resolve_a_records() {
  local d="$1"
  getent ahostsv4 "$d" | awk '{print $1}' | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//' || true
}

check_dns_one() {
  local d="$1"
  local resolved=""
  resolved="$(resolve_a_records "$d")"
  [[ -n "$resolved" ]] || die "åå $d å°æªè§£æå° IPv4ãè¯·åæ·»å  A è®°å½å°æ¬ VPS å¬ç½ IPã"
  info "åå A è®°å½ï¼$d -> $resolved"
  if [[ -n "$PUBLIC_IP" ]]; then
    info "æ¬æºå¬ç½ IPv4ï¼$PUBLIC_IP"
    if ! echo " $resolved " | grep -q " $PUBLIC_IP "; then
      die "DNS A è®°å½æªæåæ¬æºå¬ç½ IPv4ãè¥ä½¿ç¨ Cloudflare æ©äºï¼è¯·åå³æ©äºï¼ç¡®è®¤æ è¯¯æ¶å¯å  --skip-dns-checkã"
    fi
  fi
}

check_dns() {
  [[ "$SKIP_DNS_CHECK" == "1" ]] && { warn "å·²è·³è¿ DNS æ£æ¥ãSSL å¦å¤±è´¥ï¼è¯·åæ£æ¥ååè§£æå 80/443 å¥ç«ã"; return 0; }
  get_public_ip
  check_dns_one "$DOMAIN"
  [[ -n "$ADMIN_DOMAIN" ]] && check_dns_one "$ADMIN_DOMAIN"
}

apt_wait() {
  local locks=(/var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock)
  local i
  for i in {1..60}; do
    if ! fuser "${locks[@]}" >/dev/null 2>&1; then
      return 0
    fi
    warn "apt/dpkg è¢«å ç¨ï¼ç­å¾ä¸­... ($i/60)"
    sleep 3
  done
  die "ç­å¾ apt/dpkg éè¶æ¶ã"
}

apt_update_once() {
  export DEBIAN_FRONTEND=noninteractive
  apt_wait
  apt-get update -y
}

install_base_packages() {
  info "å®è£åºç¡ç»ä»¶ï¼curlãgnupgãnginxãmysql-serverãrsyncãufw ç­"
  apt_update_once
  apt_wait
  apt-get install -y ca-certificates curl gnupg lsb-release unzip tar gzip rsync jq openssl ufw nginx mysql-server sudo python3 psmisc
  systemctl enable --now mysql
  systemctl enable --now nginx
}

ensure_swap() {
  local mem_kb swap_kb total_mb
  mem_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
  swap_kb="$(awk '/SwapTotal/ {print $2}' /proc/meminfo)"
  total_mb=$(( (mem_kb + swap_kb) / 1024 ))
  if (( total_mb < 1200 )); then
    if [[ ! -f /swapfile ]]; then
      warn "åå­+Swap ä½äº 1.2GBï¼åå»º 1GB /swapfileï¼éä½ Ghost-CLI åå­æ£æ¥å¤±è´¥æ¦çã"
      fallocate -l 1G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=1024
      chmod 600 /swapfile
      mkswap /swapfile
      swapon /swapfile
      grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    else
      swapon /swapfile || true
    fi
  fi
}

install_nodejs() {
  info "å®è£ Node.js ${NODE_MAJOR} LTS"
  mkdir -p /etc/apt/keyrings
  rm -f /etc/apt/keyrings/nodesource.gpg /etc/apt/sources.list.d/nodesource.list
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
  chmod 644 /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
  apt_update_once
  apt_wait
  apt-get install -y nodejs
  node -v
  npm -v
}

install_ghost_cli() {
  info "å®è£/æ´æ° Ghost-CLI"
  npm install ghost-cli@latest -g
  ghost --version || true
}

setup_firewall() {
  if [[ "$ENABLE_UFW" == "1" ]]; then
    warn "å°å¯ç¨ UFWãè¥ä½ ç SSH ä¸æ¯ 22 ç«¯å£ï¼è¯·åèªè¡æ¾è¡å¯¹åºç«¯å£ã"
    ufw allow OpenSSH || true
    ufw allow 'Nginx Full' || true
    ufw --force enable
    ufw status verbose || true
  else
    if ufw status | grep -qi 'Status: active'; then
      info "UFW å·²å¯ç¨ï¼æ¾è¡ Nginx Fullã"
      ufw allow 'Nginx Full' || true
    else
      warn "UFW æªå¯ç¨ãèæ¬ä¸ä¼èªå¨å¯ç¨é²ç«å¢ï¼é¿åéæ å SSH ç«¯å£è¢«éãå¯æå¨å  --enable-ufwã"
    fi
  fi
}

remove_nginx_default() {
  if [[ -e /etc/nginx/sites-enabled/default ]]; then
    info "ç§»é¤ Nginx é»è®¤ç«ç¹ï¼é¿åå¹²æ° Ghost vhostã"
    rm -f /etc/nginx/sites-enabled/default
  fi
  nginx -t
  systemctl reload nginx || true
}

create_admin_user() {
  if ! id "$ADMIN_USER" >/dev/null 2>&1; then
    info "åå»º Ghost ç®¡çç¨æ·ï¼$ADMIN_USER"
    adduser --disabled-password --gecos "Ghost Manager" "$ADMIN_USER"
  fi
  usermod -aG sudo "$ADMIN_USER" || true
}

enable_temp_sudoers() {
  cat > "$SUDOERS_TEMP" <<SUDOERS
$ADMIN_USER ALL=(ALL) NOPASSWD: ALL
SUDOERS
  chmod 440 "$SUDOERS_TEMP"
  visudo -cf "$SUDOERS_TEMP" >/dev/null
}

disable_temp_sudoers() {
  rm -f "$SUDOERS_TEMP" 2>/dev/null || true
}

as_admin() {
  local cmd="$1"
  sudo -u "$ADMIN_USER" -H bash -lc "$cmd"
}

ghost_in_dir() {
  local cmd="$1"
  enable_temp_sudoers
  as_admin "cd $(quote "$INSTALL_DIR") && $cmd"
  disable_temp_sudoers
}

prepare_install_dir() {
  if [[ -d "$INSTALL_DIR" ]]; then
    if [[ -n "$(find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]]; then
      die "$INSTALL_DIR ä¸æ¯ç©ºç®å½ãGhost å®æ¹å®è£è¦æ±ç®æ ç®å½ä¸ºç©ºãè¯·æ¢ --install-dir ææ¸çç®å½ã"
    fi
  else
    mkdir -p "$INSTALL_DIR"
  fi
  chown "$ADMIN_USER:$ADMIN_USER" "$INSTALL_DIR"
  chmod 775 "$INSTALL_DIR"
}

mysql_exec() {
  mysql --protocol=socket -uroot "$@"
}

setup_database() {
  [[ -n "$DB_PASS" ]] || DB_PASS="$(rand_pass)"
  info "åå»º/æ´æ° MySQL æ°æ®åºåç¨æ·ï¼$DB_NAME / $DB_USER"
  mysql_exec <<SQL
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL
}

build_ghost_install_cmd() {
  local url admin_opt
  url="https://$DOMAIN"
  admin_opt=""
  if [[ -n "$ADMIN_DOMAIN" ]]; then
    admin_opt=" --admin-url $(quote "https://$ADMIN_DOMAIN")"
  fi
  cat <<CMD
cd $(quote "$INSTALL_DIR") && ghost install \
  --url $(quote "$url") \
  $admin_opt \
  --ip 127.0.0.1 \
  --port $(quote "$PORT") \
  --db mysql \
  --dbhost localhost \
  --dbuser $(quote "$DB_USER") \
  --dbpass $(quote "$DB_PASS") \
  --dbname $(quote "$DB_NAME") \
  --process systemd \
  --sslemail $(quote "$EMAIL") \
  --no-prompt \
  --start
CMD
}

install_ghost_site() {
  if [[ -f "$INSTALL_DIR/.ghost-cli" || -d "$INSTALL_DIR/current" ]]; then
    die "$INSTALL_DIR çèµ·æ¥å·²ç»å®è£è¿ Ghostãè¯·å backup/statusï¼ææ¢ --install-dirã"
  fi
  info "å¼å§å®è£ Ghost å° $INSTALL_DIR"
  enable_temp_sudoers
  as_admin "$(build_ghost_install_cmd)"
  disable_temp_sudoers
  save_config
  info "Ghost å®è£å®æãåå°å¥å£ï¼https://$DOMAIN/ghost"
}

install_prerequisites_only() {
  check_os
  install_base_packages
  ensure_swap
  install_nodejs
  install_ghost_cli
  setup_firewall
  remove_nginx_default
  create_admin_user
}

ensure_backup_dir() {
  mkdir -p "$BACKUP_DIR"
  chmod 700 "$BACKUP_DIR"
}

require_config_for_maintenance() {
  load_config_if_exists
  [[ -f "$CONFIG_FILE" || -f "$LEGACY_CONFIG_FILE" ]] || die "æªæ¾å°éç½®æä»¶ãè¯·å installï¼æå¨å½ä»¤ä¸­è¡¥åå®æ´åæ°ã"
  validate_port
  validate_paths_and_names
  [[ -n "$INSTALL_DIR" && -d "$INSTALL_DIR" ]] || die "å®è£ç®å½ä¸å­å¨ï¼$INSTALL_DIR"
}

backup_ghost_cli_zip() {
  local out_dir="$1"
  mkdir -p "$out_dir"
  local before_file latest_zip
  before_file="$out_dir/.before.txt"
  find "$INSTALL_DIR" -maxdepth 1 -type f -name '*.zip' -printf '%f\n' 2>/dev/null | sort > "$before_file" || true
  enable_temp_sudoers
  as_admin "cd $(quote "$INSTALL_DIR") && ghost backup --no-prompt --no-color" || warn "ghost backup å¤±è´¥ï¼ç»§ç»­ä¿ç raw MySQL+content å¨éå¤ä»½ã"
  disable_temp_sudoers
  latest_zip="$(find "$INSTALL_DIR" -maxdepth 1 -type f -name '*.zip' -mmin -15 -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1{print $2}' || true)"
  if [[ -n "$latest_zip" && -f "$latest_zip" ]]; then
    cp -a "$latest_zip" "$out_dir/"
    rm -f "$latest_zip" || true
  fi
  rm -f "$before_file"
}

create_backup() {
  require_config_for_maintenance
  ensure_backup_dir
  TMP_WORKDIR="$(mktemp -d)"
  chmod 700 "$TMP_WORKDIR"
  local ts archive base
  ts="$(date +%Y%m%d_%H%M%S)"
  base="ghost-full-${DOMAIN:-site}-${ts}"
  archive="$BACKUP_DIR/${base}.tar.gz"

  info "åå»º Ghost å¨éå¤ä»½ï¼$archive"
  cat > "$TMP_WORKDIR/metadata.env" <<META
BACKUP_VERSION="$VERSION"
CREATED_AT="$ts"
DOMAIN="$DOMAIN"
EMAIL="$EMAIL"
ADMIN_DOMAIN="$ADMIN_DOMAIN"
INSTALL_DIR="$INSTALL_DIR"
ADMIN_USER="$ADMIN_USER"
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
PORT="$PORT"
NODE_MAJOR="$NODE_MAJOR"
META

  info "å¯¼åº MySQL æ°æ®åºï¼$DB_NAME"
  mysqldump --protocol=socket -uroot --single-transaction --routines --triggers --events --default-character-set=utf8mb4 "$DB_NAME" > "$TMP_WORKDIR/mysql.sql"

  info "å¤å¶ Ghost content ç®å½"
  mkdir -p "$TMP_WORKDIR/content"
  rsync -a --numeric-ids "$INSTALL_DIR/content/" "$TMP_WORKDIR/content/"

  [[ -f "$INSTALL_DIR/config.production.json" ]] && cp -a "$INSTALL_DIR/config.production.json" "$TMP_WORKDIR/config.production.json"
  [[ -f "$CONFIG_FILE" ]] && cp -a "$CONFIG_FILE" "$TMP_WORKDIR/ghost-onekey-v2-config.env"
  [[ -f "$LEGACY_CONFIG_FILE" ]] && cp -a "$LEGACY_CONFIG_FILE" "$TMP_WORKDIR/ghost-onekey-v1-config.env"

  info "å°è¯çæ Ghost-CLI é»è¾å¤ä»½ zip"
  backup_ghost_cli_zip "$TMP_WORKDIR/ghost-cli-backup"

  tar -C "$TMP_WORKDIR" -czf "$archive" .
  chmod 600 "$archive"
  info "å¤ä»½å®æï¼$archive"
  TMP_WORKDIR=""
}

read_restore_metadata() {
  local meta="$1"
  [[ -f "$meta" ]] || return 0
  local meta_domain meta_email meta_admin_domain
  meta_domain="$(grep '^DOMAIN=' "$meta" | cut -d= -f2- | tr -d '"' || true)"
  meta_email="$(grep '^EMAIL=' "$meta" | cut -d= -f2- | tr -d '"' || true)"
  meta_admin_domain="$(grep '^ADMIN_DOMAIN=' "$meta" | cut -d= -f2- | tr -d '"' || true)"
  [[ -z "$DOMAIN" && -n "$meta_domain" ]] && DOMAIN="$meta_domain"
  [[ -z "$EMAIL" && -n "$meta_email" ]] && EMAIL="$meta_email"
  [[ -z "$ADMIN_DOMAIN" && -n "$meta_admin_domain" ]] && ADMIN_DOMAIN="$meta_admin_domain"
}

fresh_install_for_restore_if_needed() {
  load_config_if_exists
  if [[ -f "$CONFIG_FILE" && -d "$INSTALL_DIR/current" ]]; then
    info "æ£æµå°ç°æ Ghost å®è£ï¼å°å¨å¶ä¸æ¢å¤æ°æ®ã"
    return 0
  fi

  info "æªæ£æµå°ç°æ Ghost å®è£ï¼åå®è£ä¸ä¸ªç©º Ghost å®ä¾ç¨äºæ¿è½½æ¢å¤æ°æ®ã"
  install_prerequisites_only
  prepare_install_dir
  setup_database
  install_ghost_site
}

restore_backup() {
  [[ -n "$RESTORE_FILE" ]] || die "restore éè¦ --file /path/to/backup.tar.gz"
  [[ -f "$RESTORE_FILE" ]] || die "å¤ä»½æä»¶ä¸å­å¨ï¼$RESTORE_FILE"

  TMP_WORKDIR="$(mktemp -d)"
  chmod 700 "$TMP_WORKDIR"
  tar -xzf "$RESTORE_FILE" -C "$TMP_WORKDIR"
  [[ -f "$TMP_WORKDIR/mysql.sql" ]] || die "å¤ä»½åç¼ºå° mysql.sql"
  [[ -d "$TMP_WORKDIR/content" ]] || die "å¤ä»½åç¼ºå° content ç®å½"

  read_restore_metadata "$TMP_WORKDIR/metadata.env"
  require_domain_email_for_install_like
  check_dns

  if [[ ( -f "$CONFIG_FILE" || -f "$LEGACY_CONFIG_FILE" ) && "$NO_PRE_RESTORE_BACKUP" != "1" ]]; then
    warn "æ¢å¤ååèªå¨å¤ä»½å½åç«ç¹ã"
    create_backup
    TMP_WORKDIR="$(mktemp -d)"
    chmod 700 "$TMP_WORKDIR"
    tar -xzf "$RESTORE_FILE" -C "$TMP_WORKDIR"
  fi

  fresh_install_for_restore_if_needed
  load_config_if_exists
  require_domain_email_for_install_like

  info "åæ­¢ Ghost"
  ghost_in_dir "ghost stop || true"

  info "æ¸ç©ºå¹¶å¯¼å¥æ°æ®åºï¼$DB_NAME"
  mysql_exec <<SQL
DROP DATABASE IF EXISTS \`$DB_NAME\`;
CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL
  mysql --protocol=socket -uroot --default-character-set=utf8mb4 "$DB_NAME" < "$TMP_WORKDIR/mysql.sql"

  info "æ¢å¤ content ç®å½"
  mkdir -p "$INSTALL_DIR/content"
  rsync -a --delete "$TMP_WORKDIR/content/" "$INSTALL_DIR/content/"
  if id ghost >/dev/null 2>&1; then
    chown -R ghost:ghost "$INSTALL_DIR/content"
  else
    chown -R "$ADMIN_USER:$ADMIN_USER" "$INSTALL_DIR/content"
  fi
  find "$INSTALL_DIR/content" -type d -exec chmod 775 {} \; || true
  find "$INSTALL_DIR/content" -type f -exec chmod 664 {} \; || true

  info "åæ­¥ç«ç¹ URLãNginx ä¸ SSL"
  ghost_in_dir "ghost config url $(quote "https://$DOMAIN")"
  if [[ -n "$ADMIN_DOMAIN" ]]; then
    ghost_in_dir "ghost config admin.url $(quote "https://$ADMIN_DOMAIN")"
  fi
  ghost_in_dir "ghost setup nginx ssl --sslemail $(quote "$EMAIL") --no-prompt"
  ghost_in_dir "ghost setup migrate --no-prompt || true"
  ghost_in_dir "ghost restart || ghost start"
  save_config
  info "æ¢å¤å®æï¼ https://$DOMAIN/ghost"
  TMP_WORKDIR=""
}

show_status() {
  require_config_for_maintenance
  info "Ghost OneKey éç½®ï¼"
  echo "  VERSION=$VERSION"
  echo "  DOMAIN=$DOMAIN"
  [[ -n "$ADMIN_DOMAIN" ]] && echo "  ADMIN_DOMAIN=$ADMIN_DOMAIN"
  echo "  INSTALL_DIR=$INSTALL_DIR"
  echo "  ADMIN_USER=$ADMIN_USER"
  echo "  DB_NAME=$DB_NAME"
  echo "  DB_USER=$DB_USER"
  echo "  DB_PASS=********"
  echo "  PORT=$PORT"
  echo "  BACKUP_DIR=$BACKUP_DIR"
  echo "  CONFIG_FILE=$CONFIG_FILE"
  echo ""
  enable_temp_sudoers
  as_admin "ghost ls || true"
  disable_temp_sudoers
  echo ""
  systemctl --no-pager --type=service | grep -E 'ghost|nginx|mysql' || true
  echo ""
  nginx -t || true
}

update_ghost() {
  require_config_for_maintenance
  create_backup
  info "æ´æ° Ghost-CLI"
  npm install ghost-cli@latest -g
  info "æ´æ° Ghostãè¥å¤±è´¥ï¼å¯è¿è¡ rollbackã"
  ghost_in_dir "ghost update --no-prompt"
}

rollback_ghost() {
  require_config_for_maintenance
  info "æ§è¡ Ghost åæ»"
  ghost_in_dir "ghost update --rollback --no-prompt"
}

restart_ghost() {
  require_config_for_maintenance
  ghost_in_dir "ghost restart"
}

show_logs() {
  require_config_for_maintenance
  ghost_in_dir "ghost log -n 120 || true"
  echo ""
  journalctl -u "ghost*" -n 160 --no-pager || true
}

run_doctor() {
  require_config_for_maintenance
  ghost_in_dir "ghost doctor"
}

renew_ssl() {
  load_config_if_exists
  [[ -n "$EMAIL" ]] || die "renew-ssl éè¦ --email æéç½®æä»¶ä¸­å·²æ EMAIL"
  [[ -n "$DOMAIN" ]] || die "renew-ssl éè¦éç½®æä»¶ä¸­å·²æ DOMAINï¼æä¼  --domain"
  validate_email "$EMAIL"
  validate_domain "$DOMAIN"
  check_dns
  ghost_in_dir "ghost setup nginx ssl --sslemail $(quote "$EMAIL") --no-prompt"
  save_config
}

uninstall_ghost() {
  require_config_for_maintenance
  [[ "$YES" == "1" ]] || die "å¸è½½ä¼å é¤ Ghost ç¨åºä¸æ°æ®åºãè¯·ç¡®è®¤åå  --yesã"
  create_backup
  warn "å¼å§å¸è½½ Ghostãå¤ä»½å·²ä¿å­å¨ $BACKUP_DIRã"
  ghost_in_dir "ghost stop || true"
  ghost_in_dir "ghost uninstall --no-prompt || ghost uninstall --force || true"
  mysql_exec <<SQL || true
DROP DATABASE IF EXISTS \`$DB_NAME\`;
DROP USER IF EXISTS '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL
  rm -f "$CONFIG_FILE"
  info "å¸è½½å®æãå®è£ç®å½å¦ææ®çè¯·äººå·¥æ£æ¥ï¼$INSTALL_DIR"
}

self_check() {
  info "æ§è¡èæ¬èªæ£"
  bash -n "$0" || die "bash -n æªéè¿"
  echo "èæ¬è¯­æ³ï¼OK"
  if [[ -f "$CONFIG_FILE" || -f "$LEGACY_CONFIG_FILE" ]]; then
    load_config_if_exists
    echo "éç½®æä»¶ï¼FOUND"
    echo "å®è£ç®å½ï¼$INSTALL_DIR"
    [[ -d "$INSTALL_DIR" ]] && echo "å®è£ç®å½å­å¨ï¼OK" || echo "å®è£ç®å½å­å¨ï¼NO"
  else
    echo "éç½®æä»¶ï¼æªåç°ï¼æªå®è£æ¶æ­£å¸¸"
  fi
  command -v nginx >/dev/null 2>&1 && nginx -t || true
  command -v mysql >/dev/null 2>&1 && mysql --protocol=socket -uroot -e 'SELECT VERSION();' || true
  command -v node >/dev/null 2>&1 && node -v || true
  command -v npm >/dev/null 2>&1 && npm -v || true
  command -v ghost >/dev/null 2>&1 && ghost --version || true
}

install_all() {
  load_config_if_exists
  require_domain_email_for_install_like
  check_os
  check_dns
  [[ -n "$DB_PASS" ]] || DB_PASS="$(rand_pass)"

  if [[ -f "$CONFIG_FILE" || -f "$LEGACY_CONFIG_FILE" ]]; then
    die "æ£æµå°å·²æ ghost-onekey éç½®æä»¶ãè¥è¦ç»´æ¤è¯·ç¨ status/backup/updateï¼è¥è¦éè£è¯·å uninstall --yes ææå¨æ¸çã"
  fi

  install_prerequisites_only
  prepare_install_dir
  setup_database
  install_ghost_site

  cat <<DONE

======================================================================
Ghost å®è£ç»æ
======================================================================
ç«ç¹å°åï¼        https://$DOMAIN
åå°å°åï¼        https://$DOMAIN/ghost
å®è£ç®å½ï¼        $INSTALL_DIR
ç®¡çç¨æ·ï¼        $ADMIN_USER
æ°æ®åºï¼          $DB_NAME
å¤ä»½ç®å½ï¼        $BACKUP_DIR
éç½®æä»¶ï¼        $CONFIG_FILE
æ¥å¿æä»¶ï¼        $LOG_FILE

å¸¸ç¨ç»´æ¤ï¼
  sudo bash $0 status
  sudo bash $0 backup
  sudo bash $0 update
  sudo bash $0 rollback
  sudo bash $0 restore --file <å¤ä»½å> --domain $DOMAIN --email $EMAIL

éè¦æéï¼
  1) ç°å¨è®¿é® https://$DOMAIN/ghost åå»º Ghost ç«é¿è´¦æ·ã
  2) å¤ä»½ååå«ææä¿¡æ¯ï¼ä¸è¦ä¸ä¼ å°å¬å¼ GitHubã
  3) å¦æä½¿ç¨ Cloudflareï¼è¯ä¹¦ç­¾åååå¼å¯æ©äºï¼SSL/TLS è®¾ä¸º Full (strict)ã
======================================================================
DONE
}

main() {
  parse_args "$@"
  require_root
  init_logging
  acquire_lock

  case "$ACTION" in
    install) install_all ;;
    status) show_status ;;
    backup) create_backup ;;
    update) update_ghost ;;
    rollback) rollback_ghost ;;
    restart) restart_ghost ;;
    logs) show_logs ;;
    doctor) run_doctor ;;
    renew-ssl) renew_ssl ;;
    restore) restore_backup ;;
    uninstall) uninstall_ghost ;;
    self-check) self_check ;;
    *) usage; die "æªç¥å½ä»¤ï¼$ACTION" ;;
  esac
}

main "$@"
