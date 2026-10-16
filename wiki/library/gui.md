---
title: PLDAPS_vK2_GUI
type: library
category: Library
summary: Structure of PLDAPS_vK2_GUI.m — figure layout, the six panels, every callback, and the helper functions
sources:
  - PLDAPS_vK2_GUI.m @ cc365abfb9
  - +pds/setStringListForGui.m @ df32df637c
  - +pds/loadP.m @ 6e86bda495
  - +pds/stopRunButton.m @ 269adc74c1
verified_at: e48934be
updated: 2026-10-15
---

# PLDAPS_vK2_GUI

`PLDAPS_vK2_GUI.m` is one programmatic GUI file: no GUIDE and no `.fig`. Running it builds the
figure, `cd`s to the PLDAPS root (the folder holding the file), resets the path to
`pathdef` plus that root, and stores everything in `guidata` as `uiData`. If called with an
output argument it returns the figure handle. How the loop works is in
[quintet loop](../concepts/quintet-and-gui-loop.md). This page is a map of the code.

## `uiData`

| field | contents |
|---|---|
| `uiData.handles.*` | figure `hGui`, `uiStatusString`, `panels.*`, and every uicontrol |
| `uiData.paths.pldapsDir` | root folder |
| `uiData.paths.settingsFileSearchStart` | where Browse opens (the root) |
| `uiData.paths.settingsFileNames/Paths` | every settings file browsed this session |
| `uiData.p` | the experiment struct ([p struct](../concepts/p-struct.md)) |

## Layout (800×500 figure named `PLDAPS_vK2_GUI`)

The status string runs along the top ("Ready to a select a Settings File" → "Ready to
Initialize" → "<protocol_title>: Initialized with file …" → "Running..." / "Idle."). The
panels:

| panel | position | contents | callbacks |
|---|---|---|---|
| Settings Files | top-left | popup of browsed files (hidden until the first browse); **Browse** | `settingsFilesPopUp_callback` (empty), `settingsFilesBrowse_callback` |
| Standard Actions | left | **Initialize**, **Clear**, **Run** (toggle) | `initializeButton_callback`, `clearButton_callback`, `runButton_callback` |
| User Actions | lower-left | 10 buttons from `p.init.taskActions` | `userActionButton_callback` ([actions](../concepts/actions.md)) |
| Control Parameters | centre | 12 rows: popup of `trVarsGuiComm` names + edit box | `ctrlParamPopUp_callback`, `ctrlParamEdit_callback` ([trial variables](../concepts/trial-variables-and-gui.md)) |
| Status Values | right | 12 rows: popup of `p.status` names + text | `statValPopUp_callback` (empty) |
| Output Files | lower-right | output folder text, **Output Path**, **Concatenate Output** | `outputPathButton_callback`, `concatenateOutputButton_callback` |

Everything except Browse starts hidden and appears as the workflow moves on: Initialize after
the first browse; the parameter, status, action and output controls on Initialize; Clear and
Run after the task's `_init` returns. Each panel's controls are built by a `build*UiControls`
function (`buildSettingsFilesUiControls`, `buildStandardActionsUiControls`,
`buildUserActionsUiControls`, `buildControlParametersUiControls`,
`buildStatusValuesUiControls`, `buildOutputFilesUiControls`), which `buildUiElements` calls
after `buildUiPanels` has built the panels. Parameter rows and action buttons share one
callback per control type, and each tells the callback which row it is through its `UserData`
index.

## Callbacks

- **`settingsFilesBrowse_callback`**: `uigetfile` starting at the root. Appends the name and
  path, selects the new entry, and shows the popup and Initialize.
- **`initializeButton_callback`**: resets the path (root + `genpath` of the settings folder);
  `eval`s the settings function into `uiData.p`; fills the parameter rows using
  `pds.setStringListForGui` and `p.rig.guiVars`, the status rows using `p.rig.guiStatVals`,
  the action buttons and the output path; runs `Screen('CloseAll')`, closes and reopens
  DataPixx, and sets `VisualDebuglevel` to 3; `eval`s `p.init.taskFiles.init`; prints the
  "PLDAPS vK2, AT YOUR SERVICE!" banner.
- **`runButton_callback`**: on toggle-on, colours the button green and loops
  `next → run → finish` while `uiData.p.runFlag` is set and the button is down, pushing and
  pulling `guidata` and calling `updateStatusValues` + `drawnow` after each step. On exit it
  restores the button and shows "Idle.". Tasks can end the loop with `pds.stopRunButton`
  (finds the `'runButton'` tag and sets `Value` false) or `p.runFlag = false`.
- **`ctrlParamPopUp_callback`**: shows the selected `trVarsGuiComm` value (`NaN` if it is not
  a scalar).
- **`ctrlParamEdit_callback`**: `str2double` the text and store it in
  `uiData.p.trVarsGuiComm` if the result is not `NaN`; otherwise restore the old value.
- **`userActionButton_callback`**: `which` the action, add the `pdsActions.` prefix if it
  lives in the package, `eval` it on `uiData.p`, and store the result.
- **`clearButton_callback`**: delete every figure whose name does not contain
  `PLDAPS_vK2_GUI`, then run `Screen('CloseAll')`.
- **`outputPathButton_callback`**: `uigetdir` and set `p.init.outputFolder` (and the text).
  `p.init.sessionFolder`, where `pds.saveP` writes the per-trial files, was fixed in
  settings and does not change.
- **`concatenateOutputButton_callback`**: `p = pds.loadP(uiData.p.init.sessionFolder)`, then
  save it as `<outputFolder>/<sessionId>.mat` with `save -struct`. If MATLAB warns
  `sizeTooBigForMATFile`, it saves again with `-v7.3` ([data saving](../concepts/data-saving.md)).
- **`guiCloseFunction`** (the figure's `DeleteFcn`): close the other figures, then
  `Screen('CloseAll')` and `Screen('CloseMovie')`.

## Helper functions

- **`updateStatusValues(uiData)`**: re-reads `sort(fieldnames(p.status))`, updates each
  status row's text from the field its popup currently selects, and rebuilds the popup lists
  so the selections stay put even when fields are added.
- **`pds.setStringListForGui(struct)`** (in `+pds`): flattens field names one level deep
  (`a`, `b.c`) for the parameter popups.

## Notes

- Task code is run with `eval` string dispatch, so a quintet function has to be callable by
  the bare name in `p.init.taskFiles.*` (minus `.m`) on the path that Initialize set up.
  `CLAUDE.md` "Caveats" points to IMPROVEMENT_PLAN.md for the modernization discussion.
- Initialize resets the path every time, so switching tasks does not leave the previous task's
  `supportFunctions/` (many tasks share file names such as `nextParams.m` and `initClut.m`)
  ahead of the new one.

## Related
- [quintet loop](../concepts/quintet-and-gui-loop.md),
  [trial variables and GUI](../concepts/trial-variables-and-gui.md),
  [actions](../concepts/actions.md), [pds functions](pds-functions.md)
