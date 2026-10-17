# srsClassic_Moretraining Saved Data Dictionary

Reference for the behavioral data written by PLDAPS_vK2 for the SRS
(Salience–Reward–Saccade) task, variant `srsClassic_Moretraining`, and for
aligning that data to neural recordings made on a Ripple Neuro system.

---

## 0. Scope and provenance

**Task variant.** `tasks/SRS_Task_Smooth/srsClassic_Moretraining_settings.m`.
This settings file is a thin override on top of `srsSmooth_settings.m`; the
other four members of the quintet (`srsSmooth_init/next/run/finish.m`) are
shared with every other `srsSmooth_*` variant. Everything below describes the
task **as configured by `srsClassic_Moretraining_settings.m`** — i.e.
`salienceType = 1` (DKL hue contrast) with `hueSamplingMode = 'classic'`, and
single-target instruction training enabled.

**Sessions this document was written for.**

| Session | Task variant | Notes |
|---|---|---|
| `20260819_t1440_srsClassic_Moretraining` | srsClassic_Moretraining | 342 saved trial files |
| Session recorded 2026-08-20 | srsClassic_Moretraining | Same variant; adds the `rewardScale` parameter (see §4.3) |

**Source of truth.** `pds.saveP` writes a zip archive of the entire task
folder into every session folder (`srsSmooth.zip`) on trial 1. This document
was written against the archive extracted from
`20260819_t1440_srsClassic_Moretraining/srsSmooth.zip`, which is the code that
actually executed that day — not the current working tree. The two differ in
exactly one respect (reward scaling, §4.3); everything else is byte-identical.

**Verification status.** Field names, values and control flow below are derived
from the archived source and from `+pds/`. The `.mat` files themselves were not
readable at the time of writing (OneDrive placeholders). Where a claim is worth
checking directly against saved data, the relevant saved field is named so it
can be confirmed from the session itself.

**Other salience modes.** `srsSmooth_settings.m` also defines a DKL-luminance
mode (`salienceType = 2`) and a direct-RGB C24 mode (`salienceType = 3`).
Neither was used here. Their variables are still present in every saved trial,
set to `NaN` or `0`; §6.7 lists them so they are not mistaken for data.

---

## 1. Task at a glance

On each trial the subject fixates a central point. One or two peripheral
rectangular targets appear while fixation is maintained. After a fixed delay
the fixation point is extinguished (the **go signal**), and the subject makes a
saccade to a target and holds it briefly. A correct hold delivers a liquid
reward whose size depends on **which target identity was chosen**.

Two properties are manipulated independently:

- **Salience** — how different a target's hue is from the background. Varies
  trial to trial.
- **Reward** — each target identity has a mean reward magnitude that is fixed
  within a block and unsignaled. Varies block to block.

The experimental question is what the subject does when these two conflict.

```
                fixation      targets      GO
                  on          appear    (fix off)   saccade    hold    reward
   trial ──────────┬────────────┬───────────┬──────────┬────────┬────────┬────
   begin           │            │           │          │        │        │
                   │◄ fixDurReq►│◄  450 ms ►│◄ ≤450 ms►│◄~0.2-  │◄250 ms►│
                   │  0.5-0.8 s │   delay   │ response │  0.3 s │ delay  │
                   │            │           │  window  │        │        │
   state:    showFix   dontMove   targetDelay  MakeSaccade  holdTarg  sacComplete
     (2)        (4)        (456)      (450)      (451/452)     (455)
```

---

## 2. Files on disk

A session folder is `p.init.sessionFolder`, named
`<yyyymmdd>_t<HHMM>_srsClassic_Moretraining`.

| File | Written | Contents |
|---|---|---|
| `p.mat` | Once on trial 1, then `status` re-appended after every saved trial | The whole `p` struct saved with `-struct`, so each top-level field of `p` becomes a variable in the file. `trVars`/`trData` in this file are **trial 1's only**. `status` is overwritten each trial, so it reflects the **last saved trial**. |
| `trial####.mat` | After every trial that is not a `nonStart` | Four variables: `trVars`, `trData`, `status`, `init`. |
| `srsSmooth.zip` | Once on trial 1 | Zip of the entire `tasks/SRS_Task_Smooth/` folder as it existed at run time. Authoritative record of the code that produced the session. |

**Trial file numbering.** The number is `p.status.iTrial`, the *attempt*
counter, zero-padded to four digits. `pds.saveP` returns early without writing
a file when `p.trData.trialEndState == p.state.nonStart` (13), so **gaps in the
numbering are non-start attempts**, not missing data. In the 2026-08-19 session
there are 342 trial files; `trial0005.mat` is absent because attempt 5 was a
non-start.

`init` is duplicated in full inside every trial file. It is constant within a
session; read it once.

---

## 3. Loading the data

```matlab
p = pds.loadP('.../output/20260819_t1440_srsClassic_Moretraining');
```

`pds.loadP` loads `p.mat`, then replaces `p.trVars` and `p.trData` with
1×nTrials struct arrays built from the `trial####.mat` files, unifying field
sets across trials via `pds.unifyStructArray` (trials that ended early may lack
fields that later states would have written). `p.status` after this call is
still the single last-trial snapshot from `p.mat` — **per-trial status must be
read from the trial files directly**, because several analysis-critical
quantities live only in `status` (§6.6).

A minimal per-trial loop that keeps `status`:

```matlab
files = dir(fullfile(sessionFolder, 'trial*.mat'));
for iF = 1:numel(files)
    S = load(fullfile(files(iF).folder, files(iF).name));
    trVars(iF) = S.trVars;  trData(iF) = S.trData;  status(iF) = S.status;
end
```

`tasks/SRS_Task_Smooth/SRS_behavior_analysis_2/srs_load_session.m` already
implements a fuller version of this, producing a flat trial table.

---

## 4. Task design

### 4.1 Targets: identity versus side

The single most important distinction in this dataset. **Target identity**
(T1/T2) and **screen side** (right/left) are independent and are randomized
against each other on every trial.

| | Meaning |
|---|---|
| **T1** | Horizontal rectangle. Long axis 2.00°, short axis 0.667° (3:1). |
| **T2** | Vertical rectangle. Same dimensions, rotated 90°. |
| **Side 1** | Right. The rightmost of the two configured locations, i.e. (+10°, 0°). |
| **Side 2** | Left. The leftmost configured location, i.e. (−10°, 0°). |

Reward is attached to **identity**, not side. Salience is assigned by
identity and then read out as a side. Every side-valued and identity-valued
field is listed with its convention in §6; the convention is always
`1 = right, 2 = left` for sides and `1 = T1, 2 = T2` for identities, with `0`
meaning "none/not applicable".

`p.trVars.T1Side` / `T2Side` give the mapping for the trial. They always
satisfy `T2Side == 3 - T1Side`, and the target locations `T1_locDegX/Y` and
`T2_locDegX/Y` saved in `trVars` are **already resolved to that trial's sides**
— i.e. the saved values are the physical positions used, not the settings-file
defaults.

**Acceptance windows.** `targWinWidthDeg` and `targWinHeightDeg` (both 4) are
used as **half**-widths: a saccade counts as landing on a target if
`|eyeDegX − targX| ≤ 4` and `|eyeDegY − targY| ≤ 4`. With targets at ±10° the
two windows do not overlap. `fixWinWidthDeg`/`fixWinHeightDeg` (both 2) are
likewise half-widths, and the fixation test is strict (`<`, not `≤`).

### 4.2 Salience: classic DKL hue contrast

In this variant salience is hue contrast against the background, drawn from a
fixed four-hue set. Both background hue poles and both target hues share a
fixed DKL luminance of −0.495 and saturation radius 0.4; only the hue angle
differs.

`p.trVars.backgroundHueIdx` is drawn fresh each trial as `randi(2)`:

| `backgroundHueIdx` | Background hue | High-salience target hue | Low-salience target hue |
|---|---|---|---|
| 1 | 0° (CLUT 20) | 180° (CLUT 22) | 20° (CLUT 21) |
| 2 | 180° (CLUT 22) | 0° (CLUT 20) | 200° (CLUT 23) |

