function p = initTrialStructure(p)
%   p = initTrialStructure(p)
%
% Builds the trial array for the Conflict Task experiment.
% Called once during initialization from conflict_task_init.m.
%
% Trial Structure:
%   - 6 blocks total (60 trials each = 360 trials per session)
%   - Blocks alternate reward location: A -> B -> A -> B -> A -> B
%   - Each block: 30 Conflict + 30 Congruent trials
%   - Each trial type: 5 trials at each of 6 delta-t values
%   - Trials shuffled within blocks but not across blocks

%% 1. Define column names for the trial array
p.init.trialArrayColumnNames = {...
    'blockNumber', ...      % Block (1-6)
    'trialInBlock', ...     % Trial index within block (1-60)
    'trialType', ...        % 1=CONFLICT, 2=CONGRUENT
    'deltaTIdx', ...        % Index into deltaTValues (1-6)
    'deltaT', ...           % Delta-t value in ms (-150 to +100)
    'highRewardLoc', ...    % Which location has high reward (1=A, 2=B)
    'highSalienceLoc', ...  % Which location has high salience (1=A, 2=B)
    'completed'};           % 0=not done, 1=completed

%% 2. Define trial parameters
nBlocks = 6;
trialsPerBlock = 60;
deltaTValues = [-150, -100, -50, 0, 50, 100];  % ms
nDeltaT = length(deltaTValues);
trialsPerDeltaTPerType = 5;

% Trial types
CONFLICT = 1;
CONGRUENT = 2;

%% 3. Build the complete trial array
totalTrials = nBlocks * trialsPerBlock;
nCols = length(p.init.trialArrayColumnNames);
p.init.trialsArray = zeros(totalTrials, nCols);

currentRow = 1;

for iBlock = 1:nBlocks

    % Determine high reward location for this block
    % Odd blocks: Location A = high reward
    % Even blocks: Location B = high reward
    if mod(iBlock, 2) == 1
        highRewardLoc = 1;  % Location A
    else
        highRewardLoc = 2;  % Location B
    end

    % Build trials for this block
    blockTrials = [];

    for iDeltaT = 1:nDeltaT
        deltaT = deltaTValues(iDeltaT);

        % Add Conflict trials (5 per delta-t)
        for iTrial = 1:trialsPerDeltaTPerType
            % CONFLICT: high salience at LOW reward location
            if highRewardLoc == 1
                highSalienceLoc = 2;  % Salience at B when reward at A
            else
                highSalienceLoc = 1;  % Salience at A when reward at B
            end

            trialRow = [...
                iBlock, ...             % blockNumber
                0, ...                  % trialInBlock (filled after shuffle)
                CONFLICT, ...           % trialType
                iDeltaT, ...            % deltaTIdx
                deltaT, ...             % deltaT
                highRewardLoc, ...      % highRewardLoc
                highSalienceLoc, ...    % highSalienceLoc
                0];                     % completed

            blockTrials = [blockTrials; trialRow]; %#ok<AGROW>
        end

        % Add Congruent trials (5 per delta-t)
        for iTrial = 1:trialsPerDeltaTPerType
            % CONGRUENT: high salience at HIGH reward location
            highSalienceLoc = highRewardLoc;

            trialRow = [...
                iBlock, ...
                0, ...
                CONGRUENT, ...
                iDeltaT, ...
                deltaT, ...
                highRewardLoc, ...
                highSalienceLoc, ...
                0];

            blockTrials = [blockTrials; trialRow]; %#ok<AGROW>
        end
    end

    % Shuffle trials within this block
    shuffleOrder = randperm(size(blockTrials, 1));
    blockTrials = blockTrials(shuffleOrder, :);

    % Fill in trial-within-block indices
    blockTrials(:, 2) = (1:trialsPerBlock)';

    % Add to main array
    p.init.trialsArray(currentRow:(currentRow + trialsPerBlock - 1), :) = ...
        blockTrials;
    currentRow = currentRow + trialsPerBlock;
end

%% 4. Store delta-t values for reference
p.init.deltaTValues = deltaTValues;

%% 5. Create logical array tracking which trials are still available
% For each block, we track which trials remain to be completed
p.status.trialsArrayRowsPossible = true(totalTrials, 1);

%% 6. Print summary
fprintf('----------------------------------------\n');
fprintf('Conflict Task Trial Structure Generated:\n');
fprintf('  Total trials: %d\n', totalTrials);
fprintf('  Blocks: %d\n', nBlocks);
fprintf('  Trials per block: %d\n', trialsPerBlock);
fprintf('  Delta-t values: %s ms\n', mat2str(deltaTValues));
fprintf('  Trials per condition per delta-t: %d\n', trialsPerDeltaTPerType);
fprintf('----------------------------------------\n');

end
