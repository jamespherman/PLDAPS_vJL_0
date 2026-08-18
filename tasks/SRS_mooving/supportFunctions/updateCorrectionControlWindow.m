function p = updateCorrectionControlWindow(p)
%UPDATECORRECTIONCONTROLWINDOW Refresh moving-task correction diagnostics.
%
% Absolute right-choice probability is conditioned on trials where one
% target was available in each horizontal hemifield. Relative rightmost
% choice is shown separately and remains meaningful for same-side pairs.

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

pRight = computeChoiceProbability(p, 'rightHemi');
pRightmost = computeChoiceProbability(p, 'rightmost');
active = getLogical(status, 'correctionTrialActive', false);
row = getNumeric(status, 'correctionTrialRow', NaN);
rep = getNumeric(status, 'correctionTrialRepetition', 0);
triggerSide = getNumeric(status, 'correctionTrialTriggerSide', NaN);
maxRep = getNumeric(trVars, 'correctionTrialMaxRepetition', ...
    getNumeric(guiVars, 'correctionTrialMaxRepetition', 15));
outcome = getText(status, 'correctionTrialLastOutcome', 'inactive');
origRight = getNumeric(trVars, 'correctionOriginalRightRewardMs', NaN);
appliedRight = getNumeric(trVars, 'correctionRightRewardAppliedMs', NaN);
snapshotValid = getLogical(status, 'correctionTrialSnapshotValid', false);
bothSides = getLogical(trVars, 'correctionBothSides', ...
    getLogical(guiVars, 'correctionBothSides', false));

if bothSides
    modeText = 'LEFT + RIGHT low-reward choices, only when L/R both available';
else
    modeText = 'RIGHT low-reward choices, only when L/R both available';
end

lines = { ...
    sprintf('Enabled: %s', yesNo(getLogical(trVars, 'correctionTrial', false))), ...
    sprintf('Trigger mode: %s', modeText), ...
    sprintf('Active: %s', yesNo(active)), ...
    sprintf('Incorrect trigger side: %s', sideText(triggerSide)), ...
    sprintf('Forced row: %s', numberText(row)), ...
    sprintf('Repetition: %d / %d', round(rep), round(maxRep)), ...
    sprintf('Exact condition saved: %s', yesNo(snapshotValid)), ...
    sprintf('Last outcome: %s', outcome), ...
    sprintf('RIGHT reward original/applied: %s / %s ms', ...
        numberText(origRight), numberText(appliedRight)), ...
    probabilityText('P(right hemi | L/R available)', pRight), ...
    probabilityText('P(rightmost target)', pRightmost), ...
    sprintf('Triggered/succeeded/max: %d / %d / %d', ...
        round(getNumeric(status, 'correctionTrialTriggerCount', 0)), ...
        round(getNumeric(status, 'correctionTrialSuccessCount', 0)), ...
        round(getNumeric(status, 'correctionTrialMaxReachedCount', 0))) ...
    };

set(p.draw.correctionControl.statusText, 'String', lines);
drawnow limitrate nocallbacks;

end

function result = computeChoiceProbability(p, mode)
result = struct('value', NaN, 'n', 0);
if ~isfield(p, 'status') || ~isfield(p.status, 'onlinePlot')
    return
end
op = p.status.onlinePlot;
if ~isfield(op, 'nStim') || ~isfield(op, 'mappingValid')
    return
end

nStim = double(op.nStim(:));
mappingRaw = double(op.mappingValid(:));
valid = nStim == 2 & isfinite(mappingRaw) & mappingRaw ~= 0;

switch mode
    case 'rightHemi'
        if ~isfield(op,'chosenSide') || ~isfield(op,'straddlesLR')
            return
        end
        choice = double(op.chosenSide(:));
        straddle = double(op.straddlesLR(:));
        valid = valid & straddle == 1 & ismember(choice,[1 2]);
        success = choice == 1;
    case 'rightmost'
        if ~isfield(op,'chosenHorizontalRank')
            return
        end
        choice = double(op.chosenHorizontalRank(:));
        valid = valid & ismember(choice,[1 2]);
        success = choice == 1;
    otherwise
        return
end

result.n = sum(valid);
if result.n > 0
    result.value = mean(success(valid));
end
end

function txt = probabilityText(label, result)
if isfinite(result.value)
    txt = sprintf('%s: %.3f  (n=%d)', label, result.value, result.n);
else
    txt = sprintf('%s: n/a  (n=%d)', label, result.n);
end
end

function value = getNumeric(s, name, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s,name)
    candidate = s.(name);
    if (isnumeric(candidate)||islogical(candidate)) && ...
            isscalar(candidate) && isfinite(double(candidate))
        value = double(candidate);
    end
end
end

function value = getLogical(s,name,defaultValue)
value = logical(getNumeric(s,name,double(defaultValue)));
end

function value = getText(s,name,defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s,name)
    candidate = s.(name);
    if ischar(candidate)
        value = candidate;
    elseif isstring(candidate) && isscalar(candidate)
        value = char(candidate);
    end
end
end

function txt = numberText(value)
if isfinite(value), txt=sprintf('%.0f',value); else, txt='n/a'; end
end

function txt = sideText(side)
if side==1, txt='RIGHT'; elseif side==2, txt='LEFT'; else, txt='n/a'; end
end

function txt = yesNo(tf)
if tf, txt='Yes'; else, txt='No'; end
end
