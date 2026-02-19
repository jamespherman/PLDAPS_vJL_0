function p = updateTrialsList(p)
%
% p = updateTrialsList(p)
%
% If trial needs to be repeated, shuffle it into the remaining trials. If
% a block has been completed, start a new block.
%

% Mark the appropriate row of p.status.trialsArrayRowsPossible according to
% the outcome of the previous trial (does it need to be repeated?).
p.status.trialsArrayRowsPossible(p.trVars.currentTrialsArrayRow) = p.trData.trialRepeatFlag;

% If all the trials in the current block have been completed, reset
% p.status.trialsArrayRowsPossible
if ~any(p.status.trialsArrayRowsPossible)
    p.status.trialsArrayRowsPossible(:) = true;
end

end
