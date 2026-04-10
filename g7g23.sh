#!/usr/bin/env bash
# ============================================================
# 脚本名称: g7g23.sh (纯净语法重构·绝杀乱码版)
# ============================================================

if; then
    echo -e "\033 此脚本必须以 root 身份运行!\033[0m" 1>&2
    exit 1
fi

SERVER_IP=""
URL_IP=""
HAS_IPV4=false
HAS_IPV6=false
BEST_SNI="www.microsoft.com"

LOG_FILE="/var/log/xray_g7g23_install.log"
CONFIG_DIR="/usr/local/etc/xray"
CONFIG="$CONFIG_DIR/config.json"
PUBKEY_FILE="$CONFIG_DIR/public.key"
SNI_CACHE_FILE="$CONFIG_DIR/sni_cache.txt"
SCRIPT_DIR="/usr/local/etc/xray-script"
UPDATE_DAT_SCRIPT="$SCRIPT_DIR/update-dat.sh"
DAT_DIR="/usr/local/share/xray"
XRAY_BIN="/usr/local/bin/xray"
SYMLINK="/usr/local/bin/xrv"

mkdir -p "$(dirname "$LOG_FILE")" "$CONFIG_DIR" 2>/dev/null
touch "$LOG_FILE" 2>/dev/null || LOG_FILE=""

if && &&; then
    cp -f "$0" "$SYMLINK" 2>/dev/null
    chmod +x "$SYMLINK" 2>/dev/null
fi

