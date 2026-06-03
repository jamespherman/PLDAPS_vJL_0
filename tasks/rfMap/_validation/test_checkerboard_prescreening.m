% test_checkerboard_prescreening.m
%
% Tests the practical pipeline: brief checkerboard to identify responsive
% channels → run denseAchromatic only scoring those channels.
%
% Key finding: for LGN RFs (sigma 0.05-0.16 deg), all practical check
% sizes (0.25-2.0 dva) are much larger than the RF. The optimal
% denseAchromatic check size is determined by the precision/convergence
% tradeoff, NOT by the RF's preferred SF. The checkerboard's value is
% in identifying which channels are responsive AT ALL before committing
% to the longer denseAchromatic run.

projRoot = '/home/herman_lab/Documents/PLDAPS_vK2_MASTER';
addpath(projRoot);
addpath(fullfile(projRoot, 'tasks', 'rfMap', 'supportFunctions'));
figDir = fullfile(projRoot, 'tasks', 'rfMap', '_validation', 'figs_checkerboard_first');
if ~isfolder(figDir), mkdir(figDir); end

fprintf('=== CHECKERBOARD PRE-SCREENING PIPELINE ===\n\n');

%% Step 1: Load population (reuse from previous test)
popFile = fullfile(figDir, 'calibrated_population.mat');
if ~exist(popFile, 'file')
    pop = simGeneratePopulation( ...
        'nNeurons', 12, 'nChannels', 64, 'hemifield', 'left', ...
        'eccentricityRange', [2 5], 'elevationRange', [-3 3], ...
        'seed', 77, 'baseRate', 2, 'peakRate', 20, 'saveFile', popFile);
else
    tmp = load(popFile); pop = tmp.population;
    fprintf('Loaded population: %d neurons, %d channels\n', ...
        numel(pop.neurons), pop.nChannels);
end

%% Step 2: Run brief checkerboard (50 trials)
screenW = 1920; screenH = 1080;
p = struct();
p.trVarsInit.nChannels = 64;
p.trVarsInit.nSTALags = 24;
p.trVarsInit.checkSizeDeg = 2.0;
p.trVarsInit.noiseFrameHold = 1;
p.trVarsInit.fixDegX = 0;
p.trVarsInit.fixDegY = 0;
p.trVarsInit.rfCenterThreshFrac = 0.5;
p.trVarsInit.checkSizesDva  = [0.5 1.0 2.0];
p.trVarsInit.checkContrasts = [0.5 1.0];
p.trVarsInit.checkReversalHz = 5;
p.draw.middleXY = [screenW/2 screenH/2];
p.rig.frameDuration = 0.01;
p.rig.screenh = 0.30;
p.rig.screenhpix = 1080;
p.rig.viewdist = 0.60;
p.init.stimType = 'checkerboard';
p.init.noiseGridSize = [ceil(screenH/75), ceil(screenW/75)];
p.init.noiseGridCenterPix = p.draw.middleXY;

p = simLoadPopulation(p, popFile);
bank = p.init.simKernelBank;

nCh = 64;
nSize = numel(p.trVarsInit.checkSizesDva);
nCt = numel(p.trVarsInit.checkContrasts);
nLags = 24;
reversalHz = 5;
displayFrameS = p.rig.frameDuration;
trialDurS = 2.0;
nFramesTrial = round(trialDurS / displayFrameS);
framesPerRev = round(1 / (reversalHz * displayFrameS));

% Only use full contrast and the two largest check sizes (quick screen).
repsPerCond = 8;
trialArray = [];
for rep = 1:repsPerCond
    for sz = 1:nSize
        for ct = 1:nCt
            trialArray = [trialArray; sz ct]; %#ok<AGROW>
        end
    end
end
nTrials = size(trialArray, 1);

staAccum = struct( ...
    'temporalKernel',      zeros(nLags, nSize, nCt, nCh), ...
    'spikeCountPerCondCh', zeros(nSize, nCt, nCh), ...
    'f1f2AmpSum',          zeros(2, nSize, nCt, nCh), ...
    'f1f2TrialCount',      zeros(nSize, nCt));

fprintf('Phase 1: Running %d checkerboard trials (%.1f min)...\n', ...
    nTrials, nTrials * trialDurS / 60);

