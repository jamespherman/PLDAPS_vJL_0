function p = rfMap_commonSettings(p)
%   p = rfMap_commonSettings(p)
%
% Shared configuration for all rfMap stim types. Called from each
% per-stim-type settings file AFTER p.init.stimType has been set.
%
% Stim type codes (string  ->  integer for strobe wire format):
%     'denseAchromatic'  ->  1
%     'denseChromatic'   ->  2
%     'sparse'           ->  3
%     'checkerboard'     ->  4
%
% Per-stim-type settings files declare:
%   - p.init.stimType (string, set BEFORE calling this)
%   - any stim-type-specific p.trVarsInit overrides
%   - any stim-type-specific entries appended to p.init.strobeList

if ~isfield(p, 'init') || ~isfield(p.init, 'stimType')
    error('rfMap_commonSettings:missingStimType', ...
        ['p.init.stimType must be set before calling ' ...
         'rfMap_commonSettings. Set it in the per-stim-type ' ...
         'settings file (e.g. rfMap_denseAchromatic_settings).']);
end

%% determine which PC we're on for rig-specific settings:
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
p.init.taskName               = 'rfMap';
p.init.taskType               = 1;
p.init.pldapsFolder           = pwd;
p.init.protocol_title         = [p.init.taskName '_task'];
p.init.date                   = datestr(now, 'yyyymmdd');
p.init.time                   = datestr(now, 'HHMM');

p.init.date_1yyyy             = str2double(['1' datestr(now, 'yyyy')]);
p.init.date_1mmdd             = str2double(['1' datestr(now, 'mmdd')]);
p.init.time_1hhmm             = str2double(['1' datestr(now, 'HHMM')]);

% Schema version of the saved session (bumped on incompatible changes).
%   1: initial Phase-1 merge (denseAchromatic, sparse, denseChromatic
%      whole-session pre-rendered movie/drive).
%   2: chromatic switched to per-trial seeded generation. Drive tensor
%      and noiseMovie are no longer held at session level for
%      denseChromatic; offline analysis must read the per-trial
%      `chromaticSeed` column from p.init.trialsArray and call
%      recomputeDklDrive(seed, ...) per trial. Achromatic / sparse
%      schemes unchanged. checkSizeDeg default reduced from 2 dva to
%      0.5 dva (LGN-standard).
p.init.sessionFormatVersion   = 2;

% Map the stim type string to the integer used by the wire format. The
% lookup lives here so analysis tools can read either field; they should
% prefer the string since it is self-describing.
p.init.stimTypeIntMap = struct( ...
    'denseAchromatic', 1, ...
    'denseChromatic',  2, ...
    'sparse',          3, ...
    'checkerboard',    4);
if ~isfield(p.init.stimTypeIntMap, p.init.stimType)
    error('rfMap_commonSettings:badStimType', ...
        ['p.init.stimType = ''%s'' is not one of: ' ...
         'denseAchromatic, denseChromatic, sparse, checkerboard'], ...
        p.init.stimType);
end
p.init.stimTypeInt = p.init.stimTypeIntMap.(p.init.stimType);

% output files: append stim type to sessionId so multi-mode sessions
% are unambiguous on disk.
p.init.outputFolder           = fullfile(p.init.pldapsFolder, 'output');
p.init.figureFolder           = fullfile(p.init.pldapsFolder, 'output', 'figures');
p.init.sessionId              = [p.init.date '_t' p.init.time '_' ...
    p.init.taskName '_' p.init.stimType];
p.init.sessionFolder          = fullfile(p.init.outputFolder, p.init.sessionId);

% quintet files (shared across all stim types):
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
p.state.trialBegun      = 1;
p.state.showFix         = 2;
p.state.holdFixAndPlay  = 3;
p.state.fixBreak        = 11;
p.state.nonStart        = 13;
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

%% gui variables (12 slots)
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

%% TRIAL VARIABLES (common across stim types)
% Notes on what is intentionally absent here:
%   - colorMode and stimMode (the old single-monolith fields) are gone.
%     Stim type lives in p.init.stimType, set per-type.
%   - Per-stim-type files override checkSizeDeg, contrastBinary, and
%     anything else that should differ by mode.

% --- general / debug ---
p.trVarsInit.passJoy             = 1;
p.trVarsInit.passEye             = 0;
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

% --- noise stimulus parameters (defaults shared by dense/sparse paths;
%     per-type files override as needed) ---
% checkSizeDeg = 0.5 deg matches the standard LGN dense-noise STA scale
% (Solomon et al., feng_LGN/stim_densenoise_color.m). Macaque parafoveal
% LGN RF centers are ~0.05-0.3 dva, so 0.5 dva checks resolve them.
% Bump to ~1 dva for SC sessions (larger RFs); 2 dva is a cortex-flavor
% choice and was the old (pre-LGN-tuning) default.
p.trVarsInit.checkSizeDeg        = 0.5;
p.trVarsInit.noiseFrameHold      = 6;       % display frames per noise frame
p.trVarsInit.contrastBinary      = 1;       % 1 = binary (0/1), 0 = continuous uniform
p.trVarsInit.clearPatchDeg       = 1.0;
p.trVarsInit.clearPatchShape     = 1;       % 1 = disk, 2 = square
p.trVarsInit.movieDurationMin    = 10;

