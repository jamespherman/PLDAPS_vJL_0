# Data Dictionary for 'tokens' Task

This document provides a comprehensive explanation of the fields and subfields of the data structures saved on each trial of the 'tokens' task. The primary data structure is `p`, which is saved once per session. This document will detail all sub-structures within `p`.

## `p.init`

This structure contains initialization parameters that are set only once at the very beginning of an experimental session.

- **`p.init.pcName`**: The hostname of the computer running the experiment. Used to select the correct rig configuration file.
- **`p.init.rigConfigFile`**: The path to the rig-specific configuration file (e.g., `rigConfig_rig1.m`). This file contains hardware details like screen distance.
- **`p.init.useDataPixxBool`**: A boolean flag that should always be `true`, indicating that the DataPixx I/O box is in use.
- **`p.init.taskName`**: A string identifying the name of the task, which is `'tokens'`.
- **`p.init.taskType`**: A numerical index for the task type (value is `1`). The documentation notes this is "poorly defined".
- **`p.init.pldapsFolder`**: The root directory of the PLDAPS-based task.
- **`p.init.protocol_title`**: A string used for the banner text in the GUI to identify the protocol (e.g., `'tokens_task'`).
- **`p.init.date`**: The date the session was started, in `'yyyymmdd'` format.
- **`p.init.time`**: The time the session was started, in `'HHMM'` format.
- **`p.init.date_1yyyy`**: The year of the session, prepended with a '1' to avoid issues with leading zeros when converting to a double.
- **`p.init.date_1mmdd`**: The month and day of the session, prepended with a '1'.
- **`p.init.time_1hhmm`**: The hour and minute of the session, prepended with a '1'.
- **`p.init.outputFolder`**: The path to the main output directory where session data is saved.
- **`p.init.figureFolder`**: The path to the directory where figures generated during the session are saved.
- **`p.init.sessionId`**: A unique identifier for the session, combining the date, time, and task name (e.g., `'20230525_t1430_tokens'`).
- **`p.init.sessionFolder`**: The full path to the directory for the current session's data.
- **`p.init.taskFiles`**: A structure containing the filenames for the core task functions:
    - **`p.init.taskFiles.init`**: The initialization script (e.g., `'tokens_init.m'`).
    - **`p.init.taskFiles.next`**: The script that runs before each trial (e.g., `'tokens_next.m'`).
    - **`p.init.taskFiles.run`**: The script that runs each trial (e.g., `'tokens_run.m'`).
    - **`p.init.taskFiles.finish`**: The script that runs after each trial (e.g., `'tokens_finish.m'`).
- **`p.init.taskActions`**: A cell array of strings listing user-defined "action" M-files that can be called from the GUI.
- **`p.init.trialsPerCondition`**: The number of times each unique trial condition is repeated within a block.
- **`p.init.exptType`**: A string indicating the specific version of the experiment being run (e.g., `'tokens_AV'`).
- **`p.init.trDataInitList`**: A cell array that defines the initial values for variables within `p.trData`. This is used to reset trial-specific data at the beginning of each new trial.
- **`p.init.nTrDataListRows`**: The number of rows in `p.init.trDataInitList`, stored for efficient looping.
- **`p.init.strobeList`**: A cell array defining a list of variables whose values are to be strobed (sent as event markers to the ephys system) at the end of each trial. Each row contains the variable to be strobed and a human-readable name for it.

## `p.rig`

This structure contains parameters related to the specific hardware configuration of the experimental rig.

