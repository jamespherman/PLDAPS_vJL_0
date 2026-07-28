%% RUN_ONE_SRS_SESSION
% Point d'entree pour analyser une session SRS_Task_Smooth.
%
% Utilisation conseillee :
%   1. Ouvrir ce fichier dans l'Editor MATLAB.
%   2. Modifier seulement la variable sessionFolder ci-dessous si besoin.
%   3. Cliquer sur Run, ou executer les sections une par une.
%
% Le code n'a pas besoin que PLDAPS soit dans le MATLAB path. Il lit
% directement les fichiers trialXXXX.mat sauvegardes dans la session.

clear;
clc;
close all;

%% 1. Ajouter le dossier d'analyse au MATLAB path
analysisFolder = fileparts(mfilename('fullpath'));
if isempty(analysisFolder)
    % Ce cas peut arriver si le code est colle directement dans la console.
    analysisFolder = pwd;
end
addpath(analysisFolder);

%% 2. Choisir la session
% Chemin correspondant a la session que tu as transmise.
sessionFolder = fullfile( ...
    '/home/herman_lab/Documents/PLDAPS_vK2_MASTER', ...
    'output', ...
    '20260721_t1530_srsSmooth_training');

% Si le chemin n'existe pas sur cette machine, MATLAB ouvre un selecteur.
if ~isfolder(sessionFolder)
    sessionFolder = uigetdir(pwd, ...
        'Choisir le dossier de session SRS contenant trialXXXX.mat');
    if isequal(sessionFolder, 0)
        error('Aucun dossier de session selectionne.');
    end
end

%% 3. Options principales
options = struct();

% Fenetre glissante utilisee pour les courbes d'engagement.
options.rollingWindow = 20;

% Nombre de permutations pour les comparaisons non parametriques.
% 5000 donne des p-values assez stables tout en restant raisonnable.
options.nPermutations = 5000;

% Graine fixe : les tests par permutation sont reproductibles.
options.randomSeed = 20260720;

% Creer et sauvegarder les figures.
options.makeFigures = true;
options.saveFigures = true;
options.saveMatlabFigures = true;

% Par defaut, les resultats sont places dans :
%   <sessionFolder>/offline_behavior_analysis
% Laisser vide pour conserver ce comportement.
options.outputRoot = '';

% Afficher les etapes et les principaux resultats dans la Command Window.
options.verbose = true;

%% 4. Lancer l'analyse
results = srs_run_analysis({sessionFolder}, options);

%% 5. Variables utiles apres execution
% results.sessions(1).trials       : table complete, un essai par ligne
% results.sessions(1).statistics   : tables statistiques et diagnostics
% results.sessions(1).outputFolder : dossier contenant CSV, figures et rapport
%
% Exemple : afficher uniquement les choix a deux cibles.
choiceTrials = results.sessions(1).trials( ...
    results.sessions(1).trials.GoodChoice, :);

disp('Apercu des choix a deux cibles :');
disp(choiceTrials(1:min(10, height(choiceTrials)), ...
    {'Attempt', 'Block', 'TrialTypeLabel', ...
     'ChosenTarget', 'ChosenSideLabel', ...
     'RichTarget', 'HighSalienceTarget', ...
     'ChoseRich', 'ChoseHighSalience'}));
