#!/usr/bin/env python3
"""Mechanical health check for the PLDAPS_vK2 wiki.

Usage:  python3 wiki/_tools/wiki_lint.py [--json]

Reports (always exits 0; it is a report, not a gate):
  broken_links     relative links that point at nothing
  orphans          pages nothing links to (index/log/SCHEMA exempt)
  not_in_index     pages index.md does not link to
  bad_frontmatter  pages missing title/type/sources/verified_at/updated
  missing_sources  `sources:` entries that do not exist in the repo
  stale            pages whose source content changed since `wiki_gen.py stamp`
  uncovered_tasks  task directories with no page citing them
  uncovered_pds    +pds / +pdsActions files no page mentions by name
  conflict_copies  OneDrive conflict copies inside wiki/ (merge, then delete)
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import wiki_lib as wl  # noqa: E402

REQUIRED = ("title", "type", "sources", "verified_at", "updated")
EXEMPT_ORPHAN = {"index.md", "log.md", "SCHEMA.md"}
EXEMPT_INDEX = {"index.md", "log.md"}


def lint():
    pages = wl.load_pages()
    report = {k: [] for k in ("broken_links", "orphans", "not_in_index",
                              "bad_frontmatter", "missing_sources", "stale",
                              "uncovered_tasks", "uncovered_pds", "conflict_copies")}
    inbound = {rel: 0 for rel in pages}
    index_targets = set()

    for rel, pg in pages.items():
        base = os.path.dirname(pg["abs"])
        for target in wl.links_in(pg["text"]):
            dest = os.path.normpath(os.path.join(base, target))
            if not os.path.exists(dest):
                report["broken_links"].append(f"{rel} -> {target}")
                continue
            if dest.startswith(wl.WIKI_DIR + os.sep) and dest.endswith(".md"):
                drel = os.path.relpath(dest, wl.WIKI_DIR).replace(os.sep, "/")
                if drel in inbound and drel != rel:
                    inbound[drel] += 1
                    if rel == "index.md":
                        index_targets.add(drel)

        meta = pg["meta"]
        if meta is None or any(k not in meta for k in REQUIRED):
            missing = REQUIRED if meta is None else [k for k in REQUIRED if k not in meta]
            report["bad_frontmatter"].append(f"{rel}: missing {', '.join(missing)}")
        for src in wl.page_sources(pg):
            if not os.path.exists(os.path.join(wl.REPO_DIR, src.rstrip("/"))):
                report["missing_sources"].append(f"{rel}: {src}")

    for rel, n in inbound.items():
        if n == 0 and rel not in EXEMPT_ORPHAN:
            report["orphans"].append(rel)
        if rel not in index_targets and rel not in EXEMPT_INDEX:
            report["not_in_index"].append(rel)

    # Staleness: content hash of a source differs from the one stamped on the page.
    for rel, paths in sorted(wl.stale_pages(pages).items()):
        more = f" (+{len(paths) - 5} more)" if len(paths) > 5 else ""
        report["stale"].append(f"{rel}: {', '.join(paths[:5])}{more}")

    # OneDrive conflict copies inside the wiki.
    for root, _, files in os.walk(wl.WIKI_DIR):
        for f in files:
            if wl.is_conflict_copy(f):
                report["conflict_copies"].append(os.path.relpath(os.path.join(root, f), wl.WIKI_DIR))

    # Coverage.
    all_sources = [s for pg in pages.values() for s in wl.page_sources(pg)]
    tasks_dir = os.path.join(wl.REPO_DIR, "tasks")
    for name in sorted(os.listdir(tasks_dir)):
        if os.path.isdir(os.path.join(tasks_dir, name)):
            prefix = f"tasks/{name}/"
            if not any(s.startswith(prefix) or s == prefix.rstrip("/") for s in all_sources):
                report["uncovered_tasks"].append(prefix)
    corpus = "\n".join(pg["text"] for pg in pages.values())
    for pkg in ("+pds", "+pdsActions"):
        for f in sorted(os.listdir(os.path.join(wl.REPO_DIR, pkg))):
            if f.endswith(".m") and "-Murawski-Desktop" not in f:
                if f[:-2] not in corpus:
                    report["uncovered_pds"].append(f"{pkg}/{f}")
    return report


def main():
    report = lint()
    if "--json" in sys.argv:
        print(json.dumps(report, indent=1))
        return
    total = 0
    for key, items in report.items():
        print(f"{key}: {len(items)}")
        for item in items:
            print(f"  - {item}")
        total += len(items)
    print(f"\n{total} issue(s).")


if __name__ == "__main__":
    main()
