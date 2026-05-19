# rfMap simulation-mode validation harness — implementation plan

Status: planned, not implemented. Hand this file to a fresh Claude
instance when ready to implement.

## Goal

Replace live Ripple spikes with synthetic per-channel LNP
(Linear-Nonlinear-Poisson) spikes so the online RF estimator
(`computeRFCenters`), per-channel browser (`updateSTAChannelBrowser`),
and CSV export action (`pdsActions.exportRFCentersCSV`) can be exercised
trial-by-trial without an animal subject. Production behavior must stay
bit-identical when the simulation flag is off.

## Existing building blocks

- `tasks/rfMap/supportFunctions/buildGroundTruthRF.m` — DoG spatial ×
  biphasic temporal stRF generator (rfCenterDeg, sigmas, latencies).
- `tasks/rfMap/supportFunctions/testSTA.m` — offline LNP reference;
  the new helper should mirror its math.
- `+pds/getRippleData.m` — defines the field layout the simulator must
  reproduce: `p.trData.spikeTimes` (seconds, "Ripple clock"),
  `p.trData.spikeClusters` (1..nChannels), `p.trData.eventTimes`,
  `p.trData.eventValues`. `accumulateSTA` (in `rfMap_finish.m`) locates
  trial onset via `find(p.trData.eventValues == p.init.codes.stimOn,
  1, 'last')` — the simulator must write at least one `stimOn` event.

## File layout

All new code under `tasks/rfMap/supportFunctions/`. Nothing under
`+pds/` changes (the injection is rfMap-level).

New files:

- `simulateRippleData.m` — entry point. Signature mirrors
  `pds.getRippleData(p)`: takes and returns `p`. Dispatches on
  `p.init.stimType`.
- `simInitKernelBank.m` — builds per-channel ground-truth kernel bank
  on `p.init.simKernelBank` during `rfMap_init`. Called once per
  session.
- `simLNPSpikes.m` — pure-math helper. Given a per-frame drive vector
  `g(t)`, baseline rate, peak rate, frame duration, and an RNG stream,
  returns a column of spike times in seconds.

Edits:

- `rfMap_commonSettings.m` — add `p.trVarsInit.useSimulatedSpikes = false`.
- `rfMap_init.m` — call `simInitKernelBank(p)` (own step 15) when flag is on.
- `rfMap_finish.m` — at the "(0) Retrieve spike data from Ripple"
  block, branch on `p.trVars.useSimulatedSpikes`. Also relax the
  accumulate guard from `useRippleSTA && ripple.status` to
  `(useRippleSTA && ripple.status) || useSimulatedSpikes`.

## Per-channel kernel bank

Lives on `p.init.simKernelBank`:

```matlab
p.init.simKernelBank = struct( ...
    'nChannels',     nCh, ...
    'kernels',       {cell(nCh,1)}, ...
    'channelParams', struct(...));
```

Default: 8 distinct templates × 4 channels each = 32 channels.
Templates scattered across visual field on a small ring/grid:

```matlab
templateCenters = [-3 2; 3 2; 0 3; -3 -2; 3 -2; 0 -2; -5 0; 5 0];
```

Per-template jitter: `rfSigmaCenterDeg` 0.6→1.0 dva, `rfExcPeakMs`
25→45 ms, ON/OFF polarity (sign flip on temporal kernel).

Per-stim-type kernel shape:

- **denseAchromatic / sparse**: separable [spatial, temporal] via
  `buildGroundTruthRF`. Grid params from `p.init.noiseGridSize`,
  `p.trVars.checkSizeDeg`, `p.trVars.noiseFrameHold *
  p.rig.frameDuration * 1000`, `p.trVarsInit.nSTALags`.

  **Critical coordinate-frame subtlety**: `buildGroundTruthRF` puts the
  origin at the top-left of the grid; the rfMap grid is centered on
  screen at `middleXY`. Each template's `rfCenterDeg` is specified
  *relative to fixation* and must be converted to grid coordinates by
  mirroring the Y-flip in `computeRFCenters`:

  ```matlab
  rfCenter_gridFrame = [ rfCenter_fixFrame(1) + nX*checkSizeDeg/2, ...
                        -rfCenter_fixFrame(2) + nY*checkSizeDeg/2 ];
  ```

  Get this wrong and recovered centers will be flipped/offset.

- **denseChromatic**: same spatial kernel, plus per-channel DKL-axis
  weighting `wDKL = [wLM, wS, wA]`. Per-frame projection:

  ```matlab
  proj(t) = sum_{y,x,c} spatialKernel(y,x) * wDKL(c) * thisTrialDklDrive(y,x,c,t)
  ```

- **checkerboard**: NO spatial kernel (stimulus is full-screen). Just a
  temporal kernel + per-(checkSize, contrast) gain table:

  ```matlab
  drive(t) = polaritySequence(t) * gain(checkSizeIdx, contrastIdx)
  ```

  Proposed gain: `gain = (1 - 0.5*sizeIdx_norm) * contrast`.

