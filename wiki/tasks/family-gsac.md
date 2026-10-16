---
title: gSac family (guided saccades)
type: family
category: Tasks — gSac family
summary: Shared design and lineage of gSac, gSac_jph, gSac_contrast and gSac_4factors, with a differs-from-parent table
status: active
sources:
  - tasks/gSac/gSac_settings.m @ 484a1c321c
  - tasks/gSac/gSac_run.m @ dbf5649de4
  - tasks/gSac/supportFunctions/nextParams.m @ a194f805dc
  - tasks/gSac/supportFunctions/initTrialStructure.m @ c799a84474
  - tasks/gSac_jph/gSac_jph_settings.m @ 68f571a08a
  - tasks/gSac_jph/gSac_jph_run.m @ 973df8c549
  - tasks/gSac_jph/gSac_jph_finish.m @ a936bf3f09
  - tasks/gSac_jph/supportFunctions/nextParams.m @ d5aac792a1
  - tasks/gSac_contrast/gSac_contrast_settings.m @ 12ae4c0fd6
  - tasks/gSac_contrast/gSac_contrast_run.m @ e80e9d586e
  - tasks/gSac_contrast/supportFunctions/nextParams.m @ f38fc93da2
  - tasks/gSac_contrast/supportFunctions/initTrialStructure.m @ 04eae873fd
  - tasks/gSac_4factors/gSac_4factors_settings.m @ 132bc9eff2
  - tasks/gSac_4factors/gSac_4factors_run.m @ 9aa849922b
  - tasks/gSac_4factors/supportFunctions/nextParams.m @ 3356244d78
  - tasks/gSac_4factors/supportFunctions/initTrialStructure.m @ bad52d5c96
verified_at: e48934be
updated: 2026-10-15
---

# gSac family (guided saccades)

The four gSac tasks are variants of one visually- or memory-guided saccade
paradigm. The subject fixates and a peripheral target appears. In
memory-guided trials the target flashes and disappears. When the fixation
point turns off (the go signal), the subject saccades to the target and holds
gaze on it for juice. All four use the same state set and broadly the same
`_run.m` skeleton. They differ in how target locations and conditions are
chosen, in what the target looks like, and in what is recorded.

| Task | Status | Purpose |
|---|---|---|
| [gSac](gSac.md) | legacy | Original stock vis/mem saccade task (Omniplex era) |
| [gSac_jph](gSac_jph.md) | active | Saccade/RF mapping with the `saccadeGUI` window and Ripple spikes |
| [gSac_contrast](gSac_contrast.md) | legacy | DKL target/background salience × reward, 2 mirror locations |
| [gSac_4factors](gSac_4factors.md) | active | Stimulus identity/salience × reward × probability × location (current recordings) |

## Shared design

- **States** (same IDs in all four settings files): `trialBegun`=1, `waitForJoy`=2, `showFix`=3, `dontMove`=4, `makeSaccade`=5, `checkLanding`=6, `holdTarg`=7, `sacComplete`=21, `fixBreak`=31, `joyBreak`=32, `nonStart`=33, `failedToHoldTarg`=34 (defined but not entered). See [run-loop state machine](../concepts/run-loop-state-machine.md).
- **Timing** is drawn per trial in `nextParams.m → timingInfo` and counted from fixation acquisition: `timeTargOnset` = U(`targOnsetMin`, `targOnsetMax`), target offset = onset + `targetFlashDuration` for memory trials (Inf for visual trials where supported), and go signal = onset + U(`goTimePostTargMin`, `goTimePostTargMax`). The goTimes are measured from **target onset**, so the memory delay is `goTimePostTarg − targetFlashDuration`.
- **Saccade window:** leaving the fixation window before `goLatencyMin`, or not leaving it by `goLatencyMax`, is a `fixBreak`. After landing in the target window, gaze must be held for U(`targHoldDurationMin`, `targHoldDurationMax`). Memory trials re-illuminate the target during or after the hold (`targetReillum`).
- **Location strobes** use polar coordinates, `targetTheta` = angle × 10 and `targetRadius` = ecc × 100, set in `setLocations` (see [strobe codes](../concepts/strobe-codes.md)).
- **Trial arrays** (where used): `updateTrialsList` marks a row done only after a non-error trial. Errors (`fixBreak`, `joyBreak`, `nonStart`) leave it available. See [trial structure](../concepts/trial-structure.md).
- **`passJoy = 1`** is the default in every settings file, which makes `pds.joyHeld` always true (see [eye and joystick](../concepts/eye-and-joystick.md)).
- Behavioural events are strobed with `strobeNow` and visual events are queued and strobed after the flip (commit 61d7a932 for gSac/gSac_jph/gSac_contrast, ce70510d for gSac_4factors).

