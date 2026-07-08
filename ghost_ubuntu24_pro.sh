#!/usr/bin/env bash
# ghost_ubuntu24_pro.sh
# Ghost CMS one-key installer/maintenance script for Ubuntu 24.04 LTS minimal.
# Stack: Nginx + MySQL 8 + Node.js 22 LTS + Ghost-CLI + systemd + HTTPS.
# Author: generated for GitHub self-hosting use

set -Eeuo pipefail
IFS=$'\n\t'

VERSION="v1.0.0"
CONFIG_FILE="/etc/ghost-onekey.conf"
SUDOERS_TEMP="/etc/sudoers.d/90-ghost-onekey-temp"
LOG_DIR="/var/log/ghost-onekey"
LOG_FILE="$LOG_DIR/run.log"

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
BACKUP_DIR="/var/backups/ghost-onekey"
RESTORE_FILE=""
ENABLE_UFW="0"
SKIP_DNS_CHECK="0"
FORCE_OS="0"
YES="0"
NO_PRE_RESTORE_BACKUP="0"
NODE_MAJOR="22"
PUBLIC_IP=""
P_NAME=""

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

# ----------------------------- UI helpers -----------------------------
info() { echo -e "[INFO] $*"; }
warn() { echo -e "[WARN] $*" >&2; }
err()  { echo -e "[ERROR] $*" >&2; }
die()  { err "$*"; exit 1; }

on_error() {
  local ec=$?
  err "èæ¬æ§è¡å¤±è´¥ï¼éåºç ï¼$ec"
  err "æ¥å¿ï¼$LOG_FILE"
  disable_temp_sudoers || true
  exit "$ec"
}
trap on_error ERR

usage() {
  cat <<USAGE
Ghost Ubuntu 24 Pro One-Key Script $VERSION

ç¨æ³ï¼
  sudo bash ghost_ubuntu24_pro.sh install --domain example.com --email admin@example.com
  sudo bash ghost_ubuntu24_pro.sh --domain example.com --email admin@example.com

ç»´æ¤å½ä»¤ï¼
  sudo bash ghost_ubuntu24_pro.sh status
  sudo bash ghost_ubuntu24_pro.sh backup
  sudo bash ghost_ubuntu24_pro.sh update
  sudo bash ghost_ubuntu24_pro.sh rollback
  sudo bash ghost_ubuntu24_pro.sh restart
  sudo bash ghost_ubuntu24_pro.sh logs
  sudo bash ghost_ubuntu24_pro.sh doctor
  sudo bash ghost_ubuntu24_pro.sh renew-ssl --email admin@example.com
  sudo bash ghost_ubuntu24_pro.sh restore --file /var/backups/ghost-onekey/ghost-full-xxxx.tar.gz --domain example.com --email admin@example.com
  sudo bash ghost_ubuntu24_pro.sh uninstall --yes

åæ°ï¼
  --domain DOMAIN              ä¸»ç«ååï¼ä¾å¦ example.comï¼ä¸è¦å¸¦ http:// æ https://
  --email EMAIL                Let's Encrypt è¯ä¹¦éç¥é®ç®±
  --admin-domain DOMAIN        å¯éï¼Ghost åå°ç¬ç«ååï¼ä¾å¦ admin.example.com
  --install-dir PATH           é»è®¤ /var/www/ghost
  --admin-user USER            é»è®¤ ghostmgrï¼ä¸è¦è®¾ä¸º ghost
  --db-name NAME               é»è®¤ ghost_prod
  --db-user USER               é»è®¤ ghost_user
  --db-pass PASS               å¯éï¼ä¸å¡«èªå¨çæ
  --port PORT                  Ghost æ¬å°çå¬ç«¯å£ï¼é»è®¤ 2368
  --backup-dir PATH            é»è®¤ /var/backups/ghost-onekey
  --file PATH                  restore ä½¿ç¨çå¤ä»½å
  --enable-ufw                 å¯ç¨ UFW å¹¶æ¾è¡ OpenSSH + Nginx Full
  --skip-dns-check             è·³è¿åå A è®°å½æ ¡éªï¼Cloudflare æ©äºæ¶å¯è½éè¦
  --force-os                   é Ubuntu 24.04 æ¶å¼ºå¶ç»§ç»­ï¼ä¸æ¨è
  --no-pre-restore-backup      restore åä¸èªå¨å¤ä»½ç°æç«ç¹
  --yes                        å¸è½½ç­å±é©æä½ç¡®è®¤
  -h, --help                   æ¾ç¤ºå¸®å©

æ¨è GitHub ä¸è½½æ§è¡ï¼
  curl -fsSL https://raw.githubusercontent.com/ä½ çç¨æ·å/ä½ çä»åº/main/ghost_ubuntu24_pro.sh -o ghost_ubuntu24_pro.sh
  chmod +x ghost_ubuntu24_pro.sh
  sudo ./ghost_ubuntu24_pro.sh --domain example.com --email admin@example.com

æ³¨æï¼
  1) ååå¿é¡»åè§£æå°æ¬ VPS çå¬ç½ IPv4ï¼HTTPS æè½ç­¾åã
  2) Cloudflare è¯·åå³é­æ©äºä»£çï¼è¯ä¹¦ç­¾åæåååæå¼ï¼å¹¶è®¾ç½® Full (strict)ã
  3) å¤ä»½ååå«æ°æ®åºå¯¼åºãcontent ç®å½åéç½®æä»¶ï¼å¯è½å« SMTP/æ°æ®åºå¯ç ï¼ä¸è¦ä¸ä¼ å°å¬å¼ä»åºã
