# rfMap Task: Implementation Plan

## Dense Noise Receptive Field Mapping for Macaque LGN (and SC)

**Date:** 2026-04-15
**Author:** James P. Herman (with Claude Code)

---

## 1. Overview

### 1.1 Purpose

This task estimates spatio-temporal receptive fields (stRFs) in macaque LGN
(and optionally SC) during passive fixation. A full-screen dense binary noise
stimulus is presented while the monkey fixates for periodic juice reward.
Threshold-crossing times from a Ripple Grapevine NIP are used to compute a
running spike-triggered average (STA) that is displayed online, giving the
experimenter real-time feedback on RF location, spatial extent, and temporal
dynamics.

### 1.2 Design Rationale

**Why dense noise (not sparse)?** Dense noise updates every spatial location on
every frame, making it ~3-5x more data-efficient than sparse noise per unit of
fixation time. Because the stimulus is spatiotemporally white (independent
across space and time), the STA is an unbiased estimator of the linear RF
kernel even through a static output nonlinearity. The STA itself reveals where
the RF is -- there is no need for a separate "localization" step.

**Why full-screen?** When targeting LGN, the RF eccentricity is not always known
precisely in advance. Full-screen noise guarantees coverage regardless of RF
location. A small clearing patch around the fixation point prevents the noise
from interfering with the monkey's ability to see and hold fixation.

**Why not sweeping bars or checkerboards?** Sweeping bars map 1D projections and
require many repetitions across angles. Contrast-reversing checkerboards are
useful for spatial frequency tuning but have uniform spatial structure that
does not support STA-based RF estimation. Dense noise directly yields a 2D
spatiotemporal RF map.

**Why pre-generate the noise movie?** Three reasons: (1) timing reliability --
no risk of frame drops from on-the-fly computation during `_run.m`; (2)
continuity -- the noise is one deterministic sequence across all trials, and
aborted trials can be re-presented; (3) reproducibility -- saving the RNG seed
allows exact offline reconstruction of the stimulus without storing the full
matrix.

### 1.3 Primary Use Case

- Awake macaque, head-fixed, passively fixating
- Electrode (single-contact or multi-contact linear probe) in LGN or SC
- Neural signals recorded on Ripple Grapevine NIP, accessed via xippmex
- ViewPixx display at 100 Hz, timing via DataPixx
- Goal: real-time RF visualization to confirm electrode placement and
  characterize stRFs

---

## 2. Stimulus Design

### 2.1 Dense Binary Noise

The stimulus is a grid of "checks" (square elements) covering the full screen.
On each noise frame, every check is independently assigned to be black or white
(binary, 100% Michelson contrast on a mean-gray background). The check pattern
is held constant for a configurable number of display frames ("frame hold")
before the next noise frame is drawn.

The entire noise sequence is pre-generated as a matrix in `_init.m` using a
deterministic RNG seed. Each trial presents a contiguous chunk of this
sequence. If a trial is aborted (fixation break), the same chunk is
re-presented on the next attempt, ensuring complete coverage.

### 2.2 Color Modes

Two color modes are supported, selectable via a settings parameter:

- **`'luminance'`** (default, used initially): Each check is a single scalar
  value -- black (0) or white (1). The noise matrix is 3D:
  `[nChecksY, nChecksX, nFrames]`, stored as `uint8`.

- **`'rgb'`**: Each check has 3 independent values (R, G, B), each
  independently drawn as 0 or 1. The noise matrix is 4D:
  `[nChecksY, nChecksX, 3, nFrames]`, stored as `uint8`. This mode reveals
  chromatic opponency in P cells and S-cone sensitivity in K cells.

Implementation will support both modes from the start. Online STA will
initially use luminance mode only; RGB STA support can be added later.

### 2.3 Stimulus Parameters

