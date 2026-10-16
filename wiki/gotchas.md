---
title: Gotchas
type: meta
category: Start here
summary: Non-obvious behaviors of the framework and repository that are easy to trip over
sources:
  - +pds/strobeTrialData.m @ 119964102b
  - +pds/initCodes.m @ 55d625cb0d
  - +pds/classyStrobe.m @ 4b9bb7c352
verified_at: e48934be
updated: 2026-10-16
---

# Gotchas

Facts about how the framework and repository behave that are easy to miss. Each links to the
page that explains it. Suspected bugs are tracked separately in [open issues](open-issues.md).

## Strobing

- **One failing strobeList row ends the list.** `pds.strobeTrialData` wraps its whole loop
  in a single `try/catch` with an empty handler. If a row's code name is missing from
  `initCodes.m`, or its value expression errors, that row and every later row go unstrobed,
  with no message. Rows before it are still sent. The
  [registry's integrity checks](reference/strobe-codes.md#integrity-checks) list strobeList
  names that have no code. See [strobe codes](concepts/strobe-codes.md).
- **Two strobeList layouts exist.** Newer settings files write `{'codeName', 'valueExpr'; …}`;
  older ones write `fliplr({'valueExpr', 'codeName'; …})`, which swaps the columns at load
  time. The column order has to match the form used.
- **Values must fit in 15 bits** (0–32767) and be non-negative integers; negative or
  fractional quantities are offset or scaled first (CLAUDE.md, "Handling negative values").
- **A name assigned twice in `initCodes.m` keeps its last value.** The file's own duplicate
  check looks at values, not names; `noChange` and `isNoChangeTrial` are each assigned twice.
- **Task-local `initCodes.m` copies are not used.** Several joystick tasks carry
  `supportFunctions/initCodes.m`, but their `_init` files call `pds.initCodes`.

## Timing

- **postFlip timestamps are `-1` until the flip after the state change.** Check
  `p.trData.timing.X > 0` before using one (CLAUDE.md;
  [drawing and postFlip](concepts/drawing-and-postflip.md)).

## Names and files

- **File prefixes don't always match the directory.** `tasks/nfl/` holds `scd_*` files;
  `tasks/joystickPress_playMovie/` holds `joystickPress_*` files. The quintet file names come
  from `p.init.taskName` set in the settings file, not from the directory name ([quintet and GUI loop](concepts/quintet-and-gui-loop.md)).
- **Rig config function names don't always match their file names**: for example
  `+rigConfigFiles/rigA_20200203.m` declares `rigConfig_rigF_20190328`
  ([rig configs](library/rig-configs.md)).
- **Output location is set per task.** Most settings files use
  `fullfile(p.init.pldapsFolder, 'output')` (repository root); `srsMoving_settings.m` uses the
  task folder ([data saving](concepts/data-saving.md)).

## Repository hygiene

- **OneDrive conflict copies.** The repo lives in OneDrive and is used from more than one
  machine, so files like `initCodes-Murawski-Desktop.m` appear (in the working tree and in
  `.git/`). They are not part of the code; the wiki tools and hooks ignore them.
- **MATLAB autosaves (`.asv`) are tracked**: 27 `.asv` files are in git.
- **`+test/` is an older snapshot** of the GUI, `+pds`, and several tasks; current tasks don't
  call into it.
