function p = barsweep_cardinal4_settings
%  p = barsweep_cardinal4_settings
%
%  Translating-bar receptive-field-mapping task, cardinal-4 regime.
%  Passive fixation, one bar sweep per trial. Direction is drawn without
%  replacement from a fixed angle list (default [0 90 180 270]); the
%  session ends when every angle has been rewarded setRepeats times.
%
%  The companion file barsweep_rfmap12_settings.m wraps this one and
%  switches to a 12-direction schedule (0:30:330) for filtered
%  back-projection RF reconstruction.
%
% Part of the quintet of pldaps functions:
%   settings function
%   init function
%   next function (before each trial)
%   run function (each trial)
%   finish function (after each trial)

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

assert(~isempty(p.init.rigConfigFile), ...
    ['barsweep_cardinal4_settings: failed to resolve rigConfigFile from hostname ' ...
     '"' strtrim(p.init.pcName) '". Expected rigConfigFiles.rigConfig_rigN ' ...
     'on the path with N derived from pcName(end-1).']);

p.init.useDataPixxBool = true;

%% define task name and related files:
p.init.taskName         = 'barsweep';
p.init.taskType         = 1;

% exptType selects the angle schedule and online-RF reconstruction strategy.
% cardinal4 uses [0 90 180 270] and reconstructs 1D x/y profiles + a
% separable 2D outer product. rfmap12 uses 0:30:330 and reconstructs a
% 2D RF image via iradon (filtered back-projection).
p.init.exptType         = 'barsweep_cardinal4';
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
p.state.trialBegun        = 1;
p.state.showFix           = 2;
p.state.holdFixAndSweep   = 3;

% end states - aborted:
p.state.fixBreak          = 11;
p.state.nonStart          = 13;

% end states - success:
p.state.trialComplete     = 21;

%% STATUS VALUES
p.status.iTrial                     = 0;
p.status.iGoodTrial                 = 0;
p.status.iAbortedTrial              = 0;
p.status.missedFrames               = 0;
p.status.fixBreakCount              = 0;
p.status.nonStartCount              = 0;
p.status.rewardCount                = 0;
p.status.lastTrialDurS              = 0;
p.status.barsweepSetsCompleted      = 0;
p.status.barsweepPool               = [];
p.status.barsweepPoolAtTrialStart   = [];

p.rig.guiStatVals = { ...
    'iTrial'; ...
    'iGoodTrial'; ...
    'iAbortedTrial'; ...
    'missedFrames'; ...
    'fixBreakCount'; ...
    'nonStartCount'; ...
    'rewardCount'; ...
    'barsweepSetsCompleted'; ...
    'lastTrialDurS'; ...
    };

%% user determines the variables shown in gui upon init
p.rig.guiVars = { ...
    'rewardDurationMs'; ...     % 1
    'fixWinWidthDeg'; ...       % 2
    'fixWinHeightDeg'; ...      % 3
    'fixDegX'; ...              % 4
    'fixDegY'; ...              % 5
    'pathCenterXDeg'; ...       % 6
    'pathCenterYDeg'; ...       % 7
    'pathLengthDeg'; ...        % 8
    'speedDegPerSec'; ...       % 9
    'barWidthDeg'; ...          % 10
    'barLengthDeg'; ...         % 11
    'setRepeats'; ...           % 12
    };

%% TRIAL VARIABLES
% --- general / debug ---
p.trVarsInit.passJoy             = 1;       % always pass joystick (not used in this task)
p.trVarsInit.passEye             = 0;       % pass = 1; simulate fixation
p.trVarsInit.mouseEyeSim         = 0;       % use mouse to simulate eye
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

% --- sweep schedule and geometry (matches source defaults) ---
p.trVarsInit.setRepeats          = 50;      % rewarded sweeps per angle (frozen on first _next.m call)
p.trVarsInit.pathAngleDeg        = 0;       % resolved per trial from the schedule
p.trVarsInit.pathCenterXDeg      = 10;
p.trVarsInit.pathCenterYDeg      = 0;
p.trVarsInit.pathLengthDeg       = 70;
p.trVarsInit.speedDegPerSec      = 70;
p.trVarsInit.barWidthDeg         = 0.5;     % thickness (perpendicular to motion)
p.trVarsInit.barLengthDeg        = 80;      % total end-to-end length (1:1 mapping)

