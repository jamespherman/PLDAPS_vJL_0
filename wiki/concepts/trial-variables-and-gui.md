---
title: Trial variables and the GUI
type: concept
category: Concepts
summary: trVarsInit vs trVarsGuiComm vs trVars, how a GUI edit reaches the next trial, guiVars/guiStatVals, and the Status Values panel
sources:
  - PLDAPS_vK2_GUI.m @ cc365abfb9
  - +pds/setStringListForGui.m @ df32df637c
  - +pds/initTrialVariables.m @ 0850b09f1c
  - tasks/gSac_4factors/gSac_4factors_settings.m @ 132bc9eff2
  - tasks/gSac_4factors/gSac_4factors_next.m @ f1bd18e88d
  - tasks/SRS_Task_Smooth/srsSmooth_next.m @ 1868be0a2d
  - tasks/SRS_Task_Smooth/supportFunctions/readCorrectionControlWindow.m @ 8827a79c4b
verified_at: e48934be
updated: 2026-10-15
---

# Trial variables and the GUI

## Three copies of the trial variables

| struct | written by | role |
|---|---|---|
| `p.trVarsInit` | settings file; `pds.initRigConfigFile` (in `_init`) also sets `rewardDurationMs` from `p.rig.baseReward` when the rig config defines it | defaults. Some code reads constants straight from it during the trial (for example `p.trVarsInit.eyeVelFiltTaps` and `p.trVarsInit.targWidth` in `gSac_4factors_run`) |
| `p.trVarsGuiComm` | settings (`p.trVarsGuiComm = p.trVarsInit` at the end of the trVars section); GUI edit boxes; occasionally task code | the "GUI communication" copy: the only one the GUI reads and writes |
| `p.trVars` | every `_next`: `p.trVars = p.trVarsGuiComm` | the copy the trial runs on and the one saved per trial (`trialNNNN.mat`) |

So an edit flows: **edit box → `p.trVarsGuiComm` → copied into `p.trVars` at the next `_next`
→ used and saved for that trial.** Every task's `_next.m` does this copy. An edit made while a
trial is running therefore takes effect on the *following* trial.

Anything `_next`/`nextParams` assigns after the copy wins over the GUI value for that trial.
For example, `gSac_4factors`' `nextParams` sets `targDegX/Y` from the trial array's
`targetLocIdx`. Because the whole struct is replaced, values written to `p.trVars` during one
trial do not carry into the next. Anything that must persist goes in `p.status` or
`p.trVarsGuiComm` ([p struct](p-struct.md)).

Task code writes `p.trVarsGuiComm` directly in a few places. SRS_Task_Smooth's
`readCorrectionControlWindow` (called in `srsSmooth_next` right after the copy) reads its own
correction-control figure and writes the values into both `trVars` and `trVarsGuiComm`.
`rfMap_init` sets `p.trVarsGuiComm.noiseFrameHold`.

## Control Parameters panel (12 rows)

On Initialize the GUI calls `pds.setStringListForGui(p.trVarsGuiComm)`. It lists every field
name and goes one level into substructs, producing names such as `postFlip.logical`. The list
is sorted and every row's popup gets the full list.

- `p.rig.guiVars` (a cell of up to 12 names, set in settings) chooses the starting variable for
  each row. If a name has no match, the GUI warns ("couldnt match guiVars …") and falls back to
  the i-th variable alphabetically. An empty entry uses the same fallback.
- `ctrlParamPopUp_callback` shows the selected variable's current value. Non-scalar values show
  as `NaN`.
- `ctrlParamEdit_callback` parses the typed text with `str2double`. Any result other than `NaN` is stored
  in `uiData.p.trVarsGuiComm.(name)`. Anything else is rejected and the box goes back to the
  stored value. Only numeric scalars can be edited from the GUI: strings, vectors and logicals
  shown as numbers come back as doubles.

Because `trVarsInit` also holds run-loop bookkeeping (`currentState`, `exitWhileLoop`,
`whileLoopIdx`, …), those names appear in the popup list too.

## Status Values panel (12 rows)

The panel shows fields of `p.status`, which counts and tracks the session and is never reset
by `_next`.

- Names are `sort(fieldnames(p.status))`. `p.rig.guiStatVals` (settings) sets which ones show
  first. Rows beyond that list are filled with the first names alphabetically.
- `updateStatusValues(uiData)` runs after each of `_next`, `_run` and `_finish`. It re-reads
  `fieldnames(p.status)`, so fields added during the session show up, and keeps each popup on
  the field it had selected. Non-scalar values (for example the `onlineMetrics` cell in
  gSac_4factors) display as `NaN`.
- The status popups are read-only views. `statValPopUp_callback` is empty.

## `pds.initTrialVariables`

This helper operates on a `c` struct rather than `p`. It evals `c.trialVars{i,1} =
c.trialVars{i,2}` over a `c.trialVars` list. No current task calls it. Trial variables are
reset by the `trVarsGuiComm` copy, and trial data by each task's own `initTrData` (rows of
`p.init.trDataInitList`).

## Practical notes

- To expose a new parameter, add it to `p.trVarsInit` *before* the
  `p.trVarsGuiComm = p.trVarsInit` line. To show it at startup, list it in `p.rig.guiVars`.
- Settings variants that change `trVarsInit` after calling the base settings must copy it
  again (`p.trVarsGuiComm = p.trVarsInit`), as `srsSmooth_training_settings.m` does.
- `pdsActions.dataToWorkspace` copies the current `p` (including `trVarsGuiComm`) into the base
  workspace for inspection ([actions](actions.md)).

## Related
- [quintet loop](quintet-and-gui-loop.md), [gui.md](../library/gui.md), [p struct](p-struct.md)
