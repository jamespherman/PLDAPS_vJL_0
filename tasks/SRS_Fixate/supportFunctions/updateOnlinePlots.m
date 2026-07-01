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

trialIdx = p.status.iTrial;

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
% Reward difference plotted like in the paper:
% rewardDiff = T1 - T2

rewardDiff = NaN;

if isfield(p.trVars, 'rewardDurationRight') && isfield(p.trVars, 'rewardDurationLeft')

    reward_T1 = double(p.trVars.rewardDurationRight);
    reward_T2 = double(p.trVars.rewardDurationLeft);

    rewardDiff = reward_T1 - reward_T2;

    appendPoint( ...
        p.draw.onlinePlotObj.rewardDiff, ...
        trialIdx, ...
        rewardDiff);
end

%% ------------------------------------------------------------
% 2. Reaction time plot for Endo vs Exo choices
% ------------------------------------------------------------
% Reaction time:
% RT = saccade onset - go signal
% Go signal = fixation offset = p.trData.timing.fixOff
%
% Endo choice:
% conflict trial + chose high reward target
%
% Exo choice:
% conflict trial + chose high salience target

if isfield(p.trData, 'GoodTrial') && p.trData.GoodTrial

    hasRT = ...
        isfield(p.trData, 'timing') && ...
        isfield(p.trData.timing, 'saccadeOnset') && ...
        isfield(p.trData.timing, 'fixOff') && ...
        p.trData.timing.saccadeOnset > 0 && ...
        p.trData.timing.fixOff > 0;

    hasChoice = isfield(p.trData, 'chosenSide');

    if hasRT && hasChoice

        rtMs = 1000 * (p.trData.timing.saccadeOnset - p.trData.timing.fixOff);
        disp(rtMs)
        isConflictTrial = p.status.ActualTrialType == 2;

        if isConflictTrial && rtMs > 0

            choseHighReward = p.trData.chosenSide == p.status.highRewardSide;
            choseHighSalience = p.trData.chosenSide == p.status.highSalienceSide;

            if choseHighReward
                % Endogenous choice:
                % rich target wins despite being low salience
                appendPoint( ...
                    p.draw.onlinePlotObj.rtEndo, ...
                    trialIdx, ...
                    rtMs);

            elseif choseHighSalience
                % Exogenous choice:
                % salient target wins despite being poor reward
                appendPoint( ...
                    p.draw.onlinePlotObj.rtExo, ...
                    trialIdx, ...
                    rtMs);
            end
        end
    end
end

%% ------------------------------------------------------------
% 3. Update axes limits
% ------------------------------------------------------------

xMax = max(10, trialIdx + 1);

% Reward axis
set(p.draw.onlinePlotAxes.rewardDiff, 'XLim', [0 xMax]);

set( ...
    p.draw.onlinePlotObj.rewardZero, ...
    'XData', [0 xMax], ...
    'YData', [0 0]);

rewardY = get(p.draw.onlinePlotObj.rewardDiff, 'YData');
rewardY = rewardY(isfinite(rewardY));

if isempty(rewardY)
    yAbsMax = 200;
else
    yAbsMax = max(50, 1.2 * max(abs(rewardY)));
end

set(p.draw.onlinePlotAxes.rewardDiff, ...
    'YLim', [-yAbsMax yAbsMax]);

% RT axis
set(p.draw.onlinePlotAxes.rtChoice, 'XLim', [0 xMax]);

rtEndo = get(p.draw.onlinePlotObj.rtEndo, 'YData');
rtExo  = get(p.draw.onlinePlotObj.rtExo,  'YData');

rtAll = [rtEndo(:); rtExo(:)];
rtAll = rtAll(isfinite(rtAll));

if isempty(rtAll)
    rtMax = 500;
else
    rtMax = max(500, 1.15 * max(rtAll));
end

set(p.draw.onlinePlotAxes.rtChoice, ...
    'YLim', [0 rtMax]);

%% ------------------------------------------------------------
% 4. Update status text display
% ------------------------------------------------------------

if isfield(p.draw.onlinePlotObj, 'statusText') && ...
        ishandle(p.draw.onlinePlotObj.statusText)

    statusLines = makeOnlineStatusLines(p, trialIdx, rewardDiff);

    set(p.draw.onlinePlotObj.statusText, ...
    'String', statusLines, ...
    'Value', 1);

end


drawnow;

end

%% ------------------------------------------------------------
% Helper function
% ------------------------------------------------------------

function appendPoint(plotHandle, x, y)

oldX = get(plotHandle, 'XData');
oldY = get(plotHandle, 'YData');

% Remove initial NaN point
if numel(oldX) == 1 && isnan(oldX)
    oldX = [];
    oldY = [];
end

set(plotHandle, ...
    'XData', [oldX x], ...
    'YData', [oldY y]);

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
    '<html><font color="%s"><b>%-20s</b> : %s</font></html>', ...
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


function statusLines = makeOnlineStatusLines(p, trialIdx, rewardDiff)

%% ------------------------------------------------------------
% Block type
% ------------------------------------------------------------

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

%% ------------------------------------------------------------
% Trial type
% ------------------------------------------------------------

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

%% ------------------------------------------------------------
% Choice
% ------------------------------------------------------------

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

%% ------------------------------------------------------------
% Good trial
% ------------------------------------------------------------

if isfield(p.status, 'iGoodTrial')
    goodTrialString = valueToString(p.status.iGoodTrial);
elseif isfield(p.trData, 'GoodTrial')
    goodTrialString = valueToString(p.trData.GoodTrial);
else
    goodTrialString = 'missing';
end

%% ------------------------------------------------------------
% RT
% ------------------------------------------------------------

rtString = 'missing';

if isfield(p.trData, 'timing') && ...
        isfield(p.trData.timing, 'fixOff') && ...
        isfield(p.trData.timing, 'saccadeOnset') && ...
        isfinite(p.trData.timing.fixOff) && ...
        isfinite(p.trData.timing.saccadeOnset) && ...
        p.trData.timing.saccadeOnset > p.trData.timing.fixOff

    rtMs = 1000 * (p.trData.timing.saccadeOnset - p.trData.timing.fixOff);
    rtString = sprintf('%.1f ms', rtMs);
end

%% ------------------------------------------------------------
% Reward values
% ------------------------------------------------------------

richRewardString = getFieldString(p.status, 'ActualRichReward');
poorRewardString = getFieldString(p.status, 'ActualPoorReward');

if isfinite(rewardDiff)
    rewardDiffString = sprintf('%.1f', rewardDiff);
else
    rewardDiffString = 'NaN';
end

%% ------------------------------------------------------------
% Remaining / total values
% ------------------------------------------------------------

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

%% ------------------------------------------------------------
% Build prettier status panel
% ------------------------------------------------------------

statusLines = { ...
    htmlTitle('TASK STATUS', '#1f4e79'); ...
    htmlLine('Good trials', goodTrialString, '#000000'); ...
    htmlLine('Current trial', sprintf('%d', trialIdx), '#000000'); ...
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
    htmlLine('Reward diff T1 - T2', rewardDiffString, '#000000') ...
    };

end
