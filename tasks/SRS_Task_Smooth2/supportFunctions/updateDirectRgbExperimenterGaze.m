function p = updateDirectRgbExperimenterGaze(p)
%UPDATEDIRECTRGBEXPERIMENTERGAZE Update the blue gaze marker in the preview.
%
% The update is throttled to avoid calling MATLAB graphics at the 120-Hz
% stimulus refresh rate. No Psychtoolbox Screen() call is made here.

if ~isfield(p, 'draw') || ~isfield(p.draw, 'directRgbPreviewFigure') || ...
        ~isgraphics(p.draw.directRgbPreviewFigure) || ...
        ~isfield(p.draw, 'directRgbPreviewAxes') || ...
        ~isgraphics(p.draw.directRgbPreviewAxes)
    return
end

nowTime = GetSecs;
lastTime = -inf;
if isfield(p.status, 'directRgbPreviewLastGazeUpdate') && ...
        isfinite(p.status.directRgbPreviewLastGazeUpdate)
    lastTime = p.status.directRgbPreviewLastGazeUpdate;
end
updateInterval = 0.005; % 20 Hz preview, independent of the subject display.
if nowTime - lastTime < updateInterval
    return
end
p.status.directRgbPreviewLastGazeUpdate = nowTime;

x = getScalar(p.trVars, 'eyeDegX', NaN);
y = getScalar(p.trVars, 'eyeDegY', NaN);
if ~isfinite(x) || ~isfinite(y)
    return
end

if ~isfield(p.draw, 'directRgbPreviewGaze') || ...
        ~isgraphics(p.draw.directRgbPreviewGaze)
    p.draw.directRgbPreviewGaze = plot(p.draw.directRgbPreviewAxes, x, y, 'o', ...
        'MarkerSize', 8, 'MarkerFaceColor', [0.1 0.55 1], ...
        'MarkerEdgeColor', [0.75 0.9 1], 'LineWidth', 1.2, ...
        'Tag', 'DirectRgbGazeMarker');
else
    set(p.draw.directRgbPreviewGaze, 'XData', x, 'YData', y, 'Visible', 'on');
end

drawnow limitrate nocallbacks;

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
