---
title: Drawing and the postFlip mechanism
type: concept
category: Concepts
summary: How drawMachine gates frames and flips, how postFlip.varNames time-stamps visual events at the flip, how post-flip strobes are queued, and the -1 convention
sources:
  - tasks/gSac_4factors/gSac_4factors_run.m @ 9aa849922b
  - tasks/gSac_4factors/gSac_4factors_settings.m @ 132bc9eff2
  - tasks/gSac_4factors/supportFunctions/initTrData.m @ 534411fb3d
  - tasks/conflict_task/conflict_task_run.m @ d44eef3da2
  - +pds/classyStrobe.m @ 4b9bb7c352
  - +pds/initDataPixx.m @ d2924f59b6
verified_at: e48934be
updated: 2026-10-15
---

# Drawing and the postFlip mechanism

The *rule* (check `p.trData.timing.X > 0` before using a postFlip-set time) is in `CLAUDE.md`
("Timing Variables and the postFlip Convention"). This page explains how the mechanism works,
using `tasks/gSac_4factors/gSac_4factors_run.m`. The same field names appear in conflict_task,
the joystick tasks, nfl, scd, rfMap, barsweep, SRS_Task_Smooth and others.

## drawMachine: drawing only when a frame is due

The [run loop](run-loop-state-machine.md) calls `drawMachine(p)` on every pass. It draws only
when

```matlab
timeNow > p.trData.timing.lastFrameTime + p.rig.frameDuration - p.rig.magicNumber
```

`magicNumber` (0.008 s in `gSac_4factors_settings` and `rigConfig_rig1`; some other rig configs
use 0.006 or 0) is "time to wait for screen flip". It
starts drawing that far ahead of the next refresh, so the draw commands are finished before
the vertical blank. On passes where no frame is due, the loop just polls inputs again. When a
frame is due, `drawMachine`:

1. fills the background (`p.draw.color.background`, a CLUT index) and draws the experimenter
   overlays: grid, gaze marker, fixation and target windows, reward indicator;
2. draws subject-visible items according to flags the state and timing machines set
   (`p.trVars.targetIsOn`, `p.draw.color.fix`);
3. flips:
   `p.trData.timing.flipTime(flipIdx) = Screen('Flip', p.draw.window, GetSecs + 0.00);`
   `Flip` blocks until the swap and returns its timestamp. `lastFrameTime` is set to that
   timestamp minus `trialStartPTB`;
4. **strobes queued codes**: `if p.init.strb.armedToStrobe, p.init.strb.strobeList; end`;
5. **resolves postFlip names** (below);
6. increments `p.trVars.flipIdx`.

Colors are CLUT *indices*, not RGB. The CLUTs for the experimenter and subject displays let an
overlay item be visible on one display and match the background on the other. Names such as
`expGrey70_subBg` say what each display shows. See [color and calibration](color-and-calibration.md).
`p.draw.window` comes from `PsychImaging('OpenWindow', …)` in `pds.initDataPixx`.

## postFlip: putting the flip time on visual events

The state and timing machines decide that something should *appear* (or disappear). It is
only on screen after the next flip, so they do not write a time stamp. Instead they register
the event:

```matlab
% timingMachine, target onset (gSac_4factors_run.m)
if targetOnWindow && p.trData.timing.targetOn < 0
    p.trVars.targetIsOn = true;                          % drawMachine will draw it
    if ~ismember('targetOn', p.trVars.postFlip.varNames)
        p.init.strb.addValueOnce(p.init.codes.targetOn); % queue strobe for after flip
        p.trVars.postFlip.logical           = true;
        p.trVars.postFlip.varNames{end + 1} = 'targetOn';
    end
end
```

and `drawMachine`, right after the flip:

```matlab
if p.trVars.postFlip.logical
    for j = 1:length(p.trVars.postFlip.varNames)
        varName = p.trVars.postFlip.varNames{j};
        if p.trData.timing.(varName) < 0
            p.trData.timing.(varName) = p.trData.timing.lastFrameTime;
        end
    end
    p.trVars.postFlip.logical  = false;
    p.trVars.postFlip.varNames = cell(0);
end
```

Each name in `postFlip.varNames` is a field of `p.trData.timing`. The time stamp is the
trial-relative flip time of the first frame that showed the change. The `< 0` test means a
time is never overwritten once set. The `ismember` guard stops the same name being queued
twice while a frame is pending. `postFlip` lives in `p.trVarsInit`
(`postFlip.logical = false`, `postFlip.varNames = cell(0)`), so it is clean at the start of
every trial.

**Strobes follow the same path.** `addValueOnce` puts the code in `strb.valueList` and in the
veto list, so repeated calls on later passes do nothing. `strobeList` in `drawMachine` sends
the queued codes right after `Flip` returns, which keeps the ephys event aligned with the
frame. `fixOff` in `dontMove` uses `addValue` (no veto). It is reached only once, because the
state changes to `makeSaccade` on the same pass. Behavior events with no visual component use
`strobeNow` at once ([strobe codes](strobe-codes.md)).

## The -1 convention and the one-frame gap

`p.init.trDataInitList` sets every `p.trData.timing.*` to `-1`, and the task's `initTrData`
applies it in `_next`. Between registering an event and the next flip (up to one frame plus
the pass in which it was registered) the time is still `-1`, even though the state machine
may already be in the next state. Code that runs in that gap must not treat the value as a
time. `gSac_4factors` `makeSaccade` computes `timeSinceGo = timeNow - fixOff` straight away.
Its "too late" branch checks `p.trData.timing.fixOff > 0`, and its other branches can't fire
while `fixOff` is `-1`, because `timeSinceGo` (`timeNow + 1`) is then larger than the default
`goLatencyMax` of 1 s.
conflict_task's run file has comments at these spots ("Timing variables set via postFlip may
still be -1 initially").

Times that are *not* visual (`fixAq`, `saccadeOnset`, `joyPress`, `fixBreak`, `reward`) are
set straight away with `timeNow` in the state machine or `pds.deliverReward`.

## Related
- [run loop](run-loop-state-machine.md), [strobe codes](strobe-codes.md),
  [datapixx and timing](datapixx-and-timing.md), [color and calibration](color-and-calibration.md)
- `CLAUDE.md`: postFlip rule and the WRONG/CORRECT example
