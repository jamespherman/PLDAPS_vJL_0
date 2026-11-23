function mask = occludedCheckMask(p)
% occludedCheckMask  Logical [nY, nX] of dense-noise checks occluded on the
% SUBJECT display by the fixation clearing patch (and fixation point).
%
%   mask = occludedCheckMask(p)
%
%   rfMap_run.m draws a p.trVars.clearPatchDeg background disk (and the
%   fixation point) ON TOP of the noise, so the checks near fixation show
%   constant mean luminance, not noise. The STA accumulators, however,
%   correlate spikes against the regenerated/rendered noise everywhere,
%   including those occluded checks. Because that noise was never actually
%   presented, the correlation is spurious and -- interacting with the
%   population's hemifield drive -- produces high-Z "receptive fields"
%   pinned at fixation (verified 2026-07-08: 11/20 dense-achromatic RFs on
%   one central pixel; masking them collapses Z to the noise floor with no
%   real RF underneath). Callers use this mask to zero the occluded checks
%   in the accumulated STA (see applyOccludedMask), so RF detection, SNR,
%   maps, and colour tuning never see the artifact.
%
%   Grid geometry matches computeRFCenters / nextParams: the grid is
%   centred on p.init.noiseGridCenterPix (screen centre for 'full', offset
%   for hemifield modes and for the barsweep RF window) with square checks
%   of deg2pix(checkSizeDeg) pixels. Check centres are placed in PIXELS and
%   converted to absolute dva one point at a time (deg2pix/pix2deg are a
%   tangent map), then compared with fixation (fixDegX, fixDegY). A check is
%   occluded if the clearing-patch disk overlaps it (centre within
%   patchRadius + checkHalfWidth of fixation).
%
%   Before 2026-11 this assumed the grid was centred on the screen, which
%   flagged the wrong checks for hemifield grids and for any displaced
%   window (plan review #6).

nY = p.init.noiseGridSize(1);
nX = p.init.noiseGridSize(2);
checkDeg = p.trVars.checkSizeDeg;
fixX = getdef(p.trVars, 'fixDegX', 0);
fixY = getdef(p.trVars, 'fixDegY', 0);
clearDeg = getdef(p.trVars, 'clearPatchDeg', 0);

if clearDeg <= 0
    mask = false(nY, nX);
    return;
end

checkPix = max(pds.deg2pix(checkDeg, p), 1);
gc = getdef(p.init, 'noiseGridCenterPix', p.draw.middleXY);

% Check-centre screen pixels (PTB: y grows downward).
colPix = gc(1) + ((1:nX) - 0.5 - nX/2) * checkPix;
rowPix = gc(2) + ((1:nY) - 0.5 - nY/2) * checkPix;
% Absolute screen dva, y up.
colAx = pds.pix2deg(colPix - p.draw.middleXY(1), p);
rowAx = pds.pix2deg(p.draw.middleXY(2) - rowPix, p);
[CX, CY] = meshgrid(colAx, rowAx);

r = clearDeg/2 + checkDeg/2;                  % patch radius + check half-side
mask = hypot(CX - fixX, CY - fixY) <= r;
end

function v = getdef(s, f, d)
if isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end
