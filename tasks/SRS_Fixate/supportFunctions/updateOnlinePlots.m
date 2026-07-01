function p = updateOnlinePlots(p)

%% Safety checks

if ~isfield(p.draw, 'onlinePlotWindow')
    return;
end

if ~ishandle(p.draw.onlinePlotWindow)
    return;
end

if ~isfield(p.draw, 'onlinePlotObj')
    return;
end

if isfield(p.status, 'iTrial')
    trialIdx = p.status.iTrial;
else
    trialIdx = NaN;
end

p = initializeOnlinePlotStorage(p);

%% ------------------------------------------------------------
% 1. Reward difference plot
% ------------------------------------------------------------
% Convention:
% T1 = right target
% T2 = left target
%
% Therefore:
% reward_T1 = rewardDurationRight
% reward_T2 = rewardDurationLeft
%
% Reward difference:
% rewardDiff = T1 - T2

rewardDiff = NaN;

if isfield(p.trVars, 'rewardDurationRight') && isfield(p.trVars, 'rewardDurationLeft')

    reward_T1 = double(p.trVars.rewardDurationRight);
    reward_T2 = double(p.trVars.rewardDurationLeft);

    rewardDiff = reward_T1 - reward_T2;

    if isfield(p.draw.onlinePlotObj, 'rewardDiff') && ...
            ishandle(p.draw.onlinePlotObj.rewardDiff)

        appendOrReplacePoint( ...
            p.draw.onlinePlotObj.rewardDiff, ...
            trialIdx, ...
            rewardDiff);
    end
end

%% ------------------------------------------------------------
% 2. Store trial data for summary plots
% ------------------------------------------------------------

trialType = getCurrentTrialType(p);          % 1 = congruent, 2 = conflict
[hasChoice, chosenSide] = getCurrentChoice(p);
highSalienceSide = getHighSalienceSide(p);
[hasValidRT, rtMs] = getCurrentRT(p);

% Did the monkey choose the high salience target?
if hasChoice && isfinite(highSalienceSide)
    choseHighSal = double(chosenSide == highSalienceSide);
else
    choseHighSal = NaN;
end

% If there is no valid RT, store NaN
if ~hasValidRT
    rtMs = NaN;
end

p = appendOrReplaceTrialSummary( ...
    p, ...
    trialIdx, ...
    trialType, ...
    choseHighSal, ...
    rtMs);

%% ------------------------------------------------------------
% 3. Compute summary values
% ------------------------------------------------------------

onlineStats = computeOnlineStats(p);

%% ------------------------------------------------------------
% 4. Update P(High Salience), Conflict vs Congruent
% ------------------------------------------------------------

if isfield(p.draw.onlinePlotObj, 'pHighSalConflict') && ...
        ishandle(p.draw.onlinePlotObj.pHighSalConflict)

    set(p.draw.onlinePlotObj.pHighSalConflict, ...
        'YData', onlineStats.pHighSalConflict);
end

if isfield(p.draw.onlinePlotObj, 'pHighSalCongruent') && ...
        ishandle(p.draw.onlinePlotObj.pHighSalCongruent)

    set(p.draw.onlinePlotObj.pHighSalCongruent, ...
        'YData', onlineStats.pHighSalCongruent);
end

%% ------------------------------------------------------------
% 5. Update Median RT, Conflict vs Congruent
% ------------------------------------------------------------

if isfield(p.draw.onlinePlotObj, 'medianRTConflict') && ...
        ishandle(p.draw.onlinePlotObj.medianRTConflict)

    set(p.draw.onlinePlotObj.medianRTConflict, ...
        'YData', onlineStats.medianRTConflict);
end

if isfield(p.draw.onlinePlotObj, 'medianRTCongruent') && ...
        ishandle(p.draw.onlinePlotObj.medianRTCongruent)

    set(p.draw.onlinePlotObj.medianRTCongruent, ...
        'YData', onlineStats.medianRTCongruent);
end

% Dynamic RT axis
if isfield(p.draw.onlinePlotAxes, 'medianRT') && ...
        ishandle(p.draw.onlinePlotAxes.medianRT)

    rtAll = p.status.onlinePlot.rtMs(isfinite(p.status.onlinePlot.rtMs));

    if isempty(rtAll)
        rtMax = 500;
    else
        rtMax = max(500, 1.15 * max(rtAll));
    end

    set(p.draw.onlinePlotAxes.medianRT, ...
        'YLim', [0 rtMax]);
end

