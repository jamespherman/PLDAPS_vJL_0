function p = conflict_task_settings
%  p = conflict_task_settings
%
%   Conflict Task
% =============
% A behavioral paradigm that pits goal-directed attention (driven by reward
% expectation) against stimulus-driven attention (driven by salience).
%
% Task sequence:
% Fixation dot appears, subject acquires fixation, after variable delay
% TWO bullseye stimuli appear simultaneously (one high-salience, one low-
% salience) at opposite locations. At go signal (fixation offset), subject
% makes a saccade to one of the two targets. The key manipulation is delta-t
% (stimulus onset asynchrony) - timing of stimulus onset relative to go signal.
%
% Trial Types:
%   CONGRUENT: High reward and high salience at same location
%   CONFLICT:  High reward and high salience at opposite locations
%
% Part of the quintet of pldaps functions:
%   settings function (this file)
%   init function
%   next function (before each trial)
%   run function (each trial)
%   finish function (after each trial)
%
%%% settings function
% runs at the very beginning of the task, only once.
% All settings are set here.
%   s struct has status values that change within the trial
%   p struct has control parameters that are defined once

%% p.init:
p = struct;

% determine which PC we're on so we can select the appropriate calibration
if ~ispc
    [~, p.init.pcName] = unix('hostname');
else
    % if this IS running on a (windows) PC, figure it out
    keyboard
end

% rig config file has subject/rig-specific details (eg distance from
% screen). Select rig config file depending on PC name:
p.init.rigConfigFile = which(['rigConfigFiles.rigConfig_rig' ...
    p.init.pcName(end-1)]);

%% define task name and related files:

p.init.taskName         = 'conflict_task';
p                       = pds.initTaskMetadata(p);
p.init.pldapsFolder     = pwd;
p.init.protocol_title   = [p.init.taskName '_task'];
p.init.date             = datestr(now,'yyyymmdd');
p.init.time             = datestr(now,'HHMM');

% output files:
p.init.outputFolder     = fullfile(p.init.pldapsFolder, 'output');
p.init.sessionId        = [p.init.date '_t' p.init.time '_' p.init.taskName];
p.init.sessionFolder    = fullfile(p.init.outputFolder, p.init.sessionId);

% Define the "init", "next", "run", and "finish" ".m" files.
p.init.taskFiles.init   = [p.init.taskName '_init.m'];
p.init.taskFiles.next   = [p.init.taskName '_next.m'];
p.init.taskFiles.run    = [p.init.taskName '_run.m'];
p.init.taskFiles.finish = [p.init.taskName '_finish.m'];

% are we using datapixx / viewpixx?
p.init.useDataPixxBool = true;

%% Define the Action M-files
p.init.taskActions{1} = 'pdsActions.dataToWorkspace';
p.init.taskActions{2} = 'pdsActions.blackScreen';
p.init.taskActions{3} = 'pdsActions.alphaBinauralBeats';
p.init.taskActions{4} = 'pdsActions.stopAudioSchedule';
p.init.taskActions{5} = 'pdsActions.rewardDrain';
p.init.taskActions{6} = 'pdsActions.dklToRgbFileMaker';
p.init.taskActions{7} = 'pdsActions.i1CalibrateAndMeasure';
p.init.taskActions{8} = 'pdsActions.i1Validate';

%% rig variables:
p.rig.screen_number     = 1;
p.rig.refreshRate       = 100;                  % display refresh rate (Hz)
p.rig.frameDuration     = 1/p.rig.refreshRate;  % display frame duration (s)
p.rig.joyThreshPress    = 0.5;
p.rig.joyThreshRelease  = 2;
p.rig.magicNumber       = 0.008;                % time to wait for screen flip
p.rig.joyVoltageMax     = 2.2436;

%% audio:
p.audio.audsplfq    = 48000;
p.audio.Hitfq       = 600;
p.audio.Missfq      = 100;
p.audio.auddur      = 4800;

