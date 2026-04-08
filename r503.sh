#!/bin/bash

# =================================
# Linux Network Optimization Script
# BBR + Kernel Performance Tuning
# =================================

set -e

if [ "$(id -u)" != "0" ]; then
    echo "请使用 root 运行此脚本"
    exit 1
fi

echo "======================================="
echo "开始网络优化"
echo "======================================="

echo "清空1"
sudo truncate -s 0 /etc/sysctl.conf
sudo truncate -s 0 /etc/sysctl.d/99-sysctl.conf
sudo truncate -s 0 /etc/sysctl.d/99-network-optimized.conf

echo "清空2"
sudo rm -f /etc/sysctl.d/99-bbr.conf
sudo rm -f /etc/sysctl.d/99-bbr3.conf
sudo rm -f /etc/sysctl.d/99-bbr3-ultra.conf
sudo rm -f /etc/sysctl.d/99-bbrpro.conf
sudo rm -f /etc/sysctl.d/99-bbrv3.conf
sudo rm -f /etc/sysctl.d/99-ipv6-disable.conf
sudo rm -f /etc/sysctl.d/99-network-optimized.conf
sudo rm -f /etc/sysctl.d/99-pro66.conf
sudo rm -f /etc/sysctl.d/99-pro70.conf
sudo rm -f /etc/sysctl.d/99-pro77.conf
sudo rm -f /etc/sysctl.d/99-pro831.conf
sudo rm -f /etc/sysctl.d/99-pro838.conf
sudo rm -f /etc/sysctl.d/99-pro850.conf
sudo rm -f /etc/sysctl.d/99-pro860.conf
sudo rm -f /etc/sysctl.d/99-xanmod-bbr3.conf
sudo rm -f /usr/lib/sysctl.d/50-pid-max.conf
sudo rm -f /usr/lib/sysctl.d/99-protect-links.conf


sudo rm -f /etc/security/limits.conf

CONF_FILE="/etc/security/limits.conf"

cat > $CONF_FILE << 'EOF'
root     soft   nofile    1000000
root     hard   nofile    1000000
root     soft   nproc    1000000
root     hard   nproc    1000000
root     soft   core    1000000
root     hard   core    1000000
root     soft   stack     1000000
root     hard   stack     1000000

*     soft   nofile    1000000
*     hard   nofile    1000000
*     soft   nproc    1000000
*     hard   nproc    1000000
*     soft   core    1000000
*     hard   core     1000000
*     soft   stack    1000000
*     hard   stack    1000000


nginx soft nofile 1000000
nginx hard nofile 1000000

EOF


echo "session required pam_limits.so" >> /etc/pam.d/common-session

echo "session required pam_limits.so" >> /etc/pam.d/common-session-noninteractive

echo "DefaultLimitNOFILE=1000000" >> /etc/systemd/system.conf

echo "DefaultLimitNPROC=1000000" >> /etc/systemd/system.conf


CONF_FILE="/etc/sysctl.d/99-network-optimized.conf"


echo "写入优化配置..."

cat > $CONF_FILE << 'EOF'
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.neigh.default.base_reachable_time_ms = 60000
net.ipv4.neigh.default.mcast_solicit = 2
net.ipv4.neigh.default.retrans_time_ms = 500
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_ecn = 1
net.ipv4.tcp_ecn_fallback = 1

net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_sack = 1

net.ipv4.tcp_window_scaling = 1
#窗口
net.ipv4.tcp_adv_win_scale = 3
net.ipv4.tcp_moderate_rcvbuf = 1
net.core.rmem_default = 1050576
net.core.wmem_default = 1050576
net.core.rmem_max = 22971528
net.core.wmem_max = 22971528

net.ipv4.tcp_rmem = 32768 1050576 22971528
net.ipv4.tcp_wmem = 32768 1050576 22971528
net.ipv4.udp_rmem_min = 32768
net.ipv4.udp_wmem_min = 32768

net.core.netdev_budget = 600
net.ipv4.igmp_max_memberships = 200

net.ipv4.route.flush = 1
net.ipv4.tcp_slow_start_after_idle = 0
vm.swappiness = 1
fs.file-max = 1048576
fs.nr_open = 1048576
fs.inotify.max_user_instances = 262144
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_fin_timeout = 12
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_time = 60
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_max_tw_buckets = 262144

net.ipv4.tcp_retries1 = 5
net.ipv4.tcp_retries2 = 8
net.ipv4.tcp_syn_retries = 3
net.ipv4.tcp_synack_retries = 2
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_max_orphans = 262144
net.core.optmem_max = 3276800
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_reordering = 3