for trial = 1:nTrials
    szIdx = trialArray(trial, 1);
    ctIdx = trialArray(trial, 2);
    revBlock = floor((0:nFramesTrial-1) / framesPerRev);
    polaritySeq = int8(1 - 2 * mod(revBlock, 2));
    polarity = double(polaritySeq(:)');

    spikeTimesPerChan = cell(nCh, 1);
    stimOnTime = 0;
    for ch = 1:nCh
        k = bank.kernels{ch};
        if isempty(k), continue; end
        seed = mod(42 + ch + 10000*trial, 2^32 - 1);
        chRs = RandStream('mt19937ar', 'Seed', uint32(seed));
        if isfield(k, 'isNoise') && k.isNoise
            g = zeros(nFramesTrial, 1);
            spkRel = simLNPSpikes(g, k.baseRate, 0, displayFrameS, chRs);
        else
            g0 = k.gainTable(szIdx, ctIdx);
            proj = g0 * polarity;
            g = filter(k.temporalKernel, 1, proj(:)) / k.gStd;
            spkRel = simLNPSpikes(g, k.baseRate, k.peakRate, displayFrameS, chRs);
        end
        if ~isempty(spkRel)
            spikeTimesPerChan{ch} = stimOnTime + spkRel;
        end
    end
    staAccum = updateSTA_checkerboard( ...
        staAccum, spikeTimesPerChan, stimOnTime, displayFrameS, ...
        polaritySeq, [szIdx ctIdx], reversalHz, nLags);
end

%% Step 3: Identify responsive channels
% A channel is "responsive" if its best F1 at full contrast exceeds a
% noise baseline. Noise baseline: median F1 across all channels (most
% are noise channels, so the median approximates the noise floor).
fprintf('\nPhase 1 analysis: identifying responsive channels...\n');
bestF1 = zeros(nCh, 1);
for ch = 1:nCh
    f1max = 0;
    for sz = 1:nSize
        nT = staAccum.f1f2TrialCount(sz, nCt);
        if nT > 0
            f1 = staAccum.f1f2AmpSum(1, sz, nCt, ch) / nT;
            f1max = max(f1max, f1);
        end
    end
    bestF1(ch) = f1max;
end

noiseFloor = median(bestF1(bestF1 > 0));
f1Threshold = noiseFloor * 1.5;
responsiveChannels = find(bestF1 > f1Threshold);

% Also compute spike-rate responsiveness: channels with total spikes
% above the noise median.
totalSpikesPerCh = squeeze(sum(sum(staAccum.spikeCountPerCondCh, 1), 2));
noiseSpikeMedian = median(totalSpikesPerCh(totalSpikesPerCh > 0));

fprintf('\n  F1 noise floor: %.1f, threshold (1.5x): %.1f\n', ...
    noiseFloor, f1Threshold);
fprintf('  Responsive channels (F1 > threshold): %d / %d\n', ...
    numel(responsiveChannels), nCh);

% Identify which are real RF channels for validation.
rfChSet = arrayfun(@(n) n.channelIdx, pop.neurons);
truePositive = sum(ismember(responsiveChannels, rfChSet));
falsePositive = sum(~ismember(responsiveChannels, rfChSet));
missed = sum(~ismember(rfChSet, responsiveChannels));

fprintf('  True positive: %d, False positive: %d, Missed RF: %d\n', ...
    truePositive, falsePositive, missed);

fprintf('\n  Per-channel detail:\n');
fprintf('  ch | bestF1 | totalSpk | isRF | detected | type\n');
fprintf('  ---+--------+----------+------+----------+-----\n');
for ch = 1:nCh
    if bestF1(ch) == 0 && totalSpikesPerCh(ch) == 0, continue; end
    isRF = ismember(ch, rfChSet);
    detected = ismember(ch, responsiveChannels);
    cellType = '  -';
    for nk = 1:numel(pop.neurons)
        if pop.neurons(nk).channelIdx == ch
            cellType = sprintf('  %s', pop.neurons(nk).cellType);
            break;
        end
    end
    marker = '';
    if isRF && ~detected, marker = ' *** MISSED'; end
    if ~isRF && detected, marker = ' *** FP'; end
    fprintf('  %2d | %6.1f | %8d | %4s | %8s | %s%s\n', ...
        ch, bestF1(ch), totalSpikesPerCh(ch), ...
        ternary(isRF, 'YES', 'no'), ternary(detected, 'YES', 'no'), ...
        cellType, marker);
end

%% Step 4: Run denseAchromatic at 2-dva checks
fprintf('\n=== Phase 2: denseAchromatic (2.0 dva checks, left hemifield) ===\n');
checkSizeDeg = 2.0;
p.init.stimType = 'denseAchromatic';
p.trVarsInit.checkSizeDeg = checkSizeDeg;
p.trVarsInit.nSTALags = 8;

checkSizePix = pds.deg2pix(checkSizeDeg, p);
if checkSizePix < 1, checkSizePix = 1; end
gridWidthPix = screenW / 2;
gridCenterX = screenW / 4;
nX = ceil(gridWidthPix / checkSizePix);
nY = ceil(screenH / checkSizePix);
p.init.noiseGridSize = [nY nX];
p.init.noiseGridCenterPix = [gridCenterX, screenH/2];
nLagsDA = 8;
p.trVarsInit.nSTALags = nLagsDA;
fprintf('Grid: %dx%d checks at %.1f dva\n', nY, nX, checkSizeDeg);

p = simLoadPopulation(p, popFile);
bankDA = p.init.simKernelBank;

nTrialsDA = 300;
framesPerTrial = 15;
frameDurMs = 100;
frameDurS = frameDurMs / 1000;
nTotalFrames = nTrialsDA * framesPerTrial;
rng(12345, 'twister');
noiseMovie = uint8(rand(nY, nX, nTotalFrames) > 0.5);

staAccumDA = cell(nCh, 1);
for ch = 1:nCh, staAccumDA{ch} = zeros(nY, nX, nLagsDA); end
staSpikeCountDA = zeros(nCh, nLagsDA);

fprintf('Simulating %d trials...\n', nTrialsDA);
for trial = 1:nTrialsDA
    f0 = (trial-1) * framesPerTrial + 1;
    f1 = f0 + framesPerTrial - 1;
    S = double(noiseMovie(:,:,f0:f1)) - 0.5;
    spikeTimesPerChan = cell(nCh, 1);
    stimOnTime = 0;
    for ch = 1:nCh
        k = bankDA.kernels{ch};
        if isempty(k), continue; end
        seed = mod(42 + ch + 10000*trial, 2^32 - 1);
        chRs = RandStream('mt19937ar', 'Seed', uint32(seed));
        if isfield(k, 'isNoise') && k.isNoise
            g = zeros(framesPerTrial, 1);
            spkRel = simLNPSpikes(g, k.baseRate, 0, frameDurS, chRs);
        else
            sk = k.spatialKernel;
            sFlat = reshape(S, [], framesPerTrial);
            proj = sk(:)' * sFlat;
            g = filter(k.temporalKernel, 1, proj(:)) / k.gStd;
            spkRel = simLNPSpikes(g, k.baseRate, k.peakRate, frameDurS, chRs);
        end
        if ~isempty(spkRel)
            spikeTimesPerChan{ch} = stimOnTime + spkRel;
        end
    end
    [staAccumDA, staSpikeCountDA] = updateSTA_denseAchromatic( ...
        staAccumDA, staSpikeCountDA, spikeTimesPerChan, stimOnTime, ...
        frameDurS, noiseMovie, f0, framesPerTrial, nLagsDA);
end

%% Step 5: Quality scores
p.init.staAccum = staAccumDA;
p.init.staSpikeCount = staSpikeCountDA;
p.trVars.checkSizeDeg = checkSizeDeg;
p.draw.fixPointPix = p.draw.middleXY;
quality = computeChannelQuality(p);

fprintf('\n=== QUALITY + PRE-SCREENING COMPARISON ===\n');
fprintf('  ch | type | pre-screen | spatSNR | err(chk) | passGo\n');
fprintf('  ---+------+------------+---------+----------+-------\n');
nPassTotal = 0;
nPassPrescreen = 0;
for ch = 1:nCh
    k = bankDA.kernels{ch};
    if isempty(k) || (isfield(k, 'isNoise') && k.isNoise), continue; end
    q = quality(ch);
    prescreen = ismember(ch, responsiveChannels);

    cellType = '?';
    for nk = 1:numel(pop.neurons)
        if pop.neurons(nk).channelIdx == ch, cellType = pop.neurons(nk).cellType; break; end
    end

    errStr = 'N/A';
    if ~any(isnan(q.rfCenterDeg))
        gtX = k.rfCenterFixFrame(1); gtY = k.rfCenterFixFrame(2);
        err = sqrt((q.rfCenterDeg(1)-gtX)^2 + (q.rfCenterDeg(2)-gtY)^2) / checkSizeDeg;
        errStr = sprintf('%8.2f', err);
    end

    if q.passGo, nPassTotal = nPassTotal + 1; end
    if q.passGo && prescreen, nPassPrescreen = nPassPrescreen + 1; end

    fprintf('  %2d |   %s  | %10s | %7.1f | %s | %s\n', ...
        ch, cellType, ternary(prescreen, 'YES', 'no'), ...
        q.spatialSNR, errStr, ternary(q.passGo, 'PASS', 'FAIL'));
end

fprintf('\n  Quality pass: %d / %d RF channels\n', nPassTotal, numel(rfChSet));
fprintf('  Would pass with pre-screening: %d (no info lost)\n', nPassPrescreen);

%% Step 6: Summary figure
fig = figure('Visible', 'off', 'Position', [0 0 900 400]);

subplot(1,2,1);
rfF1 = bestF1(rfChSet);
noiseF1 = bestF1(setdiff(1:nCh, rfChSet));
noiseF1 = noiseF1(noiseF1 > 0);
histogram(noiseF1, 20, 'FaceColor', [0.7 0.7 0.7], 'FaceAlpha', 0.7); hold on;
histogram(rfF1, 20, 'FaceColor', [0.2 0.6 0.2], 'FaceAlpha', 0.7);
xline(f1Threshold, 'r--', sprintf('thresh=%.1f', f1Threshold), 'LineWidth', 1.5);
xlabel('Best F1 amplitude'); ylabel('Count');
title('Checkerboard F1: RF vs noise channels');
legend('Noise ch', 'RF ch', 'Location', 'best');

subplot(1,2,2);
rfSNR = arrayfun(@(ch) quality(ch).spatialSNR, rfChSet);
noiseSNR = arrayfun(@(ch) quality(ch).spatialSNR, ...
    setdiff(1:nCh, rfChSet));
noiseSNR = noiseSNR(~isnan(noiseSNR));
histogram(noiseSNR, 20, 'FaceColor', [0.7 0.7 0.7], 'FaceAlpha', 0.7); hold on;
histogram(rfSNR, 20, 'FaceColor', [0.2 0.6 0.2], 'FaceAlpha', 0.7);
xline(5, 'r--', 'thresh=5', 'LineWidth', 1.5);
xlabel('Spatial SNR'); ylabel('Count');
title('denseAchromatic spatial SNR');
legend('Noise ch', 'RF ch', 'Location', 'best');

sgtitle('Checkerboard pre-screening + denseAchromatic quality');
print(fig, fullfile(figDir, 'prescreening_comparison.png'), '-dpng', '-r150');
close(fig);
fprintf('\nSaved prescreening_comparison.png\n');

%% Summary
checkerboardMinutes = nTrials * trialDurS / 60;
daMinutes = nTrialsDA * framesPerTrial * frameDurS / 60;
fprintf('\n=== PIPELINE TIMING ===\n');
fprintf('  Checkerboard: %d trials = %.1f min\n', nTrials, checkerboardMinutes);
fprintf('  denseAchromatic: %d trials = %.1f min\n', nTrialsDA, daMinutes);
fprintf('  Total: %.1f min\n', checkerboardMinutes + daMinutes);
fprintf('  Pre-screening identified %d/%d responsive channels\n', ...
    truePositive, numel(rfChSet));
fprintf('  (could skip %d noise channels in future analysis)\n', ...
    nCh - numel(responsiveChannels));

exit;


function v = ternary(cond, a, b)
if cond, v = a; else, v = b; end
end
