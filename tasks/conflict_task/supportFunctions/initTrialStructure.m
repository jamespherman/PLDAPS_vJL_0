function p = initTrialStructure(p)
%   p = initTrialStructure(p)
%
% Builds the trial array for the Conflict Task experiment (refactored design).
% Called once during initialization from conflict_task_init.m.
%
% Trial Structure:
%   - 3 phases total (128 successful trials each = 384 trials per session)
%   - Phase 1: 1:1 reward ratio (equal rewards)
%   - Phase 2: 1:2 reward ratio (left:right = 130ms:260ms)
%   - Phase 3: 2:1 reward ratio (left:right = 260ms:130ms)
%
% Conditions per phase (128 unique):
%   - 16 target location pairs (4 left × 4 right)
%   - 2 background hue conditions (Hue A vs Hue B for counterbalancing)
%   - 2 high salience sides (left vs right)
%   - 2 delta-t values (-150ms, +150ms)
%
% 16 × 2 × 2 × 2 = 128 conditions per phase
%
% Trials are shuffled within phases but not across phases.

%% 1. Define column names for the trial array
p.init.trialArrayColumnNames = {...
    'phaseNumber', ...      % 1, 2, or 3
    'trialInPhase', ...     % Trial index within phase (1-128)
    'leftLocIdx', ...       % Index into leftAngles (1-4)
    'rightLocIdx', ...      % Index into rightAngles (1-4)
    'backgroundHueIdx', ... % 1=Hue A (0 deg DKL target), 2=Hue B (180 deg DKL target)
    'highSalienceSide', ... % 1=left, 2=right
    'deltaTIdx', ...        % Index into deltaTValues (1 or 2)
    'deltaT', ...           % Delta-t value in ms (-150 or +150)
    'completed'};           % 0=not done, 1=completed

%% 2. Define trial parameters
nPhases = 3;
trialsPerPhase = 128;

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

% Verify condition count
nConditions = nLocPairs * nBackgroundHues * nSalienceSides * nDeltaT;
assert(nConditions == trialsPerPhase, ...
    'Condition count mismatch: expected %d, got %d', trialsPerPhase, nConditions);

%% 3. Build the complete trial array
totalTrials = nPhases * trialsPerPhase;
nCols = length(p.init.trialArrayColumnNames);
p.init.trialsArray = zeros(totalTrials, nCols);

currentRow = 1;

for iPhase = 1:nPhases

    % Build all conditions for this phase
    phaseTrials = [];

    for iLeftLoc = 1:nLeftLocs
        for iRightLoc = 1:nRightLocs
            for iBgHue = 1:nBackgroundHues
                for iSalSide = 1:nSalienceSides
                    for iDeltaT = 1:nDeltaT

                        deltaT = deltaTValues(iDeltaT);

                        trialRow = [...
                            iPhase, ...         % phaseNumber
                            0, ...              % trialInPhase (filled after shuffle)
                            iLeftLoc, ...       % leftLocIdx
                            iRightLoc, ...      % rightLocIdx
                            iBgHue, ...         % backgroundHueIdx
                            iSalSide, ...       % highSalienceSide (1=left, 2=right)
                            iDeltaT, ...        % deltaTIdx
                            deltaT, ...         % deltaT
                            0];                 % completed

                        phaseTrials = [phaseTrials; trialRow]; %#ok<AGROW>

                    end
                end
            end
        end
    end

    % Shuffle trials within this phase
    shuffleOrder = randperm(size(phaseTrials, 1));
    phaseTrials = phaseTrials(shuffleOrder, :);

    % Fill in trial-within-phase indices
    phaseTrials(:, 2) = (1:trialsPerPhase)';

    % Add to main array
    p.init.trialsArray(currentRow:(currentRow + trialsPerPhase - 1), :) = ...
        phaseTrials;
    currentRow = currentRow + trialsPerPhase;
end

%% 4. Store configuration values for reference
p.init.deltaTValues = deltaTValues;
p.init.nPhases = nPhases;
p.init.trialsPerPhase = trialsPerPhase;
p.init.totalTrials = totalTrials;

