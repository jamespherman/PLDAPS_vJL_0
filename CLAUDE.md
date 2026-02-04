# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PLDAPS_vK2 is a MATLAB-based framework for conducting neurophysiology and psychophysics experiments. It manages real-time hardware interaction (eye tracking, joystick input, reward delivery), stimulus presentation via Psychtoolbox, and synchronized ephys recording via strobing event codes to neural acquisition systems.

**Primary use case:** Primate behavioral experiments with frame-rate synchronized stimulus presentation (~100Hz), precise timing via DataPixx/ViewPixx hardware, and integration with neural recording systems (Omniplex, Ripple).

## Architecture

### The "Quintet" Pattern

Every experimental task consists of exactly five files that control the experiment lifecycle:

1. **`taskName_settings.m`** - Initializes all task parameters (called once when loading)
2. **`taskName_init.m`** - Hardware setup, stimulus loading (called once on "Initialize")
3. **`taskName_next.m`** - Pre-trial setup, picks conditions (called before each trial)
4. **`taskName_run.m`** - Trial execution with frame-by-frame state machine (called each trial)
5. **`taskName_finish.m`** - Data saving, metric updates (called after each trial)

Each task also has a `supportFunctions/` subdirectory for task-specific helpers.

### The Central Data Structure: `p`

All experiment state flows through a single structure `p` containing:

- **`p.trVars`** - Trial variables (change per trial, GUI-controllable)
- **`p.trVarsGuiComm`** - GUI communication interface for parameter modification
- **`p.trData`** - Collected trial data (eye position, timing, outcomes)
- **`p.rig`** - Hardware configuration (screen geometry, joystick calibration, DataPixx settings)
- **`p.init`** - Session-level metadata and task file references
- **`p.state`** - Named state definitions with integer IDs for state machine
- **`p.draw`** - Visual drawing parameters and color LUT
- **`p.audio`** - Audio feedback parameters

### Directory Structure

- **`+pds/`** - Core library package (61 shared functions for hardware I/O, data management)
- **`+pdsActions/`** - User-callable actions from GUI (reward delivery, audio control)
- **`+rigConfigFiles/`** - PC-specific hardware configurations
- **`tasks/`** - Experimental task implementations (22 tasks, each follows quintet pattern)
- **`stimuli/`** - Stimulus files (images, movies)
- **`data_dictionaries/`** - Documentation of saved data structures
- **`analysisPlanningDocs/`** - Task design and analysis specifications

### Key +pds Functions

**Hardware I/O:**
- `pds.getEyeJoy` - Read eye position and joystick voltage from DataPixx
- `pds.deliverReward` - Generate liquid reward via solenoid
- `pds.initDataPixx`, `pds.initPsychToolbox` - Hardware initialization
- `pds.getTimes` - Get synchronized PTB and DataPixx timestamps

**Eye/Joystick Monitoring:**
- `pds.eyeInWindow` - Check if eye is within target window
- `pds.joyHeld`, `pds.joyReld` - Detect joystick press/release

**Data & Codes:**
- `pds.storeDataInPDS` - Save trial data to .mat file
- `pds.code2str`, `pds.str2code` - Convert event codes to/from strings
- `pds.classyStrobe` - Object for managing event strobing to ephys systems

### Strobe Code System (CRITICAL)

The strobe code system sends event markers to neural recording systems (Omniplex, Ripple) for synchronization. **This file is HOLY** - once recording has been done, `+pds/initCodes.m` is the only way to reconstruct when events occurred in the ephys data.

**How it works:**

1. **`+pds/initCodes.m`** defines all strobe codes as a struct:
   ```matlab
   codes.fixOn = 3001;      % integer code sent to ephys
   codes.targetOn = 4001;
   codes.deltaT = 16020;    % conflict_task specific
   ```

2. **`p.init.strobeList`** (in each `_settings.m`) defines what to strobe per trial:
   ```matlab
   p.init.strobeList = {
       'fixOn',        'p.trData.timing.fixOn';     % code name, value expression
       'deltaT',       'p.trVars.deltaT + 1000';    % offset handles negatives
   };
   ```

3. **During `_init.m`**, codes are loaded: `p.init.codes = pds.initCodes;`

4. **`pds.strobeTrialData(p)`** loops over `strobeList`, looks up each code name in `p.init.codes`, and strobes the (code, value) pair.

**CRITICAL REQUIREMENT:** Every code name in column 1 of `p.init.strobeList` **must** have a matching field in `+pds/initCodes.m`. Missing codes will silently fail (caught by try/catch).

**Handling negative values:** Strobe values must be positive integers. For variables that can be negative:
- Add an offset (e.g., `deltaT + 1000` for values in range -1000 to +1000)
- Use angle/radius instead of x/y coordinates for locations

**Target location convention:** Use polar coordinates (theta, radius) instead of Cartesian (x, y):
```matlab
'targetTheta',   'p.trVars.targTheta_x10';      % angle * 10
'targetRadius',  'p.trVars.targRadius_x100';    % eccentricity * 100
```
For angles that can be negative (-180 to +180), add 1800 after scaling by 10.

