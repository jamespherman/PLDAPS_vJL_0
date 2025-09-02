# Data Dictionary for '4factors' Task

This document provides a comprehensive explanation of the fields and subfields of the data structures saved during the '4factors' task. The 'p' structure is saved once at the beginning of a session, while a structure containing `p.trVars` and `p.trData` is saved for each trial.

## `p` Structure

The `p` structure contains all the parameters and settings for the experiment. It is initialized at the beginning of the experiment and saved once per session.

### `p.init`

This substructure contains initialization parameters for the task.

| Field | Description |
|---|---|
| `pcName` | The name of the computer running the experiment. |
| `rigConfigFile` | The path to the rig configuration file. |
| `taskName` | The name of the task (e.g., 'gSac_4factors'). |
| `pldapsFolder` | The root folder of the PLDAPS installation. |
| `protocol_title` | The title of the experimental protocol. |
| `date` | The date the experiment was run (yyyymmdd). |
| `time` | The time the experiment was run (HHMM). |
| `outputFolder` | The folder where output files are saved. |
| `sessionId` | A unique identifier for the session. |
| `sessionFolder` | The folder for the current session's data. |
| `taskFiles` | A structure containing the names of the init, next, run, and finish files for the task. |
| `useDataPixxBool` | A boolean indicating whether to use the DataPixx/ViewPixx. |
| `taskActions` | A cell array of strings with the names of action M-files. |
| `exptType` | A string indicating which version of the experiment is running. |
| `trDataInitList` | A cell array that lists the trial data variables (`p.trData`) and their initial values. |
| `nTrDataListRows` | The number of rows in `p.init.trDataInitList`. |
| `strobeList` | A cell array defining the variables to be strobed at the end of each trial. |
| `trialsArray` | An array that defines the parameters for each trial in the experiment. The columns are defined by `p.init.trialArrayColumnNames`. |
| `trialArrayColumnNames` | A cell array of strings that are the column headers for `p.init.trialsArray`. These include: `halfBlock`, `targetLocIdx`, `stimType` (1: Face, 2: Non-Face, 3: HS/TC1, 4: LS/TC1, 5: HS/TC2, 6: LS/TC2), `salience` (0 for images, 1 for high, 2 for low), `reward` (1 for high, 2 for low), `targetColor` (0 for images, 1 or 2 for bullseye), `numTrials`, `trialCode`, `completed`. |

### `p.rig`

This substructure contains parameters related to the experimental rig.

| Field | Description |
|---|---|
| `screen_number` | The screen number for the display. |
| `refreshRate` | The refresh rate of the display in Hz. |
| `frameDuration` | The duration of a single frame in seconds. |
| `joyThreshPress` | The voltage threshold for a joystick press. |
| `joyThreshRelease` | The voltage threshold for a joystick release. |
| `magicNumber` | A small time adjustment for screen flips. |
| `joyVoltageMax` | The maximum voltage of the joystick. |
| `guiStatVals` | A cell array of status variable names to be displayed in the GUI. |
| `guiVars` | A cell array of trial variable names to be displayed in theGUI. |

### `p.audio`

This substructure contains parameters for auditory feedback.

| Field | Description |
|---|---|
| `audsplfq` | The sampling frequency for audio. |
| `Hitfq` | The frequency of the tone for a correct trial. |
| `Missfq` | The frequency of the tone for an incorrect trial. |
| `auddur` | The duration of the audio tone. |

### `p.draw`

This substructure contains parameters related to drawing visual stimuli.

| Field | Description |
|---|---|
| `clutIdx` | A structure that defines the indices for the Color Look-Up Table (CLUT). |
| `color` | A structure that defines the colors for various task elements, using the indices from `p.draw.clutIdx`. |
| `fixPointWidth` | The width of the fixation point in pixels. |
| `fixPointRadius` | The radius of the fixation point in pixels. |
| `fixWinPenThin`, `fixWinPenThick`, `fixWinPenDraw` | Pen widths for the fixation window. |
| `targWinPenThin`, `targWinPenThick`, `targWinPenDraw` | Pen widths for the target window. |
| `eyePosWidth` | The width of the eye position indicator in pixels. |
| `gridSpacing` | The spacing of the grid on the experimenter's display in degrees. |
| `gridW` | The width of the grid lines. |
| `joyRect` | The position of the joystick indicator rectangle on the experimenter's display. |
| `cursorW` | The width of the cursor in pixels. |
| `middleXY` | The pixel coordinates of the center of the screen. |
| `window` | The handle for the PTB window. |

