function [T, meta] = srs_load_session(sessionFolder)
%SRS_LOAD_SESSION Read a PLDAPS SRS session directly from MAT files.
%
%   [T, META] = SRS_LOAD_SESSION(SESSIONFOLDER)
%
% Input
% -----
% SESSIONFOLDER: folder containing trial0001.mat, trial0002.mat, etc.
%
% Outputs
% -------
% T: one row per saved attempt, including raw fields and derived behavioral
%    variables such as reward choice, spatial choice, reaction time, and
%    sequential dependencies.
% META: session metadata and validity warnings.
%
% This function does not depend on pds.loadP and never modifies raw data.

%% Folder checks
if nargin < 1 || isempty(sessionFolder)
    error('A session folder must be provided.');
end

if isstring(sessionFolder)
    sessionFolder = char(sessionFolder);
end

if ~isfolder(sessionFolder)
    error('The session folder does not exist: %s', sessionFolder);
end

fileInfo = dir(fullfile(sessionFolder, 'trial*.mat'));
if isempty(fileInfo)
    error('No trialXXXX.mat file was found in: %s', sessionFolder);
end

% Sort numerically even if filenames are not always zero-padded.
%
fileNumbers = nan(numel(fileInfo), 1);
for iFile = 1:numel(fileInfo)
    token = regexp(fileInfo(iFile).name, 'trial(\d+)\.mat', ...
        'tokens', 'once');
    if ~isempty(token)
        fileNumbers(iFile) = str2double(token{1});
    end
end
[~, sortOrder] = sort(fileNumbers);
fileInfo = fileInfo(sortOrder);
fileNumbers = fileNumbers(sortOrder);

%% Read the first file to identify the session
firstFile = fullfile(sessionFolder, fileInfo(1).name);
firstData = load(firstFile, 'trVars', 'trData', 'status', 'init');

[~, folderName] = fileparts(sessionFolder);
sessionID = getText(firstData.init, 'sessionId', folderName);
experimentType = getText(firstData.init, 'exptType', 'unknown');
taskName = getText(firstData.init, 'taskName', 'srsSmooth');
sessionDate = getText(firstData.init, 'date', '');
sessionTime = getText(firstData.init, 'time', '');

nFiles = numel(fileInfo);
rows = repmat(emptyTrialRow(), nFiles, 1);

