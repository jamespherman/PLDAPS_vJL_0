function results = srs_run_analysis(sessionFolders, options)
%SRS_RUN_ANALYSIS Load sessions, compute statistics, create figures, export.
%
% RESULTS = SRS_RUN_ANALYSIS(SESSIONFOLDERS, OPTIONS)
%
% SESSIONFOLDERS may be a character vector, string, or cell array of paths.
% By default, outputs are centralized next to this code:
%   SRS_behavior_analysis/results/<session ID>/
%   SRS_behavior_analysis/figures/<session ID>/
%
% This keeps generated files separate from the raw PLDAPS session folders.

trial_start = 527;

if nargin < 1 || isempty(sessionFolders)
    selectedFolder = uigetdir(pwd, ...
        'Select an SRS session folder containing trialXXXX.mat files');
    if isequal(selectedFolder, 0)
        error('No session folder was selected.');
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
    error('sessionFolders must be a path or a cell array of paths.');
end

nSessions = numel(sessionFolders);
results = struct();
results.sessions = repmat(struct( ...
    'meta', struct(), 'trials', table(), 'statistics', struct(), ...
    'figureFiles', strings(0, 1), 'reportFile', '', ...
    'outputFolder', '', 'figureFolder', ''), nSessions, 1);
results.combined = [];

allTrials = table();
allMetas = cell(nSessions, 1);

for iSession = trial_start:nSessions
    sessionFolder = sessionFolders{iSession};
    if options.verbose
        fprintf('\n============================================================\n');
        fprintf('Reading session %d/%d\n%s\n', ...
            iSession, nSessions, sessionFolder);
    end

    [T, meta] = srs_load_session(sessionFolder);
    stats = srs_compute_statistics(T, meta, options);

    sessionKey = sanitizePathComponent(meta.sessionID);
    resultFolder = fullfile(options.resultsRoot, sessionKey);
    figureFolder = fullfile(options.figuresRoot, sessionKey);
    ensureFolder(resultFolder);
    ensureFolder(figureFolder);

    writeAnalysisTables(T, stats, resultFolder);
    figureFiles = srs_make_figures(T, stats, meta, figureFolder, options);
    reportFile = srs_write_report(T, stats, meta, resultFolder);

    save(fullfile(resultFolder, 'analysis_results.mat'), ...
        'T', 'meta', 'stats', 'figureFiles', 'figureFolder', '-v7');

    results.sessions(iSession).meta = meta;
    results.sessions(iSession).trials = T;
    results.sessions(iSession).statistics = stats;
    results.sessions(iSession).figureFiles = figureFiles;
    results.sessions(iSession).reportFile = reportFile;
    results.sessions(iSession).outputFolder = resultFolder;
    results.sessions(iSession).figureFolder = figureFolder;

    allMetas{iSession} = meta;
    if isempty(allTrials)
        allTrials = T;
    else
        allTrials = [allTrials; T]; %#ok<AGROW>
    end

    if options.verbose
        printSessionSummary(meta, stats, resultFolder, figureFolder);
    end
end

