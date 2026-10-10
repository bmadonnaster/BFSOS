# BFSOS office and Brother printer integration (r436)

## LibreOffice

Added `ports/office/libreoffice` (source) and `ports/office/libreoffice-bin` (upstream RPM repackaging) at upstream 26.8.1. Both remain **unbuilt** on BFSOS. The source recipe's `autogen.sh` options, build prerequisites, and system dependency policy need validation. The binary recipe needs RPM payload/layout verification, desktop launcher correctness, and staged-file ownership audit. **Never install both variants together:** they can ship overlapping program files or desktop entries; pkgutils does not offer a reliable virtual-package conflict policy here. We intentionally do not mark mutual exclusion completed.

Ensure `/usr/ports/office` is synchronized and recognized by `prt-get`, updater and ISO builder. Review optional locale/dictionary packaging and desktop integrations.

## Brother HL-L8250CDN

Added two documented **fail-closed stubs** in `ports/contrib` at official vendor component versions LPR 1.1.2-1 and CUPSwrapper 1.1.3-1. Do not build/install them: verified direct vendor payload links, license review, extraction, correct CUPS filter location, PPD and 32-bit binary ABI are pending. Do not substitute a different printer's driver package.

### CUPS smoke test on actual hardware

```
sudo systemctl enable --now cups.service
lpinfo -v
lpstat -t
# Configure discovered IPP device using http://localhost:631 if driverless printing is supported
# Once configured:
printf 'BFSOS CUPS print smoke test\n' | lp -d YOUR_QUEUE
lpstat -o
journalctl -b -u cups --no-pager
```

Do not enable CUPS automatically for live ISO merely by adding this port. Prefer network IPP/driverless first, then test vendor LPR+CUPSwrapper separately.
