---
title: joystick_release_for_stim_change_and_dim
type: task
category: Tasks — joystick family
summary: Cued covert-attention change detection ("attention task") — hold joystick and fixation, release when a peripheral checkerboard patch changes orientation; learning, opto, QUEST and psychometric variants
status: active
task_dir: tasks/joystick_release_for_stim_change_and_dim/
sources:
  - tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_orient_change_and_dim_settings_6040.m @ d03d35a9c2
  - tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_orient_change_and_dim_settings_7030.m @ c46c241f96
  - tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_orient_change_and_dim_settings_9010.m @ 3fa6a12bc5
  - tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_orient_change_and_dim_learn_cue_settings.m @ f07cfcaed5
  - tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_orient_change_and_dim_learn_chg_settings.m @ 62b8c7b22b
  - tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_orient_change_and_dim_opto_settings.m @ e381730914
  - tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_orient_change_and_dim_psycho_settings.m @ 8d1467d525
  - tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_orient_change_and_dim_Quest_settings.m @ 6209965bc2
  - tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_stim_change_and_dim_init.m @ 71f6625c73
  - tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_stim_change_and_dim_next.m @ 0029e75977
  - tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_stim_change_and_dim_run.m @ ebd1fcdcad
  - tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_stim_change_and_dim_finish.m @ 34b124e267
  - tasks/joystick_release_for_stim_change_and_dim/supportFunctions/initTrialStructure.m @ 19a34084fa
  - tasks/joystick_release_for_stim_change_and_dim/supportFunctions/nextParams.m @ 965006cfcd
  - tasks/joystick_release_for_stim_change_and_dim/supportFunctions/defineVisuals.m @ 39c928d621
  - tasks/joystick_release_for_stim_change_and_dim/supportFunctions/updateTrialsList.m @ 8a9220550d
  - tasks/joystick_release_for_stim_change_and_dim/supportFunctions/postTrialTimeOut.m @ acd7643341
  - tasks/joystick_release_for_stim_change_and_dim/supportFunctions/getQuestSuggestedDelta.m @ 98a2196495
  - tasks/joystick_release_for_stim_change_and_dim/supportFunctions/updateQuest.m @ 20dc33fa58
  - tasks/joystick_release_for_stim_change_and_dim/supportFunctions/alignSpikes.m @ a6df427ac1
  - tasks/joystick_release_for_stim_change_and_dim/extractCueInfo.m @ 516057dd55
  - tasks/joystick_release_for_stim_change_and_dim/otherSettingsFiles/ @ 6ec878eecb
  - data_dictionaries/joystick_release_for_stim_change_and_dim_data_dictionary.md @ c4dcdb6937
  - analysisPlanningDocs/joystick_release_for_stim_change_and_dim_analysis_planning.md @ b62b078d2a
verified_at: e48934be
updated: 2026-10-15
---

# joystick_release_for_stim_change_and_dim

This is the final stage of the [joystick family](family-joystick.md). Git history calls it
the "attention task". The subject holds a joystick and fixates. One, two or four dynamic
checkerboard patches (`generateStimuli`, shared with [scd](scd.md)) appear at locations
spaced 90° apart at `stimLoc1Ecc`. After a random delay, one patch may change
**orientation** by `orientDelta`, and the subject must release the joystick within
[`joyMinLatency`, `joyMaxLatency`] of the change. On no-change trials the subject keeps
holding through a matched "pseudo-change" time and is rewarded for doing so (correct
reject). In most variants a **cue ring** marks the likely change location before the
patches appear. On multi-patch trials, the coloured fraction of the ring equals the cue
validity (see below). The task measures detection and reaction time as a function of cue
validity, number of patches and change size. With Ripple, it also records neuronal
responses to the cue, stimulus, change and reward.

The task name says "change and dim", but `lumDelta = 0` in every current settings file, so
the patches change only in orientation. Luminance is still a column in the trials array and
can be turned on through `lumDelta`, which is a GUI variable in the 6040/7030/9010, learn_chg and psycho files.
The [data dictionary](../../data_dictionaries/joystick_release_for_stim_change_and_dim_data_dictionary.md)
and the
[analysis plan](../../analysisPlanningDocs/joystick_release_for_stim_change_and_dim_analysis_planning.md)
describe saved fields and analysis targets, focusing on the `learn_cue` variant.

