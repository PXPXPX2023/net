#!/usr/bin/env bash
# =============================================================================
#  GPC2.SH — 中国股票数据看板 一键部署脚本
#  域名: gpc.230139.xyz  端口: 16666  快捷键: gpc
#  功能: Docker + Streamlit + HTTPS(自签或Let's Encrypt) + 用户管理 + IP审计
#  数据源: AKShare + 东方财富 + 新浪财经 + 同花顺
# =============================================================================

set -euo pipefail
SCRIPT_VERSION="2.0.0"
DOMAIN="gpc.230139.xyz"
PORT=16666
APP_DIR="/opt/gpc-dashboard"
DATA_DIR="${APP_DIR}/data"
LOG_DIR="${APP_DIR}/logs"
CERT_DIR="${APP_DIR}/certs"
NGINX_CONF="${APP_DIR}/nginx.conf"
COMPOSE_FILE="${APP_DIR}/docker-compose.yml"
ENV_FILE="${APP_DIR}/.env"
USERS_FILE="${DATA_DIR}/users.json"
ACCESS_LOG="${LOG_DIR}/access.log"
SHORTCUT_NAME="gpc"

# ─── 颜色定义 ────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
header()  { echo -e "\n${BOLD}${BLUE}══════════════════════════════════════════${NC}"; echo -e "${BOLD}${BLUE}  $*${NC}"; echo -e "${BOLD}${BLUE}══════════════════════════════════════════${NC}\n"; }

# =============================================================================
#  SECTION 1 — 环境检测与依赖安装
# =============================================================================
check_root() {
    [[ $EUID -eq 0 ]] || error "请以 root 用户执行此脚本: sudo bash gpc2.sh"
}

detect_os() {
    if [[ -f /etc/debian_version ]]; then
        OS="debian"
        PKG_MGR="apt-get"
        PKG_INSTALL="apt-get install -y -q"
    elif [[ -f /etc/redhat-release ]]; then
        OS="rhel"
        PKG_MGR="yum"
        PKG_INSTALL="yum install -y -q"
    else
        error "不支持的操作系统，仅支持 Debian/Ubuntu/CentOS/RHEL"
    fi
    info "检测到系统: ${OS}"
}

install_docker() {
    if command -v docker &>/dev/null; then
        success "Docker 已安装: $(docker --version)"
        return
    fi
    header "安装 Docker"
    if [[ "${OS}" == "debian" ]]; then
        apt-get update -q
        apt-get install -y -q ca-certificates curl gnupg lsb-release
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
            | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null \
            || curl -fsSL https://download.docker.com/linux/debian/gpg \
            | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
        DIST=$(. /etc/os-release && echo "$ID")
        CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${DIST} ${CODENAME} stable" \
            > /etc/apt/sources.list.d/docker.list
        apt-get update -q
        apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-compose-plugin
    else
        yum install -y -q yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y -q docker-ce docker-ce-cli containerd.io docker-compose-plugin
    fi
    systemctl enable --now docker
    success "Docker 安装完成: $(docker --version)"
}

install_docker_compose() {
    if docker compose version &>/dev/null 2>&1; then
        success "Docker Compose (plugin) 已就绪"
        COMPOSE_CMD="docker compose"
        return
    fi
    if command -v docker-compose &>/dev/null; then
        success "docker-compose 已安装"
        COMPOSE_CMD="docker-compose"
        return
    fi
    info "安装 docker-compose standalone..."
    COMPOSE_VER="v2.24.6"
    ARCH=$(uname -m)
    [[ "${ARCH}" == "x86_64" ]] && ARCH="x86_64"
    [[ "${ARCH}" == "aarch64" ]] && ARCH="aarch64"
    curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VER}/docker-compose-linux-${ARCH}" \
        -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    COMPOSE_CMD="docker-compose"
    success "docker-compose 安装完成"
}

install_system_deps() {
    header "安装系统依赖"
    if [[ "${OS}" == "debian" ]]; then
        apt-get update -q
        apt-get install -y -q \
            openssl curl wget jq python3 python3-pip \
            net-tools ufw htop nano 2>/dev/null || true
    else
        yum install -y -q openssl curl wget jq python3 python3-pip \
            net-tools firewalld htop nano 2>/dev/null || true
    fi
    success "系统依赖安装完成"
}

# =============================================================================
#  SECTION 2 — 目录与配置文件创建
# =============================================================================
create_directories() {
    header "创建目录结构"
    mkdir -p "${APP_DIR}" "${DATA_DIR}" "${LOG_DIR}" "${CERT_DIR}"
    mkdir -p "${APP_DIR}/app"
    mkdir -p "${APP_DIR}/nginx"
    success "目录结构: ${APP_DIR}"
}

generate_self_signed_cert() {
    info "生成自签名 TLS 证书 (${DOMAIN})..."
    openssl req -x509 -nodes -days 3650 \
        -newkey rsa:4096 \
        -keyout "${CERT_DIR}/privkey.pem" \
        -out    "${CERT_DIR}/fullchain.pem" \
        -subj   "/C=CN/ST=Beijing/L=Beijing/O=GPC/CN=${DOMAIN}" \
        -addext "subjectAltName=DNS:${DOMAIN},DNS:localhost,IP:127.0.0.1" \
        2>/dev/null
    chmod 600 "${CERT_DIR}/privkey.pem"
    success "自签名证书已生成 (有效期10年)"
}

try_letsencrypt_cert() {
    info "尝试申请 Let's Encrypt 证书..."
    if ! command -v certbot &>/dev/null; then
        if [[ "${OS}" == "debian" ]]; then
            apt-get install -y -q certbot 2>/dev/null || { warn "certbot 安装失败，使用自签名证书"; return 1; }
        else
            yum install -y -q certbot 2>/dev/null || { warn "certbot 安装失败，使用自签名证书"; return 1; }
        fi
    fi
    # 检测域名是否解析到本机
    LOCAL_IP=$(curl -4 -s ifconfig.me 2>/dev/null || curl -4 -s icanhazip.com 2>/dev/null || echo "")
    DOMAIN_IP=$(getent hosts "${DOMAIN}" | awk '{print $1}' 2>/dev/null || dig +short "${DOMAIN}" 2>/dev/null | head -1 || echo "")
    if [[ "${LOCAL_IP}" != "${DOMAIN_IP}" ]]; then
        warn "域名 ${DOMAIN} 未解析到本机 IP (本机: ${LOCAL_IP}, 域名: ${DOMAIN_IP})"
        warn "跳过 Let's Encrypt，使用自签名证书"
        return 1
    fi
    # 临时停 80 端口（如占用）
    certbot certonly --standalone \
        --non-interactive --agree-tos \
        --email "admin@${DOMAIN}" \
        -d "${DOMAIN}" \
        --http-01-port 8880 2>/dev/null && {
        ln -sf "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" "${CERT_DIR}/fullchain.pem"
        ln -sf "/etc/letsencrypt/live/${DOMAIN}/privkey.pem"   "${CERT_DIR}/privkey.pem"
        success "Let's Encrypt 证书申请成功"
        return 0
    } || {
        warn "Let's Encrypt 申请失败，使用自签名证书"
        return 1
    }
}

setup_certificates() {
    header "配置 TLS 证书"
    try_letsencrypt_cert || generate_self_signed_cert
}

