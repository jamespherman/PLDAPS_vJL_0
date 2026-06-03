function results = evaluateSimSession(sessionFolder)
% evaluateSimSession  Quantitative evaluation of a GUI-run rfMap simulation.
%
%   results = evaluateSimSession(sessionFolder)
%
%   Loads the trial files from a completed rfMap sim session, reconstructs
%   the STA accumulators (stripped from saved files), and compares recovered
%   RF centers and temporal profiles against the ground-truth kernel bank.
%
%   Produces three figures:
%     1. RF center recovery: ground-truth vs recovered positions + error
%     2. STA gallery: spatial map at peak lag for each simulated channel
%     3. Temporal profile comparison: recovered vs ground-truth per template
%
%   Example:
%     sessionFolder = 'output/20260602_t1017_rfMap_denseAchromatic';
%     results = evaluateSimSession(sessionFolder);

if nargin < 1
    error('evaluateSimSession:noInput', ...
        'Provide the session folder path (absolute or relative to repo root).');
end
if ~isfolder(sessionFolder)
    repoRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    sessionFolder = fullfile(repoRoot, sessionFolder);
end
if ~isfolder(sessionFolder)
    error('evaluateSimSession:badPath', 'Session folder not found: %s', sessionFolder);
end

thisDir = fileparts(mfilename('fullpath'));
addpath(fullfile(thisDir, '..', 'supportFunctions'));
addpath(fullfile(thisDir, '..', '..', '..'));

%% 1. Discover trial files and load metadata
trialFiles = dir(fullfile(sessionFolder, 'trial*.mat'));
trialNums = cellfun(@(f) sscanf(f, 'trial%d.mat'), {trialFiles.name});
[trialNums, sortIdx] = sort(trialNums);
trialFiles = trialFiles(sortIdx);
nTrialFiles = numel(trialFiles);
fprintf('Found %d trial files in %s\n', nTrialFiles, sessionFolder);

lastTrial = load(fullfile(sessionFolder, trialFiles(end).name));
firstTrial = load(fullfile(sessionFolder, trialFiles(1).name));

bank       = lastTrial.init.simKernelBank;
nCh        = bank.nChannels;
nSimCh     = bank.nSimulated;
stimType   = bank.stimType;
spikeCount = lastTrial.init.staSpikeCount;
rfCenters  = lastTrial.init.lastRFCentersDeg;
nLags      = firstTrial.trVars.nSTALags;

fprintf('Stim type: %s | Simulated channels: %d/%d | nLags: %d\n', ...
    stimType, nSimCh, nCh, nLags);
fprintf('Total spikes accumulated (last trial): %d\n', sum(spikeCount(:, 1)));

%% 2. Ground-truth template centers
templateXY = nan(nCh, 2);
for ch = 1:nSimCh
    k = bank.kernels{ch};
    if ~isempty(k) && isfield(k, 'rfCenterFixFrame')
        templateXY(ch, :) = k.rfCenterFixFrame;
    end
end

%% 3. RF center error analysis
simIdx = find(~isnan(templateXY(:,1)));
locErrDeg    = sqrt(sum((rfCenters(simIdx,:) - templateXY(simIdx,:)).^2, 2));
checkSizeDeg = firstTrial.trVars.checkSizeDeg;
locErrChecks = locErrDeg / checkSizeDeg;
medianErr    = median(locErrChecks, 'omitnan');
meanErr      = mean(locErrChecks, 'omitnan');

fprintf('\n=== RF CENTER RECOVERY ===\n');
fprintf('  ch | spikes | template (x,y) dva | recovered (x,y) dva | err (chk)\n');
fprintf('  ---+--------+--------------------+---------------------+----------\n');
for ii = 1:numel(simIdx)
    ch = simIdx(ii);
    fprintf('  %2d | %6d | (%+5.1f, %+5.1f)      | (%+6.2f, %+6.2f)     | %5.2f\n', ...
        ch, spikeCount(ch, 1), ...
        templateXY(ch,1), templateXY(ch,2), ...
        rfCenters(ch,1), rfCenters(ch,2), locErrChecks(ii));
