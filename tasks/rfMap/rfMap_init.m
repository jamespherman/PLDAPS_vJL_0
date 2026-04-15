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

%% (1) define rig-specific information
p = pds.initRigConfigFile(p);

%% (2) define color look-up-table (lut)
p = initClut(p);

%% (3) initialize VIEWPixx/DATAPixx
p = pds.initDataPixx(p);

%% (4) define audio waveforms and load to VIEWPixx
p = pds.initAudio(p);

%% (5) define trial structure
p = initTrialStructure(p);

%% (6) initialize connection to Ripple
p = pds.initRipple(p);

%% (7) pre-generate full noise movie
p = generateNoiseMovieForTask(p);

%% (8) initialize STA accumulators
p = initSTAAccumulators(p);

%% (9) create online STA display figure (if Ripple STA enabled)
if p.trVarsInit.useRippleSTA
    noiseFrameDurMs = p.trVarsInit.noiseFrameHold * p.rig.frameDuration * 1000;
    p.init.staFigData = initSTADisplay(p.trVarsInit.nSTALags, ...
        p.trVarsInit.nChannels, noiseFrameDurMs);
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

%% (14) initialize random seed
RandStream.setGlobalStream(RandStream('mt19937ar', 'Seed', 0));

end

%% ---- Local functions ----

function p = generateNoiseMovieForTask(p)
% Generate the full noise movie and store in p.init

% Compute grid size from rig geometry.
% Use deg2pix to get check size in pixels, then divide screen by that.
checkSizePix = pds.deg2pix(p.trVarsInit.checkSizeDeg, p);
if checkSizePix < 1, checkSizePix = 1; end
screenWidthPix  = p.draw.screenRect(3);
screenHeightPix = p.draw.screenRect(4);
nChecksX = ceil(screenWidthPix  / checkSizePix);
nChecksY = ceil(screenHeightPix / checkSizePix);

% Compute total noise frames
frameDurS = p.trVarsInit.noiseFrameHold * p.rig.frameDuration;
nNoiseFrames = ceil(p.trVarsInit.movieDurationMin * 60 / frameDurS);

% Color mode string
if p.trVarsInit.colorMode == 1
    colorModeStr = 'luminance';
else
    colorModeStr = 'rgb';
end

% Generate movie
[p.init.noiseMovie, p.init.noiseRngSeed] = generateNoiseMovie( ...
    nChecksY, nChecksX, nNoiseFrames, ...
    colorModeStr, logical(p.trVarsInit.contrastBinary), []);

% Store metadata
p.init.noiseGridSize  = [nChecksY, nChecksX];
p.init.nNoiseFrames   = nNoiseFrames;
p.init.noiseFrameIdx  = 1;  % playback position (advances on successful trials)

fprintf('Noise grid: %d x %d checks, %d total frames\n', ...
    nChecksY, nChecksX, nNoiseFrames);

end

function p = initSTAAccumulators(p)
% Allocate STA accumulator arrays

nCh = p.trVarsInit.nChannels;
nLags = p.trVarsInit.nSTALags;
nY = p.init.noiseGridSize(1);
nX = p.init.noiseGridSize(2);

p.init.staAccum = cell(nCh, 1);
for ch = 1:nCh
    p.init.staAccum{ch} = zeros(nY, nX, nLags);
end
p.init.staSpikeCount = zeros(nCh, 1);

fprintf('STA accumulators initialized: %d channels, %d lags\n', nCh, nLags);

end
