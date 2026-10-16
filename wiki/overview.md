---
title: Overview
type: meta
category: Start here
summary: Start here — what PLDAPS_vK2 is, how a session runs end to end, and where to read next
sources:
  - README.md @ 2cc15c52cc
  - CLAUDE.md @ 093adce265
  - PLDAPS_vK2_GUI.m @ cc365abfb9
verified_at: e48934be
updated: 2026-10-16
---

# PLDAPS_vK2 overview

PLDAPS_vK2 is a MATLAB framework for primate (and some human) behavioral and
neurophysiology experiments. It drives a Psychtoolbox display synchronized to a
VIEWPixx/DATAPixx, reads eye position and joystick voltage every frame, delivers liquid
reward, and strobes event codes to the neural recording system (Plexon Omniplex or Ripple
Grapevine) so behavior can be aligned with spikes offline. The README dates the framework to
2018; this repository's history runs 2022–2026 (see [timeline](timeline.md)).

The must-follow coding rules (strobe codes, postFlip timing, quintet structure) live in
[CLAUDE.md](../CLAUDE.md); this wiki explains the machinery behind them and documents every
task.

## How a session runs

1. **Load.** The experimenter runs `PLDAPS_vK2_GUI.m`, browses to a task's `*_settings.m`
   file, and the GUI calls it to build the [`p` struct](concepts/p-struct.md).
2. **Initialize.** `*_init.m` opens hardware ([DataPixx](concepts/datapixx-and-timing.md),
   Psychtoolbox, optionally [Omniplex/Ripple](concepts/ephys-integration.md)), loads
   [strobe codes](concepts/strobe-codes.md) (`p.init.codes = pds.initCodes`), builds the
   [condition table](concepts/trial-structure.md), sets up [color lookup tables](concepts/color-and-calibration.md)
   and [online plots](concepts/online-plotting.md).
3. **Trial loop.** While Run is on, the GUI calls `*_next.m` → `*_run.m` → `*_finish.m`
   ([quintet and GUI loop](concepts/quintet-and-gui-loop.md)). `_next` picks the trial's
   conditions and applies GUI edits ([trial variables](concepts/trial-variables-and-gui.md));
   `_run` executes the frame-by-frame [state machine](concepts/run-loop-state-machine.md),
   reading [eye and joystick](concepts/eye-and-joystick.md), drawing and time-stamping
   visual events at the flip ([postFlip](concepts/drawing-and-postflip.md)), and delivering
   [reward](concepts/reward.md); `_finish` strobes the per-trial `strobeList`, saves the
   trial ([data saving](concepts/data-saving.md)), updates status counters and plots, and
   decides which condition to repeat.
4. **Analysis.** Saved `p` files plus the ephys file's strobes reconstruct each trial. The
   [strobe code registry](reference/strobe-codes.md) maps every code; per-task data
   dictionaries (see the [docs catalog](docs-catalog.md)) describe saved fields.

Experimenter-facing extras: [action buttons](concepts/actions.md) in the GUI
([GUI structure](library/gui.md)), per-rig [configuration files](library/rig-configs.md).

## The code base at a glance

| Area | Where | Wiki |
|---|---|---|
| Shared library (73 functions) | `+pds/` | [+pds catalog](library/pds-functions.md) |
| GUI action buttons | `+pdsActions/`, `tasks/*/actions/` | [+pdsActions](library/pdsActions.md), [actions](concepts/actions.md) |
| Rig hardware settings | `+rigConfigFiles/` | [rig configs](library/rig-configs.md) |
| Tasks (26 directories) | `tasks/` | family pages below |
| Docs written alongside code | `data_dictionaries/`, `analysisPlanningDocs/`, task folders | [docs catalog](docs-catalog.md) |

## Tasks by family

- [gSac family](tasks/family-gsac.md): guided/memory saccades, culminating in the actively
  recorded [gSac_4factors](tasks/gSac_4factors.md).
- [Salience vs. reward choice family](tasks/family-srs.md): [SRS_Task_Smooth](tasks/SRS_Task_Smooth.md),
  [SRS_mooving](tasks/SRS_mooving.md), [conflict_task](tasks/conflict_task.md), plus the
  numerosity discriminations ([seansFirstTask](tasks/seansFirstTask.md), [numerosity](tasks/numerosity.md)).
- [RF mapping & fixation family](tasks/family-mapping.md): [rfMap](tasks/rfMap.md),
  [barsweep](tasks/barsweep.md), [sacc_to_phosph](tasks/sacc_to_phosph.md), [fixate](tasks/fixate.md).
- [Joystick family](tasks/family-joystick.md): training lineage ending in the attention task
  [joystick_release_for_stim_change_and_dim](tasks/joystick_release_for_stim_change_and_dim.md).
- [Detection, tokens & utility](tasks/family-scd.md): [scd](tasks/scd.md), [nfl](tasks/nfl.md),
  [tokens](tasks/tokens.md), [human_psychophysical_threshold](tasks/human_psychophysical_threshold.md),
  [reward_calibration](tasks/reward_calibration.md).

The full page list is in the [index](index.md). Before changing code, skim
[gotchas](gotchas.md) and the [open issues](open-issues.md) (verified suspected bugs, including
which ones affect already-recorded data).
