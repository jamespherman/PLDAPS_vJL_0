# LGN RF-Mapping Battery Redesign — Implementation Plan

**Author:** J. Herman (with Claude)
**Date:** 2026-07-28
**Basis:** Offline analysis of the 2026-06-08 LGN session
(`chen-data-analysis/report/LGN_20260608_presentation.pdf`) plus the derived
per-channel results in `chen-data-analysis/results/per_channel_summary.csv`.
**Status:** Independently code-reviewed 2026-07-28; review findings folded in
(inline notes tagged *[review]*).

---

## 0. Motivation & summary

The 2026-06-08 session mapped one 64-channel LGN penetration five ways
(checkerboard, barsweep, denseChromatic, denseAchromatic, sparse) in ~1 hour.
The offline analysis showed:

- **Moving-bar sweeps (barsweep) mapped RFs far more reliably than white-noise
  STA** (22 reliable centers vs 10 marginal STA detections at 2° checks).
- The current **online barsweep RF estimator is the wrong method**: it pools
  opposite sweep directions by orientation, assumes a fixed response latency,
  and reads the center from a moment/centroid — the "estimator artifact" that
  corrupts the azimuth map. The collaborator's method (and Supèr & Roelfsema
  2005, *Prog. Brain Res.* 147) instead fits **each direction separately** and
  takes the **midpoint of opposite-sweep peaks**, which cancels latency without
  assuming it and yields the latency for free from the peak separation.
