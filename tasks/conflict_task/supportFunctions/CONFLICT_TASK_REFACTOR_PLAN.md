# Conflict Task Refactor Implementation Plan

## Overview

This document describes the complete refactoring plan for the `conflict_task` to implement new experimental design requirements including multiple target locations, dynamic reward ratios, and enhanced online visualization.

---

## Current State Summary

| Aspect | Current Implementation |
|--------|----------------------|
| Target Locations | 2 fixed (A and B, 180° apart) |
| Reward Structure | Fixed: 350ms high, 160ms low |
| Delta-T Values | 6 values: [-150, -100, -50, 0, 50, 100] ms |
| Trial Structure | 6 blocks × 60 trials = 360 trials |
| Background Colors | Single grey background |
| Visualization | Tachometric curve (P(goal) vs deltaT) |

---

## Target State Summary

| Aspect | New Implementation |
|--------|-------------------|
| Target Locations | 8 total (4 left, 4 right) = 16 combinations |
| Reward Structure | Phase-dependent: 1:1 → 1:2 → 2:1 with C=390ms total |
| Delta-T Values | 2 values: [-150, +150] ms |
| Trial Structure | 128 (1:1) + 128 (1:2) + 128 (2:1) = 384 trials |
| Background Colors | 2 colors (DKL hue counterbalancing) |
| Visualization | Multi-panel with hemifield, conflict/congruent, and cumulative analysis |

---

## Detailed Design Specifications

### 1. Target Location System

#### 1.1 Location Geometry
- **Eccentricity**: Configurable via `p.trVarsInit.targetEccentricity` (default: existing calculation from locationA_x, locationA_y)
- **Right visual field angles**: +45°, +15°, -15°, -45° (equally spaced, 30° intervals)
- **Left visual field angles**: +135°, +165°, -165°, -135° (mirror symmetric)

#### 1.2 Data Structure
New trial array columns:
```matlab
'leftLocIdx'    % Index 1-4 for left target location
'rightLocIdx'   % Index 1-4 for right target location
'leftLocAngle'  % Polar angle in degrees for left target
'rightLocAngle' % Polar angle in degrees for right target
```

#### 1.3 Location Definitions (in settings)
```matlab
p.trVarsInit.targetEccentricityDeg = 8;  % degrees from fixation
p.trVarsInit.rightAngles = [45, 15, -15, -45];  % degrees, 0 = rightward
p.trVarsInit.leftAngles = [135, 165, -165, -135];  % mirror of right
```

### 2. Reward Structure

#### 2.1 New Variables
```matlab
p.trVarsInit.rewardDurationMs = 390;      % Total reward "budget" (C)
p.trVarsInit.rewardRatioLeft = 1;         % Current ratio part for left
p.trVarsInit.rewardRatioRight = 1;        % Current ratio part for right
p.trVarsInit.rewardDurationLeft = 195;    % Calculated: C * left/(left+right)
p.trVarsInit.rewardDurationRight = 195;   % Calculated: C * right/(left+right)
```

#### 2.2 Phase Definitions
```matlab
p.status.rewardPhase = 1;  % 1 = 1:1, 2 = 1:2, 3 = 2:1
p.status.trialsPerPhase = [128, 128, 128];
p.status.completedTrialsInPhase = 0;
```

#### 2.3 Reward Calculation Logic
```matlab
% Called at start of each trial
function [leftReward, rightReward] = calculateRewards(C, ratioLeft, ratioRight)
    total = ratioLeft + ratioRight;
    leftReward = round(C * ratioLeft / total);
    rightReward = round(C * ratioRight / total);
end

% Phase 1 (1:1): 195ms / 195ms
% Phase 2 (1:2): 130ms / 260ms
% Phase 3 (2:1): 260ms / 130ms
```

### 3. Delta-T Configuration

#### 3.1 Changes
```matlab
% Old
deltaTValues = [-150, -100, -50, 0, 50, 100];

% New
deltaTValues = [-150, 150];
p.status.nDeltaT = 2;
```

### 4. Trial Structure

#### 4.1 Phase 1: Equal Reward (1:1)
- **Trials**: 128 (successfully completed)
- **Conditions**: 16 location pairs × 2 background hues × 2 high-salience sides × 2 Δt values = 128
- **Reward**: Left = 195ms, Right = 195ms
- **Categorization**: By high-salience side (left vs right) only (no conflict/congruent)

#### 4.2 Phase 2: Asymmetric (1:2 - Left:Right)
- **Trials**: 128 (successfully completed)
- **Same condition matrix as Phase 1**
- **Reward**: Left = 130ms, Right = 260ms
- **Categorization**:
  - Congruent = high salience RIGHT (matches high reward)
  - Conflict = high salience LEFT (opposes high reward)

#### 4.3 Phase 3: Asymmetric (2:1 - Left:Right)
- **Trials**: 128 (successfully completed)
- **Same condition matrix as Phase 1**
- **Reward**: Left = 260ms, Right = 130ms
- **Categorization**:
  - Congruent = high salience LEFT (matches high reward)
  - Conflict = high salience RIGHT (opposes high reward)

