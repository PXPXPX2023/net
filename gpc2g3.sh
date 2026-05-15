#!/usr/bin/env bash
set -Eeuo pipefail

############################################################
# GPC2G3 ULTIMATE (Enhanced Version)
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
# COLORS & LOGGING
############################################################

GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
NC="\033[0m"

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERR ]${NC} $1"; }

if [ "$(id -u)" != "0" ]; then
    error "Please run as root"
    exit 1
fi

############################################################
# INSTALL SYSTEM DEPENDENCIES
############################################################

info "Installing packages..."
apt update -y
DEBIAN_FRONTEND=noninteractive apt install -y \
    python3 python3-pip python3-venv build-essential \
    redis-server postgresql postgresql-contrib \
    nginx curl wget git jq sqlite3 htop unzip

############################################################
# PYTHON VENV & MODULES
############################################################

info "Creating python venv..."
python3 -m venv $VENV
source $VENV/bin/activate
pip install --upgrade pip setuptools wheel

info "Fixing bcrypt dependency..."
pip uninstall -y bcrypt || true
pip install bcrypt==3.2.2

info "Installing Python modules..."
pip install \
    akshare pandas numpy pyarrow fastapi uvicorn streamlit \
    redis websockets requests plotly sqlalchemy psycopg2-binary \
    passlib==1.7.4 python-jose python-multipart aiofiles PyJWT

############################################################
# REDIS & POSTGRES CONFIGURATION
############################################################

systemctl enable redis-server
systemctl restart redis-server

systemctl enable postgresql
systemctl restart postgresql

POSTGRES_USER="gpc"
POSTGRES_PASS=$(openssl rand -hex 12)

sudo -u postgres psql <<EOF
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$POSTGRES_USER') THEN
      CREATE ROLE $POSTGRES_USER LOGIN PASSWORD '$POSTGRES_PASS';
   END IF;
END \$\$;
EOF

sudo -u postgres psql <<EOF
SELECT 'CREATE DATABASE $POSTGRES_DB'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$POSTGRES_DB')\gexec
EOF

############################################################
# ADMIN SETUP
############################################################

echo
echo "============================"
echo " CREATE ADMIN USER"
echo "============================"
read -rp "Admin Username: " ADMIN_USER
read -rsp "Admin Password (8~32 chars): " ADMIN_PASS
echo

if [ ${#ADMIN_PASS} -lt 8 ] || [ ${#ADMIN_PASS} -gt 32 ]; then
    error "Password length must be 8~32"
    exit 1
fi

HASHED_PASS=$($VENV/bin/python3 - <<PY
from passlib.context import CryptContext
pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")
print(pwd.hash("$ADMIN_PASS"))
PY
)

############################################################
# DATABASE INIT
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
    username TEXT,
    stock_code TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(username, stock_code)
);

CREATE TABLE IF NOT EXISTS access_log (
    id SERIAL PRIMARY KEY,
    ip TEXT,
    path TEXT,
    username TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);
EOF

PGPASSWORD="$POSTGRES_PASS" psql -h 127.0.0.1 -U $POSTGRES_USER -d $POSTGRES_DB -f $ROOT/etc/init.sql

PGPASSWORD="$POSTGRES_PASS" psql -h 127.0.0.1 -U $POSTGRES_USER -d $POSTGRES_DB <<EOF
INSERT INTO users(username,password) VALUES('$ADMIN_USER','$HASHED_PASS') ON CONFLICT (username) DO NOTHING;
EOF

############################################################
# MODULE SELECTION
############################################################

echo
echo "============================"
echo " DATA MODULE SELECTION"
echo "============================"
read -rp "Install ETF module? (y/n): " ETF_ENABLE
read -rp "Install FUND module? (y/n): " FUND_ENABLE
read -rp "Install INDEX module? (y/n): " INDEX_ENABLE
read -rp "Install Capital Flow (资金量) module? (y/n): " CAPITAL_ENABLE

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
  "index": "$INDEX_ENABLE",
  "capital": "$CAPITAL_ENABLE"
}
EOF

############################################################
# L2 ENGINE (MARKET DATA WORKER)
############################################################

cat > $ROOT/l2/l2_engine.py <<'EOF'
import akshare as ak
import redis
import json
import time
import pandas as pd

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