- **`p.rig.guiStatVals`**: A cell array of strings listing status variables (`p.status`) to be displayed in the GUI.
- **`p.rig.guiVars`**: A cell array of strings listing trial variables (`p.trVarsInit`) that can be modified from the GUI.
- **`p.rig.dp`**: A sub-structure containing settings for the DataPixx.
    - **`p.rig.dp.useDataPixxBool`**: A boolean indicating if the DataPixx is being used.
    - **`p.rig.dp.adcRate`**: The sampling rate for the Analog-to-Digital Converter (ADC) in Hz (e.g., 1000).
    - **`p.rig.dp.maxDurADC`**: The maximum duration in seconds to pre-allocate for the ADC buffer (e.g., 15).
    - **`p.rig.dp.adcBuffAddr`**: The memory buffer address for the ADC on the DataPixx.
    - **`p.rig.dp.dacRate`**: The sampling rate for the Digital-to-Analog Converter (DAC) in Hz (e.g., 1000).
    - **`p.rig.dp.dacPadDur`**: A padding duration in seconds for the DAC signal.
    - **`p.rig.dp.dacBuffAddr`**: The memory buffer base address for the DAC on the DataPixx.
    - **`p.rig.dp.dacChannelOut`**: The DAC output channel used for controlling the reward system.

## `p.audio`

This structure contains all parameters related to auditory stimuli and feedback.

- **`p.audio.audsplfq`**: The audio playback sampling rate in Hz for the DataPixx (e.g., 48000).
- **`p.audio.Hitfq`**: The frequency in Hz of the "high" tone, used to indicate a correct trial (hit).
- **`p.audio.Missfq`**: The frequency in Hz of the "low" tone, used to indicate an incorrect trial (miss/error).
- **`p.audio.auddur`**: The duration of the auditory tones in samples (e.g., 4800 samples, which is 100ms at 48kHz).
- **`p.audio.lineOutLevel`**: The audio level for the DataPixx line out, on a scale from 0 to 1.
- **`p.audio.pcPlayback`**: A boolean flag to determine if audio should be played from the host PC's soundcard (via Psychtoolbox) instead of the DataPixx.

## `p.draw`

This structure defines parameters for visual elements that are drawn on the screen. It includes dimensions, widths, and color look-up table (CLUT) indices.

- **`p.draw.eyePosWidth`**: The width in pixels of the eye position indicator on the experimenter's screen.
- **`p.draw.fixPointWidth`**: The line width in pixels of the fixation point.
- **`p.draw.fixPointRadius`**: The radius in pixels of the fixation point.
- **`p.draw.fixWinPenPre`**: The line width of the fixation window *before* a change.
- **`p.draw.fixWinPenPost`**: The line width of the fixation window *after* a change.
- **`p.draw.fixWinPenDraw`**: This variable is assigned the value of either `fixWinPenPre` or `fixWinPenPost` during the trial to dynamically change the fixation window's appearance.
- **`p.draw.gridSpacing`**: The spacing of the reference grid on the experimenter's display in degrees of visual angle.
- **`p.draw.gridW`**: The line width of the reference grid lines.
- **`p.draw.joyRect`**: The position and dimensions of the rectangle used to indicate joystick status on the experimenter's display.
- **`p.draw.cursorW`**: The width of the cursor in pixels.

### `p.draw.clutIdx`

This sub-structure contains indices for the Color Look-Up Table (CLUT). Each field name is a human-readable identifier for a color, and its value corresponds to a row in the CLUT. This allows for easy color changes by modifying the CLUT without changing the drawing code. The format is `expColor_subColor`, where `exp` is the color on the experimenter's screen and `sub` is the color on the subject's screen.

- **Example Fields**: `expBlack_subBlack`, `expBg_subBg`, `expRed_subBg`, `expCyan_subCyan`, etc.

### `p.draw.color`

This sub-structure assigns specific CLUT indices from `p.draw.clutIdx` to different visual elements in the task. This is where the color of each component is defined for the current trial.

- **`p.draw.color.background`**: CLUT index for the screen's background color.
- **`p.draw.color.cursor`**: CLUT index for the cursor color.
- **`p.draw.color.fix`**: CLUT index for the fixation point color.
- **`p.draw.color.fixWin`**: CLUT index for the fixation window color.
- **`p.draw.color.cueDots`**: CLUT index for the cue dots color.
- **`p.draw.color.foilDots`**: CLUT index for the foil dots color.
- **`p.draw.color.eyePos`**: CLUT index for the eye position indicator.
- **`p.draw.color.gridMajor`**: CLUT index for the major grid lines on the experimenter screen.
- **`p.draw.color.gridMinor`**: CLUT index for the minor grid lines on the experimenter screen.
- **`p.draw.color.cueRing`**: CLUT index for the cue ring color.
- **`p.draw.color.joyInd`**: CLUT index for the joystick indicator color.

