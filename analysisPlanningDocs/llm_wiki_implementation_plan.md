# LLM Wiki for PLDAPS_vK2 — Implementation Plan

Status: v2 (revised after independent review) — IMPLEMENTED 2026-10-15 (see §13)

## 1. Goal

Instantiate the "LLM Wiki" pattern (persistent, LLM-maintained, interlinked markdown
knowledge base) for this repository, so that knowledge about the framework, its tasks,
its shared library, and its history is compiled once and kept current rather than
re-derived from code on every question. Claude Code hooks keep the wiki current.

## 2. Mapping the pattern onto this repo

| llm-wiki layer | PLDAPS_vK2 instantiation |
|---|---|
| Raw sources (LLM reads, never edits) | Code (`tasks/`, `+pds/`, `+pdsActions/`, `+rigConfigFiles/`, `PLDAPS_vK2_GUI.m`), existing docs (`data_dictionaries/`, `analysisPlanningDocs/`, task-folder `.md`, `README.md`, `IMPROVEMENT_PLAN.md`), git history, and **what the user tells Claude** (session practice, rationale). |
| The wiki (LLM-owned) | `wiki/` |
| The schema | `wiki/SCHEMA.md` + a short "Project Wiki" section in `CLAUDE.md`. |

The sources change constantly and most edits happen **outside Claude** (MATLAB editor,
two machines, ≥2 people). So the wiki needs (a) content-hash staleness detection that
catches any edit, surfaced at session start, and (b) a Stop hook that captures the
session's own changes *with their rationale* while Claude still has context.

## 3. Ownership: CLAUDE.md vs wiki

CLAUDE.md (loaded every session) keeps its short must-follow rules unchanged. The wiki
holds depth and links to CLAUDE.md for the rules instead of restating them. One owner per
topic avoids drift.

## 4. Layout

```
wiki/
  SCHEMA.md            conventions + workflows
  index.md             GENERATED from page frontmatter (never hand-edited)
  log.md               append-only, one line per entry: `- [YYYY-MM-DD] op | title — note`
  overview.md          "start here" synthesis
  gotchas.md           non-obvious traps (neutral tone)
  timeline.md          development arcs from git log
  docs-catalog.md      existing repo .md docs, one line each
  concepts/            cross-cutting mechanisms
  tasks/               family pages + per-task pages (status: active/legacy/WiP)
  library/             +pds by area, +pdsActions, rig configs, GUI
  reference/
    strobe-codes.md    GENERATED registry: every initCodes entry, which tasks strobe it,
                       value expressions, duplicate-value check
  analyses/            filed-back query answers
  _tools/              wiki_lib.py, wiki_lint.py, wiki_gen.py
```

Task pages: family pages (joystick family, gSac family, SRS family, rfMap/barsweep, scd/nfl)
carry the shared design + "differs from parent" tables; each task directory still gets its
own page (shorter for legacy). Each task page has:
- a GENERATED facts block (between `<!-- GEN:facts -->` markers): files, settings variants,
  `p.state` names/IDs, strobeList (code name → value expression), status/last-touched;
- narrative (purpose, trial flow, conditions, lineage, related docs);
- **Session practice & decisions** (facts not recoverable from code, e.g. gSac_4factors
  base location placed on RF; `passJoy = 1` always);
- **Data/strobe change history** (date, commit, what changed in saved data or strobes) for
  active tasks — so analysts can tell which code version produced which session.

## 5. Page conventions

```yaml
---
title: gSac_4factors
type: task                 # task | family | concept | library | reference | catalog | analysis | meta
category: Tasks — gSac family   # index grouping
summary: One line for index.md
status: active             # tasks only: active | legacy | wip
sources:                   # explicit files preferred; dirs (trailing /) allowed
  - tasks/gSac_4factors/gSac_4factors_run.m @ 1a2b3c4d5e
verified_at: e48934be      # informational only
updated: 2026-10-15
---
```

