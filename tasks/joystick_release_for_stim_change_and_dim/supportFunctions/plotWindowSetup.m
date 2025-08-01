function p               = plotWindowSetup(p)

%% Create plotting window(s)
% close open windows other than the gui:
figWins = findobj(0, 'Type', 'Figure');
figWins = figWins(~arrayfun(@(x)contains(x.Name, 'PLDAPS'), figWins));
if ~isempty(figWins)
    delete(figWins);
end

if isfield(p.trVarsInit, 'wantOnlinePlots') && p.trVarsInit.wantOnlinePlots
    
% make new plotting PSTHs
% p.draw.onlinePlotWindow         = ...
%     figure(...
%     'Position', [880 8 1000 1314],...
%     'Name','Online PSTHs',...
%     'NumberTitle','off',...
%     'Color', 1 * [1 1 1],...
%     'Visible','on',...
%     'NextPlot','add');

% make new plotting window for plotting a running estimate of correct
% performance
p.draw.onlinePerfPlotWindow         = ...
    figure(...
    'Position', [1883 8 667 1314],...
    'Name','OnlinePerfPlotWindow',...
    'NumberTitle','off',...
    'Color', 1 * [1 1 1],...
    'Visible','on',...
    'NextPlot','add');

% % If we're actually going to use the online plots, we need to create some
% % axes to plot into in the online plot figure window, and graphics object
% % handles for the plots themselves, and we should also show the plotting
% % window:
% 
%     % x labels for PSTHs:
%     psthXLabel{1} = 'Time from Fixation Onset (s)';
%     psthXLabel{2} = 'Time from Stimulus Onset (s)';
%     psthXLabel{3} = 'Time from Stimulus Change (s)';
%     psthXLabel{4} = 'Time from Reward Onset (s)';
%     psthXLabel{5} = 'Time from Free Reward Onset (s)';
% 
%     % make axes for plotting PSTHs; one column of plots for free reward,
%     % reward, single stimulus change, single stimulus onset, fixation
%     % onset; a second column for stimulus change and stimulus onset for
%     % multiple stimulus trials.
%     for i = 1:5
%         p.draw.psthPlotAxes(i) = axes(...
%             'Parent', p.draw.onlinePlotWindow, ...
%             'Position', [0.07 0.05 + (i-1)*0.19 0.43 0.15], ...
%             'TickDir', 'Out', ...
%             'LineWidth', 1, ...
%             'XColor', [0 0 0], ...
%             'YColor', [0 0 0], ...
%             'NextPlot', 'add', ...
%             'Visible', 'on');
%         xlabel(p.draw.psthPlotAxes(i), psthXLabel{i});
%     end
%     p.draw.psthPlotAxes(6) = axes(...
%         'Parent', p.draw.onlinePlotWindow, ...
%         'Position', [0.52 0.24 0.43 0.15], ...
%         'TickDir', 'Out', ...
%         'LineWidth', 1, ...
%         'XColor', [0 0 0], ...
%         'YColor', [0 0 0], ...
%         'YAxisLocation', 'right', ...
%         'NextPlot', 'add', ...
%         'Visible', 'on');
%     xlabel(p.draw.psthPlotAxes(6), psthXLabel{2});
%     p.draw.psthPlotAxes(7) = axes(...
%         'Parent', p.draw.onlinePlotWindow, ...
%         'Position', [0.52 0.43 0.43 0.15], ...
%         'TickDir', 'Out', ...
%         'LineWidth', 1, ...
%         'XColor', [0 0 0], ...
%         'YColor', [0 0 0], ...
%         'YAxisLocation', 'right', ...
%         'NextPlot', 'add', ...
%         'Visible', 'on');
%     xlabel(p.draw.psthPlotAxes(7), psthXLabel{3});
% 
%     % Make plot objects for several trial PSTHs:
%     % (1) Fixation onset
%     % (2) Single stimulus onset (location 1)
%     % (3) Single stimulus onset (location 2)
%     % (4) Single stimulus onset (location 3)
%     % (5) Single stimulus onset (location 4)
%     % (6) Single stimulus change (location 1)
%     % (7) Single stimulus change (location 2)
%     % (8) Single stimulus change (location 3)
%     % (9) Single stimulus change (location 4)
%     % (10) Reward
%     % (11) Free reward
%     % (12) No free reward
%     % (13) Multiple stimulus onset (location 1)
%     % (14) Multiple stimulus onset (location 2)
%     % (15) Multiple stimulus onset (location 3)
%     % (16) Multiple stimulus onset (location 4)
%     % (17) Multiple stimulus change (location 1)
%     % (18) Multiple stimulus change (location 2)
%     % (19) Multiple stimulus change (location 3)
%     % (20) Multiple stimulus change (location 4)
%     p.draw.onlinePlotObj(1) = plot(p.draw.psthPlotAxes(1), NaN, NaN);
%     p.draw.onlinePlotObj(2) = plot(p.draw.psthPlotAxes(2), NaN, NaN);
%     p.draw.onlinePlotObj(3) = plot(p.draw.psthPlotAxes(2), NaN, NaN);
%     p.draw.onlinePlotObj(4) = plot(p.draw.psthPlotAxes(2), NaN, NaN);
%     p.draw.onlinePlotObj(5) = plot(p.draw.psthPlotAxes(2), NaN, NaN);
%     p.draw.onlinePlotObj(6) = plot(p.draw.psthPlotAxes(3), NaN, NaN);
%     p.draw.onlinePlotObj(7) = plot(p.draw.psthPlotAxes(3), NaN, NaN);
%     p.draw.onlinePlotObj(8) = plot(p.draw.psthPlotAxes(3), NaN, NaN);
%     p.draw.onlinePlotObj(9) = plot(p.draw.psthPlotAxes(3), NaN, NaN);
%     p.draw.onlinePlotObj(10) = plot(p.draw.psthPlotAxes(4), NaN, NaN);
%     p.draw.onlinePlotObj(11) = plot(p.draw.psthPlotAxes(5), NaN, NaN);
%     p.draw.onlinePlotObj(12) = plot(p.draw.psthPlotAxes(5), NaN, NaN);
%     p.draw.onlinePlotObj(13) = plot(p.draw.psthPlotAxes(6), NaN, NaN);
%     p.draw.onlinePlotObj(14) = plot(p.draw.psthPlotAxes(6), NaN, NaN);
%     p.draw.onlinePlotObj(15) = plot(p.draw.psthPlotAxes(6), NaN, NaN);
%     p.draw.onlinePlotObj(16) = plot(p.draw.psthPlotAxes(6), NaN, NaN);
%     p.draw.onlinePlotObj(17) = plot(p.draw.psthPlotAxes(7), NaN, NaN);
%     p.draw.onlinePlotObj(18) = plot(p.draw.psthPlotAxes(7), NaN, NaN);
%     p.draw.onlinePlotObj(19) = plot(p.draw.psthPlotAxes(7), NaN, NaN);
%     p.draw.onlinePlotObj(20) = plot(p.draw.psthPlotAxes(7), NaN, NaN);
% 
%     % add fields to the "UserData" field of each plot object to count
%     % numbers of trials and to store spikeTimes:
%     for i = 1:length(p.draw.onlinePlotObj)
%         p.draw.onlinePlotObj(i).UserData.trialCount = 0;
%         p.draw.onlinePlotObj(i).UserData.spTimes = [];
%     end
% 
%     % colors for plots:
%     palette = parula(16);
% 
%     % (1) Fixation onset
%     set(p.draw.onlinePlotObj(1), 'Color', 'k', 'Tag', 'Fixation Onset')
% 
%     % (2) Stimulus onset (location 1)
%     set(p.draw.onlinePlotObj(2), 'Color', palette(1, :), ...
%         'Tag', 'Stim Onset Loc 1');
% 
%     % (3) Stimulus onset (location 2)
%     set(p.draw.onlinePlotObj(3), 'Color', palette(6, :), ...
%         'Tag', 'Stim Onset Loc 2');
% 
%     % (4) Stimulus onset (location 3)
%     set(p.draw.onlinePlotObj(4), 'Color', palette(10, :), ...
%         'Tag', 'Stim Onset Loc 3');
% 
%     % (5) Stimulus onset (location 4)
%     set(p.draw.onlinePlotObj(5), 'Color', palette(14, :), ...
%         'Tag', 'Stim Onset Loc 4');
% 
%     % (6) Stimulus change (location 1)
%     set(p.draw.onlinePlotObj(6), 'Color', palette(1, :), ...
%         'Tag', 'Stim Change Loc 4');
% 
%     % (7) Stimulus onset (location 2)
%     set(p.draw.onlinePlotObj(7), 'Color', palette(6, :), ...
%         'Tag', 'Stim Change Loc 2');
% 
%     % (8) Stimulus onset (location 3)
%     set(p.draw.onlinePlotObj(8), 'Color', palette(10, :), ...
%         'Tag', 'Stim Change Loc 3');
% 
%     % (9) Stimulus onset (location 4)
%     set(p.draw.onlinePlotObj(9), 'Color', palette(14, :), ...
%         'Tag', 'Stim Change Loc 4');
% 
%     % (10) Reward
%     set(p.draw.onlinePlotObj(10), 'Color', 'k', 'Tag', 'Reward')
% 
%     % (11) Free reward
%     set(p.draw.onlinePlotObj(11), 'Color', 'r', 'Tag', 'Free Reward');
% 
%     % (12) No Free reward
%     set(p.draw.onlinePlotObj(12), 'Color', 'k', 'Tag', 'No Free Reward');
% 
%     % (13) Multiple stimulus onset (location 1)
%     set(p.draw.onlinePlotObj(13), 'Color', palette(1, :), ...
%         'Tag', 'Stim Onset Loc 1');
% 
%     % (14) Multiple stimulus onset (location 2)
%     set(p.draw.onlinePlotObj(14), 'Color', palette(6, :), ...
%         'Tag', 'Stim Onset Loc 2');
% 
%     % (15) Multiple stimulus onset (location 3)
%     set(p.draw.onlinePlotObj(15), 'Color', palette(10, :), ...
%         'Tag', 'Stim Onset Loc 3');
% 
%     % (16) Multiple stimulus onset (location 4)
%     set(p.draw.onlinePlotObj(16), 'Color', palette(14, :), ...
%         'Tag', 'Stim Onset Loc 4');
% 
%     % (17) Multiple stimulus change (location 1)
%     set(p.draw.onlinePlotObj(17), 'Color', palette(1, :), ...
%         'Tag', 'Stim Change Loc 4');
% 
%     % (18) Multiple stimulus onset (location 2)
%     set(p.draw.onlinePlotObj(18), 'Color', palette(6, :), ...
%         'Tag', 'Stim Change Loc 2');
% 
%     % (19) Multiple stimulus onset (location 3)
%     set(p.draw.onlinePlotObj(19), 'Color', palette(10, :), ...
%         'Tag', 'Stim Change Loc 3');
% 
%     % (20) Multiple stimulus onset (location 4)
%     set(p.draw.onlinePlotObj(20), 'Color', palette(14, :), ...
%         'Tag', 'Stim Change Loc 4');
% 
%     % add legend objects to the PSTH axes, also store a count of the number
%     % of children for each set of axes so we don't have to count later:
%     for i = 1:length(p.draw.psthPlotAxes)
% 
%         % add legend object
%         p.draw.onlinePlotLegend(i) = legend(...
%             p.draw.psthPlotAxes(i), 'boxoff');
% 
%         % store count of children:
%         p.draw.psthPlotAxes(i).UserData = ...
%             length(p.draw.psthPlotAxes(i).Children);
%     end
% 
%     % When we update the online plots, we're going to update the legend
%     % entries to reflect the trial count for each trace. The easist
%     % way to do this is to store strings with everything except the trial
%     % count in the UserData field of the legend object itself. Store those
%     % strings there now. NOTE: because axes store children in "reverse"
%     % order (last added plot is first in list), we have to reverse order
%     % the strings here to align with the ordering in that list so we can
%     % just loop over each axes children and have a correspondingly ordered
%     % list of the appropriate "base string" for the legend entry stored in
%     % "UserData"
%     p.draw.onlinePlotLegend(1).UserData = {'Fixation Onset (XX)'};
%     p.draw.onlinePlotLegend(2).UserData = {'Stim Loc 4 (XX)', ...
%         'Stim Loc 3 (XX)', 'Stim Loc 2 (XX)', 'Stim Loc 1 (XX)'};
%     p.draw.onlinePlotLegend(3).UserData = {'Stim Loc 4 (XX)', ...
%         'Stim Loc 3 (XX)', 'Stim Loc 2 (XX)', 'Stim Loc 1 (XX)'};
%     p.draw.onlinePlotLegend(4).UserData = {'Reward (XX)'};
%     p.draw.onlinePlotLegend(5).UserData = {'No Free Reward (XX)', ...
%         'Free Reward (XX)'};
%     p.draw.onlinePlotLegend(6).UserData = {'Stim Loc 4 (XX)', ...
%         'Stim Loc 3 (XX)', 'Stim Loc 2 (XX)', 'Stim Loc 1 (XX)'};
%     p.draw.onlinePlotLegend(7).UserData = {'Stim Loc 4 (XX)', ...
%         'Stim Loc 3 (XX)', 'Stim Loc 2 (XX)', 'Stim Loc 1 (XX)'};
% 
%     % make axes for plotting aggregate performance / reaction time
%     % data:
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
% 
%     % make plot objects for aggregate performance / reaction time data.
%     % Note, here we make one "fill" object (the "bar" part of the error
%     % bar) and one "line" object (the mean / median line indicator part of
%     % the errorbar) per axis (performance / RT). In "updateOnlinePlots we
%     % check how many we need in total and we add new ones as needed.
%     p.draw.onlinePerfFillObj(1) = fill(p.draw.onlinePerfPlotAxes, ...
%         NaN(1, 5), NaN(1, 5), 0.7*[1 1 1]);
%     p.draw.onlineRtFillObj(1) = fill(p.draw.onlineRtPlotAxes, ...
%         NaN(1, 5), NaN(1, 5), 0.7*[1 1 1]);
%     set([p.draw.onlinePerfFillObj(1), p.draw.onlineRtFillObj(1)], ...
%         'EdgeColor', 'None');
% 
%     p.draw.onlinePerfPlotObj(1) = plot(p.draw.onlinePerfPlotAxes, ...
%         NaN, NaN, 'Color', [0 0 0], 'LineWidth', 2);
%     p.draw.onlineRtPlotObj(1)   = plot(p.draw.onlineRtPlotAxes, ...
%         NaN, NaN, 'Color', [0 0 0], 'LineWidth', 2);
% 
%     % add X / Y axis labels:
%     set(p.draw.onlinePerfPlotAxes.XAxis.Label, ...
%         'String', 'Trial Condition', ...
%         'FontSize', 16 ...
%         );
%     set(p.draw.onlinePerfPlotAxes.YAxis.Label, ...
%         'String', 'Proportion Correct', ...
%         'FontSize', 16 ...
%         );
%     set(p.draw.onlineRtPlotAxes.YAxis.Label, ...
%         'String', 'Median Reaction Time (seconds)', ...
%         'FontSize', 16 ...
%         );
% 
% 
% 
%     % Psychometric plot
% 
    if contains(p.init.exptType, 'psycho')
        % make new plotting window for psychometric function estimation plot
        p.draw.OnlinePsychoPlotWindow         = ...
            figure(...
            'Position', [1883 8 667 667],...
            'Name','OnlinePsychoPlotWindow',...
            'NumberTitle','off',...
            'Color', 1 * [1 1 1],...
            'Visible','on',...
            'NextPlot','add');

        % create psychometric plot objects


        % make accumulator variables for orient delta plot
        p.status.orientDelta = cell(4, 1);
        p.status.orientDelta{1} = struct('hitCount', 0, 'totalCount', 0);
        p.status.orientDelta{2} = struct('hitCount', 0, 'totalCount', 0);
        p.status.orientDelta{3} = struct('hitCount', 0, 'totalCount', 0);
        p.status.orientDelta{4} = struct('hitCount', 0, 'totalCount', 0);

        p.draw.onlinePsychoPerfPlotAxes = axes(...
            'Parent', p.draw.OnlinePsychoPlotWindow, ...
            'Position', [0.1 0.1 0.875 0.875], ...
            'TickDir', 'Out', ...
            'LineWidth', 1, ...
            'XColor', [0 0 0], ...
            'YColor', [0 0 0], ...
            'NextPlot', 'add');

        xlabel(p.draw.onlinePsychoPerfPlotAxes, 'Orient Delta Value', ...
            'FontSize', 16);
        ylabel(p.draw.onlinePsychoPerfPlotAxes, 'Proportion Correct', ...
            'FontSize', 16);

        % make plot objects for psycho performance data
        for i = 1:4

            centerX = 1 + (i-1);
            xFill = centerX + 0.25 * [-1 1 1 -1 -1];
            yFill = [0, 0, 1, 1, 0]; % placeholder yFill values

            % Create the fill object for the current box plot
            p.draw.onlinePsychoPerfFillObj(i) = ...
                fill(p.draw.onlinePsychoPerfPlotAxes, ...
                xFill, yFill, 0.7*[1 1 1], 'EdgeColor', 'None');
            xPlot = [centerX, centerX];
            yPlot = [0.5, 0.5]; % placeholder

            % create the plot object for the current box plot
            p.draw.onlinePsychoPerfPlotObj(i) = ...
                plot(p.draw.onlinePsychoPerfPlotAxes, xPlot, yPlot, ...
                'Color', [0 0 0], 'LineWidth', 2);
        end

    end


    % Confusion Matrix Plot

    % Confusion Matrix Plot
    p.draw.onlineConfusionPlotWindow = figure(...
        'Position', [1883 8 667 667],...
        'Name','onlineConfusionPlotWindow',...
        'NumberTitle','off',...
        'Color', [1 1 1],...
        'Visible','on',...
        'NextPlot','add');

    % Create axes for confusion matrix
    p.draw.onlineConfusionPlotAxes = axes(...
        'Parent', p.draw.onlineConfusionPlotWindow, ...
        'Position', [0.1 0.1 0.875 0.875], ...
        'TickDir', 'Out', ...
        'LineWidth', 1, ...
        'XColor', [0 0 0], ...
        'YColor', [0 0 0], ...
        'NextPlot', 'add');

    xlabel(p.draw.onlineConfusionPlotAxes, ...
        'Confusion Matrix Category', 'FontSize', 16);
    ylabel(p.draw.onlineConfusionPlotAxes, 'Rate', 'FontSize', 16);

    % we're going to plot 6 categories of behavioral response:
    % 1 - single stimulus hits
    % 2 - single stimulus FAs
    % 3 - single stimulus OTHER (non starts / joybreaks / etc).
    % 4 - multi stimulus hits
    % 5 - multi stimulus FAs
    % 6 - multi stimulus OTHER (non starts / joybreaks / etc).
    tickLabels = {'Sgl. Hits', 'Sgl. FAs', 'Sgl. Other', ...
        'Multi. Hits', 'Multi. FAs', 'Multi. Other'};
    nObj = length(tickLabels);

    % Make fill objects
    for i = 1:nObj
        centerX = 1 + (i-1);
        xFill = centerX + 0.25*[-1 1 1 -1 -1];
        yFill = [0, 0, 1, 1, 0]; % placeholder
        p.draw.onlineConfusionFillObj(i) = ...
            fill(p.draw.onlineConfusionPlotAxes, xFill, yFill, 0.7*[1 1 1], ...
            'EdgeColor', 'None');
    end

    % Make plot objects
    for i = 1:nObj
        centerY = 0.5;
        xMin = 1 + (i-1) - 0.25;
        xMax = 1 + (i-1) + 0.25;
        xPlot = [xMin, xMax];
        yPlot = [centerY, centerY];
        p.draw.onlineConfusionPlotObj(i) = ...
            plot(p.draw.onlineConfusionPlotAxes, ...
            xPlot, yPlot, 'Color', [0 0 0], 'LineWidth', 2, 'Visible', 'on');
    end

    % Set x-tick labels
    set(p.draw.onlineConfusionPlotAxes, 'XTick', 1:nObj, ...
        'XTickLabel', tickLabels);

    % Cued vs. Uncued Performance Plot
    p.draw.onlineCuedPlotWindow = figure(...
        'Position', [1200 8 667 667],... % Adjusted position to not overlap
        'Name','onlineCuedPerfPlotWindow',...
        'NumberTitle','off',...
        'Color', [1 1 1],...
        'Visible','on',...
        'NextPlot','add');
        
    % Create axes for the cued performance plot
    p.draw.onlineCuedPlotAxes = axes(...
        'Parent', p.draw.onlineCuedPlotWindow, ...
        'Position', [0.1 0.1 0.875 0.875], ...
        'TickDir', 'Out', ...
        'LineWidth', 1, ...
        'XColor', [0 0 0], ...
        'YColor', [0 0 0], ...
        'NextPlot', 'add');
    xlabel(p.draw.onlineCuedPlotAxes, 'Condition', 'FontSize', 16);
    ylabel(p.draw.onlineCuedPlotAxes, 'Hit Rate', 'FontSize', 16);

    % We will plot 6 categories:
    % 1. Overall Cued Hits
    % 2. Overall Uncued Hits
    % 3. Loc 1 Cued Hits
    % 4. Loc 1 Uncued Hits
    % 5. Loc 3 Cued Hits
    % 6. Loc 3 Uncued Hits
    tickLabels = {'Cued', 'Uncued', 'Cued L1', 'Uncued L1', 'Cued L3', 'Uncued L3'};
    nObj = length(tickLabels);
    
    % Define colors for cued and uncued bars
    cuedColor = [0, 0.4470, 0.7410]; % A nice blue
    uncuedColor = 0.7 * [1, 1, 1];   % A light gray

    % Make placeholder fill and plot objects
    for i = 1:nObj
        centerX = i;
        xFill = centerX + 0.3 * [-1, 1, 1, -1, -1];
        yFill = [0, 0, 1, 1, 0]; % Placeholder Y values

        % Alternate colors for cued vs uncued bars
        if mod(i, 2) == 1 % Odd numbers are cued
            barColor = cuedColor;
        else % Even numbers are uncued
            barColor = uncuedColor;
        end

        p.draw.onlineCuedFillObj(i) = ...
            fill(p.draw.onlineCuedPlotAxes, xFill, yFill, barColor, ...
            'EdgeColor', 'None');
            
        centerY = 0.5; % Placeholder Y value
        xPlot = [centerX - 0.3, centerX + 0.3];
        yPlot = [centerY, centerY];
        
        p.draw.onlineCuedPlotObj(i) = ...
            plot(p.draw.onlineCuedPlotAxes, xPlot, yPlot, ...
            'Color', [0, 0, 0], 'LineWidth', 2, 'Visible', 'on');
    end

    % Set x-tick labels to be descriptive
    set(p.draw.onlineCuedPlotAxes, 'XTick', 1:nObj, 'XTickLabel', tickLabels);
    % Rotate labels for better readability if needed
    xtickangle(p.draw.onlineCuedPlotAxes, 45);
    
    % Add a title
    title(p.draw.onlineCuedPlotAxes, 'Cued vs. Uncued Hit Rate');

    % Learning Curve Plot

%     p.draw.onlineLearningCurveWindow = figure(...
%         'Position', [1883 8 667 667],...
%         'Name','onlineLearningCurveWindow',...
%         'NumberTitle','off',...
%         'Color', [1 1 1],...
%         'Visible','on',...
%         'NextPlot','add');
% 
%     % Create axes for the learning curve plot
%     p.draw.onlineLearningCurveAxes = axes('Parent', ...
%         p.draw.onlineLearningCurveWindow);
%     xlabel(p.draw.onlineLearningCurveAxes, 'Block Number');
%     ylabel(p.draw.onlineLearningCurveAxes, 'Accuracy');
%     title(p.draw.onlineLearningCurveAxes, 'Learning Curve');
%     grid(p.draw.onlineLearningCurveAxes, 'on');
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