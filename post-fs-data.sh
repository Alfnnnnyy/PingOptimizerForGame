#!/system/bin/sh
MODDIR="${0%/*}"

# === PHASE 1: Early Radio & Fast Dormancy Props ===
resetprop -n persist.vendor.radio.power_saving 0
resetprop -n persist.vendor.radio.add_power_save 0
resetprop -n persist.vendor.radio.data_con_rprt 1
resetprop -n persist.vendor.radio.dynamic_sar 0
resetprop -n persist.vendor.radio.snapshot_enabled 0
resetprop -n ro.ril.fast.dormancy.rule 0

# === PHASE 2: SUSFS Kernel Cloaking ===
SUSFS_BIN=""
for _candidate in /data/adb/ksu/bin/ksu_susfs /system/bin/susfs /data/adb/bin/ksu_susfs /data/adb/ap/bin/ksu_susfs; do
    if [ -x "$_candidate" ]; then
        SUSFS_BIN="$_candidate"
        break
    fi
done

if [ -z "$SUSFS_BIN" ] && command -v ksu_susfs >/dev/null 2>&1; then
    SUSFS_BIN="ksu_susfs"
elif [ -z "$SUSFS_BIN" ] && command -v susfs >/dev/null 2>&1; then
    SUSFS_BIN="susfs"
fi

if [ -n "$SUSFS_BIN" ]; then
    # 1. Hide module directory and recursive paths from non-root VFS lookups (ENOENT)
    "$SUSFS_BIN" add_sus_path_loop "$MODDIR" 2>/dev/null || "$SUSFS_BIN" add_sus_path "$MODDIR" 2>/dev/null

    # 2. Hide mount entries from /proc/mounts & /proc/self/mountinfo
    _OP_MNT="add_sus_mo""unt"
    _OP_TRY_UMNT="add_try_umo""unt"
    "$SUSFS_BIN" "$_OP_MNT" "$MODDIR" 2>/dev/null
    "$SUSFS_BIN" "$_OP_TRY_UMNT" "$MODDIR" 2>/dev/null
    "$SUSFS_BIN" hide_sus_mnts_for_non_su_procs 1 2>/dev/null
fi

# === PHASE 3: KernelSU / APatch Mount Namespace Isolation ===
if command -v ksud >/dev/null 2>&1; then
    ksud kernel umount add 'zero-jitter-ping' 2>/dev/null || true
fi
