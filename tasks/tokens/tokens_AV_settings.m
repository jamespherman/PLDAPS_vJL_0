function p = tokens_AV_settings
%  p = tokens_AV_settings
%
%  "scd" - stimulus change detection; stimuli have multiple feature
%  dimensions, each of which can change.
%
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

% need to set "useDataPixxBool" to true in all settings files. We really
% need to change how we do this in general. There should be a some master
% list of settings that are required for all tasks to run correctly that
% get set in every settings file without the need to duplicate lines of
% code across all settings files, and separately a list of settings that is
% task-specific (JPH - 05/25/2023).
p.init.useDataPixxBool = true;

%% define task name and related files:

p.init.taskName         = 'tokens';
p.init.taskType         = 1;                            % poorly defined numerical index for the task "type"
p.init.pldapsFolder     = pwd;                          % pldaps gui takes us to taks folder automatically once we choose a settings file
p.init.protocol_title   = [p.init.taskName '_task'];    % Define Banner text to identify the experimental protocol
p.init.date             = datestr(now,'yyyymmdd');
p.init.time             = datestr(now,'HHMM');

p.init.date_1yyyy       = str2double(['1' datestr(now,'yyyy')]); % gotta add a '1' otherwise date/times starting with zero lose that zero in conversion to double.
p.init.date_1mmdd       = str2double(['1' datestr(now,'mmdd')]);
p.init.time_1hhmm       = str2double(['1' datestr(now,'HHMM')]);

% output files:
p.init.outputFolder     = fullfile(p.init.pldapsFolder, 'output');
p.init.figureFolder     = fullfile(p.init.pldapsFolder, 'output', 'figures');
p.init.sessionId        = [p.init.date '_t' p.init.time '_' p.init.taskName];     % Define the prefix for the Output File
p.init.sessionFolder    = fullfile(p.init.outputFolder, p.init.sessionId);

% Define the "init", "next", "run", and "finish" ".m" files.
p.init.taskFiles.init   = [p.init.taskName '_init.m'];
p.init.taskFiles.next   = [p.init.taskName '_next.m'];
p.init.taskFiles.run    = [p.init.taskName '_run.m'];
p.init.taskFiles.finish = [p.init.taskName '_finish.m'];

%% Define the Action M-files
% User-defined actions that are either within the task folder under
% "actions" or within the +pdsActions:
p.init.taskActions{1} = 'pdsActions.dataToWorkspace';
p.init.taskActions{2} = 'pdsActions.blackScreen';
p.init.taskActions{3} = 'pdsActions.alphaBinauralBeats';
p.init.taskActions{4} = 'pdsActions.stopAudioSchedule';
p.init.taskActions{5} = 'pdsActions.rewardDrain';
p.init.taskActions{6} = 'pdsActions.singleReward';
p.init.taskActions{7} = 'pdsActions.catOldOutput';

p.init.trialsPerCondition = 100; % The number of repetitions of each condition WITHIN a single block


%% audio:
p.audio.audsplfq        = 48000; % datapixx audio playback sampling rate.
p.audio.Hitfq           = 600;   % frequency for "high" (hit) tone.
p.audio.Missfq          = 100;   % frequency for "low" (miss) tone.
p.audio.auddur          = 4800;  % duration in samples for tones.
p.audio.lineOutLevel    = 0.4;   % datapixx line out audio level [0 - 1].
p.audio.pcPlayback      = false;  % do we want audio playback from psychtoolbox PC?

%% STATES
% The state machine uses these values to transition through the trial.

% --- Transition States ---
% These are the states that make up the flow of a trial.
p.state.trialBegun      = 1;
p.state.waitForITI      = 2;
p.state.showCue         = 3;
p.state.waitForFix      = 4;
p.state.holdFix         = 5;
p.state.showOutcome     = 6;
p.state.cashInTokens    = 7;

% --- End States (Aborted) ---
% These states are reached when a trial ends prematurely due to error.
p.state.fixBreak        = 11; % Monkey looked away during holdFix
p.state.nonStart        = 12; % Monkey never acquired fixation

% --- End States (Success) ---
% This state is reached when a trial is completed successfully.
p.state.success         = 21;

