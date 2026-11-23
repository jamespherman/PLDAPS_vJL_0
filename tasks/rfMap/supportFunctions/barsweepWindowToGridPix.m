function g = barsweepWindowToGridPix(p, win, checkSizePix)
% barsweepWindowToGridPix  Place a fixation-relative dva window on screen.
%
%   g = barsweepWindowToGridPix(p, win, checkSizePix)
%
%   win: struct from importBarsweepRFWindow (centerDeg, widthDeg, heightDeg,
%   all fixation-relative dva). Each EDGE is converted as an absolute screen
%   eccentricity (fixDeg + offset) with pds.deg2pix, because deg2pix is a
%   tangent map and is only valid on absolute eccentricities -- applying it
%   to a width is the bug documented in
%   analysisPlanningDocs/barsweep_geometry_discrepancy_report.md. The window
%   is clipped to the screen.
%
%   g.ok, g.reason, g.centerPix [x y] (PTB pixels), g.widthPix, g.heightPix,
%   g.xEdgePix, g.yEdgePix (top, bottom).

fx = p.trVarsInit.fixDegX;
fy = p.trVarsInit.fixDegY;
xEdgeDeg = fx + win.centerDeg(1) + [-0.5 0.5] * win.widthDeg;
yEdgeDeg = fy + win.centerDeg(2) + [-0.5 0.5] * win.heightDeg;

mid = p.draw.middleXY;
xEdgePix = mid(1) + [pds.deg2pix(xEdgeDeg(1), p), pds.deg2pix(xEdgeDeg(2), p)];
yEdgePix = mid(2) - [pds.deg2pix(yEdgeDeg(2), p), pds.deg2pix(yEdgeDeg(1), p)]; % top, bottom

W = p.draw.screenRect(3);  H = p.draw.screenRect(4);
xEdgePix = min(max(xEdgePix, 0), W);
yEdgePix = min(max(yEdgePix, 0), H);

g = struct('ok', false, 'reason', '', 'centerPix', [NaN NaN], ...
    'widthPix', 0, 'heightPix', 0, 'xEdgePix', xEdgePix, 'yEdgePix', yEdgePix);
if diff(xEdgePix) < checkSizePix || diff(yEdgePix) < checkSizePix
    g.reason = sprintf('x [%.1f %.1f], y [%.1f %.1f] dva', xEdgeDeg, yEdgeDeg);
    return;
end
g.ok        = true;
g.reason    = 'ok';
g.widthPix  = diff(xEdgePix);
g.heightPix = diff(yEdgePix);
g.centerPix = [mean(xEdgePix), mean(yEdgePix)];
end