#### 4.4 New Trial Array Structure
```matlab
p.init.trialArrayColumnNames = {...
    'phaseNumber', ...      % 1, 2, or 3
    'trialInPhase', ...     % 1-128
    'leftLocIdx', ...       % 1-4
    'rightLocIdx', ...      % 1-4
    'backgroundHueIdx', ... % 1 (Hue A) or 2 (Hue B)
    'highSalienceSide', ... % 1=left, 2=right
    'deltaTIdx', ...        % 1 or 2 (index into [-150, 150])
    'deltaT', ...           % -150 or 150 ms
    'completed'};           % 0=not done, 1=completed
```

### 5. Background Color System

#### 5.1 Hue Configurations
| backgroundHueIdx | Target Hue | High Salience BG | Low Salience BG |
|-----------------|------------|------------------|-----------------|
| 1 (Hue A) | 0° DKL | 180° DKL | 45° DKL |
| 2 (Hue B) | 180° DKL | 0° DKL | 225° DKL |

#### 5.2 Implementation
- The target on the high-salience side gets the target hue
- The target on the low-salience side also gets the same target hue
- Background color is set to create 180° contrast with high-salience target
- This creates high/low salience via contrast, not different target hues

### 6. Online Visualization

#### 6.1 Figure Layout
```
+-------------------------------------------+
|  PANEL 1: Phase 1 (1:1) - By Hemifield    |
|  P(choose high salience) vs Δt            |
|  Lines: High sal LEFT vs High sal RIGHT   |
+-------------------------------------------+
|  PANEL 2: Phase 1 (1:1) - Collapsed       |
|  P(choose high salience) vs Δt            |
|  Single line (all trials combined)        |
+-------------------------------------------+
|  PANEL 3: Phases 2-3 - Conflict/Congruent |
|  P(choose high salience) vs Δt            |
|  Lines: Conflict vs Congruent             |
+-------------------------------------------+
|  PANEL 4: Cumulative Choice Evolution     |
|  Normalized cumsum over trial number      |
|  Multiple traces by condition             |
+-------------------------------------------+
|  PANEL 5: Session Progress                |
|  Phase X/3 | Trial Y/128 | Total Z/384    |
+-------------------------------------------+
```

#### 6.2 Online Metrics Structure
```matlab
p.status.onlineMetrics = struct();

% Phase 1 (1:1): categorize by high salience side
p.status.onlineMetrics.phase1 = struct();
p.status.onlineMetrics.phase1.highSalLeft = cell(2, 1);   % {deltaTIdx}
p.status.onlineMetrics.phase1.highSalRight = cell(2, 1);  % {deltaTIdx}
% Each cell: struct with nChoseHighSal, nChoseLowSal, RTs

% Phases 2-3: categorize by conflict/congruent
p.status.onlineMetrics.phase2 = struct();
p.status.onlineMetrics.phase2.conflict = cell(2, 1);
p.status.onlineMetrics.phase2.congruent = cell(2, 1);

p.status.onlineMetrics.phase3 = struct();
p.status.onlineMetrics.phase3.conflict = cell(2, 1);
p.status.onlineMetrics.phase3.congruent = cell(2, 1);

% Cumulative tracking for evolution plot
p.status.onlineMetrics.cumulative = struct();
p.status.onlineMetrics.cumulative.trialNumbers = [];
p.status.onlineMetrics.cumulative.choseHighSal = [];  % 1 or 0 per trial
p.status.onlineMetrics.cumulative.condition = [];     % condition label per trial
```

#### 6.3 Cumulative Plot Details
- X-axis: Trial number (1 to current)
- Y-axis: Cumulative proportion (cumsum / trial_count)
- Traces:
  - Phase 1: "High Sal Left" and "High Sal Right" (within phase 1 only)
  - Phase 2-3: "Conflict" and "Congruent" (starting fresh at phase 2)
- Vertical lines at phase transitions (trial 128, trial 256)

---

## Implementation Tasks

### Task 1: Update `conflict_task_settings.m`
- [ ] Add new target location variables (eccentricity, angles)
- [ ] Update reward variables (remove high/low, add ratio system)
- [ ] Update deltaTValues to [-150, 150]
- [ ] Add phase tracking variables
- [ ] Update trial array column names
- [ ] Update strobed variables list
- [ ] Update online metrics initialization structure

### Task 2: Rewrite `initTrialStructure.m`
- [ ] Generate 384 trials across 3 phases
- [ ] Create all 128 unique conditions per phase
- [ ] Implement location pair generation (16 combinations)
- [ ] Add background hue counterbalancing
- [ ] Implement within-phase shuffling
- [ ] Update trialsArrayRowsPossible tracking

### Task 3: Update `nextParams.m`
- [ ] Implement phase transition logic
- [ ] Calculate dynamic reward amounts based on current phase
- [ ] Set target locations from trial array
- [ ] Set background color based on backgroundHueIdx and highSalienceSide
- [ ] Detect session completion (all 384 trials done)

