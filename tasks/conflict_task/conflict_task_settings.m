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
p.status.iBlock             = 1;
p.status.iTrialInBlock      = 0;
p.status.rippleOnline       = 0;

% Outcome counters
p.status.nGoalDirected      = 0;
p.status.nCapture           = 0;
p.status.nFixBreak          = 0;
p.status.nNoResponse        = 0;
p.status.nInaccurate        = 0;

% Online metrics for tachometric curve
% Structure: onlineMetrics.conflict{deltaTIdx} and onlineMetrics.congruent{deltaTIdx}
% Each cell contains struct with nGoalDirected, nCapture, RTs
% NOTE: deltaTValues and onlineMetrics are reinitialized in initTrialStructure.m
% to ensure consistency with the actual trial array. Values here are placeholders.
p.status.deltaTValues = [-100, -50, 0, 50, 100, 150];  % ms (updated by initTrialStructure)
p.status.nDeltaT = length(p.status.deltaTValues);

p.status.onlineMetrics = struct();
p.status.onlineMetrics.conflict = cell(p.status.nDeltaT, 1);
p.status.onlineMetrics.congruent = cell(p.status.nDeltaT, 1);
for iDT = 1:p.status.nDeltaT
    p.status.onlineMetrics.conflict{iDT} = struct(...
        'nGoalDirected', 0, 'nCapture', 0, ...
        'rtGoalDirected', [], 'rtCapture', []);
    p.status.onlineMetrics.congruent{iDT} = struct(...
        'nGoalDirected', 0, 'nCapture', 0, ...
        'rtGoalDirected', [], 'rtCapture', []);
end

%% user determines the n status values shown in gui upon init
p.rig.guiStatVals = {...
    'iTrial'; ...
    'iGoodTrial'; ...
    'iBlock'; ...
    'nGoalDirected'; ...
    'nCapture'; ...
    'nFixBreak'; ...
    'nNoResponse'; ...
    'nInaccurate'};

%% user determines the 12 variables shown in gui upon init
p.rig.guiVars = {...
    'locationA_x'; ...
    'locationA_y'; ...
    'rewardDurationHigh'; ...
    'rewardDurationLow'; ...
    'passEye'; ...
    'fixWinWidthDeg'; ...
    'fixWinHeightDeg'; ...
    'targWinWidthDeg'; ...
    'targWinHeightDeg'; ...
    'responseWindow'; ...
    'fixHoldDurationMin'; ...
    'fixHoldDurationMax'};

%% INIT VARIABLES
p.init.exptType = 'conflict_task';

%% TRIAL VARIABLES
% general vars:
p.trVarsInit.passJoy                = 1;
p.trVarsInit.passEye                = 0;
p.trVarsInit.connectPLX             = 0;
p.trVarsInit.joyPressVoltDirection  = -1;
p.trVarsInit.blockNumber            = 0;
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

% Location A - experimenter-specified RF location (GUI-editable)
p.trVarsInit.locationA_x         = -7;      % Location A X position (degrees)
p.trVarsInit.locationA_y         = 5;       % Location A Y position (degrees)

% Location B is computed as 180-degree rotation of Location A
% (computed in nextParams, not stored here)

% times/latencies/durations:
p.trVarsInit.rewardDurationHigh      = 350;     % reward duration for goal-directed choice (ms)
p.trVarsInit.rewardDurationLow       = 160;     % reward duration for capture (ms)
p.trVarsInit.rewardDurationMs        = 350;     % current reward duration (set per trial)
p.trVarsInit.rewardDelay             = 0.25;    % delay between target hold and reward
p.trVarsInit.timeoutAfterFa          = 1.0;     % timeout duration following errors (1s per user choice)
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
p.trVarsInit.fixWinWidthDeg       = 2;
p.trVarsInit.fixWinHeightDeg      = 2;
p.trVarsInit.targWinWidthDeg      = 5;      % 5 degree radius per spec
p.trVarsInit.targWinHeightDeg     = 5;
p.trVarsInit.targWidth            = 12;     % target line width in pixels
p.trVarsInit.targRadius           = 16;

