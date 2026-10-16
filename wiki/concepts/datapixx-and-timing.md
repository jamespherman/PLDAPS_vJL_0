---
title: DataPixx and timing
type: concept
category: Concepts
summary: How the VIEWPixx/DATAPixx is opened, how ADC/DIN schedules run per trial, and how PTB and DataPixx clocks are related
sources:
  - +pds/initDataPixx.m @ d2924f59b6
  - +pds/initPsychToolbox.m @ 4a6742d354
  - +pds/measureRefresh.m @ 00442b80b3
  - +pds/getTimes.m @ 89958e4e79
  - +pds/setSchedules.m @ 8ecc587fd2
  - +pds/startEphysAndSchedules.m @ 8226d3f44c
  - +pds/readDatapixxBuffers.m @ 503626d7b5
  - +pds/correctForLatency.m @ 8d731924d8
  - tasks/gSac_4factors/gSac_4factors_init.m @ 67777bb049
  - tasks/gSac_4factors/gSac_4factors_next.m @ f1bd18e88d
  - tasks/gSac_4factors/gSac_4factors_run.m @ 9aa849922b
  - tasks/gSac_4factors/gSac_4factors_finish.m @ f800fddb30
verified_at: e48934be
updated: 2026-10-15
---

# DataPixx and timing

All monkey rigs run the display, analog inputs (eye, pupil, joystick), digital
output (strobes) and DAC output (reward, opto) through a VPixx VIEWPixx/DATAPixx.
The `+pds` functions below wrap the `Datapixx(...)` and `Screen(...)` calls. The
per-trial order shown here is the one used by current tasks such as
`tasks/gSac_4factors`; older tasks follow the same pattern with small variations.

## Per-session: opening the display and the DataPixx

`pds.initDataPixx(p)` (called from each task's `_init.m`, after the task's own
`initClut`):

- Sets PTB text preferences, then opens a PsychImaging window on screen 1.
- Unless the task plays a movie (`p.draw.movie`) or uses token stimuli
  (`p.stim.token`), it adds the `EnableDataPixxL48Output` task, which gives the
  subject display and the experimenter (console) display separate CLUTs. It loads
  `[p.draw.clut.subCLUT; p.draw.clut.expCLUT]` as the combined gamma table. See
  [color and calibration](color-and-calibration.md).
- Measures the refresh rate with `pds.measureRefresh` and writes
  `p.rig.refreshRate` and `p.rig.frameDuration`, replacing the values the
  [rig config](../library/rig-configs.md) predicted.
- Opens the DataPixx, stops all schedules, disables DIN debounce, starts the
  DIN log, zeros the digital outputs, disables DAC→ADC loopback and ADC free-running
  ("for microsecond-precise sample windows"), and enables the scanning backlight.

`pds.initPsychToolbox(p)` is the non-VPixx alternative. It opens a 32-bit
floating-point window on the highest-numbered screen and also calls
`pds.measureRefresh`. Only `tasks/human_psychophysical_threshold` uses it, together
with an EyeLink (see [eye and joystick](eye-and-joystick.md)).

`pds.measureRefresh(window)` takes the frame duration from
`Screen('GetFlipInterval')`, falling back to `FrameRate`. It prints the measured
rate and warns (`pds:measureRefresh:unexpectedRefresh`) if it is more than 2 Hz from
both supported rig rates, 100 and 120 Hz.

## Per-trial schedule lifecycle

| Step | Where | Function | What happens |
|---|---|---|---|
| 1 | `_next.m` | `pds.setSchedules(p)` | If `p.rig.dp.useDataPixxBool`, sets up an ADC schedule on channels 0–3 at `p.rig.dp.adcRate` into a buffer at `p.rig.dp.adcBuffAddr` sized `adcRate * maxDurADC` samples. If `p.audio.pcPlayback` is set, it also routes microphone input to the audio output with a 2-sample delay. |
| 2 | `_next.m` | `pds.startEphysAndSchedules` | Calls `pds.startOmniPlex` (raises the Plexon RSTART bit, then waits 100 ms) and then starts the ADC schedule. See [ephys integration](ephys-integration.md). |
| 3 | `_run.m` start | `pds.getTimes` | `[p.trData.timing.trialStartPTB, p.trData.timing.trialStartDP]` is a PTB `GetSecs` and a `Datapixx('GetTime')` taken right after the same register read/write. |
| 4 | `_run.m` loop | `pds.getEyeJoy` | Reads the latest ADC voltages each loop iteration (see [eye and joystick](eye-and-joystick.md)). |
| 5 | `_finish.m` | `pds.readDatapixxBuffers(p)` | Reads every new ADC frame and stops the ADC schedule, then reads the DIN log and stops it. |

`readDatapixxBuffers` writes:

- `p.trData.eyeX`, `eyeY`, `eyeP`, `joyV`: raw voltages from ADC channels 0–3 (eye X,
  eye Y, pupil, joystick).
- `p.trData.eyeT`: the DataPixx timestamp of each ADC sample.
- `p.trData.dInValues`, `p.trData.dInTimes`: the digital-input log.

## Two clocks

There are two time bases. PTB (`GetSecs`) is used for all `p.trData.timing.*`
values, which are stored relative to `trialStartPTB`. The DataPixx clock stamps ADC
samples (`eyeT`) and DIN events. The pair captured by `pds.getTimes` at trial start
links the two. For example, `gSac_4factors_finish.m` (`calcSacParams`) puts the ADC
samples on the PTB clock with:

```matlab
T = p.trData.timing.trialStartPTB + p.trData.eyeT - p.trData.timing.trialStartDP;
```

Online plotting code (for example, `updateOnlinePlots` in gSac_4factors) uses the
same offset. Times recorded by Ripple or Omniplex use the recording system's own
clock and are aligned to behavior through strobes (see
[strobe codes](strobe-codes.md)).

Flip timestamps are PTB times. Visual-event times are assigned after the flip
through the postFlip mechanism (see [drawing and postFlip](drawing-and-postflip.md)
and CLAUDE.md). `p.rig.magicNumber` (from the rig config) is a small allowance
subtracted from the frame period when code decides whether a new flip is due. One
example is the flicker loop in `pds.waitForJoystickRelease`.

## Display latency correction

`pds.correctForLatency(t, y, rig)` is an offline helper. It subtracts a measured
strobe-to-screen latency and a per-LED-row top-to-bottom scan latency from event
times `t` at screen rows `y`. Only one rig is defined, `'rigA_viewpixx'` (8.7 ms
strobe-to-screen, 8 ms top-to-bottom, 1200 rows, 8 LED rows). No task calls it.

## Related

- [Eye and joystick](eye-and-joystick.md), [reward](reward.md),
  [ephys integration](ephys-integration.md)
- [Run-loop state machine](run-loop-state-machine.md), [drawing and postFlip](drawing-and-postflip.md)
- [Rig configs](../library/rig-configs.md) (`p.rig.dp.*` fields), [+pds catalog](../library/pds-functions.md)
