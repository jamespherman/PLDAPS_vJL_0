function p = updateDirectRgbExperimenterPreview(p)
%UPDATEDIRECTRGBEXPERIMENTERPREVIEW Draw exp-only windows and reward cue.
%
% The preview is intentionally updated once between trials. It does not
% issue Screen() calls and cannot alter the C24 image seen by the subject.

if ~isPreviewEnabled(p)
    return
end

if ~isfield(p.draw, 'directRgbPreviewFigure') || ...
        ~isgraphics(p.draw.directRgbPreviewFigure) || ...
        ~isfield(p.draw, 'directRgbPreviewAxes') || ...
        ~isgraphics(p.draw.directRgbPreviewAxes)
    p = initDirectRgbExperimenterPreview(p);
end

if ~isfield(p.draw, 'directRgbPreviewAxes') || ...
        ~isgraphics(p.draw.directRgbPreviewAxes)
    return
end

ax = p.draw.directRgbPreviewAxes;
cla(ax);
hold(ax, 'on');
set(ax, 'Color', [0 0 0], ...
    'XColor', [0.85 0.85 0.85], ...
    'YColor', [0.85 0.85 0.85], ...
    'DataAspectRatio', [1 1 1], ...
    'Box', 'on');

% Resolve current target positions and visible identities.
T1xy = [getScalar(p.trVars, 'T1_locDegX', 10), ...
        getScalar(p.trVars, 'T1_locDegY', 0)];
T2xy = [getScalar(p.trVars, 'T2_locDegX', -10), ...
        getScalar(p.trVars, 'T2_locDegY', 0)];
T1present = logical(getScalar(p.trVars, 'T1_present', 1));
T2present = logical(getScalar(p.trVars, 'T2_present', 1));

winHalfW = getScalar(p.trVars, 'targWinWidthDeg', 4);
winHalfH = getScalar(p.trVars, 'targWinHeightDeg', 4);
long1 = getScalar(p.trVars, 'T1_longAxisDeg', 2);
short1 = getScalar(p.trVars, 'T1_shortAxisDeg', 2/3);
long2 = getScalar(p.trVars, 'T2_longAxisDeg', 2);
short2 = getScalar(p.trVars, 'T2_shortAxisDeg', 2/3);

T1rgb = getRgb(p.trVars, 'T1_colorRGB255', [220 40 100]);
T2rgb = getRgb(p.trVars, 'T2_colorRGB255', [220 40 100]);

% Fixation marker.
plot(ax, 0, 0, '+', 'Color', [1 1 1], 'LineWidth', 2, 'MarkerSize', 12);

if T1present
    drawTarget(ax, T1xy, long1, short1, T1rgb, 'T1');
    drawWindow(ax, T1xy, winHalfW, winHalfH);
end
if T2present
    drawTarget(ax, T2xy, short2, long2, T2rgb, 'T2');
    drawWindow(ax, T2xy, winHalfW, winHalfH);
end


% Blue gaze marker, updated continuously by updateDirectRgbExperimenterGaze.
eyeX = getScalar(p.trVars, 'eyeDegX', NaN);
eyeY = getScalar(p.trVars, 'eyeDegY', NaN);
p.draw.directRgbPreviewGaze = plot(ax, eyeX, eyeY, 'o', ...
    'MarkerSize', 8, 'MarkerFaceColor', [0.1 0.55 1], ...
    'MarkerEdgeColor', [0.75 0.9 1], 'LineWidth', 1.2, ...
    'Tag', 'DirectRgbGazeMarker');

% Rich-target frame. This is the green indicator that was hidden in C24.
highRewardTargetID = getScalar(p.status, 'highRewardTargetID', NaN);
if highRewardTargetID == 1 && T1present
    drawRewardFrame(ax, T1xy, winHalfW, winHalfH);
elseif highRewardTargetID == 2 && T2present
    drawRewardFrame(ax, T2xy, winHalfW, winHalfH);
end

