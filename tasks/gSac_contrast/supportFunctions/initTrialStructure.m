function p = initTrialStructure(p)

%
% p = initTrialStructure(p)
% 
% Define the trial types for a single "block" of trials - this includes
% trials with the cue at one angle of elevation and at the diametrically
% opposed elevation (180 degrees away).
%

% column descriptions
p.init.trialArrayColumnNames = {'targetLocIdx', 'tgtBkgndCond', ...
    'highLowRwd', 'numTrials', 'trialCode'};

% table definition
switch p.init.exptType
    case 'gSac_contrast'
        table = rwdSaliencyTable;
end          

% Make "n" copies of each row in the table, where n is in the 8th column.
% Add a column to indicate which rows of the array have been completed in a
% given block. First, initialize the "trials" array to hold the
% repetitions. Next initialize a variable to indicate which row we're
% currently at.
nCols = length(p.init.trialArrayColumnNames);
p.init.trialsArray = zeros(sum(table(:, nCols - 1)), nCols);
currentRow = 1;

% loop over each row of the table.
for i = 1:size(table, 1)
    % how many repetitions of the current row do we need?
    nReps = table(i, contains(p.init.trialArrayColumnNames, 'numTrials'));
    
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

function table = rwdSaliencyTable
table =           [ 1   1   1   3   24001; ... % target loc 1 | tgt/bkgnd cond 1 | high rwd
                    2   1   1   3   24002; ... % target loc 2 | tgt/bkgnd cond 1 | high rwd
                    1   2   1   3   24003; ... % target loc 1 | tgt/bkgnd cond 2 | high rwd
                    2   2   1   3   24004; ... % target loc 2 | tgt/bkgnd cond 2 | high rwd
                    1   3   1   3   24005; ... % target loc 1 | tgt/bkgnd cond 3 | high rwd
                    2   3   1   3   24006; ... % target loc 2 | tgt/bkgnd cond 3 | high rwd
                    1   4   1   3   24007; ... % target loc 1 | tgt/bkgnd cond 4 | high rwd
                    2   4   1   3   24008; ... % target loc 2 | tgt/bkgnd cond 4 | high rwd
                    1   5   1   3   24009; ... % target loc 1 | tgt/bkgnd cond 5 | high rwd
                    2   5   1   3   24010; ... % target loc 2 | tgt/bkgnd cond 5 | high rwd
                    1   6   1   3   24011; ... % target loc 1 | tgt/bkgnd cond 6 | high rwd
                    2   6   1   3   24012; ... % target loc 2 | tgt/bkgnd cond 6 | high rwd
                    1   7   1   3   24013; ... % target loc 1 | tgt/bkgnd cond 7 | high rwd
                    2   7   1   3   24014; ... % target loc 2 | tgt/bkgnd cond 7 | high rwd
                    1   8   1   3   24015; ... % target loc 1 | tgt/bkgnd cond 8 | high rwd
                    2   8   1   3   24016; ... % target loc 2 | tgt/bkgnd cond 8 | high rwd
                    1   1   2   3   24017; ... % target loc 1 | tgt/bkgnd cond 1 | low rwd
                    2   1   2   3   24018; ... % target loc 2 | tgt/bkgnd cond 1 | low rwd
                    1   2   2   3   24019; ... % target loc 1 | tgt/bkgnd cond 2 | low rwd
                    2   2   2   3   24020; ... % target loc 2 | tgt/bkgnd cond 2 | low rwd
                    1   3   2   3   24021; ... % target loc 1 | tgt/bkgnd cond 3 | low rwd
                    2   3   2   3   24022; ... % target loc 2 | tgt/bkgnd cond 3 | low rwd
                    1   4   2   3   24023; ... % target loc 1 | tgt/bkgnd cond 4 | low rwd
                    2   4   2   3   24024; ... % target loc 2 | tgt/bkgnd cond 4 | low rwd
                    1   5   2   3   24025; ... % target loc 1 | tgt/bkgnd cond 5 | low rwd
                    2   5   2   3   24026; ... % target loc 2 | tgt/bkgnd cond 5 | low rwd
                    1   6   2   3   24027; ... % target loc 1 | tgt/bkgnd cond 6 | low rwd
                    2   6   2   3   24028; ... % target loc 2 | tgt/bkgnd cond 6 | low rwd
                    1   7   2   3   24029; ... % target loc 1 | tgt/bkgnd cond 7 | low rwd
                    2   7   2   3   24030; ... % target loc 2 | tgt/bkgnd cond 7 | low rwd
                    1   8   2   3   24031; ... % target loc 1 | tgt/bkgnd cond 8 | low rwd
                    2   8   2   3   24032;...  % target loc 2 | tgt/bkgnd cond 8 | low rwd
                    ];
end