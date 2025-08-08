function p = gSac_4factors_settings
%  p = gSac_4factors_settings
%
%   gSac_4factors task
% =============
% gSac - guided saccades. 
% This is your stock visually- or memory-guided saccade task.
% 
% Task sequence:
% fixation dot appears, subject acquires fixation, a target appears 
% elsewhere and either stays on (visually-gSac) or disappears 
% (memory-gSac), delay, fixation point disappears indicating subject to
% make a saccade to target, reward. 

% Part of the quintet of pldpas functions:
%   settings function
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


%%
% p.init;           % all things that are saved once except for trialVarsInit
% p.rig;            % all rig (monitor, PTB stuff, distances) related stuff
% 


% p.audio;          % all things audio related
% p.draw;           % all widths/hieghts/etc of stuff that's drawn. (all except for stimulus, which is saved uniquely in stim struct)
% p.state           % all the states that we use and their id integer
% p.trVarsInit;     % all vars used in pldaps. here intiailized.
% p.trVars;         % all vars used in run function inherit value from trVarsInit.
% p.trVarsGuiComm;  % inheritance and user update of trVars happens through this struct, the trial variables gui coomunication
% p.trData;         % all data collected in a trial (behavior, timing, analog..)


%% p.init:
p = struct;

% determine which PC we're on so we can select the appropriate reward
% magnitude:
if ~ispc
    [~, p.init.pcName] = unix('hostname');
else
    % if this IS running on a (windows) PC that means we've neglected to
    % account for something - figure it out now! JPH - 5/16/2023
    keyboard
end

% rig config file has subject/rig-specific details (eg distance from
% screen). Select rig config file depending on PC name (assuming the 2nd to
% last characteer in the pcName string is 1 or 2):
p.init.rigConfigFile     = which(['rigConfigFiles.rigConfig_rig' ...
    p.init.pcName(end-1)]);


%% define task name and related files:

p.init.taskName         = 'gSac_4factors';
p                       = pds.initTaskMetadata(p); 
p.init.pldapsFolder     = pwd;                          % pldaps gui takes us to taks folder automatically once we choose a settings file
p.init.protocol_title   = [p.init.taskName '_task'];    % Define Banner text to identify the experimental protocol
p.init.date             = datestr(now,'yyyymmdd');
p.init.time             = datestr(now,'HHMM');

% output files:
p.init.outputFolder     = fullfile(p.init.pldapsFolder, 'output');
p.init.sessionId        = [p.init.date '_t' p.init.time '_' p.init.taskName];     % Define the prefix for the Output File
p.init.sessionFolder    = fullfile(p.init.outputFolder, p.init.sessionId);

% Define the "init", "next", "run", and "finish" ".m" files.
p.init.taskFiles.init   = [p.init.taskName '_init.m'];
p.init.taskFiles.next   = [p.init.taskName '_next.m'];
p.init.taskFiles.run    = [p.init.taskName '_run.m'];
p.init.taskFiles.finish = [p.init.taskName '_finish.m'];

% are we using datapixx / viewpixx?
p.init.useDataPixxBool = true;

%% Define the Action M-files
% User-defined actions that are either within the task folder under
% "actions" or within the +pds package under "actions":
p.init.taskActions{1} = 'pdsActions.dataToWorkspace';
p.init.taskActions{2} = 'pdsActions.blackScreen';
p.init.taskActions{3} = 'pdsActions.alphaBinauralBeats';
p.init.taskActions{4} = 'pdsActions.stopAudioSchedule';
p.init.taskActions{5} = 'pdsActions.rewardDrain';
p.init.taskActions{6} = 'pdsActions.dklToRgbFileMaker';
p.init.taskActions{7} = 'pdsActions.i1CalibrateAndMeasure';
p.init.taskActions{8} = 'pdsActions.i1Validate';

% p.init.taskActions.action_2 = 'load_old.m';
% p.init.taskActions.action_3 = 'save_data.m';
% p.init.taskActions.action_4 = 'Inactivation_ON.m';
% p.init.taskActions.action_5 = 'showbehavior.m';
% p.init.taskActions.action_6 = 'saveplot.m';
% % p.init.taskActions.action_7 = 'save_data.m';
% p.init.taskActions.action_8 = 'psychmetrics.m';
% p.init.taskActions.action_9 = 'RT_hist.m';

