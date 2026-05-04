# rfMap Unified Merge Plan

## Goal

Upgrade `tasks/rfMap` into a unified passive-fixation receptive-field-mapping
task that supports four pre-generated stimulus types — **dense achromatic**,
**dense chromatic (DKL)**, **sparse (balanced)**, and **checkerboard
(multi-check-size, multi-contrast, contrast-reversing)** — with online
analyses appropriate to each. Deprecate `tasks/fix_present_squares(WiP)`.

Inspired by `~/Downloads/feng_LGN/` collaborator code, with the following
explicit exclusions: webcam recording, photodiode tracking, log-polar
cortical-magnification warp, bar-sweep stimulus, natural-movie playback.
Spatial jitter and restricted apertures are kept as opt-in features.

### What "RF mapping" means in each mode (be honest about scope)

- **Dense achromatic / Dense chromatic / Sparse**: produce online spatial
  receptive-field maps per channel via STA. These are the primary
  RF-mapping modes.
- **Checkerboard**: does **not** produce an online spatial RF (the spatial
  pattern is fixed; only polarity flips). What it does produce online is a
  per-condition temporal kernel and F1/F2 phase-locking — useful for cell
  screening / magno-parvo typing but **not** a spatial map. Treat it as a
  cell-characterization mode that lives alongside the RF-mapping modes
  because the architecture (pre-rendered textures, Ripple ingestion, online
  plot window, passive fixation) is identical. Note also that
  checkerboard's "check size" is **not** a clean spatial-frequency
  manipulation — checkerboards are SF-broadband. Use check-size as a
  pragmatic spatial-scale knob, not a tuning curve. If clean SF tuning is
  later required, that calls for a separate drifting-grating task, not an
  expansion of rfMap.

## Stimulus types and online estimation methods

| Stim type | Generator (new file) | Online estimator | Output dimensionality |
|---|---|---|---|
| Dense achromatic | `generateStim_denseAchromatic.m` | mean-subtracted spatial STA (existing logic, isolated) | `[nY, nX, nLags, nCh]` |
| Dense chromatic (DKL) | `generateStim_denseChromatic.m` | spatial STA accumulated against the **DKL drive vector** (not RGB) | `[nY, nX, 3, nLags, nCh]` (3 = DKL axes: L-M, S, achromatic) |
| Sparse (balanced) | `generateStim_sparseBalanced.m` | raw-value STA (existing sparse path) | `[nY, nX, nLags, nCh]` |
| Checkerboard | `prepareStim_checkerboard.m` (pre-renders texture pair × N conditions, not a movie tensor) | (a) temporal reverse-correlation on ±1 polarity sequence per (checkSize, contrast); (b) F1/F2 amplitude at reversal frequency per (checkSize, contrast) | `[nLags, nCheckSize, nContrast, nCh]` and `[2, nCheckSize, nContrast, nCh]` |

### Why DKL for chromatic STA (locked decision)

Accumulate STA against DKL coordinates rather than RGB. RGB-channel STAs
force offline analysis to invert the rig calibration, coupling the analysis
code to a calibration file that drifts. Drawing remains DKL → RGB at
texture-generation time; the per-frame DKL drive vector (3-vector per
check) is what feeds the STA accumulator.

### Why balanced sparse (rationale, not just "feng does it")

Today's uniform-random sparse selects spots independently each frame, so
per-frame mean luminance fluctuates by a binomial of order
`sqrt(nSparseSpots)`. For neurons with strong center-surround antagonism
(the very neurons sparse mode targets), this residual mean-luminance
modulation contaminates the spike-triggered average at low spike counts —
because the cell's spike rate covaries with whole-field mean luminance
even when the spot of interest isn't in the RF. The balanced
Twin-Deck/Pad-Block-Shuffle algorithm (`feng_LGN/create_sparsechecks.m`)
guarantees exactly N/2 white + N/2 black per frame, eliminating that
covariate. The gain is largest at low spike counts and for
surround-suppressed cells; for highly responsive cells with thousands of
spikes per session it's a small correction.

## Phasing

### Phase 0 — Prep (no behavior change)

**Phase 0 has two parts: (0a) work the user runs on the rig before any
code changes land, and (0b) work Claude/the developer does in the repo.
Phase 1 cannot start until 0a is complete — without the baseline session
folders there is nothing to regress against.**

#### Phase 0a — User runs on the rig (prerequisite, gates Phase 1)

Capture two baseline sessions with the current (pre-refactor) rfMap
code: one dense-achromatic, one sparse. PLDAPS saves each session as a
folder containing `p.mat` plus `trial<N>.mat` files (see
`+pds/saveP.m:23,31,40`); after the run, the GUI's **"Concatenate
Output"** button calls `pds.loadP` and writes a single
`output/<sessionId>.mat` (see
`PLDAPS_vK2_GUI.m:concatenateOutputButton_callback` at line ~578).
**One concatenated `.mat` per stim type is the deliverable.**

**Suggested filenames** (the GUI uses the auto-generated `sessionId`,
but rename after concatenation for clarity):
`baseline_rfMap_denseAchro_<YYYYMMDD>.mat`,
`baseline_rfMap_sparse_<YYYYMMDD>.mat`.

**How many trials**: ~**100 completed trials per stim type**. Rationale:
- Bit-exact dense regression only needs enough trials to exercise the
  full per-trial code path (~30 would suffice), but spike data for
  estimator regression scales with trial count. 100 × 1.5 s ≈ 150 s of
  noise per session is the sweet spot — enough to recover a clear STA
  peak from a real or synthetic spike train, short enough to run in
  one sitting.
