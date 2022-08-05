function p               = plotWindowSetup(p)

%% Create plotting window(s)
% if there's already a window open, get rid of it:
if ~isempty(findobj('Name','OnlinePlotWindow'))
    delete(findobj('Name','OnlinePlotWindow'));
end

% make new plotting window for fixation / joystick press duration timing
% information:
p.draw.onlinePlotWindow         = ...
    figure(...
    'Position', [880 10 750 1200],...
    'Name','OnlinePlotWindow',...
    'NumberTitle','off',...
    'Color', 1 * [1 1 1],...
    'Visible','off',...
    'NextPlot','add');

% make new plotting window for eye position relative to fixation window:
p.draw.onlineEyePlotWindow         = ...
    figure(...
    'Position', [110 560 750 750],...
    'Name','OnlineEyePlotWindow',...
    'NumberTitle','off',...
    'Color', 1 * [1 1 1],...
    'Visible','off',...
    'NextPlot','add');

% If we're actually going to use the online plots, we need to create some
% axes to plot into in the online plot figure window, and graphics object
% handles for the plots themselves, and we should also show the plotting
% window:
if isfield(p.trVarsInit, 'wantOnlinePlots') && p.trVarsInit.wantOnlinePlots
    
    % make axes for plotting:
    p.draw.onlinePlotAxes = axes(...
        'Parent', p.draw.onlinePlotWindow, ...
        'Position', [0.1 0.1 0.875 0.875], ...
        'TickDir', 'Out', ...
        'LineWidth', 1, ...
        'XColor', [0 0 0], ...
        'YColor', [0 0 0], ...
        'NextPlot', 'add', ...
        'YDir', 'reverse' ...
        );
    
    % add X / Y axis labels:
    set(p.draw.onlinePlotAxes.XAxis.Label, ...
        'String', 'Fixation Hold Duration (s)', ...
        'FontSize', 16 ...
        );
    set(p.draw.onlinePlotAxes.YAxis.Label, ...
        'String', 'Trial Number / Index', ...
        'FontSize', 16 ...
        );
    
    % make plot objects: (1) green filled squares for "hits", (2) red Xs
    % for "misses", and (3) grey circles for non-starts:
    p.draw.onlinePlotObj(1) = plot(p.draw.onlinePlotAxes, NaN, NaN);
    p.draw.onlinePlotObj(2) = plot(p.draw.onlinePlotAxes, NaN, NaN);
    p.draw.onlinePlotObj(3) = plot(p.draw.onlinePlotAxes, NaN, NaN);
    
    % set plot object properties:
    set(p.draw.onlinePlotObj(1), 'LineStyle', 'none', 'Marker', 's', ...
        'MarkerFaceColor', [0.1 1 0.1], 'MarkerEdgeColor', 'None');
    set(p.draw.onlinePlotObj(2), 'LineStyle', 'none', 'Marker', 'x', ...
        'MarkerEdgeColor', [1 0.1 0.1], 'LineWidth', 2);
    set(p.draw.onlinePlotObj(3), 'LineStyle', 'none', 'Marker', 'o', ...
        'MarkerEdgeColor', 0.8 * [1 1 1], 'LineWidth', 1);
    
    % make axes for plotting eye position:
    p.draw.onlineEyePlotAxes = axes(...
        'Parent', p.draw.onlineEyePlotWindow, ...
        'Position', [0.1 0.1 0.875 0.875], ...
        'TickDir', 'Out', ...
        'LineWidth', 1, ...
        'XColor', [0 0 0], ...
        'YColor', [0 0 0], ...
        'NextPlot', 'add' ...
        );
    
    % add X / Y axis labels:
    set(p.draw.onlineEyePlotAxes.XAxis.Label, ...
        'String', 'Horizontal Position (deg)', ...
        'FontSize', 16 ...
        );
    set(p.draw.onlineEyePlotAxes.YAxis.Label, ...
        'String', 'Vertical Position (deg)', ...
        'FontSize', 16 ...
        );

    % make plot objects: (1) fixation window indicator (black); (2) eye
    % position before fixation acquisition (red); (3) eye position after
    % fixation acquisition (blue).
    p.draw.onlineEyePlotObj(1) = plot(p.draw.onlineEyePlotAxes, NaN, NaN);
    p.draw.onlineEyePlotObj(2) = plot(p.draw.onlineEyePlotAxes, NaN, NaN);
    p.draw.onlineEyePlotObj(3) = plot(p.draw.onlineEyePlotAxes, NaN, NaN);
    
    % set plot object properties:
    set(p.draw.onlineEyePlotObj(1), 'Color', [0 0 0], 'LineWidth', 1);
    set(p.draw.onlineEyePlotObj(2), 'Color', [1 0.1 0.1], 'LineWidth', 1);
    set(p.draw.onlineEyePlotObj(3), 'Color', [0.1 1 0.1], 'LineWidth', 1);
    
    set([p.draw.onlinePlotWindow; p.draw.onlineEyePlotWindow], ...
        'Visible', 'on');
end

%% Reposition GUI window
% allobj = findall(0);
% 
% for i = 1:length(allobj)
%     if isfield(get(allobj(i)),'Name')
%         if strfind(get(allobj(i),'Name'),'pldaps')
%             set(allobj(i),'Position',[280 7.58 133.8333   43.4167]);
%             break;
%         end
%     end
% end

%% close old windows
% oldWins = findobj('Type','figure','-not','Name','pldaps_gui2_beta (05nov2012)');
% if ~isempty(oldWins)
%     close(oldWins)
% end

end