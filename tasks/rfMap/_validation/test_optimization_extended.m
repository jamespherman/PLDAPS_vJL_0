% test_optimization_extended.m
%
% Extended optimization: test 2 check sizes (1.5 dva and 2.0 dva) up to
% 600 trials to find where pass rate truly plateaus.
%
% Rationale: 2.0 dva checks on a 15x13 grid reached 65% at 400 trials.
% A 1.5 dva check size increases grid to ~20x18 = 360 pixels — more
% spatial precision but more parameters to estimate.

projRoot = '/home/herman_lab/Documents/PLDAPS_vK2_MASTER';
addpath(projRoot);
addpath(fullfile(projRoot, 'tasks', 'rfMap', 'supportFunctions'));
figDir = fullfile(projRoot, 'tasks', 'rfMap', '_validation', 'figs_optimization');
if ~isfolder(figDir), mkdir(figDir); end

fprintf('=== EXTENDED OPTIMIZATION: CHECK SIZE COMPARISON ===\n\n');

screenW = 1920; screenH = 1080;
checkSizes = [1.5 2.0];
nSizes = numel(checkSizes);
nSeeds = 3;
seeds = [42 77 256];
maxTrials = 600;
checkpoints = 50:50:maxTrials;
nCheckpoints = numel(checkpoints);

results = struct();
for csIdx = 1:nSizes
    checkSizeDeg = checkSizes(csIdx);
    fprintf('=== Check size: %.1f dva ===\n', checkSizeDeg);

    passMatrix = zeros(nSeeds, nCheckpoints);
    errMatrix = nan(nSeeds, nCheckpoints);

    for seedIdx = 1:nSeeds
        seed = seeds(seedIdx);
        popFile = fullfile(figDir, sprintf('pop_seed%03d.mat', seed));
        if ~exist(popFile, 'file')
            pop = simGeneratePopulation( ...
                'nNeurons', 12, 'nChannels', 64, 'hemifield', 'left', ...
                'eccentricityRange', [2 5], 'elevationRange', [-3 3], ...
                'seed', seed, 'baseRate', 2, 'peakRate', 20, 'saveFile', popFile);
        else
            tmp = load(popFile); pop = tmp.population;
        end

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
        nLags = 8;

        p = simLoadPopulation(p, popFile);
        bank = p.init.simKernelBank;

        nCh = 64;
        framesPerTrial = 15;
        frameDurS = 0.1;
        nTotalFrames = maxTrials * framesPerTrial;
        rng(seed * 100 + csIdx, 'twister');
        noiseMovie = uint8(rand(nY, nX, nTotalFrames) > 0.5);

        staAccum = cell(nCh, 1);
        for ch = 1:nCh, staAccum{ch} = zeros(nY, nX, nLags); end
        staSpikeCount = zeros(nCh, nLags);

        rfChSet = arrayfun(@(n) n.channelIdx, pop.neurons);
        cpIdx = 1;

        fprintf('  seed=%d, grid %dx%d (%d pix)\n', seed, nY, nX, nY*nX);

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

            if cpIdx <= nCheckpoints && trial == checkpoints(cpIdx)
                pEval = p;
                pEval.init.staAccum = staAccum;
                pEval.init.staSpikeCount = staSpikeCount;
                pEval.trVars.checkSizeDeg = checkSizeDeg;
                pEval.draw.fixPointPix = pEval.draw.middleXY;
                quality = computeChannelQuality(pEval);

                nPassThis = 0;
                errVec = [];
                for ki = 1:numel(pop.neurons)
                    n = pop.neurons(ki);
                    ch = n.channelIdx;
                    q = quality(ch);
                    if q.passGo, nPassThis = nPassThis + 1; end
                    if ~any(isnan(q.rfCenterDeg))
                        gt = bank.kernels{ch}.rfCenterFixFrame;
                        err = sqrt(sum((q.rfCenterDeg - gt).^2)) / checkSizeDeg;
                        errVec = [errVec; err]; %#ok<AGROW>
                    end
                end
                passMatrix(seedIdx, cpIdx) = nPassThis / numel(pop.neurons);
                if ~isempty(errVec)
                    errMatrix(seedIdx, cpIdx) = median(errVec);
                end

                if mod(trial, 100) == 0
                    fprintf('    trial %3d: %d/%d pass, err=%.2f\n', ...
                        trial, nPassThis, numel(pop.neurons), median(errVec));
                end
                cpIdx = cpIdx + 1;
            end
        end
    end

    results(csIdx).checkSizeDeg = checkSizeDeg;
    results(csIdx).passMatrix = passMatrix;
    results(csIdx).errMatrix = errMatrix;
    results(csIdx).meanPass = mean(passMatrix, 1);
    results(csIdx).meanErr = mean(errMatrix, 1, 'omitnan');
end

%% Compare check sizes
fprintf('\n=== CHECK SIZE COMPARISON ===\n');
fprintf('Trials | 1.5 dva pass | 2.0 dva pass | 1.5 err | 2.0 err\n');
fprintf('-------+--------------+--------------+---------+--------\n');
for cp = 1:nCheckpoints
    fprintf('  %3d  |    %5.0f%%    |    %5.0f%%    | %6.2f  | %6.2f\n', ...
        checkpoints(cp), ...
        100*results(1).meanPass(cp), 100*results(2).meanPass(cp), ...
        results(1).meanErr(cp), results(2).meanErr(cp));
end

%% Figure
fig = figure('Visible', 'off', 'Position', [0 0 900 400]);

subplot(1,2,1);
hold on;
colors = [0.2 0.4 0.8; 0.8 0.3 0.2];
for csIdx = 1:nSizes
    plot(checkpoints, 100*results(csIdx).meanPass, '-s', ...
        'Color', colors(csIdx,:), 'LineWidth', 2, 'MarkerSize', 5, ...
        'MarkerFaceColor', colors(csIdx,:));
end
yline(60, 'k--', '60%');
yline(75, 'k:', '75%');
xlabel('denseAchromatic trials');
ylabel('RF channels passing quality (%)');
title('Pass rate by check size');
legend(arrayfun(@(c) sprintf('%.1f dva', c), checkSizes, 'uni', false), ...
    'Location', 'southeast');
ylim([0 100]);

subplot(1,2,2);
hold on;
for csIdx = 1:nSizes
    plot(checkpoints, results(csIdx).meanErr, '-s', ...
        'Color', colors(csIdx,:), 'LineWidth', 2, 'MarkerSize', 5, ...
        'MarkerFaceColor', colors(csIdx,:));
end
yline(0.5, 'k--', '0.5 checks');
xlabel('denseAchromatic trials');
ylabel('Median RF center error (checks)');
title('Center accuracy by check size');
legend(arrayfun(@(c) sprintf('%.1f dva', c), checkSizes, 'uni', false), ...
    'Location', 'northeast');

sgtitle('Check size comparison: 1.5 vs 2.0 dva');
print(fig, fullfile(figDir, 'checksize_comparison.png'), '-dpng', '-r150');
close(fig);
fprintf('\nSaved checksize_comparison.png\n');

exit;
