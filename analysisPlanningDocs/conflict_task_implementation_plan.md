# Conflict Task Implementation Plan

## Document Purpose
This document outlines the implementation plan for the Conflict Task, a behavioral paradigm based on the existing gSac_4factors task architecture. The Conflict Task pits goal-directed attention (reward expectation) against stimulus-driven attention (salience) using the compelled saccade paradigm.

---

## Overview

### Source Reference
- **Design Specification:** `D:\Google Drive\HermanLab\grants\R01_Herman_February_2026\markdown\Conflict_Task_Design_Specification.md`
- **Base Task:** `D:\OneDrive - University of Pittsburgh\Code\PLDAPS_vK2\tasks\gSac_4factors`

### Target Directory
`D:\OneDrive - University of Pittsburgh\Code\PLDAPS_vK2\tasks\conflict_task`

---

## Key Differences from gSac_4factors

| Aspect | gSac_4factors | Conflict Task |
|--------|---------------|---------------|
| Factorial design | 4 factors (salience, reward, probability, stimulus type) | 2 factors (trial type × Δt) |
| Stimulus types | Face images, non-face images, bullseyes | Bullseyes only |
| Target locations | 4 locations (90° rotations) | 2 locations (180° apart) |
| Number of targets per trial | 1 target | 2 simultaneous targets |
| Timing manipulation | Fixed stimulus timing, memory-guided | Δt (stimulus onset asynchrony) |
| Block structure | 2-4 half-blocks with probability manipulation | 6 blocks alternating reward location |
| Response classification | Correct/Incorrect | Goal-directed/Capture/Error |
| Trials per session | Variable (~200+ per 2-block cycle) | Fixed 360 (6 blocks × 60 trials) |

---

## Implementation Plan

### Phase 1: Directory Structure and File Scaffolding

**Files to Create:**
```
conflict_task/
├── conflict_task_init.m          (One-time initialization)
├── conflict_task_next.m          (Pre-trial setup)
├── conflict_task_run.m           (Trial execution)
├── conflict_task_finish.m        (Post-trial processing)
├── conflict_task_settings.m      (Parameter definitions)
└── supportFunctions/
    ├── initClut.m                (Copy and adapt from gSac_4factors)
    ├── initTrialStructure.m      (NEW - Conflict Task specific)
    ├── nextParams.m              (NEW - Conflict Task specific)
    ├── updateOnlinePlots.m       (NEW - Tachometric curve visualization)
    ├── updateStatusVariables.m   (Adapt from gSac_4factors)
    ├── extraWindowSetup.m        (Adapt from gSac_4factors)
    ├── initCodes.m               (Adapt with new event codes)
    ├── playTone.m                (Copy from gSac_4factors)
    └── postTrialTimeOut.m        (Copy from gSac_4factors)
```

### Phase 2: Settings File (conflict_task_settings.m)

**Key Parameter Changes:**

1. **Task Identity:**
   - `p.init.taskName = 'conflict_task'`
   - New task description and metadata

2. **State Machine States:**
   - Keep: trialBegun, waitForJoy, showFix, dontMove, makeSaccade, checkLanding, holdTarg, sacComplete
   - Keep error states: fixBreak, joyBreak, nonStart
   - Add: New outcome classification logic

3. **Status Variables:**
   - `iBlock` (1-6)
   - `rewardLocation` (A or B)
   - `iTrialInBlock` (1-60)
   - Outcome counters: `nGoalDirected`, `nCapture`, `nFixBreak`, `nNoResponse`, `nInaccurate`
   - Online metrics arrays organized by Δt and trial type

4. **Trial Variables (p.trVarsInit):**
   - **Timing:**
     - `fixHoldDurationMin/Max`: 1.0-1.4s (variable fixation period)
     - `deltaT`: Stimulus onset asynchrony (−150 to +100 ms)
     - `responseWindow`: 600 ms from go signal
   - **Geometry:**
     - `locationA_x`, `locationA_y`: Experimenter-specified RF location
     - `locationB_x`, `locationB_y`: Computed as −locationA (180° rotation)
     - `targetEccentricity`: Preserved for both locations
   - **Stimulus:**
     - `trialType`: CONFLICT or CONGRUENT
     - `highSalienceLocation`: A or B
     - `highRewardLocation`: A or B (block-determined)
   - **Reward:**
     - `rewardHighDuration`: 350 ms (goal-directed choice)
     - `rewardLowDuration`: 160 ms (capture)
   - **Windows:**
     - `targetWindow`: 5° radius (acceptance window per spec)

