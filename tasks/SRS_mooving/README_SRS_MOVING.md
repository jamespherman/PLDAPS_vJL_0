# SRS_mooving

Moving-target variant of `SRS_Task_Smooth` designed to dissociate target identity/value from fixed screen location.

## Install

Copy the complete `tasks/SRS_mooving` folder into the repository and replace `+pds/initCodes.m` with the version supplied in the update package.

`SRS_mooving` requires the sibling folder `tasks/SRS_Task_Smooth` because reward, salience, display and state-machine logic are inherited from the maintained base task.

Use `srsMoving_Moretraining_settings.m` for the moving-target training variant.

## Moving geometry

On every normal trial, T1 and T2 are placed on the same eccentricity circle. T1 is uniform over 0 to 360 degrees and T2 is sampled with a configurable minimum angular separation. Forced correction repeats restore the exact original coordinates.

Default settings:

```matlab
p.trVarsInit.movingTargetEccDeg = 10;
p.trVarsInit.movingTargetMinSeparationDeg = 90;
```

## Important spatial definitions

There are two different notions of "right":

1. **Right hemifield**: target X is to the right of fixation. This is an absolute screen location.
2. **Rightmost target**: the target with the larger X coordinate. This is a relative comparison between T1 and T2.

If both targets are left of fixation, a right-hemifield choice is impossible. Such a trial is excluded from `P(right hemi | L/R available)`, but it is still included in `P(rightmost target)`.

The same distinction is implemented for upper/lower hemifield versus uppermost/lowermost target.

## Correction trials

Horizontal correction is allowed only when the targets straddle the vertical meridian, so one target is actually available on each side. Same-hemifield target pairs can never trigger a left/right correction.

If the inherited `correctionBothSides` option exists and is enabled, incorrect low-reward choices can trigger from either side, still only when both left and right are available. The optional RIGHT reward reduction is applied only to a correction that was triggered by a right-side error.

## Online status

The moving-task status reports separately:

- `P(T1 identity)`
- `P(right hemi | L/R available)`
- `P(rightmost target)`
- `P(upper hemi | U/D available)`
- `P(uppermost target)`

This avoids treating target availability as a behavioral bias.

## Simple_analysis

`Simple_analysis/RUN_SIMPLE_MOVING_ANALYSIS.m` compares candidate identity/value strategies with spatial strategies:

- high reward identity
- high salience identity
- T1 / T2 identity
- repeat previous identity
- rightmost / leftmost
- uppermost / lowermost
- right / left hemifield when both are available
- upper / lower hemifield when both are available

It also computes an availability-normalized angular selection profile. Forced correction repeats are excluded from the primary strategy figure by default, while a second strategy CSV including all completed choices is exported.

## Ephys codes

The moving task has unique task code `32024` and moving geometry paired-strobe codes `20054` through `20064`. `srsMoving_init` refuses to start if the supplied `+pds/initCodes.m` has not been installed.
