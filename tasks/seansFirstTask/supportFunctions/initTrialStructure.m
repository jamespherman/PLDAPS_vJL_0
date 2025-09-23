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
p.init.trialArrayColumnNames = {'numDots', 'numTargets', 'targsSameColor', 'stimShape','no of trials', 'trialcode'};

% table definition
switch p.init.exptType
    case 'step1'
        table = step1;
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


function table = step1
table = [
    1 1 true 1 0 24001; ... %  one dots, one targets, targets same color, oval stim, 0 reps, 24001 trial code
    1 1 false 1 0 24002; ... % one dots, one targets, targets diff color, oval stim, 0 reps, 24002 trial code
    1 2 true 1 0 24003; ... %  one dots, two targets, targets same color, oval stim, 0 reps, 24003 trial code
    1 2 false 1 5 24004; ... % one dots, two targets, targets diff color, oval stim, 3 reps, 24004 trial code  
    2 1 true 1 0 24005; ... %  two dots, one targets, targets same color, oval stim, 0 reps, 24005 trial code
    2 1 false 1 0 24006; ... % two dots, one targets, targets diff color, oval stim, 0 reps, 24006 trial code    
    2 2 true 1 0 24007; ... %  two dots, two targets, targets same color, oval stim, 0 reps, 24007 trial code
    2 2 false 1 4 24008; ... % two dots, two targets, targets diff color, oval stim, 3 reps, 24008 trial code
    1 1 true 2 0 24001; ... %  one dots, one targets, targets same color, rect stim, 0 reps, 24001 trial code
    1 1 false 2 0 24002; ... % one dots, one targets, targets diff color, rect stim, 0 reps, 24002 trial code
    1 2 true 2 0 24003; ... %  one dots, two targets, targets same color, rect stim, 0 reps, 24003 trial code
    1 2 false 2 5 24004; ... % one dots, two targets, targets diff color, rect stim, 3 reps, 24004 trial code  
    2 1 true 2 0 24005; ... %  two dots, one targets, targets same color, rect stim, 0 reps, 24005 trial code
    2 1 false 2 0 24006; ... % two dots, one targets, targets diff color, rect stim, 0 reps, 24006 trial code    
    2 2 true 2 0 24007; ... %  two dots, two targets, targets same color, rect stim, 0 reps, 24007 trial code
    2 2 false 2 4 24008; ... % two dots, two targets, targets diff color, rect stim, 3 reps, 24008 trial code      
    2 2 false 3 2 24009; ... % two dots, two targets, targets diff color, both stim, 2 reps, 24009 trial code
    ];
end