%% STATUS VALUES

p.status.iTrial                     = 0; % ITERATOR for current trial count
p.status.iGoodTrial                 = 0; % count of all trials that have ended in hit, miss, cr, foil fa (no fix or joy breaks, no fa)
p.status.trialsLeftInBlock          = 0; % how many trials remain in the current block?
p.status.blockNumber                = 0; % what block are we in?
p.status.fixDurReq                  = 0; % how long was the monkey required to hold down the joystick on the last trial?
p.status.missedFrames               = 0; % count of missed frames as reported by psychtoolbox
p.status.lastTrialEndTime = 0;

p.status.trialsArrayRowsPossible    = [];
p.status.repeatLast                 = false;
p.status.lastTrialRow               = 0;

p.rig.guiStatVals = {...
    'blockNumber'; ...
    'iTrial'; ...   
    'iGoodTrial'; ...
    'trialsLeftInBlock'; ...
    'fixDurReq'; ...
%     'missedFrames'; ...
    };    

%% user determines the 12 variables are shown in gui upon init
% here you just list the vars you want to see. You do not set them, yet.
% Setting them takes place below in the appropriate section.
% The list of vars should be in string format eg 'p.trVarsInit.cueDelta'

p.rig.guiVars = {...
    'fixDur'; ...   %1
    'rewardDurationMs'; ...
    'juicePause'; ...
    'outcomeDelay'; ...
    'itiMean'; ...
    'itiMin'; ...       % 6
    'itiMax'; ...
    'tokenBaseX'; ...
    'tokenBaseY'; ...
    'passJoy'; ...          
    'passEye'; ...
    'tokenBaseX'; ...
    'tokenBaseY'; ...
    'tokenSpacing'};


%% INIT VARIABLES 
% vars that are only set once

p.init.exptType         = 'tokens_AV';  % Which experiment are we running? The full version with all trial types? The single-stimulus-only version? Something else?


