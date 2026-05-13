function bd = initChannelBrowser(nCh, tileKind, opts)
% pds.initChannelBrowser  Per-channel RF browser uifigure.
%
%   bd = pds.initChannelBrowser(nCh, tileKind, opts)
%
%   Creates a uifigure with a left-hand control column (channel listbox,
%   compact range-syntax editor, select-all/deselect-all buttons,
%   per-channel <-> global CLim toggle) and a right-hand grid of nCh
%   pre-allocated tile panels. Each panel contains either:
%     'image+line' : a top imagesc axes + a shorter (1/4 height) line
%                    axes with a peak marker. Used by rfMap (image is
%                    the peak-lag spatial slice; line is power vs lag).
%     'image'      : a single imagesc axes only. Used by barsweep
%                    (image is the FBP or separable-2D RF estimate).
%
%   The PSTH_plotter pattern is used for layout: nCols = ceil(sqrt(n)),
%   nRows = ceil(n/nCols); each visible panel sits in one cell of a 1x
%   uigridlayout. Panels are pre-allocated once and never destroyed --
%   selection changes only toggle Visible and reassign Layout.Row/Column.
%
%   Inputs:
%     nCh      - total number of channels (size of the panel pool)
%     tileKind - 'image+line' | 'image'
%     opts     - struct of optional fields:
%       .figName       - figure window title
%       .imgXLabel     - x-axis label for the image axes
%       .imgYLabel     - y-axis label for the image axes
%       .lineXLabel    - x-axis label for the line axes (image+line)
%       .lineYLabel    - y-axis label for the line axes (image+line)
%       .colormap      - Nx3 matrix; default = blue-white-red diverging
%       .initialSelection - vector of channels to show initially (default 1:nCh)
%       .climMode      - 'per-channel' (default) or 'global'
%       .figPos        - 1x4 figure Position
%
%   Returns bd struct (the "browser data") with handle bookkeeping:
%     .fig, .mainGl, .leftPanel, .rightGl
%     .listbox, .rangeEdit, .selectAllBtn, .deselectAllBtn
%     .climToggle              - matlab.ui.control.StateButton
%     .panels(1, nCh)          - per-channel uipanel handles
%     .imgAx(1, nCh)           - image axes per panel
%     .imgObj(1, nCh)          - image (Surface) object per panel
%     .lineAx(1, nCh)          - line axes per panel (image+line only)
%     .lineObj(1, nCh)         - line object (image+line only)
%     .markerObj(1, nCh)       - peak marker (image+line only)
%     .titleObj(1, nCh)        - title text inside each panel
%     .nChannels               - mirror of nCh
%     .tileKind                - mirror of tileKind
%     .selectedChannels        - current selection (vector, sorted)
%     .climMode                - 'per-channel' | 'global'
%     .colormap                - colormap matrix
%
%   Callbacks installed by this function are self-contained: they read
%   and write bd via the figure's UserData slot, so a caller does not
%   need to forward selection-change events. The returned bd is also
%   what the caller passes to the per-task update routine each trial.

if nargin < 3 || isempty(opts), opts = struct(); end
opts = setDefault(opts, 'figName',          'Channel browser');
opts = setDefault(opts, 'imgXLabel',        '');
opts = setDefault(opts, 'imgYLabel',        '');
opts = setDefault(opts, 'lineXLabel',       'lag');
opts = setDefault(opts, 'lineYLabel',       'power');
opts = setDefault(opts, 'colormap',         bluewhitered(256));
opts = setDefault(opts, 'initialSelection', 1:min(nCh, 16));
opts = setDefault(opts, 'climMode',         'per-channel');
opts = setDefault(opts, 'figPos',           [60 60 1500 850]);

validKinds = {'image+line', 'image'};
if ~ismember(tileKind, validKinds)
    error('pds:initChannelBrowser:badTileKind', ...
        'tileKind must be one of: %s. Got "%s".', ...
        strjoin(validKinds, ', '), tileKind);
end

%% --- Figure shell ---------------------------------------------------
fig = uifigure( ...
    'Name',         opts.figName, ...
    'Position',     opts.figPos, ...
    'Color',        [1 1 1]);

mainGl = uigridlayout(fig);
mainGl.ColumnWidth   = {220, '1x'};
mainGl.RowHeight     = {'1x'};
mainGl.Padding       = [4 4 4 4];
mainGl.ColumnSpacing = 4;
mainGl.BackgroundColor = [1 1 1];

%% --- Left-hand control column --------------------------------------
leftPanel = uipanel(mainGl, ...
    'Title',           'Channels', ...
    'BackgroundColor', [1 1 1]);
leftPanel.Layout.Row    = 1;
leftPanel.Layout.Column = 1;

leftGl = uigridlayout(leftPanel);
leftGl.ColumnWidth   = {'1x', '1x'};
% rows: listbox, range label, range edit, selectAll/deselectAll buttons,
%       clim toggle, spacer.
leftGl.RowHeight     = {'1x', 18, 28, 28, 28, 28};
leftGl.RowSpacing    = 4;
leftGl.Padding       = [4 4 4 4];
leftGl.BackgroundColor = [1 1 1];

