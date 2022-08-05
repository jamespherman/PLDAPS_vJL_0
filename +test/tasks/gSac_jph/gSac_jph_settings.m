function p = gSac_jph_settings
%  p = gSac_jph_settings
%
%   gSac_jph task
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
% p.audio;          % all things audio related
% p.draw;           % all widths/hieghts/etc of stuff that's drawn. (all except for stimulus, which is saved uniquely in stim struct)
% p.state           % all the states that we use and their id integer
% p.trVarsInit;     % all vars used in pldaps. here intiailized.
% p.trVars;         % all vars used in run function inherit value from trVarsInit.
% p.trVarsGuiComm;  % inheritance and user update of trVars happens through this struct, the trial variables gui coomunication
% p.trData;         % all data collected in a trial (behavior, timing, analog..)


%% p.init:
p = struct;

% rigConfigFile has information per a particular rig/monkey setup. Info you
% might expect to find inlcudes screen dimensions, screen refresh rate, 
% joystick voltages, datapixx schedules, and many more...
p.init.rigConfigFile     =  which('rigConfigFiles.rigConfig_ramsey_rigF_20190517'); % rig config file has subject/rig-specific details (eg distance from screen)


%% define task name and related files:

p.init.taskName     = 'gSac_jph';
p                   = pds.initTaskMetadata(p); 
% p.init.pldapsFolder     = pwd;                          % pldaps gui takes us to taks folder automatically once we choose a settings file
% p.init.protocol_title   = [p.init.taskName '_task'];    % Define Banner text to identify the experimental protocol
% p.init.date             = datestr(now,'yyyymmdd');
% p.init.time             = datestr(now,'HHMM');
% 
% % output files:
% p.init.outputFolder     = fullfile(p.init.pldapsFolder, 'output');
% p.init.sessionId        = [p.init.date '_t' p.init.time '_' p.init.taskName];     % Define the prefix for the Output File
% p.init.sessionFolder    = fullfile(p.init.outputFolder, p.init.sessionId);
% 
% 
% % Define the "init", "next", "run", and "finish" ".m" files.
% p.init.taskFiles.init   = [p.init.taskName '_init.m'];
% p.init.taskFiles.next   = [p.init.taskName '_next.m'];
% p.init.taskFiles.run    = [p.init.taskName '_run.m'];
% p.init.taskFiles.finish = [p.init.taskName '_finish.m'];

%% Define the Action M-files
% User-defined actions that are either within the task folder under
% "actions" or within the +pds package under "actions":
p.init.taskActions{1} = 'pdsActions.dataToWorkspace';
p.init.taskActions{2} = 'pdsActions.blackScreen';
p.init.taskActions{3} = 'pdsActions.alphaBinauralBeats';
p.init.taskActions{4} = 'pdsActions.stopAudioSchedule';
p.init.taskActions{5} = 'pdsActions.rewardDrain';

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
    'iTarget'};

%% user determines the 12 variables are shown in gui upon init
% here you just list the vars you want to see. You do not set them, yet.
% Setting them takes place below in the appropriate section.
% The list of vars should be in string format eg 'p.trVarsInit.cueDelta'

p.rig.guiVars = {...
    'joyPressVoltDirection';...
    'fixDegX'; ...          
    'fixDegY'; ...
    'rewardDurationMs'; ...       
    'propVis'; ...
    'fixWinHeightDeg'; ...
    'fixWinWidthDeg'; ...
    'targWinHeightDeg'; ...
    'targWinWidthDeg'; ...
    'rewardDelay'; ...        % 6
    'passEye'; ...
    'passJoy'};              % 12



%% INIT VARIABLES 
% vars that are only set once

p.init.exptType         = 'all_locs';  % Which experiment are we running? The full version with all trial types? The single-stimulus-only version? Something else?
% p.init.exptType         = 'two_locs';  % Which experiment are we running? The full version with all trial types? The single-stimulus-only version? Something else?

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

% how to set the next target location (via mouse, gui, or neither). If
% neither, then they get set at random from the predefined grid.
p.trVarsInit.setTargLocViaMouse         = false;
p.trVarsInit.setTargLocViaGui           = true;
p.trVarsInit.setTargLocViaTrialArray    = false;

% geometry/stimulus vars:
p.trVarsInit.propVis             = 1;  % proportion of visually-guided saccades out of the total (i.e. propMem would equal 1 - pVis )
p.trVarsInit.fixDegX             = 0;    % fixation X location in degrees
p.trVarsInit.fixDegY             = 0;    % fixation Y location in degrees
p.trVarsInit.targDegX            = 0;
p.trVarsInit.targDegY            = 0;

