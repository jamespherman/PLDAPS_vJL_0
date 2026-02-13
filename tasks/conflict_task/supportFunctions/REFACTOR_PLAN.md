# Conflict Task Refactor Plan

## Overview

Six coordinated changes to the conflict_task:

1. Separate timeout for inaccurate saccades (`timeoutSacErr`)
2. Configurable asymmetric reward ratio (`rewardRatioBig`)
3. Single-stim trials first in Phase 1 (sequential, not interleaved)
4. Phase 1 pseudorandom 50/50 large reward assignment
5. Phase 2/3 probabilistic (~90%) reward assignment
6. Visualization redesign (3x3 layout with RT panels)

Changes 2, 4, and 5 are deeply coupled: they all modify how rewards are assigned per trial. The key architectural change is adding a `rewardBigSide` column to the trial array, so reward mapping is pre-assigned per trial rather than determined at the phase level.

### Correction on Item 5

The user believed pseudorandom pre-assignment was impossible for Phase 2/3 probabilistic rewards. **This is incorrect.** Pre-assignment works because the monkey's choice on any trial is made before observing the reward, so choice and assignment are independent. If 90% of trials have `rewardBigSide=2` (big right), then P(big reward | chose right) = 90% regardless of the monkey's behavior. We will pre-assign using `round(nTrials * rewardProbHigh)` trials with the canonical mapping.

### Assumption on Item 5 Phrasing

The user wrote: "there should be a high (~90%) probability in Phase 1 that rightward saccades receive the large magnitude reward" — I interpret "Phase 1" here as a typo for "Phase 2", since the paragraph opens with "In Phase 2 / 3" and the current Phase 2 has big-right as canonical. So:
- Phase 2: ~90% `rewardBigSide=2` (big right, canonical)
- Phase 3: ~90% `rewardBigSide=1` (big left, canonical)

---

## Files Modified (10 files)

| File | Changes |
|------|---------|
| `conflict_task_settings.m` | Add `timeoutSacErr`, `rewardRatioBig`, `rewardProbHigh`, `rewardBigSide`; update strobeList |
| `+pds/initCodes.m` | Add 2 new strobe codes |
| `supportFunctions/initTrialStructure.m` | Add `rewardBigSide` column; sequential single-stim; probabilistic reward assignment |
| `supportFunctions/nextParams.m` | Extract `rewardBigSide`; rewrite `calculateRewards`; update `isConflict` logic |
| `supportFunctions/postTrialTimeOut.m` | Separate inaccurate timeout |
| `supportFunctions/extraWindowSetup.m` | Complete redesign: 3x3 layout with RT panels |
| `supportFunctions/updateOnlinePlots.m` | Remove collapsed panel; add RT panels; expand info panel |
| `supportFunctions/updateTrialsList.m` | Dynamic ratio strings |
| `conflict_task_run.m` | Update reward indicator for per-trial `rewardBigSide` |
| `supportFunctions/updateStatusVariables.m` | No changes needed (counters are fine) |

---

## Change 1: Timeout for Inaccurate Saccades

### `conflict_task_settings.m`
- Add after line 281 (`timeoutAfterFa`):
  ```matlab
  p.trVarsInit.timeoutSacErr = 2.0;  % timeout for inaccurate saccades (outside both targets)
  ```

### `postTrialTimeOut.m`
- Split the switch case to give `inaccurate` its own timeout:
  ```matlab
  switch p.trData.trialEndState
      case {p.state.fixBreak, p.state.joyBreak, p.state.nonStart, p.state.noResponse}
          timeOutDur = p.trVars.timeoutAfterFa;
      case p.state.inaccurate
          timeOutDur = p.trVars.timeoutSacErr;
      otherwise
          timeOutDur = 0;
  end
  ```

---

## Change 2: Configurable Reward Ratio

### `conflict_task_settings.m`
- Add near line 275 (reward system section):
  ```matlab
  p.trVarsInit.rewardRatioBig = 2;        % asymmetric reward ratio (big:small = this:1)
  p.trVarsInit.rewardProbHigh = 0.9;      % P(canonical reward side) in Phases 2-3
  p.trVarsInit.rewardBigSide = 0;         % 1=big-left, 2=big-right (set per trial from array)
  ```

### `+pds/initCodes.m`
- Add after `singleStimSide` (code 16034):
  ```matlab
  codes.rewardRatioBig_x100   = 16035;  % reward ratio * 100 (e.g., 2.0 -> 200)
  codes.rewardProbHigh_x1000  = 16036;  % P(canonical reward) * 1000 (e.g., 0.9 -> 900)
  ```

