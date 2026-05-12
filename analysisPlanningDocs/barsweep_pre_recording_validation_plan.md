# Barsweep Pre-Recording Validation Plan

## Purpose

Before using the `barsweep` task to collect neural data from monkeys, validate end-to-end that:

1. Every event the task is supposed to strobe to the Ripple system actually arrives, with the right code and the right value.
2. Every parameter strobed at end-of-trial round-trips correctly: the value decoded from the Ripple stream reproduces the value the task believes it sent.
3. Event ordering on the Ripple side matches the state-machine's intended order.
4. Inter-event timing on the Ripple side matches the PLDAPS-side `p.trData.timing` to within hardware tolerance (`~1` frame for flip-locked events; `~1` ms for `strobeNow` events).
5. Per-trial saved `.mat` files contain everything an offline analysis needs (consistency between `p.trData.strobed`, `p.trData.eventValues`, and the timing fields).
6. Edge cases — `nonStart`, `fixBreak`, the post-completion no-op cycle, schedule pool wrap, missed frames — do not corrupt the strobe stream or the saved data.
7. The online RF mapping path (`useOnlineRF = true`) is correct: the per-trial accumulator update is consistent with the saved spike/event data and the persisted RF sidecar; mid-session spatial-knob changes snapshot-and-reset cleanly; the bypass paths (`useOnlineRF = false`, Ripple unavailable) are safe; the synthetic-spike unit test (`testBarsweepRF`) passes for both regimes (`cardinal4` and `rfmap12`).
8. The two regime settings files (`barsweep_settings.m` for cardinal4 and `barsweep_rfmap12_settings.m` for rfmap12) both pass the static and runtime checks; the rfmap12 wrapper preserves all base-settings invariants, adds the two reconstruction-knob strobes, and overrides the `barsweepExptType` strobe to `2`.

The validation is performed **without a monkey**, by driving fixation through PLDAPS' built-in `mouseEyeSim` mode while a Ripple system records the strobes generated on the experiment PC. This is the same setup that will be used in vivo, minus the animal and the recording probe.

## Scope and acceptance criteria

In scope:
- A static (no-hardware) audit script that catches strobe-list / `initCodes.m` mismatches and out-of-range values before each session, for **both** settings files (`barsweep_settings.m` and `barsweep_rfmap12_settings.m`).
- A small dry-run harness inside MATLAB that drives end-to-end trials with the eye tracker turned off (zero-voltage eye signal sits near the fixation window) and exercises every state-machine outcome.
- Installation of Blackrock's NPMK on the rig MATLAB path (the rig does not currently have it).
- An offline analysis script that loads a recorded session (PLDAPS `.mat` per-trial files plus the Ripple `.nev` file plus, when present, the `<sessionId>_barsweepRF.mat` and `<sessionId>_barsweepRF_resetN.mat` sidecars) and produces a pass/fail report on the eight checks above.
- A pre-rig synthetic-spike pass against the **existing** `tasks/barsweep/supportFunctions/testBarsweepRF.m` covering both regimes, regime equivalence, and the latency-mismatch sanity check.
- A short written test protocol the experimenter follows on the rig to produce the input data for that report.

Out of scope:
- Photodiode validation. The user will address photon-side timing at some later point once the photodiode circuit is built; it is not part of this plan.
- Online RF mapping algorithm-quality benchmarks (separate concern: the design plan in `barsweep_online_rf_mapping_plan.md` defines convergence criteria; here we only validate that the accumulator/reconstruction implementation is *correct relative to the saved data*, that bypass paths are safe, and that mid-session reset behavior is sound).
- Closed-loop behavioral validation (eye-tracker calibration, fixation accuracy, etc.) — those are rig-setup tasks, not strobe-correctness tasks.

Acceptance criteria:

1. **Static audit clean.** `auditBarsweepStrobes` prints zero errors against the current `barsweep_settings.m` + `barsweep_rfmap12_settings.m` + `+pds/initCodes.m`. In particular, it verifies the new codes (`barsweepExptType`, `barsweepRfLatency`, `barsweepRfPosBin_x100`, and the rfmap12-only `barsweepRfRampCutoff_x100`, `barsweepRfRampFilter`) are present and that `pds.barsweepRampFilterEnum` returns a value in `[1, 4]` for the configured `rfRampFilter`.
2. **Strobe inventory.** For a recorded dry-run session that exercises every state-machine outcome (`trialComplete`, `fixBreak`, `nonStart`) with at least the per-outcome counts in §7, the offline script confirms that every strobe `barsweep_run.m` and `barsweep_finish.m` was supposed to emit appears in the Ripple `.nev` stream, with the expected outcome-conditional pattern. The end-of-trial parameter batch counts match the regime: 25 entries × 2 = 50 strobes for `barsweep_cardinal4`, 27 entries × 2 = 54 strobes for `barsweep_rfmap12`.
3. **Round-trip parameter decode.** For every trial, every value in `p.init.strobeList` decoded from the Ripple stream matches the corresponding `p.trVars` / `p.status` / `p.trData` field on the PLDAPS side, exactly (integer-equal after applying the documented `*_x10` / `*_x100` / `*_x1000` / `+1800` / filter-enum encodings). `barsweepExptType` decodes to `1` for cardinal4 sessions and `2` for rfmap12 sessions.
4. **Ordering.** Per-trial event sequence on the Ripple side matches the canonical sequence (§3) for that trial's outcome, with no extra or missing events.
5. **Timing.** Inter-event intervals on the Ripple side agree with `p.trData.timing` to within ±1 frame (postFlip-armed events) or ±1.5 ms (`strobeNow` events). Sweep duration `stimOff − stimOn` matches `p.trVars.sweepDurationS_visible` to within ±1 frame.
6. **No-op cycle harmless.** The extra `_next → _run → _finish` cycle that fires after `barsweepSessionDone` produces no strobes on the Ripple side and no `trial####.mat` increment.
7. **Online-RF correctness against saved data.** For every `useOnlineRF=true` trial that contributed to the accumulator (`trialComplete` or `fixBreak`), an offline replay using only `p.trData.spikeTimes`, `p.trData.spikeClusters`, `p.trData.eventTimes`, `p.trData.eventValues`, `p.trVars.sweepCenterDegByFrame`, `p.trData.timing.flipTime`, and `p.trData.timing.flipIdxStimOn` reproduces the per-trial increments to `spikeHist`, `dwellTime`, `spikeCount`, and `trialsByDirection` that ended up in the persisted `<sessionId>_barsweepRF.mat`. `nonStart` trials are excluded from accumulation. The fixBreak truncation point matches `min(stimOff−stimOn, fixBreak−stimOn) − latencyMs/1000`.
8. **Online-RF bypass paths safe.** With `useOnlineRF=false`, the session runs end-to-end with no `barsweepRF` figure created, no Ripple connection attempt blocked or required, and no sidecar written. With `useOnlineRF=true` but Ripple unavailable, init prints exactly one `barsweep_init:rippleUnavailable` warning, sets `p.init.barsweepRF.enabled = false`, and `_finish.m` skips both accumulation and figure refresh on every trial.
9. **Online-RF reset behavior.** Mid-session edits to `pathLengthDeg`, `barWidthDeg`, `rfPosBinDeg`, or `rfLatencyMs`, or super-bin `pathCenterDeg` moves, write a `<sessionId>_barsweepRF_resetN.mat` snapshot **before** zeroing the accumulator and increment `resetCount` monotonically. Sub-bin `pathCenterDeg` moves are absorbed without resetting (same `resetCount`, same accumulator contents). Reconstruction-only knobs (`rfMapExtentDeg`, `rfRampFilter`, `rfRampCutoff`, `rfSelectedChannel`) **never** trigger a reset.
10. **Synthetic-spike unit test passes.** `testBarsweepRF()` (with default arguments, `savePlots=true`) returns `results.rfmap12.pass == true` and `results.cardinal4.pass == true`, the regime-equivalence check agrees on both axes within 5 position bins, and the latency-mismatch shift is within 2 bins of `speedDegPerSec * deltaMs/1000`.