%% ------------------------------------------------------------
% 6. Update choice evolution over session
% ------------------------------------------------------------

if isfield(p.draw.onlinePlotObj, 'choiceOverall') && ...
        ishandle(p.draw.onlinePlotObj.choiceOverall)

    set(p.draw.onlinePlotObj.choiceOverall, ...
        'XData', onlineStats.xOverall, ...
        'YData', onlineStats.yOverall);
end

if isfield(p.draw.onlinePlotObj, 'choiceConflict') && ...
        ishandle(p.draw.onlinePlotObj.choiceConflict)

    set(p.draw.onlinePlotObj.choiceConflict, ...
        'XData', onlineStats.xConflict, ...
        'YData', onlineStats.yConflict);
end

if isfield(p.draw.onlinePlotObj, 'choiceCongruent') && ...
        ishandle(p.draw.onlinePlotObj.choiceCongruent)

    set(p.draw.onlinePlotObj.choiceCongruent, ...
        'XData', onlineStats.xCongruent, ...
        'YData', onlineStats.yCongruent);
end

%% ------------------------------------------------------------
% 7. Update axes limits
% ------------------------------------------------------------

xMax = max(10, trialIdx + 1);

% Reward axis
if isfield(p.draw.onlinePlotAxes, 'rewardDiff') && ...
        ishandle(p.draw.onlinePlotAxes.rewardDiff)

    set(p.draw.onlinePlotAxes.rewardDiff, 'XLim', [0 xMax]);

    if isfield(p.draw.onlinePlotObj, 'rewardZero') && ...
            ishandle(p.draw.onlinePlotObj.rewardZero)

        set(p.draw.onlinePlotObj.rewardZero, ...
            'XData', [0 xMax], ...
            'YData', [0 0]);
    end

    rewardY = get(p.draw.onlinePlotObj.rewardDiff, 'YData');
    rewardY = rewardY(isfinite(rewardY));

    if isempty(rewardY)
        yAbsMax = 200;
    else
        yAbsMax = max(50, 1.2 * max(abs(rewardY)));
    end

    set(p.draw.onlinePlotAxes.rewardDiff, ...
        'YLim', [-yAbsMax yAbsMax]);
end

% Choice evolution axis
if isfield(p.draw.onlinePlotAxes, 'choiceEvolution') && ...
        ishandle(p.draw.onlinePlotAxes.choiceEvolution)

    set(p.draw.onlinePlotAxes.choiceEvolution, ...
        'XLim', [0 xMax], ...
        'YLim', [0 1]);

    if isfield(p.draw.onlinePlotObj, 'choiceChance') && ...
            ishandle(p.draw.onlinePlotObj.choiceChance)

        set(p.draw.onlinePlotObj.choiceChance, ...
            'XData', [0 xMax], ...
            'YData', [0.5 0.5]);
    end
end

%% ------------------------------------------------------------
% 8. Update status text display
% ------------------------------------------------------------

if isfield(p.draw.onlinePlotObj, 'statusText') && ...
        ishandle(p.draw.onlinePlotObj.statusText)

    statusLines = makeOnlineStatusLines(p, trialIdx, rewardDiff, onlineStats);

    set(p.draw.onlinePlotObj.statusText, ...
        'String', statusLines, ...
        'Value', 1);
end

drawnow;

end

%% ============================================================
% Main helper functions
% ============================================================

function p = initializeOnlinePlotStorage(p)

if ~isfield(p.status, 'onlinePlot') || isempty(p.status.onlinePlot)
    p.status.onlinePlot.trial        = [];
    p.status.onlinePlot.trialType    = [];
    p.status.onlinePlot.choseHighSal = [];
    p.status.onlinePlot.rtMs         = [];
    return;
end

neededFields = {'trial', 'trialType', 'choseHighSal', 'rtMs'};

for iField = 1:numel(neededFields)
    thisField = neededFields{iField};

    if ~isfield(p.status.onlinePlot, thisField)
        p.status.onlinePlot.(thisField) = [];
    end
end

end

function p = appendOrReplaceTrialSummary(p, trialIdx, trialType, choseHighSal, rtMs)

% If updateOnlinePlots gets called twice for the same trial, replace the
% last entry instead of duplicating the trial.

if isempty(p.status.onlinePlot.trial) || p.status.onlinePlot.trial(end) ~= trialIdx

    p.status.onlinePlot.trial(end + 1)        = trialIdx;
    p.status.onlinePlot.trialType(end + 1)    = trialType;
    p.status.onlinePlot.choseHighSal(end + 1) = choseHighSal;
    p.status.onlinePlot.rtMs(end + 1)         = rtMs;

