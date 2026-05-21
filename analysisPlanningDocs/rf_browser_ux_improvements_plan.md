# RF browser UX improvements — agent plan-prompt

Plan-prompt for a fresh Claude Code agent to land five related improvements to
the per-channel RF visualization browsers in PLDAPS_vK2. Copy the section below
the horizontal rule into the agent's initial prompt.

---

You're working in `/home/herman_lab/Documents/PLDAPS_vK2_MASTER` (MATLAB
neurophysiology framework — read `CLAUDE.md` at the repo root before doing
anything; it explains the quintet pattern, the `p` struct, and the strobe-code
conventions you must respect). Five related improvements to the per-channel RF
visualization browsers. Land each as a separate commit. Do **not** add doc
files, abstractions, or backwards-compat shims (see CLAUDE.md's "Doing tasks"
rules — they apply).

## Background (why these exist)

The user has been running RF mapping sessions with three tools that share the
per-channel browser infrastructure in `+pds/initChannelBrowser.m`:

- **barsweep** (cardinal4 and rfmap12 variants) — wraps via
  `tasks/barsweep/supportFunctions/initBarsweepChannelBrowser.m`
- **rfMap denseChromatic / denseAchromatic / sparse** — wraps via
  `tasks/rfMap/supportFunctions/initSTAChannelBrowser.m` and updates via
  `updateSTAChannelBrowser.m`
- **rfMap checkerboard** — wraps via `initCheckerboardChannelBrowser.m`

Recent sessions surfaced five pain points. The user has already verified these
are real problems and chosen the fix for each — your job is implementation,
not redesign.

## Task 1 — Fix per-channel tile aspect ratio

**File:** `+pds/initChannelBrowser.m:207`

Current code:
```matlab
img = imagesc(ax1, zeros(2));
axis(ax1, 'image');
axis(ax1, 'xy');
```

`axis image` forces the axes box to shrink to the image's pixel aspect, which
distorts the tile inside the grid cell. Replace with `axis equal` plus
explicit `xlim`/`ylim` set from the data extent in dva. The caller
(e.g. `initSTAChannelBrowser`, `initBarsweepChannelBrowser`) knows the extent
in dva (`p.trVars.rfMapExtentDeg` is half-width; the image spans
`[-extent, +extent]` in both x and y). `initChannelBrowser` is generic and
does not currently take that info — add an optional `opts.imgExtentDeg` field
(default `[]` to preserve current behavior for callers that don't set it;
when set, use as `[-imgExtentDeg, +imgExtentDeg]` on both axes).

Update both wrappers (`initBarsweepChannelBrowser`, `initSTAChannelBrowser`,
`initCheckerboardChannelBrowser`) to pass the extent through. Look at how
each wrapper constructs `opts` — there are existing examples to follow.

## Task 2 — Reduce barsweep `pathLengthDeg`

**File:** `tasks/barsweep/barsweep_cardinal4_settings.m:164`

Change `p.trVarsInit.pathLengthDeg = 70;` → `40`. (Reason: at 70 dva the bar
clips off-screen and creates apparent direction-dependent speed differences —
see commit `e87d0cdd` for related work.) Verify `barsweep_rfmap12_settings.m`
inherits this default (it should, but confirm — grep for `pathLengthDeg` in
the rfmap12 file).

## Task 4 — Dynamic per-channel panel sizing in STA browser

**Files:** `tasks/rfMap/supportFunctions/initSTAChannelBrowser.m` and
`+pds/updateChannelBrowserLayout.m`

Currently the right-hand panel grid is laid out as
`nCols = ceil(sqrt(nVisible))`, which tiles 16 channels into a 4×4 grid that
fills the viewport, but with only 2 channels selected leaves the panels small
in a 2×1 grid in the corner.

The user wants: when the selection count is small (say, ≤4), panels should
expand to fill the available viewport rather than tile in tiny corner cells.
Look at `+pds/updateChannelBrowserLayout.m` — that's where layout is
recomputed on selection change. Pick a sensible rule (e.g., if `nVisible ≤ 2`
use 1 column; if `nVisible ≤ 4` use 2 columns; otherwise current
`ceil(sqrt)`) and apply uniformly.

## Task 5 — Overlay RF center estimates on STA tiles

**Files:** `tasks/rfMap/supportFunctions/updateSTAChannelBrowser.m`, possibly
`initSTAChannelBrowser.m`

