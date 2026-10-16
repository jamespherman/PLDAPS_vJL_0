---
title: Data saving and loading
type: concept
category: Concepts
summary: Where session output goes, what pds.saveP writes per session and per trial, and how pds.loadP / concatenation rebuild a session
sources:
  - +pds/saveP.m @ 299010d8a6
  - +pds/loadP.m @ 6e86bda495
  - +pds/unifyStructArray.m @ aeec93c427
  - +pds/initTaskMetadata.m @ 764e25c2d9
  - +pds/storeDataInPDS.m @ bcb990ac61
  - +pds/autoBackup.m @ 8eaaba3328
  - +pds/pdfSave.m @ 949e4ed384
  - +pdsActions/catOldOutput.m @ 2033964770
  - +pdsActions/dataToWorkspace.m @ fffa7ef56b
  - PLDAPS_vK2_GUI.m @ cc365abfb9
  - tasks/barsweep/barsweep_finish.m @ 31a2680a12
verified_at: e48934be
updated: 2026-10-15
---

# Data saving and loading

## Output layout

`pds.initTaskMetadata(p)` (called from `_settings.m` in conflict_task, gSac,
gSac_4factors, gSac_contrast, gSac_jph and seansFirstTask) defines the paths.
Other tasks set the same `p.init` fields directly in their settings files.
`p.init.pldapsFolder = pwd`, and the GUI leaves MATLAB in the PLDAPS root (it does not `cd`
into the task folder; see [quintet and GUI loop](quintet-and-gui-loop.md)), so `<root>` below is
the repository root. Exception: `srsMoving_settings.m` sets
`p.init.outputFolder = fullfile(thisTaskFolder, 'output')`.

```
<root>/output/                          p.init.outputFolder
<root>/output/figures/                  p.init.figureFolder
<root>/output/<yyyymmdd_tHHMM_taskName>/  p.init.sessionFolder (sessionId)
    p.mat              whole p on trial 1; p.status appended on later trials
    trial0001.mat ...  trVars, trData, status, init for each started trial
    <taskName>.zip     zipped copy of the task folder (trial 1)
```

`initTaskMetadata` also sets:

- `p.init.taskCode` from `codes.uniqueTaskCode_<taskName>` in `pds.initCodes`;
- the date and time stamps `date_1yyyy`, `date_1mmdd` and `time_1hhmm`, which have
  a leading 1 so leading zeros survive conversion to a number;
- the `_init`, `_next`, `_run` and `_finish` file names in `p.init.taskFiles`.

The GUI shows `outputFolder` and has a button to change it.

## `pds.saveP(p)`: called in `_finish.m` of every task except SRS_mooving

1. Creates `sessionFolder` if needed.
2. On `p.status.iTrial == 1`, saves `p` with `save(..., '-struct', 'p')`, so
   `p.mat` holds `init`, `trVars`, `rig` and the rest as top-level variables that
   load straight back into a struct. It also zips the directory that contains the
   task's `_run.m`.
3. If `p.trData.trialEndState == p.state.nonStart`, it returns. Trials the subject
   never started get no trial file and no status update.
4. Otherwise it appends `status` to `p.mat` and writes `trialNNNN.mat` (4-digit
   trial number) containing `trVars`, `trData`, `status` and `init`.

**Saved once per session:** everything in `p` at trial 1 (`rig`, `draw`, `audio`,
`state`, `init`, `trVarsInit`, …). **Saved per trial:** `p.trVars` (what was
actually used that trial), `p.trData` (timing, ADC traces, strobed list, spikes and
events), `p.status` (running counts) and `p.init`.

Some tasks change this to fit their data:

- barsweep and rfMap strip large RF accumulators from `p.init` before calling
  `saveP`.
- barsweep writes the full accumulator to a sidecar,
  `<sessionId>_barsweepRF.mat`, and appends `status` to `p.mat` even on nonStart
  trials.

See those task pages.

## Loading

`p = pds.loadP(sessionFolder)` (with no argument it opens a folder picker):

1. Loads `p.mat` into `p`.
2. Loads every `trial*.mat` file in the order `dir` returns them.
3. Turns the per-trial `trVars` and `trData` into struct arrays
   (`p.trVars(iTrial)`, `p.trData(iTrial)`) with `pds.unifyStructArray`. That
   function adds any missing field as `[]` and sorts fields alphabetically, so
   trials that ended early (and so lack some fields) can still be concatenated.
4. Warns (`pds:loadP:fieldMismatch`) if unifying added fields.

**Concatenated session file.** The GUI's concatenate button runs `pds.loadP` on
the current session and saves the result as `<outputFolder>/<sessionId>.mat`. If
the file is too large it retries with `-v7.3`. `pdsActions.catOldOutput` does the
same for a folder you pick, writing `<folder>.mat` next to it.

`pdsActions.dataToWorkspace` copies the live `p` into the base workspace as `p`.

## Other helpers

- `pds.pdfSave(fileName, paperSize, fh)` saves a figure as a vector PDF (Painters
  renderer, page sized to the figure). rfMap uses it to export the channel browser.
- `pds.storeDataInPDS` and `pds.autoBackup` are empty stubs: their bodies contain
  only comments. Nothing calls them.

## What each task saves

The data dictionaries in `data_dictionaries/` describe the saved fields for
specific tasks:

- `4factors_data_dictionary.md` (gSac_4factors)
- `gSac_jph_data_dictionary.md`
- `joystick_release_for_stim_change_and_dim_data_dictionary.md`
- `rfMap_data_dictionary.md`
- `tokens_data_dictionary.md`
- `srsClassic_Moretraining_data_dictionary.md`

For the strobed copy of trial variables in the ephys file, see
[strobe codes](strobe-codes.md).

## Related

- [The p struct](p-struct.md), [quintet and GUI loop](quintet-and-gui-loop.md), [GUI](../library/gui.md)
- [Docs catalog](../docs-catalog.md), [+pds catalog](../library/pds-functions.md)
