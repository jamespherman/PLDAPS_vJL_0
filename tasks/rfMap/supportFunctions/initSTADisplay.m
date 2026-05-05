function figData = initSTADisplay(nLags, nChannels, noiseFrameDurMs, nAxes)
% initSTADisplay  Create the online STA display figure.
%
%   figData = initSTADisplay(nLags, nChannels, noiseFrameDurMs, nAxes)
%
%   Layouts:
%     nAxes = 1 (default; denseAchromatic, sparse):
%       - Top region: 1 row x nLags heatmap subplots showing the STA
%         at each temporal lag. figData.hImages and figData.hAxes are
%         row vectors of length nLags.
%     nAxes = 3 (denseChromatic):
%       - Top region: 3 rows x nLags heatmap subplots. Rows are DKL
%         axes 1=L-M (top), 2=S (middle), 3=Achromatic (bottom).
%         figData.hImages and figData.hAxes are [3 x nLags].
%
%   Color scale per panel is symmetric around zero (blue-white-red).
%
%   Inputs:
%     nLags           - number of temporal lags
%     nChannels       - number of recording channels
%     noiseFrameDurMs - noise frame duration in ms (for lag labels)
%     nAxes           - 1 (achro/sparse) or 3 (chromatic). Default 1.
%
%   Returns:
%     figData - struct with figure/axes handles for plotSTA to update:
%       .fig          - figure handle
%       .hAxes        - [nAxes x nLags] axes handles for heatmaps
%       .hImages      - [nAxes x nLags] image handles
%       .hChanText    - text handle for channel display
%       .hSpikeText   - text handle for spike count display
%       .bwrMap       - blue-white-red colormap matrix
%       .nLags        - number of lags
%       .nChannels    - number of channels
%       .nAxes        - number of DKL axes (1 or 3)

if nargin < 3 || isempty(noiseFrameDurMs), noiseFrameDurMs = 30; end
if nargin < 4 || isempty(nAxes),           nAxes           = 1;  end

if nAxes ~= 1 && nAxes ~= 3
    error('initSTADisplay:nAxesUnsupported', ...
        'nAxes = %d not supported. Use 1 (achro/sparse) or 3 (chromatic).', ...
        nAxes);
end

% Create figure (taller for 3-axis chromatic)
figHeight = 400;
if nAxes == 3, figHeight = 800; end
figName = 'Online STA Display';
if nAxes == 3, figName = 'Online STA Display - Chromatic (LM / S / Achro)'; end
fig = figure('Name', figName, ...
    'NumberTitle', 'off', ...
    'Position', [50 400 1500 figHeight], ...
    'Color', 'w');

% Blue-white-red diverging colormap
nColors = 256;
half = nColors / 2;
r = [linspace(0, 1, half), ones(1, half)]';
g = [linspace(0, 1, half), linspace(1, 0, half)]';
b = [ones(1, half), linspace(1, 0, half)]';
bwrMap = [r, g, b];

% Subplot grid: nAxes rows for heatmaps + 1 row for info text. Use the
% same nLags-column grid throughout.
totalRows = nAxes + 1;

hAxes   = gobjects(nAxes, nLags);
hImages = gobjects(nAxes, nLags);

axisLabels = {'L-M', 'S', 'Achro'};

for axisIdx = 1:nAxes
    for k = 1:nLags
        hAxes(axisIdx, k) = subplot(totalRows, nLags, ...
            (axisIdx - 1) * nLags + k);
        hImages(axisIdx, k) = imagesc(zeros(2));
        axis image; axis off;
        colormap(hAxes(axisIdx, k), bwrMap);
        if axisIdx == 1
            lagMs = (k - 1) * noiseFrameDurMs;
            title(sprintf('%d ms', lagMs), 'FontSize', 9);
        end
        if k == 1 && nAxes == 3
            % Row label on the leftmost panel of each row
            ylabel(axisLabels{axisIdx}, 'Visible', 'on', ...
                'FontSize', 11, 'FontWeight', 'bold');
        end
    end
end

% Bottom row: channel and spike info, plus a colorbar legend.
infoHalf = ceil(nLags / 2);
hInfoAxes = subplot(totalRows, nLags, ...
    nAxes * nLags + 1 : nAxes * nLags + infoHalf); %#ok<NASGU>
axis off;
hChanText  = text(0.05, 0.6, 'Channel: 1', ...
    'FontSize', 12, 'FontWeight', 'bold', 'Units', 'normalized');
hSpikeText = text(0.05, 0.1, 'Spikes: 0', ...
    'FontSize', 12, 'Units', 'normalized');

hCbAxes = subplot(totalRows, nLags, ...
    nAxes * nLags + infoHalf + 1 : (nAxes + 1) * nLags); %#ok<NASGU>
axis off;
text(0.05, 0.6, 'Blue = below mean', 'FontSize', 10, ...
    'Color', [0 0 0.8], 'Units', 'normalized');
text(0.05, 0.1, 'Red = above mean', 'FontSize', 10, ...
    'Color', [0.8 0 0], 'Units', 'normalized');

% For the achromatic / sparse layout, plotSTA_spatial expects hImages
% and hAxes to be 1D-indexable. Reshape down to a row vector when nAxes
% is 1 so old call sites that used hImages(k) keep working.
if nAxes == 1
    hAxes   = reshape(hAxes,   1, nLags);
    hImages = reshape(hImages, 1, nLags);
end

% Package handles
figData.fig         = fig;
figData.hAxes       = hAxes;
figData.hImages     = hImages;
figData.hChanText   = hChanText;
figData.hSpikeText  = hSpikeText;
figData.bwrMap      = bwrMap;
figData.nLags       = nLags;
figData.nChannels   = nChannels;
figData.nAxes       = nAxes;

end
