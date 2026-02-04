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
    fprintf('  Phase %d complete! (%d trials)\n', currentPhase, p.init.trialsPerPhase);
    fprintf('========================================\n');

    % Check if all phases are complete (session finished)
    if currentPhase >= p.init.nPhases
        fprintf('****************************************\n');
        fprintf('** All %d phases complete!            **\n', p.init.nPhases);
        fprintf('** Session finished: %d trials done.  **\n', p.init.totalTrials);
        fprintf('****************************************\n');

        % Signal session completion - do NOT reset for this task design
        % The session should end after 384 trials
        % nextParams will set exitWhileLoop=true when no trials remain
    else
        % Phase transition message
        nextPhase = currentPhase + 1;
        if nextPhase == 2
            ratioStr = '1:2 (Left=130ms, Right=260ms)';
        else
            ratioStr = '2:1 (Left=260ms, Right=130ms)';
        end
        fprintf('  Transitioning to Phase %d: %s\n', nextPhase, ratioStr);
        fprintf('========================================\n');
    end
end

end
