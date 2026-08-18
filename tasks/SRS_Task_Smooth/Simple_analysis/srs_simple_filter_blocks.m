function [T, meta] = srs_simple_filter_blocks(T, meta, blockRange)
%SRS_SIMPLE_FILTER_BLOCKS Retain complete blocks and refresh derived fields.
%
% BLOCKRANGE is [firstBlock lastBlock]. Inf is allowed as the upper limit.
% Filtering occurs after loading but all cumulative, timing, and sequential
% variables are recomputed so excluded blocks cannot influence the first
% retained choice.

if nargin < 3 || isempty(blockRange)
    blockRange = [-Inf Inf];
end
validateattributes(blockRange, {'numeric'}, ...
    {'vector', 'numel', 2, 'real', 'nonnan'}, ...
    mfilename, 'blockRange', 3);
blockRange = double(blockRange(:)');
if blockRange(1) > blockRange(2)
    error('blockRange(1) must be less than or equal to blockRange(2).');
end
if ~any(strcmp(T.Properties.VariableNames, 'Block'))
    error('The loaded trial table has no Block variable.');
end

availableBlocks = unique(T.Block(isfinite(T.Block)), 'stable')';
keep = isfinite(T.Block) & T.Block >= blockRange(1) & ...
    T.Block <= blockRange(2);
if ~any(keep)
    error(['No attempts were found in blocks %g through %g. ', ...
        'Available blocks: %s'], blockRange(1), blockRange(2), ...
        mat2str(availableBlocks));
end

T = T(keep, :);
[~, order] = sort(T.Attempt);
T = T(order, :);
nTrials = height(T);

% Cumulative indices.
T.GoodTrialOrdinal = cumsum(double(T.GoodTrial));
T.ChoiceOrdinal = nan(nTrials, 1);
choiceRows = find(T.GoodChoice);
T.ChoiceOrdinal(choiceRows) = (1:numel(choiceRows))';

% Block identifiers and within-block counters.
T.BlockUID = strings(nTrials, 1);
for iTrial = 1:nTrials
    if isfinite(T.Block(iTrial))
        T.BlockUID(iTrial) = sprintf('%s_B%03d', ...
            char(T.SessionID(iTrial)), round(T.Block(iTrial)));
    else
        T.BlockUID(iTrial) = sprintf('%s_Bmissing', ...
            char(T.SessionID(iTrial)));
    end
end

T.GoodTrialInBlock = nan(nTrials, 1);
T.ChoiceInBlock = nan(nTrials, 1);
uniqueBlocks = unique(T.BlockUID, 'stable');
for iBlock = 1:numel(uniqueBlocks)
    rows = find(T.BlockUID == uniqueBlocks(iBlock));
    goodCount = 0;
    choiceCount = 0;
    for iRow = 1:numel(rows)
        row = rows(iRow);
        if T.GoodTrial(row)
            goodCount = goodCount + 1;
            T.GoodTrialInBlock(row) = goodCount;
        end
        if T.GoodChoice(row)
            choiceCount = choiceCount + 1;
            T.ChoiceInBlock(row) = choiceCount;
        end
    end
end

% Elapsed time and interval before each retained attempt.
firstStart = firstFiniteValue(T.TrialStartPTB);
if isfinite(firstStart)
    T.SessionElapsedMin = (T.TrialStartPTB - firstStart) / 60;
else
    T.SessionElapsedMin = nan(nTrials, 1);
end
T.PreTrialIntervalSec = nan(nTrials, 1);
for iTrial = 2:nTrials
    previousEnd = T.TrialStartPTB(iTrial - 1) + ...
        T.TrialDurationSec(iTrial - 1);
    if isfinite(T.TrialStartPTB(iTrial)) && isfinite(previousEnd)
        intervalValue = T.TrialStartPTB(iTrial) - previousEnd;
        if intervalValue >= 0
            T.PreTrialIntervalSec(iTrial) = intervalValue;
        end
    end
end

% Sequential dependencies between retained two-target choices.
T.PreviousChosenTarget = nan(nTrials, 1);
T.PreviousChosenSide = nan(nTrials, 1);
T.PreviousRewardMs = nan(nTrials, 1);
T.PreviousChoiceSameBlock = false(nTrials, 1);
T.SwitchedTarget = nan(nTrials, 1);
T.SwitchedSide = nan(nTrials, 1);

lastChoiceRow = NaN;
for iTrial = 1:nTrials
    if ~T.GoodChoice(iTrial)
        continue;
    end
    if isfinite(lastChoiceRow)
        previousRow = lastChoiceRow;
        T.PreviousChosenTarget(iTrial) = T.ChosenTarget(previousRow);
        T.PreviousChosenSide(iTrial) = T.ChosenSide(previousRow);
        T.PreviousRewardMs(iTrial) = T.ChosenRewardMs(previousRow);
        T.PreviousChoiceSameBlock(iTrial) = ...
            T.BlockUID(iTrial) == T.BlockUID(previousRow);
        T.SwitchedTarget(iTrial) = double( ...
            T.ChosenTarget(iTrial) ~= T.ChosenTarget(previousRow));
        T.SwitchedSide(iTrial) = double( ...
            T.ChosenSide(iTrial) ~= T.ChosenSide(previousRow));
    end
    lastChoiceRow = iTrial;
end
T.StayedTarget = 1 - T.SwitchedTarget;
T.StayedSide = 1 - T.SwitchedSide;
T.RealEyeChoice = T.GoodChoice & T.PassEye == 0 & T.MouseEyeSim == 0;

% Refresh metadata so the recap describes only retained attempts.
meta.blockRangeRequested = blockRange;
meta.availableBlocks = availableBlocks;
meta.analyzedBlocks = unique(T.Block(isfinite(T.Block)), 'stable')';
meta.nAttemptFiles = height(T);
meta.nGoodTrials = sum(T.GoodTrial);
meta.nGoodChoices = sum(T.GoodChoice);
meta.nRealEyeChoices = sum(T.RealEyeChoice);
meta.passEyeFraction = mean(T.PassEye ~= 0);
meta.passJoyFraction = mean(T.PassJoy ~= 0);
meta.mouseEyeSimFraction = mean(T.MouseEyeSim ~= 0);
meta.dataLikelySimulated = any(T.PassEye ~= 0 | T.MouseEyeSim ~= 0);
meta.nValidReactionTimes = sum(isfinite(T.ReactionTimeMs));
meta.nValidFixAcquisitionLatencies = ...
    sum(isfinite(T.FixAcquisitionLatencyMs));
meta.totalMissedFrames = sum(T.MissedFrames, 'omitnan');
meta.mappingErrors = sum(T.GoodChoice & ~T.ChoiceMappingValid);

if isfinite(firstStart)
    finalStart = T.TrialStartPTB(end);
    finalDuration = T.TrialDurationSec(end);
    if isfinite(finalStart) && isfinite(finalDuration)
        meta.sessionDurationMin = ...
            (finalStart + finalDuration - firstStart) / 60;
    else
        meta.sessionDurationMin = NaN;
    end
else
    meta.sessionDurationMin = NaN;
end

warnings = strings(0, 1);
warnings(end + 1, 1) = sprintf( ...
    'Analysis restricted to blocks %s.', mat2str(meta.analyzedBlocks));
if meta.passEyeFraction > 0
    warnings(end + 1, 1) = sprintf([ ...
        'passEye is active on %.1f %% of retained attempts. ', ...
        'These programmed choices are excluded from behavioral inference.'], ...
        100 * meta.passEyeFraction);
end
if meta.passJoyFraction > 0
    warnings(end + 1, 1) = sprintf([ ...
        'passJoy is active on %.1f %% of retained attempts.'], ...
        100 * meta.passJoyFraction);
end
if meta.mouseEyeSimFraction > 0
    warnings(end + 1, 1) = sprintf([ ...
        'mouseEyeSim is active on %.1f %% of retained attempts. ', ...
        'Simulated choices are excluded from behavioral inference.'], ...
        100 * meta.mouseEyeSimFraction);
end
meta.warnings = warnings;
end

function value = firstFiniteValue(values)
rows = find(isfinite(values), 1, 'first');
if isempty(rows)
    value = NaN;
else
    value = values(rows);
end
end
