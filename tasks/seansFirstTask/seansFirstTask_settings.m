function p = seansFirstTask_settings
%  p = seansFirstTask_settings
%
%   seansFirstTask task
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

% need to set "useDataPixxBool" to true in all settings files. We really
% need to change how we do this in general. There should be a some master
% list of settings that are required for all tasks to run correctly that
% get set in every settings file without the need to duplicate lines of
% code across all settings files, and separately a list of settings that is
% task-specific (JPH - 05/25/2023).
p.init.useDataPixxBool = true;

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

% define task name and related files:
p.init.taskName     = 'seansFirstTask';
p                   = pds.initTaskMetadata(p); % ye ye I know, shouldn't this be in init? well it's here. For now...


% Define the Action M-files
% User-defined actions that are either within the task folder under
% "actions" or within the +pds package under "actions":
p.init.taskActions{1} = 'pdsActions.dataToWorkspace';
p.init.taskActions{2} = 'pdsActions.blackScreen';
p.init.taskActions{3} = 'pdsActions.alphaBinauralBeats';
p.init.taskActions{4} = 'pdsActions.stopAudioSchedule';
p.init.taskActions{5} = 'pdsActions.rewardDrain';


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

p.status.iTrial                     = 0; % ITERATOR for current trial count
p.status.iGoodTrial                 = 0; % 
p.status.iGoodVis                 = 0; % 
p.status.iGoodMem                 = 0; % 
p.status.pGoodVis                   = 0; % proportion good (ie successfuly completed) visually guided
p.status.pGoodMem                   = 0; % proportion good (ie successfuly completed) memory guided
p.status.iTarget                    = 1; % iterator into the list of target locations (defined in _init). Used when multiple locations are predeteremined (e.g. a grid of targets).  
p.status.trialsLeftInBlock          = 0; % how many trials remain in the current block?

p.status.iGoodOneTargetOneDot		    = 0;
p.status.iGoodOneTargetTwoDots		    = 0;

p.status.iGoodTwoTargetOneDot		    = 0;
p.status.iGoodTwoTargetTwoDots		    = 0;



p.rig.guiStatVals = {...
    'iTrial'; ...   
    'iGoodTrial'; ...
    'iGoodVis'; ...
    'iGoodMem'; ...
    'pGoodVis'; ...
    'pGoodMem'; ...
    'iTarget'; ...
    'trialsLeftInBlock'; ...       
};              

%% user determines the 12 variables are shown in gui upon init
% here you just list the vars you want to see. You do not set them, yet.
% Setting them takes place below in the appropriate section.
% The list of vars should be in string format eg 'p.trVarsInit.cueDelta'

p.rig.guiVars = {...
    'mouseEyeSim';...
    'passJoy'; ...          
    'passEye'; ...
    'rewardDurationMs'; ...       
    'propVis'; ...
    'fixWinHeightDeg'; ...
    'fixWinWidthDeg'; ...
    'targWinHeightDeg'; ...
    'targWinWidthDeg'; ...
    'rewardDelay'; ...        % 6
    'fixDegX'; ...
    'fixDegY'};              % 12



%% INIT VARIABLES 
% vars that are only set once

% Which experiment are we running? The full version with all trial types? 
% The single-stimulus-only version? Something else?
p.init.exptType         = 'step1';

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
p.trVarsInit.joyPressVoltDir        = 1;    % 1=pressing reduces voltage; 2=pressing increases voltage
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
p.trVarsInit.mouseEyeSim            = 1;

% how to set the next target location (via mouse, gui, or neither). If
% neither, then they get set at random from the predefined grid.
p.trVarsInit.setTargLocViaMouse         = false;
p.trVarsInit.setTargLocViaGui           = false;
p.trVarsInit.setTargLocViaTrialArray    = false;

% p.trVarsInit.ratioShowBothTargs	 = 0.8; % Proportion of trials in which both targets are shown simultaneously

