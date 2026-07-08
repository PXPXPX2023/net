#!/usr/bin/env bash
# ghost_ubuntu24_pro_v5.sh
# ASCII-only Ghost CMS one-key installer and maintenance script.
# Target stack: Ubuntu 24.04 + Node.js 22 LTS + MySQL 8 + Nginx + systemd + Ghost-CLI + HTTPS.
# Safe for GitHub raw download. No non-ASCII comments, prompts, or symbols.

set -Eeuo pipefail
IFS=$'\n\t'
shopt -s inherit_errexit 2>/dev/null || true

export LC_ALL=C.UTF-8
export LANG=C.UTF-8

VERSION="v5.0.0"
SCRIPT_NAME="ghost_ubuntu24_pro_v5.sh"

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
LOGGING_READY="0"

info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
err()  { printf '[ERROR] %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

quote() { printf '%q' "$1"; }

cleanup() {
  rm -f "$SUDOERS_TEMP" 2>/dev/null || true
  if [[ -n "${TMP_WORKDIR:-}" && -d "$TMP_WORKDIR" ]]; then
    rm -rf "$TMP_WORKDIR" || true
  fi
}

on_error() {
  local ec=$?
  local line=${BASH_LINENO[0]:-unknown}
  err "Script failed. exit_code=$ec line=$line"
  if [[ "$LOGGING_READY" == "1" ]]; then
    err "Log file: $LOG_FILE"
  fi
  cleanup
  exit "$ec"
}
trap on_error ERR
trap cleanup EXIT

usage() {
  cat <<'USAGE'
Ghost Ubuntu 24 Pro One-Key Script v5.0.0

Usage:
  sudo bash ghost_ubuntu24_pro_v5.sh install --domain example.com --email admin@example.com
  sudo bash ghost_ubuntu24_pro_v5.sh --domain example.com --email admin@example.com

Commands:
  install       Install Ghost with Nginx, MySQL, systemd, and HTTPS.
  status        Show current Ghost and service status.
  backup        Create a full backup.
  restore       Restore from a backup archive.
  update        Backup first, then update Ghost.
  rollback      Roll back the last failed Ghost update.
  restart       Restart Ghost.
  logs          Show Ghost and systemd logs.
  doctor        Run ghost doctor.
  renew-ssl     Rebuild Nginx SSL config and request or renew certificates.
  uninstall     Backup first, then remove Ghost database and Ghost installation.
  self-check    Run script syntax, ASCII, and environment checks.

Options:
  --domain DOMAIN             Main site domain, such as example.com. Do not include http:// or https://.
  --email EMAIL               Lets Encrypt notification email.
  --admin-domain DOMAIN       Optional admin domain, such as admin.example.com.
  --install-dir PATH          Default: /var/www/ghost. Must be empty or not exist for install.
  --admin-user USER           Default: ghostmgr. Must not be root or ghost.
  --db-name NAME              Default: ghost_prod.
  --db-user USER              Default: ghost_user.
  --db-pass PASS              Optional. Auto-generated if omitted.
  --port PORT                 Local Ghost port. Default: 2368.
  --backup-dir PATH           Default: /var/backups/ghost-onekey.
  --file PATH                 Backup archive path for restore.
  --enable-ufw                Enable UFW and allow OpenSSH plus Nginx Full.
  --skip-dns-check            Skip DNS A record validation.
  --force-os                  Continue on non-Ubuntu-24.04 systems. Not recommended.
  --no-pre-restore-backup     Do not auto-backup current site before restore.
  --yes, -y                   Confirm destructive actions.
  -h, --help                  Show this help.

GitHub raw example:
  curl -fsSL https://raw.githubusercontent.com/USER/REPO/main/ghost_ubuntu24_pro_v5.sh -o ghost_ubuntu24_pro_v5.sh
  chmod +x ghost_ubuntu24_pro_v5.sh
  sudo ./ghost_ubuntu24_pro_v5.sh --domain example.com --email admin@example.com

Important:
  1. The domain A record must point to this VPS IPv4 before HTTPS setup.
  2. If using Cloudflare, disable orange-cloud proxy for the first install, then use Full strict after HTTPS works.
  3. Backup archives contain database and config data. Do not upload them to public repositories.
USAGE
}

parse_args() {
  if [[ $# -gt 0 ]]; then
    case "$1" in
      install|status|backup|restore|update|rollback|restart|logs|doctor|renew-ssl|uninstall|self-check)
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
      *) die "Unknown argument: $1. Run --help for usage." ;;
    esac
  done
}

init_logging() {
  mkdir -p "$LOG_DIR"
  touch "$LOG_FILE"
  chmod 700 "$LOG_DIR"
  chmod 600 "$LOG_FILE"
  LOGGING_READY="1"
  exec > >(tee -a "$LOG_FILE") 2>&1
}

require_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "Run as root: sudo ./$SCRIPT_NAME ..."
}

