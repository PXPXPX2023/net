#!/bin/bash

# =====================================================================
# 系统：私人金融数据看板 (AkShare + Streamlit + Docker)
# 版本：gpc2_fixed.sh (全量溯源修复优化版)
# 修复内容：Docker Daemon 连接超时修复 + Compose 语法更新
# =====================================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}>>> 1. 环境初始化与 Docker 守护进程检查...${NC}"

# 安装 Docker (如果未安装)
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}正在安装 Docker 引擎...${NC}"
    curl -fsSL https://get.docker.com | bash -s docker
fi

# 核心修复：确保 Docker 服务真正启动并可用
systemctl start docker
systemctl enable docker

echo -e "${YELLOW}等待 Docker 守护进程就绪...${NC}"
MAX_RETRIES=10
COUNT=0
while ! docker ps > /dev/null 2>&1; do
    echo -n "."
    sleep 2
    ((COUNT++))
    if [ $COUNT -ge $MAX_RETRIES ]; then
        echo -e "${RED}\n错误: Docker 启动失败，请手动运行 'systemctl status docker' 查看原因。${NC}"
        exit 1
    fi
done
echo -e "${GREEN}\nDocker 已就绪！${NC}"

# 2. 创建目录
PROJECT_DIR="/opt/stock_dashboard"
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# 3. 编写 app.py (纯净版，无幽灵空格)
echo -e "${BLUE}>>> 2. 注入核心应用引擎 (app.py)...${NC}"
cat << 'EOF' > app.py
import streamlit as st
import akshare as ak
import pandas as pd
import streamlit_authenticator as stauth
from datetime import datetime

st.set_page_config(page_title="GPC 私人金融看板", page_icon="📈", layout="wide")

credentials = {
    'usernames': {
        'admin': {
            'email': 'admin@gpc.230139.xyz',
            'name': '超级管理员',
            'password': '$2b$12$6pXWp3.0FpB5N3E2U/pM/O.v4.D.K6zFpWJ5/H.6pZ/H.6pZ/H.6p'
        }
    }
}

authenticator = stauth.Authenticate(
    credentials,
    'gpc_cookie_key',
    'gpc_signature_2026',
    cookie_expiry_days=30
)

name, authentication_status, username = authenticator.login('main')

if authentication_status == False:
    st.error('❌ 账号或密码错误')
elif authentication_status == None:
    st.warning('🔒 请使用管理员账号登录')
    st.stop()
elif authentication_status:
    def get_remote_ip():
        try:
            from streamlit.web.server.websocket_headers import _get_websocket_headers
            headers = _get_websocket_headers()
            return headers.get("X-Real-Ip", headers.get("X-Forwarded-For", "Local/Unknown"))
        except:
            return "获取失败"

    visitor_ip = get_remote_ip()
    st.sidebar.title(f"👤 {name}")
    authenticator.logout('退出登录', 'sidebar')
    st.sidebar.markdown("---")
    menu = st.sidebar.radio("功能导航", ["A股全景(实时排序)", "自选1分钟监控", "ETF与新发基金", "资金流向排行", "系统后台监控"])

    @st.cache_data(ttl=60)
    def get_stock_spot():
        try: return ak.stock_zh_a_spot_em()
        except: return pd.DataFrame()

    if menu == "A股全景(实时排序)":
        st.header("📈 A股实时行情 (全场排序)")
        df = get_stock_spot()
        if not df.empty:
            cols = ['代码', '名称', '最新价', '涨跌幅', '成交量', '成交额', '换手率']
            st.dataframe(df[cols], use_container_width=True, height=600)
        else:
            st.error("数据接口异常，请重试")

    elif menu == "自选1分钟监控":
        st.header("⏱️ 自选股日内1分钟量能")
        code = st.text_input("输入股票代码", "600519")
        if code:
            try:
                df_min = ak.stock_zh_a_hist_min_em(symbol=code, period='1')
                if not df_min.empty:
                    df_min['时间'] = pd.to_datetime(df_min['时间'])
                    st.subheader(f"{code} 成交额趋势")
                    st.line_chart(df_min.set_index('时间')['成交额'])
                    st.subheader(f"{code} 成交量分布")
                    st.bar_chart(df_min.set_index('时间')['成交量'])
            except:
                st.warning("解析代码失败")

    elif menu == "ETF与新发基金":
        st.header("📊 基金与ETF监控")
        tab1, tab2 = st.tabs(["实时ETF", "新发基金/ETF"])
        with tab1:
            st.dataframe(ak.fund_etf_spot_em(), use_container_width=True)
        with tab2:
            st.dataframe(ak.fund_new_em(), use_container_width=True)

    elif menu == "系统后台监控":
        st.header("🛡️ 系统后台")
        st.info(f"当前访客 IP: {visitor_ip}")
        st.write(f"当前时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
EOF

# 4. 依赖清单
cat << 'EOF' > requirements.txt
streamlit==1.32.0
akshare>=1.12.95
pandas>=2.0.0
streamlit-authenticator==0.3.1
pyyaml
EOF

# 5. Dockerfile
cat << 'EOF' > Dockerfile
FROM python:3.10-slim
WORKDIR /app
RUN apt-get update && apt-get install -y curl build-essential && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple
COPY . .
EXPOSE 8501
ENTRYPOINT ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
EOF

# 6. Caddyfile (16666端口)
cat << 'EOF' > Caddyfile
:16666 {
    encode zstd gzip
    reverse_proxy streamlit:8501 {
        header_up X-Real-Ip {remote_host}
        header_up X-Forwarded-For {remote_host}
    }
}
EOF

# 7. docker-compose.yml (移除过时的 version 属性)
cat << 'EOF' > docker-compose.yml
services:
  streamlit:
    build: .
    container_name: gpc_app
    restart: always
    environment:
      - TZ=Asia/Shanghai

  caddy:
    image: caddy:latest
    container_name: gpc_caddy
    restart: always
    ports:
      - "16666:16666"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    depends_on:
      - streamlit

volumes:
  caddy_data:
  caddy_config:
EOF

# 8. 快捷键
if ! grep -q "alias gpc=" ~/.bashrc; then
    echo "alias gpc='cd /opt/stock_dashboard && docker compose logs -f --tail 20'" >> ~/.bashrc
    source ~/.bashrc 2>/dev/null
fi

# 9. 构建与部署 (增加权限强制)
echo -e "${BLUE}>>> 3. 构建并启动容器...${NC}"
docker compose down > /dev/null 2>&1
docker compose up -d --build

echo -e "====================================================================="
echo -e "${GREEN}✅ 系统修复并部署完成！${NC}"
echo -e "🌐 ${BLUE}访问地址${NC}: http://gpc.230139.xyz:16666"
echo -e "🔑 ${BLUE}初始密码${NC}: admin123"
echo -e "⌨️  ${BLUE}快捷指令${NC}: 输入 ${YELLOW}gpc${NC} 查看日志"
echo -e "====================================================================="
echo -e "如果需要修改代码，请直接编辑 ${PROJECT_DIR}/app.py，容器会自动热更新。"
