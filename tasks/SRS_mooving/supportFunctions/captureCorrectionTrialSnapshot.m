function p = captureCorrectionTrialSnapshot(p)
%CAPTURECORRECTIONTRIALSNAPSHOT Save the exact reward/salience condition.
%
% The snapshot is created on the trigger trial and restored on every forced
% repetition. Schedule identity and target positions still come from the
% same row; this snapshot preserves the stochastic reward and stimulus
% values that would otherwise be resampled by nextParams. In SRS_mooving,
% the exact random target coordinates/angles are included as well.

snapshot = struct();
snapshot.trVars = struct();

if isfield(p, 'trVars') && isstruct(p.trVars)
    names = fieldnames(p.trVars);
    for i = 1:numel(names)
        name = names{i};
        if shouldSnapshotTrialField(name)
            snapshot.trVars.(name) = p.trVars.(name);
        end
    end
end

snapshot.status = struct();
statusFields = { ...
    'ActualRichReward', 'ActualPoorReward', ...
    'highRewardTargetID', 'highRewardSide', ...
    'highSalienceTargetID', 'highSalienceSide', ...
    'highRewardPhysicalSide', 'highSaliencePhysicalSide', ...
    'correctionTrialTriggerTargetID', ...
    'ActualTrialType', 'CurrentTrialType'};
for i = 1:numel(statusFields)
    name = statusFields{i};
    if isfield(p.status, name)
        snapshot.status.(name) = p.status.(name);
    end
end

% Smooth-hue trials may rewrite reserved CLUT entries each trial. Preserve
% the exact CLUT state so the repeated colors are identical.
if isfield(p, 'draw') && isfield(p.draw, 'clut')
    snapshot.clut = p.draw.clut;
else
    snapshot.clut = [];
end

snapshot.capturedAttempt = getScalar(p.status, 'iTrial', NaN);
snapshot.capturedRow = getScalar(p.trVars, 'currentTrialsArrayRow', NaN);
p.status.correctionTrialSnapshot = snapshot;
p.status.correctionTrialSnapshotValid = true;

end

function tf = shouldSnapshotTrialField(name)
nameLower = lower(name);
includeTokens = { ...
    'reward', 'salience', 'luminance', 'hue', 'dkl', 'color', 'rgb', ...
    'redlevel', 'background', 'updateclut', 'contrast', ...
    'moving', 'locdeg', 'physicalside', 'verticalside', ...
    'rightmost', 'leftmost', 'uppermost', 'lowermost', 'straddle'};
excludeTokens = {'correction', 'preview', 'controlwindow'};

tf = false;
for i = 1:numel(includeTokens)
    if contains(nameLower, includeTokens{i})
        tf = true;
        break
    end
end
for i = 1:numel(excludeTokens)
    if contains(nameLower, excludeTokens{i})
        tf = false;
        break
    end
end
end

function value = getScalar(s, name, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s, name)
    candidate = s.(name);
    if (isnumeric(candidate) || islogical(candidate)) && ...
            isscalar(candidate) && isfinite(double(candidate))
        value = double(candidate);
    end
end
end
