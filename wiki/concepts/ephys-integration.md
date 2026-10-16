---
title: Ephys integration
type: concept
category: Concepts
summary: Plexon Omniplex and Ripple Grapevine connections, per-trial spike/event retrieval, spike-threshold tools, and opto/microstim output
sources:
  - +pds/openPortToServer.m @ 788ccfed7e
  - +pds/getOmniplexData.m @ 3b387a571c
  - +pds/startOmniPlex.m @ 83f532995b
  - +pds/stopOmniPlex.m @ 0d1eb30ab9
  - +pds/startEphysAndSchedules.m @ 8226d3f44c
  - +pds/initRipple.m @ 365c2e8143
  - +pds/getRippleData.m @ dd24a98b4e
  - +pds/xippmex.m @ d9ced2d029
  - +pds/setSpikeThreshFromRMS.m @ c8e1030754
  - +pds/recheckSpikeThresholds.m @ d799a6c8fd
  - +pds/monitorSpikeThresholds.m @ 7f911a1fcd
  - +pds/deliverOptoStim.m @ 114a9d1386
  - +pds/servo.m @ f6d17685de
  - +pdsActions/recheckThresholds.m @ 93f7c4f808
  - tasks/gSac_4factors/gSac_4factors_finish.m @ f800fddb30
  - tasks/rfMap/rfMap_init.m @ ac6c52e1a1
  - tasks/rfMap/rfMap_finish.m @ dacf5df585
verified_at: e48934be
updated: 2026-10-15
---

# Ephys integration

Behavior and neural data are aligned by strobing event codes on the DataPixx
digital output, which the recording system logs (see
[strobe codes](strobe-codes.md) and CLAUDE.md). Separately from that, the
framework can pull spikes and events back into MATLAB after each trial for online
analysis. Two recording systems are supported:

- Plexon **Omniplex**: older tasks.
- Ripple **Grapevine/Trellis**: current tasks, accessed with `xippmex`.

## Omniplex (Plexon)

- **Record gating.** `pds.startOmniPlex` raises digital-out bit 17 (RSTART) and
  waits 100 ms "otherwise subsequent strobes might not get registered".
  `pds.stopOmniPlex` lowers it and waits 50 ms.
- **Every trial.** `pds.startEphysAndSchedules` (called in `_next.m` of nearly
  every task) calls `startOmniPlex` and then starts the ADC schedule. This happens
  whichever recording system is in use.
- **Where `stopOmniPlex` is called.** In `_finish.m` of many tasks: fixate,
  gSac, gSac_contrast, gSac_jph, most joystick_* tasks, joystickPress, nfl,
  numerosity, sacc_to_phosph, scd, seansFirstTask, SRS_Task_Smooth and tokens.
  gSac_4factors does not call it.
- **TCP link.** If a rig config sets `p.rig.connectToOmniplex` (or `connectPLX` in
  `rigA_20200203` and `rigConfig_rigF_20190328`), it calls `pds.openPortToServer(p)`. This opens a TCP client
  (`tcpip`, IP `128.231.132.88`, port 30000) to a MATLAB instance on the Omniplex
  PC. A `BytesAvailableFcn` appends incoming doubles to `p.rig.tcpipObj.UserData`.
  `rigConfig_rig1/2` set `connectToOmniplex = false`.
- **Per-trial retrieval.** `pds.getOmniplexData(p)` sends `'0'`, waits until data
  arrives, and reshapes it into an n×4 `p.trData.spikeAndStrobeTimes`. Tasks
  that call it (for example the joystick_* tasks, gSac, scd, tokens and
  SRS_Task_Smooth) do so in `_finish.m` when `p.rig.connectToOmniplex` is true.

## Ripple

`pds.xippmex` is the Ripple MEX (`+pds/xippmex.mexa64`). Because it sits inside the
package it is called as `pds.xippmex(...)`. `+pds/xippmex.m` is only the help text
(xippmex 1.7.2.97).

**`pds.initRipple(p)`** (in `_init.m`):

- If `p.trVarsInit.connectRipple` is false, it sets `p.rig.ripple.status = false`
  with empty channel lists and returns. This is the simulation mode.
- Otherwise it opens xippmex and reads the NIP time twice, 50 ms apart.
  `status` is true only if the time advanced, meaning the NIP is powered on.
- It sets `p.rig.ripple.recChans` (micro + nano front ends) and
  `p.rig.ripple.stimChans`, and warns if either is empty.