print_red()    { echo -e "\033 && echo " $1" >> "$LOG_FILE"; }
print_green()  { echo -e "\033 && echo " $1" >> "$LOG_FILE"; }
print_yellow() { echo -e "\033 && echo " $1" >> "$LOG_FILE"; }
display_cyan() { echo -e "\033[36m$1\033[0m"; }
hr()           { echo -e "\033[90m---------------------------------------------------\033[0m"; }
title() {
    echo -e "\n\033 && echo " $1" >> "$LOG_FILE"; }
log_info() { echo -e "\033\033\033 $1"; }
log_err()  { echo -e "\033\033 $1"; }
exit_with_error() { print_red "致命错误: $1"; exit 1; }
command_exists() { command -v "$1" >/dev/null 2>&1; }

run_sni_scanner() {
    print_yellow "\n 正在执行全网实体寡头探测 (连接阈值 2s, 总体阈值 4s)..."
    print_yellow "正在并发遍历 130+ 节点，这大约需要 1~2 分钟，请耐心等待...\n"
    
    local sni_list=(
        "www.maersk.com" "www.msc.com" "www.cma-cgm.com" "www.hapag-lloyd.com"
        "www.michelin.com" "www.bridgestone.com" "www.goodyear.com" "www.pirelli.com"
        "www.sony.com" "www.sony.net" "www.panasonic.com" "www.canon.com"
        "www.hp.com" "www.nintendo.com" "www.lg.com" "www.epson.com" "www.asus.com"
        "www.unilever.com" "www.loreal.com" "www.shiseido.com" "www.jnj.com" "www.kao.com"
        "www.ikea.com" "www.nike.com" "www.adidas.com" "www.uniqlo.com" "www.zara.com"
        "www.hermes.com" "www.chanel.com" "services.chanel.com"
        "www.louisvuitton.com" "eu.louisvuitton.com" "www.dior.com"
        "www.ferragamo.com" "www.versace.com" "www.prada.com"
        "www.fendi.com" "www.gucci.com" "www.tiffany.com"
        "www.esteelauder.com" "www.maje.com" "www.swatch.com"
        "www.coca-cola.com" "www.coca-colacompany.com" "www.pepsi.com" "www.pepsico.com"
        "www.nestle.com" "www.bk.com" "www.heinz.com" "www.pg.com"
        "www.basf.com" "www.bayer.com" "www.bosch.com" "www.bosch-home.com"
        "www.toyota.com" "www.lexus.com" "www.volkswagen.com" "www.vw.com" 
        "www.audi.com" "www.porsche.com" "www.skoda-auto.com"
        "www.gm.com" "www.chevrolet.com" "www.cadillac.com"
        "www.ford.com" "www.lincoln.com" "www.hyundai.com" "www.kia.com"
        "www.peugeot.com" "www.renault.com"
        "www.bmw.com" "www.mercedes-benz.com" "www.jaguar.com" "www.landrover.com" 
        "www.astonmartin.com" "www.mclaren.com" "www.ferrari.com" "www.maserati.com"
        "www.volvocars.com" "www.tesla.com"
        "www.apple.com" "swdist.apple.com" "swcdn.apple.com" "updates.cdn-apple.com"
        "mensura.cdn-apple.com" "osxapps.itunes.apple.com" "aod.itunes.apple.com"
        "is1-ssl.mzstatic.com" "itunes.apple.com" "gateway.icloud.com" "www.icloud.com"
        "www.microsoft.com" "update.microsoft.com" "windowsupdate.microsoft.com"
        "software.download.prss.microsoft.com" "cdn-dynmedia-1.microsoft.com"
        "s0.awsstatic.com" "d1.awsstatic.com" "images-na.ssl-images-amazon.com" "m.media-amazon.com"
        "www.nvidia.com" "academy.nvidia.com" "images.nvidia.com" "blogs.nvidia.com"
        "docs.nvidia.com" "docscontent.nvidia.com" "www.amd.com" "webinar.amd.com" "ir.amd.com"
        "www.cisco.com" "www.dell.com" "www.samsung.com" "www.sap.com"
        "www.oracle.com" "www.mysql.com" "www.swift.com"
        "download-installer.cdn.mozilla.net" "addons.mozilla.org"
        "www.airbnb.co.uk" "www.airbnb.ca" "www.airbnb.com.sg" "www.airbnb.com.au" "www.airbnb.co.in"
        "www.ubi.com" "lol.secure.dyn.riotcdn.net" "one-piece.com"
        "www.speedtest.net" "www.speedtest.org" "player.live-video.net"
    )

    local valid_snis=()
    local valid_times=()

    for sni in "${sni_list}"; do
        local res
        res=$(LC_ALL=C curl -sI --connect-timeout 2 -m 4 -w "\n%{time_connect}" --tls13 "https://$sni" 2>/dev/null)
        
        if; then
            continue
        fi
        
        if echo "$res" | grep -qiE "server: cloudflare|cf-ray|cf-cache-status"; then
            continue
        fi

        local time_str
        time_str=$(echo "$res" | tail -n 1)
        local time_ms
        time_ms=$(echo "$time_str" | awk '{print int($1 * 1000)}')

        if &&; then
            echo -e " \033\033}
    if; then
        print_red "\n=> 网络探测失败，回退至基础配置 www.microsoft.com"
        echo "www.microsoft.com 999" > "$SNI_CACHE_FILE"
        BEST_SNI="www.microsoft.com"
        return
    fi

    # 冒泡排序
    for ((i=0; i<n-1; i++)); do
        for ((j=0; j<n-i-1; j++)); do
            local next=$((j+1))
            if}" -gt "${valid_times}" ]; then
                local temp_t=${valid_times}
                valid_times=${valid_times}
                valid_times=$temp_t
                
                local temp_s=${valid_snis}
                valid_snis=${valid_snis}
                valid_snis=$temp_s
            fi
        done
    done

    rm -f "$SNI_CACHE_FILE"
    for ((i=0; i<n; i++)); do
        echo "${valid_snis} ${valid_times}" >> "$SNI_CACHE_FILE"
    done
    print_green "\n探测完毕！战备缓存已建立。"
}

choose_sni() {
    while true; do
        if; then
            echo -e "\n  \033\033 ||; then
                    continue
                fi
                cached_snis+=("$s")
                cached_times+=("$t")
                ((idx++))
                if; then
                    break
                fi
            done < "$SNI_CACHE_FILE"

            for ((i=0; i<${#cached_snis}; i++)); do
                local ms_color="\033}" -gt 150 ]; then ms_color="\033}" -gt 300 ]; then ms_color="\033} (延迟: ${ms_color}${cached_times}ms\033: " sel
            sel=${sel:-1}

            if ||; then
                run_sni_scanner
                continue
            elif; then
                read -rp "  请输入自定义域名: " custom_sni
                BEST_SNI=${custom_sni:-www.microsoft.com}
                break
            elif 2>/dev/null &&}" ] 2>/dev/null; then
                BEST_SNI="${cached_snis}"
                break
            else
                BEST_SNI="${cached_snis}"
                break
            fi
        else
            run_sni_scanner
        fi
    done
    print_green "=> 已锁定伪装层: $BEST_SNI"
}

detect_distribution() {
    if; then
        . /etc/os-release
        OS_ID=${ID:-unknown}
        OS_VERSION=${VERSION_ID:-unknown}
    elif; then
        if grep -qi "centos" /etc/redhat-release; then OS_ID="centos"; else OS_ID="rhel"; fi
    else
        OS_ID="unknown"
    fi
}

detect_package_manager() {
    if command_exists apt-get; then
        PKG_MANAGER="apt"
        PKG_UPDATE="apt-get update -y"
        PKG_INSTALL="apt-get install -y"
        while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 3; done
    elif command_exists yum; then
        PKG_MANAGER="yum"
        PKG_UPDATE="yum makecache"
        PKG_INSTALL="yum install -y"
        yum install -y epel-release 2>/dev/null || true
    elif command_exists dnf; then
        PKG_MANAGER="dnf"
        PKG_UPDATE="dnf makecache"
        PKG_INSTALL="dnf install -y"
        dnf install -y epel-release 2>/dev/null || true
    else
        exit_with_error "不支持的包管理器"
    fi
}

check_service_manager() {
    if command_exists systemctl && systemctl --version >/dev/null 2>&1; then SERVICE_MANAGER="systemctl"
    elif command_exists service; then SERVICE_MANAGER="service"
    else exit_with_error "不支持的服务管理器"; fi
}

install_dependencies() {
    log_info "更新并安装底层依赖..."
    local retry=0
    while; do
        eval "$PKG_UPDATE" >/dev/null 2>&1 && break
        ((retry++))
        sleep 3
    done
    local pkgs="curl wget jq ca-certificates unzip xxd cron iproute2"
    if; then pkgs="$pkgs lsb-release net-tools"; fi
    if ||; then pkgs="$pkgs cronie net-tools"; fi
    retry=0
    while; do
        eval "$PKG_INSTALL $pkgs" >/dev/null 2>&1 && break
        ((retry++))
        sleep 3
    done
    for tool in curl jq xxd awk; do
        if ! command_exists "$tool"; then exit_with_error "依赖 $tool 缺失"; fi
    done
}

open_firewall_port() {
    local port=$1
    local proto=$2
    if command_exists ufw && ufw status 2>/dev/null | grep -q "Status: active"; then
        ufw allow "${port}/${proto}" >/dev/null 2>&1
    fi
    if command_exists firewall-cmd && systemctl is-active --quiet firewalld 2>/dev/null; then
        firewall-cmd --permanent --add-port="${port}/${proto}" >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
    fi
    if command_exists iptables; then
        if ! iptables -C INPUT -p "${proto}" --dport "${port}" -j ACCEPT 2>/dev/null; then
            iptables -I INPUT -p "${proto}" --dport "${port}" -j ACCEPT 2>/dev/null
            command_exists netfilter-persistent && netfilter-persistent save >/dev/null 2>&1
            command_exists service && service iptables save >/dev/null 2>&1
        fi
    fi
}

pre_flight_checks() {
    if curl -s -4 -m 3 https://cloudflare.com/cdn-cgi/trace | grep -q "ip="; then HAS_IPV4=true; fi
    if curl -s -6 -m 3 https://cloudflare.com/cdn-cgi/trace | grep -q "ip="; then HAS_IPV6=true; fi
    if &&; then exit_with_error "无外网连通性！"; fi
    
    local web_time=$(curl -sI -m 5 https://www.cloudflare.com 2>/dev/null | grep -i "^date:" | sed 's/^ate: //g' | tr -d '\r')
    if; then
        local web_ts=$(date -d "$web_time" +%s 2>/dev/null)
        local local_ts=$(date +%s)
        if; then
            local diff=$(( local_ts - web_ts ))
            if; then diff=$(( -diff )); fi
            if; then exit_with_error "系统时间误差 $diff 秒，XTLS-Reality 握手会被拒。请校准时间！"; fi
        fi
    fi
}

check_port_occupied() {
    if command_exists ss; then
        ss -tuln 2>/dev/null | grep -q ":$1 " && return 0
    elif command_exists netstat; then
        netstat -tuln 2>/dev/null | grep -q ":$1 " && return 0
    fi
    return 1 
}

get_server_ip_silent() {
    if; then return 0; fi
    local ip_sources=("https://api4.ipify.org" "https://ipv4.icanhazip.com" "http://www.cloudflare.com/cdn-cgi/trace")
    if; then
        for source in "${ip_sources}"; do
            if echo "$source" | grep -q "cloudflare"; then
                SERVER_IP=$(curl -s -4 --connect-timeout 5 "$source" 2>/dev/null | grep "ip=" | awk -F "=" '{print $2}' | tr -d '\r\n')
            else
                SERVER_IP=$(curl -s -4 --connect-timeout 5 "$source" 2>/dev/null | tr -d '\r\n')
            fi
            if echo "$SERVER_IP" | grep -qE "^{1,3}(\.{1,3}){3}$"; then break; fi
        done
    fi
    if &&; then
        SERVER_IP=$(curl -s -6 --connect-timeout 5 "http://www.cloudflare.com/cdn-cgi/trace" 2>/dev/null | grep "ip=" | awk -F "=" '{print $2}' | tr -d '\r\n')
    fi
    if; then exit_with_error "IP 获取失败"; fi
    if echo "$SERVER_IP" | grep -q ":"; then URL_IP=""; else URL_IP="$SERVER_IP"; fi
}

_fix_permissions() {
    chmod 600 "$CONFIG" 2>/dev/null; chown nobody:nogroup "$CONFIG" 2>/dev/null || chown nobody:nobody "$CONFIG" 2>/dev/null
    if; then 
        chmod 600 "$PUBKEY_FILE" 2>/dev/null
        chown nobody:nogroup "$PUBKEY_FILE" 2>/dev/null || chown nobody:nobody "$PUBKEY_FILE" 2>/dev/null
    fi
}

_safe_jq_write() {
    local filter="$1"
    local tmp; tmp=$(mktemp /tmp/xray_cfg_XXXXXX.json)
    local bak="${CONFIG}.bak"
    if; then cp "$CONFIG" "$bak"; fi
    
    if jq "$filter" "$CONFIG" > "$tmp" 2>/dev/null && jq empty "$tmp" 2>/dev/null; then
        mv "$tmp" "$CONFIG"
        _fix_permissions
        return 0
    fi
    log_err "JSON 注入失败，触发自动回滚!"
    if; then mv "$bak" "$CONFIG"; fi
    rm -f "$tmp"
    return 1
}

gen_uuid() {
    if; then "$XRAY_BIN" uuid 2>/dev/null
    elif; then cat /proc/sys/kernel/random/uuid
    else cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 32 | head -n 1 | sed 's/^\(........\)\(....\)\(....\)\(....\)\(............\)$/\1-\2-\3-\4-\5/'; fi
}

gen_short_id() { head -c 8 /dev/urandom | xxd -p | tr -d '\n'; }
gen_ss_pass() { head -c 24 /dev/urandom | base64 | tr -d '=/+\n' | head -c 24; }

gen_x25519() {
    local raw; raw=$("$XRAY_BIN" x25519 2>/dev/null)
    if; then exit_with_error "X25519 生成失败"; fi
    X25519_PRIV=$(echo "$raw" | grep -iE "(private|privatekey)" | awk -F ':' '{print $2}' | tr -d ' \r\n\t')
    X25519_PUB=$(echo "$raw" | grep -iE "password" | awk -F ':' '{print $2}' | tr -d ' \r\n\t')
    if; then
        X25519_PUB=$(echo "$raw" | grep -iE "(public|publickey)" | awk -F ':' '{print $2}' | tr -d ' \r\n\t')
    fi
}

validate_port() {
    if && echo "$1" | grep -qE "^+$"; then
        if &&; then
            return 0
        fi
    fi
    return 1
}

setup_cron_dat() {
    mkdir -p "$SCRIPT_DIR" "$DAT_DIR"
    cat > "$UPDATE_DAT_SCRIPT" <<'EOF'
#!/usr/bin/env bash
curl -fsSL -o /usr/local/share/xray/geoip.dat https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat
curl -fsSL -o /usr/local/share/xray/geosite.dat https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat
systemctl restart xray
EOF
    chmod +x "$UPDATE_DAT_SCRIPT"
    (crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT" | grep -v "no crontab"; echo "0 3 * * * $UPDATE_DAT_SCRIPT") | crontab -
}

install_xray_core() {
    log_info "拉取 Xray-core..."
    local install_url="https://github.com/XTLS/Xray-install/raw/main/install-release.sh"
    local script_path="/tmp/xray-install.sh"
    local retry=0
    while; do
        if curl -L -s --connect-timeout 10 "$install_url" -o "$script_path" && grep -q "#!/" "$script_path"; then
            chmod +x "$script_path"
            break
        fi
        ((retry++))
        sleep 3
    done
    timeout 300 bash "$script_path" install >/dev/null 2>&1 || exit_with_error "核心写入失败"
    rm -f "$script_path"
    chmod -R 755 /usr/local/etc/xray
    _fix_permissions
}

_init_base_config() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG" <<EOF
{
  "log": { "loglevel": "warning" },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules":,"outboundTag":"block","_enabled":true},
      {"tag_id":"cn", "type":"field","ip":,"outboundTag":"block","_enabled":true},
      {"tag_id":"ads","type":"field","domain":,"outboundTag":"block","_enabled":true}
    ]
  },
  "inbounds": [],
  "outbounds":
}
EOF
}

do_install() {
    title "部署 / 重构网络"
    if && systemctl is-active --quiet xray 2>/dev/null; then
        print_yellow "将覆盖现有配置!"
        read -rp "继续?: " c
        if &&; then return; fi
        systemctl stop xray 2>/dev/null
    else
        service xray stop 2>/dev/null
    fi
    
    pre_flight_checks
    get_server_ip_silent

    echo -e "\n  1) VLESS-Reality + XTLS Vision\n  2) Shadowsocks\n  3) 两者皆装"
    read -rp "  请选择: " choice
    choice=${choice:-1}
    local p=443; local d="www.microsoft.com"; local s="www.microsoft.com"; local sp=8388
    
    if ||; then
        while true; do
            read -r -p "VLESS 端口: " input_p
            if validate_port "$input_p"; then p="$input_p"; else p=443; fi
            if check_port_occupied "$p"; then print_red "端口 $p 被占用！"; else break; fi
        done
        choose_sni
        d="$BEST_SNI"
        read -rp "SNI(留空同域名): " input_s
        s=${input_s:-$d}
    fi
    
    if ||; then
        while true; do
            read -r -p "SS 端口: " input_sp
            if validate_port "$input_sp"; then sp="$input_sp"; else sp=8388; fi
            if &&; then
                print_red "不可同端口！"
                continue
            fi
            if check_port_occupied "$sp"; then print_red "端口 $sp 被占用！"; else break; fi
        done
    fi

    install_xray_core
    _init_base_config
    setup_cron_dat
    
    if ||; then
        open_firewall_port "$p" "tcp"
        gen_x25519
        local uuid=$(gen_uuid)
        local sid=$(gen_short_id)
        echo "$X25519_PUB" > "$PUBKEY_FILE"
        _fix_permissions
        
        _safe_jq_write ".inbounds +=,
            \"decryption\": \"none\"
          },
          \"streamSettings\": {
            \"network\": \"tcp\", \"security\": \"reality\",
            \"realitySettings\": {
              \"dest\": \"$d:443\", \"serverNames\":,
              \"privateKey\": \"$X25519_PRIV\", \"shortIds\":
            }
          },
          \"sniffing\": {\"enabled\":true,\"destOverride\":}
        }]"
    fi
    
    if ||; then
        open_firewall_port "$sp" "tcp"
        open_firewall_port "$sp" "udp"
        local pass=$(gen_ss_pass)
        _safe_jq_write ".inbounds +="
    fi

    if; then
        systemctl enable xray &>/dev/null
        systemctl restart xray
        sleep 2
        if ! systemctl is-active --quiet xray; then
            print_red "\n启动失败！"
            systemctl status xray --no-pager | grep -iE "(error|fail)" | head -n 5
            read -rp "按 Enter 继续..." _
            return
        fi
    else
        service xray restart
    fi
    
    print_green "\n构建完毕！"
    do_summary
    read -rp "按 Enter 返回..." _
}