acquire_lock() {
  exec 9>"$LOCK_FILE"
  flock -n 9 || die "Another ghost-onekey task is running: $LOCK_FILE"
}

apply_cli_overrides() {
  if [[ -n "$CLI_DOMAIN" ]]; then DOMAIN="$CLI_DOMAIN"; fi
  if [[ -n "$CLI_EMAIL" ]]; then EMAIL="$CLI_EMAIL"; fi
  if [[ -n "$CLI_ADMIN_DOMAIN" ]]; then ADMIN_DOMAIN="$CLI_ADMIN_DOMAIN"; fi
  if [[ -n "$CLI_INSTALL_DIR" ]]; then INSTALL_DIR="$CLI_INSTALL_DIR"; fi
  if [[ -n "$CLI_ADMIN_USER" ]]; then ADMIN_USER="$CLI_ADMIN_USER"; fi
  if [[ -n "$CLI_DB_NAME" ]]; then DB_NAME="$CLI_DB_NAME"; fi
  if [[ -n "$CLI_DB_USER" ]]; then DB_USER="$CLI_DB_USER"; fi
  if [[ -n "$CLI_DB_PASS" ]]; then DB_PASS="$CLI_DB_PASS"; fi
  if [[ -n "$CLI_PORT" ]]; then PORT="$CLI_PORT"; fi
  if [[ -n "$CLI_BACKUP_DIR" ]]; then BACKUP_DIR="$CLI_BACKUP_DIR"; fi
  return 0
}

