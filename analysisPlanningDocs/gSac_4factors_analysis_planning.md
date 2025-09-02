# gSac_4factors Task: Data Analysis Plan

This document outlines the key components of the 'gSac_4factors' task in the PLDAPS codebase, designed to facilitate data analysis. It covers the task's goal, trial structure, experimental variables, and critical timing parameters.

## 1. Task Goal

The subject's primary objective is to perform a visually-guided saccade task. The subject must first acquire and hold fixation on a central point. A peripheral target is then presented, and after a "go" signal (the disappearance of the fixation point), the subject must make a quick and accurate eye movement (a saccade) to the target's location to receive a juice reward. The task manipulates several factors, including the visual properties of the target and background, the salience of the target, and the magnitude of the associated reward, to investigate their influence on saccadic eye movements.

## 2. Trial Structure & State Machine

The chronological flow of each trial is governed by a state machine defined in `tasks/gSac_4factors/gSac_4factors_run.m`. The key states and events are as follows:

- **p.state.trialBegun (State 1):** The trial officially starts.
- **p.state.waitForJoy (State 2):** The system waits for the subject to press and hold the joystick to initiate the trial. If the subject fails to press the joystick within `p.trVars.joyWaitDur`, the trial aborts to a `nonStart` state.
- **p.state.showFix (State 3):** A fixation point appears. The system waits for the subject's gaze to enter the fixation window. If fixation is not acquired within `p.trVars.fixWaitDur`, the trial aborts to a `nonStart` state.
- **p.state.dontMove (State 4):** The subject must maintain fixation. The peripheral target appears after a variable delay (`p.trVars.timeTargOnset`). After the target is on, the subject must continue to hold fixation until the fixation point disappears (`p.trVars.timeFixOffset`). Breaking fixation or releasing the joystick during this period aborts the trial to a `fixBreak` or `joyBreak` state, respectively.
- **p.state.makeSaccade (State 5):** The fixation point is extinguished (the "go" signal). The subject has a window of time (`p.trVars.goLatencyMin` to `p.trVars.goLatencyMax`) to initiate a saccade out of the fixation window. Failure to do so results in a `fixBreak`.
- **p.state.checkLanding (State 6):** The system checks if the saccade lands within the target window. If the saccade lands outside the target, the trial aborts to a `fixBreak`. Blinking during the saccade also aborts the trial.
- **p.state.holdTarg (State 7):** After a successful saccade, the subject must maintain gaze within the target window for a specified duration (`p.trVars.targHoldDuration`). Breaking this hold results in a `fixBreak`.
- **p.state.sacComplete (State 21):** The trial is successfully completed. A juice reward is delivered.
- **p.state.fixBreak (State 31):** An aborted trial state resulting from breaking eye fixation at an inappropriate time.
- **p.state.joyBreak (State 32):** An aborted trial state resulting from releasing the joystick prematurely.
- **p.state.nonStart (State 33):** An aborted trial state resulting from a failure to initiate the trial correctly (either by not pressing the joystick or not acquiring initial fixation).

## 3. Independent Variables (Experimental Factors)

These variables are manipulated across trials, defined in a trial array, and assigned in `gSac_4factors_settings.m`. The key factors are strobed at the end of each trial.

- **`stimType`**: An integer from 1 to 6 that defines the visual properties of the stimulus and background.
    - `1, 2`: Face or Non-Face Image target on a gray background.
    - `3, 4`: Bullseye target with high or low salience on a DKL color background.
    - `5, 6`: Bullseye target with high or low salience on a different DKL color background.
- **`salience`**: A variable indicating the target's salience level, often linked to `stimType`.
- **`reward`**: The magnitude of the reward associated with the trial (e.g., high or low). This is used to set `p.trVars.rewardDurationMs`.
- **`targetColor`**: Defines the hue of the target, particularly for the Bullseye stimuli.
- **`targetLocIdx`**: An index specifying the spatial location of the target from a predefined list (`p.stim.targLocationList`).
- **`isVisSac`**: A boolean indicating if it is a visually-guided (`true`) or memory-guided (`false`) saccade trial. For memory-guided trials, the target is flashed briefly and disappears before the "go" signal.

## 4. Key Dependent Variables (Performance Measures)

These are the primary outcomes recorded on each trial to assess performance, initialized in `p.init.trDataInitList` and stored in the `p.trData` structure.

- **`trialEndState`**: An integer code representing the final outcome of the trial (e.g., `p.state.sacComplete`, `p.state.fixBreak`). This is the most critical measure of trial success.
- **`timing.saccadeOnset`**: The timestamp when the saccade was initiated, relative to the "go" signal (fixation offset). This is used to calculate Saccadic Reaction Time (SRT).
- **`timing.saccadeOffset`**: The timestamp when the saccade ended.
- **`timing.fixAq`**: The timestamp when initial fixation was acquired.
- **`timing.fixBreak`**: The timestamp of any fixation break, if one occurred.
- **`timing.joyPress` / `timing.joyRelease`**: Timestamps for joystick press and release events.
- **Eye-tracking Data**:
  - `onlineGaze`: A matrix containing gaze position (`degX`, `degY`), timestamp, and calculated eye velocity for each while-loop iteration.
  - `preSacXY` & `postSacXY`: Gaze coordinates just before and after the saccade.
  - `peakVel`: The peak velocity of the saccade.

## 5. Critical Timing Parameters

These are user-configurable variables (defined in `p.trVarsInit` in `gSac_4factors_settings.m`) that control the pacing and difficulty of the trial.

- **`joyWaitDur`**: The maximum time (in seconds) to wait for a joystick press at the start of the trial.
- **`fixWaitDur`**: The maximum time (in seconds) to wait for fixation acquisition after the fixation point appears.
- **`targOnsetMin` / `targOnsetMax`**: The time range (in seconds) after fixation acquisition when the peripheral target can appear.
- **`goTimePostTargMin` / `goTimePostTargMax`**: The time range (in seconds) after target onset for the "go" signal (fixation offset) to occur.
- **`goLatencyMin` / `goLatencyMax`**: The time window (in seconds) after the "go" signal during which a saccade must be initiated.
- **`targHoldDurationMin` / `targHoldDurationMax`**: The required duration (in seconds) to hold gaze on the target after a successful saccade.
- **`rewardDurationHigh` / `rewardDurationLow`**: The duration (in milliseconds) of the solenoid opening for high and low rewards, respectively.
- **`targetFlashDuration`**: For memory-guided trials, the duration (in seconds) the target is visible before disappearing.
