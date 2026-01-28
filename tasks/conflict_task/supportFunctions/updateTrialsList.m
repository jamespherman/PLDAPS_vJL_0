function p = updateTrialsList(p)
%   p = updateTrialsList(p)
%
% Updates the trial availability list after each trial.
% If the trial was completed successfully (goal-directed or capture),
% mark it as unavailable. If it was an error, keep it available for repeat.

%% Mark the trial as completed or available based on outcome
% trialRepeatFlag is true for errors, false for completed trials
p.status.trialsArrayRowsPossible(p.trVars.currentTrialsArrayRow) = ...
    p.trData.trialRepeatFlag;

%% Check if current block is complete
blockCol = strcmp(p.init.trialArrayColumnNames, 'blockNumber');
currentBlock = p.status.iBlock;
inCurrentBlock = p.init.trialsArray(:, blockCol) == currentBlock;
blockComplete = ~any(inCurrentBlock & p.status.trialsArrayRowsPossible);

if blockComplete
    fprintf('========================================\n');
    fprintf('  Block %d complete!\n', currentBlock);
    fprintf('========================================\n');

    % Check if all blocks are complete
    if currentBlock >= 6
        fprintf('****************************************\n');
        fprintf('** All 6 blocks complete!             **\n');
        fprintf('** Session finished.                  **\n');
        fprintf('****************************************\n');

        % Could reset for another session loop, or end here
        % For now, reset to allow continued running
        p.status.trialsArrayRowsPossible = ...
            true(size(p.init.trialsArray, 1), 1);
    end
end

end
