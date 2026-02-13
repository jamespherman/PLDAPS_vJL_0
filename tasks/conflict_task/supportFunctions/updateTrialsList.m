function p = updateTrialsList(p)
%   p = updateTrialsList(p)
%
% Updates the trial availability list after each trial.
% If the trial was completed successfully (chose high or low salience),
% mark it as unavailable. If it was an error, keep it available for repeat.
%
% Handles phase transitions when a phase is complete.

%% Mark the trial as completed or available based on outcome
% trialRepeatFlag is true for errors, false for completed trials
p.status.trialsArrayRowsPossible(p.trVars.currentTrialsArrayRow) = ...
    p.trData.trialRepeatFlag;

%% Check if current phase is complete
phaseCol = strcmp(p.init.trialArrayColumnNames, 'phaseNumber');
currentPhase = p.status.currentPhase;
inCurrentPhase = p.init.trialsArray(:, phaseCol) == currentPhase;
phaseComplete = ~any(inCurrentPhase & p.status.trialsArrayRowsPossible);

if phaseComplete
    fprintf('========================================\n');
    fprintf('  Phase %d complete! (%d trials)\n', currentPhase, p.init.trialsPerPhaseList(currentPhase));
    fprintf('========================================\n');

    % Check if all phases are complete (session finished)
    if currentPhase >= p.init.nPhases
        fprintf('****************************************\n');
        fprintf('** All %d phases complete!            **\n', p.init.nPhases);
        fprintf('** Session finished: %d trials done.  **\n', p.init.totalTrials);
        fprintf('****************************************\n');

        % Signal session completion - do NOT reset for this task design
        % The session should end after all trials complete
        % nextParams will set exitWhileLoop=true when no trials remain
    else
        % Phase transition message with dynamic reward values
        nextPhase = currentPhase + 1;
        C = p.trVarsInit.rewardDurationMs;
        R = p.trVarsInit.rewardRatioBig;
        smallR = round(C * 1 / (1 + R));
        bigR = round(C * R / (1 + R));
        if nextPhase == 2
            ratioStr = sprintf('1:%.1f (Left=%dms, Right=%dms)', R, smallR, bigR);
        else
            ratioStr = sprintf('%.1f:1 (Left=%dms, Right=%dms)', R, bigR, smallR);
        end
        fprintf('  Transitioning to Phase %d: %s\n', nextPhase, ratioStr);
        fprintf('========================================\n');
    end
end

end