%% rig variables:
p.rig.screen_number     = 1;                    % zero for one screen set-up, 1 or 2 for multiscreen
p.rig.refreshRate       = 100;                  % display refresh rate (Hz).
p.rig.frameDuration     = 1/p.rig.refreshRate;  % display frame duration (s);
p.rig.joyThreshPress    = 0.5;                  % joystick press threshold voltage (what voltages count as "joystick pressed"?)
p.rig.joyThreshRelease  = 2;                    % joystick release threshold voltage (what voltages count as "joystick released"?)
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
p.state.failedToHoldTarg    = 34;

%% STATUS VALUES

p.status.iTrial             = 0;
p.status.iGoodTrial         = 0;
p.status.iGoodVis           = 0;
p.status.iGoodMem           = 0;
p.status.pGoodVis           = 0;
p.status.pGoodMem           = 0;
p.status.iTarget            = 0;
p.status.rippleOnline       = 0;
p.status.tLoc1HighRwdFirst  = 0;

%% user determines the n status values shwon in gui upon init
% here you just list the status vals you want to see. You do not set them,
% yet. Setting them takes place below in the appropriate section.
% The list of vars should be in string format eg 'hr1Loc1'
p.rig.guiStatVals           = {...
    'iTrial'; ...
    'iGoodTrial'; ...
    'iGoodVis'; ...
    'iGoodMem'; ...
    'pGoodVis'; ...
    'pGoodMem'; ...
    'iTarget'; ...
    'tLoc1HighRwdFirst'};

%% user determines the 12 variables are shown in gui upon init
% here you just list the vars you want to see. You do not set them, yet.
% Setting them takes place below in the appropriate section.
% The list of vars should be in string format eg 'p.trVarsInit.cueDelta'

p.rig.guiVars = {...
    'targTrainingDelay';...
    'fixDegX'; ...          
    'fixDegY'; ...
    'rewardDurationMs'; ...       
    'passEye'; ...
    'targDegX'; ...
    'targDegY'; ...
    'targWinHeightDeg'; ...
    'targWinWidthDeg'; ...
    'rewardDelay'; ...        % 6
    'rewardDurationHigh'; ...
    'rewardDurationLow'};              % 12



%% INIT VARIABLES 
% vars that are only set once

p.init.exptType         = 'gSac_4factors';  % Which experiment are we running? The full version with all trial types? The single-stimulus-only version? Something else?

