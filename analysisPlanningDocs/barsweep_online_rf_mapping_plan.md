# Barsweep Online Receptive-Field Mapping Plan

## Purpose

Add an online receptive-field (RF) mapping feature to the `barsweep` task so the experimenter can see a per-channel RF estimate update during a session and use it to place stimuli for downstream tasks (e.g. `gSac_jph`, `conflict_task`). The recording targets are **macaque LGN and superficial SC**.

The existing `rfMap` task uses spike-triggered averaging (STA) of dense binary noise. That is the right algorithm for high-dimensional white stimuli but is the wrong fit for `barsweep`, where the stimulus is a single deterministic moving bar.

The task must support **two regimes** that share the same quintet but operate as distinct experiments:

- **`cardinal4`** — the collaborator's canonical configuration: 4 directions `[0 90 180 270]` = 2 unique orientations after opposite-direction pooling. Online reconstruction produces **two orthogonal 1D rate profiles** (one along x, one along y), an `(x_center, y_center)` estimate from each profile's peak, and a separable 2D estimate via outer product. Sufficient to localize an RF for stimulus placement; assumes RF separability (reasonable for LGN concentric RFs, fine for most SC visual neurons, breaks for oriented V1 cells).
- **`rfmap12`** — 12 directions `[0 30 60 90 120 150 180 210 240 270 300 330]` = 6 unique orientations. Online reconstruction produces a true 2D RF image via filtered back-projection (FBP), `iradon` doing the ramp-filtered inverse Radon transform (Johnston et al. 2014, J Neurophysiol; Hu et al. 2012, Neural Computation; Fiorani et al. 2014, J Neurosci Methods). No separability assumption.

Both regimes share a single accumulator data structure and a single per-spike binning routine. They differ only in the reconstruction step at display time, which branches on `p.init.exptType`. The architecture mirrors the multi-regime pattern used by `joystick_release_for_stim_change_and_dim` (one shared quintet, multiple settings files each setting a unique `p.init.exptType`, downstream code branches on that string).

The plan is intentionally scoped to **online** RF estimation. Offline reconstruction can do better (per-channel latency fitting, NNMF, iterative tomography) but those are out of scope; the saved per-trial data plus the persisted accumulators give an offline analysis everything it needs to redo the math from scratch.

### Note on the legacy collaborator code

The four legacy files under `~/Downloads/feng_LGN/` strobe trial events for offline analysis but do no online RF mapping; the online feature is therefore additive, not a replacement.

### Why this lives in `barsweep` and not in `rfMap`

`rfMap` recently gained a sparse-noise mode (commit `d25c4901`) that produces faster STAs for surround-dominated LGN/SC RFs. It would be reasonable to ask why we don't just run rfMap-sparse before/between barsweep sessions instead of building a separate online RF estimator inside barsweep. Two reasons make the barsweep-internal estimator the right call:

1. **Same-session double duty.** `barsweep` is the collaborator's standing direction-tuning workflow. Every session already produces sweeps suitable for RF estimation; running rfMap-sparse separately doubles the recording time for no scientific gain. An online estimator inside barsweep means each barsweep session simultaneously yields direction tuning *and* an RF map.
2. **Online sweep-placement feedback.** A failure mode of bar-sweep recording is placing the sweep off the cell's RF; the experimenter realizes this only after offline analysis, by which point the cell may be lost. An online RF estimate computed *during* the barsweep session lets the experimenter nudge `pathCenterDeg` and re-run, recovering data in real time. Switching to rfMap-sparse, then back to barsweep, breaks the recording rhythm and risks losing the unit.

The cardinal4 regime in particular only exists because the collaborator is committed to the 4-direction protocol; the online RF estimator gives them an estimate from the data they were already going to collect.

## Why position-binning, and how the two reconstructions diverge

