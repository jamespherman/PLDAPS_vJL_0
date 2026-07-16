function p = updateSrsScheduleStatus(p)
%UPDATESRSSCHEDULESTATUS Recompute remaining counts from schedule eligibility.

if ~isfield(p.init, 'trialsArray') || isempty(p.init.trialsArray) || ...
        ~isfield(p.status, 'trialsArrayRowsPossible')
    p.status.RemainingSingleT1 = 0;
    p.status.RemainingSingleT2 = 0;
    p.status.RemainingInstructionTrials = 0;
    p.status.RemainingCongruent = 0;
    p.status.RemainingConflict = 0;
    p.status.RemainingChoiceTrials = 0;
    p.status.trialsLeftInBlock = 0;
    p.status.CurrentBlockTrial = 0;
    p.status.ActiveSchedulePhase = 0;
    p.status.ActiveSingleTargetID = 0;
    p.status.RemainingActivePhase = 0;
    p.status.blockScheduleComplete = true;
    return
end

cols = p.init.trialCols;
remaining = logical(p.status.trialsArrayRowsPossible(:));
trialsArray = p.init.trialsArray;

if numel(remaining) ~= size(trialsArray, 1)
    error('trialsArrayRowsPossible does not match the SRS trialsArray length.');
end

p.status.RemainingSingleT1 = sum(remaining & ...
    trialsArray(:, cols.nStim) == 1 & ...
    trialsArray(:, cols.singleTargetID) == 1);

p.status.RemainingSingleT2 = sum(remaining & ...
    trialsArray(:, cols.nStim) == 1 & ...
    trialsArray(:, cols.singleTargetID) == 2);

p.status.RemainingInstructionTrials = ...
    p.status.RemainingSingleT1 + p.status.RemainingSingleT2;

p.status.RemainingCongruent = sum(remaining & ...
    trialsArray(:, cols.nStim) == 2 & ...
    trialsArray(:, cols.trialType) == 1);

p.status.RemainingConflict = sum(remaining & ...
    trialsArray(:, cols.nStim) == 2 & ...
    trialsArray(:, cols.trialType) == 2);

p.status.RemainingChoiceTrials = ...
    p.status.RemainingCongruent + p.status.RemainingConflict;

p.status.trialsLeftInBlock = sum(remaining);
p.status.CurrentBlockTrial = sum(~remaining);
p.status.blockScheduleComplete = ~any(remaining);

% Report the earliest unfinished phase. During training this identifies the
% currently active single-target group and confirms that groups do not
% overlap. Standard blocks contain only phase 3 choice trials.
if any(remaining)
    schedulePhase = trialsArray(:, cols.schedulePhase);
    activePhase = min(schedulePhase(remaining));
    p.status.ActiveSchedulePhase = activePhase;
    p.status.RemainingActivePhase = sum(remaining & schedulePhase == activePhase);

    if activePhase == 1
        p.status.ActiveSingleTargetID = getStatusScalar( ...
            p.status, 'FirstSingleTargetID', 0);
    elseif activePhase == 2
        p.status.ActiveSingleTargetID = getStatusScalar( ...
            p.status, 'SecondSingleTargetID', 0);
    else
        p.status.ActiveSingleTargetID = 0;
    end
else
    p.status.ActiveSchedulePhase = 0;
    p.status.ActiveSingleTargetID = 0;
    p.status.RemainingActivePhase = 0;
end

end

function value = getStatusScalar(s, fieldName, defaultValue)
value = defaultValue;
if isfield(s, fieldName) && isnumeric(s.(fieldName)) && ...
        isscalar(s.(fieldName)) && isfinite(s.(fieldName))
    value = s.(fieldName);
end
end
