function p = rfMap_settings
%  p = rfMap_settings
%
%  Dense noise receptive field mapping for LGN/SC.
%  Passive fixation with full-screen binary noise stimulus.
%
% Part of the quintet of pldaps functions:
%   settings function
%   init function
%   next function (before each trial)
%   run function (each trial)
%   finish function (after each trial)

%%
% p.init;           % all things that are saved once
% p.rig;            % all rig (monitor, PTB stuff, distances) related stuff
% p.audio;          % all things audio related
% p.draw;           % all widths/heights/etc of stuff that's drawn
% p.state           % all the states that we use and their id integer
% p.trVarsInit;     % all vars used in pldaps. here initialized.
% p.trVars;         % all vars used in run function inherit value from trVarsInit
% p.trVarsGuiComm;  % inheritance and user update of trVars happens through this struct
% p.trData;         % all data collected in a trial (behavior, timing, analog..)

%% p.init:
p = struct;

% determine which PC we're on for rig-specific settings:
if ~ispc
    [~, p.init.pcName] = unix('hostname');
else
    keyboard
end

% rig config file:
p.init.rigConfigFile = which(['rigConfigFiles.rigConfig_rig' ...
    p.init.pcName(end-1)]);

p.init.useDataPixxBool = true;

%% define task name and related files:
p.init.taskName         = 'rfMap';
p.init.taskType         = 1;
p.init.pldapsFolder     = pwd;
p.init.protocol_title   = [p.init.taskName '_task'];
p.init.date             = datestr(now, 'yyyymmdd');
p.init.time             = datestr(now, 'HHMM');

p.init.date_1yyyy       = str2double(['1' datestr(now, 'yyyy')]);
p.init.date_1mmdd       = str2double(['1' datestr(now, 'mmdd')]);
p.init.time_1hhmm       = str2double(['1' datestr(now, 'HHMM')]);

% output files:
p.init.outputFolder     = fullfile(p.init.pldapsFolder, 'output');
p.init.figureFolder     = fullfile(p.init.pldapsFolder, 'output', 'figures');
p.init.sessionId        = [p.init.date '_t' p.init.time '_' p.init.taskName];
p.init.sessionFolder    = fullfile(p.init.outputFolder, p.init.sessionId);

% quintet files:
p.init.taskFiles.init   = [p.init.taskName '_init.m'];
p.init.taskFiles.next   = [p.init.taskName '_next.m'];
p.init.taskFiles.run    = [p.init.taskName '_run.m'];
p.init.taskFiles.finish = [p.init.taskName '_finish.m'];

%% Define the Action M-files
p.init.taskActions{1} = 'pdsActions.dataToWorkspace';
p.init.taskActions{2} = 'pdsActions.blackScreen';
p.init.taskActions{3} = 'pdsActions.alphaBinauralBeats';
p.init.taskActions{4} = 'pdsActions.stopAudioSchedule';
p.init.taskActions{5} = 'pdsActions.rewardDrain';
p.init.taskActions{6} = 'pdsActions.singleReward';
p.init.taskActions{7} = 'pdsActions.catOldOutput';

%% audio:
p.audio.audsplfq        = 48000;
p.audio.Hitfq           = 600;
p.audio.Missfq          = 100;
p.audio.auddur          = 4800;
p.audio.lineOutLevel    = 0.4;
p.audio.pcPlayback      = false;

%% STATES
% transition states:
p.state.trialBegun      = 1;
p.state.showFix         = 2;
p.state.holdFixAndPlay  = 3;

% end states - aborted:
p.state.fixBreak        = 11;
p.state.nonStart        = 13;

% end states - success:
p.state.noiseComplete   = 21;

%% STATUS VALUES
p.status.iTrial                     = 0;
p.status.iGoodTrial                 = 0;
p.status.iAbortedTrial              = 0;
p.status.missedFrames               = 0;
p.status.moviePctComplete           = 0;
p.status.totalSpikesAccum           = 0;
p.status.lastTrialDurS              = 0;
p.status.meanFixHoldS               = 0;
p.status.fixBreakCount              = 0;
p.status.nonStartCount              = 0;
p.status.rewardCount                = 0;
p.status.trialsArrayRowsPossible    = [];

p.rig.guiStatVals = { ...
    'iTrial'; ...
    'iGoodTrial'; ...
    'iAbortedTrial'; ...
    'missedFrames'; ...
    'moviePctComplete'; ...
    'totalSpikesAccum'; ...
    'fixBreakCount'; ...
    'nonStartCount'; ...
    'rewardCount'; ...
    'lastTrialDurS'; ...
    'meanFixHoldS'; ...
    };

