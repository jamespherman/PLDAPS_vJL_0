---
title: Docs catalog
type: catalog
category: Catalogs
summary: Every existing doc in the repo outside wiki/ (README, plans, data dictionaries, task-folder notes) with what it is, its status, and the related wiki page
sources:
  - README.md @ 2cc15c52cc
  - IMPROVEMENT_PLAN.md @ fdc09c81c6
  - CLAUDE.md @ 093adce265
  - _listOfChanges.rtf @ 901dae6d23
  - +test/_README.rtf @ 77fa55271f
  - +test/_listOfChanges.rtf @ 901dae6d23
  - externalTools/i1/README.md @ 75e3d57f4f
  - data_dictionaries/4factors_data_dictionary.md @ 4439263e5a
  - data_dictionaries/gSac_jph_data_dictionary.md @ efa2f87748
  - data_dictionaries/joystick_release_for_stim_change_and_dim_data_dictionary.md @ c4dcdb6937
  - data_dictionaries/rfMap_data_dictionary.md @ d767ec0bc9
  - data_dictionaries/srsClassic_Moretraining_data_dictionary.md @ 0332aa8fc0
  - data_dictionaries/tokens_data_dictionary.md @ fec1340014
  - analysisPlanningDocs/barsweep_geometry_discrepancy_report.md @ 0fcdfc5591
  - analysisPlanningDocs/barsweep_implementation_plan.md @ 8ec1151dad
  - analysisPlanningDocs/barsweep_online_rf_mapping_plan.md @ e3237074d8
  - analysisPlanningDocs/barsweep_pre_recording_validation_plan.md @ 602c014731
  - analysisPlanningDocs/conflict_task_implementation_plan.md @ ce14c2c6f2
  - analysisPlanningDocs/gSac_4factors_analysis_planning.md @ 3e97e9f8cf
  - analysisPlanningDocs/gSac_4factors_task_description.md @ 3e8b965e68
  - analysisPlanningDocs/gSac_4factors_task_spec_plan.md @ 9906f0a046
  - analysisPlanningDocs/gSac_contrast_analysis_planning.md @ 1550338397
  - analysisPlanningDocs/gSac_jph_analysis_planning.md @ 8e0a19ba5f
  - analysisPlanningDocs/joystick_release_for_stim_change_and_dim_analysis_planning.md @ b62b078d2a
  - analysisPlanningDocs/LGN_battery_redesign_plan.md @ 12b2fe238f
  - analysisPlanningDocs/LGN_battery_redesign_test_log.md @ ca8f912f5c
  - analysisPlanningDocs/llm_wiki_implementation_plan.md @ b89a686fe1
  - analysisPlanningDocs/rf_browser_ux_improvements_plan.md @ ddd6548127
  - analysisPlanningDocs/rfMap_unified_merge_plan.md @ 8181f45123
  - analysisPlanningDocs/seansFirstTask_analysis_planning.md @ 9e4223e9e1
  - analysisPlanningDocs/tokens_analysis_planning.md @ 7206fad136
  - tasks/conflict_task/supportFunctions/CONFLICT_TASK_REFACTOR_PLAN.md @ 918ebfdc84
  - tasks/conflict_task/supportFunctions/MULTI_SESSION_ANALYSIS_PLAN.md @ 186e1b85bf
  - tasks/conflict_task/supportFunctions/REFACTOR_PLAN.md @ bf26fb47a5
  - tasks/conflict_task/supportFunctions/SINGLE_STIM_IMPLEMENTATION_PLAN.md @ 2f7afbcf3c
  - tasks/conflict_task/supportFunctions/target_timing_report.md @ d4ca9ca649
  - tasks/gSac_4factors/gSac_4factors_task_design_specification.md @ 82458e7bb4
  - tasks/rfMap/_validation/PLAN_rf_estimation_pipeline.md @ 750e552840
  - tasks/rfMap/_validation/SIM_MODE_PLAN.md @ 194208745d
  - tasks/rfMap/dklVsRgbChomaticNoise.md @ a6b4911fa6
  - tasks/SRS_mooving/README_SRS_MOVING.md @ 69338d7779
  - tasks/SRS_mooving/Simple_analysis/README.md @ 695e28b48f
  - tasks/SRS_Task_Smooth/Simple_analysis/README.md @ 0817f6ea58
  - tasks/SRS_Task_Smooth/SRS_behavior_analysis_2/CHANGELOG.md @ cbafea5033
  - tasks/SRS_Task_Smooth/SRS_behavior_analysis_2/README.md @ 4cb508ba31
