# SRS_mooving Simple_analysis

`RUN_SIMPLE_MOVING_ANALYSIS.m` creates a compact diagnostic analysis for the moving-target SRS task.

The primary question is whether behavior follows target identity/value or screen geometry.

Key distinction:

- `P(right hemi | L/R available)` is computed only when one target is left of fixation and the other is right. If both targets are on the left, the trial is excluded from this denominator because a right-hemifield choice was impossible.
- `P(rightmost target)` is computed whenever the two targets have different X coordinates. It therefore remains valid when both targets are left or both are right.
- The same logic is used for `upper/lower hemifield` versus `uppermost/lowermost target`.

The strategy table compares identity/value candidates (`high reward identity`, `high salience identity`, `T1`, `T2`, previous identity) with spatial candidates (`rightmost`, `leftmost`, `uppermost`, `lowermost`, and absolute hemifield rules).

By default, forced correction repeats are excluded from the primary strategy figure because the repeated condition is experimentally imposed. A second CSV including all completed choices is always exported.

Outputs are written under `Simple_analysis/results/<session>` and `Simple_analysis/figures/<session>`.