Callers are barsweep, conflict_task, gSac_4factors, gSac_contrast, gSac_jph,
joystick_release_for_stim_change_and_dim, joystickPress_playMovie, numerosity,
rfMap and sacc_to_phosph.

**`pds.getRippleData(p)`** (in `_finish.m`, typically guarded by
`p.rig.ripple.status && ~isempty(p.rig.ripple.recChans)`):

- `xippmex('spike', recChans, 0)` returns spike times in 30 kHz ticks, which are
  divided by 30000 to give `p.trData.spikeTimes` in seconds.
- If `p.trVars.useOnlineSort` is set, it keeps only spikes with a nonzero online
  unit and stores the unit IDs in `p.trData.spikeClusters`. Otherwise it keeps all
  threshold crossings and stores the channel index in `spikeClusters`.
- `xippmex('digin')` returns the strobed words. The parallel-port values and their
  times (in seconds) go to `p.trData.eventValues` and `p.trData.eventTimes`.
- Ripple's buffer can hold spikes from before the trial. gSac_4factors
  (`postTrialGui`) keeps only spikes between the first and last event times.

### Spike thresholds (rfMap, barsweep)

- **`pds.setSpikeThreshFromRMS(p, chans, mult)`**, called once in `rfMap_init` and
  `barsweep_init`, imitates Trellis's "multiple of RMS" thresholding:
  1. Sets a −3 µV test threshold for 0.5 s.
  2. Pulls the noise-crossing snippets.
  3. Estimates σ per channel as the std of the first 10 (pre-trigger) samples.
     The header explains why it uses std rather than MAD: 0.2 µV quantization.
  4. Sets each lower threshold to −mult·σ (default mult 4). Channels with no
     crossings keep their previous threshold.
  5. Logs everything in `p.rig.ripple.spikeThresh`.
- **`pds.recheckSpikeThresholds(p, chans)`** repeats the estimate mid-session
  (0.3 s test window, intended for the ITI). It compares σ with the init-time σ
  and flags channels that changed by more than 50%. Thresholds are updated only
  if `p.trVarsInit.threshAutoAdjust` is true. Results go to
  `p.status.threshRecheck`. The GUI button is `pdsActions.recheckThresholds`.
- **`pds.monitorSpikeThresholds(p)`** (called in `rfMap_finish`) is passive. It
  tracks crossing counts per channel and trial, and sets a baseline from the first
  `threshMonBaselineTrials` (20) good trials. It flags channels whose
  sliding-window rate drops below 0.4× or rises above 3× baseline, prints a
  warning, and stores the result in `p.status.threshMon`.

The per-channel online RF display (`pds.initChannelBrowser`) is covered in
[online plotting](online-plotting.md).

## Stimulation output

- **Opto.** `pds.deliverOptoStim(p)` builds either a constant level
  (`optoIpiSec == 0`) or a train of `optoPulseDurSec` pulses at
  `optoPulseAmpVolts`. It writes the waveform to DAC channel `p.rig.dp.optoDacChan`
  (set to 1 in the opto, Quest and learn_cue settings files of
  joystick_release_for_stim_change_and_dim and in joystickPress_playMovie's
  settings) and starts it. It strobes
  `codes.optoStimOn` (17001) and records `p.trData.timing.optoStim`. For trains it
  shortens `optoStimDurSec` to a whole number of cycles. Callers:
  `joystick_release_for_stim_change_and_dim_run.m` and
  `joystickPress_playMovie/joystickPress_run.m`. After the stimulation period,
  both runs reset the channel with `Datapixx('SetDacVoltages', [optoDacChan 0])`.
- **Microstim (Ripple).** `sacc_to_phosph_run.m` calls
  `pds.xippmex('fastsettle', ...)` and `pds.xippmex('stimseq', ...)` directly. See
  [sacc_to_phosph](../tasks/sacc_to_phosph.md).

## Electrode drive

`pds.servo(cmd)` sends one text command (for example `GETPOS`, `UPxxxx`) over a
Java socket to an LSR drive server at `ikura.local:31313` and returns the reply.
With no argument it prints the command list. No task calls it.

## Related

- [Strobe codes](strobe-codes.md), [DataPixx and timing](datapixx-and-timing.md), [data saving](data-saving.md)
- [Rig configs](../library/rig-configs.md), [+pds catalog](../library/pds-functions.md), [pdsActions](../library/pdsActions.md)
- [Mapping family](../tasks/family-mapping.md) (rfMap, barsweep, sacc_to_phosph)
