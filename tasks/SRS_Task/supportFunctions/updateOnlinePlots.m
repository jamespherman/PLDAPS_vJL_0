function p = updateOnlinePlots(p)
%UPDATEONLINEPLOTS Update SRS behavioral plots and the online status panel.
%
% Behavioral data are added only for successfully completed trials. Failed
% or aborted attempts refresh the status panel but never alter any plot.
%
% The exploration analysis asks whether the animal switches T1/T2 identity
% on the current successful two-target trial as a function of the reward it
% received on the immediately preceding successful two-target choice trial.

%% ------------------------------------------------------------
% Safety checks
% ------------------------------------------------------------

if ~isfield(p, 'draw') || ~isfield(p.draw, 'onlinePlotWindow') || ...
        ~ishandle(p.draw.onlinePlotWindow) || ...
        ~isfield(p.draw, 'onlinePlotObj')
    return;
end

p = initializeOnlinePlotStorage(p);

trialIdx = getNumericField(p.status, 'iTrial', NaN);
isGoodTrial = isfield(p, 'trData') && ...
    isfield(p.trData, 'GoodTrial') && logical(p.trData.GoodTrial);

rewardDiff = getCurrentRewardDiff(p);
luminanceDiff = getCurrentLuminanceDiff(p);

currentTransition = struct( ...
    'chosenRewardMs', NaN, ...
    'previousRewardMs', NaN, ...
    'switchedTarget', NaN);

%% ------------------------------------------------------------
% Add the current trial only when it was successfully completed
% ------------------------------------------------------------

if isGoodTrial

    if isfinite(rewardDiff)
        appendOrReplacePoint( ...
            p.draw.onlinePlotObj.rewardDiff, trialIdx, rewardDiff);
    end

    if isfinite(luminanceDiff)
        appendOrReplacePoint( ...
            p.draw.onlinePlotObj.luminanceDiff, trialIdx, luminanceDiff);
    end

    trialType = getCurrentTrialType(p);
    nStim = getCurrentNStim(p);
    [hasChoice, chosenTargetID, ~] = getCurrentChoice(p);
    [hasValidRT, rtMs] = getCurrentRT(p);

    choseHighSal = NaN;
    choseHighReward = NaN;
    chosenRewardMs = NaN;
    previousRewardMs = NaN;
    switchedTarget = NaN;

    if hasChoice
        chosenRewardMs = getRewardForTarget(p, chosenTargetID);
    end

    % Instruction trials are forced choices and are excluded from all
    % choice summaries. They can still appear in the reward/luminance
    % time-series because they are successful trials.
    if nStim == 2 && hasChoice
        highSalienceTargetID = getHighSalienceTargetID(p);
        highRewardTargetID = getHighRewardTargetID(p);

        if any(highSalienceTargetID == [1 2])
            choseHighSal = double(chosenTargetID == highSalienceTargetID);
        end

        if any(highRewardTargetID == [1 2])
            choseHighReward = double(chosenTargetID == highRewardTargetID);
        end

        if ~hasValidRT
            rtMs = NaN;
        end

        [previousRewardMs, previousTargetID] = ...
            getPreviousSuccessfulChoice(p, trialIdx);

        if isfinite(previousRewardMs) && any(previousTargetID == [1 2])
            switchedTarget = double(chosenTargetID ~= previousTargetID);
        end
    else
        rtMs = NaN;
    end

    currentTransition.chosenRewardMs = chosenRewardMs;
    currentTransition.previousRewardMs = previousRewardMs;
    currentTransition.switchedTarget = switchedTarget;

    p = upsertSuccessfulTrial( ...
        p, trialIdx, trialType, nStim, choseHighSal, choseHighReward, ...
        rtMs, chosenTargetID, chosenRewardMs, previousRewardMs, ...
        switchedTarget);

    onlineStats = computeOnlineStats(p);
    p = refreshBehavioralPlots(p, onlineStats, trialIdx);

else
    onlineStats = computeOnlineStats(p);
end

%% ------------------------------------------------------------
% Status panel is refreshed after every attempt
% ------------------------------------------------------------

if isfield(p.draw.onlinePlotObj, 'statusText') && ...
        ishandle(p.draw.onlinePlotObj.statusText)

    statusLines = makeOnlineStatusLines( ...
        p, trialIdx, isGoodTrial, rewardDiff, luminanceDiff, ...
        onlineStats, currentTransition);

    set(p.draw.onlinePlotObj.statusText, ...
        'String', statusLines, ...
        'Value', 1);
