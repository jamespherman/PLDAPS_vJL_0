function p = human_psychophysical_threshold_settings_hue4
%  p = human_psychophysical_threshold_settings_hue4
%
%  On some proportion of trials, the fixation point turns off without
%  reward delivery or "boop", monkey must release joystick to get reward on
%  those trials. On the remaining trials, the "boop" and reward are
%  delivered simultaneously with fixation offset.
%4
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

% 7/20/2023
%
% Everything is working! (Almost). It seems that eyelink somehow obtains
% control over the continued running of the experiment: regardless of
% whether I unclick "RUN" in the PLDAPS gui, the experiment keeps running.
% Maybe this is just about querying the state of the run button? I also
% want to check if there's something I need to do like send Eyelink a
% "stop" command? After that we just need to decide on how to vary stimulus
% intensity from trial to trial. I think an adaptive method is probably the
% best. We should try QUEST with some visualization (of estimated
% psychometric function). We also have to check up on the data and make
% sure we have what we need.

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
p.init.rigConfigFile     = which('rigConfigFiles.rigConfig_human'); % rig config file has subject/rig-specific details (eg distance from screen)


%% define task name and related files:

p.init.taskName         = 'human_psychophysical_threshold';
p.init.taskType         = 1;                            % poorly defined numerical index for the task "type"
p.init.pldapsFolder     = pwd;                          % pldaps gui takes us to taks folder automatically once we choose a settings file
p.init.protocol_title   = [p.init.taskName '_task'];    % Define Banner text to identify the experimental protocol
p.init.date             = datestr(now,'yyyymmdd');
p.init.time             = datestr(now,'HHMM');

p.init.exptType         = 'human_psychophysics_hue_discrimination';  % Which experiment are we running? <- IMPORTANT FOR TRIAL STRUCTURE CHOICE

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

% We need to know that this is a "human" experiment rather than a monkey
% experiment. Define a variable in "init" for this purpose. Using PLDAPS
% for human experiments means we might or we might not be using the
% VIEWPixx. Set a variable for that too. Finally, set a variable indicating
% whether we are using "dummy mode" for the Eyelink (if dummy mode is set
% to "1", the tracker need not be physically connected).
p.init.subjType         = 'Human';
p.init.elDummyMode      = 0;
p.init.useDataPixxBool  = false;

%% Define the Action M-files
% User-defined actions that are either within the task folder under
% "actions" or within the +pdsActions:
p.init.taskActions{1} = 'pdsActions.dataToWorkspace';
p.init.taskActions{2} = 'pdsActions.blackScreen';
p.init.taskActions{3} = 'pdsActions.alphaBinauralBeats';
p.init.taskActions{4} = 'pdsActions.stopAudioSchedule';
p.init.taskActions{5} = 'pdsActions.catOldOutput';
p.init.taskActions{6} = 'i1CalibrateAndMeasure';
p.init.taskActions{7} = 'i1Validate';

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

% end states - completed:
p.state.trialCompleted  = 26;

%% STATUS VALUES

p.status.iTrial                     = 0; % ITERATOR for current trial count
p.status.iGoodTrial                 = 0; % count of all trials that have ended in hit, miss, cr, foil fa (no fix or joy breaks, no fa)
p.status.trialsLeftInBlock          = 0; % how many trials remain in the current block?
p.status.blockNumber                = 0; % what block are we in?
p.status.totalTrials                = 0; % how many trials will we run in total?

p.status.missedFrames               = 0; % count of missed frames as reported by psychtoolbox

p.status.trialsArrayRowsPossible    = [];

p.status.trialEndStates             = []; % vector of trial end state values
p.status.reactionTimes              = []; % vector of joystick release reaction times (relative to dimming).
p.status.questThreshEst             = []; % quest's estimated threshold
p.status.questSignalVal             = []; % last quest-suggested signal strength
p.status.fixSignalStrength          = 0;  % are we presenting a fixed signal strength or a quest-determined variable one?
p.status.numTrialsSinceFixSig       = 0;  % running count of the number of good trials since the threshold was fixed.
p.rig.guiStatVals = {...
    'blockNumber'; ...
    'iTrial'; ...   
    'iGoodTrial'; ...
    'trialsLeftInBlock'; ...
    'questSignalVal'; ...
    'questThreshEst'; ...
    'fixSignalStrength'; ...
    'numTrialsSinceFixSig'; ...
    };

%% user determines the 12 variables are shown in gui upon init
% here you just list the vars you want to see. You do not set them, yet.
% Setting them takes place below in the appropriate section.
% The list of vars should be in string format eg 'p.trVarsInit.cueDelta'

