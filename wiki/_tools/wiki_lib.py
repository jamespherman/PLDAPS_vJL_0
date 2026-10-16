"""Shared helpers for the PLDAPS_vK2 wiki tools and hooks (stdlib only)."""
import hashlib
import os
import re
import subprocess

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
WIKI_DIR = os.path.dirname(TOOLS_DIR)
REPO_DIR = os.path.dirname(WIKI_DIR)

LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")


def git(*args, cwd=REPO_DIR):
    """Run git and return stdout ('' on failure)."""
    try:
        out = subprocess.run(["git", *args], cwd=cwd, capture_output=True,
                             text=True, timeout=20)
        return out.stdout if out.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""


def parse_frontmatter(text):
    """Minimal YAML subset: `key: value` scalars and `key:` followed by `- item` lists."""
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end < 0:
        return None
    meta, key = {}, None
    for line in text[3:end].splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = re.match(r"^\s*-\s+(.*)$", line)
        if m and key is not None:
            if not isinstance(meta.get(key), list):
                meta[key] = []
            meta[key].append(m.group(1).split(" #")[0].strip().strip("'\""))
            continue
        m = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", line)
        if m:
            key, val = m.group(1), m.group(2).split(" #")[0].strip()
            if val.startswith("[") and val.endswith("]"):
                meta[key] = [v.strip().strip("'\"") for v in val[1:-1].split(",") if v.strip()]
            else:
                meta[key] = val.strip("'\"") if val else []
    return meta


def wiki_pages():
    """Yield (relpath_from_wiki, abspath) for every wiki page, skipping _tools."""
    for root, dirs, files in os.walk(WIKI_DIR):
        dirs[:] = [d for d in dirs if not d.startswith((".", "_"))]
        for f in sorted(files):
            if f.endswith(".md"):
                p = os.path.join(root, f)
                yield os.path.relpath(p, WIKI_DIR).replace(os.sep, "/"), p


def load_pages():
    """Return {relpath: {'meta': dict|None, 'text': str, 'abs': path}}."""
    pages = {}
    for rel, p in wiki_pages():
        with open(p, encoding="utf-8", errors="replace") as fh:
            text = fh.read()
        pages[rel] = {"meta": parse_frontmatter(text), "text": text, "abs": p}
    return pages


# OneDrive conflict copies look like `name-Murawski-Desktop.m` or `name-HOST-2.md`.
CONFLICT_RE = re.compile(r"-[A-Z][A-Za-z0-9]*-(Desktop|Laptop|PC|MacBook[A-Za-z0-9-]*|Mac[A-Z][A-Za-z0-9-]*|iMac[A-Za-z0-9-]*|Workstation)(-\d+)?$")
HASH_EXTS = (".m", ".md")


def is_conflict_copy(path):
    base = os.path.basename(path)
    stem = base if "." not in base else base[:base.rfind(".")]
    return bool(CONFLICT_RE.search(stem))


def blob_hash(abspath):
    """git-compatible blob sha1 of a file (works on uncommitted files)."""
    with open(abspath, "rb") as fh:
        data = fh.read()
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def source_hash(source):
    """10-char content hash of a repo file, or of a directory's .m/.md files; None if missing."""
    path = os.path.join(REPO_DIR, source.rstrip("/"))
    if os.path.isfile(path):
        return blob_hash(path)[:10]
    if os.path.isdir(path):
        h = hashlib.sha1()
        for root, dirs, files in os.walk(path):
            dirs.sort()
            for f in sorted(files):
                if f.endswith(HASH_EXTS) and not is_conflict_copy(f):
                    fp = os.path.join(root, f)
                    h.update(os.path.relpath(fp, path).replace(os.sep, "/").encode())
                    h.update(blob_hash(fp).encode())
        return h.hexdigest()[:10]
    return None


def split_source(entry):
    """'path @ hash' -> (path, hash or None)."""
    if " @ " in entry:
        path, h = entry.rsplit(" @ ", 1)
        return path.strip(), h.strip() or None
    return entry.strip(), None


def page_source_entries(page):
    meta = page.get("meta") or {}
    src = meta.get("sources") or []
    src = [src] if isinstance(src, str) else list(src)
    return [split_source(s) for s in src]


def page_sources(page):
    return [p for p, _ in page_source_entries(page)]


def stale_pages(pages=None):
    """{page: [changed or unstamped source paths]} for pages whose recorded hashes differ."""
    pages = pages if pages is not None else load_pages()
    out = {}
    for rel, pg in pages.items():
        bad = []
        for path, recorded in page_source_entries(pg):
            if recorded is None or source_hash(path) != recorded:
                bad.append(path)
        if bad:
            out[rel] = bad
    return out


def source_matches(source, path):
    """True if repo-relative `path` is covered by `source` (file, or dir ending in /)."""
    source = source.strip().lstrip("./")
    if source.endswith("/"):
        return path.startswith(source)
    return path == source


def pages_for_paths(paths, pages=None):
    """Map each repo path to the list of wiki pages whose sources cover it."""
    pages = pages if pages is not None else load_pages()
    out = {}
    for path in paths:
        out[path] = sorted(rel for rel, pg in pages.items()
                           if any(source_matches(s, path) for s in page_sources(pg)))
    return out


def links_in(text):
    """Relative link targets in a page (external/anchor-only links dropped)."""
    text = re.sub(r"```.*?```", "", text, flags=re.S)  # ignore fenced code
    text = re.sub(r"`[^`\n]*`", "", text)               # and inline code
    out = []
    for target in LINK_RE.findall(text):
        if re.match(r"^[a-z]+:", target) or target.startswith("#"):
            continue
        out.append(target.split("#")[0])
    return [t for t in out if t]
