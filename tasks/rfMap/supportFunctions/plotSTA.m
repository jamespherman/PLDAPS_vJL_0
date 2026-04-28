function plotSTA(figData, staAccum, staSpikeCount, selectedChannel)
% plotSTA  Update the online STA display with current accumulator data.
%
%   plotSTA(figData, staAccum, staSpikeCount, selectedChannel)
%
%   Inputs:
%     figData         - struct returned by initSTADisplay
%     staAccum        - cell array {nChannels}, each [nY, nX, nLags] double
%     staSpikeCount   - [nChannels, 1] spike counts per channel
%     selectedChannel - which channel to display (scalar index)

if nargin < 4, selectedChannel = 1; end

% Check figure is still open
if ~isvalid(figData.fig)
    return;
end

ch = selectedChannel;

% Need at least 1 spike to display
if staSpikeCount(ch) < 1
    return;
end

% Compute normalized STA for this channel
sta = staAccum{ch} / staSpikeCount(ch);

% Symmetric color scale centered on zero
cMax = max(abs(sta(:)));
if cMax == 0
    cMax = 1;  % avoid degenerate scaling
end

% Update each lag subplot
for k = 1:figData.nLags
    set(figData.hImages(k), 'CData', sta(:, :, k));
    set(figData.hAxes(k), 'CLim', [-cMax, cMax]);
end

% Update info text
set(figData.hChanText,  'String', sprintf('Channel: %d', ch));
set(figData.hSpikeText, 'String', sprintf('Spikes: %d', staSpikeCount(ch)));

drawnow;

end
