# kernel_xiaomi_ginkgo_ksu

Custom 4.14.356 kernel for Xiaomi Redmi Note 8 / 8T (ginkgo / willow,
SoC sm6125) with KernelSU-Next + SUSFS, built against the
EvolutionX 16 / LineageOS 23.x base.

Branch `ginkgo-susfs` is the working line.

## Stack

- Base: Evolution-X-Devices/kernel_xiaomi_sm6125 (branch `bka`, kernel
  4.14.356-OpenELA), tracked here as the `upstream` remote.
- Root: KernelSU-Next `v3.1.0-legacy-susfs` (submodule, manual hooks —
  this is the **last** KSU-Next tag that ships SUSFS integration;
  v3.2.0 onwards removed it).
- Stealth: SUSFS v2.1.0 sources imported from sidex15-kernel
  v4.14.355-OpenELA-v7, patched for KSU's v2.0.0 API expectations
  (signature mismatches stubbed in `fs/susfs.c`).
- Toolchain: Neutron Clang at `~/toolchains/neutron-clang`. External
  `dtc` 1.7.2 is required for the `&label`-style plugin overlay
  syntax in `arch/arm64/boot/dts/xiaomi/`; the bundled DTC 1.4.4
  cannot parse it.

## Clone

```sh
git clone --recurse-submodules \
    git@github.com:fnxln/kernel_xiaomi_ginkgo_ksu.git \
    -b ginkgo-susfs
cd kernel_xiaomi_ginkgo_ksu
patches/apply.sh   # apply local mods to KernelSU-Next/
```

If you already cloned without submodules:

```sh
git submodule update --init
patches/apply.sh
```

## Build

```sh
export PATH=~/toolchains/neutron-clang/bin:$PATH
make O=out ARCH=arm64 LLVM=1 LLVM_IAS=1 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    DTC_EXT=/usr/sbin/dtc \
    -j$(nproc)
```

Output: `out/arch/arm64/boot/Image.gz`,
`out/arch/arm64/boot/dts/xiaomi/qcom-base/trinket.dtb`,
`out/arch/arm64/boot/dts/xiaomi/ginkgo-trinket-overlay.dtbo`.

The `ginkgo-susfs` defconfig fragments are merged automatically from
`arch/arm64/configs/vendor/trinket-perf_defconfig` +
`vendor/xiaomi-trinket.config` + `vendor/ginkgo.config` at make time.

## Flashing

Pack the kernel into AnyKernel3 with an Android-DTBO-wrapped overlay
(use `mkdtboimg.py` to wrap `ginkgo-trinket-overlay.dtbo` into a real
`dtbo.img`). The flash script must drop the matching `ksud` binary
(from KernelSU-Next's release for the same version code as the
manager APK) into `/data/adb/ksud` and chmod it 0755 — without that
file the kernel's init.rc inject has nothing to exec at
`on post-fs-data` and the manager APK keeps showing the "v2 signature
not found" error.

Flash via TWRP/OFOX with `/data` **decrypted** before installing —
writing to encrypted `/data` from a recovery that hasn't decrypted
the FBE volume produces ksud binary bytes the running system can't
read.

## Manual-hook integration notes

Non-GKI 4.14 uses manual hooks (no kprobes). The following call
sites are wired in this tree:

| Hook                              | Site                            |
|-----------------------------------|---------------------------------|
| `ksu_handle_sys_reboot`           | `kernel/reboot.c`               |
| `ksu_handle_execveat`             | `fs/exec.c` do_execve, compat   |
| `ksu_handle_vfs_read`             | `fs/read_write.c` vfs_read      |
| Manual umount support             | `fs/internal.h`, `fs/namespace.c` |
| `seccomp.filter_count` exposure   | `include/linux/seccomp.h`       |
| SELinux helpers (sid/cred/inode)  | `security/selinux/*`            |

The `vfs_read` and `execveat` hooks were added on top of the
upstream KSU manual-hook patches because without them ksud is never
exec'd from init and the manager APK can't bootstrap. See commit
`77efa0b5c216` for the rationale.

### Throne fallback (`patches/ksunext/0001-…patch`)

KernelSU-Next's `pkg_observer` tries to set an `fsnotify` mark on
`/data/system` from `kernelsu_init()`, but on this kernel `/data` is
not mounted yet at that point and the mark fails. As a result the
"crown the manager APK by signature" search never fires through its
normal trigger.

The local patch in `patches/ksunext/` makes `do_get_info()` call
`track_throne(false)` synchronously the first time a probe arrives
while `ksu_manager_appid` is still invalid. The very first
`sys_reboot(KSU_INSTALL_MAGIC1, …, CMD_GET_INFO, …)` from the
manager APK now scans `/data/app`, matches the APK signature, and
crowns the manager on the spot.

This is **not** something the upstream KSU-Next team should carry —
it's a workaround for a non-GKI 4.14 boot-order quirk. Hence the
patches/ dir instead of a submodule fork.

## License

GPLv2 (inherited from Linux kernel).
