function p = initTrialStructure(p)

%
% p = initTrialStructure(p)
% 
% Define the trial types for a single "block" of trials - this includes
% trials with the cue at one angle of elevation and at the diametrically
% opposed elevation (180 degrees away).
%

% column descriptions
p.init.trialColumnNames = {'stim location index', 'change trial', 'stim elevation angle', 'no of trials', 'stimcode'};

% table definition
switch p.init.exptType
    case 'all_locs'
        table = all_locs;
    case 'two_locs'
        table = two_locs;
end          

% Make "n" copies of each row in the table, where n is in the 8th column.
% Add a column to indicate which rows of the array have been completed in a
% given block. First, initialize the "trials" array to hold the
% repetitions. Next initialize a variable to indicate which row we're
% currently at.
nCols = length(p.init.trialColumnNames);
p.init.trialsArray = zeros(sum(table(:, nCols - 1)), nCols);
currentRow = 1;

% loop over each row of the table.
for i = 1:size(table, 1)
    % how many repetitions of the current row do we need?
    nReps = table(i, nCols - 1);
    
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

% redefine finish, we only want to run 1 block!
p.trVars.finish = p.init.blockLength;

end

function table = all_locs
table =           [     1            1                0               5            24001;   % target at location 1
                        
                        2            1                60              5            24003;   % target at location 2
                        
                        3            1                120             5            24005;   % target at location 3
                        
                        4            1                180             5            24007;   % target at location 4
                        
                        5            1                240             5            24009;   % target at location 5
                        
                        6            1                300             5            24011;   % target at location 6
                 ];
end

function table = two_locs
table =           [     1            1                0               16           24001;   % target at location 1
                        
                        2            1                60              16           24003;   % target at location 2
                        
                        3            1                120             16           24005;   % target at location 3
                        
                        4            1                180             16           24007;   % target at location 4
                        
                        5            1                240             16           24009;   % target at location 5
                        
                        6            1                300             16           24011;   % target at location 6
                 ];
end