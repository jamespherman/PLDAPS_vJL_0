---
title: Open issues
type: catalog
category: Start here
summary: Verified suspected bugs and stale docs — where, what happens, effect on recorded data and since when; resolved items kept with the fixing commit
sources:
  - +pds/deliverOptoStim.m @ 114a9d1386
  - +pds/deliverReward.m @ 35fec770c6
  - +pds/freeReward.m @ e0108ee298
  - +pds/initCodes.m @ 55d625cb0d
  - +pds/initRigConfigFile.m @ f32e98b29d
  - +pds/regenerateStim_mcd.m @ 53f00c23cd
  - +pds/setStringListForGui.m @ df32df637c
  - +pds/state2num.m @ 01b26ee488
  - +pds/strobeTrialData.m @ 119964102b
  - PLDAPS_vK2_GUI.m @ cc365abfb9
  - analysisPlanningDocs/barsweep_geometry_discrepancy_report.md @ 0fcdfc5591
  - analysisPlanningDocs/gSac_4factors_task_description.md @ 3e8b965e68
  - data_dictionaries/4factors_data_dictionary.md @ 4439263e5a
  - data_dictionaries/joystick_release_for_stim_change_and_dim_data_dictionary.md @ c4dcdb6937
  - data_dictionaries/rfMap_data_dictionary.md @ d767ec0bc9
  - tasks/SRS_Task_Smooth/srsClassic_Moretraining_settings.m @ 399ab2b57c
  - tasks/SRS_Task_Smooth/srsSmooth_init.m @ 5471f02001
  - tasks/SRS_Task_Smooth/srsSmooth_run.m @ 74859508c5
  - tasks/SRS_Task_Smooth/srsSmooth_settings.m @ 34495a80b8
  - tasks/SRS_Task_Smooth/supportFunctions/sampleTargetDelayMs.m @ 89479f7228
  - tasks/SRS_mooving/srsMoving_Moretraining_settings.m @ efd2b6f309
  - tasks/SRS_mooving/srsMoving_finish.m @ 8ae379cb89
  - tasks/conflict_task/conflict_task_settings.m @ 4467fe7e8c
  - tasks/gSac/gSac_settings_trialsArray.m @ dae7681ff1
  - tasks/gSac/supportFunctions/initTrialStructure.m @ c799a84474
  - tasks/gSac_4factors/gSac_4factors_settings.m @ 132bc9eff2
  - tasks/gSac_4factors/gSac_4factors_task_design_specification.md @ 82458e7bb4
  - tasks/gSac_contrast/gSac_contrast_run.m @ e80e9d586e
  - tasks/gSac_contrast/gSac_contrast_settings.m @ 12ae4c0fd6
  - tasks/gSac_contrast/supportFunctions/nextParams.m @ f38fc93da2
  - tasks/gSac_jph/gSac_jph_run.m @ 973df8c549
  - tasks/human_psychophysical_threshold/human_psychophysical_threshold_run.m @ 37b06a5f59
  - tasks/joystick_release_for_fix_and_stim_dim/supportFunctions/initTrialStructure.m @ 3b88272007
  - tasks/joystick_release_for_fix_and_stim_dim/supportFunctions/nextParams.m @ 977d171255
  - tasks/joystick_release_for_fix_dim/joystick_release_for_fix_dim_run.m @ 635c3716d7
  - tasks/joystick_release_for_fix_dim/joystick_release_for_fix_dim_settings_DEBUG.m @ baf0722fd0
  - tasks/joystick_release_for_fix_dim/supportFunctions/nextParams.m @ 4ca43fec1a
  - tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_orient_change_and_dim_learn_chg_settings.m @ 62b8c7b22b
  - tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_stim_change_and_dim_run.m @ ebd1fcdcad
  - tasks/joystick_release_for_stim_change_and_dim/supportFunctions/initTrialStructure.m @ 19a34084fa
  - tasks/joystick_release_for_stim_change_and_dim/supportFunctions/nextParams.m @ 965006cfcd
  - tasks/joystick_release_for_stim_change_and_dim/supportFunctions/updateTrialsList.m @ 8a9220550d
  - tasks/nfl/scd_run.m @ 96fd513609
  - tasks/nfl/scd_settings.m @ 17d86ece27
  - tasks/nfl/scd_settings_nflNoSgl.m @ fb1ddedc87
  - tasks/nfl/supportFunctions/generateStimuli.m @ 73f8570bfb
  - tasks/nfl/supportFunctions/initClut.m @ 6a988f81b1
  - tasks/nfl/supportFunctions/initCodes.m @ 06471934f3
  - tasks/nfl/supportFunctions/initTrialStructure.m @ f0095b599a
  - tasks/rfMap/_validation/SIM_MODE_PLAN.md @ 194208745d
  - tasks/rfMap/rfMap_commonSettings.m @ 13b0ec92af
  - tasks/rfMap/sim_setup_population.m @ c3937d2f25
  - tasks/scd/scd_run.m @ 417d5bf557
  - tasks/scd/scd_settings_satInc.m @ 5bad9a710b
  - tasks/scd/supportFunctions/initClut.m @ 6a988f81b1
  - tasks/tokens/supportFunctions/nextParams.m @ 9506049c47
  - tasks/tokens/tokens_run.m @ 95459e3a0b
  - tasks/tokens/tokens_settings.m @ 4184994680
verified_at: e48934be
updated: 2026-10-16
---

# Open issues

Suspected bugs and out-of-date docs found while building this wiki (2026-10-15/16). Every
item was found by one agent reading the code and then re-checked against the code and git
history by a second; nobody has run MATLAB to reproduce them. **Confidence** says which
entries depend on runtime conditions. IDs are stable — keep them when editing.

