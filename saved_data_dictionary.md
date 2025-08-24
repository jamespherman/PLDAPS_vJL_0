# Saved Data Dictionary for 'joystick_release_for_stim_change_and_dim'

This document describes the data structures saved during the 'joystick_release_for_stim_change_and_dim' task, with a focus on the variant defined by the 'joystick_release_for_orient_change_and_dim_learn_cue_settings.m' settings file.

The data is saved in a main structure `p`. The entire `p` structure is saved once at the beginning of the session in a file named `p.mat`. For each trial, a separate file named `trialXXXX.mat` is saved, containing the `trVars`, `trData`, `status`, and `init` structures for that trial.

## The `p` Structure (Session-Level Data)

The `p` structure contains all the parameters and data for the experimental session. The fields described below are those that are saved once at the beginning of the session.

### `p.init`

This structure contains initialization parameters that are set once at the beginning of the session.

*   `p.init.pcName`: The hostname of the computer running the experiment.
*   `p.init.rigConfigFile`: The path to the rig configuration file, which contains subject- and rig-specific details.
*   `p.init.exptType`: A string identifying the specific experiment being run. For this task variant, it is 'joystick_release_for_stim_dim_and_orient_change_learn_cue_multi'. This string determines which trial structure table is used.
*   `p.init.taskName`: The name of the task, which is 'joystick_release_for_stim_change_and_dim'.
*   `p.init.taskType`: A numerical index for the task type (value is 1).
*   `p.init.pldapsFolder`: The path to the main PLDAPS directory.
*   `p.init.protocol_title`: The banner text to identify the experimental protocol.
*   `p.init.date`: The date of the session in 'yyyymmdd' format.
*   `p.init.time`: The time of the session in 'HHMM' format.
*   `p.init.date_1yyyy`, `p.init.date_1mmdd`, `p.init.time_1hhmm`: Numerical representations of the date and time, with a '1' prepended to avoid issues with leading zeros.
*   `p.init.useDataPixxBool`: A boolean indicating whether the DataPixx/ViewPixx is being used.
*   `p.init.outputFolder`: The folder where the output files are saved.
*   `p.init.figureFolder`: The folder where figures are saved.
*   `p.init.sessionId`: A unique identifier for the session, combining the date, time, and task name.
*   `p.init.sessionFolder`: The folder where the data for the current session is saved.
*   `p.init.taskFiles`: A structure containing the filenames for the init, next, run, and finish scripts for the task.
*   `p.init.taskActions`: A cell array of strings containing the names of action M-files to be used in the task.
*   `p.init.trDataInitList`: A cell array that defines the variables within `p.trData` and their initial values at the start of each trial.
*   `p.init.nTrDataListRows`: The number of rows in `p.init.trDataInitList`.
*   `p.init.strobeList`: A cell array of variable names to be strobed at the end of each trial.
*   `p.init.trialsArray`: A matrix that defines the parameters for each trial in a block. Each row represents a trial, and each column represents a parameter. The columns are defined in `p.init.trialArrayColumnNames`.
*   `p.init.trialArrayColumnNames`: A cell array of strings that are the names of the columns in `p.init.trialsArray`.
*   `p.init.trialsTable`: The table of trial conditions used to generate `p.init.trialsArray`.
*   `p.init.blockLength`: The number of trials in a block.
*   `p.init.codes`: A structure containing the numerical codes for various trial events that are strobed to the ephys recording system.
*   `p.init.strb`: An object of the `pds.classyStrobe` class, used for strobing values to the ephys system.

### `p.audio`

This structure contains parameters related to audio feedback.

*   `p.audio.audsplfq`: The audio playback sampling rate for the DataPixx (48000 Hz).
*   `p.audio.Hitfq`: The frequency of the "hit" tone (600 Hz).
*   `p.audio.Missfq`: The frequency of the "low" (miss) tone (100 Hz).
*   `p.audio.auddur`: The duration of the tones in samples (4800 samples).
*   `p.audio.lineOutLevel`: The audio level for the DataPixx line out (0 to 1).
*   `p.audio.pcPlayback`: A boolean indicating whether to use the PC for audio playback.

### `p.draw`

This structure contains parameters related to drawing visual elements on the screen.