end
fprintf('  Median error: %.2f checks | Mean error: %.2f checks\n', medianErr, meanErr);
fprintf('  Pass criterion (test_simMode): median <= 1.5 checks\n');
if medianErr <= 1.5
    fprintf('  PASS\n');
else
    fprintf('  FAIL\n');
end

%% 4. Reconstruct STA from trial data
fprintf('\nReconstructing STA from %d trial files...\n', nTrialFiles);

nY = firstTrial.init.noiseGridSize(1);
nX = firstTrial.init.noiseGridSize(2);
noiseRngSeed = firstTrial.init.noiseRngSeed;
nNoiseFrames = firstTrial.init.nNoiseFrames;
contrastBinary = firstTrial.trVars.contrastBinary;

noiseMovie = generateStim_denseAchromatic(nY, nX, nNoiseFrames, ...
    logical(contrastBinary), noiseRngSeed);
fprintf('  Regenerated noise movie: [%d x %d x %d]\n', nY, nX, size(noiseMovie,3));

staAccum = cell(nCh, 1);
for ch = 1:nCh, staAccum{ch} = zeros(nY, nX, nLags); end
staSpikeCountRecon = zeros(nCh, nLags);
goodTrialCount = 0;

stimOnCode = firstTrial.init.codes.stimOn;
for ti = 1:nTrialFiles
    T = load(fullfile(sessionFolder, trialFiles(ti).name), 'trData', 'trVars');

    if isempty(T.trData.spikeTimes), continue; end

    eventIdx = find(T.trData.eventValues == stimOnCode, 1, 'last');
    if isempty(eventIdx), continue; end
    stimOnTime = T.trData.eventTimes(eventIdx);

    spikesPerChan = cell(nCh, 1);
    if ~isempty(T.trData.spikeClusters)
        for ch = 1:nCh
            spikesPerChan{ch} = T.trData.spikeTimes(T.trData.spikeClusters == ch);
        end
    end

    [staAccum, staSpikeCountRecon] = updateSTA_denseAchromatic( ...
        staAccum, staSpikeCountRecon, spikesPerChan, stimOnTime, ...
        T.trVars.noiseFrameDurS, noiseMovie, ...
        T.trVars.trialStartFrame, T.trVars.nFramesThisTrial, nLags);

    goodTrialCount = goodTrialCount + 1;
end
fprintf('  Reconstructed STA from %d good trials\n', goodTrialCount);

% Verify spike counts match
countDiff = max(abs(staSpikeCountRecon - spikeCount), [], 'all');
if countDiff == 0
    fprintf('  Spike count verification: MATCH (offline == online)\n');
else
    fprintf('  Spike count verification: MISMATCH (max diff = %d)\n', countDiff);
end

%% 5. Compute per-channel STA and temporal profiles
staMean = cell(nCh, 1);
peakLag = zeros(nCh, 1);
lagEnergy = zeros(nCh, nLags);
for ch = 1:nCh
    if max(staSpikeCountRecon(ch, :)) < 1, continue; end
    counts = max(staSpikeCountRecon(ch, :), 1);
    staMean{ch} = staAccum{ch} ./ reshape(counts, 1, 1, []);
    for lag = 1:nLags
        lagEnergy(ch, lag) = sum(sum(staMean{ch}(:,:,lag).^2));
    end
    lagEnergy(ch, :) = lagEnergy(ch, :) .* counts;
    [~, peakLag(ch)] = max(lagEnergy(ch,:));
end

%% 6. Temporal profile comparison per template
nTemplates = size(bank.templateCenters, 1);
chPerTemplate = bank.nSimulated / nTemplates;
frameDurMs = firstTrial.trVars.noiseFrameDurS * 1000;
lagAxisMs = (0:nLags-1) * frameDurMs;

