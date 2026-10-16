---
title: Timeline
type: catalog
category: Catalogs
summary: Development history of the repo from git log (2022–2026) — when tasks and framework features appeared, and when tasks went dormant
sources: []
verified_at: e48934be
updated: 2026-10-15
---

# Timeline

History of PLDAPS_vK2 as recorded in `git log` (460 commits, 2022-08-04 to 2026-10-15).
Commit counts by year: 2022 35, 2023 48, 2024 107, 2025 97, 2026 173. Authors: James P. Herman
(also "James Paul Herman" / "jamespherman"; ~387 commits), matthewmurawski2 (35, 2024),
MayoLab (19, the shared lab account; mostly human psychophysics 2023–2024) and
google-labs-jules[bot] (19, Aug 2025 – Jan 2026, docs and tokens features delivered as GitHub PRs).
Commits marked "-- LGC" in mid-2026 are SRS-task work committed from the lab account.

The GitHub remote is `github.com/jamespherman/PLDAPS_vJL_0`. Of 54 merge commits, 33 are
`Merge branch 'main' of https://github.com/jamespherman/PLDAPS_vJL_0` (work from several rig and
office machines reconciled through that remote), and 18 are merges of GitHub pull requests
(#1–#19, mostly from the jules bot). The framework itself predates the repo: the original
`_README.rtf` / [`_listOfChanges.rtf`](../_listOfChanges.rtf) describe vK2 as written by James
Herman and Leor Katz in 2018 (see [docs catalog](docs-catalog.md)).

How to read a bullet: `date range — what — representative commits`. Task names link to their
pages; see [overview](overview.md) for the current picture and the family pages for grouping.

## 2022 H2 — import and the joystick-release family

- 2022-08-04 — initial commit imports the framework (`+pds`, `+pdsActions`, `+rigConfigFiles`,
  `+test`, `PLDAPS_vK2_GUI.m`) with tasks [fixate](tasks/fixate.md), [gSac](tasks/gSac.md),
  [gSac_jph](tasks/gSac_jph.md), [joystickPress](tasks/joystickPress.md),
  [joystickPress_playMovie](tasks/joystickPress_playMovie.md),
  [joystick_press_and_fixate](tasks/joystick_press_and_fixate.md), [nfl](tasks/nfl.md),
  [scd](tasks/scd.md) — 97559e58
- 2022-08 — `output/` data folders removed from version control; reward delay added to
  joystick_press_and_fixate — 134d3cf9, ded2cadd, 5c60339a
- 2022-09-01 — [joystick_release_for_fix_off](tasks/joystick_release_for_fix_off.md) created
  (first named "joystick_release_on_fix_off") — be9556bc, 33041d74
- 2022-10-05 – 10-11 — [joystick_release_for_fix_dim](tasks/joystick_release_for_fix_dim.md)
  created; dim value saved in `p.trData`, minimum release latency, `-1` defaults for
  `p.trData.timing` events, online performance / RT plotting, change / no-change outcome naming
  — f2b4a5bb, e20646f9, f4e45d8b, 8db1d55e, 7b352ded
- 2022-10-24 — [joystick_release_for_fix_and_stim_dim](tasks/joystick_release_for_fix_and_stim_dim.md)
  created — 47f42cf2, eb8438a0
- 2022-11-08 – 11-11 — [joystick_release_for_stim_change_and_dim](tasks/joystick_release_for_stim_change_and_dim.md)
  created (4 stimulus locations); multiple settings files per variant. This becomes the most
  edited task in the repo (~100 commits through 2025) — ec6aa85a, 0015feec

## 2023 H1 — Ripple, human psychophysics, rig selection

- 2023-01 — fixation-dimming fixes; on-the-fly fixation size in fixate — 688bfd1d, 157c6793
- 2023-02-08 — [reward_calibration](tasks/reward_calibration.md) created — 3f9fbfed
- 2023-02-21 — orientation-change training variant of stim_change_and_dim — d31a4bd3
- 2023-03-01 – 03-31 — **Ripple support**: `pds.initRipple`, `pds.getRippleData`, `xippmex`
  added; `saccadeGUI` gains spike heatmaps / rasters; gSac_jph PSTHs, `targTrainingDelay`,
  VisSac training settings, online gaze/target plotting — 13d5c320, 6390c950, 8323daf0, 2e6cebfe,
  79954c4e (see [ephys integration](concepts/ephys-integration.md))
- 2023-03-10 – 04-03 — [human_psychophysical_threshold](tasks/human_psychophysical_threshold.md)
  created with **Eyelink support** (`pds.initEyelink`, `pds.getEyelink`, `pds.eyelinkInWindow`,
  `pds.eyeInWindowEL`) and `pds.initPsychToolbox` — a6444a80, 60bdc2ea, 0e9ebeed, 49e0383b
- 2023-05-16 – 05-25 — Ripple status from NIP LED state; **rig config chosen from PC name**
  (`pldaps1` → rig1); `useDataPixxBool` added to settings files across tasks — 188603be, 23c0509a,
  df9ea97a (see [rig configs](library/rig-configs.md))
- 2023-06-21 – 07-12 — `pds.freeReward` (inter-trial free reward); end-of-trial strobing and
  multi-condition PSTHs in stim_change_and_dim; cued variant — fe1d47f1, d20e23eb, 57c10fa6, c47eaaf5

## 2023 H2 — QUEST thresholds

- 2023-07-27 – 09-11 — human task: QUEST threshold estimation, stop on plateau, 20 fixed-strength
  trials after threshold, summary plot, XOrg config — a56ec6dc, 8c3717bb, f2827f1c, 7d8bce0a, 60540d08
- 2023-11-29 — stimulus masking, audio feedback in the human "hue1" variant — ec19c0af

## 2024 H1 — cued attention training (with Matt Murawski)

- 2024-01-24 – 02-08 — cued task strobes `cueLoc` / `chgLoc`; cued-vs-uncued performance plot
  window — 122a35d1, b8031978, 8894584f
- 2024-02-27 — orientation psychometric-curve variant (`..._orient_change_and_dim_psycho_settings.m`)
  — 2ea0fc49, ef8c7462
- 2024-03-11 — dkl2rgb generation from photometer measurements (human task actions) — 1c6fabb0
  (see [color and calibration](concepts/color-and-calibration.md))
- 2024-05-13 – 06-18 — training variants `learn_cue`, `learn_chg`, `learn_cue_multi` as settings
  files of stim_change_and_dim; confusion-matrix and learning-curve plots; `p.status.trialEndStates`
  — aca0caf7, bcf9dcb9, ba329595, 011e46c8, 3c2f91ad, 5aa1104f
- 2024-05-15 — GUI settings-file text made smaller — d657695c (see [GUI](library/gui.md))
- 2024-06-06 – 07-17 — [gSac_contrast](tasks/gSac_contrast.md) created (reward × target color
  contrast); explicit high/low reward durations; DKL luminance matching; per-display LUT files —
  ac709aa8, d9b375b1, 66d4ee6d, f6342ab2, 44cb093f

## 2024 H2 — output folders, opto stimulation

- 2024-06-27 — stray `output` folders consolidated; output-folder specification changed — 2bd1e54f
- 2024-07-01 – 07-09 — Ripple robustness (box on without headstage; require `recChans`) —
  c1dc6b5e, 4d02760e
- 2024-08-07 — attention-task event timing rework — af77b01e
- 2024-08-12 – 08-15 — human task: PC-specific rig config, drift correction (last MayoLab commit) —
  930b078b, bc5b4e3d
- 2024-12-18 – 12-20 — **optical stimulation**: `pds.deliverOptoStim`, opto attention-task updates,
  PSTH plotting app, mapping GUI fix — 3bd3c2dc, 2c4a193d, 11c787b4, 38f668f4

## 2025 H1 — cleanup, Chen lab, seansFirstTask

- 2025-05-09 — cleanup of stray files from the repo root; "All tasks except nfl, scd working" —
  7e42402d, 5e55e2a9
- 2025-05-22 — Ripple status from NIP clock query — 6865ab30
- 2025-06-05 — `mouseEyeSim` added to gSac; [fixate_chen](tasks/fixate_chen.md) created for the
  Chen lab; [seansFirstTask](tasks/seansFirstTask.md) created with its own `uniqueTaskCode` in
  `pds.initCodes` — 166581bf, 07e6043e
- 2025-06-06 — per-task `supportFunctions/output` folders deleted; gSac_contrast aborted trials
  repeated immediately — 75a26860, d9bf98cc
- 2025-06-11 – 07-18 — `pds.eyeInWindow` takes a target number for multi-target tasks;
  seansFirstTask two-target trials, target-one/two saccade strobes, rectangles and ovals —
  c464bad0, ec4735d8, 81adfb27, 179ac62d

## 2025 H2 — tokens, gSac_4factors, agent-written docs

- 2025-07-31 – 08-13 — [tokens](tasks/tokens.md) created; AV variant, flicker colours, time-based
  flicker, dynamic token positioning, audio frequency sweep in `pds.initAudio` (several via jules PRs
  #1–#5) — 44f19e1b, b7cd75b4, c25075ab, 6b59c056, 8ad6f158, b2261d33
- 2025-08-06 – 08-08 — [gSac_4factors](tasks/gSac_4factors.md) created (image / bullseye targets,
  reward, probability, location) — c4e0fd3d, a39123ae, b253b755, dcfd5ddb
- 2025-08-24 – 09-03 — **agent-written documentation** (jules PRs #6–#16): data dictionaries
  (tokens, 4factors, gSac_jph, stim_change_and_dim), `README.md`, `IMPROVEMENT_PLAN.md`,
  analysis planning docs — 08806fdd, 8a0028f7, ffa1fb9c, 687c739f, 32e7a3ff, 0222fe36, 57d01637
  (see [docs catalog](docs-catalog.md))
- 2025-09-23 – 11-20 — seansFirstTask moves to textures and adds a temporal-task transition;
  PSTH plotting updates — 794c1755, 7ea472f4, 5429d763

## 2026 H1 — conflict task, CLAUDE.md, online RF mapping

- 2026-01-13 – 01-30 — gSac_4factors flip-contingent strobing and fixOff postFlip fix, SRT
  reference fix; tokens `trialsArray` reward pre-specification and block regeneration;
  `pds.unifyStructArray`; online pkV / RT / endpoint plots — 386b84c5, 665b85be, 57d7acb3,
  47928692, 1f497b7c, 81e25812
- 2026-01-28 – 02-13 — [conflict_task](tasks/conflict_task.md) created from gSac_4factors; DKL
  hue salience, `hueType` strobe, 8 locations, then per-trial rewards and single-stim sequencing —
  67d22900, aac171b4, eefe2da2, ee98240e, 26f134a6, 1b14d789
- 2026-02-04 — `CLAUDE.md` added; agent-assisted development with Claude Code from here on
  (later `.claude/`, `AGENTS.md` ignored: 633f45ee) — 4a2c7e0f
- 2026-02-19 — numerosity_spatial / numerosity_temporal (copies of seansFirstTask) and
  saccade-to-phosphene (copy of gSac) started — 9c0aa4cc, 95850615
- 2026-04-15 — [rfMap](tasks/rfMap.md) created (dense-noise RF mapping for LGN/SC); LGN_RF_mapping
  started, renamed fix_present_squares 04-28 — c894f7dd, d0adbdeb, f2248a08
- 2026-04-28 — **strobeNow** for behavioral state-machine events in gSac_4factors, then all
  tasks (`pds.classyStrobe` method) — ce70510d, 61d7a932 (see [strobe codes](concepts/strobe-codes.md))
- 2026-04-28 — [barsweep](tasks/barsweep.md) created (translating-bar RF mapping) — 54ff641b
- 2026-05-04 – 05-07 — rfMap unified merge: per-stim-type dispatcher, dense chromatic DKL noise,
  checkerboard, Phase 4 cancelled, post-session audit tool; fix_present_squares removed —
  22c19255, 17877dad, 3ffb4905, fdf42c41, 2e104361, 96a23211
- 2026-05-05 — `initmon()` switched to per-rig LUT files across 14 tasks — 6e8bd9c4
- 2026-05-08 – 05-12 — numerosity variants consolidated into [numerosity](tasks/numerosity.md)
  (WiP) — a6d4837e, 1b53d4a3
- 2026-05-12 – 05-20 — framework trusts measured refresh rate; barsweep online RF mapping with
  cardinal4 / rfmap12 regimes; `pds.setSpikeThreshFromRMS`; shared per-channel RF browser
  (`pds.initChannelBrowser`); RF-centre CSV export actions; `pds.pdfSave`; rfMap LNP simulation
  harness — a69c7b16, 0dffe3f4, 02ddd08c, 42622f4a, 52cecd4f, 25f3dba4, b629f9fb, 13b37f44
- 2026-05-19 – 06-15 — [sacc_to_phosph](tasks/sacc_to_phosph.md) (WiP): late-saccade state,
  bipolar and two-channel microstim, screenshots at stimulus onset, online plots — d1e37fc4,
  5c6ab1e5, e4341c16, d60fcd1f
- 2026-05-27 — `pds.saveP` saves a zipped copy of the task folder with the session — e6e066c2
  (see [data saving](concepts/data-saving.md))
- 2026-06-03 – 06-16 — rfMap shared LGN population sim, channel quality scoring, passive spike
  threshold monitoring (`pds.monitorSpikeThresholds`, `pds.recheckSpikeThresholds`); trialEnd
  strobe moved to the end of the current trial in rfMap/barsweep — 8c486eb7, 13d873b5, 1aeb315f

## 2026 H2 — SRS tasks, LGN battery redesign, gSac_4factors refinements

- 2026-06-22 – 07-16 — SRS (salience–reward–saccade) development as SRS_Fixate / SRS_Task
  ("-- LGC" commits): blocks, reward, strobes, plots, DKL hue and luminance salience —
  2c0109e3, 640ab16d, 3427871f, 441b367e, 76ffae24
- 2026-07-08 — checkerboard F1/F2 at the contrast fundamental; fixation-occluded checks masked from
  dense-noise STA — 5cf82cbb, bf17396c
- 2026-07-21 – 08-20 — [SRS_Task_Smooth](tasks/SRS_Task_Smooth.md): continuous log-uniform hue
  sampling, MoreTraining variant, correction trials, analysis folders, per-block reward means and
  `rewardScale`; superseded SRS directories removed 08-17 — afafeb63, 62ddf889, 09e7d867,
  30ce6753, da18cf11, 77eb7ee8 (see [SRS family](tasks/family-srs.md))
- 2026-07-28 – 08-17 — LGN RF-mapping battery redesign: auto-stop at session end
  (`pds.stopRunButton`, `pds.measureRefresh`), barsweep cardinal4 midpoint RF method, sweep-geometry
  fix — f97a06ae, cea9c31d, c4b143af, cb4170fd
- 2026-08-17 — [SRS_mooving](tasks/SRS_mooving.md) created (moving-target SRS) — 1854e4c9
- 2026-08-18 — sacc_to_phosph "random sample" constant-stimuli method — 76c4b6d3
- 2026-08-20 — i1 colorimeter MEX resolved from the repo (`pds.i1MexFolder`, `externalTools/i1/`)
  — 84bad9b5
- 2026-10-06 – 10-15 — gSac_4factors: go signal 100–600 ms after target offset; image exemplar
  saved and strobed — 19c9e3a5, e48934be

## Dormancy

Commits that sweep across all tasks (6e8bd9c4 LUT files, 61d7a932 strobeNow, the 2025-05 and
2025-06 cleanups) touch even dormant tasks, so the dates below are the last commit that changed a
task for its own sake.

| Task | Created | Last task-specific work |
|---|---|---|
| [nfl](tasks/nfl.md), [scd](tasks/scd.md) | 2022-08 (import) | 2022-10 / 2022-11 — excluded from "All tasks except nfl, scd working" (5e55e2a9, 2025-05-09) |
| [joystick_press_and_fixate](tasks/joystick_press_and_fixate.md), [joystick_release_for_fix_dim](tasks/joystick_release_for_fix_dim.md), [reward_calibration](tasks/reward_calibration.md) | 2022–2023 | 2023-05 (df9ea97a) |
| [joystickPress](tasks/joystickPress.md) | 2022-08 (import) | 2024-07 |
| [joystick_release_for_fix_off](tasks/joystick_release_for_fix_off.md) | 2022-09 | 2024-05 |
| [joystick_release_for_fix_and_stim_dim](tasks/joystick_release_for_fix_and_stim_dim.md) | 2022-10 | 2025-06 |
| [gSac](tasks/gSac.md) | 2022-08 (import) | 2025-06 (`mouseEyeSim`) |
| [fixate](tasks/fixate.md) | 2022-08 (import) | 2026-05 (`plotWindowSetup` fix, 4afbdeed) |
| [joystickPress_playMovie](tasks/joystickPress_playMovie.md) | 2022-08 (import) | 2025-10 (PSTH plotting) |
| [fixate_chen](tasks/fixate_chen.md) | 2025-06 | 2025-06 |
| [gSac_contrast](tasks/gSac_contrast.md) | 2024-06 | 2025-08 (later: i1 action edit, 6bcbb2cf, 2026-07) |
| [human_psychophysical_threshold](tasks/human_psychophysical_threshold.md) | 2023-03 | 2026-02 |
| [tokens](tasks/tokens.md) | 2025-07 | 2026-01 |
| [joystick_release_for_stim_change_and_dim](tasks/joystick_release_for_stim_change_and_dim.md) | 2022-11 | 2025-08 (later: helper script, formatting, i1 action edit) |
| [conflict_task](tasks/conflict_task.md) | 2026-01 | 2026-04 (analysis scripts; later a two-line run-file edit, 35269b50, 2026-07) |
| [seansFirstTask](tasks/seansFirstTask.md) | 2025-06 | 2026-07 (9afb8f59) |
| [gSac_jph](tasks/gSac_jph.md) | 2022-08 (import) | 2026-07 (35269b50) |

Active in the last few months: gSac_4factors, SRS_Task_Smooth, SRS_mooving, rfMap, barsweep,
sacc_to_phosph (WiP), numerosity (WiP).
