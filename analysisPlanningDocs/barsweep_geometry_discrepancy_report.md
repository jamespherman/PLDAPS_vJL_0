# barsweep (cardinal4): sweep-geometry discrepancy — investigation report

**Date:** 2026-08-17
**Task:** `tasks/barsweep/`, `exptType = 'barsweep_cardinal4'`
**Reported by:** collaborators recording right LGN, awake behaving NHP
**Status:** confirmed, root cause identified, fix not yet applied

---

## 1. The reports

Two independent observations from the rig:

1. With `pathLengthDeg = 40`, the sweep looks longer than 40° — "maybe more like 50°".
2. With `pathCenterXDeg = -17` and `pathLengthDeg = 40`, a leftward (180°) sweep should
   start at **+3°** and end at **−37°**. Measured against the experimenter-display grid
   (2° spacing), the bar instead first appears at **≈ +6.5°**.

Both are real. Observation 2 is reproduced by the code to within 0.01°.

---

## 2. Root cause

`+pds/deg2pix.m` is a **tangent (perspective) mapping**, not a scale factor:

```matlab
pix = round(tand(deg) * p.rig.viewdist * p.rig.screenhpix / p.rig.screenh);
```

It is valid only for converting an **absolute eccentricity from screen center** into a
pixel offset from screen center. Critically:

```
deg2pix(a + b) ≠ deg2pix(a) + deg2pix(b)
0.5 * deg2pix(40) ≠ deg2pix(20)
```

`tasks/barsweep/supportFunctions/nextParams.m:63-75` uses it as if it were a scale factor,
passing a *length* (`pathLengthDeg`) through it and then doing linear arithmetic in pixel
space:

```matlab
cx_pix = p.draw.middleXY(1) + pds.deg2pix(p.trVars.pathCenterXDeg, p);
L_pix  = pds.deg2pix(p.trVars.pathLengthDeg, p);   % <-- a LENGTH through tand()
theta  = deg2rad(p.trVars.pathAngleDeg);
dx =  0.5 * L_pix * cos(theta);
dy = -0.5 * L_pix * sin(theta);
p.trVars.sweepStartPix = [cx_pix - dx; cy_pix - dy];
p.trVars.sweepEndPix   = [cx_pix + dx; cy_pix + dy];
```

Because `0.5·tan(40°) > tan(20°)`, the half-path is too long, and because the half-path is
added in pixel space to a tangent-mapped center, the two endpoints are displaced
asymmetrically.

The experimenter grid (`+pds/defineGridLines.m:9`) *is* drawn with the tangent-correct
mapping, so grid lines mark true angular positions. The collaborators' ruler was correct;
the stimulus was not.

---

## 3. Quantitative prediction for the reported configuration

Rig geometry (identical for `rigConfig_rig1` and `rigConfig_rig2`):
viewing distance 410 mm, 1200 px over 302.4 mm.

```
k = viewdist * screenhpix / screenh = 410 * 1200 / 302.4 = 1626.98 px per unit tangent
```

Settings: `pathCenterXDeg = -17`, `pathCenterYDeg = 0`, `pathLengthDeg = 40`,
`pathAngleDeg = 180` (leftward), `speedDegPerSec = 20`.

| Quantity | Intended | Actual (current code) |
|---|---|---|
| half-path, pixels | `tand(20)·k` = 592 px | `0.5·tand(40)·k` = 682.5 px |
| half-path, degrees | 20.00° | `atand(682.5/k)` = **22.76°** |
| sweep **start** (angle 180) | **+3.00°** | **+6.504°** ← matches the ≈6.5° measurement |
| sweep **end** | −37.00° | −35.94° |
| total angular extent | 40.00° | **42.44°** |
| nominal speed | 20 °/s | 20.1 °/s in the *assigned* coordinate |
| true angular speed | 20 °/s (constant) | **24.1 °/s at 0°, 22.1 °/s at −17°, 16.2 °/s at −35°** |