## Trial flow

All times in `dontMove` are measured from `fixAq`. The generated block lists the states.

1. `waitForJoy` → `showFix`: a press strobes `joyPress`. The white fixation point appears
   (`fixOn` timed by postFlip). Fixation must be acquired within `fixWaitDur` with the
   joystick held, which strobes `fixAq`.
2. `dontMove`:
   - At `fix2CueIntvl` the cue ring comes on (`cueOn`) and turns off `cueDur` later
     (`cueOff`). With `cueDur = 0`, `cueIsOn` stays false and no ring is drawn.
   - At `fix2StimOnIntvl = fix2CueIntvl + cueDur + cue2StimIntvl` the patches come on
     (`stimOn`).
   - Variants with `optoStimDurSec` (learn_cue, opto, Quest): at `fix2StimOnIntvl + 0.25`
     the run calls `pds.deliverOptoStim` on opto trials. Otherwise it logs and strobes
     `optoStimSham`.
   - At `stimChangeTime` the trial goes to `makeDecision`. On change trials it queues
     `stimChange` and times `stimChg` after the flip. On no-change trials it does the same
     with `noChange` / `noChg`. The patch frames switch to epoch 2 on that frame.
   - A fixation break gives `fixBreak`. A release gives `fa` if the patches have been on
     longer than `joyMinLatency`, and `joyBreak` otherwise.
3. `makeDecision`: a release between `stimChangeTime + joyMinLatency` and
   `joyMaxLatencyAfterChange` on a change trial gives `hit` (high tone). An earlier
   release, or any release on a no-change trial, gives `fa` (noise tone). Holding past
   `joyMaxLatencyAfterChange` gives `miss` (low tone) or `cr`.
4. `hit`: reward at `hitRwdTime = stimChangeTime + rewardDelay`. `cr`: reward on entry.
   Each trial ends `postRewardDuration` (uniform in [`postRewardDurMin`,
   `postRewardDurMax`] = 1–1.2 s) after the reward.

`timing.reactionTime = joyRelease − stimChangeTime` is recorded on every release.
`postTrialTimeOut` applies `timeoutAfterFa` / `timeoutAfterFixBreak`. A miss at an
**uncued** location gets no timeout. Unlike the earlier steps, `_finish` does not wait for
joystick release. Instead it waits until the reward schedule plus `postRewardDuration`
has elapsed, then delivers a block-scheduled free reward if one applies.

<!-- GEN:facts:start -->
<!-- Generated by wiki/_tools/wiki_gen.py facts. Do not edit by hand. -->

### Generated facts

- **Directory:** `tasks/joystick_release_for_stim_change_and_dim/` — last commit touching it: 2026-07-15 6bcbb2cf
- **Quintet files:** `joystick_release_for_stim_change_and_dim_finish.m`, `joystick_release_for_stim_change_and_dim_init.m`, `joystick_release_for_stim_change_and_dim_next.m`, `joystick_release_for_stim_change_and_dim_run.m`
- **Settings files (8):** `joystick_release_for_orient_change_and_dim_Quest_settings.m` (primary), `joystick_release_for_orient_change_and_dim_learn_chg_settings.m`, `joystick_release_for_orient_change_and_dim_learn_cue_settings.m`, `joystick_release_for_orient_change_and_dim_opto_settings.m`, `joystick_release_for_orient_change_and_dim_psycho_settings.m`, `joystick_release_for_orient_change_and_dim_settings_6040.m`, `joystick_release_for_orient_change_and_dim_settings_7030.m`, `joystick_release_for_orient_change_and_dim_settings_9010.m`
- **Subfolders:** `supportFunctions/` (24 .m files), `actions/` (6 .m files); other: `otherSettingsFiles/`
- **Unique task code:** `uniqueTaskCode_scd`
- **States** (`p.state`, from `joystick_release_for_orient_change_and_dim_Quest_settings.m`): `trialBegun`=1, `waitForJoy`=2, `showFix`=3, `dontMove`=4, `makeDecision`=5, `fixBreak`=11, `joyBreak`=12, `nonStart`=13, `hit`=21, `cr`=22, `miss`=23, `foilFa`=24, `fa`=25

**strobeList** (from `joystick_release_for_orient_change_and_dim_Quest_settings.m`; strobed each trial by `pds.strobeTrialData`):

