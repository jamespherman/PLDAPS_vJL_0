---
title: Trial structure and condition tables
type: concept
category: Concepts
summary: How tasks build condition tables (initTrialStructure → p.init.trialsArray), pick rows in nextParams, and repeat failed trials (updateTrialsList), with gSac_4factors, joystickPress and SRS_Task_Smooth examples
sources:
  - tasks/gSac_4factors/supportFunctions/initTrialStructure.m @ bad52d5c96
  - tasks/gSac_4factors/supportFunctions/nextParams.m @ 3356244d78
  - tasks/gSac_4factors/supportFunctions/updateTrialsList.m @ 1701f230b8
  - tasks/gSac_4factors/gSac_4factors_finish.m @ f800fddb30
  - tasks/joystickPress/supportFunctions/initTrialStructure.m @ bd4890598a
  - tasks/joystickPress/supportFunctions/nextParams.m @ 4958c1698c
  - tasks/joystickPress/supportFunctions/updateTrialsList.m @ 2c40bde655
  - tasks/joystickPress/joystickPress_finish.m @ 2edf17790a
  - tasks/SRS_Task_Smooth/supportFunctions/initTrialStructure.m @ cfd42abb4d
  - tasks/SRS_Task_Smooth/supportFunctions/buildSrsBlockSchedule.m @ 6d8d38b5ae
  - tasks/SRS_Task_Smooth/supportFunctions/nextParams.m @ c33d8e5c32
  - tasks/SRS_Task_Smooth/supportFunctions/updateTrialsList.m @ 4d498d44b5
verified_at: e48934be
updated: 2026-10-15
---

# Trial structure and condition tables

Condition logic belongs to each task's `supportFunctions/`. `+pds` has no shared helper for it.
Most tasks share one vocabulary, though:

| name | where | meaning |
|---|---|---|
| `p.init.trialArrayColumnNames` | `initTrialStructure` | cell of column names |
| *table* (recipe) | local function in `initTrialStructure` | one row per condition, with a repetitions column (`numTrials` / `no of trials` / `noOfTrials`) |
| `p.init.trialsArray` | `initTrialStructure` | the table expanded: one row per trial to complete |
| `p.status.trialsArrayRowsPossible` | `initTrialStructure` / `nextParams` | logical, one per row: is this row still to be run? |
| `p.trVars.currentTrialsArrayRow` | `nextParams` | row chosen for this trial |
| `p.trData.trialRepeatFlag` | `_finish` | did this trial fail, so the row stays eligible? |
| `updateTrialsList` | `_finish` | writes the outcome into `trialsArrayRowsPossible`; refills at block end |

The cycle: **`_init` → `initTrialStructure` builds the array; `_next` → `nextParams` picks an
eligible row and copies its columns into `p.trVars`; `_finish` → sets `trialRepeatFlag`, then
`updateTrialsList` retires the row on success or keeps it on failure; when nothing is
eligible, a new block starts.** Each trial array column is either copied into `p.trVars` or
strobed directly with a `strobeList` expression that indexes `p.init.trialsArray`
([strobe codes](strobe-codes.md)).

## Example 1: gSac_4factors (fixed factorial deck, ordered half-blocks)

- `fourFactorsTable` builds 96 recipe rows: 4 half-blocks × 4 target locations × 6 stimulus
  types (face, non-face, four bullseye salience × hue types). The columns are `halfBlock`,
  `targetLocIdx`, `stimType`, `salience`, `reward`, `targetColor`, `numTrials` and
  `trialCode`. The repetition count sets location probability (5 at the block's
  high-probability location, 1 elsewhere) and is doubled for image types to balance the
  categories. Reward alternates hemifield between the two halves of a block.
  `trialCode = 26000 + 1000*block + condition`.
- After expansion, rows are shuffled **within each block**. A `completed` column is appended,
  and `trialsArrayRowsPossible` starts all true.
- `nextParams` → `chooseRow` draws at random from the lowest-numbered half-block that still has
  eligible rows. Half-blocks therefore run in order 1→4, and when all four are done everything
  is reset. `trialTypeInfo` copies the columns into `p.trVars` and picks a random face or
  non-face texture (`imageIdx`).
