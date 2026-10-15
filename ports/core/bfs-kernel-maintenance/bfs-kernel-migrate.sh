#!/bin/sh
set -eu
exec python3 /usr/libexec/bfs-kernel-migrate.py "$@"