### `p.state`

This substructure defines the different states of the trial state machine.

| Field | Description |
|---|---|
| `trialBegun` | State for the beginning of the trial. |
| `waitForJoy` | State for waiting for the joystick to be pressed. |
| `showFix` | State for showing the fixation point. |
| `dontMove` | State for maintaining fixation. |
| `makeSaccade` | State for initiating a saccade. |
| `checkLanding` | State for checking the saccade landing position. |
| `holdTarg` | State for holding fixation on the target. |
| `sacComplete` | State for a successful saccade. |
| `fixBreak` | End state for a fixation break. |
| `joyBreak` | End state for a joystick release error. |
| `nonStart` | End state for failing to start the trial. |
| `failedToHoldTarg` | End state for failing to hold the target. |

### `p.status`

This substructure contains status variables that are updated throughout the experiment.

| Field | Description |
|---|---|
| `iTrial` | The current trial number. |
| `iGoodTrial` | The number of good trials. |
| `iGoodVis`, `iGoodMem` | The number of good visual and memory guided trials. |
| `pGoodVis`, `pGoodMem` | The proportion of good visual and memory guided trials. |
| `iTarget` | The index of the current target. |
| `rippleOnline` | A flag indicating if Ripple is online. |
| `tLoc1HighRwdFirst` | A flag for reward location. |
| `trialsArrayRowsPossible` | A logical array indicating which trials from `p.init.trialsArray` are available to be run. |

### `p.stim`

This substructure contains parameters for the visual stimuli.

| Field | Description |
|---|---|
| `targLocationPreset` | The method for generating target locations ('grid', 'ring', 'nRing'). |
| `dotWidth` | The width of the target dot in pixels. |
| `stimDiamDeg` | The diameter of the stimulus images in degrees. |
| `nStimLevels` | The number of intensity levels for the stimuli. |
| `gridMinX`, `gridMaxX`, `gridBinSizeX` | Parameters for the 'grid' preset. |
| `gridMinY`, `gridMaxY`, `gridBinSizeY` | Parameters for the 'grid' preset. |
| `ringRadius`, `ringTargNumber`, `ringBaseAngle` | Parameters for the 'ring' and 'nRing' presets. |

## `p.trVars`

This structure contains variables that can change on a trial-by-trial basis. The values in `p.trVars` are inherited from `p.trVarsInit` at the start of each trial and can be modified by the GUI via `p.trVarsGuiComm`.

