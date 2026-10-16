---
title: +pds function catalog
type: library
category: Library
summary: One-line catalog of every function in the +pds package, grouped by area, with the concept page that covers each
sources:
  - +pds/ @ a663e26256
verified_at: e48934be
updated: 2026-10-15
---

# +pds function catalog

`+pds/` is the shared library. Functions are called package-qualified, as
`pds.<name>`. This page lists every `.m` file in it, excluding `.asv` autosaves and
the untracked `*-Murawski-Desktop.m` sync copies. Each entry gives the name, what
the function does, and the page that covers it in depth.

"No current caller" means a repo-wide grep found no call outside `+pds` itself.
The `+test/` package and the `+test/tasks` folder were not searched; they hold an
older snapshot of `+pds`, `+pdsActions` and `+rigConfigFiles`.

## Session setup and the GUI

- `initTaskMetadata` — sets `p.init.taskCode`, the date/time stamps, the
  output/session folder paths and the `_init`/`_next`/`_run`/`_finish` file names. → [data saving](../concepts/data-saving.md)
- `initRigConfigFile` — runs the rig config named in `p.init.rigConfigFile` and
  copies `p.rig.baseReward` into `rewardDurationMs`. → [rig configs](rig-configs.md)
- `initTrialVariables` — legacy loop that sets each variable listed in
  `c.trialVars` on an old `c` struct to its initial value. No current caller. → [trial variables and GUI](../concepts/trial-variables-and-gui.md)
- `setStringListForGui` — lists the field names of a struct, one level deep as
  `a.b`, for the GUI parameter menus. Used by `PLDAPS_vK2_GUI.m`. → [GUI](gui.md)
- `stopRunButton` — turns off the GUI Run toggle (`Tag 'runButton'`) so the trial
  loop stops. Used by rfMap and barsweep when their session is complete. → [quintet and GUI loop](../concepts/quintet-and-gui-loop.md)
- `structNames` — recursively lists the fully qualified field names of a struct.
  No current caller. → [p struct](../concepts/p-struct.md)

## Display, geometry and drawing helpers

- `initDataPixx` — opens the PTB window with VPixx L48 dual CLUTs, measures the
  refresh rate and configures the DataPixx. → [DataPixx and timing](../concepts/datapixx-and-timing.md)
- `initPsychToolbox` — opens a PTB window without the DataPixx and measures the
  refresh rate. Used by human_psychophysical_threshold. → [DataPixx and timing](../concepts/datapixx-and-timing.md)
- `measureRefresh` — gets the refresh rate and frame duration from
  `GetFlipInterval`; warns if the rate is not near 100 or 120 Hz. → [DataPixx and timing](../concepts/datapixx-and-timing.md)
- `deg2pix` — converts degrees of visual angle to pixels using
  `p.rig.viewdist`, `screenhpix` and `screenh`. → [rig configs](rig-configs.md)
- `pix2deg` — the inverse of `deg2pix`. → [rig configs](rig-configs.md)
- `defineGridLines` — builds `p.draw.gridXY`, the experimenter-display grid with
  `p.draw.gridSpacing` spacing. → [drawing and postFlip](../concepts/drawing-and-postflip.md)
- `joyRectFillCalc` — maps joystick voltage to the filled part of the
  joystick-bar rectangle. → [eye and joystick](../concepts/eye-and-joystick.md)
- `richColors` — fixed 16-color palette. No current caller. → [color and calibration](../concepts/color-and-calibration.md)
- `i1MexFolder` — absolute path of `externalTools/i1` (the i1Pro MEX). → [color and calibration](../concepts/color-and-calibration.md)

## DataPixx schedules and timing

- `getTimes` — returns paired PTB `GetSecs` and DataPixx times. → [DataPixx and timing](../concepts/datapixx-and-timing.md)
- `setSchedules` — sets up the per-trial ADC schedule and optional PC-audio
  passthrough. → [DataPixx and timing](../concepts/datapixx-and-timing.md)
- `startEphysAndSchedules` — calls `startOmniPlex`, then starts the ADC schedule. → [DataPixx and timing](../concepts/datapixx-and-timing.md)
- `readDatapixxBuffers` — reads the trial's ADC buffer (eye X/Y, pupil, joystick,
  time) and the DIN log, then stops both. → [DataPixx and timing](../concepts/datapixx-and-timing.md)
