function p = updateOnlinePlots(p)
%UPDATEONLINEPLOTS Update SRS behavioral plots and the online status panel.
%
% Behavioral data are added only for successfully completed trials. Failed
% or aborted attempts refresh the status panel but never alter any plot.
%
% Exploration relates switching on the current successful two-target trial
% to the reward and decision category of the preceding successful choice.
% Congruent and conflict-high-reward/high-salience histories are separated.

%% ------------------------------------------------------------
% Safety checks
% ------------------------------------------------------------

if ~isfield(p, 'draw') || ~isfield(p.draw, 'onlinePlotWindow') || ...
        ~ishandle(p.draw.onlinePlotWindow) || ...
        ~isfield(p.draw, 'onlinePlotObj')
    return;
end

p = initializeOnlinePlotStorage(p);

attemptTrialIdx = getNumericField(p.status, 'iTrial', NaN);
goodTrialIdx = getNumericField(p.status, 'iGoodTrial', NaN);
isGoodTrial = isfield(p, 'trData') && ...
    isfield(p.trData, 'GoodTrial') && logical(p.trData.GoodTrial);

rewardDiff = getCurrentRewardDiff(p);
luminanceDiff = getCurrentLuminanceDiff(p);
hueContrastDiff = getCurrentHueContrastDiff(p);

currentTransition = struct( ...
    'chosenRewardMs', NaN, ...
    'previousRewardMs', NaN, ...
    'previousTrialType', NaN, ...
    'previousChoiceClass', NaN, ...
    'currentTrialType', NaN, ...
    'currentChoiceClass', NaN, ...
    'switchedTarget', NaN);

%% ------------------------------------------------------------
% Add the current trial only when it was successfully completed
% ------------------------------------------------------------

if isGoodTrial

    if isfinite(rewardDiff)
        appendOrReplacePoint( ...
            p.draw.onlinePlotObj.rewardDiff, goodTrialIdx, rewardDiff);
    end

    if isfinite(luminanceDiff)
        appendOrReplacePoint( ...
            p.draw.onlinePlotObj.luminanceDiff, goodTrialIdx, luminanceDiff);
    end

    if isfinite(hueContrastDiff)
        appendOrReplacePoint( ...
            p.draw.onlinePlotObj.hueContrastDiff, ...
            goodTrialIdx, hueContrastDiff);
    end

    trialType = getCurrentTrialType(p);
    nStim = getCurrentNStim(p);
    [hasChoice, chosenTargetID, ~] = getCurrentChoice(p);
    [hasValidRT, rtMs] = getCurrentRT(p);

    mappingValid = NaN;
    choseHighSal = NaN;
    choseHighReward = NaN;
    chosenRewardMs = NaN;
    previousRewardMs = NaN;
    previousTrialType = NaN;
    previousChoseHighReward = NaN;
    previousChoseHighSalience = NaN;
    previousChoiceClass = NaN;
    switchedTarget = NaN;

    if hasChoice
        chosenRewardMs = getRewardForTarget(p, chosenTargetID);
    end

    % Single-target instruction trials are forced choices and are excluded
    % from choice summaries. They can still appear in the time-series.
    if nStim == 2 && hasChoice
        highSalienceTargetID = getHighSalienceTargetID(p);
        highRewardTargetID = getHighRewardTargetID(p);

        mappingValid = validateEvidenceMapping( ...
            trialType, highRewardTargetID, highSalienceTargetID);

        if mappingValid
            choseHighSal = double(chosenTargetID == highSalienceTargetID);
            choseHighReward = double(chosenTargetID == highRewardTargetID);
        else
            warning(['Online plots excluded a choice trial because the ', ...
                'reward/salience mapping was inconsistent with its ', ...
                'congruent/conflict label.']);
        end

        if ~hasValidRT
            rtMs = NaN;
        end

        [previousRewardMs, previousTargetID, previousTrialType, ...
            previousChoseHighReward, previousChoseHighSalience] = ...
            getPreviousSuccessfulChoice(p, goodTrialIdx);

        previousChoiceClass = classifyChoiceCategory( ...
            previousTrialType, previousChoseHighReward, ...
            previousChoseHighSalience);

        if isfinite(previousRewardMs) && any(previousTargetID == [1 2])
            switchedTarget = double(chosenTargetID ~= previousTargetID);
        end
    else
        rtMs = NaN;
    end

    currentTransition.chosenRewardMs = chosenRewardMs;
    currentTransition.previousRewardMs = previousRewardMs;
    currentTransition.previousTrialType = previousTrialType;
    currentTransition.previousChoiceClass = previousChoiceClass;
    currentTransition.currentTrialType = trialType;
    currentTransition.currentChoiceClass = classifyChoiceCategory( ...
        trialType, choseHighReward, choseHighSal);
    currentTransition.switchedTarget = switchedTarget;

    p = upsertSuccessfulTrial( ...
        p, goodTrialIdx, attemptTrialIdx, trialType, nStim, mappingValid, ...
        choseHighSal, choseHighReward, rtMs, chosenTargetID, ...
        chosenRewardMs, previousRewardMs, previousTrialType, ...
        previousChoseHighReward, previousChoseHighSalience, switchedTarget);

    onlineStats = computeOnlineStats(p);
    p = refreshBehavioralPlots(p, onlineStats, goodTrialIdx);

