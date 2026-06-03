% test_multitask_optimization.m
%
% Determines the optimal trial budget for the RF-estimation pipeline:
%   Phase 1: Checkerboard pre-screening (48 trials, ~1.6 min)
%   Phase 2: denseAchromatic RF mapping (variable trial count)
%
% Evaluates quality at checkpoints (every 50 trials) to find the
% minimum trial count where RF recovery plateaus. Also tests multiple
% population seeds to measure robustness across different neuron
% configurations.
%
% Outputs:
%   - Convergence curves: # channels passing quality vs trial count
%   - Per-cell-type convergence breakdown (P vs M vs K)
%   - Recommended trial budget for real sessions
%   - Summary figure saved to figs_optimization/

projRoot = '/home/herman_lab/Documents/PLDAPS_vK2_MASTER';
addpath(projRoot);
addpath(fullfile(projRoot, 'tasks', 'rfMap', 'supportFunctions'));
figDir = fullfile(projRoot, 'tasks', 'rfMap', '_validation', 'figs_optimization');
if ~isfolder(figDir), mkdir(figDir); end

fprintf('=== MULTI-TASK OPTIMIZATION ===\n\n');

%% Configuration
screenW = 1920; screenH = 1080;
checkSizeDeg = 2.0;
nSeeds = 5;
seeds = [42 77 123 256 999];
maxTrials = 400;
checkpoints = 50:50:maxTrials;
nCheckpoints = numel(checkpoints);

% Trial timing for real-session budget estimation.
checkerboardTrialDurS = 2.0;
nCheckerboardTrials = 48;
denseAchromaticTrialDurS = 1.5;  % ~15 frames * 100ms

%% Run multiple populations
allResults = struct();
for seedIdx = 1:nSeeds
    seed = seeds(seedIdx);
    fprintf('--- Population seed %d (%d/%d) ---\n', seed, seedIdx, nSeeds);

    % Generate population.
    popFile = fullfile(figDir, sprintf('pop_seed%03d.mat', seed));
    pop = simGeneratePopulation( ...
        'nNeurons', 12, 'nChannels', 64, 'hemifield', 'left', ...
        'eccentricityRange', [2 5], 'elevationRange', [-3 3], ...
        'seed', seed, 'baseRate', 2, 'peakRate', 20, 'saveFile', popFile);

    % Build p struct for denseAchromatic.
    p = struct();
    p.trVarsInit.nChannels = 64;
    p.trVarsInit.nSTALags = 8;
    p.trVarsInit.checkSizeDeg = checkSizeDeg;
    p.trVarsInit.noiseFrameHold = 1;
    p.trVarsInit.fixDegX = 0;
    p.trVarsInit.fixDegY = 0;
    p.trVarsInit.rfCenterThreshFrac = 0.5;
    p.draw.middleXY = [screenW/2 screenH/2];
    p.rig.frameDuration = 0.01;
    p.rig.screenh = 0.30;
    p.rig.screenhpix = 1080;
    p.rig.viewdist = 0.60;
    p.init.stimType = 'denseAchromatic';

    checkSizePix = pds.deg2pix(checkSizeDeg, p);
    if checkSizePix < 1, checkSizePix = 1; end
    gridWidthPix = screenW / 2;
    gridCenterX = screenW / 4;
    nX = ceil(gridWidthPix / checkSizePix);
    nY = ceil(screenH / checkSizePix);
    p.init.noiseGridSize = [nY nX];
    p.init.noiseGridCenterPix = [gridCenterX, screenH/2];

    nCh = 64;
    nLags = 8;

    p = simLoadPopulation(p, popFile);
    bank = p.init.simKernelBank;

    % Pre-generate all noise frames.
    framesPerTrial = 15;
    frameDurS = 0.1;
    nTotalFrames = maxTrials * framesPerTrial;
    rng(seed * 100 + 1, 'twister');
    noiseMovie = uint8(rand(nY, nX, nTotalFrames) > 0.5);

    % Initialize accumulators.
    staAccum = cell(nCh, 1);
    for ch = 1:nCh, staAccum{ch} = zeros(nY, nX, nLags); end
    staSpikeCount = zeros(nCh, nLags);

    % Track results at each checkpoint.
    nPass = zeros(nCheckpoints, 1);
    nPassByType = zeros(nCheckpoints, 3);  % P, M, K
    medianErr = nan(nCheckpoints, 1);
    allErr = cell(nCheckpoints, 1);
    cpIdx = 1;

    % Cell types for each RF channel.
    rfChSet = arrayfun(@(n) n.channelIdx, pop.neurons);
    cellTypes = {pop.neurons.cellType};

    fprintf('  Grid: %dx%d, simulating %d trials...\n', nY, nX, maxTrials);

    for trial = 1:maxTrials
        f0 = (trial-1) * framesPerTrial + 1;
        f1 = f0 + framesPerTrial - 1;
        S = double(noiseMovie(:,:,f0:f1)) - 0.5;
        spikeTimesPerChan = cell(nCh, 1);
        stimOnTime = 0;

        for ch = 1:nCh
            k = bank.kernels{ch};
            if isempty(k), continue; end
            trialSeed = mod(seed*1000 + ch + 10000*trial, 2^32 - 1);
            chRs = RandStream('mt19937ar', 'Seed', uint32(trialSeed));
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

        [staAccum, staSpikeCount] = updateSTA_denseAchromatic( ...
            staAccum, staSpikeCount, spikeTimesPerChan, stimOnTime, ...
            frameDurS, noiseMovie, f0, framesPerTrial, nLags);

        % Evaluate at checkpoint?
        if cpIdx <= nCheckpoints && trial == checkpoints(cpIdx)
            pEval = p;
            pEval.init.staAccum = staAccum;
            pEval.init.staSpikeCount = staSpikeCount;
            pEval.trVars.checkSizeDeg = checkSizeDeg;
            pEval.draw.fixPointPix = pEval.draw.middleXY;
            quality = computeChannelQuality(pEval);

            nPassThis = 0;
            errVec = [];
            nPassP = 0; nPassM = 0; nPassK = 0;

            for ki = 1:numel(pop.neurons)
                n = pop.neurons(ki);
                ch = n.channelIdx;
                q = quality(ch);
                if q.passGo
                    nPassThis = nPassThis + 1;
                    switch n.cellType
                        case 'P', nPassP = nPassP + 1;
                        case 'M', nPassM = nPassM + 1;
                        case 'K', nPassK = nPassK + 1;
                    end
                end
                if ~any(isnan(q.rfCenterDeg))
                    k = bank.kernels{ch};
                    gt = k.rfCenterFixFrame;
                    err = sqrt(sum((q.rfCenterDeg - gt).^2)) / checkSizeDeg;
                    errVec = [errVec; err]; %#ok<AGROW>
                end
            end

            nPass(cpIdx) = nPassThis;
            nPassByType(cpIdx, :) = [nPassP nPassM nPassK];
            if ~isempty(errVec)
                medianErr(cpIdx) = median(errVec);
            end
            allErr{cpIdx} = errVec;

            fprintf('    trial %3d: %d/%d pass, median err %.2f checks\n', ...
                trial, nPassThis, numel(pop.neurons), medianErr(cpIdx));
            cpIdx = cpIdx + 1;
        end
    end

    allResults(seedIdx).seed = seed;
    allResults(seedIdx).nPass = nPass;
    allResults(seedIdx).nPassByType = nPassByType;
    allResults(seedIdx).medianErr = medianErr;
    allResults(seedIdx).allErr = allErr;
    allResults(seedIdx).nNeurons = numel(pop.neurons);
    allResults(seedIdx).nP = sum(strcmp(cellTypes, 'P'));
    allResults(seedIdx).nM = sum(strcmp(cellTypes, 'M'));
    allResults(seedIdx).nK = sum(strcmp(cellTypes, 'K'));
