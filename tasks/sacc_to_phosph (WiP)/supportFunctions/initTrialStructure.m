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
p.init.trialArrayColumnNames = {'trialType', 'stimAmplitude', ...
    'cmdPeriod', 'cmdRepeats', 'cmdSeqLength', 'cmdSeqIPI', ... 
    'no of trials', 'trialCode'};

% table definition
switch p.init.exptType
    case 'pick_one_channel'
        table = pick_one_channel_table;
    case 'pick_all_channels'
        table = pick_all_channels_table;
    case 'random_sample'
        table = random_sample_table;

        % initialize ampVals variable and status variables for microstim
        % Note: Doing it here because it depends on the trial structure
        tempShortTable = table;
        tempShortTable (tempShortTable(:, 7) == 0, :) = [];
        p.trVarsInit.ampVals = unique(tempShortTable(:, 2));
        p.status.microstimNumHits = zeros (64, numel(p.trVarsInit.ampVals));
        p.status.microstimNumMisses = zeros (64, numel(p.trVarsInit.ampVals));
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

% For the "pick one channel" version of the task. Note that stim parameters
% are defined in the settings file or in the GUI for this version
function table = pick_one_channel_table
table = [
    1 0 0 0 0 0 15 24001; ... % visual stimulus, 24001 trial code

    2 0 0 0 0 0 0 24002; ... % One-channel microstimulation, 24002 trial code

    3 0 0 0 0 0 50 24003; ... % no stimulus, 24003 trial code

    4 0 0 0 0 0 0 24004; ... % Two-channel microstimulation, opposite polarity, 24004 trial code

    5 0 0 0 0 0 35 24005; ... % N-channel microstimulation, same polarity, 24005 trial code
    
    8 0 0 0 0 0 0 24008; ... % Biomimetic microstimulation, N-channel, 24008 trial code
    ];
end

% For the "pick all channels" version of the task. Note that stim parameters
% are defined in the settings file or in the GUI for this version
function table = pick_all_channels_table
table = [
    1 0 0 0 0 0 1 24001; ... % visual stimulus, 24001 trial code

    3 0 0 0 0 0 1 24003; ... % no stimulus, 24003 trial code

    6 0 0 0 0 0 0 24006; ... % microstimulation, 24006 trial code
    ];
end

% For the "random sample" version of the task. We pick which 
function table = random_sample_table
table = [
    1 0 0 0 0 0 2 24001; ... % visual stimulus, 24001 trial code

    3 0 0 0 0 0 6 24003; ... % no stimulus, 24003 trial code

    % 100 Hz
    7 1 100 20 3 2 1 24007; ... % microstimulation, 24007 trial code
    7 12 100 20 3 2 1 24007; ... % microstimulation, 24007 trial code
    7 24 100 20 3 2 1 24007; ... % microstimulation, 24007 trial code
    7 36 100 20 3 2 1 24007; ... % microstimulation, 24007 trial code
    7 48 100 20 3 2 1 24007; ... % microstimulation, 24007 trial code

    % 200 Hz
    7 1 100 20 4 2 1 24007; ... % microstimulation, 24007 trial code
    7 12 100 20 4 2 1 24007; ... % microstimulation, 24007 trial code
    7 24 100 20 4 2 1 24007; ... % microstimulation, 24007 trial code
    7 36 100 20 4 2 1 24007; ... % microstimulation, 24007 trial code
    7 48 100 20 4 2 1 24007; ... % microstimulation, 24007 trial code

	%300 Hz	
    7 1 100 20 5 2 1 24007; ... % microstimulation, 24007 trial code
    7 12 100 20 5 2 1 24007; ... % microstimulation, 24007 trial code
    7 24 100 20 5 2 1 24007; ... % microstimulation, 24007 trial code
    7 36 100 20 5 2 1 24007; ... % microstimulation, 24007 trial code
    7 48 100 20 5 2 1 24007; ... % microstimulation, 24007 trial code
    ];
end


