# Barsweep Task Implementation Plan

## Purpose
This document defines the implementation plan for a new passive-fixation `barsweep` task in PLDAPS. The task is intended for offline analysis of stimulus-direction preferences and related receptive-field characterization using a translating bar stimulus. It is a near-direct port of collaborator code in `/home/herman_lab/Downloads/feng_LGN/`, adapted to PLDAPS conventions for trial structure, saving, rig detection, and strobing.

## High-Level Design

### Core Behavioral Structure
- Passive fixation only.
- One bar sweep per trial.
- Fixation must be acquired and held continuously through the entire sweep to receive reward.
- A fixation break before sweep completion aborts the trial without reward.
- Session terminates when **every angle has been rewarded `setRepeats` times** (default 50 rewarded sweeps per angle, ⇒ ≥ 200 rewarded trials, plus whatever aborted attempts are needed to reach that total).

#### Canonical trial timeline
Two distinct end-of-trial markers, separated to avoid the historical ambiguity in PLDAPS where `trialEnd` was overloaded across `_run.m` and `_finish.m`:

- **`trialRunDone`** — emitted exactly once, immediately after the behavioral while-loop in `_run.m` exits, regardless of outcome. **Not flip-locked**: it uses the same trial-relative `GetSecs - trialStartPTB` clock as other run-loop timing variables, but is not gated on a post-flip assignment. Marks "behavioral execution complete."
- **`trialEnd`** — emitted exactly once, in `_finish.m`, **after** `pds.strobeTrialData` (so all parameter strobes are upstream of `trialEnd`) and **before** any post-trial waits. Marks "trial record sealed." The gap `trialEnd[N] → fixOn[N+1]` contains the post-trial waits (`postRewardDuration`, `timeoutAfterFixBreak`, `iti`) **plus** next-trial setup work in `_next.m` (GUI copy, parameter validation, sweep precompute, texture pre-build) and harness overhead between callbacks. Configured `iti` is **not cleanly recoverable** from this gap by subtraction — for that, read `p.trVars.iti` from the saved per-trial `.mat`. The strobe-stream gap is useful as an upper bound on configured ITI and for detecting gross timing pathologies, not as a precise ITI measure.

`trialRunDone` is a new code added to `+pds/initCodes.m` (`30008`); existing `trialEnd` (`30009`) is reused with the narrowed semantics above.

```
Reward branch (trialComplete):
  trialBegin → fixOn → (wait fixWaitDur for fixAq) → fixAq
            → stimOn (first visible bar frame, post-flip)
            → [sweepFrames visible frames, fixation enforced each frame]
            → stimOff (first blank flip after the bar)
            → reward
            → trialRunDone             [strobed at end of _run.m, immediately after run-loop exit]
            (control returns to harness, _finish.m runs)
            → [_finish.m: getRippleData, readDatapixxBuffers, pool mutation, strobeTrialData, saveP, texture cleanup]
            → trialEnd                 [strobed in _finish.m, after parameter strobes, before waits]
            → postRewardDuration       [WaitSecs in _finish.m, after trialEnd]
            → iti                      [WaitSecs in _finish.m, after postRewardDuration]
            (next trial)

fixBreak branch:
  trialBegin → fixOn → fixAq → stimOn → [partial sweep] → fixBreak → stimOff
            → trialRunDone             [strobed at end of _run.m]
            → trialEnd                 [strobed in _finish.m, after parameter strobes]
            → timeoutAfterFixBreak
            → iti
            (next trial)

nonStart branch:
  trialBegin → fixOn → (fixWaitDur expires with no fixAq) → nonStart
            → trialRunDone             [strobed at end of _run.m]
            → trialEnd                 [strobed in _finish.m, after parameter strobes]
            → timeoutAfterFixBreak
            → iti
            (next trial)
```

**One-rule statement (mandatory acceptance criterion):** `trialRunDone` is emitted exactly once per trial, at the end of `barsweep_run.m`, never in `barsweep_finish.m`. `trialEnd` is emitted exactly once per trial, in `barsweep_finish.m`, after `pds.strobeTrialData` and before any `WaitSecs`, never in `barsweep_run.m`. Phase 4 validation must round-trip-decode both strobes from one trial of each outcome and confirm exactly one of each, in that order.

Every named interval (`fixWaitDur`, `postRewardDuration`, `timeoutAfterFixBreak`, `iti`) must be implemented somewhere in the run/finish flow. If any one of them ever ends up unused, either remove it from the spec or wire it in — silent drift from the source timing is unacceptable.

**Note on existing repo state:** other tasks (rfMap, fixate) currently strobe `trialEnd` in both `_run.m` and `_finish.m`; conflict_task only in `_finish.m`. barsweep adopts the new split convention and does **not** retrofit those tasks. Future work could standardize them, but that is out of scope here.

### Direction Schedule (balanced sampling)
The single governing invariant is **balance across rewarded sweeps**.

- Direction is drawn without replacement from a fixed angle list.
- Default angle list: `[0 90 180 270]`.
- Each "set" consumes a shuffled pass through the full angle list, then re-shuffles.
- A "completed set" is one in which every angle in the list has been rewarded once.
- After `setRepeats` completed sets, the session ends.

#### State machine: peek-in-`_next`, mutate-in-`_finish`
The pool is mutated in exactly one place (`_finish.m`). `_next.m` only reads.

| Step | File | Effect on `barsweepPool` | Effect on `barsweepSetsCompleted` |
|---|---|---|---|
| Select angle for upcoming trial | `_next.m` | **Peek** front of pool (read, no removal). | unchanged |
| Trial outcome = `trialComplete` (rewarded) | `_finish.m` | Remove the trial's angle from the front of the pool. If pool is now empty, increment sets-completed and re-shuffle a fresh full pool. | +1 iff this removal emptied the pool |
| Trial outcome = `fixBreak` | `_finish.m` | unchanged | unchanged |
| Trial outcome = `nonStart` | `_finish.m` | unchanged | unchanged |

Consequence: an aborted angle is retried on the next trial because it was never removed from the pool. Total rewarded trials = `setRepeats × nAngles`; total attempted trials may exceed this depending on the abort rate.