else

    p.status.onlinePlot.trialType(end)    = trialType;
    p.status.onlinePlot.choseHighSal(end) = choseHighSal;
    p.status.onlinePlot.rtMs(end)         = rtMs;
end

end

function onlineStats = computeOnlineStats(p)

trial        = p.status.onlinePlot.trial;
trialType    = p.status.onlinePlot.trialType;
choseHighSal = p.status.onlinePlot.choseHighSal;
rtMs         = p.status.onlinePlot.rtMs;

validChoice = isfinite(choseHighSal);
validRT     = isfinite(rtMs);

isConflictChoice  = trialType == 2 & validChoice;
isCongruentChoice = trialType == 1 & validChoice;

isConflictRT  = trialType == 2 & validRT;
isCongruentRT = trialType == 1 & validRT;

% P(High Salience)
onlineStats.pHighSalConflict  = safeMean(choseHighSal(isConflictChoice));
onlineStats.pHighSalCongruent = safeMean(choseHighSal(isCongruentChoice));

onlineStats.nConflictChoice   = sum(isConflictChoice);
onlineStats.nCongruentChoice  = sum(isCongruentChoice);

% Median RT
onlineStats.medianRTConflict  = safeMedian(rtMs(isConflictRT));
onlineStats.medianRTCongruent = safeMedian(rtMs(isCongruentRT));

onlineStats.nConflictRT       = sum(isConflictRT);
onlineStats.nCongruentRT      = sum(isCongruentRT);

% Choice evolution, overall
if any(validChoice)
    xOverall = trial(validChoice);
    yOverall = cumsum(choseHighSal(validChoice)) ./ (1:sum(validChoice));
else
    xOverall = NaN;
    yOverall = NaN;
end

% Choice evolution, conflict
if any(isConflictChoice)
    xConflict = trial(isConflictChoice);
    yConflict = cumsum(choseHighSal(isConflictChoice)) ./ (1:sum(isConflictChoice));
else
    xConflict = NaN;
    yConflict = NaN;
end

% Choice evolution, congruent
if any(isCongruentChoice)
    xCongruent = trial(isCongruentChoice);
    yCongruent = cumsum(choseHighSal(isCongruentChoice)) ./ (1:sum(isCongruentChoice));
else
    xCongruent = NaN;
    yCongruent = NaN;
end

onlineStats.xOverall   = xOverall;
onlineStats.yOverall   = yOverall;

onlineStats.xConflict  = xConflict;
onlineStats.yConflict  = yConflict;

onlineStats.xCongruent = xCongruent;
onlineStats.yCongruent = yCongruent;

end

function trialType = getCurrentTrialType(p)

trialType = NaN;

if isfield(p.status, 'ActualTrialType')

    value = p.status.ActualTrialType;

    if isnumeric(value) && isscalar(value)
        trialType = value;
        return;
    end

    valueString = lower(string(value));

    if contains(valueString, "conflict")
        trialType = 2;
    elseif contains(valueString, "congruent")
        trialType = 1;
    end
end

end

function [hasChoice, chosenSide] = getCurrentChoice(p)

hasChoice = false;
chosenSide = NaN;

if ~isfield(p.trData, 'chosenSide')
    return;
end

value = p.trData.chosenSide;

if isnumeric(value) && isscalar(value)
    chosenSide = value;
elseif ischar(value) || isstring(value)
    valueString = lower(string(value));

    if valueString == "right" || valueString == "r" || valueString == "t1"
        chosenSide = 1;
    elseif valueString == "left" || valueString == "l" || valueString == "t2"
        chosenSide = 2;
    end
end

hasChoice = any(chosenSide == [1 2]);

end

function highSalienceSide = getHighSalienceSide(p)

highSalienceSide = NaN;

if isfield(p.status, 'highSalienceSide')
    highSalienceSide = p.status.highSalienceSide;
elseif isfield(p.trVars, 'highSalienceSide')
    highSalienceSide = p.trVars.highSalienceSide;
elseif isfield(p.trVars, 'highSalSide')
    highSalienceSide = p.trVars.highSalSide;
elseif isfield(p.status, 'highSalSide')
    highSalienceSide = p.status.highSalSide;
end