%% STATES
% transition states:
p.state.trialBegun          = 1;
p.state.waitForJoy          = 2;
p.state.showFix             = 3;
p.state.dontMove            = 4;
p.state.makeSaccade         = 5;
p.state.checkLanding        = 6;
p.state.holdTarg            = 7;

% end states - success:
p.state.sacComplete         = 21;

% end states - aborted:
p.state.fixBreak            = 31;
p.state.joyBreak            = 32;
p.state.nonStart            = 33;
p.state.noResponse          = 34;  % no saccade within response window
p.state.inaccurate          = 35;  % saccade landed outside both targets

%% STATUS VALUES

p.status.iTrial             = 0;
p.status.iGoodTrial         = 0;
p.status.rippleOnline       = 0;

% Phase tracking (3 phases with different reward ratios)
% Phase 1: 1:1 reward ratio (128 dual-stim + 64 single-stim = 192 trials)
% Phase 2: 1:2 reward ratio - left:right (128 trials)
% Phase 3: 2:1 reward ratio - left:right (128 trials)
p.status.currentPhase           = 1;
p.status.trialsPerPhase         = 128;      % base dual-stim trials per phase
p.status.trialsPhase1           = 192;      % Phase 1: 128 dual + 64 single
p.status.singleStimTrials       = 64;       % single-stim trials in Phase 1
p.status.totalPhases            = 3;
p.status.completedTrialsInPhase = 0;
p.status.totalTrialsTarget      = 448;      % 192 + 128 + 128

% Outcome counters
p.status.nChoseHighSalience = 0;
p.status.nChoseLowSalience  = 0;
p.status.nFixBreak          = 0;
p.status.nNoResponse        = 0;
p.status.nInaccurate        = 0;
p.status.nSingleStimCorrect = 0;
p.status.nSingleStimTotal   = 0;

% Delta-T values (reduced from 6 to 2)
p.status.deltaTValues = [-150, 150];  % ms
p.status.nDeltaT = length(p.status.deltaTValues);

% Online metrics for new visualization design
% Phase 1 (1:1): categorize by high salience side (left vs right)
% Phases 2-3: categorize by conflict vs congruent
p.status.onlineMetrics = struct();

% Phase 1 metrics: by high salience side
p.status.onlineMetrics.phase1 = struct();
p.status.onlineMetrics.phase1.highSalLeft = cell(p.status.nDeltaT, 1);
p.status.onlineMetrics.phase1.highSalRight = cell(p.status.nDeltaT, 1);
for iDT = 1:p.status.nDeltaT
    p.status.onlineMetrics.phase1.highSalLeft{iDT} = struct(...
        'nChoseHighSal', 0, 'nChoseLowSal', 0, ...
        'rtHighSal', [], 'rtLowSal', []);
    p.status.onlineMetrics.phase1.highSalRight{iDT} = struct(...
        'nChoseHighSal', 0, 'nChoseLowSal', 0, ...
        'rtHighSal', [], 'rtLowSal', []);
end

% Phase 2 metrics: conflict vs congruent (1:2 ratio, high reward right)
p.status.onlineMetrics.phase2 = struct();
p.status.onlineMetrics.phase2.conflict = cell(p.status.nDeltaT, 1);
p.status.onlineMetrics.phase2.congruent = cell(p.status.nDeltaT, 1);
for iDT = 1:p.status.nDeltaT
    p.status.onlineMetrics.phase2.conflict{iDT} = struct(...
        'nChoseHighSal', 0, 'nChoseLowSal', 0, ...
        'rtHighSal', [], 'rtLowSal', []);
    p.status.onlineMetrics.phase2.congruent{iDT} = struct(...
        'nChoseHighSal', 0, 'nChoseLowSal', 0, ...
        'rtHighSal', [], 'rtLowSal', []);
end

