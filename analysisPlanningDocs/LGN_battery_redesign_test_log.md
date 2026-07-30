# LGN RF-Mapping Battery Redesign — Test Log

Companion to `LGN_battery_redesign_plan.md`. Every test to run to validate the
implementation, grouped by phase and by what each test needs:

- **[OFFLINE]** — pure MATLAB, no rig hardware, no monkey. Runnable on any PC
  with the repo on the path (e.g. the office PC).
- **[RIG]** — needs DataPixx/ViewPixx + the display (Psychtoolbox opens a
  window). No monkey required; mouse-eye simulation is fine.
- **[REC]** — needs Ripple/Trellis (and usually a monkey) for real spikes /
  MUAE.

For each test: what to do, and the **expected** result. Note anything that
deviates and pass it back.

> Status legend: ☐ not run · ☑ pass · ✗ fail (add notes)

---

## Phase 1 — auto-stop + measured-refresh hardening  (committed `cea9c31d`)

### [RIG] 1.1 — Refresh is measured and logged
- **Do:** Load any barsweep or rfMap settings file → **Initialize**.
- **Expect:** console prints
  `pds.measureRefresh: display refresh = 119.xx Hz (frame duration = 8.3xx ms).`
  (≈120 Hz on the LGN rig).
- **Fail signals:** prints ~100 Hz, or a `pds:measureRefresh:unexpectedRefresh`
  warning → the display mode / PTB sync is wrong; tell me (it changes the STA
  frame-rate math in Phase 4).

### [RIG] 1.2 — barsweep auto-stops (no runaway)
- **Do:** Load `barsweep_cardinal4_settings`, set `setRepeats` small (e.g. 2)
  in the GUI, **Run**. Use mouse-eye sim (`mouseEyeSim=1`) or pass-eye to get
  through trials quickly.
- **Expect:** when the last set completes, console prints
  `barsweep: session complete (2 set(s) of 2 done) -- stopping run.`, the Run
  button returns to **Idle** on its own, and the command window does **not**
  flood with rapidly incrementing trial lines.

### [RIG] 1.3 — rfMap STA variant auto-stops
- **Do:** Load `rfMap_denseAchromatic_settings`, set `movieDurationMin` small
  (e.g. 0.2) so one movie pass is short, **Run**.
- **Expect:** after one full movie pass, prints
  `rfMap (denseAchromatic): session complete -- stopping run.`, button → Idle,
  no flood. (`targetNoiseCycles=1` by default.)

### [RIG] 1.4 — rfMap checkerboard auto-stops
- **Do:** Load `rfMap_checkerboard_settings`, reduce `checkRepsPerCondition`
  (e.g. 1) so the trial array is short, **Run**.
- **Expect:** when the (checkSize, contrast) trial array is exhausted, prints
  `rfMap (checkerboard): session complete -- stopping run.`, button → Idle,
  no flood.

### [OFFLINE] 1.5 — stop helper guards
- **Do:** In MATLAB with no GUI open, run `pds.stopRunButton`.
- **Expect:** no error (empty `findall` → no-op).

---

## Phase 2 — barsweep midpoint RF method (crossings)  (core, viz upgrade pending)

The accumulator is now keyed by DIRECTION for cardinal4 (rfmap12 unchanged), the
assumed-latency subtraction is dropped, and the RF center is the midpoint of
opposite-direction peaks (latency read from peak separation). Backward-compatible
output fields keep the existing figure/browser/export working; the 4-panel PSTH
viz is a later step.

### [OFFLINE] 2.1 — synthetic RF recovery (the key correctness gate)
- **Do:** in MATLAB with the repo on path:
  `cd tasks/barsweep/supportFunctions; results = testBarsweepRF;`
- **Expect:** prints `[OK]` for every block and ends with
  `[OK] testBarsweepRF passed all checks.` New blocks that MUST pass:
  - `cardinal4 within 1.0 dva on both axes` (midpoint recovers the center)
  - `cardinal4 latency independence (v2)` — center moves < ~0.75 dva when the
    generator latency changes 20→80 ms (**this is the whole point of the
    method**; if it fails, latency is leaking into the center)
  - `cardinal4 projection-sign-trap guard` — center recovered under asymmetric
    forward/backward gain (guards the mod(θ,π) projection; a sign-flipped
    projection would fail here, pinning the center near path center)
  - `rfmap12` blocks still pass (regime untouched)
- **Artifacts:** PNGs under `tasks/barsweep/output/testBarsweepRF/<stamp>/` —
  eyeball `cardinal4_recon.png` (recovered center on truth).

### [OFFLINE] 2.2 — latency robustness sweep
- **Do:** `testBarsweepRF(struct('latencyMs', 20));` and again with `120`.
- **Expect:** all `[OK]`; recovered cardinal4 center within tolerance regardless
  of latency (the accumulator no longer subtracts an assumed latency).

### [OFFLINE] 2.3 — full-fit export path
- **Do:** after a `testBarsweepRF` run, take its `results.cardinal4.rf` and call
  `out = reconstructBarsweepRF(results.cardinal4.rf, 2, 'barsweep_cardinal4', struct('fitMode','full'));`
- **Expect:** no error; `out.xCenter/out.yCenter` finite and near truth;
  `out.latencyMs` finite; `out.fitByDir` is a 4-element struct with `.ok` true
  for driven directions.

### [REC] 2.4 — live barsweep session sanity
- **Do:** run a real barsweep_cardinal4 session with Ripple connected.
- **Expect:** the online RF figure + all-channel browser still render (via the
  compatibility fields), per-channel SNR/centers look sane, no errors in
  `accumulateBarsweepRF` / `reconstructBarsweepRF`. Console shows the usual
  per-trial lines.

### [REC] 2.5 — export CSV format
- **Do:** run GUI action `exportBarsweepRFCentersCSV` (or the action button)
  after a session.
- **Expect:** CSV header is now `channel,x_deg,y_deg,snr,latency_ms`; detected
  channels have finite centers + a plausible `latency_ms` (roughly tens of ms
  for LGN); undetected channels are NaN.
- **Note:** the SNR definition changed (per-axis = min of the two opposite
  directions). The high-SNR threshold (~4.0–4.2) that feeds the Phase-4 rfMap
  window may need **recalibration** against this new SNR — compare the exported
  `snr` column against the offline `bar_snr` you trust and adjust
  `rfWindowSnrThresh` / `rfDetectThresh` if needed. **Please send me a sample
  exported CSV** so I can sanity-check the distribution.

<!-- Phase 3+ tests appended below as each phase is implemented. -->
