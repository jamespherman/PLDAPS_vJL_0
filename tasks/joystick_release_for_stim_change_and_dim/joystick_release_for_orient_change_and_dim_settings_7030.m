function p = joystick_release_for_orient_change_and_dim_settings_7030
%  p = joystick_release_for_orient_change_and_dim_settings_7030
%  On some proportion of trials, the fixation point turns off without
%  reward delivery or "boop", monkey must release joystick to get reward on
%  those trials. On the remaining trials, the "boop" and reward are
%  delivered simultaneously with fixation offset.
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


% define paths to add for this task
% a list of paths to add (at present, for making sure directories
% containing support functions will be in the path).
% % p.init.pathList      = {[pwd '/supportFunctions']};

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

p.init.exptType         = 'joystick_release_for_stim_dim_and_orient_change_7030';  % Which experiment are we running? <- IMPORTANT FOR TRIAL STRUCTURE CHOICE

p.init.taskName         = 'joystick_release_for_stim_change_and_dim';
p.init.taskType         = 1;                            % poorly defined numerical index for the task "type"
p.init.pldapsFolder     = pwd;                          % pldaps gui takes us to taks folder automatically once we choose a settings file
p.init.protocol_title   = [p.init.taskName '_task'];    % Define Banner text to identify the experimental protocol
p.init.date             = datestr(now,'yyyymmdd');
p.init.time             = datestr(now,'HHMM');

p.init.date_1yyyy       = str2double(['1' datestr(now,'yyyy')]); % gotta add a '1' otherwise date/times starting with zero lose that zero in conversion to double.
p.init.date_1mmdd       = str2double(['1' datestr(now,'mmdd')]);
p.init.time_1hhmm       = str2double(['1' datestr(now,'HHMM')]);


% are we using datapixx / viewpixx?
p.init.useDataPixxBool = true;

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

% are we using datapixx / viewpixx?
p.init.useDataPixxBool = true;

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

%% audio:
p.audio.audsplfq        = 48000; % datapixx audio playback sampling rate.
p.audio.Hitfq           = 600;   % frequency for "high" (hit) tone.
p.audio.Missfq          = 100;   % frequency for "low" (miss) tone.
p.audio.auddur          = 4800;  % duration in samples for tones.
p.audio.lineOutLevel    = 0.4;   % datapixx line out audio level [0 - 1].
p.audio.pcPlayback      = false;  % do we want audio playback from psychtoolbox PC?

%% STATES
% transition states:
p.state.trialBegun      = 1;
p.state.waitForJoy      = 2;
p.state.showFix         = 3;
p.state.dontMove        = 4;
p.state.makeDecision    = 5;

% end states - aborted:
p.state.fixBreak        = 11;
p.state.joyBreak        = 12;
p.state.nonStart        = 13;

% end states - success:
p.state.hit             = 21;
p.state.cr              = 22;
p.state.miss            = 23;
p.state.foilFa          = 24;
p.state.fa              = 25;

%% STATUS VALUES

p.status.iTrial                     = 0; % ITERATOR for current trial count
p.status.iGoodTrial                 = 0; % count of all trials that have ended in hit, miss, cr, foil fa (no fix or joy breaks, no fa)
p.status.trialsLeftInBlock          = 0; % how many trials remain in the current block?
p.status.blockNumber                = 0; % what block are we in?

p.status.fixDurReq                  = 0; % how long was the monkey required to hold down the joystick on the last trial?

p.status.hr1stim                    = 0; % hit rate for 1-stimulus trials
p.status.hr2stim                    = 0; % hit rate for 2-stimulus trials
p.status.hr3stim                    = 0; % hit rate for 3-stimulus trials
p.status.hr4stim                    = 0; % hit rate for 4-stimulus trials

p.status.hc1stim                    = 0; % hit count for 1-stimulus trials
p.status.hc2stim                    = 0; % hit count for 2-stimulus trials
p.status.hc3stim                    = 0; % hit count for 3-stimulus trials
p.status.hc4stim                    = 0; % hit count for 4-stimulus trials
p.status.tc1stim                    = 0; % total count for 1-stimulus trials
p.status.tc2stim                    = 0; % total count for 2-stimulus trials
p.status.tc3stim                    = 0; % total count for 3-stimulus trials
p.status.tc4stim                    = 0; % total count for 4-stimulus trials

