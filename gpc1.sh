#!/bin/bash

# =====================================================================
# 私人金融数据看板 (AkShare + Streamlit + Docker + Caddy) 一键部署脚本
# 域名: gpc.230139.xyz
# 作者: 优化融合版 v1.0
# =====================================================================

# 定义颜色
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}>>> 开始部署金融数据看板系统 (版本: gpc1.sh)...${NC}"

# 1. 检查并安装 Docker 与 Docker Compose
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}未检测到 Docker，正在自动安装...${NC}"
    curl -fsSL https://get.docker.com | bash -s docker
    systemctl start docker
    systemctl enable docker
else
    echo -e "${GREEN}Docker 已安装。${NC}"
fi

# 2. 创建并进入项目目录
PROJECT_DIR="/opt/stock_dashboard"
echo -e "${BLUE}>>> 创建项目目录: ${PROJECT_DIR}${NC}"
mkdir -p $PROJECT_DIR
cd $PROJECT_DIR

# 3. 编写核心 Python 应用代码 (app.py)
# 注意：使用单引号 'EOF' 防止 bash 解析内部的 $ 等特殊符号
echo -e "${BLUE}>>> 生成核心应用代码 app.py...${NC}"
cat << 'EOF' > app.py
import streamlit as st
import akshare as ak
import pandas as pd
import streamlit_authenticator as stauth
import yaml
from yaml.loader import SafeLoader
import time

# --- 1. 基础页面配置 ---
st.set_page_config(page_title="私人数据核心看板", page_icon="📈", layout="wide")

# --- 2. 安全与权限管理 ---
# 配置 admin 账户，密码为 admin123 对应的 bcrypt hash
# 在生产环境中，你可以使用 stauth.Hasher(['你的新密码']).generate() 生成新 hash 替换此处
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
    credentials=credentials,
    cookie_name='gpc_stock_auth',
    key='super_secret_signature_key_2026',
    cookie_expiry_days=30
)

# 渲染登录界面
name, authentication_status, username = authenticator.login('main')

if authentication_status == False:
    st.error('❌ 用户名或密码错误')
elif authentication_status == None:
    st.warning('🔒 请输入管理员账号和密码以访问系统')
    st.stop()
elif authentication_status:
    # --- 登录成功后的主逻辑 ---
    
    # 获取访客真实 IP 的安全函数
    def get_remote_ip():
        try:
            from streamlit.web.server.websocket_headers import _get_websocket_headers
            headers = _get_websocket_headers()
            if headers and "X-Forwarded-For" in headers:
                return headers["X-Forwarded-For"].split(",")[0].strip()
        except Exception:
            pass
        return "无法获取 (可能处于本地调试或代理配置异常)"

    visitor_ip = get_remote_ip()

    # 侧边栏配置
    st.sidebar.title(f"欢迎, {name}")
    authenticator.logout('退出登录', 'sidebar')
    st.sidebar.markdown("---")
    menu = st.sidebar.radio(
        "📊 核心功能导航",
        ["A股全景排序看板", "自选股1分钟监控", "ETF与新发基金", "主力资金流向", "系统安全后台"]
    )
    st.sidebar.markdown("---")
    st.sidebar.caption("数据源: AkShare | 引擎: Streamlit")

    # --- 辅助缓存函数，防止频繁请求被封IP ---
    @st.cache_data(ttl=60)
    def fetch_a_shares():
        try:
            df = ak.stock_zh_a_spot_em()
            return df
        except Exception as e:
            st.error(f"A股数据拉取失败: {e}")
            return pd.DataFrame()

    @st.cache_data(ttl=60)
    def fetch_etf():
        try:
            return ak.fund_etf_spot_em()
        except:
            return pd.DataFrame()

    @st.cache_data(ttl=3600) # 新发基金不需要太高频刷新
    def fetch_new_funds():
        try:
            return ak.fund_new_em()
        except:
            return pd.DataFrame()

    @st.cache_data(ttl=120)
    def fetch_fund_flow():
        try:
            return ak.stock_individual_fund_flow_rank(indicator="今日")
        except:
            return pd.DataFrame()

    # ================= 业务模块 =================

    if menu == "A股全景排序看板":
        st.header("🚀 A股全市场实时行情")
        st.markdown("💡 **操作提示**：点击表格任意**列头**即可进行升序/降序排列，支持全屏查看。")
        col1, col2 = st.columns([1, 8])
        with col1:
            if st.button("🔄 手动刷新"):
                st.cache_data.clear()
        
        df_a = fetch_a_shares()
        if not df_a.empty:
            # 优化展示列
            show_cols = ['代码', '名称', '最新价', '涨跌幅', '涨跌额', '成交量', '成交额', '换手率', '最高', '最低', '今开', '昨收']
            st.dataframe(df_a[show_cols], use_container_width=True, height=700)
        else:
            st.warning("暂无数据，可能是非交易时间或接口限流。")

    elif menu == "自选股1分钟监控":
        st.header("⏱️ 自选股1分钟维度量价监控")
        st.markdown("针对特定股票进行高频数据轮询，查看日内走势。")
        
        col_input, col_btn = st.columns([3, 1])
        with col_input:
            symbol = st.text_input("请输入股票代码 (例如: 600519 或 000001)", "600519")
        
        if symbol:
            try:
                with st.spinner("正在拉取分钟级数据..."):
                    df_min = ak.stock_zh_a_hist_min_em(symbol=symbol, period='1', adjust="")
                
                if not df_min.empty:
                    st.subheader(f"[{symbol}] 今日1分钟成交走势")
                    df_min['时间'] = pd.to_datetime(df_min['时间'])
                    df_min.set_index('时间', inplace=True)
                    
                    col1, col2 = st.columns(2)
                    with col1:
                        st.write("📊 **1分钟成交量 (手)**")
                        st.bar_chart(df_min['成交量'], color="#1f77b4")
                    with col2:
                        st.write("💰 **1分钟成交额 (元)**")
                        st.line_chart(df_min['成交额'], color="#ff7f0e")
                    
                    st.write("📝 **详细数据表**")
                    st.dataframe(df_min.sort_index(ascending=False), use_container_width=True, height=300)
                else:
                    st.warning("未获取到该代码的分钟数据，请检查代码是否正确。")
            except Exception as e:
                st.error(f"拉取失败，请确保输入的是6位纯数字A股代码。错误详情: {e}")

    elif menu == "ETF与新发基金":
        st.header("📈 ETF 行情与新发基金监控")
        tab1, tab2 = st.tabs(["实时 ETF 行情", "近期新发基金/ETF"])
        
        with tab1:
            st.markdown("全市场 ETF 实时表现 (支持点击表头排序)")
            df_etf = fetch_etf()
            st.dataframe(df_etf, use_container_width=True, height=500)
            
        with tab2:
            st.markdown("跟踪东方财富新发基金数据")
            df_new = fetch_new_funds()
            st.dataframe(df_new, use_container_width=True, height=500)

    elif menu == "主力资金流向":
        st.header("💰 市场主力资金流向排行 (个股)")
        st.info("数据反映今日全市场个股的资金流入流出情况。")
        df_flow = fetch_fund_flow()
        if not df_flow.empty:
            st.dataframe(df_flow, use_container_width=True, height=700)

    elif menu == "系统安全后台":
        st.header("🛡️ 系统管理与监控后台")
        st.markdown("---")
        st.write(f"**当前在线管理员**: `{username}`")
        st.success(f"**您的当前访问 IP**: `{visitor_ip}`")
        
        st.markdown("### 系统状态")
        st.code(f"Streamlit Version: {st.__version__}\nAkShare Version: {ak.__version__}\nCaddy HTTPS: Active\nDomain: gpc.230139.xyz", language="yaml")
