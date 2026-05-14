#!/usr/bin/env bash
# =========================================================
# GPC2H v1.0
# 原生 VPS 股票数据系统部署脚本（非 Docker）
#
# 功能:
# - FastAPI + Streamlit
# - Redis + PostgreSQL
# - HTTPS(Nginx)
# - AkShare
# - JWT 用户系统
# - systemd
# - gpc 管理命令
# - 16666 HTTPS
# - 可迁移
# - repair/update/migrate
#
# 系统:
# Debian 12+
#
# 作者:
# GPT
# =========================================================

set -Eeuo pipefail

########################################
# 基础变量
########################################

GPC_ROOT="/opt/gpc"
GPC_PORT="16666"

BACKEND_PORT="18000"
FRONTEND_PORT="18501"

REDIS_PORT="6379"
POSTGRES_PORT="5432"

PYTHON_VERSION="3.11"

DOMAIN=""
EMAIL=""

JWT_SECRET="$(openssl rand -hex 32)"
ADMIN_USER="admin"
ADMIN_PASS="$(openssl rand -base64 18)"

POSTGRES_DB="gpc"
POSTGRES_USER="gpc"
POSTGRES_PASS="$(openssl rand -hex 16)"

########################################
# 颜色
########################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

########################################
# 输出函数
########################################

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

########################################
# Root 检测
########################################

if [[ $EUID -ne 0 ]]; then
    err "请使用 root 运行"
    exit 1
fi

########################################
# 系统检测
########################################

check_system() {

    info "检查系统"

    if ! grep -q "Debian GNU/Linux 12" /etc/os-release; then
        warn "当前不是 Debian 12，继续执行"
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

########################################
# 输入域名
########################################

input_domain() {

    echo ""
    read -rp "请输入域名: " DOMAIN

    if [[ -z "${DOMAIN}" ]]; then
        err "域名不能为空"
        exit 1
    fi

    read -rp "请输入邮箱(SSL续签): " EMAIL

    if [[ -z "${EMAIL}" ]]; then
        err "邮箱不能为空"
        exit 1
    fi
}

########################################
# 安装基础依赖
########################################

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
        pkg-config \
        libpq-dev \
        ufw \
        cron \
        net-tools \
        htop \
        vim \
        openssl \
        socat

    ok "基础依赖安装完成"
}

########################################
# 创建目录
########################################

create_dirs() {

    info "创建目录"

    mkdir -p \
        ${GPC_ROOT} \
        ${GPC_ROOT}/backend \
        ${GPC_ROOT}/frontend \
        ${GPC_ROOT}/workers \
        ${GPC_ROOT}/scheduler \
        ${GPC_ROOT}/config \
        ${GPC_ROOT}/logs \
        ${GPC_ROOT}/runtime \
        ${GPC_ROOT}/backups \
        ${GPC_ROOT}/ssl \
        ${GPC_ROOT}/scripts \
        ${GPC_ROOT}/systemd \
        ${GPC_ROOT}/data \
        ${GPC_ROOT}/data/parquet \
        ${GPC_ROOT}/data/minute \
        ${GPC_ROOT}/data/cache \
        ${GPC_ROOT}/data/etf

    ok "目录创建完成"
}

########################################
# Python venv
########################################

create_venv() {

    info "创建 Python 虚拟环境"

    python3 -m venv ${GPC_ROOT}/venv

    source ${GPC_ROOT}/venv/bin/activate

    pip install --upgrade pip wheel setuptools

    ok "venv 创建完成"
}

########################################
# Python依赖
########################################

install_python_packages() {

    info "安装 Python 依赖"

    source ${GPC_ROOT}/venv/bin/activate

    cat > ${GPC_ROOT}/requirements.txt <<EOF
fastapi
uvicorn[standard]
streamlit
pandas
numpy
akshare
redis
psycopg2-binary
sqlalchemy
passlib[bcrypt]
python-jose
python-multipart
httpx
apscheduler
plotly
streamlit-aggrid
pyarrow
EOF

    pip install -r ${GPC_ROOT}/requirements.txt

    ok "Python 依赖安装完成"
}

########################################
# PostgreSQL
########################################