templateTemporalRecovered = zeros(nTemplates, nLags);
templateTemporalGT        = zeros(nTemplates, nLags);
templateSpatialCorr       = zeros(nTemplates, 1);
for tmpl = 1:nTemplates
    chRange = (tmpl-1)*chPerTemplate + (1:chPerTemplate);
    chRange = chRange(chRange <= nSimCh);

    % Ground-truth temporal kernel
    k = bank.kernels{chRange(1)};
    templateTemporalGT(tmpl,:) = k.temporalKernel(:)';

    % Average recovered temporal profile across channels sharing a template
    recTemp = zeros(1, nLags);
    nValid = 0;
    for ch = chRange
        if max(staSpikeCountRecon(ch, :)) < 1, continue; end
        slice = staMean{ch}(:, :, peakLag(ch));
        [peakRow, peakCol] = find(abs(slice) == max(abs(slice(:))), 1);
        if isempty(peakRow), continue; end
        pixTrace = squeeze(staMean{ch}(peakRow, peakCol, :))';
        if pixTrace(peakLag(ch)) < 0
            pixTrace = -pixTrace;
        end
        recTemp = recTemp + pixTrace / max(abs(pixTrace));
        nValid = nValid + 1;
    end
    if nValid > 0
        recTemp = recTemp / nValid;
    end
    templateTemporalRecovered(tmpl,:) = recTemp;

    % Spatial correlation at peak lag (ground truth vs recovered)
    spatCorr = nan(numel(chRange), 1);
    for ci = 1:numel(chRange)
        ch = chRange(ci);
        kk = bank.kernels{ch};
        if isempty(kk) || max(staSpikeCountRecon(ch, :)) < 1, continue; end
        gtSpatial  = kk.spatialKernel(:);
        recSpatial = staMean{ch}(:,:,peakLag(ch));
        recSpatial = recSpatial(:);
        if kk.polarity < 0
            recSpatial = -recSpatial;
        end
        cc = corrcoef(gtSpatial, recSpatial);
        spatCorr(ci) = cc(1,2);
    end
    templateSpatialCorr(tmpl) = mean(spatCorr, 'omitnan');
end

fprintf('\n=== TEMPORAL & SPATIAL RECOVERY PER TEMPLATE ===\n');
fprintf('  tmpl | center (x,y)   | spat corr | temp peak lag | polarity\n');
fprintf('  -----+----------------+-----------+--------------+---------\n');
for tmpl = 1:nTemplates
    ch1 = (tmpl-1)*chPerTemplate + 1;
    k = bank.kernels{ch1};
    fprintf('  %4d | (%+5.1f, %+5.1f) |   %+.3f   |     %d (%3.0f ms) |    %s\n', ...
        tmpl, bank.templateCenters(tmpl,1), bank.templateCenters(tmpl,2), ...
        templateSpatialCorr(tmpl), peakLag(ch1), lagAxisMs(peakLag(ch1)), ...
        ternary(k.polarity > 0, 'ON', 'OFF'));
end

%% 7. Compute SNR at peak lag per channel
snrPeakLag = nan(nSimCh, 1);
for ch = 1:nSimCh
    if staSpikeCountRecon(ch) < 1, continue; end
    slice = staMean{ch}(:,:,peakLag(ch));
    peakVal = max(abs(slice(:)));
    noiseSlice = staMean{ch}(:,:,1);  % lag 1 = 0ms, mostly noise
    noiseStd = std(noiseSlice(:));
    if noiseStd > 0
        snrPeakLag(ch) = peakVal / noiseStd;
    end
end
fprintf('\n=== SIGNAL-TO-NOISE (peak / noise-floor std) ===\n');
fprintf('  Median SNR at peak lag: %.1f\n', median(snrPeakLag, 'omitnan'));
validSNR = snrPeakLag(~isnan(snrPeakLag));
fprintf('  Range: [%.1f, %.1f]\n', min(validSNR), max(validSNR));

%% 8. Convergence trace (RF center error vs trial count)
% Each saved trial file carries init.lastRFCentersDeg — the cumulative RF
% center estimate up to that trial. Read it at ~10 evenly spaced checkpoints
% to trace convergence without re-running computeRFCenters (which needs the
% full p struct with draw/rig fields not saved in trial files).
checkpoints = round(linspace(max(10, round(nTrialFiles/10)), nTrialFiles, min(10, nTrialFiles)));
checkpoints = unique(checkpoints);
convergenceErr = nan(numel(checkpoints), 1);
convergenceTrials = checkpoints;