# =============================================================================
#  SECTION 3 — 生成随机密钥与初始用户
# =============================================================================
generate_secrets() {
    header "生成安全密钥"
    SECRET_KEY=$(openssl rand -hex 32)
    ADMIN_PASS=$(openssl rand -base64 12 | tr -d '/+=' | head -c 12)
    # 使用 Python 生成 bcrypt hash（若有）或 sha256
    ADMIN_HASH=$(python3 -c "
import hashlib, sys
pw = '${ADMIN_PASS}'
print(hashlib.sha256(pw.encode()).hexdigest())
" 2>/dev/null || echo "$(echo -n "${ADMIN_PASS}" | sha256sum | cut -d' ' -f1)")

    # 初始化用户文件
    cat > "${USERS_FILE}" << USERJSON
{
  "users": [
    {
      "username": "admin",
      "password_hash": "${ADMIN_HASH}",
      "role": "admin",
      "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
      "last_login": null,
      "enabled": true
    }
  ]
}
USERJSON

    # 写入环境变量文件
    cat > "${ENV_FILE}" << ENVEOF
SECRET_KEY=${SECRET_KEY}
ADMIN_PASS=${ADMIN_PASS}
DOMAIN=${DOMAIN}
PORT=${PORT}
APP_DIR=${APP_DIR}
ENVEOF
    chmod 600 "${ENV_FILE}" "${USERS_FILE}"
    success "管理员账号: admin / ${ADMIN_PASS}"
    warn "请保存上述密码！安装完成后不再显示"
}

# =============================================================================
#  SECTION 4 — Nginx 反向代理配置
# =============================================================================
write_nginx_conf() {
    header "写入 Nginx 配置"
    cat > "${APP_DIR}/nginx/nginx.conf" << 'NGINXEOF'
user  nginx;
worker_processes  auto;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  4096;
    use epoll;
    multi_accept on;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main_ext  '$remote_addr - $remote_user [$time_local] '
                           '"$request" $status $body_bytes_sent '
                           '"$http_referer" "$http_user_agent" '
                           'rt=$request_time ua="$upstream_addr"';

    access_log  /var/log/nginx/access.log  main_ext;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    keepalive_timeout  75s;
    client_max_body_size 32m;
    server_tokens off;
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
    gzip_min_length 1024;

    # Rate limiting: 防止爬取
    limit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;
    limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

    # HTTP → HTTPS 重定向 (非标准端口)
    server {
        listen 8080;
        server_name _;
        return 301 https://$host:GPC_PORT$request_uri;
    }

    # 主 HTTPS 服务
    server {
        listen GPC_PORT ssl http2;
        server_name GPC_DOMAIN localhost;

        ssl_certificate     /etc/nginx/certs/fullchain.pem;
        ssl_certificate_key /etc/nginx/certs/privkey.pem;
        ssl_protocols       TLSv1.2 TLSv1.3;
        ssl_ciphers         ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256;
        ssl_prefer_server_ciphers off;
        ssl_session_cache   shared:SSL:10m;
        ssl_session_timeout 1d;
        ssl_session_tickets off;
        add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;
        add_header X-Frame-Options DENY always;
        add_header X-Content-Type-Options nosniff always;

        # WebSocket 支持 (Streamlit)
        location /_stcore/stream {
            proxy_pass         http://streamlit:8501/_stcore/stream;
            proxy_http_version 1.1;
            proxy_set_header   Upgrade $http_upgrade;
            proxy_set_header   Connection "upgrade";
            proxy_set_header   Host $host;
            proxy_set_header   X-Real-IP $remote_addr;
            proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_read_timeout 86400s;
            proxy_send_timeout 86400s;
        }

        location / {
            proxy_pass         http://streamlit:8501;
            proxy_http_version 1.1;
            proxy_set_header   Upgrade $http_upgrade;
            proxy_set_header   Connection "upgrade";
            proxy_set_header   Host $host;
            proxy_set_header   X-Real-IP $remote_addr;
            proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header   X-Forwarded-Proto https;
            proxy_read_timeout 300s;
            proxy_connect_timeout 30s;
        }

        # 访问日志镜像到共享卷
        access_log /var/log/nginx/access.log main_ext;
    }
}
NGINXEOF
    # 替换占位符
    sed -i "s/GPC_PORT/${PORT}/g" "${APP_DIR}/nginx/nginx.conf"
    sed -i "s/GPC_DOMAIN/${DOMAIN}/g" "${APP_DIR}/nginx/nginx.conf"
    success "Nginx 配置写入完成"
}