5. **Draw Parameters:**
   - Bullseye specifications (same as gSac_4factors)
   - Two simultaneous target rendering
   - DKL hue offsets: 180° (high salience) vs. 0° (low salience)

6. **Strobe List:**
   - Block number
   - Reward location
   - Trial type (Conflict/Congruent)
   - Δt value
   - High salience location
   - Outcome (goal-directed/capture/error type)
   - Reaction time
   - Processing time (RT + Δt)

### Phase 3: Trial Structure Generation (initTrialStructure.m)

**Block Structure:**
- 6 blocks total
- 60 trials per block
- Reward location alternates: A → B → A → B → A → B

**Trial Allocation per Block:**
```
For each Δt in {−150, −100, −50, 0, +50, +100} ms:
  - 5 Conflict trials
  - 5 Congruent trials
Total: 6 Δt × 10 trials = 60 trials per block
```

**Trial Array Columns:**
1. Block number (1-6)
2. Trial index within block (1-60)
3. Δt value (−150, −100, −50, 0, +50, +100)
4. Trial type (1=Conflict, 2=Congruent)
5. High reward location (1=A, 2=B) - determined by block
6. High salience location (1=A, 2=B) - determined by trial type
7. Completion flag (0=pending, 1=completed)

**Pseudorandomization:**
- Shuffle trial order within each block (not across blocks)
- Pre-generate complete 360-trial sequence at session start

### Phase 4: Pre-Trial Setup (conflict_task_next.m, nextParams.m)

