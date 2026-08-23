# BFSOS opt/xorg service integration static audit — r148

Static inventory only. Runtime systemd/service validation remains required before 1.0.

| Port | Shipped service/config files | Pkgfile integration indicators |
|---|---|---|
| `opt/accountsservice` | — | `systemd` |
| `opt/alsa-lib` | — | `systemd` |
| `opt/colord` | — | `systemd` |
| `opt/cups` | `cups.path`, `cups.service`, `cups.socket` | `systemd`, `.service`, `.socket`, `.path` |
| `opt/gpm` | — | `systemd`, `.service` |
| `opt/gst-plugins-bad` | — | `systemd` |
| `opt/gst-plugins-base` | — | `systemd` |
| `opt/gst-plugins-good` | — | `systemd` |
| `opt/gst-plugins-ugly` | — | `systemd` |
| `opt/ndctl` | — | `systemd` |
| `opt/networkmanager` | — | `systemd` |
| `opt/nvidia` | `10-nvidia-drm-outputclass.conf` | — |
| `opt/p11-kit` | — | `systemd` |
| `opt/snapper` | — | `systemd` |
| `opt/udisks` | — | `systemd` |
| `opt/wireplumber` | — | `systemd` |
| `xorg/libinput` | — | `systemd` |
| `xorg/nvidia` | `10-nvidia-drm-outputclass.conf` | — |
| `xorg/xorg-server` | — | `systemd` |