# =============================================================================
#  SECTION 5 — Streamlit 应用主程序
# =============================================================================
write_streamlit_app() {
    header "写入 Streamlit 应用代码"

    # ── 5.1 依赖清单 ────────────────────────────────────────────────────────
    cat > "${APP_DIR}/app/requirements.txt" << 'REQEOF'
streamlit==1.35.0
akshare>=1.14.0
pandas>=2.0.0
numpy>=1.24.0
plotly>=5.18.0
requests>=2.31.0
pytz>=2024.1
bcrypt>=4.1.0
python-dateutil>=2.8.2
streamlit-autorefresh>=1.0.1
schedule>=1.2.1
diskcache>=5.6.3
openpyxl>=3.1.2
REQEOF

    # ── 5.2 Streamlit 配置 ──────────────────────────────────────────────────
    mkdir -p "${APP_DIR}/app/.streamlit"
    cat > "${APP_DIR}/app/.streamlit/config.toml" << 'STCONF'
[server]
port = 8501
address = "0.0.0.0"
headless = true
enableCORS = false
enableXsrfProtection = false
maxUploadSize = 50

[browser]
serverAddress = "0.0.0.0"
serverPort = 8501
gatherUsageStats = false

[theme]
primaryColor = "#E63946"
backgroundColor = "#0D1117"
secondaryBackgroundColor = "#161B22"
textColor = "#C9D1D9"
font = "sans serif"

[runner]
fastReruns = true

[logger]
level = "warning"
STCONF

    # ── 5.3 工具模块 auth.py ────────────────────────────────────────────────
    cat > "${APP_DIR}/app/auth.py" << 'AUTHEOF'
"""
auth.py — 用户认证 + IP 审计模块
"""
import hashlib
import json
import os
import time
import streamlit as st
from datetime import datetime, timezone
from pathlib import Path

USERS_FILE = os.environ.get("USERS_FILE", "/app/data/users.json")
ACCESS_LOG  = os.environ.get("ACCESS_LOG",  "/app/logs/access.log")

# ── 工具函数 ────────────────────────────────────────────────────────────────
def _hash_pw(password: str) -> str:
    return hashlib.sha256(password.encode()).hexdigest()

def _load_users() -> dict:
    p = Path(USERS_FILE)
    if not p.exists():
        return {"users": []}
    with open(p, "r", encoding="utf-8") as f:
        return json.load(f)

def _save_users(data: dict):
    with open(USERS_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def _get_client_ip() -> str:
    """从 streamlit headers 尝试获取真实 IP"""
    try:
        headers = st.context.headers
        for key in ("x-real-ip", "x-forwarded-for", "cf-connecting-ip"):
            v = headers.get(key, "")
            if v:
                return v.split(",")[0].strip()
    except Exception:
        pass
    return "unknown"

def log_access(username: str, action: str, ip: str = ""):
    """写访问日志"""
    ip = ip or _get_client_ip()
    ts  = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    entry = f"[{ts}] user={username} action={action} ip={ip}\n"
    try:
        Path(ACCESS_LOG).parent.mkdir(parents=True, exist_ok=True)
        with open(ACCESS_LOG, "a", encoding="utf-8") as f:
            f.write(entry)
    except Exception:
        pass

# ── 认证核心 ────────────────────────────────────────────────────────────────
def verify_user(username: str, password: str) -> bool:
    data = _load_users()
    for u in data.get("users", []):
        if u["username"] == username and u.get("enabled", True):
            if u["password_hash"] == _hash_pw(password):
                # 更新最后登录时间
                u["last_login"] = datetime.now(timezone.utc).isoformat()
                _save_users(data)
                return True
    return False

def get_user_role(username: str) -> str:
    data = _load_users()
    for u in data.get("users", []):
        if u["username"] == username:
            return u.get("role", "viewer")
    return "viewer"

def login_page():
    """渲染登录页"""
    st.markdown("""
    <style>
    .login-box {
        max-width: 420px; margin: 80px auto;
        background: #161B22; border-radius: 12px;
        padding: 40px 36px; border: 1px solid #30363D;
        box-shadow: 0 8px 32px rgba(0,0,0,0.5);
    }
    .login-title { font-size: 2rem; font-weight: 700; color: #E63946;
        text-align: center; margin-bottom: 8px; }
    .login-sub { text-align: center; color: #8B949E; margin-bottom: 28px; font-size: 0.9rem; }
    </style>
    <div class="login-box">
    <div class="login-title">📈 GPC 看板</div>
    <div class="login-sub">中国金融数据监控系统</div>
    </div>
    """, unsafe_allow_html=True)

    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        st.markdown("### 🔐 登录")
        username = st.text_input("用户名", key="login_user", placeholder="请输入用户名")
        password = st.text_input("密码",   key="login_pass", type="password", placeholder="请输入密码")
        btn      = st.button("登 录", type="primary", use_container_width=True)

        if btn:
            if not username or not password:
                st.error("请填写用户名和密码")
                return
            ip = _get_client_ip()
            if verify_user(username, password):
                st.session_state["authenticated"] = True
                st.session_state["username"]      = username
                st.session_state["role"]          = get_user_role(username)
                st.session_state["login_ip"]      = ip
                log_access(username, "LOGIN_SUCCESS", ip)
                st.rerun()
            else:
                log_access(username, "LOGIN_FAILED", ip)
                st.error("用户名或密码错误")

def require_auth():
    """认证守卫 — 在每个页面顶部调用"""
    if not st.session_state.get("authenticated"):
        login_page()
        st.stop()

def logout():
    log_access(st.session_state.get("username","?"), "LOGOUT", st.session_state.get("login_ip",""))
    for k in ["authenticated","username","role","login_ip"]:
        st.session_state.pop(k, None)
    st.rerun()

# ── 用户管理（admin 专用）─────────────────────────────────────────────────
def admin_user_manager():
    st.subheader("👥 用户管理")
    data = _load_users()
    users = data.get("users", [])

    # 当前用户列表
    st.markdown("#### 现有用户")
    for i, u in enumerate(users):
        c1, c2, c3, c4, c5 = st.columns([2, 1.5, 1.5, 1.5, 1])
        c1.write(f"**{u['username']}**")
        c2.write(u.get("role","viewer"))
        c3.write("✅ 启用" if u.get("enabled",True) else "❌ 停用")
        c4.write(u.get("last_login","从未")[:19] if u.get("last_login") else "从未")
        with c5:
            if u["username"] != "admin":
                if st.button("删除", key=f"del_{i}"):
                    users.pop(i)
                    _save_users(data)
                    st.success(f"已删除 {u['username']}")
                    st.rerun()

    st.markdown("---")
    st.markdown("#### 添加新用户")
    n1, n2, n3, n4 = st.columns([2, 2, 1.5, 1])
    new_user = n1.text_input("用户名", key="new_uname")
    new_pass = n2.text_input("密码",   key="new_upass", type="password")
    new_role = n3.selectbox("权限", ["viewer","admin"], key="new_urole")
    if n4.button("添加", key="add_user"):
        if new_user and new_pass:
            if any(u["username"] == new_user for u in users):
                st.error("用户名已存在")
            else:
                users.append({
                    "username": new_user,
                    "password_hash": _hash_pw(new_pass),
                    "role": new_role,
                    "created_at": datetime.now(timezone.utc).isoformat(),
                    "last_login": None,
                    "enabled": True
                })
                _save_users(data)
                st.success(f"用户 {new_user} 添加成功")
                st.rerun()
        else:
            st.warning("请填写用户名和密码")

def admin_access_log():
    st.subheader("🌐 访问日志 (最近200条)")
    try:
        with open(ACCESS_LOG, "r", encoding="utf-8") as f:
            lines = f.readlines()
        recent = lines[-200:][::-1]
        st.code("".join(recent), language="text")
    except FileNotFoundError:
        st.info("暂无访问日志")
AUTHEOF

    # ── 5.4 数据获取模块 data_fetcher.py ────────────────────────────────────
    cat > "${APP_DIR}/app/data_fetcher.py" << 'DFEOF'
"""
data_fetcher.py — AKShare 数据拉取层（带缓存与降级）
所有公开接口均有 try/except，失败返回空 DataFrame，不崩溃主进程
"""
import time
import hashlib
import logging
from functools import wraps
from datetime import datetime
from typing import Optional

import pandas as pd
import akshare as ak
import diskcache as dc

logger = logging.getLogger(__name__)
CACHE_DIR = "/app/data/cache"
cache = dc.Cache(CACHE_DIR, size_limit=512 * 1024 * 1024)   # 512 MB

# ── 缓存装饰器 ───────────────────────────────────────────────────────────────
def cached(ttl: int = 60):
    """磁盘缓存装饰器，ttl 单位秒"""
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            key = f"gpc:{fn.__name__}:{hashlib.md5(str(args+tuple(sorted(kwargs.items()))).encode()).hexdigest()}"
            hit = cache.get(key)
            if hit is not None:
                return hit
            result = fn(*args, **kwargs)
            if result is not None and (not isinstance(result, pd.DataFrame) or not result.empty):
                cache.set(key, result, expire=ttl)
            return result
        return wrapper
    return decorator

def safe(fn):
    """安全包装，失败返回空 DataFrame"""
    @wraps(fn)
    def wrapper(*args, **kwargs):
        try:
            return fn(*args, **kwargs)
        except Exception as e:
            logger.warning(f"{fn.__name__} 失败: {e}")
            return pd.DataFrame()
    return wrapper

# ─────────────────────────────────────────────────────────────────────────────
#  A股实时行情 (东方财富)
# ─────────────────────────────────────────────────────────────────────────────
@safe
@cached(ttl=10)
def get_a_stock_spot() -> pd.DataFrame:
    """沪深京A股实时行情 — 东方财富"""
    df = ak.stock_zh_a_spot_em()
    if df.empty:
        return df
    # 统一列名
    rename_map = {
        "序号":"序号","代码":"代码","名称":"名称","最新价":"最新价",
        "涨跌幅":"涨跌幅%","涨跌额":"涨跌额","成交量":"成交量(手)",
        "成交额":"成交额(元)","振幅":"振幅%","最高":"最高","最低":"最低",
        "今开":"今开","昨收":"昨收","量比":"量比","换手率":"换手率%",
        "市盈率-动态":"PE(动)","市净率":"PB","总市值":"总市值(元)",
        "流通市值":"流通市值(元)","涨速":"涨速%","5分钟涨跌":"5min涨跌%",
        "60日涨跌幅":"60日涨跌%","年初至今涨跌幅":"年初至今%"
    }
    df.rename(columns={k:v for k,v in rename_map.items() if k in df.columns}, inplace=True)
    return df

# ─────────────────────────────────────────────────────────────────────────────
#  ETF 实时行情 (东方财富)
# ─────────────────────────────────────────────────────────────────────────────
@safe
@cached(ttl=15)
def get_etf_spot() -> pd.DataFrame:
    """场内ETF实时行情"""
    df = ak.fund_etf_spot_em()
    return df

@safe
@cached(ttl=300)
def get_etf_daily() -> pd.DataFrame:
    """ETF日行情（含净值、折溢价）"""
    return ak.fund_etf_fund_daily_em()

@safe
@cached(ttl=3600)
def get_new_etf_list() -> pd.DataFrame:
    """新发售ETF列表（上交所+深交所）"""
    try:
        df_sse = ak.fund_etf_scale_sse()
    except Exception:
        df_sse = pd.DataFrame()
    try:
        df_szse = ak.fund_etf_scale_szse()
    except Exception:
        df_szse = pd.DataFrame()
    frames = [f for f in [df_sse, df_szse] if not f.empty]
    if frames:
        return pd.concat(frames, ignore_index=True)
    return pd.DataFrame()

# ─────────────────────────────────────────────────────────────────────────────
#  基金数据
# ─────────────────────────────────────────────────────────────────────────────
@safe
@cached(ttl=300)
def get_fund_open_rank() -> pd.DataFrame:
    """开放式基金排行"""
    return ak.fund_open_fund_rank_em(symbol="全部")

@safe
@cached(ttl=3600)
def get_new_fund_list() -> pd.DataFrame:
    """新发基金列表"""
    try:
        return ak.fund_new_stock_rating_em()
    except Exception:
        return pd.DataFrame()

@safe
@cached(ttl=60)
def get_money_fund_daily() -> pd.DataFrame:
    """货币基金实时收益"""
    try:
        return ak.fund_money_fund_daily_em()
    except Exception:
        return pd.DataFrame()

# ─────────────────────────────────────────────────────────────────────────────
#  资金流向
# ─────────────────────────────────────────────────────────────────────────────
@safe
@cached(ttl=60)
def get_stock_fund_flow_individual(symbol: str) -> pd.DataFrame:
    """个股资金流向"""
    return ak.stock_individual_fund_flow(stock=symbol, market="sh" if symbol.startswith("6") else "sz")

@safe
@cached(ttl=60)
def get_market_fund_flow() -> pd.DataFrame:
    """大盘资金流向（东方财富）"""
    return ak.stock_market_fund_flow()

@safe
@cached(ttl=30)
def get_sector_fund_flow(sector: str = "行业资金流") -> pd.DataFrame:
    """行业/概念/地域资金流"""
    indicator_map = {
        "今日": "今日", "3日": "3日", "5日": "5日",
        "10日": "10日", "20日": "20日"
    }
    return ak.stock_sector_fund_flow_rank(symbol=sector, indicator="今日")

@safe
@cached(ttl=60)
def get_north_money_flow() -> pd.DataFrame:
    """北向资金（沪深港通）实时"""
    try:
        return ak.stock_hsgt_fund_flow_summary_em()
    except Exception:
        return pd.DataFrame()

# ─────────────────────────────────────────────────────────────────────────────
#  同花顺排名数据
# ─────────────────────────────────────────────────────────────────────────────
@safe
@cached(ttl=60)
def get_ths_rank_create_high() -> pd.DataFrame:
    """同花顺-创新高"""
    return ak.stock_rank_cxg_ths()

@safe
@cached(ttl=60)
def get_ths_rank_lxsz() -> pd.DataFrame:
    """同花顺-连续上涨"""
    return ak.stock_rank_lxsz_ths()

@safe
@cached(ttl=60)
def get_ths_rank_cxfl() -> pd.DataFrame:
    """同花顺-持续放量"""
    return ak.stock_rank_cxfl_ths()

@safe
@cached(ttl=60)
def get_ths_rank_ljqs() -> pd.DataFrame:
    """同花顺-量价齐升"""
    return ak.stock_rank_ljqs_ths()

# ─────────────────────────────────────────────────────────────────────────────
#  自选股 1分钟分时数据
# ─────────────────────────────────────────────────────────────────────────────
@safe
def get_stock_1min(symbol: str) -> pd.DataFrame:
    """自选股1分钟分时行情 — 东方财富（不缓存，每次实时）"""
    # symbol 格式: "000001"
    df = ak.stock_intraday_em(symbol=symbol)
    return df

@safe
def get_stock_1min_sina(symbol: str) -> pd.DataFrame:
    """自选股1分钟分时行情 — 新浪（备用）"""
    prefix = "sh" if symbol.startswith("6") else "sz"
    df = ak.stock_zh_a_minute(symbol=f"{prefix}{symbol}", period="1", adjust="")
    return df

# ─────────────────────────────────────────────────────────────────────────────
#  行业板块
# ─────────────────────────────────────────────────────────────────────────────
@safe
@cached(ttl=60)
def get_sector_spot() -> pd.DataFrame:
    """行业板块实时行情"""
    return ak.stock_board_industry_name_em()

@safe
@cached(ttl=60)
def get_concept_spot() -> pd.DataFrame:
    """概念板块实时行情"""
    return ak.stock_board_concept_name_em()

# ─────────────────────────────────────────────────────────────────────────────
#  指数行情
# ─────────────────────────────────────────────────────────────────────────────
@safe
@cached(ttl=10)
def get_index_spot() -> pd.DataFrame:
    """主要指数实时行情"""
    return ak.stock_zh_index_spot_em()

@safe
@cached(ttl=10)
def get_index_spot_sina() -> pd.DataFrame:
    """新浪-A股指数实时行情（备用）"""
    return ak.stock_zh_index_spot_sina(symbol="沪深重要指数")

# ─────────────────────────────────────────────────────────────────────────────
#  市场概览
# ─────────────────────────────────────────────────────────────────────────────
@safe
@cached(ttl=60)
def get_market_activity() -> pd.DataFrame:
    """市场情绪——涨跌家数统计"""
    return ak.stock_market_activity_legu()

def is_trading_time() -> bool:
    """判断当前是否为A股交易时间（中国时区）"""
    import pytz
    tz = pytz.timezone("Asia/Shanghai")
    now = datetime.now(tz)
    if now.weekday() >= 5:
        return False
    t = now.time()
    from datetime import time as dtime
    morning   = dtime(9, 30) <= t <= dtime(11, 30)
    afternoon = dtime(13, 0) <= t <= dtime(15, 0)
    return morning or afternoon
DFEOF

    # ── 5.5 主应用 app.py ───────────────────────────────────────────────────
    cat > "${APP_DIR}/app/app.py" << 'APPEOF'
"""
GPC 中国金融数据看板 — 主程序
域名: gpc.230139.xyz  端口: 16666
"""
import os
import sys
import time
import json
import logging
from datetime import datetime

import pandas as pd
import numpy as np
import plotly.graph_objects as go
import plotly.express as px
import streamlit as st
from streamlit_autorefresh import st_autorefresh

# 本地模块
sys.path.insert(0, "/app")
from auth import require_auth, logout, admin_user_manager, admin_access_log, log_access
import data_fetcher as df_mod

logging.basicConfig(level=logging.WARNING)

# ─────────────────────────────────────────────────────────────────────────────
#  页面初始化
# ─────────────────────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="GPC 金融看板",
    page_icon="📈",
    layout="wide",
    initial_sidebar_state="expanded",
    menu_items={"Get Help": None, "Report a bug": None, "About": "GPC Stock Dashboard v2.0"}
)

# 注入全局 CSS
st.markdown("""
<style>
/* 主题色调 */
:root {
    --up-color: #00C896;
    --down-color: #FF3B30;
    --neutral-color: #8B949E;
    --card-bg: #161B22;
    --border-color: #30363D;
}
/* 全局背景 */
.main { background-color: #0D1117; }
.stApp { background-color: #0D1117; }
/* 指标卡片 */
.metric-card {
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: 8px;
    padding: 16px;
    text-align: center;
    margin: 4px 0;
}
.metric-card .label { font-size: 0.82rem; color: var(--neutral-color); margin-bottom: 6px; }
.metric-card .value { font-size: 1.5rem; font-weight: 700; }
.up   { color: var(--up-color) !important; }
.down { color: var(--down-color) !important; }
/* 隐藏 streamlit 品牌 */
#MainMenu { visibility: hidden; }
footer    { visibility: hidden; }
/* 侧边栏 */
[data-testid="stSidebar"] { background: #0D1117; border-right: 1px solid #30363D; }
/* 表格 */
.stDataFrame { background: #161B22 !important; }
/* 标签页 */
.stTabs [data-baseweb="tab"] { color: #8B949E; }
.stTabs [aria-selected="true"] { color: #E63946 !important; border-bottom: 2px solid #E63946; }
/* 刷新时钟 */
.refresh-bar { background: #161B22; padding: 6px 16px; border-radius: 6px;
    border: 1px solid #30363D; font-size: 0.8rem; color: #8B949E; }
</style>
""", unsafe_allow_html=True)

# ─────────────────────────────────────────────────────────────────────────────
#  认证守卫
# ─────────────────────────────────────────────────────────────────────────────
require_auth()
log_access(st.session_state.get("username","?"), "PAGE_VIEW")

# ─────────────────────────────────────────────────────────────────────────────
#  侧边栏 — 导航 + 自选股管理
# ─────────────────────────────────────────────────────────────────────────────
with st.sidebar:
    st.markdown(f"""
    <div style='text-align:center; padding: 12px 0;'>
        <div style='font-size:1.6rem; font-weight:800; color:#E63946;'>📈 GPC 看板</div>
        <div style='font-size:0.75rem; color:#8B949E; margin-top:4px;'>
            用户: {st.session_state.get("username","?")} | {st.session_state.get("role","viewer")}
        </div>
    </div>
    """, unsafe_allow_html=True)
    st.markdown("---")

    # 导航
    PAGE_OPTIONS = {
        "🏠 市场总览":      "overview",
        "📊 全部A股":       "all_stocks",
        "🔮 ETF 行情":      "etf",
        "💼 基金数据":      "fund",
        "⭐ 自选股":        "watchlist",
        "💰 资金流向":      "fund_flow",
        "🏭 板块行情":      "sector",
        "🏆 同花顺排名":    "ths_rank",
        "🆕 新发ETF/基金":  "new_products",
    }
    if st.session_state.get("role") == "admin":
        PAGE_OPTIONS["⚙️ 系统管理"] = "admin"

    page_label = st.radio("导航", list(PAGE_OPTIONS.keys()), key="nav_page", label_visibility="collapsed")
    page = PAGE_OPTIONS[page_label]

    st.markdown("---")
    # 自动刷新控制
    auto_refresh = st.checkbox("🔄 自动刷新", value=True, key="auto_refresh")
    refresh_interval = st.select_slider(
        "刷新间隔(秒)", options=[5, 10, 15, 30, 60], value=15, key="refresh_interval"
    )

    st.markdown("---")
    # 自选股管理
    st.markdown("**⭐ 我的自选股**")
    if "watchlist" not in st.session_state:
        st.session_state["watchlist"] = ["000001", "600036", "300750", "510300", "159915"]
    wl_input = st.text_input("添加股票代码", placeholder="如 000001", key="wl_input")
    if st.button("➕ 添加", key="wl_add"):
        code = wl_input.strip().zfill(6)
        if code and code not in st.session_state["watchlist"]:
            st.session_state["watchlist"].append(code)
            st.rerun()
    # 显示并删除
    wl = st.session_state["watchlist"]
    for i, code in enumerate(wl):
        c1, c2 = st.columns([3, 1])
        c1.caption(code)
        if c2.button("✕", key=f"wl_del_{i}"):
            wl.pop(i)
            st.rerun()

    st.markdown("---")
    if st.button("🚪 退出登录", use_container_width=True):
        logout()

# 自动刷新
if auto_refresh:
    st_autorefresh(interval=refresh_interval * 1000, key="autorefresher")

# ─────────────────────────────────────────────────────────────────────────────
#  辅助函数
# ─────────────────────────────────────────────────────────────────────────────
def color_pct(val):
    try:
        v = float(str(val).replace("%",""))
        if v > 0:   return "color: #00C896"
        elif v < 0: return "color: #FF3B30"
    except Exception:
        pass
    return ""

def fmt_large(n):
    """格式化大数字"""
    try:
        n = float(n)
        if n >= 1e8:   return f"{n/1e8:.2f}亿"
        if n >= 1e4:   return f"{n/1e4:.2f}万"
        return f"{n:.2f}"
    except Exception:
        return str(n)

def trading_status_badge():
    is_trading = df_mod.is_trading_time()
    color = "#00C896" if is_trading else "#FF3B30"
    text  = "交易中 🟢" if is_trading else "休市 🔴"
    now_cn = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    st.markdown(f"""
    <div class='refresh-bar'>
        <span style='color:{color};font-weight:600;'>{text}</span>
        &nbsp;&nbsp;|&nbsp;&nbsp;
        {now_cn} (北京时间)
        &nbsp;&nbsp;|&nbsp;&nbsp;
        刷新: {refresh_interval}s
    </div>
    """, unsafe_allow_html=True)

def render_df(df: pd.DataFrame, pct_cols=None, fmt_cols=None, height=400):
    """带颜色的 DataFrame 渲染"""
    if df.empty:
        st.info("暂无数据")
        return
    styler = df.style
    if pct_cols:
        for col in pct_cols:
            if col in df.columns:
                styler = styler.applymap(color_pct, subset=[col])
    st.dataframe(styler, height=height, use_container_width=True)

# ─────────────────────────────────────────────────────────────────────────────
#  PAGE: 市场总览
# ─────────────────────────────────────────────────────────────────────────────
def page_overview():
    st.title("🏠 市场总览")
    trading_status_badge()
    st.markdown("")

    # ── 指数行情卡片 ─────────────────────────────────────────────────────────
    st.markdown("#### 主要指数")
    idx_df = df_mod.get_index_spot()
    key_indices = {
        "000001": "上证指数", "399001": "深证成指", "399006": "创业板指",
        "000300": "沪深300",  "000905": "中证500",  "000852": "中证1000",
        "HSI":    "恒生指数"
    }
    if not idx_df.empty:
        cols = st.columns(min(7, len(key_indices)))
        code_col = "代码" if "代码" in idx_df.columns else idx_df.columns[0]
        price_col = next((c for c in idx_df.columns if "最新" in c or "收盘" in c or "现价" in c), None)
        pct_col   = next((c for c in idx_df.columns if "涨跌幅" in c or "涨幅" in c), None)
        for i, (code, name) in enumerate(key_indices.items()):
            row = idx_df[idx_df[code_col].astype(str).str.contains(code)]
            if row.empty:
                continue
            row = row.iloc[0]
            price = row.get(price_col, "--") if price_col else "--"
            pct   = row.get(pct_col, 0)      if pct_col   else 0
            try:
                pct_f = float(str(pct).replace("%",""))
            except Exception:
                pct_f = 0
            color = "up" if pct_f > 0 else ("down" if pct_f < 0 else "")
            sign  = "+" if pct_f > 0 else ""
            with cols[i % len(cols)]:
                st.markdown(f"""
                <div class='metric-card'>
                    <div class='label'>{name}</div>
                    <div class='value {color}'>{price}</div>
                    <div class='{color}' style='font-size:0.85rem'>{sign}{pct_f:.2f}%</div>
                </div>
                """, unsafe_allow_html=True)

    st.markdown("---")

    # ── 市场活跃度 ───────────────────────────────────────────────────────────
    col_l, col_r = st.columns(2)
    with col_l:
        st.markdown("#### 市场涨跌分布")
        mkt_df = df_mod.get_market_activity()
        if not mkt_df.empty:
            st.dataframe(mkt_df, use_container_width=True, height=200)
        else:
            # 用A股数据统计
            spot = df_mod.get_a_stock_spot()
            if not spot.empty and "涨跌幅%" in spot.columns:
                pct_col = "涨跌幅%"
                up_cnt   = (spot[pct_col] > 0).sum()
                down_cnt = (spot[pct_col] < 0).sum()
                flat_cnt = (spot[pct_col] == 0).sum()
                st.markdown(f"""
                <div style='display:flex;gap:12px;'>
                    <div class='metric-card' style='flex:1'><div class='label'>上涨</div>
                        <div class='value up'>{up_cnt}</div></div>
                    <div class='metric-card' style='flex:1'><div class='label'>下跌</div>
                        <div class='value down'>{down_cnt}</div></div>
                    <div class='metric-card' style='flex:1'><div class='label'>平盘</div>
                        <div class='value'>{flat_cnt}</div></div>
                </div>
                """, unsafe_allow_html=True)

    with col_r:
        st.markdown("#### 北向资金")
        north = df_mod.get_north_money_flow()
        if not north.empty:
            st.dataframe(north, use_container_width=True, height=200)
        else:
            st.info("北向资金数据暂时不可用")

    st.markdown("---")

    # ── 大盘资金流向 ─────────────────────────────────────────────────────────
    st.markdown("#### 大盘资金流向")
    mff = df_mod.get_market_fund_flow()
    if not mff.empty:
        pct_cols = [c for c in mff.columns if "%" in c or "涨跌" in c]
        render_df(mff, pct_cols=pct_cols, height=300)
    else:
        st.info("大盘资金流向数据获取中...")

# ─────────────────────────────────────────────────────────────────────────────
#  PAGE: 全部A股
# ─────────────────────────────────────────────────────────────────────────────
def page_all_stocks():
    st.title("📊 全部A股实时行情")
    trading_status_badge()

    spot = df_mod.get_a_stock_spot()
    if spot.empty:
        st.error("A股数据获取失败，请检查网络")
        return

    # ── 筛选工具栏 ───────────────────────────────────────────────────────────
    with st.expander("🔍 筛选 & 排序", expanded=True):
        fc1, fc2, fc3, fc4, fc5 = st.columns(5)
        search_kw    = fc1.text_input("搜索名称/代码", key="stock_search", placeholder="如 平安 / 000001")
        sort_col_opt = fc2.selectbox("排序字段", [
            "涨跌幅%","成交额(元)","成交量(手)","换手率%","量比",
            "涨速%","5min涨跌%","总市值(元)","PE(动)"
        ], key="stock_sort_col")
        sort_asc     = fc3.radio("排序方向", ["降序","升序"], horizontal=True, key="stock_sort_dir") == "升序"
        limit_n      = fc4.select_slider("显示条数", options=[50,100,200,500,1000,3000], value=200, key="stock_limit")
        pct_filter   = fc5.slider("涨跌幅范围 (%)", min_value=-20.0, max_value=20.0, value=(-20.0, 20.0), step=0.5, key="stock_pct_filter")

    df = spot.copy()
    # 搜索
    if search_kw:
        mask = df["名称"].str.contains(search_kw, na=False) | df["代码"].astype(str).str.contains(search_kw, na=False)
        df = df[mask]
    # 涨跌幅过滤
    pct_col = "涨跌幅%"
    if pct_col in df.columns:
        df[pct_col] = pd.to_numeric(df[pct_col], errors="coerce")
        df = df[df[pct_col].between(pct_filter[0], pct_filter[1])]
    # 排序
    if sort_col_opt in df.columns:
        df[sort_col_opt] = pd.to_numeric(df[sort_col_opt], errors="coerce")
        df = df.sort_values(sort_col_opt, ascending=sort_asc, na_position="last")
    df = df.head(limit_n)

    # 汇总指标
    total = len(spot)
    filtered = len(df)
    m1, m2, m3, m4 = st.columns(4)
    m1.metric("全市场股票数", total)
    m2.metric("当前筛选结果", filtered)
    if pct_col in spot.columns:
        up_c   = (spot[pct_col] > 0).sum()
        down_c = (spot[pct_col] < 0).sum()
        m3.metric("上涨家数 🟢", up_c)
        m4.metric("下跌家数 🔴", down_c)

    # 显示
    display_cols = [c for c in [
        "代码","名称","最新价","涨跌幅%","涨跌额","成交额(元)",
        "成交量(手)","换手率%","量比","涨速%","5min涨跌%",
        "总市值(元)","PE(动)","PB"
    ] if c in df.columns]
    render_df(df[display_cols], pct_cols=["涨跌幅%","涨速%","5min涨跌%"], height=600)

    # 下载
    st.download_button(
        "⬇️ 下载 CSV", data=df.to_csv(index=False).encode("utf-8-sig"),
        file_name=f"a_stock_{datetime.now().strftime('%Y%m%d_%H%M')}.csv",
        mime="text/csv"
    )

# ─────────────────────────────────────────────────────────────────────────────
#  PAGE: ETF行情
# ─────────────────────────────────────────────────────────────────────────────
def page_etf():
    st.title("🔮 ETF 行情")
    trading_status_badge()
    tab1, tab2 = st.tabs(["📡 实时行情", "📅 日行情(含净值折溢价)"])

    with tab1:
        etf_spot = df_mod.get_etf_spot()
        if etf_spot.empty:
            st.error("ETF实时数据获取失败")
        else:
            # 筛选
            c1, c2, c3 = st.columns(3)
            kw    = c1.text_input("搜索ETF", key="etf_search", placeholder="如 沪深300")
            sort_c = c2.selectbox("排序", [c for c in etf_spot.columns if "涨" in c or "跌" in c or "额" in c or "量" in c], key="etf_sort")
            n      = c3.select_slider("显示条数", [50,100,200,500], value=200, key="etf_n")
            df = etf_spot.copy()
            if kw:
                name_col = next((c for c in df.columns if "名" in c), None)
                code_col = next((c for c in df.columns if "代" in c), None)
                masks = []
                if name_col: masks.append(df[name_col].astype(str).str.contains(kw, na=False))
                if code_col: masks.append(df[code_col].astype(str).str.contains(kw, na=False))
                if masks:
                    df = df[masks[0] | masks[1]] if len(masks)>1 else df[masks[0]]
            if sort_c in df.columns:
                df[sort_c] = pd.to_numeric(df[sort_c], errors="coerce")
                df = df.sort_values(sort_c, ascending=False, na_position="last")
            pct_cols = [c for c in df.columns if "涨跌" in c or "%" in str(c)]
            render_df(df.head(n), pct_cols=pct_cols, height=580)

    with tab2:
        etf_daily = df_mod.get_etf_daily()
        if etf_daily.empty:
            st.info("ETF日行情数据暂不可用（通常收盘后16:00更新）")
        else:
            pct_cols = [c for c in etf_daily.columns if "增长" in c or "折价" in c or "涨跌" in c]
            render_df(etf_daily, pct_cols=pct_cols, height=580)

# ─────────────────────────────────────────────────────────────────────────────
#  PAGE: 基金数据
# ─────────────────────────────────────────────────────────────────────────────
def page_fund():
    st.title("💼 基金数据")
    tab1, tab2, tab3 = st.tabs(["📈 开放式基金排行", "💵 货币基金", "🆕 新发基金"])

    with tab1:
        fund_df = df_mod.get_fund_open_rank()
        if not fund_df.empty:
            pct_cols = [c for c in fund_df.columns if "增长" in c or "收益" in c or "涨" in c]
            render_df(fund_df, pct_cols=pct_cols, height=550)
        else:
            st.error("基金排行数据获取失败")

    with tab2:
        mf = df_mod.get_money_fund_daily()
        if not mf.empty:
            render_df(mf, height=450)
        else:
            st.info("货币基金数据暂不可用")

    with tab3:
        nf = df_mod.get_new_fund_list()
        if not nf.empty:
            st.dataframe(nf, use_container_width=True, height=450)
        else:
            st.info("新发基金数据暂不可用")

# ─────────────────────────────────────────────────────────────────────────────
#  PAGE: 自选股（1分钟成交量/成交额）
# ─────────────────────────────────────────────────────────────────────────────
def page_watchlist():
    st.title("⭐ 自选股 · 1分钟分时监控")
    trading_status_badge()

    wl = st.session_state.get("watchlist", [])
    if not wl:
        st.info("请在左侧侧边栏添加自选股代码")
        return

    spot = df_mod.get_a_stock_spot()

    # ── 自选股实时行情卡片 ───────────────────────────────────────────────────
    st.markdown("#### 实时行情")
    n_cols = min(len(wl), 4)
    cols   = st.columns(n_cols)
    if not spot.empty:
        code_col = "代码" if "代码" in spot.columns else spot.columns[0]
        for i, code in enumerate(wl):
            row = spot[spot[code_col].astype(str) == code]
            with cols[i % n_cols]:
                if not row.empty:
                    r = row.iloc[0]
                    name  = r.get("名称",  code)
                    price = r.get("最新价", "--")
                    pct   = r.get("涨跌幅%", 0)
                    vol   = r.get("成交量(手)", "--")
                    amt   = r.get("成交额(元)", "--")
                    try:
                        pct_f = float(pct)
                    except Exception:
                        pct_f = 0
                    clr = "up" if pct_f > 0 else ("down" if pct_f < 0 else "")
                    sign = "+" if pct_f > 0 else ""
                    st.markdown(f"""
                    <div class='metric-card'>
                        <div class='label'>{name} ({code})</div>
                        <div class='value {clr}'>{price}</div>
                        <div class='{clr}' style='font-size:0.88rem'>{sign}{pct_f:.2f}%</div>
                        <div style='font-size:0.75rem;color:#8B949E;margin-top:6px'>
                            量: {fmt_large(vol)} | 额: {fmt_large(amt)}
                        </div>
                    </div>
                    """, unsafe_allow_html=True)
                else:
                    st.markdown(f"""
                    <div class='metric-card'>
                        <div class='label'>{code}</div>
                        <div style='color:#8B949E'>暂无数据</div>
                    </div>
                    """, unsafe_allow_html=True)

    st.markdown("---")

    # ── 1分钟分时图表 ────────────────────────────────────────────────────────
    st.markdown("#### 1分钟分时图 — 成交量 & 成交额")
    selected = st.selectbox("选择股票", wl, key="wl_selected_stock")

    if selected:
        with st.spinner(f"加载 {selected} 1分钟数据..."):
            min_df = df_mod.get_stock_1min(selected)

        if min_df.empty:
            # 备用新浪
            min_df = df_mod.get_stock_1min_sina(selected)

        if not min_df.empty:
            # 标准化列名
            col_map = {}
            for c in min_df.columns:
                cl = c.lower()
                if "time" in cl or "时间" in cl: col_map[c] = "time"
                elif "close" in cl or "收盘" in cl or "price" in cl: col_map[c] = "close"
                elif "volume" in cl or "成交量" in cl: col_map[c] = "volume"
                elif "amount" in cl or "成交额" in cl or "turnover" in cl: col_map[c] = "amount"
            min_df.rename(columns=col_map, inplace=True)
            if "time" in min_df.columns:
                min_df["time"] = pd.to_datetime(min_df["time"], errors="coerce")
                min_df = min_df.dropna(subset=["time"]).sort_values("time")

            tab_v, tab_a, tab_p = st.tabs(["📊 成交量", "💰 成交额", "📈 分时价格"])
            with tab_v:
                if "volume" in min_df.columns and "time" in min_df.columns:
                    fig = px.bar(min_df, x="time", y="volume",
                                 title=f"{selected} — 1分钟成交量(手)",
                                 color_discrete_sequence=["#00C896"],
                                 template="plotly_dark")
                    fig.update_layout(height=360, margin=dict(t=40,b=20,l=20,r=20))
                    st.plotly_chart(fig, use_container_width=True)
                    # 汇总统计
                    m1,m2,m3,m4 = st.columns(4)
                    m1.metric("最大1分钟量", fmt_large(min_df["volume"].max()))
                    m2.metric("平均1分钟量", fmt_large(min_df["volume"].mean()))
                    m3.metric("今日累计量",  fmt_large(min_df["volume"].sum()))
                    m4.metric("数据点数",    len(min_df))
                else:
                    st.info("成交量列不可用")

            with tab_a:
                if "amount" in min_df.columns and "time" in min_df.columns:
                    fig = px.bar(min_df, x="time", y="amount",
                                 title=f"{selected} — 1分钟成交额(元)",
                                 color_discrete_sequence=["#E63946"],
                                 template="plotly_dark")
                    fig.update_layout(height=360, margin=dict(t=40,b=20,l=20,r=20))
                    st.plotly_chart(fig, use_container_width=True)
                    m1,m2,m3 = st.columns(3)
                    m1.metric("最大1分钟额", fmt_large(min_df["amount"].max()))
                    m2.metric("平均1分钟额", fmt_large(min_df["amount"].mean()))
                    m3.metric("今日累计额",  fmt_large(min_df["amount"].sum()))
                else:
                    st.info("成交额列不可用")

            with tab_p:
                if "close" in min_df.columns and "time" in min_df.columns:
                    fig = go.Figure()
                    fig.add_trace(go.Scatter(
                        x=min_df["time"], y=min_df["close"],
                        mode="lines", name="价格",
                        line=dict(color="#58A6FF", width=1.5)
                    ))
                    fig.update_layout(
                        title=f"{selected} — 分时价格",
                        template="plotly_dark", height=360,
                        margin=dict(t=40,b=20,l=20,r=20)
                    )
                    st.plotly_chart(fig, use_container_width=True)

            st.markdown("##### 原始数据")
            st.dataframe(min_df, use_container_width=True, height=260)
        else:
            st.warning(f"{selected} 1分钟数据暂不可用（可能非交易时间）")

# ─────────────────────────────────────────────────────────────────────────────
#  PAGE: 资金流向
# ─────────────────────────────────────────────────────────────────────────────
def page_fund_flow():
    st.title("💰 资金流向")
    tab1, tab2, tab3 = st.tabs(["🏢 行业资金流", "🌐 大盘资金流", "🔍 个股资金流"])

    with tab1:
        sector_ff = df_mod.get_sector_fund_flow()
        if not sector_ff.empty:
            pct_cols = [c for c in sector_ff.columns if "%" in str(c) or "涨" in c or "净" in c]
            render_df(sector_ff, pct_cols=pct_cols, height=500)
        else:
            st.error("行业资金流数据获取失败")

    with tab2:
        mff = df_mod.get_market_fund_flow()
        if not mff.empty:
            pct_cols = [c for c in mff.columns if "%" in str(c) or "涨" in c]
            render_df(mff, pct_cols=pct_cols, height=400)
        else:
            st.error("大盘资金流数据获取失败")

    with tab3:
        code_input = st.text_input("输入股票代码", value="600036", placeholder="如 000001", key="ff_code")
        if st.button("查询", key="ff_query"):
            with st.spinner("查询中..."):
                ff_df = df_mod.get_stock_fund_flow_individual(code_input.strip())
            if not ff_df.empty:
                pct_cols = [c for c in ff_df.columns if "%" in str(c) or "净" in c]
                render_df(ff_df, pct_cols=pct_cols, height=400)
            else:
                st.error(f"股票 {code_input} 资金流向数据获取失败")

# ─────────────────────────────────────────────────────────────────────────────
#  PAGE: 板块行情
# ─────────────────────────────────────────────────────────────────────────────
def page_sector():
    st.title("🏭 板块行情")
    tab1, tab2 = st.tabs(["🏭 行业板块", "💡 概念板块"])

    with tab1:
        sec_df = df_mod.get_sector_spot()
        if not sec_df.empty:
            pct_cols = [c for c in sec_df.columns if "涨跌" in c or "%" in str(c)]
            if "涨跌幅" in sec_df.columns:
                sec_df["涨跌幅"] = pd.to_numeric(sec_df["涨跌幅"], errors="coerce")
                sec_df = sec_df.sort_values("涨跌幅", ascending=False)
                fig = px.bar(
                    sec_df.head(30), x=sec_df.columns[0], y="涨跌幅",
                    title="行业板块涨跌幅 TOP30",
                    color="涨跌幅",
                    color_continuous_scale=["#FF3B30","#FF9500","#30D158","#00C896"],
                    template="plotly_dark"
                )
                fig.update_layout(height=380, margin=dict(t=40,b=80,l=20,r=20))
                fig.update_xaxes(tickangle=45)
                st.plotly_chart(fig, use_container_width=True)
            render_df(sec_df, pct_cols=pct_cols, height=400)
        else:
            st.error("行业板块数据获取失败")

    with tab2:
        con_df = df_mod.get_concept_spot()
        if not con_df.empty:
            pct_cols = [c for c in con_df.columns if "涨跌" in c or "%" in str(c)]
            render_df(con_df, pct_cols=pct_cols, height=500)
        else:
            st.error("概念板块数据获取失败")

# ─────────────────────────────────────────────────────────────────────────────
#  PAGE: 同花顺排名
# ─────────────────────────────────────────────────────────────────────────────
def page_ths_rank():
    st.title("🏆 同花顺技术选股排名")
    tab1, tab2, tab3, tab4 = st.tabs(["🚀 创新高", "📈 连续上涨", "📊 持续放量", "💹 量价齐升"])

    with tab1:
        df = df_mod.get_ths_rank_create_high()
        render_df(df, pct_cols=[c for c in df.columns if "%" in str(c) or "涨" in c], height=500)
    with tab2:
        df = df_mod.get_ths_rank_lxsz()
        render_df(df, height=500)
    with tab3:
        df = df_mod.get_ths_rank_cxfl()
        render_df(df, height=500)
    with tab4:
        df = df_mod.get_ths_rank_ljqs()
        render_df(df, height=500)

# ─────────────────────────────────────────────────────────────────────────────
#  PAGE: 新发ETF/基金
# ─────────────────────────────────────────────────────────────────────────────
def page_new_products():
    st.title("🆕 新发行 ETF & 基金")
    tab1, tab2 = st.tabs(["🔮 新发ETF", "💼 新发基金"])

    with tab1:
        new_etf = df_mod.get_new_etf_list()
        if not new_etf.empty:
            st.success(f"共 {len(new_etf)} 条记录")
            st.dataframe(new_etf, use_container_width=True, height=500)
        else:
            st.info("新发ETF数据暂不可用")

    with tab2:
        new_fund = df_mod.get_new_fund_list()
        if not new_fund.empty:
            st.success(f"共 {len(new_fund)} 条记录")
            st.dataframe(new_fund, use_container_width=True, height=500)
        else:
            st.info("新发基金数据暂不可用")

# ─────────────────────────────────────────────────────────────────────────────
#  PAGE: 系统管理（admin）
# ─────────────────────────────────────────────────────────────────────────────
def page_admin():
    if st.session_state.get("role") != "admin":
        st.error("无权限访问管理页面")
        return
    st.title("⚙️ 系统管理")
    tab1, tab2, tab3 = st.tabs(["👥 用户管理", "🌐 访问日志", "💾 系统信息"])

    with tab1:
        admin_user_manager()
    with tab2:
        admin_access_log()
    with tab3:
        st.markdown("#### 系统信息")
        info_data = {
            "版本": "GPC v2.0",
            "Python": sys.version.split()[0],
            "AKShare": "最新",
            "数据目录": "/app/data",
            "日志目录": "/app/logs",
            "运行时间": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        }
        for k,v in info_data.items():
            st.text(f"{k}: {v}")
        if st.button("🗑️ 清空磁盘缓存"):
            try:
                import diskcache as dc
                c = dc.Cache("/app/data/cache")
                c.clear()
                st.success("缓存已清空")
            except Exception as e:
                st.error(f"清空失败: {e}")

# ─────────────────────────────────────────────────────────────────────────────
#  路由分发
# ─────────────────────────────────────────────────────────────────────────────
PAGES = {
    "overview":     page_overview,
    "all_stocks":   page_all_stocks,
    "etf":          page_etf,
    "fund":         page_fund,
    "watchlist":    page_watchlist,
    "fund_flow":    page_fund_flow,
    "sector":       page_sector,
    "ths_rank":     page_ths_rank,
    "new_products": page_new_products,
    "admin":        page_admin,
}

current_page = st.session_state.get("nav_page","🏠 市场总览")
page_key = {
    "🏠 市场总览":"overview","📊 全部A股":"all_stocks","🔮 ETF 行情":"etf",
    "💼 基金数据":"fund","⭐ 自选股":"watchlist","💰 资金流向":"fund_flow",
    "🏭 板块行情":"sector","🏆 同花顺排名":"ths_rank","🆕 新发ETF/基金":"new_products",
    "⚙️ 系统管理":"admin"
}.get(current_page, "overview")

PAGES.get(page_key, page_overview)()
APPEOF

    success "Streamlit 应用代码写入完成"
}

