# BFSOS manual kernel and GRUB guide

This guide is for advanced BFSOS users who want to build a kernel manually or repair/install GRUB without using the installer. The packaged `linux-lts` kernel remains the normal BFSOS default and should be kept available while testing a custom kernel.

The workflow follows the general CRUX/LFS model—configure an upstream kernel, build and install it, then install/update the bootloader—but the option baseline below reflects the current BFSOS kernel ports and its Dracut/systemd/storage policy.

## Start from the BFSOS configuration

For the least surprising result, begin with the configuration shipped by the current BFSOS kernel port:

```bash
cd ~/BFSOS/ports/core/linux-lts
cp config /path/to/linux-source/.config
```

For the optional current kernel use `ports/core/linux/config` instead. In the kernel source tree:

```bash
make olddefconfig
make menuconfig
```

Give a custom kernel a unique local version so it cannot overwrite packaged BFSOS files, for example:

```text
CONFIG_LOCALVERSION="-BFS-CUSTOM"
```

Keep the packaged LTS kernel and its initramfs until the custom kernel has booted successfully.


## Finding the options in `menuconfig`

Kernel menu locations can move slightly between releases, so the most reliable way to find an option is to search by its config symbol.

From the kernel source tree:

```bash
make menuconfig
```

Press `/` and search for the symbol **without** the `CONFIG_` prefix. For example:

```text
BLK_DEV_NVME
SATA_AHCI
EXT4_FS
XFS_FS
BTRFS_FS
DM_CRYPT
```

The search result shows the prompt, dependencies, current value, and the current menu path for that exact kernel release.

The major BFSOS groups are normally under:

```text
General setup
  Initial RAM filesystem and RAM disk support
  Control Group support

Device Drivers
  Generic Driver Options
  NVM Express block device
  SCSI device support
  Serial ATA and Parallel ATA drivers (libata)
  Multiple devices driver support (RAID and LVM)

File systems
  Ext4
  XFS
  Btrfs
  F2FS
  DOS/FAT filesystems
```

When in doubt, use `/` search because it reports the exact current path and any missing dependency.

## Apply the BFSOS recommended baseline automatically

The kernel source tree contains `scripts/config`, which can edit `.config` directly by symbol name. Start from the maintained BFSOS LTS configuration:

```bash
cp ~/BFSOS/ports/core/linux-lts/config .config
```

Then apply the common BFSOS boot/storage/filesystem baseline:

```bash
scripts/config     --enable BLK_DEV_INITRD     --enable DEVTMPFS     --enable DEVTMPFS_MOUNT     --enable CGROUPS     --enable MEMCG     --enable CGROUP_SCHED     --enable INOTIFY_USER     --enable TMPFS     --enable TMPFS_POSIX_ACL     --enable NET     --enable INET     --enable IPV6     --enable PARTITION_ADVANCED     --enable MSDOS_PARTITION     --enable EFI_PARTITION     --enable SCSI     --enable BLK_DEV_SD     --enable ATA     --enable SATA_AHCI     --enable NVME_CORE     --enable BLK_DEV_NVME     --enable BLK_DEV_MD     --enable MD     --module MD_RAID0     --module MD_RAID1     --module MD_RAID10     --module MD_RAID456     --enable BLK_DEV_DM     --module DM_CRYPT     --enable EXT4_FS     --enable XFS_FS     --enable BTRFS_FS     --module F2FS_FS     --module FAT_FS     --module MSDOS_FS     --module VFAT_FS     --enable NLS     --enable NLS_CODEPAGE_437     --module NLS_ISO8859_1     --enable EFI     --enable EFI_STUB     --enable EFIVAR_FS     --enable VT     --enable VT_CONSOLE     --enable FRAMEBUFFER_CONSOLE     --enable DRM     --enable DRM_FBDEV_EMULATION     --enable DRM_SIMPLEDRM     --enable KERNEL_ZSTD     --enable MODULE_COMPRESS_ZSTD     --enable RELOCATABLE     --enable RANDOMIZE_BASE     --enable STACKPROTECTOR     --enable STACKPROTECTOR_STRONG     --enable PSI
```

For a custom kernel name:

```bash
scripts/config --set-str LOCALVERSION "-BFS-CUSTOM"
```

Then reconcile dependencies and newly introduced kernel options:

```bash
make olddefconfig
```

A quick audit of the important settings:

```bash
grep -E 'CONFIG_(BLK_DEV_INITRD|DEVTMPFS|CGROUPS|NVME|BLK_DEV_NVME|SCSI|BLK_DEV_SD|ATA|SATA_AHCI|BLK_DEV_MD|MD_RAID|BLK_DEV_DM|DM_CRYPT|EXT4_FS|XFS_FS|BTRFS_FS|F2FS_FS|VFAT_FS|EFI|VT|FRAMEBUFFER_CONSOLE|DRM_SIMPLEDRM|KERNEL_ZSTD|MODULE_COMPRESS_ZSTD)=' .config
```

This is a baseline, not a replacement for hardware-specific configuration. Network, GPU, sound, USB, CPU, input, virtualization, and other machine-specific drivers still need to match the hardware.

### Built-in versus module

BFSOS uses Dracut, so many storage features can be modules as long as the initramfs contains them. Anything required to reach the root filesystem is safest as built-in (`=y`) when building a recovery kernel or booting without an initramfs.

For an NVMe root using XFS:

```bash
scripts/config     --enable NVME_CORE     --enable BLK_DEV_NVME     --enable XFS_FS
```

For a SATA/AHCI root using ext4:

```bash
scripts/config     --enable SCSI     --enable BLK_DEV_SD     --enable ATA     --enable SATA_AHCI     --enable EXT4_FS
```

After changes:

```bash
make olddefconfig
```

## BFSOS baseline options

The maintained `linux` and `linux-lts` Pkgfiles explicitly reconcile important options after loading their known-good configs. For a general-purpose BFSOS kernel, verify at least the following groups.

### Required for the normal BFSOS boot/userspace path

```text
CONFIG_64BIT=y
CONFIG_X86_64=y
CONFIG_BLK_DEV_INITRD=y
CONFIG_DEVTMPFS=y
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_CGROUPS=y
CONFIG_MEMCG=y
CONFIG_CGROUP_SCHED=y
CONFIG_INOTIFY_USER=y
CONFIG_TMPFS=y
CONFIG_TMPFS_POSIX_ACL=y
CONFIG_NET=y
CONFIG_INET=y
CONFIG_IPV6=y
```

BFSOS uses systemd and Dracut, so initramfs, devtmpfs, cgroups, normal networking, and the pseudo-filesystem support above should not be removed from a normal configuration.

### Storage used by the BFSOS installer

The kernel must contain the controller driver and filesystem support needed to reach the root filesystem. BFSOS supports NVMe and SATA/AHCI systems, USB storage, LVM/device mapper, LUKS, Linux MD RAID, and the common filesystems offered by the installer.

#### NVMe

For PCIe/NVMe SSDs, BFSOS enables:

```text
CONFIG_NVME_CORE=y
CONFIG_BLK_DEV_NVME=y
```

Typical area:

```text
Device Drivers
  NVM Express block device
```

Enable it directly:

```bash
scripts/config     --enable NVME_CORE     --enable BLK_DEV_NVME
```

If `/` is directly on NVMe, building these in (`=y`) gives the simplest early-boot/recovery path.

#### SATA / AHCI

For normal SATA SSDs and hard disks, BFSOS enables:

```text
CONFIG_SCSI=y
CONFIG_BLK_DEV_SD=y
CONFIG_ATA=y
CONFIG_SATA_AHCI=y
```

Typical areas:

```text
Device Drivers
  SCSI device support
    SCSI disk support

Device Drivers
  Serial ATA and Parallel ATA drivers (libata)
    AHCI SATA support
```

Enable them directly:

```bash
scripts/config     --enable SCSI     --enable BLK_DEV_SD     --enable ATA     --enable SATA_AHCI
```

`CONFIG_BLK_DEV_SD` is important even for ordinary SATA disks because Linux exposes them through the SCSI disk layer.

#### USB storage

The BFSOS LTS config carries:

```text
CONFIG_USB_STORAGE=m
```

Enable it with:

```bash
scripts/config --module USB_STORAGE
```

The machine's USB host-controller driver must also be enabled.

#### Partition tables

For BIOS/MBR and GPT/UEFI layouts:

```text
CONFIG_PARTITION_ADVANCED=y
CONFIG_MSDOS_PARTITION=y
CONFIG_EFI_PARTITION=y
```

Enable them with:

```bash
scripts/config     --enable PARTITION_ADVANCED     --enable MSDOS_PARTITION     --enable EFI_PARTITION
```

#### Filesystems

The maintained BFSOS LTS config currently uses:

