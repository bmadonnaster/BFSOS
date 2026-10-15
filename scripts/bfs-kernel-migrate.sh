#!/bin/sh
# BFSOS r484: transactional PREPARATION of legacy kernel package identities.
# Never removes a kernel, modules, or an initramfs. A reboot and new kernel
# installation are separate, explicitly operator-controlled steps.
set -eu
exec python3 "$(dirname "$0")/bfs-kernel-migrate.py" "$@"
