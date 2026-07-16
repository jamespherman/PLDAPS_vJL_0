function p = buildSrsBlockSchedule(p)
%BUILDSRSBLOCKSCHEDULE Build the compact table and expanded block schedule.
%
% Training blocks contain three non-overlapping schedule phases:
%   1. Ten consecutive successful trials from one single-target identity
%   2. Ten consecutive successful trials from the other identity
%   3. Two-target congruent/conflict choice trials
%
% The order of the T1-only and T2-only groups is randomized once per block.
% Within a group, target side is randomized/counterbalanced. A failed trial
% remains eligible, so the next group cannot begin until the current group
% has been completed successfully.

cols = p.init.trialsTableCols;
conditionRows = zeros(0, numel(p.init.trialsTableColumnNames));
conditionID = 0;

useTraining = getLogicalField(p.trVars, 'useSingleStimTraining', false);
randomizeSides = getLogicalField(p.trVars, 'randomizeTargetIdentitySides', true);

nSingleT1 = getNumericField(p.trVars, 'nSingleT1PerBlock', 10);
nSingleT2 = getNumericField(p.trVars, 'nSingleT2PerBlock', 10);
nChoice = round(getNumericField(p.status, 'TotalChoiceTrialsPerBlock', 80));

nSingleT1 = max(0, round(nSingleT1));
nSingleT2 = max(0, round(nSingleT2));
nChoice = max(4, round(nChoice));

% Two trial types x two identity-to-side mappings require a multiple of 4.
if randomizeSides
    nChoice = 4 * round(nChoice / 4);
else
    nChoice = 2 * round(nChoice / 2);
end
p.status.TotalChoiceTrialsPerBlock = nChoice;

%% Choose the order of the two single-target instruction groups
% Phase 1 and phase 2 are assigned once per block. This guarantees that
% T1-only and T2-only trials never interleave.
if useTraining
    singleGroupOrder = randperm(2);
    p.status.FirstSingleTargetID = singleGroupOrder(1);
    p.status.SecondSingleTargetID = singleGroupOrder(2);

    phaseT1 = find(singleGroupOrder == 1, 1, 'first');
    phaseT2 = find(singleGroupOrder == 2, 1, 'first');
else
    p.status.FirstSingleTargetID = 0;
    p.status.SecondSingleTargetID = 0;
    phaseT1 = NaN;
    phaseT2 = NaN;
end

%% Instruction conditions
if useTraining
    if randomizeSides
        [nT1Right, nT1Left] = splitAcrossSides(nSingleT1);
        [nT2Right, nT2Left] = splitAcrossSides(nSingleT2);

        [conditionRows, conditionID] = addCondition(conditionRows, conditionID, cols, ...
            1, 1, 1, 2, 0, phaseT1, nT1Right); % T1 only, T1 right
        [conditionRows, conditionID] = addCondition(conditionRows, conditionID, cols, ...
            1, 1, 2, 1, 0, phaseT1, nT1Left);  % T1 only, T1 left
        [conditionRows, conditionID] = addCondition(conditionRows, conditionID, cols, ...
            1, 2, 2, 1, 0, phaseT2, nT2Right); % T2 only, T2 right
        [conditionRows, conditionID] = addCondition(conditionRows, conditionID, cols, ...
            1, 2, 1, 2, 0, phaseT2, nT2Left);  % T2 only, T2 left
    else
        [conditionRows, conditionID] = addCondition(conditionRows, conditionID, cols, ...
            1, 1, 1, 2, 0, phaseT1, nSingleT1); % T1 fixed right
        [conditionRows, conditionID] = addCondition(conditionRows, conditionID, cols, ...
            1, 2, 1, 2, 0, phaseT2, nSingleT2); % T2 fixed left
    end
end

%% Two-target choice conditions
if randomizeSides
    repsPerCell = nChoice / 4;
    for trialType = 1:2
        for T1Side = 1:2
            T2Side = 3 - T1Side;
            [conditionRows, conditionID] = addCondition(conditionRows, conditionID, cols, ...
                2, 0, T1Side, T2Side, trialType, 3, repsPerCell);
        end
    end
else
    repsPerType = nChoice / 2;
    for trialType = 1:2
        [conditionRows, conditionID] = addCondition(conditionRows, conditionID, cols, ...
            2, 0, 1, 2, trialType, 3, repsPerType);
    end
end