Additional consequence: the far end of the sweep at −35.94° is **−1179 px**, but the screen
half-width is 960 px (**−30.54°**). **The last ~16% of every leftward sweep is off-screen.**
The bar visibly vanishes at −30.5° rather than reaching the nominal −37°.

### On the "more like 50°" impression

The model predicts 42.4° total (of which ~37.0° is on-screen), not 50°. The most likely
origin of the 50° figure is measuring the path on the screen surface and dividing by the
*foveal* scale: 1365 px ÷ 28.4 px/deg = **48°**. Whatever the exact provenance, the
direction and mechanism are the same — the path is genuinely longer than requested, and its
angular velocity is not constant.

---

## 4. Effect on the online RF estimates

`nextParams.m:137-147` builds `sweepCenterDegByFrame` by linear interpolation **in dva**
between `pathCenter ± pathLength/2` (i.e. −37° → +3°), while the bar actually moves linearly
**in pixels** (+6.50° → −35.94°). `accumulateBarsweepRF.m:41-46` uses
`sweepCenterDegByFrame` as its position axis; `plotBarsweepRF.m:141` and
`+pdsActions/exportBarsweepRFCentersCSV.m:117` add `pathCenterDeg` back to report absolute
dva. Reported centers therefore inherit the mismatch.

**Azimuth** (0°/180° sweeps) — accurate at the path center, degrading away from it:

| True azimuth | Reported | Error |
|---|---|---|
| 0° | −2.44° | −2.44° |
| −5° | −6.61° | −1.61° |
| −10° | −10.84° | −0.84° |
| **−17° (path center)** | **−17.01°** | **≈ 0** |
| −25° | −24.67° | +0.33° |
| −30° | −29.96° | +0.04° |
| −35° | −35.82° | −0.82° |

**Elevation** (90°/270° sweeps, `pathCenterYDeg = 0`) — a systematic compression toward
zero of roughly 14%:

| True elevation | Reported | Error |
|---|---|---|
| 5° | 4.17° | −0.83° |
| 10° | 8.41° | −1.59° |
| 15° | 12.77° | −2.23° |

### What is *not* affected

- **Latency estimates** (`out.latencyAzMs`, `latencyElMs`, `latencyMs`). The buggy position
  coordinate is exactly proportional to pixel position, hence exactly **linear in time**.
  The opposite-direction peaks still sit symmetrically at `s_RF ± v·λ`, so both the midpoint
  cancellation and the latency-from-separation calculation remain valid. (Residual error is
  the 0.4% difference between nominal and frame-quantized sweep duration.)
- **The reconstruction geometry itself.** Because the assigned coordinate is an isotropic
  scaled copy of the pixel plane (same `k` for x and y), the accumulated histograms are a
  *valid reconstruction in the tangent/pixel plane* for both `cardinal4` and `rfmap12`. The
  bug is confined to the final coordinate label. This is what makes the post-hoc correction
  in §5 exact rather than approximate.

### What is genuinely lost (not correctable post hoc)

Frames whose bar center fell off-screen were excluded from accumulation
(`accumulateBarsweepRF.m:153-164`, correct behaviour). For the reported configuration this
means azimuth coverage stopped at **−30.54°**; channels whose RF sits beyond that have
truncated profiles and unreliable centers regardless of the correction.

---

## 5. Correcting already-collected data

The bug is a pure, deterministic, invertible relabeling of the position axis. No
re-accumulation and no re-analysis of raw data is required for the RF centers.

### 5.1 Closed form

Let

- `k  = p.rig.viewdist * p.rig.screenhpix / p.rig.screenh`
- `c  = round(tand(pathCenterDeg) * k)`   (the rounded center offset the code actually used)
- `Lp = round(tand(pathLengthDeg) * k)`   (the rounded "path length" in pixels)
- `s` = a reported **path-center-relative** coordinate in the buggy dva units
  (i.e. `s = reportedAbsolute − pathCenterDeg`)