% Phase 3 metrics: conflict vs congruent (2:1 ratio, high reward left)
p.status.onlineMetrics.phase3 = struct();
p.status.onlineMetrics.phase3.conflict = cell(p.status.nDeltaT, 1);
p.status.onlineMetrics.phase3.congruent = cell(p.status.nDeltaT, 1);
for iDT = 1:p.status.nDeltaT
    p.status.onlineMetrics.phase3.conflict{iDT} = struct(...
        'nChoseHighSal', 0, 'nChoseLowSal', 0, ...
        'rtHighSal', [], 'rtLowSal', []);
    p.status.onlineMetrics.phase3.congruent{iDT} = struct(...
        'nChoseHighSal', 0, 'nChoseLowSal', 0, ...
        'rtHighSal', [], 'rtLowSal', []);
end

% Cumulative tracking for evolution plot
p.status.onlineMetrics.cumulative = struct();
p.status.onlineMetrics.cumulative.trialNumbers = [];
p.status.onlineMetrics.cumulative.choseHighSal = [];    % 1 or 0 per trial
p.status.onlineMetrics.cumulative.phase = [];           % phase number per trial
p.status.onlineMetrics.cumulative.highSalSide = [];     % 1=left, 2=right
p.status.onlineMetrics.cumulative.isConflict = [];      % 1=conflict, 0=congruent (phases 2-3)
p.status.onlineMetrics.cumulative.isSingleStim = [];   % true if single-stimulus trial

%% user determines the n status values shown in gui upon init
p.rig.guiStatVals = {...
    'iTrial'; ...
    'iGoodTrial'; ...
    'currentPhase'; ...
    'completedTrialsInPhase'; ...
    'nChoseHighSalience'; ...
    'nChoseLowSalience'; ...
    'nFixBreak'; ...
    'nNoResponse'; ...
    'nInaccurate'};

%% user determines the 12 variables shown in gui upon init
p.rig.guiVars = {...
    'targetEccentricityDeg'; ...
    'rewardDurationMs'; ...
    'passEye'; ...
    'fixWinWidthDeg'; ...
    'fixWinHeightDeg'; ...
    'targWinWidthDeg'; ...
    'targWinHeightDeg'; ...
    'responseWindow'; ...
    'fixHoldDurationMin'; ...
    'fixHoldDurationMax'; ...
    'rewardRatioLeft'; ...
    'rewardRatioRight'};

%% INIT VARIABLES
p.init.exptType = 'conflict_task';

%% TRIAL VARIABLES
% general vars:
p.trVarsInit.passJoy                = 1;
p.trVarsInit.passEye                = 0;
p.trVarsInit.connectPLX             = 0;
p.trVarsInit.joyPressVoltDirection  = -1;
p.trVarsInit.repeat                 = 0;
p.trVarsInit.rwdJoyPR               = 0;
p.trVarsInit.wantEndFlicker         = true;
p.trVarsInit.finish                 = 4000;
p.trVarsInit.filesufix              = 1;
p.trVarsInit.joyVolt                = 0;
p.trVarsInit.eyeDegX                = 0;
p.trVarsInit.eyeDegY                = 0;
p.trVarsInit.eyePixX                = 0;
p.trVarsInit.eyePixY                = 0;
p.trVarsInit.mouseEyeSim            = 0;

% trial selection method
p.trVarsInit.setTargLocViaMouse         = false;
p.trVarsInit.setTargLocViaGui           = false;
p.trVarsInit.setTargLocViaTrialArray    = true;

% geometry/stimulus vars:
p.trVarsInit.fixDegX             = 0;       % fixation X location in degrees
p.trVarsInit.fixDegY             = 0;       % fixation Y location in degrees

% Target location system (8 locations: 4 left, 4 right)
% Locations defined by eccentricity and polar angles
p.trVarsInit.targetEccentricityDeg = 10;     % degrees from fixation (same for all targets)

