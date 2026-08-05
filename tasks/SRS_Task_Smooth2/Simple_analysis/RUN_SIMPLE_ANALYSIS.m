%% RUN_SIMPLE_ANALYSIS
% Generate only the seven requested behavioral figures and a concise text
% summary for one SRS_Task_Smooth session.
%
% Required sibling folder:
%   tasks/SRS_Task_Smooth/SRS_behavior_analysis_2
%
% The core loader and statistical functions are reused from that validated
% analysis pipeline. Raw trial files are read only and are never modified.

clear;
clc;
close all;

%% 1. Locate this folder and the validated core analysis
simpleFolder = fileparts(mfilename('fullpath'));
if isempty(simpleFolder)
    simpleFolder = pwd;
end
parentFolder = fileparts(simpleFolder);
coreFolder = fullfile(parentFolder, 'SRS_behavior_analysis_2');

if ~isfolder(coreFolder)
    error(['Required folder not found: %s\nPlace Simple_analysis next to ', ...
        'SRS_behavior_analysis_2 inside tasks/SRS_Task_Smooth.'], coreFolder);
end

requiredCoreFiles = {'srs_load_session.m', 'srs_compute_statistics.m'};
for iFile = 1:numel(requiredCoreFiles)
    if ~isfile(fullfile(coreFolder, requiredCoreFiles{iFile}))
        error('Required core file not found: %s', ...
            fullfile(coreFolder, requiredCoreFiles{iFile}));
    end
end

addpath(simpleFolder);
addpath(coreFolder);

%% 2. Select the session
% Leave empty to open a folder picker, or enter a full session path.
sessionFolder = '';

if isempty(sessionFolder) || ~isfolder(sessionFolder)
    selectedFolder = uigetdir(pwd, ...
        'Select an SRS session folder containing trialXXXX.mat files');
    if isequal(selectedFolder, 0)
        error('No session folder was selected.');
    end
    sessionFolder = selectedFolder;
end

%% 3. Select the blocks to analyze
% Default requested by the current training analysis: block 8 through the
% final available block. Examples: [1 Inf], [8 Inf], or [8 12].
blockRange = [1 Inf];

%% 4. Statistical and export options
options = struct();
options.rollingWindow = 20;
options.nPermutations = 5000;
options.randomSeed = 20260720;
options.saveFigures = true;
options.savePdfFigures = true;
options.saveMatlabFigures = true;

%% 5. Load, filter, and analyze
fprintf('Loading session:\n%s\n', sessionFolder);
[T, meta] = srs_load_session(sessionFolder);
[T, meta] = srs_simple_filter_blocks(T, meta, blockRange);
stats = srs_compute_statistics(T, meta, options);

%% 6. Output folders
analysisID = sprintf('%s_B%03d_to_B%03d', char(meta.sessionID), ...
    round(min(meta.analyzedBlocks)), round(max(meta.analyzedBlocks)));
analysisID = regexprep(analysisID, '[^A-Za-z0-9_.-]', '_');

figureFolder = fullfile(simpleFolder, 'figures', analysisID);
resultFolder = fullfile(simpleFolder, 'results', analysisID);
if ~isfolder(figureFolder)
    mkdir(figureFolder);
end
if ~isfolder(resultFolder)
    mkdir(resultFolder);
end

%% 7. Create the recap, then display everything in one window
summaryFile = srs_write_simple_summary(T, stats, meta, resultFolder);
figureFiles = srs_make_simple_figures(T, stats, meta, figureFolder, ...
    options, summaryFile);

save(fullfile(resultFolder, 'simple_analysis_results.mat'), ...
    'T', 'meta', 'stats', 'figureFiles', 'summaryFile', '-v7');

fprintf('\nSimple analysis complete.\n');
fprintf('Analyzed blocks: %s\n', mat2str(meta.analyzedBlocks));
fprintf('Figures: %s\n', figureFolder);
fprintf('Recap: %s\n', summaryFile);