if ischar(highSalienceSide) || isstring(highSalienceSide)
    valueString = lower(string(highSalienceSide));

    if valueString == "right" || valueString == "r" || valueString == "t1"
        highSalienceSide = 1;
    elseif valueString == "left" || valueString == "l" || valueString == "t2"
        highSalienceSide = 2;
    else
        highSalienceSide = NaN;
    end
end

end

function [hasValidRT, rtMs] = getCurrentRT(p)

hasValidRT = false;
rtMs = NaN;

if ~isfield(p.trData, 'timing')
    return;
end

if ~isfield(p.trData.timing, 'fixOff') || ...
        ~isfield(p.trData.timing, 'saccadeOnset')
    return;
end

fixOff = p.trData.timing.fixOff;
saccadeOnset = p.trData.timing.saccadeOnset;

hasValidRT = ...
    isnumeric(fixOff) && ...
    isnumeric(saccadeOnset) && ...
    isscalar(fixOff) && ...
    isscalar(saccadeOnset) && ...
    isfinite(fixOff) && ...
    isfinite(saccadeOnset) && ...
    fixOff > 0 && ...
    saccadeOnset > fixOff;

if hasValidRT
    rtMs = 1000 * (saccadeOnset - fixOff);
end

end

function appendOrReplacePoint(plotHandle, x, y)

oldX = get(plotHandle, 'XData');
oldY = get(plotHandle, 'YData');

% Remove initial NaN point
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

set(plotHandle, ...
    'XData', oldX, ...
    'YData', oldY);

end

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

%% ============================================================
% Status display helper functions
% ============================================================

function statusLines = makeOnlineStatusLines(p, trialIdx, rewardDiff, onlineStats)

%% Block type

if isfield(p.status, 'CurrentBlockType')
    if p.status.CurrentBlockType == 1
        blockType = 'T1 rich';
    elseif p.status.CurrentBlockType == 2
        blockType = 'T2 rich';
    else
        blockType = sprintf('Unknown (%s)', valueToString(p.status.CurrentBlockType));
    end
else
    blockType = 'missing';
end

%% Trial type

if isfield(p.status, 'ActualTrialType')
    if p.status.ActualTrialType == 1
        trialType = 'Congruent';
    elseif p.status.ActualTrialType == 2
        trialType = 'Conflict';
    else
        trialType = sprintf('Unknown (%s)', valueToString(p.status.ActualTrialType));
    end
else
    trialType = 'missing';
end

%% Choice

choiceString = 'missing';

if isfield(p.trData, 'chosenSide')
    if p.trData.chosenSide == 1
        choiceString = 'T1 / right';
    elseif p.trData.chosenSide == 2
        choiceString = 'T2 / left';
    else
        choiceString = sprintf('Unknown (%s)', valueToString(p.trData.chosenSide));
    end
end

%% Good trial

if isfield(p.status, 'iGoodTrial')
    goodTrialString = valueToString(p.status.iGoodTrial);
elseif isfield(p.trData, 'GoodTrial')
    goodTrialString = valueToString(p.trData.GoodTrial);
else
    goodTrialString = 'missing';
end

%% RT

rtString = 'missing';

[hasValidRT, rtMs] = getCurrentRT(p);

if hasValidRT
    rtString = sprintf('%.1f ms', rtMs);
end

%% Reward values

richRewardString = getFieldString(p.status, 'ActualRichReward');
poorRewardString = getFieldString(p.status, 'ActualPoorReward');

if isfinite(rewardDiff)
    rewardDiffString = sprintf('%.1f', rewardDiff);
else
    rewardDiffString = 'NaN';
end

%% Remaining / total values

% Blocks
currentBlock = getNumericField(p.status, 'CurrentBlockNumber', NaN);
remainingBlock = getNumericField(p.status, 'RemainingBlock', NaN);

if isfield(p.status, 'TotalBlockNumber')
    totalBlocks = p.status.TotalBlockNumber;
elseif isfield(p.status, 'TotalBlocks')
    totalBlocks = p.status.TotalBlocks;
elseif isfinite(currentBlock) && isfinite(remainingBlock)
    totalBlocks = currentBlock + remainingBlock;
else
    totalBlocks = NaN;
end

remainingBlockString = fractionString(remainingBlock, totalBlocks);

% Conflict / congruent trials
totalTrialsPerBlock = getNumericField(p.status, 'TotalTrialsPerBlock', NaN);
remainingConflict = getNumericField(p.status, 'RemainingConflict', NaN);
remainingCongruent = getNumericField(p.status, 'RemainingCongruent', NaN);

% Default assumption: half conflict, half congruent
if isfield(p.status, 'TotalConflict')
    totalConflict = p.status.TotalConflict;
