function results = srs_run_analysis(sessionFolders, options)
%SRS_RUN_ANALYSIS Orchestrer le chargement, les statistiques et les figures.
%
%   RESULTS = SRS_RUN_ANALYSIS(SESSIONFOLDERS, OPTIONS)
%
% SESSIONFOLDERS peut etre :
%   - un chemin char/string ;
%   - une cellule de plusieurs chemins.
%
% Chaque session produit un dossier avec :
%   trial_table.csv
%   summary_statistics.csv
%   balance_checks.csv
%   bias_statistics.csv
%   strategy_comparison.csv
%   conditional_associations.csv
%   choice_evolution_early_late.csv
%   psychometric_binned.csv
%   online_choice_statistics.csv
%   online_timeseries_statistics.csv
%   reaction_time_statistics.csv
%   outcomes.csv
%   block_completion.csv
%   engagement_early_vs_late.csv
%   logistic_models.csv
%   analysis_report.txt
%   analysis_results.mat
%   figures PNG et FIG

if nargin < 1 || isempty(sessionFolders)
    selectedFolder = uigetdir(pwd, ...
        'Choisir un dossier de session SRS');
    if isequal(selectedFolder, 0)
        error('Aucun dossier selectionne.');
    end
    sessionFolders = {selectedFolder};
end

if nargin < 2
    options = struct();
end
options = fillRunDefaults(options);

if ischar(sessionFolders) || isstring(sessionFolders)
    sessionFolders = cellstr(sessionFolders);
end
if ~iscell(sessionFolders)
    error('sessionFolders doit etre un chemin ou une cellule de chemins.');
end

nSessions = numel(sessionFolders);
results = struct();
results.sessions = repmat(struct( ...
    'meta', struct(), ...
    'trials', table(), ...
    'statistics', struct(), ...
    'figureFiles', strings(0, 1), ...
    'reportFile', '', ...
    'outputFolder', ''), nSessions, 1);
results.combined = [];

allTrials = table();
allMetas = cell(nSessions, 1);

for iSession = 1:nSessions
    sessionFolder = sessionFolders{iSession};

    if options.verbose
        fprintf('\n============================================================\n');
        fprintf('Lecture de la session %d/%d\n%s\n', ...
            iSession, nSessions, sessionFolder);
    end

    [T, meta] = srs_load_session(sessionFolder, options.blockRange);
    stats = srs_compute_statistics(T, meta, options);

    sessionOutput = chooseSessionOutputFolder( ...
        sessionFolder, meta.sessionID, options, nSessions);
    if ~isfolder(sessionOutput)
        mkdir(sessionOutput);
    end

    writeAnalysisTables(T, stats, sessionOutput);
    figureFiles = srs_make_figures(T, stats, meta, ...
        sessionOutput, options);
    reportFile = srs_write_report(T, stats, meta, sessionOutput);

    save(fullfile(sessionOutput, 'analysis_results.mat'), ...
        'T', 'meta', 'stats', 'figureFiles', '-v7');

    results.sessions(iSession).meta = meta;
    results.sessions(iSession).trials = T;
    results.sessions(iSession).statistics = stats;
    results.sessions(iSession).figureFiles = figureFiles;
    results.sessions(iSession).reportFile = reportFile;
    results.sessions(iSession).outputFolder = sessionOutput;

    allMetas{iSession} = meta;
    if isempty(allTrials)
        allTrials = T;
    else
        allTrials = [allTrials; T]; %#ok<AGROW>
    end

    if options.verbose
        printSessionSummary(meta, stats, sessionOutput);
    end
end

%% Analyse concatenee lorsque plusieurs sessions sont fournies
if nSessions > 1
    combinedTrials = prepareCombinedTable(allTrials);
    combinedMeta = makeCombinedMeta(combinedTrials, allMetas);
    combinedStats = srs_compute_statistics( ...
        combinedTrials, combinedMeta, options);

    combinedOutput = chooseCombinedOutputFolder( ...
        sessionFolders, options);
    if ~isfolder(combinedOutput)
        mkdir(combinedOutput);
    end

    writeAnalysisTables(combinedTrials, combinedStats, combinedOutput);
    combinedFigures = srs_make_figures( ...
        combinedTrials, combinedStats, combinedMeta, ...
        combinedOutput, options);
    combinedReport = srs_write_report( ...
        combinedTrials, combinedStats, combinedMeta, combinedOutput);

    save(fullfile(combinedOutput, 'analysis_results.mat'), ...
        'combinedTrials', 'combinedMeta', 'combinedStats', ...
        'combinedFigures', '-v7');

    results.combined = struct( ...
        'meta', combinedMeta, ...
        'trials', combinedTrials, ...
        'statistics', combinedStats, ...
        'figureFiles', combinedFigures, ...
        'reportFile', combinedReport, ...
        'outputFolder', combinedOutput);

    if options.verbose
        fprintf('\nAnalyse concatenee sauvegardee dans :\n%s\n', ...
            combinedOutput);
    end
