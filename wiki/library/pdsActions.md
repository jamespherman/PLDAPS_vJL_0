---
title: +pdsActions catalog
type: library
category: Library
summary: Every function in +pdsActions (GUI user-action buttons) and how the GUI resolves and calls actions listed in p.init.taskActions
sources:
  - +pdsActions/ @ 59fe231f21
  - PLDAPS_vK2_GUI.m @ cc365abfb9
verified_at: e48934be
updated: 2026-10-15
---

# +pdsActions catalog

## How actions are invoked

- **Listing.** A settings file lists actions in `p.init.taskActions`, a cell array
  of function names such as `'pdsActions.singleReward'` or a bare
  `'i1LivePhotometer'`.
- **Buttons.** After the settings file loads, `PLDAPS_vK2_GUI.m` labels up to 10
  "User Actions" buttons with these names, dropping the `pdsActions.` prefix for
  display.
- **Click.** `userActionButton_callback` resolves the name with `which(...)`. If the
  resolved path contains `pdsActions`, it adds the `pdsActions.` prefix back. It
  then runs `uiData.p = <name>(uiData.p);` with `eval`. Every action therefore has
  the signature `p = action(p)`.
- **Task-local actions.** The GUI adds the selected task folder and all its
  subfolders to the path (`addpath(genpath(...))`), so functions in a task's
  `actions/` folder are found by bare name. Examples are `summarizeBehaviorBasic`
  and the i1 tools.

For the broader picture of actions vs. trial variables, see
[actions](../concepts/actions.md).

## Functions in `+pdsActions/`

| Action | What it does | Listed in |
|---|---|---|
| `dataToWorkspace` | `assignin('base', 'p', p)`: copies the live `p` to the base workspace. | almost every settings file |
| `blackScreen` | Fills the PTB window with 0 and flips. | almost every settings file |
| `alphaBinauralBeats` | Plays the "alpha binaural beats" clip from DataPixx audio memory (`p.audio.alphaBuffAdd`, written by `pds.initAudio`). | almost every settings file |
| `stopAudioSchedule` | `Datapixx('StopAudioSchedule')`. | almost every settings file |
| `rewardDrain` | 30 × 9.5 s solenoid openings with 0.5 s pauses to flush the reward line; closing the waitbar aborts. | most monkey tasks |
| `singleReward` | One opening of `p.trVars.rewardDurationMs`. | many monkey tasks |
| `rewardGive` | Poisson-timed rewards (λ = 0.7 per 1 s cycle, 0.1 s each) for 180 s or until Esc. | no current settings file |
| `catOldOutput` | Folder picker → `pds.loadP` → saves `<folder>.mat` next to the folder (falls back to `-v7.3`). | many tasks |
| `exportRFCentersCSV` | Writes `channel,x_deg,y_deg` from `p.trData.rfCentersDeg` (in session) or from the latest `trial*.mat` in a chosen folder, as `rfCenters_<sessionId>_trialNNN.csv`. Used to target sacc_to_phosph by hand. | rfMap |
| `exportBarsweepRFCentersCSV` | Same CSV format, reconstructed from the barsweep RF accumulator. In session it uses `p.init.barsweepRF`; afterwards it uses the `<sessionId>_barsweepRF.mat` sidecar. | barsweep |
| `evaluateRFQuality` | Runs rfMap's `computeChannelQuality` on the STA accumulators and prints per-channel pass/fail and RF centers. In simulation it also prints error against ground truth. | rfMap |
| `recheckThresholds` | Runs `pds.recheckSpikeThresholds` and prints init vs. current noise σ. | rfMap |

The three reward actions open the DataPixx themselves and use DAC channel 0,
buffer `6e6`, at 1 kHz. They do not strobe. See [reward](../concepts/reward.md).
The CSV and RF actions are described with their tasks
([rfMap](../tasks/rfMap.md), [barsweep](../tasks/barsweep.md),
[sacc_to_phosph](../tasks/sacc_to_phosph.md)). The threshold action is described in
[ephys integration](../concepts/ephys-integration.md).

## Task-local actions (not in this package)

- `summarizeBehaviorBasic`: in the `actions/` folders of fixate, the joystick_*
  tasks, joystickPress, nfl, scd, tokens, reward_calibration and
  human_psychophysical_threshold.
- `analyzePupilPE`: tokens.
- `i1CalibrateAndMeasure`, `i1Validate` and the script `dklToRgbFileMaker`: in the
  `actions/` folders of gSac_4factors, gSac_contrast,
  human_psychophysical_threshold and SRS_Task_Smooth. SRS_Task_Smooth has extra
  i1 photometry actions. See [color and calibration](../concepts/color-and-calibration.md).

gSac_4factors, gSac_contrast and conflict_task list the i1 tools as
`pdsActions.dklToRgbFileMaker`, `pdsActions.i1CalibrateAndMeasure` and
`pdsActions.i1Validate`, but no files with those names exist in `+pdsActions/`.
SRS_Task_Smooth lists its i1 actions by bare name.

## Related

- [GUI](gui.md), [+pds catalog](pds-functions.md), [quintet and GUI loop](../concepts/quintet-and-gui-loop.md)