p.status.hr1Loc1                    = 0; % hit rate for single patch at location 1
p.status.cr1Loc1                    = 0; % correct reject rate for single patch at location 1
p.status.hr1Loc2                    = 0; % hit rate for single patch at location 2
p.status.cr1Loc2                    = 0; % correct reject rate for single patch at location 2
p.status.hr2Loc1                    = 0; % hit rate for two patch at location 1
p.status.cr2Loc1                    = 0; % correct reject rate for two patch at location 1
p.status.hr2Loc2                    = 0; % hit rate for two patch at location 2
p.status.cr2Loc2                    = 0; % correct reject rate for two patch at location 2

p.status.hc1Loc1                    = 0; % hit count for single patch at location 1
p.status.crc1Loc1                   = 0; % correct reject count for single patch at location 1
p.status.hc1Loc2                    = 0; % hit count for single patch at location 2
p.status.crc1Loc2                   = 0; % correct reject count for single patch at location 2
p.status.hc2Loc1                    = 0; % hit count for two patch at location 1
p.status.crc2Loc1                   = 0; % correct reject count for two patch at location 1
p.status.hc2Loc2                    = 0; % hit count for two patch at location 2
p.status.crc2Loc2                   = 0; % correct reject count for two patch at location 2

p.status.cue1CtLoc1                 = 0; % count of single patch cue change trials at location 1
p.status.foil1CtLoc1                = 0; % count of single patch foil change trials at location 1
p.status.cue1CtLoc2                 = 0; % count of single patch cue change trials at location 2
p.status.foil1CtLoc2                = 0; % count of single patch foil change trials at location 2
p.status.cue2CtLoc1                 = 0; % count of two patch cue change trials at location 1
p.status.foil2CtLoc1                = 0; % count of two patch foil change trials at location 1
p.status.cue2CtLoc2                 = 0; % count of two patch cue change trials at location 2
p.status.foil2CtLoc2                = 0; % count of two patch foil change trials at location 2

p.status.missedFrames               = 0; % count of missed frames as reported by psychtoolbox
p.status.freeRwdRand                = 0; % random number drawn for deciding whether or not to deliver free reward
p.status.freeRwdTotal               = 0; % total count of free inter trial interval rewards delivered
p.status.freeRwdLast                = 0; % last trial in which a free reward was given.

p.status.trialsArrayRowsPossible    = [];
p.status.freeRewardsAvailable       = [];

p.status.trialEndStates             = []; % vector of trial end state values
p.status.reactionTimes              = []; % vector of joystick release reaction times (relative to dimming).
p.status.dimVals                    = []; % vector of dim values.
p.status.changeDelta                = []; % magnitude of stimulus change in current trial
p.rig.guiStatVals = {...
    'blockNumber'; ...
    'iTrial'; ...   
    'iGoodTrial'; ...
    'trialsLeftInBlock'; ...
    'fixDurReq'; ...
    'freeRwdRand'; ...
    'freeRwdTotal'; ...
    'freeRwdLast'; ...
    'hr1stim'; ...
    'hr2stim'; ...
    'hr3stim'; ...
    'hr4stim'; ...
%     'missedFrames'; ...
    };    

%% user determines the 12 variables are shown in gui upon init
% here you just list the vars you want to see. You do not set them, yet.
% Setting them takes place below in the appropriate section.
% The list of vars should be in string format eg 'p.trVarsInit.cueDelta'

p.rig.guiVars = {...
    'rewardDurationMs'; ...     % 1
    'rewardDelay'; ...          % 2
    'stim2ChgIntvl'; ...        % 3
    'chgWinDur'; ...            % 4
    'stimLoc1Elev'; ...         % 5
    'hueDelta'; ...             % 6
    'lumDelta'; ...             % 7
    'propHueChgOnly'; ...       % 8
    'joyMinLatency'; ...        % 9
    'joyMaxLatency'; ...        % 10
    'passJoy'; ...              % 11
    'passEye'};                 % 12

%% INIT VARIABLES 
% vars that are only set once

