function p = updateTrialsList(p)
%UPDATETRIALLIST Update schedule eligibility and optional correction trials.
%
% Standard behavior:
%   - successful rows are removed from the schedule;
%   - failed or aborted rows remain eligible.
%
% Optional correction behavior:
%   The legacy mode corrects only a RIGHT low-reward choice on a conflict
%   trial. When correctionBothSides is enabled, the same rule applies to a
%   low-reward choice on either side. The exact stochastic condition is
%   forced again until the high-reward target is chosen or the configurable
%   repetition limit is reached.

if ~isfield(p.trVars, 'currentTrialsArrayRow') || ...
        isempty(p.trVars.currentTrialsArrayRow) || ...
        p.trVars.currentTrialsArrayRow < 1
    return
end

rowIdx = round(double(p.trVars.currentTrialsArrayRow));
if rowIdx > numel(p.status.trialsArrayRowsPossible)
    error('Current SRS schedule row is outside trialsArrayRowsPossible.');
end

p = ensureCorrectionStatusFields(p);
correctionEnabled = getLogicalField(p.trVars, 'correctionTrial', false);
correctionBothSides = getLogicalField( ...
    p.trVars, 'correctionBothSides', false);
maxRepetition = max(0, round(getNumericField( ...
    p.trVars, 'correctionTrialMaxRepetition', 15)));
activeTriggerSide = getNumericField( ...
    p.status, 'correctionTrialTriggerSide', NaN);
leftCorrectionNoLongerAllowed = p.status.correctionTrialActive && ...
    activeTriggerSide == 2 && ~correctionBothSides;

% If correction was switched off, or bilateral mode was disabled during a
% LEFT-triggered sequence, retire the completed trigger row and resume.
if p.status.correctionTrialActive && ...
        (~correctionEnabled || leftCorrectionNoLongerAllowed)
    activeRow = p.status.correctionTrialRow;
    if isValidRow(activeRow, p.status.trialsArrayRowsPossible)
        p.status.trialsArrayRowsPossible(activeRow) = false;
    end
    if leftCorrectionNoLongerAllowed
        p = clearCorrectionState(p, 'bilateral mode disabled');
    else
        p = clearCorrectionState(p, 'disabled');
    end
end

