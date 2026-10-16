---
title: Salience vs. reward choice family
type: family
category: Tasks — salience/reward choice family
summary: Two-alternative saccade-choice tasks that pit stimulus salience against reward (SRS_Task_Smooth, SRS_mooving, conflict_task) and the dot-numerosity discrimination tasks that share their two-target layout (seansFirstTask, numerosity)
status: active
sources:
  - tasks/SRS_Task_Smooth/srsSmooth_settings.m @ 34495a80b8
  - tasks/SRS_Task_Smooth/supportFunctions/nextParams.m @ c33d8e5c32
  - tasks/SRS_mooving/srsMoving_settings.m @ 14f3a7431d
  - tasks/conflict_task/conflict_task_settings.m @ 4467fe7e8c
  - tasks/conflict_task/supportFunctions/nextParams.m @ a0f77e8809
  - tasks/seansFirstTask/seansFirstTask_settings.m @ 140372910d
  - tasks/numerosity (WiP)/numerosity_settings_spatial.m @ cc66bf1073
verified_at: e48934be
updated: 2026-10-15
---

# Salience vs. reward choice family

These tasks share one trial skeleton: the subject fixates a central point, one or two
peripheral targets appear, the fixation point goes off (the go signal), and the subject
saccades to a target and holds it. What differs is what decides the outcome of the choice.

- **Salience vs. reward** ([SRS_Task_Smooth](SRS_Task_Smooth.md), [SRS_mooving](SRS_mooving.md),
  [conflict_task](conflict_task.md)): both targets are rewarded, one is more salient (larger contrast
  with the background) and one pays more. Congruent trials put both on the same target,
  conflict trials put them on opposite targets. The choice shows which one controls behavior.
- **Numerosity discrimination** ([seansFirstTask](seansFirstTask.md), [numerosity](numerosity.md)):
  a brief stimulus of one or two elements is shown, and the subject must saccade to the target
  that matches the count (target 1 for "one", target 2 for "two"). numerosity adds trials where
  the "stimulus" is microstimulation through one or two electrodes.

## How they differ

| | SRS_Task_Smooth | SRS_mooving | conflict_task | seansFirstTask | numerosity |
|---|---|---|---|---|---|
| Status | active | active | active | active | wip |
| Relationship | base SRS task | wrapper around SRS_Task_Smooth (reuses its quintet and supportFunctions) | separate implementation, based on gSac_4factors | separate implementation | copy of seansFirstTask, then edited |
| Choice outcome | reward by chosen target **identity** (T1 horizontal / T2 vertical rectangle) | same as SRS_Task_Smooth | reward by chosen **side** (left/right) | correct / wrong target | correct / wrong target |
| Target locations | two fixed locations (default ±10°, 0°); identity-to-side mapping randomized | both targets on a 10° circle, angles resampled every trial | 4 left × 4 right locations at 10° | fixed positions (`preset_quatro` targets) | inherited from seansFirstTask |
| Salience manipulation | DKL hue contrast (smooth: continuous 10–180°; classic: 180° vs 20°), or red luminance (DKL CLUT or direct RGB) | as SRS_Task_Smooth, but `srsMoving_finish` accepts only `salienceType` 1 (hue) and 2 (DKL luminance) | DKL hue contrast 180° vs 45° | none | none |
| Reward structure | unsignaled blocks; rich/poor block means drawn per block, Gaussian trial noise | same as SRS_Task_Smooth | three fixed phases (1:1, then big-right, then big-left, ~85% canonical) | fixed `rewardDurationMs` | fixed `rewardDurationMs` |
| Timing manipulation | fixed target-to-go delay | same | target onset 0 or +125 ms relative to go signal (`deltaT`) | stimulus timing; `temporalOverlap` sets simultaneous vs. sequential elements | spatial vs. temporal settings files |
| Joystick | not required | not required | required unless `passJoy` (default 1) | required unless `passJoy` (default 1) | not used (trial goes straight to fixation) |
| Strobed task code | none set (see page) | 32024 | 32016 | 32013 | 32017 |

## Shared conventions

- **Salience by hue contrast.** For conflict_task the rule is documented in
  [CLAUDE.md](../../CLAUDE.md) ("Conflict Task: Salience via DKL Color Contrast"): each target gets
  its own hue, and salience is the hue distance from the background. SRS_Task_Smooth uses the same
  two background hues (DKL 0° and 180°) but different target offsets. See
  [color and calibration](../concepts/color-and-calibration.md).
- **Shared strobe codes.** SRS_Task_Smooth's strobeList reuses conflict_task's codes 16021–16024 and 16029
  (`highRewardLocation`, `highSalienceLocation`, `chosenTarget`, `outcomeCode`, `choseHighSalience`),
  with one difference: side 1 means **left** in conflict_task and **right** in SRS. Read the side
  convention from the task before decoding. See [strobe codes](../concepts/strobe-codes.md) and the
  [strobe registry](../reference/strobe-codes.md).
- **Condition schedules** remove a row only when its trial succeeds; failed rows stay eligible
  ([trial structure](../concepts/trial-structure.md)).

## Related

- [Run loop and state machine](../concepts/run-loop-state-machine.md),
  [drawing and postFlip](../concepts/drawing-and-postflip.md), [reward](../concepts/reward.md)
- [gSac family](family-gsac.md) (conflict_task was built from gSac_4factors)
- [Mapping family](family-mapping.md) (sacc_to_phosph, the other Ripple-microstimulation task)
- [Ephys integration](../concepts/ephys-integration.md) (Ripple stimulation used by numerosity)
