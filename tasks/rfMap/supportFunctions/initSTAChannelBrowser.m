function bd = initSTAChannelBrowser(nCh, nLags, noiseFrameDurMs, isChromatic, imgExtentDeg)
% initSTAChannelBrowser  Per-channel STA browser uifigure for rfMap.
%
%   bd = initSTAChannelBrowser(nCh, nLags, noiseFrameDurMs, isChromatic, imgExtentDeg)
%
%   Wraps pds.initChannelBrowser with the rfMap tile content:
%     - top axes: peak-lag spatial slice (m x n imagesc)
%     - bottom axes (1/4 height): power-vs-lag curve with red 'x' at peak
%
%   Chromatic STAs (4D: nY x nX x 3 x nLags) are collapsed to a 3D
%   "color-blind RF magnitude" tensor by per-pixel L2 norm across the
%   three DKL axes before computing the lag-energy curve and peak slice.
%   This is the standard "color-blind STA energy" convention (Field et
%   al., 2010 Nature; Chichilnisky 2001 footnote). Per-DKL-axis tuning
%   detail still lives in the existing 3-row detail panel from
%   initSTADisplay; this browser is meant for cross-channel scanning,
%   not color-axis dissection.
%
%   imgExtentDeg (optional) is forwarded to pds.initChannelBrowser to
%   pin per-tile axes box to dva (rather than pixel/check aspect).
%   Accepts a scalar (symmetric [-E, +E]) or a 1x4 vector
%   [xmin xmax ymin ymax]. Default [] keeps the legacy 'axis image'
%   behaviour.
%
%   bd is the struct returned by pds.initChannelBrowser plus:
%     .nLags           - cached lag count
%     .lagAxisMs       - 1 x nLags vector of lag values in ms
%     .isChromatic     - cached for updateSTAChannelBrowser
%     .rfCenterMarker  - 1 x nCh handles to the per-tile RF center markers
%                        ('k+'); updateSTAChannelBrowser mutates their
%                        XData/YData to NaN when no center is available.

if nargin < 5, imgExtentDeg = []; end
if nargin < 4 || isempty(isChromatic), isChromatic = false; end
if nargin < 3 || isempty(noiseFrameDurMs), noiseFrameDurMs = 30; end

opts = struct( ...
    'figName',          'rfMap STA - Channel browser', ...
    'imgXLabel',        '', ...
    'imgYLabel',        '', ...
    'lineXLabel',       'lag (ms)', ...
    'lineYLabel',       'power', ...
    'initialSelection', 1:min(nCh, 16), ...
    'climMode',         'per-channel', ...
    'figPos',           [60 60 1500 850], ...
    'imgExtentDeg',     imgExtentDeg);

bd = pds.initChannelBrowser(nCh, 'image+line', opts);

bd.nLags       = nLags;
bd.lagAxisMs   = (0:nLags - 1) * noiseFrameDurMs;
bd.isChromatic = logical(isChromatic);

% Pre-set the line axes x-data so the user sees correct ms ticks even
% before the first spike arrives. Also pre-allocate the RF center
% marker per channel (hidden at NaN until updateSTAChannelBrowser
% receives valid centers from computeRFCenters).
bd.rfCenterMarker = gobjects(1, nCh);
for ch = 1:nCh
    if isgraphics(bd.lineObj(ch))
        set(bd.lineObj(ch), 'XData', bd.lagAxisMs, ...
            'YData', zeros(1, nLags));
    end
    if isgraphics(bd.lineAx(ch))
        xlim(bd.lineAx(ch), [bd.lagAxisMs(1), bd.lagAxisMs(end) + eps]);
    end
    if isgraphics(bd.imgAx(ch))
        ax = bd.imgAx(ch);
        prevHold = ishold(ax);
        hold(ax, 'on');
        bd.rfCenterMarker(ch) = plot(ax, NaN, NaN, 'k+', ...
            'MarkerSize', 10, 'LineWidth', 1.5);
        if ~prevHold, hold(ax, 'off'); end
    end
end

% Append a "Save PDF" button below the existing left-column rows.
% leftGl rows are currently {'1x', 18, 28, 28, 28, 28}; tack on a 28-px
% row and place the button spanning both columns.
if isfield(bd, 'leftGl') && isgraphics(bd.leftGl)
    bd.leftGl.RowHeight = [bd.leftGl.RowHeight, {28}];
    newRow = numel(bd.leftGl.RowHeight);
    bd.savePdfBtn = uibutton(bd.leftGl, 'push', 'Text', 'Save PDF');
    bd.savePdfBtn.Layout.Row    = newRow;
    bd.savePdfBtn.Layout.Column = [1 2];
    bd.savePdfBtn.ButtonPushedFcn = @(src, evt) onSavePdf(src, evt);
end

bd.fig.UserData = bd;

end


function onSavePdf(src, ~)
fig = ancestor(src, 'figure');
defaultName = sprintf('sta_browser_%s.pdf', datestr(now, 'yyyymmdd_HHMMSS'));
[file, path] = uiputfile('*.pdf', 'Save STA browser as PDF', defaultName);
if isequal(file, 0), return; end
pds.pdfSave(fullfile(path, file), fig.Position(3:4) / 72, fig);
end
