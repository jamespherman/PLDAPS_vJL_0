function p = initTrialStructure(p)
%   p = initTrialStructure(p)
%
% Builds the trial array for the Conflict Task experiment.
% Called once during initialization from conflict_task_init.m.
%
% Trial Structure:
%   - 3 phases total
%   - Phase 1: 192 trials (64 single-stim FIRST, then 128 dual-stim)
%   - Phase 2: 128 dual-stim trials (~90% big reward RIGHT)
%   - Phase 3: 128 dual-stim trials (~90% big reward LEFT)
%
% Dual-stimulus conditions per phase (128 unique):
%   - 16 target location pairs (4 left x 4 right)
%   - 2 background hue conditions (Hue A vs Hue B)
%   - 2 high salience sides (left vs right)
%   - 2 delta-t values (-150ms, +150ms)
%   16 x 2 x 2 x 2 = 128
%
% Single-stimulus trials (Phase 1 only, 64 total):
%   - High-salience target only (no distractor)
%   - 32 left-target + 32 right-target
%   - Per side: 4 locations x 2 hues x 2 deltaT = 16 conditions x 2 reps
%   - All single-stim trials occur at the BEGINNING of Phase 1
%
% Reward assignment (rewardBigSide column):
%   - Phase 1: 50/50 pseudorandom, counterbalanced within highSalienceSide
%   - Phase 2: ~rewardProbHigh canonical (big-right), rest flipped
%   - Phase 3: ~rewardProbHigh canonical (big-left), rest flipped
%
% Trials are shuffled within sub-blocks but not across phases.

%% 1. Define column names for the trial array
p.init.trialArrayColumnNames = {...
    'phaseNumber', ...      % 1, 2, or 3
    'trialInPhase', ...     % Trial index within phase
    'leftLocIdx', ...       % Index into leftAngles (1-4)
    'rightLocIdx', ...      % Index into rightAngles (1-4)
    'backgroundHueIdx', ... % 1=Hue A (0 deg DKL target), 2=Hue B (180 deg DKL target)
    'highSalienceSide', ... % 1=left, 2=right
    'deltaTIdx', ...        % Index into deltaTValues (1 or 2)
    'deltaT', ...           % Delta-t value in ms (-150 or +150)
    'singleStimSide', ...   % 0=dual, 1=single-left, 2=single-right
    'rewardBigSide', ...    % 1=big-left, 2=big-right (per-trial reward assignment)
    'completed'};           % 0=not done, 1=completed

% Build column index lookup
colNames = p.init.trialArrayColumnNames;
for iCol = 1:length(colNames)
    cols.(colNames{iCol}) = iCol;
end

%% 2. Define trial parameters
nPhases = 3;
dualTrialsPerPhase = 128;
singleStimTrialsPhase1 = 64;  % 32 left + 32 right
trialsPhase1 = dualTrialsPerPhase + singleStimTrialsPhase1;  % 192
nSingleStimReps = 2;  % repetitions per single-stim condition

% Target location parameters
nLeftLocs = 4;      % Number of left-side target locations
nRightLocs = 4;     % Number of right-side target locations
nLocPairs = nLeftLocs * nRightLocs;  % = 16

% Background hue conditions (for counterbalancing)
nBackgroundHues = 2;  % Hue A (0 deg) and Hue B (180 deg)

% High salience side
nSalienceSides = 2;  % Left or Right

% Delta-t values
deltaTValues = [-150, 150];  % ms
nDeltaT = length(deltaTValues);

% Reward parameters from settings
rewardRatioBig = p.trVarsInit.rewardRatioBig;
rewardProbHigh = p.trVarsInit.rewardProbHigh;

% Verify dual-stimulus condition count
nDualConditions = nLocPairs * nBackgroundHues * nSalienceSides * nDeltaT;
assert(nDualConditions == dualTrialsPerPhase, ...
    'Dual-stim condition count mismatch: expected %d, got %d', ...
    dualTrialsPerPhase, nDualConditions);