## 1. The strobe surface to validate

Three categories, with their sources and timing semantics. Anything we add to the validator must understand all three.

### 1a. Hardcoded event strobes (in `_run.m` and `_finish.m`)

From `barsweep_run.m` and `barsweep_finish.m`:

| Code name | Numeric (from `+pds/initCodes.m`) | Source line | Timing semantics |
|---|---|---|---|
| `trialBegin` | 30001 | `_run.m:82` | `strobeNow` at state entry |
| `fixOn` | 3001 | `_run.m:96` (armed), strobed on next flip | postFlip — strobe lands on the flip that displays fix |
| `fixAq` | 3004 | `_run.m:101` | `strobeNow`, no flip dependency |
| `nonStart` | 22004 | `_run.m:107` | `strobeNow`, no flip dependency |
| `stimOn` | 6002 | `_run.m:126` (armed), strobed on next flip | postFlip — strobe lands on the flip that displays the first bar frame |
| `fixBreak` | 3005 | `_run.m:131` | `strobeNow`, no flip dependency |
| `stimOff` | 6003 | `_run.m:140 / :155` (armed), strobed on next flip | postFlip — strobe lands on the first blank flip after the bar |
| `reward` | 8000 | `_run.m:163` (via `pds.deliverReward`) | `strobeNow` inside the trialComplete state. `trialComplete`-only — never on `fixBreak` / `nonStart`. Position relative to `stimOff` is non-deterministic (see §3 note). |
| `trialRunDone` | 30008 | `_run.m:69` | `strobeNow`, end of run loop |
| `trialEnd` | 30009 | `_finish.m:78` | `strobeNow`, end of finish |

`addValueOnce` writes to a per-trial veto-deduplicated buffer; `strobeList` (called from `drawMachine` line 281) clocks the buffer out on the same frame the postFlip variable receives its timestamp. So **`p.trData.timing.fixOn` and the Ripple-side `fixOn` event time refer to the same flip**, and any skew between them is purely USB→DataPixx→Ripple latency (sub-millisecond).

### 1b. Per-trial parameter strobes (`p.init.strobeList`)

Sent in `_finish.m` step (6) via `pds.strobeTrialData(p)`. Each list row is a `(codeName, valueExpression)` pair; `strobeTrialData` `eval`s the expression and emits two consecutive strobes (the code, then the value).

**Cardinal4 list** (from `barsweep_cardinal4_settings.m`, 25 entries → 50 strobes per batch):

```
taskCode, date_1yyyy, date_1mmdd, time_1hhmm, trialCount,
barsweepAngle_x10, barsweepCenterTheta_x10, barsweepCenterRadius_x100,
barsweepPathLength_x100, barsweepSpeed_x100, barsweepWidth_x100,
barsweepLength_x100, barsweepFixTheta_x10, barsweepFixRadius_x100,
barsweepFixWinWidth_x100, barsweepFixWinHeight_x100, barsweepStimMode,
barsweepBgLumIdx, barsweepBarLumIdx, barsweepNoiseLumLowIdx,
barsweepNoiseLumHighIdx, barsweepNoiseGrain_x100,
barsweepExptType, barsweepRfLatency, barsweepRfPosBin_x100
```

**Rfmap12 list** (from `barsweep_rfmap12_settings.m`, base list + 2 appended rows + `barsweepExptType` overridden to `2`, 27 entries → 54 strobes per batch):

```
... (same 25 base entries, with barsweepExptType expression overridden to '2') ...
barsweepRfRampCutoff_x100, barsweepRfRampFilter
```

The batch is bracketed by `trialRunDone` (before) and `trialEnd` (after) on every outcome.

### 1c. Encoding conventions

All values must arrive as positive integers in `[0, 32767]` (DataPixx 15-bit data field). The barsweep-specific encodings are:
- `*_x10`, `*_x100`, `*_x1000`: scaled and rounded.
- `barsweepCenterTheta_x10` and `barsweepFixTheta_x10`: `theta_deg * 10 + 1800` to handle negative angles in `[-180, 180]`.
- `barsweepAngle_x10`: `mod(pathAngleDeg, 360) * 10`, range `[0, 3600)`.
- `barsweepExptType`: `1` for cardinal4 sessions, `2` for rfmap12 sessions. Settings-file-controlled literal (cardinal4 hardcodes `'1'`; the rfmap12 wrapper rewrites the row to `'2'`).
- `barsweepRfLatency`: `round(rfLatencyMs)` — 1 ms resolution, no scaling.
- `barsweepRfPosBin_x100`: `round(rfPosBinDeg * 100)`.
- `barsweepRfRampCutoff_x100` (rfmap12 only): `round(rfRampCutoff * 100)`, where `rfRampCutoff ∈ [0, 1]`.
- `barsweepRfRampFilter` (rfmap12 only): `pds.barsweepRampFilterEnum(rfRampFilter)` returns `1=Ram-Lak`, `2=Hann`, `3=Shepp-Logan`, `4=Cosine`. Any other string raises in `+pds/barsweepRampFilterEnum.m` (so a misconfigured filter name fails before the first strobe).
- `taskCode` (32000) is the special paired-strobe used by PLDAPS to identify the task at session start; it must always arrive as `(32000, 32000)` per the convention in `+pds/strobe.m`.

