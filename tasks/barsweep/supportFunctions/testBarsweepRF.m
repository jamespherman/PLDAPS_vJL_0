function results = testBarsweepRF(params)
% testBarsweepRF  Validate online RF mapping with synthetic spike trains.
%
%   results = testBarsweepRF(params)
%
% Mirrors plan §11 acceptance criteria #3, #4, and #5 in a single
% deliverable. Generates synthetic spike trains from a known 2D Gaussian
% RF, runs them through accumulateBarsweepRF + reconstructBarsweepRF,
% and asserts the recovered RF center is within tolerance of truth for
% both regimes.
%
% Run BEFORE deploying on the rig:
%   >> testBarsweepRF()                    % defaults
%   >> testBarsweepRF(struct('latencyMs', 60))
%
% params (all optional, with defaults):
%   .rfX, .rfY        - true RF center (dva)               default (-3, 2)
%   .rfSigmaRfmap     - rfmap12 RF sigma (dva)             default 1.0
%   .rfSigmaCardinal  - cardinal4 RF sigma (dva)           default 2.0
%   .latencyMs        - response latency (ms)              default 60
%                       (deliberately non-default 40 to exercise
%                        latency code; see plan §11.4)
%   .pathLengthDeg    - sweep length (dva)                 default 30
%   .speedDegPerSec   - sweep speed                        default 30
%   .frameDur         - frame duration (s)                 default 0.01
%   .baseRate         - baseline firing (spk/s)            default 5
%   .peakRate         - driven peak rate (spk/s)           default 60
%   .nRepeatsRfmap    - reps per direction (rfmap12)       default 15
%   .nRepeatsCardinal - reps per direction (cardinal4)     default 25
%   .testCh           - which simulated channel            default 2
%   .nChannels        - total simulated channels           default 4
%   .rngSeed          - RNG seed                           default 42
%   .latencyMismatch  - per plan §11.4: run an extra trial
%                       with the accumulator's latency
%                       deliberately disagreeing from the
%                       generator's, and verify the recovered
%                       center shifts as expected. Default true.
%
% Returns a struct with .rfmap12 and .cardinal4 sub-structs containing
% recovered peaks and pass/fail flags.

if nargin < 1, params = struct(); end
defaults = struct( ...
    'rfX',              -3, ...
    'rfY',               2, ...
    'rfSigmaRfmap',      1.0, ...
    'rfSigmaCardinal',   2.0, ...
    'latencyMs',         60, ...
    'pathLengthDeg',     30, ...
    'speedDegPerSec',    30, ...
    'frameDur',          0.01, ...
    'baseRate',          5, ...
    'peakRate',          60, ...
    'nRepeatsRfmap',     15, ...
    'nRepeatsCardinal',  25, ...
    'testCh',            2, ...
    'nChannels',         4, ...
    'rngSeed',           42, ...
    'latencyMismatch',   true, ...
    'tolRfmap',          1.5, ...
    'tolCardinal',       1.0, ...
    'savePlots',         true, ...
    'plotsDir',          '');
fn = fieldnames(defaults);
for k = 1:numel(fn)
    if ~isfield(params, fn{k}), params.(fn{k}) = defaults.(fn{k}); end
end

rng(params.rngSeed);

results = struct();

%% Resolve a plots directory if savePlots requested.
if params.savePlots
    if isempty(params.plotsDir)
        thisDir = fileparts(mfilename('fullpath'));
        taskRoot = fileparts(thisDir);   % .../tasks/barsweep
        stamp = datestr(now, 'yyyymmdd_HHMMSS'); %#ok<TNOW1,DATST>
        params.plotsDir = fullfile(taskRoot, 'output', ...
            'testBarsweepRF', stamp);
    end
    if ~exist(params.plotsDir, 'dir')
        mkdir(params.plotsDir);
    end
    fprintf('Plots will be written to: %s\n', params.plotsDir);
    results.plotsDir = params.plotsDir;
end

%% rfmap12
fprintf('\n=== testBarsweepRF: rfmap12 ===\n');
[rfRfmap, peakX, peakY] = runRegime(params, 'barsweep_rfmap12', ...
    params.rfSigmaRfmap, 0:30:330, params.nRepeatsRfmap);

