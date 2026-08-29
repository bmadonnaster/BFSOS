#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"
fail=0
say_fail(){ printf 'RELEASE-AUDIT: %s\n' "$*" >&2; fail=1; }

bash scripts/bfs-ports-static-audit.sh || fail=1
bash -n bootstrap.sh || say_fail "bootstrap.sh syntax"
bash -n scripts/install-bfs-menu-current.sh || say_fail "current installer syntax"

# Current installer must be the newest maintained implementation.
current_target="$(readlink scripts/install-bfs-menu-current.sh 2>/dev/null || true)"
case "$current_target" in
  *r71-lvm-equal-split.sh) ;;
  *) say_fail "current installer does not point at r71: $current_target" ;;
esac

# Base diagnostics and trust stack.
[ -f ports/core/traceroute/Pkgfile ] || say_fail "traceroute diagnostic port missing"
grep -q '^# Depends on: p11-kit' ports/core/make-ca/Pkgfile || say_fail "make-ca must depend on p11-kit"
! grep -Eq '^# Depends on:.*(^|[[:space:]])make-ca([[:space:]]|$)' ports/opt/p11-kit/Pkgfile || say_fail "p11-kit must not depend on make-ca"
[ -x ports/core/make-ca/post-install ] || [ -f ports/core/make-ca/post-install ] || say_fail "make-ca post-install missing"
grep -q 'update-pki.timer' ports/core/make-ca/post-install || say_fail "make-ca timer policy missing"

# Qt split and consumers.
grep -q -- '-skip qtwebengine' ports/opt/qt5/Pkgfile || say_fail "Qt5 WebEngine not split"
[ -f ports/opt/qtwebengine5/Pkgfile ] || say_fail "qtwebengine5 port missing"
[ -f ports/opt/qt6-webengine/Pkgfile ] || say_fail "qt6-webengine port missing"
grep -q 'rm -rf qtwebengine' ports/opt/qt6/Pkgfile || say_fail "Qt6 WebEngine not excluded from qt6"
grep -q 'qt6-webengine' ports/plasma/khelpcenter/Pkgfile || say_fail "known Qt6 WebEngine consumer khelpcenter missing dependency"

# Plasma desktop baseline.
deps="$(grep '^# Depends on:' ports/plasma/plasma-meta/Pkgfile)"
for dep in sddm pipewire wireplumber phonon-backend-vlc xdg-desktop-portal-kde; do
  grep -qw "$dep" <<<"$deps" || say_fail "plasma-meta missing $dep"
done
[ "$(grep -o 'phonon-backend-vlc' <<<"$deps" | wc -l)" -eq 1 ] || say_fail "phonon-backend-vlc dependency duplicated"
! grep -qw consolekit ports/plasma/kscreenlocker/Pkgfile || say_fail "kscreenlocker still depends on ConsoleKit"

# Xfce and Compiz must each provide a one-command complete desktop/stack meta package.
[ -f ports/xfce/xfce4-meta/Pkgfile ] || say_fail "xfce4-meta complete desktop package missing"
xfce_deps="$(grep '^# Depends on:' ports/xfce/xfce4-meta/Pkgfile 2>/dev/null || true)"
for dep in xfce4-session xfce4-settings xfce4-panel xfdesktop xfwm4 xfce4-appfinder thunar thunar-volman tumbler xfce4-power-manager xfce4-apps-meta; do
  grep -qw "$dep" <<<"$xfce_deps" || say_fail "xfce4-meta missing $dep"
done
[ -f ports/compiz/compiz-meta/Pkgfile ] || say_fail "compiz-meta package missing"
compiz_deps="$(grep '^# Depends on:' ports/compiz/compiz-meta/Pkgfile 2>/dev/null || true)"
for dep in compiz compiz-bcop libcompizconfig compizconfig-python ccsm compiz-plugins-main compiz-plugins-extra emerald emerald-themes; do
  grep -qw "$dep" <<<"$compiz_deps" || say_fail "compiz-meta missing $dep"
done