### Task 4: Update `conflict_task_run.m`
- [ ] Update reward delivery to use side-specific amounts
- [ ] Update target drawing to use dynamic locations
- [ ] Update background color setting per trial
- [ ] Verify state machine works with new location system
- [ ] Update outcome classification for new metrics

### Task 5: Rewrite `extraWindowSetup.m`
- [ ] Create 5-panel figure layout
- [ ] Initialize all plot handles
- [ ] Set up axes labels and legends
- [ ] Add phase transition markers to cumulative plot

### Task 6: Rewrite `updateOnlinePlots.m`
- [ ] Route metrics to correct phase/category
- [ ] Update Panel 1 (phase 1 by hemifield)
- [ ] Update Panel 2 (phase 1 collapsed)
- [ ] Update Panel 3 (phases 2-3 conflict/congruent)
- [ ] Update Panel 4 (cumulative evolution)
- [ ] Update Panel 5 (session progress)

### Task 7: Update `updateTrialsList.m`
- [ ] Handle phase completion detection
- [ ] Implement automatic phase transition
- [ ] Implement session completion (stop after 384)

### Task 8: Update `updateStatusVariables.m`
- [ ] Track phase-specific trial counts
- [ ] Update phase number when transitioning

### Task 9: Update `conflict_task_finish.m`
- [ ] Ensure proper session termination after 384 trials
- [ ] Update any data saving for new structure

### Task 10: Testing and Validation
- [ ] Verify 128 unique conditions per phase
- [ ] Verify reward calculations (130/260/195 values)
- [ ] Verify phase transitions occur at correct trial counts
- [ ] Verify visualizations update correctly
- [ ] Test with passEye=1 mode

---

## File Change Summary

| File | Change Type | Description |
|------|-------------|-------------|
| `conflict_task_settings.m` | MODIFY | New variables, updated initializations |
| `conflict_task_init.m` | MINOR | May need adjustments for new structure |
| `conflict_task_next.m` | MINOR | Verify compatibility |
| `conflict_task_run.m` | MODIFY | Dynamic locations, rewards, backgrounds |
| `conflict_task_finish.m` | MODIFY | Session completion logic |
| `initTrialStructure.m` | REWRITE | Complete new trial generation logic |
| `nextParams.m` | MODIFY | Phase logic, reward calculation, locations |
| `extraWindowSetup.m` | REWRITE | New 5-panel visualization layout |
| `updateOnlinePlots.m` | REWRITE | New metrics routing and plotting |
| `updateTrialsList.m` | MODIFY | Phase transition detection |
| `updateStatusVariables.m` | MODIFY | Phase-specific counters |

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Breaking existing state machine | Minimal changes to _run.m state logic; only modify inputs/outputs |
| Incorrect reward calculation | Unit test calculateRewards() function with known values |
| Phase transition errors | Add explicit logging at transitions |
| Visualization bugs | Test with synthetic data before live use |
| Trial counting errors | Add assertions that sum of phase trials = 384 |

---

## Verification Checklist

After implementation, verify:

1. **Trial Structure**
   - [ ] Phase 1 has exactly 128 unique conditions
   - [ ] Phase 2 has exactly 128 unique conditions
   - [ ] Phase 3 has exactly 128 unique conditions
   - [ ] Total trials = 384

2. **Reward Values**
   - [ ] Phase 1: Both sides = 195ms
   - [ ] Phase 2: Left = 130ms, Right = 260ms
   - [ ] Phase 3: Left = 260ms, Right = 130ms

3. **Target Locations**
   - [ ] 4 left angles: 135°, 165°, -165°, -135°
   - [ ] 4 right angles: 45°, 15°, -15°, -45°
   - [ ] All 16 pairs appear in each phase

4. **Visualizations**
   - [ ] Panel 1 shows two lines (left/right high salience)
   - [ ] Panel 2 shows collapsed single line
   - [ ] Panel 3 shows conflict/congruent for phases 2-3
   - [ ] Panel 4 shows cumulative evolution with phase markers

5. **Session Flow**
   - [ ] Task stops after 384 successful trials
   - [ ] Failed trials are repeated (not counted toward 384)
   - [ ] Phase transitions occur at exactly trial 128 and 256

---

## Sub-Agent Recommendations

Given the scope of this refactor, I recommend using sub-agents for:

1. **Explore Agent**: Initial codebase exploration (already done)
2. **Implementation**: Main agent handles sequential file modifications
3. **Testing**: Could use separate agent for validation if needed

The implementation is best done sequentially by the main agent because:
- Files have dependencies (settings must be updated before initTrialStructure)
- State machine changes require understanding of multiple files
- Visualization changes depend on metrics structure changes

---

## Notes

- Eccentricity should be parameterized but default to current value (calculated from locationA_x and locationA_y)
- The "conflict" vs "congruent" terminology only applies to phases 2-3; phase 1 uses "high salience left/right"
- Background color system already exists in CLUT; we just need to set it per-trial
- The cumulative plot should normalize by dividing by trial count so all traces end at their final proportion

---

*Plan created: 2026-02-04*
*Author: Claude Code (Opus 4.5)*
