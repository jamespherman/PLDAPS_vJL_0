# RF-Center Estimation Pipeline — Plan Document

**Created:** 2026-06-02
**Context:** Optimizing the workflow: probe placement in LGN → RF-center estimation → microstimulation (sacc_to_phosph)

---

## Current State & Key Findings (2026-06-02)

### Simulation validation (120-trial denseAchromatic sim)
- STA recovery works: median RF center error = 0.03 checks, all 8 templates recovered
- Temporal kernels recovered with correct biphasic shape
- **But the simulation is 13-32x too hot** (see below)

### Real data baseline (2026-06-01, 64ch probe in right LGN)

| Session | Task | Good trials | Spk/ch/trial | Total spikes |
|---------|------|-------------|-------------|-------------|
| t1210 | checkerboard | 243 | 16.2 | 252,667 |
| t1235 | barsweep_cardinal4 | 199 | 10.3 | 131,806 |
| t1258 | denseChromatic | 129 | 9.1 | 74,795 |
| t1306 | denseAchromatic | 112 | 8.7 | 62,578 |

**Simulation comparison:**
- Sim: ~119 spk/ch/trial (peakRate=150, baseRate=5) → ~80 spk/s
- Real: ~5-10 spk/ch/trial → ~3-7 spk/s
- Sim overestimates by 13-32x

