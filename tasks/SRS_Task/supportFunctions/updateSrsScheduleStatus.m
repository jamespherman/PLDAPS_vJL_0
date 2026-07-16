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

end
