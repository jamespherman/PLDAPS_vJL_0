function p = assignDubeyMovingLocations(p)
%ASSIGNDUBEYMOVINGLOCATIONS Randomize SRS target positions on a circle.
%
% Normal trial:
%   T1 angle is uniform on [0,360) deg. T2 is sampled from the conditional
%   uniform distribution whose shortest angular separation from T1 is at
%   least movingTargetMinSeparationDeg. Both targets share one eccentricity.
%
% Forced correction repeat:
%   the exact trigger-trial geometry is restored by the correction snapshot
%   and must not be resampled.
%
% Saved angle convention:
%   0 deg = +X/right, 90 deg = +Y/up in task degree coordinates.

if ~getLogical(p.trVars, 'movingTargetsEnabled', true)
    p = refreshMovingMetadata(p);
    return
end

eccDeg = getNumeric(p.trVars, 'movingTargetEccDeg', 10);
minSepDeg = getNumeric(p.trVars, 'movingTargetMinSeparationDeg', 90);

if ~isfinite(eccDeg) || eccDeg <= 0
    error('SRS_mooving:InvalidEccentricity', ...
        'movingTargetEccDeg must be a finite value > 0.');
end
if ~isfinite(minSepDeg) || minSepDeg < 0 || minSepDeg > 180
    error('SRS_mooving:InvalidSeparation', ...
        'movingTargetMinSeparationDeg must be between 0 and 180 deg.');
end

isCorrectionRepeat = getLogical(p.trVars, 'correctionTrialActive', false);
snapshotValid = isfield(p, 'status') && ...
    getLogical(p.status, 'correctionTrialSnapshotValid', false);

if isCorrectionRepeat
    if ~snapshotValid || ~hasFiniteSavedGeometry(p.trVars)
        error('SRS_mooving:MissingCorrectionGeometry', ...
            ['A correction repeat is active but the exact moving-target ', ...
             'geometry was not restored from the trigger trial.']);
    end
else
    theta1 = 360 * rand;
    separation = minSepDeg + (180 - minSepDeg) * rand;
    if rand < 0.5
        direction = -1;
    else
        direction = 1;
    end
    theta2 = mod(theta1 + direction * separation, 360);

    fixX = getNumeric(p.trVars, 'fixDegX', 0);
    fixY = getNumeric(p.trVars, 'fixDegY', 0);

    p.trVars.movingT1AngleDeg = mod(theta1, 360);
    p.trVars.movingT2AngleDeg = mod(theta2, 360);
    p.trVars.T1_locDegX = fixX + eccDeg * cosd(theta1);
    p.trVars.T1_locDegY = fixY + eccDeg * sind(theta1);
    p.trVars.T2_locDegX = fixX + eccDeg * cosd(theta2);
    p.trVars.T2_locDegY = fixY + eccDeg * sind(theta2);
end

p = refreshMovingMetadata(p);

if p.trVars.movingAngularSeparationDeg + 1e-9 < minSepDeg
    error('SRS_mooving:SeparationViolation', ...
        'Sampled target separation %.6f deg is below requested %.6f deg.', ...
        p.trVars.movingAngularSeparationDeg, minSepDeg);
end

end

function p = refreshMovingMetadata(p)
fixX = getNumeric(p.trVars, 'fixDegX', 0);
fixY = getNumeric(p.trVars, 'fixDegY', 0);
tol = 1e-9;

% Reconstruct angles from coordinates if a partial/older snapshot is loaded.
if ~isfield(p.trVars, 'movingT1AngleDeg') || ...
        ~isfinite(double(p.trVars.movingT1AngleDeg))
    p.trVars.movingT1AngleDeg = mod(atan2d( ...
        p.trVars.T1_locDegY - fixY, p.trVars.T1_locDegX - fixX), 360);
end
if ~isfield(p.trVars, 'movingT2AngleDeg') || ...
        ~isfinite(double(p.trVars.movingT2AngleDeg))
    p.trVars.movingT2AngleDeg = mod(atan2d( ...
        p.trVars.T2_locDegY - fixY, p.trVars.T2_locDegX - fixX), 360);
end

p.trVars.movingT1AngleDeg = mod(double(p.trVars.movingT1AngleDeg), 360);
p.trVars.movingT2AngleDeg = mod(double(p.trVars.movingT2AngleDeg), 360);
p.trVars.movingAngularSeparationDeg = circularSeparationDeg( ...
    p.trVars.movingT1AngleDeg, p.trVars.movingT2AngleDeg);

% Absolute hemifields relative to fixation.
p.trVars.T1PhysicalSide = horizontalSideFromX(p.trVars.T1_locDegX, fixX);
p.trVars.T2PhysicalSide = horizontalSideFromX(p.trVars.T2_locDegX, fixX);
p.trVars.T1VerticalSide = verticalSideFromY(p.trVars.T1_locDegY, fixY);
p.trVars.T2VerticalSide = verticalSideFromY(p.trVars.T2_locDegY, fixY);

