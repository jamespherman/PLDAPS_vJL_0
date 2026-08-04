function p = updateCorrectionControlWindow(p)
%UPDATECORRECTIONCONTROLWINDOW Refresh live correction diagnostics.

if ~isfield(p, 'draw') || ~isfield(p.draw, 'correctionControlFigure') || ...
        ~isgraphics(p.draw.correctionControlFigure) || ...
        ~isfield(p.draw, 'correctionControl') || ...
        ~isfield(p.draw.correctionControl, 'statusText') || ...
        ~isgraphics(p.draw.correctionControl.statusText)
    return
end

trVars = struct();
if isfield(p, 'trVars') && isstruct(p.trVars)
    trVars = p.trVars;
elseif isfield(p, 'trVarsGuiComm') && isstruct(p.trVarsGuiComm)
    trVars = p.trVarsGuiComm;
elseif isfield(p, 'trVarsInit') && isstruct(p.trVarsInit)
    trVars = p.trVarsInit;
end
guiVars = struct();
if isfield(p, 'trVarsGuiComm') && isstruct(p.trVarsGuiComm)
    guiVars = p.trVarsGuiComm;
end
status = struct();
if isfield(p, 'status') && isstruct(p.status)
    status = p.status;
end

pRight = computeRightChoiceProbability(p);
active = getLogical(status, 'correctionTrialActive', false);
row = getNumeric(status, 'correctionTrialRow', NaN);
rep = getNumeric(status, 'correctionTrialRepetition', 0);
reductionLevel = getNumeric(status, ...
    'correctionRightRewardReductionLevel', 0);
maxRep = getNumeric(trVars, 'correctionTrialMaxRepetition', ...
    getNumeric(guiVars, 'correctionTrialMaxRepetition', 15));
outcome = getText(status, 'correctionTrialLastOutcome', 'inactive');
origRight = getNumeric(trVars, 'correctionOriginalRightRewardMs', NaN);
appliedRight = getNumeric(trVars, 'correctionRightRewardAppliedMs', NaN);
snapshotValid = getLogical(status, 'correctionTrialSnapshotValid', false);

if isfinite(pRight.value)
    rightText = sprintf('P(right choice): %.3f  (n=%d)', ...
        pRight.value, pRight.n);
else
    rightText = sprintf('P(right choice): n/a  (n=%d)', pRight.n);
end

lines = { ...
    sprintf('Enabled: %s', yesNo(getLogical(trVars, 'correctionTrial', false))), ...
    sprintf('Active:  %s', yesNo(active)), ...
    sprintf('Forced row: %s', numberText(row)), ...
    sprintf('Repetition: %d / %d', round(rep), round(maxRep)), ...
    sprintf('RIGHT reward reduction level: %d', round(reductionLevel)), ...
    sprintf('Exact condition saved: %s', yesNo(snapshotValid)), ...
    sprintf('Last outcome: %s', outcome), ...
    sprintf('RIGHT reward original/applied: %s / %s ms', ...
        numberText(origRight), numberText(appliedRight)), ...
    rightText, ...
    sprintf('Triggered/succeeded/max: %d / %d / %d', ...
        round(getNumeric(status, 'correctionTrialTriggerCount', 0)), ...
        round(getNumeric(status, 'correctionTrialSuccessCount', 0)), ...
        round(getNumeric(status, 'correctionTrialMaxReachedCount', 0))) ...
    };
set(p.draw.correctionControl.statusText, 'String', lines);
drawnow limitrate nocallbacks;

end

function result = computeRightChoiceProbability(p)
result = struct('value', NaN, 'n', 0);
if ~isfield(p, 'status') || ~isfield(p.status, 'onlinePlot')
    return
end
op = p.status.onlinePlot;
if ~isfield(op, 'chosenSide')
    return
end
chosenSide = double(op.chosenSide(:));
valid = isfinite(chosenSide) & ismember(chosenSide, [1 2]);
if isfield(op, 'nStim')
    valid = valid & double(op.nStim(:)) == 2;
end
if isfield(op, 'mappingValid')
    try
    valid = valid & logical(op.mappingValid(:));
    catch exception
        ... 
    end
    end
result.n = sum(valid);
if result.n > 0
    result.value = mean(chosenSide(valid) == 1);
end
end

function value = getNumeric(s, name, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s, name)
    candidate = s.(name);
    if (isnumeric(candidate) || islogical(candidate)) && ...
            isscalar(candidate) && isfinite(double(candidate))
        value = double(candidate);
    end
end
end

function value = getLogical(s, name, defaultValue)
value = logical(getNumeric(s, name, double(defaultValue)));
end

function value = getText(s, name, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s, name)
    candidate = s.(name);
    if ischar(candidate)
        value = candidate;
    elseif isstring(candidate) && isscalar(candidate)
        value = char(candidate);
    end
end
end

function text = numberText(value)
if isfinite(value)
    text = sprintf('%.0f', value);
else
    text = 'n/a';
end
end

function text = yesNo(tf)
if tf
    text = 'Yes';
else
    text = 'No';
end
end
