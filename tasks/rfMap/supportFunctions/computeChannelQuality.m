function quality = computeChannelQuality(p)
% computeChannelQuality  Per-channel RF quality score for go/no-go decisions.
%
%   quality = computeChannelQuality(p)
%
%   Scores each channel on multiple criteria derived from STA accumulators.
%   Returns a struct array (one per channel) with individual metrics and a
%   composite pass/fail flag suitable for selecting channels for
%   microstimulation (sacc_to_phosph).
%
%   Criteria (all computed from current STA accumulators on p.init):
%     1. spikeCount    - Total spikes at peak lag. Minimum needed for SNR.
%     2. peakSNR       - Energy at peak lag / median energy across lags.
%                        Indicates whether the temporal profile has a clear
%                        peak vs flat noise.
%     3. spatialSNR    - Peak spatial pixel magnitude / RMS of the STA
%                        slice at peak lag. High for localized RFs, low for
%                        diffuse noise.
%     4. rfCenterDeg   - [x, y] RF center estimate (from computeRFCenters).
%     5. rfSpreadDeg   - Weighted spatial spread around the centroid (proxy
%                        for RF center confidence; tight = confident).
%     6. passGo        - true if all thresholds met.
%
%   Thresholds (configurable via p.trVarsInit):
%     rfQualMinSpikes       - minimum spike count at peak lag (default 200)
%     rfQualMinPeakSNR      - minimum peak-lag SNR (default 1.15)
%     rfQualMinSpatialSNR   - minimum spatial SNR (default 5)
%     rfQualMaxSpreadDeg    - maximum RF spread in dva (default 4)

nCh = p.trVarsInit.nChannels;

% Configurable thresholds with defaults.
minSpikes     = getOr(p.trVarsInit, 'rfQualMinSpikes',     200);
minPeakSNR    = getOr(p.trVarsInit, 'rfQualMinPeakSNR',   1.15);
minSpatialSNR = getOr(p.trVarsInit, 'rfQualMinSpatialSNR', 5);
maxSpreadDeg  = getOr(p.trVarsInit, 'rfQualMaxSpreadDeg',  4);

isCheckerboard = strcmp(p.init.stimType, 'checkerboard');
isChromatic    = strcmp(p.init.stimType, 'denseChromatic');

rfCenters = computeRFCenters(p);

checkSizeDeg = p.trVarsInit.checkSizeDeg;
nY = p.init.noiseGridSize(1);
nX = p.init.noiseGridSize(2);
[colGrid, rowGrid] = meshgrid(1:nX, 1:nY);

emptyQ = struct('channel', 0, 'spikeCount', 0, 'peakLag', NaN, ...
    'peakSNR', NaN, 'spatialSNR', NaN, 'rfCenterDeg', [NaN NaN], ...
    'rfSpreadDeg', NaN, 'passGo', false, 'failReasons', {{}});
quality = repmat(emptyQ, nCh, 1);

for ch = 1:nCh
    quality(ch).channel = ch;
    quality(ch).rfCenterDeg = rfCenters(ch, :);

    if isCheckerboard || ~isfield(p.init, 'staAccum') || ...
            isempty(p.init.staAccum)
        quality(ch).failReasons = {'no_spatial_sta'};
        continue;
    end

    if max(p.init.staSpikeCount(ch, :)) < 1
        quality(ch).failReasons = {'no_spikes'};
        continue;
    end

    counts = max(p.init.staSpikeCount(ch, :), 1);

    nd = ndims(p.init.staAccum{ch});
    shp = ones(1, nd);
    shp(nd) = numel(counts);
    sta = p.init.staAccum{ch} ./ reshape(counts, shp);

    if isChromatic
        sta = squeeze(sqrt(sum(sta.^2, 3)));
    end

    % Energy per lag (corrected metric).
    energy = squeeze(sum(sum(sta.^2, 1), 2));
    energy = energy(:)' .* counts;

    [peakEnergy, peakLag] = max(energy);
    medianEnergy = median(energy);

    quality(ch).spikeCount = p.init.staSpikeCount(ch, peakLag);
    quality(ch).peakLag = peakLag;

    % Peak SNR: how much the peak lag stands out.
    if medianEnergy > 0
        quality(ch).peakSNR = peakEnergy / medianEnergy;
    else
        quality(ch).peakSNR = 0;
    end

    % Spatial SNR at peak lag.
    slice = sta(:, :, peakLag);
    mag = abs(slice);
    peakMag = max(mag(:));
    rmsMag  = sqrt(mean(mag(:).^2));
    if rmsMag > 0
        quality(ch).spatialSNR = peakMag / rmsMag;
    else
        quality(ch).spatialSNR = 0;
    end

    % RF spread: weighted standard deviation of pixel positions.
    threshFrac = getOr(p.trVarsInit, 'rfCenterThreshFrac', 0.5);
    w = mag;
    w(mag < threshFrac * peakMag) = 0;
    wSum = sum(w(:));
    if wSum > 0
        rowC = sum(rowGrid(:) .* w(:)) / wSum;
        colC = sum(colGrid(:) .* w(:)) / wSum;
        rowVar = sum(w(:) .* (rowGrid(:) - rowC).^2) / wSum;
        colVar = sum(w(:) .* (colGrid(:) - colC).^2) / wSum;
        spreadChecks = sqrt(rowVar + colVar);
        quality(ch).rfSpreadDeg = spreadChecks * checkSizeDeg;
    else
        quality(ch).rfSpreadDeg = Inf;
    end

    % Go/no-go evaluation.
    reasons = {};
    if quality(ch).spikeCount < minSpikes
        reasons{end+1} = sprintf('low_spikes(%d<%d)', ...
            quality(ch).spikeCount, minSpikes);
    end
    if quality(ch).peakSNR < minPeakSNR
        reasons{end+1} = sprintf('low_peakSNR(%.1f<%.1f)', ...
            quality(ch).peakSNR, minPeakSNR);
    end
    if quality(ch).spatialSNR < minSpatialSNR
        reasons{end+1} = sprintf('low_spatialSNR(%.1f<%.1f)', ...
            quality(ch).spatialSNR, minSpatialSNR);
    end
    if quality(ch).rfSpreadDeg > maxSpreadDeg
        reasons{end+1} = sprintf('wide_rf(%.1f>%.1f)', ...
            quality(ch).rfSpreadDeg, maxSpreadDeg);
    end
    if any(isnan(quality(ch).rfCenterDeg))
        reasons{end+1} = 'no_center';
    end

    quality(ch).failReasons = reasons;
    quality(ch).passGo = isempty(reasons);
end

end


function v = getOr(s, field, default)
if isfield(s, field)
    v = s.(field);
else
    v = default;
end
end