| Parameter | Default | Range | Notes |
|---|---|---|---|
| `checkSizeDeg` | 0.5 | 0.1 - 1.0 | Check size in degrees of visual angle |
| `noiseFrameHold` | 3 | 2 - 5 | Display frames per noise frame (30ms default at 100Hz) |
| `colorMode` | `'luminance'` | `'luminance'` or `'rgb'` | Noise color mode |
| `clearPatchDeg` | 1.0 | 0 - 3.0 | Diameter of clearing patch around fixation (0 = no patch) |
| `clearPatchShape` | `'disk'` | `'disk'` or `'square'` | Shape of clearing patch |
| `movieDurationMin` | 10 | 5 - 30 | Total duration of pre-generated noise movie (minutes) |
| `contrastBinary` | true | true/false | Binary (true) or continuous uniform (false) noise |

### 2.4 Memory Estimates

At 100 Hz with a 3-frame hold, one noise frame = 30 ms. For a 10-minute movie:

- Total noise frames: `10 * 60 / 0.030 = 20,000`
- Screen coverage at rig1 geometry (410mm viewing distance, 1920x1200 px):
  approximately 61 x 40 degrees of visual angle.

| Check Size | Grid (W x H) | Luminance Matrix | RGB Matrix |
|---|---|---|---|
| 0.5 deg | 122 x 80 | 195 MB | 586 MB |
| 0.25 deg | 244 x 160 | 781 MB | 2.3 GB |
| 1.0 deg | 61 x 40 | 49 MB | 146 MB |

Luminance mode at 0.5 deg is very comfortable. For smaller check sizes or RGB
mode, memory should be verified on the target machine before running.

### 2.5 Fixation Point

The fixation point is drawn ON TOP of the noise stimulus. Its position is
configurable (default: screen center). For eccentric RF locations that would
fall outside the display with central fixation, the fixation point can be
repositioned to bring the expected RF location onto the screen.

---

## 3. Trial Structure

### 3.1 Flow

```
_settings.m   (once at load time)
    |
_init.m       (once on "Initialize" button press)
    |          - rig config, DataPixx, audio, Ripple init
    |          - pre-generate full noise movie matrix (save RNG seed)
    |          - init STA accumulators
    |          - create online STA display figure
    |
    v
_next.m       (before each trial)
    |          - check if movie is exhausted; if so, end session
    |          - slice next chunk of noise frames from movie matrix
    |          - create PTB textures for this trial's frames
    |          - set DataPixx ADC/DAC schedules
    |          - init trial data
    |
    v
_run.m        (each trial -- frame-by-frame state machine)
    |          - trialBegun -> showFix -> waitForFix -> holdFixAndPlay -> reward
    |          - present noise frames at configured hold rate
    |          - monitor fixation each display frame
    |          - on fixation break: abort (do NOT advance movie index)
    |          - on successful completion: deliver reward, advance movie index
    |
    v
_finish.m     (after each trial)
    |          - retrieve spike data from Ripple via xippmex
    |          - if trial was successful: accumulate STA
    |          - update online STA display
    |          - save trial data to p struct
    |          - close PTB textures to free VRAM
    |
    v
    (loop back to _next.m)
```

### 3.2 Trial Timing

| Parameter | Default | Notes |
|---|---|---|
| `trialDurationS` | 3.0 | Duration of noise presentation per trial (seconds) |
| `fixWaitDur` | 5.0 | Max wait for fixation acquisition (seconds) |
| `fixWinWidthDeg` | 3.0 | Fixation window width (degrees) |
| `fixWinHeightDeg` | 3.0 | Fixation window height (degrees) |
| `rewardDurationMs` | 200 | Reward duration on successful trial (ms) |
| `timeoutAfterFixBreak` | 0.1 | Timeout after fixation break (seconds) |
| `postRewardDuration` | 0.1 | Post-reward period before trial end (seconds) |

### 3.3 Aborted Trial Handling

If fixation breaks during noise presentation:

1. The trial is marked as an error.
2. The noise movie index is NOT advanced -- the same frame range will be
   re-presented on the next trial.
