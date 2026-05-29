cat > apple_deep_check.sh <<'EOF'
#!/usr/bin/env bash

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[36m"
RESET="\033[0m"

ok() { echo -e "${GREEN}[OK]${RESET} $1"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $1"; }
fail() { echo -e "${RED}[FAIL]${RESET} $1"; }
info() { echo -e "${BLUE}[INFO]${RESET} $1"; }

echo
echo "======================================================"
echo " Apple Deep Connectivity Diagnostic"
echo "======================================================"
echo

info "1. System"

uname -a

echo
info "2. resolv.conf"

cat /etc/resolv.conf 2>/dev/null || true

echo
info "3. dnsmasq"

systemctl status dnsmasq --no-pager 2>/dev/null | head -n 15 || true

echo
info "4. Port 53"

ss -lnptu | grep :53 || true

echo
info "5. gai.conf"

grep -v '^#' /etc/gai.conf 2>/dev/null | grep precedence || true

echo
info "6. Apple DNS"

DOMAINS="
apps.apple.com
itunes.apple.com
icloud.com
mzstatic.com
aaplimg.com
"

for d in $DOMAINS; do
    echo "----------------------------"
    echo "$d"

    echo "[IPv4]"
    getent ahostsv4 "$d" | head -n 2 || true

    echo

    echo "[IPv6]"
    getent ahostsv6 "$d" | head -n 2 || true

    echo
done

echo
info "7. IPv4"

if ping -4 -c1 -W2 1.1.1.1 >/dev/null 2>&1; then
    ok "IPv4 OK"
else
    fail "IPv4 FAIL"
fi

echo
info "8. IPv6"

if ping -6 -c1 -W2 2606:4700:4700::1111 >/dev/null 2>&1; then
    ok "IPv6 OK"
else
    warn "IPv6 FAIL"
fi

echo
info "9. Apple HTTPS IPv4"

curl -4 -I --connect-timeout 8 https://apps.apple.com 2>/dev/null | head -n 5 || true

echo
info "10. Apple HTTPS IPv6"

curl -6 -I --connect-timeout 8 https://apps.apple.com 2>/dev/null | head -n 5 || true

echo
info "11. TLS"

echo | openssl s_client -connect apps.apple.com:443 -tls1_3 2>/dev/null | grep "Verify return code" || true

echo
info "12. MTU"

IFACE=$(ip route | awk '/default/ {print $5}' | head -n1)

echo "Interface: $IFACE"

ip link show "$IFACE" | grep mtu || true

echo
info "13. Xray"

if pgrep xray >/dev/null 2>&1; then
    warn "Xray detected"

    ss -lnpt | grep xray || true
else
    ok "No Xray"
fi

echo
info "14. Recent dnsmasq Logs"

journalctl -u dnsmasq --no-pager -n 20 || true

echo
echo "======================================================"
echo " DONE"
echo "======================================================"
echo
EOF
