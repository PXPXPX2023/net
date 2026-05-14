#!/usr/bin/env bash
# =========================================================
#  GPC2H - 股票数据系统生产级骨架部署脚本
#  Version : v1.0
#  Author  : GPT
#  Target  : Debian 12+
# =========================================================

set -Eeuo pipefail

########################################
# 基础变量
########################################

GPC_ROOT="/opt/gpc"
DOMAIN="gpc.230139.xyz"
HTTPS_PORT="16666"

POSTGRES_PASSWORD="$(openssl rand -hex 16)"
JWT_SECRET="$(openssl rand -hex 32)"

REDIS_PORT="6379"
POSTGRES_PORT="5432"

GPC_USER="gpcadmin"
GPC_PASS="$(openssl rand -base64 18)"

COMPOSE_FILE="${GPC_ROOT}/docker-compose.yml"

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
    echo -e "${GREEN}[OK]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

err() {
    echo -e "${RED}[ERROR]${NC} $1"
}

########################################
# root检测
########################################

if [[ $EUID -ne 0 ]]; then
    err "请使用 root 运行"
    exit 1
fi

########################################
# 系统检测
########################################

check_system() {

    info "检测系统..."

    if ! grep -q "Debian GNU/Linux 12" /etc/os-release; then
        warn "当前不是 Debian 12，继续执行但可能有兼容性问题"
    fi

    ARCH=$(uname -m)

    case "${ARCH}" in
        x86_64|amd64)
            ok "检测到 x86_64"
            ;;
        aarch64|arm64)
            ok "检测到 ARM64"
            ;;
        *)
            err "不支持架构: ${ARCH}"
            exit 1
            ;;
    esac
}

########################################
# 基础依赖
########################################

install_base() {

    info "安装基础依赖..."

    apt-get update -y

    apt-get install -y \
        curl \
        wget \
        git \
        unzip \
        tar \
        vim \
        htop \
        jq \
        openssl \
        gnupg \
        lsb-release \
        ca-certificates \
        software-properties-common \
        apt-transport-https \
        net-tools \
        ufw

    ok "基础依赖安装完成"
}

########################################
# Docker安装
########################################

install_docker() {

    if command -v docker >/dev/null 2>&1; then
        ok "Docker 已安装"
        return
    fi

    info "安装 Docker..."

    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] \
      https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" \
      > /etc/apt/sources.list.d/docker.list

    apt-get update -y

    apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    systemctl enable docker
    systemctl restart docker

    ok "Docker 安装完成"
}

########################################
# 创建目录
########################################

create_dirs() {

    info "创建目录结构..."

    mkdir -p \
        ${GPC_ROOT} \
        ${GPC_ROOT}/backend/app \
        ${GPC_ROOT}/frontend \
        ${GPC_ROOT}/nginx/ssl \
        ${GPC_ROOT}/logs \
        ${GPC_ROOT}/backup \
        ${GPC_ROOT}/redis \
        ${GPC_ROOT}/postgres \
        ${GPC_ROOT}/scripts

    ok "目录创建完成"
}

########################################
# .env
########################################

create_env() {

cat > ${GPC_ROOT}/.env <<EOF
DOMAIN=${DOMAIN}
HTTPS_PORT=${HTTPS_PORT}

POSTGRES_DB=gpc
POSTGRES_USER=gpc
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

JWT_SECRET=${JWT_SECRET}

GPC_USER=${GPC_USER}
GPC_PASS=${GPC_PASS}
EOF

ok ".env 创建完成"
}

########################################
# FastAPI
########################################

create_backend() {

info "创建 FastAPI 后端..."

cat > ${GPC_ROOT}/backend/requirements.txt <<EOF
fastapi
uvicorn[standard]
redis
pandas
akshare
httpx
python-jose
passlib[bcrypt]
sqlalchemy
psycopg2-binary
websockets
apscheduler
EOF

cat > ${GPC_ROOT}/backend/Dockerfile <<EOF
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

cat > ${GPC_ROOT}/backend/app/main.py <<'EOF'
from fastapi import FastAPI
import akshare as ak

app = FastAPI()

@app.get("/")
def root():
    return {"status": "ok"}

@app.get("/market/a-share")
def a_share():

    df = ak.stock_zh_a_spot_em()

    return df.head(50).to_dict(orient="records")
EOF

ok "FastAPI 创建完成"
}

########################################
# Streamlit
########################################

create_frontend() {

info "创建 Streamlit 前端..."

cat > ${GPC_ROOT}/frontend/requirements.txt <<EOF
streamlit
pandas
requests
plotly
streamlit-autorefresh
EOF

cat > ${GPC_ROOT}/frontend/Dockerfile <<EOF
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
EOF

cat > ${GPC_ROOT}/frontend/app.py <<'EOF'
import streamlit as st
import pandas as pd
import requests

st.set_page_config(
    page_title="GPC",
    layout="wide"
)

st.title("GPC 股票系统")

try:

    r = requests.get("http://backend:8000/market/a-share", timeout=20)

    data = r.json()

    df = pd.DataFrame(data)

    st.dataframe(df, use_container_width=True)

except Exception as e:
    st.error(str(e))
EOF

ok "Streamlit 创建完成"
}

