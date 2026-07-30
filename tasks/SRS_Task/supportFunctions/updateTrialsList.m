function p = updateTrialsList(p)
%UPDATETRIALSLIST Mark the current schedule row complete or repeatable.
%
% Successful trials are removed from eligibility. Failed/aborted trials
% remain eligible and will be selected again later. A new block is created
% by nextParams on the next trial after all rows are complete.

if ~isfield(p.trVars, 'currentTrialsArrayRow') || ...
        isempty(p.trVars.currentTrialsArrayRow) || ...
        p.trVars.currentTrialsArrayRow < 1
    return
end

rowIdx = p.trVars.currentTrialsArrayRow;

if rowIdx > numel(p.status.trialsArrayRowsPossible)
    error('Current SRS schedule row is outside trialsArrayRowsPossible.');
end

p.trData.trialRepeatFlag = ~logical(p.trData.GoodTrial);
p.status.trialsArrayRowsPossible(rowIdx) = p.trData.trialRepeatFlag;

p = updateSrsScheduleStatus(p);

end