- `correctForLatency` — offline correction for strobe-to-screen and scan-row
  latency (`rigA_viewpixx` only). No current caller. → [DataPixx and timing](../concepts/datapixx-and-timing.md)

## Audio

- `initAudio` — synthesizes the tones (right 300 Hz, wrong 150 Hz, noise,
  alpha binaural beats, sweep) and loads them into DataPixx audio memory. →
  [actions](../concepts/actions.md) (audio actions); tone playback is the task's own `playTone`

## Eye and joystick

- `getEyeJoy` — reads ADC eye position (4 deg/V) and joystick voltage into
  `p.trVars`. → [eye and joystick](../concepts/eye-and-joystick.md)
- `getMouse` — stores the cursor position in `p.trVars.mouseCursorX/Y`, for mouse
  simulation of the eye. → [eye and joystick](../concepts/eye-and-joystick.md)
- `initEyelink` — connects to the EyeLink, opens an EDF file and runs tracker
  setup. → [eye and joystick](../concepts/eye-and-joystick.md)
- `getEyelink` — reads the newest EyeLink gaze sample in pixels. → [eye and joystick](../concepts/eye-and-joystick.md)
- `eyeInWindow` — degree-based fixation/target/image window test, honoring
  `passEye`. → [eye and joystick](../concepts/eye-and-joystick.md)
- `eyeInWindowEL` — pixel-based window test for EyeLink gaze. → [eye and joystick](../concepts/eye-and-joystick.md)
- `eyelinkInWindow` — pixel gaze compared against `*Deg` window sizes. No current
  caller. → [eye and joystick](../concepts/eye-and-joystick.md)
- `checkEye` — square window around zero. No current caller. → [eye and joystick](../concepts/eye-and-joystick.md)
- `checkJoy` — `Joy > Th || pass`. No current caller. → [eye and joystick](../concepts/eye-and-joystick.md)
- `joyHeld` — joystick state (pressed / released / in between) with hysteresis,
  from `p.rig.joyThresh` and `joyPressVoltDir`. → [eye and joystick](../concepts/eye-and-joystick.md)
- `joyHeld_version1` — earlier single-threshold version (the file declares its
  function as `joyHeld`). No current caller. → [eye and joystick](../concepts/eye-and-joystick.md)
- `joyReld` — release test on an old `c` struct. No current caller. → [eye and joystick](../concepts/eye-and-joystick.md)
- `waitForJoystickRelease` — post-trial loop that waits for joystick release and
  for any reward to finish. → [eye and joystick](../concepts/eye-and-joystick.md)
- `smoothDiff` — 29-tap smoothing differentiator for eye velocity. No current
  caller; tasks such as gSac_4factors keep a local `smoothdiff`. → [eye and joystick](../concepts/eye-and-joystick.md)

## Reward and stimulation

- `deliverReward` — +4 V DAC pulse of `rewardDurationMs`; strobes `reward`;
  records the time of the first reward. → [reward](../concepts/reward.md)
- `freeReward` — the same pulse, strobing `freeReward`. → [reward](../concepts/reward.md)
- `deliverOptoStim` — constant or pulsed DAC waveform on `optoDacChan`; strobes
  `optoStimOn`. → [ephys integration](../concepts/ephys-integration.md)

## Strobe codes and state names

- `initCodes` — the registry of all strobe codes (HOLY; see CLAUDE.md). →
  [strobe codes](../concepts/strobe-codes.md), [registry](../reference/strobe-codes.md)
- `classyStrobe` — handle class that queues (`addValue`, `addValueOnce`) and sends
  (`strobeList`, `strobeNow`) 15-bit words on the DataPixx digital output, and
  keeps `strobedList`. → [strobe codes](../concepts/strobe-codes.md)
- `strobeTrialData` — loops over `p.init.strobeList` and queues and strobes
  (code, value) pairs. → [strobe codes](../concepts/strobe-codes.md)
- `code2str` — code value(s) → code name(s) from a `codes` struct. → [strobe codes](../concepts/strobe-codes.md)
- `code2strView` — the same as `code2str`, but it also prints and returns
  `"name - value"` strings. → [strobe codes](../concepts/strobe-codes.md)
