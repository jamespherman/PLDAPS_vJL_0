---
title: The p struct
type: concept
category: Concepts
summary: Every top-level field of p, which quintet function creates or resets it, and what persists across trials and into saved files
sources:
  - PLDAPS_vK2_GUI.m @ cc365abfb9
  - +pds/initTaskMetadata.m @ 764e25c2d9
  - +pds/initRigConfigFile.m @ f32e98b29d
  - +pds/initDataPixx.m @ d2924f59b6
  - +pds/saveP.m @ 299010d8a6
  - +pds/loadP.m @ 6e86bda495
  - tasks/gSac_4factors/gSac_4factors_settings.m @ 132bc9eff2
  - tasks/gSac_4factors/gSac_4factors_init.m @ 67777bb049
  - tasks/gSac_4factors/gSac_4factors_next.m @ f1bd18e88d
  - tasks/gSac_4factors/supportFunctions/initTrData.m @ 534411fb3d
verified_at: e48934be
updated: 2026-10-15
---

# The `p` struct

All experiment state lives in one struct, `p`. The GUI keeps it in `uiData.p`
([quintet loop](quintet-and-gui-loop.md)). Each quintet function receives it and returns it.
The settings files start with `p = struct;`. The header comment in `gSac_4factors_settings.m`
lists the substructs, and the table below follows that list plus what the code adds.

## Top-level fields

| field | created by | reset per trial? | contents |
|---|---|---|---|
| `p.init` | settings (`pds.initTaskMetadata` or hand-written), extended in `_init` | no | session metadata: `taskName`, `taskCode`, `date_1yyyy`/`date_1mmdd`/`time_1hhmm`, `sessionId`, `outputFolder`, `sessionFolder`, `taskFiles`, `taskActions`, `useDataPixxBool`, `rigConfigFile`, `pcName`, `exptType`, `strobeList`, `trDataInitList`/`nTrDataListRows`; in `_init`: `codes` (`pds.initCodes`), `strb` (`pds.classyStrobe` handle object), `trialsArray`, `trialArrayColumnNames` |
| `p.rig` | settings (screen/refresh/joystick, `guiVars`, `guiStatVals`), then `pds.initRigConfigFile` and the hardware init | no | rig geometry (`viewdist`, `deg2PixConstant`), `refreshRate`/`frameDuration` (re-measured in `pds.initDataPixx`), `magicNumber`, joystick thresholds `joyThresh`, DataPixx settings `p.rig.dp.*`, Ripple status `p.rig.ripple`, `baseReward` |
| `p.state` | settings | no (constant) | state name → integer ID ([run loop](run-loop-state-machine.md)) |
| `p.status` | settings (initial values), updated in `_next`/`_finish` | no, accumulates | trial counters (`iTrial`, `iGoodTrial`, …), block bookkeeping (`trialsArrayRowsPossible`), online metrics; shown in the GUI Status Values panel |
| `p.trVarsInit` | settings | no | default value of every trial variable |
| `p.trVarsGuiComm` | settings: `p.trVarsGuiComm = p.trVarsInit` | no; GUI edits write here | the copy the GUI edits ([trial variables](trial-variables-and-gui.md)) |
| `p.trVars` | `_next`: `p.trVars = p.trVarsGuiComm` | **yes** | this trial's variables, plus per-trial picks from `nextParams` (condition, locations, timing) and live values written during `_run` (eye/joystick, `currentState`, `whileLoopIdx`, `flipIdx`, `postFlip`) |
| `p.trData` | `_next` via the task's `initTrData` looping over `p.init.trDataInitList` | **yes** | data collected this trial: `timing.*` (initialized to `-1`), `eyeX/Y/P/T`, `joyV`, `onlineGaze`, `strobed`, `trialEndState`, `trialRepeatFlag`, spike/event data |
| `p.draw` | settings (`clutIdx`, `color.*`, pen widths), `_init` (`window`, `screenRect`, `middleXY`, `clut`, grid) | no | drawing parameters and the PTB window ([drawing](drawing-and-postflip.md)) |
| `p.audio` | settings, then `pds.initAudio` | no | tone frequencies and durations, buffers |
| `p.stim` | settings, `_init`, `nextParams` | no | stimulus parameters and textures; `gSac_4factors_next` copies it into `p.trVars.stim` every trial |
| `p.runFlag` | GUI Run button | — | toggle state; a task can set it false to end the loop |

## What resets each trial and what persists

The per-trial reset happens in `_next` and depends on two lines:

1. `p.trVars = p.trVarsGuiComm` overwrites every trial variable. Run-loop bookkeeping stored in
   `trVarsInit` (`currentState = p.state.trialBegun`, `exitWhileLoop = false`,
   `whileLoopIdx = 0`, `flipIdx = 1`, `postFlip`) therefore returns to its start value at the
   beginning of every trial.
2. `initTrData(p)` evals each `{'p.trData.x', '<init expr>'}` row of `p.init.trDataInitList`.
   This is what sets every `p.trData.timing.*` to `-1` (see the postFlip rule in `CLAUDE.md`).

Everything else carries over from trial to trial. That includes `p.draw`: colors changed in
`_run` (for example `p.draw.color.fix`) keep their values unless the next trial sets them
again. `p.status` and the `p.init.strb` object also persist. `_finish` clears the strobe
object's veto and strobed lists with `flushVetoList` and `flushStrobedList`.

## What gets saved

`pds.saveP` writes to `p.init.sessionFolder` ([data saving](data-saving.md)):

- trial 1: the whole of `p` as `p.mat` (`save -struct`), plus a zip of the task folder.
- every trial except non-starts: appends `status` to `p.mat` and writes `trialNNNN.mat` with
  `trVars`, `trData`, `status` and `init`.

`pds.loadP` rebuilds a single `p` from those files. It loads `p.mat` and then builds
`p.trVars` and `p.trData` as struct arrays across trials, using `pds.unifyStructArray` to merge
mismatched field sets.

## Related
- [trial variables and GUI](trial-variables-and-gui.md), [quintet loop](quintet-and-gui-loop.md)
- [data saving](data-saving.md); data dictionaries in `data_dictionaries/` (for example
  `4factors_data_dictionary.md`)
- `CLAUDE.md`: "The Central Data Structure: `p`"
