function results = test_simMode()
% test_simMode  In-repo validation of the rfMap simulation harness.
%
%   results = test_simMode
%
% Constructs a minimal `p` struct (no PTB / DataPixx / Ripple), populates
% the fields that simInitKernelBank + simulateRippleData + accumulateSTA
% depend on, runs ~20 trials per stim type, and reports the pass criteria
% from SIM_MODE_PLAN.md:
%
%   1. After ~20 trials of denseAchromatic, recovered RFs are localized
%      at the template centers (median location error <= ~1 check-size).
%   2. denseChromatic produces sensible per-channel RFs near templates.
%   3. checkerboard temporal kernels recover the per-condition gain
%      gradient (highest contrast / smallest size shows the largest
%      |kernel| at the peak lag).
%
% Run from MATLAB:  cd <repo>/tasks/rfMap/_validation;  test_simMode

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', 'supportFunctions'));
addpath(fullfile(thisDir, '..', '..', '..'));   % repo root for +pds

results = struct();

fprintf('\n=== test_simMode ===\n');
results.denseAchromatic = runOneType('denseAchromatic', 20);
results.denseChromatic  = runOneType('denseChromatic',  20);
results.checkerboard    = runOneType('checkerboard',    36);

fprintf('\n=== test_simMode SUMMARY ===\n');
fprintf('denseAchromatic: median locErr %.2f checks (pass <= 1.5)\n', ...
    results.denseAchromatic.medianLocErrChecks);
fprintf('denseChromatic:  median locErr %.2f checks (pass <= 1.5)\n', ...
    results.denseChromatic.medianLocErrChecks);
fprintf('checkerboard:    contrast slope = %.3f (positive => pass)\n', ...
    results.checkerboard.contrastTuningSlope);
end


function out = runOneType(stimType, nTrials)
fprintf('\n--- %s (%d trials) ---\n', stimType, nTrials);

p = buildSimP(stimType);
p.trVarsInit.useSimulatedSpikes = true;
p = simulateInitPipeline(p);
p = simInitKernelBank(p);

for iTrial = 1:nTrials
    p = simulateNext(p, iTrial);
    p = simulateRippleData(p);
    p = simulateFinishAccumulate(p);
end

recovered = computeRFCenters(p);
bank = p.init.simKernelBank;
templateXY = nan(bank.nChannels, 2);
for ch = 1:bank.nSimulated
    k = bank.kernels{ch};
    if isempty(k), continue; end
    if isfield(k, 'rfCenterFixFrame')
        templateXY(ch, :) = k.rfCenterFixFrame;
    end
end

checkSizeDeg = p.trVarsInit.checkSizeDeg;
simIdx = 1:bank.nSimulated;
locErrDeg    = sqrt(sum((recovered - templateXY).^2, 2));
locErrChecks = locErrDeg / checkSizeDeg;
medianErr = median(locErrChecks(simIdx), 'omitnan');

fprintf('  ch | spikes | template (x,y) dva | recovered (x,y) dva | err (chk)\n');
for ch = simIdx(1:min(8, numel(simIdx)))
    fprintf('  %2d | %5d  | (%+4.1f, %+4.1f)        | (%+5.2f, %+5.2f)      | %.2f\n', ...
        ch, p.init.staSpikeCount(ch), ...
        templateXY(ch,1), templateXY(ch,2), ...
        recovered(ch,1), recovered(ch,2), locErrChecks(ch));
end
fprintf('  Median location error: %.2f checks (target <= 1)\n', medianErr);
fprintf('  Mean spike count / simulated channel: %.0f\n', ...
    mean(p.init.staSpikeCount(simIdx)));

out = struct();
out.p = p; out.recoveredCentersDeg = recovered; out.templateXY = templateXY;
out.locErrChecks = locErrChecks; out.medianLocErrChecks = medianErr;
out.stimType = stimType;