then the true visual angle is

```
trueDeg(s) = atand( ( c + (s / pathLengthDeg) * Lp ) / k )
```

Applied per axis: azimuth uses `pathCenterXDeg`, elevation uses `pathCenterYDeg`. Sanity
checks for the reported configuration: `s = 0 → −16.987°`, `s = +20 → +6.504°`,
`s = −20 → −35.941°`.

The `round()` calls are reproduced deliberately — `pds.deg2pix` rounds to whole pixels, and
the correction is meant to be exact rather than merely close. This is also why `s = 0` maps
to −16.987° rather than −17.000°: `round(tand(-17)·k) = −497 px`, so the path centre was
physically placed 0.013° off the requested value. That sub-pixel offset is real and present
in the data; it is not an artefact of the correction.

**Order matters.** Apply the map to the *already-averaged* midpoint center
(`out.xCenter`, `out.yCenter`), **not** to the individual per-direction peaks. The midpoint
must be taken in the time-linear coordinate for latency to cancel; mapping first and
averaging second would reintroduce a latency-dependent bias.

RF **sizes** need the local derivative rather than the map itself:

```
sigmaTrueDeg ≈ sigmaS * (180/pi) * (Lp / (pathLengthDeg * k)) / (1 + u^2),
where u = (c + (s / pathLengthDeg) * Lp) / k
```

### 5.2 Recommended procedure — PLDAPS-side

Each session folder already contains everything needed:

| File | Contents |
|---|---|
| `p.mat` | full `p`, including `p.rig` (viewdist / screenh / screenhpix) and `p.draw` |
| `<sessionId>_barsweepRF.mat` | full accumulator: `spikeHist`, `dwellTime`, `positionEdges`, `pathCenterDeg`, `pathLengthDeg` |
| `trial####.mat` | per-trial `trVars` (incl. `sweepCenterPix`, `sweepCenterDegByFrame`) and `trData` (incl. Ripple `spikeTimes` / `eventTimes`) |
| `barsweep.zip` | **a snapshot of the task code as it was run** — use this to determine whether a session predates the fix |

Run:

```matlab
correctBarsweepRFCenters('/path/to/output/<sessionId>')
```

which reads the sidecar + `p.mat`, reconstructs per channel, applies the §5.1 map, and
writes `rfCenters_<sessionId>_final_corrected.csv` containing raw and corrected centres side
by side, corrected RF sigmas, the unchanged latency estimates, and an `outsideCoverage` flag
for channels beyond the sampled range. The original CSV is left untouched.

**Provenance rule:** a session is affected iff its `barsweep.zip` copy of `nextParams.m`
still contains `L_pix = pds.deg2pix(p.trVars.pathLengthDeg, p)`. After the fix lands, that
line is gone, and `correctBarsweepRFCenters` refuses to touch such sessions.

### 5.3 Recommended procedure — Ripple-side

For analyses built on offline-sorted units from the raw Ripple `.nev` / `.ns5` rather than
the online threshold crossings:

1. Decode the strobe stream with `decodeRippleEvents(eventValues, eventTimes, pds.initCodes)`.
   It returns per-trial `paramsDecoded` with `barsweepAngle_x10`,
   `barsweepCenterTheta_x10` / `barsweepCenterRadius_x100` (→ `pathCenterXDeg`,
   `pathCenterYDeg`), `barsweepPathLength_x100`, and `barsweepSpeed_x100`.
2. **Rig geometry is *not* strobed.** `viewdist`, `screenh`, and `screenhpix` exist only in
   the session's `p.mat`. Any Ripple-only reconstruction must be paired with the matching
   `p.mat` (or the rig constants must be supplied by hand). This is worth fixing going
   forward — see §7.
3. Reconstruct the bar trajectory. Because the strobed values are *nominal*, a naive
   reconstruction reproduces the intended (wrong) geometry. Use
   `barsweepSweepAxisToDeg` to convert any path-center-relative position into true dva —
   the same function used by the PLDAPS-side corrector, so both paths agree by construction.
