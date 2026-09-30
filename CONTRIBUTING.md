# Contributing to BFSOS

BFSOS development happens in the GitHub repository:

<https://github.com/bmadonnaster/BFSOS>

Use GitHub Issues for bug reports and feature requests. SourceForge hosts public release artifacts and the project website; it is not the primary source/issue tracker.

## Before opening an issue

Please include enough information to reproduce the problem:

- BFSOS release and Git commit when known;
- affected package/stage/script;
- relevant build or installer log;
- kernel/initramfs version for boot/runtime problems;
- VM or bare-metal environment;
- storage topology for installer/RAID/LUKS/LVM/filesystem issues;
- exact command and error output.

Do not include passwords, API keys, private signing keys, or other credentials.

## Port contributions

Read [`docs/PORTS.md`](docs/PORTS.md) before adding or changing a package. BFSOS prefers generic pkgutils build handling plus `build_opt` over unnecessary custom `pkg_build()` functions.

A new port can be started with:

```bash
cd ports/<collection>
../../scripts/gentemplate.sh https://example.org/foo-1.2.3.tar.xz
```

The generated Pkgfile must be reviewed; it is not a complete package recipe by itself.

## Validation

Run the tests relevant to your change. Useful broad checks include:

```bash
scripts/bfs-ports-static-audit.sh
scripts/bfs-release-static-audit.sh
scripts/bfs-source-tests.sh
```

For shell changes, run `bash -n`. For Python changes, run `python3 -m py_compile` or the matching test suite.

Changes that affect Bootstrap, the ISO builder, installer, kernels, storage, package installation hooks, or hardware-dependent behavior also need the corresponding BFSOS runtime test; source/static success is not a substitute for runtime acceptance.

## Repository hygiene

Keep generated source/package caches, logs, private keys, credentials, and scratch files out of commits. Reviewed package integrity metadata such as `.footprint`/`.signature` is not deleted automatically by BFSOS Git helpers; review it deliberately before staging.