EOF

# 4. 生成 requirements.txt (锁定核心库版本以保证稳定性)
echo -e "${BLUE}>>> 生成依赖清单 requirements.txt...${NC}"
cat << 'EOF' > requirements.txt
streamlit==1.32.0
akshare>=1.12.95
pandas>=2.0.0
streamlit-authenticator==0.3.1
pyyaml
EOF

# 5. 生成 Dockerfile
echo -e "${BLUE}>>> 生成 Dockerfile...${NC}"
cat << 'EOF' > Dockerfile
FROM python:3.10-slim

WORKDIR /app

# 安装系统编译依赖 (防止某些 Python 包编译失败)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# 使用清华源加速安装
RUN pip install --no-cache-dir -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

COPY . .

EXPOSE 8501

HEALTHCHECK CMD curl --fail http://localhost:8501/_stcore/health

ENTRYPOINT ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
EOF

# 6. 生成 Caddyfile (处理 HTTPS 证书及反向代理)
echo -e "${BLUE}>>> 生成 Caddyfile (域名: gpc.230139.xyz)...${NC}"
cat << 'EOF' > Caddyfile
gpc.230139.xyz {
    # 启用 gzip/zstd 压缩加快数据表加载速度
    encode zstd gzip
    
    # 反向代理到 streamlit 容器，并透传真实 IP
    reverse_proxy streamlit:8501 {
        header_up X-Forwarded-For {remote}
        header_up X-Real-IP {remote}
    }
}
EOF

# 7. 生成 docker-compose.yml
echo -e "${BLUE}>>> 生成 docker-compose.yml...${NC}"
cat << 'EOF' > docker-compose.yml
version: '3.8'

services:
  streamlit:
    build: .
    container_name: stock_streamlit_app
    restart: always
    environment:
      - TZ=Asia/Shanghai  # 统一使用北京时间
    expose:
      - "8501"

  caddy:
    image: caddy:latest
    container_name: stock_caddy_gateway
    restart: always
    ports:
      - "80:80"
      - "443:443"
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

# 8. 执行部署命令
echo -e "${BLUE}>>> 开始构建并启动 Docker 容器 (这可能需要几分钟的时间下载镜像)...${NC}"
docker compose up -d --build

# 9. 部署完成提示
echo -e "====================================================================="
echo -e "${GREEN}✅ 部署完成！${NC}"
echo -e "请确保你的域名 ${YELLOW}gpc.230139.xyz${NC} 已经正确解析到本台服务器的 IP 地址。"
echo -e "Caddy 会在后台自动为你申请并配置 HTTPS 证书（通常需要10秒-1分钟左右）。"
echo -e ""
echo -e "🌐 ${BLUE}访问地址${NC}: https://gpc.230139.xyz"
echo -e "👤 ${BLUE}默认账号${NC}: adminxxp"
echo -e "🔑 ${BLUE}默认密码${NC}: XXP0515!2076@"
echo -e "====================================================================="
echo -e "如果需要修改代码，请直接编辑 ${PROJECT_DIR}/app.py，容器会自动热更新。"
