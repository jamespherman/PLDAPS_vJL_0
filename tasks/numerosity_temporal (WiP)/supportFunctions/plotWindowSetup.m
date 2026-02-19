function p               = plotWindowSetup(p)

%{

% Currently working on this

%% Create plotting window(s)
% close open windows other than the gui:
figWins = findobj(0, 'Type', 'Figure');
figWins = figWins(~arrayfun(@(x)contains(x.Name, 'PLDAPS'), figWins));
if ~isempty(figWins)
    delete(figWins);
end

if isfield(p.trVarsInit, 'wantOnlinePlots') && p.trVarsInit.wantOnlinePlots

    p.draw.onlinePerfPlotWindow = figure(...
        'Position', [1883 8 667 667],...
        'Name','onlinePerfPlotWindow',...
        'NumberTitle','off',...
        'Color', [1 1 1],...
        'Visible','on',...
        'NextPlot','add');


end
%}
end


%{ 

% Code for original plotWindowSetup (from +pds)

%% Create plotting windows
if isempty(findobj('Name','OnlinePlotWindow'))
    p.draw.onlinePlotWindow         = figure('Position', [20 90 1600 1250],...
        'Name','OnlinePlotWindow',...
        'NumberTitle','off',...
        'Color',[0.8 0.8 0.8],...
        'Visible','on',...
        'NextPlot','add');
else
    p.draw.onlinePlotWindow         = findobj('Name','OnlinePlotWindow');
    set(0, 'CurrentFigure', p.draw.onlinePlotWindow);
end

% Show the online plot window.
set(p.draw.onlinePlotWindow,'Visible','off');

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



%}
