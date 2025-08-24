# Documentation for '4factors' Task Data Structures

This document provides a comprehensive explanation of the fields and subfields of the data structures saved during the '4factors' task. The 'p' structure is saved once at the beginning of a session, while a structure containing `p.trVars` and `p.trData` is saved for each trial.

## `p` Structure

The `p` structure contains all the parameters and settings for the experiment. It is initialized at the beginning of the experiment and saved once per session.

### `p.init`

This substructure contains initialization parameters for the task.

- `p.init.pcName`: The name of the computer running the experiment.
- `p.init.rigConfigFile`: The path to the rig configuration file.
- `p.init.taskName`: The name of the task (e.g., 'gSac_4factors').
- `p.init.pldapsFolder`: The root folder of the PLDAPS installation.
- `p.init.protocol_title`: The title of the experimental protocol.
- `p.init.date`: The date the experiment was run (yyyymmdd).
- `p.init.time`: The time the experiment was run (HHMM).
- `p.init.outputFolder`: The folder where output files are saved.
- `p.init.sessionId`: A unique identifier for the session.
- `p.init.sessionFolder`: The folder for the current session's data.
- `p.init.taskFiles`: A structure containing the names of the init, next, run, and finish files for the task.
- `p.init.useDataPixxBool`: A boolean indicating whether to use the DataPixx/ViewPixx.
- `p.init.taskActions`: A cell array of strings with the names of action M-files.
- `p.init.exptType`: A string indicating which version of the experiment is running.
- `p.init.trDataInitList`: A cell array that lists the trial data variables (`p.trData`) and their initial values.
- `p.init.nTrDataListRows`: The number of rows in `p.init.trDataInitList`.
- `p.init.strobeList`: A cell array defining the variables to be strobed at the end of each trial.
- `p.init.trialsArray`: An array that defines the parameters for each trial in the experiment. The columns are defined by `p.init.trialArrayColumnNames`.
- `p.init.trialArrayColumnNames`: A cell array of strings that are the column headers for `p.init.trialsArray`. These include:
    - `halfBlock`: The half-block number.
    - `targetLocIdx`: The index of the target location.
    - `stimType`: The type of stimulus (1: Face, 2: Non-Face, 3: HS/TC1, 4: LS/TC1, 5: HS/TC2, 6: LS/TC2).
    - `salience`: The salience of the stimulus (0 for images, 1 for high, 2 for low).
    - `reward`: The reward magnitude (1 for high, 2 for low).
    - `targetColor`: The color of the target (0 for images, 1 or 2 for bullseye).
    - `numTrials`: The number of trials for this condition.
    - `trialCode`: A unique code for the trial condition.
    - `completed`: A flag indicating if the trial has been completed.

### `p.rig`

This substructure contains parameters related to the experimental rig.

- `p.rig.screen_number`: The screen number for the display.
- `p.rig.refreshRate`: The refresh rate of the display in Hz.
- `p.rig.frameDuration`: The duration of a single frame in seconds.
- `p.rig.joyThreshPress`: The voltage threshold for a joystick press.
- `p.rig.joyThreshRelease`: The voltage threshold for a joystick release.
- `p.rig.magicNumber`: A small time adjustment for screen flips.
- `p.rig.joyVoltageMax`: The maximum voltage of the joystick.
- `p.rig.guiStatVals`: A cell array of status variable names to be displayed in the GUI.
- `p.rig.guiVars`: A cell array of trial variable names to be displayed in theGUI.

### `p.audio`

This substructure contains parameters for auditory feedback.

- `p.audio.audsplfq`: The sampling frequency for audio.
- `p.audio.Hitfq`: The frequency of the tone for a correct trial.
- `p.audio.Missfq`: The frequency of the tone for an incorrect trial.
- `p.audio.auddur`: The duration of the audio tone.

### `p.draw`

This substructure contains parameters related to drawing visual stimuli.

