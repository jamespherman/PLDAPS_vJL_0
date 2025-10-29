clear; clc; close all
dataDir = '/home/herman_lab/Documents/PLDAPS_vK2_MASTER/output';
fileName = ("20250826_t1059_joystick_release_for_stim_change_and_dim");
load(fullfile(dataDir, fileName))

allEndstates =[trData.trialEndState];

numTrials = numel(allEndstates);
Hit = 21;
wasHit = (allEndstates == Hit);
totalHits = cumsum(wasHit);


trialNumbers = 1:numTrials;

figure;
plot(trialNumbers, totalHits, 'k-', 'LineWidth',2);

grid on;
title('Newton Cumulative Hits 08/26/25')
xlabel = ('Trial Number');
ylabel ('Total Cumulative Hits')
set(gca, 'FontSize', 12);