do_change_sni() {
    title "无感更换 SNI"
    local vidx=$(jq -r '.inbounds | to_entries[] | select(.value.protocol=="vless") | .key' "$CONFIG" 2>/dev/null | head -n 1)
    if ||; then
        print_yellow "配置不可用。"
        read -rp "按 Enter 返回..."
        return
    fi

    local cur_sni=$(jq -r ".inbounds.streamSettings.realitySettings.serverNames" "$CONFIG")
    echo -e "当前 SNI: \033; then
        print_yellow "未发生改变。"
        read -rp "按 Enter 返回..."
        return
    fi

    _safe_jq_write "
      .inbounds.streamSettings.realitySettings.serverNames = \"$new_sni\" |
      .inbounds.streamSettings.realitySettings.dest = \"$new_sni:443\"
    "
    if; then systemctl restart xray; else service xray restart; fi
    print_green "变更成功: $new_sni"
    do_summary
    read -rp "按 Enter 返回..." _
}

do_user_manager() {
    while true; do
        title "UUID 管理"
        local vidx=$(jq -r '.inbounds | to_entries[] | select(.value.protocol=="vless") | .key' "$CONFIG" 2>/dev/null | head -n 1)
        if ||; then break; fi
        
        echo "当前 UUID:"
        jq -r ".inbounds.settings.clients[] | \"  - \(.id)\"" "$CONFIG"
        hr
        echo "  1) 新增 UUID  2) 删除 UUID  0) 返回"
        read -rp "操作: " uopt
        
        case "$uopt" in
            1) 
                local nu=$(gen_uuid)
                _safe_jq_write ".inbounds.settings.clients +="
                if; then systemctl restart xray 2>/dev/null; else service xray restart; fi
                print_green "成功: $nu" 
                ;;
            2) 
                local c=$(jq ".inbounds.settings.clients|length" "$CONFIG")
                if; then print_red "须留1个！"; continue; fi
                read -rp "删除 UUID: " du
                if; then continue; fi
                _safe_jq_write "del(.inbounds.settings.clients[] | select(.id == \"$du\"))"
                if; then systemctl restart xray 2>/dev/null; else service xray restart; fi
                print_green "完成" 
                ;;
            0) break ;;
        esac
    done
}