*   `p.draw.ringThickDeg`: The thickness of the cue ring in degrees.
*   `p.draw.ringRadDeg`: The radius of the cue ring in degrees.
*   `p.draw.eyePosWidth`: The width of the eye position indicator in pixels.
*   `p.draw.fixPointWidth`: The line width of the fixation point in pixels.
*   `p.draw.fixPointRadius`: The radius of the fixation point in pixels.
*   `p.draw.fixWinPenPre`: The pen width for the fixation window before a change event.
*   `p.draw.fixWinPenPost`: The pen width for the fixation window after a change event.
*   `p.draw.fixWinPenDraw`: The current pen width for the fixation window, which is set to either `fixWinPenPre` or `fixWinPenPost` during the trial.
*   `p.draw.gridSpacing`: The spacing of the grid on the experimenter's display in degrees.
*   `p.draw.gridW`: The grid spacing in degrees.
*   `p.draw.joyRect`: The rectangle defining the position of the joystick indicator on the experimenter's display.
*   `p.draw.cursorW`: The width of the cursor in pixels.
*   `p.draw.clutIdx`: A structure containing integer indices for the Color Look-Up Table (CLUT). Each field name is a descriptive string for a color, and the value is the row index in the CLUT.
*   `p.draw.color`: A structure that holds the current CLUT index for various visual elements (e.g., `p.draw.color.background`, `p.draw.color.fix`). The values of these fields are updated during the trial to change the colors of the elements.
*   `p.draw.cueRingRect`: The rectangle defining the position and size of the cue ring in pixels.
*   `p.draw.ringThickPix`: The thickness of the cue ring in pixels.
*   `p.draw.myCLUTs`: The Color Look-Up Tables for each frame of the stimulus animation.
*   `p.draw.stimTex`: A cell array of textures for the stimuli.
*   `p.draw.middleXY`: The pixel coordinates of the center of the screen.
*   `p.draw.gridXY`: The coordinates for the grid lines on the experimenter display.
*   `p.draw.window`: The handle for the Psychtoolbox window.
*   `p.draw.cueArcAngles`: The start and end angles for the colored and grey portions of the cue arc.
*   `p.draw.cueArcProp`: The proportion of the cue arc that is colored, based on the probability of a change at the cued location.
*   `p.draw.fixPointPix`: The pixel coordinates of the fixation point.
*   `p.draw.fixPointRect`: The rectangle defining the fixation point.

### `p.state`

This structure defines the numerical codes for the different states of the trial state machine.

*   `p.state.trialBegun`: 1
*   `p.state.waitForJoy`: 2
*   `p.state.showFix`: 3
*   `p.state.dontMove`: 4
*   `p.state.makeDecision`: 5
*   `p.state.fixBreak`: 11
*   `p.state.joyBreak`: 12
*   `p.state.nonStart`: 13
*   `p.state.hit`: 21
*   `p.state.cr`: 22
*   `p.state.miss`: 23
*   `p.state.foilFa`: 24
*   `p.state.fa`: 25

### `p.status`

This structure contains variables that track the status of the experiment across trials. It is updated at the end of each trial.

*   `p.status.iTrial`: The current trial number.
*   `p.status.iGoodTrial`: The number of "good" trials (hits, misses, correct rejects, foil FAs).
*   `p.status.trialsLeftInBlock`: The number of trials remaining in the current block.
*   `p.status.blockNumber`: The current block number.
*   `p.status.fixDurReq`: The required fixation duration for the last trial.
*   `p.status.hr1stim`, `p.status.hr2stim`, `p.status.hr3stim`, `p.status.hr4stim`: Hit rates for trials with 1, 2, 3, and 4 stimuli, respectively.
*   `p.status.hc1stim`, `p.status.hc2stim`, `p.status.hc3stim`, `p.status.hc4stim`: Hit counts for trials with 1, 2, 3, and 4 stimuli, respectively.
*   `p.status.tc1stim`, `p.status.tc2stim`, `p.status.tc3stim`, `p.status.tc4stim`: Total trial counts for trials with 1, 2, 3, and 4 stimuli, respectively.
*   `p.status.hr1Loc1`, `p.status.cr1Loc1`, `p.status.hr1Loc2`, `p.status.cr1Loc2`, etc.: Hit rates and correct reject rates for different stimulus configurations.
*   `p.status.hc1Loc1`, `p.status.crc1Loc1`, `p.status.hc1Loc2`, `p.status.crc1Loc2`, etc.: Hit counts and correct reject counts for different stimulus configurations.
*   `p.status.cue1CtLoc1`, `p.status.foil1CtLoc1`, `p.status.cue1CtLoc2`, `p.status.foil1CtLoc2`, etc.: Counts of cue and foil change trials for different stimulus configurations.
*   `p.status.totalHits`: Total number of hits.
*   `p.status.totalMisses`: Total number of misses.
*   `p.status.totalChangeFalseAlarms`: Total number of false alarms on change trials.
*   `p.status.totalNoChangeFalseAlarms`: Total number of false alarms on no-change trials.
*   `p.status.totalCorrectRejects`: Total number of correct rejects.
*   `p.status.missedFrames`: The number of missed frames reported by Psychtoolbox.
*   `p.status.freeRwdRand`: The random number drawn to determine if a free reward should be given.
*   `p.status.freeRwdTotal`: The total number of free rewards delivered.
*   `p.status.freeRwdLast`: The trial number of the last free reward.
*   `p.status.trialsArrayRowsPossible`: A logical vector indicating which rows of the `trialsArray` are still available to be run in the current block.
*   `p.status.freeRewardsAvailable`: A logical vector indicating which trials in the block are designated to have a free reward.
*   `p.status.trialEndStates`: A vector containing the end state of each trial.
*   `p.status.reactionTimes`: A vector of reaction times for each trial.
*   `p.status.dimVals`: A vector of dimming values for each trial.
*   `p.status.changeDelta`: The magnitude of the stimulus change in the current trial.
*   `p.status.chgLoc`: The location of the stimulus change.
*   `p.status.cueLoc`: The location of the cue.
*   `p.status.nStim`: The number of stimuli on the current trial.

