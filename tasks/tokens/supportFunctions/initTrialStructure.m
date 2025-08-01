function p = initTrialStructure(p)
%
% p = initTrialStructure(p)
%
% Defines the trial structure for the 'tokens' Pavlovian task.
% Uses a switch statement on p.init.exptType to select a table of
% trial conditions, which is then used to generate the block.

% (1) Define the column names for the trial conditions table.
% This is useful for accessing columns by name instead of index.
p.init.trialArrayColumnNames = {'dist', 'cueFile', 'isFixationRequired', 'isToken', 'nReps'};

% (2) Use a switch statement to select the trial table based on experiment type.
% This allows for different versions of the experiment to be run from the same task.
% For now, we will define one main version.
switch p.init.exptType
    case 'tokens_main'
        table = tableDef_TokensMain(p);

        % You could add other cases here for different versions of the task
        % case 'tokens_familiar_only'
        %     table = tableDef_TokensFamiliarOnly(p);

    otherwise
        % Default to the main experiment type if not specified
        warning('p.init.exptType not specified, using ''tokens_main''.');
        table = tableDef_TokensMain(p);
end

% (3) Store table for subsequent use:
p.init.trialsTable = table;

% (4) Unpack the table into a list of trials based on the 'nReps' column.
% This creates the full, unshuffled list of all trials in the block.
p = generateTrialsArray(p);

% (5) Initialize the logical array that tracks which trials are available
%    to be chosen within the current block. This is critical.
p.status.trialsArrayRowsPossible = true(p.init.blockLength, 1);

% (6) Initialize block and overall trial counters.
p.status.blockNumber = 1;
p.status.iTrial = 0;
end


% --- Sub-functions for defining trial tables ---

function table = tableDef_TokensMain(p)
% Defines the 8 core conditions for the main tokens experiment.
% The last column, nReps, is the number of trials of this type per block.

% Get the number of repetitions from the settings file
% This makes it easy to change without editing this function
nReps = p.init.trialsPerCondition;

% Columns: {dist, cueFile, isFixationRequired, isToken, nReps}
table = { ...
    % Normal Distribution Cues (dist=1)
    1, 'famNorm_01.jpg', true, true, nReps; ...
    1, 'famNorm_02.jpg', true, true, nReps; ...
    1, 'novNorm_01.jpg',    true, true, nReps; ...
    % Uniform Distribution Cues (dist=2)
    2, 'famUni_01.jpg',  true, true, nReps; ...
    2, 'famUni_02.jpg',  true, true, nReps; ...
    2, 'novUni_01.jpg',     true, true, nReps; ...
    % Free Reward, Tokens (dist=0)
    0, 'blank.jpg',      false, true, nReps; ...
    % Free Reward, No Tokens (dist=0)
    0, 'blank.jpg',      false, false, nReps; ...
    };
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