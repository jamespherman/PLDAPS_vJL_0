% reanalyze_real_session.m  Offline STA reconstruction of real LGN data
% with corrected per-lag spike counts and energy metric.
%
% The original session (20260601) ran before the per-lag spike count fix.
% This script reconstructs the STA from saved trial files using the
% corrected updateSTA_denseChromatic and the energy * N_k metric.

projRoot = '/home/herman_lab/Documents/PLDAPS_vK2_MASTER';
addpath(projRoot);
addpath(fullfile(projRoot, 'tasks', 'rfMap', 'supportFunctions'));
outDir = fullfile(projRoot, 'output', '20260601_t1258_rfMap_denseChromatic');

%% 1. Discover trial files and load session metadata
trialFiles = dir(fullfile(outDir, 'trial*.mat'));
trialNums  = cellfun(@(f) sscanf(f, 'trial%d.mat'), {trialFiles.name});
[trialNums, sortIdx] = sort(trialNums);
trialFiles = trialFiles(sortIdx);
nTrialFiles = numel(trialFiles);
fprintf('Found %d trial files in %s\n', nTrialFiles, outDir);

d1 = load(fullfile(outDir, trialFiles(1).name));
nCh          = d1.trVars.nChannels;
nLags        = d1.trVars.nSTALags;
nY           = d1.init.noiseGridSize(1);
nX           = d1.init.noiseGridSize(2);
frameDurS    = d1.trVars.noiseFrameDurS;
stimOnCode   = d1.init.codes.stimOn;
frameDurMs   = frameDurS * 1000;
lagAxisMs    = (0:nLags-1) * frameDurMs;

fprintf('nCh=%d  nLags=%d  grid=[%dx%d]  frameDur=%.0fms  lagAxis=[%s] ms\n', ...
    nCh, nLags, nY, nX, frameDurMs, num2str(lagAxisMs, '%.0f '));

%% 2. Accumulate STA from all trials
staAccum     = cell(nCh, 1);
for ch = 1:nCh, staAccum{ch} = zeros(nY, nX, 3, nLags, 'double'); end
staSpikeCount = zeros(nCh, nLags);
goodTrials    = 0;
totalSpikesKept    = 0;
totalSpikesDropped = 0;

for ti = 1:nTrialFiles
    T = load(fullfile(outDir, trialFiles(ti).name), 'trData', 'trVars');

    if isempty(T.trData.spikeTimes), continue; end

    evIdx = find(T.trData.eventValues == stimOnCode, 1, 'last');
    if isempty(evIdx), continue; end
    stimOnTime = T.trData.eventTimes(evIdx);

    % Temporal window filter (upstream, matches rfMap_finish.m)
    trialDurS = T.trVars.nFramesThisTrial * frameDurS;
    inWin = T.trData.spikeTimes >= stimOnTime & ...
            T.trData.spikeTimes <  stimOnTime + trialDurS;
    nDropped = numel(T.trData.spikeTimes) - nnz(inWin);
    spikeTimes    = T.trData.spikeTimes(inWin);
    spikeClusters = T.trData.spikeClusters(inWin);
    totalSpikesKept    = totalSpikesKept + numel(spikeTimes);
    totalSpikesDropped = totalSpikesDropped + nDropped;

    if isempty(spikeTimes), continue; end

    % Organize spikes by channel
    spikeTimesPerChan = cell(nCh, 1);
    for ch = 1:nCh
        spikeTimesPerChan{ch} = spikeTimes(spikeClusters == ch);
    end

    % Use saved per-trial DKL drive tensor
    dklDrive = T.trVars.thisTrialDklDrive;

    [staAccum, staSpikeCount] = updateSTA_denseChromatic( ...
        staAccum, staSpikeCount, spikeTimesPerChan, stimOnTime, ...
        frameDurS, dklDrive, 1, T.trVars.nFramesThisTrial, nLags);

    goodTrials = goodTrials + 1;
    if mod(goodTrials, 50) == 0
        fprintf('  %d/%d trials processed...\n', goodTrials, nTrialFiles);
    end
end

fprintf('\nReconstructed STA from %d good trials (of %d files)\n', ...
    goodTrials, nTrialFiles);
fprintf('Total spikes: %d kept, %d dropped (out-of-window)\n', ...
    totalSpikesKept, totalSpikesDropped);

%% 3. Compute mean STA, corrected energy, and peak lag per channel
peakLag     = zeros(nCh, 1);
lagEnergy   = zeros(nCh, nLags);
cMaxByCh    = zeros(nCh, 1);
activeChans = false(nCh, 1);

for ch = 1:nCh
    if max(staSpikeCount(ch, :)) < 1, continue; end
    activeChans(ch) = true;

    counts = max(staSpikeCount(ch, :), 1);
    sta = staAccum{ch} ./ reshape(counts, 1, 1, 1, []);

    % Collapse DKL axes -> per-pixel L2 magnitude [nY, nX, nLags]
    staMag = squeeze(sqrt(sum(sta.^2, 3)));

    energy = squeeze(sum(sum(staMag.^2, 1), 2))';
    % Corrected energy: multiply by N_k to flatten noise floor
    energy = energy .* counts;
    lagEnergy(ch, :) = energy;
    [~, peakLag(ch)] = max(energy);

    slice = staMag(:, :, peakLag(ch));
    cMaxByCh(ch) = max(abs(slice(:)));
end

nActive = nnz(activeChans);
fprintf('\nActive channels: %d / %d\n', nActive, nCh);

