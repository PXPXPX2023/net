#!/usr/bin/env bash
# =========================================================
# GPC2H v1.1 Production
# 私有化 VPS 股票数据系统
#
# 特性:
# - 非 Docker 原生部署
# - FastAPI + Streamlit
# - AkShare + 东方财富
# - Redis + PostgreSQL
# - HTTPS(acme.sh DNS)
# - JWT 登录
# - 用户管理
# - 当前访问 IP 显示
# - systemd
# - gpc 管理命令
# - 可迁移
# - repair/update/migrate
#
# 系统:
# Debian 12+
#
# 目录:
# /opt/gpc
#
# =========================================================

set -Eeuo pipefail

###########################################################
# 基础变量
###########################################################

GPC_ROOT="/opt/gpc"

BACKEND_PORT="18000"
FRONTEND_PORT="18501"
HTTPS_PORT="16666"

REDIS_PORT="6379"
POSTGRES_PORT="5432"

DOMAIN=""
EMAIL=""

JWT_SECRET="$(openssl rand -hex 32)"

ADMIN_USER="admin"
ADMIN_PASS="$(openssl rand -base64 18)"

POSTGRES_DB="gpc"
POSTGRES_USER="gpc"
POSTGRES_PASS="$(openssl rand -hex 16)"

CF_TOKEN=""
CF_ZONE_ID=""
CF_ACCOUNT_ID=""

###########################################################
# 颜色
###########################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

###########################################################
# 输出函数
###########################################################

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

ok() {
    echo -e "${GREEN}[ OK ]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

err() {
    echo -e "${RED}[FAIL]${NC} $1"
}

###########################################################
# root 检测
###########################################################

if [[ $EUID -ne 0 ]]; then
    err "请使用 root 运行"
    exit 1
fi

###########################################################
# 系统检测
###########################################################

check_system() {

    info "检查系统"

    if ! grep -q "Debian GNU/Linux 12" /etc/os-release; then
        warn "当前不是 Debian12，继续执行"
    fi

    ARCH=$(uname -m)

    case "$ARCH" in
        x86_64|amd64)
            ok "x86_64"
            ;;
        aarch64|arm64)
            ok "ARM64"
            ;;
        *)
            err "不支持架构: $ARCH"
            exit 1
            ;;
    esac
}

###########################################################
# 输入
###########################################################

input_config() {

    echo ""

    read -rp "请输入域名: " DOMAIN

    if [[ -z "$DOMAIN" ]]; then
        err "域名不能为空"
        exit 1
    fi

    read -rp "请输入邮箱: " EMAIL

    read -rp "Cloudflare API Token: " CF_TOKEN
    read -rp "Cloudflare Zone ID: " CF_ZONE_ID
    read -rp "Cloudflare Account ID: " CF_ACCOUNT_ID
}

###########################################################
# 安装依赖
###########################################################

install_base() {

    info "安装基础依赖"

    apt update -y

    apt install -y \
        curl \
        wget \
        git \
        unzip \
        tar \
        jq \
        nginx \
        redis-server \
        postgresql \
        postgresql-contrib \
        python3 \
        python3-pip \
        python3-venv \
        python3-dev \
        build-essential \
        libpq-dev \
        ufw \
        cron \
        htop \
        vim \
        net-tools \
        socat \
        openssl

    ok "基础依赖安装完成"
}

###########################################################
# 创建目录
###########################################################

create_dirs() {

    info "创建目录"

    mkdir -p \
        ${GPC_ROOT} \
        ${GPC_ROOT}/backend \
        ${GPC_ROOT}/frontend \
        ${GPC_ROOT}/workers \
        ${GPC_ROOT}/scheduler \
        ${GPC_ROOT}/runtime \
        ${GPC_ROOT}/logs \
        ${GPC_ROOT}/ssl \
        ${GPC_ROOT}/config \
        ${GPC_ROOT}/backups \
        ${GPC_ROOT}/scripts \
        ${GPC_ROOT}/systemd \
        ${GPC_ROOT}/data \
        ${GPC_ROOT}/data/parquet \
        ${GPC_ROOT}/data/minute \
        ${GPC_ROOT}/data/cache \
        ${GPC_ROOT}/data/etf

    ok "目录创建完成"
}

###########################################################
# Python venv
###########################################################

create_venv() {

    info "创建 venv"

    python3 -m venv ${GPC_ROOT}/venv

    source ${GPC_ROOT}/venv/bin/activate

    pip install --upgrade pip wheel setuptools

    ok "venv 创建完成"
}

###########################################################
# requirements
###########################################################

install_python_packages() {

    info "安装 Python 包"

cat > ${GPC_ROOT}/requirements.txt <<EOF
fastapi
uvicorn[standard]
streamlit
pandas
numpy
redis
akshare
psycopg2-binary
sqlalchemy
python-jose
passlib[bcrypt]
python-multipart
httpx
apscheduler
plotly
streamlit-aggrid
pyarrow
polars
EOF

    source ${GPC_ROOT}/venv/bin/activate

    pip install -r ${GPC_ROOT}/requirements.txt

    ok "Python 包安装完成"
}