### `conflict_task_settings.m` (strobeList)
- Add to strobeList:
  ```matlab
  'highRewardLocation',   'p.trVars.rewardBigSide'; ...           % 1=left, 2=right
  'rewardRatioBig_x100',  'round(p.trVars.rewardRatioBig * 100)'; ...
  'rewardProbHigh_x1000', 'round(p.trVars.rewardProbHigh * 1000)'; ...
  ```

### `initTrialStructure.m`
- Replace hardcoded `phaseRewardRatios`:
  ```matlab
  rewardRatioBig = p.trVarsInit.rewardRatioBig;
  p.init.phaseRewardRatios = [1, 1; 1, rewardRatioBig; rewardRatioBig, 1];
  ```
- Update print summary to compute values dynamically:
  ```matlab
  C = p.trVarsInit.rewardDurationMs;
  smallReward = round(C * 1 / (1 + rewardRatioBig));
  bigReward = round(C * rewardRatioBig / (1 + rewardRatioBig));
  equalReward = round(C / 2);
  fprintf('  Phase 1: 1:1 (%dms : %dms)\n', equalReward, equalReward);
  fprintf('  Phase 2: 1:%.1f (%dms : %dms)\n', rewardRatioBig, smallReward, bigReward);
  fprintf('  Phase 3: %.1f:1 (%dms : %dms)\n', rewardRatioBig, bigReward, smallReward);
  ```

### `updateTrialsList.m`
- Replace hardcoded ratio strings with dynamic computation:
  ```matlab
  C = p.trVarsInit.rewardDurationMs;
  R = p.trVarsInit.rewardRatioBig;
  smallR = round(C * 1 / (1 + R));
  bigR = round(C * R / (1 + R));
  if nextPhase == 2
      ratioStr = sprintf('1:%.1f (Left=%dms, Right=%dms)', R, smallR, bigR);
  else
      ratioStr = sprintf('%.1f:1 (Left=%dms, Right=%dms)', R, bigR, smallR);
  end
  ```

### `nextParams.m` — `calculateRewards`
- Rewrite to use per-trial `rewardBigSide`:
  ```matlab
  function p = calculateRewards(p)
  C = p.trVars.rewardDurationMs;
  R = p.trVars.rewardRatioBig;
  if p.trVars.rewardBigSide == 1
      leftRatio = R;  rightRatio = 1;
  else
      leftRatio = 1;  rightRatio = R;
  end
  p.trVars.rewardRatioLeft = leftRatio;
  p.trVars.rewardRatioRight = rightRatio;
  totalRatio = leftRatio + rightRatio;
  p.trVars.rewardDurationLeft = round(C * leftRatio / totalRatio);
  p.trVars.rewardDurationRight = round(C * rightRatio / totalRatio);
  end
  ```

### `nextParams.m` — `trialTypeInfo`
- Extract `rewardBigSide` from trial array (new column)
- Update `isConflict` to use `rewardBigSide` instead of phase-based hardcoding:
  ```matlab
  if p.trVars.singleStimSide > 0
      p.trVars.isConflict = false;  % N/A for single-stim
  else
      p.trVars.isConflict = (p.trVars.rewardBigSide ~= p.trVars.highSalienceSide);
  end
  ```
- Update print ratio strings to be dynamic

### `conflict_task_run.m` — `drawMachine` reward indicator
- Replace phase-based indicator logic with per-trial `rewardBigSide`:
  ```matlab
  % Draw high-reward indicator on the big-reward side
  if p.trVars.rewardBigSide == 1
      % Big reward on LEFT
      if p.trVars.singleStimSide ~= 2  % don't show if only right target
          % draw green frame around left target
      end
  elseif p.trVars.rewardBigSide == 2
      % Big reward on RIGHT
      if p.trVars.singleStimSide ~= 1  % don't show if only left target
          % draw green frame around right target
      end
  end
  ```

---

## Change 3: Single-Stim Trials First in Phase 1

### `initTrialStructure.m`
- For Phase 1 only, instead of combining and shuffling all together:
  ```matlab
  if iPhase == 1
      % Shuffle single-stim and dual-stim separately
      singleShuffled = singleTrials(randperm(size(singleTrials, 1)), :);
      dualShuffled = phaseTrials(randperm(size(phaseTrials, 1)), :);
      % Single-stim FIRST, then dual-stim
      phaseTrials = [singleShuffled; dualShuffled];
  else
      phaseTrials = phaseTrials(randperm(size(phaseTrials, 1)), :);
  end
  ```

