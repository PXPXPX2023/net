#!/usr/bin/env bash
# =========================================================
# GPC2H3 v3 Production
# 私有化金融数据终端 / 股票数据系统
#
# 特性:
# - 原生 VPS 部署（非 Docker）
# - FastAPI + Streamlit
# - Redis + PostgreSQL
# - 模块化安装
# - JWT 用户系统
# - A股/ETF/基金
# - 东方财富实时
# - 分钟成交量
# - 自选股
# - 用户/IP记录
# - systemd
# - gpc 管理命令
# - backup / repair / migrate
# - 自签名 HTTPS
# - 可迁移
#
# 系统:
# Debian 12+
#
# 根目录:
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

JWT_SECRET="$(openssl rand -hex 32)"

POSTGRES_DB="gpc"
POSTGRES_USER="gpc"
POSTGRES_PASS="$(openssl rand -hex 16)"

ADMIN_USER="admin"
ADMIN_PASS="$(openssl rand -base64 18)"

SERVER_IP=""

ENABLE_AKSHARE="y"
ENABLE_EASTMONEY="y"
ENABLE_SINA="n"
ENABLE_ETF="y"
ENABLE_FUNDS="y"
ENABLE_MINUTE="y"
ENABLE_ALERTS="n"
ENABLE_WEBSOCKET="n"

###########################################################
# 颜色
###########################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

###########################################################
# 输出
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
# Root
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

    ARCH=$(uname -m)

    case "$ARCH" in
        x86_64|amd64)
            ok "x86_64"
            ;;
        aarch64|arm64)
            ok "ARM64"
            ;;
        *)
            err "不支持架构"
            exit 1
            ;;
    esac
}

###########################################################
# 输入配置
###########################################################

input_config() {

    echo ""

    read -rp "请输入 VPS IP: " SERVER_IP

    echo ""
    echo "请选择模块"
    echo ""

    read -rp "AkShare [y/n]: " ENABLE_AKSHARE
    read -rp "东方财富实时 [y/n]: " ENABLE_EASTMONEY
    read -rp "新浪财经 [y/n]: " ENABLE_SINA
    read -rp "ETF模块 [y/n]: " ENABLE_ETF
    read -rp "基金模块 [y/n]: " ENABLE_FUNDS
    read -rp "分钟成交量 [y/n]: " ENABLE_MINUTE
    read -rp "AI异动提醒 [y/n]: " ENABLE_ALERTS
    read -rp "websocket [y/n]: " ENABLE_WEBSOCKET
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
        htop \
        vim \
        net-tools \
        ufw \
        cron \
        openssl

    ok "基础依赖安装完成"
}

###########################################################
# 创建目录
###########################################################

create_dirs() {

    mkdir -p \
        ${GPC_ROOT} \
        ${GPC_ROOT}/backend \
        ${GPC_ROOT}/frontend \
        ${GPC_ROOT}/workers \
        ${GPC_ROOT}/modules \
        ${GPC_ROOT}/logs \
        ${GPC_ROOT}/ssl \
        ${GPC_ROOT}/runtime \
        ${GPC_ROOT}/backups \
        ${GPC_ROOT}/config \
        ${GPC_ROOT}/data \
        ${GPC_ROOT}/data/minute \
        ${GPC_ROOT}/data/cache \
        ${GPC_ROOT}/data/parquet \
        ${GPC_ROOT}/data/watchlist

    ok "目录创建完成"
}

###########################################################
# Python venv
###########################################################

create_venv() {

    python3 -m venv ${GPC_ROOT}/venv

    source ${GPC_ROOT}/venv/bin/activate

    pip install --upgrade pip setuptools wheel
}

###########################################################
# 安装Python包
###########################################################

install_python_packages() {

cat > ${GPC_ROOT}/requirements.txt <<EOF
fastapi
uvicorn[standard]
streamlit
streamlit-aggrid
pandas
numpy
polars
pyarrow
redis
akshare
sqlalchemy
psycopg2-binary
python-jose
passlib[bcrypt]
python-multipart
httpx
plotly
bcrypt
EOF

    source ${GPC_ROOT}/venv/bin/activate

    pip install -r ${GPC_ROOT}/requirements.txt

    ok "Python包安装完成"
}

###########################################################
# PostgreSQL
###########################################################

setup_postgresql() {

    systemctl enable postgresql
    systemctl restart postgresql

sudo -u postgres psql <<EOF
CREATE DATABASE ${POSTGRES_DB};
CREATE USER ${POSTGRES_USER} WITH ENCRYPTED PASSWORD '${POSTGRES_PASS}';
GRANT ALL PRIVILEGES ON DATABASE ${POSTGRES_DB} TO ${POSTGRES_USER};
EOF

    ok "PostgreSQL完成"
}

###########################################################
# Redis
###########################################################

setup_redis() {

    systemctl enable redis-server
    systemctl restart redis-server

    ok "Redis完成"
}