p.rig.guiVars = {...
    'passJoy'; ...     % 1
    'passEye'; ...          % 2
    'doDriftCorrect'; ...        % 3
    'hueDelta'; ...            % 4
    'hueVar'; ...         % 5
    'ctrstInit'; ...             % 6
    'satInit'; ...             % 7
    'satVar'; ...       % 8
    'lumInit'; ...        % 9
    'satMaskVar'; ...        % 10
    'hueMaskVar'; ...              % 11
    'divFactorNoThreshChg'};                 % 12

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

p.trVarsInit.propHueChgOnly      = 0.5;         % proportion of trials in which the peripheral stimulus only changes hue with no dimming
p.trVarsInit.isStimChangeTrial   = false;     % variable tracking whether the current trial is a "change" or "no change" trial.

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
p.trVarsInit.stimLoc1Elev        = 45;          % Stimulus location (angle of elevation).
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

% How bright should the background be in DKL colorspace?
p.trVarsInit.bgLum                    = -0.5;

% Initial / base values for each stimulus feature.
p.trVarsInit.speedInit                = 0.0;      % initial motion magniutde
p.trVarsInit.ctrstInit                = 0.1;      % initial contrast
p.trVarsInit.orientInit               = 30;       % initial orientation
p.trVarsInit.freqInit                 = 0.175;    % initial spatial frequency (cycles per degree)
p.trVarsInit.satInit                  = 0.4;      % initial color saturation
p.trVarsInit.lumInit                  = p.trVarsInit.bgLum;      % initial luminance
p.trVarsInit.hueInit                  = 270;        % initial hue (color angle)

% Stimulus feature variances used for masking:
p.trVarsInit.ctrstMask                = 0;        % contrast for masking epoch
p.trVarsInit.lumMaskVar               = 0.25;      % contrast variance for masking epoch
p.trVarsInit.orientMaskVar            = 20;       % orientation variance for masking epoch
p.trVarsInit.hueMaskVar               = 180;    % hue variance for masking epoch
p.trVarsInit.satMaskVar               = 0.4;      % sat variance for masking epoch
p.trVarsInit.satMask                  = 0.0;      % sat for masking epoch

% Variance of feature dimensions that can be variable in this way:
p.trVarsInit.orientVar                = 2;       % variability in orientation
p.trVarsInit.hueVar                   = 0.05;     % variability in hue (angle)
p.trVarsInit.lumVar                   = 0.0;     % variability in luminance
p.trVarsInit.satVar                   = 0.0;     % variability in saturation

% Magnitude of stimulus delta if desired:
p.trVarsInit.speedDelta               = (pi/8);   % motion magniutde
p.trVarsInit.contDelta                = 0.3;      % contrast
p.trVarsInit.orientDelta              = 45;       % orientation
p.trVarsInit.freqDelta                = 0.25;     % spatial frequency (cycles per degree)
p.trVarsInit.satDelta                 = 0.038;    % color saturation
p.trVarsInit.lumDelta                 = 0;        % luminance
p.trVarsInit.hueDelta                 = 45;       % hue (color angle)

% spatial properties of "checkerboard":
p.trVarsInit.stimRadius               = 3.25;     % aperture radius in deg
p.trVarsInit.boxSizePix               = 6;        % diameter of each "check" in pixels
p.trVarsInit.boxLifetime              = 8;        % "check" lifetime in frams
p.trVarsInit.nPatches                 = 4;        % number of stimuli 
p.trVarsInit.nEpochs                  = 3;        % just one epoch with all four stimuli present.

% times/latencies/durations:
p.trVarsInit.rewardDurationMs        = 200;      % reward duration
p.trVarsInit.fix2CueIntvl            = 0.0;      % Time delay between acquiring fixation and cue onset.
p.trVarsInit.cueDur                  = 0.0;      % Duration of cue presentaiton.
p.trVarsInit.cue2StimItvl            = 0.25;     % time between cue offset and stimulus onset (stimulus onset asynchrony).
p.trVarsInit.maskItvlMin             = 0.3;      % minimum duration of masking interval
p.trVarsInit.maskItvlWin             = 0.2;      % multiplicative scalar to determine masking interval duration (rand * win + min)
p.trVarsInit.targetItvlDur           = 1.5;      % duratino of "target" interval
p.trVarsInit.chgWinDur               = 0.0;      % time window during which a change is possible.
p.trVarsInit.rewardDelay             = 0.5;      % delay between cued change and reward delivery for hits.
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
p.trVarsInit.stimChgIdx              = 0;        % which stimulus will be the outlier on the upcoming trial?

