function out = reconstructBarsweepRF(rf, ch, exptType, opts)
% out = reconstructBarsweepRF(rf, ch, exptType, opts)
%
% Reconstruct a per-channel RF estimate from the running accumulator.
% Pure function: takes the rf struct (assumed to be a snapshot of
% p.init.barsweepRF) and a channel index, returns regime-appropriate
% output. Kept separate from plotBarsweepRF so it's reusable from
% offline replay scripts.
%
% rfmap12 -> out.rfImage (2D), out.axisDeg
% cardinal4 -> out.rateX, out.rateY, out.axisX, out.axisY,
%              out.xCenter, out.yCenter, out.separable2D
%
% Both regimes also return:
%   out.peakStats - struct with peakValue, peakXY (path-center-relative
%                   dva), noiseLevel (1.4826*MAD off-peak), snr, detected.
%   out.gaussFit  - struct with x0, y0 (moment-based centroid),
%                   sigmaX, sigmaY (marginal SDs), rho (correlation),
%                   fwhmX, fwhmY, ellipseX, ellipseY (1-sigma contour
%                   vertices for plotting). All in path-center-relative
%                   dva. Returns NaN-filled struct when peakStats.detected
%                   is false (no point fitting noise).
%
% opts (optional struct, all fields optional):
%   .detectThresh - SNR threshold for peakStats.detected. Default 3.0.
%   .fitFloorFrac - fraction of peak below which pixels are excluded
%                   from the moment fit. Default 0.25 (i.e. only the
%                   FWHM-ish region contributes to the centroid).
%   .exclusionDeg - radius (rfmap12) or half-width (cardinal4 1D) around
%                   the argmax to exclude when computing the noise floor.
%                   Default 1.5 dva.

if nargin < 4 || isempty(opts), opts = struct(); end
if ~isfield(opts, 'detectThresh'), opts.detectThresh = 4.0; end
if ~isfield(opts, 'fitFloorFrac'), opts.fitFloorFrac = 0.25; end
if ~isfield(opts, 'exclusionDeg'), opts.exclusionDeg = 1.5; end
% cardinal4 v2 only: PSTH smoothing scale (dva) for display + peak picking,
% and fit mode -- 'cheap' (parabolic peak of the smoothed profile, used live
% for all channels) or 'full' (per-direction Gaussian fit, used at session
% end / on demand and for the export).
if ~isfield(opts, 'smoothDeg'), opts.smoothDeg = 0.5; end
if ~isfield(opts, 'fitMode'),   opts.fitMode   = 'cheap'; end

% Build the rate matrix [nOri x nPosBins] for this channel.
spikeMat = squeeze(rf.spikeHist(:, :, ch));    % [nOri x nPosBins]
% Force row vector when nOri == 1 (squeeze can collapse to a column).
if size(spikeMat, 2) ~= numel(rf.positionCenters)
    spikeMat = spikeMat.';
end
rateMatrix = spikeMat ./ rf.dwellTime;

% Zero-dwell handling: replace NaN/Inf bins with the orientation row's
% mean rate (so they neither suppress nor excite the back-projection).
zeroDwell = ~isfinite(rateMatrix);
for k = 1:size(rateMatrix, 1)
    rowDwell = rf.dwellTime(k, :);
    rowVals  = rateMatrix(k, ~zeroDwell(k, :));
    if isempty(rowVals)
        rowMean = 0;
    else
        rowMean = mean(rowVals);
        if isnan(rowMean), rowMean = 0; end
    end
    rateMatrix(k, zeroDwell(k, :)) = rowMean;
    % Also handle bins where dwell is genuinely zero (untouched by
    % isfinite check above if dwell == 0 and spikes == 0 -> 0/0 = NaN
    % which is caught; but spikes>0 and dwell==0 would give Inf which
    % is caught here too).
    rateMatrix(k, rowDwell == 0) = rowMean;
end