% geometry/stimulus vars:
p.trVarsInit.propVis             = 1;  % proportion of visually-guided saccades out of the total (i.e. propMem would equal 1 - pVis )
p.trVarsInit.fixDegX             = 0;    % fixation X location in degrees 
p.trVarsInit.fixDegY             = 0;    % fixation Y location in degrees
p.trVarsInit.targDegX            = 0;
p.trVarsInit.targDegY            = 5;
p.trVarsInit.numDots             = 0; % how many dots does the target stimulus have on this trial?
p.trVarsInit.twoTargSepDeg       = 1; % how far apart should the two target dots be? (in dva?)
p.trVarsInit.twoStimSepDegMin    = 1.8; % how far apart should the two stim dots be? (in dva?)
p.trVarsInit.twoStimSepDegMax    = 2;
p.trVarsInit.stimRangeRadius	 = 0; % create stimuli randomly within radius of __? (in pixels?)
p.trVarsInit.stimSizeMin	 = 15; % create stimuli of what size? (randomly chosen between min and max) (in pixels?)
p.trVarsInit.stimSizeMax	 = 20;
p.trVarsInit.stimRotationRange	 = 0; % Range within which stimulus is rotated (randomly chosen between 0 and given value, max 180).


% times/latencies/durations:
p.trVarsInit.rewardDurationMs        = 180; % reward duration
p.trVarsInit.rewardDelay             = 0;        % delay between cued change and reward delivery for hits.
p.trVarsInit.timeoutAfterFa          = 2;        % timeout duration following false alarm.
p.trVarsInit.joyWaitDur              = 5;        % how long to wait for the subject to press the joystick at the beginning of a trial?
p.trVarsInit.fixWaitDur              = 1;        % how long to wait after initial joystick press for the subject to acquire fixation?
p.trVarsInit.freeDur                 = 0;        % time before start of joystick press check
p.trVarsInit.trialMax                = 15;       % max length of the trial
p.trVarsInit.joyReleaseWaitDur       = 3;        % how long to wait after trial end to start flickering the screen if the joystick hasn't been released
p.trVarsInit.stimFrameIdx            = 1;        % stimulus (eg dots) frame display index
p.trVarsInit.flipIdx                 = 1;        % index of
p.trVarsInit.postRewardDuration      = 0.25;     % how long should the trial last AFTER reward delivery? This lets us record the neuronal response to reward.


p.trVarsInit.targetFlashDuration     = 0.2;      % Duration target stays on for the memory-guided trials.
% p.trVarsInit.postFlashFixMin       = 1;    % minimum post-flash fixation-duration
% p.trVarsInit.postFlashFixMax       = 1.5;  % maximum post-flash fixation-duration
p.trVarsInit.targHoldDurationMin     = 0.5;  % minimum duration to maintain fixation on the target post-saccade 
p.trVarsInit.targHoldDurationMax     = 0.7;      % maximum duration to maintain fixation on the target post-saccade 
p.trVarsInit.maxSacDurationToAccept  = 0.1; % this is the max duration of a saccades that we're willing to wait for. 
p.trVarsInit.targetReillumDelay      = 0.15; % the delay (s) between saccadeOffset (ie entry into target window) and target reillumination
p.trVarsInit.goLatencyMin            = 0.1;  % minimum saccade-latency criterion
p.trVarsInit.goLatencyMax            = 0.5;  % maximum saccade-latency criterion
% p.trVarsInit.preTargMin            = 0.75; % minimum fixation-only time before target onset
% p.trVarsInit.preTargMax            = 1;    % maximum fixation-only time before target onset

p.trVarsInit.stimOnsetMin	     = 0.3; % Time after fixation before stim comes on
p.trVarsInit.stimOnsetMax	     = 0.5;
p.trVarsInit.stimDurMin		     = 0.5; % Time stim stays on
p.trVarsInit.stimDurMax		     = 0.6;
p.trVarsInit.targOnsetMin            = 0.01; % Time after stim goes off before target onset
p.trVarsInit.targOnsetMax            = 0.02;
p.trVarsInit.goTimePostTargMin       = 0.3; % min duration from targ onset to the 'go' signal to saccade (which is fixation offset)
p.trVarsInit.goTimePostTargMax       = 0.8; % max duration from targ onset to the 'go' signal to saccade (which is fixation offset)

