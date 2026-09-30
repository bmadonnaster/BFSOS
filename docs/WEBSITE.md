# BFSOS SourceForge website

The public BFSOS site source lives in `website/` and is intentionally static HTML/CSS. The design is lightweight and CRUX-inspired, but uses a BFSOS dark blue/purple identity and does not copy CRUX branding.

SourceForge Project Web serves the project at:

```text
https://bfsos.sourceforge.io/
```

GitHub remains authoritative for source code, ports, pull requests, and GitHub Issues. SourceForge hosts the public website and release artifacts.

## Pages

- `website/index.html` — Home;
- `website/documentation.html` — links to maintained GitHub documentation;
- `website/download.html` — separate ISO and base/rootfs download paths;
- `website/ports.html` — links to the authoritative GitHub ports tree;
- Bugs in the common navigation links directly to GitHub Issues;
- `website/links.html` — CRUX, Linux From Scratch, GitHub, and SourceForge.

## Publish to SourceForge

SourceForge Project Web accepts SSH-key authentication and `rsync`. With the project short name `bfsos`, the remote path is:

```text
bmadonnaster@web.sourceforge.net:/home/project-web/bfsos/htdocs/
```

The maintained helper performs a dry-run by default:

```bash
SF_USER=bmadonnaster ./scripts/bfs-publish-website-sourceforge.sh
```

Publish for real only after reviewing the dry-run:

```bash
SF_USER=bmadonnaster ./scripts/bfs-publish-website-sourceforge.sh --publish
```

The script uses `--delete`, so the remote site is synchronized to the maintained `website/` tree. Keep unrelated hand-created files out of the remote `htdocs` directory unless they are also represented in this source tree.

## Before publishing

Check desktop and narrow/mobile widths, keyboard navigation, contrast, every external link, and the active release download paths. Update release strings when `VERSION` changes.
