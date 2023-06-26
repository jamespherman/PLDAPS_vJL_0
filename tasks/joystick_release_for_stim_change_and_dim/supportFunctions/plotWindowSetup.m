function p               = plotWindowSetup(p)

%% Create plotting window(s)
% close open windows other than the gui:
figWins = findobj(0, 'Type', 'Figure');
figWins = figWins(~arrayfun(@(x)contains(x.Name, 'PLDAPS'), figWins));
if ~isempty(figWins)
    delete(figWins);
end

% make new plotting PSTHs
p.draw.onlinePlotWindow         = ...
    figure(...
    'Position', [880 10 750 1200],...
    'Name','Online PSTHs',...
    'NumberTitle','off',...
    'Color', 1 * [1 1 1],...
    'Visible','on',...
    'NextPlot','add');

% make new plotting window for plotting a running estimate of correct
% performance
p.draw.onlinePerfPlotWindow         = ...
    figure(...
    'Position', [1750 560 800 1200],...
    'Name','OnlinePerfPlotWindow',...
    'NumberTitle','off',...
    'Color', 1 * [1 1 1],...
    'Visible','on',...
    'NextPlot','add');

% If we're actually going to use the online plots, we need to create some
% axes to plot into in the online plot figure window, and graphics object
% handles for the plots themselves, and we should also show the plotting
% window:
if isfield(p.trVarsInit, 'wantOnlinePlots') && p.trVarsInit.wantOnlinePlots
    
    % x labels for PSTHs:
    psthXLabel{1} = 'Time from Fixation Onset (s)';
    psthXLabel{2} = 'Time from Stimulus Onset (s)';
    psthXLabel{3} = 'Time from Stimulus Change (s)';
    psthXLabel{4} = 'Time from Reward Onset (s)';
    psthXLabel{5} = 'Time from Free Reward Onset (s)';

    % make axes for plotting PSTHs
    for i = 1:5
        p.draw.psthPlotAxes(i) = axes(...
            'Parent', p.draw.onlinePlotWindow, ...
            'Position', [0.1 0.05 + (i-1)*0.19 0.875 0.15], ...
            'TickDir', 'Out', ...
            'LineWidth', 1, ...
            'XColor', [0 0 0], ...
            'YColor', [0 0 0], ...
            'NextPlot', 'add', ...
            'Visible', 'on');
        xlabel(p.draw.psthPlotAxes(i), psthXLabel{i});
    end
    
    % Make plot objects for several trial PSTHs:
    % (1) Fixation onset
    % (2) Stimulus onset (location 1)
    % (3) Stimulus onset (location 2)
    % (4) stimulus onset (location 3)
    % (5) Stimulus onset (location 4)
    % (6) Stimulus change (location 1)
    % (7) Stimulus change (location 2)
    % (8) Stimulus change (location 3)
    % (9) Stimulus change (location 4)
    % (10) Reward
    % (11) Free reward
    % (12) No free reward
    p.draw.onlinePlotObj(1) = plot(p.draw.psthPlotAxes(1), NaN, NaN);
    p.draw.onlinePlotObj(2) = plot(p.draw.psthPlotAxes(2), NaN, NaN);
    p.draw.onlinePlotObj(3) = plot(p.draw.psthPlotAxes(2), NaN, NaN);
    p.draw.onlinePlotObj(4) = plot(p.draw.psthPlotAxes(2), NaN, NaN);
    p.draw.onlinePlotObj(5) = plot(p.draw.psthPlotAxes(2), NaN, NaN);
    p.draw.onlinePlotObj(6) = plot(p.draw.psthPlotAxes(3), NaN, NaN);
    p.draw.onlinePlotObj(7) = plot(p.draw.psthPlotAxes(3), NaN, NaN);
    p.draw.onlinePlotObj(8) = plot(p.draw.psthPlotAxes(3), NaN, NaN);
    p.draw.onlinePlotObj(9) = plot(p.draw.psthPlotAxes(3), NaN, NaN);
    p.draw.onlinePlotObj(10) = plot(p.draw.psthPlotAxes(4), NaN, NaN);
    p.draw.onlinePlotObj(11) = plot(p.draw.psthPlotAxes(5), NaN, NaN);
    p.draw.onlinePlotObj(12) = plot(p.draw.psthPlotAxes(5), NaN, NaN);

    % add fields to the "UserData" field of each plot object to count
    % numbers of trials and to store spikeTimes:
    for i = 1:length(p.draw.onlinePlotObj)
        p.draw.onlinePlotObj(i).UserData.trialCount = 0;
        p.draw.onlinePlotObj(i).UserData.spTimes = [];
    end

    % colors for plots:
    palette = parula(16);
    
    % (1) Fixation onset
    set(p.draw.onlinePlotObj(1), 'Color', 'k')

    % (2) Stimulus onset (location 1)
    set(p.draw.onlinePlotObj(2), 'Color', palette(1, :));

    % (3) Stimulus onset (location 2)
    set(p.draw.onlinePlotObj(3), 'Color', palette(6, :));

    % (4) Stimulus onset (location 3)
    set(p.draw.onlinePlotObj(4), 'Color', palette(10, :));

    % (5) Stimulus onset (location 4)
    set(p.draw.onlinePlotObj(5), 'Color', palette(14, :));

    % (6) Stimulus change (location 1)
    set(p.draw.onlinePlotObj(6), 'Color', palette(1, :));

    % (7) Stimulus onset (location 2)
    set(p.draw.onlinePlotObj(7), 'Color', palette(6, :));

    % (8) Stimulus onset (location 3)
    set(p.draw.onlinePlotObj(8), 'Color', palette(10, :));

    % (9) Stimulus onset (location 4)
    set(p.draw.onlinePlotObj(9), 'Color', palette(14, :));
    
    % (10) Reward
    set(p.draw.onlinePlotObj(10), 'Color', 'k');

    % (11) Free reward
    set(p.draw.onlinePlotObj(11), 'Color', 'r');

    % (11) Free reward
    set(p.draw.onlinePlotObj(12), 'Color', 'k');

    % make axes for plotting aggregate performance / reaction time 
    % data:
    p.draw.onlinePerfPlotAxes = axes(...
        'Parent', p.draw.onlinePerfPlotWindow, ...
        'Position', [0.1 0.1 0.875 0.375], ...
        'TickDir', 'Out', ...
        'LineWidth', 1, ...
        'XColor', [0 0 0], ...
        'YColor', [0 0 0], ...
        'NextPlot', 'add');
    p.draw.onlineRtPlotAxes = axes(...
        'Parent', p.draw.onlinePerfPlotWindow, ...
        'Position', [0.1 0.6 0.875 0.375], ...
        'TickDir', 'Out', ...
        'LineWidth', 1, ...
        'XColor', [0 0 0], ...
        'YColor', [0 0 0], ...
        'NextPlot', 'add');

    % make plot objects for aggregate performance / reaction time data.
    % Note, here we make one "fill" object (the "bar" part of the error
    % bar) and one "line" object (the mean / median line indicator part of
    % the errorbar) per axis (performance / RT). In "updateOnlinePlots we
    % check how many we need in total and we add new ones as needed.
    p.draw.onlinePerfFillObj(1) = fill(p.draw.onlinePerfPlotAxes, ...
        NaN(1, 5), NaN(1, 5), 0.7*[1 1 1]);
    p.draw.onlineRtFillObj(1) = fill(p.draw.onlineRtPlotAxes, ...
        NaN(1, 5), NaN(1, 5), 0.7*[1 1 1]);
    set([p.draw.onlinePerfFillObj(1), p.draw.onlineRtFillObj(1)], ...
        'EdgeColor', 'None');

    p.draw.onlinePerfPlotObj(1) = plot(p.draw.onlinePerfPlotAxes, ...
        NaN, NaN, 'Color', [0 0 0], 'LineWidth', 2);
    p.draw.onlineRtPlotObj(1)   = plot(p.draw.onlineRtPlotAxes, ...
        NaN, NaN, 'Color', [0 0 0], 'LineWidth', 2);

    % add X / Y axis labels:
    set(p.draw.onlinePerfPlotAxes.XAxis.Label, ...
        'String', 'Trial Condition', ...
        'FontSize', 16 ...
        );
    set(p.draw.onlinePerfPlotAxes.YAxis.Label, ...
        'String', 'Proportion Correct', ...
        'FontSize', 16 ...
        );
    set(p.draw.onlineRtPlotAxes.YAxis.Label, ...
        'String', 'Median Reaction Time (seconds)', ...
        'FontSize', 16 ...
        );
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