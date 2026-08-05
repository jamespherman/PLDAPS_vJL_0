# Simple_analysis

This folder runs the requested SRS behavioral analysis in **one MATLAB window**.

The window contains eight tabs:

1. Candidate strategies
2. Choice by task condition
3. Conditional associations
4. Conditional spatial influences
5. Conflict versus congruent
6. Previous reward versus identity switch
7. Reaction time
8. Text recap

Each plot tab contains a caption explaining:

- the axes;
- the statistical test;
- what the plot measures;
- the expected result under reward, salience, spatial-bias, or perseveration hypotheses.

## Installation

Place the complete folder here:

```text
tasks/SRS_Task_Smooth/Simple_analysis/
```

It must remain next to:

```text
tasks/SRS_Task_Smooth/SRS_behavior_analysis_2/
```

The simple analysis reuses `srs_load_session.m` and `srs_compute_statistics.m` from that folder.

## Use

1. Open `RUN_SIMPLE_ANALYSIS.m` in MATLAB.
2. Set `sessionFolder`, or leave it empty to use the folder picker.
3. Set `blockRange`.

The default is:

```matlab
blockRange = [8 Inf];
```

This analyzes block 8 through the final available block.

4. Run `RUN_SIMPLE_ANALYSIS.m`.

Only one figure window is opened. Use the tabs at the top to move between plots and the recap.

## Outputs

Outputs are created inside `Simple_analysis`:

```text
figures/<session_and_blocks>/
results/<session_and_blocks>/
```

The complete interactive tabbed window is saved as:

```text
simple_analysis_all_tabs.fig
```

Each tab is also exported separately as PNG and PDF without opening additional MATLAB windows. The results folder contains:

- `simple_analysis_summary.txt`
- `simple_analysis_results.mat`

Raw PLDAPS trial files are never modified.

## Inference rules

Behavioral inference uses only successful real eye-controlled two-target choices:

```text
passEye = 0
mouseEyeSim = 0
```

Single-target instruction trials are excluded from the choice plots and statistical tests.