%% TRIAL VARIABLES
% vars that may change throughout an experimental session and are therefore
% saved on every trial. 
% Here we define 'trVarsInit' as this is the default. However, user may
% change any variable through the gui (which updates 'trVarsGuiComm) and
% then updates 'trVars' during the run function. 
% 'trVars' is the key strcutarray that gets saved on every trial.

% general vars:
p.trVarsInit.passJoy                = 1;    % pass = 1; simulate correct trials (for debugging)
p.trVarsInit.passEye                = 0;    % pass = 1; simulate correct trials (for debugging)
p.trVarsInit.connectPLX             = 0;
p.trVarsInit.joyPressVoltDirection  = -1;   % -1 = pressing down reduces voltage. 1=pressing down increaess voltage
p.trVarsInit.blockNumber            = 0;       % block number
p.trVarsInit.repeat                 = 0;       % repeat trial if true
p.trVarsInit.rwdJoyPR               = 0;       % 0 = Give reward if Joy is pressed; 1 = Give reward if Joystick released
p.trVarsInit.wantEndFlicker         = true;   % have screen flicker while waiting for joystick release.
p.trVarsInit.finish                 = 4000;
p.trVarsInit.filesufix              = 1;    % save to file sufix
p.trVarsInit.joyVolt                = 0;
p.trVarsInit.eyeDegX                = 0;
p.trVarsInit.eyeDegY                = 0;
p.trVarsInit.eyePixX                = 0;
p.trVarsInit.eyePixY                = 0;
p.trVarsInit.mouseEyeSim            = 0;

% how to set the next target location (via mouse, gui, or neither). If
% neither, then they get set at random from the predefined grid.
p.trVarsInit.setTargLocViaMouse         = false;
p.trVarsInit.setTargLocViaGui           = false;
p.trVarsInit.setTargLocViaTrialArray    = true;

% geometry/stimulus vars:
p.trVarsInit.propVis             = 0;    % proportion of visually-guided saccades out of the total (i.e. propMem would equal 1 - pVis )
p.trVarsInit.fixDegX             = 0;    % fixation X location in degrees
p.trVarsInit.fixDegY             = 0;    % fixation Y location in degrees
p.trVarsInit.targDegX            = -5;  % default target X location if one isn't specified by other means
p.trVarsInit.targDegY            = 5;    % default target Y location if one isn't specified by other means

% times/latencies/durations:
p.trVarsInit.rewardDurationHigh      = 350;      % reward duration (solenoid open time) for "large reward" target
p.trVarsInit.rewardDurationLow       = 160;       % reward duration for "small reward" target
p.trVarsInit.rewardDurationMs        = 165;      % reward duration variable used to define solenoid opening "schedule" (VPixx)
p.trVarsInit.rwdSize                 = 0;        % variable to store whether the current trial is "high" or "low" reward (coded as 1 or 2).
p.trVarsInit.rewardDelay             = 0.25;     % delay between successful target fixation and reward delivery
p.trVarsInit.timeoutAfterFa          = 2;        % timeout duration following false alarm.
p.trVarsInit.joyWaitDur              = 15;       % how long to wait for the subject to press the joystick at the beginning of a trial?
p.trVarsInit.fixWaitDur              = 3;        % how long to wait after initial joystick press for the subject to acquire fixation?
p.trVarsInit.freeDur                 = 0;        % time before start of joystick press check
p.trVarsInit.trialMax                = 15;       % max length of the trialF
p.trVarsInit.joyReleaseWaitDur       = 3;        % how long to wait after trial end to start flickering the screen if the joystick hasn't been released
p.trVarsInit.stimFrameIdx            = 1;        % stimulus (eg dots) frame display index
p.trVarsInit.flipIdx                 = 1;        % index of
p.trVarsInit.postRewardDuration      = 0.25;     % how long should the trial last AFTER reward delivery? This lets us record the neuronal response to reward.
p.trVarsInit.joyPressVoltDir         = 1;

p.trVarsInit.targetFlashDuration     = 0.4;      % Duration target stays on for the memory-guided trials.
% p.trVarsInit.postFlashFixMin       = 1;    % minimum post-flash fixation-duration
% p.trVarsInit.postFlashFixMax       = 1.5;  % maximum post-flash fixation-duration
p.trVarsInit.targHoldDurationMin     = 0.2;  % minimum duration to maintain fixation on the target post-saccade 
p.trVarsInit.targHoldDurationMax     = 0.3;      % maximum duration to maintain fixation on the target post-saccade 
p.trVarsInit.maxSacDurationToAccept  = 0.1; % this is the max duration of a saccades that we're willing to wait for. 
p.trVarsInit.goLatencyMin            = 0.1;  % minimum saccade-latency criterion
p.trVarsInit.goLatencyMax            = 1;  % maximum saccade-latency criterion
% p.trVarsInit.preTargMin            = 0.75; % minimum fixation-only time before target onset
% p.trVarsInit.preTargMax            = 1;    % maximum fixation-only time before target onset
p.trVarsInit.targOnsetMin            = 0.75; % minimum fixation-only time before target onset
p.trVarsInit.targOnsetMax            = 1;
p.trVarsInit.goTimePostTargMin       = 0.3; % min duration from targ onset to the 'go' signal to saccade (which is fixation offset)
p.trVarsInit.goTimePostTargMax       = 0.8; % max duration from targ onset to the 'go' signal to saccade (which is fixation offset)

p.trVarsInit.maxFixWait              = 10;    % maximum time to wait for fixation-acquisition
p.trVarsInit.targOnSacOnly           = 1;    % condition target reappearance on saccade?
p.trVarsInit.rwdTime                 = -1;

% if we're training the animal to make memory guided sacacdes, we'll delay
% the onset of the target after fixation offset without making it saccade
% contingent. What should this delay be?
p.trVarsInit.targTrainingDelay       = -1;
p.trVarsInit.timeoutdur              = 0.275;    % how long to time-out after an error-trial (in seconds)?
p.trVarsInit.minTargAmp              = 2.5;    % minimum target amplitude
p.trVarsInit.maxTargAmp              = 18;   % maximum target amplitude
p.trVarsInit.staticTargAmp           = 12;  % fixed target amplitude
p.trVarsInit.maxHorzTargAmp          = 20;  % when using the "rectangular annulus" method of specifying target locations, we need separate horizontal and vertical max amps
p.trVarsInit.maxVertTargAmp          = 12;  % "rectangular annulus" method of specifying target amplitude
        
p.trVarsInit.fixWinWidthDeg       = 2;        % fixation window width in degrees
p.trVarsInit.fixWinHeightDeg      = 2;        % fixation window height in degrees
p.trVarsInit.targWinWidthDeg      = 8;        % target window width in degrees
p.trVarsInit.targWinHeightDeg     = 8;        % target window height in degrees
p.trVarsInit.targWidth            = 12;       % fixation point indicator line width in pixels
p.trVarsInit.targRadius           = 16;       % fixation point "radius" in pixels

p.trVarsInit.stimConfigIdx        = 0;      % integer indicating which target / background color configuration is used on the current trial

% I don't think I need to carry these around in 'p'....
% can't I just define them in the 'run' worksapce and forget avbout them?
p.trVarsInit.currentState     = p.state.trialBegun;  % initialize "state" variable.
p.trVarsInit.exitWhileLoop    = false;  % do we want to exit the "run" while loop?

p.trVarsInit.targetIsOn = false;

p.trVarsInit.postMemSacTargOn = false;  % do we want the target on because a memory guided saccade has been successfully completed?

% variables related to online tracking of gaze position / velocity
p.trVarsInit.whileLoopIdx           = 0;    % numerical index to current iteration of run while-loop
p.trVarsInit.eyeVelFiltTaps         = 5;    % length in samples of online velocity filter
p.trVarsInit.eyeVelThresh           = 100;   % threshold in deg/s for online saccade detection
p.trVarsInit.useVelThresh           = true; % does the experimenter want to use the velocity threshold to check saccade onset / offset?
p.trVarsInit.eyeVelThreshOffline    = 100;   % gaze velocity threshold in deg/s for offline saccade detection (cleaner signal, lower threshold).

p.trVarsInit.connectRipple          = true;
p.trVarsInit.rippleChanSelect       = 1;
p.trVarsInit.useOnlineSort  	    = 1; % a boolean indicating whether we want to use spike times that have been sorted online in trellis or all threshold crossing times.

% do we want online plots?
p.trVarsInit.wantOnlinePlots        = false;

%% end of trVarsInit
% once all trial variables have been initialized in trVarsInit, we copy 
% them to 'trVarsGuiComm' in order to inform the gui. 
% trVarsGuiComm's sole purpose is to communicate between the gui and the 
% trVars that inherit its contents on every trial. Thus, user may change
% things in gui (which effectively chagnes the trVarsGuiComm) that then
% (in the 'next' function) updates the trVars!

p.trVarsGuiComm = p.trVarsInit;

%% trData - These are variables that acquire their values during the trial.
% These variables need to be initialized to specific values prior to each
% trial. Define a cell-array of variable names and values to loop over and
% initialize prior to each trial.
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
    'p.trData.spikeClusters',           '[]'; ...
    'p.trData.trialEndState',           '-1'; ...   % final state in trial
    'p.trData.trialRepeatFlag',         'false'; ...
    'p.trData.timing.lastFrameTime',    '0'; ...    % time at which last video frame was displayed
    'p.trData.timing.fixOn',            '-1'; ...   % time of fixation onset
    'p.trData.timing.fixAq',            '-1'; ...   % time of fixation acquisition
    'p.trData.timing.fixOff',           '-1'; ...   % time of fixation offset
    'p.trData.timing.targetOn'          '-1'; ...   % time of target onset
    'p.trData.timing.targetOff',        '-1'; ...   % time of target offset
    'p.trData.timing.targetReillum',    '-1'; ...   % time of target reillumination (memsac)
    'p.trData.timing.targetAq',         '-1'; ...   % time of target acquisition
    'p.trData.timing.saccadeOnset',     '-1'; ...   % time of saccade start
    'p.trData.timing.saccadeOffset',    '-1'; ...   % time of saccade end
    'p.trData.timing.brokeFix',         '-1'; ...   % time of fixation break
    'p.trData.timing.reward',           '-1'; ...   % time of reward delivery
    'p.trData.timing.tone',             '-1'; ...   % time of audio feedback delivery
    'p.trData.timing.trialBegin',       '-1'; ...   % time of trial begin
    'p.trData.timing.trialStartPTB'     '-1'; ...   % time of joystick release relative to dimming
    'p.trData.timing.trialStartDP',     '-1'; ...   % time that fixation hold duration was met (also time of fixation dimming)
    'p.trData.timing.frameNow',         '-1'; ...   % current frame number
    };