# =============================================================================
#  SECTION 6 — Dockerfile
# =============================================================================
write_dockerfile() {
    # 生成 entrypoint.sh：修正挂载卷权限后以非root执行
    cat > "${APP_DIR}/app/entrypoint.sh" << 'EPEOF'
#!/bin/sh
set -e
chown -R 1001:1001 /app/data /app/logs 2>/dev/null || true
exec su-exec appuser "$@" 2>/dev/null || exec gosu appuser "$@" 2>/dev/null || exec "$@"
EPEOF
    chmod +x "${APP_DIR}/app/entrypoint.sh"

    cat > "${APP_DIR}/app/Dockerfile" << 'DKEOF'
FROM python:3.11-slim

# 时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 系统依赖
RUN apt-get update -q && apt-get install -y -q --no-install-recommends \
    gcc g++ libffi-dev curl tzdata procps gosu \
    && rm -rf /var/lib/apt/lists/*

# 工作目录
WORKDIR /app

# 安装 Python 依赖（分两步提高缓存利用率）
COPY requirements.txt /app/
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY . /app/

# 数据目录
RUN mkdir -p /app/data/cache /app/logs

# 创建运行用户，但挂载卷由 entrypoint 修正权限
RUN useradd -m -u 1001 appuser && chown -R appuser:appuser /app

# entrypoint 脚本：修正挂载卷权限后切换用户
COPY --chown=root:root entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8501

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8501/_stcore/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["streamlit", "run", "app.py", \
     "--server.port=8501", \
     "--server.address=0.0.0.0", \
     "--server.headless=true", \
     "--browser.gatherUsageStats=false"]
DKEOF
}

# =============================================================================
#  SECTION 7 — Docker Compose
# =============================================================================
write_docker_compose() {
    header "写入 docker-compose.yml"
    # 读入运行时环境变量
    source "${ENV_FILE}"
    cat > "${COMPOSE_FILE}" << DCEOF
version: "3.9"

services:
  streamlit:
    build:
      context: ${APP_DIR}/app
      dockerfile: Dockerfile
    container_name: gpc_streamlit
    restart: unless-stopped
    environment:
      - TZ=Asia/Shanghai
      - USERS_FILE=/app/data/users.json
      - ACCESS_LOG=/app/logs/access.log
      - SECRET_KEY=${SECRET_KEY}
    volumes:
      - ${DATA_DIR}:/app/data
      - ${LOG_DIR}:/app/logs
    networks:
      - gpc_net
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8501/_stcore/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    logging:
      driver: json-file
      options:
        max-size: "50m"
        max-file: "5"

  nginx:
    image: nginx:1.25-alpine
    container_name: gpc_nginx
    restart: unless-stopped
    ports:
      - "${PORT}:${PORT}"
      - "8080:8080"
    volumes:
      - ${APP_DIR}/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ${CERT_DIR}:/etc/nginx/certs:ro
      - ${LOG_DIR}:/var/log/nginx
    depends_on:
      streamlit:
        condition: service_healthy
    networks:
      - gpc_net
    logging:
      driver: json-file
      options:
        max-size: "20m"
        max-file: "3"

networks:
  gpc_net:
    driver: bridge
DCEOF
    success "docker-compose.yml 写入完成"
}

# =============================================================================
#  SECTION 8 — 防火墙配置
# =============================================================================
setup_firewall() {
    header "配置防火墙"
    if command -v ufw &>/dev/null; then
        ufw --force enable 2>/dev/null || true
        ufw allow ssh    comment "SSH"            2>/dev/null || true
        ufw allow "${PORT}/tcp" comment "GPC Dashboard" 2>/dev/null || true
        ufw allow 8080/tcp      comment "GPC HTTP redirect" 2>/dev/null || true
        success "UFW 防火墙已配置 (仅开放 SSH + ${PORT} + 8080)"
    elif command -v firewall-cmd &>/dev/null; then
        systemctl start firewalld 2>/dev/null || true
        firewall-cmd --permanent --add-port="${PORT}/tcp" 2>/dev/null || true
        firewall-cmd --permanent --add-port="8080/tcp"   2>/dev/null || true
        firewall-cmd --reload                             2>/dev/null || true
        success "firewalld 配置完成"
    else
        warn "未检测到 ufw/firewalld，请手动开放端口 ${PORT}"
    fi
}

# =============================================================================
#  SECTION 9 — 快捷键 gpc
# =============================================================================
install_shortcut() {
    header "安装快捷命令 'gpc'"
    cat > "/usr/local/bin/${SHORTCUT_NAME}" << SHORTEOF
#!/usr/bin/env bash
# GPC 看板管理面板
APP_DIR="${APP_DIR}"
COMPOSE_FILE="${COMPOSE_FILE}"
PORT="${PORT}"
DOMAIN="${DOMAIN}"
ENV_FILE="${ENV_FILE}"
LOG_DIR="${LOG_DIR}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

show_banner() {
    clear
    echo -e "\${BOLD}\${CYAN}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║      GPC 金融看板  管理面板 v2.0         ║"
    echo "  ║  域名: ${DOMAIN}:${PORT}   ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "\${NC}"
}

show_status() {
    echo -e "\${BOLD}服务状态:\${NC}"
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q gpc_streamlit; then
        echo -e "  Streamlit: \${GREEN}运行中 ✅\${NC}"
    else
        echo -e "  Streamlit: \${RED}已停止 ❌\${NC}"
    fi
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q gpc_nginx; then
        echo -e "  Nginx:     \${GREEN}运行中 ✅\${NC}"
    else
        echo -e "  Nginx:     \${RED}已停止 ❌\${NC}"
    fi
    echo ""
    echo -e "  访问地址: \${BOLD}https://${DOMAIN}:${PORT}\${NC}"
    echo ""
}

show_menu() {
    echo -e "\${BOLD}操作菜单:\${NC}"
    echo "  [1] 启动服务"
    echo "  [2] 停止服务"
    echo "  [3] 重启服务"
    echo "  [4] 查看实时日志"
    echo "  [5] 查看访问日志(最近50条)"
    echo "  [6] 查看当前在线IP"
    echo "  [7] 更新应用代码"
    echo "  [8] 查看服务状态"
    echo "  [9] 重新构建镜像"
    echo "  [0] 退出"
    echo ""
}

get_online_ips() {
    echo -e "\${BOLD}最近访问的 IP 地址:\${NC}"
    if [[ -f "\${LOG_DIR}/access.log" ]]; then
        grep -oP "ip=\K[\d\.]+" "\${LOG_DIR}/access.log" 2>/dev/null | sort | uniq -c | sort -rn | head -30 || echo "暂无记录"
    fi
    echo ""
    echo -e "\${BOLD}Nginx 访问日志最近 IP:\${NC}"
    if [[ -f "\${LOG_DIR}/access.log" ]]; then
        tail -100 "\${LOG_DIR}/access.log" | awk '{print \$1}' | sort | uniq -c | sort -rn | head -20 || echo "暂无记录"
    fi
}

main() {
    show_banner
    show_status
    show_menu
    read -rp "请选择操作 [0-9]: " choice
    case "\${choice}" in
        1) echo "启动服务..."; cd "\${APP_DIR}" && docker compose -f "\${COMPOSE_FILE}" up -d ;;
        2) echo "停止服务..."; cd "\${APP_DIR}" && docker compose -f "\${COMPOSE_FILE}" down ;;
        3) echo "重启服务..."; cd "\${APP_DIR}" && docker compose -f "\${COMPOSE_FILE}" restart ;;
        4) cd "\${APP_DIR}" && docker compose -f "\${COMPOSE_FILE}" logs -f --tail=100 ;;
        5) tail -50 "\${LOG_DIR}/access.log" 2>/dev/null || echo "暂无日志" ;;
        6) get_online_ips ;;
        7) echo "更新代码..."; cd "\${APP_DIR}" && docker compose -f "\${COMPOSE_FILE}" up -d --no-deps streamlit ;;
        8) show_status; docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep gpc || true ;;
        9) echo "重新构建..."; cd "\${APP_DIR}" && docker compose -f "\${COMPOSE_FILE}" build --no-cache && docker compose -f "\${COMPOSE_FILE}" up -d ;;
        0) exit 0 ;;
        *) echo "无效选项" ;;
    esac
}

main "\$@"
SHORTEOF
    chmod +x "/usr/local/bin/${SHORTCUT_NAME}"

    # 加入 bash/zsh 的别名（可选）
    for profile in /root/.bashrc /root/.zshrc /home/*/.bashrc; do
        [[ -f "${profile}" ]] && ! grep -q "alias gpc=" "${profile}" 2>/dev/null && \
            echo "alias gpc='/usr/local/bin/gpc'" >> "${profile}" 2>/dev/null || true
    done

    success "快捷命令安装完成，输入 'gpc' 即可唤出管理面板"
}