- For the **sparse synthetic-STA recovery test** (the *gating* test
  for the new balanced sparse generator, since bit-exact is impossible
  by design), 100 trials gives ~500 spots/frame-position — sufficient
  SNR to compare old-vs-new estimator quality.

**Settings beyond switching stim type** — leave at defaults except:
- **RNG seed handling**: the current rfMap does not expose a
  pre-settable seed in `trVarsInit`; `generateNoiseMovie.m:41-45`
  calls `rng('shuffle')` and captures the resulting seed into
  `p.init.noiseRngSeed` (saved to the session file via
  `rfMap_init.m:109`). For Phase-0a, **just let it shuffle and run**
  — the captured seed is what feeds the post-refactor bit-exact test
  (the new generator will be invoked with the baseline's recorded
  seed and must produce the identical movie tensor). Phase 1 adds
  the settable-seed plumbing.
- Confirm `noiseFrameHold = 6`, `checkSizeDeg = 2`, `nSTALags = 8`,
  `nChannels = 32`, `trialDurationS = 1.5` (the current defaults).
  These define the regression contract — if they differ between the
  baseline and post-refactor runs, the comparison is meaningless.
- Dense session: `stimMode = 1`, `colorMode = 1`.
- Sparse session: `stimMode = 2`, `colorMode = 1`, `nSparseSpots = 5`.
- **Ripple/spike data — what to expect when no probe is in LGN.**
  `p.trData.spikeTimes` is populated only by `pds.getRippleData`
  (`+pds/getRippleData.m:3`), which requires a live `xippmex` spike
  stream. With no probe present, `spikeTimes` will be empty for every
  trial, and `rfMap_finish.m:38-39` will skip STA accumulation
  (`p.init.staAccum` stays `[]` at session end). **The current rfMap
  has no synthetic-spike fallback in the quintet** — `testSTA.m` and
  `buildGroundTruthRF.m` exist but are an offline test harness only.
  Set `connectRipple = 0` and `useRippleSTA = 0` for the no-probe
  baseline so the task doesn't try to connect.
- **What the no-probe baseline does and does not capture**:
  - **Captured**: `p.init.trialsArray`, `p.init.noiseRngSeed`,
    `p.init.noiseMovie` regeneration parameters, all `trVars`/`init`
    settings, per-trial frame timing in `p.trData.timing`, and the
    full `p` struct schema. **This is sufficient for bit-exact
    movie-tensor regression** (regenerate the movie from the saved
    seed under the new code and compare).
  - **Not captured**: `spikeTimes` (empty) and `staAccum` (empty).
    The estimator regression therefore cannot replay biology against
    the new code — it must run via `testSTA.m`-style synthetic spikes
    fed into both old and new estimators. The gating sparse test
    (synthetic-STA recovery, plan §"Phase 1 regression") was already
    designed to not need real spikes, so this is not a blocker for
    sparse validation. For dense, the post-refactor regression test
    is: feed identical synthetic spike trains into both old
    `updateSTA` and new `updateSTA_denseAchromatic` against the
    bit-exact-regenerated movie; outputs must be numerically
    identical.

**Archiving**: store the `.mat` file(s) at a documented path (lab
share or `tasks/rfMap/_regressionBaseline/` if small enough to
commit) and record the chosen path here once captured.

#### Phase 0a outcome (recorded 2026-05-01)

One usable baseline retained as a *structural* reference (schema,
settings, trial-array shape, frame timing):

```
denseAchro: output/baseline_rfMap_dense_20260501.mat
            sessionId 20260501_t0951_rfMap, 113 good trials,
            stimMode=1, colorMode=1, noiseFrameHold=6, checkSizeDeg=2,
            nSTALags=8, nChannels=32, trialDurationS=1.5,
            connectRipple=0, useRippleSTA=0
            (noiseRngSeed=0 — see Findings below)
sparse:     not retained (re-run aborted — see Findings below)
```

#### Phase 0a findings (bugs discovered, both fixed in Phase 1)