end

drawnow;

end

%% ========================================================================
% Storage and calculations
% ========================================================================

function p = initializeOnlinePlotStorage(p)

fields = { ...
    'trial', ...
    'trialType', ...
    'nStim', ...
    'choseHighSal', ...
    'choseHighReward', ...
    'rtMs', ...
    'chosenTargetID', ...
    'chosenRewardMs', ...
    'previousRewardMs', ...
    'switchedTarget'};

if ~isfield(p.status, 'onlinePlot') || isempty(p.status.onlinePlot)
    p.status.onlinePlot = struct();
end

nExisting = 0;
if isfield(p.status.onlinePlot, 'trial')
    nExisting = numel(p.status.onlinePlot.trial);
end

for iField = 1:numel(fields)
    fieldName = fields{iField};
    if ~isfield(p.status.onlinePlot, fieldName)
        p.status.onlinePlot.(fieldName) = nan(1, nExisting);
    elseif numel(p.status.onlinePlot.(fieldName)) < nExisting
        p.status.onlinePlot.(fieldName)(end + 1:nExisting) = NaN;
    end
end

end

function p = upsertSuccessfulTrial(p, trialIdx, trialType, nStim, ...
        choseHighSal, choseHighReward, rtMs, chosenTargetID, ...
        chosenRewardMs, previousRewardMs, switchedTarget)

op = p.status.onlinePlot;

if isempty(op.trial) || op.trial(end) ~= trialIdx
    idx = numel(op.trial) + 1;
else
    idx = numel(op.trial);
end

op.trial(idx) = trialIdx;
op.trialType(idx) = trialType;
op.nStim(idx) = nStim;
op.choseHighSal(idx) = choseHighSal;
op.choseHighReward(idx) = choseHighReward;
op.rtMs(idx) = rtMs;
op.chosenTargetID(idx) = chosenTargetID;
op.chosenRewardMs(idx) = chosenRewardMs;
op.previousRewardMs(idx) = previousRewardMs;
op.switchedTarget(idx) = switchedTarget;

p.status.onlinePlot = op;

end

function [previousRewardMs, previousTargetID] = ...
        getPreviousSuccessfulChoice(p, currentTrialIdx)

previousRewardMs = NaN;
previousTargetID = NaN;

op = p.status.onlinePlot;
if isempty(op.trial)
    return;
end

valid = op.nStim == 2 & ...
    op.trial < currentTrialIdx & ...
    isfinite(op.chosenTargetID) & ...
    isfinite(op.chosenRewardMs);

lastIdx = find(valid, 1, 'last');
if isempty(lastIdx)
    return;
end

previousRewardMs = op.chosenRewardMs(lastIdx);
previousTargetID = op.chosenTargetID(lastIdx);

end

function stats = computeOnlineStats(p)

op = p.status.onlinePlot;

trial = op.trial;
trialType = op.trialType;
nStim = op.nStim;
choseHighSal = op.choseHighSal;
choseHighReward = op.choseHighReward;
rtMs = op.rtMs;
previousRewardMs = op.previousRewardMs;
switchedTarget = op.switchedTarget;

isChoice = nStim == 2;

conflictHighSal = isChoice & trialType == 2 & isfinite(choseHighSal);
congruentHighSal = isChoice & trialType == 1 & isfinite(choseHighSal);
conflictHighReward = isChoice & trialType == 2 & isfinite(choseHighReward);
congruentHighReward = isChoice & trialType == 1 & isfinite(choseHighReward);
conflictRT = isChoice & trialType == 2 & isfinite(rtMs);
congruentRT = isChoice & trialType == 1 & isfinite(rtMs);

stats.pHighSalConflict = safeMean(choseHighSal(conflictHighSal));
stats.pHighSalCongruent = safeMean(choseHighSal(congruentHighSal));
stats.nConflictHighSal = sum(conflictHighSal);
stats.nCongruentHighSal = sum(congruentHighSal);

stats.pHighRewardConflict = safeMean(choseHighReward(conflictHighReward));
stats.pHighRewardCongruent = safeMean(choseHighReward(congruentHighReward));
stats.nConflictHighReward = sum(conflictHighReward);
stats.nCongruentHighReward = sum(congruentHighReward);

stats.medianRTConflict = safeMedian(rtMs(conflictRT));
stats.medianRTCongruent = safeMedian(rtMs(congruentRT));
stats.nConflictRT = sum(conflictRT);
stats.nCongruentRT = sum(congruentRT);

