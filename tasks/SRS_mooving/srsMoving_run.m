function p = srsMoving_run(p)
%SRSMOVING_RUN Execute one SRS trial and annotate its true spatial choice.
%
% srsSmooth_run still performs the state machine and reward delivery using
% T1/T2 identity. This wrapper adds absolute hemifield and relative spatial
% descriptors after the behavioral loop so moving-target analyses do not
% confuse "right hemifield" with "rightmost target".

p = srsSmooth_run(p);

if ~isfield(p, 'trData') || ~isstruct(p.trData)
    return
end

chosenTargetID = getNumeric(p.trData, 'chosenTargetID', 0);

p.trData.chosenPhysicalSide = 0;
p.trData.chosenVerticalSide = 0;
p.trData.chosenHorizontalRank = 0;
p.trData.chosenVerticalRank = 0;
p.trData.chosenTargetAngleDeg = NaN;
p.trData.chosenTargetXDeg = NaN;
p.trData.chosenTargetYDeg = NaN;

if chosenTargetID == 1
    p.trData.chosenPhysicalSide = getNumeric(p.trVars, 'T1PhysicalSide', 0);
    p.trData.chosenVerticalSide = getNumeric(p.trVars, 'T1VerticalSide', 0);
    p.trData.chosenTargetAngleDeg = getNumeric(p.trVars, 'movingT1AngleDeg', NaN);
    p.trData.chosenTargetXDeg = getNumeric(p.trVars, 'T1_locDegX', NaN);
    p.trData.chosenTargetYDeg = getNumeric(p.trVars, 'T1_locDegY', NaN);
elseif chosenTargetID == 2
    p.trData.chosenPhysicalSide = getNumeric(p.trVars, 'T2PhysicalSide', 0);
    p.trData.chosenVerticalSide = getNumeric(p.trVars, 'T2VerticalSide', 0);
    p.trData.chosenTargetAngleDeg = getNumeric(p.trVars, 'movingT2AngleDeg', NaN);
    p.trData.chosenTargetXDeg = getNumeric(p.trVars, 'T2_locDegX', NaN);
    p.trData.chosenTargetYDeg = getNumeric(p.trVars, 'T2_locDegY', NaN);
end

rightmostTargetID = getNumeric(p.trVars, 'rightmostTargetID', 0);
leftmostTargetID = getNumeric(p.trVars, 'leftmostTargetID', 0);
if chosenTargetID ~= 0 && chosenTargetID == rightmostTargetID
    p.trData.chosenHorizontalRank = 1;
elseif chosenTargetID ~= 0 && chosenTargetID == leftmostTargetID
    p.trData.chosenHorizontalRank = 2;
end

uppermostTargetID = getNumeric(p.trVars, 'uppermostTargetID', 0);
lowermostTargetID = getNumeric(p.trVars, 'lowermostTargetID', 0);
if chosenTargetID ~= 0 && chosenTargetID == uppermostTargetID
    p.trData.chosenVerticalRank = 1;
elseif chosenTargetID ~= 0 && chosenTargetID == lowermostTargetID
    p.trData.chosenVerticalRank = 2;
end

% Mirror rank values in trVars for status/debugging convenience. Strobes use
% trData so they reflect the completed choice rather than the default zero.
p.trVars.chosenHorizontalRank = p.trData.chosenHorizontalRank;
p.trVars.chosenVerticalRank = p.trData.chosenVerticalRank;

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
