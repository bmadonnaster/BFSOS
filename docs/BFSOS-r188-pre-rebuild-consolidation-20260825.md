# BFSOS r188 pre-rebuild consolidation

Static implementation pass before the next destructive fresh-VM installer regression.

Implemented: current 7.1.10/6.18.46 kernel point releases; exact selected-kernel finalization and atomic kernel/source symlink policy; installer r66; low-RAM tmpfs auto-disable; X.Org/XCB baseline closure for Qt; bash-completion profile ownership migration; default `.pkg.tar.zst` package compression; and the r187 Plasma/PAM/PipeWire fixes.

Still requires runtime validation: kernel builds/boots and LTS patch application, Shadow/PAM authentication, pkgutils `.zst` install/update path, X.Org/Qt XCB feature detection, Plasma X11/Wayland login, PipeWire/WirePlumber/RTKit audio, and package ownership upgrades.

Known non-baseline Plasma graph gaps remaining: `libaccounts-qt`, `signond`, and `kio-extras`.