% Conflict task specific variables
p.trVarsInit.deltaT               = 0;      % stimulus onset asynchrony (ms)
p.trVarsInit.deltaTIdx            = 4;      % index into deltaTValues array
p.trVarsInit.trialType            = 1;      % 1=CONFLICT, 2=CONGRUENT
p.trVarsInit.highRewardLocation   = 1;      % 1=A, 2=B (block-determined)
p.trVarsInit.highSalienceLocation = 1;      % 1=A, 2=B (trial-determined)
p.trVarsInit.hueType              = 1;      % 1 or 2 (counterbalanced color scheme)
p.trVarsInit.chosenTarget         = 0;      % which target was chosen (1=A, 2=B)
p.trVarsInit.outcome              = '';     % GOAL_DIRECTED, CAPTURE, FIX_BREAK, etc.

% Location coordinates (computed in nextParams)
p.trVarsInit.targA_degX           = -7;
p.trVarsInit.targA_degY           = 5;
p.trVarsInit.targB_degX           = 7;
p.trVarsInit.targB_degY           = -5;

% Polar coordinates for strobing (computed in nextParams, same as gSac_4factors)
p.trVarsInit.targTheta_x10        = 0;    % target angle * 10 (0-3600)
p.trVarsInit.targRadius_x100      = 0;    % target eccentricity * 100

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
    'p.trData.chosenTarget',            '0'; ...   % 1=A, 2=B, 0=neither
    'p.trData.outcomeCode',             '0'; ...   % 1=goal, 2=capture, 3+=error types
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
% Salience is defined by hue contrast between target and background:
%   High salience = 180 deg hue difference (maximum chromatic contrast)
%   Low salience = 45 deg hue difference (reduced chromatic contrast)
p.draw.clutIdx.expDkl0_subDkl0         = 8;     % 0 deg DKL hue (background when A=high sal)
p.draw.clutIdx.expDkl45_subDkl45       = 9;     % 45 deg DKL hue (low sal target, 45 deg from 0)
p.draw.clutIdx.expDkl180_subDkl180     = 10;    % 180 deg DKL hue (high sal target, 180 deg from 0; or bg when B=high sal)
p.draw.clutIdx.expDkl225_subDkl225     = 11;    % 225 deg DKL hue (low sal target, 45 deg from 180)

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
p.draw.bullseyeOuterDeg     = 4;    % 4 degree outer ring
p.draw.bullseyeInnerDeg     = 2;    % 2 degree inner ring

%% WHAT TO STROBE:
p.init.strobeList = {...
    %--- basic information ---
    'taskCode',             'p.init.taskCode'; ...
    'date_1yyyy',           'p.init.date_1yyyy'; ...
    'date_1mmdd',           'p.init.date_1mmdd'; ...
    'time_1hhmm',           'p.init.time_1hhmm'; ...

    % --- Core Trial Information ---
    'trialCount',           'p.status.iTrial'; ...
    'goodTrialCount',       'p.status.iGoodTrial'; ...
    'blockNumber',          'p.trVars.blockNumber'; ...
    'rewardDuration',       'p.trVars.rewardDurationMs'; ...

    % --- Conflict Task Variables ---
    'trialType',            'p.trVars.trialType'; ...           % 1=CONFLICT, 2=CONGRUENT
    'deltaT',               'p.trVars.deltaT + 1000'; ...       % offset by 1000 to handle negatives
    'highRewardLocation',   'p.trVars.highRewardLocation'; ...  % 1=A, 2=B
    'highSalienceLocation', 'p.trVars.highSalienceLocation'; ...% 1=A, 2=B
    'hueType',              'p.trVars.hueType'; ...             % 1 or 2 (counterbalanced color scheme)
    'chosenTarget',         'p.trData.chosenTarget'; ...        % 1=A, 2=B, 0=neither
    'outcomeCode',          'p.trData.outcomeCode'; ...         % 1=goal, 2=capture, 3+=error

    % --- Location A in polar coordinates (same approach as gSac_4factors) ---
    % Location B is always 180 deg opposite, so only A needs to be strobed
    'targetTheta',          'p.trVars.targTheta_x10'; ...       % theta * 10 (0-3600)
    'targetRadius',         'p.trVars.targRadius_x100'; ...     % radius * 100
    };

end