%% Read every saved attempt
for iFile = 1:nFiles
    filePath = fullfile(sessionFolder, fileInfo(iFile).name);

    % Load only useful structures and skip large function-workspace fields.

    S = load(filePath, 'trVars', 'trData', 'status', 'init');

    if ~isfield(S, 'trVars') || ~isfield(S, 'trData') || ...
            ~isfield(S, 'status')
        error('File %s does not contain trVars/trData/status.', ...
            fileInfo(iFile).name);
    end

    tv = S.trVars;
    td = S.trData;
    st = S.status;

    if isfield(td, 'timing') && isstruct(td.timing)
        timing = td.timing;
    else
        timing = struct();
    end

    r = emptyTrialRow();

    % Attempt identification
    r.SessionID = string(sessionID);
    r.ExperimentType = string(experimentType);
    r.FileName = string(fileInfo(iFile).name);
    r.FileTrialIndex = fileNumbers(iFile);
    r.Attempt = getScalar(st, 'iTrial', fileNumbers(iFile));
    r.GoodTrialIndexBefore = getScalar(st, 'iGoodTrial', NaN);

    % Block and condition structure
    r.Block = getScalar(st, 'CurrentBlockNumber', NaN);
    r.BlockAttempt = getScalar(st, 'blockAttemptCount', NaN);
    r.BlockGoodBefore = getScalar(st, 'CurrentBlockTrial', NaN);
    r.ExpectedTrialsInBlock = getScalar(st, 'TotalTrialsPerBlock', NaN);
    r.ExpectedChoiceTrialsInBlock = ...
        getScalar(st, 'TotalChoiceTrialsPerBlock', NaN);
    r.ExpectedInstructionTrialsInBlock = ...
        getScalar(st, 'TotalInstructionTrialsPerBlock', NaN);
    r.TotalBlocksTarget = getScalar(st, 'TotalBlocksTarget', NaN);
    r.BlockRichTarget = getScalar(st, 'CurrentBlockType', NaN);
    r.TrialType = getScalar(st, 'ActualTrialType', NaN);
    r.ConditionID = getScalar(tv, 'conditionID', NaN);
    r.SchedulePhase = getScalar(tv, 'schedulePhase', NaN);
    r.CurrentScheduleRow = getScalar(tv, 'currentTrialsArrayRow', NaN);
    r.TrialSeed = getScalar(tv, 'trialSeed', NaN);

    % Number and identity of targets
    r.NStim = getScalar(tv, 'nStim', NaN);
    r.SingleTargetID = getScalar(tv, 'singleTargetID', NaN);
    r.T1Side = getScalar(tv, 'T1Side', NaN);
    r.T2Side = getScalar(tv, 'T2Side', NaN);

    % Rich and high-salience targets. These values apply to the current
    % attempt even though cumulative status counters may be saved before
    % their update in srsSmooth_finish.
    r.RichTarget = getScalar(st, 'highRewardTargetID', ...
        getScalar(st, 'CurrentBlockType', NaN));
    r.RichSide = getScalar(st, 'highRewardSide', NaN);
    r.HighSalienceTarget = getScalar(st, 'highSalienceTargetID', NaN);
    r.HighSalienceSide = getScalar(st, 'highSalienceSide', NaN);

    % Observed response
    r.ChosenTarget = getScalar(td, 'chosenTargetID', 0);
    r.ChosenSide = getScalar(td, 'chosenSide', 0);
    r.Outcome = string(getText(td, 'outcome', ''));
    r.OutcomeCode = getScalar(td, 'outcomeCode', 0);
    r.TrialEndState = getScalar(td, 'trialEndState', NaN);

    goodField = getScalar(td, 'GoodTrial', NaN);
    if isfinite(goodField)
        r.GoodTrial = logical(goodField);
    else
        % 455 corresponds to p.state.sacComplete in this SRS version.
        r.GoodTrial = r.TrialEndState == 455;
    end

    r.TrialRepeatFlag = getScalar(td, 'trialRepeatFlag', NaN);
    r.MissedFrames = getScalar(td, 'missedFrameCount', 0);

    % Debug/bypass modes. In this task, passEye=1 forces selection of the
    % rich target on two-target trials.
    r.PassEye = getScalar(tv, 'passEye', 0);
    r.PassJoy = getScalar(tv, 'passJoy', 0);
    r.MouseEyeSim = getScalar(tv, 'mouseEyeSim', 0);

    % Reward variables
    r.RewardT1Ms = getScalar(tv, 'rewardDurationT1', NaN);
    r.RewardT2Ms = getScalar(tv, 'rewardDurationT2', NaN);
    r.ActualRichRewardMs = getScalar(st, 'ActualRichReward', NaN);
    r.ActualPoorRewardMs = getScalar(st, 'ActualPoorReward', NaN);
    r.RewardDifferenceT1MinusT2Ms = r.RewardT1Ms - r.RewardT2Ms;

    if r.ChosenTarget == 1
        r.ChosenRewardMs = r.RewardT1Ms;
    elseif r.ChosenTarget == 2
        r.ChosenRewardMs = r.RewardT2Ms;
    else
        r.ChosenRewardMs = NaN;
    end

    % DKL hue salience
    r.SalienceType = getScalar(tv, 'salienceType', NaN);
    r.BackgroundHueDeg = getScalar(tv, 'BackgroundHue', NaN);
    r.HueT1Deg = getScalar(tv, 'ActualHueT1', NaN);
    r.HueT2Deg = getScalar(tv, 'ActualHueT2', NaN);
    r.HueContrastT1Deg = getScalar(tv, 'HueContrastT1', NaN);
    r.HueContrastT2Deg = getScalar(tv, 'HueContrastT2', NaN);
    r.HueContrastDifferenceT1MinusT2Deg = ...
        getScalar(tv, 'HueContrastDifferenceT1MinusT2', NaN);
    r.HueContrastMagnitudeDeg = ...
        getScalar(tv, 'HueContrastDifferenceMagnitude', NaN);

    % Luminance salience when that mode is used
    r.MeasuredLuminanceT1CdM2 = ...
        getScalar(tv, 'MeasuredLuminanceT1CdM2', NaN);
    r.MeasuredLuminanceT2CdM2 = ...
        getScalar(tv, 'MeasuredLuminanceT2CdM2', NaN);
    r.MeasuredLuminanceDifferenceT1MinusT2CdM2 = ...
        getScalar(tv, 'MeasuredLuminanceDifferenceT1MinusT2CdM2', NaN);

    % Timing events are relative to trial onset, except TrialStartPTB,
    % which is an absolute GetSecs clock.
    r.TrialStartPTB = getScalar(timing, 'trialStartPTB', NaN);
    r.TrialStartDP = getScalar(timing, 'trialStartDP', NaN);
    r.TrialDurationSec = getScalar(timing, 'trialEnd', NaN);
    r.FixOnSec = getScalar(timing, 'fixOn', NaN);
    r.FixAcquiredSec = getScalar(timing, 'fixAq', NaN);
    r.FixHoldReqMetSec = getScalar(timing, 'fixHoldReqMet', NaN);
    r.FixOffSec = getScalar(timing, 'fixOff', NaN);
    r.SaccadeOnsetSec = getScalar(timing, 'saccadeOnset', NaN);
    r.SaccadeOffsetSec = getScalar(timing, 'saccadeOffset', NaN);
    r.TargetAcquiredSec = getScalar(timing, 'targetAq', NaN);
    r.JoyPressSec = getScalar(timing, 'joyPress', NaN);
    r.JoyReleaseSec = getScalar(timing, 'joyRelease', NaN);
    r.RewardTimeSec = getScalar(timing, 'reward', NaN);

    % Fixation-acquisition latency is an operational engagement measure.

    % Negative PLDAPS sentinel values are rejected.

    if isfinite(r.FixOnSec) && isfinite(r.FixAcquiredSec) && ...
            r.FixOnSec >= 0 && r.FixAcquiredSec >= r.FixOnSec
        r.FixAcquisitionLatencyMs = ...
            1000 * (r.FixAcquiredSec - r.FixOnSec);
    else
        r.FixAcquisitionLatencyMs = NaN;
    end

    % A reaction time is accepted only when both timestamps exist and occur
    % in the correct order. passEye can produce saccadeOnset before fixOff,
    % so those values are marked NaN.
    if isfinite(r.FixOffSec) && isfinite(r.SaccadeOnsetSec) && ...
            r.FixOffSec > 0 && r.SaccadeOnsetSec > r.FixOffSec
        r.ReactionTimeMs = 1000 * (r.SaccadeOnsetSec - r.FixOffSec);
    else
        r.ReactionTimeMs = NaN;
    end

    if isfinite(r.SaccadeOnsetSec) && isfinite(r.SaccadeOffsetSec) && ...
            r.SaccadeOffsetSec > r.SaccadeOnsetSec
        r.SaccadeDurationMs = ...
            1000 * (r.SaccadeOffsetSec - r.SaccadeOnsetSec);
    else
        r.SaccadeDurationMs = NaN;
    end

    % Total time from fixation offset to target acquisition, including
    % response latency and saccade duration.
    if isfinite(r.FixOffSec) && isfinite(r.TargetAcquiredSec) && ...
            r.FixOffSec > 0 && r.TargetAcquiredSec > r.FixOffSec
        r.TargetAcquisitionLatencyMs = ...
            1000 * (r.TargetAcquiredSec - r.FixOffSec);
    else
        r.TargetAcquisitionLatencyMs = NaN;
    end

    rows(iFile) = r;
