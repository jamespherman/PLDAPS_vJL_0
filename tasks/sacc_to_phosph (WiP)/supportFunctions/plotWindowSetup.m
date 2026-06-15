function p               = plotWindowSetup(p)
% p = plotWindowSetup(p)
% 
% Set up on-line plots


%% Close open windows other than the gui:
figWins = findobj(0, 'Type', 'Figure');
figWins = figWins(~arrayfun(@(x)contains(x.Name, 'PLDAPS'), figWins));
if ~isempty(figWins)
    delete(figWins);
end


%% Create plotting window(s)

% First check if we want online plots or not
if isfield(p.trVarsInit, 'wantOnlinePlots') && p.trVarsInit.wantOnlinePlots

    % Psychometric curve
    p.draw.onlinePlotPsychoWindow = figure(...
        'Name', 'On-line Psychometric Curve',...
        'Position', [1800 900 500 500]);

    p.draw.onlinePlotPsychoAxes = axes(p.draw.onlinePlotPsychoWindow);
    title(p.draw.onlinePlotPsychoAxes, 'On-line Psychometric Curve');
    xlabel(p.draw.onlinePlotPsychoAxes, 'Current amplitude (uA)');
    ylabel(p.draw.onlinePlotPsychoAxes, 'Performance');
    
    p.draw.onlinePlotPsychoAxes.XLim = [-1, 211];
    p.draw.onlinePlotPsychoAxes.YLim = [0, 1];

    p.draw.onlinePlotPsychoData = line(p.draw.onlinePlotPsychoAxes);
    p.draw.onlinePlotPsychoData.XData = p.trVarsInit.ampVals;
    p.draw.onlinePlotPsychoData.YData = zeros(1, numel(p.trVarsInit.ampVals));
    p.draw.onlinePlotPsychoData.Color = [0 0 1];
    p.draw.onlinePlotPsychoData.Marker = '.';
    p.draw.onlinePlotPsychoData.LineStyle = 'None';

    p.draw.onlinePlotPsychoFARate = yline(p.draw.onlinePlotPsychoAxes, 0);
    p.draw.onlinePlotPsychoFARate.Color = [1 0 0];
    p.draw.onlinePlotPsychoFARate.LineStyle = ':';

    p.draw.onlinePlotPsychoC50 = yline(p.draw.onlinePlotPsychoAxes, 0.5);
    p.draw.onlinePlotPsychoC50.Color = [0 1 0];
    p.draw.onlinePlotPsychoC50.LineStyle = ':';

    legend(p.draw.onlinePlotPsychoAxes, 'Data', 'C50 Threshold', 'FA Rate');


end

end