% times/latencies/durations:
p.trVarsInit.rewardDurationMs        = 150; % reward duration
p.trVarsInit.rewardDelay             = 0;        % delay between cued change and reward delivery for hits.
p.trVarsInit.timeoutAfterFa          = 2;        % timeout duration following false alarm.
p.trVarsInit.joyWaitDur              = 15;        % how long to wait for the subject to press the joystick at the beginning of a trial?
p.trVarsInit.fixWaitDur              = 1;        % how long to wait after initial joystick press for the subject to acquire fixation?
p.trVarsInit.freeDur                 = 0;        % time before start of joystick press check
p.trVarsInit.trialMax                = 15;       % max length of the trial
p.trVarsInit.joyReleaseWaitDur       = 3;        % how long to wait after trial end to start flickering the screen if the joystick hasn't been released
p.trVarsInit.stimFrameIdx            = 1;        % stimulus (eg dots) frame display index
p.trVarsInit.flipIdx                 = 1;        % index of
p.trVarsInit.postRewardDuration      = 0.25;     % how long should the trial last AFTER reward delivery? This lets us record the neuronal response to reward.
p.trVarsInit.joyPressVoltDir         = 1;

p.trVarsInit.targetFlashDuration     = 0.2;      % Duration target stays on for the memory-guided trials.
% p.trVarsInit.postFlashFixMin       = 1;    % minimum post-flash fixation-duration
% p.trVarsInit.postFlashFixMax       = 1.5;  % maximum post-flash fixation-duration
p.trVarsInit.targHoldDurationMin     = 0.5;  % minimum duration to maintain fixation on the target post-saccade 
p.trVarsInit.targHoldDurationMax     = 0.7;      % maximum duration to maintain fixation on the target post-saccade 
p.trVarsInit.maxSacDurationToAccept  = 0.1; % this is the max duration of a saccades that we're willing to wait for. 
p.trVarsInit.goLatencyMin            = 0.1;  % minimum saccade-latency criterion
p.trVarsInit.goLatencyMax            = 0.5;  % maximum saccade-latency criterion
% p.trVarsInit.preTargMin            = 0.75; % minimum fixation-only time before target onset
% p.trVarsInit.preTargMax            = 1;    % maximum fixation-only time before target onset
p.trVarsInit.targOnsetMin            = 0.75; % minimum fixation-only time before target onset
p.trVarsInit.targOnsetMax            = 1;
p.trVarsInit.goTimePostTargMin       = 1; % min duration from targ onset to the 'go' signal to saccade (which is fixation offset)
p.trVarsInit.goTimePostTargMax       = 2; % max duration from targ onset to the 'go' signal to saccade (which is fixation offset)

p.trVarsInit.maxFixWait              = 5;    % maximum time to wait for fixation-acquisition
p.trVarsInit.targOnSacOnly           = 1;    % condition target reappearance on saccade?
p.trVarsInit.rwdTime                 = -1;

% if we're training the animal to make memory guided sacacdes, we'll delay
% the onset of the target after fixation offset without making it saccade
% contingent. What should this delay be?
p.trVarsInit.targTrainingDelay       = 0;
p.trVarsInit.timeoutdur              = 0.275;    % how long to time-out after an error-trial (in seconds)?
p.trVarsInit.minTargAmp              = 2.5;    % minimum target amplitude
p.trVarsInit.maxTargAmp              = 18;   % maximum target amplitude
p.trVarsInit.staticTargAmp           = 12;  % fixed target amplitude
p.trVarsInit.maxHorzTargAmp          = 20;  % when using the "rectangular annulus" method of specifying target locations, we need separate horizontal and vertical max amps
p.trVarsInit.maxVertTargAmp          = 12;  % "rectangular annulus" method of specifying target amplitude
        
p.trVarsInit.fixWinWidthDeg       = 3;        % fixation window width in degrees
p.trVarsInit.fixWinHeightDeg      = 3;        % fixation window height in degrees
p.trVarsInit.targWinWidthDeg      = 4;        % target window width in degrees
p.trVarsInit.targWinHeightDeg     = 4;        % target window height in degrees


% I don't think I need to carry these around in 'p'....
% can't I just define them in the 'run' worksapce and forget avbout them?
p.trVarsInit.currentState     = p.state.trialBegun;  % initialize "state" variable.
p.trVarsInit.exitWhileLoop    = false;  % do we want to exit the "run" while loop?

p.trVarsInit.targetIsOn = false;

p.trVarsInit.postMemSacTargOn = false;  % do we want the target on because a memory guided saccade has been successfully completed?

% variables related to online tracking of gaze position / velocity
p.trVarsInit.whileLoopIdx           = 0;    % numerical index to current iteration of run while-loop
p.trVarsInit.eyeVelFiltTaps         = 5;    % length in samples of online velocity filter
p.trVarsInit.eyeVelThresh           = 25;   % threshold in deg/s for online saccade detection
p.trVarsInit.useVelThresh           = true; % does the experimenter want to use the velocity threshold to check saccade onset / offset?
p.trVarsInit.eyeVelThreshOffline    = 10;   % gaze velocity threshold in deg/s for offline saccade detection (cleaner signal, lower threshold).

p.trVarsInit.connectPLX             = false;

%% end of trVarsInit
% once all trial variables have been initialized in trVarsInit, we copy 
% them to 'trVarsGuiComm' in order to inform the gui. 
% trVarsGuiComm's sole purpose is to communicate between the gui and the 
% trVars that inherit its contents on every trial. Thus, user may change
% things in gui (which effectively chagnes the trVarsGuiComm) that then
% (in the 'next' function) updates the trVars!