end

%% Convert to a table and add derived variables
T = struct2table(rows);

% Files are already sorted, but sorting by Attempt protects against renamed
% or copied files.
[~, rowOrder] = sort(T.Attempt);
T = T(rowOrder, :);

nTrials = height(T);

T.TrialTypeLabel = repmat("Other", nTrials, 1);
T.TrialTypeLabel(T.NStim == 1) = "Instruction";
T.TrialTypeLabel(T.NStim == 2 & T.TrialType == 1) = "Congruent";
T.TrialTypeLabel(T.NStim == 2 & T.TrialType == 2) = "Conflict";

T.T1SideLabel = sideLabels(T.T1Side);
T.T2SideLabel = sideLabels(T.T2Side);
T.ChosenSideLabel = sideLabels(T.ChosenSide);
T.RichSideLabel = sideLabels(T.RichSide);
T.HighSalienceSideLabel = sideLabels(T.HighSalienceSide);

T.IsInstruction = T.NStim == 1;
T.IsChoice = T.NStim == 2;
T.IsCongruent = T.IsChoice & T.TrialType == 1;
T.IsConflict = T.IsChoice & T.TrialType == 2;

T.GoodChoice = T.GoodTrial & T.IsChoice & ...
    ismember(T.ChosenTarget, [1 2]) & ismember(T.ChosenSide, [1 2]);