end

end

%% ========================================================================
% Ecriture des fichiers
% ========================================================================

function writeAnalysisTables(T, stats, outputFolder)
writetable(T, fullfile(outputFolder, 'trial_table.csv'));
writeTableIfPresent(stats, 'summaryTable', outputFolder, ...
    'summary_statistics.csv');
writeTableIfPresent(stats, 'balanceTable', outputFolder, ...
    'balance_checks.csv');
writeTableIfPresent(stats, 'biasTable', outputFolder, ...
    'bias_statistics.csv');
writeTableIfPresent(stats, 'strategyTable', outputFolder, ...
    'strategy_comparison.csv');
writeTableIfPresent(stats, 'associationTable', outputFolder, ...
    'conditional_associations.csv');
writeTableIfPresent(stats, 'choiceEvolutionTable', outputFolder, ...
    'choice_evolution_early_late.csv');
writeTableIfPresent(stats, 'psychometricTable', outputFolder, ...
    'psychometric_binned.csv');
writeTableIfPresent(stats, 'onlineChoiceTable', outputFolder, ...
    'online_choice_statistics.csv');
writeTableIfPresent(stats, 'timeSeriesTable', outputFolder, ...
    'online_timeseries_statistics.csv');
writeTableIfPresent(stats, 'rtTable', outputFolder, ...
    'reaction_time_statistics.csv');
writeTableIfPresent(stats, 'outcomeTable', outputFolder, ...
    'outcomes.csv');
writeTableIfPresent(stats, 'blockTable', outputFolder, ...
    'block_completion.csv');
writeTableIfPresent(stats, 'engagementTable', outputFolder, ...
    'engagement_early_vs_late.csv');
writeTableIfPresent(stats, 'modelTable', outputFolder, ...
    'logistic_models.csv');

if isfield(stats, 'exploration')
    E = stats.exploration;
    explorationSummary = table( ...
        E.nAll, E.pSwitchAll, E.nReal, E.pSwitchReal, ...
        E.ciLowReal, E.ciHighReal, E.pExactVsChanceReal, ...
        E.rewardSwitchCorrelation, E.rewardSwitchPermutationP, ...
        'VariableNames', {'NAll', 'PSwitchAll', 'NReal', ...
        'PSwitchReal', 'CI95LowReal', 'CI95HighReal', ...
        'PExactVsChanceReal', 'RewardSwitchCorrelation', ...
        'RewardSwitchPermutationP'});
    writetable(explorationSummary, ...
        fullfile(outputFolder, 'exploration_summary.csv'));

    binTable = table(E.binCenters(:), E.binPSwitch(:), E.binN(:), ...
        'VariableNames', {'PreviousRewardBinCenterMs', ...
        'PSwitch', 'N'});
    writetable(binTable, ...
        fullfile(outputFolder, 'exploration_binned.csv'));
end
end

function writeTableIfPresent(stats, fieldName, outputFolder, fileName)
if isfield(stats, fieldName) && istable(stats.(fieldName)) && ...
        ~isempty(stats.(fieldName))
    writetable(stats.(fieldName), fullfile(outputFolder, fileName));
end
end

%% ========================================================================
% Dossiers de sortie
% ========================================================================

function outputFolder = chooseSessionOutputFolder( ...
        sessionFolder, sessionID, options, nSessions)
if isempty(options.outputRoot)
    outputFolder = fullfile(sessionFolder, 'offline_behavior_analysis');
elseif nSessions == 1
    outputFolder = options.outputRoot;
else
    outputFolder = fullfile(options.outputRoot, sessionID);
end
end

function outputFolder = chooseCombinedOutputFolder(sessionFolders, options)
if ~isempty(options.outputRoot)
    outputFolder = fullfile(options.outputRoot, 'ALL_SESSIONS_COMBINED');
else
    firstParent = fileparts(sessionFolders{1});
    outputFolder = fullfile(firstParent, ...
        'offline_behavior_analysis_all', 'ALL_SESSIONS_COMBINED');
end
end

%% ========================================================================
% Table et metadonnees concatenees
% ========================================================================

function T = prepareCombinedTable(T)
% Conserver les indices locaux, puis creer des indices globaux pour les
% figures concatenees. Les dependances sequentielles restent celles calculees
% au sein de chaque session par srs_load_session.
T.AttemptWithinSession = T.Attempt;
T.ChoiceOrdinalWithinSession = T.ChoiceOrdinal;
T.GoodTrialOrdinalWithinSession = T.GoodTrialOrdinal;