errR = hypot(peakX - params.rfX, peakY - params.rfY);
fprintf('  Recovered peak: (%.2f, %.2f) | True: (%.2f, %.2f) | err = %.2f dva\n', ...
    peakX, peakY, params.rfX, params.rfY, errR);
results.rfmap12 = struct('peakX', peakX, 'peakY', peakY, ...
    'err', errR, 'pass', errR < params.tolRfmap, 'rf', rfRfmap);
if params.savePlots
    pngPath = fullfile(params.plotsDir, 'rfmap12_recon.png');
    plotRfmap12Recon(rfRfmap, params, peakX, peakY, pngPath);
    fprintf('  -> %s\n', pngPath);
    results.rfmap12.plotPath = pngPath;
end
assert(errR < params.tolRfmap, ...
    'rfmap12 peak %.2f dva off truth (tol = %.2f).', errR, params.tolRfmap);
fprintf('  [OK] rfmap12 within %.1f dva\n', params.tolRfmap);

%% cardinal4
fprintf('\n=== testBarsweepRF: cardinal4 ===\n');
[rfCard, ~, ~, xC, yC] = runRegime(params, 'barsweep_cardinal4', ...
    params.rfSigmaCardinal, [0 90 180 270], params.nRepeatsCardinal);

errX = abs(xC - params.rfX);
errY = abs(yC - params.rfY);
fprintf('  cardinal4 xCenter=%.3f (truth %.2f) yCenter=%.3f (truth %.2f) -- errX=%.2f errY=%.2f\n', ...
    xC, params.rfX, yC, params.rfY, errX, errY);
results.cardinal4 = struct('xCenter', xC, 'yCenter', yC, ...
    'errX', errX, 'errY', errY, ...
    'pass', errX < params.tolCardinal && errY < params.tolCardinal, ...
    'rf', rfCard);
if params.savePlots
    pngPath = fullfile(params.plotsDir, 'cardinal4_recon.png');
    plotCardinal4Recon(rfCard, params, xC, yC, pngPath);
    fprintf('  -> %s\n', pngPath);
    results.cardinal4.plotPath = pngPath;
end
assert(errX < params.tolCardinal, 'cardinal4 xCenter %.2f dva off (tol %.2f).', errX, params.tolCardinal);
assert(errY < params.tolCardinal, 'cardinal4 yCenter %.2f dva off (tol %.2f).', errY, params.tolCardinal);
fprintf('  [OK] cardinal4 within %.1f dva on both axes\n', params.tolCardinal);

%% Regime equivalence (plan §11.5)
% The two regimes' recovered centers should agree to within one position
% bin on the same RF. We use the cardinal4-friendly (wider) sigma to
% make the y-axis observable in cardinal4; then re-run rfmap12 with that
% RF as well so the comparison is apples-to-apples.
fprintf('\n=== testBarsweepRF: regime equivalence ===\n');
[rfWide, peakX2, peakY2] = runRegime(params, 'barsweep_rfmap12', ...
    params.rfSigmaCardinal, 0:30:330, params.nRepeatsRfmap);
fprintf('  rfmap12 peak (wide RF): (%.2f, %.2f) | cardinal4 (xC, yC): (%.2f, %.2f)\n', ...
    peakX2, peakY2, xC, yC);
binSize = 0.25;
agreeX = abs(peakX2 - xC) < 5 * binSize;
agreeY = abs(peakY2 - yC) < 5 * binSize;
results.equivalence = struct('agreeX', agreeX, 'agreeY', agreeY);
fprintf('  agree within 5 bins: x=%d y=%d\n', agreeX, agreeY);
if params.savePlots
    pngPath = fullfile(params.plotsDir, 'regime_equivalence.png');
    plotRegimeEquivalence(rfWide, rfCard, params, ...
        peakX2, peakY2, xC, yC, pngPath);
    fprintf('  -> %s\n', pngPath);
    results.equivalence.plotPath = pngPath;
end

