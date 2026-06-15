% test_checkerboard_first_pipeline.m
%
% Tests the workflow: brief checkerboard → analyze F1 per check size →
% choose optimal check size → run denseAchromatic → quality scoring.
%
% Uses a literature-calibrated LGN population (P/M/K cell types with
% Croner & Kaplan 1995 sigma-vs-eccentricity scaling).

projRoot = '/home/herman_lab/Documents/PLDAPS_vK2_MASTER';
addpath(projRoot);
addpath(fullfile(projRoot, 'tasks', 'rfMap', 'supportFunctions'));
figDir = fullfile(projRoot, 'tasks', 'rfMap', '_validation', 'figs_checkerboard_first');
if ~isfolder(figDir), mkdir(figDir); end

fprintf('=== CHECKERBOARD-FIRST PIPELINE TEST ===\n\n');

%% Step 1: Generate a literature-calibrated population
popFile = fullfile(figDir, 'calibrated_population.mat');
pop = simGeneratePopulation( ...
    'nNeurons', 12, ...
    'nChannels', 64, ...
    'hemifield', 'left', ...
    'eccentricityRange', [2 5], ...
    'elevationRange', [-3 3], ...
    'seed', 77, ...
    'baseRate', 2, ...
    'peakRate', 20, ...
    'saveFile', popFile);

fprintf('\n--- Population neurons ---\n');
fprintf('  ch | type | center(dva)  | sigma_c(deg) | exc(ms) | inh_wt | pol | DKL\n');
fprintf('  ---+------+--------------+--------------+---------+--------+-----+----\n');
for k = 1:numel(pop.neurons)
    n = pop.neurons(k);
    fprintf('  %2d |   %s  | (%+5.1f,%+5.1f) |    %7.4f   |   %4.0f  | %5.2f  |  %+d | [%+.1f %.1f %.1f]\n', ...
        n.channelIdx, n.cellType, n.centerDeg(1), n.centerDeg(2), ...
        n.sigmaCenterDeg, n.excPeakMs, n.inhWeight, n.polarity, ...
        n.dklWeights(1), n.dklWeights(2), n.dklWeights(3));
end
fprintf('\n');

%% Step 2: Configure checkerboard simulation
% Rig geometry (must match between checkerboard and denseAchromatic).
screenW = 1920; screenH = 1080;

p = struct();
p.trVarsInit.nChannels = 64;
p.trVarsInit.nSTALags = 24;
p.trVarsInit.checkSizeDeg = 2.0;
p.trVarsInit.noiseFrameHold = 1;
p.trVarsInit.fixDegX = 0;
p.trVarsInit.fixDegY = 0;
p.trVarsInit.rfCenterThreshFrac = 0.5;
p.trVarsInit.checkSizesDva  = [0.25 0.5 1.0 2.0];
p.trVarsInit.checkContrasts = [0.25 0.5 1.0];
p.trVarsInit.checkReversalHz = 5;
p.draw.middleXY = [screenW/2 screenH/2];
p.rig.frameDuration = 0.01;   % 100 Hz display
p.rig.screenh = 0.30;
p.rig.screenhpix = 1080;
p.rig.viewdist = 0.60;
p.init.stimType = 'checkerboard';
p.init.noiseGridSize = [ceil(screenH/75), ceil(screenW/75)];
p.init.noiseGridCenterPix = p.draw.middleXY;

% Build checkerboard kernel bank from the population.
p = simLoadPopulation(p, popFile);
bank = p.init.simKernelBank;

%% Step 3: Run checkerboard simulation
checkSizes  = p.trVarsInit.checkSizesDva;
checkCt     = p.trVarsInit.checkContrasts;
nSize       = numel(checkSizes);
nCt         = numel(checkCt);
nCh         = 64;
nLags       = p.trVarsInit.nSTALags;
reversalHz  = p.trVarsInit.checkReversalHz;
displayFrameS = p.rig.frameDuration;
trialDurS   = 2.0;
nFramesTrial = round(trialDurS / displayFrameS);
framesPerRev = round(p.rig.frameDuration^-1 / reversalHz);

repsPerCond = 12;
nTrials     = nSize * nCt * repsPerCond;

% Build trial array: cycle through all (size, contrast) conditions.
trialArray = [];
for rep = 1:repsPerCond
    for sz = 1:nSize
        for ct = 1:nCt
            trialArray = [trialArray; sz ct]; %#ok<AGROW>
        end
    end
