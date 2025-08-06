function p = updateTrialsList(p)
%
% p = updateTrialsList(p)
%
% If the last trial was completed successfully, mark it as unavailable in
% "p.status.trialsArrayRowsPossible", otherwise, keep it eligible for
% completion. If no more rows are available to run, reset
% "p.status.trialsArrayRowsPossible" so that all rows are available (start
% of a new block).
%

% Mark the appropriate row of p.status.trialsArrayRowsPossible according to
% the outcome of the previous trial (does it need to be repeated?).
p.status.trialsArrayRowsPossible(p.trVars.currentTrialsArrayRow) = ...
    p.trData.trialRepeatFlag;

% If all the trials in the current block have been completed, reset
% p.status.trialsArrayRowsPossible. Also, flip "p.status.tLoc1HighRwdFirst"
% from true to false or vice versa:
if ~any(p.status.trialsArrayRowsPossible)
    p.status.trialsArrayRowsPossible(:) = true;

    % flip p.status.tLoc1HighRwdFirst:
    p.status.tLoc1HighRwdFirst = ~p.status.tLoc1HighRwdFirst;
end

end