### Core Stimulus Structure
- A bar translates linearly across the screen along a direction-of-motion `pathAngleDeg` set per trial from the schedule.
- The bar's long axis is always perpendicular to the direction of motion.
- Sweep trajectory is centered on `(pathCenterXDeg, pathCenterYDeg)` and spans `pathLengthDeg`, traversed at `speedDegPerSec`.
- Sweep duration is therefore `pathLengthDeg / speedDegPerSec`.
- Bar geometry: `barWidthDeg` (thickness, perpendicular to motion) and `barLengthDeg` (total end-to-end length along the long axis — 1:1 mapping, not the source's half-length convention).

### Stimulus Appearance Modes
- `stimulusMode`: 1 = noise (default), 2 = solid.
- `noise` mode: bar region contains a binary checker texture refreshed every flip; texture rotated to match the bar's orientation. Background remains uniform. Mirrors `Stm.BarNoiseTexture = true` in `stim_barsweep.m`.
- `solid` mode: uniform bar luminance against uniform background luminance.
- Default `noiseCheckSizeDeg = 0.25` (matches `Stm.BarNoiseGrain_dva = 0.25`).

### Fixation
- Fixation point is positioned independently of the sweep center, via `fixDegX/fixDegY`.
- `fixWinWidthDeg/fixWinHeightDeg` define the acceptance window.
- Fixation point uses a "pre / fix / go" color scheme as in the source if desired (optional polish; not required for v1).

### Reward
- Delivered after the bar sweep completes with fixation continuously held.
- Standard PLDAPS reward path: `pds.deliverReward(p)`.

## Design Decisions Locked

1. The task is a brand-new `barsweep` task with a new unique task code.
2. The task uses standard hostname-based rig detection.
3. Fixation position and sweep-path-center position are configurable independently in dva.
4. One sweep per trial; trial duration is determined by sweep duration plus fixation lead-in and post-reward intervals — no separate `trialDurationS` variable.
5. Reward is gated on fixation held through the full sweep.
6. Direction is drawn without replacement from `[0 90 180 270]`; configurable angle list deferred.
7. Bar long axis is always perpendicular to path; no GUI toggle in v1.
8. `barWidthDeg` is bar thickness (perpendicular to motion). `barLengthDeg` is total end-to-end length along the bar's long axis, with a 1:1 mapping (no source-style 2× rendering).
9. Default appearance is `noise`; solid is selectable via flag.
10. Mouse-controlled centering is deferred to a later version. v1 uses static `pathCenterXDeg/YDeg`.
11. Photodiode patches are not implemented in v1.
12. Session terminates when every angle has been rewarded `setRepeats` times (default 50 per angle ⇒ 200 rewarded trials). Aborted trials (`fixBreak`, `nonStart`) leave the angle pool unchanged, so the same angle is retried on the next trial until rewarded.

## Relationship to Existing Code

### Collaborator Reference Code
Files reviewed in `/home/herman_lab/Downloads/feng_LGN/`:
- `runstim_rfmap_lgn2.m` — master experiment loop and `STIMTYPE` dispatcher.
- `run_BarSweep.m` — per-trial bar-sweep executor.
- `stim_barsweep.m` — stimulus parameter file (the `Stm` struct).
- `par_NIN_RN3s132.m` — rig/hardware/par file.

Key facts established by reading the source:
- The bar's long axis is hard-coded perpendicular to motion: `BarAng = Stm.Ang(I) + 90`.
- `BarLength_dva` in the source is half-length: the rendered polygon and the noise destination rect both use `2 * BarLength`, so the on-screen bar spans `2 * BarLength_dva`. **Our task corrects this** — `barLengthDeg` here means total end-to-end length.
- Direction sampling uses `randperm(length(Stm.Ang))` per set, with `Stm.SetRepeats = 50` complete sets per session.
- `BarNoiseTexture = true` is the default appearance — every flip generates a fresh binary noise texture, rotated to match the bar.
- The source draws photodiode patches; we omit them.
- The source uses `dasbit/dasword` for ephys event marking; we use `pds.classyStrobe` and `pds.strobeTrialData`.

### Behavioral Departures from Source (intentional)
- `fixDegX/Y` is independent of `pathCenterXDeg/Y` (source ties fix dot to a single `Stm.Fxy_dva`).
- Photodiode patches omitted.
- Color cycling for solid mode (source toggles white/black across trials) deferred — solid color is fixed per session via `barLumIdx`.

### In-Repo PLDAPS Patterns to Follow
- Hostname-based rig config selection:
  - e.g. [rfMap_commonSettings.m](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/tasks/rfMap/rfMap_commonSettings.m:1)
  - e.g. [fixate_settings.m](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/tasks/fixate/fixate_settings.m:1)
- Task metadata and unique task code resolution:
  - [initTaskMetadata.m](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/+pds/initTaskMetadata.m:1)
- Trial-end parameter strobes via `p.init.strobeList`:
  - [rfMap_commonSettings.m](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/tasks/rfMap/rfMap_commonSettings.m:341)
  - [conflict_task_settings.m](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/tasks/conflict_task/conflict_task_settings.m:486)
- Polar (theta, radius) location encoding for negative-safe strobing:
  - conflict_task `targetTheta` / `targetRadius` pattern.
- Per-frame texture refresh pattern reusable for noise mode:
  - [generateNoiseTextures.m](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/tasks/rfMap/supportFunctions/generateNoiseTextures.m:1)

## Task Directory and Files

### New Task Directory
`tasks/barsweep/`

### Quintet Files
- `barsweep_settings.m`
- `barsweep_init.m`
- `barsweep_next.m`
- `barsweep_run.m`
- `barsweep_finish.m`

### Expected Support Functions
- `supportFunctions/initClut.m`
- `supportFunctions/defineVisuals.m`
- `supportFunctions/initTrData.m`
- `supportFunctions/nextParams.m` — **peeks** the front of `p.status.barsweepPool` for the upcoming trial and snapshots the pool into `p.status.barsweepPoolAtTrialStart`. It does **not** mutate the pool. All pool mutation (removal on reward, re-shuffle on set completion) lives in `_finish.m`, per the schedule state-machine table.
- `supportFunctions/postTrialTimeOut.m`
- `supportFunctions/playTone.m`
- `supportFunctions/updateStatusVariables.m`
- `supportFunctions/buildBarTexture.m` — solid bar texture; built **per trial** in `_next.m` from the current `(barWidthDeg, barLengthDeg)` and released in `_finish.m`. Per-trial rebuild is required because those parameters are GUI-mutable.
- `supportFunctions/buildNoiseBarFrame.m` — per-flip binary noise frame for noise mode.

## Planned Task Architecture

### 1. `barsweep_settings.m`
Responsibilities:
- Define task identity and quintet filenames.
- Resolve rig config from hostname.
- Set `p.init.useDataPixxBool = true`.
- Call `pds.initTaskMetadata(p)` so the task gets a new unique task code via `p.init.taskName = 'barsweep'`.
- Define state IDs, GUI variables, status variables, trial variables, `trData` initialization, and `p.init.strobeList`.

#### State machine
- `trialBegun`
- `showFix`
- `holdFixAndSweep`
- `trialComplete`
- `fixBreak`
- `nonStart`

#### GUI-exposed task variables
- `rewardDurationMs`
- `fixWinWidthDeg`
- `fixWinHeightDeg`
- `fixDegX`
- `fixDegY`
- `pathCenterXDeg`
- `pathCenterYDeg`
- `pathLengthDeg`
- `speedDegPerSec`
- `barWidthDeg`
- `barLengthDeg`

`pathAngleDeg` is **not** GUI-exposed — it is set by the schedule.

#### Other (non-GUI) trVarsInit
- `stimulusMode` (1 = noise, 2 = solid)
- `backgroundLumIdx`
- `barLumIdx`
- `noiseLumLowIdx`
- `noiseLumHighIdx`
- `noiseCheckSizeDeg`
- `noiseFrameHold` (default 1; not strobed in v1)
- `mouseEyeSim`
- `passEye`
- `fixWaitDur`
- `timeoutAfterFixBreak`
- `postRewardDuration`
- `iti`
- `setRepeats` (default 50) — scalar, **GUI-editable** until the session starts. **Session-immutable** *after the first trial begins*: snapshotted into `p.init.barsweepSchedule.setRepeats` lazily, on the first `_next.m` call (when `p.status.iTrial == 0` transitions to `1`, after `p.trVars = p.trVarsGuiComm`). The termination rule reads only the frozen `p.init.barsweepSchedule.setRepeats`; subsequent GUI edits to `p.trVars.setRepeats` are explicitly ignored.
- `angleList` (default `[0 90 180 270]`) — **NOT GUI-editable in v1.** The PLDAPS GUI's parameter editor at [PLDAPS_vK2_GUI.m:54–63](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/PLDAPS_vK2_GUI.m:54) and [:88–106](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/PLDAPS_vK2_GUI.m:88) only handles scalar numerics — non-scalars display as `'NaN'` and writes go through `str2double`, which silently coerces non-scalar strings to `NaN`. So the GUI cannot represent or edit `[0 90 180 270]`. v1 takes the simpler path: `angleList` is set directly in `p.init.barsweepSchedule.angleList` at session start (in `_settings.m` or `_init.m`) and is never user-editable during a session. To change angles, edit `barsweep_settings.m` (or whichever quintet file owns the assignment) and restart. This matches the "configurable angle list deferred" decision in §"Design Decisions Locked".

**Why lazy-freeze `setRepeats` (and not `angleList`):** in this codebase, operator GUI edits propagate to `p.trVarsGuiComm`, not `p.trVarsInit` ([PLDAPS_vK2_GUI.m:96](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/PLDAPS_vK2_GUI.m:96)). The operator's typical workflow is Browse → Initialize (runs `_settings.m` and `_init.m`) → tweak GUI fields → Run. Freezing `setRepeats` in `_init.m` would ignore any post-Initialize, pre-Run edits the operator made. Freezing on the first `_next.m` call captures the operator's actual intent at the moment they pressed Run. `angleList` does not need lazy-freeze because it is never GUI-editable in the first place; the canonical value lives in `p.init.barsweepSchedule.angleList` from the moment `_init.m` returns.

**Implementation rule (mandatory):** all schedule logic (initial pool build, post-set reshuffle, termination check) reads from `p.init.barsweepSchedule.*`, never from `p.trVars.*` or `p.trVarsGuiComm.*`. There is no `p.trVars.angleList` field at all in v1 — adding one would mislead readers into thinking it is operator-editable. The frozen `setRepeats` is mirrored under `p.init.barsweepSchedule.setRepeats`; the live `p.trVars.setRepeats` GUI display is informational only after trial 1.

**Future extension (post-v1):** if configurable angles are needed, the cleanest options are (a) a preset enum exposed as a scalar selector (e.g., `angleSetIdx ∈ {1: cardinals, 2: cardinals + obliques, ...}`) that maps to a fixed table in `_settings.m`, (b) editing the angle list in `_settings.m` and restarting, or (c) a dedicated non-GUI parser. None of these are in v1 scope.

#### Luminance representation
Indexed palette (1 = dark, 2 = mid, 3 = light), with numeric values held in `p.stim.luminanceLevels = [Ldark, Lmid, Llight]`. GUI-facing trVars stay index-based.

Validation in `nextParams.m` (all checked before any trial-start side effects; failure aborts the trial-start with a useful error):
- Luminance contrast:
  - `backgroundLumIdx ~= barLumIdx` in solid mode.
  - `noiseLumLowIdx ~= noiseLumHighIdx`.
- Geometry positivity:
  - `speedDegPerSec > 0`
  - `pathLengthDeg > 0`
  - `barWidthDeg > 0`
  - `barLengthDeg > 0`
  - `noiseCheckSizeDeg > 0` (noise mode only)
- Derived-quantity sanity:
  - `sweepFrames = round(pathLengthDeg / speedDegPerSec / frameInterval) >= 1`
  - `sweepFrames <= sweepFramesMax` (configurable upper bound, default 600 frames ≈ 6 s sweep at 100 Hz). Catches accidental zero or near-zero `speedDegPerSec`.
  - Projected noise-texture memory (using the formula in "Texture Pre-Build") below a configurable cap (default 64 MB).
- Spatial-undersampling warning (not a hard fail): if `speedDegPerSec / refreshRate > barWidthDeg`, log a warning that the bar is moving more than its own width per frame.
- `p.init.barsweepSchedule.angleList` non-empty and all entries finite (validated in `_init.m`, not per-trial; the field is immutable after `_init.m`).
- `setRepeats >= 1`.

### 2. `barsweep_init.m`
Responsibilities:
- Standard rig/DataPixx/audio initialization.
- Initialize CLUT and any plotting windows.
- **Set the canonical (non-GUI-editable) `angleList`**: `p.init.barsweepSchedule.angleList = [0 90 180 270];` (or whatever the settings file specifies). This field is final after `_init.m` returns; nothing else mutates it.
- **Build the initial shuffled pool**: `p.status.barsweepPool = p.init.barsweepSchedule.angleList(randperm(numel(p.init.barsweepSchedule.angleList)));`. The pool exists from the end of `_init.m` onward (so even a first-trial nonStart's `pds.saveP` initial-`p.mat` write captures a real shuffled pool, not an empty placeholder).
- **Leave `p.init.barsweepSchedule.setRepeats` unset for now.** It is populated lazily on the first `_next.m` call, after `p.trVars = p.trVarsGuiComm` runs, so it captures the operator's GUI value at Run-time (see "Lazy schedule freeze" in `_next.m`). Initialize as `p.init.barsweepSchedule.setRepeats = NaN` (or omit the field) so that a stale value from a prior session cannot leak in.
- Initialize `p.status.barsweepSetsCompleted = 0`.
- Initialize the classy strobe object.
- Cache derived constants (luminance values, screen center, frame interval).
- **Solid-mode bar texture is NOT built here.** Solid-mode geometry depends on `barWidthDeg`/`barLengthDeg`, which are GUI-mutable, so the texture is rebuilt per trial in `_next.m` alongside noise-mode pre-build (see "Texture lifetime" below). `_init.m` builds nothing texture-related.

### 3. `barsweep_next.m`
Responsibilities, **in this order**. The termination check fires first so no trial-specific side effects happen on the post-final-set call.

1. **Session-end check (first action, before any trial-specific work):** if `p.status.iTrial >= 1` (i.e., `setRepeats` has already been frozen by a prior trial) AND `p.status.barsweepSetsCompleted >= p.init.barsweepSchedule.setRepeats`, set `p.trVars.barsweepSessionDone = true` and return immediately. Do not increment `iTrial`, do not copy GUI vars, do not peek the pool, do not pre-build textures. The downstream stop behavior is specified in "Session termination mechanism" below.
2. Increment `p.status.iTrial`.
3. Copy `p.trVarsGuiComm` into `p.trVars`.
4. **Lazy `setRepeats` freeze (first trial only)**: if `p.status.iTrial == 1`, populate the frozen `setRepeats` from the just-copied `p.trVars`:
   ```matlab
   if p.status.iTrial == 1
       p.init.barsweepSchedule.setRepeats = p.trVars.setRepeats;
   end
   ```
   This captures the operator's GUI value at the moment Run was pressed (edits flow through `p.trVarsGuiComm`, which step 3 just copied into `p.trVars`). After this point, the frozen `p.init.barsweepSchedule.setRepeats` is the only authority for the termination rule; live `p.trVars.setRepeats` edits are ignored. **`angleList` is not lazy-frozen here** — it was set in `_init.m` and is not GUI-editable (see "Other (non-GUI) trVarsInit" above).
5. Initialize trial data (timing variables to -1, etc.).
6. **Peek** the next angle from `p.status.barsweepPool` (read the front element without removing it) and store it as `p.trVars.pathAngleDeg`. The pool is not mutated here — see the schedule state-machine table above; mutation happens only in `_finish.m`.
7. Snapshot the pool at trial start into both `p.status.barsweepPoolAtTrialStart` and `p.trData.barsweepPoolAtTrialStart`. Storing it in `trData` as well makes the snapshot trial-local in the saved per-trial `.mat`, rather than only inferable from the appended `status` block.
8. Resolve trial-specific stimulus parameters and run the validation guards listed under "Validation in `nextParams.m`".
9. Precompute the sweep trajectory (`sweepStartPix`, `sweepEndPix`, `sweepFrames`, `sweepDurationS_nominal`, `sweepDurationS_visible`, `sweepDurationS_motion`, `speedDegPerSec_realized`, `sweepCenterPix`) and copy these into `p.trData` for offline use.
10. **Pre-build all bar textures for the upcoming sweep** (see "Texture Pre-Build" below). Both modes pre-build per-trial:
    - **Solid mode**: build one bar texture sized to the current `(barWidthDeg, barLengthDeg)`, store it as `p.trVars.barTextures(1)`. The remainder of the array (`2:sweepFrames`) holds copies of the same handle — drawing the same texture every frame in solid mode. Alternatively, store a single handle and have `_run.m` index `p.trVars.barTextures(1)` regardless of frame; the contract is "all textures used in the run loop are released in `_finish.m`."
    - **Noise mode**: build `sweepFrames` fresh per-frame textures here, never inside the run loop.

#### Sweep parameter handling
Convert all dva parameters to pixels using `pds.deg2pix`. Cache:
- `sweepStartPix`, `sweepEndPix` (each a 2-vector `[x; y]`)
- `sweepDurationS_nominal = pathLengthDeg / speedDegPerSec`
- `sweepFrames = round(sweepDurationS_nominal / frameInterval)`, with positivity guard
- `sweepDurationS_visible = sweepFrames * frameInterval` — the on-screen visibility window: `[stimOn, stimOff)` half-open, `sweepFrames` flips wide
- `sweepDurationS_motion = (sweepFrames - 1) * frameInterval` — the time elapsed between the bar at `sweepStartPix` (first visible flip) and the bar at `sweepEndPix` (last visible flip)
- `speedDegPerSec_realized = pathLengthDeg / sweepDurationS_motion` — the **endpoint-to-endpoint** realized speed. Defined consistently with the chosen endpoint contract: motion happens across `sweepFrames - 1` inter-frame intervals, not `sweepFrames`. Use this for offline analysis that aligns to physical bar position. Differs from nominal `speedDegPerSec` by at most one frame's worth across the sweep.
- `sweepCenterPix` — a precomputed `2 × sweepFrames` array of bar-center pixel positions, generated as
  ```
  sweepCenterPix(1, :) = linspace(sweepStartPix(1), sweepEndPix(1), sweepFrames);
  sweepCenterPix(2, :) = linspace(sweepStartPix(2), sweepEndPix(2), sweepFrames);
  ```
  This makes the endpoint contract testable: `sweepCenterPix(:, 1) == sweepStartPix` and `sweepCenterPix(:, sweepFrames) == sweepEndPix` exactly. The run loop indexes this array by frame number; it does **not** integrate per-frame deltas, which would accumulate rounding error and miss one endpoint. Per-frame deltas (`sweepDxPixPerFrame`, `sweepDyPixPerFrame`) are not cached — they are derivable from `sweepCenterPix` if a downstream consumer needs them, but the canonical positional representation is the precomputed vector.

#### Quantization contract (single source of truth for sweep timing)
The bar must occupy `sweepStartPix` on its first visible frame and `sweepEndPix` on its last visible frame. With `sweepFrames` visible frames, the bar traverses `pathLengthDeg` across `sweepFrames - 1` inter-frame motion intervals. The visible duration and the motion duration are therefore **distinct quantities** that differ by exactly one `frameInterval`:

- **Visible duration** = `sweepFrames * frameInterval`. This is the on-screen visibility window `[stimOn, stimOff)` and is what the strobe timestamps report (`stimOff − stimOn`).
- **Motion duration** = `(sweepFrames - 1) * frameInterval`. This is the elapsed time between the bar at `sweepStartPix` and the bar at `sweepEndPix`.
- **Contract chosen:** exact endpoints (geometric truth wins). Speed is approximate, off by at most `1 / (sweepFrames - 1)` (≈ 1 % at default settings).
- **Realized speed (single canonical definition):** `speedDegPerSec_realized = pathLengthDeg / ((sweepFrames - 1) * frameInterval)`. This is the endpoint-to-endpoint motion speed, defined consistently with the endpoint contract. Offline analyses that align to physical bar position should use this value, not the nominal `speedDegPerSec`. **There is no separate `_visible`-derived realized speed; the visible-window speed is not a useful kinematic quantity here, so we do not save it to avoid the bias hazard.**
- **Bookkeeping:** `_next.m` records all of: `sweepDurationS_nominal` (configured), `sweepDurationS_visible` (= `sweepFrames * frameInterval`), `sweepDurationS_motion` (= `(sweepFrames - 1) * frameInterval`), `speedDegPerSec` (nominal, as configured), and `speedDegPerSec_realized` (endpoint-motion definition above) into `p.trData`. The two duration fields are intentionally distinct so offline code that conflates "visibility" and "motion" surfaces immediately rather than silently miscomputing speed.

The timing-strobes section, the endpoint validation item, and this section now share one definition: **`sweepFrames` visible flips, `stimOn` on the first, `stimOff` on the (`sweepFrames + 1`)th, `[stimOn, stimOff)` is the half-open visibility interval of duration `sweepDurationS_visible = sweepFrames * frameInterval`. Motion endpoints are separated by `sweepDurationS_motion = (sweepFrames - 1) * frameInterval`.**

#### Texture Pre-Build (mirrors rfMap)
The single biggest timing risk in noise mode is `Screen('MakeTexture')` calls inside `_run.m` causing dropped flips. Following the [generateNoiseTextures.m](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/tasks/rfMap/supportFunctions/generateNoiseTextures.m:1) pattern, all textures are built ahead of the run loop:
- Pre-allocate `p.trVars.barTextures = zeros(1, sweepFrames);`
- For each sweep frame, generate the binary noise grid for that frame and call `Screen('MakeTexture', ...)`, storing the handle.
- In `_run.m`, the run loop only calls `Screen('DrawTexture', win, p.trVars.barTextures(f), [], destRect, rotationAngle, 0)` — no per-flip allocation. The trailing `0` is `filterMode = 0` (nearest-neighbor sampling), matching the rfMap convention at [generateNoiseTextures.m:4](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/tasks/rfMap/supportFunctions/generateNoiseTextures.m:4) and [rfMap_run.m:230](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/tasks/rfMap/rfMap_run.m:230). Without this, PTB's default bilinear filtering blurs the binary checker grid — especially after rotation — and the "binary checker" assumption no longer holds. Solid mode also passes `filterMode = 0` for consistency, though the effect is invisible on a uniform texture.
- All textures are released in `_finish.m`.
- **Error cleanup in `_next.m`:** texture allocation happens late in the `_next.m` sequence, but any code path between the first `Screen('MakeTexture')` call and successful return must close already-allocated textures before rethrowing. Wrap the texture-build loop in a `try/catch` that calls `Screen('Close', p.trVars.barTextures(p.trVars.barTextures > 0))` and zeroes the array before rethrowing the original error. Without this, a partial allocation followed by a thrown error orphans GPU handles for the rest of the session.

**Memory cost (concrete formula):** per sweep, GPU memory is approximately

```
bytes ≈ nChecksX × nChecksY × sweepFrames × bytesPerTexel
```

where `nChecksX = ceil(barLengthDeg / noiseCheckSizeDeg)`, `nChecksY = ceil(barWidthDeg / noiseCheckSizeDeg)`. **Use `bytesPerTexel = 4` for the budget calculation**, not 1: PTB allocates RGBA textures by default, internal driver/format overhead can add more, and the 1-byte estimate produces false confidence. If a future implementation actually verifies single-channel storage on both rigs (via `Screen('PreloadTextures')` profiling or equivalent), the budget can be tightened, but the spec defaults to the conservative `× 4` multiplier.

At defaults (`barLengthDeg=80`, `barWidthDeg=0.5`, `noiseCheckSizeDeg=0.25`, `sweepFrames ≈ pathLengthDeg/speedDegPerSec / frameInterval ≈ 100`), this is `320 × 2 × 100 × 4 ≈ 256 KB` of texel data per trial — still well within any reasonable VRAM budget. The formula must be re-evaluated whenever any of those four parameters is changed substantially. `nextParams.m` refuses to start a trial if the projected texel count exceeds a configurable budget (default 64 MB) to catch parameter-entry errors before they OOM the GPU. The 64 MB cap is a guard against pathological misconfiguration, not a fine-grained admission test — verify actual VRAM headroom on both rigs during Phase 4.

### 4. `barsweep_run.m`
Responsibilities:
- Standard PLDAPS while-loop: get inputs, advance state, draw, flip.
- Acquire eye each frame (`pds.getEyeJoy`).
- Enforce fixation through the entire sweep epoch.
- Present a single sweep, then transition to `trialComplete` and reward.
- Use stimulus-locked strobes via the existing post-flip mechanism.
- After the run-loop exits (regardless of outcome), emit exactly one `trialRunDone` strobe and record `p.trData.timing.trialRunDone`. Do **not** emit `trialEnd` in this file.

#### Run-loop structure
Each frame, in order:
1. `p = pds.getEyeJoy(p);`
2. Apply mouse-eye simulation if `mouseEyeSim` is enabled.
3. **Fixation check first** — see ordering rule below. In `holdFixAndSweep`, if the eye is outside the fixation window, transition to `fixBreak` and skip the completion check.
4. Advance state machine (completion / abort transitions).
5. Index sweep position from `sweepCenterPix(:, frameIdx)`.
6. Draw background, bar, fixation point, experimenter overlay.
7. Flip screen.
8. Resolve any post-flip timing assignments.

#### Ordering rule (CRITICAL — prevents rewarding broken trials)
Within `holdFixAndSweep`, the per-frame check order is:
1. Read eye position.
2. **Fixation-break check.** If the eye is out of window, transition to `fixBreak` immediately and do not draw the bar this frame.
3. Only if fixation is still held, evaluate completion: if `frameIdx == sweepFrames`, mark this as the final visible frame and arm the transition to `trialComplete` so that the next flip is the first blank flip.

Reward is reachable only via the `trialComplete` path, which is only entered when fixation was in-window on every frame including the final visible one. The state machine never checks completion before checking fixation on the same frame.

#### Sweep playback within `holdFixAndSweep`
- On entry, arm `stimOn` post-flip assignment and the `stimOn` strobe; initialize `frameIdx = 1`.
- Each frame: apply the ordering rule above. If fixation holds, look up `sweepCenterPix(:, frameIdx)` and draw the precomputed texture for this frame (`p.trVars.barTextures(frameIdx)` in noise mode, or `p.trVars.barTextures(1)` in solid mode — the per-trial static texture pre-built in `_next.m`) via `Screen('DrawTexture')` rotated to bar orientation. **No texture creation inside the run loop**, in either solid or noise mode. Increment `frameIdx` after the flip.
- After the flip that displayed `frameIdx == sweepFrames` (the final visible frame, with fixation confirmed in-window for that frame), the **next flip** (the first blank frame after the bar) arms `stimOff` post-flip and the state transitions to `trialComplete`. See "Timing-event semantics" below.
- A fixation break at any frame during the sweep transitions to `fixBreak` and aborts before reward.

#### Experimenter overlay
- Eye position trace.
- Fix window outline.
- Sweep path endpoints and current bar position annotated on the experimenter display.

### 5. `barsweep_finish.m`
Responsibilities (in order):

**0. Post-completion no-op gate (first action, before any other step):** if `p.trVars.barsweepSessionDone == true`, perform **only** the final-status append and the run-button toggle, then return. **No** `pds.getRippleData`, **no** `Screen('FillRect')`/flip, **no** `pds.readDatapixxBuffers`, **no** pool mutation, **no** `pds.strobeTrialData`, **no** `trialEnd` strobe, **no** `pds.saveP`, **no** `Screen('Close', ...)`, **no** `WaitSecs`, **no** counter updates. See "Session termination mechanism" for the full rationale.
   ```matlab
   if p.trVars.barsweepSessionDone
       status = p.status;
       save(fullfile(p.init.sessionFolder, 'p.mat'), 'status', '-append');
       runButtonObj = findall(groot, 'Tag', 'runButton');
       runButtonObj.Value = false;
       return;
   end
   ```

The remaining steps (1–9) execute **only** on real trials, never on the post-completion cycle:

1. Retrieve Ripple data if connected: `if p.rig.ripple.status; p = pds.getRippleData(p); end`.
2. Fill background and flip once to clear the bar.
3. Read DataPixx ADC/DIN buffers: `p = pds.readDatapixxBuffers(p);`.
4. Resolve trial outcome (this is the only place the pool is mutated — see the schedule state-machine table above):
   - If `trialEndState == trialComplete` (rewarded): remove this trial's angle from the front of `p.status.barsweepPool`. If the pool is now empty, increment `p.status.barsweepSetsCompleted` and re-shuffle a fresh full pool from `p.init.barsweepSchedule.angleList` (the **only** angle source; there is no `p.trVars.angleList` to read from).
   - If `trialEndState == fixBreak` or `nonStart`: **leave the pool unchanged**. The same angle will be peeked again on the next trial. The session-completion target is per-rewarded-presentation, not per-attempt.
5. Strobe end-of-trial parameter values: `p = pds.strobeTrialData(p);` (also flush strobe veto/strobed lists, matching rfMap's pattern). Note: `pds.strobeTrialData` only strobes paired entries from `p.init.strobeList`; it does **not** emit `trialEnd`. Immediately after this returns, emit exactly one `trialEnd` timing strobe and record `p.trData.timing.trialEnd`. `trialEnd` is emitted only here, never in `_run.m`, and always before any post-trial `WaitSecs`.
6. Save trial data: `pds.saveP(p);`. **Note**: on `trialEndState == nonStart`, `pds.saveP` skips both the per-trial `trialNNNN.mat` write and the `status` append into `p.mat` (see [+pds/saveP.m:27](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/+pds/saveP.m:27)). **Important exception:** the initial full `p.mat` is written *before* the nonStart check, inside the `if p.status.iTrial == 1` block (see [+pds/saveP.m:22](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/+pds/saveP.m:22)). So a first-trial nonStart still produces an initial `p.mat` on disk; only subsequent nonStarts write nothing. Auditability implications and the v1-required final-status append are spelled out in "Non-start trial auditability" below.
7. Release pre-built textures: `Screen('Close', p.trVars.barTextures(p.trVars.barTextures > 0))` and zero the array. Both modes pre-build per trial in `_next.m` and release per trial here, so there is no "static across session" texture to manage separately.
8. **Apply post-trial waits**, in this order (after `trialEnd` has been strobed and data saved). All post-trial waits live in `_finish.m`; `_run.m` performs no `WaitSecs` after reward delivery:
   - On abort (`fixBreak` or `nonStart`): `WaitSecs(p.trVars.timeoutAfterFixBreak)`.
   - On reward (`trialComplete`): `WaitSecs(p.trVars.postRewardDuration)`. **Single source of truth: this wait is imposed only here, never in `_run.m`.**
   - **All trial outcomes**: `WaitSecs(p.trVars.iti)` (inter-trial interval, matches source `Stm.ITI`). Without this step, `iti` is silently inert.
9. Update status variables and outcome counters; print one-line trial summary.
10. **Per-trial status append (v1-required, all outcomes):** unconditionally append `p.status` to `p.mat` so the on-disk record covers every attempt, including nonStarts (which `pds.saveP` skips):
    ```matlab
    status = p.status;
    save(fullfile(p.init.sessionFolder, 'p.mat'), 'status', '-append');
    ```
    See "Non-start trial auditability" for the rationale and the manual-stop coverage table.

### Session termination mechanism (single source of truth)
The GUI harness at [PLDAPS_vK2_GUI.m:491–536](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/PLDAPS_vK2_GUI.m:491) calls `_next.m → _run.m → _finish.m` unconditionally every loop iteration; the run-button toggle is only checked at line 533, *after* `_finish.m` returns. So once the session-end condition is met, exactly one full quintet cycle still executes before the harness loop exits. That post-completion cycle must be a strict no-op — otherwise it would re-strobe, re-save, re-mutate counters, or re-close textures against stale `p.trVars`/`p.trData` from the previous real trial.

The contract is therefore three layers, all gated on a single flag:

1. **`_next.m`** detects completion via `p.status.barsweepSetsCompleted >= p.init.barsweepSchedule.setRepeats`, sets `p.trVars.barsweepSessionDone = true`, and returns immediately. This is the **only** place the flag is raised. No `iTrial` increment, no GUI copy, no pool peek, no parameter validation, no texture build.
2. **`_run.m`** checks `p.trVars.barsweepSessionDone` as its **first action**, before initializing any trial timing or entering the state machine. If set, sets `p.trVars.exitWhileLoop = true` and returns immediately. No `trialBegin` strobe, no behavioral state machine, no flips.
3. **`_finish.m`** checks `p.trVars.barsweepSessionDone` as its **first action**, before any other step in the responsibilities list. If set, the function performs **only** (a) a final `status` append to `p.mat` (see "Non-start trial auditability") and (b) the run-button toggle (mirroring [reward_calibration_finish.m:52–55](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/tasks/reward_calibration/reward_calibration_finish.m:52)), then returns. **No** strobing, **no** `pds.strobeTrialData`, **no** `trialEnd` strobe, **no** `pds.saveP`, **no** counter updates, **no** pool mutation, **no** `Screen('Close', ...)`, **no** `WaitSecs`. The pseudocode contract:

   ```matlab
   function p = barsweep_finish(p)
       if p.trVars.barsweepSessionDone
           % POST-COMPLETION NO-OP: persist final status, stop the harness, exit.
           status = p.status;
           save(fullfile(p.init.sessionFolder, 'p.mat'), 'status', '-append');
           runButtonObj = findall(groot, 'Tag', 'runButton');
           runButtonObj.Value = false;
           return;
       end
       % ... normal _finish.m responsibilities (steps 1–9 above) ...
   end
   ```

**Initialization:** `p.trVarsInit.barsweepSessionDone = false;` in `_settings.m`. Like `movieExhausted` in rfMap, this is a runtime status flag, not a user-tunable parameter; it is not GUI-exposed.

**Why the no-op must be strict:** the harness loop at [PLDAPS_vK2_GUI.m:491](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/PLDAPS_vK2_GUI.m:491) calls `_finish.m` even after `_next.m` short-circuits. If `_finish.m` ran its normal flow on that pass, it would (a) call `pds.strobeTrialData` against the previous trial's parameter values, emitting duplicate parameter and `trialEnd` strobes; (b) re-save the previous trial's `trialNNNN.mat` (`pds.saveP` keys on `iTrial`, which `_next.m` did not increment, so it would overwrite); (c) potentially double-decrement the pool or re-shuffle a fresh set; (d) attempt `Screen('Close', ...)` on already-closed texture handles. The pseudocode above prevents all of this.

**Acceptance test (mandatory in Phase 4):** after the last rewarded trial, the harness performs exactly one post-completion callback cycle and produces (i) no new `trialNNNN.mat` file, (ii) no new parameter strobes in the Ripple stream, (iii) no new `trialBegin`/`trialRunDone`/`trialEnd` strobes, (iv) no change to `p.status.iTrial`, `p.status.iGoodTrial`, `p.status.barsweepPool`, or `p.status.barsweepSetsCompleted`, and (v) no `Screen('Close', ...)` calls. The **only** permitted on-disk change in this cycle is one append of the final `status` block to `p.mat` (see "Non-start trial auditability"); the post-completion `p.mat` `status` must reflect attempts through the very last (possibly nonStart) trial. Verified by diffing `p` and the strobe stream across the post-completion cycle.

## Saving Strategy

Standard PLDAPS save flow via `pds.saveP(p)` (called from `_finish.m` after `pds.strobeTrialData`). On trial 1, `pds.saveP` writes the full `p` struct to `p.mat`; on every started trial, it appends `status` to `p.mat` and writes a per-trial `trialNNNN.mat` containing `trVars`, `trData`, `status`, `init`. Non-start trials are intentionally not saved as standalone files (see [+pds/saveP.m:27](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/+pds/saveP.m:27)).

The empty stub at `+pds/storeDataInPDS.m` should not be used; the canonical examples are [rfMap_finish.m:46–77](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/tasks/rfMap/rfMap_finish.m:46) and [conflict_task_finish.m:32](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/tasks/conflict_task/conflict_task_finish.m:32).

All trial-relevant metadata must live in `p.trVars` or `p.trData`.

### Minimum fields in saved data
- fixation position (`fixDegX`, `fixDegY`)
- fixation window size
- sweep center (`pathCenterXDeg`, `pathCenterYDeg`)
- sweep angle (this trial)
- path length
- speed
- bar width
- bar length
- stimulus mode
- luminance indices (and resolved numeric values)
- stimOn / stimOff timestamps
- trial outcome / `trialEndState`
- direction-pool snapshot at trial start (mirrored in `p.status.barsweepPoolAtTrialStart` and `p.trData.barsweepPoolAtTrialStart`; the `trData` copy makes the snapshot trial-local in the per-trial `.mat`)

### Non-start trial auditability
`pds.saveP` distinguishes three on-disk artifacts:

1. **Initial full `p.mat` write** at [+pds/saveP.m:22](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/+pds/saveP.m:22) — fires unconditionally when `p.status.iTrial == 1`, **before** any nonStart check. So even a first-trial nonStart writes the full `p` struct to `p.mat` once.
2. **`status` append into `p.mat`** at [+pds/saveP.m:31](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/+pds/saveP.m:31) — skipped on nonStart (the function returns at line 27 before reaching it).
3. **Per-trial `trialNNNN.mat`** at [+pds/saveP.m:40](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/+pds/saveP.m:40) — also skipped on nonStart.

Implications for barsweep **without** the v1-required per-trial append:

- A first-trial nonStart would leave only the initial `p.mat` on disk (with the trial-1 entry-state snapshot of `p.status` — `barsweepPool` shuffled by `_init.m`, `iTrial == 1`, and the `nonStart`-incremented `nonStartCount` because `_finish.m` step 9 ran before step 6's `pds.saveP` call); no `trialNNNN.mat`. **However**, note the order: in `_finish.m` step 6, `pds.saveP` writes the initial `p.mat` *before* the nonStart return at [+pds/saveP.m:27](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/+pds/saveP.m:27), but step 9's status counter update happens *after* step 6, so the `p.mat` snapshot from `pds.saveP` actually predates the step-9 counter increment. This is exactly the gap that step 10's per-trial append closes.
- The on-disk `p.mat`'s `status` field would reflect state through the **last started trial**, not the last *attempted* trial.
- A trailing streak of non-start trials at the end of a session would **not** be persisted to `p.mat`. Manual stops during a nonStart streak would leave those attempts absent from disk.

**With the v1-required per-trial append at `_finish.m` step 10:** every trial — including nonStarts — appends `p.status` to `p.mat` after step 9. The on-disk `status` therefore reflects every attempt regardless of outcome, and all three implications above are eliminated. The only remaining caveat is the per-trial `trialNNNN.mat`, which is still skipped on nonStart by `pds.saveP`; that is intentional (no ephys/eye trace to save) and is not closed by this append.

The Ripple strobe stream is the canonical record of every attempt that actually emitted a `trialBegin` strobe. For schedule-integrity audits the strobe stream takes precedence over the saved `.mat` for trial-by-trial counts; the `.mat` provides the per-trial parameter detail for started trials.

**Required mitigation (v1):** the schedule's retry-on-abort logic makes attempt counts and fixation-quality auditability load-bearing, so a nonStart attempt silently dropping off disk is not acceptable on **any** stop path (manual stop, normal completion, or operator interrupt). v1 covers all stop paths with **two** complementary appends:

1. **Per-trial unconditional status append in `_finish.m`** (after step 9, on every real trial regardless of outcome): immediately after step 9, write
   ```matlab
   status = p.status;
   save(fullfile(p.init.sessionFolder, 'p.mat'), 'status', '-append');
   ```
   This is run on **every** outcome (`trialComplete`, `fixBreak`, **and** `nonStart`), so the on-disk `p.status` always reflects the most recent attempt. `pds.saveP` (called in step 6) returns early on nonStart at [+pds/saveP.m:27](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/+pds/saveP.m:27) before reaching its own status append at [+pds/saveP.m:31](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/+pds/saveP.m:31), which is what creates the gap; this dedicated append closes it. The I/O cost is one small `save -append` per trial — negligible relative to texture prebuild.
2. **Post-completion append in the no-op branch of `_finish.m`** (the branch that fires when `p.trVars.barsweepSessionDone == true`): same pattern, done before toggling the run button off. Strictly speaking this append is redundant with the per-trial append above (the last real-trial `_finish.m` already wrote the final state), but the redundancy is cheap and makes the no-op branch self-contained: if the per-trial append is ever removed or fails silently, the post-completion branch still produces a valid final `p.mat`.

**Stop paths covered:**

| Stop path | What happens | Final `p.status` on disk reflects |
|---|---|---|
| Normal completion (last rewarded trial empties final pool) | Per-trial append on the rewarded trial. Then one no-op cycle: `_next.m` raises the flag; `_run.m` short-circuits; `_finish.m` no-op branch appends status (redundant) and toggles run button. | Last rewarded trial. (No trailing nonStarts exist in this case — the rewarded trial *is* the terminating trial.) |
| Manual stop mid-session, last trial = rewarded or fixBreak | Per-trial append on that trial. Operator toggles run button; harness loop exits at [PLDAPS_vK2_GUI.m:533](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/PLDAPS_vK2_GUI.m:533) before the next `_next.m`. | Last started trial. |
| Manual stop mid-session, last trial = nonStart | Per-trial append on the nonStart trial (this is the path that the previous v1 spec did not cover). Operator toggles run button; harness exits. | Last nonStart attempt — including correct `p.status.nonStartCount`. |

This carve-out is consistent with the "no-op must be strict" rule: the per-trial append produces no new strobes, no counter mutations, and no behavioral side effects — it is purely a `save -append` of an already-updated struct.

## Strobing Plan

### Belt-and-suspenders principle
The Ripple ephys stream is sufficient to reconstruct, for each trial, its **nominal configuration** — geometry (path angle, center, length, speed, bar dimensions, fixation geometry), stimulus mode and palette indices — and the **timing of behavioral events** (`trialBegin`, `fixOn`, `fixAq`, `stimOn`, `stimOff`, `fixBreak`, `nonStart`, `reward`, `trialRunDone`, `trialEnd`) without relying on the saved `.mat`. Session-level scheduling parameters that don't reconstruct an individual trial's stimulus (e.g., `setRepeats`, `iti`) are NOT strobed — they are recoverable from the `.mat` and from the timing-event stream itself.

**What the strobe stream cannot reconstruct:** the realized per-frame playback. If frames were dropped, if the GPU stalled, or if the binary noise pattern on a particular flip differed from what `_next.m` pre-built, those anomalies are invisible from strobes alone. Frame-by-frame fidelity claims must be backed by the saved `.mat` (which carries `sweepDurationS_visible`, `sweepDurationS_motion`, `speedDegPerSec_realized`, and the texture-prebuild metadata) and by Psychtoolbox flip-timing logs. The strobe stream covers nominal stimulus and behavioral timing; it does not certify rendering fidelity.

**Scoped-down: physical luminance is *not* reconstructable from the strobe stream alone.** Only luminance *indices* are strobed; the resolved numeric values in `p.stim.luminanceLevels` depend on the rig CLUT and live only in the `.mat`. Offline analyses that need physical contrast must join the strobe stream against the saved `p.mat`/`init.mat` for that session. This is intentional — encoding 8-bit-or-better luminances per channel would inflate the strobe count for no behavioral-decoding benefit, and the rig CLUT is per-session-stable. If a future use case demands ephys-only physical luminance, add three luminance-value strobes (one per palette slot) to the per-trial parameter block.

### Existing codes reused (no new entries)
- `taskCode`, `date_1yyyy`, `date_1mmdd`, `time_1hhmm`, `trialCount`
- Timing: `trialBegin`, `fixOn`, `fixAq`, `fixBreak`, `nonStart`, `stimOn`, `stimOff`, `reward`, `trialEnd`

### New codes added to [+pds/initCodes.m](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/+pds/initCodes.m:1)

**Identity (32xxx range):**
- `codes.uniqueTaskCode_barsweep = 32021;`

**Timing (30xxx range):**
- `codes.trialRunDone = 30008;` — end of the trial loop in `_run.m`. Distinct from `trialEnd` (record close in `_finish.m`). Added to disambiguate the historical PLDAPS overload of `trialEnd`. Used by all future tasks that adopt the split convention; not retrofitted into existing tasks.

**Per-trial parameter / outcome codes (contiguous block 16115–16131, 17 codes):**

| # | Code name | Encoding | Range / notes |
|---|---|---|---|
| 1 | `barsweepAngle_x10` | angle × 10 | 0–3600; v1 cardinals only, no offset |
| 2 | `barsweepCenterTheta_x10` | (angle × 10) + 1800 | handles ±180° |
| 3 | `barsweepCenterRadius_x100` | radius × 100 | non-negative |
| 4 | `barsweepPathLength_x100` | dva × 100 | non-negative |
| 5 | `barsweepSpeed_x100` | dva/s × 100 | non-negative |
| 6 | `barsweepWidth_x100` | dva × 100 | non-negative |
| 7 | `barsweepLength_x100` | dva × 100, total end-to-end | non-negative |
| 8 | `barsweepFixTheta_x10` | (angle × 10) + 1800 | handles ±180° |
| 9 | `barsweepFixRadius_x100` | radius × 100 | non-negative |
| 10 | `barsweepFixWinWidth_x100` | dva × 100 | non-negative |
| 11 | `barsweepFixWinHeight_x100` | dva × 100 | non-negative |
| 12 | `barsweepStimMode` | 1 = noise, 2 = solid | scalar |
| 13 | `barsweepBgLumIdx` | 1/2/3 | scalar |
| 14 | `barsweepBarLumIdx` | 1/2/3 | scalar |
| 15 | `barsweepNoiseLumLowIdx` | 1/2/3 | scalar |
| 16 | `barsweepNoiseLumHighIdx` | 1/2/3 | scalar |
| 17 | `barsweepNoiseGrain_x100` | dva × 100 | non-negative |

**Total new codes: 19** (1 task identifier + 1 timing code `trialRunDone` + 17 parameter codes).

### Codes intentionally not added
| Proposed | Reason for omission |
|---|---|
| `barsweepSweepCount` | Redundant with reward strobe and `trialEndState`; only ever 0 or 1 with one-sweep-per-trial. |
| `barsweepNoiseFrameHold` | Constant in v1 (= 1); recoverable from `.mat` if it ever varies. |
| `barsweepSetRepeats` | Session-level scheduling; doesn't reconstruct a trial. |
| `barsweepNAngles` | Fixed at 4 in v1; recoverable from `.mat`. |
| `barsweepITI_x1000` | `iti` is actively imposed in `_finish.m` (see canonical timeline). The configured value is **not** cleanly recoverable from `trialEnd[N] → fixOn[N+1]` spacing because that gap also includes `_next.m` setup work and harness overhead. It is recovered from the saved `.mat` (`p.trVars.iti`). If a future use case demands ephys-only configured-ITI recovery, add a `barsweepITI_x1000` strobe; v1 trades that for a smaller per-trial parameter block. |

### `p.init.strobeList` entries (in order)
The list will reference each new code by name; values are evaluated MATLAB expressions referencing `p.trVars` / `p.trData` / `p.init`. Negative-safe encoding is applied at the strobeList expression level (e.g., theta values pre-add the 1800 offset).

#### Robustness against silent strobe loss
`pds.strobeTrialData` wraps each `eval` of a strobeList expression in a `try/catch` that swallows errors silently (see [+pds/strobeTrialData.m:14](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/+pds/strobeTrialData.m:14)). A typo or undefined field reference in any strobeList row will drop that strobe with no warning. Because this task explicitly relies on the strobe stream for offline reconstruction, mitigations are mandatory:

1. **Compile-time check (in `_settings.m` or `_init.m`):** after building `p.init.strobeList`, iterate the list once and verify every code name exists in `p.init.codes`. Fail loudly on the first missing code rather than discovering it mid-session.
2. **First-trial dry-run validation:** on trial 1 (after `_next.m` populates the relevant fields), evaluate every strobeList expression in a non-`try/catch` loop and assert each result is a finite non-negative integer in the strobe range. Abort the session if any expression raises or produces an out-of-range value.
3. **Phase 4 mandatory acceptance test:** decode one rewarded trial from the Ripple stream and compare the recovered values against the saved `trVars`/`trData`. Treat any mismatch as a release blocker.

### Timing-event strobes
Split between `_run.m` (behavioral) and `_finish.m` (record close). `pds.strobeTrialData` strobes only paired entries from `p.init.strobeList` and is not used for these timing events; they are emitted via the classy strobe object directly.

**In `_run.m`:**
- `trialBegin` at trial start.
- `fixOn` post-flip when fix dot first appears.
- `fixAq` when eye enters window (state transition).
- `stimOn` post-flip on the first flip that contains the bar.
- `stimOff` post-flip on the **first blank flip after the last visible bar frame**. Strobed on **both** the rewarded and `fixBreak` branches: on reward, this is the flip after `frameIdx == sweepFrames`; on `fixBreak`, this is the flip that removes the bar after the broken-fixation frame. With this convention, `[stimOn, stimOff)` is the half-open visibility interval for every trial that began the sweep, and aborted-trial visible duration is reconstructable from timing strobes alone.
- `fixBreak` when eye leaves window during sweep.
- `nonStart` when `fixWaitDur` expires without `fixAq`. The repo's existing `codes.nonStart = 22004` is used; aborts that never began the sweep are then visible in the ephys record, which the saved `.mat` does not capture (`pds.saveP` skips nonStart trials entirely).
- `reward` on reward delivery.
- `trialRunDone` at the very end of `_run.m`, after the run-loop exits — exactly once per trial regardless of outcome. **Never emitted in `_finish.m`.**

**In `_finish.m`:**
- `trialEnd` after `pds.strobeTrialData` returns and before any `WaitSecs` for post-trial waits — exactly once per trial. **Never emitted in `_run.m`.** The inter-strobe gap `trialEnd[N] → fixOn[N+1]` contains the post-trial waits (`postRewardDuration`, `timeoutAfterFixBreak`, `iti`) **plus** `_next.m` setup work for trial `N+1` (GUI copy, parameter validation, sweep precompute, texture pre-build) and harness overhead. This gap is a useful upper bound on configured ITI but is **not** a precise ITI measure — read `p.trVars.iti` from the saved `.mat` if exact ITI matters.

### Timing-event semantics
Both `stimOn` and `stimOff` are flip-locked via the post-flip mechanism. On the rewarded branch, the bar is drawn for exactly `sweepFrames` flips; the (`sweepFrames + 1`)th flip in the sweep epoch is the first blank flip, and that flip's timestamp is `stimOff`, so `stimOff − stimOn = sweepDurationS_visible = sweepFrames * frameInterval`. The endpoint-to-endpoint motion duration is `sweepDurationS_motion = (sweepFrames - 1) * frameInterval` and is one frame shorter than the visibility window — they are distinct quantities by construction; do not conflate them. On the `fixBreak` branch, the bar is drawn for `k < sweepFrames` flips and the (`k + 1`)th flip removes the bar — that flip's timestamp is `stimOff`, and `stimOff − stimOn = k * frameInterval` is the partial visible duration. In both cases `[stimOn, stimOff)` is the half-open visibility interval. The `nonStart` branch never emits `stimOn` or `stimOff`.

## Geometry and Drawing Details

### Coordinate conventions
- All task geometry kept in dva relative to screen center until final pixel conversion.
- Y-sign convention follows existing PLDAPS tasks (rfMap, fixate); the polygon and trajectory math go through a single helper to centralize the sign handling.

### Sweep definition
Given:
- center `(cx, cy)`
- path angle `theta`
- path length `L`

Bar center moves from:
- `(cx, cy) − 0.5·L·[cos(theta), sin(theta)]`
to
- `(cx, cy) + 0.5·L·[cos(theta), sin(theta)]`

Bar long-axis orientation is `theta + 90°` (perpendicular).

### Bar drawing
Default for both modes is **texture-based**:
- Solid mode: a small bar texture sized to the current `(barWidthDeg, barLengthDeg)` in pixels, drawn via `Screen('DrawTexture', win, tex, [], destRect, rotationAngle, 0)`. Built per trial in `_next.m` (because `barWidthDeg`/`barLengthDeg` are GUI-mutable) and released per trial in `_finish.m`.
- Noise mode: pre-built binary noise frames at the configured `noiseCheckSizeDeg` grain, drawn rotated.

This avoids `Screen('FillPoly')`, which is not used elsewhere in the repo and behaves unpredictably for very thin (1–2 px) bars.

### Texture management
- Solid mode: one texture is built per trial in `_next.m` from the current `(barWidthDeg, barLengthDeg)` and released per trial in `_finish.m`. **Not** built once in `_init.m`: the bar geometry parameters are GUI-mutable, so a session-cached texture would silently render stale dimensions after any mid-session GUI edit. Per-trial rebuild keeps the rendered bar in sync with `p.trVars` at the cost of one trivially small texture allocation per trial.
- Noise mode: all `sweepFrames` textures for the upcoming sweep are pre-built in `_next.m` (mirroring [generateNoiseTextures.m](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/tasks/rfMap/supportFunctions/generateNoiseTextures.m:1)) and stored in `p.trVars.barTextures`. The run loop only calls `Screen('DrawTexture')` — never `MakeTexture` — eliminating per-flip allocation as a frame-drop risk. All per-trial textures are released in `_finish.m` via `Screen('Close', p.trVars.barTextures(p.trVars.barTextures > 0))`.

## Mouse Support Plan (v1)

Mouse-controlled sweep centering is **deferred**. v1 supports only the existing `mouseEyeSim` debug pathway (already standard in the repo) for offline development without a real eye-tracker. The code structure will leave a clear extension point for adding `centerSource = 'mouse'` later without touching the strobe list (the polar-encoded center already covers any per-trial center variation).

## Reward Logic

Reward fires at the end of `holdFixAndSweep` when fixation has been continuously maintained from `fixAq` through the final sweep frame. Implemented via `pds.deliverReward(p)` with duration `rewardDurationMs`. Standard `reward` timing strobe is emitted.

## Proposed `trVars` Summary

### Core fixation and timing
- `fixDegX`, `fixDegY`
- `fixWinWidthDeg`, `fixWinHeightDeg`
- `fixWaitDur`
- `rewardDurationMs`
- `timeoutAfterFixBreak`
- `postRewardDuration`
- `iti`

### Sweep schedule and geometry
- `setRepeats` (scalar, GUI-editable until trial 1; lazy-frozen into `p.init.barsweepSchedule.setRepeats`)
- `pathAngleDeg` (resolved per trial from the schedule)

**Note:** `angleList` is **not** in `p.trVars`. It lives only in `p.init.barsweepSchedule.angleList`, set in `_init.m`, and is not GUI-editable in v1 (the PLDAPS GUI cannot represent non-scalars).
- `pathCenterXDeg`, `pathCenterYDeg`
- `pathLengthDeg`
- `speedDegPerSec`
- `barWidthDeg`
- `barLengthDeg` (total end-to-end length)

### Stimulus selection
- `stimulusMode`
- `backgroundLumIdx`, `barLumIdx`
- `noiseLumLowIdx`, `noiseLumHighIdx`
- `noiseCheckSizeDeg`
- `noiseFrameHold` (constant 1 in v1)

### Debug / simulation
- `passEye`
- `mouseEyeSim`

### Runtime status flags (not GUI-exposed)
- `barsweepSessionDone` — initialized `false` in `p.trVarsInit`; set `true` in `_next.m` when the termination condition is met. Drives `_run.m` short-circuit and `_finish.m` run-button toggle. Mirrors rfMap's `movieExhausted` pattern.

## Proposed `trData` Additions

### Timing
- `timing.trialBegin`
- `timing.fixOn`
- `timing.fixAq`
- `timing.stimOn`
- `timing.stimOff`
- `timing.fixBreak`
- `timing.nonStart`
- `timing.reward`
- `timing.trialRunDone` (set at end of `_run.m`)
- `timing.trialEnd` (set in `_finish.m`, after `pds.strobeTrialData`)

### Sweep-specific
- `pathAngleDeg` (the angle this trial)
- `sweepCenterDeg` (resolved center this trial)
- `sweepStartPix`, `sweepEndPix`
- `sweepFrames`
- `sweepDurationS_nominal`, `sweepDurationS_visible`, `sweepDurationS_motion` — quantization contract (visibility window vs endpoint-to-endpoint motion; see "Quantization contract")
- `speedDegPerSec_realized` — realized endpoint-motion speed = `pathLengthDeg / sweepDurationS_motion`
- `barsweepPoolAtTrialStart` — snapshot of `p.status.barsweepPool` at the start of this trial; mirrors `p.status.barsweepPoolAtTrialStart` so the snapshot is trial-local in the per-trial `.mat`

### Outcome
- `trialEndState`
- `trialRepeatFlag`

## Schedule Pool Bookkeeping

**Frozen at session start, in `p.init` (immutable across the session):**

- `p.init.barsweepSchedule.angleList` — the canonical angle list, set in `_init.m` (e.g., `[0 90 180 270]`). Not GUI-editable (the PLDAPS GUI is scalar-only). Every reshuffle on set completion draws from this field; there is no `p.trVars.angleList` to fall back to.
- `p.init.barsweepSchedule.setRepeats` — snapshot of `setRepeats` at session start. The termination rule reads only this field.

**Mutable, in `p.status` (not strobed; saved via the `status` append in `pds.saveP`):**

- `p.status.barsweepPool` — shuffled queue of angles still to be **rewarded** in the active set. Mutated only in `_finish.m`: on `trialComplete`, the front element is removed; on `fixBreak`/`nonStart`, the pool is unchanged. When emptied, `_finish.m` reshuffles a fresh full pool from `p.init.barsweepSchedule.angleList`.
- `p.status.barsweepPoolAtTrialStart` — snapshot of the pool at the start of each trial, for offline auditing.
- `p.status.barsweepSetsCompleted` — strict count of **fully completed sets**, where a set is completed only when every angle in the frozen `angleList` has been rewarded once. Incremented in `_finish.m` on the rewarded trial that empties the active pool. Initialized to 0 in `_init.m`.

**Selection contract:** `_next.m` reads `p.status.barsweepPool(1)` into `p.trVars.pathAngleDeg` but does not modify the pool. All pool mutation lives in `_finish.m`.

**Termination rule (single source of truth):** the session ends when `p.status.barsweepSetsCompleted >= p.init.barsweepSchedule.setRepeats`. With the leave-pool-unchanged-on-abort policy, this is equivalent to "every angle has been rewarded `setRepeats` times," and is decoupled from the total attempt count. The mechanism that translates this condition into the harness actually stopping is in "Session termination mechanism."

**Off-by-one note:** `barsweepSetsCompleted` is the count of sets already finished, not the index of the currently active set. The active set's progress is implicit in `length(barsweepPool)` (= angles still to be rewarded in this set).

## Implementation Sequence

### Phase 1: Scaffolding
1. Create `tasks/barsweep/` quintet files.
2. Add minimal support functions.
3. Add to `+pds/initCodes.m`: the unique task code (`uniqueTaskCode_barsweep = 32021`), the new timing code (`trialRunDone = 30008`), and the 17 parameter codes (`16115–16131`).

### Phase 2: Minimal viable task — solid mode
1. Implement solid mode bar rendering via texture rotation.
2. Implement balanced-direction schedule pool with set-based termination.
3. Implement passive fixation with reward-on-sweep-completion.
4. Implement `p.init.strobeList` with all 17 parameter strobes plus standard timing strobes.

### Phase 3: Noise mode
1. Add per-flip binary noise texture generation rotated to bar orientation.
2. Validate timing and texture cleanup (no GPU leaks across long sessions).

### Phase 4: Validation
1. Run on both rigs through hostname-selected rig config.
2. Confirm fixation and sweep-center positioning in dva are independently controllable.
3. Confirm balanced direction sampling: after `k` completed sets, each angle has exactly `k` rewarded presentations.
4. Confirm narrow-bar rendering at small `barWidthDeg`.
5. **Mandatory strobe round-trip test**: record one rewarded trial on Ripple, decode every parameter strobe from the stream, and assert each decoded value matches the corresponding `trVars`/`trData` field in the saved `.mat`. Because `pds.strobeTrialData` swallows expression errors silently, this check is the only way to catch a typo'd strobeList row. Treat any mismatch as a release blocker.
6. Confirm saved `trVars`/`trData` contain sufficient sweep metadata for offline interpretation.
7. Confirm session terminates after `setRepeats × nAngles` rewarded trials.
8. Confirm the trial timeline matches the canonical timeline (every named interval — `fixWaitDur`, `postRewardDuration`, `timeoutAfterFixBreak`, `iti` — is reflected in measured trial-to-trial spacing).

## Validation Checklist

- Task initializes from GUI with standard quintet flow.
- Rig config resolves correctly on both lab rigs.
- Fixation point moves correctly with `fixDegX`, `fixDegY`.
- Sweep center moves correctly with `pathCenterXDeg`, `pathCenterYDeg`, independently of fixation.
- Direction schedule produces balanced sampling: each angle is rewarded exactly `setRepeats` times.
- Aborted trials (`fixBreak`, `nonStart`) leave the pool unchanged; the same angle is presented on the next trial until rewarded.
- Solid mode renders narrow and wide bars correctly via texture rotation.
- Noise mode pre-builds all sweep textures in `_next.m` and the run loop calls only `Screen('DrawTexture')`.
- No frame drops attributable to texture creation across a full session.
- All per-trial textures are released in `_finish.m`.
- Bar long axis is perpendicular to direction of motion at every angle in `[0 90 180 270]`.
- Trial ends with reward only after fixation held through the entire sweep.
- Run-loop ordering: on every visible-sweep frame, the fixation-break check fires **before** the completion-transition check. A fix break on the final visible frame produces `fixBreak`, never reward.
- Fixation break aborts the trial without reward.
- Inter-trial interval (`iti`) is observed on every trial outcome (`trialComplete`, `fixBreak`, `nonStart`) and matches `p.trVars.iti` to within one frame.
- Trial-information strobes are emitted via `p.init.strobeList`.
- Timing-event strobes are aligned to the relevant flip; `stimOff` corresponds to the first blank flip after the bar.
- Endpoint/timing semantics (rewarded branch): the bar is on screen for exactly `sweepFrames` flips; `stimOn` matches the first visible-bar flip; `stimOff` matches the first blank flip after the bar; `stimOff − stimOn` equals `sweepDurationS_visible = sweepFrames × frameInterval` to within one frame; the bar's rendered position on the first and last visible frame matches the precomputed `sweepStartPix` and `sweepEndPix` exactly. The endpoint-to-endpoint motion duration is `sweepDurationS_motion = (sweepFrames − 1) × frameInterval`, and `speedDegPerSec_realized = pathLengthDeg / sweepDurationS_motion`.
- Endpoint/timing semantics (`fixBreak` branch): `stimOff` is strobed on the flip that removes the bar after the broken-fixation frame, so `[stimOn, stimOff)` reconstructs partial visible duration from the strobe stream alone.
- Quantization contract: `p.trData` carries `sweepDurationS_nominal`, `sweepDurationS_visible`, `sweepDurationS_motion`, `speedDegPerSec` (nominal), and `speedDegPerSec_realized`; the strobe-measured `stimOff − stimOn` matches `sweepDurationS_visible`; offline analyses that infer speed from rendered bar positions match `speedDegPerSec_realized = pathLengthDeg / sweepDurationS_motion`.
- `nonStart` strobe is emitted whenever `fixWaitDur` expires without `fixAq`, so aborted-before-sweep attempts are visible in the ephys record (the saved `.mat` does not capture them).
- `trialEnd` strobe precedes all post-trial waits (`postRewardDuration`, `timeoutAfterFixBreak`, `iti`); the inter-strobe gap `trialEnd[N] → fixOn[N+1]` contains those waits plus `_next.m` setup overhead. Configured ITI is read from `p.trVars.iti` in the saved `.mat`, not inferred by subtraction from this gap.
- `_next.m` checks `p.status.barsweepSetsCompleted >= p.init.barsweepSchedule.setRepeats` **before** any trial-specific work, sets `p.trVars.barsweepSessionDone = true`, and returns immediately if the session is complete; no `iTrial` increment, no GUI copy, no pool peek, no texture pre-build occurs on the post-final-set call. `_run.m` short-circuits on the same flag; `_finish.m` toggles the GUI run button off on the same flag (see "Session termination mechanism").
- For each rewarded, fixBreak, and nonStart trial, the strobe stream contains exactly one `trialRunDone` (emitted at the end of `_run.m`) and exactly one `trialEnd` (emitted in `_finish.m` after `pds.strobeTrialData`), in that order, with no duplicates from either file.
- Noise-mode `Screen('DrawTexture')` calls pass `filterMode = 0` (nearest-neighbor) so the binary checker grain is preserved through scaling and rotation.
- `setRepeats` is session-immutable after trial 1: mid-session GUI edits to `p.trVars.setRepeats` do not change the termination target (`p.init.barsweepSchedule.setRepeats`). `angleList` is not GUI-editable at all; it lives only in `p.init.barsweepSchedule.angleList`. Documented in the GUI tooltip / settings header.
- If `_next.m` throws after partial texture allocation, all already-allocated handles are closed before the error propagates. Verified via a fault-injection test in Phase 4.
- All 17 parameter codes decode to expected values from the ephys stream alone (subject to the scoping note in "Belt-and-suspenders principle": physical luminance still requires the saved `.mat`).
- Session terminates when `p.status.barsweepSetsCompleted >= p.init.barsweepSchedule.setRepeats` (i.e., `setRepeats × nAngles` rewarded trials), and the harness stops calling the quintet because `_finish.m` toggled the run button off.
- `pds.saveP(p)` writes per-trial files for started trials only; `p.mat` carries the full `p` struct from trial 1 and an updated `status` from every started trial.
- **Post-completion no-op (mandatory):** after the last rewarded trial, the one extra `_next.m → _run.m → _finish.m` cycle the harness performs is a strict no-op except for (a) one append of final `p.status` to `p.mat` and (b) the run-button toggle. No `trialBegin`/`trialRunDone`/`trialEnd` strobes, no `pds.strobeTrialData` call, no `pds.saveP` call, no `Screen('Close', ...)`, no `WaitSecs`, no counter or pool mutation. Verified by diffing `p` and the Ripple strobe stream across that cycle.
- **Final-status persistence on every stop path (mandatory):** the on-disk `p.mat`'s `status` field reflects every attempt through the last trial executed, **regardless of how the session ended** (normal completion, manual stop after a rewarded/fixBreak trial, or manual stop after a nonStart). Verified by three separate runs: (i) run to normal completion, confirm final `nonStartCount`/`fixBreakCount`/`iGoodTrial` on disk match the in-memory values; (ii) manually stop after a fixBreak, confirm same; (iii) manually stop *during a forced nonStart streak*, confirm `p.status.nonStartCount` on disk matches the live in-memory count (this is the path the previous v1 spec did not cover; the per-trial append at `_finish.m` step 10 closes it).
- **Lazy `setRepeats` freeze (mandatory):** `p.init.barsweepSchedule.setRepeats` is populated on the first `_next.m` call, after `p.trVars = p.trVarsGuiComm` runs, so it reflects the operator's GUI value at Run-time (not the `_settings.m` default). Verified by editing `setRepeats` in the GUI between Initialize and Run, then confirming the frozen value matches the post-edit GUI value, not the `trVarsInit` default.
- **`angleList` is settings-file-only:** there is no `p.trVars.angleList` field; `angleList` lives only at `p.init.barsweepSchedule.angleList`, set in `_init.m`. The PLDAPS GUI cannot represent or edit it ([PLDAPS_vK2_GUI.m:54](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/PLDAPS_vK2_GUI.m:54), [:89](/home/herman_lab/Documents/PLDAPS_vK2_MASTER/PLDAPS_vK2_GUI.m:89) — scalar-only). Verified by inspecting the trVars list in the running GUI: `angleList` is absent.
- **Solid-mode texture per-trial rebuild:** mid-session GUI edits to `barWidthDeg` or `barLengthDeg` are reflected on the very next trial's rendered bar. Verified by editing those params during a session and confirming the bar dimensions change on the next trial.

## Risks and Mitigations

### Risk 1: Spatial undersampling at high speed × thin bar
At `speedDegPerSec >> barWidthDeg × frameRate`, the bar moves more than its own width per frame, leaving spatial gaps. Mitigation: warn (or auto-clamp) in `nextParams.m` when `speedDegPerSec / frameRate > barWidthDeg`. Defaults are conservative.

### Risk 2: Noise-mode GPU memory leak
The pre-build design (textures created in `_next.m`, drawn in `_run.m`, closed in `_finish.m`) eliminates per-flip allocation but introduces a per-trial cleanup obligation. Mitigation: every trial that allocates `p.trVars.barTextures` must release them in `_finish.m`, including aborted trials. `_finish.m` calls `Screen('Close', p.trVars.barTextures(p.trVars.barTextures > 0))` unconditionally and zeroes the array. Add a session-end assertion that the total live texture count returned by `Screen('Windows')` has not grown across the session. Note: `_run.m` never calls `Screen('MakeTexture')`, so close-on-draw policies do not apply here.

### Risk 3: Coordinate-sign mistakes
Mitigation: keep all task geometry in dva until a single conversion helper. Centralize polygon/trajectory math.

### Risk 4: Schedule-pool desync from outcome bookkeeping
Mitigation: explicit unit-style sanity check at session end — total rewarded trials equals `setRepeats × nAngles`, and per-direction count equals `setRepeats`.

### Risk 5: Hostname-based rig selection edge case
The repo's `pcName(end-1)` rig-number extraction is fragile if hostnames change. Mitigation: assert on `p.init.rigConfigFile` non-empty in `barsweep_settings.m` and fail loudly with a useful message if rig resolution fails.

### Risk 6: Silent strobe loss from `pds.strobeTrialData` try/catch
`+pds/strobeTrialData.m` evaluates each strobeList row inside a `try/catch` that swallows errors. A typo or stale field reference will silently drop that strobe with no warning; offline reconstruction would then be missing the parameter and the failure mode is undiagnosable from the data alone. Mitigation (all required, not optional):
- Compile-time check at `_init.m` that every code name in `p.init.strobeList` exists in `p.init.codes`.
- First-trial dry-run: evaluate every strobeList expression outside the silent `try/catch` and assert each result is a finite non-negative integer in the strobe range; abort the session on any failure.
- Phase 4 mandatory acceptance test: round-trip-decode one rewarded trial from Ripple and compare against the saved `.mat`.

### Risk 7: Endpoint drift from per-frame incremental motion
Caching only `sweepDxPixPerFrame`/`sweepDyPixPerFrame` and integrating per frame accumulates rounding error and typically misses one of the endpoints by one frame's worth of motion. Mitigation: precompute the full `sweepCenterPix` (`2 × sweepFrames`) array via `linspace(start, end, sweepFrames)` and index it by frame number in `_run.m`. The endpoint contract (`sweepCenterPix(:,1) == sweepStartPix`, `sweepCenterPix(:,end) == sweepEndPix`) is then tautologically true and testable.

## Recommended Initial Defaults

- `setRepeats = 50` (→ 200 trials at 4 angles; GUI-editable scalar)
- `p.init.barsweepSchedule.angleList = [0 90 180 270]` (set in `_init.m`; not GUI-editable in v1)
- `fixDegX = 0`, `fixDegY = 0`
- `fixWinWidthDeg = 4`, `fixWinHeightDeg = 4`
- `fixWaitDur = 5.0`
- `pathCenterXDeg = 10`, `pathCenterYDeg = 0`
- `pathLengthDeg = 70` (matches source)
- `speedDegPerSec = 70` (matches source; ~1 s sweep)
- `barWidthDeg = 0.5` (matches source thickness)
- `barLengthDeg = 80` (total end-to-end; corresponds to source's effective on-screen length)
- `stimulusMode = 1` (noise, matches source default)
- `noiseCheckSizeDeg = 0.25`
- `backgroundLumIdx = 2`
- `barLumIdx = 3` (only used in solid mode)
- `noiseLumLowIdx = 1`, `noiseLumHighIdx = 3`
- `iti = 0.5` (s, matches source `Stm.ITI = 500` ms)
- `rewardDurationMs` = rig-default

## Immediate Next Step
Use this document as the spec for implementation. The first coding pass should build the minimal solid-mode, balanced-direction, single-sweep-per-trial task with correct PLDAPS saving and strobing conventions before adding noise mode.
