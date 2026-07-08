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
%   Grid geometry matches denseGridAxes / computeRFCenters: check centres
%   are on a regular grid of side p.trVars.checkSizeDeg, fixation at
%   (fixDegX, fixDegY). A check is occluded if the clearing-patch disk
%   overlaps it (centre within patchRadius + checkHalfWidth of fixation).

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

% Check-centre coordinates in dva relative to fixation-at-origin, y up
% (same convention as denseGridAxes).
colAx = ((1:nX) - 0.5 - nX/2) * checkDeg;    % azimuth
rowAx = -(((1:nY) - 0.5 - nY/2) * checkDeg); % elevation
[CX, CY] = meshgrid(colAx, rowAx);

r = clearDeg/2 + checkDeg/2;                  % patch radius + check half-side
mask = hypot(CX - fixX, CY - fixY) <= r;
end

function v = getdef(s, f, d)
if isfield(s, f) && ~isempty(s.(f)), v = s.(f); else, v = d; end
end
