#!/usr/bin/env python3
"""Fill only missing BFSOS Pkgfile descriptions from verified metadata sources.

This is intentionally separate from normal version scans. Existing Description
lines are never rewritten. Unresolved/ambiguous ports remain unchanged.
"""
from __future__ import annotations

import argparse, concurrent.futures, html, json, os, re, shutil, subprocess, sys, tempfile
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import quote, urljoin, urlsplit
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PORTS = ROOT / "ports"
BOOKS = [
    ("MLFS DEV", "https://www.linuxfromscratch.org/mlfs/view/dev/longindex.html"),
    ("LFS", "https://www.linuxfromscratch.org/lfs/view/systemd/longindex.html"),
    ("BLFS", "https://www.linuxfromscratch.org/blfs/view/systemd/longindex.html"),
    ("GLFS", "https://www.linuxfromscratch.org/glfs/view/dev/longindex.html"),
]

@dataclass
class Candidate:
    rel: str
    description: str
    provider: str
    reason: str = ""


def fetch(url: str, timeout: int) -> str:
    req=Request(url, headers={"User-Agent":"BFSOS-description-maintainer/1"})
    with urlopen(req, timeout=timeout) as r:
        return r.read(1_000_000).decode("utf-8", "replace")


def normalize_name(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def clean_desc(value: str) -> str:
    value=html.unescape(re.sub(r"<[^>]+>", " ", value or ""))
    value=re.sub(r"\[[^\]]+\]\([^\)]+\)", " ", value)
    value=re.sub(r"https?://\S+", " ", value)
    value=" ".join(value.split()).strip(" -–—:;")
    if not value or len(value) < 8:
        return ""
    low=value.lower()
    if low in {"package", "description", "no description", "none", "n/a"}:
        return ""
    if len(value) > 160:
        cut=value[:157].rsplit(" ",1)[0].rstrip(" ,;:-")
        value=cut + "…"
    return value


def parse_pkg(path: Path):
    text=path.read_text(errors="replace")
    if re.search(r"(?m)^# Description:\s*\S", text):
        return None
    name_m=re.search(r"(?m)^name=(?:['\"])?([^\s'\"]+)", text)
    name=name_m.group(1) if name_m else path.parent.name
    url_m=re.search(r"(?m)^# URL:\s*(\S+)", text)
    homepage=url_m.group(1) if url_m else ""
    urls=re.findall(r"(?:https?|ftp)://[^\s)'\"]+", text)
    return text,name,homepage,urls


def identity(url: str):
    try: u=urlsplit(url)
    except Exception: return ("","")
    host=(u.hostname or "").lower().removeprefix("www.")
    parts=[p for p in u.path.strip("/").split("/") if p]
    if host=="github.com" and len(parts)>=2:
        return host, "/".join(parts[:2]).removesuffix(".git").lower()
    if "gitlab" in host and len(parts)>=2:
        return host, "/".join(parts[:2]).removesuffix(".git").lower()
    return host, ""


def same_identity(a: str, b: str) -> bool:
    ia,ib=identity(a),identity(b)
    if not ia[0] or not ib[0]: return False
    if ia[0] != ib[0]: return False
    if ia[1] and ib[1]: return ia[1] == ib[1]
    return True


def lfs_description(name: str, timeout: int) -> tuple[str,str]:
    wanted=normalize_name(name.removesuffix("-32"))
    for label,index in BOOKS:
        try: raw=fetch(index,timeout)
        except Exception: continue
        links=re.findall(r'<a\s+[^>]*href=["\']([^"\']+)["\'][^>]*>(.*?)</a>',raw,re.I|re.S)
        target=""
        for href,label_html in links:
            label_text=clean_desc(label_html)
            if normalize_name(label_text) == wanted:
                target=urljoin(index,href); break
        if not target: continue
        try: page=fetch(target,timeout)
        except Exception: continue
        paragraphs=re.findall(r"<p(?:\s[^>]*)?>(.*?)</p>",page,re.I|re.S)
        for para in paragraphs:
            desc=clean_desc(para)
            low=desc.lower()
            if desc and (name.lower().split("-")[0] in low or "package contains" in low or "package provides" in low):
                return desc,label
    return "",""


def crux_description(name: str, timeout: int) -> tuple[str,str]:
    if not shutil.which("rsync"): return "",""
    base=name.removesuffix("-32")
    with tempfile.TemporaryDirectory(prefix="bfs-desc-crux-") as td:
        out=Path(td)/"Pkgfile"
        for collection in ("core","opt","xorg","compat-32","contrib"):
            try:
                cp=subprocess.run(["rsync","--contimeout","2","--timeout","2","-q",
                    f"rsync://crux.nu/ports/crux-3.8/{collection}/{base}/Pkgfile",str(out)],
                    stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=min(timeout,3))
            except Exception: continue
            if cp.returncode==0 and out.is_file():
                m=re.search(r"(?m)^# Description:\s*(.+)$",out.read_text(errors="replace"))
                if m:
                    d=clean_desc(m.group(1))
                    if d: return d,"CRUX"
    return "",""


def arch_description(name: str, homepage: str, sources: list[str], timeout: int) -> tuple[str,str]:
    base=name.removesuffix("-32")
    try: raw=fetch("https://archlinux.org/packages/search/json/?name="+quote(base),timeout); data=json.loads(raw)
    except Exception: return "",""
    refs=[u for u in [homepage,*sources] if u.startswith(("http://","https://"))]
    for row in data.get("results",[]):
        if row.get("pkgname") != base: continue
        upstream=str(row.get("url") or "")
        if refs and not any(same_identity(upstream,r) for r in refs):
            continue
        d=clean_desc(str(row.get("pkgdesc") or ""))
        if d: return d,"Arch"
    return "",""


def upstream_description(homepage: str, sources: list[str], timeout: int) -> tuple[str,str]:
    candidates=[homepage]+sources
    seen=set()
    for url in candidates:
        if not url.startswith(("http://","https://")): continue
        ident=identity(url)
        if ident in seen: continue
        seen.add(ident)
        if ident[0]=="github.com" and ident[1]:
            try:
                raw=fetch("https://api.github.com/repos/"+ident[1],timeout); data=json.loads(raw)
                d=clean_desc(str(data.get("description") or ""))
                if d: return d,"upstream GitHub"
            except Exception: pass
        page=homepage if homepage.startswith(("http://","https://")) and same_identity(homepage,url) else url
        try: raw=fetch(page,timeout)
        except Exception: continue
        for pat in (r'<meta[^>]+name=["\']description["\'][^>]+content=["\']([^"\']+)',
                    r'<meta[^>]+property=["\']og:description["\'][^>]+content=["\']([^"\']+)'):
            m=re.search(pat,raw,re.I)
            if m:
                d=clean_desc(m.group(1))
                if d: return d,"upstream site"
    return "",""


def resolve_one(pkgfile: Path, ports_root: Path, timeout: int) -> Candidate | None:
    parsed=parse_pkg(pkgfile)
    if parsed is None: return None
    _text,name,homepage,sources=parsed
    rel=str(pkgfile.parent.relative_to(ports_root))
    # Root/template Pkgfile is not traversed because glob is tree/port/Pkgfile.
    for fn in (lfs_description,):
        d,p=fn(name,timeout)
        if d: return Candidate(rel,d,p)
    d,p=crux_description(name,timeout)
    if d: return Candidate(rel,d,p)
    d,p=arch_description(name,homepage,sources,timeout)
    if d: return Candidate(rel,d,p)
    d,p=upstream_description(homepage,sources,timeout)
    if d: return Candidate(rel,d,p)
    return Candidate(rel,"","NEEDS REVIEW","no verified description source")


def apply_candidate(ports_root: Path, c: Candidate):
    p=ports_root/c.rel/"Pkgfile"
    text=p.read_text()
    if re.search(r"(?m)^# Description:",text): return False
    line=f"# Description: {c.description}\n"
    p.write_text(line+text)
    return True


def dialog_review(cands: list[Candidate]) -> set[str] | None:
    if not shutil.which("dialog") or not sys.stdin.isatty():
        return None
    items=[]
    for c in cands:
        items += [c.rel, f"{c.description} [{c.provider}]", "off"]
    cp=subprocess.run(["dialog","--stdout","--title","Fill missing port descriptions","--separate-output","--checklist",
        "Only missing descriptions are shown. Space toggles; Enter applies selected entries.","30","130","22",*items],text=True,stdout=subprocess.PIPE)
    if cp.returncode != 0: return set()
    return {x.strip('"') for x in cp.stdout.splitlines() if x.strip()}


def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--ports-root",type=Path,default=DEFAULT_PORTS)
    ap.add_argument("--timeout",type=int,default=8)
    ap.add_argument("--jobs",type=int,default=int(os.environ.get("BFS_AUDIT_JOBS", str(len(os.sched_getaffinity(0)) if hasattr(os, "sched_getaffinity") else (os.cpu_count() or 1)))))
    ap.add_argument("--apply-all",action="store_true",help="apply every resolved description without dialog")
    ap.add_argument("--tsv",type=Path)
    ns=ap.parse_args()
    ports=ns.ports_root.resolve()
    pkgfiles=sorted(ports.glob("*/*/Pkgfile"))
    missing=[p for p in pkgfiles if parse_pkg(p) is not None]
    print(f"Missing descriptions: {len(missing)}",file=sys.stderr)
    rows=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1,ns.jobs)) as ex:
        futs={ex.submit(resolve_one,p,ports,ns.timeout):p for p in missing}
        for fut in concurrent.futures.as_completed(futs):
            try: c=fut.result()
            except Exception as exc:
                rel=str(futs[fut].parent.relative_to(ports)); c=Candidate(rel,"","NEEDS REVIEW",str(exc))
            if c: rows.append(c)
    rows.sort(key=lambda c:c.rel)
    resolved=[c for c in rows if c.description]
    selected={c.rel for c in resolved} if ns.apply_all else dialog_review(resolved)
    if selected is None:
        selected=set()
    changed=[]
    for c in resolved:
        if c.rel in selected and apply_candidate(ports,c): changed.append(c.rel)
    out=ns.tsv or ROOT/"logs"/"update"/"missing-descriptions.tsv"
    out.parent.mkdir(parents=True,exist_ok=True)
    with out.open("w",encoding="utf-8") as f:
        f.write("port\tstatus\tprovider\tdescription\treason\n")
        for c in rows:
            status="UPDATED" if c.rel in changed else ("RESOLVED" if c.description else "NEEDS-REVIEW")
            vals=[c.rel,status,c.provider,c.description,c.reason]
            f.write("\t".join(v.replace("\t"," ").replace("\n"," ") for v in vals)+"\n")
    print(f"Resolved: {len(resolved)}  Updated: {len(changed)}  Needs review: {len(rows)-len(resolved)}")
    print(f"Report: {out}")
    return 0

if __name__=="__main__": raise SystemExit(main())