The decoder must invert each of these unambiguously, including reverse-mapping the filter enum to its canonical string name for offline reports.

## 2. Generating input data: eye-tracker-off sessions

The simplest way to drive trials without a monkey is to leave the eye tracker turned off. The eye-position voltages then sit at ~0 V, which (with a centered fixation point and a typical fix-window) places the simulated gaze inside the fix window. The task acquires fixation, holds it through the sweep, and rewards on every trial — i.e. the natural outcome is `trialComplete` on every trial.

To exercise the other two outcomes, the experimenter introduces deliberate perturbations:

- **`trialComplete`**: default — eye tracker off, do nothing.
- **`fixBreak`**: while a sweep is in progress, momentarily disturb the (zero) eye-position signal so it leaves the fix window — e.g. by toggling the eye-tracker source, briefly grounding the analog input, or temporarily shrinking the fix window via the GUI. Any one of these is fine; the goal is just to push the gaze indicator out of the window mid-sweep.
- **`nonStart`**: shrink the fix window to a value smaller than the (small but non-zero) noise on the zero-voltage signal, so fixation is never acquired during the entire `fixWaitDur` interval. Alternatively, offset the fixation point so it is far from the gaze indicator at (0,0).

`mouseEyeSim` is also available as a fallback if the eye-tracker-off behavior turns out to be unreliable on a given rig (e.g. excessive baseline noise pushing the gaze indicator out of the window unpredictably). The validator code does not care which method is used — it only inspects strobes and saved data.

For each outcome we want enough trials to make the timing-tolerance histograms meaningful and to surface low-rate failure modes. Recommended targets:

- **100 `trialComplete`**: drives the timing histograms (figure b in §4c) for every postFlip event and the sweep-duration histogram (figure c) into a regime where a 1-frame outlier is visibly anomalous against the bulk.
- **50 `fixBreak`**: enough to exercise `fixBreak` mid-sweep at varied positions along the bar's path. Since `fixBreak` arms `stimOff` on the same iteration, this also gives 50 samples of the `fixBreak → stimOff` ordering check.
- **50 `nonStart`**: enough to confirm `nonStart` never co-occurs with `stimOn`/`stimOff`/`fixBreak` and that the param-strobe batch fires identically regardless of outcome.

Total ~200 trials. With the user's "leave it running while doing other work" availability this is comfortable in a single pass. Lower counts are acceptable for regression passes once the validator is known good.

A small helper `runBarsweepValidationSession.m` (under `tasks/barsweep/supportFunctions/`) sets the relevant defaults (eye tracker off, generous `fixWaitDur`, short ITI, `setRepeats` chosen to deliver ~200 total trials, plus a flag that, when set, switches to mouseEyeSim mode if the eye-tracker-off path proves noisy). It accepts a regime argument (`'cardinal4'` or `'rfmap12'`) and dispatches to the matching settings file (`barsweep_settings.m` or `barsweep_rfmap12_settings.m`). **It does not start Trellis recording itself** — the experimenter starts/stops Trellis manually, mirroring the production workflow.

## 3. Canonical event sequences (the spec the offline checker enforces)

For each trial, the validator builds the expected event set + ordering constraints from the trial's PLDAPS-side outcome and compares against the Ripple stream. Per-outcome canonical sequences:

```
trialComplete (backbone events in strict order; reward in window):
  trialBegin → fixOn → fixAq → stimOn → [reward] → stimOff → trialRunDone
    → [params: taskCode×2, date_1yyyy×2, ..., barsweepRfPosBin_x100×2
              (rfmap12 also: barsweepRfRampCutoff_x100×2, barsweepRfRampFilter×2)]
    → trialEnd

fixBreak:
  trialBegin → fixOn → fixAq → stimOn → fixBreak → [stimOff?] → trialRunDone
    → [params: ...]
    → trialEnd

nonStart:
  trialBegin → fixOn → nonStart → trialRunDone
    → [params: ...]
    → trialEnd
```

Notes:

- **`reward` on `trialComplete`** is `strobeNow` from `pds.deliverReward`, fired during the polling iteration after the `holdFixAndSweep → trialComplete` transition. `stimOff` is `postFlip`-bound and waits for the next actual flip. The two events can land in either order on Ripple time depending on the polling-vs-flip race in `drawMachine` — typically `stimOn → reward → stimOff → trialRunDone`, but a faster polling loop can hit the flip boundary first and produce `stimOn → stimOff → reward → trialRunDone`. The validator therefore enforces strict order on the **backbone** (the seven non-reward events listed above) and only requires `reward` to appear **somewhere between `stimOn` and `trialRunDone`**.
- `reward` is **never** present on `fixBreak` or `nonStart` (no `pds.deliverReward` call on those code paths); the aborted-trial sanity check (§6.6) verifies absence.
- `stimOff` is **optional on `fixBreak`**. `_run.m:131–141` arms it as a `postFlip` strobe when fixBreak is detected, but the run loop typically exits within 1–2 polling iterations of the fixBreak strobe (~sub-ms apart) — well before `drawMachine` would have flipped at the rig's ~10 ms cadence. So in practice `stimOff` almost never fires on `fixBreak`. The validator allows it either way: present is OK, absent is OK; if present, it must follow `stimOn`. We deliberately do not "fix" this in the production task: keeping `stimOff` flip-locked means it always corresponds to a real bar-removal flip when it does fire, and on a trial where the animal broke fixation the precise bar-offset time is not analytically meaningful (the `fixBreak` strobe itself is the trial-end marker). There is no `stimOff` on `nonStart` (no bar was ever shown).
- The param batch is regime-dependent (25 entries for cardinal4, 27 for rfmap12) but identical in count across all three outcomes within a regime.