%% Combined analysis when multiple sessions are supplied
if nSessions > 1
    combinedTrials = prepareCombinedTable(allTrials);
    combinedMeta = makeCombinedMeta(combinedTrials, allMetas);
    combinedStats = srs_compute_statistics(combinedTrials, combinedMeta, options);

    combinedKey = sanitizePathComponent(combinedMeta.sessionID);
    combinedResultFolder = fullfile(options.resultsRoot, combinedKey);
    combinedFigureFolder = fullfile(options.figuresRoot, combinedKey);
    ensureFolder(combinedResultFolder);
    ensureFolder(combinedFigureFolder);

    writeAnalysisTables(combinedTrials, combinedStats, combinedResultFolder);
    combinedFigures = srs_make_figures(combinedTrials, combinedStats, ...
        combinedMeta, combinedFigureFolder, options);
    combinedReport = srs_write_report(combinedTrials, combinedStats, ...
        combinedMeta, combinedResultFolder);

    save(fullfile(combinedResultFolder, 'analysis_results.mat'), ...
        'combinedTrials', 'combinedMeta', 'combinedStats', ...
        'combinedFigures', 'combinedFigureFolder', '-v7');

    results.combined = struct( ...
        'meta', combinedMeta, 'trials', combinedTrials, ...
        'statistics', combinedStats, 'figureFiles', combinedFigures, ...
        'reportFile', combinedReport, ...
        'outputFolder', combinedResultFolder, ...
        'figureFolder', combinedFigureFolder);

    if options.verbose
        fprintf('\nCombined results saved in:\n%s\n', combinedResultFolder);
        fprintf('Combined figures saved in:\n%s\n', combinedFigureFolder);
    end
end
end

%% File export

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
writeTableIfPresent(stats, 'onlineConditionComparisonTable', outputFolder, ...
    'online_condition_comparisons.csv');
writeTableIfPresent(stats, 'timeSeriesTable', outputFolder, ...
    'online_timeseries_statistics.csv');
writeTableIfPresent(stats, 'rtTable', outputFolder, ...
    'reaction_time_statistics.csv');
writeTableIfPresent(stats, 'outcomeTable', outputFolder, 'outcomes.csv');
writeTableIfPresent(stats, 'blockTable', outputFolder, ...
    'block_completion.csv');
writeTableIfPresent(stats, 'engagementTable', outputFolder, ...
    'engagement_early_vs_late.csv');
writeTableIfPresent(stats, 'modelTable', outputFolder, ...
    'logistic_models.csv');

if isfield(stats, 'psychometricFit')
    F = stats.psychometricFit;
    fitSummary = table(string(F.EvidenceType), F.N, F.EvidenceMean, ...
        F.EvidenceSD, F.Intercept, F.InterceptSE, F.SlopePerSD, ...
        F.SlopeSE, F.OddsRatioPerSD, F.WaldP, F.LikelihoodRatioP, ...
        F.Converged, string(F.Note), ...
        'VariableNames', {'EvidenceType', 'N', 'EvidenceMean', ...
        'EvidenceSD', 'Intercept', 'InterceptSE', 'SlopePerSD', ...
        'SlopeSE', 'OddsRatioPerSD', 'WaldP', 'LikelihoodRatioP', ...
        'Converged', 'Note'});
    writetable(fitSummary, ...
        fullfile(outputFolder, 'psychometric_logistic_fit.csv'));
    if ~isempty(F.XGrid)
        curveTable = table(F.XGrid(:), F.PGrid(:), ...
            'VariableNames', {'Evidence', 'PredictedPChooseT1'});
        writetable(curveTable, ...
            fullfile(outputFolder, 'psychometric_logistic_curve.csv'));
    end
end

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
        'VariableNames', {'PreviousRewardBinCenterMs', 'PSwitch', 'N'});
    writetable(binTable, fullfile(outputFolder, 'exploration_binned.csv'));
end
end

function writeTableIfPresent(stats, fieldName, outputFolder, fileName)
if isfield(stats, fieldName) && istable(stats.(fieldName)) && ...
        ~isempty(stats.(fieldName))
    writetable(stats.(fieldName), fullfile(outputFolder, fileName));
end
end

%% Combined table and metadata

function T = prepareCombinedTable(T)
% Preserve local indices and create global indices for combined figures.
% Sequential dependencies remain those computed within each source session.
T.AttemptWithinSession = T.Attempt;
T.ChoiceOrdinalWithinSession = T.ChoiceOrdinal;
T.GoodTrialOrdinalWithinSession = T.GoodTrialOrdinal;
T.Attempt = (1:height(T))';
T.GoodTrialOrdinal = cumsum(double(T.GoodTrial));
T.ChoiceOrdinal(:) = NaN;
T.ChoiceOrdinal(T.GoodChoice) = (1:sum(T.GoodChoice))';