% RNG seed for the noise movie. Pin to a known integer for bit-exact
% regression; pre-Phase-1 code used the broken
% rng('shuffle')-and-grab-previous-state idiom that always saved 0.
% Per-stim-type files may override.
p.trVarsInit.noiseRngSeed        = 12345;

% Legacy uniform-random vs balanced TwinDeck for sparse. 1 = legacy,
% 2 = balanced. Only consumed when stimType is 'sparse'.
p.trVarsInit.sparseBalancedFlag  = 2;

% --- trial timing ---
p.trVarsInit.trialDurationS      = 1.5;
p.trVarsInit.fixWaitDur          = 5.0;
p.trVarsInit.rewardDurationMs    = 280;
p.trVarsInit.timeoutAfterFixBreak = 0.1;
p.trVarsInit.postRewardDuration  = 0.1;

% --- fixation ---
p.trVarsInit.fixDegX             = 0;
p.trVarsInit.fixDegY             = 0;
p.trVarsInit.fixWinWidthDeg      = 3.0;
p.trVarsInit.fixWinHeightDeg     = 3.0;
p.trVarsInit.fixPointRadPix      = 20;
p.trVarsInit.fixPointLinePix     = 12;

% --- STA / Ripple ---
p.trVarsInit.connectRipple       = 0;
p.trVarsInit.useOnlineSort       = 0;
p.trVarsInit.useRippleSTA        = 0;
p.trVarsInit.nSTALags            = 8;
p.trVarsInit.nChannels           = 32;

% Online-plot throttling. Plotter renders only on schedule; accumulators
% update every trial regardless.
p.trVarsInit.staPlotEveryNTrials = 5;
p.trVarsInit.staPlotChannels     = [];      % [] = all channels

% --- state machine ---
p.trVarsInit.currentState        = p.state.trialBegun;
p.trVarsInit.exitWhileLoop       = false;

% --- noise presentation tracking ---
p.trVarsInit.noiseIsOn           = false;
p.trVarsInit.currentNoiseIdx     = 1;
p.trVarsInit.noiseStartFlipIdx   = 0;
p.trVarsInit.movieExhausted      = false;

% --- postFlip ---
p.trVarsInit.postFlip.logical    = false;
p.trVarsInit.postFlip.varNames   = cell(0);

% --- online plots ---
p.trVarsInit.wantOnlinePlots     = false;

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
p.draw.eyePosWidth          = 6;
p.draw.fixPointWidth        = 4;
p.draw.fixPointRadius       = 6;
p.draw.fixWinPenPre         = 4;
p.draw.fixWinPenPost        = 8;
p.draw.fixWinPenDraw        = [];
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

%% WHAT TO STROBE: shared base list
% Per-stim-type settings files MAY append additional entries (e.g., DKL
% params for chromatic, check params for checkerboard, sparse-balanced
% flag for sparse).
%
% Removed vs the pre-merge strobeList:
%   noiseColorMode (16105)  -> superseded by rfMapStimType (16140)
%   noiseStimMode  (16113)  -> superseded by rfMapStimType (16140)
% Both old codes are kept reserved-but-deprecated in +pds/initCodes.m.
p.init.strobeList = { ...
    'taskCode',                 'p.init.taskCode'; ...
    'date_1yyyy',               'p.init.date_1yyyy'; ...
    'date_1mmdd',               'p.init.date_1mmdd'; ...
    'time_1hhmm',               'p.init.time_1hhmm'; ...
    'trialCount',               'p.status.iTrial'; ...
    'rfMapStimType',            'p.init.stimTypeInt'; ...
    'rfMapSessionFormatVersion','p.init.sessionFormatVersion'; ...
    'noiseCheckSize_x100',      'round(p.trVars.checkSizeDeg * 100)'; ...
    'noiseFrameHold',           'p.trVars.noiseFrameHold'; ...
    'noiseRngSeed',             'double(mod(p.init.noiseRngSeed, 32768))'; ...
    'rfMapRngSeedHigh',         'double(mod(floor(double(p.init.noiseRngSeed) / 32768), 32768))'; ...
    'noiseTrialFrameStart',     'min(p.trVars.trialStartFrame, 32767)'; ...
    'noiseTrialFrameEnd',       'min(p.trVars.trialEndFrame, 32767)'; ...
    'noiseTotalFrames',         'min(p.init.nNoiseFrames, 32767)'; ...
    'noiseGridW',               'p.init.noiseGridSize(2)'; ...
    'noiseGridH',               'p.init.noiseGridSize(1)'; ...
    };

% Note: p.trVarsGuiComm assignment is left to the per-stim-type settings
% file, since it must capture the per-type overrides that come AFTER
% this common block runs.

end