T.Attempt = (1:height(T))';
T.GoodTrialOrdinal = cumsum(double(T.GoodTrial));
T.ChoiceOrdinal(:) = NaN;
T.ChoiceOrdinal(T.GoodChoice) = (1:sum(T.GoodChoice))';

% Eviter qu'une detection d'intervalle interprete le passage d'une session
% a la suivante comme une pause de l'animal.
for i = 1:height(T)
    if i == 1 || T.SessionID(i) ~= T.SessionID(i - 1)
        T.PreTrialIntervalSec(i) = NaN;
    end
end
end

function meta = makeCombinedMeta(T, allMetas)
meta = struct();
meta.sessionFolder = 'Plusieurs dossiers';
meta.sessionID = 'ALL_SESSIONS_COMBINED';
meta.experimentType = 'combined';
meta.taskName = 'srsSmooth';
meta.sessionDate = '';
meta.sessionTime = '';
meta.nAttemptFiles = height(T);
meta.nGoodTrials = sum(T.GoodTrial);
meta.nGoodChoices = sum(T.GoodChoice);
meta.nRealEyeChoices = sum(T.RealEyeChoice);
meta.passEyeFraction = mean(T.PassEye ~= 0);
meta.passJoyFraction = mean(T.PassJoy ~= 0);
meta.mouseEyeSimFraction = mean(T.MouseEyeSim ~= 0);
meta.dataLikelySimulated = any(T.PassEye ~= 0 | T.MouseEyeSim ~= 0);
meta.nValidReactionTimes = sum(isfinite(T.ReactionTimeMs));
meta.nValidFixAcquisitionLatencies = ...
    sum(isfinite(T.FixAcquisitionLatencyMs));
meta.totalMissedFrames = sum(T.MissedFrames, 'omitnan');
meta.mappingErrors = sum(T.GoodChoice & ~T.ChoiceMappingValid);
meta.totalBlocksTarget = NaN;
durations = cellfun(@(m) m.sessionDurationMin, allMetas);
meta.sessionDurationMin = sum(durations, 'omitnan');

warnings = strings(0, 1);
for iMeta = 1:numel(allMetas)
    currentMeta = allMetas{iMeta};
    if isfield(currentMeta, 'warnings')
        warnings = [warnings; currentMeta.warnings(:)]; %#ok<AGROW>
    end
end
warnings(end + 1, 1) = [ ...
    "Les mesures d'engagement de l'ensemble concatene decrivent un ordre " + ...
    "de fichiers multi-session. Pour dater un desengagement, utiliser les " + ...
    "rapports de chaque session separement."];
meta.warnings = unique(warnings, 'stable');
end

%% ========================================================================
% Affichage console
% ========================================================================

function printSessionSummary(meta, stats, outputFolder)
fprintf('\nSession : %s\n', meta.sessionID);
fprintf('  Tentatives       : %d\n', meta.nAttemptFiles);
fprintf('  Essais reussis   : %d\n', meta.nGoodTrials);
fprintf('  Choix 2 cibles   : %d\n', meta.nGoodChoices);
fprintf('  Choix reels      : %d\n', meta.nRealEyeChoices);
fprintf('  passEye          : %.1f %%\n', 100 * meta.passEyeFraction);
fprintf('  RT valides       : %d\n', meta.nValidReactionTimes);

if isfield(meta, 'warnings') && ~isempty(meta.warnings)
    for iWarning = 1:numel(meta.warnings)
        fprintf('  ATTENTION : %s\n', char(meta.warnings(iWarning)));
    end
end

if ~isempty(stats.strategyTable)
    [bestAccuracy, idx] = max(stats.strategyTable.AccuracyAll);
    fprintf('  Meilleure strategie descriptive : %s (%.3f)\n', ...
        char(stats.strategyTable.Strategy(idx)), bestAccuracy);
end

fprintf('  Resultats sauvegardes dans :\n  %s\n', outputFolder);
end

%% ========================================================================
% Options
% ========================================================================

function options = fillRunDefaults(options)
defaults = struct( ...
    'blockRange', [], ...
    'rollingWindow', 20, ...
    'nPermutations', 5000, ...
    'randomSeed', 1, ...
    'makeFigures', true, ...
    'saveFigures', true, ...
    'saveMatlabFigures', true, ...
    'outputRoot', '', ...
    'verbose', true);
fields = fieldnames(defaults);
for iField = 1:numel(fields)
    name = fields{iField};
    if ~isfield(options, name) || isempty(options.(name))
        options.(name) = defaults.(name);
    end
end
end
