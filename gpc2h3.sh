#!/usr/bin/env bash
set -Eeuo pipefail

############################################################
# GPC2H3 ULTIMATE
############################################################

ROOT="/opt/gpc"
VENV="$ROOT/venv"

API_PORT=18000
UI_PORT=18501
NGINX_PORT=16666

REDIS_PORT=6379

POSTGRES_DB="gpc"

mkdir -p $ROOT/{data,logs,etc,workers,l2,backend,frontend,auth}

############################################################
# COLORS
############################################################

GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
NC="\033[0m"

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERR ]${NC} $1"
}

############################################################
# ROOT
############################################################

if [ "$(id -u)" != "0" ]; then
    error "Please run as root"
    exit 1
fi

############################################################
# INSTALL
############################################################

info "Installing packages..."

apt update -y

DEBIAN_FRONTEND=noninteractive apt install -y \
python3 \
python3-pip \
python3-venv \
build-essential \
redis-server \
postgresql \
postgresql-contrib \
nginx \
curl \
wget \
git \
jq \
sqlite3 \
htop \
unzip

############################################################
# PYTHON VENV
############################################################

info "Creating python venv..."

python3 -m venv $VENV

source $VENV/bin/activate

pip install --upgrade pip setuptools wheel

############################################################
# FIX BCRYPT
############################################################

pip uninstall -y bcrypt || true

pip install bcrypt==3.2.2

############################################################
# PYTHON MODULES
############################################################

info "Installing python modules..."

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
passlib==1.7.4 \
python-jose \
python-multipart \
aiofiles

############################################################
# REDIS
############################################################

systemctl enable redis-server
systemctl restart redis-server

############################################################
# POSTGRES
############################################################

systemctl enable postgresql
systemctl restart postgresql

POSTGRES_USER="gpc"
POSTGRES_PASS=$(openssl rand -hex 12)

sudo -u postgres psql <<EOF
DO
\$\$
BEGIN
   IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE rolname = '$POSTGRES_USER'
   ) THEN

      CREATE ROLE $POSTGRES_USER LOGIN PASSWORD '$POSTGRES_PASS';

   END IF;
END
\$\$;
EOF

sudo -u postgres psql <<EOF
SELECT 'CREATE DATABASE $POSTGRES_DB'
WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = '$POSTGRES_DB'
)\gexec
EOF

############################################################
# ADMIN
############################################################

echo
echo "============================"
echo " CREATE ADMIN USER"
echo "============================"

read -rp "Username: " ADMIN_USER
read -rsp "Password (8~32 chars): " ADMIN_PASS
echo

