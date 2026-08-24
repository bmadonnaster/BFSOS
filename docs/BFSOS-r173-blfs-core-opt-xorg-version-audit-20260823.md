# BFSOS r173 BLFS core/opt/xorg version audit — 2026-08-23

Reference: current BLFS systemd development book r13.0-1327 (published 2026-08-22),
plus the BLFS Xorg Libraries / Xorg Applications / Xorg Input Drivers package lists.

## Version refresh applied

Beyond the r172 tracker-specific dependency/build fixes, this pass updated 39
directly mapped core/opt/xorg packages to the current BLFS development versions.
Examples include CrackLib 2.10.3, GnuPG 2.5.21, GPGME 2.1.2, Kerberos 1.22.2,
OpenSSH 10.5p1, LVM2 2.03.42, mdadm 4.6, smartmontools 7.5, libarchive 3.8.9,
libblockdev 3.5.0, libgcrypt 1.12.2, libgpg-error 1.61, libnvme 1.16.2,
libqalculate 5.12.0, libwacom 2.19.1, libjpeg-turbo 3.2.0, libtiff 4.7.2,
Highlight 4.21, Lua 5.4.8, NetworkManager 1.58.1, libevent 2.1.13,
libpcap 1.10.6, glslang 16.5.0, Vulkan Headers/Loader 1.4.357.0,
Gtkmm 3.24.11, and the current Pangomm API lines.

Mesa 26.2.1 and gdk-pixbuf 2.44.8 were intentionally retained because BFSOS is
already newer than the BLFS development versions shown by the reference.

## Xorg detailed refresh

The BLFS Xorg component lists exposed 56 additional stale Xorg package versions.
Updated the Xorg library/application/input stack, including xtrans 1.6.0,
libX11 1.8.13, libXext 1.3.7, libSM 1.2.6, libXpm 3.5.19, libXfont2 2.0.9,
libXi 1.8.3, libXrandr 1.5.5, libpciaccess 0.19, libxkbfile 1.2.0,
xauth 1.1.5, xkbutils 1.0.7, xsetroot 1.1.4, luit 20250912,
libevdev 1.13.6 and libinput 1.31.3.

## Source-path checks performed while bumping

- Corrected Kerberos's hard-coded 1.21 source directory to `${version%.*}`.
- Corrected Lua hard-coded 5.4.7 library/version residue to 5.4.8.
- Changed libtiff source to HTTPS.
- Highlight 4.21 now builds its GUI against Qt6 instead of Qt5, matching the
  modern BLFS generation; Qt6 is therefore the BFSOS hard dependency for the
  current always-GUI recipe.
- No old-version string residues remain in the Pkgfiles changed by this version
  pass.
- Network access is unavailable from the artifact container, so source
  reachability was cross-checked against current BLFS/upstream web references
  where available; clean-cache `pkgmk` downloads remain the runtime verification.

## Structural verification

- All 930 Pkgfiles in core/opt/xorg/plasma pass `bash -n`.
- Every hard dependency token in all 761 core/opt/xorg Pkgfiles resolves to an
  existing BFSOS port.
- No duplicate hard dependency tokens remain.

This is substantially broader than the previous audit, but packages not mapped
by current BLFS still require upstream-specific current-version/source checks.