end
trialArray = trialArray(randperm(size(trialArray, 1)), :);

% Initialize STA accumulators (matching rfMap_init structure).
staAccum = struct( ...
    'temporalKernel',      zeros(nLags, nSize, nCt, nCh), ...
    'spikeCountPerCondCh', zeros(nSize, nCt, nCh), ...
    'f1f2AmpSum',          zeros(2, nSize, nCt, nCh), ...
    'f1f2TrialCount',      zeros(nSize, nCt));

fprintf('Running %d checkerboard trials (%d reps x %d sizes x %d contrasts)...\n', ...
    nTrials, repsPerCond, nSize, nCt);

totalSpikes = 0;
for trial = 1:nTrials
    szIdx = trialArray(trial, 1);
    ctIdx = trialArray(trial, 2);

    % Build polarity sequence.
    revBlock = floor((0:nFramesTrial-1) / framesPerRev);
    polaritySeq = int8(1 - 2 * mod(revBlock, 2));
    polarity = double(polaritySeq(:)');

    % Simulate spikes.
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
            tk = k.temporalKernel;
            g = filter(tk, 1, proj(:));
            g = g / k.gStd;
            spkRel = simLNPSpikes(g, k.baseRate, k.peakRate, displayFrameS, chRs);
        end

        if ~isempty(spkRel)
            spikeTimesPerChan{ch} = stimOnTime + spkRel;
            totalSpikes = totalSpikes + numel(spkRel);
        end
    end

    % Accumulate STA.
    staAccum = updateSTA_checkerboard( ...
        staAccum, spikeTimesPerChan, stimOnTime, displayFrameS, ...
        polaritySeq, [szIdx ctIdx], reversalHz, nLags);

    if mod(trial, 36) == 0
        fprintf('  Trial %d/%d: %d total spikes\n', trial, nTrials, totalSpikes);
    end
end

%% Step 4: Analyze checkerboard results
fprintf('\n=== CHECKERBOARD ANALYSIS ===\n');
fprintf('  ch | type | sigma_c | ');
for sz = 1:nSize
    fprintf('F1@%.2fdva ', checkSizes(sz));
end
fprintf('| best_size | peak_SF\n');
fprintf('  ---+------+---------+');
for sz = 1:nSize, fprintf('----------'); end
fprintf('-+-----------+--------\n');

bestCheckSize = nan(nCh, 1);
rfChannels = [];

for ch = 1:nCh
    k = bank.kernels{ch};
    if isempty(k) || (isfield(k, 'isNoise') && k.isNoise), continue; end

    rfChannels = [rfChannels; ch]; %#ok<AGROW>

    % F1 amplitude at full contrast for each check size.
    f1PerSize = zeros(1, nSize);
    for sz = 1:nSize
        nTrialsCond = staAccum.f1f2TrialCount(sz, nCt);
        if nTrialsCond > 0
            f1PerSize(sz) = staAccum.f1f2AmpSum(1, sz, nCt, ch) / nTrialsCond;
        end
    end

    [~, bestIdx] = max(f1PerSize);
    bestCheckSize(ch) = checkSizes(bestIdx);

    sigC = 0;
    if isfield(k, 'sigmaCenterDeg'), sigC = k.sigmaCenterDeg; end
    cellType = '?';
    for nk = 1:numel(pop.neurons)
        if pop.neurons(nk).channelIdx == ch
            cellType = pop.neurons(nk).cellType;
            sigC = pop.neurons(nk).sigmaCenterDeg;
            break;
        end
    end

    peakSF = 0;
    if bestCheckSize(ch) > 0, peakSF = 1/(2*bestCheckSize(ch)); end

    fprintf('  %2d |   %s  | %7.4f | ', ch, cellType, sigC);
    for sz = 1:nSize
        fprintf('%9.1f ', f1PerSize(sz));
    end
    fprintf('| %9.2f | %6.2f\n', bestCheckSize(ch), peakSF);
end

% Determine optimal denseAchromatic check size: mode of best check sizes
% across RF channels, weighted by F1 amplitude.
validBest = bestCheckSize(rfChannels);
[counts, edges] = histcounts(validBest, [checkSizes - 0.001, max(checkSizes) + 0.001]);
[~, modeIdx] = max(counts);
recommendedCheckSize = checkSizes(modeIdx);
fprintf('\n  Recommended denseAchromatic check size: %.2f dva\n', recommendedCheckSize);
fprintf('  (mode of per-channel best: %s)\n', ...
    mat2str(round(histcounts(validBest, [checkSizes - 0.001, max(checkSizes) + 0.001]))));

%% Step 5: Figure — Checkerboard analysis
fig1 = figure('Visible', 'off', 'Position', [0 0 1000 500]);
nRF = numel(rfChannels);

% Panel 1: F1 vs check size per channel
subplot(1,2,1);
cmap = lines(nRF);
for i = 1:nRF
    ch = rfChannels(i);
    f1PerSize = zeros(1, nSize);
    for sz = 1:nSize
        nTrialsCond = staAccum.f1f2TrialCount(sz, nCt);
        if nTrialsCond > 0
            f1PerSize(sz) = staAccum.f1f2AmpSum(1, sz, nCt, ch) / nTrialsCond;
        end
    end
    plot(checkSizes, f1PerSize, '-o', 'Color', cmap(i,:), 'LineWidth', 1.5, ...
        'MarkerSize', 5, 'MarkerFaceColor', cmap(i,:));
    hold on;
end
set(gca, 'XScale', 'log');
xlabel('Check size (dva)');
ylabel('F1 amplitude (full contrast)');
title('Checkerboard: F1 vs check size');
xline(recommendedCheckSize, 'k--', sprintf('%.2f dva', recommendedCheckSize), ...
    'LineWidth', 1.5);
legend(arrayfun(@(c) sprintf('ch%d', c), rfChannels, 'UniformOutput', false), ...
    'Location', 'best', 'FontSize', 6);
grid on;

% Panel 2: Gain tables (MTF-based)
subplot(1,2,2);
for i = 1:nRF
    ch = rfChannels(i);
    k = bank.kernels{ch};
    gainFull = k.gainTable(:, end);  % full contrast
    plot(checkSizes, gainFull, '-s', 'Color', cmap(i,:), 'LineWidth', 1.5, ...
        'MarkerSize', 5, 'MarkerFaceColor', cmap(i,:));
    hold on;
end
set(gca, 'XScale', 'log');
xlabel('Check size (dva)');
ylabel('Gain (MTF * contrast)');
title('RF-based gain model');
grid on;

sgtitle('Checkerboard pre-screening');
print(fig1, fullfile(figDir, 'checkerboard_analysis.png'), '-dpng', '-r150');
close(fig1);
fprintf('Saved checkerboard_analysis.png\n');

%% Step 6: Run denseAchromatic at the recommended check size
fprintf('\n=== DENSE ACHROMATIC WITH CHECK SIZE = %.2f dva ===\n', recommendedCheckSize);

% Reconfigure p struct for denseAchromatic.
p.init.stimType = 'denseAchromatic';
p.trVarsInit.checkSizeDeg = recommendedCheckSize;
p.trVarsInit.nSTALags = 8;

checkSizePix = pds.deg2pix(recommendedCheckSize, p);
if checkSizePix < 1, checkSizePix = 1; end
gridWidthPix = screenW / 2;
gridCenterX  = screenW / 4;
nX = ceil(gridWidthPix / checkSizePix);
nY = ceil(screenH / checkSizePix);
p.init.noiseGridSize = [nY nX];
p.init.noiseGridCenterPix = [gridCenterX, screenH/2];
nLagsDA = 8;
p.trVarsInit.nSTALags = nLagsDA;
fprintf('Grid: %dx%d checks at %.2f dva (checkSizePix=%d)\n', nY, nX, recommendedCheckSize, checkSizePix);

% Reload kernel bank for denseAchromatic.
p = simLoadPopulation(p, popFile);
bankDA = p.init.simKernelBank;

% Generate noise and run sim.
nTrialsDA = 300;
framesPerTrialDA = 15;
frameDurMs = 100;
frameDurS = frameDurMs / 1000;
nTotalFrames = nTrialsDA * framesPerTrialDA;
rng(12345, 'twister');
noiseMovie = uint8(rand(nY, nX, nTotalFrames) > 0.5);

staAccumDA = cell(nCh, 1);
for ch = 1:nCh, staAccumDA{ch} = zeros(nY, nX, nLagsDA); end
staSpikeCountDA = zeros(nCh, nLagsDA);

fprintf('Simulating %d denseAchromatic trials (%dx%d grid)...\n', nTrialsDA, nY, nX);
for trial = 1:nTrialsDA
    f0 = (trial-1) * framesPerTrialDA + 1;
    f1 = f0 + framesPerTrialDA - 1;
    S = double(noiseMovie(:,:,f0:f1)) - 0.5;

    spikeTimesPerChan = cell(nCh, 1);
    stimOnTime = 0;

    for ch = 1:nCh
        k = bankDA.kernels{ch};
        if isempty(k), continue; end
        seed = mod(42 + ch + 10000*trial, 2^32 - 1);
        chRs = RandStream('mt19937ar', 'Seed', uint32(seed));

        if isfield(k, 'isNoise') && k.isNoise
            g = zeros(framesPerTrialDA, 1);
            spkRel = simLNPSpikes(g, k.baseRate, 0, frameDurS, chRs);
        else
            sk = k.spatialKernel;
            sFlat = reshape(S, [], framesPerTrialDA);
            proj = sk(:)' * sFlat;
            g = filter(k.temporalKernel, 1, proj(:));
            g = g / k.gStd;
            spkRel = simLNPSpikes(g, k.baseRate, k.peakRate, frameDurS, chRs);
        end

        if ~isempty(spkRel)
            spikeTimesPerChan{ch} = stimOnTime + spkRel;
        end
    end

    [staAccumDA, staSpikeCountDA] = updateSTA_denseAchromatic( ...
        staAccumDA, staSpikeCountDA, spikeTimesPerChan, stimOnTime, ...
        frameDurS, noiseMovie, f0, framesPerTrialDA, nLagsDA);

    if mod(trial, 100) == 0
        fprintf('  Trial %d/%d\n', trial, nTrialsDA);
    end
end

%% Step 7: Quality scores and comparison
p.init.staAccum = staAccumDA;
p.init.staSpikeCount = staSpikeCountDA;
p.trVars.checkSizeDeg = recommendedCheckSize;
p.draw.fixPointPix = p.draw.middleXY;

quality = computeChannelQuality(p);

fprintf('\n=== QUALITY SCORES (checkSize=%.2f dva) ===\n', recommendedCheckSize);
nPass = 0;
rfErrors = [];
for ch = 1:nCh
    q = quality(ch);
    k = bankDA.kernels{ch};
    if isempty(k) || (isfield(k, 'isNoise') && k.isNoise), continue; end

    if q.passGo, nPass = nPass + 1; end

    if ~any(isnan(q.rfCenterDeg))
        gtX = k.rfCenterFixFrame(1);
        gtY = k.rfCenterFixFrame(2);
        err = sqrt((q.rfCenterDeg(1) - gtX)^2 + (q.rfCenterDeg(2) - gtY)^2);
        rfErrors = [rfErrors; ch err]; %#ok<AGROW>
        fprintf('  ch%2d: err=%.2f checks, spatSNR=%.1f, %s\n', ...
            ch, err/recommendedCheckSize, q.spatialSNR, ...
            ternary(q.passGo, 'PASS', 'FAIL'));
    end
end

fprintf('\n  Pass: %d / %d RF channels\n', nPass, numel(rfChannels));
if ~isempty(rfErrors)
    fprintf('  Median error: %.3f dva (%.2f checks)\n', ...
        median(rfErrors(:,2)), median(rfErrors(:,2)) / recommendedCheckSize);
end

fprintf('\n=== PIPELINE SUMMARY ===\n');
fprintf('  1. Checkerboard: %d trials (%.1f min) → identified optimal check size = %.2f dva\n', ...
    nTrials, nTrials * trialDurS / 60, recommendedCheckSize);
fprintf('  2. denseAchromatic: %d trials (%.1f min) at %dx%d grid → %d/%d channels pass\n', ...
    nTrialsDA, nTrialsDA * framesPerTrialDA * frameDurS / 60, ...
    nY, nX, nPass, numel(rfChannels));
fprintf('  Total sim time: %.1f min\n', ...
    (nTrials * trialDurS + nTrialsDA * framesPerTrialDA * frameDurS) / 60);

fprintf('\n=== TEST COMPLETE ===\n');
exit;


function v = ternary(cond, a, b)
if cond, v = a; else, v = b; end
end
