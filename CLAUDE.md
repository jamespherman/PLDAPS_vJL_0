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

## Caveats

- The GUI uses `eval()` for dynamic task function dispatch (see IMPROVEMENT_PLAN.md for modernization recommendations)
- Frame-by-frame execution is timing-critical; avoid adding slow operations to `_run.m`
- All hardware access should go through `+pds` functions for proper abstraction