3. A short timeout occurs before the next trial begins.
4. Spike data from the aborted trial is NOT included in the STA.

This ensures every noise frame is eventually shown during a successful
fixation epoch, maintaining complete stimulus coverage.

---

## 4. State Machine (`_run.m`)

### 4.1 States

| State | ID | Description |
|---|---|---|
| `trialBegun` | 1 | Strobe trial start, transition immediately |
| `showFix` | 2 | Show fixation point on gray background, wait for fixation |
| `holdFixAndPlay` | 3 | Present noise frames, monitor fixation, deliver reward on completion |
| `noiseComplete` | 21 | Noise presentation finished successfully |
| `fixBreak` | 11 | Fixation broken during noise |
| `nonStart` | 13 | Fixation never acquired |

### 4.2 State Transitions

```
trialBegun (1)
    |
    v
showFix (2)
    |-- eye in window --> holdFixAndPlay (3)
    |-- timeout ---------> nonStart (13)
    
holdFixAndPlay (3)
    |   [present noise frames, one per noiseFrameHold display frames]
    |   [monitor fixation every display frame]
    |-- all frames shown --> noiseComplete (21)  --> reward --> exit
    |-- eye leaves window --> fixBreak (11)       --> exit
```

### 4.3 Noise Frame Presentation Logic

Within `holdFixAndPlay`, the run loop iterates over display frames. A counter
tracks how many display frames the current noise frame has been shown. When
the counter reaches `noiseFrameHold`, the next noise texture is drawn.

```
frameCounter = 0;
noiseIdx = 1;  % index into this trial's texture array

while in holdFixAndPlay:
    % get eye/joy
    p = pds.getEyeJoy(p);

    % check fixation
    if ~pds.eyeInWindow(p)
        transition to fixBreak
    end

    % time for a new noise frame?
    frameCounter = frameCounter + 1;
    if frameCounter > noiseFrameHold
        frameCounter = 1;
        noiseIdx = noiseIdx + 1;
        if noiseIdx > nFramesThisTrial
            transition to noiseComplete
        end
    end

    % draw noise texture, clearing patch, fixation point
    % flip
```

The key timing constraint: the noise frame update must be phase-locked to the
display refresh. Using `Screen('Flip')` with a target time ensures this.

---

## 5. Online STA Computation

### 5.1 Algorithm

The spike-triggered average is computed as:

```
STA(x, y, tau) = (1/N) * sum_{i=1}^{N} S(x, y, t_i - tau)
```

where `N` is the total spike count, `t_i` is the time of the i-th spike, `tau`
is the temporal lag, and `S(x, y, t)` is the stimulus value at position
(x, y) at time t.

In practice, we maintain a running accumulator and spike count:

```
staAccum(x, y, tau) += S(x, y, t_i - tau)    for each spike i
spikeCount += 1
STA = staAccum / spikeCount
```

For luminance mode, `staAccum` is `[nChecksY, nChecksX, nLags]`.
For RGB mode, `staAccum` would be `[nChecksY, nChecksX, 3, nLags]`.

### 5.2 Clock Synchronization Strategy

The Ripple system has its own 30 kHz clock that is independent of the PLDAPS /
DataPixx clock. Rather than attempting to translate between clocks, we use
timing information exclusively from the Ripple clock:

1. **Stimulus onset strobe:** PLDAPS strobes a digital word (e.g., `noiseOn`)
   through DataPixx at noise onset. Ripple records the arrival time of this
   strobe in its own clock via digital input.

2. **Threshold crossings:** Ripple returns spike times in its own clock
   (samples / 30000 = seconds).

3. **Relative timing:** For each spike, compute:
   `t_relative = t_spike_ripple - t_noiseOn_ripple`

4. **Frame identification:** Given that noise frames update every
   `noiseFrameHold * frameDuration` seconds:
   `frameIdx = floor(t_relative / (noiseFrameHold * frameDuration)) + 1`