if strcmp(stimType, 'checkerboard')
    tk = p.init.staAccum.temporalKernel;
    spc = p.init.staAccum.spikeCountPerCondCh;
    nSz = size(tk, 2); nCt = size(tk, 3);
    kernelPeak = zeros(nSz, nCt);
    for sz = 1:nSz
        for ct = 1:nCt
            chKern = squeeze(tk(:, sz, ct, simIdx));
            chCounts = squeeze(spc(sz, ct, simIdx));
            valid = chCounts > 0;
            if any(valid)
                normalized = chKern(:, valid) ./ reshape(chCounts(valid), 1, []);
                kernelPeak(sz, ct) = mean(max(abs(normalized), [], 1));
            end
        end
    end
    fprintf('  kernel peak |amp| by (sz, ct):\n'); disp(kernelPeak);
    if nCt >= 2
        out.contrastTuningSlope = kernelPeak(1, end) - kernelPeak(1, 1);
    else
        out.contrastTuningSlope = 0;
    end
    out.kernelPeak = kernelPeak;
end
end


function p = buildSimP(stimType)
p = struct;
p.init.stimType = stimType;
p = rfMap_commonSettings_offline(p);
switch stimType
    case 'denseChromatic'
        p.trVarsInit.dklAxes      = [1 2 3];
        p.trVarsInit.dklContrasts = 0.45;
        p.trVarsInit.noiseTargetUpdateHz = 10;
    case 'checkerboard'
        p.trVarsInit.checkSizesDva   = [0.5 1.0 2.0];
        p.trVarsInit.checkContrasts  = [0.25 0.5 1.0];
        p.trVarsInit.checkReversalHz = 5;
        p.trVarsInit.noiseFrameHold  = 1;
        p.trVarsInit.trialDurationS  = 2;
        p.trVarsInit.nSTALags        = 24;
end
p.trVarsGuiComm = p.trVarsInit;
p.trVars = p.trVarsInit;
end


function p = rfMap_commonSettings_offline(p)
% Minimal subset of rfMap_commonSettings sufficient for sim mode.
% Uses checkSizeDeg = 2 (current production default per recent commit
% 0a3622a2). The simInitKernelBank kernel templates are designed for
% this scale -- sigmaC = 0.3-0.5 dva, so the spatial kernel is
% effectively a delta on a 2-dva grid. With this geometry, the STA
% noise floor on a 360-pixel grid is small enough that recovery within
% ~20 trials is robust. At finer grids (e.g., LGN-scale 0.5 dva), the
% kernel spans a few pixels and recovery requires more trials.
p.init.taskName = 'rfMap';
p.trVarsInit.useSimulatedSpikes  = false;
p.trVarsInit.checkSizeDeg        = 2;
p.trVarsInit.noiseTargetUpdateHz = 12;
p.trVarsInit.noiseFrameHold      = NaN;
p.trVarsInit.trialDurationS      = 1.5;
p.trVarsInit.contrastBinary      = 1;
p.trVarsInit.movieDurationMin    = 10;
p.trVarsInit.noiseRngSeed        = 12345;
p.trVarsInit.useRippleSTA        = 1;
p.trVarsInit.nSTALags            = 8;
p.trVarsInit.nChannels           = 64;
p.trVarsInit.rfCenterThreshFrac  = 0.5;
p.trVarsInit.nSparseSpots        = 6;
p.trVarsInit.staPlotEveryNTrials = 5;

p.rig.frameDuration = 1/100;
p.rig.refreshRate   = 100;
p.rig.viewdist      = 57;
p.rig.screenh       = 30;
p.rig.screenhpix    = 1200;
p.draw.screenRect   = [0 0 1920 1200];
p.draw.middleXY     = [960, 600];
p.draw.fixPointPix  = p.draw.middleXY;

p.init.codes.stimOn   = 4001;
p.state.fixBreak      = 11;
p.state.nonStart      = 13;
p.state.noiseComplete = 21;
p.status.iTrial = 0; p.status.iGoodTrial = 0;
end


function p = simulateInitPipeline(p)
if ~strcmp(p.init.stimType, 'checkerboard')
    nfh = round(p.rig.refreshRate / p.trVarsInit.noiseTargetUpdateHz);
    p.trVarsInit.noiseFrameHold = nfh;
    p.trVars.noiseFrameHold     = nfh;
