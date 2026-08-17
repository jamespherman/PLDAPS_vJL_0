%% RUN_SIMPLE_MOVING_ANALYSIS
% Set the folder containing trialXXXX.mat files, then run this script.

sessionFolder = fullfile( ...
    '/home/herman_lab/Documents/PLDAPS_vK2_MASTER/tasks/SRS_mooving/', ...
    'output', ...
    '20260814_t1500_srsMoving');;

% Primary strategy plots exclude forced correction repeats because those
% repeats are experimentally imposed and are not independent spontaneous
% choices. The analysis also exports a second strategy table including them.
excludeForcedCorrectionRepeats = true;

results = srsMoving_simple_analysis( ...
    sessionFolder, excludeForcedCorrectionRepeats);

disp(results.summary)
disp(results.strategyPrimary)
