%% RUN_ALL_SRS_SESSIONS
% Analyse automatiquement toutes les sessions SRS presentes dans le dossier
% output. Cette analyse multi-session est celle qu'il faut privilegier pour
% separer correctement :
%   - une preference identitaire T1/T2 ;
%   - une preference spatiale droite/gauche ;
%   - une strategie de choix de la cible riche ;
%   - une strategie guidee par la saillance.
%
% Dans un seul bloc, une cible identitaire peut rester riche pendant tout le
% bloc. Par exemple, "toujours T2" et "toujours la cible riche" peuvent alors
% faire exactement les memes predictions. Plusieurs blocs avec renversement
% T1 riche / T2 riche sont necessaires pour les dissocier.

clear;
clc;
close all;

%% 1. Ajouter les fonctions au path
analysisFolder = fileparts(mfilename('fullpath'));
if isempty(analysisFolder)
    analysisFolder = pwd;
end
addpath(analysisFolder);

%% 2. Dossier contenant les sessions
parentFolder = fullfile( ...
    '/home/herman_lab/Documents/PLDAPS_vK2_MASTER', ...
    'tasks', 'SRS_Task_Smooth', 'output');

if ~isfolder(parentFolder)
    parentFolder = uigetdir(pwd, ...
        'Choisir le dossier output contenant les sessions SRS');
    if isequal(parentFolder, 0)
        error('Aucun dossier parent selectionne.');
    end
end

%% 3. Rechercher les dossiers de sessions
folderInfo = dir(parentFolder);
isCandidate = [folderInfo.isdir] & ...
    ~ismember({folderInfo.name}, {'.', '..'});
folderInfo = folderInfo(isCandidate);

sessionFolders = {};
for iFolder = 1:numel(folderInfo)
    candidate = fullfile(parentFolder, folderInfo(iFolder).name);
    trialFiles = dir(fullfile(candidate, 'trial*.mat'));
    nameLower = lower(folderInfo(iFolder).name);

    % On exige au moins un fichier trialXXXX.mat et un nom compatible SRS.
    if ~isempty(trialFiles) && ~isempty(strfind(nameLower, 'srssmooth')) %#ok<STREMP>
        sessionFolders{end + 1, 1} = candidate; %#ok<SAGROW>
    end
end

if isempty(sessionFolders)
    error('Aucune session SRS avec des fichiers trialXXXX.mat trouvee.');
end

fprintf('%d session(s) trouvee(s).\n', numel(sessionFolders));
for iSession = 1:numel(sessionFolders)
    fprintf('  %s\n', sessionFolders{iSession});
end

%% 4. Options
options = struct();
options.rollingWindow = 20;
options.nPermutations = 5000;
options.randomSeed = 20260720;
options.makeFigures = true;
options.saveFigures = true;
options.saveMatlabFigures = true;
options.verbose = true;

% Un dossier central recevra aussi l'analyse concatenee de toutes les sessions.
options.outputRoot = fullfile(parentFolder, 'offline_behavior_analysis_all');

%% 5. Lancer l'analyse
results = srs_run_analysis(sessionFolders, options);

% La table concatenee est disponible si au moins deux sessions ont ete lues.
if isfield(results, 'combined') && ~isempty(results.combined)
    disp('Apercu du resume par bloc :');
    disp(results.combined.statistics.blockTable);
end