`tasks/rfMap/supportFunctions/computeRFCenters.m` returns per-channel RF
centers in dva. The result is written to `p.init.lastRFCentersDeg` in
`rfMap_finish.m:74` (and initialized to `nan(nCh, 2)` in `rfMap_init.m:299`).

Add a marker (e.g.,
`plot(ax, cx, cy, 'k+', 'MarkerSize', 10, 'LineWidth', 1.5)`) on each
channel's STA image axes showing the current center estimate. The marker
handle should be pre-created in `initSTAChannelBrowser` (one per channel,
stored on `bd` like `bd.rfCenterMarker(ch)`) and have its `XData`/`YData`
updated in `updateSTAChannelBrowser`. NaN centers should make the marker
invisible (`set(h, 'XData', NaN, 'YData', NaN)` works fine).

You'll need to thread the centers through to `updateSTAChannelBrowser` —
currently it takes `(bd, staAccum, staSpikeCount)`. Add a 4th argument
`rfCentersDeg` (Nx2, NaN-filled if unavailable) and update the call site in
`rfMap_finish.m:306`. Keep the argument optional via `nargin` so existing
flows don't break.

## Task 6 — PDF save button on STA browser

**Files:** `tasks/rfMap/supportFunctions/initSTAChannelBrowser.m`, uses
`+pds/pdfSave.m`

Add a "Save PDF" button to the left-hand control column of the STA browser
(see `+pds/initChannelBrowser.m:88-100` for how the left column is laid out —
you'll likely need to add this button in the wrapper after
`pds.initChannelBrowser` returns, or extend `initChannelBrowser` with an
optional `opts.extraLeftButtons` hook). Callback uses `pds.pdfSave`:

```matlab
pds.pdfSave(fileName, bd.fig.Position(3:4)/72, bd.fig);
```

Use `uiputfile('*.pdf', 'Save STA browser as PDF')` to pick the filename.
Default filename can be something like `sta_browser_<yyyymmdd_HHMMSS>.pdf`.

## Verification — ask the user

You **cannot** launch PLDAPS yourself: it depends on hardware (DataPixx,
ViewPixx, Psychtoolbox display), runs only on the rig PC, and shows results
in a GUI you can't see. Do not run `PLDAPS_vK2_GUI.m`, do not invoke the
`run` skill, do not try to instrument a headless harness — none of those will
exercise the actual UI changes.

Instead, before declaring the bundle done:

1. Make sure each commit compiles cleanly (`mlint` / `checkcode` if you want
   static checks, but the user's environment is the source of truth).
2. Produce a short **verification checklist** for the user — a numbered list
   of exactly what they should look at, broken down per task. For example:
   > Please verify in a real PLDAPS session:
   > - **Task 1 (aspect ratio):** Run `barsweep_cardinal4_settings.m`, open
   >   the channel browser. Each per-channel tile should be square, not
   >   stretched. Repeat with `rfMap_denseChromatic_settings.m`.
   > - **Task 2 (pathLengthDeg):** Bars should sweep across the full active
   >   display region without clipping at the edges.
   > - **Task 4 (dynamic panels):** Select 1, 2, 4, and 16 channels in the
   >   STA browser listbox. With ≤4 selected, panels should expand to fill
   >   the viewport; with 16, the original 4×4 grid should return.
   > - **Task 5 (RF center overlay):** After enough trials accumulate, a
   >   `+` marker should appear on each tile at the computed RF center.
   >   Channels with NaN centers should show no marker.
   > - **Task 6 (PDF save):** Click "Save PDF" in the left column. Open the
   >   resulting PDF and confirm it matches the on-screen browser.
3. Tell the user explicitly that you have **not** verified the UI changes
   yourself and that the commits should not be considered final until they
   confirm. If they report a regression, fix and amend (or add a follow-up
   commit, per CLAUDE.md's git-safety conventions).

## Commit structure

One commit per numbered task, in numeric order. Commit messages should follow
the style of recent commits (`git log -10` — short imperative, e.g.,
`rfMap: overlay RF center markers on STA browser tiles`).

## Out of scope

Do not refactor `initChannelBrowser` beyond what these tasks require. Do not
add new abstractions for "future" features. Do not touch the checkerboard
browser unless task 1 forces you to (it shares `initChannelBrowser`). Do not
modify `+pds/initCodes.m` or any `strobeList` — none of these tasks need new
strobe codes.