4. Frame times: the `stimOn` / `stimOff` strobes bracket the sweep. Within that window the
   bar center is exactly linear in pixels, so uniform interpolation across `sweepFrames` is
   correct. Exact per-flip times are available in `trData.timing.flipTime` from the paired
   `trial####.mat` if sub-frame precision is needed.

### 5.4 Numerical verification of the correction

The pre-fix trajectory was simulated frame-by-frame (including the `round()` inside
`deg2pix`) for `pathCenter = (-17, 0)`, `pathLengthDeg = 40`, 240 frames, and the closed
form of §5.1 was compared against `atand(pixelOffset / k)` at every frame:

| Sweep direction | Axis | max abs error over 240 frames |
|---|---|---|
| 0° | azimuth | 1.1e-14° |
| 180° | azimuth | 1.4e-14° |
| 90° | elevation | 1.1e-14° |
| 270° | elevation | 1.1e-14° |

The correction is exact to floating-point precision, not approximate.

The shipped `barsweepSweepAxisToDeg.m` was then exercised in MATLAB against those reference
values and returned `[-35.9406, -16.9865, 6.5045]` for `s = [-20, 0, 20]` on the azimuth
axis and `[-22.7575, 0, 22.7575]` on the elevation axis; its analytic derivative matched a
central finite difference to 1.2e-10 relative error, and both input guards fired as intended.

The `rfmap12` claim was checked separately: for oblique sweeps (30°, 60°, 120°, 150°, 210°,
330°) the accumulated coordinate `s` equals `(pathLengthDeg / L_pix)` times the projection of
the pixel offset onto the orientation axis, to within 2.5e-14. The sinogram fed to `iradon`
is therefore a geometrically valid *pixel-plane* sinogram, and the recovered 2-D centre in
sweep-axis units maps through the same per-axis closed form.

### 5.5 Validation against a real session

Run on `output/20260814_t1207_barsweep` (151 trials, 64 channels, `pathCenter = (0, 0)`,
`pathLengthDeg = 40`):

```
legacy accumulator detected (accumBy is "<absent>" but cardinal4 reconstruction
  requires per-direction accumulation)
re-accumulating from trial####.mat ...
rebuilt from 151 trial(s) | 167480 spikes across 64 channel(s)
rig k = 1626.98 px/unit-tangent | pathCenter = [0.00 0.00] | pathLength = 40.00 deg
azimuth   sweep actually spanned -22.76 to 22.76 deg (nominal -20.00 to 20.00)
elevation sweep actually spanned -22.76 to 22.76 deg (nominal -20.00 to 20.00)
on-screen coverage: azimuth [-30.54 30.54] deg, elevation [-20.24 20.24] deg
7/64 channels detected | median |shift| = [0.406 0.088] deg, max |shift| = [0.529 0.821] deg
```

| ch | x_raw | y_raw | x_corr | y_corr | sigmaX_raw | sigmaX_corr | snr |
|---|---|---|---|---|---|---|---|
| 10 | −2.207 | −0.545 | −2.650 | −0.655 | 1.188 | 1.425 | 5.55 |
| 12 | −2.637 | −0.686 | −3.166 | −0.825 | 1.189 | 1.425 | 4.38 |
| 18 | −1.995 | −0.438 | −2.397 | −0.527 | 1.011 | 1.213 | 4.76 |
| 20 | −1.608 | −0.263 | −1.932 | −0.316 | 0.912 | 1.095 | 4.47 |
| 24 | −0.535 | −0.303 | −0.643 | −0.364 | 0.634 | 0.761 | 6.56 |
| 42 | −2.137 | −0.255 | −2.567 | −0.307 | 0.826 | 0.991 | 4.11 |
| 44 | −2.019 | 4.130 | −2.425 | 4.951 | 1.052 | 1.263 | 5.29 |

Every corrected value was reproduced by independent hand calculation to 4 decimal places.

