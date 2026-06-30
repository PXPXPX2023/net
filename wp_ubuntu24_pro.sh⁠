#!/usr/bin/env bash
#
# wp_ubuntu24_pro.sh
# WordPress one-click installer for Ubuntu 24.04 LTS minimal
# Stack: Nginx + PHP 8.3-FPM + MariaDB + Redis + WP-CLI + Let's Encrypt HTTPS
# Author: LP/ChatGPT
# License: MIT
#
# Recommended:
#   bash wp_ubuntu24_pro.sh --domain example.com --email admin@example.com
#
# Quick download example:
#   curl -fsSL https://raw.githubusercontent.com/YOUR_NAME/YOUR_REPO/main/wp_ubuntu24_pro.sh -o wp_ubuntu24_pro.sh
#   chmod +x wp_ubuntu24_pro.sh
#   sudo ./wp_ubuntu24_pro.sh --domain example.com --email admin@example.com
#

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_VERSION="1.0.0"
PHP_VERSION="8.3"
DEFAULT_INSTALL_DIR="/var/www/wordpress"
DEFAULT_DB_NAME="wordpress"
DEFAULT_DB_USER="wpuser"
DEFAULT_LOCALE="zh_CN"
LOG_DIR="/var/log/wp-oneclick"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
BACKUP_DIR="/root/wp-oneclick-backup"

DOMAIN=""
EMAIL=""
SITE_TITLE=""
ADMIN_USER=""
ADMIN_PASS=""
ADMIN_EMAIL=""
DB_NAME="$DEFAULT_DB_NAME"
DB_USER="$DEFAULT_DB_USER"
DB_PASS=""
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
LOCALE="$DEFAULT_LOCALE"
ENABLE_SSL=1
ENABLE_WWW=0
ENABLE_REDIS=1
ENABLE_UFW=0
SKIP_DNS_CHECK=0
FORCE_INSTALL=0
NON_INTERACTIVE=0
CURRENT_PUBLIC_IP=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "$LOG_DIR" "$BACKUP_DIR"
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

trap 'on_error $LINENO "$BASH_COMMAND"' ERR

on_error() {
  local line="$1"
  local cmd="$2"
  echo -e "\n${RED}[ERROR] Script failed at line ${line}: ${cmd}${NC}"
  echo -e "${YELLOW}Log file: ${LOG_FILE}${NC}"
  exit 1
}

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
fatal() { echo -e "${RED}[FATAL]${NC} $*"; exit 1; }

usage() {
  cat <<USAGE
WordPress One-Click Installer for Ubuntu 24.04 LTS minimal v${SCRIPT_VERSION}

Usage:
  sudo bash $0 --domain example.com --email admin@example.com [options]

Options:
  --domain DOMAIN             Main domain, for example: example.com
  --email EMAIL               Email for Let's Encrypt and WordPress admin fallback
  --site-title TITLE          WordPress site title
  --admin-user USER           WordPress admin username
  --admin-pass PASS           WordPress admin password; random if omitted
  --admin-email EMAIL         WordPress admin email; defaults to --email
  --db-name NAME              Database name; default: wordpress
  --db-user USER              Database user; default: wpuser
  --db-pass PASS              Database password; random if omitted
  --install-dir DIR           Install path; default: /var/www/wordpress
  --locale LOCALE             WordPress locale; default: zh_CN
  --www                       Also configure www.DOMAIN
  --no-ssl                    Skip Let's Encrypt HTTPS
  --no-redis                  Do not install/configure Redis object cache
  --enable-ufw                Enable UFW and allow 22/80/443
  --skip-dns-check            Skip A/AAAA DNS check before SSL
  --force                     Overwrite existing install directory and Nginx vhost backup
  --non-interactive           Do not ask questions; missing values are auto-generated where possible
  -h, --help                  Show this help

Examples:
  sudo bash $0 --domain example.com --email admin@example.com
  sudo bash $0 --domain example.com --email admin@example.com --www --enable-ufw
  sudo bash $0 --domain example.com --email admin@example.com --no-ssl

USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --domain) DOMAIN="${2:-}"; shift 2 ;;
      --email) EMAIL="${2:-}"; shift 2 ;;
      --site-title) SITE_TITLE="${2:-}"; shift 2 ;;
      --admin-user) ADMIN_USER="${2:-}"; shift 2 ;;
      --admin-pass) ADMIN_PASS="${2:-}"; shift 2 ;;
      --admin-email) ADMIN_EMAIL="${2:-}"; shift 2 ;;
      --db-name) DB_NAME="${2:-}"; shift 2 ;;
      --db-user) DB_USER="${2:-}"; shift 2 ;;
      --db-pass) DB_PASS="${2:-}"; shift 2 ;;
      --install-dir) INSTALL_DIR="${2:-}"; shift 2 ;;
      --locale) LOCALE="${2:-}"; shift 2 ;;
      --www) ENABLE_WWW=1; shift ;;
      --no-ssl) ENABLE_SSL=0; shift ;;
      --no-redis) ENABLE_REDIS=0; shift ;;
      --enable-ufw) ENABLE_UFW=1; shift ;;
      --skip-dns-check) SKIP_DNS_CHECK=1; shift ;;
      --force) FORCE_INSTALL=1; shift ;;
      --non-interactive) NON_INTERACTIVE=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) fatal "Unknown option: $1" ;;
    esac
  done
}

