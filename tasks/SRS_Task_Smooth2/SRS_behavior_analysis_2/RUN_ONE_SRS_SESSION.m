%% RUN_ONE_SRS_SESSION
% Main entry point for analyzing one SRS_Task_Smooth session.
%
% Recommended workflow:
%   1. Open this file in the MATLAB Editor.
%   2. Edit only sessionFolder if required.
%   3. Click Run.
%
% The analysis does not require PLDAPS to be on the MATLAB path. It reads
% the trialXXXX.mat files directly and stores all generated outputs inside
% this SRS_behavior_analysis folder.

clear;
clc;
close all;

%% 1. Add the analysis code to the MATLAB path
analysisFolder = fileparts(mfilename('fullpath'));
if isempty(analysisFolder)
    analysisFolder = pwd;
end
addpath(analysisFolder);

%% 2. Select the session
sessionFolder = fullfile( ...
    '/home/herman_lab/Documents/PLDAPS_vK2_MASTER', ...
    'output', ...
    '20260728_t1405_srsSmooth_training');

% If the path is not present on this computer, MATLAB opens a folder picker.
if ~isfolder(sessionFolder)
    sessionFolder = uigetdir(pwd, ...
        'Select the SRS session folder containing trialXXXX.mat files');
    if isequal(sessionFolder, 0)
        error('No session folder was selected.');
    end
end

%% 3. Analysis options
options = struct();

% Analyze block 8 through the final available block.
% Use [9 Inf] to exclude the first eight blocks.
% Use [] to analyze every block as before.
options.blockRange = [8 Inf];

% Trailing-window length for engagement and spatial-entropy curves.
options.rollingWindow = 20;

% Number of permutations for non-parametric tests. Five thousand provides
% reasonably stable exploratory p-values while remaining practical.
options.nPermutations = 5000;

% Fixed seed makes permutation tests and outputs reproducible.
options.randomSeed = 20260720;

% Figure exports. PNG, PDF, and editable MATLAB FIG files are generated.
options.makeFigures = true;
options.saveFigures = true;
options.savePdfFigures = true;
options.saveMatlabFigures = true;

% Default output locations are created automatically:
%   SRS_behavior_analysis/results/<session name>/
%   SRS_behavior_analysis/figures/<session name>/
% Leave outputRoot empty to use this structure.
options.outputRoot = '';

% Print progress and main output paths in the Command Window.
options.verbose = true;

%% 4. Run the analysis
results = srs_run_analysis({sessionFolder}, options);

%% 5. Useful variables after execution
% results.sessions(1).trials        complete trial table
% results.sessions(1).statistics    statistical tables and diagnostics
% results.sessions(1).outputFolder  CSV, MAT, and report folder
% results.sessions(1).figureFolder  PNG, PDF, and FIG folder

choiceTrials = results.sessions(1).trials( ...
    results.sessions(1).trials.GoodChoice, :);

disp('Preview of two-target choices:');
disp(choiceTrials(1:min(10, height(choiceTrials)), ...
    {'Attempt', 'Block', 'TrialTypeLabel', ...
     'ChosenTarget', 'ChosenSideLabel', ...
     'RichTarget', 'HighSalienceTarget', ...
     'ChoseRich', 'ChoseHighSalience'}));