## Lineage

- `gSac` and `gSac_jph` were both present at the repository's initial commit (2022-08-04). gSac_jph extends gSac with online gaze velocity, blink detection, the saccade-mapping GUI and Ripple.
- `gSac_contrast` was added 2024-06-06 (ac709aa8). It shares gSac_jph's support-function set and run-loop structure, and adds DKL colour (`initmon`, `dkl2rgb`, per-rig LUT files) and the i1 calibration actions.
- `gSac_4factors` was created 2025-08-06 (c4e0fd3d) as a verbatim copy of gSac_contrast's `_run.m` and `nextParams.m`, then rewritten over 2025-08 and 2026-01.

## Differs from parent

| Aspect | gSac | gSac_jph (vs gSac) | gSac_contrast (vs gSac_jph) | gSac_4factors (vs gSac_contrast) |
|---|---|---|---|---|
| Target location | `preset_quatro`: 2 RF points + rotated partners, from trial array `gSac4_v1` | `saccadeGUI` picks locations (`setTargLocViaGui = true`), or ring/grid lists | Trial array: `targDegX/Y` (default −6, 0) or its mirror (`targetLocIdx` 2 = negated) | 4 locations: base `targDegX_base/Y_base` rotated in 90° steps |
| Vis vs mem | from the trial array (`gSac4_v1` has both); `propVis` 0.5 otherwise | `propVis` 1 (visual by default) | `propVis` 0 (memory) | Always memory (`isVisSac = 0`) |
| Conditions | location × vis/mem (`trialCode` 20x0x) | none (mapping) | 2 locations × 8 target/background DKL configs × high/low reward, 3 reps (96 trials) | 4 half-blocks × 4 locations × 6 stimTypes; probability and reward blocks |
| Target stimulus | square outline | square outline | square outline in DKL hue on DKL background (4 high-, 4 low-salience pairs) | face/non-face image textures or two-ring DKL bullseye; per-trial background |
| Saccade detection | exit window + `maxSacDurationToAccept` | adds online velocity threshold and blink check (`onlineGaze`) | same as gSac_jph | same, plus the `fixOff > 0` guard on the latency check |
| Visual event times | `timeNow` in state machine | `timeNow` | `timeNow` | flip time via `p.trVars.postFlip` |
| Error handling | errored row reshuffled | (no trial array by default) | errored row repeated immediately (`chooseRow`) | errored row redrawn later in same half-block |
| Reward | single `rewardDurationMs` | single `rewardDurationMs` | `highLowRwd` trial-array column; the location/reward pairing switches partway through each block (`chooseRow`, `tLoc1HighRwdFirst`) | `rewardDurationHigh/Low` by hemifield, swapped each half-block |
| Ephys | Omniplex (`pds.getOmniplexData`) | Ripple (`pds.initRipple`, `getRippleData`), spikes to `saccadeGUI` | Ripple | Ripple |
| Post-trial metrics | none | `calcSacParams` (pkV, SRT, pre/post XY) | same | same, SRT in trial-relative time |
| End-of-trial strobes | taskCode/date/time, `connectPLX`, `vissac`, location, `rewardDuration`, counts, `passJoy`, `joyPressVoltDir`, `trialCode` | drops `passJoy`, `joyPressVoltDir`, `trialCode` | adds `trialCode` back | drops `connectPLX`; adds block/half-block, location index, stimType, salience, reward, targetColor, imageId |

Each task page's generated facts block has the exact strobeList.

## Related

- Concepts: [quintet and GUI loop](../concepts/quintet-and-gui-loop.md), [drawing and postFlip](../concepts/drawing-and-postflip.md), [colour and calibration](../concepts/color-and-calibration.md), [ephys integration](../concepts/ephys-integration.md), [reward](../concepts/reward.md).
- Docs: `analysisPlanningDocs/gSac_jph_analysis_planning.md`, `analysisPlanningDocs/gSac_contrast_analysis_planning.md`, `analysisPlanningDocs/gSac_4factors_task_description.md`, `data_dictionaries/gSac_jph_data_dictionary.md`, `data_dictionaries/4factors_data_dictionary.md`.