USAGE
}

# ----------------------------- arg parser -----------------------------
parse_args() {
  if [[ $# -gt 0 ]]; then
    case "$1" in
      install|status|backup|update|rollback|restart|logs|doctor|renew-ssl|restore|uninstall)
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
      --yes|-y) YES="1"; shift ;;
      --no-pre-restore-backup) NO_PRE_RESTORE_BACKUP="1"; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "æªç¥åæ°ï¼$1ãè¿è¡ --help æ¥çç¨æ³ã" ;;
    esac
  done

  if [[ -z "$P_NAME" && -n "$DOMAIN" ]]; then
    P_NAME="ghost-$(echo "$DOMAIN" | tr '.-' '__' | tr -cd '[:alnum:]_')"
  fi
}

# ----------------------------- basic checks -----------------------------
init_logging() {
  mkdir -p "$LOG_DIR"
  touch "$LOG_FILE"
  chmod 700 "$LOG_DIR"
  chmod 600 "$LOG_FILE"
  exec > >(tee -a "$LOG_FILE") 2>&1
}

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "è¯·ç¨ root æ§è¡ï¼sudo ./ghost_ubuntu24_pro.sh ..."
}

load_config_if_exists() {
  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
    # Re-apply explicit CLI parameters after loading persisted config.
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
  fi
}

save_config() {
  umask 077
  cat > "$CONFIG_FILE" <<CFG
DOMAIN="$DOMAIN"
EMAIL="$EMAIL"
ADMIN_DOMAIN="$ADMIN_DOMAIN"
INSTALL_DIR="$INSTALL_DIR"
ADMIN_USER="$ADMIN_USER"
DB_NAME="$DB_NAME"
DB_USER="$DB_USER"
DB_PASS="$DB_PASS"
PORT="$PORT"
BACKUP_DIR="$BACKUP_DIR"
NODE_MAJOR="$NODE_MAJOR"
P_NAME="$P_NAME"
CFG
  chmod 600 "$CONFIG_FILE"
}

