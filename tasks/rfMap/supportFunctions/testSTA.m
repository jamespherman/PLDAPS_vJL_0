function results = testSTA(params)
% testSTA  Validate STA recovery using LNP simulation.
%
%   results = testSTA(params)
%
%   Uses an LNP (Linear-Nonlinear-Poisson) model to generate ground-truth
%   spike trains from a known spatiotemporal RF kernel, then feeds those
%   spikes through the same updateSTA function used by the rfMap task.
%
%   This test should be run BEFORE deploying the rfMap task on the rig to
%   verify that the STA algorithm correctly recovers a known stRF.
%
%   params fields (all optional, with defaults):
%     .checkSizeDeg      - check size (degrees), default 0.5
%     .nChecksX          - grid width (checks), default 40
%     .nChecksY          - grid height (checks), default 30
%     .noiseFrameDurMs   - noise frame duration (ms), default 30
%     .movieDurationS    - total movie duration (seconds), default 300
%     .rfCenterDeg       - [x, y] RF center (degrees), default [5, 3]
%     .rfSigmaCenterDeg  - center Gaussian sigma (degrees), default 0.8
%     .rfSigmaSurrDeg    - surround Gaussian sigma (degrees), default 2.5
%     .rfSurrWeight      - surround weight, default 0.5
%     .rfExcPeakMs       - excitatory peak latency (ms), default 30
%     .rfInhPeakMs       - inhibitory peak latency (ms), default 60
%     .rfInhWeight       - inhibitory temporal weight, default 0.5
%     .baseRate          - baseline firing rate (spk/s), default 5
%     .peakRate          - peak driven rate (spk/s), default 50
%     .trialDurationS    - trial duration (seconds), default 3
%     .nSTALags          - number of STA lags, default 8
%     .nChannels         - number of simulated channels, default 1
%     .rngSeed           - RNG seed for noise movie, default 42
%
%   Returns:
%     results.groundTruth         - true stRF kernel [nY, nX, nLags]
%     results.spatialKernel       - spatial component [nY, nX]
%     results.temporalKernel      - temporal component [nLags, 1]
%     results.recoveredSTA        - recovered STA [nY, nX, nLags]
%     results.correlation         - spatial corr at peak lag
%     results.temporalCorrelation - temporal profile corr
%     results.peakLagIdx          - recovered peak lag index
%     results.peakLocation        - [row, col] of STA peak
%     results.trueLocation        - [row, col] of true RF peak
%     results.locationError       - distance error in checks
%     results.nSpikes             - total spike count
%     results.meanRate            - mean firing rate (spk/s)
%     results.convergenceCurve    - struct with .nSpikes and .correlation
%     results.params              - parameters used

% Ensure support functions are on the path
thisDir = fileparts(mfilename('fullpath'));
addpath(thisDir);

%% 0. Set defaults
if nargin < 1, params = struct(); end
if ~isfield(params, 'checkSizeDeg'),     params.checkSizeDeg = 0.5; end
if ~isfield(params, 'nChecksX'),         params.nChecksX = 40; end
if ~isfield(params, 'nChecksY'),         params.nChecksY = 30; end
if ~isfield(params, 'noiseFrameDurMs'),  params.noiseFrameDurMs = 30; end
if ~isfield(params, 'movieDurationS'),   params.movieDurationS = 300; end
if ~isfield(params, 'rfCenterDeg'),      params.rfCenterDeg = [5, 3]; end
if ~isfield(params, 'rfSigmaCenterDeg'), params.rfSigmaCenterDeg = 0.8; end
if ~isfield(params, 'rfSigmaSurrDeg'),   params.rfSigmaSurrDeg = 2.5; end
if ~isfield(params, 'rfSurrWeight'),     params.rfSurrWeight = 0.5; end
if ~isfield(params, 'rfExcPeakMs'),      params.rfExcPeakMs = 30; end
if ~isfield(params, 'rfInhPeakMs'),      params.rfInhPeakMs = 60; end
if ~isfield(params, 'rfInhWeight'),      params.rfInhWeight = 0.5; end
if ~isfield(params, 'baseRate'),         params.baseRate = 5; end
if ~isfield(params, 'peakRate'),         params.peakRate = 50; end
if ~isfield(params, 'trialDurationS'),   params.trialDurationS = 3; end
if ~isfield(params, 'nSTALags'),         params.nSTALags = 8; end
if ~isfield(params, 'nChannels'),        params.nChannels = 1; end
if ~isfield(params, 'rngSeed'),          params.rngSeed = 42; end

