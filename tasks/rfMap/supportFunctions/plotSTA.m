function plotSTA(figData, staAccum, staSpikeCount, selectedChannel)
% plotSTA  Update the online STA display with current accumulator data.
%
%   plotSTA(figData, staAccum, staSpikeCount, selectedChannel)
%
%   Maintains two figures:
%     1. Per-lag view of selectedChannel (the original figData figure)
%     2. Grid view of ALL channels at each channel's peak-energy lag
%        (secondary figure, auto-created on first call)

persistent hAllFig hAllAxes hAllImg hAllTxt nChPersist

if nargin < 4, selectedChannel = 1; end

%% ---- Primary figure: selected channel, all lags ----
if isvalid(figData.fig) && staSpikeCount(selectedChannel) >= 1
    ch = selectedChannel;
    sta = staAccum{ch} / staSpikeCount(ch);
    cMax = max(abs(sta(:)));
    if cMax == 0, cMax = 1; end
    for k = 1:figData.nLags
        set(figData.hImages(k), 'CData', sta(:, :, k));
        set(figData.hAxes(k), 'CLim', [-cMax, cMax]);
    end
    set(figData.hChanText,  'String', sprintf('Channel: %d', ch));
    set(figData.hSpikeText, 'String', sprintf('Spikes: %d', staSpikeCount(ch)));
end

%% ---- Secondary figure: all channels, peak lag each ----
nCh = length(staAccum);

% Choose grid layout
if nCh == 32
    nRows = 4; nCols = 8;
else
    nCols = ceil(sqrt(nCh));
    nRows = ceil(nCh / nCols);
end

% (Re)create figure if needed
if isempty(hAllFig) || ~isvalid(hAllFig) || nChPersist ~= nCh
    hAllFig = figure('Name', 'STA - All Channels (peak lag)', ...
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
    nChPersist = nCh;
end

% Noise frame duration (ms) for lag labels. figData.hAxes(k) title is
% "<lagMs> ms", so frame duration = title value at k=2.
frameDurMs = 30;  % default; override if we can read it from figData
if isfield(figData, 'hAxes') && numel(figData.hAxes) >= 2 && isvalid(figData.hAxes(2))
    t = get(get(figData.hAxes(2), 'Title'), 'String');
    v = sscanf(t, '%d');
    if ~isempty(v), frameDurMs = v; end
end

% Update each channel's panel with its peak-energy lag slice
for ch = 1:nCh
    if staSpikeCount(ch) < 1, continue; end
    sta = staAccum{ch} / staSpikeCount(ch);
    lagEnergy = squeeze(sum(sum(sta.^2, 1), 2));
    [~, peakLag] = max(lagEnergy);
    slice = sta(:, :, peakLag);
    cMax = max(abs(slice(:)));
    if cMax == 0, cMax = 1; end
    set(hAllImg(ch),  'CData', slice);
    set(hAllAxes(ch), 'CLim', [-cMax, cMax]);
    set(hAllTxt(ch),  'String', sprintf('ch%d: %d (%dms)', ...
        ch, staSpikeCount(ch), (peakLag - 1) * frameDurMs));
end

drawnow;

end