validate_domain() {
  local d="$1"
  [[ -n "$d" ]] || die "ç¼ºå° --domain"
  [[ ! "$d" =~ ^https?:// ]] || die "--domain ä¸è¦å¸¦ http:// æ https://ï¼åªå¡« example.com"
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

validate_names() {
  [[ "$ADMIN_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "--admin-user åªåè®¸ Linux ç¨æ·åæ ¼å¼ï¼å°åå­æ¯/æ°å­/_/-"
  [[ "$DB_NAME" =~ ^[A-Za-z0-9_]{1,64}$ ]] || die "--db-name åªåè®¸å­æ¯ãæ°å­ãä¸åçº¿"
  [[ "$DB_USER" =~ ^[A-Za-z0-9_]{1,32}$ ]] || die "--db-user åªåè®¸å­æ¯ãæ°å­ãä¸åçº¿"
  [[ "$INSTALL_DIR" = /* ]] || die "--install-dir å¿é¡»æ¯ç»å¯¹è·¯å¾"
  [[ "$DB_PASS" != *"'"* ]] || die "--db-pass ä¸åè®¸åå«åå¼å·ï¼é¿å SQL/CLI è½¬ä¹é£é©"
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

require_domain_email_for_install_like() {
  [[ -n "$DOMAIN" ]] || die "$ACTION éè¦ --domain example.com"
  [[ -n "$EMAIL" ]] || die "$ACTION éè¦ --email admin@example.com"
  validate_domain "$DOMAIN"
  validate_email "$EMAIL"
  if [[ -n "$ADMIN_DOMAIN" ]]; then
    validate_domain "$ADMIN_DOMAIN"
  fi
  validate_port
  validate_names
}

rand_pass() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 36 | tr -d '\n' | tr '/+' '_-' | cut -c1-32
  else
    tr -dc 'A-Za-z0-9_-' </dev/urandom | head -c 32
  fi
}

# ----------------------------- network/dns -----------------------------
get_public_ip() {
  PUBLIC_IP="$(curl -4fsS --max-time 8 https://api.ipify.org 2>/dev/null || true)"
  if [[ -z "$PUBLIC_IP" ]]; then
    PUBLIC_IP="$(curl -4fsS --max-time 8 https://ifconfig.me 2>/dev/null || true)"
  fi
  [[ -n "$PUBLIC_IP" ]] || warn "æ æ³è·åå¬ç½ IPv4ï¼å°åªåå¼± DNS æ£æ¥ã"
}

check_dns() {
  [[ "$SKIP_DNS_CHECK" == "1" ]] && { warn "å·²è·³è¿ DNS æ£æ¥ã"; return 0; }
  get_public_ip
  local resolved=""
  resolved="$(getent ahostsv4 "$DOMAIN" | awk '{print $1}' | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//' || true)"
  [[ -n "$resolved" ]] || die "åå $DOMAIN å°æªè§£æå° IPv4ãè¯·åæ·»å  A è®°å½å°æ¬ VPS å¬ç½ IPã"
  info "åå A è®°å½ï¼$DOMAIN -> $resolved"
  if [[ -n "$PUBLIC_IP" ]]; then
    info "æ¬æºå¬ç½ IPv4ï¼$PUBLIC_IP"
    if ! echo " $resolved " | grep -q " $PUBLIC_IP "; then
      die "DNS A è®°å½æªæåæ¬æºå¬ç½ IPv4ãè¥ä½¿ç¨ Cloudflare æ©äºï¼è¯·åå³æ©äºï¼æå  --skip-dns-checkã"
    fi
  fi

  if [[ -n "$ADMIN_DOMAIN" ]]; then
    local admin_resolved=""
    admin_resolved="$(getent ahostsv4 "$ADMIN_DOMAIN" | awk '{print $1}' | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//' || true)"
    [[ -n "$admin_resolved" ]] || die "åå°åå $ADMIN_DOMAIN å°æªè§£æå° IPv4ã"
    if [[ -n "$PUBLIC_IP" ]] && ! echo " $admin_resolved " | grep -q " $PUBLIC_IP "; then
      die "åå°åå $ADMIN_DOMAIN æªæåæ¬æºå¬ç½ IPv4ã"
    fi
  fi
}

# ----------------------------- system prep -----------------------------
apt_update_once() {
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
}

install_base_packages() {
  info "å®è£åºç¡ç»ä»¶ï¼curlãgnupgãnginxãmysql-serverãrsyncãufw ç­"
  apt_update_once
  apt-get install -y ca-certificates curl gnupg lsb-release unzip tar gzip rsync jq openssl ufw nginx mysql-server sudo python3
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
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
  apt_update_once
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
  systemctl enable --now nginx
  systemctl reload nginx || true
}

create_admin_user() {
  [[ "$ADMIN_USER" != "ghost" ]] || die "ADMIN_USER ä¸è½å« ghostï¼ä¼ä¸ Ghost-CLI åå»ºçä½æéè¿è¡ç¨æ·å²çªã"
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
  rm -f "$SUDOERS_TEMP"
}

prepare_install_dir() {
  mkdir -p "$INSTALL_DIR"
  chown "$ADMIN_USER:$ADMIN_USER" "$INSTALL_DIR"
  chmod 775 "$INSTALL_DIR"
}

mysql_exec() {
  mysql --protocol=socket -uroot "$@"
}

setup_database() {
  [[ -n "$DB_PASS" ]] || DB_PASS="$(rand_pass)"
  info "åå»º/æ´æ° MySQL æ°æ®åºåç¨æ·ï¼$DB_NAME / $DB_USER"
  local sql
  sql="
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
ALTER USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;"
  mysql_exec -e "$sql"
}

# ----------------------------- Ghost commands -----------------------------
as_admin() {
  local cmd="$1"
  sudo -u "$ADMIN_USER" -H bash -lc "$cmd"
}

ghost_cmd() {
  local cmd="$1"
  enable_temp_sudoers
  as_admin "cd '$INSTALL_DIR' && $cmd"
  disable_temp_sudoers
}

build_install_cmd() {
  local url="https://$DOMAIN"
  local admin_arg=""
  [[ -n "$ADMIN_DOMAIN" ]] && admin_arg=" --admin-url https://$ADMIN_DOMAIN"
  cat <<CMD
cd '$INSTALL_DIR' && ghost install \
  --url '$url' \
  $admin_arg \
  --ip '127.0.0.1' \
  --port '$PORT' \
  --db mysql \
  --dbhost localhost \
  --dbuser '$DB_USER' \
  --dbpass '$DB_PASS' \
  --dbname '$DB_NAME' \
  --process systemd \
  --pname '$P_NAME' \
  --sslemail '$EMAIL' \
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
  as_admin "$(build_install_cmd)"
  disable_temp_sudoers
  save_config
  info "Ghost å®è£å®æãåå°å¥å£ï¼https://$DOMAIN/ghost"
}

# ----------------------------- backup / restore -----------------------------
ensure_backup_dir() {
  mkdir -p "$BACKUP_DIR"
  chmod 700 "$BACKUP_DIR"
}

require_config_for_maintenance() {
  load_config_if_exists
  [[ -f "$CONFIG_FILE" ]] || die "æªæ¾å° $CONFIG_FILEãè¯·åå®è£ï¼æå¨å½ä»¤ä¸­è¡¥åå®æ´åæ°ã"
  [[ -n "$INSTALL_DIR" && -d "$INSTALL_DIR" ]] || die "å®è£ç®å½ä¸å­å¨ï¼$INSTALL_DIR"
}

create_backup() {
  require_config_for_maintenance
  ensure_backup_dir
  local ts tmp archive base
  ts="$(date +%Y%m%d_%H%M%S)"
  base="ghost-full-${DOMAIN:-site}-${ts}"
  tmp="$(mktemp -d)"
  archive="$BACKUP_DIR/${base}.tar.gz"
  chmod 700 "$tmp"

  info "åå»º Ghost å¨éå¤ä»½ï¼$archive"
  cat > "$tmp/metadata.env" <<META
VERSION="$VERSION"
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
P_NAME="$P_NAME"
META

  info "å¯¼åº MySQL æ°æ®åºï¼$DB_NAME"
  mysqldump --single-transaction --routines --triggers --events --default-character-set=utf8mb4 "$DB_NAME" > "$tmp/mysql.sql"

  info "å¤å¶ Ghost content ç®å½"
  mkdir -p "$tmp/content"
  rsync -a "$INSTALL_DIR/content/" "$tmp/content/"

  if [[ -f "$INSTALL_DIR/config.production.json" ]]; then
    cp -a "$INSTALL_DIR/config.production.json" "$tmp/config.production.json"
  fi
  if [[ -f "$CONFIG_FILE" ]]; then
    cp -a "$CONFIG_FILE" "$tmp/ghost-onekey.conf"
  fi

  info "å°è¯çæ Ghost-CLI é»è¾å¤ä»½ zip"
  local cli_tmp
  cli_tmp="$(mktemp -d /tmp/ghost-cli-backup.XXXXXX)"
  chown "$ADMIN_USER:$ADMIN_USER" "$cli_tmp"
  enable_temp_sudoers
  (cd "$cli_tmp" && sudo -u "$ADMIN_USER" -H ghost backup --dir "$INSTALL_DIR") || warn "ghost backup å¤±è´¥ï¼å·²ç»§ç»­ä¿ç raw æ°æ®åº+content å¨éå¤ä»½ã"
  disable_temp_sudoers
  find "$cli_tmp" -maxdepth 1 -type f -name '*.zip' -print -exec cp -a {} "$tmp/" \; || true
  rm -rf "$cli_tmp"

  tar -C "$tmp" -czf "$archive" .
  chmod 600 "$archive"
  rm -rf "$tmp"
  info "å¤ä»½å®æï¼$archive"
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
  prepare_install_dir
}

fresh_install_for_restore_if_needed() {
  if [[ -f "$CONFIG_FILE" && -d "$INSTALL_DIR/current" ]]; then
    info "æ£æµå°ç°æ Ghost å®è£ï¼å°å¨å¶ä¸æ¢å¤æ°æ®ã"
    load_config_if_exists
    return 0
  fi
  info "æªæ£æµå°ç°æ Ghost å®è£ï¼åå®è£ä¸ä¸ªç©º Ghost å®ä¾ç¨äºæ¿è½½æ¢å¤æ°æ®ã"
  [[ -n "$DB_PASS" ]] || DB_PASS="$(rand_pass)"
  P_NAME="ghost-$(echo "$DOMAIN" | tr '.-' '__' | tr -cd '[:alnum:]_')"
  install_prerequisites_only
  setup_database
  install_ghost_site
}

restore_backup() {
  [[ -n "$RESTORE_FILE" ]] || die "restore éè¦ --file /path/to/backup.tar.gz"
  [[ -f "$RESTORE_FILE" ]] || die "å¤ä»½æä»¶ä¸å­å¨ï¼$RESTORE_FILE"

  local tmp meta_domain meta_email
  tmp="$(mktemp -d)"
  chmod 700 "$tmp"
  tar -xzf "$RESTORE_FILE" -C "$tmp"
  [[ -f "$tmp/mysql.sql" ]] || die "å¤ä»½åç¼ºå° mysql.sql"
  [[ -d "$tmp/content" ]] || die "å¤ä»½åç¼ºå° content ç®å½"

  if [[ -f "$tmp/metadata.env" ]]; then
    meta_domain="$(grep '^DOMAIN=' "$tmp/metadata.env" | cut -d= -f2- | tr -d '"' || true)"
    meta_email="$(grep '^EMAIL=' "$tmp/metadata.env" | cut -d= -f2- | tr -d '"' || true)"
    [[ -z "$DOMAIN" && -n "$meta_domain" ]] && DOMAIN="$meta_domain"
    [[ -z "$EMAIL" && -n "$meta_email" ]] && EMAIL="$meta_email"
  fi

  require_domain_email_for_install_like
  check_dns

  if [[ -f "$CONFIG_FILE" && "$NO_PRE_RESTORE_BACKUP" != "1" ]]; then
    warn "æ¢å¤ååèªå¨å¤ä»½å½åç«ç¹ã"
    create_backup
  fi

  fresh_install_for_restore_if_needed
  load_config_if_exists

  info "åæ­¢ Ghost"
  enable_temp_sudoers
  as_admin "cd '$INSTALL_DIR' && ghost stop || true"
  disable_temp_sudoers

  info "æ¸ç©ºå¹¶å¯¼å¥æ°æ®åºï¼$DB_NAME"
  mysql_exec -e "DROP DATABASE IF EXISTS \`$DB_NAME\`; CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci; GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost'; FLUSH PRIVILEGES;"
  mysql --default-character-set=utf8mb4 "$DB_NAME" < "$tmp/mysql.sql"

  info "æ¢å¤ content ç®å½"
  rsync -a --delete "$tmp/content/" "$INSTALL_DIR/content/"
  if id ghost >/dev/null 2>&1; then
    chown -R ghost:ghost "$INSTALL_DIR/content"
  else
    chown -R "$ADMIN_USER:$ADMIN_USER" "$INSTALL_DIR/content"
  fi

  info "åæ­¥ç«ç¹ URL å¹¶éå¯"
  enable_temp_sudoers
  as_admin "cd '$INSTALL_DIR' && ghost config url 'https://$DOMAIN' && ghost setup nginx ssl --sslemail '$EMAIL' --no-prompt && ghost start || ghost restart"
  disable_temp_sudoers

  rm -rf "$tmp"
  save_config
  info "æ¢å¤å®æï¼ https://$DOMAIN/ghost"
}

# ----------------------------- maintenance -----------------------------
show_status() {
  require_config_for_maintenance
  info "Ghost OneKey éç½®ï¼"
  echo "  DOMAIN=$DOMAIN"
  echo "  INSTALL_DIR=$INSTALL_DIR"
  echo "  ADMIN_USER=$ADMIN_USER"
  echo "  DB_NAME=$DB_NAME"
  echo "  PORT=$PORT"
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
  enable_temp_sudoers
  as_admin "cd '$INSTALL_DIR' && ghost update"
  disable_temp_sudoers
}

rollback_ghost() {
  require_config_for_maintenance
  info "æ§è¡ Ghost åæ»"
  enable_temp_sudoers
  as_admin "cd '$INSTALL_DIR' && ghost update --rollback"
  disable_temp_sudoers
}

restart_ghost() {
  require_config_for_maintenance
  enable_temp_sudoers
  as_admin "cd '$INSTALL_DIR' && ghost restart"
  disable_temp_sudoers
}

show_logs() {
  require_config_for_maintenance
  enable_temp_sudoers
  as_admin "cd '$INSTALL_DIR' && ghost log || true"
  disable_temp_sudoers
  echo ""
  journalctl -u "ghost*" -n 120 --no-pager || true
}

run_doctor() {
  require_config_for_maintenance
  enable_temp_sudoers
  as_admin "cd '$INSTALL_DIR' && ghost doctor"
  disable_temp_sudoers
}

renew_ssl() {
  require_config_for_maintenance
  [[ -n "$EMAIL" ]] || die "renew-ssl éè¦ --email æéç½®æä»¶ä¸­å·²æ EMAIL"
  validate_email "$EMAIL"
  enable_temp_sudoers
  as_admin "cd '$INSTALL_DIR' && ghost setup nginx ssl --sslemail '$EMAIL' --no-prompt"
  disable_temp_sudoers
  save_config
}

uninstall_ghost() {
  require_config_for_maintenance
  [[ "$YES" == "1" ]] || die "å¸è½½ä¼å é¤ Ghost ç¨åºä¸æ°æ®åºãè¯·ç¡®è®¤åå  --yesã"
  create_backup
  warn "å¼å§å¸è½½ Ghostãå¤ä»½å·²ä¿å­å¨ $BACKUP_DIRã"
  enable_temp_sudoers
  as_admin "cd '$INSTALL_DIR' && ghost stop || true"
  as_admin "cd '$INSTALL_DIR' && ghost uninstall --no-prompt || true"
  disable_temp_sudoers
  mysql_exec -e "DROP DATABASE IF EXISTS \`$DB_NAME\`; DROP USER IF EXISTS '$DB_USER'@'localhost'; FLUSH PRIVILEGES;" || true
  rm -f "$CONFIG_FILE"
  info "å¸è½½å®æãå®è£ç®å½å¦ææ®çè¯·äººå·¥æ£æ¥ï¼$INSTALL_DIR"
}

# ----------------------------- install orchestration -----------------------------
install_all() {
  require_domain_email_for_install_like
  check_os
  check_dns

  [[ -n "$DB_PASS" ]] || DB_PASS="$(rand_pass)"
  [[ -n "$P_NAME" ]] || P_NAME="ghost-$(echo "$DOMAIN" | tr '.-' '__' | tr -cd '[:alnum:]_')"

  install_base_packages
  ensure_swap
  install_nodejs
  install_ghost_cli
  setup_firewall
  remove_nginx_default
  create_admin_user
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

  case "$ACTION" in
    install) install_all ;;
    status) show_status ;;
    backup) create_backup ;;
    update) update_ghost ;;
    rollback) rollback_ghost ;;
    restart) restart_ghost ;;
    logs) show_logs ;;
    doctor) run_doctor ;;
    renew-ssl) [[ -n "$EMAIL" ]] || load_config_if_exists; renew_ssl ;;
    restore) restore_backup ;;
    uninstall) uninstall_ghost ;;
    *) usage; die "æªç¥å½ä»¤ï¼$ACTION" ;;
  esac
}

main "$@"
