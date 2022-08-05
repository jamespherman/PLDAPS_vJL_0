function [hA, hL] = plotTrialTimingEvents(timing)
%
    
hA = gca;    
clr = lines(10);

xlim([timing.trialBegin timing.trialEnd]);

% plot flip times:
plot(timing.flipTime(1:end-1), diff(timing.flipTime));

yl = ylim;

%% mark timing of meaningful events

hL = [];    % handle for lines
iL = 1;     % itereator for lines
hL(iL) = line(repmat(timing.trialBegin,  [1,2]), yl, 'Color', clr(iL,:)); iL = iL+1;
hL(iL) = line(repmat(timing.cueOn,       [1,2]), yl, 'Color', clr(iL,:)); iL = iL+1;
hL(iL) = line(repmat(timing.cueOff,      [1,2]), yl, 'Color', clr(iL,:)); iL = iL+1;
hL(iL) = line(repmat(timing.cueChg,      [1,2]), yl, 'Color', clr(iL,:)); iL = iL+1;
hL(iL) = line(repmat(timing.foilChg,     [1,2]), yl, 'Color', clr(iL,:)); iL = iL+1;
hL(iL) = line(repmat(timing.trialEnd,    [1,2]), yl, 'Color', clr(iL,:)); iL = iL+1;