end

%% Aggregate across seeds
fprintf('\n=== AGGREGATE RESULTS ===\n');
fprintf('Checkpoint | Pass rate (mean +/- std) | Median err (mean +/- std)\n');
fprintf('-----------+--------------------------+--------------------------\n');

passMatrix = zeros(nSeeds, nCheckpoints);
errMatrix = nan(nSeeds, nCheckpoints);
for s = 1:nSeeds
    passMatrix(s,:) = allResults(s).nPass / allResults(s).nNeurons;
    errMatrix(s,:) = allResults(s).medianErr;
end

for cp = 1:nCheckpoints
    fprintf('  %3d trials | %.0f%% +/- %.0f%% | %.2f +/- %.2f checks\n', ...
        checkpoints(cp), ...
        100*mean(passMatrix(:,cp)), 100*std(passMatrix(:,cp)), ...
        mean(errMatrix(:,cp), 'omitnan'), std(errMatrix(:,cp), 'omitnan'));
end

% Find the minimum trial count where pass rate >= 60%.
targetPassRate = 0.60;
meanPassRate = mean(passMatrix, 1);
recommendedIdx = find(meanPassRate >= targetPassRate, 1, 'first');
if isempty(recommendedIdx)
    recommendedTrials = maxTrials;
    fprintf('\nWARNING: %.0f%% pass rate not reached at %d trials.\n', ...
        100*targetPassRate, maxTrials);
else
    recommendedTrials = checkpoints(recommendedIdx);
end

checkerboardMinutes = nCheckerboardTrials * checkerboardTrialDurS / 60;
daMinutes = recommendedTrials * denseAchromaticTrialDurS / 60;
totalMinutes = checkerboardMinutes + daMinutes;