p.trVarsGuiComm = p.trVarsInit;


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


%% CLUT - Color Look Up Table
% the CLUT gets initialized in the _init file, but here I set verbal
% identifiers that may be used. 
% The integer number here indicates a row in the CLUT (see initClut.m)
% (format is 'expColor_subColor' where 'exp' stands for experimenter, 'sub' 
% for subject clut ('Bg' = background)

p.draw.clutIdx.expBlack_subBlack         = 0;
p.draw.clutIdx.expGrey25_subBg           = 1;
p.draw.clutIdx.expBg_subBg               = 2;
p.draw.clutIdx.expGrey70_subBg           = 3;
p.draw.clutIdx.expWhite_subWhite         = 4;
p.draw.clutIdx.expRed_subBg              = 5;
p.draw.clutIdx.expOrange_subBg           = 6;
p.draw.clutIdx.expBlue_subBg             = 7;
p.draw.clutIdx.expCyan_subCyan           = 8;
p.draw.clutIdx.expGrey90_subBg           = 9;
p.draw.clutIdx.expMutGreen_subBg         = 10;
p.draw.clutIdx.expGreen_subBg            = 11;
p.draw.clutIdx.expBlack_subBg            = 12;
p.draw.clutIdx.expOldGreen_subOldGreen   = 13;
p.draw.clutIdx.expVisGreen_subBg         = 14;
p.draw.clutIdx.expMemMagenta_subBg       = 15;
p.draw.clutIdx.expCyan_subBg             = 16;

%% COLORS 
% here we just init them. They get updated in the run function as a 
% function of state- and time-machines. 
% each color is assigned a row in the CLUT (see initClut.m), based on the
% CLUT section above.
p.draw.color.background     = p.draw.clutIdx.expBg_subBg;                   % background CLUT index
p.draw.color.cursor         = p.draw.clutIdx.expOrange_subBg;               % cursor CLUT index
p.draw.color.fix            = p.draw.clutIdx.expBg_subBg;                   % fixation CLUT index
p.draw.color.fixWin         = p.draw.clutIdx.expBg_subBg;                   % fixation window CLUT index
p.draw.color.targ           = p.draw.clutIdx.expWhite_subWhite;             % fixation CLUT index
p.draw.color.targWin        = p.draw.clutIdx.expBg_subBg;                   % fixation window CLUT index
p.draw.color.eyePos         = p.draw.clutIdx.expBlue_subBg;                 % eye position indicator CLUT index
p.draw.color.gridMajor      = p.draw.clutIdx.expGrey90_subBg;               % grid line CLUT index
p.draw.color.gridMinor      = p.draw.clutIdx.expGrey70_subBg;               % grid line CLUT index
p.draw.color.cueRing        = p.draw.clutIdx.expOldGreen_subOldGreen;       % fixation window CLUT index
p.draw.color.joyInd         = p.draw.clutIdx.expGrey90_subBg;               % joy position indicator CLUT index
p.draw.color.mouseCursor    = p.draw.clutIdx.expCyan_subBg;                % mouse cursor

%% draw - these are paramters used for drawing
% the boring stuff, like width and height of stuff that gets drawn.

% fixation point and fixation point win:
p.draw.fixPointWidth        = 4;        % fixation point indicator line width in pixels
p.draw.fixPointRadius       = 6;        % fixation point "radius" in pixels
p.draw.fixWinPenThin        = 4;        % fixation window width (prior to 'go' signal).
p.draw.fixWinPenThick       = 8;        % fixation window width (post 'go' signal).
p.draw.fixWinPenDraw        = [];       % gets assigned either the pre or the post during the run function 

% target and target win:
p.draw.targWidth            = 4;        % fixation point indicator line width in pixels
p.draw.targRadius           = 6;        % fixation point "radius" in pixels
p.draw.targWinPenThin       = 4;        % fixation window width (prior to 'go' signal).
p.draw.targWinPenThick      = 8;        % fixation window width (post 'go' signal).
p.draw.targWinPenDraw       = [];       % gets assigned either the pre or the post during the run function

% others:
p.draw.eyePosWidth          = 6;        % eye position indicator width in pixels
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
    'taskCode',         'p.init.taskCode'; ...
    'date_1yyyy',       'p.init.date_1yyyy'; ...
    'date_1mmdd',       'p.init.date_1mmdd'; ...
    'time_1hhmm',       'p.init.time_1hhmm'; ...
    'connectPLX', 'p.trVars.connectPLX'; ...
    'vissac', 'p.trVars.isVisSac'; ...
    'targetTheta', 'p.trVars.targTheta_x10'; ...
    'targetRadius', 'p.trVars.targRadius_x100'; ...
    'rewardDuration', 'p.trVars.rewardDurationMs'; ...
    'trialCount', 'p.status.iTrial'; ...
    'goodTrialCount', 'p.status.iGoodTrial'; ...
    };


end