frameDurS = params.noiseFrameDurMs / 1000;
nFrames = ceil(params.movieDurationS / frameDurS);

fprintf('\n=== testSTA: Validating STA recovery with LNP simulation ===\n');
fprintf('  Grid: %d x %d checks (%.1f deg checks)\n', ...
    params.nChecksY, params.nChecksX, params.checkSizeDeg);
fprintf('  Movie: %d frames (%.1f min), frame dur: %d ms\n', ...
    nFrames, params.movieDurationS / 60, params.noiseFrameDurMs);
fprintf('  RF center: [%.1f, %.1f] deg, sigma_c: %.2f deg\n', ...
    params.rfCenterDeg(1), params.rfCenterDeg(2), params.rfSigmaCenterDeg);
fprintf('\n');

%% 1. Generate noise movie
fprintf('Step 1: Generating noise movie...\n');
[noiseMovie, ~] = generateNoiseMovie(params.nChecksY, params.nChecksX, ...
    nFrames, 'luminance', true, params.rngSeed);

%% 2. Build ground-truth stRF kernel
fprintf('Step 2: Building ground-truth stRF kernel...\n');
rfParams = struct( ...
    'nChecksX',         params.nChecksX, ...
    'nChecksY',         params.nChecksY, ...
    'checkSizeDeg',     params.checkSizeDeg, ...
    'rfCenterDeg',      params.rfCenterDeg, ...
    'rfSigmaCenterDeg', params.rfSigmaCenterDeg, ...
    'rfSigmaSurrDeg',   params.rfSigmaSurrDeg, ...
    'rfSurrWeight',     params.rfSurrWeight, ...
    'rfExcPeakMs',      params.rfExcPeakMs, ...
    'rfInhPeakMs',      params.rfInhPeakMs, ...
    'rfInhWeight',      params.rfInhWeight, ...
    'nSTALags',         params.nSTALags, ...
    'noiseFrameDurMs',  params.noiseFrameDurMs);

[groundTruth, spatialKernel, temporalKernel] = buildGroundTruthRF(rfParams);

% True RF peak location
[~, peakIdx] = max(abs(spatialKernel(:)));
[trueRow, trueCol] = ind2sub(size(spatialKernel), peakIdx);
fprintf('  True RF peak at check [row=%d, col=%d] = [%.1f, %.1f] deg\n', ...
    trueRow, trueCol, ...
    (trueCol - 0.5) * params.checkSizeDeg, ...
    (trueRow - 0.5) * params.checkSizeDeg);

% Peak temporal lag
[~, truePeakLag] = max(abs(temporalKernel));
fprintf('  True peak temporal lag: %d (%d ms)\n', ...
    truePeakLag, (truePeakLag - 1) * params.noiseFrameDurMs);

%% 3. Simulate spikes via LNP model
fprintf('Step 3: Simulating spikes (LNP model)...\n');

% 3a. Compute spatial projection: proj(t) = K_spatial(:)' * S(:,t)
%     where S is mean-subtracted noise (-0.5 / +0.5)
spatFlat = spatialKernel(:)';
proj = zeros(1, nFrames);
chunkSize = 2000;
for startF = 1:chunkSize:nFrames
    endF = min(startF + chunkSize - 1, nFrames);
    idx = startF:endF;
    chunk = double(reshape(noiseMovie(:, :, idx), [], length(idx))) - 0.5;
    proj(idx) = spatFlat * chunk;
end

% 3b. Compute generator signal via causal temporal filter
%     g(t) = sum_k temporalKernel(k) * proj(t - k + 1)
g = filter(temporalKernel, 1, proj);