% Listbox with one entry per channel.
chanLabels = arrayfun(@(k) sprintf('ch %d', k), 1:nCh, 'UniformOutput', false);
listbox = uilistbox(leftGl, ...
    'Items',         chanLabels, ...
    'ItemsData',     1:nCh, ...
    'Multiselect',   'on', ...
    'Value',         opts.initialSelection);
listbox.Layout.Row    = 1;
listbox.Layout.Column = [1 2];

rangeLbl = uilabel(leftGl, 'Text', 'Range (e.g. 1-16, 33):');
rangeLbl.Layout.Row    = 2;
rangeLbl.Layout.Column = [1 2];

rangeEdit = uieditfield(leftGl, 'text', ...
    'Value', pds.formatChannelRange(opts.initialSelection));
rangeEdit.Layout.Row    = 3;
rangeEdit.Layout.Column = [1 2];

selectAllBtn = uibutton(leftGl, 'push', 'Text', 'Select all');
selectAllBtn.Layout.Row    = 4;
selectAllBtn.Layout.Column = 1;

deselectAllBtn = uibutton(leftGl, 'push', 'Text', 'Deselect all');
deselectAllBtn.Layout.Row    = 4;
deselectAllBtn.Layout.Column = 2;

climToggle = uibutton(leftGl, 'state', ...
    'Text',  'CLim: per-channel', ...
    'Value', strcmp(opts.climMode, 'global'));
climToggle.Layout.Row    = 5;
climToggle.Layout.Column = [1 2];
% Cosmetic: when Value=true, label changes to "global" so the user
% sees the *current* mode rather than the action.
syncClimLabel(climToggle);

%% --- Right-hand panel grid ----------------------------------------
rightPanelHost = uipanel(mainGl, ...
    'BorderType',      'none', ...
    'BackgroundColor', [1 1 1]);
rightPanelHost.Layout.Row    = 1;
rightPanelHost.Layout.Column = 2;

rightGl = uigridlayout(rightPanelHost);
rightGl.ColumnWidth    = {'1x'};
rightGl.RowHeight      = {'1x'};
rightGl.Padding        = [2 2 2 2];
rightGl.ColumnSpacing  = 2;
rightGl.RowSpacing     = 2;
rightGl.BackgroundColor = [1 1 1];

%% --- Pre-allocate per-channel tile panels --------------------------
panels   = gobjects(1, nCh);
imgAx    = gobjects(1, nCh);
imgObj   = gobjects(1, nCh);
lineAx   = gobjects(1, nCh);
lineObj  = gobjects(1, nCh);
markerObj = gobjects(1, nCh);
titleObj = gobjects(1, nCh);

for ch = 1:nCh
    pn = uipanel(rightGl, ...
        'BorderType',      'line', ...
        'BackgroundColor', [1 1 1], ...
        'Visible',         'off');
    pn.Layout.Row    = 1;   % real position assigned by updateChannelBrowserLayout
    pn.Layout.Column = 1;

    panels(ch) = pn;

    pnGl = uigridlayout(pn);
    pnGl.ColumnWidth    = {'1x'};
    pnGl.Padding        = [2 2 2 2];
    pnGl.RowSpacing     = 1;
    pnGl.BackgroundColor = [1 1 1];

    % Title strip at the very top (small height); image fills middle;
    % line at bottom (only for image+line).
    switch tileKind
        case 'image+line'
            pnGl.RowHeight = {12, '3x', '1x'};
        case 'image'
            pnGl.RowHeight = {12, '1x'};
    end

    titleObj(ch) = uilabel(pnGl, ...
        'Text',                sprintf('ch %d', ch), ...
        'HorizontalAlignment', 'left', ...
        'FontSize',            9);
    titleObj(ch).Layout.Row    = 1;
    titleObj(ch).Layout.Column = 1;

    ax1 = uiaxes(pnGl);
    ax1.Layout.Row    = 2;
    ax1.Layout.Column = 1;
    ax1.Toolbar.Visible = 'off';
    disableDefaultInteractions(ax1);
    set(ax1, 'XTick', [], 'YTick', [], 'Box', 'on');
    colormap(ax1, opts.colormap);
    if ~isempty(opts.imgXLabel), xlabel(ax1, opts.imgXLabel, 'FontSize', 7); end
    if ~isempty(opts.imgYLabel), ylabel(ax1, opts.imgYLabel, 'FontSize', 7); end

    img = imagesc(ax1, zeros(2));
    axis(ax1, 'image');
    axis(ax1, 'xy');
    imgAx(ch)  = ax1;
    imgObj(ch) = img;

    if strcmp(tileKind, 'image+line')
        ax2 = uiaxes(pnGl);
        ax2.Layout.Row    = 3;
        ax2.Layout.Column = 1;
        ax2.Toolbar.Visible = 'off';
        disableDefaultInteractions(ax2);
        set(ax2, 'Box', 'on', 'FontSize', 7);
        if ~isempty(opts.lineXLabel), xlabel(ax2, opts.lineXLabel, 'FontSize', 7); end
        if ~isempty(opts.lineYLabel), ylabel(ax2, opts.lineYLabel, 'FontSize', 7); end
        hold(ax2, 'on');
        ln = plot(ax2, NaN, NaN, 'k-', 'LineWidth', 1);
        mk = plot(ax2, NaN, NaN, 'rx', 'MarkerSize', 8, 'LineWidth', 1.2);
        hold(ax2, 'off');
        lineAx(ch)    = ax2;
        lineObj(ch)   = ln;
        markerObj(ch) = mk;
    end