## `p.state`

This structure defines the integer codes for the different states of the trial's state machine. The `p.trVars.currentState` variable will hold one of these values at any given time during a trial.

### Transition States
These are the states that constitute the normal flow of a trial.

- **`p.state.trialBegun` (1)**: The initial state of every trial. Used for setup before the ITI begins.
- **`p.state.waitForITI` (2)**: The inter-trial interval (ITI) state, a pause between trials.
- **`p.state.showCue` (3)**: The state where the fixation cue is displayed, prompting the subject to fixate.
- **`p.state.waitForFix` (4)**: The state where the system waits for the subject's gaze to enter the fixation window.
- **`p.state.holdFix` (5)**: The state where the subject must maintain fixation within the window for a specified duration.
- **`p.state.showOutcome` (6)**: The state where the token stimuli are displayed on the screen.
- **`p.state.cashInTokens` (7)**: The state where the token "cashing in" animation occurs, and rewards are delivered sequentially.

### End States (Aborted)
These states are reached if the trial is terminated prematurely due to an error.

- **`p.state.fixBreak` (11)**: The trial is aborted because the subject looked away from the fixation point during the `holdFix` state.
- **`p.state.nonStart` (12)**: The trial is aborted because the subject failed to acquire fixation on the cue within the allotted time.

### End States (Success)
This state is reached upon successful completion of the trial.

- **`p.state.success` (21)**: The trial was completed successfully, and all rewards were delivered.

## Trial Variables (`p.trVarsInit`, `p.trVarsGuiComm`, `p.trVars`)

These structures manage variables that can change on a trial-by-trial basis. They are crucial for controlling the difficulty and parameters of the task as the experiment progresses.

- **`p.trVarsInit`**: This structure is defined once in the settings file and holds the *default* values for all trial-specific variables.
- **`p.trVarsGuiComm`**: This structure's sole purpose is to communicate with the GUI. It is initialized with the values from `p.trVarsInit`. When a user changes a parameter in the GUI, it updates the corresponding field in `p.trVarsGuiComm`.
- **`p.trVars`**: This is the structure that is actively used during a trial. At the beginning of each trial (in the `_next.m` file), it inherits all values from `p.trVarsGuiComm`. This ensures that any changes made in the GUI are applied to the upcoming trial. The `p.trVars` structure is saved to the data file at the end of each trial.

### Key `p.trVarsInit` Fields

- **`passJoy` (boolean)**: If `true`, simulates correct joystick trials for debugging.
- **`passEye` (boolean)**: If `true`, simulates correct eye position trials for debugging.
- **`blockNumber` (integer)**: The current block number.
- **`repeat` (boolean)**: If `true`, the current trial's parameters will be repeated on the next trial.
- **`rwdJoyPR` (boolean)**: If `0`, reward is given for a joystick *press*. If `1`, reward is given for a joystick *release*.
- **`finish` (integer)**: The number of trials after which the experiment will automatically stop.
- **`filesufix` (integer)**: A suffix for the data file.
- **`joyVolt`, `eyeDegX`, `eyeDegY`, `eyePixX`, `eyePixY`**: Live readings of joystick voltage and eye position in degrees and pixels. Initialized to 0.
- **`fixDegX`, `fixDegY` (degrees)**: The X and Y coordinates of the fixation point.
- **`fixDur` (seconds)**: The required duration for which the subject must hold fixation.
- **`fixAqDur` (seconds)**: The maximum time allowed to acquire fixation on the cue.
- **`fixWinWidthDeg`, `fixWinHeightDeg` (degrees)**: The width and height of the fixation window.
- **`rewardDurationMs` (ms)**: The duration of a single juice pulse for a reward.
- **`juicePause` (seconds)**: The pause between sequential juice rewards when "cashing in" multiple tokens.
- **`outcomeDelay` (seconds)**: The delay after a successful fixation before the tokens are shown and "cashed in".
- **`tokenI` (integer)**: An index used to count through tokens during the reward delivery sequence.
- **`itiMean`, `itiMin`, `itiMax` (seconds)**: Parameters defining the duration of the inter-trial interval (ITI). The actual ITI for a trial is drawn from a distribution defined by these values.
- **`tokenBaseX`, `tokenBaseY` (degrees)**: The (X,Y) position of the first token.
- **`tokenSpacing` (degrees)**: The spacing between adjacent tokens.
- **`flickerFramesPerColor` (frames)**: The number of screen refreshes each color is displayed for during the token flicker animation.
- **`currentState` (integer)**: The current state of the state machine, initialized to `p.state.trialBegun`.
- **`exitWhileLoop` (boolean)**: A flag that, when set to `true`, terminates the `while` loop in the `_run.m` file, ending the current trial.
- **`fixPointRadPix`, `fixPointLinePix` (pixels)**: The radius and line weight of the fixation point.
- **`useCellsForDraw`, `wantEndFlicker`, `wantOnlinePlots` (booleans)**: Flags to control various drawing and plotting options.
- **`postFlip` (struct)**: A structure used internally for precise timing, to log the exact time an event occurred after a screen flip.
- **`flipIdx` (integer)**: An index that counts the number of screen flips in a trial.