validChoice = isChoice & isfinite(choseHighSal);
[stats.xOverall, stats.yOverall] = cumulativeSeries( ...
    trial(validChoice), choseHighSal(validChoice));
[stats.xConflict, stats.yConflict] = cumulativeSeries( ...
    trial(conflictHighSal), choseHighSal(conflictHighSal));
[stats.xCongruent, stats.yCongruent] = cumulativeSeries( ...
    trial(congruentHighSal), choseHighSal(congruentHighSal));

validExploration = isChoice & ...
    isfinite(previousRewardMs) & isfinite(switchedTarget);
stats.explorationX = previousRewardMs(validExploration);
stats.explorationY = switchedTarget(validExploration);
stats.nExploration = sum(validExploration);
stats.pSwitchOverall = safeMean(stats.explorationY);
[stats.explorationBinX, stats.explorationBinY] = ...
    binExplorationData(stats.explorationX, stats.explorationY);

end

function [x, y] = cumulativeSeries(trial, binaryChoice)

if isempty(trial)
    x = NaN;
    y = NaN;
    return;
end

x = trial;
y = cumsum(binaryChoice) ./ (1:numel(binaryChoice));

end

function [binX, binY] = binExplorationData(x, y)

% Use one joint validity mask so x and y remain aligned.
valid = isfinite(x) & isfinite(y);
x = x(valid);
y = y(valid);

if isempty(x)
    binX = NaN;
    binY = NaN;
    return;
end

if min(x) == max(x)
    binX = mean(x);
    binY = mean(y);
    return;
end

nBins = min(6, max(2, round(sqrt(numel(x)))));
edges = linspace(min(x), max(x), nBins + 1);
binX = nan(1, nBins);
binY = nan(1, nBins);

for iBin = 1:nBins
    if iBin < nBins
        inBin = x >= edges(iBin) & x < edges(iBin + 1);
    else
        inBin = x >= edges(iBin) & x <= edges(iBin + 1);
    end

    if any(inBin)
        binX(iBin) = mean(x(inBin));
        binY(iBin) = mean(y(inBin));
    end
end

keep = isfinite(binX) & isfinite(binY);
binX = binX(keep);
binY = binY(keep);

if isempty(binX)
    binX = NaN;
    binY = NaN;
end

end

%% ========================================================================
% Plot updates
% ========================================================================

function p = refreshBehavioralPlots(p, stats, trialIdx)

setIfHandle(p.draw.onlinePlotObj, 'pHighSalConflict', ...
    'YData', stats.pHighSalConflict);
setIfHandle(p.draw.onlinePlotObj, 'pHighSalCongruent', ...
    'YData', stats.pHighSalCongruent);
setIfHandle(p.draw.onlinePlotObj, 'pHighRewardConflict', ...
    'YData', stats.pHighRewardConflict);
setIfHandle(p.draw.onlinePlotObj, 'pHighRewardCongruent', ...
    'YData', stats.pHighRewardCongruent);
setIfHandle(p.draw.onlinePlotObj, 'medianRTConflict', ...
    'YData', stats.medianRTConflict);
setIfHandle(p.draw.onlinePlotObj, 'medianRTCongruent', ...
    'YData', stats.medianRTCongruent);

setXYIfHandle(p.draw.onlinePlotObj, 'choiceOverall', ...
    stats.xOverall, stats.yOverall);
setXYIfHandle(p.draw.onlinePlotObj, 'choiceConflict', ...
    stats.xConflict, stats.yConflict);
setXYIfHandle(p.draw.onlinePlotObj, 'choiceCongruent', ...
    stats.xCongruent, stats.yCongruent);
setXYIfHandle(p.draw.onlinePlotObj, 'explorationRaw', ...
    stats.explorationX, stats.explorationY);
setXYIfHandle(p.draw.onlinePlotObj, 'explorationBinned', ...
    stats.explorationBinX, stats.explorationBinY);

xMax = max(10, trialIdx + 1);
updateTimeSeriesAxis(p, 'rewardDiff', 'rewardDiff', 'rewardZero', xMax, 50);
updateTimeSeriesAxis(p, 'luminanceDiff', 'luminanceDiff', ...
    'luminanceZero', xMax, 1);