### `p.trVarsInit` and `p.trVarsGuiComm`

These structures are initialized in the settings file and contain the default values for the trial variables. `p.trVarsGuiComm` can be updated by the user through the GUI, and its values are copied to `p.trVars` at the beginning of each trial. Only fields that are not found in `p.trVars` will be documented here. As it turns out, all fields in `p.trVarsInit` and `p.trVarsGuiComm` are also fields in `p.trVars`, so there is no need to document them separately here.

### `p.trVars`

This structure contains the parameters for the current trial. Its values are set at the beginning of each trial in `_next.m`, primarily by copying from `p.trVarsGuiComm` and then being modified by `nextParams.m`.

*   `p.trVars.passJoy`: If set to 1, simulates a correct joystick response. Used for debugging.
*   `p.trVars.passEye`: If set to 1, simulates correct eye fixation. Used for debugging.
*   `p.trVars.blockNumber`: The current block number.
*   `p.trVars.repeat`: If true, the trial will be repeated.
*   `p.trVars.rwdJoyPR`: Determines reward condition (0 for joystick press, 1 for joystick release).
*   `p.trVars.isCueChangeTrial`: Boolean indicating if the trial is a cue change trial.
*   `p.trVars.isFoilChangeTrial`: Indicates if this is a foil change trial (1), no change (0), or if a foil is not present (-1).
*   `p.trVars.isNoChangeTrial`: Boolean indicating if the trial is a no-change trial. Set in `nextParams.m`.
*   `p.trVars.finish`: The maximum number of trials to run.
*   `p.trVars.filesufix`: A suffix for the saved file.
*   `p.trVars.joyVolt`: The current joystick voltage.
*   `p.trVars.eyeDegX`, `p.trVars.eyeDegY`: The current eye position in degrees.
*   `p.trVars.eyePixX`, `p.trVars.eyePixY`: The current eye position in pixels.
*   `p.trVars.propHueChgOnly`: The proportion of change trials where only the hue of the peripheral stimulus changes (no dimming).
*   `p.trVars.isStimChangeTrial`: Boolean, true if it is a stimulus change trial. Set in `nextParams.m`.
*   `p.trVars.chgAndDimOnMultiOnly`: Boolean, if true, change+dim trials only occur on multi-stimulus trials.
*   `p.trVars.stimLoc1Elev`, `p.trVars.stimLoc1Ecc`: The elevation and eccentricity of the first stimulus location.
*   `p.trVars.stimLoc2Elev`, `p.trVars.stimLoc2Ecc`, etc.: The elevation and eccentricity for the other stimulus locations. Can be used to override the default circular arrangement.
*   `p.trVars.fixDegX`, `p.trVars.fixDegY`: The X and Y coordinates of the fixation point in degrees.
*   `p.trVars.fixLocRandX`, `p.trVars.fixLocRandY`: The range of random jitter for the fixation point location.
*   `p.trVars.lowDimVal`, `p.trVars.midDimVal`, `p.trVars.highDimVal`: The brightness levels for the fixation point after dimming, relative to the background.
*   `p.trVars.speedInit`, `p.trVars.ctrstInit`, `p.trVars.orientInit`, `p.trVars.freqInit`, `p.trVars.satInit`, `p.trVars.lumInit`, `p.trVars.hueInit`: Initial values for the various stimulus features.
*   `p.trVars.orientVar`, `p.trVars.hueVar`, `p.trVars.lumVar`, `p.trVars.satVar`: The variance for stimulus features that can be varied.
*   `p.trVars.speedDelta`, `p.trVars.contDelta`, `p.trVars.orientDelta`, `p.trVars.freqDelta`, `p.trVars.satDelta`, `p.trVars.lumDelta`, `p.trVars.hueDelta`: The magnitude of the change for each stimulus feature on change trials.
*   `p.trVars.stimRadius`: The radius of the stimulus aperture in degrees.
*   `p.trVars.boxSizePix`: The size of the "checks" in the checkerboard stimulus in pixels.
*   `p.trVars.boxLifetime`: The lifetime of the "checks" in frames.
*   `p.trVars.nPatches`: The number of stimulus patches.
*   `p.trVars.nEpochs`: The number of stimulus epochs (pre-change and post-change).
*   `p.trVars.rewardDurationMs`: The duration of the reward in milliseconds.
*   `p.trVars.rewardDurationMsSmall`: The duration of a small reward in milliseconds.
*   `p.trVars.fix2CueIntvlMin`, `p.trVars.fix2CueIntvlWin`: The minimum and window duration for the interval between fixation and cue onset.
*   `p.trVars.fix2CueIntvl`: The actual interval between fixation and cue onset for the current trial, randomly drawn from the min/win range.
*   `p.trVars.cueDur`: The duration of the cue presentation.
*   `p.trVars.cue2StimIntvlMin`, `p.trVars.cue2StimIntvlWin`: The minimum and window duration for the interval between cue offset and stimulus onset.
*   `p.trVars.cue2StimIntvl`: The actual interval between cue offset and stimulus onset for the current trial.
*   `p.trVars.stim2ChgIntvl`: The minimum time between stimulus onset and change.
*   `p.trVars.chgWinDur`: The time window during which a change can occur.
*   `p.trVars.rewardDelay`: The delay between a correct response (hit) and reward delivery.
*   `p.trVars.joyMinLatency`, `p.trVars.joyMaxLatency`: The minimum and maximum acceptable joystick release latency.
*   `p.trVars.timeoutAfterFa`, `p.trVars.timeoutAfterFoilFa`, `p.trVars.timeoutAfterMiss`, `p.trVars.timeoutAfterFixBreak`: The timeout durations for different trial outcomes.
*   `p.trVars.joyWaitDur`: The maximum time to wait for a joystick press at the start of a trial.
*   `p.trVars.fixWaitDur`: The maximum time to wait for fixation acquisition.
*   `p.trVars.freeDur`: The time before the start of the joystick press check.
*   `p.trVars.trialMax`: The maximum duration of a trial.
*   `p.trVars.joyReleaseWaitDur`: The time to wait after trial end to start the end-of-trial flicker if the joystick is not released.
*   `p.trVars.stimFrameIdx`: The current frame index for the stimulus animation.
*   `p.trVars.flipIdx`: The index of the current screen flip.
*   `p.trVars.postRewardDurMin`, `p.trVars.postRewardDurMax`: The minimum and maximum duration to wait after reward delivery before ending the trial.
*   `p.trVars.useQuest`: Boolean, if true, QUEST is used to determine stimulus parameters.
*   `p.trVars.numTrialsForPerfCalc`: The number of recent trials to use for performance calculation.
*   `p.trVars.freeRewardProbability`: The probability of a free reward between trials.
*   `p.trVars.freeRewardFlag`: A boolean to enable or disable free rewards.
*   `p.trVars.connectRipple`: Boolean, if true, connect to the Ripple system.
*   `p.trVars.rippleChanSelect`: The selected Ripple channel.
*   `p.trVars.useOnlineSort`: Boolean, if true, use online sorted spike times from Trellis.
*   `p.trVars.psthBinWidth`, `p.trVars.fixOnPsthMinTime`, etc.: Parameters for PSTH plotting.
*   `p.trVars.currentState`: The current state of the trial state machine.
*   `p.trVars.exitWhileLoop`: A boolean that controls the main trial loop.
*   `p.trVars.cueIsOn`: A boolean indicating if the cue is currently displayed.
*   `p.trVars.stimIsOn`: A boolean indicating if the stimuli are currently displayed.
*   `p.trVars.fixWinWidthDeg`, `p.trVars.fixWinHeightDeg`: The width and height of the fixation window in degrees.
*   `p.trVars.fixPointRadPix`, `p.trVars.fixPointLinePix`: The radius and line width of the fixation point in pixels.
*   `p.trVars.useCellsForDraw`: A boolean for drawing options.
*   `p.trVars.wantEndFlicker`: A boolean to enable the end-of-trial screen flicker.
*   `p.trVars.wantOnlinePlots`: A boolean to enable online plotting.
*   `p.trVars.fixColorIndex`: The color index for the fixation point.
*   `p.trVars.postFlip`: A structure used to log the timing of events that occur immediately after a screen flip.
*   `p.trVars.optoStimDurSec`, `p.trVars.optoPulseDurSec`, `p.trVars.otoPulseAmpVolts`, `p.trVars.optoIpiSec`, `p.trVars.isOptoStimTrial`: Parameters for optogenetic stimulation.
*   `p.trVars.currentTrialsArrayRow`: The row index of `p.init.trialsArray` for the current trial.
*   `p.trVars.stimSeed`, `p.trVars.trialSeed`: Random seeds for the stimulus and trial parameters.
*   `p.trVars.isStimChgNoDim`: Boolean, true if it is a stimulus change trial with no dimming.
*   `p.trVars.stim1On`, `p.trVars.stim2On`, etc.: Booleans indicating which stimuli are on for the current trial.
*   `p.trVars.stimOnList`: A numerical list of the stimuli that are on.
*   `p.trVars.isContrastChangeTrial`: Boolean, true if it is a contrast change trial.
*   `p.trVars.stimElevs`, `p.trVars.stimEccs`: Vectors of elevations and eccentricities for all stimulus locations.
*   `p.trVars.stimLocCart`, `p.trVars.stimLocCartPix`: The Cartesian coordinates of the stimulus locations in degrees and pixels.
*   `p.trVars.stimRects`: The rectangles defining the stimulus patches.
*   `p.trVars.fix2StimOnIntvl`: The interval between fixation acquisition and stimulus onset.
*   `p.trVars.stimChangeTime`: The time of the stimulus change (or pseudo-change) relative to fixation acquisition.
*   `p.trVars.joyMaxLatencyAfterChange`: The latest acceptable joystick release time after a change.
*   `p.trVars.hitRwdTime`, `p.trVars.corrRejRwdTime`: The time of reward delivery for hits and correct rejects.
*   `p.trVars.fix2StimOffIntvl`: The interval between fixation acquisition and stimulus offset.
*   `p.trVars.stimDur`: The maximum possible stimulus duration.
*   `p.trVars.stimFrames`: The total number of frames for the stimulus animation.
*   `p.trVars.rewardScheduleDur`: The duration of the reward schedule.
*   `p.trVars.postRewardDuration`: The duration to wait after reward delivery before ending the trial.