%% user determines the 12 variables shown in gui upon init
p.rig.guiVars = { ...
    'rewardDurationMs'; ...     % 1
    'fixWinWidthDeg'; ...       % 2
    'fixWinHeightDeg'; ...      % 3
    'fixDegX'; ...              % 4
    'fixDegY'; ...              % 5
    'checkSizeDeg'; ...         % 6
    'noiseFrameHold'; ...       % 7
    'trialDurationS'; ...       % 8
    'clearPatchDeg'; ...        % 9
    'movieDurationMin'; ...     % 10
    'passEye'; ...              % 11
    'connectRipple'; ...        % 12
    };

%% TRIAL VARIABLES
% --- general / debug ---
p.trVarsInit.passJoy             = 1;       % always pass joystick (not used in this task)
p.trVarsInit.passEye             = 0;       % pass = 1; simulate fixation
p.trVarsInit.repeat              = 0;
p.trVarsInit.blockNumber         = 0;
p.trVarsInit.finish              = 5000;
p.trVarsInit.filesufix           = 1;
p.trVarsInit.joyVolt             = 0;
p.trVarsInit.eyeDegX             = 0;
p.trVarsInit.eyeDegY             = 0;
p.trVarsInit.eyePixX             = 0;
p.trVarsInit.eyePixY             = 0;
p.trVarsInit.flipIdx             = 1;

% --- noise stimulus parameters ---
p.trVarsInit.checkSizeDeg        = 2;     % check size in degrees of visual angle
p.trVarsInit.noiseFrameHold      = 6;       % display frames per noise frame (3 = 30ms at 100Hz)
p.trVarsInit.colorMode           = 1;       % 1 = luminance, 2 = rgb
p.trVarsInit.contrastBinary      = 1;       % 1 = binary (0/1), 0 = continuous uniform
p.trVarsInit.stimMode            = 2;       % 1 = dense (whole-field), 2 = sparse (isolated spots)
p.trVarsInit.nSparseSpots        = 5;       % spots per frame in sparse mode
p.trVarsInit.clearPatchDeg       = 1.0;     % diameter of clearing patch around fixation (0 = none)
p.trVarsInit.clearPatchShape     = 1;       % 1 = disk, 2 = square
p.trVarsInit.movieDurationMin    = 10;      % total noise movie duration (minutes)

% --- trial timing ---
p.trVarsInit.trialDurationS      = 1.5;     % noise presentation duration per trial (seconds)
p.trVarsInit.fixWaitDur          = 5.0;     % max wait for fixation acquisition (seconds)
p.trVarsInit.rewardDurationMs    = 280;     % reward duration on successful trial (ms)
p.trVarsInit.timeoutAfterFixBreak = 0.1;    % timeout after fixation break (seconds)
p.trVarsInit.postRewardDuration  = 0.1;     % post-reward period before trial end (seconds)

% --- fixation ---
p.trVarsInit.fixDegX             = 0;       % fixation X location in degrees
p.trVarsInit.fixDegY             = 0;       % fixation Y location in degrees
p.trVarsInit.fixWinWidthDeg      = 3.0;     % fixation window width (degrees)
p.trVarsInit.fixWinHeightDeg     = 3.0;     % fixation window height (degrees)
p.trVarsInit.fixPointRadPix      = 20;      % fixation point radius in pixels
p.trVarsInit.fixPointLinePix     = 12;      % fixation point line weight in pixels

% --- STA / Ripple ---
p.trVarsInit.connectRipple       = 1;       % attempt to connect to Ripple NIP?
p.trVarsInit.useOnlineSort       = 0;       % use online spike sorting from Ripple?
p.trVarsInit.useRippleSTA        = 1;       % compute online STA from Ripple data?
p.trVarsInit.nSTALags            = 8;       % number of temporal lags for STA
p.trVarsInit.nChannels           = 32;       % number of Ripple channels for STA

% --- state machine ---
p.trVarsInit.currentState        = p.state.trialBegun;
p.trVarsInit.exitWhileLoop       = false;

% --- noise presentation tracking ---
p.trVarsInit.noiseIsOn           = false;
p.trVarsInit.currentNoiseIdx     = 1;       % current noise frame index (within trial)
p.trVarsInit.noiseStartFlipIdx   = 0;       % flipIdx when noise started
p.trVarsInit.movieExhausted      = false;   % set true when noise movie is fully played

% --- postFlip ---
p.trVarsInit.postFlip.logical    = false;
p.trVarsInit.postFlip.varNames   = cell(0);

% --- online plots ---
p.trVarsInit.wantOnlinePlots     = false;

%% end of trVarsInit
p.trVarsGuiComm = p.trVarsInit;

