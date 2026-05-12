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
        % Off-peak noise floor: MAD over pixels outside an exclusion disc
        % around the argmax. Use absolute value because FBP ringing has
        % both signs and we want the magnitude of the noise envelope.
        [Xg, Yg] = meshgrid(out.axisDeg, out.axisDeg);
        offMask = hypot(Xg - peakX, Yg - peakY) > opts.exclusionDeg;
        if any(offMask(:))
            offVals = out.rfImage(offMask);
            noise = 1.4826 * mad(offVals, 1);   % MAD scaled to sigma-equivalent
        else
            noise = NaN;
        end
        if isnan(noise) || noise <= 0, noise = eps; end
        out.peakStats = struct( ...
            'peakValue', peakVal, ...
            'peakXY',    [peakX, peakY], ...
            'noiseLevel', noise, ...
            'snr',       peakVal / noise, ...
            'detected',  (peakVal / noise) >= opts.detectThresh);
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
        % After opposite-pooling, orientationsRad has 2 entries:
        % 0 (vertical bar => x-projection) and pi/2 (horizontal bar =>
        % y-projection).
        xIdx = find(abs(rf.orientationsRad - 0)    < 1e-6, 1);
        yIdx = find(abs(rf.orientationsRad - pi/2) < 1e-6, 1);
        if isempty(xIdx) || isempty(yIdx)
            error(['reconstructBarsweepRF: cardinal4 expects orientationsRad ' ...
                   'to contain 0 and pi/2 exactly.']);
        end

        out.rateX   = rateMatrix(xIdx, :);
        out.rateY   = rateMatrix(yIdx, :);
        out.axisX   = rf.positionCenters;
        out.axisY   = rf.positionCenters;
        out.xCenter = parabolicPeak(out.axisX, out.rateX);
        out.yCenter = parabolicPeak(out.axisY, out.rateY);
        % Outer-product separable estimate, normalized to [0, 1].
        sep = out.rateY(:) * out.rateX(:)';        % rows = y, cols = x
        m   = max(sep(:));
        if m <= 0
            sep = zeros(size(sep));
        else
            sep = sep / m;
        end
        out.separable2D = sep;
        out.rateMatrix  = rateMatrix;

        % --- Per-axis SNR (cardinal4) ---
        % For each 1D profile compute the off-peak noise as 1.4826 * MAD
        % of bins more than exclusionDeg from the argmax. SNR is
        % min(peak_x / noise_x, peak_y / noise_y) -- both axes must
        % clear threshold for the (x_c, y_c) readout to be trusted.
        snrX = profileSNR(out.axisX, out.rateX, opts.exclusionDeg);
        snrY = profileSNR(out.axisY, out.rateY, opts.exclusionDeg);
        snr  = min(snrX, snrY);
        peakXVal = max(out.rateX); peakYVal = max(out.rateY);
        out.peakStats = struct( ...
            'peakValue', max(peakXVal, peakYVal), ...
            'peakXY',    [out.xCenter, out.yCenter], ...
            'noiseLevel', NaN, ...     % per-axis only; see snrX, snrY
            'snr',       snr, ...
            'snrX',      snrX, ...
            'snrY',      snrY, ...
            'detected',  snr >= opts.detectThresh);
        % 2D moment fit on the separable thumbnail. The thumbnail is
        % already non-negative (outer product of non-negative profiles)
        % so no positive-part clipping needed; threshold at fitFloorFrac
        % to drop the long sub-peak tails that would bias the moments.
        if out.peakStats.detected
            [Xg, Yg] = meshgrid(out.axisX, out.axisY);
            sep2 = out.separable2D;
            mask = sep2 >= opts.fitFloorFrac * max(sep2(:));
            out.gaussFit = momentFit2D(sep2, Xg, Yg, mask);
        else
            out.gaussFit = emptyGaussFit();
        end

    otherwise
        error('reconstructBarsweepRF: unknown exptType "%s".', exptType);
end

end

%% --- helpers ---

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

function s = profileSNR(axisDeg, rate, exclusionDeg)
% Peak-to-MAD SNR for a 1D rate profile. Excludes a +/- exclusionDeg
% window around the argmax when computing the noise floor.
[peakVal, ip] = max(rate);
peakX = axisDeg(ip);
offMask = abs(axisDeg - peakX) > exclusionDeg;
if ~any(offMask)
    s = 0; return;
end
offVals = rate(offMask);
medOff = median(offVals);
noise  = 1.4826 * mad(offVals, 1);
if noise <= 0, noise = eps; end
s = (peakVal - medOff) / noise;     % subtract baseline so a flat profile -> 0
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