1. **`generateNoiseMovie.m:42-43` does not capture the seed it claims
   to.** The code is `rngState = rng('shuffle'); rngSeed =
   rngState.Seed;`, but `rng('shuffle')` returns the *previous* RNG
   state (per MATLAB's documented contract), not the new one. On a
   fresh MATLAB session the previous state is the default twister
   with seed 0, which is exactly what got saved into both baseline
   files (`p.init.noiseRngSeed = 0`). The actual seed used to
   generate the saved movies was derived from the system clock and
   was never recorded. **Consequence**: bit-exact movie regeneration
   from any pre-Phase-1 saved session is impossible. Phase 1 fixes
   this by having callers *pass in* a pinned seed and recording that
   exact value.

2. **`p.trVars.stimMode` is settings-time-only despite living in
   `trVars`.** The noise movie is generated once during
   `_init.m → generateNoiseMovieForTask`, which reads
   `p.trVarsInit.stimMode`. Toggling `p.trVars.stimMode` via the
   GUI mid-session has no effect on the displayed stimulus. The
   user discovered this trying to capture a sparse baseline:
   initialized with default settings (`stimMode=2` per
   `rfMap_settings.m:159`, but the GUI showed `stimMode=1` set in
   trVars), toggled in the GUI to switch modes, and the displayed
   stimulus did not change. **Consequence**: the second baseline run
   was actually dense, not sparse. **Fix**: Phase 1's per-stim-type
   settings files architecture inherently eliminates this — there
   is no mid-session toggle, stim type is pinned by which settings
   file was loaded, and the value lives in `p.init.stimType` (not
   `p.trVars`).

#### Phase 0a → Phase 1 handoff (revised regression contract)

The original plan envisioned bit-exact comparison of new-code output
against a saved baseline session. With the seed-capture bug, that's
not achievable from any pre-Phase-1 file. **Revised contract** (no
rig time needed):

- Phase 1 development includes a side-by-side validation harness
  `tasks/rfMap/_validation/compare_old_vs_new_generators.m` that
  runs the *current* `generateNoiseMovie.m` and the *new*
  `generateStim_denseAchromatic.m` with the same pinned seed and
  byte-compares outputs. Old code is invoked from a tag/branch
  reference; new code from the working tree.
- The retained structural baseline confirms the post-refactor `p`
  struct still contains the same top-level fields and per-trial
  `trData` schema.
- Sparse validation runs entirely on synthetic spikes against
  freshly-generated movies (the gating test was always
  synthetic-STA recovery — see "Phase 1 regression" below).

#### Phase 0b — Developer/Claude work (in repo)
- Tag/branch the current `rfMap` and `fix_present_squares(WiP)` so they
  remain restorable. Tag names: `rfMap-pre-unified-merge` and
  `fix-present-squares-pre-deletion`.
- Grep the repo (and any external analysis scripts the user knows of) for
  references to `fix_present_squares` paths or `stimMode` field, to scope
  downstream impact before touching either.

#### Note on file-format references throughout this plan
Where this document says "saved session" or "session file," it means
the PLDAPS session **folder** (`p.mat` + per-trial `trial<N>.mat`),
not a `.PDS` blob. Earlier drafts of this plan used `.PDS` — that was
an invented extension and has been corrected.

### Phase 1 — Refactor existing rfMap into stimulus-type-dispatched architecture
- Add `p.init.stimType` as a **string** with values
  `'denseAchromatic' | 'denseChromatic' | 'sparse' | 'checkerboard'`.
  **It lives on `p.init`, not `p.trVars`** — stim type is
  session-level immutable, set by which `_settings.m` was loaded,
  consumed once during `_init.m` for movie generation. Putting it
  in `trVars` would reintroduce the Phase-0a UX hazard (a GUI-
  mutable field whose value the underlying code reads only once).
  The string is what's saved to the session file (self-describing
  — analysis scripts don't need to consult `+pds/initCodes.m` to
  interpret a session). At strobe time only, it's mapped to an
  integer `1..4` for the wire format. The lookup table lives in
  `rfMap_commonSettings.m`.
- **Fix the seed-capture bug discovered in Phase 0a.** Per-stim-type
  settings files declare `p.init.noiseRngSeed` (settable, default
  pinned to a known integer like `12345`). Each per-type generator
  receives the seed as an explicit argument, calls `rng(seed,
  'twister')`, and **does not** rely on the broken
  `rng('shuffle')`-and-grab-previous-state idiom. The seed actually
  used is what's saved and strobed.
- **One `_settings.m` file per stim type** — not a single settings file
  with conditional GUI exposure. Concretely:
  - `tasks/rfMap/rfMap_denseAchromatic_settings.m`
  - `tasks/rfMap/rfMap_denseChromatic_settings.m`
  - `tasks/rfMap/rfMap_sparseBalanced_settings.m`
  - `tasks/rfMap/rfMap_checkerboard_settings.m`

  Each file declares only the parameters relevant to its stim type
  (DKL axes vs check sizes vs sparse density), preventing operator error
  like setting `checkContrasts` in a sparse session. The PLDAPS GUI's
  existing "load settings file" workflow — Browse → select file →
  Initialize, repeat per session — is the natural way to switch between
  modes. A small shared `rfMap_commonSettings.m` (or local helper) holds
  the parameters that are identical across all four. This replaces any
  notion of stim-type-conditional parameter exposure inside a single
  settings file.
- **Clean rename, no alias.** Confirmed via grep: `stimMode` and
  `colorMode` have zero consumers outside rfMap (rfMap_settings.m,
  rfMap_init.m, generateNoiseMovie.m, nextParams.m only). Both fields are
  removed from `p.trVars`. Bump `p.init.sessionFormatVersion` (new field)
  so any future analysis loaders can branch on schema. The strobe codes
  `noiseColorMode` (16105) and `noiseStimMode` (16113) are **kept in
  `+pds/initCodes.m` per the "holy" rule** but no longer strobed —
  comment them as deprecated, do not reuse the numbers.
- **`colorMode` collapse**: today `colorMode==2` (RGB random noise) is
  partially-implemented and unused. It is folded into
  `stimType=2 (denseChromatic)` going forward; no separate RGB-noise
  mode survives. Document this in the settings file comments.
- Split `supportFunctions/generateNoiseMovie.m` into a dispatcher plus
  per-type generators:
  - `generateStim_denseAchromatic.m` — current dense path, isolated.
  - `generateStim_sparseBalanced.m` — **new**, port feng_LGN's
    Twin-Deck/Pad-Block-Shuffle (`create_sparsechecks.m:37-150`) to replace
    today's uniform-random sparse. Rationale above. **The balanced port
    intentionally breaks bit-exact regression for sparse** — see testing
    section.
  - `generateStim_denseChromatic.m` — stub in Phase 1, filled in Phase 2.
  - `prepareStim_checkerboard.m` — stub in Phase 1, filled in Phase 3.
    Named `prepare*` rather than `generate*` because it pre-renders a
    texture pair × N conditions, not a frame-indexed movie tensor.