- Update file header comment to reflect "sequential" instead of "interleaved"

---

## Change 4: Phase 1 Pseudorandom 50/50 Large Rewards

### `initTrialStructure.m`

Add `rewardBigSide` as the 10th column (before `completed` which becomes 11th).

**Column definitions update:**
```matlab
p.init.trialArrayColumnNames = {...
    'phaseNumber', 'trialInPhase', 'leftLocIdx', 'rightLocIdx', ...
    'backgroundHueIdx', 'highSalienceSide', 'deltaTIdx', 'deltaT', ...
    'singleStimSide', 'rewardBigSide', 'completed'};
```

**Phase 1 dual-stim (128 trials) assignment:**
After building all 128 dual-stim rows, assign `rewardBigSide` with 50/50 balance within each `highSalienceSide` group:
```matlab
% Balance rewardBigSide within each highSalienceSide
salSideVals = phaseTrials(:, cols.highSalienceSide);
for iSal = 1:2
    idx = find(salSideVals == iSal);  % 64 trials
    nHalf = length(idx) / 2;           % 32
    assignment = [ones(nHalf, 1); 2 * ones(nHalf, 1)];
    assignment = assignment(randperm(length(assignment)));
    phaseTrials(idx, cols.rewardBigSide) = assignment;
end
```

**Phase 1 single-stim (64 trials) assignment:**
Balance within each `singleStimSide` group:
```matlab
for iSide = 1:2
    idx = find(singleTrials(:, cols.singleStimSide) == iSide);  % 32 trials
    nHalf = length(idx) / 2;  % 16
    assignment = [ones(nHalf, 1); 2 * ones(nHalf, 1)];
    assignment = assignment(randperm(length(assignment)));
    singleTrials(idx, cols.rewardBigSide) = assignment;
end
```

---

## Change 5: Phase 2/3 Probabilistic (~90%) Reward Assignment

### `initTrialStructure.m`

**Phase 2 (128 trials):**
```matlab
rewardProbHigh = p.trVarsInit.rewardProbHigh;
nCanonical = round(dualTrialsPerPhase * rewardProbHigh);  % ~115
nFlipped = dualTrialsPerPhase - nCanonical;                % ~13

% Phase 2 canonical = big-right (rewardBigSide=2)
assignment = [2 * ones(nCanonical, 1); ones(nFlipped, 1)];
assignment = assignment(randperm(length(assignment)));
phaseTrials(:, cols.rewardBigSide) = assignment;
```

**Phase 3 (128 trials):**
```matlab
% Phase 3 canonical = big-left (rewardBigSide=1)
assignment = [ones(nCanonical, 1); 2 * ones(nFlipped, 1)];
assignment = assignment(randperm(length(assignment)));
phaseTrials(:, cols.rewardBigSide) = assignment;
```

### Counterbalancing verification update:
- Phase 1: assert 50/50 split of rewardBigSide within each highSalienceSide
- Phase 2: assert ~90/10 split with rewardBigSide=2 as majority
- Phase 3: assert ~90/10 split with rewardBigSide=1 as majority

---

## Change 6: Visualization Redesign

### New Layout

```
  Col 1 (0.06-0.36)           Col 2 (0.40-0.70)           Col 3 (0.76-0.97)
  +-----------------------+   +-----------------------+   +-----------------------+
  | Phase 1 (1:1)         |   | Phases 2-3            |   |                       |
  | P(High Sal)           |   | P(High Sal)           |   |   SESSION INFO        |
  | by Hemifield          |   | Conflict/Congruent    |   |   Phase, trial count  |
  | [2 lines]             |   | [2 lines]             |   |   Reward params       |
  +-----------------------+   +-----------------------+   |   Outcome counts      |
  | Phase 1 (1:1)         |   | Phases 2-3            |   |   Error breakdown     |
  | Median RT             |   | Median RT             |   |   Single-stim stats   |
  | by Hemifield          |   | Conflict/Congruent    |   |   P(HighSal) summary  |
  | [2 lines]             |   | [2 lines]             |   |                       |
  +-----------------------+   +-----------------------+   |                       |
  | Choice Evolution Over Session                     |   |                       |
  | [4 lines: P1 L/R, P23 conflict/congruent]         |   |                       |
  +---------------------------------------------------+   +-----------------------+
```

### Panel positions (normalized):

