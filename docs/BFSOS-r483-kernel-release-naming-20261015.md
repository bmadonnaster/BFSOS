# BFSOS r483 — Kernel release identity standardization

## New naming (source-tree revision; not yet installed-system migration)

| Port | `uname -r` / kernel release | Module tree | Kernel source tree |
|---|---|---|---|
| `linux` (default 6.18.56 LTS, release 2) | `6.18.56-BFSOS-LTS` | `/lib/modules/6.18.56-BFSOS-LTS` | `/usr/src/linux-6.18.56-BFSOS-LTS` |
| `linux-mainline` (7.2.10, release 3) | `7.2.10-BFSOS-Mainline` | `/lib/modules/7.2.10-BFSOS-Mainline` | `/usr/src/linux-7.2.10-BFSOS-Mainline` |

The `/boot/vmlinuz-<release>`, initramfs, config and System.map names follow these release names. The conventional `/usr/src/linux` selected-kernel alias remains. `/boot/vmlinuz-lts` stays an LTS convenience alias. Kernel package names remain `linux` and `linux-mainline`; headers stay `linux-headers`.

## Modified source

Linux Pkgfiles, seed configs, versioned footprints, kernel post-install hooks; mainline config generator; `bfs-kernel-maintenance` and its package release (now 1.0-4); ISO builder and installer kernel-discovery patterns; kernel maintenance regression test. Legacy `-BFS-LTS`/`-BFS-Linux` are accepted by the maintenance finalizer; legacy LTS GRUB entries remain recognizable in MD checks.

## Safety / outstanding verification

- **DO NOT** rename live `/lib/modules`, `/usr/src`, or `/boot` paths by hand. Kernel build `LOCALVERSION` produces the release name; build/install/dracut must create the matching files.
- This archive does **not** migrate the installed `linux-lts` package database to `linux`. The `linux` pre-install guard still rejects an existing `linux-lts` package. Implement and test a safe, transactional migration before any installed-system rename.
- Rebuild **both** kernels for the new local versions and compare the generated footprints (`pkgmk -kw`), including the currently preexisting `<kernel-version>` placeholders in the `linux` footprint. The included footprints are name projections, not freshly produced by a successful build.
- Test live boot, Dracut initramfs, GRUB default/recovery, RAID+LVM, kernel maintenance rollback and old-kernel coexistence in the VM, with the QCOW2 backup retained.
- No kernel compilation or live guest migration was performed in the packaging environment.