# =============================================================================
#  SECTION 10 — 构建并启动服务
# =============================================================================
build_and_start() {
    header "构建 Docker 镜像并启动服务"
    cd "${APP_DIR}"

    info "拉取 Nginx 基础镜像..."
    docker pull nginx:1.25-alpine --quiet 2>/dev/null || true

    info "构建 Streamlit 应用镜像（首次约需 5-10 分钟）..."
    ${COMPOSE_CMD} -f "${COMPOSE_FILE}" build --no-cache

    info "启动所有服务..."
    ${COMPOSE_CMD} -f "${COMPOSE_FILE}" up -d

    # 等待健康检查
    info "等待服务就绪（最长60秒）..."
    for i in $(seq 1 12); do
        sleep 5
        if docker ps --format '{{.Names}} {{.Status}}' | grep -q "gpc_streamlit.*healthy\|gpc_streamlit.*Up"; then
            if docker ps --format '{{.Names}} {{.Status}}' | grep -q "gpc_nginx.*Up"; then
                success "所有服务已就绪 ✅"
                return 0
            fi
        fi
        echo -n "."
    done
    echo ""
    warn "服务启动超时，请手动检查: docker compose -f ${COMPOSE_FILE} logs"
}

# =============================================================================
#  SECTION 11 — 设置 systemd 开机自启
# =============================================================================
setup_systemd() {
    header "配置 systemd 开机自启"
    cat > /etc/systemd/system/gpc-dashboard.service << SVCEOF
[Unit]
Description=GPC Financial Dashboard
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${APP_DIR}
ExecStart=/usr/bin/docker compose -f ${COMPOSE_FILE} up -d
ExecStop=/usr/bin/docker compose -f ${COMPOSE_FILE} down
TimeoutStartSec=180
Restart=on-failure

[Install]
WantedBy=multi-user.target
SVCEOF
    systemctl daemon-reload
    systemctl enable gpc-dashboard.service
    success "systemd 服务已配置，开机自动启动"
}

