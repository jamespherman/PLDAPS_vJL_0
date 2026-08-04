function figureFiles = srs_make_figures(T, stats, meta, outputFolder, options)
%SRS_MAKE_FIGURES Creer les figures offline principales.
%
% Les figures utilisent les donnees enregistrees pour rester comparables aux
% online plots. Lorsqu'aucun choix RealEyeChoice n'est present, les titres
% indiquent explicitement que les courbes sont descriptives/debug.

figureFiles = strings(0, 1);

if nargin < 5 || ~isfield(options, 'makeFigures') || ~options.makeFigures
    return;
end

if ~isfolder(outputFolder)
    mkdir(outputFolder);
end

if meta.nRealEyeChoices > 0
    inferenceLabel = 'choix reels disponibles';
else
    inferenceLabel = 'DESCRIPTIF DEBUG - aucun choix oculaire reel';
end

%% Figure 1 : reproduction et extension des online plots
fig = figure('Color', 'w', 'Position', [80 80 1450 900], ...
    'Name', 'SRS online plots offline');

% 1. Difference de recompense
subplot(3, 2, 1);
mask = T.GoodTrial & isfinite(T.RewardDifferenceT1MinusT2Ms);
plot(T.GoodTrialOrdinal(mask), T.RewardDifferenceT1MinusT2Ms(mask), ...
    '.-', 'LineWidth', 1.0, 'MarkerSize', 9);
hold on;
plotHorizontalZero();
xlabel('Essai reussi');
ylabel('T1 - T2 reward (ms)');
title('Difference de recompense');
box off;

% 2. Difference de saillance : teinte ou luminance suivant les donnees
subplot(3, 2, 2);
hueMask = T.GoodTrial & ...
    isfinite(T.HueContrastDifferenceT1MinusT2Deg);
lumMask = T.GoodTrial & ...
    isfinite(T.MeasuredLuminanceDifferenceT1MinusT2CdM2);
if sum(hueMask) >= sum(lumMask) && any(hueMask)
    plot(T.GoodTrialOrdinal(hueMask), ...
        T.HueContrastDifferenceT1MinusT2Deg(hueMask), ...
        '.-', 'LineWidth', 1.0, 'MarkerSize', 9);
    ylabel('T1 - T2 contraste DKL (deg)');
    title('Difference de contraste de teinte');
elseif any(lumMask)
    plot(T.GoodTrialOrdinal(lumMask), ...
        T.MeasuredLuminanceDifferenceT1MinusT2CdM2(lumMask), ...
        '.-', 'LineWidth', 1.0, 'MarkerSize', 9);
    ylabel('T1 - T2 luminance (cd/m^2)');
    title('Difference de luminance mesuree');
else
    showNoData('Aucune mesure de saillance finie');
end
hold on;
plotHorizontalZero();
xlabel('Essai reussi');
box off;

% 3. P(haute saillance) et P(cible riche)
subplot(3, 2, 3);
choiceStats = stats.onlineChoiceTable;
selectedRows = 1:min(4, height(choiceStats));
values = choiceStats.ProportionAll(selectedRows);
low = nan(size(values));
high = nan(size(values));
for i = 1:numel(selectedRows)
    row = selectedRows(i);
    [low(i), high(i)] = localWilson( ...
        choiceStats.CountAll(row), choiceStats.NAll(row));
end
bar(1:numel(values), values);
hold on;
errorbar(1:numel(values), values, values - low, high - values, ...
    'k.', 'LineWidth', 1.2);
plot([0.5, numel(values) + 0.5], [0.5 0.5], 'k--');
set(gca, 'XTick', 1:numel(values), ...
    'XTickLabel', {'Sal conflit', 'Sal congruent', ...
                   'Reward conflit', 'Reward congruent'}, ...
    'XTickLabelRotation', 20, 'YLim', [0 1]);
ylabel('Proportion');
title('Choix par condition');
box off;

% 4. Evolution cumulative des choix de la cible tres saillante
subplot(3, 2, 4);
C = T(T.GoodChoice, :);
if isempty(C)
    showNoData('Aucun choix a deux cibles');