verified_at: a9564f6b
updated: 2026-10-18
---

# Docs catalog

Every human- or agent-written document in the repo outside `wiki/`. These are **raw sources**:
the wiki summarizes and links to them and never edits them. Format: path — what it is — status —
related wiki page. "Status" is taken from the doc itself or from the commit that added it; dates
are last-commit dates. A doc marked *uncommitted* is in the working tree but not yet in git.

When a new doc appears, add it here (the **ingest** workflow in [SCHEMA](SCHEMA.md)).

## Framework docs

- [../README.md](../README.md) — repo README: quintet, `p` struct, GUI workflow, directory layout
  (jules PR #10, 2025-08) — reference — [overview](overview.md), [quintet](concepts/quintet-and-gui-loop.md)
- [../CLAUDE.md](../CLAUDE.md) — must-follow rules for coding agents: quintet, strobe-code system,
  postFlip convention, conflict-task salience (2026-02) — reference, authoritative for rules —
  [gotchas](gotchas.md), [strobe codes](concepts/strobe-codes.md), [drawing and postFlip](concepts/drawing-and-postflip.md)
- [../IMPROVEMENT_PLAN.md](../IMPROVEMENT_PLAN.md) — analysis of `PLDAPS_vK2_GUI.m` (callback model,
  `eval` dispatch) with modernization suggestions (jules PR #11, 2025-09) — open plan — [GUI](library/gui.md)
- [../_listOfChanges.rtf](../_listOfChanges.rtf) — 2018 list of changes from vK1 to vK2: rewritten
  quintet, Datapixx time, `p` substructs, named states and CLUTs, post-flip strobing, per-trial
  saving via `saveP` / `loadP` (imported 2022-08) — historical — [p struct](concepts/p-struct.md)
- [../+test/_listOfChanges.rtf](../+test/_listOfChanges.rtf) — identical copy of the above — historical
- [../+test/_README.rtf](../+test/_README.rtf) — original 2018 README: PLDAPS = PLexon DAtapixx
  PSychtoolbox (Eastman & Huk 2012), vK2 = "version Krauzlis 2", written by James Herman and Leor
  Katz; the root copy was removed when `README.md` was created (687c739f) — historical — [overview](overview.md)
- [../externalTools/i1/README.md](../externalTools/i1/README.md) — why the X-Rite i1Pro MEX lives
  outside `+pds` and is resolved with `pds.i1MexFolder` (2026-08) — reference —
  [color and calibration](concepts/color-and-calibration.md)
- `.claude/skills/wiki/SKILL.md` — Claude Code skill for
  maintaining this wiki (update / ingest / query / lint) — git-ignored (`.claude/`, local to the machine), reference — [SCHEMA](SCHEMA.md)
- [../analysisPlanningDocs/llm_wiki_implementation_plan.md](../analysisPlanningDocs/llm_wiki_implementation_plan.md)
  — plan for this wiki (layers, ownership vs CLAUDE.md, hooks, staleness hashing), v2 2026-10-15 —
  implemented 2026-10-15 (§13 records implementation notes) — [SCHEMA](SCHEMA.md)

## Data dictionaries

Field-by-field descriptions of saved `p` / per-trial structures. The four from 2025 were written by
the jules bot (PRs #6–#9, unified #12, timing added #16).

- [../data_dictionaries/4factors_data_dictionary.md](../data_dictionaries/4factors_data_dictionary.md)
  — gSac_4factors saved data (2025-09) — reference; predates the 2026 gSac_4factors changes listed
  on the task page — [gSac_4factors](tasks/gSac_4factors.md)
- [../data_dictionaries/gSac_jph_data_dictionary.md](../data_dictionaries/gSac_jph_data_dictionary.md)
  — gSac_jph saved data (2025-09) — reference — [gSac_jph](tasks/gSac_jph.md)
- [../data_dictionaries/joystick_release_for_stim_change_and_dim_data_dictionary.md](../data_dictionaries/joystick_release_for_stim_change_and_dim_data_dictionary.md)
  — stim change + dim saved data, focused on the `learn_cue` settings variant (2025-09) — reference —
  [joystick_release_for_stim_change_and_dim](tasks/joystick_release_for_stim_change_and_dim.md)
- [../data_dictionaries/tokens_data_dictionary.md](../data_dictionaries/tokens_data_dictionary.md)
  — tokens saved data (2025-09) — reference — [tokens](tasks/tokens.md)
- [../data_dictionaries/rfMap_data_dictionary.md](../data_dictionaries/rfMap_data_dictionary.md)
  — rfMap saved data after the unified merge: stim types, states, strobe ranges incl. reserved codes
  (2026-05) — reference — [rfMap](tasks/rfMap.md)
- [../data_dictionaries/srsClassic_Moretraining_data_dictionary.md](../data_dictionaries/srsClassic_Moretraining_data_dictionary.md)
  — SRS_Task_Smooth `srsClassic_Moretraining` variant: saved data and Ripple alignment, written for
  the 2026-08-19/20 sessions — reference — [SRS_Task_Smooth](tasks/SRS_Task_Smooth.md)

## Analysis planning docs (`analysisPlanningDocs/`)

Per-task analysis primers (2025-09): goal, state machine, key variables and timing, for analysts.
The tokens, gSac_4factors and gSac_jph primers came from jules PRs #13–#15; the gSac_contrast,
stim change + dim and seansFirstTask primers were committed by James Herman (ea073cd9, 277b51df).

- [../analysisPlanningDocs/gSac_4factors_analysis_planning.md](../analysisPlanningDocs/gSac_4factors_analysis_planning.md)
  — reference — [gSac_4factors](tasks/gSac_4factors.md)
- [../analysisPlanningDocs/gSac_contrast_analysis_planning.md](../analysisPlanningDocs/gSac_contrast_analysis_planning.md)
  — reference — [gSac_contrast](tasks/gSac_contrast.md)
- [../analysisPlanningDocs/gSac_jph_analysis_planning.md](../analysisPlanningDocs/gSac_jph_analysis_planning.md)
  — reference — [gSac_jph](tasks/gSac_jph.md)
- [../analysisPlanningDocs/joystick_release_for_stim_change_and_dim_analysis_planning.md](../analysisPlanningDocs/joystick_release_for_stim_change_and_dim_analysis_planning.md)
  — reference — [joystick_release_for_stim_change_and_dim](tasks/joystick_release_for_stim_change_and_dim.md)
- [../analysisPlanningDocs/seansFirstTask_analysis_planning.md](../analysisPlanningDocs/seansFirstTask_analysis_planning.md)
  — reference — [seansFirstTask](tasks/seansFirstTask.md)
- [../analysisPlanningDocs/tokens_analysis_planning.md](../analysisPlanningDocs/tokens_analysis_planning.md)
  — covers tokens_main and tokens_AV — reference — [tokens](tasks/tokens.md)

Design, implementation and investigation docs:

- [../analysisPlanningDocs/gSac_4factors_task_description.md](../analysisPlanningDocs/gSac_4factors_task_description.md)
  — complete behavioral description of gSac_4factors with settings defaults (updated 2026-10-06) —
  reference — [gSac_4factors](tasks/gSac_4factors.md)
- [../analysisPlanningDocs/gSac_4factors_task_spec_plan.md](../analysisPlanningDocs/gSac_4factors_task_spec_plan.md)
  — plan for writing the gSac_4factors design specification — implemented (the spec in the task
  folder, same commit e7cf40b8) — [gSac_4factors](tasks/gSac_4factors.md)
- [../analysisPlanningDocs/conflict_task_implementation_plan.md](../analysisPlanningDocs/conflict_task_implementation_plan.md)
  — plan to build conflict_task from gSac_4factors (2 factors, bullseyes, 2 locations) —
  implemented 67d22900, since refactored (see task-folder docs) — [conflict_task](tasks/conflict_task.md)
- [../analysisPlanningDocs/rfMap_unified_merge_plan.md](../analysisPlanningDocs/rfMap_unified_merge_plan.md)
  — phased plan to unify rfMap into four stim types and retire fix_present_squares, with recorded
  phase outcomes — Phases 0–3 shipped; the original jitter/aperture Phase 4 was cancelled (fdf42c41)
  and Phase 4 became the cleanup (2e104361); Phase 5 is a validation gate (5d audit tool 96a23211)
  — [rfMap](tasks/rfMap.md)
- [../analysisPlanningDocs/rf_browser_ux_improvements_plan.md](../analysisPlanningDocs/rf_browser_ux_improvements_plan.md)
  — agent plan-prompt for five per-channel RF browser improvements (tile aspect, barsweep path
  length, panel sizing, RF-centre overlay, PDF save) — implemented (commits of 2026-05-20, e.g.
  1a0a4bf1, 6944b01b, eb0f5ca1, b088df8a) — [rfMap](tasks/rfMap.md), [online plotting](concepts/online-plotting.md)
- [../analysisPlanningDocs/barsweep_implementation_plan.md](../analysisPlanningDocs/barsweep_implementation_plan.md)
  — plan for the passive-fixation barsweep task, ported from collaborator code — implemented
  54ff641b — [barsweep](tasks/barsweep.md)
- [../analysisPlanningDocs/barsweep_online_rf_mapping_plan.md](../analysisPlanningDocs/barsweep_online_rf_mapping_plan.md)
  — online RF mapping for barsweep in cardinal4 / rfmap12 regimes — implemented 0dffe3f4 (cardinal4
  estimator later replaced by the midpoint method, see LGN battery plan) — [barsweep](tasks/barsweep.md)
- [../analysisPlanningDocs/barsweep_pre_recording_validation_plan.md](../analysisPlanningDocs/barsweep_pre_recording_validation_plan.md)
  — strobe / timing / saved-data validation protocol before recording with barsweep — validation
  protocol — [barsweep](tasks/barsweep.md), [ephys integration](concepts/ephys-integration.md)
- [../analysisPlanningDocs/barsweep_geometry_discrepancy_report.md](../analysisPlanningDocs/barsweep_geometry_discrepancy_report.md)
  — investigation of cardinal4 sweeps appearing longer / offset (tangent mapping in `pds.deg2pix`)
  — report; its status line says "fix not yet applied", and it was committed together with the
  sweep-geometry fix cb4170fd — [barsweep](tasks/barsweep.md)
- [../analysisPlanningDocs/LGN_battery_redesign_plan.md](../analysisPlanningDocs/LGN_battery_redesign_plan.md)
  — redesign of the LGN RF-mapping battery after the 2026-06-08 session, with an implementation-status
  table — partly implemented (Phase 1 cea9c31d, Phase 2 core c4b143af; Phases 2-viz, 3–5 pending
  per the doc) — [family-mapping](tasks/family-mapping.md)
- [../analysisPlanningDocs/LGN_battery_redesign_test_log.md](../analysisPlanningDocs/LGN_battery_redesign_test_log.md)
  — test list and run history for the redesign (offline tests passed 2026-08-06; rig / recording
  tests not yet run per the doc) — test log — [family-mapping](tasks/family-mapping.md)

## Task-folder docs

- [../tasks/gSac_4factors/gSac_4factors_task_design_specification.md](../tasks/gSac_4factors/gSac_4factors_task_design_specification.md)
  — design specification: four factors, stimuli, locations, timing —
  reference — [gSac_4factors](tasks/gSac_4factors.md)
- [../tasks/conflict_task/supportFunctions/CONFLICT_TASK_REFACTOR_PLAN.md](../tasks/conflict_task/supportFunctions/CONFLICT_TASK_REFACTOR_PLAN.md)
  — refactor to more target locations, new reward structure and visualization — implemented
  (refactor ee98240e) — [conflict_task](tasks/conflict_task.md)
- [../tasks/conflict_task/supportFunctions/REFACTOR_PLAN.md](../tasks/conflict_task/supportFunctions/REFACTOR_PLAN.md)
  — six changes incl. `timeoutSacErr`, `rewardRatioBig`, per-trial `rewardBigSide` — implemented
  (those variables are in the task code) — [conflict_task](tasks/conflict_task.md)
- [../tasks/conflict_task/supportFunctions/SINGLE_STIM_IMPLEMENTATION_PLAN.md](../tasks/conflict_task/supportFunctions/SINGLE_STIM_IMPLEMENTATION_PLAN.md)
  — add single-stimulus trials to Phase 1 to counter a rightward bias — implemented —
  [conflict_task](tasks/conflict_task.md)
- [../tasks/conflict_task/supportFunctions/target_timing_report.md](../tasks/conflict_task/supportFunctions/target_timing_report.md)
  — go-signal and target-onset timing analysis (jules PR #19) — report —
  [conflict_task](tasks/conflict_task.md)
- [../tasks/conflict_task/supportFunctions/MULTI_SESSION_ANALYSIS_PLAN.md](../tasks/conflict_task/supportFunctions/MULTI_SESSION_ANALYSIS_PLAN.md)
  — analysis plan across the Feb 2026 sessions (salience- vs reward-driven regimes) — analysis plan
  — [conflict_task](tasks/conflict_task.md)
- [../tasks/rfMap/dklVsRgbChomaticNoise.md](../tasks/rfMap/dklVsRgbChomaticNoise.md) — note for
  collaborators on why chromatic noise uses DKL rather than RGB axes — design rationale —
  [rfMap](tasks/rfMap.md), [color and calibration](concepts/color-and-calibration.md)
- [../tasks/rfMap/_validation/SIM_MODE_PLAN.md](../tasks/rfMap/_validation/SIM_MODE_PLAN.md) —
  LNP simulation-mode harness plan; the doc says "planned, not implemented" but the harness was
  added afterwards (13b37f44) — implemented plan — [rfMap](tasks/rfMap.md)
- [../tasks/rfMap/_validation/PLAN_rf_estimation_pipeline.md](../tasks/rfMap/_validation/PLAN_rf_estimation_pipeline.md)
  — RF-centre estimation pipeline from LGN probe placement to microstimulation, with simulation
  findings (2026-06-02) — plan — [rfMap](tasks/rfMap.md), [sacc_to_phosph](tasks/sacc_to_phosph.md)
- [../tasks/SRS_mooving/README_SRS_MOVING.md](../tasks/SRS_mooving/README_SRS_MOVING.md) — install
  notes and moving geometry for SRS_mooving; depends on `tasks/SRS_Task_Smooth` — reference —
  [SRS_mooving](tasks/SRS_mooving.md)

## Analysis-code READMEs

- [../tasks/SRS_Task_Smooth/Simple_analysis/README.md](../tasks/SRS_Task_Smooth/Simple_analysis/README.md)
  — one-page 4 × 2 SRS behavioral summary — reference — [SRS_Task_Smooth](tasks/SRS_Task_Smooth.md)
- [../tasks/SRS_Task_Smooth/SRS_behavior_analysis_2/README.md](../tasks/SRS_Task_Smooth/SRS_behavior_analysis_2/README.md)
  — standalone SRS analysis pipeline over `trialXXXX.mat` files — reference — [SRS_Task_Smooth](tasks/SRS_Task_Smooth.md)
- [../tasks/SRS_Task_Smooth/SRS_behavior_analysis_2/CHANGELOG.md](../tasks/SRS_Task_Smooth/SRS_behavior_analysis_2/CHANGELOG.md)
  — version-2 changes (statistical tests, figure documentation) — changelog — [SRS_Task_Smooth](tasks/SRS_Task_Smooth.md)
- [../tasks/SRS_mooving/Simple_analysis/README.md](../tasks/SRS_mooving/Simple_analysis/README.md)
  — moving-target diagnostic: identity / value vs screen-geometry strategies — reference —
  [SRS_mooving](tasks/SRS_mooving.md)

Related: [timeline](timeline.md) (when each doc was added), [overview](overview.md).
