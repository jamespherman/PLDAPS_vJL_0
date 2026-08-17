function p = updateTrialsList(p)
%UPDATETRIALLIST Update schedule eligibility and optional correction trials.
%
% Standard behavior:
%   - successful rows are removed from the schedule;
%   - failed or aborted rows remain eligible.
%
% Optional correction behavior:
%   Correction uses ACTUAL moving coordinates, never the internal T1Side/T2Side
%   balancing slots. A left/right correction can only be interpreted when the
%   two targets straddle the vertical meridian, so same-hemifield trials are
%   never correction triggers. RIGHT-only is the default; if correctionBothSides
%   exists and is true, an incorrect low-reward choice in either hemifield may
%   trigger. The exact condition, including coordinates, is then repeated.

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
maxRepetition = max(0, round(getNumericField( ...
    p.trVars, 'correctionTrialMaxRepetition', 15)));

% If correction was switched off from the GUI while a row was active,
% retire that already-completed trigger row and resume normal scheduling.
if p.status.correctionTrialActive && ~correctionEnabled
    activeRow = p.status.correctionTrialRow;
    if isValidRow(activeRow, p.status.trialsArrayRowsPossible)
        p.status.trialsArrayRowsPossible(activeRow) = false;
    end
    p = clearCorrectionState(p, 'disabled');
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

    choseHighReward = currentChoiceWasHighReward(p);
    repetition = p.status.correctionTrialRepetition;

    if logical(p.trData.GoodTrial) && choseHighReward
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
        p.status.correctionTrialLastOutcome = 'repeat pending';
    end

    p = updateSrsScheduleStatus(p);
    return
end

% Trigger correction only after a valid free-choice conflict trial for
% which a genuine left-versus-right decision was available. If both targets
% are on the same side of fixation, calling one response a "right choice"
% would confound availability with preference, so that trial cannot trigger
% a horizontal correction.
chosenPhysicalSide = getNumericField(p.trData, 'chosenPhysicalSide', NaN);
chosenTargetID = getNumericField(p.trData, 'chosenTargetID', NaN);
highRewardTargetID = getNumericField(p.status, 'highRewardTargetID', NaN);
straddlesLR = getLogicalField(p.trVars, 'movingTargetsStraddleLR', false);
correctionBothSides = getLogicalField(p.trVars, 'correctionBothSides', false);
sideEligible = chosenPhysicalSide == 1 || ...
    (correctionBothSides && chosenPhysicalSide == 2);

triggerCorrection = correctionEnabled && maxRepetition > 0 && ...
    getLogicalField(p.trData, 'GoodTrial', false) && getCurrentNStim(p) == 2 && ...
    getCurrentTrialType(p) == 2 && straddlesLR && sideEligible && ...
    any(chosenTargetID == [1 2]) && any(highRewardTargetID == [1 2]) && ...
    chosenTargetID ~= highRewardTargetID;

if triggerCorrection
    p.status.correctionTrialActive = true;
    p.status.correctionTrialRow = rowIdx;
    p.status.correctionTrialRepetition = 0;
    p.status.correctionTrialTriggerTargetID = chosenTargetID;
    p.status.correctionTrialTriggerSide = chosenPhysicalSide;
    p.status.correctionTrialTriggerCount = ...
        p.status.correctionTrialTriggerCount + 1;
    if chosenPhysicalSide == 1
        p.status.correctionTrialLastOutcome = ...
            'triggered by RIGHT low-reward choice (L/R available)';
    else
        p.status.correctionTrialLastOutcome = ...
            'triggered by LEFT low-reward choice (L/R available)';
    end
    p = captureCorrectionTrialSnapshot(p);

    % Keep the completed trigger row eligible so chooseScheduledRow can
    % force it on the next trial.
    p.status.trialsArrayRowsPossible(rowIdx) = true;
    p.trData.trialRepeatFlag = true;
else
    p.trData.trialRepeatFlag = ~getLogicalField(p.trData, 'GoodTrial', false);
    p.status.trialsArrayRowsPossible(rowIdx) = p.trData.trialRepeatFlag;
end

p = updateSrsScheduleStatus(p);

end

function p = ensureCorrectionStatusFields(p)
defaults = struct( ...
    'correctionTrialActive', false, ...
    'correctionTrialRow', NaN, ...
    'correctionTrialRepetition', 0, ...
    'correctionTrialTriggerCount', 0, ...
    'correctionTrialSuccessCount', 0, ...
    'correctionTrialMaxReachedCount', 0, ...
    'correctionTrialLastOutcome', 'inactive', ...
    'correctionTrialSnapshot', struct(), ...
    'correctionTrialSnapshotValid', false, ...
    'correctionTrialTriggerTargetID', 0, ...
    'correctionTrialTriggerSide', 0);
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
p.status.correctionTrialLastOutcome = outcome;
p.status.correctionTrialTriggerTargetID = 0;
p.status.correctionTrialTriggerSide = 0;
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