5. **Lag computation:** For each desired lag `tau` (in noise frames):
   `stimFrameAtLag = frameIdx - tau`
   Look up the stimulus values at that frame from the pre-generated movie
   matrix.

This approach requires that PLDAPS stores, for each trial, the mapping between
trial-local noise frames and their indices in the global movie matrix. This is
straightforward since each trial is a contiguous slice:
`globalFrameIdx = trialStartFrame + localFrameIdx - 1`.

### 5.3 Per-Trial STA Update (in `_finish.m`)

```matlab
% 1. Retrieve Ripple data
[~, spikeTimes, ~, ~] = pds.xippmex('spike', p.rig.ripple.recChans, 0);
[~, eventTimes, eventValues] = pds.xippmex('digin');

% 2. Find noiseOn event time in Ripple clock
noiseOnCode = p.init.codes.noiseOn;
noiseOnIdx = find([eventValues.parallel] == noiseOnCode, 1, 'last');
t_noiseOn = eventTimes(noiseOnIdx) / 30000;  % convert to seconds

% 3. For each channel to process:
for ch = 1:p.trVars.nChannels
    theseSpikes = spikeTimes{ch} / 30000;  % seconds, Ripple clock

    for s = 1:length(theseSpikes)
        t_rel = theseSpikes(s) - t_noiseOn;

        % which noise frame was on screen at this spike time?
        noiseFrameIdx = floor(t_rel / p.trVars.noiseFrameDurS) + 1;

        % skip if spike is outside the stimulus period
        if noiseFrameIdx < 1 || noiseFrameIdx > nFramesThisTrial
            continue;
        end

        % global frame index in the movie matrix
        globalIdx = p.trVars.trialStartFrame + noiseFrameIdx - 1;

        % accumulate STA at each lag
        for lagIdx = 1:p.trVars.nSTALags
            stimIdx = globalIdx - lagIdx + 1;
            if stimIdx >= 1
                stimFrame = p.init.noiseMovie(:, :, stimIdx);
                p.init.staAccum{ch}(:, :, lagIdx) = ...
                    p.init.staAccum{ch}(:, :, lagIdx) + double(stimFrame);
                p.init.staSpikeCount(ch) = p.init.staSpikeCount(ch) + 1;
            end
        end
    end
end
```

Note: The actual implementation may optimize this by vectorizing the spike
loop and/or pre-computing frame indices for all spikes at once.

### 5.4 STA Parameters

| Parameter | Default | Notes |
|---|---|---|
| `nSTALags` | 8 | Number of temporal lags to compute |
| `staLagFrames` | 1:8 | Lag values in noise frames (30-240 ms at 30ms/frame) |
| `nChannels` | 1 | Number of Ripple channels to process for STA |
| `channelList` | [1] | Which Ripple channels to use (indices into recChans) |

### 5.5 STA Display

A dedicated MATLAB figure with a simple GUI for viewing STAs:

**Layout:**
- **Top row:** Row of `nSTALags` heatmap subplots showing the STA at each
  temporal lag for the currently selected channel. Each subplot is labeled
  with its lag in ms. Color scale is symmetric around zero (blue = below
  mean, red = above mean).
- **Bottom row:** Controls
  - Channel selector (dropdown or numeric spinner)
  - Spike count display
  - "Auto-scale" toggle for color axis

**Update frequency:** After each successful trial.

**Multi-channel summary (optional, for multi-contact probes):** A separate
panel showing one small heatmap per channel at the peak lag, allowing the
experimenter to see at a glance which channels have clear RFs.

The display code will be in `supportFunctions/initSTADisplay.m` (create the
figure) and `supportFunctions/plotSTA.m` (update it).

---

## 6. Simulation / Test Function

### 6.1 Purpose

Before using the STA on real neural data, we need to validate that the
algorithm can recover a known stRF from simulated data. This test function
uses an LNP (Linear-Nonlinear-Poisson) model to generate "ground truth" spike
trains from a known RF, then feeds those spikes through the STA algorithm to
verify recovery.