########################################
# Nginx
########################################

create_nginx() {

info "创建 Nginx 配置..."

cat > ${GPC_ROOT}/nginx/nginx.conf <<EOF
events {}

http {

    server {

        listen ${HTTPS_PORT} ssl;

        server_name ${DOMAIN};

        ssl_certificate /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key /etc/nginx/ssl/privkey.pem;

        location / {

            proxy_pass http://frontend:8501;

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }

        location /api/ {

            proxy_pass http://backend:8000/;

            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }
    }
}
EOF

ok "Nginx 配置完成"
}

########################################
# 自签SSL
########################################

create_ssl() {

info "生成 SSL 证书..."

openssl req -x509 -nodes \
    -days 3650 \
    -newkey rsa:2048 \
    -keyout ${GPC_ROOT}/nginx/ssl/privkey.pem \
    -out ${GPC_ROOT}/nginx/ssl/fullchain.pem \
    -subj "/CN=${DOMAIN}"

ok "SSL 生成完成"
}

########################################
# Docker Compose
########################################

create_compose() {

info "创建 docker-compose..."

cat > ${COMPOSE_FILE} <<EOF
services:

  nginx:
    image: nginx:latest
    container_name: gpc_nginx
    restart: always
    ports:
      - "${HTTPS_PORT}:${HTTPS_PORT}"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/ssl:/etc/nginx/ssl
    depends_on:
      - frontend
      - backend

  frontend:
    build: ./frontend
    container_name: gpc_frontend
    restart: always

  backend:
    build: ./backend
    container_name: gpc_backend
    restart: always
    depends_on:
      - redis
      - postgres

  redis:
    image: redis:7
    container_name: gpc_redis
    restart: always

  postgres:
    image: postgres:16
    container_name: gpc_postgres
    restart: always
    environment:
      POSTGRES_DB: gpc
      POSTGRES_USER: gpc
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - ./postgres:/var/lib/postgresql/data

EOF

ok "docker-compose 创建完成"
}

########################################
# systemd
########################################

create_systemd() {

info "创建 systemd 服务..."

cat > /etc/systemd/system/gpc.service <<EOF
[Unit]
Description=GPC Stock System
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${GPC_ROOT}

ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down

TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gpc.service

ok "systemd 创建完成"
}

########################################
# gpc命令
########################################

create_gpc_command() {

info "创建 gpc 命令..."

cat > /usr/local/bin/gpc <<'EOF'
#!/usr/bin/env bash

ROOT="/opt/gpc"

menu() {

echo ""
echo "========== GPC =========="
echo "1. 查看状态"
echo "2. 重启服务"
echo "3. 查看日志"
echo "4. 停止服务"
echo "5. 启动服务"
echo "6. Docker状态"
echo "7. 在线IP"
echo "0. 退出"
echo ""
read -rp "选择: " num

case "$num" in

1)
docker compose -f ${ROOT}/docker-compose.yml ps
;;

2)
docker compose -f ${ROOT}/docker-compose.yml restart
;;

3)
docker compose -f ${ROOT}/docker-compose.yml logs -f
;;

4)
docker compose -f ${ROOT}/docker-compose.yml down
;;

5)
docker compose -f ${ROOT}/docker-compose.yml up -d
;;

6)
docker stats
;;

7)
ss -tnp
;;

0)
exit 0
;;

*)
echo "错误"
;;
esac
}

while true; do
menu
done
EOF

chmod +x /usr/local/bin/gpc

ok "gpc 命令创建完成"
}

########################################
# 防火墙
########################################

setup_firewall() {

info "配置防火墙..."

ufw allow 22/tcp
ufw allow ${HTTPS_PORT}/tcp

ufw --force enable

ok "防火墙配置完成"
}

########################################
# 启动
########################################

start_services() {

info "启动服务..."

cd ${GPC_ROOT}

docker compose up -d --build

systemctl restart gpc.service

ok "服务启动完成"
}

########################################
# 输出信息
########################################

final_info() {

echo ""
echo "=================================================="
echo " GPC 股票系统部署完成"
echo "=================================================="
echo ""
echo "访问地址:"
echo "https://${DOMAIN}:${HTTPS_PORT}"
echo ""
echo "管理员:"
echo "用户: ${GPC_USER}"
echo "密码: ${GPC_PASS}"
echo ""
echo "PostgreSQL:"
echo "密码: ${POSTGRES_PASSWORD}"
echo ""
echo "JWT:"
echo "${JWT_SECRET}"
echo ""
echo "快捷命令:"
echo "gpc"
echo ""
echo "目录:"
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
install_base
install_docker

create_dirs
create_env

create_backend
create_frontend

create_nginx
create_ssl

create_compose

create_systemd
create_gpc_command

setup_firewall

start_services

final_info
}

main