with open("/opt/gpc/etc/config.json", "r") as f:
    config = json.load(f)

def fetch_and_store(name, fetch_func, process_func):
    try:
        df = fetch_func()
        data = process_func(df)
        payload = {"ts": time.time(), "data": data}
        r.set(f"gpc:l2:{name}", json.dumps(payload, ensure_ascii=False))
        print(f"[{name}] updated {len(data)} records")
    except Exception as e:
        print(f"[{name}] Error: {e}")

def process_a_stock(df):
    df.rename(columns={"代码": "code", "名称": "name", "最新价": "price", "涨跌幅": "pct", "成交额": "turnover"}, inplace=True)
    df['heat'] = abs(df['pct']) * 5 + df['turnover'] / 100000000
    df = df.fillna(0)
    return df[["code", "name", "price", "pct", "turnover", "heat"]].to_dict('records')

def process_etf(df):
    df.rename(columns={"代码": "code", "名称": "name", "最新价": "price", "涨跌幅": "pct", "成交额": "turnover"}, inplace=True)
    df = df.fillna(0)
    return df[["code", "name", "price", "pct", "turnover"]].to_dict('records')

def process_index(df):
    df.rename(columns={"代码": "code", "名称": "name", "最新价": "price", "涨跌幅": "pct", "成交额": "turnover"}, inplace=True)
    df = df.fillna(0)
    return df[["code", "name", "price", "pct", "turnover"]].to_dict('records')

while True:
    fetch_and_store("stock", ak.stock_zh_a_spot_em, process_a_stock)
    
    if config.get("etf", "n").lower() == "y":
        fetch_and_store("etf", ak.fund_etf_spot_em, process_etf)
        fetch_and_store("new_fund", ak.fund_new_found_em, lambda df: df.fillna("").to_dict('records'))
        
    if config.get("index", "n").lower() == "y":
        fetch_and_store("index", ak.stock_zh_index_spot_em, process_index)

    if config.get("capital", "n").lower() == "y":
        fetch_and_store("capital", ak.stock_market_fund_flow, lambda df: df.fillna(0).to_dict('records'))
        
    time.sleep(5)
EOF

############################################################
# MINUTE WORKER (WATCHLIST 1-MIN DATA)
############################################################

cat > $ROOT/workers/minute_worker.py <<'EOF'
import akshare as ak
import psycopg2
import redis
import json
import time
from datetime import datetime

with open("/opt/gpc/etc/config.json", "r") as f:
    config = json.load(f)

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)

def get_db():
    return psycopg2.connect(
        host="127.0.0.1",
        database=config['postgres_db'],
        user=config['postgres_user'],
        password=config['postgres_pass']
    )

while True:
    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute("SELECT DISTINCT stock_code FROM watchlist")
        codes = [row[0] for row in cur.fetchall()]
        cur.close()
        conn.close()

        for code in codes:
            try:
                # 抓取该代码最新的1分钟数据
                df = ak.stock_zh_a_hist_min_em(symbol=code, period="1", adjust="qq")
                if not df.empty:
                    latest = df.iloc[-1]
                    data = {
                        "time": str(latest["时间"]),
                        "open": float(latest["开盘"]),
                        "close": float(latest["收盘"]),
                        "high": float(latest["最高"]),
                        "low": float(latest["最低"]),
                        "volume": float(latest["成交量"]),
                        "turnover": float(latest["成交额"])
                    }
                    r.set(f"gpc:min:{code}", json.dumps(data), ex=300)
            except Exception as e:
                print(f"Failed to fetch min data for {code}: {e}")
                
            time.sleep(0.5) # 防止频繁请求触发风控
        print(f"[{datetime.now()}] Minute worker updated {len(codes)} symbols.")
    except Exception as e:
        print(f"Minute Worker Error: {e}")
        
    time.sleep(60)
EOF

############################################################
# BACKEND API (FASTAPI)
############################################################

cat > $ROOT/backend/app.py <<'EOF'
from fastapi import FastAPI, Request, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel
import redis, json, jwt, datetime, psycopg2
from passlib.context import CryptContext

with open("/opt/gpc/etc/config.json", "r") as f:
    config = json.load(f)