# =============================================================================
#  SECTION 12 — 安装完成摘要
# =============================================================================
print_summary() {
    source "${ENV_FILE}"
    echo ""
    echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${GREEN}║          🎉  GPC 看板部署完成！                              ║${NC}"
    echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BOLD}${GREEN}║${NC}  访问地址:  ${BOLD}https://${DOMAIN}:${PORT}${NC}"
    echo -e "${BOLD}${GREEN}║${NC}  管理面板:  输入 ${BOLD}gpc${NC} 命令"
    echo -e "${BOLD}${GREEN}║${NC}  管理账号:  ${BOLD}admin${NC}"
    echo -e "${BOLD}${GREEN}║${NC}  管理密码:  ${BOLD}${ADMIN_PASS}${NC}  ${YELLOW}⚠ 请立即保存！${NC}"
    echo -e "${BOLD}${GREEN}║${NC}  证书类型:  $([ -L "${CERT_DIR}/fullchain.pem" ] && echo "Let's Encrypt" || echo "自签名（浏览器需手动信任）")"
    echo -e "${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}║${NC}  ${YELLOW}注意: 如使用自签名证书，首次访问需在浏览器点击"高级"${NC}"
    echo -e "${BOLD}${GREEN}║${NC}  ${YELLOW}然后选择"继续访问"即可正常使用。${NC}"
    echo -e "${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}║${NC}  快捷命令:"
    echo -e "${BOLD}${GREEN}║${NC}    ${BOLD}gpc${NC}              — 唤出管理面板"
    echo -e "${BOLD}${GREEN}║${NC}    ${BOLD}gpc start${NC}        — 启动 (或用面板菜单1)"
    echo -e "${BOLD}${GREEN}║${NC}    ${BOLD}gpc stop${NC}         — 停止"
    echo -e "${BOLD}${GREEN}║${NC}    ${BOLD}gpc logs${NC}         — 查看日志"
    echo -e "${BOLD}${GREEN}║${NC}"
    echo -e "${BOLD}${GREEN}║${NC}  数据源覆盖:"
    echo -e "${BOLD}${GREEN}║${NC}    ✅ 全部A股实时行情 (东方财富)"
    echo -e "${BOLD}${GREEN}║${NC}    ✅ ETF实时+日行情 (净值/折溢价)"
    echo -e "${BOLD}${GREEN}║${NC}    ✅ 开放式基金/货币基金排行"
    echo -e "${BOLD}${GREEN}║${NC}    ✅ 新发ETF/基金列表"
    echo -e "${BOLD}${GREEN}║${NC}    ✅ 资金流向 (个股/行业/大盘/北向)"
    echo -e "${BOLD}${GREEN}║${NC}    ✅ 行业板块 + 概念板块"
    echo -e "${BOLD}${GREEN}║${NC}    ✅ 同花顺技术排名 (创新高/连涨/放量/量价齐升)"
    echo -e "${BOLD}${GREEN}║${NC}    ✅ 自选股1分钟成交量/成交额分时图"
    echo -e "${BOLD}${GREEN}║${NC}    ✅ 全A股多字段排序筛选"
    echo -e "${BOLD}${GREEN}║${NC}    ✅ 用户管理 + IP审计日志"
    echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# =============================================================================
