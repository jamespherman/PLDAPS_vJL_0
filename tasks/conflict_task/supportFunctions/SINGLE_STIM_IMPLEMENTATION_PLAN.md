# Implementation Plan: Add Single-Stimulus Trials to Phase 1

## Goal
Add 64 single-stimulus, high-salience-only trials to Phase 1 of the conflict_task (32 left-target, 32 right-target), interleaved with the existing 128 dual-stimulus trials. This addresses the monkey's rightward spatial bias by forcing leftward saccades on left-target trials.

## Design Decisions
- Single-stimulus trials show ONLY the high-salience target (no low-salience distractor)
- Trials are interleaved randomly with existing dual-stimulus trials in Phase 1
- Reward is identical to other Phase 1 trials (195ms, 1:1 ratio)
- Single-stimulus trials are excluded from tachometric curve analysis (Panels 1-4) but tracked in Panel 5
- Saccades to the empty location on single-stim trials count as INACCURATE (existing logic handles this)
- Phase 1 grows from 128 to 192 trials; Phases 2-3 unchanged at 128 each; total session = 448

## Counterbalancing (64 single-stimulus trials)
- 4 target locations per side × 2 background hues × 2 delta-T values = 16 conditions per side
- 16 × 2 sides = 32 unique conditions
- 2 repetitions × 32 = 64 trials total (32 left, 32 right)

## Trial Array Column Addition
Add one new column: `singleStimSide`
- 0 = dual-stimulus (both targets shown) — default for all existing trials
- 1 = single-stimulus, LEFT target only
- 2 = single-stimulus, RIGHT target only

---

## Files to Modify (7 files)

### 1. `+pds/initCodes.m`
**What:** Add one new strobe code for the single-stimulus flag.
**Where:** After line ~242 (after `codes.rightTargRadius = 16033;`)
**Change:**
```matlab
codes.singleStimSide        = 16034;  % 0=dual, 1=single-left, 2=single-right
```

### 2. `tasks/conflict_task/conflict_task_settings.m`
**What:** Add new trVarsInit fields, update strobe list, update trial counts.

**2a. Add trVarsInit fields (after line 321, near other conflict task variables):**
```matlab
p.trVarsInit.singleStimSide      = 0;      % 0=dual, 1=single-left, 2=single-right
```

**2b. Add to strobe list (after the `outcomeCode` entry, around line 493):**
```matlab
'singleStimSide',       'p.trVars.singleStimSide'; ...
```

**2c. Update trial count constants (lines 128-131):**
Change:
```matlab
p.status.trialsPerPhase         = 128;
...
p.status.totalTrialsTarget      = 384;  % 128 * 3
```
To:
```matlab
p.status.trialsPerPhaseBase     = 128;      % dual-stim trials per phase
p.status.singleStimTrials       = 64;       % single-stim trials in Phase 1 only
p.status.trialsPhase1           = 192;      % 128 + 64
p.status.trialsPerPhase         = 128;      % phases 2-3 (unchanged)
p.status.totalPhases            = 3;
p.status.completedTrialsInPhase = 0;
p.status.totalTrialsTarget      = 448;      % 192 + 128 + 128
```

**2d. Add single-stim outcome counter (after line 138):**
```matlab
p.status.nSingleStimCorrect     = 0;
p.status.nSingleStimTotal       = 0;
```

### 3. `tasks/conflict_task/supportFunctions/initTrialStructure.m`
**What:** Add `singleStimSide` column, generate 64 single-stimulus trials for Phase 1, update total trial count and counterbalancing verification.

**3a. Update column names (line 24-33) — add `singleStimSide` before `completed`:**
```matlab
p.init.trialArrayColumnNames = {...
    'phaseNumber', ...      % 1, 2, or 3
    'trialInPhase', ...     % Trial index within phase
    'leftLocIdx', ...       % Index into leftAngles (1-4)
    'rightLocIdx', ...      % Index into rightAngles (1-4)
    'backgroundHueIdx', ... % 1=Hue A, 2=Hue B
    'highSalienceSide', ... % 1=left, 2=right
    'deltaTIdx', ...        % Index into deltaTValues (1 or 2)
    'deltaT', ...           % Delta-t value in ms
    'singleStimSide', ...   % 0=dual, 1=single-left, 2=single-right
    'completed'};           % 0=not done, 1=completed
```

