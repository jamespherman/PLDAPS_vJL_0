function p = initTrialStructure(p)

%
% p = initTrialStructure(p)
% 
% Define the trial types for a single "block" of trials - this includes
% trials with the cue at one angle of elevation and at the diametrically
% opposed elevation (180 degrees away).
%

% column descriptions
p.init.trialArrayColumnNames = {'halfBlock', 'targetLocIdx', ...
    'stimType', 'salience', 'reward', 'colorPair', 'numTrials', ...
    'trialCode'};

% table definition
switch p.init.exptType
    case 'gSac_4factors'
        table = fourFactors;
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

% column descriptions
% p.init.trialArrayColumnNames = {'halfBlock', 'targetLocIdx', ...
%     'stimType', 'salience', 'reward', 'colorPair', 'numTrials', ...
% 'trialCode'};

function table = fourFactors
table =           [            1           1           1           1           1           1
           1           1           1           1           1           2
           1           1           1           2           1           1
           1           1           1           2           1           2
           1           1           2           1           1           1
           1           1           2           1           1           2
           1           1           2           2           1           1
           1           1           2           2           1           2
           1           1           3           1           1           1
           1           1           3           1           1           2
           1           1           3           2           1           1
           1           1           3           2           1           2
           1           2           1           1           1           1
           1           2           1           1           1           2
           1           2           1           2           1           1
           1           2           1           2           1           2
           1           2           2           1           1           1
           1           2           2           1           1           2
           1           2           2           2           1           1
           1           2           2           2           1           2
           1           2           3           1           1           1
           1           2           3           1           1           2
           1           2           3           2           1           1
           1           2           3           2           1           2
           1           3           1           1           2           1
           1           3           1           1           2           2
           1           3           1           2           2           1
           1           3           1           2           2           2
           1           3           2           1           2           1
           1           3           2           1           2           2
           1           3           2           2           2           1
           1           3           2           2           2           2
           1           3           3           1           2           1
           1           3           3           1           2           2
           1           3           3           2           2           1
           1           3           3           2           2           2
           1           4           1           1           2           1
           1           4           1           1           2           2
           1           4           1           2           2           1
           1           4           1           2           2           2
           1           4           2           1           2           1
           1           4           2           1           2           2
           1           4           2           2           2           1
           1           4           2           2           2           2
           1           4           3           1           2           1
           1           4           3           1           2           2
           1           4           3           2           2           1
           1           4           3           2           2           2

           4       21001
           4       21002
           4       21003
           4       21004
           4       21005 
           4       21006
           4       21007
           4       21008
           4       21009
           4       21010
           4       21011
           4       21012
           1       21101
           1       21102
           1       21103
           1       21104
           1       21105
           1       21106
           1       21107
           1       21108
           1       21109
           1       21110
           1       21111
           1       21112
           0       21201
           0       21202
           0       21203
           0       21204
           0       21205
           0       21206
           0       21207
           0       21208
           0       21209
           0       21210
           0       21211
           0       21212
           0       21301
           0       21302
           0       21303
           0       21304
           0       21305
           0       21306
           0       21307
           0       21308
           0       21309
           0       21310
           0       21311
           0       21312
                    ];
end

function table = lowReward
table =           [ 1   1   2   3   24017; ... % target loc 1 | tgt/bkgnd cond 1 | low rwd
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