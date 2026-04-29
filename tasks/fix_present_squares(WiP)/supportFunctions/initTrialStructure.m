function p = initTrialStructure(p)

%
% p = initTrialStructure(p)
% 
% Define the trial types for a single "block" of trials - this includes
% trials with the cue at one angle of elevation and at the diametrically
% opposed elevation (180 degrees away).
%

% column descriptions
% p.init.trialColumnNames = {'number of target stimuli', 'no of trials' 'trialcode'};
p.init.trialArrayColumnNames = {'no of trials', 'trialCode'};

% table definition
switch p.init.exptType
    case 'sparseNoise'
	table = sparseNoiseTable;
    case 'denseNoise'
    	table = denseNoiseTable;
    case 'checkerboard'
    	table = checkerboardTable;
    end
    

% Make "n" copies of each row in the table, where n is in the "no of trials" column.
% Add a column to indicate which rows of the array have been completed in a
% given block. First, initialize the "trials" array to hold the
% repetitions. Next initialize a variable to indicate which row we're
% currently at.
nCols = length(p.init.trialArrayColumnNames);
p.init.trialsArray = zeros(sum(table(:, nCols - 1)), nCols);
currentRow = 1;

% which column tells us how many repetitions of a given trial type will be
% included?
repCol = find(strcmp(p.init.trialArrayColumnNames, 'no of trials'));

% loop over each row of the table.
for i = 1:size(table, 1)
    % how many repetitions of the current row do we need?
    nReps = table(i, repCol);
    
    try
    % place the repeated row into the "trials" array
    p.init.trialsArray(currentRow:(currentRow + nReps - 1), :) = ...
        repmat(table(i, :), nReps, 1);
    catch me
        keyboard
    end
    
    % iterate the "currentRow" variable.
    currentRow = currentRow + nReps;
end

% store length of block
p.init.blockLength = size(p.init.trialsArray, 1);

end


function table = sparseNoiseTable
table = [
    1 24101; ... % sparse noise, 1 reps, 24101 trial code
    ];
end

function table = denseNoiseTable
table = [
    1 24201; ... % dense noise, 1 reps, 24201 trial code
    ];
end

function table = checkerboardTable
table = [
    1 24301; ... % checkerboard, 1 reps, 24301 trial code
    ];
end