else
    x = (1:height(C))';
    overall = cumsum(C.ChoseHighSalience) ./ x;
    plot(x, overall, 'k--', 'LineWidth', 1.5);
    hold on;

    conflict = C.IsConflict;
    if any(conflict)
        conflictOrdinal = cumsum(double(conflict));
        conflictCum = cumsum(C.ChoseHighSalience .* double(conflict));
        yConflict = nan(height(C), 1);
        yConflict(conflict) = conflictCum(conflict) ./ conflictOrdinal(conflict);
        plot(x(conflict), yConflict(conflict), '-', 'LineWidth', 1.7);
    end

    congruent = C.IsCongruent;
    if any(congruent)
        congruentOrdinal = cumsum(double(congruent));
        congruentCum = cumsum(C.ChoseHighSalience .* double(congruent));
        yCongruent = nan(height(C), 1);
        yCongruent(congruent) = ...
            congruentCum(congruent) ./ congruentOrdinal(congruent);
        plot(x(congruent), yCongruent(congruent), '-', 'LineWidth', 1.7);
    end
    plot([1 max(2, height(C))], [0.5 0.5], 'k:');
    ylim([0 1]);
    xlabel('Choix a deux cibles');
    ylabel('P cumulative (haute saillance)');
    legend({'Tous', 'Conflit', 'Congruent'}, 'Location', 'best');
    title('Evolution des choix');
    box off;
end

% 5. Temps de reaction conflit/congruent
subplot(3, 2, 5);
plotReactionTimes(T);

% 6. Exploration : reward precedente et switch identitaire
subplot(3, 2, 6);
mask = T.GoodChoice & isfinite(T.PreviousRewardMs) & ...
    isfinite(T.SwitchedTarget);
if any(mask)
    scatter(T.PreviousRewardMs(mask), T.SwitchedTarget(mask), 24, ...
        'filled');
    hold on;
    if any(isfinite(stats.exploration.binCenters))
        plot(stats.exploration.binCenters, ...
            stats.exploration.binPSwitch, '-o', 'LineWidth', 2);
    end
    ylim([-0.12 1.12]);
    set(gca, 'YTick', [0 1], 'YTickLabel', {'Stay', 'Switch'});
    xlabel('Reward du choix precedent (ms)');
    ylabel('Transition identitaire');
    title(sprintf('Exploration, P(switch)=%.3f', ...
        stats.exploration.pSwitchAll));
    box off;
else
    showNoData('Pas de transition de choix exploitable');
end

addFigureTitle(sprintf('%s | %s | %s', ...
    meta.sessionID, 'Online plots reproduits offline', inferenceLabel));
figureFiles(end + 1) = saveFigure(fig, outputFolder, ...
    '01_online_plots_offline', options);

%% Figure 2 : strategie spatiale, identitaire, valeur et saillance
fig = figure('Color', 'w', 'Position', [100 70 1450 900], ...
    'Name', 'SRS strategy diagnostics');

% 1. Precision des strategies candidates
subplot(3, 2, 1);
strategyTable = stats.strategyTable;
if isempty(strategyTable)
    showNoData('Aucune strategie calculable');
else
    if any(strategyTable.NReal > 0)
        accuracy = strategyTable.AccuracyReal;
        valid = strategyTable.NReal > 0;
        suffix = 'choix reels';
    else
        accuracy = strategyTable.AccuracyAll;
        valid = strategyTable.NAll > 0;
        suffix = 'descriptif debug';
    end
    validRows = find(valid & isfinite(accuracy));
    [sortedAccuracy, order] = sort(accuracy(validRows), 'descend');
    sortedRows = validRows(order);
    barh(1:numel(sortedRows), sortedAccuracy);
    hold on;
    plot([0.5 0.5], [0.5 numel(sortedRows) + 0.5], 'k--');
    set(gca, 'YTick', 1:numel(sortedRows), ...
        'YTickLabel', cellstr(strategyTable.Strategy(sortedRows)), ...
        'YDir', 'reverse', 'XLim', [0 1]);
    xlabel('Proportion de choix correctement predits');
    title(['Strategies candidates - ' suffix]);
    box off;
end

% 2. Sequence spatiale
subplot(3, 2, 2);
C = T(T.GoodChoice, :);
if isempty(C)
    showNoData('Aucun choix');
else
    plot(C.ChoiceOrdinal, C.ChosenSide, 'ko', 'MarkerSize', 4);
    hold on;
    plot(C.ChoiceOrdinal, C.RichSide, '-', 'LineWidth', 1.0);
    plot(C.ChoiceOrdinal, C.HighSalienceSide, ':', 'LineWidth', 1.2);
    set(gca, 'YLim', [0.7 2.3], 'YTick', [1 2], ...
        'YTickLabel', {'Droite', 'Gauche'});
    xlabel('Choix a deux cibles');
    ylabel('Cote');
    legend({'Choisi', 'Riche', 'Tres saillant'}, 'Location', 'best');
    title('Sequence spatiale');
    box off;
