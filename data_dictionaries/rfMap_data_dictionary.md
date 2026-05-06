# Data Dictionary for `rfMap` Task

This document describes the fields and subfields of the data structures
saved during the `rfMap` task (post-unified-merge: Phase 1 dispatcher
architecture, Phase 2 chromatic). The `p` structure is saved once at
session start; per-trial files contain `p.trVars` and `p.trData`.

For the rationale and phasing of the merge, see
`analysisPlanningDocs/rfMap_unified_merge_plan.md`.

## Stim types overview

`rfMap` is a unified passive-fixation receptive-field-mapping task with
four stim-type modes. **One stim type per session**, pinned by which
per-stim-type `_settings.m` was loaded:

| `p.init.stimType`  | Settings file                          | Online estimator output                | Status   |
|--------------------|----------------------------------------|----------------------------------------|----------|
| `denseAchromatic`  | `rfMap_denseAchromatic_settings.m`     | spatial STA `[nY, nX, nLags]`          | Phase 1  |
| `denseChromatic`   | `rfMap_denseChromatic_settings.m`      | DKL spatial STA `[nY, nX, 3, nLags]`   | Phase 2  |
| `sparse`           | `rfMap_sparseBalanced_settings.m`      | spatial STA `[nY, nX, nLags]`          | Phase 1  |
| `checkerboard`     | `rfMap_checkerboard_settings.m`        | per-condition temporal kernel + F1/F2  | Phase 3  |

Important caveats:

- **Checkerboard does NOT yield an online spatial RF.** The spatial
  pattern is fixed; only polarity reverses. Online output is a
  per-(channel, checkSize, contrast) temporal kernel via reverse-
  correlation against the ±1 polarity sequence, plus per-(channel,
  checkSize, contrast) F1/F2 amplitudes from per-trial complex sums.
  Reporting convention (locked): raw amplitude AND the F1/(F1+F2)
  modulation index; phase is computed but not plotted online. Cross-
  trial average is `mean(|z|)` (no phase-locking across trials, since
  reversal phase is reset at each trial start). "Check size" is a
  pragmatic spatial-scale knob, **not** a clean spatial-frequency
  manipulation. Use a different mode (dense or sparse) for online
  spatial mapping.
- **Chromatic STA is accumulated against the DKL drive vector**, not
  RGB. This decouples offline analysis from rig calibration drift.
  The drive tensor itself is NOT saved (recomputable from the seed and
  parameters via `recomputeDklDrive.m`).
- **`stimMode` and `colorMode` no longer exist.** Old session files
  (pre-Phase-1) used those fields; new sessions use `p.init.stimType`
  (string) and `p.init.sessionFormatVersion` (integer). Analysis loaders
  must branch on `sessionFormatVersion`.

## `p` Structure

### `p.init`

Session-level immutable fields. Set in `_commonSettings.m` and the
per-stim-type `_settings.m`; consumed once during `_init.m`.