% Verify single-stimulus condition count
nSingleCondPerSide = max(nLeftLocs, nRightLocs) * nBackgroundHues * nDeltaT;
assert(nSingleCondPerSide * nSingleStimReps * 2 == singleStimTrialsPhase1, ...
    'Single-stim condition count mismatch: expected %d, got %d', ...
    singleStimTrialsPhase1, nSingleCondPerSide * nSingleStimReps * 2);

%% 3. Build the complete trial array
totalTrials = trialsPhase1 + (nPhases - 1) * dualTrialsPerPhase;  % 192 + 256 = 448
nCols = length(p.init.trialArrayColumnNames);
p.init.trialsArray = zeros(totalTrials, nCols);

currentRow = 1;

for iPhase = 1:nPhases

    % Build all dual-stimulus conditions for this phase (128 trials)
    phaseTrials = [];

    for iLeftLoc = 1:nLeftLocs
        for iRightLoc = 1:nRightLocs
            for iBgHue = 1:nBackgroundHues
                for iSalSide = 1:nSalienceSides
                    for iDeltaT = 1:nDeltaT

                        deltaT = deltaTValues(iDeltaT);

                        trialRow = zeros(1, nCols);
                        trialRow(cols.phaseNumber)      = iPhase;
                        trialRow(cols.trialInPhase)     = 0;  % filled after shuffle
                        trialRow(cols.leftLocIdx)       = iLeftLoc;
                        trialRow(cols.rightLocIdx)      = iRightLoc;
                        trialRow(cols.backgroundHueIdx) = iBgHue;
                        trialRow(cols.highSalienceSide) = iSalSide;
                        trialRow(cols.deltaTIdx)        = iDeltaT;
                        trialRow(cols.deltaT)           = deltaT;
                        trialRow(cols.singleStimSide)   = 0;  % dual
                        trialRow(cols.rewardBigSide)    = 0;  % assigned below
                        trialRow(cols.completed)        = 0;

                        phaseTrials = [phaseTrials; trialRow]; %#ok<AGROW>

                    end
                end
            end
        end
    end

    %% Assign rewardBigSide and handle Phase 1 single-stim
    if iPhase == 1
        %% Phase 1: Build single-stimulus trials
        singleTrials = [];

        for iSingleSide = 1:2  % 1=left, 2=right
            if iSingleSide == 1
                nLocs = nLeftLocs;
            else
                nLocs = nRightLocs;
            end

            for iRep = 1:nSingleStimReps
                for iLoc = 1:nLocs
                    for iBgHue = 1:nBackgroundHues
                        for iDeltaT = 1:nDeltaT

                            deltaT = deltaTValues(iDeltaT);

                            if iSingleSide == 1
                                leftIdx = iLoc;
                                rightIdx = 1;  % placeholder
                            else
                                leftIdx = 1;   % placeholder
                                rightIdx = iLoc;
                            end

                            trialRow = zeros(1, nCols);
                            trialRow(cols.phaseNumber)      = iPhase;
                            trialRow(cols.trialInPhase)     = 0;
                            trialRow(cols.leftLocIdx)       = leftIdx;
                            trialRow(cols.rightLocIdx)      = rightIdx;
                            trialRow(cols.backgroundHueIdx) = iBgHue;
                            trialRow(cols.highSalienceSide) = iSingleSide;
                            trialRow(cols.deltaTIdx)        = iDeltaT;
                            trialRow(cols.deltaT)           = deltaT;
                            trialRow(cols.singleStimSide)   = iSingleSide;
                            trialRow(cols.rewardBigSide)    = 0;  % assigned below
                            trialRow(cols.completed)        = 0;

                            singleTrials = [singleTrials; trialRow]; %#ok<AGROW>

                        end
                    end
                end
            end
        end

        %% Phase 1 dual-stim: assign rewardBigSide 50/50 within highSalienceSide
        for iSal = 1:2
            idx = find(phaseTrials(:, cols.highSalienceSide) == iSal);
            nHalf = length(idx) / 2;
            assignment = [ones(nHalf, 1); 2 * ones(nHalf, 1)];
            assignment = assignment(randperm(length(assignment)));
            phaseTrials(idx, cols.rewardBigSide) = assignment;
        end

        %% Phase 1 single-stim: assign rewardBigSide 50/50 within singleStimSide
        for iSide = 1:2
            idx = find(singleTrials(:, cols.singleStimSide) == iSide);
            nHalf = length(idx) / 2;
            assignment = [ones(nHalf, 1); 2 * ones(nHalf, 1)];
            assignment = assignment(randperm(length(assignment)));
            singleTrials(idx, cols.rewardBigSide) = assignment;
        end

        %% Phase 1: shuffle separately, single-stim FIRST
        singleShuffled = singleTrials(randperm(size(singleTrials, 1)), :);
        dualShuffled = phaseTrials(randperm(size(phaseTrials, 1)), :);
        phaseTrials = [singleShuffled; dualShuffled];

    elseif iPhase == 2
        %% Phase 2: ~90% big-right (canonical), ~10% big-left (flipped)
        nCanonical = round(dualTrialsPerPhase * rewardProbHigh);
        nFlipped = dualTrialsPerPhase - nCanonical;
        assignment = [2 * ones(nCanonical, 1); ones(nFlipped, 1)];
        assignment = assignment(randperm(length(assignment)));
        phaseTrials(:, cols.rewardBigSide) = assignment;

        % Shuffle
        phaseTrials = phaseTrials(randperm(size(phaseTrials, 1)), :);

    elseif iPhase == 3
        %% Phase 3: ~90% big-left (canonical), ~10% big-right (flipped)
        nCanonical = round(dualTrialsPerPhase * rewardProbHigh);
        nFlipped = dualTrialsPerPhase - nCanonical;
        assignment = [ones(nCanonical, 1); 2 * ones(nFlipped, 1)];
        assignment = assignment(randperm(length(assignment)));
        phaseTrials(:, cols.rewardBigSide) = assignment;

        % Shuffle
        phaseTrials = phaseTrials(randperm(size(phaseTrials, 1)), :);
    end

    % Number of trials in this phase
    nTrialsThisPhase = size(phaseTrials, 1);

    % Fill in trial-within-phase indices
    phaseTrials(:, cols.trialInPhase) = (1:nTrialsThisPhase)';

    % Add to main array
    p.init.trialsArray(currentRow:(currentRow + nTrialsThisPhase - 1), :) = ...
        phaseTrials;
    currentRow = currentRow + nTrialsThisPhase;
