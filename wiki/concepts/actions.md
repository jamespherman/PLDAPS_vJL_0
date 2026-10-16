---
title: Actions
type: concept
category: Concepts
summary: How p.init.taskActions lists +pdsActions and per-task actions/ functions, how the GUI makes buttons for them and runs them via eval
sources:
  - PLDAPS_vK2_GUI.m @ cc365abfb9
  - tasks/gSac_4factors/gSac_4factors_settings.m @ 132bc9eff2
  - tasks/SRS_Task_Smooth/srsSmooth_settings.m @ 34495a80b8
  - +pdsActions/ @ 59fe231f21
verified_at: e48934be
updated: 2026-10-15
---

# Actions

An *action* is a function `p = name(p)` that the experimenter runs from a button in the GUI's
**User Actions** panel. Typical uses are giving a reward by hand, draining the reward line,
blanking the screen, copying `p` into the workspace, or running a calibration routine.
Actions come from two places:

- **`+pdsActions/`**: shared package functions, listed with the package prefix
  (`'pdsActions.rewardDrain'`). The catalog is in [pdsActions](../library/pdsActions.md).
- **`tasks/<task>/actions/`**: task-specific functions, listed by bare name (`'i1LivePhotometer'` in
  `srsSmooth_settings.m`).
  They are on the path because Initialize adds `genpath(<settings folder>)`.
  Examples: `summarizeBehaviorBasic.m` in many joystick-era tasks, the i1 photometer and
  DKL tools (`i1CalibrateAndMeasure`, `i1Validate`, `dklToRgbFileMaker`, …) in gSac_4factors,
  gSac_contrast, human_psychophysical_threshold and SRS_Task_Smooth, and `analyzePupilPE.m` in
  tokens.

## Declaring them

Each settings file fills `p.init.taskActions`, a cell of name strings, for example in
`gSac_4factors_settings.m`:

```matlab
p.init.taskActions{1} = 'pdsActions.dataToWorkspace';
p.init.taskActions{2} = 'pdsActions.blackScreen';
p.init.taskActions{5} = 'pdsActions.rewardDrain';
```

`srsSmooth_settings.m` mixes the two kinds: `pdsActions.*` plus bare `i1FindGrayBackgroundLum`,
`i1LivePhotometer`, …. The most common set across tasks is `dataToWorkspace`, `blackScreen`,
`alphaBinauralBeats`, `stopAudioSchedule`, `rewardDrain`, `catOldOutput` and `singleReward`.

## How the GUI uses them

On Initialize (`initializeButton_callback`):

- The panel has **10 buttons** (`buildUserActionsUiControls`, `nUserActionRows = 10`). The
  first `min(10, numel(taskActions))` buttons get labels and become visible.
- The label is the entry with a leading `pdsActions.` removed. The labels are stored in
  `p.init.taskActionsElegant`.

On click (`userActionButton_callback`):

1. The button's `UserData` is its index into `p.init.taskActions`.
2. `fileparts(which(<entry>))` finds the file. If the folder path contains `pdsActions`, the
   function name is prefixed with `pdsActions.`.
3. `eval(['uiData.p = ' nameString '(uiData.p);'])` runs it, and the returned `p` is stored
   with `guidata`.

Because the returned `p` is stored, an action can change session state, for example
`p.trVarsGuiComm` or `p.status`. If the trial loop is running, the callback runs at one of the
loop's `drawnow` calls between quintet steps, and the next `guidata` pull picks up the result
([quintet loop](quintet-and-gui-loop.md)). Actions that only have side effects return `p`
unchanged: `blackScreen` fills the PTB window with 0 and flips, `dataToWorkspace` does
`assignin('base','p',p)`, and `stopAudioSchedule` stops the DataPixx audio schedule.

## Writing a new action

1. Write `function p = myAction(p)`. Use it for work done between trials. A callback that runs
   during the loop blocks the next trial until it returns.
2. Put it in `tasks/<task>/actions/` (task-specific) or `+pdsActions/` (shared).
3. Add it to `p.init.taskActions` in the settings file, by bare name for a task folder or as
   `'pdsActions.myAction'` for the package, keeping the total at 10 or fewer.

## Related
- [pdsActions catalog](../library/pdsActions.md), [gui.md](../library/gui.md),
  [reward](reward.md) (`rewardDrain`, `rewardGive`, `singleReward`)