p.trVarsInit.maxFixWait              = 5;    % maximum time to wait for fixation-acquisition
p.trVarsInit.targOnSacOnly           = 1;    % condition target reappearance on saccade?
p.trVarsInit.rwdTime                 = -1;

% if we're training the animal to make memory guided sacacdes, we'll delay
% the onset of the target after fixation offset without making it saccade
% contingent. What should this delay be?
p.trVarsInit.targTrainingDelay       = 0;
p.trVarsInit.timeoutdur              = 0.275;    % how long to time-out after an error-trial (in seconds)?
p.trVarsInit.minTargAmp              = 3;    % minimum target amplitude
p.trVarsInit.maxTargAmp              = 18;   % maximum target amplitude
p.trVarsInit.staticTargAmp           = 12;  % fixed target amplitude

p.trVarsInit.fixWinWidthDeg       = 2;        % fixation window width in degrees
p.trVarsInit.fixWinHeightDeg      = 2;        % fixation window height in degrees
p.trVarsInit.targWinWidthDeg      = 3;        % target window width in degrees
p.trVarsInit.targWinHeightDeg     = 3;        % target window height in degrees


% I don't think I need to carry these around in 'p'....
% can't I just define them in the 'run' worksapce and forget avbout them?
p.trVarsInit.currentState     = p.state.trialBegun;  % initialize "state" variable.
p.trVarsInit.exitWhileLoop    = false;  % do we want to exit the "run" while loop?

p.trVarsInit.stimIsOn 	= false;
p.trVarsInit.targetIsOn = false;

p.trVarsInit.postMemSacTargOn = false;  % do we want the target on because a memory guided saccade has been successfully completed?

% variables related to online tracking of gaze position / velocity
p.trVarsInit.whileLoopIdx           = 0;    % numerical index to current iteration of run while-loop
p.trVarsInit.eyeVelFiltTaps         = 5;    % length in samples of online velocity filter
p.trVarsInit.eyeVelThresh           = 25;   % threshold in deg/s for online saccade detection
p.trVarsInit.useVelThresh           = true; % does the experimenter want to use the velocity threshold to check saccade onset / offset?
p.trVarsInit.eyeVelThreshOffline    = 10;   % gaze velocity threshold in deg/s for offline saccade detection (cleaner signal, lower threshold).

%% stimulus-specific:
% The 'stimulus' in this task is for target location.
% Target location is preset (e.g. on a grid or a ring or other) but can 
% be overriden and set via mouse location or gui.

% define your preset here, and then it's paramters, below. 
% The location of each target gets defined in 'initTargetLocationList'
p.stim.targLocationPreset = 'preset_quatro'; 

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
    
    case 'preset_quatro'
        x1 =  10;   y1 = 5;
        x2 = -6;    y2 =  -4;
        
        
        x_total = []; y_total = [];
        x_total = [x1 x2]; y_total = [y1 y2];
        
        target_n = [];
        
%         for target_n = 1: length(x_total)
%             
%             th = []; r = []; th_rotate = [];
%             
%             [th, r] = cart2pol(x_total(target_n), y_total(target_n));
%             
%             th = th/pi*180;
%             
%             if th >= 0 && th < 90
%                 th_rotate = th - 90;
%             elseif th >= 90 && th < 180
%                 th_rotate = th + 90;
%             elseif (th >= -180 && th < -90) || th ==180
%                 th_rotate = th - 90;
%             elseif th >= -90 && th < 0
%                 th_rotate = th + 90;
%             end
%             
%             [x_rotate(target_n), y_rotate(target_n)] = pol2cart(deg2rad(th_rotate), r);
%             
%         end
        
        for target_n = 1: length(x_total)
            
            [th, r] = cart2pol(x_total(target_n), y_total(target_n));

            if th == pi
                th_rotate = th + (7/16) * pi;
            elseif th >= 0 && th < pi/2
                th_rotate = th - pi/2;
            elseif th >= pi/2 && th < pi
                th_rotate = th + pi/2;
            elseif (th >= -pi && th < -pi/2) || th ==pi
                th_rotate = th - pi/2;
            elseif th >= -pi/2 && th < 0
                th_rotate = th + pi/2;
            end
            
            [x_rotate(target_n), y_rotate(target_n)] = pol2cart(th_rotate, r);
            
        end

        
