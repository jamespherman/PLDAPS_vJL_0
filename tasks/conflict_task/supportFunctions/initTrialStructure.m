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
    'hueType', ...          % 1 or 2 (counterbalanced background/target hue scheme)
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

% Pre-generate hueType assignments for counterbalancing across the session.
% For each (trialType x deltaTIdx) condition, there are 5 trials/block x 6 blocks = 30 trials.
% We assign 15 to hueType=1 and 15 to hueType=2.
% Distribution per block alternates: 3-2, 2-3, 3-2, 2-3, 3-2, 2-3 to ensure balance.
%
% hueTypeAssignments{trialType, deltaTIdx} = [6x5] array of hueTypes for each block
hueTypeAssignments = cell(2, nDeltaT);
for iType = 1:2
    for iDeltaT = 1:nDeltaT
        assignments = zeros(nBlocks, trialsPerDeltaTPerType);
        for iBlock = 1:nBlocks
            % Alternate 3-2 and 2-3 distribution across blocks
            % Use both iType and iDeltaT to vary the starting pattern
            if mod(iBlock + iType + iDeltaT, 2) == 0
                % 3 of hueType 1, 2 of hueType 2
                assignments(iBlock, :) = [1 1 1 2 2];
            else
                % 2 of hueType 1, 3 of hueType 2
                assignments(iBlock, :) = [1 1 2 2 2];
            end
            % Shuffle within block to randomize which specific trials get which hueType
            assignments(iBlock, :) = assignments(iBlock, randperm(trialsPerDeltaTPerType));
        end
        hueTypeAssignments{iType, iDeltaT} = assignments;
    end
end

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

            % Get counterbalanced hueType for this trial
            hueType = hueTypeAssignments{CONFLICT, iDeltaT}(iBlock, iTrial);

            trialRow = [...
                iBlock, ...             % blockNumber
                0, ...                  % trialInBlock (filled after shuffle)
                CONFLICT, ...           % trialType
                iDeltaT, ...            % deltaTIdx
                deltaT, ...             % deltaT
                highRewardLoc, ...      % highRewardLoc
                highSalienceLoc, ...    % highSalienceLoc
                hueType, ...            % hueType (1 or 2)
                0];                     % completed

            blockTrials = [blockTrials; trialRow]; %#ok<AGROW>
        end

        % Add Congruent trials (5 per delta-t)
        for iTrial = 1:trialsPerDeltaTPerType
            % CONGRUENT: high salience at HIGH reward location
            highSalienceLoc = highRewardLoc;

            % Get counterbalanced hueType for this trial
            hueType = hueTypeAssignments{CONGRUENT, iDeltaT}(iBlock, iTrial);

            trialRow = [...
                iBlock, ...
                0, ...
                CONGRUENT, ...
                iDeltaT, ...
                deltaT, ...
                highRewardLoc, ...
                highSalienceLoc, ...
                hueType, ...            % hueType (1 or 2)
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
fprintf('  HueType counterbalanced: 15 type-1, 15 type-2 per condition\n');
fprintf('----------------------------------------\n');

end