% since the list above is 50fixed, count its rows now for looping over later.
p.init.nTrDataListRows                  = size(p.init.trDataInitList, 1);

%% stimulus-specific:
% The 'stimulus' in this task is for target location.
% Target location is preset (e.g. on a grid or a ring or other) but can 
% be overriden and set via mouse location or gui.

% define your preset here, and then it's paramters, below. 
% The location of each target gets defined in 'initTargetLocationList'
p.stim.targLocationPreset = 'nRing'; 

switch p.stim.targLocationPreset
    case 'grid'
        % paramters for the grid:
        p.stim.gridMinX     = -15;
        p.stim.gridMaxX     = 15;
        p.stim.gridBinSizeX = 5;
        p.stim.gridMinY     = -10;
        p.stim.gridMaxY     = 10;
        p.stim.gridBinSizeY = 5;
        
    case 'ring'
        % paramters for the ring:
        p.stim.ringRadius       = 10; % can be single, or more e.g. [10 15]
        p.stim.ringTargNumber   = 8;
        p.stim.ringBaseAngle    = 0; % the angle at which the first target is located. The rest are then plotted to complete the ring
        
    case 'nRing'
        p.stim.ringRadius       = [5 10 15]; % can be single, or more e.g. [10 15]
        p.stim.ringTargNumber   = [8 8 8];
        p.stim.ringBaseAngle    = [0 0 0]; % the angle at which the first target is located. The rest are then plotted to complete the ring