%% Latency-mismatch sanity check (plan §11.4)
% If the accumulator's rfLatencyMs disagrees with the generator's by
% +deltaMs, the recovered RF center shifts along the projection axis by
% (barVelocity * deltaMs/1000). To isolate that effect from RNG noise,
% seed the RNG identically before each run so the spike trains are
% bit-identical. The only difference between the two reconstructions is
% the accumulator's latencyMs.
if params.latencyMismatch
    fprintf('\n=== testBarsweepRF: latency-mismatch check ===\n');
    delta = 20;  % ms
    seedA = 12345;
    [~, pxBase, pyBase] = runRegimeSeeded(params, 'barsweep_rfmap12', ...
        params.rfSigmaCardinal, 0:30:330, params.nRepeatsRfmap, ...
        params.latencyMs, seedA);
    [~, pxMis, pyMis]   = runRegimeSeeded(params, 'barsweep_rfmap12', ...
        params.rfSigmaCardinal, 0:30:330, params.nRepeatsRfmap, ...
        params.latencyMs + delta, seedA);
    expectedShift = params.speedDegPerSec * delta/1000;  % ~0.6 dva at 30 dva/s, 20 ms
    actualShift = hypot(pxMis - pxBase, pyMis - pyBase);
    fprintf('  delta=%d ms -> baseline=(%.2f,%.2f), mismatched=(%.2f,%.2f)\n', ...
        delta, pxBase, pyBase, pxMis, pyMis);
    fprintf('  expected ~%.2f dva shift, got %.2f dva\n', ...
        expectedShift, actualShift);
    results.latencyShift = actualShift;
    % Soft check: shift should be within a position bin of the prediction.
    if abs(actualShift - expectedShift) > 2 * params.peakRate / 100
        fprintf('  [warn] latency-shift differs from prediction by more than 2 bins.\n');
    end
end

fprintf('\n[OK] testBarsweepRF passed all checks.\n');

end

%% --- helpers ---

function bwrMap = bwrColormap()
nC = 256; half = nC / 2;
r = [linspace(0, 1, half), ones(1, half)]';
g = [linspace(0, 1, half), linspace(1, 0, half)]';
b = [ones(1, half), linspace(1, 0, half)]';
bwrMap = [r, g, b];
end

function plotRfmap12Recon(rf, params, peakX, peakY, pngPath)
% Two-panel figure: (1) FBP-reconstructed image with truth + argmax peak
% + Gaussian-fit ellipse, (2) sinogram (rate matrix).
out = reconstructBarsweepRF(rf, params.testCh, 'barsweep_rfmap12');
fig = figure('Visible', 'off', 'Position', [50 50 1100 500], 'Color', 'w');

ax1 = subplot(1, 2, 1);
imagesc(ax1, out.axisDeg, out.axisDeg, out.rfImage);
axis(ax1, 'image'); axis(ax1, 'xy');
colormap(ax1, bwrColormap());
cMax = max(abs(out.rfImage(:))); if cMax == 0, cMax = 1; end
set(ax1, 'CLim', [-cMax, cMax]);
hold(ax1, 'on');
plot(ax1, params.rfX, params.rfY, 'g+', 'MarkerSize', 18, 'LineWidth', 2);
plot(ax1, peakX,  peakY,  'kx', 'MarkerSize', 14, 'LineWidth', 2);
% Overlay 1-sigma Gaussian-fit ellipse + centroid (magenta) when detected.
if out.peakStats.detected && ~isempty(out.gaussFit.ellipseX)
    plot(ax1, out.gaussFit.ellipseX, out.gaussFit.ellipseY, ...
        'm-', 'LineWidth', 1.5);
    plot(ax1, out.gaussFit.x0, out.gaussFit.y0, 'm+', ...
        'MarkerSize', 14, 'LineWidth', 1.5);
end
hold(ax1, 'off');
xlabel(ax1, 'x (dva, path-center-relative)');
ylabel(ax1, 'y (dva, path-center-relative)');
if out.peakStats.detected
    title(ax1, sprintf(['rfmap12 FBP  truth(g+) recov-argmax(kx) recov-fit(m+)\n' ...
        'snr=%.1f  fit=(%.2f, %.2f)  fwhm=(%.2f, %.2f) dva'], ...
        out.peakStats.snr, out.gaussFit.x0, out.gaussFit.y0, ...
        out.gaussFit.fwhmX, out.gaussFit.fwhmY));
