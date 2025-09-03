# joystick_release_for_stim_change_and_dim Task: Data Analysis Plan

This document outlines the key components of the 'joystick_release_for_stim_change_and_dim' task in the PLDAPS codebase, designed to facilitate data analysis. It covers the task's goal, trial structure, experimental variables, and critical timing parameters.

## 1. Task Goal

The subject's primary objective is to detect a change in a visual stimulus and report it by releasing a joystick. The subject must first press and hold a joystick, then acquire and maintain fixation on a central point. One or more peripheral stimuli are presented. On "change" trials, one of the stimuli will change one of its visual features (e.g., orientation, hue, luminance) after a variable delay. The subject must release the joystick within a specific time window after the change to receive a reward. On "no-change" trials, no stimulus change occurs, and the subject must continue to hold the joystick to receive a reward. The task is designed to measure reaction times and the ability to detect changes in various visual features under different conditions (e.g., number of stimuli, cueing).

## 2. Trial Structure & State Machine

The chronological flow of each trial is governed by a state machine defined in `tasks/joystick_release_for_stim_change_and_dim/joystick_release_for_stim_change_and_dim_run.m`. The key states and events are as follows:

-   **`p.state.trialBegun` (State 1):** The trial officially starts.
-   **`p.state.waitForJoy` (State 2):** The system waits for the subject to press and hold the joystick. If the subject fails to press the joystick within `p.trVars.joyWaitDur`, the trial aborts to a `nonStart` state.
-   **`p.state.showFix` (State 3):** A fixation point appears. The system waits for the subject's gaze to enter the fixation window. If fixation is not acquired within `p.trVars.fixWaitDur`, the trial aborts to a `nonStart` or `joyBreak` state.
-   **`p.state.dontMove` (State 4):** The subject must maintain fixation and hold the joystick. Peripheral stimuli are presented. The system waits for the stimulus change time (`p.trVars.stimChangeTime`). Breaking fixation or releasing the joystick prematurely aborts the trial to a `fixBreak` or `joyBreak`/`fa` state.
-   **`p.state.makeDecision` (State 5):** The stimulus change (or a sham change on "no-change" trials) occurs. The subject must decide whether to release the joystick.
-   **`p.state.hit`:** Successful outcome. The subject correctly released the joystick within the response window (`p.trVars.joyMinLatency` to `p.trVars.joyMaxLatency`) on a "change" trial. A reward is delivered.
-   **`p.state.miss`:** Unsuccessful outcome. The subject failed to release the joystick on a "change" trial.
-   **`p.state.fa` (False Alarm):** Unsuccessful outcome. The subject released the joystick on a "no-change" trial or outside the valid response window on a "change" trial.
-   **`p.state.cr` (Correct Reject):** Successful outcome. The subject correctly held the joystick on a "no-change" trial. A reward may be delivered.
-   **`p.state.fixBreak` (State 11):** An aborted trial state resulting from breaking eye fixation at an inappropriate time.
-   **`p.state.joyBreak` (State 12):** An aborted trial state resulting from releasing the joystick prematurely before the decision window.
-   **`p.state.nonStart` (State 13):** An aborted trial state resulting from a failure to initiate the trial correctly.

## 3. Independent Variables (Experimental Factors)

These variables are manipulated across trials, defined in `initTrialStructure.m` and a settings file (e.g., `joystick_release_for_orient_change_and_dim_settings_6040.m`). The key factors are defined in `p.init.trialArrayColumnNames`.

-   **`cue loc`**: The location of the spatial cue, indicating the likely location of the stimulus change.
-   **`n stim`**: The number of stimuli presented on the screen (e.g., 1, 2, 4).
-   **`stim chg`**: An integer indicating which stimulus (1-4) will change. A value of 0 indicates a "no-change" trial.
-   **Feature Change Dimensions**: A set of boolean flags that determine which visual feature will change:
    -   `speed`
    -   `orientation`
    -   `spatial frequency`
    -   `saturation`
    -   `hue`
    -   `luminance`
    -   `contrast`
-   **`isOptoStimTrial`**: (In some versions) A boolean indicating if optogenetic stimulation is delivered on the trial.

## 4. Key Dependent Variables (Performance Measures)

These are the primary outcomes recorded on each trial to assess performance, initialized in `p.init.trDataInitList` and stored in the `p.trData` structure.

-   **`trialEndState`**: An integer code representing the final outcome of the trial (e.g., `p.state.hit`, `p.state.miss`, `p.state.fa`, `p.state.cr`, `p.state.fixBreak`). This is the most critical measure of trial success.
-   **`timing.reactionTime`**: The latency to release the joystick, calculated from the time of the stimulus change (`p.trData.timing.stimChg`) to the time of joystick release (`p.trData.timing.joyRelease`).
-   **`timing.joyPress` / `timing.joyRelease`**: Timestamps for joystick press and release events.
-   **`timing.fixAq` / `timing.fixBreak`**: Timestamps for fixation acquisition and break events.
-   **`timing.stimOn` / `timing.stimChg`**: Timestamps for the onset of the stimulus and the stimulus change.
-   **Eye-tracking Data**:
    -   `onlineEyeX`, `onlineEyeY`: Gaze position in degrees, recorded during the trial loop.

## 5. Critical Timing Parameters

These are user-configurable variables (defined in `p.trVarsInit` in the settings file) that control the pacing and difficulty of the trial.

-   **`joyWaitDur`**: The maximum time (in seconds) to wait for a joystick press at the start of the trial.
-   **`fixWaitDur`**: The maximum time (in seconds) to wait for fixation acquisition.
-   **`fix2CueIntvl`**: The time delay (in seconds) between acquiring fixation and the onset of a spatial cue.
-   **`cueDur`**: The duration (in seconds) of the spatial cue presentation.
-   **`stim2ChgIntvl`**: The minimum time (in seconds) between stimulus onset and the earliest possible stimulus change.
-   **`chgWinDur`**: The duration of the window (in seconds) after `stim2ChgIntvl` during which the change can occur.
-   **`joyMinLatency`**: The minimum allowed reaction time (in seconds) to release the joystick after a change for it to be considered a Hit.
-   **`joyMaxLatency`**: The maximum allowed reaction time (in seconds) to release the joystick after a change.
-   **`rewardDurationMs`**: The duration (in milliseconds) of the juice reward.
-   **`rewardDelay`**: The delay (in seconds) between a correct response (Hit/CR) and reward delivery.
-   **`timeoutAfterFa` / `timeoutAfterMiss` / `timeoutAfterFixBreak`**: The duration (in seconds) of the penalty timeout for different error types.