| Field | Description |
|---|---|
| `passJoy`, `passEye` | Booleans to simulate correct joystick or eye movements for debugging. |
| `connectPLX` | Boolean to connect to Plexon. |
| `joyPressVoltDirection` | Direction of voltage change on joystick press. |
| `blockNumber` | The current block number. |
| `repeat` | Boolean to repeat the current trial. |
| `rwdJoyPR` | Boolean to determine if reward is given for press or release. |
| `wantEndFlicker` | Boolean for screen flicker at trial end. |
| `finish` | The number of trials to run. |
| `filesufix` | Suffix for saved files. |
| `joyVolt` | The current joystick voltage. |
| `eyeDegX`, `eyeDegY` | Eye position in degrees. |
| `eyePixX`, `eyePixY` | Eye position in pixels. |
| `mouseEyeSim` | Boolean to simulate eye position with the mouse. |
| `setTargLocViaMouse`, `setTargLocViaGui`, `setTargLocViaTrialArray` | Booleans to determine how target location is set. |
| `propVis` | Proportion of visually-guided saccade trials. |
| `fixDegX`, `fixDegY` | Fixation point location in degrees. |
| `targDegX`, `targDegY`, `targDegX_base`, `targDegY_base` | Target location in degrees. |
| `rewardDurationHigh`, `rewardDurationLow`, `rewardDurationMs` | Reward durations in milliseconds. |
| `rwdSize` | The reward size for the current trial (1=high, 2=low). |
| `rewardDelay` | Delay before reward delivery. |
| `timeoutAfterFa` | Duration of timeout after a false alarm. |
| `joyWaitDur` | Time to wait for joystick press. |
| `fixWaitDur` | Time to wait for fixation acquisition. |
| `freeDur` | Duration of free time at the start of a trial. |
| `trialMax` | Maximum trial length. |
| `joyReleaseWaitDur` | Time to wait for joystick release at the end of a trial. |
| `stimFrameIdx`, `flipIdx` | Frame indices. |
| `postRewardDuration` | Duration of the trial after reward. |
| `joyPressVoltDir` | Direction of voltage change for joystick press. |
| `targetFlashDuration` | Duration of target flash in memory-guided trials. |
| `targHoldDurationMin`, `targHoldDurationMax` | Min and max duration to hold target. |
| `maxSacDurationToAccept` | Maximum duration of a saccade. |
| `goLatencyMin`, `goLatencyMax` | Min and max saccade latency. |
| `targOnsetMin`, `targOnsetMax` | Min and max time to target onset. |
| `goTimePostTargMin`, `goTimePostTargMax` | Min and max time from target onset to go signal. |
| `maxFixWait` | Maximum time to wait for fixation. |
| `targOnSacOnly` | Boolean to make target reappear on saccade. |
| `rwdTime` | Time of reward. |
| `targTrainingDelay` | Delay for target onset in training. |
| `timeoutdur` | Duration of timeout after an error. |
| `minTargAmp`, `maxTargAmp`, `staticTargAmp`, `maxHorzTargAmp`, `maxVertTargAmp` | Target amplitude parameters. |
| `fixWinWidthDeg`, `fixWinHeightDeg` | Fixation window dimensions in degrees. |
| `targWinWidthDeg`, `targWinHeightDeg` | Target window dimensions in degrees. |
| `targWidth`, `targRadius` | Target dimensions in pixels. |
| `stimConfigIdx` | Index for target/background color configuration. |
| `currentState` | The current state of the state machine. |
| `exitWhileLoop` | Boolean to exit the main trial loop. |
| `targetIsOn` | Boolean indicating if the target is currently displayed. |
| `postMemSacTargOn` | Boolean for target display after memory-guided saccade. |
| `whileLoopIdx` | Index for the main while loop. |
| `eyeVelFiltTaps` | Number of taps for the online eye velocity filter. |
| `eyeVelThresh` | Threshold for online saccade detection. |
| `useVelThresh` | Boolean to use the velocity threshold. |
| `eyeVelThreshOffline` | Velocity threshold for offline analysis. |
| `connectRipple` | Boolean to connect to Ripple. |
| `rippleChanSelect` | Selected Ripple channel. |
| `useOnlineSort` | Boolean to use online sorted spike times. |
| `wantOnlinePlots` | Boolean to display online plots. |
| `currentTrialsArrayRow` | The current row of `p.init.trialsArray`. |

## `p.trData`

This structure stores the data collected during a single trial. It is re-initialized at the beginning of each trial.

| Field | Description |
|---|---|
| `eyeX`, `eyeY`, `eyeP`, `eyeT` | Raw eye position data. |
| `joyV` | Joystick voltage samples. |
| `dInValues`, `dInTimes` | Digital input values and times. |
| `onlineGaze` | Online gaze position and velocity. |
| `strobed` | Strobed event codes and times. |
| `spikeTimes` | Spike times from Ripple. |
| `eventTimes`, `eventValues` | Event times and values. |
| `preSacXY`, `postSacXY` | Pre- and post-saccadic eye positions. |
| `peakVel` | Peak saccade velocity. |
| `SRT` | Saccadic reaction time. |
| `spikeClusters` | Spike cluster IDs. |
| `trialEndState` | The final state of the trial. |
| `trialRepeatFlag` | A flag to repeat the trial. |
| `timing` | A substructure containing timestamps for various trial events. |
| `timing.lastFrameTime` | Time of the last frame flip. |
| `timing.fixOn` | Time of fixation point onset. |
| `timing.fixAq` | Time of fixation acquisition. |
| `timing.fixOff` | Time of fixation point offset. |
| `timing.targetOn` | Time of target onset. |
| `timing.targetOff` | Time of target offset. |
| `timing.targetReillum` | Time of target re-illumination. |
| `timing.targetAq` | Time of target acquisition. |
| `timing.saccadeOnset` | Time of saccade onset. |
| `timing.saccadeOffset` | Time of saccade offset. |
| `timing.brokeFix` | Time of fixation break. |
| `timing.reward` | Time of reward delivery. |
| `timing.tone` | Time of audio feedback. |
| `timing.trialBegin` | Time of trial begin. |
| `timing.trialStartPTB` | Trial start time (PTB clock). |
| `timing.trialStartDP` | Trial start time (DataPixx clock). |
| `timing.frameNow` | Current frame number. |
| `timing.flipTime` | An array of frame flip times. |
| `timing.joyPress` | Time of joystick press. |
| `timing.joyRelease` | Time of joystick release. |
