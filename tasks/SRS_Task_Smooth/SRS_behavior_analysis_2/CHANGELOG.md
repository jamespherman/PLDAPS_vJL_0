# Version 2 changes

## Statistical annotations

- Added exact two-sided binomial tests against 0.5 for individual choice proportions.
- Added two-sided Fisher exact tests for conflict-versus-congruent comparisons and conditional 2x2 associations.
- Added two-sided permutation tests for reaction-time differences, early-versus-late changes, temporal trends, and engagement change points.
- Added an unbinned logistic psychometric fit for the effect of signed salience evidence on T1 choice.
- Added optional multivariable logistic-regression summaries when `fitglm` is available.
- Added Benjamini-Hochberg false-discovery-rate correction within related exploratory test families.
- Added `ns`, `*`, `**`, and `***` labels directly to the relevant figure panels.
- Added Wilson 95% confidence intervals, odds ratios, and exact p/q values in the exported tables and report.

## Figure documentation

- Rebuilt all figure windows in English.
- Added descriptive axis titles, panel titles, legends, reference lines, and inferential annotations.
- Added a full panel-by-panel caption inside every MATLAB figure and every exported PNG/PDF.
- Added a fifth compact statistical-summary figure.
- Clarified that operational engagement analyses cannot directly measure subjective boredom.

## Output organization

Figures are now written to:

```text
SRS_behavior_analysis/figures/<session_name>/
```

Tables, reports, and MAT files are written to:

```text
SRS_behavior_analysis/results/<session_name>/
```

Raw PLDAPS session folders are not modified.