% 3c. Normalize g to unit variance so the sigmoid operates in its
%     quasi-linear regime. Without this, large ||K||^2 (especially from
%     broad surrounds) drives g to extreme values where the sigmoid
%     saturates, biasing the STA toward surround features.
gStd = std(g(params.nSTALags:end));  % skip transient at start
if gStd > 0
    g = g / gStd;
end
fprintf('  Generator signal std (pre-norm): %.2f, normalized to 1.0\n', gStd);

% 3c. Apply sigmoid nonlinearity: r(t) = baseRate + peakRate * sigmoid(g)
rate = params.baseRate + params.peakRate ./ (1 + exp(-g));

fprintf('  Rate range: [%.1f, %.1f] spk/s, mean: %.1f spk/s\n', ...
    min(rate), max(rate), mean(rate));

% 3d. Generate Poisson spikes at 1-ms resolution (Bernoulli approx)
rng(params.rngSeed + 1000, 'twister');
dtFine = 0.001;  % 1 ms resolution
nBinsPerFrame = round(frameDurS / dtFine);

allSpikeTimes = cell(params.nChannels, 1);
for ch = 1:params.nChannels
    ratePerBin = repelem(rate, nBinsPerFrame);
    spikeEvents = rand(size(ratePerBin)) < ratePerBin * dtFine;
    allSpikeTimes{ch} = (find(spikeEvents) - 0.5) * dtFine;
end

totalSpikes = sum(cellfun(@length, allSpikeTimes));
meanRate = totalSpikes / (params.nChannels * params.movieDurationS);
fprintf('  Generated %d spikes (%.1f spk/s observed mean)\n', ...
    totalSpikes, meanRate);

%% 4. Segment into trials and run STA accumulation
fprintf('Step 4: Running STA accumulation trial-by-trial...\n');

framesPerTrial = round(params.trialDurationS / frameDurS);
nTrials = floor(nFrames / framesPerTrial);

% Initialize STA accumulators
staAccum = cell(params.nChannels, 1);
for ch = 1:params.nChannels
    staAccum{ch} = zeros(params.nChecksY, params.nChecksX, params.nSTALags);
end
staSpikeCount = zeros(params.nChannels, 1);

% Convergence tracking
convergenceNSpikes = [];
convergenceCorr    = [];
convergenceCheckInterval = max(1, floor(nTrials / 20));

% Process each trial (simulating the PLDAPS _finish.m flow)
for trial = 1:nTrials
    trialStartFrame = (trial - 1) * framesPerTrial + 1;
    noiseOnTime     = (trialStartFrame - 1) * frameDurS;
    trialEndTime    = noiseOnTime + framesPerTrial * frameDurS;

    % Extract spikes that fall within this trial's noise presentation
    trialSpikes = cell(params.nChannels, 1);
    for ch = 1:params.nChannels
        valid = allSpikeTimes{ch} >= noiseOnTime & ...
                allSpikeTimes{ch} < trialEndTime;
        trialSpikes{ch} = allSpikeTimes{ch}(valid);
    end

    % Accumulate STA (calls the same function the task will use)
    [staAccum, staSpikeCount] = updateSTA(staAccum, staSpikeCount, ...
        trialSpikes, noiseOnTime, frameDurS, noiseMovie, ...
        trialStartFrame, framesPerTrial, params.nSTALags);

    % Convergence checkpoint
    if mod(trial, convergenceCheckInterval) == 0 || trial == nTrials
        if staSpikeCount(1) > 0
            currentSTA = staAccum{1} / staSpikeCount(1);
            staSlice  = currentSTA(:, :, truePeakLag);
            trueSlice = groundTruth(:, :, truePeakLag);
            r = corrcoef(staSlice(:), trueSlice(:));
            convergenceNSpikes(end+1) = staSpikeCount(1); %#ok<AGROW>
            convergenceCorr(end+1)    = r(1,2);            %#ok<AGROW>
        end
    end

    % Progress
    if mod(trial, ceil(nTrials / 10)) == 0
        fprintf('  Trial %d/%d (%.0f%%), %d spikes\n', ...
            trial, nTrials, 100 * trial / nTrials, staSpikeCount(1));
    end