**Per-trial detail** (denseAchromatic #2, trial 10): 170 spikes across 46/64 active channels. Most channels 1-5 spikes. A few "hot" channels (ch54: 22, ch55: 11) likely near neurons.

**First-trial Ripple buffer bloat:** Every session shows 7-35x spike inflation on trial 1 (leftover buffer data from before session start). Must be fixed — see Priority 1 below.

### Why structure doesn't emerge in online displays
1. **Frame-count bottleneck:** 22×34=748 pixel grid, 18 frames/trial × 112 trials = 2016 frames. STA noise ≈ sqrt(0.25/N_spikes) per pixel. With ~600 spk/ch, signal is at the noise floor.
2. **Multi-unit contamination:** Threshold crossings mix multiple neurons per channel, washing out the STA.
3. **Noise channels:** ~46/64 channels have crossings but most are noise — no RF, just diluting the display.
4. **Full-field stimulus waste:** Recording right LGN (left visual field RFs), but noise covers the entire screen. Half the grid pixels can never carry signal but raise the max-of-noise detection threshold.

---

## Implementation Plan

### Priority 1: Temporal window filter on spike data ~~(was: Flush Ripple buffer)~~ — DONE

**Problem:** `pds.getRippleData` reads the entire Ripple spike buffer on first call, which may contain tens of thousands of spikes from before the session. Inter-trial crossings also accumulate during ITIs.

**Resolution:** Rather than flushing the buffer once at init (fragile: what if init runs minutes before trial 1?), we filter `p.trData.spikeTimes/spikeClusters` to the stimulus presentation window on every trial, immediately after retrieval. This is more principled — it handles pre-session bloat, inter-trial crossings, and any future edge cases in one shot.

**Verified:** All STA accumulators (denseAchromatic, denseChromatic, sparse, checkerboard) and the barsweep RF accumulator already had precise internal temporal filters. The upstream filter added here keeps saved data clean and avoids wasted iteration over out-of-window spikes.

**Files modified (2026-06-02):**
- `rfMap_finish.m` §(0b) — trims to `[stimOnRipple, stimOnRipple + trialDuration)` after Ripple data retrieval, before STA accumulation and save
- `barsweep_finish.m` §(1a) — trims to `[stimOnRipple, stimOnRipple + sweepDuration + 1s)` after Ripple data retrieval, before RF accumulation and save
- Gracefully no-ops when stimOn event is absent (aborted trials) or in sim mode (spikes already in-window)

### Priority 2: Calibrate simulation to real spike statistics — DONE

**Goal:** Make the LNP simulation produce ~5-10 spk/ch/trial (matching real threshold crossings).

**Changes to `simInitKernelBank.m` (2026-06-03):**
- `baseRate`: 5 → **2** spk/s (real channels show ~2-3 spk/s baseline)
- `peakRate`: 150 → **20** spk/s (both spatial and checkerboard modes)
- Added **32 noise channels** (ch33-64): Poisson spikes at 2-4 spk/s with no spatial kernel, matching the observation that ~46/64 real channels show threshold crossings but most have no RF
- `simulateRippleData.m` updated to loop over all channels (RF + noise) and handle noise channels via `isNoise` flag

**Calibration result:** RF channels median 11.7 Hz (~17.5 spk/trial), noise channels median 3.0 Hz (~4.6 spk/trial). RF rate is ~2× real median but within the range of active real channels. Key improvement: 7.5× reduction from old 150 peak rate.

### Priority 1b: Per-lag spike counts and energy metric fix — DONE

**Problem (discovered during Priority 1 testing):** denseChromatic uses per-trial tensors starting at frame 1, creating a boundary effect: spikes on early frames can't reach back to large lags. The shared spike count denominator diluted the mean STA at large lags.

**Fix (2026-06-02):** Changed `staSpikeCount` from `[nCh x 1]` to `[nCh x nLags]` with per-lag counting in all three updateSTA functions. rfMap_init allocates the 2D shape.

**Energy metric follow-up (2026-06-03):** Per-lag normalization fixed the mean STA but introduced a secondary issue: `sum(mean_sta^2)` has noise floor proportional to 1/N_k. Added `energy = energy .* counts` in `updateSTAChannelBrowser.m`, `computeRFCenters.m`, and `evaluateSimSession.m`. Verified: 0/32 correct peak lag (uncorrected) → 26/32 correct (corrected, 97-trial sim).

### Priority 3: Contralateral hemifield stimulus restriction — DONE

**Rationale:** Right LGN → left visual field RFs. Currently the 22×34 noise grid spans the full screen. Half the grid (right hemifield) can never drive recorded neurons but adds noise pixels that raise the detection threshold (max-of-noise across all pixels).

**Approach options:**
1. **Restrict grid to left hemifield (simplest):** Keep check size at 2 dva, halve nX. Grid becomes 22×17 = 374 pixels. Signal per RF pixel unchanged, but max-of-noise threshold drops because there are half as many noise pixels. Detection improves by ~sqrt(2).
2. **Restrict + refine:** Use the saved grid area to decrease check size (e.g., 1 dva checks on a 22×17 dva region → 22×17 pixels at 1 dva, or 44×34 at 1 dva covering the left half). Finer checks better resolve RF shape, but at 1 dva with LGN sigma ~0.3 dva, the kernel spans only 1 pixel — similar to current situation.
3. **Dynamic restriction:** After N initial trials, identify the rough RF band (elevation range) from the strongest channels, then restrict vertically too. This is more complex but maximizes frame efficiency.

**Implementation (2026-06-03, Option 1):** Added `stimHemifield` parameter ('full'/'left'/'right'). Default is 'full' (backward compatible). For right LGN recordings, set to 'left'.

**Files modified:**
- `rfMap_commonSettings.m` — added `p.trVarsInit.stimHemifield = 'full'`
- `rfMap_init.m` / `generateStimForTask` — computes grid width from hemifield setting; stores `p.init.noiseGridCenterPix` and `p.init.stimHemifieldInt` (0/1/2 for strobe)
- `nextParams.m` — uses `noiseGridCenterPix` for texture dest rect (fallback to middleXY for pre-hemifield sessions)
- `computeRFCenters.m` — uses `noiseGridCenterPix` for grid-to-dva mapping (fallback to middleXY)
- `simInitKernelBank.m` — grid-frame template conversion accounts for hemifield offset via `gridCenterDeg`
- `+pds/initCodes.m` — added `rfMapStimHemifield = 16161` (0=full, 1=left, 2=right)
- Strobe list in commonSettings — strobes `p.init.stimHemifieldInt`

**Usage:** Set `p.trVarsInit.stimHemifield = 'left'` in the per-stim-type settings file or in the sim wrapper. Halves nChecksX, reducing noise pixel count and improving detection threshold by ~sqrt(2).

### Priority 4: Threshold monitoring during sessions — DONE

**Problem:** Ripple threshold values are set once during init. Electrode impedance and noise floor can drift during a session (hours), causing thresholds to become too high (missing spikes) or too low (more noise crossings).

**Implementation (2026-06-03):** Two-tier system:

**Tier 1 — Passive rate monitoring** (`+pds/monitorSpikeThresholds.m`):
- Called every successful trial in `rfMap_finish.m` §(4d)
- Tracks per-channel crossing rate in a sliding window (default 20 trials)
- After a baseline period (first 20 good trials), flags channels whose rate drops below 40% of baseline (threshold too high / electrode drift) or rises above 3× baseline (threshold too low / noise increase)
- Stores results on `p.status.threshMon` for online display
- Zero overhead: just counts spikes already retrieved by getRippleData
- Configurable: `threshMonBaselineTrials`, `threshMonWindowTrials`, `threshMonDriftLowFrac`, `threshMonDriftHighFrac`

**Tier 2 — Active RMS recheck** (`+pds/recheckSpikeThresholds.m`):
- On-demand via `pdsActions.recheckThresholds` (GUI action menu)
- Briefly sets -3 uV test threshold for 0.3s to acquire noise waveforms
- Estimates current noise sigma from pre-trigger baseline samples (same method as `setSpikeThreshFromRMS`)
- Compares to init-time sigma stored in `p.rig.ripple.spikeThresh`
- Flags channels where sigma drifted >50%
- Optional auto-adjust: set `p.trVarsInit.threshAutoAdjust = true` to automatically update drifted thresholds to -mult × currentSigma
- Call during ITI only (generates noise crossings in Ripple stream during test window)

### Priority 5: Shared LGN population simulation architecture — DONE

**Goal:** Define a simulated LGN population (neuron specs saved to disk), then run multiple tasks in sim mode against the same population. This enables optimizing task order and trial counts.

**Implementation (2026-06-03):**

**Population spec file format** (`.mat`):
```
population.neurons(k):
  .centerDeg       [x, y] in fixation-relative dva
  .sigmaCenterDeg  center Gaussian sigma (dva)
  .sigmaSurrDeg    surround sigma (dva)
  .surrWeight      surround suppression strength
  .excPeakMs       excitatory temporal peak (ms)
  .inhPeakMs       inhibitory temporal peak (ms)
  .inhWeight       inhibitory temporal weight
  .polarity        ON (+1) or OFF (-1)
  .peakRate        spk/s at max drive
  .baseRate        spontaneous rate
  .dklWeights      [L-M, S, Achro] for chromatic sensitivity
  .channelIdx      which probe channel this neuron appears on
population.noiseChannels  - indices of channels with no RF
population.noiseRates     - spontaneous rates for noise channels
population.params         - generation parameters for provenance
```

**Files created:**
- `simGeneratePopulation.m` — Creates a parameterized LGN population and saves to disk. Configurable: nNeurons, nChannels, hemifield, eccentricity/elevation range, seed, base/peakRate. Spatial sigma scales with eccentricity. DKL weights cycle through L-M, achromatic, mixed, and S types.
- `simLoadPopulation.m` — Drop-in replacement for `simInitKernelBank` when a population file is available. Loads the spec and builds the task-specific kernel bank (`p.init.simKernelBank`) that `simulateRippleData` expects. Handles denseAchromatic, denseChromatic, sparse, and checkerboard stim types. Accounts for hemifield grid offset.
- `rfMap_init.m` §(15) — Modified to check `p.trVarsInit.simPopulationFile`; if set, calls `simLoadPopulation` instead of `simInitKernelBank`.

**Usage:** In a sim settings file, set:
```matlab
p.trVarsInit.simPopulationFile = '/path/to/lgn_population_042.mat';
```

**Workflow:**
1. Generate population → save to `simPopulations/lgn_population_001.mat`
2. Run checkerboard (50 trials) → get spatial-frequency/contrast preferences
3. Run rfMap_denseAchromatic (100 trials) → get RF center estimates
4. Run barsweep_cardinal4 (50 trials) → cross-validate RF centers
5. Score per-channel RF quality → go/no-go for microstimulation
6. Vary trial counts and task order → find optimal sequence

**Validated (headless):** 8-neuron population, 300-trial denseAchromatic sim on 15x13 left-hemifield grid. Median RF center error: 0.29 checks. All 8 RF channels recovered, 0 noise channels false-positive.

### Priority 6: Per-channel go/no-go criteria for microstimulation — DONE

**Goal:** After the RF estimation sequence, each channel gets a quality score determining whether it has a well-defined RF suitable for microstimulation.

**Implementation (2026-06-03):** `computeChannelQuality.m`

**Criteria (per channel):**
- **spikeCount** — Total spikes at peak lag. Minimum: 200 (configurable via `rfQualMinSpikes`)
- **peakSNR** — Energy at peak lag / median energy across lags. Minimum: 1.15 (`rfQualMinPeakSNR`). Mild filter; at calibrated rates this metric has limited discrimination.
- **spatialSNR** — Peak pixel magnitude / RMS of STA slice at peak lag. Minimum: 5 (`rfQualMinSpatialSNR`). Primary discriminator: RF channels show 5-8, noise channels 2.5-3.8.
- **rfSpreadDeg** — Weighted spatial standard deviation of thresholded STA. Maximum: 4 dva (`rfQualMaxSpreadDeg`). RF channels show 0-1.5 dva, noise ~10-12 dva.
- **rfCenterDeg** — Center estimate from `computeRFCenters`. Must not be NaN.

**Output struct per channel:** spikeCount, peakLag, peakSNR, spatialSNR, rfCenterDeg, rfSpreadDeg, passGo (bool), failReasons (cell of strings).

**Validated:** 300-trial population sim, 8/8 RF channels pass, 0/56 noise channels pass. Zero false positives, zero false negatives. Thresholds calibrated against realistic spike rates (base=2, peak=20 spk/s).

**Integration with sacc_to_phosph:** The quality struct provides channel-level RF centers and pass flags. sacc_to_phosph can filter `quality(ch).passGo` to select channels, and use `quality(ch).rfCenterDeg` for predicted phosphene locations.

**Future extensions:**
- Cross-task consistency: if both denseAchromatic and barsweep have been run, compare RF centers; require agreement within 1 check width.
- Bootstrap confidence interval: resample STA accumulators to estimate center uncertainty.
- Online display integration: color-code channels in the browser by quality status.

---

## Suggested Execution Order

1. ~~**Temporal window filter** (Priority 1)~~ — DONE (2026-06-02)
2. ~~**Per-lag spike counts + energy fix** (Priority 1b)~~ — DONE (2026-06-02/03)
3. ~~**Calibrate simulation** (Priority 2)~~ — DONE (2026-06-03)
4. ~~**Hemifield restriction** (Priority 3)~~ — DONE (2026-06-03)
5. ~~**Run calibrated sim**~~ — DONE (2026-06-03). ~150 trials for convergence at calibrated rates (denseAchromatic, 22x34 full grid). With left-hemifield 15x13 grid: 300 trials, median 0.29 checks.
6. ~~**Shared population architecture** (Priority 5)~~ — DONE (2026-06-03). simGeneratePopulation + simLoadPopulation.
7. ~~**Go/no-go criteria** (Priority 6)~~ — DONE (2026-06-03). computeChannelQuality with calibrated thresholds.
8. ~~**Checkerboard pre-screening validation**~~ — DONE (2026-06-03). 48 trials (1.6 min) identifies 12/12 RF channels with 0 false positives. F1 threshold = 1.5× noise floor. See `test_checkerboard_prescreening.m` and `figs_checkerboard_first/prescreening_comparison.png`.
9. ~~**Multi-task optimization**~~ — DONE (2026-06-03). Tested 5 populations x 400 trials + check size comparison (1.5 vs 2.0 dva, 3 populations x 600 trials). See `test_multitask_optimization.m`, `test_optimization_extended.m`, and `figs_optimization/`.
10. ~~**Threshold monitoring** (Priority 4)~~ — DONE (2026-06-03). Passive rate monitor in rfMap_finish + on-demand active RMS recheck via pdsActions.

---

## Recommended Session Workflow (from optimization results)

### Optimal parameters
- **Check size:** 2.0 dva (15x13 grid, left hemifield). Converges ~100-150 trials faster than 1.5 dva (19x17 grid). Both reach sub-check center accuracy at convergence.
- **Hemifield:** Match to recording side (right LGN → left hemifield, left LGN → right hemifield).

### Session sequence

| Phase | Task | Trials | Time (min) | Purpose |
|-------|------|--------|-----------|---------|
| 1 | Checkerboard (3 sizes × 2 contrasts × 8 reps) | 48 | 1.6 | Pre-screen responsive channels |
| 2 | denseAchromatic (2.0 dva, hemifield) | 400-500 | 10-12.5 | RF center estimation |
| **Total** | | **448-548** | **~12-14** | |

### Expected outcomes by trial count (2.0 dva, sim-calibrated)
| Trials | Pass rate | Median center error | Notes |
|--------|-----------|-------------------|-------|
| 200 | ~17% | 3.1 checks | Too early |
| 300 | ~31% | 0.9 checks | Transition zone — some channels emerging |
| 400 | ~56% | 0.5 checks | Useful — majority of best channels pass |
| 500 | **~86%** | **0.4 checks** | **Recommended target** — most RF channels recovered |
| 600 | ~94% | 0.4 checks | Diminishing returns |

### Caveats
- These pass rates are conservative: the sim uses threshold-crossing (multi-unit) rates of 2-20 spk/s. Real "hot" channels with single-unit activity can have higher SNR, so real pass rates may exceed sim predictions.
- P cells converge fastest (~70% at 400), M cells intermediate (~43%), K cells slowest (~23%). K cells have slow temporal dynamics and weak achromatic drive, making them inherently harder to recover with denseAchromatic alone.
- Center accuracy in dva: 0.4 checks × 2.0 dva/check = 0.8 dva. For LGN RFs at 2-5 dva eccentricity (RF diameter ~0.5-1.0 dva), this is within 1 RF diameter — sufficient for microstimulation targeting.

---

## Open Questions

- What is the xippmex API call for flushing the spike buffer? Is it a simple read-and-discard, or is there an explicit flush command?
- How many neurons per channel is realistic for the multi-contact probe geometry? (2-3? more?)
- Should the population spec include inter-neuron correlations, or is independent Poisson sufficient?
- For the hemifield restriction: should we also restrict vertically (e.g., ±5 dva) based on expected LGN RF eccentricities for the probe depth?
- What's the target total session time for the RF estimation sequence? (This constrains the trial budget.)
