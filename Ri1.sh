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
kernel.pid_max = 131072
kernel.panic = 1
kernel.sysrq = 1
kernel.core_pattern = core_%e
kernel.printk = 3 4 1 3
kernel.numa_balancing = 0
kernel.sched_autogroup_enabled = 0
vm.swappiness = 5
vm.dirty_ratio = 5
vm.dirty_background_ratio = 2
vm.panic_on_oom = 1
vm.overcommit_memory = 1
vm.min_free_kbytes = 65536
net.core.default_qdisc = fq
net.core.netdev_max_backlog = 8192
net.core.somaxconn = 8192
net.core.optmem_max = 262144
net.core.rmem_max = 27262976
net.core.wmem_max = 27262976
net.core.rmem_default = 1048576
net.core.wmem_default = 1048576
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_max_tw_buckets = 32768
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_rmem = 32768 1048576 27262976
net.ipv4.tcp_wmem = 32768 1048576 27262976
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_notsent_lowat = 524288
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.tcp_max_orphans = 32768
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_abort_on_overflow = 0
net.ipv4.tcp_stdurg = 0
net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.ip_no_pmtu_disc = 0
net.ipv4.route.gc_timeout = 100
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.neigh.default.gc_thresh3 = 4096
net.ipv4.neigh.default.gc_thresh2 = 2048
net.ipv4.neigh.default.gc_thresh1 = 512
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.arp_announce = 2
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.all.arp_ignore = 1
net.ipv4.conf.default.arp_ignore = 1


EOF

echo "应用 sysctl 参数..."
sysctl --system
echo "应用 sysctl 参数2..."
sudo sysctl -p

reboot