end

%% 5. Evaluate recovered STA
fprintf('\nStep 5: Evaluating recovered STA...\n');

recoveredSTA = staAccum{1} / staSpikeCount(1);

% Peak temporal lag in recovered STA
lagEnergy = squeeze(sum(sum(recoveredSTA.^2, 1), 2));
[~, recoveredPeakLag] = max(lagEnergy);

% Peak spatial location at peak lag
staAtPeakLag = recoveredSTA(:, :, recoveredPeakLag);
[~, staPeakIdx] = max(abs(staAtPeakLag(:)));
[peakRow, peakCol] = ind2sub(size(staAtPeakLag), staPeakIdx);

% Spatial correlation at peak lag (whole grid)
trueAtPeakLag = groundTruth(:, :, truePeakLag);
r = corrcoef(staAtPeakLag(:), trueAtPeakLag(:));
finalCorr = r(1, 2);

% Local ROI spatial correlation (±10 checks around true RF center).
% This is more meaningful than whole-grid correlation because the RF
% covers only a small fraction of the grid; noise at distant pixels
% dilutes the whole-grid metric.
roiHalf = 10;
roiRows = max(1, trueRow - roiHalf) : min(params.nChecksY, trueRow + roiHalf);
roiCols = max(1, trueCol - roiHalf) : min(params.nChecksX, trueCol + roiHalf);
staROI  = staAtPeakLag(roiRows, roiCols);
trueROI = trueAtPeakLag(roiRows, roiCols);
rROI = corrcoef(staROI(:), trueROI(:));
localCorr = rROI(1, 2);

% Location error
locationErr = sqrt((peakRow - trueRow)^2 + (peakCol - trueCol)^2);

% Temporal profile at peak spatial location
trueTemp = squeeze(groundTruth(trueRow, trueCol, :));
recTemp  = squeeze(recoveredSTA(peakRow, peakCol, :));
trueTemp = trueTemp / max(abs(trueTemp));
recTemp  = recTemp  / max(abs(recTemp));
rTemp = corrcoef(trueTemp, recTemp);

fprintf('  Peak lag: true=%d (%d ms), recovered=%d (%d ms)\n', ...
    truePeakLag, (truePeakLag - 1) * params.noiseFrameDurMs, ...
    recoveredPeakLag, (recoveredPeakLag - 1) * params.noiseFrameDurMs);
fprintf('  Peak location: true=[%d,%d], recovered=[%d,%d], err=%.1f chk\n', ...
    trueRow, trueCol, peakRow, peakCol, locationErr);
fprintf('  Spatial corr (whole grid): r = %.4f\n', finalCorr);
fprintf('  Spatial corr (local ROI):  r = %.4f\n', localCorr);
fprintf('  Temporal profile corr:     r = %.4f\n', rTemp(1, 2));
fprintf('  Total spikes: %d\n\n', staSpikeCount(1));

%% 6. Display results

% 6a. Online STA display (tests initSTADisplay + plotSTA)
fprintf('Step 6: Generating figures...\n');
figData = initSTADisplay(params.nSTALags, params.nChannels, ...
    params.noiseFrameDurMs);
plotSTA(figData, staAccum, staSpikeCount, 1);

% 6b. Ground truth vs recovered comparison figure
bwrMap = figData.bwrMap;
lagTimes = ((1:params.nSTALags) - 1) * params.noiseFrameDurMs;

hFig = figure('Name', 'testSTA: Ground Truth vs Recovered STA', ...
    'NumberTitle', 'off', ...
    'Position', [50 50 1600 700], ...
    'Color', 'w');

nL = params.nSTALags;

% Row 1: ground truth kernel at each lag
for k = 1:nL
    subplot(3, nL, k);
    imagesc(groundTruth(:, :, k));
    axis image; axis off;
    colormap(gca, bwrMap);
    cMax = max(abs(groundTruth(:)));
    caxis([-cMax cMax]);
    title(sprintf('%d ms', lagTimes(k)), 'FontSize', 9);
    if k == 1
        ylabel('True RF', 'FontSize', 11, 'FontWeight', 'bold');
    end