app = FastAPI()
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

def get_db_connection():
    return psycopg2.connect(
        host="127.0.0.1", database=config['postgres_db'],
        user=config['postgres_user'], password=config['postgres_pass']
    )

@app.middleware("http")
async def log_ip(request: Request, call_next):
    client_ip = request.headers.get("X-Real-IP") or request.client.host
    path = request.url.path
    
    # 获取可能存在的 Auth Header 以提取 username
    username = "anonymous"
    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.startswith("Bearer "):
        try:
            token = auth_header.split(" ")[1]
            payload = jwt.decode(token, config['jwt_secret'], algorithms=["HS256"])
            username = payload.get("sub", "unknown")
        except:
            pass

    # 后台入库审计
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("INSERT INTO access_log (ip, path, username) VALUES (%s, %s, %s)", (client_ip, path, username))
        conn.commit()
        cur.close()
        conn.close()
    except Exception as e:
        print("Log error:", e)

    return await call_next(request)

@app.post("/login")
def login(form_data: OAuth2PasswordRequestForm = Depends()):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT password FROM users WHERE username = %s", (form_data.username,))
    row = cur.fetchone()
    cur.close()
    conn.close()

    if not row or not pwd_context.verify(form_data.password, row[0]):
        raise HTTPException(status_code=400, detail="Incorrect username or password")
    
    expire = datetime.datetime.utcnow() + datetime.timedelta(hours=24)
    token = jwt.encode({"sub": form_data.username, "exp": expire}, config['jwt_secret'], algorithm="HS256")
    return {"access_token": token, "token_type": "bearer"}

async def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, config['jwt_secret'], algorithms=["HS256"])
        return payload.get("sub")
    except:
        raise HTTPException(status_code=401, detail="Invalid token")

@app.get("/api/data/{module}")
def get_market_data(module: str, user: str = Depends(get_current_user)):
    data = r.get(f"gpc:l2:{module}")
    return json.loads(data) if data else {"data": []}

class WatchItem(BaseModel):
    code: str

@app.post("/api/watchlist")
def add_watchlist(item: WatchItem, user: str = Depends(get_current_user)):
    conn = get_db_connection()
    cur = conn.cursor()
    try:
        cur.execute("INSERT INTO watchlist (username, stock_code) VALUES (%s, %s) ON CONFLICT DO NOTHING", (user, item.code))
        conn.commit()
    finally:
        cur.close()
        conn.close()
    return {"status": "ok"}

@app.get("/api/watchlist")
def get_watchlist(user: str = Depends(get_current_user)):
    conn = get_db_connection()
    cur = conn.cursor()
    cur.execute("SELECT stock_code FROM watchlist WHERE username = %s", (user,))
    codes = [row[0] for row in cur.fetchall()]
    cur.close()
    conn.close()
    
    result = []
    for code in codes:
        min_data = r.get(f"gpc:min:{code}")
        result.append({
            "code": code,
            "min_data": json.loads(min_data) if min_data else None
        })
    return {"data": result}
EOF

############################################################
# FRONTEND (STREAMLIT)
############################################################

cat > $ROOT/frontend/app.py <<'EOF'
import streamlit as st
import pandas as pd
import requests
import json

with open("/opt/gpc/etc/config.json", "r") as f:
    config = json.load(f)

API_BASE = f"http://127.0.0.1:{config['api_port']}"

st.set_page_config(page_title="GPC Terminal", layout="wide")

if "token" not in st.session_state:
    st.session_state.token = None

def login():
    st.markdown("### 系统访问受限 - 请登录")
    with st.form("login_form"):
        user = st.text_input("Username")
        pwd = st.text_input("Password", type="password")
        if st.form_submit_button("登录"):
            res = requests.post(f"{API_BASE}/login", data={"username": user, "password": pwd})
            if res.status_code == 200:
                st.session_state.token = res.json()["access_token"]
                st.success("登录成功！")
                st.rerun()
            else:
                st.error("账号或密码错误")

def fetch_data(endpoint):
    headers = {"Authorization": f"Bearer {st.session_state.token}"}
    try:
        res = requests.get(f"{API_BASE}{endpoint}", headers=headers)
        if res.status_code == 200:
            return res.json().get("data", [])
        elif res.status_code == 401:
            st.session_state.token = None
            st.rerun()
    except:
        return []
    return []

