---
title: RF mapping & fixation family
type: family
category: Tasks — RF mapping & fixation family
summary: Passive-fixation RF mapping (rfMap, barsweep), the microstimulation detection task that uses their output (sacc_to_phosph), and the plain fixation tasks (fixate, fixate_chen)
status: active
sources:
  - tasks/rfMap/rfMap_commonSettings.m @ 13b0ec92af
  - tasks/barsweep/barsweep_cardinal4_settings.m @ 157d537c96
  - tasks/sacc_to_phosph (WiP)/sacc_to_phosph_settings_pick_all_channels.m @ 7ef636fc77
  - tasks/fixate/fixate_settings.m @ b21d79b164
  - +pdsActions/exportRFCentersCSV.m @ 4d08cfd0f8
  - +pdsActions/exportBarsweepRFCentersCSV.m @ b7075234a6
  - tasks/rfMap/_validation/PLAN_rf_estimation_pipeline.md @ 750e552840
verified_at: e48934be
updated: 2026-10-15
---

# RF mapping & fixation family

These tasks share the simplest behavioral demand in the repo: hold gaze on a central
point. **rfMap** and **barsweep** pair that demand with a stimulus that plays while the
subject fixates, and with online analysis of Ripple spikes that turns each recording
channel into a receptive-field estimate during the session. **sacc_to_phosph** is the
downstream step: it microstimulates electrodes and asks whether the subject saccades to
the evoked percept. Its channel and location choices come from the mapping tasks' RF
centers. **fixate** is a bare fixation-training task, and **fixate_chen** is an empty
leftover of a fixate copy.

## Workflow

`_validation/PLAN_rf_estimation_pipeline.md` (in `tasks/rfMap/`) describes the intended
sequence: probe in LGN → rfMap checkerboard to pre-screen responsive channels → rfMap
denseAchromatic in the contralateral hemifield for RF centers (its sim workflow also lists
barsweep_cardinal4 to cross-validate centers) → per-channel quality scoring → go/no-go
for microstimulation in sacc_to_phosph. Per-channel centers are exported with
`pdsActions.exportRFCentersCSV` or `pdsActions.exportBarsweepRFCentersCSV` (both write
`channel,x_deg,y_deg` first; the barsweep file adds `snr,latency_ms`). Both export
headers say sacc_to_phosph consumes the CSV manually.

## Members

| Task | Status | One line |
|---|---|---|
| [rfMap](rfMap.md) | active | Noise RF mapping, four stim types, online STA + RF centers, simulation mode |
| [barsweep](barsweep.md) | active | Translating-bar RF mapping, cardinal4 / rfmap12 regimes |
| [sacc_to_phosph](sacc_to_phosph.md) | wip | Saccade-to-phosphene detection with visual, microstim and no-stim trials |
| [fixate](fixate.md) | active | Acquire and hold fixation for 0.2–0.4 s |
| [fixate_chen](fixate_chen.md) | legacy | Empty directories; contents moved to LGN_RF_mapping → fix_present_squares → folded into rfMap |

## How they differ

| | rfMap | barsweep | sacc_to_phosph | fixate |
|---|---|---|---|---|
| Subject's job | hold fixation while noise plays (`trialDurationS` 1.5 s; 2 s checkerboard) | hold fixation through one bar sweep (40° at 20°/s) | saccade if a stimulus or phosphene appears, otherwise hold fixation until `totalFixDur` (1.5 s) | hold fixation 0.2–0.4 s |
| Settings variants | 4 stim types + 4 `sim_` wrappers, sharing `rfMap_commonSettings.m` | `cardinal4` (base) + `rfmap12` wrapper | `pick_all_channels`, `pick_one_channel`, `random_sample` | one file |
| Trial selection | noise-movie chunks in order; checkerboard: seeded permutation of size × contrast | angle pool with opposite-direction pairs drawn together; pops on reward | trial-type table rows drawn at random; aborts reshuffled | none (random hold time) |
| Session end | auto: movie passes (`targetNoiseCycles`) or checkerboard array used up | auto: `setRepeats` rewarded sweeps per angle | manual | manual |
| Ripple use | spike read + online STA (or simulated LNP spikes) | spike read + online bar-position RF | stimulation (`xippmex stimseq`, fast-settle) | none |
| Online display | STA figure + per-channel browser uifigure | RF figure + per-channel browser | psychometric plot | behavior plot window |
| Task code / strobes | 32020; stim-type, seed, frame-range, per-type params | 32022; polar path and fixation geometry, RF knobs | 32019; trialCode, per-electrode channel / amplitude / polarity | none; date/time only |
| Reconstruct offline from | RNG seed + grid parameters (movie not saved) | `<sessionId>_barsweepRF.mat` sidecar + per-trial sweep fields | trial array + saved trVars | n/a |

Shared mechanics in the two mapping tasks: the same state sequence (`trialBegun → showFix
→ hold… → complete`, aborts 11 and 13, success 21); `stimOff`/`fixOff` via postFlip with
the reward gated on `stimOff > 0`; `trialRunDone` strobed when `_run` exits and
`trialEnd` strobed in `_finish`; spike thresholds set from RMS at init; spikes trimmed to
the stimulus window; large accumulators removed from `p.init` before each `pds.saveP`.
Both also have no-op gates in `_next`/`_run`/`_finish` that drive the GUI Run button off
at session end.

## History

`fixate` dates from the initial 2022 commit. In 2026-04, `fixate_chen` was renamed to
`LGN_RF_mapping`, then to `fix_present_squares`. rfMap was added on 2026-04-15 and barsweep on 2026-04-28. The rfMap unified
merge (2026-05-04 to 05-06, `analysisPlanningDocs/rfMap_unified_merge_plan.md`)
deprecated and deleted `fix_present_squares`. sacc_to_phosph was renamed from
`saccade_to_phosphene` on 2026-04-15, and its first working version came on 2026-04-28.

## Related

- [Ephys integration](../concepts/ephys-integration.md) · [Online plotting](../concepts/online-plotting.md) · [Strobe codes](../concepts/strobe-codes.md) · [pdsActions](../library/pdsActions.md)
- Other families: [gSac](family-gsac.md) · [joystick](family-joystick.md) · [SRS](family-srs.md) · [scd](family-scd.md)
