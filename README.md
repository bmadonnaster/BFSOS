# BFSOS

BFSOS is an x86_64 source-built Linux distribution maintained by Brian Madonna. It uses an LFS/MLFS-style bootstrap, CRUX `pkgutils`/ports for package builds, `prt-get` for dependency-aware package management, systemd, Dracut, GRUB, and a Dialog-based installer that supports both straightforward and layered storage layouts.

> **Current release:** 0.9.0. BFSOS is usable for development and testing, but the 1.0 release line is still under active validation. Keep backups when testing installer/storage changes on important systems.

## Highlights

- Source-built temporary toolchain and base system.
- Optional final-toolchain rebuild to verify that the base can rebuild itself.
- CRUX-style ports and `pkgutils`, extended for BFSOS build conventions.
- `prt-get` dependency management and Git-backed ports synchronization.
- x86_64 multilib support with 32-bit libraries under `/usr/lib32`.
- systemd with an explicit BFSOS service preset policy.
- Dracut initramfs generation and GRUB bootloader support.
- UEFI and legacy BIOS installation paths.
- Installer support for Btrfs subvolumes/snapshots, LUKS, LVM, md RAID, and layered combinations.
- Kernel selection between the default Linux **6.18.54 LTS** package and the optional **7.2.8** current kernel.
- Optional installer-managed ZRAM swap.
- Console-font choices on live media and the installed system for improved readability.
- SourceForge-hosted release/base artifacts with versioned checksums.

## Repository and releases

The authoritative source repository is:

```text
https://github.com/bmadonnaster/BFSOS
```

Issues and support:

```text
https://github.com/bmadonnaster/BFSOS/issues
```

Large base archives and public ISO releases are hosted through the BFSOS SourceForge project. SourceForge remains the release-artifact host; GitHub is the source-control host.

## Repository layout

- `bootstrap.sh` — authoritative bootstrap menu, direct stage commands, full bootstrap, and ISO/installer handoff.
- `ports/` — maintained package recipes and desktop/compatibility collections.
- `scripts/install-bfs-menu-current.sh` — canonical installer.
- `scripts/bfs-build-iso.sh` — canonical live ISO builder.
- `scripts/bfs-publish-sourceforge.sh` — canonical SourceForge publisher.
- `scripts/tests/` — source/regression checks.
- `docs/` — installation, audit, tracker, and maintenance documentation.
- `files/` — shared BFSOS build/runtime support files.
- `archives/` — generated toolchain/base archives when present locally (normally not tracked).
- `logs/` — local build/install logs (normally not part of release source archives).

Historical tracker documents are kept under `docs/`; Git history is the rollback mechanism for obsolete script revisions.

## Getting started

```sh
git clone https://github.com/bmadonnaster/BFSOS.git
cd BFSOS
./bootstrap.sh
```

The no-argument command opens the interactive bootstrap menu. A full automated bootstrap can be started directly with:

```sh
./bootstrap.sh full
```

Individual stages can also be invoked directly:

```sh
./bootstrap.sh 1
./bootstrap.sh 2
./bootstrap.sh 3
./bootstrap.sh 4
./bootstrap.sh 5
```

See `docs/COMMAND-LINE.md` for the maintained script entry points, `docs/INSTALL.md` for the installer workflow, `docs/KERNEL-GRUB.md` for manual kernel/bootloader work, and `docs/PORTS.md` for creating and maintaining packages.

## Bootstrap stages

The normal build path is:

1. **Build temporary toolchain** — required.
2. **Build base system with temporary toolchain** — required.
3. **Rebuild base with the final toolchain** — optional validation stage.
4. **Verify completed base system** — required before archiving.
5. **Create/compress and verify the base rootfs archive** — required for installer/ISO reuse.
6. Restore the newest base rootfs archive.
7. Restore the newest temporary-toolchain archive.
8. Chroot into the built/restored BFSOS rootfs.
9. Launch the BFSOS installer.

Generated bootstrap archives use zstd compression and carry BFSOS version/build identity.

## Installer and storage

The installer can build simple layouts or layered storage such as:

```text
md RAID -> LUKS -> LVM -> Btrfs subvolumes
```

It supports filesystem/mount-point assignment, ZRAM, users/groups, networking, console/font settings, kernel selection, sudo policy, GRUB/UEFI configuration, a complete pre-install review, and a post-install choice to enter the target through chroot or finish/unmount cleanly.

Storage operations can destroy data. Review the filesystem plan and final installation review before starting an install. Test unfamiliar RAID/LUKS/LVM combinations in a VM first.

## Documentation and contributing

- Installation: [`docs/INSTALL.md`](docs/INSTALL.md)
- Maintainer/CLI workflows: [`docs/COMMAND-LINE.md`](docs/COMMAND-LINE.md)
- Creating and maintaining ports: [`docs/PORTS.md`](docs/PORTS.md)
- Manual kernel build / UEFI + legacy GRUB: [`docs/KERNEL-GRUB.md`](docs/KERNEL-GRUB.md)
- Contribution guidance: [`CONTRIBUTING.md`](CONTRIBUTING.md)
- Bugs and feature requests: <https://github.com/bmadonnaster/BFSOS/issues>
- Release downloads: <https://sourceforge.net/projects/bfsos/files/BFSOS/>

The public BFSOS website is intended for SourceForge Project Web. GitHub remains authoritative for source, pull requests, and issue tracking.

## Package management

Update ports and installed packages with:

```sh
ports -u
prt-get sysup
```

Install a package and its dependencies with:

```sh
prt-get depinst <package>
```

BFSOS uses `python3` as the Python 3 package name; Python module ports use the `python3-*` naming convention.

### Package-management roles

- `pkgutils` provides low-level package tools including `pkgmk` and `pkgadd`.
- `ports` provides `ports -u` synchronization and repository drivers.
- `prt-get` is the dependency-aware frontend used for `depinst`, `sysup`, and related operations.
- `prt-utils` provides maintenance helpers such as `revdep`.

BFSOS-maintained collections use the Git-backed monorepo definition `/etc/ports/bfsos.git`. Maintainers can audit/update the source ports tree with `scripts/bfs-port-updater.py`, which dynamically discovers collections under `~/BFSOS/ports` and presents reviewable per-port update choices.

## Logs and bug reports

Bootstrap logs are written under the project's `logs/` hierarchy when enabled. Installer logs are copied into the installed system under `/var/log/bfs/installer/`.

When reporting a problem, include the failing stage/package, relevant log, storage topology where applicable, kernel/initramfs version, and whether the problem occurred in a VM or on bare metal.

## Current limitations

- Not every hardware/storage combination has been validated.
- Non-core ports can lag or need repair independently of the release-critical base.
- Reusable installer profiles intentionally do not persist passwords or LUKS passphrases.
- GRUB is the currently validated bootloader path; alternative bootloaders remain future work.

## License

See `LICENSE` and the licenses of the individual upstream packages/sources.