- `_finish`: `trialRepeatFlag = ismember(trialEndState, [fixBreak joyBreak nonStart])`. Then
  `updateTrialsList` sets `trialsArrayRowsPossible(row) = trialRepeatFlag`, so a failed row
  goes back into its half-block pool and is redrawn at random. When no row is eligible it
  resets them all and flips `p.status.tLoc1HighRwdFirst`.

The design is described in `tasks/gSac_4factors/gSac_4factors_task_design_specification.md`.
See [gSac_4factors](../tasks/gSac_4factors.md).

## Example 2: joystickPress (experiment-type tables, regenerated each block)

- `initTrialStructure` switches on `p.init.exptType` to choose a table function
  (`tableDefSatInc`, `tableDefault`, …). For the `nfl*` types it keeps two tables,
  `p.init.trialsTable1/2`. Columns describe cue side, number of stimuli, which feature
  changes, and so on. When the table is expanded, two seed columns (`trial seed`,
  `stim seed`) are appended, so trial and stimulus parameters can be reproduced.
- `nextParams` restricts the draw to subsets in a fixed priority. It filters on column 1
  (cue side) and column 2 (number of stimuli): single-stimulus trials on side 1 first, then
  multi-stimulus on side 1, then side 2. It then reads seeds and stimulus parameters from the
  chosen row.
- For some experiment types (`nfl`, `nfl_50`, `nfl_shortBlocks`,
  `saturation increase no single`), the expanded array is duplicated so every condition runs
  twice.
- `_finish` sets `trialRepeatFlag = trialEndState > 10 & trialEndState < 20`, which covers the
  abort states (11–13). When a block is used up, `updateTrialsList` increments
  `p.status.blockNumber` and calls `generateTrialsArray`, which **rebuilds** the array with
  fresh seeds. For the `nfl` types it switches to table 2, and `nfl_shortBlocks` alternates
  between the two tables.

## Example 3: SRS_Task_Smooth (schedule rebuilt every reward block)

- `initTrialStructure` only defines the column layout: compact `p.init.trialsTableColumnNames`
  plus expanded `p.init.trialArrayColumnNames`, with lookup structs
  `p.init.trialsTableCols` and `p.init.trialCols`. It leaves the array empty and sets
  `p.status.blockScheduleComplete = true`.
- At the start of each reward block, `nextParams` → `startNewBlock` sets the block type. The
  first block's type is random, and after that it alternates. It also draws the number of
  choice trials (a multiple of 4 between `minTrialsPerBlock` and `maxTrialsPerBlock`) and
  then calls `buildSrsBlockSchedule`. That function builds an instruction phase
  (single-target T1/T2 trials, when `useSingleStimTraining` is on) and a choice phase
  (congruent and conflict trials, counterbalanced across sides). Choice rows unlock only after
  every instruction row has succeeded.
- `updateTrialsList` removes successful rows and keeps failed ones. On top of that it has an
  optional *correction-trial* mode, which forces the same condition again after a low-reward
  choice, up to `correctionTrialMaxRepetition`, with optional reward reduction. The mode's
  state is saved and strobed (codes 20040–20053).

See [SRS_Task_Smooth](../tasks/SRS_Task_Smooth.md).

## Patterns to reuse

- Store column names and find columns by name (`strcmp(p.init.trialArrayColumnNames, 'x')` or
  a cols struct) instead of hard-coding indices.
- Repeat-on-error = keep the row eligible. Whether it comes back at once or later depends on
  the draw. All three examples draw at random from the eligible pool.
- Code each condition as a single integer (`trialCode`) and strobe it, so the ephys stream
  identifies the condition even without the `.mat` files.

## Related
- [quintet loop](quintet-and-gui-loop.md), [p struct](p-struct.md), [strobe codes](strobe-codes.md)
- Family pages: [gSac](../tasks/family-gsac.md), [joystick](../tasks/family-joystick.md),
  [SRS](../tasks/family-srs.md)