% Right visual field angles: equally spaced between +45 and -45 degrees
% (0 degrees = rightward, positive = upward)
p.trVarsInit.rightAngles = [45, 15, -15, -45];  % 4 locations in right hemifield

% Left visual field angles: mirror symmetric to right
p.trVarsInit.leftAngles = [135, 165, -165, -135];  % 4 locations in left hemifield

% Current trial target indices (set per trial from trial array)
p.trVarsInit.leftLocIdx          = 1;       % index into leftAngles (1-4)
p.trVarsInit.rightLocIdx         = 1;       % index into rightAngles (1-4)

% Reward system (phase-dependent ratios)
% Total reward "budget" C is constant; ratio determines split
p.trVarsInit.rewardDurationMs        = 400;     % total reward budget C (ms)
p.trVarsInit.rewardRatioBig          = 2;       % asymmetric reward ratio (big:small = this:1)
p.trVarsInit.rewardProbHigh          = 0.9;     % P(canonical reward side) in Phases 2-3
p.trVarsInit.rewardBigSide           = 0;       % 1=big-left, 2=big-right (set per trial from array)
p.trVarsInit.rewardRatioLeft         = 1;       % current ratio part for left
p.trVarsInit.rewardRatioRight        = 1;       % current ratio part for right
p.trVarsInit.rewardDurationLeft      = 200;     % calculated: C * left/(left+right)
p.trVarsInit.rewardDurationRight     = 200;     % calculated: C * right/(left+right)
p.trVarsInit.rewardDelay             = 0.25;    % delay between target hold and reward
p.trVarsInit.timeoutAfterFa          = 1.0;     % timeout duration following errors (1s per user choice)
p.trVarsInit.timeoutSacErr           = 2.0;     % timeout for inaccurate saccades (outside both targets)
p.trVarsInit.joyWaitDur              = 15;      % wait for joystick press at trial start
p.trVarsInit.fixWaitDur              = 3;       % wait for fixation acquisition
p.trVarsInit.freeDur                 = 0;
p.trVarsInit.trialMax                = 15;
p.trVarsInit.joyReleaseWaitDur       = 3;
p.trVarsInit.stimFrameIdx            = 1;
p.trVarsInit.flipIdx                 = 1;
p.trVarsInit.postRewardDuration      = 0.25;
p.trVarsInit.joyPressVoltDir         = 1;

% Conflict task specific timing
p.trVarsInit.fixHoldDurationMin      = 1.0;     % min fixation hold before go signal (s)
p.trVarsInit.fixHoldDurationMax      = 1.4;     % max fixation hold before go signal (s)
p.trVarsInit.responseWindow          = 0.6;     % 600ms response window from go signal

p.trVarsInit.targHoldDurationMin     = 0.2;
p.trVarsInit.targHoldDurationMax     = 0.3;
p.trVarsInit.maxSacDurationToAccept  = 0.1;
p.trVarsInit.goLatencyMin            = 0.0;     % minimum allowed RT (0 for this task)
p.trVarsInit.goLatencyMax            = 0.6;     % 600ms max response time

p.trVarsInit.timeoutdur              = 0.275;

% Window sizes
p.trVarsInit.fixWinWidthDeg       = 4;
p.trVarsInit.fixWinHeightDeg      = 4;
p.trVarsInit.targWinWidthDeg      = 5;      % 5 degree radius per spec
p.trVarsInit.targWinHeightDeg     = 5;
p.trVarsInit.targWidth            = 12;     % target line width in pixels
p.trVarsInit.targRadius           = 16;

