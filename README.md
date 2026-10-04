# ZeroJitter Ping Optimizer

Modul Magisk / KernelSU / APatch untuk menstabilkan ping jaringan seluler (LTE / 5G) dan mengeliminasi lonjakan latensi (ping jumping 60-70ms ke 170ms+) saat momen krusial PvP / crowd control (CC). Dilengkapi proteksi **SuSFS Kernel Stealth** agar modul tidak terdeteksi game / scanner anti-cheat.

---

## Akar Masalah Lonjakan Ping (Research & Diagnostic)

1. **RRC Inactivity & c-DRX Sleep (Modem Sleep Penalty)**
   - Pada jaringan LTE/5G (misal Telkomsel), modem Snapdragon X70 masuk ke mode hemat daya Discontinuous Reception (c-DRX) jika jeda paket > 200ms.
   - Saat burst skill/CC musuh masuk, modem butuh waktu bangun (PUCCH Scheduling Request & PDCCH UL Grant) yang memicu penalti latensi instan +80ms s.d. +150ms (ping 70ms melompat ke 170-450ms).
2. **Bufferbloat Antrean Linux (`netdev_max_backlog = 100000`, `txqueuelen = 1000`)**
   - Buffer kernel terlalu besar menampung antrean FIFO (`pfifo_fast`), menahan paket game kecil di belakang paket data lain saat terjadi lonjakan burst.
3. **TCP Slow Start After Idle (`tcp_slow_start_after_idle = 1`)**
   - Kernel mereset congestion window (cwnd) ke minimum jika koneksi sempat hening 1-2 detik (misal saat sembunyi/diam). Begitu war dimulai, koneksi tersedak *slow start*.
4. **TCP Autocorking (`tcp_autocorking = 1`)**
   - Kernel sengaja menunda pengiriman paket kecil untuk digabung ke paket besar. Sangat fatal untuk game PvP realtime.
5. **Neighbor / Gateway Re-probing (`base_reachable_time_ms = 15000`)**
   - Setiap 15 detik, kernel menandai rute gateway stale dan mengirim probe verifikasi, memicu stutter periodik.
6. **CPUSet System-Background Terkunci di Little Core (`0-2`)**
   - Daemon `rild` (Radio Interface Layer) dan `netd` dicekik di Cortex-A520 yang sering downclock ke 300MHz.

---

## 8 Pilar Optimasi ZeroJitter

1. **Anti-DRX Radio Keep-Warm Worker (Screen-Aware)**
   - Saat layar aktif (`mWakefulness=Awake`), mengirim micro-pulse (payload 0-byte, total 28-byte) interval 0.5s ke Cloudflare (1.1.1.1).
   - Mengunci modem LTE/5G tetap pada status `RRC_CONNECTED` continuous tanpa jeda bangun.
   - Konsumsi kuota hanya ~200 KB/jam, beban CPU 0.00%.
   - Saat layar mati/terkunci, worker otomatis pause agar ponsel bisa deep sleep normal.
2. **Queueing Discipline FQ-CoDel (`default_qdisc = fq_codel`)**
   - Menggantikan FIFO. Paket game realtime diberi prioritas flow terpisah dan langsung dilewatkan tanpa antre di belakang paket bulk.
3. **Anti-Bufferbloat Queue Capping**
   - `netdev_max_backlog = 512` (dari default 100.000).
   - `txqueuelen = 128` pada interface seluler (`rmnet_data*`) dan Wi-Fi.
   - `tcp_notsent_lowat = 16384`.
4. **TCP Hot-Start & Zero-Corking**
   - `tcp_slow_start_after_idle = 0` (menjaga cwnd tetap panas).
   - `tcp_autocorking = 0` (kirim paket game secepatnya).
5. **ARP & Neighbor Table Stability**
   - `base_reachable_time_ms = 600000` (10 menit, hilangkan probe drop tiap 15 detik).
   - `gc_stale_time = 86400`.
6. **RILD & Netd CPUSet Expansion**
   - `/dev/cpuset/system-background/cpus` diperluas dari `0-2` ke `0-6` (Gold Cores Cortex-A720).
7. **RPS Network Steering ke Performance Cores**
   - Memetakan pemrosesan interrupt softirq `rmnet_data*` ke CPU Gold (`0x78` = Core 3, 4, 5, 6 pada Snapdragon 8s Gen 3).
8. **Modem Dynamic SAR & Fast Dormancy Suppression**
   - Menyuntikkan konfigurasi radio lewat `system.prop` (`ro.ril.fast.dormancy.rule=0`, `persist.vendor.radio.power_saving=0`).

---

## SuSFS Kernel Stealth & Anti-Detection

Modul ini mengimplementasikan pola SuSFS dari proyek `Zcore` dan `PeridotCN-Spoofer`:
* **VFS Inode Path Hiding (`add_sus_path_loop`)**: Path `/data/adb/modules/zero-jitter-ping` dikembalikan sebagai `ENOENT` (tidak ditemukan) untuk seluruh proses non-root / game / detector.
* **Mountinfo Hiding (`add_sus_mount` & `hide_sus_mnts_for_non_su_procs`)**: Mencegah deteksi via `/proc/mounts` atau `/proc/self/mountinfo`.
* **KernelSU Umount Isolation (`ksud kernel umount add 'zero-jitter-ping'`)**: Module mount di-unmount dari mount namespace non-root.

---

## Struktur File Modul

```
PingOptimizerForGame/
├── module.prop                          # Metadata modul
├── customize.sh                         # Installer & permission handler
├── post-fs-data.sh                      # SuSFS early cloaking & mount isolation
├── service.sh                           # Boot hook, sysctl, daemon keep-warm
├── system.prop                          # Radio property injection
├── sepolicy.rule                        # Izin SELinux untuk sysfs_net
├── ZeroJitter-PingOptimizer-v1.0.zip   # Flashable ZIP untuk Magisk / KernelSU / APatch
└── README.md
```

---

## Cara Pasang (Jika Disetujui)

1. **Via KernelSU / APatch / Magisk App**:
   - Buka aplikasi Root Manager -> Tab Modul -> Pasang dari Penyimpanan -> Pilih `ZeroJitter-PingOptimizer-v1.0.zip`.
   - Reboot ponsel.
2. **Via ADB**:
   ```bash
   adb push ZeroJitter-PingOptimizer-v1.0.zip /sdcard/Download/
   ```
   Lalu flash via Magisk/KernelSU app di ponsel.