# Mainline/LTS MD policy must agree: core built in, personalities modular.
for f in ports/core/linux/Pkgfile ports/core/linux-lts/Pkgfile; do
  grep -q 'scripts/config --enable MD' "$f" || say_fail "$f does not enable MD core"
  for sym in MD_LINEAR MD_RAID0 MD_RAID1 MD_RAID10 MD_RAID456; do
    grep -q "scripts/config --module $sym" "$f" || say_fail "$f does not make $sym modular"
  done
done

# Mainline/LTS kernel package policy: Zstd kernel image and every installed
# loadable module must be compressed as .ko.zst. Keep both the recipe and the
# saved baseline config aligned so this cannot be silently skipped again.
for f in ports/core/linux/Pkgfile ports/core/linux-lts/Pkgfile; do
  grep -q 'scripts/config --enable KERNEL_ZSTD' "$f" || say_fail "$f does not enable KERNEL_ZSTD"
  grep -q 'scripts/config --disable KERNEL_GZIP' "$f" || say_fail "$f does not disable KERNEL_GZIP"
  grep -q 'scripts/config --enable MODULE_COMPRESS_ZSTD' "$f" || say_fail "$f does not select Zstd module compression"
  grep -q 'scripts/config --enable MODULE_COMPRESS_ALL' "$f" || say_fail "$f does not compress all modules during modules_install"
  grep -Fq -- "-name '*.ko.zst'" "$f" || say_fail "$f lacks post-install .ko.zst verification"
  grep -Eq '^# Depends on:.*(^|[[:space:]])zstd([[:space:]]|$)' "$f" || say_fail "$f does not depend on zstd"
done
for cfg in ports/core/linux/config ports/core/linux-lts/config; do
  grep -q '^CONFIG_KERNEL_ZSTD=y$' "$cfg" || say_fail "$cfg does not select KERNEL_ZSTD"
  grep -q '^# CONFIG_KERNEL_GZIP is not set$' "$cfg" || say_fail "$cfg still selects kernel Gzip"
  grep -q '^CONFIG_MODULE_COMPRESS=y$' "$cfg" || say_fail "$cfg does not enable module compression"
  grep -q '^CONFIG_MODULE_COMPRESS_ZSTD=y$' "$cfg" || say_fail "$cfg does not select Zstd module compression"
  grep -q '^CONFIG_MODULE_COMPRESS_ALL=y$' "$cfg" || say_fail "$cfg does not automatically compress all installed modules"
  grep -q '^# CONFIG_MODULE_COMPRESS_XZ is not set$' "$cfg" || say_fail "$cfg still selects XZ module compression"
done

grep -q 'state=y' scripts/install-bfs-menu-current.sh || say_fail "initramfs verifier does not recognize built-in support"
grep -q 'state=m' scripts/install-bfs-menu-current.sh || say_fail "initramfs verifier does not recognize modular support"

# Global package-build environment and source-cache identity.
for prefix in /opt/qt6 /opt/kf6 /opt/qt5; do
  grep -Fq "$prefix" ports/core/pkgutils/pkgmk.conf || say_fail "pkgmk build environment missing $prefix"
done
grep -Fq 'PKGMK_SOURCE_DIR="$PKGMK_SOURCE_ROOT/$name"' ports/core/pkgutils/pkgmk.conf || say_fail "source cache is not package-namespaced"

# Sysup must bring package tooling current first.
grep -q 'BFSOS sysup preflight' ports/core/prt-get/Pkgfile || say_fail "prt-get sysup pkgutils preflight missing"

# No duplicated hard dependency tokens anywhere in maintained Pkgfiles.
python3 - <<'PY' || fail=1
from pathlib import Path
from collections import Counter
bad=[]
for p in Path('ports').glob('*/*/Pkgfile'):
    for line in p.read_text(errors='replace').splitlines():
        if line.startswith('# Depends on:'):
            vals=line.split(':',1)[1].split(); dup=[x for x,c in Counter(vals).items() if c>1]
            if dup: bad.append((p,dup))
if bad:
    for p,d in bad: print(f'RELEASE-AUDIT: duplicate dependencies in {p}: {", ".join(d)}')
    raise SystemExit(1)
PY

if [ "$fail" -ne 0 ]; then
  echo 'BFSOS release static audit: FAILED' >&2
  exit 1
fi

echo 'BFSOS release static audit: PASSED'
