function figData = initBarsweepRFDisplay(p)
% figData = initBarsweepRFDisplay(p)
%
% Create the online RF figure and cache plotting handles. Called once
% from barsweep_init.m. Layout differs by regime:
%
%   barsweep_rfmap12 -> single 2D image axis (FBP) for the selected
%                       channel + an all-channels grid below it.
%   barsweep_cardinal4 -> 1x3 row of (rate-vs-x, rate-vs-y, separable-2D
%                         thumbnail) for the selected channel + an
%                         all-channels grid showing the two 1D profiles
%                         per tile.
%
% The all-channels grid is created lazily on first plotBarsweepRF call
% (we don't know whether iradon will be cheap enough until we see the
% channel count and rig speed in practice). This file just creates the
% main figure and the detail-panel handles.

rf = p.init.barsweepRF;
nCh = rf.nChannels;

% Blue-white-red diverging colormap (shared across both regimes).
nColors = 256;
half = nColors / 2;
r = [linspace(0, 1, half), ones(1, half)]';
g = [linspace(0, 1, half), linspace(1, 0, half)]';
b = [ones(1, half), linspace(1, 0, half)]';
bwrMap = [r, g, b];

fig = figure('Name', sprintf('Online barsweep RF (%s)', rf.exptType), ...
    'NumberTitle', 'off', ...
    'Position', [50 50 1500 850], ...
    'Color', 'w');

% Detail-panel layout takes the top half (rows 1-2 of a 4x6 tiled grid).
% All-channels grid takes the bottom half (rows 3-4).
detailRows = 2;
gridRows   = 2;
nGridCols  = 6;
nRowsTotal = detailRows + gridRows;

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

%% All-channels grid: place handles, populate lazily on first refresh.
figData.gridAx  = gobjects(1, nCh);
figData.gridImg = gobjects(1, nCh);     % rfmap12 only
figData.gridLineX = gobjects(1, nCh);   % cardinal4 only
figData.gridLineY = gobjects(1, nCh);   % cardinal4 only
figData.gridTxt = gobjects(1, nCh);
gridStart = detailRows * nGridCols;
for ch = 1:nCh
    pos = gridStart + ch;
    if pos > nRowsTotal * nGridCols
        % Too many channels for our 2-row grid; expand by one row.
        % Caller can resize the figure manually if desired.
        break;
    end
    ax = subplot(nRowsTotal, nGridCols, pos);
    switch rf.exptType
        case 'barsweep_rfmap12'
            figData.gridImg(ch) = imagesc(ax, zeros(2));
            axis(ax, 'image'); axis(ax, 'xy'); axis(ax, 'off');
            colormap(ax, bwrMap);
        case 'barsweep_cardinal4'
            % Two overlaid 1D profiles per tile.
            hold(ax, 'on');
            figData.gridLineX(ch) = plot(ax, NaN, NaN, 'b-', 'LineWidth', 0.8);
            figData.gridLineY(ch) = plot(ax, NaN, NaN, 'r-', 'LineWidth', 0.8);
            hold(ax, 'off');
            ax.XTick = []; ax.YTick = [];
    end
    figData.gridTxt(ch) = title(ax, sprintf('ch%d  N=0', ch), 'FontSize', 7);
    figData.gridAx(ch) = ax;
    % Used only for cardinal4 grid axis padding; harmless for rfmap12.
    if isvalid(ax)
        if strcmp(rf.exptType, 'barsweep_cardinal4')
            xlim(ax, [rf.positionCenters(1), rf.positionCenters(end)]);
        end
    end
end

% Suppress the stale-figure warning by drawing once now.
drawnow;

end
