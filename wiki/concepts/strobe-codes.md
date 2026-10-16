---
title: Strobe codes
type: concept
category: Concepts
summary: How event codes reach the ephys system — initCodes.m layout, timing vs paired strobes, classyStrobe, strobeTrialData/strobeList, value encoding conventions
sources:
  - +pds/initCodes.m @ 55d625cb0d
  - +pds/classyStrobe.m @ 4b9bb7c352
  - +pds/strobeTrialData.m @ 119964102b
  - +pds/initTaskMetadata.m @ 764e25c2d9
  - +pds/getRippleData.m @ dd24a98b4e
  - tasks/gSac_4factors/gSac_4factors_settings.m @ 132bc9eff2
  - tasks/gSac_4factors/gSac_4factors_run.m @ 9aa849922b
  - tasks/gSac_4factors/gSac_4factors_finish.m @ f800fddb30
  - tasks/gSac_4factors/supportFunctions/nextParams.m @ 3356244d78
  - tasks/conflict_task/conflict_task_settings.m @ 4467fe7e8c
verified_at: e48934be
updated: 2026-10-15
---

# Strobe codes

`CLAUDE.md` ("Strobe Code System (CRITICAL)") holds the rules: `+pds/initCodes.m` is HOLY,
every `strobeList` name must exist there, and negative values need an offset. The full table
of codes, which tasks use each one, and the integrity checks are in the generated
[strobe code registry](../reference/strobe-codes.md). This page explains how the system works.

## The wire: 15-bit words through DataPixx

All strobing ends in the local function `strobe(value)` at the bottom of `+pds/classyStrobe.m`:

```matlab
Datapixx('SetDoutValues', value, 32767);  Datapixx('RegWr');   % word on bits 0-14
Datapixx('SetDoutValues', 2^16, 65536);   Datapixx('RegWr');   % strobe bit (bit 16)
Datapixx('SetDoutValues', 0, 98303);      Datapixx('RegWr');   % clear word + strobe
```

The word mask is `32767`, so a value has to fit in **15 bits (0–32767)**. That is the reason
for the scaling and offset conventions below. The class comment says it was written for Plexon
(Omniplex). For Ripple, `pds.getRippleData` reads the digital events back with
`xippmex('digin')` into `p.trData.eventValues` and `p.trData.eventTimes` (divided by 30000,
i.e. seconds). See [ephys integration](ephys-integration.md).

## Two kinds of strobe

The header of `initCodes.m` names them:

- **Timing strobes**: a single code that marks *when* something happened (`fixOn`=3001,
  `targetOn`, `saccadeOnset`=2003, `reward`, `trialBegin`=30001, `trialEnd`=30009). They are
  sent during `_run` at the moment of the event.
- **Paired strobes**: a code that identifies a *variable*, followed at once by its *value*
  (`trialCount`=11002 then the count; `targetTheta` then angle×10). They are sent in `_finish`
  by `pds.strobeTrialData` from `p.init.strobeList`.

`taskCode` (32000) is a paired strobe whose value is the task's
`uniqueTaskCode_<taskName>` (32001–32024). `pds.initTaskMetadata` looks it up as
`codes.(['uniqueTaskCode_' p.init.taskName])` and stores it in `p.init.taskCode`.

## initCodes.m layout

`codes = pds.initCodes` returns one flat struct. Sections, in order: `taskCode`, the unique
task codes, classyStrobe's internal codes (`isCell`=32123, `cellLength`=32124, copied from
`pds.classyStrobe`), trial codes (`trialBegin`, `trialRunDone`, `trialEnd`, `trialCount`,
`trialCode`, …), date/time, end-of-trial/outcome codes, opto, joystick, fixation, saccade,
target, cue, stimulus, reward, microstim, audio, image, then per-task blocks (tokens,
gSac_4factors, conflict_task, rfMap, barsweep, SRS_Task, SRS_mooving). Some ranges are
reserved, for example in the rfMap block 16151–16157 (never strobed; the comment says do not
reuse) and 16162–16175 (reserved for future per-stim-type params and headroom).

A **validation cell** at the end runs on every call. It collects every value and calls
`error('YOU MUST FIX IT')` if two codes share a value, so a collision stops `_init`. It checks
values, not names. Assigning the same name twice in the file silently keeps the last value.
The registry lists any such names.