So the **hue contrast** (circular distance from background) is always **180°
for the high-salience target and 20° for the low-salience target**. Unlike the
`smooth` hue mode, contrast is not sampled continuously — it takes exactly two
values. `HueContrastT1` and `HueContrastT2` therefore each take only the values
180 and 20 across the session, and `HueContrastDifferenceMagnitude` is always
160.

Which *identity* is high-salience is `p.status.highSalienceTargetID`; which
*side* is high-salience is `p.status.highSalienceSide`.

### 4.3 Reward

Reward is delivered by opening a solenoid for a number of milliseconds; the
rig calibration is **0.0011 ml/ms**.

**Per block.** `chooseBlockReward` draws two candidate means independently from
a uniform distribution on [37, 191] ms (0.04–0.21 ml, from Dubey et al. 2023,
Neuron 111:3321), rejecting pairs whose separation is below 40 ms. The larger
becomes the **rich** mean, the smaller the **poor** mean. Both are then
multiplied by `rewardScale` (k).

**Per trial.** Each of the two rewards available on that trial is drawn
independently as `round(mean + SD·randn)`, floored at 1 ms:

- `p.status.ActualRichReward` — sample for the rich identity
- `p.status.ActualPoorReward` — sample for the poor identity

These are then mapped to identities and to sides:

```
highRewardTargetID = CurrentBlockType          % 1 = T1 rich, 2 = T2 rich
rewardDurationT1   = rich if T1 is rich, else poor
rewardDurationT2   = poor if T1 is rich, else rich
rewardDurationRight/Left = rewardDurationT1/T2 routed through T1Side
```

The value actually delivered is selected by **chosen identity**
(`p.trVars.rewardDurationT1` or `...T2`) and recorded in
`p.trData.deliveredRewardDurationMs`.

**The `k` (rewardScale) change between 2026-08-19 and 2026-08-20.**

| | 2026-08-19 | 2026-08-20 |
|---|---|---|
| `rewardScale` (k) | Not present in the code; behaviour equals **k = 1** | **1.5** |
| Block mean range, delivered | 37 – 191 ms | 55.5 – 286.5 ms |
| Minimum rich − poor separation, delivered | 40 ms | 60 ms |
| Per-trial Gaussian SD, delivered | 14 ms | 21 ms (SD is scaled by k too) |
| Per-delivery ceiling | None | `maxSingleRewardMs` = 400 ms |

The 2026-08-19 code drew means directly from the literal range and applied
`max(1, round(mean + 14·randn))` with no upper clamp, which is arithmetically
identical to k = 1. Treating the earlier session as k = 1 is exact, not an
approximation. On sessions where it exists, the effective post-clamp values are
saved as `p.status.BlockRewardScale` and `p.status.BlockRewardSdMs`.

### 4.4 Block schedule

Blocks alternate which identity is rich. The first block's rich identity is
`randi(2)`; every subsequent block flips it (`CurrentBlockType = 3 −
CurrentBlockType`). Block transitions are **unsignaled**.

A block schedule is an explicit list of rows, one per trial that must be
completed *successfully*. It is built by `buildSrsBlockSchedule` and has two
phases:

**Phase 1 — instruction (single-target) trials.** 25 T1-only and 25 T2-only
rows, **mixed in random order**, each set split as evenly as possible across
the two sides (12/13, with the odd row's side chosen at random). 50 rows total.
`nStim = 1`, `singleTargetID ∈ {1,2}`, `schedulePhase = 1`, `trialType = 0`.

**Phase 2 — two-target choice trials.** The number of choice rows is
`4·randi([3,12])`, i.e. **12 to 48 rows in steps of 4**, drawn per block
(`minTrialsPerBlock = 10`, `maxTrialsPerBlock = 50`). They are balanced across
a 2×2 design: {congruent, conflict} × {T1 right, T1 left}, with
`nChoice/4` repetitions per cell. `nStim = 2`, `singleTargetID = 0`,
`schedulePhase = 2`.

Total block length is therefore **62 to 98 rows**.

**Phase ordering is strict.** `chooseScheduledRow` always selects uniformly at
random among the eligible rows of the *lowest-numbered remaining phase*. No
choice trial can occur until every one of the 50 instruction rows has been
completed successfully.

**Failure handling.** A row is removed from the schedule only when its trial is
completed successfully (`trialEndState == 455`). Any failure leaves the row
eligible, so it will be sampled again later in the block. `p.status.iTrial`
counts attempts; `p.status.iGoodTrial` counts successes.

A new block starts when no eligible rows remain.
`p.status.TotalBlocksTarget` is 8, but nothing stops the session at that count
— it only drives the `RemainingBlock` display.

### 4.5 Trial types

`p.status.ActualTrialType` (mirrored to `CurrentTrialType`):

| Value | Type | Definition |
|---|---|---|
| 0 | Instruction | `nStim == 1`. One target shown. |
| 1 | Congruent | `nStim == 2`. High salience and high reward on the **same** side. |
| 2 | Conflict | `nStim == 2`. High salience and high reward on **opposite** sides. |

On instruction trials salience is assigned differently: `highSalienceTargetID =
randi(2)` **independently of which target is actually shown**. The single
visible target therefore carries the high-salience hue on ~50% of instruction
trials and the low-salience hue otherwise, uncorrelated with its identity,
side, or reward. Note that `T1Side` and `T2Side` are both defined on
instruction trials even though only one target is drawn, so
`highSalienceSide` is always well defined.

### 4.6 Correction trials

An optional anti-bias mechanism, controlled live from a dedicated MATLAB
control window (`initCorrectionControlWindow` / `readCorrectionControlWindow`),
read fresh before every trial. Defaults are off
(`p.trVarsInit.correctionTrial = false`), but the experimenter can enable it
mid-session, so **whether it was active must be read per trial from the saved
data**, not assumed.

**Trigger.** After a *successfully completed* conflict choice trial in which
the subject chose the low-reward target: right-side choices only by default,
or either side if `correctionBothSides` is set.

**Effect.** The exact schedule row is forced again, and the complete stochastic
condition (reward samples, hues, CLUT entries) is restored from a snapshot, so
repeats are identical rather than merely same-condition. Repeats continue until
the subject chooses the high-reward target or
`correctionTrialMaxRepetition` (default 15) is reached. A correction sequence
never carries across a block boundary.

**Optional reward reduction.** If `correctionReduceRightReward` is enabled and
the sequence was triggered by a *right* choice, the right-side reward is
multiplied by `correctionRightRewardMultiplier^level` (floored at
`correctionRightRewardMinimumMs`), where `level` increments only after another
completed, still-incorrect right choice.

**Reading it back.** For "was *this* trial a forced repeat", use
`p.trData.correctionTrialActive` / `p.trVars.correctionTrialActive` (captured
before the trial). For "did this trial *trigger* a correction", use
`p.status.correctionTrialActive` in the same trial file (written after the
trial, in `_finish`). These two are not the same quantity.

---

## 5. Trial time course and state machine

### 5.1 States

`p.state` maps names to integer IDs. `p.trData.trialEndState` records the state
in which the trial ended, and is the primary outcome variable.

**States reachable in this task:**

| ID | Name | Meaning |
|---|---|---|
| 1 | `trialBegun` | Entry state; strobes `trialBegin` and advances immediately. |
| 2 | `showFix` | Fixation point drawn; waiting for acquisition within `fixWaitDur` (0.3 s). |
| 4 | `dontMove` | Fixation held; waiting for `fixDurReq` (0.5–0.8 s, drawn per trial). |
| 456 | `targetDelay` | Targets shown, fixation point still on. Waits `targetDelayDurationMs` (450 ms). |
| 450 | `MakeSaccade` | Fixation extinguished (go signal). Waiting for saccade initiation within `responseWindow` (0.45 s). |
| 451 | `checkLanding` | Saccade in flight; classifying landing. |
| 452 | `holdTarg` | Gaze in a target window; must hold `targHoldDuration` (0.2–0.3 s, drawn per trial). |
| **455** | **`sacComplete`** | **Success.** Outcome classified, tone played, reward delivered, then `postRewardDuration` (0.25 s) elapses. |
| 13 | `nonStart` | Fixation never acquired. **Not saved to disk.** |
| 11 | `fixBreak` | Fixation broken before target onset, during the delay, during the saccade (blink), or during target hold. |
| 453 | `noResponse` | No saccade initiated within the response window. |
| 454 | `inaccurate` | Saccade landed outside both target windows, or exceeded `maxSacDurationToAccept` (0.1 s). |

`p.trData.GoodTrial` is exactly `trialEndState == 455`, and
`p.trData.trialRepeatFlag` is its negation.

**States defined but unreachable in this task:** `holdJoy` (3), `makeDecision`
(5), `joyBreak` (12), `hit` (21), `cr` (22), `miss` (23), `foilFa` (24),
`fa` (25). These are inherited from the change-detection task the settings file
descends from. The joystick is never a task requirement here — its voltage is
still recorded (§6.8) but no state gates on it.

**Failure sub-classification.** `p.trData.failureReason` is a string that
distinguishes causes that share a `trialEndState`:

| `failureReason` | End state | Meaning |
|---|---|---|
| `"fixationNotAcquired"` | 13 | Never entered the fixation window in time. |
| `"fixBreakBeforeTargetOn"` | 11 | Left fixation during `dontMove`. |
| `"fixbreakduringdelay"` | 11 | Left fixation during `targetDelay`, or after the state advanced but before the fixation-off frame was displayed. Also timestamped separately in `timing.fixBreakDuringDelay`. |
| `"noResponse"` | 453 | No saccade within `responseWindow`. |
| `"landingOutsideTargetWindows"` | 454 | Landed outside both windows. |
| `"saccadeDurationExceeded"` | 454 | Eye velocity stayed above threshold longer than 0.1 s. |
| `"blinkDuringSaccade"` | 11 | Gaze exceeded ±35° after the go signal. |
| `"targetHoldBreak"` | 11 | Left the chosen target window before the hold requirement was met. |

**Saccade detection** is online: an eye sample outside the fixation window,
combined with a filtered velocity above `eyeVelThresh` (100 °/s, 5-tap filter),
after `goLatencyMin` (0 s) and within `responseWindow`. Landing is declared
when velocity drops back below threshold.

### 5.2 Timing variables and the postFlip convention

Every field of `p.trData.timing` is initialized to `−1` before each trial.
**`−1` means the event did not occur.** Always test `> 0` before using a
timing value.

**Reference frame.** With one exception, all `timing` fields are **seconds
relative to `p.trData.timing.trialStartPTB`**, which is the Psychtoolbox
`GetSecs` timestamp captured at the top of `srsSmooth_run.m`.

The exception is **`timing.flipTime`**, a vector of **absolute** PTB
timestamps returned by `Screen('Flip')`. To put flips on the same axis as
everything else, subtract `trialStartPTB`.

**postFlip mechanism.** Visual event times must be recorded after the flip that
displays them. States push a variable name onto
`p.trVars.postFlip.varNames`; `drawMachine` then assigns the just-completed
flip time (relative) to `p.trData.timing.(name)` and strobes the queued codes.
`fixOn`, `targetOn` and `fixOff` are assigned this way, so they are
frame-locked. All other timestamps are taken directly in the polling loop at
the moment of detection.

---

## 6. Saved data structures

### 6.1 `p.init`

Session-level metadata and task definitions. Constant within a session;
duplicated into every trial file.

| Field | Description |
|---|---|
| `pcName` | Hostname of the rig PC. Its second-to-last character selects the rig config file. |
| `rigConfigFile` | Full path to the rig config used (e.g. `rigConfigFiles.rigConfig_rig1`). |
| `taskName` | `'srsSmooth'` — the shared quintet name, **not** the variant name. |
| `taskType` | `1`. Legacy numeric task index. |
| `exptType` | `'srs_classic_Moretraining'`. **This is the field that identifies the variant.** |
| `protocol_title` | `'srsClassic_Moretraining_task'`. |
| `pldapsFolder` | Working directory at load time. |
| `date`, `time` | `'yyyymmdd'` and `'HHMM'` strings. |
| `date_1yyyy`, `date_1mmdd`, `time_1hhmm` | Date/time as numbers with a leading `1` prepended so leading zeros survive (e.g. 14:40 → `11440`). Strip the first digit to recover. |
| `sessionId` | `<date>_t<time>_srsClassic_Moretraining`. |
| `outputFolder`, `sessionFolder`, `figureFolder` | Output paths. |
| `taskFiles` | Struct with `.init`, `.next`, `.run`, `.finish` filenames. |
| `taskActions` | Cell array of GUI-callable action m-files (data export, black screen, i1 photometer routines). |
| `useDataPixxBool` | `true`. |
| `trDataInitList` | N×2 cell array: `p.trData` field names and the expression each is reset to before every trial. This is the authoritative list of what `trData` contains (§6.8). |
| `nTrDataListRows` | Row count of the above. |
| `trialsTableColumnNames`, `trialsTableCols` | Column names and a name→index lookup struct for the compact condition table. |
| `trialArrayColumnNames`, `trialCols` | Same, for the expanded per-trial schedule array. Columns: `conditionID`, `nStim`, `singleTargetID`, `T1Side`, `T2Side`, `trialType`, `schedulePhase`, `trialSeed`. |
| `trialsTable` | Compact condition table for the **current** block: one row per condition plus a repetition count. |
| `trialsArray` | Expanded schedule for the current block: one row per trial that must be completed successfully. `p.trVars.currentTrialsArrayRow` indexes into this. |
| `blockLength` | `size(trialsArray, 1)`. |
| `strobeList` | N×2 cell array of `{codeName, valueExpression}` evaluated at the end of each trial. See §7 for what actually reaches the ephys stream. |
| `codes` | The full `pds.initCodes` struct: every event-code name mapped to its integer. **Read this from `p.mat` rather than from the repo** — it is the record of the code table that was live for this session. |
| `strb` | `pds.classyStrobe` handle object managing the strobe queue. |

Note: `trialsTable`, `trialsArray` and `blockLength` describe the block that
was current when that trial file was written, and are rebuilt at every block
boundary.

### 6.2 `p.rig`

Hardware configuration, loaded by `pds.initRigConfigFile` from the rig-specific
config. Values shown are for `rigConfig_rig1`.

| Field | Description |
|---|---|
| `viewdist` | Viewing distance, 410 mm. |
| `screenhpix`, `screenh` | Screen height in pixels (1200) and mm (302.40). |
| `deg2PixConstant` | `viewdist · screenhpix / screenh`; used by `pds.deg2pix`/`pix2deg`. |
| `screen_name`, `screen_number` | `'viewpixx'`, display index 1. |
| `refreshRate`, `frameDuration` | 120 Hz nominal; both are overwritten with measured values by `pds.initPsychToolbox`. **Use the saved values, not 120.** |
| `magicNumber` | 0.008 s. Drawing begins this long before the predicted flip deadline. |
| `baseReward` | 189. Rig reward calibration constant; not used by this task's reward computation. |
| `joyVoltageMin/Rest/Max`, `joyThresh` | Joystick calibration and press/release thresholds. Recorded but not gating in this task. |
| `dp` | DataPixx settings: `adcRate` 1000 Hz, `maxDurADC` 15 s, `adcBuffAddr` 4e6, `dacRate` 1000 Hz, `dacPadDur` 0.01 s, `dacBuffAddr` 10e6, `dacChannelOut` 0. |
| `connectToOmniplex` | `false` on rig 1. |
| `guiStatVals` | Names of `p.status` fields shown in the GUI. |
| `guiVars` | Names of `p.trVars` fields exposed as GUI controls. On 2026-08-19 this included `MeanrewardDurationMs`; from 2026-08-20 it is `rewardScale` and `maxSingleRewardMs` instead. |

### 6.3 `p.audio`

| Field | Description |
|---|---|
| `freq` | 48000 Hz playback rate. |
| `nTF` | 4800 samples = **100 ms** tone duration. |
| `audsplfq`, `auddur` | Legacy duplicates (48000, 4800). |
| `Hitfq`, `Missfq` | Legacy two-tone frequencies (600, 100 Hz). Superseded here. |
| `lineOutLevel` | 0.4. |
| `pcPlayback` | `false`. |
| `feedbackHighRewardFreqHz` | **900 Hz** — played on a correct choice of the rich identity. |
| `feedbackLowRewardFreqHz` | **450 Hz** — played on a correct choice of the poor identity. |
| `feedbackFailureFreqHz` | **150 Hz** — played on every failed trial, regardless of cause. |
| `failureTone`, `lowRewardTone`, `highRewardTone` | The generated waveforms (Gaussian-windowed sinusoids). |
| `failureBuffAdd`, `lowRewardBuffAdd`, `highRewardBuffAdd` | DataPixx buffer addresses; aliases of `wrongBuffAdd`, `rightBuffAdd`, `noiseBuffAdd` respectively. |

Tones are enabled by `p.trVarsInit.useThreeOutcomeTones = true`. Feedback is
played immediately before reward delivery on success, or when the failure state
is finalized. Because the buffers are reused, the **strobed** tone codes are
those of the reused buffers — see §7.

### 6.4 `p.draw`

Drawing parameters and the colour lookup table.

| Field | Description |
|---|---|
| `window` | Psychtoolbox window pointer. |
| `middleXY` | Screen centre in pixels. |
| `displayMode` | `'L48_DUAL_CLUT'` for this variant. |
| `isDirectRgb` | `false` for this variant. |
| `clutIdx` | Struct mapping colour names to CLUT indices (0-based). Naming is `expColor_subColor`: what the experimenter display shows vs. what the subject display shows. |
| `clut` | The CLUT itself: `expCLUT`, `subCLUT` (256×3 each) and `combinedClut` = `[subCLUT; expCLUT]`. |
| `color` | Current CLUT index for each drawn element (`background`, `fix`, `fixWin`, `eyePos`, `gridMajor`, `joyInd`, …). `color.background` changes per trial with `backgroundHueIdx`. |
| `colors.dkl_hues` | 4×3 RGB values for DKL hues 0°, 20°, 180°, 200° at luminance −0.495, saturation 0.4. |
| `colors.isolumGray` | RGB for the same DKL luminance at zero saturation. |
| `fixPointPix`, `fixPointRect`, `fixPointRadius` (6), `fixPointWidth` (4) | Fixation point geometry in pixels. |
| `fixWinWidthPix`, `fixWinHeightPix` | Fixation window half-extents in pixels. |
| `fixWinPenPre` (4), `fixWinPenPost` (8), `fixWinPenThin` (1), `fixWinPenDraw` | Experimenter-display fixation window line weights. |
| `targWinPenThin` (4), `targWinPenThick` (8), `targWinPenDraw` | Target window line weights; set thick once a target is acquired. |
| `T1_locPixX`, `T1_locPixY`, `T2_locPixX`, `T2_locPixY` | Target centres in pixels for this trial. |
| `T1_longAxisPix`, `T1_shortAxisPix`, `T2_longAxisPix`, `T2_shortAxisPix` | Target dimensions in pixels. T1 is drawn `[long × short]` (horizontal); T2 is drawn `[short × long]` (vertical). |
| `gridXY`, `gridSpacing` (2°), `gridW` | Experimenter-display reference grid. |
| `eyePosWidth` (6), `cursorW` (6), `joyRect` | Experimenter-display indicators. |

**CLUT indices relevant to this variant:**

| Index | Name | Use |
|---|---|---|
| 20 | `expDkl0_subDkl0` | DKL hue 0° — background or target |
| 21 | `expDkl20_subDkl20` | DKL hue 20° — low-salience target when background is 0° |
| 22 | `expDkl180_subDkl180` | DKL hue 180° — background or target |
| 23 | `expDkl200_subDkl200` | DKL hue 200° — low-salience target when background is 180° |
| 30–43 | `exp*_subDkl0` / `exp*_subDkl180` | Experimenter-only overlays whose subject-side entry matches the current background, so debug graphics stay invisible to the subject. |
| 200–231 | red DKL luminance ramp | Unused in this variant. |
| 250, 251 | `srsTargetT1`, `srsTargetT2` | Reserved dynamic slots used only by `smooth` hue mode. Unused here. |

### 6.5 `p.state`

Name→integer map for the state machine. Values are listed in §5.1. This struct
is constant and is the decoder for `p.trData.trialEndState`.

### 6.6 `p.status`

Session- and block-level bookkeeping. A snapshot is saved in **every trial
file**, written in `_finish` — i.e. **after** the trial's counters have been
updated and after `updateTrialsList` has run. Several fields here are not
available anywhere else and are required for analysis.

**Counters**

| Field | Description |
|---|---|
| `iTrial` | Attempt counter, incremented in `_next`. Matches the trial file number. |
| `iGoodTrial` | Cumulative count of successful trials (`trialEndState == 455`). |
| `iSingleT1Correct`, `iSingleT2Correct` | Cumulative successful instruction trials by identity. |
| `iTrial_Rich_High` | Congruent trials where the rich identity was chosen (rich = high salience). |
| `iTrial_Poor_low` | Congruent trials where the poor identity was chosen. |
| `iTrial_Rich_low` | Conflict trials where the rich identity was chosen (rich = low salience). |
| `iTrial_Poor_High` | Conflict trials where the poor identity was chosen (poor = high salience). |
| `missedFrames` | Cumulative count of flips separated by more than 1.5 frame durations. |

**Block state**

| Field | Description |
|---|---|
| `CurrentBlockNumber` | 1-based block index for this trial. |
| `CurrentBlockType` | **Rich target identity**: 1 = T1 rich, 2 = T2 rich. Alternates every block. |
| `highRewardTargetID` | Same value as `CurrentBlockType`, restated as an identity. |
| `highRewardSide` | Side (1 = right, 2 = left) carrying the rich identity **on this trial**. |
| `TotalBlocksTarget` (8), `RemainingBlock` | Display bookkeeping only. |
| `BlockRichMeanDuration`, `BlockPoorMeanDuration` | Block mean reward durations in ms, post-scaling. |
| `BlockRewardScale`, `BlockRewardSdMs` | Effective post-clamp k and SD. Present only from 2026-08-20. |
| `TotalTrialsPerBlock` | Total schedule rows for this block (62–98). |
| `TotalInstructionTrialsPerBlock` | 50. |
| `TotalSingleT1`, `TotalSingleT2` | 25 each. |
| `TotalChoiceTrialsPerBlock` | 12–48, multiple of 4. |
| `TotalCongruent`, `TotalConflict` | Half of the above each. |
| `Remaining*` | Counts of rows still eligible in each category. |
| `CurrentBlockTrial` | Schedule rows completed successfully in this block. |
| `blockAttemptCount` | Attempts in this block, including failures. |
| `blockScheduleComplete` | `true` when no eligible rows remain. |
| `trialsArrayRowsPossible` | Logical vector, one entry per row of `p.init.trialsArray`: which rows are still eligible. |
| `ActiveSchedulePhase`, `RemainingActivePhase`, `SingleTargetsMixed` | Phase bookkeeping. `FirstSingleTargetID`/`SecondSingleTargetID` are deprecated and always 0 (singles are mixed). |

**Per-trial condition** — these describe the trial in whose file they appear.

| Field | Description |
|---|---|
| `ActualTrialType` | 0 = instruction, 1 = congruent, 2 = conflict. |
| `CurrentTrialType` | Copy of the above. |
| `CurrentTrialPhase` | 1 = instruction phase, 2 = choice phase. |
| `CurrentNStim` | 1 or 2. |
| `CurrentSingleTargetID` | 0 = dual, 1 = T1 only, 2 = T2 only. |
| `highSalienceTargetID` | Identity assigned the high-salience hue. |
| `highSalienceSide` | Side carrying that identity. |
| `ActualRichReward`, `ActualPoorReward` | The two per-trial reward samples in ms. On a correction trial with right-reward reduction active, the value corresponding to the right side is overwritten with the reduced value. |
| `delta` | Constant 450. Mirrors `targetDelayDurationMs`. |
| `fixDurReq` | Legacy field, remains 0; the actual per-trial requirement is `p.trVars.fixDurReq`. |
| `previousTargetDelayDurationMs` | `NaN`. |

**Correction state (post-trial)**

| Field | Description |
|---|---|
| `correctionTrialActive` | Whether a correction sequence is active **after** this trial — i.e. whether this trial triggered or continued one. |
| `correctionTrialRow` | Schedule row being forced, or `NaN`. |
| `correctionTrialRepetition` | Forced attempts so far in the current sequence. |
| `correctionTrialTriggerSide` | Side of the choice that triggered the sequence: 1 = right, 2 = left, `NaN` = inactive. |
| `correctionRightRewardReductionLevel` | Cumulative reduction exponent for the right-side reward. |
| `correctionTrialTriggerCount`, `correctionTrialSuccessCount`, `correctionTrialMaxReachedCount` | Session totals. |
| `correctionTrialLastOutcome` | Human-readable string describing the last sequence transition. |
| `correctionTrialSnapshot`, `correctionTrialSnapshotValid` | Saved stochastic condition for exact repeats. |

**Legacy fields from the change-detection ancestor** — `hr1Loc1`, `cr1Loc1`,
`hc2Loc2`, `cue1CtLoc1`, `foil2CtLoc2` and the rest of that family are never
written by this task and remain 0. `questThreshEst` is absent because
`useQuest` is `false`.

### 6.7 `p.trVars`

Trial variables. At the start of `_next`, `p.trVars` is replaced wholesale by
`p.trVarsGuiComm` (which carries any GUI edits), then the correction control
window is read, then `nextParams` writes the trial's condition into it. The
whole struct is saved per trial, so it contains both live values and a large
number of inherited fields that this variant never uses.

**Schedule and identity**

| Field | Description |
|---|---|
| `currentTrialsArrayRow` | Row of `p.init.trialsArray` used for this trial. |
| `conditionID` | Condition identifier from the compact table. |
| `nStim` | 1 = instruction, 2 = choice. |
| `singleTargetID` | 0 = dual, 1 = T1 only, 2 = T2 only. |
| `T1_present`, `T2_present` | Whether each identity is drawn this trial. |
| `T1Side`, `T2Side` | 1 = right, 2 = left. Always complementary. |
| `schedulePhase` | 1 = instruction, 2 = choice. |
| `trialSeed` | Per-row random integer in [1, 32767], assigned when the block schedule was built. Identifies a specific schedule row across repeats. |

**Target geometry** (values are resolved for this trial's side assignment)

| Field | Description |
|---|---|
| `T1_locDegX`, `T1_locDegY` | T1 centre in degrees. |
| `T2_locDegX`, `T2_locDegY` | T2 centre in degrees. |
| `T1_longAxisDeg` (2.00), `T1_shortAxisDeg` (0.667) | T1 dimensions. Drawn horizontally. |
| `T2_longAxisDeg` (2.00), `T2_shortAxisDeg` (0.667) | T2 dimensions. Drawn vertically. |
| `targWinWidthDeg`, `targWinHeightDeg` | Both 4. Used as **half**-widths. |
| `T1_visible`, `T2_visible` | Whether each target is currently drawn. Final saved value reflects the end of the trial. |
| `fixDegX`, `fixDegY` | Fixation position, both 0. |
| `fixWinWidthDeg`, `fixWinHeightDeg` | Both 2. Used as **half**-widths. |
| `fixPointRadPix` (20), `fixPointLinePix` (12) | Fixation point size. |
| `fixationVisible` | Whether the fixation point is drawn. Goes false at the go signal. |
| `targetHorizontalEccDeg` | Legacy (10). Not used — locations come from `T1/T2_locDegX/Y`. |

**Salience (hue mode)**

| Field | Description |
|---|---|
| `salienceType` | 1 = hue. |
| `hueSamplingMode` | `'classic'`. |
| `hueModeCode` | 1 = classic, 2 = smooth. Set to 1 by `applySalience` at run time. |
| `backgroundHueIdx` | 1 = background DKL 0°, 2 = background DKL 180°. Redrawn each trial. |
| `BackgroundHue` | Background hue in degrees (0 or 180). |
| `ActualHueT1`, `ActualHueT2` | Absolute DKL hue angle of each target, in degrees. |
| `HueContrastT1`, `HueContrastT2` | Circular distance from background, in degrees. 180 for high salience, 20 for low. |
| `HueContrastDifferenceT1MinusT2` | `HueContrastT1 − HueContrastT2`: ±160. |
| `HueContrastDifferenceMagnitude` | 160. |
| `HighSalienceHueDeg`, `LowSalienceHueDeg` | Absolute hues of the high- and low-salience targets. |
| `T1_colorIdx`, `T2_colorIdx` | CLUT index used to draw each target (20–23). |
| `*_x10` variants | The same angles multiplied by 10 and rounded, for strobing. |
| `hueDklMeanLuminance` (−0.495), `hueDklSaturationRadius` (0.4) | Fixed DKL coordinates shared by background and targets. |
| `minHueAngleDeg`, `maxHueAngleDeg`, `hueContrastSamplingMode`, `hueContrastDiffMinDeg` | Smooth-mode parameters. **Not used in classic mode.** |
| `updateClutThisTrial` | `false` in classic mode (CLUT entries are static). |

**Reward**

| Field | Description |
|---|---|
| `rewardDurationT1`, `rewardDurationT2` | Reward in ms available for each identity this trial. This is what selects the delivered amount. |
| `rewardDurationRight`, `rewardDurationLeft` | The same two values routed to sides. |
| `currentRewardDuration` | The value chosen for the actual delivery. |
| `rewardDurationMs` | Set to `currentRewardDuration` immediately before `pds.deliverReward`. Its initial value (300) is not meaningful. |
| `rewardDelay` | 0.25 s. Declared but not used by the SRS state machine. |
| `postRewardDuration` | 0.25 s of trial time after reward delivery, for recording the reward response. |
| `blockMeanRewardMinMs` (37), `blockMeanRewardMaxMs` (191), `blockMeanRewardMinSepMs` (40) | Pre-scale block mean parameters. |
| `RewardSdGaussianNoiseMs` | 14 ms, pre-scale. |
| `rewardScale`, `maxSingleRewardMs` | Present from 2026-08-20 only (1.5 and 400). |
| `MeanrewardDurationMs` | Present on 2026-08-19 only (300); superseded by `rewardScale`. Not used in the reward computation. |
| `SD_rewardDuration` | 0.015 ml. Documentation of where the 14 ms SD came from; not used numerically. |

**Timing**

| Field | Description |
|---|---|
| `fixWaitDur` | 0.3 s to acquire fixation after it appears. |
| `fixDurReqMin` (0.5), `fixDurReqMax` (0.8) | Bounds for the fixation hold requirement. |
| `fixDurReq` | The requirement drawn for **this** trial, uniform in the above range. |
| `targetDelayDurationMs` | Target onset → go signal interval. **450 ms on every trial** in this variant. |
| `delay_ms_min` (300), `delay_ms_max` (600) | Bounds declared in the settings file. `targetDelayDurationMs` retains its initialized value of 450, so these bounds do not vary the delay in this variant. |
| `responseWindow` | 0.45 s from go signal to saccade initiation. |
| `goLatencyMin` (0), `goLatencyMax` (0.45) | Accepted reaction-time bounds; the effective upper bound is `responseWindow`. |
| `maxSacDurationToAccept` | 0.1 s maximum saccade flight time. |
| `targHoldDurationMin` (0.2), `targHoldDurationMax` (0.3) | Bounds for the target hold requirement. |
| `targHoldDuration` | The requirement drawn for this trial. |
| `trialMax` | 15 s hard cap. |
| `timeoutAfterFixBreak` (0.1), `timeoutAfterMiss` (1), `timeoutAfterFa` (2), `timeoutAfterFoilFa` (3) | Post-trial timeouts. Only the fixation-break value is reachable; `noResponse` and `inaccurate` incur no timeout. |
| `finish` | 1400. Maximum attempts for the session. |

**Online gaze and eye tracking**

| Field | Description |
|---|---|
| `eyeDegX`, `eyeDegY` | Current eye position in degrees (final loop iteration's value when saved). |
| `eyePixX`, `eyePixY` | Same in pixels, screen-centred, Y inverted. |
| `joyVolt` | Current joystick voltage. |
| `eyeVelThresh` | 100 °/s saccade-detection threshold. |
| `eyeVelFiltTaps` | 5-sample velocity filter. |
| `useVelThresh` | `true`. |
| `eyeVelThreshOffline` | 100 °/s, for offline reanalysis. |
| `whileLoopIdx` | Final polling-loop iteration count for the trial. |
| `flipIdx` | Number of flips plus one. |
| `mouseCursorX`, `mouseCursorY` | Mouse position; read every iteration. |
| `mouseEyeSim` | If 1, mouse position replaces the eye signal. **Should be 0 in recorded sessions.** |
| `passEye`, `passJoy` | Debug bypasses. `passEye = 1` makes every window test succeed and simulates a choice. **Should be 0 in recorded sessions.** |

**Correction (pre-trial values for this trial)**

| Field | Description |
|---|---|
| `correctionTrial` | Whether the mechanism is enabled. |
| `correctionBothSides` | `false` = right-triggered only; `true` = either side. |
| `correctionTrialActive` | 1 if **this** trial is a forced repeat. |
| `correctionTrialRepetition` | Which forced attempt this is (1-based). |
| `correctionTrialMaxRepetition` | Cap, default 15. |
| `correctionTrialTriggerSide` | Side of the triggering choice. |
| `correctionReduceRightReward` | Whether right-reward reduction is enabled. |
| `correctionRightRewardMultiplier`, `correctionRightRewardMultiplier_x1000` | Multiplier per reduction level (0.50). |
| `correctionRightRewardMinimumMs` | Floor for the reduced reward (10). |
| `correctionRightRewardReductionLevel` | Exponent applied this trial. |
| `correctionOriginalRightRewardMs` | Right reward before reduction; 0 when no reduction applied. |
| `correctionRightRewardAppliedMs` | Right reward after reduction; 0 when no reduction applied. |
| `correctionSnapshotValid` | 1 if the exact trigger condition was restored. |
| `correctionControlWindow` | Whether the live control window is in use. |

**Inactive in this variant** — present in every trial, always `NaN` or `0`:

- Luminance mode: `ActualLuminanceT1/T2`, `ActualLuminanceT1/T2_x1000`,
  `NominalLuminanceT1/T2`, `LuminanceDifferenceT1MinusT2`,
  `LuminanceDifferenceMagnitude`, `LuminancePairMean`,
  `MeasuredLuminanceT1/T2CdM2`, `MeasuredLuminanceT1/T2_x100`,
  `ActualDklRedLuminanceT1/T2`, `DklRedLuminanceDifferenceT1MinusT2`,
  `BackgroundDklLuminance`, `BackgroundMeasuredLuminanceCdM2`,
  `T1_luminance`, `T2_luminance`.
- Direct-RGB C24 mode: `displayModeCode` (set to 1),
  `T1/T2_colorRGB255` (`[0 0 0]`), `T1/T2_redLevel`, `DirectRgbT1R/G/B`,
  `DirectRgbT2R/G/B`, `DirectRgbPairDesiredMeanCdM2`,
  `DirectRgbPairMeasuredMeanCdM2`, `DirectRgbBackgroundCdM2_x1000`.
- Change-detection ancestry: `speedDelta`, `contDelta`, `orientDelta`,
  `freqDelta`, `satDelta`, `lumDelta`, `hueDelta`, `stimLoc1Elev`,
  `stimLoc1Ecc`, `stimLoc2Elev`, `stimLoc2Ecc`, `stimRadius`, `motionDir`,
  `isCueChangeTrial`, `isFoilChangeTrial`, `isNoChangeTrial`, `cueIsOn`,
  `cueStimIsOn`, `foilStimIsOn`, `fix2CueIntvl`, `cueDur`, `cue2StimItvl`,
  `stim2ChgIntvl`, `chgWinDur`, `cueChangeTime`, `foilChangeTime`,
  `hitRwdTime`, `corrRejRwdTime`, `stimDur`, `stimFrames`, `nEpochs`,
  `joyMinLatency`, `joyMaxLatency`, `joyWaitDur`, `joyReleaseWaitDur`,
  `rwdJoyPR`, `wantEndFlicker`, and the `*Init`/`*Var` stimulus-feature fields.
  `timingInfo` still computes several of these each trial, so they carry
  non-constant values that mean nothing here.
- Photometer actions: `measureRedLumRampWithI1`, `scanDklRedLumWithI1`,
  `findGrayBgWithI1`, `redRgbScan*`, `i1Ramp*` — all `false`/defaults.
- `useQuest` is `false`; `connectRipple` is `true` and `rippleChanSelect`/
  `useOnlineSort` are set, but this task never calls `pds.getRippleData`, so
  no Ripple data is embedded in the PLDAPS files (§7).
- `postFlip` — `logical` (false) and `varNames` (empty cell) at save time.

### 6.8 `p.trData`

Everything measured or decided during the trial. Reset before each trial from
`p.init.trDataInitList`.

**Raw analog and digital buffers** — read from the DataPixx in `_finish` by
`pds.readDatapixxBuffers`, covering the whole trial.

| Field | Description |
|---|---|
| `eyeX`, `eyeY` | Eye position, **raw ADC volts** (channels 0 and 1), sampled at 1000 Hz. Convert to degrees with `deg = 4 × volts`. Positive Y is up. |
| `eyeP` | Pupil signal, raw volts (channel 2). |
| `joyV` | Joystick voltage (channel 3). |
| `eyeT` | Sample timestamps in seconds on the **DataPixx clock**. Same clock as `timing.trialStartDP`; subtract it to get time relative to trial start. |
| `dInValues`, `dInTimes` | DataPixx digital input log values and timestamps. |
| `missedFrameCount` | Flips in this trial separated by more than 1.5 frame durations. |

The ADC buffer holds 15 s at 1000 Hz and is read and restarted each trial, so a
trial longer than 15 s would lose its earliest samples.

**Online gaze** — sampled once per polling-loop iteration, not at a fixed rate.

| Field | Description |
|---|---|
| `onlineGaze` | nIterations×4: `[eyeDegX, eyeDegY, t, velocity]`. `t` is seconds relative to `trialStartPTB`; velocity is °/s from the 5-tap filter and is `NaN` for the first 5 rows. |
| `onlineEyeX`, `onlineEyeY` | Columns 1 and 2 of the above, kept separately. |

**Trial condition** — copied from `trVars` in `_next` so the condition survives
in `trData` independently.

| Field | Description |
|---|---|
| `currentTrialsArrayRow`, `conditionID`, `nStim`, `singleTargetID`, `T1Side`, `T2Side`, `schedulePhase` | As in §6.7. |
| `correctionTrialEnabled`, `correctionBothSides`, `correctionTrialTriggerSide`, `correctionTrialActive`, `correctionTrialRepetition`, `correctionRightRewardReductionLevel`, `correctionTrialMaxRepetition`, `correctionReduceRightReward`, `correctionRightRewardMultiplier`, `correctionRightRewardMinimumMs`, `correctionRightRewardAppliedMs`, `correctionOriginalRightRewardMs`, `correctionSnapshotValid` | Pre-trial correction state for this trial. |

**Choice and outcome**

| Field | Description |
|---|---|
| `chosenTargetID` | **Identity chosen**: 1 = T1, 2 = T2, 0 = none. The primary choice variable. |
| `chosenSide` | **Side chosen**: 1 = right, 2 = left, 0 = none. |
| `choseHighSalience` | 1 if the chosen side matched `status.highSalienceSide`. On instruction trials it is set to 1 unconditionally. |
| `outcome` | String: `'CHOSE_HIGH_SAL'`, `'CHOSE_LOW_SAL'`, `'SINGLE_T1_CORRECT'`, `'SINGLE_T2_CORRECT'`, or `""` on failure. |
| `outcomeCode` | 1 = chose high salience, 2 = chose low salience, 10 = instruction T1 correct, 11 = instruction T2 correct, 0 = failed trial. **These encode the salience choice, not the reward choice.** |
| `failureReason` | String; see §5.1. `""` on success. |
| `feedbackTone` | Which tone was played: `"highReward"`, `"lowReward"` or `"failure"`. |
| `trialEndState` | State ID at trial end. See §5.1. |
| `GoodTrial` | `trialEndState == 455`. |
| `trialRepeatFlag` | `~GoodTrial` for ordinary trials; forced to `true` on a trial that triggers or continues a correction sequence. |
| `landingEyeDegX`, `landingEyeDegY` | Gaze position in degrees at the moment landing was classified. `NaN` if no saccade was made. |
| `deliveredRewardDurationMs` | Reward actually delivered, in ms. `NaN` on failed trials. |
| `expectedCorrectionRightRewardMs` | Reward the correction logic expected for the right side; `NaN` when not applicable. |
| `correctionRewardConsistencyPassed` | 1 = the delivered value matched the expectation, 0 = it was repaired, −1 = not checked. |
| `strobed` | Vector of every value actually strobed during this trial, in order. **This is the definitive record of the digital stream for the trial** (§7). |
| `spikeTimes`, `spikeClusters`, `eventTimes`, `eventValues` | Ripple fields defined by `pds.getRippleData`. This task never calls it, so these are absent. |

**`p.trData.timing`**

All values are seconds relative to `trialStartPTB` unless noted. `−1` means the
event did not occur.

| Field | Description |
|---|---|
| `trialStartPTB` | **Absolute** PTB `GetSecs` timestamp at the top of `_run`. Master reference. |
| `trialStartDP` | **Absolute** DataPixx timestamp captured at the same instant. Use together with `trialStartPTB` to convert between clocks. |
| `trialBegin` | State 1 entered. Essentially 0. |
| `fixOn` | Fixation point first displayed. Frame-locked (postFlip). |
| `fixAq` | Fixation acquired. |
| `fixHoldReqMet` | `fixDurReq` satisfied; transition into `targetDelay`. |
| `targetOn` | Targets first displayed. Frame-locked (postFlip). |
| `fixOff` | Fixation point extinguished — **the go signal**. Frame-locked (postFlip). |
| `saccadeOnset` | Saccade initiation detected. |
| `saccadeOffset` | Gaze entered a target window and velocity fell below threshold. |
| `targetAq` | Target acquired. Same value as `saccadeOffset`. |
| `reward` | Reward solenoid schedule started. |
| `tone` | Feedback tone. **Computed as `Datapixx('GetTime') − trialStartPTB`**, mixing the DataPixx and PTB clocks, so it is not on the same axis as the other fields. To time the tone, use the strobed tone code (§7) or infer it from `reward`, which is issued immediately after on successful trials. |
| `fixBreak` | Fixation break of any kind, including the `inaccurate` and `noResponse` end states, which also write this field. |
| `fixBreakDuringDelay` | Set **only** for breaks during the target-delay period. Use this to separate delay-period breaks from other breaks. |
| `brokeFix`, `brokeJoy`, `joyPress`, `joyRelease` | Inherited fields. `joyRelease` is written with the time of a non-start; the others stay −1. |
| `stimOn`, `stimOff`, `cueOn`, `cueOff`, `cueChg`, `foilChg`, `noChg` | Inherited from the change-detection ancestor. Always −1. |
| `flipTime` | Vector of **absolute** PTB flip timestamps. Subtract `trialStartPTB` to place on the common axis. |
| `lastFrameTime` | Time of the most recent flip, relative. This is the value the postFlip mechanism assigns. |
| `trialEnd` | Written twice: at state-machine exit in `_run`, then overwritten in `_finish` after the strobe pass. The saved value is the later one. |
| `trialEndPTB`, `trialEndDP` | **Absolute** PTB and DataPixx timestamps at the end of `_finish`. |

**Reaction time** is `timing.saccadeOnset − timing.fixOff`, valid only when both
are `> 0`.

---

## 7. Event codes and the Ripple digital stream

### 7.1 How strobing works

Event codes are 15-bit integers (0–32767) written to the DataPixx digital
output by `pds.classyStrobe`. Each strobe sets the 15 data bits, pulses a
strobe line, then clears. The Ripple system records these as parallel-port
digital events.

Two strobe paths exist:

- **`strobeNow(code)`** — emitted immediately, inside the polling loop.
- **`addValueOnce(code)`** — queued and emitted by `strobeList` immediately
  after the next `Screen('Flip')`, so the code is frame-locked to the visual
  event. A veto list prevents the same code being queued twice in a trial.

`p.trData.strobed` records every value emitted during the trial, in order.

### 7.2 The per-trial parameter strobe list

`p.init.strobeList` is a large table of `{codeName, valueExpression}` pairs
intended to transmit the trial's full condition at the end of each trial, as
(code, value) pairs. It is evaluated by `pds.strobeTrialData` in `_finish`.

The first row of the list is `{'taskCode', 'p.init.taskCode'}`.
`p.init.taskCode` is assigned by `pds.initTaskMetadata`, which
`srsSmooth_settings.m` does not call, so the field does not exist.
`pds.strobeTrialData` wraps its entire loop in a single `try`/`catch`, so
evaluating row 1 raises an error that exits the loop before any value has been
queued; the subsequent `strb.strobeList` call then finds an empty queue.

The practical consequence for analysis: **the digital stream contains the
event/timing codes listed in §7.3, and does not contain the per-trial parameter
codes listed in §7.4.** Trial condition must be recovered by pairing the
digital stream to the PLDAPS trial files. Confirm this per session by
inspecting `p.trData.strobed`, which is the authoritative record of what was
emitted.

### 7.3 Codes that reach the stream

Emitted by the state machine, `pds.deliverReward` and `playTone`.

| Code | Name | Emitted | Timing |
|---:|---|---|---|
| 30001 | `trialBegin` | Start of every attempt | Loop-timed, ~0 s |
| 3001 | `fixOn` | Fixation point displayed | **Frame-locked** |
| 3004 | `fixAq` | Fixation acquired | Loop-timed |
| 22004 | `nonStart` | Fixation never acquired | Loop-timed |
| 4001 | `targetOn` | Targets displayed | **Frame-locked** |
| 3003 | `fixOff` | **Go signal** | **Frame-locked** |
| 3005 | `fixBreak` | Any fixation/target-hold break, and blink detection | Loop-timed |
| 2003 | `saccadeOnset` | Saccade initiation | Loop-timed |
| 3009 | `noResponse` | Response window elapsed | Loop-timed |
| 3010 | `inaccurate` | Landing outside both windows, or flight time exceeded | Loop-timed |
| 2007 | `blinkDuringSac` | Gaze beyond ±35° after go signal | Loop-timed |
| 2004 | `saccadeOffset` | Landing classified | Loop-timed |
| 4004 | `targetAq` | Target acquired (same instant as `saccadeOffset`) | Loop-timed |
| 8000 | `reward` | Solenoid schedule started | Loop-timed |
| 9003 | `highTone` | Feedback: **rich identity chosen** (900 Hz) | Loop-timed |
| 9002 | `noiseTone` | Feedback: **poor identity chosen** (450 Hz) | Loop-timed |
| 9001 | `lowTone` | Feedback: **failed trial** (150 Hz) | Loop-timed |
| 30009 | `trialEnd` | **Twice per attempt**: at state-machine exit, and again in `_finish` | Loop-timed |

The tone codes are the buffer-address aliases, not new codes — `playTone` maps
`highReward → highTone`, `lowReward → noiseTone`, `failure → lowTone`. Because
of this, **9003 versus 9002 distinguishes a rich from a poor choice directly in
the digital stream**, which is the one piece of trial-outcome information
available without pairing to the PLDAPS files.

### 7.4 Parameter codes defined in `strobeList`

Listed for completeness, and because `p.init.codes` in `p.mat` contains them.
These are paired strobes: the code integer followed immediately by its value.

| Code | Name | Value convention |
|---:|---|---|
| 32000 | `taskCode` | Followed by a `uniqueTaskCode_*` value (SRS = 32023) |
| 11102 / 11103 / 11104 | `date_1yyyy` / `date_1mmdd` / `time_1hhmm` | Leading `1` prepended; strip it |
| 11002 | `trialCount` | `p.status.iTrial` |
| 11100 | `goodTrialCount` | `p.status.iGoodTrial` |
| 20000 | `CurrentBlockNumber` | Block index |
| 20001 | `CurrentBlockType` | 1 = T1 rich, 2 = T2 rich |
| 20005 | `salienceType` | 1 = hue, 2 = DKL luminance, 3 = direct RGB |
| 20009 | `backgroundHueIdx` | 1 = DKL 0° background, 2 = DKL 180° |
| 20025 / 20026 | `ActualHueT1_x10` / `ActualHueT2_x10` | Hue angle × 10 (0–3600) |
| 20027 | `BackgroundHue_x10` | Background hue × 10 |
| 20028 / 20029 | `HueContrastT1_x10` / `HueContrastT2_x10` | Contrast × 10 (200 or 1800) |
| 20015 / 20016 | `T1_colorIdx` / `T2_colorIdx` | CLUT index 20–23 |
| 20017 | `nStim` | 1 or 2 |
| 20018 | `singleTargetID` | 0 = dual, 1 = T1, 2 = T2 |
| 20019 / 20020 | `T1Side` / `T2Side` | 1 = right, 2 = left |
| 20022 | `schedulePhase` | 1 = instruction, 2 = choice |
| 20021 | `chosenTargetID` | 0 = none, 1 = T1, 2 = T2 |
| 16022 | `highSalienceLocation` | `p.status.highSalienceSide`: 1 = right, 2 = left |
| 16021 | `highRewardLocation` | `p.status.highRewardSide`: 1 = right, 2 = left |
| 16023 | `chosenTarget` | `p.trData.chosenSide`: 0/1/2 |
| 16029 | `choseHighSalience` | 0 or 1 |
| 16024 | `outcomeCode` | See §6.8 |
| 20003 / 20004 | `ActualRichReward` / `ActualPoorReward` | Milliseconds |
| 20051 | `delta` | Target delay in ms (450) |
| 20040–20053 | `correction*` | Correction metadata; see §4.6 |
| 20006 / 20007 | `ActualLuminanceT1` / `ActualLuminanceT2` | × 1000. `NaN` in hue mode |
| 20023 / 20024 | `MeasuredLuminanceT1_x100` / `...T2_x100` | × 100. `NaN` in hue mode |
| 20030–20039 | `displayModeCode`, `DirectRgb*` | Direct-RGB mode only |

Scaling conventions: `_x10`, `_x100`, `_x1000` suffixes mean the value was
multiplied by that factor and rounded before strobing, to keep it an integer
under 32767. Divide to recover. Angles use `_x10` because `_x1000` overflows
above 32.767°.

### 7.5 Aligning PLDAPS trials to the Ripple recording

The PLDAPS files contain **no** Ripple data: `pds.getRippleData` is never
called by this task, and `p.rig.connectToOmniplex` is false on rig 1. Spikes
and digital events must be read from the Trellis files and aligned via the
digital event stream.

A workable procedure:

1. **Segment the digital stream into attempts.** Each attempt runs from a
   `trialBegin` (30001) to the second of its two `trialEnd` (30009) codes.
2. **Drop non-starts.** An attempt containing `nonStart` (22004) has no
   corresponding `trial####.mat`. Removing these makes the remaining attempts
   correspond one-to-one, in order, with the sorted trial files. Cross-check
   with the file numbering: the gaps must coincide.
3. **Anchor within a trial.** Use `fixOff` (3003) as the primary anchor. It is
   frame-locked, occurs exactly once per attempt that reached the go signal,
   and is the event most analyses are aligned to. `targetOn` (4001) and
   `fixOn` (3001) are equally reliable anchors and also frame-locked.
4. **Map to PLDAPS time.** Within a trial, PLDAPS times are relative to
   `timing.trialStartPTB`. The offset between the Ripple timestamp of an anchor
   code and the corresponding `p.trData.timing` value gives the per-trial
   transform. Deriving it per trial rather than once per session absorbs any
   drift between the acquisition clocks.
5. **Attach the condition.** Everything about the trial — identities, sides,
   salience, reward, block, outcome — comes from the matched trial file, using
   the fields in §6.

Sanity checks worth running: the number of segmented attempts should equal
`p.status.iTrial` on the final trial; the number of `reward` (8000) codes
should equal the number of trials with `GoodTrial == 1`; and the counts of
9003/9002/9001 should match the `feedbackTone` tallies.

---

## 8. Building an analysis trial table

The quantities most analyses need are not all stored in one place. Per trial:

| Quantity | Source |
|---|---|
| Attempt number | `status.iTrial` (or the file number) |
| Block | `status.CurrentBlockNumber` |
| Rich identity | `status.CurrentBlockType` (= `status.highRewardTargetID`) |
| Rich side | `status.highRewardSide` |
| High-salience identity | `status.highSalienceTargetID` |
| High-salience side | `status.highSalienceSide` |
| Trial type | `status.ActualTrialType` (0/1/2) |
| Instruction vs choice | `trData.nStim` (1/2) |
| T1 side | `trData.T1Side` |
| Chosen identity | `trData.chosenTargetID` |
| Chosen side | `trData.chosenSide` |
| Success | `trData.GoodTrial` |
| Failure cause | `trData.failureReason` |
| Reaction time | `trData.timing.saccadeOnset − trData.timing.fixOff` |
| Reward delivered | `trData.deliveredRewardDurationMs` |
| Rich/poor samples | `status.ActualRichReward`, `status.ActualPoorReward` |
| Forced repeat | `trData.correctionTrialActive` |

Derived measures:

```matlab
choseRich  = GoodTrial & nStim==2 & (chosenTargetID == highRewardTargetID);
choseHighSal = GoodTrial & nStim==2 & (chosenTargetID == highSalienceTargetID);
choseRight = GoodTrial & (chosenSide == 1);
```

Three points that change results if missed:

- **`outcomeCode` and `choseHighSalience` describe the salience choice.** The
  reward choice must be derived by comparing `chosenTargetID` to
  `highRewardTargetID`. On congruent trials these coincide; on conflict trials
  they are opposite, which is the entire point of the design.
- **Restrict choice analyses to `nStim == 2`.** Instruction trials have only
  one available target and their salience assignment is random and independent
  of what is shown.
- **Correction repeats are not independent observations.** A conflict condition
  can be forced up to 15 times in a row. Filter on
  `trData.correctionTrialActive == 0` for analyses that assume independence, or
  model the sequence explicitly.

A consistency check worth running once per session: for every successful trial,
`chosenSide` should equal `T1Side` when `chosenTargetID == 1` and `T2Side` when
`chosenTargetID == 2`. Any violation means an identity/side mapping problem.

---

## 9. Related files

| Path | Purpose |
|---|---|
| `tasks/SRS_Task_Smooth/srsClassic_Moretraining_settings.m` | Variant settings |
| `tasks/SRS_Task_Smooth/srsSmooth_settings.m` | Base settings; `p.init.strobeList` and `p.init.trDataInitList` live here |
| `tasks/SRS_Task_Smooth/srsSmooth_run.m` | State machine and drawing |
| `tasks/SRS_Task_Smooth/supportFunctions/nextParams.m` | Per-trial condition, salience and reward assignment |
| `tasks/SRS_Task_Smooth/supportFunctions/buildSrsBlockSchedule.m` | Block schedule construction |
| `tasks/SRS_Task_Smooth/supportFunctions/updateTrialsList.m` | Schedule eligibility and correction-trial logic |
| `tasks/SRS_Task_Smooth/supportFunctions/initClut.m` | CLUT and DKL colour definitions |
| `tasks/SRS_Task_Smooth/SRS_behavior_analysis_2/srs_load_session.m` | Existing session loader producing a flat trial table |
| `+pds/initCodes.m` | Event code definitions (also saved into every session as `p.init.codes`) |
| `+pds/saveP.m`, `+pds/loadP.m` | Save and load implementation |
| `<session>/srsSmooth.zip` | The exact task code that produced that session |