%% TRIAL VARIABLES
% vars that may change throughout an experimental session and are therefore
% saved on every trial. 
% Here we define 'trVarsInit' as this is the default. However, user may
% change any variable through the gui (which updates 'trVarsGuiComm) and
% then updates 'trVars' during the run function. 
% 'trVars' is the key strcutarray that gets saved on every trial.

% general vars:
p.trVarsInit.passJoy             = 0;       % pass = 1; simulate correct trials (for debugging)
p.trVarsInit.passEye             = 0;       % pass = 1; simulate correct trials (for debugging)
p.trVarsInit.blockNumber         = 0;       % block number
p.trVarsInit.repeat              = 0;       % repeat trial if true
p.trVarsInit.rwdJoyPR            = 0;       % 0 = Give reward if Joy is pressed; 1 = Give reward if Joystick released
p.trVarsInit.isCueChangeTrial    = 0;       % change (1) or no change trial (0)
p.trVarsInit.isFoilChangeTrial   = -1;      % no change(0); change(1); foil not present (-1)
p.trVarsInit.isNoChangeTrial     = -1;
p.trVarsInit.finish              = 5000;
p.trVarsInit.filesufix           = 1;       % save to file sufix
p.trVarsInit.joyVolt             = 0;
p.trVarsInit.eyeDegX             = 0;
p.trVarsInit.eyeDegY             = 0;
p.trVarsInit.eyePixX             = 0;
p.trVarsInit.eyePixY             = 0;

% what are the variables we need for this task? We need one that controls
% the proportion of trials that will be "change" trials in which the monkey
% has to release the joystick in response to the fixation dimming, and the
% porportion that will be "no change" trials in which the monkey has to
% keep holding the joystick down. We also need a logical variable to
% indicate whether the current trial is a "change" or a "no change" trial.
% The above is old - update it (jph - 11/1/2022).

p.trVarsInit.propHueChgOnly      = 0;       % proportion of trials in which the peripheral stimulus only changes hue with no dimming
p.trVarsInit.isStimChangeTrial   = false;     % variable tracking whether the current trial is a "change" or "no change" trial.

% for the training step in which we move from 1 stimulus to 4 stimuli, we
% want the option to have the change + dim only on multiple stimulus
% trials, which we have implemented, but we also want to be able to turn it
% off so we have change + dim on ALL the trials, including the 1 stimulus
% trials, since the monkey might get frustrated by the single stimulus
% trials effectively being harder. Make a flag for this:
p.trVarsInit.chgAndDimOnMultiOnly = false;

% Stimulus geometry variables. There can be up to 4 stimuli shown
% stimultaneously. We specify stimulus location 1 by an angle
% of elevtation ("stimLoc1Elev") and an eccentricity (stimLoc1Ecc). Then we
% position the other 3 stimuli at the same eccentricity, and at elevations
% that are regularly spaced around the circle (e.g. +90, +180, +270
% relative to "stimLoc1Elev"). However, we may want to tweak these stimulus
% locations in the future, so we're going to include variables for each of
% the remaining stimulus locations (e.g. stimLoc2Elev, stimLoc3Elev,
% stimLoc4Elev), which we can use to tweak their positions. If those
% variables are 0, we do nothing, but if those variables are nonzero, we
% replace the automatically calculated elevations and eccentricities with
% the specified values:
p.trVarsInit.stimLoc1Elev        = 0;           % Stimulus location (angle of elevation).
p.trVarsInit.stimLoc1Ecc         = 10;          % Stimulus location (eccentricity in degrees).
p.trVarsInit.stimLoc2Elev        = 0;           % Stimulus location (angle of elevation).
p.trVarsInit.stimLoc2Ecc         = 0;           % Stimulus location (eccentricity in degrees).
p.trVarsInit.stimLoc3Elev        = 0;           % Stimulus location (angle of elevation).
p.trVarsInit.stimLoc3Ecc         = 0;           % Stimulus location (eccentricity in degrees).
p.trVarsInit.stimLoc4Elev        = 0;           % Stimulus location (angle of elevation).
p.trVarsInit.stimLoc4Ecc         = 0;           % Stimulus location (eccentricity in degrees).

% Fixation location variables:
p.trVarsInit.fixDegX             = 0;           % fixation X location in degrees
p.trVarsInit.fixDegY             = 0;           % fixation Y location in degrees
p.trVarsInit.fixLocRandX         = 0;           % random variation in X location of fixation point
p.trVarsInit.fixLocRandY         = 0;           % random variation in X location of fixation point

% the following three variables determine how fixation dimming works. In
% each trial we will choose with equal probability whether the fixation
% will dim to the "lowDimVal", the "midDimVal", or the "highDimVal". The
% values below determine how bright the fixation will be after dimming,
% relative to the background. A value of 0 would mean the fixation is
% completely extinguished (off), a value of 1 would mean the fixation
% remains at a fixed brightness.
p.trVarsInit.lowDimVal           = 0.75;          % minimum brightness ABOVE background level of fixation after dimming
p.trVarsInit.midDimVal           = 0.825;         % middle brightness ABOVE background level of fixation after dimming
p.trVarsInit.highDimVal          = 0.9;        % high brightness ABOVE background level of fixation after dimming

% Initial / base values for each stimulus feature.
p.trVarsInit.speedInit                = 0.0;      % initial motion magniutde
p.trVarsInit.ctrstInit                = 0.375;    % initial contrast
p.trVarsInit.orientInit               = 30;       % initial orientation
p.trVarsInit.freqInit                 = 0.25;     % initial spatial frequency (cycles per degree)
p.trVarsInit.satInit                  = 0.0;      % initial color saturation
p.trVarsInit.lumInit                  = 0.3;      % initial luminance
p.trVarsInit.hueInit                  = 20;       % initial hue (color angle)

% Variance of feature dimensions that can be variable in this way:
p.trVarsInit.orientVar                = 8;        % variability in orientation
p.trVarsInit.hueVar                   = 0.00;     % variability in hue (angle)
p.trVarsInit.lumVar                   = 0.02;     % variability in luminance
p.trVarsInit.satVar                   = 0.00;     % variability in saturation

% Magnitude of stimulus delta if desired:
p.trVarsInit.speedDelta               = (pi/8);   % motion magniutde
p.trVarsInit.contDelta                = 0.2;      % contrast
p.trVarsInit.orientDelta              = 45;       % orientation
p.trVarsInit.freqDelta                = 0.25;     % spatial frequency (cycles per degree)
p.trVarsInit.satDelta                 = 0.038;    % color saturation
p.trVarsInit.lumDelta                 = -0.15;     % luminance
p.trVarsInit.hueDelta                 = 50;       % hue (color angle)

% spatial properties of "checkerboard":
p.trVarsInit.stimRadius               = 3.25;     % aperture radius in deg
p.trVarsInit.boxSizePix               = 24;       % diameter of each "check" in pixels
p.trVarsInit.boxLifetime              = 8;        % "check" lifetime in frames
p.trVarsInit.nPatches                 = 4;        % number of stimuli 
p.trVarsInit.nEpochs                  = 2;        % just one "pre-change" and one "post-change" epoch for now

% times/latencies/durations:
p.trVarsInit.rewardDurationMs        = 300;      % reward duration
p.trVarsInit.fix2CueIntvl            = 0.0;      % Time delay between acquiring fixation and cue onset.
p.trVarsInit.cueDur                  = 0.0;      % Duration of cue presentaiton.
p.trVarsInit.cue2StimItvl            = 0.35;     % time between cue offset and stimulus onset (stimulus onset asynchrony).
p.trVarsInit.stim2ChgIntvl           = 0.5;      % minimum time between stimulus onset and change.
p.trVarsInit.chgWinDur               = 1.5;      % time window during which a change is possible.
p.trVarsInit.rewardDelay             = 0.65;     % delay between cued change and reward delivery for hits.
p.trVarsInit.joyMinLatency           = 0.2;      % minimum acceptable joystick release latency.
p.trVarsInit.joyMaxLatency           = 1;        % maximum acceptable joystick release latency.
p.trVarsInit.timeoutAfterFa          = 1;        % timeout duration following false alarm.
p.trVarsInit.timeoutAfterFoilFa      = 0;        % timeout duration following false alarm.
p.trVarsInit.timeoutAfterMiss        = 0;        % timeout duration following miss
p.trVarsInit.timeoutAfterFixBreak    = 0.1;      % timeout duration following fixation break
p.trVarsInit.joyWaitDur              = 5;        % how long to wait for the subject to press the joystick at the beginning of a trial?
p.trVarsInit.fixWaitDur              = 5;        % how long to wait after initial joystick press for the subject to acquire fixation?
p.trVarsInit.freeDur                 = 0;        % time before start of joystick press check
p.trVarsInit.trialMax                = 15;       % max length of the trial
p.trVarsInit.joyReleaseWaitDur       = 5;        % how long to wait after trial end to start flickering the screen if the joystick hasn't been released

p.trVarsInit.stimFrameIdx            = 1;        % stimulus (eg dots) frame display index
p.trVarsInit.flipIdx                 = 1;        % index of
p.trVarsInit.postRewardDurMin        = 1;      % how long should the trial last AFTER reward delivery at minimum? This lets us record the neuronal response to reward.
p.trVarsInit.postRewardDurMax        = 1.2;      % how long should the trial last AFTER reward delivery at maximum? This lets us record the neuronal response to reward.
p.trVarsInit.useQuest                = false;    % use "QUEST" to determine next stimulus value?
p.trVarsInit.numTrialsForPerfCalc    = 100;      % how many of the most recently completed trials should be used to calculate % correct / median RT?
p.trVarsInit.freeRewardProbability   = 0.1;      % How probable is it that the monkey will get a free reward in between trials?

p.trVarsInit.connectRipple           = true;
p.trVarsInit.rippleChanSelect        = 1;
p.trVarsInit.useOnlineSort  	     = 0; % a boolean indicating whether we want to use spike times that have been sorted online in trellis or all threshold crossing times.

% variables related to PSTH plotting:
p.trVarsInit.psthBinWidth            = 0.025;
p.trVarsInit.fixOnPsthMinTime        = -0.1;
p.trVarsInit.fixOnPsthMaxTime        = 0.75;
p.trVarsInit.stimOnPsthMinTime       = -0.1;
p.trVarsInit.stimOnPsthMaxTime       = 0.75;
p.trVarsInit.stimChgPsthMinTime      = -0.1;
p.trVarsInit.stimChgPsthMaxTime      = 0.75;
p.trVarsInit.rwdPsthMinTime          = -0.1;
p.trVarsInit.rwdPsthMaxTime          = 0.75;
p.trVarsInit.freeRwdPsthMinTime      = -0.1;
p.trVarsInit.freeRwdPsthMaxTime      = 0.75;

% I don't think I need to carry these around in 'p'....
% can't I just define them in the 'run' worksapce and forget avbout them?
p.trVarsInit.currentState     = p.state.trialBegun;  % initialize "state" variable.
p.trVarsInit.exitWhileLoop    = false;  % do we want to exit the "run" while loop?
p.trVarsInit.cueIsOn          = 0;  % is the cue ring currently being presented?
p.trVarsInit.stimIsOn         = false;  % are stimuli currently being presented?

p.trVarsInit.fixWinWidthDeg       = 4;        % fixation window width in degrees
p.trVarsInit.fixWinHeightDeg      = 4;        % fixation window height in degrees
p.trVarsInit.fixPointRadPix       = 20;       % fixation point "radius" in pixels
p.trVarsInit.fixPointLinePix      = 12;       % fixation point line weight in pixels

% variables related to how the experiment is run / what is shown, etc.
p.trVarsInit.useCellsForDraw        = false;
p.trVarsInit.wantEndFlicker         = true;     % have screen flicker / low tone play repeatedly while waiting for joystick release?
p.trVarsInit.wantOnlinePlots        = true;     % use online plotting window?
p.trVarsInit.fixColorIndex          = 0;

% substructure for marking stimulus-events after each flip
p.trVarsInit.postFlip.logical         = false;
p.trVarsInit.postFlip.varNames        = cell(0);

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
    'p.trData.spikeTimes',              '[]'; ...
    'p.trData.eventTimes',              '[]'; ...
    'p.trData.eventValues',             '[]'; ...
    'p.trData.onlineEyeX',              '[]'; ...
    'p.trData.onlineEyeY',              '[]'; ...
    'p.trData.timing.lastFrameTime',    '0'; ...    % time at which last video frame was displayed
    'p.trData.timing.fixOn',            '-1'; ...   % time of fixation onset
    'p.trData.timing.fixAq',            '-1'; ...   % time of fixation acquisition
    'p.trData.timing.stimOn',           '-1'; ...   % time of stimulus onset
    'p.trData.timing.stimOff',          '-1'; ...   % time of stimulus offset
    'p.trData.timing.cueOn',            '-1'; ...   % time of cur ring onset
    'p.trData.timing.cueOff',           '-1'; ...   % time of cue ring offset
    'p.trData.timing.stimChg',          '-1'; ...   % time of stimulus change
    'p.trData.timing.noChg',            '-1'; ...   % time of no change
    'p.trData.timing.brokeFix',         '-1'; ...   % time of fixation break
    'p.trData.timing.brokeJoy',         '-1'; ...   % time of joystick release
    'p.trData.timing.reward',           '-1'; ...   % time of reward delivery
    'p.trData.timing.tone',             '-1'; ...   % time of audio feedback delivery
    'p.trData.timing.joyPress',         '-1'; ...   % time of joystick press
    'p.trData.timing.joyRelease',       '-1'; ...   % time of joystick release
    'p.trData.timing.reactionTime'      '-1'; ...   % time of joystick release relative to dimming
    'p.trData.timing.fixHoldReqMet',    '-1'; ...   % time that fixation hold duration was met (also time of fixation dimming)
    'p.trData.timing.freeReward',       '-1'; ...   % time that free reward was delivered
    };

