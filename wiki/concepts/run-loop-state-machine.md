---
title: Run loop and state machine
type: concept
category: Concepts
summary: The _run.m while loop (getEyeJoy → stateMachine → timingMachine → drawMachine), state ID conventions, timing bases, trial end and abort handling
sources:
  - tasks/gSac_4factors/gSac_4factors_run.m @ 9aa849922b
  - tasks/gSac_4factors/gSac_4factors_settings.m @ 132bc9eff2
  - tasks/gSac_4factors/gSac_4factors_finish.m @ f800fddb30
  - tasks/rfMap/rfMap_run.m @ f0637a5bb2
  - +pds/getEyeJoy.m @ c1d49fb59f
  - +pds/getTimes.m @ 89958e4e79
  - +pds/eyeInWindow.m @ 7fe8e2ccb5
  - +pds/joyHeld.m @ 02109bb580
  - +pds/deliverReward.m @ 35fec770c6
  - +pds/trialEndFun.m @ 4539b38689
  - +pds/abortTrial.m @ 1c41353bcf
  - +pds/num2state.m @ 185ae04200
verified_at: e48934be
updated: 2026-10-15
---

# Run loop and state machine

`_run.m` executes one trial. Every task with a `_run.m` follows the same shape. The `_run.m`
files contain a `stateMachine` and a `drawMachine` subfunction, and the gSac-family,
conflict_task, numerosity, sacc_to_phosph and seansFirstTask runs also have a `timingMachine`.
`SRS_mooving`'s run wraps `srsSmooth_run`. The example used here is
`tasks/gSac_4factors/gSac_4factors_run.m`.

## Skeleton

```matlab
[p.trData.timing.trialStartPTB, p.trData.timing.trialStartDP] = pds.getTimes;
while ~p.trVars.exitWhileLoop
    p.trVars.whileLoopIdx = p.trVars.whileLoopIdx + 1;
    p = pds.getEyeJoy(p);      % newest ADC sample -> eyePix/eyeDeg, joyVolt
    p = pds.getMouse(p);       % (mouseEyeSim: mouse replaces gaze)
    p = onlineGazeCalcs(p);    % append [x y t vel] to p.trData.onlineGaze
    p = stateMachine(p);       % behavior-driven transitions
    p = timingMachine(p);      % clock-driven stimulus events
    p = drawMachine(p);        % draw + flip when a frame is due
end
```

The loop is **not** locked to the display. It spins as fast as MATLAB allows and polls
eye/joystick on every pass. `drawMachine` only draws and flips when
`timeNow > lastFrameTime + frameDuration - magicNumber` ([drawing](drawing-and-postflip.md)).
`p.trVars.exitWhileLoop`, `currentState`, `whileLoopIdx` and `flipIdx` start from their
`trVarsInit` values each trial, because `_next` copies `trVarsGuiComm` into `trVars`
([p struct](p-struct.md)).

## Time bases

- `pds.getTimes` calls `Datapixx('RegWrRd')` and then returns `GetSecs` (PTB) and
  `Datapixx('GetTime')`. It is called once at trial start to store `trialStartPTB` and
  `trialStartDP`. These two numbers let `_finish` map the DataPixx ADC buffer onto PTB time
  (`T = trialStartPTB + eyeT - trialStartDP` in `calcSacParams`).
- Inside the loop each machine computes `timeNow = GetSecs - trialStartPTB`. Every
  `p.trData.timing.*` value is in seconds relative to trial start, and `-1` means the event has
  not happened. See [datapixx and timing](datapixx-and-timing.md).

## States

`p.state` is defined in settings as name → integer. Low numbers are transition states, and
end states sit in higher bands. Which band holds aborts differs between tasks:

| task | transition | end: outcome / success | end: aborted |
|---|---|---|---|
| gSac_4factors | `trialBegun`=1 … `holdTarg`=7 | `sacComplete`=21 | `fixBreak`=31, `joyBreak`=32, `nonStart`=33, `failedToHoldTarg`=34 |
| joystickPress | `trialBegun`=1 … `makeDecision`=5 | `hit`=21, `cr`=22, `miss`=23, `foilFa`=24, `fa`=25 | `fixBreak`=11, `joyBreak`=12, `nonStart`=13 |
| rfMap | `trialBegun`=1 … `holdFixAndPlay`=3 | `noiseComplete`=21 | `fixBreak`=11, `nonStart`=13 |

`stateMachine` is a `switch p.trVars.currentState`. Each case checks inputs
(`pds.eyeInWindow(p[, 'target'])`, `pds.joyHeld(p)`, both short-circuited by
`passEye`/`passJoy`) and elapsed time against the trial's `trVars` durations. When it changes
`currentState` it usually also strobes the event (gSac_4factors' `waitForJoy` timeout to
`nonStart` and `holdTarg` → `sacComplete` send no strobe). Behavior events that do not depend on a flip are
strobed straight away with `p.init.strb.strobeNow(code)` and time-stamped with `timeNow`.
Visual events are queued and time-stamped after the flip ([postFlip](drawing-and-postflip.md)).
The generated facts block on each task page lists that task's states.

`timingMachine` (gSac family) handles events tied to the clock rather than behavior, for
example target on/off relative to `fixAq`. It sets flags (`targetIsOn`), queues strobes with
`addValueOnce` and registers postFlip names.

## Ending a trial

- **Success.** On the first pass through `sacComplete`, `pds.deliverReward` starts the reward
  DAC schedule, runs `strobeNow(codes.reward)` and sets `timing.reward`. Later passes wait
  `postRewardDuration + dacPadDur + rewardDurationMs/1000` and then set `exitWhileLoop`.
- **Abort.** The aborted end-state cases (`fixBreak`, `joyBreak`, `nonStart`) call
  `playTone(p,'low')` and set `exitWhileLoop`. The strobe for the break (`codes.fixBreak`,
  `joyRelease`, …), where there is one, was already sent at the transition.
- Whenever `exitWhileLoop` is true, `stateMachine` blanks the fixation and windows and sets
  `p.trData.trialEndState = p.trVars.currentState`.
- Newer tasks (rfMap, barsweep, sacc_to_phosph, numerosity) strobe `codes.trialRunDone` once,
  after the while loop. `_finish` strobes `trialEnd` after the paired info strobes
  ([strobe codes](strobe-codes.md)).

Back in `_finish`, the end state drives the rest of the trial: `trialRepeatFlag` (gSac_4factors
uses `ismember(trialEndState, [fixBreak joyBreak nonStart])`), saving (`pds.saveP` skips
`nonStart` trials), status counters, and repeat-on-error ([trial structure](trial-structure.md)).

## Library helpers you may encounter

- `pds.trialEndFun` is an empty function and `pds.abortTrial` operates on a `c` struct rather
  than `p`. No task calls either. Trial end is handled inline as described above.
- `pds.num2state(num, p)` converts state numbers to names using `p.state`, which is handy for
  decoding `trialEndState` offline.

## Rules from CLAUDE.md
- Keep slow work (plotting, file I/O) out of `_run.m`. Do it in `_finish`.
- Check `p.trData.timing.X > 0` before doing arithmetic on postFlip-set times. `gSac_4factors`
  `makeSaccade` guards its "too late" branch with `p.trData.timing.fixOff > 0`.

## Related
- [drawing and postFlip](drawing-and-postflip.md), [eye and joystick](eye-and-joystick.md),
  [reward](reward.md), [strobe codes](strobe-codes.md), [quintet loop](quintet-and-gui-loop.md)
