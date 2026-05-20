function bd = initBarsweepChannelBrowser(rf)
% initBarsweepChannelBrowser  Per-channel RF browser uifigure for barsweep.
%
%   bd = initBarsweepChannelBrowser(rf)
%
%   Wraps pds.initChannelBrowser with a single-image tile per channel
%   (no lag mini-axis -- barsweep RF estimates have no temporal lag
%   dimension; latency is a single scalar applied at accumulation time
%   in accumulateBarsweepRF.m).
%
%   For barsweep_rfmap12, each tile shows the FBP RF image. For
%   barsweep_cardinal4, each tile shows the separable-2D thumbnail
%   (out.separable2D from reconstructBarsweepRF). Both are 2D images
%   of size approximately equal to the path extent in dva.
%
%   Inputs:
%     rf - p.init.barsweepRF struct (post-init), used for nChannels and
%          exptType.
%
%   Returns bd from pds.initChannelBrowser plus:
%     .exptType - mirror of rf.exptType (used by updateBarsweepChannelBrowser
%                 to decide which reconstruction output to display)

nCh = rf.nChannels;
% Per-tile dva extent: image spans pathCenter +/- mapExtentDeg in both
% axes (matches XData/YData set per channel in updateBarsweepChannelBrowser
% via axisOffset = pathCenterDeg). Pass as 1x4 [xmin xmax ymin ymax] so
% the axes box matches the grid cell rather than the image's pixel aspect.
cx = rf.pathCenterDeg(1);
cy = rf.pathCenterDeg(2);
E  = rf.mapExtentDeg;
imgExtentDeg = [cx - E, cx + E, cy - E, cy + E];

opts = struct( ...
    'figName',          sprintf('barsweep RF (%s) - Channel browser', rf.exptType), ...
    'imgXLabel',        'x (dva)', ...
    'imgYLabel',        'y (dva)', ...
    'initialSelection', 1:min(nCh, 16), ...
    'climMode',         'per-channel', ...
    'figPos',           [60 60 1500 850], ...
    'imgExtentDeg',     imgExtentDeg);

bd = pds.initChannelBrowser(nCh, 'image', opts);
bd.exptType = rf.exptType;
bd.fig.UserData = bd;

end