end

checkSizePix = pds.deg2pix(p.trVarsInit.checkSizeDeg, p);
if checkSizePix < 1, checkSizePix = 1; end
nX = ceil(p.draw.screenRect(3) / checkSizePix);
nY = ceil(p.draw.screenRect(4) / checkSizePix);
p.init.noiseGridSize = [nY, nX];

frameDurS = p.trVarsInit.noiseFrameHold * p.rig.frameDuration;
nNoise    = ceil(p.trVarsInit.movieDurationMin * 60 / frameDurS);
p.init.nNoiseFrames  = nNoise;
p.init.noiseFrameIdx = 1;

switch p.init.stimType
    case 'denseAchromatic'
        nGen = min(nNoise, 2000);
        p.init.noiseMovie = generateStim_denseAchromatic(nY, nX, nGen, ...
            true, p.trVarsInit.noiseRngSeed);
        p.init.nNoiseFrames = size(p.init.noiseMovie, 3);
    case 'sparse'
        nGen = min(nNoise, 2000);
        p.init.noiseMovie = generateStim_sparseBalanced(nY, nX, nGen, ...
            p.trVarsInit.nSparseSpots, p.trVarsInit.noiseRngSeed);
        p.init.nNoiseFrames = size(p.init.noiseMovie, 3);
    case 'denseChromatic'
        p.init.noiseMovie = [];
    case 'checkerboard'
        p.init.noiseMovie = [];
        p.init.checkInfo.nCheckSize = numel(p.trVarsInit.checkSizesDva);
        p.init.checkInfo.nContrast  = numel(p.trVarsInit.checkContrasts);
end

nCh = p.trVarsInit.nChannels; nLags = p.trVarsInit.nSTALags;
switch p.init.stimType
    case {'denseAchromatic', 'sparse'}
        p.init.staAccum = cell(nCh, 1);
        for ch = 1:nCh, p.init.staAccum{ch} = zeros(nY, nX, nLags); end
        p.init.staSpikeCount = zeros(nCh, 1);
    case 'denseChromatic'
        p.init.staAccum = cell(nCh, 1);
        for ch = 1:nCh, p.init.staAccum{ch} = zeros(nY, nX, 3, nLags); end
        p.init.staSpikeCount = zeros(nCh, 1);
    case 'checkerboard'
        nSz = p.init.checkInfo.nCheckSize; nCt = p.init.checkInfo.nContrast;
        p.init.staAccum = struct( ...
            'temporalKernel',      zeros(nLags, nSz, nCt, nCh), ...
            'spikeCountPerCondCh', zeros(nSz, nCt, nCh), ...
            'f1f2AmpSum',          zeros(2, nSz, nCt, nCh), ...
            'f1f2TrialCount',      zeros(nSz, nCt));
        p.init.staSpikeCount = zeros(nCh, 1);
end
p.init.lastRFCentersDeg = nan(nCh, 2);
end


function p = simulateNext(p, iTrial)
p.status.iTrial = iTrial;

if strcmp(p.init.stimType, 'checkerboard')
    dDur = p.rig.frameDuration;
    nF   = round(p.trVarsInit.trialDurationS / dDur);
    p.trVars.trialStartFrame  = 1;
    p.trVars.trialEndFrame    = nF;
    p.trVars.nFramesThisTrial = nF;
    p.trVars.noiseFrameDurS   = dDur;
    fpr = round(p.rig.refreshRate / p.trVarsInit.checkReversalHz);
    revBlock = floor((0:nF - 1) / fpr);
    p.trVars.checkPolaritySequence = int8(1 - 2 * mod(revBlock, 2));
    nSz = p.init.checkInfo.nCheckSize; nCt = p.init.checkInfo.nContrast;
    condIdx = mod(iTrial - 1, nSz * nCt) + 1;
    [sz, ct] = ind2sub([nSz, nCt], condIdx);
    p.trVars.checkSizeIdx = sz; p.trVars.contrastIdx = ct;
    p.trVars.checkReversalHz = p.trVarsInit.checkReversalHz;
    p.trVars.nSTALags = p.trVarsInit.nSTALags;