| Panel | Position [left bottom width height] |
|-------|--------------------------------------|
| 1: P(HighSal) Phase 1 | [0.06, 0.72, 0.30, 0.22] |
| 2: P(HighSal) Phases 2-3 | [0.40, 0.72, 0.30, 0.22] |
| 3: RT Phase 1 | [0.06, 0.42, 0.30, 0.22] |
| 4: RT Phases 2-3 | [0.40, 0.42, 0.30, 0.22] |
| 5: Choice Evolution | [0.06, 0.06, 0.64, 0.28] |
| 6: Info panel | [0.76, 0.06, 0.22, 0.88] |

### `extraWindowSetup.m` changes:
- Remove Panel 2 (Phase 1 Collapsed) and its plot objects
- Move Phases 2-3 P(HighSal) to row 1, col 2 (position change)
- Add two new RT panels (row 2, cols 1-2) with:
  - Y-axis: "Median RT (ms)", auto-scaled or initial [0, 500]
  - Same X-axis (deltaTValues) and colors as corresponding P(HighSal) panels
  - Plot handles: `rt_p1_highSalLeft`, `rt_p1_highSalRight`, `rt_p23_conflict`, `rt_p23_congruent`
- Choice Evolution panel spans cols 1-2 in row 3
- Info panel spans all 3 rows in col 3:
  - Phase/trial progress (existing)
  - Reward parameters: `rewardRatioBig`, `rewardProbHigh`, reward durations
  - Outcome summary with error breakdown (fix breaks, no response, inaccurate separately)
  - Single-stim counter
  - P(HighSal) summary per phase

### `updateOnlinePlots.m` changes:

**Remove:**
- Panel 2 (collapsed) computation and update (lines 207-226)

**Add RT panel updates:**
```matlab
%% RT Panel 1: Phase 1 by Hemifield
for iDT = 1:nDeltaT
    allRT_left = [phase1.highSalLeft{iDT}.rtHighSal, phase1.highSalLeft{iDT}.rtLowSal];
    if ~isempty(allRT_left)
        medianRT_left(iDT) = median(allRT_left);
    else
        medianRT_left(iDT) = NaN;
    end
    % same for right...
end
% Update plot handles...

%% RT Panel 2: Phases 2-3 Conflict vs Congruent
% Same pattern: combine rtHighSal + rtLowSal, compute median
```

**Update info panel content:**
- Add text objects for reward parameters, error breakdown
- Display P(HighSal) running summary per phase
- Show `rewardRatioBig` and `rewardProbHigh` values

---

## Implementation Order

1. **`+pds/initCodes.m`** — Add new strobe codes (independent)
2. **`conflict_task_settings.m`** — Add new variables, update strobeList
3. **`initTrialStructure.m`** — New column, sequential ordering, reward assignment
4. **`nextParams.m`** — Extract `rewardBigSide`, rewrite rewards and `isConflict`
5. **`postTrialTimeOut.m`** — Separate inaccurate timeout
6. **`conflict_task_run.m`** — Update reward indicator in drawMachine
7. **`updateTrialsList.m`** — Dynamic ratio strings
8. **`extraWindowSetup.m`** — Complete layout redesign
9. **`updateOnlinePlots.m`** — RT panels, remove collapsed, expand info

---

## Validation Checklist

- [ ] `rewardBigSide` column added to trial array (column 10, before `completed`)
- [ ] Phase 1: 64 single-stim trials first, then 128 dual-stim
- [ ] Phase 1: rewardBigSide is 50/50 balanced within each highSalienceSide
- [ ] Phase 1 single-stim: rewardBigSide is 50/50 balanced within each singleStimSide
- [ ] Phase 2: ~90% rewardBigSide=2, ~10% rewardBigSide=1
- [ ] Phase 3: ~90% rewardBigSide=1, ~10% rewardBigSide=2
- [ ] All strobe codes in strobeList exist in initCodes.m
- [ ] Inaccurate trials use `timeoutSacErr` (2s), other errors use `timeoutAfterFa` (1s)
- [ ] Reward indicator in drawMachine shows correct big-reward side per trial
- [ ] `isConflict` derived from `rewardBigSide != highSalienceSide` (dual-stim only)
- [ ] Visualization has 6 panels in 3x3 layout
- [ ] RT panels show median RT with same groupings as P(HighSal) panels
- [ ] Info panel shows reward parameters, error breakdown, summary stats
- [ ] Counterbalancing assertions updated for new structure
- [ ] Print strings use dynamic reward values (no hardcoded ms)