- White-noise STA under-resolved LGN RFs because checks were too coarse (2°),
  frames too slow (~83 ms can't resolve the ~30 ms LGN latency), and noise was
  spread over the whole screen instead of tiled over the RFs.
- Both barsweep and rfMap **"run away"** after their target trial count —
  the command window floods and trial counters spin because the loop is not
  reliably stopped.
- Color/contrast cell-typing (DKL STA + reversing checkerboard) is sound in
  principle but under-powered (near the noise floor / drive-limited).

This plan implements four workstreams:

1. **Barsweep RF method** → collaborator's latency-free midpoint estimator
   (cardinal-4 regime only), with a selectable threshold-crossing / MUAE signal
   source.
2. **Barsweep → rfMap STA handoff** → STA noise tiled in a single robust window
   over the high-SNR barsweep RF centers, with finer checks and faster frames.
3. **No runaway** → clean auto-stop when the target trial count is reached
   (both tasks).
4. **Cell-typing** → checkerboard contrast set refined for low-contrast gain,
   denseChromatic RF-centered, plus a cross-session magno/parvo/konio readout.

### Locked design decisions (from the planning discussion)

| Topic | Decision |
|---|---|
| Barsweep RF method scope | **cardinal4 only**; rfmap12 (12-dir iradon) untouched |
| Estimator | Per-direction Gaussian/DoG fits; **az = midpoint(0°,180°), el = midpoint(90°,270°)**; latency from peak separation; **no assumed-latency subtraction** |
| Reliability | **SNR threshold ~4.0–4.2**; no permutation test online |
| Signal source | **Selectable** `crossings` (default) or `muae` (attempt-and-warn) |
| Fit timing | **Two-tier**: cheap smoothed-PSTH peaks live (all ch) + selected-ch live fit; **full 4×64 fits deferred** to session-end / on-demand (feeds export) |
| Handoff | **Optional** file-based CSV; no file ⇒ current full/hemifield window |
| STA window | **Single robust trimmed union** (median ± ~2·MAD of SNR≥thresh centers), displaced from fixation, size-capped |
| STA checks | **1.0°** default (2.0° fallback) |
| STA frame rate | **Every frame (~120 Hz)**; `noiseFrameHold=1`; **~12 lags** |
| STA run cap | **≤10 min** |
| Occlusion | Displace window + drop clearing patch when window clears fixation + keep `occludedCheckMask` backstop |
| Stop behavior | **Auto-stop** (robust `runButton.Value=false` + defensive throttle) |
| Checkerboard spatial | **Unchanged** (full-screen); no centering |
| Checkerboard contrast | **`[0.125 0.25 0.5 1.0]`** |
| denseChromatic | RF-centered (via window); **single 0.45 DKL contrast unchanged** |
| Classifier | Cross-session post-hoc export (~0 runtime) |

### Grounding numbers (2026-06-08, from `per_channel_summary.csv`)

- **MU threshold-crossing rate on high-SNR channels:** median **~10 Hz**
  (achromatic), **~8 Hz** (chromatic), **~2.6 Hz** (sparse). sparse is
  spike-starved and will be the weakest STA variant.
- **High-SNR (≥4) barsweep centers:** raw union ≈ **17° × 16°** (outlier-heavy);
  robust box (median ± 2·MAD, keeps 12/15) ≈ **10° wide × 4° tall**, centered
  az −8.9°, el −0.4°. Confirms the window must be robustly trimmed, not a raw
  union, and is not a 6×6 square.

### Out of scope (explicitly deferred)

- Probe-geometry / depth logging by the tasks (wiring map lives in
  `tasks/sacc_to_phosph (WiP)/electrodeInfo.mat` for offline use).
- rfmap12 (12-direction iradon) changes.
- Permutation-based reliability.
- denseChromatic multi-contrast / finer color checks.
- Any checkerboard spatial change (centering/windowing) — argued moot without
  RF center/surround sizes.

---

## Implementation status (updated 2026-07-30)

Committed + pushed to `main`; **none yet validated on the rig** — see
`LGN_battery_redesign_test_log.md`.

| Item | Status | Commit |
|---|---|---|
| **Phase 1** — auto-stop (both tasks) + measured-refresh hardening | ✅ done | `cea9c31d` |
| **Phase 2 core** — barsweep cardinal4 midpoint method (crossings) + offline tests + export latency column | ✅ done | `44e4e016` (rebased `c4b143af`) |
| Phase 2 viz — 4-panel per-direction PSTH display (plotBarsweepRF + browser) | ⬜ pending | — (task runs now via backward-compat fields) |
| **Phase 3** — MUAE selectable signal source | ⬜ pending | needs rig/Trellis continuous-stream validation |
| **Phase 4** — rfMap RF-restricted window + STA defaults + occlusion-mask fix + adequacy estimator | ⬜ pending | best built with a real Phase-2 export CSV in hand (calibrates `rfWindowSnrThresh`) |
| **Phase 5** — checkerboard contrast set `[0.125 0.25 0.5 1.0]` + RF-centered denseChromatic + cross-session classifier | ⬜ pending | checkerboard settings file is actively co-edited; do as one unit |

Sequencing note: Phase 4's window-selection threshold is calibrated from the
Phase-2 barsweep SNR distribution (test-log item 2.5 asks for a sample CSV), so
Phase 4 is deliberately staged after a Phase-2 rig check.

---

## 1. Change 1 — Barsweep RF method (cardinal4)

### 1.1 What's wrong today

- `initBarsweepRF.m:57-67,105-106` allocates `spikeHist [nOri × nPosBins × nCh]`
  with `nOri = 2` for cardinal4 (orientations 0°, 90°). Opposite directions are
  **structurally pooled** by `thetaOri = mod(thetaMotion, pi)`
  (`accumulateBarsweepRF.m:45-58`), destroying the per-direction peaks the
  midpoint method needs.
- `accumulateBarsweepRF.m:159` subtracts a **fixed assumed latency**
  (`rf.latencyMs`, default 40 ms) from spike times before binning.
- `reconstructBarsweepRF.m:156-216` (cardinal4) reads the center from a
  `parabolicPeak` on pooled marginals plus a `momentFit2D` on the separable
  outer-product thumbnail — the moment/centroid the analysis flagged as the
  azimuth-corrupting artifact.

### 1.2 Target method (Xing / Supèr-Roelfsema)

- **Accumulate by direction** (`nDir = 4`), not orientation — but **only the
  storage key changes.** *[review]* The position coordinate must **still** be
  projected onto the **orientation** axis `mod(θ, π)` exactly as
  `accumulateBarsweepRF.m:44-48` does today
  (`s_perFrame = projAxis'·relCenter`, `projAxis = [cos(mod(θ,π)); sin(mod(θ,π))]`).
  Do **not** project onto the full direction vector: if you do, the 180° profile
  sign-flips, its peak becomes `−s_RF + Lv`, and `midpoint = Lv` — every RF is
  silently pinned at `±latency·speed` from path center (a plausible-looking
  bug where all RFs cluster at path center). The change is one line: store into
  a **direction** row (`dirIdx`) instead of an **orientation** row (`oriIdx`);
  the projection math is untouched. Each of 0°, 90°, 180°, 270° then owns a
  rate-vs-position profile per channel.
- **No latency subtraction.** Bin each spike at the true bar position at
  `(t_spike − stimOn)`. The midpoint of opposite-direction peaks cancels
  latency; subtracting an assumed latency would double-correct.
- **Trailing-edge caveat.** *[review]* With latency subtraction gone, each
  direction's peak sits at `s_RF ± L·v` (shifted in the motion direction). For
  the 2026-06-08 geometry that shift is ≈0.6° (L≈30 ms, v=20°/s) against a 40°
  path centered at −17° with RFs near az −8.9°, so peaks stay well inside the
  covered range. Keep `accumMarginDeg` and ensure the sweep path extends ≥`L·v`
  beyond the expected RF cluster so a peak near a sweep extreme is not
  truncated. We do **not** extend the spike keep-window past `visibleEnd` — the
  bar position is undefined there; the margin belongs in the sweep *path*, not
  the accumulation window.
- **Per axis:**
  - Smoothed PSTH → peak (live, cheap).
  - Gaussian/DoG fit → fitted peak (final).
  - **az center = midpoint(peak@0°, peak@180°)**, **el center =
    midpoint(peak@90°, peak@270°)**, both in path-center-relative dva, then add
    `pathCenterDeg` back for absolute.
  - **Latency (per axis) = |peak@θ − peak@(θ+180°)| / (2·speedDegPerSec)** →
    report in ms; flag if implausible (>100 ms or negative) but do not gate on
    it.
- **SNR** per axis as today (`profileSNR`-style peak-to-noise on the smoothed
  profile), detection when `min(snrAz, snrEl) ≥ rfDetectThresh`
  (default 4.0, tunable 4.0–4.2).

### 1.3 Two-tier estimation (performance)

Running 4 × 64 = 256 nonlinear fits per trial would eat the ITI. Instead:

- **Live, every trial, all channels:** smoothed PSTH per direction (already
  computed for display) → **parabolic-interpolated peak** → midpoint + SNR.
  Vectorized; ≪10 ms.
- **Live, every trial, selected channel only:** full 4-direction Gaussian/DoG
  fit (4 fits) so the detail panel shows real fit quality for the inspected
  channel.
- **Deferred (session-end auto + on-demand GUI action):** full 256
  Gaussian/DoG fits. These fitted peaks are the **authoritative** centers used
  by the export and the rfMap handoff — not the live smoothed peaks.

### 1.4 Signal source: threshold crossings vs MUAE (selectable)

- New setting `p.trVarsInit.rfSignalSource = 'crossings' | 'muae'`
  (default `'crossings'`). May also be surfaced as separate settings files
  (`barsweep_cardinal4_settings.m` vs `barsweep_cardinal4_muae_settings.m`) that
  set this field.
- **`crossings`:** unchanged path — `pds.getRippleData` →
  `xippmex('spike', recChans, 0)` threshold crossings, `spikeClusters` = channel.
- **`muae`:** per trial, pull a continuous high-frequency band anchored to
  `stimOn` via a new `pds.getRippleContinuous` (`xippmex('cont'/'contdata', …)`),
  then compute the MUAE envelope in MATLAB per Supèr-Roelfsema:
  **Filt1 band-pass 750–5000 Hz → full-wave rectify (abs) → Filt2 low-pass
  <500 Hz**, downsample. *[review]* This is a **distinct accumulation path**,
  not the per-spike one: bin each downsampled envelope **sample** by the bar
  position at that sample's time (`s_perFrame` interpolated to the sample clock),
  sum envelope amplitude per position bin, and divide by the same per-bin dwell
  — a per-sample `accumarray`, not the per-spike `discretize→accumarray` at
  `accumulateBarsweepRF.m:179-199`. Downsample Filt2 output enough (e.g. to
  1–2 kS/s) that per-trial binning of 64 ch stays cheap.
  - **Attempt-and-warn:** if no continuous stream is available/configured on
    Trellis, print a clear warning and **fall back to `crossings`** for that
    session. (This is the one hardware dependency I cannot verify from code —
    online MUAE requires Trellis to record/buffer a 30 kS/s hi-freq or raw
    continuous stream; the 64-ch × 30 kS/s transfer + filtering cost is the
    practical risk.)
- **Accumulator generalization (NOT just a rename).** *[review]* Storage does
  generalize (`spikeHist` → `responseHist`, holding counts *or* summed
  envelope, with `rate = responseHist ./ dwellTime`), but the **SNR/noise model
  must fork by source.** `profileSNR` (`reconstructBarsweepRF.m:280-290`) mixes
  a MAD floor with a **Poisson shot-noise** term `sqrt(meanOff/medDwell)` that
  is valid **only for spike counts**; fed envelope amplitude it injects a
  meaningless floor and the SNR≥4 gate becomes arbitrary. For `muae`, use an
  envelope-appropriate floor (MAD-only, or the off-peak envelope variance) —
  the Supèr-Roelfsema Sp/(Pe−Sp) normalization is the natural fit. Keep
  `spikeCount` (crossings) / `envelopeSum` (MUAE) as the per-channel drive gate.

### 1.5 Visualization

Replace the current 1D-marginals + separable-thumbnail detail panel with the
collaborator's **4-direction PSTH panels** per channel:

- One sub-panel per direction (0°, 180°, 90°, 270°): smoothed PSTH (color trace),
  Gaussian/DoG fit (black), fitted-peak tick.
- Midpoint markers on the azimuth (0°/180°) and elevation (90°/270°) pairs; RF
  center, SNR, and implied latency in the title.
- **High-SNR (detected) channels drawn bold** in the all-channel browser;
  low-SNR channels faint.

### 1.6 Files touched

- `tasks/barsweep/supportFunctions/initBarsweepRF.m` — re-key accumulator by
  direction; generalize array names; keep rfmap12 branch as-is. **Add
  `rf.formatVersion`** *[review]* (the struct today carries `resetCount` but no
  schema version, unlike rfMap's `sessionFormatVersion`); bump it for the
  direction re-key so loaders can branch.
- `.../accumulateBarsweepRF.m` — per-direction accumulation; drop latency
  subtraction; MUAE envelope path; keep off-screen / fixBreak truncation.
- `.../reconstructBarsweepRF.m` — new cardinal4 midpoint reconstruction (cheap
  peak + full fit paths); latency from peak separation; leave rfmap12 branch.
- `.../plotBarsweepRF.m`, `.../initBarsweepChannelBrowser.m`,
  `.../updateBarsweepChannelBrowser.m` — 4-direction panels + bold high-SNR.
- `tasks/barsweep/barsweep_finish.m` — live cheap update; end-of-session full
  fit; MUAE continuous pull hook. *[review]* **Remove `rfLatencyMs` from the
  reset-trigger set** in `barsweepRF_detectAndReset` (`barsweep_finish.m:288`):
  once latency subtraction is dropped the knob no longer affects the histogram,
  so nudging it in the GUI must not wipe the accumulator.
- `+pds/getRippleData.m` (+ new `+pds/getRippleContinuous.m`) — MUAE stream.
- `+pdsActions/exportBarsweepRFCentersCSV.m` — use deferred full fits + midpoint;
  add a `latency_ms` column alongside `channel,x_deg,y_deg,snr`. *[review]*
  Branch on `rf.formatVersion` when loading a `<sessionId>_barsweepRF.mat`
  sidecar (`exportBarsweepRFCentersCSV.m:69-77`): legacy (nOri=2) sidecars must
  route to the old reconstruction, not silently mis-index the new nDir=4 code.
  Decide + document whether legacy sidecars are reprocessable with the new
  midpoint method (they lack per-direction histograms, so generally **no** —
  they can only be read with the legacy estimator).
- `tasks/barsweep/barsweep_cardinal4_settings.m` (+ optional `_muae` variant) —
  `rfSignalSource`, MUAE filter params, keep `rfDetectThresh`. *[review]* The
  `barsweepRfLatency` strobe (`..._settings.m:366`) becomes misleading once
  accumulation ignores it — either drop it or relabel its intent as
  "assumed latency (unused in v2 accumulation)".
- `+pds/initCodes.m` — any new strobe fields (e.g. `barsweepSignalSource`).
- `.../decodeRippleEvents.m`, `.../validateBarsweepSession.m`,
  `.../testBarsweepRF.m`, `.../rebuildBarsweepRFFromTrials.m` — update for the
  direction-keyed accumulator + new params.

### 1.7 Acceptance criteria

- Synthetic two-peak test: opposite-direction profiles with a known RF center
  and injected latency ⇒ recovered center within one position bin and recovered
  latency within tolerance, **independent of the injected latency**. *[review]*
  Also inject **asymmetric forward/backward gain** and assert the recovered
  center is the true `s_RF` and **not** at path center (0) — this is the guard
  that catches the projection-sign trap from §1.2.
- rfmap12 regime unchanged (regression test on its iradon path).
- `crossings` and `muae` paths produce comparable centers on shared synthetic
  input; MUAE falls back cleanly with a warning when no continuous stream.
- Live all-channel refresh stays well within the ITI (no per-trial nonlinear
  fits except the one selected channel).

---

## 2. Change 2 — Barsweep → rfMap STA handoff (RF-restricted window)

### 2.1 Handoff & ingestion

- **Optional** file-based CSV `channel,x_deg,y_deg,snr[,latency_ms]`
  (produced by `exportBarsweepRFCentersCSV`), fixation-relative dva.
- New setting `p.trVarsInit.barsweepRFCsv` (explicit path, or a directory to
  auto-select the latest `rfCenters_*_final.csv`). rfMap reads it in
  `rfMap_init.m` **before** `generateStimForTask`.
- **If absent/empty/unreadable ⇒ current behavior** (full or `stimHemifield`
  window). This keeps the two sessions fully decoupled.

### 2.2 Window construction (robust trimmed union)

New helper `tasks/rfMap/supportFunctions/importBarsweepRFWindow.m`:

1. Keep channels with `snr ≥ rfWindowSnrThresh` (default 4.0) and finite center.
2. Robust center = `median(x), median(y)`; spread = `1.4826·MAD` per axis.
3. Keep channels within `median ± k·MAD` (k default 2) — drops eccentric
   outliers.
4. Window = padded bounding box of kept centers (`+rfWindowPadDeg`, ~1–2°),
   clamped to `[rfWindowMinDeg, rfWindowMaxDeg]` (e.g. 3°…12°).
5. Assert the window edge stays clear of fixation by `rfWindowFixMarginDeg`;
   if the cluster is foveal enough that the window would include fixation, keep
   the clearing patch + mask (see §2.4).
6. Degenerate cases: fall back to the default window and warn. *[review]* This
   must also catch **MAD = 0** (≤2 channels, or near-identical centers), which
   collapses the `median ± k·MAD` box to zero width — apply the
   `rfWindowMinDeg` clamp (step 4) **before** the bounding-box is used, so a
   zero-width trim can never reach the renderer.

Set `p.init.noiseGridCenterPix` and `p.init.noiseGridSize` from this window,
replacing the full/half-screen computation in `rfMap_init.m` `generateStimForTask`
(lines 173-275). `nextParams.m:81-92` already centers the destination rect on
`noiseGridCenterPix`, so per-trial rendering follows automatically.

> **Units** *[review]*: the CSV centers are **fixation-relative dva**;
> `noiseGridCenterPix` is **screen pixels**. `importBarsweepRFWindow` must
> convert via `pds.deg2pix` **and add the fixation pixel offset** — fixation
> (`fixDegX/Y`) is not necessarily screen center, so a bare `deg2pix` would
> place the window relative to the wrong origin.

### 2.3 STA parameter defaults (STA variants only — not checkerboard)

- `checkSizeDeg = 1.0` (fallback 2.0; operator knob). *(2× finer than today's 2°,
  4× cheaper than 0.5° in spike budget.)*
- `noiseFrameHold = 1` ⇒ present every monitor frame (~120 Hz), sourced from the
  **measured** refresh (see §2.5). Skip the current
  `noiseTargetUpdateHz → noiseFrameHold` derivation, or set
  `noiseTargetUpdateHz = refresh`.
- `nSTALags ≈ 12` (span 0–~100 ms; up from 8) so the latency peak is resolved
  and the STA can be read at its **peak lag**.
- `movieDurationMin ≤ 10` (already the default) — the run cap. *[review]* Note
  this bounds **stimulus (on-screen) time**, i.e. movie cycles, **not
  wall-clock**: fixation breaks + ITIs make the session longer. Keep this
  consistent with the adequacy estimator, which correctly counts accumulated
  **fixation** time.
- **Live adequacy estimator** (in `nextParams.m` / `rfMap_finish.m`): from the
  observed per-channel crossing rate, print expected spikes/channel
  (`rate × accumulated fixation time`) and **warn** if a target (e.g. a few
  thousand spikes) won't be reached within 10 min at the chosen `checkSizeDeg`.
- **Texture cost (re-diagnosed)** *[review]*: the "72k-frame memory bank" worry
  was wrong. `p.init.noiseMovie` stores the **check grid**
  (`nChecksY×nChecksX×nFrames`, `rfMap_init.m:217`), not a pixel bitmap, and
  `nextParams.m:33-38` already wraps/cycles it — the movie *is* the bounded
  bank, and with RF-restriction the grid collapses to ~tens of checks, so the
  array stays trivial even at 120 Hz × 10 min. The genuine cost is the per-trial
  **`Screen('MakeTexture')` count in the ITI** (`generateNoiseTextures.m:59-73`,
  one texture per frame per trial), which **doubles with frame rate** and grows
  with finer checks. Watch ITI upload latency, not GPU memory; if the ITI
  tightens, reuse a pre-uploaded texture ring rather than rebuilding per trial.

> **Expectation-setting (not a design change):** at ~9 Hz and a 10-min cap the
> **spike budget is the binding constraint**, not the window. RF-restriction and
> finer checks do not add spikes; the real gains are (a) affording finer checks +
> centering, and (b) resolving the latency so the STA is read at its peak lag.
> The adequacy estimator surfaces when 10 min is insufficient; 2.0° is the
> safe fallback. sparse (~2.6 Hz) may not clear threshold in 10 min.

### 2.4 Occlusion

- When the window clears fixation: set `clearPatchDeg = 0` (no patch drawn over
  noise), and `occludedCheckMask` (`occludedCheckMask.m:32-35`) returns
  all-false — a no-op. `applyOccludedMask` stays wired unconditionally as a
  backstop.
- When the window is foveal enough to include/touch fixation: keep the clearing
  patch **and** the mask (current merged behavior).
- **Fix the mask geometry so the backstop is real, not accidentally-inert.**
  *[review]* `occludedCheckMask.m:39-44` builds check-center coordinates as if
  the grid center is screen middle and compares against `(fixDegX,fixDegY)`.
  Once the RF window displaces `noiseGridCenterPix`, that assumption is false —
  in the one case where the mask actually matters (foveal cluster, patch on),
  it would flag the **wrong** checks. Pass `noiseGridCenterPix` into
  `occludedCheckMask` and offset the check-center grid by it, so the mask is
  correct under a displaced window rather than only safe because
  `clearPatchDeg=0` disables it.

### 2.5 Refresh-rate fix (cross-cutting)

- `initPsychToolbox.m:34` / `initDataPixx.m:32` already override the rig config's
  hardcoded `refreshRate = 100` with the measured `FrameRate(window)`. Harden
  this: prefer `1/Screen('GetFlipInterval', window)` for precision and **log the
  measured rate**. *[review]* Do **not** hard-assert `== 120` — the checkerboard
  explicitly supports both 100 and 120 Hz rigs
  (`prepareStim_checkerboard.m:42-43,67-72`), so a `==120` gate would break a
  legitimate 100 Hz rig. Instead assert the measured rate is in the **supported
  set** and that `noiseFrameHold` yields the intended update rate on whatever
  the true refresh is. (The rig-config `refreshRate` edit below is then purely
  cosmetic, since the runtime value already comes from measurement.)
- Update the stale `p.rig.refreshRate = 100` in the live rig config
  (`+rigConfigFiles/rigA_20200203.m:25` and the active rig file) to 120 so the
  pre-override value isn't misleading.
- Ensure `noiseFrameHold`, STA lag timing, and the barsweep sweep timing all use
  the measured rate.

### 2.6 Files touched

- `tasks/rfMap/rfMap_init.m` — read CSV; build window; feed
  `generateStimForTask`; `nSTALags`; refresh sourcing.
- `.../supportFunctions/nextParams.m` — destRect from window; adequacy estimator.
- `.../supportFunctions/importBarsweepRFWindow.m` — **new** importer/window
  builder.
- `.../rfMap_commonSettings.m` — new params: `barsweepRFCsv`,
  `rfWindowSnrThresh`, `rfWindowKmad`, `rfWindowPadDeg`, `rfWindowMinDeg`,
  `rfWindowMaxDeg`, `rfWindowFixMarginDeg`, `checkSizeDeg = 1.0`,
  `noiseFrameHold = 1`, `nSTALags = 12`.
- `.../supportFunctions/generateNoiseTextures.m` — watch per-trial
  `Screen('MakeTexture')` count at 120 Hz (ITI latency); reuse a pre-uploaded
  texture ring if the ITI tightens (not a memory-bank problem — see §2.3).
- `.../rfMap_run.m` — conditional clearing patch.
- `.../supportFunctions/initSTAChannelBrowser.m` / `initSTADisplay*.m` —
  `imgExtentDeg` reflects the window.
- `+pds/initPsychToolbox.m`, `+rigConfigFiles/<active rig>.m` — refresh fix.

### 2.7 Acceptance criteria

- With a valid CSV, the noise field renders inside the computed window, off
  fixation, at 1.0° / 120 Hz; the browser extent matches.
- With no CSV, behavior is byte-for-byte the current full/hemifield path.
- Outlier channels (e.g. the 2026-06-08 eccentric ch5/6/26) are trimmed;
  degenerate inputs fall back with a warning.
- Adequacy estimator prints an expected-spikes/warn line each trial.

---

## 3. Change 3 — No runaway (auto-stop, both tasks)

### 3.1 Mechanism

The GUI loop's `while` header tests `uiData.p.runFlag` (`PLDAPS_vK2_GUI.m:491`),
which is set once and never flips; the **effective** stop is the
`if ~get(runButton,'Value'); break; end` at `PLDAPS_vK2_GUI.m:533-534`
*[review]*. There is **no WaitSecs throttle** between trials.
A task stops the session by driving that button false. Add a shared, robust
helper (e.g. `+pds/stopRunButton.m`):

```matlab
rb = findall(groot, 'Tag', 'runButton');
if ~isempty(rb), set(rb(1), 'Value', false); end   % rb(1) guards multi-handle
```

plus a **defensive `WaitSecs(0.05)`** in each task's done-gate so that even a
pathological failed break cannot spin faster than ~20 Hz.

### 3.2 rfMap (has no stop today)

- The STA noise modes currently cycle forever (`nextParams.m:33-38`); only the
  checkerboard sets `movieExhausted`.
- **Derive "done" from persistent state each `_next`, do NOT persist a flag on
  `p.trVars`.** *[review]* `rfMap_next.m:18` runs `p.trVars = p.trVarsGuiComm;`,
  which would wipe any done-flag carried on `p.trVars` from the prior trial
  before it could be read. Mirror barsweep (`barsweep_next.m:22-24`), which
  re-derives the termination condition from persistent `p.status`/`p.init` each
  `_next` and only sets a `trVars` flag **within the same cycle** immediately
  before returning:
  - **STA variants:** done when `p.init.noiseCycleCount ≥ targetCycles`
    (target derived from `movieDurationMin`).
  - **checkerboard:** done when the trial array is exhausted (reuse the existing
    `movieExhausted` / `trialsArrayRowsPossible` emptiness).
- `rfMap_next.m`: compute "done" from persistent state; if done, set the
  transient flag + early-return **before** `iTrial` increment. `rfMap_run.m`:
  short-circuit on the transient flag. `rfMap_finish.m`: no-op gate +
  `pds.stopRunButton` + final status persist + defensive wait.

### 3.3 barsweep (harden existing)

- Keep the `barsweepSessionDone` path (`barsweep_next.m:22-27`,
  `barsweep_run.m:23-26`, `barsweep_finish.m:20-31`) but replace the inline
  toggle with `pds.stopRunButton` (empty/multi-handle guard) and add the
  defensive wait in the finish done-gate.

### 3.4 Files touched

- `+pds/stopRunButton.m` — **new** shared helper.
- `tasks/rfMap/rfMap_next.m`, `rfMap_run.m`, `rfMap_finish.m`,
  `rfMap_commonSettings.m` — session-done flag + counters + auto-stop.
- `tasks/barsweep/barsweep_finish.m` — robust toggle + throttle.

### 3.5 Acceptance criteria

- On reaching the target, each task performs **one** no-op cycle, breaks the GUI
  loop, resets the button to Idle, and prints no more than a single completion
  line — no command-window flood, no rapid counter spin.

---

## 4. Change 4 — Cell-typing

### 4.1 Checkerboard

- **Spatial config unchanged** (full-screen; no centering — argued moot without
  RF center/surround sizes).
- `checkContrasts = [0.125 0.25 0.5 1.0]` (was `[0.25 0.5 1.0]`). Adds a genuine
  low-contrast point for magno low-contrast gain; 0.25 is retained because the
  2026-06-08 responses are **not** saturated there.
  - Trial count = `nCheckSize(3) × nContrast(4) × checkRepsPerCondition(12) =
    144` (~6 min at ~2 s/trial).
  - **CLUT budget: confirmed ample — keep all three check sizes.** *[review]*
    `initClut.m:173-207` allocates checkerboard slots **dynamically** from
    `numel(checkContrasts)` (2 per contrast, appended after 14 base colors) and
    `prepareStim_checkerboard.m:114` sizes to match; 4 contrasts uses 8 of ~242
    free slots of 256. `dkl2rgb([±0.125;0;0])` is well inside gamut, so the low
    point won't clip. The earlier "reduce `checkSizesDva`" worry was unfounded.
- Keep `checkReversalHz = 5` (F1 = 2.5 Hz), `nSTALags = 24`.

### 4.2 denseChromatic

- **RF-centered** via the Change-2 window (automatic once ingestion is wired).
- **Single 0.45 DKL contrast unchanged** — the color task supplies the
  opponency/dominant-axis; the contrast-gain axis comes from the checkerboard,
  so multi-contrast color would be redundant.

### 4.3 Combined magno/parvo/konio readout (cross-session, post-hoc)

New `+pdsActions/classifyCellTypes.m`:

- Ingests **two sessions'** per-channel outputs — denseChromatic DKL STA
  (opponency index: achromatic/magno ↔ chromatic/parvo, plus S-dominance for
  konio) and checkerboard F1 (low-contrast gain = e.g. `F1(0.125)/F1(1.0)`).
- Computes the two axes, plots each channel on the magno/parvo/konio plane, and
  writes a CSV + figure. ~64 channels × a few arithmetic ops ⇒ well under the
  10–30 s ceiling; **adds nothing to either task's runtime**.

### 4.4 Files touched

- `tasks/rfMap/rfMap_checkerboard_settings.m` — `checkContrasts`.
- `.../supportFunctions/prepareStim_checkerboard.m`, `initClut.m` — 4 contrasts.
- `+pdsActions/classifyCellTypes.m` — **new** cross-session readout.
- Per-channel export helpers for both variants as needed (source data for the
  classifier).

### 4.5 Acceptance criteria

- Checkerboard installs 4 contrasts without exceeding CLUT slots; F1/F2 pipeline
  handles the new low point.
- Classifier action runs on two saved sessions and emits the plane + labels in
  seconds.

---

## 5. Cross-cutting concerns

- **Strobe codes:** every new strobed parameter must have a matching field in
  `+pds/initCodes.m` (per the HOLY-file rule). *[review]* `barsweepSignalSource`
  is **confirmed absent** and must be added. `rfMapCheckContrastIdx` (16147)
  needs **no** change — it strobes a 1-based index, and strobe *values* can be
  any positive integer, so 4 contrast levels are already representable.
- **Validation/tests:** update `testBarsweepRF`, `validateBarsweepSession`,
  `decodeRippleEvents`, `rebuildBarsweepRFFromTrials` for the direction-keyed
  accumulator; add tests for the midpoint estimator, window construction
  (robust trim + degenerate fallback), and auto-stop (single no-op cycle).
- **MUAE hardware dependency:** online MUAE requires a Trellis continuous
  hi-freq/raw stream; implemented attempt-and-warn with fallback to crossings.

## 6. Suggested phasing

1. **Refresh-rate fix + auto-stop** (small, both tasks, low risk, immediate
   quality-of-life; unblocks recording sessions from the runaway).
2. **Barsweep midpoint method** (accumulator re-key, reconstruction, two-tier
   viz, export) — **crossings only**.
3. **Barsweep MUAE option** (continuous pull + envelope + fallback).
4. **rfMap window ingestion + STA defaults + occlusion + adequacy estimator.**
5. **Checkerboard contrast set + cross-session classifier.**

## 7. Open risks

- **MUAE transfer/compute** (64 ch × 30 kS/s) may prove impractical online —
  mitigated by selectable source + attempt-and-warn.
- **STA yield at ≤10 min / ~9 Hz** — spike-limited; adequacy estimator surfaces
  it; 2.0° fallback; sparse likely weakest.
- **ITI texture-upload latency** at 120 Hz — per-trial `Screen('MakeTexture')`
  count doubles with frame rate and grows with finer checks (*[review]*
  re-pointed from the earlier, incorrect "texture memory / CLUT capacity"
  risks, both of which were checked and are non-issues).
- **Robust window degeneracy** (few detected channels) → floor to default size
  and warn.