% Conflict task specific variables
p.trVarsInit.deltaT               = -150;   % stimulus onset asynchrony (ms)
p.trVarsInit.deltaTIdx            = 1;      % index into deltaTValues array (1 or 2)
p.trVarsInit.phaseNumber          = 1;      % 1, 2, or 3
p.trVarsInit.backgroundHueIdx     = 1;      % 1=Hue A (0 deg DKL), 2=Hue B (180 deg DKL)
p.trVarsInit.highSalienceSide     = 1;      % 1=left, 2=right
p.trVarsInit.chosenSide           = 0;      % 1=left, 2=right, 0=neither
p.trVarsInit.choseHighSalience    = false;  % true if chose high salience target
p.trVarsInit.outcome              = '';     % CHOSE_HIGH_SAL, CHOSE_LOW_SAL, FIX_BREAK, etc.

% For phases 2-3: conflict vs congruent categorization
% Phase 2: high reward = right, so conflict = high salience left
% Phase 3: high reward = left, so conflict = high salience right
p.trVarsInit.isConflict           = false;  % true if high sal opposes high reward

% Single-stimulus trial flag (Phase 1 bias correction)
% 0 = dual-stimulus (both targets), 1 = single-left, 2 = single-right
p.trVarsInit.singleStimSide      = 0;

% Target hue indices (set in nextParams based on backgroundHueIdx and highSalienceSide)
% High salience target: 180° from background, Low salience target: 45° from background
p.trVarsInit.highSalienceHueIdx   = 10;     % CLUT index for high salience hue
p.trVarsInit.lowSalienceHueIdx    = 9;      % CLUT index for low salience hue
p.trVarsInit.leftTargHueIdx       = 10;     % CLUT index for left target
p.trVarsInit.rightTargHueIdx      = 9;      % CLUT index for right target

% Location coordinates (computed in nextParams from angles)
p.trVarsInit.leftTarg_degX        = -5.66;  % default: 8 deg at 135 degrees
p.trVarsInit.leftTarg_degY        = 5.66;
p.trVarsInit.rightTarg_degX       = 5.66;   % default: 8 deg at 45 degrees
p.trVarsInit.rightTarg_degY       = 5.66;

% State tracking
p.trVarsInit.currentState         = p.state.trialBegun;
p.trVarsInit.exitWhileLoop        = false;

% Stimulus visibility
p.trVarsInit.stimuliVisible       = false;  % are the target stimuli visible?
p.trVarsInit.fixationVisible      = true;   % is fixation point visible?

% Timing values computed per trial (relative to fixation acquisition)
p.trVarsInit.timeGoSignal         = 0;      % time of go signal (fixation offset)
p.trVarsInit.timeStimOnset        = 0;      % time of stimulus onset (can be negative relative to go)

% online gaze tracking
p.trVarsInit.whileLoopIdx           = 0;
p.trVarsInit.eyeVelFiltTaps         = 5;
p.trVarsInit.eyeVelThresh           = 100;
p.trVarsInit.useVelThresh           = true;
p.trVarsInit.eyeVelThreshOffline    = 100;

p.trVarsInit.connectRipple          = true;
p.trVarsInit.rippleChanSelect       = 1;
p.trVarsInit.useOnlineSort  	    = 1;

% online plots
p.trVarsInit.wantOnlinePlots        = false;

p.trVarsInit.currentTrialsArrayRow = 1;

% substructure for marking stimulus-events after each flip
p.trVarsInit.postFlip.logical         = false;
p.trVarsInit.postFlip.varNames        = cell(0);

%% end of trVarsInit
p.trVarsGuiComm = p.trVarsInit;