end

% Row 2: recovered STA at each lag
for k = 1:nL
    subplot(3, nL, nL + k);
    imagesc(recoveredSTA(:, :, k));
    axis image; axis off;
    colormap(gca, bwrMap);
    cMax = max(abs(recoveredSTA(:)));
    caxis([-cMax cMax]);
    if k == 1
        ylabel('STA', 'FontSize', 11, 'FontWeight', 'bold');
    end
end

% Row 3, left: convergence curve
nBottom = max(2, floor(nL / 3));
subplot(3, nL, 2*nL + 1 : 2*nL + nBottom);
plot(convergenceNSpikes, convergenceCorr, 'b-o', ...
    'LineWidth', 1.5, 'MarkerSize', 4);
xlabel('Number of Spikes');
ylabel('Correlation with true RF');
title('STA Convergence');
grid on;
ylim([min(0, min(convergenceCorr) - 0.05), 1.05]);

% Row 3, middle: temporal profile comparison
subplot(3, nL, 2*nL + nBottom + 1 : 2*nL + 2*nBottom);
plot(lagTimes, trueTemp, 'k-', 'LineWidth', 2); hold on;
plot(lagTimes, recTemp,  'r--', 'LineWidth', 2);
xlabel('Lag (ms)');
ylabel('Normalized amplitude');
title('Temporal Profile');
legend('True', 'Recovered', 'Location', 'best');
grid on;

% Row 3, right: summary text
subplot(3, nL, 2*nL + 2*nBottom + 1 : 3*nL);
axis off;
summaryLines = {
    sprintf('Total spikes: %d', staSpikeCount(1));
    sprintf('Mean rate: %.1f spk/s', meanRate);
    '';
    sprintf('Spatial r (grid): %.4f', finalCorr);
    sprintf('Spatial r (ROI):  %.4f', localCorr);
    sprintf('Temporal r:       %.4f', rTemp(1, 2));
    '';
    sprintf('Peak lag: %d ms', (recoveredPeakLag - 1) * params.noiseFrameDurMs);
    sprintf('Location err: %.1f chk', locationErr);
    '';
    sprintf('Grid: %dx%d, %.1f deg/chk', ...
        params.nChecksY, params.nChecksX, params.checkSizeDeg);
    sprintf('Duration: %.0f s', params.movieDurationS);
    };
text(0.05, 0.95, summaryLines, 'VerticalAlignment', 'top', ...
    'FontSize', 10, 'FontName', 'FixedWidth', 'Units', 'normalized');

drawnow;

% Save figures to disk (supports headless / -nodisplay operation)
figDir = fullfile(thisDir, '..', 'output', 'testSTA_figures');
if ~exist(figDir, 'dir'), mkdir(figDir); end

print(figData.fig, fullfile(figDir, 'sta_online_display.png'), '-dpng', '-r150');
fprintf('  Saved: %s\n', fullfile(figDir, 'sta_online_display.png'));

print(hFig, fullfile(figDir, 'sta_ground_truth_vs_recovered.png'), '-dpng', '-r150');
fprintf('  Saved: %s\n', fullfile(figDir, 'sta_ground_truth_vs_recovered.png'));

%% 7. Package results
results.groundTruth         = groundTruth;
results.spatialKernel       = spatialKernel;
results.temporalKernel      = temporalKernel;
results.recoveredSTA        = recoveredSTA;
results.correlation         = finalCorr;
results.localCorrelation    = localCorr;
results.temporalCorrelation = rTemp(1, 2);
results.peakLagIdx          = recoveredPeakLag;
results.peakLocation        = [peakRow, peakCol];
results.trueLocation        = [trueRow, trueCol];
results.locationError       = locationErr;
results.nSpikes             = staSpikeCount(1);
results.meanRate            = meanRate;
results.convergenceCurve.nSpikes     = convergenceNSpikes;
results.convergenceCurve.correlation = convergenceCorr;
results.params              = params;

fprintf('=== testSTA complete ===\n\n');

end