#  MAIN — 主流程
# =============================================================================
main() {
    clear
    echo -e "${BOLD}${BLUE}"
    echo "  ██████╗ ██████╗  ██████╗"
    echo "  ██╔════╝██╔══██╗██╔════╝"
    echo "  ██║  ███╗██████╔╝██║"
    echo "  ██║   ██║██╔═══╝ ██║"
    echo "  ╚██████╔╝██║     ╚██████╗"
    echo "   ╚═════╝ ╚═╝      ╚═════╝"
    echo -e "${NC}${BOLD}  中国金融数据看板  一键部署脚本 v${SCRIPT_VERSION}${NC}"
    echo ""

    check_root
    detect_os
    install_system_deps
    install_docker
    install_docker_compose
    create_directories
    setup_certificates
    generate_secrets
    write_nginx_conf
    write_streamlit_app
    write_dockerfile
    write_docker_compose
    setup_firewall
    install_shortcut
    build_and_start
    setup_systemd
    print_summary
}

# 支持子命令（非安装模式调用）
case "${1:-install}" in
    install) main ;;
    start)   cd "${APP_DIR}" && ${COMPOSE_CMD:-docker compose} -f "${COMPOSE_FILE}" up -d ;;
    stop)    cd "${APP_DIR}" && ${COMPOSE_CMD:-docker compose} -f "${COMPOSE_FILE}" down ;;
    restart) cd "${APP_DIR}" && ${COMPOSE_CMD:-docker compose} -f "${COMPOSE_FILE}" restart ;;
    logs)    cd "${APP_DIR}" && ${COMPOSE_CMD:-docker compose} -f "${COMPOSE_FILE}" logs -f --tail=100 ;;
    status)  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep gpc || echo "服务未运行" ;;
    rebuild) cd "${APP_DIR}" && ${COMPOSE_CMD:-docker compose} -f "${COMPOSE_FILE}" build --no-cache && ${COMPOSE_CMD:-docker compose} -f "${COMPOSE_FILE}" up -d ;;
    *)       echo "用法: bash gpc2.sh [install|start|stop|restart|logs|status|rebuild]" ;;
esac