## Convolution-to-rate math

Mirror `testSTA.m`.

1. **Spatial projection** (achromatic/sparse): `proj(t) = sum
   spatialKernel(y,x) * (S(y,x,t) - 0.5)` per frame in the trial
   window. Chromatic drive is already zero-mean — skip the −0.5.
2. **Temporal filter**: `g = filter(temporalKernel, 1, proj)` (causal).
3. **Variance normalization**: divide `g` by an **analytic** std
   pre-computed in `simInitKernelBank`, NOT per-trial:

   ```matlab
   gStd = sqrt(sum(spatialKernel(:).^2) * sum(temporalKernel.^2) * stimVar);
   ```

   `stimVar = 0.25` for ±0.5 binary noise. Per-trial std (~18 frames)
   is too noisy and causes first-trial sigmoid saturation.
4. **Sigmoid nonlinearity** (matches `testSTA.m:152`):

   ```matlab
   rate = baseRate + peakRate ./ (1 + exp(-g));
   ```

   Defaults: `baseRate = 5 spk/s`, `peakRate = 50 spk/s`, both jittered
   ±20% per channel. No clipping needed (sigmoid bounds output).

## Poisson spike generation

1 ms binning (matches `testSTA.m`):

```matlab
dtFine        = 0.001;
nBinsPerFrame = round(frameDurS / dtFine);
ratePerBin    = repelem(rate(:), nBinsPerFrame);
spikeMask     = rand(numel(ratePerBin), 1) < ratePerBin * dtFine;
spkRel        = (find(spikeMask) - 0.5) * dtFine;   % seconds since stimOn
```

Per-channel/per-trial seeded RNG for reproducibility:

```matlab
RandStream('mt19937ar', 'Seed', baseSeed + ch + 10000*iTrial)
```

`baseSeed` lives at `p.init.simKernelBank.baseSeed` (default 42).

Target mean rate ≈ 30 spk/s × 1.5 s × 32 ch = ~1440 spikes/trial.
After ~20 trials, ~900 spikes/channel → clean RFs in browser.

## Fabricating eventTimes / eventValues / spikeTimes / spikeClusters

Anchor `stimOnTimeSim = p.trData.timing.stimOn` (PTB time, used as
"sim Ripple clock"). `accumulateSTA` only subtracts this from
`spikeTimes`, so any consistent monotonic clock works.

```matlab
p.trData.eventValues = p.init.codes.stimOn;     % scalar column
p.trData.eventTimes  = stimOnTimeSim;           % scalar column
```

Then loop channels:

```matlab
spkAbs = stimOnTimeSim + spkRel;
p.trData.spikeTimes    = [p.trData.spikeTimes;    spkAbs(:)];
p.trData.spikeClusters = [p.trData.spikeClusters; repmat(ch, numel(spkAbs), 1)];
```

This is byte-compatible with `getRippleData`'s non-online-sort branch
(line 26–29). `accumulateSTA` then does `chanMask = spikeClusters == ch`
and gets per-channel spike vectors.

All spikes fall within `[stimOnTimeSim, stimOnTimeSim +
nFramesThisTrial*frameDurS]`, so `accumulateSTA`'s `trialEndTime`
filter accepts them. Same arithmetic works for checkerboard
(`frameDurS = displayFrameDurS`).

**Aborted trials**: still call `simulateRippleData` (cheap). The
existing `~isempty(spikeTimes)` guard in finish decides whether STA
accumulates. Matches real Ripple behavior.

## Open questions (deferred from planning)

1. Bank size: 8 templates × 4 channels, or 32 unique?
2. Chromatic DKL mix: half achromatic + L-M / few-S, or all-achromatic
   for a simpler eye-test?
3. Checkerboard: temporal-kernel + per-condition gain only (no spatial
   gating) — acceptable?
4. Sparse stim encoding: defer to whatever `updateSTA_sparse.m`
   actually uses, or specify?
5. RNG: per-trial reproducible seeds, or `rng('shuffle')` each session?
6. Init wiring: `simInitKernelBank` as its own step (15) at end of
   `rfMap_init.m` — OK?

## Files the planning agent read

- `CLAUDE.md`
- `tasks/rfMap/rfMap_{finish,init,commonSettings,denseAchromatic_settings,checkerboard_settings}.m`
- `+pds/getRippleData.m`
- `tasks/rfMap/supportFunctions/{buildGroundTruthRF,testSTA,computeRFCenters,updateSTA,updateSTA_denseAchromatic,updateSTA_denseChromatic,updateSTA_checkerboard,updateSTAChannelBrowser,nextParams,generateStim_denseChromatic}.m`
- `+pdsActions/exportRFCentersCSV.m`
