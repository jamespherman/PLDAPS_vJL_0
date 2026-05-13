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
% CLim sweep below.
sliceByCh = cell(1, nCh);
xByCh     = cell(1, nCh);
yByCh     = cell(1, nCh);
snrByCh   = nan(1, nCh);
detected  = false(1, nCh);

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
        case 'barsweep_cardinal4'
            sliceByCh{ch} = out.separable2D;
            xByCh{ch}     = out.axisX + axisOffset(1);
            yByCh{ch}     = out.axisY + axisOffset(2);
        otherwise
            error('updateBarsweepChannelBrowser:badExptType', ...
                'Unknown exptType "%s".', exptType);
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
end

end
