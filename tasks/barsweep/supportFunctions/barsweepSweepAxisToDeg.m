function [trueDeg, degPerUnitS] = barsweepSweepAxisToDeg(s, centerDeg, pathLengthDeg, rigK)
% [trueDeg, degPerUnitS] = barsweepSweepAxisToDeg(s, centerDeg, pathLengthDeg, rigK)
%
% Convert a barsweep path-center-relative position from the (incorrect)
% sweep-axis units produced by the pre-fix nextParams.m into true visual
% angle in degrees.
%
% USE THIS ONLY ON DATA COLLECTED BEFORE THE nextParams.m GEOMETRY FIX.
% Sessions run after the fix already carry true dva on the sweep axis and
% need no correction (see analysisPlanningDocs/barsweep_geometry_discrepancy_report.md).
%
% ---------------------------------------------------------------------
% Why a correction is possible at all
%
% The pre-fix code computed the sweep trajectory as
%
%     cx_pix = middleXY(1) + deg2pix(pathCenterDeg)      % = round(tand(c)*k)
%     L_pix  = deg2pix(pathLengthDeg)                    % = round(tand(L)*k)
%     pix    = cx_pix + 0.5*L_pix*cos(theta)*linspace(-1,1,nFrames)
%
% while labelling those same frames with a position axis that is linear
% in dva:
%
%     s      = 0.5*pathLengthDeg*cos(theta)*linspace(-1,1,nFrames)
%
% Eliminating the frame index between the two gives an exact, invertible
% relation: the sweep axis is a rigidly scaled copy of the pixel axis,
%
%     pixOffsetFromScreenCenter = round(tand(c)*k) + (s/L) * round(tand(L)*k)
%
% so the true visual angle is just atand(pixOffset/k). The accumulated
% histograms are therefore a VALID reconstruction in the tangent (pixel)
% plane -- only the axis labels are wrong -- which is what makes this a
% relabeling rather than a re-analysis.
%
% ---------------------------------------------------------------------
% Inputs
%   s              path-center-relative position(s) on the sweep axis, in
%                  the pre-fix dva-like units. Any size. To correct an
%                  absolute reported center, pass (reported - centerDeg).
%   centerDeg      pathCenterXDeg (for azimuth / 0-180 deg sweeps) or
%                  pathCenterYDeg (for elevation / 90-270 deg sweeps).
%   pathLengthDeg  the nominal p.trVars.pathLengthDeg used at collection.
%   rigK           either the scalar viewdist*screenhpix/screenh, or a
%                  struct with those three fields (e.g. p.rig).
%
% Outputs
%   trueDeg        true visual angle, ABSOLUTE (not path-center-relative),
%                  same size as s.
%   degPerUnitS    local derivative dTrueDeg/ds at each s. Multiply a
%                  width/sigma expressed in sweep-axis units by this to get
%                  a width in true degrees.
%
% ---------------------------------------------------------------------
% ORDER OF OPERATIONS (cardinal4)
%
% Apply this to the ALREADY-AVERAGED midpoint centre (out.xCenter /
% out.yCenter), NOT to the individual per-direction peaks. The sweep axis
% is exactly linear in time, so the opposite-direction midpoint is what
% cancels response latency; averaging must happen in that coordinate.
% Mapping first and averaging second reintroduces a latency-dependent bias.
%
% Latency estimates derived from peak SEPARATION need no correction at all,
% for the same reason.
%
% See also correctBarsweepRFCenters, pds.deg2pix, pds.pix2deg

%% Resolve rigK.
if isstruct(rigK)
    assert(all(isfield(rigK, {'viewdist', 'screenhpix', 'screenh'})), ...
        ['barsweepSweepAxisToDeg: struct rigK must have fields viewdist, ' ...
         'screenhpix, screenh (i.e. pass p.rig).']);
    rigK = rigK.viewdist * rigK.screenhpix / rigK.screenh;
end
assert(isscalar(rigK) && isfinite(rigK) && rigK > 0, ...
    'barsweepSweepAxisToDeg: rigK must resolve to a positive finite scalar.');

assert(isscalar(centerDeg) && isfinite(centerDeg), ...
    'barsweepSweepAxisToDeg: centerDeg must be a finite scalar.');
assert(isscalar(pathLengthDeg) && isfinite(pathLengthDeg) && pathLengthDeg > 0, ...
    'barsweepSweepAxisToDeg: pathLengthDeg must be a positive finite scalar.');
assert(abs(centerDeg) < 90 && pathLengthDeg < 90, ...
    ['barsweepSweepAxisToDeg: |centerDeg| and pathLengthDeg must be < 90 deg; ' ...
     'tand() diverges at 90 and the original deg2pix call would have been ' ...
     'meaningless.']);

%% Reproduce the exact pixel geometry the pre-fix code used.
% round() is reproduced deliberately: pds.deg2pix rounds, and we want the
% correction to be exact rather than merely close.
cPix  = round(tand(centerDeg)     * rigK);
LPix  = round(tand(pathLengthDeg) * rigK);

u       = (cPix + (s ./ pathLengthDeg) .* LPix) ./ rigK;
trueDeg = atand(u);

if nargout > 1
    % d/ds atand(u) with du/ds = LPix/(pathLengthDeg*rigK), in degrees.
    degPerUnitS = (180 / pi) .* (LPix ./ (pathLengthDeg .* rigK)) ./ (1 + u.^2);
end

end