%% TRIAL VARIABLES
% vars that may change throughout an experimental session and are therefore
% saved on every trial. 
% Here we define 'trVarsInit' as this is the default. However, user may
% change any variable through the gui (which updates 'trVarsGuiComm) and
% then updates 'trVars' during the run function. 
% 'trVars' is the key strcutarray that gets saved on every trial.

% general vars:
p.trVarsInit.passJoy             = 1;       % pass = 1; simulate correct trials (for debugging)
p.trVarsInit.passEye             = 0;       % pass = 1; simulate correct trials (for debugging)
p.trVarsInit.blockNumber         = 0;       % block number
p.trVarsInit.repeat              = 0;       % repeat trial if true
p.trVarsInit.rwdJoyPR            = 0;       % 0 = Give reward if Joy is pressed; 1 = Give reward if Joystick released
p.trVarsInit.finish              = 5000;
p.trVarsInit.filesufix           = 1;       % save to file sufix
p.trVarsInit.joyVolt             = 0;
p.trVarsInit.eyeDegX             = 0;
p.trVarsInit.eyeDegY             = 0;
p.trVarsInit.eyePixX             = 0;
p.trVarsInit.eyePixY             = 0;
p.trVarsInit.fixDegX             = 0;           % fixation X location in degrees
p.trVarsInit.fixDegY             = 0;           % fixation Y location in degrees

% -- Fixation Parameters
p.trVarsInit.fixDur = 0.5;                  % Fixation hold duration in seconds, from fixdur = 500 [cite: 1]
p.trVarsInit.fixAqDur = 10;                 % Time allowed to acquire fixation in seconds[cite: 1].
p.trVarsInit.fixWinWidthDeg     = 2.0;
p.trVarsInit.fixWinHeightDeg    = 2.0;

% -- Reward Parameters
p.trVarsInit.rewardDurationMs = 65;         % Juice pulse duration in ms [cite: 1]
p.trVarsInit.juicePause = 0.5;              % Pause after each juice delivery in seconds, from juice_pausetime = 500 [cite: 1]
p.trVarsInit.outcomeDelay = 1.0;            % Pause before "cashing in" tokens, from idle(1000) [cite: 1]
p.trVarsInit.tokenI = 1;

% -- Inter-Trial Interval (ITI) Parameters
p.trVarsInit.itiMean = 3.0; % seconds
p.trVarsInit.itiMin = 1.0;  % seconds
p.trVarsInit.itiMax = 5.0;  % seconds

p.trVarsInit.tokenBaseX = -10;
p.trVarsInit.tokenBaseY = 8;
p.trVarsInit.tokenSpacing = 2;

% -- Token Stimulus Parameters
% From the crc() definitions in the .txt file [cite: 2]
p.stim.token.radius = 0.7; % Radius in degrees of visual angle [cite: 2]
p.stim.token.color = [0.458 1 1]; % Token color [cite: 2]
% Token positions in degrees [X,Y] [cite: 2]

% Number of frames each flicker color is displayed for.
p.trVarsInit.flickerFramesPerColor = 6;

% I don't think I need to carry these around in 'p'....
% can't I just define them in the 'run' worksapce and forget avbout them?
p.trVarsInit.currentState     = p.state.trialBegun;  % initialize "state" variable.
p.trVarsInit.exitWhileLoop    = false;  % do we want to exit the "run" while loop?

p.trVarsInit.fixWinWidthDeg       = 6;        % fixation window width in degrees
p.trVarsInit.fixWinHeightDeg      = 6;        % fixation window height in degrees
p.trVarsInit.fixPointRadPix       = 20;       % fixation point "radius" in pixels
p.trVarsInit.fixPointLinePix      = 12;       % fixation point line weight in pixels

% variables related to how the experiment is run / what is shown, etc.
p.trVarsInit.useCellsForDraw        = false;
p.trVarsInit.wantEndFlicker         = false;    % have screen flicker / low tone play repeatedly while waiting for joystick release?
p.trVarsInit.wantOnlinePlots        = false;     % use online plotting window?

% substructure for marking stimulus-events after each flip
p.trVarsInit.postFlip.logical         = false;
p.trVarsInit.postFlip.varNames        = cell(0);
p.trVarsInit.flipIdx                  = 1;

% Add this to tokens_settings.m

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
    'p.trData.onlineEyeX',              '[]'; ...
    'p.trData.onlineEyeY',              '[]'; ...
    'p.trData.timing.lastFrameTime',    '0'; ...    % time at which last video frame was displayed
    'p.trData.timing.fixOn',            '-1'; ...   % time of fixation onset
    'p.trData.timing.fixAq',            '-1'; ...   % time of fixation acquisition
    'p.trData.timing.stimOn',           '-1'; ...   % time of stimulus onset
    'p.trData.timing.stimOff',          '-1'; ...   % time of stimulus offset
    'p.trData.timing.fixBreak',         '-1'; ...   % time of fixation break
    'p.trData.timing.cueOn',            '-1'; ...   % time of cue onset
    'p.trData.timing.reward',           '-1'; ...   % time of reward delivery
    'p.trData.timing.trialEnd',         '-1'; ...   % time of trial end
    'p.trData.timing.outcomeOn',        '-1'; ...   % time of outcome onset
    };

% since the list above is fixed, count its rows now for looping over later.
p.init.nTrDataListRows                  = size(p.init.trDataInitList, 1);

%% draw - these are paramters used for drawing
% the boring stuff, like width and height of stuff that gets drawn - NOTE,
% variables defined here are retained for the duration of the experiment,
% they can't be changed from trial-to-trial in the GUI.
p.draw.eyePosWidth          = 6;        % eye position indicator width in pixels
p.draw.fixPointWidth        = 4;        % fixation point indicator line width in pixels
p.draw.fixPointRadius       = 6;        % fixation point "radius" in pixels
p.draw.fixWinPenPre         = 4;        % fixation window width (prior to change).
p.draw.fixWinPenPost        = 8;        % fixation window width (after change).
p.draw.fixWinPenDraw        = [];       % gets assigned either the pre or the post during the run function 
p.draw.gridSpacing          = 2;        % experimenter display grid spacing (in degrees).
p.draw.gridW                = 2;        % grid spacing in degrees
p.draw.joyRect              = [1705 900 1735 1100]; % experimenter-display joystick indicator rectangle.
p.draw.cursorW              = 6; % cursor width in pixels

