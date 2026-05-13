function figData = initBarsweepRFDisplay(p)
% figData = initBarsweepRFDisplay(p)
%
% Create the online RF detail figure and cache plotting handles. Called
% once from barsweep_init.m. Layout differs by regime:
%
%   barsweep_rfmap12 -> single 2D image axis (FBP) for the selected
%                       channel.
%   barsweep_cardinal4 -> 1x3 row of (rate-vs-x, rate-vs-y, separable-2D
%                         thumbnail) for the selected channel.
%
% The cross-channel grid that used to live in this figure was replaced
% by the per-channel browser uifigure created by
% initBarsweepChannelBrowser; plotBarsweepRF drives it via
% updateBarsweepChannelBrowser.

rf = p.init.barsweepRF;
nCh = rf.nChannels;

% Blue-white-red diverging colormap (shared across both regimes).
nColors = 256;
half = nColors / 2;
r = [linspace(0, 1, half), ones(1, half)]';
g = [linspace(0, 1, half), linspace(1, 0, half)]';
b = [ones(1, half), linspace(1, 0, half)]';
bwrMap = [r, g, b];

fig = figure('Name', sprintf('Online barsweep RF detail (%s)', rf.exptType), ...
    'NumberTitle', 'off', ...
    'Position', [50 450 1500 450], ...
    'Color', 'w');

% Detail-panel layout occupies the entire figure now (the all-channels
% grid moved to a separate uifigure browser).
detailRows = 1;
gridRows   = 0;
nGridCols  = 6;
nRowsTotal = detailRows;

figData.fig          = fig;
figData.bwrMap       = bwrMap;
figData.exptType     = rf.exptType;
figData.nChannels    = nCh;
figData.nGridCols    = nGridCols;
figData.detailRows   = detailRows;
figData.gridRows     = gridRows;
figData.nRowsTotal   = nRowsTotal;

%% Detail panel
switch rf.exptType
    case 'barsweep_rfmap12'
        ax = subplot(nRowsTotal, nGridCols, 1:nGridCols*detailRows);
        figData.detailImg = imagesc(zeros(2));
        axis(ax, 'image'); axis(ax, 'xy');
        colormap(ax, bwrMap);
        figData.detailAx = ax;
        figData.detailTitle = title(ax, 'awaiting trial...', ...
            'Interpreter', 'none');
        xlabel(ax, 'x (dva)'); ylabel(ax, 'y (dva)');
        hold(ax, 'on');
        figData.detailCrosshairX = plot(ax, [0 0], [0 0], 'k--', ...
            'LineWidth', 1);
        figData.detailCrosshairY = plot(ax, [0 0], [0 0], 'k--', ...
            'LineWidth', 1);
        figData.detailZeroContour = [];   % drawn lazily on first refresh
        hold(ax, 'off');

    case 'barsweep_cardinal4'
        % Three sub-axes laid out in a 1x3 row inside the top half.
        % We carve the top half into 3 column groups.
        cellsPerCol = nGridCols / 3;
        if cellsPerCol ~= round(cellsPerCol)
            error('initBarsweepRFDisplay: nGridCols must be divisible by 3 for cardinal4 layout.');
        end
        idxX   = 1 : cellsPerCol;
        idxY   = cellsPerCol + (1 : cellsPerCol);
        idxSep = 2*cellsPerCol + (1 : cellsPerCol);
        % Span both detail rows.
        spanCols = @(idx) reshape(((1:detailRows)' - 1) * nGridCols + idx, 1, []);

        axX = subplot(nRowsTotal, nGridCols, spanCols(idxX));
        figData.detailLineX = plot(axX, NaN, NaN, 'b-', 'LineWidth', 1.2);
        hold(axX, 'on');
        figData.detailMarkerX = plot(axX, NaN, NaN, 'ro', ...
            'MarkerSize', 6, 'LineWidth', 1.2);
        figData.detailVlineX = plot(axX, [0 0], [0 1], 'k--');
        hold(axX, 'off');
        title(axX, 'rate vs x (vertical bars)');
        xlabel(axX, 'x (dva)'); ylabel(axX, 'rate (sp/s)');
        figData.detailAxX = axX;

        axY = subplot(nRowsTotal, nGridCols, spanCols(idxY));
        figData.detailLineY = plot(axY, NaN, NaN, 'b-', 'LineWidth', 1.2);
        hold(axY, 'on');
        figData.detailMarkerY = plot(axY, NaN, NaN, 'ro', ...
            'MarkerSize', 6, 'LineWidth', 1.2);
        figData.detailVlineY = plot(axY, [0 0], [0 1], 'k--');
        hold(axY, 'off');
        title(axY, 'rate vs y (horizontal bars)');
        xlabel(axY, 'y (dva)'); ylabel(axY, 'rate (sp/s)');
        figData.detailAxY = axY;

        axSep = subplot(nRowsTotal, nGridCols, spanCols(idxSep));
        figData.detailSepImg = imagesc(axSep, zeros(2));
        axis(axSep, 'image'); axis(axSep, 'xy');
        colormap(axSep, bwrMap);
        title(axSep, 'sep. estimate (cardinal4)');
        xlabel(axSep, 'x (dva)'); ylabel(axSep, 'y (dva)');
        hold(axSep, 'on');
        figData.detailSepCrossX = plot(axSep, [0 0], [0 0], 'k--');
        figData.detailSepCrossY = plot(axSep, [0 0], [0 0], 'k--');
        hold(axSep, 'off');
        figData.detailAxSep = axSep;

        % Banner-text axis spans the title strip (drawn into axX's title
        % for now; banner text uses the figure name for visibility).
        figData.detailTitle = [];

    otherwise
        error('initBarsweepRFDisplay: unknown exptType "%s".', rf.exptType);
end

% The all-channels grid is now a separate uifigure browser created by
% initBarsweepChannelBrowser; legacy grid* handle fields are no longer
% allocated here. plotBarsweepRF iterates through the browser instead.

% Suppress the stale-figure warning by drawing once now.
drawnow;

end
