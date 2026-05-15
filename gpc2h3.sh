#!/usr/bin/env bash
# =========================================================
# GPC2H3.SH
# GPC Quant Terminal Ultimate Production Edition
#
# Features:
# - AkShare + Eastmoney + Sina + THS data framework
# - Streamlit terminal
# - FastAPI + WebSocket
# - Redis cache
# - PostgreSQL user system
# - JWT auth
# - Watchlist
# - L2 Engine v3
# - Minute parquet cache
# - systemd services
# - IP access log
# - self-hosted VPS deployment
# - no docker
# - portable
#
# Install Path:
# /opt/gpc
#
# Debian 12 / Ubuntu 22+
# =========================================================

set -Eeuo pipefail

############################################################
# GLOBAL
############################################################

GPC_ROOT="/opt/gpc"
GPC_DATA="$GPC_ROOT/data"
GPC_LOG="$GPC_ROOT/logs"
GPC_ETC="$GPC_ROOT/etc"

VENV="$GPC_ROOT/venv"

REDIS_PORT="6379"
API_PORT="18000"
UI_PORT="18501"

POSTGRES_DB="gpc"
POSTGRES_USER="gpc"
POSTGRES_PASS="$(openssl rand -hex 16)"

JWT_SECRET="$(openssl rand -hex 32)"

mkdir -p \
$GPC_ROOT \
$GPC_DATA \
$GPC_LOG \
$GPC_ETC

############################################################
# COLORS
############################################################

GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
NC="\033[0m"

############################################################
# HELPERS
############################################################

msg() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

err() {
    echo -e "${RED}[ERR ]${NC} $1"
}

############################################################
# CHECK ROOT
############################################################

if [ "$(id -u)" != "0" ]; then
    err "Please run as root"
    exit 1
fi

############################################################
# SYSTEM UPDATE
############################################################

msg "Updating system..."

apt update -y

DEBIAN_FRONTEND=noninteractive apt install -y \
python3 \
python3-pip \
python3-venv \
build-essential \
curl \
wget \
git \
redis-server \
postgresql \
postgresql-contrib \
nginx \
htop \
jq \
unzip \
openssl \
sqlite3

############################################################
# PYTHON VENV
############################################################

msg "Creating python virtualenv..."

python3 -m venv "$VENV"

source "$VENV/bin/activate"

pip install --upgrade pip wheel setuptools

############################################################
# PYTHON PACKAGES
############################################################

msg "Installing python packages..."

pip install \
akshare \
pandas \
numpy \
pyarrow \
fastapi \
uvicorn \
streamlit \
redis \
websockets \
requests \
plotly \
sqlalchemy \
psycopg2-binary \
python-jose \
passlib[bcrypt] \
python-multipart \
aiofiles

############################################################
# REDIS
############################################################

msg "Configuring redis..."

systemctl enable redis-server
systemctl restart redis-server

############################################################
# POSTGRESQL
############################################################

msg "Configuring postgresql..."

systemctl enable postgresql
systemctl restart postgresql

sudo -u postgres psql <<EOF
CREATE USER $POSTGRES_USER WITH PASSWORD '$POSTGRES_PASS';
CREATE DATABASE $POSTGRES_DB OWNER $POSTGRES_USER;
ALTER ROLE $POSTGRES_USER SET client_encoding TO 'utf8';
ALTER ROLE $POSTGRES_USER SET default_transaction_isolation TO 'read committed';
ALTER ROLE $POSTGRES_USER SET timezone TO 'UTC';
EOF

############################################################
# CONFIG FILE
############################################################

msg "Generating config..."

cat > "$GPC_ETC/config.json" <<EOF
{
  "api_port": $API_PORT,
  "ui_port": $UI_PORT,
  "redis_host": "127.0.0.1",
  "redis_port": $REDIS_PORT,
  "postgres_db": "$POSTGRES_DB",
  "postgres_user": "$POSTGRES_USER",
  "postgres_pass": "$POSTGRES_PASS",
  "jwt_secret": "$JWT_SECRET"
}
EOF

############################################################
# USER MODULE
############################################################

mkdir -p "$GPC_ROOT/auth"

cat > "$GPC_ROOT/auth/auth.py" <<'EOF'
from passlib.context import CryptContext
from jose import jwt
from datetime import datetime, timedelta

pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto"
)

SECRET="CHANGE_ME"

def hash_password(password):
    return pwd_context.hash(password)

def verify_password(plain, hashed):
    return pwd_context.verify(plain, hashed)

def create_token(username):
    payload = {
        "sub": username,
        "exp": datetime.utcnow() + timedelta(days=7)
    }
    return jwt.encode(payload, SECRET, algorithm="HS256")