Other wiki pages describe the code as it is and link here by ID rather than restating an
issue. When a fix lands, move the entry to [Resolved](#resolved) with the date and commit
(the Stop hook reminds Claude to do this when it edits a cited file).

## Items that affect recorded data

Most useful when analyzing existing sessions. "Since" is the commit that introduced the
behavior (details in each entry).

| ID | Task / scope | Effect | Since |
|---|---|---|---|
| [S1](#s1-srs_task_smooth-strobes-no-strobelist-values-pinittaskcode-never-set) | SRS_Task_Smooth | No per-trial strobeList pairs reach ephys (trial data in .mat is intact) | 2026-07-21 afafeb63 |
| [T1](#t1-gsac_contrast-reward-duration-is-always-the-low-value) | gSac_contrast | Low reward on every trial; intended high/low still in `rwdSize`/`trialCode` | 2025-08-07 c6b0a4bb |
| [T14](#t14-srs_task_smooth-target-delay-is-a-fixed-450-ms) | SRS_Task_Smooth | Target delay fixed at 450 ms; strobed `delta` constant | 2026-08-17 09e7d867 |
| [S7](#s7-joystick_release_for_stim_change_and_dim-reactiontime-mixes-time-bases) | joystick_release_for_stim_change_and_dim | Saved `reactionTime` too large by `fixAq` (recomputable) | 2022-11-08 ec6aa85a |
| [T7](#t7-stim_change_and_dim-correct-reject-reward-timed-from-a-field-the-task-never-sets) | joystick_release_for_stim_change_and_dim | cr reward delivered immediately (no `rewardDelay`) | 2022-11-08 ec6aa85a |
| [T8](#t8-free-reward-schedule-is-not-reset-between-blocks-singularplural-field-name) | joystick_release_for_stim_change_and_dim | Free-reward eligibility accumulates across blocks | 2023-07-05 67a81f67 |
| [T4](#t4-opto-table-cue-2-rows-with-a-mismatched-stimulus-or-change-location) | joystick_release_for_stim_change_and_dim (opto) | Two cue-2 trialCode pairs don't describe what was shown | 2024-12-18 333a6f44 |
| [T5](#t5-learn_cue_multi-table-reuses-trialcodes-23152-and-23352) | joystick_release_for_stim_change_and_dim (learn_cue_multi) | trialCodes 23152/23352 each label two conditions | 2025-08-04 8adb9586 |
| [T6](#t6-7030-table-cue-location-4-has-7-no-change-rows-instead-of-3) | joystick_release_for_stim_change_and_dim (7030) | Location 4 has 7 no-change rows (others 3) | 2025-06-06 9230a828 |
| [T11](#t11-joystick_release_for_fix_dim-correct-rejects-end-before-the-reward-branch-runs) | joystick_release_for_fix_dim | cr trials unrewarded (likely) | 2022-10-11 7b352ded |
| [T2](#t2-gsac_contrast-always-starts-with-location-1-low-reward--location-2-high-reward) | gSac_contrast | First block always loc1-low/loc2-high | 2024-06-06 ac709aa8 |
| [T18](#t18-makesaccade-compares-trial-time-with-a-duration-meant-to-start-at-fixation-acquisition) | sacc_to_phosph (WiP) | Hold-fixation outcome timed from trial start (likely) | 2026-05-19 d1e37fc4 |
| [S8](#s8-numerosity-temporal-strobe-name-typo-microstimchanne) | numerosity (WiP), temporal | Electrode-2 channel/amplitude not strobed | 692fde30 |
| [S3](#s3-nfl-variants-strobe-randseedtrialrandseedstim-which-are-not-in-pdsinitcodesm) | nfl (5 variants) | Trial/stim seed (and `isContrastChangeTrial`) not strobed | 2022-08-04 97559e58 |
| [S4](#s4-nfl-trialtypetrialcode-strobe-sends-trialsarray-column-9-saturation-flag) | nfl | `trialType`/`trialCode` strobe carries the saturation flag | 2022-08-04 97559e58 |
| [S5](#s5-nochange-and-isnochangetrial-are-each-assigned-twice-in-pdsinitcodesm) | nfl, scd, stim_change_and_dim | `noChange`/`isNoChangeTrial` codes changed value (6006/6009 → 6021/6023) | 2022-11-08 ec6aa85a |
| [S6](#s6-trialend-strobed-twice-per-trial-in-many-tasks) | fixate, 6 joystick tasks, scd, nfl, reward_calibration, SRS_Task_Smooth, tokens | `trialEnd` strobed twice per trial | task creation |
| [S9](#s9-gsac_4factors-reward-level-strobed-with-the-reward-delivery-code) | gSac_4factors | Reward level shares code 8000 with reward delivery (noted in task description §9) | see entry |
| [S10](#s10-gsac_4factors-strobes-rewardduration-twice-per-trial) | gSac_4factors | `rewardDuration` strobed twice per trial | 5124ac6d |
| [T23](#t23-drawmachine-sends-an-eyelink-trial_end-message-on-every-loop-iteration) | human_psychophysical_threshold | Many Eyelink `TRIAL_END` messages per trial in EDF files | 2023-04-03 49e0383b |
| [F2](#f2-gsac_jph-and-gsac_contrast-overwrite-pinitrigconfigfile-with-rig1-every-frame) | gSac_jph, gSac_contrast | Saved `p.init.rigConfigFile` always names rig1 | 2023-03-31 / 2024-06-06 |

Everything else below is behavior-only (a task errors, a counter or comment is wrong, a
button does nothing) or documentation.

## Strobes and saved data

**Mechanism.** `pds.strobeTrialData` (`+pds/strobeTrialData.m`) wraps its entire loop over `p.init.strobeList` in a single `try ... catch me` whose handler is empty (only a commented-out `keyboard`). Each row does `p.init.codes.(name)` and then `eval(expr)`. If either fails for row *k* (code name not in `+pds/initCodes.m`, a name that is not a valid field name, or a value expression that errors), control jumps out of the loop: rows 1..*k*−1 have already been queued with `addValue`, row *k* and every row after it are not. The `p.init.strb.strobeList` call that sends the queue sits after the `catch`, so the earlier rows are still sent. No warning is printed and nothing is written to `p`. `p.trData.strobed` (from `strobedList`) records only what was actually sent. Confirmed by reading code.

### S1. SRS_Task_Smooth strobes no strobeList values (`p.init.taskCode` never set)
- **Where:** `tasks/SRS_Task_Smooth/srsSmooth_settings.m` (WHAT TO STROBE section); `tasks/SRS_Task_Smooth/srsSmooth_init.m`
- **What happens:** Row 1 of the strobeList is `'taskCode', 'p.init.taskCode'`. Nothing in `SRS_Task_Smooth` sets `p.init.taskCode`: no call to `pds.initTaskMetadata` and no direct assignment. The `eval` fails on row 1, so no strobeList pairs are sent on any trial. All 8 settings variants (`srsSmooth_settings`, `_classic`, `_classic_training`, `_direct_rgb`, `_direct_rgb_training`, `_training`, `_Moretraining`, `srsClassic_Moretraining`) inherit this list from `srsSmooth_settings`. `codes.uniqueTaskCode_SRS_task` (32023) is defined in `+pds/initCodes.m` but nothing references it. `SRS_mooving` is not affected: `srsMoving_init.m` sets `p.init.taskCode = p.init.codes.uniqueTaskCode_SRS_mooving`, checks every strobeList name against `p.init.codes`, and `srsMoving_finish.m` checks every value before strobing.
- **Effect on recorded data:** Every SRS_Task_Smooth session sent no per-trial code/value pairs to ephys (task code, date/time, trial counts, salience/luminance/hue values, and so on). Event codes sent with `strobeNow` (trialBegin, trialEnd, …) still go out. The `.mat` trial data (`p.trVars`, `p.trData`) is unaffected. This has been the case since the task was added (2026-07-21 afafeb63).
- **Confidence:** Confirmed by reading code
- **Possible direction:** set `p.init.taskCode` (e.g., via `pds.initTaskMetadata` or from `uniqueTaskCode_SRS_task`) in settings or init.

### S2. nfl `scd_settings.m` strobeList columns are in reverse order
- **Where:** `tasks/nfl/scd_settings.m` (`p.init.strobeList`)
- **What happens:** The list is written as `{'valueExpr', 'codeName'}` (e.g., `'p.trVars.isCueChangeTrial', 'isCueChangeTrial'`) with no `fliplr`. Every other `scd_settings_*.m` variant wraps its list in `fliplr`. Row 1 evaluates `p.init.codes.('p.trVars.isCueChangeTrial')`, which is an invalid field name, so no strobeList pairs are sent. The list also contains `cueRadius` and `cueTheta`, which are not in `+pds/initCodes.m`. Separately, this file's rig config path does not exist (see F7), so `_init` stops before any trial runs.
- **Effect on recorded data:** If a session ever ran with this file, it sent no strobeList pairs. The file has been this way since the initial commit (2022-08-04 97559e58).
- **Confidence:** Likely. Data loss depends on a session having run with this file, which F7 suggests is not possible with the current rig configs.

### S3. nfl variants strobe `randSeedTrial`/`randSeedStim`, which are not in `+pds/initCodes.m`
- **Where:** `tasks/nfl/scd_settings_nflNoSgl.m`, `scd_settings_nflNoSgl_50.m`, `scd_settings_nflNoSgl_shortBlocks.m`, `scd_settings_nfl_eachChangeOnce.m`, `scd_settings_satIncNoSgl.m` (`p.init.strobeList`)
- **What happens:** These lists use the code names `randSeedTrial` and `randSeedStim`. `+pds/initCodes.m` (which `scd_init.m` loads) defines `trialSeed` (16667) and `stimSeed` (16666) but has no `randSeed*` names, and git shows it never has. `fliplr` swaps only the columns, so row order is unchanged. Row 15 (`randSeedTrial`) fails, and rows 1–14 are sent. Lost rows:
  - In the four 17-row lists (`nflNoSgl`, `nflNoSgl_50`, `nflNoSgl_shortBlocks`, `nfl_eachChangeOnce`): rows 15–17, i.e., trial seed, stim seed and `isContrastChangeTrial`.
  - In `satIncNoSgl` (16 rows): rows 15–16, i.e., trial seed and stim seed.

  `scd_settings_nfl.m` uses `trialSeed`/`stimSeed` and is not affected.
- **Effect on recorded data:** In sessions run with these five settings files, ephys has no trial seed, stim seed or (where listed) `isContrastChangeTrial` pairs. The values are still in the `.mat` trial data. This has been the case since the initial commit (2022-08-04 97559e58).
- **Confidence:** Confirmed by reading code

### S4. nfl `trialType`/`trialCode` strobe sends trialsArray column 9 (saturation flag)
- **Where:** `tasks/nfl/scd_settings_*.m` (strobeList row `p.init.trialsArray(p.trVars.currentTrialsArrayRow, 9)`); `tasks/nfl/supportFunctions/initTrialStructure.m` (`p.init.trialArrayColumnNames`)
- **What happens:** In the nfl trials array, column 9 is `'saturation'` (whether saturation changes). The stimulus/trial code is column 15 (`'stimcode'`). Every variant strobes column 9 under the name `trialType` (`_nfl`, `_satInc`, `_fourStimTest`, `_satIncNoSgl`) or `trialCode` (`_nflNoSgl*`, `_nfl_eachChangeOnce`). `scd_settings.m` has the same row, but that list sends nothing (S2).
- **Effect on recorded data:** In nfl sessions, the 11010 (`trialType`) or 11009 (`trialCode`) value in ephys is the saturation-change flag, not the trial code. The column layout and the strobe row have both been the same since the initial commit (2022-08-04 97559e58).
- **Confidence:** Confirmed by reading code
- **Possible direction:** use the column lookup by name (`strcmp(p.init.trialArrayColumnNames, 'stimcode')`), as other tasks do.

### S5. `noChange` and `isNoChangeTrial` are each assigned twice in `+pds/initCodes.m`
- **Where:** `+pds/initCodes.m` (stimulus codes section; validation section)
- **What happens:** `codes.noChange = 6006` and later `codes.noChange = 6021`. `codes.isNoChangeTrial = 6009` and later `= 6023`. The later assignment overwrites the earlier one, so the codes in use are 6021 and 6023, and 6006 and 6009 are never produced. The duplicate check at the end of the file compares field *values*, so it cannot detect a repeated *name*. The unused copy `tasks/nfl/supportFunctions/initCodes.m` has only 6006 and 6009. Tasks that send these codes:
  - `noChange` (via `addValue`): `tasks/nfl/scd_run.m`, `tasks/scd/scd_run.m` and `joystick_release_for_stim_change_and_dim_run.m`.
  - `isNoChangeTrial` (strobeList): all `tasks/nfl/scd_settings*.m` and `tasks/scd/scd_settings_satInc.m`.
  - `alignSpikes.m` in `joystick_release_for_stim_change_and_dim` and `joystickPress_playMovie` match on `codes.noChange`.
- **Effect on recorded data:** Since 2022-11-08 (ec6aa85a), these tasks have sent 6021 and 6023. Sessions recorded before that commit used 6006 and 6009. Decoding older data with the current `initCodes.m` maps 6006 and 6009 to no name.
- **Confidence:** Confirmed by reading code

### S6. `trialEnd` strobed twice per trial in many tasks
- **Where:** `*_run.m` (`stateMachine`, the `if p.trVars.exitWhileLoop` end-of-trial block) and `*_finish.m` ("strobe and mark end of trial")
- **What happens:** In these tasks, `p.init.strb.strobeNow(p.init.codes.trialEnd)` runs once when the run loop ends and again in `_finish`. `strobeNow` has no veto. `_finish` also overwrites `p.trData.timing.trialEnd` with its own later time.
  - Affected: `fixate`; `joystickPress`, `joystickPress_playMovie`, `joystick_press_and_fixate`, `joystick_release_for_fix_off`, `joystick_release_for_fix_dim`, `joystick_release_for_fix_and_stim_dim`; `reward_calibration`; `scd`; `nfl`; `SRS_Task_Smooth`; `tokens`.
  - Not affected: `joystick_release_for_stim_change_and_dim`. The `_finish` strobe was removed on 2023-06-27 (de3fbaff), so it strobes only from `_run`.
- **Effect on recorded data:** Each trial has two 30009 events in ephys and in `p.trData.strobed`. The saved `timing.trialEnd` is the `_finish` time. This has been true since each task was created: 2022-08-04 97559e58 for fixate, joystickPress, joystickPress_playMovie, joystick_press_and_fixate, scd and nfl; fix_off 2022-09-01 be9556bc; fix_dim 2022-10-05 f2b4a5bb; fix_and_stim_dim 2022-10-24 5bae0a20; reward_calibration 2023-02-08 3f9fbfed; tokens 2025-07-31 44f19e1b; SRS_Task_Smooth 2026-07-21 afafeb63.
- **Confidence:** Confirmed by reading code

### S7. joystick_release_for_stim_change_and_dim `reactionTime` mixes time bases
- **Where:** `tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_stim_change_and_dim_run.m` (`stateMachine`, three joystick-release branches); `supportFunctions/updateStatusVariables.m`
- **What happens:** `p.trData.timing.reactionTime = p.trData.timing.joyRelease - p.trVars.stimChangeTime`. `joyRelease` is `timeNow`, which is measured from trial start. `stimChangeTime` is measured from fixation acquisition (the state machine compares it with `timeNow - p.trData.timing.fixAq`). The result is offset by `fixAq`. `p.status.reactionTimes` stores this value. `data_dictionaries/joystick_release_for_stim_change_and_dim_data_dictionary.md` documents the same formula and describes `stimChangeTime` as relative to fixation acquisition.
- **Effect on recorded data:** In all sessions of this task, `p.trData.timing.reactionTime` and `p.status.reactionTimes` are larger than the change-to-release time by `timing.fixAq`. The true value can be recomputed from the saved `joyRelease`, `fixAq` and `stimChangeTime`. This has been the case since the task was added (2022-11-08 ec6aa85a).
- **Confidence:** Confirmed by reading code

### S8. numerosity temporal: strobe name typo `'microStimChanne;'`
- **Where:** `tasks/numerosity (WiP)/numerosity_settings_temporal.m` (`p.init.strobeList`)
- **What happens:** Row 6 uses the code name `'microStimChanne;'`, which is not a valid field name. Rows 1–5 are sent. Row 6 (`stimElectrode2`) and row 7 (`microStimCurrAmp` / `stimAmplitude2`) are not. `numerosity_settings_spatial.m` spells it correctly.
- **Effect on recorded data:** Temporal-variant sessions sent no second-electrode channel or amplitude pairs. This has been the case since 2026-05-11 (692fde30). The task is marked WiP.
- **Confidence:** Confirmed by reading code

### S9. gSac_4factors reward level strobed with the reward-delivery code
- **Where:** `tasks/gSac_4factors/gSac_4factors_settings.m` (strobeList row `'reward'`); `+pds/deliverReward.m`
- **What happens:** `pds.deliverReward` sends `codes.reward` (8000) as an event at delivery. At trial end the strobeList row `'reward'` sends 8000 followed by the trial-array reward level (1 or 2). `analysisPlanningDocs/gSac_4factors_task_description.md` §9 contains an "Ephys caution" note. It says the end-of-trial reward level uses code 8000, the same as the reward-delivery event, and that an 8000 followed by a 1 or 2 near trial end is the reward level, not a second delivery. It adds that `rewardDuration` (18000) also gives the level unambiguously.
- **Effect on recorded data:** Rewarded trials carry two 8000 codes in ephys. This has been the case since 2025-08-06 (5124ac6d).
- **Confidence:** Confirmed by reading code

### S10. gSac_4factors strobes `rewardDuration` twice per trial
- **Where:** `tasks/gSac_4factors/gSac_4factors_settings.m` (`p.init.strobeList`, Core Trial Information block)
- **What happens:** `'rewardDuration', 'p.trVars.rewardDurationMs'` appears twice: after `blockNumber` and after `targetRadius`. Both pairs are sent. The task description §9 notes this ("`rewardDuration` is sent twice per trial").
- **Effect on recorded data:** Two 18000/value pairs per trial in ephys. This has been the case since 2025-08-06 (5124ac6d).
- **Confidence:** Confirmed by reading code

## Task behavior

**gSac family**

### T1. gSac_contrast reward duration is always the low value
- **Where:** `tasks/gSac_contrast/supportFunctions/nextParams.m` (`timingInfo`)
- **What happens:** `timingInfo` looks up the trial-array column `'reward'`, but `initTrialStructure` names that column `'highLowRwd'`. The lookup returns an empty value, `if p.trVars.reward == 1` is false, and every trial gets `rewardDurationMs = p.trVarsInit.rewardDurationLow` (160 ms by default). `timingInfo` also reads `p.trVarsInit` rather than `p.trVars`, so GUI edits to `rewardDurationHigh`/`rewardDurationLow` have no effect.
- **Effect on recorded data:** Every gSac_contrast session since 2025-08-07 (`c6b0a4bb`, "Final changes to the gSac_4factors task", which rewrote this function) delivered the low reward on all trials. The strobed `rewardDuration` and the saved `p.trVars.rewardDurationMs` show the low value. The intended high/low condition is still saved in `p.trVars.rwdSize` (taken from `highLowRwd`) and in the strobed `trialCode`. Before that commit, the function read `'highLowRwd'` directly.
- **Confidence:** Confirmed by reading code
- **Possible direction:** Read the `'highLowRwd'` column, as `chooseRow` and the pre-2025-08-07 version do.

### T2. gSac_contrast always starts with location 1 low reward / location 2 high reward
- **Where:** `tasks/gSac_contrast/supportFunctions/nextParams.m` (`chooseRow`)
- **What happens:** The comment says "flip a coin", but the code is `p.status.tLoc1HighRwdFirst = rand < 0;`, which is always false. The first half of the first block therefore always uses the rows with location 1 low reward and location 2 high reward. `updateTrialsList` flips the flag at each block end, so the order alternates after that.
- **Effect on recorded data:** Block order (which reward pairing comes first) is the same in every gSac_contrast session. The code has been this way since the file was created (2024-06-06, `ac709aa8`). Since 2025-08-07, T1 makes the delivered reward low on all trials anyway. The pairing still sets the saved `rwdSize`, the `trialCode` and the experimenter-display target window.
- **Confidence:** Confirmed by reading code
- **Possible direction:** `rand < 0.5`.

### T3. gSac_settings_trialsArray.m selects an exptType that initTrialStructure does not handle
- **Where:** `tasks/gSac/gSac_settings_trialsArray.m`, `tasks/gSac/supportFunctions/initTrialStructure.m`
- **What happens:** These settings set `p.init.exptType = 'all_locs'`. The `switch` in gSac's `initTrialStructure` has only `case 'gSac4_v1'` and no `otherwise`, so `table` is never assigned. The next line, `sum(table(:, nCols - 1))`, then resolves `table` to MATLAB's built-in `table` function, which errors during Initialize.
- **Effect on recorded data:** None (behavior only)
- **Confidence:** Confirmed by reading code (that no case matches); the exact error message depends on MATLAB's handling of `table(...)`.

**Joystick family**

### T4. Opto table: cue-2 rows with a mismatched stimulus or change location
- **Where:** `tasks/joystick_release_for_stim_change_and_dim/supportFunctions/initTrialStructure.m` (`tableDef_stimDimPlusOrientChange_opto`)
- **What happens:** Two kinds of cue-location-2 rows have a column that does not match the row's comment and trialCode.
  - Single-patch change rows (trialCode 23222 opto−, 24222 opto+): the stim-on columns turn on stimulus 3 (`0 0 1 0`), while `stim chg = 2`. The change is applied to patch 2, which is not shown.
  - Multi-patch "Change @ 1" rows (23251, 24251): `stim chg = 3`. These rows duplicate the "Change @ 3" rows, and the multi-patch change-at-1 condition never occurs for cue 2.
- **Effect on recorded data:** Sessions run with `joystick_release_for_orient_change_and_dim_opto_settings.m` since 2024-12-18 (`333a6f44`, "Opto stim attention task updates"). In those sessions, trialCodes 23222/24222 and 23251/24251 do not describe what was displayed. Recover the actual configuration from the saved trialsArray row (stim-on columns, `stim chg`).
- **Confidence:** Confirmed by reading code

### T5. learn_cue_multi table reuses trialCodes 23152 and 23352
- **Where:** `tasks/joystick_release_for_stim_change_and_dim/supportFunctions/initTrialStructure.m` (`tableDef_stimDimPlusOrientChange_learn_cue_multi`)
- **What happens:** Two codes each label two conditions:
  - 23152: cue 1, change at location 2, and also cue 1, change at location 3 (23153 is not used).
  - 23352: cue 3, change at location 1, and also cue 3, change at location 2 (23351 is not used).

  Commit `30a8d201` (2024-07-30, "Modified 'trial codes' to be unique") had unique codes, including 23153. The duplicates appeared when the table was edited in `8adb9586` (2025-08-04).
- **Effect on recorded data:** The strobed and saved `trialCode` cannot tell these condition pairs apart in sessions using `joystick_release_for_orient_change_and_dim_learn_cue_settings.m` (exptType `..._learn_cue_multi`) since 2025-08-04 (`8adb9586`). The `stim chg` column of the saved trialsArray row does distinguish them. (`tableDef_..._learn_cue_multi_100`, which no current settings file selects, also repeats 23120 and 23310.)
- **Confidence:** Confirmed by reading code

### T6. 7030 table: cue location 4 has 7 no-change rows instead of 3
- **Where:** `tasks/joystick_release_for_stim_change_and_dim/supportFunctions/initTrialStructure.m` (`tableDef_stimDimPlusOrientChange_7030`)
- **What happens:** Locations 1–3 each have 7 change and 3 no-change repetitions. Location 4 has 7 change and 7 no-change (last row, trialCode 23007). A block is therefore 44 trials: 28 change and 16 no-change (64% change overall, 50% at location 4).
- **Effect on recorded data:** Change/no-change proportions in sessions using `joystick_release_for_orient_change_and_dim_settings_7030.m` since 2025-06-06 (`9230a828`, "Attention task changes").
- **Confidence:** Confirmed by reading code

### T7. stim_change_and_dim correct-reject reward timed from a field the task never sets
- **Where:** `tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_stim_change_and_dim_run.m` (`stateMachine`, `cr` state)
- **What happens:** The `cr` state delivers reward when `(timeNow - p.trData.timing.fixHoldReqMet) > p.trVars.rewardDelay`. This run file never assigns `fixHoldReqMet`, so it stays at its initial `-1` and the condition is true immediately. Reward is delivered as soon as the `cr` state is entered, with no `rewardDelay`. The `hit` state uses `fixAq + hitRwdTime` instead.
- **Effect on recorded data:** On cr trials, reward time (`timing.reward`) equals cr-state entry, in all settings of this task since it was created (2022-11-08, `ec6aa85a`).
- **Confidence:** Confirmed by reading code

### T8. Free-reward schedule is not reset between blocks (singular/plural field name)
- **Where:** `tasks/joystick_release_for_stim_change_and_dim/supportFunctions/updateTrialsList.m`
- **What happens:** At a block boundary the code resets `p.status.freeRewardAvailable` (singular), a field nothing else reads. It then sets new true entries in `p.status.freeRewardsAvailable` (plural), which `_finish.m` reads. The plural vector is never cleared, so true entries from earlier blocks remain and the number of trial rows eligible for a free reward grows from block to block. The per-block count here is `ceil(blockLength/10)`, while `nextParams` uses `freeRewardProbability` for the first block.
- **Effect on recorded data:** Changes which trials were followed by inter-trial free rewards (`p.status.freeRwdTotal` and the free-reward strobe) when free rewards are on (`freeRewardProbability > 0` and `freeRewardFlag`; the learn_cue and opto settings default to 0.1). This dates from 2023-07-05 (`67a81f67`).
- **Confidence:** Confirmed by reading code

### T9. learn_chg settings lack the interval Min/Win variables read by timingInfo
- **Where:** `tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_orient_change_and_dim_learn_chg_settings.m`, `supportFunctions/nextParams.m` (`timingInfo`)
- **What happens:** `timingInfo` reads `p.trVars.fix2CueIntvlMin`, `fix2CueIntvlWin`, `cue2StimIntvlMin` and `cue2StimIntvlWin`. The learn_chg settings define only `fix2CueIntvl`, so the first trial's `nextParams` errors with a missing-field error. The learn_chg settings were created 2024-05-15 (`bcf9dcb9`). `timingInfo` started reading these variables on 2024-08-07 (`af77b01e`).
- **Effect on recorded data:** None (behavior only)
- **Confidence:** Confirmed by reading code

### T10. Three stim_change_and_dim settings find the PLDAPS folder by matching 'PLDAPS_vK2_MASTER'
- **Where:** `joystick_release_for_orient_change_and_dim_learn_cue_settings.m`, `..._Quest_settings.m`, `..._opto_settings.m` (all in `tasks/joystick_release_for_stim_change_and_dim/`)
- **What happens:** These settings use `p.init.pldapsFolder = regexp(mfilename('fullpath'), '/(?<=/).+?PLDAPS_vK2_MASTER', 'match', 'once')`, while the other settings files use `pwd`. The repository folder is `PLDAPS_vK2`, and Windows paths use `\`, so the match returns `''`. That makes `outputFolder`/`figureFolder` the relative paths `output` and `output/figures`. These resolve against the current directory, which the GUI sets to the repository root.
- **Effect on recorded data:** None expected while the current directory is the repository root. The saved `p.init.pldapsFolder` is empty.
- **Confidence:** Likely — depends on the path on the rig PC and on the current directory at save time

### T11. joystick_release_for_fix_dim: correct rejects end before the reward branch runs
- **Where:** `tasks/joystick_release_for_fix_dim/joystick_release_for_fix_dim_run.m` (`stateMachine`, `cr` state)
- **What happens:** The `cr` state sets `p.trVars.exitWhileLoop = true` unconditionally on entry, before its reward block. On that first pass, `timeNow - fixHoldReqMet` is about one loop iteration, which is less than `rewardDelay` (0.1 s by default), so no reward is triggered and the loop exits. cr trials get the high tone only. This matches the current wiki family page.
- **Effect on recorded data:** cr trials are unrewarded, with `timing.reward = -1`. This has been the case since the reward block was added on 2022-10-11 (`7b352ded`).
- **Confidence:** Likely — depends on loop iteration time staying below `rewardDelay`

### T12. joystick_release_for_fix_dim_settings_DEBUG.m lacks variables nextParams reads
- **Where:** `tasks/joystick_release_for_fix_dim/joystick_release_for_fix_dim_settings_DEBUG.m`, `supportFunctions/nextParams.m` (`trialTypeInfo`)
- **What happens:** `trialTypeInfo` reads `p.trVars.propChangeTrials` and `p.draw.clutIdx.expFixDim_subFixDim`. The main settings file defines both (0.8 and CLUT index 14). The DEBUG settings define neither: its CLUT index 14 is `expWhite20_subWhite20`. The first trial's `nextParams` therefore errors. The DEBUG file has not changed since 2023-05-25. `propChangeTrials` entered `nextParams` on 2022-10-11 (`7b352ded`).
- **Effect on recorded data:** None (behavior only)
- **Confidence:** Confirmed by reading code

### T13. joystick_release_for_fix_and_stim_dim: no-change rows pause in keyboard
- **Where:** `tasks/joystick_release_for_fix_and_stim_dim/supportFunctions/initTrialStructure.m` (`tableDef_fixAndStimDim_6040`, `_7030`, `_9010`), `supportFunctions/nextParams.m` (`trialTypeInfo`)
- **What happens:** In these tables the `orientation` column is 1 on every row, including no-change rows where `stim chg = 0`. The feature loop in `trialTypeInfo` then indexes `p.stim.orientArray(0, 2)`, which errors. The surrounding `try/catch` calls `keyboard`, so every no-change trial stops at the MATLAB prompt. The `_1000` table has no no-change rows and is unaffected.
- **Effect on recorded data:** None (behavior only). After `dbcont`, the remaining features in the loop (sat, lum, hue) are skipped for that trial. They are all 0 on no-change rows. The orientation flag was set on these rows on 2025-05-29 (`8bff0229`, "Fixed stim change + dim code").
- **Confidence:** Confirmed by reading code

**SRS family**

### T14. SRS_Task_Smooth target delay is a fixed 450 ms
- **Where:** `tasks/SRS_Task_Smooth/srsSmooth_settings.m`, `srsSmooth_run.m` (`targetDelay` state), `supportFunctions/sampleTargetDelayMs.m`
- **What happens:** The run waits `p.trVars.targetDelayDurationMs` (450 ms in `srsSmooth_settings.m`). Nothing assigns that value per trial: `sampleTargetDelayMs` is called only from `SELF_TEST_SRS_MORETRAINING_LOGIC.m`, and `delay_ms_min`/`delay_ms_max` are not read by task code. The settings comment says the delay is "sampled once per trial by nextParams". The comments in `srsSmooth_Moretraining_settings.m` and `srsClassic_Moretraining_settings.m` say "A new target-onset -> fixation-offset delay is drawn for every trial".
- **Effect on recorded data:** In all SRS_Task_Smooth settings since 2026-08-17 (`09e7d867`), the delay is 450 ms on every trial. The strobed `delta` (`p.status.delta`) is the constant 450. From 2026-07-30 (`62ddf889`) until that commit, `p.status.delta` was drawn from `unifrnd(delay_ms_min, delay_ms_max)` inside the run's `targetDelay` state.
- **Confidence:** Confirmed by reading code
- **Possible direction:** Call `sampleTargetDelayMs` in `nextParams` and copy the value to `p.status.delta`.

### T15. srsClassic_Moretraining_settings.m sets hueModeCode = 2 in classic mode (no effect)
- **Where:** `tasks/SRS_Task_Smooth/srsClassic_Moretraining_settings.m`
- **What happens:** The file sets `hueSamplingMode = 'classic'` with `hueModeCode = 2` ("smooth"). `nextParams` overwrites `p.trVars.hueModeCode` every trial: 1 for classic, 2 for smooth, NaN for salienceType 3. The setting has no effect. The file's header comment is copied from the smooth version ("SRSSMOOTH_MORETRAINING_SETTINGS Smooth-hue …").
- **Effect on recorded data:** None (behavior only)
- **Confidence:** Confirmed by reading code

### T16. SRS_mooving finish errors for salienceType 3 after the trial has run
- **Where:** `tasks/SRS_mooving/srsMoving_finish.m` (`prepareMovingTrialStrobes`)
- **What happens:** `prepareMovingTrialStrobes` handles salienceType 1 and 2. Any other value, including 3 (direct RGB), raises `SRS_mooving:InvalidSalienceTypeForStrobe`. The check runs in `_finish`, before `srsSmooth_finish` saves the trial, so the trial runs to completion and then errors. `salienceType` is inherited from `srsSmooth_settings.m`, where it is a GUI variable.
- **Effect on recorded data:** None (behavior only); the affected trial is not saved
- **Confidence:** Likely — depends on salienceType 3 being selected and getting through init and run

### T17. srsMoving_Moretraining_settings.m header says it matches srsSmooth_Moretraining but counts differ
- **Where:** `tasks/SRS_mooving/srsMoving_Moretraining_settings.m`
- **What happens:** The header says "Same current schedule parameters as srsSmooth_Moretraining_settings: 20 successful T1-only and 20 successful T2-only". The file sets `nSingleT1PerBlock = nSingleT2PerBlock = 20`, while `srsSmooth_Moretraining_settings.m` sets 25 and 25.
- **Effect on recorded data:** None (behavior only)
- **Confidence:** Confirmed by reading code

**sacc_to_phosph (WiP)**

### T18. makeSaccade compares trial time with a duration meant to start at fixation acquisition
- **Where:** `tasks/sacc_to_phosph (WiP)/sacc_to_phosph_run.m` (`makeSaccade` state), `supportFunctions/nextParams.m`
- **What happens:** `nextParams` sets `p.trVars.timeFixOffset = p.trVars.totalFixDur` (1.5 s). The settings comment describes this as "Total time from fixAcq to 'heldFix' state". `makeSaccade` tests `timeNow > p.trVars.timeFixOffset`, but `timeNow` counts from trial start, not from `fixAq`. `makeSaccade` begins at `fixAq + timeStimOnset` (0.3–1.3 s). If more than about 0.2–1.2 s passed between trial start and fixation acquisition, the trial goes to `heldFix` on the first `makeSaccade` iteration where the eye is still in the window.
- **Effect on recorded data:** Trial outcome (`trialEndState` heldFix vs. saccade) and the staircase/hit counts that use it. This applies to all sacc_to_phosph settings since 2026-05-19 (`d1e37fc4`, "retime to stimOn").
- **Confidence:** Likely — depends on time from trial start to fixation acquisition

### T19. pick_all_channels electrode warning condition is inverted
- **Where:** `tasks/sacc_to_phosph (WiP)/supportFunctions/nextParams.m` (top-level electrode check, `pick_all_channels` branch)
- **What happens:** The warning "Some chosen electrode(s) are not on good electrodes list!" fires when `all(ismember(stimList{...}(1,:), goodElectrodes))` is true, which is when every chosen electrode is on the good list. It does not fire when one is missing. The other two branches use `~any(...)`.
- **Effect on recorded data:** None (behavior only)
- **Confidence:** Confirmed by reading code

### T20. random_sample_table comments say 100/200/300 Hz but only phase width varies
- **Where:** `tasks/sacc_to_phosph (WiP)/supportFunctions/initTrialStructure.m` (`random_sample_table`)
- **What happens:** The three row groups are labelled "100 Hz", "200 Hz" and "300 Hz". `cmdPeriod` is 100 in every row (100 × 33.3 µs = 3.33 ms, about 300 Hz). Only `cmdSeqLength` changes (3/4/5), and `nextParams` uses it as the phase width (about 100/133/167 µs).
- **Effect on recorded data:** None (behavior only); the saved `cmd*` values are the ones delivered, but the comment labels do not describe them.
- **Confidence:** Confirmed by reading code

### T21. updateStatusVariables microstimTrials count omits trial type 7
- **Where:** `tasks/sacc_to_phosph (WiP)/supportFunctions/updateStatusVariables.m`
- **What happens:** `p.status.microstimTrials` counts `ismember(trialType, [2 4 5 6])`. The random_sample version uses type 7 for all its microstim trials, so this counter stays 0 there. Other type-7 counters in the same file do exist.
- **Effect on recorded data:** None (behavior only); only the status counter is affected
- **Confidence:** Confirmed by reading code

### T22. pick_one_channel table has a type-8 row that nextParams does not handle (0 repetitions)
- **Where:** `tasks/sacc_to_phosph (WiP)/supportFunctions/initTrialStructure.m` (`pick_one_channel_table`), `supportFunctions/nextParams.m` (`switch p.trVars.trialType`)
- **What happens:** The table includes a row `8 … 0 24008` (biomimetic microstim) with 0 repetitions. The `trialType` switch in `nextParams` has cases 1, {2,4,5,6,7} and 3 only. With 0 repetitions the row never enters the trials array.
- **Effect on recorded data:** None (behavior only)
- **Confidence:** Confirmed by reading code

**human_psychophysical_threshold**

### T23. drawMachine sends an Eyelink TRIAL_END message on every loop iteration
- **Where:** `tasks/human_psychophysical_threshold/human_psychophysical_threshold_run.m` (`drawMachine`)
- **What happens:** `Eyelink('Message', 'TRIAL_END')` is the second line of `drawMachine`, outside the frame-timing `if`, so it runs on every while-loop iteration. The real end-of-trial `TRIAL_END` in `stateMachine` is sent in addition.
- **Effect on recorded data:** EDF files from human_psychophysical_threshold sessions since 2023-04-03 (`49e0383b`) contain many TRIAL_END messages per trial. Parsing that uses TRIAL_END as the trial boundary needs to take the last one (or the one followed by StopRecording).
- **Confidence:** Confirmed by reading code

**scd / nfl**

### T24. scd and nfl initClut need p.init.pcName, which no scd/nfl settings define
- **Where:** `tasks/scd/supportFunctions/initClut.m`, `tasks/nfl/supportFunctions/initClut.m`
- **What happens:** Both build the LUT name as `['LUT_VPIXX_rig' p.init.pcName(end-1)]`. Neither task's settings set `p.init.pcName`, and no `+pds` or rig-config function sets it, so Initialize errors in `initClut`. Other tasks set it with `[~, p.init.pcName] = unix('hostname')`.
- **Effect on recorded data:** None (behavior only). The per-rig LUT name was introduced on 2026-05-05 (`6e8bd9c4`).
- **Confidence:** Confirmed by reading code

### T25. nfl generateStimuli reads p.stim.ctrstArray, but six settings name the feature 'cont'
- **Where:** `tasks/nfl/supportFunctions/generateStimuli.m`; settings `scd_settings_nfl.m`, `scd_settings_nflNoSgl.m`, `scd_settings_nflNoSgl_50.m`, `scd_settings_nflNoSgl_shortBlocks.m`, `scd_settings_nfl_eachChangeOnce.m`, `scd_settings_satIncNoSgl.m` (all in `tasks/nfl/`)
- **What happens:** `nextParams` creates `p.stim.<feature>Array` from `p.stim.featureValueNames`. In these six settings that list has `'cont'`, so `p.stim.contArray` is created and `ctrstArray` is not. `generateStimuli` uses `p.stim.ctrstArray(j,i)` and errors on a missing field. `scd_settings.m`, `scd_settings_satInc.m` and `scd_settings_fourStimTest.m` use `'ctrst'`. The trial-array column match also depends on this name: `'cont'` matches the `'contrast'` column, `'ctrst'` does not.
- **Effect on recorded data:** None (behavior only). `generateStimuli` has read `ctrstArray` since 2022-10-24 (`42a61337`). Currently T24 stops Initialize before this point is reached.
- **Confidence:** Confirmed by reading code

### T26. scd_run drawMachine prints stimOn every drawn frame
- **Where:** `tasks/scd/scd_run.m` (`drawMachine`)
- **What happens:** `disp(p.trData.timing.stimOn)` runs inside the "close to next flip" block, so it prints once per drawn frame, not on every loop iteration as first reported. It has been present since 2022-10-24 (`47f42cf2`). (The `tasks/nfl` copy of `scd_run.m` does not have this line.)
- **Effect on recorded data:** None (behavior only)
- **Confidence:** Confirmed by reading code

**tokens**

### T27. tokens_settings.m (tokens_main) lacks variables read by nextParams and tokens_run
- **Where:** `tasks/tokens/tokens_settings.m`, `supportFunctions/nextParams.m` (`trialTypeInfo`), `tokens_run.m` (`showOutcome` state)
- **What happens:** `trialTypeInfo` builds token positions from `p.trVars.tokenBaseX`, `tokenBaseY` and `tokenSpacing` for every exptType. Only `tokens_AV_settings.m` defines them, so the first trial errors under `tokens_settings.m`. `showOutcome` also tests `if p.trVars.isAVTrial` without an `isfield` guard. `isAVTrial` is assigned only when `exptType` is `'tokens_AV'`. Token positioning was added on 2025-08-13 (`b2261d33`), and the unguarded `isAVTrial` test the same day (`6b59c056`).
- **Effect on recorded data:** None (behavior only)
- **Confidence:** Confirmed by reading code

**rfMap**

### T28. sim_setup_population.m refers to a script that does not exist
- **Where:** `tasks/rfMap/sim_setup_population.m` (header usage notes)
- **What happens:** Step 3 says "run sim_evaluate_session.m". No file by that name exists in the repository or its git history. The closest match is `tasks/rfMap/_validation/evaluateSimSession.m`, a function that takes a session folder. The alternative given in the same note, `pdsActions.evaluateRFQuality`, does exist.
- **Effect on recorded data:** None (behavior only)
- **Confidence:** Confirmed by reading code

## Framework (+pds, GUI, rig configs)

### F1. Rig `baseReward` does not reach trials
- **Where:** `+pds/initRigConfigFile.m`; every task's `_next.m` (`p.trVars = p.trVarsGuiComm`)
- **What happens:** After running the rig config, `initRigConfigFile` sets `p.trVarsInit.rewardDurationMs` and `p.trVars.rewardDurationMs` to `p.rig.baseReward` (rig1 189, rig2 200). It runs from `_init`. By then the settings file has already done `p.trVarsGuiComm = p.trVarsInit`, and the GUI does not copy again. Each `_next` replaces `p.trVars` with `p.trVarsGuiComm`, so trials use the settings value (or the GUI-edited value). `trVarsInit` holds the rig value. No task copies `trVarsInit.rewardDurationMs` into `trVarsGuiComm`. In `conflict_task`, `initTrialStructure`, `updateTrialsList`, `extraWindowSetup` and `plotConflictTaskSession` read `p.trVarsInit.rewardDurationMs` (rig value) for printed and plotted reward values. Meanwhile `nextParams` computes delivered rewards from `p.trVars.rewardDurationMs` (settings value, 400).
- **Effect on recorded data:** Delivered and strobed reward durations match `p.trVars`, so they are internally consistent. The `trVarsInit.rewardDurationMs` saved in `p.mat` shows the rig value, which was not used. The `baseReward` block has been there since 2023-05-17 (9b069254).
- **Confidence:** Confirmed by reading code

### F2. gSac_jph and gSac_contrast overwrite `p.init.rigConfigFile` with rig1 every frame
- **Where:** `tasks/gSac_jph/gSac_jph_run.m` and `tasks/gSac_contrast/gSac_contrast_run.m` (`drawMachine`, after `Screen('Flip')`)
- **What happens:** Each flip runs `p.init.rigConfigFile = which('rigConfigFiles.rigConfig_rig1')`. The settings files choose rig1 or rig2 from the PC name, and that file is what `_init` loads. After the first frame, the field holds the rig1 path on any rig. A `which()` call runs on every flip.
- **Effect on recorded data:** On rigs other than rig1, `p.mat` (saved after trial 1) and each trial file's `init` record the rig1 config path. The rig config actually loaded is not changed. This has been the case since 2023-03-31 for gSac_jph (79954c4e) and since creation (2024-06-06 ac709aa8) for gSac_contrast.
- **Confidence:** Confirmed by reading code

### F3. GUI parameter menus include dotted names that cannot be used as field names
- **Where:** `PLDAPS_vK2_GUI.m` (`initializeButton_callback`, `ctrlParamPopUp_callback`, `ctrlParamEdit_callback`); `+pds/setStringListForGui.m`
- **What happens:** `setStringListForGui` lists one level of sub-struct fields as `'parent.child'` (e.g., `postFlip.logical`; 53 settings files define `trVarsInit.postFlip`). The GUI reads and writes `uiData.p.trVarsGuiComm.(name)`. With a dotted name, MATLAB raises an invalid-field-name error. This happens when such a name is chosen in a popup, or at Initialize if it is listed in `p.rig.guiVars` or lands in a default slot.
- **Effect on recorded data:** None (behavior only)
- **Confidence:** Confirmed by reading code

### F4. GUI Initialize errors on a `guiStatVals` name missing from `p.status`
- **Where:** `PLDAPS_vK2_GUI.m` (`initializeButton_callback`, status-value popups)
- **What happens:** `cellfun(@(x)find(strcmp(statusValueNames, x)), p.rig.guiStatVals)` uses uniform output. A name that is not in `p.status` makes `find` return empty, and `cellfun` errors. The comment that follows says unmatched or short lists were meant to be padded, but the padding covers only a short list.
- **Effect on recorded data:** None (behavior only)
- **Confidence:** Confirmed by reading code

### F5. `pdsActions.*` color-calibration actions listed by three tasks are not in `+pdsActions`
- **Where:** `tasks/gSac_4factors/gSac_4factors_settings.m`, `tasks/gSac_contrast/gSac_contrast_settings.m`, `tasks/conflict_task/conflict_task_settings.m` (`p.init.taskActions{6..8}`); `PLDAPS_vK2_GUI.m` (`userActionButton_callback`)
- **What happens:** These settings list `'pdsActions.dklToRgbFileMaker'`, `'pdsActions.i1CalibrateAndMeasure'` and `'pdsActions.i1Validate'`. `+pdsActions/` contains none of them. Copies exist in `tasks/gSac_4factors/actions/` and `tasks/gSac_contrast/actions/` (and in SRS_Task_Smooth and human_psychophysical_threshold), but `conflict_task` has no `actions/` folder. `which()` of the package-qualified name returns `''`, and the callback then evals `uiData.p = (uiData.p);`. Clicking the button does nothing and shows no message.
- **Effect on recorded data:** None (behavior only)
- **Confidence:** Likely — depends on MATLAB `which('pdsActions.X')` returning `''` when the package has no `X` (expected behavior)

### F6. `+pds/deliverReward`, `freeReward`, `deliverOptoStim`: schedule channel hard-coded
- **Where:** `+pds/deliverReward.m`, `+pds/freeReward.m`, `+pds/deliverOptoStim.m`
- **What happens:** `WriteDacBuffer` is given the configured channel (`p.rig.dp.dacChannelOut` or `p.rig.dp.optoDacChan`). The `SetDacSchedule` channel argument is a literal: 0 for reward and 1 for opto. Every current rig config sets `dacChannelOut = 0`, and every settings file sets `optoDacChan = 1`, so the two agree today. A different configured channel would not change which DAC is driven.
- **Effect on recorded data:** None (behavior only)
- **Confidence:** Confirmed by reading code

### F7. Rig config function/file name mismatches and missing rig configs
- **Where:** `+rigConfigFiles/`; `tasks/nfl/scd_settings.m`; `tasks/gSac/gSac_settings_trialsArray.m`
- **What happens:** Three rig config files declare a function name that differs from the file name. MATLAB calls the file by its file name, so this does not stop them from running.
  - `rigA_20200203.m` declares `rigConfig_rigF_20190328`.
  - `rigB_2019016_porter.m` and `rigB_20190316_porter.m` both declare `rigB_20190116_porter`.

  Two settings files reference rig configs that do not exist. `which()` returns `''`, and `pds.initRigConfigFile` stops `_init` with "failed to load a valid rigConfigFile".
  - `scd_settings.m` uses `which('rigConfig_rigB_20180802.m')`.
  - `gSac_settings_trialsArray.m` uses `which('rigConfig_rigB_20180712.m')`.
- **Effect on recorded data:** None (behavior only)
- **Confidence:** Confirmed by reading code

### F8. `+pds/state2num.m` looks up `p.init.codes` instead of `p.state`
- **Where:** `+pds/state2num.m`
- **What happens:** The help text describes mapping a state name to its state number (the inverse of `pds.num2state`, which uses `p.state`). The body returns `p.init.codes.(state{ii})` instead. Nothing in the repo calls it, apart from a copy under `+test/+pds/`.
- **Effect on recorded data:** None (behavior only)
- **Confidence:** Confirmed by reading code

### F9. `+pds/regenerateStim_mcd.m`: `dips(` typo
- **Where:** `+pds/regenerateStim_mcd.m` (seed-mismatch `else` branch)
- **What happens:** The branch calls `dips('THIS IS BIG NO NO')`. If the branch is reached, this raises an undefined-function error before the empty `stim` is returned. Nothing in the repo calls the function, apart from a copy under `+test/+pds/`.
- **Effect on recorded data:** None (behavior only)
- **Confidence:** Confirmed by reading code

## Documentation out of date

### D1. rfMap data dictionary lists 16160–16175 as reserved
- **Where:** `data_dictionaries/rfMap_data_dictionary.md` (strobe code table)
- **What happens:** The table lists 16160–16175 as "Reserved for future per-stim-type params". `+pds/initCodes.m` now defines `rfMapNoiseCycleCount` = 16160 (added 2026-05-13, 82929c3b) and `rfMapStimHemifield` = 16161 (added 2026-06-03, 7b095e95). Both are used by `tasks/rfMap/rfMap_commonSettings.m` and `supportFunctions/nextParams.m`.
- **Effect on recorded data:** None (docs only)
- **Confidence:** Confirmed by reading code

### D2. gSac_4factors `imageIdx`/`imageId` (6660) not documented
- **Where:** `data_dictionaries/4factors_data_dictionary.md`; `analysisPlanningDocs/gSac_4factors_task_description.md` (§9 strobe summary); `tasks/gSac_4factors/gSac_4factors_task_design_specification.md`
- **What happens:** e48934be (2026-10-15) added `p.trVars.imageIdx` (row in images.mat; 0 = bullseye) and a strobeList row `'imageId'` (code 6660, defined since the initial commit). None of the three documents mentions `imageIdx`, `imageId` or 6660. The §9 list of end-of-trial pairs ends at `targetColor`.
- **Effect on recorded data:** None (docs only)
- **Confidence:** Confirmed by reading code

### D3. Barsweep geometry report says the fix is not applied
- **Where:** `analysisPlanningDocs/barsweep_geometry_discrepancy_report.md` (header Status line)
- **What happens:** The report reads "Status: confirmed, root cause identified, fix not yet applied". The fix was committed on 2026-08-17 (cb4170fd, "barsweep: fix sweep geometry (deg2pix misused on a length)").
- **Effect on recorded data:** None (docs only)
- **Confidence:** Confirmed by reading code

### D4. rfMap SIM_MODE_PLAN says not implemented
- **Where:** `tasks/rfMap/_validation/SIM_MODE_PLAN.md` (header)
- **What happens:** The header reads "Status: planned, not implemented". The simulation mode was added on 2026-05-20 (13b37f44, "rfMap: add LNP simulation-mode validation harness"), gated by `p.trVarsInit.useSimulatedSpikes`.
- **Effect on recorded data:** None (docs only)
- **Confidence:** Confirmed by reading code

## Resolved

_None yet._ Format: `- [YYYY-MM-DD] <ID> <title> — fixed in <commit> (<one line>)`.