for cpIdx = 1:numel(checkpoints)
    ti = checkpoints(cpIdx);
    Tcp = load(fullfile(sessionFolder, trialFiles(ti).name), 'init');
    rfConv = Tcp.init.lastRFCentersDeg;
    errConv = sqrt(sum((rfConv(simIdx,:) - templateXY(simIdx,:)).^2, 2)) / checkSizeDeg;
    convergenceErr(cpIdx) = median(errConv, 'omitnan');
end

%% ======== FIGURES ========

%% Figure 1: RF Center Recovery
fig1 = figure('Name', 'RF Center Recovery', 'Position', [50 100 1200 500]);

subplot(1,3,1); hold on;
for tmpl = 1:nTemplates
    chRange = (tmpl-1)*chPerTemplate + (1:chPerTemplate);
    chRange = chRange(chRange <= nSimCh);
    plot(templateXY(chRange(1),1), templateXY(chRange(1),2), 'ks', ...
        'MarkerSize', 14, 'LineWidth', 2);
    for ch = chRange
        if ~isnan(rfCenters(ch,1))
            plot(rfCenters(ch,1), rfCenters(ch,2), 'ro', ...
                'MarkerSize', 6, 'MarkerFaceColor', [1 .4 .4]);
            plot([templateXY(ch,1) rfCenters(ch,1)], ...
                 [templateXY(ch,2) rfCenters(ch,2)], 'r-', 'LineWidth', 0.5);
        end
    end
end
axis equal; grid on;
xlabel('x (dva)'); ylabel('y (dva)');
title('Ground truth (squares) vs Recovered (circles)');
xl = max(abs([xlim ylim])); axis([-xl xl -xl xl]*1.1);

subplot(1,3,2);
histogram(locErrChecks, 0:0.25:max(locErrChecks)+0.5);
hold on;
xline(medianErr, 'r--', sprintf('median = %.2f', medianErr), 'LineWidth', 2);
xline(1.5, 'k:', 'pass threshold', 'LineWidth', 1);
xlabel('Location error (check widths)'); ylabel('Count');
title('RF center error distribution');

subplot(1,3,3);
plot(convergenceTrials, convergenceErr, 'ko-', 'LineWidth', 1.5, ...
    'MarkerFaceColor', [.3 .3 .3], 'MarkerSize', 6);
hold on;
yline(1.5, 'k:', 'pass threshold');
yline(1.0, 'g:', '1-check target');
xlabel('Trial number'); ylabel('Median error (check widths)');
title('Convergence of RF center error');
grid on;
sgtitle(sprintf('RF Center Recovery — %d trials, median err = %.2f checks', ...
    nTrialFiles, medianErr));

%% Figure 2: STA Gallery at peak lag
nCols = chPerTemplate;
nRows = nTemplates;
fig2 = figure('Name', 'STA Gallery', 'Position', [50 100 nCols*220 nRows*180]);
for tmpl = 1:nTemplates
    for rep = 1:chPerTemplate
        ch = (tmpl-1)*chPerTemplate + rep;
        if ch > nSimCh, break; end
        subplot(nRows, nCols, (tmpl-1)*nCols + rep);
        if max(staSpikeCountRecon(ch, :)) >= 1
            slice = staMean{ch}(:,:,peakLag(ch));
            imagesc(slice); axis image;
            cLim = max(abs(slice(:)));
            if cLim > 0, caxis([-cLim cLim]); end
            colormap(gca, bluewhitered(256));
            hold on;
            % Mark ground-truth center on the grid
            k = bank.kernels{ch};
            gtGridX = k.rfCenterGridFrame(1) / checkSizeDeg + 0.5;
            gtGridY = k.rfCenterGridFrame(2) / checkSizeDeg + 0.5;
            plot(gtGridX, gtGridY, 'g+', 'MarkerSize', 10, 'LineWidth', 2);
        end
        title(sprintf('ch%d (lag%d, %dk spk)', ch, peakLag(ch), ...
            round(staSpikeCountRecon(ch, 1)/1000)), 'FontSize', 8);
        set(gca, 'XTick', [], 'YTick', []);
    end