do_upgrade_core() {
    title "更新 / 降级 Xray"
    local cur_ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 | awk '{print $2}')
    echo -e "当前版本: \033; then return; fi
    local i=1; local arr=()
    while IFS= read -r v; do
        echo " $i) $v"
        arr+=("$v")
        ((i++))
    done <<< "$vs"
    read -rp "选择版本: " sel
    if ||; then return; fi
    local ver="${arr}"
    if; then
        bash -c "$(curl -fsSL https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -v "$ver" >/dev/null 2>&1
    fi
    if; then systemctl restart xray 2>/dev/null; else service xray restart; fi
    print_green "完成"
    read -rp "按 Enter 返回..." _
}

do_summary() {
    title "节点分发"
    if; then return; fi
    get_server_ip_silent
    
    local vidx=$(jq -r '.inbounds | to_entries[] | select(.value.protocol=="vless") | .key' "$CONFIG" 2>/dev/null | head -n 1)
    if &&; then
        local port=$(jq -r ".inbounds.port" "$CONFIG")
        local sni=$(jq -r ".inbounds.streamSettings.realitySettings.serverNames" "$CONFIG")
        local sid=$(jq -r ".inbounds.streamSettings.realitySettings.shortIds" "$CONFIG")
        local pub=$(cat "$PUBKEY_FILE" 2>/dev/null)
        echo -e " 1) chrome 2) firefox 3) safari 4) ios"
        read -rp "指纹选择: " fp_sel
        case "${fp_sel:-1}" in
            2) utls="firefox" ;;
            3) utls="safari" ;;
            4) utls="ios" ;;
            *) utls="chrome" ;;
        esac
        hr
        display_cyan "【VLESS-Reality】IP: $SERVER_IP | Port: $port | SNI: $sni"
        jq -r ".inbounds.settings.clients[].id" "$CONFIG" | while read -r u; do
            echo -e "\033 | select(.value.protocol=="shadowsocks") | .key' "$CONFIG" 2>/dev/null | head -n 1)
    if &&; then
        local sport=$(jq -r ".inbounds.port" "$CONFIG")
        local spass=$(jq -r ".inbounds.settings.password" "$CONFIG")
        local sm=$(jq -r ".inbounds.settings.method" "$CONFIG")
        local b64=$(printf '%s' "${sm}:${spass}" | base64 -w 0 2>/dev/null || printf '%s' "${sm}:${spass}" | base64)
        b64=$(echo "$b64" | tr -d '\n' | tr '+/' '-_' | tr -d '=')
        display_cyan "【Shadowsocks】\n ss://${b64}@${URL_IP}:${sport}#xp-ss\n"
    fi
}