- `p.draw.clutIdx`: A structure that defines the indices for the Color Look-Up Table (CLUT).
- `p.draw.color`: A structure that defines the colors for various task elements, using the indices from `p.draw.clutIdx`.
- `p.draw.fixPointWidth`: The width of the fixation point in pixels.
- `p.draw.fixPointRadius`: The radius of the fixation point in pixels.
- `p.draw.fixWinPenThin`, `p.draw.fixWinPenThick`, `p.draw.fixWinPenDraw`: Pen widths for the fixation window.
- `p.draw.targWinPenThin`, `p.draw.targWinPenThick`, `p.draw.targWinPenDraw`: Pen widths for the target window.
- `p.draw.eyePosWidth`: The width of the eye position indicator in pixels.
- `p.draw.gridSpacing`: The spacing of the grid on the experimenter's display in degrees.
- `p.draw.gridW`: The width of the grid lines.
- `p.draw.joyRect`: The position of the joystick indicator rectangle on the experimenter's display.
- `p.draw.cursorW`: The width of the cursor in pixels.
- `p.draw.middleXY`: The pixel coordinates of the center of the screen.
- `p.draw.window`: The handle for the PTB window.

### `p.state`

This substructure defines the different states of the trial state machine.

- `p.state.trialBegun`: State for the beginning of the trial.
- `p.state.waitForJoy`: State for waiting for the joystick to be pressed.
- `p.state.showFix`: State for showing the fixation point.
- `p.state.dontMove`: State for maintaining fixation.
- `p.state.makeSaccade`: State for initiating a saccade.
- `p.state.checkLanding`: State for checking the saccade landing position.
- `p.state.holdTarg`: State for holding fixation on the target.
- `p.state.sacComplete`: State for a successful saccade.
- `p.state.fixBreak`: End state for a fixation break.
- `p.state.joyBreak`: End state for a joystick release error.
- `p.state.nonStart`: End state for failing to start the trial.
- `p.state.failedToHoldTarg`: End state for failing to hold the target.

### `p.status`

This substructure contains status variables that are updated throughout the experiment.

- `p.status.iTrial`: The current trial number.
- `p.status.iGoodTrial`: The number of good trials.
- `p.status.iGoodVis`, `p.status.iGoodMem`: The number of good visual and memory guided trials.
- `p.status.pGoodVis`, `p.status.pGoodMem`: The proportion of good visual and memory guided trials.
- `p.status.iTarget`: The index of the current target.
- `p.status.rippleOnline`: A flag indicating if Ripple is online.
- `p.status.tLoc1HighRwdFirst`: A flag for reward location.
- `p.status.trialsArrayRowsPossible`: A logical array indicating which trials from `p.init.trialsArray` are available to be run.

### `p.stim`

This substructure contains parameters for the visual stimuli.

- `p.stim.targLocationPreset`: The method for generating target locations ('grid', 'ring', 'nRing').
- `p.stim.dotWidth`: The width of the target dot in pixels.
- `p.stim.stimDiamDeg`: The diameter of the stimulus images in degrees.
- `p.stim.nStimLevels`: The number of intensity levels for the stimuli.
- `p.stim.gridMinX`, `p.stim.gridMaxX`, `p.stim.gridBinSizeX`: Parameters for the 'grid' preset.
- `p.stim.gridMinY`, `p.stim.gridMaxY`, `p.stim.gridBinSizeY`: Parameters for the 'grid' preset.
- `p.stim.ringRadius`, `p.stim.ringTargNumber`, `p.stim.ringBaseAngle`: Parameters for the 'ring' and 'nRing' presets.

## `p.trVars`

This structure contains variables that can change on a trial-by-trial basis. The values in `p.trVars` are inherited from `p.trVarsInit` at the start of each trial and can be modified by the GUI via `p.trVarsGuiComm`.