end

% 3. Sequence identitaire
subplot(3, 2, 3);
if isempty(C)
    showNoData('Aucun choix');
else
    plot(C.ChoiceOrdinal, C.ChosenTarget, 'ko', 'MarkerSize', 4);
    hold on;
    plot(C.ChoiceOrdinal, C.RichTarget, '-', 'LineWidth', 1.0);
    plot(C.ChoiceOrdinal, C.HighSalienceTarget, ':', 'LineWidth', 1.2);
    set(gca, 'YLim', [0.7 2.3], 'YTick', [1 2], ...
        'YTickLabel', {'T1', 'T2'});
    xlabel('Choix a deux cibles');
    ylabel('Identite');
    legend({'Choisie', 'Riche', 'Tres saillante'}, 'Location', 'best');
    title('Sequence identitaire');
    box off;
end

% 4. P(droite) conditionnelle : lecture intuitive des influences
subplot(3, 2, 4);
plotConditionalRightChoice(C);

% 5. Performance par bloc
subplot(3, 2, 5);
plotBlockChoiceSummary(T);

% 6. Entropie spatiale glissante
subplot(3, 2, 6);
plot(T.Attempt, stats.engagement.rollingRightChoiceEntropy, ...
    'LineWidth', 1.5);
ylim([0 1]);
xlabel('Tentative');
ylabel('Entropie binaire (bits)');
title(sprintf('Diversite droite/gauche, fenetre %d', ...
    stats.engagement.window));
box off;

addFigureTitle(sprintf('%s | Strategies | %s', ...
    meta.sessionID, inferenceLabel));
figureFiles(end + 1) = saveFigure(fig, outputFolder, ...
    '02_strategy_diagnostics', options);

%% Figure 3 : qualite, engagement et arret
fig = figure('Color', 'w', 'Position', [120 35 1450 1080], ...
    'Name', 'SRS engagement and quality');

subplot(4, 2, 1);
plot(T.Attempt, double(T.GoodTrial), 'ko', 'MarkerSize', 4);
hold on;
set(gca, 'YLim', [-0.15 1.15], 'YTick', [0 1], ...
    'YTickLabel', {'Echec', 'Succes'});
xlabel('Tentative');
ylabel('Issue');
title('Succes et echecs');
markDisengagement(stats.engagement);
box off;

subplot(4, 2, 2);
plot(T.Attempt, stats.engagement.rollingCompletionRate, ...
    'LineWidth', 1.7);
hold on;
plot([min(T.Attempt) max(T.Attempt)], [0.8 0.8], 'k:');
ylim([0 1.05]);
xlabel('Tentative');
ylabel('Taux de completion');
title(sprintf('Completion glissante, fenetre %d', ...
    stats.engagement.window));
markDisengagement(stats.engagement);
box off;

subplot(4, 2, 3);
plot(T.Attempt, T.PreTrialIntervalSec, '.', 'MarkerSize', 8);
hold on;
plot(T.Attempt, stats.engagement.rollingPreTrialIntervalSec, ...
    'LineWidth', 1.7);
xlabel('Tentative');
ylabel('Intervalle avant essai (s)');
title('Ralentissement entre les essais');
markDisengagement(stats.engagement);
box off;

subplot(4, 2, 4);
validFix = isfinite(T.FixAcquisitionLatencyMs);
if any(validFix)
    plot(T.Attempt(validFix), T.FixAcquisitionLatencyMs(validFix), '.', ...
        'MarkerSize', 8);
    hold on;
    plot(T.Attempt, stats.engagement.rollingFixAcquisitionLatencyMs, ...
        'LineWidth', 1.7);
    xlabel('Tentative');
    ylabel('Latence fixation (ms)');
    title('Acquisition de la fixation');
    markDisengagement(stats.engagement);
    box off;
else
    showNoData('Aucune latence de fixation valide');
end

subplot(4, 2, 5);
validRT = isfinite(T.ReactionTimeMs);
if any(validRT)
    plot(T.Attempt(validRT), T.ReactionTimeMs(validRT), '.', ...
        'MarkerSize', 8);
    hold on;
    plot(T.Attempt, stats.engagement.rollingReactionTimeMs, ...
        'LineWidth', 1.7);
    xlabel('Tentative');
    ylabel('RT (ms)');
    title('Temps de reaction');
    markDisengagement(stats.engagement);
    box off;