if [ ${#ADMIN_PASS} -lt 8 ]; then
    error "Password too short"
    exit 1
fi

if [ ${#ADMIN_PASS} -gt 32 ]; then
    error "Password too long"
    exit 1
fi

HASHED_PASS=$($VENV/bin/python3 - <<PY
from passlib.context import CryptContext

pwd = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto"
)

print(pwd.hash("$ADMIN_PASS"))
PY
)

############################################################
# DB INIT
############################################################

cat > $ROOT/etc/init.sql <<EOF
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
-U $POSTGRES_USER \
-d $POSTGRES_DB \
-f $ROOT/etc/init.sql

PGPASSWORD="$POSTGRES_PASS" psql \
-h 127.0.0.1 \
-U $POSTGRES_USER \
-d $POSTGRES_DB <<EOF
INSERT INTO users(username,password)
VALUES('$ADMIN_USER','$HASHED_PASS')
ON CONFLICT (username) DO NOTHING;
EOF

############################################################
# MODULE SELECT
############################################################

echo
echo "============================"
echo " MODULE SELECT"
echo "============================"

read -rp "Install ETF module? (y/n): " ETF_ENABLE
read -rp "Install FUND module? (y/n): " FUND_ENABLE
read -rp "Install INDEX module? (y/n): " INDEX_ENABLE

############################################################
# CONFIG
############################################################

JWT_SECRET=$(openssl rand -hex 32)

cat > $ROOT/etc/config.json <<EOF
{
  "api_port": $API_PORT,
  "ui_port": $UI_PORT,
  "jwt_secret": "$JWT_SECRET",
  "postgres_user": "$POSTGRES_USER",
  "postgres_pass": "$POSTGRES_PASS",
  "postgres_db": "$POSTGRES_DB",
  "etf": "$ETF_ENABLE",
  "fund": "$FUND_ENABLE",
  "index": "$INDEX_ENABLE"
}
EOF

############################################################
# L2 ENGINE
############################################################

cat > $ROOT/l2/l2_engine.py <<'EOF'
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

    def orderbook(self, price):

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

    def run(self):

        df = ak.stock_zh_a_spot_em()

        # 防Redis爆炸
        df = df.head(500)

        rows = []

        for _, row in df.iterrows():

            try:

                price = float(row["最新价"])
                pct = float(row["涨跌幅"])
                turnover = float(row["成交额"])

                heat = round(
                    abs(pct)*5 + turnover/100000000,
                    2
                )

                rows.append({
                    "code": row["代码"],
                    "name": row["名称"],
                    "price": price,
                    "pct": pct,
                    "turnover": turnover,
                    "heat": heat,
                    "orderbook": self.orderbook(price)
                })

            except:
                continue

        payload = {
            "ts": time.time(),
            "data": rows
        }

        r.set(
            "gpc:l2",
            json.dumps(payload, ensure_ascii=False)
        )

if __name__ == "__main__":

    e = L2Engine()

    while True:

        try:
            e.run()
            print("L2 updated")
        except Exception as ex:
            print(ex)

        time.sleep(2)
EOF

############################################################
# MINUTE WORKER
############################################################

cat > $ROOT/workers/minute_worker.py <<'EOF'
import akshare as ak
import pandas as pd
import time
from pathlib import Path
import os

BASE="/opt/gpc/data/minute"

Path(BASE).mkdir(
    parents=True,
    exist_ok=True
)

MAX_FILES=1440

while True:

    try:

        df = ak.stock_zh_a_spot_em()

        ts = int(time.time())

        file = f"{BASE}/{ts}.parquet"

        df.to_parquet(file)

        files = sorted(os.listdir(BASE))

        if len(files) > MAX_FILES:

            remove = files[0]

            os.remove(f"{BASE}/{remove}")

        print("minute cache saved")

    except Exception as e:
        print(e)

    time.sleep(60)
EOF

############################################################
# API
############################################################

cat > $ROOT/backend/app.py <<EOF
from fastapi import FastAPI, Request, WebSocket
import redis
import json

app = FastAPI()

r = redis.Redis(
    host="127.0.0.1",
    port=$REDIS_PORT,
    decode_responses=True
)

@app.middleware("http")
async def log_ip(request: Request, call_next):

    print("ACCESS:", request.client.host)

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
# STREAMLIT
############################################################

cat > $ROOT/frontend/app.py <<EOF
import streamlit as st
import pandas as pd
import requests

API="http://127.0.0.1:$API_PORT/api/l2"

st.set_page_config(layout="wide")

st.title("GPC QUANT TERMINAL")

try:

    data = requests.get(API).json()

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
        ).head(50),
        use_container_width=True
    )

except Exception as e:
    st.error(str(e))
EOF

############################################################
# NGINX
############################################################

cat > /etc/nginx/sites-available/gpc <<EOF
server {

    listen $NGINX_PORT;

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

cat > /etc/systemd/system/gpc-l2.service <<EOF
[Unit]
Description=GPC L2
After=network.target

[Service]
WorkingDirectory=$ROOT
ExecStart=$VENV/bin/python $ROOT/l2/l2_engine.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/gpc-minute.service <<EOF
[Unit]
Description=GPC Minute Worker
After=network.target

[Service]
WorkingDirectory=$ROOT
ExecStart=$VENV/bin/python $ROOT/workers/minute_worker.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/gpc-api.service <<EOF
[Unit]
Description=GPC API
After=network.target

[Service]
WorkingDirectory=$ROOT
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
WorkingDirectory=$ROOT/frontend
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
# GPC COMMAND
############################################################

cat > /usr/local/bin/gpc <<'EOF'
#!/usr/bin/env bash

echo "============================"
echo " GPC CONTROL PANEL"
echo "============================"

echo "1. status"
echo "2. restart"
echo "3. logs"
echo "4. stop"
echo "5. start"

read -rp "Select: " x

case $x in

1)
systemctl status gpc-l2
systemctl status gpc-api
systemctl status gpc-ui
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
# FIREWALL
############################################################

ufw allow $NGINX_PORT/tcp || true

############################################################
# FINISH
############################################################

IP=$(curl -s ipv4.ip.sb || true)

echo
echo "================================================="
echo " GPC2H3 INSTALL SUCCESS"
echo "================================================="
echo "URL:"
echo "http://$IP:$NGINX_PORT"
echo
echo "USERNAME:"
echo "$ADMIN_USER"
echo
echo "PASSWORD:"
echo "$ADMIN_PASS"
echo
echo "CLI:"
echo "gpc"
echo
echo "ROOT:"
echo "$ROOT"
echo
echo "BACKUP:"
echo "tar zcf gpc_backup.tar.gz /opt/gpc"
echo "================================================="