### 6.2 LNP Model

The model has three stages:

1. **Linear filter (L):** Convolve the stimulus with a known stRF kernel
   `K(x, y, tau)` to produce a generator signal `g(t)`.

2. **Nonlinearity (N):** Pass `g(t)` through a static nonlinearity to produce
   an instantaneous firing rate `r(t) >= 0`.

3. **Poisson spike generation (P):** At each time bin, draw a spike count from
   a Poisson distribution with rate `r(t) * dt`.

### 6.3 Ground-Truth stRF Construction

A realistic LGN-like stRF consists of:

**Spatial component:** Difference-of-Gaussians (center-surround):

```
K_spatial(x, y) = A_c * exp(-(x^2 + y^2) / (2 * sigma_c^2))
                - A_s * exp(-(x^2 + y^2) / (2 * sigma_s^2))
```

where `sigma_c` is the center radius, `sigma_s` is the surround radius
(typically 3-5x `sigma_c`), and `A_c > A_s`.

**Temporal component:** Biphasic kernel (difference of two alpha functions):

```
K_temporal(tau) = (tau/t1)^n * exp(-n*(tau/t1 - 1))
                - w * (tau/t2)^n * exp(-n*(tau/t2 - 1))
```

where `t1` is the excitatory peak latency (~25 ms for M cells, ~40 ms for P
cells), `t2` is the inhibitory peak latency (~50-70 ms), and `w` is the
inhibitory weight.

**Full stRF:** `K(x, y, tau) = K_spatial(x, y) * K_temporal(tau)` (space-time
separable).

### 6.4 Simulation Procedure

```matlab
function results = testSTA(params)
% testSTA  Validate STA recovery using LNP simulation.
%
%   results = testSTA(params)
%
%   params fields:
%     .checkSizeDeg      - check size (degrees), default 0.5
%     .noiseFrameHoldMs  - noise frame duration (ms), default 30
%     .movieDurationS    - total movie duration (seconds), default 300
%     .rfCenterDeg       - [x, y] RF center (degrees), default [5, 3]
%     .rfSigmaCenterDeg  - center Gaussian sigma (degrees), default 0.3
%     .rfSigmaSurrDeg    - surround Gaussian sigma (degrees), default 1.0
%     .rfSurrWeight       - surround weight, default 0.5
%     .rfExcPeakMs       - excitatory peak latency (ms), default 30
%     .rfInhPeakMs       - inhibitory peak latency (ms), default 60
%     .rfInhWeight        - inhibitory temporal weight, default 0.5
%     .baseRate           - baseline firing rate (spk/s), default 5
%     .peakRate           - peak driven rate (spk/s), default 50
%     .trialDurationS    - trial duration (seconds), default 3
%     .nChannels          - number of simulated channels, default 1

% Steps:
%   1. Generate noise movie matrix (same algorithm as the task)
%   2. Build ground-truth stRF K(x,y,tau)
%   3. For each time bin:
%      a. Compute g(t) = sum_{tau} sum_{x,y} K(x,y,tau) * S(x,y,t-tau)
%      b. Compute r(t) = baseRate + peakRate * exp(g(t)) / (1 + exp(g(t)))
%         (sigmoid nonlinearity, ensures positive rates)
%      c. Draw spike count ~ Poisson(r(t) * dt)
%   4. Collect spike times
%   5. Simulate trial structure (segment movie into trials)
%   6. Run STA accumulation using the same updateSTA function
%   7. Compare recovered STA to ground-truth K
%   8. Report: correlation, peak location, temporal profile

% Outputs:
%   results.groundTruth    - the true stRF kernel
%   results.recoveredSTA   - the recovered STA
%   results.correlation    - spatial correlation at peak lag
%   results.nSpikes        - total spike count
%   results.convergenceCurve - STA quality vs. number of spikes
```

### 6.5 Validation Criteria

The test should verify:

1. **Spatial accuracy:** The peak of the recovered STA is at the correct
   spatial location (within 1 check of the true RF center).
2. **Temporal accuracy:** The temporal profile of the STA at the peak spatial
   location matches the shape of the true temporal kernel.
3. **Convergence:** The STA quality (spatial correlation with ground truth)
   increases monotonically with spike count and approaches 1.0.
4. **Unbiasedness:** The STA converges to the true kernel regardless of the
   nonlinearity used (a key property of white-noise stimuli).

### 6.6 Importance

This test function should be built and validated BEFORE implementing the real
PLDAPS task. It serves as the development platform for the core STA algorithm
(`updateSTA.m`) and display code (`plotSTA.m`), which can be developed and
debugged entirely offline without needing the rig hardware.

---

## 7. PLDAPS Integration Details

### 7.1 File List

| File | Type | Description |
|---|---|---|
| `rfMap_settings.m` | Quintet | All parameters, states, trial variables, strobe list |
| `rfMap_init.m` | Quintet | One-time setup: rig, DataPixx, Ripple, noise movie generation, STA init, display init |
| `rfMap_next.m` | Quintet | Per-trial: slice noise chunk, create PTB textures, set schedules, init trial data |
| `rfMap_run.m` | Quintet | State machine: fixation acquisition, noise presentation, reward |
| `rfMap_finish.m` | Quintet | Post-trial: retrieve Ripple data, accumulate STA, update display, save data, close textures |
| `supportFunctions/generateNoiseMovie.m` | Support | Pre-generate full noise matrix with RNG seed |
| `supportFunctions/generateNoiseTextures.m` | Support | Create PTB textures for one trial's worth of noise frames |
| `supportFunctions/updateSTA.m` | Support | Spike-triggered accumulation given spikes + frame indices |
| `supportFunctions/plotSTA.m` | Support | Update online STA display |
| `supportFunctions/initSTADisplay.m` | Support | Create the STA figure/GUI with channel selector |
| `supportFunctions/testSTA.m` | Support | LNP simulation to validate STA recovery |
| `supportFunctions/buildGroundTruthRF.m` | Support | Construct a parameterized stRF kernel |
| `supportFunctions/nextParams.m` | Support | Set per-trial parameters (frame range, etc.) |
| `supportFunctions/initTrialStructure.m` | Support | Define trial array structure |
| `supportFunctions/initTrData.m` | Support | Initialize per-trial data fields |

### 7.2 Data Stored in `p` Structure

**`p.init` (set once in `_init.m`):**

| Field | Description |
|---|---|
| `p.init.noiseMovie` | Pre-generated noise matrix `[nY, nX, nFrames]` (uint8) |
| `p.init.noiseRngSeed` | RNG seed used for movie generation |
| `p.init.noiseGridSize` | `[nChecksY, nChecksX]` |
| `p.init.nNoiseFrames` | Total frames in movie |
| `p.init.noiseFrameIdx` | Current playback position in movie (advances on successful trials) |
| `p.init.staAccum` | Cell array `{nChannels}`, each `[nY, nX, nLags]` double |
| `p.init.staSpikeCount` | `[nChannels, 1]` spike counts per channel |
| `p.init.staFigHandle` | Handle to online STA display figure |
| `p.init.codes` | Strobe codes (loaded from `pds.initCodes`) |

**`p.trVars` (set per trial in `_next.m`):**

| Field | Description |
|---|---|
| `p.trVars.trialStartFrame` | First frame index (in global movie) for this trial |
| `p.trVars.trialEndFrame` | Last frame index for this trial |
| `p.trVars.nFramesThisTrial` | Number of noise frames this trial |
| `p.trVars.noiseFrameDurS` | Duration of one noise frame in seconds |
| `p.trVars.noiseTextures` | Array of PTB texture handles for this trial |

**`p.trData` (collected during trial):**

