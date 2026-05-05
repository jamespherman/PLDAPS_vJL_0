function p = rfMap_init(p)
%   p = rfMap_init(p)
%
% Part of the quintet of pldaps functions:
%   settings function
%   init function
%   next function (before each trial)
%   run function (each trial)
%   finish function (after each trial)
%
% Initialization function for rfMap task. Executed once after settings.
% Dispatches stim-type-specific generators by reading p.init.stimType
% (set by which rfMap_<stimType>_settings.m was loaded).

%% (1) define rig-specific information
p = pds.initRigConfigFile(p);

%% (2) define color look-up-table (lut)
% For chromatic mode, initClut also installs the 8 tri-noise palette
% slots (and saves p.init.chromaticClutBase / chromaticPaletteRGB /
% chromaticStateBits). pds.initDataPixx then loads the full CLUT to
% the VPixx in the usual single Screen('LoadNormalizedGammaTable') call.
p = initClut(p);

%% (3) initialize VIEWPixx/DATAPixx
p = pds.initDataPixx(p);

%% (4) define audio waveforms and load to VIEWPixx
p = pds.initAudio(p);

%% (5) define trial structure
p = initTrialStructure(p);

%% (6) initialize connection to Ripple
p = pds.initRipple(p);

%% (7) pre-generate the stimulus by stim type (dispatcher)
p = generateStimForTask(p);

%% (8) initialize STA accumulators
p = initSTAAccumulators(p);

%% (9) create online STA display figure (if Ripple STA enabled)
if p.trVarsInit.useRippleSTA
    noiseFrameDurMs = p.trVarsInit.noiseFrameHold * p.rig.frameDuration * 1000;
    if strcmp(p.init.stimType, 'denseChromatic')
        nAxesDisplay = 3;
    else
        nAxesDisplay = 1;
    end
    p.init.staFigData = initSTADisplay(p.trVarsInit.nSTALags, ...
        p.trVarsInit.nChannels, noiseFrameDurMs, nAxesDisplay);
end

%% (10) define grid lines for experimenter display
p = pds.defineGridLines(p);

%% (11) define online-plotting windows (and reposition others)
p = plotWindowSetup(p);

%% (12) set task codes
p.init.codes = pds.initCodes;
p.init.taskCode = 32020;  % unique task code for rfMap (= LGN_RF_mapping)

%% (13) define classyStrobe
p.init.strb = pds.classyStrobe;

%% (14) initialize global random stream (post-stimulus-generation)
% Rationale: per-trial randomness (e.g., next-trial selection in
% nextParams.m) lives on the global stream. Stimulus generation runs
% earlier and pins its own seed via p.init.noiseRngSeed; resetting the
% global stream here does not affect the saved movie.
RandStream.setGlobalStream(RandStream('mt19937ar', 'Seed', 0));

end

%% ---- Local functions ----

function p = generateStimForTask(p)
% Dispatch to per-stim-type generator. p.init.stimType is set by
% rfMap_<stimType>_settings.m and validated in rfMap_commonSettings.m.

% Compute grid size from rig geometry.
checkSizePix    = pds.deg2pix(p.trVarsInit.checkSizeDeg, p);
if checkSizePix < 1, checkSizePix = 1; end
screenWidthPix  = p.draw.screenRect(3);
screenHeightPix = p.draw.screenRect(4);
nChecksX        = ceil(screenWidthPix  / checkSizePix);
nChecksY        = ceil(screenHeightPix / checkSizePix);

% Compute total noise frames
frameDurS    = p.trVarsInit.noiseFrameHold * p.rig.frameDuration;
nNoiseFrames = ceil(p.trVarsInit.movieDurationMin * 60 / frameDurS);

% Pin the seed used for the movie. The post-merge contract is that
% p.init.noiseRngSeed is set by rfMap_commonSettings.m (or overridden
% by a per-stim-type settings file) BEFORE generation, and the same
% value is what generators consume and what is strobed/saved.
p.init.noiseRngSeed = p.trVarsInit.noiseRngSeed;

switch p.init.stimType
    case 'denseAchromatic'
        p.init.noiseMovie = generateStim_denseAchromatic( ...
            nChecksY, nChecksX, nNoiseFrames, ...
            logical(p.trVarsInit.contrastBinary), ...
            p.init.noiseRngSeed);

    case 'sparse'
        p.init.noiseMovie = generateStim_sparseBalanced( ...
            nChecksY, nChecksX, nNoiseFrames, ...
            p.trVarsInit.nSparseSpots, ...
            p.init.noiseRngSeed);

    case 'denseChromatic'
        [p.init.noiseMovie, p.init.dklDriveTensor] = ...
            generateStim_denseChromatic( ...
                nChecksY, nChecksX, nNoiseFrames, ...
                p.trVarsInit.dklAxes, p.trVarsInit.dklContrasts, ...
                p.init.noiseRngSeed);

    case 'checkerboard'
        % Phase-3 stub. Function errors clearly.
        p.init.checkerboardTextures = prepareStim_checkerboard( ...
            p.trVarsInit.checkSizesDva, p.trVarsInit.checkContrasts, ...
            screenWidthPix, screenHeightPix, ...
            p.rig.PixPerDeg, p.init.noiseRngSeed);
        p.init.noiseMovie = [];

    otherwise
        error('rfMap_init:badStimType', ...
            ['Unrecognized p.init.stimType = ''%s''. Expected one of: ' ...
             'denseAchromatic, denseChromatic, sparse, checkerboard.'], ...
            p.init.stimType);
end

% Store metadata
p.init.noiseGridSize  = [nChecksY, nChecksX];
p.init.nNoiseFrames   = nNoiseFrames;
p.init.noiseFrameIdx  = 1;

fprintf('rfMap stimType=%s: %d x %d checks, %d total frames\n', ...
    p.init.stimType, nChecksY, nChecksX, nNoiseFrames);

end

function p = initSTAAccumulators(p)
% Allocate STA accumulator arrays.
%   Spatial-map estimators (denseAchromatic, sparse): [nY, nX, nLags]
%   Chromatic estimator (denseChromatic):             [nY, nX, 3, nLags]
%   Checkerboard (Phase 3):                           allocated by Phase 3.

nCh   = p.trVarsInit.nChannels;
nLags = p.trVarsInit.nSTALags;
nY    = p.init.noiseGridSize(1);
nX    = p.init.noiseGridSize(2);

p.init.staAccum = cell(nCh, 1);
switch p.init.stimType
    case {'denseAchromatic', 'sparse'}
        for ch = 1:nCh
            p.init.staAccum{ch} = zeros(nY, nX, nLags);
        end
    case 'denseChromatic'
        for ch = 1:nCh
            p.init.staAccum{ch} = zeros(nY, nX, 3, nLags);
        end
    case 'checkerboard'
        % Phase 3 will allocate per-condition / per-channel buffers.
        for ch = 1:nCh
            p.init.staAccum{ch} = [];
        end
    otherwise
        error('rfMap_init:initSTAAccumulators:badStimType', ...
            'Unrecognized stimType ''%s''.', p.init.stimType);
end
p.init.staSpikeCount = zeros(nCh, 1);

fprintf('STA accumulators initialized: %d channels, %d lags (stimType=%s)\n', ...
    nCh, nLags, p.init.stimType);

end