```text
CONFIG_EXT4_FS=y
CONFIG_XFS_FS=y
CONFIG_BTRFS_FS=y
CONFIG_F2FS_FS=m
CONFIG_FAT_FS=m
CONFIG_MSDOS_FS=m
CONFIG_VFAT_FS=m
```

Typical menu locations:

```text
File systems
  Ext4 journalling file system support
  XFS filesystem support
  Btrfs filesystem support
  F2FS filesystem support

File systems
  DOS/FAT/EXFAT/NT Filesystems
    MSDOS fs support
    VFAT (Windows-95) fs support
```

Enable the normal BFSOS set:

```bash
scripts/config     --enable EXT4_FS     --enable XFS_FS     --enable BTRFS_FS     --module F2FS_FS     --module FAT_FS     --module MSDOS_FS     --module VFAT_FS
```

Use `/` in `menuconfig` to search `EXT4_FS`, `XFS_FS`, `BTRFS_FS`, `F2FS_FS`, or `VFAT_FS` for the exact location in the kernel being built.

The root filesystem's driver must be available during early boot. With Dracut it may be a module included in the initramfs; without an initramfs it must be built into the kernel.

VFAT is needed by Linux to mount a normal FAT32 EFI System Partition at `/boot/efi` for GRUB installation and maintenance.

#### LVM / device mapper

BFSOS uses device mapper for LVM:

```text
CONFIG_BLK_DEV_DM=y
```

Typical area:

```text
Device Drivers
  Multiple devices driver support (RAID and LVM)
    Device mapper support
```

Enable it with:

```bash
scripts/config --enable BLK_DEV_DM
```

#### LUKS / dm-crypt

LUKS normally uses:

```text
CONFIG_DM_CRYPT=m
```

Typical area:

```text
Device Drivers
  Multiple devices driver support (RAID and LVM)
    Device mapper support
      Crypt target support
```

Enable it with:

```bash
scripts/config     --enable BLK_DEV_DM     --module DM_CRYPT
```

Because BFSOS uses Dracut, `DM_CRYPT=m` is fine when the module is included in the initramfs. Use `--enable DM_CRYPT` if you deliberately want it built into the kernel.

#### MD software RAID

The maintained BFSOS LTS config includes:

```text
CONFIG_BLK_DEV_MD=y
CONFIG_MD=y
CONFIG_MD_RAID0=m
CONFIG_MD_RAID1=m
CONFIG_MD_RAID10=m
CONFIG_MD_RAID456=m
```

Typical area:

```text
Device Drivers
  Multiple devices driver support (RAID and LVM)
    RAID support
      RAID-0
      RAID-1
      RAID-10
      RAID-4/RAID-5/RAID-6
```

Enable the BFSOS set:

```bash
scripts/config     --enable BLK_DEV_MD     --enable MD     --module MD_RAID0     --module MD_RAID1     --module MD_RAID10     --module MD_RAID456
```

For an MD array containing `/`, the required RAID personality must either be built in or included by Dracut.

#### Example BFSOS storage stacks

```text
NVMe -> GPT -> LVM -> XFS
SATA -> GPT -> LUKS -> LVM -> ext4
4 x SATA HDD -> MD RAID10 -> LVM -> XFS
NVMe -> GPT -> Btrfs
```

Every layer needed to reach `/` must be available during early boot.

After changing storage options, regenerate the initramfs for the exact kernel:

```bash
KREL=$(make -s kernelrelease)
sudo dracut --force "/boot/initramfs-$KREL.img" "$KREL"
```

### UEFI

For normal UEFI systems keep:

```text
CONFIG_EFI=y
CONFIG_EFI_STUB=y
CONFIG_EFI_PARTITION=y
CONFIG_VFAT_FS=y
CONFIG_EFIVAR_FS=y
CONFIG_NLS=y
CONFIG_NLS_CODEPAGE_437=y
CONFIG_NLS_ISO8859_1=y
```

`VFAT_FS` is needed for the normal FAT32 EFI System Partition.

### Console and graphics fallback

The BFSOS configs intentionally retain a boot-visible console path:

```text
CONFIG_VT=y
CONFIG_VT_CONSOLE=y
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_FB=y
CONFIG_DRM=y
CONFIG_DRM_FBDEV_EMULATION=y
CONFIG_DRM_SIMPLEDRM=y
CONFIG_FRAMEBUFFER_CONSOLE=y
```

Hardware-specific DRM drivers may be modules, but avoid removing the generic early-console path when building a recovery-capable kernel.

### BFSOS policy choices

