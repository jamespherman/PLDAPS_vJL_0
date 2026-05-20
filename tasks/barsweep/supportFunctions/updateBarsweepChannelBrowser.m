function updateBarsweepChannelBrowser(bd, rf, reconOpts, axisOffset)
% updateBarsweepChannelBrowser  Refresh per-channel barsweep RF tiles.
%
%   updateBarsweepChannelBrowser(bd, rf, reconOpts, axisOffset)
%
%   For each channel:
%     - reconstruct via reconstructBarsweepRF(rf, ch, rf.exptType, reconOpts)
%     - rfmap12   -> display out.rfImage on out.axisDeg + axisOffset
%     - cardinal4 -> display out.separable2D on out.axisX/Y + axisOffset
%   axisOffset is a [xOff, yOff] pair (typically [pathCenterXDeg,
%   pathCenterYDeg]) that converts path-center-relative dva to absolute
%   display dva, matching plotBarsweepRF's detail-panel convention.
%
%   CLim policy:
%     'per-channel': symmetric [-cMax, cMax] off the channel's own slice
%       (rfmap12) or [0, 1] (cardinal4 separable thumbnails are
%       normalized to [0, 1] inside reconstructBarsweepRF).
%     'global': single symmetric range across all visible tiles for
%       rfmap12; the cardinal4 case is already normalized so global has
%       no effect on it.
%
%   Channels with zero spikes get a blank slice and "N=0" title.

if ~isstruct(bd) || ~isfield(bd, 'fig') || ~isvalid(bd.fig)
    return;
end
if nargin < 4 || isempty(axisOffset), axisOffset = [0, 0]; end
if nargin < 3 || isempty(reconOpts),  reconOpts  = struct(); end

% Re-fetch live bd (selection / CLim toggle may have changed).
bd = bd.fig.UserData;

nCh      = bd.nChannels;
exptType = bd.exptType;

% First pass: reconstruct + cache per-channel slices for the global
% CLim sweep below. Also cache per-channel RF-center estimates so the
% second pass can drive the pre-allocated marker on each tile. Same
% estimator that the CSV export uses (parabolic peaks for cardinal4,
% gaussFit centroid for rfmap12) so the live display agrees with what
% gets written to disk.
sliceByCh = cell(1, nCh);
xByCh     = cell(1, nCh);
yByCh     = cell(1, nCh);
snrByCh   = nan(1, nCh);
detected  = false(1, nCh);
centerXY  = nan(nCh, 2);

for ch = 1:nCh
    if ~isgraphics(bd.imgObj(ch)), continue; end
    if rf.spikeCount(ch) < 1
        sliceByCh{ch} = zeros(2);
        xByCh{ch} = [-1, 1] + axisOffset(1);
        yByCh{ch} = [-1, 1] + axisOffset(2);
        continue;
    end

    out = reconstructBarsweepRF(rf, ch, exptType, reconOpts);
    snrByCh(ch)  = out.peakStats.snr;
    detected(ch) = out.peakStats.detected;

    switch exptType
        case 'barsweep_rfmap12'
            sliceByCh{ch} = out.rfImage;
            xByCh{ch}     = out.axisDeg + axisOffset(1);
            yByCh{ch}     = out.axisDeg + axisOffset(2);
            % gaussFit on a small disc around the iradon argmax --
            % localized and unbiased; matches the rfmap12 CSV column.
            cx = out.gaussFit.x0;
            cy = out.gaussFit.y0;
        case 'barsweep_cardinal4'
            sliceByCh{ch} = out.separable2D;
            xByCh{ch}     = out.axisX + axisOffset(1);
            yByCh{ch}     = out.axisY + axisOffset(2);
            % Parabolic peaks of the 1-D marginals -- the cardinal4
            % CSV's estimator (gaussFit on the outer-product thumbnail
            % is biased toward path center; don't use it).
            cx = out.xCenter;
            cy = out.yCenter;
        otherwise
            error('updateBarsweepChannelBrowser:badExptType', ...
                'Unknown exptType "%s".', exptType);
    end
    if isfinite(cx) && isfinite(cy)
        centerXY(ch, :) = [cx + axisOffset(1), cy + axisOffset(2)];
    end
end

% Compute global CLim if requested (rfmap12 only -- cardinal4 is
% already in [0, 1]).
useGlobal = strcmp(bd.climMode, 'global') && strcmp(exptType, 'barsweep_rfmap12');
globalCMax = 0;
if useGlobal
    sel = bd.selectedChannels;
    for k = 1:numel(sel)
        ch = sel(k);
        s = sliceByCh{ch};
        if ~isempty(s)
            v = max(abs(s(:)));
            if v > globalCMax, globalCMax = v; end
        end
    end
    if globalCMax == 0, globalCMax = 1; end
end

for ch = 1:nCh
    if ~isgraphics(bd.imgObj(ch)), continue; end

    slice = sliceByCh{ch};
    xData = xByCh{ch};
    yData = yByCh{ch};

    set(bd.imgObj(ch), 'CData', slice, 'XData', xData, 'YData', yData);

    switch exptType
        case 'barsweep_rfmap12'
            if useGlobal
                cMax = globalCMax;
            else
                cMax = max(abs(slice(:)));
                if cMax == 0, cMax = 1; end
            end
            set(bd.imgAx(ch), 'CLim', [-cMax, cMax]);
        case 'barsweep_cardinal4'
            % separable2D is already in [0, 1]; pin the scale.
            set(bd.imgAx(ch), 'CLim', [0, 1]);
    end

    if rf.spikeCount(ch) < 1
        titleStr = sprintf('ch %d  N=0', ch);
    else
        suffix = '';
        if ~detected(ch), suffix = ' *'; end
        titleStr = sprintf('ch %d  N=%d  snr=%.1f%s', ...
            ch, rf.spikeCount(ch), snrByCh(ch), suffix);
    end
    set(bd.titleObj(ch), 'Text', titleStr);

    % RF center marker. Plot whenever an estimate is finite (including
    % below-threshold channels) so the experimenter can see the argmax
    % the algorithm landed on -- but mute the color when undetected so
    % real RFs read at a glance and noise peaks don't.
    if isfield(bd, 'rfCenterMarker') && isgraphics(bd.rfCenterMarker(ch))
        cx = centerXY(ch, 1);
        cy = centerXY(ch, 2);
        if isnan(cx) || isnan(cy)
            set(bd.rfCenterMarker(ch), 'XData', NaN, 'YData', NaN);
        elseif detected(ch)
            set(bd.rfCenterMarker(ch), 'XData', cx, 'YData', cy, ...
                'Color', [0.85 0 0], 'LineWidth', 1.8);
        else
            set(bd.rfCenterMarker(ch), 'XData', cx, 'YData', cy, ...
                'Color', [0.55 0.55 0.55], 'LineWidth', 1.0);
        end
    end
end

end