if isfield(p.draw.onlinePlotAxes, 'choiceEvolution') && ...
        ishandle(p.draw.onlinePlotAxes.choiceEvolution)
    set(p.draw.onlinePlotAxes.choiceEvolution, ...
        'XLim', [0 xMax], 'YLim', [0 1]);
    setXYIfHandle(p.draw.onlinePlotObj, 'choiceChance', ...
        [0 xMax], [0.5 0.5]);
end

if isfield(p.draw.onlinePlotAxes, 'medianRT') && ...
        ishandle(p.draw.onlinePlotAxes.medianRT)
    allRT = p.status.onlinePlot.rtMs;
    allRT = allRT(isfinite(allRT));
    if isempty(allRT)
        rtMax = 500;
    else
        rtMax = max(500, 1.15 * max(allRT));
    end
    set(p.draw.onlinePlotAxes.medianRT, 'YLim', [0 rtMax]);
end

if isfield(p.draw.onlinePlotAxes, 'exploration') && ...
        ishandle(p.draw.onlinePlotAxes.exploration)
    x = stats.explorationX;
    x = x(isfinite(x));
    if isempty(x)
        xLim = [0 300];
    elseif min(x) == max(x)
        xLim = [max(0, min(x) - 20), max(x) + 20];
    else
        pad = 0.08 * (max(x) - min(x));
        xLim = [max(0, min(x) - pad), max(x) + pad];
    end
    set(p.draw.onlinePlotAxes.exploration, 'XLim', xLim);
    setXYIfHandle(p.draw.onlinePlotObj, 'explorationChance', ...
        xLim, [0.5 0.5]);
end

end

function updateTimeSeriesAxis(p, axisName, dataName, zeroName, xMax, minAbs)

if ~isfield(p.draw.onlinePlotAxes, axisName) || ...
        ~ishandle(p.draw.onlinePlotAxes.(axisName))
    return;
end

set(p.draw.onlinePlotAxes.(axisName), 'XLim', [0 xMax]);
setXYIfHandle(p.draw.onlinePlotObj, zeroName, [0 xMax], [0 0]);

y = get(p.draw.onlinePlotObj.(dataName), 'YData');
y = y(isfinite(y));
if isempty(y)
    yAbs = minAbs;
else
    yAbs = max(minAbs, 1.15 * max(abs(y)));
end
set(p.draw.onlinePlotAxes.(axisName), 'YLim', [-yAbs yAbs]);

end

function setIfHandle(s, fieldName, propertyName, propertyValue)

if isfield(s, fieldName) && ishandle(s.(fieldName))
    set(s.(fieldName), propertyName, propertyValue);
end

end

function setXYIfHandle(s, fieldName, x, y)

if isfield(s, fieldName) && ishandle(s.(fieldName))
    set(s.(fieldName), 'XData', x, 'YData', y);
end

end

function appendOrReplacePoint(plotHandle, x, y)

if ~ishandle(plotHandle)
    return;
end

oldX = get(plotHandle, 'XData');
oldY = get(plotHandle, 'YData');

if numel(oldX) == 1 && isnan(oldX)
    oldX = [];
    oldY = [];
end

if ~isempty(oldX) && oldX(end) == x
    oldY(end) = y;
else
    oldX(end + 1) = x;
    oldY(end + 1) = y;
end

set(plotHandle, 'XData', oldX, 'YData', oldY);

end

%% ========================================================================
% Current-trial extraction
% ========================================================================

function rewardDiff = getCurrentRewardDiff(p)

rewardDiff = NaN;
if isfield(p, 'trVars') && ...
        isfield(p.trVars, 'rewardDurationT1') && ...
        isfield(p.trVars, 'rewardDurationT2')
    rewardDiff = double(p.trVars.rewardDurationT1) - ...
        double(p.trVars.rewardDurationT2);
end

end

function rewardMs = getRewardForTarget(p, targetID)

rewardMs = NaN;
if targetID == 1 && isfield(p.trVars, 'rewardDurationT1')
    rewardMs = double(p.trVars.rewardDurationT1);
elseif targetID == 2 && isfield(p.trVars, 'rewardDurationT2')
    rewardMs = double(p.trVars.rewardDurationT2);
end

end

function luminanceDiff = getCurrentLuminanceDiff(p)

luminanceDiff = NaN;
if isfield(p, 'trVars') && ...
        isfield(p.trVars, 'LuminanceDifferenceT1MinusT2') && ...
        isnumeric(p.trVars.LuminanceDifferenceT1MinusT2) && ...
        isscalar(p.trVars.LuminanceDifferenceT1MinusT2)
    luminanceDiff = double(p.trVars.LuminanceDifferenceT1MinusT2);