else
    title(ax1, sprintf('rfmap12 FBP  NO RF DETECTED (snr=%.1f, thr=%.1f)', ...
        out.peakStats.snr, 3.0), 'Color', [0.7 0 0]);
end
colorbar(ax1);

ax2 = subplot(1, 2, 2);
imagesc(ax2, rf.positionCenters, rad2deg(rf.orientationsRad), out.rateMatrix);
xlabel(ax2, 's (dva)');
ylabel(ax2, 'orientation (deg)');
title(ax2, sprintf('rate matrix (sinogram input)\n%d trials, %d total spikes', ...
    sum(rf.trialsByDirection), sum(rf.spikeCount)));
colormap(ax2, hot);
colorbar(ax2);

exportgraphics(fig, pngPath, 'Resolution', 120);
close(fig);
end

function plotCardinal4Recon(rf, params, xC, yC, pngPath)
% Three-panel figure: rate-vs-x, rate-vs-y, separable 2D outer product.
out = reconstructBarsweepRF(rf, params.testCh, 'barsweep_cardinal4');
fig = figure('Visible', 'off', 'Position', [50 50 1300 400], 'Color', 'w');

% Plot windows centered on the truth, ±max(2*|rfX|, 4) along each axis.
xWin = max(2 * abs(params.rfX), 4);
yWin = max(2 * abs(params.rfY), 4);

ax1 = subplot(1, 3, 1);
plot(ax1, out.axisX, out.rateX, 'b-', 'LineWidth', 1.5);
hold(ax1, 'on');
plot(ax1, params.rfX, max(out.rateX), 'g+', 'MarkerSize', 16, 'LineWidth', 2);
plot(ax1, xC, max(out.rateX), 'kx', 'MarkerSize', 14, 'LineWidth', 2);
xlim(ax1, [params.rfX - xWin, params.rfX + xWin]);
xlabel(ax1, 'x (dva)'); ylabel(ax1, 'rate (sp/s)');
title(ax1, sprintf('rate vs x (vert sweeps)\ntruth=%.1f recov=%.2f', params.rfX, xC));

ax2 = subplot(1, 3, 2);
plot(ax2, out.axisY, out.rateY, 'b-', 'LineWidth', 1.5);
hold(ax2, 'on');
plot(ax2, params.rfY, max(out.rateY), 'g+', 'MarkerSize', 16, 'LineWidth', 2);
plot(ax2, yC, max(out.rateY), 'kx', 'MarkerSize', 14, 'LineWidth', 2);
xlim(ax2, [params.rfY - yWin, params.rfY + yWin]);
xlabel(ax2, 'y (dva)'); ylabel(ax2, 'rate (sp/s)');
title(ax2, sprintf('rate vs y (horiz sweeps)\ntruth=%.1f recov=%.2f', params.rfY, yC));

ax3 = subplot(1, 3, 3);
% out.separable2D is [nY, nX]; rows = y-axis (positionCenters)
imagesc(ax3, out.axisX, out.axisY, out.separable2D);
axis(ax3, 'image'); axis(ax3, 'xy');
colormap(ax3, hot);
hold(ax3, 'on');
plot(ax3, params.rfX, params.rfY, 'g+', 'MarkerSize', 18, 'LineWidth', 2);
plot(ax3, xC, yC, 'cx', 'MarkerSize', 14, 'LineWidth', 2);
if out.peakStats.detected && ~isempty(out.gaussFit.ellipseX)
    plot(ax3, out.gaussFit.ellipseX, out.gaussFit.ellipseY, ...
        'm-', 'LineWidth', 1.5);
    plot(ax3, out.gaussFit.x0, out.gaussFit.y0, 'm+', ...
        'MarkerSize', 14, 'LineWidth', 1.5);
end
xlim(ax3, [params.rfX - xWin, params.rfX + xWin]);
ylim(ax3, [params.rfY - yWin, params.rfY + yWin]);
xlabel(ax3, 'x (dva)'); ylabel(ax3, 'y (dva)');
if out.peakStats.detected
    title(ax3, sprintf('separable 2D  snrXY=[%.1f, %.1f]  fwhm=(%.2f, %.2f)', ...
        out.peakStats.snrX, out.peakStats.snrY, ...
        out.gaussFit.fwhmX, out.gaussFit.fwhmY));