end
sgtitle(sprintf('STA at peak lag — %s (%d trials)', stimType, nTrialFiles));

%% Figure 3: Temporal profile comparison
fig3 = figure('Name', 'Temporal Profiles', 'Position', [100 100 1000 600]);
for tmpl = 1:nTemplates
    subplot(2, ceil(nTemplates/2), tmpl);
    gtNorm = templateTemporalGT(tmpl,:);
    if max(abs(gtNorm)) > 0
        gtNorm = gtNorm / max(abs(gtNorm));
    end
    recNorm = templateTemporalRecovered(tmpl,:);
    if max(abs(recNorm)) > 0
        recNorm = recNorm / max(abs(recNorm));
    end
    plot(lagAxisMs, gtNorm, 'k-', 'LineWidth', 2); hold on;
    plot(lagAxisMs, recNorm, 'r-o', 'LineWidth', 1.5, 'MarkerSize', 4);
    xlabel('Lag (ms)'); ylabel('Normalized amplitude');
    title(sprintf('Template %d (%+.0f, %+.0f) r=%.2f', tmpl, ...
        bank.templateCenters(tmpl,1), bank.templateCenters(tmpl,2), ...
        templateSpatialCorr(tmpl)), 'FontSize', 9);
    legend('Ground truth', 'Recovered', 'Location', 'best');
    grid on; ylim([-0.6 1.2]);
end
sgtitle(sprintf('Temporal kernel recovery — %s (%d trials)', stimType, nTrialFiles));

%% Pack results
results.sessionFolder    = sessionFolder;
results.stimType         = stimType;
results.nTrialFiles      = nTrialFiles;
results.nGoodTrials      = goodTrialCount;
results.nSimChannels     = nSimCh;
results.checkSizeDeg     = checkSizeDeg;
results.spikeCount       = spikeCount;
results.rfCentersRecovered = rfCenters;
results.templateCenters  = templateXY;
results.locErrChecks     = locErrChecks;
results.medianLocErrChecks = medianErr;
results.meanLocErrChecks   = meanErr;
results.peakLag          = peakLag;
results.snrPeakLag       = snrPeakLag;
results.templateSpatialCorr     = templateSpatialCorr;
results.templateTemporalGT      = templateTemporalGT;
results.templateTemporalRecov   = templateTemporalRecovered;
results.convergenceTrials = convergenceTrials;
results.convergenceErr    = convergenceErr;
results.staAccum          = staAccum;
results.staSpikeCount     = staSpikeCountRecon;
results.staMean           = staMean;
results.lagAxisMs         = lagAxisMs;
results.figures           = [fig1, fig2, fig3];

fprintf('\n=== SUMMARY ===\n');
fprintf('  Trials: %d files, %d good\n', nTrialFiles, goodTrialCount);
fprintf('  Median RF center error: %.2f checks (%s)\n', medianErr, ...
    ternary(medianErr <= 1.5, 'PASS', 'FAIL'));
fprintf('  Mean spatial correlation: %.3f\n', mean(templateSpatialCorr, 'omitnan'));
fprintf('  Median SNR at peak lag: %.1f\n', median(snrPeakLag, 'omitnan'));
fprintf('  Total spikes (all simulated ch): %d\n', sum(spikeCount(1:nSimCh, 1)));
fprintf('  Mean spikes/channel: %.0f\n', mean(spikeCount(1:nSimCh, 1)));

end


function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end


function cmap = bluewhitered(n)
% Simple blue-white-red diverging colormap.
if nargin < 1, n = 256; end
half = floor(n/2);
r = [linspace(0,1,half), ones(1,n-half)]';
g = [linspace(0,1,half), linspace(1,0,n-half)]';
b = [ones(1,half), linspace(1,0,n-half)]';
cmap = [r g b];
end