| code name | value expression |
|---|---|
| `date_1yyyy` | `p.init.date_1yyyy` |
| `date_1mmdd` | `p.init.date_1mmdd` |
| `time_1hhmm` | `p.init.time_1hhmm` |
| `taskCode` | `p.init.codes.uniqueTaskCode_scd` |
| `stimLoc1Elev` | `p.trVars.stimLoc1Elev` |
| `stimLoc1Ecc` | `p.trVars.stimLoc1Ecc` |
| `cueLoc` | `p.stim.cueLoc` |
| `chgLoc` | `p.stim.stimChgIdx` |
| `rewardDuration` | `p.trVars.rewardDurationMs` |
| `trialCount` | `p.status.iTrial` |
| `goodTrialCount` | `p.status.iGoodTrial` |
| `trialCode` | `p.init.trialsArray(p.trVars.currentTrialsArrayRow, strcmp(p.init.trialArrayColumnNames, 'trialCode'))` |
| `trialSeed` | `p.trVars.trialSeed` |
| `stimSeed` | `p.trVars.stimSeed` |
| `optoStimTrial` | `p.trVars.isOptoStimTrial` |

- `joystick_release_for_orient_change_and_dim_learn_chg_settings.m` strobeList differs: lacks `optoStimTrial`

- `joystick_release_for_orient_change_and_dim_psycho_settings.m` strobeList differs: lacks `optoStimTrial`

- `joystick_release_for_orient_change_and_dim_settings_6040.m` strobeList differs: lacks `optoStimTrial`

- `joystick_release_for_orient_change_and_dim_settings_7030.m` strobeList differs: lacks `optoStimTrial`

- `joystick_release_for_orient_change_and_dim_settings_9010.m` strobeList differs: lacks `optoStimTrial`

<!-- GEN:facts:end -->

## Conditions / trial structure

`initTrialStructure` selects a table by `p.init.exptType`. It uses the same 19 columns as
[fix_and_stim_dim](joystick_release_for_fix_and_stim_dim.md): `cue loc`, `n stim`,
`stim1..4 on`, `stim chg` (0 = no change), seven feature flags, `primary`,
`no of trials`, `trialCode`, `trial seed`, `stim seed`. One block is the expanded table.
`chooseRow` works through cue location 1 → 2 → 3 → 4 first, and within each location
single-patch → multi-patch rows, picking at random among the remaining rows.
`updateTrialsList` marks completed rows. Aborted trials (end state 11–19) stay in the pool.
When the pool is empty a new block is generated with fresh seeds.

`nextParams` derives the rest:
- `isStimChangeTrial = (stim chg ≠ 0)`.
- `isOptoStimTrial = (thousands digit of trialCode == 4)`, i.e. trial codes 24xxx.
- Orientation start values are randomised (`orientInit = randi(360)`) and offset by 45°
  per patch. Hue is offset by 90° per patch. Both are rotated by `primary`.
- `orientDelta` is added to the changing patch's epoch-2 value. In Quest it is replaced by
  the QUEST value, and in psycho by a per-row value.
- Timing: `fix2CueIntvl = fix2CueIntvlMin + fix2CueIntvlWin·rand` (and likewise
  `cue2StimIntvl`). `stimChangeTime = fix2StimOnIntvl + stim2ChgIntvl + chgWinDur·rand`.
  `fix2StimOffIntvl` is `stimChangeTime + joyMaxLatency` on change trials and a random
  `corrRejRwdTime` later in the window on no-change trials; `stimOff` is logged at trial end
  once that time has passed.
- Cue ring: drawn around the cued patch. On single-patch trials it is a full ring. On
  multi-patch trials, `p.draw.cueArcProp` = (multi-patch changes at the cued location) /
  (all multi-patch changes) in the block. That fraction of the ring is coloured, and the
  rest is grey, facing the fixation point (`defineVisuals`).

### Settings variants (top-level files)