else
    showNoData('Aucun RT valide');
end

subplot(4, 2, 6);
stem(T.Attempt, T.MissedFrames, 'Marker', 'none');
xlabel('Tentative');
ylabel('Frames manquees');
title(sprintf('Qualite affichage, total = %.0f', ...
    sum(T.MissedFrames, 'omitnan')));
markDisengagement(stats.engagement);
box off;

subplot(4, 2, 7);
blockTable = stats.blockTable;
if isempty(blockTable)
    showNoData('Aucun bloc');
else
    bar(1:height(blockTable), blockTable.CompletionFraction);
    hold on;
    plot([0.5 height(blockTable) + 0.5], [1 1], 'k--');
    set(gca, 'XTick', 1:height(blockTable), ...
        'XTickLabel', cellstr(blockTable.BlockUID), ...
        'XTickLabelRotation', 25, 'YLim', [0 1.1]);
    ylabel('Fraction du bloc terminee');
    title('Point d''arret de chaque bloc');
    box off;
end

subplot(4, 2, 8);
validDuration = isfinite(T.TrialDurationSec);
if any(validDuration)
    plot(T.Attempt(validDuration), T.TrialDurationSec(validDuration), '.', ...
        'MarkerSize', 8);
    hold on;
    plot(T.Attempt, stats.engagement.rollingTrialDurationSec, ...
        'LineWidth', 1.7);
    xlabel('Tentative');
    ylabel('Duree (s)');
    title('Duree des tentatives');
    markDisengagement(stats.engagement);
    box off;
else
    showNoData('Aucune duree de tentative valide');
end

addFigureTitle(sprintf('%s | Engagement operationnel | %s', ...
    meta.sessionID, inferenceLabel));
figureFiles(end + 1) = saveFigure(fig, outputFolder, ...
    '03_engagement_quality', options);

%% Figure 4 : analyses supplementaires
fig = figure('Color', 'w', 'Position', [140 80 1450 900], ...
    'Name', 'SRS additional behavioral analyses');

subplot(2, 2, 1);
plotPsychometric(stats.psychometricTable);

subplot(2, 2, 2);
plotChoiceEvolution(stats.choiceEvolutionTable);

subplot(2, 2, 3);
plotAssociationEffects(stats.associationTable);

subplot(2, 2, 4);
plotTimeSeriesTrends(stats.timeSeriesTable);

addFigureTitle(sprintf('%s | Analyses supplementaires | %s', ...
    meta.sessionID, inferenceLabel));
figureFiles(end + 1) = saveFigure(fig, outputFolder, ...
    '04_additional_analyses', options);

end

%% ========================================================================
% Sous-fonctions de graphiques
% ========================================================================

function plotReactionTimes(T)
conflict = T.GoodChoice & T.IsConflict & isfinite(T.ReactionTimeMs);
congruent = T.GoodChoice & T.IsCongruent & isfinite(T.ReactionTimeMs);
if ~any(conflict | congruent)
    showNoData('Aucun RT valide');
    return;
end

hold on;
if any(conflict)
    x = 1 + 0.10 * (rand(sum(conflict), 1) - 0.5);
    plot(x, T.ReactionTimeMs(conflict), 'o', 'MarkerSize', 4);
    medianConflict = median(T.ReactionTimeMs(conflict));
    plot([0.75 1.25], [medianConflict medianConflict], 'k-', ...
        'LineWidth', 2);
end
if any(congruent)
    x = 2 + 0.10 * (rand(sum(congruent), 1) - 0.5);
    plot(x, T.ReactionTimeMs(congruent), 'o', 'MarkerSize', 4);
    medianCongruent = median(T.ReactionTimeMs(congruent));
    plot([1.75 2.25], [medianCongruent medianCongruent], 'k-', ...
        'LineWidth', 2);
end
set(gca, 'XLim', [0.5 2.5], 'XTick', [1 2], ...
    'XTickLabel', {'Conflit', 'Congruent'});
ylabel('RT (ms)');
title('RT individuels et medianes');
box off;
end

function plotConditionalRightChoice(C)
if isempty(C)
    showNoData('Aucun choix');
    return;
end

