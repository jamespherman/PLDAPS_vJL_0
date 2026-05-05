function figData = initSTADisplay_checkerboard( ...
    nLags, nChannels, frameDurMs, nCheckSize, nContrast, ...
    checkSizesDva, checkContrasts)
% initSTADisplay_checkerboard  Online checkerboard STA display layout.
%
%   figData = initSTADisplay_checkerboard( ...
%       nLags, nChannels, frameDurMs, nCheckSize, nContrast, ...
%       checkSizesDva, checkContrasts)
%
%   Layout for the selected channel:
%     Left block: nCheckSize x nContrast grid of temporal-kernel traces.
%                 Rows = checkSize; columns = contrast.
%     Right block: matching nCheckSize x nContrast grid of bar pairs
%                  showing F1 / F2 amplitudes (raw) for each cell.
%     Bottom: channel/spike text + F1/(F1+F2) modulation index annotation.
%
%   Returns figData with handles for plotSTA_checkerboard to update.

if nargin < 6 || isempty(checkSizesDva), checkSizesDva = (1:nCheckSize); end
if nargin < 7 || isempty(checkContrasts), checkContrasts = (1:nContrast); end

% Two side-by-side blocks. Width: nContrast cols for kernel + nContrast
% cols for F1/F2 bars + 1 col gap = 2*nContrast + 1.
gapCols   = 1;
totalCols = 2 * nContrast + gapCols;
totalRows = nCheckSize + 1;     % +1 row for text/info at bottom

fig = figure('Name', 'Online STA Display - Checkerboard', ...
    'NumberTitle', 'off', ...
    'Position', [50 200 1500 800], ...
    'Color', 'w');

hKernAxes = gobjects(nCheckSize, nContrast);
hKernLine = gobjects(nCheckSize, nContrast);
hBarAxes  = gobjects(nCheckSize, nContrast);
hBars     = gobjects(nCheckSize, nContrast);

lagTimesMs = (0:nLags-1) * frameDurMs;

for sz = 1:nCheckSize
    for ct = 1:nContrast
        % --- Kernel panel ---
        kernelCol = ct;
        kernelLin = (sz - 1) * totalCols + kernelCol;
        hKernAxes(sz, ct) = subplot(totalRows, totalCols, kernelLin);
        hKernLine(sz, ct) = plot(lagTimesMs, zeros(1, nLags), 'k-', ...
            'LineWidth', 1.2);
        hold on; plot(xlim, [0 0], 'Color', [0.7 0.7 0.7]);
        xlim([0, lagTimesMs(end) + frameDurMs]);
        ylim([-1.05, 1.05]);
        if sz == 1
            title(sprintf('c = %.2f', checkContrasts(ct)), 'FontSize', 9);
        end
        if ct == 1
            ylabel(sprintf('%.2f deg', checkSizesDva(sz)), ...
                'FontSize', 9, 'FontWeight', 'bold');
        end
        if sz < nCheckSize, set(gca, 'XTickLabel', []); end
        set(gca, 'FontSize', 7);

        % --- F1/F2 bar panel ---
        barCol = nContrast + gapCols + ct;
        barLin = (sz - 1) * totalCols + barCol;
        hBarAxes(sz, ct) = subplot(totalRows, totalCols, barLin);
        hBars(sz, ct) = bar([1, 2], [0, 0], 'FaceColor', [0.4 0.6 0.85]);
        ylim([0, 1]);
        set(gca, 'XTick', [1 2], 'XTickLabel', {'F1', 'F2'}, ...
            'FontSize', 7);
        if sz == 1 && ct == nContrast
            title('F1 / F2 amp', 'FontSize', 9);
        end
    end
end

% Bottom info row.
hInfoAxes = subplot(totalRows, totalCols, ...
    nCheckSize * totalCols + 1 : (nCheckSize + 1) * totalCols); %#ok<NASGU>
axis off;
hChanText  = text(0.02, 0.7, 'Channel: 1', ...
    'FontSize', 12, 'FontWeight', 'bold', 'Units', 'normalized');
hSpikeText = text(0.02, 0.3, 'Spikes: 0 (across all conditions)', ...
    'FontSize', 11, 'Units', 'normalized');
hModulText = text(0.50, 0.7, 'F1/(F1+F2): -- ', ...
    'FontSize', 11, 'Units', 'normalized');
hCondText  = text(0.50, 0.3, 'Trials per cond: --', ...
    'FontSize', 11, 'Units', 'normalized');

figData.fig            = fig;
figData.hKernAxes      = hKernAxes;
figData.hKernLine      = hKernLine;
figData.hBarAxes       = hBarAxes;
figData.hBars          = hBars;
figData.hChanText      = hChanText;
figData.hSpikeText     = hSpikeText;
figData.hModulText     = hModulText;
figData.hCondText      = hCondText;
figData.nLags          = nLags;
figData.nChannels      = nChannels;
figData.nCheckSize     = nCheckSize;
figData.nContrast      = nContrast;
figData.frameDurMs     = frameDurMs;
figData.checkSizesDva  = checkSizesDva;
figData.checkContrasts = checkContrasts;
figData.lagTimesMs     = lagTimesMs;

end
