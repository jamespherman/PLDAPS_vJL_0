function displayTrialStatus(p)
%DISPLAYTRIALSTATUS Display current SRS schedule and trial information.

fprintf('\n');
fprintf('============================================================\n');
fprintf('                    TASK STATUS SUMMARY                     \n');
fprintf('============================================================\n');
printField('Current trial good', yesNo(getField(p.trData, 'GoodTrial', 0)));
printField('Good trials total', getField(p.status, 'iGoodTrial', NaN));
printField('Current attempt', getField(p.status, 'iTrial', NaN));

fprintf('\n------------------------- BLOCK ----------------------------\n');
blockType = 'not started';
if getField(p.status, 'CurrentBlockType', 0) == 1
    blockType = 'T1 rich';
elseif getField(p.status, 'CurrentBlockType', 0) == 2
    blockType = 'T2 rich';
end
printField('Current block type', blockType);
printField('Current block number', fractionString( ...
    getField(p.status, 'CurrentBlockNumber', NaN), ...
    getField(p.status, 'TotalBlocksTarget', NaN)));
printField('Remaining blocks', getField(p.status, 'RemainingBlock', NaN));
printField('Completed schedule rows', fractionString( ...
    getField(p.status, 'CurrentBlockTrial', NaN), ...
    getField(p.status, 'TotalTrialsPerBlock', NaN)));

fprintf('\n---------------------- BLOCK CONTENT -----------------------\n');
printField('Instruction remaining', fractionString( ...
    getField(p.status, 'RemainingInstructionTrials', NaN), ...
    getField(p.status, 'TotalInstructionTrialsPerBlock', NaN)));
printField('Single T1 remaining', fractionString( ...
    getField(p.status, 'RemainingSingleT1', NaN), ...
    getField(p.status, 'TotalSingleT1', NaN)));
printField('Single T2 remaining', fractionString( ...
    getField(p.status, 'RemainingSingleT2', NaN), ...
    getField(p.status, 'TotalSingleT2', NaN)));
printField('Congruent remaining', fractionString( ...
    getField(p.status, 'RemainingCongruent', NaN), ...
    getField(p.status, 'TotalCongruent', NaN)));
printField('Conflict remaining', fractionString( ...
    getField(p.status, 'RemainingConflict', NaN), ...
    getField(p.status, 'TotalConflict', NaN)));

fprintf('\n-------------------------- TRIAL ---------------------------\n');
nStim = getField(p.trVars, 'nStim', NaN);
if nStim == 1
    trialType = sprintf('Instruction: T%d only', ...
        getField(p.trVars, 'singleTargetID', NaN));
elseif getField(p.status, 'ActualTrialType', NaN) == 1
    trialType = 'Congruent choice';
else
    trialType = 'Conflict choice';
end
printField('Schedule row', getField(p.trVars, 'currentTrialsArrayRow', NaN));
printField('Trial type', trialType);
printField('Number of stimuli', nStim);
printField('T1 side', sideString(getField(p.trVars, 'T1Side', NaN)));
printField('T2 side', sideString(getField(p.trVars, 'T2Side', NaN)));
printField('Rich target', targetSideString( ...
    getField(p.status, 'highRewardTargetID', NaN), ...
    getField(p.status, 'highRewardSide', NaN)));
printField('High-salience target', targetSideString( ...
    getField(p.status, 'highSalienceTargetID', NaN), ...
    getField(p.status, 'highSalienceSide', NaN)));
printField('Chosen target', targetSideString( ...
    getField(p.trData, 'chosenTargetID', NaN), ...
    getField(p.trData, 'chosenSide', NaN)));

fprintf('\n------------------------- VALUES ---------------------------\n');
printField('T1 reward (ms)', getField(p.trVars, 'rewardDurationT1', NaN));
printField('T2 reward (ms)', getField(p.trVars, 'rewardDurationT2', NaN));
printField('T1 task luminance', getField(p.trVars, 'ActualLuminanceT1', NaN));
printField('T2 task luminance', getField(p.trVars, 'ActualLuminanceT2', NaN));
printField('Luminance diff T1-T2', ...
    getField(p.trVars, 'LuminanceDifferenceT1MinusT2', NaN));
printField('Background DKL lum', getBackgroundDkl(p));

fprintf('============================================================\n\n');

end

function printField(label, value)
fprintf('  %-28s : %s\n', label, valueToString(value));
end

function value = getField(s, fieldName, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s, fieldName)
    value = s.(fieldName);
end
end

function value = getBackgroundDkl(p)
value = NaN;
if isfield(p.draw, 'clut') && isfield(p.draw.clut, 'srsBackgroundDklLum')
    value = p.draw.clut.srsBackgroundDklLum;
elseif isfield(p.trVars, 'srsLuminanceBackgroundDklLum')
    value = p.trVars.srsLuminanceBackgroundDklLum;
end
end

function txt = fractionString(value, total)
if isnumeric(value) && isnumeric(total) && isfinite(value) && isfinite(total)
    txt = sprintf('%.0f / %.0f', value, total);
else
    txt = 'missing';
end
end

function txt = sideString(side)
if side == 1
    txt = 'right';
elseif side == 2
    txt = 'left';
else
    txt = 'none';
end
end

function txt = targetSideString(targetID, side)
if any(targetID == [1 2])
    txt = sprintf('T%d / %s', targetID, sideString(side));
else
    txt = 'none';
end
end

function txt = yesNo(value)
if logical(value)
    txt = 'yes';
else
    txt = 'no';
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
    txt = yesNo(value);
else
    txt = '<unsupported type>';
end
end
