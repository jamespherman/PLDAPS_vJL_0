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

%% (3b) derive noiseFrameHold from the target noise update rate.
% Settings declare a rig-rate-independent target Hz; we round to the
% nearest integer hold length now that p.rig.refreshRate is populated.
% Skipped for checkerboard, which is reversal-driven (noiseFrameHold
% pinned to 1 in rfMap_checkerboard_settings).
if ~strcmp(p.init.stimType, 'checkerboard')
    if ~isfield(p.trVarsInit, 'noiseTargetUpdateHz') || ...
            ~isfinite(p.trVarsInit.noiseTargetUpdateHz) || ...
            p.trVarsInit.noiseTargetUpdateHz <= 0
        error('rfMap_init:badTargetHz', ...
            ['p.trVarsInit.noiseTargetUpdateHz must be a positive ' ...
             'finite number for stimType=%s. Set it in commonSettings ' ...
             'or the per-stim-type settings file.'], p.init.stimType);
    end
    nfh = round(p.rig.refreshRate / p.trVarsInit.noiseTargetUpdateHz);
    p.trVarsInit.noiseFrameHold    = nfh;
    p.trVars.noiseFrameHold        = nfh;
    p.trVarsGuiComm.noiseFrameHold = nfh;
    fprintf(['rfMap_init: noiseFrameHold = %d (target %.1f Hz, ' ...
             'actual %.2f Hz at %.2f Hz refresh)\n'], ...
        nfh, p.trVarsInit.noiseTargetUpdateHz, ...
        p.rig.refreshRate / nfh, p.rig.refreshRate);
end

%% (4) define audio waveforms and load to VIEWPixx
p = pds.initAudio(p);

%% (5) define trial structure
p = initTrialStructure(p);

%% (6) initialize connection to Ripple and set thresholds
p = pds.initRipple(p);
p = pds.setSpikeThreshFromRMS(p);

%% (7) pre-generate the stimulus by stim type (dispatcher)
p = generateStimForTask(p);

%% (8) initialize STA accumulators
p = initSTAAccumulators(p);

%% (9) create online STA display figure (if Ripple STA enabled)
if p.trVarsInit.useRippleSTA
    switch p.init.stimType
        case 'checkerboard'
            % Different layout entirely: kernel grid + F1/F2 bars.
            % Display frames are the lag unit for checkerboard, so
            % frameDurMs is 1/refreshRate in ms.
            displayFrameMs = p.rig.frameDuration * 1000;
            p.init.staFigData = initSTADisplay_checkerboard( ...
                p.trVarsInit.nSTALags, p.trVarsInit.nChannels, ...
                displayFrameMs, p.init.checkInfo.nCheckSize, ...
                p.init.checkInfo.nContrast, ...
                p.trVarsInit.checkSizesDva, ...
                p.trVarsInit.checkContrasts);
        otherwise
            noiseFrameDurMs = p.trVarsInit.noiseFrameHold * ...
                p.rig.frameDuration * 1000;
            if strcmp(p.init.stimType, 'denseChromatic')
                nAxesDisplay = 3;
            else
                nAxesDisplay = 1;
            end
            p.init.staFigData = initSTADisplay(p.trVarsInit.nSTALags, ...
                p.trVarsInit.nChannels, noiseFrameDurMs, nAxesDisplay);
    end
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
        % Per-trial generation: nextParams.m regenerates this trial's
        % noiseMovie + dklDriveTensor from the trial-array's per-trial
        % seed (column 'chromaticSeed' set in initTrialStructure).
        % Session-level fields stay empty -- the drive tensor at LGN
        % grid sizes (~88 x 136) for a full 10-min session would be
        % ~8.6 GB in single precision; per-trial it is ~70 MB and
        % gc'd at the end of each trial. sessionFormatVersion = 2
        % marks this scheme.
        p.init.noiseMovie      = [];
        p.init.dklDriveTensor  = [];

    case 'checkerboard'
        % Phase 3: pre-render indexed checkerboard texture data per
        % (checkSize, contrast) condition. Convert dva -> pixels here
        % via pds.deg2pix (codebase convention; no p.rig.PixPerDeg
        % field).
        checkSizesPix = arrayfun(@(d) pds.deg2pix(d, p), ...
            p.trVarsInit.checkSizesDva);
        p.init.checkInfo = prepareStim_checkerboard( ...
            p.trVarsInit.checkSizesDva, p.trVarsInit.checkContrasts, ...
            screenWidthPix, screenHeightPix, checkSizesPix, ...
            p.rig.refreshRate, p.trVarsInit.checkReversalHz, ...
            p.init.checkerboardLowSlots, p.init.checkerboardHighSlots, ...
            p.trVarsInit.checkGpuMemCapBytes);
        p.init.checkInfo = uploadCheckerboardTextures(p, p.init.checkInfo);
        p.init.noiseMovie = [];

    otherwise
        error('rfMap_init:badStimType', ...
            ['Unrecognized p.init.stimType = ''%s''. Expected one of: ' ...
             'denseAchromatic, denseChromatic, sparse, checkerboard.'], ...
            p.init.stimType);
