---
title: Online plotting
type: concept
category: Concepts
summary: How tasks build and update between-trial figures (plotWindowSetup/updateOnlinePlots, saccade GUI, per-channel RF browser, PSTH_plotter)
sources:
  - +pds/plotWindowSetup.m @ 5312c10a3d
  - +pds/heatMapPlotGUI.m @ bbf6e6f241
  - +pds/initChannelBrowser.m @ 3ad9ee7186
  - +pds/updateChannelBrowserLayout.m @ 7333e1542d
  - +pds/parseChannelRange.m @ b804fbaf7a
  - +pds/formatChannelRange.m @ 4851d443ce
  - +pds/pdfSave.m @ 949e4ed384
  - tasks/gSac_4factors/supportFunctions/extraWindowSetup.m @ 8afbf8b893
  - tasks/gSac_4factors/supportFunctions/updateOnlinePlots.m @ af480d71f3
  - tasks/SRS_Task_Smooth/supportFunctions/plotWindowSetup.m @ 8ba0ddd675
  - tasks/joystick_release_for_stim_change_and_dim/supportFunctions/alignSpikes.m @ a6df427ac1
  - tasks/rfMap/supportFunctions/initSTAChannelBrowser.m @ 8e90340f2a
verified_at: e48934be
updated: 2026-10-15
---

# Online plotting

Online figures are drawn in `_finish.m`, between trials, never inside the
frame loop in `_run.m` (see the caveat in CLAUDE.md about slow operations in
`_run`). Almost all plotting code is task-specific and lives in each task's
`supportFunctions/`. The shared `+pds` pieces are the generic window helper and
the per-channel browser.

## The usual pattern: setup in `_init`, update in `_finish`

1. **`_init.m`** calls a setup function that creates figures and stores their
   handles in `p.draw.*`:
   - Most tasks call their own `supportFunctions/plotWindowSetup.m`. This
     includes fixate, the joystick_* tasks, joystickPress, nfl, scd, tokens,
     reward_calibration, SRS_Task_Smooth, human_psychophysical_threshold,
     seansFirstTask and sacc_to_phosph.
   - Only `tasks/gSac` calls the shared `pds.plotWindowSetup`. That version creates
     (or reuses) a figure named `OnlinePlotWindow`, stores it in
     `p.draw.onlinePlotWindow`, and leaves it hidden.
   - conflict_task, gSac_4factors, gSac_contrast and gSac_jph use
     `extraWindowSetup` instead.
2. **`_finish.m`** calls the task's `updateOnlinePlots(p)`, usually after
   `pds.saveP` and the status update. Some tasks call it only on successful
   trials.

Examples:

- **gSac_4factors.** `extraWindowSetup` opens the gaze-vs-time figure when
  `p.trVarsInit.wantOnlinePlots` is true, and the saccade-mapping GUI
  (`saccadeGUI`, stored in `p.rig.guiData`) when `setTargLocViaGui` is true. Its
  `updateOnlinePlots` always updates the saccade metrics plots (peak velocity, RT,
  error by target location). It draws gaze and velocity traces only when
  `wantOnlinePlots` is set. Traces are put on a common time base with
  `trialStartDP` (see [DataPixx and timing](datapixx-and-timing.md)).
- **SRS_Task_Smooth.** `plotWindowSetup` builds a tiled behavioral dashboard and
  sets up `p.status.onlinePlot` storage (trial type, choices, RT, reward history,
  …). Behavioral panels use successful trials only, while the status panel
  updates after every attempt.
- **Psychometric plots.** Many joystick/scd-era tasks also have
  `actions/supportFunctions/plotFunctions/plot_hitP_foilFaP*.m`. The
  `summarizeBehaviorBasic` action calls them through `mkfig.behaviorBasic`.

## PSTH_plotter (App Designer)

`joystick_release_for_stim_change_and_dim` and `joystickPress_playMovie` contain
`PSTH_plotter.mlapp` and `psthComponent.mlapp`. Their `alignSpikes(p)` (called
from `_finish.m`) works as follows:

- On first use it creates the app in `p.draw.psthPlotterApp` and sets up empty
  `spikeTimes`, `spikeClusters` and an `eventTimes` struct whose fields mirror
  `p.trData.timing`.
- Each trial it maps the Ripple-recorded event codes (`p.trData.eventValues`)
  to timing field names. It then passes `p.trData.spikeTimes`, `spikeClusters`
  and the event times to the app's `updateData` method.

## Per-channel RF browser (rfMap, barsweep)

**`pds.initChannelBrowser(nCh, tileKind, opts)`** builds a `uifigure`:

- **Left column:** a channel listbox, a range-syntax edit box, select-all and
  deselect-all buttons, and a per-channel/global CLim toggle.
- **Right side:** a grid of `nCh` panels, created once and reused. The tile kind
  `'image+line'` (rfMap STA) shows an image above a short lag-power line with a
  peak marker. `'image'` (rfMap checkerboard, barsweep) shows only the image.
- **State:** callbacks keep their state in the figure's `UserData`, so callers do
  not need to forward selection events. The returned `bd` struct holds all handles
  and is passed to each task's own update routine every trial. Those routines are
  `updateSTAChannelBrowser`, `updateCheckerboardChannelBrowser` and barsweep's
  equivalent, wrapped by `initSTAChannelBrowser`, `initCheckerboardChannelBrowser`
  and `initBarsweepChannelBrowser`.

**`pds.updateChannelBrowserLayout(bd)`** shows only the selected panels:

- The grid uses 1 column for up to 2 channels, 2 columns for up to 4, and
  `ceil(sqrt(n))` columns otherwise.
- It resizes the grid and toggles `Visible`, without destroying or recreating
  panels.

**Channel-range text.** `pds.parseChannelRange(str, nCh)` turns text such as
`"1-16, 33, 40-50"` into a sorted, unique channel vector clipped to
`[1, nCh]`. `pds.formatChannelRange(chans)` does the reverse.

**Export.** `pds.pdfSave` cannot save a uifigure directly.
`initSTAChannelBrowser` copies the visible tiles into a classic figure and then
calls `pds.pdfSave` on it.

Threshold drift messages from `pds.monitorSpikeThresholds` go to the command
window and `p.status.threshMon` (see [ephys integration](ephys-integration.md)).

## heatMapPlotGUI

`pds.heatMapPlotGUI` is a standalone saccade/RF mapping GUI from the original
code import. It has:

- a heatmap over target locations, with a contour and colorbar;
- rasters at three alignments;
- RF-fit, timing-window and map-type panels;
- a dummy-data generator for testing.

It stores its data in a `SimpleClass` object with a `PDS` property. No current
task calls it.

## Related

- [Quintet and GUI loop](quintet-and-gui-loop.md), [data saving](data-saving.md)
- [gSac family](../tasks/family-gsac.md), [mapping family](../tasks/family-mapping.md), [SRS family](../tasks/family-srs.md)
- [+pds catalog](../library/pds-functions.md)