- `str2code` — code name(s) → value(s). → [strobe codes](../concepts/strobe-codes.md)
- `num2state` — state number(s) → state name(s) from `p.state`. → [run-loop state machine](../concepts/run-loop-state-machine.md)
- `state2num` — state name(s) → number(s); it looks names up in
  `p.init.codes`. → [run-loop state machine](../concepts/run-loop-state-machine.md)
- `barsweepRampFilterEnum` — maps an iradon filter name to an integer 1–4 for the
  barsweep strobeList. → [barsweep](../tasks/barsweep.md)

## Ephys: Omniplex, Ripple, thresholds, drive

- `openPortToServer` — TCP client to the Omniplex-PC MATLAB server (called from
  rig configs). → [ephys integration](../concepts/ephys-integration.md)
- `getOmniplexData` — asks for and receives n×4 spike/strobe data over TCP. → [ephys integration](../concepts/ephys-integration.md)
- `startOmniPlex` — raises the Plexon RSTART digital-out bit. → [ephys integration](../concepts/ephys-integration.md)
- `stopOmniPlex` — lowers RSTART. → [ephys integration](../concepts/ephys-integration.md)
- `initRipple` — connects to the Ripple NIP and gets recording and stimulation
  channels; skipped when `connectRipple` is false. → [ephys integration](../concepts/ephys-integration.md)
- `getRippleData` — per-trial spike times and clusters plus digital-in events
  from Ripple. → [ephys integration](../concepts/ephys-integration.md)
- `xippmex` — help file for the Ripple MEX `+pds/xippmex.mexa64`, which is called
  as `pds.xippmex`. → [ephys integration](../concepts/ephys-integration.md)
- `setSpikeThreshFromRMS` — sets Ripple thresholds to −mult·σ, with σ estimated
  from noise snippets. → [ephys integration](../concepts/ephys-integration.md)
- `recheckSpikeThresholds` — re-estimates σ mid-session; optionally adjusts
  thresholds. → [ephys integration](../concepts/ephys-integration.md)
- `monitorSpikeThresholds` — passive monitor of per-channel rate drift against a
  baseline. → [ephys integration](../concepts/ephys-integration.md)
- `servo` — text-command socket client for the LSR electrode drive. No current
  caller. → [ephys integration](../concepts/ephys-integration.md)

## Online plotting

- `plotWindowSetup` — creates or reuses the hidden `OnlinePlotWindow` figure.
  Used only by `tasks/gSac`; other tasks have local versions. → [online plotting](../concepts/online-plotting.md)
- `heatMapPlotGUI` — standalone saccade/RF heatmap and raster GUI. No current
  caller. → [online plotting](../concepts/online-plotting.md)
- `initChannelBrowser` — per-channel RF browser uifigure (rfMap, barsweep). → [online plotting](../concepts/online-plotting.md)
- `updateChannelBrowserLayout` — lays out the selected channel tiles in a grid. → [online plotting](../concepts/online-plotting.md)
- `parseChannelRange` — `"1-16, 33"` → channel vector. → [online plotting](../concepts/online-plotting.md)
- `formatChannelRange` — channel vector → compact range string. → [online plotting](../concepts/online-plotting.md)
- `pdfSave` — saves a figure as a vector PDF. → [data saving](../concepts/data-saving.md)

## Data saving and loading

- `saveP` — writes `p.mat` on trial 1 and `trialNNNN.mat` for every started
  trial. → [data saving](../concepts/data-saving.md)
- `loadP` — rebuilds a session `p` with struct-array `trVars` and `trData`. → [data saving](../concepts/data-saving.md)
- `unifyStructArray` — cell array of structs → struct array with the union of
  their fields. → [data saving](../concepts/data-saving.md)
- `storeDataInPDS` — empty stub. No current caller. → [data saving](../concepts/data-saving.md)
- `autoBackup` — empty stub. No current caller. → [data saving](../concepts/data-saving.md)
- `regenerateStim_mcd` — offline regeneration of "mcd" task dot stimuli from saved
  random seeds, checked against `stimLastFrame`. No current caller. → [data saving](../concepts/data-saving.md)

## Legacy stubs

- `abortTrial` — old `c`-struct fixation-break handler (strobes `fixbreak`,
  sets `c.trialState = 3`, plays the low tone). No current caller.
- `trialEndFun` — empty function body. No current caller.

## Related

- [pdsActions](pdsActions.md), [rig configs](rig-configs.md), [GUI](gui.md)
- [Overview](../overview.md)