% Binary choice variables use NaN when the variable does not apply or no
% valid choice was produced.
T.ChoseRight = nan(nTrials, 1);
T.ChoseT1 = nan(nTrials, 1);
T.ChoseRich = nan(nTrials, 1);
T.ChoseHighSalience = nan(nTrials, 1);

validChoice = T.GoodChoice;
T.ChoseRight(validChoice) = double(T.ChosenSide(validChoice) == 1);
T.ChoseT1(validChoice) = double(T.ChosenTarget(validChoice) == 1);
T.ChoseRich(validChoice) = double( ...
    T.ChosenTarget(validChoice) == T.RichTarget(validChoice));
T.ChoseHighSalience(validChoice) = double( ...
    T.ChosenTarget(validChoice) == T.HighSalienceTarget(validChoice));

T.ChoseLeft = 1 - T.ChoseRight;
T.ChoseT2 = 1 - T.ChoseT1;
T.ChosePoor = 1 - T.ChoseRich;
T.ChoseLowSalience = 1 - T.ChoseHighSalience;

% Predictors used to separate spatial, identity, reward, and salience
% strategies in choice models.
T.T1OnRight = double(T.T1Side == 1);
T.RichOnRight = double(T.RichSide == 1);
T.HighSalienceOnRight = double(T.HighSalienceSide == 1);
T.T1IsRich = double(T.RichTarget == 1);
T.T1IsHighSalience = double(T.HighSalienceTarget == 1);

% Verify that the recorded chosen side matches the chosen target identity.
T.ChoiceMappingValid = false(nTrials, 1);
mapT1 = validChoice & T.ChosenTarget == 1;
mapT2 = validChoice & T.ChosenTarget == 2;
T.ChoiceMappingValid(mapT1) = T.ChosenSide(mapT1) == T.T1Side(mapT1);
T.ChoiceMappingValid(mapT2) = T.ChosenSide(mapT2) == T.T2Side(mapT2);

% Compute cumulative indices directly from files instead of trusting status
% counters saved before updateStatusVariables.
T.GoodTrialOrdinal = cumsum(double(T.GoodTrial));
T.ChoiceOrdinal = nan(nTrials, 1);
T.ChoiceOrdinal(validChoice) = (1:sum(validChoice))';

