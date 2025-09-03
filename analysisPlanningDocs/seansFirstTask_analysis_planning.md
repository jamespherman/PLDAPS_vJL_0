# seansFirstTask Task: Data Analysis Plan

This document outlines the key components of the 'seansFirstTask' task in the PLDAPS codebase, designed to facilitate data analysis. It covers the task's goal, trial structure, experimental variables, and critical timing parameters.

## 1. Task Goal

The subject's primary objective is to perform a visually-guided saccade task that requires discriminating between two types of stimuli. The subject must first initiate a trial by holding a joystick, then acquire and hold fixation on a central point. A stimulus, consisting of either one or two dots, is briefly presented. Following a "go" signal (the disappearance of the fixation point), the subject must make a saccade to one of two potential target locations. The correct target is determined by the number of dots in the preceding stimulus. A correct choice results in a juice reward.

## 2. Trial Structure & State Machine

The chronological flow of each trial is governed by a state machine defined in `tasks/seansFirstTask/seansFirstTask_run.m`. The key states and events are as follows:

- **p.state.trialBegun (State 1):** The trial officially starts.
- **p.state.waitForJoy (State 2):** The system waits for the subject to press and hold the joystick. Failure to do so within `p.trVars.joyWaitDur` aborts the trial to a `nonStart` state.
- **p.state.showFix (State 3):** A fixation point appears. The subject must acquire fixation within `p.trVars.fixWaitDur`, or the trial aborts to a `nonStart` state.
- **p.state.dontMove (State 4):** The subject must maintain fixation. The stimulus (one or two dots) appears after a variable delay. The subject must continue to hold fixation until the fixation point disappears. Breaking fixation or releasing the joystick during this period aborts the trial to a `fixBreak` or `joyBreak` state, respectively.
- **p.state.makeSaccade (State 5):** The fixation point is extinguished (the "go" signal). The subject has a window of time (`p.trVars.goLatencyMin` to `p.trVars.goLatencyMax`) to initiate a saccade. Failure to do so results in a `fixBreak`.
- **p.state.checkLanding (State 6):** The system checks if the saccade lands within one of the target windows. The landing determines which target was chosen.
- **p.state.holdTarg (State 7):** If the saccade lands on the correct target, the subject must maintain gaze within the target window for a specified duration (`p.trVars.targHoldDuration`). Breaking this hold results in a `fixBreak`.
- **p.state.sacComplete (State 21):** The trial is successfully completed, and a juice reward is delivered.
- **p.state.wrongTarget (State 22):** An aborted trial state resulting from the subject making a saccade to the incorrect target.
- **p.state.fixBreak (State 31):** An aborted trial state resulting from breaking eye fixation at an inappropriate time.
- **p.state.joyBreak (State 32):** An aborted trial state resulting from releasing the joystick prematurely.
- **p.state.nonStart (State 33):** An aborted trial state resulting from a failure to initiate the trial correctly.

## 3. Independent Variables (Experimental Factors)

These variables are manipulated across trials and are defined in `tasks/seansFirstTask/supportFunctions/initTrialStructure.m`.

- **`numDots`**: The number of dots presented in the stimulus (1 or 2). This is the primary feature for the subject to discriminate.
- **`numTargets`**: The number of targets presented on the screen (1 or 2).
- **`targsSameColor`**: A boolean (`true` or `false`) indicating whether the targets are the same color.
- **`stimShape`**: An integer defining the shape of the stimulus (1 for oval, 2 for rectangle, 3 for a combination).
- **Target Location**: The spatial position of the targets, which can be configured in `seansFirstTask_settings.m` to be on a 'grid', 'ring', or at 'preset_quatro' locations.

## 4. Key Dependent Variables (Performance Measures)

These are the primary outcomes recorded on each trial to assess performance, stored in the `p.trData` structure.

- **`trialEndState`**: An integer code representing the final outcome of the trial (e.g., `p.state.sacComplete`, `p.state.wrongTarget`, `p.state.fixBreak`). This is the most critical measure of trial success and accuracy.
- **`timing.saccadeOnset`**: The timestamp when the saccade was initiated, used to calculate Saccadic Reaction Time (SRT).
- **`timing.saccadeOffset`**: The timestamp when the saccade ended.
- **`wrongTargetFlag`**: A boolean flag set to `true` if the subject chooses the incorrect target.
- **Eye-tracking Data**: Continuous gaze position is available for detailed analysis of saccade trajectories and kinematics.

## 5. Critical Timing Parameters

These are user-configurable variables (defined in `p.trVarsInit` in `seansFirstTask_settings.m`) that control the pacing and difficulty of the trial.

- **`joyWaitDur`**: The maximum time (in seconds) to wait for a joystick press.
- **`fixWaitDur`**: The maximum time (in seconds) to wait for fixation acquisition.
- **`stimOnsetMin` / `stimOnsetMax`**: The time range (in seconds) after fixation acquisition when the stimulus can appear.
- **`stimDurMin` / `stimDurMax`**: The duration (in seconds) for which the stimulus is presented.
- **`targOnsetMin` / `targOnsetMax`**: The time range (in seconds) after stimulus offset when the target(s) can appear.
- **`goTimePostTargMin` / `goTimePostTargMax`**: The time range (in seconds) after target onset for the "go" signal to occur.
- **`goLatencyMin` / `goLatencyMax`**: The time window (in seconds) after the "go" signal during which a saccade must be initiated.
- **`targHoldDurationMin` / `targHoldDurationMax`**: The required duration (in seconds) to hold gaze on the target after a successful saccade.
- **`rewardDurationMs`**: The duration (in milliseconds) of the juice reward.
- **`maxSacDurationToAccept`**: The maximum duration (in seconds) of a saccade that is considered valid.