Date and time are sent with a leading `1` (`date_1yyyy`, `date_1mmdd`, `time_1hhmm`, built in
`initTaskMetadata` as `str2double(['1' datestr(now,'mmdd')])`), so leading zeros survive.
Strip the first digit when decoding.

## classyStrobe (`p.init.strb`)

This is a `handle` class created in `_init` (`p.init.strb = pds.classyStrobe`). Because it is
a handle, method calls change it in place, and the `p.init.strb.method(...)` calls in tasks
do not need to be assigned back.

| method | effect |
|---|---|
| `strobeNow(v)` | send `v` now; append to `strobedList` |
| `addValue(v)` | queue onto `valueList`, set `armedToStrobe`. A numeric vector queues each element. A logical is converted to double. A cell queues `isCell, cellLength, n` before each element's contents |
| `addValueOnce(v)` | `addValue` unless `v` is in `vetoList`, then add it to `vetoList` |
| `strobeList` | send everything in `valueList` in order, log to `strobedList`, clear the queue and disarm |
| `flushVetoList`, `flushStrobedList`, `removeFromVetoList(v)` | bookkeeping |

During a trial, visual-event codes are queued with `addValueOnce` and sent by `strobeList`
right after the flip in `drawMachine` ([postFlip](drawing-and-postflip.md)). Behavior events
use `strobeNow`. At the end of `_finish`, gSac_4factors copies `p.init.strb.strobedList` into
`p.trData.strobed` (the saved per-trial record of what was sent) and then flushes both lists.

## strobeList and pds.strobeTrialData

`p.init.strobeList` (in settings) is an N×2 cell: `{codeName, valueExpression}`.
`pds.strobeTrialData(p)`, called in `_finish`, loops over the rows:

```matlab
strbCode = p.init.codes.(p.init.strobeList{ii, 1});
strbVal  = eval(p.init.strobeList{ii, 2});     % expression string, evaluated with p in scope
```

A scalar value queues `code, value`. A vector value queues `code, v(i)` for each element. After
the loop, a single `p.init.strb.strobeList` sends the whole queue. The loop sits inside one
`try … catch` with an empty catch. An error in any row (an unknown code name, or an expression
that fails) ends the loop at that row with no message. Rows already queued are still sent, and
the remaining rows are not. The expressions can read anything in `p`. For example,
gSac_4factors reads trial-array columns with
`p.init.trialsArray(p.trVars.currentTrialsArrayRow, find(strcmp(p.init.trialArrayColumnNames, ''stimType'')))`.

Order in gSac_4factors `_finish`: `pds.strobeTrialData` → `strobeNow(codes.trialEnd)` →
`trData.strobed = strb.strobedList`. All of a trial's paired strobes therefore fall between
that trial's timing strobes and its `trialEnd`. The `initCodes` comment on `trialEnd` notes
that the gap from `trialEnd[N]` to `fixOn[N+1]` holds only ITI, timeout and post-reward time.
Newer tasks also send `trialRunDone` (30008) when the `_run` loop exits.

## Value encoding conventions

Values must be non-negative integers no larger than 32767:

- **Scale** fractions: `_x10`, `_x100`, `_x1000` suffixes (`rewardRatioBig_x100 = round(ratio*100)`).
- **Offset** signed values: conflict_task strobes `deltaT + 1000` and
  `round(angle*10) + 1800` for angles in −180…180.
- **Polar target locations**: gSac_4factors `nextParams` computes
  `targTheta_x10 = round(mod(rad2deg(theta),360)*10)` and `targRadius_x100 = round(r*100)`.
- **Booleans and categories**: 0/1, or small integers documented in the settings comment.

## Adding a code

Add it to `+pds/initCodes.m` in the right section with a value no other code uses (the
validation cell enforces this), add the `{name, expr}` row to the task's `strobeList`, then
regenerate the [registry](../reference/strobe-codes.md). Never renumber or reuse an existing
value.

## Related
- [strobe code registry](../reference/strobe-codes.md), [ephys integration](ephys-integration.md),
  [drawing and postFlip](drawing-and-postflip.md), [run loop](run-loop-state-machine.md)