predictorNames = {'Riche a gauche', 'Riche a droite', ...
                  'Saliente a gauche', 'Saliente a droite', ...
                  'T1 a gauche', 'T1 a droite'};
values = nan(6, 1);
values(1) = mean(C.ChoseRight(C.RichOnRight == 0), 'omitnan');
values(2) = mean(C.ChoseRight(C.RichOnRight == 1), 'omitnan');
values(3) = mean(C.ChoseRight(C.HighSalienceOnRight == 0), 'omitnan');
values(4) = mean(C.ChoseRight(C.HighSalienceOnRight == 1), 'omitnan');
values(5) = mean(C.ChoseRight(C.T1OnRight == 0), 'omitnan');
values(6) = mean(C.ChoseRight(C.T1OnRight == 1), 'omitnan');

bar(1:6, values);
hold on;
plot([0.5 6.5], [0.5 0.5], 'k--');
set(gca, 'XTick', 1:6, 'XTickLabel', predictorNames, ...
    'XTickLabelRotation', 25, 'YLim', [0 1]);
ylabel('P(choix droite)');
title('Influences spatiales conditionnelles');
box off;
end

function plotBlockChoiceSummary(T)
blocks = unique(T.BlockUID, 'stable');
if isempty(blocks)
    showNoData('Aucun bloc');
    return;
end

pRich = nan(numel(blocks), 1);
pRight = nan(numel(blocks), 1);
pT1 = nan(numel(blocks), 1);
pHighSal = nan(numel(blocks), 1);
for iBlock = 1:numel(blocks)
    mask = T.BlockUID == blocks(iBlock) & T.GoodChoice;
    pRich(iBlock) = mean(T.ChoseRich(mask), 'omitnan');
    pRight(iBlock) = mean(T.ChoseRight(mask), 'omitnan');
    pT1(iBlock) = mean(T.ChoseT1(mask), 'omitnan');
    pHighSal(iBlock) = mean(T.ChoseHighSalience(mask), 'omitnan');
end
plot(1:numel(blocks), pRich, '-o', 'LineWidth', 1.5);
hold on;
plot(1:numel(blocks), pRight, '-o', 'LineWidth', 1.5);
plot(1:numel(blocks), pT1, '-o', 'LineWidth', 1.5);
plot(1:numel(blocks), pHighSal, '-o', 'LineWidth', 1.5);
plot([0.5 numel(blocks) + 0.5], [0.5 0.5], 'k:');
set(gca, 'XTick', 1:numel(blocks), ...
    'XTickLabel', cellstr(blocks), 'XTickLabelRotation', 25, ...
    'YLim', [0 1]);
ylabel('Proportion');
title('Strategie par bloc');
legend({'Riche', 'Droite', 'T1', 'Haute saillance'}, ...
    'Location', 'best');
box off;
end

function plotPsychometric(P)
if isempty(P)
    showNoData('Aucune evidence de saillance continue');
    return;
end

if any(P.NReal > 0)
    y = P.PChooseT1Real;
    low = P.CI95LowReal;
    high = P.CI95HighReal;
    valid = P.NReal > 0 & isfinite(y);
    dataLabel = 'choix reels';
else
    y = P.PChooseT1All;
    low = P.CI95LowAll;
    high = P.CI95HighAll;
    valid = P.NAll > 0 & isfinite(y);
    dataLabel = 'descriptif debug';
end

if ~any(valid)
    showNoData('Aucun bin psychometrique exploitable');
    return;
end

x = P.EvidenceMean(valid);
y = y(valid);
low = low(valid);
high = high(valid);
errorbar(x, y, y - low, high - y, 'o-', 'LineWidth', 1.5);
hold on;
limits = [min(x) max(x)];
if limits(1) == limits(2)
    limits = limits + [-0.5 0.5];
end
plot(limits, [0.5 0.5], 'k--');
plot([0 0], [0 1], 'k:');
xlim(limits);
ylim([0 1]);
xlabel(char(P.EvidenceType(1)));
ylabel('P(choix T1)');
title(['Psychometrie de saillance - ' dataLabel]);
box off;
end

function plotChoiceEvolution(E)
if isempty(E)
    showNoData('Aucune evolution de choix calculable');
    return;
end

if any(E.NEarlyReal > 0 & E.NLateReal > 0)
    values = E.LateMinusEarlyReal;
    valid = E.NEarlyReal > 0 & E.NLateReal > 0 & isfinite(values);
    dataLabel = 'choix reels';