elseif isfield(p, 'trVars') && ...
        isfield(p.trVars, 'ActualLuminanceT1') && ...
        isfield(p.trVars, 'ActualLuminanceT2')
    luminanceDiff = double(p.trVars.ActualLuminanceT1) - ...
        double(p.trVars.ActualLuminanceT2);
end

end

function [lumT1, lumT2] = getCurrentLuminanceValues(p)

lumT1 = getNumericField(p.trVars, 'ActualLuminanceT1', NaN);
lumT2 = getNumericField(p.trVars, 'ActualLuminanceT2', NaN);

end

function nStim = getCurrentNStim(p)

nStim = getNumericField(p.trVars, 'nStim', NaN);
if ~isfinite(nStim)
    nStim = getNumericField(p.trData, 'nStim', NaN);
end
if ~isfinite(nStim)
    nStim = getNumericField(p.status, 'CurrentNStim', NaN);
end

end

function trialType = getCurrentTrialType(p)

trialType = getNumericField(p.status, 'ActualTrialType', NaN);
if getCurrentNStim(p) == 1
    trialType = 0;
end

end

function [hasChoice, chosenTargetID, chosenSide] = getCurrentChoice(p)

chosenTargetID = getNumericField(p.trData, 'chosenTargetID', NaN);
chosenSide = getNumericField(p.trData, 'chosenSide', NaN);

if ~any(chosenTargetID == [1 2]) && any(chosenSide == [1 2])
    T1Side = getNumericField(p.trVars, 'T1Side', NaN);
    T2Side = getNumericField(p.trVars, 'T2Side', NaN);
    if chosenSide == T1Side
        chosenTargetID = 1;
    elseif chosenSide == T2Side
        chosenTargetID = 2;
    end
end

hasChoice = any(chosenTargetID == [1 2]);

end

function targetID = getHighSalienceTargetID(p)

targetID = getNumericField(p.status, 'highSalienceTargetID', NaN);
if any(targetID == [1 2])
    return;
end

side = getNumericField(p.status, 'highSalienceSide', NaN);
T1Side = getNumericField(p.trVars, 'T1Side', NaN);
T2Side = getNumericField(p.trVars, 'T2Side', NaN);
if side == T1Side
    targetID = 1;
elseif side == T2Side
    targetID = 2;
end

end

function targetID = getHighRewardTargetID(p)

targetID = getNumericField(p.status, 'highRewardTargetID', NaN);
if ~any(targetID == [1 2])
    targetID = getNumericField(p.status, 'CurrentBlockType', NaN);
end

end

function [hasValidRT, rtMs] = getCurrentRT(p)

hasValidRT = false;
rtMs = NaN;

if ~isfield(p, 'trData') || ~isfield(p.trData, 'timing') || ...
        ~isfield(p.trData.timing, 'fixOff') || ...
        ~isfield(p.trData.timing, 'saccadeOnset')
    return;
end

fixOff = p.trData.timing.fixOff;
saccadeOnset = p.trData.timing.saccadeOnset;

hasValidRT = isnumeric(fixOff) && isnumeric(saccadeOnset) && ...
    isscalar(fixOff) && isscalar(saccadeOnset) && ...
    isfinite(fixOff) && isfinite(saccadeOnset) && ...
    fixOff > 0 && saccadeOnset > fixOff;

if hasValidRT
    rtMs = 1000 * (saccadeOnset - fixOff);
end

end

%% ========================================================================
% Status panel
% ========================================================================

function statusLines = makeOnlineStatusLines(p, trialIdx, isGoodTrial, ...
        rewardDiff, luminanceDiff, stats, currentTransition)

nStim = getCurrentNStim(p);
trialTypeValue = getCurrentTrialType(p);
singleTargetID = getNumericField(p.trVars, 'singleTargetID', NaN);

if nStim == 1 && any(singleTargetID == [1 2])
    trialType = sprintf('Instruction: T%d only', singleTargetID);
elseif trialTypeValue == 1
    trialType = 'Congruent choice';
elseif trialTypeValue == 2
    trialType = 'Conflict choice';
else
    trialType = 'missing';
end

if getNumericField(p.status, 'CurrentBlockType', NaN) == 1
    blockType = 'T1 rich';
elseif getNumericField(p.status, 'CurrentBlockType', NaN) == 2
    blockType = 'T2 rich';
else
    blockType = 'not started';
end