elseif isfinite(totalTrialsPerBlock)
    totalConflict = totalTrialsPerBlock / 2;
else
    totalConflict = NaN;
end

if isfield(p.status, 'TotalCongruent')
    totalCongruent = p.status.TotalCongruent;
elseif isfinite(totalTrialsPerBlock)
    totalCongruent = totalTrialsPerBlock / 2;
else
    totalCongruent = NaN;
end

remainingConflictString = fractionString(remainingConflict, totalConflict);
remainingCongruentString = fractionString(remainingCongruent, totalCongruent);

%% Online summary values

pHighSalConflictString = probabilityString( ...
    onlineStats.pHighSalConflict, ...
    onlineStats.nConflictChoice);

pHighSalCongruentString = probabilityString( ...
    onlineStats.pHighSalCongruent, ...
    onlineStats.nCongruentChoice);

medianRTConflictString = medianString( ...
    onlineStats.medianRTConflict, ...
    onlineStats.nConflictRT);

medianRTCongruentString = medianString( ...
    onlineStats.medianRTCongruent, ...
    onlineStats.nCongruentRT);

%% Build status panel

statusLines = { ...
    htmlTitle('TASK STATUS', '#1f4e79'); ...
    htmlLine('Good trials', goodTrialString, '#000000'); ...
    htmlLine('Current trial', sprintf('%.0f', trialIdx), '#000000'); ...
    ' '; ...
    htmlSection('BLOCK', '#2f75b5'); ...
    htmlLine('Block type', blockType, '#000000'); ...
    htmlLine('Block number', fractionString(currentBlock, totalBlocks), '#000000'); ...
    htmlLine('Remaining blocks', remainingBlockString, '#000000'); ...
    ' '; ...
    htmlSection('BLOCK CONTENT', '#548235'); ...
    htmlLine('Trials per block', getFieldString(p.status, 'TotalTrialsPerBlock'), '#000000'); ...
    htmlLine('Remaining conflict', remainingConflictString, '#c00000'); ...
    htmlLine('Remaining congruent', remainingCongruentString, '#008000'); ...
    ' '; ...
    htmlSection('TRIAL', '#7030a0'); ...
    htmlLine('Trial type', trialType, '#000000'); ...
    htmlLine('Choice', choiceString, '#000000'); ...
    htmlLine('RT', rtString, '#000000'); ...
    ' '; ...
    htmlSection('REWARD', '#c55a11'); ...
    htmlLine('Rich reward', richRewardString, '#000000'); ...
    htmlLine('Poor reward', poorRewardString, '#000000'); ...
    htmlLine('Reward diff T1 - T2', rewardDiffString, '#000000'); ...
    ' '; ...
    htmlSection('ONLINE SUMMARY', '#44546a'); ...
    htmlLine('P high sal conflict', pHighSalConflictString, '#c00000'); ...
    htmlLine('P high sal congruent', pHighSalCongruentString, '#008000'); ...
    htmlLine('Median RT conflict', medianRTConflictString, '#c00000'); ...
    htmlLine('Median RT congruent', medianRTCongruentString, '#008000') ...
    };

end

function txt = getFieldString(s, fieldName)

if isfield(s, fieldName)
    txt = valueToString(s.(fieldName));
else
    txt = 'missing';
end

end

function txt = valueToString(value)

if ischar(value)
    txt = value;

elseif isstring(value)
    txt = char(value);

elseif isnumeric(value)
    if isscalar(value)
        txt = num2str(value);
    else
        txt = mat2str(value);
    end

elseif islogical(value)
    if value
        txt = 'true';
    else
        txt = 'false';
    end

elseif iscategorical(value)
    txt = char(value);

else
    txt = '<unsupported type>';
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
    '<html><font color="%s"><b>%-22s</b> : %s</font></html>', ...
    color, label, value);

end

function value = getNumericField(s, fieldName, defaultValue)

if isfield(s, fieldName) && isnumeric(s.(fieldName)) && isscalar(s.(fieldName))
    value = s.(fieldName);
else
    value = defaultValue;
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

function txt = probabilityString(value, n)

if isfinite(value)
    txt = sprintf('%.2f (n=%d)', value, n);
else
    txt = sprintf('NaN (n=%d)', n);
end

end

function txt = medianString(value, n)

if isfinite(value)
    txt = sprintf('%.1f ms (n=%d)', value, n);
else
    txt = sprintf('NaN (n=%d)', n);
end

end