if p.status.correctionTrialActive
    % We should only arrive here while running the forced correction row.
    activeRow = p.status.correctionTrialRow;
    if rowIdx ~= activeRow
        warning(['Correction row mismatch: expected row %d but completed ', ...
            'row %d. Keeping the expected row eligible.'], activeRow, rowIdx);
        p.status.trialsArrayRowsPossible(rowIdx) = ...
            ~logical(p.trData.GoodTrial);
        if isValidRow(activeRow, p.status.trialsArrayRowsPossible)
            p.status.trialsArrayRowsPossible(activeRow) = true;
        end
        p.trData.trialRepeatFlag = true;
        p = updateSrsScheduleStatus(p);
        return
    end

    trialCompleted = logical(p.trData.GoodTrial);
    choseHighReward = currentChoiceWasHighReward(p);
    triggerSide = getNumericField( ...
        p.status, 'correctionTrialTriggerSide', NaN);

    % RIGHT reward reduction is only meaningful for a correction that was
    % triggered by an incorrect RIGHT choice. A LEFT-triggered correction
    % must preserve the correct HIGH reward on the right.
    if triggerSide == 1
        currentReductionLevel = max(1, round( ...
            p.status.correctionRightRewardReductionLevel));
        nextReductionLevel = advanceCorrectionRightRewardReductionLevel( ...
            currentReductionLevel, trialCompleted, ...
            getNumericField(p.trData, 'chosenSide', NaN), choseHighReward);
        choseRightAgain = nextReductionLevel > currentReductionLevel;
    else
        currentReductionLevel = 0;
        nextReductionLevel = 0;
        choseRightAgain = false;
    end
    repetition = p.status.correctionTrialRepetition;

    if trialCompleted && choseHighReward
        % Correction succeeded. Remove the row and resume the schedule.
        p.status.trialsArrayRowsPossible(rowIdx) = false;
        p.trData.trialRepeatFlag = false;
        p.status.correctionTrialSuccessCount = ...
            p.status.correctionTrialSuccessCount + 1;
        p = clearCorrectionState(p, 'correct choice');

    elseif repetition >= maxRepetition
        % The trigger trial was already a valid completed trial. Once the
        % training cap is reached, retire the row even if the final repeat
        % was aborted or still incorrect, otherwise it could continue to
        % reappear through the ordinary failed-trial mechanism.
        p.status.trialsArrayRowsPossible(rowIdx) = false;
        p.trData.trialRepeatFlag = false;
        p.status.correctionTrialMaxReachedCount = ...
            p.status.correctionTrialMaxReachedCount + 1;
        p = clearCorrectionState(p, 'maximum reached');

    else
        % Keep forcing the same row on the next attempt.
        p.status.trialsArrayRowsPossible(rowIdx) = true;
        p.trData.trialRepeatFlag = true;
        if choseRightAgain
            % Only another completed RIGHT choice compounds the reward
            % reduction. Fixation breaks, no-response trials and other
            % aborted attempts keep the current reduction level.
            p.status.correctionRightRewardReductionLevel = ...
                nextReductionLevel;
            p.status.correctionTrialLastOutcome = sprintf( ...
                'right choice; reduction level %d pending', ...
                p.status.correctionRightRewardReductionLevel);
        else
            p.status.correctionTrialLastOutcome = ...
                'repeat pending; reduction level unchanged';
        end
    end

    p = updateSrsScheduleStatus(p);
    return
end

% Trigger correction after a valid free-choice conflict trial when the
% subject chose the low-reward target. correctionBothSides selects between
% the legacy RIGHT-only trigger and a bilateral LEFT/RIGHT trigger.
highRewardSide = getHighRewardSide(p);
chosenSide = getNumericField(p.trData, 'chosenSide', NaN);
choseHighReward = currentChoiceWasHighReward(p);
bothSides = getLogicalField(p.trVars, 'correctionBothSides', false);
validSideChoice = any(chosenSide == [1 2]) && any(highRewardSide == [1 2]);
wrongLowRewardChoice = validSideChoice && ~choseHighReward && ...
    chosenSide ~= highRewardSide;

if bothSides
    sideRulePassed = wrongLowRewardChoice;
else
    sideRulePassed = wrongLowRewardChoice && chosenSide == 1;
end

triggerCorrection = correctionEnabled && maxRepetition > 0 && ...
    logical(p.trData.GoodTrial) && getCurrentNStim(p) == 2 && ...
    getCurrentTrialType(p) == 2 && sideRulePassed;

if triggerCorrection
    p.status.correctionTrialActive = true;
    p.status.correctionTrialRow = rowIdx;
    p.status.correctionTrialRepetition = 0;
    p.status.correctionTrialTriggerSide = chosenSide;

    % Only a RIGHT-triggered correction uses the optional anti-right reward
    % reduction. LEFT-triggered corrections keep the original rewards.
    p.status.correctionRightRewardReductionLevel = double(chosenSide == 1);
    p.status.correctionTrialTriggerCount = ...
        p.status.correctionTrialTriggerCount + 1;
    p.status.correctionTrialLastOutcome = sprintf( ...
        'triggered by %s low-reward choice', lower(sideName(chosenSide)));
    p = captureCorrectionTrialSnapshot(p);

    % Keep the completed trigger row eligible so chooseScheduledRow can
    % force it on the next trial.
    p.status.trialsArrayRowsPossible(rowIdx) = true;
    p.trData.trialRepeatFlag = true;
else
    p.trData.trialRepeatFlag = ~logical(p.trData.GoodTrial);
    p.status.trialsArrayRowsPossible(rowIdx) = p.trData.trialRepeatFlag;