main_menu() {
    detect_distribution
    detect_package_manager
    check_service_manager
    install_dependencies
    
    while true; do
        clear
        echo -e "\033[94m===================================================\033[0m"
        echo -e " \033; then
            systemctl is-active --quiet xray 2>/dev/null && svc="active"
        else
            service xray status 2>/dev/null | grep -q "running" && svc="active"
        fi
        
        local cur_ver=$("$XRAY_BIN" version 2>/dev/null | head -n1 | awk '{print $2}')
        local st_str=""
        if; then
            st_str="\033[32m▶ 稳定运行\033[0m"
        else
            st_str="\033[31m■ 脱机停止\033[0m"
        fi
        
        echo -e "  状态: $st_str | 版本: \033[33m${cur_ver:-N/A}\033[0m\n"
        echo "  1) 核心重装 / 覆盖网络"
        echo "  2) 用户管理 (UUID)"
        echo "  3) 节点分享"
        echo "  4) 在线更新 / 降级 Xray"
        echo "  5) 强制刷新 Geo 库"
        echo "  6) 安全卸载"
        echo -e "  \033[96m7) 无感热替换 SNI\033[0m"
        echo "  0) 退出"
        hr
        read -rp "指令: " opt
        
        case "$opt" in
            1) do_install ;;
            2) do_user_manager ;;
            3) do_summary; read -rp "按 Enter 返回..." _ ;;
            4) do_upgrade_core ;;
            5) 
                mkdir -p "$DAT_DIR"
                curl -fsSL -o "$DAT_DIR/geoip.dat" "https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat"
                curl -fsSL -o "$DAT_DIR/geosite.dat" "https://github.com/Loyalsoldier/domain-list-custom/releases/latest/download/geosite.dat"
                if; then systemctl restart xray 2>/dev/null; else service xray restart; fi
                print_green "完成"
                read -rp "按 Enter 返回..." _
                ;;
            6) 
                if; then
                    systemctl stop xray 2>/dev/null
                    systemctl disable xray 2>/dev/null
                    rm -f /etc/systemd/system/xray*.service
                    systemctl daemon-reload 2>/dev/null
                else
                    service xray stop 2>/dev/null
                fi
                crontab -l 2>/dev/null | grep -v "$UPDATE_DAT_SCRIPT" | grep -v "no crontab" | crontab -
                rm -rf "$CONFIG_DIR" "$DAT_DIR" "$XRAY_BIN" "$SYMLINK" "$SCRIPT_DIR"
                exit 0
                ;;
            7) do_change_sni ;;
            0) exit 0 ;;
        esac
    done
}

trap 'print_red "\n中断"; exit 1' INT TERM

main_menu