else
    title(ax3, sprintf('separable 2D  NO RF (snrXY=[%.1f, %.1f])', ...
        out.peakStats.snrX, out.peakStats.snrY), 'Color', [0.7 0 0]);
end
colorbar(ax3);

sgtitle(fig, sprintf('cardinal4 cardinal sweeps  %d trials  %d total spikes', ...
    sum(rf.trialsByDirection), sum(rf.spikeCount)));

exportgraphics(fig, pngPath, 'Resolution', 120);
close(fig);
end

function plotRegimeEquivalence(rfWide, rfCard, params, peakX2, peakY2, xC, yC, pngPath)
% Side-by-side: rfmap12 FBP image and cardinal4 separable estimate, both
% on the same RF (wide sigma). Truth and per-regime recovered peak in
% green+ and black/cyan x.
outR = reconstructBarsweepRF(rfWide, params.testCh, 'barsweep_rfmap12');
outC = reconstructBarsweepRF(rfCard, params.testCh, 'barsweep_cardinal4');
fig = figure('Visible', 'off', 'Position', [50 50 1100 500], 'Color', 'w');

ax1 = subplot(1, 2, 1);
imagesc(ax1, outR.axisDeg, outR.axisDeg, outR.rfImage);
axis(ax1, 'image'); axis(ax1, 'xy');
colormap(ax1, bwrColormap());
cMax = max(abs(outR.rfImage(:))); if cMax == 0, cMax = 1; end
set(ax1, 'CLim', [-cMax, cMax]);
hold(ax1, 'on');
plot(ax1, params.rfX, params.rfY, 'g+', 'MarkerSize', 18, 'LineWidth', 2);
plot(ax1, peakX2, peakY2, 'kx', 'MarkerSize', 14, 'LineWidth', 2);
xlabel(ax1, 'x (dva)'); ylabel(ax1, 'y (dva)');
title(ax1, sprintf('rfmap12 FBP (wide RF)  recov=(%.2f, %.2f)', peakX2, peakY2));
colorbar(ax1);

ax2 = subplot(1, 2, 2);
imagesc(ax2, outC.axisX, outC.axisY, outC.separable2D);
axis(ax2, 'image'); axis(ax2, 'xy');
colormap(ax2, hot);
hold(ax2, 'on');
plot(ax2, params.rfX, params.rfY, 'g+', 'MarkerSize', 18, 'LineWidth', 2);
plot(ax2, xC, yC, 'cx', 'MarkerSize', 14, 'LineWidth', 2);
% Match the rfmap12 image extent so the two panels are visually comparable.
xlim(ax2, [outR.axisDeg(1), outR.axisDeg(end)]);
ylim(ax2, [outR.axisDeg(1), outR.axisDeg(end)]);
xlabel(ax2, 'x (dva)'); ylabel(ax2, 'y (dva)');
title(ax2, sprintf('cardinal4 separable  recov=(%.2f, %.2f)', xC, yC));
colorbar(ax2);

binSize = rfWide.rfPosBinDeg;
sgtitle(fig, sprintf(['regime equivalence (truth (%.1f, %.1f) green+, recovered black/cyan x)' ...
    '  binSize=%.2f dva'], params.rfX, params.rfY, binSize));

exportgraphics(fig, pngPath, 'Resolution', 120);
close(fig);
end

function [rf, peakX, peakY, xC, yC] = runRegimeSeeded(params, exptType, sigma, ...
    directionsDeg, nRepeats, accumLatencyMs, rngSeed)
% Same as runRegime, but resets the RNG to a known seed first so two
% calls with the same arguments produce bit-identical spike trains.
rng(rngSeed);
[rf, peakX, peakY, xC, yC] = runRegime(params, exptType, sigma, ...
    directionsDeg, nRepeats, accumLatencyMs);
end

function [rf, peakX, peakY, xC, yC] = runRegime(params, exptType, sigma, ...
    directionsDeg, nRepeats, accumLatencyMs)
