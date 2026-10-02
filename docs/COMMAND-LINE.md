# BFSOS maintained command-line entry points

The interactive menus remain the default user interface, but Bootstrap and the ISO builder also provide direct command-line entry points for repeatable maintainer workflows.

## Bootstrap

```text
./bootstrap.sh                     interactive menu
./bootstrap.sh 1                   build temporary toolchain
./bootstrap.sh 2                   build base with temporary toolchain
./bootstrap.sh 3                   rebuild base with final toolchain
./bootstrap.sh 4                   verify base
./bootstrap.sh 5                   create/compress base archive
./bootstrap.sh 6                   restore newest base archive
./bootstrap.sh 7                   restore newest toolchain archive
./bootstrap.sh 8                   chroot into BFSOS root
./bootstrap.sh 9                   launch installer
./bootstrap.sh full                run complete automated build through Stage 5
./bootstrap.sh full --force        explicit clean Stage 1-5 rebuild; retain source cache
./bootstrap.sh full --force --iso  clean base rebuild, then build ISO from the new base
./bootstrap.sh full --force --refresh-sources
                                   clean rebuild and also discard downloaded source cache
./bootstrap.sh resume-full         resume at first incomplete stage
./bootstrap.sh iso [ISO options]   launch ISO builder
./bootstrap.sh --help              full maintained usage
```

Invalid arguments fail instead of silently opening the menu.

## ISO builder

```text
scripts/bfs-build-iso.sh
scripts/bfs-build-iso.sh --local-base /path/to/BFSOS-base-0.9.0-x86_64.tar.zst
scripts/bfs-build-iso.sh --sourceforge-base
scripts/bfs-build-iso.sh --refresh-base
scripts/bfs-build-iso.sh --git-ref main
```

By default the builder prefers a verified current-release base from the maintained local archive area. Explicit SourceForge mode is useful for release-mirror validation. `--refresh-base` forces a new remote download.

## Installer

```text
scripts/install-bfs-menu-current.sh
scripts/install-bfs-menu-current.sh --console-font 20
scripts/install-bfs-menu-current.sh --no-log
scripts/install-bfs-menu-current.sh --log-file /path/to/log
```

The installer currently remains menu-driven for destructive/storage decisions. Reusable non-secret configuration profiles can be saved/loaded from Installer Settings. A future fully non-interactive installation mode must require explicit storage/account policy rather than guessing destructive defaults.

## Host requirements check

Before a bootstrap on a new host, run:

```text
scripts/version-check.sh
```

The checker is synchronized with the LFS 13.1-systemd host requirements and adds BFSOS-specific bootstrap dependencies such as libarchive/bsdtar, GMP, MPFR, libtirpc, curl, Git, rsync, zstd, sudo, pkg-config, and autoreconf. ISO-only tools are reported separately.

## Port maintenance

Create a starter port from a normal upstream source URL with:

```text
cd ports/<collection>
../../scripts/gentemplate.sh https://example.org/foo-1.2.3.tar.xz
```

Run `scripts/gentemplate.sh --help` for syntax. The generated Pkgfile is only a starting point; see `docs/PORTS.md` for build options, footprints, signatures, and maintainer workflow.

The primary maintainer updater is:

```text
scripts/bfs-port-updater.py
```

It discovers the actual trees under `~/BFSOS/ports`, provides Dialog checklists for tree and per-port selection, follows the BFSOS LFS/MLFS policy, and can hand selected updates to the transactional updater. Report-only examples:

```text
scripts/bfs-port-updater.py --list-trees
scripts/bfs-port-updater.py --report-only --trees core opt
scripts/bfs-port-updater.py --kernel-only --report-only
```

Lower-level audit helpers remain available:

```text
scripts/checkupdate.sh
scripts/bfs-maintained-port-version-audit.sh
scripts/multilibvercheck.sh
scripts/bfs-ports-static-audit.sh
scripts/bfs-source-tests.sh
scripts/bfs-runtime-check.sh
```
