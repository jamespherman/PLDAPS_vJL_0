% convergence_test.m  How many trials at calibrated LGN rates to recover RFs?
%
% Self-contained headless test. Generates a denseAchromatic noise movie,
% creates ground-truth LNP kernels at realistic rates (peakRate=20,
% baseRate=2), accumulates STA trial-by-trial, and measures RF center
% error as a function of trial count.
%
% Output: convergence figure + text summary.

projRoot = '/home/herman_lab/Documents/PLDAPS_vK2_MASTER';
addpath(projRoot);
addpath(fullfile(projRoot, 'tasks', 'rfMap', 'supportFunctions'));
figDir = fullfile(projRoot, 'tasks', 'rfMap', '_validation', 'figs_convergence');
if ~isfolder(figDir), mkdir(figDir); end

%% Parameters (matching real LGN denseAchromatic conditions)
nY           = 22;
nX           = 34;
nLags        = 8;
checkSizeDeg = 2.0;
frameDurMs   = 100;      % ~10 Hz noise update
frameDurS    = frameDurMs / 1000;
framesPerTrial = 15;     % 1.5s trial
trialDurS    = framesPerTrial * frameDurS;
nTrialsMax   = 500;
rngSeed      = 12345;

% Calibrated rates
baseRate = 2;   % spk/s
peakRate = 20;  % spk/s

% Ground truth templates (4 locations in left hemifield)
templateCenters = [-3 2; -5 0; -3 -2; 0 3];
nTemplates = size(templateCenters, 1);
chPerTemplate = 2;
nSimCh = nTemplates * chPerTemplate;
nTotalCh = 64;

fprintf('=== CONVERGENCE TEST ===\n');
fprintf('Grid: %dx%d, frameDur=%.0fms, %d frames/trial (%.1fs)\n', ...
    nY, nX, frameDurMs, framesPerTrial, trialDurS);
fprintf('Rates: base=%.0f, peak=%.0f spk/s\n', baseRate, peakRate);
fprintf('Templates: %d at %d ch each = %d RF channels + %d noise\n', ...
    nTemplates, chPerTemplate, nSimCh, nTotalCh - nSimCh);
fprintf('Max trials: %d\n\n', nTrialsMax);

%% Generate noise movie
nTotalFrames = nTrialsMax * framesPerTrial;
rng(rngSeed, 'twister');
noiseMovie = uint8(rand(nY, nX, nTotalFrames) > 0.5);
fprintf('Generated noise movie: [%d x %d x %d]\n', nY, nX, nTotalFrames);

%% Build ground-truth kernels
rs = RandStream('mt19937ar', 'Seed', uint32(42));
kernels = cell(nTotalCh, 1);

for tmplIdx = 1:nTemplates
    cFix = templateCenters(tmplIdx, :);
    cGrid = [cFix(1) + nX * checkSizeDeg / 2, ...
             -cFix(2) + nY * checkSizeDeg / 2];

    for repIdx = 1:chPerTemplate
        ch = (tmplIdx-1) * chPerTemplate + repIdx;
        sigmaC  = 0.3 + 0.2 * rand(rs);
        excPeak = frameDurMs * (1.0 + 1.5 * rand(rs));
        pol     = (rand(rs) > 0.5) * 2 - 1;

        rfp = struct( ...
            'nChecksX', nX, 'nChecksY', nY, ...
            'checkSizeDeg', checkSizeDeg, ...
            'rfCenterDeg', cGrid, ...
            'rfSigmaCenterDeg', sigmaC, ...
            'rfSigmaSurrDeg', sigmaC * 1.5, ...
            'rfSurrWeight', 0.15, ...
            'rfExcPeakMs', excPeak, ...
            'rfInhPeakMs', excPeak * 2, ...
            'rfInhWeight', 0.25, ...
            'nSTALags', nLags, ...
            'noiseFrameDurMs', frameDurMs);
        [~, spatialKernel, temporalKernel] = buildGroundTruthRF(rfp);
        temporalKernel = pol * temporalKernel;

        spatialEnergy = sum(spatialKernel(:).^2);
        tempEnergy    = sum(temporalKernel(:).^2);
        gStd = sqrt(spatialEnergy * tempEnergy * 0.25);
        if ~(gStd > 0), gStd = 1; end

        br = baseRate * (1 + 0.4*(rand(rs)-0.5));
        pr = peakRate * (1 + 0.4*(rand(rs)-0.5));

        kernels{ch} = struct('spatialKernel', spatialKernel, ...
            'temporalKernel', temporalKernel, 'baseRate', br, ...
            'peakRate', pr, 'gStd', gStd, 'polarity', pol, ...
            'rfCenterFixFrame', cFix, 'rfCenterGridFrame', cGrid, ...
            'templateIdx', tmplIdx);
    end
