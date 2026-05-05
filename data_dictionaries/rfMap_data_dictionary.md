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
  per-condition temporal kernel and F1/F2 amplitudes (cell screening /
  magno-parvo typing). Use a different mode (dense or sparse) if
  spatial mapping is the goal.
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
| `sessionFormatVersion` | int | Schema version. **Bump on incompatible changes.** Phase 1 = 1. |
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
| `noiseMovie` | array | Pre-rendered movie. **Stripped before save** (recomputable from seed). All stim types use single-channel indexed `[nY,nX,nFrames]` arrays so the framebuffer-as-CLUT-index path of VPixx L48 mode displays them correctly: uint8 0/1 (denseAchromatic, mapped at draw time to `{expBlack, expWhite}` slots); int8 in {-1,0,+1} (sparse, mapped to `{expBlack, expBg, expWhite}`); uint8 0..7 (denseChromatic, **state index** -- bit 0 = L-M sign, bit 1 = S sign, bit 2 = Achro sign -- mapped to CLUT slots `chromaticClutBase + state` at draw time). |
| `dklDriveTensor` | `[nY,nX,3,nFrames]` single | (denseChromatic only.) Per-check signed DKL contrasts. **Stripped before save**; recomputable via `recomputeDklDrive(seed, ...)`. |
| `chromaticClutBase` | int | (denseChromatic only.) First CLUT row index (0-based) where the 8 tri-noise palette entries are installed. Texture value `k` (0..7) lives at slot `chromaticClutBase + k`. Set during `_init.m`; saved to disk. |
| `chromaticPaletteRGB` | `[3,8]` uint8 | (denseChromatic only.) The 8 gamma-corrected RGB triples (column k = state k-1). Built from `dkl2rgb(...)` via `buildChromaticPalette`. Saved so offline analysis can reconstruct the displayed colors without re-loading the rig calibration. |
| `chromaticStateBits` | `[3,8]` int8 | (denseChromatic only.) +/-1 sign matrix mapping state index to (L-M, S, Achro) signs. Saved for offline reconstruction. |
| `dklDriveVariancePerAxis` | `[1,3]` double | (denseChromatic only.) `c_axis^2` per axis in order `[LM, S, Achro]`; inactive axes are 0. With non-uniform per-axis contrasts the recovered STA amplitude scales by `c_axis`, so cross-axis tuning comparisons must divide `|sta(:,:,axis,k)|` by `sqrt(dklDriveVariancePerAxis(axis))` before treating the per-axis amplitudes as comparable. With uniform contrast (the default) all entries are equal and the renormalization is a no-op. |
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
| `jitterMode`, `jitterRangeDva`, `apertureMode`, `apertureCenterDva`, `apertureSizeDva` | -- | Phase-4 placeholders (off by default). |

Stim-type-specific:

| Field | Used by | Description |
|---|---|---|
| `dklAxes` | denseChromatic | Active DKL axes (subset of `[1 2 3]` for L-M / S / Achro). Default `[1 2 3]` (tri-noise). |
| `dklContrasts` | denseChromatic | Per-axis contrast magnitude. Scalar (broadcast) or vector. Default 0.45 = 0.95 × `gamutMaxContrasts([1 2 3], [1 1 1])` on rig1/rig2 (max safe uniform contrast 0.4738; 5% margin against fp / quantization). To pick a principled value for a different rig, call `gamutMaxContrasts(dklAxes, axisRatios)` from the rig command line after `initmon(LUT_VPIXX_rigN)`. `initClut` errors with the rig's max safe value if the configured contrast clips any corner. |
| `nSparseSpots` | sparse | Number of nonzero spots per frame. |
| `sparseBalancedFlag` | sparse | 1 = legacy uniform-random, 2 = balanced TwinDeck (default). |

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
| 16146-16150 | `rfMapCheck*` | 3 | Checkerboard params (TBD Phase 3). |
| 16151-16157 | `rfMapJitter*`, `rfMapAperture*` | 4 | Jitter / aperture (TBD Phase 4). |
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

% Chromatic (drive tensor -- no rig calibration needed):
drive = recomputeDklDrive(nY, nX, nFrames, dklAxes, dklContrasts, seed);

% Chromatic (state-index movie + drive tensor):
[movie, drive] = generateStim_denseChromatic(nY, nX, nFrames, ...
    dklAxes, dklContrasts, seed);
% movie values 0..7 are state indices, NOT RGB. To recover the
% displayed RGB triple for a check, use the saved chromaticPaletteRGB:
%   rgbForCheck = p.init.chromaticPaletteRGB(:, movie(y,x,f) + 1);
```

Required parameters all live in `p.init` (`noiseGridSize`, `nNoiseFrames`,
`noiseRngSeed`, plus stim-type-specific fields like `dklAxes`,
`dklContrasts`, `nSparseSpots`).
