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
% Note: 'rewardAmt' is now included; 'nReps' is no longer used.
p.init.trialArrayColumnNames = {'dist', 'cueFile', 'isFixationRequired', 'isToken', 'trialCode', 'rewardAmt'};

% (2) Use a switch statement to select the trial table based on experiment type.
switch p.init.exptType
    case 'tokens_main'
        p.init.trialsArray = buildTrialsArray_TokensMain();

    case 'tokens_AV'
        p.init.trialArrayColumnNames = {'dist', 'cueFile', 'isFixationRequired', 'isToken', 'avProbability', 'trialCode', 'rewardAmt'};
        p.init.trialsArray = buildTrialsArray_TokensAV();

    otherwise
        % Default to the main experiment type if not specified
        warning('p.init.exptType not specified, using ''tokens_main''.');
        p.init.trialsArray = buildTrialsArray_TokensMain();
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


% --- Sub-functions for building trials arrays ---

function trialsArray = buildTrialsArray_TokensMain()
% Builds the complete trialsArray for tokens_main experiment.
% Each row has: {dist, cueFile, isFixationRequired, isToken, trialCode, rewardAmt}
%
% Block contains 8 conditions × 18 trials each = 144 trials per block:
%   3 Normal cues × 18 trials each = 54 trials
%   3 Uniform cues × 18 trials each = 54 trials
%   2 Uncued conditions × 18 trials each = 36 trials

    trialsArray = {};

    % --- Normal Distribution Cues (dist=1) ---
    % Each Normal cue gets 18 trials with bell-curve reward distribution
    trialsArray = [trialsArray; expandCondition(1, 'famNorm_01.jpg', true, true, 27001)];
    trialsArray = [trialsArray; expandCondition(1, 'famNorm_02.jpg', true, true, 27002)];
    trialsArray = [trialsArray; expandCondition(1, 'novNorm_01.jpg', true, true, 27003)];

    % --- Uniform Distribution Cues (dist=2) ---
    % Each Uniform cue gets 9 trials with flat reward distribution
    trialsArray = [trialsArray; expandCondition(2, 'famUni_01.jpg', true, true, 27004)];
    trialsArray = [trialsArray; expandCondition(2, 'famUni_02.jpg', true, true, 27005)];
    trialsArray = [trialsArray; expandCondition(2, 'novUni_01.jpg', true, true, 27006)];

    % --- Uncued Conditions (dist=0) ---
    % Each uncued condition gets 9 trials at mean reward value
    trialsArray = [trialsArray; expandCondition(0, 'blank.jpg', false, true,  27007)];
    trialsArray = [trialsArray; expandCondition(0, 'blank.jpg', false, false, 27008)];
end


function trialsArray = buildTrialsArray_TokensAV()
% Builds the complete trialsArray for tokens_AV experiment.
% Each row has: {dist, cueFile, isFixationRequired, isToken, avProbability, trialCode, rewardAmt}
%
% Block contains 14 conditions × 18 trials each = 252 trials per block:
%   6 Normal cues × 18 trials each = 108 trials
%   6 Uniform cues × 18 trials each = 108 trials
%   2 Uncued conditions × 18 trials each = 36 trials

    trialsArray = {};

    % --- Normal Distribution, Familiar Cues ---
    trialsArray = [trialsArray; expandConditionAV(1, 'famNorm_01.jpg', true, true, 0,   28001)];
    trialsArray = [trialsArray; expandConditionAV(1, 'famNorm_02.jpg', true, true, 0.5, 28002)];
    trialsArray = [trialsArray; expandConditionAV(1, 'famNorm_03.jpg', true, true, 1,   28003)];

    % --- Normal Distribution, Novel Cues ---
    trialsArray = [trialsArray; expandConditionAV(1, 'novNorm_01.jpg', true, true, 0,   28004)];
    trialsArray = [trialsArray; expandConditionAV(1, 'novNorm_02.jpg', true, true, 0.5, 28005)];
    trialsArray = [trialsArray; expandConditionAV(1, 'novNorm_03.jpg', true, true, 1,   28006)];

    % --- Uniform Distribution, Familiar Cues ---
    trialsArray = [trialsArray; expandConditionAV(2, 'famUni_01.jpg', true, true, 0,   28007)];
    trialsArray = [trialsArray; expandConditionAV(2, 'famUni_02.jpg', true, true, 0.5, 28008)];
    trialsArray = [trialsArray; expandConditionAV(2, 'famUni_03.jpg', true, true, 1,   28009)];

    % --- Uniform Distribution, Novel Cues ---
    trialsArray = [trialsArray; expandConditionAV(2, 'novUni_01.jpg', true, true, 0,   28010)];
    trialsArray = [trialsArray; expandConditionAV(2, 'novUni_02.jpg', true, true, 0.5, 28011)];
    trialsArray = [trialsArray; expandConditionAV(2, 'novUni_03.jpg', true, true, 1,   28012)];

    % --- Uncued Control Conditions ---
    trialsArray = [trialsArray; expandConditionAV(0, 'blank.jpg', false, true,  NaN, 28013)];
    trialsArray = [trialsArray; expandConditionAV(0, 'blank.jpg', false, false, NaN, 28014)];
end


function rows = expandCondition(dist, cueFile, isFixReq, isToken, trialCode)
% Expands a single condition into multiple rows based on the reward distribution.
% For tokens_main format: {dist, cueFile, isFixationRequired, isToken, trialCode, rewardAmt}

    [values, frequencies] = getRewardDistribution(dist);

    rows = {};
    for i = 1:length(values)
        for j = 1:frequencies(i)
            rows{end+1, 1} = dist;
            rows{end, 2} = cueFile;
            rows{end, 3} = isFixReq;
            rows{end, 4} = isToken;
            rows{end, 5} = trialCode;
            rows{end, 6} = values(i);
        end
    end
end


function rows = expandConditionAV(dist, cueFile, isFixReq, isToken, avProb, trialCode)
% Expands a single condition into multiple rows based on the reward distribution.
% For tokens_AV format: {dist, cueFile, isFixationRequired, isToken, avProbability, trialCode, rewardAmt}

    [values, frequencies] = getRewardDistribution(dist);

    rows = {};
    for i = 1:length(values)
        for j = 1:frequencies(i)
            rows{end+1, 1} = dist;
            rows{end, 2} = cueFile;
            rows{end, 3} = isFixReq;
            rows{end, 4} = isToken;
            rows{end, 5} = avProb;
            rows{end, 6} = trialCode;
            rows{end, 7} = values(i);
        end
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