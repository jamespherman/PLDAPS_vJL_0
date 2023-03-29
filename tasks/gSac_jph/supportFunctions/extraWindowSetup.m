function p = extraWindowSetup(p)

%
% p = extraWindowSetup(p)
%
% Function in which we initialize the saccade mapping gui.

% if we're using the mapping gui, initialize it here
if p.trVarsInit.setTargLocViaGui
    
    % first check to see if there's already a gui open and close it.
    guiHandle = findall(0, 'Name', 'saccade mapping GUI');
    if ~isempty(guiHandle)
        close(guiHandle)
    end
    
    % open new gui window
    p.rig.guiData = saccadeGUI(false);
    
    % reposition saccade gui window relative to main gui window
    mainGuiPos = get(findall(0, 'Name', 'PLDAPS_vK2_GUI'), 'Position');
    set(p.rig.guiData.handles.hGui, 'Position', ...
        [sum([mainGuiPos([1 3]), 10]), mainGuiPos(2), 1500, 1200]);
end

if p.trVarsInit.wantOnlinePlots
% make a gui window to plot eye / target position information:
% make new plotting window for fixation / joystick press duration timing
% information:
p.draw.gazeVsTimeFig         = ...
    figure(...
    'Position', [10 800 1200 650],...
    'Name','gazeVsTimeFig',...
    'NumberTitle','off',...
    'Color', 1 * [1 1 1],...
    'Visible','on',...
    'NextPlot','add');

% make axes for plotting eye position
p.draw.gazePosPlotAxes = ...
    axes(...
    'Parent', p.draw.gazeVsTimeFig, ...
    'Position', [0.06 0.1 0.875 0.875], ...
    'TickDir', 'Out', ...
    'LineWidth', 1, ...
    'XColor', [0 0 0], ...
    'YColor', [0 0 0], ...
    'NextPlot', 'add' ...
    );

% make axes for plotting eye velocity
p.draw.gazeVelPlotAxes = ...
    axes(...
    'Parent', p.draw.gazeVsTimeFig, ...
    'Position', [0.06 0.1 0.875 0.875], ...
    'TickDir', 'Out', ...
    'LineWidth', 1, ...
    'XColor', 'none', ...
    'YColor', [0.2 0.2 1], ...
    'NextPlot', 'add', ...
    'YAxisLocation', 'right', ...
    'Color', 'none' ...
    );

% add X / Y axis labels:
set(p.draw.gazePosPlotAxes.XAxis.Label, ...
    'String', 'Time from fixation acquisition (s)', ...
    'FontSize', 16 ...
    );
set(p.draw.gazePosPlotAxes.YAxis.Label, ...
    'String', 'Eye Position (deg)', ...
    'FontSize', 16 ...
    );
set(p.draw.gazeVelPlotAxes.YAxis.Label, ...
    'String', 'Eye Velocity (deg / s)', ...
    'FontSize', 16 ...
    );


% Make plot objects for several features
% (1) X gaze
% (2) Y gaze
% (3) Target
% (4) Fixation
% (5) eye velocity
% (6) Saccade Onset
% (7) Saccade Offset
% (8) Velocity Threshold
p.draw.plotObs.xGaze    = plot(p.draw.gazePosPlotAxes, NaN, NaN, ...
    'Color', [0.2941         0    0.5725]);
p.draw.plotObs.yGaze    = plot(p.draw.gazePosPlotAxes, NaN, NaN, ...
    'Color', [0    0.4235    0.8196]);
p.draw.plotObs.tgt      = plot(p.draw.gazePosPlotAxes, NaN, NaN, ...
    'Color', [0.0471    0.4824    0.8627]);
p.draw.plotObs.fix      = plot(p.draw.gazePosPlotAxes, NaN, NaN, ...
    'Color', [0.1020    0.5216    1.0000]);
p.draw.plotObs.eyeVel   = plot(p.draw.gazeVelPlotAxes, NaN, NaN, ...
    'Color', [0 0 0]);
p.draw.plotObs.sacOn    = plot(p.draw.gazeVelPlotAxes, NaN, NaN, ...
    'Color', [0.8824    0.7451    0.4157]);
p.draw.plotObs.sacOff   = plot(p.draw.gazeVelPlotAxes, NaN, NaN, ...
    'Color', [0.6000    0.3098         0]);
p.draw.plotObs.vThresh  = plot(p.draw.gazeVelPlotAxes, NaN, NaN, ...
    'Color', [0.8275    0.3725    0.7176]);
end

end