end

% Store metadata
p.init.noiseGridSize   = [nChecksY, nChecksX];
p.init.nNoiseFrames    = nNoiseFrames;
p.init.noiseFrameIdx   = 1;
p.init.noiseCycleCount = 0;   % # times the cursor has wrapped (movie modes)

fprintf('rfMap stimType=%s: %d x %d checks, %d total frames\n', ...
    p.init.stimType, nChecksY, nChecksX, nNoiseFrames);

end


function checkInfo = uploadCheckerboardTextures(p, checkInfo)
% Upload the pre-computed checkerboard texture data matrices to PTB.
% Returns checkInfo with .textures (nCheckSize x nContrast x 2) of
% Screen('MakeTexture') handles. The original .textureData is cleared
% to free MATLAB-side memory.
texHandles = zeros(checkInfo.nCheckSize, checkInfo.nContrast, 2);
for sz = 1:checkInfo.nCheckSize
    for ct = 1:checkInfo.nContrast
        for pol = 1:2
            texHandles(sz, ct, pol) = Screen('MakeTexture', ...
                p.draw.window, checkInfo.textureData{sz, ct, pol});
        end
    end
end
checkInfo.textures    = texHandles;
checkInfo.textureData = [];   % free CPU-side memory; data is on GPU now

% Destination rect: each condition's texture is screen-sized (or
% larger), centered.
checkInfo.destRect = p.draw.screenRect;
end

function p = initSTAAccumulators(p)
% Allocate STA accumulator arrays. Layout depends on stim type:
%   denseAchromatic / sparse: cell {nCh,1} of [nY, nX, nLags]
%   denseChromatic:           cell {nCh,1} of [nY, nX, 3, nLags]
%   checkerboard:             struct with temporalKernel, f1f2AmpSum,
%                             spikeCountPerCondCh, f1f2TrialCount
%                             (the dispatcher hands the struct directly
%                             to updateSTA_checkerboard).

nCh   = p.trVarsInit.nChannels;
nLags = p.trVarsInit.nSTALags;

switch p.init.stimType
    case {'denseAchromatic', 'sparse'}
        nY = p.init.noiseGridSize(1);
        nX = p.init.noiseGridSize(2);
        p.init.staAccum = cell(nCh, 1);
        for ch = 1:nCh
            p.init.staAccum{ch} = zeros(nY, nX, nLags);
        end
        p.init.staSpikeCount = zeros(nCh, 1);

    case 'denseChromatic'
        nY = p.init.noiseGridSize(1);
        nX = p.init.noiseGridSize(2);
        p.init.staAccum = cell(nCh, 1);
        for ch = 1:nCh
            p.init.staAccum{ch} = zeros(nY, nX, 3, nLags);
        end
        p.init.staSpikeCount = zeros(nCh, 1);

    case 'checkerboard'
        nCkSz = p.init.checkInfo.nCheckSize;
        nCt   = p.init.checkInfo.nContrast;
        p.init.staAccum = struct( ...
            'temporalKernel',       zeros(nLags, nCkSz, nCt, nCh), ...
            'spikeCountPerCondCh',  zeros(nCkSz, nCt, nCh), ...
            'f1f2AmpSum',           zeros(2, nCkSz, nCt, nCh), ...
            'f1f2TrialCount',       zeros(nCkSz, nCt));
        % staSpikeCount kept for code-path compatibility (rfMap_finish
        % reads it for the run-summary print and status display).
        p.init.staSpikeCount = zeros(nCh, 1);

    otherwise
        error('rfMap_init:initSTAAccumulators:badStimType', ...
            'Unrecognized stimType ''%s''.', p.init.stimType);
end

fprintf('STA accumulators initialized: %d channels, %d lags (stimType=%s)\n', ...
    nCh, nLags, p.init.stimType);

end