Each sweep traverses the visual field along a known direction at known speed. For a linear neuron, the spike-rate-vs-time profile during a sweep is — after correcting for response latency — the **Radon projection** of the 2D spatial RF onto the sweep direction (i.e. the bar's motion axis). The reconstruction problem is then "given Radon projections at K orientations, recover the 2D function."

**Common to both regimes:** the per-spike accumulator is a 2D histogram `spikeHist{ch}(orientationIdx, positionBin)` where `positionBin` is the bar center's signed projection onto the motion axis at the time the spike was emitted (after subtracting response latency). The dwell-time matrix `dwellTime(orientationIdx, positionBin)` accumulates how long the bar spent at each `(orientation, position)` cell. The rate matrix is `spikeHist ./ dwellTime`. This is identical machinery for both regimes.

**`rfmap12` reconstruction:** with 6 unique orientations covering 0–180° in 30° steps, the rate matrix is a Radon sinogram, and `iradon(rateMatrix', orientationsDeg, 'linear', 'Hann', ...)` returns the 2D RF image directly. Convergence is fast (Johnston et al. 2014: ~4 min for usable RGC RFs vs. ~20 min for white-noise STA), and `iradon` runs in well under 50 ms for 32 channels at 80×80 output resolution.

**`cardinal4` reconstruction:** with only 2 unique orientations (vertical bar sweeping along x; horizontal bar sweeping along y), `iradon` is degenerate — two projections cannot reconstruct a generic 2D image. But the two projections are **orthogonal**, which means they directly give marginal 1D RF profiles along x and y. From these:
- `x_center = position with peak rate in vertical-bar profile`
- `y_center = position with peak rate in horizontal-bar profile`
- 1D RF widths along each axis from FWHM (or 1/e drop) of each profile
- Separable 2D estimate: `rfMap2D(x,y) ≈ rate_x(x) * rate_y(y) / max(rate_x * rate_y)` — assumes RF is the outer product of its two marginals (true for circular Gaussians; approximate for elliptical ones; wrong for oriented stripes)

**Why the separability assumption is OK here.** LGN concentric RFs and most superficial SC visual RFs are well-approximated as circular or moderately elliptical Gaussians, both of which are exactly separable along the cardinal axes. The use case is online stimulus placement, not RF imaging research. The separable 2D estimate is rendered with a clear visual indication that it is an outer-product approximation (e.g. dashed crosshair lines and a label `"separable estimate (cardinal4)"` on the panel).

**Why STA-of-dense-noise is the wrong choice for either regime:**
- The stimulus is rank-1 per frame; STA of a rank-1 stimulus is degenerate (can only recover the 1D profile along the bar's long axis, plus orientation tuning).
- Per-spike compute is much higher (one full image update per spike per lag).
- Position-binning is what a person with the four direction PSTHs and paper would do anyway; the algorithm is interpretable to the experimenter.

## Scope and acceptance criteria

In scope:
- Online per-channel RF estimate, refreshed once per rewarded trial, in **both** `cardinal4` and `rfmap12` regimes.
- Per-channel detail panel (selectable channel) with regime-appropriate display (1D x+y profiles + separable 2D for `cardinal4`; full 2D FBP image for `rfmap12`).
- All-channels grid (one tile per channel, contrast-normalized).
- Reuse `rfMap`'s Ripple integration, plot-handle caching, and accumulator-strip-before-save patterns.
- Defaults appropriate for LGN (40 ms latency); GUI-tunable for SC (60 ms) and elsewhere.

Out of scope for this plan (call out as future work):
- Per-channel latency estimation (could be added by minimizing RF elongation in offline scripts).
- NNMF / iterative reconstruction.
- Online spike sorting beyond what Ripple's hardware sorter provides.
- Saving the running RF accumulators to `.mat` at session end (currently rfMap doesn't either; can be added if desired — see §10).

Acceptance criteria:
1. **`rfmap12` convergence.** After ≥ ~30 rewarded trials at 12 directions against a Ripple system with simulated or live spikes, the per-channel detail panel shows a recognizable 2D RF map for any channel with a real RF.
2. **`cardinal4` convergence.** After ≥ ~40 rewarded trials at 4 cardinal directions, the per-channel detail panel shows two well-formed 1D rate profiles with identifiable peaks for any channel with a real RF, and the (x_center, y_center) readout matches the simulated RF center to within one position bin.
3. **Bypass.** With `useOnlineRF = false` in either regime, the online RF code path is fully bypassed — no Ripple calls, no figure created, no accumulators allocated.
4. **Ripple-disabled fallback.** With `useOnlineRF = true` but Ripple unavailable (`p.rig.ripple.status == false`), the task initializes cleanly with a warning, and `_finish.m` skips the spike-fetch and accumulation steps each trial without erroring.
5. **Aborted-trial handling.** `nonStart` trials do **not** contribute to the RF or dwell-time accumulators (no bar visibility). `fixBreak` trials contribute *partially*: spikes and dwell up to `min(stimOff - stimOn, fixBreak - stimOn) - latencyMs/1000` are accumulated, anything after is dropped. A `fixBreak` trial where the break occurs before the latency-corrected first visible-bar position contributes nothing.
6. **Save round-trip.** The per-trial saved `.mat` contains everything needed to reconstruct the RF offline from scratch: spike times in Ripple clock, the `stimOn` event time in Ripple clock, sweep parameters (`pathAngleDeg`, `pathLengthDeg`, `pathCenterDeg`), and `sweepCenterPix` (or its dva equivalent — see §6).
7. **Quintet sharing.** A single set of `_init/_next/_run/_finish.m` files serves both regimes; only the settings file differs and a small number of `exptType`-keyed branches in support functions handle regime-specific behavior.

## 1. Data model

All RF-mapping state lives under `p.init.barsweepRF`. The choice of `p.init` (vs. `p.trData`) mirrors `rfMap`'s `p.init.staAccum` pattern: state must persist across trials and is stripped before each save to keep per-trial `.mat` files small.

```matlab
% Pseudocode (nCh = p.trVarsInit.rfNChannels). Orientations are regime-dependent
% and set inside initBarsweepRF based on p.init.exptType:
%   'barsweep_cardinal4' -> [0 pi/2]                       (2 unique)
%   'barsweep_rfmap12'   -> [0 pi/6 pi/3 pi/2 2*pi/3 5*pi/6] (6 unique)
%
% Two distinct extents in this struct, NOT one:
%   ACCUMULATOR EXTENT — the half-width of positionEdges. Spans the full sweep
%   so every bar position lands in a valid bin. Derived from pathLengthDeg
%   (default 70°), with a barWidthDeg/2 + small margin pad:
%     halfL         = pathLengthDeg/2 + barWidthDeg/2 + accumMarginDeg
%     positionEdges = -halfL : rfPosBinDeg : halfL
%   IMAGE EXTENT — mapExtentDeg, the half-width of the 2D output image. Local
%   to the RF, much smaller than halfL (default 10° for an LGN/SC RF the user
%   will fit inside the sweep).
%
% positionEdges/positionCenters are in PATH-CENTER-RELATIVE dva (i.e. zero
% means "bar at pathCenterDeg"). The user-set sweep center pathCenterDeg is
% added back at display time. This decouples the accumulator from where on
% the screen the user has placed the sweep.
p.init.barsweepRF = struct( ...
    'enabled',        true, ...                 % mirror of p.trVars.useOnlineRF, frozen at init
    'nChannels',      nCh, ...
    'orientationsRad',[], ...                   % populated from exptType  [1 x nOri]
    'directionsRad',  [], ...                   % all directions (e.g. 4 or 12), per-direction counter axis
    'pathLengthDeg',  [], ...                   % captured from p.trVars at init; drives positionEdges
    'accumMarginDeg', 1.0, ...                  % pad beyond pathLengthDeg/2 + barWidthDeg/2 (1° = 4 bins at 0.25)
    'positionEdges',  [], ...                   % dva relative to pathCenterDeg; computed from pathLengthDeg
    'positionCenters',[], ...                   % dva relative to pathCenterDeg; computed from positionEdges
    'pathCenterDeg',  [0; 0], ...               % captured from p.trVars; auto-reset on change
    'mapExtentDeg',   10, ...                   % half-width of 2D output IMAGE (local to RF)
    'mapPixelDeg',    0.25, ...                 % output image resolution
    'latencyMs',      40, ...                   % response latency in ms (single unit throughout)
    'rampFilter',     'Hann', ...               % iradon filter type (smoother default for online use)
    'rampCutoff',     0.5, ...                  % iradon high-frequency cutoff in [0,1]
    'spikeHist',      zeros(0,0,0), ...         % [nOri x nPosBins x nCh] - allocated to actual size in init
    'dwellTime',      [], ...                   % [nOri x nPosBins], shared across channels (seconds)
    'spikeCount',     zeros(nCh,1), ...         % cumulative spikes contributing per channel
    'trialsByDirection', [], ...                % [nDir x 1] count of contributing trials per *direction*
    'resetCount',     0, ...                    % bumped each auto-reset; drives sidecar versioning
    'figData',        [], ...                   % handles for plotting, populated by initBarsweepRFDisplay
    'lastUpdateTrial',0 ...
);
```

### Why a 3D `spikeHist` array, not a cell of 2D matrices

`spikeHist` is a single `[nOri × nPosBins × nCh]` array rather than `cell(nCh, 1)` of `[nOri × nPosBins]` matrices. Same memory, but the per-trial update is a single 2D `accumarray` over `(posBin, channel)` indices that fills the relevant `oriIdx` slice without an inner per-channel loop. Easier to reshape for plotting (the all-channels grid is one `squeeze`/`permute` away). Cell array offers no functional advantage here.

### Per-direction counter

Opposite-direction pooling (§2) collapses `dwellTime` and `spikeHist` to per-orientation rows; per-direction information is lost in the accumulator itself. To support the direction-balance diagnostic (§2 prose), `trialsByDirection` is a `[nDir × 1]` integer counter incremented per rewarded trial. The figure title shows per-orientation balance as `min(forward, reverse) / max(forward, reverse)` derived from this counter — small (~tens of bytes) and recovered cleanly even with auto-reset.

### Mid-session parameter changes

**Spatial knobs** (`pathCenterXDeg`, `pathCenterYDeg`, `pathLengthDeg`, `barWidthDeg`, `rfPosBinDeg`, `rfLatencyMs`) are captured into `p.init.barsweepRF` at `initBarsweepRF` time and the accumulator is built around them. If the experimenter changes any of these mid-session via the GUI — entirely plausible, since the whole point is to nudge the sweep center as RFs become visible — the accumulator would silently mix incoherent data across the change. `pathLengthDeg` and `barWidthDeg` are in this list because the accumulator extent is derived from them (see the data-model comment above); changing either redefines what `positionEdges` should be. **Reconstruction-only knobs** (`rfMapExtentDeg`, `mapPixelDeg`, `rfRampFilter`, `rfRampCutoff`) do *not* trigger an accumulator reset — they only affect the image rendered at display time and are read live in `plotBarsweepRF` per call.

**UX trade-off explicit.** Auto-reset costs the operator their on-screen continuity — the §0 motivation literally describes the user "nudging `pathCenterDeg` and re-running to recover data in real time," but every nudge zeroes the visible accumulator and the operator goes from "I see something forming" back to noise. The versioned sidecar preserves the data offline, which is the right call for the *recording*, but doesn't help the live decision the operator is making at the rig. Two mitigations apply:

1. **Sub-bin nudge quantization (implemented in v1).** A `pathCenterDeg` change smaller than `rfPosBinDeg` along either axis is below the bin grid and doesn't change which bin any historical bar position landed in. The accumulator state remains coherent in the *path-center-relative* coordinate system if we round the new `pathCenterDeg` to the nearest bin grid relative to the snapshot. Treat sub-bin moves as label-only changes: update the displayed axis labels (`pathCenterDeg + axisDeg`) without zeroing. Only super-bin moves trigger the snapshot-and-reset path. This mitigation is cheap (~5 lines in the change-detection block) and matches the operator's mental model — small nudges *should* feel continuous.
2. **Absolute-coordinate accumulator with re-rendered local view (deferred to v2).** Keep a wider accumulator in absolute screen coordinates and reconstruct only the local `mapExtentDeg` window around the current `pathCenterDeg`. Heavier in memory and reconstruction cost; matches the operator mental model more completely. Lift to v1 only if real-rig sessions show the v1 mitigation #1 doesn't cover the actual use cases — most operator nudges are likely to be sub-bin once an RF is becoming visible.

Super-bin moves still trigger the snapshot-and-reset path documented above; the operator gets explicit feedback (banner + bumped `resetCount`) that they have started a new accumulation epoch, which is the correct behavior for a coordinate-system-changing move.

`barsweep_finish.m` therefore detects mid-session changes by comparing the live `p.trVars` values (current trial, populated from `trVarsGuiComm`) against the captured `p.init.barsweepRF` snapshot at the start of each call. **Read from `p.trVars`, not `p.trVarsInit`** — `trVarsInit` is frozen at settings load; mid-session GUI edits flow `trVarsGuiComm → trVars`. On any change:
1. **Save before zeroing.** Write the current accumulator to a versioned sidecar `<sessionId>_barsweepRF_resetN.mat` (with `N = resetCount + 1`) *before* re-running `initBarsweepRF`. This preserves the data the experimenter accumulated under the previous spatial setup; the offline analyst then has the full sequence of attempted sweep centers, which is exactly the diagnostic the user wants when reviewing a session post hoc. Without this, the auto-reset destroys the very data it was designed to surface as suspect.
2. **Re-run `initBarsweepRF`** (zero accumulators, re-compute edges/centers from the new values, increment `resetCount`).
3. **Overlay a one-trial banner** on the figure title (`"RF accumulator reset (N=%d)"`) so the experimenter sees what happened.

The "live" sidecar `<sessionId>_barsweepRF.mat` (overwritten each trial, §10) continues to track the *current* accumulator; the versioned `_resetN.mat` files are immutable snapshots of each prior epoch.

`rfSelectedChannel` is **not** in this list — it changes only the displayed channel, not the accumulated data, so it's read fresh each `plotBarsweepRF` call without triggering a reset. `rfMapExtentDeg`, `mapPixelDeg`, `rfRampFilter`, and `rfRampCutoff` are also not in this list for the same reason: they're reconstruction parameters consumed at display time, never baked into the accumulator.

Why these choices:
- **Path-center-relative position binning.** `pathCenterDeg` (the user's sweep center, e.g. `[15, 0]` for an eccentric SC RF) can be anywhere on screen. Binning the absolute bar-center coordinate would force `positionEdges` to span the whole field; binning the *relative* coordinate `s = projAxis' * (sweepDeg - pathCenterDeg)` keeps the histogram tight around the sweep extent and works at any eccentricity. The reconstructed RF image is then naturally centered at zero, and `pathCenterDeg` is added back to axis labels at display time.
- **`spikeHist` per channel, `dwellTime` shared.** Bar-position dwell time only depends on the stimulus, not the channel; storing it once saves memory and wall-clock per accumulation.
- **Position bins in dva, not pixels.** Keeps the accumulator screen-resolution-independent; conversion to pixels happens only at display time.
- **`positionEdges` precomputed once at init / on auto-reset.** Avoids recomputing histogram edges every spike; matches rfMap's `noiseFrameDurMs` pre-computation pattern.
- **Latency stored in milliseconds, single unit throughout.** GUI exposes `rfLatencyMs`, accumulator stores `latencyMs`, change-detection compares the same unit. The accumulator divides by 1000 once when subtracting from spike times in seconds. A future per-channel vector is a drop-in replacement (`latencyMs(ch)`).
- **`rampCutoff` exposed as a knob.** `iradon`'s default 1.0 keeps the full ramp filter, which is fine offline but produces visibly noisy RFs after only ~30 trials online. 0.5 gives a smoother online estimate; the live value is read from `p.trVars.rfRampCutoff` (which is copied from `trVarsInit` at trial start and reflects mid-session GUI edits via `trVarsGuiComm`). Reading `trVarsInit` directly would freeze the value at settings load.

## 2. Algorithm

For each rewarded trial:

1. **Pull spikes and events** via `pds.getRippleData(p)` (already used in rfMap) → `p.trData.spikeTimes`, `p.trData.spikeClusters`, `p.trData.eventTimes`, `p.trData.eventValues`, all in Ripple-clock seconds. With `useOnlineSort == false`, `getRippleData` populates `spikeClusters` with the channel index `iChan` (`+pds/getRippleData.m:28-29`); rfMap uses this same convention (`rfMap_finish.m:147-155`). The accumulator therefore keys off `spikeClusters` as channel index. **No `getRippleData` patch is required** — the only change needed is initializing the four fields in `p.init.trDataInitList` so concatenation works on trial 1 (see §4).
2. **Locate `stimOn` in Ripple clock.** Find the event whose value matches `p.init.codes.stimOn` using `find(..., 1, 'last')` (matches `rfMap_finish.m:136`). The `'last'` selector is robust against stale strobes still queued in the `xippmex('digin', ...)` buffer from a prior trial; `'first'` would silently lock onto stale data and put every spike outside the sweep window. Store as `stimOnRipple`. Slice the per-flip timestamps using the flip-index captured at stimOn: `flipT = p.trData.timing.flipTime(flipIdxStimOn : flipIdxStimOn + sweepFrames)`. The slice is `sweepFrames+1` long because barsweep produces a post-sweep blank flip that erases the bar (state transition `holdFixAndSweep`→`trialComplete` triggers a non-bar flip whose timestamp is appended to `flipTime`); slicing through that blank flip gives `diff(flipT)` of length `sweepFrames` with all real measured durations and no synthetic last-frame fallback. The full `flipTime` buffer is preallocated to 1×3000 and indexed by `p.trVars.flipIdx`, which counts every flip in the trial including the pre-sweep fixation period (`barsweep_run.m:273`); naive indexing as `flipTime(1:sweepFrames)` would pick up pre-stimulus flips. `flipIdxStimOn` is captured by `barsweep_run.m`'s postFlip block at the moment `stimOn` is assigned (see §4 modifications).
3. **Compute the bar's 1D projection coordinate per frame, path-center-relative.** Bar moves at angle `θ_motion`; the orientation bin is `θ_ori = mod(θ_motion, π)`. With `barCenterDeg(:, f)` the bar center in absolute dva at frame `f` and `pathCenterDeg = [pathCenterXDeg; pathCenterYDeg]` the user's sweep center:
   ```
   s(f) = (barCenterDeg(:, f) - pathCenterDeg)' * [cos(θ_ori); sin(θ_ori)]
   ```
   Yielding a vector `s(1:sweepFrames)` of bar positions in the path-center-relative Radon-projection coordinate, naturally bracketed by `[-pathLengthDeg/2, +pathLengthDeg/2]` regardless of where on the screen the sweep is centered.
4. **Bin spikes by stimulus position using real flip times.** For each spike `t_spike` on channel `ch`:
   ```
   tEffective_ripple = t_spike - stimOnRipple - latencyMs/1000
   if tEffective_ripple < 0 || tEffective_ripple >= sweepDuration: skip
   % Map to a frame index by binsearch into flipTime offsets relative to stimOn (PTB).
   % Both clocks tick at 1 Hz; sub-trial skew is sub-ms so the relative
   % offset is interchangeable. Use stimOn-relative time:
   tEffective_rel = tEffective_ripple
   frameIdx = find(flipTime_relStim <= tEffective_rel, 1, 'last')
   posCoord = s(frameIdx)
   posBin   = discretize(posCoord, positionEdges)
   spikeHist{ch}(oriIdx, posBin) += 1   % only if posBin is not NaN
   ```
   This handles dropped frames or wake-up jitter correctly — at typical bar velocities, an analytical `floor(t/frameDuration)+1` mismaps spikes by `barVelocity × frameDuration` ≈ 0.7 dva on a single dropped frame, which exceeds the position-bin width.
5. **Accumulate dwell time using actual frame durations.** With `flipT` sliced through the post-sweep blank flip (length `sweepFrames+1`), per-frame dwell is `diff(flipT)` — exactly `sweepFrames` real measured durations, no synthetic fallback. Vectorized:
   ```
   frameDurations = diff(flipT)                       % length sweepFrames
   posBins_perFrame = discretize(s, positionEdges)    % length sweepFrames
   valid = ~isnan(posBins_perFrame)
   dwellTime(oriIdx, :) += accumarray(posBins_perFrame(valid)', ...
                                      frameDurations(valid)', ...
                                      [numel(positionCenters) 1])'
   ```
   Accumulate even if no spikes occurred — dwell is stimulus-only.
6. **Reconstruct** (only at display time, not in the accumulator):
   ```
   rate(oriIdx, posBin) = spikeHist{ch}(oriIdx, :) ./ dwellTime(oriIdx, :)
   ```
   For the FBP regime the rate matrix becomes `iradon` input. For the cardinal4 regime, two argmax + parabolic interpolation give sub-bin RF center estimates. See §5 for full pseudocode and the zero-dwell-bin handling.
7. **Display.** Update the per-channel detail panel (selected channel) and refresh the all-channels grid.

### Why opposite directions pool naturally

Direction `θ` and direction `θ + π` produce sweeps along the same 1D coordinate axis but traversed in reverse. Latency-corrected, both yield the same projection-coordinate-vs-rate function. With `θ_ori = mod(θ_motion, π)`, both directions accumulate into the **same orientation row** of `spikeHist` and `dwellTime`, automatically pooling them. This gives the user a free SNR boost when running balanced opposite-direction pairs and is the cheapest first-order latency-error correction (the sign of the latency-induced position offset flips between opposite directions; pooling cancels it to first order).

**This first-order cancellation is only effective when both directions of a pair have run roughly equal trial counts.** Early in a session, with the schedule shuffler delivering directions one at a time, a 4:1 imbalance between forward and reverse can easily occur. The accumulator displays the per-orientation `min(dwellForward, dwellReverse) / max(dwellForward, dwellReverse)` ratio in the figure title as a "balance" diagnostic, so the experimenter knows when the latency-cancellation assumption is being honored. Real LGN latencies span ~25–55 ms across cells; with a single scalar `rfLatencyMs` and balanced opposite-pair pooling, the residual smear on the bar-motion axis is `Δlatency × bar_velocity` ≈ 0.1 dva at 10°/s. At higher bar velocities (30°/s), residual smear approaches the position-bin width and per-channel latency estimation becomes worthwhile — see §10 follow-up.

### Regime selection: two settings files via `exptType`

Following the joystick_release pattern: keep one shared quintet (`barsweep_init.m`, `barsweep_next.m`, `barsweep_run.m`, `barsweep_finish.m`), and define each regime by its own settings file that sets a unique `p.init.exptType` string.

| Settings file | `p.init.exptType` | Angle list | Reconstruction |
|---|---|---|---|
| `barsweep_settings.m` (existing) | `'barsweep_cardinal4'` | `[0 90 180 270]` | 1D x-profile + 1D y-profile + separable 2D outer product |
| `barsweep_rfmap12_settings.m` (new) | `'barsweep_rfmap12'` | `[0 30 60 90 120 150 180 210 240 270 300 330]` | FBP via `iradon` |

`barsweep_init.m` keys off `p.init.exptType` to set `p.init.barsweepSchedule.angleList` — same dispatcher pattern as `initTrialStructure.m:50` in the joystick_release task. No GUI dropdown is needed; the experimenter chooses regime by selecting the appropriate settings file in the PLDAPS GUI's file browser.

`plotBarsweepRF.m` keys off `p.init.exptType` to choose the reconstruction strategy. Everything else (accumulator allocation, spike binning, dwell time accumulation, save-strip behavior) is identical across regimes.

This keeps stimulus design (which schedule to run) orthogonal to the analysis flag (`useOnlineRF`). A user could hypothetically run cardinal4 with `useOnlineRF=false` for direction-tuning-only sessions; the regime then selects only the angle schedule and the online RF infrastructure stays cold.

#### Future regimes

The two-settings-file pattern is open-ended. Adding `'rfmap8'` (8 directions / 4 orientations, faster than rfmap12 but with blurrier reconstructions) is a one-file copy + an entry in the dispatcher's `switch`. A 6-direction / 3-orientation regime is technically possible but lies below FBP's practical lower bound (visible streak artifacts); not recommended. Out of scope for v1.

## 3. New strobe codes

Currently strobed parameters are stimulus-only. The online RF feature requires no new event codes — it consumes the existing `stimOn` and `stimOff`. **Sweep geometry is already strobed per trial** via the existing `barsweepAngle_x10`, `barsweepCenterTheta_x10`, `barsweepCenterRadius_x100`, `barsweepPathLength_x100`, `barsweepSpeed_x100`, and `barsweepWidth_x100` codes (`barsweep_settings.m:308-331`), so a mid-session sweep recentering is already fully recoverable from the ephys stream alone. What is *not* currently captured are the RF-analysis-specific parameters; these need new strobes so that a mid-session GUI change to e.g. `rfRampCutoff` doesn't leave offline analyses unable to recover the same online estimate:

- `barsweepExptType` — `1 = barsweep_cardinal4`, `2 = barsweep_rfmap12`. (Future regimes get 3, 4, ….) Strobed once per trial via `p.init.strobeList`.
- `barsweepRfLatency` — latency in ms (1 ms resolution; 40 ms → 40). No scaling factor.
- `barsweepRfPosBin_x100` — position-bin width in dva × 100 (so 0.25 dva → 25), matching the existing `_x100` convention.
- `barsweepRfRampCutoff_x100` — `iradon` cutoff × 100 (so 0.5 → 50). rfmap12 only; cardinal4 strobes 0.
- `barsweepRfRampFilter` — small enum (1 = `'Ram-Lak'`, 2 = `'Hann'`, 3 = `'Shepp-Logan'`, 4 = `'Cosine'`). rfmap12 only; cardinal4 strobes 0.

> **Testing-time check:** CLAUDE.md states "Strobe values must be positive integers" and the project convention is to add an offset for non-positive values. Strobing 0 for the two rfmap12-only fields under cardinal4 may be silently dropped or mis-decoded by the recording system. Verify on the rig in the first cardinal4 session; if 0 doesn't round-trip cleanly, switch to a sentinel `1 = 'N/A'` (filter enum shifts to 2..5; cutoff sentinel = 1) or conditionally append the two rows to `strobeList` only when `exptType == 'barsweep_rfmap12'`. Sentinel approach is simpler.

Per-trial strobing of `barsweepRfLatency` deserves an explicit note: latency is *not* on the auto-reset list (changing it doesn't invalidate the accumulator — reconstruction can re-bin), so strobing it per trial means the saved offline data has the latency value applied at *that trial's* accumulation, not a session-wide constant. Mid-session latency edits are recoverable trial-by-trial from the strobe stream alone.

Adding these is cheap and protects against the failure mode where the experimenter changes a setting mid-session and the offline analysis re-uses the wrong value. Codes go in the next available block in `+pds/initCodes.m`; pick a contiguous range — verify against current allocations before writing.

**Default filter = `'Hann'` for online use.** With ~30 trials and the sparse coverage typical of online sessions, full ramp filtering produces visibly streaky reconstructions even with `rampCutoff=0.5`. `'Hann'` smooths the high-frequency end and gives an interpretable image at the convergence point that matters most (when the experimenter is deciding whether to nudge the sweep center). The GUI knob and strobe are retained for offline-replay flexibility — `'Ram-Lak'` is documented as the offline-replay choice when full per-trial saved data is reprocessed.

## 4. Files to add and modify

### New files

Under `tasks/barsweep/`:
- **`barsweep_rfmap12_settings.m`** — copy of `barsweep_settings.m` with one change: `p.init.exptType = 'barsweep_rfmap12'` (vs. `'barsweep_cardinal4'` in the existing settings file). Both regimes default `useOnlineRF = true` (see §10 design choice); the regime selection is purely about the angle schedule and the reconstruction strategy, not whether RF mapping is on. Most parameters carry over unchanged. ~same line count as `barsweep_settings.m`.

Under `tasks/barsweep/supportFunctions/`:
- **`initBarsweepRF.m`** — allocate `p.init.barsweepRF` accumulators based on settings; called once from `barsweep_init.m`. Allocates the 3D `spikeHist` array of size `[nOri × nPosBins × nCh]` (the §1 form, used by the vectorized 2D `accumarray` over `(posBin, channel)` in §5), zeros the `[nOri × nPosBins]` dwell matrix, precomputes `positionEdges`/`positionCenters`/`orientationsRad`/`directionsRad`, allocates `trialsByDirection = zeros(nDir, 1)`. The `nOri` dimension equals 2 for `cardinal4` and 6 for `rfmap12`; `nDir` equals 4 or 12. ~60 lines.
- **`initBarsweepRFDisplay.m`** — create the figure with a 2-panel layout (detail + grid), cache image/line/text handles in `figData`, return for storage on `p.init.barsweepRF.figData`. The detail-panel layout differs by regime: `cardinal4` shows two 1D rate-profile axes side-by-side plus a small separable-2D thumbnail; `rfmap12` shows a single 2D image axis. The all-channels grid is identical across regimes (one tile per channel). Modeled on `tasks/rfMap/supportFunctions/initSTADisplay.m`. ~120 lines.
- **`accumulateBarsweepRF.m`** — pure function: take `(p)` (or just the relevant fields), update `spikeHist`, `dwellTime`, `spikeCount` for this trial. Identical for both regimes. ~120 lines.
- **`reconstructBarsweepRF.m`** — pure function: given `spikeHist{ch}`, `dwellTime`, `orientationsRad`, `nMapPixels`, and `exptType`, return either `(rfMap2D, axisDeg)` for `rfmap12` (via `iradon`) or `(rateProfileX, rateProfileY, separable2D, xCenter, yCenter, axisX, axisY)` for `cardinal4`. Implemented as a small dispatcher on `exptType` calling internal helpers `reconstructFBP` and `reconstructCardinal`. ~80 lines total. Kept separate from `plotBarsweepRF` so it's reusable from offline scripts.
- **`plotBarsweepRF.m`** — refresh figure; calls `reconstructBarsweepRF` for the selected channel and for each channel's all-channels-grid tile. Branches on `exptType` for the detail-panel rendering only (the all-channels grid uses the same per-tile rendering as the detail panel for whichever regime is active). Modeled on `plotSTA.m`. ~150 lines.

### Modifications to existing files

- **`barsweep_settings.m`**:
  - Add `p.init.exptType = 'barsweep_cardinal4'`.
  - Add `p.trVarsInit.useOnlineRF = true` (per §10; bypass cleanly if Ripple is unavailable).
  - Add `p.trVarsInit.rfNChannels = 32`. (Single-pedestal Ripple default; users with dual-pedestal or 64-channel arrays bump this. The grid layout and `iradon` cost both scale linearly; ~2 ms per channel × 64 = 128 ms still fits the 500 ms ITI. Document the upper bound or compute from `p.rig.ripple.nChannels` if that field exists; otherwise leave as a user-set scalar.)
  - **Silent-drop guard.** The §5 hot path filters `chs >= 1 & chs <= rf.nChannels`, which would silently discard spikes from channels above the configured limit if a 64-channel user forgets to bump `rfNChannels`. `initBarsweepRF` (or `accumulateBarsweepRF` on the first trial that produces spikes) must compare `max(p.trData.spikeClusters)` against `rf.nChannels` and **error loudly** if the live data exceeds the configured limit, with a message naming the offending channel index and pointing the user at `rfNChannels`. A warn-and-continue path is wrong here — a half-population RF map looks like real data and would be a silent failure.
  - Add `p.trVarsInit.rfLatencyMs = 40` (LGN default; user changes to 60 for SC).
  - Add `p.trVarsInit.rfPosBinDeg = 0.25`.
  - Add `p.trVarsInit.rfMapExtentDeg = 10` (half-width of 2D output image).
  - Add `p.trVarsInit.rfRampFilter = 'Ram-Lak'` (`iradon` filter type for the rfmap12 regime; `'Hann'` is also exposed for users wanting smoother defaults).
  - Add `p.trVarsInit.rfRampCutoff = 0.5` (`iradon` high-frequency cutoff for the rfmap12 regime).
  - Add `p.trVarsInit.rfSelectedChannel = 1`. **Note:** like every other live-tunable knob, this is copied to `trVars` at trial start, mirrored into `trVarsGuiComm` so the GUI can write it, then read fresh from `p.trVars.rfSelectedChannel` per trial in `plotBarsweepRF`. Reading from `trVarsInit` would freeze the selector at settings load and silently ignore mid-session GUI changes. The same `trVarsInit → trVars` flow applies uniformly to `rfLatencyMs`, `rfPosBinDeg`, `rfMapExtentDeg`, `rfRampFilter`, `rfRampCutoff`, and `pathCenterXDeg`/`pathCenterYDeg` — auto-reset detection in `_finish.m` compares `p.trVars.*` against the snapshot in `p.init.barsweepRF`.
  - Add `p.trVarsInit.useOnlineSort = 0` (matches `rfMap_commonSettings.m:223`). Required by the assert in `barsweep_init.m` (see below); barsweep does not currently expose this field at all.
  - **Add Ripple-data fields to `p.init.trDataInitList`:** `'p.trData.spikeTimes', '[]'`; `'p.trData.spikeClusters', '[]'`; `'p.trData.eventTimes', '[]'`; `'p.trData.eventValues', '[]'`. Without these, `getRippleData`'s concatenation errors on trial 1 (rfMap initializes the equivalent in `rfMap_commonSettings.m` `p.init.trDataInitList`; barsweep currently does not).
  - **Add `flipIdxStimOn` to `p.init.trDataInitList`:** `'p.trData.timing.flipIdxStimOn', '-1'`. Captured in `barsweep_run.m` postFlip block (see below).
  - Append the new strobe codes to `p.init.strobeList`.
- **`barsweep_run.m` (specifically inside the `drawMachine` local function, *not* `stateMachine`)**:
  - Immediately after the existing postFlip assignment block (`barsweep_run.m:285–293`), capture the flip index that corresponded to stimOn:
    ```matlab
    if p.trData.timing.stimOn > 0 && p.trData.timing.flipIdxStimOn < 0
        p.trData.timing.flipIdxStimOn = p.trVars.flipIdx;
    end
    ```
    This runs before the `flipIdx` increment at `barsweep_run.m:298`, so `flipIdx` correctly points at the flip that just rendered stimOn. The block lives inside `drawMachine` because that's where `flipIdx` is owned and incremented.
- **`barsweep_init.m`**:
  - Branch on `p.init.exptType` to set `p.init.barsweepSchedule.angleList`:
    ```matlab
    switch p.init.exptType
        case 'barsweep_cardinal4', p.init.barsweepSchedule.angleList = [0 90 180 270];
        case 'barsweep_rfmap12',   p.init.barsweepSchedule.angleList = 0:30:330;
        otherwise, error('Unknown barsweep exptType: %s', p.init.exptType);
    end
    ```
    (Currently the angle list is hard-coded; this is a small refactor.)
  - **Assert `p.trVars.useOnlineSort == false` when `useOnlineRF == true`.** `pds.getRippleData` already populates `spikeClusters` with channel index `iChan` when `useOnlineSort == false` (`+pds/getRippleData.m:28–29`); rfMap uses this convention (`rfMap_finish.m:147–155`). The accumulator keys off `spikeClusters` as channel index, matching rfMap. With online sort enabled, `spikeClusters` carries unit IDs and the channel mapping is lost. Online-sort + online-RF coexistence is a v2 feature; gate it out with an explicit assert and clear error message. The error string must name both flags by their full `p.trVars.*` paths and tell the user how to fix it (`"Online RF mapping requires p.trVars.useOnlineSort = 0; got %d. Either disable online sort in the GUI or disable useOnlineRF."`) — a generic `assert(...)` with no message becomes a confusing downstream failure for users who happen to load an existing settings file with `useOnlineSort = 1`.
  - If `useOnlineRF == true` and `p.rig.ripple.status == true`, call `initBarsweepRF(p)` and `initBarsweepRFDisplay(p)`.
  - If `useOnlineRF == true` and Ripple is unavailable, warn once and proceed; the `_finish.m` guard is `useOnlineRF && p.rig.ripple.status` so accumulation simply won't happen.
- **`barsweep_next.m`**:
  - In `nextParams.m`, also precompute and store `p.trVars.sweepCenterDegByFrame` (a `[2 x sweepFrames]` matrix in dva, parallel to the existing `sweepCenterPix` precomputation). Use this name to avoid colliding with the existing `[1×2]` `p.trData.sweepCenterDeg` static path-center field at `nextParams.m:111` (which we leave alone).
- **`barsweep_finish.m`**:
  - Add `pds.getRippleData(p)` call at the top, gated on `useOnlineRF && p.rig.ripple.status`.
  - **Detect spatial-parameter changes:** before calling `accumulateBarsweepRF`, compare `pathCenterDeg`, `pathLengthDeg`, `barWidthDeg`, `rfPosBinDeg`, `rfLatencyMs` against their snapshot in `p.init.barsweepRF`. **Sub-bin nudge filter:** a `pathCenterDeg` change with `max(abs(delta)) < rfPosBinDeg` along both axes is treated as label-only — update the displayed axis offsets (so the on-screen RF moves with the new label) but do **not** zero the accumulator (see §1 UX trade-off). Bigger spatial moves and any change to `pathLengthDeg`/`barWidthDeg`/`rfPosBinDeg`/`rfLatencyMs` enter the full reset path:
    1. **Snapshot the pre-reset accumulator** to `<sessionId>_barsweepRF_resetN.mat` (with `N = p.init.barsweepRF.resetCount + 1`) before doing anything else. Without this, the auto-reset destroys exactly the data the experimenter wants to review post hoc — see §1.
    2. Re-run `initBarsweepRF(p)` (zero accumulators, recompute `positionEdges` from the new `pathLengthDeg`/`barWidthDeg`/`rfPosBinDeg`, increment `resetCount`).
    3. Set a one-trial banner flag for `plotBarsweepRF` to display (`"RF accumulator reset (N=%d)"`).
    Reconstruction-only knobs (`rfMapExtentDeg`, `rfRampFilter`, `rfRampCutoff`, `rfSelectedChannel`) do **not** trigger this path; `plotBarsweepRF` reads them live.
  - On rewarded trials only (same gate rfMap uses), call `accumulateBarsweepRF(p)`.
  - Call `plotBarsweepRF(...)` once per trial (see rfMap_finish.m:168 pattern).
  - Strip `p.init.barsweepRF.spikeHist` and `p.init.barsweepRF.dwellTime` before `pds.saveP` and restore after, mirroring rfMap_finish.m:68–82.
  - **Session-end accumulator save:** after `pds.saveP`, write a sidecar `<sessionId>_barsweepRF.mat` containing `p.init.barsweepRF` (overwrite each trial). The latest snapshot on disk is the post-session state — no need to detect "last trial," which PLDAPS doesn't expose. Cost is ~120 KB per write at 32 ch × 6 orientations × 80 bins × 8 bytes plus headers; fast on a local SSD. **Assumes the per-trial save directory is local;** if `pds.saveP`'s output path is on a network share, the per-trial overwrite cost can grow into the tens of milliseconds and may chew into the ITI budget. For network-share sessions, skip the per-trial sidecar overwrite and write only on `_resetN` events plus once at session end (gate on a path heuristic or a config flag).
- **`+pds/initCodes.m`**:
  - Add `codes.barsweepExptType` (1 = `barsweep_cardinal4`, 2 = `barsweep_rfmap12`).
  - Add `codes.barsweepRfLatency` (ms, 1 ms resolution).
  - Add `codes.barsweepRfPosBin_x100` (dva × 100).
  - Add `codes.barsweepRfRampCutoff_x100` (`iradon` cutoff × 100; e.g. 0.5 → 50).
  - Add `codes.barsweepRfRampFilter` (small enum: 1 = `'Ram-Lak'`, 2 = `'Hann'`, 3 = `'Shepp-Logan'`, 4 = `'Cosine'`).

Estimated total new code: ~530 lines across 5 new files (one settings file + four supportFunctions); ~70-line diff to existing files.

## 5. Pseudocode for the hot path

```matlab
% In barsweep_finish.m, gated on useOnlineRF && p.rig.ripple.status
function p = accumulateBarsweepRF(p)
    rf = p.init.barsweepRF;

    % 1. Find stimOn in Ripple clock. Use 'last' (matches rfMap_finish.m:136).
    %    Per +pds/getRippleData.m:38-43 the digin buffer drains on read, so
    %    cross-trial pollution is unlikely. The real reason 'last' matters:
    %    if anything in the run loop ever causes stimOn to be re-strobed
    %    within a single trial (retry logic, error path), 'last' deterministi-
    %    cally tracks the most recent value while 'first' would silently lock
    %    onto a stale within-trial strobe.
    stimOnCode = p.init.codes.stimOn;
    onMask = p.trData.eventValues == stimOnCode;
    if ~any(onMask), return; end                     % strobe missed; skip
    stimOnRipple = p.trData.eventTimes(find(onMask, 1, 'last'));

    % 2. Sweep geometry in PATH-CENTER-RELATIVE dva, projection coordinate
    %    sweepCenterDegByFrame is precomputed in nextParams.m alongside
    %    sweepCenterPix (see §6 — preferred Option A: store both at trial
    %    setup). Note: the existing p.trData.sweepCenterDeg is a separate
    %    [1x2] static path-center field; do not confuse the two.
    relCenter   = p.trVars.sweepCenterDegByFrame - rf.pathCenterDeg;  % [2 x sweepFrames]
    thetaMotion = deg2rad(p.trVars.pathAngleDeg);
    thetaOri    = mod(thetaMotion, pi);
    projAxis    = [cos(thetaOri); sin(thetaOri)];
    s_perFrame  = projAxis' * relCenter;              % [1 x sweepFrames]
    [~, oriIdx] = min(abs(rf.orientationsRad - thetaOri));

    % 3. Slice flipTime by the captured stimOn flip index (NOT 1:sweepFrames —
    %    flipTime is preallocated 1x3000 and counts pre-stim flips too).
    %    Slice through fi0+sweepFrames inclusive: the +1th entry is the
    %    post-sweep blank flip that erases the bar (state holdFixAndSweep
    %    transitions to trialComplete, which produces a non-bar flip whose
    %    timestamp is appended to flipTime). diff() then yields exactly
    %    sweepFrames real measured durations — no synthetic fallback.
    fi0    = p.trData.timing.flipIdxStimOn;
    flipT  = p.trData.timing.flipTime(fi0 : fi0 + p.trVars.sweepFrames);
    flipT  = flipT(:)' - flipT(1);                    % stim-onset relative
    frameDur = diff(flipT);                            % length sweepFrames

    % 4. Dwell-time update (vectorized)
    posBins_perFrame = discretize(s_perFrame, rf.positionEdges);
    valid = ~isnan(posBins_perFrame);
    if any(valid)
        rf.dwellTime(oriIdx, :) = rf.dwellTime(oriIdx, :) + ...
            accumarray(posBins_perFrame(valid)', frameDur(valid)', ...
                       [numel(rf.positionCenters) 1])';
    end

    % 5. Spike binning, vectorized across all channels (2D accumarray)
    %    spikeClusters carries the channel index when useOnlineSort=false
    %    (asserted in barsweep_init.m); identical convention to rfMap_finish.m:147.
    %    flipT has sweepFrames+1 entries (last = post-sweep blank flip),
    %    so it is itself the frameEdges vector and flipT(end) is sweepDur.
    sweepDur   = flipT(end);
    frameEdges = flipT;

    tAll = p.trData.spikeTimes - stimOnRipple - rf.latencyMs/1000;
    keep = tAll >= 0 & tAll < sweepDur;
    if any(keep)
        chs   = p.trData.spikeClusters(keep);
        frIdx = discretize(tAll(keep), frameEdges);
        ok    = ~isnan(frIdx) & chs >= 1 & chs <= rf.nChannels;
        if any(ok)
            posBins = discretize(s_perFrame(frIdx(ok)), rf.positionEdges);
            ok2     = ~isnan(posBins);
            chsK    = chs(ok); chsK = chsK(ok2);
            posK    = posBins(ok2);
            if ~isempty(posK)
                nPos = numel(rf.positionCenters);
                inc  = accumarray([posK(:), chsK(:)], 1, [nPos, rf.nChannels]);
                rf.spikeHist(oriIdx, :, :) = squeeze(rf.spikeHist(oriIdx, :, :)) + inc;
                rf.spikeCount = rf.spikeCount + accumarray(chsK(:), 1, [rf.nChannels, 1]);
            end
        end
    end

    % 6. Per-direction trial counter (for the balance diagnostic in §2)
    [~, dirIdx] = min(abs(rf.directionsRad - thetaMotion));
    rf.trialsByDirection(dirIdx) = rf.trialsByDirection(dirIdx) + 1;

    p.init.barsweepRF = rf;
end
```

`reconstructBarsweepRF` dispatches on `exptType`. Three correctness details:

- **Zero-dwell handling.** A position bin the bar never visited has `dwellTime == 0`. Setting the rate there to zero (the obvious choice) lets `iradon` back-project "evidence of no spikes" through that bin and biases the reconstruction. Instead, set zero-dwell bins to the **column mean** for that orientation (so they contribute the average rate, neither suppressing nor exciting the back-projection). The artifact is most visible early in a session when dwell coverage is sparse.
- **Sub-bin precision for cardinal4 centers.** `[~,ix] = max(rateX)` rounds the RF center to the nearest 0.25 dva. A 3-point parabolic interpolation around the peak gives sub-bin resolution at zero cost; this is what an experimenter does by eye on paper PSTHs. Caveat: the parabolic fit assumes a unimodal RF profile. Bimodal profiles (rare in LGN/SC but possible at MUA recording sites with two cells under one electrode) produce sub-bin nonsense. The fit falls back to argmax when the second-derivative discriminant is small (see `parabolicPeak` below).
- **Bar-width-induced position blur affects RF *width* estimates, not RF *center* estimates.** A bar of width `barWidthDeg` convolves the projected RF along the projection axis with a symmetric boxcar of width `barWidthDeg`. Symmetric convolution preserves the centroid and the location of the peak, so the recovered RF *center* is unbiased and recoverable to sub-bin precision given enough spikes — exactly what the cardinal4 parabolic interpolation does. The recovered RF *width* is inflated by `≈ barWidthDeg` (in quadrature for a Gaussian-on-Gaussian convolution; additive for FWHM rules of thumb). Document this distinction in the task readme: "RF center is recoverable to sub-bin precision; RF width readouts (FWHM/1-σ) are inflated by ≈barWidthDeg and should be deconvolved offline if widths matter."

```matlab
function out = reconstructBarsweepRF(rf, ch, exptType)
    rateMatrix = squeeze(rf.spikeHist(:, :, ch)) ./ rf.dwellTime;
    % Zero-dwell -> NaN, then replace per orientation with that orientation's mean
    zeroDwell = ~isfinite(rateMatrix);
    for k = 1:size(rateMatrix, 1)
        rowMean = mean(rateMatrix(k, ~zeroDwell(k, :)));
        if isnan(rowMean), rowMean = 0; end
        rateMatrix(k, zeroDwell(k, :)) = rowMean;
    end

    switch exptType
        case 'barsweep_rfmap12'
            nMapPix = round(2 * rf.mapExtentDeg / rf.mapPixelDeg);
            out.rfImage = iradon(rateMatrix', rad2deg(rf.orientationsRad), ...
                                 'linear', rf.rampFilter, rf.rampCutoff, nMapPix);
            out.axisDeg = linspace(-rf.mapExtentDeg, rf.mapExtentDeg, nMapPix);

        case 'barsweep_cardinal4'
            % After opposite-pooling, orientationsRad has 2 entries:
            % 0 (vertical bar, x-projection) and pi/2 (horizontal bar, y-projection).
            xIdx = find(abs(rf.orientationsRad - 0)    < 1e-6, 1);
            yIdx = find(abs(rf.orientationsRad - pi/2) < 1e-6, 1);

            out.rateX = rateMatrix(xIdx, :);
            out.rateY = rateMatrix(yIdx, :);
            out.axisX = rf.positionCenters;     % path-center-relative dva
            out.axisY = rf.positionCenters;
            out.xCenter = parabolicPeak(out.axisX, out.rateX);
            out.yCenter = parabolicPeak(out.axisY, out.rateY);
            % Outer-product separable estimate, normalized to [0,1]
            sep = out.rateY(:) * out.rateX(:)';     % rows = y, cols = x
            sep = sep / max(sep(:) + eps);
            out.separable2D = sep;
        otherwise
            error('Unknown exptType: %s', exptType);
    end
end

function xPeak = parabolicPeak(xAxis, y)
    [~, i] = max(y);
    if i == 1 || i == numel(y), xPeak = xAxis(i); return; end
    y1 = y(i-1); y2 = y(i); y3 = y(i+1);
    denom = (y1 - 2*y2 + y3);
    if abs(denom) < eps, xPeak = xAxis(i); return; end
    delta = 0.5 * (y1 - y3) / denom;          % sub-bin offset in [-1, 1]
    xPeak = xAxis(i) + delta * (xAxis(2) - xAxis(1));
end
```

Path-center is added back at display time: the user-visible RF center is `(out.xCenter + pathCenterXDeg, out.yCenter + pathCenterYDeg)` for cardinal4, and the rfmap12 image axes get labeled as `axisDeg + pathCenterXDeg` (and similarly for y).

## 6. Reusing `sweepCenterPix` cleanly

`p.trVars.sweepCenterPix` is in pixels with the PTB y-down sign convention. Two clean options:

- **Option A (preferred):** also precompute and store `sweepCenterDeg` in `nextParams.m` (one extra `linspace` line on dva endpoints, with the user-visible y-up sign). Pure additive; keeps the run loop unchanged; no risk of sign-flip bugs at accumulation time.
- **Option B:** invert the pixel→dva conversion at accumulation time. Works but couples accumulation to rig calibration and re-introduces y-sign handling in two places.

Pick Option A. The cost is one extra `linspace` and 16 bytes per trial. The §5 pseudocode assumes this.

## 7. Display layout

One figure window with two panels. The detail panel's contents differ by regime; the all-channels grid is identical across regimes.

### Detail panel — `barsweep_rfmap12`

A single 2D image showing the FBP-reconstructed RF for `p.trVars.rfSelectedChannel`. Axes labeled in dva, with crosshair at the current `pathCenterXDeg, pathCenterYDeg`. Title: `"ch %d  spikes=%d  trial=%d  bal=%.2f  (FBP)"` where `bal` is the worst per-orientation `min(forward, reverse) / max(forward, reverse)` ratio derived from `trialsByDirection` — the §2 balance diagnostic. Color the title text **red** when `bal < 0.5` so the experimenter notices imbalance even if they aren't reading the title; otherwise use default text color.

`iradon` output legitimately goes negative (filtered back-projection ringing), so a sequential colormap would misrepresent ringing as "low rate." Use a **diverging blue-white-red colormap** with symmetric limits `±max(abs)`, **plus a black contour overlay at the zero crossing** so the experimenter can visually distinguish "no RF here" (near-zero, light shading) from "ringing artifact" (negative-going, blue lobe). The contour costs one `contour(..., [0 0])` call per refresh; trivial.

### Detail panel — `barsweep_cardinal4`

Three sub-axes laid out in a 1×3 row inside the detail panel:
1. **1D rate-vs-x** (vertical-bar sweeps): line plot of `rateX` against `axisX`, with a marker at the peak position `xCenter` and a vertical line at `pathCenterXDeg` (to show the user where the sweep is centered relative to the peak).
2. **1D rate-vs-y** (horizontal-bar sweeps): same as above but for `rateY` against `axisY`.
3. **Separable 2D estimate**: `imagesc(axisX, axisY, separable2D)` with the same crosshair and a title prefix `"sep. estimate"` so the experimenter is reminded the 2D is an outer-product approximation, not a true 2D measurement. Symmetric color limits as above.

Title text on the detail panel: `"ch %d  spikes=%d  trial=%d  bal=[%.2f, %.2f]  (cardinal4: x_c=%.2f, y_c=%.2f dva)"` — the two `bal` entries are the per-pair `min/max` ratios for `{0°, 180°}` (x-axis pair) and `{90°, 270°}` (y-axis pair) respectively. With only two pairs the worst-case scalar hides the action item: balanced 50/50 on x with 80/20 on y has the same scalar as 60/40 on both, but the corrective action ("run more horizontal sweeps") is specific to the y pair. The red-text rule fires when `min(both ratios) < 0.5`. (rfmap12 has 6 pairs; the worst-case scalar in the rfmap12 title remains appropriate there.)

### All-channels grid (both regimes)

A `ceil(sqrt(nCh)) × ceil(sqrt(nCh))` grid of small per-channel summaries, contrast-normalized per-tile. Title per tile: `"ch%d  N=%d"`. Modeled on `plotSTA.m:29–79`.

- **`rfmap12`**: each tile is the FBP image (same colormap and zero-contour treatment as the detail panel).
- **`cardinal4`**: each tile is **NOT** the separable-2D outer product. The outer-product image is shape-misleading for any non-circular RF (a horizontally-elongated separable image looks like an oriented horizontal blob even when the underlying cell has no orientation preference, just because horizontal-bar sweeps got more spikes). Instead, each tile shows the two 1D rate profiles (rate-vs-x and rate-vs-y) overlaid on a shared axis, with markers at `xCenter` and `yCenter`. The (x_c, y_c) pair is the actually-supported quantity; the 2D outer-product thumbnail is reserved for the detail panel where it can be labeled "separable estimate" and the experimenter is paying attention to the caveat.

### Update cadence

Once per rewarded trial, in `_finish.m` after `accumulateBarsweepRF`. The full all-channels grid runs `iradon` 32 times per refresh — each call is ~1–3 ms on a modern CPU at 80×80 output from 6 projections, so ~30–100 ms total wall clock. The configured ITI is 500 ms (current `barsweep_settings.m`), so the refresh fits comfortably within the ITI budget. If grid responsiveness becomes an issue on slower hardware, fall back to caching last-trial all-channels images and recomputing only the selected-channel detail panel at full res. The cardinal4 reconstruction is even cheaper (no `iradon`, just two argmax + an outer product) and not a concern.

### Channel selection

Read from `p.trVars.rfSelectedChannel` each `plotBarsweepRF` call. The selector flows: `trVarsInit` (initial value) → copied to `trVars` and mirrored in `trVarsGuiComm` at trial start → GUI writes to `trVarsGuiComm` → next-trial copy lands in `trVars` → `plotBarsweepRF` reads `trVars`. Reading from `trVarsInit` directly would freeze the selector at settings load and silently ignore mid-session GUI changes. **All other live-tunable RF knobs follow the same flow** — `rfLatencyMs`, `rfPosBinDeg`, `rfMapExtentDeg`, `rfRampFilter`, `rfRampCutoff`, `pathCenterXDeg`, `pathCenterYDeg` are read from `p.trVars.*` in `plotBarsweepRF` and `barsweep_finish.m`'s auto-reset detector, never `trVarsInit`.

## 8. Clock and timing

The plan uses **Ripple clock for both spikes and the `stimOn` reference time**. `p.trData.eventTimes` is populated by `pds.getRippleData` from `xippmex('digin', ...)` and is in the same 30 kHz Ripple clock as `spikeTimes`. This is the same pattern rfMap uses (rfMap_finish.m:143). The subtraction `t_spike - stimOnRipple` is internally consistent because both sides are in Ripple time.

`p.trData.timing.flipTime` is in PTB clock (trial-start-relative scalars assigned post-flip by `drawMachine`). The accumulator uses `flipTime` only as a **stim-onset-relative** quantity (`flipT - flipT(1)`), so the absolute clock origin doesn't matter — only the relative durations between flips, which are PTB-only and not subject to PTB-vs-Ripple skew at all. The cross-clock comparison between spike-time-relative-to-stimOn (Ripple) and flipTime-relative-to-stimOn (PTB) is valid because both clocks tick at the same rate (1 s/s) and any rate skew is sub-ppm over a single-trial duration; sub-millisecond residual is well below the position-bin resolution.

**Footnote on the constant Ripple-digin offset.** The `stimOn` strobe is fired at `barsweep_run.m:280`, immediately *after* the flip on line 273 and the `lastFrameTime` postFlip assignment. The strobe then propagates through DataPixx → Ripple with a small physical delay (~100–300 μs from optocoupler + Ripple sample-and-hold). So `stimOnRipple` is systematically *later* than the PTB `flipTime(flipIdxStimOn)` that anchors `flipT(1)`. This is **not** a clock-skew issue — both clocks tick at 1 Hz to within sub-ppm — but a constant additive offset that biases the apparent spike latency by 100–300 μs. Far below the position-bin resolution (~1 ms equivalent at 30°/s ≈ 0.03 dva), so it's negligible for online RF localization. Noted here so a future debugging pass tracking down a ~5 ms offset isn't surprised. If sub-bin precision ever matters, the offset can be characterized once with a flash + photodiode and subtracted from `stimOnRipple`.

Failure modes and their handling:
- **`stimOn` strobe not seen by Ripple** (rare; e.g., DataPixx buffer flush issue). The code finds no matching event and returns without updating accumulators. Trial is silently dropped from RF estimate but everything else proceeds normally.
- **Ripple temporarily disconnected mid-session.** `p.rig.ripple.status` flips false; subsequent trials skip accumulation but the figure stays alive showing the last good state.

## 9. Configuration defaults and recording-area presets

Recommended GUI defaults:

| Parameter | `barsweep_settings.m` (cardinal4) | `barsweep_rfmap12_settings.m` (rfmap12) |
|---|---|---|
| `useOnlineRF` | `true` | `true` |
| `rfLatencyMs` | 40 | 40 |
| `rfPosBinDeg` | 0.25 | 0.25 |
| `rfMapExtentDeg` | 10 | 10 |
| `rfRampFilter` | (unused) | `'Hann'` |
| `rfRampCutoff` | (unused) | 0.5 |

These are **defaults**, not hard-coded; the user changes any of them from the GUI before clicking Initialize, or mid-session at the cost of an automatic accumulator reset (§1). The latency default of 40 ms suits LGN; an SC user changes the GUI field to 60 ms. SC users with larger eccentric RFs may also widen `rfMapExtentDeg` to 15 and `rfPosBinDeg` to 0.5.

**Bar-width / position-bin coupling.** The current `barsweep_settings.m` has `barWidthDeg = 0.5`. Because every spike's effective stimulus position is smeared by ±`barWidthDeg/2` along the projection axis, the *effective* resolution ceiling is `~barWidthDeg` regardless of how fine `rfPosBinDeg` is. Choosing `rfPosBinDeg < barWidthDeg/2` buys nothing but extra zero-dwell bins; choosing `rfPosBinDeg > barWidthDeg` wastes the bar's resolution. The recommended default coupling is **`rfPosBinDeg = barWidthDeg / 2`** (so 0.25 dva for the canonical 0.5 dva bar). If a user widens `barWidthDeg` mid-session for a low-firing-rate cell, the natural action is to widen `rfPosBinDeg` proportionally; this is a documentation suggestion, not enforced by code (the accumulator handles any combination). The figure title or a panel-side text note should record both values so the experimenter sees the resolution ceiling.

The "preset" framing is purely a documentation suggestion in CLAUDE.md / the task readme; the implementation just exposes the underlying scalars and lets the experimenter set them. The latency defaults come from Maunsell et al. 1999 (LGN) and Boehnke & Munoz 2008 (SC).

## 10. Resolved design choices

Settled by external review during planning (not open for further negotiation unless the user pushes back):

- **`cardinal4` detail-panel layout** = 1×3 row (rate-vs-x, rate-vs-y, separable-2D thumbnail). The thumbnail is purely a visual; nothing depends on it being prominent.
- **`rfmap12` detail-panel layout** = single 2D image. No per-orientation 1D profile row in v1; the all-channels grid covers diagnostic-by-eye coverage, and a single-channel deep-dive can be done by promoting the channel to detail.
- **All-channels grid** = included in v1 (cheap, high-value).
- **Session-end accumulator save** = yes; implemented as a per-trial overwrite of `<sessionId>_barsweepRF.mat` in `barsweep_finish.m` (§4). The latest snapshot on disk is the post-session state — sidesteps the absence of a "last trial" signal in PLDAPS.
- **Online sort + online RF mapping coexistence** = **deferred to v2.** rfMap doesn't support it either, and a v1 user choosing online RF can run with hardware-sort off — same trade-off rfMap users already make. Implementation when it lands would be a `+pds/getRippleData.m` patch to populate a parallel `spikeChannels` vector, plus a `barsweep_init.m` flip to read it instead of `spikeClusters`. v1 asserts `useOnlineSort == false` when `useOnlineRF == true` with a clear error message.
- **Mid-session spatial-knob changes** = auto-reset on detection in `barsweep_finish.m`. Banner flag drives a one-trial title overlay in `plotBarsweepRF`. `rfSelectedChannel` is exempt (display-only, no accumulator impact).
- **Per-channel latency** = scalar in v1; vector is a follow-up. Implementation sketch for v2: after every K trials of an oriented pair, fit `latency(ch) = argmin_τ ||PSTH_forward(t-τ) - PSTH_reverse(t+τ)||²` per channel — a 1D grid search over 20–100 ms in 5 ms steps. Cheap and matches what the offline analysis would do. **This requires a structural change**: the v1 accumulator pools forward+reverse directions into one `oriIdx` row at accumulation time (§2 prose), discarding the per-direction PSTH the v2 latency fit needs. A v2 implementation must either (a) stop pooling at accumulation time and keep `spikeHist` indexed by `directionIdx` (doubles `nOri` to `nDir`, sums to per-orientation rate at reconstruction time), or (b) maintain a parallel direction-resolved accumulator alongside the v1 orientation-pooled one (more memory, but the v1 accumulator stays bit-identical for offline replay). Worth lifting into v1 if real-rig data show >0.5 dva residual smear after opposite-pair pooling.
- **`barsweepExptType` strobe** = yes. Protects against the "wrong settings file loaded" failure mode.
- **Aborted trials, partial-sweep recovery from `fixBreak`** = **lifted into v1.** `nonStart` trials still excluded (no bar visibility). For `fixBreak` trials, the bar position-vs-time trajectory is known up to the break time, dwell is well-defined, and visible-bar-period spikes are still RF-modulated; dropping them is a meaningful SNR cost when convergence is slow. The accumulation logic gates spikes and dwell by `tEffective < min(stimOff - stimOn, fixBreak - stimOn) - latencyMs/1000` per trial (using whichever timing event fires first; `stimOff` for completed sweeps, `fixBreak` for aborts). One extra branch in `accumulateBarsweepRF` and a guard against `fixBreak < latencyMs/1000` (in which case the trial contributes nothing). `nonStart` continues to be excluded outright. Cost: trivial; benefit: ~10–15% more contributing trials, especially in messy LGN sessions where fix breaks are common.
- **Cardinal4 default `useOnlineRF`** = `true`. The §0 motivation ("every barsweep session simultaneously yields direction tuning *and* an RF map") only holds if the feature is on by default; defaulting off requires the collaborator to flip a GUI field they currently don't touch and silently regresses the value proposition. Acceptance criterion #4 already requires clean fallback when Ripple is unavailable, so a non-recording session with `useOnlineRF = true` simply skips the RF code path with a one-time warning. Users who genuinely want the legacy behavior toggle the GUI field off before clicking Initialize.
- **Opposite-direction pair-shuffle scheduling.** The §2 balance diagnostic surfaces forward/reverse imbalance after the fact, but a small scheduler tweak prevents most of the imbalance from happening. Change the angle-list shuffler to draw opposite-direction pairs as a unit and shuffle within each pair: produce `[θ_a, θ_a+180, θ_b, θ_b+180, …]` rather than fully random, so every pair completes within two trials. ~5 lines in the schedule generator. The diagnostic stays as a sanity check, but the imbalance window shrinks from "hundreds of trials" to "one trial in flight at any time." **Gating:** this changes the angle-list distribution for *all* barsweep users, including legacy `useOnlineRF = false` runs. Both schedules are valid randomizations of the same direction set, but the collaborator should be told before their canonical schedule changes shape. Expose as `p.trVarsInit.barsweepPairShuffle` (default `true` for both regimes; flip to `false` to recover the prior fully-random behavior).

## 11. Validation steps before declaring done

Once implemented, the following checks should pass:

1. **Code path bypass.** With `useOnlineRF = false`, no `barsweepRF` field is created on `p`, no figure opens, no `getRippleData` calls happen. Verify in both regimes.
2. **Ripple-disabled fallback.** With `useOnlineRF = true` but `p.rig.ripple.status = false`, `_init.m` warns once and proceeds; `_finish.m` gates correctly and never errors. Verify in both regimes.
3. **Synthetic spikes test, `rfmap12`.** Inject a Poisson spike train modulated by a known 2D Gaussian RF (centered at e.g. [-3, 2] dva, σ=1 dva) at the appropriate latency-corrected time relative to bar position; run ~50 simulated trials of the 12-direction schedule; verify the FBP reconstruction returns a peak within 0.5 dva of [-3, 2]. **Visual-quality gate:** peak-location accuracy alone misses the actual operator failure mode — 30°-spaced FBP streak artifacts can produce plausible-looking secondary lobes at the convergence point (~30 trials) where the operator is deciding whether to trust the map. Add two checks: (a) ratio of primary peak to next-strongest local maximum outside a 1-σ exclusion disc around the peak ≥ 2.0 at 30 trials and ≥ 3.0 at 50 trials; (b) render the reconstructed image to PNG in the test harness and require manual inspection (i.e. the test prints the PNG path and a "verify by eye" line, not a silent pass). The current `'Hann'` + `rampCutoff=0.5` defaults are expected to clear (a); the harness exists to confirm rather than assume.
4. **Synthetic spikes test, `cardinal4`.** Same RF as above, but ~80 trials of the 4-direction schedule; verify `xCenter` is within 0.25 dva of -3 and `yCenter` is within 0.25 dva of 2 (one position bin tolerance). The detail-panel separable-2D thumbnail should also peak within 0.5 dva of the true center.

   **Latency-path coverage.** Both the rfmap12 (#3) and cardinal4 (#4) synthetic tests must use a non-default `rfLatencyMs` (e.g. 60 ms) for both the spike-train generator *and* the accumulator under test, with the same value passed through to both. If both default to 40, the latency code path is silently untested and a sign error or unit confusion (e.g. divide-by-1000 missing, or `latencyS` vs `latencyMs` left over from a prior revision) goes undetected. The harness should also include one trial where the accumulator's `rfLatencyMs` deliberately disagrees with the generator's by ±20 ms, and confirm the recovered RF center shifts by `barVelocity × Δlatency` along the projection axis — this is the smoking-gun assertion that the latency math is correctly wired and signed.
5. **Regime equivalence on sufficient data.** With ~150 trials each, the cardinal4 (`xCenter, yCenter`) estimate and the rfmap12 FBP peak location should agree to within one position bin for a separable Gaussian RF. (For a deliberately oriented elongated RF, they won't — and that's expected and useful diagnostic information.) Encoded directly in the synthetic harness as
   ```matlab
   assert(abs(rfmap12_peakX - cardinal4.xCenter) < rf.mapPixelDeg);
   assert(abs(rfmap12_peakY - cardinal4.yCenter) < rf.mapPixelDeg);
   ```
   so the test runs as a single script.
6. **Live test.** A short awake-fixation session (~10-15 min) with each regime should produce visible RF estimates for channels with strong responses.
7. **Per-trial save round-trip — hard gate.** Load a saved `.mat`, run an offline script that pulls `spikeTimes`, `spikeClusters`, `eventTimes`, `eventValues`, `flipTime`, `flipIdxStimOn`, `sweepCenterDegByFrame`, and `pathAngleDeg`, and reconstruct the same per-trial spike-position histogram update. Bit-identical to what the online code computed. (Note: `spikeClusters`, not `spikeChannels` — `getRippleData` populates `spikeClusters` with the channel index when `useOnlineSort = false`; that's the field name that flows into the saved .mat.) This is the only criterion that protects against silent online/offline divergence on real data and is the single most important acceptance test in this document. Model the harness on `tasks/rfMap/supportFunctions/testSTA.m` — name it `testBarsweepRF.m`, place under `tasks/barsweep/supportFunctions/`, and include the regime-equivalence assert from §11.5 in the same script so it runs as a single deliverable. Also a deliverable for testing task #2 (the strobe-validation pass).

## 12. Implementation order

Build and validate **rfmap12 end-to-end first**, then drop in cardinal4. The FBP path exercises every part of the binning/dwell/latency machinery; cardinal4 reconstruction is essentially a degenerate special case (two argmaxes + outer product) that's hard to get wrong once the accumulator is correct. Building both reconstructions in parallel risks debugging the dispatcher and two reconstructions simultaneously.

If approved:

1. `barsweep_rfmap12_settings.m` (new, with `exptType = 'barsweep_rfmap12'` and `useOnlineRF = true`).
2. **Strobe codes up front.** Add `barsweepExptType`, `barsweepRfLatency`, `barsweepRfPosBin_x100`, `barsweepRfRampCutoff_x100`, `barsweepRfRampFilter` to `+pds/initCodes.m` and append to both settings files' `strobeList`. Doing this first means trial 1 of every test session is already replayable from the strobe stream alone; deferring strobes to the end leaves all early validation runs non-replayable.
3. `barsweep_settings.m` additions (set `exptType = 'barsweep_cardinal4'`, add `useOnlineRF = true`, `useOnlineSort = 0`, and the RF-config fields, add Ripple-data fields and `flipIdxStimOn` to `trDataInitList`, ensure `rfSelectedChannel` is wired through `trVarsInit → trVarsGuiComm → trVars`).
4. `barsweep_run.m` patch — capture `flipIdxStimOn` inside `drawMachine` after the stimOn postFlip block (5 lines).
5. `barsweep_next.m` / `nextParams.m` — precompute and store `p.trVars.sweepCenterDegByFrame` (2 lines); also the optional pair-shuffle scheduler tweak (§10).
6. `barsweep_init.m` refactor: dispatch on `exptType` to set `angleList`; assert `useOnlineSort == false` when `useOnlineRF == true`; if `useOnlineRF && rippleOk`, call `initBarsweepRF` and `initBarsweepRFDisplay`.
7. `initBarsweepRF.m` (regime-agnostic accumulator allocation; `orientationsRad` and `directionsRad` set from `exptType`; 3D `spikeHist` allocated to `[nOri × nPosBins × nCh]`; `positionEdges` derived from `pathLengthDeg + barWidthDeg + accumMarginDeg`, NOT a hardcoded literal).
8. `accumulateBarsweepRF.m` (regime-agnostic spike binning; path-center-relative coordinates; vectorized 2D `accumarray`; per-direction trial counter).
9. `barsweep_finish.m` integration (Ripple fetch, spatial-knob change detection + save-versioned-then-reset, accumulation gate, save-strip, live-sidecar save).
10. `reconstructBarsweepRF.m` — **rfmap12 branch only first**. Validate against synthetic spikes (a 2D Gaussian RF placed at a non-zero `pathCenterDeg` to exercise the path-center-relative math).
11. `initBarsweepRFDisplay.m` and `plotBarsweepRF.m` — **rfmap12 layout only first**, reading `p.trVars.rfSelectedChannel`. Live-test on the rig.
12. Add the cardinal4 branch to `reconstructBarsweepRF.m` and the cardinal4 layout to `plotBarsweepRF.m`. Shared accumulator from steps 7–9 is reused unchanged.
13. Synthetic-spike validation harness for cardinal4 (with the regime-equivalence assert from §11.5).
14. Live test pass on the rig in cardinal4.

Each step is independently testable; the math in steps 7 + 8 is the highest-risk piece and gets the synthetic-spike harness as its acceptance gate before going anywhere near a recording session.
