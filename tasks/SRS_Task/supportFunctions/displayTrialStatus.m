function displayTrialStatus(p)
%DISPLAYTRIALSTATUS Display current SRS schedule and trial information.
%
% Luminance labels distinguish the nominal sampling coordinates from the
% DKL coordinates sent to the display and the physical i1Pro 3 measurements
% in cd/m^2.

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

fprintf('\n---------------------- BLOCK SCHEDULE ----------------------\n');
printField('Instruction order', instructionOrderString(p.status));
printField('Active schedule', activeScheduleString(p.status));
printField('Active phase remaining', ...
    getField(p.status, 'RemainingActivePhase', NaN));
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
elseif getField(p.status, 'ActualTrialType', NaN) == 2
    trialType = 'Conflict choice';
else
    trialType = 'missing';
end
printField('Schedule row', getField(p.trVars, 'currentTrialsArrayRow', NaN));
printField('Schedule phase', getField(p.trVars, 'schedulePhase', NaN));
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

fprintf('\n------------------------- REWARD ---------------------------\n');
printField('T1 reward (ms)', getField(p.trVars, 'rewardDurationT1', NaN));
printField('T2 reward (ms)', getField(p.trVars, 'rewardDurationT2', NaN));
printField('Reward diff T1-T2 (ms)', ...
    getField(p.trVars, 'rewardDurationT1', NaN) - ...
    getField(p.trVars, 'rewardDurationT2', NaN));

fprintf('\n------------------ MEASURED LUMINANCE ----------------------\n');
backgroundDkl = getBackgroundDkl(p);
backgroundCdM2 = getBackgroundCdM2(p);
printField('Background DKL lum', formatScalar(backgroundDkl, '%.3f'));
printField('Background measured', formatScalar(backgroundCdM2, '%.1f cd/m^2'));
printField('T1 measured', formatScalar( ...
    getField(p.trVars, 'MeasuredLuminanceT1CdM2', NaN), '%.3f cd/m^2'));
printField('T2 measured', formatScalar( ...
    getField(p.trVars, 'MeasuredLuminanceT2CdM2', NaN), '%.3f cd/m^2'));
printField('Measured diff T1-T2', formatScalar( ...
    getField(p.trVars, ...
    'MeasuredLuminanceDifferenceT1MinusT2CdM2', NaN), ...
    '%.3f cd/m^2'));
[calibrationMin, calibrationMax, calibrationLabel] = ...
    getCalibrationSummary(p);
printField('Calibration range', calibrationRangeString( ...
    calibrationMin, calibrationMax));
printField('Calibration label', calibrationLabel);
printField('T1 / T2 colorIdx', sprintf('%s / %s', ...
    valueToString(getField(p.trVars, 'T1_colorIdx', NaN)), ...
    valueToString(getField(p.trVars, 'T2_colorIdx', NaN))));

fprintf('\n------------------- LUMINANCE MAPPING ----------------------\n');
nominalT1 = getField(p.trVars, 'NominalLuminanceT1', ...
    getField(p.trVars, 'ActualLuminanceT1', NaN));
nominalT2 = getField(p.trVars, 'NominalLuminanceT2', ...
    getField(p.trVars, 'ActualLuminanceT2', NaN));
printField('T1 nominal coordinate', formatScalar(nominalT1, '%.3f'));
printField('T2 nominal coordinate', formatScalar(nominalT2, '%.3f'));
printField('Nominal diff T1-T2', formatScalar( ...
    getField(p.trVars, 'NominalLuminanceDifferenceT1MinusT2', ...
    nominalT1 - nominalT2), '%.3f'));
printField('T1 DKL luminance', formatScalar( ...
    getField(p.trVars, 'ActualDklRedLuminanceT1', NaN), '%.6f'));
printField('T2 DKL luminance', formatScalar( ...
    getField(p.trVars, 'ActualDklRedLuminanceT2', NaN), '%.6f'));
printField('DKL diff T1-T2', formatScalar( ...
    getField(p.trVars, ...
    'DklRedLuminanceDifferenceT1MinusT2', NaN), '%.6f'));

fprintf('============================================================\n\n');

end

function printField(label, value)
fprintf('  %-29s : %s\n', label, valueToString(value));
end

function value = getField(s, fieldName, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s, fieldName)
    value = s.(fieldName);
end
end

function value = getBackgroundDkl(p)
value = getField(p.trVars, 'BackgroundDklLuminance', NaN);
if ~isfiniteScalar(value) && isfield(p.draw, 'clut')
    value = getField(p.draw.clut, 'srsBackgroundDklLum', NaN);
end
if ~isfiniteScalar(value)
    value = getField(p.trVars, 'srsLuminanceBackgroundDklLum', NaN);
end
end

function value = getBackgroundCdM2(p)
value = getField(p.trVars, 'BackgroundMeasuredLuminanceCdM2', NaN);
if ~isfiniteScalar(value) && isfield(p.draw, 'clut')
    value = getField(p.draw.clut, 'srsBackgroundMeasuredCdM2', NaN);
end
if ~isfiniteScalar(value)
    value = getField(p.trVars, 'srsLuminanceBackgroundMeasuredCdM2', NaN);
end
end

function [minimumCdM2, maximumCdM2, label] = getCalibrationSummary(p)
minimumCdM2 = NaN;
maximumCdM2 = NaN;
label = 'not loaded';
if isfield(p.draw, 'clut') && ...
        isfield(p.draw.clut, 'redLumCalibration') && ...
        isstruct(p.draw.clut.redLumCalibration)
    calibration = p.draw.clut.redLumCalibration;
    minimumCdM2 = getField(calibration, 'minimumCdM2', NaN);
    maximumCdM2 = getField(calibration, 'maximumCdM2', NaN);
    label = getField(calibration, 'label', label);
end
end

function txt = instructionOrderString(status)
firstTarget = getField(status, 'FirstSingleTargetID', NaN);
secondTarget = getField(status, 'SecondSingleTargetID', NaN);
if any(firstTarget == [1 2]) && any(secondTarget == [1 2])
    txt = sprintf('T%d-only -> T%d-only', firstTarget, secondTarget);
else
    txt = 'none';
end
end

function txt = activeScheduleString(status)
phase = getField(status, 'ActiveSchedulePhase', NaN);
targetID = getField(status, 'ActiveSingleTargetID', NaN);
if phase == 1 || phase == 2
    if any(targetID == [1 2])
        txt = sprintf('Phase %.0f: T%d-only', phase, targetID);
    else
        txt = sprintf('Phase %.0f: single-target', phase);
    end
elseif phase == 3
    txt = 'Phase 3: two-target choice';
elseif phase == 0
    txt = 'complete / not started';
else
    txt = 'missing';
end
end

function txt = calibrationRangeString(minimumCdM2, maximumCdM2)
if isfiniteScalar(minimumCdM2) && isfiniteScalar(maximumCdM2)
    txt = sprintf('%.3f - %.3f cd/m^2', minimumCdM2, maximumCdM2);
else
    txt = 'not loaded';
end
end

function txt = formatScalar(value, fmt)
if isfiniteScalar(value)
    txt = sprintf(fmt, value);
else
    txt = 'NaN';
end
end

function tf = isfiniteScalar(value)
tf = isnumeric(value) && isscalar(value) && isfinite(value);
end

function txt = fractionString(value, total)
if isfiniteScalar(value) && isfiniteScalar(total)
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