end

%% 4. Store configuration values for reference
p.init.deltaTValues = deltaTValues;
p.init.nPhases = nPhases;
p.init.trialsPerPhaseList = [trialsPhase1, dualTrialsPerPhase, dualTrialsPerPhase];
p.init.trialsPerPhase = dualTrialsPerPhase;  % base count (phases 2-3)
p.init.singleStimTrialsPhase1 = singleStimTrialsPhase1;
p.init.totalTrials = totalTrials;

% Store reward ratios for reference (canonical phase-level ratios)
p.init.phaseRewardRatios = [...
    1, 1; ...
    1, rewardRatioBig; ...
    rewardRatioBig, 1];

%% 5. Create logical array tracking which trials are still available
p.status.trialsArrayRowsPossible = true(totalTrials, 1);

%% 6. Verify counterbalancing
rewardCol = cols.rewardBigSide;

for iPhase = 1:nPhases
    phaseRows = p.init.trialsArray(:, cols.phaseNumber) == iPhase;
    phaseData = p.init.trialsArray(phaseRows, :);

    % Separate dual and single-stim trials
    dualMask = phaseData(:, cols.singleStimSide) == 0;
    dualData = phaseData(dualMask, :);

    % Verify dual-stimulus counterbalancing
    nHighSalLeft = sum(dualData(:, cols.highSalienceSide) == 1);
    nHighSalRight = sum(dualData(:, cols.highSalienceSide) == 2);
    nHueA = sum(dualData(:, cols.backgroundHueIdx) == 1);
    nHueB = sum(dualData(:, cols.backgroundHueIdx) == 2);
    nDeltaTNeg = sum(dualData(:, cols.deltaTIdx) == 1);
    nDeltaTPos = sum(dualData(:, cols.deltaTIdx) == 2);

    assert(nHighSalLeft == nHighSalRight, ...
        'Phase %d dual: highSalienceSide not balanced! Left=%d, Right=%d', ...
        iPhase, nHighSalLeft, nHighSalRight);
    assert(nHueA == nHueB, ...
        'Phase %d dual: backgroundHueIdx not balanced! A=%d, B=%d', ...
        iPhase, nHueA, nHueB);
    assert(nDeltaTNeg == nDeltaTPos, ...
        'Phase %d dual: deltaT not balanced! -150=%d, +150=%d', ...
        iPhase, nDeltaTNeg, nDeltaTPos);

    % Verify rewardBigSide assignment
    nBigLeft = sum(dualData(:, rewardCol) == 1);
    nBigRight = sum(dualData(:, rewardCol) == 2);

    if iPhase == 1
        % Phase 1: 50/50 balanced within each highSalienceSide group
        for iSal = 1:2
            salIdx = dualData(:, cols.highSalienceSide) == iSal;
            nBL = sum(dualData(salIdx, rewardCol) == 1);
            nBR = sum(dualData(salIdx, rewardCol) == 2);
            assert(nBL == nBR, ...
                'Phase 1 dual (sal=%d): rewardBigSide not balanced! Left=%d, Right=%d', ...
                iSal, nBL, nBR);
        end

        % Verify single-stimulus trials
        singleData = phaseData(~dualMask, :);
        nSingleLeft = sum(singleData(:, cols.singleStimSide) == 1);
        nSingleRight = sum(singleData(:, cols.singleStimSide) == 2);

        assert(nSingleLeft == singleStimTrialsPhase1 / 2, ...
            'Phase 1: single-stim LEFT count wrong! Expected %d, got %d', ...
            singleStimTrialsPhase1 / 2, nSingleLeft);
        assert(nSingleRight == singleStimTrialsPhase1 / 2, ...
            'Phase 1: single-stim RIGHT count wrong! Expected %d, got %d', ...
            singleStimTrialsPhase1 / 2, nSingleRight);
        assert(size(dualData, 1) == dualTrialsPerPhase, ...
            'Phase 1: dual-stim count wrong! Expected %d, got %d', ...
            dualTrialsPerPhase, size(dualData, 1));

        % Verify single-stim rewardBigSide balance within each side
        for iSide = 1:2
            sideIdx = singleData(:, cols.singleStimSide) == iSide;
            nBL = sum(singleData(sideIdx, rewardCol) == 1);
            nBR = sum(singleData(sideIdx, rewardCol) == 2);
            assert(nBL == nBR, ...
                'Phase 1 single (side=%d): rewardBigSide not balanced! Left=%d, Right=%d', ...
                iSide, nBL, nBR);
        end

        % Verify single-stim hue and deltaT balance
        nSingleHueA = sum(singleData(:, cols.backgroundHueIdx) == 1);
        nSingleHueB = sum(singleData(:, cols.backgroundHueIdx) == 2);
        nSingleDTNeg = sum(singleData(:, cols.deltaTIdx) == 1);
        nSingleDTPos = sum(singleData(:, cols.deltaTIdx) == 2);
        assert(nSingleHueA == nSingleHueB, ...
            'Phase 1 single-stim: hue not balanced! A=%d, B=%d', ...
            nSingleHueA, nSingleHueB);
        assert(nSingleDTNeg == nSingleDTPos, ...
            'Phase 1 single-stim: deltaT not balanced! -150=%d, +150=%d', ...
            nSingleDTNeg, nSingleDTPos);

        % Verify single-stim trials come first
        singleRows = find(~dualMask);
        dualRows = find(dualMask);
        assert(max(singleRows) < min(dualRows), ...
            'Phase 1: single-stim trials must precede dual-stim trials!');

    elseif iPhase == 2
        % Phase 2: ~90% big-right (canonical)
        expectedCanonical = round(dualTrialsPerPhase * rewardProbHigh);
        assert(nBigRight == expectedCanonical, ...
            'Phase 2: rewardBigSide=2 count wrong! Expected %d, got %d', ...
            expectedCanonical, nBigRight);
        assert(~any(phaseData(:, cols.singleStimSide) ~= 0), ...
            'Phase 2 should have no single-stim trials!');

    elseif iPhase == 3
        % Phase 3: ~90% big-left (canonical)
        expectedCanonical = round(dualTrialsPerPhase * rewardProbHigh);
        assert(nBigLeft == expectedCanonical, ...
            'Phase 3: rewardBigSide=1 count wrong! Expected %d, got %d', ...
            expectedCanonical, nBigLeft);
        assert(~any(phaseData(:, cols.singleStimSide) ~= 0), ...
            'Phase 3 should have no single-stim trials!');
    end