% --- stimulus appearance ---
p.trVarsInit.stimulusMode        = 1;       % 1 = noise, 2 = solid
p.trVarsInit.backgroundLumIdx    = 2;       % palette index
p.trVarsInit.barLumIdx           = 3;       % palette index (solid mode)
p.trVarsInit.noiseLumLowIdx      = 1;       % palette index (noise mode)
p.trVarsInit.noiseLumHighIdx     = 3;       % palette index (noise mode)
p.trVarsInit.noiseCheckSizeDeg   = 0.25;    % matches Stm.BarNoiseGrain_dva
p.trVarsInit.noiseFrameHold      = 1;       % display frames per noise update (constant in v1)

% --- trial timing ---
p.trVarsInit.fixWaitDur          = 5.0;     % max wait for fixation acquisition (s)
p.trVarsInit.rewardDurationMs    = 280;     % reward duration on successful trial (ms)
p.trVarsInit.timeoutAfterFixBreak = 0.5;    % timeout after fixation break / non-start (s)
p.trVarsInit.postRewardDuration  = 0.1;     % post-reward period before iti (s)
p.trVarsInit.iti                 = 0.5;     % inter-trial interval (s, matches Stm.ITI = 500 ms)

% --- fixation drawing ---
p.trVarsInit.fixDegX             = 0;
p.trVarsInit.fixDegY             = 0;
p.trVarsInit.fixWinWidthDeg      = 4.0;
p.trVarsInit.fixWinHeightDeg     = 4.0;
p.trVarsInit.fixPointRadPix      = 6;
p.trVarsInit.fixPointLinePix     = 4;

% --- state machine ---
p.trVarsInit.currentState        = p.state.trialBegun;
p.trVarsInit.exitWhileLoop       = false;

% --- runtime status flags (not GUI-exposed) ---
p.trVarsInit.barsweepSessionDone = false;   % set true in _next.m when termination condition met

