---
title: Joystick task family
type: family
category: Tasks — joystick family
summary: Training lineage from "press and hold the joystick" to the cued orientation-change attention task, with a per-step "differs from parent" table
status: active
sources:
  - tasks/joystickPress/joystickPress_settings.m @ 5e91bb852d
  - tasks/joystickPress/joystickPress_run.m @ 2315e232a5
  - tasks/joystickPress_playMovie/joystickPress_settings.m @ a729d073e7
  - tasks/joystickPress_playMovie/joystickPress_run.m @ 2ab72a0581
  - tasks/joystick_press_and_fixate/joystick_press_and_fixate_settings.m @ fba5499ca0
  - tasks/joystick_press_and_fixate/joystick_press_and_fixate_run.m @ 7331a114ed
  - tasks/joystick_release_for_fix_off/joystick_release_for_fix_off_settings.m @ 2984776ffb
  - tasks/joystick_release_for_fix_off/joystick_release_for_fix_off_run.m @ 12082c4d2b
  - tasks/joystick_release_for_fix_dim/joystick_release_for_fix_dim_settings.m @ 2a89b9733b
  - tasks/joystick_release_for_fix_dim/joystick_release_for_fix_dim_run.m @ 635c3716d7
  - tasks/joystick_release_for_fix_and_stim_dim/joystick_release_for_fix_and_stim_dim_settings_1000.m @ 4aac405d99
  - tasks/joystick_release_for_fix_and_stim_dim/joystick_release_for_fix_and_stim_dim_run.m @ e1dc54cf08
  - tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_orient_change_and_dim_settings_6040.m @ d03d35a9c2
  - tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_stim_change_and_dim_run.m @ ebd1fcdcad
verified_at: e48934be
updated: 2026-10-15
---

# Joystick task family

Seven task directories form a training sequence. Each step adds one requirement to the one
before it: first press and hold a joystick, then also fixate, then release the joystick
when the fixation point disappears, then when it dims, then when a peripheral stimulus
dims, and finally when a peripheral stimulus changes orientation at a cued location. The
last step, [joystick_release_for_stim_change_and_dim](joystick_release_for_stim_change_and_dim.md),
is the covert-attention task used with recordings. Git history calls it the "attention task".

All seven come from the same template as [scd](scd.md). The settings header of
`joystickPress_settings.m` still reads `"scd" - stimulus change detection`, and every
directory carries copies of scd's support functions (`generateStimuli`, `initClut`,
`initTrialStructure`, `getQuestSuggestedDelta`, …); all but the attention task also keep a
local `supportFunctions/initCodes.m`. Many of these
copies go unused in the early steps. The local `supportFunctions/initCodes.m` files are
never called, because every `_init.m` loads codes with `p.init.codes = pds.initCodes`
(see [strobe codes](../concepts/strobe-codes.md)).

## Tasks

| Task | Subject must… | Status |
|---|---|---|
| [joystickPress](joystickPress.md) | press and hold the joystick for `joyPressReq` s | legacy |
| [joystickPress_playMovie](joystickPress_playMovie.md) | the same, while a movie plays; adds Ripple, PSTH and opto-sham hooks | active |
| [joystick_press_and_fixate](joystick_press_and_fixate.md) | hold the joystick, then fixate a jittered point for `fixDurReq` s | legacy |
| [joystick_release_for_fix_off](joystick_release_for_fix_off.md) | on some trials, release the joystick after the fixation point turns off | legacy |
| [joystick_release_for_fix_dim](joystick_release_for_fix_dim.md) | release when the fixation point dims (change trials), keep holding otherwise | legacy |
| [joystick_release_for_fix_and_stim_dim](joystick_release_for_fix_and_stim_dim.md) | release when a peripheral patch dims, with or without the fixation point dimming too | legacy |
| [joystick_release_for_stim_change_and_dim](joystick_release_for_stim_change_and_dim.md) | release when a peripheral patch changes orientation, using a spatial cue | active |

## Differs from parent

Each row compares the task to the row above it. The parent of `joystickPress_playMovie`
is `joystickPress`. The parent of `joystick_press_and_fixate` is also `joystickPress`.