fprintf('\n=== RECOMMENDATION ===\n');
fprintf('  Checkerboard pre-screen: %d trials (%.1f min)\n', ...
    nCheckerboardTrials, checkerboardMinutes);
fprintf('  denseAchromatic: %d trials (%.1f min)\n', ...
    recommendedTrials, daMinutes);
fprintf('  Total: %.1f min for >= %.0f%% channel pass rate\n', ...
    totalMinutes, 100*targetPassRate);
fprintf('  Mean pass rate at %d trials: %.0f%% (%.1f +/- %.1f / 12 neurons)\n', ...
    recommendedTrials, 100*meanPassRate(recommendedIdx), ...
    mean(passMatrix(:,recommendedIdx))*12, std(passMatrix(:,recommendedIdx))*12);

%% Per-cell-type breakdown
fprintf('\n=== PER-CELL-TYPE CONVERGENCE ===\n');
for cp = 1:nCheckpoints
    pRates = zeros(nSeeds, 1);
    mRates = zeros(nSeeds, 1);
    kRates = zeros(nSeeds, 1);
    for s = 1:nSeeds
        if allResults(s).nP > 0
            pRates(s) = allResults(s).nPassByType(cp, 1) / allResults(s).nP;
        end
        if allResults(s).nM > 0
            mRates(s) = allResults(s).nPassByType(cp, 2) / allResults(s).nM;
        end
        if allResults(s).nK > 0
            kRates(s) = allResults(s).nPassByType(cp, 3) / allResults(s).nK;
        end
    end
    fprintf('  %3d trials: P=%.0f%%, M=%.0f%%, K=%.0f%%\n', ...
        checkpoints(cp), 100*mean(pRates), 100*mean(mRates), 100*mean(kRates));
end

%% Summary figure
fig = figure('Visible', 'off', 'Position', [0 0 1200 500]);

% Panel 1: Pass rate convergence (all seeds).
subplot(1,3,1);
hold on;
colors = lines(nSeeds);
for s = 1:nSeeds
    plot(checkpoints, 100*passMatrix(s,:), '-o', 'Color', colors(s,:), ...
        'MarkerSize', 4, 'LineWidth', 0.8);
end
plot(checkpoints, 100*meanPassRate, 'k-s', 'LineWidth', 2, 'MarkerSize', 6, ...
    'MarkerFaceColor', 'k');
yline(100*targetPassRate, 'r--', sprintf('%.0f%% target', 100*targetPassRate), ...
    'LineWidth', 1.5);
if ~isempty(recommendedIdx)
    xline(recommendedTrials, 'g--', sprintf('%d trials', recommendedTrials), ...
        'LineWidth', 1.5);
end
xlabel('denseAchromatic trials');
ylabel('RF channels passing quality (%)');
title('Convergence: pass rate');
ylim([0 105]);
legend([arrayfun(@(s) sprintf('seed=%d', seeds(s)), 1:nSeeds, 'uni', false), ...
    {'Mean'}], 'Location', 'southeast', 'FontSize', 7);

% Panel 2: Median center error convergence.
subplot(1,3,2);
hold on;
for s = 1:nSeeds
    plot(checkpoints, errMatrix(s,:), '-o', 'Color', colors(s,:), ...
        'MarkerSize', 4, 'LineWidth', 0.8);
end
plot(checkpoints, mean(errMatrix, 1, 'omitnan'), 'k-s', 'LineWidth', 2, ...
    'MarkerSize', 6, 'MarkerFaceColor', 'k');
yline(0.5, 'r--', '0.5 checks', 'LineWidth', 1.5);
xlabel('denseAchromatic trials');
ylabel('Median RF center error (checks)');
title('Convergence: center accuracy');
ylim([0 max(errMatrix(:))*1.1]);

% Panel 3: Session time budget.
subplot(1,3,3);
timeDA = checkpoints * denseAchromaticTrialDurS / 60;
totalTime = checkerboardMinutes + timeDA;
plot(totalTime, 100*meanPassRate, 'k-s', 'LineWidth', 2, 'MarkerSize', 6, ...
    'MarkerFaceColor', 'k');
hold on;
yline(100*targetPassRate, 'r--', sprintf('%.0f%% target', 100*targetPassRate));
xlabel('Total session time (min)');
ylabel('RF channels passing quality (%)');
title('Time budget');
ylim([0 105]);

sgtitle(sprintf('Multi-task optimization: %d populations x %d trials max', ...
    nSeeds, maxTrials));
print(fig, fullfile(figDir, 'optimization_convergence.png'), '-dpng', '-r150');
close(fig);
fprintf('\nSaved optimization_convergence.png\n');

%% Save results for downstream use
save(fullfile(figDir, 'optimization_results.mat'), ...
    'allResults', 'checkpoints', 'passMatrix', 'errMatrix', ...
    'recommendedTrials', 'seeds', 'meanPassRate', 'targetPassRate');
fprintf('Saved optimization_results.mat\n');

exit;