require_root() {
  [[ "${EUID}" -eq 0 ]] || fatal "Please run as root: sudo bash $0 ..."
}

check_os() {
  [[ -f /etc/os-release ]] || fatal "Cannot detect OS. /etc/os-release not found."
  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
    warn "This script is designed for Ubuntu 24.04 LTS. Detected: ${PRETTY_NAME:-unknown}"
    if [[ "$FORCE_INSTALL" -ne 1 ]]; then
      fatal "Use --force if you really want to continue on this OS."
    fi
  fi
  success "OS check passed: ${PRETTY_NAME:-Ubuntu 24.04}"
}

valid_domain() {
  local d="$1"
  [[ "$d" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]
}

valid_email() {
  local e="$1"
  [[ "$e" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]
}

random_password() {
  openssl rand -base64 36 | tr -d '=+/[:space:]' | cut -c1-24
}

validate_inputs() {
  [[ "$DB_NAME" =~ ^[A-Za-z0-9_]+$ ]] || fatal "Invalid --db-name. Use letters, numbers, underscore only."
  [[ "$DB_USER" =~ ^[A-Za-z0-9_]+$ ]] || fatal "Invalid --db-user. Use letters, numbers, underscore only."
  [[ "$ADMIN_USER" =~ ^[A-Za-z0-9_@.-]+$ ]] || fatal "Invalid --admin-user. Use letters, numbers, underscore, @, dot, hyphen only."
  case "$INSTALL_DIR" in
    /|/root|/etc|/usr|/var|/var/www) fatal "Unsafe --install-dir: $INSTALL_DIR" ;;
  esac
}

prompt_if_needed() {
  if [[ -z "$DOMAIN" && "$NON_INTERACTIVE" -ne 1 ]]; then
    read -rp "Enter domain, e.g. example.com: " DOMAIN
  fi
  [[ -n "$DOMAIN" ]] || fatal "--domain is required."
  valid_domain "$DOMAIN" || fatal "Invalid domain: $DOMAIN"

  if [[ -z "$EMAIL" && "$NON_INTERACTIVE" -ne 1 ]]; then
    read -rp "Enter email for SSL/admin, e.g. admin@example.com: " EMAIL
  fi
  [[ -n "$EMAIL" ]] || EMAIL="admin@$DOMAIN"
  valid_email "$EMAIL" || fatal "Invalid email: $EMAIL"

  [[ -n "$ADMIN_EMAIL" ]] || ADMIN_EMAIL="$EMAIL"
  valid_email "$ADMIN_EMAIL" || fatal "Invalid admin email: $ADMIN_EMAIL"

  if [[ -z "$SITE_TITLE" ]]; then
    SITE_TITLE="$DOMAIN"
  fi

  if [[ -z "$ADMIN_USER" ]]; then
    ADMIN_USER="wpadmin"
  fi

  if [[ -z "$ADMIN_PASS" ]]; then
    ADMIN_PASS="$(random_password)"
  fi

  if [[ -z "$DB_PASS" ]]; then
    DB_PASS="$(random_password)"
  fi

  [[ "$INSTALL_DIR" == /* ]] || fatal "--install-dir must be an absolute path."
  validate_inputs

  info "Install settings:"
  echo "  Domain:        $DOMAIN"
  [[ "$ENABLE_WWW" -eq 1 ]] && echo "  WWW alias:     www.$DOMAIN" || true
  echo "  Install dir:   $INSTALL_DIR"
  echo "  Site title:    $SITE_TITLE"
  echo "  Admin user:    $ADMIN_USER"
  echo "  Admin email:   $ADMIN_EMAIL"
  echo "  Database:      $DB_NAME"
  echo "  DB user:       $DB_USER"
  echo "  HTTPS:         $([[ "$ENABLE_SSL" -eq 1 ]] && echo enabled || echo disabled)"
  echo "  Redis:         $([[ "$ENABLE_REDIS" -eq 1 ]] && echo enabled || echo disabled)"

  if [[ "$NON_INTERACTIVE" -ne 1 ]]; then
    echo
    read -rp "Continue installation? [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]] || fatal "Cancelled by user."
  fi
}

install_base_packages() {
  info "Updating apt and installing base packages..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y \
    ca-certificates curl wget gnupg lsb-release apt-transport-https \
    software-properties-common unzip zip tar rsync cron logrotate \
    nginx mariadb-server mariadb-client \
    php${PHP_VERSION}-fpm php${PHP_VERSION}-cli php${PHP_VERSION}-mysql \
    php${PHP_VERSION}-curl php${PHP_VERSION}-gd php${PHP_VERSION}-mbstring \
    php${PHP_VERSION}-xml php${PHP_VERSION}-zip php${PHP_VERSION}-intl \
    php${PHP_VERSION}-bcmath php${PHP_VERSION}-imagick php${PHP_VERSION}-opcache \
    certbot python3-certbot-nginx \
    openssl dnsutils ufw fail2ban

  if [[ "$ENABLE_REDIS" -eq 1 ]]; then
    apt-get install -y redis-server php${PHP_VERSION}-redis
  fi

  systemctl enable --now nginx
  systemctl enable --now mariadb
  systemctl enable --now php${PHP_VERSION}-fpm
  [[ "$ENABLE_REDIS" -eq 1 ]] && systemctl enable --now redis-server || true
  success "Packages installed."
}

configure_ufw() {
  if [[ "$ENABLE_UFW" -ne 1 ]]; then
    warn "UFW not enabled by default. Use --enable-ufw if you want the script to manage firewall rules."
    return 0
  fi

  info "Configuring UFW..."
  ufw allow OpenSSH || ufw allow 22/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
  ufw --force enable
  ufw status verbose || true
  success "UFW configured."
}

get_public_ip() {
  local ip=""
  ip="$(curl -4fsS --max-time 8 https://api.ipify.org || true)"
  if [[ -z "$ip" ]]; then
    ip="$(curl -4fsS --max-time 8 https://ifconfig.me/ip || true)"
  fi
  CURRENT_PUBLIC_IP="$ip"
  [[ -n "$CURRENT_PUBLIC_IP" ]] || warn "Could not detect public IPv4. DNS check may be incomplete."
}

check_dns() {
  if [[ "$SKIP_DNS_CHECK" -eq 1 || "$ENABLE_SSL" -ne 1 ]]; then
    warn "DNS check skipped."
    return 0
  fi

  get_public_ip
  [[ -n "$CURRENT_PUBLIC_IP" ]] || return 0

  info "Checking DNS A record for $DOMAIN ..."
  local resolved_ips
  resolved_ips="$(dig +short A "$DOMAIN" | tr '\n' ' ' || true)"

  if [[ -z "$resolved_ips" ]]; then
    fatal "No A record found for $DOMAIN. Please point your domain to this VPS IP: $CURRENT_PUBLIC_IP"
  fi

  if ! grep -qw "$CURRENT_PUBLIC_IP" <<< "$resolved_ips"; then
    fatal "DNS A record mismatch. $DOMAIN resolves to [$resolved_ips], but VPS public IPv4 is [$CURRENT_PUBLIC_IP]. Fix DNS or use --skip-dns-check."
  fi

  if [[ "$ENABLE_WWW" -eq 1 ]]; then
    local www_ips
    www_ips="$(dig +short A "www.$DOMAIN" | tr '\n' ' ' || true)"
    if [[ -z "$www_ips" ]]; then
      fatal "No A record found for www.$DOMAIN. Add A/CNAME record or remove --www. VPS IP: $CURRENT_PUBLIC_IP"
    fi
    if ! grep -qw "$CURRENT_PUBLIC_IP" <<< "$www_ips"; then
      warn "www.$DOMAIN does not resolve to this VPS IPv4. Current: [$www_ips], VPS: [$CURRENT_PUBLIC_IP]"
      fatal "Fix www DNS or remove --www."
    fi
  fi

  success "DNS A record points to this VPS: $CURRENT_PUBLIC_IP"
}

backup_existing() {
  info "Checking existing files..."
  local stamp
  stamp="$(date +%Y%m%d-%H%M%S)"

  if [[ -d "$INSTALL_DIR" && -n "$(ls -A "$INSTALL_DIR" 2>/dev/null || true)" ]]; then
    if [[ "$FORCE_INSTALL" -ne 1 ]]; then
      fatal "$INSTALL_DIR is not empty. Use --force to backup and overwrite."
    fi
    local dst="$BACKUP_DIR/wordpress-files-$stamp"
    info "Backing up existing install dir to $dst ..."
    mkdir -p "$dst"
    rsync -a "$INSTALL_DIR/" "$dst/"
    rm -rf "$INSTALL_DIR"
  fi

  if [[ -f "/etc/nginx/sites-available/$DOMAIN" ]]; then
    cp -a "/etc/nginx/sites-available/$DOMAIN" "$BACKUP_DIR/nginx-$DOMAIN-$stamp.conf"
  fi
}

secure_mariadb_minimal() {
  info "Applying minimal MariaDB hardening..."
  mysql -uroot <<SQL
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
SQL
  success "MariaDB minimal hardening done."
}

create_database() {
  info "Creating MariaDB database and user..."
  mysql -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL
  success "Database ready."
}

install_wp_cli() {
  if command -v wp >/dev/null 2>&1; then
    success "WP-CLI already installed: $(wp --version --allow-root 2>/dev/null || wp --version 2>/dev/null || true)"
    return 0
  fi

  info "Installing WP-CLI..."
  curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp
  chmod +x /usr/local/bin/wp
  wp --info --allow-root >/dev/null
  success "WP-CLI installed: $(wp --version --allow-root)"
}

configure_php() {
  info "Configuring PHP ${PHP_VERSION}..."
  local fpm_ini="/etc/php/${PHP_VERSION}/fpm/php.ini"
  local cli_ini="/etc/php/${PHP_VERSION}/cli/php.ini"
  local pool_conf="/etc/php/${PHP_VERSION}/fpm/pool.d/www.conf"
  local opcache_ini="/etc/php/${PHP_VERSION}/mods-available/opcache.ini"

  cp -a "$fpm_ini" "$BACKUP_DIR/php-fpm-php.ini.$(date +%Y%m%d-%H%M%S)" || true

  sed -i \
    -e 's/^upload_max_filesize = .*/upload_max_filesize = 128M/' \
    -e 's/^post_max_size = .*/post_max_size = 128M/' \
    -e 's/^memory_limit = .*/memory_limit = 256M/' \
    -e 's/^max_execution_time = .*/max_execution_time = 300/' \
    -e 's/^max_input_time = .*/max_input_time = 300/' \
    -e 's/^;cgi.fix_pathinfo=.*/cgi.fix_pathinfo=0/' \
    -e 's/^expose_php = .*/expose_php = Off/' \
    "$fpm_ini"

  sed -i \
    -e 's/^memory_limit = .*/memory_limit = 256M/' \
    -e 's/^max_execution_time = .*/max_execution_time = 300/' \
    "$cli_ini"

  cat > "$opcache_ini" <<OPCACHE
zend_extension=opcache.so
opcache.enable=1
opcache.enable_cli=1
opcache.memory_consumption=192
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
opcache.validate_timestamps=1
opcache.revalidate_freq=60
opcache.jit=0
OPCACHE

  # Use dynamic process manager with moderate defaults for small VPS.
  sed -i \
    -e 's/^pm = .*/pm = dynamic/' \
    -e 's/^pm.max_children = .*/pm.max_children = 20/' \
    -e 's/^pm.start_servers = .*/pm.start_servers = 3/' \
    -e 's/^pm.min_spare_servers = .*/pm.min_spare_servers = 2/' \
    -e 's/^pm.max_spare_servers = .*/pm.max_spare_servers = 6/' \
    -e 's/^;pm.max_requests = .*/pm.max_requests = 500/' \
    "$pool_conf"

  systemctl restart php${PHP_VERSION}-fpm
  success "PHP configured."
}

configure_nginx_http() {
  info "Writing Nginx HTTP vhost..."
  mkdir -p "$INSTALL_DIR"
  chown -R www-data:www-data "$INSTALL_DIR"

  local server_names="$DOMAIN"
  [[ "$ENABLE_WWW" -eq 1 ]] && server_names="$server_names www.$DOMAIN"

  cat > "/etc/nginx/sites-available/$DOMAIN" <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name ${server_names};

    root ${INSTALL_DIR};
    index index.php index.html index.htm;

    access_log /var/log/nginx/${DOMAIN}.access.log;
    error_log  /var/log/nginx/${DOMAIN}.error.log warn;

    client_max_body_size 128M;
    include /etc/nginx/snippets/wp-security-headers.conf;

    location /.well-known/acme-challenge/ {
        root ${INSTALL_DIR};
        allow all;
    }

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_read_timeout 300;
    }

    location ~* /(?:uploads|files)/.*\.php$ {
        deny all;
    }

    location ~* \.(?:css|js|jpg|jpeg|gif|png|webp|avif|svg|ico|ttf|otf|woff|woff2)$ {
        expires 30d;
        access_log off;
        add_header Cache-Control "public, no-transform";
        try_files \$uri =404;
    }

    location ~ /\. {
        deny all;
    }

    location = /xmlrpc.php {
        # WordPress mobile app / Jetpack may need this.
        # Uncomment the next line if you want to disable XML-RPC completely.
        # deny all;
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
        include fastcgi_params;
    }
}
NGINX

  ln -sfn "/etc/nginx/sites-available/$DOMAIN" "/etc/nginx/sites-enabled/$DOMAIN"
  rm -f /etc/nginx/sites-enabled/default
  nginx -t
  systemctl reload nginx
  success "Nginx HTTP vhost ready."
}

install_wordpress() {
  info "Downloading and installing WordPress..."
  mkdir -p "$INSTALL_DIR"
  chown -R www-data:www-data "$INSTALL_DIR"

  wp core download --path="$INSTALL_DIR" --locale="$LOCALE" --allow-root --force

  if [[ ! -f "$INSTALL_DIR/wp-config.php" ]]; then
    wp config create \
      --path="$INSTALL_DIR" \
      --dbname="$DB_NAME" \
      --dbuser="$DB_USER" \
      --dbpass="$DB_PASS" \
      --dbhost="localhost" \
      --dbcharset="utf8mb4" \
      --dbcollate="utf8mb4_unicode_ci" \
      --allow-root \
      --force
  fi

  local url="http://$DOMAIN"
  if [[ "$ENABLE_SSL" -eq 1 ]]; then
    # URL will be switched after SSL succeeds.
    url="http://$DOMAIN"
  fi

  if ! wp core is-installed --path="$INSTALL_DIR" --allow-root >/dev/null 2>&1; then
    wp core install \
      --path="$INSTALL_DIR" \
      --url="$url" \
      --title="$SITE_TITLE" \
      --admin_user="$ADMIN_USER" \
      --admin_password="$ADMIN_PASS" \
      --admin_email="$ADMIN_EMAIL" \
      --skip-email \
      --allow-root
  else
    warn "WordPress already installed in $INSTALL_DIR. Skipping core install."
  fi

  wp option update permalink_structure '/%postname%/' --path="$INSTALL_DIR" --allow-root >/dev/null
  wp rewrite flush --path="$INSTALL_DIR" --allow-root >/dev/null || true

  # Basic wp-config hardening and performance constants.
  wp config set DISALLOW_FILE_EDIT true --type=constant --path="$INSTALL_DIR" --allow-root >/dev/null || true
  wp config set WP_MEMORY_LIMIT '256M' --type=constant --path="$INSTALL_DIR" --allow-root >/dev/null || true
  wp config set WP_MAX_MEMORY_LIMIT '512M' --type=constant --path="$INSTALL_DIR" --allow-root >/dev/null || true
  wp config set FS_METHOD 'direct' --type=constant --path="$INSTALL_DIR" --allow-root >/dev/null || true
  wp config set WP_POST_REVISIONS 10 --raw --type=constant --path="$INSTALL_DIR" --allow-root >/dev/null || true
  wp config set AUTOSAVE_INTERVAL 120 --raw --type=constant --path="$INSTALL_DIR" --allow-root >/dev/null || true

  chown -R www-data:www-data "$INSTALL_DIR"
  find "$INSTALL_DIR" -type d -exec chmod 755 {} \;
  find "$INSTALL_DIR" -type f -exec chmod 644 {} \;
  chmod 640 "$INSTALL_DIR/wp-config.php"

  success "WordPress installed."
}

configure_redis_wordpress() {
  if [[ "$ENABLE_REDIS" -ne 1 ]]; then
    return 0
  fi

  info "Configuring Redis object cache for WordPress..."
  systemctl restart redis-server || true
  wp config set WP_CACHE true --raw --type=constant --path="$INSTALL_DIR" --allow-root >/dev/null || true
  wp config set WP_REDIS_HOST '127.0.0.1' --type=constant --path="$INSTALL_DIR" --allow-root >/dev/null || true
  wp config set WP_REDIS_PORT 6379 --raw --type=constant --path="$INSTALL_DIR" --allow-root >/dev/null || true
  wp plugin install redis-cache --activate --path="$INSTALL_DIR" --allow-root || true
  wp redis enable --path="$INSTALL_DIR" --allow-root || true
  chown -R www-data:www-data "$INSTALL_DIR/wp-content" || true
  success "Redis object cache configured."
}

obtain_ssl() {
  if [[ "$ENABLE_SSL" -ne 1 ]]; then
    warn "SSL disabled by --no-ssl."
    return 0
  fi

  info "Requesting Let's Encrypt certificate..."
  local domains_args=( -d "$DOMAIN" )
  if [[ "$ENABLE_WWW" -eq 1 ]]; then
    domains_args+=( -d "www.$DOMAIN" )
  fi

  certbot --nginx \
    "${domains_args[@]}" \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    --redirect \
    --keep-until-expiring

  wp option update home "https://$DOMAIN" --path="$INSTALL_DIR" --allow-root >/dev/null || true
  wp option update siteurl "https://$DOMAIN" --path="$INSTALL_DIR" --allow-root >/dev/null || true
  wp search-replace "http://$DOMAIN" "https://$DOMAIN" --path="$INSTALL_DIR" --skip-columns=guid --allow-root || true

  systemctl reload nginx
  certbot renew --dry-run || warn "Certbot dry-run failed. Certificate may still be installed, but check renew manually."
  success "HTTPS enabled for $DOMAIN."
}

write_security_headers_optional() {
  # Keep this conservative. HSTS is intentionally not forced in v1.0 to avoid locking mistakes.
  local conf="/etc/nginx/snippets/wp-security-headers.conf"
  cat > "$conf" <<'HEADERS'
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
# HSTS is intentionally disabled by default. Enable only after HTTPS is confirmed stable.
# add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
HEADERS
}

create_backup_script() {
  info "Creating backup helper script..."
  local helper="/usr/local/sbin/wp-backup-$DOMAIN.sh"
  cat > "$helper" <<BACKUP
#!/usr/bin/env bash
set -Eeuo pipefail
BACKUP_BASE="/root/wp-backups/$DOMAIN"
STAMP="\$(date +%Y%m%d-%H%M%S)"
mkdir -p "\$BACKUP_BASE"
mysqldump --single-transaction --quick --lock-tables=false "$DB_NAME" | gzip > "\$BACKUP_BASE/db-\$STAMP.sql.gz"
tar -C "$(dirname "$INSTALL_DIR")" -czf "\$BACKUP_BASE/files-\$STAMP.tar.gz" "$(basename "$INSTALL_DIR")"
find "\$BACKUP_BASE" -type f -mtime +14 -delete
BACKUP
  chmod +x "$helper"

  cat > "/etc/cron.d/wp-backup-$DOMAIN" <<CRON
# Daily WordPress backup for $DOMAIN
17 3 * * * root $helper >/var/log/wp-oneclick/backup-$DOMAIN.log 2>&1
CRON
  success "Backup helper created: $helper"
}

write_summary() {
  local scheme="http"
  [[ "$ENABLE_SSL" -eq 1 ]] && scheme="https"

  local summary_file="/root/wp-oneclick-$DOMAIN.txt"
  cat > "$summary_file" <<SUMMARY
WordPress One-Click Install Summary
Generated: $(date -Is)
Script version: $SCRIPT_VERSION

Site URL:      ${scheme}://${DOMAIN}
Admin URL:     ${scheme}://${DOMAIN}/wp-admin/
Install dir:   ${INSTALL_DIR}
Nginx config:  /etc/nginx/sites-available/${DOMAIN}
Log file:      ${LOG_FILE}

WordPress admin user:     ${ADMIN_USER}
WordPress admin password: ${ADMIN_PASS}
WordPress admin email:    ${ADMIN_EMAIL}

Database name: ${DB_NAME}
Database user: ${DB_USER}
Database pass: ${DB_PASS}

Backup helper: /usr/local/sbin/wp-backup-${DOMAIN}.sh
Backup cron:   /etc/cron.d/wp-backup-${DOMAIN}
Backup dir:    /root/wp-backups/${DOMAIN}

Useful commands:
  nginx -t && systemctl reload nginx
  systemctl status nginx php${PHP_VERSION}-fpm mariadb
  certbot certificates
  certbot renew --dry-run
  wp core update --path=${INSTALL_DIR} --allow-root
  wp plugin update --all --path=${INSTALL_DIR} --allow-root
  wp theme update --all --path=${INSTALL_DIR} --allow-root
SUMMARY
  chmod 600 "$summary_file"

  echo
  success "Installation completed."
  echo -e "${GREEN}Site:${NC}      ${scheme}://${DOMAIN}"
  echo -e "${GREEN}Admin:${NC}     ${scheme}://${DOMAIN}/wp-admin/"
  echo -e "${GREEN}User:${NC}      ${ADMIN_USER}"
  echo -e "${GREEN}Password:${NC}  ${ADMIN_PASS}"
  echo -e "${GREEN}Summary:${NC}   ${summary_file}"
  echo -e "${GREEN}Log:${NC}       ${LOG_FILE}"
  echo
  warn "Please save the admin/database passwords from: $summary_file"
}

main() {
  parse_args "$@"
  require_root
  check_os
  prompt_if_needed
  install_base_packages
  configure_ufw
  check_dns
  backup_existing
  secure_mariadb_minimal
  create_database
  install_wp_cli
  configure_php
  write_security_headers_optional
  configure_nginx_http
  install_wordpress
  configure_redis_wordpress
  obtain_ssl
  create_backup_script
  write_summary
}

main "$@"
