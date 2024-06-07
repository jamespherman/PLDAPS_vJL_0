%%
% clear workspace and close open figure windows

% load data
load(['/home/herman_lab/OneDrive/Behavioral Data/' ...
    '20240606_t1004_joystick_release_for_stim_change_and_dim.mat'])

% close open figure windows AGAIN

%% all the stuff after loading data:

% a function to get timing data from the "timing" substruct:
getTime = @(x)arrayfun(@(y)y.timing.(x), trData);

% define variables of interest:
trialEndState   = [trData.trialEndState]';
isStimChangeTrial = [trVars.isStimChangeTrial]';
isNoChangeTrial = [trVars.isNoChangeTrial]';
joyRelTime      = getTime('joyRelease');
stimOnTime      = getTime('stimOn');
fixAqTime       = getTime('fixAq');
fixOnTime       = getTime('fixOn');
trialEndTime    = getTime('trialEnd');
stimChgTime     = getTime('stimChg');
noChgTime       = getTime('noChg');
fix2StimOff     = [trVars.fix2StimOffIntvl];
planChgTime     = [trVars.stimChangeTime];
stim2ChgTime    = [trVars.stim2ChgIntvl];
cueChgFa        = trialEndState == state.fa & isStimChangeTrial;
noChgFa         = trialEndState == state.fa & isNoChangeTrial;

% plot window
figure('Color', [1 1 1])

% "scatter" plot axes:
ax(1) = subplot(4,1,1:3);
hold on
plot(stimOnTime(cueChgFa) - fixAqTime(cueChgFa), 1:nnz(cueChgFa), ...
    'o', 'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'w')
plot(joyRelTime(cueChgFa) - fixAqTime(cueChgFa), 1:nnz(cueChgFa), ...
    'o', 'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'w')
plot(planChgTime(cueChgFa), 1:nnz(cueChgFa), ...
    'd', 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'w')
plot(fix2StimOff(cueChgFa), 1:nnz(cueChgFa), ...
    's', 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'w')
plot([1 1] * (mean(stimOnTime(cueChgFa) - fixAqTime(cueChgFa)) + ...
    mean(stim2ChgTime)), ...
    [1 nnz(cueChgFa)], 'Color', 0.65 * [1 1 1])
plot([1 1] * (mean(stimOnTime(cueChgFa) - fixAqTime(cueChgFa)) + ...
    mean(stim2ChgTime) + trVars(1).chgWinDur), ...
    [1 nnz(cueChgFa)], 'Color', 0.65 * [1 1 1])

% legend:
legObj = legend('stim On', 'joy rel', 'plan chg', 'plan stim off', ...
    'FontSize', 16, 'Box', 'Off', 'Location', 'Best');

% title:
title('cued change')

% get axes limits to plot matching histograms:
xLims = xlim;

% how many histogram bins
nbin = 25;

% histogram axes:
ax(2) = subplot(4,1,4);
hold on
histogram(stimOnTime(cueChgFa) - fixAqTime(cueChgFa), 'NumBins', nbin, ...
    'BinLimits', xLims, 'EdgeColor', 'None', 'FaceColor', 'b');
histogram(joyRelTime(cueChgFa) - fixAqTime(cueChgFa), 'NumBins', nbin, ...
    'BinLimits', xLims, 'EdgeColor', 'None', 'FaceColor', 'g');
histogram(planChgTime(cueChgFa), 'NumBins', nbin, ...
    'BinLimits', xLims, 'EdgeColor', 'None', 'FaceColor', 'r');
histogram(fix2StimOff(cueChgFa), 'NumBins', nbin, ...
    'BinLimits', xLims, 'EdgeColor', 'None', 'FaceColor', 'k');
set(ax, 'XLim', xLims, 'TickDir', 'Out')
set(ax(1), 'XColor', 'None')

%%
% plot window
figure('Color', [1 1 1])

% "scatter" plot axes:
ax(1) = subplot(4,1,1:3);
hold on
plot(stimOnTime(noChgFa) - fixAqTime(noChgFa), 1:nnz(noChgFa), ...
    'o', 'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'w')
plot(joyRelTime(noChgFa) - fixAqTime(noChgFa), 1:nnz(noChgFa), ...
    'o', 'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'w')
plot(planChgTime(noChgFa), 1:nnz(noChgFa), ...
    'd', 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'w')
plot(fix2StimOff(noChgFa), 1:nnz(noChgFa), ...
    's', 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'w')
plot([1 1] * (mean(stimOnTime(noChgFa) - fixAqTime(noChgFa)) + ...
    mean(stim2ChgTime)), ...
    [1 nnz(noChgFa)], 'Color', 0.65 * [1 1 1])
plot([1 1] * (mean(stimOnTime(noChgFa) - fixAqTime(noChgFa)) + ...
    mean(stim2ChgTime) + trVars(1).chgWinDur), ...
    [1 nnz(noChgFa)], 'Color', 0.65 * [1 1 1])

% legend:
legObj = legend('stim On', 'joy rel', 'plan chg', 'plan stim off', ...
    'FontSize', 16, 'Box', 'Off', 'Location', 'Best');

% title:
title('NO change')

% get axes limits to plot matching histograms:
xLims = xlim;

% how many histogram bins
nbin = 25;

% histogram axes:
ax(2) = subplot(4,1,4);
hold on
histogram(stimOnTime(noChgFa) - fixAqTime(noChgFa), 'NumBins', nbin, ...
    'BinLimits', xLims, 'EdgeColor', 'None', 'FaceColor', 'b');
histogram(joyRelTime(noChgFa) - fixAqTime(noChgFa), 'NumBins', nbin, ...
    'BinLimits', xLims, 'EdgeColor', 'None', 'FaceColor', 'g');
histogram(planChgTime(noChgFa), 'NumBins', nbin, ...
    'BinLimits', xLims, 'EdgeColor', 'None', 'FaceColor', 'r');
histogram(fix2StimOff(noChgFa), 'NumBins', nbin, ...
    'BinLimits', xLims, 'EdgeColor', 'None', 'FaceColor', 'k');
set(ax, 'XLim', xLims, 'TickDir', 'Out')
set(ax(1), 'XColor', 'None')