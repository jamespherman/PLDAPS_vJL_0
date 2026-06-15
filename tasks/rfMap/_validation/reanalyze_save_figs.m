% reanalyze_save_figs.m  Save STA reconstruction figures to PNG.
% Runs the same analysis as reanalyze_real_session.m but saves figures
% instead of trying to display them.

projRoot = '/home/herman_lab/Documents/PLDAPS_vK2_MASTER';
addpath(projRoot);
addpath(fullfile(projRoot, 'tasks', 'rfMap', 'supportFunctions'));
outDir = fullfile(projRoot, 'output', '20260601_t1258_rfMap_denseChromatic');
figDir = fullfile(projRoot, 'tasks', 'rfMap', '_validation', 'figs_real_LGN');
if ~isfolder(figDir), mkdir(figDir); end

%% 1. Load and accumulate
trialFiles = dir(fullfile(outDir, 'trial*.mat'));
trialNums  = cellfun(@(f) sscanf(f, 'trial%d.mat'), {trialFiles.name});
[trialNums, sortIdx] = sort(trialNums);
trialFiles = trialFiles(sortIdx);
nTrialFiles = numel(trialFiles);

d1 = load(fullfile(outDir, trialFiles(1).name));
nCh       = d1.trVars.nChannels;
nLags     = d1.trVars.nSTALags;
nY        = d1.init.noiseGridSize(1);
nX        = d1.init.noiseGridSize(2);
frameDurS = d1.trVars.noiseFrameDurS;
stimOnCode = d1.init.codes.stimOn;
lagAxisMs  = (0:nLags-1) * frameDurS * 1000;

staAccum      = cell(nCh, 1);
for ch = 1:nCh, staAccum{ch} = zeros(nY, nX, 3, nLags, 'double'); end
staSpikeCount = zeros(nCh, nLags);
goodTrials    = 0;

for ti = 1:nTrialFiles
    T = load(fullfile(outDir, trialFiles(ti).name), 'trData', 'trVars');
    if isempty(T.trData.spikeTimes), continue; end
    evIdx = find(T.trData.eventValues == stimOnCode, 1, 'last');
    if isempty(evIdx), continue; end
    stimOnTime = T.trData.eventTimes(evIdx);
    trialDurS  = T.trVars.nFramesThisTrial * frameDurS;
    inWin = T.trData.spikeTimes >= stimOnTime & ...
            T.trData.spikeTimes <  stimOnTime + trialDurS;
    spikeTimes    = T.trData.spikeTimes(inWin);
    spikeClusters = T.trData.spikeClusters(inWin);
    if isempty(spikeTimes), continue; end
    spikeTimesPerChan = cell(nCh, 1);
    for ch = 1:nCh
        spikeTimesPerChan{ch} = spikeTimes(spikeClusters == ch);
    end
    dklDrive = T.trVars.thisTrialDklDrive;
    [staAccum, staSpikeCount] = updateSTA_denseChromatic( ...
        staAccum, staSpikeCount, spikeTimesPerChan, stimOnTime, ...
        frameDurS, dklDrive, 1, T.trVars.nFramesThisTrial, nLags);
    goodTrials = goodTrials + 1;
end
fprintf('Reconstructed STA from %d trials\n', goodTrials);

%% 2. Compute corrected energy and peak lag
peakLag    = ones(nCh, 1);
lagEnergy  = zeros(nCh, nLags);
cMaxByCh   = zeros(nCh, 1);
activeCh   = false(nCh, 1);
staMagCell = cell(nCh, 1);

for ch = 1:nCh
    if max(staSpikeCount(ch, :)) < 1, continue; end
    activeCh(ch) = true;
    counts = max(staSpikeCount(ch, :), 1);
    sta = staAccum{ch} ./ reshape(counts, 1, 1, 1, []);
    staMag = squeeze(sqrt(sum(sta.^2, 3)));
    staMagCell{ch} = staMag;
    energy = squeeze(sum(sum(staMag.^2, 1), 2))';
    energy = energy .* counts;  % corrected metric
    lagEnergy(ch, :) = energy;
    [~, peakLag(ch)] = max(energy);
    slice = staMag(:, :, peakLag(ch));
    cMaxByCh(ch) = max(abs(slice(:)));
end

