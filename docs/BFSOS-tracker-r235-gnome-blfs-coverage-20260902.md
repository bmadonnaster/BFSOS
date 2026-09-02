# BFSOS r235 — Current BLFS GNOME chapter coverage reconciliation

Date: 2026-09-02

## Scope

This pass compares the BFSOS source tree with the current BLFS systemd GNOME
Libraries/Desktop and GNOME Applications chapters. It is a **coverage** pass:
missing current packages/applications are added and the GNOME meta packages are
corrected. It does not falsely mark the broader dependency-ordered GNOME 50
version migration complete; many older BFSOS GNOME recipes still require
individual version/API/build validation.

## Existing packages that were not actually missing

The first visual audit of `ports/gnome` alone made a few BLFS items appear
absent even though BFSOS already carries them in another canonical collection:

- `libsecret` -> `ports/opt/libsecret`
- `dconf-editor` -> `ports/opt/dconf-editor`

No duplicate GNOME-local copy was created.

## Missing current BLFS GNOME chapter packages added in r235

### GNOME library/data coverage

- `gweather-locations 2026.2` -> `ports/gnome/gweather-locations`
  - current split location/timezone database used by libgweather;
  - `libgweather` updated to `4.6.0` and now explicitly depends on it.

### GNOME Applications coverage

- `loupe 49.2` -> `ports/gnome/loupe`
  - current GNOME image viewer;
  - replaces EOG in the default current GNOME application bundle.
- `showtime 49.1` -> `ports/gnome/showtime`
  - current lightweight GNOME audio/video player.

## New support ports required by those applications

- `glycin 2.1.5` -> `ports/opt/glycin`
  - required at runtime by Loupe;
  - uses the current BLFS first-build bootstrap fix;
  - tests/docs disabled for the package build;
  - enables the image-rs, JPEG XL and SVG loaders already supported by the
    BFSOS dependency tree, while not forcing missing optional libheif.
- `blueprint-compiler 0.22.2` -> `ports/opt/blueprint-compiler`
  - required to build Showtime.

## GNOME application meta-package policy

`gnome-apps-meta` now hard-depends on the complete current BLFS GNOME
Applications chapter identity set:

- baobab
- brasero
- evince
- evolution
- file-roller
- gnome-calculator
- gnome-color-manager
- gnome-connections
- gnome-disk-utility
- gnome-logs
- gnome-maps
- gnome-nettool
- gnome-power-manager
- gnome-system-monitor
- gnome-terminal
- gnome-weather
- gucharmap
- loupe
- seahorse
- showtime
- snapshot

`eog` and `gnome-screenshot` remain available as standalone BFSOS ports for
compatibility/user choice, but are no longer hard dependencies of the current
default app bundle. EOG has been superseded by Loupe in current BLFS/GNOME
coverage, and current development BLFS no longer lists `gnome-screenshot` in
the GNOME Applications chapter.

## Complete GNOME meta package

`gnome-meta` now additionally makes the normal user-facing desktop support
explicit by including:

- `gnome-shell-extensions`
- `gnome-tweaks`
- `gnome-user-docs`
- `yelp`
- `dconf-editor`

alongside the existing GDM/session/shell/control-center/Nautilus/app bundle,
portal and PipeWire/WirePlumber desktop audio path.

## Static policy enforcement

The release audit now requires:

- all five newly added coverage/support ports;
- `libgweather -> gweather-locations`;
- every current BLFS GNOME Applications identity in `gnome-apps-meta`;
- Loupe/Showtime as current defaults and no EOG/gnome-screenshot hard default;
- expanded complete `gnome-meta` desktop support.

The ports-tree audit also reports current BLFS GNOME application identity
coverage. At r235 it reports zero missing GNOME application identities and zero
duplicate package identities.

## Required build/runtime regression order

Before closing this work, build in dependency order on BFSOS:

1. `blueprint-compiler`
2. `gweather-locations`
3. `libgweather`
4. `glycin`
5. `loupe`
6. `showtime`
7. `gnome-apps-meta`
8. `gnome-meta`

Then verify Loupe opens common image formats through Glycin, Showtime plays
local audio/video through GStreamer, Weather can resolve locations, Nautilus
uses Loupe as the preferred image viewer on a clean user profile, and a clean
`prt-get depinst gnome-meta` contains the complete intended app set.

## Still OPEN

This does **not** complete the GNOME 50 modernization. Existing 47-era GNOME
core/application ports still need dependency-ordered current-version updates,
patch/API reconciliation, package builds and a clean GDM/GNOME login regression.
