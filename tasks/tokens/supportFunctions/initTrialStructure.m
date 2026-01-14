function p = initTrialStructure(p)
%
% p = initTrialStructure(p)
%
% Defines the trial structure for the 'tokens' Pavlovian task.
% Uses a switch statement on p.init.exptType to select a table of
% trial conditions, which is then used to generate the block.
%
% REWARD DISTRIBUTION APPROACH (updated):
% Rather than generating reward amounts at runtime via random number
% generation, this function now pre-specifies the exact rewardAmt for each
% trial. This guarantees that both Normal and Uniform distributions span
% the same range of integer values (1-9) with the same mean (5).
%
% All conditions have 18 trials each, ensuring equal condition frequency:
%   Normal-like: [1,1,2,3,4,3,2,1,1] frequencies for values 1-9 (18 trials/cue)
%   Uniform:     [2,2,2,2,2,2,2,2,2] frequencies for values 1-9 (18 trials/cue)
%   Fixed:       18 trials at value 5 (for uncued conditions)
%
% Block sizes:
%   tokens_main: 8 conditions × 18 = 144 trials
%   tokens_AV:   14 conditions × 18 = 252 trials

% (1) Define the column names for the trial conditions table.
% Note: 'rewardAmt' is pre-specified; 'nReps' is used in trialsTable for expansion.
% The trialsArray (expanded version) does NOT include 'nReps'.
p.init.trialArrayColumnNames = {'dist', 'cueFile', 'isFixationRequired', 'isToken', 'trialCode', 'rewardAmt', 'nReps'};

% (2) Use a switch statement to select the trial table based on experiment type.
% Build a compact trialsTable, then expand it into trialsArray.
switch p.init.exptType
    case 'tokens_main'
        p.init.trialsTable = buildTrialsTable_TokensMain();
        p.init.trialsArray = expandTrialsTable(p.init.trialsTable, p.init.trialArrayColumnNames);

    case 'tokens_AV'
        p.init.trialArrayColumnNames = {'dist', 'cueFile', 'isFixationRequired', 'isToken', 'avProbability', 'trialCode', 'rewardAmt', 'nReps'};
        p.init.trialsTable = buildTrialsTable_TokensAV();
        p.init.trialsArray = expandTrialsTable(p.init.trialsTable, p.init.trialArrayColumnNames);

    otherwise
        % Default to the main experiment type if not specified
        warning('p.init.exptType not specified, using ''tokens_main''.');
        p.init.trialsTable = buildTrialsTable_TokensMain();
        p.init.trialsArray = expandTrialsTable(p.init.trialsTable, p.init.trialArrayColumnNames);
end

% (3) Store block length
p.init.blockLength = size(p.init.trialsArray, 1);

% (4) Initialize the logical array that tracks which trials are available
%    to be chosen within the current block.
p.status.trialsArrayRowsPossible = true(p.init.blockLength, 1);

% (5) Initialize block and overall trial counters.
p.status.blockNumber = 1;
p.status.iTrial = 0;

end


% --- Sub-functions for building trials tables ---

function trialsTable = buildTrialsTable_TokensMain()
% Builds the compact trialsTable for tokens_main experiment.
% Each row has: {dist, cueFile, isFixationRequired, isToken, trialCode, rewardAmt, nReps}
%
% This is a compact representation where each unique (condition, rewardAmt) pair
% is one row, with nReps specifying how many times it appears in a block.
%
% Block contains 8 conditions × 18 trials each = 144 trials per block:
%   3 Normal cues × 18 trials each = 54 trials
%   3 Uniform cues × 18 trials each = 54 trials
%   2 Uncued conditions × 18 trials each = 36 trials

    trialsTable = {};

    % --- Normal Distribution Cues (dist=1) ---
    % Each Normal cue gets 18 trials with bell-curve reward distribution
    trialsTable = [trialsTable; buildCondition(1, 'famNorm_01.jpg', true, true, 27001)];
    trialsTable = [trialsTable; buildCondition(1, 'famNorm_02.jpg', true, true, 27002)];
    trialsTable = [trialsTable; buildCondition(1, 'novNorm_01.jpg', true, true, 27003)];

    % --- Uniform Distribution Cues (dist=2) ---
    % Each Uniform cue gets 18 trials with flat reward distribution
    trialsTable = [trialsTable; buildCondition(2, 'famUni_01.jpg', true, true, 27004)];
    trialsTable = [trialsTable; buildCondition(2, 'famUni_02.jpg', true, true, 27005)];
    trialsTable = [trialsTable; buildCondition(2, 'novUni_01.jpg', true, true, 27006)];

    % --- Uncued Conditions (dist=0) ---
    % Each uncued condition gets 18 trials at mean reward value
    trialsTable = [trialsTable; buildCondition(0, 'blank.jpg', false, true,  27007)];
    trialsTable = [trialsTable; buildCondition(0, 'blank.jpg', false, false, 27008)];
end