%% 3. Figure 1: Power vs lag (8x8 grid)
fig1 = figure('Visible', 'off', 'Position', [0 0 1400 1000]);
for ch = 1:nCh
    subplot(8, 8, ch);
    if activeCh(ch)
        bar(lagAxisMs, lagEnergy(ch, :), 'FaceColor', [0.3 0.5 0.8], ...
            'EdgeColor', 'none');
        hold on;
        plot(lagAxisMs(peakLag(ch)), lagEnergy(ch, peakLag(ch)), 'rv', ...
            'MarkerSize', 5, 'MarkerFaceColor', 'r');
    end
    title(sprintf('ch%d N=%d', ch, staSpikeCount(ch, 1)), 'FontSize', 6);
    set(gca, 'FontSize', 5, 'XTick', [0 300 600]);
    if ch > 56, xlabel('ms', 'FontSize', 6); end
end
sgtitle(sprintf('Power vs Lag — Real LGN (%d trials, corrected energy)', goodTrials));
print(fig1, fullfile(figDir, 'power_vs_lag_all.png'), '-dpng', '-r150');
close(fig1);
fprintf('Saved power_vs_lag_all.png\n');

%% 4. Figure 2: STA spatial maps at peak lag, top 16 by cMax
[~, sortByCMax] = sort(cMaxByCh, 'descend');
topN = min(16, nnz(activeCh));
topCh = sortByCMax(1:topN);

fig2 = figure('Visible', 'off', 'Position', [0 0 1100 700]);
for ii = 1:topN
    ch = topCh(ii);
    slice = staMagCell{ch}(:, :, peakLag(ch));
    subplot(4, 4, ii);
    imagesc(slice); axis image;
    cLim = max(abs(slice(:)));
    if cLim > 0, caxis([0 cLim]); end
    colormap(gca, hot);
    title(sprintf('ch%d lag%dms N=%d', ch, lagAxisMs(peakLag(ch)), ...
        staSpikeCount(ch, 1)), 'FontSize', 8);
    set(gca, 'XTick', [], 'YTick', []);
end
sgtitle('Top 16 channels by STA magnitude (color-blind L2) — Real LGN');
print(fig2, fullfile(figDir, 'sta_spatial_top16.png'), '-dpng', '-r150');
close(fig2);
fprintf('Saved sta_spatial_top16.png\n');

%% 5. Figure 3: Per-DKL-axis STA for top 4
fig3 = figure('Visible', 'off', 'Position', [0 0 1000 600]);
axisNames = {'L-M', 'S', 'Achromatic'};
topN2 = min(4, topN);
for ii = 1:topN2
    ch = topCh(ii);
    counts = max(staSpikeCount(ch, :), 1);
    sta = staAccum{ch} ./ reshape(counts, 1, 1, 1, []);
    pk = peakLag(ch);
    for ax = 1:3
        subplot(topN2, 3, (ii-1)*3 + ax);
        slice = sta(:, :, ax, pk);
        imagesc(slice); axis image;
        cLim = max(abs(slice(:)));
        if cLim > 0, caxis([-cLim cLim]); end
        colormap(gca, bluewhitered(256));
        title(sprintf('ch%d %s lag%dms', ch, axisNames{ax}, lagAxisMs(pk)), ...
            'FontSize', 8);
        set(gca, 'XTick', [], 'YTick', []);
    end
end
sgtitle('Per-DKL-axis STA at peak lag — Top 4 channels by magnitude');
print(fig3, fullfile(figDir, 'sta_dkl_axes_top4.png'), '-dpng', '-r150');
close(fig3);
fprintf('Saved sta_dkl_axes_top4.png\n');

%% 6. Figure 4: Spike count distribution
fig4 = figure('Visible', 'off', 'Position', [0 0 800 400]);
subplot(1,2,1);
histogram(staSpikeCount(activeCh, 1), 20, 'FaceColor', [0.3 0.5 0.8]);
xlabel('Spike count (lag 1)'); ylabel('# channels');
title('Spike count distribution');
subplot(1,2,2);
peakLagActive = peakLag(activeCh);
histogram(lagAxisMs(peakLagActive), lagAxisMs(1)-50:100:lagAxisMs(end)+50, ...
    'FaceColor', [0.8 0.3 0.3]);
xlabel('Peak lag (ms)'); ylabel('# channels');
title('Peak lag distribution');
sgtitle(sprintf('Real LGN — %d active channels, %d trials', nnz(activeCh), goodTrials));
print(fig4, fullfile(figDir, 'distributions.png'), '-dpng', '-r150');
close(fig4);
fprintf('Saved distributions.png\n');

fprintf('\nAll figures saved to: %s\n', figDir);
exit;


function cmap = bluewhitered(n)
if nargin < 1, n = 256; end
half = floor(n/2);
r = [linspace(0,1,half), ones(1,n-half)]';
g = [linspace(0,1,half), linspace(1,0,n-half)]';
b = [ones(1,half), linspace(1,0,n-half)]';
cmap = [r g b];
end