% "Right choice" is only a meaningful binary hemifield decision when one
% target is left and the other is right. Same logic vertically.
p.trVars.movingTargetsStraddleLR = double( ...
    (p.trVars.T1PhysicalSide == 1 && p.trVars.T2PhysicalSide == 2) || ...
    (p.trVars.T1PhysicalSide == 2 && p.trVars.T2PhysicalSide == 1));
p.trVars.movingTargetsStraddleUD = double( ...
    (p.trVars.T1VerticalSide == 1 && p.trVars.T2VerticalSide == 2) || ...
    (p.trVars.T1VerticalSide == 2 && p.trVars.T2VerticalSide == 1));

% Relative spatial ranks remain defined even when both targets are in the
% same hemifield. Ties occur only at measure-zero geometries, but are handled.
dx = double(p.trVars.T1_locDegX) - double(p.trVars.T2_locDegX);
if dx > tol
    p.trVars.rightmostTargetID = 1;
    p.trVars.leftmostTargetID = 2;
elseif dx < -tol
    p.trVars.rightmostTargetID = 2;
    p.trVars.leftmostTargetID = 1;
else
    p.trVars.rightmostTargetID = 0;
    p.trVars.leftmostTargetID = 0;
end

dy = double(p.trVars.T1_locDegY) - double(p.trVars.T2_locDegY);
if dy > tol
    p.trVars.uppermostTargetID = 1;
    p.trVars.lowermostTargetID = 2;
elseif dy < -tol
    p.trVars.uppermostTargetID = 2;
    p.trVars.lowermostTargetID = 1;
else
    p.trVars.uppermostTargetID = 0;
    p.trVars.lowermostTargetID = 0;
end

p.trVars.movingT1Angle_x10 = mod(round(10 * p.trVars.movingT1AngleDeg), 3600);
p.trVars.movingT2Angle_x10 = mod(round(10 * p.trVars.movingT2AngleDeg), 3600);
p.trVars.movingSeparation_x10 = round(10 * p.trVars.movingAngularSeparationDeg);
p.trVars.movingEccentricity_x100 = round(100 * ...
    getNumeric(p.trVars, 'movingTargetEccDeg', 10));

p.status.highRewardPhysicalSide = physicalSideOfTarget(p, ...
    getNumeric(p.status, 'highRewardTargetID', 0));
p.status.highSaliencePhysicalSide = physicalSideOfTarget(p, ...
    getNumeric(p.status, 'highSalienceTargetID', 0));

% nextParams converted the old coordinates to pixels before this helper ran.
% Recompute them after randomizing positions so drawing and acceptance
% windows follow the true moving coordinates.
p = updatePixelLocations(p);
end

function p = updatePixelLocations(p)
if ~isfield(p, 'draw') || ~isfield(p.draw, 'middleXY')
    error('SRS_mooving:MissingDisplayGeometry', ...
        'p.draw.middleXY is unavailable while assigning moving targets.');
end
p.draw.T1_locPixX = p.draw.middleXY(1) + pds.deg2pix(p.trVars.T1_locDegX, p);
p.draw.T1_locPixY = p.draw.middleXY(2) - pds.deg2pix(p.trVars.T1_locDegY, p);
p.draw.T2_locPixX = p.draw.middleXY(1) + pds.deg2pix(p.trVars.T2_locDegX, p);
p.draw.T2_locPixY = p.draw.middleXY(2) - pds.deg2pix(p.trVars.T2_locDegY, p);
end

function side = physicalSideOfTarget(p, targetID)
if targetID == 1
    side = getNumeric(p.trVars, 'T1PhysicalSide', 0);
elseif targetID == 2
    side = getNumeric(p.trVars, 'T2PhysicalSide', 0);
else
    side = 0;
end
end

function side = horizontalSideFromX(targetX, fixX)
tol = 1e-9;
if targetX > fixX + tol
    side = 1;
elseif targetX < fixX - tol
    side = 2;
else
    side = 0;
end
end

function side = verticalSideFromY(targetY, fixY)
tol = 1e-9;
if targetY > fixY + tol
    side = 1; % upper
elseif targetY < fixY - tol
    side = 2; % lower
else
    side = 0;
end
end

function sep = circularSeparationDeg(a, b)
d = mod(abs(double(a) - double(b)), 360);
sep = min(d, 360 - d);
end

function tf = hasFiniteSavedGeometry(s)
fields = {'T1_locDegX','T1_locDegY','T2_locDegX','T2_locDegY', ...
    'movingT1AngleDeg','movingT2AngleDeg'};
tf = true;
for iField = 1:numel(fields)
    name = fields{iField};
    if ~isfield(s, name) || ~isnumeric(s.(name)) || ...
            ~isscalar(s.(name)) || ~isfinite(double(s.(name)))
        tf = false;
        return
    end
end
end

function value = getNumeric(s, name, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s, name)
    candidate = s.(name);
    if (isnumeric(candidate) || islogical(candidate)) && ...
            isscalar(candidate) && isfinite(double(candidate))
        value = double(candidate);
    end
end
end

function value = getLogical(s, name, defaultValue)
value = logical(getNumeric(s, name, double(defaultValue)));
end
