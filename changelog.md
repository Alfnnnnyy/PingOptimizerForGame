# ZeroJitter Ping Optimizer - Changelog

## v1.2 (versionCode 120)
- **Zero-Drop UDP Network Stack**: Switched from `fq_codel` (which drops UDP packets) to zero-drop queueing discipline.
- **Eliminated Background Ping Daemon**: Removed repeating ping worker to prevent LTE/5G Uplink scheduling contention and socket churn.
- **Hardware Native Headroom**: Restored native `txqueuelen = 1000` to prevent driver-level tail-drops during bursty combat traffic.
- **Cellular MTU Blackhole Fix**: Set `ip_no_pmtu_disc = 1` to prevent carrier GTP-U packet drops.
- **Expanded Socket Backlog**: Increased `netdev_max_backlog = 4096`, `rmem_default = 1MB`, `udp_rmem_min = 16KB`.
- **SuSFS Kernel Cloaking**: Hidden from non-root scanners and anti-cheat via `ksu_susfs add_sus_path_loop` and mount isolation.
- **KernelSU In-App Auto-Update**: Enabled seamless one-tap updates directly in KernelSU manager via `update.json`.

---

## v1.1 (versionCode 110)
- Fixed periodic `ifconfig` loop interruption during active matches.
- Injected persistent radio flags (`persist.vendor.radio.*`) to suppress RRC dormancy sleep.
- Bound network interrupt queues (RPS/XPS) to Gold Cortex-A720 performance cores (`0x78`).

---

## v1.0 (versionCode 100)
- Initial release for POCO F6 (`peridot`) / Snapdragon 8s Gen 3 (`SM8635`).
- Fix 170ms+ ping spikes on cellular data (Telkomsel LTE/5G).