| Field | Description |
|---|---|
| `p.trData.timing.trialStartPTB` | Trial start time (PTB clock) |
| `p.trData.timing.noiseOn` | Noise onset time (PTB clock, via postFlip) |
| `p.trData.timing.noiseOff` | Noise offset time (PTB clock) |
| `p.trData.timing.fixOn` | Fixation point onset time |
| `p.trData.timing.fixAq` | Fixation acquisition time |
| `p.trData.timing.reward` | Reward delivery time |
| `p.trData.timing.fixBreak` | Fixation break time (if applicable) |
| `p.trData.spikeTimes` | Spike times from Ripple (seconds, Ripple clock) |
| `p.trData.eventTimes` | Event times from Ripple (seconds, Ripple clock) |
| `p.trData.eventValues` | Event values from Ripple (strobe codes) |
| `p.trData.noiseFrameFlipTimes` | Actual flip times of each noise frame (PTB clock) |

### 7.3 Strobe Codes

New codes to add to `+pds/initCodes.m`. These follow the existing convention
where task-specific codes are in the 16000+ range. We will use codes starting
at 16100 to avoid collision with existing conflict_task codes (16020-16036).

| Code Name | Value | Description |
|---|---|---|
| `noiseOn` | 16101 | First noise frame onset |
| `noiseOff` | 16102 | Last noise frame offset / noise presentation complete |
| `noiseCheckSize_x100` | 16103 | Check size in degrees * 100 |
| `noiseFrameHold` | 16104 | Number of display frames per noise update |
| `noiseColorMode` | 16105 | 1 = luminance, 2 = rgb |
| `noiseRngSeed` | 16106 | RNG seed (lower 16 bits) |
| `noiseRngSeedHigh` | 16107 | RNG seed (upper 16 bits) |
| `noiseTrialFrameStart` | 16108 | Starting frame index in movie (this trial) |
| `noiseTrialFrameEnd` | 16109 | Ending frame index in movie (this trial) |
| `noiseTotalFrames` | 16110 | Total frames in movie (lower 16 bits) |
| `noiseGridW` | 16111 | Noise grid width (number of checks) |
| `noiseGridH` | 16112 | Noise grid height (number of checks) |

Note: strobe values are limited to 15 bits (0-32767) on most systems. For
values exceeding this (e.g., RNG seed, large frame counts), we split into
high/low 16-bit words, or use offsets as needed.

### 7.4 `_init.m` Sequence

```
1.  p = pds.initRigConfigFile(p);          % rig geometry, deg2pix
2.  p = initClut(p);                        % color LUT
3.  p = pds.initDataPixx(p);               % DataPixx hardware
4.  p = pds.initAudio(p);                  % audio feedback
5.  p = initTrialStructure(p);             % trial array (minimal for this task)
6.  p = pds.initRipple(p);                 % Ripple connection
7.  p = generateNoiseMovie(p);             % pre-generate full noise matrix
8.  p = initSTAAccumulators(p);            % allocate STA arrays
9.  p = initSTADisplay(p);                 % create online display figure
10. p = plotWindowSetup(p);                % reposition MATLAB/GUI windows
```

### 7.5 `_next.m` Sequence

```
1.  p.status.iTrial = p.status.iTrial + 1;
2.  p.trVars = p.trVarsGuiComm;
3.  p = nextParams(p);                     % set frame range, check completion
4.  p = initTrData(p);                     % initialize trial data fields
5.  p = generateNoiseTextures(p);          % create PTB textures for this trial
6.  p = pds.setSchedules(p);              % start DataPixx ADC schedules
7.  pds.startEphysAndSchedules;
```

### 7.6 `_finish.m` Sequence

```
1.  p = pds.getEyeJoy(p);                 % final eye/joy sample
2.  p = pds.getRippleData(p);             % retrieve spikes + events
3.  if trial was successful (noiseComplete state):
        p = updateSTA(p);                  % accumulate STA
        plotSTA(p);                         % update display
4.  p = pds.strobeTrialData(p);           % strobe end-of-trial codes
5.  p = pds.storeDataInPDS(p);            % save trial data
6.  Close PTB textures (p.trVars.noiseTextures)
7.  Update status display (trial counts, etc.)
```