## `p.trData`

This is one of the most important structures for post-experiment analysis. It contains all the data that is recorded during a single trial. A `p.trData` structure is saved for every trial, building up the dataset for the session. The fields are initialized before each trial via the `p.init.trDataInitList`.

### Raw Data Streams
- **`p.trData.eyeX`, `p.trData.eyeY`**: Arrays containing the raw X and Y eye position data for the trial.
- **`p.trData.eyeP`**: Array containing the raw pupil diameter data.
- **`p.trData.eyeT`**: Array containing the timestamps for each eye data sample.
- **`p.trData.joyV`**: Array containing the raw joystick voltage readings.
- **`p.trData.dInValues`**: Array of values from the digital input channels on the DataPixx.
- **`p.trData.dInTimes`**: Array of timestamps for the digital input values.
- **`p.trData.onlineEyeX`, `p.trData.onlineEyeY`**: Eye position data used for online plotting during the experiment.

### Timing Information
This sub-structure (`p.trData.timing`) contains timestamps for all key events within the trial. Timestamps are in seconds, relative to the start of the trial (`p.trData.timing.trialStartPTB`), unless otherwise noted. A value of -1 indicates that the event did not occur in that trial.

- **`p.trData.timing.trialStartPTB`**: The time the trial began, according to Psychtoolbox's `GetSecs`.
- **`p.trData.timing.trialStartDP`**: The time the trial began, according to the DataPixx clock.
- **`p.trData.timing.lastFrameTime`**: The timestamp of the most recent screen flip.
- **`p.trData.timing.flipTime`**: An array containing the timestamp for every screen flip that occurred during the trial.
- **`p.trData.timing.cueOn`**: The time the fixation cue appeared on the screen.
- **`p.trData.timing.fixAq`**: The time the subject's gaze first entered the fixation window.
- **`p.trData.timing.stimOn`**: The time the stimulus appeared (Note: this seems to be defined but not used in the `tokens_run.m` state machine, which uses `outcomeOn`).
- **`p.trData.timing.stimOff`**: The time the stimulus was removed (Note: seems unused).
- **`p.trData.timing.fixBreak`**: The time the subject's gaze left the fixation window during the hold period.
- **`p.trData.timing.reward`**: The time of reward delivery.
- **`p.trData.timing.outcomeOn`**: The time the token outcome was displayed.
- **`p.trData.timing.trialEnd`**: The time the trial's `run` loop concluded.

## `p.stim`

This structure contains parameters related to the visual stimuli used in the task. In this case, it primarily defines the properties of the tokens.

- **`p.stim.token.radius` (degrees)**: The radius of each token stimulus in degrees of visual angle.
- **`p.stim.token.color` ([R, G, B])**: The color of the token stimuli, defined as an RGB triplet.