net.ipv4.tcp_autocorking = 0
net.ipv4.tcp_tso_win_divisor = 6
kernel.pid_max = 4194304
kernel.threads-max = 85536
net.ipv4.neigh.default.gc_thresh1 = 1024
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv4.neigh.default.gc_stale_time = 100
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
net.unix.max_dgram_qlen = 130000
net.ipv4.tcp_notsent_lowat = 46005

vm.vfs_cache_pressure = 10
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.ip_forward = 1
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.tcp_early_retrans = 3
net.ipv4.neigh.default.unres_qlen = 25535
net.ipv4.conf.all.route_localnet =0
net.ipv4.tcp_orphan_retries = 8
net.core.busy_poll = 0
net.core.busy_read = 0
net.ipv4.conf.all.forwarding = 1

net.ipv4.ipfrag_max_dist = 72
net.ipv4.ipfrag_secret_interval = 20
net.ipv4.ipfrag_low_thresh = 67108864
net.ipv4.ipfrag_high_thresh = 134217728
net.ipv4.ipfrag_time = 30

fs.aio-max-nr = 262144
kernel.msgmax = 655350
kernel.msgmnb = 655350
net.ipv4.neigh.default.proxy_qlen = 50000
net.ipv4.tcp_pacing_ca_ratio = 120
net.ipv4.tcp_pacing_ss_ratio = 200
fs.protected_fifos = 1
fs.protected_hardlinks = 1
fs.protected_regular = 2
fs.protected_symlinks = 1

net.core.rps_sock_flow_entries = 65535
net.core.flow_limit_table_len = 131072

net.ipv4.tcp_workaround_signed_windows = 1
vm.dirty_ratio = 35
vm.overcommit_memory = 0
kernel.sysrq = 1
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
vm.max_map_count = 65535
net.ipv4.tcp_child_ehash_entries = 65535

net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.tcp_stdurg = 0
net.ipv4.tcp_challenge_ack_limit = 1200
net.ipv4.tcp_comp_sack_delay_ns = 100000
net.ipv4.tcp_comp_sack_nr = 2
net.ipv4.tcp_fwmark_accept = 1
net.ipv4.tcp_invalid_ratelimit = 800
net.ipv4.tcp_l3mdev_accept = 1
net.core.dev_weight = 256
net.core.dev_weight_tx_bias = 50
net.core.dev_weight_rx_bias = 50
net.core.tstamp_allow_data = 1
net.core.netdev_tstamp_prequeue = 1
kernel.randomize_va_space = 2

net.ipv4.tcp_mem = 65536 131072 262144
net.ipv4.udp_mem = 65536 131072 262144

net.ipv4.tcp_recovery = 0x1

net.ipv4.tcp_dsack = 1
kernel.shmmax = 67108864
kernel.shmall = 16777216

net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

net.ipv4.tcp_limit_output_bytes = 1310720
net.ipv4.tcp_min_tso_segs = 1

net.ipv4.tcp_thin_linear_timeouts = 0
net.ipv4.tcp_early_demux = 1
net.ipv4.tcp_shrink_window = 0

net.ipv4.neigh.default.unres_qlen_bytes = 65535

kernel.printk=3 4 1 3
kernel.sched_autogroup_enabled=0





#net.ipv4.tcp_frto = 2
#net.ipv4.tcp_low_latency = 1
#net.ipv4.fib_sync_mem = 6666354
#net.ipv4.tcp_fack = 1
#net.ipv4.tcp_app_win = 31
#net.ipv4.tcp_retrans_collapse = 3 #老旧废弃
#net.ipv4.tcp_plb_enabled = 1
#net.ipv4.conf.default.forwarding = 1
#vm.min_free_kbytes = 65535
#net.ipv4.route.max_size = 655350
#net.ipv4.route.gc_timeout = 1350

#1c 1, 2c 3, 4c f, 8c ff，自动为ffff
#net.core.rps_default_mask = 1
#CIPSO 是 军事安全标签网络，无意义
#net.ipv4.cipso_cache_enable = 1
#net.ipv4.cipso_cache_bucket_size = 37000
#net.ipv4.cipso_rbm_optfmt = 1
#net.ipv4.route.gc_min_interval_ms = 700

EOF

echo "应用 sysctl 参数..."
sysctl --system
echo "应用 sysctl 参数2..."
sudo sysctl -p

reboot
