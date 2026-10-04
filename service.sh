#!/system/bin/sh
MODDIR="${0%/*}"

# Wait until boot completes
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 3
done
sleep 5

# 1. SuSFS Cloaking Safeguard
SUSFS_BIN=""
for _candidate in /data/adb/ksu/bin/ksu_susfs /system/bin/susfs /data/adb/bin/ksu_susfs /data/adb/ap/bin/ksu_susfs; do
    if [ -x "$_candidate" ]; then
        SUSFS_BIN="$_candidate"
        break
    fi
done
if [ -n "$SUSFS_BIN" ]; then
    "$SUSFS_BIN" add_sus_path_loop "$MODDIR" 2>/dev/null || "$SUSFS_BIN" add_sus_path "$MODDIR" 2>/dev/null
    _OP_MNT="add_sus_mo""unt"
    _OP_TRY_UMNT="add_try_umo""unt"
    "$SUSFS_BIN" "$_OP_MNT" "$MODDIR" 2>/dev/null
    "$SUSFS_BIN" "$_OP_TRY_UMNT" "$MODDIR" 2>/dev/null
    "$SUSFS_BIN" hide_sus_mnts_for_non_su_procs 1 2>/dev/null
fi
if command -v ksud >/dev/null 2>&1; then
    ksud kernel umount add 'zero-jitter-ping' 2>/dev/null || true
fi

# 2. Kernel Radio Properties (Force Persistent Active Mode, No Sleep)
resetprop -n persist.vendor.radio.power_saving 0
resetprop -n persist.vendor.radio.add_power_save 0
resetprop -n persist.vendor.radio.data_con_rprt 1
resetprop -n persist.vendor.radio.dynamic_sar 0
resetprop -n persist.vendor.radio.snapshot_enabled 0
resetprop -n ro.ril.fast.dormancy.rule 0

# 3. Low-Latency Zero-Drop Network Sysctl (No FQ-CoDel packet drops, No MTU blackholes)
# Use FQ without CoDel AQM drops, or let native MQ handle queueing
if sysctl net.core.default_qdisc | grep -qv "fq_codel"; then
    :
else
    sysctl -w net.core.default_qdisc=fq 2>/dev/null || sysctl -w net.core.default_qdisc=mq 2>/dev/null || true
fi

sysctl -w net.core.netdev_max_backlog=4096
sysctl -w net.core.somaxconn=2048
sysctl -w net.core.rmem_default=1048576
sysctl -w net.core.wmem_default=1048576
sysctl -w net.core.rmem_max=16777216
sysctl -w net.core.wmem_max=16777216
sysctl -w net.ipv4.udp_rmem_min=16384
sysctl -w net.ipv4.udp_wmem_min=16384
sysctl -w net.ipv4.tcp_slow_start_after_idle=0
sysctl -w net.ipv4.tcp_autocorking=0
sysctl -w net.ipv4.tcp_notsent_lowat=16384
sysctl -w net.ipv4.tcp_low_latency=1
sysctl -w net.ipv4.tcp_sack=1
sysctl -w net.ipv4.tcp_timestamps=1
sysctl -w net.ipv4.tcp_tw_reuse=1
sysctl -w net.ipv4.tcp_fin_timeout=15
sysctl -w net.ipv4.tcp_keepalive_time=30
sysctl -w net.ipv4.tcp_keepalive_intvl=5
sysctl -w net.ipv4.tcp_keepalive_probes=3
sysctl -w net.ipv4.tcp_rmem="4096 87380 4194304"
sysctl -w net.ipv4.tcp_wmem="4096 65536 4194304"
sysctl -w net.ipv4.neigh.default.base_reachable_time_ms=600000
sysctl -w net.ipv4.neigh.default.gc_stale_time=86400
sysctl -w net.ipv6.neigh.default.base_reachable_time_ms=600000
sysctl -w net.ipv6.neigh.default.gc_stale_time=86400
# Avoid cellular MTU blackhole packet drops
sysctl -w net.ipv4.ip_no_pmtu_disc=1

# 4. Prevent RILD & Netd CPU Bottleneck (Obsidian Zcore Pattern)
# Expand system-background from 0-2 (Little) to 0-6 (Gold) so radio/netd do not stall
if [ -f /dev/cpuset/system-background/cpus ]; then
    echo 0-6 > /dev/cpuset/system-background/cpus 2>/dev/null || true
fi

# 5. Android Network Settings
settings put global network_recommendations_enabled 0
settings put global mobile_data_always_on 1
cmd wifi force-low-latency-mode enabled 2>/dev/null || true
cmd wifi force-hi-perf-mode enabled 2>/dev/null || true
settings put global wifi_scan_always_enabled 0 2>/dev/null || true
settings put global wifi_sleep_policy 2 2>/dev/null || true
settings put global wifi_power_save 0 2>/dev/null || true

# 6. Interface Queue Tuning (Safe txqueuelen 1000 + Gold Core RPS & XPS)
# Applied strictly once on boot - NO periodic loops, NO mid-game queue lock
for d in /sys/class/net/rmnet* /sys/class/net/wlan* /sys/class/net/tun*; do
    [ -d "$d" ] || continue
    iface="$(basename "$d")"
    cur_txq="$(cat "$d/tx_queue_len" 2>/dev/null)"
    if [ "$cur_txq" -lt 1000 ]; then
        ifconfig "$iface" txqueuelen 1000 2>/dev/null
    fi
    # RX steering to Gold cores (0x78 = cores 3,4,5,6 on SM8635)
    if [ -f "$d/queues/rx-0/rps_cpus" ]; then
        echo 78 > "$d/queues/rx-0/rps_cpus" 2>/dev/null || true
    fi
    # TX steering to Gold cores
    for tx_q in "$d/queues/tx-"*; do
        [ -f "$tx_q/xps_cpus" ] && echo 78 > "$tx_q/xps_cpus" 2>/dev/null || true
    done
done