### `p.trData`

This structure contains the data collected during the current trial. It is initialized at the beginning of each trial by `initTrData.m` based on the `p.init.trDataInitList` from the settings file.

*   `p.trData.eyeX`, `p.trData.eyeY`, `p.trData.eyeP`, `p.trData.eyeT`: These fields are intended to store eye data, but in the current implementation, they are not populated. Eye data is stored in `p.trData.onlineEyeX` and `p.trData.onlineEyeY`.
*   `p.trData.joyV`: Stores the joystick voltage values. Not currently populated in the provided code.
*   `p.trData.dInValues`, `p.trData.dInTimes`: Store the values and times of digital input events. Not currently populated in the provided code.
*   `p.trData.spikeTimes`: Stores the timestamps of spikes from the ephys system.
*   `p.trData.eventTimes`, `p.trData.eventValues`: Store the times and values of strobed events.
*   `p.trData.onlineEyeX`, `p.trData.onlineEyeY`: Store the X and Y eye position in degrees, sampled on every frame of the trial.
*   `p.trData.spikeClusters`: Stores the cluster ID for each spike.
*   `p.trData.timing`: A sub-structure containing the timestamps of various trial events, relative to the start of the trial.
    *   `p.trData.timing.trialStartPTB`: The trial start time, according to Psychtoolbox's `GetSecs`.
    *   `p.trData.timing.trialStartDP`: The trial start time, according to the DataPixx.
    *   `p.trData.timing.trialBegin`: The time the trial began (state 1).
    *   `p.trData.timing.joyPress`: The time the joystick was pressed.
    *   `p.trData.timing.fixOn`: The time the fixation point appeared.
    *   `p.trData.timing.fixAq`: The time fixation was acquired.
    *   `p.trData.timing.stimOn`: The time the stimuli appeared.
    *   `p.trData.timing.stimOff`: The time the stimuli disappeared.
    *   `p.trData.timing.cueOn`: The time the cue appeared.
    *   `p.trData.timing.cueOff`: The time the cue disappeared.
    *   `p.trData.timing.stimChg`: The time of the stimulus change.
    *   `p.trData.timing.noChg`: The time of the pseudo-change on a no-change trial.
    *   `p.trData.timing.brokeFix`: The time of a fixation break.
    *   `p.trData.timing.brokeJoy`: The time of a joystick break.
    *   `p.trData.timing.reward`: The time of reward delivery.
    *   `p.trData.timing.tone`: The time of audio feedback.
    *   `p.trData.timing.joyRelease`: The time the joystick was released.
    *   `p.trData.timing.reactionTime`: The reaction time, calculated as `joyRelease` - `stimChangeTime`.
    *   `p.trData.timing.fixHoldReqMet`: The time the required fixation duration was met.
    *   `p.trData.timing.freeReward`: The time a free reward was delivered.
    *   `p.trData.timing.flipTime`: A vector of timestamps for each screen flip.
    *   `p.trData.timing.lastFrameTime`: The time of the last screen flip.
    *   `p.trData.timing.optoStim`: The time of optogenetic stimulation onset.
    *   `p.trData.timing.optoStimSham`: The time of sham optogenetic stimulation.
