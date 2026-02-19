function p = initTrialStructure(p)

%
% p = initTrialStructure(p)
% 
% Define the trial types for a single "block" of trials - this includes
% trials with the cue at one angle of elevation and at the diametrically
% opposed elevation (180 degrees away).
%

% column descriptions
% p.init.trialColumnNames = {'stim location index', 'change trial', 'stim elevation angle', 'no of trials', 'stimcode'};
p.init.trialArrayColumnNames = {'stimX', 'stimY', 'isVisSac', 'no of trials', 'trialCode'};

% table definition
switch p.init.exptType
    case 'gSac4_v1'
        table = gSac4_v1(p);
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

function table = gSac4_v1(p)
table =           [     p.stim.xy{1}(1)     p.stim.xy{1}(2)     1       4       20101;   % target at location 1, visSac                        
                        p.stim.xy{1}(1)     p.stim.xy{1}(2)     0       4       20100;   % target at location 1, visSac
                        p.stim.xy{2}(1)     p.stim.xy{2}(2)     1       2       20201;   % target at location 1, visSac
                        p.stim.xy{2}(1)     p.stim.xy{2}(2)     0       2       20200;   % target at location 1, visSac
                        p.stim.xy{3}(1)     p.stim.xy{3}(2)     1       4       20301;   % target at location 1, visSac
                        p.stim.xy{3}(1)     p.stim.xy{3}(2)     0       4       20300;   % target at location 1, visSac
                        p.stim.xy{4}(1)     p.stim.xy{4}(2)     1       2       20401;   % target at location 1, visSac
                        p.stim.xy{4}(1)     p.stim.xy{4}(2)     0       2       20400;   % target at location 1, visSac
                 ];
end