% Remove zero-repetition conditions.
conditionRows = conditionRows(conditionRows(:, cols.noOfTrials) > 0, :);
p.init.trialsTable = conditionRows;

%% Expand compact table into one row per required successful trial
arrayCols = p.init.trialCols;
nTrials = sum(conditionRows(:, cols.noOfTrials));
trialsArray = zeros(nTrials, numel(p.init.trialArrayColumnNames));
currentRow = 1;

for iCondition = 1:size(conditionRows, 1)
    nReps = conditionRows(iCondition, cols.noOfTrials);
    outRows = currentRow:(currentRow + nReps - 1);

    trialsArray(outRows, arrayCols.conditionID) = conditionRows(iCondition, cols.conditionID);
    trialsArray(outRows, arrayCols.nStim) = conditionRows(iCondition, cols.nStim);
    trialsArray(outRows, arrayCols.singleTargetID) = conditionRows(iCondition, cols.singleTargetID);
    trialsArray(outRows, arrayCols.T1Side) = conditionRows(iCondition, cols.T1Side);
    trialsArray(outRows, arrayCols.T2Side) = conditionRows(iCondition, cols.T2Side);
    trialsArray(outRows, arrayCols.trialType) = conditionRows(iCondition, cols.trialType);
    trialsArray(outRows, arrayCols.schedulePhase) = conditionRows(iCondition, cols.schedulePhase);
    trialsArray(outRows, arrayCols.trialSeed) = randi(2^15 - 1, nReps, 1);

    currentRow = currentRow + nReps;
end

p.init.trialsArray = trialsArray;
p.init.blockLength = size(trialsArray, 1);
p.status.trialsArrayRowsPossible = true(p.init.blockLength, 1);
p.status.blockScheduleComplete = isempty(trialsArray);
p.status.blockAttemptCount = 0;

%% Store totals and initialize remaining counts
p.status.TotalSingleT1 = sum(trialsArray(:, arrayCols.nStim) == 1 & ...
    trialsArray(:, arrayCols.singleTargetID) == 1);
p.status.TotalSingleT2 = sum(trialsArray(:, arrayCols.nStim) == 1 & ...
    trialsArray(:, arrayCols.singleTargetID) == 2);
p.status.TotalInstructionTrialsPerBlock = p.status.TotalSingleT1 + p.status.TotalSingleT2;
p.status.TotalCongruent = sum(trialsArray(:, arrayCols.nStim) == 2 & ...
    trialsArray(:, arrayCols.trialType) == 1);
p.status.TotalConflict = sum(trialsArray(:, arrayCols.nStim) == 2 & ...
    trialsArray(:, arrayCols.trialType) == 2);
p.status.TotalTrialsPerBlock = p.init.blockLength;

p = updateSrsScheduleStatus(p);

end

function [rows, conditionID] = addCondition(rows, conditionID, cols, ...
    nStim, singleTargetID, T1Side, T2Side, trialType, schedulePhase, nReps)
%ADDCONDITION Append one compact condition row.

if nReps <= 0
    return
end

conditionID = conditionID + 1;
newRow = zeros(1, size(rows, 2));
newRow(cols.conditionID) = conditionID;
newRow(cols.nStim) = nStim;
newRow(cols.singleTargetID) = singleTargetID;
newRow(cols.T1Side) = T1Side;
newRow(cols.T2Side) = T2Side;
newRow(cols.trialType) = trialType;
newRow(cols.schedulePhase) = schedulePhase;
newRow(cols.noOfTrials) = nReps;
rows(end + 1, :) = newRow;

end

function [nRight, nLeft] = splitAcrossSides(nTrials)
%SPLITACROSSSIDES Balance identity presentations across right and left.

nRight = floor(nTrials / 2);
nLeft = nTrials - nRight;

% Randomize which side receives the extra trial when the count is odd.
if mod(nTrials, 2) == 1 && rand > 0.5
    temp = nRight;
    nRight = nLeft;
    nLeft = temp;
end

end

function value = getNumericField(s, fieldName, defaultValue)
if isfield(s, fieldName) && isnumeric(s.(fieldName)) && isscalar(s.(fieldName))
    value = s.(fieldName);
else
    value = defaultValue;
end
end

function value = getLogicalField(s, fieldName, defaultValue)
if isfield(s, fieldName)
    value = logical(s.(fieldName));
else
    value = defaultValue;
end
end