end

% targets are usually dots, but it could be a patch, image, anything.
p.stim.dotWidth              = 6;        % dot width

% Set the visual angle of the square stimulus images
p.stim.stimDiamDeg = 6;

% This controls the degree of intensity compression. Max is 238.
p.stim.nStimLevels = 5; 

%% CLUT - Color Look Up Table
% CLUT index definitions for the static CLUT
p.draw.clutIdx.expBlack_subBlack         = 0;
p.draw.clutIdx.expGrey25_subBg           = 1;  % Grid lines
p.draw.clutIdx.expGrey_subBg             = 2;  % Default background (isoluminant gray)
p.draw.clutIdx.expGrey70_subBg           = 3;  % Fixation window
p.draw.clutIdx.expWhite_subWhite         = 4;  % Fixation point
p.draw.clutIdx.expBlue_subBg             = 5;  % Gaze cursor
p.draw.clutIdx.expGreen_subBg            = 6;  % High reward indicator for experimenter
p.draw.clutIdx.expDkGreen_subBg          = 7;  % (Optional) Low reward indicator for experimenter

% Indices for the 4 key DKL hues for Bullseye trials
p.draw.clutIdx.expDkl0_subDkl0         = 8;
p.draw.clutIdx.expDkl45_subDkl45       = 9;
p.draw.clutIdx.expDkl180_subDkl180     = 10;
p.draw.clutIdx.expDkl225_subDkl225     = 11;

% Indices for the Grayscale Ramp for Image trials
p.draw.clutIdx.grayscale_ramp_start = 18;
p.draw.clutIdx.grayscale_ramp_end   = 255;

%% COLORS
% Default color assignments for various task elements. These define the
% initial state. Many of these will be changed dynamically in the _run.m file.

% Each color is assigned a row in the CLUT based on the clutIdx struct above.
p.draw.color.background     = p.draw.clutIdx.expGrey_subBg;      % Default background is isoluminant gray
p.draw.color.fix            = p.draw.clutIdx.expWhite_subWhite;  % Fixation point is always white
p.draw.color.fixWin         = p.draw.clutIdx.expGrey70_subBg;    % Fixation window (for experimenter)
p.draw.color.targWin        = p.draw.clutIdx.expGrey70_subBg;    % Target window (for experimenter)
p.draw.color.eyePos         = p.draw.clutIdx.expBlue_subBg;      % Gaze position cursor
p.draw.color.gridMajor      = p.draw.clutIdx.expGrey25_subBg;    % Grid lines
p.draw.color.gridMinor      = p.draw.clutIdx.expGrey25_subBg;    % Grid lines (using same color as major)