- **RNG contract for bit-exact dense regression**: each per-type generator
  begins with `rng(p.trVars.rngSeed)` (or equivalent state restore)
  immediately before its first random draw. Pre-allocations and
  parameter-derivation steps must not consume the RNG stream. Audit
  this at the dispatcher boundary.
- **Jitter-aware accumulator hook from day one**: even though Phase 4
  adds the actual jitter logic, all four `updateSTA_*` estimators take a
  per-trial `(jitterX, jitterY)` offset argument in their Phase-1
  signature, defaulted to `(0,0)`. This avoids re-touching chromatic and
  checkerboard estimators in Phase 4.
- Mirror the dispatcher pattern on the analysis side, **but only where
  the math actually differs**:
  - `updateSTA.m` → thin dispatcher → four per-type estimators
    (`updateSTA_denseAchromatic.m`, `updateSTA_denseChromatic.m`,
    `updateSTA_sparse.m`, `updateSTA_checkerboard.m`). The math is
    different in each (raw STA vs DKL-vector STA vs temporal kernel
    + F1/F2), so per-type files keep each implementation legible.
  - `plotSTA.m` → thin dispatcher → **only two** per-type plotters:
    `plotSTA_spatial.m` (handles denseAchromatic, denseChromatic,
    sparse — they all render an `[nY, nX, ...]` tensor with axes/lag
    selector/channel grid; chromatic adds a 3-panel L-M/S/Achro
    layout via an axis-count argument) and `plotSTA_checkerboard.m`
    (genuinely different layout: temporal-kernel traces stacked by
    (checkSize, contrast) + F1/F2 amplitude bars). Rationale:
    plotting math is the same across the three spatial modes; only
    labels and panel count differ. Splitting four ways here would be
    over-fragmentation.
- **Online plot throttling**: specify in settings:
  `p.trVars.staPlotEveryNTrials` (default 5) and
  `p.trVars.staPlotChannels` (default `[]` → all; can be a vector to
  restrict at high channel counts). The dispatcher updates accumulators
  every trial; the plotter renders only on schedule.
- **Trial-array column unification (locked)**: `trialArrayColumnNames`
  is **stim-type-conditional**, not a superset-with-NaN. Each
  per-stim-type `_settings.m` declares only its relevant columns
  (sparse omits checkSizeIdx/contrastIdx; checkerboard omits sparse
  density). Phase 4's jitter and aperture columns are appended to
  whichever stim type enables them. Analysis loaders branch on
  `stimType` + `sessionFormatVersion`. The superset-with-NaN
  alternative was rejected because it would let an operator
  unintentionally configure irrelevant columns at the GUI/array level
  — the same error the per-stim-type settings files are designed
  to prevent.
- Settings file gains a `p.init.stimTypeName` string (used in filenames /
  strobes) and stim-type-conditional defaults (check size, frame hold,
  lifetime, etc.).
- `rfMap_init.m`: lift the hard-coded `colorMode==1` block; replace with
  per-stim-type validation.
- Verify Phase-1 behavior is identical to current rfMap on **dense only**
  before moving on. Sparse gets a separate validation track (regression
  tests below).

**Phase dependency map (clarification):** Phase 1.5 gates **Phase 2
only**. Phases 3 (checkerboard) and 4 (jitter/aperture) depend only on
the Phase-1 dispatcher and are **not** blocked by the calibration
audit. If the colorimeter is delayed, work continues on Phases 3 and 4
in parallel.

### Phase 1.5 — DKL calibration audit (gates Phase 2)
- Measure monitor primaries (R, G, B chromaticities + max luminance) on
  the actual recording rig with a colorimeter / spectrophotometer.
- Measure / verify gamma curves per channel.
- Regenerate the DKL → RGB conversion matrix from these measurements.
- Validate by displaying canonical DKL axis stimuli (pure L-M, pure S,
  pure achromatic at known contrasts) and verifying the colorimeter
  readings match the intended cone excitations within tolerance.
- **Fallback if no colorimeter is available on-rig:** use vendor-published
  primaries + measured gamma (gamma can be measured with any photodiode
  or even photometer-grade luminance meter). Tag the saved session with
  `p.init.dklCalibrationSource = 'vendor_primaries+measured_gamma'` vs
  `'measured_primaries+measured_gamma'` so offline analysis can flag
  uncertainty. Vendor-primaries fallback is acceptable for screening but
  should be flagged in publications.
- **Phase 2 cannot start until calibration is documented and signed off,
  using whichever source was used.**

### Phase 2 — Chromatic dense noise
- **Audit the existing `dkl2rgb.m` and `initmon.m`** already present in
  `tasks/rfMap/supportFunctions/`. Diff them against the
  `fix_present_squares(WiP)` copies; identify which is canonical (or
  whether they have already diverged). Update the conversion matrix from
  the Phase-1.5 audit. They stay task-local for now; flag for later
  promotion to `+pds/` if other tasks need them.
- `generateStim_denseChromatic.m` produces a `[nY, nX, 3, nFrames]` RGB
  movie for display. **The per-check DKL drive vector is NOT saved to
  the session folder — it is recomputable from `(rngSeed, nY, nX,
  nFrames, dklAxes, dklContrasts)`.** A naive `[nY,nX,3,nFrames]` DKL
  tensor at
  typical sizes (e.g., 30×30×3×60000 doubles) is ~400 MB per session;
  storing it would bloat saved data and slow saves. The recomputation
  helper (e.g., `recomputeDklDrive.m`) lives in
  `tasks/rfMap/supportFunctions/` and is called by both online STA
  (during `_run`) and offline analysis. The seed and all generator
  parameters are strobed and saved to `p.init`/`p.trVars`.