if not st.session_state.token:
    login()
else:
    st.sidebar.title("GPC Terminal")
    if st.sidebar.button("退出登录"):
        st.session_state.token = None
        st.rerun()

    menu = ["全市场行情 (A股)", "自选股与高频盯盘"]
    if config.get("etf", "n") == "y":
        menu.extend(["ETF行情", "新发基金"])
    if config.get("index", "n") == "y":
        menu.append("指数行情")
    if config.get("capital", "n") == "y":
        menu.append("大盘资金流向")

    choice = st.sidebar.selectbox("模块导航", menu)

    if choice == "全市场行情 (A股)":
        st.title("实时 A股")
        data = fetch_data("/api/data/stock")
        if data:
            df = pd.DataFrame(data)
            # 全量A股，开启原生的点击列头排序
            st.dataframe(df, use_container_width=True, height=600)

    elif choice == "自选股与高频盯盘":
        st.title("自选池监控")
        c1, c2 = st.columns([1, 4])
        with c1:
            with st.form("add_watch"):
                code = st.text_input("输入股票代码 (如: 600519)")
                if st.form_submit_button("加入自选"):
                    requests.post(
                        f"{API_BASE}/api/watchlist", 
                        json={"code": code}, 
                        headers={"Authorization": f"Bearer {st.session_state.token}"}
                    )
                    st.success("已添加")
        with c2:
            st.subheader("1分钟级别量价追踪")
            w_data = fetch_data("/api/watchlist")
            if w_data:
                rows = []
                for item in w_data:
                    md = item.get("min_data")
                    if md:
                        rows.append({
                            "代码": item["code"],
                            "最新时间": md["time"],
                            "1分钟收盘价": md["close"],
                            "1分钟成交量(手)": md["volume"],
                            "1分钟成交额(元)": md["turnover"]
                        })
                    else:
                        rows.append({"代码": item["code"], "最新时间": "等待拉取数据..."})
                st.dataframe(pd.DataFrame(rows), use_container_width=True)
                
    elif choice == "ETF行情":
        st.title("实时 ETF")
        st.dataframe(pd.DataFrame(fetch_data("/api/data/etf")), use_container_width=True)
        
    elif choice == "新发基金":
        st.title("新发基金")
        st.dataframe(pd.DataFrame(fetch_data("/api/data/new_fund")), use_container_width=True)

    elif choice == "指数行情":
        st.title("实时 指数")
        st.dataframe(pd.DataFrame(fetch_data("/api/data/index")), use_container_width=True)

    elif choice == "大盘资金流向":
        st.title("大盘资金流向")
        st.dataframe(pd.DataFrame(fetch_data("/api/data/capital")), use_container_width=True)
EOF

############################################################
# NGINX (WITH WEBSOCKET SUPPORT FOR STREAMLIT)
############################################################

cat > /etc/nginx/sites-available/gpc <<EOF
server {
    listen $NGINX_PORT;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:$UI_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        
        # WEBSOCKET SUPPORT NEEDED FOR STREAMLIT
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
    }
}
EOF

ln -sf /etc/nginx/sites-available/gpc /etc/nginx/sites-enabled/gpc
rm -f /etc/nginx/sites-enabled/default
nginx -t

systemctl enable nginx
systemctl restart nginx

############################################################
# SYSTEMD SERVICES
############################################################

cat > /etc/systemd/system/gpc-l2.service <<EOF
[Unit]
Description=GPC L2 Engine
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
Description=GPC API Backend
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
Description=GPC Streamlit Frontend
After=network.target

[Service]
WorkingDirectory=$ROOT/frontend
ExecStart=$VENV/bin/streamlit run app.py --server.port $UI_PORT --server.address 0.0.0.0 --server.headless true
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable gpc-l2 gpc-minute gpc-api gpc-ui
systemctl restart gpc-l2 gpc-minute gpc-api gpc-ui

############################################################
# CLI TOOL (GPC) - ADVANCED MANAGEMENT PANEL
############################################################

cat > /usr/local/bin/gpc <<'EOF'
#!/usr/bin/env bash
ROOT="/opt/gpc"
VENV="$ROOT/venv"

