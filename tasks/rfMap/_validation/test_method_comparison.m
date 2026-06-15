function results = test_method_comparison(varargin)
% test_method_comparison  Compare RF estimation methods by convergence rate.
%
%   results = test_method_comparison()
%   results = test_method_comparison('nPopulations', 3, ...)
%
%   Simulates four RF estimation methods against shared LGN populations and
%   evaluates accuracy at trial-count checkpoints:
%     1. denseAchromatic  — STA centroid
%     2. denseChromatic   — STA centroid (DKL L2 norm)
%     3. barsweep cardinal4 — parabolic peak (current method)
%     4. barsweep cardinal4 — 1-D DOG fit  (collaborator's method)
%
%   Name-Value options:
%     nPopulations  (5)   — independent population seeds
%     maxTrials     (600) — maximum trials per method
%     checkpoints   ([])  — trial counts to evaluate (auto if empty)
%     popSeeds      ([])  — RNG seeds (auto if empty)

sfDir = fullfile(fileparts(mfilename('fullpath')), '..', 'supportFunctions');
addpath(sfDir);

% ------------------------------------------------------------------
%  Parse options
% ------------------------------------------------------------------
ip = inputParser;
ip.addParameter('nPopulations', 5);
ip.addParameter('maxTrials', 600);
ip.addParameter('checkpoints', []);
ip.addParameter('popSeeds', []);
ip.parse(varargin{:});
o = ip.Results;

nPop = o.nPopulations;
if isempty(o.popSeeds),    o.popSeeds = 41 + (1:nPop);          end
if isempty(o.checkpoints), o.checkpoints = unique([25:25:100, ...
        150:50:o.maxTrials]);                                     end
chk   = o.checkpoints(:)';
nChk  = numel(chk);
maxTr = max(chk);

% ------------------------------------------------------------------
%  Shared configuration
% ------------------------------------------------------------------
nNeurons  = 12;
nChannels = 64;

gridCenter   = [-3.5, 0];
nY = 15;  nX = 13;
checkSizeDeg = 2.0;
frameDurS    = 0.03;           % 3-frame hold at 100 Hz
nLags        = 8;
framesPerTr  = 50;            % ~1.5 s per trial

daCfg = struct('nY',nY, 'nX',nX, 'checkSizeDeg',checkSizeDeg, ...
    'frameDurS',frameDurS, 'nLags',nLags, 'framesPerTrial',framesPerTr, ...
    'gridCenterDeg',gridCenter, 'threshFrac',0.25);

dcCfg = daCfg;
dcCfg.dklAxes      = [1 2 3];
dcCfg.dklContrasts = [0.2 0.2 0.2];

bsCfg = struct('speedDegPerSec',35, 'pathLengthDeg',40, ...
    'barWidthDeg',0.4, 'frameDurS',0.01, 'rfPosBinDeg',0.25, ...
    'rfLatencyMs',40, 'pathCenterDeg',gridCenter, ...
    'directions',[0 90 180 270]);

nMethod     = 4;
methodNames = {'denseAchromatic','denseChromatic', ...
               'barsweepParabolic','barsweepDOG'};
timePerTr   = [framesPerTr*frameDurS, framesPerTr*frameDurS, ...
               bsCfg.pathLengthDeg/bsCfg.speedDegPerSec, ...
               bsCfg.pathLengthDeg/bsCfg.speedDegPerSec];

% ------------------------------------------------------------------
%  Pre-allocate
% ------------------------------------------------------------------
errors = nan(nPop, nMethod, nChk, nNeurons);
gtAll  = cell(nPop, 1);

% ------------------------------------------------------------------
%  Main loop over populations
% ------------------------------------------------------------------
tWall = tic;
for p = 1:nPop
    seed = o.popSeeds(p);
    fprintf('\n=== Population %d/%d  (seed %d) ===\n', p, nPop, seed);

    tmpFile = fullfile(tempdir, sprintf('mcmp_pop_%d.mat', seed));
    pop = simGeneratePopulation( ...
        'nNeurons', nNeurons, 'nChannels', nChannels, ...
        'hemifield', 'left', 'eccentricityRange', [1 6], ...
        'elevationRange', [-4 4], 'seed', seed, ...
        'baseRate', 2, 'peakRate', 20, 'saveFile', tmpFile);

    gt   = reshape([pop.neurons.centerDeg], 2, [])';
    rfCh = [pop.neurons.channelIdx];
    gtAll{p} = gt;

    fprintf('  [1/4] denseAchromatic STA ...\n');
    errors(p,1,:,:) = runDenseAchromatic(pop, daCfg, chk, gt, rfCh);

    fprintf('  [2/4] denseChromatic STA ...\n');
    errors(p,2,:,:) = runDenseChromatic(pop, dcCfg, chk, gt, rfCh);

    fprintf('  [3-4/4] barsweep (parabolic + DOG) ...\n');
    [eP, eD] = runBarsweep(pop, bsCfg, chk, gt, rfCh);
    errors(p,3,:,:) = eP;
    errors(p,4,:,:) = eD;

    if exist(tmpFile, 'file'), delete(tmpFile); end
end
fprintf('\nTotal wall time: %.1f s\n', toc(tWall));

% ------------------------------------------------------------------
%  Assemble & visualise
% ------------------------------------------------------------------
results = struct('errors', errors, 'checkpoints', chk, ...
    'methodNames', {methodNames}, 'timePerTrial', timePerTr, ...
    'nPopulations', nPop, 'groundTruth', {gtAll}, ...
    'popSeeds', o.popSeeds);

plotConvergence(results);
printSummary(results);

end


% =====================================================================
%  METHOD RUNNERS
% =====================================================================

function errs = runDenseAchromatic(pop, cfg, chk, gt, rfCh)

nCh = pop.nChannels;  nN = numel(pop.neurons);
maxTr = max(chk);     nF = cfg.framesPerTrial;
totFrames = maxTr * nF;

kernels = buildOfflineKernels(pop, cfg, false);

rsM   = RandStream('mt19937ar', 'Seed', uint32(2001));
movie = uint8(rand(rsM, cfg.nY, cfg.nX, totFrames) > 0.5);

staA = cell(nCh,1);
for ch = 1:nCh, staA{ch} = zeros(cfg.nY, cfg.nX, cfg.nLags); end
staN = zeros(nCh, cfg.nLags, 'uint32');

errs = nan(numel(chk), nN);
ci = 1;

for tr = 1:maxTr
    f0 = (tr-1)*nF + 1;
    S  = double(movie(:,:, f0:f0+nF-1)) - 0.5;
    sFlat = reshape(S, [], nF);

    spkPC = cell(nCh,1);
    for k = 1:nN
        n = pop.neurons(k);  ch = n.channelIdx;
        proj = kernels(k).sk(:)' * sFlat;
        g = filter(kernels(k).tk, 1, proj(:)) / kernels(k).gStd;
        rs = RandStream('mt19937ar', 'Seed', ...
            uint32(mod(2001 + ch + 10000*tr, 2^32-1)));
        spkPC{ch} = simLNPSpikes(g, n.baseRate, n.peakRate, cfg.frameDurS, rs);
    end
    for i = 1:numel(pop.noiseChannels)
        ch = pop.noiseChannels(i);
        if ch > nCh, continue; end
        rs = RandStream('mt19937ar', 'Seed', ...
            uint32(mod(2001 + ch + 50000 + 10000*tr, 2^32-1)));
        spkPC{ch} = simLNPSpikes(zeros(nF,1), pop.noiseRates(i), 0, ...
            cfg.frameDurS, rs);
    end

    [staA, staN] = updateSTA_denseAchromatic(staA, staN, spkPC, 0, ...
        cfg.frameDurS, movie, f0, nF, cfg.nLags);

    if ci <= numel(chk) && tr == chk(ci)
        c = rfCentersFromSTA(staA, staN, cfg, false);
        for k = 1:nN
            ch = rfCh(k);
            if all(isfinite(c(ch,:)))
                errs(ci,k) = sqrt(sum((c(ch,:) - gt(k,:)).^2));
            end
        end
        fprintf('    %4d trials: median %.2f dva\n', tr, ...
            median(errs(ci,:), 'omitnan'));
        ci = ci + 1;
    end
end

end


function errs = runDenseChromatic(pop, cfg, chk, gt, rfCh)

nCh = pop.nChannels;  nN = numel(pop.neurons);
maxTr = max(chk);     nF = cfg.framesPerTrial;
totFrames = maxTr * nF;

kernels = buildOfflineKernels(pop, cfg, true);

rsM  = RandStream('mt19937ar', 'Seed', uint32(3001));
signs = single(2*(rand(rsM, cfg.nY, cfg.nX, 3, totFrames) > 0.5) - 1);
cVec  = reshape(single(cfg.dklContrasts(:)), 1, 1, 3, 1);
dklD  = signs .* cVec;
clear signs;

staA = cell(nCh,1);
for ch = 1:nCh
    staA{ch} = zeros(cfg.nY, cfg.nX, 3, cfg.nLags);
end
staN = zeros(nCh, cfg.nLags, 'uint32');

errs = nan(numel(chk), nN);
ci = 1;

for tr = 1:maxTr
    f0 = (tr-1)*nF + 1;
    D  = dklD(:,:,:, f0:f0+nF-1);

    spkPC = cell(nCh,1);
    for k = 1:nN
        n = pop.neurons(k);  ch = n.channelIdx;
        wk = kernels(k).wDKL;
        Dw = squeeze(wk(1)*D(:,:,1,:) + wk(2)*D(:,:,2,:) + wk(3)*D(:,:,3,:));
        sFlat = reshape(double(Dw), [], nF);
        proj = kernels(k).sk(:)' * sFlat;
        g = filter(kernels(k).tk, 1, proj(:)) / kernels(k).gStd;
        rs = RandStream('mt19937ar', 'Seed', ...
            uint32(mod(3001 + ch + 10000*tr, 2^32-1)));
        spkPC{ch} = simLNPSpikes(g, n.baseRate, n.peakRate, cfg.frameDurS, rs);
    end
    for i = 1:numel(pop.noiseChannels)
        ch = pop.noiseChannels(i);
        if ch > nCh, continue; end
        rs = RandStream('mt19937ar', 'Seed', ...
            uint32(mod(3001 + ch + 50000 + 10000*tr, 2^32-1)));
        spkPC{ch} = simLNPSpikes(zeros(nF,1), pop.noiseRates(i), 0, ...
            cfg.frameDurS, rs);
    end

    [staA, staN] = updateSTA_denseChromatic(staA, staN, spkPC, 0, ...
        cfg.frameDurS, dklD, f0, nF, cfg.nLags);

    if ci <= numel(chk) && tr == chk(ci)
        c = rfCentersFromSTA(staA, staN, cfg, true);
        for k = 1:nN
            ch = rfCh(k);
            if all(isfinite(c(ch,:)))
                errs(ci,k) = sqrt(sum((c(ch,:) - gt(k,:)).^2));
            end
        end
        fprintf('    %4d trials: median %.2f dva\n', tr, ...
            median(errs(ci,:), 'omitnan'));
        ci = ci + 1;
    end
end

end


function [errsP, errsD] = runBarsweep(pop, cfg, chk, gt, rfCh)

nCh  = pop.nChannels;
nN   = numel(pop.neurons);
maxTr = max(chk);
dirs  = cfg.directions;
nDir  = numel(dirs);

sweepDur = cfg.pathLengthDeg / cfg.speedDegPerSec;
halfPath = cfg.pathLengthDeg / 2;
edges    = (-halfPath : cfg.rfPosBinDeg : halfPath);
nBins    = numel(edges) - 1;
binCtrs  = (edges(1:end-1) + edges(2:end)) / 2;

bank   = struct('nChannels', nCh);
params = struct('speedDegPerSec', cfg.speedDegPerSec, ...
    'pathLengthDeg', cfg.pathLengthDeg, 'barWidthDeg', cfg.barWidthDeg, ...
    'frameDurS', cfg.frameDurS, 'pathCenterDeg', cfg.pathCenterDeg);

spikeH = zeros(2, nBins, nCh);   % orientation index: 1=x(0deg), 2=y(90deg)
dwellT = zeros(2, nBins);

errsP = nan(numel(chk), nN);
errsD = nan(numel(chk), nN);
ci = 1;

for tr = 1:maxTr
    dirIdx   = mod(tr-1, nDir) + 1;
    angleDeg = dirs(dirIdx);
    oriDeg   = mod(angleDeg, 180);
    oIdx     = round(oriDeg / 90) + 1;           % 1 for 0deg, 2 for 90deg

    thetaR   = angleDeg * pi / 180;
    dirVec   = [cos(thetaR), sin(thetaR)];
    oriAxis  = [cos(oriDeg*pi/180), sin(oriDeg*pi/180)];
    dotDA    = dirVec * oriAxis';
    startPos = cfg.pathCenterDeg - halfPath * dirVec;

    spkPC = simBarsweepTrial(pop, bank, angleDeg, params, tr);

    % --- Dwell time (vectorised) ---
    nFrames = round(sweepDur / cfg.frameDurS);
    fracs   = (0:nFrames-1)' / max(nFrames-1, 1);
    posAlong = (fracs - 0.5) * cfg.pathLengthDeg * dotDA;
    bis = discretize(posAlong, edges);
    vb  = ~isnan(bis);
    if any(vb)
        dwellT(oIdx,:) = dwellT(oIdx,:) + ...
            accumarray(bis(vb), cfg.frameDurS, [nBins 1])';
    end

    % --- Spike binning ---
    for ch = 1:nCh
        st = spkPC{ch};
        if isempty(st), continue; end
        tEff = st(:) - cfg.rfLatencyMs / 1000;
        keep = tEff >= 0 & tEff < sweepDur;
        tEff = tEff(keep);
        if isempty(tEff), continue; end

        frac = tEff / sweepDur;
        posA = (frac - 0.5) * cfg.pathLengthDeg * dotDA;
        bi   = discretize(posA, edges);
        ok   = ~isnan(bi);
        if any(ok)
            spikeH(oIdx,:,ch) = spikeH(oIdx,:,ch) + ...
                accumarray(bi(ok), 1, [nBins 1])';
        end
    end

    % --- Checkpoint evaluation ---
    if ci <= numel(chk) && tr == chk(ci)
        for k = 1:nN
            ch = rfCh(k);
            cP = [NaN NaN];
            cD = [NaN NaN];
            for o = 1:2
                r = squeeze(spikeH(o,:,ch));
                d = squeeze(dwellT(o,:));
                vb2 = d > 0;
                if sum(vb2) < 6, continue; end

                rate = zeros(size(r));
                rate(vb2) = r(vb2) ./ d(vb2);
                xv = binCtrs(vb2);
                yv = rate(vb2);

                % Detect ON vs OFF (invert if strongest feature is a dip)
                nFlank = max(1, round(numel(yv)*0.1));
                bl = median([yv(1:nFlank), yv(end-nFlank+1:end)]);
                if (bl - min(yv)) > (max(yv) - bl)
                    yv = 2*bl - yv;
                end

                cP(o) = cfg.pathCenterDeg(o) + parabolicPeak1D(xv, yv);
                [dogX, ~, ~] = fitDOG1D(xv, yv);
                cD(o) = cfg.pathCenterDeg(o) + dogX;
            end

            if all(isfinite(cP))
                errsP(ci,k) = sqrt(sum((cP - gt(k,:)).^2));
            end
            if all(isfinite(cD))
                errsD(ci,k) = sqrt(sum((cD - gt(k,:)).^2));
            end
        end
        fprintf('    %4d trials: parabolic %.2f, DOG %.2f dva\n', ...
            chk(ci), median(errsP(ci,:),'omitnan'), ...
            median(errsD(ci,:),'omitnan'));
        ci = ci + 1;
    end
end

end


% =====================================================================
%  OFFLINE KERNEL BUILDER
% =====================================================================

function kernels = buildOfflineKernels(pop, cfg, isChrom)

nN = numel(pop.neurons);
noiseFrameDurMs = cfg.frameDurS * 1000;

for k = nN:-1:1
    n = pop.neurons(k);

    cGrid_x =  (n.centerDeg(1) - cfg.gridCenterDeg(1)) + cfg.nX*cfg.checkSizeDeg/2;
    cGrid_y = -(n.centerDeg(2) - cfg.gridCenterDeg(2)) + cfg.nY*cfg.checkSizeDeg/2;

    excPk = max(n.excPeakMs, noiseFrameDurMs * 0.8);
    inhPk = excPk * (n.inhPeakMs / max(n.excPeakMs, 1));

    rfp = struct('nChecksX',cfg.nX, 'nChecksY',cfg.nY, ...
        'checkSizeDeg',cfg.checkSizeDeg, ...
        'rfCenterDeg',[cGrid_x, cGrid_y], ...
        'rfSigmaCenterDeg',n.sigmaCenterDeg, ...
        'rfSigmaSurrDeg',n.sigmaSurrDeg, ...
        'rfSurrWeight',n.surrWeight, ...
        'rfExcPeakMs',excPk, 'rfInhPeakMs',inhPk, ...
        'rfInhWeight',n.inhWeight, ...
        'nSTALags',cfg.nLags, 'noiseFrameDurMs',noiseFrameDurMs);

    [~, sk, tk] = buildGroundTruthRF(rfp);
    tk = n.polarity * tk;

    spatE = sum(sk(:).^2);
    tmpE  = sum(tk(:).^2);

    if isChrom
        wDKL = n.dklWeights;
        cVec = zeros(1,3);
        cVec(cfg.dklAxes) = cfg.dklContrasts;
        wDKL(cVec == 0) = 0;
        wn = norm(wDKL); if wn > 0, wDKL = wDKL / wn; end
        stimVar = sum((wDKL .* cVec).^2);
        if stimVar <= 0, stimVar = 0.25; end
    else
        stimVar = 0.25;
        wDKL = [];
    end

    gStd = sqrt(spatE * tmpE * stimVar);
    if ~(gStd > 0), gStd = 1; end

    kernels(k) = struct('sk',sk, 'tk',tk, 'gStd',gStd, 'wDKL',wDKL);
end

end


% =====================================================================
%  RF CENTRES FROM STA (offline)
% =====================================================================

function c = rfCentersFromSTA(staA, staN, cfg, isChrom)

nCh = numel(staA);
c = nan(nCh, 2);
[colG, rowG] = meshgrid(1:cfg.nX, 1:cfg.nY);

for ch = 1:nCh
    if max(staN(ch,:)) < 1, continue; end
    counts = max(double(staN(ch,:)), 1);
    sta = staA{ch};
    nd = ndims(sta);
    shp = ones(1, nd);  shp(nd) = numel(counts);
    sta = sta ./ reshape(counts, shp);

    if isChrom
        sta = squeeze(sqrt(sum(sta.^2, 3)));
    end

    energy = squeeze(sum(sum(sta.^2, 1), 2));
    energy = energy(:)' .* counts;
    [eMax, peakLag] = max(energy);
    if eMax <= 0, continue; end

    slice  = sta(:,:,peakLag);
    mag    = abs(slice);
    maxMag = max(mag(:));
    if maxMag <= 0, continue; end

    w = mag;
    w(mag < cfg.threshFrac * maxMag) = 0;
    wS = sum(w(:));
    if wS <= 0, continue; end

    rowC = sum(rowG(:) .* w(:)) / wS;
    colC = sum(colG(:) .* w(:)) / wS;

    c(ch,1) =  (colC - 0.5 - cfg.nX/2) * cfg.checkSizeDeg + cfg.gridCenterDeg(1);
    c(ch,2) = -(rowC - 0.5 - cfg.nY/2) * cfg.checkSizeDeg + cfg.gridCenterDeg(2);
end

end


% =====================================================================
%  PARABOLIC PEAK (1-D)
% =====================================================================

function xPk = parabolicPeak1D(xAxis, y)
[~, idx] = max(y);
N = numel(y);
if N < 3 || idx == 1 || idx == N
    xPk = xAxis(idx);
    return;
end
y1 = y(idx-1);  y2 = y(idx);  y3 = y(idx+1);
denom = y1 - 2*y2 + y3;
if abs(denom) < eps
    xPk = xAxis(idx);
    return;
end
delta = 0.5 * (y1 - y3) / denom;
xPk = xAxis(idx) + delta * (xAxis(2) - xAxis(1));
end


% =====================================================================
%  VISUALISATION
% =====================================================================

function plotConvergence(R)

nM = numel(R.methodNames);
colors = [0.2 0.4 0.8;  0.8 0.2 0.2;  0.2 0.7 0.3;  0.8 0.6 0.1];

figure('Position', [80 120 1000 420], 'Name', 'RF Method Comparison');

% --- Panel 1: error vs trial count ---
ax1 = subplot(1,2,1);  hold(ax1, 'on');
hLines = gobjects(nM,1);
for m = 1:nM
    medE = squeeze(median(R.errors(:,m,:,:), 4, 'omitnan'));  % [nPop x nChk]
    mu = mean(medE, 1, 'omitnan');
    se = std(medE, 0, 1, 'omitnan') / sqrt(size(medE,1));
    fill(ax1, [R.checkpoints, fliplr(R.checkpoints)], ...
        [mu+se, fliplr(mu-se)], colors(m,:), ...
        'FaceAlpha', 0.15, 'EdgeColor', 'none');
    hLines(m) = plot(ax1, R.checkpoints, mu, '-', ...
        'Color', colors(m,:), 'LineWidth', 2);
end
yline(ax1, 1, '--k');
xlabel(ax1, 'Trials');
ylabel(ax1, 'Median RF error (dva)');
legend(ax1, hLines, R.methodNames, 'Location','northeast', ...
    'Interpreter','none', 'FontSize', 8);
title(ax1, 'Convergence by trial count');
ylim(ax1, [0, min(8, max(ylim(ax1)))]);

% --- Panel 2: error vs cumulative stimulus time ---
ax2 = subplot(1,2,2);  hold(ax2, 'on');
for m = 1:nM
    medE = squeeze(median(R.errors(:,m,:,:), 4, 'omitnan'));
    mu = mean(medE, 1, 'omitnan');
    se = std(medE, 0, 1, 'omitnan') / sqrt(size(medE,1));
    tAx = R.checkpoints * R.timePerTrial(m);
    fill(ax2, [tAx, fliplr(tAx)], [mu+se, fliplr(mu-se)], ...
        colors(m,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none');
    plot(ax2, tAx, mu, '-', 'Color', colors(m,:), 'LineWidth', 2);
end
yline(ax2, 1, '--k');
xlabel(ax2, 'Cumulative stim time (s)');
ylabel(ax2, 'Median RF error (dva)');
title(ax2, 'Convergence by time');
ylim(ax2, [0, min(8, max(ylim(ax2)))]);

drawnow;

end


function printSummary(R)

nM = numel(R.methodNames);
evalTrials = [100, 200, 400, R.checkpoints(end)];

fprintf('\n%s\n', repmat('=', 1, 72));
fprintf('  RF METHOD COMPARISON SUMMARY  (%d populations)\n', R.nPopulations);
fprintf('%s\n\n', repmat('=', 1, 72));

% --- Median error table ---
fprintf('%-22s', 'Median error (dva)');
for t = evalTrials, fprintf(' %7d tr', t); end
fprintf('\n%s\n', repmat('-', 1, 22 + 10*numel(evalTrials)));

for m = 1:nM
    fprintf('%-22s', R.methodNames{m});
    for t = evalTrials
        ci = find(R.checkpoints == t, 1);
        if isempty(ci)
            [~, ci] = min(abs(R.checkpoints - t));
        end
        medE = squeeze(median(R.errors(:,m,ci,:), 4, 'omitnan'));
        fprintf(' %9.2f', mean(medE, 'omitnan'));
    end
    fprintf('\n');
end

% --- Pass rate table ---
fprintf('\n%-22s', 'Pass rate (<1 dva)');
for t = evalTrials, fprintf(' %7d tr', t); end
fprintf('\n%s\n', repmat('-', 1, 22 + 10*numel(evalTrials)));

for m = 1:nM
    fprintf('%-22s', R.methodNames{m});
    for t = evalTrials
        ci = find(R.checkpoints == t, 1);
        if isempty(ci)
            [~, ci] = min(abs(R.checkpoints - t));
        end
        allE = squeeze(R.errors(:,m,ci,:));
        pr = mean(allE(:) < 1, 'omitnan');
        fprintf(' %8.0f%%', pr * 100);
    end
    fprintf('\n');
end

% --- Time-to-threshold ---
fprintf('\n%-22s  trials   time (s)\n', 'Trials to <1 dva');
fprintf('%s\n', repmat('-', 1, 44));
for m = 1:nM
    medE = squeeze(median(R.errors(:,m,:,:), 4, 'omitnan'));
    mu = mean(medE, 1, 'omitnan');
    ci = find(mu < 1, 1);
    if isempty(ci)
        fprintf('%-22s  > %d    > %.0f\n', R.methodNames{m}, ...
            R.checkpoints(end), R.checkpoints(end)*R.timePerTrial(m));
    else
        fprintf('%-22s  %5d    %6.0f\n', R.methodNames{m}, ...
            R.checkpoints(ci), R.checkpoints(ci)*R.timePerTrial(m));
    end
end

fprintf('\n');

end