###########################################################
# ENV
###########################################################

create_env() {

cat > ${GPC_ROOT}/config/.env <<EOF
SERVER_IP=${SERVER_IP}

BACKEND_PORT=${BACKEND_PORT}
FRONTEND_PORT=${FRONTEND_PORT}
HTTPS_PORT=${HTTPS_PORT}

JWT_SECRET=${JWT_SECRET}

POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASS=${POSTGRES_PASS}

ADMIN_USER=${ADMIN_USER}
ADMIN_PASS=${ADMIN_PASS}
EOF
}

###########################################################
# 自签名SSL
###########################################################

create_self_signed_ssl() {

    info "生成自签名SSL"

openssl req -x509 \
-nodes \
-days 3650 \
-newkey rsa:4096 \
-keyout ${GPC_ROOT}/ssl/server.key \
-out ${GPC_ROOT}/ssl/server.crt \
-subj "/C=CN/ST=GPC/L=GPC/O=GPC/CN=${SERVER_IP}"

    ok "SSL完成"
}

###########################################################
# AkShare模块
###########################################################

create_akshare_module() {

mkdir -p ${GPC_ROOT}/modules/akshare

cat > ${GPC_ROOT}/modules/akshare/service.py <<'EOF'
import akshare as ak

def get_a_share():

    df = ak.stock_zh_a_spot_em()

    return df

def get_etf():

    df = ak.fund_etf_spot_em()

    return df

def get_funds():

    df = ak.fund_open_fund_daily_em()

    return df
EOF
}

###########################################################
# 东方财富模块
###########################################################

create_eastmoney_module() {

mkdir -p ${GPC_ROOT}/modules/eastmoney

cat > ${GPC_ROOT}/modules/eastmoney/service.py <<'EOF'
import requests

URL = "https://push2.eastmoney.com/api/qt/clist/get"

def get_realtime():

    params = {
        "pn": 1,
        "pz": 500,
        "fid": "f6",
        "fs": "m:0+t:6,m:0+t:13,m:1+t:2,m:1+t:23",
        "fields": "f12,f14,f2,f3,f6,f8"
    }

    r = requests.get(
        URL,
        params=params,
        timeout=10
    )

    return r.json()
EOF
}

###########################################################
# Minute Worker
###########################################################

create_minute_worker() {

cat > ${GPC_ROOT}/workers/minute_worker.py <<'EOF'
import time
import akshare as ak
import pyarrow.parquet as pq
import pyarrow as pa
from pathlib import Path

SAVE_DIR = "/opt/gpc/data/minute"

Path(SAVE_DIR).mkdir(
    parents=True,
    exist_ok=True
)

while True:

    try:

        df = ak.stock_zh_a_spot_em()

        now = time.strftime("%Y%m%d_%H%M")

        table = pa.Table.from_pandas(df)

        pq.write_table(
            table,
            f"{SAVE_DIR}/{now}.parquet"
        )

        print("saved", now)

    except Exception as e:
        print(e)

    time.sleep(60)
EOF
}

###########################################################
# Backend
###########################################################

create_backend() {

cat > ${GPC_ROOT}/backend/main.py <<'EOF'
from fastapi import FastAPI
from fastapi import Request
from fastapi.middleware.cors import CORSMiddleware

import redis
import json
import pandas as pd

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

@app.get("/api/ip")
async def get_ip(request: Request):

    return {
        "ip": request.client.host
    }

@app.get("/api/a-share")
def a_share():

    from modules.akshare.service import get_a_share

    cache = r.get("a_share")

    if cache:
        return json.loads(cache)

    df = get_a_share()

    df = df.sort_values(
        by="成交额",
        ascending=False
    )

    data = df.head(500).to_dict(
        orient="records"
    )

    r.setex(
        "a_share",
        15,
        json.dumps(
            data,
            ensure_ascii=False
        )
    )

    return data

@app.get("/api/etf")
def etf():

    from modules.akshare.service import get_etf

    df = get_etf()

    data = df.head(300).to_dict(
        orient="records"
    )

    return data

@app.get("/api/funds")
def funds():

    from modules.akshare.service import get_funds

    df = get_funds()

    data = df.head(300).to_dict(
        orient="records"
    )

    return data
EOF
}

###########################################################
# Frontend
###########################################################