[hasChoice, chosenTargetID, chosenSide] = getCurrentChoice(p);
if hasChoice
    choiceString = sprintf('T%d / %s', chosenTargetID, sideName(chosenSide));
else
    choiceString = 'none';
end

[hasValidRT, rtMs] = getCurrentRT(p);
if hasValidRT
    rtString = sprintf('%.1f ms', rtMs);
else
    rtString = 'missing';
end

currentBlock = getNumericField(p.status, 'CurrentBlockNumber', NaN);
remainingBlock = getNumericField(p.status, 'RemainingBlock', NaN);
totalBlocks = getNumericField(p.status, 'TotalBlocksTarget', NaN);

[lumT1, lumT2] = getCurrentLuminanceValues(p);
dklT1 = getNumericField(p.trVars, 'ActualDklRedLuminanceT1', NaN);
dklT2 = getNumericField(p.trVars, 'ActualDklRedLuminanceT2', NaN);
dklDiff = getNumericField(p.trVars, ...
    'DklRedLuminanceDifferenceT1MinusT2', NaN);
bgDkl = NaN;
if isfield(p.draw, 'clut')
    bgDkl = getNumericField(p.draw.clut, 'srsBackgroundDklLum', NaN);
end
if ~isfinite(bgDkl)
    bgDkl = getNumericField(p.trVars, ...
        'srsLuminanceBackgroundDklLum', NaN);
end

previousReward = currentTransition.previousRewardMs;
chosenReward = currentTransition.chosenRewardMs;
switchValue = currentTransition.switchedTarget;

% On a failed trial, show the latest completed transition rather than
% displaying a misleading current transition.
if ~isGoodTrial && isfield(p.status, 'onlinePlot')
    validTransition = isfinite(p.status.onlinePlot.previousRewardMs) & ...
        isfinite(p.status.onlinePlot.switchedTarget);
    lastIdx = find(validTransition, 1, 'last');
    if ~isempty(lastIdx)
        previousReward = p.status.onlinePlot.previousRewardMs(lastIdx);
        chosenReward = p.status.onlinePlot.chosenRewardMs(lastIdx);
        switchValue = p.status.onlinePlot.switchedTarget(lastIdx);
    end
end