echo "======================================"
echo " GPC TERMINAL CONTROL PANEL "
echo "======================================"
echo " 1. 查看组件运行状态 (Status)"
echo " 2. 重启所有服务 (Restart All)"
echo " 3. 查看运行日志 (Logs)"
echo " 4. 停止所有服务 (Stop All)"
echo " 5. 启动所有服务 (Start All)"
echo " -----------------------------------"
echo " 6. [用户管理] 新增账号"
echo " 7. [用户管理] 修改密码"
echo " 8. [安全审计] 查看最近的IP访问记录"
echo "======================================"
read -rp "请选择 (1-8): " x

case $x in
1)
    systemctl status gpc-l2 gpc-api gpc-ui gpc-minute --no-pager
    ;;
2)
    systemctl restart gpc-l2 gpc-minute gpc-api gpc-ui
    echo "重启完毕."
    ;;
3)
    journalctl -u gpc-l2 -u gpc-api -u gpc-ui -n 50 --no-pager
    ;;
4)
    systemctl stop gpc-l2 gpc-minute gpc-api gpc-ui
    echo "已停止."
    ;;
5)
    systemctl start gpc-l2 gpc-minute gpc-api gpc-ui
    echo "已启动."
    ;;
6)
    read -rp "输入新用户名: " NEW_USER
    read -rsp "输入新密码: " NEW_PASS
    echo
    HASH=$($VENV/bin/python3 -c "from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt'], deprecated='auto').hash('$NEW_PASS'))")
    PGPASSWORD=$(jq -r '.postgres_pass' $ROOT/etc/config.json)
    PGUSER=$(jq -r '.postgres_user' $ROOT/etc/config.json)
    PGDB=$(jq -r '.postgres_db' $ROOT/etc/config.json)
    psql -h 127.0.0.1 -U "$PGUSER" -d "$PGDB" -c "INSERT INTO users(username, password) VALUES('$NEW_USER', '$HASH');"
    echo "用户 $NEW_USER 添加成功！"
    ;;
7)
    read -rp "输入要修改的用户名: " MOD_USER
    read -rsp "输入新密码: " MOD_PASS
    echo
    HASH=$($VENV/bin/python3 -c "from passlib.context import CryptContext; print(CryptContext(schemes=['bcrypt'], deprecated='auto').hash('$MOD_PASS'))")
    PGPASSWORD=$(jq -r '.postgres_pass' $ROOT/etc/config.json)
    PGUSER=$(jq -r '.postgres_user' $ROOT/etc/config.json)
    PGDB=$(jq -r '.postgres_db' $ROOT/etc/config.json)
    psql -h 127.0.0.1 -U "$PGUSER" -d "$PGDB" -c "UPDATE users SET password='$HASH' WHERE username='$MOD_USER';"
    echo "用户 $MOD_USER 密码修改成功！"
    ;;
8)
    echo "最近 20 条 IP 访问记录："
    PGPASSWORD=$(jq -r '.postgres_pass' $ROOT/etc/config.json)
    PGUSER=$(jq -r '.postgres_user' $ROOT/etc/config.json)
    PGDB=$(jq -r '.postgres_db' $ROOT/etc/config.json)
    psql -h 127.0.0.1 -U "$PGUSER" -d "$PGDB" -c "SELECT created_at, ip, username, path FROM access_log ORDER BY id DESC LIMIT 20;"
    ;;
*)
    echo "无效选项."
    ;;
esac
EOF

chmod +x /usr/local/bin/gpc

############################################################
# FIREWALL & FINISH
############################################################

ufw allow $NGINX_PORT/tcp || true

IP=$(curl -s ipv4.ip.sb || true)

echo
echo "================================================="
echo " GPC2G3 INSTALL SUCCESS "
echo "================================================="
echo "💻 访问地址 (URL): http://$IP:$NGINX_PORT"
echo "👤 初始用户名: $ADMIN_USER"
echo "🔑 初始密码: (你刚才设置的)"
echo "-------------------------------------------------"
echo "⚙️ 后台管理命令: 输入 gpc 唤出控制面板"
echo "   (支持一键新增账号、改密、查IP访问记录)"
echo "📁 安装路径: $ROOT"
echo "================================================="