else
    onlineStats = computeOnlineStats(p);
end

%% ------------------------------------------------------------
% Status panel is refreshed after every attempt
% ------------------------------------------------------------

if isfield(p.draw.onlinePlotObj, 'statusText') && ...
        ishandle(p.draw.onlinePlotObj.statusText)

    statusLines = makeOnlineStatusLines( ...
        p, attemptTrialIdx, goodTrialIdx, isGoodTrial, rewardDiff, ...
        luminanceDiff, hueContrastDiff, ...
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
    'attemptTrial', ...
    'trialType', ...
    'nStim', ...
    'mappingValid', ...
    'choseHighSal', ...
    'choseHighReward', ...
    'rtMs', ...
    'chosenTargetID', ...
    'chosenRewardMs', ...
    'previousRewardMs', ...
    'previousTrialType', ...
    'previousChoseHighReward', ...
    'previousChoseHighSalience', ...
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

function p = upsertSuccessfulTrial(p, goodTrialIdx, attemptTrialIdx, ...
        trialType, nStim, mappingValid, choseHighSal, choseHighReward, ...
        rtMs, chosenTargetID, chosenRewardMs, previousRewardMs, ...
        previousTrialType, previousChoseHighReward, ...
        previousChoseHighSalience, switchedTarget)

op = p.status.onlinePlot;

if isempty(op.trial) || op.trial(end) ~= goodTrialIdx
    idx = numel(op.trial) + 1;
else
    idx = numel(op.trial);
end

op.trial(idx) = goodTrialIdx;
op.attemptTrial(idx) = attemptTrialIdx;
op.trialType(idx) = trialType;
op.nStim(idx) = nStim;
op.mappingValid(idx) = mappingValid;
op.choseHighSal(idx) = choseHighSal;
op.choseHighReward(idx) = choseHighReward;
op.rtMs(idx) = rtMs;
op.chosenTargetID(idx) = chosenTargetID;
op.chosenRewardMs(idx) = chosenRewardMs;
op.previousRewardMs(idx) = previousRewardMs;
op.previousTrialType(idx) = previousTrialType;
op.previousChoseHighReward(idx) = previousChoseHighReward;
op.previousChoseHighSalience(idx) = previousChoseHighSalience;
op.switchedTarget(idx) = switchedTarget;

p.status.onlinePlot = op;

end

function [previousRewardMs, previousTargetID, previousTrialType, ...
        previousChoseHighReward, previousChoseHighSalience] = ...
        getPreviousSuccessfulChoice(p, currentGoodTrialIdx)

previousRewardMs = NaN;
previousTargetID = NaN;
previousTrialType = NaN;
previousChoseHighReward = NaN;
previousChoseHighSalience = NaN;

op = p.status.onlinePlot;
if isempty(op.trial)
    return;
end

valid = op.nStim == 2 & ...
    op.mappingValid == 1 & ...
    op.trial < currentGoodTrialIdx & ...
    isfinite(op.chosenTargetID) & ...
    isfinite(op.chosenRewardMs);

lastIdx = find(valid, 1, 'last');
if isempty(lastIdx)
    return;
end

previousRewardMs = op.chosenRewardMs(lastIdx);
previousTargetID = op.chosenTargetID(lastIdx);
previousTrialType = op.trialType(lastIdx);
previousChoseHighReward = op.choseHighReward(lastIdx);
previousChoseHighSalience = op.choseHighSal(lastIdx);

end

function stats = computeOnlineStats(p)

op = p.status.onlinePlot;

trial = op.trial;
trialType = op.trialType;
nStim = op.nStim;
mappingValid = op.mappingValid;
choseHighSal = op.choseHighSal;
choseHighReward = op.choseHighReward;
rtMs = op.rtMs;
previousRewardMs = op.previousRewardMs;
previousTrialType = op.previousTrialType;
previousChoseHighReward = op.previousChoseHighReward;
previousChoseHighSalience = op.previousChoseHighSalience;
switchedTarget = op.switchedTarget;

isChoice = nStim == 2 & mappingValid == 1;
isConflict = isChoice & trialType == 2;
isCongruent = isChoice & trialType == 1;

conflictHighSal = isConflict & isfinite(choseHighSal);
conflictHighReward = isConflict & isfinite(choseHighReward);
congruentHighSal = isCongruent & isfinite(choseHighSal);
congruentHighReward = isCongruent & isfinite(choseHighReward);

stats.pHighSalConflict = safeMean(choseHighSal(conflictHighSal));
stats.pHighRewardConflict = safeMean(choseHighReward(conflictHighReward));
stats.nConflictHighSal = sum(conflictHighSal);
stats.nConflictHighReward = sum(conflictHighReward);

stats.pHighSalCongruent = safeMean(choseHighSal(congruentHighSal));
stats.pHighRewardCongruent = safeMean(choseHighReward(congruentHighReward));
stats.nCongruentHighSal = sum(congruentHighSal);
stats.nCongruentHighReward = sum(congruentHighReward);

% In congruent trials high reward and high salience identify the same
% target. Plot one favored probability and its true complement.
stats.pCongruentFavored = stats.pHighRewardCongruent;
if isfinite(stats.pCongruentFavored)
    stats.pCongruentUnfavored = 1 - stats.pCongruentFavored;
else
    stats.pCongruentUnfavored = NaN;
end

% These diagnostics expose mapping or bookkeeping problems immediately.
if isfinite(stats.pHighRewardConflict) && isfinite(stats.pHighSalConflict)
    stats.conflictProbabilitySum = ...
        stats.pHighRewardConflict + stats.pHighSalConflict;
else
    stats.conflictProbabilitySum = NaN;
end
if isfinite(stats.pHighRewardCongruent) && isfinite(stats.pHighSalCongruent)
    stats.congruentProbabilityDifference = ...
        stats.pHighRewardCongruent - stats.pHighSalCongruent;
else
    stats.congruentProbabilityDifference = NaN;
end
stats.nMappingErrors = sum(nStim == 2 & mappingValid == 0);

% Dubey-style RT split within conflict trials.
conflictHighRewardRT = isConflict & choseHighReward == 1 & isfinite(rtMs);
conflictHighSalienceRT = isConflict & choseHighSal == 1 & isfinite(rtMs);
congruentRT = isCongruent & isfinite(rtMs);
stats.medianRTConflictHighReward = safeMedian(rtMs(conflictHighRewardRT));
stats.medianRTConflictHighSalience = safeMedian(rtMs(conflictHighSalienceRT));
stats.medianRTCongruent = safeMedian(rtMs(congruentRT));
stats.nConflictHighRewardRT = sum(conflictHighRewardRT);
stats.nConflictHighSalienceRT = sum(conflictHighSalienceRT);
stats.nCongruentRT = sum(congruentRT);

% Backward-compatible aggregate conflict RT fields.
stats.medianRTConflict = safeMedian(rtMs(isConflict & isfinite(rtMs)));
stats.nConflictRT = sum(isConflict & isfinite(rtMs));

validChoice = isChoice & isfinite(choseHighSal);
choiceOrdinal = nan(size(trial));
choiceOrdinal(validChoice) = 1:sum(validChoice);
[stats.xOverall, stats.yOverall] = cumulativeSeries( ...
    choiceOrdinal(validChoice), choseHighSal(validChoice));
[stats.xConflict, stats.yConflict] = cumulativeSeries( ...
    choiceOrdinal(conflictHighSal), choseHighSal(conflictHighSal));
[stats.xCongruent, stats.yCongruent] = cumulativeSeries( ...
    choiceOrdinal(congruentHighSal), choseHighSal(congruentHighSal));

% Classify the previous successful choice:
%   1 = congruent
%   2 = conflict choice of high reward (Rich-Dim)
%   3 = conflict choice of high salience (Poor-Bright)
previousClass = nan(size(trial));
previousClass(previousTrialType == 1) = 1;
previousClass(previousTrialType == 2 & previousChoseHighReward == 1) = 2;
previousClass(previousTrialType == 2 & previousChoseHighSalience == 1) = 3;

validExploration = isChoice & ...
    isfinite(previousRewardMs) & isfinite(switchedTarget) & ...
    isfinite(previousClass);
stats.explorationX = previousRewardMs(validExploration);
stats.explorationY = switchedTarget(validExploration);
stats.nExploration = sum(validExploration);
stats.pSwitchOverall = safeMean(stats.explorationY);

prevCongruent = validExploration & previousClass == 1;
prevConflictHR = validExploration & previousClass == 2;
prevConflictHS = validExploration & previousClass == 3;

[stats.exploreRawPrevCongruentX, stats.exploreRawPrevCongruentY] = ...
    rawExplorationData(previousRewardMs, switchedTarget, prevCongruent);
[stats.exploreRawPrevConflictHRX, stats.exploreRawPrevConflictHRY] = ...
    rawExplorationData(previousRewardMs, switchedTarget, prevConflictHR);
[stats.exploreRawPrevConflictHSX, stats.exploreRawPrevConflictHSY] = ...
    rawExplorationData(previousRewardMs, switchedTarget, prevConflictHS);

[stats.exploreBinPrevCongruentX, stats.exploreBinPrevCongruentY] = ...
    binExplorationData(previousRewardMs(prevCongruent), ...
    switchedTarget(prevCongruent));
[stats.exploreBinPrevConflictHRX, stats.exploreBinPrevConflictHRY] = ...
    binExplorationData(previousRewardMs(prevConflictHR), ...
    switchedTarget(prevConflictHR));
[stats.exploreBinPrevConflictHSX, stats.exploreBinPrevConflictHSY] = ...
    binExplorationData(previousRewardMs(prevConflictHS), ...
    switchedTarget(prevConflictHS));

stats.pSwitchPrevCongruent = safeMean(switchedTarget(prevCongruent));
stats.pSwitchPrevConflictHR = safeMean(switchedTarget(prevConflictHR));
stats.pSwitchPrevConflictHS = safeMean(switchedTarget(prevConflictHS));
stats.nSwitchPrevCongruent = sum(prevCongruent);
stats.nSwitchPrevConflictHR = sum(prevConflictHR);
stats.nSwitchPrevConflictHS = sum(prevConflictHS);

% Nine previous-choice-category -> current-choice-category transitions.
% Current classes use the same codes as previous classes:
%   1=congruent, 2=conflict-high-reward, 3=conflict-high-salience.
currentClass = nan(size(trial));
currentClass(isCongruent) = 1;
currentClass(isConflict & choseHighReward == 1) = 2;
currentClass(isConflict & choseHighSal == 1) = 3;

transitionMasks = cell(1, 9);
iTransition = 0;
for previousCode = 1:3
    for currentCode = 1:3
        iTransition = iTransition + 1;
        transitionMasks{iTransition} = validExploration & ...
            previousClass == previousCode & currentClass == currentCode;
    end
end
stats.pSwitchTransition = nan(1, 9);
stats.nSwitchTransition = zeros(1, 9);
for iTransition = 1:9
    thisMask = transitionMasks{iTransition};
    stats.pSwitchTransition(iTransition) = ...
        safeMean(switchedTarget(thisMask));
    stats.nSwitchTransition(iTransition) = sum(thisMask);
end

end

function [x, y] = rawExplorationData(reward, switched, mask)
x = reward(mask);
y = switched(mask);
if isempty(x)
    x = NaN;
    y = NaN;
end
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

function p = refreshBehavioralPlots(p, stats, goodTrialIdx)

setIfHandle(p.draw.onlinePlotObj, 'conflictChoiceHighReward', ...
    'YData', stats.pHighRewardConflict);
setIfHandle(p.draw.onlinePlotObj, 'conflictChoiceHighSalience', ...
    'YData', stats.pHighSalConflict);
setIfHandle(p.draw.onlinePlotObj, 'congruentChoiceFavored', ...
    'YData', stats.pCongruentFavored);
setIfHandle(p.draw.onlinePlotObj, 'congruentChoiceUnfavored', ...
    'YData', stats.pCongruentUnfavored);

setIfHandle(p.draw.onlinePlotObj, 'medianRTConflictHighReward', ...
    'YData', stats.medianRTConflictHighReward);
setIfHandle(p.draw.onlinePlotObj, 'medianRTConflictHighSalience', ...
    'YData', stats.medianRTConflictHighSalience);
setIfHandle(p.draw.onlinePlotObj, 'medianRTCongruent', ...
    'YData', stats.medianRTCongruent);

setXYIfHandle(p.draw.onlinePlotObj, 'choiceOverall', ...
    stats.xOverall, stats.yOverall);
setXYIfHandle(p.draw.onlinePlotObj, 'choiceConflict', ...
    stats.xConflict, stats.yConflict);
setXYIfHandle(p.draw.onlinePlotObj, 'choiceCongruent', ...
    stats.xCongruent, stats.yCongruent);

setXYIfHandle(p.draw.onlinePlotObj, 'exploreRawPrevCongruent', ...
    stats.exploreRawPrevCongruentX, stats.exploreRawPrevCongruentY);
setXYIfHandle(p.draw.onlinePlotObj, 'exploreRawPrevConflictHR', ...
    stats.exploreRawPrevConflictHRX, stats.exploreRawPrevConflictHRY);
setXYIfHandle(p.draw.onlinePlotObj, 'exploreRawPrevConflictHS', ...
    stats.exploreRawPrevConflictHSX, stats.exploreRawPrevConflictHSY);
setXYIfHandle(p.draw.onlinePlotObj, 'exploreBinPrevCongruent', ...
    stats.exploreBinPrevCongruentX, stats.exploreBinPrevCongruentY);
setXYIfHandle(p.draw.onlinePlotObj, 'exploreBinPrevConflictHR', ...
    stats.exploreBinPrevConflictHRX, stats.exploreBinPrevConflictHRY);
setXYIfHandle(p.draw.onlinePlotObj, 'exploreBinPrevConflictHS', ...
    stats.exploreBinPrevConflictHSX, stats.exploreBinPrevConflictHSY);

if isfield(p.draw.onlinePlotObj, 'explorationTransitionBars')
    bars = p.draw.onlinePlotObj.explorationTransitionBars;
    for iTransition = 1:min(numel(bars), 9)
        if ishandle(bars(iTransition))
            set(bars(iTransition), 'YData', ...
                stats.pSwitchTransition(iTransition));
        end
    end
end

xMax = max(10, goodTrialIdx + 1);
updateTimeSeriesAxis(p, 'rewardDiff', 'rewardDiff', 'rewardZero', xMax, 50);
updateTimeSeriesAxis(p, 'luminanceDiff', 'luminanceDiff', ...
    'luminanceZero', xMax, 1);
updateTimeSeriesAxis(p, 'hueContrastDiff', 'hueContrastDiff', ...
    'hueContrastZero', xMax, 20);

if isfield(p.draw.onlinePlotAxes, 'choiceEvolution') && ...
        ishandle(p.draw.onlinePlotAxes.choiceEvolution)
    choiceX = stats.xOverall;
    choiceX = choiceX(isfinite(choiceX));
    if isempty(choiceX)
        choiceXMax = 10;
    else
        choiceXMax = max(10, max(choiceX) + 1);
    end
    set(p.draw.onlinePlotAxes.choiceEvolution, ...
        'XLim', [0 choiceXMax], 'YLim', [0 1]);
    setXYIfHandle(p.draw.onlinePlotObj, 'choiceChance', ...
        [0 choiceXMax], [0.5 0.5]);
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
%GETCURRENTLUMINANCEDIFF Return physical T1-T2 luminance in cd/m^2.
%
% The calibrated value is preferred. The nominal task coordinate is used
% only as a backwards-compatible fallback when no physical lookup exists.

luminanceDiff = getNumericField( ...
    p.trVars, 'MeasuredLuminanceDifferenceT1MinusT2CdM2', NaN);

if ~isfinite(luminanceDiff)
    measuredT1 = getNumericField(p.trVars, 'MeasuredLuminanceT1CdM2', NaN);
    measuredT2 = getNumericField(p.trVars, 'MeasuredLuminanceT2CdM2', NaN);
    if isfinite(measuredT1) && isfinite(measuredT2)
        luminanceDiff = measuredT1 - measuredT2;
    end
end

if ~isfinite(luminanceDiff)
    luminanceDiff = getNumericField( ...
        p.trVars, 'LuminanceDifferenceT1MinusT2', NaN);
end

end

function hueContrastDiff = getCurrentHueContrastDiff(p)
%GETCURRENTHUECONTRASTDIFF Signed T1-T2 contrast from current background.

hueContrastDiff = getNumericField( ...
    p.trVars, 'HueContrastDifferenceT1MinusT2', NaN);
if ~isfinite(hueContrastDiff)
    contrastT1 = getNumericField(p.trVars, 'HueContrastT1', NaN);
    contrastT2 = getNumericField(p.trVars, 'HueContrastT2', NaN);
    if isfinite(contrastT1) && isfinite(contrastT2)
        hueContrastDiff = contrastT1 - contrastT2;
    end
end

end

function [lumT1, lumT2] = getCurrentNominalLuminanceValues(p)
%GETCURRENTNOMINALLUMINANCEVALUES Return task-level sampling coordinates.

lumT1 = getNumericField(p.trVars, 'NominalLuminanceT1', NaN);
lumT2 = getNumericField(p.trVars, 'NominalLuminanceT2', NaN);

if ~isfinite(lumT1)
    lumT1 = getNumericField(p.trVars, 'ActualLuminanceT1', NaN);
end
if ~isfinite(lumT2)
    lumT2 = getNumericField(p.trVars, 'ActualLuminanceT2', NaN);
end

end

function [lumT1, lumT2] = getCurrentMeasuredLuminanceValues(p)
%GETCURRENTMEASUREDLUMINANCEVALUES Return i1Pro 3 values in cd/m^2.

lumT1 = getNumericField(p.trVars, 'MeasuredLuminanceT1CdM2', NaN);
lumT2 = getNumericField(p.trVars, 'MeasuredLuminanceT2CdM2', NaN);

end

function [minimumCdM2, maximumCdM2, label] = getLuminanceCalibrationSummary(p)
%GETLUMINANCECALIBRATIONSUMMARY Return the active physical calibration.

minimumCdM2 = NaN;
maximumCdM2 = NaN;
label = 'not loaded';

if isfield(p, 'draw') && isfield(p.draw, 'clut') && ...
        isfield(p.draw.clut, 'redLumCalibration') && ...
        isstruct(p.draw.clut.redLumCalibration)
    calibration = p.draw.clut.redLumCalibration;
    minimumCdM2 = getNumericField(calibration, 'minimumCdM2', NaN);
    maximumCdM2 = getNumericField(calibration, 'maximumCdM2', NaN);
    if isfield(calibration, 'label') && ~isempty(calibration.label)
        label = char(calibration.label);
    end
end

end

function backgroundCdM2 = getBackgroundMeasuredLuminance(p)
%GETBACKGROUNDMEASUREDLUMINANCE Return measured gray-background luminance.

backgroundCdM2 = getNumericField( ...
    p.trVars, 'BackgroundMeasuredLuminanceCdM2', NaN);

if ~isfinite(backgroundCdM2) && isfield(p, 'draw') && ...
        isfield(p.draw, 'clut')
    backgroundCdM2 = getNumericField( ...
        p.draw.clut, 'srsBackgroundMeasuredCdM2', NaN);
end

if ~isfinite(backgroundCdM2)
    backgroundCdM2 = getNumericField( ...
        p.trVars, 'srsLuminanceBackgroundMeasuredCdM2', NaN);
end

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

function mappingValid = validateEvidenceMapping( ...
        trialType, highRewardTargetID, highSalienceTargetID)
%VALIDATEEVIDENCEMAPPING Check the defining relation of each trial type.

mappingValid = false;
if ~any(highRewardTargetID == [1 2]) || ...
        ~any(highSalienceTargetID == [1 2])
    return;
end

if trialType == 1
    mappingValid = highRewardTargetID == highSalienceTargetID;
elseif trialType == 2
    mappingValid = highRewardTargetID ~= highSalienceTargetID;
end

end

function category = classifyChoiceCategory( ...
        trialType, choseHighReward, choseHighSalience)
%CLASSIFYCHOICECATEGORY Encode the preceding successful choice.
%   1 = congruent
%   2 = conflict, chose high reward
%   3 = conflict, chose high salience

category = NaN;
if trialType == 1
    category = 1;
elseif trialType == 2 && choseHighReward == 1
    category = 2;
elseif trialType == 2 && choseHighSalience == 1
    category = 3;
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

function statusLines = makeOnlineStatusLines(p, attemptTrialIdx, ...
        goodTrialIdx, isGoodTrial, rewardDiff, luminanceDiff, ...
        hueContrastDiff, stats, currentTransition)

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

[nominalT1, nominalT2] = getCurrentNominalLuminanceValues(p);
[measuredT1, measuredT2] = getCurrentMeasuredLuminanceValues(p);
measuredDiff = getNumericField(p.trVars, ...
    'MeasuredLuminanceDifferenceT1MinusT2CdM2', luminanceDiff);
nominalDiff = getNumericField(p.trVars, ...
    'NominalLuminanceDifferenceT1MinusT2', NaN);
if ~isfinite(nominalDiff) && isfinite(nominalT1) && isfinite(nominalT2)
    nominalDiff = nominalT1 - nominalT2;
end

dklT1 = getNumericField(p.trVars, 'ActualDklRedLuminanceT1', NaN);
dklT2 = getNumericField(p.trVars, 'ActualDklRedLuminanceT2', NaN);
dklDiff = getNumericField(p.trVars, ...
    'DklRedLuminanceDifferenceT1MinusT2', NaN);

bgDkl = getNumericField(p.trVars, 'BackgroundDklLuminance', NaN);
if ~isfinite(bgDkl) && isfield(p.draw, 'clut')
    bgDkl = getNumericField(p.draw.clut, 'srsBackgroundDklLum', NaN);
end
if ~isfinite(bgDkl)
    bgDkl = getNumericField(p.trVars, ...
        'srsLuminanceBackgroundDklLum', NaN);
end
bgCdM2 = getBackgroundMeasuredLuminance(p);
[calibrationMin, calibrationMax, calibrationLabel] = ...
    getLuminanceCalibrationSummary(p);

instructionOrder = instructionOrderString(p.status);
activeSchedule = activeScheduleString(p.status);

hueModeString = 'missing';
if isfield(p.trVars, 'hueSamplingMode') && ~isempty(p.trVars.hueSamplingMode)
    hueModeString = char(p.trVars.hueSamplingMode);
end
highHueDeg = getNumericField(p.trVars, 'HighSalienceHueDeg', NaN);
lowHueDeg = getNumericField(p.trVars, 'LowSalienceHueDeg', NaN);
hueContrastMagnitude = getNumericField( ...
    p.trVars, 'HueContrastDifferenceMagnitude', NaN);

previousReward = currentTransition.previousRewardMs;
chosenReward = currentTransition.chosenRewardMs;
previousChoiceClass = currentTransition.previousChoiceClass;
currentTransitionTrialType = currentTransition.currentTrialType;
currentChoiceClass = currentTransition.currentChoiceClass;
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
        previousChoiceClass = classifyChoiceCategory( ...
            p.status.onlinePlot.previousTrialType(lastIdx), ...
            p.status.onlinePlot.previousChoseHighReward(lastIdx), ...
            p.status.onlinePlot.previousChoseHighSalience(lastIdx));
        currentTransitionTrialType = ...
            p.status.onlinePlot.trialType(lastIdx);
        currentChoiceClass = classifyChoiceCategory( ...
            p.status.onlinePlot.trialType(lastIdx), ...
            p.status.onlinePlot.choseHighReward(lastIdx), ...
            p.status.onlinePlot.choseHighSal(lastIdx));
    end
end

statusLines = { ...
    htmlTitle('TASK STATUS', '#1f4e79'); ...
    htmlLine('Current trial good', yesNoString(isGoodTrial), '#000000'); ...
    htmlLine('Good trials total', valueToString(getNumericField(p.status, 'iGoodTrial', NaN)), '#000000'); ...
    htmlLine('Current attempt', valueToString(attemptTrialIdx), '#000000'); ...
    htmlLine('Good-trial index', valueToString(goodTrialIdx), '#000000'); ...
    ' '; ...
    htmlSection('BLOCK', '#2f75b5'); ...
    htmlLine('Block type', blockType, '#000000'); ...
    htmlLine('Block number', fractionString(currentBlock, totalBlocks), '#000000'); ...
    htmlLine('Remaining blocks', valueToString(remainingBlock), '#000000'); ...
    htmlLine('Attempts this block', valueToString(getNumericField(p.status, 'blockAttemptCount', NaN)), '#000000'); ...
    ' '; ...
    htmlSection('BLOCK SCHEDULE', '#548235'); ...
    htmlLine('Instruction schedule', instructionOrder, '#7f6000'); ...
    htmlLine('Active schedule', activeSchedule, '#7f6000'); ...
    htmlLine('Active phase remaining', valueToString( ...
        getNumericField(p.status, 'RemainingActivePhase', NaN)), '#7f6000'); ...
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
    htmlLine('Schedule phase', valueToString(getNumericField(p.trVars, 'schedulePhase', NaN)), '#000000'); ...
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
    htmlSection('MEASURED LUMINANCE', '#8064a2'); ...
    htmlLine('Background', sprintf('%s cd/m^2  (DKL %s)', ...
        formatNumber(bgCdM2, '%.1f'), formatNumber(bgDkl, '%.3f')), '#000000'); ...
    htmlLine('T1 / T2 measured', sprintf('%s / %s cd/m^2', ...
        formatNumber(measuredT1, '%.3f'), ...
        formatNumber(measuredT2, '%.3f')), '#000000'); ...
    htmlLine('Measured diff T1-T2', formatNumber(measuredDiff, '%.3f cd/m^2'), '#000000'); ...
    htmlLine('Calibration range', calibrationRangeString( ...
        calibrationMin, calibrationMax), '#000000'); ...
    htmlLine('Calibration label', calibrationLabel, '#000000'); ...
    htmlLine('T1 / T2 colorIdx', sprintf('%s / %s', ...
        valueToString(getNumericField(p.trVars, 'T1_colorIdx', NaN)), ...
        valueToString(getNumericField(p.trVars, 'T2_colorIdx', NaN))), '#000000'); ...
    ' '; ...
    htmlSection('LUMINANCE MAPPING', '#8064a2'); ...
    htmlLine('T1 / T2 nominal', sprintf('%s / %s', ...
        formatNumber(nominalT1, '%.3f'), formatNumber(nominalT2, '%.3f')), '#000000'); ...
    htmlLine('Nominal diff T1-T2', formatNumber(nominalDiff, '%.3f'), '#000000'); ...
    htmlLine('T1 / T2 DKL lum', sprintf('%s / %s', ...
        formatNumber(dklT1, '%.6f'), formatNumber(dklT2, '%.6f')), '#000000'); ...
    htmlLine('DKL lum diff T1-T2', formatNumber(dklDiff, '%.6f'), '#000000'); ...
    ' '; ...
    htmlSection('HUE CONTRAST', '#7B1FA2'); ...
    htmlLine('Hue sampling mode', hueModeString, '#000000'); ...
    htmlLine('Background hue', getFieldString(p.trVars, 'BackgroundHue', '%.1f deg'), '#000000'); ...
    htmlLine('High / low hue', sprintf('%s / %s', ...
        formatNumber(highHueDeg, '%.1f deg'), ...
        formatNumber(lowHueDeg, '%.1f deg')), '#000000'); ...
    htmlLine('T1 / T2 hue', sprintf('%s / %s', ...
        getFieldString(p.trVars, 'ActualHueT1', '%.1f deg'), ...
        getFieldString(p.trVars, 'ActualHueT2', '%.1f deg')), '#000000'); ...
    htmlLine('T1 / T2 hue distance', sprintf('%s / %s', ...
        getFieldString(p.trVars, 'HueContrastT1', '%.1f deg'), ...
        getFieldString(p.trVars, 'HueContrastT2', '%.1f deg')), '#000000'); ...
    htmlLine('Contrast diff T1-T2', ...
        formatNumber(hueContrastDiff, '%.1f deg'), '#000000'); ...
    htmlLine('|Contrast difference|', ...
        formatNumber(hueContrastMagnitude, '%.1f deg'), '#000000'); ...
    ' '; ...
    htmlSection('EXPLORATION', '#7030a0'); ...
    htmlLine('Previous choice category', ...
        choiceCategoryString(previousChoiceClass), '#000000'); ...
    htmlLine('Current transition trial', ...
        trialTypeString(currentTransitionTrialType), '#000000'); ...
    htmlLine('Current choice category', ...
        choiceCategoryString(currentChoiceClass), '#000000'); ...
    htmlLine('Previous choice reward', ...
        formatNumber(previousReward, '%.0f ms'), '#000000'); ...
    htmlLine('Changed T1/T2 target', switchString(switchValue), '#000000'); ...
    htmlLine('P switch overall', ...
        probabilityString(stats.pSwitchOverall, stats.nExploration), '#000000'); ...
    htmlLine('P switch | prev congruent', ...
        probabilityString(stats.pSwitchPrevCongruent, ...
        stats.nSwitchPrevCongruent), '#555555'); ...
    htmlLine('P switch | prev conflict-HR', ...
        probabilityString(stats.pSwitchPrevConflictHR, ...
        stats.nSwitchPrevConflictHR), '#0072bd'); ...
    htmlLine('P switch | prev conflict-HS', ...
        probabilityString(stats.pSwitchPrevConflictHS, ...
        stats.nSwitchPrevConflictHS), '#d95319'); ...
    ' '; ...
    htmlSection('ONLINE SUMMARY', '#44546a'); ...
    htmlLine('Conflict P(high reward)', probabilityString( ...
        stats.pHighRewardConflict, stats.nConflictHighReward), '#0072bd'); ...
    htmlLine('Conflict P(high salience)', probabilityString( ...
        stats.pHighSalConflict, stats.nConflictHighSal), '#d95319'); ...
    htmlLine('Conflict probability sum', ...
        formatNumber(stats.conflictProbabilitySum, '%.3f (expected 1)'), '#000000'); ...
    htmlLine('Congruent P(favored HR=HS)', probabilityString( ...
        stats.pCongruentFavored, stats.nCongruentHighReward), '#008000'); ...
    htmlLine('Congruent P(unfavored)', probabilityString( ...
        stats.pCongruentUnfavored, stats.nCongruentHighReward), '#666666'); ...
    htmlLine('Congruent HR-HS difference', ...
        formatNumber(stats.congruentProbabilityDifference, ...
        '%.3f (expected 0)'), '#000000'); ...
    htmlLine('Mapping errors excluded', ...
        valueToString(stats.nMappingErrors), '#c00000'); ...
    htmlLine('Median RT conflict-HR', medianString( ...
        stats.medianRTConflictHighReward, ...
        stats.nConflictHighRewardRT), '#0072bd'); ...
    htmlLine('Median RT conflict-HS', medianString( ...
        stats.medianRTConflictHighSalience, ...
        stats.nConflictHighSalienceRT), '#d95319'); ...
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

function txt = instructionOrderString(status)
%INSTRUCTIONORDERSTRING Describe the instruction schedule.

if getNumericField(status, 'TotalInstructionTrialsPerBlock', 0) > 0
    txt = 'mixed T1-only / T2-only';
else
    txt = 'none';
end

end

function txt = activeScheduleString(status)
%ACTIVESCHEDULESTRING Describe the earliest unfinished schedule phase.

phase = getNumericField(status, 'ActiveSchedulePhase', NaN);
if phase == 1
    txt = 'Phase 1: mixed single-target';
elseif phase == 2
    txt = 'Phase 2: two-target choice';
elseif phase == 0
    txt = 'complete / not started';
else
    txt = 'missing';
end

end

function txt = choiceCategoryString(category)
if category == 1
    txt = 'congruent';
elseif category == 2
    txt = 'conflict, chose high reward';
elseif category == 3
    txt = 'conflict, chose high salience';
else
    txt = 'none';
end
end

function txt = trialTypeString(trialType)
if trialType == 1
    txt = 'congruent';
elseif trialType == 2
    txt = 'conflict';
else
    txt = 'none';
end
end

function txt = calibrationRangeString(minimumCdM2, maximumCdM2)
%CALIBRATIONRANGESTRING Format physical i1Pro 3 range.

if isfinite(minimumCdM2) && isfinite(maximumCdM2)
    txt = sprintf('%.3f - %.3f cd/m^2', minimumCdM2, maximumCdM2);
else
    txt = 'not loaded';
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