| Settings file (`joystick_release_for_orient_change_and_dim_…`) | `exptType` suffix | Table design (per cue location) | Timing / other differences |
|---|---|---|---|
| `settings_6040.m` | `_6040` | 2 patches (1+3 or 2+4), change always at the cued patch, 6 change : 3 no-change | `cueDur = 0` (no ring), fixed onsets, `stim2ChgIntvl` 1 s, `chgWinDur` 3 s, `rewardDelay` 1 s, `orientDelta` 45, `lumInit −0.8`, `ctrstInit 0.175` |
| `settings_7030.m` | `_7030` | 2 patches, cued change 7 : 3 no-change (7 : 7 at cue location 4) | as 6040 but `chgWinDur` 2 s, `orientVar` 8, `lumInit 0.3`, `ctrstInit 0.375` |
| `settings_9010.m` | `_9010` | 4 patches, cued change 9 : 3 no-change | as 7030 |
| `learn_cue_settings.m` | `_learn_cue_multi` | cue at 1 or 3; single: cued change 9, lone patch elsewhere (no change) 2×3; four patches: cued change 24, uncued change 2×3, no change 15 | randomised cue/stim onsets (0.25 + 0.25·rand s each), `cueDur` 0.3, `chgWinDur` 2.5, reward 400 ms, free rewards available (`freeRewardProbability` 0.1, gated by `freeRewardFlag`), opto variables, strobes `optoStimTrial` |
| `learn_chg_settings.m` | `_learn_chg` | change trials only; cue at 1 or 3, single and four-patch rows across all four `primary` values, change always at cue | `orientDelta` 20, `cueDur` 0.25, reward 350 ms |
| `opto_settings.m` | `_opto` | all four cue locations; single: cued change 7, lone patch elsewhere 1×3; four patches: cued change 12, uncued change 1×3, no change 5; every row duplicated with codes 23xxx (no opto) and 24xxx (opto) | `optoStimDurSec` 0.5, `optoPulseAmpVolts` 3.5, `p.rig.dp.optoDacChan`; `timing.optoStim` / `optoStimSham` |
| `Quest_settings.m` | `_quest` | single patch only; cued change 16, lone patch elsewhere 2×3 | `useQuest = true`; `p.init.quest.*` (tGuess 35°, pThreshold 0.75, min 1°, max 90°) |
| `psycho_settings.m` | `_psycho` | single patch at the cued location, 40 change : 5 no-change | `orientDelta` set per row from a fixed schedule (15°×4, 20°×6, 25°×10, 30°×10, 35°×6, 40°×4, 0°×5); `stim2ChgIntvl` 0.5, `chgWinDur` 1.5 |

**QUEST.** `getQuestSuggestedDelta` creates the QUEST object on first use. On change trials
it proposes `QuestQuantile`, or `maxVal` on 10% of trials, and the value is clipped to
[`minVal`, `maxVal`]. `updateQuest` updates the object after each trial, re-estimates beta
every 10 trials, and adjusts gamma/delta from no-change false alarms and max-value trials.
`p.status.questThreshEst` holds the running estimate.