---

## 8. Implementation Order

The implementation should proceed in this order, with each phase tested before
moving to the next:

### Phase 1: Simulation and STA Validation (no hardware needed)

1. **`buildGroundTruthRF.m`** -- Parameterized center-surround spatial +
   biphasic temporal kernel.
2. **`generateNoiseMovie.m`** -- Noise matrix generation with RNG seed. Can be
   tested standalone.
3. **`updateSTA.m`** -- Core STA accumulation function. Takes spike times,
   event times, frame indices, and noise matrix; returns updated accumulators.
4. **`testSTA.m`** -- Full LNP simulation pipeline. Validates that `updateSTA`
   recovers the ground-truth RF.
5. **`plotSTA.m`** and **`initSTADisplay.m`** -- Online display code. Can be
   tested with simulated data from `testSTA`.

**Exit criterion:** `testSTA` demonstrates clean recovery of a known stRF with
realistic parameters (0.5 deg checks, 30 ms frames, ~20 spk/s, 5-10 min of
data).

### Phase 2: PLDAPS Task Skeleton (hardware needed for testing)

6. **`rfMap_settings.m`** -- All parameters, states, strobe list.
7. **`rfMap_init.m`** -- Full initialization including noise movie generation.
8. **`rfMap_next.m`** -- Trial preparation with texture generation.
9. **`rfMap_run.m`** -- State machine (fixation + noise presentation).
10. **`rfMap_finish.m`** -- Data retrieval and STA update.
11. **`+pds/initCodes.m`** -- Add new strobe codes.

**Exit criterion:** Task runs on the rig, presents noise, delivers reward on
fixation, and saves trial data. Can be tested without Ripple by disabling
the STA update.

### Phase 3: Online STA Integration

12. Integrate `updateSTA` into `_finish.m` with real Ripple data.
13. Verify clock synchronization with a known stimulus-response relationship
    (e.g., photodiode + Ripple analog input, or audio click + neural response).
14. Test with live recording.

**Exit criterion:** Online STA shows clear RF structure from real LGN units.

---

## 9. Open Questions / Future Enhancements

- **RGB STA display:** When RGB mode is enabled, display code will need to
  show 3 heatmaps per lag (R, G, B channels). Deferred to after achromatic
  mode is validated.

- **Epoch-based generation:** If runs longer than ~15 minutes are needed at
  small check sizes, implement generation in epochs (generate next epoch's
  noise during a brief pause) rather than pre-generating the entire movie.

- **Cortical magnification warping:** The Feng code includes a log-polar warp
  mode that scales check size with eccentricity. This could be added later
  but complicates STA interpretation. Deferred.

- **STA significance testing:** Bootstrap or shift-predictor methods to assess
  whether an STA is significantly different from noise. Could be added to the
  display as a p-value or confidence contour.

- **Multiple unit STAs:** If online sorting becomes available on Ripple, extend
  to compute separate STAs per sorted unit.

- **Gaussian fit to STA:** Automatically fit a 2D Gaussian to the peak spatial
  STA to estimate RF center and size. Display fit parameters.

---

## 10. References

- Feng Wang et al. (Netherlands Institute for Neuroscience) -- reference
  code for LGN RF mapping with dense/sparse noise, checkerboards, and
  sweeping bars. Located at `/home/herman_lab/Downloads/feng_LGN/`.

- Jeffries, A. M., Killian, N. J., & Pezaris, J. S. (2014). Mapping the
  primate lateral geniculate nucleus: A review of experiments and methods.
  *Journal of Physiology - Paris*, 108(1), 3-10.

- Chichilnisky, E. J. (2001). A simple white noise analysis of neuronal light
  responses. *Network: Computation in Neural Systems*, 12(2), 199-213.
  (Foundational reference for STA methodology.)
