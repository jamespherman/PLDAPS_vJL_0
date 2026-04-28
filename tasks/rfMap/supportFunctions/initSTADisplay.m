function figData = initSTADisplay(nLags, nChannels, noiseFrameDurMs)
% initSTADisplay  Create the online STA display figure.
%
%   figData = initSTADisplay(nLags, nChannels, noiseFrameDurMs)
%
%   Creates a figure with:
%     - Top row: nLags heatmap subplots showing the STA at each temporal
%       lag. Color scale is symmetric around zero (blue-white-red).
%     - Bottom row: channel and spike count info.
%
%   Inputs:
%     nLags           - number of temporal lags
%     nChannels       - number of recording channels
%     noiseFrameDurMs - noise frame duration in ms (for lag labels)
%
%   Returns:
%     figData - struct with figure/axes handles for plotSTA to update:
%       .fig          - figure handle
%       .hAxes        - [1, nLags] axes handles for heatmaps
%       .hImages      - [1, nLags] image handles
%       .hChanText    - text handle for channel display
%       .hSpikeText   - text handle for spike count display
%       .bwrMap        - blue-white-red colormap matrix
%       .nLags        - number of lags
%       .nChannels    - number of channels

if nargin < 3, noiseFrameDurMs = 30; end

% Create figure
fig = figure('Name', 'Online STA Display', ...
    'NumberTitle', 'off', ...
    'Position', [50 400 1500 400], ...
    'Color', 'w');

% Blue-white-red diverging colormap
nColors = 256;
half = nColors / 2;
r = [linspace(0, 1, half), ones(1, half)]';
g = [linspace(0, 1, half), linspace(1, 0, half)]';
b = [ones(1, half), linspace(1, 0, half)]';
bwrMap = [r, g, b];

% Top row: heatmap subplots for each lag
hAxes   = gobjects(1, nLags);
hImages = gobjects(1, nLags);

for k = 1:nLags
    hAxes(k) = subplot(5, nLags, k + [0, nLags, 2*nLags]);  % span 3 rows
    hImages(k) = imagesc(zeros(2));  % placeholder
    axis image; axis off;
    colormap(hAxes(k), bwrMap);
    lagMs = (k - 1) * noiseFrameDurMs;
    title(sprintf('%d ms', lagMs), 'FontSize', 9);
end

% Bottom rows: channel and spike info
hInfoAxes = subplot(5, nLags, 4*nLags + 1 : 4*nLags + ceil(nLags/2));
axis off;
hChanText  = text(0.05, 0.6, 'Channel: 1', ...
    'FontSize', 12, 'FontWeight', 'bold', 'Units', 'normalized');
hSpikeText = text(0.05, 0.1, 'Spikes: 0', ...
    'FontSize', 12, 'Units', 'normalized');

% Colorbar label
hCbAxes = subplot(5, nLags, 4*nLags + ceil(nLags/2) + 1 : 5*nLags);
axis off;
text(0.05, 0.6, 'Blue = below mean', 'FontSize', 10, ...
    'Color', [0 0 0.8], 'Units', 'normalized');
text(0.05, 0.1, 'Red = above mean', 'FontSize', 10, ...
    'Color', [0.8 0 0], 'Units', 'normalized');

% Package handles
figData.fig         = fig;
figData.hAxes       = hAxes;
figData.hImages     = hImages;
figData.hChanText   = hChanText;
figData.hSpikeText  = hSpikeText;
figData.bwrMap      = bwrMap;
figData.nLags       = nLags;
figData.nChannels   = nChannels;

end