% --- Ripple / online RF mapping ---
% useOnlineRF = true keeps the RF accumulator alive; with Ripple unavailable
% the accumulation step is silently skipped (acceptance criterion #4).
% useOnlineSort must be 0 because pds.getRippleData populates spikeClusters
% with the channel index only when online sort is off; the RF accumulator
% keys off spikeClusters as channel index. barsweep_init.m enforces this.
p.trVarsInit.connectRipple       = 1;       % attempt to connect to Ripple NIP
p.trVarsInit.useOnlineSort       = 0;       % must be 0 for online RF mapping
p.trVarsInit.useOnlineRF         = true;    % run online RF estimator
p.trVarsInit.rfNChannels         = 32;      % number of Ripple channels for RF
p.trVarsInit.rfLatencyMs         = 40;      % response latency (ms); LGN default
p.trVarsInit.rfPosBinDeg         = 0.25;    % position-bin width (dva)
p.trVarsInit.rfMapExtentDeg      = 10;      % half-width of 2D output image (dva)
p.trVarsInit.rfRampFilter        = 'Hann';  % iradon filter (rfmap12 only)
p.trVarsInit.rfRampCutoff        = 0.5;     % iradon cutoff in [0,1] (rfmap12 only)
p.trVarsInit.rfSelectedChannel   = 1;       % channel rendered in detail panel
p.trVarsInit.rfDetectThresh      = 4.0;     % SNR (peak/noise-MAD) for "RF detected"
p.trVarsInit.barsweepPairShuffle = true;    % draw opposite-direction pairs together

% --- safety budgets (admission tests in nextParams.m) ---
p.trVarsInit.sweepFramesMax      = 600;     % refuses sweeps > ~6 s at 100 Hz
p.trVarsInit.noiseTextureBudgetBytes = 64 * 1024 * 1024;  % 64 MB cap on projected noise texel data per trial

% --- postFlip ---
p.trVarsInit.postFlip.logical    = false;
p.trVarsInit.postFlip.varNames   = cell(0);

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
    'p.trData.onlineEyeX',              '[]'; ...
    'p.trData.onlineEyeY',              '[]'; ...
    'p.trData.spikeTimes',              '[]'; ...
    'p.trData.spikeClusters',           '[]'; ...
    'p.trData.eventTimes',              '[]'; ...
    'p.trData.eventValues',             '[]'; ...
    'p.trData.timing.lastFrameTime',    '0'; ...
    'p.trData.timing.trialStartPTB',    '-1'; ...
    'p.trData.timing.trialStartDP',     '-1'; ...
    'p.trData.timing.trialBegin',       '-1'; ...
    'p.trData.timing.trialEnd',         '-1'; ...
    'p.trData.timing.trialRunDone',     '-1'; ...
    'p.trData.timing.fixOn',            '-1'; ...
    'p.trData.timing.fixAq',            '-1'; ...
    'p.trData.timing.stimOn',           '-1'; ...
    'p.trData.timing.stimOff',          '-1'; ...
    'p.trData.timing.fixBreak',         '-1'; ...
    'p.trData.timing.nonStart',         '-1'; ...
    'p.trData.timing.reward',           '-1'; ...
    'p.trData.timing.tone',             '-1'; ...
    'p.trData.timing.flipTime',         'zeros(1, 3000)'; ...
    'p.trData.timing.flipIdxStimOn',    '-1'; ...
    'p.trData.trialEndState',           '0'; ...
    'p.trData.trialRepeatFlag',         'false'; ...
    'p.trData.pathAngleDeg',            'NaN'; ...
    'p.trData.sweepCenterDeg',          '[NaN NaN]'; ...
    'p.trData.sweepStartPix',           '[NaN; NaN]'; ...
    'p.trData.sweepEndPix',             '[NaN; NaN]'; ...
    'p.trData.sweepFrames',             '0'; ...
    'p.trData.sweepDurationS_nominal',  'NaN'; ...
    'p.trData.sweepDurationS_visible',  'NaN'; ...
    'p.trData.sweepDurationS_motion',   'NaN'; ...
    'p.trData.speedDegPerSec_realized', 'NaN'; ...
    'p.trData.barsweepPoolAtTrialStart','[]'; ...
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

%% Indexed luminance palette (1=dark, 2=mid, 3=light)
% Maps the v1 luminance indices to existing CLUT slots.
% The numeric values aren't strobed (rig CLUT is per-session-stable);
% offline analyses needing physical contrast join the strobe stream
% against the saved p.mat for that session.
p.stim.luminancePaletteClut = [ ...
    p.draw.clutIdx.expBlack_subBlack, ...
    p.draw.clutIdx.expBg_subBg, ...
    p.draw.clutIdx.expWhite_subWhite];

%% WHAT TO STROBE:
% Column 1: code name (must match a field in +pds/initCodes.m)
% Column 2: value expression (eval'd to get the value to strobe)
%
% Negative-safe encoding is applied at the expression level:
%   theta values: scale by 10, then add 1800 (range ±180° -> 0..3600)
%   pathAngleDeg is unsigned (0..360 wrap), scale by 10
% Length / radius / size values: scale and round to integer.
p.init.strobeList = { ...
    'taskCode',                    'p.init.taskCode'; ...
    'date_1yyyy',                  'p.init.date_1yyyy'; ...
    'date_1mmdd',                  'p.init.date_1mmdd'; ...
    'time_1hhmm',                  'p.init.time_1hhmm'; ...
    'trialCount',                  'p.status.iTrial'; ...
    'barsweepAngle_x10',           'round(mod(p.trVars.pathAngleDeg, 360) * 10)'; ...
    'barsweepCenterTheta_x10',     'round(atan2d(p.trVars.pathCenterYDeg, p.trVars.pathCenterXDeg) * 10) + 1800'; ...
    'barsweepCenterRadius_x100',   'round(hypot(p.trVars.pathCenterXDeg, p.trVars.pathCenterYDeg) * 100)'; ...
    'barsweepPathLength_x100',     'round(p.trVars.pathLengthDeg * 100)'; ...
    'barsweepSpeed_x100',          'round(p.trVars.speedDegPerSec * 100)'; ...
    'barsweepWidth_x100',          'round(p.trVars.barWidthDeg * 100)'; ...
    'barsweepLength_x100',         'round(p.trVars.barLengthDeg * 100)'; ...
    'barsweepFixTheta_x10',        'round(atan2d(p.trVars.fixDegY, p.trVars.fixDegX) * 10) + 1800'; ...
    'barsweepFixRadius_x100',      'round(hypot(p.trVars.fixDegX, p.trVars.fixDegY) * 100)'; ...
    'barsweepFixWinWidth_x100',    'round(p.trVars.fixWinWidthDeg * 100)'; ...
    'barsweepFixWinHeight_x100',   'round(p.trVars.fixWinHeightDeg * 100)'; ...
    'barsweepStimMode',            'p.trVars.stimulusMode'; ...
    'barsweepBgLumIdx',            'p.trVars.backgroundLumIdx'; ...
    'barsweepBarLumIdx',           'p.trVars.barLumIdx'; ...
    'barsweepNoiseLumLowIdx',      'p.trVars.noiseLumLowIdx'; ...
    'barsweepNoiseLumHighIdx',     'p.trVars.noiseLumHighIdx'; ...
    'barsweepNoiseGrain_x100',     'round(p.trVars.noiseCheckSizeDeg * 100)'; ...
    'barsweepExptType',            '1'; ...
    'barsweepRfLatency',           'round(p.trVars.rfLatencyMs)'; ...
    'barsweepRfPosBin_x100',       'round(p.trVars.rfPosBinDeg * 100)'; ...
    };

end