- `updateSTA_denseChromatic.m` accumulates spatial STA against the DKL
  drive vector — output `[nY, nX, 3, nLags, nCh]`.
- `plotSTA_denseChromatic.m`: three side-by-side spatial maps (L-M, S,
  achromatic) at the user-selected lag.
- Strobe additions: `noiseDklAxis_x100`, `noiseDklContrast_x100`,
  `noiseDklHue_x10`.
- Update `data_dictionaries/rfMap_data_dictionary.md` (newly created in
  this phase — none currently exists) with the chromatic field set.

### Phase 3 — Checkerboard with online F1/F2 + temporal kernel
- `prepareStim_checkerboard.m` ports `create_Checkerboard.m` logic:
  pre-generate two-polarity texture pair per (checkSize, contrast)
  combination at startup. Store the polarity sequence over time as a
  `±1` vector (the analysis "stimulus").
- **GPU-memory back-of-envelope (operating point)**: 3 checkSizes ×
  3 contrasts × 2 polarities × 1920×1080 RGBA8 ≈ **143 MB** of texture
  memory; same configuration at 8-bit luminance ≈ 36 MB. Both fit
  comfortably on the rig GPU. Log peak texture-memory usage on first
  session and add a hard cap in `prepareStim_checkerboard.m` that errors
  out cleanly if a user expands to a configuration that would exceed
  ~512 MB.
- `rfMap_run.m`: at each scheduled reversal, switch the active polarity.
  **Strobe via `pds.classyStrobe.addValueOnce()` queued between draw and
  flip** (not synchronous DataPixx writes). Reversal rates are ≤10 Hz so
  the timing budget is comfortable, but keep the rule explicit: no
  blocking strobe writes inside the per-flip loop.
- Settings additions: `checkSizesDva` (vector — note: spatial-scale knob,
  not SF), `checkContrasts` (vector or pair), `checkReversalHz`,
  `checkApertureMode`.
- **Reversal-rate validator** (settings-time): `checkReversalHz` must
  divide `p.rig.refreshRate` evenly. At 100 Hz the legal set is
  `{50, 25, 20, 10, 5, 4, 2, 1}` Hz. Warn or error on mismatch.
- **F1/F2 frequency safety**: F2 = 2·`checkReversalHz` must remain below
  Nyquist (frame_rate/2). At 100 Hz, `checkReversalHz ≤ 25` Hz keeps F2
  below Nyquist. Anything above aliases — validator should reject.
- Analysis files (`updateSTA_checkerboard.m`, `plotSTA_checkerboard.m`):
  - **Temporal reverse-correlation**: spike-triggered average of the ±1
    polarity sequence at lags 1..nSTALags, accumulated per
    (channel, checkSize, contrast). **Per-condition accumulation, not
    per-channel only** — that's how a single session yields contrast
    response and a coarse spatial-scale comparison.
  - **F1/F2**: per-trial complex sums
    `Σ_t cos(2πf·t)·s(t) + i·Σ_t sin(2πf·t)·s(t)` for
    `f ∈ {check_crf, 2·check_crf}`, with **t = 0 at trial start**
    (reversal phase aligned per trial — `t` resets each trial). The
    per-trial complex value is then averaged across trials within each
    (checkSize, contrast, channel) cell as `mean(|z|)` for amplitude.
    Phase is computed but not phase-locked across trials (no
    inter-trial reversal-phase guarantee). `computeF1F2.m` helper.
  - **Reporting convention (locked)**: report **raw amplitude** (sqrt of
    squared sum) AND the F1/(F1+F2) modulation index. Magno-vs-parvo
    typing relies on the modulation index; raw amplitude is needed for
    SNR judgment. Phase is computed but not plotted online (saved for
    offline use).
  - **Per-condition minimum-N target (rule of thumb, validate on
    first session)**: starting target ≈ **40 trials per (checkSize,
    contrast) cell** for visually-recognizable temporal kernels and
    **≈ 80 trials per cell** for stable F1/F2 amplitudes. These are
    extrapolations from typical LGN reverse-correlation sessions, not
    derived from a power analysis. **Validate on the first real
    session** by computing the F1/F2 amplitude bootstrap CI as a
    function of trial count per cell, and revise the target accordingly
    before treating it as a default. Document the calibrated target in
    the on-rig README once measured.
  - Plot: temporal-kernel traces stacked by (checkSize, contrast); F1/F2
    amplitude bars adjacent. Throttle per Phase-1's
    `staPlotEveryNTrials` setting.

### Phase 4 — Spatial jitter + restricted apertures (opt-in, all stim types)
- Add `p.trVars.jitterMode` (`'none' | 'perTrial'`) and
  `p.trVars.jitterRangeDva` (4-vector). Compute per-trial pixel offset in
  `rfMap_next.m`, apply via the source rect in
  `Screen('DrawTexture', …, srcRect, dstRect, …)` rather than regenerating
  textures — pattern from `feng_LGN/run_Checkerboard.m:111-119`.
- **Jitter-margin convention (locked)**: each generator allocates the
  noise tensor at `(nY + 2·marginY) × (nX + 2·marginX)` where
  `marginX = ceil(maxJitterX / checkSizePix)` and similarly for Y. The
  *unjittered* center region is the configured grid, exposed online via
  `srcRect`. Without margin, srcRect-based jitter runs off the texture
  edge. Document this in each `generateStim_*` header and in the
  data dictionary.