end

% Noise channels
for ch = nSimCh+1:nTotalCh
    kernels{ch} = struct('isNoise', true, ...
        'baseRate', 2 + 2*rand(rs), 'peakRate', 0);
end

%% Simulate trials and accumulate STA
staAccum = cell(nTotalCh, 1);
for ch = 1:nTotalCh, staAccum{ch} = zeros(nY, nX, nLags); end
staSpikeCount = zeros(nTotalCh, nLags);

% Checkpoints for convergence measurement
checkpoints = [10 20 50 100 150 200 300 400 500];
checkpoints = checkpoints(checkpoints <= nTrialsMax);
convergenceErr = nan(numel(checkpoints), nSimCh);
convergenceMedian = nan(numel(checkpoints), 1);
cpIdx = 1;

totalSpikes = 0;

for trial = 1:nTrialsMax
    f0 = (trial-1) * framesPerTrial + 1;
    f1 = f0 + framesPerTrial - 1;
    S = double(noiseMovie(:, :, f0:f1)) - 0.5;

    % Simulate spikes for all channels
    spikeTimesPerChan = cell(nTotalCh, 1);
    stimOnTime = 0;  % arbitrary absolute time

    for ch = 1:nTotalCh
        k = kernels{ch};
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
            g = filter(k.temporalKernel, 1, proj(:));
            g = g / k.gStd;
            spkRel = simLNPSpikes(g, k.baseRate, k.peakRate, frameDurS, chRs);
        end

        if ~isempty(spkRel)
            spikeTimesPerChan{ch} = stimOnTime + spkRel;
            totalSpikes = totalSpikes + numel(spkRel);
        end
    end

    % Accumulate STA
    [staAccum, staSpikeCount] = updateSTA_denseAchromatic( ...
        staAccum, staSpikeCount, spikeTimesPerChan, stimOnTime, ...
        frameDurS, noiseMovie, f0, framesPerTrial, nLags);

    % Check convergence at checkpoints
    if cpIdx <= numel(checkpoints) && trial == checkpoints(cpIdx)
        for ch = 1:nSimCh
            if max(staSpikeCount(ch,:)) < 1, continue; end
            counts = max(staSpikeCount(ch,:), 1);
            sta = staAccum{ch} ./ reshape(counts, 1, 1, []);
            energy = squeeze(sum(sum(sta.^2, 1), 2))';
            energy = energy .* counts;
            [~, pk] = max(energy);
            slice = sta(:, :, pk);
            mag = abs(slice);
            maxMag = max(mag(:));
            if maxMag <= 0, continue; end
            w = mag; w(mag < 0.5*maxMag) = 0;
            wSum = sum(w(:));
            if wSum <= 0, continue; end
            [colGrid, rowGrid] = meshgrid(1:nX, 1:nY);
            rowC = sum(rowGrid(:) .* w(:)) / wSum;
            colC = sum(colGrid(:) .* w(:)) / wSum;
            % Grid -> fixation dva
            recX = (colC - 0.5 - nX/2) * checkSizeDeg;
            recY = -(rowC - 0.5 - nY/2) * checkSizeDeg;
            gtX = kernels{ch}.rfCenterFixFrame(1);
            gtY = kernels{ch}.rfCenterFixFrame(2);
            errDeg = sqrt((recX - gtX)^2 + (recY - gtY)^2);
            convergenceErr(cpIdx, ch) = errDeg / checkSizeDeg;
        end
        convergenceMedian(cpIdx) = median(convergenceErr(cpIdx, :), 'omitnan');
        fprintf('  Trial %3d: median RF error = %.2f checks, total spikes = %d\n', ...
            trial, convergenceMedian(cpIdx), totalSpikes);
        cpIdx = cpIdx + 1;
    end
end