**3b. Update trial counts (lines 36-37):**
```matlab
nPhases = 3;
dualTrialsPerPhase = 128;
singleStimTrialsPhase1 = 64;  % 32 left + 32 right
trialsPhase1 = dualTrialsPerPhase + singleStimTrialsPhase1;  % 192
```

**3c. Update total trials calculation (line 60-62):**
```matlab
totalTrials = trialsPhase1 + (nPhases - 1) * dualTrialsPerPhase;  % 192 + 256 = 448
```

**3d. Modify the phase loop to handle Phase 1 specially:**
For Phase 1: after building the 128 dual-stimulus rows (with singleStimSide=0), build 64 additional single-stimulus rows:
- For each `singleSide` in [1, 2] (left, right):
  - For each of the 4 target locations on that side:
    - For each of 2 background hues:
      - For each of 2 delta-t values:
        - Create a row with:
          - `phaseNumber = 1`
          - `leftLocIdx` = location index (if singleSide==1) or 1 (placeholder if singleSide==2)
          - `rightLocIdx` = location index (if singleSide==2) or 1 (placeholder if singleSide==1)
          - `backgroundHueIdx` = iBgHue
          - `highSalienceSide` = singleSide (the shown target IS high salience)
          - `deltaTIdx`, `deltaT` = as usual
          - `singleStimSide` = singleSide
          - `completed` = 0

This gives: 2 sides × 4 locations × 2 hues × 2 deltaT = 32 conditions, but we need 64 (32 per side). Since there are 4 locations × 2 hues × 2 deltaT = 16 per side, we need 2 repetitions each to reach 32 per side. So: generate the 16 conditions per side, then replicate each set once (repmat or loop twice).

**3e. Shuffle all Phase 1 trials together (both dual + single), then assign trialInPhase 1:192.**

**3f. For Phases 2-3:** Add `singleStimSide = 0` column to each trial row (all dual-stimulus). These phases are unchanged except for the extra column.

**3g. Update counterbalancing verification:**
- Verify Phase 1 has exactly 32 single-stim-left and 32 single-stim-right trials
- Verify Phase 1 has exactly 128 dual-stim trials (64 highSalLeft + 64 highSalRight)
- Existing checks for phases 2-3 unchanged (all dual-stim)

**3h. Update p.init metadata:**
```matlab
p.init.trialsPerPhase = [trialsPhase1, dualTrialsPerPhase, dualTrialsPerPhase];  % [192, 128, 128]
p.init.trialsPerPhaseBase = dualTrialsPerPhase;
p.init.singleStimTrialsPhase1 = singleStimTrialsPhase1;
p.init.totalTrials = totalTrials;  % 448
```
NOTE: `p.init.trialsPerPhase` becomes a vector. All code that references it must handle this. Alternatively, keep `p.init.trialsPerPhase` as a scalar equal to the current phase's count and create a lookup `p.init.trialsPerPhaseList = [192, 128, 128]`. The simpler approach: just update `p.init.trialsPerPhase` to 192 for Phase 1 context and let the per-phase trial count be derived dynamically from the trial array. Since `chooseRow` already counts remaining trials per phase from the array, and `updateStatusVariables` counts completed trials from the array, the main place `trialsPerPhase` is used as a scalar is in the print statements and Panel 5 display. We should store `p.init.trialsPerPhaseList = [192, 128, 128]` and use `p.init.trialsPerPhaseList(currentPhase)` where needed.

### 4. `tasks/conflict_task/supportFunctions/nextParams.m`
**What:** Read `singleStimSide` from trial array, set visibility flags, handle hue assignment for single-stim trials.

**4a. In `trialTypeInfo` (after line 118, where other columns are read):**
```matlab
p.trVars.singleStimSide = currentRow(cols.singleStimSide);
```

**4b. Update the fprintf at lines 159-163 to indicate single-stim trials:**
Add a `singleStr` variable:
```matlab
if p.trVars.singleStimSide == 0
    singleStr = '';
elseif p.trVars.singleStimSide == 1
    singleStr = 'SINGLE-LEFT';
else
    singleStr = 'SINGLE-RIGHT';
end
```
Include `singleStr` in the fprintf output.

**4c. In `setBackgroundColor` — for single-stim trials, only the shown target needs a hue. The hidden target's hue doesn't matter since it won't be drawn, but we still set it to avoid uninitialized values:**
No change needed here. The existing logic already assigns hues to both targets. The draw machine will simply skip drawing the hidden one.

**4d. In `setLocations` — for single-stim trials, we still compute both target positions (needed for the experimenter window display). No change needed.**

