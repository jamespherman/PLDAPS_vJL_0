function rfCentersDeg = computeRFCenters(p)
% computeRFCenters  Per-channel RF center (dva) from current STA accumulators.
%
%   rfCentersDeg = computeRFCenters(p)
%
%   Returns an nChannels x 2 matrix of [x_deg, y_deg] centers in degrees
%   of visual angle relative to the fixation point (PTB-convention Y is
%   flipped so +y_deg is up in visual space).
%
%   Algorithm (per channel):
%     1. If staSpikeCount(ch) < 1 or stimType is 'checkerboard' -> NaN row.
%     2. Mean STA = staAccum{ch} / staSpikeCount(ch).
%     3. Chromatic: per-pixel L2 across DKL axes -> [nY, nX, nLags].
%     4. Lag energy -> peak lag -> slice [nY, nX].
%     5. mag = abs(slice); thr = threshFrac * max(mag(:)).
%     6. Centroid of mag thresholded at thr (rows = y, cols = x).
%     7. Grid (row, col) -> screen pixel using p.draw.middleXY and the
%        noiseGridSize geometry, then to dva via pds.pix2deg using the
%        fixation pixel as origin.
%
%   Checkerboard mode has no spatial accumulator (struct, not cell), so
%   it returns all-NaN -- callers may simply skip running this on
%   p.init.stimType == 'checkerboard'.

nCh = p.trVarsInit.nChannels;
rfCentersDeg = nan(nCh, 2);

% Checkerboard has no spatial RF -- bail with NaN.
if strcmp(p.init.stimType, 'checkerboard')
    return;
end

% Defensive: STA may not yet be allocated on the very first call.
if ~isfield(p.init, 'staAccum') || isempty(p.init.staAccum) || ...
        ~isfield(p.init, 'staSpikeCount')
    return;
end

threshFrac  = p.trVarsInit.rfCenterThreshFrac;
isChromatic = strcmp(p.init.stimType, 'denseChromatic');

nY = p.init.noiseGridSize(1);
nX = p.init.noiseGridSize(2);

% checkSizePix mirrors nextParams.m:82-83.
checkSizePix = pds.deg2pix(p.trVars.checkSizeDeg, p);
if checkSizePix < 1, checkSizePix = 1; end

% Grid is centered at noiseGridCenterPix (defaults to middleXY for
% full-screen; shifted for hemifield modes — see rfMap_init.m).
if isfield(p.init, 'noiseGridCenterPix')
    midX = p.init.noiseGridCenterPix(1);
    midY = p.init.noiseGridCenterPix(2);
else
    midX = p.draw.middleXY(1);
    midY = p.draw.middleXY(2);
end
fixPx = p.draw.fixPointPix(1);
fixPy = p.draw.fixPointPix(2);

% Precompute row/col index grids for the centroid weighted sum.
[colGrid, rowGrid] = meshgrid(1:nX, 1:nY);

for ch = 1:nCh
    if max(p.init.staSpikeCount(ch, :)) < 1, continue; end

    counts = max(p.init.staSpikeCount(ch, :), 1);
    nd = ndims(p.init.staAccum{ch});
    shp = ones(1, nd);
    shp(nd) = numel(counts);
    sta = p.init.staAccum{ch} ./ reshape(counts, shp);
    if isChromatic
        % [nY, nX, 3, nLags] -> [nY, nX, nLags] color-blind RF magnitude.
        sta = squeeze(sqrt(sum(sta.^2, 3)));
    end

    energy = squeeze(sum(sum(sta.^2, 1), 2));
    energy = energy(:)' .* counts;
    [eMax, peakLag] = max(energy(:));
    if eMax <= 0, continue; end

    slice = sta(:, :, peakLag);
    mag   = abs(slice);
    maxMag = max(mag(:));
    if maxMag <= 0, continue; end

    w = mag;
    w(mag < threshFrac * maxMag) = 0;
    wSum = sum(w(:));
    if wSum <= 0, continue; end

    rowC = sum(rowGrid(:) .* w(:)) / wSum;
    colC = sum(colGrid(:) .* w(:)) / wSum;

    % Grid (row, col) -> screen pixel (centered on middleXY).
    screenX = midX + (colC - 0.5 - nX / 2) * checkSizePix;
    screenY = midY + (rowC - 0.5 - nY / 2) * checkSizePix;

    % dva relative to fixation. PTB screen Y grows downward; dva up is
    % positive, so flip Y when subtracting from fixation.
    rfCentersDeg(ch, 1) = pds.pix2deg(screenX - fixPx, p);
    rfCentersDeg(ch, 2) = pds.pix2deg(fixPy - screenY, p);
end

end