statusLines = { ...
    htmlTitle('TASK STATUS', '#1f4e79'); ...
    htmlLine('Current trial good', yesNoString(isGoodTrial), '#000000'); ...
    htmlLine('Good trials total', valueToString(getNumericField(p.status, 'iGoodTrial', NaN)), '#000000'); ...
    htmlLine('Current attempt', valueToString(trialIdx), '#000000'); ...
    ' '; ...
    htmlSection('BLOCK', '#2f75b5'); ...
    htmlLine('Block type', blockType, '#000000'); ...
    htmlLine('Block number', fractionString(currentBlock, totalBlocks), '#000000'); ...
    htmlLine('Remaining blocks', fractionString(remainingBlock, totalBlocks), '#000000'); ...
    htmlLine('Attempts this block', valueToString(getNumericField(p.status, 'blockAttemptCount', NaN)), '#000000'); ...
    ' '; ...
    htmlSection('BLOCK SCHEDULE', '#548235'); ...
    htmlLine('Completed rows', fractionString( ...
        getNumericField(p.status, 'CurrentBlockTrial', NaN), ...
        getNumericField(p.status, 'TotalTrialsPerBlock', NaN)), '#000000'); ...
    htmlLine('Instruction remaining', fractionString( ...
        getNumericField(p.status, 'RemainingInstructionTrials', NaN), ...
        getNumericField(p.status, 'TotalInstructionTrialsPerBlock', NaN)), '#7f6000'); ...
    htmlLine('Single T1 remaining', fractionString( ...
        getNumericField(p.status, 'RemainingSingleT1', NaN), ...
        getNumericField(p.status, 'TotalSingleT1', NaN)), '#7f6000'); ...
    htmlLine('Single T2 remaining', fractionString( ...
        getNumericField(p.status, 'RemainingSingleT2', NaN), ...
        getNumericField(p.status, 'TotalSingleT2', NaN)), '#7f6000'); ...
    htmlLine('Conflict remaining', fractionString( ...
        getNumericField(p.status, 'RemainingConflict', NaN), ...
        getNumericField(p.status, 'TotalConflict', NaN)), '#c00000'); ...
    htmlLine('Congruent remaining', fractionString( ...
        getNumericField(p.status, 'RemainingCongruent', NaN), ...
        getNumericField(p.status, 'TotalCongruent', NaN)), '#008000'); ...
    ' '; ...
    htmlSection('CURRENT TRIAL', '#7030a0'); ...
    htmlLine('Schedule row', valueToString(getNumericField(p.trVars, 'currentTrialsArrayRow', NaN)), '#000000'); ...
    htmlLine('Condition ID', valueToString(getNumericField(p.trVars, 'conditionID', NaN)), '#000000'); ...
    htmlLine('Trial type', trialType, '#000000'); ...
    htmlLine('Number of stimuli', valueToString(nStim), '#000000'); ...
    htmlLine('T1 side', sideName(getNumericField(p.trVars, 'T1Side', NaN)), '#000000'); ...
    htmlLine('T2 side', sideName(getNumericField(p.trVars, 'T2Side', NaN)), '#000000'); ...
    htmlLine('Rich target', targetAndSideString( ...
        getHighRewardTargetID(p), ...
        getNumericField(p.status, 'highRewardSide', NaN)), '#000000'); ...
    htmlLine('High-salience target', targetAndSideString( ...
        getHighSalienceTargetID(p), ...
        getNumericField(p.status, 'highSalienceSide', NaN)), '#000000'); ...
    htmlLine('Choice', choiceString, '#000000'); ...
    htmlLine('RT', rtString, '#000000'); ...
    ' '; ...
    htmlSection('REWARD', '#c55a11'); ...
    htmlLine('T1 reward', formatNumber(getNumericField(p.trVars, 'rewardDurationT1', NaN), '%.0f ms'), '#000000'); ...
    htmlLine('T2 reward', formatNumber(getNumericField(p.trVars, 'rewardDurationT2', NaN), '%.0f ms'), '#000000'); ...
    htmlLine('Rich / poor', sprintf('%s / %s', ...
        formatNumber(getNumericField(p.status, 'ActualRichReward', NaN), '%.0f ms'), ...
        formatNumber(getNumericField(p.status, 'ActualPoorReward', NaN), '%.0f ms')), '#000000'); ...
    htmlLine('Reward diff T1 - T2', formatNumber(rewardDiff, '%.0f ms'), '#000000'); ...
    htmlLine('Chosen reward', formatNumber(chosenReward, '%.0f ms'), '#000000'); ...
    ' '; ...
    htmlSection('LUMINANCE', '#8064a2'); ...
    htmlLine('Background DKL lum', formatNumber(bgDkl, '%.3f'), '#000000'); ...
    htmlLine('T1 task luminance', formatNumber(lumT1, '%.3f'), '#000000'); ...
    htmlLine('T2 task luminance', formatNumber(lumT2, '%.3f'), '#000000'); ...
    htmlLine('Task lum diff T1-T2', formatNumber(luminanceDiff, '%.3f'), '#000000'); ...
    htmlLine('T1 / T2 DKL lum', sprintf('%s / %s', ...
        formatNumber(dklT1, '%.3f'), formatNumber(dklT2, '%.3f')), '#000000'); ...
    htmlLine('DKL lum diff T1-T2', formatNumber(dklDiff, '%.3f'), '#000000'); ...
    htmlLine('T1 / T2 colorIdx', sprintf('%s / %s', ...
        valueToString(getNumericField(p.trVars, 'T1_colorIdx', NaN)), ...
        valueToString(getNumericField(p.trVars, 'T2_colorIdx', NaN))), '#000000'); ...
    ' '; ...
    htmlSection('HUE CONTRAST', '#7B1FA2'); ...
    htmlLine('Background hue', getFieldString(p.trVars, 'BackgroundHue', '%.1f deg'), '#000000'); ...
    htmlLine('T1 / T2 hue', sprintf('%s / %s', ...
        getFieldString(p.trVars, 'ActualHueT1', '%.1f deg'), ...
        getFieldString(p.trVars, 'ActualHueT2', '%.1f deg')), '#000000'); ...
    htmlLine('T1 / T2 hue distance', sprintf('%s / %s', ...
        getFieldString(p.trVars, 'HueContrastT1', '%.1f deg'), ...
        getFieldString(p.trVars, 'HueContrastT2', '%.1f deg')), '#000000'); ...
    ' '; ...
    htmlSection('EXPLORATION', '#7030a0'); ...
    htmlLine('Previous choice reward', formatNumber(previousReward, '%.0f ms'), '#000000'); ...
    htmlLine('Changed T1/T2 target', switchString(switchValue), '#000000'); ...
    htmlLine('P(switch)', probabilityString(stats.pSwitchOverall, stats.nExploration), '#000000'); ...
    ' '; ...
    htmlSection('ONLINE SUMMARY', '#44546a'); ...
    htmlLine('P high sal conflict', probabilityString( ...
        stats.pHighSalConflict, stats.nConflictHighSal), '#c00000'); ...
    htmlLine('P high sal congruent', probabilityString( ...
        stats.pHighSalCongruent, stats.nCongruentHighSal), '#008000'); ...
    htmlLine('P high reward conflict', probabilityString( ...
        stats.pHighRewardConflict, stats.nConflictHighReward), '#c00000'); ...
    htmlLine('P high reward congruent', probabilityString( ...
        stats.pHighRewardCongruent, stats.nCongruentHighReward), '#008000'); ...
    htmlLine('Median RT conflict', medianString( ...
        stats.medianRTConflict, stats.nConflictRT), '#c00000'); ...
    htmlLine('Median RT congruent', medianString( ...
        stats.medianRTCongruent, stats.nCongruentRT), '#008000') ...
    };

