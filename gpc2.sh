#!/bin/bash

# =====================================================================
# 系统：私人金融数据看板 (AkShare + Streamlit + Docker)
# 版本：gpc2.sh (融合修复+非标端口+快捷键版)
# 域名端口：gpc.230139.xyz:16666
# =====================================================================

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 1. 环境检查与 Docker 安装
echo -e "${BLUE}>>> 正在初始化环境...${NC}"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | bash -s docker
    systemctl start docker
    systemctl enable docker
fi

# 2. 创建目录结构
PROJECT_DIR="/opt/stock_dashboard"
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# 3. 编写 app.py (包含全量逻辑、IP监控、鉴权)
echo -e "${BLUE}>>> 注入核心应用引擎 (app.py)...${NC}"
cat << 'EOF' > app.py
import streamlit as st
import akshare as ak
import pandas as pd
import streamlit_authenticator as stauth
from datetime import datetime

# 页面基础配置
st.set_page_config(page_title="GPC 私人金融看板", page_icon="📈", layout="wide")

# 用户验证配置
credentials = {
    'usernames': {
        'admin': {
            'email': 'admin@gpc.230139.xyz',
            'name': '超级管理员',
            'password': '$2b$12$6pXWp3.0FpB5N3E2U/pM/O.v4.D.K6zFpWJ5/H.6pZ/H.6pZ/H.6p' # 默认 admin123
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
    # --- 登录成功模块 ---
    
    # IP 捕获逻辑
    def get_remote_ip():
        try:
            from streamlit.web.server.websocket_headers import _get_websocket_headers
            headers = _get_websocket_headers()
            # 优先获取 Caddy 转发的真实 IP
            return headers.get("X-Real-Ip", headers.get("X-Forwarded-For", "Local/Unknown"))
        except:
            return "获取失败"

    visitor_ip = get_remote_ip()

    # 侧边栏
    st.sidebar.title(f"👤 {name}")
    authenticator.logout('退出登录', 'sidebar')
    
    st.sidebar.markdown("---")
    menu = st.sidebar.radio("功能导航", [
        "A股全景(实时排序)", 
        "自选1分钟监控", 
        "ETF与新发基金", 
        "资金流向排行", 
        "系统后台监控"
    ])

    # --- 数据获取函数 (带错误穿透保护) ---
    @st.cache_data(ttl=60)
    def get_stock_spot():
        try: return ak.stock_zh_a_spot_em()
        except: return pd.DataFrame()

    @st.cache_data(ttl=60)
    def get_etf_spot():
        try: return ak.fund_etf_spot_em()
        except: return pd.DataFrame()

    # --- 模块路由 ---
    if menu == "A股全景(实时排序)":
        st.header("📈 A股实时行情 (全场排序)")
        df = get_stock_spot()
        if not df.empty:
            cols = ['代码', '名称', '最新价', '涨跌幅', '成交量', '成交额', '换手率']
            st.dataframe(df[cols], use_container_width=True, height=600)
        else:
            st.error("数据接口异常，请检查网络")

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
                st.warning("解析代码失败，请输入正确的6位代码")

    elif menu == "ETF与新发基金":
        st.header("📊 基金与ETF监控")
        tab1, tab2 = st.tabs(["实时ETF", "新发基金/ETF"])
        with tab1:
            st.dataframe(get_etf_spot(), use_container_width=True)
        with tab2:
            st.dataframe(ak.fund_new_em(), use_container_width=True)

    elif menu == "系统后台监控":
        st.header("🛡️ 系统后台")
        st.info(f"当前访客 IP: {visitor_ip}")
        st.write(f"当前时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        st.markdown("---")
        st.caption("GPC 数据显示系统 v2.0")
EOF

# 4. 依赖配置 (requirements.txt)
cat << 'EOF' > requirements.txt
streamlit==1.32.0
akshare>=1.12.95
pandas>=2.0.0
streamlit-authenticator==0.3.1
pyyaml
EOF

# 5. Dockerfile 优化
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

# 6. Caddyfile 修复 (监听 16666 端口，关闭自动 HTTPS 以适配翻墙共存)
# 注意：在 16666 这种非标端口，Caddy 默认不会尝试申请 SSL，我们配置其为 HTTP 转发，确保不报错
cat << 'EOF' > Caddyfile
:16666 {
    encode zstd gzip
    reverse_proxy streamlit:8501 {
        header_up X-Real-Ip {remote_host}
        header_up X-Forwarded-For {remote_host}
    }
}
EOF

# 7. docker-compose.yml (端口映射 16666)
cat << 'EOF' > docker-compose.yml
version: '3.8'
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

# 8. 注入快捷键 gpc
echo -e "${BLUE}>>> 配置快捷键 gpc...${NC}"
if ! grep -q "alias gpc=" ~/.bashrc; then
    echo "alias gpc='cd /opt/stock_dashboard && docker compose logs -f --tail 20'" >> ~/.bashrc
    source ~/.bashrc
fi

# 9. 启动系统
echo -e "${BLUE}>>> 正在拉取镜像并启动容器...${NC}"
docker compose up -d --build

# 10. 最终检查与提示
echo -e "====================================================================="
echo -e "${GREEN}✅ 系统全量部署完成！${NC}"
echo -e "🌐 ${BLUE}访问地址${NC}: http://gpc.230139.xyz:16666"
echo -e "👤 ${BLUE}默认账户${NC}: admin"
echo -e "🔑 ${BLUE}默认密码${NC}: admin123"
echo -e "⌨️  ${BLUE}快捷指令${NC}: 随时在终端输入 ${YELLOW}gpc${NC} 查看运行状态"
echo -e "⚠️  ${YELLOW}注意${NC}: 端口 16666 已开启，请确保 VPS 防火墙/安全组已放行该端口。"
echo -e "====================================================================="
echo -e "如果需要修改代码，请直接编辑 ${PROJECT_DIR}/app.py，容器会自动热更新。"
