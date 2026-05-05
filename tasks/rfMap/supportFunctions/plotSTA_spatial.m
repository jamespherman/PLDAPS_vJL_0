function plotSTA_spatial(figData, staAccum, staSpikeCount, ...
    selectedChannel, nAxes)
% plotSTA_spatial  Render online STA spatial map for dense / sparse / chromatic.
%
%   plotSTA_spatial(figData, staAccum, staSpikeCount, selectedChannel, nAxes)
%
%   Maintains two figures:
%     1. Per-lag view of selectedChannel (figData.fig + figData.hImages)
%        - nAxes = 1: single row of nLags heatmaps (achromatic / sparse)
%        - nAxes = 3: three rows (L-M, S, achromatic) of nLags heatmaps
%          (chromatic). figData.hImages is [3 x nLags] in this case;
%          figData.hAxes likewise.
%     2. Grid view of ALL channels at each channel's peak-energy lag
%        (secondary figure, auto-created on first call). For nAxes = 3
%        the grid shows the achromatic axis (3rd of 3) at peak lag.
%
%   nAxes = 1 active for denseAchromatic and sparse (Phase 1).
%   nAxes = 3 active for denseChromatic (Phase 2).

persistent hAllFig hAllAxes hAllImg hAllTxt nChPersist nAxesPersist

if nargin < 4 || isempty(selectedChannel), selectedChannel = 1; end
if nargin < 5 || isempty(nAxes),            nAxes = 1; end

if nAxes ~= 1 && nAxes ~= 3
    error('plotSTA_spatial:nAxesUnsupported', ...
        'nAxes = %d not supported. Use 1 (achro/sparse) or 3 (chromatic).', ...
        nAxes);
end

%% ---- Primary figure: selected channel, all lags ----
if isvalid(figData.fig) && staSpikeCount(selectedChannel) >= 1
    ch = selectedChannel;
    sta = staAccum{ch} / staSpikeCount(ch);    % [nY, nX, nLags] or [nY, nX, 3, nLags]

    if nAxes == 1
        cMax = max(abs(sta(:)));
        if cMax == 0, cMax = 1; end
        for k = 1:figData.nLags
            set(figData.hImages(k), 'CData', sta(:, :, k));
            set(figData.hAxes(k), 'CLim', [-cMax, cMax]);
        end
    else
        % Per-axis color limits so a strong axis doesn't compress the
        % display of a weaker one.
        for axisIdx = 1:3
            slice3D = sta(:, :, axisIdx, :);
            cMax = max(abs(slice3D(:)));
            if cMax == 0, cMax = 1; end
            for k = 1:figData.nLags
                set(figData.hImages(axisIdx, k), 'CData', sta(:, :, axisIdx, k));
                set(figData.hAxes(axisIdx, k), 'CLim', [-cMax, cMax]);
            end
        end
    end
    set(figData.hChanText,  'String', sprintf('Channel: %d', ch));
    set(figData.hSpikeText, 'String', sprintf('Spikes: %d', staSpikeCount(ch)));
end

%% ---- Secondary figure: all channels, peak lag each ----
nCh = length(staAccum);

if nCh == 32
    nRows = 4; nCols = 8;
else
    nCols = ceil(sqrt(nCh));
    nRows = ceil(nCh / nCols);
end

if isempty(hAllFig) || ~isvalid(hAllFig) || ...
        nChPersist ~= nCh || nAxesPersist ~= nAxes
    if ~isempty(hAllFig) && isvalid(hAllFig), close(hAllFig); end
    figName = 'STA - All Channels (peak lag)';
    if nAxes == 3, figName = [figName ' [Achro axis]']; end
    hAllFig = figure('Name', figName, ...
        'NumberTitle', 'off', 'Position', [50 50 1400 700], 'Color', 'w');
    hAllAxes = gobjects(1, nCh);
    hAllImg  = gobjects(1, nCh);
    hAllTxt  = gobjects(1, nCh);
    for ch = 1:nCh
        hAllAxes(ch) = subplot(nRows, nCols, ch);
        hAllImg(ch)  = imagesc(zeros(2));
        axis image; axis off;
        colormap(hAllAxes(ch), figData.bwrMap);
        hAllTxt(ch) = title(sprintf('ch%d: 0', ch), 'FontSize', 8);
    end
    nChPersist   = nCh;
    nAxesPersist = nAxes;
end

frameDurMs = 30;
if isfield(figData, 'hAxes') && size(figData.hAxes, 2) >= 2
    % hAxes(1, 2) is the lag-2 panel of the first axis row in both
    % layouts (1xnLags and 3xnLags); titles are set there.
    probeAxis = figData.hAxes(1, 2);
    if isvalid(probeAxis)
        t = get(get(probeAxis, 'Title'), 'String');
        v = sscanf(t, '%d');
        if ~isempty(v), frameDurMs = v; end
    end
end

for ch = 1:nCh
    if staSpikeCount(ch) < 1, continue; end
    sta = staAccum{ch} / staSpikeCount(ch);

    if nAxes == 1
        lagEnergy = squeeze(sum(sum(sta.^2, 1), 2));
        [~, peakLag] = max(lagEnergy);
        slice = sta(:, :, peakLag);
    else
        % Pick the (axis, lag) cell with peak energy across the spatial
        % grid. Display that cell's spatial map (so the grid view
        % shows whichever DKL axis is most strongly tuned).
        energy = squeeze(sum(sum(sta.^2, 1), 2));   % [3, nLags]
        [~, idx] = max(energy(:));
        [peakAxis, peakLag] = ind2sub(size(energy), idx);
        slice = sta(:, :, peakAxis, peakLag);
    end

    cMax = max(abs(slice(:)));
    if cMax == 0, cMax = 1; end
    set(hAllImg(ch),  'CData', slice);
    set(hAllAxes(ch), 'CLim', [-cMax, cMax]);
    if nAxes == 1
        set(hAllTxt(ch),  'String', sprintf('ch%d: %d (%dms)', ...
            ch, staSpikeCount(ch), (peakLag - 1) * frameDurMs));
    else
        axisLabels = {'LM','S','A'};
        set(hAllTxt(ch),  'String', sprintf('ch%d: %d %s@%dms', ...
            ch, staSpikeCount(ch), axisLabels{peakAxis}, ...
            (peakLag - 1) * frameDurMs));
    end
end

drawnow;

end
