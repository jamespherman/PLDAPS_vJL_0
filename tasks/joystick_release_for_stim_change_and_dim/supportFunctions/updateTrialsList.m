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
% "p.status.blockNumber" and either reset 
% "p.status.trialsArrayRowsPossible" OR if a new trial structure is needed
% for the next block, update p.init.trialsArray; also reset the vector of
% trials that will have free reward available.
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

     % define a vector of booleans to determine which trials will have a
    % free reward after they're completed and which will not:
    p.status.freeRewardAvailable = false(p.init.blockLength, 1);

    % how many free rewards per block?
    nFreeRewards = ceil(p.init.blockLength / 10);

    % pick trials to have free rewards:
    p.status.freeRewardsAvailable(...
        randi(p.init.blockLength, [nFreeRewards, 1])) = true;
end

end

function p = generateTrialsArray(p)

% if this is the 'nfl_shortBlocks' experiment, we need to alternate between
% "table1" and "table2" each block, if this is 'nfl' or 'nfl_50' we need to
% repeat "table2" indefinitely.
if strcmp(p.init.exptType, 'nfl_shortBlocks')
    
    % if this is an even block, use table2, otherwise use table1
    if round(p.status.blockNumber / 2) == (p.status.blockNumber / 2)
        table = p.init.trialsTable2;
    else
        table = p.init.trialsTable1;
    end
elseif strncmp(p.init.exptType, 'nfl', 3)
    table = p.init.trialsTable2;
else
    table = p.init.trialsTable;
end

% how many columns will the trials array have?
nCols   = length(p.init.trialArrayColumnNames);

% which column tells us how many repetitions of a given trial type will be
% included?
repCol = find(strcmp(p.init.trialArrayColumnNames, 'no of trials'));

% make an empty "trialsArray"
trialsArray = zeros(sum(table(:, repCol)), nCols);

% initate index tracking what row of the trials array has been generated as
% we loop through the trials table.
currentRow = 1;

% loop over each row of the table.
for i = 1:size(table, 1)
    
    % how many repetitions of the current row do we need?
    nReps = table(i, repCol);

    % place the repeated row into the "trials" array
    trialsArray(currentRow:(currentRow + nReps - 1), :) = ...
        repmat([table(i, :), 0, 0], nReps, 1);

    % iterate the "currentRow" variable.
    currentRow = currentRow + nReps;
end

% add trial seed and stim seed values
trialsArray(:, strcmp(p.init.trialArrayColumnNames, 'trial seed')) = ...
    randi(2^15-1, sum(table(:, repCol)), 1);
trialsArray(:, strcmp(p.init.trialArrayColumnNames, 'stim seed')) = ...
    randi(2^15-1, sum(table(:, repCol)), 1);

% duplicate all rows of the trialsArray
% trialsArray = repmat(trialsArray, 2, 1);

% store trialsarray
p.init.trialsArray = trialsArray;

% store length of block
p.init.blockLength = size(p.init.trialsArray, 1);

end