**This session shows the worst case for the error.** With `pathCenterDeg = 0`, the local
expansion factor at the path centre is **1.2017** — RF eccentricities and sizes were both
underestimated by ~20%. The factor is `(180/π)·L_pix/(pathLength·k) / (1 + tan²(centre))`,
so it is largest at the fovea and falls to 1.0990 for a path centred at −17°. Sessions
mapping near the fovea are the most strongly affected, not the peripheral ones.

Two things this run exposed that are worth separating from the geometry bug:

1. **Legacy sidecars cannot be read by the current `reconstructBarsweepRF` at all.** This
   session's accumulator predates the v2 per-direction change: it has 2 orientation rows,
   and the cardinal4 branch requires 4 direction rows. `exportBarsweepRFCentersCSV` and
   `rebuildBarsweepRFFromTrials` would both fail on it with an opaque out-of-bounds index.
   `correctBarsweepRFCenters` now detects this and re-accumulates from the trial files.
2. **Re-accumulating also changes the analysis method**, from v1 assumed-latency to v2
   midpoint. That accounts for the small spike-count difference against the online sidecar
   (167 480 vs 167 783, 0.18% — the v1 path shifted the acceptance window by the assumed
   40 ms latency) and is why the `latency_ms` column is meaningful at all. The tool prints
   this caveat when it fires.

Trials whose spatial knobs differ from the sidecar snapshot are skipped during rebuild:
`barsweep_finish.m` resets the accumulator whenever a spatial knob changes, so a session can
contain more than one geometry, and replaying all of them blindly would mix coordinate
systems. (All 151 trials matched in this session.)

### 5.6 When re-accumulation *is* required

Only if the per-bin profiles themselves (not just the centers) are needed in true dva, or
if the accumulator logic changes. `rebuildBarsweepRFFromTrials(sessionDir)` already exists
for this: it replays every `trial####.mat` through the current `accumulateBarsweepRF`. Two
things must change for a geometry-corrected replay:

- `sweepCenterDegByFrame` must be recomputed from the saved **pixel** array —
  `pix2deg(sweepCenterPix(1,:) − middleXY(1))` and
  `pix2deg(middleXY(2) − sweepCenterPix(2,:))` — rather than trusted as saved.
- `positionEdges` must be widened. `initBarsweepRF.m:96-99` spans
  `±(pathLengthDeg/2 + barWidthDeg/2 + 1)` = ±21.5°, but true path-center-relative
  positions reach **+23.50°**; bins beyond ±21.5° would be silently dropped by `discretize`.
  The corrected half-extent is `atand(0.5·tand(pathLengthDeg)) + barWidthDeg/2 + margin`
  = 24.26° for these settings.

---

## 6. The fix

Convert **endpoints** to degrees first, then interpolate in degrees and convert each frame
to pixels — replacing `nextParams.m:63-75` and `:121-147`:

```matlab
% endpoints in dva, then dva -> pix. deg2pix is a tangent mapping: it is only
% valid on absolute eccentricities, never on lengths or differences.
dxDeg = 0.5 * p.trVars.pathLengthDeg * cos(theta);
dyDeg = 0.5 * p.trVars.pathLengthDeg * sin(theta);
startDeg = [p.trVars.pathCenterXDeg - dxDeg; p.trVars.pathCenterYDeg - dyDeg];
endDeg   = [p.trVars.pathCenterXDeg + dxDeg; p.trVars.pathCenterYDeg + dyDeg];

p.trVars.sweepStartPix = [p.draw.middleXY(1) + pds.deg2pix(startDeg(1), p); ...
                          p.draw.middleXY(2) - pds.deg2pix(startDeg(2), p)];
p.trVars.sweepEndPix   = [p.draw.middleXY(1) + pds.deg2pix(endDeg(1), p); ...
                          p.draw.middleXY(2) - pds.deg2pix(endDeg(2), p)];

% per-frame: interpolate in DEGREES (constant angular velocity), then convert
p.trVars.sweepCenterDegByFrame = ...
    [linspace(startDeg(1), endDeg(1), sweepFrames); ...
     linspace(startDeg(2), endDeg(2), sweepFrames)];
p.trVars.sweepCenterPix = [ ...
    p.draw.middleXY(1) + pds.deg2pix(p.trVars.sweepCenterDegByFrame(1,:), p); ...
    p.draw.middleXY(2) - pds.deg2pix(p.trVars.sweepCenterDegByFrame(2,:), p)];
```