% Block identifiers remain unique when sessions are concatenated.
%
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
    idx = find(T.BlockUID == uniqueBlocks(iBlock));
    goodCount = 0;
    choiceCount = 0;
    for j = 1:numel(idx)
        rowIdx = idx(j);
        if T.GoodTrial(rowIdx)
            goodCount = goodCount + 1;
            T.GoodTrialInBlock(rowIdx) = goodCount;
        end
        if T.GoodChoice(rowIdx)
            choiceCount = choiceCount + 1;
            T.ChoiceInBlock(rowIdx) = choiceCount;
        end
    end
end

% Elapsed time and interval before each attempt.
firstStart = firstFinite(T.TrialStartPTB);
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

% Sequential dependencies between successive two-target choices. Instruction
% and failed trials are skipped when locating the previous choice.
%
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

% passEye and simulated-eye trials remain useful for technical checks but
% are excluded from inference about the animal's strategy.
%
T.RealEyeChoice = T.GoodChoice & T.PassEye == 0 & T.MouseEyeSim == 0;

%% Metadata and validity warnings
meta = struct();
meta.sessionFolder = sessionFolder;
meta.sessionID = sessionID;
meta.experimentType = experimentType;
meta.taskName = taskName;
meta.sessionDate = sessionDate;
meta.sessionTime = sessionTime;
meta.nAttemptFiles = nTrials;
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
meta.totalBlocksTarget = firstFinite(T.TotalBlocksTarget);

if isfinite(firstStart)
    finalEnd = T.TrialStartPTB(end) + T.TrialDurationSec(end);
    meta.sessionDurationMin = (finalEnd - firstStart) / 60;
else
    meta.sessionDurationMin = NaN;
end

warnings = strings(0, 1);
if meta.passEyeFraction > 0
    warnings(end + 1, 1) = sprintf([ ...
        'passEye is active on %.1f %% of attempts. In this SRS version, ', ...
        'passEye automatically selects the rich target on two-target ', ...
        'trials. These choices are therefore not behavioral observations.'], ...
        100 * meta.passEyeFraction);
end
if meta.passJoyFraction > 0
    warnings(end + 1, 1) = sprintf([ ...
        'passJoy is active on %.1f %% of attempts. Engagement measures ', ...
        'related to joystick behavior must be interpreted cautiously.'], ...
        100 * meta.passJoyFraction);
end
if meta.mouseEyeSimFraction > 0
    warnings(end + 1, 1) = sprintf([ ...
        'mouseEyeSim is active on %.1f %% of attempts.'], ...
        100 * meta.mouseEyeSimFraction);
end
if meta.mappingErrors > 0
    warnings(end + 1, 1) = sprintf([ ...
        '%d choices have an inconsistency between chosen identity and chosen side.'], ...
        meta.mappingErrors);
end
if meta.nGoodChoices > 0 && meta.nRealEyeChoices == 0
    warnings(end + 1, 1) = [ ...
        "No real eye-controlled two-target choice is " + ...
        "available for inferential tests."];
end
meta.warnings = warnings;

end

%% ========================================================================
% Local utility functions
% ========================================================================

function r = emptyTrialRow()
% Define every field once so struct2table produces homogeneous columns even
% when aborted trials lack some fields.