###########################################################
# PostgreSQL
###########################################################

setup_postgresql() {

    info "配置 PostgreSQL"

    systemctl enable postgresql
    systemctl restart postgresql

sudo -u postgres psql <<EOF
CREATE DATABASE ${POSTGRES_DB};
CREATE USER ${POSTGRES_USER} WITH ENCRYPTED PASSWORD '${POSTGRES_PASS}';
GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_USER};
EOF

    ok "PostgreSQL 配置完成"
}

###########################################################
# Redis
###########################################################

setup_redis() {

    info "配置 Redis"

    systemctl enable redis-server
    systemctl restart redis-server

    ok "Redis 配置完成"
}

###########################################################
# ENV
###########################################################

create_env() {

cat > ${GPC_ROOT}/config/.env <<EOF
DOMAIN=${DOMAIN}

BACKEND_PORT=${BACKEND_PORT}
FRONTEND_PORT=${FRONTEND_PORT}
HTTPS_PORT=${HTTPS_PORT}

JWT_SECRET=${JWT_SECRET}

ADMIN_USER=${ADMIN_USER}
ADMIN_PASS=${ADMIN_PASS}

POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASS=${POSTGRES_PASS}

REDIS_HOST=127.0.0.1
REDIS_PORT=${REDIS_PORT}
EOF

ok ".env 创建完成"
}

###########################################################
# FastAPI
###########################################################

create_backend() {

info "创建 FastAPI"

cat > ${GPC_ROOT}/backend/main.py <<'EOF'
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
import akshare as ak
import pandas as pd
import redis
import json

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

r = redis.Redis(
    host="127.0.0.1",
    port=6379,
    decode_responses=True
)

@app.get("/")
def root():
    return {"status": "ok"}

@app.get("/api/a-share")
def a_share():

    cache = r.get("a_share")

    if cache:
        return json.loads(cache)

    df = ak.stock_zh_a_spot_em()

    df = df.sort_values(by="成交额", ascending=False)

    data = df.head(300).to_dict(orient="records")

    r.setex(
        "a_share",
        15,
        json.dumps(data, ensure_ascii=False)
    )

    return data

@app.get("/api/etf")
def etf():

    cache = r.get("etf")

    if cache:
        return json.loads(cache)

    df = ak.fund_etf_spot_em()

    data = df.head(200).to_dict(orient="records")

    r.setex(
        "etf",
        30,
        json.dumps(data, ensure_ascii=False)
    )

    return data

@app.get("/api/ip")
async def get_ip(request: Request):

    ip = request.headers.get(
        "CF-Connecting-IP",
        request.client.host
    )

    return {
        "ip": ip
    }
EOF

ok "FastAPI 创建完成"
}

###########################################################
# Streamlit
###########################################################

create_frontend() {

info "创建 Streamlit"

cat > ${GPC_ROOT}/frontend/app.py <<EOF
import streamlit as st
import pandas as pd
import requests

st.set_page_config(
    page_title="GPC2H",
    layout="wide"
)

st.title("GPC2H 股票系统")

tabs = st.tabs([
    "A股",
    "ETF",
    "访问IP"
])

with tabs[0]:

    st.subheader("A股实时排行")

    r = requests.get(
        "http://127.0.0.1:${BACKEND_PORT}/api/a-share",
        timeout=30
    )

    df = pd.DataFrame(r.json())

    st.dataframe(
        df,
        use_container_width=True,
        height=850
    )

with tabs[1]:

    st.subheader("ETF")

    r = requests.get(
        "http://127.0.0.1:${BACKEND_PORT}/api/etf",
        timeout=30
    )

    df = pd.DataFrame(r.json())

    st.dataframe(
        df,
        use_container_width=True,
        height=850
    )

with tabs[2]:

    r = requests.get(
        "http://127.0.0.1:${BACKEND_PORT}/api/ip"
    )

    st.json(r.json())
EOF

ok "Streamlit 创建完成"
}

###########################################################
# acme.sh
###########################################################

install_acme() {

    info "安装 acme.sh"

    curl https://get.acme.sh | sh

    source ~/.bashrc || true

    ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

    ~/.acme.sh/acme.sh --register-account -m ${EMAIL}

    ok "acme.sh 安装完成"
}

###########################################################
# SSL DNS
###########################################################

issue_ssl() {

    info "DNS 模式签发 SSL"

    export CF_Token="${CF_TOKEN}"
    export CF_Zone_ID="${CF_ZONE_ID}"
    export CF_Account_ID="${CF_ACCOUNT_ID}"

    ~/.acme.sh/acme.sh \
        --issue \
        --dns dns_cf \
        -d ${DOMAIN}

    ~/.acme.sh/acme.sh --install-cert -d ${DOMAIN} \
        --key-file ${GPC_ROOT}/ssl/${DOMAIN}.key \
        --fullchain-file ${GPC_ROOT}/ssl/fullchain.cer

    ok "SSL 签发完成"
}

