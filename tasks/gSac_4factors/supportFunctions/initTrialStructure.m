function p = initTrialStructure(p)
%   p = initTrialStructure(p)
%
% Builds the trial array defining all trial types for the experiment.
% Called once during initialization from gSac_4factors_init.m.
%
% The trial array contains one row per trial condition, with columns
% specifying factorial conditions (location, stimulus type, reward, etc.)

%% 1. Define column names for the trial array
% This defines what each column in the trial array represents
p.init.trialArrayColumnNames = {...
    'halfBlock', ...    % Which half-block (1-4)
    'targetLocIdx', ... % Target location index (1-4)
    'stimType', ...     % Stimulus type (1-6, see fourFactorsTable)
    'salience', ...     % Salience level (0=image, 1=high, 2=low)
    'reward', ...       % Reward level (1=high, 2=low)
    'targetColor', ...  % Target color code
    'numTrials', ...    % Number of repetitions
    'trialCode'};       % Unique code for this condition

%% 2. Get the recipe table based on experiment type
switch p.init.exptType
    case 'gSac_4factors'
        % 4-factor experiment with 6 stimulus conditions
        table = fourFactorsTable;
    otherwise
        error('p.init.exptType is not valid');
end

%% 3. Expand the recipe table into the final trial array
% Each row in the recipe table specifies numTrials repetitions
nCols = length(p.init.trialArrayColumnNames);
p.init.trialsArray = zeros(sum(table(:, nCols - 1)), nCols);
currentRow = 1;

% Loop over each row of the recipe table
for i = 1:size(table, 1)
    % Get number of repetitions for this condition
    numTrialsCol = contains(p.init.trialArrayColumnNames, 'numTrials');
    nReps = table(i, numTrialsCol);

    if nReps > 0
        % Replicate this row nReps times in the trial array
        p.init.trialsArray(currentRow:(currentRow + nReps - 1), :) = ...
            repmat(table(i, :), nReps, 1);
        currentRow = currentRow + nReps;
    end
end

%% 4. Shuffle trials within each block
% Randomizes trial order while respecting block structure
nTrials = size(p.init.trialsArray, 1);

% Calculate number of blocks (2 half-blocks per block)
nBlocks = p.init.trialsArray(end, 1) / 2;
nTrialsPerBlock = nTrials / nBlocks;

shuffledArray = [];
for i_block = 1:nBlocks
    % Get row indices for this block
    block_start_row = (i_block - 1) * nTrialsPerBlock + 1;
    block_end_row = i_block * nTrialsPerBlock;

    % Extract trials for this block
    current_block_trials = ...
        p.init.trialsArray(block_start_row:block_end_row, :);

    % Shuffle rows within the block
    shuffled_block = ...
        current_block_trials(randperm(size(current_block_trials, 1)), :);

    % Append to master shuffled array
    shuffledArray = [shuffledArray; shuffled_block]; %#ok<AGROW>
end

p.init.trialsArray = shuffledArray;

%% 5. Add completion tracking column
% Tracks which trials have been completed (0 = not completed)
p.init.trialsArray(:, end+1) = 0;
p.init.trialArrayColumnNames{end+1} = 'completed';

% Create logical array tracking which trials are still available
p.status.trialsArrayRowsPossible = ...
    true(size(p.init.trialsArray, 1), 1);

end


%% ==================== RECIPE TABLE GENERATOR ====================

function table = fourFactorsTable
% Generates the master recipe table for the gSac_4factors experiment.
% Creates a factorial design with 6 stimulus conditions across 4 target
% locations, 2 blocks (4 half-blocks), with location probability and
% reward manipulations.
%
% Stimulus Types:
%   1: Face image
%   2: Non-face image
%   3: Bullseye - High salience, Target hue A (0 deg DKL)
%   4: Bullseye - Low salience, Target hue A (0 deg DKL)
%   5: Bullseye - High salience, Target hue B (180 deg DKL)
%   6: Bullseye - Low salience, Target hue B (180 deg DKL)

%% Define stimulus condition mapping
% Columns: [stimType, salience, targetColor]
% salience: 0=N/A (image), 1=high, 2=low
% targetColor: 0=N/A (image), 1=hue A, 2=hue B
stim_condition_map = [ ...
    1, 0, 0; ...  % Face
    2, 0, 0; ...  % Non-Face
    3, 1, 1; ...  % High salience, Hue A
    4, 2, 1; ...  % Low salience, Hue A
    5, 1, 2; ...  % High salience, Hue B
    6, 2, 2; ...  % Low salience, Hue B
    ];

n_stim_conditions = size(stim_condition_map, 1);
n_half_blocks = 4;
n_locations = 4;

%% Pre-allocate the recipe table
% Total rows: 4 half-blocks x 4 locations x 6 stimulus conditions = 96
table = zeros(n_half_blocks * n_locations * n_stim_conditions, 8);

%% Build the recipe table row by row
current_row = 1;

for i_half_block = 1:n_half_blocks

    % Determine which block this half-block belongs to
    block_num = ceil(i_half_block / 2);

    % Set high-probability location for this block
    % Block 1: location 1 is high-prob; Block 2: location 3 is high-prob
    if block_num == 1
        high_prob_loc = 1;
    else
        high_prob_loc = 3;
    end

    % Determine if this is first or second half of the block
    % Used to alternate which hemifield gets high reward
    is_first_half_of_block = mod(i_half_block, 2) == 1;

    for i_loc = 1:n_locations
        for i_stim = 1:n_stim_conditions

            % Get stimulus properties from mapping table
            stimType    = stim_condition_map(i_stim, 1);
            salience    = stim_condition_map(i_stim, 2);
            targetColor = stim_condition_map(i_stim, 3);

            % Populate row: halfBlock, targetLocIdx, stimType
            table(current_row, 1) = i_half_block;
            table(current_row, 2) = i_loc;
            table(current_row, 3) = stimType;

            % Populate row: salience, targetColor
            table(current_row, 4) = salience;
            table(current_row, 6) = targetColor;

            % Set numTrials based on location probability
            % High-prob location: 5 reps per half-block (10 per block)
            % Low-prob locations: 1 rep per half-block (2 per block)
            if i_loc == high_prob_loc
                table(current_row, 7) = 5;
            else
                table(current_row, 7) = 1;
            end

            % Set reward based on hemifield and half-block
            % Locations 1-2: one hemifield; Locations 3-4: other hemifield
            % Alternates which hemifield is high-reward between halves
            is_loc_in_high_rwd_hemi = (i_loc <= 2);
            if (is_first_half_of_block && is_loc_in_high_rwd_hemi) || ...
                    (~is_first_half_of_block && ~is_loc_in_high_rwd_hemi)
                table(current_row, 5) = 1;  % High reward
            else
                table(current_row, 5) = 2;  % Low reward
            end

            % Generate unique trial code for this condition
            % Format: 26XXX where X encodes block and condition
            condition_code = (i_loc - 1) * n_stim_conditions + i_stim;
            table(current_row, 8) = ...
                26000 + (block_num * 1000) + condition_code;

            current_row = current_row + 1;
        end
    end
end

end