%% trData - variables that acquire values during each trial
p.init.trDataInitList = { ...
    'p.trData.eyeX',                    '[]'; ...
    'p.trData.eyeY',                    '[]'; ...
    'p.trData.eyeP',                    '[]'; ...
    'p.trData.eyeT',                    '[]'; ...
    'p.trData.joyV',                    '[]'; ...
    'p.trData.dInValues',               '[]'; ...
    'p.trData.dInTimes',                '[]'; ...
    'p.trData.onlineEyeX',             '[]'; ...
    'p.trData.onlineEyeY',             '[]'; ...
    'p.trData.spikeTimes',             '[]'; ...
    'p.trData.spikeClusters',          '[]'; ...
    'p.trData.eventTimes',             '[]'; ...
    'p.trData.eventValues',            '[]'; ...
    'p.trData.timing.lastFrameTime',    '0'; ...
    'p.trData.timing.trialStartPTB',    '-1'; ...
    'p.trData.timing.trialStartDP',     '-1'; ...
    'p.trData.timing.trialBegin',       '-1'; ...
    'p.trData.timing.trialEnd',         '-1'; ...
    'p.trData.timing.fixOn',            '-1'; ...
    'p.trData.timing.fixAq',            '-1'; ...
    'p.trData.timing.noiseOn',          '-1'; ...
    'p.trData.timing.noiseOff',         '-1'; ...
    'p.trData.timing.fixBreak',         '-1'; ...
    'p.trData.timing.reward',           '-1'; ...
    'p.trData.timing.tone',             '-1'; ...
    'p.trData.timing.flipTime',         'zeros(1, 3000)'; ...
    'p.trData.trialEndState',           '0'; ...
    'p.trData.trialRepeatFlag',         'false'; ...
    };

p.init.nTrDataListRows = size(p.init.trDataInitList, 1);

%% draw parameters
p.draw.eyePosWidth          = 6;        % eye position indicator width in pixels
p.draw.fixPointWidth        = 4;        % fixation point line weight in pixels
p.draw.fixPointRadius       = 6;        % fixation point radius in pixels
p.draw.fixWinPenPre         = 4;        % fixation window pen width (before noise)
p.draw.fixWinPenPost        = 8;        % fixation window pen width (during noise)
p.draw.fixWinPenDraw        = [];       % assigned during run
p.draw.gridSpacing          = 2;
p.draw.gridW                = 2;
p.draw.joyRect              = [1705 900 1735 1100];
p.draw.cursorW              = 6;

%% datapixx
p.rig.dp.useDataPixxBool       = 1;
p.rig.dp.adcRate               = 1000;
p.rig.dp.maxDurADC             = 15;
p.rig.dp.adcBuffAddr           = 4e6;
p.rig.dp.dacRate               = 1000;
p.rig.dp.dacPadDur             = 0.01;
p.rig.dp.dacBuffAddr           = 10e6;
p.rig.dp.dacChannelOut         = 0;

%% CLUT - Color Look Up Table indices
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

%% COLORS (CLUT row assignments, updated during run)
p.draw.color.background = p.draw.clutIdx.expBg_subBg;
p.draw.color.cursor     = p.draw.clutIdx.expOrange_subBg;
p.draw.color.fix        = p.draw.color.background;
p.draw.color.fixWin     = p.draw.clutIdx.expGrey25_subBg;
p.draw.color.eyePos     = p.draw.clutIdx.expBlue_subBg;
p.draw.color.gridMajor  = p.draw.clutIdx.expGrey25_subBg;
p.draw.color.gridMinor  = p.draw.clutIdx.expGrey25_subBg;
p.draw.color.joyInd     = p.draw.clutIdx.expGrey90_subBg;

%% WHAT TO STROBE:
% Column 1: code name (must match a field in +pds/initCodes.m)
% Column 2: value expression (eval'd to get the value to strobe)
p.init.strobeList = { ...
    'taskCode',                 'p.init.taskCode'; ...
    'date_1yyyy',               'p.init.date_1yyyy'; ...
    'date_1mmdd',               'p.init.date_1mmdd'; ...
    'time_1hhmm',               'p.init.time_1hhmm'; ...
    'trialCount',               'p.status.iTrial'; ...
    'noiseCheckSize_x100',      'round(p.trVars.checkSizeDeg * 100)'; ...
    'noiseFrameHold',           'p.trVars.noiseFrameHold'; ...
    'noiseColorMode',           'p.trVars.colorMode'; ...
    'noiseRngSeed',             'double(mod(p.init.noiseRngSeed, 32768))'; ...
    'noiseRngSeedHigh',         'double(mod(floor(double(p.init.noiseRngSeed) / 32768), 32768))'; ...
    'noiseTrialFrameStart',     'min(p.trVars.trialStartFrame, 32767)'; ...
    'noiseTrialFrameEnd',       'min(p.trVars.trialEndFrame, 32767)'; ...
    'noiseTotalFrames',         'min(p.init.nNoiseFrames, 32767)'; ...
    'noiseGridW',               'p.init.noiseGridSize(2)'; ...
    'noiseGridH',               'p.init.noiseGridSize(1)'; ...
    'noiseStimMode',            'p.trVars.stimMode'; ...
    'noiseNSparseSpots',        'p.trVars.nSparseSpots'; ...
    };

end