- `p.trVars.passJoy`, `p.trVars.passEye`: Booleans to simulate correct joystick or eye movements for debugging.
- `p.trVars.connectPLX`: Boolean to connect to Plexon.
- `p.trVars.joyPressVoltDirection`: Direction of voltage change on joystick press.
- `p.trVars.blockNumber`: The current block number.
- `p.trVars.repeat`: Boolean to repeat the current trial.
- `p.trVars.rwdJoyPR`: Boolean to determine if reward is given for press or release.
- `p.trVars.wantEndFlicker`: Boolean for screen flicker at trial end.
- `p.trVars.finish`: The number of trials to run.
- `p.trVars.filesufix`: Suffix for saved files.
- `p.trVars.joyVolt`: The current joystick voltage.
- `p.trVars.eyeDegX`, `p.trVars.eyeDegY`: Eye position in degrees.
- `p.trVars.eyePixX`, `p.trVars.eyePixY`: Eye position in pixels.
- `p.trVars.mouseEyeSim`: Boolean to simulate eye position with the mouse.
- `p.trVars.setTargLocViaMouse`, `p.trVars.setTargLocViaGui`, `p.trVars.setTargLocViaTrialArray`: Booleans to determine how target location is set.
- `p.trVars.propVis`: Proportion of visually-guided saccade trials.
- `p.trVars.fixDegX`, `p.trVars.fixDegY`: Fixation point location in degrees.
- `p.trVars.targDegX`, `p.trVars.targDegY`, `p.trVars.targDegX_base`, `p.trVars.targDegY_base`: Target location in degrees.
- `p.trVars.rewardDurationHigh`, `p.trVars.rewardDurationLow`, `p.trVars.rewardDurationMs`: Reward durations in milliseconds.
- `p.trVars.rwdSize`: The reward size for the current trial (1=high, 2=low).
- `p.trVars.rewardDelay`: Delay before reward delivery.
- `p.trVars.timeoutAfterFa`: Duration of timeout after a false alarm.
- `p.trVars.joyWaitDur`: Time to wait for joystick press.
- `p.trVars.fixWaitDur`: Time to wait for fixation acquisition.
- `p.trVars.freeDur`: Duration of free time at the start of a trial.
- `p.trVars.trialMax`: Maximum trial length.
- `p.trVars.joyReleaseWaitDur`: Time to wait for joystick release at the end of a trial.
- `p.trVars.stimFrameIdx`, `p.trVars.flipIdx`: Frame indices.
- `p.trVars.postRewardDuration`: Duration of the trial after reward.
- `p.trVars.joyPressVoltDir`: Direction of voltage change for joystick press.
- `p.trVars.targetFlashDuration`: Duration of target flash in memory-guided trials.
- `p.trVars.targHoldDurationMin`, `p.trVars.targHoldDurationMax`: Min and max duration to hold target.
- `p.trVars.maxSacDurationToAccept`: Maximum duration of a saccade.
- `p.trVars.goLatencyMin`, `p.trVars.goLatencyMax`: Min and max saccade latency.
- `p.trVars.targOnsetMin`, `p.trVars.targOnsetMax`: Min and max time to target onset.
- `p.trVars.goTimePostTargMin`, `p.trVars.goTimePostTargMax`: Min and max time from target onset to go signal.
- `p.trVars.maxFixWait`: Maximum time to wait for fixation.
- `p.trVars.targOnSacOnly`: Boolean to make target reappear on saccade.
- `p.trVars.rwdTime`: Time of reward.
- `p.trVars.targTrainingDelay`: Delay for target onset in training.
- `p.trVars.timeoutdur`: Duration of timeout after an error.
- `p.trVars.minTargAmp`, `p.trVars.maxTargAmp`, `p.trVars.staticTargAmp`, `p.trVars.maxHorzTargAmp`, `p.trVars.maxVertTargAmp`: Target amplitude parameters.
- `p.trVars.fixWinWidthDeg`, `p.trVars.fixWinHeightDeg`: Fixation window dimensions in degrees.
- `p.trVars.targWinWidthDeg`, `p.trVars.targWinHeightDeg`: Target window dimensions in degrees.
- `p.trVars.targWidth`, `p.trVars.targRadius`: Target dimensions in pixels.
- `p.trVars.stimConfigIdx`: Index for target/background color configuration.
- `p.trVars.currentState`: The current state of the state machine.
- `p.trVars.exitWhileLoop`: Boolean to exit the main trial loop.
- `p.trVars.targetIsOn`: Boolean indicating if the target is currently displayed.
- `p.trVars.postMemSacTargOn`: Boolean for target display after memory-guided saccade.
- `p.trVars.whileLoopIdx`: Index for the main while loop.
- `p.trVars.eyeVelFiltTaps`: Number of taps for the online eye velocity filter.
- `p.trVars.eyeVelThresh`: Threshold for online saccade detection.
- `p.trVars.useVelThresh`: Boolean to use the velocity threshold.
- `p.trVars.eyeVelThreshOffline`: Velocity threshold for offline analysis.
- `p.trVars.connectRipple`: Boolean to connect to Ripple.
- `p.trVars.rippleChanSelect`: Selected Ripple channel.
- `p.trVars.useOnlineSort`: Boolean to use online sorted spike times.
- `p.trVars.wantOnlinePlots`: Boolean to display online plots.
- `p.trVars.currentTrialsArrayRow`: The current row of `p.init.trialsArray`.