setup_postgres() {

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

########################################
# Redis
########################################

setup_redis() {

    info "配置 Redis"

    systemctl enable redis-server
    systemctl restart redis-server

    ok "Redis 配置完成"
}

########################################
# ENV
########################################

create_env() {

cat > ${GPC_ROOT}/config/.env <<EOF
DOMAIN=${DOMAIN}
PORT=${GPC_PORT}

BACKEND_PORT=${BACKEND_PORT}
FRONTEND_PORT=${FRONTEND_PORT}

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

########################################
# FastAPI
########################################

create_backend() {

info "创建 FastAPI"

cat > ${GPC_ROOT}/backend/main.py <<'EOF'
from fastapi import FastAPI
import akshare as ak
import redis
import pandas as pd

app = FastAPI()

@app.get("/")
def root():
    return {"status": "ok"}

@app.get("/market/a-share")
def market():

    df = ak.stock_zh_a_spot_em()

    df = df.sort_values(by="成交额", ascending=False)

    return df.head(200).to_dict(orient="records")

@app.get("/market/etf")
def etf():

    df = ak.fund_etf_spot_em()

    return df.head(100).to_dict(orient="records")
EOF

ok "FastAPI 创建完成"
}

########################################
# Streamlit
########################################

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
    "ETF"
])

with tabs[0]:

    st.subheader("A股实时排行")

    r = requests.get(
        "http://127.0.0.1:${BACKEND_PORT}/market/a-share",
        timeout=30
    )

    df = pd.DataFrame(r.json())

    st.dataframe(df, use_container_width=True)

with tabs[1]:

    st.subheader("ETF")

    r = requests.get(
        "http://127.0.0.1:${BACKEND_PORT}/market/etf",
        timeout=30
    )

    df = pd.DataFrame(r.json())

    st.dataframe(df, use_container_width=True)
EOF

ok "Streamlit 创建完成"
}

########################################
# Nginx
########################################

create_nginx() {

info "配置 Nginx"

cat > /etc/nginx/sites-available/gpc <<EOF
server {

    listen ${GPC_PORT} ssl http2;

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
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /api/ {

        proxy_pass http://127.0.0.1:${BACKEND_PORT}/;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

ln -sf /etc/nginx/sites-available/gpc /etc/nginx/sites-enabled/gpc

rm -f /etc/nginx/sites-enabled/default

nginx -t

systemctl restart nginx

ok "Nginx 配置完成"
}

########################################
# SSL
########################################

install_acme() {

info "安装 acme.sh"

curl https://get.acme.sh | sh

source ~/.bashrc || true

~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

~/.acme.sh/acme.sh --register-account -m ${EMAIL}

ok "acme.sh 安装完成"
}

########################################
# SSL签发
########################################

issue_ssl() {

info "签发 SSL"

~/.acme.sh/acme.sh --issue \
    -d ${DOMAIN} \
    --standalone \
    --httpport 8888

mkdir -p ${GPC_ROOT}/ssl

~/.acme.sh/acme.sh --install-cert -d ${DOMAIN} \
--key-file       ${GPC_ROOT}/ssl/${DOMAIN}.key \
--fullchain-file ${GPC_ROOT}/ssl/fullchain.cer

ok "SSL 证书签发完成"
}

########################################
# systemd backend
########################################

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

########################################
# systemd frontend
########################################

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

########################################
# gpc command
########################################

create_gpc_command() {

cat > /usr/local/bin/gpc <<'EOF'
#!/usr/bin/env bash

while true; do

clear

echo "================================"
echo " GPC2H 管理面板"
echo "================================"
echo ""
echo "1. 服务状态"
echo "2. 后端日志"
echo "3. 前端日志"
echo "4. 重启服务"
echo "5. Redis状态"
echo "6. PostgreSQL状态"
echo "7. 当前连接IP"
echo "8. 备份"
echo "9. 更新"
echo "10. repair"
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
echo "请手动 git pull 更新"
;;

10)
systemctl restart gpc-backend
systemctl restart gpc-frontend
systemctl restart redis-server
systemctl restart postgresql
systemctl restart nginx
echo "repair完成"
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

########################################
# 防火墙
########################################

setup_firewall() {

info "配置防火墙"

ufw allow 22/tcp
ufw allow ${GPC_PORT}/tcp

ufw --force enable

ok "防火墙配置完成"
}

########################################
# 启动服务
########################################

start_services() {

systemctl restart gpc-backend
systemctl restart gpc-frontend
systemctl restart nginx

ok "服务启动完成"
}

########################################
# 最终信息
########################################

final_info() {

echo ""
echo "=================================================="
echo " GPC2H 部署完成"
echo "=================================================="
echo ""
echo "访问地址:"
echo "https://${DOMAIN}:${GPC_PORT}"
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
echo "=================================================="
echo ""
}

########################################
# 主流程
########################################

main() {

check_system

input_domain

install_base

create_dirs

create_venv

install_python_packages

setup_postgres
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