switch exptType
    case 'barsweep_rfmap12'
        nMapPix = max(2, round(2 * rf.mapExtentDeg / rf.mapPixelDeg));
        % iradon expects a [nProj x nOri] sinogram. Our rateMatrix is
        % [nOri x nPosBins], so transpose. But iradon also expects each
        % column to be the projection onto one orientation, so we need
        % rateMatrix' as the sinogram with rows = position, cols = ori.
        sinogram = rateMatrix';
        orientationsDeg = rad2deg(rf.orientationsRad);
        if exist('iradon', 'file') == 2
            rfImg = iradon(sinogram, orientationsDeg, ...
                'linear', rf.rampFilter, rf.rampCutoff, nMapPix);
        else
            % Image Processing Toolbox missing: fall back to back-
            % projection without filtering (worse but visible).
            warning('reconstructBarsweepRF:noIradon', ...
                'iradon not on path; using unfiltered back-projection.');
            rfImg = simpleBackProject(sinogram, ...
                orientationsDeg, nMapPix, rf.positionCenters);
        end
        % iradon returns the reconstructed image with row 1 = most-positive
        % math-y (the standard image-y-down convention). Our experimenters
        % work in y-up (positive y = above fixation) -- flip vertically so
        % row 1 of out.rfImage corresponds to y = -mapExtentDeg and row N
        % to y = +mapExtentDeg. With axisDeg ascending, callers can then
        % treat axisDeg(ry) as the user-y at row ry without sign juggling.
        out.rfImage    = flipud(rfImg);
        out.axisDeg    = linspace(-rf.mapExtentDeg, rf.mapExtentDeg, nMapPix);
        out.rateMatrix = rateMatrix;

        % --- Peak detection + 2D Gaussian fit (rfmap12) ---
        [peakVal, idx] = max(out.rfImage(:));
        [ry, rx]       = ind2sub(size(out.rfImage), idx);
        peakX          = out.axisDeg(rx);
        peakY          = out.axisDeg(ry);
        % Off-peak noise floor: combine MAD (outlier-robust) and std
        % (handles sparse-spike FBP images where most off-peak pixels
        % are near zero and median = MAD = 0) over pixels that are
        % (a) outside the exclusion disc around the argmax and
        % (b) inside the coverage region. The coverage region is the
        % union of the bar paths at orientations where dwell > 0;
        % including the uncovered surround would deflate the noise
        % estimate because those pixels are dominated by interpolation
        % zeros, not by spike statistics.
        [Xg, Yg] = meshgrid(out.axisDeg, out.axisDeg);
        covMask = false(size(Xg));
        for kk = 1:numel(orientationsDeg)
            th = deg2rad(orientationsDeg(kk));
            sProj = Xg * cos(th) + Yg * sin(th);
            iBin = interp1(rf.positionCenters, ...
                1:numel(rf.positionCenters), sProj, 'nearest', NaN);
            inRange = isfinite(iBin);
            iBin(~inRange) = 1;
            dwellPix = rf.dwellTime(kk, iBin);
            covMask = covMask | (inRange & reshape(dwellPix > 0, size(Xg)));
        end
        offMask = (hypot(Xg - peakX, Yg - peakY) > opts.exclusionDeg) & covMask;
        if any(offMask(:))
            offVals  = out.rfImage(offMask);
            medOff   = median(offVals);
            noiseMAD = 1.4826 * mad(offVals, 1);
            noiseStd = std(offVals);
            noise    = max(noiseMAD, noiseStd);
            if noise <= 0
                snrVal = 0;
            else
                snrVal = (peakVal - medOff) / noise;
            end
        else
            medOff = 0; noise = eps; snrVal = 0;
        end
        out.peakStats = struct( ...
            'peakValue', peakVal, ...
            'peakXY',    [peakX, peakY], ...
            'noiseLevel', noise, ...
            'snr',       snrVal, ...
            'detected',  snrVal >= opts.detectThresh);
        % 2D moment fit on the positive part of the image. Threshold at
        % opts.fitFloorFrac * peak so off-peak ringing doesn't pollute
        % the centroid; restrict to the local peak component via a
        % connectivity-free disc cut at exclusionDeg*2 from the argmax.
        if out.peakStats.detected
            posImg = max(out.rfImage, 0);
            mask = hypot(Xg - peakX, Yg - peakY) <= 2 * opts.exclusionDeg;
            mask = mask & (posImg >= opts.fitFloorFrac * peakVal);
            out.gaussFit = momentFit2D(posImg, Xg, Yg, mask);
        else
            out.gaussFit = emptyGaussFit();
        end

    case 'barsweep_cardinal4'
        % v2 MIDPOINT METHOD. rateMatrix is [nDir x nPos], one row per sweep
        % direction in rf.directionsRad order ([0 90 180 270]). Each
        % direction's response peak sits at s_RF +/- L*v (shifted along the
        % direction of motion by response latency L). Azimuth = midpoint of
        % the 0/180 peaks; elevation = midpoint of the 90/270 peaks --
        % latency cancels, never assumed. Latency is read from the peak
        % SEPARATION.
        axisPos = rf.positionCenters(:).';                 % [1 x nPos] path-center-rel dva
        dirsDeg = round(rad2deg(rf.directionsRad(:).'));   % [0 90 180 270]
        nDir    = numel(dirsDeg);
        binDeg  = rf.rfPosBinDeg;

        fullFit    = strcmp(opts.fitMode, 'full');
        smoothBins = max(1, round(opts.smoothDeg / binDeg));

        smoothByDir = zeros(nDir, numel(axisPos));
        peakByDir   = nan(nDir, 1);
        snrByDir    = zeros(nDir, 1);
        fitByDir    = repmat(emptyGaussFit1D(), nDir, 1);
        for d = 1:nDir
            sm = smooth1D(rateMatrix(d, :), smoothBins);
            smoothByDir(d, :) = sm;
            % SNR off the smoothed profile, dropping zero-dwell bins.
            snrByDir(d) = profileSNR(axisPos, sm, rf.dwellTime(d, :), ...
                opts.exclusionDeg);
            if fullFit
                fitByDir(d) = gaussFit1D(axisPos, sm, rf.dwellTime(d, :));
                if fitByDir(d).ok
                    peakByDir(d) = fitByDir(d).mu;
                else
                    peakByDir(d) = parabolicPeak(axisPos, sm);
                end
            else
                peakByDir(d) = parabolicPeak(axisPos, sm);
            end
        end

        % Map directions to axes: 0/180 sweep AZIMUTH (x), 90/270 sweep
        % ELEVATION (y).
        i0   = findDir(dirsDeg, 0);
        i180 = findDir(dirsDeg, 180);
        i90  = findDir(dirsDeg, 90);
        i270 = findDir(dirsDeg, 270);

        out.xCenter = mean([peakByDir(i0),  peakByDir(i180)], 'omitnan');
        out.yCenter = mean([peakByDir(i90), peakByDir(i270)], 'omitnan');

        % Latency (ms) from peak separation / (2*speed). For a real lagging
        % response peak@0 > peak@180 (positive). NaN if speed unknown.
        if isfield(rf, 'speedDegPerSec') && isfinite(rf.speedDegPerSec) && ...
                rf.speedDegPerSec > 0
            out.latencyAzMs = 1000 * (peakByDir(i0)  - peakByDir(i180)) / ...
                (2 * rf.speedDegPerSec);
            out.latencyElMs = 1000 * (peakByDir(i90) - peakByDir(i270)) / ...
                (2 * rf.speedDegPerSec);
        else
            out.latencyAzMs = NaN;
            out.latencyElMs = NaN;
        end
        out.latencyMs = mean([out.latencyAzMs, out.latencyElMs], 'omitnan');

        % Per-axis SNR: BOTH opposite directions must show a peak, since the
        % midpoint is only meaningful when both peaks are real.
        snrX = min(snrByDir(i0),  snrByDir(i180));
        snrY = min(snrByDir(i90), snrByDir(i270));
        snr  = min(snrX, snrY);

        % --- New per-direction outputs (4-panel viz consumes these) ---
        out.directionsDeg = dirsDeg;
        out.axis          = axisPos;
        out.rateByDir     = rateMatrix;
        out.smoothByDir   = smoothByDir;
        out.peakByDir     = peakByDir;
        out.fitByDir      = fitByDir;
        out.snrByDir      = snrByDir;
        out.rateMatrix    = rateMatrix;

        out.peakStats = struct( ...
            'peakValue', max(rateMatrix(:)), ...
            'peakXY',    [out.xCenter, out.yCenter], ...
            'noiseLevel', NaN, ...
            'snr',       snr, ...
            'snrX',      snrX, ...
            'snrY',      snrY, ...
            'detected',  snr >= opts.detectThresh);

        % --- Backward-compatible fields (existing plot/browser/export) ---
        % rateX/rateY are the average of each axis' two direction profiles
        % (a DISPLAY AID; the RF center is xCenter/yCenter, NOT the peak of
        % these averages). axisX/axisY = positionCenters.
        out.axisX = axisPos;
        out.axisY = axisPos;
        out.rateX = mean(smoothByDir([i0,  i180], :), 1);
        out.rateY = mean(smoothByDir([i90, i270], :), 1);
        sep = out.rateY(:) * out.rateX(:)';
        m   = max(sep(:));
        if m <= 0, sep = zeros(size(sep)); else, sep = sep / m; end
        out.separable2D = sep;

        % gaussFit compat: centered on the midpoint centers, widths from the
        % per-direction fits (full) or the profile second moment (cheap);
        % axis-aligned 1-sigma ellipse for overlays.
        sigX = axisSigma(fitByDir([i0,  i180]), axisPos, smoothByDir([i0,  i180], :));
        sigY = axisSigma(fitByDir([i90, i270]), axisPos, smoothByDir([i90, i270], :));
        out.gaussFit = buildCompatGaussFit(out.xCenter, out.yCenter, ...
            sigX, sigY, out.peakStats.detected);

    otherwise
        error('reconstructBarsweepRF: unknown exptType "%s".', exptType);
end

end

%% --- helpers ---

function y = smooth1D(x, sigmaBins)
% Edge-corrected Gaussian smoothing of a 1D profile (no toolbox needed).
x = x(:).';
if sigmaBins <= 0.5 || numel(x) < 3
    y = x;
    return;
end
half = ceil(3 * sigmaBins);
t = -half:half;
k = exp(-0.5 * (t / sigmaBins).^2);
k = k / sum(k);
num = conv(x, k, 'same');
den = conv(ones(size(x)), k, 'same');   % normalize out edge tapering
y = num ./ den;
end

function idx = findDir(dirsDeg, target)
% Index of a cardinal direction within dirsDeg (mod 360).
idx = find(mod(dirsDeg - target, 360) == 0, 1);
if isempty(idx)
    error('reconstructBarsweepRF: cardinal4 missing direction %d deg.', target);
end
end

function fit = emptyGaussFit1D()
fit = struct('amp', NaN, 'mu', NaN, 'sigma', NaN, 'offset', NaN, ...
    'peak', NaN, 'ok', false);
end

function fit = gaussFit1D(xAxis, y, dwell)
% 1D Gaussian-plus-offset fit via fminsearch (base MATLAB; no Optimization
% Toolbox). y = amp*exp(-(x-mu)^2/(2 sigma^2)) + offset, fit over bins with
% dwell > 0. Returns fit.ok = false (mu = NaN) when the fit is degenerate or
% lands off-axis, so the caller falls back to the parabolic peak.
fit = emptyGaussFit1D();
xAxis = xAxis(:).'; y = y(:).'; dwell = dwell(:).';
valid = dwell > 0 & isfinite(y);
if sum(valid) < 5
    return;
end
xv = xAxis(valid); yv = y(valid);
[ymax, im] = max(yv);
b0  = median(yv);
a0  = max(ymax - b0, eps);
mu0 = xv(im);
above = yv > (b0 + 0.5 * a0);
dx = xAxis(2) - xAxis(1);
if nnz(above) >= 2
    s0 = max((max(xv(above)) - min(xv(above))) / 2.355, 2 * dx);
else
    s0 = 3 * dx;
end
obj = @(pp) sum((pp(1) * exp(-0.5 * ((xv - pp(2)) / max(abs(pp(3)), eps)).^2) ...
    + pp(4) - yv).^2);
opt = optimset('Display', 'off', 'MaxFunEvals', 2000, 'MaxIter', 2000);
try
    pf = fminsearch(obj, [a0, mu0, s0, b0], opt);
catch
    pf = [a0, mu0, s0, b0];
end
fit.amp = pf(1); fit.mu = pf(2); fit.sigma = abs(pf(3)); fit.offset = pf(4);
fit.peak = pf(2);
if ~isfinite(fit.mu) || fit.amp <= 0 || ...
        fit.mu < xAxis(1) || fit.mu > xAxis(end)
    fit.mu = NaN; fit.peak = NaN;
end
fit.ok = isfinite(fit.mu);
end

function s = axisSigma(fits, xAxis, profs)
% Representative RF width (dva) for one axis: mean of the per-direction
% Gaussian sigmas when available, else the second moment of the mean
% profile about its centroid.
sig = [];
for k = 1:numel(fits)
    if isstruct(fits(k)) && isfield(fits(k), 'sigma') && ...
            isfinite(fits(k).sigma) && fits(k).sigma > 0
        sig(end + 1) = fits(k).sigma; %#ok<AGROW>
    end
end
if ~isempty(sig)
    s = mean(sig);
    return;
end
xAxis = xAxis(:).';
mp = mean(profs, 1);
w  = max(mp - min(mp), 0);
W  = sum(w);
if W <= 0
    s = NaN;
    return;
end
mu = sum(w .* xAxis) / W;
s  = sqrt(max(sum(w .* (xAxis - mu).^2) / W, 0));
if s <= 0, s = NaN; end
end

function fit = buildCompatGaussFit(x0, y0, sigX, sigY, detected)
% Assemble a 2D gaussFit-compatible struct (same fields as emptyGaussFit)
% centered on the midpoint centers with axis-aligned widths, for the legacy
% plot/browser/export overlays.
fit = emptyGaussFit();
if ~detected || ~isfinite(x0) || ~isfinite(y0)
    return;
end
fit.x0 = x0; fit.y0 = y0;
fit.sigmaX = sigX; fit.sigmaY = sigY; fit.rho = 0;
if isfinite(sigX), fit.fwhmX = 2.3548 * sigX; end
if isfinite(sigY), fit.fwhmY = 2.3548 * sigY; end
if isfinite(sigX) && isfinite(sigY)
    phi = linspace(0, 2*pi, 64);
    fit.ellipseX = x0 + sigX * cos(phi);
    fit.ellipseY = y0 + sigY * sin(phi);
    fit.covariance = [sigX^2, 0; 0, sigY^2];
end
end

function xPeak = parabolicPeak(xAxis, y)
% 3-point parabolic interpolation around the argmax. Falls back to
% argmax when the curvature term is degenerate or the peak sits at the
% array edges. Sub-bin precision at zero cost; preserves the centroid
% exactly for symmetric profiles.

[~, i] = max(y);
n = numel(y);
if n < 3 || i == 1 || i == n
    xPeak = xAxis(i);
    return;
end
y1 = y(i-1); y2 = y(i); y3 = y(i+1);
denom = (y1 - 2*y2 + y3);
if abs(denom) < eps
    xPeak = xAxis(i);
    return;
end
% Subbin offset in [-1, 1] when the peak is well-conditioned.
delta = 0.5 * (y1 - y3) / denom;
if ~isfinite(delta) || abs(delta) > 1
    xPeak = xAxis(i);
    return;
end
xPeak = xAxis(i) + delta * (xAxis(2) - xAxis(1));

end

function s = profileSNR(axisDeg, rate, dwell, exclusionDeg)
% Peak-to-noise SNR for a 1D rate profile. Excludes a +/- exclusionDeg
% window around the argmax AND bins with zero dwell (the row-mean fill
% applied upstream collapses MAD to 0 if those are kept). Noise floor
% is max(1.4826*MAD, sqrt(baseline/dwell)) so sparse-spike profiles
% don't underestimate noise via MAD = 0.
axisDeg = axisDeg(:).';
rate    = rate(:).';
dwell   = dwell(:).';
valid = dwell > 0 & isfinite(rate);
if sum(valid) < 5
    s = 0; return;
end
r = rate(valid);
p = axisDeg(valid);
d = dwell(valid);
[peakVal, ip] = max(r);
peakX = p(ip);
offMask = abs(p - peakX) > exclusionDeg;
if ~any(offMask)
    s = 0; return;
end
offVals = r(offMask);
offDwell = d(offMask);
medOff   = median(offVals);     % robust baseline for peak-above-baseline
meanOff  = mean(offVals);       % mean rate as Poisson rate estimate
noiseMAD = 1.4826 * mad(offVals, 1);
% Poisson shot-noise floor for a single-bin rate estimate at the
% off-peak baseline: rate = k/t with k ~ Poisson(lambda*t) has
% std sqrt(lambda/t). Use the mean off-peak rate as the lambda
% estimate -- median collapses to 0 on sparse profiles where most
% bins have zero spikes, even when valid (non-zero-dwell) bins are
% selected.
medDwell = median(offDwell);
if medDwell <= 0, medDwell = eps; end
poissonFloor = sqrt(max(meanOff, 0) / medDwell);
noise = max(noiseMAD, poissonFloor);
if noise <= 0, noise = eps; end
s = (peakVal - medOff) / noise;
end

function fit = momentFit2D(img, Xg, Yg, mask)
% Method-of-moments 2D Gaussian fit on a non-negative image, restricted
% to mask. Returns centroid + covariance + 1-sigma ellipse vertices.
% No iterative solver: O(N^2) once per channel per refresh.

if ~any(mask(:))
    fit = emptyGaussFit();
    return;
end
w  = img;
w(~mask) = 0;
W  = sum(w(:));
if W <= 0
    fit = emptyGaussFit();
    return;
end
x0 = sum(w(:) .* Xg(:)) / W;
y0 = sum(w(:) .* Yg(:)) / W;
dX = Xg - x0; dY = Yg - y0;
sxx = sum(w(:) .* dX(:).^2) / W;
syy = sum(w(:) .* dY(:).^2) / W;
sxy = sum(w(:) .* dX(:) .* dY(:)) / W;

sigmaX = sqrt(max(sxx, 0));
sigmaY = sqrt(max(syy, 0));
denom  = sigmaX * sigmaY;
if denom <= 0
    rho = 0;
else
    rho = sxy / denom;
    rho = max(-0.99, min(0.99, rho));   % numerical safety
end

% 1-sigma ellipse via eigendecomposition of the covariance matrix.
C = [sxx, sxy; sxy, syy];
[V, D] = eig(C);
phi = linspace(0, 2*pi, 64);
% Principal-axis radii = sqrt(eigenvalues).
ellipsePts = V * sqrt(max(D, 0)) * [cos(phi); sin(phi)];

fit = struct( ...
    'x0',       x0, ...
    'y0',       y0, ...
    'sigmaX',   sigmaX, ...
    'sigmaY',   sigmaY, ...
    'rho',      rho, ...
    'fwhmX',    2.3548 * sigmaX, ...    % 2*sqrt(2*ln(2))
    'fwhmY',    2.3548 * sigmaY, ...
    'ellipseX', x0 + ellipsePts(1, :), ...
    'ellipseY', y0 + ellipsePts(2, :), ...
    'covariance', C);
end

function fit = emptyGaussFit()
fit = struct( ...
    'x0',       NaN, ...
    'y0',       NaN, ...
    'sigmaX',   NaN, ...
    'sigmaY',   NaN, ...
    'rho',      NaN, ...
    'fwhmX',    NaN, ...
    'fwhmY',    NaN, ...
    'ellipseX', [], ...
    'ellipseY', [], ...
    'covariance', NaN(2));
end

function img = simpleBackProject(sinogram, orientationsDeg, nMapPix, posCenters)
% Minimal unfiltered back-projection. Only used when iradon is missing.
% Quality is markedly worse but the function should still run.

img = zeros(nMapPix);
[X, Y] = meshgrid(linspace(min(posCenters), max(posCenters), nMapPix));
for k = 1:numel(orientationsDeg)
    th = deg2rad(orientationsDeg(k));
    proj = sinogram(:, k);
    s = X * cos(th) + Y * sin(th);
    vals = interp1(posCenters, proj, s, 'linear', 0);
    img = img + vals;
end
img = img / max(numel(orientationsDeg), 1);

end