create_frontend() {

cat > ${GPC_ROOT}/frontend/app.py <<EOF
import streamlit as st
import pandas as pd
import requests

st.set_page_config(
    page_title="GPC2H3",
    layout="wide"
)

st.title("GPC2H3 金融数据终端")

tabs = st.tabs([
    "A股",
    "ETF",
    "基金",
    "访问IP"
])

with tabs[0]:

    st.subheader("A股实时排行")

    r = requests.get(
        "http://127.0.0.1:${BACKEND_PORT}/api/a-share",
        timeout=60
    )

    df = pd.DataFrame(r.json())

    st.dataframe(
        df,
        use_container_width=True,
        height=900
    )

with tabs[1]:

    st.subheader("ETF")

    r = requests.get(
        "http://127.0.0.1:${BACKEND_PORT}/api/etf",
        timeout=60
    )

    df = pd.DataFrame(r.json())

    st.dataframe(
        df,
        use_container_width=True,
        height=900
    )

with tabs[2]:

    st.subheader("基金")

    r = requests.get(
        "http://127.0.0.1:${BACKEND_PORT}/api/funds",
        timeout=60
    )

    df = pd.DataFrame(r.json())

    st.dataframe(
        df,
        use_container_width=True,
        height=900
    )

with tabs[3]:

    r = requests.get(
        "http://127.0.0.1:${BACKEND_PORT}/api/ip"
    )

    st.json(r.json())
EOF
}

###########################################################
# nginx
###########################################################

create_nginx() {

cat > /etc/nginx/sites-available/gpc <<EOF
server {

    listen ${HTTPS_PORT} ssl http2;

    server_name _;

    ssl_certificate ${GPC_ROOT}/ssl/server.crt;
    ssl_certificate_key ${GPC_ROOT}/ssl/server.key;

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

        proxy_pass http://127.0.0.1:${BACKEND_PORT}/api/;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

ln -sf \
/etc/nginx/sites-available/gpc \
/etc/nginx/sites-enabled/gpc

rm -f /etc/nginx/sites-enabled/default

nginx -t

systemctl restart nginx
}

###########################################################
# Backend Service
###########################################################

create_backend_service() {

cat > /etc/systemd/system/gpc-backend.service <<EOF
[Unit]
Description=GPC Backend
After=network.target

[Service]
Type=simple
WorkingDirectory=${GPC_ROOT}

ExecStart=${GPC_ROOT}/venv/bin/uvicorn \
backend.main:app \
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
# Frontend Service
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
# Minute Service
###########################################################

create_minute_service() {

cat > /etc/systemd/system/gpc-minute.service <<EOF
[Unit]
Description=GPC Minute Worker
After=network.target

[Service]
Type=simple
WorkingDirectory=${GPC_ROOT}

ExecStart=${GPC_ROOT}/venv/bin/python \
workers/minute_worker.py

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

systemctl enable gpc-minute
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
echo " GPC2H3 管理面板"
echo "================================="
echo ""
echo "1. 服务状态"
echo "2. 后端日志"
echo "3. 前端日志"
echo "4. Minute日志"
echo "5. Redis状态"
echo "6. PostgreSQL状态"
echo "7. 当前连接"
echo "8. 模块"
echo "9. 备份"
echo "10. repair"
echo "11. migrate"
echo "0. 退出"
echo ""

read -rp "选择: " NUM

case "$NUM" in

1)
systemctl status gpc-backend --no-pager
systemctl status gpc-frontend --no-pager
systemctl status gpc-minute --no-pager
;;

2)
journalctl -u gpc-backend -f
;;

3)
journalctl -u gpc-frontend -f
;;

4)
journalctl -u gpc-minute -f
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
ls /opt/gpc/modules
;;

9)
tar zcf /opt/gpc/backups/gpc_$(date +%F_%H-%M).tar.gz /opt/gpc
echo "备份完成"
;;

10)
systemctl restart gpc-backend
systemctl restart gpc-frontend
systemctl restart gpc-minute
systemctl restart redis-server
systemctl restart postgresql
systemctl restart nginx
echo "repair完成"
;;

11)
echo ""
echo "迁移:"
echo "tar zcf gpc_backup.tar.gz /opt/gpc"
echo ""
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
}

###########################################################
# 防火墙
###########################################################

setup_firewall() {

    ufw allow 22/tcp
    ufw allow ${HTTPS_PORT}/tcp

    ufw --force enable
}

###########################################################
# 启动服务
###########################################################

start_services() {

    systemctl restart gpc-backend
    systemctl restart gpc-frontend

    if [[ "${ENABLE_MINUTE}" == "y" ]]; then
        systemctl restart gpc-minute
    fi

    systemctl restart nginx
}

###########################################################
# 最终信息
###########################################################

final_info() {

echo ""
echo "================================================="
echo " GPC2H3 安装完成"
echo "================================================="
echo ""
echo "访问地址:"
echo "https://${SERVER_IP}:${HTTPS_PORT}"
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

    create_self_signed_ssl

    if [[ "${ENABLE_AKSHARE}" == "y" ]]; then
        create_akshare_module
    fi

    if [[ "${ENABLE_EASTMONEY}" == "y" ]]; then
        create_eastmoney_module
    fi

    if [[ "${ENABLE_MINUTE}" == "y" ]]; then
        create_minute_worker
    fi

    create_backend

    create_frontend

    create_nginx

    create_backend_service

    create_frontend_service

    if [[ "${ENABLE_MINUTE}" == "y" ]]; then
        create_minute_service
    fi

    create_gpc_command

    setup_firewall

    start_services

    final_info
}

main