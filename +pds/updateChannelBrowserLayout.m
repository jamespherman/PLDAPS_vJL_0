function bd = updateChannelBrowserLayout(bd)
% pds.updateChannelBrowserLayout  Reposition selected channel panels.
%
%   bd = pds.updateChannelBrowserLayout(bd)
%
%   Uses the bd.selectedChannels vector to choose which of the
%   pre-allocated bd.panels are shown, lays them out in a sqrt-ish grid
%   (PSTH_plotter convention: nCols=ceil(sqrt(n)), nRows=ceil(n/nCols)),
%   and toggles Visible on/off. Pre-allocated panels are never destroyed
%   or recreated -- only their grid position and Visible state change.
%
%   The right-hand uigridlayout (bd.rightGl) is also resized to match
%   the new row/column count so each visible tile gets a 1x cell.

if ~isfield(bd, 'panels') || isempty(bd.panels)
    return;
end

sel = bd.selectedChannels(:)';
nCh = bd.nChannels;
unSel = setdiff(1:nCh, sel);

% Hide unselected first so any handle-row/column reuse doesn't briefly
% double-occupy a cell.
for k = 1:numel(unSel)
    pn = bd.panels(unSel(k));
    if isgraphics(pn)
        set(pn, 'Visible', 'off');
    end
end

if isempty(sel)
    % Collapse the grid to a single 1x1 placeholder so the layout
    % engine doesn't keep stale row/column heights.
    bd.rightGl.RowHeight    = {'1x'};
    bd.rightGl.ColumnWidth  = {'1x'};
    return;
end

n     = numel(sel);
nCols = ceil(sqrt(n));
nRows = ceil(n / nCols);

bd.rightGl.RowHeight   = repmat({'1x'}, 1, nRows);
bd.rightGl.ColumnWidth = repmat({'1x'}, 1, nCols);

for i = 1:n
    ch = sel(i);
    pn = bd.panels(ch);
    if ~isgraphics(pn), continue; end
    [r, c] = ind2sub([nRows, nCols], i);
    % uipanel inside uigridlayout: positioned via Layout property.
    lay = pn.Layout;
    lay.Row    = r;
    lay.Column = c;
    pn.Layout  = lay;
    set(pn, 'Visible', 'on');
end

end