%% datapixx - vars related to datapixx schedule settings

p.rig.dp.useDataPixxBool       = 1;        % using datapixx
p.rig.dp.adcRate               = 1000;     % define ADC sampling rate (Hz).
p.rig.dp.maxDurADC             = 15;       % what is the maximum duration to preallocate for ADC buffering?
p.rig.dp.adcBuffAddr           = 4e6;      % VIEWPixx / DATAPixx internal ADC memory buffer address.
p.rig.dp.dacRate               = 1000;     % define DAC sampling rate (Hz);
p.rig.dp.dacPadDur             = 0.01;     % how much time to pad the DAC +4V with +0V?
p.rig.dp.dacBuffAddr           = 10e6;     % DAC buffer base address
p.rig.dp.dacChannelOut         = 0;        % Which channel to use for DAC outpt control of reward system.

%% stimulus-specific (and static over the course of an experiment):
% here we have motion related vars but if your stimulus is of different
% nature, by all means.
% While some stim vars go above in trVArsInit (e.g stimRadius) here I
% placed the lower level stim vars that are unlikely to be changed in the
% course of an experiment.

%% CLUT - Color Look Up Table
% the CLUT gets initialized in the _init file, but here we set character
% string identifiers that may be used for ease. Integer number here
% refers to a row in the CLUT (see initClut.m); format is:
% 'expColor_subColor' where 'exp' stands for experimenter, 'sub' for 
% subject clut ('Bg' = background)

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

%% COLORS 
% here we just init them. They get updated in the run function as a 
% function of state- and time-machines. 
% each color is assigned a row in the CLUT (see initClut.m), based on the
% CLUT section above.
p.draw.color.background = p.draw.clutIdx.expBg_subBg;                   % background CLUT index
p.draw.color.cursor     = p.draw.clutIdx.expOrange_subBg;               % cursor CLUT index
p.draw.color.fix        = p.draw.color.background;                      % fixation CLUT index
p.draw.color.fixWin     = p.draw.clutIdx.expGrey25_subBg;               % fixation window CLUT index
p.draw.color.cueDots    = p.draw.clutIdx.expWhite_subWhite;             % cue dots CLUT index
p.draw.color.foilDots   = p.draw.clutIdx.expWhite_subWhite;             % foil CLUT index
p.draw.color.eyePos     = p.draw.clutIdx.expBlue_subBg;                 % eye position indicator CLUT index
p.draw.color.gridMajor  = p.draw.clutIdx.expGrey25_subBg;               % grid line CLUT index
p.draw.color.gridMinor  = p.draw.clutIdx.expGrey25_subBg;               % grid line CLUT index
p.draw.color.cueRing    = p.draw.clutIdx.expWhite_subWhite;             % fixation window CLUT index
p.draw.color.joyInd     = p.draw.clutIdx.expGrey90_subBg;               % joy position indicator CLUT index


%% WHAT TO STROBE:
% here lies a list of variables we wish to strobe at the end of every
% trial (this is in addition to the time-sensitive strobes that get strobed 
% suring the run function!).
% The function pds.strobeVars takes this list and strobes a number that 
% identifies the variable, immidiately followed by its value.
% eg

p.init.strobeList = fliplr({...                 
    'p.init.date_1yyyy',                                                                                        'date_1yyyy'; ...        
    'p.init.date_1mmdd',                                                                                        'date_1mmdd'; ...      
    'p.init.time_1hhmm',                                                                                        'time_1hhmm'; ...
    'p.init.codes.REWARD_AMOUNT_BASE + p.trVars.rewardAmt',                                                     'REWARD_AMOUNT_BASE'; ...
    'p.trVars.rewardAmt',                                                                                       'rwdAmt'; ...
    'p.init.codes.uniqueTaskCode_tokens',                                                                       'taskCode'; ...
    'p.status.iTrial',                                                                                          'trialCount'; ...
    'p.init.trialsArray(p.trVars.currentTrialsArrayRow, strcmp(p.init.trialArrayColumnNames, ''trialCode''))',  'trialCode'; ...
    });
end