## Running the Framework

1. Launch MATLAB and run `PLDAPS_vK2_GUI.m`
2. Click "Browse" and select a `_settings.m` file from a task directory
3. Click "Initialize" to run the task's `_init.m`
4. Click "Run" to start the trial loop (`_next.m` → `_run.m` → `_finish.m` per trial)

## Creating a New Task

1. Create directory in `tasks/` (e.g., `tasks/myNewTask/`)
2. Copy quintet files from an existing similar task
3. Create `supportFunctions/` subdirectory for helpers
4. Implement state machine logic in `_run.m`
5. Use `+pds` functions for all hardware access
6. **Define `p.init.strobeList`** in `_settings.m` with task-specific variables to strobe
7. **Add any new strobe codes** to `+pds/initCodes.m` - every code name in `strobeList` must exist in `initCodes.m`

## Dependencies

- **MATLAB** (R2018 or later)
- **Psychtoolbox-3** - Stimulus display and timing
- **DataPixx/ViewPixx Toolbox** - VPixx hardware communication
- **Eyelink SDK** (optional) - Eye tracking
- **Ripple/Omniplex APIs** (optional) - Neural recording integration

## Known Code Patterns

**State machine in `_run.m`:** Trial logic uses a while loop with state transitions:
```matlab
while p.trVars.currentState ~= p.state.trialDone
    % Get inputs
    p = pds.getEyeJoy(p);
    % Check state conditions and transition
    switch p.trVars.currentState
        case p.state.waitForFixation
            if pds.eyeInWindow(p)
                p.trVars.currentState = p.state.holdFixation;
            end
        % ... more states
    end
    % Draw and flip
    Screen('Flip', p.draw.window);
end
```

**Rig configuration loading:** Tasks load rig-specific configs via:
```matlab
p = rigConfigFiles.rigConfig_rig1(p);
```

### Timing Variables and the postFlip Convention (CRITICAL)

Timing variables in `p.trData.timing` (e.g., `fixOn`, `fixOff`, `stimOn`) are initialized to `-1` in each task's `_settings.m` file. This allows checking whether a timing event has occurred:
- `-1` = event has NOT occurred yet
- `> 0` = event has occurred, value is the timestamp

**The postFlip mechanism:** Visual event times (fixation onset, stimulus onset, etc.) must be recorded AFTER the screen flip that displays them. This is handled by:
1. Adding the variable name to `p.trVars.postFlip.varNames` before the flip
2. The `drawMachine` assigns the actual timestamp after `Screen('Flip', ...)` executes

**CRITICAL BUG PATTERN:** When a state transition occurs (e.g., from `dontMove` to `makeSaccade`), timing variables set via postFlip may still be `-1` on the first iteration because the flip hasn't happened yet.

**WRONG - will compute incorrect time:**
```matlab
case p.state.makeSaccade
    timeSinceGo = timeNow - p.trData.timing.fixOff;  % BUG: fixOff may be -1!
    if timeSinceGo > p.trVars.responseWindow
        % This triggers immediately with huge timeSinceGo value
    end
```

**CORRECT - check timing variable is valid first:**
```matlab
case p.state.makeSaccade
    if p.trData.timing.fixOff > 0
        timeSinceGo = timeNow - p.trData.timing.fixOff;
        if timeSinceGo > p.trVars.responseWindow
            % Safe: only checked when fixOff has real value
        end
    else
        return  % Skip timing checks until fixOff is assigned
    end
```

**Rule:** Always check `p.trData.timing.X > 0` before using timing variable `X` in calculations, especially for variables set via the postFlip mechanism.

### Conflict Task: Salience via DKL Color Contrast

In the conflict task, target salience is created through **hue contrast with background**, not by using the same color for both targets:

- **High-salience target**: hue 180° away from background (maximum contrast)
- **Low-salience target**: hue 45° away from background (low contrast)

| backgroundHueIdx | Background | High Sal Target | Low Sal Target |
|------------------|------------|-----------------|----------------|
| 1 (Hue A) | 0° DKL | 180° DKL | 45° DKL |
| 2 (Hue B) | 180° DKL | 0° DKL | 225° DKL |

The `highSalienceSide` variable (1=left, 2=right) determines which physical target gets the high-salience hue. This is set per-trial in `nextParams.m`:
```matlab
p.trVars.leftTargHueIdx = ...;   % Assigned based on highSalienceSide
p.trVars.rightTargHueIdx = ...;  % Each target drawn with its own hue
```

**Common mistake:** Drawing both targets with the same hue creates equal salience for both, defeating the purpose of the manipulation.

## Caveats

- The GUI uses `eval()` for dynamic task function dispatch (see IMPROVEMENT_PLAN.md for modernization recommendations)
- Frame-by-frame execution is timing-critical; avoid adding slow operations to `_run.m`
- All hardware access should go through `+pds` functions for proper abstraction