**nextParams.m Logic:**
1. Determine current block from trial count
2. Set reward location based on block number (odd=A, even=B)
3. Get next trial from shuffled trial array
4. Extract: Δt, trial type, high salience location
5. Compute high reward location (always current block's reward location)
6. Set stimulus parameters:
   - Location A stimulus: high/low salience based on `highSalienceLocation`
   - Location B stimulus: opposite salience
7. Calculate timing:
   - Random fixation duration (1000-1400 ms)
   - Stimulus onset time = fixation offset time + Δt
   - Note: Δt can be negative (stimulus before go) or positive (stimulus after go)

### Phase 5: Trial Execution (conflict_task_run.m)

**State Machine Modifications:**

1. **showFix State:**
   - Display fixation point at screen center
   - Wait for eye to enter fixation window
   - No changes from gSac_4factors

2. **dontMove State:**
   - Subject maintains fixation
   - **Key Change:** Timing machine handles Δt-dependent stimulus onset
   - For negative Δt: Stimuli appear BEFORE fixation offset
   - For positive Δt: Stimuli appear AFTER fixation offset
   - Go signal = fixation point offset (as in gSac_4factors)

3. **makeSaccade State:**
   - Go signal given (fixation off)
   - Wait for saccade initiation
   - **Key Change:** For positive Δt, stimuli may appear during this state
   - Response window: 600 ms (extended from original 500 ms)

4. **checkLanding State:**
   - **Key Change:** Check landing against TWO target windows
   - If saccade lands in Location A window → record `saccadeTarget = A`
   - If saccade lands in Location B window → record `saccadeTarget = B`
   - If saccade lands outside both → Error: Inaccurate

5. **holdTarg State:**
   - Hold gaze at chosen target
   - On completion → sacComplete

6. **sacComplete State:**
   - **Key Change:** Outcome classification:
     - If `saccadeTarget == highRewardLocation` → Goal-directed choice → Large reward
     - If `saccadeTarget != highRewardLocation` → Capture → Small reward
   - Play appropriate tone
   - Deliver reward

**Timing Machine Modifications:**

Critical change for Δt implementation:
```matlab
% Calculate stimulus onset time relative to trial start
stimOnsetTime = goSignalTime + deltaT;  % deltaT can be negative!

% During dontMove state:
if currentTime >= stimOnsetTime && ~stimuliVisible
    % Turn on BOTH stimuli simultaneously
    stimuliVisible = true;
    strobe(targetOnCode);
end

% Go signal timing (fixation offset):
if currentTime >= goSignalTime && fixationVisible
    fixationVisible = false;
    strobe(fixOffCode);
end
```

**Draw Machine Modifications:**

1. **Dual Target Rendering:**
   - Draw two bullseyes simultaneously (when stimuliVisible)
   - Location A: Use appropriate salience color
   - Location B: Use opposite salience color

2. **Bullseye Drawing:**
   - Same geometry as gSac_4factors (4° outer ring, 2° inner ring)
   - High salience: 180° DKL hue offset (maximally salient)
   - Low salience: 0° DKL hue offset (isoluminant with background)

3. **Target Windows:**
   - Draw both target windows on experimenter display
   - Highlight high-reward location window (green frame)

### Phase 6: Post-Trial Processing (conflict_task_finish.m)

**Outcome Classification:**
```matlab
switch trialEndState
    case sacComplete
        if saccadeTarget == highRewardLocation
            outcome = 'GOAL_DIRECTED';
        else
            outcome = 'CAPTURE';
        end
    case fixBreak
        outcome = 'FIX_BREAK';
    case noResponse (timeout in makeSaccade)
        outcome = 'NO_RESPONSE';
    case inaccurate (landed outside both windows)
        outcome = 'INACCURATE';
end
```

**Trial Repetition Logic:**
- Repeat trial if: FIX_BREAK, NO_RESPONSE, or INACCURATE
- Do NOT repeat: GOAL_DIRECTED or CAPTURE (both are valid completions)

**Saccade Parameter Calculation:**
- Peak velocity (deg/s)
- Reaction time: go signal to saccade onset
- Processing time: RT + Δt
- Saccade amplitude
- Endpoint error (distance from chosen target)

**Data Strobing:**
- Block number
- Trial type
- Δt value
- High salience location
- Chosen target (A/B)
- Outcome
- Reaction time
- Processing time

### Phase 7: Online Visualization (updateOnlinePlots.m)

**Primary Display: Tachometric Curve**

Real-time visualization showing P(goal-directed) vs. Δt:

```
Figure Layout:
┌─────────────────────────────────────────┐
│ Tachometric Curve (Conflict Trials)     │
│                                          │
│  P(goal)   ●───●                        │
│    1.0 │        ●───●                   │
│    0.5 │            ●───●               │
│    0.0 │                                │
│        └──────────────────────────      │
│         -150 -100 -50  0  +50 +100      │
│                   Δt (ms)               │
├─────────────────────────────────────────┤
│ Congruent Trial Performance             │
│  P(goal)                                 │
│    1.0 │ ●───●───●───●───●───●          │
│        └──────────────────────────      │
│         -150 -100 -50  0  +50 +100      │
├─────────────────────────────────────────┤
│ RT Distribution by Outcome              │
│  [Histogram: Goal-directed vs Capture]  │
└─────────────────────────────────────────┘
```

**Metrics to Track:**
1. P(goal-directed) at each Δt for Conflict trials
2. P(goal-directed) at each Δt for Congruent trials (should be flat/high)
3. RT distributions: Goal-directed vs. Capture
4. Mean RT by Δt
5. Fixation break rate by Δt
6. Block-by-block learning curves

**Data Structures:**
```matlab
p.status.onlineMetrics.conflict.nGoalDirected   % 6×1 (by Δt)
p.status.onlineMetrics.conflict.nCapture        % 6×1 (by Δt)
p.status.onlineMetrics.congruent.nGoalDirected  % 6×1 (by Δt)
p.status.onlineMetrics.congruent.nCapture       % 6×1 (by Δt)
p.status.onlineMetrics.rtGoalDirected           % cell array of RTs
p.status.onlineMetrics.rtCapture                % cell array of RTs
p.status.onlineMetrics.fixBreakByDeltaT         % 6×1 (by Δt)
```

### Phase 8: Testing and Validation

**Unit Tests:**
1. Verify trial structure generation (360 trials, 6 blocks, correct allocation)
2. Verify Δt timing (stimulus onset relative to go signal)
3. Verify dual stimulus rendering
4. Verify outcome classification logic
5. Verify reward delivery (large vs. small)

**Integration Tests:**
1. Run simulated session with eye simulation
2. Verify state machine transitions
3. Verify timing machine handles negative Δt correctly
4. Verify online plots update correctly

**Behavioral Validation:**
1. Confirm fixation break handling with timeout
2. Confirm trial repetition for errors
3. Confirm block transitions and reward location changes

---

## Implementation Order

1. **Day 1: Scaffolding**
   - Create directory structure
   - Copy and adapt settings file
   - Create trial structure generation function

2. **Day 2: Core Trial Execution**
   - Implement modified timing machine for Δt
   - Implement dual-target draw machine
   - Implement two-target landing check

3. **Day 3: Outcome Classification and Rewards**
   - Implement outcome classification
   - Implement differential reward delivery
   - Implement trial repetition logic

4. **Day 4: Online Visualization**
   - Implement tachometric curve plotting
   - Implement RT distribution plotting
   - Implement status variable updates

5. **Day 5: Testing and Refinement**
   - Run simulated trials
   - Debug timing issues
   - Verify data logging

---

## Uncertainties and Questions

1. **Joystick Requirement:**
   - The design spec doesn't mention joystick. Should the task use joystick-triggered trial starts (like gSac_4factors) or automatic trial starts?
   - **Recommendation:** Keep joystick for consistency with existing training.

2. **Location A Specification:**
   - Design spec says "Experimenter-specified coordinates" for Location A.
   - Should this be a GUI-editable parameter, or set in settings file?
   - **Recommendation:** Make it a settings parameter with GUI override capability.

3. **Block Transition Handling:**
   - Design spec says "hard switch" with no signal.
   - Should there be any visual/audio indication to experimenter (but not subject)?
   - **Recommendation:** Log block transitions but provide no cue to subject.

4. **Stimulus Duration:**
   - Design spec says stimuli remain visible "until saccade completion."
   - Should stimuli turn off at saccade onset, offset, or target acquisition?
   - **Recommendation:** Keep visible until target acquisition (like gSac_4factors).

5. **Error Timeout Duration:**
   - Design spec mentions 0.5-1.0s timeout for fixation breaks.
   - Should this be the same for all error types?
   - **Recommendation:** Use 1.0s timeout for all errors (consistent with gSac_4factors: 2s).

6. **Neural Recording Integration:**
   - Should we preserve Ripple integration from gSac_4factors?
   - **Recommendation:** Yes, preserve all neural recording infrastructure.

---

## File Dependencies

Files to copy directly from gSac_4factors:
- `playTone.m`
- `postTrialTimeOut.m`
- `dkl2rgb.m`
- Calibration LUT files (LUT_VPIXX_rig*.{r,g,b})

Files to adapt from gSac_4factors:
- `initClut.m` (simplify for bullseyes only)
- `extraWindowSetup.m` (modify for new plot layout)
- `initCodes.m` (add new event codes)
- `updateStatusVariables.m` (new status structure)

Files to create new:
- `initTrialStructure.m` (completely new logic)
- `nextParams.m` (completely new logic)
- `updateOnlinePlots.m` (new tachometric curve plots)

---

## Implementation Status

**STATUS: COMPLETED**

### Files Created

**Main Task Files (5):**
- `conflict_task_settings.m` - All task parameters, states, timing, strobe list
- `conflict_task_init.m` - One-time initialization
- `conflict_task_next.m` - Pre-trial setup
- `conflict_task_run.m` - Trial execution (state/timing/draw machines)
- `conflict_task_finish.m` - Post-trial processing

**Support Functions (10):**
- `initTrialStructure.m` - NEW: Generates 6-block, 360-trial structure
- `nextParams.m` - NEW: Sets trial parameters including delta-t
- `updateOnlinePlots.m` - NEW: Tachometric curve visualization
- `extraWindowSetup.m` - NEW: Creates tachometric curve figure
- `updateStatusVariables.m` - Modified: Conflict-specific status tracking
- `initClut.m` - Adapted: DKL color lookup table
- `updateTrialsList.m` - Adapted: Trial completion tracking
- `playTone.m` - Copied from gSac_4factors
- `postTrialTimeOut.m` - Modified: Uses 1.0s timeout
- `initTrData.m` - Copied from gSac_4factors
- `initmon.m` - Copied: DKL color space initialization
- `dkl2rgb.m` - Copied: DKL to RGB conversion

**Calibration Files (8):**
- LUT_VPIXX_rig1.{r,g,b,xyY}
- LUT_VPIXX_rig2.{r,g,b,xyY}

---

## Document History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2026-01-28 | 1.0 | Claude | Initial implementation plan |
| 2026-01-28 | 2.0 | Claude | Implementation completed |