- **Aperture API**: `p.trVars.apertureMode`
  (`'fullField' | 'rect' | 'circle'`), `apertureCenterDva`,
  `apertureSizeDva` are **per-trial**. Pre-generate a small bank of
  alpha-mask textures in `_init` covering the discrete settings the
  task will actually use (per the trial array); fall back to on-demand
  generation in `_next` if the trial requests an unbanked combination.
  Avoid generating a unique mask per trial in `_run` — texture creation
  inside the per-flip loop is the timing risk.
- The Phase-1 jitter-aware accumulator hooks now activate: per-trial
  `(jitterX, jitterY)` is passed to each `updateSTA_*` and used as a
  spatial-index offset into the cumulative map.
- Strobe per-trial jitter offset (`jitterX_x10`, `jitterY_x10`) and
  aperture parameters; store in `p.trData` for offline reconstruction.
- Defaults: both options off → existing behavior unchanged.

### Phase 5 — Cleanup
- Re-run the Phase-0 grep for `fix_present_squares` and `stimMode` to
  confirm no live references before deletion.
- `git rm -r tasks/fix_present_squares(WiP)/`. The Phase-0 tag is the
  archive — no `_archive/` directory needed; that just pollutes the tree.
- Finalize `data_dictionaries/rfMap_data_dictionary.md` (already created
  in Phase 2, extended in Phase 3); ensure all per-stim-type fields,
  trial-array column conventions, and the strobe-code table are
  documented there. **Project convention is data-dictionary-driven**, so
  the dictionary is the canonical reference — no separate
  `tasks/rfMap/README.md`. The dictionary's opening section enumerates
  stim types, their parameters, and which estimator runs for each,
  including the explicit "checkerboard does not give a spatial RF
  online" caveat.

## Files touched (cumulative)

### Modified
- **`tasks/rfMap/rfMap_settings.m` is replaced** by the four per-stim-type
  settings files plus `rfMap_commonSettings.m` (see Phase 1). Each
  per-type file declares only its relevant parameters, jitter/aperture
  fields, and a `sessionFormatVersion`. The current monolithic
  `rfMap_settings.m` is removed in Phase 5 once the four replacements
  are tested.
- `tasks/rfMap/rfMap_init.m` — dispatch generator by `stimType`; lift RGB
  block.
- `tasks/rfMap/rfMap_next.m` — compute jitter offset; select condition
  (checkSize/contrast) for checker; resolve aperture mask from the
  pre-generated bank (or on-demand fallback).
- `tasks/rfMap/rfMap_run.m` — branch draw call by `stimType`; handle
  checkerboard reversal scheduling and queued polarity strobe.
- `tasks/rfMap/rfMap_finish.m` — branch STA accumulation by stim type;
  handle exclusion of large per-type buffers from saved `p`.
- `tasks/rfMap/supportFunctions/updateSTA.m` — thin dispatcher; passes
  `(jitterX, jitterY)` to per-type estimators.
- `tasks/rfMap/supportFunctions/plotSTA.m` — thin dispatcher.
- `tasks/rfMap/supportFunctions/initSTADisplay.m` — figure layout choice
  driven by stim type.
- `tasks/rfMap/supportFunctions/dkl2rgb.m` — already exists; audit and
  update conversion matrix from Phase-1.5 calibration.
- `tasks/rfMap/supportFunctions/initmon.m` — already exists; audit and
  update.
- `+pds/initCodes.m` — append codes for stimType, sessionFormatVersion,
  chromatic params, checker params, polarity reversals, jitter offsets,
  aperture params (new code numbers in the **16140–16175** block, after
  barsweep's last code at 16136; do **not** renumber existing entries —
  the file is "holy" per CLAUDE.md). Mark `noiseColorMode` (16105) and
  `noiseStimMode` (16113) as deprecated in comments; keep numbers
  reserved.

### Added
- `tasks/rfMap/supportFunctions/generateStim_denseAchromatic.m`
- `tasks/rfMap/supportFunctions/generateStim_denseChromatic.m`
- `tasks/rfMap/supportFunctions/generateStim_sparseBalanced.m`
- `tasks/rfMap/supportFunctions/prepareStim_checkerboard.m`
- `tasks/rfMap/supportFunctions/updateSTA_denseAchromatic.m`
- `tasks/rfMap/supportFunctions/updateSTA_denseChromatic.m`
- `tasks/rfMap/supportFunctions/updateSTA_sparse.m`
- `tasks/rfMap/supportFunctions/updateSTA_checkerboard.m`
- `tasks/rfMap/supportFunctions/plotSTA_spatial.m` (handles
  denseAchromatic, denseChromatic, sparse via axis-count argument)
- `tasks/rfMap/supportFunctions/plotSTA_checkerboard.m`
- `tasks/rfMap/supportFunctions/recomputeDklDrive.m` (regenerates the
  DKL drive vector tensor from saved seed + params; used by online STA
  and offline analysis)
- Per-stim-type settings files (Phase 1):
  `rfMap_denseAchromatic_settings.m`,
  `rfMap_denseChromatic_settings.m`,
  `rfMap_sparseBalanced_settings.m`,
  `rfMap_checkerboard_settings.m`,
  plus a shared `rfMap_commonSettings.m` for parameters identical
  across all four.
- `tasks/rfMap/supportFunctions/applyJitterAndAperture.m` (helper used
  inside `_run`)