% since the list above is fixed, count its rows now for looping over later.
p.init.nTrDataListRows                  = size(p.init.trDataInitList, 1);

%% draw - these are paramters used for drawing
% the boring stuff, like width and height of stuff that gets drawn - NOTE,
% variables defined here are retained for the duration of the experiment,
% they can't be changed from trial-to-trial in the GUI.
p.draw.ringThickDeg         = 0.5;     % ring thickness in degrees
p.draw.ringRadDeg           = 4;        % ring radius in degrees
p.draw.eyePosWidth          = 6;        % eye position indicator width in pixels
p.draw.fixPointWidth        = 4;        % fixation point indicator line width in pixels
p.draw.fixPointRadius       = 10;       % fixation point "radius" in pixels
p.draw.fixWinPenPre         = 4;        % fixation window width (prior to change).
p.draw.fixWinPenPost        = 8;        % fixation window width (after change).
p.draw.fixWinPenDraw        = 4;        % gets assigned either the pre or the post during the run function 
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

% Store a list of stimulus feature value array names to speed up defining
% them later. NOTE: the strings used here must match the strings used in
% "p.init.trialArrayColumnNames" and pretty much everywhere else we refer
% to each of the features. For example, p.trVars should have a field called
% "contDelta" referring to the magnitude of contrast change (when a
% contrast change trial occurs).
p.stim.featureValueNames = {'speed', 'ctrst', 'orient', 'freq', 'sat', 'lum', 'hue'};
p.stim.nFeatures         = length(p.stim.featureValueNames);

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
p.draw.clutIdx.expRwdRed_subRwdRed       = 8;
p.draw.clutIdx.expRwdBlue_subRwdBlue     = 9;
p.draw.clutIdx.expRwdGreen_subRwdGreen   = 10;
p.draw.clutIdx.expCueGrey_subCueGrey     = 11;
p.draw.clutIdx.expBlack_subBg            = 12;
p.draw.clutIdx.expOldGreen_subOldGreen   = 13;
p.draw.clutIdx.expFixDim_subFixDim       = 14;

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
p.draw.color.joyInd     = p.draw.clutIdx.expGrey70_subBg;               % joy position indicator CLUT index


