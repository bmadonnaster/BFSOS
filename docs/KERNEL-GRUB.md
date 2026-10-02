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

Enable the controller/filesystem support needed to reach your root filesystem. The maintained BFSOS configs explicitly enable common x86_64 paths including:

```text
CONFIG_BLK_DEV_NVME=y
CONFIG_SCSI=y
CONFIG_BLK_DEV_SD=y
CONFIG_ATA=y
CONFIG_SATA_AHCI=y
CONFIG_EXT4_FS=y
CONFIG_XFS_FS=y
CONFIG_BTRFS_FS=y
CONFIG_F2FS_FS=y
```

BFSOS also supports device-mapper/LVM, MD software RAID, and LUKS/dm-crypt layouts. Keep the required block, device-mapper, MD/RAID, and cryptographic options enabled when your installation uses those features. Storage needed before the real root is mounted must either be built into the kernel or be present in the Dracut initramfs.

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