- `tasks/rfMap/supportFunctions/computeF1F2.m`
- `tasks/rfMap/_validation/compare_old_vs_new_generators.m` (Phase 1
  developer-side harness: pinned-seed byte-comparison of old
  `generateNoiseMovie.m` (loaded from `rfMap-pre-unified-merge` tag)
  against new `generateStim_denseAchromatic.m`, plus synthetic-spike
  STA equivalence test old `updateSTA` vs new
  `updateSTA_denseAchromatic`. Run during Phase 1 development; not
  part of the shipped task.)
- `data_dictionaries/rfMap_data_dictionary.md` — created in Phase 2,
  extended through Phase 4.

### Removed (Phase 5)
- `tasks/rfMap/supportFunctions/generateNoiseMovie.m` (logic absorbed into
  the per-type generator files).
- `tasks/fix_present_squares(WiP)/` (deleted via `git rm`; Phase-0 tag is
  the archive).

## Strobe-code additions (`+pds/initCodes.m`)

**Block conflict check (verified):** barsweep occupies `16115–16136`
(see `+pds/initCodes.m:273-296`). The next free contiguous range is
`16137+`.

**Concrete code assignment (locked before Phase 1 lands).** Once any
session strobes a number, it is permanent per CLAUDE.md's "holy" rule.
Pinning the table now prevents mid-Phase-3 collisions. Reserved range
**16140–16175** (36 codes total, with headroom at 16170–16175 for
late additions). Every code listed here must appear in `p.init.strobeList`.

| Code   | Name                          | Phase | Meaning |
|--------|-------------------------------|-------|---------|
| 16140  | `rfMapStimType`               | 1 | 1=denseAchro, 2=denseChroma, 3=sparse, 4=checker |
| 16141  | `rfMapSessionFormatVersion`   | 1 | schema version (integer) |
| 16142  | `rfMapDklAxisIdx`             | 2 | DKL axis index (1=L-M, 2=S, 3=achromatic, 4=mixed) |
| 16143  | `rfMapDklContrast_x100`       | 2 | DKL contrast × 100 |
| 16144  | `rfMapDklHue_x10`             | 2 | DKL hue (deg) × 10 (0..3600) |
| 16145  | `rfMapDklCalibSource`         | 2 | 1=measured_primaries, 2=vendor_primaries |
| 16146  | `rfMapCheckSizeIdx`           | 3 | index into `checkSizesDva` |
| 16147  | `rfMapCheckContrastIdx`       | 3 | index into `checkContrasts` |
| 16148  | `rfMapCheckReversalHz_x10`    | 3 | reversal rate (Hz) × 10 |
| 16149  | `rfMapCheckPolaritySign`      | 3 | 1 = +1 polarity, 2 = −1 polarity (offset to stay positive) |
| 16150  | `rfMapCheckReversalEvent`     | 3 | strobed at each reversal flip (value = polarity sign) |
| 16151  | `rfMapJitterX_x10`            | 4 | per-trial jitter X (dva) × 10 + 1800 (offset for negatives) |
| 16152  | `rfMapJitterY_x10`            | 4 | per-trial jitter Y (dva) × 10 + 1800 |
| 16153  | `rfMapJitterMode`             | 4 | 1=none, 2=perTrial |
| 16154  | `rfMapApertureMode`           | 4 | 1=fullField, 2=rect, 3=circle |
| 16155  | `rfMapApertureCenterTheta_x10`| 4 | aperture center polar angle × 10 + 1800 |
| 16156  | `rfMapApertureCenterRadius_x100` | 4 | aperture center eccentricity × 100 |
| 16157  | `rfMapApertureSize_x100`      | 4 | aperture size (dva) × 100 |
| 16158  | `rfMapSparseBalancedFlag`     | 1 | 1 = uniform-random (legacy), 2 = balanced TwinDeck |
| 16159  | `rfMapRngSeedHigh`            | 1 | RNG seed upper 16 bits (lower 16 stay in existing `noiseRngSeed` 16106 — kept active for backwards reading) |
| 16160–16169 | (reserved future per-stim-type params) | — | leave free |
| 16170–16175 | (headroom)                   | — | leave free |

**Deprecated (kept reserved, not strobed):**
- `noiseColorMode` (16105) — superseded by `stimType`.
- `noiseStimMode` (16113) — superseded by `stimType`. The semantic
  collision (16113's `1=dense, 2=sparse` vs new `stimType` enum
  `1=denseAchro, 2=denseChroma, 3=sparse, 4=checker`) is the reason
  16113 is **not** reused — old session files retain their original
  meaning, and new sessions strobe the new code.

## Decisions locked in

1. **One stim type per session** (no within-session interleaving).
   Locked. The PLDAPS GUI's load-settings-then-Initialize workflow is
   the supported way to switch between modes mid-recording: load
   `rfMap_denseAchromatic_settings.m`, Initialize, Run; then load
   `rfMap_sparseBalanced_settings.m`, Initialize, Run. Each mode
   produces its own `.PDS` file. Block-level interleaving inside a
   single session is explicitly out of scope — it would require
   per-block re-randomized trial arrays, per-block STA accumulator
   resets, and GUI support for mid-session mode switch. Not adopted.
2. **Chromatic STA in DKL coordinates** (not RGB). Decouples analysis from
   calibration drift.
3. **Checker temporal kernel and F1/F2 are computed per (checkSize,
   contrast) condition**, not just per channel. This is what makes a
   single session yield contrast response.
4. **`dkl2rgb` lives task-local** for now, flagged for promotion to
   `+pds/dkl2rgb.m` later if reused.