end

p = updateSrsScheduleStatus(p);

end

function p = ensureCorrectionStatusFields(p)
defaults = struct( ...
    'correctionTrialActive', false, ...
    'correctionTrialRow', NaN, ...
    'correctionTrialRepetition', 0, ...
    'correctionTrialTriggerSide', NaN, ...
    'correctionRightRewardReductionLevel', 0, ...
    'correctionTrialTriggerCount', 0, ...
    'correctionTrialSuccessCount', 0, ...
    'correctionTrialMaxReachedCount', 0, ...
    'correctionTrialLastOutcome', 'inactive', ...
    'correctionTrialSnapshot', struct(), ...
    'correctionTrialSnapshotValid', false);
fields = fieldnames(defaults);
for iField = 1:numel(fields)
    name = fields{iField};
    if ~isfield(p.status, name)
        p.status.(name) = defaults.(name);
    end
end
end

function p = clearCorrectionState(p, outcome)
p.status.correctionTrialActive = false;
p.status.correctionTrialRow = NaN;
p.status.correctionTrialRepetition = 0;
p.status.correctionTrialTriggerSide = NaN;
p.status.correctionRightRewardReductionLevel = 0;
p.status.correctionTrialLastOutcome = outcome;
p.status.correctionTrialSnapshot = struct();
p.status.correctionTrialSnapshotValid = false;
end

function tf = currentChoiceWasHighReward(p)
chosenTargetID = getNumericField(p.trData, 'chosenTargetID', NaN);
highRewardTargetID = getNumericField(p.status, 'highRewardTargetID', NaN);
if ~any(chosenTargetID == [1 2])
    chosenSide = getNumericField(p.trData, 'chosenSide', NaN);
    T1Side = getNumericField(p.trVars, 'T1Side', NaN);
    T2Side = getNumericField(p.trVars, 'T2Side', NaN);
    if chosenSide == T1Side
        chosenTargetID = 1;
    elseif chosenSide == T2Side
        chosenTargetID = 2;
    end
end
tf = any(chosenTargetID == [1 2]) && ...
    chosenTargetID == highRewardTargetID;
end

function side = getHighRewardSide(p)
side = getNumericField(p.status, 'highRewardSide', NaN);
if any(side == [1 2])
    return
end
highRewardTargetID = getNumericField(p.status, 'highRewardTargetID', NaN);
if highRewardTargetID == 1
    side = getNumericField(p.trVars, 'T1Side', NaN);
elseif highRewardTargetID == 2
    side = getNumericField(p.trVars, 'T2Side', NaN);
end
end

function nStim = getCurrentNStim(p)
nStim = getNumericField(p.trData, 'nStim', NaN);
if ~isfinite(nStim)
    nStim = getNumericField(p.trVars, 'nStim', NaN);
end
end

function trialType = getCurrentTrialType(p)
trialType = getNumericField(p.status, 'ActualTrialType', NaN);
end

function tf = isValidRow(rowIdx, rowMask)
tf = isfinite(rowIdx) && rowIdx >= 1 && rowIdx <= numel(rowMask) && ...
    rowIdx == round(rowIdx);
end

function name = sideName(side)
if side == 1
    name = 'RIGHT';
elseif side == 2
    name = 'LEFT';
else
    name = 'UNKNOWN';
end
end

function value = getNumericField(s, fieldName, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s, fieldName)
    candidate = s.(fieldName);
    if isnumeric(candidate) || islogical(candidate)
        candidate = double(candidate);
        if isscalar(candidate) && isfinite(candidate)
            value = candidate;
        end
    end
end
end

function value = getLogicalField(s, fieldName, defaultValue)
value = logical(defaultValue);
if isstruct(s) && isfield(s, fieldName)
    candidate = s.(fieldName);
    if (isnumeric(candidate) || islogical(candidate)) && isscalar(candidate)
        value = logical(candidate);
    end
end
end
