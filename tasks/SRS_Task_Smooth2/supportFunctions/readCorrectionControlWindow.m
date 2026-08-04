function p = readCorrectionControlWindow(p)
%READCORRECTIONCONTROLWINDOW Read live correction controls before a trial.

if ~isfield(p, 'draw') || ~isfield(p.draw, 'correctionControlFigure') || ...
        ~isgraphics(p.draw.correctionControlFigure) || ...
        ~isfield(p.draw, 'correctionControl')
    return
end

% Process pending MATLAB UI edits before reading String/Value properties.
drawnow limitrate;

h = p.draw.correctionControl;
required = {'enable','maxRepetition','reduceRightReward', ...
    'rightRewardMultiplier','rightRewardMinimumMs'};
for i = 1:numel(required)
    if ~isfield(h, required{i}) || ~isgraphics(h.(required{i}))
        return
    end
end

enabled = logical(get(h.enable, 'Value'));
maxRep = parseNumericEdit(h.maxRepetition, 15, 0, 1000, true);
reduceRight = logical(get(h.reduceRightReward, 'Value'));
multiplier = parseNumericEdit(h.rightRewardMultiplier, 0.50, 0, 1, false);
minimumMs = parseNumericEdit(h.rightRewardMinimumMs, 1, 0, inf, true);

p.trVars.correctionTrial = enabled;
p.trVars.correctionTrialMaxRepetition = maxRep;
p.trVars.correctionReduceRightReward = reduceRight;
p.trVars.correctionRightRewardMultiplier = multiplier;
p.trVars.correctionRightRewardMinimumMs = minimumMs;
p.trVars.correctionRightRewardMultiplier_x1000 = round(1000 * multiplier);

% Mirror into the GUI communication copy so the values survive the normal
% p.trVars = p.trVarsGuiComm assignment on the next trial.
if ~isfield(p, 'trVarsGuiComm') || ~isstruct(p.trVarsGuiComm)
    p.trVarsGuiComm = p.trVars;
else
    p.trVarsGuiComm.correctionTrial = enabled;
    p.trVarsGuiComm.correctionTrialMaxRepetition = maxRep;
    p.trVarsGuiComm.correctionReduceRightReward = reduceRight;
    p.trVarsGuiComm.correctionRightRewardMultiplier = multiplier;
    p.trVarsGuiComm.correctionRightRewardMinimumMs = minimumMs;
    p.trVarsGuiComm.correctionRightRewardMultiplier_x1000 = round(1000 * multiplier);
end

end

function value = parseNumericEdit(handle, defaultValue, minValue, maxValue, integerOnly)
value = str2double(get(handle, 'String'));
if ~isfinite(value)
    value = defaultValue;
end
value = min(max(value, minValue), maxValue);
if integerOnly
    value = round(value);
end
set(handle, 'String', num2str(value, '%.6g'));
end