5. **Clean rename, no `stimMode` alias.** Verified zero external
   consumers; the prior "mirrored alias" plan was back-compat theater.
   Bump `sessionFormatVersion`; deprecate the old strobe codes
   (`noiseColorMode`, `noiseStimMode`) in place per the "holy" rule.
6. **`colorMode==2` (RGB random noise) is killed**, not migrated as a
   fifth stim type. Folded into `stimType=2 (denseChromatic)`. Code
   16105 (`noiseColorMode`) reserved-but-deprecated.

## Testing & validation

Tighter, less hand-wavy than the prior draft.

- **Phase 0a (user)**: complete with caveats — see "Phase 0a outcome"
  above. One usable dense baseline retained as a structural
  reference; sparse re-collection skipped after discovering two
  generator/UX bugs (recorded in "Phase 0a findings"). The revised
  regression contract runs in-repo via the side-by-side validation
  harness, not against a saved session file.
- **Phase 0b (repo)**: tags created, grep results documented.
- **Phase 1 regression (split test)**:
  - **Dense (bit-exact required, in-repo)**: a developer-side harness
    `tasks/rfMap/_validation/compare_old_vs_new_generators.m`
    invokes the *current* `generateNoiseMovie.m` (from the
    `rfMap-pre-unified-merge` tag) and the *new*
    `generateStim_denseAchromatic.m` with the same pinned seed and
    byte-compares the returned movie tensors. Same harness feeds
    a synthetic spike train into both old `updateSTA` and new
    `updateSTA_denseAchromatic` against the byte-identical movie;
    STA outputs must be numerically identical. **No rig session
    needed.** The RNG contract must hold: `rng(seed, 'twister')`
    is called immediately before the per-type generator's first
    random draw, no upstream pre-allocation order changes.
  - **Sparse — gating test is the synthetic STA recovery**: the
    Twin-Deck/Pad-Block-Shuffle port intentionally changes the per-frame
    distribution, so bit-exact regression is impossible by design. The
    **pass/fail criterion for shipping Phase 1 sparse** is: on a
    synthetic spike train phase-locked to one cell, the recovered STA
    peak is at the correct cell with SNR ≥ the old uniform-random
    implementation (matched spike count). The per-frame-mean and marginal
    statistics are sanity checks of the *generator*, not validation of
    the estimator — they must also pass, but they are not what
    determines whether the new sparse path is correct.
  - **On-rig smoke test (gate before ship)**: a short live session on
    the actual recording rig with sham (or real) Ripple ingestion must
    complete cleanly with the dispatcher refactor before Phase 1 ships.
    Synthetic + offline checks alone are not sufficient; real-time
    timing, Ripple strobing, and `pds.classyStrobe` queue behavior need
    verification on hardware.
  - Old session folders (pre-refactor `p.mat` + `trial<N>.mat`) do
    **not** need to load under new code (clean rename,
    schema-version-bumped); offline analysis pipelines branch on
    `sessionFormatVersion`.
- **Phase 1.5**: colorimeter readings on canonical DKL axis stimuli match
  intended cone excitations within stated tolerance, documented per axis.
- **Phase 2**:
  - DKL → RGB → DKL round-trip on canonical axis vectors within numerical
    tolerance (closed-form unit test).
  - Bit-exact RNG-seed reproducibility for `generateStim_denseChromatic`.
  - **DKL-axis recovery test (locked spec)**: synthesize three separate
    spike trains, each phase-locked to a single chromatic check on one
    DKL axis (one for L-M, one for S, one for achromatic), at a known
    spatial location and lag. The online STA must (a) put the peak at
    the correct (x, y) location and (b) put the peak energy on the
    correct DKL axis (the other two axes' peaks at that location must
    be ≤ 1/3 the magnitude of the driven axis). A test that only
    recovers spatial location with arbitrary chromatic axis assignment
    is a fail.
  - On-rig smoke test on real Ripple hardware before shipping.
- **Phase 3**:
  - Bit-exact RNG-seed reproducibility for the checker polarity sequence.
  - Closed-form F1/F2 unit test: feed a synthetic sinusoid of known
    amplitude and phase at frequency `f` into `computeF1F2`; recover
    amplitude and phase within numerical tolerance.
  - Reversal events strobe at the configured rate (verify timestamps from
    one session offline).
  - Strobe queue depth audit: log queue length each flip across a
    long session; confirm bounded.
  - On-rig smoke test on real Ripple hardware before shipping.
- **Phase 4**:
  - Per-trial jitter offsets distribute uniformly over the configured range
    (Kolmogorov-Smirnov check on a session of trials).
  - Aperture mask covers exactly the configured pixels (image diff on a
    test frame).
  - On-rig smoke test on real Ripple hardware before shipping.
- Each phase ships only after passing its checks, before the next phase
  begins.

## Reference files

- Current rfMap: `tasks/rfMap/` (quintet + `supportFunctions/`).
- Deprecated: `tasks/fix_present_squares(WiP)/` (multi-stim-type scaffolding
  in `supportFunctions/nextParams.m:236-334`; DKL pipeline in
  `supportFunctions/dkl2rgb.m`, `supportFunctions/initmon.m`).
- Collaborator reference: `~/Downloads/feng_LGN/`
  - Balanced sparse: `create_sparsechecks.m:37-150`.
  - Multi-condition / contrast-reversing checkerboard:
    `create_Checkerboard.m`, `run_Checkerboard.m`.
  - Spatial jitter pattern: `run_Checkerboard.m:111-119`.
  - Aperture pattern: `run_Checkerboard.m:71-108`.
