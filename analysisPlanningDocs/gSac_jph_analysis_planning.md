# gSac_jph Task: Data Analysis Plan

This document outlines the key components of the 'gSac_jph' task in the PLDAPS codebase, designed to facilitate data analysis. It covers the task's goal, trial structure, experimental variables, and critical timing parameters.

## 1. Task Goal

The subject's primary objective is to perform a guided saccade task. The subject must first acquire and hold fixation on a central point. A peripheral target then appears, which either remains on-screen (visually-guided saccade) or disappears after a brief flash (memory-guided saccade). Following a 'go' signal (the disappearance of the fixation point), the subject must make an eye movement (a saccade) to the target's location to receive a juice reward.

## 2. Trial Structure & State Machine

The chronological flow of each trial is governed by a state machine defined in `tasks/gSac_jph/gSac_jph_run.m`. The key states and events are as follows:

- **p.state.trialBegun (State 1):** The trial officially starts.
- **p.state.waitForJoy (State 2):** The system waits for the subject to press and hold the joystick. Failure to do so within `p.trVars.joyWaitDur` aborts the trial to a `nonStart` state.
- **p.state.showFix (State 3):** A fixation point appears. The system waits for the subject's gaze to enter the fixation window. If fixation is not acquired within `p.trVars.fixWaitDur`, the trial aborts to a `nonStart` state.
- **p.state.dontMove (State 4):** The subject must maintain fixation. The peripheral target appears after a variable delay (`p.trVars.timeTargOnset`). The subject must continue to hold fixation until the fixation point disappears (`p.trVars.timeFixOffset`). Breaking fixation or releasing the joystick during this period aborts the trial to a `fixBreak` or `joyBreak` state, respectively.
- **p.state.makeSaccade (State 5):** The fixation point is extinguished (the "go" signal). The subject has a window of time (`p.trVars.goLatencyMin` to `p.trVars.goLatencyMax`) to initiate a saccade. Failure to do so results in a `fixBreak`.
- **p.state.checkLanding (State 6):** The system checks if the saccade lands within the target window. If the saccade lands outside the target or a blink is detected, the trial aborts to a `fixBreak`.
- **p.state.holdTarg (State 7):** After a successful saccade, the subject must maintain gaze within the target window for a specified duration (`p.trVars.targHoldDuration`). Breaking this hold results in a `fixBreak`.
- **p.state.sacComplete (State 21):** The trial is successfully completed. A juice reward is delivered.
- **p.state.fixBreak (State 31):** An aborted trial state resulting from breaking eye fixation at an inappropriate time.
- **p.state.joyBreak (State 32):** An aborted trial state resulting from releasing the joystick prematurely.
- **p.state.nonStart (State 33):** An aborted trial state resulting from a failure to initiate the trial correctly.

## 3. Independent Variables (Experimental Factors)

These variables are manipulated across trials and are primarily defined in `gSac_jph_settings.m` and `supportFunctions/nextParams.m`.

- **`isVisSac`**: A boolean (`1` or `0`) that determines whether the trial is visually-guided (target remains visible) or memory-guided (target is flashed briefly). The proportion of visual trials is controlled by `p.trVars.propVis`.
- **Target Location (`targDegX`, `targDegY`)**: The spatial coordinates of the saccade target. The location can be determined in several ways:
    - **`setTargLocViaTrialArray`**: From a predefined list of target elevations in `initTrialStructure.m`.
    - **`setTargLocViaGui`**: Manually set by the experimenter through the GUI.
    - **`setTargLocViaMouse`**: Set to the location of the mouse cursor at trial start.
    - **Random**: Chosen from a predefined grid or ring of locations (`p.stim.targLocationPreset`).
- **`targTheta` & `targRadius`**: Polar coordinates of the target location, derived from `targDegX` and `targDegY`, which are strobed for recording.

## 4. Key Dependent Variables (Performance Measures)

These are the primary outcomes recorded on each trial to assess performance, initialized via `p.init.trDataInitList` and stored in the `p.trData` structure.

- **`trialEndState`**: An integer code representing the final outcome of the trial (e.g., `p.state.sacComplete`, `p.state.fixBreak`). This is the most critical measure of trial success.
- **`timing.saccadeOnset`**: The timestamp when the saccade was initiated. This is used to calculate Saccadic Reaction Time (SRT).
- **`timing.saccadeOffset`**: The timestamp when the saccade ended.
- **`timing.targetAq`**: The timestamp when the target was acquired.
- **`timing.fixBreak`**: The timestamp of any fixation break, if one occurred.
- **Eye-tracking Data**:
  - `onlineGaze`: A matrix containing gaze position (`degX`, `degY`), timestamp, and calculated eye velocity.
  - `preSacXY` & `postSacXY`: Gaze coordinates just before and after the saccade.
  - `peakVel`: The peak velocity of the saccade.
  - `SRT`: Saccadic Reaction Time.

## 5. Critical Timing Parameters

These are user-configurable variables (defined in `p.trVarsInit` in `gSac_jph_settings.m`) that control the pacing and difficulty of the trial.

- **`joyWaitDur`**: Maximum time (s) to wait for a joystick press.
- **`fixWaitDur`**: Maximum time (s) to wait for fixation acquisition.
- **`targOnsetMin` / `targOnsetMax`**: Time range (s) after fixation acquisition for the target to appear.
- **`goTimePostTargMin` / `goTimePostTargMax`**: Time range (s) after target onset for the "go" signal (fixation offset).
- **`goLatencyMin` / `goLatencyMax`**: Time window (s) after the "go" signal to initiate a saccade.
- **`targHoldDurationMin` / `targHoldDurationMax`**: Required duration (s) to hold gaze on the target post-saccade.
- **`rewardDurationMs`**: Duration (ms) of the juice reward.
- **`targetFlashDuration`**: For memory-guided trials, the duration (s) the target is visible.