%         p.stim.xy{1} = [x_total(1),  y_total(1)];
%         p.stim.xy{2} = [x_total(1),  y_total(1)];
%         p.stim.xy{3} = [x_rotate(1), y_rotate(1)];
%         p.stim.xy{4} = [x_total(2), y_total(2)];
%         p.stim.xy{5} = [x_total(2), y_total(2)];
%         p.stim.xy{6} = [x_rotate(2), y_rotate(2)];
        p.stim.xy{1} = [x_total(1),  y_total(1)];   % in RF 1
        p.stim.xy{2} = [x_rotate(1), y_rotate(1)];  % pair of RF 1
        p.stim.xy{3} = [x_total(2), y_total(2)];    % in RF 2
        p.stim.xy{4} = [x_rotate(2), y_rotate(2)];  % pair of RF 2
        
        % current hack: (would be better to set this in one place,
        % presently we set the value of "p.trVars.setTargLocViaTrialArray"
        % to FALSE (above) and then only set it to true IF we're in this
        % "IF" statement.
        p.trVarsInit.setTargLocViaTrialArray = true;
end

% targets are usually dots, but it could be a patch, image, anything.
p.stim.dotWidth              = 6;        % dot width

%% end of trVarsInit
% once all trial variables have been initialized in trVarsInit, we copy 
% them to 'trVarsGuiComm' in order to inform the gui. 
% trVarsGuiComm's sole purpose is to communicate between the gui and the 
% trVars that inherit its contents on every trial. Thus, user may change
% things in gui (which effectively chagnes the trVarsGuiComm) that then
% (in the 'next' function) updates the trVars!

p.trVarsGuiComm = p.trVarsInit;

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
p.draw.targRadius           = 10;        % fixation point "radius" in pixels
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
% during the run function!).
%
% format:
%   every row is a pair:
%   {str, var}
% where 'str' is a fieldname from p.init.codes (also see pds.initCodes.m), and
% 'var' is that variable we wish to strobe its vale.
%
% example:
%   {trialCount, p.status.iTrial}, 
%   where 'trialCount' has a unique code (defined in 'pds.initCodes'), and 
%   'p.status.iTrial' holds the value of the current trial. So on trial 
%   666, you'd get:
%       {110022, 666}. 
%
% The list below is strobed by the function 'pds.strobeVars' 
% Useful functions to toggle between codes and strings:
%   pds.str2code.m, pds.code2str.m

p.init.strobeList = {...
    'taskCode',         'p.init.taskCode'; ...
    'date_1yyyy',       'p.init.date_1yyyy'; ...
    'date_1mmdd',       'p.init.date_1mmdd'; ...
    'time_1hhmm',       'p.init.time_1hhmm'; ...
    'connectPLX',       'p.trVars.connectPLX'; ...
    'vissac',           'p.trVars.isVisSac'; ...
    'targetTheta',      'p.trVars.targTheta_x10'; ...
    'targetRadius',     'p.trVars.targRadius_x100'; ...
    'rewardDuration',   'p.trVars.rewardDurationMs'; ...
    'trialCount',       'p.status.iTrial'; ...
    'goodTrialCount',   'p.status.iGoodTrial'; ...
    'passJoy',          'p.trVarsInit.passJoy'; ...
    'joyPressVoltDir',  'p.trVarsInit.joyPressVoltDir'; ...
    'trialCode',        'p.init.trialsArray(p.trVars.currentTrialsArrayRow, strcmp(p.init.trialArrayColumnNames, ''trialCode''))';
    };


end
