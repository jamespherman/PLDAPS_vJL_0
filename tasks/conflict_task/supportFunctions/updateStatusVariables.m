function p = updateStatusVariables(p)
%   p = updateStatusVariables(p)
%
% Updates session-level status variables after each trial.

%% Update good trial count (trials that don't need to be repeated)
p.status.iGoodTrial = p.status.iGoodTrial + double(~p.trData.trialRepeatFlag);

%% Update outcome-specific counters
switch p.trData.outcome
    case 'CHOSE_HIGH_SAL'
        % Counter updated in updateOnlinePlots
    case 'CHOSE_LOW_SAL'
        % Counter updated in updateOnlinePlots
    case 'FIX_BREAK'
        p.status.nFixBreak = p.status.nFixBreak + 1;
    case 'NO_RESPONSE'
        p.status.nNoResponse = p.status.nNoResponse + 1;
    case 'INACCURATE'
        p.status.nInaccurate = p.status.nInaccurate + 1;
end

%% Calculate trials remaining in current phase
if p.trVars.setTargLocViaTrialArray
    % Count remaining trials in current phase
    phaseCol = strcmp(p.init.trialArrayColumnNames, 'phaseNumber');
    currentPhase = p.status.currentPhase;
    inCurrentPhase = p.init.trialsArray(:, phaseCol) == currentPhase;
    p.status.trialsLeftInPhase = ...
        sum(inCurrentPhase & p.status.trialsArrayRowsPossible);

    % Update completed trials in phase (use per-phase count)
    trialsInThisPhase = p.init.trialsPerPhaseList(currentPhase);
    p.status.completedTrialsInPhase = trialsInThisPhase - p.status.trialsLeftInPhase;
else
    trialsInThisPhase = p.init.trialsPerPhaseList(p.status.currentPhase);
    p.status.trialsLeftInPhase = trialsInThisPhase - p.status.completedTrialsInPhase;
end

end