###########################################################
# Nginx
###########################################################

create_nginx() {

info "配置 Nginx"

cat > /etc/nginx/sites-available/gpc <<EOF
server {

    listen ${HTTPS_PORT} ssl http2;

    server_name ${DOMAIN};

    ssl_certificate ${GPC_ROOT}/ssl/fullchain.cer;
    ssl_certificate_key ${GPC_ROOT}/ssl/${DOMAIN}.key;

    client_max_body_size 100m;

    location / {

        proxy_pass http://127.0.0.1:${FRONTEND_PORT};

        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header CF-Connecting-IP \$http_cf_connecting_ip;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /api/ {

        proxy_pass http://127.0.0.1:${BACKEND_PORT}/api/;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header CF-Connecting-IP \$http_cf_connecting_ip;
    }
}
EOF

ln -sf /etc/nginx/sites-available/gpc /etc/nginx/sites-enabled/gpc

rm -f /etc/nginx/sites-enabled/default

nginx -t

systemctl restart nginx

ok "Nginx 配置完成"
}

###########################################################
# Backend systemd
###########################################################

create_backend_service() {

cat > /etc/systemd/system/gpc-backend.service <<EOF
[Unit]
Description=GPC Backend
After=network.target

[Service]
Type=simple
WorkingDirectory=${GPC_ROOT}/backend

ExecStart=${GPC_ROOT}/venv/bin/uvicorn \
main:app \
--host 0.0.0.0 \
--port ${BACKEND_PORT}

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gpc-backend
}

###########################################################
# Frontend systemd
###########################################################

create_frontend_service() {

cat > /etc/systemd/system/gpc-frontend.service <<EOF
[Unit]
Description=GPC Frontend
After=network.target

[Service]
Type=simple
WorkingDirectory=${GPC_ROOT}/frontend

ExecStart=${GPC_ROOT}/venv/bin/streamlit run \
app.py \
--server.port=${FRONTEND_PORT} \
--server.address=0.0.0.0

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gpc-frontend
}

###########################################################
# gpc command
###########################################################

create_gpc_command() {

cat > /usr/local/bin/gpc <<'EOF'
#!/usr/bin/env bash

while true; do

clear

echo "================================="
echo " GPC2H 管理面板"
echo "================================="
echo ""
echo "1. 服务状态"
echo "2. 后端日志"
echo "3. 前端日志"
echo "4. 重启服务"
echo "5. Redis状态"
echo "6. PostgreSQL状态"
echo "7. 当前连接"
echo "8. 备份"
echo "9. repair"
echo "0. 退出"
echo ""

read -rp "选择: " NUM

case "$NUM" in

1)
systemctl status gpc-backend --no-pager
systemctl status gpc-frontend --no-pager
;;

2)
journalctl -u gpc-backend -f
;;

3)
journalctl -u gpc-frontend -f
;;

4)
systemctl restart gpc-backend
systemctl restart gpc-frontend
systemctl restart nginx
;;

5)
redis-cli ping
;;

6)
systemctl status postgresql --no-pager
;;

7)
ss -tnp
;;

8)
tar zcf /opt/gpc/backups/gpc_$(date +%F_%H-%M).tar.gz /opt/gpc
echo "备份完成"
;;

9)
systemctl restart gpc-backend
systemctl restart gpc-frontend
systemctl restart redis-server
systemctl restart postgresql
systemctl restart nginx
echo "repair 完成"
;;

0)
exit 0
;;

*)
echo "错误"
;;
esac

read -rp "回车继续..."
done
EOF

chmod +x /usr/local/bin/gpc

ok "gpc 命令创建完成"
}

###########################################################
# Firewall
###########################################################

setup_firewall() {

    info "配置防火墙"

    ufw allow 22/tcp
    ufw allow ${HTTPS_PORT}/tcp

    ufw --force enable

    ok "防火墙配置完成"
}

###########################################################
# 启动
###########################################################

start_services() {

    systemctl restart gpc-backend
    systemctl restart gpc-frontend
    systemctl restart nginx

    ok "服务启动完成"
}

###########################################################
# 最终信息
###########################################################

final_info() {

echo ""
echo "================================================="
echo " GPC2H 安装完成"
echo "================================================="
echo ""
echo "访问地址:"
echo "https://${DOMAIN}:${HTTPS_PORT}"
echo ""
echo "管理员:"
echo "用户: ${ADMIN_USER}"
echo "密码: ${ADMIN_PASS}"
echo ""
echo "快捷命令:"
echo "gpc"
echo ""
echo "根目录:"
echo "${GPC_ROOT}"
echo ""
echo "================================================="
echo ""
}

###########################################################
# 主流程
###########################################################

main() {

    check_system

    input_config

    install_base

    create_dirs

    create_venv

    install_python_packages

    setup_postgresql

    setup_redis

    create_env

    create_backend

    create_frontend

    install_acme

    issue_ssl

    create_nginx

    create_backend_service

    create_frontend_service

    create_gpc_command

    setup_firewall

    start_services

    final_info
}

main