% Prevent the transition between files from being interpreted as an animal
% pause when sessions are concatenated.
for i = 1:height(T)
    if i == 1 || T.SessionID(i) ~= T.SessionID(i - 1)
        T.PreTrialIntervalSec(i) = NaN;
    end
end
end

function meta = makeCombinedMeta(T, allMetas)
meta = struct();
meta.sessionFolder = 'Multiple source folders';
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
    "Combined engagement traces describe an ordering across multiple " + ...
    "sessions. Use the individual session reports to date any operational " + ...
    "change in engagement."];
meta.warnings = unique(warnings, 'stable');
end

%% Console summary

function printSessionSummary(meta, stats, resultFolder, figureFolder)
fprintf('\nSession: %s\n', meta.sessionID);
fprintf('  Saved attempts          : %d\n', meta.nAttemptFiles);
fprintf('  Successful trials       : %d\n', meta.nGoodTrials);
fprintf('  Two-target choices      : %d\n', meta.nGoodChoices);
fprintf('  Real eye choices        : %d\n', meta.nRealEyeChoices);
fprintf('  passEye                 : %.1f %%\n', 100 * meta.passEyeFraction);
fprintf('  Valid reaction times    : %d\n', meta.nValidReactionTimes);
if isfield(meta, 'warnings') && ~isempty(meta.warnings)
    for iWarning = 1:numel(meta.warnings)
        fprintf('  WARNING: %s\n', char(meta.warnings(iWarning)));
    end
end
if ~isempty(stats.strategyTable)
    if any(stats.strategyTable.NReal > 0)
        values = stats.strategyTable.AccuracyReal;
    else
        values = stats.strategyTable.AccuracyAll;
    end
    values(~isfinite(values)) = -Inf;
    [bestAccuracy, idx] = max(values);
    fprintf('  Best descriptive strategy: %s (%.3f)\n', ...
        char(stats.strategyTable.Strategy(idx)), bestAccuracy);
end
fprintf('  Tables and report saved in:\n  %s\n', resultFolder);
fprintf('  Figures saved in:\n  %s\n', figureFolder);
end

%% Options and path helpers

function options = fillRunDefaults(options)
analysisRoot = fileparts(mfilename('fullpath'));
if isempty(analysisRoot)
    analysisRoot = pwd;
end

% outputRoot is retained as a backward-compatible shortcut. When supplied,
% it becomes the parent of separate results and figures directories.
if isfield(options, 'outputRoot') && ~isempty(options.outputRoot)
    defaultResultsRoot = fullfile(options.outputRoot, 'results');
    defaultFiguresRoot = fullfile(options.outputRoot, 'figures');
else
    defaultResultsRoot = fullfile(analysisRoot, 'results');
    defaultFiguresRoot = fullfile(analysisRoot, 'figures');
end

defaults = struct( ...
    'rollingWindow', 20, ...
    'nPermutations', 5000, ...
    'randomSeed', 1, ...
    'makeFigures', true, ...
    'saveFigures', true, ...
    'savePdfFigures', true, ...
    'saveMatlabFigures', true, ...
    'outputRoot', '', ...
    'resultsRoot', defaultResultsRoot, ...
    'figuresRoot', defaultFiguresRoot, ...
    'verbose', true);
fields = fieldnames(defaults);
for iField = 1:numel(fields)
    name = fields{iField};
    if ~isfield(options, name) || isempty(options.(name))
        options.(name) = defaults.(name);
    end
end
end

function ensureFolder(folderPath)
if ~isfolder(folderPath)
    mkdir(folderPath);
end
end

function value = sanitizePathComponent(value)
value = char(string(value));
value = regexprep(value, '[^A-Za-z0-9._-]', '_');
if isempty(value)
    value = 'UNNAMED_SESSION';
end
end