%% WHAT TO STROBE:
% here lies a list of variables we wish to strobe at the end of every
% trial (this is in addition to the time-sensitive strobes that get strobed 
% suring the run function!).
% The function pds.strobeVars takes this list and strobes a number that 
% identifies the variable, immidiately followed by its value.
% eg
% HACK ALERT - DON'T HARD CODE NUMBERS (e.g. "17" for trial code below).
% Fix it. jph - 6/21/2023

p.init.strobeList = fliplr({...                 
    'p.init.date_1yyyy',                                                                                        'date_1yyyy'; ...
    'p.init.date_1mmdd',                                                                                        'date_1mmdd'; ...      
    'p.init.time_1hhmm',                                                                                        'time_1hhmm'; ...
    'p.init.codes.uniqueTaskCode_scd',                                                                          'taskCode'; ...
    'p.trVars.stimLoc1Elev',                                                                                    'stimLoc1Elev'; ...
    'p.trVars.stimLoc1Ecc',                                                                                     'stimLoc1Ecc'; ...
    'p.stim.cueLoc',                                                                                            'cueLoc'; ...
    'p.stim.stimChgIdx',                                                                                        'chgLoc'; ...
    'p.trVars.rewardDurationMs',                                                                                'rewardDuration'; ...
    'p.status.iTrial',                                                                                          'trialCount'; ...
    'p.status.iGoodTrial',                                                                                      'goodTrialCount'; ...
    'p.init.trialsArray(p.trVars.currentTrialsArrayRow, strcmp(p.init.trialArrayColumnNames, ''trialCode''))',  'trialCode'; ...
    'p.trVars.trialSeed',                                                                                       'trialSeed'; ...
    'p.trVars.stimSeed',                                                                                        'stimSeed'; ...

    });
end