allX = [0 T1xy(1) T2xy(1)];
allY = [0 T1xy(2) T2xy(2)];
marginX = max(5, winHalfW + 2);
marginY = max(5, winHalfH + 2);
xlim(ax, [min(allX)-marginX max(allX)+marginX]);
ylim(ax, [min(allY)-marginY max(allY)+marginY]);
axis(ax, 'manual');
grid(ax, 'on');

trialNumber = getScalar(p.status, 'iTrial', NaN);
blockNumber = getScalar(p.status, 'CurrentBlockNumber', NaN);
trialType = getScalar(p.status, 'ActualTrialType', NaN);
if trialType == 1
    trialLabel = 'Congruent';
elseif trialType == 2
    trialLabel = 'Conflict';
else
    trialLabel = 'Instruction';
end

correctionActive = logical(getScalar(p.status, 'correctionTrialActive', 0));
correctionRep = getScalar(p.status, 'correctionTrialRepetition', 0);
correctionMax = getScalar(p.trVars, 'correctionTrialMaxRepetition', 15);
if correctionActive
    correctionText = sprintf(' | correction %d/%d', correctionRep, correctionMax);
else
    correctionText = '';
end

title(ax, sprintf('EXP ONLY | block %g | attempt %g | %s%s', ...
    blockNumber, trialNumber, trialLabel, correctionText), ...
    'Color', [1 1 1], 'Interpreter', 'none');

text(ax, 0.01, 0.01, ...
    'Dashed = acceptance windows | Green = high reward', ...
    'Units', 'normalized', ...
    'Color', [0.9 0.9 0.9], ...
    'VerticalAlignment', 'bottom', ...
    'FontSize', 9);

% This runs between trials, so a normal drawnow is acceptable and keeps the
% preview responsive without entering the subject's frame loop.
drawnow limitrate nocallbacks;

end

function drawTarget(ax, center, width, height, rgb, label)
rectangle(ax, ...
    'Position', [center(1)-width/2, center(2)-height/2, width, height], ...
    'FaceColor', rgb, ...
    'EdgeColor', [1 1 1], ...
    'LineWidth', 1);
text(ax, center(1), center(2), label, ...
    'HorizontalAlignment', 'center', ...
    'VerticalAlignment', 'middle', ...
    'Color', [1 1 1], ...
    'FontWeight', 'bold');
end

function drawWindow(ax, center, halfW, halfH)
rectangle(ax, ...
    'Position', [center(1)-halfW, center(2)-halfH, 2*halfW, 2*halfH], ...
    'EdgeColor', [0.75 0.75 0.75], ...
    'LineStyle', '--', ...
    'LineWidth', 1.5);
end

function drawRewardFrame(ax, center, halfW, halfH)
scale = 1.15;
rectangle(ax, ...
    'Position', [center(1)-scale*halfW, center(2)-scale*halfH, ...
                 2*scale*halfW, 2*scale*halfH], ...
    'EdgeColor', [0 1 0], ...
    'LineWidth', 3);
end

function rgb = getRgb(s, fieldName, defaultRgb255)
rgb = double(defaultRgb255(:)') / 255;
if isstruct(s) && isfield(s, fieldName)
    candidate = double(s.(fieldName));
    candidate = candidate(:)';
    if numel(candidate) == 3 && all(isfinite(candidate))
        if max(candidate) > 1
            candidate = candidate / 255;
        end
        rgb = min(max(candidate, 0), 1);
    end
end
end

function value = getScalar(s, fieldName, defaultValue)
value = defaultValue;
if isstruct(s) && isfield(s, fieldName)
    candidate = s.(fieldName);
    if (isnumeric(candidate) || islogical(candidate)) && ...
            isscalar(candidate) && isfinite(double(candidate))
        value = double(candidate);
    end
end
end

function tf = isPreviewEnabled(p)
tf = isfield(p, 'trVars') && ...
    isfield(p.trVars, 'directRgbExperimenterPreview') && ...
    logical(p.trVars.directRgbExperimenterPreview);
if ~tf && isfield(p, 'trVarsInit') && ...
        isfield(p.trVarsInit, 'directRgbExperimenterPreview')
    tf = logical(p.trVarsInit.directRgbExperimenterPreview);
end
end