end

%% 7. Print summary
C = p.trVarsInit.rewardDurationMs;
equalReward = round(C / 2);
smallReward = round(C * 1 / (1 + rewardRatioBig));
bigReward = round(C * rewardRatioBig / (1 + rewardRatioBig));
nCanonicalP23 = round(dualTrialsPerPhase * rewardProbHigh);
nFlippedP23 = dualTrialsPerPhase - nCanonicalP23;

fprintf('----------------------------------------\n');
fprintf('Conflict Task Trial Structure Generated:\n');
fprintf('  Total trials: %d\n', totalTrials);
fprintf('  Phases: %d\n', nPhases);
fprintf('  Phase 1: %d trials (%d single-stim FIRST, then %d dual-stim)\n', ...
    trialsPhase1, singleStimTrialsPhase1, dualTrialsPerPhase);
fprintf('  Phase 2: %d trials (dual-stim only)\n', dualTrialsPerPhase);
fprintf('  Phase 3: %d trials (dual-stim only)\n', dualTrialsPerPhase);
fprintf('  Target locations: %d left x %d right = %d pairs\n', ...
    nLeftLocs, nRightLocs, nLocPairs);
fprintf('  Background hues: %d (for counterbalancing)\n', nBackgroundHues);
fprintf('  Delta-t values: %s ms\n', mat2str(deltaTValues));
fprintf('----------------------------------------\n');
fprintf('Reward parameters:\n');
fprintf('  Budget C = %d ms, Ratio big:small = %.1f:1\n', C, rewardRatioBig);
fprintf('  Equal reward: %d ms each\n', equalReward);
fprintf('  Big reward: %d ms, Small reward: %d ms\n', bigReward, smallReward);
fprintf('  P(canonical) in Phases 2-3: %.1f%% (%d/%d canonical, %d/%d flipped)\n', ...
    rewardProbHigh * 100, nCanonicalP23, dualTrialsPerPhase, ...
    nFlippedP23, dualTrialsPerPhase);
fprintf('----------------------------------------\n');
fprintf('Reward assignment per phase:\n');
fprintf('  Phase 1: 50/50 big-left/big-right (pseudorandom, counterbalanced)\n');
fprintf('  Phase 2: %.0f%% big-RIGHT (canonical), %.0f%% big-LEFT (flipped)\n', ...
    rewardProbHigh * 100, (1 - rewardProbHigh) * 100);
fprintf('  Phase 3: %.0f%% big-LEFT (canonical), %.0f%% big-RIGHT (flipped)\n', ...
    rewardProbHigh * 100, (1 - rewardProbHigh) * 100);
fprintf('----------------------------------------\n');
fprintf('Single-stim trials (Phase 1 only, %d trials, presented FIRST):\n', ...
    singleStimTrialsPhase1);
fprintf('  Left target:  32 trials (16 big-left, 16 big-right)\n');
fprintf('  Right target: 32 trials (16 big-left, 16 big-right)\n');
fprintf('----------------------------------------\n');

end