**otherSettingsFiles/** holds older and test settings files: hue-change `6040/7030/9010` (`exptType …_hue_change_*`), the
1-to-4-patch training steps (`1to4_train` = step 1, `1to4_step2`, `1to4_step2_allChg`),
`1stim_allChg`, `6040_SINGLE` (single location) and two `TEST` files. Each `exptType` has
a matching case in `initTrialStructure`, except `…_feature_change_TEST`, which falls
through to `tableDefault`.

## Data & strobes

- Saved per trial (see the data dictionary): `trVars` (trial type flags, cue/change
  location, timing intervals, `stimChangeTime`), `trData.timing` (`fixAq`, `cueOn/Off`,
  `stimOn/Off`, `stimChg`/`noChg`, `joyRelease`, `reactionTime`, `reward`, `freeReward`,
  and opto times), `trData.trialEndState`, `trData.dimVal` (1 = change trial, 0 =
  no-change), `p.stim.*Array`, and Ripple `spikeTimes` / `spikeClusters` / `eventTimes` /
  `eventValues`.
- **strobeList** (built as `fliplr({expression, codeName; …})`): `date_1yyyy`,
  `date_1mmdd`, `time_1hhmm`, `taskCode` (`uniqueTaskCode_scd`), `stimLoc1Elev`,
  `stimLoc1Ecc`, `cueLoc`, `chgLoc` (= `p.stim.stimChgIdx`), `rewardDuration`,
  `trialCount`, `goodTrialCount`, `trialCode` (the trials-array column), `trialSeed`,
  `stimSeed`. learn_cue, opto and Quest also strobe `optoStimTrial`.
- Event strobes from the run: `trialBegin`, `joyPress`, `fixOn`, `fixAq`, `cueOn`, `cueOff`,
  `stimOn`, `stimChange` / `noChange`, `fixBreak`, `joyRelease`, `stimOff`, `trialEnd`,
  `optoStimSham`. Elsewhere: tone codes (`playTone`), `reward` (`pds.deliverReward`),
  `optoStimOn` (`pds.deliverOptoStim`), and `freeReward` / `noFreeReward` (`_finish`). The
  state machine does not strobe outcome codes (`hit`, `miss`, `fa`, `cr`). The outcome is
  in the saved `trialEndState`.
- The `trialCode` column identifies the condition. Opto tables encode cue location,
  single vs multi and change location in the last digits, and opto on/off in the
  thousands digit (23xxx vs 24xxx).

## Analysis helpers and online plots

- `extractCueInfo.m` takes one loaded `trialXXXX.mat` and returns the cue index, change
  index, cued/uncued/no-change flags and the cue and patch coordinates.
- `PSTH_plotter.mlapp` / `psthComponent.mlapp`: `alignSpikes` (called from `_finish`)
  creates the app on the first trial and adds spikes aligned to strobed events.
- `plotWindowSetup` / `updateOnlinePlots` open performance, confusion-matrix (change vs
  no-change false alarms) and cued-vs-uncued hit-rate windows
  ([online plotting](../concepts/online-plotting.md)). The code for a psychometric window
  is still there, but its update block is disabled (`contains(exptType, 'psycho') && false`).

## Session practice & decisions

Nothing has been recorded beyond what the code shows. The data dictionary documents the
`learn_cue` variant as its reference configuration.

## Data/strobe change history

- 2026-04-28 — 61d7a932 — behavioural state-machine events strobed immediately with `strobeNow`.
- 2025-08-04 — 8adb9586 — learn_cue_multi table: more single-patch no-change rows, uncued-change rows at every uncued location, 15 multi-patch no-change rows.
- 2025-08-01 — e99c4b41 — psycho variant: per-row `orientDelta` schedule built in `initTrialStructure` and read in `nextParams`.
- 2025-06-06 — d9bf98cc — QUEST variant added (`Quest_settings`, `tableDef_singleStim_Quest`, `getQuestSuggestedDelta`, `updateQuest`); `optoStimTrial` strobe in Quest.
- 2024-12-19 — 11c787b4 — PSTH plotter app and `alignSpikes`.
- 2024-12-18 — 333a6f44 — opto variant: opto table with 24xxx codes, `isOptoStimTrial` from trialCode, `optoStim` / `optoStimSham` timing, `optoStimTrial` strobed.
- 2024-08-07 — af77b01e — cue and stimulus onset times randomised (`fix2CueIntvlMin/Win`, `cue2StimIntvlMin/Win`); `freeRewardFlag` added.
- 2024-07-30 — 30a8d201 — learn_cue_multi: uncued change trials on multi-patch trials; trial codes revised.
- 2024-05-15 — bcf9dcb9 — learn_chg variant added (learn_cue without no-change trials).
- 2024-05-13 — aca0caf7 — learn_cue training variant added.
- 2024-04-11 — b6904e86 — `p.status.changeDelta` stores each trial's change magnitude.
- 2024-02-27 — 2ea0fc49 — psychometric (psycho) variant added.

## Related

- [Joystick family](family-joystick.md). The previous step is
  [joystick_release_for_fix_and_stim_dim](joystick_release_for_fix_and_stim_dim.md).
  The stimulus and trial-array code comes from [scd](scd.md).
- Concepts: [trial structure](../concepts/trial-structure.md),
  [strobe codes](../concepts/strobe-codes.md),
  [postFlip](../concepts/drawing-and-postflip.md),
  [ephys integration](../concepts/ephys-integration.md),
  [reward](../concepts/reward.md).
- Docs: [data dictionary](../../data_dictionaries/joystick_release_for_stim_change_and_dim_data_dictionary.md),
  [analysis plan](../../analysisPlanningDocs/joystick_release_for_stim_change_and_dim_analysis_planning.md),
  [docs catalog](../docs-catalog.md).