%% Print final per-channel stats
fprintf('\n=== FINAL (after %d trials) ===\n', nTrialsMax);
fprintf('  ch | spikes(lag1) | rate(Hz) | peakLag(ms) | err(checks)\n');
fprintf('  ---+--------------+----------+-------------+------------\n');
for ch = 1:nSimCh
    rateHz = staSpikeCount(ch,1) / (nTrialsMax * trialDurS);
    fprintf('  %2d | %12d | %8.1f | %11.0f |     %.2f\n', ...
        ch, staSpikeCount(ch,1), rateHz, ...
        (find(staSpikeCount(ch,:) == max(staSpikeCount(ch,:)),1)-1)*frameDurMs, ...
        convergenceErr(end, ch));
end
fprintf('  Median error: %.2f checks\n', convergenceMedian(end));

%% Figure: Convergence curve
fig1 = figure('Visible', 'off', 'Position', [0 0 800 500]);
subplot(1,2,1);
plot(checkpoints, convergenceMedian, 'ko-', 'LineWidth', 2, ...
    'MarkerFaceColor', [0.3 0.3 0.3], 'MarkerSize', 8);
hold on;
yline(1.5, 'r--', '1.5 checks (pass)', 'LineWidth', 1.5);
yline(1.0, 'g:', '1.0 checks', 'LineWidth', 1);
xlabel('Trials'); ylabel('Median RF center error (check widths)');
title('RF center convergence');
grid on; ylim([0 max(10, max(convergenceMedian)*1.1)]);

subplot(1,2,2);
for ch = 1:nSimCh
    plot(checkpoints, convergenceErr(:, ch), '-o', 'MarkerSize', 3);
    hold on;
end
yline(1.5, 'r--', 'LineWidth', 1.5);
xlabel('Trials'); ylabel('Error (check widths)');
title('Per-channel convergence');
grid on; ylim([0 max(10, max(convergenceErr(:))*1.1)]);
legend(arrayfun(@(c) sprintf('ch%d', c), 1:nSimCh, 'UniformOutput', false), ...
    'Location', 'best', 'FontSize', 6);

sgtitle(sprintf('Convergence at calibrated rates (base=%d, peak=%d spk/s)', ...
    baseRate, peakRate));
print(fig1, fullfile(figDir, 'convergence_calibrated.png'), '-dpng', '-r150');
close(fig1);
fprintf('\nSaved convergence_calibrated.png\n');

%% Figure: STA gallery at final trial count
fig2 = figure('Visible', 'off', 'Position', [0 0 1000 500]);
for ch = 1:nSimCh
    counts = max(staSpikeCount(ch,:), 1);
    sta = staAccum{ch} ./ reshape(counts, 1, 1, []);
    energy = squeeze(sum(sum(sta.^2,1),2))';
    energy = energy .* counts;
    [~, pk] = max(energy);
    slice = sta(:,:,pk);
    subplot(2, nSimCh/2, ch);
    imagesc(slice); axis image;
    cLim = max(abs(slice(:)));
    if cLim > 0, caxis([-cLim cLim]); end
    colormap(gca, bluewhitered(256));
    title(sprintf('ch%d lag%d N=%d', ch, (pk-1)*frameDurMs, staSpikeCount(ch,1)), ...
        'FontSize', 7);
    set(gca, 'XTick', [], 'YTick', []);
    % Mark GT center
    hold on;
    gtGrid = kernels{ch}.rfCenterGridFrame;
    plot(gtGrid(1)/checkSizeDeg + 0.5, gtGrid(2)/checkSizeDeg + 0.5, ...
        'g+', 'MarkerSize', 12, 'LineWidth', 2);
end
sgtitle(sprintf('STA at %d trials — calibrated rates', nTrialsMax));
print(fig2, fullfile(figDir, 'sta_gallery_calibrated.png'), '-dpng', '-r150');
close(fig2);
fprintf('Saved sta_gallery_calibrated.png\n');

exit;


function cmap = bluewhitered(n)
if nargin < 1, n = 256; end
half = floor(n/2);
r = [linspace(0,1,half), ones(1,n-half)]';
g = [linspace(0,1,half), linspace(1,0,n-half)]';
b = [ones(1,half), linspace(1,0,n-half)]';
cmap = [r g b];
end