### 5. `tasks/conflict_task/conflict_task_run.m`
**What:** Modify drawMachine and checkLanding to handle single-stimulus trials.

**5a. `drawMachine` — conditionally draw targets (modify lines 490-530):**
Replace the current block that draws both targets with:
```matlab
if p.trVars.stimuliVisible
    leftHueIdx = p.trVars.leftTargHueIdx;
    rightHueIdx = p.trVars.rightTargHueIdx;

    stimSize_pix_outer = pds.deg2pix(p.draw.bullseyeOuterDeg, p);
    stimSize_pix_inner = pds.deg2pix(p.draw.bullseyeInnerDeg, p);

    % Draw LEFT target bullseye (skip if single-stim RIGHT only)
    if p.trVars.singleStimSide ~= 2
        leftRect_outer = CenterRectOnPoint(...);
        Screen('FrameRect', p.draw.window, leftHueIdx, leftRect_outer, p.trVarsInit.targWidth);
        leftRect_inner = CenterRectOnPoint(...);
        Screen('FrameRect', p.draw.window, leftHueIdx, leftRect_inner, p.trVarsInit.targWidth);
    end

    % Draw RIGHT target bullseye (skip if single-stim LEFT only)
    if p.trVars.singleStimSide ~= 1
        rightRect_outer = CenterRectOnPoint(...);
        Screen('FrameRect', p.draw.window, rightHueIdx, rightRect_outer, p.trVarsInit.targWidth);
        rightRect_inner = CenterRectOnPoint(...);
        Screen('FrameRect', p.draw.window, rightHueIdx, rightRect_inner, p.trVarsInit.targWidth);
    end
end
```

**5b. `drawMachine` — also conditionally draw target WINDOW FRAMES (lines 437-449):**
The target window frames (FrameRect for left/right target windows) are drawn for the experimenter's benefit. For single-stim trials, we should still draw BOTH window frames (so the experimenter can see where both windows are), but we could optionally dim the hidden target's window. Simplest approach: leave window frames unchanged (always draw both). This is experimenter-only visual feedback and doesn't affect the subject.

**5c. `drawMachine` — also conditionally draw reward indicator frames (lines 451-481):**
For single-stim trials in Phase 1 (equal reward), the reward indicators are drawn around both targets. For single-stim, only show the indicator around the visible target. Modify the Phase 1 block:
```matlab
if p.trVars.phaseNumber == 1
    if p.trVars.singleStimSide ~= 2  % show left indicator unless single-right
        leftRewardRect = ...;
        Screen('FrameRect', ...);
    end
    if p.trVars.singleStimSide ~= 1  % show right indicator unless single-left
        rightRewardRect = ...;
        Screen('FrameRect', ...);
    end
end
```

**5d. `stateMachine` checkLanding (lines 214-257) — no change needed.**
The existing logic already handles this correctly:
- If single-stim LEFT: only the left target is drawn, monkey saccades left → `gazeInLeftTarget` = true → correct
- If monkey saccades right on a single-left trial: `gazeInRightTarget` could still be true (the window exists even though no stimulus was drawn). This would incorrectly register as a "right target choice."

**CRITICAL FIX: We MUST modify checkLanding to only accept the presented target on single-stim trials:**
```matlab
% After computing gazeInLeftTarget and gazeInRightTarget:
% Mask out the hidden target on single-stim trials
if p.trVars.singleStimSide == 1
    gazeInRightTarget = false;  % right target not presented
elseif p.trVars.singleStimSide == 2
    gazeInLeftTarget = false;   % left target not presented
end
```
Insert this immediately after lines 215-216, before the if/elseif chain at line 218.

