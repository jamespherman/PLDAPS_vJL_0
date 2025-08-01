function p = updateTrialsList(p)
%
% p = updateTrialsList(p)
%
% If trial needs to be repeated, shuffle it into the remaining trials. If
% a block has been completed, start a new block.
%

% Mark the appropriate row of p.status.trialsArrayRowsPossible according to
% the outcoe of the previous trial (does it need to be repeated?).
p.status.trialsArrayRowsPossible(p.trVars.currentTrialsArrayRow) = ...
    p.trData.trialRepeatFlag;

% If all the trials in the current block have been completed, update
% "p.status.blockNumber" and either reset "p.status.trialsArrayRowsPossible" OR
% if a new trial structure is needed for the next block, update
% p.init.trialsArray
if ~any(p.status.trialsArrayRowsPossible)
    
    % iterate block number
    p.status.blockNumber = p.status.blockNumber + 1;
    
    % If this is the 2nd block of the "nfl" experiment, we need to generate
    % a new "trialsArray". Do that here. If this is the 3rd block or
    % beyond, we don't NEED to generate a new trialsArray, but we do need
    % new trial and stim seed values - since generating a new trialsArray
    % already accomplishes the goal of new seed values, let's just be lazy
    % and regenerate the trialsArray at the start of each new block.
    p = generateTrialsArray(p);
    
    % reset "p.status.trialsArrayRowsPossible" to all true.
    p.status.trialsArrayRowsPossible = true(p.init.blockLength, 1);
end

end

function p = generateTrialsArray(p)
%
% This function creates the pool of trials (p.init.trialsArray) for a new
% block. It reads the master list of conditions from p.init.trialsTable
% and unpacks it based on the number of repetitions for each condition.

    % Get the master table of unique conditions, which was defined once
    % in the initTrialStructure function.
    table = p.init.trialsTable;
    
    % Find the column that specifies the number of repetitions ('nReps').
    repCol = contains(p.init.trialArrayColumnNames, 'nReps');
    
    % Initialize an empty cell array to hold the full trial list for the block.
    trialsArray = {};
    
    % Loop through each unique condition in the master table.
    for i = 1:size(table, 1)
        % How many repetitions of this condition do we need for the block?
        nReps = table{i, repCol};
        
        % Append this condition to the main list 'nReps' times.
        for j = 1:nReps
            % Exclude the final 'nReps' column from the generated trials array.
            trialsArray(end+1, :) = table(i, 1:end-1);
        end
    end

    % Store the newly generated trials array and the block length.
    % This array is the unshuffled pool that 'chooseRow' will sample from.
    p.init.trialsArray = trialsArray;
    p.init.blockLength = size(p.init.trialsArray, 1);
    
end