- `@ hash` is a 10-char git-blob sha1 of the file content (for dirs: hash over the
  directory's `.m`/`.md` files), written by `wiki_gen.py stamp`. Works on uncommitted files;
  independent of git refs (which are OneDrive-synced and conflict-prone here).
- Relative markdown links; repo paths + function names, not line numbers.
- Neutral tone; no "judgy" framing of deliberate design choices. Possible bugs found during
  writing go to the user in the session report, not onto pages.
- Claims must be grounded in a cited file; anything unconfirmable is deleted, not tagged.

## 6. Tooling (`wiki/_tools/`, stdlib Python)

- `wiki_lib.py` — frontmatter parsing, link resolution, path→page mapping, content hashing,
  conflict-copy detection (`-<host>(-\d+)?.<ext>`).
- `wiki_gen.py`
  - `index` — regenerate `index.md` from frontmatter.
  - `facts` — regenerate GEN blocks on task pages (MATLAB parsed with regex).
  - `strobes` — regenerate `reference/strobe-codes.md`.
  - `stamp [pages…]` — rewrite source hashes (after a page is verified/updated).
  - `stale [--brief]` — list pages whose source hashes differ.
  - `all` — index + facts + strobes.
- `wiki_lint.py` — broken links, orphans, frontmatter, missing sources, stale pages,
  uncovered task dirs / +pds files, conflict copies inside `wiki/`.

## 7. Hooks (`.claude/settings.json`, `.claude/hooks/`)

`.claude/` is gitignored (local config, but OneDrive-synced to a Windows machine). Every hook
command is quoted, guarded (`command -v python3 … || true`), and scripts exit 0 silently on any
error. Git output parsed with `-z`.

1. **PostToolUse `Edit|Write|MultiEdit|NotebookEdit`** → append `file_path` to
   `.claude/wiki-state/<session>.touched` (records exactly what this session edited).
2. **PreToolUse / PostToolUse `Bash`** → snapshot hashes of dirty+untracked files before;
   after, credit only paths whose hash changed to the session. Catches sed/script edits
   without attributing other machines' or sessions' work.
3. **Stop** (`wiki_stop.py`):
   - exit 0 if `stop_hook_active`;
   - read the touched log; keep **block-worthy** paths: top-level task files and
     `supportFunctions/` in `tasks/*/`, `+pds/`, `+pdsActions/`, `+rigConfigFiles/`,
     `PLDAPS_vK2_GUI.m`, data dictionaries; exclude analysis/validation subfolders,
     `.asv`, conflict copies, `wiki/`, `.claude/`;
   - drop paths already acknowledged by an earlier block this session (re-editing the same
     file does not re-block — staleness hashes catch it later);
   - if a wiki file was touched after the last block-worthy touch (log order, not mtime) →
     treat as handled;
   - else block once with: changed files → affected pages (or "no page covers X"),
     instructions (update narrative, run `wiki_gen.py all` + `stamp`, add a log line, record
     any rationale/session practice the user stated; make no edits if nothing documented
     changed), and: **finish with a final message whose first lines restate the substantive
     answer to the user's request** (the user reads only the final message), then one line
     naming wiki pages touched;
   - record acknowledged paths.
4. **SessionStart** (`wiki_session_start.py`) → run the hash staleness check (no model call)
   and inject one line of context, e.g. "Wiki: 3 pages stale (…). Run `/wiki update` when
   relevant." Silent when nothing is stale.

## 8. Skill

`.claude/skills/wiki/SKILL.md` → `/wiki update | ingest <path> | query <question> | lint`.

## 9. Bootstrap

1. Write tooling, SCHEMA.md; run `wiki_gen.py` to produce generated blocks/registry.
2. Parallel writer subagents (concepts+library; 5 task batches; active tasks prioritized:
   gSac_4factors, SRS_Task_Smooth, rfMap, barsweep, conflict_task). Writers fill narrative
   around GEN blocks, cite paths, report suspected bugs separately.
3. Verifier subagents (one per batch) check every claim against cited code and delete what
   can't be confirmed.
4. I write overview, gotchas, timeline, docs-catalog, log; run gen/stamp/lint to zero issues.

## 10. Verification

- Lint: 0 broken links, 0 orphans, full task coverage, 0 stale.
- Hook tests with synthetic stdin: no touches → silent; Edit of a task file → one block with
  correct page mapping; second Stop → no block; re-edit same file → no block; Bash-made edit
  credited; pre-existing dirty files not credited; conflict copies ignored; SessionStart
  reports staleness after a source file changes.

## 11. Review feedback not adopted

- "Block right after `git commit`": extra complexity; the once-per-file-set Stop rule plus
  session-start staleness covers it.
- A verifier agent per page: one per batch is the cost/benefit compromise.
- Moving CLAUDE.md's DKL section into the wiki: CLAUDE.md is user-authored guidance; left
  as-is, the wiki links to it.

## 12. Out of scope

qmd/embedding search; background headless updater (loses session rationale); committing
(left to the user; suggest committing wiki changes separately from code).

## 13. Implementation notes (2026-10-15)

- 56 pages: 15 concepts, 4 library, 1 generated reference, 31 task/family pages, overview,
  gotchas, timeline, docs-catalog, SCHEMA, log (+ generated index). Lint: 0 issues.
- Bootstrap: 8 writer agents, then 7 verifier agents (~45 corrections). Suspected code bugs
  were reported to the user in chat, not written onto pages.
- `wiki_gen.py` parses both strobeList layouts (`{name, expr}` and `fliplr({expr, name})`),
  missing commas and trailing commas; its registry integrity check lists strobeList names
  with no `initCodes` entry.
- Hooks live in `.claude/settings.json` + `.claude/hooks/wiki_hook.py`; all synthetic tests in
  §10 passed; the session-start check takes ~0.06 s.