The packaged kernels also deliberately use Zstandard compression and normal hardening options. Important examples include `CONFIG_KERNEL_ZSTD`, module compression with Zstd, `CONFIG_RELOCATABLE`, `CONFIG_RANDOMIZE_BASE`, `CONFIG_STACKPROTECTOR`, and `CONFIG_STACKPROTECTOR_STRONG`.

BFSOS disables kernel `WERROR` so a new compiler warning does not unnecessarily turn into a kernel build failure. It enables PSI and does not use `PSI_DEFAULT_DISABLED`. These choices mirror the maintained BFSOS package recipes even where a generic CRUX custom-kernel guide may leave them entirely to the administrator.

Hardware-specific drivers remain your responsibility; do not enable every possible option merely to match a generic list.

## Build and install a custom kernel

From the configured kernel source tree:

```bash
make -j"$(nproc)"
sudo make modules_install
```

Determine the resulting release string:

```bash
make -s kernelrelease
```

Then install the kernel, System.map, and configuration using unique names. For example, with `KREL=$(make -s kernelrelease)`:

```bash
KREL=$(make -s kernelrelease)
sudo cp -v arch/x86/boot/bzImage "/boot/vmlinuz-$KREL"
sudo cp -v System.map "/boot/System.map-$KREL"
sudo cp -v .config "/boot/config-$KREL"
```

Generate a Dracut initramfs for that exact kernel:

```bash
sudo dracut --force "/boot/initramfs-$KREL.img" "$KREL"
```

Confirm that `/lib/modules/$KREL`, the kernel image, and initramfs all exist before touching GRUB.

## Regenerate GRUB configuration

After adding or removing kernels:

```bash
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Inspect the generated menu before rebooting and keep at least one known-good BFSOS kernel entry.

# Manual GRUB installation

Mount the installed BFSOS root first. If `/boot` or `/boot/efi` are separate filesystems, mount them at their normal locations inside that root before running `grub-install`. When repairing from the live ISO, bind-mount `/dev`, `/proc`, `/sys`, and `/run` as needed and enter the installed system with `chroot`.

## UEFI

The BFSOS installer uses the EFI System Partition at `/boot/efi` and the bootloader identifier `BFS`.

Verify that the ESP is mounted:

```bash
findmnt /boot/efi
```

Install GRUB:

```bash
sudo grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=BFS
```

The normal BFSOS EFI loader should then exist at:

```text
/boot/efi/EFI/BFS/grubx64.efi
```

For firmware that requires the removable/fallback path, BFSOS also supports:

```bash
sudo grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=BFS \
    --removable
```

That path should produce `EFI/BOOT/BOOTX64.EFI` on the ESP. Regenerate `/boot/grub/grub.cfg` afterward.

## Legacy BIOS

Install GRUB to the whole boot disk, **not to a filesystem partition**. Example:

```bash
sudo grub-install /dev/sda
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

Replace `/dev/sda` with the actual disk that firmware boots. On a GPT disk used with legacy BIOS GRUB, provide a small BIOS Boot partition (`bios_grub` type/flag); it is not mounted as a normal filesystem.

## Separate `/boot`, LVM, RAID, LUKS, and Btrfs

GRUB must be able to read the files needed to start the kernel, and Dracut must contain the drivers/tools needed to reach the real root. With a separate `/boot`, mount it before installing or regenerating GRUB. With LVM, MD RAID, LUKS, or Btrfs root, regenerate the initramfs after storage-related kernel changes and verify that the resulting GRUB command line identifies the intended root layout.

## Recovery from the BFSOS live ISO

A typical repair sequence is:

```bash
sudo mount /dev/ROOT /mnt/bfs
sudo mount /dev/BOOT /mnt/bfs/boot              # if separate
sudo mount /dev/ESP /mnt/bfs/boot/efi           # UEFI only
sudo mount --rbind /dev  /mnt/bfs/dev
sudo mount --make-rslave /mnt/bfs/dev
sudo mount -t proc proc /mnt/bfs/proc
sudo mount --rbind /sys  /mnt/bfs/sys
sudo mount --make-rslave /mnt/bfs/sys
sudo mount --rbind /run  /mnt/bfs/run
sudo mount --make-rslave /mnt/bfs/run
sudo chroot /mnt/bfs /bin/bash
```

Inside the chroot, run the appropriate UEFI or BIOS `grub-install` command and then:

```bash
grub-mkconfig -o /boot/grub/grub.cfg
```

Before rebooting, verify the expected kernel/initramfs files and the generated GRUB entries. Exit the chroot and unmount the target filesystems cleanly.