%% trData - variables that acquire values during the trial
p.init.trDataInitList = {...
    'p.trData.eyeX',                    '[]'; ...
    'p.trData.eyeY',                    '[]'; ...
    'p.trData.eyeP',                    '[]'; ...
    'p.trData.eyeT',                    '[]'; ...
    'p.trData.joyV',                    '[]'; ...
    'p.trData.dInValues',               '[]'; ...
    'p.trData.dInTimes',                '[]'; ...
    'p.trData.onlineGaze',              '[]'; ...
    'p.trData.strobed',                 '[]'; ...
    'p.trData.spikeTimes',              '[]'; ...
    'p.trData.eventTimes',              '[]'; ...
    'p.trData.eventValues',             '[]'; ...
    'p.trData.preSacXY',                '[]'; ...
    'p.trData.postSacXY',               '[]'; ...
    'p.trData.peakVel',                 '[]'; ...
    'p.trData.SRT',                     '[]'; ...
    'p.trData.processingTime',          '[]'; ...  % RT + deltaT
    'p.trData.spikeClusters',           '[]'; ...
    'p.trData.trialEndState',           '-1'; ...
    'p.trData.trialRepeatFlag',         'false'; ...
    'p.trData.chosenSide',              '0'; ...   % 1=left, 2=right, 0=neither
    'p.trData.choseHighSalience',       'false'; ...
    'p.trData.outcome',                 ''''''; ...
    'p.trData.timing.lastFrameTime',    '0'; ...
    'p.trData.timing.fixOn',            '-1'; ...
    'p.trData.timing.fixAq',            '-1'; ...
    'p.trData.timing.fixOff',           '-1'; ...
    'p.trData.timing.stimOn',           '-1'; ...  % both stimuli on simultaneously
    'p.trData.timing.targetAq',         '-1'; ...
    'p.trData.timing.saccadeOnset',     '-1'; ...
    'p.trData.timing.saccadeOffset',    '-1'; ...
    'p.trData.timing.brokeFix',         '-1'; ...
    'p.trData.timing.reward',           '-1'; ...
    'p.trData.timing.tone',             '-1'; ...
    'p.trData.timing.trialBegin',       '-1'; ...
    'p.trData.timing.trialStartPTB'     '-1'; ...
    'p.trData.timing.trialStartDP',     '-1'; ...
    'p.trData.timing.frameNow',         '-1'; ...
    };

p.init.nTrDataListRows = size(p.init.trDataInitList, 1);

%% stimulus-specific:
% The Conflict Task uses only bullseye stimuli with DKL color manipulation

%% CLUT - Color Look Up Table
% CLUT index definitions for the static CLUT
p.draw.clutIdx.expBlack_subBlack         = 0;
p.draw.clutIdx.expGrey25_subBg           = 1;   % Grid lines
p.draw.clutIdx.expGrey_subBg             = 2;   % Default background
p.draw.clutIdx.expGrey70_subBg           = 3;   % Fixation/target window
p.draw.clutIdx.expWhite_subWhite         = 4;   % Not used
p.draw.clutIdx.expBlue_subBg             = 5;   % Gaze cursor
p.draw.clutIdx.expGreen_subBg            = 6;   % High reward indicator
p.draw.clutIdx.expDkGreen_subBg          = 7;   % Low reward indicator (optional)

% Indices for DKL hues for Bullseye stimuli
p.draw.clutIdx.expDkl0_subDkl0         = 8;     % Low salience (0 deg = isoluminant)
p.draw.clutIdx.expDkl45_subDkl45       = 9;     % Background for low salience
p.draw.clutIdx.expDkl180_subDkl180     = 10;    % High salience (180 deg = max contrast)
p.draw.clutIdx.expDkl225_subDkl225     = 11;    % Background for high salience

% Grayscale ramp (not needed for this task but kept for compatibility)
p.draw.clutIdx.grayscale_ramp_start = 18;
p.draw.clutIdx.grayscale_ramp_end   = 255;

%% COLORS
p.draw.color.background     = p.draw.clutIdx.expGrey_subBg;
p.draw.color.fix            = p.draw.clutIdx.expBlack_subBlack;
p.draw.color.fixWin         = p.draw.clutIdx.expGrey70_subBg;
p.draw.color.targWin        = p.draw.clutIdx.expGrey70_subBg;
p.draw.color.eyePos         = p.draw.clutIdx.expBlue_subBg;
p.draw.color.gridMajor      = p.draw.clutIdx.expGrey25_subBg;
p.draw.color.gridMinor      = p.draw.clutIdx.expGrey25_subBg;

