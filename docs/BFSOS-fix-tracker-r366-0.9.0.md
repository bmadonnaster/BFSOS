# BFSOS Fix Tracker — r366

Updated: 2026-10-01

## [x] SOURCE COMPLETE — expand manual kernel guide option locations and storage coverage

`docs/KERNEL-GRUB.md` now:

- explains `make menuconfig` `/` symbol search so users can find the exact current menu path for each `CONFIG_*` option;
- provides a copy/paste `scripts/config` baseline for the BFSOS recommended kernel settings;
- explicitly documents NVMe and SATA/AHCI;
- documents SCSI disk support required by SATA;
- documents USB storage and MBR/GPT partition support;
- documents ext4, XFS, Btrfs, F2FS, FAT/MSDOS/VFAT and the current BFSOS built-in/module defaults;
- documents LVM/device mapper, LUKS/dm-crypt, and Linux MD RAID including RAID10;
- explains built-in versus module choices with Dracut;
- gives example BFSOS storage stacks and exact initramfs regeneration commands.

Runtime acceptance remains open until the documented `scripts/config` baseline is exercised against the active BFSOS LTS source and a custom kernel is built/booted.

**Status: SOURCE COMPLETE; kernel-build/boot acceptance remains open.**