| Task | Differs from parent |
|---|---|
| joystickPress | Root. The states are `waitForJoy` → `holdJoy` → `hit` (reward plus high tone), and releasing early ends in `miss`. Nothing is drawn for the subject; only the experimenter's grid, gaze dot and joystick bar appear. `joyPressReq` is drawn uniformly from [`joyPressReqMin`, `joyPressReqMax`] (`nextParams`). |
| joystickPress_playMovie | The quintet files keep the `joystickPress_*` names. A movie picked at random from `p.draw.movie.movieDir` plays behind the trial (`movieInit`, `Screen('PlayMovie')` in `_next`, and the movie resumes where it stopped on the previous trial). Adds `pds.initRipple`, `alignSpikes`/`PSTH_plotter`, online gaze velocity (`onlineGazeCalcs`), and opto/sham-opto timing while the joystick is held (`isOptoStimTrial = rand > 0.5`). Defaults: hold 3–6 s, `passJoy = 1`, PC audio playback on. |
| joystick_press_and_fixate | The `holdJoy` state becomes `showFix`. After the press, a fixation point appears in one of three random colours (white, cyan or green), with its position jittered by `fixLocRandX/Y`. The subject must acquire fixation within `fixWaitDur` and hold it for `fixDurReq` (`dontMove`). Reward follows `rewardDelay` after the hold is met. Releasing the joystick gives `joyBreak`, and looking away gives `fixBreak`. |
| joystick_release_for_fix_off | On a fraction `propRelTrials` of trials (`isRelOnFixOffTrial`), the fixation point turns off when the hold is met without a tone, and the subject must release within `maxJoyRelLatency` (`makeDecision`). Otherwise that trial is a `miss`. On the other trials, the tone and reward come at fixation offset, as in the parent. |
| joystick_release_for_fix_dim | Fixation offset becomes **dimming**. `isChangeTrial = rand < propChangeTrials`. On change trials, the fixation point is redrawn in CLUT slot `expFixDim_subFixDim`, which `nextParams` sets each trial to `bg + dimVal·(white − bg)`, with `dimVal` drawn from `low/mid/highDimVal`. Release in [`joyMinLatency`, `joyMaxLatency`] gives `hit`. Earlier releases give `fa` (noise tone). Holding through a no-change trial gives `cr` (high tone). `p.trData.dimVal` and `timing.reactionTime` are saved. |
| joystick_release_for_fix_and_stim_dim | Adds peripheral checkerboard patches (`generateStimuli`) and a trials array (`initTrialStructure`, chosen by `exptType`; the settings files `_1000/_6040/_7030/_9010` differ only in `exptType`, which sets the change:no-change ratio). On change trials, the patch at `stim chg` dims (`lumDelta`), and with probability 1−`propPeriphDimOnly` the fixation point dims too (`isStimDimOnlyTrial`). |
| joystick_release_for_stim_change_and_dim | The change becomes an orientation step (`orientDelta`) at one of four patch locations. In all current settings files `lumDelta = 0`, so the change is orientation only. A cue ring marks the likely change location (`cueOn`/`cueOff`). Single- and multi-patch trials, uncued changes, block-wise free rewards, Ripple/PSTH, opto (trial codes 24xxx), QUEST and fixed-delta psychometric variants are all added. The change time is drawn within `stim2ChgIntvl + chgWinDur·rand` after stimulus onset, and no-change trials get a matched "pseudo-change" time (`noChg`). |

## Shared conventions

- **States.** All seven use the same `p.state` numbering: transition states 1–5, aborts
  11–13 and outcomes 21–25 (see [run loop](../concepts/run-loop-state-machine.md)). Some
  tasks rename state 3 (`holdJoy` vs `showFix`). `_finish` sets
  `trialRepeatFlag = 10 < trialEndState < 20`.
- **strobeList.** Each settings file builds it as `fliplr({expression, codeName; …})`. The first six tasks strobe only
  `date_1yyyy`, `date_1mmdd` and `time_1hhmm`. The attention task strobes more (see its page).
  Behavioural events are strobed from the state machine with `p.init.strb.strobeNow`.
  Visual onsets are queued with `addValueOnce` and timed after the flip
  ([postFlip](../concepts/drawing-and-postflip.md)).
- **Feedback.** `playTone(p, 'high' | 'low' | 'noise')` plays a high tone on hit (and
  on cr in fix_dim and fix_and_stim_dim), a low tone on miss/abort and noise on fa. `postTrialTimeOut` adds outcome-specific
  timeouts (`timeoutAfterFa`, `timeoutAfterMiss`, …).
- **Output.** `pds.saveP` writes the trial files
  ([data saving](../concepts/data-saving.md)). `_finish` calls
  `pds.waitForJoystickRelease` before the next trial in every task except the attention task.
- Each directory has a copy of `actions/summarizeBehaviorBasic.m` with its plotting
  helpers. `p.init.taskActions` lists only `pdsActions.*` entries.

## Related

- [scd](scd.md) / [family-scd](family-scd.md) — the template these tasks were copied from.
- Concepts: [eye and joystick](../concepts/eye-and-joystick.md),
  [reward](../concepts/reward.md), [trial structure](../concepts/trial-structure.md),
  [colour and CLUT](../concepts/color-and-calibration.md),
  [ephys integration](../concepts/ephys-integration.md).