%% draw - these are paramters used for drawing
% the boring stuff, like width and height of stuff that gets drawn.

% fixation point and fixation point win:
p.draw.fixPointWidth        = 6;        % fixation point indicator line width in pixels
p.draw.fixPointRadius       = 16;        % fixation point "radius" in pixels
p.draw.fixWinPenThin        = 4;        % fixation window width (prior to 'go' signal).
p.draw.fixWinPenThick       = 8;        % fixation window width (post 'go' signal).
p.draw.fixWinPenDraw        = [];       % gets assigned either the pre or the post during the run function 

% target and target win:
p.draw.targWinPenThin       = 4;        % fixation window width (prior to 'go' signal).
p.draw.targWinPenThick      = 8;        % fixation window width (post 'go' signal).
p.draw.targWinPenDraw       = [];       % gets assigned either the pre or the post during the run function

% others:
p.draw.eyePosWidth          = 8;        % eye position indicator width in pixels
p.draw.gridSpacing          = 2;        % experimenter display grid spacing (in degrees).
p.draw.gridW                = 2;        % grid spacing in degrees
p.draw.joyRect              = [1705 900 1735 1100]; % experimenter-display joystick indicator rectangle.
p.draw.cursorW              = 6;        % cursor width in pixels

%% WHAT TO STROBE:
% here lies a list of variables we wish to strobe at the end of every
% trial (this is in addition to the time-sensitive strobes that get strobed 
% suring the run function!).
% The function pds.strobeVars takes this list and strobes a number that 
% identifies the variable, immidiately followed by its value.
% eg

p.init.strobeList = {...
    %--- basic information ---
    'taskCode',         'p.init.taskCode'; ...
    'date_1yyyy',       'p.init.date_1yyyy'; ...
    'date_1mmdd',       'p.init.date_1mmdd'; ...
    'time_1hhmm',       'p.init.time_1hhmm'; ...

    % --- Core Trial Information ---
    'trialCode',        'p.init.trialsArray(p.trVars.currentTrialsArrayRow, find(strcmp(p.init.trialArrayColumnNames, ''trialCode'')))'; ...
    'blockNumber',      'ceil(p.init.trialsArray(p.trVars.currentTrialsArrayRow, find(strcmp(p.init.trialArrayColumnNames, ''halfBlock''))) / 2)'; ...
    'rewardDuration',   'p.trVars.rewardDurationMs'; ...
    'trialCount',       'p.status.iTrial'; ...
    'goodTrialCount',   'p.status.iGoodTrial'; ...
    'vissac',           'p.trVars.isVisSac'; ...
    'targetTheta',      'p.trVars.targTheta_x10'; ...
    'targetRadius',     'p.trVars.targRadius_x100'; ...
    'rewardDuration',   'p.trVars.rewardDurationMs'; ...

    % --- Factorial Design Variables (strobed directly from the trial array) ---
    'halfBlock',        'p.init.trialsArray(p.trVars.currentTrialsArrayRow, find(strcmp(p.init.trialArrayColumnNames, ''halfBlock'')))'; ...
    'targetLocIdx',     'p.init.trialsArray(p.trVars.currentTrialsArrayRow, find(strcmp(p.init.trialArrayColumnNames, ''targetLocIdx'')))'; ...
    'stimType',         'p.init.trialsArray(p.trVars.currentTrialsArrayRow, find(strcmp(p.init.trialArrayColumnNames, ''stimType'')))'; ...
    'salience',         'p.init.trialsArray(p.trVars.currentTrialsArrayRow, find(strcmp(p.init.trialArrayColumnNames, ''salience'')))'; ...
    'reward',           'p.init.trialsArray(p.trVars.currentTrialsArrayRow, find(strcmp(p.init.trialArrayColumnNames, ''reward'')))'; ...
    'targetColor',      'p.init.trialsArray(p.trVars.currentTrialsArrayRow, find(strcmp(p.init.trialArrayColumnNames, ''targetColor'')))'; ...
    };

end