**5e. `stateMachine` sacComplete (lines 293-332) — outcome classification:**
For single-stim trials, the monkey always chooses the high-salience target (it's the only one). The existing logic at lines 297-307 will correctly classify this as `CHOSE_HIGH_SAL` since `highSalienceSide` == the only presented side. No change needed.

### 6. `tasks/conflict_task/supportFunctions/updateOnlinePlots.m`
**What:** Exclude single-stim trials from tachometric curves, track them separately in Panel 5.

**6a. In `updateMetrics` — guard the Phase 1 metrics routing (lines 38-66):**
Add at the top of `updateMetrics`:
```matlab
isSingleStim = (p.trVars.singleStimSide ~= 0);
```

Then wrap the Phase 1 metrics update:
```matlab
if phaseNumber == 1
    if isSingleStim
        % Track single-stim trials separately
        p.status.nSingleStimTotal = p.status.nSingleStimTotal + 1;
        if choseHighSal  % always true for single-stim (only target shown)
            p.status.nSingleStimCorrect = p.status.nSingleStimCorrect + 1;
        end
    else
        % Existing dual-stim Phase 1 metrics (unchanged)
        if highSalSide == 1
            metricsCell = p.status.onlineMetrics.phase1.highSalLeft;
        else
            metricsCell = p.status.onlineMetrics.phase1.highSalRight;
        end
        % ... existing update code ...
    end
end
```

**6b. Still add single-stim trials to cumulative tracking (lines 130-136) so the trial count is correct, but add the isSingleStim flag:**
```matlab
cum.isSingleStim(end+1) = isSingleStim;
```
And in Panel 4 cumulative evolution, exclude single-stim trials from the P(high sal) calculation:
```matlab
p1_left_mask = (cum.phase == 1) & (cum.highSalSide == 1) & ~cum.isSingleStim;
p1_right_mask = (cum.phase == 1) & (cum.highSalSide == 2) & ~cum.isSingleStim;
```

**6c. Update Panel 5 session progress (lines 296-321):**
Update the `trialStr` to show correct trials-per-phase count:
```matlab
trialsInThisPhase = p.init.trialsPerPhaseList(p.status.currentPhase);
trialStr = sprintf('Trial %d/%d in Phase', ...
    p.status.completedTrialsInPhase, trialsInThisPhase);
```

Add a single-stim status line:
```matlab
singleStimStr = sprintf('Single-Stim: %d/%d correct', ...
    p.status.nSingleStimCorrect, p.status.nSingleStimTotal);
set(p.draw.singleStimText, 'String', singleStimStr);
```

### 7. `tasks/conflict_task/supportFunctions/extraWindowSetup.m`
**What:** Add a text handle for single-stim counter in Panel 5.

After the existing `p.draw.outcomeText` creation (around line 200), add:
```matlab
p.draw.singleStimText = text(0.5, 0.05, 'Single-Stim: 0/0 correct', ...
    'Units', 'normalized', 'FontSize', 11, ...
    'HorizontalAlignment', 'center', 'Color', [0.2 0.6 0.2]);
```

### 8. `tasks/conflict_task/supportFunctions/updateTrialsList.m`
**What:** No changes needed. The existing logic marks trials complete/available based on outcome and counts remaining trials per phase from the array. This works regardless of trial type.

### 9. `tasks/conflict_task/supportFunctions/updateStatusVariables.m`
**What:** The `trialsPerPhase` reference on line 33 needs to use the per-phase list:
```matlab
trialsInThisPhase = p.init.trialsPerPhaseList(currentPhase);
p.status.completedTrialsInPhase = trialsInThisPhase - p.status.trialsLeftInPhase;
```

### 10. `tasks/conflict_task/conflict_task_settings.m` — cumulative metrics init
**What:** Add `isSingleStim` field to the cumulative tracking struct (line 194):
```matlab
p.status.onlineMetrics.cumulative.isSingleStim = [];
```

---

## Implementation Order

1. `+pds/initCodes.m` — add `singleStimSide = 16034`
2. `conflict_task_settings.m` — add trVarsInit fields, strobe list entry, status counters, cumulative field
3. `initTrialStructure.m` — add column, generate single-stim trials, update counts
4. `nextParams.m` — read singleStimSide, update fprintf
5. `conflict_task_run.m` — conditional drawing, mask hidden target in checkLanding
6. `updateOnlinePlots.m` — exclude single-stim from tachometric curves, track separately
7. `extraWindowSetup.m` — add text handle for single-stim counter
8. `updateStatusVariables.m` — use per-phase trial count list

## Testing Checklist
- [ ] Verify trial array has 448 rows (192 + 128 + 128)
- [ ] Verify Phase 1 has 128 dual-stim + 64 single-stim trials
- [ ] Verify single-stim trials are balanced: 32 left, 32 right
- [ ] Verify counterbalancing within single-stim: 16 unique conditions per side × 2 reps
- [ ] Verify Phases 2-3 are unchanged (128 trials each, all dual-stim)
- [ ] Verify single-stim trials only show one target on screen
- [ ] Verify saccade to empty location = INACCURATE on single-stim trials
- [ ] Verify single-stim trials excluded from tachometric curves
- [ ] Verify strobe code 16034 appears in saved data for single-stim trials
- [ ] Verify session ends after 448 trials