end

%% --- Pack bd struct ------------------------------------------------
bd.fig             = fig;
bd.mainGl          = mainGl;
bd.leftPanel       = leftPanel;
bd.rightGl         = rightGl;
bd.listbox         = listbox;
bd.rangeEdit       = rangeEdit;
bd.selectAllBtn    = selectAllBtn;
bd.deselectAllBtn  = deselectAllBtn;
bd.climToggle      = climToggle;
bd.panels          = panels;
bd.imgAx           = imgAx;
bd.imgObj          = imgObj;
bd.lineAx          = lineAx;
bd.lineObj         = lineObj;
bd.markerObj       = markerObj;
bd.titleObj        = titleObj;
bd.nChannels       = nCh;
bd.tileKind        = tileKind;
bd.selectedChannels = sort(unique(opts.initialSelection(:)'));
if climToggle.Value
    bd.climMode = 'global';
else
    bd.climMode = 'per-channel';
end
bd.colormap        = opts.colormap;

% Stash bd on the figure so callbacks can mutate selection state.
fig.UserData = bd;

% Wire callbacks now that bd is on the figure.
listbox.ValueChangedFcn        = @(src, evt) onListboxChange(src, evt);
rangeEdit.ValueChangedFcn      = @(src, evt) onRangeChange(src, evt);
selectAllBtn.ButtonPushedFcn   = @(src, evt) onSelectAll(src, evt);
deselectAllBtn.ButtonPushedFcn = @(src, evt) onDeselectAll(src, evt);
climToggle.ValueChangedFcn     = @(src, evt) onClimToggle(src, evt);

% Initial layout for the default selection.
bd = pds.updateChannelBrowserLayout(bd);
fig.UserData = bd;

end


%% ===================== local functions =============================

function opts = setDefault(opts, name, value)
if ~isfield(opts, name) || isempty(opts.(name))
    opts.(name) = value;
end
end


function cmap = bluewhitered(n)
half = floor(n / 2);
r = [linspace(0, 1, half), ones(1, n - half)]';
g = [linspace(0, 1, half), linspace(1, 0, n - half)]';
b = [ones(1, half), linspace(1, 0, n - half)]';
cmap = [r, g, b];
end


function disableDefaultInteractions(ax)
% uiaxes ship with pan/zoom/datatip toolbars and rulers that flicker on
% every CData write. Strip them for a static-display use case.
try
    ax.Interactions = [];
catch
end
try
    disableDefaultInteractivity(ax);
catch
end
end


function syncClimLabel(toggle)
if toggle.Value
    toggle.Text = 'CLim: global';
else
    toggle.Text = 'CLim: per-channel';
end
end


function onListboxChange(src, ~)
fig = ancestor(src, 'figure');
bd  = fig.UserData;
sel = src.Value;
if iscell(sel)
    sel = cell2mat(sel);
end
bd.selectedChannels = sort(unique(sel(:)'));
bd.rangeEdit.Value  = pds.formatChannelRange(bd.selectedChannels);
bd = pds.updateChannelBrowserLayout(bd);
fig.UserData = bd;
end


function onRangeChange(src, ~)
fig = ancestor(src, 'figure');
bd  = fig.UserData;
sel = pds.parseChannelRange(src.Value, bd.nChannels);
bd.selectedChannels = sel;
bd.listbox.Value    = sel;
% Re-canonicalise the text the user typed so it matches the listbox.
src.Value = pds.formatChannelRange(sel);
bd = pds.updateChannelBrowserLayout(bd);
fig.UserData = bd;
end


function onSelectAll(src, ~)
fig = ancestor(src, 'figure');
bd  = fig.UserData;
sel = 1:bd.nChannels;
bd.selectedChannels = sel;
bd.listbox.Value    = sel;
bd.rangeEdit.Value  = pds.formatChannelRange(sel);
bd = pds.updateChannelBrowserLayout(bd);
fig.UserData = bd;
end


function onDeselectAll(src, ~)
fig = ancestor(src, 'figure');
bd  = fig.UserData;
bd.selectedChannels = [];
% uilistbox refuses an empty Value when Multiselect='on' is paired with
% items present; setting to a length-zero numeric is the supported way.
bd.listbox.Value    = zeros(0, 1);
bd.rangeEdit.Value  = '';
bd = pds.updateChannelBrowserLayout(bd);
fig.UserData = bd;
end


function onClimToggle(src, ~)
fig = ancestor(src, 'figure');
bd  = fig.UserData;
syncClimLabel(src);
if src.Value
    bd.climMode = 'global';
else
    bd.climMode = 'per-channel';
end
fig.UserData = bd;
% No layout change; the next per-task update applies the new CLim policy.
end
