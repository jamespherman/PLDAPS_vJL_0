function [hFig] = mkfig_trialTimingEvents(p, trNumbers)
%   [hF] = mkfig_trialTimingEvents(p, trialNumbers)
%
% INPUT:
%   p           - standard pldaps 'p' struct
%   trNumbers   - vectro of trial numbers you wish to plot eg [2 5 17]. if
%                 left empty, function plots all trials, up to
%                 'maxTrialsToPlot', defined within function.
%
% OUTPUT:
%   hF          - handle to figure

% if trNumbers not specified, plot all trials, up to maxTrialsToPlot:
if ~exist('trialNumbers', 'var')
    maxTrialsToPlot = 6;
    trNumbers       = 1:min([maxTrialsToPlot, numel(p.trData)]);
end


nTrials = numel(trNumbers);

hFig = figure;

for iTr = 1:nTrials
    subplot(nTrials, 1, iTr); hold all;
    title(['trial - ', num2str(trNumbers(iTr))]);
    [hA, hL] = plot_trialTimingEvents(p.trData(iTr).timing);
end
ylabel('time from trialStart(s)')
xlabel('frame #')
legend(hL, {'begin', 'cueOn', 'cueOff', 'cueChg', 'foilChg', 'end'})