function trialsTable = buildTrialsTable_TokensAV()
% Builds the compact trialsTable for tokens_AV experiment.
% Each row has: {dist, cueFile, isFixationRequired, isToken, avProbability, trialCode, rewardAmt, nReps}
%
% This is a compact representation where each unique (condition, rewardAmt) pair
% is one row, with nReps specifying how many times it appears in a block.
%
% Block contains 14 conditions × 18 trials each = 252 trials per block:
%   6 Normal cues × 18 trials each = 108 trials
%   6 Uniform cues × 18 trials each = 108 trials
%   2 Uncued conditions × 18 trials each = 36 trials

    trialsTable = {};

    % --- Normal Distribution, Familiar Cues ---
    trialsTable = [trialsTable; buildConditionAV(1, 'famNorm_01.jpg', true, true, 0,   28001)];
    trialsTable = [trialsTable; buildConditionAV(1, 'famNorm_02.jpg', true, true, 0.5, 28002)];
    trialsTable = [trialsTable; buildConditionAV(1, 'famNorm_03.jpg', true, true, 1,   28003)];

    % --- Normal Distribution, Novel Cues ---
    trialsTable = [trialsTable; buildConditionAV(1, 'novNorm_01.jpg', true, true, 0,   28004)];
    trialsTable = [trialsTable; buildConditionAV(1, 'novNorm_02.jpg', true, true, 0.5, 28005)];
    trialsTable = [trialsTable; buildConditionAV(1, 'novNorm_03.jpg', true, true, 1,   28006)];

    % --- Uniform Distribution, Familiar Cues ---
    trialsTable = [trialsTable; buildConditionAV(2, 'famUni_01.jpg', true, true, 0,   28007)];
    trialsTable = [trialsTable; buildConditionAV(2, 'famUni_02.jpg', true, true, 0.5, 28008)];
    trialsTable = [trialsTable; buildConditionAV(2, 'famUni_03.jpg', true, true, 1,   28009)];

    % --- Uniform Distribution, Novel Cues ---
    trialsTable = [trialsTable; buildConditionAV(2, 'novUni_01.jpg', true, true, 0,   28010)];
    trialsTable = [trialsTable; buildConditionAV(2, 'novUni_02.jpg', true, true, 0.5, 28011)];
    trialsTable = [trialsTable; buildConditionAV(2, 'novUni_03.jpg', true, true, 1,   28012)];

    % --- Uncued Control Conditions ---
    trialsTable = [trialsTable; buildConditionAV(0, 'blank.jpg', false, true,  NaN, 28013)];
    trialsTable = [trialsTable; buildConditionAV(0, 'blank.jpg', false, false, NaN, 28014)];
end


function rows = buildCondition(dist, cueFile, isFixReq, isToken, trialCode)
% Builds compact trialsTable rows for a single condition.
% For tokens_main format: {dist, cueFile, isFixationRequired, isToken, trialCode, rewardAmt, nReps}
%
% Each unique (condition, rewardAmt) pair is one row, with nReps = frequency.

    [values, frequencies] = getRewardDistribution(dist);

    rows = {};
    for i = 1:length(values)
        rows{end+1, 1} = dist;
        rows{end, 2} = cueFile;
        rows{end, 3} = isFixReq;
        rows{end, 4} = isToken;
        rows{end, 5} = trialCode;
        rows{end, 6} = values(i);       % rewardAmt
        rows{end, 7} = frequencies(i);  % nReps
    end
end


function rows = buildConditionAV(dist, cueFile, isFixReq, isToken, avProb, trialCode)
% Builds compact trialsTable rows for a single condition.
% For tokens_AV format: {dist, cueFile, isFixationRequired, isToken, avProbability, trialCode, rewardAmt, nReps}
%
% Each unique (condition, rewardAmt) pair is one row, with nReps = frequency.

    [values, frequencies] = getRewardDistribution(dist);

    rows = {};
    for i = 1:length(values)
        rows{end+1, 1} = dist;
        rows{end, 2} = cueFile;
        rows{end, 3} = isFixReq;
        rows{end, 4} = isToken;
        rows{end, 5} = avProb;
        rows{end, 6} = trialCode;
        rows{end, 7} = values(i);       % rewardAmt
        rows{end, 8} = frequencies(i);  % nReps
    end
end


function [values, frequencies] = getRewardDistribution(dist)
% Returns reward values and their frequencies for a given distribution type.
%
% All distributions span range [1, 9] with mean = 5.
% All distribution types yield 18 trials, ensuring each condition is
% equally likely to occur within a block.
%
% dist = 1 (Normal-like): Moderate bell curve, 18 trials total
%        Center value (5) appears 4×, extremes (1,9) appear 1×
% dist = 2 (Uniform): Flat distribution, 18 trials total
%        Each value appears 2×
% dist = 0 (Fixed): For uncued conditions, 18 trials at mean value
%        Value 5 appears 18×

    switch dist
        case 1  % Normal-like distribution
            values = 1:9;
            frequencies = [1, 1, 2, 3, 4, 3, 2, 1, 1];  % sum = 18

        case 2  % Uniform distribution
            values = 1:9;
            frequencies = [2, 2, 2, 2, 2, 2, 2, 2, 2];  % sum = 18

        case 0  % Fixed (uncued conditions)
            values = 5;
            frequencies = 18;  % 18 trials at mean value

        otherwise
            error('Unknown distribution type: %d', dist);
    end
end


function trialsArray = expandTrialsTable(table, colNames)
% Expands a compact trialsTable into the full trialsArray.
%
% Input:
%   table    - Compact cell array where each row is a unique trial type
%              with an 'nReps' column specifying repetitions.
%   colNames - Cell array of column names (must include 'nReps').
%
% Output:
%   trialsArray - Expanded cell array where each row is one trial.
%                 The 'nReps' column is excluded from the output.
%
% This function is called at initialization and after each block completes
% (via generateTrialsArray in updateTrialsList.m) to create a fresh pool
% of trials for sampling.

    % Find the 'nReps' column
    repCol = strcmp(colNames, 'nReps');

    trialsArray = {};

    for i = 1:size(table, 1)
        % Get the number of repetitions for this trial type
        nReps = table{i, repCol};

        % Get all columns except 'nReps'
        rowData = table(i, ~repCol);

        % Replicate this row nReps times
        for j = 1:nReps
            trialsArray(end+1, :) = rowData;
        end
    end
end