## `p.trData`

This structure stores the data collected during a single trial. It is re-initialized at the beginning of each trial.

- `p.trData.eyeX`, `p.trData.eyeY`, `p.trData.eyeP`, `p.trData.eyeT`: Raw eye position data.
- `p.trData.joyV`: Joystick voltage samples.
- `p.trData.dInValues`, `p.trData.dInTimes`: Digital input values and times.
- `p.trData.onlineGaze`: Online gaze position and velocity.
- `p.trData.strobed`: Strobed event codes and times.
- `p.trData.spikeTimes`: Spike times from Ripple.
- `p.trData.eventTimes`, `p.trData.eventValues`: Event times and values.
- `p.trData.preSacXY`, `p.trData.postSacXY`: Pre- and post-saccadic eye positions.
- `p.trData.peakVel`: Peak saccade velocity.
- `p.trData.SRT`: Saccadic reaction time.
- `p.trData.spikeClusters`: Spike cluster IDs.
- `p.trData.trialEndState`: The final state of the trial.
- `p.trData.trialRepeatFlag`: A flag to repeat the trial.
- `p.trData.timing`: A substructure containing timestamps for various trial events:
    - `p.trData.timing.lastFrameTime`: Time of the last frame flip.
    - `p.trData.timing.fixOn`: Time of fixation point onset.
    - `p.trData.timing.fixAq`: Time of fixation acquisition.
    - `p.trData.timing.fixOff`: Time of fixation point offset.
    - `p.trData.timing.targetOn`: Time of target onset.
    - `p.trData.timing.targetOff`: Time of target offset.
    - `p.trData.timing.targetReillum`: Time of target re-illumination.
    - `p.trData.timing.targetAq`: Time of target acquisition.
    - `p.trData.timing.saccadeOnset`: Time of saccade onset.
    - `p.trData.timing.saccadeOffset`: Time of saccade offset.
    - `p.trData.timing.brokeFix`: Time of fixation break.
    - `p.trData.timing.reward`: Time of reward delivery.
    - `p.trData.timing.tone`: Time of audio feedback.
    - `p.trData.timing.trialBegin`: Time of trial begin.
    - `p.trData.timing.trialStartPTB`: Trial start time (PTB clock).
    - `p.trData.timing.trialStartDP`: Trial start time (DataPixx clock).
    - `p.trData.timing.frameNow`: Current frame number.
    - `p.trData.timing.flipTime`: An array of frame flip times.
    - `p.trData.timing.joyPress`: Time of joystick press.
    - `p.trData.timing.joyRelease`: Time of joystick release.