r = struct( ...
    'SessionID', "", ...
    'ExperimentType', "", ...
    'FileName', "", ...
    'FileTrialIndex', NaN, ...
    'Attempt', NaN, ...
    'GoodTrialIndexBefore', NaN, ...
    'Block', NaN, ...
    'BlockAttempt', NaN, ...
    'BlockGoodBefore', NaN, ...
    'ExpectedTrialsInBlock', NaN, ...
    'ExpectedChoiceTrialsInBlock', NaN, ...
    'ExpectedInstructionTrialsInBlock', NaN, ...
    'TotalBlocksTarget', NaN, ...
    'BlockRichTarget', NaN, ...
    'TrialType', NaN, ...
    'ConditionID', NaN, ...
    'SchedulePhase', NaN, ...
    'CurrentScheduleRow', NaN, ...
    'TrialSeed', NaN, ...
    'NStim', NaN, ...
    'SingleTargetID', NaN, ...
    'T1Side', NaN, ...
    'T2Side', NaN, ...
    'RichTarget', NaN, ...
    'RichSide', NaN, ...
    'HighSalienceTarget', NaN, ...
    'HighSalienceSide', NaN, ...
    'ChosenTarget', NaN, ...
    'ChosenSide', NaN, ...
    'Outcome', "", ...
    'OutcomeCode', NaN, ...
    'TrialEndState', NaN, ...
    'GoodTrial', false, ...
    'TrialRepeatFlag', NaN, ...
    'MissedFrames', NaN, ...
    'PassEye', NaN, ...
    'PassJoy', NaN, ...
    'MouseEyeSim', NaN, ...
    'RewardT1Ms', NaN, ...
    'RewardT2Ms', NaN, ...
    'ActualRichRewardMs', NaN, ...
    'ActualPoorRewardMs', NaN, ...
    'RewardDifferenceT1MinusT2Ms', NaN, ...
    'ChosenRewardMs', NaN, ...
    'SalienceType', NaN, ...
    'BackgroundHueDeg', NaN, ...
    'HueT1Deg', NaN, ...
    'HueT2Deg', NaN, ...
    'HueContrastT1Deg', NaN, ...
    'HueContrastT2Deg', NaN, ...
    'HueContrastDifferenceT1MinusT2Deg', NaN, ...
    'HueContrastMagnitudeDeg', NaN, ...
    'MeasuredLuminanceT1CdM2', NaN, ...
    'MeasuredLuminanceT2CdM2', NaN, ...
    'MeasuredLuminanceDifferenceT1MinusT2CdM2', NaN, ...
    'TrialStartPTB', NaN, ...
    'TrialStartDP', NaN, ...
    'TrialDurationSec', NaN, ...
    'FixOnSec', NaN, ...
    'FixAcquiredSec', NaN, ...
    'FixHoldReqMetSec', NaN, ...
    'FixOffSec', NaN, ...
    'SaccadeOnsetSec', NaN, ...
    'SaccadeOffsetSec', NaN, ...
    'TargetAcquiredSec', NaN, ...
    'JoyPressSec', NaN, ...
    'JoyReleaseSec', NaN, ...
    'RewardTimeSec', NaN, ...
    'FixAcquisitionLatencyMs', NaN, ...
    'ReactionTimeMs', NaN, ...
    'SaccadeDurationMs', NaN, ...
    'TargetAcquisitionLatencyMs', NaN);

end

function value = getScalar(s, fieldName, defaultValue)
% Return a numeric/logical scalar or a default value.

if nargin < 3
    defaultValue = NaN;
end
value = defaultValue;

if ~isstruct(s) || ~isfield(s, fieldName)
    return;
end

candidate = s.(fieldName);
if (isnumeric(candidate) || islogical(candidate)) && ...
        isscalar(candidate) && ~isempty(candidate)
    value = double(candidate);
end

end

function value = getText(s, fieldName, defaultValue)
% Convertir proprement char/string/cellstr en texte MATLAB char.

if nargin < 3
    defaultValue = '';
end
value = defaultValue;

if ~isstruct(s) || ~isfield(s, fieldName)
    return;
end

candidate = s.(fieldName);
if isstring(candidate) && isscalar(candidate)
    value = char(candidate);
elseif ischar(candidate)
    value = candidate;
elseif iscell(candidate) && numel(candidate) == 1 && ...
        (ischar(candidate{1}) || isstring(candidate{1}))
    value = char(candidate{1});
end

end

function labels = sideLabels(sideValues)
labels = repmat("None", size(sideValues));
labels(sideValues == 1) = "Right";
labels(sideValues == 2) = "Left";
labels(~ismember(sideValues, [0 1 2])) = "Manquant";
end

function value = firstFinite(x)
idx = find(isfinite(x), 1, 'first');
if isempty(idx)
    value = NaN;
else
    value = x(idx);
end
end