load_config_if_exists() {
  if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
  elif [[ -f "$LEGACY_CONFIG_FILE" ]]; then
    warn "Legacy config found: $LEGACY_CONFIG_FILE. It will be read and rewritten as v5 config later."
    # shellcheck source=/dev/null
    source "$LEGACY_CONFIG_FILE"
  fi
  VERSION="v5.0.0"
  apply_cli_overrides
  return 0
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
  [[ -n "$d" ]] || die "Missing --domain"
  [[ ! "$d" =~ ^https?:// ]] || die "--domain must not include http:// or https://"
  [[ "$d" != */* ]] || die "--domain must not include a path"
  [[ "$d" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$ ]] || die "Invalid domain: $d"
}

validate_email() {
  local e="$1"
  [[ -n "$e" ]] || die "Missing --email"
  [[ "$e" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]] || die "Invalid email: $e"
}

validate_port() {
  [[ "$PORT" =~ ^[0-9]+$ ]] || die "Port must be numeric"
  (( PORT >= 1024 && PORT <= 65535 )) || die "Port must be between 1024 and 65535"
}

validate_paths_and_names() {
  [[ "$ADMIN_USER" != "root" && "$ADMIN_USER" != "ghost" ]] || die "--admin-user must not be root or ghost"
  [[ "$ADMIN_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "Invalid --admin-user"
  [[ "$DB_NAME" =~ ^[A-Za-z0-9_]{1,64}$ ]] || die "Invalid --db-name"
  [[ "$DB_USER" =~ ^[A-Za-z0-9_]{1,32}$ ]] || die "Invalid --db-user"
  [[ "$INSTALL_DIR" = /* ]] || die "--install-dir must be an absolute path"
  [[ "$BACKUP_DIR" = /* ]] || die "--backup-dir must be an absolute path"
  [[ "$INSTALL_DIR" =~ ^/[A-Za-z0-9._/@:+-]+$ ]] || die "--install-dir must not contain spaces or quotes"
  [[ "$BACKUP_DIR" =~ ^/[A-Za-z0-9._/@:+-]+$ ]] || die "--backup-dir must not contain spaces or quotes"
  if [[ -n "$DB_PASS" && ! "$DB_PASS" =~ ^[A-Za-z0-9_@%+=:.,~-]{16,128}$ ]]; then
    die "--db-pass must be 16-128 chars and use only A-Z a-z 0-9 _ @ % + = : . , ~ -"
  fi
}

require_domain_email_for_install_like() {
  [[ -n "$DOMAIN" ]] || die "$ACTION requires --domain example.com"
  [[ -n "$EMAIL" ]] || die "$ACTION requires --email admin@example.com"
  validate_domain "$DOMAIN"
  validate_email "$EMAIL"
  if [[ -n "$ADMIN_DOMAIN" ]]; then
    validate_domain "$ADMIN_DOMAIN"
  fi
  validate_port
  validate_paths_and_names
}

check_os() {
  [[ -f /etc/os-release ]] || die "Cannot identify OS: /etc/os-release is missing"
  # shellcheck source=/dev/null
  source /etc/os-release
  if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
    if [[ "$FORCE_OS" == "1" ]]; then
      warn "Current OS is ${PRETTY_NAME:-unknown}; continuing because --force-os was used."
    else
      die "This script targets Ubuntu 24.04 LTS. Current OS: ${PRETTY_NAME:-unknown}. Use --force-os only if you accept the risk."
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
  if [[ -z "$PUBLIC_IP" ]]; then
    warn "Could not detect public IPv4. DNS check will only verify that A records exist."
  fi
  return 0
}

resolve_a_records() {
  local d="$1"
  getent ahostsv4 "$d" | awk '{print $1}' | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//' || true
}

check_dns_one() {
  local d="$1"
  local resolved=""
  resolved="$(resolve_a_records "$d")"
  [[ -n "$resolved" ]] || die "Domain has no IPv4 A record: $d"
  info "A record: $d -> $resolved"
  if [[ -n "$PUBLIC_IP" ]]; then
    info "Server public IPv4: $PUBLIC_IP"
    if ! echo " $resolved " | grep -q " $PUBLIC_IP "; then
      die "DNS A record does not point to this server IPv4. If using Cloudflare proxy, disable proxy first, or use --skip-dns-check only when you are certain."
    fi
  fi
}

check_dns() {
  if [[ "$SKIP_DNS_CHECK" == "1" ]]; then
    warn "DNS check skipped. If HTTPS fails, verify DNS and inbound 80/443."
    return 0
  fi
  get_public_ip
  check_dns_one "$DOMAIN"
  if [[ -n "$ADMIN_DOMAIN" ]]; then
    check_dns_one "$ADMIN_DOMAIN"
  fi
  return 0
}

apt_wait() {
  local locks=(/var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock)
  local i
  if ! command -v fuser >/dev/null 2>&1; then
    return 0
  fi
  for i in {1..60}; do
    if ! fuser "${locks[@]}" >/dev/null 2>&1; then
      return 0
    fi
    warn "apt or dpkg is locked. Waiting... ($i/60)"
    sleep 3
  done
  die "Timed out waiting for apt or dpkg lock"
}

apt_update_once() {
  export DEBIAN_FRONTEND=noninteractive
  apt_wait
  apt-get update -y
}

install_base_packages() {
  info "Installing base packages"
  apt_update_once
  apt_wait
  apt-get install -y ca-certificates curl gnupg lsb-release unzip tar gzip rsync jq openssl ufw nginx mysql-server sudo python3 psmisc cron
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
      warn "Memory plus swap is below 1.2GB. Creating 1GB /swapfile."
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
  info "Installing Node.js ${NODE_MAJOR}.x"
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
  info "Installing or updating Ghost-CLI"
  npm install ghost-cli@latest -g
  ghost --version || true
}

setup_firewall() {
  if [[ "$ENABLE_UFW" == "1" ]]; then
    warn "Enabling UFW. If SSH uses a non-standard port, allow it manually before using --enable-ufw."
    ufw allow OpenSSH || true
    ufw allow 'Nginx Full' || true
    ufw --force enable
    ufw status verbose || true
  else
    if ufw status | grep -qi 'Status: active'; then
      info "UFW is active. Allowing Nginx Full."
      ufw allow 'Nginx Full' || true
    else
      warn "UFW is inactive. Not enabling it automatically. Use --enable-ufw if desired."
    fi
  fi
}

remove_nginx_default() {
  if [[ -e /etc/nginx/sites-enabled/default ]]; then
    info "Removing default Nginx site"
    rm -f /etc/nginx/sites-enabled/default
  fi
  nginx -t
  systemctl reload nginx || true
}

create_admin_user() {
  if ! id "$ADMIN_USER" >/dev/null 2>&1; then
    info "Creating admin user: $ADMIN_USER"
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
      die "$INSTALL_DIR is not empty. Ghost requires an empty install directory."
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
  info "Creating or updating MySQL database and user: $DB_NAME / $DB_USER"
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
    die "$INSTALL_DIR already looks like a Ghost installation. Use status, backup, update, or another --install-dir."
  fi
  info "Installing Ghost into $INSTALL_DIR"
  enable_temp_sudoers
  as_admin "$(build_ghost_install_cmd)"
  disable_temp_sudoers
  save_config
  info "Ghost install finished. Admin: https://$DOMAIN/ghost"
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
  [[ -f "$CONFIG_FILE" || -f "$LEGACY_CONFIG_FILE" ]] || die "No config file found. Install first, or provide complete parameters."
  validate_port
  validate_paths_and_names
  [[ -n "$INSTALL_DIR" && -d "$INSTALL_DIR" ]] || die "Install directory does not exist: $INSTALL_DIR"
}

backup_ghost_cli_zip() {
  local out_dir="$1"
  mkdir -p "$out_dir"
  local latest_zip
  enable_temp_sudoers
  as_admin "cd $(quote "$INSTALL_DIR") && ghost backup --no-prompt --no-color" || warn "ghost backup failed. Continuing with raw MySQL plus content backup."
  disable_temp_sudoers
  latest_zip="$(find "$INSTALL_DIR" -maxdepth 1 -type f -name '*.zip' -mmin -20 -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1{print $2}' || true)"
  if [[ -n "$latest_zip" && -f "$latest_zip" ]]; then
    cp -a "$latest_zip" "$out_dir/"
    rm -f "$latest_zip" || true
  fi
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

  info "Creating full backup: $archive"
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

  info "Dumping MySQL database: $DB_NAME"
  mysqldump --protocol=socket -uroot --single-transaction --routines --triggers --events --default-character-set=utf8mb4 "$DB_NAME" > "$TMP_WORKDIR/mysql.sql"

  info "Copying Ghost content directory"
  mkdir -p "$TMP_WORKDIR/content"
  rsync -a --numeric-ids "$INSTALL_DIR/content/" "$TMP_WORKDIR/content/"

  [[ -f "$INSTALL_DIR/config.production.json" ]] && cp -a "$INSTALL_DIR/config.production.json" "$TMP_WORKDIR/config.production.json"
  [[ -f "$CONFIG_FILE" ]] && cp -a "$CONFIG_FILE" "$TMP_WORKDIR/ghost-onekey-v5-config.env"
  [[ -f "$LEGACY_CONFIG_FILE" ]] && cp -a "$LEGACY_CONFIG_FILE" "$TMP_WORKDIR/ghost-onekey-legacy-config.env"

  info "Trying Ghost-CLI logical backup zip"
  backup_ghost_cli_zip "$TMP_WORKDIR/ghost-cli-backup"

  tar -C "$TMP_WORKDIR" -czf "$archive" .
  chmod 600 "$archive"
  info "Backup finished: $archive"
  rm -rf "$TMP_WORKDIR"
  TMP_WORKDIR=""
}

read_restore_metadata() {
  local meta="$1"
  if [[ ! -f "$meta" ]]; then
    return 0
  fi
  local meta_domain meta_email meta_admin_domain
  meta_domain="$(grep '^DOMAIN=' "$meta" | cut -d= -f2- | tr -d '"' || true)"
  meta_email="$(grep '^EMAIL=' "$meta" | cut -d= -f2- | tr -d '"' || true)"
  meta_admin_domain="$(grep '^ADMIN_DOMAIN=' "$meta" | cut -d= -f2- | tr -d '"' || true)"
  if [[ -z "$DOMAIN" && -n "$meta_domain" ]]; then DOMAIN="$meta_domain"; fi
  if [[ -z "$EMAIL" && -n "$meta_email" ]]; then EMAIL="$meta_email"; fi
  if [[ -z "$ADMIN_DOMAIN" && -n "$meta_admin_domain" ]]; then ADMIN_DOMAIN="$meta_admin_domain"; fi
  return 0
}

fresh_install_for_restore_if_needed() {
  load_config_if_exists
  if [[ -f "$CONFIG_FILE" && -d "$INSTALL_DIR/current" ]]; then
    info "Existing Ghost install detected. Restoring into current install."
    return 0
  fi

  info "No existing Ghost install detected. Installing a blank Ghost instance first."
  install_prerequisites_only
  prepare_install_dir
  setup_database
  install_ghost_site
}

setup_nginx_ssl() {
  ghost_in_dir "ghost setup nginx --no-prompt"
  ghost_in_dir "ghost setup ssl --sslemail $(quote "$EMAIL") --no-prompt"
}

restore_backup() {
  [[ -n "$RESTORE_FILE" ]] || die "restore requires --file /path/to/backup.tar.gz"
  [[ -f "$RESTORE_FILE" ]] || die "Backup file not found: $RESTORE_FILE"

  TMP_WORKDIR="$(mktemp -d)"
  chmod 700 "$TMP_WORKDIR"
  tar -xzf "$RESTORE_FILE" -C "$TMP_WORKDIR"
  [[ -f "$TMP_WORKDIR/mysql.sql" ]] || die "Backup archive lacks mysql.sql"
  [[ -d "$TMP_WORKDIR/content" ]] || die "Backup archive lacks content directory"

  read_restore_metadata "$TMP_WORKDIR/metadata.env"
  require_domain_email_for_install_like
  check_dns

  if [[ ( -f "$CONFIG_FILE" || -f "$LEGACY_CONFIG_FILE" ) && "$NO_PRE_RESTORE_BACKUP" != "1" ]]; then
    warn "Creating a pre-restore backup of the current site."
    local old_restore_file="$RESTORE_FILE"
    create_backup
    TMP_WORKDIR="$(mktemp -d)"
    chmod 700 "$TMP_WORKDIR"
    RESTORE_FILE="$old_restore_file"
    tar -xzf "$RESTORE_FILE" -C "$TMP_WORKDIR"
  fi

  fresh_install_for_restore_if_needed
  load_config_if_exists
  require_domain_email_for_install_like

  info "Stopping Ghost"
  ghost_in_dir "ghost stop || true"

  info "Recreating and importing database: $DB_NAME"
  mysql_exec <<SQL
DROP DATABASE IF EXISTS \`$DB_NAME\`;
CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL
  mysql --protocol=socket -uroot --default-character-set=utf8mb4 "$DB_NAME" < "$TMP_WORKDIR/mysql.sql"

  info "Restoring content directory"
  mkdir -p "$INSTALL_DIR/content"
  rsync -a --delete "$TMP_WORKDIR/content/" "$INSTALL_DIR/content/"
  if id ghost >/dev/null 2>&1; then
    chown -R ghost:ghost "$INSTALL_DIR/content"
  else
    chown -R "$ADMIN_USER:$ADMIN_USER" "$INSTALL_DIR/content"
  fi
  find "$INSTALL_DIR/content" -type d -exec chmod 775 {} \; || true
  find "$INSTALL_DIR/content" -type f -exec chmod 664 {} \; || true

  info "Updating Ghost URL and rebuilding Nginx plus SSL"
  ghost_in_dir "ghost config url $(quote "https://$DOMAIN")"
  if [[ -n "$ADMIN_DOMAIN" ]]; then
    ghost_in_dir "ghost config admin.url $(quote "https://$ADMIN_DOMAIN")"
  fi
  setup_nginx_ssl
  ghost_in_dir "ghost setup migrate --no-prompt || true"
  ghost_in_dir "ghost restart || ghost start"
  save_config
  info "Restore finished. Admin: https://$DOMAIN/ghost"
  rm -rf "$TMP_WORKDIR"
  TMP_WORKDIR=""
}

show_status() {
  require_config_for_maintenance
  info "Ghost OneKey config"
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
  info "Updating Ghost-CLI"
  npm install ghost-cli@latest -g
  info "Updating Ghost. If it fails, run rollback."
  ghost_in_dir "ghost update --no-prompt"
}

rollback_ghost() {
  require_config_for_maintenance
  info "Rolling back Ghost update"
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
  [[ -n "$EMAIL" ]] || die "renew-ssl requires --email or existing EMAIL in config"
  [[ -n "$DOMAIN" ]] || die "renew-ssl requires --domain or existing DOMAIN in config"
  validate_email "$EMAIL"
  validate_domain "$DOMAIN"
  validate_port
  validate_paths_and_names
  check_dns
  setup_nginx_ssl
  save_config
}

uninstall_ghost() {
  require_config_for_maintenance
  [[ "$YES" == "1" ]] || die "Uninstall removes Ghost application data and database. Add --yes to confirm."
  create_backup
  warn "Uninstalling Ghost. Backup is stored in $BACKUP_DIR."
  ghost_in_dir "ghost stop || true"
  ghost_in_dir "ghost uninstall --no-prompt || true"
  mysql_exec <<SQL || true
DROP DATABASE IF EXISTS \`$DB_NAME\`;
DROP USER IF EXISTS '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
SQL
  rm -f "$CONFIG_FILE"
  info "Uninstall finished. Check remaining directory manually: $INSTALL_DIR"
}

self_check_ascii() {
  local target="$1"
  python3 - "$target" <<'PYCHECK'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
b = p.read_bytes()
bad = [(i, x) for i, x in enumerate(b) if x > 127]
if bad:
    print(f"ASCII check: FAIL, non_ascii_bytes={len(bad)}, first_offset={bad[0][0]}, first_byte=0x{bad[0][1]:02x}")
    sys.exit(1)
print("ASCII check: OK")
PYCHECK
}

self_check() {
  info "Running self-check"
  bash -n "$0" || die "bash -n failed"
  echo "Bash syntax: OK"
  if command -v python3 >/dev/null 2>&1; then
    self_check_ascii "$0"
  else
    warn "python3 not found; skipping ASCII check"
  fi
  if [[ -f "$CONFIG_FILE" || -f "$LEGACY_CONFIG_FILE" ]]; then
    load_config_if_exists
    echo "Config file: FOUND"
    echo "Install dir: $INSTALL_DIR"
    [[ -d "$INSTALL_DIR" ]] && echo "Install dir exists: OK" || echo "Install dir exists: NO"
  else
    echo "Config file: not found; normal before install"
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
  [[ -n "$DB_PASS" ]] || DB_PASS="$(rand_pass)"

  if [[ -f "$CONFIG_FILE" || -f "$LEGACY_CONFIG_FILE" ]]; then
    die "Existing ghost-onekey config detected. Use status, backup, update, or uninstall --yes before reinstalling."
  fi

  install_prerequisites_only
  check_dns
  prepare_install_dir
  setup_database
  install_ghost_site

  cat <<DONE

======================================================================
Ghost install result
======================================================================
Site URL:       https://$DOMAIN
Admin URL:      https://$DOMAIN/ghost
Install dir:    $INSTALL_DIR
Admin user:     $ADMIN_USER
Database:       $DB_NAME
Backup dir:     $BACKUP_DIR
Config file:    $CONFIG_FILE
Log file:       $LOG_FILE

Common maintenance:
  sudo bash $0 status
  sudo bash $0 backup
  sudo bash $0 update
  sudo bash $0 rollback
  sudo bash $0 restore --file <backup-archive> --domain $DOMAIN --email $EMAIL

Important:
  1. Visit https://$DOMAIN/ghost to create the Ghost owner account.
  2. Backup archives contain sensitive data. Do not upload them to public GitHub repos.
  3. If using Cloudflare, enable proxy only after HTTPS works, then use Full strict.
======================================================================
DONE
}

main() {
  parse_args "$@"
  if [[ "$ACTION" == "self-check" && "${EUID:-$(id -u)}" -ne 0 ]]; then
    self_check
    exit 0
  fi
  require_root
  init_logging
  acquire_lock

  case "$ACTION" in
    install) install_all ;;
    status) show_status ;;
    backup) create_backup ;;
    restore) restore_backup ;;
    update) update_ghost ;;
    rollback) rollback_ghost ;;
    restart) restart_ghost ;;
    logs) show_logs ;;
    doctor) run_doctor ;;
    renew-ssl) renew_ssl ;;
    uninstall) uninstall_ghost ;;
    self-check) self_check ;;
    *) usage; die "Unknown command: $ACTION" ;;
  esac
}

main "$@"
