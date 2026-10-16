---
title: Reward delivery
type: concept
category: Concepts
summary: How liquid reward is delivered as a DataPixx DAC pulse, how its duration is set per rig and per trial, and the reward GUI actions
sources:
  - +pds/deliverReward.m @ 35fec770c6
  - +pds/freeReward.m @ e0108ee298
  - +pds/initRigConfigFile.m @ f32e98b29d
  - +pds/waitForJoystickRelease.m @ 7740aa1360
  - +pdsActions/singleReward.m @ 88e1442f09
  - +pdsActions/rewardDrain.m @ 9b0ae745f0
  - +pdsActions/rewardGive.m @ 42326f09a3
  - +rigConfigFiles/rigConfig_rig1.m @ 95baf18b31
  - +rigConfigFiles/rigConfig_rig2.m @ 488fc5b2ba
  - tasks/reward_calibration/reward_calibration_run.m @ 2189244319
  - tasks/reward_calibration/reward_calibration_settings.m @ 0a1f8963d4
verified_at: e48934be
updated: 2026-10-15
---

# Reward delivery

Liquid reward is a solenoid that is open while the DataPixx DAC outputs +4 V.

## `pds.deliverReward(p)`

1. Builds a waveform at `p.rig.dp.dacRate`: `dacPadDur/2` of 0 V, then
   `p.trVars.rewardDurationMs` of +4 V, then `dacPadDur/2` of 0 V.
2. Writes it to the DAC buffer `p.rig.dp.dacBuffAddr` on channel
   `p.rig.dp.dacChannelOut` and sets the DAC schedule.
3. Starts the schedule and strobes `p.init.codes.reward` (8000) right away with
   `p.init.strb.strobeNow`.
4. Sets `p.trData.timing.reward` (trial-relative PTB time), but only if it is
   still negative. On trials with more than one reward, this keeps the time of the
   first one.

The call returns without waiting, and the solenoid closes when the hardware
schedule ends. `pds.waitForJoystickRelease` (in `_finish.m`) keeps looping while
`Datapixx('GetDacStatus').scheduleRunning` is true, so the next trial does not
start mid-reward.

`pds.freeReward(p)` is the same waveform with two differences. It strobes
`codes.freeReward` (8001) and always overwrites `p.trData.timing.freeReward`. Its
only caller is `joystick_release_for_stim_change_and_dim_finish.m`, which uses it
for inter-trial free rewards.

## Where the duration comes from

- The rig config sets `p.rig.baseReward` (`rigConfig_rig1`: 189 ms;
  `rigConfig_rig2`: 200 ms). This lets each rig have its own calibration (commit
  23c0509a).
- `pds.initRigConfigFile` (run at `_init`) copies `p.rig.baseReward` into both
  `p.trVarsInit.rewardDurationMs` and `p.trVars.rewardDurationMs` when the field
  exists.
- Tasks then set the per-trial value in `_next`/`_run`. Examples:
  - gSac_4factors `nextParams` sets `rewardDurationHigh` or `rewardDurationLow`.
  - `srsSmooth_run.m` sets `currentRewardDuration`.
- `rewardDurationMs` is usually exposed in the GUI as a trial variable (see
  [trial variables and GUI](trial-variables-and-gui.md)).

## Reward actions (GUI buttons)

These are in `+pdsActions/`. Each opens the DataPixx on its own and builds its own
4 V pulse at 1 kHz on DAC channel 0, buffer `6e6`. They do not strobe and do not
touch `p.trData`.

| Action | Behavior |
|---|---|
| `pdsActions.singleReward` | One opening of `p.trVars.rewardDurationMs`. |
| `pdsActions.rewardDrain` | 30 openings of 9.5 s each, with 0.5 s pauses, to flush the line. Closing the waitbar aborts it. |
| `pdsActions.rewardGive` | Gives a reward in 1 s cycles with Poisson probability (`lambda = 0.7`) for 180 s or until Esc. No current settings file lists it. |

See [pdsActions](../library/pdsActions.md) for how actions are wired to the GUI.

## reward_calibration task

`tasks/reward_calibration` delivers one reward per trial for measuring volume per
opening. In the `trialBegun` state, `reward_calibration_run.m` strobes
`trialBegin`, calls `pds.deliverReward`, and ends the trial. The settings file
exposes `rewardDurationMs` (default 280 ms) as the first GUI variable. See
[reward_calibration](../tasks/reward_calibration.md).

## Related

- [DataPixx and timing](datapixx-and-timing.md), [strobe codes](strobe-codes.md)
- [Rig configs](../library/rig-configs.md), [+pds catalog](../library/pds-functions.md)
