#!/bin/sh
# if6.sh — 这个文件用 sh 写，兼容所有系统
set -e
REPO="https://raw.githubusercontent.com/PXPXPX2023/net/refs/heads/main"
curl -sS -o /root/xrayv6f6g1.sh "$REPO/xrayv6f6g1.sh"
chmod +x /root/xrayv6f6g1.sh
ln -sf /root/xrayv6f6g1.sh /usr/local/bin/xrv
echo "安装完成，输入 xrv 启动"