%% 4. Per-channel spike rate summary
fprintf('\nPer-channel spike counts (lag 1) and peak lag:\n');
fprintf('  ch | N(lag1) | rate(Hz) | peakLag(ms) | cMax\n');
fprintf('  ---+---------+----------+-------------+------\n');
for ch = 1:nCh
    if ~activeChans(ch), continue; end
    nSpk = staSpikeCount(ch, 1);
    totalStimDurS = goodTrials * d1.trVars.nFramesThisTrial * frameDurS;
    rateHz = nSpk / totalStimDurS;
    fprintf('  %2d | %7d | %8.1f | %11.0f | %.4f\n', ...
        ch, nSpk, rateHz, lagAxisMs(peakLag(ch)), cMaxByCh(ch));
end

%% 5. Figure: Power vs lag for all active channels
fig1 = figure('Name', 'Real LGN: Power vs Lag', 'Position', [50 100 900 600]);
nPlotCols = 8;
nPlotRows = ceil(nActive / nPlotCols);
plotIdx = 0;
for ch = 1:nCh
    if ~activeChans(ch), continue; end
    plotIdx = plotIdx + 1;
    subplot(nPlotRows, nPlotCols, plotIdx);
    bar(lagAxisMs, lagEnergy(ch, :), 'FaceColor', [0.3 0.5 0.8]);
    hold on;
    plot(lagAxisMs(peakLag(ch)), lagEnergy(ch, peakLag(ch)), 'rv', ...
        'MarkerSize', 6, 'MarkerFaceColor', 'r');
    title(sprintf('ch%d (%d)', ch, staSpikeCount(ch, 1)), 'FontSize', 7);
    set(gca, 'FontSize', 6, 'XTick', [0 200 400 600]);
    if plotIdx > (nPlotRows-1)*nPlotCols
        xlabel('ms');
    end
end
sgtitle(sprintf('Power vs Lag — Real LGN denseChromatic (%d trials, %d channels)', ...
    goodTrials, nActive));

%% 6. Figure: STA spatial maps at peak lag (top 16 by cMax)
[~, sortByCMax] = sort(cMaxByCh, 'descend');
topN = min(16, nActive);
topCh = sortByCMax(1:topN);

fig2 = figure('Name', 'Real LGN: STA Spatial Maps', 'Position', [50 50 1100 700]);
for ii = 1:topN
    ch = topCh(ii);
    counts = max(staSpikeCount(ch, :), 1);
    sta = staAccum{ch} ./ reshape(counts, 1, 1, 1, []);
    staMag = squeeze(sqrt(sum(sta.^2, 3)));
    slice = staMag(:, :, peakLag(ch));

    subplot(4, 4, ii);
    imagesc(slice);
    axis image;
    cLim = max(abs(slice(:)));
    if cLim > 0, caxis([0 cLim]); end
    colormap(gca, hot);
    title(sprintf('ch%d lag%dms N=%d', ch, lagAxisMs(peakLag(ch)), ...
        staSpikeCount(ch, 1)), 'FontSize', 8);
    set(gca, 'XTick', [], 'YTick', []);
end
sgtitle('Top 16 channels by peak STA magnitude — Real LGN');

%% 7. Figure: Per-DKL-axis STA for top 4 channels
fig3 = figure('Name', 'Real LGN: DKL Axis STA', 'Position', [100 100 1000 600]);
axisNames = {'L-M', 'S', 'Achromatic'};
topN2 = min(4, nActive);
for ii = 1:topN2
    ch = topCh(ii);
    counts = max(staSpikeCount(ch, :), 1);
    sta = staAccum{ch} ./ reshape(counts, 1, 1, 1, []);
    pk = peakLag(ch);
    for ax = 1:3
        subplot(topN2, 3, (ii-1)*3 + ax);
        slice = sta(:, :, ax, pk);
        imagesc(slice);
        axis image;
        cLim = max(abs(slice(:)));
        if cLim > 0, caxis([-cLim cLim]); end
        colormap(gca, bluewhitered(256));
        title(sprintf('ch%d %s lag%dms', ch, axisNames{ax}, lagAxisMs(pk)), ...
            'FontSize', 8);
        set(gca, 'XTick', [], 'YTick', []);
    end
end
sgtitle('Per-DKL-axis STA at peak lag — Top 4 channels');

%% 8. Summary statistics
fprintf('\n=== SUMMARY ===\n');
peakLagActive = peakLag(activeChans);
fprintf('Peak lag distribution: median=%.0fms  mean=%.0fms\n', ...
    median(lagAxisMs(peakLagActive)), mean(lagAxisMs(peakLagActive)));
lagHist = histcounts(lagAxisMs(peakLagActive), [-50, lagAxisMs + frameDurMs/2]);
fprintf('Peak lag histogram: ');
for k = 1:nLags
    fprintf('%dms:%d  ', lagAxisMs(k), lagHist(k));
end
fprintf('\n');

fprintf('Median spike count (lag 1): %d\n', ...
    median(staSpikeCount(activeChans, 1)));
fprintf('Top 4 channels by STA magnitude: %s\n', ...
    num2str(topCh(1:min(4,topN))'));

fprintf('\nFigures saved. Inspect visually for RF structure.\n');

exit;


function cmap = bluewhitered(n)
if nargin < 1, n = 256; end
half = floor(n/2);
r = [linspace(0,1,half), ones(1,n-half)]';
g = [linspace(0,1,half), linspace(1,0,n-half)]';
b = [ones(1,half), linspace(1,0,n-half)]';
cmap = [r g b];
end
