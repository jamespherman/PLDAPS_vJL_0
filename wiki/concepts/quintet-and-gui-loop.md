---
title: Quintet and GUI trial loop
type: concept
category: Concepts
summary: How PLDAPS_vK2_GUI.m loads a settings file, eval-dispatches init/next/run/finish, runs the trial loop, and stops
sources:
  - PLDAPS_vK2_GUI.m @ cc365abfb9
  - +pds/initTaskMetadata.m @ 764e25c2d9
  - +pds/stopRunButton.m @ 269adc74c1
  - tasks/gSac_4factors/gSac_4factors_settings.m @ 132bc9eff2
  - tasks/gSac_4factors/gSac_4factors_init.m @ 67777bb049
  - tasks/gSac_4factors/gSac_4factors_next.m @ f1bd18e88d
  - tasks/gSac_4factors/gSac_4factors_finish.m @ f800fddb30
  - tasks/SRS_Task_Smooth/srsSmooth_training_settings.m @ 3b82063292
verified_at: e48934be
updated: 2026-10-15
---

# Quintet and GUI trial loop

Every task is five functions (the "quintet", summarized in `CLAUDE.md`). Each one takes `p` and
returns it (`settings` takes no input and returns a new `p`). The GUI in `PLDAPS_vK2_GUI.m` is
the only caller. It finds the four runtime functions **by name strings stored in `p`** and runs
them with `eval`. See [gui.md](../library/gui.md) for the panels and callbacks.

## 1. Browse: choosing a settings file

`settingsFilesBrowse_callback` opens `uigetfile` and adds the file name and path to
`uiData.paths.settingsFileNames/settingsFilePaths`. You can browse more than one file. The
popup selects which one **Initialize** uses. Any `.m` file can be picked. It has to be a
function with no arguments that returns `p`, and its name must match the file name.

Settings *variants* are just more settings functions. A variant usually calls the base settings
and then overrides fields. For example, `srsSmooth_training_settings` calls `srsSmooth_settings`,
edits `p.trVarsInit.*`, and then re-copies `p.trVarsGuiComm = p.trVarsInit`. rfMap variants call
`rfMap_commonSettings(p)` instead.

## 2. Initialize

`initializeButton_callback`:

1. Resets the MATLAB path: `path(pathdef)`, `addpath(<PLDAPS root>)`, then
   `addpath(genpath(<settings file's folder>))`. This puts the task's `supportFunctions/` and
   `actions/` on the path, and removes any task loaded earlier. Packages at the root (`+pds`,
   `+pdsActions`, `+rigConfigFiles`) are reachable because the root is on the path.
2. `eval(['uiData.p = ' <settingsName>])` runs the settings function.
3. Fills the Control Parameters panel from `p.trVarsGuiComm` and `p.rig.guiVars`, the Status
   Values panel from `p.status` and `p.rig.guiStatVals`, the User Actions buttons from
   `p.init.taskActions`, and the output-path text from `p.init.outputFolder`. See
   [trial variables and GUI](trial-variables-and-gui.md) and [actions](actions.md).
4. Runs `Screen('CloseAll')`. If `p.init.useDataPixxBool` is set, it runs `Datapixx('close')`
   and then `Datapixx('Open')`. When the open fails, the callback stops with an error that
   tells you to turn the DataPixx on.
5. `eval(['uiData.p = ' p.init.taskFiles.init(1:end-2) '(uiData.p);'])` runs the task's
   `_init`.

`p.init.taskFiles.{init,next,run,finish}` are file names such as `gSac_4factors_init.m`. They
are built from `p.init.taskName`, either by `pds.initTaskMetadata` or written out in the
settings file. The task name does not have to match the directory name: `SRS_Task_Smooth` uses
`taskName = 'srsSmooth'`. The GUI does not `cd` into the task folder (that code is commented
out). After launch MATLAB stays in the PLDAPS root, so `p.init.pldapsFolder = pwd` in
`initTaskMetadata` and the settings files points at the root, and `p.init.outputFolder`
defaults to `<root>/output`.

What a typical `_init` does (`gSac_4factors_init`): load the rig config
(`pds.initRigConfigFile`), build the CLUT, `pds.initDataPixx` (opens the PTB window), load
textures and audio, set up the plot windows, `pds.defineGridLines`,
`p.init.codes = pds.initCodes`, `initTrialStructure`, `pds.initRipple`, and
`p.init.strb = pds.classyStrobe`.

## 3. Run: the trial loop

**Run** is a toggle button. `runButton_callback` stores its value in `uiData.p.runFlag` and
turns the button green. Then it loops:

```matlab
while uiData.p.runFlag
    uiData = guidata(hObject);                         % pick up GUI edits
    eval(['uiData.p = ' next '(uiData.p);']);   push; updateStatusValues; drawnow; pull
    eval(['uiData.p = ' run  '(uiData.p);']);   push; updateStatusValues; drawnow; pull
    eval(['uiData.p = ' finish '(uiData.p);']); push; updateStatusValues; drawnow; pull
    drawnow; if ~get(hObject,'Value'), break; end
end
```

"push" is `guidata(hObject, uiData)` and "pull" is `uiData = guidata(hObject)`. GUI callbacks
that are waiting (parameter edits, action buttons) run during each `drawnow`. They change the
stored copy, and the next pull picks those changes up. The status panel therefore refreshes
three times per trial.

What each step does, per trial (pattern from `gSac_4factors_next`/`_finish`):

| step | typical work |
|---|---|
| `_next` | `p.status.iTrial += 1`; `p.trVars = p.trVarsGuiComm` (the per-trial reset, see [p struct](p-struct.md)); `nextParams` picks the condition ([trial structure](trial-structure.md)); `pds.setSchedules`; `initTrData` resets `p.trData`; `pds.startEphysAndSchedules` |
| `_run` | frame loop / state machine until `p.trVars.exitWhileLoop` ([run loop](run-loop-state-machine.md)) |
| `_finish` | blank screen, `pds.readDatapixxBuffers`, set `trialRepeatFlag`, `pds.strobeTrialData` + `trialEnd` strobe ([strobe codes](strobe-codes.md)), `pds.waitForJoystickRelease`, Ripple data, `pds.saveP` ([data saving](data-saving.md)), status/plots, `updateTrialsList`, flush strobe lists |

## 4. Stopping

The loop has no separate pause control. Three things end it, and each takes effect only at a
trial boundary, so the current trial always completes:

- **Un-toggling Run.** The `get(hObject,'Value')` check after `_finish` breaks the loop. The
  button returns to its normal look and the status reads "Idle.".
- **`pds.stopRunButton`**, called from a task's `_finish` (rfMap, barsweep) when the session
  target is reached. It finds the handle tagged `'runButton'` with `findall` and sets its
  `Value` to false. If several handles match, it acts on the first one only.
- **Setting `p.runFlag = false`** inside the task. The `while uiData.p.runFlag` condition then
  fails (`human_psychophysical_threshold_finish`).

**Clear** (`clearButton_callback`) closes every figure except the GUI and runs
`Screen('CloseAll')`. Closing the GUI (`guiCloseFunction`) does the same and also runs
`Screen('CloseMovie')`.

## Related
- [gui.md](../library/gui.md): panels, callbacks, helper functions
- [p struct](p-struct.md), [trial variables and GUI](trial-variables-and-gui.md)
- [run loop / state machine](run-loop-state-machine.md), [actions](actions.md)
- `CLAUDE.md`: "Running the Framework" and "Creating a New Task"