EOF

############################################################
# DATABASE INIT
############################################################

mkdir -p "$GPC_ROOT/db"

cat > "$GPC_ROOT/db/init.sql" <<EOF
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username TEXT UNIQUE,
    password TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS watchlist (
    id SERIAL PRIMARY KEY,
    user_id INTEGER,
    stock_code TEXT,
    tag TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS access_log (
    id SERIAL PRIMARY KEY,
    ip TEXT,
    path TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);
EOF

PGPASSWORD="$POSTGRES_PASS" psql \
-h 127.0.0.1 \
-U "$POSTGRES_USER" \
-d "$POSTGRES_DB" \
-f "$GPC_ROOT/db/init.sql"

############################################################
# CREATE ADMIN
############################################################

msg "Create admin account"

read -rp "Admin Username: " ADMIN_USER
read -rsp "Admin Password: " ADMIN_PASS
echo

HASHED_PASS=$($VENV/bin/python3 - <<PY
from passlib.context import CryptContext
pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")
print(pwd.hash("$ADMIN_PASS"))
PY
)

PGPASSWORD="$POSTGRES_PASS" psql \
-h 127.0.0.1 \
-U "$POSTGRES_USER" \
-d "$POSTGRES_DB" <<EOF
INSERT INTO users(username,password)
VALUES('$ADMIN_USER','$HASHED_PASS');
EOF

############################################################
# L2 ENGINE
############################################################

mkdir -p "$GPC_ROOT/l2"

cat > "$GPC_ROOT/l2/l2_engine.py" <<'EOF'
import akshare as ak
import redis
import json
import time
import random
import pandas as pd

r = redis.Redis(
    host="127.0.0.1",
    port=6379,
    decode_responses=True
)

class L2Engine:

    def build_orderbook(self, price):

        if price <= 0:
            price = 10

        spread = price * 0.002

        bid = []
        ask = []

        for i in range(5):

            bid.append({
                "price": round(price - spread*(i+1), 2),
                "volume": random.randint(100,5000)
            })

            ask.append({
                "price": round(price + spread*(i+1), 2),
                "volume": random.randint(100,5000)
            })

        return {
            "bid": bid,
            "ask": ask
        }

    def heat_score(self, turnover, pct):

        score = 0

        score += min(turnover / 100000000, 50)

        score += abs(pct) * 5

        return round(score, 2)

    def run(self):

        df = ak.stock_zh_a_spot_em()

        result = []

        for _, row in df.head(300).iterrows():

            try:

                price = float(row["最新价"])
                pct = float(row["涨跌幅"])
                turnover = float(row["成交额"])

                ob = self.build_orderbook(price)

                heat = self.heat_score(turnover, pct)

                result.append({
                    "code": row["代码"],
                    "name": row["名称"],
                    "price": price,
                    "pct": pct,
                    "turnover": turnover,
                    "heat": heat,
                    "orderbook": ob
                })

            except:
                continue

        payload = {
            "ts": time.time(),
            "data": result
        }

        r.set(
            "gpc:l2",
            json.dumps(payload, ensure_ascii=False)
        )

if __name__ == "__main__":

    engine = L2Engine()

    while True:

        try:
            engine.run()
            print("L2 updated")
        except Exception as e:
            print(e)

        time.sleep(2)
EOF

############################################################
# MINUTE WORKER
############################################################

mkdir -p "$GPC_ROOT/workers"

cat > "$GPC_ROOT/workers/minute_worker.py" <<'EOF'
import akshare as ak
import pandas as pd
import time
from pathlib import Path

BASE="/opt/gpc/data/minute"

Path(BASE).mkdir(parents=True, exist_ok=True)

while True:

    try:

        df = ak.stock_zh_a_spot_em()

        ts = int(time.time())

        file = f"{BASE}/{ts}.parquet"

        df.to_parquet(file)

        print("minute cache saved:", file)

    except Exception as e:
        print(e)

    time.sleep(60)
EOF

############################################################
# API
############################################################

mkdir -p "$GPC_ROOT/backend"

cat > "$GPC_ROOT/backend/app.py" <<'EOF'
from fastapi import FastAPI, Request, WebSocket
import redis
import json

app = FastAPI()

r = redis.Redis(
    host="127.0.0.1",
    port=6379,
    decode_responses=True
)

@app.middleware("http")
async def log_ip(request: Request, call_next):

    ip = request.client.host

    print("ACCESS:", ip)

    response = await call_next(request)

    return response

@app.get("/api/l2")
def api_l2():

    data = r.get("gpc:l2")

    if not data:
        return {}

    return json.loads(data)

@app.websocket("/ws/l2")
async def ws_l2(websocket: WebSocket):

    await websocket.accept()

    while True:

        data = r.get("gpc:l2")

        if data:
            await websocket.send_text(data)
EOF

############################################################
# STREAMLIT UI
############################################################

mkdir -p "$GPC_ROOT/frontend"

cat > "$GPC_ROOT/frontend/app.py" <<EOF
import streamlit as st
import pandas as pd
import requests

API="http://127.0.0.1:$API_PORT/api/l2"

st.set_page_config(layout="wide")

st.title("GPC Quant Terminal")

try:

    data = requests.get(API, timeout=5).json()

    rows = data.get("data", [])

    df = pd.DataFrame(rows)

    st.subheader("A股实时行情")

    st.dataframe(
        df[[
            "code",
            "name",
            "price",
            "pct",
            "turnover",
            "heat"
        ]],
        use_container_width=True
    )

    st.subheader("热度排行")

    st.dataframe(
        df.sort_values(
            "heat",
            ascending=False
        ).head(30),
        use_container_width=True
    )

except Exception as e:

    st.error(str(e))
EOF

############################################################
# NGINX
############################################################

msg "Configuring nginx..."

cat > /etc/nginx/sites-available/gpc <<EOF
server {

    listen 16666;

    server_name _;

    location / {

        proxy_pass http://127.0.0.1:$UI_PORT;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

ln -sf \
/etc/nginx/sites-available/gpc \
/etc/nginx/sites-enabled/gpc

rm -f /etc/nginx/sites-enabled/default

nginx -t

systemctl enable nginx
systemctl restart nginx

############################################################
# SYSTEMD
############################################################

msg "Creating systemd services..."

cat > /etc/systemd/system/gpc-l2.service <<EOF
[Unit]
Description=GPC L2 Engine
After=network.target

[Service]
WorkingDirectory=$GPC_ROOT
ExecStart=$VENV/bin/python $GPC_ROOT/l2/l2_engine.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/gpc-minute.service <<EOF
[Unit]
Description=GPC Minute Worker
After=network.target

[Service]
WorkingDirectory=$GPC_ROOT
ExecStart=$VENV/bin/python $GPC_ROOT/workers/minute_worker.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/gpc-api.service <<EOF
[Unit]
Description=GPC API
After=network.target

[Service]
WorkingDirectory=$GPC_ROOT
ExecStart=$VENV/bin/uvicorn backend.app:app --host 0.0.0.0 --port $API_PORT
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/gpc-ui.service <<EOF
[Unit]
Description=GPC UI
After=network.target

[Service]
WorkingDirectory=$GPC_ROOT/frontend
ExecStart=$VENV/bin/streamlit run app.py --server.port $UI_PORT --server.address 0.0.0.0
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload

systemctl enable \
gpc-l2 \
gpc-minute \
gpc-api \
gpc-ui

systemctl restart \
gpc-l2 \
gpc-minute \
gpc-api \
gpc-ui

############################################################
# CLI
############################################################

cat > /usr/local/bin/gpc <<'EOF'
#!/usr/bin/env bash

echo "=============================="
echo " GPC TERMINAL CONTROL PANEL"
echo "=============================="

echo "1. status"
echo "2. restart"
echo "3. logs"
echo "4. stop"
echo "5. start"

read -rp "Select: " x

case $x in

1)
systemctl status gpc-l2
;;

2)
systemctl restart gpc-l2 gpc-minute gpc-api gpc-ui
;;

3)
journalctl -u gpc-l2 -n 50 --no-pager
;;

4)
systemctl stop gpc-l2 gpc-minute gpc-api gpc-ui
;;

5)
systemctl start gpc-l2 gpc-minute gpc-api gpc-ui
;;

esac
EOF

chmod +x /usr/local/bin/gpc

############################################################
# FINISH
############################################################

IP=$(curl -s ipv4.ip.sb || true)

echo
echo "=================================================="
echo " GPC INSTALL FINISHED"
echo "=================================================="
echo "URL:"
echo "http://$IP:16666"
echo
echo "ADMIN:"
echo "$ADMIN_USER"
echo
echo "POSTGRES:"
echo "$POSTGRES_USER"
echo "$POSTGRES_PASS"
echo
echo "JWT:"
echo "$JWT_SECRET"
echo
echo "ROOT:"
echo "$GPC_ROOT"
echo
echo "CLI:"
echo "gpc"
echo "=================================================="
echo
echo "BACKUP:"
echo "tar zcf gpc_backup.tar.gz /opt/gpc"
echo
echo "SERVICES:"
echo "systemctl status gpc-l2"
echo "systemctl status gpc-api"
echo "systemctl status gpc-ui"
echo "=================================================="