% Store reward ratios for each phase
% Format: [leftRatio, rightRatio]
p.init.phaseRewardRatios = [...
    1, 1; ...   % Phase 1: 1:1 (195ms : 195ms)
    1, 2; ...   % Phase 2: 1:2 (130ms : 260ms)
    2, 1];      % Phase 3: 2:1 (260ms : 130ms)

%% 5. Create logical array tracking which trials are still available
% For each phase, we track which trials remain to be completed
p.status.trialsArrayRowsPossible = true(totalTrials, 1);

%% 6. Verify counterbalancing
% Get column index for highSalienceSide
colNames = p.init.trialArrayColumnNames;
salSideCol = find(strcmp(colNames, 'highSalienceSide'));
phaseCol = find(strcmp(colNames, 'phaseNumber'));
bgHueCol = find(strcmp(colNames, 'backgroundHueIdx'));
deltaTCol = find(strcmp(colNames, 'deltaTIdx'));

% Check counterbalancing within each phase
for iPhase = 1:nPhases
    phaseRows = p.init.trialsArray(:, phaseCol) == iPhase;
    phaseData = p.init.trialsArray(phaseRows, :);

    % Count high salience sides
    nHighSalLeft = sum(phaseData(:, salSideCol) == 1);
    nHighSalRight = sum(phaseData(:, salSideCol) == 2);

    % Count background hues
    nHueA = sum(phaseData(:, bgHueCol) == 1);
    nHueB = sum(phaseData(:, bgHueCol) == 2);

    % Count delta-t values
    nDeltaTNeg = sum(phaseData(:, deltaTCol) == 1);
    nDeltaTPos = sum(phaseData(:, deltaTCol) == 2);

    % Verify exact counterbalancing
    assert(nHighSalLeft == nHighSalRight, ...
        'Phase %d: highSalienceSide not balanced! Left=%d, Right=%d', ...
        iPhase, nHighSalLeft, nHighSalRight);
    assert(nHueA == nHueB, ...
        'Phase %d: backgroundHueIdx not balanced! A=%d, B=%d', ...
        iPhase, nHueA, nHueB);
    assert(nDeltaTNeg == nDeltaTPos, ...
        'Phase %d: deltaT not balanced! -150=%d, +150=%d', ...
        iPhase, nDeltaTNeg, nDeltaTPos);
end

%% 7. Print summary
fprintf('----------------------------------------\n');
fprintf('Conflict Task Trial Structure Generated (Refactored):\n');
fprintf('  Total trials: %d\n', totalTrials);
fprintf('  Phases: %d\n', nPhases);
fprintf('  Trials per phase: %d\n', trialsPerPhase);
fprintf('  Target locations: %d left × %d right = %d pairs\n', ...
    nLeftLocs, nRightLocs, nLocPairs);
fprintf('  Background hues: %d (for counterbalancing)\n', nBackgroundHues);
fprintf('  High salience sides: %d (left, right)\n', nSalienceSides);
fprintf('  Delta-t values: %s ms\n', mat2str(deltaTValues));
fprintf('  Conditions per phase: %d × %d × %d × %d = %d\n', ...
    nLocPairs, nBackgroundHues, nSalienceSides, nDeltaT, nConditions);
fprintf('----------------------------------------\n');
fprintf('Counterbalancing verified (per phase):\n');
fprintf('  High salience LEFT:  %d trials (50%%)\n', trialsPerPhase/2);
fprintf('  High salience RIGHT: %d trials (50%%)\n', trialsPerPhase/2);
fprintf('  Background Hue A:    %d trials (50%%)\n', trialsPerPhase/2);
fprintf('  Background Hue B:    %d trials (50%%)\n', trialsPerPhase/2);
fprintf('  Delta-t = -150ms:    %d trials (50%%)\n', trialsPerPhase/2);
fprintf('  Delta-t = +150ms:    %d trials (50%%)\n', trialsPerPhase/2);
fprintf('----------------------------------------\n');
fprintf('Reward ratios:\n');
fprintf('  Phase 1: 1:1 (195ms : 195ms)\n');
fprintf('  Phase 2: 1:2 (130ms : 260ms)\n');
fprintf('  Phase 3: 2:1 (260ms : 130ms)\n');
fprintf('----------------------------------------\n');

end
