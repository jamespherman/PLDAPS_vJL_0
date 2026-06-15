function p = initTrialStructure(p)

%
% p = initTrialStructure(p)
% 
% Define the trial types for a single "block" of trials - this includes
% trials with the cue at one angle of elevation and at the diametrically
% opposed elevation (180 degrees away).
%

% column descriptions
% p.init.trialColumnNames = {'number of target stimuli', 'no of trials' 'trialCode'};
p.init.trialArrayColumnNames = {'trialType', 'no of trials', 'trialCode'};

% table definition
switch p.init.exptType
    case 'pick_one_channel'
        table = pick_one_channel_table;
    case 'pick_all_channels'
        table = pick_all_channels_table;
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


function table = pick_one_channel_table
table = [
    1 0 24001; ... % visual stimulus, 24001 trial code

    2 1 24002; ... % One-channel microstimulation, 24002 trial code

    3 0 24003; ... % no stimulus, 24003 trial code

    4 0 24004; ... % Two-channel microstimulation, opposite polarity, 24004 trial code

    5 0 24005; ... % N-channel microstimulation, same polarity, 24005 trial code
    ];
end


function table = pick_all_channels_table
table = [
    1 0 24001; ... % visual stimulus, 24001 trial code

    3 0 24003; ... % no stimulus, 24003 trial code

    6 2 24006; ... % microstimulation, 24006 trial code
    ];
end