p.trVarsInit.stimFrameIdx            = 1;        % stimulus (eg dots) frame display index
p.trVarsInit.flipIdx                 = 1;        % index of
p.trVarsInit.postRewardDuration      = 0;        % how long should the trial last AFTER reward delivery? This lets us record the neuronal response to reward.
p.trVarsInit.numTrialsForPerfCalc    = 100;      % how many of the most recently completed trials should be used to calculate % correct / median RT?

% variables related to "QUEST" (adaptive threshold estimation)
p.trVarsInit.useQuest                = true;     % use "QUEST" to determine next stimulus value?
p.trVarsInit.initQuestThreshGuess    = 10;       % initial guess of threshold value to pass to quest
p.trVarsInit.initQuestSD             = 10;       % how many SDs to tell QUEST to search for threshold value?
p.trVarsInit.initQuestBetaGuess      = 10;       % what is our initial guess for beta?
p.trVarsInit.signalStrength          = 30;       % what is the signal strength for the upcoming trial (updated during experiment). This is also the assumed suprathreshold value.
p.trVarsInit.minSignalStrength       = 1;        % what is the smallest signal we want to test?
p.trVarsInit.maxSignalStrength       = 360;      % what is the largest signal we want to test?
p.trVarsInit.supraSignalStrength     = 60;       % what is a signal strength that is very likely to be above threshold?
p.trVarsInit.numThreshCheckTrials    = 5;        % how many trials to check for thrreshold estimate being lower than criterion?
p.trVarsInit.divFactorNoThreshChg    = 1000;     % what fraction size are we looking for a trial-to-trial change in threshold estimate to change by, to trigger a switch to constant delta?

% I don't think I need to carry these around in 'p'....
% can't I just define them in the 'run' worksapce and forget avbout them?
p.trVarsInit.currentState     = p.state.trialBegun;  % initialize "state" variable.
p.trVarsInit.exitWhileLoop    = false;  % do we want to exit the "run" while loop?
p.trVarsInit.cueIsOn          = 0;  % is the cue ring currently being presented?
p.trVarsInit.stimIsOn         = false;  % are stimuli currently being presented?

p.trVarsInit.fixWinWidthDeg       = 4;        % fixation window width in degrees
p.trVarsInit.fixWinHeightDeg      = 4;        % fixation window height in degrees
p.trVarsInit.fixPointRadPix       = 10;       % fixation point "radius" in pixels
p.trVarsInit.fixPointLinePix      = 6;        % fixation point line weight in pixels

% variables related to how the experiment is run / what is shown, etc.
p.trVarsInit.useCellsForDraw        = false;
p.trVarsInit.wantEndFlicker         = false;     % have screen flicker / low tone play repeatedly while waiting for joystick release?
p.trVarsInit.wantOnlinePlots        = false;     % use online plotting window?
p.trVarsInit.fixColorIndex          = 0;

% substructure for marking stimulus-events after each flip
p.trVarsInit.postFlip.logical         = false;
p.trVarsInit.postFlip.varNames        = cell(0);
p.trVarsInit.postFlip.msgNames        = cell(0);

% do we want to be doing drift correction every trial? I think not. Maybe
% every X trials? Maybe only when a variable is 1 and not when it's 0.
% Let's start with the latter and go from there.
p.trVarsInit.doDriftCorrect = false;

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
    };

% since the list above is fixed, count its rows now for looping over later.
p.init.nTrDataListRows                  = size(p.init.trDataInitList, 1);

%% draw - these are paramters used for drawing
% the boring stuff, like width and height of stuff that gets drawn - NOTE,
% variables defined here are retained for the duration of the experiment,
% they can't be changed from trial-to-trial in the GUI.

p.draw.ringThickDeg         = 0.25;     % ring thickness in degrees
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
p.draw.clutIdx.expCyan_subCyan           = 8;
p.draw.clutIdx.expGrey90_subBg           = 9;
p.draw.clutIdx.expMutGreen_subMutGreen   = 10;
p.draw.clutIdx.expGreen_subBg            = 11;
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
p.draw.color.joyInd     = p.draw.clutIdx.expGrey90_subBg;               % joy position indicator CLUT index


%% WHAT TO STROBE:
% here lies a list of variables we wish to strobe at the end of every
% trial (this is in addition to the time-sensitive strobes that get strobed 
% suring the run function!).
% The function pds.strobeVars takes this list and strobes a number that 
% identifies the variable, immidiately followed by its value.
% eg

p.init.strobeList = fliplr({...                 
    'p.init.date_1yyyy',                                                                                        'date_1yyyy';         
    'p.init.date_1mmdd',                                                                                        'date_1mmdd';  ...      
    'p.init.time_1hhmm',                                                                                        'time_1hhmm';
    });
end