else
    frameDurS = p.trVars.noiseFrameHold * p.rig.frameDuration;
    framesPerTrial = round(p.trVarsInit.trialDurationS / frameDurS);
    p.trVars.trialStartFrame  = p.init.noiseFrameIdx;
    p.trVars.trialEndFrame    = min(p.trVars.trialStartFrame + framesPerTrial - 1, ...
                                    p.init.nNoiseFrames);
    p.trVars.nFramesThisTrial = p.trVars.trialEndFrame - p.trVars.trialStartFrame + 1;
    p.trVars.noiseFrameDurS   = frameDurS;
    p.init.noiseFrameIdx      = p.trVars.trialEndFrame + 1;
    if p.init.noiseFrameIdx > p.init.nNoiseFrames, p.init.noiseFrameIdx = 1; end

    if strcmp(p.init.stimType, 'denseChromatic')
        nY = p.init.noiseGridSize(1); nX = p.init.noiseGridSize(2);
        seed = p.trVarsInit.noiseRngSeed + iTrial;
        [~, p.trVars.thisTrialDklDrive] = generateStim_denseChromatic( ...
            nY, nX, p.trVars.nFramesThisTrial, ...
            p.trVarsInit.dklAxes, p.trVarsInit.dklContrasts, seed);
    end
end

p.trData.timing.stimOn = iTrial * 10.0;
p.trData.spikeTimes    = [];
p.trData.spikeClusters = [];
p.trData.eventTimes    = [];
p.trData.eventValues   = [];
end


function p = simulateFinishAccumulate(p)
% Subset of rfMap_finish's accumulateSTA -- no Screen/strobe/saveP.
eventIdx = find(p.trData.eventValues == p.init.codes.stimOn, 1, 'last');
if isempty(eventIdx), return; end
stimOnTime = p.trData.eventTimes(eventIdx);

spikesPerChan = cell(p.trVarsInit.nChannels, 1);
for ch = 1:p.trVarsInit.nChannels
    spikesPerChan{ch} = p.trData.spikeTimes(p.trData.spikeClusters == ch);
end

p.status.iGoodTrial = p.status.iGoodTrial + 1;

switch p.init.stimType
    case 'checkerboard'
        p.init.staAccum = updateSTA_checkerboard(p.init.staAccum, ...
            spikesPerChan, stimOnTime, p.trVars.noiseFrameDurS, ...
            p.trVars.checkPolaritySequence, ...
            [p.trVars.checkSizeIdx, p.trVars.contrastIdx], ...
            p.trVars.checkReversalHz, p.trVars.nSTALags);
        endT = stimOnTime + p.trVars.nFramesThisTrial * p.trVars.noiseFrameDurS;
        for ch = 1:p.trVarsInit.nChannels
            spk = spikesPerChan{ch};
            if ~isempty(spk)
                p.init.staSpikeCount(ch) = p.init.staSpikeCount(ch) + ...
                    sum(spk >= stimOnTime & spk < endT);
            end
        end
    case 'denseChromatic'
        [p.init.staAccum, p.init.staSpikeCount] = updateSTA(p.init.stimType, ...
            p.init.staAccum, p.init.staSpikeCount, ...
            spikesPerChan, stimOnTime, p.trVars.noiseFrameDurS, ...
            p.trVars.thisTrialDklDrive, 1, p.trVars.nFramesThisTrial, ...
            p.trVarsInit.nSTALags);
    otherwise
        [p.init.staAccum, p.init.staSpikeCount] = updateSTA(p.init.stimType, ...
            p.init.staAccum, p.init.staSpikeCount, ...
            spikesPerChan, stimOnTime, p.trVars.noiseFrameDurS, ...
            p.init.noiseMovie, p.trVars.trialStartFrame, ...
            p.trVars.nFramesThisTrial, p.trVarsInit.nSTALags);
end
end