The post-completion no-op cycle (`barsweepSessionDone == true`, see `_run.m:23–26` and `_finish.m:20–32`) emits no strobes; the validator confirms this by checking that the count of `trialEnd` strobes matches the count of completed real trials, not real-trials + 1.

## 4. The validation tooling

Six artifacts, all under `tasks/barsweep/supportFunctions/`. One (`testBarsweepRF.m`) already exists; the other five are new for this plan:

### 4a. `auditBarsweepStrobes.m` (static, ~120 lines)

A lint pass run once per session, before pressing Initialize. Loads each settings file (default invocation audits **both** `barsweep_settings.m` and `barsweep_rfmap12_settings.m`) and `+pds/initCodes.m`, then:

1. For every `codeName` in column 1 of `p.init.strobeList`, asserts the field exists in `initCodes`. Reports any missing. (This duplicates the runtime assertion in `barsweep_init.m` step 11 but catches it before pressing Initialize, when there's still time to fix without losing rig setup state.)
2. Greps `_run.m` and `_finish.m` for `p.init.codes.<name>` references; confirms each `<name>` exists in `initCodes`. Catches typos in hardcoded event strobes that would silently fail (the `try/catch` in `strobeTrialData.m:14–41` swallows them).
3. For every `valueExpression` in column 2, eval against a synthetic `p` with worst-case parameters (extreme angles, max eccentricity, max speed, all four filter names). Reports any value outside `[0, 32767]`, any non-integer, any non-scalar. The synthetic `p` covers the new RF-mapping fields (`rfLatencyMs`, `rfPosBinDeg`, `rfRampFilter`, `rfRampCutoff`) so the new strobe rows are exercised on both settings files.
4. Confirms all required `p.trData.timing.*` fields used by `_run.m` are initialized to `-1` in `_settings.m` (`fixOn`, `fixAq`, `stimOn`, `stimOff`, `fixBreak`, `nonStart`, `reward`, `trialBegin`, `trialEnd`, `trialRunDone`). Also confirms `flipIdxStimOn` is initialized to `-1` (used by `accumulateBarsweepRF` to slice `flipTime`).
5. Calls `pds.barsweepRampFilterEnum(p.trVarsInit.rfRampFilter)` against the configured value and confirms it returns an integer in `[1, 4]`. A typo in the filter name would otherwise raise only on the first end-of-trial strobe attempt of the first trial.
6. Asserts `p.trVarsInit.useOnlineSort == 0` whenever `p.trVarsInit.useOnlineRF == true`. (Mirrors the runtime assertion in `barsweep_init.m` step 13; both regimes' settings files should already satisfy this, but a future settings-file edit could violate it silently.)
7. Reads `p.trVarsInit.rfNChannels` and warns if it differs from the rig's actual Ripple channel count (when known from a previously saved rig config); a 32 vs 64 mismatch will raise `barsweepRF:channelOverflow` at runtime.
8. For the rfmap12 settings file specifically, asserts the row override worked: `barsweepExptType`'s expression evaluates to `2`, and the two appended rows (`barsweepRfRampCutoff_x100`, `barsweepRfRampFilter`) are present.

Cheap, deterministic, no hardware. Can be a pre-Initialize hook later.

### 4b. `decodeRippleEvents.m` (~150 lines)

Pure function. Takes `eventValues`, `eventTimes` (the arrays already on `p.trData` after `pds.getRippleData`, or read from a `.nev` file by `openNEV`), plus `pds.initCodes`. Returns a struct array of trials:

```
trial(i).startTime         % Ripple-clock seconds, from trialBegin
trial(i).endTime           % from trialEnd
trial(i).iTrial            % decoded from trialCount
trial(i).events            % table: codeName, codeValue, time
trial(i).params            % struct: barsweepAngle_x10 -> value, ...
trial(i).paramsDecoded     % same, with encoding inverted (degrees, dva, etc.)
trial(i).outcome           % 'trialComplete' | 'fixBreak' | 'nonStart'
                           % inferred from presence of fixAq / fixBreak strobes
trial(i).exptType          % 'barsweep_cardinal4' | 'barsweep_rfmap12'
                           % decoded from barsweepExptType strobe (1 -> cardinal4, 2 -> rfmap12)
trial(i).rfLatencyMs       % decoded from barsweepRfLatency
trial(i).rfPosBinDeg       % decoded from barsweepRfPosBin_x100
trial(i).rfRampFilter      % rfmap12 only: decoded back to canonical string via the inverse enum
trial(i).rfRampCutoff      % rfmap12 only: decoded from barsweepRfRampCutoff_x100
```

Trial segmentation is by `trialBegin → trialEnd` brackets. The function builds a name-from-value reverse lookup from `pds.initCodes` once, then walks the event stream. Outcome inference is local: presence of `fixBreak` → `fixBreak`; absence of `fixAq` → `nonStart`; otherwise → `trialComplete`.

The decoder also asserts intra-session consistency: `exptType` must be the same value on every trial (a regime change mid-session is a programmer error, not a feature) and the rfmap12-only fields are present iff `exptType == 'barsweep_rfmap12'`.

This is the same primitive offline RF analysis will need, so building it now pays for itself.

### 4c. `validateBarsweepSession.m` (~350 lines)

The main test driver. Inputs:
- `sessionFolder` — the PLDAPS `.../sessionId/` directory containing `p.mat`, `trial####.mat`, and (when online RF is on) `<sessionId>_barsweepRF.mat` plus any `<sessionId>_barsweepRF_resetN.mat` snapshots.
- `nevFile` — path to the Trellis-saved `.nev`. Optional: if omitted, uses the per-trial `p.trData.eventValues` / `eventTimes` arrays (already in Ripple clock; a degenerate pass that catches everything except a few hardware-side issues).

Steps:
1. Load `pds.initCodes` and the session's `p.mat`. Read `p.init.exptType` and confirm it agrees with what `decodeRippleEvents` infers from the strobed `barsweepExptType`.
2. Either parse the `.nev` (via NPMK `openNEV`'s `NEV.Data.SerialDigitalIO.UnparsedData` and `.TimeStampSec` — see §5) or concatenate `eventValues`/`eventTimes` across `trial####.mat` files.
3. Call `decodeRippleEvents` to get the structured trial array.
4. For each PLDAPS trial:
   - Match by `iTrial` to the corresponding `trial####.mat`.
   - Run the strobe-correctness checks (§6.1–§6.6 below). Report per-check pass/fail with diffs.
   - When the trial was eligible for online-RF accumulation (`useOnlineRF=true`, Ripple alive, outcome ∈ {trialComplete, fixBreak}), run the online-RF replay check (§6.7) using `replayBarsweepRF`.
5. Run the across-session checks (§6.8–§6.12), including reset-snapshot integrity and final-accumulator round-trip against the persisted sidecar.
6. Aggregate pass/fail counts, print a summary, optionally save an HTML or `.txt` report.

Output figures (one MATLAB figure with several panels):
- (a) Strobe inventory heatmap: trials × code names, cell colored by present/absent/extra.
- (b) Inter-event interval scatter: PLDAPS-side vs Ripple-side, one point per (event, trial), with `±1 frame` and `±1.5 ms` reference bands.
- (c) Sweep-duration histogram: `stimOff − stimOn` per trial vs `sweepDurationS_visible`.
- (d) Param round-trip: trials × parameter, value of `(decoded − pldaps)`; should be uniformly zero.
- (e) Outcome confusion: PLDAPS `trialEndState` × Ripple-inferred outcome; should be diagonal.
- (f) Online-RF replay residuals: trials × `{spikeHist, dwellTime, spikeCount, trialsByDirection}` increments, max abs difference between live update and offline replay; should be uniformly zero.
- (g) Reset-snapshot timeline: vertical lines at trials where `resetCount` increments, with the spatial knob value that triggered each reset annotated.

### 4d. `replayBarsweepRF.m` (~120 lines)

Pure function used by `validateBarsweepSession`. Given a `trial####.mat` and the current pre-trial snapshot of `p.init.barsweepRF`, runs the same `accumulateBarsweepRF` logic offline and returns the predicted post-trial accumulator state. Lets the validator compare live updates against a deterministic replay using only the saved per-trial fields (no Ripple, no GPU, no figure handles). Trivially testable on synthetic input; reused by anyone doing post-hoc RF replay.

### 4e. `runBarsweepValidationSession.m` (~50 lines)

Tiny wrapper that loads either `barsweep_settings.m` or `barsweep_rfmap12_settings.m` (selectable via a single argument), overrides a small set of `p.trVarsInit` fields appropriate for dry-running (eye-tracker-off mode by default with `mouseEyeSim` as fallback, short ITI, `setRepeats` chosen to deliver ~200 total trials), and prints rig-side instructions. Just a convenience to keep the test protocol consistent across users and across regimes.

### 4f. `testBarsweepRF.m` (already exists in `tasks/barsweep/supportFunctions/`)

Pre-existing synthetic-spike unit test. The validation plan does not need to write this — only run it. Acceptance criterion #10 above is exactly its pass conditions: both regimes recover a known RF center within tolerance, regime equivalence within 5 position bins, and a latency-mismatch shift within 2 bins of `speedDegPerSec * deltaMs/1000`. Run before any rig session that uses online RF mapping (see §10 implementation order).

## 5. Reading the `.nev` file offline

Trellis saves `.nev` (events/spikes), `.ns2`/`.ns5`/`.ns6` (continuous), and a small sidecar. The strobed parallel word is in `.nev` under the "Serial/Digital IO" section. The plan uses **Blackrock NPMK's `openNEV`** to read it. NPMK is not currently on the rig MATLAB path; installing it is part of the implementation order in §10.

Installation steps:

1. Clone `https://github.com/BlackrockMicrosystems/NPMK` into a stable location on the rig (e.g. `~/MATLAB/NPMK/`).
2. Add the NPMK root to MATLAB's path (`addpath(genpath(...))`). On Linux, where `savepath` typically can't write the system `pathdef.m`, this can be done from `~/Documents/MATLAB/startup.m` (created if necessary) — MATLAB executes that file automatically on every desktop launch.
3. Smoke-test: load any small `.nev` and confirm `openNEV(nevFile, 'nosave', 'nomat')` returns `NEV.Data.SerialDigitalIO.UnparsedData` (16-bit words, low 15 bits = strobed value) and `.TimeStampSec`.

Trellis-written `.nev` files are byte-compatible with NPMK at the wire level for all current Trellis versions. The validator calls `openNEV` directly and produces a `(timestamps_s, values)` pair that `decodeRippleEvents` consumes.

**One local NPMK patch required for event-only `.nev` files.** Out-of-the-box NPMK assumes every `.nev` has at least one spike electrode and crashes at line 598 with `Dot indexing is not supported for variables of this type` when `NEV.ElectrodesInfo` is empty. Validation `.nev` files (recorded with strobes only, no spike channels enabled in Trellis) hit this every time. The fix is a one-line guard:

```matlab
% openNEV.m line 598 (was: NEV.MetaTags.ChannelID = [NEV.ElectrodesInfo.ElectrodeID];)
if isempty(NEV.ElectrodesInfo)
    NEV.MetaTags.ChannelID = [];   % event-only .nev (no spike channels)
else
    NEV.MetaTags.ChannelID = [NEV.ElectrodesInfo.ElectrodeID];
end
```

This is a local edit to a third-party library, so it must be re-applied if NPMK is ever reinstalled or upgraded. The alternative (recording at least one spike channel in every Trellis session so `ElectrodesInfo` is non-empty) is a workflow change rather than a code fix.

## 6. The checks (the heart of `validateBarsweepSession`)

Per trial:

1. **Strobe inventory.** Build the expected set from PLDAPS-side outcome (§3). Build the actual set from the Ripple-side trial. Diff. Fail if any expected event is missing or any unexpected event is present.

2. **Param round-trip.** For every `(codeName, valueExpression)` in `p.init.strobeList`, eval the expression against the trial's `p.trVars`/`p.status`/`p.trData` (loaded from `trial####.mat`); compare to the Ripple-decoded value. Fail on any inequality. (Note: the eval-against-p step requires the same `p` shape `strobeTrialData` saw — easy on `trialComplete` trials, slightly trickier on `nonStart` because the Phase-1 ordering and pool state may differ; the script reads exactly the saved fields.) For rfmap12 sessions the list includes the two appended rows, and `barsweepExptType` must decode to `2`; for cardinal4 it must decode to `1`.

3. **Encoding round-trip.** For every encoded parameter (e.g. `barsweepAngle_x10`), apply the documented inversion and confirm the result agrees with the original `p.trVars` field to within `1 / scale` precision. Catches errors in the encoding spec, not just in the strobing. The filter-enum round-trip (`barsweepRfRampFilter` → string) is asserted against the canonical name in `+pds/barsweepRampFilterEnum.m`.

4. **Ordering.** The Ripple-side event sequence (after dropping the param batch) must satisfy the per-outcome canonical-sequence spec (§3): every backbone event present and in strict canonical order, plus every aux event present within its documented window. Currently `reward` on `trialComplete` is the only aux event; its window is `(stimOn, trialRunDone)`, exclusive on both ends. Fail on any backbone reorder, any backbone-event absence, any aux-event absence, or any aux-event landing outside its window.

5. **Timing.** Build a per-trial alignment table with both clocks zeroed at the `trialBegin` strobe:
   - `t_pldaps_rel`: `p.trData.timing.<event> − p.trData.timing.trialBegin`. `p.trData.timing.<event>` is relative to `trialStartPTB` (set BEFORE the loop body in `barsweep_run.m:29-30`), so `timing.trialBegin` is itself nonzero (the time PLDAPS took to reach the trialBegin state and fire the strobe). Subtracting puts the PLDAPS-side clock on the same origin as Ripple.
   - `t_ripple_rel`: Ripple-stream time of the corresponding event minus Ripple-stream time of `trialBegin`.
   - For each event, compute `Δ = t_ripple_rel − t_pldaps_rel`.
   - Pass if `|Δ|` ≤ tolerance: 1 frame for postFlip events (`fixOn`, `stimOn`, `stimOff`), 1.5 ms for `strobeNow` events.
   - Additionally, check `(stimOff − stimOn)_ripple ≈ (timing.stimOff − timing.stimOn)_pldaps` to within 1 frame. We compare the two real measurements directly (Ripple vs PLDAPS), not against `sweepDurationS_visible`. `sweepDurationS_visible` is computed in `nextParams.m:93` as `sweepFrames * p.rig.frameDuration` and is only as accurate as the rig-config-time prediction of frame duration; if `p.rig.frameDuration` diverges from the rig's true refresh rate, `sweepDurationS_visible` will diverge from reality even though the actual flips (and therefore the strobes) are still consistent across the two clocks. That divergence is a rig-calibration issue, not a strobe-correctness issue, and should not produce a per-trial check 5 failure.

6. **Aborted-trial sanity.** On `nonStart`, confirm `stimOn`, `stimOff`, `fixBreak` are all absent. On `fixBreak`, confirm `stimOn` is present and `stimOff` follows it. Reward strobe is absent on both abort outcomes.

7. **Online-RF replay (only when `useOnlineRF=true` and the trial is eligible).** For each `trialComplete`/`fixBreak` trial, call `replayBarsweepRF` with the pre-trial snapshot of `p.init.barsweepRF` and the trial's saved fields. The replayed post-trial increments to `spikeHist`, `dwellTime`, `spikeCount`, and `trialsByDirection` must equal the live update bit-for-bit (within float tolerance for `dwellTime`). `nonStart` trials must produce a zero increment (verified by walking the persisted sidecar's monotonically-increasing trial counter and confirming no entry corresponds to a `nonStart`). For `fixBreak` trials, the truncation point used by the live accumulator must match `min(stimOff−stimOn, fixBreak−stimOn) − latencyMs/1000`.

Across-session checks (run once after the per-trial loop):

8. **Trial-count consistency.** `length(trial####.mat) == nnz(eventValues == codes.trialEnd) == nnz(eventValues == codes.trialBegin)`.

9. **Pool integrity.** Reconstruct the angle pool's evolution from per-trial `p.status.barsweepPool` snapshots; confirm draw-without-replacement within a set, and a fresh shuffle at set boundaries. When `barsweepPairShuffle` is true (default), additionally confirm that within every completed set, opposite-direction pairs (`theta`, `theta+180`) appear adjacent in trial order.

10. **No strobes after `barsweepSessionDone`.** No event between `trialEnd` of the last real trial and the end of the recording.

11. **Online-RF sidecar round-trip.** Load `<sessionId>_barsweepRF.mat`. The `barsweepRF.spikeHist`, `dwellTime`, `spikeCount`, and `trialsByDirection` arrays must equal the cumulative replay (sum of all per-trial replayed increments since the most recent reset). `barsweepRF.lastUpdateTrial` must equal the index of the last RF-eligible trial. `barsweepRF.nChannels` must equal `p.trVars.rfNChannels` from the matching trial. `barsweepRF.exptType` must equal `p.init.exptType`.

12. **Reset-snapshot integrity.** For each `<sessionId>_barsweepRF_resetN.mat` written during the session, the file must contain a `barsweepRF` struct whose `resetCount == N` and whose accumulator arrays are non-empty (a snapshot of zeros means the reset fired before any contribution and the snapshot is meaningless — flag as a warning, not a fail). Across all reset files, `resetCount` is monotonically increasing with no gaps. The trial at which each reset fired (inferred from `lastUpdateTrial`) must coincide with a per-trial change in one of the gating spatial knobs (`pathLengthDeg`, `barWidthDeg`, `rfPosBinDeg`, `rfLatencyMs`, or super-bin `pathCenterDeg`). Sub-bin `pathCenterDeg` changes must NOT correspond to a reset file.

13. **Bypass-path sidecar invariant** (acceptance criterion #8). The persisted RF sidecar (`<sessionId>_barsweepRF.mat`) must be present iff `p.trVarsInit.useOnlineRF == true` AND `p.rig.ripple.status == true` (read from the saved `p.mat`). When either is false, no main sidecar and no reset snapshots may exist on disk. This positively validates the two bypass paths from §7's last paragraph (a `useOnlineRF=false` run, and a `useOnlineRF=true` run with Ripple unavailable) without requiring out-of-band directory inspection.

## 7. Test protocol (rig-side)

The full pass is **two long unattended sessions** — one per regime — each delivering ~200 trials distributed across outcomes. Wall-clock time depends on `setRepeats` and ITI but is well under a typical experimental session. The two regimes share the same quintet, so a passing run on one regime catches almost all bugs that affect both; the second regime exists to validate the regime-switch surface (settings-file overrides, `iradon` path, the two appended strobes).

**Pre-rig (no hardware required):**

0. Run `testBarsweepRF()` from the MATLAB command window with the synthetic-spike defaults. Both regimes must pass; the regime-equivalence and latency-mismatch checks must pass. Saved PNGs go to `tasks/barsweep/output/testBarsweepRF/<timestamp>/`. This satisfies acceptance criterion #10 and is a fast (~30 s) prerequisite to bringing the rig up. **Already run** — multiple passing runs are on disk under `tasks/barsweep/output/testBarsweepRF/`. Re-run only if any of the RF-mapping support functions (`initBarsweepRF`, `accumulateBarsweepRF`, `reconstructBarsweepRF`) change.

**Per-regime rig pass** (run twice, once for each settings file):

1. Pull the latest barsweep code; run `auditBarsweepStrobes` from the MATLAB command window against **both** settings files. Should print clean for each. (`auditBarsweepStrobes('all')` audits both in one call.)
2. Confirm NPMK is on the path (`exist('openNEV', 'file') == 2`). If not, install per §5.
3. Power on Ripple, open Trellis, configure parallel-digital-input port, start file recording. Suggested filenames: `barsweep_cardinal4_validation_YYYYMMDD.nev` and `barsweep_rfmap12_validation_YYYYMMDD.nev`. `.nev` only — no continuous needed.
4. Eye tracker off. In MATLAB, run `runBarsweepValidationSession('cardinal4')` or `runBarsweepValidationSession('rfmap12')`, configured to run a full set of trials with `setRepeats` chosen to give the session-termination path a chance to fire near the end. The wrapper sets `useOnlineRF=true` so the online-RF path is exercised. Click Initialize, then Run.
5. Walk away. Periodically (every ~50 trials or whenever convenient) introduce one of the perturbations from §2 to force a `fixBreak` or `nonStart`, until the per-outcome targets are met:
   - ~100 `trialComplete` (default, no intervention)
   - ~50 `fixBreak` (mid-sweep perturbation)
   - ~50 `nonStart` (window-shrink or fix-point offset until `fixWaitDur` elapses)
   At one or two points during the run, **deliberately** edit a spatial knob in the GUI (e.g. nudge `pathCenterXDeg` past one bin width, or change `rfPosBinDeg`) to force an online-RF reset. Note the trial number — the validator will reconcile it against `<sessionId>_barsweepRF_resetN.mat`. Make at least one **sub-bin** `pathCenterDeg` move that should NOT trigger a reset (validator confirms no extra reset file).
6. Let the run terminate naturally on `barsweepSessionDone` so the post-completion no-op cycle is exercised in-band (criterion #6 in the top section). Stop Trellis recording.
7. Run:
   ```matlab
   report = validateBarsweepSession( ...
       'sessionFolder', '<path-to-session>', ...
       'nevFile',       '<path-to-nev>');
   ```
8. Inspect `report.summary` and the figures. Acceptance is the criteria in the top section. The script writes `validationReport.mat` and `validationReport.fig` (or `.png`) into the session folder alongside the per-trial files for later reference.

The natural-termination path in step 6 also confirms criterion #6 (no strobes after `barsweepSessionDone`) at full schedule length, which is the more rigorous test. If a session ever needs to be cut short for a different reason, the same check still works on the truncated record.

**Bypass-path coverage (one short session, ~30 trials, either regime):**

A separate dry-run with `useOnlineRF=false` confirms acceptance criterion #8: no figure window opens, no `<sessionId>_barsweepRF.mat` is written, and the strobe-correctness checks still pass. A second dry-run with `useOnlineRF=true` but Ripple physically disconnected confirms the warning-only path (init prints `barsweep_init:rippleUnavailable`, `_finish.m` skips accumulation, no figure refresh). These two short runs do not need full ~200-trial coverage; ~30 trials each is enough to confirm the bypass paths don't crash and don't leak state.

## 8. Notes on choices answered upstream

A few decisions are baked in from the user's responses to the original draft and are recorded here so the implementer doesn't re-litigate them:

- **NPMK install.** Required; performed as part of the rig-side prep in §5 / §7.
- **Recording stream.** `.nev` only.
- **Trial counts.** ~200 total (100 / 50 / 50) per pass; user prefers a thorough pass over a fast pass.
- **Regime coverage.** Both `barsweep_cardinal4` and `barsweep_rfmap12` get a full pass. The shared quintet means most of the surface is exercised by either, but the regime-switch points (settings file, the two appended strobes, the iradon reconstruction path) need a dedicated rfmap12 run.
- **CI / scheduled regression.** Skipped for the rig-side passes. `testBarsweepRF` is fast enough that it can be run pre-session every time without scheduled automation.
- **Report artifacts.** Saved into the session folder.
- **Eye-source method.** Eye tracker off (preferred); `mouseEyeSim` retained as fallback.
- **No-op-cycle coverage.** Tested in-band by letting the full schedule run to natural termination (step 6 above).
- **Online-RF inclusion.** Validating online-RF correctness against saved data is the right scope for this plan. Algorithmic quality (does the RF map look right with real spikes?) is judged at the rig by the experimenter using the live figure; the offline replay only asserts that the live update is *reproducible* from the saved fields, which is what offline analysis also depends on.

## 9. Implementation order

If approved:

1. **Run `testBarsweepRF()`.** Already implemented at `tasks/barsweep/supportFunctions/testBarsweepRF.m`; the only "implementation" is running it and checking the saved PNGs. **Done** — passing runs already on disk under `tasks/barsweep/output/testBarsweepRF/`. This is the fastest signal that the online-RF math is sound and gates everything downstream; re-run only after edits to the RF-mapping support functions.
2. `auditBarsweepStrobes.m` (static, no hardware needed; isolates the lowest-risk failure mode first; covers both settings files).
3. `decodeRippleEvents.m` (pure, easily unit-tested with synthetic event arrays; includes the new exptType / RF-related fields and the rfmap12 filter-enum reverse map).
4. `replayBarsweepRF.m` (pure, unit-tested by feeding the existing `testBarsweepRF` synthetic spike trains through it and confirming the same accumulator increments come out).
5. `validateBarsweepSession.m` (consumes 2–4; first pass operates on the PLDAPS-side `eventValues`/`eventTimes` already saved per trial, before NPMK is wired up).
6. First cardinal4 validation session on the rig using the saved-per-trial path; iterate on tolerances and decode bugs.
7. Install NPMK on the rig; add the `.nev` reader path to `validateBarsweepSession`.
8. Second cardinal4 validation session using the on-disk `.nev` directly. Confirms that the saved-per-trial path and the `.nev` path agree.
9. First rfmap12 validation session. Reuses everything above; the only new surface exercised is the regime-switch points (settings file, two appended strobes, iradon path).
10. Two short bypass-path runs (`useOnlineRF=false`, and `useOnlineRF=true` with Ripple disconnected) to cover acceptance criterion #8.

Each step is independently usable: `testBarsweepRF` and `auditBarsweepStrobes` are valuable on their own even if no recording session ever happens; `decodeRippleEvents` and `replayBarsweepRF` are building blocks any offline RF analysis will also want.

## 10. Surfaces added by online RF mapping (validation reference)

This section is a checklist of the new code surfaces the validator must understand. The rest of the plan above already references them; this table consolidates them for review.

### 10a. Runtime guards (must fire before any state corruption)

| Guard | Source | Trip condition | Validator expectation |
|---|---|---|---|
| `barsweep_init:strobeListMissingCode` | `barsweep_init.m` step 11 | Any code name in `p.init.strobeList` not in `p.init.codes`. | Static audit (§4a check 1) catches this before Initialize. |
| `barsweep_init:useOnlineSortMustBeZero` | `barsweep_init.m` step 13 | `useOnlineRF=true` and `useOnlineSort != 0`. | Static audit (§4a check 6) catches this. |
| `barsweep_init:rippleUnavailable` (warning) | `barsweep_init.m` step 13 | `useOnlineRF=true` but `p.rig.ripple.status == false`. | Bypass-path run in §7 confirms init prints exactly this warning, sets `p.init.barsweepRF.enabled = false`, and `_finish.m` skips accumulation. |
| `barsweepRF:channelOverflow` | `accumulateBarsweepRF.m` | A spike arrives on a channel index above `rfNChannels`. | Static audit (§4a check 7) warns at audit time; the runtime error itself is the last-ditch backstop. |
| `nextParams:strobeListEvalFailed` | `nextParams.m` step 10 | First-trial dry-run of any strobeList expression raises or yields a non-finite/negative/non-integer value. | Static audit's worst-case-`p` eval (§4a check 3) catches this before pressing Initialize. |
| `nextParams:projectedNoiseTextureBudget` | `nextParams.m` step 9 | `nChecksX * nChecksY * sweepFrames * 4 > noiseTextureBudgetBytes`. | Static audit can mirror this calculation against worst-case `p` and report. |
| `nextParams:sweepFramesMax` | `nextParams.m` step 5 | Derived `sweepFrames > sweepFramesMax`. | Static audit can mirror against worst-case `p` and report. |

### 10b. Per-session saved files (RF-related)

When `useOnlineRF=true` and Ripple is connected, `_finish.m` writes:

- `<sessionId>_barsweepRF.mat` — overwritten every trial. Contains the latest snapshot of `p.init.barsweepRF` (with `figData`, `spikeHist`, `dwellTime` retained). The latest copy on disk equals the post-session state. Validated by check §6.11.
- `<sessionId>_barsweepRF_resetN.mat` — written **before** the accumulator is zeroed on a forced reset. `N` increments monotonically. Validated by check §6.12.

When `useOnlineRF=false`: neither file is written.

When `useOnlineRF=true` but Ripple is unavailable: neither file is written (the per-trial guard in `_finish.m` step 1c short-circuits).

### 10c. Per-trial saved fields used by offline replay

`replayBarsweepRF` reads only the following fields from each `trial####.mat` (and they must round-trip across saves):

- `p.trData.spikeTimes`, `p.trData.spikeClusters` — Ripple clock, channel index.
- `p.trData.eventTimes`, `p.trData.eventValues` — for `stimOn` anchoring.
- `p.trData.timing.flipTime` (preallocated `1×3000`), `p.trData.timing.flipIdxStimOn` — for stim-onset-relative frame slicing.
- `p.trData.timing.stimOn`, `p.trData.timing.fixBreak` — for fixBreak truncation.
- `p.trVars.sweepCenterDegByFrame` (`2×sweepFrames`) — bar position in dva, y-up convention. Distinct from the static `p.trData.sweepCenterDeg` `[1×2]`.
- `p.trVars.sweepFrames`, `p.trVars.flipIdx`, `p.trVars.pathAngleDeg`.
- `p.trData.trialEndState` — for outcome filtering (nonStart excluded).

Plus the pre-trial snapshot of `p.init.barsweepRF` (rebuilt by `replayBarsweepRF` from the per-trial RF parameters, since `p.init.barsweepRF` is stripped before save in `_finish.m` step 8).

The validator's audit script asserts every one of these fields exists and is non-empty on every RF-eligible saved trial. A missing field (for example, `flipIdxStimOn` reverting to `-1` would mean stimOn never fired) is flagged with the trial number and the offending field.

### 10d. Regime-switch invariants

- **Schedule.** `barsweep_init.m` step 10 selects the angle list based on `p.init.exptType`: cardinal4 → `[0 90 180 270]`, rfmap12 → `0:30:330`. Other `exptType` values raise.
- **Orientation pooling.** `initBarsweepRF.m` selects `orientationsDeg` from `exptType`: cardinal4 → `[0 90]` (2 unique after pooling), rfmap12 → `0:30:150` (6 unique).
- **Reconstruction.** `reconstructBarsweepRF.m` branches on `exptType`: cardinal4 returns `(rateX, rateY, separable2D, xCenter, yCenter)`; rfmap12 returns `rfImage` from `iradon`. Other `exptType` values raise.
- **Strobe surface.** Cardinal4 has 25 list rows; rfmap12 has 27 (the two appended) and overrides `barsweepExptType`'s expression to `'2'`. The static audit asserts the override worked (check 8).
- **Settings file.** `barsweep_rfmap12_settings.m` is a thin wrapper that calls `barsweep_settings()` first, so any new field added to the cardinal4 settings file flows automatically into rfmap12. The audit asserts no field exists in `barsweep_settings()` output that the rfmap12 wrapper drops.

### 10e. Things explicitly NOT changed by online RF mapping

These are unchanged from the original plan and remain validated as before:

- The strobe state machine in `_run.m` and `_finish.m` (canonical sequences in §3 still apply).
- `trialBegin / trialRunDone / trialEnd` strobe placement.
- `postFlip` mechanics for `fixOn`, `stimOn`, `stimOff`.
- `addValueOnce` / `strobeNow` semantics.
- Schedule pool mutation (only in `_finish.m` step 5).
- Session-termination via `barsweepSessionDone` and the post-completion no-op cycle.