| Field | Type | Description |
|---|---|---|
| `pcName` | string | Hostname of the rig PC. |
| `rigConfigFile` | string | Path to the rig configuration `.m` file. |
| `taskName` | `'rfMap'` | Task name. |
| `taskCode` | int | Numeric task code (32020). |
| `pldapsFolder` | string | Repo root. |
| `date`, `time` | string | yyyymmdd / HHMM at session start. |
| `sessionFormatVersion` | int | Schema version. **Bump on incompatible changes.** v1 = initial Phase-1 merge. v2 = chromatic switched to per-trial seeded generation; chromatic `dklDriveTensor` and `noiseMovie` no longer held at session level (offline analysis pulls per-trial seeds from `trialsArray(:, 'chromaticSeed')`). |
| `stimType` | string | One of `denseAchromatic` \| `denseChromatic` \| `sparse` \| `checkerboard`. **Self-describing** -- analysis scripts should branch on this string, not the integer. |
| `stimTypeIntMap` | struct | String -> integer lookup used at strobe time only. |
| `stimTypeInt` | int | Integer form of `stimType` for the wire format (1=denseAchromatic, 2=denseChromatic, 3=sparse, 4=checkerboard). |
| `sessionId` | string | `<date>_t<time>_rfMap_<stimType>`. |
| `sessionFolder` | string | Output folder for this session. |
| `outputFolder`, `figureFolder` | string | Top-level output paths. |
| `taskFiles` | struct | Names of `_init`/`_next`/`_run`/`_finish` files. |
| `taskActions` | cell | Action M-file names. |
| `noiseRngSeed` | int | RNG seed used to generate the noise movie / drive tensor. **Always pinned to a known integer**; never `rng('shuffle')` (that idiom captures the previous seed, not the new one -- see Phase-0a findings in the merge plan). |
| `noiseGridSize` | `[nY nX]` | Number of checks. |
| `nNoiseFrames` | int | Total noise frames pre-generated. |
| `noiseFrameIdx` | int | Playback position; advances on successful trials. |
| `noiseMovie` | array | Pre-rendered session-level movie for **denseAchromatic / sparse only**. Single-channel indexed `[nY,nX,nFrames]` so the L48 framebuffer-as-CLUT-index path displays them correctly: uint8 0/1 (denseAchromatic, mapped at draw time to `{expBlack, expWhite}` slots); int8 in {-1,0,+1} (sparse, mapped to `{expBlack, expBg, expWhite}`). **Stripped before save** (recomputable from `noiseRngSeed`). For **denseChromatic this field is empty at the session level** (sessionFormatVersion ≥ 2); the per-trial movie lives on `p.trVars.thisTrialNoiseMovie` and is regenerated each trial from the trial's `chromaticSeed`. |
| `dklDriveTensor` | -- | **Empty at the session level for sessionFormatVersion ≥ 2.** Pre-2 sessions held the whole-session `[nY,nX,3,nFrames]` single tensor here; v2+ regenerates per trial onto `p.trVars.thisTrialDklDrive` from the per-trial `chromaticSeed`. The session-level tensor at LGN check sizes (~88×136) for a 10-min session would be ~8.6 GB; per-trial generation is ~70 MB per trial and gc'd at trial end. |
| `chromaticClutBase` | int | (denseChromatic only.) First CLUT row index (0-based) where the 8 tri-noise palette entries are installed. Texture value `k` (0..7) lives at slot `chromaticClutBase + k`. Set during `_init.m`; saved to disk. |
| `chromaticPaletteRGB` | `[3,8]` uint8 | (denseChromatic only.) The 8 gamma-corrected RGB triples (column k = state k-1). Built from `dkl2rgb(...)` via `buildChromaticPalette`. Saved so offline analysis can reconstruct the displayed colors without re-loading the rig calibration. |
| `chromaticStateBits` | `[3,8]` int8 | (denseChromatic only.) +/-1 sign matrix mapping state index to (L-M, S, Achro) signs. Saved for offline reconstruction. |
| `dklDriveVariancePerAxis` | `[1,3]` double | (denseChromatic only.) `c_axis^2` per axis in order `[LM, S, Achro]`; inactive axes are 0. With non-uniform per-axis contrasts the recovered STA amplitude scales by `c_axis`, so cross-axis tuning comparisons must divide `|sta(:,:,axis,k)|` by `sqrt(dklDriveVariancePerAxis(axis))` before treating the per-axis amplitudes as comparable. With uniform contrast (the default) all entries are equal and the renormalization is a no-op. |
| `checkerboardClutBase` | int | (checkerboard only.) First CLUT row index (0-based) where the checkerboard contrast-pair grays were installed. Each contrast level uses 2 consecutive slots: `lowSlots(k) = checkerboardClutBase + 2*(k-1)`, `highSlots(k) = checkerboardClutBase + 2*(k-1) + 1`. |
| `checkerboardLowSlots`/`HighSlots` | `[1, nContrast]` | (checkerboard only.) 0-based CLUT slots holding the gamma-corrected dark/bright gray for each contrast. Pre-rendered textures contain only these two values per condition. |
| `checkInfo` | struct | (checkerboard only.) Texture-prep result. Fields: `.textures` (`[nCheckSize, nContrast, 2]` PTB handles, persistent across trials), `.framesPerReversal` (integer; how many display frames between polarity flips), `.conditionTable`, `.nCheckSize`, `.nContrast`, `.nConditions`, `.checkSizePix`, `.totalBytes`. `.textureData` is cleared after upload. `.destRect` is screen-sized. |
| `dklCalibrationSource` | string | (denseChromatic only.) `'measured_primaries+measured_gamma'` or `'vendor_primaries+measured_gamma'`. Strobed as `rfMapDklCalibSource` (1 / 2). |
| `dklAxisIdxStrobe` | int | (denseChromatic only.) Pre-computed value for the `rfMapDklAxisIdx` strobe (1=L-M, 2=S, 3=Achro, 4=mixed tri-noise). |
| `dklCalibSourceStrobe` | int | (denseChromatic only.) Pre-computed value for the `rfMapDklCalibSource` strobe. |
| `staAccum` | cell of arrays | Online STA accumulator. Phase 1 layout `[nY,nX,nLags]` per channel; chromatic `[nY,nX,3,nLags]`; checkerboard TBD. **Stripped before save**; only persisted at session end if needed. |
| `staSpikeCount` | `[nCh,1]` | Spike count contributing to each channel's STA. |
| `staFigData` | struct | Online figure handles. **Stripped before save** (handles don't serialize). |
| `strobeList` | cell `{name, expr}` | Variables to strobe each trial. Eval'd at strobe time. **Common base** comes from `_commonSettings`; per-stim-type files append entries (chromatic adds DKL params, sparse adds the balanced-flag, etc.). |
| `codes` | struct | Lookup table `name -> code`, populated from `pds.initCodes`. The `+pds/initCodes.m` file is **holy** -- never reuse a code number once it has been strobed in any session. |
| `strb` | `pds.classyStrobe` | Strobe object that buffers (code, value) pairs and writes them in queued batches. |

### `p.trVarsInit` / `p.trVars` / `p.trVarsGuiComm`

Trial variables. `trVarsInit` are the defaults from settings; `trVarsGuiComm`
is the GUI-mutable mirror; `trVars` is the working copy each trial reads
from `trVarsGuiComm`.

Common fields (all stim types):

| Field | Default | Description |
|---|---|---|
| `passEye`, `passJoy` | 0/1 | Pass through eye / joystick samples. |
| `repeat`, `blockNumber`, `finish` | -- | Standard PLDAPS bookkeeping. |
| `checkSizeDeg` | 2 | Side length of one check in dva. |
| `noiseFrameHold` | 6 (12 chromatic) | Display frames per noise frame. |
| `contrastBinary` | 1 | 1 = binary (0/1), 0 = continuous uniform. (Achromatic only.) |
| `clearPatchDeg`, `clearPatchShape` | 1.0, 1=disk | Hide region around fixation. |
| `movieDurationMin` | 10 | Total noise movie length (minutes). |
| `noiseRngSeed` | 12345 | Pinned seed for the movie. |
| `trialDurationS` | 1.5 | Per-trial noise presentation duration. |
| `fixWaitDur`, `rewardDurationMs`, `timeoutAfterFixBreak` | -- | Timing. |
| `fixDegX`, `fixDegY`, `fixWinWidthDeg`, `fixWinHeightDeg` | -- | Fixation. |
| `connectRipple`, `useOnlineSort`, `useRippleSTA` | 0/0/0 | Ripple integration. |
| `nSTALags`, `nChannels` | 8, 32 | STA dimensions. |
| `staPlotEveryNTrials`, `staPlotChannels` | 5, [] | Online-plot throttling. |

Stim-type-specific:

| Field | Used by | Description |
|---|---|---|
| `dklAxes` | denseChromatic | Active DKL axes (subset of `[1 2 3]` for L-M / S / Achro). Default `[1 2 3]` (tri-noise). |
| `dklContrasts` | denseChromatic | Per-axis contrast magnitude. Scalar (broadcast) or vector. Default 0.45 = 0.95 × `gamutMaxContrasts([1 2 3], [1 1 1])` on rig1/rig2 (max safe uniform contrast 0.4738; 5% margin against fp / quantization). To pick a principled value for a different rig, call `gamutMaxContrasts(dklAxes, axisRatios)` from the rig command line after `initmon(LUT_VPIXX_rigN)`. `initClut` errors with the rig's max safe value if the configured contrast clips any corner. |
| `nSparseSpots` | sparse | Number of nonzero spots per frame. |
| `sparseBalancedFlag` | sparse | 1 = legacy uniform-random, 2 = balanced TwinDeck (default). |
| `checkSizesDva` | checkerboard | Vector of check side lengths in dva. Pragmatic spatial-scale knob, NOT a clean SF manipulation (checkerboards are SF-broadband). |
| `checkContrasts` | checkerboard | Vector of Michelson contrasts in (0, 1]. Each level reserves 2 CLUT slots (gamma-corrected via `dkl2rgb([±c; 0; 0])`). |
| `checkReversalHz` | checkerboard | Polarity reversal frequency. **Validators**: must divide refresh rate evenly AND `2*checkReversalHz < refreshRate/2` (Nyquist). `prepareStim_checkerboard` errors with the legal set if either fails. |
| `checkRepsPerCondition` | checkerboard | Trials per (checkSize, contrast) cell. Plan-target ≈ 80 for stable F1/F2; default 12 for short test sessions, calibrate against bootstrap CIs on first real session. |
| `checkGpuMemCapBytes` | checkerboard | Hard cap on pre-rendered texture memory. Default 512 MB. `prepareStim_checkerboard` errors before allocating if the configured combination would exceed. |

### `p.trData`

Per-trial collected data.

| Field | Description |
|---|---|
| `eyeX`, `eyeY`, `eyeP`, `eyeT` | Eye-position samples buffered from DataPixx ADC. |
| `joyV` | Joystick voltage. |
| `dInValues`, `dInTimes` | DataPixx digital-in event log. |
| `onlineEyeX`, `onlineEyeY` | Per-frame online eye samples. |
| `spikeTimes`, `spikeClusters` | Ripple spike data (channel = cluster). Empty if no probe / Ripple disabled. |
| `eventTimes`, `eventValues` | Ripple digital-event timestamps. |
| `timing.lastFrameTime`, `trialStartPTB`, `trialStartDP` | Frame / trial start times. |
| `timing.fixOn`, `fixAq`, `fixBreak`, `noiseOn`, `noiseOff`, `reward`, `tone`, `trialEnd` | Event timestamps (relative to trial start). **All initialize to -1**; check `> 0` before use (postFlip-assigned timing variables are not real until the corresponding flip has happened). |
| `timing.flipTime` | Per-flip timestamps (preallocated 3000 entries). |
| `trialEndState` | Final state value. |
| `trialRepeatFlag` | True if trial aborted (state 11..19). |
| `missedFrameCount` | Frames where `diff(flipTime) > 1.5 * frameDuration`. |
| `strobed` | Cell of (code, value) pairs strobed this trial (mirror of `pds.classyStrobe.strobedList`). |

### `p.state`

| State | Value | Meaning |
|---|---|---|
| `trialBegun` | 1 | Initial state, strobes trialBegin. |
| `showFix` | 2 | Fixation point shown; waiting for acquisition. |
| `holdFixAndPlay` | 3 | Noise movie playing. |
| `fixBreak` | 11 | Trial aborted (fixation broken). |
| `nonStart` | 13 | Trial aborted (fixation not acquired in time). |
| `noiseComplete` | 21 | Successful trial; reward delivered. |

## Strobe codes used by `rfMap`

These are appended to `+pds/initCodes.m`; numbers are reserved per the
"holy" rule (do not reuse). See merge plan §"Strobe-code additions" for
the full block (16140-16175 reserved).

| Code | Name | Phase | Meaning |
|---|---|---|---|
| 16140 | `rfMapStimType` | 1 | 1=denseAchro, 2=denseChroma, 3=sparse, 4=checker |
| 16141 | `rfMapSessionFormatVersion` | 1 | Schema version. |
| 16142 | `rfMapDklAxisIdx` | 2 | 1=L-M, 2=S, 3=Achro, 4=mixed tri-noise. |
| 16143 | `rfMapDklContrast_x100` | 2 | DKL contrast * 100 (max across active axes). |
| 16144 | `rfMapDklHue_x10` | 2 | (Reserved; not strobed by tri-noise mode.) |
| 16145 | `rfMapDklCalibSource` | 2 | 1=measured_primaries, 2=vendor_primaries, 0=other. |
| 16146 | `rfMapCheckSizeIdx` | 3 | Per-trial: 1..nCheckSize index into `checkSizesDva`. |
| 16147 | `rfMapCheckContrastIdx` | 3 | Per-trial: 1..nContrast index into `checkContrasts`. |
| 16148 | `rfMapCheckReversalHz_x10` | 3 | Reversal Hz × 10 (session-constant). |
| 16149 | `rfMapCheckPolaritySign` | 3 | Initial polarity (1 = +1, 2 = -1; reserved, not currently strobed since the schedule always starts at +1). |
| 16150 | `rfMapCheckReversalEvent` | 3 | Strobed at each polarity-flip flip (queued via `addValue` between draw and flip; the value is the new polarity, 1 = +1, 2 = -1). |
| 16151-16157 | (cancelled; reserved-but-unused) | — | Originally allocated for jitter / aperture params (Phase 4). Phase 4 was cancelled before implementation; numbers stay reserved per the "holy" rule. |
| 16158 | `rfMapSparseBalancedFlag` | 1 | 1=legacy uniform-random, 2=balanced TwinDeck. |
| 16159 | `rfMapRngSeedHigh` | 1 | Upper 16 bits of `noiseRngSeed`. Lower 16 stay in `noiseRngSeed` (16106) for backwards reading. |
| 16160-16175 | -- | -- | Reserved for future per-stim-type params. |
| 16105 (deprecated) | `noiseColorMode` | -- | Pre-merge field. **Not strobed in new sessions.** |
| 16113 (deprecated) | `noiseStimMode` | -- | Pre-merge field. **Not strobed in new sessions.** |

## Reconstructing the noise stimulus offline

The pre-rendered noise tensor (and, for chromatic, the DKL drive tensor)
is **not** saved to disk -- they are recomputable from the seed and
parameters. To regenerate:

```matlab
% Achromatic dense:
movie = generateStim_denseAchromatic(nY, nX, nFrames, isBinary, seed);

% Sparse balanced:
movie = generateStim_sparseBalanced(nY, nX, nFrames, nSparseSpots, seed);

% Chromatic (sessionFormatVersion >= 2): per-trial seeds saved in
% the trial array. Pull the trial's seed and regenerate that trial's
% drive / movie:
trialIdx  = ...;     % 1..nTrials
seedCol   = strcmp(p.init.trialArrayColumnNames, 'chromaticSeed');
trialSeed = p.init.trialsArray(trialIdx, seedCol);
nFramesTr = (frame range for the trial; see trialStartFrame /
             trialEndFrame in saved p.trData);
[movieTr, driveTr] = generateStim_denseChromatic( ...
    p.init.noiseGridSize(1), p.init.noiseGridSize(2), nFramesTr, ...
    p.trVars.dklAxes, p.trVars.dklContrasts, double(trialSeed));
% movieTr values 0..7 are state indices, NOT RGB. To recover the
% displayed RGB triple for a check, use the saved chromaticPaletteRGB:
%   rgbForCheck = p.init.chromaticPaletteRGB(:, movieTr(y,x,f) + 1);

% Chromatic (sessionFormatVersion = 1): one-shot whole-session call
% with the master seed:
%   [movie, drive] = generateStim_denseChromatic( ...
%       nY, nX, nFrames, dklAxes, dklContrasts, p.init.noiseRngSeed);
```

Required parameters all live in `p.init` (`noiseGridSize`, `nNoiseFrames`,
`noiseRngSeed`, plus stim-type-specific fields like `dklAxes`,
`dklContrasts`, `nSparseSpots`).
