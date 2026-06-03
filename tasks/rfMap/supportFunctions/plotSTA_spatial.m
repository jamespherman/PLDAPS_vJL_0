function plotSTA_spatial(figData, staAccum, staSpikeCount, ...
    selectedChannel, nAxes)
% plotSTA_spatial  Render online STA spatial map for dense / sparse / chromatic.
%
%   plotSTA_spatial(figData, staAccum, staSpikeCount, selectedChannel, nAxes)
%
%   Renders the per-lag detail view of selectedChannel into
%   figData.fig + figData.hImages:
%     - nAxes = 1: single row of nLags heatmaps (achromatic / sparse)
%     - nAxes = 3: three rows (L-M, S, achromatic) of nLags heatmaps
%       (chromatic). figData.hImages is [3 x nLags] in this case;
%       figData.hAxes likewise.
%
%   The cross-channel "all channels at peak lag" grid that used to live
%   here was replaced by the per-channel browser uifigure created via
%   initSTAChannelBrowser; rfMap_finish.m drives it through
%   updateSTAChannelBrowser.
%
%   nAxes = 1 active for denseAchromatic and sparse (Phase 1).
%   nAxes = 3 active for denseChromatic (Phase 2).

if nargin < 4 || isempty(selectedChannel), selectedChannel = 1; end
if nargin < 5 || isempty(nAxes),            nAxes = 1; end

if nAxes ~= 1 && nAxes ~= 3
    error('plotSTA_spatial:nAxesUnsupported', ...
        'nAxes = %d not supported. Use 1 (achro/sparse) or 3 (chromatic).', ...
        nAxes);
end

%% ---- Primary figure: selected channel, all lags ----
if isvalid(figData.fig) && max(staSpikeCount(selectedChannel, :)) >= 1
    ch = selectedChannel;
    counts = max(staSpikeCount(ch, :), 1);
    nd = ndims(staAccum{ch});
    shp = ones(1, nd);
    shp(nd) = numel(counts);
    sta = staAccum{ch} ./ reshape(counts, shp);

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
    set(figData.hSpikeText, 'String', sprintf('Spikes: %d', staSpikeCount(ch, 1)));
end

drawnow;

end