%% draw parameters
p.draw.fixPointWidth        = 6;
p.draw.fixPointRadius       = 16;
p.draw.fixWinPenThin        = 4;
p.draw.fixWinPenThick       = 8;
p.draw.fixWinPenDraw        = [];

p.draw.targWinPenThin       = 4;
p.draw.targWinPenThick      = 8;
p.draw.targWinPenDraw       = [];

p.draw.eyePosWidth          = 8;
p.draw.gridSpacing          = 2;
p.draw.gridW                = 2;
p.draw.joyRect              = [1705 900 1735 1100];
p.draw.cursorW              = 6;

% Bullseye sizes (in degrees)
p.draw.bullseyeOuterDeg     = 2;    % 4 degree outer ring
p.draw.bullseyeInnerDeg     = 1;    % 2 degree inner ring

%% WHAT TO STROBE:
% NOTE: Every code name in column 1 MUST have a corresponding entry in
% +pds/initCodes.m. The strobing mechanism (pds.strobeTrialData) looks up
% p.init.codes.(codeName) to get the integer code to strobe.
p.init.strobeList = {...
    %--- basic information ---
    'taskCode',             'p.init.taskCode'; ...
    'date_1yyyy',           'p.init.date_1yyyy'; ...
    'date_1mmdd',           'p.init.date_1mmdd'; ...
    'time_1hhmm',           'p.init.time_1hhmm'; ...

    % --- Core Trial Information ---
    'trialCount',           'p.status.iTrial'; ...
    'goodTrialCount',       'p.status.iGoodTrial'; ...
    'phaseNumber',          'p.trVars.phaseNumber'; ...
    'rewardDurationLeft',   'p.trVars.rewardDurationLeft'; ...
    'rewardDurationRight',  'p.trVars.rewardDurationRight'; ...

    % --- Conflict Task Variables ---
    'deltaT',               'p.trVars.deltaT + 1000'; ...       % offset by 1000 to handle negatives
    'hueType',              'p.trVars.backgroundHueIdx'; ...    % 1=Hue A, 2=Hue B
    'highSalienceLocation', 'p.trVars.highSalienceSide'; ...    % 1=left, 2=right
    'chosenTarget',         'p.trData.chosenSide'; ...          % 1=left, 2=right, 0=neither
    'choseHighSalience',    'p.trData.choseHighSalience'; ...   % 0 or 1
    'outcomeCode',          'p.trData.outcomeCode'; ...         % 1=high sal, 2=low sal, 3+=error
    'singleStimSide',       'p.trVars.singleStimSide'; ...      % 0=dual, 1=single-left, 2=single-right
    'highRewardLocation',   'p.trVars.rewardBigSide'; ...          % 1=left, 2=right (per-trial)
    'rewardRatioBig_x100',  'round(p.trVars.rewardRatioBig * 100)'; ...  % ratio * 100
    'rewardProbHigh_x1000', 'round(p.trVars.rewardProbHigh * 1000)'; ... % probability * 1000

    % --- Target locations using theta/radius (avoids negative coordinate issues) ---
    % Theta: angle in degrees * 10, with +1800 offset to handle negatives (-180 to +180 -> 0 to 3600)
    % Radius: eccentricity in degrees * 100
    'leftTargTheta',        'round(p.trVarsInit.leftAngles(p.trVars.leftLocIdx) * 10) + 1800'; ...
    'leftTargRadius',       'round(p.trVarsInit.targetEccentricityDeg * 100)'; ...
    'rightTargTheta',       'round(p.trVarsInit.rightAngles(p.trVars.rightLocIdx) * 10) + 1800'; ...
    'rightTargRadius',      'round(p.trVarsInit.targetEccentricityDeg * 100)'; ...
    };

end
