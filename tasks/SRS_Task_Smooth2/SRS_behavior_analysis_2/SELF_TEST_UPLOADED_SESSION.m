%% SELF_TEST_UPLOADED_SESSION
% Strict regression test for 20260720_t1112_srsSmooth_training.
%
% The reference session used passEye and passJoy. It is appropriate for
% checking file loading and deterministic outputs, not animal behavior.

clear;
clc;
close all;

%% 1. Add analysis functions to the MATLAB path
analysisFolder = fileparts(mfilename('fullpath'));
if isempty(analysisFolder)
    analysisFolder = pwd;
end
addpath(analysisFolder);

%% 2. Locate the reference session
sessionName = '20260720_t1112_srsSmooth_training';
candidates = { ...
    fullfile('/home/herman_lab/Documents/PLDAPS_vK2_MASTER', ...
        'tasks', 'SRS_Task_Smooth', 'output', sessionName), ...
    fullfile(fileparts(analysisFolder), sessionName), ...
    fullfile(pwd, sessionName)};

sessionFolder = '';
for iCandidate = 1:numel(candidates)
    if isfolder(candidates{iCandidate})
        sessionFolder = candidates{iCandidate};
        break;
    end
end
if isempty(sessionFolder)
    sessionFolder = uigetdir(pwd, ['Select folder ' sessionName]);
    if isequal(sessionFolder, 0)
        error('No session folder was selected.');
    end
end
fprintf('Session under test:\n%s\n\n', sessionFolder);

%% 3. Test loading and derived variables
[T, meta] = srs_load_session(sessionFolder);
assert(height(T) == 99, 'Expected 99 saved attempts; observed %d.', height(T));
assert(sum(T.GoodTrial) == 99, 'Expected 99 successful trials.');
assert(sum(T.GoodTrial & T.IsInstruction) == 20, ...
    'Expected 20 instruction trials.');
assert(sum(T.GoodChoice) == 79, 'Expected 79 two-target choices.');
assert(sum(T.GoodChoice & T.IsCongruent) == 39, ...
    'Expected 39 congruent choices.');
assert(sum(T.GoodChoice & T.IsConflict) == 40, ...
    'Expected 40 conflict choices.');

assert(all(T.PassEye == 1), 'Expected passEye=1 on every attempt.');
assert(all(T.PassJoy == 1), 'Expected passJoy=1 on every attempt.');
assert(all(T.MouseEyeSim == 0), 'Expected mouseEyeSim=0 on every attempt.');
assert(meta.dataLikelySimulated, 'The session should be marked debug/simulated.');
assert(meta.nRealEyeChoices == 0, ...
    'No choice should be eligible for behavioral inference.');

assert(all(T.RichTarget(T.GoodChoice) == 2), ...
    'Expected T2 to be rich for all two-target choices.');
assert(all(T.ChosenTarget(T.GoodChoice) == 2), ...
    'Expected every two-target choice to select T2.');
assert(sum(T.ChoseRich(T.GoodChoice)) == 79, ...
    'Expected 79/79 rich-target choices.');
assert(sum(T.GoodChoice & T.ChosenSide == 1) == 40, ...
    'Expected 40 right choices.');
assert(sum(T.GoodChoice & T.ChosenSide == 2) == 39, ...
    'Expected 39 left choices.');
assert(all(T.ChoiceMappingValid(T.GoodChoice)), ...
    'Every chosen side should match the side of T2.');
assert(sum(T.ChoseHighSalience(T.GoodChoice & T.IsCongruent)) == 39, ...
    'Expected 39/39 high-salience choices in congruent trials.');
assert(sum(T.ChoseHighSalience(T.GoodChoice & T.IsConflict)) == 0, ...
    'Expected 0/40 high-salience choices in conflict trials.');
assert(sum(isfinite(T.ReactionTimeMs)) == 0, ...
    'Expected no valid saccadic reaction time.');
assert(meta.mappingErrors == 0, ...
    'Expected no identity-side mapping inconsistency.');

%% 4. Test statistical structures
quickOptions = struct();
quickOptions.nPermutations = 100;
quickOptions.randomSeed = 20260720;
quickOptions.rollingWindow = 20;
stats = srs_compute_statistics(T, meta, quickOptions);

assert(height(stats.blockTable) == 1, 'Expected one saved block.');
assert(stats.blockTable.ExpectedTrials(1) == 100, ...
    'Expected 100 planned trials.');
assert(stats.blockTable.GoodTrials(1) == 99, ...
    'Expected 99 successful saved trials.');
assert(stats.blockTable.TrialsMissing(1) == 1, ...
    'Expected one planned but unsaved trial.');
assert(~stats.interpretation.inferenceAllowed, ...
    'Animal inference must be disabled for this session.');
assert(~isfinite(stats.engagement.estimatedDisengagementAttempt), ...
    'No operational disengagement point should be retained in debug mode.');
assert(~isempty(stats.psychometricTable), ...
    'The descriptive psychometric table should be available.');
assert(any(strcmp(stats.biasTable.Properties.VariableNames, 'QFDR')), ...
    'FDR-adjusted q-values should be added to bias statistics.');
assert(isfield(stats, 'psychometricFit'), ...
    'The psychometric-fit structure should exist.');

%% 5. Test the complete export pipeline
% Figures are disabled so this test can run without a graphical display.
testOutput = tempname;
fullOptions = quickOptions;
fullOptions.makeFigures = false;
fullOptions.saveFigures = false;
fullOptions.savePdfFigures = false;
fullOptions.saveMatlabFigures = false;
fullOptions.outputRoot = testOutput;
fullOptions.verbose = false;
results = srs_run_analysis({sessionFolder}, fullOptions);

assert(isfolder(results.sessions(1).outputFolder), ...
    'The result folder was not created.');
assert(isfolder(results.sessions(1).figureFolder), ...
    'The session-specific figure folder was not created.');

requiredFiles = { ...
    'trial_table.csv', 'summary_statistics.csv', 'balance_checks.csv', ...
    'bias_statistics.csv', 'strategy_comparison.csv', ...
    'conditional_associations.csv', 'choice_evolution_early_late.csv', ...
    'psychometric_binned.csv', 'psychometric_logistic_fit.csv', ...
    'online_choice_statistics.csv', 'online_timeseries_statistics.csv', ...
    'reaction_time_statistics.csv', 'outcomes.csv', ...
    'block_completion.csv', 'engagement_early_vs_late.csv', ...
    'logistic_models.csv', 'exploration_summary.csv', ...
    'exploration_binned.csv', 'analysis_report.txt', ...
    'analysis_results.mat'};

for iFile = 1:numel(requiredFiles)
    filePath = fullfile(results.sessions(1).outputFolder, requiredFiles{iFile});
    assert(isfile(filePath), 'Missing output file: %s', filePath);
end

%% 6. Verdict
fprintf('\n============================================================\n');
fprintf('SRS SELF-TEST: PASS\n');
fprintf('Reference values, statistical structures, and outputs verified.\n');
fprintf('Temporary result folder:\n%s\n', results.sessions(1).outputFolder);
fprintf('Temporary figure folder:\n%s\n', results.sessions(1).figureFolder);
fprintf('============================================================\n');