*   `p.trData.trialEndState`: The numerical code of the state in which the trial ended.
*   `p.trData.dimVal`: Set to 1 for change trials and 0 for no-change trials. This is a legacy variable and may not be used in analysis.

### `p.stim`

This structure contains parameters and data related to the stimuli. It is populated in `nextParams.m` and `generateStimuli.m`.

*   `p.stim.featureValueNames`: A cell array of strings with the names of the stimulus features that can be varied.
*   `p.stim.nFeatures`: The number of features in `p.stim.featureValueNames`.
*   `p.stim.stimChgIdx`: The index of the stimulus that changes on the current trial.
*   `p.stim.cueLoc`: The index of the cued stimulus location.
*   `p.stim.nStim`: The number of stimuli presented on the current trial.
*   `p.stim.primStim`: The index of the "primary" stimulus, used to ensure that stimuli have different starting values for their features.
*   `p.stim.speedArray`, `p.stim.ctrstArray`, `p.stim.orientArray`, `p.stim.freqArray`, `p.stim.satArray`, `p.stim.lumArray`, `p.stim.hueArray`: These are arrays that define the values of the stimulus features for each stimulus patch (rows) and each epoch (columns). The values are determined by the initial values in `p.trVars`, the deltas for the current trial, and the `trialsArray`.
*   `p.stim.orientVarArray`, `p.stim.hueVarArray`, `p.stim.lumVarArray`, `p.stim.satVarArray`: Arrays defining the variance for the corresponding stimulus features.
*   `p.stim.patchDiamPix`: The diameter of the stimulus patch in pixels.
*   `p.stim.patchDiamBox`: The diameter of the stimulus patch in "boxes" or "checks".
*   `p.stim.epochFrames`: A vector containing the number of frames in each epoch.
*   `p.stim.chgFrames`: A cumulative sum of the epoch durations in frames, used to determine when changes occur.
*   `p.stim.funs`: A structure containing anonymous functions for various calculations.
*   `p.stim.X`, `p.stim.Y`: 3D arrays containing the X and Y indices for each box in each frame of the stimulus animation.
*   `p.stim.nBoxTot`: The total number of boxes across all patches.
*   `p.stim.uci`: A 3D array containing a unique numerical index for each unique color value needed for the stimulus animation.
*   `p.stim.upi`: A 3D array containing the unique phase index for the gabor phase values.
*   `p.stim.ucir`: A reshaped version of `p.stim.uci`.
*   `p.stim.tempR`, `p.stim.tempG`, `p.stim.tempB`: Temporary vectors used to store the RGB color values for the stimuli.
*   `p.stim.colorRowSelector`: A logical vector used to select the correct color values from the temporary color vectors.
*   `p.stim.stimArray`: A cell array where each cell contains the image matrix for a stimulus patch.