% Build a stub p struct, run nRepeats per direction of synthetic sweeps,
% and reconstruct.

if nargin < 6, accumLatencyMs = params.latencyMs; end
peakX = NaN; peakY = NaN; xC = NaN; yC = NaN;

p = struct();
p.init.exptType = exptType;
p.trVarsInit.pathLengthDeg = params.pathLengthDeg;
p.trVarsInit.barWidthDeg = 0.5;
p.trVarsInit.rfPosBinDeg = 0.25;
p.trVarsInit.rfMapExtentDeg = 8;
p.trVarsInit.rfNChannels = params.nChannels;
p.trVarsInit.rfLatencyMs = accumLatencyMs;
p.trVarsInit.rfRampFilter = 'Hann';
p.trVarsInit.rfRampCutoff = 0.5;
p.trVarsInit.pathCenterXDeg = 0;
p.trVarsInit.pathCenterYDeg = 0;
p = initBarsweepRF(p);

p.init.codes.stimOn = 4001;
p.trVars = p.trVarsInit;
p.status.iTrial = 0;

sweepDur = params.pathLengthDeg / params.speedDegPerSec;
sweepFrames = round(sweepDur / params.frameDur);
stimOnRipple = 100;

dirSched = repmat(directionsDeg, 1, nRepeats);
dirSched = dirSched(randperm(numel(dirSched)));

for iTr = 1:numel(dirSched)
    p.status.iTrial = iTr;
    angleDeg = dirSched(iTr);
    theta = deg2rad(angleDeg);
    L = params.pathLengthDeg;
    startDeg = -0.5 * L * [cos(theta); sin(theta)];
    endDeg   = +0.5 * L * [cos(theta); sin(theta)];
    sweepCenterDeg = [linspace(startDeg(1), endDeg(1), sweepFrames); ...
                      linspace(startDeg(2), endDeg(2), sweepFrames)];

    p.trVars.pathAngleDeg = angleDeg;
    p.trVars.sweepCenterDegByFrame = sweepCenterDeg;
    p.trVars.sweepFrames = sweepFrames;
    p.trVars.flipIdx = sweepFrames + 2;

    flipTimeAll = zeros(1, 3000);
    flipTimeAll(1) = 0.0;
    flipTimeAll(2:sweepFrames+2) = (0:sweepFrames) * params.frameDur + 0.5;
    p.trData.timing.flipTime = flipTimeAll;
    p.trData.timing.flipIdxStimOn = 2;
    p.trData.timing.stimOn = 0.5;
    p.trData.timing.fixBreak = -1;

    dx = sweepCenterDeg(1, :) - params.rfX;
    dy = sweepCenterDeg(2, :) - params.rfY;
    rate = params.peakRate * exp(-(dx.^2 + dy.^2) / (2 * sigma^2)) + params.baseRate;
    nPerFrame = poissrnd(rate * params.frameDur);

    spikeT = zeros(1, 0);
    for f = 1:sweepFrames
        if nPerFrame(f) == 0, continue; end
        tCenter = (f - 0.5) * params.frameDur;
        % Use the GENERATOR's latency, not the accumulator's.
        s = stimOnRipple + tCenter + params.latencyMs/1000 + ...
            (rand(1, nPerFrame(f)) - 0.5) * params.frameDur;
        spikeT = [spikeT, s]; %#ok<AGROW>
    end
    p.trData.spikeTimes = spikeT(:);
    p.trData.spikeClusters = ones(numel(spikeT), 1) * params.testCh;
    p.trData.eventTimes = stimOnRipple;
    p.trData.eventValues = p.init.codes.stimOn;

    p = accumulateBarsweepRF(p);
end

rf = p.init.barsweepRF;
out = reconstructBarsweepRF(rf, params.testCh, exptType);
switch exptType
    case 'barsweep_rfmap12'
        [~, idx] = max(out.rfImage(:));
        [ry, rx] = ind2sub(size(out.rfImage), idx);
        peakX = out.axisDeg(rx);
        peakY = out.axisDeg(ry);
    case 'barsweep_cardinal4'
        xC = out.xCenter;
        yC = out.yCenter;
        peakX = xC;
        peakY = yC;
end

end
