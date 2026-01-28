function p = updateStatusVariables(p)
%   p = updateStatusVariables(p)
%
% Updates session-level status variables after each trial.

%% Update good trial count (trials that don't need to be repeated)
p.status.iGoodTrial = p.status.iGoodTrial + double(~p.trData.trialRepeatFlag);

%% Update outcome-specific counters
switch p.trData.outcome
    case 'GOAL_DIRECTED'
        % Counter updated in updateOnlinePlots
    case 'CAPTURE'
        % Counter updated in updateOnlinePlots
    case 'FIX_BREAK'
        p.status.nFixBreak = p.status.nFixBreak + 1;
    case 'NO_RESPONSE'
        p.status.nNoResponse = p.status.nNoResponse + 1;
    case 'INACCURATE'
        p.status.nInaccurate = p.status.nInaccurate + 1;
end

%% Calculate trials remaining in current block
if p.trVars.setTargLocViaTrialArray
    % Count remaining trials in current block
    blockCol = strcmp(p.init.trialArrayColumnNames, 'blockNumber');
    currentBlock = p.status.iBlock;
    inCurrentBlock = p.init.trialsArray(:, blockCol) == currentBlock;
    p.status.trialsLeftInBlock = ...
        sum(inCurrentBlock & p.status.trialsArrayRowsPossible);
else
    p.status.trialsLeftInBlock = 60 - p.status.iTrialInBlock;
end

end
