# BFSOS r234 — BLFS LXQt application/meta reconciliation — 2026-09-02

## Result

The current BLFS Chapter 38 LXQt Applications set contains exactly eight packages:

- lximage-qt 2.4.0
- lxqt-archiver 1.4.0
- lxqt-notificationd 2.4.0
- pavucontrol-qt 2.4.0
- qps 2.13.0
- qtermwidget 2.4.0
- qterminal 2.4.0
- screengrab 3.2.0

All eight ports were already present in the r233 source pass and were already listed in `lxqt-meta`.

The r234 reconciliation fixes the remaining gaps found by comparing the meta package and app recipes with current BLFS:

1. `lxqt-archiver` now explicitly depends on `liblxqt` (release 2).
2. `pavucontrol-qt` now explicitly depends on `liblxqt` (release 2).
3. `lxqt-meta` is release 3 and now includes `openbox` + `obconf-qt` so the default X11 LXQt installation has a real window manager and its Qt configuration utility.
4. `lxqt-meta` also includes BLFS-recommended `breeze-icons` and `desktop-file-utils`.
5. Static/release audits now require all eight BLFS Chapter 38 applications in the meta package and enforce the X11/recommended integration set.

## Wayland note

`lxqt-wayland-session` remains included. BLFS recommends a separate Wayland compositor such as Wayfire at runtime. BFSOS does not yet have a Wayfire port/closure, so r234 does not pretend that installing `lxqt-wayland-session` alone makes the Wayland path complete. Add/test a compositor deliberately in a later focused Wayland pass.

## Runtime regression still required

Run a clean `prt-get depinst lxqt-meta`, build/install the updated LXQt ports, log into LXQt under X11, verify Openbox + ObConf-Qt, icons/menu databases, notifications, audio, terminal, image viewer, archiver, process manager and screenshot utility. Test Wayland only after a supported compositor is packaged/configured.
