%% RUN_ALL_SRS_SESSIONS
% Analyze every SRS session found in the task output directory, then create
% a combined analysis. Multiple sessions are particularly important for
% separating:
%   - T1/T2 identity preference;
%   - right/left spatial preference;
%   - rich-target choice;
%   - salience-guided choice.
%
% Within one block, an identity may remain rich throughout. In that case,
% strategies such as "always T2" and "choose the rich target" may produce
% identical predictions. Rich-target reversals across blocks are required.

clear;
clc;
close all;

%% 1. Add the analysis code to the MATLAB path
analysisFolder = fileparts(mfilename('fullpath'));
if isempty(analysisFolder)
    analysisFolder = pwd;
end
addpath(analysisFolder);

%% 2. Folder containing SRS session folders
parentFolder = fullfile( ...
    '/home/herman_lab/Documents/PLDAPS_vK2_MASTER', ...
    'tasks', 'SRS_Task_Smooth', 'output');

if ~isfolder(parentFolder)
    parentFolder = uigetdir(pwd, ...
        'Select the output folder containing SRS sessions');
    if isequal(parentFolder, 0)
        error('No parent folder was selected.');
    end
end

%% 3. Find session folders
folderInfo = dir(parentFolder);
isCandidate = [folderInfo.isdir] & ~ismember({folderInfo.name}, {'.', '..'});
folderInfo = folderInfo(isCandidate);

sessionFolders = {};
for iFolder = 1:numel(folderInfo)
    candidate = fullfile(parentFolder, folderInfo(iFolder).name);
    trialFiles = dir(fullfile(candidate, 'trial*.mat'));
    nameLower = lower(folderInfo(iFolder).name);
    if ~isempty(trialFiles) && ...
            ~isempty(strfind(nameLower, 'srssmooth')) %#ok<STREMP>
        sessionFolders{end + 1, 1} = candidate; %#ok<SAGROW>
    end
end

if isempty(sessionFolders)
    error('No SRS session containing trialXXXX.mat files was found.');
end

fprintf('%d session(s) found.\n', numel(sessionFolders));
for iSession = 1:numel(sessionFolders)
    fprintf('  %s\n', sessionFolders{iSession});
end

%% 4. Options
options = struct();
% Apply the block selection separately within every session.
options.blockRange = [8 Inf];
options.rollingWindow = 20;
options.nPermutations = 5000;
options.randomSeed = 20260720;
options.makeFigures = true;
options.saveFigures = true;
options.savePdfFigures = true;
options.saveMatlabFigures = true;
options.outputRoot = '';
options.verbose = true;

%% 5. Run separate and combined analyses
results = srs_run_analysis(sessionFolders, options);

if isfield(results, 'combined') && ~isempty(results.combined)
    disp('Combined block summary:');
    disp(results.combined.statistics.blockTable);
end