end

%% ========================================================================
% Generic helpers
% ========================================================================

function value = safeMean(x)

x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = mean(x);
end

end

function value = safeMedian(x)

x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = median(x);
end

end

function value = getNumericField(s, fieldName, defaultValue)

value = defaultValue;
if isstruct(s) && isfield(s, fieldName) && ...
        isnumeric(s.(fieldName)) && isscalar(s.(fieldName))
    value = double(s.(fieldName));
end

end

function txt = getFieldString(s, fieldName, fmt)

if nargin < 3
    fmt = '';
end

if ~isstruct(s) || ~isfield(s, fieldName)
    txt = 'missing';
    return;
end

value = s.(fieldName);
if ~isempty(fmt) && isnumeric(value) && isscalar(value)
    txt = formatNumber(value, fmt);
else
    txt = valueToString(value);
end

end

function txt = valueToString(value)

if ischar(value)
    txt = value;
elseif isstring(value)
    txt = char(value);
elseif isnumeric(value)
    if isscalar(value)
        if isfinite(value)
            txt = num2str(value);
        else
            txt = 'NaN';
        end
    else
        txt = mat2str(value);
    end
elseif islogical(value)
    txt = yesNoString(value);
elseif iscategorical(value)
    txt = char(value);
else
    txt = '<unsupported type>';
end

end

function txt = formatNumber(value, fmt)

if isnumeric(value) && isscalar(value) && isfinite(value)
    txt = sprintf(fmt, value);
else
    txt = 'NaN';
end

end

function txt = fractionString(value, total)

if isfinite(value) && isfinite(total)
    txt = sprintf('%.0f / %.0f', value, total);
elseif isfinite(value)
    txt = sprintf('%.0f / ?', value);
else
    txt = 'missing';
end

end

function txt = sideName(side)

if side == 1
    txt = 'right';
elseif side == 2
    txt = 'left';
else
    txt = 'none';
end

end

function txt = targetAndSideString(targetID, side)

if any(targetID == [1 2])
    txt = sprintf('T%d / %s', targetID, sideName(side));
else
    txt = 'none';
end

end

function txt = yesNoString(value)

if logical(value)
    txt = 'yes';
else
    txt = 'no';
end

end

function txt = switchString(value)

if ~isfinite(value)
    txt = 'not available';
elseif value == 1
    txt = 'yes';
else
    txt = 'no';
end

end

function txt = probabilityString(value, n)

if isfinite(value)
    txt = sprintf('%.1f%%  (n=%.0f)', 100 * value, n);
else
    txt = sprintf('NaN  (n=%.0f)', n);
end

end

function txt = medianString(value, n)

if isfinite(value)
    txt = sprintf('%.1f ms  (n=%.0f)', value, n);
else
    txt = sprintf('NaN  (n=%.0f)', n);
end

end

function line = htmlTitle(txt, color)

line = sprintf( ...
    '<html><font color="%s" size="5"><b>%s</b></font></html>', ...
    color, txt);

end

function line = htmlSection(txt, color)

line = sprintf( ...
    '<html><font color="%s" size="4"><b>%s</b></font></html>', ...
    color, txt);

end

function line = htmlLine(label, value, color)

line = sprintf( ...
    '<html><font color="%s"><b>%-23s</b> : %s</font></html>', ...
    color, label, value);

end