This fixes all three symptoms at once: the path becomes exactly `pathLengthDeg` of visual
angle, the bar starts at exactly +3.00° for these settings, the bar moves at a genuinely
constant `speedDegPerSec`, and `sweepCenterDegByFrame` becomes the true on-screen position
so the RF accumulator's axis is correct by construction.

Note it changes the endpoint contract documented at `nextParams.m:121-123`: start and end
pixels still match `sweepStartPix` / `sweepEndPix` exactly, but intermediate frames are no
longer linear in pixels. That is the intent.

### Consequences to weigh before switching

- The far endpoint moves outward to −37.0° (−1226 px), so slightly **more** of a leftward
  sweep falls off-screen (edge at −30.54°). Consider reducing `pathLengthDeg` or moving
  `pathCenterXDeg` so the whole sweep is visible, or accept the truncation knowingly.
- Vertical sweeps span ±20.0° after the fix versus ±22.76° before; screen half-height is
  600 px = ±20.24°, so vertical sweeps become fully visible (they were previously clipped).
- Pre- and post-fix sessions are **not** directly poolable without applying §5 to the
  earlier ones.

---

## 7. Related observations (not the reported bug)

- **Bar width and length** go through the same conversion (`nextParams.m:150-151`). A
  "1°" bar is 28 px — exactly 1.0° at the fovea but ≈0.73° at 30° eccentricity. This is an
  unavoidable consequence of a flat screen and a fixed-size texture, not a coding error,
  but it means nominal bar width is only exact near fixation. `barLengthDeg = 80` produces a
  9227-px texture, which is harmless (it simply overhangs the screen) but is not meaningfully
  "80 degrees".
- **Rig geometry is not strobed.** Adding `viewdist`, `screenh`, `screenhpix` (or a single
  `deg2PixConstant_x100`) to `p.init.strobeList` would make Ripple-side reconstruction
  self-contained. This requires new codes in `+pds/initCodes.m`.
- **The same `deg2pix`-on-a-length pattern** should be audited elsewhere in the codebase;
  fixation/target *windows* use it as a half-width relative to a point, which is consistent
  with the degree-based `pds.eyeInWindow` test only when the point is at screen center.

---

## 8. Files referenced

| File | Role |
|---|---|
| `+pds/deg2pix.m` | tangent mapping; correct as written, misused downstream |
| `+pds/pix2deg.m` | inverse |
| `+pds/defineGridLines.m` | experimenter grid; tangent-correct, valid as a ruler |
| `tasks/barsweep/supportFunctions/nextParams.m:63-75` | **the bug** |
| `tasks/barsweep/supportFunctions/nextParams.m:137-147` | `sweepCenterDegByFrame`, inherits it |
| `tasks/barsweep/supportFunctions/accumulateBarsweepRF.m:41-46` | consumes the wrong axis |
| `tasks/barsweep/supportFunctions/initBarsweepRF.m:96-99` | `positionEdges` extent |
| `tasks/barsweep/supportFunctions/reconstructBarsweepRF.m:162+` | cardinal4 midpoint method |
| `+pdsActions/exportBarsweepRFCentersCSV.m:117` | absolute-dva conversion for export |
| `tasks/barsweep/supportFunctions/barsweepSweepAxisToDeg.m` | **new** — closed-form correction |
| `tasks/barsweep/supportFunctions/correctBarsweepRFCenters.m` | **new** — session-level corrector |