else
    values = E.LateMinusEarlyAll;
    valid = E.NEarlyAll > 0 & E.NLateAll > 0 & isfinite(values);
    dataLabel = 'descriptif debug';
end

if ~any(valid)
    showNoData('Aucune comparaison debut-fin');
    return;
end

rows = find(valid);
barh(1:numel(rows), values(rows));
hold on;
plot([0 0], [0.5 numel(rows) + 0.5], 'k--');
set(gca, 'YTick', 1:numel(rows), ...
    'YTickLabel', cellstr(E.Metric(rows)), 'YDir', 'reverse');
xlabel('Fin moins debut');
title(['Evolution premier/dernier tiers - ' dataLabel]);
box off;
end

function plotAssociationEffects(A)
if isempty(A)
    showNoData('Aucune association conditionnelle');
    return;
end

if any(A.NReal > 0)
    values = A.DifferenceReal;
    valid = A.NReal > 0 & isfinite(values);
    dataLabel = 'choix reels';
else
    values = A.DifferenceAll;
    valid = A.NAll > 0 & isfinite(values);
    dataLabel = 'descriptif debug';
end

if ~any(valid)
    showNoData('Associations non estimables');
    return;
end

rows = find(valid);
labels = A.Predictor(rows) + " vers " + A.Response(rows);
barh(1:numel(rows), values(rows));
hold on;
plot([0 0], [0.5 numel(rows) + 0.5], 'k--');
set(gca, 'YTick', 1:numel(rows), ...
    'YTickLabel', cellstr(labels), 'YDir', 'reverse');
xlabel('P(reponse|pred=1) - P(reponse|pred=0)');
title(['Associations conditionnelles - ' dataLabel]);
box off;
end

function plotTimeSeriesTrends(S)
if isempty(S)
    showNoData('Aucune serie temporelle');
    return;
end

valid = S.N >= 5 & isfinite(S.CorrelationWithAttempt);
if ~any(valid)
    showNoData('Aucune tendance temporelle estimable');
    return;
end

rows = find(valid);
values = S.CorrelationWithAttempt(rows);
barh(1:numel(rows), values);
hold on;
plot([0 0], [0.5 numel(rows) + 0.5], 'k--');
set(gca, 'YTick', 1:numel(rows), ...
    'YTickLabel', cellstr(S.Metric(rows)), 'YDir', 'reverse', ...
    'XLim', [-1 1]);
xlabel('Correlation avec la tentative');
title('Tendances temporelles, p-values dans le CSV');
box off;
end

function plotHorizontalZero()
limits = xlim;
if all(isfinite(limits))
    plot(limits, [0 0], 'k:');
end
end

function showNoData(message)
axis off;
text(0.5, 0.5, message, 'HorizontalAlignment', 'center', ...
    'Units', 'normalized', 'FontWeight', 'bold');
end

function addFigureTitle(titleText)
if exist('sgtitle', 'file') == 2
    sgtitle(titleText, 'FontWeight', 'bold');
else
    annotation('textbox', [0 0.965 1 0.03], ...
        'String', titleText, 'EdgeColor', 'none', ...
        'HorizontalAlignment', 'center', 'FontWeight', 'bold');
end
end

function markDisengagement(engagement)
if ~isfinite(engagement.estimatedDisengagementAttempt)
    return;
end
limits = ylim;
x = engagement.estimatedDisengagementAttempt;
plot([x x], limits, 'r--', 'LineWidth', 1.4);
ylim(limits);
end

function filePath = saveFigure(fig, outputFolder, baseName, options)
filePath = fullfile(outputFolder, [baseName '.png']);
if isfield(options, 'saveFigures') && options.saveFigures
    print(fig, filePath, '-dpng', '-r160');
end
if isfield(options, 'saveMatlabFigures') && options.saveMatlabFigures
    figPath = fullfile(outputFolder, [baseName '.fig']);
    if exist('savefig', 'file') == 2
        savefig(fig, figPath);
    else
        saveas(fig, figPath);
    end
end
end

function [low, high] = localWilson(x, n)
if n <= 0 || ~isfinite(x) || ~isfinite(n)
    low = NaN;
    high = NaN;
    return;
end
z = 1.95996398454005;
p = x / n;
den = 1 + z^2 / n;
center = (p + z^2 / (2 * n)) / den;
halfWidth = z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den;
low = max(0, center - halfWidth);
high = min(1, center + halfWidth);
end
